import 'package:flutter/material.dart';

import '../widgets/app_main_background.dart';
import '../widgets/app_top_bar.dart';

class AiStudyPlanPage extends StatelessWidget {
  const AiStudyPlanPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: const AppTopBar(
        title: 'AI 학습 플랜',
        centerTitle: false,
      ),
      body: AppMainBackground(
        child: const SafeArea(
          child: Center(
            child: Text(
              'AI 학습 플랜 페이지',
              style: TextStyle(
                color: Color(0xFF302C2E),
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}