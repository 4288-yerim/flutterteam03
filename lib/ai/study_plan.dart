import 'package:flutter/material.dart';

import '../widgets/app_main_background.dart';
import '../widgets/app_top_bar.dart';

class AiStudyPlanPage extends StatefulWidget {
  const AiStudyPlanPage({super.key});

  @override
  State<AiStudyPlanPage> createState() => _AiStudyPlanPageState();
}

class _AiStudyPlanPageState extends State<AiStudyPlanPage> {
  static const Color _textColor = Color(0xFF302C2E);
  static const Color _subTextColor = Color(0xFF8E8589);
  static const Color _pinkColor = Color(0xFFF4869D);
  static const Color _purpleColor = Color(0xFF9D7BFF);
  static const Color _borderColor = Color(0xFFE8E1E4);

  final TextEditingController _certificateSearchController =
  TextEditingController();

  final List<_CertificateOption> _certificateOptions = const [
    _CertificateOption(
      name: '정보처리기사',
      rounds: [
        '2026년 1회',
        '2026년 2회',
        '2026년 3회',
      ],
    ),
    _CertificateOption(
      name: 'SQLD',
      rounds: [
        '제60회',
        '제61회',
        '제62회',
        '제63회',
      ],
    ),
    _CertificateOption(
      name: '컴퓨터활용능력 1급',
      rounds: [
        '상시 시험',
      ],
    ),
    _CertificateOption(
      name: '빅데이터분석기사',
      rounds: [
        '2026년 1회',
        '2026년 2회',
      ],
    ),
    _CertificateOption(
      name: '네트워크관리사 2급',
      rounds: [
        '2026년 1회',
        '2026년 2회',
        '2026년 3회',
        '2026년 4회',
      ],
    ),
  ];

  final List<_StudyTimeSlot> _timeSlots = [];

  String _searchKeyword = '';

  _CertificateOption? _selectedCertificate;
  String? _selectedRound;
  DateTime? _studyStartDate;

  bool _includeReview = true;
  bool _isPlanGenerated = false;

  @override
  void dispose() {
    _certificateSearchController.dispose();
    super.dispose();
  }

  List<_CertificateOption> get _filteredCertificates {
    final keyword = _searchKeyword.trim().toLowerCase();

    if (keyword.isEmpty) {
      return [];
    }

    return _certificateOptions.where((certificate) {
      return certificate.name.toLowerCase().contains(keyword);
    }).toList();
  }

  Future<void> _selectStudyStartDate() async {
    final now = DateTime.now();

    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _studyStartDate ?? today,
      firstDate: today,
      lastDate: DateTime(now.year + 3, 12, 31),
      helpText: '공부 시작 날짜 선택',
      cancelText: '취소',
      confirmText: '선택',
    );

    if (selectedDate == null) {
      return;
    }

    setState(() {
      _studyStartDate = selectedDate;
    });
  }

  Future<void> _openAddTimeSlotSheet() async {
    final result = await showModalBottomSheet<_StudyTimeSlot>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return const _AddTimeSlotSheet();
      },
    );

    if (result == null) {
      return;
    }

    setState(() {
      _timeSlots.add(result);
    });
  }

  void _selectCertificate(_CertificateOption certificate) {
    setState(() {
      _selectedCertificate = certificate;
      _selectedRound = null;

      _searchKeyword = '';
      _certificateSearchController.text = certificate.name;
    });
  }

  void _removeSelectedCertificate() {
    setState(() {
      _certificateSearchController.clear();

      _searchKeyword = '';
      _selectedCertificate = null;
      _selectedRound = null;
    });
  }

  void _removeTimeSlot(int index) {
    setState(() {
      _timeSlots.removeAt(index);
    });
  }

  void _generatePlan() {
    if (_selectedCertificate == null) {
      _showMessage('자격증을 선택해주세요.');
      return;
    }

    if (_selectedRound == null) {
      _showMessage('시험 회차를 선택해주세요.');
      return;
    }

    if (_studyStartDate == null) {
      _showMessage('공부 시작 날짜를 선택해주세요.');
      return;
    }

    if (_timeSlots.isEmpty) {
      _showMessage('선호 공부 시간대를 한 개 이상 추가해주세요.');
      return;
    }

    setState(() {
      _isPlanGenerated = true;
    });
  }

  void _savePlan() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('학습 플랜 저장 기능은 추후 구현 예정입니다.'),
      ),
    );
  }

  void _resetPlan() {
    setState(() {
      _certificateSearchController.clear();

      _searchKeyword = '';
      _selectedCertificate = null;
      _selectedRound = null;
      _studyStartDate = null;
      _timeSlots.clear();
      _includeReview = true;
      _isPlanGenerated = false;
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '${date.year}.$month.$day';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: const AppTopBar(
        title: 'AI 학습 플랜',
      ),
      body: AppMainBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              24,
              20,
              24,
              40,
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _isPlanGenerated
                  ? _buildGeneratedPlan()
                  : _buildInputForm(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputForm() {
    return Column(
      key: const ValueKey('inputForm'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _PageGuideCard(),

        const SizedBox(height: 28),

        const _SectionTitle(
          number: '1',
          title: '응시할 자격증과 회차',
          description: '자격증 이름을 검색한 뒤 시험 회차를 선택해주세요.',
        ),

        const SizedBox(height: 16),

        _buildCertificateSearch(),

        if (_selectedCertificate != null) ...[
          const SizedBox(height: 14),
          _buildSelectedCertificateCard(),
          const SizedBox(height: 14),
          _buildRoundSelector(),
        ],

        const SizedBox(height: 30),

        const _SectionTitle(
          number: '2',
          title: '공부 시작 날짜',
          description: '선택한 날짜부터 시험 전날까지 플랜을 구성합니다.',
        ),

        const SizedBox(height: 16),

        _buildDateSelector(),

        const SizedBox(height: 30),

        const _SectionTitle(
          number: '3',
          title: '선호 공부 시간대',
          description: '요일과 시간을 묶어서 여러 개 추가할 수 있습니다.',
        ),

        const SizedBox(height: 16),

        _buildTimeSlotArea(),

        const SizedBox(height: 30),

        const _SectionTitle(
          number: '4',
          title: '복습 포함 여부',
          description: '주간 복습과 오답 정리 시간을 플랜에 포함합니다.',
        ),

        const SizedBox(height: 16),

        _buildReviewSelector(),

        const SizedBox(height: 34),

        SizedBox(
          width: double.infinity,
          height: 56,
          child: FilledButton.icon(
            onPressed: _generatePlan,
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
              'AI 학습 플랜 생성하기',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCertificateSearch() {
    final filteredCertificates = _filteredCertificates;

    return Column(
      children: [
        TextField(
          controller: _certificateSearchController,
          onChanged: (value) {
            setState(() {
              _searchKeyword = value;

              if (_selectedCertificate?.name != value) {
                _selectedCertificate = null;
                _selectedRound = null;
              }
            });
          },
          decoration: InputDecoration(
            hintText: '예: 정보처리기사, SQLD',
            hintStyle: const TextStyle(
              color: Color(0xFFB2A9AD),
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: _purpleColor,
            ),
            suffixIcon: _certificateSearchController.text.isEmpty
                ? null
                : IconButton(
              onPressed: _removeSelectedCertificate,
              icon: const Icon(
                Icons.close_rounded,
              ),
            ),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.88),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 18,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(
                color: _borderColor,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(
                color: _purpleColor,
                width: 1.5,
              ),
            ),
          ),
        ),

        if (_searchKeyword.trim().isNotEmpty &&
            _selectedCertificate == null) ...[
          const SizedBox(height: 8),

          Container(
            width: double.infinity,
            constraints: const BoxConstraints(
              maxHeight: 250,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _borderColor,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: filteredCertificates.isEmpty
                ? const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                '검색 결과가 없습니다.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _subTextColor,
                ),
              ),
            )
                : ListView.separated(
              padding: const EdgeInsets.symmetric(
                vertical: 8,
              ),
              shrinkWrap: true,
              itemCount: filteredCertificates.length,
              separatorBuilder: (context, index) {
                return const Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: Color(0xFFF1ECEE),
                );
              },
              itemBuilder: (context, index) {
                final certificate =
                filteredCertificates[index];

                return ListTile(
                  onTap: () {
                    _selectCertificate(certificate);
                  },
                  leading: Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEDE6FF),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.workspace_premium_outlined,
                      color: _purpleColor,
                      size: 22,
                    ),
                  ),
                  title: Text(
                    certificate.name,
                    style: const TextStyle(
                      color: _textColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    '${certificate.rounds.length}개 회차 선택 가능',
                    style: const TextStyle(
                      color: _subTextColor,
                      fontSize: 12,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: _subTextColor,
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSelectedCertificateCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF3EEFF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: _purpleColor,
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '선택한 자격증',
                  style: TextStyle(
                    color: _subTextColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  _selectedCertificate!.name,
                  style: const TextStyle(
                    color: _textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),

          IconButton(
            onPressed: _removeSelectedCertificate,
            icon: const Icon(
              Icons.close_rounded,
              color: _subTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoundSelector() {
    return DropdownButtonFormField<String>(
      value: _selectedRound,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: '시험 회차',
        labelStyle: const TextStyle(
          color: _subTextColor,
        ),
        prefixIcon: const Icon(
          Icons.event_available_outlined,
          color: _purpleColor,
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.88),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: _borderColor,
          ),
        ),
      ),
      items: _selectedCertificate!.rounds.map((round) {
        return DropdownMenuItem<String>(
          value: round,
          child: Text(round),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedRound = value;
        });
      },
    );
  }

  Widget _buildDateSelector() {
    return InkWell(
      onTap: _selectStudyStartDate,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _borderColor,
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today_outlined,
              color: _purpleColor,
              size: 22,
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Text(
                _studyStartDate == null
                    ? '공부 시작 날짜를 선택해주세요.'
                    : _formatDate(_studyStartDate!),
                style: TextStyle(
                  color: _studyStartDate == null
                      ? const Color(0xFFB2A9AD)
                      : _textColor,
                  fontSize: 15,
                  fontWeight: _studyStartDate == null
                      ? FontWeight.w500
                      : FontWeight.w700,
                ),
              ),
            ),

            const Icon(
              Icons.chevron_right_rounded,
              color: _subTextColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSlotArea() {
    return Column(
      children: [
        if (_timeSlots.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 24,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _borderColor,
              ),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  color: Color(0xFFB8ACB1),
                  size: 30,
                ),
                SizedBox(height: 10),
                Text(
                  '등록된 공부 시간대가 없습니다.',
                  style: TextStyle(
                    color: _subTextColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: _timeSlots.length,
            separatorBuilder: (context, index) {
              return const SizedBox(height: 10);
            },
            itemBuilder: (context, index) {
              final slot = _timeSlots[index];

              return Container(
                padding: const EdgeInsets.fromLTRB(
                  16,
                  14,
                  8,
                  14,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: _borderColor,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFE8EE),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: _pinkColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),

                    const SizedBox(width: 13),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            slot.dayLabel,
                            style: const TextStyle(
                              color: _textColor,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),

                          const SizedBox(height: 5),

                          Text(
                            '${slot.formatTime(slot.startTime)}'
                                ' ~ '
                                '${slot.formatTime(slot.endTime)}',
                            style: const TextStyle(
                              color: _subTextColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    IconButton(
                      onPressed: () {
                        _removeTimeSlot(index);
                      },
                      icon: const Icon(
                        Icons.close_rounded,
                        color: _subTextColor,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

        const SizedBox(height: 12),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton.icon(
            onPressed: _openAddTimeSlotSheet,
            style: OutlinedButton.styleFrom(
              foregroundColor: _purpleColor,
              side: const BorderSide(
                color: Color(0xFFCFC1FF),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            icon: const Icon(
              Icons.add_rounded,
            ),
            label: const Text(
              '시간대 추가하기',
              style: TextStyle(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewSelector() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        18,
        14,
        12,
        14,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _borderColor,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              color: Color(0xFFE2F5F1),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.replay_rounded,
              color: Color(0xFF5BB8AB),
            ),
          ),

          const SizedBox(width: 14),

          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '복습 일정 포함',
                  style: TextStyle(
                    color: _textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '주간 복습과 시험 직전 총정리를 배정합니다.',
                  style: TextStyle(
                    color: _subTextColor,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          Switch(
            value: _includeReview,
            activeTrackColor: _pinkColor,
            onChanged: (value) {
              setState(() {
                _includeReview = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGeneratedPlan() {
    final samplePlans = [
      const _DailyPlanItem(
        day: '1일차',
        title: '전체 범위 확인 및 기초 개념 학습',
        detail: '출제 범위를 확인하고 핵심 개념 2개 단원을 학습합니다.',
        duration: '2시간',
      ),
      const _DailyPlanItem(
        day: '2일차',
        title: '핵심 이론 학습',
        detail: '빈출 이론을 중심으로 개념 정리와 예제를 진행합니다.',
        duration: '2시간',
      ),
      const _DailyPlanItem(
        day: '3일차',
        title: '기출문제 풀이',
        detail: '학습한 범위의 기출문제를 풀고 오답을 표시합니다.',
        duration: '1시간 30분',
      ),
      if (_includeReview)
        const _DailyPlanItem(
          day: '복습일',
          title: '주간 복습 및 오답 정리',
          detail: '누적 오답과 취약 개념을 다시 확인합니다.',
          duration: '1시간',
        ),
    ];

    return Column(
      key: const ValueKey('generatedPlan'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFFE4ED),
                Color(0xFFF1E9FF),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'AI 생성 완료',
                  style: TextStyle(
                    color: _pinkColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),

              const SizedBox(height: 14),

              Text(
                '${_selectedCertificate!.name} 학습 플랜',
                style: const TextStyle(
                  color: _textColor,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),

              const SizedBox(height: 9),

              Text(
                '$_selectedRound · '
                    '${_formatDate(_studyStartDate!)} 시작',
                style: const TextStyle(
                  color: _subTextColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 26),

        const Text(
          '일일 학습 계획',
          style: TextStyle(
            color: _textColor,
            fontSize: 21,
            fontWeight: FontWeight.w800,
          ),
        ),

        const SizedBox(height: 8),

        const Text(
          '현재는 AI 연동 전 UI 확인용 샘플 데이터입니다.',
          style: TextStyle(
            color: _subTextColor,
            fontSize: 13,
          ),
        ),

        const SizedBox(height: 16),

        ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: samplePlans.length,
          separatorBuilder: (context, index) {
            return const SizedBox(height: 12);
          },
          itemBuilder: (context, index) {
            return _PlanCard(
              item: samplePlans[index],
              index: index,
            );
          },
        ),

        const SizedBox(height: 30),

        SizedBox(
          width: double.infinity,
          height: 56,
          child: FilledButton.icon(
            onPressed: _savePlan,
            style: FilledButton.styleFrom(
              backgroundColor: _pinkColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            icon: const Icon(
              Icons.bookmark_add_outlined,
            ),
            label: const Text(
              '학습 플랜 저장하기',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        SizedBox(
          width: double.infinity,
          height: 54,
          child: OutlinedButton.icon(
            onPressed: _resetPlan,
            style: OutlinedButton.styleFrom(
              foregroundColor: _textColor,
              side: const BorderSide(
                color: _borderColor,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            icon: const Icon(
              Icons.refresh_rounded,
            ),
            label: const Text(
              '다시 생성하기',
              style: TextStyle(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PageGuideCard extends StatelessWidget {
  const _PageGuideCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            color: _AiStudyPlanPageState._pinkColor,
            size: 28,
          ),

          SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '나에게 맞는 학습 계획을 만들어보세요.',
                  style: TextStyle(
                    color: _AiStudyPlanPageState._textColor,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                SizedBox(height: 8),

                Text(
                  '시험 일정과 가능한 공부 시간을 기준으로 '
                      '일일 학습량을 배정합니다.',
                  style: TextStyle(
                    color: _AiStudyPlanPageState._subTextColor,
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
  final String number;
  final String title;
  final String description;

  const _SectionTitle({
    required this.number,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: Color(0xFFEDE6FF),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                number,
                style: const TextStyle(
                  color: _AiStudyPlanPageState._purpleColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: _AiStudyPlanPageState._textColor,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        Padding(
          padding: const EdgeInsets.only(
            left: 38,
          ),
          child: Text(
            description,
            style: const TextStyle(
              color: _AiStudyPlanPageState._subTextColor,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _AddTimeSlotSheet extends StatefulWidget {
  const _AddTimeSlotSheet();

  @override
  State<_AddTimeSlotSheet> createState() {
    return _AddTimeSlotSheetState();
  }
}

class _AddTimeSlotSheetState extends State<_AddTimeSlotSheet> {
  static const List<String> _days = [
    '월',
    '화',
    '수',
    '목',
    '금',
    '토',
    '일',
  ];

  final Set<String> _selectedDays = {};

  TimeOfDay _startTime = const TimeOfDay(
    hour: 20,
    minute: 0,
  );

  TimeOfDay _endTime = const TimeOfDay(
    hour: 22,
    minute: 0,
  );

  Future<void> _selectTime({
    required bool isStart,
  }) async {
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
      helpText: isStart ? '시작 시간 선택' : '종료 시간 선택',
      cancelText: '취소',
      confirmText: '선택',
    );

    if (selectedTime == null) {
      return;
    }

    setState(() {
      if (isStart) {
        _startTime = selectedTime;
      } else {
        _endTime = selectedTime;
      }
    });
  }

  int _toMinutes(TimeOfDay time) {
    return time.hour * 60 + time.minute;
  }

  void _addTimeSlot() {
    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('요일을 한 개 이상 선택해주세요.'),
        ),
      );

      return;
    }

    if (_toMinutes(_endTime) <= _toMinutes(_startTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('종료 시간은 시작 시간보다 늦어야 합니다.'),
        ),
      );

      return;
    }

    final orderedDays = _days.where((day) {
      return _selectedDays.contains(day);
    }).toList();

    Navigator.pop(
      context,
      _StudyTimeSlot(
        days: orderedDays,
        startTime: _startTime,
        endTime: _endTime,
      ),
    );
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        22,
        24,
        MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '공부 시간대 추가',
                    style: TextStyle(
                      color: _AiStudyPlanPageState._textColor,
                      fontSize: 21,
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
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            const Text(
              '요일 선택',
              style: TextStyle(
                color: _AiStudyPlanPageState._textColor,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 12),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _days.map((day) {
                final isSelected = _selectedDays.contains(day);

                return FilterChip(
                  label: Text(day),
                  selected: isSelected,
                  showCheckmark: false,
                  selectedColor: const Color(0xFFEDE6FF),
                  backgroundColor: const Color(0xFFF8F5F6),
                  side: BorderSide(
                    color: isSelected
                        ? _AiStudyPlanPageState._purpleColor
                        : const Color(0xFFE8E1E4),
                  ),
                  labelStyle: TextStyle(
                    color: isSelected
                        ? _AiStudyPlanPageState._purpleColor
                        : _AiStudyPlanPageState._subTextColor,
                    fontWeight: FontWeight.w800,
                  ),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedDays.add(day);
                      } else {
                        _selectedDays.remove(day);
                      }
                    });
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            const Text(
              '시간 선택',
              style: TextStyle(
                color: _AiStudyPlanPageState._textColor,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _TimePickerBox(
                    label: '시작 시간',
                    time: _formatTime(_startTime),
                    onTap: () {
                      _selectTime(isStart: true);
                    },
                  ),
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10,
                  ),
                  child: Text(
                    '~',
                    style: TextStyle(
                      color: _AiStudyPlanPageState._subTextColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),

                Expanded(
                  child: _TimePickerBox(
                    label: '종료 시간',
                    time: _formatTime(_endTime),
                    onTap: () {
                      _selectTime(isStart: false);
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 26),

            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                onPressed: _addTimeSlot,
                style: FilledButton.styleFrom(
                  backgroundColor:
                  _AiStudyPlanPageState._pinkColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: const Text(
                  '추가하기',
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
    );
  }
}

class _TimePickerBox extends StatelessWidget {
  final String label;
  final String time;
  final VoidCallback onTap;

  const _TimePickerBox({
    required this.label,
    required this.time,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: const Color(0xFFF9F6F7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFE8E1E4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: _AiStudyPlanPageState._subTextColor,
                fontSize: 12,
              ),
            ),

            const SizedBox(height: 6),

            Row(
              children: [
                const Icon(
                  Icons.schedule_rounded,
                  color: _AiStudyPlanPageState._purpleColor,
                  size: 18,
                ),

                const SizedBox(width: 6),

                Text(
                  time,
                  style: const TextStyle(
                    color: _AiStudyPlanPageState._textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final _DailyPlanItem item;
  final int index;

  const _PlanCard({
    required this.item,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final isEven = index.isEven;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE8E1E4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isEven
                  ? const Color(0xFFEDE6FF)
                  : const Color(0xFFFFE8EE),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '${index + 1}',
              style: TextStyle(
                color: isEven
                    ? _AiStudyPlanPageState._purpleColor
                    : _AiStudyPlanPageState._pinkColor,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.day,
                  style: const TextStyle(
                    color: _AiStudyPlanPageState._subTextColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  item.title,
                  style: const TextStyle(
                    color: _AiStudyPlanPageState._textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 7),

                Text(
                  item.detail,
                  style: const TextStyle(
                    color: _AiStudyPlanPageState._subTextColor,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),

                const SizedBox(height: 10),

                Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 16,
                      color:
                      _AiStudyPlanPageState._purpleColor,
                    ),

                    const SizedBox(width: 5),

                    Text(
                      item.duration,
                      style: const TextStyle(
                        color:
                        _AiStudyPlanPageState._purpleColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CertificateOption {
  final String name;
  final List<String> rounds;

  const _CertificateOption({
    required this.name,
    required this.rounds,
  });
}

class _StudyTimeSlot {
  final List<String> days;
  final TimeOfDay startTime;
  final TimeOfDay endTime;

  const _StudyTimeSlot({
    required this.days,
    required this.startTime,
    required this.endTime,
  });

  String get dayLabel {
    return days.join(' · ');
  }

  String formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }
}

class _DailyPlanItem {
  final String day;
  final String title;
  final String detail;
  final String duration;

  const _DailyPlanItem({
    required this.day,
    required this.title,
    required this.detail,
    required this.duration,
  });
}