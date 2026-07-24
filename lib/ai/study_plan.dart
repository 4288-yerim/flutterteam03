import 'dart:async';
import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'services/study_plan_ai_service.dart';
import '../widgets/app_main_background.dart';
import '../widgets/app_top_bar.dart';

class AiStudyPlanPage extends StatefulWidget {
  const AiStudyPlanPage({super.key});

  @override
  State<AiStudyPlanPage> createState() => _AiStudyPlanPageState();
}

class _AiStudyPlanPageState extends State<AiStudyPlanPage>
    with SingleTickerProviderStateMixin {
  static const Color _textColor = Color(0xFF302C2E);
  static const Color _subTextColor = Color(0xFF8E8589);
  static const Color _pinkColor = Color(0xFFE8879C);
  static const Color _pinkSoft = Color(0xFFF6E9EC);
  static const Color _pinkAccent = Color(0xFFEDA0AE);
  static const Color _purpleColor = Color(0xFFA48CDB);
  static const Color _borderColor = Color(0xFFE8E1E4);

  static const List<String> _genMessages = [
    '입력하신 정보를 확인하고 있어요',
    '학습 가능 시간을 계산하고 있어요',
    '단계별 학습 강도를 배분하고 있어요',
    '학습 플랜을 구성하고 있어요',
    '거의 다 됐어요',
    '이제 보여드릴게요',
  ];
  static const List<int> _genDurations = [1000, 1200, 1400, 1200, 800, 500];

  final PageController _pageController = PageController();
  int _currentStep = 0; // 0: 자격증/회차, 1: 날짜/시간대/복습, 2: 결과

  late final AnimationController _loadingController;

  final TextEditingController _certificateSearchController =
  TextEditingController();

  final List<_CertificateOption> _certificateOptions = [];
  bool _isLoadingCertificates = true;

  final TextEditingController _manualRoundController = TextEditingController();

  final List<_StudyTimeSlot> _timeSlots = [];

  String _searchKeyword = '';

  _CertificateOption? _selectedCertificate;
  String? _selectedRound;
  DateTime? _studyStartDate;

  List<String> _availableRounds = [];
  bool _isLoadingRounds = false;
  bool _isManualEntry = false;
  final Map<String, DateTime?> _roundExamDates = {};
  DateTime? _examDate;
  bool _examDateAutoFilled = false;
  bool _includeReview = true;
  bool _isGenerating = false;
  bool _isSavingPlan = false;

  final List<DateTime> _excludedDates = [];

  final StudyPlanAiService _aiService = StudyPlanAiService();
  List<StudyPlanDayResult> _generatedPlan = [];

  @override
  void initState() {
    super.initState();
    _loadingController = AnimationController(vsync: this);
    _aiService.loadModel();
    _loadCertificates();
  }

  Future<void> _loadCertificates() async {
    try {
      final snapshot =
      await FirebaseFirestore.instance.collection('certifications').get();
      if (!mounted) return;
      setState(() {
        _certificateOptions
          ..clear()
          ..addAll(snapshot.docs.map(_CertificateOption.fromDoc));
        _isLoadingCertificates = false;
      });
    } catch (e) {
      debugPrint('자격증 목록 조회 실패: $e');
      if (!mounted) return;
      setState(() => _isLoadingCertificates = false);
    }
  }

  Future<void> _fetchRoundsForCertificate(_CertificateOption certificate) async {
    setState(() {
      _isLoadingRounds = true;
      _availableRounds = [];
      _selectedRound = null;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('certifications')
          .doc(certificate.jmcd)
          .collection('schedules')
          .orderBy('sortdate', descending: false)
          .get();

      final roundField =
      certificate.qualgbcd == 'T' ? 'implplannm' : 'description';

      final now = Timestamp.now();

      final validDocs = snapshot.docs.where((doc) {
        final data = doc.data();
        final candidates = [
          data['pracpassendat'],
          data['docpassat'],
          data['pracexamendat'],
          data['sortdate'],
        ].whereType<Timestamp>().toList();

        if (candidates.isEmpty) return true;
        candidates.sort((a, b) => a.compareTo(b));
        final latestEndDate = candidates.last;
        return latestEndDate.compareTo(now) >= 0;
      }).toList();

      final rounds = <String>[];
      final examDates = <String, DateTime?>{};

      for (final doc in validDocs) {
        final data = doc.data();
        final label = data[roundField] as String?;
        if (label == null) continue;

        rounds.add(label);
        // 필기(서류) 시험일 우선, 없으면 실기 시험일
        final docExam = (data['docexamstartat'] as Timestamp?)?.toDate();
        final pracExam = (data['pracexamstartat'] as Timestamp?)?.toDate();
        examDates[label] = docExam ?? pracExam;
      }

      if (!mounted) return;
      setState(() {
        _availableRounds = rounds;
        _roundExamDates
          ..clear()
          ..addAll(examDates);
        _isLoadingRounds = false;
      });
    } catch (e) {
      debugPrint('회차 조회 실패: $e');
      if (!mounted) return;
      setState(() => _isLoadingRounds = false);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _loadingController.dispose();
    _aiService.dispose();
    _certificateSearchController.dispose();
    _manualRoundController.dispose();
    super.dispose();
  }

  List<_CertificateOption> get _filteredCertificates {
    final keyword = _searchKeyword.trim().toLowerCase();
    if (keyword.isEmpty) return [];

    return _certificateOptions.where((certificate) {
      return certificate.name.toLowerCase().contains(keyword);
    }).toList();
  }

  void _goToStep(int step) {
    setState(() => _currentStep = step);
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _onNextFromStep0() {
    if (_selectedCertificate == null) {
      _showMessage('자격증을 선택해주세요.');
      return;
    }
    final round = _isManualEntry
        ? _manualRoundController.text.trim()
        : (_selectedRound ?? '');
    if (round.isEmpty) {
      _showMessage('시험 회차를 선택해주세요.');
      return;
    }
    _selectedRound = round;
    _goToStep(1);
  }

  Future<void> _selectStudyStartDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final selectedDate = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DatePickerSheet(
        initialDate: _studyStartDate ?? today,
        firstDate: today,
        lastDate: DateTime(now.year + 3, 12, 31),
        title: '공부 시작 날짜',
      ),
    );

    if (selectedDate == null) return;

    setState(() {
      _studyStartDate = selectedDate;
    });
  }

  Future<void> _selectExamDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DatePickerSheet(
        initialDate: _examDate ?? (_studyStartDate ?? today),
        firstDate: _studyStartDate ?? today,
        lastDate: DateTime(now.year + 3, 12, 31),
        title: '시험 날짜',
      ),
    );

    if (picked == null) return;

    setState(() {
      _examDate = picked;
      _examDateAutoFilled = false;
    });
  }

  Future<void> _openAddTimeSlotSheet() async {
    final result = await showModalBottomSheet<_StudyTimeSlot>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _AddTimeSlotSheet(),
    );

    if (result == null) return;

    setState(() {
      _timeSlots.add(result);
    });
  }

  Future<void> _addExcludedDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final picked = await showModalBottomSheet<List<DateTime>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _MultiDatePickerSheet(
        initialSelectedDates: _excludedDates,
        firstDate: _studyStartDate ?? today,
        lastDate: DateTime(now.year + 3, 12, 31),
        title: '제외할 날짜',
      ),
    );

    if (picked == null) return;

    setState(() {
      _excludedDates
        ..clear()
        ..addAll(picked)
        ..sort();
    });
  }

  void _removeExcludedDate(DateTime date) {
    setState(() {
      _excludedDates.removeWhere((d) =>
      d.year == date.year && d.month == date.month && d.day == date.day);
    });
  }

  void _selectCertificate(_CertificateOption certificate) {
    setState(() {
      _selectedCertificate = certificate;
      _selectedRound = null;
      _isManualEntry = false;
      _searchKeyword = '';
      _certificateSearchController.text = certificate.name;
      _examDate = null;
      _examDateAutoFilled = false;
    });
    _fetchRoundsForCertificate(certificate);
  }

  void _continueWithManualCertificate() {
    final name = _certificateSearchController.text.trim();
    if (name.isEmpty) return;

    setState(() {
      _selectedCertificate = _CertificateOption.manual(name);
      _selectedRound = null;
      _isManualEntry = true;
      _availableRounds = [];
      _manualRoundController.clear();
      _examDate = null;
      _examDateAutoFilled = false;
    });
  }

  void _removeSelectedCertificate() {
    setState(() {
      _certificateSearchController.clear();
      _searchKeyword = '';
      _selectedCertificate = null;
      _selectedRound = null;
      _isManualEntry = false;
      _availableRounds = [];
      _manualRoundController.clear();
      _examDate = null;
      _examDateAutoFilled = false;
    });
  }
  void _removeTimeSlot(int index) {
    setState(() {
      _timeSlots.removeAt(index);
    });
  }

  Duration _minLoadingDuration() {
    final sum = _genDurations.fold<int>(0, (a, b) => a + b);
    return Duration(milliseconds: sum);
  }

  Future<void> _generatePlan() async {
    if (_studyStartDate == null) {
      _showMessage('공부 시작 날짜를 선택해주세요.');
      return;
    }
    if (_examDate == null) {
      _showMessage('시험 날짜를 선택해주세요.');
      return;
    }
    if (_examDate!.isBefore(_studyStartDate!)) {
      _showMessage('시험 날짜는 공부 시작일 이후여야 해요.');
      return;
    }
    if (_timeSlots.isEmpty) {
      _showMessage('선호 공부 시간대를 한 개 이상 추가해주세요.');
      return;
    }

    final studyDates = _buildStudyDates();
    if (studyDates.isEmpty) {
      _showMessage('선택하신 요일/제외 날짜 조건으로는 공부 가능한 날이 없어요. 다시 확인해주세요.');
      return;
    }

    setState(() => _isGenerating = true);

    final stopwatch = Stopwatch()..start();

    if (!_aiService.isLoaded) {
      await _aiService.loadModel();
    }

    final dailyHoursAvg = _averageDailyHours();
    final difficulty =
    StudyPlanAiService.difficultyForCertificate(_selectedCertificate!.name);

    final totalDays = studyDates.length;

    final rawResults = _aiService.generatePlan(
      totalDays: totalDays,
      dailyHoursAvg: dailyHoursAvg,
      difficultyTier: difficulty,
      includeReview: _includeReview,
    );

    final generatedDays = <StudyPlanDayResult>[];
    for (var i = 0; i < rawResults.length; i++) {
      final original = rawResults[i];
      final date = i < studyDates.length ? studyDates[i] : null;
      final isReviewDay = original.dayLabel == '복습일';
      final label = date != null
          ? (isReviewDay
          ? '${_formatDateWithWeekday(date)} · 복습'
          : _formatDateWithWeekday(date))
          : original.dayLabel;

      generatedDays.add(
        StudyPlanDayResult(
          dayIndex: original.dayIndex,
          dayLabel: label,
          title: original.title,
          detail: original.detail,
          duration: original.duration,
        ),
      );
    }

    stopwatch.stop();

    final minDuration = _minLoadingDuration();
    if (stopwatch.elapsed < minDuration) {
      await Future.delayed(minDuration - stopwatch.elapsed);
    }

    if (!mounted) return;

    setState(() {
      _generatedPlan = generatedDays;
      _isGenerating = false;
    });

    _goToStep(2);
  }

  double _averageDailyHours() {
    final totalMinutes = _timeSlots.fold<int>(0, (sum, slot) {
      final start = slot.startTime.hour * 60 + slot.startTime.minute;
      final end = slot.endTime.hour * 60 + slot.endTime.minute;
      return sum + (end - start) * slot.days.length;
    });
    return (totalMinutes / 60) / 7;
  }

  Future<void> _savePlan() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _showMessage('로그인 후 저장할 수 있어요.');
      return;
    }
    if (_generatedPlan.isEmpty || _selectedCertificate == null) return;

    setState(() => _isSavingPlan = true);

    try {
      final steps = _generatedPlan.asMap().entries.map((entry) {
        final order = entry.key + 1;
        final day = entry.value;
        return {
          'order': order,
          'dayLabel': day.dayLabel,
          'title': day.title,
          'detail': day.detail,
          'duration': day.duration,
          'isCompleted': false,
        };
      }).toList();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('studyPlans')
          .add({
        'certificateId': _selectedCertificate!.jmcd,
        'certificateName': _selectedCertificate!.name,
        'scheduleName': _selectedRound,
        'examStartAt': _examDate != null ? Timestamp.fromDate(_examDate!) : null,
        'recommendedStudyStartDate':
        _studyStartDate != null ? _formatDateYmd(_studyStartDate!) : null,
        'steps': steps,
        'totalStepCount': steps.length,
        'completedStepCount': 0,
        'completionRate': 0,
        'status': 'NOT_STARTED',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      setState(() => _isSavingPlan = false);
      _showMessage('학습 플랜이 저장됐어요.');
    } catch (e) {
      debugPrint('학습 플랜 저장 실패: $e');
      if (!mounted) return;
      setState(() => _isSavingPlan = false);
      _showMessage('저장에 실패했어요. 잠시 후 다시 시도해주세요.');
    }
  }

  Future<bool?> _showExitDuringGenerationSheet() {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _ExitDuringGenerationSheet(),
    );
  }

  Future<void> _showRegeneratePlanSheet() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _RegeneratePlanSheet(),
    );

    if (choice == 'full') {
      _resetPlanFull();
    } else if (choice == 'keep') {
      _resetPlanKeepCertificate();
    }
  }

  void _resetPlanFull() {
    setState(() {
      _certificateSearchController.clear();
      _searchKeyword = '';
      _selectedCertificate = null;
      _selectedRound = null;
      _isManualEntry = false;
      _availableRounds = [];
      _manualRoundController.clear();
      _studyStartDate = null;
      _timeSlots.clear();
      _excludedDates.clear();
      _includeReview = true;
      _generatedPlan = [];
      _examDate = null;
      _examDateAutoFilled = false;
    });
    _goToStep(0);
  }

  void _resetPlanKeepCertificate() {
    setState(() {
      _studyStartDate = null;
      _timeSlots.clear();
      _excludedDates.clear();
      _includeReview = true;
      _generatedPlan = [];
    });
    _goToStep(1);
  }
  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}.$month.$day';
  }

  String _formatDateYmd(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  static const List<String> _weekdayShort = ['월', '화', '수', '목', '금', '토', '일'];

  String _formatDateWithWeekday(DateTime date) {
    final wd = _weekdayShort[date.weekday - 1];
    return '${date.month}/${date.day}($wd)';
  }

  List<DateTime> _buildStudyDates() {
    if (_studyStartDate == null || _examDate == null) return [];

    const dayMap = {'월': 1, '화': 2, '수': 3, '목': 4, '금': 5, '토': 6, '일': 7};
    final availableWeekdays = <int>{};
    for (final slot in _timeSlots) {
      for (final d in slot.days) {
        final wd = dayMap[d];
        if (wd != null) availableWeekdays.add(wd);
      }
    }
    if (availableWeekdays.isEmpty) return [];

    final dates = <DateTime>[];
    var cursor = DateTime(_studyStartDate!.year, _studyStartDate!.month, _studyStartDate!.day);
    final end = DateTime(_examDate!.year, _examDate!.month, _examDate!.day);

    while (!cursor.isAfter(end)) {
      final isExcluded = _excludedDates.any((d) =>
      d.year == cursor.year && d.month == cursor.month && d.day == cursor.day);
      if (!isExcluded && availableWeekdays.contains(cursor.weekday)) {
        dates.add(cursor);
      }
      cursor = cursor.add(const Duration(days: 1));
    }
    return dates;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        if (_isGenerating) {
          final shouldExit = await _showExitDuringGenerationSheet();
          if (shouldExit == true && mounted) {
            Navigator.of(context).pop();
          }
          return;
        }

        Navigator.of(context).pop();
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: Colors.transparent,
        appBar: AppTopBar(
          title: 'AI 학습 플랜',
          centerTitle: false,
          leading: (_currentStep == 1 && !_isGenerating)
              ? IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            onPressed: () => _goToStep(0),
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
                        children: [
                          _buildStep0(),
                          _buildStep1(),
                          _buildStep2Result(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (_isGenerating)
                Positioned.fill(
                  child: Container(
                    color: Colors.white.withValues(alpha: 0.92),
                    child: Align(
                      alignment: const Alignment(0, -0.15),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: _RotatingLoadingContent(
                          messages: _genMessages,
                          durations: _genDurations,
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

  Widget _buildStep0() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Align(
              alignment: const Alignment(0, -0.45),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _FadeSlideIn(
                    duration: const Duration(milliseconds: 600),
                    child: const Center(child: _HeroBadge()),
                  ),
                  const SizedBox(height: 14),
                  _FadeSlideIn(
                    delay: const Duration(milliseconds: 150),
                    duration: const Duration(milliseconds: 700),
                    child: Column(
                      children: [
                        const Text(
                          '나에게 맞는 학습 계획을 만들어보세요.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _textColor,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '시험 일정과 가능한 공부 시간을 기준으로 학습 계획을 생성합니다.',
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
                  const SizedBox(height: 22),
                  _FadeSlideIn(
                    delay: const Duration(milliseconds: 320),
                    duration: const Duration(milliseconds: 700),
                    child: const Align(
                      alignment: Alignment.centerLeft,
                      child: _SectionTitle(
                        title: '응시할 자격증과 회차',
                        isRequired: true,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _FadeSlideIn(
                    delay: const Duration(milliseconds: 480),
                    duration: const Duration(milliseconds: 700),
                    child: _buildCertificateSearch(),
                  ),
                  if (_selectedCertificate != null) ...[
                    const SizedBox(height: 14),
                    _buildSelectedCertificateCard(),
                    const SizedBox(height: 14),
                    _buildRoundSelector(),
                  ],
                  const SizedBox(height: 34),
                  _FadeSlideIn(
                    delay: const Duration(milliseconds: 620),
                    duration: const Duration(milliseconds: 700),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: const LinearGradient(
                            colors: [_pinkColor, _pinkAccent],
                          ),
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
                            onTap: _onNextFromStep0,
                            child: const Center(
                              child: Text(
                                '다음',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStep1() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 40),
          child: _FadeSlideIn(
            duration: const Duration(milliseconds: 600),
            child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionTitle(
                      title: '시험 날짜',
                      isRequired: true,
                    ),
                    const SizedBox(height: 12),
                    _buildExamDateSelector(),
                    const SizedBox(height: 28),
                    const _SectionTitle(
                      title: '공부 시작 날짜',
                      isRequired: true,
                    ),
                    const SizedBox(height: 12),
                    _buildDateSelector(),
                    const SizedBox(height: 28),
                    const _SectionTitle(
                      title: '선호 공부 시간대',
                      isRequired: true,
                    ),
                    const SizedBox(height: 12),
                    _buildTimeSlotArea(),
                    const SizedBox(height: 28),
                    const _SectionTitle(title: '복습 포함 여부'),
                    const SizedBox(height: 12),
                    _buildReviewSelector(),
                    const SizedBox(height: 28),
                    const _SectionTitle(title: '공부 제외 날짜'),
                    const SizedBox(height: 12),
                    _buildExcludedDatesArea(),
                    const SizedBox(height: 34),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: const LinearGradient(
                            colors: [_pinkColor, _pinkAccent],
                          ),
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
                            onTap: _isGenerating ? null : _generatePlan,
                            child: const Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.auto_awesome_rounded,
                                      color: Colors.white),
                                  SizedBox(width: 8),
                                  Text(
                                    'AI 학습 플랜 생성하기',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
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
        );
      },
    );
  }

  Widget _buildCertificateSearch() {
    final filteredCertificates = _filteredCertificates;

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _pinkSoft),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14C98198),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: TextField(
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
            style: const TextStyle(
              color: _textColor,
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              hintText: '예: 정보처리기사',
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
              contentPadding: const EdgeInsets.fromLTRB(6, 17, 6, 17),
              border: InputBorder.none,
            ),
          ),
        ),
        if (_searchKeyword.trim().isNotEmpty &&
            _selectedCertificate == null) ...[
          const SizedBox(height: 8),
          if (_isLoadingCertificates)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _borderColor),
              ),
              child: const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: _purpleColor,
                  ),
                ),
              ),
            )
          else if (filteredCertificates.isEmpty)
            _buildNotFoundWarning()
          else
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 250),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                shrinkWrap: true,
                itemCount: filteredCertificates.length,
                separatorBuilder: (context, index) => const Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: Color(0xFFF1ECEE),
                ),
                itemBuilder: (context, index) {
                  final certificate = filteredCertificates[index];
                  return ListTile(
                    onTap: () => _selectCertificate(certificate),
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
                      certificate.qualgbcd == 'T' ? '국가기술자격' : '국가전문자격',
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

  Widget _buildNotFoundWarning() {
    final typedName = _certificateSearchController.text.trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFCE5AE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: Color(0xFFCA9A2E),
                size: 20,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '목록에서 자격증을 찾지 못했어요.',
                  style: TextStyle(
                    color: _textColor,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            '자격증명을 다시 확인해보시거나, 그래도 이 이름으로 진행할 수 있어요. '
                '이 경우 회차는 직접 입력해주셔야 해요.',
            style: TextStyle(
              color: _subTextColor,
              fontSize: 12.5,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton(
              onPressed: typedName.isEmpty ? null : _continueWithManualCertificate,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFCA9A2E),
                side: const BorderSide(color: Color(0xFFE9C167)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                '"$typedName"(으)로 그래도 진행하기',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedCertificateCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF3EEFF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              color: _purpleColor,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      '선택한 자격증',
                      style: TextStyle(
                        color: _subTextColor,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (!_isManualEntry) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _selectedCertificate!.qualgbcd == 'T'
                              ? '국가기술자격'
                              : '국가전문자격',
                          style: const TextStyle(
                            color: _purpleColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                    if (_isManualEntry) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7E8),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFCE5AE)),
                        ),
                        child: const Text(
                          '직접 입력',
                          style: TextStyle(
                            color: Color(0xFFCA9A2E),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  _selectedCertificate!.name,
                  style: const TextStyle(
                    color: _textColor,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _removeSelectedCertificate,
            icon: const Icon(Icons.close_rounded, color: _subTextColor),
          ),
        ],
      ),
    );
  }
  Widget _buildRoundSelector() {
    if (_isManualEntry) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _borderColor),
        ),
        child: TextField(
          controller: _manualRoundController,
          style: const TextStyle(
            color: _textColor,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
          decoration: const InputDecoration(
            labelText: '시험 회차 (직접 입력)',
            labelStyle: TextStyle(color: _subTextColor, fontSize: 13),
            hintText: '예: 2026년 2회',
            prefixIcon: Icon(Icons.event_available_outlined, color: _purpleColor),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      );
    }

    if (_isLoadingRounds) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _borderColor),
        ),
        child: const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: _purpleColor),
          ),
        ),
      );
    }

    if (_availableRounds.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _borderColor),
        ),
        child: const Text(
          '등록된 회차 정보가 없어요.',
          style: TextStyle(color: _subTextColor, fontSize: 13),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderColor),
      ),
      child: DropdownButtonFormField<String>(
        value: _selectedRound,
        isExpanded: true,
        icon: const Padding(
          padding: EdgeInsets.only(right: 6),
          child: Icon(Icons.keyboard_arrow_down_rounded, color: _purpleColor),
        ),
        decoration: const InputDecoration(
          labelText: '시험 회차',
          labelStyle: TextStyle(color: _subTextColor, fontSize: 13),
          prefixIcon: Icon(Icons.event_available_outlined, color: _purpleColor),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 16),
        ),
        style: const TextStyle(
          color: _textColor,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
        items: _availableRounds.map((round) {
          return DropdownMenuItem<String>(value: round, child: Text(round));
        }).toList(),
        onChanged: (value) {
          setState(() {
            _selectedRound = value;
            final fetchedDate = value != null ? _roundExamDates[value] : null;
            _examDate = fetchedDate;
            _examDateAutoFilled = fetchedDate != null;
          });
        },
      ),
    );
  }

  Widget _buildDateSelector() {
    return InkWell(
      onTap: _selectStudyStartDate,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _borderColor),
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
            const Icon(Icons.chevron_right_rounded, color: _subTextColor),
          ],
        ),
      ),
    );
  }

  Widget _buildExamDateSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: _selectExamDate,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _borderColor),
            ),
            child: Row(
              children: [
                const Icon(Icons.event_rounded, color: _purpleColor, size: 22),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    _examDate == null ? '시험 날짜를 선택해주세요.' : _formatDate(_examDate!),
                    style: TextStyle(
                      color: _examDate == null ? const Color(0xFFB2A9AD) : _textColor,
                      fontSize: 15,
                      fontWeight: _examDate == null ? FontWeight.w500 : FontWeight.w700,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: _subTextColor),
              ],
            ),
          ),
        ),
        if (_examDateAutoFilled && _examDate != null) ...[
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 1.5),
                child: Icon(Icons.info_outline_rounded, size: 13, color: _purpleColor),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  '등록된 회차 정보로 자동 입력됐어요. 실제 시험일과 다르면 위를 눌러 수정해주세요.',
                  style: TextStyle(color: _subTextColor, fontSize: 11.5, height: 1.4),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildTimeSlotArea() {
    return Column(
      children: [
        if (_timeSlots.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _borderColor),
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
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final slot = _timeSlots[index];
              return Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _borderColor),
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
                            '${slot.formatTime(slot.startTime)} ~ '
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
                      onPressed: () => _removeTimeSlot(index),
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
              side: const BorderSide(color: Color(0xFFCFC1FF)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            icon: const Icon(Icons.add_rounded),
            label: const Text(
              '시간대 추가하기',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewSelector() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 14, 12, 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderColor),
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
              setState(() => _includeReview = value);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildExcludedDatesArea() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_excludedDates.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _excludedDates.map((date) {
              return Chip(
                label: Text(_formatDate(date)),
                onDeleted: () => _removeExcludedDate(date),
                backgroundColor: Colors.white,
                side: const BorderSide(color: _borderColor),
                labelStyle: const TextStyle(
                  color: _textColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
                deleteIconColor: _subTextColor,
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
        ],
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: _addExcludedDate,
            style: OutlinedButton.styleFrom(
              foregroundColor: _purpleColor,
              side: const BorderSide(color: Color(0xFFCFC1FF)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.event_busy_rounded, size: 18),
            label: const Text(
              '제외할 날짜 추가',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2Result() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 40),
      child: _FadeSlideIn(
        duration: const Duration(milliseconds: 600),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFFE4ED), Color(0xFFF1E9FF)],
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
                    '${_selectedCertificate?.name ?? ''} 학습 플랜',
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
                        '${_studyStartDate != null ? _formatDate(_studyStartDate!) : ''} 시작'
                        '${_examDate != null ? ' · 시험일 ${_formatDate(_examDate!)}' : ''}',
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
              'AI가 자동으로 배정한 학습 계획입니다.',
              style: TextStyle(color: _subTextColor, fontSize: 13),
            ),
            const SizedBox(height: 16),
            ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: _generatedPlan.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final result = _generatedPlan[index];
                final item = _DailyPlanItem(
                  day: result.dayLabel,
                  title: result.title,
                  detail: result.detail,
                  duration: result.duration,
                );
                return _PlanCard(item: item, index: index);
              },
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                onPressed: _isSavingPlan ? null : _savePlan,
                style: FilledButton.styleFrom(
                  backgroundColor: _pinkColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                icon: _isSavingPlan
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.white,
                  ),
                )
                    : const Icon(Icons.bookmark_add_outlined),
                label: Text(
                  _isSavingPlan ? '저장 중...' : '학습 플랜 저장하기',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: OutlinedButton.icon(
                onPressed: _showRegeneratePlanSheet,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _textColor,
                  side: const BorderSide(color: _borderColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text(
                  '다시 생성하기',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
            _AiStudyPlanPageState._pinkColor,
            _AiStudyPlanPageState._pinkAccent,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _AiStudyPlanPageState._pinkColor.withValues(alpha: 0.35),
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
      children: List.generate(3, (i) {
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
              _AiStudyPlanPageState._pinkColor,
              _AiStudyPlanPageState._pinkAccent,
            ])
                : null,
            color:
            (active || done) ? null : _AiStudyPlanPageState._pinkSoft,
          ),
        );
      }),
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
            color: _AiStudyPlanPageState._textColor,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (isRequired) ...[
          const SizedBox(width: 4),
          const Text(
            '*',
            style: TextStyle(
              color: _AiStudyPlanPageState._pinkColor,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ],
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

class _WaveLoadingIndicator extends StatefulWidget {
  final double size;
  final double progress;

  const _WaveLoadingIndicator({this.size = 72, required this.progress});

  @override
  State<_WaveLoadingIndicator> createState() => _WaveLoadingIndicatorState();
}

class _WaveLoadingIndicatorState extends State<_WaveLoadingIndicator>
    with TickerProviderStateMixin {
  late final AnimationController _levelController;
  late Animation<double> _levelAnimation;
  late final AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _levelController =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _levelAnimation = Tween<double>(begin: 0, end: widget.progress).animate(
      CurvedAnimation(parent: _levelController, curve: Curves.easeOut),
    );
    _levelController.forward();

    _waveController =
    AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat();
  }

  @override
  void didUpdateWidget(covariant _WaveLoadingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      _levelAnimation = Tween<double>(
        begin: _levelAnimation.value,
        end: widget.progress,
      ).animate(CurvedAnimation(parent: _levelController, curve: Curves.easeOut));
      _levelController
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _levelController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: const BoxDecoration(shape: BoxShape.circle),
      child: ClipOval(
        child: AnimatedBuilder(
          animation: Listenable.merge([_levelController, _waveController]),
          builder: (context, _) {
            return CustomPaint(
              size: Size(widget.size, widget.size),
              painter: _WavePainter(
                level: _levelAnimation.value,
                wavePhase: _waveController.value,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  final double level;
  final double wavePhase;

  const _WavePainter({required this.level, required this.wavePhase});

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFFFFF3F5);
    canvas.drawRect(Offset.zero & size, bgPaint);

    final baseY = size.height * (1 - level);
    final waveHeight = size.height * 0.045;

    final path = Path()..moveTo(0, baseY);
    for (double x = 0; x <= size.width; x += 2) {
      final y = baseY +
          math.sin((x / size.width * 2 * math.pi) + wavePhase * 2 * math.pi) *
              waveHeight;
      path.lineTo(x, y);
    }
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    final wavePaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFF4869D), Color(0xFFFF8FA3)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Offset.zero & size);

    canvas.drawPath(path, wavePaint);
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) =>
      oldDelegate.level != level || oldDelegate.wavePhase != wavePhase;
}

class _RotatingLoadingContent extends StatefulWidget {
  final List<String> messages;
  final List<int> durations;

  const _RotatingLoadingContent({
    required this.messages,
    required this.durations,
  });

  @override
  State<_RotatingLoadingContent> createState() =>
      _RotatingLoadingContentState();
}

class _RotatingLoadingContentState extends State<_RotatingLoadingContent>
    with SingleTickerProviderStateMixin {
  Timer? _messageTimer;
  int _messageIndex = 0;

  @override
  void initState() {
    super.initState();
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
    _messageTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _WaveLoadingIndicator(
          size: 72,
          progress: _messageIndex / (widget.messages.length - 1),
        ),
        const SizedBox(height: 26),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position:
              Tween(begin: const Offset(0, 0.15), end: Offset.zero).animate(anim),
              child: child,
            ),
          ),
          child: Text(
            widget.messages[_messageIndex],
            key: ValueKey(_messageIndex),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _AiStudyPlanPageState._textColor,
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
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
  State<_AddTimeSlotSheet> createState() => _AddTimeSlotSheetState();
}

class _AddTimeSlotSheetState extends State<_AddTimeSlotSheet> {
  static const List<String> _days = ['월', '화', '수', '목', '금', '토', '일'];

  final Set<String> _selectedDays = {};

  TimeOfDay _startTime = const TimeOfDay(hour: 20, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 22, minute: 0);

  String? _errorMessage;

  Future<void> _selectTime({required bool isStart}) async {
    final selectedTime = await showModalBottomSheet<TimeOfDay>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TimePickerSheet(
        initialTime: isStart ? _startTime : _endTime,
        title: isStart ? '시작 시간' : '종료 시간',
      ),
    );

    if (selectedTime == null) return;

    setState(() {
      if (isStart) {
        _startTime = selectedTime;
      } else {
        _endTime = selectedTime;
      }
    });
  }

  int _toMinutes(TimeOfDay time) => time.hour * 60 + time.minute;

  void _addTimeSlot() {
    if (_selectedDays.isEmpty) {
      setState(() => _errorMessage = '요일을 한 개 이상 선택해주세요.');
      return;
    }

    if (_toMinutes(_endTime) <= _toMinutes(_startTime)) {
      setState(() => _errorMessage = '종료 시간은 시작 시간보다 늦어야 합니다.');
      return;
    }

    final orderedDays =
    _days.where((day) => _selectedDays.contains(day)).toList();

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
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
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
            Row(
              children: _days.map((day) {
                final isSelected = _selectedDays.contains(day);
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedDays.remove(day);
                          } else {
                            _selectedDays.add(day);
                          }
                          _errorMessage = null;
                        });
                      },
                      child: Container(
                        height: 46,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFEDE6FF)
                              : const Color(0xFFF8F5F6),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? _AiStudyPlanPageState._purpleColor
                                : const Color(0xFFE8E1E4),
                          ),
                        ),
                        child: Text(
                          day,
                          style: TextStyle(
                            color: isSelected
                                ? _AiStudyPlanPageState._purpleColor
                                : _AiStudyPlanPageState._subTextColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
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
                    onTap: () => _selectTime(isStart: true),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
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
                    onTap: () => _selectTime(isStart: false),
                  ),
                ),
              ],
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0F0),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFD3D3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: Color(0xFFE0685E), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Color(0xFFE0685E),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 26),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                onPressed: _addTimeSlot,
                style: FilledButton.styleFrom(
                  backgroundColor: _AiStudyPlanPageState._pinkColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: const Text(
                  '추가하기',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
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
          border: Border.all(color: const Color(0xFFE8E1E4)),
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

class _DatePickerSheet extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final String title;

  const _DatePickerSheet({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.title,
  });

  @override
  State<_DatePickerSheet> createState() => _DatePickerSheetState();
}

class _DatePickerSheetState extends State<_DatePickerSheet> {
  static const List<String> _weekdays = ['일', '월', '화', '수', '목', '금', '토'];

  late DateTime _displayedMonth;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _displayedMonth = DateTime(widget.initialDate.year, widget.initialDate.month);
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isSelectable(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final first = DateTime(widget.firstDate.year, widget.firstDate.month, widget.firstDate.day);
    final last = DateTime(widget.lastDate.year, widget.lastDate.month, widget.lastDate.day);
    return !d.isBefore(first) && !d.isAfter(last);
  }

  void _changeMonth(int delta) {
    setState(() {
      _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month + delta);
    });
  }

  bool get _canGoPrev {
    final prevMonthLastDay =
    DateTime(_displayedMonth.year, _displayedMonth.month, 0);
    return !prevMonthLastDay.isBefore(
      DateTime(widget.firstDate.year, widget.firstDate.month, 1),
    );
  }

  bool get _canGoNext {
    final nextMonthFirstDay =
    DateTime(_displayedMonth.year, _displayedMonth.month + 1, 1);
    return !nextMonthFirstDay.isAfter(
      DateTime(widget.lastDate.year, widget.lastDate.month, widget.lastDate.day),
    );
  }

  @override
  Widget build(BuildContext context) {
    final firstWeekday = DateTime(_displayedMonth.year, _displayedMonth.month, 1).weekday % 7;
    final daysInMonth = DateTime(_displayedMonth.year, _displayedMonth.month + 1, 0).day;

    return Container(
      padding: EdgeInsets.fromLTRB(
        24, 22, 24, MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      color: _AiStudyPlanPageState._textColor,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_displayedMonth.year}년 ${_displayedMonth.month}월',
                  style: const TextStyle(
                    color: _AiStudyPlanPageState._textColor,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Row(
                  children: [
                    _MonthNavButton(
                      icon: Icons.chevron_left_rounded,
                      enabled: _canGoPrev,
                      onTap: () => _changeMonth(-1),
                    ),
                    const SizedBox(width: 6),
                    _MonthNavButton(
                      icon: Icons.chevron_right_rounded,
                      enabled: _canGoNext,
                      onTap: () => _changeMonth(1),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: _weekdays.map((w) {
                return Expanded(
                  child: Center(
                    child: Text(
                      w,
                      style: const TextStyle(
                        color: _AiStudyPlanPageState._subTextColor,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 6),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: firstWeekday + daysInMonth,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
              ),
              itemBuilder: (context, index) {
                if (index < firstWeekday) return const SizedBox.shrink();

                final day = index - firstWeekday + 1;
                final date = DateTime(_displayedMonth.year, _displayedMonth.month, day);
                final selectable = _isSelectable(date);
                final isSelected =
                    _selectedDate != null && _isSameDay(_selectedDate!, date);
                final isToday = _isSameDay(date, DateTime.now());

                return GestureDetector(
                  onTap: selectable
                      ? () => setState(() => _selectedDate = date)
                      : null,
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _AiStudyPlanPageState._purpleColor
                          : Colors.transparent,
                      shape: BoxShape.circle,
                      border: (isToday && !isSelected)
                          ? Border.all(color: _AiStudyPlanPageState._purpleColor, width: 1.4)
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$day',
                      style: TextStyle(
                        color: !selectable
                            ? const Color(0xFFD9D2D5)
                            : isSelected
                            ? Colors.white
                            : _AiStudyPlanPageState._textColor,
                        fontSize: 14.5,
                        fontWeight:
                        isSelected || isToday ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                onPressed: _selectedDate == null
                    ? null
                    : () => Navigator.pop(context, _selectedDate),
                style: FilledButton.styleFrom(
                  backgroundColor: _AiStudyPlanPageState._purpleColor,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFE8E1E4),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: const Text(
                  '선택 완료',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RegeneratePlanSheet extends StatelessWidget {
  const _RegeneratePlanSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        24, 22, 24, MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
                    '무엇을 다시 설정할까요?',
                    style: TextStyle(
                      color: _AiStudyPlanPageState._textColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              '전부 새로 고를지, 공부 일정만 바꿀지 선택해주세요.',
              style: TextStyle(
                color: _AiStudyPlanPageState._subTextColor,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 22),
            _RegenerateOption(
              icon: Icons.workspace_premium_outlined,
              iconBg: const Color(0xFFF3EEFF),
              iconColor: _AiStudyPlanPageState._purpleColor,
              title: '자격증부터 다시 선택',
              description: '자격증, 회차, 시험 날짜, 공부 일정을 모두 새로 설정해요.',
              onTap: () => Navigator.pop(context, 'full'),
            ),
            const SizedBox(height: 12),
            _RegenerateOption(
              icon: Icons.schedule_rounded,
              iconBg: const Color(0xFFFFE8EE),
              iconColor: _AiStudyPlanPageState._pinkColor,
              title: '공부 일정만 다시 설정',
              description: '선택한 자격증과 회차는 그대로 두고, 시작일·시간대만 바꿔요.',
              onTap: () => Navigator.pop(context, 'keep'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RegenerateOption extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _RegenerateOption({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFAF8F8),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE8E1E4)),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _AiStudyPlanPageState._textColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        color: _AiStudyPlanPageState._subTextColor,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: _AiStudyPlanPageState._subTextColor),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimePickerSheet extends StatefulWidget {
  final TimeOfDay initialTime;
  final String title;

  const _TimePickerSheet({
    required this.initialTime,
    required this.title,
  });

  @override
  State<_TimePickerSheet> createState() => _TimePickerSheetState();
}

class _TimePickerSheetState extends State<_TimePickerSheet> {
  late final FixedExtentScrollController _hourController;
  late final FixedExtentScrollController _minuteController;

  late int _selectedHour;
  late int _selectedMinute; // 0, 5, 10, ... 55

  @override
  void initState() {
    super.initState();
    _selectedHour = widget.initialTime.hour;
    _selectedMinute = (widget.initialTime.minute / 5).round() * 5 % 60;

    _hourController = FixedExtentScrollController(initialItem: _selectedHour);
    _minuteController =
        FixedExtentScrollController(initialItem: _selectedMinute ~/ 5);
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  Widget _buildWheel({
    required FixedExtentScrollController controller,
    required int itemCount,
    required String Function(int) labelBuilder,
    required ValueChanged<int> onChanged,
  }) {
    return SizedBox(
      width: 88,
      height: 180,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF3EEFF),
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          ListWheelScrollView.useDelegate(
            controller: controller,
            itemExtent: 44,
            diameterRatio: 1.6,
            physics: const FixedExtentScrollPhysics(),
            onSelectedItemChanged: onChanged,
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: itemCount,
              builder: (context, index) {
                return Center(
                  child: Text(
                    labelBuilder(index),
                    style: const TextStyle(
                      color: _AiStudyPlanPageState._textColor,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        24, 22, 24, MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      color: _AiStudyPlanPageState._textColor,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildWheel(
                  controller: _hourController,
                  itemCount: 24,
                  labelBuilder: (i) => _pad(i),
                  onChanged: (i) => setState(() => _selectedHour = i),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    ':',
                    style: TextStyle(
                      color: _AiStudyPlanPageState._textColor,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _buildWheel(
                  controller: _minuteController,
                  itemCount: 12,
                  labelBuilder: (i) => _pad(i * 5),
                  onChanged: (i) => setState(() => _selectedMinute = i * 5),
                ),
              ],
            ),
            const SizedBox(height: 26),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                onPressed: () => Navigator.pop(
                  context,
                  TimeOfDay(hour: _selectedHour, minute: _selectedMinute),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: _AiStudyPlanPageState._purpleColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: const Text(
                  '선택 완료',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthNavButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _MonthNavButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled ? const Color(0xFFF3EEFF) : const Color(0xFFF5F2F3),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            icon,
            size: 20,
            color: enabled
                ? _AiStudyPlanPageState._purpleColor
                : const Color(0xFFCBC2C6),
          ),
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final _DailyPlanItem item;
  final int index;

  const _PlanCard({required this.item, required this.index});

  @override
  Widget build(BuildContext context) {
    final isEven = index.isEven;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8E1E4)),
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
                      color: _AiStudyPlanPageState._purpleColor,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      item.duration,
                      style: const TextStyle(
                        color: _AiStudyPlanPageState._purpleColor,
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
  final String jmcd;
  final String name;
  final String qualgbcd; // T: 국가기술자격, S: 국가전문자격
  final bool isManual;

  const _CertificateOption({
    required this.jmcd,
    required this.name,
    required this.qualgbcd,
    this.isManual = false,
  });

  factory _CertificateOption.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return _CertificateOption(
      jmcd: data['jmcd'] as String? ?? doc.id,
      name: data['jmfldnm'] as String? ?? '',
      qualgbcd: data['qualgbcd'] as String? ?? 'T',
    );
  }

  factory _CertificateOption.manual(String name) {
    return _CertificateOption(
      jmcd: '',
      name: name,
      qualgbcd: '',
      isManual: true,
    );
  }
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

  String get dayLabel => days.join(' · ');

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

class _ExitDuringGenerationSheet extends StatelessWidget {
  const _ExitDuringGenerationSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        24, 26, 24, MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Color(0xFFFFF0F0),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFE0685E),
                size: 28,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              '학습 플랜 생성을 중단할까요?',
              style: TextStyle(
                color: _AiStudyPlanPageState._textColor,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              '지금 나가면 생성 중인 학습 플랜이 저장되지 않아요.',
              style: TextStyle(
                color: _AiStudyPlanPageState._subTextColor,
                fontSize: 13,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _AiStudyPlanPageState._textColor,
                        side: const BorderSide(
                          color: _AiStudyPlanPageState._borderColor,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        '계속 생성하기',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFE0685E),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        '나가기',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                    ),
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
class _MultiDatePickerSheet extends StatefulWidget {
  final List<DateTime> initialSelectedDates;
  final DateTime firstDate;
  final DateTime lastDate;
  final String title;

  const _MultiDatePickerSheet({
    required this.initialSelectedDates,
    required this.firstDate,
    required this.lastDate,
    required this.title,
  });

  @override
  State<_MultiDatePickerSheet> createState() => _MultiDatePickerSheetState();
}

class _MultiDatePickerSheetState extends State<_MultiDatePickerSheet> {
  static const List<String> _weekdays = ['일', '월', '화', '수', '목', '금', '토'];

  late DateTime _displayedMonth;
  late Set<DateTime> _selectedDates;

  @override
  void initState() {
    super.initState();
    _selectedDates = widget.initialSelectedDates
        .map((d) => DateTime(d.year, d.month, d.day))
        .toSet();
    final base =
    _selectedDates.isNotEmpty ? _selectedDates.first : widget.firstDate;
    _displayedMonth = DateTime(base.year, base.month);
  }

  bool _isSelectable(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final first =
    DateTime(widget.firstDate.year, widget.firstDate.month, widget.firstDate.day);
    final last =
    DateTime(widget.lastDate.year, widget.lastDate.month, widget.lastDate.day);
    return !d.isBefore(first) && !d.isAfter(last);
  }

  void _toggleDate(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    setState(() {
      final existing = _selectedDates.where((e) =>
      e.year == d.year && e.month == d.month && e.day == d.day);
      if (existing.isEmpty) {
        _selectedDates.add(d);
      } else {
        _selectedDates.remove(existing.first);
      }
    });
  }

  void _changeMonth(int delta) {
    setState(() {
      _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month + delta);
    });
  }

  bool get _canGoPrev {
    final prevMonthLastDay =
    DateTime(_displayedMonth.year, _displayedMonth.month, 0);
    return !prevMonthLastDay.isBefore(
      DateTime(widget.firstDate.year, widget.firstDate.month, 1),
    );
  }

  bool get _canGoNext {
    final nextMonthFirstDay =
    DateTime(_displayedMonth.year, _displayedMonth.month + 1, 1);
    return !nextMonthFirstDay.isAfter(
      DateTime(widget.lastDate.year, widget.lastDate.month, widget.lastDate.day),
    );
  }

  @override
  Widget build(BuildContext context) {
    final firstWeekday =
        DateTime(_displayedMonth.year, _displayedMonth.month, 1).weekday % 7;
    final daysInMonth =
        DateTime(_displayedMonth.year, _displayedMonth.month + 1, 0).day;
    final now = DateTime.now();

    return Container(
      padding: EdgeInsets.fromLTRB(
        24, 22, 24, MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      color: _AiStudyPlanPageState._textColor,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${_selectedDates.length}개 선택됨 · 여러 날짜를 탭해서 선택하세요',
              style: const TextStyle(
                color: _AiStudyPlanPageState._subTextColor,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_displayedMonth.year}년 ${_displayedMonth.month}월',
                  style: const TextStyle(
                    color: _AiStudyPlanPageState._textColor,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Row(
                  children: [
                    _MonthNavButton(
                      icon: Icons.chevron_left_rounded,
                      enabled: _canGoPrev,
                      onTap: () => _changeMonth(-1),
                    ),
                    const SizedBox(width: 6),
                    _MonthNavButton(
                      icon: Icons.chevron_right_rounded,
                      enabled: _canGoNext,
                      onTap: () => _changeMonth(1),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: _weekdays.map((w) {
                return Expanded(
                  child: Center(
                    child: Text(
                      w,
                      style: const TextStyle(
                        color: _AiStudyPlanPageState._subTextColor,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 6),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: firstWeekday + daysInMonth,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
              ),
              itemBuilder: (context, index) {
                if (index < firstWeekday) return const SizedBox.shrink();

                final day = index - firstWeekday + 1;
                final date =
                DateTime(_displayedMonth.year, _displayedMonth.month, day);
                final selectable = _isSelectable(date);
                final isSelected = _selectedDates.any((e) =>
                e.year == date.year && e.month == date.month && e.day == date.day);
                final isToday = date.year == now.year &&
                    date.month == now.month &&
                    date.day == now.day;

                return GestureDetector(
                  onTap: selectable ? () => _toggleDate(date) : null,
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _AiStudyPlanPageState._purpleColor
                          : Colors.transparent,
                      shape: BoxShape.circle,
                      border: (isToday && !isSelected)
                          ? Border.all(
                          color: _AiStudyPlanPageState._purpleColor, width: 1.4)
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$day',
                      style: TextStyle(
                        color: !selectable
                            ? const Color(0xFFD9D2D5)
                            : isSelected
                            ? Colors.white
                            : _AiStudyPlanPageState._textColor,
                        fontSize: 14.5,
                        fontWeight:
                        isSelected || isToday ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, _selectedDates.toList()),
                style: FilledButton.styleFrom(
                  backgroundColor: _AiStudyPlanPageState._purpleColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: Text(
                  '선택 완료 (${_selectedDates.length})',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}