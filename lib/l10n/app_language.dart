import 'dart:ui';

import '../narration/narration_pack.dart';
import 'app_strings.dart';
import 'languages/de.dart';
import 'languages/es.dart';
import 'languages/fr.dart';
import 'languages/pt.dart';
import 'message_format.dart';
import 'strings_en.dart';
import 'strings_it.dart';

/// The languages the app is translated into. Each one brings its interface
/// texts, its keyed messages and its narrator script. Adding a language is
/// adding one file under `languages/` and one row here (see docs/tecnico.md).
///
/// Italian and English are the source languages: they also have the
/// narrator's voice. The others fall back to English for anything they do
/// not translate, and narrate in text only.
enum AppLanguage {
  it(Locale('it'), 'Italiano', ItalianStrings()),
  en(Locale('en'), 'English', EnglishStrings()),
  es(Locale('es'), 'Español', SpanishStrings()),
  fr(Locale('fr'), 'Français', FrenchStrings()),
  de(Locale('de'), 'Deutsch', GermanStrings()),
  pt(Locale('pt', 'BR'), 'Português (Brasil)', PortugueseStrings());

  final Locale locale;

  /// The language's name in the language itself, as its speakers look for it.
  final String nativeName;
  final AppStrings strings;

  const AppLanguage(this.locale, this.nativeName, this.strings);

  /// The ISO 639-1 code: what the server stores for rooms and queues.
  String get code => locale.languageCode;

  NarrationPack get pack => strings.pack;

  /// Right-to-left scripts (Arabic, Hebrew, Persian, Urdu...). None of the
  /// shipped translations is, but the app lays itself out by this.
  TextDirection get textDirection => rtlLanguageCodes.contains(code) ? TextDirection.rtl : TextDirection.ltr;

  /// Only the source languages have the narrator's recorded voice; the
  /// others read the script on screen.
  bool get hasVoice => this == it || this == en;

  /// Whether a role keeps its capital in the middle of a sentence ("they
  /// were the Doctor", "er war der Arzt") or drops it ("era il dottore").
  bool get capitalizesRoles => this == en || this == de;

  /// The keyed messages of this language (see [message]).
  Map<String, String> get messages => strings.messages;

  /// A keyed message, filled with [args]. A key the language does not
  /// translate yet falls back to English, then to the key itself.
  String message(String key, [Map<String, Object?> args = const {}]) {
    final template = messages[key] ?? AppLanguage.en.messages[key] ?? key;
    return formatMessage(template, args, locale: locale.toLanguageTag().replaceAll('-', '_'));
  }

  static AppLanguage? forCode(String? code) {
    if (code == null) return null;
    final lower = code.toLowerCase();
    for (final language in values) {
      if (language.code == lower) return language;
    }
    return null;
  }

  /// The translation for a locale; English when there is none yet.
  static AppLanguage forLocale(Locale? locale) => forCode(locale?.languageCode) ?? en;

  /// The phone's language: the first one the person chose counts.
  static AppLanguage forDevice(List<Locale>? preferred) =>
      forLocale(preferred == null || preferred.isEmpty ? null : preferred.first);

  static List<Locale> get locales => [for (final language in values) language.locale];
}

/// ISO 639-1 codes written right to left.
const rtlLanguageCodes = {'ar', 'he', 'fa', 'ur', 'ps', 'sd', 'yi', 'dv', 'ug'};
