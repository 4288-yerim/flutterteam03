import 'package:flutter/material.dart';

import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_main_background.dart';
import '../../widgets/app_top_bar.dart';

class GoalCertificateScreen extends StatefulWidget {
  const GoalCertificateScreen({super.key});

  @override
  State<GoalCertificateScreen> createState() =>
      _GoalCertificateScreenState();
}

class _GoalCertificateScreenState
    extends State<GoalCertificateScreen> {
  final List<GoalCertificateItem> _goals = [
    GoalCertificateItem(
      certificateName: '정보처리기사',
      examRound: '2026년 2회',
      examDate: DateTime(2026, 9, 15),
      status: GoalStatus.active,
      calendarLinked: true,
      alarmEnabled: true,
    ),
    GoalCertificateItem(
      certificateName: 'SQLD',
      examRound: '2026년 3회',
      examDate: DateTime(2026, 11, 8),
      status: GoalStatus.active,
      calendarLinked: false,
      alarmEnabled: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,

      appBar: AppTopBar(
        title: '목표 자격증 관리',
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 20,
            color: Color(0xFF1A1A1A),
          ),
        ),
      ),

      body: AppMainBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            20,
            16,
            20,
            100,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildGuideCard(),
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '준비 중인 자격증',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  Text(
                    '${_goals.length}개',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFF0788F),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              if (_goals.isEmpty)
                _buildEmptyView()
              else
                ListView.separated(
                  itemCount: _goals.length,
                  shrinkWrap: true,
                  physics:
                  const NeverScrollableScrollPhysics(),
                  separatorBuilder: (_, __) =>
                  const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final goal = _goals[index];

                    return GoalCertificateCard(
                      goal: goal,
                      onEdit: () {
                        _showGoalForm(
                          existingIndex: index,
                        );
                      },
                      onDelete: () {
                        _showDeleteDialog(index);
                      },
                      onCalendarChanged: (value) {
                        setState(() {
                          goal.calendarLinked = value;
                        });
                      },
                      onAlarmChanged: (value) {
                        setState(() {
                          goal.alarmEnabled = value;
                        });
                      },
                    );
                  },
                ),

              const SizedBox(height: 24),

              AppButton(
                text: '목표 자격증 추가',
                type: AppButtonType.primaryPink,
                onPressed: () {
                  _showGoalForm();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuideCard() {
    return AppCard(
      backgroundColor: const Color(0xFFFFF4F7),
      padding: const EdgeInsets.all(18),
      child: const Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lightbulb_outline,
            color: Color(0xFFF0788F),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              '목표 시험일을 등록하면 D-Day, 학습 계획, 시험 일정 알림에 활용할 수 있습니다.',
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: Color(0xFF666A73),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 30,
        ),
        child: Column(
          children: [
            const Icon(
              Icons.flag_outlined,
              size: 52,
              color: Color(0xFFB4B8C2),
            ),
            const SizedBox(height: 14),
            const Text(
              '등록된 목표 자격증이 없습니다.',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '준비할 자격증과 시험일을 등록해 보세요.',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF9AA0AC),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: 180,
              child: AppButton(
                text: '목표 추가',
                height: 46,
                onPressed: () {
                  _showGoalForm();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showGoalForm({
    int? existingIndex,
  }) async {
    final GoalCertificateItem? existingGoal =
    existingIndex == null
        ? null
        : _goals[existingIndex];

    final result =
    await showModalBottomSheet<GoalCertificateItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(26),
        ),
      ),
      builder: (bottomSheetContext) {
        return GoalCertificateForm(
          existingGoal: existingGoal,
        );
      },
    );

    if (result == null) {
      return;
    }

    setState(() {
      if (existingIndex == null) {
        _goals.add(result);
      } else {
        _goals[existingIndex] = result;
      }
    });
  }

  void _showDeleteDialog(int index) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text(
            '목표 삭제',
            style: TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            '${_goals[index].certificateName} 목표를 삭제하시겠습니까?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text(
                '취소',
                style: TextStyle(
                  color: Color(0xFF9AA0AC),
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _goals.removeAt(index);
                });

                Navigator.pop(dialogContext);
              },
              child: const Text(
                '삭제',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class GoalCertificateCard extends StatelessWidget {
  final GoalCertificateItem goal;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onCalendarChanged;
  final ValueChanged<bool> onAlarmChanged;

  const GoalCertificateCard({
    super.key,
    required this.goal,
    required this.onEdit,
    required this.onDelete,
    required this.onCalendarChanged,
    required this.onAlarmChanged,
  });

  @override
  Widget build(BuildContext context) {
    final int dDay =
        goal.examDate.difference(
          DateTime.now(),
        ).inDays;

    return AppCard(
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFFCEFF3),
                  borderRadius:
                  BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.workspace_premium_outlined,
                  color: Color(0xFFF0788F),
                ),
              ),
              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.certificateName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight:
                        FontWeight.w700,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      goal.examRound,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF9AA0AC),
                      ),
                    ),
                  ],
                ),
              ),

              PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert,
                  color: Color(0xFF9AA0AC),
                ),
                onSelected: (value) {
                  if (value == 'edit') {
                    onEdit();
                  }

                  if (value == 'delete') {
                    onDelete();
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: Text('수정'),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      '삭제',
                      style: TextStyle(
                        color: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 18),

          Container(
            width: double.infinity,
            padding:
            const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F8FA),
              borderRadius:
              BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_month_outlined,
                  size: 20,
                  color: Color(0xFFF0788F),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _formatDate(goal.examDate),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight:
                      FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  dDay >= 0
                      ? 'D-$dDay'
                      : '시험 종료',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight:
                    FontWeight.w700,
                    color: dDay >= 0
                        ? const Color(0xFFF0788F)
                        : const Color(0xFF9AA0AC),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text(
              '캘린더 연동',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: const Text(
              '시험 일정을 캘린더에 표시',
              style: TextStyle(
                fontSize: 12,
              ),
            ),
            value: goal.calendarLinked,
            activeColor:
            const Color(0xFFF0788F),
            onChanged: onCalendarChanged,
          ),

          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text(
              '시험 알림',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: const Text(
              '접수와 시험일 알림 받기',
              style: TextStyle(
                fontSize: 12,
              ),
            ),
            value: goal.alarmEnabled,
            activeColor:
            const Color(0xFFF0788F),
            onChanged: onAlarmChanged,
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }
}

class GoalCertificateForm extends StatefulWidget {
  final GoalCertificateItem? existingGoal;

  const GoalCertificateForm({
    super.key,
    this.existingGoal,
  });

  @override
  State<GoalCertificateForm> createState() =>
      _GoalCertificateFormState();
}

class _GoalCertificateFormState
    extends State<GoalCertificateForm> {
  final GlobalKey<FormState> _formKey =
  GlobalKey<FormState>();

  late final TextEditingController
  _certificateController;

  late final TextEditingController
  _roundController;

  late DateTime _selectedDate;
  late bool _calendarLinked;
  late bool _alarmEnabled;

  @override
  void initState() {
    super.initState();

    final existing = widget.existingGoal;

    _certificateController =
        TextEditingController(
          text: existing?.certificateName ?? '',
        );

    _roundController =
        TextEditingController(
          text: existing?.examRound ?? '',
        );

    _selectedDate =
        existing?.examDate ??
            DateTime.now().add(
              const Duration(days: 30),
            );

    _calendarLinked =
        existing?.calendarLinked ?? false;

    _alarmEnabled =
        existing?.alarmEnabled ?? true;
  }

  @override
  void dispose() {
    _certificateController.dispose();
    _roundController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset =
        MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        bottomInset + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
            CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color:
                    const Color(0xFFE2E2E6),
                    borderRadius:
                    BorderRadius.circular(20),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Text(
                widget.existingGoal == null
                    ? '목표 자격증 추가'
                    : '목표 자격증 수정',
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 22),

              const Text(
                '자격증명',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),

              TextFormField(
                controller:
                _certificateController,
                decoration: _decoration(
                  hintText: '자격증명을 입력해 주세요.',
                  icon: Icons.search,
                ),
                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return '자격증명을 입력해 주세요.';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 18),

              const Text(
                '시험 회차',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),

              TextFormField(
                controller: _roundController,
                decoration: _decoration(
                  hintText: '예: 2026년 2회',
                  icon: Icons.repeat,
                ),
              ),

              const SizedBox(height: 18),

              const Text(
                '목표 시험일',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),

              InkWell(
                onTap: _selectDate,
                borderRadius:
                BorderRadius.circular(14),
                child: InputDecorator(
                  decoration: _decoration(
                    hintText: '',
                    icon:
                    Icons.calendar_month_outlined,
                  ),
                  child: Text(
                    GoalCertificateCard
                        ._formatDate(
                      _selectedDate,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  '캘린더 연동',
                ),
                value: _calendarLinked,
                activeColor:
                const Color(0xFFF0788F),
                onChanged: (value) {
                  setState(() {
                    _calendarLinked = value;
                  });
                },
              ),

              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  '시험 알림',
                ),
                value: _alarmEnabled,
                activeColor:
                const Color(0xFFF0788F),
                onChanged: (value) {
                  setState(() {
                    _alarmEnabled = value;
                  });
                },
              ),

              const SizedBox(height: 18),

              AppButton(
                text:
                widget.existingGoal == null
                    ? '추가하기'
                    : '수정 완료',
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration({
    required String hintText,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hintText,
      prefixIcon: Icon(
        icon,
        color: const Color(0xFF9AA0AC),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding:
      const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
      border: OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color(0xFFE8E8EC),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color(0xFFE8E8EC),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color(0xFFF0788F),
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Colors.red,
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final selected =
    await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2035),
    );

    if (selected == null) {
      return;
    }

    setState(() {
      _selectedDate = selected;
    });
  }

  void _submit() {
    final valid =
        _formKey.currentState?.validate() ??
            false;

    if (!valid) {
      return;
    }

    Navigator.pop(
      context,
      GoalCertificateItem(
        certificateName:
        _certificateController.text.trim(),
        examRound:
        _roundController.text.trim(),
        examDate: _selectedDate,
        status: GoalStatus.active,
        calendarLinked: _calendarLinked,
        alarmEnabled: _alarmEnabled,
      ),
    );
  }
}

enum GoalStatus {
  active,
  passed,
  failed,
}

class GoalCertificateItem {
  final String certificateName;
  final String examRound;
  final DateTime examDate;
  final GoalStatus status;

  bool calendarLinked;
  bool alarmEnabled;

  GoalCertificateItem({
    required this.certificateName,
    required this.examRound,
    required this.examDate,
    required this.status,
    required this.calendarLinked,
    required this.alarmEnabled,
  });
}