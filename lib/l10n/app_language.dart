import 'dart:ui';

import '../narration/narration_pack.dart';
import 'app_strings.dart';
import 'strings_en.dart';
import 'strings_it.dart';

/// Le lingue in cui si gioca. Ognuna porta i suoi testi d'interfaccia e il
/// suo copione: aggiungerne una è aggiungere una riga qui e i due file.
enum AppLanguage {
  it(Locale('it'), 'Italiano', ItalianStrings()),
  en(Locale('en'), 'English', EnglishStrings());

  final Locale locale;

  /// Il nome della lingua nella lingua stessa, come lo cerca chi la parla.
  final String nativeName;
  final AppStrings strings;

  const AppLanguage(this.locale, this.nativeName, this.strings);

  NarrationPack get pack => strings.pack;

  /// L'italiano a chi parla italiano, l'inglese a tutti gli altri.
  static AppLanguage forLocale(Locale? locale) => locale?.languageCode == 'it' ? it : en;

  /// La lingua del telefono: conta la prima che la persona ha scelto.
  static AppLanguage forDevice(List<Locale>? preferred) =>
      forLocale(preferred == null || preferred.isEmpty ? null : preferred.first);

  static List<Locale> get locales => [for (final language in values) language.locale];
}
