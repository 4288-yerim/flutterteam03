import 'package:flutter/material.dart';

/// 버튼 스타일 종류
enum AppButtonType {
  /// 핑크 그라데이션 (채워진 버튼)
  primaryPink,

  /// 핑크 테두리만 있는 버튼 (배경 흰색)
  outlinePink,

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

  const AppButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.type = AppButtonType.primaryPink,
    this.borderRadius = 16,
    this.height = 56,
  });

  @override
  Widget build(BuildContext context) {
    switch (type) {
      case AppButtonType.primaryPink:
        return _GradientButton(
          text: text,
          onPressed: onPressed,
          height: height,
          borderRadius: borderRadius,
          gradientColors: const [Color(0xFFFF9FB6), Color(0xFFFF5F8F)],
          textColor: Colors.white,
        );

      case AppButtonType.primaryBlue:
        return _GradientButton(
          text: text,
          onPressed: onPressed,
          height: height,
          borderRadius: borderRadius,
          gradientColors: const [Color(0xFF5B8DEF), Color(0xFF2F6BEB)],
          textColor: Colors.white,
        );

      case AppButtonType.outlinePink:
        return SizedBox(
          width: double.infinity,
          height: height,
          child: OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFFFF6B95), width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(borderRadius),
              ),
            ),
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFFFF6B95),
              ),
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
              backgroundColor: const Color(0xFFF3F4F7),
              foregroundColor: const Color(0xFF9AA0AC),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(borderRadius),
              ),
            ),
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF9AA0AC),
              ),
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
  final List<Color> gradientColors;
  final Color textColor;

  const _GradientButton({
    required this.text,
    required this.onPressed,
    required this.height,
    required this.borderRadius,
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
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}