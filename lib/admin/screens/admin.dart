import 'package:flutter/material.dart';

import '../../widgets/app_main_background.dart';
import '../../widgets/app_top_bar.dart';

class AdminPage extends StatelessWidget {
  const AdminPage({super.key});

  static const String routeName = '/admin';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const AppTopBar(
        title: '관리자 페이지',
      ),
      body: const AppMainBackground(
        child: Center(
          child: Text(
            '관리자 페이지입니다.',
            style: TextStyle(
              color: Color(0xFF1A1A1A),
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}