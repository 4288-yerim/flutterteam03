import 'package:flutter/material.dart';

import '../services/admin_home_service.dart';

class AdminWelcomeCard extends StatelessWidget {
  const AdminWelcomeCard({
    super.key,
    required this.administratorName,
    required this.todayLabel,
  });

  final String administratorName;
  final String todayLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF8B7DF5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x336C63FF),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.admin_panel_settings_rounded,
              color: Colors.white,
              size: 29,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$administratorName님, 안녕하세요',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '$todayLabel · 서비스 운영 현황입니다.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 13,
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

class AdminSectionTitle extends StatelessWidget {
  const AdminSectionTitle({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF29292E),
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: const TextStyle(color: Color(0xFF77747E), fontSize: 13),
          ),
        ],
      ],
    );
  }
}

class AdminPendingSummary extends StatelessWidget {
  const AdminPendingSummary({
    super.key,
    required this.reportCount,
    required this.inquiryCount,
    required this.onReportTap,
    required this.onInquiryTap,
  });

  final int reportCount;
  final int inquiryCount;
  final VoidCallback onReportTap;
  final VoidCallback onInquiryTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _PendingCard(
            title: '미처리 신고',
            count: reportCount,
            unit: '건',
            icon: Icons.report_problem_rounded,
            color: const Color(0xFFE85D68),
            backgroundColor: const Color(0xFFFFF0F1),
            onTap: onReportTap,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _PendingCard(
            title: '미처리 문의',
            count: inquiryCount,
            unit: '건',
            icon: Icons.mark_unread_chat_alt_rounded,
            color: const Color(0xFFE59831),
            backgroundColor: const Color(0xFFFFF6E8),
            onTap: onInquiryTap,
          ),
        ),
      ],
    );
  }
}

class _PendingCard extends StatelessWidget {
  const _PendingCard({
    required this.title,
    required this.count,
    required this.unit,
    required this.icon,
    required this.color,
    required this.backgroundColor,
    required this.onTap,
  });

  final String title;
  final int count;
  final String unit;
  final IconData icon;
  final Color color;
  final Color backgroundColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon, color: color, size: 25),
                  Icon(Icons.arrow_forward_rounded, color: color, size: 19),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF5D5962),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '$count',
                      style: TextStyle(
                        color: color,
                        fontSize: 27,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    TextSpan(
                      text: ' $unit',
                      style: const TextStyle(
                        color: Color(0xFF5D5962),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AdminMetricGrid extends StatelessWidget {
  const AdminMetricGrid({
    super.key,
    required this.metrics,
  });

  final List<AdminMetric> metrics;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: metrics.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: 155,
      ),
      itemBuilder: (context, index) {
        final metric = metrics[index];

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFECE9F0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                metric.icon,
                color: metric.color,
                size: 23,
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    metric.value,
                    style: const TextStyle(
                      color: Color(0xFF29292E),
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    metric.label,
                    style: const TextStyle(
                      color: Color(0xFF5D5962),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    metric.comparison,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF99949E),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class AdminWeeklyStatusCard extends StatelessWidget {
  const AdminWeeklyStatusCard({super.key, required this.statuses});

  final List<AdminWeeklyStatus> statuses;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFECE9F0)),
      ),
      child: Column(
        children: List.generate(statuses.length, (index) {
          final status = statuses[index];
          return Padding(
            padding: EdgeInsets.only(
              bottom: index == statuses.length - 1 ? 0 : 20,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        status.label,
                        style: const TextStyle(
                          color: Color(0xFF4D4951),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      status.detail,
                      style: const TextStyle(
                        color: Color(0xFF77747E),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(status.value * 100).round()}%',
                      style: const TextStyle(
                        color: Color(0xFF6C63FF),
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: status.value,
                    minHeight: 7,
                    backgroundColor: const Color(0xFFEDEAF7),
                    valueColor: const AlwaysStoppedAnimation(
                      Color(0xFF756CE0),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class AdminHomeLoadingView extends StatelessWidget {
  const AdminHomeLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
    );
  }
}

class AdminHomeErrorView extends StatelessWidget {
  const AdminHomeErrorView({super.key, required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 42,
            color: Color(0xFFE85D68),
          ),
          const SizedBox(height: 12),
          const Text('홈 정보를 불러오지 못했습니다.'),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: onRetry, child: const Text('다시 시도')),
        ],
      ),
    );
  }
}
