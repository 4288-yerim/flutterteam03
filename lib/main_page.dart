import 'package:flutter/material.dart';
import 'package:flutterteam03/mypage/screens/mypage_screen.dart';
import 'package:flutterteam03/study/study_list.dart';
import '../widgets/app_bottom_bar.dart';
import 'ai/ai_main.dart';
import 'home/home.dart';
import 'package:flutterteam03/community/community_main.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MainPage(),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;

  void _onBottomMenuTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          HomePage(),
          StudyListApp(),
          AiPage(),
          CommunityMainPage(),
          MyPageScreen(),
        ],
      ),
      bottomNavigationBar: AppBottomBar(
        currentIndex: _currentIndex,
        onTap: _onBottomMenuTapped,
      ),
    );
  }
}

class _TemporaryPage extends StatelessWidget {
  final String title;

  const _TemporaryPage({
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          '$title 화면',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}