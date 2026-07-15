import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../widgets/app_main_background.dart';
import '../widgets/app_top_bar.dart';
import 'material_summary_result.dart';

class MaterialSummaryPage extends StatefulWidget {
  const MaterialSummaryPage({super.key});

  @override
  State<MaterialSummaryPage> createState() =>
      _MaterialSummaryPageState();
}

class _MaterialSummaryPageState extends State<MaterialSummaryPage> {
  static const Color _textColor = Color(0xFF302C2E);
  static const Color _subTextColor = Color(0xFF817B7D);
  static const Color _pinkColor = Color(0xFFF4869D);

  final List<String> _certificateOptions = const [
    '정보처리기사',
    '정보처리산업기사',
    '정보처리기능사',
    'SQLD',
    'SQLP',
    'ADsP',
    'ADP',
    '빅데이터분석기사',
    '컴퓨터활용능력 1급',
    '컴퓨터활용능력 2급',
    '네트워크관리사 1급',
    '네트워크관리사 2급',
    '리눅스마스터 1급',
    '리눅스마스터 2급',
    '정보보안기사',
    '정보보안산업기사',
    '전자계산기조직응용기사',
    '사무자동화산업기사',
    'AWS Certified Cloud Practitioner',
    'AWS Certified Solutions Architect',
  ];

  // 실제 선택된 파일 정보
  final List<PlatformFile> _selectedFiles = [];

// 화면에 표시할 파일명
  final List<String> _selectedFileNames = [];

// Storage에 업로드된 파일 경로
  final List<String> _uploadedStoragePaths = [];

// 중복 업로드 방지
  bool _isUploading = false;

  bool _isSummaryGenerated = false;

// 업로드한 모든 자료에 공통으로 지정한 자격증
  String? _selectedCertificate;

// 자격증별 분리 요약을 선택했는지 여부
  bool _isSplitSummarySelected = false;

// UI 테스트용
// 추후 AI 판별 결과로 교체
  bool _hasMixedCertificates = false;

// 자격증을 판별하지 못한 경우
  bool _isCertificateUnknown = false;

  Future<void> _selectFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      );

      // 사용자가 파일 선택창을 닫은 경우
      if (result == null || result.files.isEmpty) {
        return;
      }

      final newFiles = result.files.where((newFile) {
        // 같은 이름과 같은 크기의 파일은 중복으로 추가하지 않음
        final alreadyExists = _selectedFiles.any(
              (existingFile) =>
          existingFile.name == newFile.name &&
              existingFile.size == newFile.size,
        );

        return !alreadyExists;
      }).toList();

      if (!mounted) return;

      if (newFiles.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('이미 추가된 파일입니다.'),
          ),
        );

        return;
      }

      setState(() {
        _selectedFiles.addAll(newFiles);
        _selectedFileNames.addAll(
          newFiles.map((file) => file.name),
        );

        _uploadedStoragePaths.clear();

        // 파일 구성이 바뀌었으므로 기존 선택 상태 초기화
        _selectedCertificate = null;
        _isSplitSummarySelected = false;
        _isSummaryGenerated = false;

        // 현재는 팝업 테스트용 임시값
        _hasMixedCertificates = true;
        _isCertificateUnknown = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${newFiles.length}개 파일을 추가했습니다.'),
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('파일 선택 실패: $error');
      debugPrint('$stackTrace');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('파일을 불러오지 못했습니다. 다시 시도해주세요.'),
        ),
      );
    }
  }

  void _removeFile(String fileName) {
    final fileIndex = _selectedFileNames.indexOf(fileName);

    if (fileIndex == -1) {
      return;
    }

    setState(() {
      _selectedFileNames.removeAt(fileIndex);
      _selectedFiles.removeAt(fileIndex);
      _uploadedStoragePaths.clear();

      _selectedCertificate = null;
      _isSplitSummarySelected = false;
      _isSummaryGenerated = false;
    });
  }

  void _removeAllFiles() {
    setState(() {
      _selectedFiles.clear();
      _selectedFileNames.clear();
      _uploadedStoragePaths.clear();

      _selectedCertificate = null;
      _isSplitSummarySelected = false;
      _isSummaryGenerated = false;
    });
  }

  String _getContentType(String fileName) {
    final lowerFileName = fileName.toLowerCase();

    if (lowerFileName.endsWith('.jpg') ||
        lowerFileName.endsWith('.jpeg')) {
      return 'image/jpeg';
    }

    if (lowerFileName.endsWith('.png')) {
      return 'image/png';
    }

    if (lowerFileName.endsWith('.pdf')) {
      return 'application/pdf';
    }

    return 'application/octet-stream';
  }

  Future<List<String>> _uploadSelectedFiles() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception('로그인 정보가 없습니다.');
    }

    if (_selectedFiles.isEmpty) {
      throw Exception('업로드할 파일이 없습니다.');
    }

    final uploadId =
    DateTime.now().millisecondsSinceEpoch.toString();

    final uploadedPaths = <String>[];
    final uploadedReferences = <Reference>[];

    try {
      for (var index = 0;
      index < _selectedFiles.length;
      index++) {
        final selectedFile = _selectedFiles[index];
        final localPath = selectedFile.path;

        if (localPath == null || localPath.isEmpty) {
          throw Exception(
            '${selectedFile.name} 파일 경로를 불러올 수 없습니다.',
          );
        }

        final extension = selectedFile.extension?.toLowerCase() ?? 'file';

        final storageFileName =
            '${DateTime.now().microsecondsSinceEpoch}_$index.$extension';

        final storageReference =
        FirebaseStorage.instance.ref().child(
          'material_summaries/'
              '${user.uid}/'
              '$uploadId/'
              '$storageFileName',
        );

        final metadata = SettableMetadata(
          contentType: _getContentType(selectedFile.name),
          customMetadata: {
            'originalName': selectedFile.name,
            'userId': user.uid,
          },
        );

        await storageReference.putFile(
          File(localPath),
          metadata,
        );

        uploadedReferences.add(storageReference);
        uploadedPaths.add(storageReference.fullPath);
      }

      return uploadedPaths;
    } catch (error) {
      // 일부 파일만 업로드된 상태로 실패하면 해당 파일들을 정리
      for (final reference in uploadedReferences) {
        try {
          await reference.delete();
        } catch (deleteError) {
          debugPrint(
            '업로드 실패 후 파일 정리 실패: $deleteError',
          );
        }
      }

      rethrow;
    }
  }

  Future<void> _generateSummary() async {
    if (_selectedFileNames.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('요약할 사진이나 파일을 먼저 선택해주세요.'),
        ),
      );

      return;
    }

    // 사용자가 하나의 자격증을 직접 지정한 경우
    if (_selectedCertificate != null) {
      await _openSummaryResultPage();
      return;
    }

    // 자격증별 분리 요약을 선택한 경우
    if (_isSplitSummarySelected) {
      await _openSummaryResultPage();
      return;
    }

    // 자격증을 판별하지 못한 경우
    if (_isCertificateUnknown) {
      await _showUnknownCertificateDialog();
      return;
    }

    // 파일 하나 또는 같은 자격증 자료로 판별된 경우
    if (_selectedFileNames.length == 1 || !_hasMixedCertificates) {
      await _openSummaryResultPage();
      return;
    }

    // 서로 다른 자격증 자료로 판별된 경우
    await _showMixedCertificateDialog();
  }

  void _saveSummaryNote() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('요약 노트 저장 기능은 추후 연결될 예정입니다.'),
      ),
    );
  }

  void _downloadSummaryNote() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('요약본 다운로드 기능은 추후 연결될 예정입니다.'),
      ),
    );
  }

  Future<void> _showMixedCertificateDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          titlePadding: const EdgeInsets.fromLTRB(
            22,
            24,
            22,
            0,
          ),
          contentPadding: const EdgeInsets.fromLTRB(
            22,
            18,
            22,
            20,
          ),
          actionsPadding: const EdgeInsets.fromLTRB(
            16,
            0,
            16,
            18,
          ),
          title: const Row(
            children: [
              _DialogWarningIcon(),

              SizedBox(width: 12),

              Expanded(
                child: Text(
                  '업로드 자료를 확인해주세요',
                  style: TextStyle(
                    color: Color(0xFF302C2E),
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '업로드한 자료가 서로 다른 자격증과 관련된 것으로 보여요.',
                style: TextStyle(
                  color: Color(0xFF4F494B),
                  fontSize: 15,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),

              SizedBox(height: 14),

              _DialogNoticeBox(),

              SizedBox(height: 16),

              Text(
                '자격증별로 자료를 나누어 요약하거나, '
                    '업로드한 모든 자료에 하나의 자격증을 직접 지정할 수 있어요.',
                style: TextStyle(
                  color: Color(0xFF817B7D),
                  fontSize: 14,
                  height: 1.55,
                ),
              ),
            ],
          ),
          actions: [
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(dialogContext);

                      setState(() {
                        _selectedCertificate = null;
                        _isSplitSummarySelected = true;
                        _isSummaryGenerated = false;
                      });
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFF4869D),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(17),
                      ),
                    ),
                    child: const Text(
                      '자격증별로 나누어 요약',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: () async {
                      Navigator.pop(dialogContext);

                      await _showCertificateSearchDialog();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFF4869D),
                      side: const BorderSide(
                        color: Color(0xFFF4869D),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(17),
                      ),
                    ),
                    child: const Text(
                      '하나의 자격증으로 지정',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 6),

                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text(
                    '파일 다시 확인하기',
                    style: TextStyle(
                      color: Color(0xFF8E8589),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _showCertificateSearchDialog() async {
    final selectedCertificate = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return _CertificateSearchDialog(
          certificates: _certificateOptions,
        );
      },
    );

    if (selectedCertificate == null || !mounted) {
      return;
    }

    setState(() {
      _selectedCertificate = selectedCertificate;
      _isSplitSummarySelected = false;
      _isSummaryGenerated = false;
    });
  }

  Future<void> _removeSelectedCertificate() async {
    setState(() {
      _selectedCertificate = null;
      _isSplitSummarySelected = false;
      _isSummaryGenerated = false;
    });

    // 자격증 확인 불가 상태였다면 확인 불가 팝업을 다시 표시
    if (_isCertificateUnknown) {
      await _showUnknownCertificateDialog();
      return;
    }

    // 서로 다른 자격증 자료 상태였다면 혼합 자료 팝업 표시
    if (_hasMixedCertificates) {
      await _showMixedCertificateDialog();
    }
  }

  Future<void> _showUnknownCertificateDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          titlePadding: const EdgeInsets.fromLTRB(
            22,
            24,
            22,
            0,
          ),
          contentPadding: const EdgeInsets.fromLTRB(
            22,
            18,
            22,
            20,
          ),
          actionsPadding: const EdgeInsets.fromLTRB(
            16,
            0,
            16,
            18,
          ),
          title: const Row(
            children: [
              _UnknownCertificateIcon(),

              SizedBox(width: 12),

              Expanded(
                child: Text(
                  '자격증을 확인하기 어려워요',
                  style: TextStyle(
                    color: Color(0xFF302C2E),
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '업로드한 자료만으로는 어떤 자격증과 관련된 자료인지 정확히 확인하기 어려워요.',
                style: TextStyle(
                  color: Color(0xFF4F494B),
                  fontSize: 15,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),

              SizedBox(height: 14),

              _UnknownCertificateNoticeBox(),

              SizedBox(height: 16),

              Text(
                '자료와 관련된 자격증을 검색해서 선택해주세요. '
                    '선택한 자격증은 업로드한 모든 자료에 공통으로 적용돼요.',
                style: TextStyle(
                  color: Color(0xFF817B7D),
                  fontSize: 14,
                  height: 1.55,
                ),
              ),
            ],
          ),
          actions: [
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: () async {
                      Navigator.pop(dialogContext);

                      await _showCertificateSearchDialog();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFF4869D),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(17),
                      ),
                    ),
                    icon: const Icon(
                      Icons.search_rounded,
                      size: 20,
                    ),
                    label: const Text(
                      '자격증 검색해서 선택',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 6),

                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text(
                    '파일 다시 확인하기',
                    style: TextStyle(
                      color: Color(0xFF8E8589),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _openSummaryResultPage() async {
    if (_isUploading) {
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('파일을 업로드하고 있습니다.'),
          duration: Duration(seconds: 1),
        ),
      );

      final uploadedPaths = await _uploadSelectedFiles();

      if (!mounted) return;

      setState(() {
        _uploadedStoragePaths
          ..clear()
          ..addAll(uploadedPaths);
      });

      debugPrint('Storage 업로드 완료');
      debugPrint('업로드된 경로: $_uploadedStoragePaths');

      final shouldReset = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => MaterialSummaryResultPage(
            selectedCertificate: _selectedCertificate,
            isSplitSummary: _isSplitSummarySelected,
            uploadedFileNames: List<String>.from(
              _selectedFileNames,
            ),
          ),
        ),
      );

      if (!mounted) return;

      if (shouldReset == true) {
        setState(() {
          _selectedFiles.clear();
          _selectedFileNames.clear();

          _selectedCertificate = null;
          _isSplitSummarySelected = false;
          _isSummaryGenerated = false;

          _hasMixedCertificates = true;
          _isCertificateUnknown = false;
        });
      }
    } on FirebaseException catch (error, stackTrace) {
      debugPrint('Firebase Storage 업로드 실패');
      debugPrint('오류 코드: ${error.code}');
      debugPrint('오류 내용: ${error.message}');
      debugPrint('$stackTrace');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message ?? '파일 업로드에 실패했습니다.',
          ),
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('파일 업로드 실패: $error');
      debugPrint('$stackTrace');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: const AppTopBar(
        title: '자료 요약',
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
                const _SummaryHeader(),

                const SizedBox(height: 30),

                const _SectionTitle(
                  title: '요약할 자료를 올려주세요',
                  description: 'JPG, PNG, PDF 파일만 업로드할 수 있어요.',
                ),

                const SizedBox(height: 16),

                if (_selectedFileNames.isEmpty)
                  _UploadArea(
                    onPressed: _selectFiles,
                  )
                else ...[
                  _SelectedFilesSection(
                    fileNames: _selectedFileNames,
                    onAddPressed: _selectFiles,
                    onRemovePressed: _removeFile,
                    onRemoveAllPressed: _removeAllFiles,
                  ),

                  if (_selectedCertificate != null) ...[
                    const SizedBox(height: 12),

                    _SelectedCertificateCard(
                      certificateName: _selectedCertificate!,
                      onRemovePressed: _removeSelectedCertificate,
                    ),
                  ],
                ],

                const SizedBox(height: 24),

                _GenerateSummaryButton(
                  isEnabled: _selectedFileNames.isNotEmpty,
                  onPressed: _generateSummary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        22,
        26,
        20,
        24,
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
      child: const Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '긴 학습 자료도\n핵심만 빠르게 확인해요',
                  style: TextStyle(
                    color: Color(0xFF302C2E),
                    fontSize: 22,
                    height: 1.35,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.7,
                  ),
                ),
                SizedBox(height: 11),
                Text(
                  '사진이나 파일을 올리면\n구름iT이 중요한 내용을 요약해드려요.',
                  style: TextStyle(
                    color: Color(0xFF817B7D),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 12),
          Icon(
            Icons.summarize_rounded,
            size: 74,
            color: Color(0xFFF4869D),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? description;

  const _SectionTitle({
    required this.title,
    this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF302C2E),
            fontSize: 21,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        if (description != null) ...[
          const SizedBox(height: 7),
          Text(
            description!,
            style: const TextStyle(
              color: Color(0xFF817B7D),
              fontSize: 14,
              height: 1.45,
            ),
          ),
        ],
      ],
    );
  }
}

class _UploadArea extends StatelessWidget {
  final VoidCallback onPressed;

  const _UploadArea({
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.88),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(
            minHeight: 220,
          ),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFFF2CBD5),
              width: 1.5,
            ),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _UploadIcon(),

              SizedBox(height: 18),

              Text(
                '사진 또는 파일 업로드',
                style: TextStyle(
                  color: Color(0xFF302C2E),
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),

              SizedBox(height: 8),

              Text(
                '눌러서 요약할 자료를 선택해주세요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF817B7D),
                  fontSize: 14,
                ),
              ),

              SizedBox(height: 12),

              _AllowedFileBadge(),
            ],
          ),
        ),
      ),
    );
  }
}

class _UploadIcon extends StatelessWidget {
  const _UploadIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: const BoxDecoration(
        color: Color(0xFFFFE6EC),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.cloud_upload_outlined,
        color: Color(0xFFF4869D),
        size: 36,
      ),
    );
  }
}

class _AllowedFileBadge extends StatelessWidget {
  const _AllowedFileBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 13,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F4),
        borderRadius: BorderRadius.circular(30),
      ),
      child: const Text(
        'JPG · PNG · PDF',
        style: TextStyle(
          color: Color(0xFFF4869D),
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SelectedFilesSection extends StatelessWidget {
  final List<String> fileNames;
  final VoidCallback onAddPressed;
  final ValueChanged<String> onRemovePressed;
  final VoidCallback onRemoveAllPressed;

  const _SelectedFilesSection({
    required this.fileNames,
    required this.onAddPressed,
    required this.onRemovePressed,
    required this.onRemoveAllPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFF1DDE2),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '선택된 파일',
                  style: TextStyle(
                    color: Color(0xFF302C2E),
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${fileNames.length}개',
                style: const TextStyle(
                  color: Color(0xFFF4869D),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: onRemoveAllPressed,
                child: const Text(
                  '전체 삭제',
                  style: TextStyle(
                    color: Color(0xFF9A9295),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          ...List.generate(
            fileNames.length,
                (index) {
              final fileName = fileNames[index];

              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == fileNames.length - 1 ? 0 : 10,
                ),
                child: _SelectedFileItem(
                  fileName: fileName,
                  onRemovePressed: () {
                    onRemovePressed(fileName);
                  },
                ),
              );
            },
          ),

          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton.icon(
              onPressed: onAddPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFF4869D),
                side: const BorderSide(
                  color: Color(0xFFF2CBD5),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(
                Icons.add_rounded,
                size: 20,
              ),
              label: const Text(
                '파일 추가하기',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedFileItem extends StatelessWidget {
  final String fileName;
  final VoidCallback onRemovePressed;

  const _SelectedFileItem({
    required this.fileName,
    required this.onRemovePressed,
  });

  IconData _getFileIcon() {
    final lowerFileName = fileName.toLowerCase();

    if (lowerFileName.endsWith('.pdf')) {
      return Icons.picture_as_pdf_outlined;
    }

    return Icons.image_outlined;
  }

  String _getFileType() {
    final parts = fileName.split('.');

    if (parts.length < 2) {
      return 'FILE';
    }

    return parts.last.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 11, 8, 11),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7F9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: const BoxDecoration(
              color: Color(0xFFFFE6EC),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              _getFileIcon(),
              color: const Color(0xFFF4869D),
              size: 23,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF302C2E),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  _getFileType(),
                  style: const TextStyle(
                    color: Color(0xFF9A9295),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          IconButton(
            onPressed: onRemovePressed,
            visualDensity: VisualDensity.compact,
            icon: const Icon(
              Icons.close_rounded,
              color: Color(0xFF9A9295),
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class _GenerateSummaryButton extends StatelessWidget {
  final bool isEnabled;
  final VoidCallback onPressed;

  const _GenerateSummaryButton({
    required this.isEnabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: FilledButton.icon(
        onPressed: isEnabled ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFF4869D),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFE2DADD),
          disabledForegroundColor: const Color(0xFFA49CA0),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(21),
          ),
        ),
        icon: const Icon(
          Icons.auto_awesome_rounded,
          size: 22,
        ),
        label: const Text(
          '요약 생성하기',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _SummaryResultCard extends StatelessWidget {
  const _SummaryResultCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        20,
        22,
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
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SummaryResultTitle(
            number: '1',
            title: '핵심 개념',
          ),

          SizedBox(height: 12),

          Text(
            '네트워크 계층은 서로 다른 네트워크 간에 데이터를 전달하며, '
                'IP 주소를 기반으로 최적의 경로를 선택합니다.',
            style: TextStyle(
              color: Color(0xFF595254),
              fontSize: 14,
              height: 1.65,
            ),
          ),

          SizedBox(height: 22),

          Divider(
            color: Color(0xFFF0E7E9),
            height: 1,
          ),

          SizedBox(height: 22),

          _SummaryResultTitle(
            number: '2',
            title: '주요 내용',
          ),

          SizedBox(height: 12),

          _SummaryBulletText(
            text: 'IP 주소를 사용하여 출발지와 목적지를 구분해요.',
          ),

          SizedBox(height: 9),

          _SummaryBulletText(
            text: '라우터가 패킷이 이동할 경로를 결정해요.',
          ),

          SizedBox(height: 9),

          _SummaryBulletText(
            text: '대표적인 프로토콜에는 IP, ICMP, ARP 등이 있어요.',
          ),

          SizedBox(height: 22),

          Divider(
            color: Color(0xFFF0E7E9),
            height: 1,
          ),

          SizedBox(height: 22),

          _SummaryResultTitle(
            number: '3',
            title: '시험 포인트',
          ),

          SizedBox(height: 12),

          Text(
            'OSI 7계층에서 네트워크 계층의 역할과 주요 장비인 '
                '라우터의 특징을 함께 정리해두는 것이 좋아요.',
            style: TextStyle(
              color: Color(0xFF595254),
              fontSize: 14,
              height: 1.65,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryResultTitle extends StatelessWidget {
  final String number;
  final String title;

  const _SummaryResultTitle({
    required this.number,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Color(0xFFFFE6EC),
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: const TextStyle(
              color: Color(0xFFF4869D),
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),

        const SizedBox(width: 10),

        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF302C2E),
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _SummaryBulletText extends StatelessWidget {
  final String text;

  const _SummaryBulletText({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 7),
          child: Icon(
            Icons.circle,
            size: 6,
            color: Color(0xFFF4869D),
          ),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF595254),
              fontSize: 14,
              height: 1.55,
            ),
          ),
        ),
      ],
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
                backgroundColor: Colors.white.withValues(alpha: 0.84),
                side: const BorderSide(
                  color: Color(0xFFF4869D),
                  width: 1.5,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8),
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
                padding: const EdgeInsets.symmetric(horizontal: 8),
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

class _DialogWarningIcon extends StatelessWidget {
  const _DialogWarningIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: const BoxDecoration(
        color: Color(0xFFFFEEF1),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.warning_amber_rounded,
        color: Color(0xFFF4869D),
        size: 24,
      ),
    );
  }
}

class _DialogNoticeBox extends StatelessWidget {
  const _DialogNoticeBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F7),
        borderRadius: BorderRadius.circular(15),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: Color(0xFFF4869D),
            size: 20,
          ),

          SizedBox(width: 9),

          Expanded(
            child: Text(
              '업로드한 자료가 같은 자격증과 관련된 자료가 아닐 경우, '
                  '내용이 섞여 정확한 요약본 생성이 어려울 수 있어요.',
              style: TextStyle(
                color: Color(0xFF6A6063),
                fontSize: 13,
                height: 1.55,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CertificateSearchDialog extends StatefulWidget {
  final List<String> certificates;

  const _CertificateSearchDialog({
    required this.certificates,
  });

  @override
  State<_CertificateSearchDialog> createState() =>
      _CertificateSearchDialogState();
}

class _CertificateSearchDialogState
    extends State<_CertificateSearchDialog> {
  final TextEditingController _searchController =
  TextEditingController();

  late List<String> _filteredCertificates;

  @override
  void initState() {
    super.initState();

    _filteredCertificates = widget.certificates;
  }

  @override
  void dispose() {
    _searchController.dispose();

    super.dispose();
  }

  void _searchCertificate(String keyword) {
    final normalizedKeyword = keyword.trim().toLowerCase();

    setState(() {
      if (normalizedKeyword.isEmpty) {
        _filteredCertificates = widget.certificates;

        return;
      }

      _filteredCertificates = widget.certificates
          .where(
            (certificate) => certificate
            .toLowerCase()
            .contains(normalizedKeyword),
      )
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 56,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 560,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                20,
                22,
                12,
                12,
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '자격증 선택',
                      style: TextStyle(
                        color: Color(0xFF302C2E),
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),

                  IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFF8E8589),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _searchCertificate,
                decoration: InputDecoration(
                  hintText: '자격증 이름을 검색해주세요',
                  hintStyle: const TextStyle(
                    color: Color(0xFFA29A9D),
                    fontSize: 14,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: Color(0xFFF4869D),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFFFF7F9),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 15,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(17),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            Expanded(
              child: _filteredCertificates.isEmpty
                  ? const Center(
                child: Text(
                  '검색 결과가 없습니다.',
                  style: TextStyle(
                    color: Color(0xFF817B7D),
                    fontSize: 14,
                  ),
                ),
              )
                  : ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  12,
                  0,
                  12,
                  16,
                ),
                itemCount: _filteredCertificates.length,
                separatorBuilder: (_, __) {
                  return const Divider(
                    height: 1,
                    color: Color(0xFFF1E8EB),
                  );
                },
                itemBuilder: (context, index) {
                  final certificate =
                  _filteredCertificates[index];

                  return ListTile(
                    onTap: () {
                      Navigator.pop(
                        context,
                        certificate,
                      );
                    },
                    contentPadding:
                    const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    leading: Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFE9EE),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.workspace_premium_outlined,
                        color: Color(0xFFF4869D),
                        size: 22,
                      ),
                    ),
                    title: Text(
                      certificate,
                      style: const TextStyle(
                        color: Color(0xFF302C2E),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFFF4869D),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedCertificateCard extends StatelessWidget {
  final String certificateName;
  final VoidCallback onRemovePressed;

  const _SelectedCertificateCard({
    required this.certificateName,
    required this.onRemovePressed,
  });



  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        16,
        14,
        8,
        14,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F4),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.workspace_premium_outlined,
            color: Color(0xFFF4869D),
            size: 22,
          ),

          const SizedBox(width: 11),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '모든 자료에 적용할 자격증',
                  style: TextStyle(
                    color: Color(0xFF817B7D),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  certificateName,
                  style: const TextStyle(
                    color: Color(0xFF302C2E),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),

          IconButton(
            onPressed: onRemovePressed,
            tooltip: '자격증 지정 취소',
            icon: const Icon(
              Icons.close_rounded,
              color: Color(0xFFF4869D),
              size: 21,
            ),
          ),
        ],
      ),
    );
  }
}

class _UnknownCertificateIcon extends StatelessWidget {
  const _UnknownCertificateIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: const BoxDecoration(
        color: Color(0xFFFFEEF1),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.help_outline_rounded,
        color: Color(0xFFF4869D),
        size: 24,
      ),
    );
  }
}

class _UnknownCertificateNoticeBox extends StatelessWidget {
  const _UnknownCertificateNoticeBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F7),
        borderRadius: BorderRadius.circular(15),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: Color(0xFFF4869D),
            size: 20,
          ),

          SizedBox(width: 9),

          Expanded(
            child: Text(
              '자격증을 지정하지 않으면 시험 범위와 핵심 출제 내용을 기준으로 '
                  '정확한 요약본을 생성하기 어려울 수 있어요.',
              style: TextStyle(
                color: Color(0xFF6A6063),
                fontSize: 13,
                height: 1.55,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}