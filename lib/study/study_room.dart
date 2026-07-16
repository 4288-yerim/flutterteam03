import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../theme.dart';
import 'package:flutterteam03/widgets/app_state_views.dart';

import '../widgets/app_main_background.dart';
import '../widgets/app_card.dart';
import '../widgets/app_button.dart';
import '../widgets/app_top_bar.dart';
import 'study_chat.dart';
import 'study_quiz.dart';
import 'study_record.dart';
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

class StudyRoomPage extends StatelessWidget {
  final String studyId;
  final String groupName;

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
          return StudyRoomPage(
            studyId: studyId,
            groupName: groupName,
          );
        },
      ),
    );
  }

  int _getInt(
      Map<String, dynamic> data,
      String fieldName,
      ) {
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
    String recruitmentStatus =
        data['recruitmentStatus']?.toString() ?? '';

    String groupStatus = data['status']?.toString() ?? '';

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

    if (recruitmentStatus.isEmpty && groupStatus == 'CLOSED') {
      return false;
    }

    if (maxMemberCount > 0 &&
        currentMemberCount >= maxMemberCount) {
      return false;
    }

    return true;
  }

  Future<void> _updateRecruitmentStatus(
      BuildContext context,
      Map<String, dynamic> groupData,
      bool openRecruitment,
      ) async {
    int currentMemberCount = _getInt(
      groupData,
      'currentMemberCount',
    );

    int maxMemberCount = _getInt(
      groupData,
      'maxMemberCount',
    );

    if (openRecruitment &&
        maxMemberCount > 0 &&
        currentMemberCount >= maxMemberCount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('정원이 가득 차서 모집을 다시 열 수 없습니다.'),
        ),
      );
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
    } catch (error) {
      debugPrint('모집 상태 변경 오류: $error');

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('모집 상태를 변경하지 못했습니다.'),
        ),
      );
    }
  }

  Widget _buildRoomBadge(
      String text,
      Color backgroundColor,
      Color textColor,
      ) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
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
            color: _studyColors.textPrimary,
          ),
        ),
        SizedBox(height: 3),
        Text(
          description,
          style: TextStyle(
            fontSize: 11,
            color: _studyColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildRoomMetric(
      IconData icon,
      String label,
      String value,
      ) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: _studyColorScheme.surface.withOpacity(0.82),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: _studyColors.pinkStart,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      color: _studyColors.textSecondary,
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
                      color: _studyColors.pinkStart,
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

  Widget _buildStudyGoalCard(
      BuildContext context,
      Map<String, dynamic> groupData,
      ) {
    DateTime? examDate =
    _getDateTime(groupData['examDate']);

    int weeklyGoalMinutes = _getInt(
      groupData,
      'weeklyGoalMinutes',
    );

    DateTime now = DateTime.now();

    DateTime today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    DateTime weekStart = today.subtract(
      Duration(days: today.weekday - 1),
    );

    DateTime nextWeekStart = weekStart.add(
      Duration(days: 7),
    );

    Stream<QuerySnapshot<Map<String, dynamic>>> recordStream =
    FirebaseFirestore.instance
        .collection('studyGroups')
        .doc(studyId)
        .collection('studyRecords')
        .where(
      'endedAt',
      isGreaterThanOrEqualTo:
      Timestamp.fromDate(weekStart),
    )
        .where(
      'endedAt',
      isLessThan:
      Timestamp.fromDate(nextWeekStart),
    )
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: recordStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return SizedBox(
            height: 190,
            child: AppLoadingView(
              message: '주간 목표를 불러오는 중입니다.',
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
                '네트워크 연결 후 주간 목표를 다시 불러와 주세요.',
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
          for (int i = 0;
          i < snapshot.data!.docs.length;
          i++) {
            weeklyStudySeconds +=
                _getRecordStudySeconds(
                  snapshot.data!.docs[i].data(),
                );
          }
        }

        int weeklyGoalSeconds =
            weeklyGoalMinutes * 60;

        double progress = 0;

        if (weeklyGoalSeconds > 0) {
          progress =
              weeklyStudySeconds / weeklyGoalSeconds;

          if (progress > 1) {
            progress = 1;
          }
        }

        int progressPercent =
        (progress * 100).round();

        String ddayText = '시험일 미설정';
        String examDateText =
            '스터디 수정에서 시험일을 등록해 주세요.';

        if (examDate != null) {
          ddayText = _getDdayText(examDate);
          examDateText =
          '${_formatExamDate(examDate)} 시험';
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
          backgroundColor: _studyColorScheme.surface,
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _studyColors.pinkSoft,
                      borderRadius:
                      BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.event_available_rounded,
                      color: _studyColors.pinkStart,
                      size: 24,
                    ),
                  ),

                  SizedBox(width: 13),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Text(
                          ddayText,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight:
                            FontWeight.bold,
                            color:
                            _studyColors.pinkStart,
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

                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _studyColors.lavender,
                      borderRadius:
                      BorderRadius.circular(14),
                    ),
                    child: Text(
                      weeklyGoalMinutes > 0
                          ? '$progressPercent%'
                          : '-',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color:
                        _studyColors.pinkStart,
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
                        color:
                        _studyColors.textPrimary,
                      ),
                    ),
                  ),

                  Text(
                    goalText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color:
                      _studyColors.pinkStart,
                    ),
                  ),
                ],
              ),

              SizedBox(height: 10),

              ClipRRect(
                borderRadius:
                BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  minHeight: 9,
                  value: progress,
                  backgroundColor:
                  _studyColors.pinkSoft,
                  valueColor:
                  AlwaysStoppedAnimation<Color>(
                    _studyColors.pinkStart,
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
                  color:
                  _studyColors.textSecondary,
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
      String nickname,
      String profileImageUrl,
      bool isOwner,
      ) {
    Widget profile;

    if (profileImageUrl.isNotEmpty) {
      profile = CircleAvatar(
        radius: 28,
        backgroundColor: _studyColors.lavender,
        backgroundImage: NetworkImage(profileImageUrl),
      );
    } else {
      profile = CircleAvatar(
        radius: 28,
        backgroundColor: _studyColors.lavender,
        child: Text(
          _getFirstLetter(nickname),
          style: TextStyle(
            color: _studyColors.pinkStart,
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
                color: _studyColors.pinkStart,
                shape: BoxShape.circle,
                border: Border.all(
                  color: _studyColorScheme.onPrimary,
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.star_rounded,
                size: 12,
                color: _studyColorScheme.onPrimary,
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
            child: AppLoadingView(
              message: '그룹원을 불러오는 중입니다.',
            ),
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

              String nickname =
                  memberData['nickname']?.toString() ?? '스터디원';

              String role =
                  memberData['role']?.toString() ?? 'MEMBER';

              String profileImageUrl =
                  memberData['profileImageUrl']?.toString() ?? '';

              bool isOwner = role == 'OWNER';

              return Container(
                width: 72,
                margin: EdgeInsets.only(right: 10),
                child: Column(
                  children: [
                    _buildProfileImage(
                      nickname,
                      profileImageUrl,
                      isOwner,
                    ),
                    SizedBox(height: 7),
                    Text(
                      nickname,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: _studyColors.textSecondary,
                        fontWeight:
                        isOwner ? FontWeight.bold : FontWeight.normal,
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

  Widget _buildTodayStudySummary(
      BuildContext context,
      String displayGroupName,
      ) {
    DateTime now = DateTime.now();
    DateTime todayStart = DateTime(
      now.year,
      now.month,
      now.day,
    );
    DateTime tomorrowStart = todayStart.add(
      Duration(days: 1),
    );

    Stream<QuerySnapshot<Map<String, dynamic>>> memberStream =
    FirebaseFirestore.instance
        .collection('studyGroups')
        .doc(studyId)
        .collection('members')
        .snapshots();

    Stream<QuerySnapshot<Map<String, dynamic>>> recordStream =
    FirebaseFirestore.instance
        .collection('studyGroups')
        .doc(studyId)
        .collection('studyRecords')
        .where(
      'endedAt',
      isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart),
    )
        .where(
      'endedAt',
      isLessThan: Timestamp.fromDate(tomorrowStart),
    )
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: memberStream,
      builder: (context, memberSnapshot) {
        if (memberSnapshot.connectionState ==
            ConnectionState.waiting) {
          return SizedBox(
            height: 180,
            child: AppLoadingView(
              message: '오늘의 학습 현황을 불러오는 중입니다.',
            ),
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

        List<Map<String, dynamic>> studyingMembers = [];

        if (memberSnapshot.data != null) {
          for (int i = 0;
          i < memberSnapshot.data!.docs.length;
          i++) {
            Map<String, dynamic> memberData =
            memberSnapshot.data!.docs[i].data();

            String status =
                memberData['status']?.toString() ?? '';
            String role =
                memberData['role']?.toString() ?? 'MEMBER';
            bool isStudying = memberData['isStudying'] == true;

            bool isActiveMember =
                status == 'ACTIVE' || role == 'OWNER';

            if (isActiveMember && isStudying) {
              studyingMembers.add(memberData);
            }
          }
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: recordStream,
          builder: (context, recordSnapshot) {
            if (recordSnapshot.connectionState ==
                ConnectionState.waiting) {
              return SizedBox(
                height: 180,
                child: AppLoadingView(
                  message: '오늘의 공부 기록을 불러오는 중입니다.',
                ),
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

            int todayStudySeconds = 0;
            Set<String> todayMemberUidSet = {};

            if (recordSnapshot.data != null) {
              for (int i = 0;
              i < recordSnapshot.data!.docs.length;
              i++) {
                Map<String, dynamic> recordData =
                recordSnapshot.data!.docs[i].data();

                int recordStudySeconds =
                _getRecordStudySeconds(recordData);

                todayStudySeconds += recordStudySeconds;

                String uid = recordData['uid']?.toString() ?? '';

                if (uid.isNotEmpty) {
                  todayMemberUidSet.add(uid);
                }
              }
            }

            for (int i = 0; i < studyingMembers.length; i++) {
              String uid =
                  studyingMembers[i]['uid']?.toString() ?? '';

              if (uid.isNotEmpty) {
                todayMemberUidSet.add(uid);
              }
            }

            String studyingText = '지금 공부 중인 멤버가 없습니다.';

            if (studyingMembers.isNotEmpty) {
              List<String> nicknameList = [];

              for (int i = 0; i < studyingMembers.length; i++) {
                String nickname =
                    studyingMembers[i]['nickname']?.toString() ??
                        '스터디원';
                nicknameList.add(nickname);
              }

              if (nicknameList.length == 1) {
                studyingText = '${nicknameList[0]}님이 공부 중입니다.';
              } else if (nicknameList.length == 2) {
                studyingText =
                '${nicknameList[0]}님, ${nicknameList[1]}님이 공부 중입니다.';
              } else {
                int otherCount = nicknameList.length - 2;
                studyingText =
                '${nicknameList[0]}님, ${nicknameList[1]}님 외 $otherCount명이 공부 중입니다.';
              }
            }

            return AppCard(
              borderRadius: 22,
              padding: EdgeInsets.all(16),
              backgroundColor: _studyColors.lavender,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 39,
                        height: 39,
                        decoration: BoxDecoration(
                          color: _studyColors.lavender,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(
                          Icons.insights_rounded,
                          size: 20,
                          color: _studyColors.pinkStart,
                        ),
                      ),
                      SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '오늘 스터디 현황',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: _studyColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              '오늘 그룹원들의 공부 기록을 확인해요.',
                              style: TextStyle(
                                fontSize: 10,
                                color: _studyColors.textSecondary,
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
                        Icons.schedule_rounded,
                        '오늘 공부시간',
                        _formatStudyTime(todayStudySeconds),
                      ),
                      SizedBox(width: 8),
                      _buildRoomMetric(
                        Icons.person_outline_rounded,
                        '공부한 멤버',
                        '${todayMemberUidSet.length}명',
                      ),
                      SizedBox(width: 8),
                      _buildRoomMetric(
                        Icons.bolt_rounded,
                        '지금 공부 중',
                        '${studyingMembers.length}명',
                      ),
                    ],
                  ),
                  SizedBox(height: 13),
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
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
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: studyingMembers.isNotEmpty
                            ? _studyColors.mint
                            : _studyColorScheme.surface,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: studyingMembers.isNotEmpty
                                  ? _studyColorScheme.tertiary
                                  : _studyColorScheme.secondaryContainer,
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              studyingText,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                height: 1.4,
                                color: studyingMembers.isNotEmpty
                                    ? _studyColorScheme.tertiary
                                    : _studyColors.textSecondary,
                                fontWeight: studyingMembers.isNotEmpty
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 19,
                            color: _studyColors.textSecondary,
                          ),
                        ],
                      ),
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
          .orderBy(
        'createdAt',
        descending: true,
      )
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

            String senderUid =
                messageData['senderUid']?.toString() ?? '';

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

              String message =
                  messageData['message']?.toString() ?? '';

              if (isDeleted) {
                lastMessage = '삭제된 메시지입니다.';
              } else if (senderUid == currentUserUid) {
                lastMessage = '나: $message';
              } else {
                lastMessage = '$senderNickname: $message';
              }

              lastMessageTime = _formatChatTime(
                messageData['createdAt'],
              );

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
            backgroundColor: _studyColorScheme.surface,
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: _studyColors.softBlue,
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Icon(
                    Icons.forum_rounded,
                    color: _studyColorScheme.secondaryContainer,
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
                                color: _studyColors.textPrimary,
                              ),
                            ),
                          ),
                          Visibility(
                            visible: lastMessageTime.isNotEmpty,
                            child: Text(
                              lastMessageTime,
                              style: TextStyle(
                                fontSize: 11,
                                color: _studyColors.textSecondary,
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
                                color: _studyColors.textSecondary,
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
                                color: _studyColors.pinkStart,
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: Text(
                                unreadCount > 99 ? '99+' : '$unreadCount',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: _studyColorScheme.onPrimary,
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
                  color: _studyColors.textSecondary,
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
        backgroundColor: _studyColorScheme.surface,
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _studyColors.mint,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.bar_chart_rounded,
                color: _studyColorScheme.tertiary,
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
                      color: _studyColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    '오늘·이번 주·이번 달 기록 보기',
                    style: TextStyle(
                      fontSize: 11,
                      color: _studyColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: _studyColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityButton(
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
            backgroundColor: _studyColorScheme.surface,
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
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 22,
                  ),
                ),
                Spacer(),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _studyColors.textPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: _studyColors.textSecondary,
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

  void _openMemberList(BuildContext context) {
    showModalBottomSheet(
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
                    Icon(
                      Icons.groups_outlined,
                      color: _studyColors.pinkStart,
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
                      for (int i = 0;
                      i < snapshot.data!.docs.length;
                      i++) {
                        QueryDocumentSnapshot<Map<String, dynamic>>
                        memberDocument = snapshot.data!.docs[i];

                        Map<String, dynamic> memberData =
                        memberDocument.data();

                        String status =
                            memberData['status']?.toString() ?? '';

                        String role =
                            memberData['role']?.toString() ?? 'MEMBER';

                        if (status == 'ACTIVE' || role == 'OWNER') {
                          memberList.add(memberDocument);
                        }
                      }
                    }

                    memberList.sort((a, b) {
                      String aRole =
                          a.data()['role']?.toString() ?? 'MEMBER';
                      String bRole =
                          b.data()['role']?.toString() ?? 'MEMBER';

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

                    return ListView.builder(
                      padding: EdgeInsets.fromLTRB(18, 16, 18, 30),
                      itemCount: memberList.length,
                      itemBuilder: (context, index) {
                        Map<String, dynamic> memberData =
                        memberList[index].data();

                        String nickname =
                            memberData['nickname']?.toString() ??
                                '스터디원';

                        String role =
                            memberData['role']?.toString() ?? 'MEMBER';

                        String profileImageUrl =
                            memberData['profileImageUrl']?.toString() ?? '';

                        int totalStudySeconds =
                        _getTotalStudySeconds(memberData);

                        bool isOwner = role == 'OWNER';

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
                              _buildProfileImage(
                                nickname,
                                profileImageUrl,
                                isOwner,
                              ),
                              SizedBox(width: 13),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          nickname,
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
                                          '${_formatStudyTime(totalStudySeconds)}',
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

  void _openStudyRanking(BuildContext context) {
    showModalBottomSheet(
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
                    Icon(
                      Icons.emoji_events_outlined,
                      color: _studyColors.pinkStart,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '공부시간 순위',
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
                        message: '공부시간 순위를 불러오는 중입니다.',
                      );
                    }

                    if (snapshot.hasError) {
                      if (_isNetworkError(snapshot.error)) {
                        return AppNetworkErrorView(
                          message: '인터넷 연결을 확인해 주세요.',
                          description: '네트워크 연결 후 공부시간 순위를 다시 불러와 주세요.',
                          onRetryPressed: () {
                            Navigator.pop(bottomSheetContext);
                            _openStudyRanking(context);
                          },
                        );
                      }

                      return AppErrorView(
                        message: '공부시간 순위를 불러오지 못했습니다.',
                        description: '잠시 후 다시 시도해 주세요.',
                        onRetryPressed: () {
                          Navigator.pop(bottomSheetContext);
                          _openStudyRanking(context);
                        },
                      );
                    }

                    List<QueryDocumentSnapshot<Map<String, dynamic>>>
                    memberList = [];

                    if (snapshot.data != null) {
                      for (int i = 0;
                      i < snapshot.data!.docs.length;
                      i++) {
                        QueryDocumentSnapshot<Map<String, dynamic>>
                        memberDocument = snapshot.data!.docs[i];

                        Map<String, dynamic> memberData =
                        memberDocument.data();

                        String status =
                            memberData['status']?.toString() ?? '';

                        String role =
                            memberData['role']?.toString() ?? 'MEMBER';

                        if (status == 'ACTIVE' || role == 'OWNER') {
                          memberList.add(memberDocument);
                        }
                      }
                    }

                    memberList.sort((a, b) {
                      int aSeconds =
                      _getTotalStudySeconds(a.data());

                      int bSeconds =
                      _getTotalStudySeconds(b.data());

                      return bSeconds.compareTo(aSeconds);
                    });

                    if (memberList.isEmpty) {
                      return AppEmptyView(
                        message: '아직 공부시간 기록이 없습니다.',
                        description: '공부시간을 기록하면 순위가 이곳에 표시됩니다.',
                      );
                    }

                    return ListView.builder(
                      padding: EdgeInsets.fromLTRB(18, 16, 18, 30),
                      itemCount: memberList.length,
                      itemBuilder: (context, index) {
                        Map<String, dynamic> memberData =
                        memberList[index].data();

                        String nickname =
                            memberData['nickname']?.toString() ??
                                '스터디원';

                        int totalStudySeconds =
                        _getTotalStudySeconds(memberData);

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
                                width: 42,
                                height: 42,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: _studyColors.lavender,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    color: _studyColors.pinkStart,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              SizedBox(width: 13),
                              Expanded(
                                child: Text(
                                  nickname,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Text(
                                _formatStudyTime(totalStudySeconds),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _studyColors.pinkStart,
                                  fontWeight: FontWeight.bold,
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

  /// 방장만 스터디 공지를 작성하거나 수정
  void _showNoticeDialog(
      BuildContext context,
      String currentNotice,
      ) {
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
          title: Text(dialogTitle),
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

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('스터디 공지가 저장되었습니다.'),
                    ),
                  );
                } catch (error) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('공지 저장 중 오류가 발생했습니다.'),
                    ),
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
    String displayGroupName =
        groupData['groupName']?.toString() ?? groupName;

    String description =
        groupData['description']?.toString() ?? '';

    String notice = groupData['notice']?.toString() ?? '';

    String certificateName =
        groupData['certificateName']?.toString() ?? '공통 스터디';

    int currentMemberCount = _getInt(
      groupData,
      'currentMemberCount',
    );

    int maxMemberCount = _getInt(
      groupData,
      'maxMemberCount',
    );

    bool joinApprovalRequired = true;

    if (groupData['joinApprovalRequired'] is bool) {
      joinApprovalRequired =
      groupData['joinApprovalRequired'];
    }

    bool isRecruiting = _isRecruiting(groupData);

    String memberText = '$currentMemberCount명';

    if (maxMemberCount > 0) {
      memberText =
      '$currentMemberCount / $maxMemberCount명';
    }

    String joinTypeText = '바로 참여';

    if (joinApprovalRequired) {
      joinTypeText = '승인 후 참여';
    }

    if (description.isEmpty) {
      description =
      '같은 목표를 준비하는 스터디원들과 함께 공부해요.';
    }

    double bottomPadding =
        MediaQuery.of(context).padding.bottom + 42;

    return AppMainBackground(
      applySafeArea: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          18,
          14,
          18,
          bottomPadding,
        ),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            // 스터디 기본 정보
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _studyColors.pinkSoft,
                    _studyColors.lavender,
                  ],
                ),
                borderRadius:
                BorderRadius.circular(28),
                border: Border.all(
                  color: _studyColors.pinkSoft,
                ),
              ),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      _buildRoomBadge(
                        certificateName,
                        _studyColorScheme.surface
                            .withOpacity(0.88),
                        _studyColors.pinkStart,
                      ),
                      _buildRoomBadge(
                        isRecruiting
                            ? '모집 중'
                            : '모집 마감',
                        isRecruiting
                            ? _studyColors.mint
                            : _studyColorScheme
                            .outlineVariant,
                        isRecruiting
                            ? _studyColorScheme
                            .tertiary
                            : _studyColors
                            .textSecondary,
                      ),
                      Visibility(
                        visible: isOwner,
                        child: _buildRoomBadge(
                          '방장',
                          _studyColors.pinkStart,
                          _studyColorScheme.surface,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 14),
                  Text(
                    displayGroupName,
                    maxLines: 2,
                    overflow:
                    TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 23,
                      height: 1.25,
                      fontWeight: FontWeight.bold,
                      color:
                      _studyColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 9),
                  Text(
                    description,
                    maxLines: 3,
                    overflow:
                    TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.55,
                      color:
                      _studyColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 18),
                  Row(
                    children: [
                      _buildRoomMetric(
                        Icons.groups_rounded,
                        '참여 인원',
                        memberText,
                      ),
                      SizedBox(width: 10),
                      _buildRoomMetric(
                        Icons.how_to_reg_rounded,
                        '참여 방식',
                        joinTypeText,
                      ),
                    ],
                  ),
                  Visibility(
                    visible: isOwner,
                    child: Padding(
                      padding:
                      EdgeInsets.only(top: 12),
                      child: InkWell(
                        borderRadius:
                        BorderRadius.circular(15),
                        onTap: () {
                          _updateRecruitmentStatus(
                            context,
                            groupData,
                            isRecruiting == false,
                          );
                        },
                        child: Container(
                          width: double.infinity,
                          padding:
                          EdgeInsets.symmetric(
                            horizontal: 13,
                            vertical: 11,
                          ),
                          decoration: BoxDecoration(
                            color: _studyColorScheme
                                .surface
                                .withOpacity(0.82),
                            borderRadius:
                            BorderRadius.circular(
                              15,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isRecruiting
                                    ? Icons
                                    .lock_outline_rounded
                                    : Icons
                                    .lock_open_rounded,
                                size: 18,
                                color: _studyColors
                                    .pinkStart,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  isRecruiting
                                      ? '신규 참여 모집 마감하기'
                                      : '신규 참여 모집 다시 열기',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight:
                                    FontWeight.bold,
                                    color: _studyColors
                                        .pinkStart,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons
                                    .chevron_right_rounded,
                                size: 20,
                                color: _studyColors
                                    .pinkStart,
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

            _buildRoomSectionTitle(
              '시험과 주간 목표',
              '시험일까지 남은 기간과 이번 주 달성률을 확인해요.',
            ),

            SizedBox(height: 11),

            _buildStudyGoalCard(
              context,
              groupData,
            ),

            SizedBox(height: 26),

            // 열품타식 핵심 영역:
            // 오늘 현황을 먼저 보여주고 바로 공부를 시작하게 구성
            _buildRoomSectionTitle(
              '오늘의 공부',
              '그룹의 공부 현황을 확인하고 바로 시작해요.',
            ),

            SizedBox(height: 11),

            _buildTodayStudySummary(
              context,
              displayGroupName,
            ),

            SizedBox(height: 11),

            _buildPrimaryStudyButton(
              context,
              displayGroupName,
            ),

            SizedBox(height: 26),

            // 현재 스터디원
            Row(
              crossAxisAlignment:
              CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: _buildRoomSectionTitle(
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
                      color:
                      _studyColors.pinkStart,
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
              '공부 기록',
              '공부시간을 비교하고 함께 동기부여를 받아요.',
            ),

            SizedBox(height: 11),

            _buildStudyRecordButton(
              context,
              displayGroupName,
            ),

            SizedBox(height: 11),

            Row(
              children: [
                _buildActivityButton(
                  Icons.emoji_events_rounded,
                  '공부 순위',
                  '그룹원 기록 보기',
                  _studyColors.lavender,
                  _studyColors.pinkStart,
                      () {
                    _openStudyRanking(context);
                  },
                ),
                SizedBox(width: 11),
                _buildActivityButton(
                  Icons.quiz_rounded,
                  '발송 문제',
                  '문제 확인하기',
                  _studyColors.pinkSoft,
                  _studyColors.pinkStart,
                      () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) {
                          return StudyQuizPage(
                            studyId: studyId,
                            groupName:
                            displayGroupName,
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
            _buildRoomSectionTitle(
              '공지',
              '스터디원 모두가 확인해야 할 내용이에요.',
            ),

            SizedBox(height: 10),

            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _studyColors.pinkSoft,
                borderRadius:
                BorderRadius.circular(20),
                border: Border.all(
                  color: _studyColors.pinkSoft,
                ),
              ),
              child: Row(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color:
                      _studyColorScheme.surface,
                      borderRadius:
                      BorderRadius.circular(13),
                    ),
                    child: Icon(
                      Icons.campaign_rounded,
                      color:
                      _studyColors.pinkStart,
                      size: 21,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      notice.isEmpty
                          ? '등록된 공지가 없습니다.'
                          : notice,
                      maxLines: 4,
                      overflow:
                      TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: _studyColors
                            .textSecondary,
                      ),
                    ),
                  ),
                  Visibility(
                    visible: isOwner,
                    child: TextButton(
                      onPressed: () {
                        _showNoticeDialog(
                          context,
                          notice,
                        );
                      },
                      style: TextButton.styleFrom(
                        minimumSize: Size(0, 32),
                        padding:
                        EdgeInsets.symmetric(
                          horizontal: 8,
                        ),
                      ),
                      child: Text(
                        notice.isEmpty
                            ? '등록'
                            : '수정',
                        style: TextStyle(
                          fontSize: 11,
                          color: _studyColors
                              .pinkStart,
                          fontWeight:
                          FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 26),

            // 따iT의 차별 기능: 그룹 채팅
            _buildRoomSectionTitle(
              '그룹 채팅',
              '질문과 공부 계획을 그룹원과 나눠 보세요.',
            ),

            SizedBox(height: 11),

            _buildChatActivityButton(
              context,
              displayGroupName,
            ),
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
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('studyGroups')
            .doc(studyId)
            .snapshots(),
        builder: (context, groupSnapshot) {
          if (groupSnapshot.connectionState ==
              ConnectionState.waiting) {
            return AppLoadingView(
              message: '스터디방을 불러오는 중입니다.',
            );
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

          Map<String, dynamic> groupData =
              groupSnapshot.data!.data() ?? {};

          String ownerUid =
              groupData['ownerUid']?.toString() ?? '';

          bool isOwner =
              currentUser != null && currentUser.uid == ownerUid;

          if (isOwner) {
            return _buildRoomContent(
              context,
              groupData,
              true,
            );
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
              if (memberSnapshot.connectionState ==
                  ConnectionState.waiting) {
                return AppLoadingView(
                  message: '그룹원 정보를 확인하는 중입니다.',
                );
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

              if (memberSnapshot.data != null &&
                  memberSnapshot.data!.exists) {
                Map<String, dynamic> memberData =
                    memberSnapshot.data!.data() ?? {};

                memberStatus =
                    memberData['status']?.toString() ?? '';
              }

              if (memberStatus != 'ACTIVE') {
                return _buildAccessDenied();
              }

              return _buildRoomContent(
                context,
                groupData,
                false,
              );
            },
          );
        },
      ),
    );
  }
}
