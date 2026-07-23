import 'package:flutter/material.dart';

import '../theme.dart';

/// 앱 전역에서 쓰는 공통 확인 다이얼로그.
///
/// "생성 취소할까요?", "오답 기록이 없어요", "자격증이 다른 것 같아요" 처럼
/// 원형 그라데이션 아이콘 + 제목 + 설명 + 버튼(1~2개) 패턴이 페이지마다
/// 반복되고 있어서 하나로 통일했습니다.
class AppConfirmDialog extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String primaryLabel;
  final VoidCallback onPrimaryPressed;
  final String? secondaryLabel;
  final VoidCallback? onSecondaryPressed;
  final Widget? extra;

  const AppConfirmDialog({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.primaryLabel,
    required this.onPrimaryPressed,
    this.secondaryLabel,
    this.onSecondaryPressed,
    this.extra,
  });

  /// [T]를 반환하는 확인 다이얼로그를 띄웁니다.
  /// [preventBack]이 true면 하드웨어 뒤로가기로 닫히지 않습니다.
  static Future<T?> show<T>(
      BuildContext context, {
        required IconData icon,
        required String title,
        required String description,
        required String primaryLabel,
        required VoidCallback onPrimaryPressed,
        String? secondaryLabel,
        VoidCallback? onSecondaryPressed,
        Widget? extra,
        bool barrierDismissible = true,
        bool preventBack = false,
      }) {
    final dialog = AppConfirmDialog(
      icon: icon,
      title: title,
      description: description,
      primaryLabel: primaryLabel,
      onPrimaryPressed: onPrimaryPressed,
      secondaryLabel: secondaryLabel,
      onSecondaryPressed: onSecondaryPressed,
      extra: extra,
    );

    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        child: preventBack ? PopScope(canPop: false, child: dialog) : dialog,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.pink.withValues(alpha: 0.18),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.pinkGradient,
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style:  TextStyle(
              color: context.colors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.colors.textSecondary,
              fontSize: 13.5,
              height: 1.5,
            ),
          ),
          if (extra != null) ...[
            const SizedBox(height: 14),
            extra!,
          ],
          const SizedBox(height: 24),
          if (secondaryLabel == null || onSecondaryPressed == null)
            _PrimaryButton(label: primaryLabel, onPressed: onPrimaryPressed)
          else
            Row(
              children: [
                Expanded(
                  child: _SecondaryButton(
                    label: secondaryLabel!,
                    onPressed: onSecondaryPressed!,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PrimaryButton(
                    label: primaryLabel,
                    onPressed: onPrimaryPressed,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _PrimaryButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: AppColors.pinkGradient,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onPressed,
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _SecondaryButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: Material(
        color: context.colors.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onPressed,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}