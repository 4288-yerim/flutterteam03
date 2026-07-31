import 'package:flutter/material.dart';

import 'admin_section_screen.dart';

class CertificateManagementScreen extends StatelessWidget {
  const CertificateManagementScreen({super.key});

  @override
  Widget build(BuildContext context) => const AdminSectionScreen(
    title: '자격증 관리',
    description: '자격증 정보와 시험 일정을 등록하고 관리합니다.',
    icon: Icons.workspace_premium_outlined,
  );
}
