import 'package:flutter/material.dart';

import '../../theme.dart';
import '../services/certificate_category_content_service.dart';
import 'certificate_common_widgets.dart';
import 'certificate_schedule_notice_content_card.dart';

class OtherCertificateScheduleNoticeCard extends StatelessWidget {
  const OtherCertificateScheduleNoticeCard({super.key});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: certificateCardDecoration(context: context),
        child: const Text('시험 일정은 종목별, 지역별로 상이할 수 있습니다.'),
      );
}

class OtherCertificateExamInformationCard extends StatelessWidget {
  const OtherCertificateExamInformationCard({
    super.key,
    required this.writtenFee,
    required this.practicalFee,
    required this.examTrends,
    required this.howToObtain,
    this.examFeeLinks = const [],
    this.examTrendsLinks = const [],
    this.howToObtainLinks = const [],
    this.onOpenLink,
  });

  final int? writtenFee;
  final int? practicalFee;
  final String examTrends;
  final String howToObtain;
  final List<CertificateContentLink> examFeeLinks;
  final List<CertificateContentLink> examTrendsLinks;
  final List<CertificateContentLink> howToObtainLinks;
  final ValueChanged<String>? onOpenLink;

  @override
  Widget build(BuildContext context) {
    final sections = <Widget>[
      if (writtenFee != null || practicalFee != null)
        _ExamInformationSection(
          title: '응시 수수료',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (writtenFee != null)
                _ExamFeeRow(
                  label: practicalFee == null ? '통합' : '필기',
                  fee: writtenFee!,
                ),
              if (writtenFee != null && practicalFee != null)
                const SizedBox(height: 10),
              if (practicalFee != null) _ExamFeeRow(label: '실기', fee: practicalFee!),
              _linkButtons(examFeeLinks),
            ],
          ),
        ),
      if (examTrends.trim().isNotEmpty)
        _ExamInformationSection(
          title: '시험 경향',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(examTrends.trim(), style: _bodyStyle(context)),
              _linkButtons(examTrendsLinks),
            ],
          ),
        ),
      if (howToObtain.trim().isNotEmpty)
        _ExamInformationSection(
          title: '취득 방법',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(howToObtain.trim(), style: _bodyStyle(context)),
              _linkButtons(howToObtainLinks),
            ],
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

  Widget _linkButtons(List<CertificateContentLink> links) {
    if (links.isEmpty || onOpenLink == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: CertificateContentLinkButtons(links: links, onOpenLink: onOpenLink!),
    );
  }

  TextStyle _bodyStyle(BuildContext context) => TextStyle(
        color: context.colors.textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.65,
      );
}

class OtherCertificateEmptyContent extends StatelessWidget {
  const OtherCertificateEmptyContent({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 42),
        decoration: certificateCardDecoration(context: context),
        child: Center(
          child: Text(message,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.colors.textSecondary, fontSize: 14)),
        ),
      );
}

class _ExamInformationSection extends StatelessWidget {
  const _ExamInformationSection({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 13),
          child,
        ],
      );
}

class _ExamFeeRow extends StatelessWidget {
  const _ExamFeeRow({required this.label, required this.fee});
  final String label;
  final int fee;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          SizedBox(width: 48, child: Text(label)),
          Expanded(
            child: Text('${_formatFee(fee)}원',
                style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      );

  static String _formatFee(int value) => value.toString().replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (_) => ',',
      );
}
