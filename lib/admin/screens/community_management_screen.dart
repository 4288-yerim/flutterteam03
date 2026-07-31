import 'package:flutter/material.dart';

import 'admin_section_screen.dart';

class CommunityManagementScreen extends StatelessWidget {
  const CommunityManagementScreen({super.key});

  @override
  Widget build(BuildContext context) => const AdminSectionScreen(
    title: '커뮤니티 관리',
    description: '게시글과 댓글 등 커뮤니티 콘텐츠를 관리합니다.',
    icon: Icons.forum_outlined,
  );
}
