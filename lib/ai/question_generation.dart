import 'package:flutter/material.dart';

import '../widgets/app_main_background.dart';
import '../widgets/app_top_bar.dart';
import 'services/question_generation_api_service.dart';

/// AI 문제 생성 설정 화면
///
/// 로드맵 페이지와 동일하게 2단계(step1: 자격증 입력 / step2: 시험 유형·과목·생성 방식 선택)
/// PageView 구조를 사용한다.
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

  final PageController _pageController = PageController();
  int _currentStep = 0;

  late final AnimationController _loadingController;

  final TextEditingController _certNameController = TextEditingController();

  bool _isLoadingStructure = false;
  bool _isGenerating = false;
  String? _structureError;
  CertificationData? _certification;

  ExamType? _selectedExamType;
  String? _selectedSubject;

  QuestionGenerationType _selectedGenerationType =
      QuestionGenerationType.general;

  /// 현재 선택된 시험 유형의 과목 목록
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

  /// 필기·실기·통합 시험 유형 선택
  void _selectExamType(ExamType examType) {
    setState(() {
      _selectedExamType = examType;
      _selectedSubject = null;
    });
  }

  Future<void> _onGeneratePressed() async {
    final certification = _certification;

    if (certification == null) {
      _showMessage('자격증을 먼저 조회해주세요.');
      return;
    }
    if (_selectedExamType == null) {
      _showMessage('시험 유형을 선택해주세요.');
      return;
    }
    if (_currentSubjects.isNotEmpty && _selectedSubject == null) {
      _showMessage('과목을 선택해주세요.');
      return;
    }

    setState(() => _isGenerating = true);

    try {
      final question = await QuestionGenerationApiService.generateQuestion(
        certificationName: certification.name,
        examType: _selectedExamType!.label,
        subject: _selectedSubject,
      );

      if (!mounted) return;
      _showGeneratedQuestion(question);
    } catch (e) {
      debugPrint('문제 생성 에러: $e');
      if (!mounted) return;
      _showMessage('문제 생성에 실패했어요. 잠시 후 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  void _showGeneratedQuestion(GeneratedQuestion question) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _QuestionResultSheet(question: question),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppTopBar(
        title: 'AI 문제 생성',
        centerTitle: false,
        // step2에서는 페이지 뒤로가기가 아니라 step1으로 슬라이드 복귀
        leading: _currentStep == 1
            ? IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => _goToStep(0),
        )
            : null,
      ),
      body: AppMainBackground(
        child: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
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
              Positioned(
                top: 48,
                left: 0,
                right: 0,
                child: _StepProgressBar(currentStep: _currentStep),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Step 1: 자격증 이름 입력
  // ------------------------------------------------------------------

  Widget _buildStep1() {
    return Center(
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
                key: ValueKey(_isLoadingStructure),
                child: _isLoadingStructure
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
      ],
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
                color: _pinkSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.badge_outlined,
                color: _pinkColor,
                size: 19,
              ),
            ),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          suffixIcon: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _pinkColor,
                borderRadius: BorderRadius.circular(14),
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

  // ------------------------------------------------------------------
  // Step 2: 시험 유형 / 과목 / 생성 방식 선택
  // ------------------------------------------------------------------

  Widget _buildStep2() {
    final certification = _certification;
    final subjects = _currentSubjects;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 84, 24, 40),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 36),
            child: _FadeSlideIn(
              delay: const Duration(milliseconds: 200),
              duration: const Duration(milliseconds: 700),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (certification != null) ...[
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: _pinkSoft,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.badge_outlined,
                            color: _pinkColor,
                            size: 20,
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
                      isRequired: true,
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
                        items: subjects.map((subject) {
                          return DropdownMenuItem<String>(
                            value: subject,
                            child: Text(subject),
                          );
                        }).toList(),
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

                  const SizedBox(height: 40),

                  SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: FilledButton.icon(
                      onPressed: _isGenerating ? null : _onGeneratePressed,
                      style: FilledButton.styleFrom(
                        backgroundColor: _pinkColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                      icon: _isGenerating
                          ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
                      )
                          : const Icon(Icons.auto_awesome_rounded),
                      label: Text(
                        _isGenerating ? '생성 중...' : 'AI 문제 생성하기',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
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

/// 시험 유형
enum ExamType {
  written('필기'),
  practical('실기'),
  integrated('통합');

  final String label;

  const ExamType(this.label);
}

/// 문제 생성 방식
enum QuestionGenerationType {
  general,
  wrongAnswer,
  document,
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
            color: (active || done)
                ? _QuestionGenerationPageState._pinkColor
                : _QuestionGenerationPageState._pinkSoft,
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
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 280),
      child: AnimatedBuilder(
        animation: progress,
        builder: (context, _) => Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress.value,
                minHeight: 7,
                backgroundColor: _QuestionGenerationPageState._pinkSoft,
                valueColor: const AlwaysStoppedAnimation(
                  _QuestionGenerationPageState._pinkColor,
                ),
              ),
            ),
            const SizedBox(height: 10),
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
      color: isSelected
          ? const Color(0xFFFFE4EA)
          : Colors.white.withValues(alpha: 0.85),
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
            border: Border.all(
              color: isSelected
                  ? _QuestionGenerationPageState._pinkColor
                  : const Color(0xFFF1EBEE),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: isSelected
                    ? _QuestionGenerationPageState._pinkColor
                    : _QuestionGenerationPageState._subTextColor,
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
          isEnabled: true,
          onChanged: onChanged,
        ),

        const SizedBox(height: 10),

        _GenerationTypeItem(
          icon: Icons.refresh_rounded,
          title: '오답 기반 문제 생성',
          description: '기존에 틀린 내용을 기준으로 새 문제를 생성합니다.',
          value: QuestionGenerationType.wrongAnswer,
          groupValue: selectedType,
          isEnabled: false,
          onChanged: onChanged,
        ),

        const SizedBox(height: 10),

        _GenerationTypeItem(
          icon: Icons.description_outlined,
          title: '자료 기반 문제 생성',
          description: '업로드한 PDF 또는 사진 자료로 문제를 생성합니다.',
          value: QuestionGenerationType.document,
          groupValue: selectedType,
          isEnabled: false,
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
  final bool isEnabled;
  final ValueChanged<QuestionGenerationType> onChanged;

  const _GenerationTypeItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.value,
    required this.groupValue,
    required this.isEnabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = value == groupValue;

    return Material(
      color: isEnabled
          ? Colors.white.withValues(alpha: 0.85)
          : Colors.white.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: isEnabled
            ? () {
          onChanged(value);
        }
            : null,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected
                  ? _QuestionGenerationPageState._pinkColor
                  : const Color(0xFFF1EBEE),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFE4EA),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  color: _QuestionGenerationPageState._pinkColor,
                  size: 24,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: TextStyle(
                              color: isEnabled
                                  ? _QuestionGenerationPageState
                                  ._textColor
                                  : _QuestionGenerationPageState
                                  ._subTextColor,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),

                        if (!isEnabled) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF2EEF0),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              '준비 중',
                              style: TextStyle(
                                color: _QuestionGenerationPageState
                                    ._subTextColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 6),

                    Text(
                      description,
                      style: const TextStyle(
                        color: _QuestionGenerationPageState
                            ._subTextColor,
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

class _QuestionResultSheet extends StatefulWidget {
  final GeneratedQuestion question;
  const _QuestionResultSheet({required this.question});

  @override
  State<_QuestionResultSheet> createState() => _QuestionResultSheetState();
}

class _QuestionResultSheetState extends State<_QuestionResultSheet> {
  String? _selected;
  bool _revealed = false;

  bool get _isMultipleChoice => widget.question.options.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final q = widget.question;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 32),
            children: [
              Center(
                child: Container(
                  width: 40, height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFE7EA),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                q.question,
                style: const TextStyle(
                  color: _QuestionGenerationPageState._textColor,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),

              if (_isMultipleChoice)
                ...q.options.map((opt) {
                  final isSelected = _selected == opt;
                  final isCorrect = opt == q.answer;
                  Color borderColor = const Color(0xFFF1EBEE);
                  Color? fillColor = Colors.white;

                  if (_revealed) {
                    if (isCorrect) {
                      borderColor = const Color(0xFF4CAF7D);
                      fillColor = const Color(0xFFE9F7EF);
                    } else if (isSelected) {
                      borderColor = const Color(0xFFE96B7A);
                      fillColor = const Color(0xFFFFE9EC);
                    }
                  } else if (isSelected) {
                    borderColor = _QuestionGenerationPageState._pinkColor;
                    fillColor = _QuestionGenerationPageState._pinkSoft;
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Material(
                      color: fillColor,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: _revealed
                            ? null
                            : () => setState(() => _selected = opt),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: borderColor, width: 1.4),
                          ),
                          child: Text(
                            opt,
                            style: const TextStyle(
                              color: _QuestionGenerationPageState._textColor,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                })
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _QuestionGenerationPageState._pinkSoft,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    '단답형/서술형 문제입니다. 직접 답을 생각해본 뒤 정답을 확인해보세요.',
                    style: TextStyle(
                      color: _QuestionGenerationPageState._subTextColor,
                      fontSize: 13,
                    ),
                  ),
                ),

              const SizedBox(height: 8),

              if (_revealed) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F5F6),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '정답: ${q.answer}',
                        style: const TextStyle(
                          color: Color(0xFF4CAF7D),
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        q.explanation,
                        style: const TextStyle(
                          color: _QuestionGenerationPageState._textColor,
                          fontSize: 13.5,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: _revealed
                      ? () => Navigator.pop(context)
                      : (_isMultipleChoice && _selected == null)
                      ? null
                      : () => setState(() => _revealed = true),
                  style: FilledButton.styleFrom(
                    backgroundColor: _QuestionGenerationPageState._pinkColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: Text(
                    _revealed ? '닫기' : '정답 확인',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}