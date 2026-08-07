import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../community/community_post_detail.dart';
import '../../mypage/screens/friend_screen.dart';
import '../../mypage/screens/study_plan_screen.dart';
import '../../study/study_chat.dart';
import '../../study/study_join_requests.dart';
import '../../study/study_room.dart';
import '../../theme.dart';
import '../../widgets/app_main_background.dart';
import '../../widgets/app_top_bar.dart';
import '../services/notification_service.dart';
import '../widgets/notification_widgets.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key, this.notificationService});

  final NotificationService? notificationService;

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  late final NotificationService _service;

  @override
  void initState() {
    super.initState();
    _service = widget.notificationService ?? NotificationService();
    unawaited(_markNotificationsViewed());
  }

  Future<void> _markNotificationsViewed() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    try {
      await _service.markNotificationsViewed(user.uid);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return DefaultTabController(
      length: NotificationSection.values.length,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: const AppTopBar(title: '알림'),
        body: AppMainBackground(
          child: user == null
              ? const NotificationMessageView(
                  icon: Icons.login_rounded,
                  title: '로그인이 필요합니다.',
                  description: '로그인하면 알림을 확인할 수 있습니다.',
                )
              : Column(
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: TabBar(
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        labelColor: context.colors.pinkDeep,
                        unselectedLabelColor: context.colors.textSecondary,
                        indicatorColor: context.colors.pinkDeep,
                        dividerColor: context.colors.divider,
                        tabs: NotificationSection.values
                            .map((section) => Tab(text: section.label))
                            .toList(growable: false),
                      ),
                    ),
                    Expanded(
                      child: StreamBuilder<List<AppNotification>>(
                        stream: _service.watchNotifications(user.uid),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return const NotificationMessageView(
                              icon: Icons.error_outline_rounded,
                              title: '알림을 불러오지 못했습니다.',
                              description: '잠시 후 다시 시도해 주세요.',
                            );
                          }

                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return Center(
                              child: CircularProgressIndicator(
                                color: context.colors.pinkDeep,
                              ),
                            );
                          }

                          final notifications =
                              snapshot.data ?? const <AppNotification>[];

                          return TabBarView(
                            children: NotificationSection.values
                                .map(
                                  (section) => _buildSection(
                                    context,
                                    notifications,
                                    section,
                                  ),
                                )
                                .toList(growable: false),
                          );
                        },
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    List<AppNotification> notifications,
    NotificationSection section,
  ) {
    final filtered = section == NotificationSection.all
        ? notifications
        : notifications
              .where((notification) => notification.section == section)
              .toList(growable: false);

    if (filtered.isEmpty) {
      return const NotificationEmptyView();
    }

    return NotificationList(
      notifications: filtered,
      onNotificationPressed: (notification) =>
          _openNotification(context, notification),
    );
  }

  void _openNotification(BuildContext context, AppNotification notification) {
    if (notification.refType == 'FRIENDS') {
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const FriendScreen()));
      return;
    }

    if (notification.refType == 'COMMUNITY_POST') {
      final postId = notification.postId;
      if (postId == null || postId.isEmpty) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CommunityPostDetailPage(postId: postId),
        ),
      );
      return;
    }

    if (notification.refType == 'STUDY_PLAN') {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => StudyPlanScreen(
            initialDate: notification.planDate ?? DateTime.now(),
          ),
        ),
      );
      return;
    }

    final studyId = notification.studyId;
    if (studyId == null || studyId.isEmpty) return;

    final groupName = notification.groupName ?? '스터디';
    final Widget destination;
    switch (notification.refType) {
      case 'STUDY_JOIN_REQUESTS':
        destination = StudyJoinRequestsPage(studyId: studyId);
      case 'STUDY_CHAT':
        destination = StudyChatPage(studyId: studyId, groupName: groupName);
      case 'STUDY_ROOM':
        destination = StudyRoomPage(studyId: studyId, groupName: groupName);
      default:
        return;
    }

    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => destination));
  }
}
