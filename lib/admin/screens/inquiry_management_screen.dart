import 'package:flutter/material.dart';

import 'admin_section_screen.dart';

class InquiryManagementScreen extends StatelessWidget {
  const InquiryManagementScreen({super.key});

  @override
  Widget build(BuildContext context) => const AdminSectionScreen(
    title: '문의 관리',
    description: '사용자 문의를 확인하고 답변 및 처리 상태를 관리합니다.',
    icon: Icons.support_agent_outlined,
  );
}
