import 'dart:convert';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../widgets/app_main_background.dart';
import '../widgets/app_top_bar.dart';

class MaterialSummaryResultPage extends StatefulWidget {
  final String? selectedCertificate;
  final bool isSplitSummary;
  final List<String> uploadedFileNames;
  final List<String> uploadedFileUrls;

  const MaterialSummaryResultPage({
    super.key,
    required this.selectedCertificate,
    required this.isSplitSummary,
    required this.uploadedFileNames,
    required this.uploadedFileUrls,
  });

  @override
  State<MaterialSummaryResultPage> createState() =>
      _MaterialSummaryResultPageState();
}

class _MaterialSummaryResultPageState
    extends State<MaterialSummaryResultPage> {
  static const Color _textColor = Color(0xFF302C2E);
  static const Color _subTextColor = Color(0xFF817B7D);
  static const Color _pinkColor = Color(0xFFF4869D);

  // TODO: EC2 탄력적 IP로 변경
  String get _apiBaseUrl =>
      dotenv.env['API_BASE_URL']?.trim() ?? '';

  bool _isLoading = true;
  bool _isDeletingFiles = false;

  String? _summary;
  String? _errorMessage;

  int _originalLength = 0;
  int _summaryLength = 0;
  int _fileCount = 0;

  @override
  void initState() {
    super.initState();
    _requestSummary();
  }

  Future<void> _requestSummary() async {
    if (widget.uploadedFileUrls.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = '요약할 파일 URL이 없습니다.';
      });
      return;
    }

    if (_apiBaseUrl.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'API 서버 주소가 설정되지 않았습니다.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http
          .post(
        Uri.parse('$_apiBaseUrl/summarize-url'),
        headers: const {
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode({
          'file_urls': widget.uploadedFileUrls,
        }),
      )
          .timeout(const Duration(minutes: 3));

      final responseBody = utf8.decode(response.bodyBytes);

      if (response.statusCode == 200) {
        final decodedData = jsonDecode(responseBody);

        if (decodedData is! Map<String, dynamic>) {
          throw Exception('서버 응답 형식이 올바르지 않습니다.');
        }

        final summary = decodedData['summary']?.toString().trim() ?? '';

        if (summary.isEmpty) {
          throw Exception('서버에서 빈 요약 결과를 반환했습니다.');
        }

        if (!mounted) return;

        setState(() {
          _summary = summary;
          _originalLength = _toInt(decodedData['original_length']);
          _summaryLength = _toInt(decodedData['summary_length']);
          _fileCount = _toInt(
            decodedData['file_count'],
            fallback: widget.uploadedFileUrls.length,
          );
          _isLoading = false;
        });

        return;
      }

      throw Exception(_extractErrorMessage(responseBody));
    } catch (error, stackTrace) {
      debugPrint('요약 API 요청 실패: $error');
      debugPrint('$stackTrace');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = error
            .toString()
            .replaceFirst('Exception: ', '');
      });
    }
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

  String _extractErrorMessage(String responseBody) {
    if (responseBody.trim().isEmpty) {
      return '요약 생성에 실패했습니다.';
    }

    try {
      final decodedData = jsonDecode(responseBody);

      if (decodedData is Map<String, dynamic>) {
        return decodedData['detail']?.toString() ??
            '요약 생성에 실패했습니다.';
      }
    } catch (_) {
      return responseBody;
    }

    return '요약 생성에 실패했습니다.';
  }

  void _saveSummary() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('요약본 저장 기능은 추후 연결될 예정입니다.'),
      ),
    );
  }

  void _downloadSummary() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('요약본 다운로드 기능은 추후 연결될 예정입니다.'),
      ),
    );
  }

  void _showDeleteLoadingDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return PopScope(
          canPop: false,
          child: Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(
                28,
                30,
                28,
                28,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(
                      color: Color(0xFFF4869D),
                      strokeWidth: 4,
                    ),
                  ),
                  SizedBox(height: 22),
                  Text(
                    '사용한 자료를 정리하고 있어요...',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF302C2E),
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 9),
                  Text(
                    '업로드한 자료를 정리한 뒤\n새로운 요약 화면으로 돌아갈게요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF817B7D),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _summarizeAnotherMaterial() async {
    if (_isDeletingFiles) {
      return;
    }

    if (widget.uploadedFileUrls.isEmpty) {
      if (!mounted) return;

      Navigator.pop(context, true);
      return;
    }

    setState(() {
      _isDeletingFiles = true;
    });

    _showDeleteLoadingDialog();

    try {
      for (final fileUrl in widget.uploadedFileUrls) {
        final storageReference =
        FirebaseStorage.instance.refFromURL(fileUrl);

        await storageReference.delete();
      }

      if (!mounted) return;

      Navigator.of(
        context,
        rootNavigator: true,
      ).pop();

      Navigator.pop(context, true);
    } on FirebaseException catch (error, stackTrace) {
      debugPrint('요약 자료 삭제 실패');
      debugPrint('오류 코드: ${error.code}');
      debugPrint('오류 내용: ${error.message}');
      debugPrint('$stackTrace');

      if (!mounted) return;

      Navigator.of(
        context,
        rootNavigator: true,
      ).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message ?? '요약에 사용된 자료를 삭제하지 못했습니다.',
          ),
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('요약 자료 삭제 실패: $error');
      debugPrint('$stackTrace');

      if (!mounted) return;

      Navigator.of(
        context,
        rootNavigator: true,
      ).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('요약에 사용된 자료를 삭제하지 못했습니다.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDeletingFiles = false;
        });
      }
    }
  }

  Widget _buildSummaryContent() {
    if (_isLoading) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 48,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFFF0E4E8),
          ),
        ),
        child: const Column(
          children: [
            CircularProgressIndicator(
              color: _pinkColor,
            ),
            SizedBox(height: 20),
            Text(
              '자료를 분석하고 있어요.',
              style: TextStyle(
                color: _textColor,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '파일 크기에 따라 시간이 걸릴 수 있어요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _subTextColor,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(
          22,
          28,
          22,
          24,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFFF0E4E8),
          ),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: _pinkColor,
              size: 46,
            ),
            const SizedBox(height: 16),
            const Text(
              '요약을 생성하지 못했어요.',
              style: TextStyle(
                color: _textColor,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _subTextColor,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: _requestSummary,
                style: FilledButton.styleFrom(
                  backgroundColor: _pinkColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text(
                  '다시 시도',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return _CertificateSummarySection(
      certificateName:
      widget.selectedCertificate ?? '업로드 자료',
      summaryNumber: 1,
      summary: _summary ?? '',
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayedFileCount = _fileCount == 0
        ? widget.uploadedFileNames.length
        : _fileCount;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: const AppTopBar(
        title: 'AI 요약 결과',
        centerTitle: false,
      ),
      body: AppMainBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              24,
              22,
              24,
              40,
            ),
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
                const SizedBox(height: 30),
                const Text(
                  '구름iT 요약 노트',
                  style: TextStyle(
                    color: _textColor,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  _isLoading
                      ? '업로드한 자료에서 핵심 내용을 찾고 있어요.'
                      : _errorMessage != null
                      ? '오류 내용을 확인한 뒤 다시 시도해주세요.'
                      : '업로드한 자료의 핵심 내용을 정리했어요.',
                  style: const TextStyle(
                    color: _subTextColor,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                _buildSummaryContent(),
                if (!_isLoading && _errorMessage == null) ...[
                  const SizedBox(height: 12),
                  _SummaryMetadata(
                    originalLength: _originalLength,
                    summaryLength: _summaryLength,
                  ),
                  const SizedBox(height: 22),
                  _SummaryActionButtons(
                    onSavePressed: _saveSummary,
                    onDownloadPressed: _downloadSummary,
                  ),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: _isLoading || _isDeletingFiles
                        ? null
                        : () async {
                      await _summarizeAnotherMaterial();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _pinkColor,
                      backgroundColor:
                      Colors.white.withValues(alpha: 0.84),
                      side: const BorderSide(
                        color: _pinkColor,
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    icon: const Icon(
                      Icons.refresh_rounded,
                      size: 21,
                    ),
                    label: const Text(
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
      ),
    );
  }
}

class _SummaryResultHeader extends StatelessWidget {
  final String? selectedCertificate;
  final bool isSplitSummary;
  final int fileCount;
  final bool isLoading;
  final bool hasError;

  const _SummaryResultHeader({
    required this.selectedCertificate,
    required this.isSplitSummary,
    required this.fileCount,
    required this.isLoading,
    required this.hasError,
  });

  @override
  Widget build(BuildContext context) {
    final String title;
    final String description;
    final IconData icon;

    if (isLoading) {
      title = '자료를 분석하고 있어요';
      description = '업로드한 파일을 서버로 전달했어요.';
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
      padding: const EdgeInsets.fromLTRB(
        22,
        24,
        20,
        22,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFE4ED),
            Color(0xFFF2E4FF),
          ],
        ),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF302C2E),
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  description,
                  style: const TextStyle(
                    color: Color(0xFF817B7D),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '업로드 자료 $fileCount개',
                  style: const TextStyle(
                    color: Color(0xFFF4869D),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 68,
            height: 68,
            decoration: const BoxDecoration(
              color: Color(0xFFFFF2F5),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              color: const Color(0xFFF4869D),
              size: 32,
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _CertificateSummarySection extends StatelessWidget {
  final String certificateName;
  final int summaryNumber;
  final String summary;

  const _CertificateSummarySection({
    required this.certificateName,
    required this.summaryNumber,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        20,
        20,
        20,
        22,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFF0E4E8),
        ),
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
                decoration: const BoxDecoration(
                  color: Color(0xFFFFE6EC),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$summaryNumber',
                  style: const TextStyle(
                    color: Color(0xFFF4869D),
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  certificateName,
                  style: const TextStyle(
                    color: Color(0xFF302C2E),
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const _SummaryResultTitle(
            title: '요약 내용',
          ),
          const SizedBox(height: 14),
          SelectableText(
            summary,
            style: const TextStyle(
              color: Color(0xFF595254),
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

  const _SummaryMetadata({
    required this.originalLength,
    required this.summaryLength,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Text(
        '원문 $originalLength자 · 요약 $summaryLength자',
        style: const TextStyle(
          color: Color(0xFF9A9295),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SummaryResultTitle extends StatelessWidget {
  final String title;

  const _SummaryResultTitle({
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFF302C2E),
        fontSize: 17,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _SummaryActionButtons extends StatelessWidget {
  final VoidCallback onSavePressed;
  final VoidCallback onDownloadPressed;

  const _SummaryActionButtons({
    required this.onSavePressed,
    required this.onDownloadPressed,
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
                foregroundColor: const Color(0xFFF4869D),
                backgroundColor:
                Colors.white.withValues(alpha: 0.84),
                side: const BorderSide(
                  color: Color(0xFFF4869D),
                  width: 1.5,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              icon: const Icon(
                Icons.bookmark_add_outlined,
                size: 20,
              ),
              label: const Text(
                '요약본 저장',
                maxLines: 1,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SizedBox(
            height: 54,
            child: FilledButton.icon(
              onPressed: onDownloadPressed,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFF4869D),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              icon: const Icon(
                Icons.download_rounded,
                size: 20,
              ),
              label: const Text(
                '요약본 다운',
                maxLines: 1,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
