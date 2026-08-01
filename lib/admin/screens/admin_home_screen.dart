import 'package:flutter/material.dart';

import '../../theme.dart';

import '../services/admin_home_service.dart';
import '../widgets/admin_home_widgets.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({
    super.key,
    required this.onReportTap,
    required this.onInquiryTap,
  });

  final VoidCallback onReportTap;
  final VoidCallback onInquiryTap;

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  final AdminHomeService _service = AdminHomeService();
  late Future<AdminHomeData> _homeData;

  @override
  void initState() {
    super.initState();
    _homeData = _service.fetchHomeData();
  }

  Future<void> _refresh() async {
    setState(() {
      _homeData = _service.fetchHomeData();
    });
    await _homeData;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AdminHomeData>(
      future: _homeData,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const AdminHomeLoadingView();
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return AdminHomeErrorView(onRetry: _refresh);
        }

        final data = snapshot.data!;

        return RefreshIndicator(
          color: context.colors.lavenderAccent,
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
            children: [
              AdminWelcomeCard(
                administratorName: data.administratorName,
                todayLabel: data.todayLabel,
              ),
              const SizedBox(height: 24),
              const AdminSectionTitle(
                title: '처리 대기',
                subtitle: '우선 확인이 필요한 항목이에요.',
              ),
              const SizedBox(height: 12),
              AdminPendingSummary(
                reportCount: data.pendingReportCount,
                inquiryCount: data.pendingInquiryCount,
                onReportTap: widget.onReportTap,
                onInquiryTap: widget.onInquiryTap,
              ),
              const SizedBox(height: 26),
              const AdminSectionTitle(
                title: '오늘의 서비스 현황',
                subtitle: '주요 운영 지표를 한눈에 확인하세요.',
              ),
              const SizedBox(height: 12),
              AdminMetricGrid(metrics: data.metrics),
              const SizedBox(height: 26),
              const AdminSectionTitle(title: '최근 운영 현황', subtitle: '최근 7일 기준'),
              const SizedBox(height: 12),
              AdminWeeklyStatusCard(statuses: data.weeklyStatuses),
            ],
          ),
        );
      },
    );
  }
}
