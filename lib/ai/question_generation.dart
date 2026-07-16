import 'package:flutter/material.dart';

import '../widgets/app_main_background.dart';

/// AI 문제 생성 설정 화면
class QuestionGenerationPage extends StatefulWidget {
  const QuestionGenerationPage({super.key});

  @override
  State<QuestionGenerationPage> createState() =>
      _QuestionGenerationPageState();
}

class _QuestionGenerationPageState
    extends State<QuestionGenerationPage> {
  static const Color _textColor = Color(0xFF302C2E);
  static const Color _subTextColor = Color(0xFF8E8589);
  static const Color _pinkColor = Color(0xFFF4869D);

  /// 임시 자격증 데이터
  ///
  /// 나중에는 외부 API 또는 Firestore 데이터로 교체하면 됩니다.
  ///
  /// writtenSubjects: 필기 과목
  /// practicalSubjects: 실기 과목
  /// hasWritten: 필기시험 존재 여부
  /// hasPractical: 실기시험 존재 여부
  /// isIntegrated: 필기/실기 구분이 없는 시험
  final List<CertificationData> _certifications = const [
    CertificationData(
      name: '정보처리기사',
      hasWritten: true,
      hasPractical: true,
      writtenSubjects: [
        '소프트웨어 설계',
        '소프트웨어 개발',
        '데이터베이스 구축',
        '프로그래밍 언어 활용',
        '정보시스템 구축 관리',
      ],
      practicalSubjects: [
        '정보처리 실무',
      ],
    ),
    CertificationData(
      name: '컴퓨터활용능력 1급',
      hasWritten: true,
      hasPractical: true,
      writtenSubjects: [
        '컴퓨터 일반',
        '스프레드시트 일반',
        '데이터베이스 일반',
      ],
      practicalSubjects: [
        '스프레드시트 실무',
        '데이터베이스 실무',
      ],
    ),
    CertificationData(
      name: 'SQLD',
      hasWritten: true,
      hasPractical: false,
      writtenSubjects: [
        '데이터 모델링의 이해',
        'SQL 기본 및 활용',
      ],
    ),
    CertificationData(
      name: '한국사능력검정시험',
      hasWritten: false,
      hasPractical: false,
      isIntegrated: true,
      integratedSubjects: [
        '선사 시대',
        '고대',
        '고려',
        '조선',
        '근대',
        '일제강점기',
        '현대',
      ],
    ),
  ];

  CertificationData? _selectedCertification;
  ExamType? _selectedExamType;
  String? _selectedSubject;

  QuestionGenerationType _selectedGenerationType =
      QuestionGenerationType.general;

  /// 현재 선택된 시험 유형의 과목 목록
  List<String> get _currentSubjects {
    final certification = _selectedCertification;

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

  /// 자격증을 선택했을 때 기본 시험 유형 결정
  void _selectCertification(
      CertificationData? certification,
      ) {
    setState(() {
      _selectedCertification = certification;
      _selectedSubject = null;

      if (certification == null) {
        _selectedExamType = null;
        return;
      }

      if (certification.isIntegrated) {
        _selectedExamType = ExamType.integrated;
        return;
      }

      if (certification.hasWritten) {
        _selectedExamType = ExamType.written;
        return;
      }

      if (certification.hasPractical) {
        _selectedExamType = ExamType.practical;
        return;
      }

      _selectedExamType = null;
    });
  }

  /// 필기·실기·통합 시험 유형 선택
  void _selectExamType(ExamType examType) {
    setState(() {
      _selectedExamType = examType;
      _selectedSubject = null;
    });
  }

  void _onGeneratePressed() {
    if (_selectedCertification == null) {
      _showMessage('자격증을 선택해주세요.');
      return;
    }

    if (_selectedExamType == null) {
      _showMessage('시험 유형을 선택해주세요.');
      return;
    }

    if (_currentSubjects.isNotEmpty &&
        _selectedSubject == null) {
      _showMessage('과목을 선택해주세요.');
      return;
    }

    debugPrint(
      '선택 자격증: ${_selectedCertification!.name}',
    );
    debugPrint(
      '시험 유형: ${_selectedExamType!.label}',
    );
    debugPrint(
      '선택 과목: ${_selectedSubject ?? '과목 구분 없음'}',
    );
    debugPrint(
      '생성 방식: $_selectedGenerationType',
    );
    debugPrint('문제 수: 1개');

    _showMessage('AI 문제 1개 생성 기능은 다음 단계에서 연결합니다.');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final certification = _selectedCertification;
    final subjects = _currentSubjects;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          'AI 문제 생성',
          style: TextStyle(
            color: _textColor,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: _textColor,
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
          ),
        ),
      ),
      body: AppMainBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              24,
              24,
              24,
              40,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _PageDescriptionCard(),

                const SizedBox(height: 30),

                const _SectionTitle(
                  title: '자격증 선택',
                  isRequired: true,
                ),

                const SizedBox(height: 12),

                _SelectionCard(
                  child: DropdownButtonFormField<
                      CertificationData>(
                    value: _selectedCertification,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      hintText: '문제를 생성할 자격증을 선택해주세요.',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 6,
                      ),
                    ),
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                    ),
                    items: _certifications.map((item) {
                      return DropdownMenuItem<
                          CertificationData>(
                        value: item,
                        child: Text(item.name),
                      );
                    }).toList(),
                    onChanged: _selectCertification,
                  ),
                ),

                /// 자격증을 선택한 경우에만 시험 유형 표시
                if (certification != null) ...[
                  const SizedBox(height: 28),

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

                /// 현재 시험 유형에 과목이 있을 때만 표시
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
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                      ),
                      items: subjects.map((subject) {
                        return DropdownMenuItem<String>(
                          value: subject,
                          child: Text(subject),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedSubject = value;
                        });
                      },
                    ),
                  ),
                ],

                const SizedBox(height: 28),

                const _SectionTitle(
                  title: '생성 방식',
                ),

                const SizedBox(height: 12),

                _GenerationTypeCard(
                  selectedType: _selectedGenerationType,
                  onChanged: (type) {
                    setState(() {
                      _selectedGenerationType = type;
                    });
                  },
                ),

                const SizedBox(height: 40),

                SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: FilledButton.icon(
                    onPressed: _onGeneratePressed,
                    style: FilledButton.styleFrom(
                      backgroundColor: _pinkColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    icon: const Icon(
                      Icons.auto_awesome_rounded,
                    ),
                    label: const Text(
                      'AI 문제 생성하기',
                      style: TextStyle(
                        fontSize: 17,
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

/// 자격증 임시 데이터 모델
class CertificationData {
  final String name;

  final bool hasWritten;
  final bool hasPractical;
  final bool isIntegrated;

  final List<String> writtenSubjects;
  final List<String> practicalSubjects;
  final List<String> integratedSubjects;

  const CertificationData({
    required this.name,
    this.hasWritten = false,
    this.hasPractical = false,
    this.isIntegrated = false,
    this.writtenSubjects = const [],
    this.practicalSubjects = const [],
    this.integratedSubjects = const [],
  });
}

class _PageDescriptionCard extends StatelessWidget {
  const _PageDescriptionCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFE8EE),
            Color(0xFFF1E8FF),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: const BoxDecoration(
              color: Colors.white54,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Color(0xFFF4869D),
              size: 30,
            ),
          ),

          const SizedBox(width: 16),

          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '맞춤 문제를 만들어보세요',
                  style: TextStyle(
                    color: _QuestionGenerationPageState._textColor,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                SizedBox(height: 8),

                Text(
                  '자격증과 생성 방식을 선택하면\n구름iT이 연습 문제를 생성해드려요.',
                  style: TextStyle(
                    color: _QuestionGenerationPageState._subTextColor,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
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

    if (certification.hasWritten &&
        certification.hasPractical) {
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