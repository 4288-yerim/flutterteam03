import 'package:flutter/material.dart';

import '../../widgets/app_card.dart';
import '../../widgets/app_main_background.dart';
import '../../widgets/app_top_bar.dart';

class StudyRecordScreen extends StatefulWidget {
  const StudyRecordScreen({super.key});

  @override
  State<StudyRecordScreen> createState() =>
      _StudyRecordScreenState();
}

class _StudyRecordScreenState
    extends State<StudyRecordScreen> {
  int _selectedPeriodIndex = 0;

  DateTime _focusedDate = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );

  final List<String> _periodNames = [
    '주간',
    '월간',
    '전체',
  ];

  // 임시 학습 기록
  // Firestore 연결 후 이 목록을 실제 조회 결과로 교체하면 됩니다.
  static final List<_StudyRecordData> _studyRecords = [
    _StudyRecordData(
      studiedAt: DateTime(2026, 7, 13),
      subject: '정보처리기사 필기',
      description: '소프트웨어 설계 핵심 개념 복습',
      minutes: 50,
      icon: Icons.menu_book_outlined,
    ),
    _StudyRecordData(
      studiedAt: DateTime(2026, 7, 12),
      subject: '정보처리기사 기출문제',
      description: '2025년 3회 기출문제 풀이',
      minutes: 15,
      icon: Icons.edit_note_outlined,
    ),
    _StudyRecordData(
      studiedAt: DateTime(2026, 7, 11),
      subject: '데이터베이스',
      description: '정규화와 트랜잭션 복습',
      minutes: 45,
      icon: Icons.storage_outlined,
    ),
    _StudyRecordData(
      studiedAt: DateTime(2026, 7, 10),
      subject: '프로그래밍 언어',
      description: 'Java 객체지향 개념 정리',
      minutes: 40,
      icon: Icons.code_outlined,
    ),
    _StudyRecordData(
      studiedAt: DateTime(2026, 7, 8),
      subject: 'SQLD',
      description: 'SQL 기본 문법 문제 풀이',
      minutes: 80,
      icon: Icons.storage_outlined,
    ),
    _StudyRecordData(
      studiedAt: DateTime(2026, 7, 6),
      subject: '정보처리기사 필기',
      description: '요구사항 확인 단원 복습',
      minutes: 30,
      icon: Icons.menu_book_outlined,
    ),
    _StudyRecordData(
      studiedAt: DateTime(2026, 7, 3),
      subject: '프로그래밍 언어',
      description: 'Dart 컬렉션 문법 복습',
      minutes: 60,
      icon: Icons.code_outlined,
    ),
    _StudyRecordData(
      studiedAt: DateTime(2026, 6, 28),
      subject: '정보처리기사 기출문제',
      description: '2025년 2회 기출문제 풀이',
      minutes: 70,
      icon: Icons.edit_note_outlined,
    ),
    _StudyRecordData(
      studiedAt: DateTime(2026, 6, 20),
      subject: '데이터베이스',
      description: '트랜잭션과 인덱스 복습',
      minutes: 55,
      icon: Icons.storage_outlined,
    ),
    _StudyRecordData(
      studiedAt: DateTime(2026, 5, 14),
      subject: '정보처리기사 필기',
      description: '소프트웨어 개발 단원 복습',
      minutes: 90,
      icon: Icons.menu_book_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final List<_StudyRecordData> selectedRecords =
    _getSelectedRecords();

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
          padding: const EdgeInsets.fromLTRB(
            20,
            16,
            20,
            110,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildPeriodSelector(),
              const SizedBox(height: 16),

              _buildPeriodNavigator(),
              const SizedBox(height: 20),

              _StudySummaryCard(
                totalMinutes:
                _getTotalMinutes(selectedRecords),
                studyDays:
                _getStudyDayCount(selectedRecords),
                periodLabel: _getSummaryPeriodLabel(),
              ),

              const SizedBox(height: 24),

              _SectionTitle(
                title: _getStudySectionTitle(),
              ),
              const SizedBox(height: 12),

              _StudyChart(
                chartData: _getChartData(),
                totalMinutes:
                _getTotalMinutes(selectedRecords),
                description: _getChartDescription(),
              ),

              const SizedBox(height: 24),

              _SectionTitle(
                title: _getDetailSectionTitle(),
              ),
              const SizedBox(height: 8),

              _buildRecordList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      height: 50,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F2F3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: List.generate(
          _periodNames.length,
              (index) {
            final bool isSelected =
                _selectedPeriodIndex == index;

            return Expanded(
              child: Material(
                color: isSelected
                    ? Colors.white
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(13),
                child: InkWell(
                  borderRadius: BorderRadius.circular(13),
                  onTap: () {
                    setState(() {
                      _selectedPeriodIndex = index;

                      if (_selectedPeriodIndex == 2) {
                        _focusedDate = DateTime.now();
                      }
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(
                      milliseconds: 180,
                    ),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius:
                      BorderRadius.circular(13),
                      boxShadow: isSelected
                          ? [
                        BoxShadow(
                          color: Colors.black
                              .withOpacity(0.04),
                          blurRadius: 8,
                          offset:
                          const Offset(0, 3),
                        ),
                      ]
                          : null,
                    ),
                    child: Text(
                      _periodNames[index],
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isSelected
                            ? const Color(0xFFF0788F)
                            : const Color(0xFF666A73),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPeriodNavigator() {
    final bool isAllPeriod =
        _selectedPeriodIndex == 2;

    return Row(
      children: [
        IconButton(
          tooltip: '이전 기간',
          onPressed: isAllPeriod
              ? null
              : _moveToPreviousPeriod,
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
          onPressed: isAllPeriod
              ? null
              : _moveToNextPeriod,
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
        _focusedDate = _focusedDate.subtract(
          const Duration(days: 7),
        );
      } else if (_selectedPeriodIndex == 1) {
        _focusedDate = DateTime(
          _focusedDate.year,
          _focusedDate.month - 1,
          1,
        );
      }
    });
  }

  void _moveToNextPeriod() {
    setState(() {
      if (_selectedPeriodIndex == 0) {
        _focusedDate = _focusedDate.add(
          const Duration(days: 7),
        );
      } else if (_selectedPeriodIndex == 1) {
        _focusedDate = DateTime(
          _focusedDate.year,
          _focusedDate.month + 1,
          1,
        );
      }
    });
  }

  DateTime _getStartOfWeek(DateTime date) {
    return DateTime(
      date.year,
      date.month,
      date.day,
    ).subtract(
      Duration(days: date.weekday - 1),
    );
  }

  String _getPeriodText() {
    if (_selectedPeriodIndex == 0) {
      final DateTime startDate =
      _getStartOfWeek(_focusedDate);

      final DateTime endDate = startDate.add(
        const Duration(days: 6),
      );

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
    List<_StudyRecordData>.from(_studyRecords);

    records.sort((a, b) {
      return b.studiedAt.compareTo(a.studiedAt);
    });

    return records;
  }

  List<_StudyRecordData> _getWeeklyRecords() {
    final DateTime startDate =
    _getStartOfWeek(_focusedDate);

    final DateTime endDate = startDate.add(
      const Duration(days: 7),
    );

    final List<_StudyRecordData> records =
    _studyRecords.where((record) {
      final DateTime studiedDate = DateTime(
        record.studiedAt.year,
        record.studiedAt.month,
        record.studiedAt.day,
      );

      return !studiedDate.isBefore(startDate) &&
          studiedDate.isBefore(endDate);
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
    _studyRecords.where((record) {
      return !record.studiedAt.isBefore(startDate) &&
          record.studiedAt.isBefore(endDate);
    }).toList();

    records.sort((a, b) {
      return a.studiedAt.compareTo(b.studiedAt);
    });

    return records;
  }

  Map<DateTime, List<_StudyRecordData>>
  _groupRecordsByDate(
      List<_StudyRecordData> records,
      ) {
    final Map<DateTime, List<_StudyRecordData>>
    groupedRecords = {};

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

  Map<DateTime, List<_StudyRecordData>>
  _groupRecordsByMonth(
      List<_StudyRecordData> records,
      ) {
    final Map<DateTime, List<_StudyRecordData>>
    groupedRecords = {};

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
    final DateTime startDate =
    _getStartOfWeek(_focusedDate);

    const List<String> dayNames = [
      '월',
      '화',
      '수',
      '목',
      '금',
      '토',
      '일',
    ];

    return List.generate(7, (index) {
      final DateTime targetDate = startDate.add(
        Duration(days: index),
      );

      int minutes = 0;

      for (final record in _studyRecords) {
        if (_isSameDate(
          record.studiedAt,
          targetDate,
        )) {
          minutes += record.minutes;
        }
      }

      return _ChartData(
        label: dayNames[index],
        minutes: minutes,
      );
    });
  }

  List<_ChartData> _getMonthlyChartData() {
    final List<_StudyRecordData> records =
    _getMonthlyRecords();

    return List.generate(5, (index) {
      final int weekNumber = index + 1;
      int minutes = 0;

      for (final record in records) {
        if (_getWeekNumberOfMonth(
          record.studiedAt,
        ) ==
            weekNumber) {
          minutes += record.minutes;
        }
      }

      return _ChartData(
        label: '$weekNumber주',
        minutes: minutes,
      );
    });
  }

  List<_ChartData> _getAllChartData() {
    if (_studyRecords.isEmpty) {
      return [];
    }

    final List<_StudyRecordData> records =
    List<_StudyRecordData>.from(_studyRecords);

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
      int minutes = 0;

      for (final record in _studyRecords) {
        if (record.studiedAt.year ==
            currentMonth.year &&
            record.studiedAt.month ==
                currentMonth.month) {
          minutes += record.minutes;
        }
      }

      chartData.add(
        _ChartData(
          label: '${currentMonth.month}월',
          minutes: minutes,
        ),
      );

      currentMonth = DateTime(
        currentMonth.year,
        currentMonth.month + 1,
      );
    }

    return chartData;
  }

  int _getWeekNumberOfMonth(DateTime date) {
    return ((date.day - 1) ~/ 7) + 1;
  }

  bool _isSameDate(
      DateTime first,
      DateTime second,
      ) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  int _getTotalMinutes(
      List<_StudyRecordData> records,
      ) {
    int totalMinutes = 0;

    for (final record in records) {
      totalMinutes += record.minutes;
    }

    return totalMinutes;
  }

  int _getStudyDayCount(
      List<_StudyRecordData> records,
      ) {
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
    final List<_StudyRecordData> records =
    _getWeeklyRecords();

    return _buildDateGroupedRecordList(
      records: records,
      emptyMessage: '이번 주 학습 기록이 없습니다.',
      newestFirst: false,
    );
  }

  Widget _buildMonthlyRecordList() {
    final List<_StudyRecordData> records =
    _getMonthlyRecords();

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
      return _buildEmptyRecordView(
        message: '아직 학습 기록이 없습니다.',
      );
    }

    final Map<DateTime, List<_StudyRecordData>>
    groupedRecords =
    _groupRecordsByMonth(_studyRecords);

    final List<DateTime> months =
    groupedRecords.keys.toList();

    months.sort((a, b) {
      return b.compareTo(a);
    });

    return Column(
      children: [
        for (final month in months) ...[
          _buildMonthRecordGroup(
            month: month,
            records: groupedRecords[month]!,
          ),
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
      return _buildEmptyRecordView(
        message: emptyMessage,
      );
    }

    final Map<DateTime, List<_StudyRecordData>>
    groupedRecords =
    _groupRecordsByDate(records);

    final List<DateTime> dates =
    groupedRecords.keys.toList();

    dates.sort((a, b) {
      if (newestFirst) {
        return b.compareTo(a);
      }

      return a.compareTo(b);
    });

    return Column(
      children: [
        for (final date in dates) ...[
          _buildDateRecordGroup(
            date: date,
            records: groupedRecords[date]!,
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildEmptyRecordView({
    required String message,
  }) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 28,
        ),
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
    final int totalMinutes =
    _getTotalMinutes(records);

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              18,
              16,
              18,
              12,
            ),
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
          const Divider(
            height: 1,
            color: Color(0xFFF0F0F2),
          ),
          for (int index = 0;
          index < records.length;
          index++) ...[
            _StudyRecordTile(
              record: records[index],
            ),
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
    final Map<DateTime, List<_StudyRecordData>>
    groupedRecords =
    _groupRecordsByDate(records);

    final List<DateTime> dates =
    groupedRecords.keys.toList();

    dates.sort((a, b) {
      return b.compareTo(a);
    });

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              18,
              16,
              18,
              14,
            ),
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
                  '총 ${_formatMinutes(
                    _getTotalMinutes(records),
                  )}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFF0788F),
                  ),
                ),
              ],
            ),
          ),
          const Divider(
            height: 1,
            color: Color(0xFFF0F0F2),
          ),
          for (int dateIndex = 0;
          dateIndex < dates.length;
          dateIndex++) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                18,
                14,
                18,
                4,
              ),
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
            for (int recordIndex = 0;
            recordIndex <
                groupedRecords[
                dates[dateIndex]]!
                    .length;
            recordIndex++) ...[
              _StudyRecordTile(
                record: groupedRecords[
                dates[dateIndex]]![recordIndex],
              ),
              if (recordIndex <
                  groupedRecords[
                  dates[dateIndex]]!
                      .length -
                      1)
                const Divider(
                  height: 1,
                  indent: 72,
                  endIndent: 18,
                  color: Color(0xFFF0F0F2),
                ),
            ],
            if (dateIndex < dates.length - 1)
              const Divider(
                height: 1,
                color: Color(0xFFF0F0F2),
              ),
          ],
        ],
      ),
    );
  }
}

class _StudySummaryCard extends StatelessWidget {
  final int totalMinutes;
  final int studyDays;
  final String periodLabel;

  const _StudySummaryCard({
    required this.totalMinutes,
    required this.studyDays,
    required this.periodLabel,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
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
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF9AA0AC),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _SummaryValue(
                  icon: Icons.timer_outlined,
                  label: periodLabel,
                  value:
                  _formatMinutes(totalMinutes),
                ),
              ),
              Container(
                width: 1,
                height: 45,
                color: const Color(0xFFF0F0F2),
              ),
              Expanded(
                child: _SummaryValue(
                  icon:
                  Icons.calendar_today_outlined,
                  label: '학습 일수',
                  value: '$studyDays일',
                ),
              ),
              Container(
                width: 1,
                height: 45,
                color: const Color(0xFFF0F0F2),
              ),
              Expanded(
                child: _SummaryValue(
                  icon: Icons.list_alt_outlined,
                  label: '학습 횟수',
                  value: '${_getRecordCount()}회',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  int _getRecordCount() {
    // 총 시간이 0이면 기록도 없는 것으로 표시합니다.
    if (totalMinutes == 0) {
      return 0;
    }

    // 현재 카드에는 별도 횟수 값을 받지 않으므로
    // 학습한 날짜 수를 기본 횟수로 표시합니다.
    return studyDays;
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
        Icon(
          icon,
          size: 21,
          color: const Color(0xFFF0788F),
        ),
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
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF9AA0AC),
          ),
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
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.bar_chart,
                size: 20,
                color: Color(0xFFF0788F),
              ),
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
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFFF0788F),
                ),
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
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF9AA0AC),
                  ),
                ),
              ),
            )
          else
            SizedBox(
              height: 170,
              child: Row(
                crossAxisAlignment:
                CrossAxisAlignment.end,
                children: chartData.map((data) {
                  final double heightRatio =
                  maxMinutes == 0
                      ? 0
                      : data.minutes / maxMinutes;

                  final double barHeight =
                  data.minutes == 0
                      ? 4
                      : 100 * heightRatio;

                  return Expanded(
                    child: Column(
                      mainAxisAlignment:
                      MainAxisAlignment.end,
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
                            color:
                            const Color(0xFFF6A9B8),
                            borderRadius:
                            BorderRadius.circular(8),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          data.label,
                          maxLines: 1,
                          overflow:
                          TextOverflow.ellipsis,
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
              style: TextStyle(
                fontSize: 10,
                color: Color(0xFFB4B8C2),
              ),
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

  const _StudyRecordTile({
    required this.record,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 16,
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFFCEFF3),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              record.icon,
              size: 21,
              color: const Color(0xFFF0788F),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        record.subject,
                        overflow:
                        TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight:
                          FontWeight.w700,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${record.minutes}분',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight:
                        FontWeight.w700,
                        color: Color(0xFFF0788F),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  record.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF666A73),
                  ),
                ),
                const SizedBox(height: 6),
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

  const _SectionTitle({
    required this.title,
  });

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

  const _ChartData({
    required this.label,
    required this.minutes,
  });
}

class _StudyRecordData {
  final DateTime studiedAt;
  final String subject;
  final String description;
  final int minutes;
  final IconData icon;

  const _StudyRecordData({
    required this.studiedAt,
    required this.subject,
    required this.description,
    required this.minutes,
    required this.icon,
  });
}
