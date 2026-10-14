import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:oberta/l10n/app_language.dart';
import 'package:oberta/l10n/app_strings.dart';
import 'package:oberta/ui/theme/app_theme.dart';

/// Un `MaterialApp` che parla [language], come quello vero dopo che la
/// lingua è stata scelta: per provare un pezzo di interfaccia in inglese.
Widget appIn(AppLanguage language, Widget home) => MaterialApp(
      theme: buildAppTheme(),
      locale: language.locale,
      supportedLocales: AppLanguage.locales,
      localizationsDelegates: const [
        AppStrings.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      home: home,
    );

/// Parole che in un testo inglese non hanno motivo di esserci, le stesse del
/// controllo sul copione. Si guarda in minuscolo, perché i pulsanti sono
/// tutti maiuscoli; il trattino conta come confine ("Ex-Con" non è "con").
final italianWords = RegExp(
  r"(?<![a-zà-ÿ'-])"
  r'(il|lo|la|gli|le|che|è|e|non|un|una|di|del|della|con|per|su|sono|ha|chi|stanotte|notte|oggi)'
  r"(?![a-zà-ÿ'-])",
);

final genderedWords = RegExp(
  r"\b(he|she|him|her|his|hers|himself|herself|he's|she's|guy|guys|sir|madam|mister|lady|gentleman)\b",
  caseSensitive: false,
);
