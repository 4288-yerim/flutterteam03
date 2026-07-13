import 'package:flutter/material.dart';
import '../widgets/app_bottom_bar.dart';
import 'ai/ai_main.dart';
import 'home/home.dart';

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
          _TemporaryPage(title: '스터디'),
          AiPage(),
          _TemporaryPage(title: '커뮤니티'),
          _TemporaryPage(title: '마이페이지'),
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