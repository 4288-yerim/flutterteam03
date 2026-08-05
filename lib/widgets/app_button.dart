import 'package:flutter/material.dart';

import '../theme.dart';

/// 버튼 스타일 종류
enum AppButtonType {
  /// 핑크 그라데이션 (채워진 버튼)
  primaryPink,

  /// 핑크 테두리만 있는 버튼 (배경 흰색)
  outlinePink,

  /// 관리자용 보라색 그라데이션 (채워진 버튼)
  primaryAdmin,

  /// 관리자용 보라색 테두리 버튼
  outlineAdmin,

  /// 블루 그라데이션 (채워진 버튼)
  primaryBlue,

  /// 회색 비활성화/보조 버튼
  gray,
}

/// 앱 전체에서 재사용하는 기본 버튼
///
/// 사용 예시:
/// ```dart
/// AppButton(
///   text: '텍스트',
///   type: AppButtonType.primaryPink,
///   onPressed: () {},
/// )
/// ```
class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final AppButtonType type;
  final double borderRadius;
  final double height;
  final IconData? icon;

  const AppButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.type = AppButtonType.primaryPink,
    this.borderRadius = 16,
    this.height = 56,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    switch (type) {
      case AppButtonType.primaryPink:
        return _GradientButton(
          text: text,
          onPressed: onPressed,
          height: height,
          borderRadius: borderRadius,
          icon: icon,
          gradientColors: [colors.pinkStart, colors.pinkDeep],
          textColor: colors.onPrimary,
        );

      case AppButtonType.primaryBlue:
        return _GradientButton(
          text: text,
          onPressed: onPressed,
          height: height,
          borderRadius: borderRadius,
          icon: icon,
          gradientColors: [colors.info, colors.softBlueAccent],
          textColor: colors.onPrimary,
        );

      case AppButtonType.outlinePink:
        return SizedBox(
          width: double.infinity,
          height: height,
          child: OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              backgroundColor: colors.surface,
              side: BorderSide(color: colors.pinkDeep, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(borderRadius),
              ),
            ),
            child: _AppButtonContent(
              text: text,
              icon: icon,
              color: colors.pinkDeep,
            ),
          ),
        );

      case AppButtonType.primaryAdmin:
        return _GradientButton(
          text: text,
          onPressed: onPressed,
          height: height,
          borderRadius: borderRadius,
          icon: icon,
          gradientColors: [
            Color.lerp(colors.lavenderAccent, colors.surface, 0.18)!,
            colors.lavenderAccent,
          ],
          textColor: colors.onPrimary,
        );

      case AppButtonType.outlineAdmin:
        return SizedBox(
          width: double.infinity,
          height: height,
          child: OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              backgroundColor: colors.surface,
              foregroundColor: colors.lavenderAccent,
              side: BorderSide(color: colors.lavenderAccent, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(borderRadius),
              ),
            ),
            child: _AppButtonContent(
              text: text,
              icon: icon,
              color: onPressed == null
                  ? colors.textDisabled
                  : colors.lavenderAccent,
            ),
          ),
        );

      case AppButtonType.gray:
        return SizedBox(
          width: double.infinity,
          height: height,
          child: ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.surfaceMuted,
              foregroundColor: colors.textSecondary,
              disabledBackgroundColor: colors.surfaceMuted,
              disabledForegroundColor: colors.textDisabled,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(borderRadius),
              ),
            ),
            child: _AppButtonContent(
              text: text,
              icon: icon,
              color: onPressed == null
                  ? colors.textDisabled
                  : colors.textSecondary,
            ),
          ),
        );
    }
  }
}

/// 그라데이션 배경 버튼 (핑크 / 블루 공용 내부 위젯)
class _GradientButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final double height;
  final double borderRadius;
  final IconData? icon;
  final List<Color> gradientColors;
  final Color textColor;

  const _GradientButton({
    required this.text,
    required this.onPressed,
    required this.height,
    required this.borderRadius,
    required this.icon,
    required this.gradientColors,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradientColors,
              ),
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            child: Center(
              child: _AppButtonContent(
                text: text,
                icon: icon,
                color: textColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AppButtonContent extends StatelessWidget {
  const _AppButtonContent({
    required this.text,
    required this.icon,
    required this.color,
  });

  final String text;
  final IconData? icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 19, color: color),
          const SizedBox(width: 8),
        ],
        Text(
          text,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
