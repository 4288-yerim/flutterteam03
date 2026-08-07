import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../theme.dart';

import '../services/certificate_category_content_service.dart';
import '../services/technical_certificate_service.dart';
import 'certificate_common_widgets.dart';
import 'certificate_schedule_notice_content_card.dart';

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
    final badgeBackground = isOther
        ? context.colors.otherCertificateSoft
        : isTechnical
        ? context.colors.softBlue
        : context.colors.mint;
    final badgeColor = isOther
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
              color: badgeBackground,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              qualificationName,
              style: TextStyle(
                color: badgeColor,
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
            Container(
              padding: const EdgeInsets.fromLTRB(10, 5, 10, 8),
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
                  disabledTextStyle: TextStyle(
                    color: context.colors.textDisabled,
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
      label: '원서 접수 D-$remainingDays',
      isActive: false,
    );
  }

  if (!today.isAfter(endDate)) {
    return CertificateRegistrationStatus(label: '원서 접수 진행중', isActive: true);
  }

  return const CertificateRegistrationStatus(
    label: '원서 접수 종료',
    isActive: false,
  );
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

class CertificateScheduleStatus {
  final String label;
  final bool isActive;

  const CertificateScheduleStatus({
    required this.label,
    required this.isActive,
  });
}

CertificateScheduleStatus? getCertificateGoalScheduleStatus(
  CertificateGoalOption option,
) {
  final isPractical = option.examType == 'PRACTICAL';
  return resolveCertificateScheduleStatus(
    writtenRegistrationStartAt: isPractical
        ? null
        : option.registrationStartDate,
    writtenRegistrationEndAt: isPractical ? null : option.registrationEndDate,
    writtenExamStartAt: isPractical ? null : option.examStartDate,
    writtenExamEndAt: isPractical ? null : option.examEndDate,
    writtenPassStartAt: isPractical ? null : option.passAnnouncementDate,
    writtenPassEndAt: isPractical ? null : option.passAnnouncementEndDate,
    practicalRegistrationStartAt: isPractical
        ? option.registrationStartDate
        : null,
    practicalRegistrationEndAt: isPractical ? option.registrationEndDate : null,
    practicalExamStartAt: isPractical ? option.examStartDate : null,
    practicalExamEndAt: isPractical ? option.examEndDate : null,
    practicalPassStartAt: isPractical ? option.passAnnouncementDate : null,
    practicalPassEndAt: isPractical ? option.passAnnouncementEndDate : null,
    showExamTypeLabels: option.examTypeName == '필기',
  );
}

CertificateScheduleStatus? resolveCertificateScheduleStatus({
  DateTime? writtenRegistrationStartAt,
  DateTime? writtenRegistrationEndAt,
  DateTime? writtenExamStartAt,
  DateTime? writtenExamEndAt,
  DateTime? writtenPassStartAt,
  DateTime? writtenPassEndAt,
  DateTime? documentSubmitStartAt,
  DateTime? documentSubmitEndAt,
  DateTime? practicalRegistrationStartAt,
  DateTime? practicalRegistrationEndAt,
  DateTime? practicalExamStartAt,
  DateTime? practicalExamEndAt,
  DateTime? practicalPassStartAt,
  DateTime? practicalPassEndAt,
  bool showExamTypeLabels = false,
}) {
  final today = _certificateDateOnly(DateTime.now());
  final ranges = [
    (writtenRegistrationStartAt, writtenRegistrationEndAt),
    (writtenExamStartAt, writtenExamEndAt),
    (practicalRegistrationStartAt, practicalRegistrationEndAt),
    (practicalExamStartAt, practicalExamEndAt),
  ];
  final hasActiveRange = ranges.any(
    (range) => _certificateScheduleWithin(today, range.$1, range.$2),
  );

  if (!hasActiveRange) {
    final candidates = <(DateTime, String)>[];
    _addCertificateScheduleCandidate(
      candidates,
      today,
      writtenRegistrationStartAt,
      writtenRegistrationEndAt,
      writtenExamStartAt,
      showExamTypeLabels ? '필기 ' : '',
    );
    _addCertificateScheduleCandidate(
      candidates,
      today,
      practicalRegistrationStartAt,
      practicalRegistrationEndAt,
      practicalExamStartAt,
      '실기/면접 ',
    );
    if (candidates.isNotEmpty) {
      candidates.sort((a, b) => a.$1.compareTo(b.$1));
      final candidate = candidates.first;
      final days = _certificateDateOnly(candidate.$1).difference(today).inDays;
      return CertificateScheduleStatus(
        label: '${candidate.$2} D-$days',
        isActive: false,
      );
    }
  }

  final allDates = <DateTime?>[
    writtenRegistrationStartAt,
    writtenRegistrationEndAt,
    writtenExamStartAt,
    writtenExamEndAt,
    writtenPassStartAt,
    writtenPassEndAt,
    documentSubmitStartAt,
    documentSubmitEndAt,
    practicalRegistrationStartAt,
    practicalRegistrationEndAt,
    practicalExamStartAt,
    practicalExamEndAt,
    practicalPassStartAt,
    practicalPassEndAt,
  ].whereType<DateTime>().map(_certificateDateOnly).toList();
  if (allDates.isNotEmpty &&
      allDates.reduce((a, b) => a.isAfter(b) ? a : b).isBefore(today)) {
    return const CertificateScheduleStatus(label: '종료', isActive: false);
  }

  if (_certificateScheduleWithin(
    today,
    practicalExamStartAt,
    practicalExamEndAt,
  )) {
    return const CertificateScheduleStatus(
      label: '실기/면접 시험 진행중',
      isActive: true,
    );
  }
  if (_certificateScheduleWithin(
    today,
    practicalRegistrationStartAt,
    practicalRegistrationEndAt,
  )) {
    return const CertificateScheduleStatus(
      label: '실기/면접 원서 접수 중',
      isActive: true,
    );
  }
  final writtenPrefix = showExamTypeLabels ? '필기 ' : '';
  if (_certificateScheduleWithin(today, writtenExamStartAt, writtenExamEndAt)) {
    return CertificateScheduleStatus(
      label: '$writtenPrefix시험 진행중',
      isActive: true,
    );
  }
  if (_certificateScheduleWithin(
    today,
    writtenRegistrationStartAt,
    writtenRegistrationEndAt,
  )) {
    return CertificateScheduleStatus(
      label: '$writtenPrefix원서 접수 중',
      isActive: true,
    );
  }
  if (_certificateScheduleFinished(
    today,
    practicalExamStartAt,
    practicalExamEndAt,
  )) {
    return const CertificateScheduleStatus(
      label: '실기/면접 시험 종료',
      isActive: false,
    );
  }
  if (_certificateScheduleFinished(
    today,
    practicalRegistrationStartAt,
    practicalRegistrationEndAt,
  )) {
    return const CertificateScheduleStatus(
      label: '실기/면접 원서 접수 종료',
      isActive: false,
    );
  }
  if (_certificateScheduleFinished(
    today,
    writtenExamStartAt,
    writtenExamEndAt,
  )) {
    return CertificateScheduleStatus(
      label: '$writtenPrefix시험 종료',
      isActive: false,
    );
  }
  if (_certificateScheduleFinished(
    today,
    writtenRegistrationStartAt,
    writtenRegistrationEndAt,
  )) {
    return CertificateScheduleStatus(
      label: '$writtenPrefix원서 접수 종료',
      isActive: false,
    );
  }
  return null;
}

void _addCertificateScheduleCandidate(
  List<(DateTime, String)> candidates,
  DateTime today,
  DateTime? registrationStart,
  DateTime? registrationEnd,
  DateTime? examStart,
  String prefix,
) {
  if (registrationStart != null &&
      _certificateDateOnly(registrationStart).isAfter(today)) {
    candidates.add((registrationStart, '$prefix원서 접수'));
    return;
  }
  final registrationFinished =
      registrationEnd != null &&
      _certificateDateOnly(registrationEnd).isBefore(today);
  if ((registrationFinished || registrationStart == null) &&
      examStart != null &&
      !_certificateDateOnly(examStart).isBefore(today)) {
    candidates.add((examStart, '$prefix시험'));
  }
}

bool _certificateScheduleWithin(
  DateTime today,
  DateTime? start,
  DateTime? end,
) {
  if (start == null && end == null) return false;
  final first = _certificateDateOnly(start ?? end!);
  final last = _certificateDateOnly(end ?? start!);
  return !today.isBefore(first) && !today.isAfter(last);
}

bool _certificateScheduleFinished(
  DateTime today,
  DateTime? start,
  DateTime? end,
) {
  if (start == null && end == null) return false;
  return _certificateDateOnly(end ?? start!).isBefore(today);
}

class CertificateExamInformationCard extends StatelessWidget {
  final String overview;
  final int? writtenFee;
  final int? practicalFee;
  final String examTrends;
  final String howToObtain;
  final List<CertificateContentLink> examFeeLinks;
  final List<CertificateContentLink> examTrendsLinks;
  final List<CertificateContentLink> howToObtainLinks;
  final ValueChanged<String>? onOpenLink;
  final VoidCallback? onOpenExamStandard;
  final VoidCallback? onOpenOtherInformation;

  const CertificateExamInformationCard({
    super.key,
    this.overview = '',
    required this.writtenFee,
    required this.practicalFee,
    required this.examTrends,
    required this.howToObtain,
    this.examFeeLinks = const [],
    this.examTrendsLinks = const [],
    this.howToObtainLinks = const [],
    this.onOpenLink,
    this.onOpenExamStandard,
    this.onOpenOtherInformation,
  });

  @override
  Widget build(BuildContext context) {
    final sections = <Widget>[
      if (overview.trim().isNotEmpty)
        _CertificateExamInformationSection(
          title: '자격 개요',
          child: Text(
            _formatStructuredContents(overview),
            style: _bodyStyle(context),
          ),
        ),
      if (writtenFee != null || practicalFee != null)
        _CertificateExamInformationSection(
          title: '응시 수수료',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (writtenFee != null)
                _CertificateExamFeeRow(
                  label: practicalFee == null ? '통합' : '필기',
                  fee: writtenFee!,
                ),
              if (writtenFee != null && practicalFee != null)
                const SizedBox(height: 10),
              if (practicalFee != null)
                _CertificateExamFeeRow(label: '실기/면접', fee: practicalFee!),
              _links(examFeeLinks),
            ],
          ),
        ),
      if (examTrends.trim().isNotEmpty)
        _CertificateExamInformationSection(
          title: '출제 경향',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _formatStructuredContents(examTrends),
                style: _bodyStyle(context),
              ),
              _links(examTrendsLinks),
            ],
          ),
        ),
      if (howToObtain.trim().isNotEmpty)
        _CertificateExamInformationSection(
          title: '취득 방법',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _formatStructuredContents(howToObtain),
                style: _bodyStyle(context),
              ),
              _links(howToObtainLinks),
            ],
          ),
        ),
      if (onOpenExamStandard != null)
        _CertificateExamInformationSection(
          title: '출제 기준',
          child: _CertificateExamInformationAction(
            description: '출제 기준은 Q-Net 출제 기준에서 확인 바랍니다.',
            label: 'Q-Net에서 출제 기준 확인하기',
            onTap: onOpenExamStandard!,
          ),
        ),
      if (onOpenOtherInformation != null)
        _CertificateExamInformationSection(
          title: '그 외 사항',
          child: _CertificateExamInformationAction(
            description: '그 외 사항은 Q-Net에서 확인 바랍니다.',
            label: 'Q-Net에서 상세 정보 확인하기',
            onTap: onOpenOtherInformation!,
          ),
        ),
    ];
    if (sections.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 42),
        decoration: certificateCardDecoration(context: context),
        child: Center(
          child: Text(
            '등록된 자격 정보가 없습니다.',
            style: TextStyle(color: context.colors.textSecondary, fontSize: 14),
          ),
        ),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: certificateCardDecoration(context: context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < sections.length; index++) ...[
            sections[index],
            if (index < sections.length - 1)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Divider(height: 1, color: context.colors.border),
              ),
          ],
        ],
      ),
    );
  }

  Widget _links(List<CertificateContentLink> links) {
    if (links.isEmpty || onOpenLink == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: CertificateContentLinkButtons(
        links: links,
        onOpenLink: onOpenLink!,
      ),
    );
  }

  static TextStyle _bodyStyle(BuildContext context) => TextStyle(
    color: context.colors.textPrimary,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.65,
  );

  static String _formatStructuredContents(String contents) {
    var formatted = contents.trim();
    const circledNumbers = [
      '①',
      '②',
      '③',
      '④',
      '⑤',
      '⑥',
      '⑦',
      '⑧',
      '⑨',
      '⑩',
      '⑪',
      '⑫',
      '⑬',
      '⑭',
      '⑮',
      '⑯',
      '⑰',
      '⑱',
      '⑲',
      '⑳',
    ];
    for (final number in circledNumbers) {
      formatted = formatted.replaceAll(number, '\n$number ');
    }
    formatted = formatted.replaceAllMapped(
      RegExp(r'(\d{1,2})\.\s*'),
      (match) => '\n${match.group(1)}. ',
    );
    formatted = formatted.replaceAllMapped(
      RegExp(r'<([^>]+)>'),
      (match) => '\n<${match.group(1)}>\n',
    );
    return formatted.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  }
}

class _CertificateExamInformationSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _CertificateExamInformationSection({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: TextStyle(
          color: context.colors.textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 13),
      child,
    ],
  );
}

class _CertificateExamFeeRow extends StatelessWidget {
  final String label;
  final int fee;

  const _CertificateExamFeeRow({required this.label, required this.fee});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(
        width: 80,
        child: Text(
          label,
          maxLines: 1,
          softWrap: false,
          style: TextStyle(color: context.colors.textPrimary, fontSize: 13),
        ),
      ),
      Expanded(
        child: Text(
          '${fee.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',')}원',
          style: TextStyle(
            color: context.colors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ],
  );
}

class _CertificateExamInformationAction extends StatelessWidget {
  final String description;
  final String label;
  final VoidCallback onTap;

  const _CertificateExamInformationAction({
    required this.description,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        description,
        style: CertificateExamInformationCard._bodyStyle(context),
      ),
      const SizedBox(height: 12),
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            color: context.colors.pinkSoft,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: context.colors.pinkDeep,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 7),
              Icon(
                Icons.open_in_new_rounded,
                color: context.colors.pinkDeep,
                size: 17,
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

class CertificateScheduleCard extends StatefulWidget {
  final String title;
  final DateTime? writtenRegistrationStartAt;
  final DateTime? writtenRegistrationEndAt;
  final DateTime? writtenExamStartAt;
  final DateTime? writtenExamEndAt;
  final DateTime? writtenPassAt;
  final DateTime? documentSubmitStartAt;
  final DateTime? documentSubmitEndAt;
  final DateTime? practicalRegistrationStartAt;
  final DateTime? practicalRegistrationEndAt;
  final DateTime? practicalExamStartAt;
  final DateTime? practicalExamEndAt;
  final DateTime? practicalPassStartAt;
  final DateTime? practicalPassEndAt;
  final List<CertificateContentLink> links;
  final ValueChanged<String>? onOpenLink;
  final bool showExamTypeLabels;

  const CertificateScheduleCard({
    super.key,
    required this.title,
    required this.writtenRegistrationStartAt,
    required this.writtenRegistrationEndAt,
    required this.writtenExamStartAt,
    required this.writtenExamEndAt,
    required this.writtenPassAt,
    required this.documentSubmitStartAt,
    required this.documentSubmitEndAt,
    required this.practicalRegistrationStartAt,
    required this.practicalRegistrationEndAt,
    required this.practicalExamStartAt,
    required this.practicalExamEndAt,
    required this.practicalPassStartAt,
    required this.practicalPassEndAt,
    this.links = const [],
    this.onOpenLink,
    this.showExamTypeLabels = false,
  });

  @override
  State<CertificateScheduleCard> createState() =>
      _CertificateScheduleCardState();
}

class _CertificateScheduleCardState extends State<CertificateScheduleCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final items = _scheduleItems();
    final status = _resolveStatus();
    return Container(
      width: double.infinity,
      decoration: certificateCardDecoration(context: context),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title.isEmpty ? '시험 일정' : widget.title,
                      style: TextStyle(
                        color: context.colors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        height: 1.4,
                      ),
                    ),
                  ),
                  if (status != null) ...[
                    const SizedBox(width: 8),
                    CertificateScheduleStatusBadge(
                      label: status.label,
                      isActive: status.isActive,
                    ),
                  ],
                  const SizedBox(width: 10),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: context.colors.textSecondary,
                      size: 27,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: items.isEmpty
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Column(
                      children: [
                        Divider(height: 1, color: context.colors.border),
                        const SizedBox(height: 18),
                        ...List.generate(items.length, (index) {
                          final item = items[index];
                          return Column(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 150,
                                    child: Text(
                                      item.label,
                                      maxLines: 1,
                                      softWrap: false,
                                      style: TextStyle(
                                        color: context.colors.textSecondary,
                                        fontSize: 13,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      item.value,
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
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  child: Divider(
                                    height: 1,
                                    color: context.colors.border,
                                  ),
                                ),
                            ],
                          );
                        }),
                        if (widget.links.isNotEmpty &&
                            widget.onOpenLink != null) ...[
                          const SizedBox(height: 16),
                          CertificateContentLinkButtons(
                            links: widget.links,
                            onOpenLink: widget.onOpenLink!,
                          ),
                        ],
                      ],
                    ),
                  ),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  List<CertificateInfoItem> _scheduleItems() => [
    if (_hasDate(
      widget.writtenRegistrationStartAt,
      widget.writtenRegistrationEndAt,
    ))
      CertificateInfoItem(
        label: _writtenLabel('원서 접수'),
        value: _dateRange(
          widget.writtenRegistrationStartAt,
          widget.writtenRegistrationEndAt,
        ),
      ),
    if (_hasDate(widget.writtenExamStartAt, widget.writtenExamEndAt))
      CertificateInfoItem(
        label: _writtenLabel('시험'),
        value: _dateRange(widget.writtenExamStartAt, widget.writtenExamEndAt),
      ),
    if (widget.writtenPassAt != null)
      CertificateInfoItem(
        label: _writtenLabel('합격 발표'),
        value: _date(widget.writtenPassAt!),
      ),
    if (_hasDate(widget.documentSubmitStartAt, widget.documentSubmitEndAt))
      CertificateInfoItem(
        label: '서류 제출',
        value: _dateRange(
          widget.documentSubmitStartAt,
          widget.documentSubmitEndAt,
        ),
      ),
    if (_hasDate(
      widget.practicalRegistrationStartAt,
      widget.practicalRegistrationEndAt,
    ))
      CertificateInfoItem(
        label: '실기/면접 원서 접수',
        value: _dateRange(
          widget.practicalRegistrationStartAt,
          widget.practicalRegistrationEndAt,
        ),
      ),
    if (_hasDate(widget.practicalExamStartAt, widget.practicalExamEndAt))
      CertificateInfoItem(
        label: '실기/면접 시험',
        value: _dateRange(
          widget.practicalExamStartAt,
          widget.practicalExamEndAt,
        ),
      ),
    if (_hasDate(widget.practicalPassStartAt, widget.practicalPassEndAt))
      CertificateInfoItem(
        label: '실기/면접 합격 발표',
        value: _dateRange(
          widget.practicalPassStartAt,
          widget.practicalPassEndAt,
        ),
      ),
  ];

  _CertificateScheduleCardStatus? _resolveStatus() {
    final today = _certificateDateOnly(DateTime.now());
    final countdown = _upcomingStatus(today);
    if (countdown != null) return countdown;
    if (_entireScheduleFinished(today)) {
      return const _CertificateScheduleCardStatus('종료', false);
    }
    if (_within(
      today,
      widget.practicalExamStartAt,
      widget.practicalExamEndAt,
    )) {
      return const _CertificateScheduleCardStatus('실기/면접 시험 진행중', true);
    }
    if (_within(
      today,
      widget.practicalRegistrationStartAt,
      widget.practicalRegistrationEndAt,
    )) {
      return const _CertificateScheduleCardStatus('실기/면접 원서 접수 중', true);
    }
    if (_within(today, widget.writtenExamStartAt, widget.writtenExamEndAt)) {
      return _CertificateScheduleCardStatus('${_writtenLabel('시험')} 진행중', true);
    }
    if (_within(
      today,
      widget.writtenRegistrationStartAt,
      widget.writtenRegistrationEndAt,
    )) {
      return _CertificateScheduleCardStatus(
        '${_writtenLabel('원서 접수')} 중',
        true,
      );
    }
    if (_finished(
      today,
      widget.practicalExamStartAt,
      widget.practicalExamEndAt,
    )) {
      return const _CertificateScheduleCardStatus('실기/면접 시험 종료', false);
    }
    if (_finished(
      today,
      widget.practicalRegistrationStartAt,
      widget.practicalRegistrationEndAt,
    )) {
      return const _CertificateScheduleCardStatus('실기/면접 원서 접수 종료', false);
    }
    if (_finished(today, widget.writtenExamStartAt, widget.writtenExamEndAt)) {
      return _CertificateScheduleCardStatus('${_writtenLabel('시험')} 종료', false);
    }
    if (_finished(
      today,
      widget.writtenRegistrationStartAt,
      widget.writtenRegistrationEndAt,
    )) {
      return _CertificateScheduleCardStatus(
        '${_writtenLabel('원서 접수')} 종료',
        false,
      );
    }
    return null;
  }

  _CertificateScheduleCardStatus? _upcomingStatus(DateTime today) {
    final ranges = [
      (widget.writtenRegistrationStartAt, widget.writtenRegistrationEndAt),
      (widget.writtenExamStartAt, widget.writtenExamEndAt),
      (widget.practicalRegistrationStartAt, widget.practicalRegistrationEndAt),
      (widget.practicalExamStartAt, widget.practicalExamEndAt),
    ];
    if (ranges.any((range) => _within(today, range.$1, range.$2))) return null;
    final candidates = <(DateTime, String)>[];
    _addCandidate(
      candidates,
      today,
      widget.writtenRegistrationStartAt,
      widget.writtenRegistrationEndAt,
      widget.writtenExamStartAt,
      widget.showExamTypeLabels ? '필기 ' : '',
    );
    _addCandidate(
      candidates,
      today,
      widget.practicalRegistrationStartAt,
      widget.practicalRegistrationEndAt,
      widget.practicalExamStartAt,
      '실기/면접 ',
    );
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => a.$1.compareTo(b.$1));
    final candidate = candidates.first;
    final days = _certificateDateOnly(candidate.$1).difference(today).inDays;
    return _CertificateScheduleCardStatus('${candidate.$2} D-$days', false);
  }

  void _addCandidate(
    List<(DateTime, String)> candidates,
    DateTime today,
    DateTime? registrationStart,
    DateTime? registrationEnd,
    DateTime? examStart,
    String prefix,
  ) {
    if (registrationStart != null &&
        _certificateDateOnly(registrationStart).isAfter(today)) {
      candidates.add((registrationStart, '$prefix원서 접수'));
      return;
    }
    final registrationFinished =
        registrationEnd != null &&
        _certificateDateOnly(registrationEnd).isBefore(today);
    if ((registrationFinished || registrationStart == null) &&
        examStart != null &&
        !_certificateDateOnly(examStart).isBefore(today)) {
      candidates.add((examStart, '$prefix시험'));
    }
  }

  bool _entireScheduleFinished(DateTime today) {
    final dates = <DateTime?>[
      widget.writtenRegistrationStartAt,
      widget.writtenRegistrationEndAt,
      widget.writtenExamStartAt,
      widget.writtenExamEndAt,
      widget.writtenPassAt,
      widget.documentSubmitStartAt,
      widget.documentSubmitEndAt,
      widget.practicalRegistrationStartAt,
      widget.practicalRegistrationEndAt,
      widget.practicalExamStartAt,
      widget.practicalExamEndAt,
      widget.practicalPassStartAt,
      widget.practicalPassEndAt,
    ].whereType<DateTime>().map(_certificateDateOnly).toList();
    if (dates.isEmpty) return false;
    return dates.reduce((a, b) => a.isAfter(b) ? a : b).isBefore(today);
  }

  String _writtenLabel(String label) =>
      widget.showExamTypeLabels ? '필기 $label' : label;

  static bool _hasDate(DateTime? start, DateTime? end) =>
      start != null || end != null;

  static bool _within(DateTime today, DateTime? start, DateTime? end) {
    if (!_hasDate(start, end)) return false;
    final first = _certificateDateOnly(start ?? end!);
    final last = _certificateDateOnly(end ?? start!);
    return !today.isBefore(first) && !today.isAfter(last);
  }

  static bool _finished(DateTime today, DateTime? start, DateTime? end) {
    if (!_hasDate(start, end)) return false;
    return _certificateDateOnly(end ?? start!).isBefore(today);
  }

  static String _dateRange(DateTime? start, DateTime? end) {
    if (start == null) return end == null ? '' : _date(end);
    if (end == null) return _date(start);
    final first = _date(start);
    final last = _date(end);
    return first == last ? first : '$first ~ $last';
  }

  static String _date(DateTime value) {
    final date = value.toLocal();
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.'
        '${date.day.toString().padLeft(2, '0')}';
  }
}

class _CertificateScheduleCardStatus {
  final String label;
  final bool isActive;

  const _CertificateScheduleCardStatus(this.label, this.isActive);
}

class CertificateStatisticsSection extends StatelessWidget {
  final int baseYear;

  final bool showWritten;
  final bool isLoadingWritten;
  final String? writtenError;
  final List<CertificateExamStatistic> writtenStatistics;
  final VoidCallback onRetryWritten;

  final bool showPractical;
  final bool isLoadingPractical;
  final String? practicalError;
  final List<CertificateExamStatistic> practicalStatistics;
  final VoidCallback onRetryPractical;

  final bool showIntegrated;
  final bool isLoadingIntegrated;
  final String? integratedError;
  final List<CertificateExamStatistic> integratedStatistics;
  final VoidCallback? onRetryIntegrated;

  const CertificateStatisticsSection({
    super.key,
    required this.baseYear,
    this.showWritten = true,
    required this.isLoadingWritten,
    required this.writtenError,
    required this.writtenStatistics,
    required this.onRetryWritten,
    this.showPractical = true,
    required this.isLoadingPractical,
    required this.practicalError,
    required this.practicalStatistics,
    required this.onRetryPractical,
    this.showIntegrated = false,
    this.isLoadingIntegrated = false,
    this.integratedError,
    this.integratedStatistics = const [],
    this.onRetryIntegrated,
  });

  @override
  Widget build(BuildContext context) {
    final hasTableData =
        (showWritten && writtenStatistics.isNotEmpty) ||
        (showPractical && practicalStatistics.isNotEmpty) ||
        (showIntegrated && integratedStatistics.isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showWritten)
          _CertificateExamStatisticsCard(
            title: '필기시험 현황',
            icon: Icons.edit_note_rounded,
            isLoading: isLoadingWritten,
            errorMessage: writtenError,
            statistics: writtenStatistics,
            emptyMessage: '해당 종목의 필기시험 통계가 없습니다.',
            onRetry: onRetryWritten,
          ),
        if (showWritten && (showPractical || showIntegrated))
          SizedBox(height: 14),
        if (showPractical)
          _CertificateExamStatisticsCard(
            title: '실기/면접 시험 현황',
            icon: Icons.build_outlined,
            isLoading: isLoadingPractical,
            errorMessage: practicalError,
            statistics: practicalStatistics,
            emptyMessage: '해당 종목의 실기/면접 시험 통계가 없습니다.',
            onRetry: onRetryPractical,
          ),
        if (showPractical && showIntegrated) SizedBox(height: 14),
        if (showIntegrated)
          _CertificateExamStatisticsCard(
            title: '통합시험 현황',
            icon: Icons.assignment_outlined,
            isLoading: isLoadingIntegrated,
            errorMessage: integratedError,
            statistics: integratedStatistics,
            emptyMessage: '해당 종목의 통합시험 통계가 없습니다.',
            onRetry: onRetryIntegrated ?? onRetryWritten,
          ),
        if (hasTableData) ...[
          SizedBox(height: 14),
          _CertificateExamStatisticsTablesCard(
            writtenStatistics: showWritten ? writtenStatistics : const [],
            practicalStatistics: showPractical ? practicalStatistics : const [],
            integratedStatistics: showIntegrated
                ? integratedStatistics
                : const [],
          ),
        ],
      ],
    );
  }
}

class _CertificateExamStatisticsCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isLoading;
  final String? errorMessage;
  final List<CertificateExamStatistic> statistics;
  final String emptyMessage;
  final VoidCallback onRetry;

  const _CertificateExamStatisticsCard({
    required this.title,
    required this.icon,
    required this.isLoading,
    required this.errorMessage,
    required this.statistics,
    required this.emptyMessage,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return _StatisticsCardShell(
      title: title,
      icon: icon,
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (isLoading) {
      return _StatisticsLoading();
    }

    if (errorMessage != null) {
      return _StatisticsError(message: errorMessage!, onRetry: onRetry);
    }

    if (statistics.isEmpty) {
      return _StatisticsEmpty(message: emptyMessage);
    }

    return _CertificateExamStatisticsLineChart(statistics: statistics);
  }
}

class _CertificateExamStatisticsTablesCard extends StatelessWidget {
  final List<CertificateExamStatistic> writtenStatistics;
  final List<CertificateExamStatistic> practicalStatistics;
  final List<CertificateExamStatistic> integratedStatistics;

  const _CertificateExamStatisticsTablesCard({
    required this.writtenStatistics,
    required this.practicalStatistics,
    required this.integratedStatistics,
  });

  @override
  Widget build(BuildContext context) {
    return _StatisticsCardShell(
      title: '연도별 합격 현황',
      icon: Icons.table_chart_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (writtenStatistics.isNotEmpty)
            _ExamStatisticsTable(title: '필기', statistics: writtenStatistics),
          if (writtenStatistics.isNotEmpty && practicalStatistics.isNotEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 22),
              child: Divider(height: 1, color: context.colors.border),
            ),
          if (practicalStatistics.isNotEmpty)
            _ExamStatisticsTable(
              title: '실기/면접',
              statistics: practicalStatistics,
            ),
          if (integratedStatistics.isNotEmpty &&
              (writtenStatistics.isNotEmpty || practicalStatistics.isNotEmpty))
            Padding(
              padding: EdgeInsets.symmetric(vertical: 22),
              child: Divider(height: 1, color: context.colors.border),
            ),
          if (integratedStatistics.isNotEmpty)
            _ExamStatisticsTable(title: '통합', statistics: integratedStatistics),
        ],
      ),
    );
  }
}

class _ExamStatisticsTable extends StatelessWidget {
  final String title;
  final List<CertificateExamStatistic> statistics;

  const _ExamStatisticsTable({required this.title, required this.statistics});

  @override
  Widget build(BuildContext context) {
    final sortedStatistics = [...statistics]
      ..sort((a, b) => b.year.compareTo(a.year));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: context.colors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: context.colors.border),
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _ExamStatisticsTableRow(
                isHeader: true,
                year: '연도',
                examineeCount: '응시수',
                passerCount: '합격수',
                passRate: '합격률',
              ),
              ...List.generate(sortedStatistics.length, (index) {
                final statistic = sortedStatistics[index];

                return _ExamStatisticsTableRow(
                  year: '${statistic.year}',
                  examineeCount: '${_formatCount(statistic.examineeCount)}명',
                  passerCount: '${_formatCount(statistic.passerCount)}명',
                  passRate: '${statistic.passRate.toStringAsFixed(1)}%',
                  showTopBorder: true,
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
}

class _ExamStatisticsTableRow extends StatelessWidget {
  final bool isHeader;
  final String year;
  final String examineeCount;
  final String passerCount;
  final String passRate;
  final bool showTopBorder;

  const _ExamStatisticsTableRow({
    this.isHeader = false,
    required this.year,
    required this.examineeCount,
    required this.passerCount,
    required this.passRate,
    this.showTopBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(
      color: isHeader
          ? context.colors.textPrimary
          : context.colors.textSecondary,
      fontSize: isHeader ? 12 : 11,
      fontWeight: isHeader ? FontWeight.w800 : FontWeight.w600,
    );

    return Container(
      decoration: BoxDecoration(
        color: isHeader
            ? context.colors.pinkSoft.withValues(alpha: 0.55)
            : context.colors.surface,
        border: showTopBorder
            ? Border(top: BorderSide(color: context.colors.border))
            : null,
      ),
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 17,
            child: Text(year, textAlign: TextAlign.center, style: textStyle),
          ),
          Expanded(
            flex: 28,
            child: Text(
              examineeCount,
              textAlign: TextAlign.center,
              style: textStyle,
            ),
          ),
          Expanded(
            flex: 28,
            child: Text(
              passerCount,
              textAlign: TextAlign.center,
              style: textStyle,
            ),
          ),
          Expanded(
            flex: 27,
            child: Text(
              passRate,
              textAlign: TextAlign.center,
              style: textStyle.copyWith(
                color: isHeader
                    ? context.colors.textPrimary
                    : context.colors.pinkDeep,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatisticsCardShell extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _StatisticsCardShell({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: certificateCardDecoration(context: context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: context.colors.pinkDeep, size: 22),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 18),
          Divider(height: 1, color: context.colors.border),
          SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _StatisticsLoading extends StatelessWidget {
  const _StatisticsLoading();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: context.colors.pinkDeep,
              ),
            ),
            SizedBox(height: 12),
            Text(
              '조회 중...',
              style: TextStyle(
                color: context.colors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatisticsEmpty extends StatelessWidget {
  final String message;

  const _StatisticsEmpty({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 22),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: context.colors.textSecondary,
            fontSize: 13,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}

class _StatisticsError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _StatisticsError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 14),
      child: Column(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: context.colors.pinkDeep,
            size: 30,
          ),
          SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.colors.textSecondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onRetry,
            style: OutlinedButton.styleFrom(
              foregroundColor: context.colors.pinkDeep,
              side: BorderSide(color: context.colors.pinkDeep),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
            ),
            icon: Icon(Icons.refresh_rounded, size: 18),
            label: Text('다시 조회', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

String _formatCount(int value) {
  return value.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (match) => ',',
  );
}

class _CertificateExamStatisticsLineChart extends StatelessWidget {
  final List<CertificateExamStatistic> statistics;

  const _CertificateExamStatisticsLineChart({required this.statistics});

  @override
  Widget build(BuildContext context) {
    if (statistics.isEmpty) {
      return SizedBox.shrink();
    }

    final sortedStatistics = [...statistics]
      ..sort((a, b) => a.year.compareTo(b.year));

    final maximumValue = sortedStatistics.fold<double>(0, (maximum, statistic) {
      final currentMaximum = [
        statistic.registrationCount,
        statistic.examineeCount,
        statistic.passerCount,
      ].reduce((a, b) => a > b ? a : b);

      return currentMaximum > maximum ? currentMaximum.toDouble() : maximum;
    });

    final chartMaximumY = maximumValue <= 0 ? 10.0 : maximumValue * 1.2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatisticsChartLegend(
          items: [
            _StatisticsLegendItem(label: '접수자', color: context.colors.pinkDeep),
            _StatisticsLegendItem(label: '응시자', color: context.colors.info),
            _StatisticsLegendItem(label: '합격자', color: context.colors.correct),
          ],
        ),
        SizedBox(height: 20),
        SizedBox(
          height: 290,
          child: Padding(
            padding: EdgeInsets.only(left: 4, right: 12, top: 8),
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (sortedStatistics.length - 1).toDouble(),
                minY: 0,
                maxY: chartMaximumY,
                clipData: FlClipData(
                  top: false,
                  bottom: false,
                  left: false,
                  right: false,
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: _calculateChartInterval(chartMaximumY),
                  getDrawingHorizontalLine: (_) {
                    return FlLine(color: context.colors.border, strokeWidth: 1);
                  },
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 34,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        if (value % 1 != 0) {
                          return SizedBox.shrink();
                        }

                        final index = value.toInt();
                        if (index < 0 || index >= sortedStatistics.length) {
                          return SizedBox.shrink();
                        }

                        return Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            '${sortedStatistics[index].year}',
                            style: TextStyle(
                              color: context.colors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 48,
                      interval: _calculateChartInterval(chartMaximumY),
                      getTitlesWidget: (value, meta) {
                        return Padding(
                          padding: EdgeInsets.only(right: 6),
                          child: Text(
                            _formatCompactNumber(value),
                            style: TextStyle(
                              color: context.colors.textSecondary,
                              fontSize: 10,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final labels = ['접수자', '응시자', '합격자'];

                        final statisticIndex = spot.x.round();
                        final statistic =
                            statisticIndex >= 0 &&
                                statisticIndex < sortedStatistics.length
                            ? sortedStatistics[statisticIndex]
                            : null;

                        final passRateText =
                            spot.barIndex == 2 && statistic != null
                            ? '\n합격률 '
                                  '${statistic.passRate.toStringAsFixed(1)}%'
                            : '';

                        return LineTooltipItem(
                          '${labels[spot.barIndex]}\n'
                          '${_formatCount(spot.y.round())}명'
                          '$passRateText',
                          TextStyle(
                            color: spot.bar.color ?? context.colors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                lineBarsData: [
                  _buildStatisticsLine(
                    statistics: sortedStatistics,
                    color: context.colors.pinkDeep,
                    dotColor: context.colors.surface,
                    valueSelector: (item) => item.registrationCount,
                  ),
                  _buildStatisticsLine(
                    statistics: sortedStatistics,
                    color: context.colors.info,
                    dotColor: context.colors.surface,
                    valueSelector: (item) => item.examineeCount,
                  ),
                  _buildStatisticsLine(
                    statistics: sortedStatistics,
                    color: context.colors.correct,
                    dotColor: context.colors.surface,
                    valueSelector: (item) => item.passerCount,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  static LineChartBarData _buildStatisticsLine({
    required List<CertificateExamStatistic> statistics,
    required Color color,
    required Color dotColor,
    required int Function(CertificateExamStatistic item) valueSelector,
  }) {
    return LineChartBarData(
      isCurved: false,
      color: color,
      barWidth: 3,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, barData, index) {
          return FlDotCirclePainter(
            radius: 4,
            color: dotColor,
            strokeWidth: 2,
            strokeColor: color,
          );
        },
      ),
      belowBarData: BarAreaData(show: false),
      spots: List.generate(statistics.length, (index) {
        return FlSpot(
          index.toDouble(),
          valueSelector(statistics[index]).toDouble(),
        );
      }),
    );
  }

  static double _calculateChartInterval(double maximumY) {
    if (maximumY <= 10) return 2;
    if (maximumY <= 100) return 20;
    if (maximumY <= 1000) return 200;
    if (maximumY <= 10000) return 2000;
    if (maximumY <= 100000) return 20000;
    return maximumY / 5;
  }

  static String _formatCompactNumber(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}백만';
    }
    if (value >= 10000) {
      return '${(value / 10000).toStringAsFixed(1)}만';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}천';
    }
    return value.round().toString();
  }
}

class _StatisticsChartLegend extends StatelessWidget {
  final List<_StatisticsLegendItem> items;

  const _StatisticsChartLegend({required this.items});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: items.map((item) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: item.color,
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: 6),
            Text(
              item.label,
              style: TextStyle(
                color: context.colors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}

class _StatisticsLegendItem {
  final String label;
  final Color color;

  const _StatisticsLegendItem({required this.label, required this.color});
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
