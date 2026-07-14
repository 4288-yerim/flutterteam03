import 'package:flutter/material.dart';
import '../widgets/app_main_background.dart';
import '../widgets/app_top_bar.dart';
import 'question_generation.dart';

class AiPage extends StatelessWidget {
  const AiPage({super.key});

  static const Color _textColor = Color(0xFF302C2E);
  static const Color _subTextColor = Color(0xFF8E8589);
  static const Color _pinkColor = Color(0xFFF4869D);

  void _onNotificationPressed() {
    debugPrint('알림 버튼 클릭');
  }

  void _onStudyPlanPressed() {
    debugPrint('학습 플랜 클릭');
  }

  void _onRoadmapPressed() {
    debugPrint('자격증 로드맵 클릭');
  }

  void _onQuestionPressed(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const QuestionGenerationPage(),
      ),
    );
  }

  void _onSummaryPressed() {
    debugPrint('자료 요약 클릭');
  }

  void _onStartPressed() {
    debugPrint('바로 시작 클릭');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppTopBar(
        title: 'AI 학습도우미',
        actions: [
          IconButton(
            onPressed: _onNotificationPressed,
            icon: const Icon(
              Icons.notifications_none_rounded,
              color: Color(0xFF302C2E),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: AppMainBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              24,
              22,
              24,
              36,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _AiWelcomeCard(),

                const SizedBox(height: 28),

                const _SectionTitle(title: '빠른 실행'),

                const SizedBox(height: 18),

                _QuickMenuSection(
                  onStudyPlanPressed: _onStudyPlanPressed,
                  onRoadmapPressed: _onRoadmapPressed,
                  onQuestionPressed: () {
                    _onQuestionPressed(context);
                  },
                  onSummaryPressed: _onSummaryPressed,
                ),

                const SizedBox(height: 32),

                const _SectionTitle(title: '오늘의 맞춤 제안'),

                const SizedBox(height: 18),

                _RecommendationCard(
                  onStartPressed: _onStartPressed,
                ),

                const SizedBox(height: 32),

                const _SectionTitle(title: 'AI 한마디'),

                const SizedBox(height: 18),

                const _AiMessageCard(),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AiWelcomeCard extends StatelessWidget {
  const _AiWelcomeCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(
        minHeight: 210,
      ),
      padding: const EdgeInsets.fromLTRB(
        22,
        26,
        20,
        24,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF0E9FF),
            Color(0xFFDCCFFF),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '안녕하세요, 00님!',
                  style: TextStyle(
                    color: AiPage._textColor,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  '이해하기 어려운 학습을\n도와주는 AI 도우미예요.',
                  style: TextStyle(
                    color: AiPage._subTextColor,
                    fontSize: 17,
                    height: 1.55,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Container(
            width: 104,
            height: 104,
            decoration: const BoxDecoration(
              color: Color(0xFFEDE7FF),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Text(
              '🤖',
              style: TextStyle(
                fontSize: 42,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: AiPage._textColor,
        fontSize: 23,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _QuickMenuSection extends StatelessWidget {
  final VoidCallback onStudyPlanPressed;
  final VoidCallback onRoadmapPressed;
  final VoidCallback onQuestionPressed;
  final VoidCallback onSummaryPressed;

  const _QuickMenuSection({
    required this.onStudyPlanPressed,
    required this.onRoadmapPressed,
    required this.onQuestionPressed,
    required this.onSummaryPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickMenuItem(
            icon: Icons.calendar_month_outlined,
            label: '학습 플랜',
            iconColor: const Color(0xFF9D7BFF),
            iconBackgroundColor: const Color(0xFFEDE6FF),
            onPressed: onStudyPlanPressed,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _QuickMenuItem(
            icon: Icons.route_rounded,
            label: '자격증 로드맵',
            iconColor: const Color(0xFF7DCFC5),
            iconBackgroundColor: const Color(0xFFE2F5F1),
            onPressed: onRoadmapPressed,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _QuickMenuItem(
            icon: Icons.radio_button_checked_rounded,
            label: '문제 생성',
            iconColor: const Color(0xFFFF829E),
            iconBackgroundColor: const Color(0xFFFFE4EA),
            onPressed: onQuestionPressed,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _QuickMenuItem(
            icon: Icons.article_outlined,
            label: '자료 요약',
            iconColor: const Color(0xFFFFBD4A),
            iconBackgroundColor: const Color(0xFFFFF1CE),
            onPressed: onSummaryPressed,
          ),
        ),
      ],
    );
  }
}

class _QuickMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;
  final Color iconBackgroundColor;
  final VoidCallback onPressed;

  const _QuickMenuItem({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.iconBackgroundColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 18,
            horizontal: 4,
          ),
          child: Column(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: iconBackgroundColor,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 28,
                ),
              ),
              const SizedBox(height: 13),
              Text(
                label,
                maxLines: 1,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AiPage._textColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  final VoidCallback onStartPressed;

  const _RecommendationCard({
    required this.onStartPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        20,
        22,
        18,
        18,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF0CD),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.star_border_rounded,
                  color: Color(0xFFFFBE45),
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '네트워크 계층 개념 복습을 추천해요!',
                        style: TextStyle(
                          color: AiPage._textColor,
                          fontSize: 17,
                          height: 1.35,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        '지난 오답에서 관련 실수가 많았어요.',
                        style: TextStyle(
                          color: AiPage._subTextColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              const Expanded(
                child: Text(
                  '예상 학습 시간 45분',
                  style: TextStyle(
                    color: AiPage._subTextColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: onStartPressed,
                  style: FilledButton.styleFrom(
                    backgroundColor: AiPage._pinkColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text(
                    '바로 시작',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AiMessageCard extends StatelessWidget {
  const _AiMessageCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(
        minHeight: 104,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 26,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFEDE6FF),
        borderRadius: BorderRadius.circular(24),
      ),
      alignment: Alignment.center,
      child: const Text(
        '꾸준한 학습이 합격의 지름길이에요!',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AiPage._textColor,
          fontSize: 17,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}