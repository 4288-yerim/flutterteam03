import 'package:flutter/material.dart';

import '../../widgets/app_card.dart';
import '../../widgets/app_main_background.dart';
import '../../widgets/app_top_bar.dart';

class AppSettingScreen extends StatefulWidget {
  const AppSettingScreen({super.key});

  @override
  State<AppSettingScreen> createState() =>
      _AppSettingScreenState();
}

class _AppSettingScreenState
    extends State<AppSettingScreen> {
  // Firebase 연결 전 임시 설정값
  //
  // 추후 저장 경로:
  // users/{uid}/settings/app

  // 기존 DB 설계 필드
  String _themeMode = 'SYSTEM';

  bool _pushEnabled = true;
  bool _certificateAlertEnabled = true;
  bool _studyAlertEnabled = true;

  // 공부 알림 세부 설정
  bool _dailyStudyPlanAlertEnabled = true;
  bool _studyStartTimeAlertEnabled = true;
  bool _incompleteStudyAlertEnabled = true;

  bool _communityAlertEnabled = true;
  bool _friendAlertEnabled = true;
  bool _chatsAlertEnabled = true;
  bool _marketingAlertEnabled = false;

  // DB 설계 추가 예정 필드
  String _fontSizeMode = 'MEDIUM';

  bool _applicationStartAlertEnabled = true;
  bool _examD7AlertEnabled = true;
  bool _examDayAlertEnabled = true;
  bool _resultAlertEnabled = true;

  bool _studyGroupAlertEnabled = true;

  // 스터디 알림 세부 설정
  bool _studyNoticeAlertEnabled = true;
  bool _studyJoinApprovalAlertEnabled = true;
  bool _studyNewMemberAlertEnabled = true;
  bool _studyScheduleAlertEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppTopBar(
        title: '설정',
      ),
      body: AppMainBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            20,
            16,
            20,
            40,
          ),
          children: [
            _buildScreenSettingSection(),
            const SizedBox(height: 26),
            _buildNotificationSettingSection(),
            const SizedBox(height: 22),
            _buildTemporaryNotice(),
          ],
        ),
      ),
    );
  }

  Widget _buildScreenSettingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SettingSectionTitle(
          icon: Icons.palette_outlined,
          title: '화면 설정',
          description: '앱 화면의 테마와 글자 크기를 설정합니다.',
        ),
        const SizedBox(height: 12),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _buildThemeModeTile(),
              const _SettingDivider(),
              _buildFontSizeTile(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildThemeModeTile() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        16,
        14,
        16,
        14,
      ),
      child: Row(
        children: [
          const _SettingIcon(
            icon: Icons.brightness_6_outlined,
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  '테마 모드',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '앱의 밝기 모드를 설정합니다.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9AA0AC),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _themeMode,
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(14),
              items: const [
                DropdownMenuItem<String>(
                  value: 'SYSTEM',
                  child: Text('시스템'),
                ),
                DropdownMenuItem<String>(
                  value: 'LIGHT',
                  child: Text('라이트'),
                ),
                DropdownMenuItem<String>(
                  value: 'DARK',
                  child: Text('다크'),
                ),
              ],
              onChanged: (value) {
                if (value == null) {
                  return;
                }

                setState(() {
                  _themeMode = value;
                });

                _showTemporaryMessage(
                  '테마 설정은 Firebase와 앱 전체 테마 연결 후 적용됩니다.',
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFontSizeTile() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        16,
        14,
        16,
        14,
      ),
      child: Row(
        children: [
          const _SettingIcon(
            icon: Icons.text_fields_outlined,
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  '글자 크기',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '앱에서 표시되는 글자 크기를 설정합니다.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9AA0AC),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _fontSizeMode,
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(14),
              items: const [
                DropdownMenuItem<String>(
                  value: 'SMALL',
                  child: Text('작게'),
                ),
                DropdownMenuItem<String>(
                  value: 'MEDIUM',
                  child: Text('보통'),
                ),
                DropdownMenuItem<String>(
                  value: 'LARGE',
                  child: Text('크게'),
                ),
              ],
              onChanged: (value) {
                if (value == null) {
                  return;
                }

                setState(() {
                  _fontSizeMode = value;
                });

                _showTemporaryMessage(
                  '글자 크기는 앱 전체 설정 연결 후 적용됩니다.',
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationSettingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SettingSectionTitle(
          icon: Icons.notifications_outlined,
          title: '알림 설정',
          description: '받고 싶은 알림 종류를 설정합니다.',
        ),
        const SizedBox(height: 12),

        AppCard(
          padding: EdgeInsets.zero,
          child: _SettingSwitchTile(
            icon: Icons.notifications_active_outlined,
            title: '전체 푸시 알림',
            subtitle: '모든 앱 푸시 알림을 허용합니다.',
            value: _pushEnabled,
            isMainSetting: true,
            onChanged: (value) {
              setState(() {
                _pushEnabled = value;
              });
            },
          ),
        ),

        const SizedBox(height: 14),
        _buildCertificateAlertCard(),

        const SizedBox(height: 14),
        _buildStudyAlertCard(),

        const SizedBox(height: 14),
        _buildCommunityAlertCard(),

        const SizedBox(height: 14),
        _buildOtherAlertCard(),
      ],
    );
  }

  Widget _buildCertificateAlertCard() {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          const _NotificationGroupHeader(
            icon: Icons.workspace_premium_outlined,
            title: '자격증 알림',
          ),
          const _SettingDivider(),

          _SettingSwitchTile(
            title: '자격증 일정 알림',
            subtitle: '시험과 원서 접수 관련 알림을 받습니다.',
            value: _certificateAlertEnabled,
            enabled: _pushEnabled,
            onChanged: (value) {
              setState(() {
                _certificateAlertEnabled = value;
              });
            },
          ),

          const _SettingDivider(),

          _SettingSwitchTile(
            title: '접수 시작',
            subtitle: '자격증 원서 접수가 시작되면 알려줍니다.',
            value: _applicationStartAlertEnabled,
            enabled: _pushEnabled &&
                _certificateAlertEnabled,
            isChildSetting: true,
            onChanged: (value) {
              setState(() {
                _applicationStartAlertEnabled = value;
              });
            },
          ),

          const _SettingDivider(),

          _SettingSwitchTile(
            title: '시험 D-7',
            subtitle: '시험일 7일 전에 알려줍니다.',
            value: _examD7AlertEnabled,
            enabled: _pushEnabled &&
                _certificateAlertEnabled,
            isChildSetting: true,
            onChanged: (value) {
              setState(() {
                _examD7AlertEnabled = value;
              });
            },
          ),

          const _SettingDivider(),

          _SettingSwitchTile(
            title: '시험 당일',
            subtitle: '시험 당일 일정을 알려줍니다.',
            value: _examDayAlertEnabled,
            enabled: _pushEnabled &&
                _certificateAlertEnabled,
            isChildSetting: true,
            onChanged: (value) {
              setState(() {
                _examDayAlertEnabled = value;
              });
            },
          ),

          const _SettingDivider(),

          _SettingSwitchTile(
            title: '합격 발표',
            subtitle: '합격 발표일에 알림을 받습니다.',
            value: _resultAlertEnabled,
            enabled: _pushEnabled &&
                _certificateAlertEnabled,
            isChildSetting: true,
            onChanged: (value) {
              setState(() {
                _resultAlertEnabled = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStudyAlertCard() {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          const _NotificationGroupHeader(
            icon: Icons.menu_book_outlined,
            title: '학습 알림',
          ),
          const _SettingDivider(),

          _SettingSwitchTile(
            title: '공부 알림',
            subtitle: '개인 학습 계획과 할 일 알림을 받습니다.',
            value: _studyAlertEnabled,
            enabled: _pushEnabled,
            onChanged: (value) {
              setState(() {
                _studyAlertEnabled = value;
              });
            },
          ),

          const _SettingDivider(),

          _SettingSwitchTile(
            title: '오늘의 학습 계획',
            subtitle: '오늘 진행할 학습 계획을 알려줍니다.',
            value: _dailyStudyPlanAlertEnabled,
            enabled:
            _pushEnabled && _studyAlertEnabled,
            isChildSetting: true,
            onChanged: (value) {
              setState(() {
                _dailyStudyPlanAlertEnabled = value;
              });
            },
          ),

          const _SettingDivider(),

          _SettingSwitchTile(
            title: '공부 시작 시간',
            subtitle: '설정한 공부 시작 시간이 되면 알려줍니다.',
            value: _studyStartTimeAlertEnabled,
            enabled:
            _pushEnabled && _studyAlertEnabled,
            isChildSetting: true,
            onChanged: (value) {
              setState(() {
                _studyStartTimeAlertEnabled = value;
              });
            },
          ),

          const _SettingDivider(),

          _SettingSwitchTile(
            title: '미완료 계획',
            subtitle: '완료하지 않은 학습 계획을 알려줍니다.',
            value: _incompleteStudyAlertEnabled,
            enabled:
            _pushEnabled && _studyAlertEnabled,
            isChildSetting: true,
            onChanged: (value) {
              setState(() {
                _incompleteStudyAlertEnabled = value;
              });
            },
          ),

          const _SettingDivider(),

          _SettingSwitchTile(
            title: '스터디 알림',
            subtitle: '스터디 그룹 관련 알림을 받습니다.',
            value: _studyGroupAlertEnabled,
            enabled: _pushEnabled,
            onChanged: (value) {
              setState(() {
                _studyGroupAlertEnabled = value;
              });
            },
          ),

          const _SettingDivider(),

          _SettingSwitchTile(
            title: '스터디 공지',
            subtitle: '새로운 스터디 공지가 등록되면 알려줍니다.',
            value: _studyNoticeAlertEnabled,
            enabled: _pushEnabled &&
                _studyGroupAlertEnabled,
            isChildSetting: true,
            onChanged: (value) {
              setState(() {
                _studyNoticeAlertEnabled = value;
              });
            },
          ),

          const _SettingDivider(),

          _SettingSwitchTile(
            title: '가입 승인',
            subtitle: '스터디 가입 요청 결과를 알려줍니다.',
            value: _studyJoinApprovalAlertEnabled,
            enabled: _pushEnabled &&
                _studyGroupAlertEnabled,
            isChildSetting: true,
            onChanged: (value) {
              setState(() {
                _studyJoinApprovalAlertEnabled = value;
              });
            },
          ),

          const _SettingDivider(),

          _SettingSwitchTile(
            title: '새 멤버',
            subtitle: '스터디에 새로운 멤버가 참여하면 알려줍니다.',
            value: _studyNewMemberAlertEnabled,
            enabled: _pushEnabled &&
                _studyGroupAlertEnabled,
            isChildSetting: true,
            onChanged: (value) {
              setState(() {
                _studyNewMemberAlertEnabled = value;
              });
            },
          ),

          const _SettingDivider(),

          _SettingSwitchTile(
            title: '스터디 일정',
            subtitle: '등록된 스터디 일정이 가까워지면 알려줍니다.',
            value: _studyScheduleAlertEnabled,
            enabled: _pushEnabled &&
                _studyGroupAlertEnabled,
            isChildSetting: true,
            onChanged: (value) {
              setState(() {
                _studyScheduleAlertEnabled = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCommunityAlertCard() {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          const _NotificationGroupHeader(
            icon: Icons.forum_outlined,
            title: '커뮤니티 및 친구 알림',
          ),
          const _SettingDivider(),

          _SettingSwitchTile(
            title: '커뮤니티 알림',
            subtitle: '게시글의 댓글과 좋아요 알림을 받습니다.',
            value: _communityAlertEnabled,
            enabled: _pushEnabled,
            onChanged: (value) {
              setState(() {
                _communityAlertEnabled = value;
              });
            },
          ),

          const _SettingDivider(),

          _SettingSwitchTile(
            title: '친구 알림',
            subtitle: '친구 요청과 친구 활동 알림을 받습니다.',
            value: _friendAlertEnabled,
            enabled: _pushEnabled,
            onChanged: (value) {
              setState(() {
                _friendAlertEnabled = value;
              });
            },
          ),

          const _SettingDivider(),

          _SettingSwitchTile(
            title: '채팅 알림',
            subtitle: '새로운 채팅 메시지 알림을 받습니다.',
            value: _chatsAlertEnabled,
            enabled: _pushEnabled,
            onChanged: (value) {
              setState(() {
                _chatsAlertEnabled = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOtherAlertCard() {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          const _NotificationGroupHeader(
            icon: Icons.campaign_outlined,
            title: '기타 알림',
          ),
          const _SettingDivider(),

          _SettingSwitchTile(
            title: '마케팅 알림',
            subtitle: '이벤트와 혜택 정보를 받습니다.',
            value: _marketingAlertEnabled,
            enabled: _pushEnabled,
            onChanged: (value) {
              setState(() {
                _marketingAlertEnabled = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTemporaryNotice() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFFE5B2),
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 20,
            color: Color(0xFFE59B2E),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              '현재 설정은 화면 확인용 임시 데이터입니다. '
                  'Firebase 연결 후 users/{uid}/settings/app 문서에 저장됩니다.',
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: Color(0xFF8A6429),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showTemporaryMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }
}

class _SettingSectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _SettingSectionTitle({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFFCEFF3),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(
            icon,
            size: 22,
            color: const Color(0xFFF0788F),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF9AA0AC),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NotificationGroupHeader
    extends StatelessWidget {
  final IconData icon;
  final String title;

  const _NotificationGroupHeader({
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        16,
        16,
        16,
        14,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: const Color(0xFFF0788F),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A1A1A),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingSwitchTile extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final bool isMainSetting;
  final bool isChildSetting;
  final ValueChanged<bool> onChanged;

  const _SettingSwitchTile({
    this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.isMainSetting = false,
    this.isChildSetting = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color titleColor = enabled
        ? const Color(0xFF1A1A1A)
        : const Color(0xFFB4B8C2);

    final Color subtitleColor = enabled
        ? const Color(0xFF9AA0AC)
        : const Color(0xFFD0D2D8);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        isChildSetting ? 30 : 16,
        10,
        10,
        10,
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            _SettingIcon(
              icon: icon!,
              enabled: enabled,
            ),
            const SizedBox(width: 14),
          ],

          if (isChildSetting) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: enabled
                    ? const Color(0xFFF0788F)
                    : const Color(0xFFD0D2D8),
              ),
            ),
            const SizedBox(width: 12),
          ],

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: isChildSetting ? 14 : 15,
                    fontWeight: isMainSetting
                        ? FontWeight.w800
                        : FontWeight.w600,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: subtitleColor,
                  ),
                ),
              ],
            ),
          ),

          Switch(
            value: value,
            activeThumbColor: const Color(0xFFF0788F),
            onChanged: enabled
                ? onChanged
                : null,
          ),
        ],
      ),
    );
  }
}

class _SettingIcon extends StatelessWidget {
  final IconData icon;
  final bool enabled;

  const _SettingIcon({
    required this.icon,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: enabled
            ? const Color(0xFFFCEFF3)
            : const Color(0xFFF3F3F5),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(
        icon,
        size: 21,
        color: enabled
            ? const Color(0xFFF0788F)
            : const Color(0xFFB4B8C2),
      ),
    );
  }
}

class _SettingDivider extends StatelessWidget {
  const _SettingDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 1,
      indent: 16,
      endIndent: 16,
      color: Color(0xFFF0EEF0),
    );
  }
}