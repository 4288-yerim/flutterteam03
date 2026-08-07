import 'package:flutter/material.dart';

import '../../theme.dart';
import '../../widgets/app_button.dart';

BoxDecoration certificateCardDecoration({
  BuildContext? context,
  Color? backgroundColor,
  Color? borderColor,
  bool showBorder = false,
}) {
  return BoxDecoration(
    color:
        backgroundColor ?? context?.colors.surface ?? AppColors.light.surface,
    borderRadius: BorderRadius.circular(22),
    border: showBorder
        ? Border.all(
            color:
                borderColor ?? context?.colors.border ?? AppColors.light.border,
            width: 1,
          )
        : null,
  );
}

class CertificatePageHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const CertificatePageHeader({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: context.colors.textPrimary,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
          ),
        ),
        SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(
            color: context.colors.textSecondary,
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class CertificateSectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;
  final int? count;

  const CertificateSectionTitle({
    super.key,
    required this.title,
    required this.subtitle,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
            ),
            if (count != null)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: context.colors.pinkSoft,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$count개',
                  style: TextStyle(
                    color: context.colors.pinkDeep,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: 5),
        Text(
          subtitle,
          style: TextStyle(
            color: context.colors.textSecondary,
            fontSize: 13,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class CertificateLoadError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const CertificateLoadError({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(24),
          decoration: certificateCardDecoration(context: context),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CertificateEmptyIcon(icon: Icons.error_outline_rounded),
              SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.colors.textSecondary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              SizedBox(height: 20),
              AppButton(
                text: '다시 시도',
                type: AppButtonType.primaryPink,
                onPressed: onRetry,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EmptyFilterResult extends StatelessWidget {
  final String message;

  const EmptyFilterResult({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      decoration: certificateCardDecoration(context: context),
      child: Column(
        children: [
          CertificateEmptyIcon(icon: Icons.inbox_outlined),
          SizedBox(height: 13),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.colors.textSecondary,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyInlineResult extends StatelessWidget {
  final String message;

  const EmptyInlineResult({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: context.colors.textSecondary, fontSize: 14),
        ),
      ),
    );
  }
}

class CertificateEmptyIcon extends StatelessWidget {
  final IconData icon;

  const CertificateEmptyIcon({super.key, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: context.colors.pinkSoft,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Icon(icon, color: context.colors.pinkDeep, size: 27),
    );
  }
}
