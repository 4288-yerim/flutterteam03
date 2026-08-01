import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import '../theme.dart';
import 'package:share_plus/share_plus.dart';

import '../widgets/app_main_background.dart';
import '../widgets/app_top_bar.dart';
import 'widgets/wave_loading_indicator.dart';
import '../theme.dart';
import '../widgets/app_confirm_dialog.dart';
import 'services/question_generation_api_service.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';

class MaterialSummaryResultPage extends StatefulWidget {
  final String? selectedCertificate;
  final bool isSplitSummary;
  final List<String> uploadedFileNames;
  final List<String> uploadedFileUrls;

  /// 이전 화면(업로드 화면)에서 이미 summarizeMaterial 호출까지 끝내고
  /// 응답을 들고 왔다면 여기로 넘겨준다. 그러면 이 페이지는 API를
  /// 다시 호출하지 않고 로딩 없이 바로 결과를 보여준다.
  /// null이면 기존처럼 이 페이지가 직접 요약을 요청한다.
  final Map<String, dynamic>? initialResult;

  MaterialSummaryResultPage({
    super.key,
    required this.selectedCertificate,
    required this.isSplitSummary,
    required this.uploadedFileNames,
    required this.uploadedFileUrls,
    this.initialResult,
  });

  @override
  State<MaterialSummaryResultPage> createState() =>
      _MaterialSummaryResultPageState();
}

class _MaterialSummaryResultPageState extends State<MaterialSummaryResultPage> {
  final GlobalKey _summaryCaptureKey = GlobalKey();
  static List<String> _analysisMessages = [
    '구름iT이 자료를 분석하고 있어요',
    '업로드한 자료를 읽고 있어요',
    '핵심 내용을 정리하고 있어요',
    '요약을 만들고 있어요',
    '거의 다 됐어요',
    '이제 보여드릴게요',
  ];
  static List<int> _analysisDurations = [2800, 3200, 3200, 3600, 2200, 900];

  bool _isLoading = true;
  // 뒤로가기/다른 자료 요약하기를 중복으로 여러 번 누르는 것만 막기 위한 플래그.
  // (더 이상 화면을 막는 로딩 표시는 하지 않는다)
  bool _isLeaving = false;
  bool _isSavingSummary = false;

  String? _summary;
  String? _errorMessage;

  int _originalLength = 0;
  int _summaryLength = 0;
  int _fileCount = 0;

  @override
  void initState() {
    super.initState();

    if (widget.initialResult != null) {
      // 이전 화면(업로드 화면)에서 이미 summarizeMaterial까지 끝내고
      // 결과를 들고 온 경우: 이 페이지에서는 로딩을 아예 띄우지 않는다.
      _isLoading = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _handleDecodedData(widget.initialResult!, forceSummary: false);
      });
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _requestSummary();
    });
  }

  Future<void> _requestSummary({bool forceSummary = false}) async {
    if (widget.uploadedFileUrls.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = '요약할 파일 URL이 없습니다.';
      });
      return;
    }

    final selectedCertificate = widget.selectedCertificate?.trim() ?? '';

    if (selectedCertificate.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = '선택한 자격증 정보가 없습니다.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final decodedData = await QuestionGenerationApiService.summarizeMaterial(
        fileUrls: widget.uploadedFileUrls,
        selectedCertificate: selectedCertificate,
        forceSummary: forceSummary,
      );

      if (!mounted) return;

      await _handleDecodedData(decodedData, forceSummary: forceSummary);
    } catch (error, stackTrace) {
      debugPrint('요약 API 요청 실패: $error');
      debugPrint('$stackTrace');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  /// summarizeMaterial 응답(직접 호출로 받았든, 이전 화면에서 미리 받아왔든)을
  /// 공통으로 처리한다. 서버는 자격증 불일치 여부와 무관하게 summary를 같은
  /// 응답 안에서 함께 만들어 보내주므로, 불일치 확인 후 "계속 요약"을
  /// 선택해도 API를 다시 호출하지 않고 이미 받은 값을 그대로 쓴다.
  Future<void> _handleDecodedData(
    Map<String, dynamic> decodedData, {
    required bool forceSummary,
  }) async {
    final selectedCertificate = widget.selectedCertificate?.trim() ?? '';
    final certificateMatch = decodedData['certificate_match'] != false;
    final summary = decodedData['summary']?.toString().trim() ?? '';
    final originalLength = _toInt(decodedData['original_length']);
    final fileCount = _toInt(
      decodedData['file_count'],
      fallback: widget.uploadedFileUrls.length,
    );

    if (!certificateMatch && !forceSummary) {
      final detectedCertificate =
          decodedData['detected_certificate']?.toString().trim() ?? '다른 자격증';
      final mismatchReason =
          decodedData['mismatch_reason']?.toString().trim() ?? '';

      if (!mounted) return;

      setState(() => _isLoading = false);

      final shouldContinue = await _showCertificateMismatchDialog(
        selectedCertificate: selectedCertificate,
        detectedCertificate: detectedCertificate,
        mismatchReason: mismatchReason,
      );

      if (!mounted) return;

      if (shouldContinue == true) {
        if (summary.isNotEmpty) {
          // 이미 받아둔 요약을 그대로 사용 -> 재요청/재로딩 없음
          setState(() {
            _summary = summary;
            _originalLength = originalLength;
            _summaryLength = summary.length;
            _fileCount = fileCount;
            _isLoading = false;
          });
        } else {
          // 혹시 서버가 요약을 못 만들어 보낸 경우에만 예외적으로 재요청
          await _requestSummary(forceSummary: true);
        }
      } else {
        _summarizeAnotherMaterial();
      }

      return;
    }

    if (summary.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = '서버에서 빈 요약 결과를 반환했습니다.';
      });
      return;
    }

    if (!mounted) return;

    setState(() {
      _summary = summary;
      _originalLength = originalLength;
      _summaryLength = summary.length;
      _fileCount = fileCount;
      _isLoading = false;
    });
  }

  int _toInt(dynamic value, {int fallback = 0}) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  Future<bool?> _showCertificateMismatchDialog({
    required String selectedCertificate,
    required String detectedCertificate,
    required String mismatchReason,
  }) {
    final descriptionParts = [
      '업로드한 자료가 선택한 자격증과 다른 자료일 수 있어요.',
      if (mismatchReason.isNotEmpty) mismatchReason,
      '선택한 자격증을 기준으로 계속 요약할까요?',
    ];

    return AppConfirmDialog.show<bool>(
      context,
      icon: Icons.warning_amber_rounded,
      title: '선택한 자격증을 확인해주세요',
      description: descriptionParts.join('\n\n'),
      // 버튼 안에서 글자가 잘리지 않도록 문구를 짧게 정리했어요.
      primaryLabel: '계속 요약할게요',
      onPrimaryPressed: () => Navigator.pop(context, true),
      secondaryLabel: '다시 확인할게요',
      onSecondaryPressed: () => Navigator.pop(context, false),
      barrierDismissible: false,
      preventBack: true,
      extra: _CertificateComparisonBox(
        selectedCertificate: selectedCertificate,
        detectedCertificate: detectedCertificate,
      ),
    );
  }

  Future<void> _saveSummary() async {
    if (_summary == null || _summary!.trim().isEmpty) {
      return;
    }
    if (_isSavingSummary) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('로그인이 필요한 기능이에요.')));
      return;
    }

    setState(() => _isSavingSummary = true);

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('saved_summaries')
          .add({
            'certificateName': widget.selectedCertificate ?? '',
            'summary': _summary,
            'originalLength': _originalLength,
            'summaryLength': _summaryLength,
            'fileCount': _fileCount,
            'createdAt': FieldValue.serverTimestamp(),
          });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('요약본을 저장했어요.')));
    } catch (error, stackTrace) {
      debugPrint('요약본 저장 실패: $error');
      debugPrint('$stackTrace');

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('요약본 저장에 실패했어요. 다시 시도해주세요.')));
    } finally {
      if (mounted) {
        setState(() => _isSavingSummary = false);
      }
    }
  }

  Future<void> _downloadSummary() async {
    if (_summary == null || _summary!.trim().isEmpty) {
      return;
    }

    final title = widget.selectedCertificate?.trim().isNotEmpty == true
        ? widget.selectedCertificate!.trim()
        : '따IT 요약본';

    try {
      final boundary =
          _summaryCaptureKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;

      if (boundary == null) {
        throw Exception('캡처할 화면을 찾지 못했습니다.');
      }

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('이미지 변환에 실패했습니다.');
      }
      final pngBytes = byteData.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/summary_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(pngBytes);

      await Share.shareXFiles([XFile(file.path)], text: '$title 요약본');
    } catch (error, stackTrace) {
      debugPrint('요약본 이미지 공유 실패: $error');
      debugPrint('$stackTrace');

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('요약본을 공유하지 못했어요. 다시 시도해주세요.')));
    }
  }

  void _summarizeAnotherMaterial() {
    if (_isLeaving) return;
    _isLeaving = true;

    _deleteUploadedFilesInBackground();

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  void _deleteUploadedFilesInBackground() {
    if (widget.uploadedFileUrls.isEmpty) return;

    for (final fileUrl in widget.uploadedFileUrls) {
      FirebaseStorage.instance.refFromURL(fileUrl).delete().catchError((
        error,
        stackTrace,
      ) {
        debugPrint('요약 자료 삭제 실패: $error');
        debugPrint('$stackTrace');
      });
    }
  }

  Widget _buildSummaryContent() {
    if (_isLoading) {
      return SizedBox.shrink();
    }

    if (_errorMessage != null) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(22, 28, 22, 24),
        decoration: BoxDecoration(
          color: context.colors.surfaceTransparent.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: context.colors.border),
        ),
        child: Column(
          children: [
            Icon(Icons.error_outline_rounded, color: AppColors.pink, size: 46),
            SizedBox(height: 16),
            Text(
              '요약을 생성하지 못했어요.',
              style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 10),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.colors.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: () => _requestSummary(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.pink,
                  foregroundColor: context.colors.onPrimary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: Icon(Icons.refresh_rounded),
                label: Text(
                  '다시 시도',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RepaintBoundary(
      key: _summaryCaptureKey,
      child: _CertificateSummarySection(
        certificateName: widget.selectedCertificate ?? '업로드 자료',
        summaryNumber: 1,
        summary: _summary ?? '',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayedFileCount = _fileCount == 0
        ? widget.uploadedFileNames.length
        : _fileCount;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_isLoading) return;
        _summarizeAnotherMaterial();
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: Colors.transparent,
        appBar: AppTopBar(
          title: 'AI 요약 결과',
          centerTitle: false,
          leading: IconButton(
            onPressed: _isLoading ? null : _summarizeAnotherMaterial,
            tooltip: '뒤로가기',
            icon: Icon(
              Icons.arrow_back_rounded,
              color: context.colors.textPrimary,
            ),
          ),
        ),
        body: AppMainBackground(
          child: Stack(
            children: [
              SafeArea(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(24, 22, 24, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SummaryResultHeader(
                        selectedCertificate: widget.selectedCertificate,
                        isSplitSummary: widget.isSplitSummary,
                        fileCount: displayedFileCount,
                        isLoading: _isLoading,
                        hasError: _errorMessage != null,
                      ),
                      SizedBox(height: 30),
                      Text(
                        '구름iT 요약 노트',
                        style: TextStyle(
                          color: context.colors.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      SizedBox(height: 7),
                      Text(
                        _isLoading
                            ? '업로드한 자료에서 핵심 내용을 찾고 있어요.'
                            : _errorMessage != null
                            ? '오류 내용을 확인한 뒤 다시 시도해주세요.'
                            : '업로드한 자료의 핵심 내용을 정리했어요.',
                        style: TextStyle(
                          color: context.colors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 16),
                      _buildSummaryContent(),
                      if (!_isLoading && _errorMessage == null) ...[
                        SizedBox(height: 12),
                        _SummaryMetadata(
                          originalLength: _originalLength,
                          summaryLength: _summaryLength,
                        ),
                        SizedBox(height: 22),
                        _SummaryActionButtons(
                          onSavePressed: _isSavingSummary ? null : _saveSummary,
                          onDownloadPressed: _downloadSummary,
                          isSaving: _isSavingSummary,
                        ),
                      ],
                      SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: OutlinedButton.icon(
                          onPressed: _isLoading
                              ? null
                              : _summarizeAnotherMaterial,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.pink,
                            backgroundColor: context.colors.surface.withValues(
                              alpha: 0.84,
                            ),
                            side: BorderSide(color: AppColors.pink, width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          icon: Icon(Icons.refresh_rounded, size: 21),
                          label: Text(
                            '다른 자료 요약하기',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_isLoading)
                Positioned.fill(
                  child: Container(
                    color: context.colors.surfaceTransparent.withValues(
                      alpha: 0.92,
                    ),
                    child: Align(
                      alignment: Alignment(0, -0.15),
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24),
                        child: _RotatingLoadingContent(
                          messages: _analysisMessages,
                          durations: _analysisDurations,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CertificateComparisonBox extends StatelessWidget {
  final String selectedCertificate;
  final String detectedCertificate;

  _CertificateComparisonBox({
    required this.selectedCertificate,
    required this.detectedCertificate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: context.colors.pinkSoftAlt,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _CertificateComparisonRow(
            label: '선택한 자격증',
            value: selectedCertificate,
          ),
          SizedBox(height: 12),
          Divider(height: 1, color: context.colors.divider),
          SizedBox(height: 12),
          _CertificateComparisonRow(
            label: 'AI가 판단한 자격증',
            value: detectedCertificate,
          ),
        ],
      ),
    );
  }
}

class _CertificateComparisonRow extends StatelessWidget {
  final String label;
  final String value;

  _CertificateComparisonRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 108,
          child: Text(
            label,
            style: TextStyle(
              color: context.colors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: context.colors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryResultHeader extends StatelessWidget {
  final String? selectedCertificate;
  final bool isSplitSummary;
  final int fileCount;
  final bool isLoading;
  final bool hasError;

  _SummaryResultHeader({
    required this.selectedCertificate,
    required this.isSplitSummary,
    required this.fileCount,
    required this.isLoading,
    required this.hasError,
  });

  // 그라데이션 배경 위에서는 테마 색상 대신 고정 색을 써서 대비를 보장한다.
  @override
  Widget build(BuildContext context) {
    final titleColor = context.colors.textPrimary;
    final descColor = context.colors.textSecondary;
    final accentColor = context.colors.pinkDeep;
    final String title;
    final String description;
    final IconData icon;

    if (isLoading) {
      title = '자료를 분석하고 있어요';
      description = '업로드한 파일을 구름iT에게 전달했어요.';
      icon = Icons.hourglass_top_rounded;
    } else if (hasError) {
      title = '요약 생성에 실패했어요';
      description = '서버 연결 또는 파일 처리 상태를 확인해주세요.';
      icon = Icons.error_outline_rounded;
    } else {
      title = '요약이 완료됐어요!';
      description = isSplitSummary
          ? '업로드한 자료를 통합하여 요약했어요.'
          : selectedCertificate != null
          ? '$selectedCertificate 자료를 요약했어요.'
          : '업로드한 자료를 요약했어요.';
      icon = Icons.auto_awesome_rounded;
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(22, 24, 20, 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [context.colors.pinkSoft, context.colors.lavender],
        ),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: context.colors.surface, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),
                SizedBox(height: 9),
                Text(
                  description,
                  style: TextStyle(
                    color: descColor,
                    fontSize: 13.5,
                    height: 1.5,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  '업로드 자료 $fileCount개',
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: context.colors.surface,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: accentColor, size: 30),
          ),
        ],
      ),
    );
  }
}

class _CertificateSummarySection extends StatelessWidget {
  final String certificateName;
  final int summaryNumber;
  final String summary;

  _CertificateSummarySection({
    required this.certificateName,
    required this.summaryNumber,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, 20, 20, 22),
      decoration: BoxDecoration(
        color: context.colors.surfaceTransparent.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: context.colors.pinkSoft,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$summaryNumber',
                  style: TextStyle(
                    color: AppColors.pink,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              SizedBox(width: 11),
              Expanded(
                child: Text(
                  certificateName,
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 22),
          _SummaryResultTitle(title: '요약 내용'),
          SizedBox(height: 14),
          SelectableText(
            summary,
            style: TextStyle(
              color: context.colors.textPrimary,
              fontSize: 14,
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryMetadata extends StatelessWidget {
  final int originalLength;
  final int summaryLength;

  _SummaryMetadata({required this.originalLength, required this.summaryLength});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Text(
        '원문 $originalLength자 · 요약 $summaryLength자',
        style: TextStyle(
          color: context.colors.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SummaryResultTitle extends StatelessWidget {
  final String title;

  _SummaryResultTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        color: context.colors.textPrimary,
        fontSize: 17,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _SummaryActionButtons extends StatelessWidget {
  final VoidCallback? onSavePressed;
  final VoidCallback onDownloadPressed;
  final bool isSaving;

  _SummaryActionButtons({
    required this.onSavePressed,
    required this.onDownloadPressed,
    this.isSaving = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 54,
            child: OutlinedButton.icon(
              onPressed: onSavePressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.pink,
                backgroundColor: context.colors.surface.withValues(alpha: 0.84),
                side: BorderSide(color: AppColors.pink, width: 1.5),
                padding: EdgeInsets.symmetric(horizontal: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              icon: isSaving
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.pink,
                      ),
                    )
                  : Icon(Icons.bookmark_add_outlined, size: 20),
              label: Text(
                '요약본 저장',
                maxLines: 1,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: SizedBox(
            height: 54,
            child: FilledButton.icon(
              onPressed: onDownloadPressed,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.pink,
                foregroundColor: context.colors.onPrimary,
                elevation: 0,
                padding: EdgeInsets.symmetric(horizontal: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              icon: Icon(Icons.ios_share_rounded, size: 20),
              label: Text(
                '요약본 다운',
                maxLines: 1,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RotatingLoadingContent extends StatefulWidget {
  final List<String> messages;
  final List<int> durations;

  _RotatingLoadingContent({required this.messages, required this.durations});

  @override
  State<_RotatingLoadingContent> createState() =>
      _RotatingLoadingContentState();
}

class _RotatingLoadingContentState extends State<_RotatingLoadingContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotationController;
  Timer? _messageTimer;
  int _messageIndex = 0;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1400),
    )..repeat();
    _scheduleNextMessage();
  }

  void _scheduleNextMessage() {
    final duration =
        widget.durations[_messageIndex.clamp(0, widget.durations.length - 1)];
    _messageTimer = Timer(Duration(milliseconds: duration), () {
      if (!mounted) return;
      if (_messageIndex < widget.messages.length - 1) {
        setState(() => _messageIndex++);
        _scheduleNextMessage();
      }
    });
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _messageTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        WaveLoadingIndicator(
          size: 72,
          progress: _messageIndex / (widget.messages.length - 1),
          backgroundColor: context.colors.pinkSoft,
          waveColorStart: Color(0xFFF4869D),
          waveColorEnd: Color(0xFFFF8FA3),
        ),
        SizedBox(height: 26),
        AnimatedSwitcher(
          duration: Duration(milliseconds: 350),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween(
                begin: Offset(0, 0.15),
                end: Offset.zero,
              ).animate(anim),
              child: child,
            ),
          ),
          child: Text(
            widget.messages[_messageIndex],
            key: ValueKey(_messageIndex),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.colors.textPrimary,
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}
