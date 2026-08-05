import 'package:flutter/material.dart';

import '../../theme.dart';

class AdminTheme extends StatelessWidget {
  const AdminTheme({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;
    final accentColor = colors.lavenderAccent;
    final selectedColor = colors.lavender;
    final adminColorScheme = theme.colorScheme.copyWith(
      primary: accentColor,
      secondary: accentColor,
    );

    return Theme(
      data: theme.copyWith(
        colorScheme: adminColorScheme,
        splashColor: selectedColor.withValues(alpha: 0.7),
        highlightColor: selectedColor.withValues(alpha: 0.45),
        focusColor: selectedColor.withValues(alpha: 0.55),
        hoverColor: selectedColor.withValues(alpha: 0.35),
        inputDecorationTheme: theme.inputDecorationTheme.copyWith(
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: accentColor, width: 1.5),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: accentColor,
            foregroundColor: colors.onPrimary,
            disabledBackgroundColor: colors.surfaceMuted,
            disabledForegroundColor: colors.textDisabled,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: accentColor,
            side: BorderSide(color: accentColor),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: accentColor),
        ),
        floatingActionButtonTheme: theme.floatingActionButtonTheme.copyWith(
          backgroundColor: accentColor,
          foregroundColor: colors.onPrimary,
        ),
        chipTheme: theme.chipTheme.copyWith(
          color: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed) ||
                states.contains(WidgetState.selected)) {
              return selectedColor;
            }
            return null;
          }),
          selectedColor: selectedColor,
          checkmarkColor: accentColor,
        ),
        progressIndicatorTheme: theme.progressIndicatorTheme.copyWith(
          color: accentColor,
        ),
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: accentColor,
          selectionColor: selectedColor,
          selectionHandleColor: accentColor,
        ),
        checkboxTheme: theme.checkboxTheme.copyWith(
          fillColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return accentColor;
            return null;
          }),
          checkColor: WidgetStatePropertyAll(colors.onPrimary),
        ),
        radioTheme: theme.radioTheme.copyWith(
          fillColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return accentColor;
            return null;
          }),
        ),
        switchTheme: theme.switchTheme.copyWith(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return accentColor;
            return null;
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return selectedColor;
            return null;
          }),
        ),
        sliderTheme: theme.sliderTheme.copyWith(
          activeTrackColor: accentColor,
          thumbColor: accentColor,
          overlayColor: selectedColor,
          valueIndicatorColor: accentColor,
        ),
        tabBarTheme: theme.tabBarTheme.copyWith(
          labelColor: accentColor,
          indicatorColor: accentColor,
          overlayColor: WidgetStatePropertyAll(selectedColor),
        ),
        segmentedButtonTheme: SegmentedButtonThemeData(
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected) ||
                  states.contains(WidgetState.pressed)) {
                return selectedColor;
              }
              return colors.surface;
            }),
            foregroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) return accentColor;
              return colors.textPrimary;
            }),
            side: WidgetStatePropertyAll(BorderSide(color: colors.border)),
          ),
        ),
      ),
      child: child,
    );
  }
}
