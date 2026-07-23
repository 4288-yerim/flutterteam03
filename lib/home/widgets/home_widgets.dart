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
          height: 360,
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

  String _formatPassAnnouncement() {
    final start = goal.targetPassAnnouncementDate;
    final end = goal.targetPassAnnouncementEndDate;

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

    if (localStart.year == localEnd.year &&
        localStart.month == localEnd.month &&
        localStart.day == localEnd.day) {
      return _formatDate(start);
    }

    if (localStart.year == localEnd.year) {
      return '${localStart.year}. '
          '${_formatShortDate(start)} ~ '
          '${_formatShortDate(end)}';
    }

    return '${_formatDate(start)}\n~ ${_formatDate(end)}';
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
                  label: '시험일',
                  value: _formatDate(goal.targetExamDate),
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

  String _formatTimeRange() {
    return '${_formatTime(todo.startPlannedAt)}'
        ' - '
        '${_formatTime(todo.endPlannedAt)}';
  }

  Color _getPlanTypeColor() {
    switch (todo.planType) {
      case 'AIADD':
        return const Color(0xFF9B7BEA);

      case 'USERADD':
        return const Color(0xFF62BE88);

      default:
        return const Color(0xFFB3AAAD);
    }
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
                const SizedBox(height: 4),
                Text(
                  _formatTimeRange(),
                  style: const TextStyle(
                    color: Color(0xFF817B7D),
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
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

/// 이번 주 스터디 제목
class HomeWeeklyStudyHeader extends StatelessWidget {
  final int completedCount;
  final int totalCount;

  const HomeWeeklyStudyHeader({
    required this.completedCount,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '이번주 스터디',
          style: TextStyle(
            color: Color(0xFF2E292B),
            fontSize: 23,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.7,
          ),
        ),
        const SizedBox(height: 9),
        Text(
          '$completedCount / $totalCount 완료',
          style: const TextStyle(
            color: Color(0xFFF06F91),
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// 스터디 진행률 카드
class HomeStudyProgressCard extends StatelessWidget {
  final String title;
  final double progress;

  const HomeStudyProgressCard({
    required this.title,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final safeProgress = progress.clamp(0.0, 1.0);
    final progressPercent = (safeProgress * 100).round();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.018),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF302C2E),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 13),

          Text(
            '진행률 $progressPercent%',
            style: const TextStyle(
              color: Color(0xFF817B7D),
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),

          const SizedBox(height: 10),

          ClipRRect(
            borderRadius: BorderRadius.circular(50),
            child: LinearProgressIndicator(
              value: safeProgress,
              minHeight: 9,
              backgroundColor: const Color(0xFFF8E3EA),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFFF286A2),
              ),
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
          Text(
            '자격증 상세페이지에서 목표 시험을 등록해보세요.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF817B7D),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
