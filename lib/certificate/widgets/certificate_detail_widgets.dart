import 'package:flutter/material.dart';

import 'certificate_common_widgets.dart';

class CertificateDetailHeader extends StatelessWidget {
  final String name;
  final String qualificationName;
  final bool isTechnical;

  const CertificateDetailHeader({
    super.key,
    required this.name,
    required this.qualificationName,
    required this.isTechnical,
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
