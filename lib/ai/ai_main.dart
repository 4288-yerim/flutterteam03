import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../notification/screens/notification.dart';
import '../widgets/app_main_background.dart';
import '../widgets/app_top_bar.dart';
import 'question_generation.dart';
import 'study_plan.dart';
import 'subscription.dart';
import 'certificate_roadmap.dart';
import 'material_summary.dart';
import 'material_summary_result.dart';

class AiPage extends StatefulWidget {
  const AiPage({super.key});

  @override
  State<AiPage> createState() => _AiPageState();
}

class _WeakestTopic {
  final String certificateName;
  final String? subject;
  final int wrongCount;

  const _WeakestTopic({
    required this.certificateName,
    this.subject,
    required this.wrongCount,
  });

  String get label =>
      (subject != null && subject!.isNotEmpty) ? '$certificateName · $subject' : certificateName;

  int get estimatedMinutes {
    final raw = wrongCount * 7;
    final rounded = ((raw + 4) ~/ 5) * 5;
    return rounded < 15 ? 15 : rounded;
  }
}

class _WeakestTopicAgg {
  final String certificateName;
  final String? subject;
  int count;

  _WeakestTopicAgg({required this.certificateName, this.subject, this.count = 1});
}

/// 이번주(월요일부터) 문제풀이 통계.
class _WeeklyStats {
  final int solvedCount;
  final int correctCount;

  const _WeeklyStats({required this.solvedCount, required this.correctCount});

  int get accuracyPercent {
    if (solvedCount == 0) return 0;
    return ((correctCount / solvedCount) * 100).round();
  }
}

/// 가장 최근에 저장한 자료 요약.
/// 카드 미리보기(preview)용 축약 텍스트뿐 아니라, 탭했을 때 결과 화면을
/// 바로 그려줄 수 있도록 전체 요약과 길이 정보까지 함께 들고 있는다.
class _RecentSummary {
  final String certificateName;
  final String preview;
  final String fullSummary;
  final int originalLength;
  final int summaryLength;
  final int fileCount;

  const _RecentSummary({
    required this.certificateName,
    required this.preview,
    required this.fullSummary,
    required this.originalLength,
    required this.summaryLength,
    required this.fileCount,
  });
}

class _AiPageState extends State<AiPage> {
  static const Color _textColor = Color(0xFF302C2E);
  static const Color _subTextColor = Color(0xFF8E8589);
  static const Color _pinkColor = Color(0xFFF4869D);

  String _nickname = '사용자';
  bool _isNicknameLoading = true;

  bool _isCheckingSubscription = false;

  bool _isInsightLoading = true;
  _WeakestTopic? _weakestTopic;
  _WeeklyStats? _weeklyStats;
  _RecentSummary? _recentSummary;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _nicknameSub;

  @override
  void initState() {
    super.initState();

    FirebaseAuth.instance.authStateChanges().listen((user) {
      _listenNickname(user);
      _loadInsights(user);
    });
  }

  @override
  void dispose() {
    _nicknameSub?.cancel();
    super.dispose();
  }

  void _listenNickname(User? user) {
    _nicknameSub?.cancel();

    if (user == null) {
      setState(() {
        _nickname = '사용자';
        _isNicknameLoading = false;
      });
      return;
    }

    setState(() => _isNicknameLoading = true);

    _nicknameSub = FirebaseFirestore.instance
        .collection('users')
        .where('uid', isEqualTo: user.uid)
        .limit(1)
        .snapshots()
        .listen((querySnapshot) {
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
        _nickname = (nickname is String && nickname.trim().isNotEmpty)
            ? nickname.trim()
            : '사용자';
        _isNicknameLoading = false;
      });
    }, onError: (error) {
      debugPrint('닉네임 불러오기 실패: $error');
      if (!mounted) return;
      setState(() {
        _nickname = '사용자';
        _isNicknameLoading = false;
      });
    });
  }

  Future<void> _loadInsights(User? user) async {
    if (!mounted) return;

    if (user == null) {
      setState(() {
        _weakestTopic = null;
        _weeklyStats = null;
        _recentSummary = null;
        _isInsightLoading = false;
      });
      return;
    }

    setState(() => _isInsightLoading = true);

    try {
      final userQuerySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (userQuerySnapshot.docs.isEmpty) {
        setState(() {
          _weakestTopic = null;
          _weeklyStats = null;
          _recentSummary = null;
          _isInsightLoading = false;
        });
        return;
      }

      final userDocRef = userQuerySnapshot.docs.first.reference;

      final results = await Future.wait([
        _fetchWeakestTopic(userDocRef),
        _fetchWeeklyStats(userDocRef),
        _fetchRecentSummary(userDocRef),
      ]).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      setState(() {
        _weakestTopic = results[0] as _WeakestTopic?;
        _weeklyStats = results[1] as _WeeklyStats?;
        _recentSummary = results[2] as _RecentSummary?;
        _isInsightLoading = false;
      });
    } catch (error) {
      debugPrint('AI 인사이트 불러오기 실패: $error');
      if (!mounted) return;
      setState(() {
        _weakestTopic = null;
        _weeklyStats = null;
        _recentSummary = null;
        _isInsightLoading = false;
      });
    }
  }

  Future<_WeakestTopic?> _fetchWeakestTopic(
      DocumentReference<Map<String, dynamic>> userDocRef,
      ) async {
    final snap = await userDocRef
        .collection('wrong_answers')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .get();

    if (snap.docs.isEmpty) return null;

    final aggs = <String, _WeakestTopicAgg>{};

    for (final doc in snap.docs) {
      final data = doc.data();
      final certName = (data['certificationName'] as String?)?.trim();
      final pdfName = (data['pdfFileName'] as String?)?.trim();
      final subject = (data['subject'] as String?)?.trim();

      final baseLabel = (certName?.isNotEmpty ?? false)
          ? certName!
          : (pdfName?.isNotEmpty ?? false)
          ? pdfName!
          : null;
      if (baseLabel == null) continue;

      final normalizedSubject = (subject?.isNotEmpty ?? false) ? subject : null;
      final key = normalizedSubject != null ? '$baseLabel·$normalizedSubject' : baseLabel;

      final existing = aggs[key];
      if (existing == null) {
        aggs[key] = _WeakestTopicAgg(certificateName: baseLabel, subject: normalizedSubject);
      } else {
        existing.count++;
      }
    }

    if (aggs.isEmpty) return null;

    final top = aggs.values.reduce((a, b) => a.count >= b.count ? a : b);
    return _WeakestTopic(
      certificateName: top.certificateName,
      subject: top.subject,
      wrongCount: top.count,
    );
  }

  /// 이번주 월요일 0시 이후에 생성된 quiz_sessions를 집계한다.
  Future<_WeeklyStats?> _fetchWeeklyStats(
      DocumentReference<Map<String, dynamic>> userDocRef,
      ) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(Duration(days: today.weekday - 1));

    final snap = await userDocRef
        .collection('quiz_sessions')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart))
        .get();

    if (snap.docs.isEmpty) {
      return const _WeeklyStats(solvedCount: 0, correctCount: 0);
    }

    var solved = 0;
    var correct = 0;

    for (final doc in snap.docs) {
      final data = doc.data();
      solved += (data['totalCount'] as num?)?.toInt() ?? 0;
      correct += (data['correctCount'] as num?)?.toInt() ?? 0;
    }

    return _WeeklyStats(solvedCount: solved, correctCount: correct);
  }

  Future<_RecentSummary?> _fetchRecentSummary(
      DocumentReference<Map<String, dynamic>> userDocRef,
      ) async {
    final snap = await userDocRef
        .collection('saved_summaries')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;

    final data = snap.docs.first.data();
    final certName = (data['certificateName'] as String?)?.trim();
    final summary = (data['summary'] as String?)?.trim();

    if (certName == null || certName.isEmpty) return null;

    final preview = (summary == null || summary.isEmpty)
        ? ''
        : (summary.length > 40 ? '${summary.substring(0, 40)}…' : summary);

    // 카드를 탭했을 때 결과 화면(MaterialSummaryResultPage)을 API 재호출 없이
    // 바로 그릴 수 있도록, 저장 당시 함께 기록해둔 길이 정보도 같이 읽어온다.
    final originalLength = (data['originalLength'] as num?)?.toInt() ?? 0;
    final summaryLength =
        (data['summaryLength'] as num?)?.toInt() ?? (summary?.length ?? 0);
    final fileCount = (data['fileCount'] as num?)?.toInt() ?? 0;

    return _RecentSummary(
      certificateName: certName,
      preview: preview,
      fullSummary: summary ?? '',
      originalLength: originalLength,
      summaryLength: summaryLength,
      fileCount: fileCount,
    );
  }

  void _onNotificationPressed() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationPage()),
    );
  }

  Future<void> _onStudyPlanPressed() async {
    if (_isCheckingSubscription) return;

    setState(() => _isCheckingSubscription = true);

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SubscriptionPage()),
        );
        return;
      }

      final userQuerySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (userQuerySnapshot.docs.isEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SubscriptionPage()),
        );
        return;
      }

      final userDocument = userQuerySnapshot.docs.first;

      final subscriptionDocument = await userDocument.reference
          .collection('subscription')
          .doc('current')
          .get()
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (!subscriptionDocument.exists) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SubscriptionPage()),
        );
        return;
      }

      final data = subscriptionDocument.data();
      final status = data?['status']?.toString().trim().toUpperCase();

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => status == 'ACTIVE'
              ? const AiStudyPlanPage()
              : const SubscriptionPage(),
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('구독 상태 확인 실패: $error\n$stackTrace');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('구독 정보를 확인하지 못했습니다. 다시 시도해주세요.')),
      );
    } finally {
      if (mounted) setState(() => _isCheckingSubscription = false);
    }
  }

  void _onRoadmapPressed() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CertificateRoadmapPage()),
    );
  }

  void _onQuestionPressed(BuildContext context, {_WeakestTopic? topic}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuestionGenerationPage(
          initialCertificate: topic?.certificateName,
          initialSubject: topic?.subject,
        ),
      ),
    );
  }

  void _onSummaryPressed() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MaterialSummaryPage()),
    );
  }

  /// "최근 요약 자료" 카드를 눌렀을 때의 동작.
  /// 저장된 요약이 있으면 MaterialSummaryResultPage에 initialResult로
  /// 그대로 넘겨서 API 재호출 없이 바로 결과 화면을 보여준다.
  /// 저장된 요약이 없으면(신규 사용자 등) 기존처럼 새로 요약하는 화면으로 보낸다.
  void _onRecentSummaryPressed() {
    final recent = _recentSummary;

    if (recent == null) {
      _onSummaryPressed();
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MaterialSummaryResultPage(
          selectedCertificate: recent.certificateName,
          isSplitSummary: false,
          uploadedFileNames: const [],
          uploadedFileUrls: const [],
          initialResult: {
            'summary': recent.fullSummary,
            'certificate_match': true,
            'original_length': recent.originalLength,
            'summary_length': recent.summaryLength,
            'file_count': recent.fileCount,
          },
        ),
      ),
    );
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
        ],
      ),
      body: AppMainBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AiWelcomeCard(
                  nickname: _nickname,
                  isLoading: _isNicknameLoading,
                ),
                const SizedBox(height: 26),
                const _SectionTitle(title: '빠른 실행'),
                const SizedBox(height: 16),
                _QuickMenuSection(
                  onStudyPlanPressed: _onStudyPlanPressed,
                  onRoadmapPressed: _onRoadmapPressed,
                  onQuestionPressed: () => _onQuestionPressed(context),
                  onSummaryPressed: _onSummaryPressed,
                ),
                const SizedBox(height: 30),
                const _SectionTitle(title: '오늘의 맞춤 제안'),
                const SizedBox(height: 16),
                _RecommendationCard(
                  isLoading: _isInsightLoading,
                  topic: _weakestTopic,
                  onStartPressed: () => _onQuestionPressed(context, topic: _weakestTopic),
                ),
                const SizedBox(height: 30),
                const _SectionTitle(title: '이번주 학습 통계'),
                const SizedBox(height: 16),
                _WeeklyStatsCard(
                  isLoading: _isInsightLoading,
                  stats: _weeklyStats,
                ),
                const SizedBox(height: 30),
                const _SectionTitle(title: '최근 요약 자료'),
                const SizedBox(height: 16),
                _RecentSummaryCard(
                  isLoading: _isInsightLoading,
                  summary: _recentSummary,
                  onPressed: _onRecentSummaryPressed,
                ),
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

  const _AiWelcomeCard({required this.nickname, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 210,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFE4ED), Color(0xFFF6D7FF)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            left: 22,
            top: 26,
            right: 110,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isLoading ? '안녕하세요!' : '안녕하세요, $nickname님!',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _AiPageState._textColor,
                    fontSize: 20,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '이해하기 어려운 학습을\n도와주는 AI 도우미\n구름iT이에요!',
                  style: TextStyle(
                    color: _AiPageState._subTextColor,
                    fontSize: 14,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 15,
            bottom: 0,
            child: Image.asset(
              'assets/images/cloud_it.png',
              width: 140,
              height: 140,
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

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: _AiPageState._pinkColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: _AiPageState._textColor,
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
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
      color: Colors.white.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFF3EDEE), width: 1.2),
          ),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconBackgroundColor,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(height: 11),
              Text(
                label,
                maxLines: 1,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _AiPageState._textColor,
                  fontSize: 11,
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
  final bool isLoading;
  final _WeakestTopic? topic;
  final VoidCallback onStartPressed;

  const _RecommendationCard({
    required this.isLoading,
    required this.topic,
    required this.onStartPressed,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Container(
        width: double.infinity,
        height: 120,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFF3EDEE), width: 1.2),
        ),
        child: const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: _AiPageState._pinkColor,
            ),
          ),
        ),
      );
    }

    final hasTopic = topic != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 20, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF3EDEE), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF0CD),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  hasTopic ? Icons.star_rounded : Icons.star_border_rounded,
                  color: const Color(0xFFFFBE45),
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasTopic
                            ? '${topic!.label} 복습을 추천해요!'
                            : '아직 오답 기록이 없어요',
                        style: const TextStyle(
                          color: _AiPageState._textColor,
                          fontSize: 15,
                          height: 1.35,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        hasTopic
                            ? '최근 오답 ${topic!.wrongCount}개가 여기서 나왔어요.'
                            : '문제를 풀면 자주 틀리는 부분을 찾아드릴게요.',
                        style: const TextStyle(
                          color: _AiPageState._subTextColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: Text(
                  hasTopic ? '예상 학습 시간 ${topic!.estimatedMinutes}분' : ' ',
                  style: const TextStyle(
                    color: _AiPageState._subTextColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              SizedBox(
                height: 44,
                child: FilledButton(
                  onPressed: onStartPressed,
                  style: FilledButton.styleFrom(
                    backgroundColor: _AiPageState._pinkColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                  child: Text(
                    hasTopic ? '바로 시작' : '문제 풀러 가기',
                    style: const TextStyle(
                      fontSize: 14,
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

/// 이번주 문제풀이 개수 / 정답률 카드.
class _WeeklyStatsCard extends StatelessWidget {
  final bool isLoading;
  final _WeeklyStats? stats;

  const _WeeklyStatsCard({required this.isLoading, required this.stats});

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _shell(
        child: const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: Color(0xFF9D7BFF),
            ),
          ),
        ),
      );
    }

    final solved = stats?.solvedCount ?? 0;
    final accuracy = stats?.accuracyPercent ?? 0;

    if (solved == 0) {
      return _shell(
        child: const Column(
          children: [
            Icon(Icons.bar_chart_rounded, color: Color(0xFF9D7BFF), size: 26),
            SizedBox(height: 8),
            Text(
              '이번주엔 아직 푼 문제가 없어요.',
              style: TextStyle(
                color: _AiPageState._textColor,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    return _shell(
      child: Row(
        children: [
          Expanded(
            child: _statColumn(
              label: '푼 문제',
              value: '$solved개',
            ),
          ),
          Container(width: 1, height: 40, color: Colors.white),
          Expanded(
            child: _statColumn(
              label: '정답률',
              value: '$accuracy%',
            ),
          ),
        ],
      ),
    );
  }

  Widget _statColumn({required String label, required String value}) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF7C5CD8),
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: _AiPageState._subTextColor,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _shell({required Widget child}) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 96),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFEDE6FF),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white, width: 2),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}

/// 최근에 저장한 자료 요약 바로가기 카드.
class _RecentSummaryCard extends StatelessWidget {
  final bool isLoading;
  final _RecentSummary? summary;
  final VoidCallback onPressed;

  const _RecentSummaryCard({
    required this.isLoading,
    required this.summary,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Container(
        width: double.infinity,
        height: 96,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFF3EDEE), width: 1.2),
        ),
        child: const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: Color(0xFFFFBD4A),
            ),
          ),
        ),
      );
    }

    return Material(
      color: Colors.white.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFF3EDEE), width: 1.2),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF1CE),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.article_outlined,
                  color: Color(0xFFFFBD4A),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary == null ? '아직 요약한 자료가 없어요' : summary!.certificateName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _AiPageState._textColor,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      summary == null
                          ? '자료를 요약하면 여기서 바로 볼 수 있어요.'
                          : summary!.preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _AiPageState._subTextColor,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: _AiPageState._subTextColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}