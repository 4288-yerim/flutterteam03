import 'package:flutter/material.dart';

import '../../widgets/app_card.dart';
import '../../widgets/app_main_background.dart';
import '../../widgets/app_top_bar.dart';

class StudyPlanScreen extends StatefulWidget {
  const StudyPlanScreen({super.key});

  @override
  State<StudyPlanScreen> createState() =>
      _StudyPlanScreenState();
}

class _StudyPlanScreenState extends State<StudyPlanScreen> {
  DateTime _selectedDate = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );

// Firebase 연결 전 임시 학습 계획 데이터
  final List<StudyPlanTask> _tasks = [
    StudyPlanTask(
      id: 'task_001',
      title: 'SQL 응용 개념 복습',
      certificateName: '정보처리기사',
      date: DateTime(2026, 7, 15),
      type: StudyPlanTaskType.aiPlan,
      startTime: const TimeOfDay(
        hour: 19,
        minute: 0,
      ),
      endTime: const TimeOfDay(
        hour: 20,
        minute: 0,
      ),
      isCompleted: true,
    ),
    StudyPlanTask(
      id: 'task_002',
      title: '기출문제 1회분 풀이',
      certificateName: '정보처리기사',
      date: DateTime(2026, 7, 15),
      type: StudyPlanTaskType.aiPlan,
      startTime: const TimeOfDay(
        hour: 20,
        minute: 0,
      ),
      endTime: const TimeOfDay(
        hour: 21,
        minute: 0,
      ),
      isCompleted: false,
    ),
    StudyPlanTask(
      id: 'task_003',
      title: '오답 노트 정리',
      certificateName: '정보처리기사',
      date: DateTime(2026, 7, 15),
      type: StudyPlanTaskType.user,
      startTime: const TimeOfDay(
        hour: 21,
        minute: 0,
      ),
      endTime: const TimeOfDay(
        hour: 21,
        minute: 30,
      ),
      isCompleted: false,
    ),
    StudyPlanTask(
      id: 'task_004',
      title: '데이터 모델링 개념 복습',
      certificateName: 'SQLD',
      date: DateTime(2026, 7, 16),
      type: StudyPlanTaskType.aiPlan,
      startTime: const TimeOfDay(
        hour: 19,
        minute: 30,
      ),
      endTime: const TimeOfDay(
        hour: 20,
        minute: 30,
      ),
      isCompleted: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final List<StudyPlanTask> selectedTasks =
    _getTasksForDate(_selectedDate);

    final int completedCount = selectedTasks
        .where(
    (task) => task.isCompleted,
    )
        .length;

    final double progress = selectedTasks.isEmpty
    ? 0
        : completedCount / selectedTasks.length;

    return Scaffold(
    extendBodyBehindAppBar: true,
    appBar: AppTopBar(
    title: '학습 계획',
    ),
    body: AppMainBackground(
    child: Column(
    children: [
    Expanded(
    child: SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(
    20,
    16,
    20,
    12,
    ),
    child: Column(
    crossAxisAlignment:
    CrossAxisAlignment.stretch,
    children: [
    _buildDateSelector(),
    const SizedBox(height: 16),

    _buildProgressCard(
    completedCount: completedCount,
    totalCount: selectedTasks.length,
    progress: progress,
    ),

    const SizedBox(height: 22),

    _buildTaskHeader(
    taskCount: selectedTasks.length,
    ),

    const SizedBox(height: 12),

    if (selectedTasks.isEmpty)
    _buildEmptyTaskCard()
    else
    ...selectedTasks.map(
    (task) {
    return Padding(
    padding:
    const EdgeInsets.only(
    bottom: 12,
    ),
    child: _buildTaskCard(task),
    );
    },
    ),
    ],
    ),
    ),
    ),

    Padding(
    padding: const EdgeInsets.fromLTRB(
    20,
    0,
    20,
    24,
    ),
    child: _buildAddTaskButton(),
    ),
    ],
    ),
    ),
    );

    }

  Widget _buildDateSelector() {
    return AppCard(
        child: Row(
          children: [
          IconButton(
          tooltip: '이전 날짜',
          onPressed: _moveToPreviousDate,
          icon: const Icon(
            Icons.chevron_left_rounded,
            size: 28,
            color: Color(0xFF666A73),
          ),
        ),

    Expanded(
    child: InkWell(
    borderRadius: BorderRadius.circular(12),
    onTap: _selectDate,
    child: Padding(
    padding: const EdgeInsets.symmetric(
    vertical: 8,
    ),
    child: Column(
    children: [
    Text(
    _formatDate(_selectedDate),
    textAlign: TextAlign.center,
    style: const TextStyle(
    fontSize: 19,
    fontWeight: FontWeight.w800,
    color: Color(0xFF1A1A1A),
    ),
    ),
    const SizedBox(height: 4),
    Text(
    _getDateLabel(_selectedDate),
    style: const TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: Color(0xFFF0788F),
    ),
    ),
    ],
    ),
    ),
    ),
    ),

    IconButton(
    tooltip: '다음 날짜',
    onPressed: _moveToNextDate,
    icon: const Icon(
    Icons.chevron_right_rounded,
    size: 28,
    color: Color(0xFF666A73),
    ),
    ),
    ],
    ),
    );

  }

  Widget _buildProgressCard({
    required int completedCount,
    required int totalCount,
    required double progress,
  }) {
    final int percentage =
    (progress * 100).round();

    return AppCard(
    child: Column(
    crossAxisAlignment:
    CrossAxisAlignment.stretch,
    children: [
    Row(
    children: [
    Container(
    width: 44,
    height: 44,
    decoration: BoxDecoration(
    color: const Color(0xFFFCEFF3),
    borderRadius:
    BorderRadius.circular(13),
    ),
    child: const Icon(
    Icons.auto_awesome_outlined,
    size: 22,
    color: Color(0xFFF0788F),
    ),
    ),

    const SizedBox(width: 13),

    const Expanded(
    child: Column(
    crossAxisAlignment:
    CrossAxisAlignment.start,
    children: [
    Text(
    '오늘의 진행률',
    style: TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: Color(0xFF666A73),
    ),
    ),
    SizedBox(height: 3),
    Text(
    '할 일을 완료해보세요.',
    style: TextStyle(
    fontSize: 12,
    color: Color(0xFF9AA0AC),
    ),
    ),
    ],
    ),
    ),

    Text(
    '$completedCount / $totalCount',
    style: const TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w800,
    color: Color(0xFFF0788F),
    ),
    ),
    ],
    ),

    const SizedBox(height: 18),

    ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: LinearProgressIndicator(
    value: progress,
    minHeight: 10,
    backgroundColor:
    const Color(0xFFF1EDEF),
    valueColor:
    const AlwaysStoppedAnimation<Color>(
    Color(0xFFF0788F),
    ),
    ),
    ),

    const SizedBox(height: 8),

    Align(
    alignment: Alignment.centerRight,
    child: Text(
    '$percentage% 완료',
    style: const TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: Color(0xFF9AA0AC),
    ),
    ),
    ),
    ],
    ),
    );

  }

  Widget _buildTaskHeader({
    required int taskCount,
  }) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            '오늘의 할 일',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A),
            ),
          ),
        ),
        Text(
          '$taskCount개',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFFF0788F),
          ),
        ),
      ],
    );
  }

  Widget _buildTaskCard(
      StudyPlanTask task,
      ) {
    final StudyPlanTaskStyle style =
    _getTaskStyle(task.type);

    return AppCard(
    padding: EdgeInsets.zero,
    child: InkWell(
    borderRadius: BorderRadius.circular(20),
    onTap: () {
    _toggleTask(task);
    },
    child: Padding(
    padding: const EdgeInsets.fromLTRB(
    16,
    15,
    8,
    15,
    ),
    child: Row(
    crossAxisAlignment:
    CrossAxisAlignment.start,
    children: [
    Padding(
    padding:
    const EdgeInsets.only(top: 2),
    child: AnimatedContainer(
    duration: const Duration(
    milliseconds: 160,
    ),
    width: 26,
    height: 26,
    decoration: BoxDecoration(
    shape: BoxShape.circle,
    color: task.isCompleted
    ? const Color(0xFFF0788F)
        : Colors.white,
    border: Border.all(
    color: task.isCompleted
    ? const Color(0xFFF0788F)
        : const Color(0xFFD6D8DE),
    width: 2,
    ),
    ),
    child: task.isCompleted
    ? const Icon(
    Icons.check_rounded,
    size: 18,
    color: Colors.white,
    )
        : null,
    ),
    ),

    const SizedBox(width: 13),

    Expanded(
    child: Column(
    crossAxisAlignment:
    CrossAxisAlignment.start,
    children: [
    Row(
    children: [
    Container(
    padding:
    const EdgeInsets.symmetric(
    horizontal: 8,
    vertical: 3,
    ),
    decoration: BoxDecoration(
    color:
    style.backgroundColor,
    borderRadius:
    BorderRadius.circular(
    20,
    ),
    ),
    child: Text(
    style.label,
    style: TextStyle(
    fontSize: 11,
    fontWeight:
    FontWeight.w700,
    color:
    style.foregroundColor,
    ),
    ),
    ),

    const SizedBox(width: 8),

    Expanded(
    child: Text(
    task.certificateName,
    overflow:
    TextOverflow.ellipsis,
    style: const TextStyle(
    fontSize: 12,
    color:
    Color(0xFF9AA0AC),
    ),
    ),
    ),
    ],
    ),

    const SizedBox(height: 9),

    Text(
    task.title,
    style: TextStyle(
    fontSize: 16,
    height: 1.4,
    fontWeight: FontWeight.w700,
    color: task.isCompleted
    ? const Color(0xFF9AA0AC)
        : const Color(0xFF1A1A1A),
    decoration: task.isCompleted
    ? TextDecoration.lineThrough
        : TextDecoration.none,
    ),
    ),

    if (task.startTime != null) ...[
    const SizedBox(height: 7),
    Row(
    children: [
    const Icon(
    Icons.schedule_outlined,
    size: 15,
    color: Color(0xFF9AA0AC),
    ),
    const SizedBox(width: 5),
    Text(
    _formatTaskTime(task),
    style: const TextStyle(
    fontSize: 12,
    color: Color(0xFF9AA0AC),
    ),
    ),
    ],
    ),
    ],
    ],
    ),
    ),

    if (task.type ==
    StudyPlanTaskType.user)
    PopupMenuButton<String>(
    tooltip: '할 일 메뉴',
    color: Colors.white,
    icon: const Icon(
    Icons.more_vert_rounded,
    color: Color(0xFF9AA0AC),
    ),
    onSelected: (value) {
    if (value == 'delete') {
    _showDeleteTaskDialog(task);
    }
    },
    itemBuilder: (context) {
    return const [
    PopupMenuItem<String>(
    value: 'delete',
    child: Row(
    children: [
    Icon(
    Icons
        .delete_outline_rounded,
    size: 20,
    color: Colors.redAccent,
    ),
    SizedBox(width: 10),
    Text('할 일 삭제'),
    ],
    ),
    ),
    ];
    },
    ),
    ],
    ),
    ),
    ),
    );

  }

  Widget _buildEmptyTaskCard() {
    return AppCard(
      child: const Padding(
        padding: EdgeInsets.symmetric(
          vertical: 32,
        ),
        child: Column(
          children: [
            Icon(
              Icons.task_alt_rounded,
              size: 44,
              color: Color(0xFFB4B8C2),
            ),
            SizedBox(height: 12),
            Text(
              '등록된 학습 계획이 없습니다.',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
            ),
            SizedBox(height: 6),
            Text(
              '할 일 추가 버튼을 눌러\n학습 계획을 등록해보세요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: Color(0xFF9AA0AC),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddTaskButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _showAddTaskDialog,
        style: ElevatedButton.styleFrom(
          backgroundColor:
          const Color(0xFFF0788F),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: const Icon(
          Icons.add_rounded,
        ),
        label: const Text(
          '할 일 추가',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  void _moveToPreviousDate() {
    setState(() {
      _selectedDate = _selectedDate.subtract(
        const Duration(days: 1),
      );
    });
  }

  void _moveToNextDate() {
    setState(() {
      _selectedDate = _selectedDate.add(
        const Duration(days: 1),
      );
    });
  }

  Future<void> _selectDate() async {
    final DateTime? pickedDate =
    await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2025),
      lastDate: DateTime(2035),
    );

    if (pickedDate == null) {
    return;
    }

    setState(() {
    _selectedDate = DateTime(
    pickedDate.year,
    pickedDate.month,
    pickedDate.day,
    );
    });

  }

  void _toggleTask(
      StudyPlanTask task,
      ) {
    setState(() {
      task.isCompleted = !task.isCompleted;
    });
  }

  Future<void> _showAddTaskDialog() async {
    final TextEditingController
    titleController =
    TextEditingController();

    final TextEditingController
    certificateController =
    TextEditingController();

    DateTime selectedDate = _selectedDate;
    TimeOfDay? startTime;
    TimeOfDay? endTime;

    final bool? result =
    await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
    return StatefulBuilder(
    builder: (
    context,
    setDialogState,
    ) {
    return AlertDialog(
    backgroundColor: Colors.white,
    title: const Text(
    '할 일 추가',
    style: TextStyle(
    fontWeight: FontWeight.w700,
    ),
    ),
    content: SingleChildScrollView(
    child: Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment:
    CrossAxisAlignment.stretch,
    children: [
    TextField(
    controller: titleController,
    onTapOutside: (_) {
    FocusManager
        .instance.primaryFocus
        ?.unfocus();
    },
    decoration:
    const InputDecoration(
    labelText: '과제명',
    hintText: '예: 기출문제 풀이',
    border:
    OutlineInputBorder(),
    ),
    ),

    const SizedBox(height: 14),

    TextField(
    controller:
    certificateController,
    onTapOutside: (_) {
    FocusManager
        .instance.primaryFocus
        ?.unfocus();
    },
    decoration:
    const InputDecoration(
    labelText: '자격증명',
    hintText: '예: 정보처리기사',
    border:
    OutlineInputBorder(),
    ),
    ),

    const SizedBox(height: 14),

    _StudyPlanSelectTile(
    icon: Icons
        .calendar_month_outlined,
    title: '날짜',
    value:
    _formatDialogDate(
    selectedDate,
    ),
    onTap: () async {
    final DateTime? pickedDate =
    await showDatePicker(
    context: context,
    initialDate:
    selectedDate,
    firstDate: DateTime(2025),
    lastDate: DateTime(2035),
    );

    if (pickedDate != null) {
    setDialogState(() {
    selectedDate =
    pickedDate;
    });
    }
    },
    ),

    const SizedBox(height: 10),

    _StudyPlanSelectTile(
    icon: Icons.schedule_outlined,
    title: '시작 시간',
    value: startTime == null
    ? '선택 안 함'
        : _formatTimeOfDay(
    startTime!,
    ),
    onTap: () async {
    final TimeOfDay? pickedTime =
    await showTimePicker(
    context: context,
    initialTime:
    startTime ??
    TimeOfDay.now(),
    );

    if (pickedTime != null) {
    setDialogState(() {
    startTime =
    pickedTime;
    });
    }
    },
    ),

    const SizedBox(height: 10),

    _StudyPlanSelectTile(
    icon: Icons
        .schedule_send_outlined,
    title: '완료 시간',
    value: endTime == null
    ? '선택 안 함'
        : _formatTimeOfDay(
    endTime!,
    ),
    onTap: () async {
    final TimeOfDay? pickedTime =
    await showTimePicker(
    context: context,
    initialTime:
    endTime ??
    startTime ??
    TimeOfDay.now(),
    );

    if (pickedTime != null) {
    setDialogState(() {
    endTime = pickedTime;
    });
    }
    },
    ),
    ],
    ),
    ),
    actions: [
    TextButton(
    onPressed: () {
    FocusManager
        .instance.primaryFocus
        ?.unfocus();

    Navigator.pop(
    dialogContext,
    false,
    );
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
    if (titleController.text
        .trim()
        .isEmpty) {
    ScaffoldMessenger.of(context)
        .showSnackBar(
    const SnackBar(
    content: Text(
    '과제명을 입력해주세요.',
    ),
    ),
    );
    return;
    }

    if (certificateController.text
        .trim()
        .isEmpty) {
    ScaffoldMessenger.of(context)
        .showSnackBar(
    const SnackBar(
    content: Text(
    '자격증명을 입력해주세요.',
    ),
    ),
    );
    return;
    }

    if (startTime == null &&
    endTime != null) {
    ScaffoldMessenger.of(context)
        .showSnackBar(
    const SnackBar(
    content: Text(
    '완료 시간을 선택하려면 시작 시간도 선택해주세요.',
    ),
    ),
    );
    return;
    }

    if (startTime != null &&
    endTime != null) {
    final int startMinutes =
    startTime!.hour * 60 +
    startTime!.minute;

    final int endMinutes =
    endTime!.hour * 60 +
    endTime!.minute;

    if (endMinutes <=
    startMinutes) {
    ScaffoldMessenger.of(context)
        .showSnackBar(
    const SnackBar(
    content: Text(
    '완료 시간은 시작 시간보다 늦어야 합니다.',
    ),
    ),
    );
    return;
    }
    }

    FocusManager
        .instance.primaryFocus
        ?.unfocus();

    Navigator.pop(
    dialogContext,
    true,
    );
    },
    child: const Text(
    '추가',
    style: TextStyle(
    color: Color(0xFFF0788F),
    fontWeight:
    FontWeight.w700,
    ),
    ),
    ),
    ],
    );
    },
    );
    },
    );

    if (result != true) {
    titleController.dispose();
    certificateController.dispose();
    return;
    }

    setState(() {
    _tasks.add(
    StudyPlanTask(
    id: DateTime.now()
        .millisecondsSinceEpoch
        .toString(),
    title: titleController.text.trim(),
    certificateName:
    certificateController.text.trim(),
    date: DateTime(
    selectedDate.year,
    selectedDate.month,
    selectedDate.day,
    ),
    type: StudyPlanTaskType.user,
    startTime: startTime,
    endTime: endTime,
    isCompleted: false,
    ),
    );

    _selectedDate = DateTime(
    selectedDate.year,
    selectedDate.month,
    selectedDate.day,
    );
    });

    titleController.dispose();
    certificateController.dispose();

    if (!mounted) {
    return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
    content: Text(
    '할 일이 추가되었습니다.',
    ),
    ),
    );

    }

  Future<void> _showDeleteTaskDialog(
      StudyPlanTask task,
      ) async {
    final bool? result =
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text(
            '할 일 삭제',
            style: TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            '"${task.title}" 할 일을 삭제하시겠습니까?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
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
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child: const Text(
                '삭제',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (result != true) {
    return;
    }

    setState(() {
    _tasks.removeWhere(
    (item) => item.id == task.id,
    );
    });

    if (!mounted) {
    return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
    content: Text(
    '할 일이 삭제되었습니다.',
    ),
    ),
    );

    }

  List<StudyPlanTask> _getTasksForDate(
      DateTime date,
      ) {
    final List<StudyPlanTask> result =
    _tasks.where(
          (task) {
        return _isSameDate(
          task.date,
          date,
        );
      },
    ).toList();

    result.sort(
    (first, second) {
    if (first.startTime == null &&
    second.startTime == null) {
    return 0;
    }

    if (first.startTime == null) {
    return -1;
    }

    if (second.startTime == null) {
    return 1;
    }

    final int firstMinutes =
    first.startTime!.hour * 60 +
    first.startTime!.minute;

    final int secondMinutes =
    second.startTime!.hour * 60 +
    second.startTime!.minute;

    return firstMinutes.compareTo(
    secondMinutes,
    );
    },
    );

    return result;

    }

  bool _isSameDate(
      DateTime first,
      DateTime second,
      ) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  String _formatDate(
      DateTime date,
      ) {
    const List<String> weekdays = [
      '월',
      '화',
      '수',
      '목',
      '금',
      '토',
      '일',
    ];

    return '${date.year}년 ${date.month}월 ${date.day}일 '
    '${weekdays[date.weekday - 1]}요일';

  }

  String _getDateLabel(
      DateTime date,
      ) {
    final DateTime today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    final DateTime target = DateTime(
    date.year,
    date.month,
    date.day,
    );

    final int difference =
    target.difference(today).inDays;

    if (difference == 0) {
    return '오늘';
    }

    if (difference == -1) {
    return '어제';
    }

    if (difference == 1) {
    return '내일';
    }

    return '날짜를 눌러 변경';

  }

  String _formatDialogDate(
      DateTime date,
      ) {
    return '${date.year}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String _formatTimeOfDay(
      TimeOfDay time,
      ) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
  }

  String _formatTaskTime(
      StudyPlanTask task,
      ) {
    if (task.startTime == null) {
      return '';
    }

    final String start =
    _formatTimeOfDay(task.startTime!);

    if (task.endTime == null) {
    return start;
    }

    final String end =
    _formatTimeOfDay(task.endTime!);

    return '$start - $end';

  }

  StudyPlanTaskStyle _getTaskStyle(
      StudyPlanTaskType type,
      ) {
    switch (type) {
    case StudyPlanTaskType.aiPlan:
    return const StudyPlanTaskStyle(
    label: 'AI 학습 계획',
    foregroundColor:
    Color(0xFF6F63C2),
    backgroundColor:
    Color(0xFFF0EEFC),
    );

    case StudyPlanTaskType.user:
    return const StudyPlanTaskStyle(
    label: '직접 추가',
    foregroundColor:
    Color(0xFF4A8F73),
    backgroundColor:
    Color(0xFFEAF6F1),
    );
    }

  }
}

enum StudyPlanTaskType {
  aiPlan,
  user,
}

class StudyPlanTask {
  final String id;
  final String title;
  final String certificateName;
  final DateTime date;
  final StudyPlanTaskType type;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;

  bool isCompleted;

  StudyPlanTask({
    required this.id,
    required this.title,
    required this.certificateName,
    required this.date,
    required this.type,
    required this.isCompleted,
    this.startTime,
    this.endTime,
  });
}

class StudyPlanTaskStyle {
  final String label;
  final Color foregroundColor;
  final Color backgroundColor;

  const StudyPlanTaskStyle({
    required this.label,
    required this.foregroundColor,
    required this.backgroundColor,
  });
}

class _StudyPlanSelectTile
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  const _StudyPlanSelectTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          border: Border.all(
            color: const Color(0xFFE2E2E6),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: const Color(0xFFF0788F),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9AA0AC),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: Color(0xFF9AA0AC),
            ),
          ],
        ),
      ),
    );
  }
}
