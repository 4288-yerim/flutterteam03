import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../notification/screens/notification.dart';
import '../widgets/app_main_background.dart';
import '../widgets/app_top_bar.dart';
import 'question_generation.dart';
import 'study_plan.dart';
import 'subscription.dart';
import 'certificate_roadmap.dart';
import 'material_summary.dart';

class AiPage extends StatefulWidget {
  const AiPage({super.key});

  @override
  State<AiPage> createState() => _AiPageState();
}

class _AiPageState extends State<AiPage> {
  static const Color _textColor = Color(0xFF302C2E);
  static const Color _subTextColor = Color(0xFF8E8589);
  static const Color _pinkColor = Color(0xFFF4869D);

  String _nickname = '사용자';
  bool _isNicknameLoading = true;

  bool _isCheckingSubscription = false;

  @override
  void initState() {
    super.initState();
    _loadNickname();
  }

  Future<void> _loadNickname() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        if (!mounted) return;

        setState(() {
          _nickname = '사용자';
          _isNicknameLoading = false;
        });

        return;
      }

      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (!mounted) return;

      if (querySnapshot.docs.isEmpty) {
        setState(() {
          _nickname = '사용자';
          _isNicknameLoading = false;
        });

        return;
      }

      final data = querySnapshot.docs.first.data();
      final nickname = data['nickname'];

      setState(() {
        if (nickname is String && nickname.trim().isNotEmpty) {
          _nickname = nickname.trim();
        } else {
          _nickname = '사용자';
        }

        _isNicknameLoading = false;
      });
    } catch (error) {
      debugPrint('닉네임 불러오기 실패: $error');

      if (!mounted) return;

      setState(() {
        _nickname = '사용자';
        _isNicknameLoading = false;
      });
    }
  }

  void _onNotificationPressed() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const NotificationPage(),
      ),
    );
  }

  Future<void> _onStudyPlanPressed() async {
    if (_isCheckingSubscription) return;

    setState(() {
      _isCheckingSubscription = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        if (!mounted) return;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const SubscriptionPage(),
          ),
        );

        return;
      }

      // users 컬렉션에서 현재 로그인 사용자의 실제 문서를 찾음
      final userQuerySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (!mounted) return;

      // 사용자 문서가 없는 경우
      if (userQuerySnapshot.docs.isEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const SubscriptionPage(),
          ),
        );

        return;
      }

      final userDocument = userQuerySnapshot.docs.first;

      // 실제 사용자 문서 아래의 subscription/current 조회
      final subscriptionDocument = await userDocument.reference
          .collection('subscription')
          .doc('current')
          .get();

      if (!mounted) return;

      // 구독 문서가 없는 경우
      if (!subscriptionDocument.exists) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const SubscriptionPage(),
          ),
        );

        return;
      }

      final data = subscriptionDocument.data();

      final status = data?['status']
          ?.toString()
          .trim()
          .toUpperCase();

      if (status == 'ACTIVE') {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const AiStudyPlanPage(),
          ),
        );

        return;
      }

      // ACTIVE가 아닌 모든 상태는 구독 페이지로 이동
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const SubscriptionPage(),
        ),
      );
    } catch (error, stackTrace) {

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('구독 정보를 확인하지 못했습니다. 다시 시도해주세요.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingSubscription = false;
        });
      }
    }
  }

  void _onRoadmapPressed() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CertificateRoadmapPage(),
      ),
    );
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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const MaterialSummaryPage(),
      ),
    );
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
          // const SizedBox(width: 12),
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
                _AiWelcomeCard(
                  nickname: _nickname,
                  isLoading: _isNicknameLoading,
                ),

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
  final String nickname;
  final bool isLoading;

  const _AiWelcomeCard({
    required this.nickname,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 225,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFE4ED),
            Color(0xFFF6D7FF),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            left: 22,
            top: 28,
            right: 110,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isLoading
                      ? '안녕하세요!'
                      : '안녕하세요, $nickname님!',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _AiPageState._textColor,
                    fontSize: 23,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  '이해하기 어려운 학습을\n'
                      '도와주는 AI 도우미\n'
                      '구름iT이에요!',
                  style: TextStyle(
                    color: _AiPageState._subTextColor,
                    fontSize: 16,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: -18,
            bottom: -5,
            child: Image.asset(
              'assets/images/cloud_it.png',
              width: 155,
              height: 155,
              fit: BoxFit.contain,
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
        color: _AiPageState._textColor,
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
                  color: _AiPageState._textColor,
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
                          color: _AiPageState._textColor,
                          fontSize: 17,
                          height: 1.35,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        '지난 오답에서 관련 실수가 많았어요.',
                        style: TextStyle(
                          color: _AiPageState._subTextColor,
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
                    color: _AiPageState._subTextColor,
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
                    backgroundColor: _AiPageState._pinkColor,
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
          color: _AiPageState._textColor,
          fontSize: 17,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}