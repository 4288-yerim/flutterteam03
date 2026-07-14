import 'package:flutter/material.dart';
import 'package:flutterteam03/widgets/app_state_views.dart';

class StateViewTestScreen extends StatelessWidget {
  const StateViewTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('상태 화면 테스트'),
      ),
      body: const AppLoadingView(
        message: '목표 자격증을 불러오는 중입니다.',
      ),
    );
  }
}