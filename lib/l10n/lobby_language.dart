import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../narration/narration_pack.dart';
import 'app_language.dart';
import 'app_strings.dart';

/// The language a room or a ranked queue is played in: any ISO 639-1 code,
/// translated or not. A Japanese phone sees the interface in English (until
/// Japanese is translated) but still finds the Japanese tables.
///
/// The texts at a table follow [app], the closest translation.
@immutable
class LobbyLanguage {
  /// The ISO 639-1 code, lower case.
  final String code;

  const LobbyLanguage._(this.code);

  static const it = LobbyLanguage._('it');
  static const en = LobbyLanguage._('en');

  /// Everyone can sit at the Italian and English tables.
  static const shared = [it, en];

  factory LobbyLanguage.of(AppLanguage language) => LobbyLanguage._(language.code);

  /// A language from a code; null for anything that is not ISO 639-1.
  static LobbyLanguage? tryParse(String? code) {
    if (code == null) return null;
    final lower = code.trim().toLowerCase();
    return isoLanguageCodes.contains(lower) ? LobbyLanguage._(lower) : null;
  }

  /// As [tryParse], with Italian for anything unknown (the old default).
  factory LobbyLanguage.parse(Object? code) => tryParse(code is String ? code : null) ?? it;

  /// The lobby of a phone: its first language, translated or not.
  static LobbyLanguage forDevice(List<Locale>? preferred) {
    if (preferred != null) {
      for (final locale in preferred) {
        final language = tryParse(locale.languageCode);
        if (language != null) return language;
      }
    }
    return en;
  }

  /// The lobbies a player is offered: Italian and English for everyone, and
  /// [mine] too when it is a third language. [mine] comes first.
  static List<LobbyLanguage> offered(LobbyLanguage mine) => [mine, ...shared.where((l) => l != mine)];

  /// The translation that plays this lobby: its own, or English.
  AppLanguage get app => AppLanguage.forCode(code) ?? AppLanguage.en;

  AppStrings get strings => app.strings;
  NarrationPack get pack => app.pack;
  Locale get locale => app.code == code ? app.locale : Locale(code);

  /// The same as [code]: what the server stores.
  String get name => code;

  /// The language's own name, for the flag's label.
  String get nativeName => app.code == code ? app.nativeName : (isoNativeNames[code] ?? code.toUpperCase());

  TextDirection get textDirection => rtlLanguageCodes.contains(code) ? TextDirection.rtl : TextDirection.ltr;

  @override
  bool operator ==(Object other) => other is LobbyLanguage && other.code == code;

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => 'LobbyLanguage($code)';
}

/// Every ISO 639-1 code: the server checks the same list
/// (internal.is_lobby_language).
const isoLanguageCodes = {
  'aa', 'ab', 'ae', 'af', 'ak', 'am', 'an', 'ar', 'as', 'av', 'ay', 'az', 'ba', 'be', 'bg', 'bi', 'bm', 'bn', 'bo', 'br', //
  'bs', 'ca', 'ce', 'ch', 'co', 'cr', 'cs', 'cu', 'cv', 'cy', 'da', 'de', 'dv', 'dz', 'ee', 'el', 'en', 'eo', 'es', 'et', //
  'eu', 'fa', 'ff', 'fi', 'fj', 'fo', 'fr', 'fy', 'ga', 'gd', 'gl', 'gn', 'gu', 'gv', 'ha', 'he', 'hi', 'ho', 'hr', 'ht', //
  'hu', 'hy', 'hz', 'ia', 'id', 'ie', 'ig', 'ii', 'ik', 'io', 'is', 'it', 'iu', 'ja', 'jv', 'ka', 'kg', 'ki', 'kj', 'kk', //
  'kl', 'km', 'kn', 'ko', 'kr', 'ks', 'ku', 'kv', 'kw', 'ky', 'la', 'lb', 'lg', 'li', 'ln', 'lo', 'lt', 'lu', 'lv', 'mg', //
  'mh', 'mi', 'mk', 'ml', 'mn', 'mr', 'ms', 'mt', 'my', 'na', 'nb', 'nd', 'ne', 'ng', 'nl', 'nn', 'no', 'nr', 'nv', 'ny', //
  'oc', 'oj', 'om', 'or', 'os', 'pa', 'pi', 'pl', 'ps', 'pt', 'qu', 'rm', 'rn', 'ro', 'ru', 'rw', 'sa', 'sc', 'sd', 'se', //
  'sg', 'si', 'sk', 'sl', 'sm', 'sn', 'so', 'sq', 'sr', 'ss', 'st', 'su', 'sv', 'sw', 'ta', 'te', 'tg', 'th', 'ti', 'tk', //
  'tl', 'tn', 'to', 'tr', 'ts', 'tt', 'tw', 'ty', 'ug', 'uk', 'ur', 'uz', 've', 'vi', 'vo', 'wa', 'wo', 'xh', 'yi', 'yo', //
  'za', 'zh', 'zu',
};

/// The native names of the most spoken languages without a translation yet.
const isoNativeNames = {
  'ar': 'العربية',
  'bg': 'Български',
  'bn': 'বাংলা',
  'ca': 'Català',
  'cs': 'Čeština',
  'da': 'Dansk',
  'el': 'Ελληνικά',
  'et': 'Eesti',
  'fa': 'فارسی',
  'fi': 'Suomi',
  'he': 'עברית',
  'hi': 'हिन्दी',
  'hr': 'Hrvatski',
  'hu': 'Magyar',
  'id': 'Bahasa Indonesia',
  'ja': '日本語',
  'ko': '한국어',
  'lt': 'Lietuvių',
  'lv': 'Latviešu',
  'ms': 'Bahasa Melayu',
  'nb': 'Norsk bokmål',
  'nl': 'Nederlands',
  'no': 'Norsk',
  'pl': 'Polski',
  'ro': 'Română',
  'ru': 'Русский',
  'sk': 'Slovenčina',
  'sl': 'Slovenščina',
  'sr': 'Српски',
  'sv': 'Svenska',
  'sw': 'Kiswahili',
  'ta': 'தமிழ்',
  'th': 'ไทย',
  'tl': 'Tagalog',
  'tr': 'Türkçe',
  'uk': 'Українська',
  'ur': 'اردو',
  'vi': 'Tiếng Việt',
  'zh': '中文',
};
