import 'package:flutter/material.dart';

import '../../widgets/app_main_background.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  static const String routeName = '/admin';

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  String _selectedMenu = '관리자 홈';

  final List<_AdminMenuItem> _operationMenus = const [
    _AdminMenuItem(title: '신고 관리', icon: Icons.report_outlined),
    _AdminMenuItem(title: '문의 관리', icon: Icons.support_agent_outlined),
    _AdminMenuItem(title: '공지 관리', icon: Icons.campaign_outlined),
  ];

  final List<_AdminMenuItem> _serviceMenus = const [
    _AdminMenuItem(title: '회원 관리', icon: Icons.people_outline),
    _AdminMenuItem(
      title: '자격증 관리',
      icon: Icons.workspace_premium_outlined,
    ),
    _AdminMenuItem(
      title: '콘텐츠 관리',
      icon: Icons.dashboard_customize_outlined,
    ),
  ];

  void _changeMenu(String menuTitle) {
    Navigator.pop(context);
    setState(() => _selectedMenu = menuTitle);
  }

  void _openMenu(String menuTitle) {
    setState(() => _selectedMenu = menuTitle);
  }

  void _showLogoutDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('로그아웃'),
          content: const Text('관리자 계정에서 로그아웃하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('로그아웃 기능은 인증 화면 연결 후 적용합니다.'),
                  ),
                );
              },
              child: const Text('로그아웃'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(_selectedMenu),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFF1A1A1A),
        actions: [
          if (_selectedMenu == '관리자 홈')
            IconButton(
              tooltip: '새로고침',
              onPressed: () {
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('운영 현황을 새로고침했습니다.'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
              icon: const Icon(Icons.refresh_rounded),
            ),
        ],
      ),
      drawer: _buildDrawer(),
      body: AppMainBackground(
        child: SafeArea(
          child: _selectedMenu == '관리자 홈'
              ? _buildAdminHome()
              : _buildMenuPlaceholder(_selectedMenu),
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            _buildDrawerHeader(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                children: [
                  _buildDrawerMenuItem(
                    const _AdminMenuItem(
                      title: '관리자 홈',
                      icon: Icons.home_outlined,
                    ),
                  ),
                  const _DrawerSectionTitle(title: '운영 관리'),
                  ..._operationMenus.map(_buildDrawerMenuItem),
                  const _DrawerSectionTitle(title: '서비스 관리'),
                  ..._serviceMenus.map(_buildDrawerMenuItem),
                  const _DrawerSectionTitle(title: '기타'),
                  _buildDrawerMenuItem(
                    const _AdminMenuItem(
                      title: '관리자 로그',
                      icon: Icons.history_outlined,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(
                Icons.logout_rounded,
                color: Color(0xFFD14D4D),
              ),
              title: const Text(
                '로그아웃',
                style: TextStyle(
                  color: Color(0xFFD14D4D),
                  fontWeight: FontWeight.w700,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _showLogoutDialog();
              },
            ),
            const SizedBox(height: 8),
          ],
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '관리자',
                  style: TextStyle(
                    color: Color(0xFF1A1A1A),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '서비스 운영 관리',
                  style: TextStyle(
                    color: Color(0xFF6B6B73),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerMenuItem(_AdminMenuItem item) {
    final bool isSelected = _selectedMenu == item.title;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        selected: isSelected,
        selectedTileColor: const Color(0xFFF1EFFF),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        leading: Icon(
          item.icon,
          color: isSelected
              ? const Color(0xFF5D54D6)
              : const Color(0xFF65656D),
        ),
        title: Text(
          item.title,
          style: TextStyle(
            color: isSelected
                ? const Color(0xFF4038A5)
                : const Color(0xFF29292E),
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, size: 20),
        onTap: () => _changeMenu(item.title),
      ),
    );
  }

  Widget _buildAdminHome() {
    return RefreshIndicator(
      onRefresh: () async => setState(() {}),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
        children: [
          _buildGreetingCard(),
          const SizedBox(height: 20),
          const _SectionHeader(
            title: '오늘 처리할 항목',
            subtitle: '운영에 필요한 핵심 업무만 모았습니다.',
          ),
          const SizedBox(height: 12),
          _buildSummaryGrid(),
          const SizedBox(height: 24),
          _buildQuickTaskSection(),
          const SizedBox(height: 24),
          _buildQuickManagementSection(),
          const SizedBox(height: 24),
          _buildRecentAdminLogSection(),
        ],
      ),
    );
  }

  Widget _buildGreetingCard() {
    final DateTime now = DateTime.now();
    const List<String> weekDays = [
      '월요일',
      '화요일',
      '수요일',
      '목요일',
      '금요일',
      '토요일',
      '일요일',
    ];

    final String dateText =
        '${now.year}년 ${now.month}월 ${now.day}일 ${weekDays[now.weekday - 1]}';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF0EDFF), Color(0xFFFDFBFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE4DFFF)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFF6C63FF),
              borderRadius: BorderRadius.circular(17),
            ),
            child: const Icon(
              Icons.admin_panel_settings_rounded,
              color: Colors.white,
              size: 29,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '안녕하세요, 관리자님',
                  style: TextStyle(
                    color: Color(0xFF1F1D2B),
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  '오늘 처리할 운영 현황입니다.',
                  style: TextStyle(
                    color: Color(0xFF666270),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  dateText,
                  style: const TextStyle(
                    color: Color(0xFF514A8D),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryGrid() {
    final List<_SummaryData> summaries = [
      const _SummaryData(
        title: '처리 대기 신고',
        value: '0건',
        icon: Icons.report_gmailerrorred_outlined,
        backgroundColor: Color(0xFFFFF0EF),
        iconColor: Color(0xFFD95B52),
        targetMenu: '신고 관리',
      ),
      const _SummaryData(
        title: '답변 대기 문의',
        value: '0건',
        icon: Icons.mark_unread_chat_alt_outlined,
        backgroundColor: Color(0xFFFFF7E7),
        iconColor: Color(0xFFD58A20),
        targetMenu: '문의 관리',
      ),
      const _SummaryData(
        title: '탈퇴 대기 회원',
        value: '0명',
        icon: Icons.person_off_outlined,
        backgroundColor: Color(0xFFF1F5FF),
        iconColor: Color(0xFF5274C9),
        targetMenu: '회원 관리',
      ),
      const _SummaryData(
        title: '게시 중인 공지',
        value: '0건',
        icon: Icons.campaign_outlined,
        backgroundColor: Color(0xFFF0F9F3),
        iconColor: Color(0xFF3D9960),
        targetMenu: '공지 관리',
      ),
    ];

    return GridView.builder(
      itemCount: summaries.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.18,
      ),
      itemBuilder: (context, index) {
        final _SummaryData data = summaries[index];

        return InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _openMenu(data.targetMenu),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: data.backgroundColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: data.iconColor.withOpacity(0.14),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 39,
                  height: 39,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.82),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(data.icon, color: data.iconColor, size: 23),
                ),
                const Spacer(),
                Text(
                  data.value,
                  style: const TextStyle(
                    color: Color(0xFF1B1B20),
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  data.title,
                  style: const TextStyle(
                    color: Color(0xFF5E5E66),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickTaskSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          title: '빠른 처리',
          subtitle: '최근 접수된 신고와 문의를 확인합니다.',
        ),
        const SizedBox(height: 12),
        _buildEmptySectionCard(
          icon: Icons.task_alt_rounded,
          title: '현재 처리할 업무가 없습니다.',
          description: '새로운 신고나 문의가 접수되면 이곳에 표시됩니다.',
        ),
      ],
    );
  }

  Widget _buildQuickManagementSection() {
    final List<_QuickMenuData> menus = [
      const _QuickMenuData(
        title: '공지 등록',
        icon: Icons.add_alert_outlined,
        targetMenu: '공지 관리',
      ),
      const _QuickMenuData(
        title: '자격증 등록',
        icon: Icons.workspace_premium_outlined,
        targetMenu: '자격증 관리',
      ),
      const _QuickMenuData(
        title: '일정 등록',
        icon: Icons.event_available_outlined,
        targetMenu: '자격증 관리',
      ),
      const _QuickMenuData(
        title: '회원 검색',
        icon: Icons.person_search_outlined,
        targetMenu: '회원 관리',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          title: '빠른 관리',
          subtitle: '자주 사용하는 관리 기능으로 바로 이동합니다.',
        ),
        const SizedBox(height: 12),
        GridView.builder(
          itemCount: menus.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.55,
          ),
          itemBuilder: (context, index) {
            final _QuickMenuData menu = menus[index];

            return OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF4038A5),
                backgroundColor: Colors.white.withOpacity(0.92),
                side: const BorderSide(color: Color(0xFFE2DEF5)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () => _openMenu(menu.targetMenu),
              icon: Icon(menu.icon, size: 21),
              label: Text(
                menu.title,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildRecentAdminLogSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: _SectionHeader(
                title: '최근 관리 기록',
                subtitle: '최근 처리한 관리자 작업입니다.',
              ),
            ),
            TextButton(
              onPressed: () => _openMenu('관리자 로그'),
              child: const Text('전체 보기'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildEmptySectionCard(
          icon: Icons.history_toggle_off_rounded,
          title: '아직 관리 기록이 없습니다.',
          description: '신고 처리, 문의 답변 등의 작업이 이곳에 표시됩니다.',
        ),
      ],
    );
  }

  Widget _buildEmptySectionCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE9E7EF)),
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF2F0F8),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: const Color(0xFF777382)),
          ),
          const SizedBox(height: 13),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF29282E),
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF77747D),
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuPlaceholder(String menuTitle) {
    final _AdminMenuItem menu = _findMenu(menuTitle);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 440),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.94),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE8E5EE)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0EDFF),
                  borderRadius: BorderRadius.circular(21),
                ),
                child: Icon(
                  menu.icon,
                  color: const Color(0xFF5D54D6),
                  size: 34,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                menuTitle,
                style: const TextStyle(
                  color: Color(0xFF1A1A1A),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _getMenuDescription(menuTitle),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF6E6A76),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF6259DA),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$menuTitle 화면은 DB 연결 단계에서 구현합니다.'),
                    ),
                  );
                },
                icon: const Icon(Icons.storage_outlined),
                label: const Text(
                  'DB 연결 예정',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _AdminMenuItem _findMenu(String title) {
    final List<_AdminMenuItem> allMenus = [
      const _AdminMenuItem(
        title: '관리자 홈',
        icon: Icons.home_outlined,
      ),
      ..._operationMenus,
      ..._serviceMenus,
      const _AdminMenuItem(
        title: '관리자 로그',
        icon: Icons.history_outlined,
      ),
    ];

    return allMenus.firstWhere(
          (menu) => menu.title == title,
      orElse: () => const _AdminMenuItem(
        title: '관리자 메뉴',
        icon: Icons.admin_panel_settings_outlined,
      ),
    );
  }

  String _getMenuDescription(String title) {
    switch (title) {
      case '신고 관리':
        return '접수된 신고를 확인하고 게시글 숨김, 사용자 경고 등 필요한 조치를 처리합니다.';
      case '문의 관리':
        return '사용자가 등록한 문의를 확인하고 답변 상태와 처리 결과를 관리합니다.';
      case '공지 관리':
        return '전체 사용자에게 보여줄 공지사항을 등록하고 게시 상태를 관리합니다.';
      case '회원 관리':
        return '회원 정보를 조회하고 정상, 정지, 탈퇴 대기 등의 상태를 관리합니다.';
      case '자격증 관리':
        return '자격증 기본 정보와 시험 회차 및 접수·시험 일정을 등록하고 수정합니다.';
      case '콘텐츠 관리':
        return '게시글, 댓글, 스터디 등 서비스 콘텐츠의 상태를 확인하고 관리합니다.';
      case '관리자 로그':
        return '관리자가 수행한 신고 처리, 문의 답변, 회원 상태 변경 기록을 확인합니다.';
      default:
        return '관리자 기능을 확인하고 서비스 운영에 필요한 작업을 처리합니다.';
    }
  }
}

class _AdminMenuItem {
  const _AdminMenuItem({required this.title, required this.icon});

  final String title;
  final IconData icon;
}

class _SummaryData {
  const _SummaryData({
    required this.title,
    required this.value,
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
    required this.targetMenu,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  final String targetMenu;
}

class _QuickMenuData {
  const _QuickMenuData({
    required this.title,
    required this.icon,
    required this.targetMenu,
  });

  final String title;
  final IconData icon;
  final String targetMenu;
}

class _DrawerSectionTitle extends StatelessWidget {
  const _DrawerSectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 20, 14, 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF929099),
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF202026),
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            color: Color(0xFF77747D),
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
