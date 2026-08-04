import 'package:flutter/material.dart';

import '../../theme.dart';

import '../services/certificate_search_service.dart';
import '../services/professional_certificate_service.dart';
import 'certificate_common_widgets.dart';
import 'certificate_detail_widgets.dart';

class ProfessionalCertificateOverview extends StatelessWidget {
  final Certification certificate;
  final Widget? action;

  const ProfessionalCertificateOverview({
    super.key,
    required this.certificate,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CertificateDetailHeader(
          name: certificate.name,
          qualificationName: certificate.qualificationName,
          isTechnical: false,
          action: action,
        ),
        SizedBox(height: 24),
        CertificateInfoCard(
          items: [
            CertificateInfoItem(
              label: '자격 구분',
              value: certificate.qualificationName,
            ),
            if (certificate.seriesnm.trim().isNotEmpty)
              CertificateInfoItem(label: '분야', value: certificate.seriesnm),
          ],
        ),
      ],
    );
  }
}

class ProfessionalScheduleCard extends StatefulWidget {
  final ProfessionalCertificateSchedule schedule;

  const ProfessionalScheduleCard({super.key, required this.schedule});

  @override
  State<ProfessionalScheduleCard> createState() =>
      _ProfessionalScheduleCardState();
}

class _ProfessionalScheduleCardState extends State<ProfessionalScheduleCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final schedule = widget.schedule;
    final scheduleStatus = _resolveScheduleStatus(schedule);

    final items = <CertificateInfoItem>[
      if (_hasDate(
        schedule.examRegistrationStartAt,
        schedule.examRegistrationEndAt,
      ))
        CertificateInfoItem(
          label: '원서접수',
          value: _formatDateRange(
            schedule.examRegistrationStartAt,
            schedule.examRegistrationEndAt,
          ),
        ),
      if (_hasDate(schedule.examStartAt, schedule.examEndAt))
        CertificateInfoItem(
          label: '시험일',
          value: _formatDateRange(schedule.examStartAt, schedule.examEndAt),
        ),
      if (_hasDate(schedule.passStartAt, schedule.passEndAt))
        CertificateInfoItem(
          label: '합격자 발표',
          value: _formatDateRange(schedule.passStartAt, schedule.passEndAt),
        ),
    ];

    return Container(
      width: double.infinity,
      decoration: certificateCardDecoration(context: context),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      schedule.description.isEmpty
                          ? '시험 일정'
                          : schedule.description,
                      style: TextStyle(
                        color: context.colors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        height: 1.4,
                      ),
                    ),
                  ),
                  if (scheduleStatus != null) ...[
                    SizedBox(width: 8),
                    CertificateScheduleStatusBadge(
                      label: scheduleStatus.label,
                      isActive: scheduleStatus.isActive,
                    ),
                  ],
                  SizedBox(width: 10),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: Duration(milliseconds: 200),
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
            firstChild: SizedBox(width: double.infinity, height: 0),
            secondChild: Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                children: [
                  Divider(height: 1, color: context.colors.border),
                  SizedBox(height: 18),
                  ...List.generate(items.length, (index) {
                    final item = items[index];

                    return Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 104,
                              child: Text(
                                item.label,
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
                            padding: EdgeInsets.symmetric(vertical: 14),
                            child: Divider(
                              height: 1,
                              color: context.colors.border,
                            ),
                          ),
                      ],
                    );
                  }),
                ],
              ),
            ),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  _ProfessionalScheduleStatus? _resolveScheduleStatus(
    ProfessionalCertificateSchedule schedule,
  ) {
    final today = _dateOnly(DateTime.now());

    final prefix = _resolveExamPrefix(schedule.description);

    final examLabel = prefix.isEmpty ? '시험' : '${prefix}시험';

    final registrationLabel = prefix.isEmpty ? '원서접수' : '$prefix 원서접수';

    final upcomingStatus = _resolveUpcomingCountdown(
      today: today,
      schedule: schedule,
      examLabel: examLabel,
      registrationLabel: registrationLabel,
    );
    if (upcomingStatus != null) {
      return upcomingStatus;
    }

    /*
     * 원서접수, 시험, 합격자 발표 일정이 모두 끝났으면
     * 해당 회차 전체 종료
     */
    if (_isEntireScheduleFinished(today, schedule)) {
      return _ProfessionalScheduleStatus(label: '종료', isActive: false);
    }

    // 시험 진행 중
    if (_isDateWithinRange(today, schedule.examStartAt, schedule.examEndAt)) {
      return _ProfessionalScheduleStatus(
        label: '$examLabel 진행중',
        isActive: true,
      );
    }

    // 원서접수 진행 중
    if (_isDateWithinRange(
      today,
      schedule.examRegistrationStartAt,
      schedule.examRegistrationEndAt,
    )) {
      return _ProfessionalScheduleStatus(
        label: '$registrationLabel 중',
        isActive: true,
      );
    }

    /*
     * 현재 진행 중인 일정이 없다면 최근에 종료된 단계 표시
     *
     * 합격자 발표는 전체 종료 판단에만 사용하고
     * 별도 뱃지는 표시하지 않는다.
     */

    if (_isRangeFinished(today, schedule.examStartAt, schedule.examEndAt)) {
      return _ProfessionalScheduleStatus(
        label: '$examLabel 종료',
        isActive: false,
      );
    }

    if (_isRangeFinished(
      today,
      schedule.examRegistrationStartAt,
      schedule.examRegistrationEndAt,
    )) {
      return _ProfessionalScheduleStatus(
        label: '$registrationLabel 종료',
        isActive: false,
      );
    }

    return null;
  }

  static _ProfessionalScheduleStatus? _resolveUpcomingCountdown({
    required DateTime today,
    required ProfessionalCertificateSchedule schedule,
    required String examLabel,
    required String registrationLabel,
  }) {
    if (_isDateWithinRange(
          today,
          schedule.examRegistrationStartAt,
          schedule.examRegistrationEndAt,
        ) ||
        _isDateWithinRange(today, schedule.examStartAt, schedule.examEndAt)) {
      return null;
    }
    final DateTime? countdownDate;
    final String label;
    if (schedule.examRegistrationStartAt != null &&
        _dateOnly(schedule.examRegistrationStartAt!).isAfter(today)) {
      countdownDate = schedule.examRegistrationStartAt;
      label = registrationLabel;
    } else if (schedule.examStartAt != null &&
        (schedule.examRegistrationEndAt == null ||
            _dateOnly(schedule.examRegistrationEndAt!).isBefore(today)) &&
        !_dateOnly(schedule.examStartAt!).isBefore(today)) {
      countdownDate = schedule.examStartAt;
      label = examLabel;
    } else {
      return null;
    }
    return _ProfessionalScheduleStatus(
      label: '$label D-${_dateOnly(countdownDate!).difference(today).inDays}',
      isActive: false,
    );
  }

  static bool _isEntireScheduleFinished(
    DateTime today,
    ProfessionalCertificateSchedule schedule,
  ) {
    final scheduleDates = <DateTime?>[
      schedule.examRegistrationStartAt,
      schedule.examRegistrationEndAt,

      schedule.examStartAt,
      schedule.examEndAt,

      schedule.passStartAt,
      schedule.passEndAt,
    ];

    final existingDates = scheduleDates
        .whereType<DateTime>()
        .map(_dateOnly)
        .toList();

    if (existingDates.isEmpty) {
      return false;
    }

    final lastScheduleDate = existingDates.reduce((currentLatest, date) {
      return date.isAfter(currentLatest) ? date : currentLatest;
    });

    return lastScheduleDate.isBefore(today);
  }

  static String _resolveExamPrefix(String description) {
    if (description.contains('필기')) {
      return '필기';
    }

    if (description.contains('실기')) {
      return '실기';
    }

    if (description.contains('면접')) {
      return '면접';
    }

    return '';
  }

  static bool _isDateWithinRange(
    DateTime today,
    DateTime? startDate,
    DateTime? endDate,
  ) {
    if (startDate == null && endDate == null) {
      return false;
    }

    final start = _dateOnly(startDate ?? endDate!);

    final end = _dateOnly(endDate ?? startDate!);

    return !today.isBefore(start) && !today.isAfter(end);
  }

  static bool _isRangeFinished(
    DateTime today,
    DateTime? startDate,
    DateTime? endDate,
  ) {
    if (startDate == null && endDate == null) {
      return false;
    }

    final lastDate = _dateOnly(endDate ?? startDate!);

    return lastDate.isBefore(today);
  }

  static DateTime _dateOnly(DateTime date) {
    final local = date.toLocal();

    return DateTime(local.year, local.month, local.day);
  }

  static bool _hasDate(DateTime? startDate, DateTime? endDate) {
    return startDate != null || endDate != null;
  }

  static String _formatDateRange(DateTime? startDate, DateTime? endDate) {
    if (startDate == null && endDate == null) {
      return '';
    }

    if (startDate == null) {
      return _formatDate(endDate!);
    }

    if (endDate == null) {
      return _formatDate(startDate);
    }

    final start = _formatDate(startDate);
    final end = _formatDate(endDate);

    if (start == end) {
      return start;
    }

    return '$start ~ $end';
  }

  static String _formatDate(DateTime date) {
    final local = date.toLocal();

    return '${local.year}.'
        '${local.month.toString().padLeft(2, '0')}.'
        '${local.day.toString().padLeft(2, '0')}';
  }
}

class _ProfessionalScheduleStatus {
  final String label;
  final bool isActive;

  const _ProfessionalScheduleStatus({
    required this.label,
    required this.isActive,
  });
}

class ProfessionalEmptyTab extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const ProfessionalEmptyTab({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 22, vertical: 34),
      decoration: certificateCardDecoration(context: context),
      child: Column(
        children: [
          CertificateEmptyIcon(icon: icon),
          SizedBox(height: 15),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.colors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.colors.textSecondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
