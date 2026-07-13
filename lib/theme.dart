import 'package:flutter/material.dart';

/// 앱 전용 컬러 팔레트.
/// ColorScheme(primary, secondary 등)에 없는 커스텀 컬러(그라데이션, blob 색상 등)를
/// 다크/라이트 모드별로 따로 관리하기 위한 ThemeExtension.
///
/// 사용 예시 (위젯 build 안에서):
/// ```dart
/// final colors = Theme.of(context).extension<AppColors>()!;
/// colors.pinkStart
/// ```
@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color pinkStart;
  final Color pinkEnd;
  final Color background;
  final Color textPrimary;
  final Color textSecondary;

  const AppColors({
    required this.pinkStart,
    required this.pinkEnd,
    required this.background,
    required this.textPrimary,
    required this.textSecondary,
  });

  // 라이트 모드 값
  static const light = AppColors(
    pinkStart: Color(0xFFF0788F),
    pinkEnd: Color(0xFFFCE1E8),
    background: Color(0xFFFFFDFC),
    textPrimary: Color(0xFF1A1A1A),
    textSecondary: Color(0xFF9AA0AC),
  );

  // 다크 모드 값 (배경은 어둡게, 핑크는 톤을 살짝 낮춰서 눈부심 방지)
  static const dark = AppColors(
    pinkStart: Color(0xFFB85C6E),
    pinkEnd: Color(0xFF3A2A2E),
    background: Color(0xFF121212),
    textPrimary: Color(0xFFF5F5F5),
    textSecondary: Color(0xFFB0B0B0),
  );

  @override
  AppColors copyWith({
    Color? pinkStart,
    Color? pinkEnd,
    Color? background,
    Color? textPrimary,
    Color? textSecondary,
  }) {
    return AppColors(
      pinkStart: pinkStart ?? this.pinkStart,
      pinkEnd: pinkEnd ?? this.pinkEnd,
      background: background ?? this.background,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
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