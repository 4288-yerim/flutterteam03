import 'package:flutter/material.dart';

import '../services/certificate_search_service.dart';
import '../services/professional_certificate_service.dart';
import 'certificate_common_widgets.dart';
import 'certificate_detail_widgets.dart';

class ProfessionalCertificateOverview
    extends StatelessWidget {
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
          qualificationName:
          certificate.qualificationName,
          isTechnical: false,
          action: action,
        ),
        const SizedBox(height: 24),
        CertificateInfoCard(
          items: [
            CertificateInfoItem(
              label: '자격 구분',
              value:
              certificate.qualificationName,
            ),
            if (certificate.seriesnm
                .trim()
                .isNotEmpty)
              CertificateInfoItem(
                label: '분야',
                value: certificate.seriesnm,
              ),
          ],
        ),
      ],
    );
  }
}

class ProfessionalScheduleCard
    extends StatefulWidget {
  final ProfessionalCertificateSchedule schedule;

  const ProfessionalScheduleCard({
    super.key,
    required this.schedule,
  });

  @override
  State<ProfessionalScheduleCard> createState() =>
      _ProfessionalScheduleCardState();
}

class _ProfessionalScheduleCardState
    extends State<ProfessionalScheduleCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final schedule = widget.schedule;

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
      if (_hasDate(
        schedule.examStartAt,
        schedule.examEndAt,
      ))
        CertificateInfoItem(
          label: '시험일',
          value: _formatDateRange(
            schedule.examStartAt,
            schedule.examEndAt,
          ),
        ),
      if (_hasDate(
        schedule.passStartAt,
        schedule.passEndAt,
      ))
        CertificateInfoItem(
          label: '합격자 발표',
          value: _formatDateRange(
            schedule.passStartAt,
            schedule.passEndAt,
          ),
        ),
    ];

    return Container(
      width: double.infinity,
      decoration: certificateCardDecoration(),
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
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 18,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      schedule.description.isEmpty
                          ? '시험 일정'
                          : schedule.description,
                      style: const TextStyle(
                        color: certificateDarkText,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        height: 1.4,
                      ),
                    ),
                  ),
                  if (schedule.isPast) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding:
                      const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F3F6),
                        borderRadius:
                        BorderRadius.circular(20),
                      ),
                      child: const Text(
                        '종료',
                        style: TextStyle(
                          color: certificateGrayText,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 10),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration:
                    const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: certificateGrayText,
                      size: 27,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(
              width: double.infinity,
              height: 0,
            ),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(
                20,
                0,
                20,
                20,
              ),
              child: Column(
                children: [
                  const Divider(
                    height: 1,
                    color: certificateBorderColor,
                  ),
                  const SizedBox(height: 18),
                  ...List.generate(
                    items.length,
                        (index) {
                      final item = items[index];

                      return Column(
                        children: [
                          Row(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 104,
                                child: Text(
                                  item.label,
                                  style: const TextStyle(
                                    color:
                                    certificateGrayText,
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  item.value,
                                  style: const TextStyle(
                                    color:
                                    certificateDarkText,
                                    fontSize: 14,
                                    fontWeight:
                                    FontWeight.w600,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (index != items.length - 1)
                            const Padding(
                              padding:
                              EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                              child: Divider(
                                height: 1,
                                color:
                                certificateBorderColor,
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration:
            const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  static bool _hasDate(
      DateTime? startDate,
      DateTime? endDate,
      ) {
    return startDate != null || endDate != null;
  }

  static String _formatDateRange(
      DateTime? startDate,
      DateTime? endDate,
      ) {
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
      padding: const EdgeInsets.symmetric(
        horizontal: 22,
        vertical: 34,
      ),
      decoration: certificateCardDecoration(),
      child: Column(
        children: [
          CertificateEmptyIcon(
            icon: icon,
          ),
          const SizedBox(height: 15),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: certificateDarkText,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: certificateGrayText,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}