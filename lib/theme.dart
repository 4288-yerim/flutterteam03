// app_colors.dart

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

  // 강조용 (아이콘, 배지, 버튼 등 배경 위에 올라가는 진한 톤)
  final Color pinkDeep;
  final Color lavenderAccent;
  final Color softBlueAccent;
  final Color mintAccent;

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
    required this.pinkDeep,
    required this.lavenderAccent,
    required this.softBlueAccent,
    required this.mintAccent,
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
    pinkDeep: Color(0xFFE9678A),
    lavenderAccent: Color(0xFF9B7AF5),
    softBlueAccent: Color(0xFF6C8EEB),
    mintAccent: Color(0xFF4FAE8E),
  );

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
    pinkDeep: Color(0xFFCB7A8E),
    lavenderAccent: Color(0xFFB39DFF),
    softBlueAccent: Color(0xFF8FA8F0),
    mintAccent: Color(0xFF7FCBB0),
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
    Color? pinkDeep,
    Color? lavenderAccent,
    Color? softBlueAccent,
    Color? mintAccent,
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
      pinkDeep: pinkDeep ?? this.pinkDeep,
      lavenderAccent: lavenderAccent ?? this.lavenderAccent,
      softBlueAccent: softBlueAccent ?? this.softBlueAccent,
      mintAccent: mintAccent ?? this.mintAccent,
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
      pinkDeep: Color.lerp(pinkDeep, other.pinkDeep, t)!,
      lavenderAccent: Color.lerp(lavenderAccent, other.lavenderAccent, t)!,
      softBlueAccent: Color.lerp(softBlueAccent, other.softBlueAccent, t)!,
      mintAccent: Color.lerp(mintAccent, other.mintAccent, t)!,
    );
  }
}

/// 편의용 확장 — context.colors 로 어디서든 바로 접근
extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}

final ThemeData lightTheme = ThemeData(
  brightness: Brightness.light,
  scaffoldBackgroundColor: AppColors.light.background,
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.light.pinkStart,
    brightness: Brightness.light,
  ),
  extensions: const [AppColors.light],
);

final ThemeData darkTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: AppColors.dark.background,
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.dark.pinkStart,
    brightness: Brightness.dark,
  ),
  extensions: const [AppColors.dark],
);