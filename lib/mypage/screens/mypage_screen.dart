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
import 'notification_setting_screen.dart';
import 'password_change_screen.dart';
import 'my_comments_screen.dart';
import 'bookmark_screen.dart';
import 'mypage_calendar_screen.dart';

class MyPageScreen extends StatelessWidget {
  const MyPageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppTopBar 뒤까지 배경이 이어지도록 설정
      extendBodyBehindAppBar: true,

      appBar: AppTopBar(
        title: '마이페이지',
        actions: [
          IconButton(
            tooltip: '설정',
            onPressed: () {
              _openPage(
                context,
                const TemporaryPage(title: '앱 설정'),
              );
            },
            icon: const Icon(
              Icons.settings_outlined,
              color: Color(0xFF1A1A1A),
            ),
          ),
        ],
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
                      icon: Icons.notifications_outlined,
                      title: '알림 설정',
                      subtitle: '시험 일정과 커뮤니티 알림을 설정합니다.',
                      onTap: () {
                        _openPage(
                          context,
                          const NotificationSettingScreen(),
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
                          const TemporaryPage(
                            title: '문의 및 도움말',
                          ),
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
                    const TemporaryPage(
                      title: '회원 탈퇴',
                    ),
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
    return AppCard(
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFFCE1E8),
                ),
                child: const Icon(
                  Icons.person,
                  size: 40,
                  color: Color(0xFFF0788F),
                ),
              ),

              Positioned(
                right: -2,
                bottom: -2,
                child: GestureDetector(
                  onTap: () {
                    // 나중에 프로필 이미지 선택 기능 연결
                  },
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFF0788F),
                      border: Border.all(
                        color: Colors.white,
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.camera_alt_outlined,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(width: 16),

          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '사용자 닉네임',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'user_id',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF9AA0AC),
                  ),
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.workspace_premium_outlined,
                      size: 16,
                      color: Color(0xFFF0788F),
                    ),
                    SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        '목표 자격증: 정보처리기사',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF666A73),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          IconButton(
            tooltip: '내 정보 수정',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ProfileEditScreen(),
                ),
              );
            },
            icon: const Icon(
              Icons.edit_outlined,
              color: Color(0xFF9AA0AC),
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

/// 실제 세부 화면을 만들기 전 사용하는 임시 화면
class TemporaryPage extends StatelessWidget {
  final String title;

  const TemporaryPage({
    super.key,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppTopBar(
        title: title,
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 20,
            color: Color(0xFF1A1A1A),
          ),
        ),
      ),
      body: AppMainBackground(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 56),
            child: Text(
              '$title 화면 준비 중',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF666A73),
              ),
            ),
          ),
        ),
      ),
    );
  }
}