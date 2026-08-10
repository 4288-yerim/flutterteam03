import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../theme.dart';
import '../widgets/app_main_background.dart';
import '../widgets/app_top_bar.dart';

String _encouragementFor(String riskLevel, int passProbability) {
  switch (riskLevel) {
    case 'HIGH':
      return '지금부터 페이스를 조금만 끌어올리면 충분히 따라잡을 수 있어요. '
          '오늘 계획한 분량 하나만 끝내보는 걸로 시작해봐요.';
    case 'MEDIUM':
      return '나쁘지 않은 흐름이에요. 지금 페이스를 유지하면서, '
          '취약한 부분만 조금 더 채워가면 안정권에 들어갈 수 있어요.';
    case 'LOW':
      return '꾸준히 잘 하고 계세요! 지금처럼만 유지하면서 '
          '마무리까지 긴장 놓지 말고 가봐요.';
    default:
      return '데이터가 쌓일수록 예측이 더 정확해져요. 꾸준히 기록해봐요.';
  }
}

/// ── 신뢰도 판정 ──────────────────────────────
/// 데이터가 너무 적으면(플랜 시작 초반) 예측이 불안정할 수 있다는 걸
/// 화면에서 먼저 말해줘서 "왜 숫자가 이상해요?" 질문을 방어한다.
class _ConfidenceInfo {
  final bool isLow;
  final String message;
  _ConfidenceInfo({required this.isLow, required this.message});
}

_ConfidenceInfo _assessConfidence(Map<String, dynamic> debug) {
  final elapsedDays = (debug['elapsedCalendarDays'] as num?)?.toInt() ?? 0;
  final totalSteps = (debug['totalSteps'] as num?)?.toInt() ?? 0;

  if (elapsedDays < 3 || totalSteps < 3) {
    return _ConfidenceInfo(
      isLow: true,
      message: '학습을 시작한 지 얼마 안 돼서 예측 신뢰도가 아직 낮아요. '
          '기록이 쌓일수록 더 정확해져요.',
    );
  }
  return _ConfidenceInfo(isLow: false, message: '');
}

/// ── 인사이트(자연어 요약) ──────────────────────────────
class _Insight {
  final String message;
  final bool isConcern;
  final double severity;
  _Insight({required this.message, required this.isConcern, required this.severity});
}

List<_Insight> _buildInsights(Map<String, double> factors) {
  final List<_Insight> insights = [];

  final consistency = factors['consistencyScore'];
  if (consistency != null) {
    if (consistency < 0.4) {
      insights.add(_Insight(
        message: '최근 학습 습관이 불규칙해요. 정해진 시간에 짧게라도 매일 이어가면 도움이 돼요.',
        isConcern: true,
        severity: 0.4 - consistency,
      ));
    } else if (consistency > 0.75) {
      insights.add(_Insight(
        message: '최근 학습을 꾸준히 이어오고 있어요.',
        isConcern: false,
        severity: consistency,
      ));
    }
  }

  final recentRate = factors['recentCompletionRate'];
  if (recentRate != null) {
    if (recentRate < 0.4) {
      insights.add(_Insight(
        message: '최근 일주일 계획 대비 완료가 많이 밀려 있어요. 오늘 하나만 끝내는 걸로 시작해봐요.',
        isConcern: true,
        severity: 0.4 - recentRate,
      ));
    } else if (recentRate > 0.75) {
      insights.add(_Insight(
        message: '이번 주 계획을 거의 다 소화하고 있어요.',
        isConcern: false,
        severity: recentRate,
      ));
    }
  }

  final progressGap = factors['progressGap'];
  if (progressGap != null) {
    if (progressGap > 0.15) {
      insights.add(_Insight(
        message: '지나간 기간에 비해 진도가 꽤 뒤처져 있어요. 남은 스텝을 조금씩 앞당겨보는 게 좋아요.',
        isConcern: true,
        severity: progressGap,
      ));
    } else if (progressGap < -0.05) {
      insights.add(_Insight(
        message: '계획보다 진도를 앞서서 나가고 있어요.',
        isConcern: false,
        severity: -progressGap,
      ));
    }
  }

  final weakRatio = factors['subjectWeakRatio'];
  if (weakRatio != null && weakRatio > 0.3) {
    insights.add(_Insight(
      message: '최근 오답이 특정 과목에 몰려 있어요. 취약 과목 위주로 짚고 넘어가면 좋아요.',
      isConcern: true,
      severity: weakRatio,
    ));
  }

  final timePressure = factors['timePressure'];
  if (timePressure != null && timePressure > 1.5) {
    insights.add(_Insight(
      message: '남은 기간 대비 처리할 분량이 많아요. 하루 학습량을 조금 늘리는 걸 고려해봐요.',
      isConcern: true,
      severity: timePressure,
    ));
  }

  final concerns = insights.where((i) => i.isConcern).toList()
    ..sort((a, b) => b.severity.compareTo(a.severity));
  final strengths = insights.where((i) => !i.isConcern).toList()
    ..sort((a, b) => b.severity.compareTo(a.severity));

  return [
    ...concerns.take(2),
    if (strengths.isNotEmpty) strengths.first,
  ];
}

class PassRiskDetailScreen extends StatefulWidget {
  final String certificateName;

  const PassRiskDetailScreen({super.key, required this.certificateName});

  @override
  State<PassRiskDetailScreen> createState() => _PassRiskDetailScreenState();
}

class _PassRiskDetailScreenState extends State<PassRiskDetailScreen> {
  bool _isRefreshing = false;

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

  String _riskLabel(String riskLevel) {
    switch (riskLevel) {
      case 'HIGH':
        return '위험';
      case 'MEDIUM':
        return '보통';
      case 'LOW':
        return '안정';
      default:
        return '알 수 없음';
    }
  }

  String _formatUpdatedAt(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return '방금 전 분석';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전 분석';
    if (diff.inHours < 24) return '${diff.inHours}시간 전 분석';
    return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} 분석';
  }

  Future<void> _refreshAnalysis() async {
    setState(() => _isRefreshing = true);
    try {
      await FirebaseFunctions.instance
          .httpsCallable('analyzePassRisk')
          .call({'certificateName': widget.certificateName});
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('다시 분석하는 데 실패했어요. 잠시 후 다시 시도해주세요.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  void _showMethodologyInfo() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.fromLTRB(24, 22, 24, MediaQuery.of(context).viewInsets.bottom + 28),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '어떻게 예측하나요?',
                      style: TextStyle(
                        color: context.colors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Text(
                '학습 진도, 최근 며칠간의 완료 패턴, 남은 시험까지의 기간, '
                    '취약 과목 여부 등 여러 학습 신호를 종합해서 AI 모델이 합격 가능성을 추정해요.\n\n'
                    '이 예측은 참고용 지표이며, 실제 합격 여부를 보장하지 않아요. '
                    '학습 기록이 쌓일수록 예측의 신뢰도도 함께 올라가요.',
                style: TextStyle(
                  color: context.colors.textSecondary,
                  fontSize: 13.5,
                  height: 1.6,
                ),
              ),
              SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: context.colors.pinkStart,
                    foregroundColor: context.colors.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text('확인했어요', style: TextStyle(fontWeight: FontWeight.w800)),
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
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppTopBar(
        title: '${widget.certificateName} 합격 예측',
        actions: [
          IconButton(
            tooltip: '어떻게 예측하나요?',
            icon: Icon(Icons.help_outline_rounded),
            onPressed: _showMethodologyInfo,
          ),
        ],
      ),
      body: AppMainBackground(
        child: SafeArea(
          child: user == null
              ? Center(child: Text('로그인이 필요합니다.'))
              : FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
            future: FirebaseFirestore.instance
                .collection('users')
                .where('uid', isEqualTo: user.uid)
                .limit(1)
                .get(),
            builder: (context, userSnapshot) {
              if (!userSnapshot.hasData) {
                return Center(
                  child: CircularProgressIndicator(color: context.colors.pinkStart),
                );
              }

              if (userSnapshot.data!.docs.isEmpty) {
                return Center(child: Text('사용자 정보를 찾을 수 없습니다.'));
              }

              final userDocRef = userSnapshot.data!.docs.first.reference;

              return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: userDocRef
                    .collection('analysis')
                    .doc(widget.certificateName.replaceAll('/', '_'))
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Center(
                      child: CircularProgressIndicator(color: context.colors.pinkStart),
                    );
                  }

                  final data = snapshot.data?.data();

                  if (data == null) {
                    return Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          '아직 분석 데이터가 없습니다.\n학습 계획을 진행하면 분석이 시작돼요.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: context.colors.textSecondary),
                        ),
                      ),
                    );
                  }

                  final passProbability = (data['passProbability'] as num?)?.toInt() ?? 0;
                  final riskLevel = (data['riskLevel'] as String?)?.trim() ?? 'UNKNOWN';
                  final factorsRaw = data['factors'] as Map<String, dynamic>? ?? {};
                  final debugRaw = data['debug'] as Map<String, dynamic>? ?? {};
                  final updatedAt = (data['updatedAt'] as Timestamp?)?.toDate();

                  final factors = factorsRaw.map(
                        (key, value) => MapEntry(key, (value as num?)?.toDouble() ?? 0.0),
                  );

                  final riskColor = _riskColor(context, riskLevel);
                  final insights = _buildInsights(factors);
                  final confidence = _assessConfidence(debugRaw);

                  return SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(20, 16, 20, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 마지막 분석 시각 + 새로고침 — "왜 안 바뀌었어요?" 질문 방어
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatUpdatedAt(updatedAt),
                              style: TextStyle(
                                color: context.colors.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            InkWell(
                              onTap: _isRefreshing ? null : _refreshAnalysis,
                              borderRadius: BorderRadius.circular(20),
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_isRefreshing)
                                      SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: context.colors.pinkStart,
                                        ),
                                      )
                                    else
                                      Icon(Icons.refresh_rounded,
                                          size: 14, color: context.colors.pinkStart),
                                    SizedBox(width: 4),
                                    Text(
                                      '지금 다시 분석',
                                      style: TextStyle(
                                        color: context.colors.pinkStart,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 10),
                        _RiskHeroCard(
                          passProbability: passProbability,
                          riskLabel: _riskLabel(riskLevel),
                          riskColor: riskColor,
                          encouragementMessage: _encouragementFor(riskLevel, passProbability),
                        ),
                        if (confidence.isLow) ...[
                          SizedBox(height: 12),
                          _ConfidenceNoticeCard(message: confidence.message),
                        ],
                        if (insights.isNotEmpty) ...[
                          SizedBox(height: 26),
                          _SectionHeader(title: '지금 확인해보면 좋아요'),
                          SizedBox(height: 10),
                          ...insights.map(
                                (insight) => Padding(
                              padding: EdgeInsets.only(bottom: 8),
                              child: _InsightCard(insight: insight),
                            ),
                          ),
                        ],
                        SizedBox(height: 20),
                        Text(
                          '이 예측은 학습 데이터를 바탕으로 한 참고 지표이며, '
                              '실제 합격 여부를 보장하지 않아요.',
                          style: TextStyle(
                            color: context.colors.textMuted,
                            fontSize: 11,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

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
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _ConfidenceNoticeCard extends StatelessWidget {
  final String message;
  const _ConfidenceNoticeCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: context.colors.lavender.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 16, color: context.colors.lavenderAccent),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final _Insight insight;
  const _InsightCard({required this.insight});

  @override
  Widget build(BuildContext context) {
    final Color color = insight.isConcern ? context.colors.warning : context.colors.mintAccent;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      padding: EdgeInsets.fromLTRB(13, 12, 14, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            insight.isConcern ? Icons.priority_high_rounded : Icons.check_circle_outline_rounded,
            size: 16,
            color: color,
          ),
          SizedBox(width: 9),
          Expanded(
            child: Text(
              insight.message,
              style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RiskHeroCard extends StatelessWidget {
  final int passProbability;
  final String riskLabel;
  final Color riskColor;
  final String encouragementMessage;

  const _RiskHeroCard({
    required this.passProbability,
    required this.riskLabel,
    required this.riskColor,
    required this.encouragementMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(22, 26, 22, 22),
      decoration: BoxDecoration(
        gradient: context.colors.themedHeroGradient,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: context.colors.surface, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '예상 합격 가능성',
            style: TextStyle(
              color: context.colors.textPrimary.withValues(alpha: 0.72),
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$passProbability',
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 52,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Padding(
                padding: EdgeInsets.only(bottom: 8, left: 2),
                child: Text(
                  '%',
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: riskColor.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(color: riskColor, shape: BoxShape.circle),
                ),
                SizedBox(width: 6),
                Text(
                  '위험도 $riskLabel',
                  style: TextStyle(
                    color: riskColor,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 18),
          // 응원 메시지: 별도 박스가 아니라 히어로 카드 안 서브 섹션으로
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: context.colors.surface.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.favorite_rounded, color: context.colors.pinkDeep, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    encouragementMessage,
                    style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
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

class _EncouragementCard extends StatelessWidget {
  final String message;
  const _EncouragementCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: context.colors.pinkSoft.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.favorite_rounded, color: context.colors.pinkDeep, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}