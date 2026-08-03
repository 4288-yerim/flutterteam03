import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../theme.dart';
import '../notification/screens/notification.dart';
import '../notification/widgets/notification_bell_button.dart';
import '../widgets/app_main_background.dart';
import '../widgets/app_top_bar.dart';
import 'question_generation.dart';
import 'study_plan.dart';
import 'subscription.dart';
import 'certificate_roadmap.dart';
import 'material_summary.dart';
import 'material_summary_result.dart';
import 'pass_risk_detail.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'subscription.dart';

class AiPage extends StatefulWidget {
  AiPage({super.key});

  @override
  State<AiPage> createState() => _AiPageState();
}

class _WeakestTopic {
  final String certificateName;
  final String? subject;
  final int wrongCount;

  _WeakestTopic({
    required this.certificateName,
    this.subject,
    required this.wrongCount,
  });

  String get label => (subject != null && subject!.isNotEmpty)
      ? '$certificateName · $subject'
      : certificateName;

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

  _WeakestTopicAgg({
    required this.certificateName,
    this.subject,
    this.count = 1,
  });
}

/// 이번주(월요일부터) 문제풀이 통계.
class _WeeklyStats {
  final int solvedCount;
  final int correctCount;

  _WeeklyStats({required this.solvedCount, required this.correctCount});

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

  _RecentSummary({
    required this.certificateName,
    required this.preview,
    required this.fullSummary,
    required this.originalLength,
    required this.summaryLength,
    required this.fileCount,
  });
}

class _PassRiskAnalysis {
  final String certificateName;
  final int passProbability;
  final String riskLevel; // LOW / MEDIUM / HIGH
  final double progressGap; // 경과 기간 대비 진도 격차
  final double recentCompletionRate;

  _PassRiskAnalysis({
    required this.certificateName,
    required this.passProbability,
    required this.riskLevel,
    required this.progressGap,
    required this.recentCompletionRate,
  });

  String get riskLabel {
    switch (riskLevel) {
      case 'HIGH':
        return '위험';
      case 'MEDIUM':
        return '보통';
      default:
        return '안정';
    }
  }
}

class _AiPageState extends State<AiPage> {
  String _nickname = '사용자';
  bool _isNicknameLoading = true;
  bool _isAnalyzingPassRisk = false;
  String? _latestStudyPlanCertificateName;

  bool _isCheckingSubscription = false;

  bool _isInsightLoading = true;
  _WeakestTopic? _weakestTopic;
  _WeeklyStats? _weeklyStats;
  _RecentSummary? _recentSummary;
  _PassRiskAnalysis? _passRiskAnalysis;

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
        .listen(
          (querySnapshot) {
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
          },
          onError: (error) {
            debugPrint('닉네임 불러오기 실패: $error');
            if (!mounted) return;
            setState(() {
              _nickname = '사용자';
              _isNicknameLoading = false;
            });
          },
        );
  }

  Future<void> _onAnalyzePassRiskPressed() async {
    if (_isAnalyzingPassRisk) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('로그인이 필요합니다.')),
      );
      return;
    }

    setState(() => _isAnalyzingPassRisk = true);

    try {
      // 구독 여부 확인
      final userQuerySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get()
          .timeout(Duration(seconds: 10));

      if (userQuerySnapshot.docs.isEmpty) {
        _goToSubscription();
        return;
      }

      final subscriptionDoc = await userQuerySnapshot.docs.first.reference
          .collection('subscription')
          .doc('current')
          .get()
          .timeout(Duration(seconds: 10));

      final status = subscriptionDoc.data()?['status']
          ?.toString()
          .trim()
          .toUpperCase();

      if (status != 'ACTIVE') {
        _goToSubscription();
        return;
      }

      final certName = _latestStudyPlanCertificateName
          ?? _passRiskAnalysis?.certificateName
          ?? _weakestTopic?.certificateName;

      if (certName == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('먼저 AI 학습 플랜을 저장해주세요.')),
        );
        return;
      }

      final callable = FirebaseFunctions.instance.httpsCallable('analyzePassRisk');
      await callable.call({'certificateName': certName});
      await _loadInsights(user);
    } on FirebaseFunctionsException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? '분석에 실패했어요.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('분석 중 오류가 발생했어요.')),
      );
    } finally {
      if (mounted) setState(() => _isAnalyzingPassRisk = false);
    }
  }

  void _goToSubscription() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SubscriptionPage()),
    );
  }

  Future<void> _loadInsights(User? user) async {
    if (!mounted) return;

    if (user == null) {
      setState(() {
        _weakestTopic = null;
        _weeklyStats = null;
        _recentSummary = null;
        _passRiskAnalysis = null;
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
          .timeout(Duration(seconds: 10));

      if (!mounted) return;

      if (userQuerySnapshot.docs.isEmpty) {
        setState(() {
          _weakestTopic = null;
          _weeklyStats = null;
          _recentSummary = null;
          _passRiskAnalysis = null;
          _isInsightLoading = false;
        });
        return;
      }
      final userDocRef = userQuerySnapshot.docs.first.reference;

      final results = await Future.wait([
        _fetchWeakestTopic(userDocRef),
        _fetchWeeklyStats(userDocRef),
        _fetchRecentSummary(userDocRef),
        _fetchPassRiskAnalysis(userDocRef),
        _fetchLatestStudyPlanCertificate(userDocRef),
      ]).timeout(Duration(seconds: 10));

      if (!mounted) return;

      setState(() {
        _weakestTopic = results[0] as _WeakestTopic?;
        _weeklyStats = results[1] as _WeeklyStats?;
        _recentSummary = results[2] as _RecentSummary?;
        _passRiskAnalysis = results[3] as _PassRiskAnalysis?;
        _latestStudyPlanCertificateName = results[4] as String?;
        _isInsightLoading = false;
      });
    } catch (error) {
      debugPrint('AI 인사이트 불러오기 실패: $error');
      if (!mounted) return;
      setState(() {
        _weakestTopic = null;
        _weeklyStats = null;
        _recentSummary = null;
        _passRiskAnalysis = null;
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
      final key = normalizedSubject != null
          ? '$baseLabel·$normalizedSubject'
          : baseLabel;

      final existing = aggs[key];
      if (existing == null) {
        aggs[key] = _WeakestTopicAgg(
          certificateName: baseLabel,
          subject: normalizedSubject,
        );
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
        .where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart),
        )
        .get();

    if (snap.docs.isEmpty) {
      return _WeeklyStats(solvedCount: 0, correctCount: 0);
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

  Future<_PassRiskAnalysis?> _fetchPassRiskAnalysis(
      DocumentReference<Map<String, dynamic>> userDocRef,
      ) async {
    final doc = await userDocRef.collection('analysis').doc('passRisk').get();

    if (!doc.exists) return null;

    final data = doc.data();
    if (data == null) return null;

    final certificateName = (data['certificateName'] as String?)?.trim();
    if (certificateName == null || certificateName.isEmpty) return null;

    final factors = data['factors'] as Map<String, dynamic>? ?? {};

    return _PassRiskAnalysis(
      certificateName: certificateName,
      passProbability: (data['passProbability'] as num?)?.toInt() ?? 0,
      riskLevel: (data['riskLevel'] as String?)?.trim() ?? 'UNKNOWN',
      progressGap: (factors['progressGap'] as num?)?.toDouble() ?? 0,
      recentCompletionRate:
      (factors['recentCompletionRate'] as num?)?.toDouble() ?? 0,
    );
  }

  Future<String?> _fetchLatestStudyPlanCertificate(
      DocumentReference<Map<String, dynamic>> userDocRef,
      ) async {
    final snap = await userDocRef
        .collection('studyPlans')
        .orderBy('createdAt', descending: true)
        .limit(10)
        .get();

    for (final doc in snap.docs) {
      final data = doc.data();
      if (data['steps'] is List) {
        final name = (data['certificateName'] as String?)?.trim();
        if (name != null && name.isNotEmpty) return name;
      }
    }
    return null;
  }

  void _onNotificationPressed() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NotificationPage()),
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
          MaterialPageRoute(builder: (_) => SubscriptionPage()),
        );
        return;
      }

      final userQuerySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get()
          .timeout(Duration(seconds: 10));

      if (!mounted) return;

      if (userQuerySnapshot.docs.isEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => SubscriptionPage()),
        );
        return;
      }

      final userDocument = userQuerySnapshot.docs.first;

      final subscriptionDocument = await userDocument.reference
          .collection('subscription')
          .doc('current')
          .get()
          .timeout(Duration(seconds: 10));

      if (!mounted) return;

      if (!subscriptionDocument.exists) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => SubscriptionPage()),
        );
        return;
      }

      final data = subscriptionDocument.data();
      final status = data?['status']?.toString().trim().toUpperCase();

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              status == 'ACTIVE' ? AiStudyPlanPage() : SubscriptionPage(),
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('구독 상태 확인 실패: $error\n$stackTrace');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('구독 정보를 확인하지 못했습니다. 다시 시도해주세요.')));
    } finally {
      if (mounted) setState(() => _isCheckingSubscription = false);
    }
  }

  void _onRoadmapPressed() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CertificateRoadmapPage()),
    );
  }

  void _onPassRiskPressed() {
    if (_passRiskAnalysis == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PassRiskDetailScreen(
          certificateName: _passRiskAnalysis!.certificateName,
        ),
      ),
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
      MaterialPageRoute(builder: (_) => MaterialSummaryPage()),
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
          uploadedFileNames: [],
          uploadedFileUrls: [],
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
        actions: [NotificationBellButton(onPressed: _onNotificationPressed)],
      ),
      body: AppMainBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(24, 22, 24, 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AiWelcomeCard(
                  nickname: _nickname,
                  isLoading: _isNicknameLoading,
                ),
                SizedBox(height: 26),
                _SectionTitle(title: '빠른 실행'),
                SizedBox(height: 16),
                _QuickMenuSection(
                  onStudyPlanPressed: _onStudyPlanPressed,
                  onRoadmapPressed: _onRoadmapPressed,
                  onQuestionPressed: () => _onQuestionPressed(context),
                  onSummaryPressed: _onSummaryPressed,
                ),
                SizedBox(height: 30),
                _SectionTitle(title: '합격 예측 분석'),
                SizedBox(height: 16),
                _PassRiskCard(
                  isLoading: _isInsightLoading,
                  analysis: _passRiskAnalysis,
                  onPressed: _onPassRiskPressed,
                  isAnalyzing: _isAnalyzingPassRisk,
                  onAnalyzePressed: _onAnalyzePassRiskPressed,
                ),
                SizedBox(height: 30),
                _SectionTitle(title: '오늘의 맞춤 제안'),
                SizedBox(height: 16),
                _RecommendationCard(
                  isLoading: _isInsightLoading,
                  topic: _weakestTopic,
                  onStartPressed: () =>
                      _onQuestionPressed(context, topic: _weakestTopic),
                ),
                SizedBox(height: 30),
                _SectionTitle(title: '이번주 학습 통계'),
                SizedBox(height: 16),
                _WeeklyStatsCard(
                  isLoading: _isInsightLoading,
                  stats: _weeklyStats,
                ),
                SizedBox(height: 30),
                _SectionTitle(title: '최근 요약 자료'),
                SizedBox(height: 16),
                _RecentSummaryCard(
                  isLoading: _isInsightLoading,
                  summary: _recentSummary,
                  onPressed: _onRecentSummaryPressed,
                ),
                SizedBox(height: 30),
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

  _AiWelcomeCard({required this.nickname, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 210,
      decoration: BoxDecoration(
        gradient: context.colors.themedHeroGradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.colors.surface, width: 2),
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
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 20,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  '이해하기 어려운 학습을\n도와주는 AI 도우미\n구름iT이에요!',
                  style: TextStyle(
                    color: context.colors.textPrimary.withValues(alpha: 0.72),
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

  _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: context.colors.pinkStart,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: context.colors.textPrimary,
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

  _QuickMenuSection({
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
            iconColor: Color(0xFF9D7BFF),
            iconBackgroundColor: context.colors.lavender,
            onPressed: onStudyPlanPressed,
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: _QuickMenuItem(
            icon: Icons.route_rounded,
            label: '자격증 로드맵',
            iconColor: Color(0xFF7DCFC5),
            iconBackgroundColor: context.colors.mint,
            onPressed: onRoadmapPressed,
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: _QuickMenuItem(
            icon: Icons.radio_button_checked_rounded,
            label: '문제 생성',
            iconColor: context.colors.pinkDeep,
            iconBackgroundColor: context.colors.pinkSoft,
            onPressed: onQuestionPressed,
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: _QuickMenuItem(
            icon: Icons.article_outlined,
            label: '자료 요약',
            iconColor: context.colors.warning,
            iconBackgroundColor: context.colors.warningSoft,
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

  _QuickMenuItem({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.iconBackgroundColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.surfaceTransparent.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 16, horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.colors.border, width: 1.2),
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
              SizedBox(height: 11),
              Text(
                label,
                maxLines: 1,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.colors.textPrimary,
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

class _PassRiskCard extends StatelessWidget {
  final bool isLoading;
  final _PassRiskAnalysis? analysis;
  final VoidCallback onPressed;
  final bool isAnalyzing;
  final VoidCallback onAnalyzePressed;

  _PassRiskCard({
    required this.isLoading,
    required this.analysis,
    required this.onPressed,
    required this.isAnalyzing,
    required this.onAnalyzePressed,
  });

  Widget _analyzeButton(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: isAnalyzing ? null : onAnalyzePressed,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: isAnalyzing
                ? null
                : LinearGradient(
              colors: [context.colors.pinkStart, context.colors.pinkDeep],
            ),
            color: isAnalyzing ? context.colors.pinkSoft : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              isAnalyzing
                  ? SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: context.colors.pinkStart,
                ),
              )
                  : Icon(
                Icons.auto_awesome_rounded,
                size: 16,
                color: context.colors.onPrimary,
              ),
              SizedBox(width: 6),
              Text(
                isAnalyzing
                    ? '분석 중...'
                    : (analysis == null ? 'AI 분석하기' : '다시 분석하기'),
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: isAnalyzing
                      ? context.colors.pinkStart
                      : context.colors.onPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Container(
        width: double.infinity,
        height: 100,
        decoration: BoxDecoration(
          color: context.colors.surfaceTransparent.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: context.colors.border, width: 1.2),
        ),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: context.colors.pinkStart,
            ),
          ),
        ),
      );
    }

    if (analysis == null) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(18, 18, 18, 16),
        decoration: BoxDecoration(
          color: context.colors.surfaceTransparent.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: context.colors.border, width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.insights_outlined, color: context.colors.textMuted, size: 26),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '학습 플랜을 등록하면 합격 가능성을 분석해드려요.',
                    style: TextStyle(
                      color: context.colors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 14),
            _analyzeButton(context),
          ],
        ),
      );
    }

    final riskColor = _riskColor(context, analysis!.riskLevel);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: context.colors.surfaceTransparent.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.colors.border, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(18),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: riskColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(Icons.insights_rounded, color: riskColor, size: 26),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          analysis!.certificateName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.colors.textSecondary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '예상 합격 가능성 ${analysis!.passProbability}%',
                          style: TextStyle(
                            color: context.colors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '위험도 ${analysis!.riskLabel}',
                          style: TextStyle(
                            color: riskColor,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: context.colors.textSecondary),
                ],
              ),
            ),
          ),
          SizedBox(height: 14),
          _analyzeButton(context),
        ],
      ),
    );
  }

  Color _riskColor(BuildContext context, String riskLevel) {
    switch (riskLevel) {
      case 'HIGH':
        return context.colors.incorrect;
      case 'MEDIUM':
        return context.colors.warning;
      default:
        return context.colors.mintAccent;
    }
  }
}

class _RecommendationCard extends StatelessWidget {
  final bool isLoading;
  final _WeakestTopic? topic;
  final VoidCallback onStartPressed;

  _RecommendationCard({
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
          color: context.colors.surfaceTransparent.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: context.colors.border, width: 1.2),
        ),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: context.colors.pinkStart,
            ),
          ),
        ),
      );
    }

    final hasTopic = topic != null;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(18, 20, 16, 16),
      decoration: BoxDecoration(
        color: context.colors.surfaceTransparent.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.colors.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: Offset(0, 4),
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
                decoration: BoxDecoration(
                  color: context.colors.warningSoft,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  hasTopic ? Icons.star_rounded : Icons.star_border_rounded,
                  color: context.colors.warning,
                  size: 28,
                ),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasTopic
                            ? '${topic!.label} 복습을 추천해요!'
                            : '아직 오답 기록이 없어요',
                        style: TextStyle(
                          color: context.colors.textPrimary,
                          fontSize: 15,
                          height: 1.35,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        hasTopic
                            ? '최근 오답 ${topic!.wrongCount}개가 여기서 나왔어요.'
                            : '문제를 풀면 자주 틀리는 부분을 찾아드릴게요.',
                        style: TextStyle(
                          color: context.colors.textSecondary,
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
          SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: Text(
                  hasTopic ? '예상 학습 시간 ${topic!.estimatedMinutes}분' : ' ',
                  style: TextStyle(
                    color: context.colors.textSecondary,
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
                    backgroundColor: context.colors.pinkStart,
                    foregroundColor: context.colors.onPrimary,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                  child: Text(
                    hasTopic ? '바로 시작' : '문제 풀러 가기',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
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

  _WeeklyStatsCard({required this.isLoading, required this.stats});

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _shell(
        context,
        child: Center(
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
        context,
        child: Column(
          children: [
            Icon(Icons.bar_chart_rounded, color: Color(0xFF9D7BFF), size: 26),
            SizedBox(height: 8),
            Text(
              '이번주엔 아직 푼 문제가 없어요.',
              style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    return _shell(
      context,
      child: Row(
        children: [
          Expanded(
            child: _statColumn(context, label: '푼 문제', value: '$solved개'),
          ),
          Container(width: 1, height: 40, color: context.colors.divider),
          Expanded(
            child: _statColumn(context, label: '정답률', value: '$accuracy%'),
          ),
        ],
      ),
    );
  }

  Widget _statColumn(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: Color(0xFF7C5CD8),
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: context.colors.textSecondary,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _shell(BuildContext context, {required Widget child}) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: 96),
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: context.colors.lavender,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.colors.surface, width: 2),
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

  _RecentSummaryCard({
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
          color: context.colors.surfaceTransparent.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: context.colors.border, width: 1.2),
        ),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: context.colors.warning,
            ),
          ),
        ),
      );
    }

    return Material(
      color: context.colors.surfaceTransparent.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: context.colors.border, width: 1.2),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: context.colors.warningSoft,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.article_outlined,
                  color: context.colors.warning,
                  size: 24,
                ),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary == null
                          ? '아직 요약한 자료가 없어요'
                          : summary!.certificateName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.colors.textPrimary,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      summary == null
                          ? '자료를 요약하면 여기서 바로 볼 수 있어요.'
                          : summary!.preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.colors.textSecondary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: context.colors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
