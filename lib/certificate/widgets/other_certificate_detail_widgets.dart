import 'package:flutter/material.dart';

import '../../theme.dart';
import 'certificate_common_widgets.dart';

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
