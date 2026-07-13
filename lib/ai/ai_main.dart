import 'package:flutter/material.dart';

import '../widgets/app_main_background.dart';
import '../widgets/app_top_bar.dart';

class AiPage extends StatelessWidget {
  const AiPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppTopBar(
        centerTitle: false,
        title: 'AI 학습도우미',
        titleStyle: const TextStyle(
          color: Color(0xFF302C2E),
          fontSize: 26,
          fontWeight: FontWeight.w800,
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.notifications_none_rounded,
              color: Color(0xFF302C2E),
            ),
          ),
        ],
      ),
      body: const AppMainBackground(
        child: Center(
          child: Text(
            'AI 화면',
            style: TextStyle(
              color: Color(0xFF302C2E),
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}