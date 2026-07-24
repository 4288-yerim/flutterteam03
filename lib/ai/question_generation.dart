import 'package:flutter/material.dart';
import 'quiz_session_page.dart';
import 'package:file_picker/file_picker.dart';
import '../widgets/app_main_background.dart';
import '../widgets/app_top_bar.dart';
import 'widgets/wave_loading_indicator.dart';
import 'services/question_generation_api_service.dart';
import 'dart:async';

class QuestionGenerationPage extends StatefulWidget {
  const QuestionGenerationPage({super.key});

  @override
  State<QuestionGenerationPage> createState() =>
      _QuestionGenerationPageState();
}

class _QuestionGenerationPageState extends State<QuestionGenerationPage>
    with SingleTickerProviderStateMixin {
  static const Color _textColor = Color(0xFF302C2E);
  static const Color _subTextColor = Color(0xFF8E8589);
  static const Color _pinkColor = Color(0xFFF4869D);
  static const Color _pinkSoft = Color(0xFFFFE4EA);
  static const Color _pinkAccent = Color(0xFFFF8FA3);

  static const List<String> _pdfMessages = [
    '구름iT이 자료를 분석하고 있어요',
    'PDF 내용을 꼼꼼히 읽고 있어요',
    '핵심 내용을 정리하고 있어요',
    '문제를 만들고 있어요',
    '거의 다 됐어요',
    '이제 보여드릴게요',
  ];
  static const List<int> _pdfDurations = [2800, 3200, 3200, 3600, 2200, 900];

  static const List<String> _genMessages = [
    'AI가 자격증 정보를 분석하고 있어요',
    '출제 경향을 파악하고 있어요',
    '문제를 만들고 있어요',
    '보기와 정답을 정리하고 있어요',
    '거의 다 됐어요',
    '이제 보여드릴게요',
  ];
  static const List<int> _genDurations = [2800, 3200, 3600, 3200, 2200, 900];

  static const List<String> _wrongAnswerMessages = [
    '오답 기록을 분석하고 있어요',
    '틀렸던 개념을 정리하고 있어요',
    '유사 문제를 만들고 있어요',
    '보기와 정답을 정리하고 있어요',
    '거의 다 됐어요',
    '이제 보여드릴게요',
  ];
  static const List<int> _wrongAnswerDurations = [2800, 3200, 3600, 3200, 2200, 900];

  final PageController _pageController = PageController();
  int _currentStep = 0;

  late final AnimationController _loadingController;

  final TextEditingController _certNameController = TextEditingController();

  bool _isLoadingStructure = false;
  bool _isGenerating = false;
  bool _cancelled = false;
  bool _isPickingPdf = false;
  bool _isProcessingPdf = false;
  String? _structureError;
  CertificationData? _certification;

  ExamType? _selectedExamType;
  String? _selectedSubject;

  QuestionGenerationType _selectedGenerationType =
      QuestionGenerationType.general;

  AnswerCheckMode _checkMode = AnswerCheckMode.immediate;
  int _generatedCount = 0;

  List<String> get _currentSubjects {
    final certification = _certification;

    if (certification == null) {
      return [];
    }

    switch (_selectedExamType) {
      case ExamType.written:
        return certification.writtenSubjects;

      case ExamType.practical:
        return certification.practicalSubjects;

      case ExamType.integrated:
        return certification.integratedSubjects;

      case null:
        return [];
    }
  }

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

  /// 입력한 자격증 이름으로 Gemini에게 시험 구조(필기/실기/과목)를 조회
  Future<void> _fetchCertificateStructure() async {
    if (_isLoadingStructure) return;

    final name = _certNameController.text.trim();
    if (name.isEmpty) {
      setState(() => _structureError = '자격증 이름을 입력해주세요.');
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoadingStructure = true;
      _structureError = null;
      _certification = null;
      _selectedExamType = null;
      _selectedSubject = null;
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
        _certification = certification;
        _isLoadingStructure = false;
        _selectedSubject = '전체';

        // 기본 시험 유형 결정
        if (certification.isIntegrated) {
          _selectedExamType = ExamType.integrated;
        } else if (certification.hasWritten) {
          _selectedExamType = ExamType.written;
        } else if (certification.hasPractical) {
          _selectedExamType = ExamType.practical;
        }
      });

      _goToStep(1);
    } catch (e) {
      // 실제 원인을 콘솔에서 확인할 수 있도록 로그를 남긴다.
      // (예: functions/not-found → 함수 미배포, unauthenticated → 인증 문제 등)
      debugPrint('자격증 구조 조회 에러: $e');
      _loadingController.stop();
      if (!mounted) return;
      setState(() {
        _isLoadingStructure = false;
        _structureError = '자격증 정보를 불러오지 못했어요. 이름을 확인하고 다시 시도해주세요.';
      });
    }
  }
  void _selectExamType(ExamType examType) {
    setState(() {
      _selectedExamType = examType;
      _selectedSubject = '전체';
    });
  }

  Future<void> _onGeneratePressed() async {
    // 자료 기반 생성을 선택했으면 PDF 피커 플로우로 바로 이동
    if (_selectedGenerationType == QuestionGenerationType.document) {
      await _pickAndProcessPdf();
      return;
    }

    final certification = _certification;

    if (certification == null) {
      _showMessage('자격증을 먼저 조회해주세요.');
      return;
    }
    if (_selectedExamType == null) {
      _showMessage('시험 유형을 선택해주세요.');
      return;
    }

    setState(() {
      _isGenerating = true;
      _generatedCount = 0;
    });

    final stopwatch = Stopwatch()..start();

    try {
      final List<GeneratedQuestion> questions;
      final QuizSourceType sourceType;
      final String examTypeLabel;
      if (_selectedGenerationType == QuestionGenerationType.wrongAnswer) {
        sourceType = QuizSourceType.wrongAnswerReview;
        examTypeLabel = '오답 기반';
        questions = await QuestionGenerationApiService
            .generateQuestionsFromWrongAnswers(
          certificationName: certification.name,
          count: 20,
        );
        if (mounted) setState(() => _generatedCount = 20);
      } else {
        sourceType = QuizSourceType.certification;
        examTypeLabel = _selectedExamType!.label;
        questions = await QuestionGenerationApiService.generateQuestionBatch(
          certificationName: certification.name,
          examType: _selectedExamType!.label,
          subject: _selectedSubject == '전체' ? null : _selectedSubject,
          count: 20,
          onProgress: (done, total) {
            if (mounted) setState(() => _generatedCount = done);
          },
        );
      }

      if (!mounted) return;
      if (_cancelled) return;

      stopwatch.stop();

      final durations = _selectedGenerationType == QuestionGenerationType.wrongAnswer
          ? _wrongAnswerDurations
          : _genDurations;
      final minDuration = _minLoadingDuration(durations);
      if (stopwatch.elapsed < minDuration) {
        await Future.delayed(minDuration - stopwatch.elapsed);
      }
      if (!mounted) return;
      if (_cancelled) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => QuizSessionPage(
            sourceType: sourceType,
            certificationName: certification.name,
            pdfFileName: null,
            examType: examTypeLabel,
            subject: _selectedSubject,
            questions: questions,
            checkMode: _checkMode,
            generationDurationSeconds: stopwatch.elapsed.inSeconds,
          ),
        ),
      );
    } catch (e) {
      debugPrint('문제 생성 에러: $e');
      if (!mounted) return;
      if (_selectedGenerationType == QuestionGenerationType.wrongAnswer &&
          e.toString().contains('오답 기록이 없어요')) {
        _showNoWrongAnswerDialog(certification.name);
      } else {
        _showMessage('문제 생성에 실패했어요. 잠시 후 다시 시도해주세요.');
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }
  Duration _minLoadingDuration(List<int> durations) {
    final sum = durations.fold<int>(0, (a, b) => a + b);
    return Duration(milliseconds: sum + 900 + 500);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showNoWrongAnswerDialog(String certificationName) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: _pinkColor.withValues(alpha: 0.18),
                blurRadius: 30,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [_pinkColor, _pinkAccent]),
                ),
                child: const Icon(
                  Icons.info_outline_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                '아직 오답 기록이 없어요',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '$certificationName에 대한 오답 기록이 아직 없어요.\n'
                    '기본 문제를 먼저 풀어보면 오답 기반 문제를\n만들어드릴 수 있어요!',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _subTextColor,
                  fontSize: 13.5,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(colors: [_pinkColor, _pinkAccent]),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => Navigator.pop(context),
                      child: const Center(
                        child: Text(
                          '확인',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
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
  Future<void> _onPdfShortcutPressed() async {
    if (_isPickingPdf || _isGenerating) return;
    await _pickAndProcessPdf();
  }

  /// PDF 선택 -> 텍스트 추출 -> 문제 생성까지의 전체 흐름.
  /// 상단 바로가기 버튼과, 2단계의 "자료 기반 문제 생성" 카드 양쪽에서 공용으로 쓴다.
  Future<void> _pickAndProcessPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final picked = result.files.single;
    setState(() => _isPickingPdf = true);

    try {
      setState(() {
        _isGenerating = true;
        _isProcessingPdf = true;
        _generatedCount = 0;
        _cancelled = false;
      });

      final stopwatch = Stopwatch()..start();

      final questions = await QuestionGenerationApiService.generateQuestionsFromDocument(
        file: picked,
        count: 20,
        onProgress: (done, total) {
          if (mounted) setState(() => _generatedCount = done);
        },
      );

      stopwatch.stop();

      if (!mounted) return;
      if (_cancelled) return;

      final minDuration = _minLoadingDuration(_pdfDurations);
      if (stopwatch.elapsed < minDuration) {
        await Future.delayed(minDuration - stopwatch.elapsed);
      }
      if (!mounted) return;
      if (_cancelled) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => QuizSessionPage(
            sourceType: QuizSourceType.document,
            certificationName: null,
            pdfFileName: _stripPdfExtension(picked.name),
            examType: '자료 기반',
            subject: null,
            questions: questions,
            checkMode: _checkMode,
            generationDurationSeconds: stopwatch.elapsed.inSeconds,
          ),
        ),
      );
    } catch (e) {
      debugPrint('PDF 문제 생성 에러: $e');
      if (!mounted) return;
      _showMessage('PDF에서 문제를 생성하지 못했어요. 파일을 확인하고 다시 시도해주세요.');
    } finally {
      if (mounted) {
        setState(() {
          _isPickingPdf = false;
          _isGenerating = false;
          _isProcessingPdf = false;
        });
      }
    }
  }

  void _confirmCancelGeneration() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: _pinkColor.withValues(alpha: 0.18),
                blurRadius: 30,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [_pinkColor, _pinkAccent]),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                '문제를 생성 중이에요!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '지금 나가면 생성 중인 문제가 취소돼요.\n그래도 나가시겠어요?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _subTextColor,
                  fontSize: 13.5,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: Material(
                        color: const Color(0xFFF6F1F2),
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => Navigator.pop(context),
                          child: const Center(
                            child: Text(
                              '계속 생성',
                              style: TextStyle(
                                color: _textColor,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(colors: [_pinkColor, _pinkAccent]),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              setState(() {
                                _isGenerating = false;
                                _cancelled = true;
                              });
                              Navigator.pop(context); // 다이얼로그 닫기
                              Navigator.pop(context); // 실제 뒤로가기
                            },
                            child: const Center(
                              child: Text(
                                '나가기',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isGenerating,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _confirmCancelGeneration();
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: Colors.transparent,
        appBar: AppTopBar(
          title: 'AI 문제 생성',
          centerTitle: false,
          leading: _currentStep == 1
              ? IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            onPressed: _isGenerating ? null : () => _goToStep(0),
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
              if (_isGenerating &&
                  _selectedGenerationType != QuestionGenerationType.document)
                Positioned.fill(
                  child: Container(
                    color: Colors.white.withValues(alpha: 0.92),
                    child: Align(
                      alignment: const Alignment(0, -0.15),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: _RotatingLoadingContent(
                          messages: _selectedGenerationType ==
                              QuestionGenerationType.wrongAnswer
                              ? _wrongAnswerMessages
                              : _genMessages,
                          durations: _selectedGenerationType ==
                              QuestionGenerationType.wrongAnswer
                              ? _wrongAnswerDurations
                              : _genDurations,
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
                key: ValueKey(_isProcessingPdf ? 'pdf' : (_isLoadingStructure ? 'loading' : 'idle')),
                child: _isProcessingPdf
                    ? const _RotatingLoadingContent(
                  messages: _pdfMessages,
                  durations: _pdfDurations,
                )
                    : (_isLoadingStructure ? _buildLoadingContent() : _buildIdleContent()),
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
          child: _HeroBadge(),
        ),
        const SizedBox(height: 18),
        _FadeSlideIn(
          delay: const Duration(milliseconds: 200),
          duration: const Duration(milliseconds: 700),
          child: Column(
            children: [
              Text(
                '조회할 자격증 이름을 입력해주세요',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _textColor,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '자격증 이름을 알려주시면 AI가 필기·실기 구조와\n과목을 분석해드려요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _subTextColor,
                  fontSize: 13.5,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _FadeSlideIn(
          delay: const Duration(milliseconds: 400),
          duration: const Duration(milliseconds: 900),
          child: _buildCertInput(),
        ),
        if (_structureError != null) ...[
          const SizedBox(height: 18),
          _InlineMessage(text: _structureError!),
        ],
        const SizedBox(height: 14),
        _FadeSlideIn(
          delay: const Duration(milliseconds: 500),
          duration: const Duration(milliseconds: 900),
          child: _buildPdfShortcutButton(),
        ),
      ],
    );
  }

  Widget _buildPdfShortcutButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: _isPickingPdf ? null : _onPdfShortcutPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: const LinearGradient(colors: [_pinkSoft, Color(0xFFFFF1F4)]),
            border: Border.all(color: const Color(0xFFFBD9E1)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _isPickingPdf
                  ? const SizedBox(
                width: 15, height: 15,
                child: CircularProgressIndicator(strokeWidth: 2, color: _pinkColor),
              )
                  : const Icon(Icons.picture_as_pdf_rounded, size: 17, color: _pinkColor),
              const SizedBox(width: 8),
              const Text(
                'PDF로 바로 문제 생성',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _pinkColor),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingContent() {
    final name = _certNameController.text.trim();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'AI가 자격증을 분석하고 있어요',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _textColor,
            fontSize: 21,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$name의 시험 구조를 확인하고 있어요.',
          textAlign: TextAlign.center,
          style: TextStyle(
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
          color: _structureError != null
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
        onSubmitted: (_) => _fetchCertificateStructure(),
        onChanged: (_) {
          if (_structureError != null) {
            setState(() => _structureError = null);
          }
        },
        style: const TextStyle(
          color: _textColor,
          fontSize: 15.5,
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          hintText: '예: 정보처리기사, SQLD, 한국사능력검정시험',
          hintStyle: const TextStyle(color: Color(0xFFB7AFB1), fontSize: 15),
          prefixIcon: Padding(
            padding: const EdgeInsets.all(12),
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [_pinkColor, _pinkAccent]),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.badge_outlined,
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
                  onTap: _isLoadingStructure ? null : _fetchCertificateStructure,
                  child: _isLoadingStructure
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
    final certification = _certification;
    final subjects = _currentSubjects;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 40),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 36),
            child: _FadeSlideIn(
              delay: const Duration(milliseconds: 200),
              duration: const Duration(milliseconds: 700),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (certification != null) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: const LinearGradient(
                          colors: [_pinkSoft, Color(0xFFFFF3F5)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(colors: [_pinkColor, _pinkAccent]),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.badge_rounded,
                              color: Colors.white,
                              size: 21,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              certification.name,
                              style: const TextStyle(
                                color: _textColor,
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 26),

                    const _SectionTitle(
                      title: '시험 유형',
                      isRequired: true,
                    ),

                    const SizedBox(height: 12),

                    _ExamTypeSection(
                      certification: certification,
                      selectedExamType: _selectedExamType,
                      onSelected: _selectExamType,
                    ),
                  ],

                  if (subjects.isNotEmpty) ...[
                    const SizedBox(height: 28),

                    const _SectionTitle(
                      title: '과목 선택',
                    ),

                    const SizedBox(height: 12),

                    _SelectionCard(
                      child: DropdownButtonFormField<String>(
                        value: _selectedSubject,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          hintText: '문제를 생성할 과목을 선택해주세요.',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 6,
                          ),
                        ),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded),
                        items: [
                          const DropdownMenuItem<String>(
                            value: '전체',
                            child: Text('전체'),
                          ),
                          ...subjects.map((subject) {
                            return DropdownMenuItem<String>(
                              value: subject,
                              child: Text(subject),
                            );
                          }),
                        ],
                        onChanged: (value) {
                          setState(() => _selectedSubject = value);
                        },
                      ),
                    ),
                  ],

                  const SizedBox(height: 28),

                  const _SectionTitle(title: '생성 방식'),

                  const SizedBox(height: 12),

                  _GenerationTypeCard(
                    selectedType: _selectedGenerationType,
                    onChanged: (type) {
                      setState(() => _selectedGenerationType = type);
                    },
                  ),

                  const SizedBox(height: 28),

                  const _SectionTitle(title: '정답 확인 방식'),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: _ExamTypeButton(
                          label: '바로 확인',
                          description: '문제마다 정답을 즉시 확인해요',
                          icon: Icons.flash_on_rounded,
                          isSelected: _checkMode == AnswerCheckMode.immediate,
                          onPressed: () =>
                              setState(() => _checkMode = AnswerCheckMode.immediate),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ExamTypeButton(
                          label: '한번에 확인',
                          description: '20문제를 다 풀고 결과를 봐요',
                          icon: Icons.checklist_rounded,
                          isSelected: _checkMode == AnswerCheckMode.afterAll,
                          onPressed: () =>
                              setState(() => _checkMode = AnswerCheckMode.afterAll),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),

                  SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: const LinearGradient(colors: [_pinkColor, _pinkAccent]),
                        boxShadow: [
                          BoxShadow(
                            color: _pinkColor.withValues(alpha: 0.35),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: _isGenerating ? null : _onGeneratePressed,
                          child: Center(
                            child: _isGenerating
                                ? const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 18, height: 18,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
                                ),
                                SizedBox(width: 10),
                                Text(
                                  '생성 중...',
                                  style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800),
                                ),
                              ],
                            )
                                : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.auto_awesome_rounded, color: Colors.white),
                                SizedBox(width: 8),
                                Text('AI 문제 생성하기',
                                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
                              ],
                            ),
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
      },
    );
  }
}
String _stripPdfExtension(String fileName) {
  final lower = fileName.toLowerCase();
  if (lower.endsWith('.pdf')) {
    return fileName.substring(0, fileName.length - 4);
  }
  return fileName;
}

enum ExamType {
  written('필기'),
  practical('실기'),
  integrated('통합');

  final String label;

  const ExamType(this.label);
}

enum QuestionGenerationType {
  general,
  wrongAnswer,
  document,
}
enum AnswerCheckMode { immediate, afterAll }

class _HeroBadge extends StatelessWidget {
  const _HeroBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 68,
      height: 68,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [
            _QuestionGenerationPageState._pinkColor,
            _QuestionGenerationPageState._pinkAccent,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _QuestionGenerationPageState._pinkColor.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 30),
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
              _QuestionGenerationPageState._pinkColor,
              _QuestionGenerationPageState._pinkAccent,
            ])
                : null,
            color: (active || done) ? null : _QuestionGenerationPageState._pinkSoft,
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
            waveColorStart: _QuestionGenerationPageState._pinkColor,
            waveColorEnd: _QuestionGenerationPageState._pinkAccent,
          ),
          const SizedBox(height: 12),
          Text(
            '${(progress.value * 100).toInt()}%',
            style: const TextStyle(
              color: _QuestionGenerationPageState._pinkColor,
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
        color: _QuestionGenerationPageState._pinkSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFBDDE3)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: _QuestionGenerationPageState._subTextColor,
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final bool isRequired;

  const _SectionTitle({
    required this.title,
    this.isRequired = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: _QuestionGenerationPageState._textColor,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (isRequired) ...[
          const SizedBox(width: 4),
          const Text(
            '*',
            style: TextStyle(
              color: _QuestionGenerationPageState._pinkColor,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ],
    );
  }
}

class _SelectionCard extends StatelessWidget {
  final Widget child;

  const _SelectionCard({
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFF1EBEE),
        ),
      ),
      child: child,
    );
  }
}

class _ExamTypeSection extends StatelessWidget {
  final CertificationData certification;
  final ExamType? selectedExamType;
  final ValueChanged<ExamType> onSelected;

  const _ExamTypeSection({
    required this.certification,
    required this.selectedExamType,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    /// 필기·실기 구분이 없는 시험
    if (certification.isIntegrated) {
      return _ExamTypeButton(
        label: '통합 시험',
        description: '필기와 실기가 별도로 구분되지 않는 시험입니다.',
        icon: Icons.menu_book_rounded,
        isSelected: selectedExamType == ExamType.integrated,
        onPressed: () {
          onSelected(ExamType.integrated);
        },
      );
    }

    final examTypes = <Widget>[];

    if (certification.hasWritten) {
      examTypes.add(
        Expanded(
          child: _ExamTypeButton(
            label: '필기',
            description: '객관식 또는 필답형',
            icon: Icons.edit_note_rounded,
            isSelected: selectedExamType == ExamType.written,
            onPressed: () {
              onSelected(ExamType.written);
            },
          ),
        ),
      );
    }

    if (certification.hasWritten && certification.hasPractical) {
      examTypes.add(
        const SizedBox(width: 10),
      );
    }

    if (certification.hasPractical) {
      examTypes.add(
        Expanded(
          child: _ExamTypeButton(
            label: '실기',
            description: '단답형·서술형·작업형',
            icon: Icons.build_outlined,
            isSelected: selectedExamType == ExamType.practical,
            onPressed: () {
              onSelected(ExamType.practical);
            },
          ),
        ),
      );
    }

    return Row(
      children: examTypes,
    );
  }
}

class _ExamTypeButton extends StatelessWidget {
  final String label;
  final String description;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onPressed;

  const _ExamTypeButton({
    required this.label,
    required this.description,
    required this.icon,
    required this.isSelected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          constraints: const BoxConstraints(
            minHeight: 105,
          ),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: isSelected
                ? const LinearGradient(
              colors: [
                _QuestionGenerationPageState._pinkSoft,
                Color(0xFFFFF3F5),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
                : null,
            color: isSelected ? null : Colors.white.withValues(alpha: 0.85),
            border: Border.all(
              color: isSelected
                  ? _QuestionGenerationPageState._pinkColor
                  : const Color(0xFFF1EBEE),
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: isSelected
                ? [
              BoxShadow(
                color: _QuestionGenerationPageState._pinkColor.withValues(alpha: 0.18),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: isSelected
                      ? const LinearGradient(colors: [
                    _QuestionGenerationPageState._pinkColor,
                    _QuestionGenerationPageState._pinkAccent,
                  ])
                      : null,
                  color: isSelected ? null : const Color(0xFFF2EEF0),
                ),
                child: Icon(
                  icon,
                  size: 16,
                  color: isSelected
                      ? Colors.white
                      : _QuestionGenerationPageState._subTextColor,
                ),
              ),

              const SizedBox(height: 10),

              Text(
                label,
                style: const TextStyle(
                  color: _QuestionGenerationPageState._textColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 5),

              Text(
                description,
                style: const TextStyle(
                  color: _QuestionGenerationPageState._subTextColor,
                  fontSize: 11,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GenerationTypeCard extends StatelessWidget {
  final QuestionGenerationType selectedType;
  final ValueChanged<QuestionGenerationType> onChanged;

  const _GenerationTypeCard({
    required this.selectedType,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _GenerationTypeItem(
          icon: Icons.edit_note_rounded,
          title: '기본 문제 생성',
          description: '선택한 자격증과 과목을 기준으로 문제를 생성합니다.',
          value: QuestionGenerationType.general,
          groupValue: selectedType,
          onChanged: onChanged,
        ),

        const SizedBox(height: 10),

        _GenerationTypeItem(
          icon: Icons.refresh_rounded,
          title: '오답 기반 문제 생성',
          description: '기존에 틀린 내용을 기준으로 새 문제를 생성합니다.',
          value: QuestionGenerationType.wrongAnswer,
          groupValue: selectedType,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _GenerationTypeItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final QuestionGenerationType value;
  final QuestionGenerationType groupValue;
  final ValueChanged<QuestionGenerationType> onChanged;

  const _GenerationTypeItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = value == groupValue;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: () => onChanged(value),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: isSelected
                ? const LinearGradient(
              colors: [
                _QuestionGenerationPageState._pinkSoft,
                Color(0xFFFFF3F5),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
                : null,
            color: isSelected ? null : Colors.white.withValues(alpha: 0.85),
            border: Border.all(
              color: isSelected
                  ? _QuestionGenerationPageState._pinkColor
                  : const Color(0xFFF1EBEE),
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: isSelected
                ? [
              BoxShadow(
                color: _QuestionGenerationPageState._pinkColor.withValues(alpha: 0.16),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: isSelected
                      ? const LinearGradient(colors: [
                    _QuestionGenerationPageState._pinkColor,
                    _QuestionGenerationPageState._pinkAccent,
                  ])
                      : null,
                  color: isSelected ? null : const Color(0xFFFFE4EA),
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  color: isSelected ? Colors.white : _QuestionGenerationPageState._pinkColor,
                  size: 24,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _QuestionGenerationPageState._textColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: const TextStyle(
                        color: _QuestionGenerationPageState._subTextColor,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              Icon(
                isSelected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: isSelected
                    ? _QuestionGenerationPageState._pinkColor
                    : const Color(0xFFCFC6CA),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FadeSlideIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  const _FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 380),
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
          waveColorStart: _QuestionGenerationPageState._pinkColor,
          waveColorEnd: _QuestionGenerationPageState._pinkAccent,
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
              color: _QuestionGenerationPageState._textColor,
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}