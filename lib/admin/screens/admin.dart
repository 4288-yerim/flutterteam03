import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../theme.dart';

import '../../auth/screens/welcome_screen.dart';
import '../../auth/services/auth_service.dart';
import '../../main_page.dart';
import '../../widgets/app_confirm_dialog.dart';
import '../../widgets/app_main_background.dart';
import '../widgets/admin_theme.dart';
import 'admin_home_screen.dart';
import 'study_management_screen.dart';
import 'certificate_management_screen.dart';
import 'certificate_add_screen.dart';
import 'certificate_category_content_edit_screen.dart';
import 'community_management_screen.dart';
import 'inquiry_management_screen.dart';
import 'member_management_screen.dart';
import 'notification_send_screen.dart';
import 'notice_management_screen.dart';
import 'report_management_screen.dart';
import 'statistics_management_screen.dart';
import 'withdrawal_management_screen.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  static const String routeName = '/admin';

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  int _selectedIndex = 0;
  bool _isSigningOut = false;
  bool _isRedirecting = false;
  late Future<bool> _adminAccessCheck;

  @override
  void initState() {
    super.initState();
    _adminAccessCheck = _hasAdminAccess();
  }

  Future<bool> _hasAdminAccess() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return false;
    }

    final userDocument = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final String role =
        userDocument.data()?['role']?.toString().trim().toUpperCase() ?? '';

    return role == 'ADMIN';
  }

  void _retryAdminAccess() {
    setState(() {
      _isRedirecting = false;
      _adminAccessCheck = _hasAdminAccess();
    });
  }

  void _redirectUnauthorizedUser() {
    if (_isRedirecting) {
      return;
    }
    _isRedirecting = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final destination = FirebaseAuth.instance.currentUser == null
          ? const WelcomeScreen()
          : const MainPage();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => destination),
            (route) => false,
      );
    });
  }

  static const List<_AdminMenuItem> _menus = [
    _AdminMenuItem('홈', Icons.home_outlined),
    _AdminMenuItem('회원 관리', Icons.people_outline),
    _AdminMenuItem('자격증 관리', Icons.workspace_premium_outlined),
    _AdminMenuItem('신고 관리', Icons.report_outlined),
    _AdminMenuItem('문의 관리', Icons.support_agent_outlined),
    _AdminMenuItem('공지 관리', Icons.campaign_outlined),
    _AdminMenuItem('스터디 관리', Icons.groups_rounded),
    _AdminMenuItem('알림 발송', Icons.notifications_active_outlined),
    _AdminMenuItem('커뮤니티 관리', Icons.forum_outlined),
    _AdminMenuItem('통계 관리', Icons.bar_chart_outlined),
    _AdminMenuItem('탈퇴 사유 관리', Icons.person_off_outlined),
  ];

  void _openMenu(int index) {
    setState(() => _selectedIndex = index);
  }

  void _selectMenu(int index) {
    Navigator.pop(context);
    _openMenu(index);
  }

  Future<void> _openUserPage() async {
    // 관리자 드로어 닫기
    Navigator.of(context).pop();

    await Future<void>.delayed(Duration.zero);

    if (!mounted) return;

    // 관리자 페이지를 유지한 채 사용자 화면을 위에 엽니다.
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const MainPage()));
  }

  List<Widget> _buildScreens() {
    return [
      AdminHomeScreen(
        isActive: _selectedIndex == 0,
        onReportTap: () => _openMenu(3),
        onInquiryTap: () => _openMenu(4),
      ),
      const MemberManagementScreen(),
      const CertificateManagementScreen(),
      const ReportManagementScreen(),
      const InquiryManagementScreen(),
      const NoticeManagementScreen(),
      StudyManagementScreen(onReportTap: () => _openMenu(3)),
      const NotificationSendScreen(),
      const CommunityManagementScreen(),
      const StatisticsManagementScreen(),
      const WithdrawalManagementScreen(),
    ];
  }

  Future<void> _signOut(BuildContext context) async {
    bool shouldSignOut = false;

    await AppConfirmDialog.show<void>(
      context,
      icon: Icons.logout_rounded,
      title: '로그아웃',
      description: '현재 계정에서 로그아웃하시겠습니까?',
      primaryLabel: '로그아웃',
      secondaryLabel: '취소',
      accentGradient: LinearGradient(
        colors: [
          Color.lerp(
            context.colors.lavenderAccent,
            context.colors.surface,
            0.18,
          )!,
          context.colors.lavenderAccent,
        ],
      ),
      accentShadowColor: context.colors.lavenderAccent,
      onSecondaryPressed: () => Navigator.of(context).pop(),
      onPrimaryPressed: () {
        shouldSignOut = true;
        Navigator.of(context).pop();
      },
    );

    if (!shouldSignOut || !mounted) {
      return;
    }

    setState(() => _isSigningOut = true);

    try {
      await AuthService.signOut();

      if (!mounted) {
        return;
      }

      Navigator.of(this.context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
            (route) => false,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() => _isSigningOut = false);
      ScaffoldMessenger.of(this.context).showSnackBar(
        const SnackBar(content: Text('로그아웃에 실패했습니다. 잠시 후 다시 시도해 주세요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminTheme(
      child: FutureBuilder<bool>(
        future: _adminAccessCheck,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasError) {
            return _buildAdminAccessError(context);
          }

          if (snapshot.data != true) {
            _redirectUnauthorizedUser();
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          return _buildAdminPage(context);
        },
      ),
    );
  }

  Widget _buildAdminAccessError(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cloud_off_rounded,
                    size: 58,
                    color: context.colors.textMuted,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    '관리자 권한을 확인하지 못했습니다.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    '네트워크 또는 Firestore 권한 설정을 확인한 뒤 '
                        '다시 시도해 주세요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.colors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    onPressed: _retryAdminAccess,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('다시 시도'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _redirectUnauthorizedUser,
                    child: const Text('사용자 화면으로 돌아가기'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAdminPage(BuildContext context) {
    final _AdminMenuItem selectedMenu = _menus[_selectedIndex];

    return PopScope(
      /*
   * 관리자 홈이고 로그아웃 처리 중이 아닐 때만
   * 관리자 페이지 자체에서 나갈 수 있음
   *
   * 하위 관리 메뉴에서는 뒤로가기를 먼저 차단한 뒤
   * onPopInvokedWithResult에서 관리자 홈으로 이동
   */
      canPop: !_isSigningOut && _selectedIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        // 관리자 페이지 자체가 이미 닫힌 경우에는 추가 동작 안함
        if (didPop) {
          return;
        }

        // 로그아웃 처리 중에는 뒤로가기를 무시
        if (_isSigningOut) {
          return;
        }

        // 관리자 하위 메뉴에서 뒤로가기를 누르면 관리자 홈으로 이동
        if (_selectedIndex != 0) {
          setState(() {
            _selectedIndex = 0;
          });
        }
      },
      child: Stack(
        children: [
          Scaffold(
            extendBodyBehindAppBar: true,
            appBar: AppBar(
              title: Text(
                selectedMenu.title,
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              centerTitle: true,
              elevation: 0,
              scrolledUnderElevation: 0,
              backgroundColor: Colors.transparent,
              foregroundColor: context.colors.textPrimary,
              surfaceTintColor: Colors.transparent,
              actions: [
                if (_selectedIndex == 2)
                  IconButton(
                    tooltip: '자격증 안내 수정',
                    icon: const Icon(Icons.edit_note_rounded),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                          const CertificateCategoryContentEditScreen(),
                        ),
                      );
                    },
                  ),
                if (_selectedIndex == 2)
                  IconButton(
                    tooltip: '자격증 추가',
                    icon: const Icon(Icons.add_rounded),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const CertificateAddScreen(),
                        ),
                      );
                    },
                  ),
              ],
            ),
            drawer: Drawer(
              child: SafeArea(
                child: Column(
                  children: [
                    _buildDrawerHeader(),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        itemCount: _menus.length,
                        itemBuilder: (context, index) {
                          final _AdminMenuItem menu = _menus[index];
                          final bool isSelected = index == _selectedIndex;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: ListTile(
                              selected: isSelected,
                              selectedTileColor: context.colors.lavender,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              leading: Icon(
                                menu.icon,
                                color: isSelected
                                    ? context.colors.lavenderAccent
                                    : context.colors.iconSecondary,
                              ),
                              title: Text(
                                menu.title,
                                style: TextStyle(
                                  color: isSelected
                                      ? context.colors.lavenderAccent
                                      : context.colors.textPrimary,
                                  fontWeight: isSelected
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                ),
                              ),
                              onTap: () => _selectMenu(index),
                            ),
                          );
                        },
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      enabled: !_isSigningOut,
                      leading: Icon(
                        Icons.phone_android_rounded,
                        color: context.colors.lavenderAccent,
                      ),
                      title: Text(
                        '일반 사용자 화면',
                        style: TextStyle(
                          color: context.colors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        '사용자 화면을 직접 확인합니다.',
                        style: TextStyle(
                          color: context.colors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      trailing: Icon(
                        Icons.open_in_new_rounded,
                        color: context.colors.iconSecondary,
                        size: 20,
                      ),
                      onTap: _openUserPage,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      enabled: !_isSigningOut,
                      leading: _isSigningOut
                          ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: context.colors.lavenderAccent,
                        ),
                      )
                          : Icon(
                        Icons.logout_rounded,
                        color: context.colors.incorrect,
                      ),
                      title: Text(
                        _isSigningOut ? '로그아웃 중...' : '로그아웃',
                        style: TextStyle(
                          color: context.colors.incorrect,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _signOut(context);
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            body: AppMainBackground(
              child: SafeArea(
                child: IndexedStack(
                  index: _selectedIndex,
                  children: _buildScreens(),
                ),
              ),
            ),
          ),
          if (_isSigningOut) ...[
            Positioned.fill(
              child: ModalBarrier(
                dismissible: false,
                color: context.colors.overlay,
              ),
            ),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 24,
                ),
                decoration: BoxDecoration(
                  color: context.colors.surfaceElevated,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: context.colors.shadow,
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      color: context.colors.lavenderAccent,
                    ),
                    SizedBox(height: 18),
                    Text(
                      '로그아웃 중...',
                      style: TextStyle(
                        color: context.colors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDrawerHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      color: context.colors.lavender,
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: context.colors.lavenderAccent,
            child: Icon(
              Icons.admin_panel_settings_outlined,
              color: context.colors.onPrimary,
              size: 28,
            ),
          ),
          SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '관리자',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 4),
              Text(
                '서비스 운영 관리',
                style: TextStyle(
                  color: context.colors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdminMenuItem {
  const _AdminMenuItem(this.title, this.icon);

  final String title;
  final IconData icon;
}
