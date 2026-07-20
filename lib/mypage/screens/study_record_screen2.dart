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

  static const List<_WeeklyStudyData> _weeklyStudyData = [
    _WeeklyStudyData(
      day: '월',
      minutes: 50,
    ),
    _WeeklyStudyData(
      day: '화',
      minutes: 80,
    ),
    _WeeklyStudyData(
      day: '수',
      minutes: 30,
    ),
    _WeeklyStudyData(
      day: '목',
      minutes: 60,
    ),
    _WeeklyStudyData(
      day: '금',
      minutes: 40,
    ),
    _WeeklyStudyData(
      day: '토',
      minutes: 45,
    ),
    _WeeklyStudyData(
      day: '일',
      minutes: 15,
    ),
  ];

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
  ];

  @override
  Widget build(BuildContext context) {
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

              const _StudySummaryCard(),
              const SizedBox(height: 24),

              _SectionTitle(
                title: _getStudySectionTitle(),
              ),
              const SizedBox(height: 12),

              _WeeklyStudyChart(
                weeklyData: _weeklyStudyData,
              ),

              const SizedBox(height: 24),

              _SectionTitle(
                title: _selectedPeriodIndex == 0
                    ? '이번 주 상세 기록'
                    : '학습 상세 기록',
              ),

              const SizedBox(height: 8),

              _buildWeeklyRecordList(),
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
              borderRadius:
              BorderRadius.circular(13),
              child: InkWell(
                borderRadius:
                BorderRadius.circular(13),
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
    }

    if (_selectedPeriodIndex == 1) {
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
    }

    if (_selectedPeriodIndex == 1) {
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
    Duration(
      days: date.weekday - 1,
    ),
  );
}

String _getPeriodText() {
  if (_selectedPeriodIndex == 0) {
    final DateTime startDate =
    _getStartOfWeek(_focusedDate);

    final DateTime endDate = startDate.add(
      const Duration(days: 6),
    );

    return '${startDate.month}월 ${startDate.day}일'
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
    return '이번 주 학습';
  }

  if (_selectedPeriodIndex == 1) {
    return '이번 달 학습';
  }

  return '전체 학습';
}

  List<_StudyRecordData> _getWeeklyRecords() {
    final DateTime startDate =
    _getStartOfWeek(_focusedDate);

    final DateTime endDate = startDate.add(
      const Duration(days: 7),
    );

    final List<_StudyRecordData> weeklyRecords =
    _studyRecords.where((record) {
      final DateTime studiedDate = DateTime(
        record.studiedAt.year,
        record.studiedAt.month,
        record.studiedAt.day,
      );

      return !studiedDate.isBefore(startDate) &&
          studiedDate.isBefore(endDate);
    }).toList();

    weeklyRecords.sort((a, b) {
      return a.studiedAt.compareTo(
        b.studiedAt,
      );
    });

    return weeklyRecords;
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

    final List<_StudyRecordData> monthlyRecords =
    _studyRecords.where((record) {
      return !record.studiedAt.isBefore(startDate) &&
          record.studiedAt.isBefore(endDate);
    }).toList();

    monthlyRecords.sort((a, b) {
      return a.studiedAt.compareTo(
        b.studiedAt,
      );
    });

    return monthlyRecords;
  }

  int _getWeekNumberOfMonth(
      DateTime date,
      ) {
    return ((date.day - 1) ~/ 7) + 1;
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

  int _getTotalMinutes(
      List<_StudyRecordData> records,
      ) {
    int totalMinutes = 0;

    for (final record in records) {
      totalMinutes += record.minutes;
    }

    return totalMinutes;
  }

  Widget _buildWeeklyRecordList() {
    final List<_StudyRecordData> weeklyRecords =
    _getWeeklyRecords();

    if (_selectedPeriodIndex != 0) {
      return AppCard(
        child: const Padding(
          padding: EdgeInsets.symmetric(
            vertical: 24,
          ),
          child: Center(
            child: Text(
              '월간·전체 상세 기록은 다음 단계에서 적용됩니다.',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF9AA0AC),
              ),
            ),
          ),
        ),
      );
    }

    if (weeklyRecords.isEmpty) {
      return AppCard(
        child: const Padding(
          padding: EdgeInsets.symmetric(
            vertical: 28,
          ),
          child: Column(
            children: [
              Icon(
                Icons.menu_book_outlined,
                size: 34,
                color: Color(0xFFB4B8C2),
              ),
              SizedBox(height: 12),
              Text(
                '이번 주 학습 기록이 없습니다.',
                style: TextStyle(
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

    final Map<DateTime, List<_StudyRecordData>>
    groupedRecords =
    _groupRecordsByDate(weeklyRecords);

    final List<DateTime> dates =
    groupedRecords.keys.toList();

    dates.sort();

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
                  '총 $totalMinutes분',
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

}
class _StudySummaryCard extends StatelessWidget {
  const _StudySummaryCard();

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
            '조금씩 꾸준히 공부하면 목표에 가까워집니다.',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF9AA0AC),
            ),
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              const Expanded(
                child: _SummaryValue(
                  icon: Icons.today_outlined,
                  label: '오늘 학습',
                  value: '50분',
                ),
              ),
              Container(
                width: 1,
                height: 45,
                color: const Color(0xFFF0F0F2),
              ),
              const Expanded(
                child: _SummaryValue(
                  icon: Icons.date_range_outlined,
                  label: '이번 주',
                  value: '5시간 20분',
                ),
              ),
              Container(
                width: 1,
                height: 45,
                color: const Color(0xFFF0F0F2),
              ),
              const Expanded(
                child: _SummaryValue(
                  icon: Icons.local_fire_department_outlined,
                  label: '연속 학습',
                  value: '4일',
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
          style: const TextStyle(
            fontSize: 15,
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
}

class _WeeklyStudyChart extends StatelessWidget {
  final List<_WeeklyStudyData> weeklyData;

  const _WeeklyStudyChart({
    required this.weeklyData,
  });

  @override
  Widget build(BuildContext context) {
    final int maxMinutes = weeklyData
        .map((data) => data.minutes)
        .reduce((current, next) {
      return current > next ? current : next;
    });

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.bar_chart,
                size: 20,
                color: Color(0xFFF0788F),
              ),
              SizedBox(width: 8),
              Text(
                '총 5시간 20분',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              Spacer(),
              Text(
                '지난주보다 40분 증가',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFFF0788F),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          SizedBox(
            height: 170,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: weeklyData.map((data) {
                final double heightRatio =
                maxMinutes == 0 ? 0 : data.minutes / maxMinutes;

                final double barHeight =
                data.minutes == 0 ? 4 : 100 * heightRatio;

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
                        data.day,
                        style: const TextStyle(
                          fontSize: 12,
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
        crossAxisAlignment: CrossAxisAlignment.start,
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        record.subject,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${record.minutes}분',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
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

class _WeeklyStudyData {
  final String day;
  final int minutes;

  const _WeeklyStudyData({
    required this.day,
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