import 'package:flutter/material.dart';

import 'admin_section_screen.dart';

class StatisticsManagementScreen extends StatelessWidget {
  const StatisticsManagementScreen({super.key});

  @override
  Widget build(BuildContext context) => const AdminSectionScreen(
    title: '통계 관리',
    description: '서비스 이용 현황과 주요 운영 지표를 확인합니다.',
    icon: Icons.bar_chart_outlined,
  );
}
