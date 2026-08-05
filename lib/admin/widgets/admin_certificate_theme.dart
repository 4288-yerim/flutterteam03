import 'package:flutter/material.dart';

import 'admin_theme.dart';

class AdminCertificateTheme extends StatelessWidget {
  const AdminCertificateTheme({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => AdminTheme(child: child);
}
