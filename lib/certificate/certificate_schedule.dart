import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../widgets/app_main_background.dart';
import '../widgets/app_top_bar.dart';

class CertificateSchedulePage extends StatefulWidget {
  const CertificateSchedulePage({super.key});

  @override
  State<CertificateSchedulePage> createState() =>
      _CertificateSchedulePageState();
}

class _CertificateSchedulePageState
    extends State<CertificateSchedulePage> {
  static const Color _primaryPink = Color(0xFFF286A2);
  static const Color _darkText = Color(0xFF302C2E);
  static const Color _grayText = Color(0xFF817B7D);
  static const Color _pinkSoft = Color(0xFFFBE7ED);

  int _selectedTabIndex = 0;

  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  // TODO: 추후 공공데이터 API 결과로 교체
  final List<CertificateSchedule> _schedules = [
    CertificateSchedule(
      certificateName: '정보처리기사',
      scheduleType: '필기시험',
      date: DateTime(2026, 7, 13),
      description: '2026년 정기 기사 2회 필기시험',
    ),
    CertificateSchedule(
      certificateName: '컴퓨터활용능력 1급',
      scheduleType: '원서접수 시작',
      date: DateTime(2026, 7, 13),
      description: '필기시험 원서접수',
    ),
    CertificateSchedule(
      certificateName: 'SQLD',
      scheduleType: '원서접수 마감',
      date: DateTime(2026, 7, 18),
      description: '제58회 SQL 개발자 시험',
    ),
    CertificateSchedule(
      certificateName: '정보처리기사',
      scheduleType: '실기시험',
      date: DateTime(2026, 7, 20),
      description: '2026년 정기 기사 2회 실기시험',
    ),
    CertificateSchedule(
      certificateName: '한국사능력검정시험',
      scheduleType: '시험일',
      date: DateTime(2026, 7, 25),
      description: '제79회 한국사능력검정시험',
    ),
    CertificateSchedule(
      certificateName: '산업안전기사',
      scheduleType: '합격자 발표',
      date: DateTime(2026, 7, 29),
      description: '최종 합격자 발표',
    ),
    CertificateSchedule(
      certificateName: '네트워크관리사 2급',
      scheduleType: '필기시험',
      date: DateTime(2026, 8, 9),
      description: '2026년 제3회 필기시험',
    ),
  ];

  List<CertificateSchedule> _getSchedulesForDay(DateTime day) {
    return _schedules.where((schedule) {
      return DateUtils.isSameDay(schedule.date, day);
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  List<CertificateSchedule> _getSchedulesForMonth(DateTime month) {
    return _schedules.where((schedule) {
      return schedule.date.year == month.year &&
          schedule.date.month == month.month;
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  void _moveMonth(int amount) {
    final newMonth = DateTime(
      _focusedDay.year,
      _focusedDay.month + amount,
      1,
    );

    setState(() {
      _focusedDay = newMonth;
      _selectedDay = newMonth;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppTopBar(
        title: '자격증 일정 조회',
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: _darkText,
            size: 21,
          ),
        ),
      ),
      body: AppMainBackground(
        child: Column(
          children: [
            const SizedBox(height: 12),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _ScheduleTabSelector(
                selectedIndex: _selectedTabIndex,
                onChanged: (index) {
                  setState(() {
                    _selectedTabIndex = index;
                  });
                },
              ),
            ),

            const SizedBox(height: 22),

            Expanded(
              child: IndexedStack(
                index: _selectedTabIndex,
                children: [
                  _buildCalendarTab(),
                  _buildListTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarTab() {
    final selectedSchedules = _getSchedulesForDay(_selectedDay);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
      child: Column(
        children: [
          _MonthHeader(
            focusedDay: _focusedDay,
            onPrevious: () => _moveMonth(-1),
            onNext: () => _moveMonth(1),
          ),

          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.035),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: TableCalendar<CertificateSchedule>(
              firstDay: DateTime(2020, 1, 1),
              lastDay: DateTime(2035, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) {
                return DateUtils.isSameDay(day, _selectedDay);
              },
              eventLoader: _getSchedulesForDay,
              calendarFormat: CalendarFormat.month,
              availableCalendarFormats: const {
                CalendarFormat.month: '월',
              },
              headerVisible: false,
              startingDayOfWeek: StartingDayOfWeek.sunday,
              rowHeight: 52,
              daysOfWeekHeight: 32,
              shouldFillViewport: false,

              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },

              onPageChanged: (focusedDay) {
                setState(() {
                  _focusedDay = focusedDay;
                  _selectedDay = DateTime(
                    focusedDay.year,
                    focusedDay.month,
                    1,
                  );
                });
              },

              daysOfWeekStyle: const DaysOfWeekStyle(
                weekdayStyle: TextStyle(
                  color: _grayText,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                weekendStyle: TextStyle(
                  color: _grayText,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),

              calendarStyle: CalendarStyle(
                outsideDaysVisible: true,
                outsideTextStyle: TextStyle(
                  color: _grayText.withValues(alpha: 0.35),
                  fontSize: 14,
                ),
                defaultTextStyle: const TextStyle(
                  color: _darkText,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                weekendTextStyle: const TextStyle(
                  color: _darkText,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                todayDecoration: BoxDecoration(
                  color: _pinkSoft,
                  shape: BoxShape.circle,
                ),
                todayTextStyle: const TextStyle(
                  color: _primaryPink,
                  fontWeight: FontWeight.w700,
                ),
                selectedDecoration: const BoxDecoration(
                  color: _primaryPink,
                  shape: BoxShape.circle,
                ),
                selectedTextStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
                markerDecoration: const BoxDecoration(
                  color: _primaryPink,
                  shape: BoxShape.circle,
                ),
                markerSize: 5,
                markersMaxCount: 3,
                markerMargin: const EdgeInsets.symmetric(horizontal: 1),
              ),
            ),
          ),

          const SizedBox(height: 28),

          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${_selectedDay.month}월 ${_selectedDay.day}일 일정',
              style: const TextStyle(
                color: _darkText,
                fontSize: 21,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
              ),
            ),
          ),

          const SizedBox(height: 14),

          if (selectedSchedules.isEmpty)
            const _EmptyScheduleCard(
              message: '선택한 날짜에 자격증 일정이 없습니다.',
            )
          else
            ...selectedSchedules.map(
                  (schedule) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ScheduleCard(schedule: schedule),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildListTab() {
    final monthlySchedules = _getSchedulesForMonth(_focusedDay);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _MonthHeader(
            focusedDay: _focusedDay,
            onPrevious: () => _moveMonth(-1),
            onNext: () => _moveMonth(1),
          ),
        ),

        const SizedBox(height: 18),

        Expanded(
          child: monthlySchedules.isEmpty
              ? const SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: _EmptyScheduleCard(
              message: '이번 달에 등록된 자격증 일정이 없습니다.',
            ),
          )
              : ListView.builder(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
            itemCount: monthlySchedules.length,
            itemBuilder: (context, index) {
              final schedule = monthlySchedules[index];

              final showDateHeader = index == 0 ||
                  !DateUtils.isSameDay(
                    schedule.date,
                    monthlySchedules[index - 1].date,
                  );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showDateHeader) ...[
                    if (index != 0) const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 4,
                        bottom: 10,
                      ),
                      child: Text(
                        '${schedule.date.month}월 '
                            '${schedule.date.day}일',
                        style: const TextStyle(
                          color: _darkText,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ScheduleCard(schedule: schedule),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ScheduleTabSelector extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _ScheduleTabSelector({
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F2F3),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TabButton(
              label: '캘린더',
              icon: Icons.calendar_month_outlined,
              selected: selectedIndex == 0,
              onTap: () => onChanged(0),
            ),
          ),
          Expanded(
            child: _TabButton(
              label: '리스트',
              icon: Icons.format_list_bulleted_rounded,
              selected: selectedIndex == 1,
              onTap: () => onChanged(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const primaryPink = Color(0xFFF286A2);
    const darkText = Color(0xFF302C2E);

    return Material(
      color: selected ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: selected
                ? [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 19,
                color: selected ? primaryPink : darkText,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: selected ? primaryPink : darkText,
                  fontSize: 15,
                  fontWeight:
                  selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  final DateTime focusedDay;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _MonthHeader({
    required this.focusedDay,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onPrevious,
          icon: const Icon(
            Icons.chevron_left_rounded,
            color: Color(0xFF302C2E),
            size: 28,
          ),
        ),
        Expanded(
          child: Text(
            '${focusedDay.year}년 ${focusedDay.month}월',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF302C2E),
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        IconButton(
          onPressed: onNext,
          icon: const Icon(
            Icons.chevron_right_rounded,
            color: Color(0xFF302C2E),
            size: 28,
          ),
        ),
      ],
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  final CertificateSchedule schedule;

  const _ScheduleCard({
    required this.schedule,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: const Color(0xFFFBE7ED),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.event_note_rounded,
              color: Color(0xFFF286A2),
              size: 22,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  schedule.certificateName,
                  style: const TextStyle(
                    color: Color(0xFF302C2E),
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  schedule.scheduleType,
                  style: const TextStyle(
                    color: Color(0xFFF286A2),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  schedule.description,
                  style: const TextStyle(
                    color: Color(0xFF817B7D),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          Text(
            '${schedule.date.month}.${schedule.date.day}',
            style: const TextStyle(
              color: Color(0xFF817B7D),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyScheduleCard extends StatelessWidget {
  final String message;

  const _EmptyScheduleCard({
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 34,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.event_busy_outlined,
            color: Color(0xFFB7B0B2),
            size: 30,
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF817B7D),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class CertificateSchedule {
  final String certificateName;
  final String scheduleType;
  final DateTime date;
  final String description;

  const CertificateSchedule({
    required this.certificateName,
    required this.scheduleType,
    required this.date,
    required this.description,
  });
}