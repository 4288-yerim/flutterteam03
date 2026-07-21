import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../widgets/app_card.dart';
import '../../widgets/app_main_background.dart';
import '../../widgets/app_top_bar.dart';

class StudyTimerScreen extends StatefulWidget {
  const StudyTimerScreen({super.key});

  @override
  State<StudyTimerScreen> createState() =>
      _StudyTimerScreenState();
}

class _StudyTimerScreenState extends State<StudyTimerScreen>
    with WidgetsBindingObserver {
  final TextEditingController _subjectController =
  TextEditingController();
  final TextEditingController _memoController =
  TextEditingController();

  static const String _freeStudyValue = '__FREE_STUDY__';

  final List<_StudyTypeOption> _studyTypes = const [
    _StudyTypeOption(code: 'THEORY', name: '이론 학습'),
    _StudyTypeOption(code: 'PRACTICE', name: '문제 풀이'),
    _StudyTypeOption(code: 'REVIEW', name: '복습'),
    _StudyTypeOption(code: 'LECTURE', name: '강의 수강'),
    _StudyTypeOption(code: 'OTHER', name: '기타'),
  ];

  List<_GoalOption> _goalOptions = [];
  String _selectedGoalValue = _freeStudyValue;
  String _selectedStudyType = 'THEORY';
  bool _isLoadingGoals = true;
  String? _goalLoadError;

  Timer? _displayTimer;
  DateTime? _startedAt;
  DateTime? _runningStartedAt;

  Duration _savedElapsed = Duration.zero;

  bool _isRunning = false;
  bool _hasStarted = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadGoalOptions();
  }

  Future<void> _loadGoalOptions() async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          _isLoadingGoals = false;
          _goalLoadError = '로그인 정보를 확인할 수 없습니다.';
        });
      }
      return;
    }

    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot =
      await FirebaseFirestore.instance
          .collection('userGoals')
          .doc(user.uid)
          .collection('goals')
          .get();

      final DocumentSnapshot<Map<String, dynamic>> userSnapshot =
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final List<_GoalOption> goals = [];

      for (final QueryDocumentSnapshot<Map<String, dynamic>> document
      in snapshot.docs) {
        final Map<String, dynamic> data = document.data();

        final String goalStatus =
        (data['goalStatus'] as String? ?? '').trim();

        if (goalStatus == 'DELETED') {
          continue;
        }

        final String certificateId =
        (data['certificateId'] as String? ?? '').trim();
        final String certificateName =
        (data['certificateName'] as String? ?? '').trim();

        if (certificateId.isEmpty || certificateName.isEmpty) {
          continue;
        }

        goals.add(
          _GoalOption(
            certificateId: certificateId,
            certificateName: certificateName,
          ),
        );
      }

      final String primaryGoalCertificateId =
      (userSnapshot.data()?['goalCertificateId'] as String? ?? '')
          .trim();

      if (primaryGoalCertificateId.isNotEmpty &&
          !goals.any(
                (goal) => goal.certificateId == primaryGoalCertificateId,
          )) {
        final DocumentSnapshot<Map<String, dynamic>> certificateSnapshot =
        await FirebaseFirestore.instance
            .collection('certificates')
            .doc(primaryGoalCertificateId)
            .get();

        final Map<String, dynamic> certificateData =
            certificateSnapshot.data() ?? <String, dynamic>{};
        final String certificateName =
        (certificateData['certificateName'] ??
            certificateData['name'] ??
            certificateData['title'] ??
            primaryGoalCertificateId.toUpperCase())
            .toString()
            .trim();

        goals.add(
          _GoalOption(
            certificateId: primaryGoalCertificateId,
            certificateName: certificateName.isEmpty
                ? primaryGoalCertificateId.toUpperCase()
                : certificateName,
          ),
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _goalOptions = goals;
        if (primaryGoalCertificateId.isNotEmpty &&
            goals.any(
                  (goal) => goal.certificateId == primaryGoalCertificateId,
            )) {
          _selectedGoalValue = primaryGoalCertificateId;
        } else if (_selectedGoalValue != _freeStudyValue &&
            !goals.any(
                  (goal) => goal.certificateId == _selectedGoalValue,
            )) {
          _selectedGoalValue = _freeStudyValue;
        }
        _isLoadingGoals = false;
        _goalLoadError = null;
      });

    } on FirebaseException {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingGoals = false;
        _goalLoadError = '목표 자격증을 불러오지 못했습니다.';
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _displayTimer?.cancel();
    _subjectController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 화면 표시 시간은 DateTime 차이로 계산하므로 앱이 백그라운드에
    // 다녀와도 실제 경과 시간이 유지됩니다.
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() {});
    }
  }

  Duration get _currentElapsed {
    if (!_isRunning || _runningStartedAt == null) {
      return _savedElapsed;
    }

    return _savedElapsed +
        DateTime.now().difference(_runningStartedAt!);
  }

  String get _formattedTime {
    final int totalSeconds = _currentElapsed.inSeconds;
    final int hours = totalSeconds ~/ 3600;
    final int minutes = (totalSeconds % 3600) ~/ 60;
    final int seconds = totalSeconds % 60;

    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  void _startTimer() {
    if (_isRunning) {
      return;
    }

    setState(() {
      _hasStarted = true;
      _isRunning = true;
      _startedAt ??= DateTime.now();
      _runningStartedAt = DateTime.now();
    });

    _displayTimer?.cancel();
    _displayTimer = Timer.periodic(
      const Duration(seconds: 1),
          (_) {
        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  void _pauseTimer() {
    if (!_isRunning || _runningStartedAt == null) {
      return;
    }

    setState(() {
      _savedElapsed +=
          DateTime.now().difference(_runningStartedAt!);
      _runningStartedAt = null;
      _isRunning = false;
    });

    _displayTimer?.cancel();
  }

  void _resumeTimer() {
    _startTimer();
  }

  Future<void> _finishTimer() async {
    if (!_hasStarted) {
      return;
    }

    if (_isRunning) {
      _pauseTimer();
    }

    final int elapsedSeconds = _savedElapsed.inSeconds;

    if (elapsedSeconds <= 0) {
      _showMessage('저장할 공부 시간이 없습니다.');
      return;
    }

    final bool? shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text(
            '공부 종료',
            style: TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            '${_formatDurationForMessage(_savedElapsed)} 동안 공부했습니다.\n'
                '학습 기록에 저장할까요?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text(
                '계속 공부',
                style: TextStyle(
                  color: Color(0xFF777B84),
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text(
                '저장',
                style: TextStyle(
                  color: Color(0xFFF0788F),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (shouldSave != true) {
      return;
    }

    await _saveStudyRecord(elapsedSeconds);
  }

  Future<void> _saveStudyRecord(int elapsedSeconds) async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage('로그인 정보를 확인할 수 없습니다.');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final DateTime endedAt = DateTime.now();
      final DateTime startedAt =
          _startedAt ?? endedAt.subtract(_savedElapsed);
      final String dateId = _formatDateId(endedAt);

      final _GoalOption? selectedGoal =
      _selectedGoalValue == _freeStudyValue
          ? null
          : _goalOptions.cast<_GoalOption?>().firstWhere(
            (goal) =>
        goal?.certificateId == _selectedGoalValue,
        orElse: () => null,
      );

      final _StudyTypeOption selectedStudyType =
      _studyTypes.firstWhere(
            (type) => type.code == _selectedStudyType,
      );

      final DocumentReference<Map<String, dynamic>> dailyDocument =
      FirebaseFirestore.instance
          .collection('userStudyLogs')
          .doc(user.uid)
          .collection('logs')
          .doc(dateId);

      final DocumentReference<Map<String, dynamic>> sessionDocument =
      dailyDocument.collection('sessions').doc();

      await FirebaseFirestore.instance.runTransaction(
            (transaction) async {
          final DocumentSnapshot<Map<String, dynamic>> dailySnapshot =
          await transaction.get(dailyDocument);

          final int previousTotalSeconds =
              (dailySnapshot.data()?['totalSeconds'] as num?)
                  ?.toInt() ??
                  0;

          final int newTotalSeconds =
              previousTotalSeconds + elapsedSeconds;

          transaction.set(
            dailyDocument,
            {
              'date': dateId,
              'totalSeconds': newTotalSeconds,
              'totalMinutes': newTotalSeconds ~/ 60,
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );

          transaction.set(
            sessionDocument,
            {
              'certificateId': selectedGoal?.certificateId,
              'certificateName':
              selectedGoal?.certificateName ?? '자유 학습',
              'studyType': selectedStudyType.code,
              'studyTypeName': selectedStudyType.name,
              'subject': _subjectController.text.trim().isEmpty
                  ? selectedStudyType.name
                  : _subjectController.text.trim(),
              'memo': _memoController.text.trim(),
              'startedAt': Timestamp.fromDate(startedAt),
              'endedAt': Timestamp.fromDate(endedAt),
              'durationSeconds': elapsedSeconds,
              'durationMinutes': elapsedSeconds ~/ 60,
              'createdAt': FieldValue.serverTimestamp(),
            },
          );
        },
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('학습 시간이 저장되었습니다.'),
        ),
      );

      Navigator.pop(context, true);
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }

      String message = '학습 기록 저장에 실패했습니다.';

      if (error.code == 'permission-denied') {
        message = '학습 기록을 저장할 권한이 없습니다.';
      }

      _showMessage(message);
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage('학습 기록 저장 중 오류가 발생했습니다.');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String _formatDateId(DateTime date) {
    final String month =
    date.month.toString().padLeft(2, '0');
    final String day =
    date.day.toString().padLeft(2, '0');

    return '${date.year}-$month-$day';
  }

  String _formatDurationForMessage(Duration duration) {
    final int hours = duration.inHours;
    final int minutes = duration.inMinutes.remainder(60);
    final int seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours시간 $minutes분 $seconds초';
    }

    if (minutes > 0) {
      return '$minutes분 $seconds초';
    }

    return '$seconds초';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  Future<bool> _confirmExit() async {
    if (!_hasStarted || _currentElapsed.inSeconds <= 0) {
      return true;
    }

    final bool? shouldExit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text(
            '타이머 종료',
            style: TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
          content: const Text(
            '저장하지 않고 나가면 측정한 시간이 사라집니다.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text(
                '취소',
                style: TextStyle(
                  color: Color(0xFF777B84),
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text(
                '나가기',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );

    return shouldExit == true;
  }

  String get _selectedGoalName {
    if (_selectedGoalValue == _freeStudyValue) return '자유 학습';

    for (final _GoalOption goal in _goalOptions) {
      if (goal.certificateId == _selectedGoalValue) {
        return goal.certificateName;
      }
    }

    return '자유 학습';
  }

  String get _selectedStudyTypeName {
    return _studyTypes
        .firstWhere((type) => type.code == _selectedStudyType)
        .name;
  }

  String get _currentSubjectName {
    final String subject = _subjectController.text.trim();
    return subject.isEmpty ? _selectedStudyTypeName : subject;
  }

  IconData _studyTypeIcon(String code) {
    return switch (code) {
      'PRACTICE' => Icons.edit_note_rounded,
      'REVIEW' => Icons.replay_rounded,
      'LECTURE' => Icons.play_circle_outline_rounded,
      'OTHER' => Icons.notes_rounded,
      _ => Icons.menu_book_outlined,
    };
  }

  Widget _buildMetaTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 13,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.86),
          borderRadius: BorderRadius.circular(17),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 19,
              color: const Color(0xFFF0788F),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF9AA0AC),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A),
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

  Widget _buildTimerHero() {
    final String statusText = !_hasStarted
        ? '시작 전'
        : (_isRunning ? '공부 중' : '일시정지');
    final IconData statusIcon = !_hasStarted
        ? Icons.hourglass_empty_rounded
        : (_isRunning ? Icons.bolt_rounded : Icons.pause_rounded);
    final Color statusBackground = !_hasStarted
        ? const Color(0xFFFFE8EE)
        : (_isRunning
        ? const Color(0xFFE8F7F1)
        : const Color(0xFFEDEAF7));
    final Color statusColor = !_hasStarted
        ? const Color(0xFFF0788F)
        : (_isRunning
        ? const Color(0xFF4FAE8E)
        : const Color(0xFF777B84));

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFEDF2),
            Color(0xFFF1EEFF),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF0788F).withOpacity(0.10),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.88),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.timer_outlined,
                  color: Color(0xFFF0788F),
                  size: 25,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '개인 학습 타이머',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      '내 페이스대로 공부시간을 기록해요.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF777B84),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: statusBackground,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 15, color: statusColor),
                    const SizedBox(width: 5),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _buildMetaTile(
                icon: Icons.workspace_premium_outlined,
                label: '목표 자격증',
                value: _selectedGoalName,
              ),
              const SizedBox(width: 10),
              _buildMetaTile(
                icon: _studyTypeIcon(_selectedStudyType),
                label: '학습 유형',
                value: _selectedStudyTypeName,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            _currentSubjectName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _formattedTime,
            style: const TextStyle(
              fontSize: 48,
              height: 1,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            '측정된 공부 시간',
            style: TextStyle(
              fontSize: 11,
              color: Color(0xFF777B84),
            ),
          ),
          const SizedBox(height: 22),
          if (!_hasStarted)
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _startTimer,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text(
                  '공부 시작',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF0788F),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(17),
                  ),
                ),
              ),
            )
          else ...[
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _isSaving
                    ? null
                    : (_isRunning ? _pauseTimer : _resumeTimer),
                icon: Icon(
                  _isRunning
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                ),
                label: Text(
                  _isRunning ? '일시정지' : '다시 시작',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFF0788F),
                  side: const BorderSide(color: Color(0xFFF0788F)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _finishTimer,
                icon: const Icon(Icons.stop_rounded),
                label: Text(
                  _isSaving ? '저장 중...' : '공부 종료',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF0788F),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStudyTypeOption(
      _StudyTypeOption type,
      double width,
      ) {
    final bool isSelected = _selectedStudyType == type.code;

    return SizedBox(
      width: width,
      child: InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap: _isSaving
            ? null
            : () {
          setState(() {
            _selectedStudyType = type.code;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 14,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFFFFEDF2)
                : const Color(0xFFFFFDFD),
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFFF0788F)
                  : const Color(0xFFE8E8EC),
              width: isSelected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                _studyTypeIcon(type.code),
                size: 21,
                color: isSelected
                    ? const Color(0xFFF0788F)
                    : const Color(0xFF9AA0AC),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  type.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                    isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected
                        ? const Color(0xFFF0788F)
                        : const Color(0xFF1A1A1A),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStudyContentCard() {
    return AppCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.tune_rounded,
                color: Color(0xFFF0788F),
                size: 23,
              ),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  '학습 내용 설정',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          const Text(
            '기록에서 구분하기 쉽도록 학습 내용을 선택해 주세요.',
            style: TextStyle(
              fontSize: 11,
              color: Color(0xFF9AA0AC),
            ),
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<String>(
            value: _selectedGoalValue,
            isExpanded: true,
            decoration: _inputDecoration(
              label: '목표 자격증',
              hint: '공부할 자격증을 선택하세요.',
              icon: Icons.workspace_premium_outlined,
            ),
            items: [
              const DropdownMenuItem<String>(
                value: _freeStudyValue,
                child: Text('자유 학습'),
              ),
              ..._goalOptions.map(
                    (goal) => DropdownMenuItem<String>(
                  value: goal.certificateId,
                  child: Text(
                    goal.certificateName,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
            onChanged: _isSaving || _isLoadingGoals
                ? null
                : (value) {
              if (value == null) return;
              setState(() {
                _selectedGoalValue = value;
              });
            },
          ),
          if (_isLoadingGoals) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(
              minHeight: 2,
              color: Color(0xFFF0788F),
              backgroundColor: Color(0xFFFFE8EE),
            ),
            const SizedBox(height: 6),
            const Text(
              '목표 자격증을 불러오는 중입니다.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF9AA0AC),
              ),
            ),
          ] else if (_goalLoadError != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _goalLoadError!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.red,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isLoadingGoals = true;
                      _goalLoadError = null;
                    });
                    _loadGoalOptions();
                  },
                  child: const Text('다시 시도'),
                ),
              ],
            ),
          ] else if (_goalOptions.isEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              '등록된 목표 자격증이 없어 자유 학습으로 기록됩니다.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF9AA0AC),
              ),
            ),
          ],
          const SizedBox(height: 20),
          const Text(
            '학습 유형',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final double itemWidth = (constraints.maxWidth - 10) / 2;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _studyTypes
                    .map((type) => _buildStudyTypeOption(type, itemWidth))
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _subjectController,
            enabled: !_isSaving,
            maxLength: 50,
            onChanged: (_) => setState(() {}),
            decoration: _inputDecoration(
              label: '세부 학습 내용',
              hint: '예: 데이터베이스 정규화 복습',
              icon: Icons.menu_book_outlined,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _memoController,
            enabled: !_isSaving,
            minLines: 3,
            maxLines: 5,
            maxLength: 150,
            decoration: _inputDecoration(
              label: '학습 메모',
              hint: '어려웠던 점이나 다음에 할 일을 적어주세요.',
              icon: Icons.edit_note_outlined,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasStarted,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final bool shouldExit = await _confirmExit();
        if (shouldExit && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppTopBar(
          title: '공부 타이머',
          leading: IconButton(
            onPressed: () async {
              final bool shouldExit = await _confirmExit();
              if (shouldExit && context.mounted) {
                Navigator.pop(context);
              }
            },
            icon: const Icon(
              Icons.arrow_back_ios_new,
              size: 20,
              color: Color(0xFF1A1A1A),
            ),
          ),
        ),
        body: AppMainBackground(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 80),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTimerHero(),
                const SizedBox(height: 20),
                _buildStudyContentCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFFFFDFD),
      prefixIcon: Icon(
        icon,
        color: const Color(0xFF9AA0AC),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 15,
        vertical: 16,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE8E8EC)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE8E8EC)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Color(0xFFF0788F),
          width: 1.5,
        ),
      ),
    );
  }
}


class _GoalOption {
  final String certificateId;
  final String certificateName;

  const _GoalOption({
    required this.certificateId,
    required this.certificateName,
  });
}

class _StudyTypeOption {
  final String code;
  final String name;

  const _StudyTypeOption({
    required this.code,
    required this.name,
  });
}
