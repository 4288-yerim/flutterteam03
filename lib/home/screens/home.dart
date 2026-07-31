import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';
import '../../appwidgets/today_todo_app_widget.dart';
import '../../certificate/screens/certificate_schedule.dart';
import '../../mypage/screens/study_plan_screen.dart';
import '../../widgets/app_main_background.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/loading_overlay.dart';
import '../services/home_service.dart';
import '../widgets/home_widgets.dart';
import '../../notification/screens/notification.dart';
import '../../widgets/tutorial_card.dart';

class HomePage extends StatefulWidget {
  final GlobalKey? notificationKey;
  final GlobalKey? certScheduleKey;
  final GlobalKey? todayTodoKey;
  final GlobalKey? todayStudyKey;

  const HomePage({
    super.key,
    this.notificationKey,
    this.certScheduleKey,
    this.todayTodoKey,
    this.todayStudyKey,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final HomeService _homeService = HomeService();

  late Stream<List<HomeGoal>> _activeGoalsStream;
  late Stream<String> _nicknameStream;
  late Stream<List<HomeTodo>> _todayTodosStream;
  late Stream<HomeTodayStudySummary> _todayStudySummaryStream;

  int _currentGoalIndex = 0;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();

    _createHomeStreams();
  }

  void _createHomeStreams() {
    _activeGoalsStream = _homeService.watchActiveGoals();

    _nicknameStream = _homeService.watchCurrentUserNickname();

    _todayTodosStream = _homeService.watchTodayTodos();

    _todayStudySummaryStream = _homeService.watchTodayStudySummary();
  }

  void _onNotificationPressed() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const NotificationPage(),
      ),
    );
  }

  Future<void> _refreshHome() async {
    if (_isRefreshing) {
      return;
    }

    setState(() {
      _isRefreshing = true;
    });

    try {
      await _homeService.refreshCurrentUserStudyData();

      if (!mounted) {
        return;
      }

      setState(() {
        _currentGoalIndex = 0;
      });
    } on HomeServiceException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text('홈 정보를 새로고침하지 못했습니다.\n$error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  Widget _wrapShowcase({
    required GlobalKey? key,
    required IconData icon,
    required String title,
    required String description,
    required Widget child,
    bool showArrow = true,
    double arrowAlignX = 0.0,
  }) {
    if (key == null) return child;
    return Showcase.withWidget(
      key: key,
      targetBorderRadius: BorderRadius.circular(18),
      targetPadding: const EdgeInsets.all(14),
      overlayColor: Colors.black,
      overlayOpacity: 0.65,
      tooltipPosition: TooltipPosition.bottom,
      container: TutorialCard(
        icon: icon,
        title: title,
        description: description,
        pointUp: true,
        showArrow: showArrow,
        arrowAlignX: arrowAlignX,
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String>(
      stream: _nicknameStream,
      initialData: '사용자',
      builder: (context, nicknameSnapshot) {
        final rawNickname = nicknameSnapshot.data?.trim() ?? '';

        final nickname = rawNickname.isEmpty ? '사용자' : rawNickname;

        return Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
          extendBody: true,
          appBar: AppTopBar(
            title: '안녕하세요, $nickname님!',
            actions: [
              _wrapShowcase(
                key: widget.notificationKey,
                icon: Icons.notifications_rounded,
                title: '알림',
                description: '새로운 소식을 여기서 확인하세요!',
                arrowAlignX: 0.85,
                child: IconButton(
                  onPressed: _onNotificationPressed,
                  icon: const Icon(
                    Icons.notifications_none_rounded,
                    color: Color(0xFF302C2E),
                  ),
                ),
              ),
            ],
          ),
          body: Stack(
            children: [
              AppMainBackground(
                child: RefreshIndicator(
                  color: const Color(0xFFF06F91),
                  backgroundColor: Colors.white,
                  onRefresh: _refreshHome,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 50),
                    children: [
                      _wrapShowcase(
                        key: widget.certScheduleKey,
                        icon: Icons.calendar_month_rounded,
                        title: '자격증 일정',
                        description: '목표로 하는 자격증 일정을 확인해보세요.',
                        child: HomeCertificateScheduleButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const CertificateSchedulePage(),
                              ),
                            );
                          },
                        ),
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
                              message: snapshot.error is HomeServiceException
                                  ? (snapshot.error! as HomeServiceException)
                                        .message
                                  : '목표 자격증을 불러오지 못했습니다.',
                            );
                          }

                          final goals = snapshot.data ?? const <HomeGoal>[];

                          if (goals.isEmpty) {
                            return const HomeEmptyGoalCard();
                          }

                          final safeIndex = _currentGoalIndex >= goals.length
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
                  _wrapShowcase(
                    key: widget.todayTodoKey,
                    icon: Icons.checklist_rounded,
                    title: '오늘의 할 일',
                    description: '오늘 해야 할 공부를 체크해보세요!',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        HomeSectionHeader(
                          title: '오늘의 할 일',
                          actionText: '전체보기',
                          onActionPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const StudyPlanScreen(),
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
                                color: Colors.white.withValues(alpha: 0.92),
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
                                ? (snapshot.error! as HomeServiceException)
                                      .message
                                : '오늘의 학습 계획을 불러오지 못했습니다.';

                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 26,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.92),
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

                          final todos = snapshot.data ?? const <HomeTodo>[];

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
                                  SnackBar(content: Text(error.message)),
                                );
                              }
                            },
                          );
                          },
                        ),
                      ],
                    ),
                  ),
                      const SizedBox(height: 32),
                      StreamBuilder<HomeTodayStudySummary>(
                        stream: _todayStudySummaryStream,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                            return _wrapShowcase(
                              key: widget.todayStudyKey,
                              icon: Icons.timer_rounded,
                              title: '오늘 공부 시간',
                              description: '오늘 하루 얼마나 공부했는지 확인할 수 있어요.',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const HomeSectionHeader(title: '오늘 공부 시간'),
                                  const SizedBox(height: 14),
                                  const HomeTodayStudyLoadingCard(),
                                ],
                              ),
                            );
                          }

                          if (snapshot.hasError) {
                            return _wrapShowcase(
                              key: widget.todayStudyKey,
                              icon: Icons.timer_rounded,
                              title: '오늘 공부 시간',
                              description: '오늘 하루 얼마나 공부했는지 확인할 수 있어요.',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const HomeSectionHeader(title: '오늘 공부 시간'),
                                  const SizedBox(height: 14),
                                  HomeTodayStudyErrorCard(
                                    message: snapshot.error is HomeServiceException
                                        ? (snapshot.error! as HomeServiceException).message
                                        : '오늘 공부 기록을 불러오지 못했습니다.',
                                  ),
                                ],
                              ),
                            );
                          }

                          final summary = snapshot.data ?? const HomeTodayStudySummary.empty();

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _wrapShowcase(
                                key: widget.todayStudyKey,
                                icon: Icons.timer_rounded,
                                title: '오늘 공부 시간',
                                description: '오늘 하루 얼마나 공부했는지 확인할 수 있어요.',
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const HomeSectionHeader(title: '오늘 공부 시간'),
                                    const SizedBox(height: 14),
                                    HomeTodayStudyCard(summary: summary),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 32),
                              const HomeSectionHeader(title: '스터디 공부 시간'),
                              const SizedBox(height: 14),
                              HomeStudyGroupStatusCard(studyGroups: summary.studyGroups),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              if (_isRefreshing) const Positioned.fill(child: LoadingOverlay()),
            ],
          ),
        );
      },
    );
  }
}