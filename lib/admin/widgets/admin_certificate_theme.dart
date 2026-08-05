import 'package:flutter/material.dart';

import '../../theme.dart';

class AdminCertificateTheme extends StatelessWidget {
  const AdminCertificateTheme({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = context.colors.lavenderAccent;
    return Theme(
      data: theme.copyWith(
        colorScheme: theme.colorScheme.copyWith(
          primary: accentColor,
          secondary: accentColor,
        ),
        inputDecorationTheme: theme.inputDecorationTheme.copyWith(
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: accentColor, width: 1.5),
          ),
        ),
      ),
      child: child,
    );
  }
}
