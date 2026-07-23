import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:flutter/material.dart';

import 'certificate_common_widgets.dart';

class CertificateDetailHeader extends StatelessWidget {
  final String name;
  final String qualificationName;
  final bool isTechnical;
  final Widget? action;

  const CertificateDetailHeader({
    super.key,
    required this.name,
    required this.qualificationName,
    required this.isTechnical,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final iconBackground = isTechnical
        ? certificateSoftBlue
        : certificateMint;

    final iconColor = isTechnical
        ? const Color(0xFF7191D8)
        : const Color(0xFF65AF91);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: certificateCardDecoration(),
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
          const SizedBox(height: 17),
          Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: certificateDarkText,
              fontSize: 23,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 11),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 13,
              vertical: 7,
            ),
            decoration: BoxDecoration(
              color: certificatePinkSoft,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              qualificationName,
              style: const TextStyle(
                color: certificatePrimaryPink,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

          if (action != null) ...[
            const SizedBox(height: 16),
            action!,
          ],
        ],
      ),
    );
  }
}

class CertificateInfoCard extends StatelessWidget {
  final List<CertificateInfoItem> items;

  const CertificateInfoCard({
    super.key,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: certificateCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '자격 정보',
            style: TextStyle(
              color: certificateDarkText,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),
          ...List.generate(
            items.length,
                (index) {
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
                          style: const TextStyle(
                            color: certificateGrayText,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          item.value.isEmpty ? '-' : item.value,
                          style: const TextStyle(
                            color: certificateDarkText,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (index != items.length - 1)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 15),
                      child: Divider(
                        height: 1,
                        color: certificateBorderColor,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class CertificateInfoItem {
  final String label;
  final String value;

  const CertificateInfoItem({
    required this.label,
    required this.value,
  });
}

class CertificateDetailSectionTitle extends StatelessWidget {
  final String title;

  const CertificateDetailSectionTitle({
    super.key,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: certificateDarkText,
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
  final DateTime? passAnnouncementDate;
  final DateTime? passAnnouncementEndDate;

  const CertificateGoalOption({
    required this.scheduleId,
    required this.targetRound,
    required this.examType,
    required this.examTypeName,
    required this.examDate,
    required this.passAnnouncementDate,
    required this.passAnnouncementEndDate,
  });
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        actionsPadding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        title: const Row(
          children: [
            Icon(
              Icons.event_available_outlined,
              color: certificatePrimaryPink,
              size: 24,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                '캘린더에 추가할까요?',
                style: TextStyle(
                  color: certificateDarkText,
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
          '시험일: ${formatCertificateGoalDate(option.examDate)}\n'
          '휴대폰 캘린더에도 시험 일정을 추가하시겠습니까?',
          style: const TextStyle(
            color: certificateBodyText,
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
            child: const Text(
              '연동 안 함',
              style: TextStyle(
                color: certificateGrayText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext, true);
            },
            style: FilledButton.styleFrom(
              backgroundColor: certificatePrimaryPink,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(
              Icons.calendar_month_outlined,
              size: 18,
            ),
            label: const Text(
              '캘린더에 추가',
              style: TextStyle(
                fontWeight: FontWeight.w700,
              ),
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
    endDate: startDate.add(const Duration(days: 1)),
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
