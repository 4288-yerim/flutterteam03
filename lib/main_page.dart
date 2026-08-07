import 'package:flutter/material.dart';
import 'package:flutterteam03/mypage/screens/mypage_screen.dart';
import 'package:flutterteam03/study/study_list.dart';
import 'package:showcaseview/showcaseview.dart';
import '../widgets/app_bottom_bar.dart';
import 'ai/ai_main.dart';
import 'home/screens/home.dart';
import '../widgets/tutorial_card.dart';
import 'package:flutterteam03/community/community_main.dart';

class MainPage extends StatefulWidget {
  final bool showTutorial;

  const MainPage({super.key, this.showTutorial = false});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;

  final GlobalKey _bottomBarKey = GlobalKey();
  final GlobalKey _notificationKey = GlobalKey();
  final GlobalKey _certScheduleKey = GlobalKey();
  final GlobalKey _todayTodoKey = GlobalKey();
  final GlobalKey _todayStudyKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (widget.showTutorial) {
      ShowcaseView.register(
        enableAutoScroll: true,
        scrollDuration: const Duration(milliseconds: 400),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ShowcaseView.get().startShowCase([
          _notificationKey,
          _certScheduleKey,
          _todayTodoKey,
          _todayStudyKey,
          _bottomBarKey,
        ]);
      });
    }
  }

  @override
  void dispose() {
    if (widget.showTutorial) {
      ShowcaseView.get().unregister();
    }
    super.dispose();
  }

  void _onBottomMenuTapped(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final bottomBar = AppBottomBar(
      currentIndex: _currentIndex,
      onTap: _onBottomMenuTapped,
    );

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomePage(
            notificationKey: widget.showTutorial ? _notificationKey : null,
            certScheduleKey: widget.showTutorial ? _certScheduleKey : null,
            todayTodoKey: widget.showTutorial ? _todayTodoKey : null,
            todayStudyKey: widget.showTutorial ? _todayStudyKey : null,
          ),
          const StudyListApp(),
          AiPage(),
          const CommunityMainPage(),
          const MyPageScreen(),
        ],
      ),
      bottomNavigationBar: widget.showTutorial
          ? Showcase.withWidget(
              key: _bottomBarKey,
              targetBorderRadius: BorderRadius.circular(18),
              targetPadding: const EdgeInsets.all(10),
              overlayColor: Colors.black,
              overlayOpacity: 0.65,
              tooltipPosition: TooltipPosition.top,
              container: const TutorialCard(
                icon: Icons.grid_view_rounded,
                title: '메인 메뉴',
                description: '여기서 홈, 스터디, AI, 커뮤니티, 마이페이지로 이동할 수 있어요!',
                isLast: true,
                pointUp: false,
              ),
              child: bottomBar,
            )
          : bottomBar,
    );
  }
}
