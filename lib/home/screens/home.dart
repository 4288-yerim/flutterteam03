import 'package:flutter/material.dart';

import '../../appwidgets/today_todo_app_widget.dart';
import '../../certificate/screens/certificate_schedule.dart';
import '../../mypage/screens/study_plan_screen.dart';
import '../../mypage/screens/study_record_screen.dart';
import '../../widgets/app_main_background.dart';
import '../../widgets/app_top_bar.dart';
import '../services/home_service.dart';
import '../widgets/home_widgets.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final HomeService _homeService = HomeService();

  late final Stream<List<HomeGoal>> _activeGoalsStream;
  late final Stream<String> _nicknameStream;
  late final Stream<List<HomeTodo>> _todayTodosStream;
  late final Stream<HomeTodayStudySummary> _todayStudySummaryStream;

  int _currentGoalIndex = 0;

  @override
  void initState() {
    super.initState();

    _activeGoalsStream = _homeService.watchActiveGoals();
    _nicknameStream = _homeService.watchCurrentUserNickname();
    _todayTodosStream = _homeService.watchTodayTodos();
    _todayStudySummaryStream =
        _homeService.watchTodayStudySummary();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String>(
      stream: _nicknameStream,
      initialData: '사용자',
      builder: (context, nicknameSnapshot) {
        final rawNickname =
            nicknameSnapshot.data?.trim() ?? '';

        final nickname = rawNickname.isEmpty
            ? '사용자'
            : rawNickname;

        return Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
          extendBody: true,
          appBar: AppTopBar(
            title: '안녕하세요, $nickname님!',
          ),
          body: AppMainBackground(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                24,
                20,
                24,
                50,
              ),
              children: [
                HomeCertificateScheduleButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                        const CertificateSchedulePage(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 14),
                StreamBuilder<List<HomeGoal>>(
                  stream: _activeGoalsStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return const HomeGoalLoadingCard();
                    }

                    if (snapshot.hasError) {
                      return HomeGoalErrorCard(
                        message:
                        snapshot.error is HomeServiceException
                            ? (snapshot.error!
                        as HomeServiceException)
                            .message
                            : '목표 자격증을 불러오지 못했습니다.',
                      );
                    }

                    final goals =
                        snapshot.data ?? const <HomeGoal>[];

                    if (goals.isEmpty) {
                      return const HomeEmptyGoalCard();
                    }

                    final safeIndex =
                    _currentGoalIndex >= goals.length
                        ? goals.length - 1
                        : _currentGoalIndex;

                    return HomeGoalCardSlider(
                      goals: goals,
                      currentIndex: safeIndex,
                      onPageChanged: (index) {
                        if (_currentGoalIndex == index) {
                          return;
                        }

                        setState(() {
                          _currentGoalIndex = index;
                        });
                      },
                    );
                  },
                ),
                const SizedBox(height: 28),
                HomeSectionHeader(
                  title: '오늘의 할 일',
                  actionText: '전체보기',
                  onActionPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                        const StudyPlanScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 14),
                StreamBuilder<List<HomeTodo>>(
                  stream: _todayTodosStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return Container(
                        width: double.infinity,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(
                            alpha: 0.92,
                          ),
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: const Center(
                          child: SizedBox(
                            width: 26,
                            height: 26,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: Color(0xFFF06F91),
                            ),
                          ),
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      final message =
                      snapshot.error is HomeServiceException
                          ? (snapshot.error!
                      as HomeServiceException)
                          .message
                          : '오늘의 학습 계획을 불러오지 못했습니다.';

                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 26,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(
                            alpha: 0.92,
                          ),
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              size: 34,
                              color: Color(0xFFF06F91),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              '오늘의 학습 계획을 불러오지 못했습니다.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF302C2E),
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              message,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFF817B7D),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final todos =
                        snapshot.data ?? const <HomeTodo>[];

                    return HomeTodayTodoCard(
                      todos: todos,
                      onTodoPressed: (todo) async {
                        try {
                          await _homeService.toggleTodoStatus(todo);
                          await TodayTodoAppWidget.sync();
                        } on HomeServiceException catch (error) {
                          if (!context.mounted) {
                            return;
                          }

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(error.message),
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
                const SizedBox(height: 32),
                HomeSectionHeader(
                  title: '오늘 공부 시간',
                ),
                const SizedBox(height: 14),
                StreamBuilder<HomeTodayStudySummary>(
                  stream: _todayStudySummaryStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return const HomeTodayStudyLoadingCard();
                    }

                    if (snapshot.hasError) {
                      return HomeTodayStudyErrorCard(
                        message:
                        snapshot.error is HomeServiceException
                            ? (snapshot.error!
                        as HomeServiceException)
                            .message
                            : '오늘 공부 기록을 불러오지 못했습니다.',
                      );
                    }

                    final summary = snapshot.data ??
                        const HomeTodayStudySummary.empty();

                    return Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.stretch,
                      children: [
                        HomeTodayStudyCard(
                          summary: summary,
                        ),
                        const SizedBox(height: 32),
                        const HomeSectionHeader(
                          title: '스터디 공부 시간',
                        ),
                        const SizedBox(height: 14),
                        HomeStudyGroupStatusCard(
                          studyGroups: summary.studyGroups,
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}