import 'package:flutter/material.dart';

import '../theme.dart';

RoundedRectangleBorder get appDialogShape {
  return RoundedRectangleBorder(borderRadius: BorderRadius.circular(24));
}

class AppAlertDialog extends StatelessWidget {
  const AppAlertDialog({
    super.key,
    this.title,
    this.content,
    this.actions,
    this.icon,
    this.isDestructive = false,
    this.insetPadding,
    this.contentPadding,
    this.actionsPadding,
    this.backgroundColor,
  });

  final Widget? title;
  final Widget? content;
  final List<Widget>? actions;
  final IconData? icon;
  final bool isDestructive;
  final EdgeInsets? insetPadding;
  final EdgeInsets? contentPadding;
  final EdgeInsets? actionsPadding;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: backgroundColor ?? context.colors.surfaceElevated,
      surfaceTintColor: context.colors.surfaceElevated,
      shape: appDialogShape,
      insetPadding: insetPadding,
      contentPadding: contentPadding,
      actionsPadding: actionsPadding,
      title: icon == null || title == null
          ? title
          : Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: isDestructive
                        ? context.colors.incorrectSoft
                        : context.colors.lavender,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    icon,
                    color: isDestructive
                        ? context.colors.incorrect
                        : context.colors.pinkStart,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: title!),
              ],
            ),
      content: content == null
          ? null
          : DefaultTextStyle.merge(
              style: TextStyle(color: context.colors.textSecondary),
              child: content!,
            ),
      actions: actions,
    );
  }
}

class AppDialogTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isDestructive;

  const AppDialogTitle({
    super.key,
    required this.icon,
    required this.title,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = isDestructive
        ? context.colors.incorrect
        : context.colors.pinkStart;
    final backgroundColor = isDestructive
        ? context.colors.incorrectSoft
        : context.colors.lavender;

    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: accentColor, size: 21),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: context.colors.textPrimary,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}
