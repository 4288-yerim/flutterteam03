import 'package:flutter/material.dart';

import '../../theme.dart';
import '../services/admin_statistics_service.dart';

class StatisticsManagementScreen extends StatefulWidget {
  const StatisticsManagementScreen({super.key});

  @override
  State<StatisticsManagementScreen> createState() =>
      _StatisticsManagementScreenState();
}

class _StatisticsManagementScreenState
    extends State<StatisticsManagementScreen> {
  final AdminStatisticsService _service = AdminStatisticsService();
  late Future<AdminStatisticsData> _statistics = _service.fetchStatistics();

  Future<void> _refresh() async {
    setState(() => _statistics = _service.fetchStatistics());
    await _statistics;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AdminStatisticsData>(
      future: _statistics,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return Center(
            child: CircularProgressIndicator(
              color: context.colors.lavenderAccent,
            ),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return _ErrorView(onRetry: _refresh);
        }

        final data = snapshot.data!;
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
            children: [
              _SummaryHeader(data: data),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 900
                      ? 4
                      : constraints.maxWidth >= 560
                      ? 2
                      : 1;
                  final width =
                      (constraints.maxWidth - (columns - 1) * 12) / columns;
                  final cards = _metricCards(data);
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: cards
                        .map((card) => SizedBox(width: width, child: card))
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 16),
              _ActivityPanel(activity: data.dailyActivity),
              const SizedBox(height: 16),
              _OperationsPanel(data: data),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _metricCards(AdminStatisticsData data) {
    return [
      _MetricCard(
        icon: Icons.people_outline,
        label: '전체 회원',
        value: '${data.totalMembers}명',
        detail: '활성 ${data.activeMembers}명 · 오늘 +${data.todayMembers}명',
      ),
      _MetricCard(
        icon: Icons.forum_outlined,
        label: '커뮤니티 게시글',
        value: '${data.totalPosts}개',
        detail: '공개 ${data.visiblePosts}개 · 숨김 ${data.hiddenPosts}개',
      ),
      _MetricCard(
        icon: Icons.comment_outlined,
        label: '표시 댓글 수',
        value: '${data.totalComments}개',
        detail: '게시글 commentCount 합계',
      ),
      _MetricCard(
        icon: Icons.groups_outlined,
        label: '스터디',
        value: '${data.totalStudyGroups}개',
        detail: '현재 참여 인원 합계 ${data.totalStudyMembers}명',
      ),
    ];
  }
}

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({required this.data});
  final AdminStatisticsData data;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: context.colors.lavender,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              Icons.bar_chart_rounded,
              color: context.colors.lavenderAccent,
              size: 31,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '서비스 운영 통계',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 5),
                Text(
                  '회원·커뮤니티·신고·문의·공지·스터디 데이터를 집계합니다.\n'
                      '마지막 조회 ${_formatDateTime(data.loadedAt)}',
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    height: 1.4,
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

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
  });

  final IconData icon;
  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Row(
        children: [
          Icon(icon, color: context.colors.lavenderAccent, size: 30),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: context.colors.textMuted)),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 12,
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

class _ActivityPanel extends StatelessWidget {
  const _ActivityPanel({required this.activity});
  final List<AdminDailyActivity> activity;

  @override
  Widget build(BuildContext context) {
    final maximum = activity.fold<int>(
      1,
          (value, item) => item.total > value ? item.total : value,
    );
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '최근 7일 신규 활동',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          Text(
            '회원가입 + 게시글 + 신고 + 문의 접수 합계',
            style: TextStyle(color: context.colors.textSecondary),
          ),
          const SizedBox(height: 18),
          ...activity.map(
                (item) => Padding(
              padding: const EdgeInsets.only(bottom: 11),
              child: Row(
                children: [
                  SizedBox(width: 48, child: Text(_formatDay(item.date))),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: item.total / maximum,
                        minHeight: 12,
                        backgroundColor: context.colors.surfaceMuted,
                        color: context.colors.lavenderAccent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 30,
                    child: Text(
                      '${item.total}',
                      textAlign: TextAlign.end,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OperationsPanel extends StatelessWidget {
  const _OperationsPanel({required this.data});
  final AdminStatisticsData data;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '현재 운영 대기 현황',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          _OperationRow(
            icon: Icons.report_outlined,
            label: '처리 대기 신고',
            value: '${data.pendingReports}건',
          ),
          _OperationRow(
            icon: Icons.task_alt_rounded,
            label: '오늘 처리한 신고',
            value: '${data.processedReportsToday}건',
          ),
          _OperationRow(
            icon: Icons.support_agent_outlined,
            label: '답변 대기 문의',
            value: '${data.pendingInquiries}건',
          ),
          _OperationRow(
            icon: Icons.campaign_outlined,
            label: '게시 중 공지',
            value: '${data.publishedNotices}건',
            showDivider: false,
          ),
        ],
      ),
    );
  }
}

class _OperationRow extends StatelessWidget {
  const _OperationRow({
    required this.icon,
    required this.label,
    required this.value,
    this.showDivider = true,
  });
  final IconData icon;
  final String label;
  final String value;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            children: [
              Icon(icon, color: context.colors.textMuted, size: 21),
              const SizedBox(width: 10),
              Expanded(child: Text(label)),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
        ),
        if (showDivider) const Divider(height: 1),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.colors.surfaceTransparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.colors.border),
      ),
      child: child,
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: context.colors.textMuted),
          const SizedBox(height: 12),
          const Text('통계를 불러오지 못했습니다.'),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('다시 시도')),
        ],
      ),
    );
  }
}

String _formatDay(DateTime date) => '${date.month}/${date.day}';

String _formatDateTime(DateTime date) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${date.year}.${two(date.month)}.${two(date.day)} '
      '${two(date.hour)}:${two(date.minute)}';
}
