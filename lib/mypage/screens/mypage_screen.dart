import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../notification/screens/notification.dart';
import '../../notification/widgets/notification_bell_button.dart';
import '../../widgets/app_confirm_dialog.dart';
import '../../auth/screens/welcome_screen.dart';
import '../../auth/services/auth_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_main_background.dart';
import '../../widgets/app_loading_dialog.dart';
import '../../widgets/app_top_bar.dart';
import 'profile_edit_screen.dart';
import 'goal_certificate_screen.dart';
import '../widgets/mypage_menu_tile.dart';
import '../widgets/mypage_summary_card.dart';
import 'study_record_screen.dart';
import 'study_plan_screen.dart';
import 'my_posts_screen.dart';
import 'joined_study_screen.dart';
import 'password_change_screen.dart';
import 'my_comments_screen.dart';
import 'bookmark_screen.dart';
import 'liked_content_screen.dart';
import 'mypage_calendar_screen.dart';
import 'friend_screen.dart';
import 'app_setting_screen.dart';
import 'help_and_inquiry_screen.dart';
import 'account_withdrawal_screen.dart';
import 'my_certificate_roadmap_screen.dart';
import '../../ai/subscription.dart';

class MyPageScreen extends StatefulWidget {
  const MyPageScreen({super.key});

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  String _nickname = '불러오는 중...';
  String _bio = '';
  String _targetCertificateName = '등록된 목표 없음';
  String? _profileImageUrl;
  bool _isLoadingProfile = true;
  int _weeklyStudySeconds = 0;
  int _joinedStudyCount = 0;
  int _postCount = 0;
  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    _loadMyPageData();
    _loadSummaryData();
  }

  Future<void> _loadSummaryData() async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (!mounted) {
        return;
      }

      setState(() {
        _weeklyStudySeconds = 0;
        _joinedStudyCount = 0;
        _postCount = 0;
      });
      return;
    }

    int weeklyStudySeconds = _weeklyStudySeconds;
    int joinedStudyCount = _joinedStudyCount;
    int postCount = _postCount;
    bool hasLoadError = false;

    try {
      weeklyStudySeconds = await _loadWeeklyStudySeconds(user.uid);
    } catch (error) {
      hasLoadError = true;
    }

    try {
      joinedStudyCount = await _loadJoinedStudyCount(user.uid);
    } catch (error) {
      hasLoadError = true;
    }

    try {
      postCount = await _loadMyPostCount(user.uid);
    } catch (error) {
      hasLoadError = true;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _weeklyStudySeconds = weeklyStudySeconds;
      _joinedStudyCount = joinedStudyCount;
      _postCount = postCount;
    });

    if (hasLoadError) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('마이페이지 요약 정보를 일부 불러오지 못했습니다.')));
    }
  }

  Future<int> _loadWeeklyStudySeconds(String uid) async {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);

    final DateTime monday = today.subtract(
      Duration(days: today.weekday - DateTime.monday),
    );

    int totalSeconds = 0;
    final int elapsedDayCount = today.weekday - DateTime.monday + 1;

    for (int dayIndex = 0; dayIndex < elapsedDayCount; dayIndex++) {
      final DateTime date = monday.add(Duration(days: dayIndex));

      final DocumentSnapshot<Map<String, dynamic>> document =
          await FirebaseFirestore.instance
              .collection('userStudyLogs')
              .doc(uid)
              .collection('logs')
              .doc(_formatDateId(date))
              .get();

      final Map<String, dynamic>? data = document.data();

      if (data == null) {
        continue;
      }

      final int? savedTotalSeconds = (data['totalSeconds'] as num?)?.toInt();

      if (savedTotalSeconds != null) {
        totalSeconds += savedTotalSeconds;
      } else {
        final int savedTotalMinutes =
            (data['totalMinutes'] as num?)?.toInt() ?? 0;
        totalSeconds += savedTotalMinutes * 60;
      }
    }

    final QuerySnapshot<Map<String, dynamic>> groupSnapshot =
        await FirebaseFirestore.instance.collection('studyGroups').get();

    final DateTime nextMonday = monday.add(Duration(days: 7));

    for (final QueryDocumentSnapshot<Map<String, dynamic>> groupDocument
        in groupSnapshot.docs) {
      final QuerySnapshot<Map<String, dynamic>> recordSnapshot =
          await groupDocument.reference
              .collection('studyRecords')
              .where('uid', isEqualTo: uid)
              .get();

      for (final QueryDocumentSnapshot<Map<String, dynamic>> recordDocument
          in recordSnapshot.docs) {
        final Map<String, dynamic> data = recordDocument.data();
        final DateTime? studiedAt = _readStudyRecordDate(data);

        if (studiedAt == null ||
            studiedAt.isBefore(monday) ||
            !studiedAt.isBefore(nextMonday)) {
          continue;
        }

        totalSeconds += _readStudyRecordSeconds(data);
      }
    }

    return totalSeconds;
  }

  int _readStudyRecordSeconds(Map<String, dynamic> data) {
    for (final String fieldName in ['studySeconds', 'elapsedSeconds']) {
      final dynamic value = data[fieldName];
      if (value is num) {
        return value.toInt();
      }
    }

    return ((data['studyMinutes'] as num?)?.toInt() ?? 0) * 60;
  }

  DateTime? _readStudyRecordDate(Map<String, dynamic> data) {
    for (final String fieldName in ['endedAt', 'startedAt', 'createdAt']) {
      final dynamic value = data[fieldName];
      if (value is Timestamp) {
        return value.toDate();
      }
    }

    final dynamic studyDate = data['studyDate'];
    return studyDate is String ? DateTime.tryParse(studyDate) : null;
  }

  Future<int> _loadJoinedStudyCount(String uid) async {
    final QuerySnapshot<Map<String, dynamic>> groupSnapshot =
        await FirebaseFirestore.instance.collection('studyGroups').get();

    int joinedStudyCount = 0;

    for (final QueryDocumentSnapshot<Map<String, dynamic>> groupDocument
        in groupSnapshot.docs) {
      final DocumentSnapshot<Map<String, dynamic>> memberDocument =
          await groupDocument.reference.collection('members').doc(uid).get();

      if (!memberDocument.exists) {
        continue;
      }

      final String memberStatus =
          (memberDocument.data()?['status'] as String? ?? 'ACTIVE')
              .trim()
              .toUpperCase();

      if (memberStatus == 'ACTIVE') {
        joinedStudyCount++;
      }
    }

    return joinedStudyCount;
  }

  Future<int> _loadMyPostCount(String uid) async {
    final QuerySnapshot<Map<String, dynamic>> postSnapshot =
        await FirebaseFirestore.instance
            .collection('posts')
            .where('writerUid', isEqualTo: uid)
            .get();

    int postCount = 0;

    for (final QueryDocumentSnapshot<Map<String, dynamic>> document
        in postSnapshot.docs) {
      final Map<String, dynamic> data = document.data();

      final String postStatus = (data['postStatus'] as String? ?? 'NORMAL')
          .trim()
          .toUpperCase();

      final String visibility = (data['visibility'] as String? ?? 'PUBLIC')
          .trim()
          .toUpperCase();

      final dynamic deletedAt = data['deletedAt'];

      if (postStatus != 'NORMAL') {
        continue;
      }

      if (visibility != 'PUBLIC') {
        continue;
      }

      if (deletedAt != null) {
        continue;
      }

      postCount++;
    }

    return postCount;
  }

  String _formatDateId(DateTime date) {
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');

    return '${date.year}-$month-$day';
  }

  Future<void> _loadMyPageData() async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (!mounted) {
        return;
      }

      setState(() {
        _nickname = '로그인이 필요합니다';
        _bio = '';
        _targetCertificateName = '등록된 목표 없음';
        _profileImageUrl = null;
        _isLoadingProfile = false;
      });
      return;
    }

    try {
      final DocumentSnapshot<Map<String, dynamic>> userDocument =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

      final Map<String, dynamic>? userData = userDocument.data();

      String nickname = user.displayName ?? '닉네임 없음';
      String bio = '';
      String targetCertificateName = '등록된 목표 없음';
      String? profileImageUrl;

      if (userData != null) {
        final dynamic savedNickname = userData['nickname'];
        final dynamic savedBio = userData['bio'];
        final dynamic savedProfileImageUrl = userData['profileImageUrl'];

        if (savedNickname is String && savedNickname.trim().isNotEmpty) {
          nickname = savedNickname.trim();
        }

        if (savedBio is String && savedBio.trim().isNotEmpty) {
          bio = savedBio.trim();
        }

        if (savedProfileImageUrl is String &&
            savedProfileImageUrl.trim().isNotEmpty) {
          profileImageUrl = savedProfileImageUrl.trim();
        }

        // isMainGoal이 true인 목표를 대표 목표로 표시합니다.
        final QuerySnapshot<Map<String, dynamic>> mainGoalSnapshot =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('goals')
                .where('isMainGoal', isEqualTo: true)
                .limit(1)
                .get();

        if (mainGoalSnapshot.docs.isNotEmpty) {
          final Map<String, dynamic> mainGoalData = mainGoalSnapshot.docs.first
              .data();

          final String mainCertificateName =
              (mainGoalData['certificateName'] as String? ?? '').trim();

          if (mainCertificateName.isNotEmpty) {
            targetCertificateName = mainCertificateName;
          }
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _nickname = nickname;
        _bio = bio;
        _targetCertificateName = targetCertificateName;
        _profileImageUrl = profileImageUrl;
        _isLoadingProfile = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _nickname = user.displayName ?? '닉네임 없음';
        _bio = '';
        _targetCertificateName = '등록된 목표 없음';
        _profileImageUrl = null;
        _isLoadingProfile = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('마이페이지 정보를 불러오지 못했습니다: $error')));
    }
  }

  Future<void> _openProfileEdit(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProfileEditScreen()),
    );

    // 프로필 수정 화면에서 돌아오면 최신 정보를 다시 조회합니다.
    await _loadMyPageData();
  }

  Future<void> _openGoalCertificate(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GoalCertificateScreen()),
    );

    // 대표 목표를 변경하고 돌아오면 마이페이지를 다시 조회
    await _loadMyPageData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      // AppTopBar 뒤까지 배경이 이어지도록 설정
      extendBodyBehindAppBar: true,

      appBar: AppTopBar(
        title: '마이페이지',
        actions: [
          NotificationBellButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => NotificationPage()),
              );
            },
          ),
        ],
      ),

      body: AppMainBackground(
        child: Stack(
          children: [
            AbsorbPointer(
              absorbing: _isLoggingOut,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildProfileCard(context),
                    SizedBox(height: 16),

                    MyPageSummaryCard(
                      studySeconds: _weeklyStudySeconds,
                      studyGroupCount: _joinedStudyCount,
                      postCount: _postCount,
                      onStudyTap: () async {
                        await _openPageAndRefreshSummary(
                          context,
                          StudyRecordScreen(),
                        );
                      },
                      onGroupTap: () async {
                        await _openPageAndRefreshSummary(
                          context,
                          JoinedStudyScreen(),
                        );
                      },
                      onPostTap: () async {
                        await _openPageAndRefreshSummary(
                          context,
                          MyPostsScreen(),
                        );
                      },
                    ),
                    SizedBox(height: 24),

                    _SectionTitle(title: '나의 학습'),
                    SizedBox(height: 12),

                    AppCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          MyPageMenuTile(
                            icon: Icons.flag_outlined,
                            title: '목표 자격증 관리',
                            subtitle: '준비 중인 자격증과 시험일을 관리합니다.',
                            onTap: () {
                              _openGoalCertificate(context);
                            },
                          ),
                          _MenuDivider(),
                          MyPageMenuTile(
                            icon: Icons.route_outlined,
                            title: '나의 자격증 로드맵',
                            subtitle: '저장한 AI 추천 자격증 취득 순서를 확인합니다.',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => MyCertificateRoadmapScreen(),
                                ),
                              );
                            },
                          ),
                          _MenuDivider(),
                          MyPageMenuTile(
                            icon: Icons.calendar_month_outlined,
                            title: '캘린더',
                            subtitle: '시험 일정과 학습 계획을 날짜별로 확인합니다.',
                            onTap: () {
                              _openPage(context, MyPageCalendarScreen());
                            },
                          ),
                          _MenuDivider(),
                          MyPageMenuTile(
                            icon: Icons.bar_chart_outlined,
                            title: '학습 기록',
                            subtitle: '공부 시간과 학습 통계를 확인합니다.',
                            onTap: () {
                              _openPage(context, StudyRecordScreen());
                            },
                          ),
                          _MenuDivider(),
                          MyPageMenuTile(
                            icon: Icons.checklist_outlined,
                            title: '학습 계획',
                            subtitle: 'AI 학습 계획과 오늘의 할 일을 확인합니다.',
                            onTap: () {
                              _openPage(context, StudyPlanScreen());
                            },
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 24),
                    _SectionTitle(title: '나의 활동'),
                    SizedBox(height: 12),

                    AppCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          MyPageMenuTile(
                            icon: Icons.article_outlined,
                            title: '내가 쓴 글',
                            subtitle: '작성한 게시글을 확인합니다.',
                            onTap: () async {
                              await _openPageAndRefreshSummary(
                                context,
                                MyPostsScreen(),
                              );
                            },
                          ),
                          _MenuDivider(),
                          MyPageMenuTile(
                            icon: Icons.chat_bubble_outline,
                            title: '내가 쓴 댓글',
                            subtitle: '작성한 댓글을 확인합니다.',
                            onTap: () {
                              _openPage(context, MyCommentsScreen());
                            },
                          ),
                          _MenuDivider(),
                          MyPageMenuTile(
                            icon: Icons.favorite_border,
                            title: '좋아요한 콘텐츠',
                            subtitle: '좋아요한 게시글과 댓글을 확인합니다.',
                            onTap: () {
                              _openPage(context, LikedContentScreen());
                            },
                          ),
                          _MenuDivider(),
                          MyPageMenuTile(
                            icon: Icons.bookmark_border,
                            title: '북마크',
                            subtitle: '저장한 게시글을 확인합니다.',
                            onTap: () {
                              _openPage(context, BookmarkScreen());
                            },
                          ),
                          _MenuDivider(),
                          MyPageMenuTile(
                            icon: Icons.people_outline,
                            title: '친구',
                            subtitle: '친구를 검색하고 친구 목록을 확인합니다.',
                            onTap: () {
                              _openPage(context, FriendScreen());
                            },
                          ),
                          _MenuDivider(),
                          MyPageMenuTile(
                            icon: Icons.groups_outlined,
                            title: '참여 중인 스터디',
                            subtitle: '가입한 스터디 그룹을 확인합니다.',
                            onTap: () {
                              _openPage(context, JoinedStudyScreen());
                            },
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 24),
                    _SectionTitle(title: '계정 및 설정'),
                    SizedBox(height: 12),

                    AppCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          MyPageMenuTile(
                            icon: Icons.workspace_premium_outlined,
                            title: '구독 관리',
                            subtitle: 'AI 구독 상태를 확인하고 결제 및 해지를 관리합니다.',
                            onTap: () {
                              _openPage(
                                context,
                                SubscriptionPage(),
                              );
                            },
                          ),
                          _MenuDivider(),
                          MyPageMenuTile(
                            icon: Icons.lock_outline,
                            title: '비밀번호 변경',
                            subtitle: '현재 비밀번호를 확인하고 변경합니다.',
                            onTap: () {
                              _openPage(context, PasswordChangeScreen());
                            },
                          ),
                          _MenuDivider(),
                          MyPageMenuTile(
                            icon: Icons.settings_outlined,
                            title: '설정',
                            subtitle: '화면 표시와 알림 수신 여부를 설정합니다.',
                            onTap: () {
                              _openPage(context, AppSettingScreen());
                            },
                          ),
                          _MenuDivider(),
                          MyPageMenuTile(
                            icon: Icons.help_outline,
                            title: '문의 및 도움말',
                            subtitle: '문의 내역과 자주 묻는 질문을 확인합니다.',
                            onTap: () {
                              _openPage(context, HelpAndInquiryScreen());
                            },
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 24),

                    AppButton(
                      text: '로그아웃',
                      type: AppButtonType.outlinePink,
                      onPressed: () {
                        AppConfirmDialog.show(
                          context,
                          icon: Icons.logout_rounded,
                          title: '로그아웃',
                          description: '현재 계정에서 로그아웃하시겠습니까?',
                          primaryLabel: '로그아웃',
                          secondaryLabel: '취소',
                          onSecondaryPressed: () => Navigator.of(context).pop(),
                          onPrimaryPressed: () async {
                            Navigator.of(context).pop();

                            setState(() {
                              _isLoggingOut = true;
                            });

                            AppLoadingDialog.show(
                              context,
                              title: '로그아웃 중...',
                              description: '잠시만 기다려 주세요.',
                            );

                            try {
                              await AuthService.signOut();

                              if (!context.mounted) {
                                return;
                              }

                              Navigator.of(
                                context,
                                rootNavigator: true,
                              ).pushAndRemoveUntil(
                                MaterialPageRoute(
                                  builder: (_) => WelcomeScreen(),
                                ),
                                (route) => false,
                              );
                            } catch (error) {
                              if (!context.mounted) {
                                return;
                              }
                              AppLoadingDialog.close(context);
                              setState(() {
                                _isLoggingOut = false;
                              });

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '로그아웃에 실패했습니다. 잠시 후 다시 시도해 주세요.',
                                  ),
                                ),
                              );
                            }
                          },
                        );
                      },
                    ),

                    SizedBox(height: 12),

                    TextButton(
                      onPressed: () {
                        _openPage(context, AccountWithdrawalScreen());
                      },
                      child: Text(
                        '회원 탈퇴',
                        style: TextStyle(
                          color: context.colors.textSecondary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_isLoggingOut)
              Positioned.fill(
                child: Container(
                  color: context.colors.shadow,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          color: context.colors.pinkStart,
                        ),
                        SizedBox(height: 16),
                        Text(
                          '로그아웃 중...',
                          style: TextStyle(
                            color: context.colors.onPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            context.colors.surface,
            context.colors.surfaceElevated,
            context.colors.pinkSoftAlt,
          ],
        ),
        border: Border.all(color: context.colors.pinkBorder),
        boxShadow: [
          BoxShadow(
            color: context.colors.pinkStart.withValues(alpha: 0.13),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 28, 24, 26),
        child: Column(
          children: [
            // 프로필 이미지
            Container(
              width: 104,
              height: 104,
              padding: EdgeInsets.all(5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.colors.surface,
                border: Border.all(color: context.colors.pinkBorder, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: context.colors.pinkStart.withValues(alpha: 0.18),
                    blurRadius: 18,
                    offset: Offset(0, 7),
                  ),
                ],
              ),
              child: ClipOval(
                child: _profileImageUrl != null && _profileImageUrl!.isNotEmpty
                    ? Image.network(
                        _profileImageUrl!,
                        width: 94,
                        height: 94,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  context.colors.pinkSoft,
                                  context.colors.surface,
                                ],
                              ),
                            ),
                            child: Icon(
                              Icons.person,
                              size: 58,
                              color: context.colors.pinkStart,
                            ),
                          );
                        },
                      )
                    : Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              context.colors.pinkSoft,
                              context.colors.surface,
                            ],
                          ),
                        ),
                        child: Icon(
                          Icons.person,
                          size: 58,
                          color: context.colors.pinkStart,
                        ),
                      ),
              ),
            ),

            SizedBox(height: 18),

            // 현재 로그인한 사용자의 닉네임
            Text(
              _nickname,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w800,
                color: context.colors.textPrimary,
              ),
            ),

            SizedBox(height: 7),

            // 현재 로그인한 사용자의 자기소개
            Text(
              _isLoadingProfile ? '' : (_bio.isEmpty ? '자기소개가 없습니다.' : _bio),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: context.colors.textSecondary,
              ),
            ),

            SizedBox(height: 18),

            // 목표 자격증 칩
            GestureDetector(
              onTap: () {
                _openGoalCertificate(context);
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                decoration: BoxDecoration(
                  color: context.colors.surface.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: context.colors.pinkBorder),
                  boxShadow: [
                    BoxShadow(
                      color: context.colors.pinkStart.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.track_changes_outlined,
                      size: 20,
                      color: context.colors.pinkStart,
                    ),
                    SizedBox(width: 8),
                    Text(
                      '목표 자격증',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    SizedBox(width: 5),
                    Text(
                      '·',
                      style: TextStyle(color: context.colors.textMuted),
                    ),
                    SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        _targetCertificateName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: context.colors.pinkStart,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 22),

            // 프로필 카드와 어울리는 부드러운 파스텔 버튼
            Container(
              width: 230,
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [context.colors.surface, context.colors.pinkSoftAlt],
                ),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: context.colors.pinkBorder),
                boxShadow: [
                  BoxShadow(
                    color: context.colors.pinkDeep.withValues(alpha: 0.12),
                    blurRadius: 14,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(25),
                child: InkWell(
                  borderRadius: BorderRadius.circular(25),
                  onTap: () => _openProfileEdit(context),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.edit_rounded,
                          size: 18,
                          color: context.colors.pinkDeep,
                        ),
                        SizedBox(width: 8),
                        Text(
                          '프로필 수정',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: context.colors.pinkDeep,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void _openPage(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  Future<void> _openPageAndRefreshSummary(
    BuildContext context,
    Widget page,
  ) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));

    await _loadSummaryData();
  }
}

class _MenuDivider extends StatelessWidget {
  _MenuDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 74,
      endIndent: 18,
      color: context.colors.divider,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: context.colors.textPrimary,
      ),
    );
  }
}
