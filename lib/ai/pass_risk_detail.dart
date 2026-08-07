import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../theme.dart';
import '../widgets/app_main_background.dart';
import '../widgets/app_top_bar.dart';

/// 백엔드 factors 필드 키를 화면에 보여줄 라벨/설명/표시형식으로 매핑.
class _FactorMeta {
  final String label;
  final String description;
  final String Function(double value) formatValue;
  final double Function(double value) toBarRatio; // 0~1로 정규화 (진행바용)

  const _FactorMeta({
    required this.label,
    required this.description,
    required this.formatValue,
    required this.toBarRatio,
  });
}

String _percentText(double v) => '${(v * 100).clamp(0, 100).round()}%';

/// 위험도에 따라 다르게 보여줄 짧은 응원/조언 메시지.
/// AI 호출 없이 riskLevel로 바로 분기하는 방식이라 비용 없이 즉시 반영됨.
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

final Map<String, _FactorMeta> _factorMetaMap = {
  'consistencyScore': _FactorMeta(
    label: '학습 꾸준함',
    description: '최근 14일 동안 계획한 학습을 얼마나 꾸준히 완료했는지',
    formatValue: _percentText,
    toBarRatio: (v) => v.clamp(0, 1),
  ),
  'recentCompletionRate': _FactorMeta(
    label: '최근 완료율',
    description: '최근 7일 학습 계획 중 실제로 완료한 비율',
    formatValue: _percentText,
    toBarRatio: (v) => v.clamp(0, 1),
  ),
  'elapsedRatio': _FactorMeta(
    label: '경과 기간',
    description: '전체 학습 기간 중 이미 지나간 기간의 비율',
    formatValue: _percentText,
    toBarRatio: (v) => v.clamp(0, 1),
  ),
  'progressGap': _FactorMeta(
    label: '진도 격차',
    description: '경과한 기간에 비해 실제 진도가 얼마나 뒤처졌는지 (0에 가까울수록 양호)',
    formatValue: (v) => '${(v * 100).round()}%p',
    toBarRatio: (v) => ((v + 1) / 2).clamp(0, 1), // -1~1 → 0~1
  ),
  'subjectWeakRatio': _FactorMeta(
    label: '취약 과목 비중',
    description: '최근 오답 기록을 바탕으로 계산한 약점 과목 비율',
    formatValue: _percentText,
    toBarRatio: (v) => v.clamp(0, 1),
  ),
  'timePressure': _FactorMeta(
    label: '시간 압박도',
    description: '남은 학습량 대비 남은 일수가 얼마나 촉박한지 (1을 넘으면 하루에 처리할 분량이 많다는 뜻)',
    formatValue: (v) => '${v.toStringAsFixed(1)}배',
    toBarRatio: (v) => (v / 4).clamp(0, 1),
  ),
  'daysRemainingNorm': _FactorMeta(
    label: '남은 기간 여유도',
    description: '전체 학습 기간 대비 아직 남은 기간의 비율',
    formatValue: _percentText,
    toBarRatio: (v) => v.clamp(0, 1),
  ),
  'difficultyNorm': _FactorMeta(
    label: '체감 난이도',
    description: '자격증 난이도',
    formatValue: _percentText,
    toBarRatio: (v) => v.clamp(0, 1),
  ),
};

_FactorMeta _metaFor(String key) =>
    _factorMetaMap[key] ??
        _FactorMeta(
          label: key,
          description: '',
          formatValue: (v) => v.toStringAsFixed(2),
          toBarRatio: (v) => v.clamp(0, 1),
        );

class PassRiskDetailScreen extends StatelessWidget {
  final String certificateName;

  const PassRiskDetailScreen({super.key, required this.certificateName});

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

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppTopBar(title: '$certificateName 합격 예측'),
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
                  child: CircularProgressIndicator(
                    color: context.colors.pinkStart,
                  ),
                );
              }

              if (userSnapshot.data!.docs.isEmpty) {
                return Center(child: Text('사용자 정보를 찾을 수 없습니다.'));
              }

              final userDocRef = userSnapshot.data!.docs.first.reference;

              return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: userDocRef
                    .collection('analysis')
                    .doc(certificateName.replaceAll('/', '_'))
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Center(
                      child: CircularProgressIndicator(
                        color: context.colors.pinkStart,
                      ),
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
                          style:
                          TextStyle(color: context.colors.textSecondary),
                        ),
                      ),
                    );
                  }

                  final passProbability =
                      (data['passProbability'] as num?)?.toInt() ?? 0;
                  final riskLevel =
                      (data['riskLevel'] as String?)?.trim() ?? 'UNKNOWN';
                  final factorsRaw =
                      data['factors'] as Map<String, dynamic>? ?? {};

                  final factors = factorsRaw.map(
                        (key, value) =>
                        MapEntry(key, (value as num?)?.toDouble() ?? 0.0),
                  );

                  final riskColor = _riskColor(context, riskLevel);

                  return SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(20, 16, 20, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _RiskHeroCard(
                          passProbability: passProbability,
                          riskLabel: _riskLabel(riskLevel),
                          riskColor: riskColor,
                        ),
                        SizedBox(height: 14),
                        _EncouragementCard(
                          message: _encouragementFor(riskLevel, passProbability),
                        ),
                        SizedBox(height: 28),
                        Row(
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
                              '이렇게 분석했어요',
                              style: TextStyle(
                                color: context.colors.textPrimary,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Padding(
                          padding: EdgeInsets.only(left: 12),
                          child: Text(
                            '아래 8가지 요인을 종합해서 합격 가능성을 예측했어요.',
                            style: TextStyle(
                              color: context.colors.textSecondary,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        SizedBox(height: 16),
                        ...factors.entries.map(
                              (entry) => Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: _FactorCard(
                              meta: _metaFor(entry.key),
                              value: entry.value,
                            ),
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

class _RiskHeroCard extends StatelessWidget {
  final int passProbability;
  final String riskLabel;
  final Color riskColor;

  const _RiskHeroCard({
    required this.passProbability,
    required this.riskLabel,
    required this.riskColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(22, 26, 22, 24),
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
          SizedBox(height: 14),
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
                  decoration: BoxDecoration(
                    color: riskColor,
                    shape: BoxShape.circle,
                  ),
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

class _FactorCard extends StatelessWidget {
  final _FactorMeta meta;
  final double value;

  const _FactorCard({required this.meta, required this.value});

  @override
  Widget build(BuildContext context) {
    final ratio = meta.toBarRatio(value);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: context.colors.surfaceTransparent.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.colors.border, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                meta.label,
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                meta.formatValue(value),
                style: TextStyle(
                  color: context.colors.pinkDeep,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          if (meta.description.isNotEmpty) ...[
            SizedBox(height: 4),
            Text(
              meta.description,
              style: TextStyle(
                color: context.colors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ],
          SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: context.colors.divider,
              valueColor: AlwaysStoppedAnimation(context.colors.pinkStart),
            ),
          ),
        ],
      ),
    );
  }
}