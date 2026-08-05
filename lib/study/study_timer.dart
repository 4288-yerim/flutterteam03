import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutterteam03/widgets/app_state_views.dart';

import '../theme.dart';
import '../services/user_profile_cache_service.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_main_background.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/loading_overlay.dart';

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

class _StudyTimerPageState extends State<StudyTimerPage>
    with WidgetsBindingObserver {
  Timer? _timer;

  DateTime? _sessionStartedAt;
  DateTime? _runningSegmentStartedAt;

  int _studySeconds = 0;
  int _restSeconds = 0;
  int _phaseSeconds = 0;

  int _focusExitCount = 0;
  int _pauseCount = 0;
  int _completedFocusRounds = 0;

  int _pomodoroStudyMinutes = 25;
  int _pomodoroRestMinutes = 5;

  bool _isSessionActive = false;
  bool _isPaused = false;
  bool _isResting = false;
  bool _isSaving = false;
  bool _isProcessingPhase = false;
  bool _isAppInBackground = false;

  bool _hasRestoredLiveStudy = false;
  bool _hasTriedTotalTimeMigration = false;
  bool _hasTriedDefaultSubjectCreation = false;

  String _timerMode = 'STOPWATCH';
  String _nickname = '사용자';
  String _activeSubjectId = '';
  String _activeSubjectName = '';

  Stream<DocumentSnapshot<Map<String, dynamic>>>? _memberStream;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _subjectStream;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _todayRecordStream;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _timer?.cancel();

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      if (!_isAppInBackground) {
        _isAppInBackground = true;

        if (_isSessionActive && !_isPaused && !_isResting) {
          setState(() {
            _focusExitCount++;
          });

          _saveFocusExitCount();
        }
      }

      return;
    }

    if (state == AppLifecycleState.resumed) {
      _isAppInBackground = false;

      if (_isSessionActive && !_isPaused) {
        _processTimerTick();
      }
    }
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
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  int _readInt(
    Map<String, dynamic> data,
    String fieldName, {
    int fallback = 0,
  }) {
    dynamic value = data[fieldName];

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return fallback;
  }

  String _formatTimer(int totalSeconds) {
    if (totalSeconds < 0) {
      totalSeconds = 0;
    }

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
      return '0분';
    }

    int hours = totalSeconds ~/ 3600;
    int minutes = (totalSeconds % 3600) ~/ 60;
    int seconds = totalSeconds % 60;

    if (hours > 0) {
      if (seconds > 0) {
        return '$hours시간 $minutes분 $seconds초';
      }

      return '$hours시간 $minutes분';
    }

    if (minutes > 0) {
      if (seconds > 0) {
        return '$minutes분 $seconds초';
      }

      return '$minutes분';
    }

    return '$seconds초';
  }

  String _formatCompactStudySeconds(int totalSeconds) {
    if (totalSeconds <= 0) {
      return '0분';
    }

    int hours = totalSeconds ~/ 3600;
    int minutes = (totalSeconds % 3600) ~/ 60;

    if (hours > 0) {
      return '$hours시간 $minutes분';
    }

    if (minutes > 0) {
      return '$minutes분';
    }

    return '${totalSeconds}초';
  }

  String _formatStudyDate(DateTime dateTime) {
    String year = dateTime.year.toString();

    String month = dateTime.month.toString().padLeft(2, '0');

    String day = dateTime.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  int _getStoredTotalStudySeconds(Map<String, dynamic> memberData) {
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

  int _getCurrentSegmentSeconds() {
    if (!_isSessionActive || _isPaused || _runningSegmentStartedAt == null) {
      return 0;
    }

    int seconds = DateTime.now()
        .difference(_runningSegmentStartedAt!)
        .inSeconds;

    if (seconds < 0) {
      return 0;
    }

    return seconds;
  }

  int _getCurrentStudySeconds() {
    int totalSeconds = _studySeconds;

    if (_isSessionActive && !_isPaused && !_isResting) {
      totalSeconds += _getCurrentSegmentSeconds();
    }

    return totalSeconds;
  }

  int _getCurrentRestSeconds() {
    int totalSeconds = _restSeconds;

    if (_isSessionActive && !_isPaused && _isResting) {
      totalSeconds += _getCurrentSegmentSeconds();
    }

    return totalSeconds;
  }

  int _getCurrentPhaseSeconds() {
    int totalSeconds = _phaseSeconds;

    if (_isSessionActive && !_isPaused) {
      totalSeconds += _getCurrentSegmentSeconds();
    }

    return totalSeconds;
  }

  int _getCurrentPhaseTargetSeconds() {
    if (_timerMode != 'POMODORO') {
      return 0;
    }

    if (_isResting) {
      return _pomodoroRestMinutes * 60;
    }

    return _pomodoroStudyMinutes * 60;
  }

  int _getPomodoroRemainingSeconds() {
    int remainingSeconds =
        _getCurrentPhaseTargetSeconds() - _getCurrentPhaseSeconds();

    if (remainingSeconds < 0) {
      return 0;
    }

    return remainingSeconds;
  }

  int _getFocusScore() {
    int score = 100;

    score -= _focusExitCount * 10;
    score -= _pauseCount * 3;

    if (score < 0) {
      return 0;
    }

    return score;
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> _getMemberStream(String uid) {
    _memberStream ??= FirebaseFirestore.instance
        .collection('studyGroups')
        .doc(widget.studyId)
        .collection('members')
        .doc(uid)
        .snapshots();

    return _memberStream!;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _getSubjectStream(String uid) {
    _subjectStream ??= FirebaseFirestore.instance
        .collection('studyGroups')
        .doc(widget.studyId)
        .collection('members')
        .doc(uid)
        .collection('subjects')
        .snapshots();

    return _subjectStream!;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _getTodayRecordStream() {
    if (_todayRecordStream == null) {
      DateTime now = DateTime.now();

      DateTime todayStart = DateTime(now.year, now.month, now.day);

      DateTime tomorrowStart = todayStart.add(Duration(days: 1));

      _todayRecordStream = FirebaseFirestore.instance
          .collection('studyGroups')
          .doc(widget.studyId)
          .collection('studyRecords')
          .where(
            'endedAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart),
          )
          .where('endedAt', isLessThan: Timestamp.fromDate(tomorrowStart))
          .snapshots();
    }

    return _todayRecordStream!;
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

  CollectionReference<Map<String, dynamic>>? _getSubjectCollection() {
    User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return null;
    }

    return FirebaseFirestore.instance
        .collection('studyGroups')
        .doc(widget.studyId)
        .collection('members')
        .doc(currentUser.uid)
        .collection('subjects');
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
        exactTotalSeconds += _getRecordStudySeconds(
          recordSnapshot.docs[i].data(),
        );
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

  Future<void> _ensureDefaultSubjects(String uid) async {
    if (_hasTriedDefaultSubjectCreation) {
      return;
    }

    _hasTriedDefaultSubjectCreation = true;

    try {
      CollectionReference<Map<String, dynamic>> subjectCollection =
          FirebaseFirestore.instance
              .collection('studyGroups')
              .doc(widget.studyId)
              .collection('members')
              .doc(uid)
              .collection('subjects');

      QuerySnapshot<Map<String, dynamic>> subjectSnapshot =
          await subjectCollection.limit(1).get();

      if (subjectSnapshot.docs.isNotEmpty) {
        return;
      }

      WriteBatch batch = FirebaseFirestore.instance.batch();

      List<String> defaultSubjects = ['전체 공부', '이론 공부', '문제 풀이', '오답 정리'];

      for (int i = 0; i < defaultSubjects.length; i++) {
        DocumentReference<Map<String, dynamic>> subjectDocument =
            subjectCollection.doc();

        batch.set(subjectDocument, {
          'name': defaultSubjects[i],
          'order': i,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    } catch (error) {
      debugPrint('기본 과목 생성 오류: $error');
    }
  }

  Future<bool> _checkMember() async {
    User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      _showMessage('로그인 정보가 없습니다.');
      return false;
    }

    final currentProfile = await UserProfileCacheService.instance.getProfile(
      currentUser.uid,
    );

    DocumentReference<Map<String, dynamic>> groupDocument = FirebaseFirestore
        .instance
        .collection('studyGroups')
        .doc(widget.studyId);

    DocumentReference<Map<String, dynamic>> memberDocument = groupDocument
        .collection('members')
        .doc(currentUser.uid);

    DocumentSnapshot<Map<String, dynamic>> memberSnapshot = await memberDocument
        .get();

    if (memberSnapshot.exists) {
      Map<String, dynamic> memberData = memberSnapshot.data() ?? {};

      String status = memberData['status']?.toString() ?? '';

      if (memberData['nickname'] != null) {
        _nickname = memberData['nickname'].toString();
      }

      if (currentProfile?.nickname.isNotEmpty == true) {
        _nickname = currentProfile!.nickname;
      }

      if (status == 'ACTIVE' || memberData['role']?.toString() == 'OWNER') {
        return true;
      }

      if (status == 'PENDING') {
        _showMessage('참여 승인 후 공부시간을 기록할 수 있습니다.');
        return false;
      }

      _showMessage('현재 참여 중인 그룹원만 기록할 수 있습니다.');
      return false;
    }

    DocumentSnapshot<Map<String, dynamic>> groupSnapshot = await groupDocument
        .get();

    if (!groupSnapshot.exists) {
      _showMessage('스터디 정보를 찾을 수 없습니다.');
      return false;
    }

    Map<String, dynamic> groupData = groupSnapshot.data() ?? {};

    String ownerUid = groupData['ownerUid']?.toString() ?? '';

    if (ownerUid != currentUser.uid) {
      _showMessage('현재 참여 중인 그룹원만 기록할 수 있습니다.');
      return false;
    }

    String ownerNickname = groupData['ownerNickname']?.toString() ?? '방장';

    if (currentProfile?.nickname.isNotEmpty == true) {
      ownerNickname = currentProfile!.nickname;
    }

    _nickname = ownerNickname;

    await memberDocument.set({
      'uid': currentUser.uid,
      'nickname': ownerNickname,
      'role': 'OWNER',
      'status': 'ACTIVE',
      'totalStudyMinutes': 0,
      'totalStudySeconds': 0,
      'isStudying': false,
      'isResting': false,
      'studyStatus': 'IDLE',
      'studySubject': '',
      'currentSubject': '',
      'joinedAt': groupData['createdAt'] ?? FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return true;
  }

  int _consumeElapsedSeconds(int elapsedSeconds) {
    if (elapsedSeconds <= 0) {
      return 0;
    }

    if (_timerMode != 'POMODORO') {
      _studySeconds += elapsedSeconds;
      _phaseSeconds += elapsedSeconds;

      return 0;
    }

    int transitionCount = 0;
    int remainingSeconds = elapsedSeconds;

    while (remainingSeconds > 0) {
      int phaseTargetSeconds = _isResting
          ? _pomodoroRestMinutes * 60
          : _pomodoroStudyMinutes * 60;

      int phaseRemainingSeconds = phaseTargetSeconds - _phaseSeconds;

      if (phaseRemainingSeconds <= 0) {
        if (!_isResting) {
          _completedFocusRounds++;
        }

        _isResting = !_isResting;
        _phaseSeconds = 0;
        transitionCount++;

        continue;
      }

      if (remainingSeconds < phaseRemainingSeconds) {
        if (_isResting) {
          _restSeconds += remainingSeconds;
        } else {
          _studySeconds += remainingSeconds;
        }

        _phaseSeconds += remainingSeconds;

        remainingSeconds = 0;
      } else {
        if (_isResting) {
          _restSeconds += phaseRemainingSeconds;
        } else {
          _studySeconds += phaseRemainingSeconds;

          _completedFocusRounds++;
        }

        remainingSeconds -= phaseRemainingSeconds;

        _isResting = !_isResting;
        _phaseSeconds = 0;
        transitionCount++;
      }
    }

    return transitionCount;
  }

  int _commitRunningSegment({bool keepRunning = false}) {
    if (!_isSessionActive || _isPaused || _runningSegmentStartedAt == null) {
      return 0;
    }

    DateTime now = DateTime.now();

    int elapsedSeconds = now.difference(_runningSegmentStartedAt!).inSeconds;

    if (elapsedSeconds < 0) {
      elapsedSeconds = 0;
    }

    int transitionCount = _consumeElapsedSeconds(elapsedSeconds);

    if (keepRunning) {
      _runningSegmentStartedAt = now;
    } else {
      _runningSegmentStartedAt = null;
    }

    return transitionCount;
  }

  void _startLocalTimer() {
    _timer?.cancel();

    if (!_isSessionActive || _isPaused) {
      return;
    }

    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      _processTimerTick();
    });

    _processTimerTick();
  }

  void _processTimerTick() {
    if (!mounted || !_isSessionActive || _isPaused || _isProcessingPhase) {
      return;
    }

    if (_timerMode != 'POMODORO') {
      setState(() {});

      return;
    }

    int currentPhaseSeconds = _getCurrentPhaseSeconds();

    int phaseTargetSeconds = _getCurrentPhaseTargetSeconds();

    if (currentPhaseSeconds < phaseTargetSeconds) {
      setState(() {});

      return;
    }

    _isProcessingPhase = true;

    _timer?.cancel();

    bool wasResting = _isResting;

    int transitionCount = 0;

    setState(() {
      transitionCount = _commitRunningSegment(keepRunning: true);
    });

    _writeLiveStatus();

    if (transitionCount > 0) {
      if (wasResting == _isResting) {
        _showMessage(
          _isResting ? '집중 시간이 끝나 휴식을 시작합니다.' : '휴식이 끝나 다시 집중을 시작합니다.',
        );
      } else {
        _showMessage(
          _isResting ? '집중 시간이 끝나 휴식을 시작합니다.' : '휴식이 끝나 다시 집중을 시작합니다.',
        );
      }
    }

    _isProcessingPhase = false;

    _startLocalTimer();
  }

  Future<void> _writeLiveStatus() async {
    DocumentReference<Map<String, dynamic>>? memberDocument =
        _getMemberDocument();

    if (memberDocument == null) {
      return;
    }

    bool isCurrentlyStudying = _isSessionActive && !_isPaused && !_isResting;

    bool isCurrentlyResting = _isSessionActive && !_isPaused && _isResting;

    String studyStatus = 'IDLE';

    if (_isSessionActive) {
      if (_isPaused) {
        studyStatus = 'PAUSED';
      } else if (_isResting) {
        studyStatus = 'RESTING';
      } else {
        studyStatus = 'STUDYING';
      }
    }

    try {
      await memberDocument.set({
        'timerSessionActive': _isSessionActive,
        'timerMode': _timerMode,
        'timerPhase': _isResting ? 'REST' : 'STUDY',
        'timerPaused': _isPaused,
        'timerStudySeconds': _studySeconds,
        'timerRestSeconds': _restSeconds,
        'timerPhaseSeconds': _phaseSeconds,
        'timerSegmentStartedAt': _isSessionActive && !_isPaused
            ? FieldValue.serverTimestamp()
            : null,
        'pomodoroStudyMinutes': _pomodoroStudyMinutes,
        'pomodoroRestMinutes': _pomodoroRestMinutes,
        'focusExitCount': _focusExitCount,
        'pauseCount': _pauseCount,
        'completedFocusRounds': _completedFocusRounds,
        'isStudying': isCurrentlyStudying,
        'isResting': isCurrentlyResting,
        'studyStatus': studyStatus,
        'studySubjectId': _activeSubjectId,
        'studySubject': _activeSubjectName,
        'currentSubject': _activeSubjectName,
        'studyStatusUpdatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (error) {
      debugPrint('실시간 타이머 상태 저장 오류: $error');
    }
  }

  Future<void> _saveFocusExitCount() async {
    DocumentReference<Map<String, dynamic>>? memberDocument =
        _getMemberDocument();

    if (memberDocument == null) {
      return;
    }

    try {
      await memberDocument.set({
        'focusExitCount': _focusExitCount,
        'lastFocusExitAt': FieldValue.serverTimestamp(),
        'studyStatusUpdatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (error) {
      debugPrint('집중 이탈 횟수 저장 오류: $error');
    }
  }

  void _restoreLiveStudy(Map<String, dynamic> memberData) {
    if (_hasRestoredLiveStudy) {
      return;
    }

    _hasRestoredLiveStudy = true;

    bool hasNewTimerSession = memberData['timerSessionActive'] == true;

    bool hasOldTimerSession = memberData['isStudying'] == true;

    if (!hasNewTimerSession && !hasOldTimerSession) {
      return;
    }

    String restoredMode = memberData['timerMode']?.toString() ?? 'STOPWATCH';

    if (restoredMode != 'POMODORO') {
      restoredMode = 'STOPWATCH';
    }

    String subjectId = memberData['studySubjectId']?.toString() ?? '';

    String subjectName = memberData['studySubject']?.toString() ?? '';

    if (subjectName.isEmpty) {
      subjectName = memberData['currentSubject']?.toString() ?? '';
    }

    bool restoredPaused = memberData['timerPaused'] == true;

    bool restoredResting = memberData['timerPhase']?.toString() == 'REST';

    int restoredStudySeconds = _readInt(memberData, 'timerStudySeconds');

    int restoredRestSeconds = _readInt(memberData, 'timerRestSeconds');

    int restoredPhaseSeconds = _readInt(memberData, 'timerPhaseSeconds');

    int restoredExitCount = _readInt(memberData, 'focusExitCount');

    int restoredPauseCount = _readInt(memberData, 'pauseCount');

    int restoredFocusRounds = _readInt(memberData, 'completedFocusRounds');

    int restoredStudyMinutes = _readInt(
      memberData,
      'pomodoroStudyMinutes',
      fallback: 25,
    );

    int restoredRestMinutes = _readInt(
      memberData,
      'pomodoroRestMinutes',
      fallback: 5,
    );

    dynamic sessionStartedAtValue = memberData['studyStartedAt'];

    DateTime? restoredSessionStartedAt;

    if (sessionStartedAtValue is Timestamp) {
      restoredSessionStartedAt = sessionStartedAtValue.toDate().toLocal();
    }

    dynamic segmentStartedAtValue = memberData['timerSegmentStartedAt'];

    DateTime? restoredSegmentStartedAt;

    if (segmentStartedAtValue is Timestamp) {
      restoredSegmentStartedAt = segmentStartedAtValue.toDate().toLocal();
    }

    if (!hasNewTimerSession && hasOldTimerSession) {
      restoredMode = 'STOPWATCH';
      restoredPaused = false;
      restoredResting = false;
      restoredStudySeconds = 0;
      restoredRestSeconds = 0;
      restoredPhaseSeconds = 0;

      dynamic oldStartedAtValue = memberData['studyStartedAt'];

      if (oldStartedAtValue is Timestamp) {
        restoredSegmentStartedAt = oldStartedAtValue.toDate().toLocal();

        restoredSessionStartedAt = restoredSegmentStartedAt;
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      if (!mounted) {
        return;
      }

      setState(() {
        _timerMode = restoredMode;
        _isSessionActive = true;
        _isPaused = restoredPaused;
        _isResting = restoredResting;

        _studySeconds = restoredStudySeconds;

        _restSeconds = restoredRestSeconds;

        _phaseSeconds = restoredPhaseSeconds;

        _focusExitCount = restoredExitCount;

        _pauseCount = restoredPauseCount;

        _completedFocusRounds = restoredFocusRounds;

        _pomodoroStudyMinutes = restoredStudyMinutes < 1
            ? 25
            : restoredStudyMinutes;

        _pomodoroRestMinutes = restoredRestMinutes < 1
            ? 5
            : restoredRestMinutes;

        _activeSubjectId = subjectId;

        _activeSubjectName = subjectName.isEmpty ? '공부' : subjectName;

        _sessionStartedAt = restoredSessionStartedAt ?? DateTime.now();

        if (!_isPaused) {
          _runningSegmentStartedAt = restoredSegmentStartedAt ?? DateTime.now();
        }
      });

      if (!_isPaused) {
        _startLocalTimer();
      }
    });
  }

  Future<void> _startStudy(String subjectId, String subjectName) async {
    if (_isSessionActive || _isSaving) {
      return;
    }

    try {
      bool canStudy = await _checkMember();

      if (!canStudy) {
        return;
      }

      DocumentReference<Map<String, dynamic>>? memberDocument =
          _getMemberDocument();

      if (memberDocument == null) {
        _showMessage('로그인 정보가 없습니다.');
        return;
      }

      DateTime startedAt = DateTime.now();

      await memberDocument.set({
        'timerSessionActive': true,
        'timerMode': _timerMode,
        'timerPhase': 'STUDY',
        'timerPaused': false,
        'timerStudySeconds': 0,
        'timerRestSeconds': 0,
        'timerPhaseSeconds': 0,
        'timerSegmentStartedAt': FieldValue.serverTimestamp(),
        'pomodoroStudyMinutes': _pomodoroStudyMinutes,
        'pomodoroRestMinutes': _pomodoroRestMinutes,
        'focusExitCount': 0,
        'pauseCount': 0,
        'completedFocusRounds': 0,
        'isStudying': true,
        'isResting': false,
        'studyStatus': 'STUDYING',
        'studySubjectId': subjectId,
        'studySubject': subjectName,
        'currentSubject': subjectName,
        'studyStartedAt': FieldValue.serverTimestamp(),
        'studyStatusUpdatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) {
        return;
      }

      setState(() {
        _isSessionActive = true;
        _isPaused = false;
        _isResting = false;

        _studySeconds = 0;
        _restSeconds = 0;
        _phaseSeconds = 0;

        _focusExitCount = 0;
        _pauseCount = 0;
        _completedFocusRounds = 0;

        _activeSubjectId = subjectId;
        _activeSubjectName = subjectName;

        _sessionStartedAt = startedAt;
        _runningSegmentStartedAt = startedAt;
      });

      _startLocalTimer();
    } catch (error) {
      debugPrint('공부 시작 오류: $error');

      _showMessage('공부를 시작하지 못했습니다.');
    }
  }

  Future<void> _togglePause() async {
    if (!_isSessionActive || _isSaving) {
      return;
    }

    if (_isPaused) {
      setState(() {
        _isPaused = false;
        _runningSegmentStartedAt = DateTime.now();
      });

      _startLocalTimer();

      await _writeLiveStatus();

      _showMessage(_isResting ? '휴식을 다시 시작합니다.' : '공부를 다시 시작합니다.');

      return;
    }

    _timer?.cancel();

    setState(() {
      _commitRunningSegment();
      _isPaused = true;
      _pauseCount++;
    });

    await _writeLiveStatus();

    _showMessage('타이머가 일시정지되었습니다.');
  }

  Future<void> _skipRest() async {
    if (!_isSessionActive || !_isResting || _isSaving) {
      return;
    }

    _timer?.cancel();

    setState(() {
      _commitRunningSegment();
      _isResting = false;
      _phaseSeconds = 0;
      _isPaused = false;
      _runningSegmentStartedAt = DateTime.now();
    });

    await _writeLiveStatus();

    _showMessage('휴식을 건너뛰고 다시 집중을 시작합니다.');

    _startLocalTimer();
  }

  Future<void> _stopStudy() async {
    if (!_isSessionActive || _isSaving) {
      return;
    }

    _timer?.cancel();

    setState(() {
      _commitRunningSegment();
      _isSaving = true;
    });

    int studySeconds = _studySeconds;

    int restSeconds = _restSeconds;

    if (studySeconds <= 0) {
      setState(() {
        _isSaving = false;
      });

      if (!_isPaused) {
        setState(() {
          _runningSegmentStartedAt = DateTime.now();
        });

        _startLocalTimer();
      }

      _showMessage('1초 이상 공부한 뒤 종료해 주세요.');

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

    DocumentReference<Map<String, dynamic>> memberDocument = FirebaseFirestore
        .instance
        .collection('studyGroups')
        .doc(widget.studyId)
        .collection('members')
        .doc(currentUser.uid);

    DocumentReference<Map<String, dynamic>> recordDocument = FirebaseFirestore
        .instance
        .collection('studyGroups')
        .doc(widget.studyId)
        .collection('studyRecords')
        .doc();

    int focusScore = _getFocusScore();

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot<Map<String, dynamic>> memberSnapshot =
            await transaction.get(memberDocument);

        Map<String, dynamic> memberData = memberSnapshot.data() ?? {};

        int previousTotalSeconds = _getStoredTotalStudySeconds(memberData);

        int newTotalSeconds = previousTotalSeconds + studySeconds;

        transaction.set(memberDocument, {
          'totalStudySeconds': newTotalSeconds,
          'totalStudyMinutes': newTotalSeconds ~/ 60,
          'lastStudyAt': FieldValue.serverTimestamp(),
          'lastStudySubjectId': _activeSubjectId,
          'lastStudySubject': _activeSubjectName,
          'lastTimerMode': _timerMode,
          'lastFocusScore': focusScore,
          'lastFocusExitCount': _focusExitCount,
          'lastPauseCount': _pauseCount,
          'lastRestSeconds': restSeconds,
          'lastCompletedFocusRounds': _completedFocusRounds,
          'timerSessionActive': false,
          'timerMode': '',
          'timerPhase': '',
          'timerPaused': false,
          'timerStudySeconds': 0,
          'timerRestSeconds': 0,
          'timerPhaseSeconds': 0,
          'timerSegmentStartedAt': null,
          'isStudying': false,
          'isResting': false,
          'studyStatus': 'IDLE',
          'studySubjectId': '',
          'studySubject': '',
          'currentSubject': '',
          'studyEndedAt': FieldValue.serverTimestamp(),
          'studyStatusUpdatedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        transaction.set(recordDocument, {
          'uid': currentUser.uid,
          'nickname': _nickname,
          'subjectId': _activeSubjectId,
          'subject': _activeSubjectName,
          'studySubject': _activeSubjectName,
          'studyDate': _formatStudyDate(endedAt),
          'studySeconds': studySeconds,
          'elapsedSeconds': studySeconds,
          'studyMinutes': studySeconds ~/ 60,
          'restSeconds': restSeconds,
          'timerMode': _timerMode,
          'focusExitCount': _focusExitCount,
          'pauseCount': _pauseCount,
          'focusScore': focusScore,
          'completedFocusRounds': _completedFocusRounds,
          'pomodoroStudyMinutes': _pomodoroStudyMinutes,
          'pomodoroRestMinutes': _pomodoroRestMinutes,
          'startedAt': Timestamp.fromDate(_sessionStartedAt ?? endedAt),
          'endedAt': Timestamp.fromDate(endedAt),
          'createdAt': FieldValue.serverTimestamp(),
        });
      });

      if (!mounted) {
        return;
      }

      _showMessage(
        '${_activeSubjectName} '
        '${_formatStudySeconds(studySeconds)}이 저장되었습니다.',
      );

      setState(() {
        _isSessionActive = false;
        _isPaused = false;
        _isResting = false;
        _isSaving = false;

        _studySeconds = 0;
        _restSeconds = 0;
        _phaseSeconds = 0;

        _focusExitCount = 0;
        _pauseCount = 0;
        _completedFocusRounds = 0;

        _sessionStartedAt = null;
        _runningSegmentStartedAt = null;

        _activeSubjectId = '';
        _activeSubjectName = '';
      });
    } catch (error) {
      debugPrint('공부시간 저장 오류: $error');

      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;

        if (!_isPaused) {
          _runningSegmentStartedAt = DateTime.now();
        }
      });

      if (!_isPaused) {
        _startLocalTimer();
      }

      _showMessage('공부시간을 저장하지 못했습니다. 타이머는 계속 유지됩니다.');
    }
  }

  Future<bool> _onWillPop() async {
    if (!_isSessionActive) {
      return true;
    }

    bool? shouldStop = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: context.colors.surface,
          surfaceTintColor: Colors.transparent,
          shape: appDialogShape,
          title: AppDialogTitle(
            icon: Icons.stop_circle_outlined,
            title: '공부를 종료할까요?',
          ),
          content: Text('현재 공부시간을 저장한 뒤 스터디방으로 돌아갑니다.'),
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

    return !_isSessionActive;
  }

  Future<void> _showSubjectDialog({
    String subjectId = '',
    String currentName = '',
  }) async {
    bool isEdit = subjectId.isNotEmpty;

    String? subjectName = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return _StudySubjectDialog(
          title: isEdit ? '과목 수정' : '과목 추가',
          actionText: isEdit ? '수정' : '추가',
          initialName: currentName,
        );
      },
    );

    if (subjectName == null || !mounted) {
      return;
    }

    CollectionReference<Map<String, dynamic>>? subjectCollection =
        _getSubjectCollection();

    if (subjectCollection == null) {
      _showMessage('로그인 정보가 없습니다.');
      return;
    }

    try {
      if (isEdit) {
        await subjectCollection.doc(subjectId).update({
          'name': subjectName,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        QuerySnapshot<Map<String, dynamic>> subjectSnapshot =
            await subjectCollection.get();

        await subjectCollection.add({
          'name': subjectName,
          'order': subjectSnapshot.docs.length,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) {
        return;
      }

      _showMessage(isEdit ? '과목명이 수정되었습니다.' : '과목이 추가되었습니다.');
    } catch (error) {
      debugPrint('과목 저장 오류: $error');

      if (!mounted) {
        return;
      }

      _showMessage('과목을 저장하지 못했습니다.');
    }
  }

  Future<void> _deleteSubject(String subjectId, String subjectName) async {
    if (_isSessionActive && _activeSubjectId == subjectId) {
      _showMessage('현재 공부 중인 과목은 삭제할 수 없습니다.');
      return;
    }

    bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: context.colors.surface,
          surfaceTintColor: Colors.transparent,
          shape: appDialogShape,
          title: AppDialogTitle(
            icon: Icons.delete_outline,
            title: '과목 삭제',
            isDestructive: true,
          ),
          content: Text(
            '$subjectName 과목을 삭제할까요?\n'
            '기존 공부 기록은 삭제되지 않습니다.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.incorrect,
                foregroundColor: context.colors.onPrimary,
              ),
              child: Text('삭제'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    CollectionReference<Map<String, dynamic>>? subjectCollection =
        _getSubjectCollection();

    if (subjectCollection == null) {
      _showMessage('로그인 정보가 없습니다.');
      return;
    }

    try {
      await subjectCollection.doc(subjectId).delete();

      _showMessage('과목이 삭제되었습니다.');
    } catch (error) {
      debugPrint('과목 삭제 오류: $error');

      _showMessage('과목을 삭제하지 못했습니다.');
    }
  }

  Future<void> _showPomodoroSettings() async {
    Map<String, int>? result = await showDialog<Map<String, int>>(
      context: context,
      builder: (dialogContext) {
        return _PomodoroSettingsDialog(
          initialStudyMinutes: _pomodoroStudyMinutes,
          initialRestMinutes: _pomodoroRestMinutes,
        );
      },
    );

    if (result == null || !mounted) {
      return;
    }

    setState(() {
      _pomodoroStudyMinutes = result['studyMinutes'] ?? 25;

      _pomodoroRestMinutes = result['restMinutes'] ?? 5;
    });
  }

  Map<String, int> _createTodaySubjectSecondsMap(
    QuerySnapshot<Map<String, dynamic>> recordSnapshot,
    String uid,
  ) {
    Map<String, int> result = {};

    for (int i = 0; i < recordSnapshot.docs.length; i++) {
      Map<String, dynamic> recordData = recordSnapshot.docs[i].data();

      String recordUid = recordData['uid']?.toString() ?? '';

      if (recordUid != uid) {
        continue;
      }

      String subjectId = recordData['subjectId']?.toString() ?? '';

      String subjectName = recordData['subject']?.toString() ?? '';

      String key = subjectId;

      if (key.isEmpty) {
        key = 'name:$subjectName';
      }

      int previousSeconds = result[key] ?? 0;

      result[key] = previousSeconds + _getRecordStudySeconds(recordData);
    }

    if (_isSessionActive) {
      String activeKey = _activeSubjectId;

      if (activeKey.isEmpty) {
        activeKey = 'name:$_activeSubjectName';
      }

      result[activeKey] = (result[activeKey] ?? 0) + _getCurrentStudySeconds();
    }

    return result;
  }

  int _getTodaySubjectSeconds(
    String subjectId,
    String subjectName,
    Map<String, int> todaySubjectSecondsMap,
  ) {
    int seconds = todaySubjectSecondsMap[subjectId] ?? 0;

    if (seconds == 0) {
      seconds = todaySubjectSecondsMap['name:$subjectName'] ?? 0;
    }

    return seconds;
  }

  int _getTodayTotalSeconds(Map<String, int> todaySubjectSecondsMap) {
    int totalSeconds = 0;

    todaySubjectSecondsMap.forEach((key, value) {
      totalSeconds += value;
    });

    return totalSeconds;
  }

  Widget _buildTodaySummary(int todayTotalSeconds, int totalStudySeconds) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [context.colors.lavender, context.colors.pinkSoft],
        ),
        borderRadius: BorderRadius.circular(26),
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
              color: context.colors.textPrimary,
            ),
          ),
          SizedBox(height: 6),
          Text(
            _isSessionActive
                ? '집중 상태와 공부시간이 스터디방에 실시간으로 표시됩니다.'
                : '타이머 방식을 선택한 뒤 과목의 시작 버튼을 눌러주세요.',
            style: TextStyle(fontSize: 12, color: context.colors.textSecondary),
          ),
          SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surface.withOpacity(0.86),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '오늘 공부시간',
                        style: TextStyle(
                          fontSize: 10,
                          color: context.colors.textSecondary,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        _formatCompactStudySeconds(todayTotalSeconds),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: context.colors.pinkStart,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surface.withOpacity(0.86),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '전체 누적시간',
                        style: TextStyle(
                          fontSize: 10,
                          color: context.colors.textSecondary,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        _formatCompactStudySeconds(
                          totalStudySeconds +
                              (_isSessionActive
                                  ? _getCurrentStudySeconds()
                                  : 0),
                        ),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: context.colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeOption({
    required String mode,
    required IconData icon,
    required String title,
    required String description,
  }) {
    bool isSelected = _timerMode == mode;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap: _isSessionActive || _isSaving
            ? null
            : () {
                setState(() {
                  _timerMode = mode;
                });
              },
        child: Container(
          padding: EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected
                ? context.colors.pinkSoft
                : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: isSelected
                  ? context.colors.pinkStart
                  : Theme.of(context).colorScheme.outlineVariant,
              width: isSelected ? 1.4 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 25,
                color: isSelected
                    ? context.colors.pinkStart
                    : context.colors.textSecondary,
              ),
              SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? context.colors.pinkStart
                      : context.colors.textPrimary,
                ),
              ),
              SizedBox(height: 4),
              Text(
                description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  height: 1.35,
                  color: context.colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimerModeSelector() {
    return AppCard(
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '타이머 방식',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: context.colors.textPrimary,
            ),
          ),
          SizedBox(height: 5),
          Text(
            '자유롭게 측정하거나 집중과 휴식을 반복할 수 있습니다.',
            style: TextStyle(fontSize: 11, color: context.colors.textSecondary),
          ),
          SizedBox(height: 14),
          Row(
            children: [
              _buildModeOption(
                mode: 'STOPWATCH',
                icon: Icons.timer_outlined,
                title: '스톱워치',
                description: '종료할 때까지 자유롭게 측정',
              ),
              SizedBox(width: 10),
              _buildModeOption(
                mode: 'POMODORO',
                icon: Icons.hourglass_bottom_rounded,
                title: '포모도로',
                description: '집중과 휴식을 자동 반복',
              ),
            ],
          ),
          if (_timerMode == 'POMODORO') ...[
            SizedBox(height: 12),
            InkWell(
              borderRadius: BorderRadius.circular(15),
              onTap: _isSessionActive || _isSaving
                  ? null
                  : _showPomodoroSettings,
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 13, vertical: 12),
                decoration: BoxDecoration(
                  color: context.colors.lavender,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.tune_rounded,
                      size: 20,
                      color: context.colors.pinkStart,
                    ),
                    SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        '집중 $_pomodoroStudyMinutes분 · '
                        '휴식 $_pomodoroRestMinutes분',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: context.colors.textPrimary,
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
          ],
        ],
      ),
    );
  }

  Widget _buildFocusMetric(IconData icon, String label, String value) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 11),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: context.colors.pinkStart),
            SizedBox(height: 6),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: context.colors.textPrimary,
              ),
            ),
            SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                color: context.colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTimerCard() {
    String statusText = '공부 중';

    Color statusBackground = context.colors.mint;

    Color statusTextColor = Theme.of(context).colorScheme.tertiary;

    IconData statusIcon = Icons.bolt_rounded;

    if (_isPaused) {
      statusText = '일시정지';
      statusBackground = Theme.of(context).colorScheme.outlineVariant;
      statusTextColor = context.colors.textSecondary;
      statusIcon = Icons.pause_rounded;
    } else if (_isResting) {
      statusText = '휴식 중';
      statusBackground = context.colors.softBlue;
      statusTextColor = Theme.of(context).colorScheme.secondaryContainer;
      statusIcon = Icons.self_improvement_rounded;
    }

    String timerText = _formatTimer(_getCurrentStudySeconds());

    String timerDescription = '현재 공부시간';

    if (_timerMode == 'POMODORO') {
      timerText = _formatTimer(_getPomodoroRemainingSeconds());

      timerDescription = _isResting ? '휴식 종료까지' : '집중 종료까지';
    }

    return AppCard(
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 13, vertical: 7),
            decoration: BoxDecoration(
              color: statusBackground,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcon, size: 16, color: statusTextColor),
                SizedBox(width: 6),
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 12,
                    color: statusTextColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 14),
          Text(
            _activeSubjectName,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: context.colors.textPrimary,
            ),
          ),
          SizedBox(height: 6),
          Text(
            _timerMode == 'POMODORO'
                ? '포모도로 · 집중 $_pomodoroStudyMinutes분 / '
                      '휴식 $_pomodoroRestMinutes분'
                : '스톱워치',
            style: TextStyle(fontSize: 11, color: context.colors.textSecondary),
          ),
          SizedBox(height: 17),
          Text(
            timerText,
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              color: context.colors.textPrimary,
            ),
          ),
          SizedBox(height: 5),
          Text(
            timerDescription,
            style: TextStyle(fontSize: 11, color: context.colors.textSecondary),
          ),
          SizedBox(height: 18),
          Row(
            children: [
              _buildFocusMetric(
                Icons.schedule_rounded,
                '공부시간',
                _formatCompactStudySeconds(_getCurrentStudySeconds()),
              ),
              SizedBox(width: 8),
              _buildFocusMetric(
                Icons.logout_rounded,
                '앱 이탈',
                '$_focusExitCount회',
              ),
              SizedBox(width: 8),
              _buildFocusMetric(
                Icons.psychology_rounded,
                '집중 점수',
                '${_getFocusScore()}점',
              ),
            ],
          ),
          if (_timerMode == 'POMODORO') ...[
            SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: context.colors.lavender,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.repeat_rounded,
                    size: 18,
                    color: context.colors.pinkStart,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '완료한 집중 '
                      '$_completedFocusRounds회 · '
                      '휴식 '
                      '${_formatCompactStudySeconds(_getCurrentRestSeconds())}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: context.colors.textPrimary,
                      ),
                    ),
                  ),
                  if (_isResting && !_isPaused)
                    TextButton(
                      onPressed: _skipRest,
                      child: Text(
                        '건너뛰기',
                        style: TextStyle(
                          fontSize: 11,
                          color: context.colors.pinkStart,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          SizedBox(height: 22),
          AppButton(
            text: _isPaused ? '다시 시작' : '일시정지',
            type: AppButtonType.outlinePink,
            height: 46,
            onPressed: _isSaving ? null : _togglePause,
          ),
          SizedBox(height: 10),
          AppButton(
            text: _isSaving ? '저장 중...' : '공부 종료',
            type: AppButtonType.primaryPink,
            height: 50,
            onPressed: _isSaving ? null : _stopStudy,
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectCard(
    QueryDocumentSnapshot<Map<String, dynamic>> subjectDocument,
    Map<String, int> todaySubjectSecondsMap,
  ) {
    Map<String, dynamic> subjectData = subjectDocument.data();

    String subjectName = subjectData['name']?.toString() ?? '과목';

    int todaySeconds = _getTodaySubjectSeconds(
      subjectDocument.id,
      subjectName,
      todaySubjectSecondsMap,
    );

    bool isActive = _isSessionActive && _activeSubjectId == subjectDocument.id;

    return Container(
      margin: EdgeInsets.only(bottom: 11),
      child: AppCard(
        backgroundColor: isActive
            ? context.colors.mint
            : Theme.of(context).colorScheme.surface,
        borderRadius: 20,
        padding: EdgeInsets.all(15),
        child: Row(
          children: [
            Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                color: isActive
                    ? Theme.of(context).colorScheme.surface
                    : context.colors.lavender,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                Icons.menu_book_rounded,
                color: isActive
                    ? Theme.of(context).colorScheme.tertiary
                    : context.colors.pinkStart,
              ),
            ),
            SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subjectName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    '오늘 '
                    '${_formatCompactStudySeconds(todaySeconds)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: context.colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              enabled: !_isSessionActive && !_isSaving,
              onSelected: (value) {
                if (value == 'edit') {
                  _showSubjectDialog(
                    subjectId: subjectDocument.id,
                    currentName: subjectName,
                  );
                }

                if (value == 'delete') {
                  _deleteSubject(subjectDocument.id, subjectName);
                }
              },
              itemBuilder: (context) {
                return [
                  PopupMenuItem(value: 'edit', child: Text('수정')),
                  PopupMenuItem(value: 'delete', child: Text('삭제')),
                ];
              },
            ),
            SizedBox(width: 3),
            InkWell(
              borderRadius: BorderRadius.circular(25),
              onTap: _isSessionActive || _isSaving
                  ? null
                  : () {
                      _startStudy(subjectDocument.id, subjectName);
                    },
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: isActive
                      ? Theme.of(context).colorScheme.tertiary
                      : context.colors.pinkStart,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isActive ? Icons.equalizer_rounded : Icons.play_arrow_rounded,
                  color: Theme.of(context).colorScheme.onPrimary,
                  size: 28,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectList(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> subjectList,
    Map<String, int> todaySubjectSecondsMap,
  ) {
    if (subjectList.isEmpty) {
      return AppEmptyView(
        message: '등록된 공부 과목이 없습니다.',
        description: '과목을 추가하고 공부시간을 기록해 보세요.',
        buttonText: '과목 추가',
        onButtonPressed: () {
          _showSubjectDialog();
        },
      );
    }

    return Column(
      children: [
        for (int i = 0; i < subjectList.length; i++)
          _buildSubjectCard(subjectList[i], todaySubjectSecondsMap),
      ],
    );
  }

  Widget _buildTimerPage(String uid, int totalStudySeconds) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _getSubjectStream(uid),
      builder: (context, subjectSnapshot) {
        if (subjectSnapshot.connectionState == ConnectionState.waiting) {
          return AppLoadingView(message: '공부 과목을 불러오는 중입니다.');
        }

        if (subjectSnapshot.hasError) {
          if (_isNetworkError(subjectSnapshot.error)) {
            return AppNetworkErrorView(
              message: '인터넷 연결을 확인해 주세요.',
              description: '네트워크 연결 후 공부 과목을 다시 불러와 주세요.',
              onRetryPressed: _reloadPage,
            );
          }

          return AppErrorView(
            message: '공부 과목을 불러오지 못했습니다.',
            description: '잠시 후 다시 시도해 주세요.',
            onRetryPressed: _reloadPage,
          );
        }

        List<QueryDocumentSnapshot<Map<String, dynamic>>> subjectList =
            subjectSnapshot.data?.docs.toList() ?? [];

        subjectList.sort((a, b) {
          int aOrder = 0;
          int bOrder = 0;

          dynamic aOrderValue = a.data()['order'];

          dynamic bOrderValue = b.data()['order'];

          if (aOrderValue is num) {
            aOrder = aOrderValue.toInt();
          }

          if (bOrderValue is num) {
            bOrder = bOrderValue.toInt();
          }

          return aOrder.compareTo(bOrder);
        });

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _getTodayRecordStream(),
          builder: (context, recordSnapshot) {
            if (recordSnapshot.connectionState == ConnectionState.waiting) {
              return AppLoadingView(message: '오늘의 공부 기록을 불러오는 중입니다.');
            }

            if (recordSnapshot.hasError) {
              if (_isNetworkError(recordSnapshot.error)) {
                return AppNetworkErrorView(
                  message: '인터넷 연결을 확인해 주세요.',
                  description: '네트워크 연결 후 오늘의 기록을 다시 불러와 주세요.',
                  onRetryPressed: _reloadPage,
                );
              }

              return AppErrorView(
                message: '오늘의 공부 기록을 불러오지 못했습니다.',
                description: '잠시 후 다시 시도해 주세요.',
                onRetryPressed: _reloadPage,
              );
            }

            QuerySnapshot<Map<String, dynamic>> todayRecordSnapshot =
                recordSnapshot.data!;

            Map<String, int> todaySubjectSecondsMap =
                _createTodaySubjectSecondsMap(todayRecordSnapshot, uid);

            int todayTotalSeconds = _getTodayTotalSeconds(
              todaySubjectSecondsMap,
            );

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
                    _buildTodaySummary(todayTotalSeconds, totalStudySeconds),
                    SizedBox(height: 18),
                    if (_isSessionActive)
                      _buildActiveTimerCard()
                    else
                      _buildTimerModeSelector(),
                    SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '공부 과목',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: context.colors.textPrimary,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                _isSessionActive
                                    ? '현재 타이머를 종료한 뒤 다른 과목을 시작할 수 있습니다.'
                                    : '오른쪽 시작 버튼을 누르면 선택한 방식으로 바로 시작됩니다.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: context.colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _isSessionActive || _isSaving
                              ? null
                              : () {
                                  _showSubjectDialog();
                                },
                          icon: Icon(Icons.add_rounded, size: 19),
                          label: Text('과목 추가'),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    _buildSubjectList(subjectList, todaySubjectSecondsMap),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return Scaffold(
        appBar: AppTopBar(title: '공부시간 기록'),
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
          actions: [
            IconButton(
              tooltip: '과목 추가',
              onPressed: _isSessionActive || _isSaving
                  ? null
                  : () {
                      _showSubjectDialog();
                    },
              icon: Icon(Icons.add_rounded),
            ),
          ],
        ),
        body: Stack(
          children: [
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _getMemberStream(currentUser.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return AppLoadingView(message: '공부시간 정보를 불러오는 중입니다.');
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
                  Map<String, dynamic> memberData = snapshot.data!.data() ?? {};

                  if (!memberData.containsKey('totalStudySeconds')) {
                    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
                      _migrateOldTotalStudyTime(currentUser.uid);
                    });
                  }

                  WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
                    _ensureDefaultSubjects(currentUser.uid);
                  });

                  totalStudySeconds = _getStoredTotalStudySeconds(memberData);

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

                  _restoreLiveStudy(memberData);
                }

                return _buildTimerPage(currentUser.uid, totalStudySeconds);
              },
            ),
            if (_isSaving) Positioned.fill(child: LoadingOverlay()),
          ],
        ),
      ),
    );
  }
}

class _StudySubjectDialog extends StatefulWidget {
  final String title;
  final String actionText;
  final String initialName;

  const _StudySubjectDialog({
    required this.title,
    required this.actionText,
    required this.initialName,
  });

  @override
  State<_StudySubjectDialog> createState() {
    return _StudySubjectDialogState();
  }
}

class _StudySubjectDialogState extends State<_StudySubjectDialog> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  String _errorText = '';

  @override
  void initState() {
    super.initState();

    _controller = TextEditingController(text: widget.initialName);

    _focusNode = FocusNode();

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _focusNode.unfocus();
    _focusNode.dispose();
    _controller.dispose();

    super.dispose();
  }

  void _closeDialog() {
    _focusNode.unfocus();

    Navigator.pop(context);
  }

  void _submitSubject() {
    String subjectName = _controller.text.trim();

    if (subjectName.isEmpty) {
      setState(() {
        _errorText = '과목명을 입력해 주세요.';
      });

      return;
    }

    _focusNode.unfocus();

    Navigator.pop(context, subjectName);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _focusNode.unfocus();

        return true;
      },
      child: AlertDialog(
        backgroundColor: context.colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: appDialogShape,
        title: AppDialogTitle(
          icon: Icons.menu_book_outlined,
          title: widget.title,
        ),
        content: TextField(
          controller: _controller,
          focusNode: _focusNode,
          maxLength: 30,
          textInputAction: TextInputAction.done,
          onSubmitted: (value) {
            _submitSubject();
          },
          onChanged: (value) {
            if (_errorText.isNotEmpty) {
              setState(() {
                _errorText = '';
              });
            }
          },
          decoration: InputDecoration(
            hintText: '예: 데이터베이스',
            counterText: '',
            errorText: _errorText.isEmpty ? null : _errorText,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        actions: [
          TextButton(onPressed: _closeDialog, child: Text('취소')),
          ElevatedButton(
            onPressed: _submitSubject,
            child: Text(widget.actionText),
          ),
        ],
      ),
    );
  }
}

class _PomodoroSettingsDialog extends StatefulWidget {
  final int initialStudyMinutes;
  final int initialRestMinutes;

  const _PomodoroSettingsDialog({
    required this.initialStudyMinutes,
    required this.initialRestMinutes,
  });

  @override
  State<_PomodoroSettingsDialog> createState() {
    return _PomodoroSettingsDialogState();
  }
}

class _PomodoroSettingsDialogState extends State<_PomodoroSettingsDialog> {
  late int _studyMinutes;
  late int _restMinutes;

  @override
  void initState() {
    super.initState();

    _studyMinutes = widget.initialStudyMinutes;

    _restMinutes = widget.initialRestMinutes;
  }

  Widget _buildMinuteSelector({
    required String title,
    required String description,
    required int value,
    required VoidCallback? onMinus,
    required VoidCallback? onPlus,
  }) {
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: context.colors.textPrimary,
            ),
          ),
          SizedBox(height: 3),
          Text(
            description,
            style: TextStyle(fontSize: 10, color: context.colors.textSecondary),
          ),
          SizedBox(height: 12),
          Row(
            children: [
              IconButton(
                onPressed: onMinus,
                icon: Icon(Icons.remove_circle_outline),
              ),
              Expanded(
                child: Container(
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: context.colors.lavender,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Text(
                    '$value분',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: context.colors.pinkStart,
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: onPlus,
                icon: Icon(Icons.add_circle_outline),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.colors.surface,
      surfaceTintColor: Colors.transparent,
      shape: appDialogShape,
      title: AppDialogTitle(icon: Icons.tune_rounded, title: '포모도로 시간 설정'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildMinuteSelector(
              title: '집중 시간',
              description: '5분부터 120분까지 설정할 수 있습니다.',
              value: _studyMinutes,
              onMinus: _studyMinutes > 5
                  ? () {
                      setState(() {
                        _studyMinutes -= 5;
                      });
                    }
                  : null,
              onPlus: _studyMinutes < 120
                  ? () {
                      setState(() {
                        _studyMinutes += 5;
                      });
                    }
                  : null,
            ),
            SizedBox(height: 12),
            _buildMinuteSelector(
              title: '휴식 시간',
              description: '1분부터 30분까지 설정할 수 있습니다.',
              value: _restMinutes,
              onMinus: _restMinutes > 1
                  ? () {
                      setState(() {
                        _restMinutes--;
                      });
                    }
                  : null,
              onPlus: _restMinutes < 30
                  ? () {
                      setState(() {
                        _restMinutes++;
                      });
                    }
                  : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: Text('취소'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context, {
              'studyMinutes': _studyMinutes,
              'restMinutes': _restMinutes,
            });
          },
          child: Text('적용'),
        ),
      ],
    );
  }
}
