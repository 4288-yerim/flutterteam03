import 'package:flutter/material.dart';

import '../../widgets/app_main_background.dart';
import '../../widgets/app_top_bar.dart';
import '../widgets/notification_widgets.dart';

class NotificationPage extends StatelessWidget {
  const NotificationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: const AppTopBar(
        title: '알림',
      ),
      body: const AppMainBackground(
        child: SafeArea(
          child: NotificationEmptyView(),
        ),
      ),
    );
  }
}