import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../widgets/app_confirm_dialog.dart';
import '../../widgets/app_date_time_sheets.dart';
import '../../widgets/app_dialog.dart';

import '../../theme.dart';
import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../widgets/app_card.dart';
import '../../widgets/app_main_background.dart';
import '../../widgets/app_top_bar.dart';
import '../../certificate/widgets/certificate_schedule_widgets.dart';

class MyPageCalendarScreen extends StatefulWidget {
  const MyPageCalendarScreen({super.key});

  @override
  State<MyPageCalendarScreen> createState() => _MyPageCalendarScreenState();
}

class _MyPageCalendarScreenState extends State<MyPageCalendarScreen> {
  int _selectedTabIndex = 0;

  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  DateTime _selectedDate = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );

  final List<CalendarScheduleItem> _schedules = [];
  bool _isLoadingSchedules = true;
  String? _scheduleLoadError;

  @override
  void initState() {
    super.initState();
    _loadSchedules();
  }

  CollectionReference<Map<String, dynamic>>? get _userScheduleCollection {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return null;
    }

    return FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .collection('calendarEvents');
  }

  Future<void> _loadSchedules() async {
    final User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      if (!mounted) {
        return;
      }

      setState(() {
        _schedules.clear();
        _isLoadingSchedules = false;
        _scheduleLoadError = '로그인 정보를 확인할 수 없습니다.';
      });

      return;
    }

    if (mounted) {
      setState(() {
        _isLoadingSchedules = true;
        _scheduleLoadError = null;
      });
    }

    try {
      final List<QuerySnapshot<Map<String, dynamic>>> snapshots =
          await Future.wait([
            FirebaseFirestore.instance
                .collection('users')
                .doc(currentUser.uid)
                .collection('calendarEvents')
                .get(),

            FirebaseFirestore.instance
                .collection('users')
                .doc(currentUser.uid)
                .collection('studyPlans')
                .get(),
          ]);

      final QuerySnapshot<Map<String, dynamic>> calendarEventSnapshot =
          snapshots[0];

      final QuerySnapshot<Map<String, dynamic>> studyPlanSnapshot =
          snapshots[1];

      final List<CalendarScheduleItem> loadedSchedules =
          <CalendarScheduleItem>[];

      for (final QueryDocumentSnapshot<Map<String, dynamic>> document
          in calendarEventSnapshot.docs) {
        final Map<String, dynamic> data = document.data();

        final Timestamp? startTimestamp = data['startAt'] as Timestamp?;

        if (startTimestamp == null) {
          continue;
        }

        final DateTime startAt = startTimestamp.toDate();

        final Timestamp? endTimestamp = data['endAt'] as Timestamp?;

        final DateTime? endAt = endTimestamp?.toDate();

        final bool allDay = data['allDay'] as bool? ?? false;

        final String eventType = ((data['eventType'] as String?) ?? 'CUSTOM')
            .trim()
            .toUpperCase();

        final String certificateName =
            ((data['certificateName'] as String?) ?? '').trim();

        final String scheduleName = ((data['scheduleName'] as String?) ?? '')
            .trim();

        final String description = scheduleName.isNotEmpty
            ? scheduleName
            : certificateName;

        loadedSchedules.add(
          CalendarScheduleItem(
            id: document.id,
            title: (data['title'] as String?)?.trim().isNotEmpty == true
                ? (data['title'] as String).trim()
                : '일정',
            description: description,
            date: _dateOnly(startAt),
            startTime: allDay ? null : TimeOfDay.fromDateTime(startAt),
            endTime: allDay || endAt == null
                ? null
                : TimeOfDay.fromDateTime(endAt),
            type: _calendarTypeFromEventType(eventType),
          ),
        );
      }

      for (final QueryDocumentSnapshot<Map<String, dynamic>> document
          in studyPlanSnapshot.docs) {
        final Map<String, dynamic> data = document.data();

        final Object? rawSteps = data['steps'];

        if (rawSteps is! List) {
          continue;
        }

        final DateTime recommendedStartDate = _readRecommendedStudyStartDate(
          data['recommendedStudyStartDate'],
        );

        final String certificateName =
            ((data['certificateName'] as String?) ?? '').trim();

        for (int index = 0; index < rawSteps.length; index++) {
          final Object? rawStep = rawSteps[index];

          if (rawStep is! Map) {
            continue;
          }

          final Map<String, dynamic> step = Map<String, dynamic>.from(rawStep);

          final String dayLabel = ((step['dayLabel'] as String?) ?? '').trim();

          final DateTime scheduleDate = _readAiPlanStepDate(
            dayLabel: dayLabel,
            recommendedStartDate: recommendedStartDate,
            fallbackIndex: index,
          );

          final String title = ((step['title'] as String?) ?? '').trim();

          final String detail = ((step['detail'] as String?) ?? '').trim();

          loadedSchedules.add(
            CalendarScheduleItem(
              id: '${document.id}_step_$index',
              title: title.isNotEmpty ? title : '학습 계획',
              description: detail.isNotEmpty ? detail : certificateName,
              date: scheduleDate,
              startTime: null,
              endTime: null,
              type: CalendarScheduleType.aiPlan,
            ),
          );
        }
      }

      loadedSchedules.sort(_compareSchedules);

      if (!mounted) {
        return;
      }

      setState(() {
        _schedules
          ..clear()
          ..addAll(loadedSchedules);

        _isLoadingSchedules = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _schedules.clear();
        _isLoadingSchedules = false;
        _scheduleLoadError = '일정을 불러오지 못했습니다.';
      });
    }
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  DateTime _readRecommendedStudyStartDate(Object? value) {
    if (value is Timestamp) {
      final DateTime date = value.toDate();

      return DateTime(date.year, date.month, date.day);
    }

    if (value is DateTime) {
      return DateTime(value.year, value.month, value.day);
    }

    if (value is String) {
      final DateTime? parsedDate = DateTime.tryParse(value.trim());

      if (parsedDate != null) {
        return DateTime(parsedDate.year, parsedDate.month, parsedDate.day);
      }
    }

    final DateTime now = DateTime.now();

    return DateTime(now.year, now.month, now.day);
  }

  DateTime _readAiPlanStepDate({
    required String dayLabel,
    required DateTime recommendedStartDate,
    required int fallbackIndex,
  }) {
    final RegExpMatch? match = RegExp(
      r'(\d{1,2})/(\d{1,2})',
    ).firstMatch(dayLabel);

    if (match == null) {
      return recommendedStartDate.add(Duration(days: fallbackIndex));
    }

    final int? month = int.tryParse(match.group(1) ?? '');

    final int? day = int.tryParse(match.group(2) ?? '');

    if (month == null || day == null) {
      return recommendedStartDate.add(Duration(days: fallbackIndex));
    }

    int year = recommendedStartDate.year;

    if (month < recommendedStartDate.month) {
      year += 1;
    }

    return DateTime(year, month, day);
  }

  CalendarScheduleType _calendarTypeFromEventType(String eventType) {
    switch (eventType) {
      case 'EXAM':
      case 'APPLICATION':
      case 'RESULT':
        return CalendarScheduleType.certificate;
      case 'STUDY':
        return CalendarScheduleType.aiPlan;
      case 'CUSTOM':
      default:
        return CalendarScheduleType.user;
    }
  }

  int _compareSchedules(CalendarScheduleItem a, CalendarScheduleItem b) {
    final int dateComparison = a.date.compareTo(b.date);
    if (dateComparison != 0) {
      return dateComparison;
    }

    final int aMinutes = a.startTime == null
        ? -1
        : a.startTime!.hour * 60 + a.startTime!.minute;
    final int bMinutes = b.startTime == null
        ? -1
        : b.startTime!.hour * 60 + b.startTime!.minute;
    return aMinutes.compareTo(bMinutes);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppTopBar(title: '캘린더'),
      body: AppMainBackground(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: CertificateScheduleTabSelector(
                selectedIndex: _selectedTabIndex,
                onChanged: (index) {
                  setState(() {
                    _selectedTabIndex = index;
                  });
                },
              ),
            ),
            SizedBox(height: 16),
            if (_isLoadingSchedules)
              LinearProgressIndicator(
                minHeight: 2,
                color: context.colors.pinkStart,
                backgroundColor: context.colors.pinkSoft,
              ),
            if (_scheduleLoadError != null)
              Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _scheduleLoadError!,
                        style: TextStyle(color: context.colors.textSecondary),
                      ),
                    ),
                    TextButton(onPressed: _loadSchedules, child: Text('다시 시도')),
                  ],
                ),
              ),
            Expanded(
              child: IndexedStack(
                index: _selectedTabIndex,
                children: [_buildCalendarTab(), _buildListTab()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabSelector() {
    return Container(
      height: 52,
      padding: EdgeInsets.all(5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [context.colors.pinkSoftAlt, context.colors.lavender],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.colors.pinkBorder, width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTabButton(
              index: 0,
              icon: Icons.calendar_month_outlined,
              title: '캘린더',
            ),
          ),
          Expanded(
            child: _buildTabButton(
              index: 1,
              icon: Icons.format_list_bulleted_rounded,
              title: '리스트',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required int index,
    required IconData icon,
    required String title,
  }) {
    final bool isSelected = _selectedTabIndex == index;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (_selectedTabIndex == index) {
          return;
        }

        setState(() {
          _selectedTabIndex = index;
        });
      },
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? context.colors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(13),
          border: isSelected
              ? Border.all(color: context.colors.pinkBorder, width: 1)
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 19,
              color: isSelected
                  ? context.colors.pinkStart
                  : context.colors.textSecondary,
            ),
            SizedBox(width: 7),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? context.colors.pinkStart
                    : context.colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarTab() {
    final List<CalendarScheduleItem> selectedSchedules = _getSchedulesForDate(
      _selectedDate,
    );

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildCalendarCard(),
                SizedBox(height: 20),
                _buildSelectedDateHeader(),
                SizedBox(height: 12),
                if (selectedSchedules.isEmpty)
                  _buildEmptyScheduleCard()
                else
                  ...selectedSchedules.map(
                    (schedule) => Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: _buildScheduleCard(schedule),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: _buildAddScheduleButton(),
        ),
      ],
    );
  }

  Widget _buildListTab() {
    final List<CalendarScheduleItem> monthlySchedules = _getSchedulesForMonth(
      _focusedMonth,
    );

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: _buildListMonthHeader(),
        ),
        SizedBox(height: 14),
        Expanded(
          child: monthlySchedules.isEmpty
              ? SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: _buildEmptyMonthlyScheduleCard(),
                )
              : ListView.builder(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                  itemCount: monthlySchedules.length,
                  itemBuilder: (context, index) {
                    final CalendarScheduleItem schedule =
                        monthlySchedules[index];

                    final bool showDateHeader =
                        index == 0 ||
                        !_isSameDate(
                          schedule.date,
                          monthlySchedules[index - 1].date,
                        );

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (showDateHeader) ...[
                          if (index != 0) SizedBox(height: 10),
                          _buildListDateHeader(schedule.date),
                          SizedBox(height: 10),
                        ],
                        Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: _buildScheduleCard(schedule),
                        ),
                      ],
                    );
                  },
                ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: _buildAddScheduleButton(),
        ),
      ],
    );
  }

  Widget _buildListMonthHeader() {
    return Row(
      children: [
        IconButton(
          tooltip: '이전 달',
          onPressed: _moveToPreviousMonth,
          icon: Icon(
            Icons.chevron_left_rounded,
            size: 27,
            color: context.colors.iconPrimary,
          ),
        ),
        Expanded(
          child: Text(
            '${_focusedMonth.year}년 '
            '${_focusedMonth.month}월',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: context.colors.iconPrimary,
            ),
          ),
        ),
        IconButton(
          tooltip: '다음 달',
          onPressed: _moveToNextMonth,
          icon: Icon(
            Icons.chevron_right_rounded,
            size: 27,
            color: context.colors.iconPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildListDateHeader(DateTime date) {
    List<String> weekdays = ['월', '화', '수', '목', '금', '토', '일'];

    return Padding(
      padding: EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Text(
            '${date.month}월 ${date.day}일',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: context.colors.textPrimary,
            ),
          ),
          SizedBox(width: 7),
          Text(
            '${weekdays[date.weekday - 1]}요일',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: context.colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyMonthlyScheduleCard() {
    return AppCard(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 34),
        child: Column(
          children: [
            Icon(
              Icons.event_busy_outlined,
              size: 44,
              color: context.colors.textMuted,
            ),
            SizedBox(height: 12),
            Text(
              '이번 달에 등록된 일정이 없습니다.',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: context.colors.textPrimary,
              ),
            ),
            SizedBox(height: 6),
            Text(
              '일정 추가 버튼을 눌러\n새로운 일정을 등록해보세요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: context.colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarCard() {
    return AppCard(
      child: Column(
        children: [
          _buildMonthHeader(),
          SizedBox(height: 14),
          TableCalendar<CalendarScheduleItem>(
            firstDay: DateTime(2020, 1, 1),
            lastDay: DateTime(2035, 12, 31),
            focusedDay: _focusedMonth,
            selectedDayPredicate: (day) => _isSameDate(day, _selectedDate),
            eventLoader: _getSchedulesForDate,
            calendarFormat: CalendarFormat.month,
            availableCalendarFormats: const {CalendarFormat.month: '월'},
            headerVisible: false,
            startingDayOfWeek: StartingDayOfWeek.sunday,
            rowHeight: 52,
            daysOfWeekHeight: 32,
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDate = _dateOnly(selectedDay);
                _focusedMonth = DateTime(focusedDay.year, focusedDay.month);
              });
            },
            onPageChanged: (focusedDay) {
              setState(() {
                _focusedMonth = DateTime(focusedDay.year, focusedDay.month);
              });
            },
            calendarBuilders: CalendarBuilders<CalendarScheduleItem>(
              markerBuilder: (context, day, events) {
                if (events.isEmpty) return null;
                final types = events.map((event) => event.type).toSet().take(3);
                final isSelected = _isSameDate(day, _selectedDate);
                return Positioned(
                  bottom: 5,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: types
                        .map(
                          (type) => Container(
                            width: 6,
                            height: 6,
                            margin: EdgeInsets.symmetric(horizontal: 1.5),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? context.colors.onPrimary
                                  : _getScheduleColor(type),
                              shape: BoxShape.circle,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                );
              },
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: TextStyle(
                color: context.colors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              weekendStyle: TextStyle(
                color: context.colors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            calendarStyle: CalendarStyle(
              outsideDaysVisible: true,
              outsideTextStyle: TextStyle(
                color: context.colors.textMuted.withValues(alpha: 0.35),
                fontSize: 14,
              ),
              defaultTextStyle: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              weekendTextStyle: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              todayDecoration: BoxDecoration(
                color: context.colors.pinkSoft,
                shape: BoxShape.circle,
              ),
              todayTextStyle: TextStyle(
                color: context.colors.pinkDeep,
                fontWeight: FontWeight.w700,
              ),
              selectedDecoration: BoxDecoration(
                color: context.colors.pinkDeep,
                shape: BoxShape.circle,
              ),
              selectedTextStyle: TextStyle(
                color: context.colors.onPrimary,
                fontWeight: FontWeight.w700,
              ),
              markersMaxCount: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthHeader() {
    return Row(
      children: [
        IconButton(
          tooltip: '이전 달',
          onPressed: _moveToPreviousMonth,
          icon: Icon(
            Icons.chevron_left_rounded,
            color: context.colors.textSecondary,
          ),
        ),
        Expanded(
          child: Text(
            '${_focusedMonth.year}년 ${_focusedMonth.month}월',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: context.colors.textPrimary,
            ),
          ),
        ),
        IconButton(
          tooltip: '다음 달',
          onPressed: _moveToNextMonth,
          icon: Icon(
            Icons.chevron_right_rounded,
            color: context.colors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildWeekdayHeader() {
    List<String> weekdays = ['일', '월', '화', '수', '목', '금', '토'];

    return Row(
      children: List.generate(weekdays.length, (index) {
        Color textColor = context.colors.textSecondary;

        if (index == 0) {
          textColor = context.colors.pinkStart;
        }

        if (index == 6) {
          textColor = context.colors.info;
        }

        return Expanded(
          child: Text(
            weekdays[index],
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildCalendarGrid() {
    final DateTime firstDayOfMonth = DateTime(
      _focusedMonth.year,
      _focusedMonth.month,
      1,
    );

    final int daysInMonth = DateTime(
      _focusedMonth.year,
      _focusedMonth.month + 1,
      0,
    ).day;

    final int leadingEmptyCount = firstDayOfMonth.weekday % 7;

    final int totalCellCount = ((leadingEmptyCount + daysInMonth + 6) ~/ 7) * 7;

    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 0.82,
      ),
      itemCount: totalCellCount,
      itemBuilder: (context, index) {
        final int dayNumber = index - leadingEmptyCount + 1;

        if (dayNumber < 1 || dayNumber > daysInMonth) {
          return SizedBox.shrink();
        }

        final DateTime date = DateTime(
          _focusedMonth.year,
          _focusedMonth.month,
          dayNumber,
        );

        return _buildCalendarDay(date);
      },
    );
  }

  Widget _buildCalendarDay(DateTime date) {
    final bool isSelected = _isSameDate(date, _selectedDate);

    final bool isToday = _isSameDate(date, DateTime.now());

    final List<CalendarScheduleItem> daySchedules = _getSchedulesForDate(date);

    Color dayTextColor = context.colors.textPrimary;

    if (date.weekday == DateTime.sunday) {
      dayTextColor = context.colors.pinkStart;
    }

    if (date.weekday == DateTime.saturday) {
      dayTextColor = context.colors.info;
    }

    if (isSelected) {
      dayTextColor = context.colors.onPrimary;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        setState(() {
          _selectedDate = date;
        });
      },
      child: Container(
        margin: EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isSelected ? context.colors.pinkStart : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isToday && !isSelected
              ? Border.all(color: context.colors.pinkStart, width: 1.5)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${date.day}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected || isToday
                    ? FontWeight.w700
                    : FontWeight.w500,
                color: dayTextColor,
              ),
            ),
            SizedBox(height: 4),
            _buildScheduleDots(daySchedules, isSelected),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleDots(
    List<CalendarScheduleItem> schedules,
    bool isSelected,
  ) {
    if (schedules.isEmpty) {
      return SizedBox(height: 6);
    }

    final List<CalendarScheduleType> types = schedules
        .map((schedule) => schedule.type)
        .toSet()
        .take(3)
        .toList();

    return SizedBox(
      height: 6,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: types.map((type) {
          return Container(
            width: 5,
            height: 5,
            margin: EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected
                  ? context.colors.onPrimary
                  : _getScheduleColor(type),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSelectedDateHeader() {
    return Row(
      children: [
        Expanded(
          child: Text(
            _formatSelectedDate(_selectedDate),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: context.colors.textPrimary,
            ),
          ),
        ),
        Text(
          '${_getSchedulesForDate(_selectedDate).length}개 일정',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.colors.pinkStart,
          ),
        ),
      ],
    );
  }

  Widget _buildScheduleCard(CalendarScheduleItem schedule) {
    final CalendarTypeStyle style = _getTypeStyle(schedule.type);

    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: style.backgroundColor,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(style.icon, size: 22, color: style.foregroundColor),
          ),
          SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: style.backgroundColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        style.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: style.foregroundColor,
                        ),
                      ),
                    ),
                    if (schedule.startTime != null) ...[
                      SizedBox(width: 8),
                      Text(
                        _formatScheduleTime(schedule),
                        style: TextStyle(
                          fontSize: 12,
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  schedule.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: '일정 메뉴',
            color: context.colors.surface,
            icon: Icon(
              Icons.more_vert_rounded,
              color: context.colors.textSecondary,
            ),
            onSelected: (String value) {
              if (value == 'calendar') {
                _addScheduleToPhoneCalendar(schedule);
              }

              if (value == 'edit') {
                _showAddScheduleDialog(editingSchedule: schedule);
              }

              if (value == 'delete') {
                _showDeleteScheduleDialog(schedule);
              }
            },
            itemBuilder: (context) {
              return [
                PopupMenuItem<String>(
                  value: 'calendar',
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_month_outlined,
                        size: 20,
                        color: context.colors.pinkStart,
                      ),
                      SizedBox(width: 10),
                      Text('휴대폰 캘린더에 추가'),
                    ],
                  ),
                ),

                // 사용자 직접 일정에만 수정과 삭제 메뉴 표시
                if (schedule.type == CalendarScheduleType.user) ...[
                  PopupMenuItem<String>(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(
                          Icons.edit_outlined,
                          size: 20,
                          color: context.colors.mintAccent,
                        ),
                        SizedBox(width: 10),
                        Text('일정 수정'),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline_rounded,
                          size: 20,
                          color: context.colors.incorrect,
                        ),
                        SizedBox(width: 10),
                        Text('일정 삭제'),
                      ],
                    ),
                  ),
                ],
              ];
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyScheduleCard() {
    return AppCard(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Column(
          children: [
            Icon(
              Icons.event_available_outlined,
              size: 44,
              color: context.colors.textMuted,
            ),
            SizedBox(height: 12),
            Text(
              '등록된 일정이 없습니다.',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: context.colors.textPrimary,
              ),
            ),
            SizedBox(height: 6),
            Text(
              '일정 추가 버튼을 눌러\n새로운 일정을 등록해보세요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: context.colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddScheduleButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: () {
          _showAddScheduleDialog();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: context.colors.pinkStart,
          foregroundColor: context.colors.onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: Icon(Icons.add_rounded),
        label: Text(
          '일정 추가',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  void _moveToPreviousMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);

      _selectedDate = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    });
  }

  void _moveToNextMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);

      _selectedDate = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    });
  }


  String? _validateScheduleInput({
    required String title,
    required TimeOfDay? startTime,
    required TimeOfDay? endTime,
  }) {
    if (title.trim().isEmpty) {
      return '일정 이름을 입력해주세요.';
    }

    if (startTime == null && endTime != null) {
      return '종료 시간을 선택하려면 시작 시간도 선택해주세요.';
    }

    if (startTime != null && endTime != null) {
      final int startMinutes = startTime.hour * 60 + startTime.minute;
      final int endMinutes = endTime.hour * 60 + endTime.minute;

      if (endMinutes <= startMinutes) {
        return '종료 시간은 시작 시간보다 늦어야 합니다.';
      }
    }

    return null;
  }

  Future<void> _showAddScheduleDialog({
    CalendarScheduleItem? editingSchedule,
  }) async {
    final bool isEditing = editingSchedule != null;

    final TextEditingController titleController = TextEditingController(
      text: editingSchedule?.title ?? '',
    );

    DateTime selectedDate = editingSchedule?.date ?? _selectedDate;
    TimeOfDay? startTime = editingSchedule?.startTime;
    TimeOfDay? endTime = editingSchedule?.endTime;

    final GlobalKey<_AddScheduleFormState> formKey =
    GlobalKey<_AddScheduleFormState>();

    final bool? result = await AppConfirmDialog.show<bool>(
      context,
      icon: isEditing ? Icons.edit_calendar_outlined : Icons.event_note_outlined,
      title: isEditing ? '일정 수정' : '일정 추가',
      description: '일정 정보를 입력해주세요.',
      primaryLabel: isEditing ? '수정' : '추가',
      secondaryLabel: '취소',
      onSecondaryPressed: () => Navigator.pop(context, false),
      onPrimaryPressed: () {
        final String? validationMessage = _validateScheduleInput(
          title: titleController.text,
          startTime: startTime,
          endTime: endTime,
        );

        if (validationMessage != null) {
          formKey.currentState?.showValidationError(validationMessage);
          return;
        }

        FocusManager.instance.primaryFocus?.unfocus();
        Navigator.pop(context, true);
      },
      extra: _AddScheduleForm(
        key: formKey,
        titleController: titleController,
        initialDate: selectedDate,
        initialStartTime: startTime,
        initialEndTime: endTime,
        onDateChanged: (date) => selectedDate = date,
        onStartTimeChanged: (time) => startTime = time,
        onEndTimeChanged: (time) => endTime = time,
      ),
    );

    if (result == true) {
      // no-op: 실제 저장은 아래에서 처리
    }

    if (result != true) {
      titleController.dispose();
      return;
    }

    final String title = titleController.text.trim();
    titleController.dispose();

    final CollectionReference<Map<String, dynamic>>? collection =
        _userScheduleCollection;
    if (collection == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('로그인 정보를 확인할 수 없습니다.')));
      }
      return;
    }

    try {
      final DocumentReference<Map<String, dynamic>> document = isEditing
          ? collection.doc(editingSchedule!.id)
          : collection.doc();

      final bool allDay = startTime == null;
      final DateTime startAt = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        startTime?.hour ?? 0,
        startTime?.minute ?? 0,
      );
      final DateTime? endAt = endTime == null
          ? null
          : DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        endTime!.hour,
        endTime!.minute,
      );

      final Map<String, dynamic> data = {
        'eventType': 'CUSTOM',
        'title': title,
        'certificateId': null,
        'certificateName': null,
        'scheduleId': null,
        'scheduleName': null,
        'goalId': null,
        'colorCode': '#4A8F73',
        'startAt': Timestamp.fromDate(startAt),
        'endAt': endAt == null ? null : Timestamp.fromDate(endAt),
        'allDay': allDay,
        'updatedAt': FieldValue.serverTimestamp(),
        if (!isEditing) 'createdAt': FieldValue.serverTimestamp(),
      };

      await document.set(data, SetOptions(merge: true));

      if (!mounted) {
        return;
      }

      setState(() {
        _focusedMonth = DateTime(selectedDate.year, selectedDate.month);
        _selectedDate = _dateOnly(selectedDate);
      });
      await _loadSchedules();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isEditing ? '일정이 수정되었습니다.' : '일정이 추가되었습니다.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEditing ? '일정을 수정하지 못했습니다.' : '일정을 추가하지 못했습니다.'),
        ),
      );
    }
  }

  Future<void> _addScheduleToPhoneCalendar(
    CalendarScheduleItem schedule,
  ) async {
    // 시작 시간이 없는 일정은 종일 일정으로 처리
    final bool isAllDay = schedule.startTime == null;

    late DateTime startDate;
    late DateTime endDate;

    if (isAllDay) {
      // 자격증 일정처럼 시간이 없는 경우
      startDate = DateTime(
        schedule.date.year,
        schedule.date.month,
        schedule.date.day,
      );

      // 종일 일정의 종료일은 다음 날 0시로 지정
      endDate = startDate.add(Duration(days: 1));
    } else {
      // 시작 시간이 있는 경우 날짜와 시간을 합침
      startDate = DateTime(
        schedule.date.year,
        schedule.date.month,
        schedule.date.day,
        schedule.startTime!.hour,
        schedule.startTime!.minute,
      );

      if (schedule.endTime != null) {
        // 종료 시간이 있으면 해당 시간 사용
        endDate = DateTime(
          schedule.date.year,
          schedule.date.month,
          schedule.date.day,
          schedule.endTime!.hour,
          schedule.endTime!.minute,
        );
      } else {
        // 종료 시간이 없으면 시작 시간으로부터 1시간 뒤
        endDate = startDate.add(Duration(hours: 1));
      }
    }

    final Event event = Event(
      title: schedule.title,
      description: schedule.description,
      startDate: startDate,
      endDate: endDate,
      allDay: isAllDay,
    );

    final bool added = await Add2Calendar.addEvent2Cal(event);

    if (!mounted) {
      return;
    }

    if (added) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('휴대폰 캘린더 등록 화면을 열었습니다.')));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('휴대폰 캘린더를 열지 못했습니다.')));
    }
  }

  Future<void> _showDeleteScheduleDialog(CalendarScheduleItem schedule) async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AppAlertDialog(
          title: Text('일정 삭제', style: TextStyle(fontWeight: FontWeight.w700)),
          content: Text('${schedule.title} 일정을 삭제하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: Text(
                '취소',
                style: TextStyle(color: context.colors.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: Text(
                '삭제',
                style: TextStyle(
                  color: context.colors.incorrect,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (result != true) {
      return;
    }

    final CollectionReference<Map<String, dynamic>>? collection =
        _userScheduleCollection;
    if (collection == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('로그인 정보를 확인할 수 없습니다.')));
      }
      return;
    }

    try {
      await collection.doc(schedule.id).delete();
      await _loadSchedules();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('일정이 삭제되었습니다.')));
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('일정을 삭제하지 못했습니다.')));
    }
  }

  List<CalendarScheduleItem> _getSchedulesForDate(DateTime date) {
    final List<CalendarScheduleItem> items = _schedules.where((schedule) {
      return _isSameDate(schedule.date, date);
    }).toList();

    items.sort((a, b) {
      if (a.startTime == null && b.startTime == null) {
        return 0;
      }

      if (a.startTime == null) {
        return -1;
      }

      if (b.startTime == null) {
        return 1;
      }

      final int aMinutes = a.startTime!.hour * 60 + a.startTime!.minute;

      final int bMinutes = b.startTime!.hour * 60 + b.startTime!.minute;

      return aMinutes.compareTo(bMinutes);
    });

    return items;
  }

  List<CalendarScheduleItem> _getSchedulesForMonth(DateTime month) {
    final List<CalendarScheduleItem> items = _schedules.where((schedule) {
      return schedule.date.year == month.year &&
          schedule.date.month == month.month;
    }).toList();

    items.sort((a, b) {
      final int dateCompare = a.date.compareTo(b.date);

      if (dateCompare != 0) {
        return dateCompare;
      }

      if (a.startTime == null && b.startTime == null) {
        return 0;
      }

      if (a.startTime == null) {
        return -1;
      }

      if (b.startTime == null) {
        return 1;
      }

      final int aMinutes = a.startTime!.hour * 60 + a.startTime!.minute;

      final int bMinutes = b.startTime!.hour * 60 + b.startTime!.minute;

      return aMinutes.compareTo(bMinutes);
    });

    return items;
  }

  bool _isSameDate(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  String _formatSelectedDate(DateTime date) {
    List<String> weekdays = ['월', '화', '수', '목', '금', '토', '일'];

    return '${date.month}월 ${date.day}일 '
        '${weekdays[date.weekday - 1]}요일';
  }

  String _formatDate(DateTime date) {
    return '${date.year}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String _formatTimeOfDay(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
  }

  String _formatScheduleTime(CalendarScheduleItem schedule) {
    if (schedule.startTime == null) {
      return '';
    }

    final String start = _formatTimeOfDay(schedule.startTime!);

    if (schedule.endTime == null) {
      return start;
    }

    final String end = _formatTimeOfDay(schedule.endTime!);

    return '$start - $end';
  }

  Color _getScheduleColor(CalendarScheduleType type) {
    return _getTypeStyle(type).foregroundColor;
  }

  CalendarTypeStyle _getTypeStyle(CalendarScheduleType type) {
    switch (type) {
      case CalendarScheduleType.certificate:
        return CalendarTypeStyle(
          label: '자격증 일정',
          icon: Icons.workspace_premium_outlined,
          foregroundColor: context.colors.pinkStart,
          backgroundColor: context.colors.pinkSoft,
        );

      case CalendarScheduleType.aiPlan:
        return CalendarTypeStyle(
          label: '학습 계획',
          icon: Icons.auto_awesome_outlined,
          foregroundColor: context.colors.lavenderAccent,
          backgroundColor: context.colors.lavender,
        );

      case CalendarScheduleType.user:
        return CalendarTypeStyle(
          label: '내 일정',
          icon: Icons.edit_calendar_outlined,
          foregroundColor: context.colors.mintAccent,
          backgroundColor: context.colors.mint,
        );
    }
  }
}

enum CalendarScheduleType { certificate, aiPlan, user }

class CalendarScheduleItem {
  final String id;
  final String title;
  final String description;
  final DateTime date;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;
  final CalendarScheduleType type;

  CalendarScheduleItem({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.type,
    this.startTime,
    this.endTime,
  });
}

class CalendarTypeStyle {
  final String label;
  final IconData icon;
  final Color foregroundColor;
  final Color backgroundColor;

  CalendarTypeStyle({
    required this.label,
    required this.icon,
    required this.foregroundColor,
    required this.backgroundColor,
  });
}

class _DialogSelectTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  const _DialogSelectTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(13),
        decoration: BoxDecoration(
          border: Border.all(color: context.colors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: context.colors.pinkStart),
            SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.colors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: context.colors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _AddScheduleForm extends StatefulWidget {
  final TextEditingController titleController;
  final DateTime initialDate;
  final TimeOfDay? initialStartTime;
  final TimeOfDay? initialEndTime;
  final ValueChanged<DateTime> onDateChanged;
  final ValueChanged<TimeOfDay?> onStartTimeChanged;
  final ValueChanged<TimeOfDay?> onEndTimeChanged;

  const _AddScheduleForm({
    super.key,
    required this.titleController,
    required this.initialDate,
    required this.initialStartTime,
    required this.initialEndTime,
    required this.onDateChanged,
    required this.onStartTimeChanged,
    required this.onEndTimeChanged,
  });

  @override
  State<_AddScheduleForm> createState() => _AddScheduleFormState();
}

class _AddScheduleFormState extends State<_AddScheduleForm> {
  late DateTime _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  String? _validationMessage;

  void showValidationError(String message) {
    if (!mounted) return;
    setState(() {
      _validationMessage = message;
    });
  }

  void _clearValidationError() {
    if (_validationMessage == null) return;
    setState(() {
      _validationMessage = null;
    });
  }

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _startTime = widget.initialStartTime;
    _endTime = widget.initialEndTime;
  }

  String _formatDialogDate(DateTime date) {
    return '${date.year}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String _formatTimeOfDay(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.5,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_validationMessage != null) ...[
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: context.colors.incorrectSoft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: context.colors.incorrect.withOpacity(0.35),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 18,
                      color: context.colors.incorrect,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _validationMessage!,
                        style: TextStyle(
                          color: context.colors.incorrect,
                          fontSize: 13,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12),
            ],
            TextField(
              controller: widget.titleController,
              onChanged: (_) => _clearValidationError(),
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: '일정 이름',
                hintText: '예: 스터디 모임',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            SizedBox(height: 12),
            _DialogSelectTile(
              icon: Icons.calendar_month_outlined,
              title: '날짜',
              value: _formatDialogDate(_selectedDate),
              onTap: () async {
                final DateTime? pickedDate = await AppDatePickerSheet.show(
                  context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2025),
                  lastDate: DateTime(2035),
                  title: '일정 날짜',
                );
                if (pickedDate != null) {
                  setState(() {
                    _selectedDate = DateTime(
                      pickedDate.year,
                      pickedDate.month,
                      pickedDate.day,
                    );
                  });
                  widget.onDateChanged(_selectedDate);
                }
              },
            ),
            SizedBox(height: 10),
            _DialogSelectTile(
              icon: Icons.schedule_outlined,
              title: '시작 시간 (선택)',
              value: _startTime == null ? '선택' : _formatTimeOfDay(_startTime!),
              onTap: () async {
                final TimeOfDay? pickedTime = await AppTimePickerSheet.show(
                  context,
                  initialTime: _startTime ?? TimeOfDay.now(),
                  title: '시작 시간',
                );
                if (pickedTime != null) {
                  setState(() => _startTime = pickedTime);
                  widget.onStartTimeChanged(_startTime);
                  _clearValidationError();
                }
              },
            ),
            SizedBox(height: 10),
            _DialogSelectTile(
              icon: Icons.schedule_send_outlined,
              title: '종료 시간 (선택)',
              value: _endTime == null ? '선택' : _formatTimeOfDay(_endTime!),
              onTap: () async {
                final TimeOfDay? pickedTime = await AppTimePickerSheet.show(
                  context,
                  initialTime: _endTime ?? _startTime ?? TimeOfDay.now(),
                  title: '종료 시간',
                );
                if (pickedTime != null) {
                  setState(() => _endTime = pickedTime);
                  widget.onEndTimeChanged(_endTime);
                  _clearValidationError();
                }
              },
            ),
            if (_startTime != null || _endTime != null) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _startTime = null;
                      _endTime = null;
                    });
                    widget.onStartTimeChanged(null);
                    widget.onEndTimeChanged(null);
                  },
                  icon: const Icon(Icons.restart_alt_rounded, size: 18),
                  label: const Text('시간 초기화'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}