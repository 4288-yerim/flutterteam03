import 'package:flutter/material.dart';

import '../../theme.dart';
import '../widgets/admin_certificate_theme.dart';

class AdminCertificateStatisticsEditScreen extends StatelessWidget {
  const AdminCertificateStatisticsEditScreen({
    super.key,
    required this.certificateName,
  });

  final String certificateName;

  @override
  Widget build(BuildContext context) {
    return AdminCertificateTheme(
      child: Scaffold(
        appBar: AppBar(title: Text('$certificateName 통계 수정')),
        body: SafeArea(
          child: Center(
            child: Text(
              '통계 수정 페이지',
              style: TextStyle(
                color: context.colors.textSecondary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
