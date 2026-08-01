import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../widgets/app_dialog.dart';

import '../../theme.dart';

import '../../appwidgets/today_todo_app_widget.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_main_background.dart';
import '../../widgets/app_top_bar.dart';

class StudyPlanScreen extends StatefulWidget {
  const StudyPlanScreen({super.key, this.initialDate});

  final DateTime? initialDate;

  @override
  State<StudyPlanScreen> createState() => _StudyPlanScreenState();
}

class _StudyPlanScreenState extends State<StudyPlanScreen> {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late DateTime _selectedDate;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    final initialDate = widget.initialDate ?? DateTime.now();

    _selectedDate = DateTime(
      initialDate.year,
      initialDate.month,
      initialDate.day,
    );
  }

  CollectionReference<Map<String, dynamic>>? get _studyPlansCollection {
    final User? user = _firebaseAuth.currentUser;

    if (user == null) {
      return null;
    }

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('studyPlans');
  }

  Stream<List<StudyPlanTask>> _watchTasksForSelectedDate() {
    final CollectionReference<Map<String, dynamic>>? collection =
        _studyPlansCollection;

    if (collection == null) {
      return Stream<List<StudyPlanTask>>.value(<StudyPlanTask>[]);
    }

    return collection.snapshots().map((snapshot) {
      final List<StudyPlanTask> allTasks = <StudyPlanTask>[];

      for (final document in snapshot.docs) {
        final Map<String, dynamic> data = document.data();
        final Object? stepsData = data['steps'];

        if (stepsData is List) {
          allTasks.addAll(StudyPlanTask.fromAiPlanDocument(document));
        } else {
          allTasks.add(StudyPlanTask.fromDocument(document));
        }
      }

      final List<StudyPlanTask> selectedTasks = allTasks.where((task) {
        return task.date.year == _selectedDate.year &&
            task.date.month == _selectedDate.month &&
            task.date.day == _selectedDate.day;
      }).toList();

      selectedTasks.sort((first, second) {
        final DateTime? firstStart = first.startPlannedAt;
        final DateTime? secondStart = second.startPlannedAt;

        if (firstStart == null && secondStart == null) {
          return first.order.compareTo(second.order);
        }

        if (firstStart == null) {
          return -1;
        }

        if (secondStart == null) {
          return 1;
        }

        return firstStart.compareTo(secondStart);
      });

      return selectedTasks;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppTopBar(title: '학습 계획'),
      body: AppMainBackground(
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<List<StudyPlanTask>>(
                stream: _watchTasksForSelectedDate(),
                builder: (context, snapshot) {
                  final List<StudyPlanTask> selectedTasks =
                      snapshot.data ?? <StudyPlanTask>[];

                  final int completedCount = selectedTasks
                      .where((task) => task.isCompleted)
                      .length;

                  final double progress = selectedTasks.isEmpty
                      ? 0
                      : completedCount / selectedTasks.length;

                  return SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildDateSelector(),
                        SizedBox(height: 16),
                        _buildProgressCard(
                          completedCount: completedCount,
                          totalCount: selectedTasks.length,
                          progress: progress,
                        ),
                        SizedBox(height: 22),
                        _buildTaskHeader(taskCount: selectedTasks.length),
                        SizedBox(height: 12),
                        if (_firebaseAuth.currentUser == null)
                          _buildMessageCard(
                            icon: Icons.login_rounded,
                            title: '로그인이 필요합니다.',
                            description: '학습 계획을 조회하고 추가하려면 로그인해주세요.',
                          )
                        else if (snapshot.connectionState ==
                                ConnectionState.waiting &&
                            !snapshot.hasData)
                          _buildLoadingCard()
                        else if (snapshot.hasError)
                          _buildMessageCard(
                            icon: Icons.error_outline_rounded,
                            title: '학습 계획을 불러오지 못했습니다.',
                            description: _getFirestoreErrorMessage(
                              snapshot.error,
                            ),
                          )
                        else if (selectedTasks.isEmpty)
                          _buildEmptyTaskCard()
                        else
                          ...selectedTasks.map(
                            (task) => Padding(
                              padding: EdgeInsets.only(bottom: 12),
                              child: _buildTaskCard(task),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 24),
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
            icon: Icon(
              Icons.chevron_left_rounded,
              size: 28,
              color: context.colors.textSecondary,
            ),
          ),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _selectDate,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    Text(
                      _formatDate(_selectedDate),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      _getDateLabel(_selectedDate),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.colors.pinkStart,
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
            icon: Icon(
              Icons.chevron_right_rounded,
              size: 28,
              color: context.colors.textSecondary,
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
    final int percentage = (progress * 100).round();

    return AppCard(
      child: totalCount == 0
          ? Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: context.colors.pinkSoft,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    Icons.auto_awesome_outlined,
                    size: 22,
                    color: context.colors.pinkStart,
                  ),
                ),
                SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '오늘의 진행률',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: context.colors.textSecondary,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        '계획된 학습이 없습니다.',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: context.colors.pinkSoft,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        Icons.auto_awesome_outlined,
                        size: 22,
                        color: context.colors.pinkStart,
                      ),
                    ),
                    SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '오늘의 진행률',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: context.colors.textSecondary,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            '학습 계획을 완료해보세요.',
                            style: TextStyle(
                              fontSize: 12,
                              color: context.colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '$completedCount / $totalCount',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: context.colors.pinkStart,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 18),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                    backgroundColor: context.colors.surfaceMuted,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      context.colors.pinkStart,
                    ),
                  ),
                ),
                SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '$percentage% 완료',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: context.colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildTaskHeader({required int taskCount}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '오늘의 학습 계획',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: context.colors.textPrimary,
            ),
          ),
        ),
        Text(
          '$taskCount개',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.colors.pinkStart,
          ),
        ),
      ],
    );
  }

  Widget _buildTaskCard(StudyPlanTask task) {
    final StudyPlanTaskStyle style = _getTaskStyle(task.type);

    return AppCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          _toggleTask(task);
        },
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 15, 8, 15),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(top: 2),
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 160),
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: task.isCompleted
                        ? context.colors.pinkStart
                        : context.colors.surface,
                    border: Border.all(
                      color: task.isCompleted
                          ? context.colors.pinkStart
                          : context.colors.border,
                      width: 2,
                    ),
                  ),
                  child: task.isCompleted
                      ? Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: context.colors.onPrimary,
                        )
                      : null,
                ),
              ),
              SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: style.backgroundColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            style.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: style.foregroundColor,
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            task.certificateName,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.colors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 9),
                    Text(
                      task.title,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.4,
                        fontWeight: FontWeight.w700,
                        color: task.isCompleted
                            ? context.colors.textSecondary
                            : context.colors.textPrimary,
                        decoration: task.isCompleted
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                      ),
                    ),
                    if (task.subjectName?.isNotEmpty == true) ...[
                      SizedBox(height: 5),
                      Text(
                        task.subjectName!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ],
                    if (task.description.isNotEmpty) ...[
                      SizedBox(height: 5),
                      Text(
                        task.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ],
                    if (task.startPlannedAt != null) ...[
                      SizedBox(height: 7),
                      Row(
                        children: [
                          Icon(
                            Icons.schedule_outlined,
                            size: 15,
                            color: context.colors.textSecondary,
                          ),
                          SizedBox(width: 5),
                          Text(
                            _formatTaskTime(task),
                            style: TextStyle(
                              fontSize: 12,
                              color: context.colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (task.type == StudyPlanTaskType.user)
                PopupMenuButton<String>(
                  tooltip: '학습 계획 메뉴',
                  color: context.colors.surface,
                  icon: Icon(
                    Icons.more_vert_rounded,
                    color: context.colors.textSecondary,
                  ),
                  onSelected: (value) {
                    if (value == 'delete') {
                      _showDeleteTaskDialog(task);
                    }
                  },
                  itemBuilder: (context) {
                    return [
                      PopupMenuItem<String>(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline_rounded,
                              size: 20,
                              color: context.colors.incorrect,
                            ),
                            SizedBox(width: 10),
                            Text('학습 계획 삭제'),
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

  Widget _buildLoadingCard() {
    return AppCard(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 34),
        child: Center(
          child: CircularProgressIndicator(color: context.colors.pinkStart),
        ),
      ),
    );
  }

  Widget _buildEmptyTaskCard() {
    return AppCard(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            Icon(
              Icons.task_alt_rounded,
              size: 44,
              color: context.colors.textMuted,
            ),
            SizedBox(height: 12),
            Text(
              '등록된 학습 계획이 없습니다.',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: context.colors.textPrimary,
              ),
            ),
            SizedBox(height: 6),
            Text(
              '학습 계획 추가 버튼을 눌러\n직접 계획을 등록해보세요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: context.colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return AppCard(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 30),
        child: Column(
          children: [
            Icon(icon, size: 42, color: context.colors.textMuted),
            SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: context.colors.textPrimary,
              ),
            ),
            SizedBox(height: 6),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: context.colors.textSecondary,
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
        onPressed: _isSaving ? null : _showAddTaskDialog,
        style: ElevatedButton.styleFrom(
          backgroundColor: context.colors.pinkStart,
          foregroundColor: context.colors.onPrimary,
          disabledBackgroundColor: context.colors.pinkSoft,
          disabledForegroundColor: context.colors.textDisabled,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: _isSaving
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: context.colors.onPrimary,
                ),
              )
            : Icon(Icons.add_rounded),
        label: Text(
          _isSaving ? '저장 중...' : '학습 계획 추가',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  void _moveToPreviousDate() {
    setState(() {
      _selectedDate = _selectedDate.subtract(Duration(days: 1));
    });
  }

  void _moveToNextDate() {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: 1));
    });
  }

  Future<void> _selectDate() async {
    final DateTime? pickedDate = await showDatePicker(
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

  Future<void> _toggleTask(StudyPlanTask task) async {
    final CollectionReference<Map<String, dynamic>>? collection =
        _studyPlansCollection;

    if (collection == null) {
      _showSnackBar('로그인이 필요합니다.');
      return;
    }

    try {
      if (task.isAiStep) {
        await _toggleAiPlanStep(collection: collection, task: task);
      } else {
        await collection.doc(task.sourceDocumentId).update({
          'status': !task.isCompleted,
          'completedat': !task.isCompleted
              ? FieldValue.serverTimestamp()
              : null,
          'updatedat': FieldValue.serverTimestamp(),
        });
      }

      await TodayTodoAppWidget.sync();
    } on FirebaseException catch (error) {
      _showSnackBar(
        error.code == 'permission-denied'
            ? '학습 계획을 수정할 권한이 없습니다.'
            : '완료 상태 변경에 실패했습니다.',
      );
    } catch (_) {
      _showSnackBar('완료 상태 변경에 실패했습니다.');
    }
  }

  Future<void> _toggleAiPlanStep({
    required CollectionReference<Map<String, dynamic>> collection,
    required StudyPlanTask task,
  }) async {
    final int? stepIndex = task.aiStepIndex;

    if (stepIndex == null) {
      return;
    }

    final DocumentReference<Map<String, dynamic>> document = collection.doc(
      task.sourceDocumentId,
    );

    await _firestore.runTransaction((transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await transaction
          .get(document);

      final Map<String, dynamic>? data = snapshot.data();

      if (data == null) {
        throw StateError('AI 학습 플랜 문서를 찾을 수 없습니다.');
      }

      final Object? rawSteps = data['steps'];

      if (rawSteps is! List || stepIndex >= rawSteps.length) {
        throw StateError('AI 학습 단계를 찾을 수 없습니다.');
      }

      final List<Map<String, dynamic>> steps = rawSteps.map((step) {
        if (step is Map) {
          return Map<String, dynamic>.from(step);
        }

        return <String, dynamic>{};
      }).toList();

      final bool newCompletedValue = !task.isCompleted;

      steps[stepIndex] = <String, dynamic>{
        ...steps[stepIndex],
        'isCompleted': newCompletedValue,
      };

      final int completedStepCount = steps.where((step) {
        return step['isCompleted'] == true;
      }).length;

      final int totalStepCount = steps.length;

      final int completionRate = totalStepCount == 0
          ? 0
          : ((completedStepCount / totalStepCount) * 100).round();

      String planStatus = 'NOT_STARTED';

      if (completedStepCount == totalStepCount && totalStepCount > 0) {
        planStatus = 'COMPLETED';
      } else if (completedStepCount > 0) {
        planStatus = 'IN_PROGRESS';
      }

      transaction.update(document, {
        'steps': steps,
        'completedStepCount': completedStepCount,
        'totalStepCount': totalStepCount,
        'completionRate': completionRate,
        'status': planStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> _showAddTaskDialog() async {
    if (_firebaseAuth.currentUser == null) {
      _showSnackBar('로그인이 필요합니다.');
      return;
    }

    final TextEditingController titleController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    final TextEditingController subjectController = TextEditingController();
    final TextEditingController certificateController = TextEditingController();

    DateTime selectedDate = _selectedDate;
    TimeOfDay? startTime;
    TimeOfDay? endTime;

    final bool? result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AppAlertDialog(
              icon: Icons.event_note_outlined,
              title: Text(
                '학습 계획 추가',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: titleController,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: '학습 과제 이름',
                        hintText: '학습 과제 이름을 적어주세요',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 14),
                    TextField(
                      controller: descriptionController,
                      minLines: 2,
                      maxLines: 4,
                      maxLength: 50,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        labelText: '학습 과제 설명',
                        hintText: '학습 과제 내용을 적어주세요',
                        counterText: '최대 50자',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 14),
                    TextField(
                      controller: subjectController,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: '과목명 (선택)',
                        hintText: '과목명을 입력해주세요',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 14),
                    TextField(
                      controller: certificateController,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: '자격증명',
                        hintText: '자격증 이름을 입력해주세요',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 14),
                    _StudyPlanSelectTile(
                      icon: Icons.calendar_month_outlined,
                      title: '학습 날짜',
                      value: _formatDialogDate(selectedDate),
                      onTap: () async {
                        final DateTime? pickedDate = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2025),
                          lastDate: DateTime(2035),
                        );

                        if (pickedDate != null) {
                          setDialogState(() {
                            selectedDate = DateTime(
                              pickedDate.year,
                              pickedDate.month,
                              pickedDate.day,
                            );
                          });
                        }
                      },
                    ),
                    SizedBox(height: 10),
                    _StudyPlanSelectTile(
                      icon: Icons.schedule_outlined,
                      title: '공부 시작 시간 (선택)',
                      value: startTime == null
                          ? '선택'
                          : _formatTimeOfDay(startTime!),
                      onTap: () async {
                        final TimeOfDay? pickedTime = await showTimePicker(
                          context: context,
                          initialTime: startTime ?? TimeOfDay.now(),
                        );

                        if (pickedTime != null) {
                          setDialogState(() {
                            startTime = pickedTime;
                          });
                        }
                      },
                    ),
                    SizedBox(height: 10),
                    _StudyPlanSelectTile(
                      icon: Icons.schedule_send_outlined,
                      title: '공부 종료 시간 (선택)',
                      value: endTime == null
                          ? '선택'
                          : _formatTimeOfDay(endTime!),
                      onTap: () async {
                        final TimeOfDay? pickedTime = await showTimePicker(
                          context: context,
                          initialTime: endTime ?? startTime ?? TimeOfDay.now(),
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
                  onPressed: () async {
                    FocusManager.instance.primaryFocus?.unfocus();

                    await Future<void>.delayed(Duration(milliseconds: 100));

                    if (!dialogContext.mounted) {
                      return;
                    }

                    Navigator.pop(dialogContext, false);
                  },
                  child: Text(
                    '취소',
                    style: TextStyle(color: context.colors.textSecondary),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final String? validationMessage = _validateStudyPlanInput(
                      title: titleController.text,
                      description: descriptionController.text,
                      certificateName: certificateController.text,
                      startTime: startTime,
                      endTime: endTime,
                    );

                    if (validationMessage != null) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(content: Text(validationMessage)),
                      );
                      return;
                    }

                    FocusManager.instance.primaryFocus?.unfocus();

                    await Future<void>.delayed(Duration(milliseconds: 100));

                    if (!dialogContext.mounted) {
                      return;
                    }

                    Navigator.pop(dialogContext, true);
                  },
                  child: Text(
                    '추가',
                    style: TextStyle(
                      color: context.colors.pinkStart,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true) {
      await _addStudyPlan(
        title: titleController.text.trim(),
        description: descriptionController.text.trim(),
        subjectName: subjectController.text.trim(),
        certificateName: certificateController.text.trim(),
        selectedDate: selectedDate,
        startTime: startTime,
        endTime: endTime,
      );
    }

    await Future<void>.delayed(Duration(milliseconds: 300));

    titleController.dispose();
    descriptionController.dispose();
    subjectController.dispose();
    certificateController.dispose();
  }

  String? _validateStudyPlanInput({
    required String title,
    required String description,
    required String certificateName,
    required TimeOfDay? startTime,
    required TimeOfDay? endTime,
  }) {
    if (title.trim().isEmpty) {
      return '학습 과제 이름을 입력해주세요.';
    }

    if (description.trim().isEmpty) {
      return '학습 과제 설명을 입력해주세요.';
    }

    if (description.trim().length > 50) {
      return '학습 과제 설명은 50자 이하로 입력해주세요.';
    }

    if (certificateName.trim().isEmpty) {
      return '자격증명을 입력해주세요.';
    }

    // 시작·종료 시간을 모두 입력하지 않은 경우 허용
    if (startTime == null && endTime == null) {
      return null;
    }

    // 한쪽 시간만 입력한 경우는 허용하지 않음
    if (startTime == null || endTime == null) {
      return '공부 시간은 시작과 종료를 모두 선택하거나 모두 비워주세요.';
    }

    final int startMinutes = _timeOfDayToMinutes(startTime);
    final int endMinutes = _timeOfDayToMinutes(endTime);

    if (endMinutes <= startMinutes) {
      return '공부 종료 시간은 시작 시간보다 늦어야 합니다.';
    }

    return null;
  }

  Future<void> _addStudyPlan({
    required String title,
    required String description,
    required String subjectName,
    required String certificateName,
    required DateTime selectedDate,
    required TimeOfDay? startTime,
    required TimeOfDay? endTime,
  }) async {
    final CollectionReference<Map<String, dynamic>>? collection =
        _studyPlansCollection;

    if (collection == null) {
      _showSnackBar('로그인이 필요합니다.');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final User? user = _firebaseAuth.currentUser;

      if (user == null) {
        _showSnackBar('로그인이 필요합니다.');
        return;
      }

      final DateTime planDate = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
      );

      DateTime? startPlannedAt;
      DateTime? endPlannedAt;

      if (startTime != null && endTime != null) {
        startPlannedAt = DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
          startTime.hour,
          startTime.minute,
        );

        endPlannedAt = DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
          endTime.hour,
          endTime.minute,
        );
      }

      final DocumentReference<Map<String, dynamic>> studyPlanDocument =
          collection.doc();

      final String planId = studyPlanDocument.id;

      final DocumentReference<Map<String, dynamic>> calendarDocument =
          _firestore
              .collection('users')
              .doc(user.uid)
              .collection('calendarEvents')
              .doc('study_plan_$planId');

      final WriteBatch batch = _firestore.batch();

      final Map<String, dynamic> studyPlanData = {
        'planday': Timestamp.fromDate(planDate),
        'plantitle': title,
        'plandescription': description,
        'subjectname': subjectName.isEmpty ? null : subjectName,
        'certificatename': certificateName,
        'plantype': 'USERADD',
        'status': false,
        'completedat': null,
        'updatedat': FieldValue.serverTimestamp(),
      };

      if (startPlannedAt != null && endPlannedAt != null) {
        studyPlanData['startplannedat'] = Timestamp.fromDate(startPlannedAt);

        studyPlanData['endplannedat'] = Timestamp.fromDate(endPlannedAt);
      }

      batch.set(studyPlanDocument, studyPlanData);

      if (startPlannedAt != null && endPlannedAt != null) {
        batch.set(calendarDocument, {
          'title': title,
          'startAt': Timestamp.fromDate(startPlannedAt),
          'endAt': Timestamp.fromDate(endPlannedAt),
          'allDay': false,
          'eventType': 'STUDY',
        });
      } else {
        batch.set(calendarDocument, {
          'title': title,
          'startAt': Timestamp.fromDate(planDate),
          'endAt': Timestamp.fromDate(planDate.add(Duration(days: 1))),
          'allDay': true,
          'eventType': 'STUDY',
        });
      }

      await batch.commit();

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedDate = planDate;
      });

      await TodayTodoAppWidget.sync();

      _showSnackBar('학습 계획이 추가되었습니다.');
    } on FirebaseException catch (error) {
      _showSnackBar(
        error.code == 'permission-denied'
            ? '학습 계획을 추가할 권한이 없습니다.'
            : '학습 계획 저장에 실패했습니다.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _showDeleteTaskDialog(StudyPlanTask task) async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AppAlertDialog(
          icon: Icons.delete_outline_rounded,
          isDestructive: true,
          title: Text(
            '학습 계획 삭제',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: Text('"${task.title}" 학습 계획을 삭제하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: Text(
                '취소',
                style: TextStyle(color: context.colors.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: Text(
                '삭제',
                style: TextStyle(
                  color: context.colors.incorrect,
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

    final CollectionReference<Map<String, dynamic>>? collection =
        _studyPlansCollection;

    if (collection == null) {
      _showSnackBar('로그인이 필요합니다.');
      return;
    }

    try {
      final User? user = _firebaseAuth.currentUser;

      if (user == null) {
        _showSnackBar('로그인이 필요합니다.');
        return;
      }

      final WriteBatch batch = _firestore.batch();

      batch.delete(collection.doc(task.id));

      batch.delete(
        _firestore
            .collection('users')
            .doc(user.uid)
            .collection('calendarEvents')
            .doc('study_plan_${task.id}'),
      );

      await batch.commit();
      await TodayTodoAppWidget.sync();

      _showSnackBar('학습 계획이 삭제되었습니다.');
    } on FirebaseException catch (error) {
      _showSnackBar(
        error.code == 'permission-denied'
            ? '학습 계획을 삭제할 권한이 없습니다.'
            : '학습 계획 삭제에 실패했습니다.',
      );
    }
  }

  int _timeOfDayToMinutes(TimeOfDay time) {
    return time.hour * 60 + time.minute;
  }

  String _formatTaskTime(StudyPlanTask task) {
    if (task.startPlannedAt == null) {
      return '';
    }

    final String start = _formatDateTimeTime(task.startPlannedAt!);

    if (task.endPlannedAt == null) {
      return start;
    }

    final String end = _formatDateTimeTime(task.endPlannedAt!);

    return '$start - $end';
  }

  String _formatDateTimeTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime date) {
    List<String> weekdays = ['월', '화', '수', '목', '금', '토', '일'];

    return '${date.year}년 ${date.month}월 ${date.day}일 '
        '${weekdays[date.weekday - 1]}요일';
  }

  String _getDateLabel(DateTime date) {
    final DateTime today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    final DateTime target = DateTime(date.year, date.month, date.day);

    final int difference = target.difference(today).inDays;

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

  String _formatDialogDate(DateTime date) {
    return '${date.year}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String _formatTimeOfDay(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
  }

  StudyPlanTaskStyle _getTaskStyle(StudyPlanTaskType type) {
    switch (type) {
      case StudyPlanTaskType.aiPlan:
        return StudyPlanTaskStyle(
          label: 'AI 학습 계획',
          foregroundColor: context.colors.lavenderAccent,
          backgroundColor: context.colors.lavender,
        );
      case StudyPlanTaskType.user:
        return StudyPlanTaskStyle(
          label: '직접 추가',
          foregroundColor: context.colors.mintAccent,
          backgroundColor: context.colors.mint,
        );
    }
  }

  String _getFirestoreErrorMessage(Object? error) {
    if (error is FirebaseException && error.code == 'permission-denied') {
      return '학습 계획을 조회할 권한이 없습니다.';
    }

    return '잠시 후 다시 시도해주세요.';
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

enum StudyPlanTaskType { aiPlan, user }

class StudyPlanTask {
  final String id;
  final String sourceDocumentId;
  final int? aiStepIndex;
  final int order;

  final String title;
  final String description;
  final String? subjectName;
  final String certificateName;
  final DateTime date;
  final StudyPlanTaskType type;
  final DateTime? startPlannedAt;
  final DateTime? endPlannedAt;
  final bool isCompleted;
  final DateTime? completedAt;
  final DateTime? updatedAt;

  StudyPlanTask({
    required this.id,
    required this.sourceDocumentId,
    required this.aiStepIndex,
    required this.order,
    required this.title,
    required this.description,
    required this.subjectName,
    required this.certificateName,
    required this.date,
    required this.type,
    required this.startPlannedAt,
    required this.endPlannedAt,
    required this.isCompleted,
    required this.completedAt,
    required this.updatedAt,
  });

  bool get isAiStep => aiStepIndex != null;

  factory StudyPlanTask.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final Map<String, dynamic> data = document.data();

    final Timestamp? planDay = data['planday'] as Timestamp?;
    final Timestamp? startPlannedAt = data['startplannedat'] as Timestamp?;
    final Timestamp? endPlannedAt = data['endplannedat'] as Timestamp?;
    final Timestamp? completedAt = data['completedat'] as Timestamp?;
    final Timestamp? updatedAt = data['updatedat'] as Timestamp?;

    final String? rawType = data['plantype'] is String
        ? (data['plantype'] as String).trim()
        : null;

    return StudyPlanTask(
      id: document.id,
      sourceDocumentId: document.id,
      aiStepIndex: null,
      order: 0,
      title: (data['plantitle'] as String? ?? '').trim(),
      description: (data['plandescription'] as String? ?? '').trim(),
      subjectName: _readNullableString(data['subjectname']),
      certificateName: (data['certificatename'] as String? ?? '').trim(),
      date: planDay?.toDate() ?? DateTime.now(),
      type: rawType == 'USERADD'
          ? StudyPlanTaskType.user
          : StudyPlanTaskType.aiPlan,
      startPlannedAt: startPlannedAt?.toDate(),
      endPlannedAt: endPlannedAt?.toDate(),
      isCompleted: data['status'] as bool? ?? false,
      completedAt: completedAt?.toDate(),
      updatedAt: updatedAt?.toDate(),
    );
  }

  static List<StudyPlanTask> fromAiPlanDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final Map<String, dynamic> data = document.data();

    final List<dynamic> rawSteps = data['steps'] is List
        ? data['steps'] as List<dynamic>
        : <dynamic>[];

    final String certificateName = (data['certificateName'] as String? ?? '')
        .trim();

    final Timestamp? updatedAt = data['updatedAt'] as Timestamp?;

    final DateTime recommendedStartDate = _parseRecommendedStartDate(
      data['recommendedStudyStartDate'],
    );

    final List<StudyPlanTask> tasks = <StudyPlanTask>[];

    for (int index = 0; index < rawSteps.length; index++) {
      final Object? rawStep = rawSteps[index];

      if (rawStep is! Map) {
        continue;
      }

      final Map<String, dynamic> step = Map<String, dynamic>.from(rawStep);

      final int order = step['order'] is num
          ? (step['order'] as num).toInt()
          : index + 1;

      final String dayLabel = (step['dayLabel'] as String? ?? '').trim();

      final DateTime stepDate = _parseStepDate(
        dayLabel: dayLabel,
        recommendedStartDate: recommendedStartDate,
        fallbackIndex: index,
      );

      tasks.add(
        StudyPlanTask(
          id: '${document.id}_step_$index',
          sourceDocumentId: document.id,
          aiStepIndex: index,
          order: order,
          title: (step['title'] as String? ?? '').trim(),
          description: (step['detail'] as String? ?? '').trim(),
          subjectName: null,
          certificateName: certificateName,
          date: stepDate,
          type: StudyPlanTaskType.aiPlan,
          startPlannedAt: null,
          endPlannedAt: null,
          isCompleted: step['isCompleted'] as bool? ?? false,
          completedAt: null,
          updatedAt: updatedAt?.toDate(),
        ),
      );
    }

    return tasks;
  }

  static DateTime _parseRecommendedStartDate(Object? value) {
    if (value is String) {
      final DateTime? parsed = DateTime.tryParse(value.trim());

      if (parsed != null) {
        return DateTime(parsed.year, parsed.month, parsed.day);
      }
    }

    final DateTime now = DateTime.now();

    return DateTime(now.year, now.month, now.day);
  }

  static DateTime _parseStepDate({
    required String dayLabel,
    required DateTime recommendedStartDate,
    required int fallbackIndex,
  }) {
    final RegExpMatch? match = RegExp(
      r'(\d{1,2})/(\d{1,2})',
    ).firstMatch(dayLabel);

    if (match == null) {
      return recommendedStartDate.add(Duration(days: fallbackIndex));
    }

    final int? month = int.tryParse(match.group(1) ?? '');
    final int? day = int.tryParse(match.group(2) ?? '');

    if (month == null || day == null) {
      return recommendedStartDate.add(Duration(days: fallbackIndex));
    }

    int year = recommendedStartDate.year;

    // 예: 시작일이 2026년 12월이고 step이 1월이면 다음 해로 처리
    if (month < recommendedStartDate.month) {
      year += 1;
    }

    return DateTime(year, month, day);
  }

  static String? _readNullableString(Object? value) {
    if (value is! String) {
      return null;
    }

    final String trimmedValue = value.trim();

    return trimmedValue.isEmpty ? null : trimmedValue;
  }
}

class StudyPlanTaskStyle {
  final String label;
  final Color foregroundColor;
  final Color backgroundColor;

  StudyPlanTaskStyle({
    required this.label,
    required this.foregroundColor,
    required this.backgroundColor,
  });
}

class _StudyPlanSelectTile extends StatelessWidget {
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
        padding: EdgeInsets.all(13),
        decoration: BoxDecoration(
          border: Border.all(color: context.colors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: context.colors.pinkStart),
            SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.colors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: context.colors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
