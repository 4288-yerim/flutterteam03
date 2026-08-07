import 'package:flutter/material.dart';

import '../../theme.dart';
import '../services/certificate_category_content_service.dart';
import 'certificate_common_widgets.dart';

class CertificateScheduleNoticeContentCard extends StatelessWidget {
  const CertificateScheduleNoticeContentCard({
    super.key,
    required this.items,
    this.links = const [],
    this.onOpenLink,
  });

  final List<String> items;
  final List<CertificateContentLink> links;
  final ValueChanged<String>? onOpenLink;

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
                color: context.colors.pinkDeep,
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
          ..._noticeRows(context),
          if (links.isNotEmpty && onOpenLink != null) ...[
            const SizedBox(height: 17),
            CertificateContentLinkButtons(links: links, onOpenLink: onOpenLink!),
          ],
        ],
      ),
    );
  }

  List<Widget> _noticeRows(BuildContext context) {
    return [
      for (var index = 0; index < items.length; index++) ...[
        _ScheduleNoticeRow(text: items[index]),
        if (index < items.length - 1) const SizedBox(height: 11),
      ],
    ];
  }
}

class CertificateContentLinkButtons extends StatelessWidget {
  const CertificateContentLinkButtons({super.key, required this.links, required this.onOpenLink});

  final List<CertificateContentLink> links;
  final ValueChanged<String> onOpenLink;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: links.map((link) => InkWell(
                onTap: () => onOpenLink(link.url),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                  decoration: BoxDecoration(color: context.colors.pinkSoft, borderRadius: BorderRadius.circular(10)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(link.label, style: TextStyle(color: context.colors.pinkDeep, fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 7),
                    Icon(Icons.open_in_new_rounded, color: context.colors.pinkDeep, size: 17),
                  ]),
                ),
              )).toList(),
  );
}

class _ScheduleNoticeRow extends StatelessWidget {
  const _ScheduleNoticeRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
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
            text,
            style: TextStyle(
              color: context.colors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.55,
            ),
          ),
        ),
      ],
    );
  }
}
