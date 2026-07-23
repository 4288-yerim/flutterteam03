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
  // 퀴즈 정답/오답 피드백용
  final Color correct;
  final Color correctSoft;
  final Color incorrect;
  final Color incorrectSoft;

  // ↓↓↓ 기존 static 스타일 코드(material_summary.dart 등)가 참조하던 색들 — 새로 추가
  final Color pinkBorder;
  final Color pinkSoftAlt;
  final Color textMuted;
  final Color divider;
  final Color surface;
  final Color surfaceMuted;

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
    required this.correct,
    required this.correctSoft,
    required this.incorrect,
    required this.incorrectSoft,
    required this.pinkBorder,
    required this.pinkSoftAlt,
    required this.textMuted,
    required this.divider,
    required this.surface,
    required this.surfaceMuted,
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
    correct: Color(0xFF4CAF7D),
    correctSoft: Color(0xFFE9F7EF),
    incorrect: Color(0xFFE96B7A),
    incorrectSoft: Color(0xFFFFE9EC),
    pinkBorder: Color(0xFFF0C4CF),
    pinkSoftAlt: Color(0xFFFBEFF2),
    textMuted: Color(0xFFB7BDC7),
    divider: Color(0xFFEDEDED),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF5F5F5),
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
    correct: Color(0xFF7FCBB0),
    correctSoft: Color(0xFF1F3A2E),
    incorrect: Color(0xFFE08A94),
    incorrectSoft: Color(0xFF4A2A2E),
    pinkBorder: Color(0xFF5A3E44),
    pinkSoftAlt: Color(0xFF3A2A2E),
    textMuted: Color(0xFF7A7A7A),
    divider: Color(0xFF2A2A2A),
    surface: Color(0xFF1E1E1E),
    surfaceMuted: Color(0xFF262626),
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
    Color? correct,
    Color? correctSoft,
    Color? incorrect,
    Color? incorrectSoft,
    Color? pinkBorder,
    Color? pinkSoftAlt,
    Color? textMuted,
    Color? divider,
    Color? surface,
    Color? surfaceMuted,
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
      correct: correct ?? this.correct,
      correctSoft: correctSoft ?? this.correctSoft,
      incorrect: incorrect ?? this.incorrect,
      incorrectSoft: incorrectSoft ?? this.incorrectSoft,
      pinkBorder: pinkBorder ?? this.pinkBorder,
      pinkSoftAlt: pinkSoftAlt ?? this.pinkSoftAlt,
      textMuted: textMuted ?? this.textMuted,
      divider: divider ?? this.divider,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
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
      correct: Color.lerp(correct, other.correct, t)!,
      correctSoft: Color.lerp(correctSoft, other.correctSoft, t)!,
      incorrect: Color.lerp(incorrect, other.incorrect, t)!,
      incorrectSoft: Color.lerp(incorrectSoft, other.incorrectSoft, t)!,
      pinkBorder: Color.lerp(pinkBorder, other.pinkBorder, t)!,
      pinkSoftAlt: Color.lerp(pinkSoftAlt, other.pinkSoftAlt, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
    );
  }

  // ─────────────────────────────────────────────────────────
  // 하위 호환용 static 상수 — 'pink'는 인스턴스 필드와 이름이 겹치지 않고,
  // const 리터럴이라 const Icon/TextStyle/BorderSide 안에서도 그대로 사용 가능.
  // (라이트 테마 고정값 — 다크모드에서도 이 색을 그대로 씀)
  // ─────────────────────────────────────────────────────────
  static const Color pink = Color(0xFFE9678A);

  // ⚠️ 아래 이름들은 위에서 이미 '인스턴스 필드'로 선언되어 있어서
  // 같은 이름의 static 멤버를 절대 추가할 수 없습니다 (Dart 언어 제약).
  // AppColors.textPrimary / textSecondary / pinkSoft / pinkBorder /
  // pinkSoftAlt / textMuted / divider / surface / surfaceMuted 를 쓰는 곳은
  // 전부 context.colors.xxx 로 직접 바꿔야 합니다. (다음 메시지에서 파일 첨부해주시면 제가 고쳐드릴게요)

  static const Gradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE094A3), Color(0xFFFCE1E8)],
  );

  static const Gradient pinkGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE9678A), Color(0xFFE094A3)],
  );
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