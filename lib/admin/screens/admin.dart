import 'package:flutter/material.dart';

import '../../widgets/app_main_background.dart';
import 'admin_home_screen.dart';
import 'ai_usage_log_management_screen.dart';
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

  static const List<_AdminMenuItem> _menus = [
    _AdminMenuItem('홈', Icons.home_outlined, AdminHomeScreen()),
    _AdminMenuItem('회원 관리', Icons.people_outline, MemberManagementScreen()),
    _AdminMenuItem(
      '자격증 관리',
      Icons.workspace_premium_outlined,
      CertificateManagementScreen(),
    ),
    _AdminMenuItem('신고 관리', Icons.report_outlined, ReportManagementScreen()),
    _AdminMenuItem(
      '문의 관리',
      Icons.support_agent_outlined,
      InquiryManagementScreen(),
    ),
    _AdminMenuItem('공지 관리', Icons.campaign_outlined, NoticeManagementScreen()),
    _AdminMenuItem(
      'AI 사용 로그 관리',
      Icons.smart_toy_outlined,
      AiUsageLogManagementScreen(),
    ),
    _AdminMenuItem(
      '알림 발송',
      Icons.notifications_active_outlined,
      NotificationSendScreen(),
    ),
    _AdminMenuItem(
      '커뮤니티 관리',
      Icons.forum_outlined,
      CommunityManagementScreen(),
    ),
    _AdminMenuItem(
      '통계 관리',
      Icons.bar_chart_outlined,
      StatisticsManagementScreen(),
    ),
  ];

  void _selectMenu(int index) {
    Navigator.pop(context);
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final _AdminMenuItem selectedMenu = _menus[_selectedIndex];

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(selectedMenu.title),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFF1A1A1A),
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
            ],
          ),
        ),
      ),
      body: AppMainBackground(
        child: SafeArea(
          child: IndexedStack(
            index: _selectedIndex,
            children: _menus.map((menu) => menu.screen).toList(),
          ),
        ),
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
  const _AdminMenuItem(this.title, this.icon, this.screen);

  final String title;
  final IconData icon;
  final Widget screen;
}
