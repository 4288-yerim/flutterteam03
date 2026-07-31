import 'package:flutter/material.dart';

import 'admin_section_screen.dart';

class ReportManagementScreen extends StatelessWidget {
  const ReportManagementScreen({super.key});

  @override
  Widget build(BuildContext context) => const AdminSectionScreen(
    title: '신고 관리',
    description: '접수된 신고를 확인하고 처리 상태를 관리합니다.',
    icon: Icons.report_outlined,
  );
}
