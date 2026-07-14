import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../widgets/app_card.dart';
import '../widgets/app_main_background.dart';

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

  @override
  void dispose() {
    if (_timer != null) {
      _timer!.cancel();
    }

    super.dispose();
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

  String _formatStudyMinutes(int totalMinutes) {
    if (totalMinutes <= 0) {
      return '0분';
    }

    int hours = totalMinutes ~/ 60;
    int minutes = totalMinutes % 60;

    if (hours == 0) {
      return '$minutes분';
    }

    if (minutes == 0) {
      return '$hours시간';
    }

    return '$hours시간 $minutes분';
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
    groupDocument
        .collection('members')
        .doc(currentUser.uid);

    DocumentSnapshot<Map<String, dynamic>> memberSnapshot =
    await memberDocument.get();

    if (memberSnapshot.exists) {
      Map<String, dynamic> memberData =
          memberSnapshot.data() ?? {};

      String status =
          memberData['status']?.toString() ?? '';

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

    Map<String, dynamic> groupData =
        groupSnapshot.data() ?? {};

    String ownerUid =
        groupData['ownerUid']?.toString() ?? '';

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
      'joinedAt': groupData['createdAt'] ??
          FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return true;
  }

  Future<void> _startStudy() async {
    if (_isStudying) {
      return;
    }

    bool canStudy = await _checkMember();

    if (canStudy == false) {
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
        if (mounted) {
          setState(() {
            _elapsedSeconds++;
          });
        }
      },
    );
  }

  Future<void> _stopStudy() async {
    if (_isStudying == false) {
      return;
    }

    if (_isSaving) {
      return;
    }

    if (_timer != null) {
      _timer!.cancel();
    }

    setState(() {
      _isStudying = false;
      _isSaving = true;
    });

    int studyMinutes = _elapsedSeconds ~/ 60;

    if (_elapsedSeconds % 60 > 0) {
      studyMinutes++;
    }

    if (studyMinutes <= 0) {
      studyMinutes = 1;
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

    CollectionReference<Map<String, dynamic>> recordCollection =
    FirebaseFirestore.instance
        .collection('studyGroups')
        .doc(widget.studyId)
        .collection('studyRecords');

    try {
      await memberDocument.update({
        'totalStudyMinutes': FieldValue.increment(studyMinutes),
        'lastStudyAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await recordCollection.add({
        'uid': currentUser.uid,
        'nickname': _nickname,
        'studyMinutes': studyMinutes,
        'elapsedSeconds': _elapsedSeconds,
        'startedAt': Timestamp.fromDate(
          _startedAt ?? endedAt,
        ),
        'endedAt': Timestamp.fromDate(endedAt),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        _showMessage('$studyMinutes분이 저장되었습니다.');
      }
    } catch (error) {
      debugPrint('공부시간 저장 오류: $error');

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

  @override
  Widget build(BuildContext context) {
    User? currentUser = FirebaseAuth.instance.currentUser;

    Stream<DocumentSnapshot<Map<String, dynamic>>>? memberStream;

    if (currentUser != null) {
      memberStream = FirebaseFirestore.instance
          .collection('studyGroups')
          .doc(widget.studyId)
          .collection('members')
          .doc(currentUser.uid)
          .snapshots();
    }

    String studyStatusText = '공부 준비';
    Color studyStatusColor = Color(0xFF777C86);

    if (_isStudying) {
      studyStatusText = '공부 중';
      studyStatusColor = Color(0xFF3F9C72);
    }

    String mainButtonText = '공부 시작';
    Color mainButtonColor = Color(0xFF8068D8);
    VoidCallback? mainButtonFunction = _startStudy;

    if (_isStudying) {
      mainButtonText = '공부 종료';
      mainButtonColor = Color(0xFFE45F73);
      mainButtonFunction = _stopStudy;
    }

    if (_isSaving) {
      mainButtonText = '저장 중...';
      mainButtonFunction = null;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('공부시간 기록'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: AppMainBackground(
        applySafeArea: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.groupName,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              SizedBox(height: 16),

              AppCard(
                child: StreamBuilder<
                    DocumentSnapshot<Map<String, dynamic>>>(
                  stream: memberStream,
                  builder: (context, snapshot) {
                    int totalStudyMinutes = 0;

                    if (snapshot.hasData &&
                        snapshot.data!.exists) {
                      Map<String, dynamic> memberData =
                          snapshot.data!.data() ?? {};

                      dynamic value =
                      memberData['totalStudyMinutes'];

                      if (value is int) {
                        totalStudyMinutes = value;
                      }

                      if (value is num) {
                        totalStudyMinutes = value.toInt();
                      }
                    }

                    return Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 30,
                          color: Color(0xFF8068D8),
                        ),

                        SizedBox(width: 12),

                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '나의 누적 공부시간',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF777C86),
                              ),
                            ),

                            SizedBox(height: 4),

                            Text(
                              _formatStudyMinutes(totalStudyMinutes),
                              style: TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),

              SizedBox(height: 16),

              AppCard(
                child: Column(
                  children: [
                    Text(
                      studyStatusText,
                      style: TextStyle(
                        fontSize: 14,
                        color: studyStatusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    SizedBox(height: 18),

                    Text(
                      _formatTime(_elapsedSeconds),
                      style: TextStyle(
                        fontSize: 46,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),

                    SizedBox(height: 10),

                    Text(
                      '1분 미만으로 공부해도 1분으로 저장됩니다.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF858994),
                      ),
                    ),

                    SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: mainButtonFunction,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: mainButtonColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          mainButtonText,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: 10),

                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: OutlinedButton(
                        onPressed: _resetTimer,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Color(0xFF6C54C8),
                          side: BorderSide(
                            color: Color(0xFFD7D3DE),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text('시간 초기화'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
