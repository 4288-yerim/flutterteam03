// app_colors.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

@immutable
class AppColors extends ThemeExtension<AppColors> {
  // ─────────────────────────────────────────────────────────
  // 브랜드 색상
  // ─────────────────────────────────────────────────────────
  // 주요 버튼, 선택 상태, 강조 아이콘 등에 사용하는 핑크 계열입니다.
  final Color pinkStart;
  final Color pinkEnd;

  // ─────────────────────────────────────────────────────────
  // 화면과 표면
  // ─────────────────────────────────────────────────────────
  // 화면 전체의 가장 아래 배경색입니다.
  final Color background;
  // 카드, 목록 타일, 입력창처럼 배경 위에 놓이는 기본 표면색입니다.
  final Color surface;
  // 다이얼로그, 팝업처럼 기본 카드보다 위에 떠 있는 표면색입니다.
  final Color surfaceElevated;
  // 선택되지 않은 칩, 비활성 영역 등에 사용하는 약한 표면색입니다.
  final Color surfaceMuted;
  // 유리 효과 카드처럼 배경이 일부 비쳐야 하는 표면색입니다.
  final Color surfaceTransparent;

  // ─────────────────────────────────────────────────────────
  // 글자와 아이콘
  // ─────────────────────────────────────────────────────────
  // 제목과 본문 등 가장 중요한 글자색입니다.
  final Color textPrimary;
  // 설명, 부가 정보 등 두 번째 우선순위 글자색입니다.
  final Color textSecondary;
  // 힌트, 시간 정보처럼 더 약하게 보여야 하는 글자색입니다.
  final Color textMuted;
  // 비활성 버튼과 사용할 수 없는 항목의 글자색입니다.
  final Color textDisabled;
  // 기본 아이콘과 보조 아이콘 색상입니다.
  final Color iconPrimary;
  final Color iconSecondary;
  // 핑크색 버튼 등 진한 강조 배경 위에 올라가는 글자·아이콘 색상입니다.
  final Color onPrimary;

  final Color pinkSoft;
  final Color lavender;
  final Color softBlue;
  final Color mint;
  final Color otherCertificateSoft;

  // 강조용 (아이콘, 배지, 버튼 등 배경 위에 올라가는 진한 톤)
  final Color pinkDeep;
  final Color lavenderAccent;
  final Color softBlueAccent;
  final Color mintAccent;
  final Color otherCertificateAccent;

  // ─────────────────────────────────────────────────────────
  // 상태 피드백
  // ─────────────────────────────────────────────────────────
  // 퀴즈 정답/오답 피드백용
  final Color correct;
  final Color correctSoft;
  final Color incorrect;
  final Color incorrectSoft;

  Color get error => incorrect;
  // 주의가 필요한 상태와 그 상태의 연한 배경입니다.
  final Color warning;
  final Color warningSoft;
  // 안내성 상태와 그 상태의 연한 배경입니다.
  final Color info;
  final Color infoSoft;

  // ─────────────────────────────────────────────────────────
  // 테두리, 구분선, 그림자, 오버레이
  // ─────────────────────────────────────────────────────────
  final Color pinkBorder;
  final Color pinkSoftAlt;
  // 카드와 입력창의 일반 테두리색입니다.
  final Color border;
  // 목록과 섹션 사이의 구분선 색상입니다.
  final Color divider;
  // 카드 그림자에 사용하는 색상입니다.
  final Color shadow;
  // 다이얼로그와 로딩 화면 뒤를 가리는 반투명 색상입니다.
  final Color overlay;

  // AppMainBackground 상단의 장식용 원형 색상입니다.
  final Color backgroundBlobPink;
  final Color backgroundBlobLavender;

  const AppColors({
    required this.pinkStart,
    required this.pinkEnd,
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.surfaceMuted,
    required this.surfaceTransparent,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.textDisabled,
    required this.iconPrimary,
    required this.iconSecondary,
    required this.onPrimary,
    required this.pinkSoft,
    required this.lavender,
    required this.softBlue,
    required this.mint,
    required this.otherCertificateSoft,
    required this.pinkDeep,
    required this.lavenderAccent,
    required this.softBlueAccent,
    required this.mintAccent,
    required this.otherCertificateAccent,
    required this.correct,
    required this.correctSoft,
    required this.incorrect,
    required this.incorrectSoft,
    required this.warning,
    required this.warningSoft,
    required this.info,
    required this.infoSoft,
    required this.pinkBorder,
    required this.pinkSoftAlt,
    required this.border,
    required this.divider,
    required this.shadow,
    required this.overlay,
    required this.backgroundBlobPink,
    required this.backgroundBlobLavender,
  });

  static const light = AppColors(
    pinkStart: Color(0xFFE094A3),
    pinkEnd: Color(0xFFFCE1E8),
    background: Color(0xFFFFFDFC),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF5F5F5),
    surfaceTransparent: Color(0xEBFFFFFF),
    textPrimary: Color(0xFF1A1A1A),
    textSecondary: Color(0xFF9AA0AC),
    textMuted: Color(0xFFB7BDC7),
    textDisabled: Color(0xFFC8CBD1),
    iconPrimary: Color(0xFF302C2E),
    iconSecondary: Color(0xFF8E8589),
    onPrimary: Color(0xFFFFFFFF),
    pinkSoft: Color(0xFFF6E8EC),
    lavender: Color(0xFFEEE9FD),
    softBlue: Color(0xFFECF0FD),
    mint: Color(0xFFECF6F3),
    otherCertificateSoft: Color(0xFFFFF1E3),
    pinkDeep: Color(0xFFE9678A),
    lavenderAccent: Color(0xFF9B7AF5),
    softBlueAccent: Color(0xFF6C8EEB),
    mintAccent: Color(0xFF4FAE8E),
    otherCertificateAccent: Color(0xFFE58A36),
    correct: Color(0xFF4CAF7D),
    correctSoft: Color(0xFFE9F7EF),
    incorrect: Color(0xFFE96B7A),
    incorrectSoft: Color(0xFFFFE9EC),
    warning: Color(0xFFE59831),
    warningSoft: Color(0xFFFFF6E8),
    info: Color(0xFF5B8DEF),
    infoSoft: Color(0xFFECF0FD),
    pinkBorder: Color(0xFFF0C4CF),
    pinkSoftAlt: Color(0xFFFBEFF2),
    border: Color(0xFFF0EDF0),
    divider: Color(0xFFEDEDED),
    shadow: Color(0x12000000),
    overlay: Color(0x73000000),
    backgroundBlobPink: Color(0x66FCE7EF),
    backgroundBlobLavender: Color(0x66E8E4FB),
  );

  static const dark = AppColors(
    pinkStart: Color(0xFFB85C6E),
    pinkEnd: Color(0xFF3A2A2E),
    background: Color(0xFF121212),
    surface: Color(0xFF1E1E1E),
    surfaceElevated: Color(0xFF292929),
    surfaceMuted: Color(0xFF262626),
    surfaceTransparent: Color(0xEB1E1E1E),
    textPrimary: Color(0xFFF5F5F5),
    textSecondary: Color(0xFFB0B0B0),
    textMuted: Color(0xFF8A8A8A),
    textDisabled: Color(0xFF666666),
    iconPrimary: Color(0xFFF0ECEE),
    iconSecondary: Color(0xFFB0A8AB),
    onPrimary: Color(0xFFFFFFFF),
    pinkSoft: Color(0xFF4A3238),
    lavender: Color(0xFF322E42),
    softBlue: Color(0xFF29304A),
    mint: Color(0xFF223A2E),
    otherCertificateSoft: Color(0xFF4A3523),
    pinkDeep: Color(0xFFCB7A8E),
    lavenderAccent: Color(0xFFB39DFF),
    softBlueAccent: Color(0xFF8FA8F0),
    mintAccent: Color(0xFF7FCBB0),
    otherCertificateAccent: Color(0xFFF0B35A),
    correct: Color(0xFF7FCBB0),
    correctSoft: Color(0xFF1F3A2E),
    incorrect: Color(0xFFE08A94),
    incorrectSoft: Color(0xFF4A2A2E),
    warning: Color(0xFFF0B35A),
    warningSoft: Color(0xFF493719),
    info: Color(0xFF8FA8F0),
    infoSoft: Color(0xFF29304A),
    pinkBorder: Color(0xFF5A3E44),
    pinkSoftAlt: Color(0xFF3A2A2E),
    border: Color(0xFF3A3A3A),
    divider: Color(0xFF2A2A2A),
    shadow: Color(0x66000000),
    overlay: Color(0x99000000),
    backgroundBlobPink: Color(0x4D6A3B47),
    backgroundBlobLavender: Color(0x4D403A5C),
  );

  @override
  AppColors copyWith({
    Color? pinkStart,
    Color? pinkEnd,
    Color? background,
    Color? surface,
    Color? surfaceElevated,
    Color? surfaceMuted,
    Color? surfaceTransparent,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? textDisabled,
    Color? iconPrimary,
    Color? iconSecondary,
    Color? onPrimary,
    Color? pinkSoft,
    Color? lavender,
    Color? softBlue,
    Color? mint,
    Color? otherCertificateSoft,
    Color? pinkDeep,
    Color? lavenderAccent,
    Color? softBlueAccent,
    Color? mintAccent,
    Color? otherCertificateAccent,
    Color? correct,
    Color? correctSoft,
    Color? incorrect,
    Color? incorrectSoft,
    Color? warning,
    Color? warningSoft,
    Color? info,
    Color? infoSoft,
    Color? pinkBorder,
    Color? pinkSoftAlt,
    Color? border,
    Color? divider,
    Color? shadow,
    Color? overlay,
    Color? backgroundBlobPink,
    Color? backgroundBlobLavender,
  }) {
    return AppColors(
      pinkStart: pinkStart ?? this.pinkStart,
      pinkEnd: pinkEnd ?? this.pinkEnd,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      surfaceTransparent: surfaceTransparent ?? this.surfaceTransparent,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      textDisabled: textDisabled ?? this.textDisabled,
      iconPrimary: iconPrimary ?? this.iconPrimary,
      iconSecondary: iconSecondary ?? this.iconSecondary,
      onPrimary: onPrimary ?? this.onPrimary,
      pinkSoft: pinkSoft ?? this.pinkSoft,
      lavender: lavender ?? this.lavender,
      softBlue: softBlue ?? this.softBlue,
      mint: mint ?? this.mint,
      otherCertificateSoft: otherCertificateSoft ?? this.otherCertificateSoft,
      pinkDeep: pinkDeep ?? this.pinkDeep,
      lavenderAccent: lavenderAccent ?? this.lavenderAccent,
      softBlueAccent: softBlueAccent ?? this.softBlueAccent,
      mintAccent: mintAccent ?? this.mintAccent,
      otherCertificateAccent:
          otherCertificateAccent ?? this.otherCertificateAccent,
      correct: correct ?? this.correct,
      correctSoft: correctSoft ?? this.correctSoft,
      incorrect: incorrect ?? this.incorrect,
      incorrectSoft: incorrectSoft ?? this.incorrectSoft,
      warning: warning ?? this.warning,
      warningSoft: warningSoft ?? this.warningSoft,
      info: info ?? this.info,
      infoSoft: infoSoft ?? this.infoSoft,
      pinkBorder: pinkBorder ?? this.pinkBorder,
      pinkSoftAlt: pinkSoftAlt ?? this.pinkSoftAlt,
      border: border ?? this.border,
      divider: divider ?? this.divider,
      shadow: shadow ?? this.shadow,
      overlay: overlay ?? this.overlay,
      backgroundBlobPink: backgroundBlobPink ?? this.backgroundBlobPink,
      backgroundBlobLavender:
          backgroundBlobLavender ?? this.backgroundBlobLavender,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      pinkStart: Color.lerp(pinkStart, other.pinkStart, t)!,
      pinkEnd: Color.lerp(pinkEnd, other.pinkEnd, t)!,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      surfaceTransparent: Color.lerp(
        surfaceTransparent,
        other.surfaceTransparent,
        t,
      )!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textDisabled: Color.lerp(textDisabled, other.textDisabled, t)!,
      iconPrimary: Color.lerp(iconPrimary, other.iconPrimary, t)!,
      iconSecondary: Color.lerp(iconSecondary, other.iconSecondary, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      pinkSoft: Color.lerp(pinkSoft, other.pinkSoft, t)!,
      lavender: Color.lerp(lavender, other.lavender, t)!,
      softBlue: Color.lerp(softBlue, other.softBlue, t)!,
      mint: Color.lerp(mint, other.mint, t)!,
      otherCertificateSoft: Color.lerp(
        otherCertificateSoft,
        other.otherCertificateSoft,
        t,
      )!,
      pinkDeep: Color.lerp(pinkDeep, other.pinkDeep, t)!,
      lavenderAccent: Color.lerp(lavenderAccent, other.lavenderAccent, t)!,
      softBlueAccent: Color.lerp(softBlueAccent, other.softBlueAccent, t)!,
      mintAccent: Color.lerp(mintAccent, other.mintAccent, t)!,
      otherCertificateAccent: Color.lerp(
        otherCertificateAccent,
        other.otherCertificateAccent,
        t,
      )!,
      correct: Color.lerp(correct, other.correct, t)!,
      correctSoft: Color.lerp(correctSoft, other.correctSoft, t)!,
      incorrect: Color.lerp(incorrect, other.incorrect, t)!,
      incorrectSoft: Color.lerp(incorrectSoft, other.incorrectSoft, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningSoft: Color.lerp(warningSoft, other.warningSoft, t)!,
      info: Color.lerp(info, other.info, t)!,
      infoSoft: Color.lerp(infoSoft, other.infoSoft, t)!,
      pinkBorder: Color.lerp(pinkBorder, other.pinkBorder, t)!,
      pinkSoftAlt: Color.lerp(pinkSoftAlt, other.pinkSoftAlt, t)!,
      border: Color.lerp(border, other.border, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      overlay: Color.lerp(overlay, other.overlay, t)!,
      backgroundBlobPink: Color.lerp(
        backgroundBlobPink,
        other.backgroundBlobPink,
        t,
      )!,
      backgroundBlobLavender: Color.lerp(
        backgroundBlobLavender,
        other.backgroundBlobLavender,
        t,
      )!,
    );
  }

  /// 홈 상단 소개 영역 등에 사용하는 테마 대응 그라데이션입니다.
  LinearGradient get themedHeroGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [pinkStart, pinkEnd],
  );

  /// 주요 실행 버튼과 강조 영역에 사용하는 테마 대응 그라데이션입니다.
  LinearGradient get themedPinkGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [pinkDeep, pinkStart],
  );

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
  AppColors get colors {
    final theme = Theme.of(this);
    return theme.extension<AppColors>() ??
        (theme.brightness == Brightness.dark ? AppColors.dark : AppColors.light);
  }
}

/// 라이트·다크 테마가 같은 규칙을 공유하도록 ThemeData를 만드는 함수입니다.
/// 페이지에서는 이 설정을 다시 선언하지 않고 Theme.of(context)를 사용합니다.
ThemeData _buildTheme({
  required Brightness brightness,
  required AppColors colors,
}) {
  final isDark = brightness == Brightness.dark;

  final colorScheme =
      ColorScheme.fromSeed(
        seedColor: colors.pinkStart,
        brightness: brightness,
      ).copyWith(
        primary: colors.pinkDeep,
        onPrimary: colors.onPrimary,
        surface: colors.surface,
        onSurface: colors.textPrimary,
        error: colors.incorrect,
        onError: colors.onPrimary,
        outline: colors.border,
        outlineVariant: colors.divider,
      );

  final baseTextTheme = ThemeData(brightness: brightness).textTheme.apply(
    bodyColor: colors.textPrimary,
    displayColor: colors.textPrimary,
    decorationColor: colors.textPrimary,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: colors.background,
    textTheme: baseTextTheme,
    extensions: [colors],

    // 앱 전체 기본 아이콘 색상입니다.
    iconTheme: IconThemeData(color: colors.iconPrimary),

    // 투명 AppBar와 상태 표시줄 아이콘 밝기를 현재 테마에 맞춥니다.
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: colors.iconPrimary,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        color: colors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: colors.background,
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
      ),
    ),

    // Card 위젯의 기본 표면, 테두리, 그림자 규칙입니다.
    cardTheme: CardThemeData(
      color: colors.surface,
      surfaceTintColor: Colors.transparent,
      shadowColor: colors.shadow,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: colors.border),
      ),
    ),

    // TextField, TextFormField의 기본 배경과 테두리입니다.
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.surface,
      hintStyle: TextStyle(color: colors.textMuted),
      labelStyle: TextStyle(color: colors.textSecondary),
      prefixIconColor: colors.iconSecondary,
      suffixIconColor: colors.iconSecondary,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colors.pinkDeep, width: 1.5),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colors.divider),
      ),
    ),

    // 버튼 종류별 기본 색상과 모양입니다.
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: colors.pinkDeep,
        foregroundColor: colors.onPrimary,
        disabledBackgroundColor: colors.surfaceMuted,
        disabledForegroundColor: colors.textDisabled,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.pinkDeep,
        side: BorderSide(color: colors.pinkBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: colors.pinkDeep),
    ),

    // 팝업, 다이얼로그, 바텀시트처럼 화면 위에 뜨는 요소입니다.
    dialogTheme: DialogThemeData(
      backgroundColor: colors.surfaceElevated,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        color: colors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
      contentTextStyle: TextStyle(color: colors.textSecondary, fontSize: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colors.surfaceElevated,
      modalBackgroundColor: colors.surfaceElevated,
      surfaceTintColor: Colors.transparent,
      modalBarrierColor: colors.overlay,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: colors.surfaceElevated,
      surfaceTintColor: Colors.transparent,
      textStyle: TextStyle(color: colors.textPrimary),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),

    // 목록 구분선, 로딩 표시, 선택 영역의 공통 색상입니다.
    dividerTheme: DividerThemeData(color: colors.divider, thickness: 1),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: colors.pinkDeep,
      linearTrackColor: colors.surfaceMuted,
      circularTrackColor: colors.surfaceMuted,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: colors.pinkDeep,
      selectionColor: colors.pinkSoft,
      selectionHandleColor: colors.pinkDeep,
    ),

    // SnackBar는 배경과 반대되는 표면색을 사용해 항상 읽히도록 합니다.
    snackBarTheme: SnackBarThemeData(
      backgroundColor: isDark ? colors.surfaceElevated : colors.textPrimary,
      contentTextStyle: TextStyle(
        color: isDark ? colors.textPrimary : colors.onPrimary,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}

/// 앱의 라이트 모드 기본 테마입니다.
final ThemeData lightTheme = _buildTheme(
  brightness: Brightness.light,
  colors: AppColors.light,
);

/// 앱의 다크 모드 기본 테마입니다.
final ThemeData darkTheme = _buildTheme(
  brightness: Brightness.dark,
  colors: AppColors.dark,
);
