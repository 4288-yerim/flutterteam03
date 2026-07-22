import 'package:flutter/material.dart';

import '../../widgets/app_button.dart';

const Color certificatePrimaryPink = Color(0xFFF0788F);
const Color certificatePinkSoft = Color(0xFFFCE1E8);
const Color certificateLavender = Color(0xFFE6E1FB);
const Color certificateSoftBlue = Color(0xFFE1E9FB);
const Color certificateMint = Color(0xFFDFF5EA);

const Color certificateDarkText = Color(0xFF1A1A1A);
const Color certificateBodyText = Color(0xFF4A4A4A);
const Color certificateGrayText = Color(0xFF9AA0AC);
const Color certificateBorderColor = Color(0xFFF0EDF0);

BoxDecoration certificateCardDecoration({
  Color backgroundColor = Colors.white,
  Color borderColor = certificateBorderColor,
  bool showBorder = false,
}) {
  return BoxDecoration(
    color: backgroundColor,
    borderRadius: BorderRadius.circular(22),
    border: showBorder
        ? Border.all(
      color: borderColor,
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
          style: const TextStyle(
            color: certificateDarkText,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: const TextStyle(
            color: certificateGrayText,
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
                style: const TextStyle(
                  color: certificateDarkText,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
            ),
            if (count != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: certificatePinkSoft,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$count개',
                  style: const TextStyle(
                    color: certificatePrimaryPink,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: const TextStyle(
            color: certificateGrayText,
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
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: certificateCardDecoration(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CertificateEmptyIcon(
                icon: Icons.error_outline_rounded,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: certificateBodyText,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
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

  const EmptyFilterResult({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 30,
      ),
      decoration: certificateCardDecoration(),
      child: Column(
        children: [
          const CertificateEmptyIcon(
            icon: Icons.inbox_outlined,
          ),
          const SizedBox(height: 13),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: certificateGrayText,
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

  const EmptyInlineResult({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: certificateGrayText,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class CertificateEmptyIcon extends StatelessWidget {
  final IconData icon;

  const CertificateEmptyIcon({
    super.key,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: certificatePinkSoft,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Icon(
        icon,
        color: certificatePrimaryPink,
        size: 27,
      ),
    );
  }
}