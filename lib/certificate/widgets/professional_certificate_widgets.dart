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
  final bool showExamTypeLabels;

  const ProfessionalScheduleCard({
    super.key,
    required this.schedule,
    this.showExamTypeLabels = false,
  });

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
    final examPrefix = widget.showExamTypeLabels
        ? _resolveExamPrefix(schedule.description)
        : '';
    String label(String value) =>
        examPrefix.isEmpty ? value : '$examPrefix $value';

    final items = <CertificateInfoItem>[
      if (_hasDate(
        schedule.examRegistrationStartAt,
        schedule.examRegistrationEndAt,
      ))
        CertificateInfoItem(
          label: label('원서 접수'),
          value: _formatDateRange(
            schedule.examRegistrationStartAt,
            schedule.examRegistrationEndAt,
          ),
        ),
      if (_hasDate(schedule.examStartAt, schedule.examEndAt))
        CertificateInfoItem(
          label: label('시험'),
          value: _formatDateRange(schedule.examStartAt, schedule.examEndAt),
        ),
      if (_hasDate(schedule.passStartAt, schedule.passEndAt))
        CertificateInfoItem(
          label: label('합격 발표'),
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

  CertificateScheduleStatus? _resolveScheduleStatus(
    ProfessionalCertificateSchedule schedule,
  ) {
    final isPractical = _resolveExamPrefix(schedule.description) == '실기/면접';
    return resolveCertificateScheduleStatus(
      writtenRegistrationStartAt: isPractical
          ? null
          : schedule.examRegistrationStartAt,
      writtenRegistrationEndAt: isPractical
          ? null
          : schedule.examRegistrationEndAt,
      writtenExamStartAt: isPractical ? null : schedule.examStartAt,
      writtenExamEndAt: isPractical ? null : schedule.examEndAt,
      writtenPassStartAt: isPractical ? null : schedule.passStartAt,
      writtenPassEndAt: isPractical ? null : schedule.passEndAt,
      practicalRegistrationStartAt: isPractical
          ? schedule.examRegistrationStartAt
          : null,
      practicalRegistrationEndAt: isPractical
          ? schedule.examRegistrationEndAt
          : null,
      practicalExamStartAt: isPractical ? schedule.examStartAt : null,
      practicalExamEndAt: isPractical ? schedule.examEndAt : null,
      practicalPassStartAt: isPractical ? schedule.passStartAt : null,
      practicalPassEndAt: isPractical ? schedule.passEndAt : null,
      showExamTypeLabels: widget.showExamTypeLabels,
    );
  }

  static String _resolveExamPrefix(String description) {
    if (description.contains('필기')) {
      return '필기';
    }

    if (description.contains('실기') || description.contains('면접')) {
      return '실기/면접';
    }

    return '';
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
