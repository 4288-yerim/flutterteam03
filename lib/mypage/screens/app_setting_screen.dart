import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../services/app_icon_service.dart';
import '../../services/theme_mode_service.dart';
import '../../theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_main_background.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/loading_overlay.dart';
import 'blocked_user_screen.dart';

class AppSettingScreen extends StatefulWidget {
  const AppSettingScreen({super.key});

  @override
  State<AppSettingScreen> createState() => _AppSettingScreenState();
}

class _AppSettingScreenState extends State<AppSettingScreen> {
  bool _isLoadingSettings = true;
  bool _isSavingSettings = false;
  bool _showSavingOverlay = false;
  bool _isTestingAppIcon = false;
  String? _selectedTestIcon;
  Timer? _savingOverlayTimer;

  // 기존 DB 설계 필드
  String _themeMode = ThemeModeService.instance.modeName;
  bool _profileActivityPublic = true;

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

  bool _applicationStartAlertEnabled = true;
  bool _applicationEndD1AlertEnabled = true;
  bool _examD7AlertEnabled = true;
  bool _examD1AlertEnabled = true;
  bool _examDayAlertEnabled = true;
  bool _resultAlertEnabled = true;

  bool _studyGroupAlertEnabled = true;

  // 스터디 알림 세부 설정
  bool _studyNoticeAlertEnabled = true;
  bool _studyJoinApprovalAlertEnabled = true;
  bool _studyNewMemberAlertEnabled = true;
  bool _studyChatsAlertEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _savingOverlayTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingSettings = false;
      });

      _showMessage('로그인 정보를 확인할 수 없습니다.');
      return;
    }

    try {
      final DocumentSnapshot<Map<String, dynamic>> snapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('settings')
              .doc('app')
              .get();

      final Map<String, dynamic> data = snapshot.data() ?? {};

      if (!mounted) {
        return;
      }

      setState(() {
        _themeMode = ThemeModeService.toName(
          ThemeModeService.fromName(_readString(data, 'themeMode', 'SYSTEM')),
        );
        _profileActivityPublic = _readBool(data, 'profileActivityPublic', true);
        _pushEnabled = _readBool(data, 'pushEnabled', true);
        _certificateAlertEnabled = _readBool(
          data,
          'certificateAlertEnabled',
          true,
        );
        _applicationStartAlertEnabled = _readBool(
          data,
          'applicationStartAlertEnabled',
          true,
        );
        _applicationEndD1AlertEnabled = _readBool(
          data,
          'applicationEndD1AlertEnabled',
          true,
        );
        _examD7AlertEnabled = _readBool(data, 'examD7AlertEnabled', true);
        _examD1AlertEnabled = _readBool(data, 'examD1AlertEnabled', true);
        _examDayAlertEnabled = _readBool(data, 'examDayAlertEnabled', true);
        _resultAlertEnabled = _readBool(data, 'resultAlertEnabled', true);
        _studyAlertEnabled = _readBool(data, 'studyAlertEnabled', true);
        _dailyStudyPlanAlertEnabled = _readBool(
          data,
          'dailyStudyPlanAlertEnabled',
          true,
        );
        _studyStartTimeAlertEnabled = _readBool(
          data,
          'studyStartTimeAlertEnabled',
          true,
        );
        _incompleteStudyAlertEnabled = _readBool(
          data,
          'incompleteStudyAlertEnabled',
          true,
        );
        _studyGroupAlertEnabled = _readBool(
          data,
          'studyGroupAlertEnabled',
          true,
        );
        _studyNoticeAlertEnabled = _readBool(
          data,
          'studyNoticeAlertEnabled',
          true,
        );
        _studyJoinApprovalAlertEnabled = _readBool(
          data,
          'studyJoinApprovalAlertEnabled',
          true,
        );
        _studyNewMemberAlertEnabled = _readBool(
          data,
          'studyNewMemberAlertEnabled',
          true,
        );
        _studyChatsAlertEnabled = _readBool(
          data,
          'studyChatsAlertEnabled',
          true,
        );
        _communityAlertEnabled = _readBool(data, 'communityAlertEnabled', true);
        _friendAlertEnabled = _readBool(data, 'friendAlertEnabled', true);
        _chatsAlertEnabled = _readBool(data, 'chatsAlertEnabled', true);
        _marketingAlertEnabled = _readBool(
          data,
          'marketingAlertEnabled',
          false,
        );
        _isLoadingSettings = false;
      });

      await ThemeModeService.instance.setThemeModeName(_themeMode);

      if (!snapshot.exists) {
        await _saveSettings();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingSettings = false;
      });

      _showMessage('설정을 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.');
    }
  }

  bool _readBool(
    Map<String, dynamic> data,
    String fieldName,
    bool defaultValue,
  ) {
    final dynamic value = data[fieldName];
    return value is bool ? value : defaultValue;
  }

  String _readString(
    Map<String, dynamic> data,
    String fieldName,
    String defaultValue,
  ) {
    final dynamic value = data[fieldName];
    return value is String ? value : defaultValue;
  }

  Future<void> _saveSettings() async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage('로그인 정보를 확인할 수 없습니다.');
      return;
    }

    if (mounted) {
      setState(() {
        _isSavingSettings = true;
        _showSavingOverlay = false;
      });

      _savingOverlayTimer?.cancel();
      _savingOverlayTimer = Timer(Duration(milliseconds: 300), () {
        if (mounted && _isSavingSettings) {
          setState(() {
            _showSavingOverlay = true;
          });
        }
      });
    }

    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();
      final settingsReference = firestore
          .collection('users')
          .doc(user.uid)
          .collection('settings')
          .doc('app');
      batch.set(settingsReference, {
        'themeMode': _themeMode,
        'profileActivityPublic': _profileActivityPublic,
        'pushEnabled': _pushEnabled,
        'certificateAlertEnabled': _certificateAlertEnabled,
        'applicationStartAlertEnabled': _applicationStartAlertEnabled,
        'applicationEndD1AlertEnabled': _applicationEndD1AlertEnabled,
        'examD7AlertEnabled': _examD7AlertEnabled,
        'examD1AlertEnabled': _examD1AlertEnabled,
        'examDayAlertEnabled': _examDayAlertEnabled,
        'resultAlertEnabled': _resultAlertEnabled,
        'studyAlertEnabled': _studyAlertEnabled,
        'dailyStudyPlanAlertEnabled': _dailyStudyPlanAlertEnabled,
        'studyStartTimeAlertEnabled': _studyStartTimeAlertEnabled,
        'incompleteStudyAlertEnabled': _incompleteStudyAlertEnabled,
        'studyGroupAlertEnabled': _studyGroupAlertEnabled,
        'studyNoticeAlertEnabled': _studyNoticeAlertEnabled,
        'studyJoinApprovalAlertEnabled': _studyJoinApprovalAlertEnabled,
        'studyNewMemberAlertEnabled': _studyNewMemberAlertEnabled,
        'studyChatsAlertEnabled': _studyChatsAlertEnabled,
        'communityAlertEnabled': _communityAlertEnabled,
        'friendAlertEnabled': _friendAlertEnabled,
        'chatsAlertEnabled': _chatsAlertEnabled,
        'marketingAlertEnabled': _marketingAlertEnabled,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      batch.set(firestore.collection('users').doc(user.uid), {
        'profileActivityPublic': _profileActivityPublic,
      }, SetOptions(merge: true));
      await batch.commit();
    } catch (error) {
      _showMessage('설정을 저장하지 못했습니다. 잠시 후 다시 시도해 주세요.');
    } finally {
      _savingOverlayTimer?.cancel();
      if (mounted) {
        setState(() {
          _isSavingSettings = false;
          _showSavingOverlay = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSavingSettings,
      child: Stack(
        children: [
          AbsorbPointer(
            absorbing: _isSavingSettings,
            child: Scaffold(
              extendBodyBehindAppBar: true,
              appBar: AppTopBar(title: '설정'),
              body: AppMainBackground(
                child: _isLoadingSettings
                    ? Center(
                        child: CircularProgressIndicator(
                          color: context.colors.pinkStart,
                        ),
                      )
                    : ListView(
                        padding: EdgeInsets.fromLTRB(20, 16, 20, 40),
                        children: [
                          _buildScreenSettingSection(),
                          SizedBox(height: 26),
                          _buildNotificationSettingSection(),
                          SizedBox(height: 26),
                          _buildPrivacySettingSection(),
                          if (kDebugMode) ...[
                            SizedBox(height: 26),
                            _buildAppIconTestSection(),
                          ],
                        ],
                      ),
              ),
            ),
          ),
          if (_showSavingOverlay) Positioned.fill(child: LoadingOverlay()),
        ],
      ),
    );
  }

  Widget _buildScreenSettingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SettingSectionTitle(
          icon: Icons.palette_outlined,
          title: '개인 설정',
          description: '테마와 프로필 활동 공개 범위를 설정합니다.',
        ),
        SizedBox(height: 12),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _buildThemeModeTile(),
              _SettingDivider(),
              _SettingSwitchTile(
                icon: Icons.visibility_outlined,
                title: '프로필 활동 공개',
                subtitle: '내 활동 기록을 다른 사용자에게 공개합니다.',
                value: _profileActivityPublic,
                onChanged: (value) {
                  setState(() {
                    _profileActivityPublic = value;
                  });
                  _saveSettings();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildThemeModeTile() {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          _SettingIcon(icon: Icons.brightness_6_outlined),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '테마 모드',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '앱의 밝기 모드를 설정합니다.',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 10),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _themeMode,
              dropdownColor: context.colors.surfaceElevated,
              style: TextStyle(color: context.colors.textPrimary),
              iconEnabledColor: context.colors.iconSecondary,
              borderRadius: BorderRadius.circular(14),
              items: [
                DropdownMenuItem<String>(value: 'SYSTEM', child: Text('시스템')),
                DropdownMenuItem<String>(value: 'LIGHT', child: Text('라이트')),
                DropdownMenuItem<String>(value: 'DARK', child: Text('다크')),
              ],
              onChanged: (value) {
                if (value == null) {
                  return;
                }

                setState(() {
                  _themeMode = value;
                });

                ThemeModeService.instance.setThemeModeName(value);
                _saveSettings();
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
        _SettingSectionTitle(
          icon: Icons.notifications_outlined,
          title: '알림 설정',
          description: '받고 싶은 알림 종류를 설정합니다.',
        ),
        SizedBox(height: 12),

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

              _saveSettings();
            },
          ),
        ),

        SizedBox(height: 14),
        _buildCertificateAlertCard(),

        SizedBox(height: 14),
        _buildStudyAlertCard(),

        SizedBox(height: 14),
        _buildCommunityAlertCard(),

        SizedBox(height: 14),
        _buildOtherAlertCard(),
      ],
    );
  }

  Widget _buildCertificateAlertCard() {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _NotificationGroupHeader(
            icon: Icons.workspace_premium_outlined,
            title: '자격증 알림',
          ),
          _SettingDivider(),

          _SettingSwitchTile(
            title: '자격증 일정 알림',
            subtitle: '시험과 원서 접수 관련 알림을 받습니다.',
            value: _certificateAlertEnabled,
            enabled: _pushEnabled,
            onChanged: (value) {
              setState(() {
                _certificateAlertEnabled = value;
              });

              _saveSettings();
            },
          ),

          _SettingDivider(),

          _SettingSwitchTile(
            title: '접수 시작',
            subtitle: '자격증 원서 접수가 시작되면 알려줍니다.',
            value: _applicationStartAlertEnabled,
            enabled: _pushEnabled && _certificateAlertEnabled,
            isChildSetting: true,
            onChanged: (value) {
              setState(() {
                _applicationStartAlertEnabled = value;
              });

              _saveSettings();
            },
          ),

          _SettingDivider(),

          _SettingSwitchTile(
            title: '접수 마감 전날',
            subtitle: '자격증 원서 접수 마감 하루 전에 알려줍니다.',
            value: _applicationEndD1AlertEnabled,
            enabled: _pushEnabled && _certificateAlertEnabled,
            isChildSetting: true,
            onChanged: (value) {
              setState(() {
                _applicationEndD1AlertEnabled = value;
              });

              _saveSettings();
            },
          ),

          _SettingDivider(),

          _SettingSwitchTile(
            title: '시험 D-7',
            subtitle: '시험일 7일 전에 알려줍니다.',
            value: _examD7AlertEnabled,
            enabled: _pushEnabled && _certificateAlertEnabled,
            isChildSetting: true,
            onChanged: (value) {
              setState(() {
                _examD7AlertEnabled = value;
              });

              _saveSettings();
            },
          ),

          _SettingDivider(),

          _SettingSwitchTile(
            title: '시험 전날',
            subtitle: '시험 하루 전에 알려줍니다.',
            value: _examD1AlertEnabled,
            enabled: _pushEnabled && _certificateAlertEnabled,
            isChildSetting: true,
            onChanged: (value) {
              setState(() {
                _examD1AlertEnabled = value;
              });

              _saveSettings();
            },
          ),

          _SettingDivider(),

          _SettingSwitchTile(
            title: '시험 당일',
            subtitle: '시험 당일 일정을 알려줍니다.',
            value: _examDayAlertEnabled,
            enabled: _pushEnabled && _certificateAlertEnabled,
            isChildSetting: true,
            onChanged: (value) {
              setState(() {
                _examDayAlertEnabled = value;
              });

              _saveSettings();
            },
          ),

          _SettingDivider(),

          _SettingSwitchTile(
            title: '합격 발표',
            subtitle: '합격 발표일에 알림을 받습니다.',
            value: _resultAlertEnabled,
            enabled: _pushEnabled && _certificateAlertEnabled,
            isChildSetting: true,
            onChanged: (value) {
              setState(() {
                _resultAlertEnabled = value;
              });

              _saveSettings();
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
          _NotificationGroupHeader(
            icon: Icons.menu_book_outlined,
            title: '학습 알림',
          ),
          _SettingDivider(),

          _SettingSwitchTile(
            title: '공부 알림',
            subtitle: '개인 학습 계획과 할 일 알림을 받습니다.',
            value: _studyAlertEnabled,
            enabled: _pushEnabled,
            onChanged: (value) {
              setState(() {
                _studyAlertEnabled = value;
              });

              _saveSettings();
            },
          ),

          _SettingDivider(),

          _SettingSwitchTile(
            title: '오늘의 학습 계획',
            subtitle: '오늘 진행할 학습 계획을 알려줍니다.',
            value: _dailyStudyPlanAlertEnabled,
            enabled: _pushEnabled && _studyAlertEnabled,
            isChildSetting: true,
            onChanged: (value) {
              setState(() {
                _dailyStudyPlanAlertEnabled = value;
              });

              _saveSettings();
            },
          ),

          _SettingDivider(),

          _SettingSwitchTile(
            title: '공부 시작 시간',
            subtitle: '설정한 공부 시작 시간이 되면 알려줍니다.',
            value: _studyStartTimeAlertEnabled,
            enabled: _pushEnabled && _studyAlertEnabled,
            isChildSetting: true,
            onChanged: (value) {
              setState(() {
                _studyStartTimeAlertEnabled = value;
              });

              _saveSettings();
            },
          ),

          _SettingDivider(),

          _SettingSwitchTile(
            title: '미완료 계획',
            subtitle: '완료하지 않은 학습 계획을 알려줍니다.',
            value: _incompleteStudyAlertEnabled,
            enabled: _pushEnabled && _studyAlertEnabled,
            isChildSetting: true,
            onChanged: (value) {
              setState(() {
                _incompleteStudyAlertEnabled = value;
              });

              _saveSettings();
            },
          ),

          _SettingDivider(),

          _SettingSwitchTile(
            title: '스터디 알림',
            subtitle: '스터디 그룹 관련 알림을 받습니다.',
            value: _studyGroupAlertEnabled,
            enabled: _pushEnabled,
            onChanged: (value) {
              setState(() {
                _studyGroupAlertEnabled = value;
              });

              _saveSettings();
            },
          ),

          _SettingDivider(),

          _SettingSwitchTile(
            title: '스터디 공지',
            subtitle: '새로운 스터디 공지가 등록되면 알려줍니다.',
            value: _studyNoticeAlertEnabled,
            enabled: _pushEnabled && _studyGroupAlertEnabled,
            isChildSetting: true,
            onChanged: (value) {
              setState(() {
                _studyNoticeAlertEnabled = value;
              });

              _saveSettings();
            },
          ),

          _SettingDivider(),

          _SettingSwitchTile(
            title: '가입 승인',
            subtitle: '스터디 가입 요청 결과를 알려줍니다.',
            value: _studyJoinApprovalAlertEnabled,
            enabled: _pushEnabled && _studyGroupAlertEnabled,
            isChildSetting: true,
            onChanged: (value) {
              setState(() {
                _studyJoinApprovalAlertEnabled = value;
              });

              _saveSettings();
            },
          ),

          _SettingDivider(),

          _SettingSwitchTile(
            title: '새 멤버',
            subtitle: '스터디에 새로운 멤버가 참여하면 알려줍니다.',
            value: _studyNewMemberAlertEnabled,
            enabled: _pushEnabled && _studyGroupAlertEnabled,
            isChildSetting: true,
            onChanged: (value) {
              setState(() {
                _studyNewMemberAlertEnabled = value;
              });

              _saveSettings();
            },
          ),

          _SettingDivider(),

          _SettingSwitchTile(
            title: '스터디 채팅',
            subtitle: '스터디 채팅에 새 메시지가 오면 알려줍니다.',
            value: _studyChatsAlertEnabled,
            enabled: _pushEnabled && _studyGroupAlertEnabled,
            isChildSetting: true,
            onChanged: (value) {
              setState(() {
                _studyChatsAlertEnabled = value;
              });

              _saveSettings();
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
          _NotificationGroupHeader(
            icon: Icons.forum_outlined,
            title: '커뮤니티 및 친구 알림',
          ),
          _SettingDivider(),

          _SettingSwitchTile(
            title: '커뮤니티 알림',
            subtitle: '게시글의 댓글과 좋아요 알림을 받습니다.',
            value: _communityAlertEnabled,
            enabled: _pushEnabled,
            onChanged: (value) {
              setState(() {
                _communityAlertEnabled = value;
              });

              _saveSettings();
            },
          ),

          _SettingDivider(),

          _SettingSwitchTile(
            title: '친구 알림',
            subtitle: '친구 요청과 친구 활동 알림을 받습니다.',
            value: _friendAlertEnabled,
            enabled: _pushEnabled,
            onChanged: (value) {
              setState(() {
                _friendAlertEnabled = value;
              });

              _saveSettings();
            },
          ),

          _SettingDivider(),

          _SettingSwitchTile(
            title: '채팅 알림',
            subtitle: '새로운 채팅 메시지 알림을 받습니다.',
            value: _chatsAlertEnabled,
            enabled: _pushEnabled,
            onChanged: (value) {
              setState(() {
                _chatsAlertEnabled = value;
              });

              _saveSettings();
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
          _NotificationGroupHeader(
            icon: Icons.campaign_outlined,
            title: '기타 알림',
          ),
          _SettingDivider(),

          _SettingSwitchTile(
            title: '마케팅 알림',
            subtitle: '이벤트와 혜택 정보를 받습니다.',
            value: _marketingAlertEnabled,
            enabled: _pushEnabled,
            onChanged: (value) {
              setState(() {
                _marketingAlertEnabled = value;
              });

              _saveSettings();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacySettingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SettingSectionTitle(
          icon: Icons.shield_outlined,
          title: '차단 사용자 관리',
          description: '차단한 사용자를 확인하고 관리합니다.',
        ),
        SizedBox(height: 12),
        AppCard(
          padding: EdgeInsets.zero,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => BlockedUserScreen()),
              );
            },
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 14, 14),
              child: Row(
                children: [
                  _SettingIcon(icon: Icons.person_off_outlined),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '차단 사용자 관리',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: context.colors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '차단 목록을 확인하고 차단을 해제합니다.',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: context.colors.textMuted,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAppIconTestSection() {
    const options = <(String, int)>[
      ('기본', 0),
      ('3일', 3),
      ('7일', 7),
      ('14일', 14),
      ('21일', 21),
      ('30일', 30),
      ('60일', 60),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SettingSectionTitle(
          icon: Icons.science_outlined,
          title: '앱 아이콘 테스트',
          description: '개발 빌드에서 미접속 일수별 아이콘을 즉시 확인합니다.',
        ),
        SizedBox(height: 12),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '아이콘을 선택한 다음 홈 화면으로 이동해 확인하세요. 실제 접속 기록은 변경되지 않습니다.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: context.colors.textSecondary,
                ),
              ),
              SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final option in options)
                    _buildIconTestChip(
                      label: option.$1,
                      selected: _selectedTestIcon == option.$1,
                      onPressed: () => _testInactiveIcon(option.$1, option.$2),
                    ),
                  _buildIconTestChip(
                    label: '연속 접속',
                    selected: _selectedTestIcon == '연속 접속',
                    onPressed: _testGoodIcon,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIconTestChip({
    required String label,
    required bool selected,
    required VoidCallback onPressed,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: _isTestingAppIcon ? null : (_) => onPressed(),
      selectedColor: context.colors.pinkSoft,
      side: BorderSide(
        color: selected ? context.colors.pinkStart : context.colors.divider,
      ),
      labelStyle: TextStyle(
        color: selected
            ? context.colors.pinkStart
            : context.colors.textSecondary,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
    );
  }

  Future<void> _testInactiveIcon(String label, int days) async {
    await _runIconTest(
      label,
      () => AppIconService.testInactiveDays(days),
    );
  }

  Future<void> _testGoodIcon() async {
    await _runIconTest('연속 접속', AppIconService.testGoodIcon);
  }

  Future<void> _runIconTest(
    String label,
    Future<String?> Function() test,
  ) async {
    setState(() => _isTestingAppIcon = true);
    final alias = await test();
    if (!mounted) return;

    setState(() {
      _isTestingAppIcon = false;
      if (alias != null) _selectedTestIcon = label;
    });

    _showMessage(
      alias == null
          ? '아이콘 변경에 실패했습니다.'
          : '$label 아이콘을 적용했습니다. 홈 화면에서 확인해 주세요.',
    );
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
            color: context.colors.pinkSoft,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, size: 22, color: context.colors.pinkStart),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: context.colors.textPrimary,
                ),
              ),
              SizedBox(height: 3),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: context.colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NotificationGroupHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _NotificationGroupHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: context.colors.pinkStart),
          SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: context.colors.textPrimary,
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
        ? context.colors.textPrimary
        : context.colors.textMuted;

    final Color subtitleColor = enabled
        ? context.colors.textSecondary
        : context.colors.textDisabled;

    return Padding(
      padding: EdgeInsets.fromLTRB(isChildSetting ? 30 : 16, 10, 10, 10),
      child: Row(
        children: [
          if (icon != null) ...[
            _SettingIcon(icon: icon!, enabled: enabled),
            SizedBox(width: 14),
          ],

          if (isChildSetting) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: enabled
                    ? context.colors.pinkStart
                    : context.colors.textDisabled,
              ),
            ),
            SizedBox(width: 12),
          ],

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                SizedBox(height: 4),
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
            activeThumbColor: context.colors.pinkStart,
            onChanged: enabled ? onChanged : null,
          ),
        ],
      ),
    );
  }
}

class _SettingIcon extends StatelessWidget {
  final IconData icon;
  final bool enabled;

  const _SettingIcon({required this.icon, this.enabled = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: enabled ? context.colors.pinkSoft : context.colors.surfaceMuted,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(
        icon,
        size: 21,
        color: enabled ? context.colors.pinkStart : context.colors.textMuted,
      ),
    );
  }
}

class _SettingDivider extends StatelessWidget {
  _SettingDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 16,
      endIndent: 16,
      color: context.colors.divider,
    );
  }
}
