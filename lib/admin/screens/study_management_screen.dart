import 'package:flutter/material.dart';

import 'admin_section_screen.dart';

class AiUsageLogManagementScreen extends StatelessWidget {
  const AiUsageLogManagementScreen({super.key});

  @override
  Widget build(BuildContext context) => const AdminSectionScreen(
    title: '스터디 관리',
    description: '스터디 관리합니다.',
    icon: Icons.smart_toy_outlined,
  );
}
