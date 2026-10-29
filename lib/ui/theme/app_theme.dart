import 'package:flutter/material.dart';

import '../widgets/targa.dart';
import 'script_fonts.dart';

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
      fontFamilyFallback: serifFallback,
      fontSize: size,
      fontWeight: FontWeight.bold,
      letterSpacing: size * 0.08,
      height: 1.1,
      color: color,
    );
  }

  static const overline = TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 2.4);

  static const body = TextStyle(color: AppColors.textSecondary, fontSize: 15, height: 1.4);
}

/// The palette every leftover Material control reads: brass for what is
/// chosen or lit, oxblood enamel for containers, lacquer for surfaces. No
/// seeded pastel tones.
final _scheme = ColorScheme.fromSeed(seedColor: AppColors.accent, brightness: Brightness.dark, surface: AppColors.surface).copyWith(
  primary: AppColors.gold,
  onPrimary: Targa.ink,
  primaryContainer: const Color(0xFF7E111A),
  onPrimaryContainer: Targa.cream,
  secondary: Targa.brass,
  onSecondary: Targa.ink,
  secondaryContainer: const Color(0xFF2A211B),
  onSecondaryContainer: Targa.brass,
  tertiary: AppColors.accent,
  onTertiary: Targa.cream,
  error: const Color(0xFFE0525B),
  onSurface: AppColors.textPrimary,
  onSurfaceVariant: AppColors.textSecondary,
  surfaceTint: Colors.transparent,
  surfaceContainerLowest: AppColors.background,
  surfaceContainerLow: AppColors.surface,
  surfaceContainer: AppColors.surface,
  surfaceContainerHigh: AppColors.surfaceHigh,
  surfaceContainerHighest: AppColors.surfaceHigh,
  outline: Targa.brassDim,
  outlineVariant: const Color(0x558C6A26),
  inverseSurface: AppColors.textPrimary,
  onInverseSurface: AppColors.background,
  inversePrimary: Targa.brassDim,
);

const _serif = TextStyle(fontFamily: 'Georgia', fontFamilyFallback: serifFallback, fontWeight: FontWeight.bold);
const _goldEdge = BorderSide(color: Color(0x99D9B45A));

Color? _when(Set<WidgetState> states, {Color? selected, Color? disabled, Color? hovered, Color? otherwise}) {
  if (states.contains(WidgetState.disabled)) return disabled;
  if (states.contains(WidgetState.selected)) return selected;
  if (states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)) return hovered ?? otherwise;
  return otherwise;
}

/// The state colours of the themes, built once: a theme built twice stays
/// equal and never animates between them.
final _textInk = WidgetStateProperty.resolveWith(
  (states) => _when(states, disabled: AppColors.textSecondary, hovered: const Color(0xFFFFE7A8), otherwise: Targa.brass),
);
final _iconInk = WidgetStateProperty.resolveWith(
  (states) => _when(states, disabled: const Color(0x66A89E93), selected: Targa.brass, otherwise: const Color(0xFFF0D590)),
);
final _segmentFace = WidgetStateProperty.resolveWith(
  (states) => _when(states, selected: const Color(0xFF7E111A), disabled: const Color(0xFF1A1512), otherwise: const Color(0xFF15100C)),
);
final _segmentInk = WidgetStateProperty.resolveWith(
  (states) => _when(states, selected: Targa.cream, disabled: AppColors.textSecondary, otherwise: Targa.brass),
);
final _switchThumb = WidgetStateProperty.resolveWith(
  (states) => _when(states, selected: Targa.brass, disabled: const Color(0xFF4A3C26), otherwise: AppColors.textSecondary),
);
final _switchTrack = WidgetStateProperty.resolveWith(
  (states) => _when(states, selected: const Color(0xFF7E111A), disabled: const Color(0xFF1A1512), otherwise: const Color(0xFF15100C)),
);
final _switchEdge = WidgetStateProperty.resolveWith(
  (states) => _when(states, selected: const Color(0xFFD9B45A), disabled: const Color(0xFF3A2E1C), otherwise: Targa.brassDim),
);
final _checkFill = WidgetStateProperty.resolveWith((states) => _when(states, selected: AppColors.gold, otherwise: Colors.transparent));
final _radioFill = WidgetStateProperty.resolveWith((states) => _when(states, selected: AppColors.gold, otherwise: Targa.brassDim));

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    fontFamilyFallback: serifFallback,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: _scheme,
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
    filledButtonTheme: FilledButtonThemeData(style: targaButtonStyle(TargaKind.primary)),
    // A plain text button is brass serif on nothing: a link, not a plate.
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        foregroundColor: _textInk,
        overlayColor: const WidgetStatePropertyAll(Color(0x1FE6C77A)),
        textStyle: WidgetStatePropertyAll(_serif.copyWith(fontSize: 14, letterSpacing: 1.2)),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(foregroundColor: _iconInk, overlayColor: const WidgetStatePropertyAll(Color(0x1FE6C77A))),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: _segmentFace,
        foregroundColor: _segmentInk,
        side: const WidgetStatePropertyAll(_goldEdge),
        overlayColor: const WidgetStatePropertyAll(Color(0x1FE6C77A)),
        textStyle: WidgetStatePropertyAll(_serif.copyWith(fontSize: 13, letterSpacing: 1.4)),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFF15100C),
      selectedColor: const Color(0xFF7E111A),
      disabledColor: const Color(0xFF1A1512),
      checkmarkColor: Targa.cream,
      side: _goldEdge,
      shape: const StadiumBorder(side: _goldEdge),
      labelStyle: _serif.copyWith(fontSize: 13, letterSpacing: 0.6, color: Targa.brass),
      secondaryLabelStyle: _serif.copyWith(fontSize: 13, letterSpacing: 0.6, color: Targa.cream),
      iconTheme: const IconThemeData(color: Targa.brass, size: 18),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: _switchThumb,
      trackColor: _switchTrack,
      trackOutlineColor: _switchEdge,
      overlayColor: const WidgetStatePropertyAll(Color(0x1FE6C77A)),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: AppColors.gold,
      inactiveTrackColor: AppColors.gold.withValues(alpha: 0.18),
      thumbColor: const Color(0xFFE2C46A),
      overlayColor: AppColors.gold.withValues(alpha: 0.16),
      activeTickMarkColor: Colors.transparent,
      inactiveTickMarkColor: Colors.transparent,
      valueIndicatorColor: AppColors.surfaceHigh,
      valueIndicatorTextStyle: const TextStyle(color: AppColors.textPrimary),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: _checkFill,
      checkColor: const WidgetStatePropertyAll(Targa.ink),
      side: const BorderSide(color: Targa.brassDim, width: 1.6),
    ),
    radioTheme: RadioThemeData(fillColor: _radioFill),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.gold, linearTrackColor: Color(0x33C9A227)),
    tabBarTheme: const TabBarThemeData(
      labelColor: AppColors.gold,
      unselectedLabelColor: AppColors.textSecondary,
      indicatorColor: AppColors.gold,
      dividerColor: Color(0x338C6A26),
      overlayColor: WidgetStatePropertyAll(Color(0x1FE6C77A)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: _goldEdge),
      titleTextStyle: AppText.display(20, color: AppColors.gold),
      contentTextStyle: AppText.body,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: _goldEdge),
      textStyle: const TextStyle(color: AppColors.textPrimary),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      dragHandleColor: Targa.brassDim,
    ),
    tooltipTheme: const TooltipThemeData(
      textStyle: TextStyle(color: AppColors.textPrimary),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.all(Radius.circular(8)),
        border: Border.fromBorderSide(_goldEdge),
      ),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppColors.gold,
      selectionColor: Color(0x55C9A227),
      selectionHandleColor: AppColors.gold,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.surface,
      contentTextStyle: const TextStyle(color: AppColors.textPrimary),
      actionTextColor: Targa.brass,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: _goldEdge),
    ),
  );
}
