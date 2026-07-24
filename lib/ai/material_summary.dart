import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../widgets/app_main_background.dart';
import '../widgets/app_top_bar.dart';
import 'widgets/wave_loading_indicator.dart';
import 'material_summary_result.dart';
import 'services/question_generation_api_service.dart';
import 'dart:async';

class MaterialSummaryPage extends StatefulWidget {
  const MaterialSummaryPage({super.key});

  @override
  State<MaterialSummaryPage> createState() => _MaterialSummaryPageState();
}

class _MaterialSummaryPageState extends State<MaterialSummaryPage>
    with SingleTickerProviderStateMixin {
  static const Color _textColor = Color(0xFF302C2E);
  static const Color _subTextColor = Color(0xFF8E8589);
  static const Color _pinkColor = Color(0xFFF4869D);
  static const Color _pinkSoft = Color(0xFFFFE4EA);
  static const Color _pinkAccent = Color(0xFFFF8FA3);

  static const int _maxFileCount = 5;


  final PageController _pageController = PageController();
  int _currentStep = 0;


  static const List<String> _summaryMessages = [
    '구름iT이 자료를 분석하고 있어요',
    '업로드한 자료를 읽고 있어요',
    '핵심 내용을 정리하고 있어요',
    '요약을 만들고 있어요',
    '거의 다 됐어요',
    '이제 보여드릴게요',
  ];
  static const List<int> _summaryDurations = [2800, 3200, 3200, 3600, 2200, 900];


  late final AnimationController _loadingController;

  // 실제 선택된 파일 정보
  final List<PlatformFile> _selectedFiles = [];

  // 화면에 표시할 파일명
  final List<String> _selectedFileNames = [];

  // Storage에 업로드된 파일 URL
  final List<String> _uploadedStoragePaths = [];

  // 중복 업로드 방지
  bool _isUploading = false;

  // AI가 확인해준 자격증 이름
  String? _selectedCertificate;

  // 자격증 이름 입력/확인 관련 상태
  final TextEditingController _certNameController = TextEditingController();
  bool _isCheckingCertificate = false;
  String? _certificateCheckError;

  @override
  void initState() {
    super.initState();
    _loadingController = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _certNameController.dispose();
    _loadingController.dispose();
    super.dispose();
  }

  void _goToStep(int step) {
    setState(() => _currentStep = step);
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  /// 입력한 자격증 이름을 AI로 확인
  Future<void> _checkCertificate() async {
    if (_isCheckingCertificate) return;

    final name = _certNameController.text.trim();
    if (name.isEmpty) {
      setState(() => _certificateCheckError = '자격증 이름을 입력해주세요.');
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isCheckingCertificate = true;
      _certificateCheckError = null;
    });

    _loadingController.value = 0;
    _loadingController.duration = const Duration(milliseconds: 1500);
    _loadingController.animateTo(0.9, curve: Curves.easeOut);

    try {
      final certification =
      await QuestionGenerationApiService.fetchCertificateStructure(name);

      await _loadingController.animateTo(
        1.0,
        duration: const Duration(milliseconds: 200),
      );
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;

      setState(() {
        _isCheckingCertificate = false;
        _selectedCertificate = certification.name;
      });

      _goToStep(1);
    } catch (e) {
      debugPrint('자격증 확인 에러: $e');
      _loadingController.stop();
      if (!mounted) return;
      setState(() {
        _isCheckingCertificate = false;
        _certificateCheckError = '자격증 정보를 확인하지 못했어요. 이름을 확인하고 다시 시도해주세요.';
      });
    }
  }

  void _removeSelectedCertificate() {
    setState(() {
      _selectedCertificate = null;
      _certNameController.clear();
      _certificateCheckError = null;

      // 자격증을 변경하면 기존 파일도 다시 선택하도록 초기화
      _selectedFiles.clear();
      _selectedFileNames.clear();
      _uploadedStoragePaths.clear();
    });
    _goToStep(0);
  }

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
        _showMessage('이미 추가된 파일입니다.');
        return;
      }

      final remainingFileCount = _maxFileCount - _selectedFiles.length;

      if (remainingFileCount <= 0) {
        _showMessage('파일은 최대 5개까지 등록할 수 있습니다.');
        return;
      }

      final filesToAdd = newFiles.take(remainingFileCount).toList();

      setState(() {
        _selectedFiles.addAll(filesToAdd);
        _selectedFileNames.addAll(filesToAdd.map((file) => file.name));

        // 파일 목록이 바뀌면 이전 업로드 결과는 무효화
        _uploadedStoragePaths.clear();
      });

      if (newFiles.length > remainingFileCount) {
        _showMessage(
          '파일은 최대 5개까지 등록할 수 있어 ${filesToAdd.length}개만 추가했습니다.',
        );
      } else {
        _showMessage('${filesToAdd.length}개 파일을 추가했습니다.');
      }
    } catch (error, stackTrace) {
      debugPrint('파일 선택 실패: $error');
      debugPrint('$stackTrace');

      if (!mounted) return;
      _showMessage('파일을 불러오지 못했습니다. 다시 시도해주세요.');
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
    });
  }

  void _removeAllFiles() {
    setState(() {
      _selectedFiles.clear();
      _selectedFileNames.clear();
      _uploadedStoragePaths.clear();
    });
  }

  String _getContentType(String fileName) {
    final lowerFileName = fileName.toLowerCase();

    if (lowerFileName.endsWith('.jpg') || lowerFileName.endsWith('.jpeg')) {
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

    final uploadId = DateTime.now().millisecondsSinceEpoch.toString();

    final uploadedPaths = <String>[];
    final uploadedReferences = <Reference>[];

    try {
      for (var index = 0; index < _selectedFiles.length; index++) {
        final selectedFile = _selectedFiles[index];
        final localPath = selectedFile.path;

        if (localPath == null || localPath.isEmpty) {
          throw Exception('${selectedFile.name} 파일 경로를 불러올 수 없습니다.');
        }

        final extension = selectedFile.extension?.toLowerCase() ?? 'file';

        final storageFileName =
            '${DateTime.now().microsecondsSinceEpoch}_$index.$extension';

        final storageReference = FirebaseStorage.instance.ref().child(
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

        await storageReference.putFile(File(localPath), metadata);

        final downloadUrl = await storageReference.getDownloadURL();

        uploadedReferences.add(storageReference);
        uploadedPaths.add(downloadUrl);
      }

      return uploadedPaths;
    } catch (error) {
      // 일부 파일만 업로드된 상태로 실패하면 해당 파일들을 정리
      for (final reference in uploadedReferences) {
        try {
          await reference.delete();
        } catch (deleteError) {
          debugPrint('업로드 실패 후 파일 정리 실패: $deleteError');
        }
      }

      rethrow;
    }
  }

  Future<void> _generateSummary() async {
    if (_selectedCertificate == null) {
      _goToStep(0);
      return;
    }

    if (_selectedFileNames.isEmpty) {
      _showMessage('요약할 사진이나 파일을 먼저 선택해주세요.');
      return;
    }

    await _openSummaryResultPage();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openSummaryResultPage() async {
    if (_isUploading) {
      return;
    }

    setState(() => _isUploading = true);

    try {
      final uploadedPaths = await _uploadSelectedFiles();

      if (!mounted) return;

      setState(() {
        _uploadedStoragePaths
          ..clear()
          ..addAll(uploadedPaths);
      });

      debugPrint('Storage 업로드 완료');
      debugPrint('업로드된 경로: $_uploadedStoragePaths');

      // 업로드가 끝난 같은 로딩 화면 안에서 요약까지 미리 받아온다.
      // 결과 페이지에서 또 로딩이 뜨지 않도록, 완성된 데이터를 그대로 들고 이동한다.
      final summaryResult = await QuestionGenerationApiService.summarizeMaterial(
        fileUrls: uploadedPaths,
        selectedCertificate: _selectedCertificate ?? '',
      );

      debugPrint('summarizeMaterial 응답(업로드 화면): $summaryResult');

      if (!mounted) return;

      final shouldReset = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => MaterialSummaryResultPage(
            selectedCertificate: _selectedCertificate,
            isSplitSummary: false,
            uploadedFileNames: List<String>.from(_selectedFileNames),
            uploadedFileUrls: List<String>.from(_uploadedStoragePaths),
            initialResult: summaryResult,
          ),
        ),
      );

      if (!mounted) return;

      if (shouldReset == true) {
        // "다른 자료 요약하기" / "자료 다시 확인할게요" 로 돌아온 경우:
        // 선택했던 자격증은 그대로 유지하고, 파일만 비운 뒤
        // 자격증 입력 단계(스텝1)가 아니라 자료 업로드 단계(스텝2)로 바로 이동한다.
        setState(() {
          _selectedFiles.clear();
          _selectedFileNames.clear();
          _uploadedStoragePaths.clear();
        });
        _goToStep(1);
      }
    } on FirebaseException catch (error, stackTrace) {
      debugPrint('Firebase Storage 업로드 실패');
      debugPrint('오류 코드: ${error.code}');
      debugPrint('오류 내용: ${error.message}');
      debugPrint('$stackTrace');

      if (!mounted) return;
      _showMessage(error.message ?? '파일 업로드에 실패했습니다.');
    } catch (error, stackTrace) {
      debugPrint('파일 업로드/요약 실패: $error');
      debugPrint('$stackTrace');

      if (!mounted) return;
      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppTopBar(
        title: 'AI 자료 요약',
        centerTitle: false,
        leading: _currentStep == 1
            ? IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: _isUploading ? null : () => _goToStep(0),
        )
            : null,
      ),
      body: AppMainBackground(
        child: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  _StepProgressBar(currentStep: _currentStep),
                  const SizedBox(height: 8),
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      onPageChanged: (i) => setState(() => _currentStep = i),
                      children: [
                        _buildStep1(),
                        _buildStep2(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_isUploading)
              Positioned.fill(
                child: Container(
                  color: Colors.white.withValues(alpha: 0.92),
                  child: Align(
                    alignment: const Alignment(0, -0.15),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _RotatingLoadingContent(
                        messages: _summaryMessages,
                        durations: _summaryDurations,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return Align(
      alignment: const Alignment(0, -0.15),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween(begin: const Offset(0, 0.03), end: Offset.zero)
                      .animate(anim),
                  child: child,
                ),
              ),
              child: KeyedSubtree(
                key: ValueKey(_isCheckingCertificate ? 'loading' : 'idle'),
                child: _isCheckingCertificate
                    ? _buildLoadingContent()
                    : _buildIdleContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIdleContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _FadeSlideIn(
          delay: Duration.zero,
          duration: const Duration(milliseconds: 600),
          child: const _SectionTitle(
            title: '어떤 자격증 자료인가요?',
            description: '요약할 자료의 자격증 이름을 입력하면 AI가 확인해드려요.',
          ),
        ),
        const SizedBox(height: 16),
        _FadeSlideIn(
          delay: const Duration(milliseconds: 300),
          duration: const Duration(milliseconds: 700),
          child: _buildCertInput(),
        ),
        if (_certificateCheckError != null) ...[
          const SizedBox(height: 14),
          _InlineMessage(text: _certificateCheckError!),
        ],
      ],
    );
  }

  Widget _buildLoadingContent() {
    final name = _certNameController.text.trim();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'AI가 자격증을 확인하고 있어요',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _textColor,
            fontSize: 21,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$name 자격증 정보를 확인하고 있어요.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _subTextColor,
            fontSize: 13.5,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 30),
        _LoadingIndicator(progress: _loadingController),
      ],
    );
  }

  Widget _buildCertInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: _certificateCheckError != null
              ? const Color(0xFFE96B7A)
              : _pinkSoft,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14C98198),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: TextField(
        controller: _certNameController,
        onSubmitted: (_) => _checkCertificate(),
        onChanged: (_) {
          if (_certificateCheckError != null) {
            setState(() => _certificateCheckError = null);
          }
        },
        style: const TextStyle(
          color: _textColor,
          fontSize: 15.5,
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          hintText: '예: 정보처리기사, SQLD, ADsP',
          hintStyle: const TextStyle(color: Color(0xFFB7AFB1), fontSize: 15),
          prefixIcon: Padding(
            padding: const EdgeInsets.all(12),
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [_pinkColor, _pinkAccent]),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.workspace_premium_outlined,
                color: Colors.white,
                size: 19,
              ),
            ),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          suffixIcon: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_pinkColor, _pinkAccent]),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: _pinkColor.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _isCheckingCertificate ? null : _checkCertificate,
                  child: _isCheckingCertificate
                      ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.2,
                      ),
                    ),
                  )
                      : const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(
                      Icons.search_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
          ),
          contentPadding: const EdgeInsets.fromLTRB(6, 17, 6, 17),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_selectedCertificate != null)
            _SelectedCertificateCard(
              certificateName: _selectedCertificate!,
              onRemovePressed: _isUploading ? () {} : _removeSelectedCertificate,
            ),
          const SizedBox(height: 28),
          const _SectionTitle(
            title: '요약할 자료를 올려주세요',
            description: 'JPG, PNG, PDF 파일만 업로드할 수 있어요.',
          ),
          const SizedBox(height: 16),
          if (_selectedFileNames.isEmpty)
            _UploadArea(onPressed: _selectFiles)
          else
            _SelectedFilesSection(
              fileNames: _selectedFileNames,
              canAddFile: _selectedFileNames.length < _maxFileCount,
              onAddPressed: _selectFiles,
              onRemovePressed: _removeFile,
              onRemoveAllPressed: _removeAllFiles,
            ),
          const SizedBox(height: 24),
          _GenerateSummaryButton(
            isEnabled: _selectedFileNames.isNotEmpty && !_isUploading,
            isLoading: _isUploading,
            onPressed: _generateSummary,
          ),
        ],
      ),
    );
  }
}

class _StepProgressBar extends StatelessWidget {
  final int currentStep;
  const _StepProgressBar({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(2, (i) {
        final active = i == currentStep;
        final done = i < currentStep;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 28 : 18,
          height: 5,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: (active || done)
                ? const LinearGradient(colors: [
              _MaterialSummaryPageState._pinkColor,
              _MaterialSummaryPageState._pinkAccent,
            ])
                : null,
            color: (active || done) ? null : _MaterialSummaryPageState._pinkSoft,
          ),
        );
      }),
    );
  }
}

class _LoadingIndicator extends StatelessWidget {
  final Animation<double> progress;
  const _LoadingIndicator({required this.progress});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progress,
      builder: (context, _) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          WaveLoadingIndicator(
            size: 72,
            progress: progress.value,
            backgroundColor: const Color(0xFFFFF3F5),
            waveColorStart: _MaterialSummaryPageState._pinkColor,
            waveColorEnd: _MaterialSummaryPageState._pinkAccent,
          ),
          const SizedBox(height: 12),
          Text(
            '${(progress.value * 100).toInt()}%',
            style: const TextStyle(
              color: _MaterialSummaryPageState._pinkColor,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineMessage extends StatelessWidget {
  final String text;
  const _InlineMessage({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _MaterialSummaryPageState._pinkSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFBDDE3)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: _MaterialSummaryPageState._subTextColor,
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? description;

  const _SectionTitle({required this.title, this.description});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _MaterialSummaryPageState._textColor,
            fontSize: 21,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        if (description != null) ...[
          const SizedBox(height: 7),
          Text(
            description!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _MaterialSummaryPageState._subTextColor,
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

  const _UploadArea({required this.onPressed});

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
          constraints: const BoxConstraints(minHeight: 220),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _MaterialSummaryPageState._pinkSoft,
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const _UploadIcon(),
              const SizedBox(height: 18),
              const Text(
                '사진 또는 파일 업로드',
                style: TextStyle(
                  color: _MaterialSummaryPageState._textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '눌러서 요약할 자료를 선택해주세요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _MaterialSummaryPageState._subTextColor,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              const _AllowedFileBadge(),
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
        color: _MaterialSummaryPageState._pinkSoft,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.cloud_upload_outlined,
        color: _MaterialSummaryPageState._pinkColor,
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
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3F5),
        borderRadius: BorderRadius.circular(30),
      ),
      child: const Text(
        'JPG · PNG · PDF',
        style: TextStyle(
          color: _MaterialSummaryPageState._pinkColor,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SelectedFilesSection extends StatelessWidget {
  final List<String> fileNames;
  final bool canAddFile;
  final VoidCallback onAddPressed;
  final ValueChanged<String> onRemovePressed;
  final VoidCallback onRemoveAllPressed;

  const _SelectedFilesSection({
    required this.fileNames,
    required this.canAddFile,
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
        border: Border.all(color: const Color(0xFFF1DDE2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '선택된 파일',
                  style: TextStyle(
                    color: _MaterialSummaryPageState._textColor,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${fileNames.length}개',
                style: const TextStyle(
                  color: _MaterialSummaryPageState._pinkColor,
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
                    color: _MaterialSummaryPageState._subTextColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...List.generate(fileNames.length, (index) {
            final fileName = fileNames[index];
            return Padding(
              padding: EdgeInsets.only(bottom: index == fileNames.length - 1 ? 0 : 10),
              child: _SelectedFileItem(
                fileName: fileName,
                onRemovePressed: () => onRemovePressed(fileName),
              ),
            );
          }),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton.icon(
              onPressed: canAddFile ? onAddPressed : null,
              style: OutlinedButton.styleFrom(
                foregroundColor: _MaterialSummaryPageState._pinkColor,
                side: const BorderSide(color: _MaterialSummaryPageState._pinkSoft),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: Text(
                canAddFile ? '파일 추가하기' : '최대 5개까지 등록 가능',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
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

  const _SelectedFileItem({required this.fileName, required this.onRemovePressed});

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
        color: const Color(0xFFFFF3F5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: const BoxDecoration(
              color: _MaterialSummaryPageState._pinkSoft,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              _getFileIcon(),
              color: _MaterialSummaryPageState._pinkColor,
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
                    color: _MaterialSummaryPageState._textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getFileType(),
                  style: const TextStyle(
                    color: _MaterialSummaryPageState._subTextColor,
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
              color: _MaterialSummaryPageState._subTextColor,
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
  final bool isLoading;
  final VoidCallback onPressed;

  const _GenerateSummaryButton({
    required this.isEnabled,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: isEnabled
              ? const LinearGradient(colors: [
            _MaterialSummaryPageState._pinkColor,
            _MaterialSummaryPageState._pinkAccent,
          ])
              : null,
          color: isEnabled ? null : const Color(0xFFE2DADD),
          boxShadow: isEnabled
              ? [
            BoxShadow(
              color: _MaterialSummaryPageState._pinkColor.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: isEnabled ? onPressed : null,
            child: Center(
              child: isLoading
                  ? const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
                  ),
                  SizedBox(width: 10),
                  Text(
                    '준비 중...',
                    style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                ],
              )
                  : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    color: isEnabled ? Colors.white : _MaterialSummaryPageState._subTextColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '요약 생성하기',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: isEnabled ? Colors.white : _MaterialSummaryPageState._subTextColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
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
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3F5),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.workspace_premium_outlined,
            color: _MaterialSummaryPageState._pinkColor,
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
                    color: _MaterialSummaryPageState._subTextColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  certificateName,
                  style: const TextStyle(
                    color: _MaterialSummaryPageState._textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemovePressed,
            tooltip: '자격증 다시 선택',
            icon: const Icon(
              Icons.close_rounded,
              color: _MaterialSummaryPageState._pinkColor,
              size: 21,
            ),
          ),
        ],
      ),
    );
  }
}

class _FadeSlideIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  const _FadeSlideIn({
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 380),
    required this.child,
  });

  @override
  State<_FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<_FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade =
  CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
  late final Animation<Offset> _slide =
  Tween(begin: const Offset(0, 0.06), end: Offset.zero)
      .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}


class _RotatingLoadingContent extends StatefulWidget {
  final List<String> messages;
  final List<int> durations;

  const _RotatingLoadingContent({
    required this.messages,
    required this.durations,
  });

  @override
  State<_RotatingLoadingContent> createState() => _RotatingLoadingContentState();
}

class _RotatingLoadingContentState extends State<_RotatingLoadingContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotationController;
  Timer? _messageTimer;
  int _messageIndex = 0;

  @override
  void initState() {
    super.initState();
    _rotationController =
    AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat();
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
          backgroundColor: const Color(0xFFFFF3F5),
          waveColorStart: _MaterialSummaryPageState._pinkColor,
          waveColorEnd: _MaterialSummaryPageState._pinkAccent,
        ),
        const SizedBox(height: 26),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween(begin: const Offset(0, 0.15), end: Offset.zero).animate(anim),
              child: child,
            ),
          ),
          child: Text(
            widget.messages[_messageIndex],
            key: ValueKey(_messageIndex),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _MaterialSummaryPageState._textColor,
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}