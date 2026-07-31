import 'package:flutter/material.dart';

import 'admin_section_screen.dart';

class NotificationSendScreen extends StatelessWidget {
  const NotificationSendScreen({super.key});

  @override
  Widget build(BuildContext context) => const AdminSectionScreen(
    title: '알림 발송',
    description: '사용자에게 보낼 알림을 작성하고 발송합니다.',
    icon: Icons.notifications_active_outlined,
  );
}
