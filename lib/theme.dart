import 'package:flutter/material.dart';

@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color pinkStart;
  final Color pinkEnd;
  final Color background;
  final Color textPrimary;
  final Color textSecondary;

  final Color pinkSoft;
  final Color lavender;
  final Color softBlue;
  final Color mint;

  const AppColors({
    required this.pinkStart,
    required this.pinkEnd,
    required this.background,
    required this.textPrimary,
    required this.textSecondary,
    required this.pinkSoft,
    required this.lavender,
    required this.softBlue,
    required this.mint,
  });

  static const light = AppColors(
    pinkStart: Color(0xFFE094A3),
    pinkEnd: Color(0xFFFCE1E8),
    background: Color(0xFFFFFDFC),
    textPrimary: Color(0xFF1A1A1A),
    textSecondary: Color(0xFF9AA0AC),
    pinkSoft: Color(0xFFF6E8EC),
    lavender: Color(0xFFEEE9FD),
    softBlue: Color(0xFFECF0FD),
    mint: Color(0xFFECF6F3),
  );

  // 다크 모드 값 (배경은 어둡게, 파스텔 컬러는 채도를 낮추고 배경과 섞어서 눈부심 방지)
  static const dark = AppColors(
    pinkStart: Color(0xFFB85C6E),
    pinkEnd: Color(0xFF3A2A2E),
    background: Color(0xFF121212),
    textPrimary: Color(0xFFF5F5F5),
    textSecondary: Color(0xFFB0B0B0),
    pinkSoft: Color(0xFF4A3238),
    lavender: Color(0xFF322E42),
    softBlue: Color(0xFF29304A),
    mint: Color(0xFF223A2E),
  );

  @override
  AppColors copyWith({
    Color? pinkStart,
    Color? pinkEnd,
    Color? background,
    Color? textPrimary,
    Color? textSecondary,
    Color? pinkSoft,
    Color? lavender,
    Color? softBlue,
    Color? mint,
  }) {
    return AppColors(
      pinkStart: pinkStart ?? this.pinkStart,
      pinkEnd: pinkEnd ?? this.pinkEnd,
      background: background ?? this.background,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      pinkSoft: pinkSoft ?? this.pinkSoft,
      lavender: lavender ?? this.lavender,
      softBlue: softBlue ?? this.softBlue,
      mint: mint ?? this.mint,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      pinkStart: Color.lerp(pinkStart, other.pinkStart, t)!,
      pinkEnd: Color.lerp(pinkEnd, other.pinkEnd, t)!,
      background: Color.lerp(background, other.background, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      pinkSoft: Color.lerp(pinkSoft, other.pinkSoft, t)!,
      lavender: Color.lerp(lavender, other.lavender, t)!,
      softBlue: Color.lerp(softBlue, other.softBlue, t)!,
      mint: Color.lerp(mint, other.mint, t)!,
    );
  }
}

/// 앱 전체에서 쓰는 라이트 테마
final ThemeData lightTheme = ThemeData(
  brightness: Brightness.light,
  scaffoldBackgroundColor: AppColors.light.background,
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.light.pinkStart,
    brightness: Brightness.light,
  ),
  extensions: const [AppColors.light],
);

/// 앱 전체에서 쓰는 다크 테마
final ThemeData darkTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: AppColors.dark.background,
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.dark.pinkStart,
    brightness: Brightness.dark,
  ),
  extensions: const [AppColors.dark],
);