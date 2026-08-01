import 'package:flutter/material.dart';

import '../../theme.dart';

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
        color: context.colors.surfaceTransparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.colors.border),
      ),
      child: child,
    );
  }
}
