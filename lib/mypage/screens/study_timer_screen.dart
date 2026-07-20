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

      if (!mounted) {
        return;
      }

      setState(() {
        _goalOptions = goals;
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasStarted,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }

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
            padding: const EdgeInsets.fromLTRB(
              20,
              24,
              20,
              80,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppCard(
                  child: Column(
                    children: [
                      const Icon(
                        Icons.timer_outlined,
                        size: 34,
                        color: Color(0xFFF0788F),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        _formattedTime,
                        style: const TextStyle(
                          fontSize: 44,
                          height: 1,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        !_hasStarted
                            ? '준비'
                            : (_isRunning ? '공부 중' : '일시정지'),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF777B84),
                        ),
                      ),
                      const SizedBox(height: 28),
                      if (!_hasStarted)
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton.icon(
                            onPressed: _startTimer,
                            icon: const Icon(
                              Icons.play_arrow_rounded,
                            ),
                            label: const Text(
                              '시작',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                              const Color(0xFFF0788F),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                BorderRadius.circular(18),
                              ),
                            ),
                          ),
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 52,
                                child: OutlinedButton.icon(
                                  onPressed: _isRunning
                                      ? _pauseTimer
                                      : _resumeTimer,
                                  icon: Icon(
                                    _isRunning
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                  ),
                                  label: Text(
                                    _isRunning ? '일시정지' : '재개',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor:
                                    const Color(0xFFF0788F),
                                    side: const BorderSide(
                                      color: Color(0xFFF0788F),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                      BorderRadius.circular(16),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SizedBox(
                                height: 52,
                                child: ElevatedButton.icon(
                                  onPressed:
                                  _isSaving ? null : _finishTimer,
                                  icon: const Icon(
                                    Icons.stop_rounded,
                                  ),
                                  label: Text(
                                    _isSaving ? '저장 중...' : '종료',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                    const Color(0xFFF0788F),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                      BorderRadius.circular(16),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '학습 내용',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A1A),
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
                          if (value == null) {
                            return;
                          }

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
                        Text(
                          _goalLoadError!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.red,
                          ),
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

                      const SizedBox(height: 16),

                      DropdownButtonFormField<String>(
                        value: _selectedStudyType,
                        isExpanded: true,
                        decoration: _inputDecoration(
                          label: '학습 유형',
                          hint: '학습 유형을 선택하세요.',
                          icon: Icons.category_outlined,
                        ),
                        items: _studyTypes
                            .map(
                              (type) => DropdownMenuItem<String>(
                            value: type.code,
                            child: Text(type.name),
                          ),
                        )
                            .toList(),
                        onChanged: _isSaving
                            ? null
                            : (value) {
                          if (value == null) {
                            return;
                          }

                          setState(() {
                            _selectedStudyType = value;
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      TextField(
                        controller: _subjectController,
                        enabled: !_isSaving,
                        maxLength: 50,
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
                ),
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
      fillColor: Colors.white,
      prefixIcon: Icon(
        icon,
        color: const Color(0xFF9AA0AC),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color(0xFFE8E8EC),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color(0xFFE8E8EC),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
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
