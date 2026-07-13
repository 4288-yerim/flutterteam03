import 'package:flutter/material.dart';
import '../widgets/app_bottom_bar.dart';

/// 하단 탭 5개(홈/스터디/AI/커뮤니티/마이페이지)를 관리하는 뼈대 화면.
/// AppBottomBar는 UI만 그려주므로, 실제 탭 전환 로직은 여기서 담당합니다.
class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;

  // AppBottomBar의 _items 순서와 반드시 동일해야 함: 홈, 스터디, AI, 커뮤니티, 마이페이지
  // 팀원이 실제 화면 완성하면 여기 Center(Text(...)) 자리를 각자 화면 위젯으로 교체하면 됨
  final List<Widget> _pages = const [
    Center(child: Text('홈 (placeholder)')),
    Center(child: Text('스터디 (placeholder)')),
    Center(child: Text('AI (placeholder)')),
    Center(child: Text('커뮤니티 (placeholder)')),
    Center(child: Text('마이페이지 (placeholder)')),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // 바텀바가 투명/떠있는 스타일이라 body가 바 뒤까지 깔리게 함
      body: _pages[_currentIndex],
      bottomNavigationBar: AppBottomBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}