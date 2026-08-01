import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../theme.dart';
import '../services/certificate_schedule_service.dart';
import 'certificate_common_widgets.dart';

class CertificateScheduleTabSelector extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const CertificateScheduleTabSelector({
    super.key,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: context.colors.pinkSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ScheduleTabButton(
              label: '캘린더',
              icon: Icons.calendar_month_outlined,
              selected: selectedIndex == 0,
              onTap: () => onChanged(0),
            ),
          ),
          Expanded(
            child: _ScheduleTabButton(
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

class CertificateMonthHeader extends StatelessWidget {
  final DateTime focusedDay;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const CertificateMonthHeader({
    super.key,
    required this.focusedDay,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _MonthMoveButton(icon: Icons.chevron_left_rounded, onTap: onPrevious),
        Expanded(
          child: Text(
            '${focusedDay.year}년 ${focusedDay.month}월',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.colors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
        ),
        _MonthMoveButton(icon: Icons.chevron_right_rounded, onTap: onNext),
      ],
    );
  }
}

class CertificateCalendarCard extends StatelessWidget {
  final DateTime focusedDay;
  final DateTime selectedDay;

  final List<CertificateSchedule> Function(DateTime day) eventLoader;

  final void Function(DateTime selectedDay, DateTime focusedDay) onDaySelected;

  final ValueChanged<DateTime> onPageChanged;

  const CertificateCalendarCard({
    super.key,
    required this.focusedDay,
    required this.selectedDay,
    required this.eventLoader,
    required this.onDaySelected,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      decoration: certificateCardDecoration(context: context),
      child: TableCalendar<CertificateSchedule>(
        firstDay: DateTime(2020, 1, 1),
        lastDay: DateTime(2035, 12, 31),
        focusedDay: focusedDay,
        selectedDayPredicate: (day) {
          return DateUtils.isSameDay(day, selectedDay);
        },
        eventLoader: eventLoader,
        calendarFormat: CalendarFormat.month,
        availableCalendarFormats: const {CalendarFormat.month: '월'},
        headerVisible: false,
        startingDayOfWeek: StartingDayOfWeek.sunday,
        rowHeight: 52,
        daysOfWeekHeight: 32,
        shouldFillViewport: false,
        onDaySelected: onDaySelected,
        onPageChanged: onPageChanged,
        calendarBuilders: CalendarBuilders<CertificateSchedule>(
          markerBuilder: (context, day, events) {
            if (events.isEmpty) {
              return null;
            }

            final hasTechnical = events.any((event) => event.isTechnical);

            final hasProfessional = events.any((event) => event.isProfessional);

            if (!hasTechnical && !hasProfessional) {
              return null;
            }

            return Positioned(
              bottom: 5,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasTechnical)
                    _CalendarMarkerDot(color: context.colors.info),
                  if (hasTechnical && hasProfessional) const SizedBox(width: 3),
                  if (hasProfessional)
                    _CalendarMarkerDot(color: context.colors.correct),
                ],
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
    );
  }
}

class CertificateScheduleDateTitle extends StatelessWidget {
  final DateTime date;
  final int? count;

  const CertificateScheduleDateTitle({
    super.key,
    required this.date,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '${date.month}월 ${date.day}일 일정',
            style: TextStyle(
              color: context.colors.textPrimary,
              fontSize: 21,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
        ),
        if (count != null) _ScheduleCountBadge(count: count!),
      ],
    );
  }
}

class CertificateScheduleListDateHeader extends StatelessWidget {
  final DateTime date;

  const CertificateScheduleListDateHeader({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    return Text(
      '${date.month}월 ${date.day}일',
      style: TextStyle(
        color: context.colors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
      ),
    );
  }
}

class CertificateScheduleCard extends StatelessWidget {
  final CertificateSchedule schedule;

  const CertificateScheduleCard({super.key, required this.schedule});

  @override
  Widget build(BuildContext context) {
    final style = _getScheduleStyle(context, schedule.scheduleType);

    final iconBackgroundColor = schedule.isProfessional
        ? context.colors.mint
        : context.colors.softBlue;

    final iconColor = schedule.isProfessional
        ? context.colors.correct
        : context.colors.info;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: certificateCardDecoration(context: context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconBackgroundColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(style.icon, color: iconColor, size: 21),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    schedule.certificateName,
                    style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                schedule.dateText,
                style: TextStyle(
                  color: context.colors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _ScheduleBadge(
                text: schedule.scheduleType,
                backgroundColor: style.backgroundColor,
                foregroundColor: style.foregroundColor,
              ),
              if (schedule.qualificationName.isNotEmpty)
                _ScheduleBadge(
                  text: schedule.qualificationName,
                  backgroundColor: schedule.isProfessional
                      ? context.colors.mint
                      : context.colors.softBlue,
                  foregroundColor: schedule.isProfessional
                      ? context.colors.correct
                      : context.colors.info,
                ),
            ],
          ),
          if (schedule.description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              schedule.description,
              style: TextStyle(
                color: context.colors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  _ScheduleStyle _getScheduleStyle(BuildContext context, String scheduleType) {
    if (scheduleType.contains('시험')) {
      return _ScheduleStyle(
        backgroundColor: context.colors.softBlue,
        foregroundColor: context.colors.info,
        icon: Icons.assignment_outlined,
      );
    }

    if (scheduleType.contains('발표')) {
      return _ScheduleStyle(
        backgroundColor: context.colors.mint,
        foregroundColor: context.colors.correct,
        icon: Icons.campaign_outlined,
      );
    }

    return _ScheduleStyle(
      backgroundColor: context.colors.pinkSoft,
      foregroundColor: context.colors.pinkDeep,
      icon: Icons.edit_calendar_outlined,
    );
  }
}

class EmptyCertificateScheduleCard extends StatelessWidget {
  final String message;

  const EmptyCertificateScheduleCard({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 34),
      decoration: certificateCardDecoration(context: context),
      child: Column(
        children: [
          const CertificateEmptyIcon(icon: Icons.event_busy_outlined),
          const SizedBox(height: 13),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.colors.textSecondary,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class CertificateScheduleLoadError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const CertificateScheduleLoadError({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return CertificateLoadError(message: message, onRetry: onRetry);
  }
}

class _CalendarMarkerDot extends StatelessWidget {
  final Color color;

  const _CalendarMarkerDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _ScheduleBadge extends StatelessWidget {
  final String text;
  final Color backgroundColor;
  final Color foregroundColor;

  const _ScheduleBadge({
    required this.text,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: foregroundColor,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ScheduleTabButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ScheduleTabButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? context.colors.pinkDeep : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 19,
                color: selected
                    ? context.colors.onPrimary
                    : context.colors.textPrimary,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: selected
                      ? context.colors.onPrimary
                      : context.colors.textPrimary,
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthMoveButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MonthMoveButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, color: context.colors.iconPrimary, size: 26),
        ),
      ),
    );
  }
}

class _ScheduleCountBadge extends StatelessWidget {
  final int count;

  const _ScheduleCountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: context.colors.pinkSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$count개',
        style: TextStyle(
          color: context.colors.pinkDeep,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ScheduleStyle {
  final Color backgroundColor;
  final Color foregroundColor;
  final IconData icon;

  const _ScheduleStyle({
    required this.backgroundColor,
    required this.foregroundColor,
    required this.icon,
  });
}
