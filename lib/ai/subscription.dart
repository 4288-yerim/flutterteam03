import 'package:flutter/material.dart';

import '../widgets/app_main_background.dart';
import '../widgets/app_top_bar.dart';

class SubscriptionPage extends StatelessWidget {
  const SubscriptionPage({super.key});

  static const Color _textColor = Color(0xFF302C2E);
  static const Color _subTextColor = Color(0xFF817B7D);
  static const Color _pinkColor = Color(0xFFF4869D);

  void _onSubscribePressed(BuildContext context) {
    // 실제 결제 기능은 추후 연결
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('결제 기능은 추후 연결될 예정입니다.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: const AppTopBar(
        title: '구름iT 구독',
        centerTitle: false,
      ),
      body: AppMainBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              24,
              24,
              24,
              40,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SubscriptionHeader(),

                const SizedBox(height: 28),

                const Text(
                  '구독 혜택',
                  style: TextStyle(
                    color: _textColor,
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),

                const SizedBox(height: 16),

                const _BenefitCard(
                  icon: Icons.calendar_month_outlined,
                  iconColor: Color(0xFF9D7BFF),
                  iconBackgroundColor: Color(0xFFEDE6FF),
                  title: '맞춤형 AI 학습 플랜',
                  description: '자격증 시험 일정에 맞춰 구름iT이 학습 플랜을 생성해요.',
                ),

                const SizedBox(height: 12),

                const _BenefitCard(
                  icon: Icons.insights_rounded,
                  iconColor: Color(0xFFF4869D),
                  iconBackgroundColor: Color(0xFFFFE4EA),
                  title: '합격 가능성 예측',
                  description: '사용자의 학습량을 분석해 현재 합격 가능성을 예측해요.',
                ),

                const SizedBox(height: 12),

                const _BenefitCard(
                  icon: Icons.auto_fix_high_rounded,
                  iconColor: Color(0xFF69BFB4),
                  iconBackgroundColor: Color(0xFFE2F5F1),
                  title: '학습 플랜 자동 조정',
                  description: '학습량이 부족하면 남은 일정에 맞게 학습 플랜을 조정해요.',
                ),

                const SizedBox(height: 28),

                const _PriceCard(),

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    onPressed: () {
                      _onSubscribePressed(context);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: _pinkColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text(
                      '첫 달 1,000원으로 시작하기',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                const Center(
                  child: Text(
                    '첫 달 이후에는 매월 2,900원이 결제됩니다.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _subTextColor,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                const Center(
                  child: Text(
                    '합격 가능성 예측 결과는 학습 참고용이며,\n실제 시험 결과를 보장하지 않습니다.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFA0999C),
                      fontSize: 12,
                      height: 1.5,
                    ),
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

class _SubscriptionHeader extends StatelessWidget {
  const _SubscriptionHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        22,
        28,
        22,
        26,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFE4ED),
            Color(0xFFF1E3FF),
          ],
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        children: [
          Image.asset(
            'assets/images/cloud_it.png',
            width: 120,
            height: 120,
            fit: BoxFit.contain,
          ),

          const SizedBox(height: 12),

          const Text(
            '구름iT과 함께\n합격까지 계획적으로 공부해요',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: SubscriptionPage._textColor,
              fontSize: 23,
              height: 1.35,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.7,
            ),
          ),

          const SizedBox(height: 10),

          const Text(
            '시험 일정과 학습 기록을 분석해\n나에게 맞는 학습 계획을 제공해요.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: SubscriptionPage._subTextColor,
              fontSize: 15,
              height: 1.55,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _BenefitCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBackgroundColor;
  final String title;
  final String description;

  const _BenefitCard({
    required this.icon,
    required this.iconColor,
    required this.iconBackgroundColor,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: iconBackgroundColor,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              color: iconColor,
              size: 27,
            ),
          ),

          const SizedBox(width: 15),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: SubscriptionPage._textColor,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 7),

                Text(
                  description,
                  style: const TextStyle(
                    color: SubscriptionPage._subTextColor,
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

class _PriceCard extends StatelessWidget {
  const _PriceCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        22,
        22,
        22,
        20,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFF6B7C7),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Text(
                '월간 구독',
                style: TextStyle(
                  color: SubscriptionPage._textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),

              Spacer(),

              DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0xFFFFE4EA),
                  borderRadius: BorderRadius.all(
                    Radius.circular(30),
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 6,
                  ),
                  child: Text(
                    '첫 달 할인',
                    style: TextStyle(
                      color: SubscriptionPage._pinkColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 22),

          const Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '첫 달',
                style: TextStyle(
                  color: SubscriptionPage._subTextColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),

              SizedBox(width: 10),

              Text(
                '1,000원',
                style: TextStyle(
                  color: SubscriptionPage._pinkColor,
                  fontSize: 32,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          const Divider(
            color: Color(0xFFF0E6E9),
            height: 1,
          ),

          const SizedBox(height: 14),

          const Row(
            children: [
              Text(
                '다음 달부터',
                style: TextStyle(
                  color: SubscriptionPage._subTextColor,
                  fontSize: 14,
                ),
              ),

              Spacer(),

              Text(
                '월 2,900원',
                style: TextStyle(
                  color: SubscriptionPage._textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}