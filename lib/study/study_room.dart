import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/user_profile_cache_service.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_dropdown.dart';
import '../widgets/app_report_bottom_sheet.dart';
import '../widgets/cached_user_profile_builder.dart';
import 'package:flutterteam03/widgets/app_state_views.dart';

import '../widgets/app_main_background.dart';
import '../widgets/app_card.dart';
import '../widgets/app_button.dart';
import '../widgets/app_top_bar.dart';
import 'study_chat.dart';
import 'study_edit.dart';
import 'study_join_requests.dart';
import 'study_quiz.dart';
import 'study_record.dart';
import 'study_timer.dart';

class StudyRoomPage extends StatelessWidget {
  final String studyId;
  final String groupName;

  static final Set<String> _profileSyncRequestedKeySet = <String>{};

  const StudyRoomPage({
    super.key,
    required this.studyId,
    required this.groupName,
  });

  bool _isNetworkError(Object? error) {
    if (error is FirebaseException) {
      if (error.code == 'unavailable' ||
          error.code == 'network-request-failed' ||
          error.code == 'deadline-exceeded') {
        return true;
      }
    }

    return false;
  }

  void _reloadPage(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) {
          return StudyRoomPage(studyId: studyId, groupName: groupName);
        },
      ),
    );
  }

  void _scheduleCurrentMemberProfileSync({required bool isOwner}) {
    User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return;
    }

    String syncKey = '$studyId:${currentUser.uid}';

    if (_profileSyncRequestedKeySet.contains(syncKey)) {
      return;
    }

    _profileSyncRequestedKeySet.add(syncKey);

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      try {
        await _syncCurrentMemberProfile(isOwner: isOwner);
      } catch (error) {
        _profileSyncRequestedKeySet.remove(syncKey);

        debugPrint('스터디 그룹원 닉네임 동기화 오류: $error');
      }
    });
  }

  Future<void> _syncCurrentMemberProfile({required bool isOwner}) async {
    User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return;
    }

    final profile = await UserProfileCacheService.instance.getProfile(
      currentUser.uid,
    );

    if (profile == null) {
      return;
    }

    String nickname = profile.nickname;

    if (nickname.isEmpty) {
      nickname = currentUser.displayName?.trim() ?? '';
    }

    String profileImageUrl = profile.profileImageUrl;

    if (profileImageUrl.isEmpty) {
      profileImageUrl = currentUser.photoURL?.trim() ?? '';
    }

    if (nickname.isEmpty && profileImageUrl.isEmpty) {
      return;
    }

    DocumentReference<Map<String, dynamic>> memberDocument = FirebaseFirestore
        .instance
        .collection('studyGroups')
        .doc(studyId)
        .collection('members')
        .doc(currentUser.uid);

    DocumentSnapshot<Map<String, dynamic>> memberSnapshot = await memberDocument
        .get();

    Map<String, dynamic> memberData = memberSnapshot.data() ?? {};

    Map<String, dynamic> updateData = {
      'uid': currentUser.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (nickname.isNotEmpty &&
        memberData['nickname']?.toString().trim() != nickname) {
      updateData['nickname'] = nickname;
    }

    if (profileImageUrl.isNotEmpty &&
        memberData['profileImageUrl']?.toString().trim() != profileImageUrl) {
      updateData['profileImageUrl'] = profileImageUrl;
    }

    if (!memberSnapshot.exists && isOwner) {
      updateData['role'] = 'OWNER';
      updateData['status'] = 'ACTIVE';
      updateData['totalStudyMinutes'] = 0;
      updateData['totalStudySeconds'] = 0;
      updateData['isStudying'] = false;
      updateData['isResting'] = false;
      updateData['studyStatus'] = 'IDLE';
      updateData['joinedAt'] = FieldValue.serverTimestamp();
    }

    if (updateData.length > 2 || !memberSnapshot.exists) {
      await memberDocument.set(updateData, SetOptions(merge: true));
    }

    if (isOwner && nickname.isNotEmpty) {
      DocumentReference<Map<String, dynamic>> groupDocument = FirebaseFirestore
          .instance
          .collection('studyGroups')
          .doc(studyId);

      DocumentSnapshot<Map<String, dynamic>> groupSnapshot = await groupDocument
          .get();

      String savedOwnerNickname =
          groupSnapshot.data()?['ownerNickname']?.toString().trim() ?? '';

      if (savedOwnerNickname != nickname) {
        await groupDocument.set({
          'ownerNickname': nickname,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }
  }

  int _getInt(Map<String, dynamic> data, String fieldName) {
    dynamic value = data[fieldName];

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return 0;
  }

  bool _isRecruiting(Map<String, dynamic> data) {
    String recruitmentStatus = data['recruitmentStatus']?.toString() ?? '';

    String groupStatus = data['status']?.toString() ?? '';

    int currentMemberCount = _getInt(data, 'currentMemberCount');

    int maxMemberCount = _getInt(data, 'maxMemberCount');

    if (groupStatus == 'COMPLETED') {
      return false;
    }

    if (recruitmentStatus == 'CLOSED') {
      return false;
    }

    if (recruitmentStatus.isEmpty && groupStatus == 'CLOSED') {
      return false;
    }

    if (maxMemberCount > 0 && currentMemberCount >= maxMemberCount) {
      return false;
    }

    return true;
  }

  Future<void> _updateRecruitmentStatus(
    BuildContext context,
    Map<String, dynamic> groupData,
    bool openRecruitment,
  ) async {
    int currentMemberCount = _getInt(groupData, 'currentMemberCount');

    int maxMemberCount = _getInt(groupData, 'maxMemberCount');

    if (openRecruitment &&
        maxMemberCount > 0 &&
        currentMemberCount >= maxMemberCount) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('정원이 가득 차서 모집을 다시 열 수 없습니다.')));
      return;
    }

    try {
      String recruitmentStatus = 'CLOSED';
      String groupStatus = 'CLOSED';

      if (openRecruitment) {
        recruitmentStatus = 'OPEN';
        groupStatus = 'RECRUITING';
      }

      await FirebaseFirestore.instance
          .collection('studyGroups')
          .doc(studyId)
          .update({
            'recruitmentStatus': recruitmentStatus,
            'status': groupStatus,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (!context.mounted) {
        return;
      }

      String message = '스터디 모집을 마감했습니다.';

      if (openRecruitment) {
        message = '스터디 모집을 다시 시작했습니다.';
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      debugPrint('모집 상태 변경 오류: $error');

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('모집 상태를 변경하지 못했습니다.')));
    }
  }

  Widget _buildMenuItemRow(
    BuildContext context,
    IconData icon,
    String label,
    Color chipColor,
    Color iconColor, {
    bool isDestructive = false,
  }) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: chipColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 17, color: iconColor),
        ),
        SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: isDestructive
                ? context.colors.incorrect
                : context.colors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildMoreMenuTrigger(BuildContext context) {
    return Icon(
      Icons.more_vert_rounded,
      size: 22,
      color: context.colors.textPrimary,
    );
  }

  Widget _buildRoomBadge(String text, Color backgroundColor, Color textColor) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildRoomSectionTitle(
    BuildContext context,
    String title,
    String description,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: context.colors.textPrimary,
          ),
        ),
        SizedBox(height: 3),
        Text(
          description,
          style: TextStyle(fontSize: 11, color: context.colors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildRoomMetric(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withOpacity(0.82),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: context.colors.pinkStart),
            SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      color: context.colors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: context.colors.pinkStart,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatStudyTime(int totalSeconds) {
    if (totalSeconds <= 0) {
      return '0초';
    }

    int hours = totalSeconds ~/ 3600;
    int minutes = (totalSeconds % 3600) ~/ 60;
    int seconds = totalSeconds % 60;

    if (hours > 0) {
      return '$hours시간 $minutes분 $seconds초';
    }

    if (minutes > 0) {
      return '$minutes분 $seconds초';
    }

    return '$seconds초';
  }

  int _getTotalStudySeconds(Map<String, dynamic> data) {
    dynamic secondsValue = data['totalStudySeconds'];

    if (secondsValue is int) {
      return secondsValue;
    }

    if (secondsValue is num) {
      return secondsValue.toInt();
    }

    dynamic minutesValue = data['totalStudyMinutes'];

    if (minutesValue is int) {
      return minutesValue * 60;
    }

    if (minutesValue is num) {
      return (minutesValue * 60).round();
    }

    return 0;
  }

  int _getRecordStudySeconds(Map<String, dynamic> data) {
    dynamic studySecondsValue = data['studySeconds'];

    if (studySecondsValue is int) {
      return studySecondsValue;
    }

    if (studySecondsValue is num) {
      return studySecondsValue.toInt();
    }

    dynamic elapsedSecondsValue = data['elapsedSeconds'];

    if (elapsedSecondsValue is int) {
      return elapsedSecondsValue;
    }

    if (elapsedSecondsValue is num) {
      return elapsedSecondsValue.toInt();
    }

    dynamic studyMinutesValue = data['studyMinutes'];

    if (studyMinutesValue is int) {
      return studyMinutesValue * 60;
    }

    if (studyMinutesValue is num) {
      return (studyMinutesValue * 60).round();
    }

    return 0;
  }

  DateTime? _getDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate().toLocal();
    }

    if (value is DateTime) {
      return value.toLocal();
    }

    return null;
  }

  String _formatGoalTime(int totalSeconds) {
    if (totalSeconds <= 0) {
      return '0분';
    }

    int hours = totalSeconds ~/ 3600;
    int minutes = (totalSeconds % 3600) ~/ 60;

    if (hours > 0) {
      return '$hours시간 $minutes분';
    }

    return '$minutes분';
  }

  String _formatExamDate(DateTime examDate) {
    return '${examDate.year}.${examDate.month.toString().padLeft(2, '0')}.'
        '${examDate.day.toString().padLeft(2, '0')}';
  }

  String _getDdayText(DateTime examDate) {
    DateTime now = DateTime.now();

    DateTime today = DateTime(now.year, now.month, now.day);

    DateTime examDay = DateTime(examDate.year, examDate.month, examDate.day);

    int difference = examDay.difference(today).inDays;

    if (difference > 0) {
      return 'D-$difference';
    }

    if (difference == 0) {
      return 'D-DAY';
    }

    return 'D+${difference.abs()}';
  }

  /// 방장이 스터디방에서 시험일과 주간 목표 설정
  Future<void> _showStudyGoalDialog(
    BuildContext context,
    Map<String, dynamic> groupData,
  ) async {
    DateTime? selectedExamDate = _getDateTime(groupData['examDate']);

    int weeklyGoalMinutes = _getInt(groupData, 'weeklyGoalMinutes');

    TextEditingController hourController = TextEditingController(
      text: weeklyGoalMinutes ~/ 60 > 0
          ? (weeklyGoalMinutes ~/ 60).toString()
          : '',
    );

    TextEditingController minuteController = TextEditingController(
      text: weeklyGoalMinutes % 60 > 0
          ? (weeklyGoalMinutes % 60).toString()
          : '',
    );

    bool isSaving = false;
    String inputError = '';

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> selectExamDate() async {
              DateTime now = DateTime.now();

              DateTime? pickedDate = await showDatePicker(
                context: dialogContext,
                initialDate: selectedExamDate ?? now,
                firstDate: DateTime(now.year - 5),
                lastDate: DateTime(now.year + 10, 12, 31),
                helpText: '시험일 선택',
                cancelText: '취소',
                confirmText: '선택',
              );

              if (pickedDate == null) {
                return;
              }

              setDialogState(() {
                selectedExamDate = DateTime(
                  pickedDate.year,
                  pickedDate.month,
                  pickedDate.day,
                );
              });
            }

            Future<void> saveGoal() async {
              int goalHours = int.tryParse(hourController.text.trim()) ?? 0;

              int goalMinutes = int.tryParse(minuteController.text.trim()) ?? 0;

              if (goalHours < 0 || goalMinutes < 0) {
                setDialogState(() {
                  inputError = '목표시간은 0 이상으로 입력해 주세요.';
                });
                return;
              }

              if (goalMinutes >= 60) {
                setDialogState(() {
                  inputError = '분은 0분부터 59분까지 입력해 주세요.';
                });
                return;
              }

              int totalGoalMinutes = goalHours * 60 + goalMinutes;

              if (totalGoalMinutes > 7 * 24 * 60) {
                setDialogState(() {
                  inputError = '주간 목표는 최대 168시간까지 설정할 수 있습니다.';
                });
                return;
              }

              setDialogState(() {
                isSaving = true;
                inputError = '';
              });

              try {
                await FirebaseFirestore.instance
                    .collection('studyGroups')
                    .doc(studyId)
                    .update({
                      'examDate': selectedExamDate == null
                          ? null
                          : Timestamp.fromDate(selectedExamDate!),
                      'weeklyGoalMinutes': totalGoalMinutes,
                      'updatedAt': FieldValue.serverTimestamp(),
                    });

                if (!dialogContext.mounted) {
                  return;
                }

                Navigator.pop(dialogContext);

                if (!context.mounted) {
                  return;
                }

                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('시험일과 주간 목표를 저장했습니다.')));
              } catch (error) {
                debugPrint('시험일·주간 목표 저장 오류: $error');

                if (!dialogContext.mounted) {
                  return;
                }

                setDialogState(() {
                  isSaving = false;
                  inputError = '시험일과 주간 목표를 저장하지 못했습니다.';
                });
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              title: Row(
                children: [
                  Icon(
                    Icons.event_available_rounded,
                    color: context.colors.pinkStart,
                  ),
                  SizedBox(width: 10),
                  Expanded(child: Text('시험일·주간 목표 설정')),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '시험일',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 8),
                    InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: isSaving ? null : selectExamDate,
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_month_outlined,
                              color: context.colors.pinkStart,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                selectedExamDate == null
                                    ? '시험일을 선택해 주세요.'
                                    : _formatExamDate(selectedExamDate!),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: selectedExamDate == null
                                      ? context.colors.textSecondary
                                      : context.colors.textPrimary,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: context.colors.textSecondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (selectedExamDate != null)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: isSaving
                              ? null
                              : () {
                                  setDialogState(() {
                                    selectedExamDate = null;
                                  });
                                },
                          child: Text(
                            '시험일 삭제',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      ),
                    SizedBox(height: 12),
                    Text(
                      '이번 주 그룹 목표',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      '그룹원 전체의 월요일부터 일요일까지 공부시간을 합산합니다.',
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.4,
                        color: context.colors.textSecondary,
                      ),
                    ),
                    SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: hourController,
                            enabled: !isSaving,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: '시간',
                              hintText: '예: 20',
                              suffixText: '시간',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: minuteController,
                            enabled: !isSaving,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: '분',
                              hintText: '예: 30',
                              suffixText: '분',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 7),
                    Text(
                      '시간과 분을 모두 비우거나 0으로 저장하면 목표가 해제됩니다.',
                      style: TextStyle(
                        fontSize: 10,
                        height: 1.4,
                        color: context.colors.textSecondary,
                      ),
                    ),
                    if (inputError.isNotEmpty) ...[
                      SizedBox(height: 10),
                      Text(
                        inputError,
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () {
                          Navigator.pop(dialogContext);
                        },
                  child: Text('취소'),
                ),
                ElevatedButton(
                  onPressed: isSaving ? null : saveGoal,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.colors.pinkStart,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                  child: isSaving
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        )
                      : Text('저장'),
                ),
              ],
            );
          },
        );
      },
    );

    hourController.dispose();
    minuteController.dispose();
  }

  /// 일반 그룹원이 스터디방에서 나가기
  Future<void> _leaveStudyRoom() async {
    User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      throw Exception('로그인 정보가 없습니다.');
    }

    DocumentReference<Map<String, dynamic>> groupDocument = FirebaseFirestore
        .instance
        .collection('studyGroups')
        .doc(studyId);

    DocumentReference<Map<String, dynamic>> memberDocument = groupDocument
        .collection('members')
        .doc(currentUser.uid);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      DocumentSnapshot<Map<String, dynamic>> groupSnapshot = await transaction
          .get(groupDocument);

      DocumentSnapshot<Map<String, dynamic>> memberSnapshot = await transaction
          .get(memberDocument);

      if (!groupSnapshot.exists) {
        throw Exception('스터디 정보를 찾을 수 없습니다.');
      }

      if (!memberSnapshot.exists) {
        throw Exception('참여 중인 스터디가 아닙니다.');
      }

      Map<String, dynamic> groupData = groupSnapshot.data() ?? {};

      Map<String, dynamic> memberData = memberSnapshot.data() ?? {};

      String ownerUid = groupData['ownerUid']?.toString() ?? '';

      String memberStatus = memberData['status']?.toString() ?? '';

      if (currentUser.uid == ownerUid) {
        throw Exception('방장은 스터디방에서 나갈 수 없습니다.');
      }

      if (memberStatus != 'ACTIVE') {
        throw Exception('이미 참여 중인 스터디가 아닙니다.');
      }

      int currentMemberCount = _getInt(groupData, 'currentMemberCount');

      int newMemberCount = currentMemberCount - 1;

      if (newMemberCount < 1) {
        newMemberCount = 1;
      }

      String currentStatus = groupData['status']?.toString() ?? 'RECRUITING';

      String nextStatus = currentStatus == 'COMPLETED'
          ? 'COMPLETED'
          : 'RECRUITING';

      transaction.update(memberDocument, {
        'status': 'LEFT',
        'isStudying': false,
        'isResting': false,
        'studyStatus': 'IDLE',
        'timerMode': '',
        'currentSubject': '',
        'timerStudySeconds': 0,
        'timerRestSeconds': 0,
        'timerPhaseSeconds': 0,
        'timerSegmentStartedAt': null,
        'leftAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      transaction.update(groupDocument, {
        'currentMemberCount': newMemberCount,
        'status': nextStatus,
        'recruitmentStatus': nextStatus == 'COMPLETED' ? 'CLOSED' : 'OPEN',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// 스터디방 나가기 확인창
  void _showLeaveStudyRoomDialog(BuildContext context) {
    bool isLeaving = false;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: context.colors.surface,
              surfaceTintColor: Colors.transparent,
              shape: appDialogShape,
              title: AppDialogTitle(
                icon: Icons.logout_rounded,
                title: '스터디방 나가기',
                isDestructive: true,
              ),
              content: Text(
                '이 스터디방에서 나갈까요?\n\n'
                '나가면 채팅과 공부 활동에 참여할 수 없으며, '
                '다시 이용하려면 스터디에 재참여해야 합니다.',
                style: TextStyle(height: 1.5),
              ),
              actions: [
                TextButton(
                  onPressed: isLeaving
                      ? null
                      : () {
                          Navigator.pop(dialogContext);
                        },
                  child: Text('취소'),
                ),
                TextButton(
                  onPressed: isLeaving
                      ? null
                      : () async {
                          setDialogState(() {
                            isLeaving = true;
                          });

                          try {
                            await _leaveStudyRoom();

                            if (!dialogContext.mounted) {
                              return;
                            }

                            Navigator.pop(dialogContext);

                            if (!context.mounted) {
                              return;
                            }

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('스터디방에서 나갔습니다.')),
                            );

                            Navigator.pop(context, true);
                          } catch (error) {
                            debugPrint('스터디방 나가기 오류: $error');

                            if (!dialogContext.mounted) {
                              return;
                            }

                            setDialogState(() {
                              isLeaving = false;
                            });

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  error.toString().replaceFirst(
                                    'Exception: ',
                                    '',
                                  ),
                                ),
                              ),
                            );
                          }
                        },
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  child: isLeaving
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text('나가기'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// 스터디 정보 수정 화면으로 이동
  Future<void> _openStudyEditPage(
    BuildContext context,
    Map<String, dynamic> groupData,
  ) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) {
          return StudyEditPage(studyId: studyId, studyData: groupData);
        },
      ),
    );
  }

  /// 방장 위임 처리
  Future<void> _transferOwner({
    required String newOwnerUid,
    required String newOwnerNickname,
    required String newOwnerProfileImageUrl,
  }) async {
    User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      throw Exception('로그인 정보가 없습니다.');
    }

    DocumentReference<Map<String, dynamic>> groupDocument = FirebaseFirestore
        .instance
        .collection('studyGroups')
        .doc(studyId);

    DocumentReference<Map<String, dynamic>> currentOwnerDocument = groupDocument
        .collection('members')
        .doc(currentUser.uid);

    DocumentReference<Map<String, dynamic>> newOwnerDocument = groupDocument
        .collection('members')
        .doc(newOwnerUid);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      DocumentSnapshot<Map<String, dynamic>> groupSnapshot = await transaction
          .get(groupDocument);

      DocumentSnapshot<Map<String, dynamic>> newOwnerSnapshot =
          await transaction.get(newOwnerDocument);

      if (!groupSnapshot.exists) {
        throw Exception('스터디 정보를 찾을 수 없습니다.');
      }

      Map<String, dynamic> groupData = groupSnapshot.data() ?? {};

      String ownerUid = groupData['ownerUid']?.toString() ?? '';

      if (ownerUid != currentUser.uid) {
        throw Exception('현재 방장만 방장을 위임할 수 있습니다.');
      }

      if (!newOwnerSnapshot.exists) {
        throw Exception('위임할 그룹원 정보를 찾을 수 없습니다.');
      }

      Map<String, dynamic> newOwnerData = newOwnerSnapshot.data() ?? {};

      String newOwnerStatus = newOwnerData['status']?.toString() ?? '';

      if (newOwnerStatus != 'ACTIVE') {
        throw Exception('활동 중인 그룹원에게만 위임할 수 있습니다.');
      }

      transaction.set(currentOwnerDocument, {
        'role': 'MEMBER',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      transaction.update(newOwnerDocument, {
        'role': 'OWNER',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      Map<String, dynamic> groupUpdateData = {
        'ownerUid': newOwnerUid,
        'ownerNickname': newOwnerNickname,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (newOwnerProfileImageUrl.isNotEmpty) {
        groupUpdateData['ownerProfileImageUrl'] = newOwnerProfileImageUrl;
      }

      transaction.update(groupDocument, groupUpdateData);
    });
  }

  /// 방장 위임 확인창
  Future<void> _showTransferOwnerConfirmDialog({
    required BuildContext context,
    required String newOwnerUid,
    required String newOwnerNickname,
    required String newOwnerProfileImageUrl,
  }) async {
    final profile = await UserProfileCacheService.instance.getProfile(
      newOwnerUid,
    );
    final currentOwnerNickname = await UserProfileCacheService.instance
        .resolveNickname(uid: newOwnerUid, fallback: newOwnerNickname);
    final currentOwnerProfileImageUrl =
        profile?.profileImageUrl.trim().isNotEmpty == true
        ? profile!.profileImageUrl
        : newOwnerProfileImageUrl;
    if (!context.mounted) {
      return;
    }

    bool isTransferring = false;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> transferOwner() async {
              setDialogState(() {
                isTransferring = true;
              });

              try {
                await _transferOwner(
                  newOwnerUid: newOwnerUid,
                  newOwnerNickname: currentOwnerNickname,
                  newOwnerProfileImageUrl: currentOwnerProfileImageUrl,
                );

                if (!dialogContext.mounted) {
                  return;
                }

                Navigator.pop(dialogContext);

                if (!context.mounted) {
                  return;
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$currentOwnerNickname 님에게 방장을 위임했습니다.'),
                  ),
                );
              } catch (error) {
                debugPrint('방장 위임 오류: $error');

                if (!dialogContext.mounted) {
                  return;
                }

                setDialogState(() {
                  isTransferring = false;
                });

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      error.toString().replaceFirst('Exception: ', ''),
                    ),
                  ),
                );
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              title: Row(
                children: [
                  Icon(
                    Icons.admin_panel_settings_outlined,
                    color: context.colors.pinkStart,
                  ),
                  SizedBox(width: 10),
                  Text('방장 위임'),
                ],
              ),
              content: Text(
                '$currentOwnerNickname 님에게 방장을 위임할까요?\n\n'
                '위임 후에는 일반 그룹원이 되며, '
                '필요하면 우측 상단 메뉴에서 스터디방을 나갈 수 있습니다.',
                style: TextStyle(height: 1.5),
              ),
              actions: [
                TextButton(
                  onPressed: isTransferring
                      ? null
                      : () {
                          Navigator.pop(dialogContext);
                        },
                  child: Text('취소'),
                ),
                ElevatedButton(
                  onPressed: isTransferring ? null : transferOwner,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.colors.pinkStart,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                  child: isTransferring
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        )
                      : Text('위임'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// 방장을 위임할 그룹원 선택
  void _showTransferOwnerSheet(BuildContext context) {
    User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface.withOpacity(0),
      builder: (bottomSheetContext) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.72,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: Column(
            children: [
              SizedBox(height: 11),
              Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(20, 18, 12, 14),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: context.colors.lavender,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.admin_panel_settings_outlined,
                        color: context.colors.pinkStart,
                      ),
                    ),
                    SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '방장 위임',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                              color: context.colors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            '새로운 방장을 선택해 주세요.',
                            style: TextStyle(
                              fontSize: 12,
                              color: context.colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        Navigator.pop(bottomSheetContext);
                      },
                      icon: Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Divider(height: 1),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('studyGroups')
                      .doc(studyId)
                      .collection('members')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return AppLoadingView(message: '그룹원을 불러오는 중입니다.');
                    }

                    if (snapshot.hasError) {
                      return AppErrorView(
                        message: '그룹원을 불러오지 못했습니다.',
                        description: '잠시 후 다시 시도해 주세요.',
                      );
                    }

                    List<QueryDocumentSnapshot<Map<String, dynamic>>>
                    memberList = [];

                    if (snapshot.data != null) {
                      for (int i = 0; i < snapshot.data!.docs.length; i++) {
                        QueryDocumentSnapshot<Map<String, dynamic>>
                        memberDocument = snapshot.data!.docs[i];

                        Map<String, dynamic> memberData = memberDocument.data();

                        String status = memberData['status']?.toString() ?? '';

                        String role =
                            memberData['role']?.toString() ?? 'MEMBER';

                        if (status == 'ACTIVE' &&
                            role != 'OWNER' &&
                            memberDocument.id != currentUser.uid) {
                          memberList.add(memberDocument);
                        }
                      }
                    }

                    memberList.sort((a, b) {
                      String aNickname = a.data()['nickname']?.toString() ?? '';

                      String bNickname = b.data()['nickname']?.toString() ?? '';

                      return aNickname.compareTo(bNickname);
                    });

                    if (memberList.isEmpty) {
                      return AppEmptyView(
                        message: '위임할 그룹원이 없습니다.',
                        description: '활동 중인 다른 그룹원이 있어야 방장을 위임할 수 있습니다.',
                      );
                    }

                    return ListView.builder(
                      padding: EdgeInsets.fromLTRB(18, 16, 18, 30),
                      itemCount: memberList.length,
                      itemBuilder: (context, index) {
                        QueryDocumentSnapshot<Map<String, dynamic>>
                        memberDocument = memberList[index];

                        Map<String, dynamic> memberData = memberDocument.data();

                        String nickname =
                            memberData['nickname']?.toString() ?? '스터디원';

                        String profileImageUrl =
                            memberData['profileImageUrl']?.toString() ?? '';

                        String firstLetter = nickname.isEmpty
                            ? '?'
                            : nickname.substring(0, 1).toUpperCase();

                        return Container(
                          margin: EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(17),
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.outlineVariant,
                            ),
                          ),
                          child: ListTile(
                            leading: profileImageUrl.isNotEmpty
                                ? CircleAvatar(
                                    backgroundColor: context.colors.lavender,
                                    backgroundImage: NetworkImage(
                                      profileImageUrl,
                                    ),
                                  )
                                : CircleAvatar(
                                    backgroundColor: context.colors.lavender,
                                    child: Text(
                                      firstLetter,
                                      style: TextStyle(
                                        color: context.colors.pinkStart,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                            title: CachedNicknameText(
                              uid: memberDocument.id,
                              fallback: nickname,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: context.colors.textPrimary,
                              ),
                            ),
                            subtitle: Text(
                              '일반 그룹원',
                              style: TextStyle(
                                fontSize: 11,
                                color: context.colors.textSecondary,
                              ),
                            ),
                            trailing: Icon(
                              Icons.chevron_right_rounded,
                              color: context.colors.textSecondary,
                            ),
                            onTap: () {
                              Navigator.pop(bottomSheetContext);

                              _showTransferOwnerConfirmDialog(
                                context: context,
                                newOwnerUid: memberDocument.id,
                                newOwnerNickname: nickname,
                                newOwnerProfileImageUrl: profileImageUrl,
                              );
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 컬렉션 안의 문서를 나누어 삭제
  Future<void> _deleteCollection(Query<Map<String, dynamic>> query) async {
    while (true) {
      QuerySnapshot<Map<String, dynamic>> snapshot = await query
          .limit(200)
          .get();

      if (snapshot.docs.isEmpty) {
        break;
      }

      WriteBatch batch = FirebaseFirestore.instance.batch();

      for (int i = 0; i < snapshot.docs.length; i++) {
        batch.delete(snapshot.docs[i].reference);
      }

      await batch.commit();

      if (snapshot.docs.length < 200) {
        break;
      }
    }
  }

  /// 스터디 관련 Firestore 데이터 삭제
  Future<void> _deleteStudyData() async {
    FirebaseFirestore firestore = FirebaseFirestore.instance;

    DocumentReference<Map<String, dynamic>> groupDocument = firestore
        .collection('studyGroups')
        .doc(studyId);

    QuerySnapshot<Map<String, dynamic>> quizSnapshot = await groupDocument
        .collection('quizzes')
        .get();

    for (int i = 0; i < quizSnapshot.docs.length; i++) {
      await _deleteCollection(
        quizSnapshot.docs[i].reference.collection('answers'),
      );
    }

    QuerySnapshot<Map<String, dynamic>> memberSnapshot = await groupDocument
        .collection('members')
        .get();

    for (int i = 0; i < memberSnapshot.docs.length; i++) {
      await _deleteCollection(
        memberSnapshot.docs[i].reference.collection('wrongAnswers'),
      );
    }

    await _deleteCollection(groupDocument.collection('quizzes'));

    await _deleteCollection(groupDocument.collection('members'));

    await _deleteCollection(groupDocument.collection('studyRecords'));

    await _deleteCollection(groupDocument.collection('subjects'));

    await _deleteCollection(groupDocument.collection('wakeUps'));

    DocumentReference<Map<String, dynamic>> chatDocument = firestore
        .collection('chats')
        .doc(studyId);

    await _deleteCollection(chatDocument.collection('messages'));

    DocumentSnapshot<Map<String, dynamic>> chatSnapshot = await chatDocument
        .get();

    if (chatSnapshot.exists) {
      await chatDocument.delete();
    }

    await _deleteCollection(
      firestore
          .collection('studyGroupInvites')
          .where('groupId', isEqualTo: studyId),
    );

    await groupDocument.delete();
  }

  /// 스터디 삭제 확인창
  void _showDeleteStudyDialog(
    BuildContext context,
    Map<String, dynamic> groupData,
  ) {
    bool isDeleting = false;

    String displayGroupName = groupData['groupName']?.toString() ?? groupName;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> deleteStudy() async {
              setDialogState(() {
                isDeleting = true;
              });

              try {
                await _deleteStudyData();

                if (!dialogContext.mounted) {
                  return;
                }

                Navigator.pop(dialogContext);

                if (!context.mounted) {
                  return;
                }

                Navigator.pop(context, true);
              } catch (error) {
                debugPrint('스터디 삭제 오류: $error');

                if (!dialogContext.mounted) {
                  return;
                }

                setDialogState(() {
                  isDeleting = false;
                });

                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('스터디를 삭제하지 못했습니다.')));
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              title: Row(
                children: [
                  Icon(
                    Icons.delete_outline,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  SizedBox(width: 10),
                  Text('스터디 삭제'),
                ],
              ),
              content: Text(
                '"$displayGroupName" 스터디를 정말 삭제할까요?\n\n'
                '그룹원, 공부 기록, 채팅, 문제와 초대 정보도 함께 삭제되며 '
                '삭제한 후에는 복구할 수 없습니다.',
                style: TextStyle(height: 1.5),
              ),
              actions: [
                TextButton(
                  onPressed: isDeleting
                      ? null
                      : () {
                          Navigator.pop(dialogContext);
                        },
                  child: Text('취소'),
                ),
                ElevatedButton(
                  onPressed: isDeleting ? null : deleteStudy,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                  child: isDeleting
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        )
                      : Text('삭제'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// 스터디 신고 저장
  Future<void> _saveStudyReport({
    required Map<String, dynamic> groupData,
    required String reasonType,
    required String detail,
  }) async {
    User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      throw Exception('로그인 정보가 없습니다.');
    }

    DocumentSnapshot<Map<String, dynamic>> memberSnapshot =
        await FirebaseFirestore.instance
            .collection('studyGroups')
            .doc(studyId)
            .collection('members')
            .doc(currentUser.uid)
            .get();

    String reporterNickname =
        memberSnapshot.data()?['nickname']?.toString().trim() ?? '';

    if (reporterNickname.isEmpty) {
      reporterNickname = currentUser.displayName?.trim() ?? '';
    }

    if (reporterNickname.isEmpty) {
      reporterNickname = '사용자';
    }

    String targetTitle = groupData['groupName']?.toString() ?? groupName;
    String reportId = 'STUDY_GROUP_${studyId}_${currentUser.uid}';
    DocumentReference<Map<String, dynamic>> reportReference = FirebaseFirestore
        .instance
        .collection('reports')
        .doc(reportId);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      DocumentSnapshot<Map<String, dynamic>> reportSnapshot = await transaction
          .get(reportReference);

      if (reportSnapshot.exists) {
        throw Exception('이미 신고한 스터디입니다.');
      }

      transaction.set(reportReference, {
        'reporterNicname': reporterNickname,
        'reporterUid': currentUser.uid,
        'targetType': 'STUDY_GROUP',
        'targetId': <Map<String, String>>[
          {'type': 'STUDY_GROUP', 'id': studyId},
        ],
        'targettitle': targetTitle,
        'targetNickname': null,
        'targetUid': null,
        'reasonType': reasonType,
        'description': detail.isEmpty ? null : detail,
        'status': 'PENDING',
        'actionType': <String>[],
        'processedBy': null,
        'processedAt': null,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// 스터디 신고창
  /// 스터디 신고창
  Future<void> _showStudyReportDialog(
    BuildContext context,
    Map<String, dynamic> groupData,
  ) async {
    const reasons = <String, String>{
      'SPAM': '스팸',
      'ABUSE': '욕설 또는 괴롭힘',
      'INAPPROPRIATE': '부적절한 콘텐츠',
      'FRAUD': '사기 또는 허위 정보',
      'ETC': '기타',
    };

    final result = await AppReportBottomSheet.show(
      context,
      title: '스터디 신고',
      reasons: reasons,
      descriptionHint: '신고 내용을 입력해 주세요. (선택)',
    );

    if (result == null || !context.mounted) {
      return;
    }

    try {
      await _saveStudyReport(
        groupData: groupData,
        reasonType: result.reasonType,
        detail: result.description,
      );

      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('스터디 신고를 접수했습니다.')));
    } catch (error) {
      debugPrint('스터디 신고 오류: $error');
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  Widget _buildRoomMoreMenu(BuildContext context) {
    User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return SizedBox();
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('studyGroups')
          .doc(studyId)
          .snapshots(),
      builder: (context, groupSnapshot) {
        if (!groupSnapshot.hasData || !groupSnapshot.data!.exists) {
          return SizedBox();
        }

        Map<String, dynamic> groupData = groupSnapshot.data!.data() ?? {};

        String ownerUid = groupData['ownerUid']?.toString() ?? '';

        bool isOwner = ownerUid == currentUser.uid;

        bool isRecruiting = _isRecruiting(groupData);

        if (isOwner) {
          return PopupMenuButton<String>(
            tooltip: '스터디방 관리',
            icon: _buildMoreMenuTrigger(context),
            elevation: 6,
            color: context.colors.surface,
            shadowColor: context.colors.shadow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            padding: EdgeInsets.zero,
            itemBuilder: (context) {
              return [
                PopupMenuItem<String>(
                  height: 46,
                  value: 'joinRequests',
                  child: _buildMenuItemRow(
                    context,
                    Icons.how_to_reg_outlined,
                    '참여 신청 관리',
                    context.colors.softBlue,
                    context.colors.info,
                  ),
                ),
                PopupMenuItem<String>(
                  height: 46,
                  value: 'edit',
                  child: _buildMenuItemRow(
                    context,
                    Icons.edit_outlined,
                    '스터디 정보 수정',
                    context.colors.lavender,
                    context.colors.lavenderAccent,
                  ),
                ),
                PopupMenuItem<String>(
                  height: 46,
                  value: 'recruitment',
                  child: _buildMenuItemRow(
                    context,
                    isRecruiting
                        ? Icons.lock_outline_rounded
                        : Icons.lock_open_rounded,
                    isRecruiting ? '모집 마감' : '모집 다시 시작',
                    context.colors.correctSoft,
                    context.colors.correct,
                  ),
                ),
                PopupMenuItem<String>(
                  height: 46,
                  value: 'transfer',
                  child: _buildMenuItemRow(
                    context,
                    Icons.admin_panel_settings_outlined,
                    '방장 위임',
                    context.colors.warningSoft,
                    context.colors.warning,
                  ),
                ),
                PopupMenuDivider(height: 9),
                PopupMenuItem<String>(
                  height: 46,
                  value: 'delete',
                  child: _buildMenuItemRow(
                    context,
                    Icons.delete_outline,
                    '스터디 삭제',
                    context.colors.incorrectSoft,
                    context.colors.incorrect,
                    isDestructive: true,
                  ),
                ),
              ];
            },
            onSelected: (value) {
              if (value == 'joinRequests') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) {
                      return StudyJoinRequestsPage(studyId: studyId);
                    },
                  ),
                );
              }

              if (value == 'edit') {
                _openStudyEditPage(context, groupData);
              }

              if (value == 'recruitment') {
                _updateRecruitmentStatus(context, groupData, !isRecruiting);
              }

              if (value == 'transfer') {
                _showTransferOwnerSheet(context);
              }

              if (value == 'delete') {
                _showDeleteStudyDialog(context, groupData);
              }
            },
          );
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('studyGroups')
              .doc(studyId)
              .collection('members')
              .doc(currentUser.uid)
              .snapshots(),
          builder: (context, memberSnapshot) {
            String memberStatus =
                memberSnapshot.data?.data()?['status']?.toString() ?? '';

            if (memberStatus != 'ACTIVE') {
              return SizedBox();
            }

            return PopupMenuButton<String>(
              tooltip: '스터디방 메뉴',
              icon: _buildMoreMenuTrigger(context),
              elevation: 6,
              color: context.colors.surface,
              shadowColor: context.colors.shadow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              padding: EdgeInsets.zero,
              itemBuilder: (context) {
                return [
                  PopupMenuItem<String>(
                    height: 46,
                    value: 'report',
                    child: _buildMenuItemRow(
                      context,
                      Icons.report_outlined,
                      '그룹원 신고',
                      context.colors.lavender,
                      context.colors.lavenderAccent,
                    ),
                  ),
                  PopupMenuDivider(height: 9),
                  PopupMenuItem<String>(
                    height: 46,
                    value: 'leave',
                    child: _buildMenuItemRow(
                      context,
                      Icons.logout_rounded,
                      '스터디방 나가기',
                      context.colors.incorrectSoft,
                      context.colors.incorrect,
                      isDestructive: true,
                    ),
                  ),
                ];
              },
              onSelected: (value) {
                if (value == 'report') {
                  _showGroupMemberReportDialog(context);
                }

                if (value == 'leave') {
                  _showLeaveStudyRoomDialog(context);
                }
              },
            );
          },
        );
      },
    );
  }

  Widget _buildStudyGoalCard(
    BuildContext context,
    Map<String, dynamic> groupData,
    bool isOwner,
  ) {
    DateTime? examDate = _getDateTime(groupData['examDate']);

    int weeklyGoalMinutes = _getInt(groupData, 'weeklyGoalMinutes');

    DateTime now = DateTime.now();

    DateTime today = DateTime(now.year, now.month, now.day);

    DateTime weekStart = today.subtract(Duration(days: today.weekday - 1));

    DateTime nextWeekStart = weekStart.add(Duration(days: 7));

    Stream<QuerySnapshot<Map<String, dynamic>>> recordStream = FirebaseFirestore
        .instance
        .collection('studyGroups')
        .doc(studyId)
        .collection('studyRecords')
        .where('endedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart))
        .where('endedAt', isLessThan: Timestamp.fromDate(nextWeekStart))
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: recordStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: 190,
            child: AppLoadingView(message: '주간 목표를 불러오는 중입니다.'),
          );
        }

        if (snapshot.hasError) {
          if (_isNetworkError(snapshot.error)) {
            return SizedBox(
              height: 220,
              child: AppNetworkErrorView(
                message: '인터넷 연결을 확인해 주세요.',
                description: '네트워크 연결 후 주간 목표를 다시 불러와 주세요.',
                onRetryPressed: () {
                  _reloadPage(context);
                },
              ),
            );
          }

          return SizedBox(
            height: 220,
            child: AppErrorView(
              message: '주간 목표를 불러오지 못했습니다.',
              description: '잠시 후 다시 시도해 주세요.',
              onRetryPressed: () {
                _reloadPage(context);
              },
            ),
          );
        }

        int weeklyStudySeconds = 0;

        if (snapshot.data != null) {
          for (int i = 0; i < snapshot.data!.docs.length; i++) {
            weeklyStudySeconds += _getRecordStudySeconds(
              snapshot.data!.docs[i].data(),
            );
          }
        }

        int weeklyGoalSeconds = weeklyGoalMinutes * 60;

        double progress = 0;

        if (weeklyGoalSeconds > 0) {
          progress = weeklyStudySeconds / weeklyGoalSeconds;

          if (progress > 1) {
            progress = 1;
          }
        }

        int progressPercent = (progress * 100).round();

        String ddayText = '시험일 미설정';
        String examDateText = '방장이 스터디방에서 시험일을 설정할 수 있습니다.';

        if (examDate != null) {
          ddayText = _getDdayText(examDate);
          examDateText = '${_formatExamDate(examDate)} 시험';
        }

        String goalText = '주간 목표 미설정';

        if (weeklyGoalMinutes > 0) {
          goalText =
              '${_formatGoalTime(weeklyStudySeconds)} / '
              '${_formatGoalTime(weeklyGoalSeconds)}';
        }

        return AppCard(
          borderRadius: 22,
          padding: EdgeInsets.all(17),
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: context.colors.pinkSoft,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.event_available_rounded,
                      color: context.colors.pinkStart,
                      size: 24,
                    ),
                  ),

                  SizedBox(width: 13),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ddayText,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: context.colors.pinkStart,
                          ),
                        ),

                        SizedBox(height: 4),

                        Text(
                          examDateText,
                          style: TextStyle(
                            fontSize: 11,
                            color: context.colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (isOwner)
                    TextButton(
                      onPressed: () {
                        _showStudyGoalDialog(context, groupData);
                      },
                      child: Text(
                        examDate != null || weeklyGoalMinutes > 0 ? '수정' : '설정',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: context.colors.pinkStart,
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: context.colors.lavender,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        weeklyGoalMinutes > 0 ? '$progressPercent%' : '-',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: context.colors.pinkStart,
                        ),
                      ),
                    ),
                ],
              ),

              SizedBox(height: 18),

              Row(
                children: [
                  Expanded(
                    child: Text(
                      '이번 주 그룹 목표',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: context.colors.textPrimary,
                      ),
                    ),
                  ),

                  Text(
                    goalText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: context.colors.pinkStart,
                    ),
                  ),
                ],
              ),

              SizedBox(height: 10),

              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  minHeight: 9,
                  value: progress,
                  backgroundColor: context.colors.pinkSoft,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    context.colors.pinkStart,
                  ),
                ),
              ),

              SizedBox(height: 9),

              Text(
                weeklyGoalMinutes > 0
                    ? '월요일부터 일요일까지 그룹원 공부시간을 합산합니다.'
                    : '방장이 주간 목표시간을 설정하면 달성률이 표시됩니다.',
                style: TextStyle(
                  fontSize: 10,
                  height: 1.4,
                  color: context.colors.textSecondary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatChatTime(dynamic createdAt) {
    if (createdAt is! Timestamp) {
      return '';
    }

    DateTime dateTime = createdAt.toDate().toLocal();
    DateTime now = DateTime.now();

    bool isToday =
        dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day;

    if (isToday) {
      String hour = dateTime.hour.toString().padLeft(2, '0');
      String minute = dateTime.minute.toString().padLeft(2, '0');

      return '$hour:$minute';
    }

    if (dateTime.year == now.year) {
      return '${dateTime.month}/${dateTime.day}';
    }

    return '${dateTime.year}.${dateTime.month}.${dateTime.day}';
  }

  String _getFirstLetter(String nickname) {
    if (nickname.isEmpty) {
      return '?';
    }

    return nickname.substring(0, 1).toUpperCase();
  }

  Widget _buildProfileImage(
    BuildContext context,
    String nickname,
    String profileImageUrl,
    bool isOwner,
  ) {
    Widget profile;

    if (profileImageUrl.isNotEmpty) {
      profile = CircleAvatar(
        radius: 28,
        backgroundColor: context.colors.lavender,
        backgroundImage: NetworkImage(profileImageUrl),
      );
    } else {
      profile = CircleAvatar(
        radius: 28,
        backgroundColor: context.colors.lavender,
        child: Text(
          _getFirstLetter(nickname),
          style: TextStyle(
            color: context.colors.pinkStart,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        profile,
        Visibility(
          visible: isOwner,
          child: Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 21,
              height: 21,
              decoration: BoxDecoration(
                color: context.colors.pinkStart,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.onPrimary,
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.star_rounded,
                size: 12,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMemberProfiles(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('studyGroups')
          .doc(studyId)
          .collection('members')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: 180,
            child: AppLoadingView(message: '그룹원을 불러오는 중입니다.'),
          );
        }

        if (snapshot.hasError) {
          if (_isNetworkError(snapshot.error)) {
            return SizedBox(
              height: 220,
              child: AppNetworkErrorView(
                message: '인터넷 연결을 확인해 주세요.',
                description: '네트워크 연결 후 그룹원을 다시 불러와 주세요.',
                onRetryPressed: () {
                  _reloadPage(context);
                },
              ),
            );
          }

          return SizedBox(
            height: 220,
            child: AppErrorView(
              message: '그룹원을 불러오지 못했습니다.',
              description: '잠시 후 다시 시도해 주세요.',
              onRetryPressed: () {
                _reloadPage(context);
              },
            ),
          );
        }

        List<QueryDocumentSnapshot<Map<String, dynamic>>> memberList = [];

        if (snapshot.data != null) {
          for (int i = 0; i < snapshot.data!.docs.length; i++) {
            QueryDocumentSnapshot<Map<String, dynamic>> memberDocument =
                snapshot.data!.docs[i];

            Map<String, dynamic> memberData = memberDocument.data();

            String status = memberData['status']?.toString() ?? '';
            String role = memberData['role']?.toString() ?? 'MEMBER';

            if (status == 'ACTIVE' || role == 'OWNER') {
              memberList.add(memberDocument);
            }
          }
        }

        memberList.sort((a, b) {
          String aRole = a.data()['role']?.toString() ?? 'MEMBER';
          String bRole = b.data()['role']?.toString() ?? 'MEMBER';

          if (aRole == 'OWNER' && bRole != 'OWNER') {
            return -1;
          }

          if (aRole != 'OWNER' && bRole == 'OWNER') {
            return 1;
          }

          return 0;
        });

        if (memberList.isEmpty) {
          return SizedBox(
            height: 220,
            child: AppEmptyView(
              message: '참여 중인 그룹원이 없습니다.',
              description: '새로운 그룹원이 참여하면 이곳에 표시됩니다.',
            ),
          );
        }

        return SizedBox(
          height: 92,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: memberList.length,
            itemBuilder: (context, index) {
              Map<String, dynamic> memberData = memberList[index].data();

              String nickname = memberData['nickname']?.toString() ?? '스터디원';

              String role = memberData['role']?.toString() ?? 'MEMBER';

              String profileImageUrl =
                  memberData['profileImageUrl']?.toString() ?? '';

              bool isOwner = role == 'OWNER';

              return Container(
                width: 72,
                margin: EdgeInsets.only(right: 10),
                child: Column(
                  children: [
                    _buildProfileImage(
                      context,
                      nickname,
                      profileImageUrl,
                      isOwner,
                    ),
                    SizedBox(height: 7),
                    CachedNicknameText(
                      uid: memberList[index].id,
                      fallback: nickname,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: context.colors.textSecondary,
                        fontWeight: isOwner
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  String _getMemberUid(Map<String, dynamic> memberData) {
    String uid = memberData['uid']?.toString() ?? '';

    if (uid.isEmpty) {
      uid = memberData['_documentUid']?.toString() ?? '';
    }

    return uid;
  }

  String _getMemberStudyStatus(Map<String, dynamic> memberData) {
    String studyStatus = memberData['studyStatus']?.toString() ?? '';

    if (studyStatus == 'STUDYING' ||
        studyStatus == 'RESTING' ||
        studyStatus == 'PAUSED' ||
        studyStatus == 'IDLE') {
      return studyStatus;
    }

    bool timerSessionActive = memberData['timerSessionActive'] == true;

    if (timerSessionActive && memberData['timerPaused'] == true) {
      return 'PAUSED';
    }

    if (memberData['isResting'] == true) {
      return 'RESTING';
    }

    if (memberData['isStudying'] == true) {
      return 'STUDYING';
    }

    return 'IDLE';
  }

  int _getMemberStatusOrder(Map<String, dynamic> memberData) {
    String studyStatus = _getMemberStudyStatus(memberData);

    if (studyStatus == 'STUDYING') {
      return 0;
    }

    if (studyStatus == 'RESTING') {
      return 1;
    }

    if (studyStatus == 'PAUSED') {
      return 2;
    }

    return 3;
  }

  String _getMemberStatusText(Map<String, dynamic> memberData) {
    String studyStatus = _getMemberStudyStatus(memberData);

    if (studyStatus == 'STUDYING') {
      return '공부 중';
    }

    if (studyStatus == 'RESTING') {
      return '휴식 중';
    }

    if (studyStatus == 'PAUSED') {
      return '일시정지';
    }

    return '대기 중';
  }

  Color _getMemberStatusBackgroundColor(
    BuildContext context,
    Map<String, dynamic> memberData,
  ) {
    String studyStatus = _getMemberStudyStatus(memberData);

    if (studyStatus == 'STUDYING') {
      return context.colors.mint;
    }

    if (studyStatus == 'RESTING') {
      return context.colors.softBlue;
    }

    if (studyStatus == 'PAUSED') {
      return context.colors.lavender;
    }

    return Theme.of(context).colorScheme.surface;
  }

  Color _getMemberStatusTextColor(
    BuildContext context,
    Map<String, dynamic> memberData,
  ) {
    String studyStatus = _getMemberStudyStatus(memberData);

    if (studyStatus == 'STUDYING') {
      return Theme.of(context).colorScheme.tertiary;
    }

    if (studyStatus == 'RESTING') {
      return Theme.of(context).colorScheme.secondaryContainer;
    }

    if (studyStatus == 'PAUSED') {
      return context.colors.pinkStart;
    }

    return context.colors.textSecondary;
  }

  String _getMemberTimerModeText(Map<String, dynamic> memberData) {
    String timerMode = memberData['timerMode']?.toString() ?? '';

    if (timerMode.isEmpty) {
      timerMode = memberData['lastTimerMode']?.toString() ?? '';
    }

    if (timerMode == 'POMODORO') {
      return '포모도로';
    }

    if (timerMode == 'STOPWATCH') {
      return '스톱워치';
    }

    return '';
  }

  String _getMemberCurrentSubject(Map<String, dynamic> memberData) {
    String subject = memberData['studySubject']?.toString() ?? '';

    if (subject.isEmpty) {
      subject = memberData['currentSubject']?.toString() ?? '';
    }

    if (subject.isEmpty) {
      subject = memberData['lastStudySubject']?.toString() ?? '';
    }

    return subject;
  }

  int _getMemberLiveStudySeconds(Map<String, dynamic> memberData) {
    int studySeconds = _getInt(memberData, 'timerStudySeconds');

    String studyStatus = _getMemberStudyStatus(memberData);

    bool isOldTimer =
        memberData['timerSessionActive'] != true &&
        memberData['isStudying'] == true;

    DateTime? segmentStartedAt = _getDateTime(
      memberData['timerSegmentStartedAt'],
    );

    if (segmentStartedAt == null && isOldTimer) {
      segmentStartedAt = _getDateTime(memberData['studyStartedAt']);
    }

    if (studyStatus == 'STUDYING' && segmentStartedAt != null) {
      int runningSeconds = DateTime.now()
          .difference(segmentStartedAt)
          .inSeconds;

      if (runningSeconds > 0) {
        studySeconds += runningSeconds;
      }
    }

    return studySeconds;
  }

  int _getMemberLiveRestSeconds(Map<String, dynamic> memberData) {
    int restSeconds = _getInt(memberData, 'timerRestSeconds');

    String studyStatus = _getMemberStudyStatus(memberData);

    DateTime? segmentStartedAt = _getDateTime(
      memberData['timerSegmentStartedAt'],
    );

    if (studyStatus == 'RESTING' && segmentStartedAt != null) {
      int runningSeconds = DateTime.now()
          .difference(segmentStartedAt)
          .inSeconds;

      if (runningSeconds > 0) {
        restSeconds += runningSeconds;
      }
    }

    return restSeconds;
  }

  int _getMemberFocusScore(Map<String, dynamic> memberData) {
    int focusExitCount = _getInt(memberData, 'focusExitCount');

    int pauseCount = _getInt(memberData, 'pauseCount');

    String studyStatus = _getMemberStudyStatus(memberData);

    if (studyStatus == 'IDLE' && memberData['lastFocusScore'] is num) {
      int lastFocusScore = (memberData['lastFocusScore'] as num).toInt();

      if (lastFocusScore < 0) {
        return 0;
      }

      if (lastFocusScore > 100) {
        return 100;
      }

      return lastFocusScore;
    }

    int focusScore = 100 - (focusExitCount * 10) - (pauseCount * 3);

    if (focusScore < 0) {
      return 0;
    }

    return focusScore;
  }

  Widget _buildLiveStatusCount(
    String label,
    int count,
    Color backgroundColor,
    Color textColor,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        '$label $count명',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildLiveMemberStatusCard(
    BuildContext context,
    Map<String, dynamic> memberData,
    int todaySavedSeconds,
  ) {
    String nickname = memberData['nickname']?.toString() ?? '스터디원';

    String role = memberData['role']?.toString() ?? 'MEMBER';

    String profileImageUrl = memberData['profileImageUrl']?.toString() ?? '';

    bool isOwner = role == 'OWNER';

    String studyStatus = _getMemberStudyStatus(memberData);

    String statusText = _getMemberStatusText(memberData);

    String subject = _getMemberCurrentSubject(memberData);

    String timerModeText = _getMemberTimerModeText(memberData);

    int liveStudySeconds = _getMemberLiveStudySeconds(memberData);

    int liveRestSeconds = _getMemberLiveRestSeconds(memberData);

    int todayTotalSeconds = todaySavedSeconds + liveStudySeconds;

    int focusExitCount = _getInt(memberData, 'focusExitCount');

    int focusScore = _getMemberFocusScore(memberData);

    String detailText = '현재 공부하지 않음';

    if (studyStatus == 'STUDYING') {
      if (subject.isEmpty) {
        subject = '과목 미지정';
      }

      detailText = '$subject · ${_formatStudyTime(liveStudySeconds)}';
    } else if (studyStatus == 'RESTING') {
      detailText = '포모도로 휴식 · ${_formatStudyTime(liveRestSeconds)}';
    } else if (studyStatus == 'PAUSED') {
      if (subject.isEmpty) {
        subject = '과목 미지정';
      }

      detailText = '$subject · 공부 ${_formatStudyTime(liveStudySeconds)}';
    } else if (todaySavedSeconds > 0) {
      detailText = '오늘 ${_formatStudyTime(todaySavedSeconds)} 공부';
    }

    return Container(
      margin: EdgeInsets.only(bottom: 9),
      padding: EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          _buildProfileImage(context, nickname, profileImageUrl, isOwner),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: CachedNicknameText(
                        uid: _getMemberUid(memberData),
                        fallback: nickname,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: context.colors.textPrimary,
                        ),
                      ),
                    ),
                    SizedBox(width: 7),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getMemberStatusBackgroundColor(
                          context,
                          memberData,
                        ),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: _getMemberStatusTextColor(context, memberData),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 5),
                Text(
                  detailText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: context.colors.textSecondary,
                  ),
                ),
                if (timerModeText.isNotEmpty && studyStatus != 'IDLE') ...[
                  SizedBox(height: 3),
                  Text(
                    '$timerModeText · 앱 이탈 $focusExitCount회',
                    style: TextStyle(
                      fontSize: 10,
                      color: context.colors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatStudyTime(todayTotalSeconds),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: context.colors.pinkStart,
                ),
              ),
              SizedBox(height: 4),
              Text(
                studyStatus == 'IDLE' ? '오늘 누적' : '집중 $focusScore점',
                style: TextStyle(
                  fontSize: 9,
                  color: context.colors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTodayStudySummary(
    BuildContext context,
    String displayGroupName,
  ) {
    DateTime now = DateTime.now();

    DateTime todayStart = DateTime(now.year, now.month, now.day);

    DateTime tomorrowStart = todayStart.add(Duration(days: 1));

    Stream<QuerySnapshot<Map<String, dynamic>>> memberStream = FirebaseFirestore
        .instance
        .collection('studyGroups')
        .doc(studyId)
        .collection('members')
        .snapshots();

    Stream<QuerySnapshot<Map<String, dynamic>>> recordStream = FirebaseFirestore
        .instance
        .collection('studyGroups')
        .doc(studyId)
        .collection('studyRecords')
        .where(
          'endedAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart),
        )
        .where('endedAt', isLessThan: Timestamp.fromDate(tomorrowStart))
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: memberStream,
      builder: (context, memberSnapshot) {
        if (memberSnapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: 180,
            child: AppLoadingView(message: '오늘의 학습 현황을 불러오는 중입니다.'),
          );
        }

        if (memberSnapshot.hasError) {
          if (_isNetworkError(memberSnapshot.error)) {
            return SizedBox(
              height: 220,
              child: AppNetworkErrorView(
                message: '인터넷 연결을 확인해 주세요.',
                description: '네트워크 연결 후 오늘의 학습 현황을 다시 불러와 주세요.',
                onRetryPressed: () {
                  _reloadPage(context);
                },
              ),
            );
          }

          return SizedBox(
            height: 220,
            child: AppErrorView(
              message: '오늘의 학습 현황을 불러오지 못했습니다.',
              description: '잠시 후 다시 시도해 주세요.',
              onRetryPressed: () {
                _reloadPage(context);
              },
            ),
          );
        }

        List<Map<String, dynamic>> activeMemberList = [];

        if (memberSnapshot.data != null) {
          for (int i = 0; i < memberSnapshot.data!.docs.length; i++) {
            QueryDocumentSnapshot<Map<String, dynamic>> memberDocument =
                memberSnapshot.data!.docs[i];

            Map<String, dynamic> memberData = Map<String, dynamic>.from(
              memberDocument.data(),
            );

            String status = memberData['status']?.toString() ?? '';

            String role = memberData['role']?.toString() ?? 'MEMBER';

            if (status == 'ACTIVE' || role == 'OWNER') {
              memberData['_documentUid'] = memberDocument.id;

              activeMemberList.add(memberData);
            }
          }
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: recordStream,
          builder: (context, recordSnapshot) {
            if (recordSnapshot.connectionState == ConnectionState.waiting) {
              return SizedBox(
                height: 180,
                child: AppLoadingView(message: '오늘의 공부 기록을 불러오는 중입니다.'),
              );
            }

            if (recordSnapshot.hasError) {
              if (_isNetworkError(recordSnapshot.error)) {
                return SizedBox(
                  height: 220,
                  child: AppNetworkErrorView(
                    message: '인터넷 연결을 확인해 주세요.',
                    description: '네트워크 연결 후 오늘의 공부 기록을 다시 불러와 주세요.',
                    onRetryPressed: () {
                      _reloadPage(context);
                    },
                  ),
                );
              }

              return SizedBox(
                height: 220,
                child: AppErrorView(
                  message: '오늘의 공부 기록을 불러오지 못했습니다.',
                  description: '잠시 후 다시 시도해 주세요.',
                  onRetryPressed: () {
                    _reloadPage(context);
                  },
                ),
              );
            }

            Map<String, int> todaySavedSecondsMap = {};

            if (recordSnapshot.data != null) {
              for (int i = 0; i < recordSnapshot.data!.docs.length; i++) {
                Map<String, dynamic> recordData = recordSnapshot.data!.docs[i]
                    .data();

                String uid = recordData['uid']?.toString() ?? '';

                if (uid.isEmpty) {
                  continue;
                }

                int previousSeconds = todaySavedSecondsMap[uid] ?? 0;

                todaySavedSecondsMap[uid] =
                    previousSeconds + _getRecordStudySeconds(recordData);
              }
            }

            int studyingCount = 0;
            int restingCount = 0;
            int pausedCount = 0;
            int todayStudySeconds = 0;

            Set<String> todayMemberUidSet = {};

            for (int i = 0; i < activeMemberList.length; i++) {
              Map<String, dynamic> memberData = activeMemberList[i];

              String uid = _getMemberUid(memberData);

              String studyStatus = _getMemberStudyStatus(memberData);

              int savedSeconds = todaySavedSecondsMap[uid] ?? 0;

              int liveStudySeconds = _getMemberLiveStudySeconds(memberData);

              int memberTodaySeconds = savedSeconds + liveStudySeconds;

              todayStudySeconds += memberTodaySeconds;

              if (memberTodaySeconds > 0 && uid.isNotEmpty) {
                todayMemberUidSet.add(uid);
              }

              if (studyStatus == 'STUDYING') {
                studyingCount++;
              } else if (studyStatus == 'RESTING') {
                restingCount++;
              } else if (studyStatus == 'PAUSED') {
                pausedCount++;
              }
            }

            activeMemberList.sort((a, b) {
              int aStatusOrder = _getMemberStatusOrder(a);

              int bStatusOrder = _getMemberStatusOrder(b);

              if (aStatusOrder != bStatusOrder) {
                return aStatusOrder.compareTo(bStatusOrder);
              }

              String aUid = _getMemberUid(a);

              String bUid = _getMemberUid(b);

              int aSeconds =
                  (todaySavedSecondsMap[aUid] ?? 0) +
                  _getMemberLiveStudySeconds(a);

              int bSeconds =
                  (todaySavedSecondsMap[bUid] ?? 0) +
                  _getMemberLiveStudySeconds(b);

              return bSeconds.compareTo(aSeconds);
            });

            return AppCard(
              borderRadius: 22,
              padding: EdgeInsets.all(16),
              backgroundColor: context.colors.lavender,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 39,
                        height: 39,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(
                          Icons.insights_rounded,
                          size: 20,
                          color: context.colors.pinkStart,
                        ),
                      ),
                      SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '실시간 학습 현황',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: context.colors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              '공부·휴식·일시정지 상태를 바로 확인해요.',
                              style: TextStyle(
                                fontSize: 10,
                                color: context.colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 14),

                  Row(
                    children: [
                      _buildRoomMetric(
                        context,
                        Icons.schedule_rounded,
                        '오늘 그룹시간',
                        _formatStudyTime(todayStudySeconds),
                      ),
                      SizedBox(width: 8),
                      _buildRoomMetric(
                        context,
                        Icons.person_outline_rounded,
                        '공부한 멤버',
                        '${todayMemberUidSet.length}명',
                      ),
                    ],
                  ),

                  SizedBox(height: 11),

                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      _buildLiveStatusCount(
                        '공부 중',
                        studyingCount,
                        context.colors.mint,
                        Theme.of(context).colorScheme.tertiary,
                      ),
                      _buildLiveStatusCount(
                        '휴식 중',
                        restingCount,
                        context.colors.softBlue,
                        Theme.of(context).colorScheme.secondaryContainer,
                      ),
                      _buildLiveStatusCount(
                        '일시정지',
                        pausedCount,
                        context.colors.lavender,
                        context.colors.pinkStart,
                      ),
                    ],
                  ),

                  SizedBox(height: 15),

                  if (activeMemberList.isEmpty)
                    SizedBox(
                      height: 180,
                      child: AppEmptyView(
                        message: '참여 중인 그룹원이 없습니다.',
                        description: '그룹원이 참여하면 실시간 학습 상태가 표시됩니다.',
                      ),
                    )
                  else
                    for (int i = 0; i < activeMemberList.length; i++)
                      _buildLiveMemberStatusCard(
                        context,
                        activeMemberList[i],
                        todaySavedSecondsMap[_getMemberUid(
                              activeMemberList[i],
                            )] ??
                            0,
                      ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildChatActivityButton(
    BuildContext context,
    String displayGroupName,
  ) {
    User? currentUser = FirebaseAuth.instance.currentUser;
    String currentUserUid = '';

    if (currentUser != null) {
      currentUserUid = currentUser.uid;
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .doc(studyId)
          .collection('messages')
          .orderBy('createdAt', descending: true)
          .limit(100)
          .snapshots(),
      builder: (context, snapshot) {
        String lastMessage = '아직 메시지가 없습니다.';
        String lastMessageTime = '';
        int unreadCount = 0;

        if (snapshot.connectionState == ConnectionState.waiting) {
          lastMessage = '채팅을 불러오는 중입니다.';
        } else if (snapshot.hasError) {
          if (_isNetworkError(snapshot.error)) {
            lastMessage = '인터넷 연결을 확인해 주세요.';
          } else {
            lastMessage = '채팅을 불러오지 못했습니다.';
          }
        } else if (snapshot.data != null) {
          bool foundLastMessage = false;

          for (int i = 0; i < snapshot.data!.docs.length; i++) {
            QueryDocumentSnapshot<Map<String, dynamic>> messageDocument =
                snapshot.data!.docs[i];

            Map<String, dynamic> messageData = messageDocument.data();

            List<dynamic> hiddenFor = [];

            if (messageData['hiddenFor'] is List) {
              hiddenFor = messageData['hiddenFor'];
            }

            if (hiddenFor.contains(currentUserUid)) {
              continue;
            }

            String senderUid = messageData['senderUid']?.toString() ?? '';

            List<dynamic> readBy = [];

            if (messageData['readBy'] is List) {
              readBy = messageData['readBy'];
            }

            bool isDeleted = messageData['isDeleted'] == true;

            if (isDeleted == false &&
                senderUid != currentUserUid &&
                readBy.contains(currentUserUid) == false) {
              unreadCount++;
            }

            if (foundLastMessage == false) {
              String senderNickname =
                  messageData['senderNickname']?.toString() ?? '스터디원';

              String message = messageData['message']?.toString() ?? '';

              if (isDeleted) {
                lastMessage = '삭제된 메시지입니다.';
              } else if (senderUid == currentUserUid) {
                lastMessage = '나: $message';
              } else {
                lastMessage = '$senderNickname: $message';
              }

              lastMessageTime = _formatChatTime(messageData['createdAt']);

              foundLastMessage = true;
            }
          }
        }

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) {
                  return StudyChatPage(
                    studyId: studyId,
                    groupName: displayGroupName,
                  );
                },
              ),
            );
          },
          child: AppCard(
            borderRadius: 22,
            padding: EdgeInsets.all(17),
            backgroundColor: Theme.of(context).colorScheme.surface,
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: context.colors.softBlue,
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Icon(
                    Icons.forum_rounded,
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    size: 25,
                  ),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '그룹 채팅',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: context.colors.textPrimary,
                              ),
                            ),
                          ),
                          Visibility(
                            visible: lastMessageTime.isNotEmpty,
                            child: Text(
                              lastMessageTime,
                              style: TextStyle(
                                fontSize: 11,
                                color: context.colors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 7),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              lastMessage,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: context.colors.textSecondary,
                              ),
                            ),
                          ),
                          Visibility(
                            visible: unreadCount > 0,
                            child: Container(
                              margin: EdgeInsets.only(left: 10),
                              constraints: BoxConstraints(
                                minWidth: 24,
                                minHeight: 24,
                              ),
                              alignment: Alignment.center,
                              padding: EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: context.colors.pinkStart,
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: Text(
                                unreadCount > 99 ? '99+' : '$unreadCount',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: context.colors.textSecondary,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStudyRecordButton(
    BuildContext context,
    String displayGroupName,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) {
              return StudyRecordPage(
                studyId: studyId,
                groupName: displayGroupName,
              );
            },
          ),
        );
      },
      child: AppCard(
        borderRadius: 21,
        padding: EdgeInsets.all(15),
        backgroundColor: Theme.of(context).colorScheme.surface,
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: context.colors.mint,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.bar_chart_rounded,
                color: Theme.of(context).colorScheme.tertiary,
                size: 25,
              ),
            ),
            SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '나의 공부 기록',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    '오늘·이번 주·이번 달 기록 보기',
                    style: TextStyle(
                      fontSize: 11,
                      color: context.colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: context.colors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityButton(
    BuildContext context,
    IconData icon,
    String title,
    String description,
    Color backgroundColor,
    Color iconColor,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          height: 128,
          child: AppCard(
            borderRadius: 21,
            padding: EdgeInsets.all(15),
            backgroundColor: Theme.of(context).colorScheme.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                Spacer(),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: context.colors.textPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPrimaryStudyButton(
    BuildContext context,
    String displayGroupName,
  ) {
    return AppButton(
      text: '지금 공부 시작하기',
      type: AppButtonType.primaryPink,
      height: 56,
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) {
              return StudyTimerPage(
                studyId: studyId,
                groupName: displayGroupName,
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _kickMemberFromRoom({
    required BuildContext context,
    required String memberUid,
    required String nickname,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      throw Exception('로그인 정보가 없습니다.');
    }

    final currentNickname = await UserProfileCacheService.instance
        .resolveNickname(uid: memberUid, fallback: nickname);
    if (!context.mounted) {
      return;
    }

    final shouldKick =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              backgroundColor: context.colors.surface,
              surfaceTintColor: Colors.transparent,
              shape: appDialogShape,
              title: AppDialogTitle(
                icon: Icons.person_remove_outlined,
                title: '그룹원 추방',
                isDestructive: true,
              ),
              content: Text(
                '$currentNickname 님을 스터디에서 추방할까요?\n\n'
                '추방된 사용자는 이 스터디에 다시 참여할 수 없습니다.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text('취소'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                  child: Text('추방'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!shouldKick) {
      return;
    }

    final groupDocument = FirebaseFirestore.instance
        .collection('studyGroups')
        .doc(studyId);
    final memberDocument = groupDocument.collection('members').doc(memberUid);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final groupSnapshot = await transaction.get(groupDocument);
      final memberSnapshot = await transaction.get(memberDocument);

      if (!groupSnapshot.exists || !memberSnapshot.exists) {
        throw Exception('그룹원 정보를 찾을 수 없습니다.');
      }

      final groupData = groupSnapshot.data() ?? <String, dynamic>{};
      final memberData = memberSnapshot.data() ?? <String, dynamic>{};

      if (groupData['ownerUid']?.toString() != currentUser.uid) {
        throw Exception('방장만 그룹원을 추방할 수 있습니다.');
      }
      if (memberUid == currentUser.uid ||
          memberData['role']?.toString() == 'OWNER') {
        throw Exception('방장은 추방할 수 없습니다.');
      }
      if (memberData['status']?.toString() != 'ACTIVE') {
        throw Exception('이미 활동 중인 그룹원이 아닙니다.');
      }

      final currentMemberCount = _getInt(groupData, 'currentMemberCount');
      final newMemberCount = currentMemberCount > 1
          ? currentMemberCount - 1
          : 1;
      final isCompleted = groupData['status']?.toString() == 'COMPLETED';

      transaction.update(memberDocument, {
        'status': 'BANNED',
        'isStudying': false,
        'isResting': false,
        'studyStatus': 'IDLE',
        'bannedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.update(groupDocument, {
        'currentMemberCount': newMemberCount,
        'status': isCompleted ? 'COMPLETED' : 'RECRUITING',
        'recruitmentStatus': isCompleted ? 'CLOSED' : 'OPEN',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$currentNickname 님을 추방했습니다.')));
    }
  }

  Future<void> _showMemberReportDialog({
    required BuildContext context,
    required String memberUid,
    required String nickname,
  }) async {
    const reasons = <String, String>{
      'SPAM': '스팸',
      'ABUSE': '욕설 또는 괴롭힘',
      'INAPPROPRIATE': '부적절한 콘텐츠',
      'FRAUD': '사기 또는 허위 정보',
      'ETC': '기타',
    };
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || currentUser.uid == memberUid) {
      return;
    }

    final currentTargetNickname = await UserProfileCacheService.instance
        .resolveNickname(uid: memberUid, fallback: nickname);
    if (!context.mounted) {
      return;
    }

    final result = await AppReportBottomSheet.show(
      context,
      title: '$currentTargetNickname 님 신고',
      reasons: reasons,
      descriptionHint: '신고 내용을 입력해 주세요. (선택)',
    );
    if (result == null || !context.mounted) {
      return;
    }

    try {
      var reporterNickname = await UserProfileCacheService.instance
          .resolveNickname(
            uid: currentUser.uid,
            fallback: currentUser.displayName ?? '사용자',
          );
      if (reporterNickname.isEmpty) {
        reporterNickname = currentUser.displayName?.trim() ?? '';
      }
      if (reporterNickname.isEmpty) {
        reporterNickname = '사용자';
      }

      final reportReference = FirebaseFirestore.instance
          .collection('reports')
          .doc('STUDY_MEMBER_${studyId}_${currentUser.uid}_$memberUid');
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final reportSnapshot = await transaction.get(reportReference);
        if (reportSnapshot.exists) {
          throw Exception('이미 신고한 스터디원입니다.');
        }
        transaction.set(reportReference, {
          'reporterNicname': reporterNickname,
          'reporterUid': currentUser.uid,
          'targetType': 'STUDY_MEMBER',
          'targetId': null,
          'targettitle': currentTargetNickname,
          'targetNickname': currentTargetNickname,
          'targetUid': memberUid,
          'reasonType': result.reasonType,
          'description': result.description.isEmpty ? null : result.description,
          'status': 'PENDING',
          'actionType': <String>[],
          'processedBy': null,
          'processedAt': null,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('신고가 접수되었습니다.')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    }
  }

  Future<void> _showGroupMemberReportDialog(BuildContext context) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return;
    }

    QuerySnapshot<Map<String, dynamic>> memberSnapshot;
    try {
      memberSnapshot = await FirebaseFirestore.instance
          .collection('studyGroups')
          .doc(studyId)
          .collection('members')
          .get();
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('그룹원 정보를 불러오지 못했습니다.')));
      }
      return;
    }

    final reportableMembers = memberSnapshot.docs.where((document) {
      final data = document.data();
      return document.id != currentUser.uid &&
          data['status']?.toString() == 'ACTIVE';
    }).toList();

    reportableMembers.sort((a, b) {
      final aIsOwner = a.data()['role']?.toString() == 'OWNER';
      final bIsOwner = b.data()['role']?.toString() == 'OWNER';
      if (aIsOwner != bIsOwner) {
        return aIsOwner ? -1 : 1;
      }

      final aNickname = a.data()['nickname']?.toString() ?? '스터디원';
      final bNickname = b.data()['nickname']?.toString() ?? '스터디원';
      return aNickname.compareTo(bNickname);
    });

    if (!context.mounted) {
      return;
    }

    if (reportableMembers.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('신고할 수 있는 그룹원이 없습니다.')));
      return;
    }

    String selectedMemberUid = reportableMembers.first.id;
    final selectedUid = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AppAlertDialog(
              icon: Icons.report_outlined,
              isDestructive: true,
              title: const Text('그룹원 신고'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '신고할 그룹원을 선택해 주세요.',
                      style: TextStyle(color: context.colors.textSecondary),
                    ),
                    const SizedBox(height: 14),
                    AppUserDropdown<String>(
                      label: '신고할 그룹원',
                      value: selectedMemberUid,
                      items: reportableMembers.map((document) {
                        final data = document.data();
                        final nickname = data['nickname']?.toString() ?? '스터디원';
                        final isOwner = data['role']?.toString() == 'OWNER';
                        return AppDropdownItem<String>(
                          value: document.id,
                          label: isOwner ? '$nickname (방장)' : nickname,
                        );
                      }).toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedMemberUid = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('취소'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, selectedMemberUid);
                  },
                  child: const Text('다음'),
                ),
              ],
            );
          },
        );
      },
    );

    if (selectedUid == null || !context.mounted) {
      return;
    }

    final selectedMember = reportableMembers.firstWhere(
      (document) => document.id == selectedUid,
    );
    final selectedNickname =
        selectedMember.data()['nickname']?.toString() ?? '스터디원';

    await _showMemberReportDialog(
      context: context,
      memberUid: selectedUid,
      nickname: selectedNickname,
    );
  }

  void _openMemberList(BuildContext context) {
    final currentUserUid = FirebaseAuth.instance.currentUser?.uid;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.72,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: Column(
            children: [
              SizedBox(height: 11),
              Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(20, 18, 12, 14),
                child: Row(
                  children: [
                    Icon(
                      Icons.groups_outlined,
                      color: context.colors.pinkStart,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '그룹원 목록',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        Navigator.pop(bottomSheetContext);
                      },
                      icon: Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Divider(height: 1),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('studyGroups')
                      .doc(studyId)
                      .collection('members')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return AppLoadingView(message: '그룹원 목록을 불러오는 중입니다.');
                    }

                    if (snapshot.hasError) {
                      if (_isNetworkError(snapshot.error)) {
                        return AppNetworkErrorView(
                          message: '인터넷 연결을 확인해 주세요.',
                          description: '네트워크 연결 후 그룹원 목록을 다시 불러와 주세요.',
                          onRetryPressed: () {
                            Navigator.pop(bottomSheetContext);
                            _openMemberList(context);
                          },
                        );
                      }

                      return AppErrorView(
                        message: '그룹원 목록을 불러오지 못했습니다.',
                        description: '잠시 후 다시 시도해 주세요.',
                        onRetryPressed: () {
                          Navigator.pop(bottomSheetContext);
                          _openMemberList(context);
                        },
                      );
                    }

                    List<QueryDocumentSnapshot<Map<String, dynamic>>>
                    memberList = [];

                    if (snapshot.data != null) {
                      for (int i = 0; i < snapshot.data!.docs.length; i++) {
                        QueryDocumentSnapshot<Map<String, dynamic>>
                        memberDocument = snapshot.data!.docs[i];

                        Map<String, dynamic> memberData = memberDocument.data();

                        String status = memberData['status']?.toString() ?? '';

                        String role =
                            memberData['role']?.toString() ?? 'MEMBER';

                        if (status == 'ACTIVE' || role == 'OWNER') {
                          memberList.add(memberDocument);
                        }
                      }
                    }

                    memberList.sort((a, b) {
                      String aRole = a.data()['role']?.toString() ?? 'MEMBER';
                      String bRole = b.data()['role']?.toString() ?? 'MEMBER';

                      if (aRole == 'OWNER' && bRole != 'OWNER') {
                        return -1;
                      }

                      if (aRole != 'OWNER' && bRole == 'OWNER') {
                        return 1;
                      }

                      return 0;
                    });

                    if (memberList.isEmpty) {
                      return AppEmptyView(
                        message: '등록된 그룹원이 없습니다.',
                        description: '새로운 그룹원이 참여하면 이곳에 표시됩니다.',
                      );
                    }

                    final currentUid =
                        FirebaseAuth.instance.currentUser?.uid ?? '';
                    final canManageMembers = memberList.any(
                      (document) =>
                          document.id == currentUid &&
                          document.data()['role']?.toString() == 'OWNER',
                    );

                    return ListView.builder(
                      padding: EdgeInsets.fromLTRB(18, 16, 18, 30),
                      itemCount: memberList.length,
                      itemBuilder: (context, index) {
                        Map<String, dynamic> memberData = memberList[index]
                            .data();

                        String nickname =
                            memberData['nickname']?.toString() ?? '스터디원';

                        String role =
                            memberData['role']?.toString() ?? 'MEMBER';

                        String profileImageUrl =
                            memberData['profileImageUrl']?.toString() ?? '';

                        int totalStudySeconds = _getTotalStudySeconds(
                          memberData,
                        );

                        bool isOwner = role == 'OWNER';
                        String memberUid = memberList[index].id;

                        return Container(
                          margin: EdgeInsets.only(bottom: 11),
                          padding: EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.outlineVariant,
                            ),
                          ),
                          child: Row(
                            children: [
                              _buildProfileImage(
                                context,
                                nickname,
                                profileImageUrl,
                                isOwner,
                              ),
                              SizedBox(width: 13),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CachedNicknameText(
                                          uid: memberUid,
                                          fallback: nickname,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Visibility(
                                          visible: isOwner,
                                          child: Container(
                                            margin: EdgeInsets.only(left: 7),
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: context.colors.pinkSoft,
                                              borderRadius:
                                                  BorderRadius.circular(11),
                                            ),
                                            child: Text(
                                              '방장',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: context.colors.pinkStart,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 5),
                                    Text(
                                      '누적 공부시간 '
                                      '${_formatStudyTime(totalStudySeconds)}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: context.colors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (!isOwner && memberUid != currentUserUid)
                                PopupMenuButton<String>(
                                  tooltip: canManageMembers
                                      ? '그룹원 관리'
                                      : '그룹원 메뉴',
                                  onSelected: (value) async {
                                    try {
                                      if (value == 'report') {
                                        await _showMemberReportDialog(
                                          context: context,
                                          memberUid: memberUid,
                                          nickname: nickname,
                                        );
                                      }
                                      if (value == 'kick') {
                                        await _kickMemberFromRoom(
                                          context: context,
                                          memberUid: memberUid,
                                          nickname: nickname,
                                        );
                                      }
                                    } catch (error) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              error.toString().replaceFirst(
                                                'Exception: ',
                                                '',
                                              ),
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    PopupMenuItem<String>(
                                      value: 'report',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.report_outlined,
                                            size: 20,
                                            color: context.colors.incorrect,
                                          ),
                                          SizedBox(width: 10),
                                          Text('신고'),
                                        ],
                                      ),
                                    ),
                                    if (canManageMembers)
                                      PopupMenuItem<String>(
                                        value: 'kick',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.person_remove_outlined,
                                              size: 20,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.error,
                                            ),
                                            SizedBox(width: 10),
                                            Text(
                                              '추방',
                                              style: TextStyle(
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.error,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openStudyRanking(BuildContext context) {
    DateTime now = DateTime.now();

    DateTime todayStart = DateTime(now.year, now.month, now.day);

    DateTime tomorrowStart = todayStart.add(Duration(days: 1));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.76,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: Column(
            children: [
              SizedBox(height: 11),
              Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(20, 18, 12, 14),
                child: Row(
                  children: [
                    Icon(
                      Icons.emoji_events_outlined,
                      color: context.colors.pinkStart,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '오늘 공부시간 순위',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            '저장된 기록과 현재 진행 중인 시간을 합산합니다.',
                            style: TextStyle(
                              fontSize: 10,
                              color: context.colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        Navigator.pop(bottomSheetContext);
                      },
                      icon: Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Divider(height: 1),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('studyGroups')
                      .doc(studyId)
                      .collection('members')
                      .snapshots(),
                  builder: (context, memberSnapshot) {
                    if (memberSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return AppLoadingView(message: '오늘 공부시간 순위를 불러오는 중입니다.');
                    }

                    if (memberSnapshot.hasError) {
                      if (_isNetworkError(memberSnapshot.error)) {
                        return AppNetworkErrorView(
                          message: '인터넷 연결을 확인해 주세요.',
                          description: '네트워크 연결 후 오늘 순위를 다시 불러와 주세요.',
                          onRetryPressed: () {
                            Navigator.pop(bottomSheetContext);
                            _openStudyRanking(context);
                          },
                        );
                      }

                      return AppErrorView(
                        message: '오늘 공부시간 순위를 불러오지 못했습니다.',
                        description: '잠시 후 다시 시도해 주세요.',
                        onRetryPressed: () {
                          Navigator.pop(bottomSheetContext);
                          _openStudyRanking(context);
                        },
                      );
                    }

                    List<Map<String, dynamic>> activeMemberList = [];

                    if (memberSnapshot.data != null) {
                      for (
                        int i = 0;
                        i < memberSnapshot.data!.docs.length;
                        i++
                      ) {
                        QueryDocumentSnapshot<Map<String, dynamic>>
                        memberDocument = memberSnapshot.data!.docs[i];

                        Map<String, dynamic> memberData =
                            Map<String, dynamic>.from(memberDocument.data());

                        String status = memberData['status']?.toString() ?? '';

                        String role =
                            memberData['role']?.toString() ?? 'MEMBER';

                        if (status == 'ACTIVE' || role == 'OWNER') {
                          memberData['_documentUid'] = memberDocument.id;

                          activeMemberList.add(memberData);
                        }
                      }
                    }

                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('studyGroups')
                          .doc(studyId)
                          .collection('studyRecords')
                          .where(
                            'endedAt',
                            isGreaterThanOrEqualTo: Timestamp.fromDate(
                              todayStart,
                            ),
                          )
                          .where(
                            'endedAt',
                            isLessThan: Timestamp.fromDate(tomorrowStart),
                          )
                          .snapshots(),
                      builder: (context, recordSnapshot) {
                        if (recordSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return AppLoadingView(
                            message: '오늘 공부 기록을 불러오는 중입니다.',
                          );
                        }

                        if (recordSnapshot.hasError) {
                          if (_isNetworkError(recordSnapshot.error)) {
                            return AppNetworkErrorView(
                              message: '인터넷 연결을 확인해 주세요.',
                              description: '네트워크 연결 후 오늘 기록을 다시 불러와 주세요.',
                              onRetryPressed: () {
                                Navigator.pop(bottomSheetContext);
                                _openStudyRanking(context);
                              },
                            );
                          }

                          return AppErrorView(
                            message: '오늘 공부 기록을 불러오지 못했습니다.',
                            description: '잠시 후 다시 시도해 주세요.',
                            onRetryPressed: () {
                              Navigator.pop(bottomSheetContext);
                              _openStudyRanking(context);
                            },
                          );
                        }

                        Map<String, int> todaySavedSecondsMap = {};

                        if (recordSnapshot.data != null) {
                          for (
                            int i = 0;
                            i < recordSnapshot.data!.docs.length;
                            i++
                          ) {
                            Map<String, dynamic> recordData = recordSnapshot
                                .data!
                                .docs[i]
                                .data();

                            String uid = recordData['uid']?.toString() ?? '';

                            if (uid.isEmpty) {
                              continue;
                            }

                            todaySavedSecondsMap[uid] =
                                (todaySavedSecondsMap[uid] ?? 0) +
                                _getRecordStudySeconds(recordData);
                          }
                        }

                        List<Map<String, dynamic>> rankingList = [];

                        for (int i = 0; i < activeMemberList.length; i++) {
                          Map<String, dynamic> memberData = activeMemberList[i];

                          String uid = _getMemberUid(memberData);

                          int todaySeconds =
                              (todaySavedSecondsMap[uid] ?? 0) +
                              _getMemberLiveStudySeconds(memberData);

                          if (todaySeconds <= 0) {
                            continue;
                          }

                          Map<String, dynamic> rankingData =
                              Map<String, dynamic>.from(memberData);

                          rankingData['_todayStudySeconds'] = todaySeconds;

                          rankingList.add(rankingData);
                        }

                        rankingList.sort((a, b) {
                          int aSeconds = _getInt(a, '_todayStudySeconds');

                          int bSeconds = _getInt(b, '_todayStudySeconds');

                          return bSeconds.compareTo(aSeconds);
                        });

                        if (rankingList.isEmpty) {
                          return AppEmptyView(
                            message: '오늘 공부시간 기록이 없습니다.',
                            description: '공부를 시작하거나 기록을 저장하면 오늘 순위가 표시됩니다.',
                          );
                        }

                        return ListView.builder(
                          padding: EdgeInsets.fromLTRB(18, 16, 18, 30),
                          itemCount: rankingList.length,
                          itemBuilder: (context, index) {
                            Map<String, dynamic> memberData =
                                rankingList[index];

                            String nickname =
                                memberData['nickname']?.toString() ?? '스터디원';

                            String profileImageUrl =
                                memberData['profileImageUrl']?.toString() ?? '';

                            bool isOwner =
                                memberData['role']?.toString() == 'OWNER';

                            int todaySeconds = _getInt(
                              memberData,
                              '_todayStudySeconds',
                            );

                            int focusScore = _getMemberFocusScore(memberData);

                            String statusText = _getMemberStatusText(
                              memberData,
                            );

                            return Container(
                              margin: EdgeInsets.only(bottom: 11),
                              padding: EdgeInsets.all(15),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.outlineVariant,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: context.colors.lavender,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        color: context.colors.pinkStart,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  _buildProfileImage(
                                    context,
                                    nickname,
                                    profileImageUrl,
                                    isOwner,
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        CachedNicknameText(
                                          uid: _getMemberUid(memberData),
                                          fallback: nickname,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: context.colors.textPrimary,
                                          ),
                                        ),
                                        SizedBox(height: 5),
                                        Row(
                                          children: [
                                            Container(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 7,
                                                vertical: 3,
                                              ),
                                              decoration: BoxDecoration(
                                                color:
                                                    _getMemberStatusBackgroundColor(
                                                      context,
                                                      memberData,
                                                    ),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: Text(
                                                statusText,
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                  color:
                                                      _getMemberStatusTextColor(
                                                        context,
                                                        memberData,
                                                      ),
                                                ),
                                              ),
                                            ),
                                            SizedBox(width: 7),
                                            Text(
                                              '집중 $focusScore점',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: context
                                                    .colors
                                                    .textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    _formatStudyTime(todaySeconds),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: context.colors.pinkStart,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 방장만 스터디 공지를 작성하거나 수정
  void _showNoticeDialog(BuildContext context, String currentNotice) {
    TextEditingController noticeController = TextEditingController();
    noticeController.text = currentNotice;

    String dialogTitle = '공지 등록';

    if (currentNotice.isNotEmpty) {
      dialogTitle = '공지 수정';
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: context.colors.surface,
          surfaceTintColor: Colors.transparent,
          shape: appDialogShape,
          title: AppDialogTitle(
            icon: Icons.campaign_outlined,
            title: dialogTitle,
          ),
          content: TextField(
            controller: noticeController,
            maxLines: 6,
            maxLength: 200,
            decoration: InputDecoration(
              hintText: '스터디원에게 전달할 공지를 입력하세요.',
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: Text('취소'),
            ),
            ElevatedButton(
              onPressed: () async {
                String notice = noticeController.text.trim();

                try {
                  await FirebaseFirestore.instance
                      .collection('studyGroups')
                      .doc(studyId)
                      .update({
                        'notice': notice,
                        'noticeUpdatedAt': FieldValue.serverTimestamp(),
                      });

                  Navigator.pop(dialogContext);

                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('스터디 공지가 저장되었습니다.')));
                } catch (error) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('공지 저장 중 오류가 발생했습니다.')),
                  );
                }
              },
              child: Text('저장'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRoomContent(
    BuildContext context,
    Map<String, dynamic> groupData,
    bool isOwner,
  ) {
    String displayGroupName = groupData['groupName']?.toString() ?? groupName;

    String description = groupData['description']?.toString() ?? '';

    String notice = groupData['notice']?.toString() ?? '';

    String certificateName =
        groupData['certificateName']?.toString() ?? '공통 스터디';

    int currentMemberCount = _getInt(groupData, 'currentMemberCount');

    int maxMemberCount = _getInt(groupData, 'maxMemberCount');

    bool joinApprovalRequired = true;

    if (groupData['joinApprovalRequired'] is bool) {
      joinApprovalRequired = groupData['joinApprovalRequired'];
    }

    bool isRecruiting = _isRecruiting(groupData);

    String memberText = '$currentMemberCount명';

    if (maxMemberCount > 0) {
      memberText = '$currentMemberCount / $maxMemberCount명';
    }

    String joinTypeText = '바로 참여';

    if (joinApprovalRequired) {
      joinTypeText = '승인 후 참여';
    }

    if (description.isEmpty) {
      description = '같은 목표를 준비하는 스터디원들과 함께 공부해요.';
    }

    double bottomPadding = MediaQuery.of(context).padding.bottom + 42;

    return AppMainBackground(
      applySafeArea: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(18, 14, 18, bottomPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 스터디 기본 정보
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [context.colors.pinkSoft, context.colors.lavender],
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: context.colors.pinkSoft),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      _buildRoomBadge(
                        certificateName,
                        Theme.of(context).colorScheme.surface.withOpacity(0.88),
                        context.colors.pinkStart,
                      ),
                      _buildRoomBadge(
                        isRecruiting ? '모집 중' : '모집 마감',
                        isRecruiting
                            ? context.colors.mint
                            : Theme.of(context).colorScheme.outlineVariant,
                        isRecruiting
                            ? Theme.of(context).colorScheme.tertiary
                            : context.colors.textSecondary,
                      ),
                      Visibility(
                        visible: isOwner,
                        child: _buildRoomBadge(
                          '방장',
                          context.colors.pinkStart,
                          Theme.of(context).colorScheme.surface,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 14),
                  Text(
                    displayGroupName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 23,
                      height: 1.25,
                      fontWeight: FontWeight.bold,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 9),
                  Text(
                    description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.55,
                      color: context.colors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 18),
                  Row(
                    children: [
                      _buildRoomMetric(
                        context,
                        Icons.groups_rounded,
                        '참여 인원',
                        memberText,
                      ),
                      SizedBox(width: 10),
                      _buildRoomMetric(
                        context,
                        Icons.how_to_reg_rounded,
                        '참여 방식',
                        joinTypeText,
                      ),
                    ],
                  ),
                  Visibility(
                    visible: isOwner,
                    child: Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(15),
                        onTap: () {
                          _updateRecruitmentStatus(
                            context,
                            groupData,
                            isRecruiting == false,
                          );
                        },
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                            horizontal: 13,
                            vertical: 11,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surface.withOpacity(0.82),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isRecruiting
                                    ? Icons.lock_outline_rounded
                                    : Icons.lock_open_rounded,
                                size: 18,
                                color: context.colors.pinkStart,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  isRecruiting
                                      ? '신규 참여 모집 마감하기'
                                      : '신규 참여 모집 다시 열기',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: context.colors.pinkStart,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 20,
                                color: context.colors.pinkStart,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 24),

            if (isOwner) ...[
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('studyGroups')
                    .doc(studyId)
                    .collection('members')
                    .snapshots(),
                builder: (context, snapshot) {
                  int pendingCount = 0;

                  if (snapshot.hasData) {
                    pendingCount = snapshot.data!.docs
                        .where(
                          (document) => document.data()['status'] == 'PENDING',
                        )
                        .length;
                  }

                  return InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) {
                            return StudyJoinRequestsPage(studyId: studyId);
                          },
                        ),
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: pendingCount > 0
                            ? context.colors.pinkSoft
                            : Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: pendingCount > 0
                              ? context.colors.pinkStart
                              : Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.how_to_reg_outlined,
                            color: context.colors.pinkStart,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '참여 신청 관리',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  pendingCount > 0
                                      ? '승인을 기다리는 신청이 $pendingCount건 있습니다.'
                                      : '현재 대기 중인 참여 신청이 없습니다.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: context.colors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded),
                        ],
                      ),
                    ),
                  );
                },
              ),
              SizedBox(height: 24),
            ],

            _buildRoomSectionTitle(
              context,
              '시험과 주간 목표',
              '시험일까지 남은 기간과 이번 주 달성률을 확인해요.',
            ),

            SizedBox(height: 11),

            _buildStudyGoalCard(context, groupData, isOwner),

            SizedBox(height: 26),

            // 열품타식 핵심 영역:
            // 오늘 현황을 먼저 보여주고 바로 공부를 시작하게 구성
            _buildRoomSectionTitle(
              context,
              '오늘의 공부',
              '그룹의 공부 현황을 확인하고 바로 시작해요.',
            ),

            SizedBox(height: 11),

            _buildTodayStudySummary(context, displayGroupName),

            SizedBox(height: 11),

            _buildPrimaryStudyButton(context, displayGroupName),

            SizedBox(height: 26),

            // 현재 스터디원
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: _buildRoomSectionTitle(
                    context,
                    '현재 스터디원',
                    '함께 공부하는 그룹원을 확인해요.',
                  ),
                ),
                TextButton(
                  onPressed: () {
                    _openMemberList(context);
                  },
                  child: Text(
                    '전체보기',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colors.pinkStart,
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 9),

            _buildMemberProfiles(context),

            SizedBox(height: 26),

            // 공부 기록과 문제
            _buildRoomSectionTitle(
              context,
              '공부 기록',
              '공부시간을 비교하고 함께 동기부여를 받아요.',
            ),

            SizedBox(height: 11),

            _buildStudyRecordButton(context, displayGroupName),

            SizedBox(height: 11),

            Row(
              children: [
                _buildActivityButton(
                  context,
                  Icons.emoji_events_rounded,
                  '공부 순위',
                  '오늘 공부시간 비교',
                  context.colors.lavender,
                  context.colors.pinkStart,
                  () {
                    _openStudyRanking(context);
                  },
                ),
                SizedBox(width: 11),
                _buildActivityButton(
                  context,
                  Icons.quiz_rounded,
                  '발송 문제',
                  '문제 확인하기',
                  context.colors.pinkSoft,
                  context.colors.pinkStart,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) {
                          return StudyQuizPage(
                            studyId: studyId,
                            groupName: displayGroupName,
                          );
                        },
                      ),
                    );
                  },
                ),
              ],
            ),

            SizedBox(height: 26),

            // 따iT의 차별 기능: 공지
            _buildRoomSectionTitle(context, '공지', '스터디원 모두가 확인해야 할 내용이에요.'),

            SizedBox(height: 10),

            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.colors.pinkSoft,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: context.colors.pinkSoft),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      Icons.campaign_rounded,
                      color: context.colors.pinkStart,
                      size: 21,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      notice.isEmpty ? '등록된 공지가 없습니다.' : notice,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ),
                  Visibility(
                    visible: isOwner,
                    child: TextButton(
                      onPressed: () {
                        _showNoticeDialog(context, notice);
                      },
                      style: TextButton.styleFrom(
                        minimumSize: Size(0, 32),
                        padding: EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: Text(
                        notice.isEmpty ? '등록' : '수정',
                        style: TextStyle(
                          fontSize: 11,
                          color: context.colors.pinkStart,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 26),

            // 따iT의 차별 기능: 그룹 채팅
            _buildRoomSectionTitle(context, '그룹 채팅', '질문과 공부 계획을 그룹원과 나눠 보세요.'),

            SizedBox(height: 11),

            _buildChatActivityButton(context, displayGroupName),
          ],
        ),
      ),
    );
  }

  Widget _buildAccessDenied() {
    return AppErrorView(
      message: '스터디방에 들어갈 수 없습니다.',
      description: '참여 승인을 받은 그룹원만 이용할 수 있습니다.',
    );
  }

  @override
  Widget build(BuildContext context) {
    User? currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppTopBar(
        title: '스터디방',
        actions: [
          IconButton(
            onPressed: () {
              _openMemberList(context);
            },
            icon: Icon(Icons.groups_outlined),
            tooltip: '그룹원 보기',
          ),
          _buildRoomMoreMenu(context),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('studyGroups')
            .doc(studyId)
            .snapshots(),
        builder: (context, groupSnapshot) {
          if (groupSnapshot.connectionState == ConnectionState.waiting) {
            return AppLoadingView(message: '스터디방을 불러오는 중입니다.');
          }

          if (groupSnapshot.hasError) {
            if (_isNetworkError(groupSnapshot.error)) {
              return AppNetworkErrorView(
                message: '인터넷 연결을 확인해 주세요.',
                description: 'Wi-Fi 또는 모바일 데이터를 확인한 뒤 다시 시도해 주세요.',
                onRetryPressed: () {
                  _reloadPage(context);
                },
              );
            }

            return AppErrorView(
              message: '스터디방을 불러오지 못했습니다.',
              description: '잠시 후 다시 시도해 주세요.',
              onRetryPressed: () {
                _reloadPage(context);
              },
            );
          }

          if (groupSnapshot.data == null ||
              groupSnapshot.data!.exists == false) {
            return AppErrorView(
              message: '존재하지 않는 스터디입니다.',
              description: '삭제되었거나 더 이상 이용할 수 없는 스터디입니다.',
            );
          }

          Map<String, dynamic> groupData = groupSnapshot.data!.data() ?? {};

          String ownerUid = groupData['ownerUid']?.toString() ?? '';

          bool isOwner = currentUser != null && currentUser.uid == ownerUid;

          if (isOwner) {
            _scheduleCurrentMemberProfileSync(isOwner: true);

            return _buildRoomContent(context, groupData, true);
          }

          if (currentUser == null) {
            return _buildAccessDenied();
          }

          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('studyGroups')
                .doc(studyId)
                .collection('members')
                .doc(currentUser.uid)
                .snapshots(),
            builder: (context, memberSnapshot) {
              if (memberSnapshot.connectionState == ConnectionState.waiting) {
                return AppLoadingView(message: '그룹원 정보를 확인하는 중입니다.');
              }

              if (memberSnapshot.hasError) {
                if (_isNetworkError(memberSnapshot.error)) {
                  return AppNetworkErrorView(
                    message: '인터넷 연결을 확인해 주세요.',
                    description: '네트워크 연결 후 그룹원 정보를 다시 확인해 주세요.',
                    onRetryPressed: () {
                      _reloadPage(context);
                    },
                  );
                }

                return AppErrorView(
                  message: '그룹원 정보를 불러오지 못했습니다.',
                  description: '잠시 후 다시 시도해 주세요.',
                  onRetryPressed: () {
                    _reloadPage(context);
                  },
                );
              }

              String memberStatus = '';

              if (memberSnapshot.data != null && memberSnapshot.data!.exists) {
                Map<String, dynamic> memberData =
                    memberSnapshot.data!.data() ?? {};

                memberStatus = memberData['status']?.toString() ?? '';
              }

              if (memberStatus != 'ACTIVE') {
                return _buildAccessDenied();
              }

              _scheduleCurrentMemberProfileSync(isOwner: false);

              return _buildRoomContent(context, groupData, false);
            },
          );
        },
      ),
    );
  }
}
