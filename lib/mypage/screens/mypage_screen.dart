import 'package:flutter/material.dart';

import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_main_background.dart';
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
import 'mypage_calendar_screen.dart';
import 'friend_screen.dart';
import 'app_setting_screen.dart';
import 'help_and_inquiry_screen.dart';
import 'account_withdrawal_screen.dart';

class MyPageScreen extends StatelessWidget {
  const MyPageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppTopBar 뒤까지 배경이 이어지도록 설정
      extendBodyBehindAppBar: true,

      appBar: AppTopBar(
        title: '마이페이지',
      ),

      body: AppMainBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            20,
            16,
            20,
            110,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildProfileCard(context),
              const SizedBox(height: 16),

              MyPageSummaryCard(
                studyMinutes: 320,
                studyGroupCount: 2,
                postCount: 5,
                onStudyTap: () {
                  _openPage(
                    context,
                    const StudyRecordScreen(),
                  );
                },
                onGroupTap: () {
                  _openPage(
                    context,
                    const JoinedStudyScreen(),
                  );
                },
                onPostTap: () {
                  _openPage(
                    context,
                    const MyPostsScreen(),
                  );
                },
              ),
              const SizedBox(height: 24),

              const _SectionTitle(title: '나의 학습'),
              const SizedBox(height: 12),

              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    MyPageMenuTile(
                      icon: Icons.flag_outlined,
                      title: '목표 자격증 관리',
                      subtitle: '준비 중인 자격증과 시험일을 관리합니다.',
                      onTap: () {
                        _openPage(
                          context,
                          const GoalCertificateScreen(),
                        );
                      },
                    ),
                    const _MenuDivider(),

                    MyPageMenuTile(
                      icon: Icons.calendar_month_outlined,
                      title: '캘린더',
                      subtitle: '시험 일정과 학습 계획을 날짜별로 확인합니다.',
                      onTap: () {
                        _openPage(
                          context,
                          const MyPageCalendarScreen(),
                        );
                      },
                    ),
                    const _MenuDivider(),
                    MyPageMenuTile(
                      icon: Icons.bar_chart_outlined,
                      title: '학습 기록',
                      subtitle: '공부 시간과 학습 통계를 확인합니다.',
                      onTap: () {
                        _openPage(
                          context,
                          const StudyRecordScreen(),
                        );
                      },
                    ),
                    const _MenuDivider(),
                    MyPageMenuTile(
                      icon: Icons.checklist_outlined,
                      title: '학습 계획',
                      subtitle: 'AI 학습 계획과 오늘의 할 일을 확인합니다.',
                      onTap: () {
                        _openPage(
                          context,
                          const StudyPlanScreen(),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              const _SectionTitle(title: '나의 활동'),
              const SizedBox(height: 12),

              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    MyPageMenuTile(
                      icon: Icons.article_outlined,
                      title: '내가 쓴 글',
                      subtitle: '작성한 게시글을 확인합니다.',
                      onTap: () {
                        _openPage(
                          context,
                          const MyPostsScreen(),
                        );
                      },
                    ),
                    const _MenuDivider(),
                    MyPageMenuTile(
                      icon: Icons.chat_bubble_outline,
                      title: '내가 쓴 댓글',
                      subtitle: '작성한 댓글을 확인합니다.',
                      onTap: () {
                        _openPage(
                          context,
                          const MyCommentsScreen(),
                        );
                      },
                    ),
                    const _MenuDivider(),
                    MyPageMenuTile(
                      icon: Icons.bookmark_border,
                      title: '북마크',
                      subtitle: '저장한 게시글을 확인합니다.',
                      onTap: () {
                        _openPage(
                          context,
                          const BookmarkScreen(),
                        );
                      },
                    ),
                    const _MenuDivider(),
                    MyPageMenuTile(
                      icon: Icons.people_outline,
                      title: '친구',
                      subtitle: '친구를 검색하고 친구 목록을 확인합니다.',
                      onTap: () {
                        _openPage(
                          context,
                          const FriendScreen(),
                        );
                      },
                    ),
                    const _MenuDivider(),
                    MyPageMenuTile(
                      icon: Icons.groups_outlined,
                      title: '참여 중인 스터디',
                      subtitle: '가입한 스터디 그룹을 확인합니다.',
                      onTap: () {
                        _openPage(
                          context,
                          const JoinedStudyScreen(),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              const _SectionTitle(title: '계정 및 설정'),
              const SizedBox(height: 12),

              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    MyPageMenuTile(
                      icon: Icons.person_outline,
                      title: '내 정보 관리',
                      subtitle: '닉네임, 프로필 이미지 등을 변경합니다.',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                            const ProfileEditScreen(),
                          ),
                        );
                      },
                    ),
                    const _MenuDivider(),
                    MyPageMenuTile(
                      icon: Icons.lock_outline,
                      title: '비밀번호 변경',
                      subtitle: '현재 비밀번호를 확인하고 변경합니다.',
                      onTap: () {
                        _openPage(
                          context,
                          const PasswordChangeScreen(),
                        );
                      },
                    ),
                    const _MenuDivider(),
                    MyPageMenuTile(
                      icon: Icons.settings_outlined,
                      title: '설정',
                      subtitle: '화면 표시와 알림 수신 여부를 설정합니다.',
                      onTap: () {
                        _openPage(
                          context,
                          const AppSettingScreen(),
                        );
                      },
                    ),
                    const _MenuDivider(),
                    MyPageMenuTile(
                      icon: Icons.help_outline,
                      title: '문의 및 도움말',
                      subtitle: '문의 내역과 자주 묻는 질문을 확인합니다.',
                      onTap: () {
                        _openPage(
                          context,
                          const HelpAndInquiryScreen(),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              AppButton(
                text: '로그아웃',
                type: AppButtonType.outlinePink,
                onPressed: () {
                  _showLogoutDialog(context);
                },
              ),

              const SizedBox(height: 12),

              TextButton(
                onPressed: () {
                  _openPage(
                    context,
                    const AccountWithdrawalScreen(),
                  );
                },
                child: const Text(
                  '회원 탈퇴',
                  style: TextStyle(
                    color: Color(0xFF9AA0AC),
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
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
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFFFFF),
            Color(0xFFFFF8FA),
            Color(0xFFFFF2F6),
          ],
        ),
        border: Border.all(
          color: const Color(0xFFFFE8EE),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF0788F).withValues(
              alpha: 0.13,
            ),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // 왼쪽 연한 원 장식
          Positioned(
            left: -38,
            top: 82,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFCE1E8).withValues(
                  alpha: 0.45,
                ),
              ),
            ),
          ),

          // 오른쪽 큰 원 장식
          Positioned(
            right: -48,
            top: 70,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFCE1E8).withValues(
                  alpha: 0.35,
                ),
              ),
            ),
          ),

          // 오른쪽 작은 원 장식
          Positioned(
            right: 74,
            top: 175,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFF8BFCB).withValues(
                  alpha: 0.22,
                ),
              ),
            ),
          ),

          // 왼쪽 반짝이 장식
          const Positioned(
            left: 76,
            top: 62,
            child: Icon(
              Icons.auto_awesome,
              size: 18,
              color: Color(0xFFF7A3B5),
            ),
          ),

          // 오른쪽 반짝이 장식
          const Positioned(
            right: 78,
            top: 58,
            child: Icon(
              Icons.auto_awesome,
              size: 18,
              color: Color(0xFFF7A3B5),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(
              24,
              28,
              24,
              26,
            ),
            child: Column(
              children: [
                // 프로필 이미지
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 104,
                      height: 104,
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(
                          color: const Color(0xFFFFDCE4),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFF0788F)
                                .withValues(
                              alpha: 0.18,
                            ),
                            blurRadius: 18,
                            offset: const Offset(0, 7),
                          ),
                        ],
                      ),
                      child: Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFFFFE8EE),
                              Color(0xFFFFF6F8),
                            ],
                          ),
                        ),
                        child: const Icon(
                          Icons.person,
                          size: 58,
                          color: Color(0xFFF0788F),
                        ),
                      ),
                    ),

                    // 카메라 버튼
                    Positioned(
                      right: -3,
                      bottom: 0,
                      child: GestureDetector(
                        onTap: () {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(
                            const SnackBar(
                              content: Text(
                                '프로필 이미지 변경 기능은 추후 연결합니다.',
                              ),
                            ),
                          );
                        },
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFF0788F),
                            border: Border.all(
                              color: Colors.white,
                              width: 2.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFF0788F)
                                    .withValues(
                                  alpha: 0.28,
                                ),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.camera_alt_outlined,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // 닉네임
                const Text(
                  '밤티라미수',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A1A),
                  ),
                ),

                const SizedBox(height: 7),

                // bio 자기소개
                const Text(
                  '먹고싶다',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: Color(0xFF777B84),
                  ),
                ),

                const SizedBox(height: 18),

                // 목표 자격증 칩
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(
                      alpha: 0.82,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0xFFFFD5DF),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF0788F)
                            .withValues(
                          alpha: 0.08,
                        ),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.track_changes_outlined,
                        size: 20,
                        color: Color(0xFFF0788F),
                      ),
                      SizedBox(width: 8),
                      Text(
                        '목표 자격증',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF44474E),
                        ),
                      ),
                      SizedBox(width: 5),
                      Text(
                        '·',
                        style: TextStyle(
                          color: Color(0xFFB5B7BE),
                        ),
                      ),
                      SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          '정보처리기사',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFF0788F),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                // 입체적인 프로필 수정 버튼
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                        const ProfileEditScreen(),
                      ),
                    );
                  },
                  child: Container(
                    width: 230,
                    height: 54,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFFFF9BB0),
                          Color(0xFFF76F8D),
                          Color(0xFFF25778),
                        ],
                      ),
                      border: Border.all(
                        color: const Color(0xFFFFB4C3),
                        width: 1.5,
                      ),
                      boxShadow: [
                        // 버튼 아래쪽 진한 그림자
                        BoxShadow(
                          color: const Color(0xFFE5496B)
                              .withValues(
                            alpha: 0.42,
                          ),
                          blurRadius: 13,
                          offset: const Offset(0, 8),
                        ),

                        // 주변에 퍼지는 연한 핑크 그림자
                        BoxShadow(
                          color: const Color(0xFFF0788F)
                              .withValues(
                            alpha: 0.20,
                          ),
                          blurRadius: 22,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // 버튼 위쪽 빛 반사
                        Positioned(
                          top: 2,
                          left: 18,
                          right: 18,
                          child: Container(
                            height: 14,
                            decoration: BoxDecoration(
                              borderRadius:
                              BorderRadius.circular(20),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.white.withValues(
                                    alpha: 0.42,
                                  ),
                                  Colors.white.withValues(
                                    alpha: 0,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '프로필 수정',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  shadows: [
                                    Shadow(
                                      color: Color(0x55000000),
                                      offset: Offset(0, 1),
                                      blurRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(
                                Icons.edit_outlined,
                                size: 18,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static void _openPage(
      BuildContext context,
      Widget page,
      ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => page,
      ),
    );
  }

  static void _showLogoutDialog(
      BuildContext context,
      ) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text(
            '로그아웃',
            style: TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
          content: const Text(
            '현재 계정에서 로그아웃하시겠습니까?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text(
                '취소',
                style: TextStyle(
                  color: Color(0xFF9AA0AC),
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext);

                // 나중에 Firebase Auth 연결
                // await FirebaseAuth.instance.signOut();

                if (!context.mounted) {
                  return;
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      '로그아웃 기능은 Firebase 연결 후 적용됩니다.',
                    ),
                  ),
                );
              },
              child: const Text(
                '로그아웃',
                style: TextStyle(
                  color: Color(0xFFF0788F),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MenuDivider extends StatelessWidget {
  const _MenuDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      indent: 74,
      endIndent: 18,
      color: Color(0xFFF0F0F2),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: Color(0xFF1A1A1A),
      ),
    );
  }
}