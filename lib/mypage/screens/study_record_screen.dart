import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../widgets/app_card.dart';
import '../../widgets/app_main_background.dart';
import '../../widgets/app_top_bar.dart';
import 'study_timer_screen.dart';

class StudyRecordScreen extends StatefulWidget {
  const StudyRecordScreen({super.key});

  @override
  State<StudyRecordScreen> createState() => _StudyRecordScreenState();
}

class _StudyRecordScreenState extends State<StudyRecordScreen> {
  int _selectedPeriodIndex = 0;
  int _selectedSourceIndex = 0;

  DateTime _focusedDate = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );

  final List<String> _periodNames = ['주간', '월간', '전체'];
  final List<String> _sourceNames = ['전체', '개인', '스터디'];

  List<_StudyRecordData> _studyRecords = [];
  bool _isLoadingRecords = true;
  String? _recordLoadError;

  @override
  void initState() {
    super.initState();
    _loadStudyRecords();
  }

  Future<void> _loadStudyRecords() async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (!mounted) return;
      setState(() {
        _studyRecords = [];
        _isLoadingRecords = false;
        _recordLoadError = '로그인 정보를 확인할 수 없습니다.';
      });
      return;
    }

    if (mounted) {
      setState(() {
        _isLoadingRecords = true;
        _recordLoadError = null;
      });
    }

    try {
      final QuerySnapshot<Map<String, dynamic>> dailySnapshot =
      await FirebaseFirestore.instance
          .collection('userStudyLogs')
          .doc(user.uid)
          .collection('logs')
          .get();

      final List<List<_StudyRecordData>> personalRecordsByDate =
      await Future.wait(
        dailySnapshot.docs.map(_loadDailySessionRecords),
      );

      final List<_StudyRecordData> personalRecords =
      personalRecordsByDate.expand((records) => records).toList();

      final List<_StudyRecordData> studyGroupRecords =
      await _loadStudyGroupRecords(user.uid);

      final List<_StudyRecordData> loadedRecords = [
        ...personalRecords,
        ...studyGroupRecords,
      ]..sort((a, b) => b.studiedAt.compareTo(a.studiedAt));

      if (!mounted) return;
      if (FirebaseAuth.instance.currentUser?.uid != user.uid) return;

      setState(() {
        _studyRecords = loadedRecords;
        _isLoadingRecords = false;
        _recordLoadError = null;
      });
    } catch (error) {
      debugPrint('통합 학습 기록 불러오기 오류: $error');

      if (!mounted) return;
      setState(() {
        _studyRecords = [];
        _isLoadingRecords = false;
        _recordLoadError = '학습 기록을 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.';
      });
    }
  }

  Future<List<_StudyRecordData>> _loadStudyGroupRecords(
      String userUid,
      ) async {
    final QuerySnapshot<Map<String, dynamic>> groupSnapshot =
    await FirebaseFirestore.instance
        .collection('studyGroups')
        .get();

    final List<_StudyRecordData> records = [];

    for (final QueryDocumentSnapshot<Map<String, dynamic>> groupDocument
    in groupSnapshot.docs) {
      final Map<String, dynamic> groupData = groupDocument.data();

      String groupName =
      (groupData['groupName'] as String? ?? '').trim();

      if (groupName.isEmpty) {
        groupName = '스터디 그룹';
      }

      final QuerySnapshot<Map<String, dynamic>> recordSnapshot =
      await groupDocument.reference
          .collection('studyRecords')
          .where('uid', isEqualTo: userUid)
          .get();

      for (final QueryDocumentSnapshot<Map<String, dynamic>> recordDocument
      in recordSnapshot.docs) {
        final Map<String, dynamic> data = recordDocument.data();

        final int studySeconds = _readStudyGroupSeconds(data);
        if (studySeconds <= 0) {
          continue;
        }

        final DateTime? studiedAt = _readStudyGroupDate(data);
        if (studiedAt == null) {
          continue;
        }

        String subject =
        (data['subject'] as String? ?? '').trim();

        if (subject.isEmpty) {
          subject =
              (data['studySubject'] as String? ?? '').trim();
        }

        if (subject.isEmpty) {
          subject = '전체 공부';
        }

        final String timerMode =
        (data['timerMode'] as String? ?? '').trim().toUpperCase();

        final String timerModeText =
        timerMode == 'POMODORO' ? '뽀모도로' : '스톱워치';

        records.add(
          _StudyRecordData(
            studiedAt: studiedAt,
            subject: subject,
            description: '$groupName · $timerModeText',
            minutes: studySeconds ~/ 60,
            seconds: studySeconds,
            icon: Icons.groups_2_outlined,
            source: 'STUDY',
            groupName: groupName,
            certificateName: '',
            studyTypeName: timerModeText,
            memo: '',
          ),
        );
      }
    }

    return records;
  }

  int _readStudyGroupSeconds(Map<String, dynamic> data) {
    final dynamic studySeconds = data['studySeconds'];

    if (studySeconds is num) {
      return studySeconds.toInt();
    }

    final dynamic elapsedSeconds = data['elapsedSeconds'];

    if (elapsedSeconds is num) {
      return elapsedSeconds.toInt();
    }

    final dynamic studyMinutes = data['studyMinutes'];

    if (studyMinutes is num) {
      return studyMinutes.toInt() * 60;
    }

    return 0;
  }

  DateTime? _readStudyGroupDate(Map<String, dynamic> data) {
    for (final String fieldName in [
      'endedAt',
      'startedAt',
      'createdAt',
    ]) {
      final dynamic value = data[fieldName];

      if (value is Timestamp) {
        return value.toDate();
      }
    }

    final dynamic studyDate = data['studyDate'];

    if (studyDate is String && studyDate.trim().isNotEmpty) {
      return DateTime.tryParse(studyDate.trim());
    }

    return null;
  }

  Future<List<_StudyRecordData>> _loadDailySessionRecords(
      QueryDocumentSnapshot<Map<String, dynamic>> dailyDocument,
      ) async {
    final Map<String, dynamic> dailyData = dailyDocument.data();
    final DateTime fallbackDate = _readDailyDate(
      dailyData['date'],
      dailyDocument.id,
    );

    final QuerySnapshot<Map<String, dynamic>> sessionSnapshot =
    await dailyDocument.reference.collection('sessions').get();

    if (sessionSnapshot.docs.isEmpty) {
      final int totalSeconds =
          (dailyData['totalSeconds'] as num?)?.toInt() ??
              ((dailyData['totalMinutes'] as num?)?.toInt() ?? 0) * 60;

      final int totalMinutes = totalSeconds ~/ 60;

      if (totalSeconds <= 0) return [];

      return [
        _StudyRecordData(
          studiedAt: fallbackDate,
          subject: '학습 기록',
          description: '해당 날짜의 총 학습 시간',
          minutes: totalMinutes,
          seconds: totalSeconds,
          icon: Icons.timer_outlined,
          source: 'PERSONAL',
          groupName: null,
          certificateName: '자유 학습',
          studyTypeName: '학습 기록',
          memo: '',
        ),
      ];
    }

    return sessionSnapshot.docs.map((sessionDocument) {
      final Map<String, dynamic> data = sessionDocument.data();
      final int durationSeconds =
          (data['durationSeconds'] as num?)?.toInt() ?? 0;
      final int minutes =
          (data['durationMinutes'] as num?)?.toInt() ?? durationSeconds ~/ 60;

      final String subject = _readText(data, [
        'subject',
        'studyTypeName',
        'certificateName',
      ], '학습 기록');
      final String memo = _readText(data, ['memo'], '');
      final String studyTypeName = _readText(data, ['studyTypeName'], '자유 학습');
      final String certificateName = _readText(data, ['certificateName'], '');

      final String description = memo.isNotEmpty
          ? memo
          : certificateName.isNotEmpty && certificateName != subject
          ? '$studyTypeName · $certificateName'
          : studyTypeName;

      return _StudyRecordData(
        studiedAt: _readSessionDate(data, fallbackDate),
        subject: subject,
        description: description,
        minutes: minutes,
        seconds: durationSeconds > 0 ? durationSeconds : minutes * 60,
        icon: _iconForStudyType(data['studyType'] as String?),
        source: 'PERSONAL',
        groupName: null,
        certificateName: certificateName.isEmpty ? '자유 학습' : certificateName,
        studyTypeName: studyTypeName,
        memo: memo,
      );
    }).toList();
  }

  DateTime _readDailyDate(dynamic value, String documentId) {
    if (value is Timestamp) return value.toDate();

    final String rawDate = value is String ? value : documentId;
    return DateTime.tryParse(rawDate) ?? DateTime.now();
  }

  DateTime _readSessionDate(Map<String, dynamic> data, DateTime fallbackDate) {
    for (final String fieldName in ['endedAt', 'startedAt', 'createdAt']) {
      final dynamic value = data[fieldName];
      if (value is Timestamp) return value.toDate();
    }

    return fallbackDate;
  }

  String _readText(
      Map<String, dynamic> data,
      List<String> fieldNames,
      String fallback,
      ) {
    for (final String fieldName in fieldNames) {
      final dynamic value = data[fieldName];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    return fallback;
  }

  IconData _iconForStudyType(String? studyType) {
    return switch (studyType) {
      'PRACTICE' => Icons.edit_note_outlined,
      'REVIEW' => Icons.replay_outlined,
      'LECTURE' => Icons.play_circle_outline_rounded,
      'OTHER' => Icons.notes_rounded,
      _ => Icons.menu_book_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    final List<_StudyRecordData> selectedRecords = _getSelectedRecords();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppTopBar(
        title: '학습 기록',
        leading: IconButton(
          tooltip: '뒤로 가기',
          onPressed: () {
            Navigator.pop(context);
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
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildStudyTimerCard(),
              const SizedBox(height: 18),

              _StudySummaryCard(
                totalMinutes: _getTotalMinutes(selectedRecords),
                studyDays: _getStudyDayCount(selectedRecords),
                recordCount: selectedRecords.length,
                periodLabel: _getSummaryPeriodLabel(),
              ),

              const SizedBox(height: 14),
              _buildSourceSummaryCard(),

              if (_isLoadingRecords) ...[
                const SizedBox(height: 16),
                const LinearProgressIndicator(
                  color: Color(0xFFF0788F),
                  backgroundColor: Color(0xFFFCEFF3),
                ),
              ],
              if (_recordLoadError != null) ...[
                const SizedBox(height: 16),
                _buildRecordLoadError(),
              ],
              const SizedBox(height: 24),

              _buildPeriodSelector(),
              const SizedBox(height: 16),

              _buildPeriodNavigator(),
              const SizedBox(height: 14),

              _buildSourceSelector(),
              const SizedBox(height: 24),

              _SectionTitle(title: _getStudySectionTitle()),
              const SizedBox(height: 12),

              _StudyChart(
                chartData: _getChartData(),
                totalMinutes: _getTotalMinutes(selectedRecords),
                description: _getChartDescription(),
              ),

              const SizedBox(height: 24),

              _SectionTitle(title: _getDetailSectionTitle()),
              const SizedBox(height: 8),

              _buildRecordList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStudyTimerCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.timer_outlined, color: Color(0xFFF0788F), size: 24),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  '공부 시간을 기록해 보세요',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '타이머를 시작하면 공부한 시간이 학습 기록에 저장됩니다.',
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: Color(0xFF777B84),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () async {
                final bool? saved = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => const StudyTimerScreen()),
                );

                if (saved == true && mounted) {
                  await _loadStudyRecords();
                }
              },
              icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
              label: const Text(
                '공부 시작',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
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
      ),
    );
  }

  Widget _buildRecordLoadError() {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFF0788F)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _recordLoadError!,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: Color(0xFF666A73),
              ),
            ),
          ),
          TextButton(onPressed: _loadStudyRecords, child: const Text('다시 시도')),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    const List<Color> selectedBackgroundColors = [
      Color(0xFFFFE8EF),
      Color(0xFFEDE9FF),
      Color(0xFFE5F5F0),
    ];

    const List<Color> selectedTextColors = [
      Color(0xFFE96882),
      Color(0xFF7569B5),
      Color(0xFF4C9A82),
    ];

    const List<IconData> periodIcons = [
      Icons.view_week_outlined,
      Icons.calendar_month_outlined,
      Icons.all_inclusive_rounded,
    ];

    return Container(
      height: 56,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F5FA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFEDE7F0),
        ),
      ),
      child: Row(
        children: List.generate(_periodNames.length, (index) {
          final bool isSelected = _selectedPeriodIndex == index;

          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: index < _periodNames.length - 1 ? 4 : 0,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    setState(() {
                      _selectedPeriodIndex = index;

                      if (_selectedPeriodIndex == 2) {
                        _focusedDate = DateTime.now();
                      }
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? selectedBackgroundColors[index]
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: isSelected
                          ? [
                        BoxShadow(
                          color: selectedTextColors[index]
                              .withValues(alpha: 0.10),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ]
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          periodIcons[index],
                          size: 17,
                          color: isSelected
                              ? selectedTextColors[index]
                              : const Color(0xFF92909A),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _periodNames[index],
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: isSelected
                                ? selectedTextColors[index]
                                : const Color(0xFF777580),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSourceSelector() {
    const List<IconData> sourceIcons = [
      Icons.apps_rounded,
      Icons.person_outline_rounded,
      Icons.groups_2_outlined,
    ];

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 8,
      children: List.generate(_sourceNames.length, (index) {
        final bool isSelected = _selectedSourceIndex == index;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () {
              setState(() {
                _selectedSourceIndex = index;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(
                horizontal: 17,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFFFEDF2)
                    : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFFF0788F)
                      : const Color(0xFFE4E5E9),
                  width: isSelected ? 1.4 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    sourceIcons[index],
                    size: 17,
                    color: isSelected
                        ? const Color(0xFFF0788F)
                        : const Color(0xFF8A8E98),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _sourceNames[index],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w600,
                      color: isSelected
                          ? const Color(0xFFF0788F)
                          : const Color(0xFF666A73),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildSourceSummaryCard() {
    final List<_StudyRecordData> periodRecords =
    _getPeriodRecordsWithoutSourceFilter();

    final int personalMinutes = _getTotalMinutes(
      periodRecords.where((record) => record.source == 'PERSONAL').toList(),
    );

    final int studyMinutes = _getTotalMinutes(
      periodRecords.where((record) => record.source == 'STUDY').toList(),
    );

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.pie_chart_outline_rounded,
                size: 20,
                color: Color(0xFFF0788F),
              ),
              SizedBox(width: 8),
              Text(
                '학습시간 구성',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildSourceSummaryItem(
                  icon: Icons.person_outline_rounded,
                  label: '개인 학습',
                  minutes: personalMinutes,
                ),
              ),
              Container(
                width: 1,
                height: 48,
                color: const Color(0xFFF0F0F2),
              ),
              Expanded(
                child: _buildSourceSummaryItem(
                  icon: Icons.groups_2_outlined,
                  label: '스터디 학습',
                  minutes: studyMinutes,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSourceSummaryItem({
    required IconData icon,
    required String label,
    required int minutes,
  }) {
    return Column(
      children: [
        Icon(icon, size: 21, color: const Color(0xFFF0788F)),
        const SizedBox(height: 6),
        Text(
          _formatMinutes(minutes),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF9AA0AC),
          ),
        ),
      ],
    );
  }

  Widget _buildPeriodNavigator() {
    final bool isAllPeriod = _selectedPeriodIndex == 2;

    return Row(
      children: [
        IconButton(
          tooltip: '이전 기간',
          onPressed: isAllPeriod ? null : _moveToPreviousPeriod,
          icon: Icon(
            Icons.chevron_left_rounded,
            size: 28,
            color: isAllPeriod
                ? const Color(0xFFD3D5DA)
                : const Color(0xFF666A73),
          ),
        ),
        Expanded(
          child: Text(
            _getPeriodText(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A),
            ),
          ),
        ),
        IconButton(
          tooltip: '다음 기간',
          onPressed: isAllPeriod ? null : _moveToNextPeriod,
          icon: Icon(
            Icons.chevron_right_rounded,
            size: 28,
            color: isAllPeriod
                ? const Color(0xFFD3D5DA)
                : const Color(0xFF666A73),
          ),
        ),
      ],
    );
  }

  void _moveToPreviousPeriod() {
    setState(() {
      if (_selectedPeriodIndex == 0) {
        _focusedDate = _focusedDate.subtract(const Duration(days: 7));
      } else if (_selectedPeriodIndex == 1) {
        _focusedDate = DateTime(_focusedDate.year, _focusedDate.month - 1, 1);
      }
    });
  }

  void _moveToNextPeriod() {
    setState(() {
      if (_selectedPeriodIndex == 0) {
        _focusedDate = _focusedDate.add(const Duration(days: 7));
      } else if (_selectedPeriodIndex == 1) {
        _focusedDate = DateTime(_focusedDate.year, _focusedDate.month + 1, 1);
      }
    });
  }

  DateTime _getStartOfWeek(DateTime date) {
    return DateTime(
      date.year,
      date.month,
      date.day,
    ).subtract(Duration(days: date.weekday - 1));
  }

  String _getPeriodText() {
    if (_selectedPeriodIndex == 0) {
      final DateTime startDate = _getStartOfWeek(_focusedDate);

      final DateTime endDate = startDate.add(const Duration(days: 6));

      return '${startDate.year}년 '
          '${startDate.month}월 ${startDate.day}일'
          ' - '
          '${endDate.month}월 ${endDate.day}일';
    }

    if (_selectedPeriodIndex == 1) {
      return '${_focusedDate.year}년 '
          '${_focusedDate.month}월';
    }

    return '전체 학습 기록';
  }

  String _getStudySectionTitle() {
    if (_selectedPeriodIndex == 0) {
      return '주간 학습 통계';
    }

    if (_selectedPeriodIndex == 1) {
      return '월간 학습 통계';
    }

    return '전체 학습 통계';
  }

  String _getDetailSectionTitle() {
    if (_selectedPeriodIndex == 0) {
      return '이번 주 상세 기록';
    }

    if (_selectedPeriodIndex == 1) {
      return '이번 달 상세 기록';
    }

    return '전체 상세 기록';
  }

  String _getSummaryPeriodLabel() {
    if (_selectedPeriodIndex == 0) {
      return '선택한 주';
    }

    if (_selectedPeriodIndex == 1) {
      return '선택한 달';
    }

    return '전체 누적';
  }

  String _getChartDescription() {
    if (_selectedPeriodIndex == 0) {
      return '요일별 학습 시간';
    }

    if (_selectedPeriodIndex == 1) {
      return '주차별 학습 시간';
    }

    return '월별 학습 시간';
  }

  List<_StudyRecordData> _getSelectedRecords() {
    if (_selectedPeriodIndex == 0) {
      return _getWeeklyRecords();
    }

    if (_selectedPeriodIndex == 1) {
      return _getMonthlyRecords();
    }

    final List<_StudyRecordData> records =
    List<_StudyRecordData>.from(_getSourceFilteredRecords());

    records.sort((a, b) {
      return b.studiedAt.compareTo(a.studiedAt);
    });

    return records;
  }

  List<_StudyRecordData> _getSourceFilteredRecords() {
    if (_selectedSourceIndex == 1) {
      return _studyRecords
          .where((record) => record.source == 'PERSONAL')
          .toList();
    }

    if (_selectedSourceIndex == 2) {
      return _studyRecords
          .where((record) => record.source == 'STUDY')
          .toList();
    }

    return List<_StudyRecordData>.from(_studyRecords);
  }

  List<_StudyRecordData> _getPeriodRecordsWithoutSourceFilter() {
    if (_selectedPeriodIndex == 0) {
      final DateTime startDate = _getStartOfWeek(_focusedDate);
      final DateTime endDate = startDate.add(const Duration(days: 7));

      return _studyRecords.where((record) {
        final DateTime studiedDate = DateTime(
          record.studiedAt.year,
          record.studiedAt.month,
          record.studiedAt.day,
        );

        return !studiedDate.isBefore(startDate) &&
            studiedDate.isBefore(endDate);
      }).toList();
    }

    if (_selectedPeriodIndex == 1) {
      final DateTime startDate = DateTime(
        _focusedDate.year,
        _focusedDate.month,
        1,
      );

      final DateTime endDate = DateTime(
        _focusedDate.year,
        _focusedDate.month + 1,
        1,
      );

      return _studyRecords.where((record) {
        return !record.studiedAt.isBefore(startDate) &&
            record.studiedAt.isBefore(endDate);
      }).toList();
    }

    return List<_StudyRecordData>.from(_studyRecords);
  }

  List<_StudyRecordData> _getWeeklyRecords() {
    final DateTime startDate = _getStartOfWeek(_focusedDate);

    final DateTime endDate = startDate.add(const Duration(days: 7));

    final List<_StudyRecordData> records =
    _getSourceFilteredRecords().where((record) {
      final DateTime studiedDate = DateTime(
        record.studiedAt.year,
        record.studiedAt.month,
        record.studiedAt.day,
      );

      return !studiedDate.isBefore(startDate) && studiedDate.isBefore(endDate);
    }).toList();

    records.sort((a, b) {
      return a.studiedAt.compareTo(b.studiedAt);
    });

    return records;
  }

  List<_StudyRecordData> _getMonthlyRecords() {
    final DateTime startDate = DateTime(
      _focusedDate.year,
      _focusedDate.month,
      1,
    );

    final DateTime endDate = DateTime(
      _focusedDate.year,
      _focusedDate.month + 1,
      1,
    );

    final List<_StudyRecordData> records =
    _getSourceFilteredRecords().where((record) {
      return !record.studiedAt.isBefore(startDate) &&
          record.studiedAt.isBefore(endDate);
    }).toList();

    records.sort((a, b) {
      return a.studiedAt.compareTo(b.studiedAt);
    });

    return records;
  }

  Map<DateTime, List<_StudyRecordData>> _groupRecordsByDate(
      List<_StudyRecordData> records,
      ) {
    final Map<DateTime, List<_StudyRecordData>> groupedRecords = {};

    for (final record in records) {
      final DateTime dateKey = DateTime(
        record.studiedAt.year,
        record.studiedAt.month,
        record.studiedAt.day,
      );

      if (groupedRecords[dateKey] == null) {
        groupedRecords[dateKey] = [];
      }

      groupedRecords[dateKey]!.add(record);
    }

    return groupedRecords;
  }

  Map<DateTime, List<_StudyRecordData>> _groupRecordsByMonth(
      List<_StudyRecordData> records,
      ) {
    final Map<DateTime, List<_StudyRecordData>> groupedRecords = {};

    for (final record in records) {
      final DateTime monthKey = DateTime(
        record.studiedAt.year,
        record.studiedAt.month,
      );

      if (groupedRecords[monthKey] == null) {
        groupedRecords[monthKey] = [];
      }

      groupedRecords[monthKey]!.add(record);
    }

    return groupedRecords;
  }

  List<_ChartData> _getChartData() {
    if (_selectedPeriodIndex == 0) {
      return _getWeeklyChartData();
    }

    if (_selectedPeriodIndex == 1) {
      return _getMonthlyChartData();
    }

    return _getAllChartData();
  }

  List<_ChartData> _getWeeklyChartData() {
    final DateTime startDate = _getStartOfWeek(_focusedDate);

    const List<String> dayNames = ['월', '화', '수', '목', '금', '토', '일'];

    return List.generate(7, (index) {
      final DateTime targetDate = startDate.add(Duration(days: index));

      int totalSeconds = 0;

      for (final record in _getSourceFilteredRecords()) {
        if (_isSameDate(record.studiedAt, targetDate)) {
          totalSeconds += record.seconds;
        }
      }

      return _ChartData(
        label: dayNames[index],
        minutes: totalSeconds ~/ 60,
      );
    });
  }

  List<_ChartData> _getMonthlyChartData() {
    final List<_StudyRecordData> records = _getMonthlyRecords();

    return List.generate(5, (index) {
      final int weekNumber = index + 1;
      int totalSeconds = 0;

      for (final record in records) {
        if (_getWeekNumberOfMonth(record.studiedAt) == weekNumber) {
          totalSeconds += record.seconds;
        }
      }

      return _ChartData(
        label: '$weekNumber주',
        minutes: totalSeconds ~/ 60,
      );
    });
  }

  List<_ChartData> _getAllChartData() {
    final List<_StudyRecordData> sourceRecords = _getSourceFilteredRecords();

    if (sourceRecords.isEmpty) {
      return [];
    }

    final List<_StudyRecordData> records = List<_StudyRecordData>.from(
      sourceRecords,
    );

    records.sort((a, b) {
      return a.studiedAt.compareTo(b.studiedAt);
    });

    final DateTime firstMonth = DateTime(
      records.first.studiedAt.year,
      records.first.studiedAt.month,
    );

    final DateTime lastMonth = DateTime(
      records.last.studiedAt.year,
      records.last.studiedAt.month,
    );

    final List<_ChartData> chartData = [];
    DateTime currentMonth = firstMonth;

    while (!currentMonth.isAfter(lastMonth)) {
      int totalSeconds = 0;

      for (final record in sourceRecords) {
        if (record.studiedAt.year == currentMonth.year &&
            record.studiedAt.month == currentMonth.month) {
          totalSeconds += record.seconds;
        }
      }

      chartData.add(
        _ChartData(
          label: '${currentMonth.month}월',
          minutes: totalSeconds ~/ 60,
        ),
      );

      currentMonth = DateTime(currentMonth.year, currentMonth.month + 1);
    }

    return chartData;
  }

  int _getWeekNumberOfMonth(DateTime date) {
    return ((date.day - 1) ~/ 7) + 1;
  }

  bool _isSameDate(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  int _getTotalMinutes(List<_StudyRecordData> records) {
    int totalSeconds = 0;

    for (final record in records) {
      totalSeconds += record.seconds;
    }

    return totalSeconds ~/ 60;
  }

  int _getStudyDayCount(List<_StudyRecordData> records) {
    final Set<String> studyDates = {};

    for (final record in records) {
      studyDates.add(
        '${record.studiedAt.year}-'
            '${record.studiedAt.month}-'
            '${record.studiedAt.day}',
      );
    }

    return studyDates.length;
  }

  String _getDayName(DateTime date) {
    const List<String> dayNames = [
      '월요일',
      '화요일',
      '수요일',
      '목요일',
      '금요일',
      '토요일',
      '일요일',
    ];

    return dayNames[date.weekday - 1];
  }

  String _formatMinutes(int totalMinutes) {
    if (totalMinutes < 60) {
      return '$totalMinutes분';
    }

    final int hours = totalMinutes ~/ 60;
    final int minutes = totalMinutes % 60;

    if (minutes == 0) {
      return '$hours시간';
    }

    return '$hours시간 $minutes분';
  }

  Widget _buildRecordList() {
    if (_selectedPeriodIndex == 0) {
      return _buildWeeklyRecordList();
    }

    if (_selectedPeriodIndex == 1) {
      return _buildMonthlyRecordList();
    }

    return _buildAllRecordList();
  }

  Widget _buildWeeklyRecordList() {
    final List<_StudyRecordData> records = _getWeeklyRecords();

    return _buildDateGroupedRecordList(
      records: records,
      emptyMessage: '이번 주 학습 기록이 없습니다.',
      newestFirst: false,
    );
  }

  Widget _buildMonthlyRecordList() {
    final List<_StudyRecordData> records = _getMonthlyRecords();

    // 월간 상세 기록은 주차별 카드가 아니라
    // 선택한 달의 기록을 날짜별로 보여줍니다.
    return _buildDateGroupedRecordList(
      records: records,
      emptyMessage: '이번 달 학습 기록이 없습니다.',
      newestFirst: false,
    );
  }

  Widget _buildAllRecordList() {
    if (_studyRecords.isEmpty) {
      return _buildEmptyRecordView(message: '아직 학습 기록이 없습니다.');
    }

    final Map<DateTime, List<_StudyRecordData>> groupedRecords =
    _groupRecordsByMonth(_studyRecords);

    final List<DateTime> months = groupedRecords.keys.toList();

    months.sort((a, b) {
      return b.compareTo(a);
    });

    return Column(
      children: [
        for (final month in months) ...[
          _buildMonthRecordGroup(month: month, records: groupedRecords[month]!),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildDateGroupedRecordList({
    required List<_StudyRecordData> records,
    required String emptyMessage,
    required bool newestFirst,
  }) {
    if (records.isEmpty) {
      return _buildEmptyRecordView(message: emptyMessage);
    }

    final Map<DateTime, List<_StudyRecordData>> groupedRecords =
    _groupRecordsByDate(records);

    final List<DateTime> dates = groupedRecords.keys.toList();

    dates.sort((a, b) {
      if (newestFirst) {
        return b.compareTo(a);
      }

      return a.compareTo(b);
    });

    return Column(
      children: [
        for (final date in dates) ...[
          _buildDateRecordGroup(date: date, records: groupedRecords[date]!),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildEmptyRecordView({required String message}) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Column(
          children: [
            const Icon(
              Icons.menu_book_outlined,
              size: 34,
              color: Color(0xFFB4B8C2),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF666A73),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateRecordGroup({
    required DateTime date,
    required List<_StudyRecordData> records,
  }) {
    final int totalMinutes = _getTotalMinutes(records);

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${date.month}월 ${date.day}일'
                        ' · '
                        '${_getDayName(date)}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ),
                Text(
                  '총 ${_formatMinutes(totalMinutes)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFF0788F),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF0F0F2)),
          for (int index = 0; index < records.length; index++) ...[
            _StudyRecordTile(record: records[index]),
            if (index < records.length - 1)
              const Divider(
                height: 1,
                indent: 72,
                endIndent: 18,
                color: Color(0xFFF0F0F2),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildMonthRecordGroup({
    required DateTime month,
    required List<_StudyRecordData> records,
  }) {
    final Map<DateTime, List<_StudyRecordData>> groupedRecords =
    _groupRecordsByDate(records);

    final List<DateTime> dates = groupedRecords.keys.toList();

    dates.sort((a, b) {
      return b.compareTo(a);
    });

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${month.year}년 ${month.month}월',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ),
                Text(
                  '총 ${_formatMinutes(_getTotalMinutes(records))}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFF0788F),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF0F0F2)),
          for (int dateIndex = 0; dateIndex < dates.length; dateIndex++) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 4),
              child: Text(
                '${dates[dateIndex].month}월 '
                    '${dates[dateIndex].day}일'
                    ' · '
                    '${_getDayName(dates[dateIndex])}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF666A73),
                ),
              ),
            ),
            for (
            int recordIndex = 0;
            recordIndex < groupedRecords[dates[dateIndex]]!.length;
            recordIndex++
            ) ...[
              _StudyRecordTile(
                record: groupedRecords[dates[dateIndex]]![recordIndex],
              ),
              if (recordIndex < groupedRecords[dates[dateIndex]]!.length - 1)
                const Divider(
                  height: 1,
                  indent: 72,
                  endIndent: 18,
                  color: Color(0xFFF0F0F2),
                ),
            ],
            if (dateIndex < dates.length - 1)
              const Divider(height: 1, color: Color(0xFFF0F0F2)),
          ],
        ],
      ),
    );
  }
}

class _StudySummaryCard extends StatelessWidget {
  final int totalMinutes;
  final int studyDays;
  final int recordCount;
  final String periodLabel;

  const _StudySummaryCard({
    required this.totalMinutes,
    required this.studyDays,
    required this.recordCount,
    required this.periodLabel,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '오늘도 목표를 향해 공부하고 있어요!',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '선택한 기간의 학습 기록을 확인해 보세요.',
            style: TextStyle(fontSize: 12, color: Color(0xFF9AA0AC)),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _SummaryValue(
                  icon: Icons.timer_outlined,
                  label: periodLabel,
                  value: _formatMinutes(totalMinutes),
                ),
              ),
              Container(width: 1, height: 45, color: const Color(0xFFF0F0F2)),
              Expanded(
                child: _SummaryValue(
                  icon: Icons.calendar_today_outlined,
                  label: '학습 일수',
                  value: '$studyDays일',
                ),
              ),
              Container(width: 1, height: 45, color: const Color(0xFFF0F0F2)),
              Expanded(
                child: _SummaryValue(
                  icon: Icons.list_alt_outlined,
                  label: '학습 횟수',
                  value: '$recordCount회',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatMinutes(int totalMinutes) {
    if (totalMinutes < 60) {
      return '$totalMinutes분';
    }

    final int hours = totalMinutes ~/ 60;
    final int minutes = totalMinutes % 60;

    if (minutes == 0) {
      return '$hours시간';
    }

    return '$hours시간 $minutes분';
  }
}

class _SummaryValue extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SummaryValue({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 21, color: const Color(0xFFF0788F)),
        const SizedBox(height: 7),
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, color: Color(0xFF9AA0AC)),
        ),
      ],
    );
  }
}

class _StudyChart extends StatelessWidget {
  final List<_ChartData> chartData;
  final int totalMinutes;
  final String description;

  const _StudyChart({
    required this.chartData,
    required this.totalMinutes,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    int maxMinutes = 0;

    for (final data in chartData) {
      if (data.minutes > maxMinutes) {
        maxMinutes = data.minutes;
      }
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart, size: 20, color: Color(0xFFF0788F)),
              const SizedBox(width: 8),
              Text(
                '총 ${_formatMinutes(totalMinutes)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const Spacer(),
              Text(
                description,
                style: const TextStyle(fontSize: 11, color: Color(0xFFF0788F)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (chartData.isEmpty)
            const SizedBox(
              height: 150,
              child: Center(
                child: Text(
                  '표시할 통계가 없습니다.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF9AA0AC)),
                ),
              ),
            )
          else
            SizedBox(
              height: 170,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: chartData.map((data) {
                  final double heightRatio = maxMinutes == 0
                      ? 0
                      : data.minutes / maxMinutes;

                  final double barHeight = data.minutes == 0
                      ? 4
                      : 100 * heightRatio;

                  return Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '${data.minutes}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF9AA0AC),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Container(
                          width: 20,
                          height: barHeight,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF6A9B8),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          data.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF666A73),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              '단위: 분',
              style: TextStyle(fontSize: 10, color: Color(0xFFB4B8C2)),
            ),
          ),
        ],
      ),
    );
  }

  String _formatMinutes(int totalMinutes) {
    if (totalMinutes < 60) {
      return '$totalMinutes분';
    }

    final int hours = totalMinutes ~/ 60;
    final int minutes = totalMinutes % 60;

    if (minutes == 0) {
      return '$hours시간';
    }

    return '$hours시간 $minutes분';
  }
}

class _StudyRecordTile extends StatelessWidget {
  final _StudyRecordData record;

  const _StudyRecordTile({required this.record});

  @override
  Widget build(BuildContext context) {
    final bool isStudyRecord = record.source == 'STUDY';
    final String categoryText = isStudyRecord
        ? (record.groupName?.trim().isNotEmpty == true
        ? record.groupName!.trim()
        : '스터디 그룹')
        : record.certificateName;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isStudyRecord
                  ? const Color(0xFFEDEAF7)
                  : const Color(0xFFFCEFF3),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              record.icon,
              size: 21,
              color: isStudyRecord
                  ? const Color(0xFF7667A8)
                  : const Color(0xFFF0788F),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isStudyRecord
                            ? const Color(0xFFEDEAF7)
                            : const Color(0xFFFFE8EE),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isStudyRecord ? '스터디' : '개인',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isStudyRecord
                              ? const Color(0xFF7667A8)
                              : const Color(0xFFF0788F),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _formatRecordTime(record),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFF0788F),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                Row(
                  children: [
                    Icon(
                      isStudyRecord
                          ? Icons.groups_2_outlined
                          : Icons.workspace_premium_outlined,
                      size: 15,
                      color: const Color(0xFF9AA0AC),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        categoryText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF777B84),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  record.subject,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 9),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: isStudyRecord
                        ? const Color(0xFFF3F1FA)
                        : const Color(0xFFFFF3F6),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isStudyRecord
                          ? const Color(0xFFDCD7EF)
                          : const Color(0xFFFFD5DE),
                    ),
                  ),
                  child: Text(
                    record.studyTypeName,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isStudyRecord
                          ? const Color(0xFF7667A8)
                          : const Color(0xFFF0788F),
                    ),
                  ),
                ),
                if (!isStudyRecord && record.memo.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F7F8),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.edit_note_outlined,
                          size: 17,
                          color: Color(0xFF9AA0AC),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            record.memo,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              height: 1.45,
                              color: Color(0xFF666A73),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 9),
                Text(
                  '${record.studiedAt.month}월 '
                      '${record.studiedAt.day}일'
                      ' · '
                      '${_getDayOfWeek(record.studiedAt)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF9AA0AC),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatRecordTime(_StudyRecordData record) {
    if (record.minutes > 0) {
      return '${record.minutes}분';
    }

    return '${record.seconds}초';
  }

  String _getDayOfWeek(DateTime date) {
    const List<String> dayNames = [
      '월요일',
      '화요일',
      '수요일',
      '목요일',
      '금요일',
      '토요일',
      '일요일',
    ];

    return dayNames[date.weekday - 1];
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: Color(0xFF1A1A1A),
      ),
    );
  }
}

class _ChartData {
  final String label;
  final int minutes;

  const _ChartData({required this.label, required this.minutes});
}

class _StudyRecordData {
  final DateTime studiedAt;
  final String subject;
  final String description;
  final int minutes;
  final int seconds;
  final IconData icon;
  final String source;
  final String? groupName;
  final String certificateName;
  final String studyTypeName;
  final String memo;

  const _StudyRecordData({
    required this.studiedAt,
    required this.subject,
    required this.description,
    required this.minutes,
    required this.seconds,
    required this.icon,
    required this.source,
    required this.groupName,
    required this.certificateName,
    required this.studyTypeName,
    required this.memo,
  });
}
