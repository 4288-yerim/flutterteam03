import 'package:flutter/material.dart';

import 'admin_section_screen.dart';

class NoticeManagementScreen extends StatelessWidget {
  const NoticeManagementScreen({super.key});

  @override
  Widget build(BuildContext context) => const AdminSectionScreen(
    title: '공지 관리',
    description: '서비스 공지사항을 작성하고 게시 상태를 관리합니다.',
    icon: Icons.campaign_outlined,
  );
}
