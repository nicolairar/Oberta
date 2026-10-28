import 'package:flutter/material.dart';

import '../widgets/targa.dart';

/// Palette noir: sfondo quasi nero, accento rosso sangue, dettagli dorati.
class AppColors {
  static const background = Color(0xFF14110F);
  static const surface = Color(0xFF221C19);
  static const surfaceHigh = Color(0xFF302723);
  static const accent = Color(0xFFB3202A);
  static const gold = Color(0xFFC9A227);
  static const textPrimary = Color(0xFFF2EAE1);
  static const textSecondary = Color(0xFFA89E93);
}

class AppText {
  /// Titoli da locandina: serif, maiuscolo spaziato.
  static TextStyle display(double size, {Color color = AppColors.gold}) {
    return TextStyle(
      fontFamily: 'Georgia',
      fontFamilyFallback: const ['serif'],
      fontSize: size,
      fontWeight: FontWeight.bold,
      letterSpacing: size * 0.08,
      height: 1.1,
      color: color,
    );
  }

  static const overline = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 2.4,
  );

  static const body = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 15,
    height: 1.4,
  );
}

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: Brightness.dark,
      surface: AppColors.surface,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: AppText.display(18, color: AppColors.textPrimary),
    ),
    // Every plain button wears the Targa plate (widgets/targa.dart).
    actionIconTheme: const ActionIconThemeData(backButtonIconBuilder: targaBackIcon, closeButtonIconBuilder: targaCloseIcon),
    elevatedButtonTheme: ElevatedButtonThemeData(style: targaButtonStyle(TargaKind.primary)),
    outlinedButtonTheme: OutlinedButtonThemeData(style: targaButtonStyle(TargaKind.secondary)),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.surface,
      contentTextStyle: TextStyle(color: AppColors.textPrimary),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
