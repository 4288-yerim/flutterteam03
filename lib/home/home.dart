import 'package:flutter/material.dart';
import '../widgets/app_main_background.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/app_bottom_bar.dart';
import '../certificate/certificate_schedule.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {

  // 추후 Firestore 데이터로 교체
  final List<HomeTodo> _todos = const [
    HomeTodo(
      title: '자료구조 기본 개념 복습',
      time: '09:00 - 11:00',
      color: Color(0xFFF58AA3),
    ),
    HomeTodo(
      title: '기출문제 풀이 (2023)',
      time: '14:00 - 16:00',
      color: Color(0xFF7899F3),
    ),
    HomeTodo(
      title: '스터디 모임',
      time: '19:00 - 21:00',
      color: Color(0xFFF4C65F),
    ),
  ];

  void _onNotificationPressed() {
    // TODO: 알림 페이지 연결
    debugPrint('알림 버튼 클릭');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      extendBody: true,

      appBar: AppTopBar(
        centerTitle: false,
        title: '안녕하세요, 00님!',
        actions: [
          IconButton(
            onPressed: _onNotificationPressed,
            icon: const Icon(
              Icons.notifications_none_rounded,
              color: Color(0xFF2E292B),
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),

      body: AppMainBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            24,
            20,
            24,
            130,
          ),
          children: [
            _CertificateScheduleButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CertificateSchedulePage(),
                  ),
                );
              },
            ),

            const SizedBox(height: 14),

            const _DdayCard(
              category: 'D-Day',
              certificateName: '정보처리기사 필기',
              dDay: 'D-28',
              examDate: '2025. 07. 20 (일)',
            ),

            const SizedBox(height: 28),

            _SectionHeader(
              title: '오늘의 할 일',
              actionText: '전체보기',
              onActionPressed: () {
                // TODO: 전체 일정 페이지 이동
                debugPrint('오늘의 할 일 전체보기');
              },
            ),

            const SizedBox(height: 14),

            _TodayTodoCard(todos: _todos),

            const SizedBox(height: 32),

            const _WeeklyStudyHeader(
              completedCount: 4,
              totalCount: 5,
            ),

            const SizedBox(height: 16),

            const _StudyProgressCard(
              title: '정보처리기사 스터디',
              progress: 0.75,
            ),
          ],
        ),
      ),
    );
  }
}

/// 자격증 D-Day 카드
class _DdayCard extends StatelessWidget {
  final String category;
  final String certificateName;
  final String dDay;
  final String examDate;

  const _DdayCard({
    required this.category,
    required this.certificateName,
    required this.dDay,
    required this.examDate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFD7E1),
            Color(0xFFF5A8BE),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            category,
            style: const TextStyle(
              color: Color(0xFFE96387),
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 7),

          Text(
            certificateName,
            style: const TextStyle(
              color: Color(0xFF2E292B),
              fontSize: 23,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
            ),
          ),

          const SizedBox(height: 22),

          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  dDay,
                  style: const TextStyle(
                    color: Color(0xFFEA668A),
                    fontSize: 58,
                    fontWeight: FontWeight.w800,
                    height: 1,
                    letterSpacing: -2,
                  ),
                ),
              ),
              const Icon(
                Icons.calendar_month_outlined,
                size: 51,
                color: Colors.white,
              ),
            ],
          ),

          const SizedBox(height: 14),

          Text(
            examDate,
            style: const TextStyle(
              color: Color(0xFFEA668A),
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// 공통 섹션 제목
class _SectionHeader extends StatelessWidget {
  final String title;
  final String? actionText;
  final VoidCallback? onActionPressed;

  const _SectionHeader({
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

/// 오늘의 할 일 카드
class _TodayTodoCard extends StatelessWidget {
  final List<HomeTodo> todos;

  const _TodayTodoCard({
    required this.todos,
  });

  @override
  Widget build(BuildContext context) {
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
              child: _TodoItem(todo: todo),
            );
          },
        ),
      ),
    );
  }
}

/// 할 일 한 줄
class _TodoItem extends StatefulWidget {
  final HomeTodo todo;

  const _TodoItem({
    required this.todo,
  });

  @override
  State<_TodoItem> createState() => _TodoItemState();
}

class _TodoItemState extends State<_TodoItem> {
  bool _isCompleted = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        setState(() {
          _isCompleted = !_isCompleted;
        });
      },
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
              color: _isCompleted
                  ? const Color(0xFFF48BA4)
                  : Colors.transparent,
              border: Border.all(
                color: _isCompleted
                    ? const Color(0xFFF48BA4)
                    : const Color(0xFFECE4E7),
                width: 2,
              ),
            ),
            child: _isCompleted
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
                  widget.todo.title,
                  style: TextStyle(
                    color: const Color(0xFF302C2E),
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    decoration: _isCompleted
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                    decorationColor: const Color(0xFF8D8789),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.todo.time,
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
              color: widget.todo.color,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

/// 이번 주 스터디 제목
class _WeeklyStudyHeader extends StatelessWidget {
  final int completedCount;
  final int totalCount;

  const _WeeklyStudyHeader({
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
class _StudyProgressCard extends StatelessWidget {
  final String title;
  final double progress;

  const _StudyProgressCard({
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

/// 임시 할 일 데이터 모델
class HomeTodo {
  final String title;
  final String time;
  final Color color;

  const HomeTodo({
    required this.title,
    required this.time,
    required this.color,
  });
}

class _CertificateScheduleButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _CertificateScheduleButton({
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

