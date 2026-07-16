import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/app_main_background.dart';
import '../widgets/app_top_bar.dart';

class AiStudyPlanPage extends StatelessWidget {
  const AiStudyPlanPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    // TODO: 실제 데이터 연동 시 Firestore 등에서 불러오도록 교체
    const weeklyProgress = 0.62;
    const totalTasks = 18;
    const doneTasks = 11;

    final schedule = [
      _DayPlan(
        day: '월',
        date: '7/14',
        isDone: true,
        tasks: const [
          _StudyTask(title: '네트워크 계층 개념 정리', minutes: 40, done: true),
          _StudyTask(title: 'OSI 7계층 문제풀이', minutes: 30, done: true),
        ],
      ),
      _DayPlan(
        day: '화',
        date: '7/15',
        isDone: true,
        tasks: const [
          _StudyTask(title: '데이터베이스 정규화', minutes: 45, done: true),
        ],
      ),
      _DayPlan(
        day: '수',
        date: '7/16',
        isDone: false,
        isToday: true,
        tasks: const [
          _StudyTask(title: 'SQL 실전 문제 20개', minutes: 50, done: false),
          _StudyTask(title: '트랜잭션 개념 복습', minutes: 25, done: false),
        ],
      ),
      _DayPlan(
        day: '목',
        date: '7/17',
        isDone: false,
        tasks: const [
          _StudyTask(title: '운영체제 프로세스 관리', minutes: 40, done: false),
        ],
      ),
      _DayPlan(
        day: '금',
        date: '7/18',
        isDone: false,
        tasks: const [
          _StudyTask(title: '모의고사 1회 풀기', minutes: 60, done: false),
        ],
      ),
    ];

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: const AppTopBar(
        title: 'AI 학습 플랜',
        centerTitle: false,
      ),
      body: AppMainBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _WeeklyProgressCard(
                  colors: colors,
                  progress: weeklyProgress,
                  doneTasks: doneTasks,
                  totalTasks: totalTasks,
                ),
                const SizedBox(height: 28),
                Text(
                  '이번 주 학습 일정',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 14),
                ...schedule.map(
                      (plan) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _DayPlanCard(colors: colors, plan: plan),
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

class _WeeklyProgressCard extends StatelessWidget {
  final AppColors colors;
  final double progress;
  final int doneTasks;
  final int totalTasks;

  const _WeeklyProgressCard({
    required this.colors,
    required this.progress,
    required this.doneTasks,
    required this.totalTasks,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: colors.pinkSoft,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: colors.pinkStart, size: 20),
              const SizedBox(width: 8),
              Text(
                '이번 주 진행률',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${(progress * 100).round()}%',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '$doneTasks / $totalTasks 완료',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: colors.background,
              valueColor: AlwaysStoppedAnimation<Color>(colors.pinkStart),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayPlan {
  final String day;
  final String date;
  final bool isDone;
  final bool isToday;
  final List<_StudyTask> tasks;

  const _DayPlan({
    required this.day,
    required this.date,
    required this.isDone,
    this.isToday = false,
    required this.tasks,
  });
}

class _StudyTask {
  final String title;
  final int minutes;
  final bool done;

  const _StudyTask({
    required this.title,
    required this.minutes,
    required this.done,
  });
}

class _DayPlanCard extends StatelessWidget {
  final AppColors colors;
  final _DayPlan plan;

  const _DayPlanCard({required this.colors, required this.plan});

  @override
  Widget build(BuildContext context) {
    final badgeColor = plan.isDone
        ? colors.mint
        : plan.isToday
        ? colors.lavender
        : colors.background;

    final badgeTextColor = plan.isDone
        ? colors.textPrimary
        : plan.isToday
        ? colors.pinkStart
        : colors.textSecondary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: plan.isToday
              ? colors.pinkStart.withValues(alpha: 0.3)
              : colors.textSecondary.withValues(alpha: 0.08),
          width: 1.2,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: badgeColor,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              plan.day,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: badgeTextColor,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      plan.date,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (plan.isToday) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: colors.lavender,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '오늘',
                          style: TextStyle(
                            color: colors.pinkStart,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                ...plan.tasks.map(
                      (task) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(
                          task.done
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          size: 18,
                          color: task.done
                              ? colors.pinkStart
                              : colors.textSecondary.withValues(alpha: 0.4),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            task.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: task.done
                                  ? colors.textSecondary
                                  : colors.textPrimary,
                              decoration: task.done
                                  ? TextDecoration.lineThrough
                                  : null,
                              decorationColor: colors.textSecondary,
                            ),
                          ),
                        ),
                        Text(
                          '${task.minutes}분',
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
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