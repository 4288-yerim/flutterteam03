import 'package:flutter/material.dart';

import 'admin_section_screen.dart';

class MemberManagementScreen extends StatelessWidget {
  const MemberManagementScreen({super.key});

  @override
  Widget build(BuildContext context) => const AdminSectionScreen(
    title: '회원 관리',
    description: '회원 정보와 계정 상태를 조회하고 관리합니다.',
    icon: Icons.people_outline,
  );
}
