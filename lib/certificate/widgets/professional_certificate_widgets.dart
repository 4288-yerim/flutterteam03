import 'package:flutter/material.dart';

import '../services/certificate_search_service.dart';
import 'certificate_detail_widgets.dart';

class ProfessionalCertificateOverview extends StatelessWidget {
  final Certification certificate;

  const ProfessionalCertificateOverview({
    super.key,
    required this.certificate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CertificateDetailHeader(
          name: certificate.name,
          qualificationName: certificate.qualificationName,
          isTechnical: false,
        ),
        const SizedBox(height: 24),
        CertificateInfoCard(
          items: [
            CertificateInfoItem(
              label: '자격 구분',
              value: certificate.qualificationName,
            ),
            if (certificate.seriesnm.trim().isNotEmpty)
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
