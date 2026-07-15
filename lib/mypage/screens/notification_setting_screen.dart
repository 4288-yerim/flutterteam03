import 'package:flutter/material.dart';

import '../../widgets/app_card.dart';
import '../../widgets/app_main_background.dart';
import '../../widgets/app_top_bar.dart';

class NotificationSettingScreen extends StatefulWidget {
  const NotificationSettingScreen({super.key});

  @override
  State<NotificationSettingScreen> createState() =>
      _NotificationSettingScreenState();
}

class _NotificationSettingScreenState
    extends State<NotificationSettingScreen> {
  // Firebase 연결 전 임시 알림 설정값
  bool _allNotificationEnabled = true;

  bool _examScheduleEnabled = true;
  bool _applicationStartEnabled = true;
  bool _examDday7Enabled = true;
  bool _examDayEnabled = true;
  bool _resultAnnouncementEnabled = true;

  bool _studyPlanEnabled = true;
  bool _studyGroupEnabled = true;
  bool _communityEnabled = true;
  bool _marketingEnabled = false;

  void _changeAllNotification(bool value) {
    setState(() {
      _allNotificationEnabled = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppTopBar(
        title: '알림 설정',
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
              _buildAllNotificationCard(),
              const SizedBox(height: 20),

              _buildSectionTitle(
                title: '자격증 시험 알림',
                description: '목표 자격증의 접수, 시험 및 발표 일정을 알려드려요.',
              ),
              const SizedBox(height: 10),

              _buildDisabledArea(
                child: AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _NotificationSwitchTile(
                        icon: Icons.event_note_rounded,
                        title: '자격증 시험 일정 알림',
                        description: '등록한 목표 자격증의 주요 일정을 알려드려요.',
                        value: _examScheduleEnabled,
                        enabled: _allNotificationEnabled,
                        onChanged: (value) {
                          setState(() {
                            _examScheduleEnabled = value;
                          });
                        },
                      ),
                      const Divider(height: 1),
                      _NotificationSwitchTile(
                        icon: Icons.app_registration_rounded,
                        title: '접수 시작 알림',
                        description: '자격증 시험 접수가 시작되면 알려드려요.',
                        value: _applicationStartEnabled,
                        enabled: _allNotificationEnabled,
                        onChanged: (value) {
                          setState(() {
                            _applicationStartEnabled = value;
                          });
                        },
                      ),
                      const Divider(height: 1),
                      _NotificationSwitchTile(
                        icon: Icons.date_range_rounded,
                        title: '시험 D-7 알림',
                        description: '시험일 일주일 전에 미리 알려드려요.',
                        value: _examDday7Enabled,
                        enabled: _allNotificationEnabled,
                        onChanged: (value) {
                          setState(() {
                            _examDday7Enabled = value;
                          });
                        },
                      ),
                      const Divider(height: 1),
                      _NotificationSwitchTile(
                        icon: Icons.alarm_rounded,
                        title: '시험 당일 알림',
                        description: '시험 당일 시간과 준비사항을 알려드려요.',
                        value: _examDayEnabled,
                        enabled: _allNotificationEnabled,
                        onChanged: (value) {
                          setState(() {
                            _examDayEnabled = value;
                          });
                        },
                      ),
                      const Divider(height: 1),
                      _NotificationSwitchTile(
                        icon: Icons.emoji_events_rounded,
                        title: '합격 발표 알림',
                        description: '합격자 발표일에 결과 확인을 안내해 드려요.',
                        value: _resultAnnouncementEnabled,
                        enabled: _allNotificationEnabled,
                        onChanged: (value) {
                          setState(() {
                            _resultAnnouncementEnabled = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              _buildSectionTitle(
                title: '학습 및 활동 알림',
                description: '학습 일정과 앱 활동에 관한 알림을 설정할 수 있어요.',
              ),
              const SizedBox(height: 10),

              _buildDisabledArea(
                child: AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _NotificationSwitchTile(
                        icon: Icons.checklist_rounded,
                        title: '학습 계획 및 오늘의 할 일 알림',
                        description: '오늘 공부할 내용과 미완료 학습 계획을 알려드려요.',
                        value: _studyPlanEnabled,
                        enabled: _allNotificationEnabled,
                        onChanged: (value) {
                          setState(() {
                            _studyPlanEnabled = value;
                          });
                        },
                      ),
                      const Divider(height: 1),
                      _NotificationSwitchTile(
                        icon: Icons.groups_rounded,
                        title: '스터디 일정 및 새 메시지 알림',
                        description: '스터디 일정과 새로운 채팅 메시지를 알려드려요.',
                        value: _studyGroupEnabled,
                        enabled: _allNotificationEnabled,
                        onChanged: (value) {
                          setState(() {
                            _studyGroupEnabled = value;
                          });
                        },
                      ),
                      const Divider(height: 1),
                      _NotificationSwitchTile(
                        icon: Icons.forum_rounded,
                        title: '커뮤니티 댓글 및 좋아요 알림',
                        description: '내 게시글의 새로운 댓글과 좋아요를 알려드려요.',
                        value: _communityEnabled,
                        enabled: _allNotificationEnabled,
                        onChanged: (value) {
                          setState(() {
                            _communityEnabled = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              _buildSectionTitle(
                title: '혜택 알림',
                description: '선택적으로 수신할 수 있는 알림이에요.',
              ),
              const SizedBox(height: 10),

              _buildDisabledArea(
                child: AppCard(
                  padding: EdgeInsets.zero,
                  child: _NotificationSwitchTile(
                    icon: Icons.campaign_rounded,
                    title: '마케팅 알림',
                    description: '이벤트, 새로운 기능 및 맞춤형 혜택을 알려드려요.',
                    value: _marketingEnabled,
                    enabled: _allNotificationEnabled,
                    onChanged: (value) {
                      setState(() {
                        _marketingEnabled = value;
                      });
                    },
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Text(
                '현재 설정은 화면 테스트용 임시 데이터이며, '
                    '앱을 다시 실행하면 초기화될 수 있습니다.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAllNotificationCard() {
    return AppCard(
      padding: EdgeInsets.zero,
      child: _NotificationSwitchTile(
        icon: Icons.notifications_active_rounded,
        title: '전체 알림',
        description: _allNotificationEnabled
            ? '앱의 알림을 받고 있습니다.'
            : '모든 알림이 일시적으로 꺼져 있습니다.',
        value: _allNotificationEnabled,
        enabled: true,
        isMainSetting: true,
        onChanged: _changeAllNotification,
      ),
    );
  }

  Widget _buildSectionTitle({
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisabledArea({
    required Widget child,
  }) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: _allNotificationEnabled ? 1 : 0.45,
      child: child,
    );
  }
}

class _NotificationSwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool value;
  final bool enabled;
  final bool isMainSetting;
  final ValueChanged<bool> onChanged;

  const _NotificationSwitchTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.value,
    required this.enabled,
    required this.onChanged,
    this.isMainSetting = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color iconBackgroundColor = isMainSetting
        ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.14)
        : Colors.grey.shade100;

    final Color iconColor = isMainSetting
        ? Theme.of(context).colorScheme.primary
        : Colors.grey.shade700;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: enabled
          ? () {
        onChanged(!value);
      }
          : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          16,
          14,
          10,
          14,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconBackgroundColor,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                icon,
                size: 22,
                color: iconColor,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: isMainSetting ? 16 : 15,
                      fontWeight:
                      isMainSetting ? FontWeight.w700 : FontWeight.w600,
                      color: enabled
                          ? Colors.black87
                          : Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: enabled
                          ? Colors.grey.shade600
                          : Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Switch.adaptive(
              value: value,
              onChanged: enabled ? onChanged : null,
            ),
          ],
        ),
      ),
    );
  }
}