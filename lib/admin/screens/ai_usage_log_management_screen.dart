import 'package:flutter/material.dart';

import 'admin_section_screen.dart';

class AiUsageLogManagementScreen extends StatelessWidget {
  const AiUsageLogManagementScreen({super.key});

  @override
  Widget build(BuildContext context) => const AdminSectionScreen(
    title: 'AI 사용 로그 관리',
    description: 'AI 기능의 사용 기록과 처리 결과를 확인합니다.',
    icon: Icons.smart_toy_outlined,
  );
}
