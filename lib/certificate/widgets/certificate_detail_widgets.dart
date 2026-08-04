import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../theme.dart';

import 'certificate_common_widgets.dart';

class CertificateDetailHeader extends StatelessWidget {
  final String name;
  final String qualificationName;
  final bool isTechnical;
  final bool isOther;
  final Widget? action;

  const CertificateDetailHeader({
    super.key,
    required this.name,
    required this.qualificationName,
    required this.isTechnical,
    this.isOther = false,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final iconBackground = isOther
        ? context.colors.otherCertificateSoft
        : isTechnical
        ? context.colors.softBlue
        : context.colors.mint;

    final iconColor = isOther
        ? context.colors.otherCertificateAccent
        : isTechnical
        ? context.colors.info
        : context.colors.correct;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(22),
      decoration: certificateCardDecoration(context: context),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(21),
            ),
            child: Icon(
              Icons.workspace_premium_outlined,
              color: iconColor,
              size: 35,
            ),
          ),
          SizedBox(height: 17),
          Text(
            name,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.colors.textPrimary,
              fontSize: 23,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
          ),
          SizedBox(height: 11),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 13, vertical: 7),
            decoration: BoxDecoration(
              color: isOther
                  ? context.colors.otherCertificateSoft
                  : context.colors.pinkSoft,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              qualificationName,
              style: TextStyle(
                color: isOther
                    ? context.colors.otherCertificateAccent
                    : context.colors.pinkDeep,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

          if (action != null) ...[SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}

class CertificateInfoCard extends StatelessWidget {
  final List<CertificateInfoItem> items;

  const CertificateInfoCard({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: certificateCardDecoration(context: context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '자격 정보',
            style: TextStyle(
              color: context.colors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 18),
          ...List.generate(items.length, (index) {
            final item = items[index];

            return Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 90,
                      child: Text(
                        item.label,
                        style: TextStyle(
                          color: context.colors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item.value.isEmpty ? '-' : item.value,
                        style: TextStyle(
                          color: context.colors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
                if (index != items.length - 1)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 15),
                    child: Divider(height: 1, color: context.colors.border),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class CertificateInfoItem {
  final String label;
  final String value;

  const CertificateInfoItem({required this.label, required this.value});
}

class CertificateDetailSectionTitle extends StatelessWidget {
  final String title;

  const CertificateDetailSectionTitle({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        color: context.colors.textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
      ),
    );
  }
}

class CertificateGoalOption {
  final String scheduleId;
  final String targetRound;
  final String examType;
  final String examTypeName;

  final DateTime examDate;
  final DateTime examStartDate;
  final DateTime? examEndDate;

  final DateTime? registrationStartDate;
  final DateTime? registrationEndDate;

  final DateTime? passAnnouncementDate;
  final DateTime? passAnnouncementEndDate;

  const CertificateGoalOption({
    required this.scheduleId,
    required this.targetRound,
    required this.examType,
    required this.examTypeName,
    required this.examDate,
    required this.examStartDate,
    required this.examEndDate,
    required this.registrationStartDate,
    required this.registrationEndDate,
    required this.passAnnouncementDate,
    required this.passAnnouncementEndDate,
  });

  CertificateGoalOption withExamDate(DateTime selectedDate) {
    return CertificateGoalOption(
      scheduleId: scheduleId,
      targetRound: targetRound,
      examType: examType,
      examTypeName: examTypeName,
      examDate: selectedDate,
      examStartDate: examStartDate,
      examEndDate: examEndDate,
      registrationStartDate: registrationStartDate,
      registrationEndDate: registrationEndDate,
      passAnnouncementDate: passAnnouncementDate,
      passAnnouncementEndDate: passAnnouncementEndDate,
    );
  }
}

Future<CertificateGoalOption?> selectCertificateGoalExamDate({
  required BuildContext context,
  required CertificateGoalOption option,
}) async {
  final firstDate = _certificateDateOnly(option.examStartDate);
  final lastDate = _certificateDateOnly(option.examEndDate ?? firstDate);
  if (!lastDate.isAfter(firstDate)) return option.withExamDate(firstDate);

  final today = _certificateDateOnly(DateTime.now());
  final selectableFirstDate = today.isAfter(firstDate) ? today : firstDate;
  if (selectableFirstDate.isAfter(lastDate)) return null;

  final selectedDate = await showDialog<DateTime>(
    context: context,
    builder: (_) => _CertificateGoalDatePickerDialog(
      firstDate: selectableFirstDate,
      lastDate: lastDate,
    ),
  );
  return selectedDate == null ? null : option.withExamDate(selectedDate);
}

class _CertificateGoalDatePickerDialog extends StatefulWidget {
  final DateTime firstDate;
  final DateTime lastDate;

  const _CertificateGoalDatePickerDialog({
    required this.firstDate,
    required this.lastDate,
  });

  @override
  State<_CertificateGoalDatePickerDialog> createState() =>
      _CertificateGoalDatePickerDialogState();
}

class _CertificateGoalDatePickerDialogState
    extends State<_CertificateGoalDatePickerDialog> {
  late DateTime _focusedDay = widget.firstDate;
  late DateTime _selectedDay = widget.firstDate;

  @override
  Widget build(BuildContext context) {
    return Dialog(
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
              '시험 응시일 선택',
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
                firstDay: widget.firstDate,
                lastDay: widget.lastDate,
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
                enabledDayPredicate: (day) =>
                    !day.isBefore(widget.firstDate) &&
                    !day.isAfter(widget.lastDate),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },
                onPageChanged: (focusedDay) => _focusedDay = focusedDay,
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
                  disabledTextStyle: TextStyle(color: context.colors.textDisabled),
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
}

Future<bool?> showCertificateCalendarLinkDialog({
  required BuildContext context,
  required CertificateGoalOption option,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        titlePadding: EdgeInsets.fromLTRB(24, 24, 24, 0),
        contentPadding: EdgeInsets.fromLTRB(24, 16, 24, 0),
        actionsPadding: EdgeInsets.fromLTRB(20, 20, 20, 20),
        title: Row(
          children: [
            Icon(
              Icons.event_available_outlined,
              color: context.colors.pinkDeep,
              size: 24,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                '캘린더에 추가할까요?',
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          '${option.targetRound} ${option.examTypeName} 시험이 '
          '목표로 등록되었습니다.\n\n'
          '선택한 시험일: ${formatCertificateGoalDate(option.examDate)}\n'
          '시험 기간: ${formatCertificateGoalDateRange(option.examStartDate, option.examEndDate)}\n'
          '휴대폰 캘린더에도 시험 일정을 추가하시겠습니까?',
          style: TextStyle(
            color: context.colors.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            height: 1.6,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext, false);
            },
            child: Text(
              '연동 안 함',
              style: TextStyle(
                color: context.colors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext, true);
            },
            style: FilledButton.styleFrom(
              backgroundColor: context.colors.pinkDeep,
              foregroundColor: context.colors.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: Icon(Icons.calendar_month_outlined, size: 18),
            label: Text(
              '캘린더에 추가',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      );
    },
  );
}

Future<bool> addCertificateGoalToDeviceCalendar({
  required String certificateName,
  required CertificateGoalOption option,
}) async {
  final localExamDate = option.examDate.toLocal();

  final startDate = DateTime(
    localExamDate.year,
    localExamDate.month,
    localExamDate.day,
  );

  final event = Event(
    title: '$certificateName ${option.examTypeName} 시험',
    description:
        '목표 자격증: $certificateName\n'
        '시험 회차: ${option.targetRound}\n'
        '시험 유형: ${option.examTypeName}',
    startDate: startDate,
    endDate: startDate.add(Duration(days: 1)),
    allDay: true,
  );

  return Add2Calendar.addEvent2Cal(event);
}

String formatCertificateGoalDate(DateTime date) {
  final localDate = date.toLocal();

  final year = localDate.year.toString();
  final month = localDate.month.toString().padLeft(2, '0');
  final day = localDate.day.toString().padLeft(2, '0');

  return '$year.$month.$day';
}

String formatCertificateGoalDateRange(DateTime startDate, DateTime? endDate) {
  final start = _certificateDateOnly(startDate);

  if (endDate == null) {
    return formatCertificateGoalDate(start);
  }

  final end = _certificateDateOnly(endDate);

  if (start == end) {
    return formatCertificateGoalDate(start);
  }

  return '${formatCertificateGoalDate(start)}'
      ' ~ '
      '${formatCertificateGoalDate(end)}';
}

CertificateRegistrationStatus? getCertificateRegistrationStatus({
  required DateTime? registrationStartDate,
  required DateTime? registrationEndDate,
}) {
  if (registrationStartDate == null || registrationEndDate == null) {
    return null;
  }

  final today = _certificateDateOnly(DateTime.now());
  final startDate = _certificateDateOnly(registrationStartDate);
  final endDate = _certificateDateOnly(registrationEndDate);

  if (today.isBefore(startDate)) {
    final remainingDays = startDate.difference(today).inDays;

    return CertificateRegistrationStatus(
      label: '원서접수 D-$remainingDays',
      isActive: false,
    );
  }

  if (!today.isAfter(endDate)) {
    return CertificateRegistrationStatus(label: '원서접수 진행중', isActive: true);
  }

  return const CertificateRegistrationStatus(label: '원서접수 종료', isActive: false);
}

DateTime _certificateDateOnly(DateTime date) {
  final localDate = date.toLocal();

  return DateTime(localDate.year, localDate.month, localDate.day);
}

class CertificateRegistrationStatus {
  final String label;
  final bool isActive;

  const CertificateRegistrationStatus({
    required this.label,
    required this.isActive,
  });
}

class CertificateScheduleStatusBadge extends StatelessWidget {
  final String label;
  final bool isActive;

  const CertificateScheduleStatusBadge({
    super.key,
    required this.label,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: isActive ? context.colors.pinkSoft : context.colors.surfaceMuted,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isActive
              ? context.colors.pinkDeep
              : context.colors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
