import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../theme.dart';

import '../../auth/screens/welcome_screen.dart';
import '../../auth/services/auth_service.dart';
import '../../main_page.dart';
import '../../widgets/app_confirm_dialog.dart';
import '../../widgets/app_main_background.dart';
import 'admin_home_screen.dart';
import 'study_management_screen.dart';
import 'certificate_management_screen.dart';
import 'certificate_add_screen.dart';
import 'community_management_screen.dart';
import 'inquiry_management_screen.dart';
import 'member_management_screen.dart';
import 'notification_send_screen.dart';
import 'notice_management_screen.dart';
import 'report_management_screen.dart';
import 'statistics_management_screen.dart';

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
  late final Future<bool> _adminAccessCheck;

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

    return userDocument.data()?['role'] == 'ADMIN';
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
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const MainPage(),
      ),
    );
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
    ];
  }

  Future<void> _signOut() async {
    bool shouldSignOut = false;

    await AppConfirmDialog.show<void>(
      context,
      icon: Icons.logout_rounded,
      title: '로그아웃',
      description: '현재 계정에서 로그아웃하시겠습니까?',
      primaryLabel: '로그아웃',
      secondaryLabel: '취소',
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

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        (route) => false,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() => _isSigningOut = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그아웃에 실패했습니다. 잠시 후 다시 시도해 주세요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _adminAccessCheck,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.data != true) {
          _redirectUnauthorizedUser();
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return _buildAdminPage();
      },
    );
  }

  Widget _buildAdminPage() {
    final _AdminMenuItem selectedMenu = _menus[_selectedIndex];

    return PopScope(
      canPop: !_isSigningOut,
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
                                color: context.colors.incorrect,
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
                        _signOut();
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
                    CircularProgressIndicator(color: context.colors.incorrect),
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
