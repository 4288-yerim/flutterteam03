import 'package:flutter/material.dart';
import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../widgets/app_card.dart';
import '../../widgets/app_main_background.dart';
import '../../widgets/app_top_bar.dart';

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
      final QuerySnapshot<Map<String, dynamic>> snapshot =
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('calendarEvents')
          .get();

      final List<CalendarScheduleItem> loadedSchedules = [];

      for (final QueryDocumentSnapshot<Map<String, dynamic>> document
      in snapshot.docs) {
        final Map<String, dynamic> data = document.data();
        final Timestamp? startTimestamp = data['startAt'] as Timestamp?;

        if (startTimestamp == null) {
          continue;
        }

        final DateTime startAt = startTimestamp.toDate();
        final Timestamp? endTimestamp = data['endAt'] as Timestamp?;
        final DateTime? endAt = endTimestamp?.toDate();
        final bool allDay = data['allDay'] as bool? ?? false;
        final String eventType =
        ((data['eventType'] as String?) ?? 'CUSTOM').trim().toUpperCase();
        final String certificateName =
        ((data['certificateName'] as String?) ?? '').trim();
        final String scheduleName =
        ((data['scheduleName'] as String?) ?? '').trim();
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

  CalendarScheduleType _calendarTypeFromEventType(String eventType) {
    switch (eventType) {
      case 'EXAM':
      case 'APPLICATION':
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
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: _buildTabSelector(),
            ),
            const SizedBox(height: 16),
            if (_isLoadingSchedules)
              const LinearProgressIndicator(
                minHeight: 2,
                color: Color(0xFFF0788F),
                backgroundColor: Color(0xFFFCEFF3),
              ),
            if (_scheduleLoadError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _scheduleLoadError!,
                        style: const TextStyle(color: Color(0xFF9AA0AC)),
                      ),
                    ),
                    TextButton(
                      onPressed: _loadSchedules,
                      child: const Text('다시 시도'),
                    ),
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
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFF0F5),
            Color(0xFFF7F2FF),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFF8DCE5),
          width: 1,
        ),
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
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(13),
          border: isSelected
              ? Border.all(
            color: const Color(0xFFF4C3D0),
            width: 1,
          )
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 19,
              color: isSelected
                  ? const Color(0xFFED6F8D)
                  : const Color(0xFF837985),
            ),
            const SizedBox(width: 7),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? const Color(0xFFED6F8D)
                    : const Color(0xFF837985),
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
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildCalendarCard(),
                const SizedBox(height: 20),
                _buildSelectedDateHeader(),
                const SizedBox(height: 12),
                if (selectedSchedules.isEmpty)
                  _buildEmptyScheduleCard()
                else
                  ...selectedSchedules.map(
                        (schedule) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildScheduleCard(schedule),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
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
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _buildListMonthHeader(),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: monthlySchedules.isEmpty
              ? SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: _buildEmptyMonthlyScheduleCard(),
          )
              : ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
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
                    if (index != 0) const SizedBox(height: 10),
                    _buildListDateHeader(schedule.date),
                    const SizedBox(height: 10),
                  ],
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildScheduleCard(schedule),
                  ),
                ],
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
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
          icon: const Icon(
            Icons.chevron_left_rounded,
            size: 27,
            color: Color(0xFF302C2E),
          ),
        ),
        Expanded(
          child: Text(
            '${_focusedMonth.year}년 '
                '${_focusedMonth.month}월',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: Color(0xFF302C2E),
            ),
          ),
        ),
        IconButton(
          tooltip: '다음 달',
          onPressed: _moveToNextMonth,
          icon: const Icon(
            Icons.chevron_right_rounded,
            size: 27,
            color: Color(0xFF302C2E),
          ),
        ),
      ],
    );
  }

  Widget _buildListDateHeader(DateTime date) {
    const List<String> weekdays = ['월', '화', '수', '목', '금', '토', '일'];

    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Text(
            '${date.month}월 ${date.day}일',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(width: 7),
          Text(
            '${weekdays[date.weekday - 1]}요일',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF9AA0AC),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyMonthlyScheduleCard() {
    return AppCard(
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 34),
        child: Column(
          children: [
            Icon(Icons.event_busy_outlined, size: 44, color: Color(0xFFB4B8C2)),
            SizedBox(height: 12),
            Text(
              '이번 달에 등록된 일정이 없습니다.',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
            ),
            SizedBox(height: 6),
            Text(
              '일정 추가 버튼을 눌러\n새로운 일정을 등록해보세요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: Color(0xFF9AA0AC),
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
          const SizedBox(height: 20),
          _buildWeekdayHeader(),
          const SizedBox(height: 10),
          _buildCalendarGrid(),
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
          icon: const Icon(
            Icons.chevron_left_rounded,
            color: Color(0xFF666A73),
          ),
        ),
        Expanded(
          child: Text(
            '${_focusedMonth.year}년 ${_focusedMonth.month}월',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A),
            ),
          ),
        ),
        IconButton(
          tooltip: '다음 달',
          onPressed: _moveToNextMonth,
          icon: const Icon(
            Icons.chevron_right_rounded,
            color: Color(0xFF666A73),
          ),
        ),
      ],
    );
  }

  Widget _buildWeekdayHeader() {
    const List<String> weekdays = ['일', '월', '화', '수', '목', '금', '토'];

    return Row(
      children: List.generate(weekdays.length, (index) {
        Color textColor = const Color(0xFF777B84);

        if (index == 0) {
          textColor = const Color(0xFFF0788F);
        }

        if (index == 6) {
          textColor = const Color(0xFF5D7FD3);
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
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 0.82,
      ),
      itemCount: totalCellCount,
      itemBuilder: (context, index) {
        final int dayNumber = index - leadingEmptyCount + 1;

        if (dayNumber < 1 || dayNumber > daysInMonth) {
          return const SizedBox.shrink();
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

    Color dayTextColor = const Color(0xFF1A1A1A);

    if (date.weekday == DateTime.sunday) {
      dayTextColor = const Color(0xFFF0788F);
    }

    if (date.weekday == DateTime.saturday) {
      dayTextColor = const Color(0xFF5D7FD3);
    }

    if (isSelected) {
      dayTextColor = Colors.white;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        setState(() {
          _selectedDate = date;
        });
      },
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF0788F) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isToday && !isSelected
              ? Border.all(color: const Color(0xFFF0788F), width: 1.5)
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
            const SizedBox(height: 4),
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
      return const SizedBox(height: 6);
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
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? Colors.white : _getScheduleColor(type),
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
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A),
            ),
          ),
        ),
        Text(
          '${_getSchedulesForDate(_selectedDate).length}개 일정',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFFF0788F),
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
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
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
                      const SizedBox(width: 8),
                      Text(
                        _formatScheduleTime(schedule),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF9AA0AC),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  schedule.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                if (schedule.description.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    schedule.description,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: Color(0xFF666A73),
                    ),
                  ),
                ],
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: '일정 메뉴',
            color: Colors.white,
            icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF9AA0AC)),
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
                const PopupMenuItem<String>(
                  value: 'calendar',
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_month_outlined,
                        size: 20,
                        color: Color(0xFFF0788F),
                      ),
                      SizedBox(width: 10),
                      Text('휴대폰 캘린더에 추가'),
                    ],
                  ),
                ),

                // 사용자 직접 일정에만 수정과 삭제 메뉴 표시
                if (schedule.type == CalendarScheduleType.user) ...[
                  const PopupMenuItem<String>(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(
                          Icons.edit_outlined,
                          size: 20,
                          color: Color(0xFF4A8F73),
                        ),
                        SizedBox(width: 10),
                        Text('일정 수정'),
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline_rounded,
                          size: 20,
                          color: Colors.redAccent,
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
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Column(
          children: [
            Icon(
              Icons.event_available_outlined,
              size: 44,
              color: Color(0xFFB4B8C2),
            ),
            SizedBox(height: 12),
            Text(
              '등록된 일정이 없습니다.',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
            ),
            SizedBox(height: 6),
            Text(
              '일정 추가 버튼을 눌러\n새로운 일정을 등록해보세요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: Color(0xFF9AA0AC),
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
          backgroundColor: const Color(0xFFF0788F),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text(
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

    final bool? result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              title: Text(
                isEditing ? '일정 수정' : '일정 추가',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: titleController,

                      // 다이얼로그가 닫힐 때 Flutter 기본 바깥 탭 처리가
                      // 중복 실행되는 오류를 막기 위해 직접 처리
                      onTapOutside: (_) {
                        FocusManager.instance.primaryFocus?.unfocus();
                      },

                      decoration: const InputDecoration(
                        labelText: '일정 이름',
                        hintText: '예: 스터디 모임',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _DialogSelectTile(
                      icon: Icons.calendar_month_outlined,
                      title: '날짜',
                      value: _formatDate(selectedDate),
                      onTap: () async {
                        final DateTime? pickedDate = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2025),
                          lastDate: DateTime(2035),
                        );

                        if (pickedDate != null) {
                          setDialogState(() {
                            selectedDate = pickedDate;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    _DialogSelectTile(
                      icon: Icons.schedule_outlined,
                      title: '시작 시간',
                      value: startTime == null
                          ? '선택 안 함'
                          : _formatTimeOfDay(startTime!),
                      onTap: () async {
                        final TimeOfDay? pickedTime = await showTimePicker(
                          context: context,
                          initialTime: startTime ?? TimeOfDay.now(),
                        );

                        if (pickedTime != null) {
                          setDialogState(() {
                            startTime = pickedTime;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    _DialogSelectTile(
                      icon: Icons.schedule_send_outlined,
                      title: '종료 시간',
                      value: endTime == null
                          ? '선택 안 함'
                          : _formatTimeOfDay(endTime!),
                      onTap: () async {
                        final TimeOfDay? pickedTime = await showTimePicker(
                          context: context,
                          initialTime: endTime ?? startTime ?? TimeOfDay.now(),
                        );

                        if (pickedTime != null) {
                          setDialogState(() {
                            endTime = pickedTime;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    // TextField 포커스를 먼저 해제한 다음 다이얼로그 종료
                    FocusManager.instance.primaryFocus?.unfocus();

                    Navigator.pop(dialogContext, false);
                  },
                  child: const Text(
                    '취소',
                    style: TextStyle(color: Color(0xFF9AA0AC)),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    if (titleController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('일정 이름을 입력해주세요.')),
                      );

                      return;
                    }

                    if (startTime == null && endTime != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('종료 시간을 선택하려면 시작 시간도 선택해주세요.'),
                        ),
                      );

                      return;
                    }

                    if (startTime != null && endTime != null) {
                      final int startMinutes =
                          startTime!.hour * 60 + startTime!.minute;

                      final int endMinutes =
                          endTime!.hour * 60 + endTime!.minute;

                      if (endMinutes <= startMinutes) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('종료 시간은 시작 시간보다 늦어야 합니다.'),
                          ),
                        );

                        return;
                      }
                    }

                    FocusManager.instance.primaryFocus?.unfocus();

                    Navigator.pop(dialogContext, true);
                  },
                  child: Text(
                    isEditing ? '수정' : '추가',
                    style: const TextStyle(
                      color: Color(0xFFF0788F),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

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
        ).showSnackBar(const SnackBar(content: Text('로그인 정보를 확인할 수 없습니다.')));
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
      endDate = startDate.add(const Duration(days: 1));
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
        endDate = startDate.add(const Duration(hours: 1));
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
      ).showSnackBar(const SnackBar(content: Text('휴대폰 캘린더 등록 화면을 열었습니다.')));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('휴대폰 캘린더를 열지 못했습니다.')));
    }
  }

  Future<void> _showDeleteScheduleDialog(CalendarScheduleItem schedule) async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text(
            '일정 삭제',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: Text('${schedule.title} 일정을 삭제하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text(
                '취소',
                style: TextStyle(color: Color(0xFF9AA0AC)),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text(
                '삭제',
                style: TextStyle(
                  color: Colors.redAccent,
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
        ).showSnackBar(const SnackBar(content: Text('로그인 정보를 확인할 수 없습니다.')));
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
      ).showSnackBar(const SnackBar(content: Text('일정이 삭제되었습니다.')));
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('일정을 삭제하지 못했습니다.')));
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
    const List<String> weekdays = ['월', '화', '수', '목', '금', '토', '일'];

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
        return const CalendarTypeStyle(
          label: '자격증 일정',
          icon: Icons.workspace_premium_outlined,
          foregroundColor: Color(0xFFF0788F),
          backgroundColor: Color(0xFFFCEFF3),
        );

      case CalendarScheduleType.aiPlan:
        return const CalendarTypeStyle(
          label: '학습 계획',
          icon: Icons.auto_awesome_outlined,
          foregroundColor: Color(0xFF6F63C2),
          backgroundColor: Color(0xFFF0EEFC),
        );

      case CalendarScheduleType.user:
        return const CalendarTypeStyle(
          label: '내 일정',
          icon: Icons.edit_calendar_outlined,
          foregroundColor: Color(0xFF4A8F73),
          backgroundColor: Color(0xFFEAF6F1),
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

  const CalendarScheduleItem({
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

  const CalendarTypeStyle({
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
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE2E2E6)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: const Color(0xFFF0788F)),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9AA0AC),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: Color(0xFF9AA0AC),
            ),
          ],
        ),
      ),
    );
  }
}
