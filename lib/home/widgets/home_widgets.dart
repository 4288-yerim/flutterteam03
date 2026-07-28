import 'package:flutter/material.dart';

import '../services/home_service.dart';

class HomeGoalCardSlider extends StatefulWidget {
  final List<HomeGoal> goals;
  final int currentIndex;
  final ValueChanged<int> onPageChanged;

  const HomeGoalCardSlider({
    super.key,
    required this.goals,
    required this.currentIndex,
    required this.onPageChanged,
  });

  @override
  State<HomeGoalCardSlider> createState() =>
      _HomeGoalCardSliderState();
}

class _HomeGoalCardSliderState extends State<HomeGoalCardSlider> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();

    final initialPage = widget.goals.isEmpty
        ? 0
        : widget.currentIndex.clamp(
      0,
      widget.goals.length - 1,
    );

    _pageController = PageController(
      initialPage: initialPage,
      viewportFraction: 0.94,
    );
  }

  @override
  void didUpdateWidget(
      covariant HomeGoalCardSlider oldWidget,
      ) {
    super.didUpdateWidget(oldWidget);

    if (widget.goals.isEmpty) {
      return;
    }

    if (widget.currentIndex >= widget.goals.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_pageController.hasClients) {
          return;
        }

        _pageController.jumpToPage(
          widget.goals.length - 1,
        );
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.goals.isEmpty) {
      return const SizedBox(
        height: 409,
      );
    }

    final safeIndex = widget.currentIndex.clamp(
      0,
      widget.goals.length - 1,
    );

    return Column(
      children: [
        SizedBox(
          height: 395,
          child: PageView.builder(
            controller: _pageController,
            physics: const PageScrollPhysics(),
            itemCount: widget.goals.length,
            onPageChanged: widget.onPageChanged,
            itemBuilder: (context, index) {
              final goal = widget.goals[index];

              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 5,
                ),
                child: _HomeGoalCard(
                  key: ValueKey<String>(goal.id),
                  goal: goal,
                ),
              );
            },
          ),
        ),
        if (widget.goals.length > 1) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 7,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.goals.length,
                    (index) {
                  final isSelected = safeIndex == index;

                  return AnimatedContainer(
                    duration: const Duration(
                      milliseconds: 200,
                    ),
                    width: isSelected ? 18 : 7,
                    height: 7,
                    margin: const EdgeInsets.symmetric(
                      horizontal: 3,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFF06F91)
                          : const Color(0xFFE8D8DD),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  );
                },
              ),
            ),
          ),
        ] else
          const SizedBox(height: 19),
      ],
    );
  }
}

class _HomeGoalCard extends StatelessWidget {
  final HomeGoal goal;

  String _formatShortDate(DateTime date) {
    final local = date.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');

    return '$month.$day';
  }

  const _HomeGoalCard({
    super.key,
    required this.goal,
  });

  String _calculateDday() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final examDate = goal.examDateOnly;
    final difference = examDate.difference(today).inDays;

    if (difference == 0) {
      return 'D-Day';
    }

    return difference > 0 ? 'D-$difference' : 'D+${difference.abs()}';
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final weekday = weekdays[local.weekday - 1];

    return '${local.year}. $month. $day ($weekday)';
  }

  String _formatDateRange(
      DateTime? start,
      DateTime? end,
      ) {
    if (start == null && end == null) {
      return '-';
    }

    if (start == null) {
      return _formatDate(end!);
    }

    if (end == null) {
      return _formatDate(start);
    }

    final localStart = start.toLocal();
    final localEnd = end.toLocal();

    final isSameDay =
        localStart.year == localEnd.year &&
            localStart.month == localEnd.month &&
            localStart.day == localEnd.day;

    if (isSameDay) {
      return _formatDate(start);
    }

    if (localStart.year == localEnd.year) {
      return '${localStart.year}. '
          '${_formatShortDate(start)} ~ '
          '${_formatShortDate(end)}';
    }

    return '${_formatDate(start)}\n'
        '~ ${_formatDate(end)}';
  }

  String _formatRegistrationPeriod() {
    return _formatDateRange(
      goal.targetRegistrationStartDate,
      goal.targetRegistrationEndDate,
    );
  }

  String _formatPassAnnouncement() {
    return _formatDateRange(
      goal.targetPassAnnouncementDate,
      goal.targetPassAnnouncementEndDate,
    );
  }

  @override
  Widget build(BuildContext context) {
    const gradientColors = [
      Color(0xFFFFD7E1),
      Color(0xFFF5A8BE),
    ];

    const accentColor = Color(0xFFE96387);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _GoalBadge(
                label: goal.qualificationLabel,
                foregroundColor: accentColor,
              ),
              const Spacer(),
              if (goal.isMainGoal)
                _MainGoalBadge(
                  foregroundColor: accentColor,
                ),
            ],
          ),
          const SizedBox(height: 13),
          Text(
            goal.certificateName.isEmpty ? '자격증 이름 없음' : goal.certificateName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF2E292B),
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            goal.targetRound.isEmpty ? '-' : goal.targetRound,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: accentColor,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 15),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  _calculateDday(),
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 50,
                    fontWeight: FontWeight.w800,
                    height: 1,
                    letterSpacing: -1.8,
                  ),
                ),
              ),
              const Icon(
                Icons.calendar_month_outlined,
                size: 45,
                color: Colors.white,
              ),
            ],
          ),
          const SizedBox(height: 17),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 15,
              vertical: 15,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.68),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                _GoalInfoRow(
                  label: '원서접수',
                  value: _formatRegistrationPeriod(),
                ),
                const SizedBox(height: 9),
                _GoalInfoRow(
                  label: '시험일',
                  value: _formatDate(
                    goal.targetExamDate,
                  ),
                ),
                const SizedBox(height: 9),
                _GoalInfoRow(
                  label: '시험 유형',
                  value: goal.examTypeLabel,
                ),
                const SizedBox(height: 9),
                _GoalInfoRow(
                  label: '합격자 발표',
                  value: _formatPassAnnouncement(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalBadge extends StatelessWidget {
  final String label;
  final Color foregroundColor;

  const _GoalBadge({
    required this.label,
    required this.foregroundColor,
  });



  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foregroundColor,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _GoalInfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _GoalInfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 78,
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF746D70),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.visible,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Color(0xFF302C2E),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _MainGoalBadge extends StatelessWidget {
  final Color foregroundColor;

  const _MainGoalBadge({
    required this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.star_rounded,
            color: foregroundColor,
            size: 15,
          ),
          const SizedBox(width: 4),
          Text(
            '대표 목표',
            style: TextStyle(
              color: foregroundColor,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// 공통 섹션 제목
class HomeSectionHeader extends StatelessWidget {
  final String title;
  final String? actionText;
  final VoidCallback? onActionPressed;

  const HomeSectionHeader({
    required this.title,
    this.actionText,
    this.onActionPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Color(0xFF2E292B),
              fontSize: 23,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.7,
            ),
          ),
        ),
        if (actionText != null)
          TextButton(
            onPressed: onActionPressed,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF898184),
              padding: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 4,
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  actionText!,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class HomeTodayTodoCard extends StatelessWidget {
  final List<HomeTodo> todos;
  final ValueChanged<HomeTodo>? onTodoPressed;

  const HomeTodayTodoCard({
    required this.todos,
    this.onTodoPressed,
  });

  @override
  Widget build(BuildContext context) {
    if (todos.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 30,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.018),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Column(
          children: [
            Icon(
              Icons.event_available_outlined,
              size: 36,
              color: Color(0xFFB3AAAD),
            ),
            SizedBox(height: 10),
            Text(
              '오늘 계획된 학습이 없습니다.',
              style: TextStyle(
                color: Color(0xFF817B7D),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 18,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.018),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: List.generate(
          todos.length,
              (index) {
            final todo = todos[index];

            return Padding(
              padding: EdgeInsets.only(
                bottom: index == todos.length - 1 ? 0 : 20,
              ),
              child: _HomeTodoItem(
                todo: todo,
                onPressed: onTodoPressed == null
                    ? null
                    : () {
                  onTodoPressed!(todo);
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HomeTodoItem extends StatelessWidget {
  final HomeTodo todo;
  final VoidCallback? onPressed;

  const _HomeTodoItem({
    required this.todo,
    this.onPressed,
  });

  String _formatTime(DateTime date) {
    final local = date.toLocal();

    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  String? _formatTimeRange() {
    final DateTime? start = todo.startPlannedAt;
    final DateTime? end = todo.endPlannedAt;

    if (start == null || end == null) {
      return null;
    }

    return '${_formatTime(start)} - ${_formatTime(end)}';
  }

  Color _getPlanTypeColor() {
    if (todo.planType == 'USERADD') {
      return const Color(0xFF62BE88);
    }

    return const Color(0xFF9B7BEA);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: todo.isCompleted
                  ? const Color(0xFFF48BA4)
                  : Colors.transparent,
              border: Border.all(
                color: todo.isCompleted
                    ? const Color(0xFFF48BA4)
                    : const Color(0xFFECE4E7),
                width: 2,
              ),
            ),
            child: todo.isCompleted
                ? const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 16,
            )
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  todo.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFF302C2E),
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    decoration: todo.isCompleted
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                    decorationColor: const Color(0xFF8D8789),
                  ),
                ),
                if (_formatTimeRange() != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _formatTimeRange()!,
                    style: const TextStyle(
                      color: Color(0xFF817B7D),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ] else if (todo.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    todo.description,
                    style: const TextStyle(
                      color: Color(0xFF817B7D),
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 11,
            height: 11,
            decoration: BoxDecoration(
              color: _getPlanTypeColor(),
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

class HomeTodayStudyCard extends StatefulWidget {
  final HomeTodayStudySummary summary;

  const HomeTodayStudyCard({
    super.key,
    required this.summary,
  });

  @override
  State<HomeTodayStudyCard> createState() =>
      _HomeTodayStudyCardState();
}

class _HomeTodayStudyCardState
    extends State<HomeTodayStudyCard> {
  bool _isDetailExpanded = false;

  String _formatSeconds(int totalSeconds) {
    if (totalSeconds <= 0) {
      return '0초';
    }

    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return '$hours시간 $minutes분 $seconds초';
    }

    if (minutes > 0) {
      return '$minutes분 $seconds초';
    }

    return '$seconds초';
  }

  String _formatTime(DateTime date) {
    final local = date.toLocal();

    final hour =
    local.hour.toString().padLeft(2, '0');

    final minute =
    local.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  IconData _getStudyTypeIcon(
      HomeStudyRecord record,
      ) {
    if (record.isStudyGroup) {
      return Icons.groups_2_outlined;
    }

    switch (record.studyType) {
      case 'PRACTICE':
        return Icons.edit_note_outlined;

      case 'REVIEW':
        return Icons.replay_outlined;

      case 'LECTURE':
        return Icons.play_circle_outline_rounded;

      case 'OTHER':
        return Icons.notes_rounded;

      default:
        return Icons.menu_book_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        20,
        20,
        20,
        18,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: 0.018,
            ),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFFCEFF3),
                  borderRadius:
                  BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.timer_outlined,
                  color: Color(0xFFF0788F),
                  size: 24,
                ),
              ),
              const SizedBox(width: 13),
              const Expanded(
                child: Text(
                  '오늘 공부한 시간',
                  style: TextStyle(
                    color: Color(0xFF817B7D),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                _formatSeconds(
                  summary.totalSeconds,
                ),
                style: const TextStyle(
                  color: Color(0xFFF06F91),
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 11,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFF9F5F7),
              borderRadius:
              BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _HomeStudyTimeBreakdown(
                    label: '개인 공부',
                    value: _formatSeconds(
                      summary.personalSeconds,
                    ),
                    color:
                    const Color(0xFFF0788F),
                  ),
                ),
                Container(
                  width: 1,
                  height: 32,
                  color: const Color(0xFFE9DFE3),
                ),
                Expanded(
                  child: _HomeStudyTimeBreakdown(
                    label: '스터디 공부',
                    value: _formatSeconds(
                      summary.studySeconds,
                    ),
                    color:
                    const Color(0xFF8874C9),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(
            height: 1,
            color: Color(0xFFF0E9EC),
          ),
          InkWell(
            onTap: () {
              setState(() {
                _isDetailExpanded =
                !_isDetailExpanded;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 14,
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '오늘 상세 기록',
                      style: TextStyle(
                        color: Color(0xFF302C2E),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns:
                    _isDetailExpanded ? 0.5 : 0,
                    duration: const Duration(
                      milliseconds: 180,
                    ),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFF817B7D),
                      size: 25,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(
              milliseconds: 200,
            ),
            crossFadeState: _isDetailExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild:
            const SizedBox(width: double.infinity),
            secondChild: _buildDetailRecords(),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRecords() {
    final records = widget.summary.records;

    if (records.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(
          vertical: 14,
        ),
        child: Center(
          child: Text(
            '오늘 기록된 공부 시간이 없습니다.',
            style: TextStyle(
              color: Color(0xFF817B7D),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    return Column(
      children: List.generate(
        records.length,
            (index) {
          final record = records[index];

          final iconColor = record.isStudyGroup
              ? const Color(0xFF8874C9)
              : const Color(0xFFF0788F);

          final iconBackground =
          record.isStudyGroup
              ? const Color(0xFFF4F1FF)
              : const Color(0xFFFCEFF3);

          return Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: iconBackground,
                      borderRadius:
                      BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getStudyTypeIcon(record),
                      color: iconColor,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.subject,
                          maxLines: 1,
                          overflow:
                          TextOverflow.ellipsis,
                          style: const TextStyle(
                            color:
                            Color(0xFF302C2E),
                            fontSize: 15,
                            fontWeight:
                            FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          record.isStudyGroup
                              ? '스터디 · '
                              '${record.description}'
                              : record.description,
                          maxLines: 1,
                          overflow:
                          TextOverflow.ellipsis,
                          style: const TextStyle(
                            color:
                            Color(0xFF817B7D),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _formatTime(
                            record.studiedAt,
                          ),
                          style: const TextStyle(
                            color:
                            Color(0xFFA09A9C),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _formatSeconds(
                      record.seconds > 0
                          ? record.seconds
                          : record.minutes * 60,
                    ),
                    style: TextStyle(
                      color: iconColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              if (index != records.length - 1)
                const Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: 13,
                  ),
                  child: Divider(
                    height: 1,
                    color: Color(0xFFF0E9EC),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _HomeStudyTimeBreakdown
    extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _HomeStudyTimeBreakdown({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF817B7D),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class HomeStudyGroupStatusCard
    extends StatelessWidget {
  final List<HomeStudyGroupSummary> studyGroups;

  const HomeStudyGroupStatusCard({
    super.key,
    required this.studyGroups,
  });

  @override
  Widget build(BuildContext context) {
    if (studyGroups.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 30,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(
            alpha: 0.92,
          ),
          borderRadius: BorderRadius.circular(28),
        ),
        child: const Column(
          children: [
            Icon(
              Icons.groups_outlined,
              size: 36,
              color: Color(0xFFB3AAAD),
            ),
            SizedBox(height: 10),
            Text(
              '참여한 스터디가 없습니다.',
              style: TextStyle(
                color: Color(0xFF817B7D),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: List.generate(
        studyGroups.length,
            (index) {
          return Padding(
            padding: EdgeInsets.only(
              bottom:
              index == studyGroups.length - 1
                  ? 0
                  : 12,
            ),
            child: _HomeStudyGroupItem(
              group: studyGroups[index],
            ),
          );
        },
      ),
    );
  }
}

class _HomeStudyGroupItem
    extends StatefulWidget {
  final HomeStudyGroupSummary group;

  const _HomeStudyGroupItem({
    required this.group,
  });

  @override
  State<_HomeStudyGroupItem> createState() =>
      _HomeStudyGroupItemState();
}

class _HomeStudyGroupItemState
    extends State<_HomeStudyGroupItem> {
  bool _isExpanded = false;

  String _formatSeconds(int totalSeconds) {
    if (totalSeconds <= 0) {
      return '0초';
    }

    final hours = totalSeconds ~/ 3600;
    final minutes =
        (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return '$hours시간 $minutes분 $seconds초';
    }

    if (minutes > 0) {
      return '$minutes분 $seconds초';
    }

    return '$seconds초';
  }

  String _formatHoursAndMinutes(int totalSeconds) {
    if (totalSeconds <= 0) {
      return '0분';
    }

    final totalMinutes = totalSeconds ~/ 60;
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;

    if (hours > 0) {
      return '$hours시간 $minutes분';
    }

    return '$minutes분';
  }

  String _buildStudyProgressText(
      HomeStudyGroupSummary group,
      ) {
    if (group.weeklyGoalSeconds <= 0) {
      return '주간 목표 미설정';
    }

    return '이번 주 ${_formatHoursAndMinutes(group.weeklyStudySeconds)}'
        ' / 목표 ${_formatHoursAndMinutes(group.weeklyGoalSeconds)}';
  }

  String _buildMemberStatusText(
      HomeStudyGroupSummary group,
      ) {
    return '공부 중 ${group.studyingMemberCount}명'
        ' · 휴식 중 ${group.restingMemberCount}명'
        ' · 일시정지 ${group.pausedMemberCount}명';
  }

  Widget _buildRankBadge(int rank) {
    // 4등부터는 배경 없이 검은색 숫자만 표시합니다.
    if (rank >= 4) {
      return SizedBox(
        width: 38,
        height: 38,
        child: Center(
          child: Text(
            '$rank',
            style: const TextStyle(
              color: Color(0xFF302C2E),
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      );
    }

    final Color backgroundColor;
    final Color textColor;

    switch (rank) {
      case 1:
        backgroundColor = const Color(0xFFFFD86B);
        textColor = const Color(0xFF795A00);
        break;

      case 2:
        backgroundColor = const Color(0xFFD9DEE7);
        textColor = const Color(0xFF596273);
        break;

      case 3:
        backgroundColor = const Color(0xFFD99A6C);
        textColor = const Color(0xFF6C351D);
        break;

      default:
        backgroundColor = Colors.transparent;
        textColor = const Color(0xFF302C2E);
    }

    return SizedBox(
      width: 42,
      height: 44,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned(
            bottom: 0,
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: backgroundColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: backgroundColor.withValues(
                      alpha: 0.28,
                    ),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Text(
                '$rank',
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),

          if (rank == 1)
            Positioned(
              top: -4,
              right: -1,
              child: Transform.rotate(
                angle: 0.28,
                child: const Text(
                  '👑',
                  style: TextStyle(
                    fontSize: 19,
                    height: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.group;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(
          alpha: 0.92,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: 0.018,
            ),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color:
                      const Color(0xFFF4F1FF),
                      borderRadius:
                      BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.groups_2_outlined,
                      color: Color(0xFF8874C9),
                      size: 23,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.groupName,
                          maxLines: 1,
                          overflow:
                          TextOverflow.ellipsis,
                          style: const TextStyle(
                            color:
                            Color(0xFF302C2E),
                            fontSize: 16,
                            fontWeight:
                            FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _buildStudyProgressText(group),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF8874C9),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: const Duration(
                      milliseconds: 180,
                    ),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFF817B7D),
                      size: 25,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(
              milliseconds: 200,
            ),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild:
            const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(
                18,
                0,
                18,
                18,
              ),
              child: Column(
                children: [
                  const Divider(
                    height: 1,
                    color: Color(0xFFF0E9EC),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9F5F7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _buildMemberStatusText(group),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF817B7D),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  ...List.generate(
                    group.members.length,
                        (index) {
                      final member =
                      group.members[index];

                      return Padding(
                        padding: EdgeInsets.only(
                          bottom:
                          index ==
                              group.members.length -
                                  1
                              ? 0
                              : 12,
                        ),
                        child: Row(
                          children: [
                            _buildRankBadge(index + 1),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      member.nickname,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: member.hasLeft
                                            ? const Color(0xFF9A9396)
                                            : const Color(0xFF302C2E),
                                        fontSize: 14,
                                        fontWeight: member.hasLeft
                                            ? FontWeight.w500
                                            : FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  if (member.isCurrentUser &&
                                      !member.hasLeft) ...[
                                    const SizedBox(
                                      width: 6,
                                    ),
                                    const Text(
                                      '나',
                                      style: TextStyle(
                                        color: Color(
                                          0xFFF0788F,
                                        ),
                                        fontSize: 11,
                                        fontWeight:
                                        FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _formatSeconds(
                                member.studySeconds,
                              ),
                              style: const TextStyle(
                                color:
                                Color(0xFF8874C9),
                                fontSize: 13,
                                fontWeight:
                                FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HomeTodayStudyLoadingCard
    extends StatelessWidget {
  const HomeTodayStudyLoadingCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 150,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(28),
      ),
      child: const Center(
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: Color(0xFFF06F91),
          ),
        ),
      ),
    );
  }
}

class HomeTodayStudyErrorCard
    extends StatelessWidget {
  final String message;

  const HomeTodayStudyErrorCard({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 26,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 34,
            color: Color(0xFFF06F91),
          ),
          const SizedBox(height: 10),
          const Text(
            '오늘 공부 기록을 불러오지 못했습니다.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF302C2E),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF817B7D),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class HomeCertificateScheduleButton extends StatelessWidget {
  final VoidCallback onPressed;

  const HomeCertificateScheduleButton({
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF302C2E),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          side: const BorderSide(
            color: Color(0xFFFF6B95),
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
        child: const Row(
          children: [
            Icon(
              Icons.calendar_month_outlined,
              color: Color(0xFFFF6B95),
              size: 22,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                '자격증 일정 보기',
                style: TextStyle(
                  color: Color(0xFF302C2E),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFFFF6B95),
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}

class HomeGoalLoadingCard extends StatelessWidget {
  const HomeGoalLoadingCard({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 409,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            height: 390,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Color(0xFFF06F91),
                ),
              ),
            ),
          ),
          const SizedBox(height: 19),
        ],
      ),
    );
  }
}

class HomeGoalErrorCard extends StatelessWidget {
  final String message;

  const HomeGoalErrorCard({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 409,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 42,
            color: Color(0xFFF06F91),
          ),
          const SizedBox(height: 12),
          const Text(
            '목표 자격증을 불러오지 못했습니다.',
            style: TextStyle(
              color: Color(0xFF302C2E),
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF817B7D),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class HomeEmptyGoalCard extends StatelessWidget {
  const HomeEmptyGoalCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 409,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(28),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.flag_outlined,
            size: 42,
            color: Color(0xFFF06F91),
          ),
          SizedBox(height: 12),
          Text(
            '등록된 목표 자격증이 없습니다.',
            style: TextStyle(
              color: Color(0xFF302C2E),
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 6),
          Column(
            children: const [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '자격증 일정 보기에서 ',
                    style: TextStyle(
                      color: Color(0xFF817B7D),
                      fontSize: 14,
                    ),
                  ),
                  Icon(
                    Icons.search_rounded,
                    size: 17,
                    color: Color(0xFF817B7D),
                  ),
                  Text(
                    '를 눌러 검색 후',
                    style: TextStyle(
                      color: Color(0xFF817B7D),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4),
              Text(
                '원하는 자격증을 선택해 목표 시험을 등록해보세요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF817B7D),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
