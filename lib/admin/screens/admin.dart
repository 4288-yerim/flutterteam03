import 'package:flutter/material.dart';

import '../../auth/screens/welcome_screen.dart';
import '../../auth/services/auth_service.dart';
import '../../widgets/app_confirm_dialog.dart';
import '../../widgets/app_main_background.dart';
import 'admin_home_screen.dart';
import 'study_management_screen.dart';
import 'certificate_management_screen.dart';
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

  List<Widget> _buildScreens() {
    return [
      AdminHomeScreen(
        onReportTap: () => _openMenu(3),
        onInquiryTap: () => _openMenu(4),
      ),
      const MemberManagementScreen(),
      const CertificateManagementScreen(),
      const ReportManagementScreen(),
      const InquiryManagementScreen(),
      const NoticeManagementScreen(),
      const AiUsageLogManagementScreen(),
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
                style: const TextStyle(
                  color: Color(0xFF1A1A1A),
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              centerTitle: true,
              elevation: 0,
              scrolledUnderElevation: 0,
              backgroundColor: Colors.transparent,
              foregroundColor: const Color(0xFF1A1A1A),
              surfaceTintColor: Colors.transparent,
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
                              selectedTileColor: const Color(0xFFF1EFFF),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              leading: Icon(
                                menu.icon,
                                color: isSelected
                                    ? const Color(0xFF5D54D6)
                                    : const Color(0xFF65656D),
                              ),
                              title: Text(
                                menu.title,
                                style: TextStyle(
                                  color: isSelected
                                      ? const Color(0xFF4038A5)
                                      : const Color(0xFF29292E),
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
                      leading: _isSigningOut
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFFD14D4D),
                              ),
                            )
                          : const Icon(
                              Icons.logout_rounded,
                              color: Color(0xFFD14D4D),
                            ),
                      title: Text(
                        _isSigningOut ? '로그아웃 중...' : '로그아웃',
                        style: const TextStyle(
                          color: Color(0xFFD14D4D),
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
            const Positioned.fill(
              child: ModalBarrier(dismissible: false, color: Color(0x73000000)),
            ),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 24,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xFFD14D4D)),
                    SizedBox(height: 18),
                    Text(
                      '로그아웃 중...',
                      style: TextStyle(
                        color: Color(0xFF29292E),
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
      color: const Color(0xFFF4F1FF),
      child: const Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: Color(0xFF6C63FF),
            child: Icon(
              Icons.admin_panel_settings_outlined,
              color: Colors.white,
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
                style: TextStyle(color: Color(0xFF6B6B73), fontSize: 13),
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
