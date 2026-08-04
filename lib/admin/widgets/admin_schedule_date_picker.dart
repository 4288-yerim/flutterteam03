import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../certificate/widgets/certificate_common_widgets.dart';
import '../../theme.dart';

class AdminScheduleDatePickerDialog extends StatefulWidget {
  const AdminScheduleDatePickerDialog({super.key, required this.initialDate});

  final DateTime initialDate;

  @override
  State<AdminScheduleDatePickerDialog> createState() =>
      _AdminScheduleDatePickerDialogState();
}

class _AdminScheduleDatePickerDialogState
    extends State<AdminScheduleDatePickerDialog> {
  late DateTime _focusedDay = widget.initialDate;
  late DateTime _selectedDay = widget.initialDate;

  @override
  Widget build(BuildContext context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 440),
          padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
          decoration: BoxDecoration(
            color: context.colors.surfaceElevated,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: context.colors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '날짜 선택',
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                decoration: certificateCardDecoration(context: context),
                child: TableCalendar<void>(
                  firstDay: DateTime(2000),
                  lastDay: DateTime(2100, 12, 31),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (day) =>
                      DateUtils.isSameDay(day, _selectedDay),
                  headerStyle: HeaderStyle(
                    titleCentered: true,
                    formatButtonVisible: false,
                    titleTextStyle: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                    leftChevronIcon: Icon(
                      Icons.chevron_left_rounded,
                      color: context.colors.textSecondary,
                    ),
                    rightChevronIcon: Icon(
                      Icons.chevron_right_rounded,
                      color: context.colors.textSecondary,
                    ),
                  ),
                  calendarFormat: CalendarFormat.month,
                  startingDayOfWeek: StartingDayOfWeek.sunday,
                  rowHeight: 46,
                  daysOfWeekHeight: 30,
                  onDaySelected: (selected, focused) => setState(() {
                    _selectedDay = selected;
                    _focusedDay = focused;
                  }),
                  onPageChanged: (focused) => _focusedDay = focused,
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
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('취소'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, _selectedDay),
                      child: const Text('선택'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}
