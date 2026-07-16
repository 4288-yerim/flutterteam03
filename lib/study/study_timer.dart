import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../theme.dart';
import 'package:flutterteam03/widgets/app_state_views.dart';

import '../widgets/app_card.dart';
import '../widgets/app_main_background.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/app_button.dart';
import '../widgets/loading_overlay.dart';


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

class StudyTimerPage extends StatefulWidget {
  final String studyId;
  final String groupName;

  const StudyTimerPage({
    super.key,
    required this.studyId,
    required this.groupName,
  });

  @override
  State<StudyTimerPage> createState() {
    return _StudyTimerPageState();
  }
}

class _StudyTimerPageState extends State<StudyTimerPage> {
  Timer? _timer;
  DateTime? _startedAt;

  int _elapsedSeconds = 0;
  bool _isStudying = false;
  bool _isSaving = false;

  String _nickname = '사용자';

  Stream<DocumentSnapshot<Map<String, dynamic>>>? _memberStream;
  bool _hasTriedTotalTimeMigration = false;

  @override
  void dispose() {
    if (_timer != null) {
      _timer!.cancel();
    }

    if (_isStudying) {
      _clearLiveStudyStatus();
    }

    super.dispose();
  }

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

  void _reloadPage() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) {
          return StudyTimerPage(
            studyId: widget.studyId,
            groupName: widget.groupName,
          );
        },
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  String _formatTime(int totalSeconds) {
    int hours = totalSeconds ~/ 3600;
    int minutes = (totalSeconds % 3600) ~/ 60;
    int seconds = totalSeconds % 60;

    String hourText = hours.toString().padLeft(2, '0');
    String minuteText = minutes.toString().padLeft(2, '0');
    String secondText = seconds.toString().padLeft(2, '0');

    return '$hourText:$minuteText:$secondText';
  }

  String _formatStudySeconds(int totalSeconds) {
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

  int _getStoredTotalStudySeconds(
      Map<String, dynamic> memberData,
      ) {
    dynamic secondsValue = memberData['totalStudySeconds'];

    if (secondsValue is int) {
      return secondsValue;
    }

    if (secondsValue is num) {
      return secondsValue.toInt();
    }

    dynamic minutesValue = memberData['totalStudyMinutes'];

    if (minutesValue is int) {
      return minutesValue * 60;
    }

    if (minutesValue is num) {
      return (minutesValue * 60).round();
    }

    return 0;
  }

  int _getRecordStudySeconds(Map<String, dynamic> recordData) {
    dynamic studySecondsValue = recordData['studySeconds'];

    if (studySecondsValue is int) {
      return studySecondsValue;
    }

    if (studySecondsValue is num) {
      return studySecondsValue.toInt();
    }

    dynamic elapsedSecondsValue = recordData['elapsedSeconds'];

    if (elapsedSecondsValue is int) {
      return elapsedSecondsValue;
    }

    if (elapsedSecondsValue is num) {
      return elapsedSecondsValue.toInt();
    }

    dynamic studyMinutesValue = recordData['studyMinutes'];

    if (studyMinutesValue is int) {
      return studyMinutesValue * 60;
    }

    if (studyMinutesValue is num) {
      return (studyMinutesValue * 60).round();
    }

    return 0;
  }

  Future<void> _migrateOldTotalStudyTime(String uid) async {
    if (_hasTriedTotalTimeMigration) {
      return;
    }

    _hasTriedTotalTimeMigration = true;

    try {
      QuerySnapshot<Map<String, dynamic>> recordSnapshot =
      await FirebaseFirestore.instance
          .collection('studyGroups')
          .doc(widget.studyId)
          .collection('studyRecords')
          .where('uid', isEqualTo: uid)
          .get();

      int exactTotalSeconds = 0;

      for (int i = 0; i < recordSnapshot.docs.length; i++) {
        exactTotalSeconds +=
            _getRecordStudySeconds(recordSnapshot.docs[i].data());
      }

      DocumentReference<Map<String, dynamic>>? memberDocument =
      _getMemberDocument();

      if (memberDocument == null) {
        return;
      }

      if (exactTotalSeconds == 0) {
        DocumentSnapshot<Map<String, dynamic>> memberSnapshot =
        await memberDocument.get();

        exactTotalSeconds = _getStoredTotalStudySeconds(
          memberSnapshot.data() ?? {},
        );
      }

      await memberDocument.set({
        'totalStudySeconds': exactTotalSeconds,
        'totalStudyMinutes': exactTotalSeconds ~/ 60,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (error) {
      debugPrint('기존 누적 공부시간 변환 오류: $error');
    }
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> _getMemberStream(
      String uid,
      ) {
    if (_memberStream == null) {
      _memberStream = FirebaseFirestore.instance
          .collection('studyGroups')
          .doc(widget.studyId)
          .collection('members')
          .doc(uid)
          .snapshots();
    }

    return _memberStream!;
  }

  DocumentReference<Map<String, dynamic>>? _getMemberDocument() {
    User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return null;
    }

    return FirebaseFirestore.instance
        .collection('studyGroups')
        .doc(widget.studyId)
        .collection('members')
        .doc(currentUser.uid);
  }

  Future<void> _clearLiveStudyStatus() async {
    DocumentReference<Map<String, dynamic>>? memberDocument =
    _getMemberDocument();

    if (memberDocument == null) {
      return;
    }

    try {
      await memberDocument.set({
        'isStudying': false,
        'studyEndedAt': FieldValue.serverTimestamp(),
        'studyStatusUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (error) {
      debugPrint('실시간 공부 상태 해제 오류: $error');
    }
  }

  Future<bool> _checkMember() async {
    User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      _showMessage('로그인 정보가 없습니다.');
      return false;
    }

    DocumentReference<Map<String, dynamic>> groupDocument =
    FirebaseFirestore.instance
        .collection('studyGroups')
        .doc(widget.studyId);

    DocumentReference<Map<String, dynamic>> memberDocument =
    groupDocument.collection('members').doc(currentUser.uid);

    DocumentSnapshot<Map<String, dynamic>> memberSnapshot =
    await memberDocument.get();

    if (memberSnapshot.exists) {
      Map<String, dynamic> memberData = memberSnapshot.data() ?? {};

      String status = memberData['status']?.toString() ?? '';

      if (memberData['nickname'] != null) {
        _nickname = memberData['nickname'].toString();
      }

      if (status == 'ACTIVE') {
        return true;
      }

      if (status == 'PENDING') {
        _showMessage('참여 승인 후 공부시간을 기록할 수 있습니다.');
        return false;
      }

      _showMessage('현재 참여 중인 그룹원만 기록할 수 있습니다.');
      return false;
    }

    DocumentSnapshot<Map<String, dynamic>> groupSnapshot =
    await groupDocument.get();

    if (groupSnapshot.exists == false) {
      _showMessage('스터디 정보를 찾을 수 없습니다.');
      return false;
    }

    Map<String, dynamic> groupData = groupSnapshot.data() ?? {};

    String ownerUid = groupData['ownerUid']?.toString() ?? '';

    if (ownerUid != currentUser.uid) {
      _showMessage('현재 참여 중인 그룹원만 기록할 수 있습니다.');
      return false;
    }

    String ownerNickname =
        groupData['ownerNickname']?.toString() ?? '방장';

    _nickname = ownerNickname;

    await memberDocument.set({
      'uid': currentUser.uid,
      'nickname': ownerNickname,
      'role': 'OWNER',
      'status': 'ACTIVE',
      'totalStudyMinutes': 0,
      'totalStudySeconds': 0,
      'isStudying': false,
      'joinedAt': groupData['createdAt'] ??
          FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return true;
  }

  Future<void> _startStudy() async {
    if (_isStudying || _isSaving) {
      return;
    }

    try {
      bool canStudy = await _checkMember();

      if (canStudy == false) {
        return;
      }

      DocumentReference<Map<String, dynamic>>? memberDocument =
      _getMemberDocument();

      if (memberDocument == null) {
        _showMessage('로그인 정보가 없습니다.');
        return;
      }

      await memberDocument.set({
        'isStudying': true,
        'studyStartedAt': FieldValue.serverTimestamp(),
        'studyStatusUpdatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) {
        return;
      }

      setState(() {
        _elapsedSeconds = 0;
        _isStudying = true;
        _startedAt = DateTime.now();
      });

      _timer = Timer.periodic(
        Duration(seconds: 1),
            (timer) {
          if (!mounted || _startedAt == null) {
            return;
          }

          int currentSeconds = DateTime.now()
              .difference(_startedAt!)
              .inSeconds;

          if (currentSeconds != _elapsedSeconds) {
            setState(() {
              _elapsedSeconds = currentSeconds;
            });
          }
        },
      );
    } catch (error) {
      debugPrint('공부 시작 오류: $error');

      if (mounted) {
        _showMessage('공부를 시작하지 못했습니다.');
      }
    }
  }

  Future<void> _stopStudy() async {
    if (_isStudying == false || _isSaving) {
      return;
    }

    if (_timer != null) {
      _timer!.cancel();
    }

    setState(() {
      _isStudying = false;
      _isSaving = true;
    });

    if (_startedAt != null) {
      _elapsedSeconds = DateTime.now()
          .difference(_startedAt!)
          .inSeconds;
    }

    int studySeconds = _elapsedSeconds;

    if (studySeconds <= 0) {
      await _clearLiveStudyStatus();

      if (mounted) {
        setState(() {
          _isSaving = false;
        });

        _showMessage('1초 이상 공부한 뒤 종료해 주세요.');
      }

      return;
    }

    User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      setState(() {
        _isSaving = false;
      });

      _showMessage('로그인 정보가 없습니다.');
      return;
    }

    DateTime endedAt = DateTime.now();

    DocumentReference<Map<String, dynamic>> memberDocument =
    FirebaseFirestore.instance
        .collection('studyGroups')
        .doc(widget.studyId)
        .collection('members')
        .doc(currentUser.uid);

    DocumentReference<Map<String, dynamic>> recordDocument =
    FirebaseFirestore.instance
        .collection('studyGroups')
        .doc(widget.studyId)
        .collection('studyRecords')
        .doc();

    try {
      await FirebaseFirestore.instance.runTransaction(
            (transaction) async {
          DocumentSnapshot<Map<String, dynamic>> memberSnapshot =
          await transaction.get(memberDocument);

          Map<String, dynamic> memberData =
              memberSnapshot.data() ?? {};

          int previousTotalSeconds =
          _getStoredTotalStudySeconds(memberData);

          int newTotalSeconds =
              previousTotalSeconds + studySeconds;

          transaction.set(
            memberDocument,
            {
              'totalStudySeconds': newTotalSeconds,
              'totalStudyMinutes': newTotalSeconds ~/ 60,
              'lastStudyAt': FieldValue.serverTimestamp(),
              'isStudying': false,
              'studyEndedAt': FieldValue.serverTimestamp(),
              'studyStatusUpdatedAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );

          transaction.set(recordDocument, {
            'uid': currentUser.uid,
            'nickname': _nickname,
            'studySeconds': studySeconds,
            'elapsedSeconds': studySeconds,
            'studyMinutes': studySeconds ~/ 60,
            'startedAt': Timestamp.fromDate(
              _startedAt ?? endedAt,
            ),
            'endedAt': Timestamp.fromDate(endedAt),
            'createdAt': FieldValue.serverTimestamp(),
          });
        },
      );

      if (mounted) {
        _showMessage(
          '${_formatStudySeconds(studySeconds)}이 저장되었습니다.',
        );
      }
    } catch (error) {
      debugPrint('공부시간 저장 오류: $error');

      await _clearLiveStudyStatus();

      if (mounted) {
        _showMessage('공부시간을 저장하지 못했습니다.');
      }
    }

    if (mounted) {
      setState(() {
        _isSaving = false;
      });
    }
  }

  void _resetTimer() {
    if (_isStudying) {
      _showMessage('공부를 종료한 후 초기화해주세요.');
      return;
    }

    setState(() {
      _elapsedSeconds = 0;
      _startedAt = null;
    });
  }

  Future<bool> _onWillPop() async {
    if (_isStudying == false) {
      return true;
    }

    bool? shouldStop = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('공부를 종료할까요?'),
          content: Text(
            '현재 공부시간을 저장한 뒤 스터디방으로 돌아갑니다.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: Text('계속 공부'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: Text('저장하고 종료'),
            ),
          ],
        );
      },
    );

    if (shouldStop != true) {
      return false;
    }

    await _stopStudy();
    return true;
  }

  Widget _buildTimerContent(int totalStudySeconds) {
    String studyStatusText = '공부 준비';
    Color studyStatusColor = _studyColors.textSecondary;
    Color statusBackgroundColor = _studyColorScheme.outlineVariant;

    if (_isStudying) {
      studyStatusText = '공부 중';
      studyStatusColor = _studyColorScheme.tertiary;
      statusBackgroundColor = _studyColors.mint;
    }

    String mainButtonText = '공부 시작';
    Color mainButtonColor = _studyColors.pinkStart;
    VoidCallback? mainButtonFunction = _startStudy;

    if (_isStudying) {
      mainButtonText = '공부 종료';
      mainButtonColor = _studyColors.pinkStart;
      mainButtonFunction = _stopStudy;
    }

    if (_isSaving) {
      mainButtonText = '저장 중...';
      mainButtonFunction = null;
    }

    return AppMainBackground(
      applySafeArea: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          18,
          16,
          18,
          MediaQuery.of(context).padding.bottom + 36,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _studyColors.lavender,
                    _studyColors.pinkSoft,
                  ],
                ),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: _studyColors.lavender,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.groupName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                      color: _studyColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    '집중한 시간은 종료할 때 자동으로 저장됩니다.',
                    style: TextStyle(
                      fontSize: 12,
                      color: _studyColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 17),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: EdgeInsets.all(13),
                          decoration: BoxDecoration(
                            color: _studyColorScheme.surface.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '나의 누적 공부시간',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: _studyColors.textSecondary,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                _formatStudySeconds(totalStudySeconds),
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: _studyColors.pinkStart,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: EdgeInsets.all(13),
                          decoration: BoxDecoration(
                            color: _studyColorScheme.surface.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '현재 상태',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: _studyColors.textSecondary,
                                ),
                              ),
                              SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: studyStatusColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    studyStatusText,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: studyStatusColor,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 18),
            AppCard(
              backgroundColor: _studyColorScheme.surface,
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: statusBackgroundColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      studyStatusText,
                      style: TextStyle(
                        fontSize: 12,
                        color: studyStatusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(height: 22),
                  Text(
                    _formatTime(_elapsedSeconds),
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      color: _studyColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 9),
                  Text(
                    _isStudying
                        ? '지금 스터디방에 공부 중으로 표시되고 있습니다.'
                        : '시작 버튼을 누르면 다른 그룹원에게 공부 중으로 표시됩니다.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.45,
                      color: _studyColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 25),
                  AppButton(
                    text: mainButtonText,
                    type: AppButtonType.primaryPink,
                    height: 50,
                    onPressed: mainButtonFunction,
                  ),
                  SizedBox(height: 10),
                  AppButton(
                    text: '시간 초기화',
                    type: AppButtonType.outlinePink,
                    height: 44,
                    onPressed: _isSaving ? null : _resetTimer,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return Scaffold(
        appBar: AppTopBar(
          title: '공부시간 기록',
        ),
        body: AppErrorView(
          message: '로그인 정보를 확인할 수 없습니다.',
          description: '다시 로그인한 뒤 공부시간을 기록해 주세요.',
        ),
      );
    }

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppTopBar(
          title: '공부시간 기록',
        ),
        body: Stack(
          children: [
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _getMemberStream(currentUser.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return AppLoadingView(
                    message: '공부시간 정보를 불러오는 중입니다.',
                  );
                }

                if (snapshot.hasError) {
                  if (_isNetworkError(snapshot.error)) {
                    return AppNetworkErrorView(
                      message: '인터넷 연결을 확인해 주세요.',
                      description: '네트워크 연결 후 공부시간 정보를 다시 불러와 주세요.',
                      onRetryPressed: _reloadPage,
                    );
                  }

                  return AppErrorView(
                    message: '공부시간 정보를 불러오지 못했습니다.',
                    description: '잠시 후 다시 시도해 주세요.',
                    onRetryPressed: _reloadPage,
                  );
                }

                int totalStudySeconds = 0;

                if (snapshot.data != null && snapshot.data!.exists) {
                  Map<String, dynamic> memberData =
                      snapshot.data!.data() ?? {};

                  if (memberData.containsKey('totalStudySeconds') == false) {
                    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
                      _migrateOldTotalStudyTime(currentUser.uid);
                    });
                  }

                  totalStudySeconds =
                      _getStoredTotalStudySeconds(memberData);

                  String status = memberData['status']?.toString() ?? '';
                  String role = memberData['role']?.toString() ?? '';

                  if (status.isNotEmpty &&
                      status != 'ACTIVE' &&
                      role != 'OWNER') {
                    return AppErrorView(
                      message: '공부시간을 기록할 수 없습니다.',
                      description: '현재 참여 중인 그룹원만 이용할 수 있습니다.',
                    );
                  }
                }

                return _buildTimerContent(totalStudySeconds);
              },
            ),
            if (_isSaving)
              Positioned.fill(
                child: LoadingOverlay(),
              ),
          ],
        ),
      ),
    );
  }
}
