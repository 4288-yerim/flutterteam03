import 'package:flutter/material.dart';

class AdminMemberDetailSurface extends StatelessWidget {
  const AdminMemberDetailSurface({
    super.key,
    required this.child,
    this.padding,
    this.clipBehavior = Clip.none,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      clipBehavior: clipBehavior,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFECE9F0)),
      ),
      child: child,
    );
  }
}
