import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../theme.dart';
import 'package:flutterteam03/widgets/app_state_views.dart';

import '../widgets/app_card.dart';
import '../widgets/app_button.dart';
import '../widgets/app_main_background.dart';
import '../widgets/app_top_bar.dart';
import 'study_chat.dart';
import 'study_edit.dart';
import 'study_join_requests.dart';
import 'study_quiz.dart';
import 'study_room.dart';
import 'study_timer.dart';


Brightness get _studyBrightness {
  return WidgetsBinding.instance.platformDispatcher.platformBrightness;
}

AppColors get _studyColors {
  if (_studyBrightness == Brightness.dark) {
    return AppColors.dark;
  }

  return AppColors.light;
}

ColorScheme get _studyColorScheme {
  if (_studyBrightness == Brightness.dark) {
    return darkTheme.colorScheme;
  }

  return lightTheme.colorScheme;
}

class StudyDetailPage extends StatelessWidget {
  final String studyId;
  final Map<String, dynamic> studyData;

  static final Set<String> _ownerProfileSyncKeySet = <String>{};

  const StudyDetailPage({
    super.key,
    required this.studyId,
    required this.studyData,
  });

  /// Firestore 숫자 가져오기
  int _getInt(
      Map<String, dynamic> data,
      String fieldName,
      ) {
    final value = data[fieldName];

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return 0;
  }

  /// 현재 모집 중인지 확인
  bool _isRecruiting(Map<String, dynamic> data) {
    String recruitmentStatus =
        data['recruitmentStatus']?.toString() ?? '';

    String groupStatus =
        data['status']?.toString() ?? '';

    int currentMemberCount = _getInt(
      data,
      'currentMemberCount',
    );

    int maxMemberCount = _getInt(
      data,
      'maxMemberCount',
    );

    if (groupStatus == 'COMPLETED') {
      return false;
    }

    if (recruitmentStatus == 'CLOSED') {
      return false;
    }

    if (recruitmentStatus.isEmpty &&
        groupStatus == 'CLOSED') {
      return false;
    }

    if (maxMemberCount > 0 &&
        currentMemberCount >= maxMemberCount) {
      return false;
    }

    return true;
  }

  /// 현재 로그인한 사용자가 방장인지 확인
  bool _isOwner(Map<String, dynamic> data) {
    final currentUserUid =
        FirebaseAuth.instance.currentUser?.uid;

    final ownerUid =
    data['ownerUid']?.toString();

    return currentUserUid != null &&
        currentUserUid == ownerUid;
  }

  /// 공부시간 표시
  String _formatStudyTime(int totalMinutes) {
    if (totalMinutes <= 0) {
      return '0분';
    }

    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;

    if (hours == 0) {
      return '$minutes분';
    }

    if (minutes == 0) {
      return '$hours시간';
    }

    return '$hours시간 $minutes분';
  }

  /// Firestore 날짜 필드를 DateTime으로 변환
  DateTime? _getDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate().toLocal();
    }

    if (value is DateTime) {
      return value.toLocal();
    }

    return null;
  }

  /// 시험일 표시
  String _formatExamDate(DateTime examDate) {
    String year = examDate.year.toString();

    String month =
    examDate.month.toString().padLeft(2, '0');

    String day =
    examDate.day.toString().padLeft(2, '0');

    return '$year.$month.$day';
  }

  /// 시험일까지 남은 날짜 표시
  String _getDdayText(DateTime examDate) {
    DateTime now = DateTime.now();

    DateTime today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    DateTime examDay = DateTime(
      examDate.year,
      examDate.month,
      examDate.day,
    );

    int difference =
        examDay.difference(today).inDays;

    if (difference > 0) {
      return 'D-$difference';
    }

    if (difference == 0) {
      return 'D-DAY';
    }

    return 'D+${difference.abs()}';
  }

  /// 초 단위 공부시간을 화면용 문구로 변환
  String _formatGoalTime(int totalSeconds) {
    if (totalSeconds <= 0) {
      return '0분';
    }

    int hours = totalSeconds ~/ 3600;
    int minutes = (totalSeconds % 3600) ~/ 60;

    if (hours > 0 && minutes > 0) {
      return '$hours시간 $minutes분';
    }

    if (hours > 0) {
      return '$hours시간';
    }

    return '$minutes분';
  }

  /// 공부 기록에서 초 단위 공부시간 가져오기
  int _getRecordStudySeconds(
      Map<String, dynamic> data,
      ) {
    dynamic studySecondsValue =
    data['studySeconds'];

    if (studySecondsValue is int) {
      return studySecondsValue;
    }

    if (studySecondsValue is num) {
      return studySecondsValue.toInt();
    }

    dynamic elapsedSecondsValue =
    data['elapsedSeconds'];

    if (elapsedSecondsValue is int) {
      return elapsedSecondsValue;
    }

    if (elapsedSecondsValue is num) {
      return elapsedSecondsValue.toInt();
    }

    dynamic studyMinutesValue =
    data['studyMinutes'];

    if (studyMinutesValue is int) {
      return studyMinutesValue * 60;
    }

    if (studyMinutesValue is num) {
      return (studyMinutesValue * 60).round();
    }

    return 0;
  }

  /// 안내 메시지 표시
  void _showMessage(
      BuildContext context,
      String message,
      ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  /// users 컬렉션에서 실제 회원 닉네임과 프로필 이미지 조회
  Future<Map<String, String>> _getUserProfile(
      String uid,
      ) async {
    String nickname = '';
    String profileImageUrl = '';

    DocumentSnapshot<Map<String, dynamic>> directUserSnapshot =
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

    Map<String, dynamic> userData = {};

    if (directUserSnapshot.exists) {
      userData = directUserSnapshot.data() ?? {};
    } else {
      QuerySnapshot<Map<String, dynamic>> userSnapshot =
      await FirebaseFirestore.instance
          .collection('users')
          .where(
        'uid',
        isEqualTo: uid,
      )
          .limit(1)
          .get();

      if (userSnapshot.docs.isNotEmpty) {
        userData = userSnapshot.docs.first.data();
      }
    }

    nickname =
        userData['nickname']?.toString().trim() ?? '';

    profileImageUrl =
        userData['profileImageUrl']?.toString().trim() ?? '';

    if (profileImageUrl.isEmpty) {
      profileImageUrl =
          userData['photoUrl']?.toString().trim() ?? '';
    }

    User? currentUser =
        FirebaseAuth.instance.currentUser;

    if (currentUser != null &&
        currentUser.uid == uid) {
      if (nickname.isEmpty) {
        nickname =
            currentUser.displayName?.trim() ?? '';
      }

      if (profileImageUrl.isEmpty) {
        profileImageUrl =
            currentUser.photoURL?.trim() ?? '';
      }
    }

    return {
      'nickname': nickname,
      'profileImageUrl': profileImageUrl,
    };
  }

  /// 방장이 상세 화면에 들어오면 실제 회원 닉네임으로 동기화
  void _scheduleOwnerProfileSync(
      Map<String, dynamic> currentStudyData,
      ) {
    User? currentUser =
        FirebaseAuth.instance.currentUser;

    String ownerUid =
        currentStudyData['ownerUid']?.toString() ?? '';

    if (currentUser == null ||
        ownerUid.isEmpty ||
        currentUser.uid != ownerUid) {
      return;
    }

    String syncKey = '$studyId:$ownerUid';

    if (_ownerProfileSyncKeySet.contains(syncKey)) {
      return;
    }

    _ownerProfileSyncKeySet.add(syncKey);

    WidgetsBinding.instance.addPostFrameCallback(
          (timeStamp) async {
        try {
          Map<String, String> profile =
          await _getUserProfile(ownerUid);

          String nickname =
              profile['nickname'] ?? '';

          String profileImageUrl =
              profile['profileImageUrl'] ?? '';

          if (nickname.isEmpty &&
              profileImageUrl.isEmpty) {
            return;
          }

          DocumentReference<Map<String, dynamic>>
          groupDocument =
          FirebaseFirestore.instance
              .collection('studyGroups')
              .doc(studyId);

          DocumentReference<Map<String, dynamic>>
          memberDocument =
          groupDocument
              .collection('members')
              .doc(ownerUid);

          Map<String, dynamic> memberUpdateData = {
            'uid': ownerUid,
            'role': 'OWNER',
            'status': 'ACTIVE',
            'updatedAt': FieldValue.serverTimestamp(),
          };

          if (nickname.isNotEmpty) {
            memberUpdateData['nickname'] = nickname;
          }

          if (profileImageUrl.isNotEmpty) {
            memberUpdateData['profileImageUrl'] =
                profileImageUrl;
          }

          await memberDocument.set(
            memberUpdateData,
            SetOptions(merge: true),
          );

          if (nickname.isNotEmpty) {
            await groupDocument.set(
              {
                'ownerNickname': nickname,
                'updatedAt': FieldValue.serverTimestamp(),
              },
              SetOptions(merge: true),
            );
          }
        } catch (error) {
          _ownerProfileSyncKeySet.remove(syncKey);

          debugPrint(
            '방장 닉네임 동기화 오류: $error',
          );
        }
      },
    );
  }

  /// 방장이 모집 상태 변경
  Future<void> _updateRecruitmentStatus(
      BuildContext context,
      Map<String, dynamic> currentStudyData,
      bool openRecruitment,
      ) async {
    int currentMemberCount = _getInt(
      currentStudyData,
      'currentMemberCount',
    );

    int maxMemberCount = _getInt(
      currentStudyData,
      'maxMemberCount',
    );

    if (openRecruitment &&
        maxMemberCount > 0 &&
        currentMemberCount >= maxMemberCount) {
      _showMessage(
        context,
        '정원이 가득 차서 모집을 다시 열 수 없습니다.',
      );
      return;
    }

    try {
      String nextRecruitmentStatus = 'CLOSED';
      String nextGroupStatus = 'CLOSED';

      if (openRecruitment) {
        nextRecruitmentStatus = 'OPEN';
        nextGroupStatus = 'RECRUITING';
      }

      await FirebaseFirestore.instance
          .collection('studyGroups')
          .doc(studyId)
          .update({
        'recruitmentStatus': nextRecruitmentStatus,
        'status': nextGroupStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!context.mounted) {
        return;
      }

      if (openRecruitment) {
        _showMessage(
          context,
          '스터디 모집을 다시 시작했습니다.',
        );
      } else {
        _showMessage(
          context,
          '스터디 모집을 마감했습니다.',
        );
      }
    } catch (error) {
      debugPrint('모집 상태 변경 오류: $error');

      if (!context.mounted) {
        return;
      }

      _showMessage(
        context,
        '모집 상태를 변경하지 못했습니다.',
      );
    }
  }

  /// 중복되지 않는 초대 문서 ID 생성
  String _createInviteDocumentId(
      String target,
      ) {
    final value = '$studyId|$target';

    return base64Url
        .encode(
      utf8.encode(value),
    )
        .replaceAll('=', '');
  }

  /// 초대 정보 저장
  Future<void> _saveInvite({
    required String groupName,
    required String target,
  }) async {
    final currentUser =
        FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      throw Exception('로그인 정보가 없습니다.');
    }

    Map<String, String> inviterProfile =
    await _getUserProfile(currentUser.uid);

    String inviterNickname =
        inviterProfile['nickname'] ?? '';

    if (inviterNickname.isEmpty) {
      inviterNickname = '사용자';
    }

    String inviterProfileImageUrl =
        inviterProfile['profileImageUrl'] ?? '';

    final normalizedTarget =
    target.trim().toLowerCase();

    final bool isEmail =
    normalizedTarget.contains('@');

    final inviteDocumentId =
    _createInviteDocumentId(
      normalizedTarget,
    );

    final inviteDocument =
    FirebaseFirestore.instance
        .collection('studyGroupInvites')
        .doc(inviteDocumentId);

    await inviteDocument.set(
      {
        'groupId': studyId,
        'groupName': groupName,

        'inviterUid': currentUser.uid,
        'inviterNickname': inviterNickname,
        'inviterProfileImageUrl':
        inviterProfileImageUrl,

        'inviteeUid': '',

        'targetEmail':
        isEmail ? normalizedTarget : '',

        'targetId':
        isEmail ? '' : normalizedTarget,

        'inviteType':
        isEmail ? 'EMAIL' : 'ID',

        'status': 'PENDING',

        'createdAt':
        FieldValue.serverTimestamp(),

        'updatedAt':
        FieldValue.serverTimestamp(),

        // 초대 유효기간 7일
        'expiredAt': Timestamp.fromDate(
          DateTime.now().add(
            Duration(days: 7),
          ),
        ),
      },
      SetOptions(
        merge: true,
      ),
    );
  }

  /// 기존 스터디에 방장 멤버 정보가 없으면 생성
  Future<void> _ensureOwnerMember(
      Map<String, dynamic> currentStudyData,
      ) async {
    final ownerUid =
        currentStudyData['ownerUid']
            ?.toString() ??
            '';

    if (ownerUid.isEmpty) {
      return;
    }

    String ownerNickname =
        currentStudyData['ownerNickname']
            ?.toString() ??
            '방장';

    String ownerProfileImageUrl = '';

    User? currentUser =
        FirebaseAuth.instance.currentUser;

    if (currentUser != null &&
        currentUser.uid == ownerUid) {
      Map<String, String> ownerProfile =
      await _getUserProfile(ownerUid);

      String actualOwnerNickname =
          ownerProfile['nickname'] ?? '';

      if (actualOwnerNickname.isNotEmpty) {
        ownerNickname = actualOwnerNickname;
      }

      ownerProfileImageUrl =
          ownerProfile['profileImageUrl'] ?? '';
    }

    final ownerMemberDocument =
    FirebaseFirestore.instance
        .collection('studyGroups')
        .doc(studyId)
        .collection('members')
        .doc(ownerUid);

    final ownerMemberSnapshot =
    await ownerMemberDocument.get();

    Map<String, dynamic> ownerMemberData = {
      'uid': ownerUid,
      'nickname': ownerNickname,
      'role': 'OWNER',
      'status': 'ACTIVE',
      'updatedAt':
      FieldValue.serverTimestamp(),
    };

    if (ownerProfileImageUrl.isNotEmpty) {
      ownerMemberData['profileImageUrl'] =
          ownerProfileImageUrl;
    }

    if (ownerMemberSnapshot.exists == false) {
      ownerMemberData['totalStudyMinutes'] = 0;
      ownerMemberData['totalStudySeconds'] = 0;
      ownerMemberData['joinedAt'] =
          currentStudyData['createdAt'] ??
              FieldValue.serverTimestamp();
    }

    await ownerMemberDocument.set(
      ownerMemberData,
      SetOptions(merge: true),
    );

    if (currentUser != null &&
        currentUser.uid == ownerUid &&
        ownerNickname.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('studyGroups')
          .doc(studyId)
          .set(
        {
          'ownerNickname': ownerNickname,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }
  }

  /// 스터디 수정 화면으로 이동
  Future<void> _openEditPage(
      BuildContext context,
      Map<String, dynamic> currentStudyData,
      ) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => StudyEditPage(
          studyId: studyId,
          studyData: currentStudyData,
        ),
      ),
    );
  }

  /// 시험일과 주간 목표 설정 창
  Future<void> _showStudyGoalDialog(
      BuildContext context,
      Map<String, dynamic> currentStudyData,
      ) async {
    DateTime? selectedExamDate =
    _getDateTime(
      currentStudyData['examDate'],
    );

    int weeklyGoalMinutes = _getInt(
      currentStudyData,
      'weeklyGoalMinutes',
    );

    int initialGoalHours =
        weeklyGoalMinutes ~/ 60;

    int initialGoalMinutes =
        weeklyGoalMinutes % 60;

    TextEditingController hourController =
    TextEditingController(
      text: initialGoalHours > 0
          ? initialGoalHours.toString()
          : '',
    );

    TextEditingController minuteController =
    TextEditingController(
      text: initialGoalMinutes > 0
          ? initialGoalMinutes.toString()
          : '',
    );

    bool isSaving = false;
    String inputError = '';

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (
              context,
              setDialogState,
              ) {
            Future<void> selectExamDate() async {
              DateTime now = DateTime.now();

              DateTime initialDate =
                  selectedExamDate ?? now;

              DateTime? pickedDate =
              await showDatePicker(
                context: dialogContext,
                initialDate: initialDate,
                firstDate: DateTime(
                  now.year - 5,
                ),
                lastDate: DateTime(
                  now.year + 10,
                  12,
                  31,
                ),
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
              int goalHours =
                  int.tryParse(
                    hourController.text.trim(),
                  ) ??
                      0;

              int goalMinutes =
                  int.tryParse(
                    minuteController.text.trim(),
                  ) ??
                      0;

              if (goalHours < 0 ||
                  goalMinutes < 0) {
                setDialogState(() {
                  inputError =
                  '목표시간은 0 이상으로 입력해 주세요.';
                });

                return;
              }

              if (goalMinutes >= 60) {
                setDialogState(() {
                  inputError =
                  '분은 0분부터 59분까지 입력해 주세요.';
                });

                return;
              }

              int totalGoalMinutes =
                  goalHours * 60 +
                      goalMinutes;

              if (totalGoalMinutes >
                  7 * 24 * 60) {
                setDialogState(() {
                  inputError =
                  '주간 목표는 최대 168시간까지 설정할 수 있습니다.';
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
                  'examDate':
                  selectedExamDate == null
                      ? null
                      : Timestamp.fromDate(
                    selectedExamDate!,
                  ),
                  'weeklyGoalMinutes':
                  totalGoalMinutes,
                  'updatedAt':
                  FieldValue.serverTimestamp(),
                });

                if (!dialogContext.mounted) {
                  return;
                }

                Navigator.pop(
                  dialogContext,
                );

                if (!context.mounted) {
                  return;
                }

                _showMessage(
                  context,
                  '시험일과 주간 목표를 저장했습니다.',
                );
              } catch (error) {
                debugPrint(
                  '시험일·주간 목표 저장 오류: $error',
                );

                if (!dialogContext.mounted) {
                  return;
                }

                setDialogState(() {
                  isSaving = false;
                  inputError =
                  '시험일과 주간 목표를 저장하지 못했습니다.';
                });
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius:
                BorderRadius.circular(22),
              ),
              title: Row(
                children: [
                  Icon(
                    Icons
                        .event_available_rounded,
                    color:
                    _studyColors.pinkStart,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '시험일·주간 목표 설정',
                    ),
                  ),
                ],
              ),
              content:
              SingleChildScrollView(
                child: Column(
                  mainAxisSize:
                  MainAxisSize.min,
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      '시험일',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                        FontWeight.bold,
                        color: _studyColors
                            .textPrimary,
                      ),
                    ),
                    SizedBox(height: 8),
                    InkWell(
                      borderRadius:
                      BorderRadius.circular(
                        14,
                      ),
                      onTap: isSaving
                          ? null
                          : selectExamDate,
                      child: Container(
                        width: double.infinity,
                        padding:
                        EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        decoration:
                        BoxDecoration(
                          color:
                          _studyColorScheme
                              .surface,
                          borderRadius:
                          BorderRadius.circular(
                            14,
                          ),
                          border: Border.all(
                            color:
                            _studyColorScheme
                                .outlineVariant,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons
                                  .calendar_month_outlined,
                              color: _studyColors
                                  .pinkStart,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                selectedExamDate ==
                                    null
                                    ? '시험일을 선택해 주세요.'
                                    : _formatExamDate(
                                  selectedExamDate!,
                                ),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: selectedExamDate ==
                                      null
                                      ? _studyColors
                                      .textSecondary
                                      : _studyColors
                                      .textPrimary,
                                ),
                              ),
                            ),
                            Icon(
                              Icons
                                  .chevron_right_rounded,
                              color: _studyColors
                                  .textSecondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (selectedExamDate !=
                        null)
                      Align(
                        alignment:
                        Alignment.centerRight,
                        child: TextButton(
                          onPressed: isSaving
                              ? null
                              : () {
                            setDialogState(
                                  () {
                                selectedExamDate =
                                null;
                              },
                            );
                          },
                          child: Text(
                            '시험일 삭제',
                            style: TextStyle(
                              color:
                              _studyColorScheme
                                  .error,
                            ),
                          ),
                        ),
                      ),
                    SizedBox(height: 14),
                    Text(
                      '이번 주 그룹 목표',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                        FontWeight.bold,
                        color: _studyColors
                            .textPrimary,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      '그룹원 전체의 월요일부터 일요일까지 공부시간을 합산합니다.',
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.4,
                        color: _studyColors
                            .textSecondary,
                      ),
                    ),
                    SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller:
                            hourController,
                            enabled: !isSaving,
                            keyboardType:
                            TextInputType
                                .number,
                            decoration:
                            InputDecoration(
                              labelText: '시간',
                              hintText: '예: 20',
                              suffixText: '시간',
                              border:
                              OutlineInputBorder(
                                borderRadius:
                                BorderRadius
                                    .circular(
                                  14,
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller:
                            minuteController,
                            enabled: !isSaving,
                            keyboardType:
                            TextInputType
                                .number,
                            decoration:
                            InputDecoration(
                              labelText: '분',
                              hintText: '예: 30',
                              suffixText: '분',
                              border:
                              OutlineInputBorder(
                                borderRadius:
                                BorderRadius
                                    .circular(
                                  14,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 7),
                    Text(
                      '시간과 분을 모두 비우거나 0으로 저장하면 주간 목표가 해제됩니다.',
                      style: TextStyle(
                        fontSize: 10,
                        height: 1.4,
                        color: _studyColors
                            .textSecondary,
                      ),
                    ),
                    if (inputError.isNotEmpty) ...[
                      SizedBox(height: 11),
                      Text(
                        inputError,
                        style: TextStyle(
                          fontSize: 11,
                          color:
                          _studyColorScheme
                              .error,
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
                    Navigator.pop(
                      dialogContext,
                    );
                  },
                  child: Text('취소'),
                ),
                ElevatedButton(
                  onPressed:
                  isSaving ? null : saveGoal,
                  style:
                  ElevatedButton.styleFrom(
                    backgroundColor:
                    _studyColors.pinkStart,
                    foregroundColor:
                    _studyColorScheme
                        .onPrimary,
                  ),
                  child: isSaving
                      ? SizedBox(
                    width: 18,
                    height: 18,
                    child:
                    CircularProgressIndicator(
                      strokeWidth: 2,
                      color:
                      _studyColorScheme
                          .onPrimary,
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

  /// 시험일과 주간 목표 카드
  Widget _buildStudyGoalCard(
      BuildContext context,
      Map<String, dynamic> currentStudyData,
      bool isOwner,
      ) {
    DateTime? examDate =
    _getDateTime(
      currentStudyData['examDate'],
    );

    int weeklyGoalMinutes = _getInt(
      currentStudyData,
      'weeklyGoalMinutes',
    );

    DateTime now = DateTime.now();

    DateTime today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    DateTime weekStart =
    today.subtract(
      Duration(
        days: today.weekday - 1,
      ),
    );

    DateTime nextWeekStart =
    weekStart.add(
      Duration(days: 7),
    );

    Stream<
        QuerySnapshot<
            Map<String, dynamic>>>
    recordStream =
    FirebaseFirestore.instance
        .collection('studyGroups')
        .doc(studyId)
        .collection('studyRecords')
        .where(
      'endedAt',
      isGreaterThanOrEqualTo:
      Timestamp.fromDate(
        weekStart,
      ),
    )
        .where(
      'endedAt',
      isLessThan:
      Timestamp.fromDate(
        nextWeekStart,
      ),
    )
        .snapshots();

    return StreamBuilder<
        QuerySnapshot<
            Map<String, dynamic>>>(
      stream: recordStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return SizedBox(
            height: 190,
            child: AppLoadingView(
              message:
              '시험일과 주간 목표를 불러오는 중입니다.',
            ),
          );
        }

        if (snapshot.hasError) {
          return SizedBox(
            height: 220,
            child: _isNetworkError(
              snapshot.error,
            )
                ? AppNetworkErrorView(
              message:
              '인터넷 연결을 확인해 주세요.',
              description:
              '네트워크 연결 후 목표 정보를 다시 불러와 주세요.',
              onRetryPressed: () {
                _retryDetailPage(
                  context,
                );
              },
            )
                : AppErrorView(
              message:
              '목표 정보를 불러오지 못했습니다.',
              description:
              '잠시 후 다시 시도해 주세요.',
              onRetryPressed: () {
                _retryDetailPage(
                  context,
                );
              },
            ),
          );
        }

        int weeklyStudySeconds = 0;

        if (snapshot.data != null) {
          for (int i = 0;
          i <
              snapshot
                  .data!.docs.length;
          i++) {
            weeklyStudySeconds +=
                _getRecordStudySeconds(
                  snapshot.data!.docs[i]
                      .data(),
                );
          }
        }

        int weeklyGoalSeconds =
            weeklyGoalMinutes * 60;

        double progress = 0;

        if (weeklyGoalSeconds > 0) {
          progress =
              weeklyStudySeconds /
                  weeklyGoalSeconds;

          if (progress > 1) {
            progress = 1;
          }
        }

        int progressPercent =
        (progress * 100).round();

        String ddayText =
        examDate == null
            ? '시험일 미설정'
            : _getDdayText(
          examDate,
        );

        String examDateText =
        examDate == null
            ? '방장이 시험일을 설정할 수 있습니다.'
            : '${_formatExamDate(examDate)} 시험';

        String goalText =
        weeklyGoalMinutes > 0
            ? '${_formatGoalTime(weeklyStudySeconds)} / '
            '${_formatGoalTime(weeklyGoalSeconds)}'
            : '주간 목표 미설정';

        bool hasGoalSetting =
            examDate != null ||
                weeklyGoalMinutes > 0;

        return AppCard(
          backgroundColor:
          _studyColorScheme.surface,
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration:
                    BoxDecoration(
                      color:
                      _studyColors.pinkSoft,
                      borderRadius:
                      BorderRadius.circular(
                        16,
                      ),
                    ),
                    child: Icon(
                      Icons
                          .event_available_rounded,
                      color:
                      _studyColors.pinkStart,
                    ),
                  ),
                  SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                      children: [
                        Text(
                          ddayText,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight:
                            FontWeight.bold,
                            color: _studyColors
                                .pinkStart,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          examDateText,
                          style: TextStyle(
                            fontSize: 11,
                            color: _studyColors
                                .textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isOwner)
                    TextButton(
                      onPressed: () {
                        _showStudyGoalDialog(
                          context,
                          currentStudyData,
                        );
                      },
                      child: Text(
                        hasGoalSetting
                            ? '수정'
                            : '설정',
                        style: TextStyle(
                          color: _studyColors
                              .pinkStart,
                          fontWeight:
                          FontWeight.bold,
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
                        fontWeight:
                        FontWeight.bold,
                        color: _studyColors
                            .textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    goalText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                      FontWeight.w600,
                      color: _studyColors
                          .pinkStart,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),
              ClipRRect(
                borderRadius:
                BorderRadius.circular(
                  10,
                ),
                child:
                LinearProgressIndicator(
                  minHeight: 9,
                  value: progress,
                  backgroundColor:
                  _studyColors.pinkSoft,
                  valueColor:
                  AlwaysStoppedAnimation<
                      Color>(
                    _studyColors.pinkStart,
                  ),
                ),
              ),
              SizedBox(height: 9),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      weeklyGoalMinutes > 0
                          ? '월요일부터 일요일까지 그룹원 공부시간을 합산합니다.'
                          : '방장이 주간 목표시간을 설정하면 달성률이 표시됩니다.',
                      style: TextStyle(
                        fontSize: 10,
                        height: 1.4,
                        color: _studyColors
                            .textSecondary,
                      ),
                    ),
                  ),
                  if (weeklyGoalMinutes >
                      0)
                    Text(
                      '$progressPercent%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                        FontWeight.bold,
                        color: _studyColors
                            .pinkStart,
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// 그룹원 추방
  Future<void> _kickMember({
    required String memberUid,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      throw Exception('로그인 정보가 없습니다.');
    }

    final groupDocument =
    FirebaseFirestore.instance
        .collection('studyGroups')
        .doc(studyId);

    final memberDocument =
    groupDocument
        .collection('members')
        .doc(memberUid);

    await FirebaseFirestore.instance
        .runTransaction(
          (transaction) async {
        final groupSnapshot =
        await transaction.get(
          groupDocument,
        );

        final memberSnapshot =
        await transaction.get(
          memberDocument,
        );

        if (!groupSnapshot.exists ||
            !memberSnapshot.exists) {
          throw Exception(
            '그룹원 정보를 찾을 수 없습니다.',
          );
        }

        final groupData =
            groupSnapshot.data() ?? {};

        final memberData =
            memberSnapshot.data() ?? {};

        if (groupData['ownerUid']?.toString() !=
            currentUser.uid) {
          throw Exception(
            '방장만 그룹원을 추방할 수 있습니다.',
          );
        }

        final role =
            memberData['role']?.toString() ??
                'MEMBER';

        final status =
            memberData['status']?.toString() ??
                'ACTIVE';

        if (role == 'OWNER') {
          throw Exception(
            '방장은 추방할 수 없습니다.',
          );
        }

        if (status != 'ACTIVE') {
          throw Exception(
            '이미 활동 중인 그룹원이 아닙니다.',
          );
        }

        final currentMemberCount =
        _getInt(
          groupData,
          'currentMemberCount',
        );

        final newMemberCount =
        currentMemberCount > 1
            ? currentMemberCount - 1
            : 1;

        final currentStatus =
            groupData['status']?.toString() ??
                'RECRUITING';

        transaction.update(
          memberDocument,
          {
            'status': 'BANNED',
            'bannedAt':
            FieldValue.serverTimestamp(),
            'updatedAt':
            FieldValue.serverTimestamp(),
          },
        );

        transaction.update(
          groupDocument,
          {
            'currentMemberCount':
            newMemberCount,

            // 완료된 스터디가 아니면 다시 모집 중으로 변경
            'status':
            currentStatus == 'COMPLETED'
                ? 'COMPLETED'
                : 'RECRUITING',

            'recruitmentStatus':
            currentStatus == 'COMPLETED'
                ? 'CLOSED'
                : 'OPEN',

            'updatedAt':
            FieldValue.serverTimestamp(),
          },
        );
      },
    );
  }

  /// 그룹원 추방 확인창
  void _showKickMemberDialog({
    required BuildContext context,
    required String memberUid,
    required String nickname,
  }) {
    bool isProcessing = false;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (
              context,
              setDialogState,
              ) {
            Future<void> kickMember() async {
              setDialogState(() {
                isProcessing = true;
              });

              try {
                await _kickMember(
                  memberUid: memberUid,
                );

                if (!dialogContext.mounted) {
                  return;
                }

                Navigator.pop(
                  dialogContext,
                );

                _showMessage(
                  context,
                  '$nickname 님을 스터디에서 추방했습니다.',
                );
              } catch (error) {
                debugPrint(
                  '그룹원 추방 오류: $error',
                );

                if (!dialogContext.mounted) {
                  return;
                }

                setDialogState(() {
                  isProcessing = false;
                });

                _showMessage(
                  context,
                  '그룹원을 추방하지 못했습니다.',
                );
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius:
                BorderRadius.circular(22),
              ),
              title: Row(
                children: [
                  Icon(
                    Icons
                        .person_remove_outlined,
                    color: _studyColorScheme.error,
                  ),
                  SizedBox(width: 10),
                  Text('그룹원 추방'),
                ],
              ),
              content: Text(
                '$nickname 님을 스터디에서 추방하시겠습니까?\n\n'
                    '추방된 사용자는 이 스터디에 참여할 수 없습니다.',
                style: TextStyle(
                  height: 1.5,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isProcessing
                      ? null
                      : () {
                    Navigator.pop(
                      dialogContext,
                    );
                  },
                  child: Text('취소'),
                ),
                ElevatedButton(
                  onPressed: isProcessing
                      ? null
                      : kickMember,
                  style:
                  ElevatedButton.styleFrom(
                    backgroundColor: _studyColorScheme.error,
                    foregroundColor: _studyColorScheme.onPrimary,
                  ),
                  child: isProcessing
                      ? SizedBox(
                    width: 18,
                    height: 18,
                    child:
                    CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _studyColorScheme.onPrimary,
                    ),
                  )
                      : Text('추방'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// 참여 신청 승인
  Future<void> _approveJoinRequest(
      BuildContext context,
      String memberUid,
      ) async {
    try {
      await StudyJoinRequestService.approve(
        studyId: studyId,
        memberUid: memberUid,
      );

      _showMessage(
        context,
        '참여 신청을 승인했습니다.',
      );
    } catch (error) {
      debugPrint(
        '참여 신청 승인 오류: $error',
      );

      _showMessage(
        context,
        error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  /// 참여 신청 거절
  Future<void> _rejectJoinRequest(
      BuildContext context,
      String memberUid,
      ) async {
    try {
      await StudyJoinRequestService.reject(
        studyId: studyId,
        memberUid: memberUid,
      );

      _showMessage(
        context,
        '참여 신청을 거절했습니다.',
      );
    } catch (error) {
      debugPrint(
        '참여 신청 거절 오류: $error',
      );

      _showMessage(
        context,
        error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  /// 참여 신청 관리 창
  void _openJoinRequestManagement(
      BuildContext context,
      ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: _studyColorScheme.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(26),
            ),
          ),
          child: Column(
            children: [
              SizedBox(height: 11),

              Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: _studyColorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  18,
                  12,
                  14,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: _studyColors.lavender,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.how_to_reg_outlined,
                        color: _studyColors.pinkStart,
                      ),
                    ),

                    SizedBox(width: 13),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '참여 신청 관리',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            '참여 신청을 승인하거나 거절합니다.',
                            style: TextStyle(
                              fontSize: 12,
                              color: _studyColors.textSecondary,
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
                child: StreamBuilder<
                    QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('studyGroups')
                      .doc(studyId)
                      .collection('members')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return AppLoadingView(
                        message: '참여 신청 목록을 불러오는 중입니다.',
                      );
                    }

                    if (snapshot.hasError) {
                      return AppErrorView(
                        message: '참여 신청 목록을 불러오지 못했습니다.',
                        description: '잠시 후 다시 시도해 주세요.',
                      );
                    }

                    List<
                        QueryDocumentSnapshot<
                            Map<String, dynamic>>>
                    requestList = [];

                    if (snapshot.data != null) {
                      for (int i = 0;
                      i < snapshot.data!.docs.length;
                      i++) {
                        QueryDocumentSnapshot<
                            Map<String, dynamic>>
                        memberDocument =
                        snapshot.data!.docs[i];

                        String status = memberDocument
                            .data()['status']
                            ?.toString() ??
                            '';

                        if (status == 'PENDING') {
                          requestList.add(memberDocument);
                        }
                      }
                    }

                    if (requestList.isEmpty) {
                      return AppEmptyView(
                        message: '대기 중인 참여 신청이 없습니다.',
                        description: '새로운 신청이 들어오면 이곳에 표시됩니다.',
                      );
                    }

                    return ListView.builder(
                      padding: EdgeInsets.fromLTRB(
                        18,
                        16,
                        18,
                        30,
                      ),
                      itemCount: requestList.length,
                      itemBuilder: (context, index) {
                        QueryDocumentSnapshot<
                            Map<String, dynamic>>
                        memberDocument =
                        requestList[index];

                        Map<String, dynamic> memberData =
                        memberDocument.data();

                        String nickname =
                            memberData['nickname']?.toString() ??
                                '신청자';

                        return Container(
                          margin: EdgeInsets.only(bottom: 12),
                          padding: EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: _studyColorScheme.surface,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: _studyColorScheme.outlineVariant,
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: _studyColors.lavender,
                                child: Icon(
                                  Icons.person_outline,
                                  color: _studyColors.pinkStart,
                                ),
                              ),

                              SizedBox(width: 12),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      nickname,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      '참여 승인 대기 중',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: _studyColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              OutlinedButton(
                                onPressed: () {
                                  _rejectJoinRequest(
                                    context,
                                    memberDocument.id,
                                  );
                                },
                                child: Text('거절'),
                              ),

                              SizedBox(width: 7),

                              ElevatedButton(
                                onPressed: () {
                                  _approveJoinRequest(
                                    context,
                                    memberDocument.id,
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _studyColors.pinkStart,
                                  foregroundColor: _studyColorScheme.onPrimary,
                                ),
                                child: Text('승인'),
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

  /// 방장에게 참여 신청 수 표시
  Widget _buildJoinRequestArea(
      BuildContext context,
      Map<String, dynamic> currentStudyData,
      ) {
    if (_isOwner(currentStudyData) == false) {
      return SizedBox();
    }

    return StreamBuilder<
        QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('studyGroups')
          .doc(studyId)
          .collection('members')
          .snapshots(),
      builder: (context, snapshot) {
        int pendingCount = 0;

        if (snapshot.data != null) {
          for (int i = 0;
          i < snapshot.data!.docs.length;
          i++) {
            Map<String, dynamic> memberData =
            snapshot.data!.docs[i].data();

            String status =
                memberData['status']?.toString() ?? '';

            if (status == 'PENDING') {
              pendingCount++;
            }
          }
        }

        String description =
            '대기 중인 참여 신청이 없습니다.';

        if (pendingCount > 0) {
          description =
          '승인 또는 거절할 신청이 있습니다.';
        }

        return _buildMenuButton(
          icon: Icons.how_to_reg_outlined,
          title: '참여 신청 관리 ($pendingCount명)',
          description: description,
          onTap: () {
            _openJoinRequestManagement(context);
          },
        );
      },
    );
  }


  /// 그룹원 목록 화면
  Future<void> _openMemberList(
      BuildContext context,
      Map<String, dynamic> currentStudyData,
      ) async {
    try {
      await _ensureOwnerMember(currentStudyData);
    } catch (error) {
      debugPrint('방장 멤버 정보 생성 오류: $error');
    }

    if (!context.mounted) {
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.72,
          decoration: BoxDecoration(
            color: _studyColorScheme.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(26),
            ),
          ),
          child: Column(
            children: [
              SizedBox(height: 11),

              Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: _studyColorScheme.outlineVariant,
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
                        color: _studyColors.lavender,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.groups_outlined,
                        color: _studyColors.pinkStart,
                      ),
                    ),

                    SizedBox(width: 13),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '그룹원 목록',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            '현재 활동 중인 그룹원을 확인합니다.',
                            style: TextStyle(
                              fontSize: 12,
                              color: _studyColors.textSecondary,
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
                child: StreamBuilder<
                    QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('studyGroups')
                      .doc(studyId)
                      .collection('members')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return AppLoadingView(
                        message: '그룹원 목록을 불러오는 중입니다.',
                      );
                    }

                    if (snapshot.hasError) {
                      debugPrint(
                        '그룹원 목록 조회 오류: ${snapshot.error}',
                      );

                      return AppErrorView(
                        message: '그룹원 목록을 불러오지 못했습니다.',
                        description: '잠시 후 다시 시도해 주세요.',
                      );
                    }

                    List<
                        QueryDocumentSnapshot<
                            Map<String, dynamic>>>
                    ownerList = [];

                    List<
                        QueryDocumentSnapshot<
                            Map<String, dynamic>>>
                    normalMemberList = [];

                    if (snapshot.data != null) {
                      for (int i = 0;
                      i < snapshot.data!.docs.length;
                      i++) {
                        QueryDocumentSnapshot<
                            Map<String, dynamic>>
                        memberDocument =
                        snapshot.data!.docs[i];

                        Map<String, dynamic> memberData =
                        memberDocument.data();

                        String status =
                            memberData['status']?.toString() ?? '';

                        String role =
                            memberData['role']?.toString() ?? 'MEMBER';

                        if (status == 'ACTIVE') {
                          if (role == 'OWNER') {
                            ownerList.add(memberDocument);
                          } else {
                            normalMemberList.add(memberDocument);
                          }
                        }
                      }
                    }

                    List<
                        QueryDocumentSnapshot<
                            Map<String, dynamic>>>
                    memberList = [];

                    memberList.addAll(ownerList);
                    memberList.addAll(normalMemberList);

                    if (memberList.isEmpty) {
                      return AppEmptyView(
                        message: '등록된 그룹원이 없습니다.',
                        description: '새로운 그룹원이 참여하면 이곳에 표시됩니다.',
                      );
                    }

                    return ListView.builder(
                      padding: EdgeInsets.fromLTRB(18, 16, 18, 30),
                      itemCount: memberList.length,
                      itemBuilder: (context, index) {
                        QueryDocumentSnapshot<
                            Map<String, dynamic>>
                        memberDocument = memberList[index];

                        Map<String, dynamic> memberData =
                        memberDocument.data();

                        String nickname =
                            memberData['nickname']?.toString() ??
                                '스터디원';

                        String role =
                            memberData['role']?.toString() ?? 'MEMBER';

                        int totalStudyMinutes = _getInt(
                          memberData,
                          'totalStudyMinutes',
                        );

                        bool isOwner = role == 'OWNER';

                        String firstLetter = '?';

                        if (nickname.isNotEmpty) {
                          firstLetter = nickname[0].toUpperCase();
                        }

                        return Container(
                          margin: EdgeInsets.only(bottom: 11),
                          padding: EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: _studyColorScheme.surface,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: _studyColorScheme.outlineVariant,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: _studyColors.lavender,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  firstLetter,
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: _studyColors.pinkStart,
                                  ),
                                ),
                              ),

                              SizedBox(width: 13),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            nickname,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                            ),
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
                                              color: _studyColors.pinkSoft,
                                              borderRadius:
                                              BorderRadius.circular(11),
                                            ),
                                            child: Text(
                                              '방장',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: _studyColors.pinkStart,
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
                                          '${_formatStudyTime(totalStudyMinutes)}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: _studyColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
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

  /// 그룹원 관리 화면
  Future<void> _openMemberManagement(
      BuildContext context,
      Map<String, dynamic> currentStudyData,
      ) async {
    try {
      await _ensureOwnerMember(
        currentStudyData,
      );
    } catch (error) {
      debugPrint(
        '방장 멤버 정보 생성 오류: $error',
      );
    }

    if (!context.mounted) {
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.76,
          minChildSize: 0.50,
          maxChildSize: 0.93,
          expand: false,
          builder: (
              context,
              scrollController,
              ) {
            return Container(
              decoration: BoxDecoration(
                color: _studyColorScheme.surface,
                borderRadius:
                BorderRadius.vertical(
                  top: Radius.circular(26),
                ),
              ),
              child: Column(
                children: [
                  SizedBox(height: 11),

                  Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: _studyColorScheme.outlineVariant,
                      borderRadius:
                      BorderRadius.circular(10),
                    ),
                  ),

                  Padding(
                    padding:
                    EdgeInsets.fromLTRB(
                      20,
                      18,
                      12,
                      14,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: _studyColors.lavender,
                            borderRadius:
                            BorderRadius.circular(
                              14,
                            ),
                          ),
                          child: Icon(
                            Icons
                                .manage_accounts_outlined,
                            color: _studyColors.pinkStart,
                          ),
                        ),

                        SizedBox(width: 13),

                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                            children: [
                              Text(
                                '그룹원 관리',
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight:
                                  FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                '활동 중인 그룹원을 확인하고 관리합니다.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _studyColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),

                        IconButton(
                          onPressed: () {
                            Navigator.pop(
                              bottomSheetContext,
                            );
                          },
                          icon: Icon(
                            Icons.close_rounded,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Divider(height: 1),

                  Expanded(
                    child: StreamBuilder<
                        QuerySnapshot<
                            Map<String, dynamic>>>(
                      stream:
                      FirebaseFirestore.instance
                          .collection(
                        'studyGroups',
                      )
                          .doc(studyId)
                          .collection('members')
                          .snapshots(),
                      builder:
                          (context, snapshot) {
                        if (snapshot
                            .connectionState ==
                            ConnectionState
                                .waiting) {
                          return Center(
                            child:
                            CircularProgressIndicator(),
                          );
                        }

                        if (snapshot.hasError) {
                          debugPrint(
                            '그룹원 조회 오류: '
                                '${snapshot.error}',
                          );

                          return Center(
                            child: Text(
                              '그룹원 목록을 불러오지 못했습니다.',
                            ),
                          );
                        }

                        final memberList =
                            snapshot.data?.docs
                                .where(
                                  (document) {
                                final status =
                                document
                                    .data()[
                                'status']
                                    ?.toString();

                                return status ==
                                    'ACTIVE';
                              },
                            )
                                .toList() ??
                                [];

                        // 방장이 가장 위에 표시되도록 정렬
                        memberList.sort(
                              (a, b) {
                            final aRole =
                                a.data()['role']
                                    ?.toString() ??
                                    'MEMBER';

                            final bRole =
                                b.data()['role']
                                    ?.toString() ??
                                    'MEMBER';

                            if (aRole == 'OWNER' &&
                                bRole != 'OWNER') {
                              return -1;
                            }

                            if (aRole != 'OWNER' &&
                                bRole == 'OWNER') {
                              return 1;
                            }

                            final aNickname =
                                a.data()['nickname']
                                    ?.toString() ??
                                    '';

                            final bNickname =
                                b.data()['nickname']
                                    ?.toString() ??
                                    '';

                            return aNickname
                                .compareTo(
                              bNickname,
                            );
                          },
                        );

                        if (memberList.isEmpty) {
                          return Center(
                            child: Text(
                              '등록된 그룹원이 없습니다.',
                            ),
                          );
                        }

                        return ListView.builder(
                          controller:
                          scrollController,
                          padding:
                          EdgeInsets.fromLTRB(
                            18,
                            16,
                            18,
                            30,
                          ),
                          itemCount:
                          memberList.length,
                          itemBuilder:
                              (context, index) {
                            final memberDocument =
                            memberList[index];

                            final memberData =
                            memberDocument.data();

                            final nickname =
                                memberData['nickname']
                                    ?.toString() ??
                                    '스터디원';

                            final role =
                                memberData['role']
                                    ?.toString() ??
                                    'MEMBER';

                            final totalStudyMinutes =
                            _getInt(
                              memberData,
                              'totalStudyMinutes',
                            );

                            final isOwner =
                                role == 'OWNER';

                            return Container(
                              margin:
                              EdgeInsets.only(
                                bottom: 11,
                              ),
                              padding:
                              EdgeInsets.all(
                                15,
                              ),
                              decoration: BoxDecoration(
                                color: _studyColorScheme.surface,
                                borderRadius:
                                BorderRadius.circular(
                                  18,
                                ),
                                border: Border.all(
                                  color: _studyColorScheme.outlineVariant,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 46,
                                    height: 46,
                                    alignment:
                                    Alignment.center,
                                    decoration:
                                    BoxDecoration(
                                      color: _studyColors.lavender,
                                      shape:
                                      BoxShape.circle,
                                    ),
                                    child: Text(
                                      nickname.isNotEmpty
                                          ? nickname[0]
                                          .toUpperCase()
                                          : '?',
                                      style:
                                      TextStyle(
                                        fontSize: 17,
                                        fontWeight:
                                        FontWeight
                                            .bold,
                                        color: _studyColors.pinkStart,
                                      ),
                                    ),
                                  ),

                                  SizedBox(
                                    width: 13,
                                  ),

                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment
                                          .start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                nickname,
                                                overflow:
                                                TextOverflow
                                                    .ellipsis,
                                                style:
                                                TextStyle(
                                                  fontSize:
                                                  15,
                                                  fontWeight:
                                                  FontWeight
                                                      .bold,
                                                ),
                                              ),
                                            ),

                                            if (isOwner) ...[
                                              SizedBox(
                                                width: 7,
                                              ),
                                              Container(
                                                padding:
                                                EdgeInsets
                                                    .symmetric(
                                                  horizontal:
                                                  8,
                                                  vertical:
                                                  3,
                                                ),
                                                decoration:
                                                BoxDecoration(
                                                  color:
                                                  _studyColors.pinkSoft,
                                                  borderRadius:
                                                  BorderRadius
                                                      .circular(
                                                    11,
                                                  ),
                                                ),
                                                child:
                                                Text(
                                                  '방장',
                                                  style:
                                                  TextStyle(
                                                    fontSize:
                                                    10,
                                                    color:
                                                    _studyColors.pinkStart,
                                                    fontWeight:
                                                    FontWeight
                                                        .w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),

                                        SizedBox(
                                          height: 5,
                                        ),

                                        Text(
                                          '누적 공부시간 '
                                              '${_formatStudyTime(totalStudyMinutes)}',
                                          style:
                                          TextStyle(
                                            fontSize: 11,
                                            color: _studyColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  if (!isOwner)
                                    OutlinedButton(
                                      onPressed: () {
                                        _showKickMemberDialog(
                                          context:
                                          context,
                                          memberUid:
                                          memberDocument
                                              .id,
                                          nickname:
                                          nickname,
                                        );
                                      },
                                      style:
                                      OutlinedButton
                                          .styleFrom(
                                        foregroundColor:
                                        _studyColorScheme.error,
                                        side:
                                        BorderSide(
                                          color: _studyColorScheme.secondaryContainer,
                                        ),
                                        minimumSize:
                                        Size(
                                          64,
                                          38,
                                        ),
                                      ),
                                      child:
                                      Text(
                                        '추방',
                                      ),
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
      },
    );
  }

  /// 공부시간 순위 표시
  Future<void> _openStudyRanking(
      BuildContext context,
      Map<String, dynamic> currentStudyData,
      ) async {
    try {
      await _ensureOwnerMember(
        currentStudyData,
      );
    } catch (error) {
      debugPrint(
        '방장 멤버 정보 생성 오류: $error',
      );
    }

    if (!context.mounted) {
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.72,
          minChildSize: 0.45,
          maxChildSize: 0.92,
          expand: false,
          builder: (
              context,
              scrollController,
              ) {
            return Container(
              decoration: BoxDecoration(
                color: _studyColorScheme.surface,
                borderRadius:
                BorderRadius.vertical(
                  top: Radius.circular(26),
                ),
              ),
              child: Column(
                children: [
                  SizedBox(height: 11),

                  Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: _studyColorScheme.outlineVariant,
                      borderRadius:
                      BorderRadius.circular(10),
                    ),
                  ),

                  Padding(
                    padding:
                    EdgeInsets.fromLTRB(
                      20,
                      18,
                      12,
                      14,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: _studyColors.lavender,
                            borderRadius:
                            BorderRadius.circular(
                              14,
                            ),
                          ),
                          child: Icon(
                            Icons
                                .emoji_events_outlined,
                            color: _studyColors.pinkStart,
                          ),
                        ),

                        SizedBox(width: 13),

                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                            children: [
                              Text(
                                '공부시간 순위',
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight:
                                  FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                '전체 누적 공부시간 기준',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _studyColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),

                        IconButton(
                          onPressed: () {
                            Navigator.pop(
                              bottomSheetContext,
                            );
                          },
                          icon: Icon(
                            Icons.close_rounded,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Divider(height: 1),

                  Expanded(
                    child: StreamBuilder<
                        QuerySnapshot<
                            Map<String, dynamic>>>(
                      stream:
                      FirebaseFirestore.instance
                          .collection(
                        'studyGroups',
                      )
                          .doc(studyId)
                          .collection('members')
                          .snapshots(),
                      builder:
                          (context, snapshot) {
                        if (snapshot
                            .connectionState ==
                            ConnectionState
                                .waiting) {
                          return Center(
                            child:
                            CircularProgressIndicator(),
                          );
                        }

                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              '공부시간 순위를 불러오지 못했습니다.',
                            ),
                          );
                        }

                        final memberList =
                            snapshot.data?.docs
                                .where(
                                  (document) {
                                final status =
                                document
                                    .data()[
                                'status']
                                    ?.toString();

                                return status ==
                                    'ACTIVE';
                              },
                            )
                                .toList() ??
                                [];

                        memberList.sort(
                              (a, b) {
                            final aMinutes =
                            _getInt(
                              a.data(),
                              'totalStudyMinutes',
                            );

                            final bMinutes =
                            _getInt(
                              b.data(),
                              'totalStudyMinutes',
                            );

                            return bMinutes
                                .compareTo(
                              aMinutes,
                            );
                          },
                        );

                        if (memberList.isEmpty) {
                          return Center(
                            child: Text(
                              '표시할 공부시간이 없습니다.',
                            ),
                          );
                        }

                        return ListView.builder(
                          controller:
                          scrollController,
                          padding:
                          EdgeInsets.fromLTRB(
                            18,
                            16,
                            18,
                            30,
                          ),
                          itemCount:
                          memberList.length,
                          itemBuilder:
                              (context, index) {
                            final memberDocument =
                            memberList[index];

                            return _buildRankingItem(
                              rank: index + 1,
                              memberUid:
                              memberDocument.id,
                              memberData:
                              memberDocument
                                  .data(),
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
      },
    );
  }

  /// 공부시간 순위 한 줄
  Widget _buildRankingItem({
    required int rank,
    required String memberUid,
    required Map<String, dynamic> memberData,
  }) {
    final currentUserUid =
        FirebaseAuth.instance.currentUser?.uid;

    final isCurrentUser =
        currentUserUid == memberUid;

    final nickname =
        memberData['nickname']?.toString() ??
            '스터디원';

    final role =
        memberData['role']?.toString() ??
            'MEMBER';

    final totalStudyMinutes =
    _getInt(
      memberData,
      'totalStudyMinutes',
    );

    Color rankBackgroundColor;
    Color rankTextColor;

    if (rank == 1) {
      rankBackgroundColor =
          _studyColorScheme.secondary;
      rankTextColor =
          _studyColorScheme.secondary;
    } else if (rank == 2) {
      rankBackgroundColor =
          _studyColorScheme.surface;
      rankTextColor =
          _studyColors.textSecondary;
    } else if (rank == 3) {
      rankBackgroundColor =
          _studyColorScheme.secondary;
      rankTextColor =
          _studyColorScheme.secondary;
    } else {
      rankBackgroundColor =
          _studyColors.lavender;
      rankTextColor =
          _studyColors.pinkStart;
    }

    return Container(
      margin:
      EdgeInsets.only(bottom: 11),
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? _studyColors.lavender
            : _studyColorScheme.surface,
        borderRadius:
        BorderRadius.circular(18),
        border: Border.all(
          color: isCurrentUser
              ? _studyColors.pinkStart
              : _studyColorScheme.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: rankBackgroundColor,
              shape: BoxShape.circle,
            ),
            child: rank <= 3
                ? Icon(
              Icons
                  .emoji_events_rounded,
              size: 21,
              color: rankTextColor,
            )
                : Text(
              '$rank',
              style: TextStyle(
                color: rankTextColor,
                fontWeight:
                FontWeight.bold,
              ),
            ),
          ),

          SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        nickname,
                        overflow:
                        TextOverflow.ellipsis,
                        style:
                        TextStyle(
                          fontSize: 15,
                          fontWeight:
                          FontWeight.bold,
                        ),
                      ),
                    ),

                    if (role == 'OWNER') ...[
                      SizedBox(width: 7),
                      _buildMiniBadge(
                        text: '방장',
                        backgroundColor:
                        _studyColors.pinkSoft,
                        textColor:
                        _studyColors.pinkStart,
                      ),
                    ],

                    if (isCurrentUser) ...[
                      SizedBox(width: 7),
                      _buildMiniBadge(
                        text: '나',
                        backgroundColor:
                        _studyColors.lavender,
                        textColor:
                        _studyColors.pinkStart,
                      ),
                    ],
                  ],
                ),

                SizedBox(height: 5),

                Text(
                  '누적 공부시간',
                  style: TextStyle(
                    fontSize: 11,
                    color: _studyColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(width: 10),

          Text(
            _formatStudyTime(
              totalStudyMinutes,
            ),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: _studyColors.pinkStart,
            ),
          ),
        ],
      ),
    );
  }

  /// 작은 미니 배지
  Widget _buildMiniBadge({
    required String text,
    required Color backgroundColor,
    required Color textColor,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius:
        BorderRadius.circular(11),
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

  /// 스터디 참여 처리
  Future<void> _joinStudy(
      BuildContext context,
      Map<String, dynamic> currentStudyData,
      ) async {
    FirebaseAuth auth = FirebaseAuth.instance;
    User? currentUser = auth.currentUser;

    if (currentUser == null) {
      _showMessage(
        context,
        '로그인 정보가 없습니다.',
      );
      return;
    }

    if (_isOwner(currentStudyData)) {
      _showMessage(
        context,
        '방장은 이미 스터디에 참여 중입니다.',
      );
      return;
    }

    DocumentReference<Map<String, dynamic>> groupDocument =
    FirebaseFirestore.instance
        .collection('studyGroups')
        .doc(studyId);

    DocumentReference<Map<String, dynamic>> memberDocument =
    groupDocument
        .collection('members')
        .doc(currentUser.uid);

    try {
      DocumentSnapshot<Map<String, dynamic>> groupSnapshot =
      await groupDocument.get();

      if (groupSnapshot.exists == false) {
        _showMessage(
          context,
          '스터디 정보를 찾을 수 없습니다.',
        );
        return;
      }

      Map<String, dynamic> groupData =
          groupSnapshot.data() ?? {};

      String groupStatus =
          groupData['status']?.toString() ?? '';

      int currentMemberCount = _getInt(
        groupData,
        'currentMemberCount',
      );

      int maxMemberCount = _getInt(
        groupData,
        'maxMemberCount',
      );

      if (groupStatus == 'COMPLETED') {
        _showMessage(
          context,
          '종료된 스터디에는 참여할 수 없습니다.',
        );
        return;
      }

      if (_isRecruiting(groupData) == false) {
        _showMessage(
          context,
          '모집이 마감된 스터디입니다.',
        );
        return;
      }

      DocumentSnapshot<Map<String, dynamic>> memberSnapshot =
      await memberDocument.get();

      int totalStudyMinutes = 0;
      int totalStudySeconds = 0;

      if (memberSnapshot.exists) {
        Map<String, dynamic> oldMemberData =
            memberSnapshot.data() ?? {};

        String oldStatus =
            oldMemberData['status']?.toString() ?? '';

        totalStudyMinutes = _getInt(
          oldMemberData,
          'totalStudyMinutes',
        );

        totalStudySeconds = _getInt(
          oldMemberData,
          'totalStudySeconds',
        );

        if (oldStatus == 'ACTIVE') {
          _showMessage(
            context,
            '이미 참여 중인 스터디입니다.',
          );
          return;
        }

        if (oldStatus == 'PENDING') {
          _showMessage(
            context,
            '이미 참여 승인을 기다리고 있습니다.',
          );
          return;
        }

        if (oldStatus == 'BANNED') {
          _showMessage(
            context,
            '이 스터디에는 참여할 수 없습니다.',
          );
          return;
        }
      }

      bool joinApprovalRequired = true;

      if (groupData['joinApprovalRequired'] is bool) {
        joinApprovalRequired =
        groupData['joinApprovalRequired'];
      }

      Map<String, String> userProfile =
      await _getUserProfile(currentUser.uid);

      String nickname =
          userProfile['nickname'] ?? '';

      if (nickname.isEmpty) {
        nickname = '사용자';
      }

      String profileImageUrl =
          userProfile['profileImageUrl'] ?? '';

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot<Map<String, dynamic>> latestGroupSnapshot =
        await transaction.get(groupDocument);
        DocumentSnapshot<Map<String, dynamic>> latestMemberSnapshot =
        await transaction.get(memberDocument);

        if (!latestGroupSnapshot.exists) {
          throw Exception('스터디 정보를 찾을 수 없습니다.');
        }

        Map<String, dynamic> latestGroupData =
            latestGroupSnapshot.data() ?? {};
        Map<String, dynamic> latestMemberData =
            latestMemberSnapshot.data() ?? {};
        String latestMemberStatus =
            latestMemberData['status']?.toString() ?? '';

        if (latestMemberStatus == 'ACTIVE') {
          throw Exception('이미 참여 중인 스터디입니다.');
        }
        if (latestMemberStatus == 'PENDING') {
          throw Exception('이미 참여 승인을 기다리고 있습니다.');
        }
        if (latestMemberStatus == 'BANNED') {
          throw Exception('이 스터디에는 참여할 수 없습니다.');
        }
        if (latestGroupData['status']?.toString() == 'COMPLETED' ||
            !_isRecruiting(latestGroupData)) {
          throw Exception('모집이 마감된 스터디입니다.');
        }

        int latestMemberCount = _getInt(
          latestGroupData,
          'currentMemberCount',
        );
        int latestMaxMemberCount = _getInt(
          latestGroupData,
          'maxMemberCount',
        );

        if (latestMaxMemberCount > 0 &&
            latestMemberCount >= latestMaxMemberCount) {
          throw Exception('모집 인원이 모두 찼습니다.');
        }

        int savedStudyMinutes = _getInt(
          latestMemberData,
          'totalStudyMinutes',
        );
        int savedStudySeconds = _getInt(
          latestMemberData,
          'totalStudySeconds',
        );

        if (savedStudyMinutes == 0) {
          savedStudyMinutes = totalStudyMinutes;
        }
        if (savedStudySeconds == 0) {
          savedStudySeconds = totalStudySeconds;
        }

        if (joinApprovalRequired) {
          transaction.set(
            memberDocument,
            {
              'uid': currentUser.uid,
              'nickname': nickname,
              'profileImageUrl': profileImageUrl,
              'role': 'MEMBER',
              'status': 'PENDING',
              'totalStudyMinutes': savedStudyMinutes,
              'totalStudySeconds': savedStudySeconds,
              'requestedAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
          return;
        }

        int newMemberCount = latestMemberCount + 1;
        bool isFull = latestMaxMemberCount > 0 &&
            newMemberCount >= latestMaxMemberCount;

        transaction.set(
          memberDocument,
          {
            'uid': currentUser.uid,
            'nickname': nickname,
            'profileImageUrl': profileImageUrl,
            'role': 'MEMBER',
            'status': 'ACTIVE',
            'totalStudyMinutes': savedStudyMinutes,
            'totalStudySeconds': savedStudySeconds,
            'joinedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        transaction.update(groupDocument, {
          'currentMemberCount': newMemberCount,
          'status': isFull ? 'CLOSED' : 'RECRUITING',
          'recruitmentStatus': isFull ? 'CLOSED' : 'OPEN',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      if (!context.mounted) {
        return;
      }

      _showMessage(
        context,
        joinApprovalRequired
            ? '참여 신청을 보냈습니다.'
            : '스터디에 참여했습니다.',
      );
    } catch (error) {
      debugPrint(
        '스터디 참여 오류: $error',
      );

      if (!context.mounted) {
        return;
      }

      _showMessage(
        context,
        error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  /// 참여 상태와 참여 버튼
  Widget _buildJoinArea(
      BuildContext context,
      Map<String, dynamic> currentStudyData,
      ) {
    User? currentUser =
        FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return AppCard(
        backgroundColor: _studyColorScheme.surface,
        child: Text(
          '로그인 후 스터디에 참여할 수 있습니다.',
        ),
      );
    }

    if (_isOwner(currentStudyData)) {
      return SizedBox();
    }

    Stream<DocumentSnapshot<Map<String, dynamic>>> memberStream =
    FirebaseFirestore.instance
        .collection('studyGroups')
        .doc(studyId)
        .collection('members')
        .doc(currentUser.uid)
        .snapshots();

    return StreamBuilder<
        DocumentSnapshot<Map<String, dynamic>>>(
      stream: memberStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return SizedBox(
            height: 180,
            child: AppLoadingView(
              message: '참여 상태를 확인하는 중입니다.',
            ),
          );
        }

        if (snapshot.hasError) {
          if (_isNetworkError(snapshot.error)) {
            return SizedBox(
              height: 220,
              child: AppNetworkErrorView(
                message: '인터넷 연결을 확인해 주세요.',
                description:
                '네트워크 연결 후 참여 상태를 다시 확인해 주세요.',
                onRetryPressed: () {
                  _retryDetailPage(context);
                },
              ),
            );
          }

          return SizedBox(
            height: 220,
            child: AppErrorView(
              message: '참여 상태를 확인하지 못했습니다.',
              description: '잠시 후 다시 시도해 주세요.',
              onRetryPressed: () {
                _retryDetailPage(context);
              },
            ),
          );
        }

        String memberStatus = '';

        if (snapshot.data != null &&
            snapshot.data!.exists) {
          Map<String, dynamic> memberData =
              snapshot.data!.data() ?? {};

          memberStatus =
              memberData['status']?.toString() ?? '';
        }

        if (memberStatus == 'ACTIVE') {
          return AppCard(
            backgroundColor: _studyColorScheme.surface,
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: _studyColorScheme.tertiary,
                ),
                SizedBox(width: 10),
                Text(
                  '참여 중인 스터디입니다.',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        }

        if (memberStatus == 'PENDING') {
          return AppCard(
            backgroundColor: _studyColorScheme.surface,
            child: Row(
              children: [
                Icon(
                  Icons.schedule_outlined,
                  color: _studyColorScheme.secondary,
                ),
                SizedBox(width: 10),
                Text(
                  '방장의 참여 승인을 기다리고 있습니다.',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        }

        if (memberStatus == 'BANNED') {
          return AppCard(
            backgroundColor: _studyColorScheme.surface,
            child: Row(
              children: [
                Icon(
                  Icons.block,
                  color: _studyColorScheme.error,
                ),
                SizedBox(width: 10),
                Text(
                  '이 스터디에는 참여할 수 없습니다.',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        }

        if (_isRecruiting(currentStudyData) == false) {
          return AppCard(
            backgroundColor: _studyColorScheme.surface,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  color: _studyColors.textSecondary,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '모집이 마감된 스터디입니다.',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '스터디 정보는 확인할 수 있지만 새로 참여할 수 없습니다.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: _studyColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        bool joinApprovalRequired = true;

        if (currentStudyData['joinApprovalRequired']
        is bool) {
          joinApprovalRequired =
          currentStudyData['joinApprovalRequired'];
        }

        String buttonText = '바로 참여하기';

        if (joinApprovalRequired) {
          buttonText = '참여 신청하기';
        }

        return AppButton(
          text: buttonText,
          type: AppButtonType.primaryPink,
          height: 50,
          onPressed: () {
            _joinStudy(
              context,
              currentStudyData,
            );
          },
        );
      },
    );
  }


  /// 참여 중인 그룹원에게 스터디방 입장 버튼 표시
  Widget _buildStudyRoomArea(
      BuildContext context,
      Map<String, dynamic> currentStudyData,
      ) {
    User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return SizedBox();
    }

    String groupName =
        currentStudyData['groupName']?.toString() ?? '스터디';

    Widget roomButton = AppButton(
      text: '스터디방 들어가기',
      type: AppButtonType.primaryPink,
      height: 52,
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) {
              return StudyRoomPage(
                studyId: studyId,
                groupName: groupName,
              );
            },
          ),
        );
      },
    );

    if (_isOwner(currentStudyData)) {
      return roomButton;
    }

    return StreamBuilder<
        DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('studyGroups')
          .doc(studyId)
          .collection('members')
          .doc(currentUser.uid)
          .snapshots(),
      builder: (context, snapshot) {
        String memberStatus = '';

        if (snapshot.data != null &&
            snapshot.data!.exists) {
          Map<String, dynamic> memberData =
              snapshot.data!.data() ?? {};

          memberStatus =
              memberData['status']?.toString() ?? '';
        }

        if (memberStatus == 'ACTIVE') {
          return roomButton;
        }

        return SizedBox();
      },
    );
  }

  /// 방장 또는 참여 중인 그룹원에게 관리 메뉴 표시
  Widget _buildStudyManageArea(
      BuildContext context,
      Map<String, dynamic> currentStudyData,
      String groupName,
      ) {
    User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return SizedBox();
    }

    if (_isOwner(currentStudyData)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '스터디 관리',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          SizedBox(height: 12),

          _buildMenuButton(
            icon: Icons.person_add_alt_outlined,
            title: '그룹원 초대',
            description: '아이디 또는 이메일로 그룹원을 초대해요.',
            onTap: () {
              _showInviteDialog(
                context,
                groupName,
              );
            },
          ),

          SizedBox(height: 12),

          _buildMenuButton(
            icon: Icons.report_outlined,
            title: '그룹원 신고',
            description: '문제가 있는 그룹원을 신고해요.',
            onTap: () {
              _showReportDialog(
                context,
                groupName,
              );
            },
          ),
        ],
      );
    }

    return StreamBuilder<
        DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('studyGroups')
          .doc(studyId)
          .collection('members')
          .doc(currentUser.uid)
          .snapshots(),
      builder: (context, snapshot) {
        String memberStatus = '';

        if (snapshot.data != null &&
            snapshot.data!.exists) {
          Map<String, dynamic> memberData =
              snapshot.data!.data() ?? {};

          memberStatus =
              memberData['status']?.toString() ?? '';
        }

        if (memberStatus != 'ACTIVE') {
          return SizedBox();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '스터디 관리',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            SizedBox(height: 12),

            _buildMenuButton(
              icon: Icons.report_outlined,
              title: '그룹원 신고',
              description: '문제가 있는 그룹원을 신고해요.',
              onTap: () {
                _showReportDialog(
                  context,
                  groupName,
                );
              },
            ),

            SizedBox(height: 12),

            _buildMenuButton(
              icon: Icons.logout,
              title: '스터디방 나가기',
              description: '현재 스터디에서 나가요.',
              onTap: () {
                _showLeaveDialog(context);
              },
            ),
          ],
        );
      },
    );
  }

  /// 참여 중인 사용자에게만 스터디 나가기 표시
  Widget _buildLeaveArea(
      BuildContext context,
      Map<String, dynamic> currentStudyData,
      ) {
    User? currentUser =
        FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return SizedBox();
    }

    if (_isOwner(currentStudyData)) {
      return SizedBox();
    }

    return StreamBuilder<
        DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('studyGroups')
          .doc(studyId)
          .collection('members')
          .doc(currentUser.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return SizedBox();
        }

        String memberStatus = '';

        if (snapshot.data != null &&
            snapshot.data!.exists) {
          Map<String, dynamic> memberData =
              snapshot.data!.data() ?? {};

          memberStatus =
              memberData['status']?.toString() ?? '';
        }

        if (memberStatus != 'ACTIVE') {
          return SizedBox();
        }

        return Column(
          children: [
            SizedBox(height: 12),
            _buildMenuButton(
              icon: Icons.logout,
              title: '스터디방 나가기',
              description: '현재 스터디에서 나가요.',
              onTap: () {
                _showLeaveDialog(context);
              },
            ),
          ],
        );
      },
    );
  }

  /// 그룹원 초대 창
  void _showInviteDialog(
      BuildContext context,
      String groupName,
      ) {
    final TextEditingController
    inviteController =
    TextEditingController();

    bool isSending = false;
    String? inputError;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (
              context,
              setDialogState,
              ) {
            Future<void> sendInvite() async {
              final target =
              inviteController.text.trim();

              if (target.isEmpty) {
                setDialogState(() {
                  inputError =
                  '아이디 또는 이메일을 입력해주세요.';
                });

                return;
              }

              if (target.length < 2) {
                setDialogState(() {
                  inputError =
                  '2글자 이상 입력해주세요.';
                });

                return;
              }

              setDialogState(() {
                isSending = true;
                inputError = null;
              });

              try {
                await _saveInvite(
                  groupName: groupName,
                  target: target,
                );

                if (!dialogContext.mounted) {
                  return;
                }

                Navigator.pop(
                  dialogContext,
                );

                _showMessage(
                  context,
                  '그룹 초대를 보냈습니다.',
                );
              } catch (error) {
                debugPrint(
                  '그룹 초대 저장 오류: $error',
                );

                if (!dialogContext.mounted) {
                  return;
                }

                setDialogState(() {
                  isSending = false;
                  inputError =
                  '초대를 보내지 못했습니다.';
                });
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius:
                BorderRadius.circular(22),
              ),
              title: Row(
                children: [
                  Icon(
                    Icons
                        .person_add_alt_outlined,
                    color: _studyColors.pinkStart,
                  ),
                  SizedBox(width: 10),
                  Text('그룹원 초대'),
                ],
              ),
              content: Column(
                mainAxisSize:
                MainAxisSize.min,
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    '초대할 사용자의 아이디 또는 이메일을 입력해주세요.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: _studyColors.textSecondary,
                    ),
                  ),

                  SizedBox(height: 16),

                  TextField(
                    controller:
                    inviteController,
                    enabled: !isSending,
                    autofocus: true,
                    textInputAction:
                    TextInputAction.done,
                    onSubmitted: (_) {
                      if (!isSending) {
                        sendInvite();
                      }
                    },
                    decoration:
                    InputDecoration(
                      labelText:
                      '아이디 또는 이메일',
                      hintText:
                      '예: user01 또는 user@email.com',
                      errorText: inputError,
                      prefixIcon:
                      Icon(
                        Icons
                            .alternate_email_rounded,
                      ),
                      border:
                      OutlineInputBorder(
                        borderRadius:
                        BorderRadius.circular(
                          14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSending
                      ? null
                      : () {
                    Navigator.pop(
                      dialogContext,
                    );
                  },
                  child: Text('취소'),
                ),
                ElevatedButton(
                  onPressed: isSending
                      ? null
                      : sendInvite,
                  style:
                  ElevatedButton.styleFrom(
                    backgroundColor:
                    _studyColors.pinkStart,
                    foregroundColor:
                    _studyColorScheme.surface,
                  ),
                  child: isSending
                      ? SizedBox(
                    width: 18,
                    height: 18,
                    child:
                    CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _studyColorScheme.onPrimary,
                    ),
                  )
                      : Text('초대 보내기'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// 컬렉션 안의 문서들을 나누어 삭제
  Future<void> _deleteCollection(
      Query<Map<String, dynamic>> query,
      ) async {
    while (true) {
      final snapshot =
      await query.limit(200).get();

      if (snapshot.docs.isEmpty) {
        break;
      }

      final batch =
      FirebaseFirestore.instance.batch();

      for (final document in snapshot.docs) {
        batch.delete(
          document.reference,
        );
      }

      await batch.commit();

      if (snapshot.docs.length < 200) {
        break;
      }
    }
  }

  /// 스터디와 관련된 데이터 삭제
  Future<void> _deleteStudyData() async {
    final firestore =
        FirebaseFirestore.instance;

    final groupDocument =
    firestore
        .collection('studyGroups')
        .doc(studyId);

    // 문제별 답안 삭제
    final quizSnapshot =
    await groupDocument
        .collection('quizzes')
        .get();

    for (final quizDocument
    in quizSnapshot.docs) {
      await _deleteCollection(
        quizDocument.reference
            .collection('answers'),
      );
    }

    // 문제 삭제
    await _deleteCollection(
      groupDocument.collection('quizzes'),
    );

    // 그룹원 삭제
    await _deleteCollection(
      groupDocument.collection('members'),
    );

    // 채팅 메시지 삭제
    final chatDocument =
    firestore
        .collection('chats')
        .doc(studyId);

    await _deleteCollection(
      chatDocument.collection('messages'),
    );

    final chatSnapshot =
    await chatDocument.get();

    if (chatSnapshot.exists) {
      await chatDocument.delete();
    }

    // 해당 스터디의 초대 삭제
    await _deleteCollection(
      firestore
          .collection('studyGroupInvites')
          .where(
        'groupId',
        isEqualTo: studyId,
      ),
    );

    // 마지막으로 스터디 문서 삭제
    await groupDocument.delete();
  }

  /// 스터디 삭제 확인창
  void _showDeleteStudyDialog(
      BuildContext context,
      String groupName,
      ) {
    bool isDeleting = false;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (
              context,
              setDialogState,
              ) {
            Future<void> deleteStudy() async {
              setDialogState(() {
                isDeleting = true;
              });

              try {
                await _deleteStudyData();

                if (!dialogContext.mounted) {
                  return;
                }

                Navigator.pop(
                  dialogContext,
                );

                if (!context.mounted) {
                  return;
                }

                Navigator.pop(
                  context,
                );
              } catch (error) {
                debugPrint(
                  '스터디 삭제 오류: $error',
                );

                if (!dialogContext.mounted) {
                  return;
                }

                setDialogState(() {
                  isDeleting = false;
                });

                _showMessage(
                  context,
                  '스터디를 삭제하지 못했습니다.',
                );
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius:
                BorderRadius.circular(22),
              ),
              title: Row(
                children: [
                  Icon(
                    Icons.delete_outline,
                    color: _studyColorScheme.error,
                  ),
                  SizedBox(width: 10),
                  Text('스터디 삭제'),
                ],
              ),
              content: Text(
                '"$groupName" 스터디를 정말 삭제하시겠습니까?\n\n'
                    '그룹원, 채팅, 문제, 초대 정보도 함께 삭제되며 '
                    '삭제한 후에는 복구할 수 없습니다.',
                style: TextStyle(
                  height: 1.5,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isDeleting
                      ? null
                      : () {
                    Navigator.pop(
                      dialogContext,
                    );
                  },
                  child: Text('취소'),
                ),
                ElevatedButton(
                  onPressed: isDeleting
                      ? null
                      : deleteStudy,
                  style:
                  ElevatedButton.styleFrom(
                    backgroundColor: _studyColorScheme.error,
                    foregroundColor: _studyColorScheme.onPrimary,
                  ),
                  child: isDeleting
                      ? SizedBox(
                    width: 18,
                    height: 18,
                    child:
                    CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _studyColorScheme.onPrimary,
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

  /// 그룹원 신고 저장
  Future<void> _saveMemberReport({
    required String reportedUid,
    required String reportedNickname,
    required String reasonType,
    required String detail,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      throw Exception('로그인 정보가 없습니다.');
    }

    if (currentUser.uid == reportedUid) {
      throw Exception('본인은 신고할 수 없습니다.');
    }

    Map<String, String> reporterProfile =
    await _getUserProfile(currentUser.uid);

    String reporterNickname =
        reporterProfile['nickname'] ?? '';

    if (reporterNickname.isEmpty) {
      reporterNickname = '사용자';
    }

    String reportId =
        'STUDY_MEMBER_${studyId}_${currentUser.uid}_$reportedUid';
    DocumentReference<Map<String, dynamic>> reportReference =
        FirebaseFirestore.instance.collection('reports').doc(reportId);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      DocumentSnapshot<Map<String, dynamic>> reportSnapshot =
          await transaction.get(reportReference);

      if (reportSnapshot.exists) {
        throw Exception('이미 신고한 스터디원입니다.');
      }

      transaction.set(reportReference, {
        'reporterNicname': reporterNickname,
        'reporterUid': currentUser.uid,
        'targetType': 'STUDY_MEMBER',
        'targetId': null,
        'targettitle': reportedNickname,
        'targetNickname': reportedNickname,
        'targetUid': reportedUid,
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

  /// 그룹원 신고 창
  Future<void> _showReportDialog(
      BuildContext context,
      String groupName,
      ) async {
    const Map<String, String> reasons = {
      'SPAM': '스팸',
      'ABUSE': '욕설 또는 괴롭힘',
      'INAPPROPRIATE': '부적절한 콘텐츠',
      'FRAUD': '사기 또는 허위 정보',
      'ETC': '기타',
    };
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      _showMessage(
        context,
        '로그인 정보가 없습니다.',
      );
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
      debugPrint('신고할 그룹원 조회 오류: $error');

      if (context.mounted) {
        _showMessage(
          context,
          '그룹원 목록을 불러오지 못했습니다.',
        );
      }
      return;
    }

    List<QueryDocumentSnapshot<Map<String, dynamic>>>
    memberList = [];

    for (int i = 0; i < memberSnapshot.docs.length; i++) {
      QueryDocumentSnapshot<Map<String, dynamic>> memberDocument =
      memberSnapshot.docs[i];

      Map<String, dynamic> memberData = memberDocument.data();

      String status =
          memberData['status']?.toString() ?? '';

      if (status == 'ACTIVE' &&
          memberDocument.id != currentUser.uid) {
        memberList.add(memberDocument);
      }
    }

    if (memberList.isEmpty) {
      if (context.mounted) {
        _showMessage(
          context,
          '신고할 수 있는 그룹원이 없습니다.',
        );
      }
      return;
    }

    String selectedMemberUid = memberList[0].id;
    String selectedReason = 'SPAM';

    TextEditingController detailController =
    TextEditingController();

    bool isSaving = false;

    if (!context.mounted) {
      detailController.dispose();
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              alignment: Alignment.bottomCenter,
              insetPadding: EdgeInsets.zero,
              backgroundColor: AppColors.light.surface,
              surfaceTintColor: Colors.transparent,
              shadowColor: Colors.transparent,
              elevation: 0,
              titlePadding: EdgeInsets.fromLTRB(22, 14, 22, 0),
              contentPadding: EdgeInsets.fromLTRB(22, 20, 22, 0),
              actionsPadding: EdgeInsets.fromLTRB(22, 12, 22, 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(26),
                ),
              ),
              title: Column(
                children: [
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.light.textSecondary.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.light.incorrectSoft,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.report_outlined,
                          color: AppColors.light.incorrect,
                        ),
                      ),
                      SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '그룹원 신고',
                            style: TextStyle(
                              color: AppColors.light.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            '신고 사유를 선택해 주세요.',
                            style: TextStyle(
                              color: AppColors.light.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedMemberUid,
                      style: TextStyle(
                        color: AppColors.light.textPrimary,
                      ),
                      decoration: InputDecoration(
                        labelText: '신고할 그룹원',
                        labelStyle: TextStyle(
                          color: AppColors.light.textSecondary,
                        ),
                        filled: true,
                        fillColor: AppColors.light.pinkSoft.withOpacity(0.3),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: memberList.map((memberDocument) {
                        Map<String, dynamic> memberData =
                        memberDocument.data();

                        String nickname =
                            memberData['nickname']?.toString() ??
                                '스터디원';

                        return DropdownMenuItem<String>(
                          value: memberDocument.id,
                          child: Text(nickname),
                        );
                      }).toList(),
                      onChanged: isSaving
                          ? null
                          : (value) {
                        if (value == null) {
                          return;
                        }

                        setDialogState(() {
                          selectedMemberUid = value;
                        });
                      },
                    ),

                    SizedBox(height: 16),

                    ...reasons.entries.map((entry) {
                      bool isSelected =
                          selectedReason == entry.key;

                      return Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: isSaving
                              ? null
                              : () {
                            setDialogState(() {
                              selectedReason = entry.key;
                            });
                          },
                          child: AnimatedContainer(
                            duration: Duration(milliseconds: 160),
                            padding: EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.light.incorrectSoft
                                  : AppColors.light.pinkSoft
                                  .withOpacity(0.35),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.light.incorrect
                                    : Colors.transparent,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_off,
                                  color: isSelected
                                      ? AppColors.light.incorrect
                                      : AppColors.light.textSecondary,
                                  size: 20,
                                ),
                                SizedBox(width: 10),
                                Text(
                                  entry.value,
                                  style: TextStyle(
                                    color: AppColors.light.textPrimary,
                                    fontSize: 14,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),

                    SizedBox(height: 16),

                        TextField(
                          controller: detailController,
                          enabled: !isSaving,
                          maxLines: 4,
                          maxLength: 500,
                          style: TextStyle(
                            color: AppColors.light.textPrimary,
                          ),
                          decoration: InputDecoration(
                            labelText: '상세 내용',
                            hintText: '신고 내용을 입력해주세요. (선택)',
                            labelStyle: TextStyle(
                              color: AppColors.light.textSecondary,
                            ),
                            hintStyle: TextStyle(
                              color: AppColors.light.textSecondary,
                            ),
                            counterStyle: TextStyle(
                              color: AppColors.light.textSecondary,
                            ),
                            alignLabelWithHint: true,
                            filled: true,
                            fillColor: AppColors.light.pinkSoft
                                .withOpacity(0.3),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: AppColors.light.incorrect,
                              ),
                            ),
                          ),
                    ),
                  ],
                ),
              ),
              actions: [
                SizedBox(
                  width: MediaQuery.of(context).size.width,
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: isSaving
                        ? null
                        : () async {
                    String detail =
                        detailController.text.trim();

                    String reportedNickname = '스터디원';

                    for (int i = 0;
                    i < memberList.length;
                    i++) {
                      if (memberList[i].id ==
                          selectedMemberUid) {
                        Map<String, dynamic> memberData =
                        memberList[i].data();

                        reportedNickname =
                            memberData['nickname']
                                ?.toString() ??
                                '스터디원';
                        break;
                      }
                    }

                    setDialogState(() {
                      isSaving = true;
                    });

                    try {
                      await _saveMemberReport(
                        reportedUid: selectedMemberUid,
                        reportedNickname:
                        reportedNickname,
                        reasonType: selectedReason,
                        detail: detail,
                      );

                      if (!dialogContext.mounted) {
                        return;
                      }

                      Navigator.pop(dialogContext);

                      if (context.mounted) {
                        _showMessage(
                          context,
                          '신고가 접수되었습니다.',
                        );
                      }
                    } catch (error) {
                      debugPrint('그룹원 신고 오류: $error');

                      if (!dialogContext.mounted) {
                        return;
                      }

                      setDialogState(() {
                        isSaving = false;
                      });

                      _showMessage(
                        context,
                        error.toString().replaceFirst(
                          'Exception: ',
                          '',
                        ),
                      );
                    }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.light.incorrect,
                      foregroundColor: AppColors.light.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: isSaving
                        ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.light.surface,
                      ),
                    )
                        : Icon(Icons.report_outlined),
                    label: Text(
                      '신고 접수하기',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

  }

  /// 스터디 나가기 처리
  Future<void> _leaveStudy() async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      throw Exception('로그인 정보가 없습니다.');
    }

    final groupDocument = FirebaseFirestore.instance
        .collection('studyGroups')
        .doc(studyId);

    final memberDocument = groupDocument
        .collection('members')
        .doc(currentUser.uid);

    await FirebaseFirestore.instance.runTransaction(
          (transaction) async {
        final groupSnapshot = await transaction.get(
          groupDocument,
        );

        final memberSnapshot = await transaction.get(
          memberDocument,
        );

        if (!groupSnapshot.exists) {
          throw Exception('스터디 정보를 찾을 수 없습니다.');
        }

        if (!memberSnapshot.exists) {
          throw Exception('참여 중인 스터디가 아닙니다.');
        }

        final groupData = groupSnapshot.data() ?? {};
        final memberData = memberSnapshot.data() ?? {};

        final ownerUid =
            groupData['ownerUid']?.toString() ?? '';

        final memberStatus =
            memberData['status']?.toString() ?? '';

        if (currentUser.uid == ownerUid) {
          throw Exception('방장은 스터디에서 나갈 수 없습니다.');
        }

        if (memberStatus != 'ACTIVE') {
          throw Exception('이미 참여 중인 스터디가 아닙니다.');
        }

        final currentMemberCount = _getInt(
          groupData,
          'currentMemberCount',
        );

        int newMemberCount = currentMemberCount - 1;

        if (newMemberCount < 1) {
          newMemberCount = 1;
        }

        final currentStatus =
            groupData['status']?.toString() ?? 'RECRUITING';

        String nextStatus = 'RECRUITING';

        if (currentStatus == 'COMPLETED') {
          nextStatus = 'COMPLETED';
        }

        transaction.update(
          memberDocument,
          {
            'status': 'LEFT',
            'leftAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );

        transaction.update(
          groupDocument,
          {
            'currentMemberCount': newMemberCount,
            'status': nextStatus,
            'recruitmentStatus':
            nextStatus == 'COMPLETED'
                ? 'CLOSED'
                : 'OPEN',
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );
      },
    );
  }

  /// 스터디 나가기 확인창
  void _showLeaveDialog(
      BuildContext context,
      ) {
    bool isLeaving = false;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (
              context,
              setDialogState,
              ) {
            return AlertDialog(
              title: Text('스터디방 나가기'),
              content: Text(
                '이 스터디에서 나가시겠습니까?\n\n'
                    '나간 뒤에는 다시 참여해야 스터디 활동을 이용할 수 있습니다.',
                style: TextStyle(
                  height: 1.5,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isLeaving
                      ? null
                      : () {
                    Navigator.pop(
                      dialogContext,
                    );
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
                      await _leaveStudy();

                      if (!dialogContext.mounted) {
                        return;
                      }

                      Navigator.pop(
                        dialogContext,
                      );

                      if (!context.mounted) {
                        return;
                      }

                      _showMessage(
                        context,
                        '스터디에서 나갔습니다.',
                      );

                      Navigator.pop(
                        context,
                        true,
                      );
                    } catch (error) {
                      debugPrint(
                        '스터디 나가기 오류: $error',
                      );

                      if (!dialogContext.mounted) {
                        return;
                      }

                      setDialogState(() {
                        isLeaving = false;
                      });

                      _showMessage(
                        context,
                        error.toString().replaceFirst(
                          'Exception: ',
                          '',
                        ),
                      );
                    }
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: _studyColorScheme.error,
                  ),
                  child: isLeaving
                      ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
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

  /// 작은 표시
  Widget _buildBadge(
      String text,
      Color backgroundColor,
      Color textColor,
      ) {
    return Container(
      padding:
      EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius:
        BorderRadius.circular(15),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// 상세 정보 한 줄
  Widget _buildInfoRow(
      IconData icon,
      String title,
      String value,
      ) {
    return Padding(
      padding:
      EdgeInsets.only(
        bottom: 14,
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: _studyColorScheme.secondaryContainer,
          ),

          SizedBox(width: 10),

          SizedBox(
            width: 78,
            child: Text(
              title,
              style: TextStyle(
                color: _studyColors.textSecondary,
              ),
            ),
          ),

          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight:
                FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 메뉴 카드
  Widget _buildMenuButton({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AppCard(
        backgroundColor: _studyColorScheme.surface,
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration:
              BoxDecoration(
                color: _studyColors.lavender,
                borderRadius:
                BorderRadius.circular(
                  14,
                ),
              ),
              child: Icon(
                icon,
                color: _studyColors.pinkStart,
              ),
            ),

            SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style:
                    TextStyle(
                      fontSize: 15,
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),

                  SizedBox(height: 4),

                  Text(
                    description,
                    style:
                    TextStyle(
                      fontSize: 12,
                      color: _studyColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            Icon(
              Icons.chevron_right,
              color: _studyColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  bool _isNetworkError(Object? error) {
    if (error is FirebaseException) {
      if (error.code == 'unavailable') {
        return true;
      }

      if (error.code == 'network-request-failed') {
        return true;
      }
    }

    return false;
  }

  void _retryDetailPage(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) {
          return StudyDetailPage(
            studyId: studyId,
            studyData: studyData,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('studyGroups')
          .doc(studyId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            snapshot.hasData == false) {
          return Scaffold(
            appBar: AppTopBar(
              title: '스터디 상세',
            ),
            body: AppLoadingView(
              message: '스터디 정보를 불러오는 중입니다.',
            ),
          );
        }

        if (snapshot.hasError) {
          debugPrint(
            '스터디 상세 조회 오류: ${snapshot.error}',
          );

          if (_isNetworkError(snapshot.error)) {
            return Scaffold(
              appBar: AppTopBar(
                title: '스터디 상세',
              ),
              body: AppNetworkErrorView(
                message: '인터넷 연결을 확인해 주세요.',
                description:
                'Wi-Fi 또는 모바일 데이터를 확인한 뒤 다시 시도해 주세요.',
                retryButtonText: '다시 시도',
                onRetryPressed: () {
                  _retryDetailPage(context);
                },
              ),
            );
          }

          return Scaffold(
            appBar: AppTopBar(
              title: '스터디 상세',
            ),
            body: AppErrorView(
              message: '스터디 정보를 불러오지 못했습니다.',
              description: '잠시 후 다시 시도해 주세요.',
              retryButtonText: '다시 시도',
              onRetryPressed: () {
                _retryDetailPage(context);
              },
            ),
          );
        }

        if (snapshot.data == null ||
            snapshot.data!.exists == false) {
          return Scaffold(
            appBar: AppTopBar(
              title: '스터디 상세',
            ),
            body: AppErrorView(
              message: '존재하지 않는 스터디입니다.',
              description: '삭제되었거나 더 이상 이용할 수 없는 스터디입니다.',
            ),
          );
        }

        Map<String, dynamic> currentStudyData =
            snapshot.data!.data() ?? studyData;

        String groupName =
            currentStudyData['groupName']?.toString() ?? '그룹명 없음';

        String description =
            currentStudyData['description']?.toString() ?? '';

        String certificateName =
            currentStudyData['certificateName']?.toString() ?? '공통 스터디';

        String ownerNickname =
            currentStudyData['ownerNickname']?.toString() ?? '방장 정보 없음';

        int currentMemberCount = _getInt(
          currentStudyData,
          'currentMemberCount',
        );

        int maxMemberCount = _getInt(
          currentStudyData,
          'maxMemberCount',
        );

        bool isPublic = true;

        if (currentStudyData['isPublic'] is bool) {
          isPublic = currentStudyData['isPublic'];
        }

        bool joinApprovalRequired = true;

        if (currentStudyData['joinApprovalRequired'] is bool) {
          joinApprovalRequired =
          currentStudyData['joinApprovalRequired'];
        }

        bool isOwner = _isOwner(currentStudyData);
        bool isRecruiting = _isRecruiting(currentStudyData);
        User? currentUser = FirebaseAuth.instance.currentUser;

        if (isOwner) {
          _scheduleOwnerProfileSync(
            currentStudyData,
          );
        }

        return Scaffold(
          appBar: AppTopBar(
            title: '스터디 상세',
            actions: [
              if (isOwner)
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'recruitment') {
                      _updateRecruitmentStatus(
                        context,
                        currentStudyData,
                        isRecruiting == false,
                      );
                    }

                    if (value == 'invite') {
                      _showInviteDialog(
                        context,
                        groupName,
                      );
                    }

                    if (value == 'member') {
                      _openMemberManagement(
                        context,
                        currentStudyData,
                      );
                    }

                    if (value == 'goal') {
                      _showStudyGoalDialog(
                        context,
                        currentStudyData,
                      );
                    }

                    if (value == 'edit') {
                      _openEditPage(
                        context,
                        currentStudyData,
                      );
                    }

                    if (value == 'delete') {
                      _showDeleteStudyDialog(
                        context,
                        groupName,
                      );
                    }
                  },
                  itemBuilder: (context) {
                    return [
                      PopupMenuItem(
                        value: 'recruitment',
                        child: Row(
                          children: [
                            Icon(
                              isRecruiting
                                  ? Icons.lock_outline_rounded
                                  : Icons.lock_open_rounded,
                              size: 20,
                            ),
                            SizedBox(width: 10),
                            Text(
                              isRecruiting
                                  ? '모집 마감'
                                  : '모집 재개',
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'invite',
                        child: Row(
                          children: [
                            Icon(
                              Icons.person_add_alt_outlined,
                              size: 20,
                            ),
                            SizedBox(width: 10),
                            Text('그룹원 초대'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'member',
                        child: Row(
                          children: [
                            Icon(
                              Icons.manage_accounts_outlined,
                              size: 20,
                            ),
                            SizedBox(width: 10),
                            Text('그룹원 관리'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'goal',
                        child: Row(
                          children: [
                            Icon(
                              Icons.event_available_outlined,
                              size: 20,
                            ),
                            SizedBox(width: 10),
                            Text('시험일·주간 목표 설정'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(
                              Icons.edit_outlined,
                              size: 20,
                            ),
                            SizedBox(width: 10),
                            Text('스터디 수정'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline,
                              size: 20,
                              color: _studyColorScheme.error,
                            ),
                            SizedBox(width: 10),
                            Text(
                              '스터디 삭제',
                              style: TextStyle(
                                color: _studyColorScheme.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ];
                  },
                ),
              if (isOwner == false && currentUser != null)
                StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('studyGroups')
                      .doc(studyId)
                      .collection('members')
                      .doc(currentUser.uid)
                      .snapshots(),
                  builder: (context, memberSnapshot) {
                    String memberStatus = '';

                    if (memberSnapshot.data != null &&
                        memberSnapshot.data!.exists) {
                      Map<String, dynamic> memberData =
                          memberSnapshot.data!.data() ?? {};

                      memberStatus =
                          memberData['status']?.toString() ?? '';
                    }

                    if (memberStatus != 'ACTIVE') {
                      return SizedBox();
                    }

                    return PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'report') {
                          _showReportDialog(
                            context,
                            groupName,
                          );
                        }

                        if (value == 'leave') {
                          _showLeaveDialog(context);
                        }
                      },
                      itemBuilder: (context) {
                        return [
                          PopupMenuItem(
                            value: 'report',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.report_outlined,
                                  size: 20,
                                ),
                                SizedBox(width: 10),
                                Text('그룹원 신고'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'leave',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.logout,
                                  size: 20,
                                  color: _studyColorScheme.error,
                                ),
                                SizedBox(width: 10),
                                Text(
                                  '스터디방 나가기',
                                  style: TextStyle(
                                    color: _studyColorScheme.error,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ];
                      },
                    );
                  },
                ),
            ],
          ),
          body: AppMainBackground(
            applySafeArea: false,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                16,
                14,
                16,
                MediaQuery.of(context).padding.bottom + 30,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppCard(
                    backgroundColor: _studyColorScheme.surface,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 7,
                          runSpacing: 7,
                          children: [
                            _buildBadge(
                              certificateName,
                              _studyColors.lavender,
                              _studyColors.pinkStart,
                            ),
                            _buildBadge(
                              isPublic ? '공개' : '비공개',
                              _studyColorScheme.outlineVariant,
                              _studyColors.textSecondary,
                            ),
                            _buildBadge(
                              isRecruiting ? '모집 중' : '모집 마감',
                              isRecruiting
                                  ? _studyColors.mint
                                  : _studyColorScheme.outlineVariant,
                              isRecruiting
                                  ? _studyColorScheme.tertiary
                                  : _studyColors.textSecondary,
                            ),
                            if (isOwner)
                              _buildBadge(
                                '방장',
                                _studyColors.pinkSoft,
                                _studyColors.pinkStart,
                              ),
                          ],
                        ),
                        SizedBox(height: 15),
                        Text(
                          groupName,
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          description.isEmpty
                              ? '등록된 스터디 소개가 없습니다.'
                              : description,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: _studyColors.textSecondary,
                          ),
                        ),
                        SizedBox(height: 20),
                        _buildInfoRow(
                          Icons.person_outline,
                          '방장',
                          ownerNickname,
                        ),
                        _buildInfoRow(
                          Icons.groups_outlined,
                          '참여 인원',
                          '$currentMemberCount / $maxMemberCount명',
                        ),
                        _buildInfoRow(
                          Icons.fact_check_outlined,
                          '참여 방식',
                          joinApprovalRequired
                              ? '방장 승인 후 참여'
                              : '바로 참여 가능',
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12),
                  _buildStudyGoalCard(
                    context,
                    currentStudyData,
                    isOwner,
                  ),
                  SizedBox(height: 12),
                  _buildJoinArea(
                    context,
                    currentStudyData,
                  ),
                  SizedBox(height: 12),
                  _buildStudyRoomArea(
                    context,
                    currentStudyData,
                  ),
                  if (isOwner) SizedBox(height: 12),
                  if (isOwner)
                    _buildJoinRequestArea(
                      context,
                      currentStudyData,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
