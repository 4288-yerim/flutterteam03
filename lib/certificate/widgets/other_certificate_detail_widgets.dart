import 'package:flutter/material.dart';

import '../../theme.dart';
import 'certificate_common_widgets.dart';

class OtherCertificateScheduleNoticeCard extends StatelessWidget {
  const OtherCertificateScheduleNoticeCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: certificateCardDecoration(context: context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: context.colors.otherCertificateAccent,
                size: 21,
              ),
              const SizedBox(width: 9),
              Text(
                '시험 일정 안내',
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Icon(
                  Icons.circle,
                  size: 5,
                  color: context.colors.textSecondary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '시험 일정은 종목별, 지역별로 상이할 수 있습니다.',
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 14,
                    height: 1.55,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class OtherCertificateExamInformationCard extends StatelessWidget {
  final int? writtenFee;
  final int? practicalFee;
  final String examTrends;
  final String howToObtain;

  const OtherCertificateExamInformationCard({
    super.key,
    required this.writtenFee,
    required this.practicalFee,
    required this.examTrends,
    required this.howToObtain,
  });

  @override
  Widget build(BuildContext context) {
    final sections = <Widget>[
      if (writtenFee != null || practicalFee != null)
        _ExamInformationSection(
          title: '응시 수수료',
          child: Column(
            children: [
              if (writtenFee != null)
                _ExamFeeRow(label: '필기', fee: writtenFee!),
              if (writtenFee != null && practicalFee != null)
                const SizedBox(height: 10),
              if (practicalFee != null)
                _ExamFeeRow(label: '실기', fee: practicalFee!),
            ],
          ),
        ),
      if (examTrends.trim().isNotEmpty)
        _ExamInformationSection(
          title: '시험 경향',
          child: Text(
            examTrends.trim(),
            style: TextStyle(
              color: context.colors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.65,
            ),
          ),
        ),
      if (howToObtain.trim().isNotEmpty)
        _ExamInformationSection(
          title: '취득 방법',
          child: Text(
            howToObtain.trim(),
            style: TextStyle(
              color: context.colors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.65,
            ),
          ),
        ),
    ];

    if (sections.isEmpty) {
      return const OtherCertificateEmptyContent(message: '등록된 자격 정보가 없습니다.');
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: certificateCardDecoration(context: context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(sections.length, (index) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              sections[index],
              if (index != sections.length - 1)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Divider(height: 1, color: context.colors.border),
                ),
            ],
          );
        }),
      ),
    );
  }
}

class OtherCertificateEmptyContent extends StatelessWidget {
  final String message;

  const OtherCertificateEmptyContent({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 42),
      decoration: certificateCardDecoration(context: context),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: context.colors.textSecondary, fontSize: 14),
        ),
      ),
    );
  }
}

class _ExamInformationSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _ExamInformationSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
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
}

class _ExamFeeRow extends StatelessWidget {
  final String label;
  final int fee;

  const _ExamFeeRow({required this.label, required this.fee});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 48,
          child: Text(
            label,
            style: TextStyle(color: context.colors.textPrimary, fontSize: 13),
          ),
        ),
        Expanded(
          child: Text(
            '${_formatFee(fee)}원',
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

  static String _formatFee(int value) {
    return value.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => ',',
    );
  }
}
