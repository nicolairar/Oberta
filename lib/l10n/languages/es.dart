import '../../narration/english_pack.dart';
import '../../narration/narration_pack.dart';
import '../app_language.dart';
import '../online_strings.dart';
import '../shop_strings.dart';
import '../strings_en.dart';

// The whole of the Spanish translation: interface, keyed messages and the
// narrator's script. Spanish, neutral enough for Spain and Latin America ("ustedes", no "vosotros").
//
// Each class extends the English one, so anything not overridden here stays
// in English; test/l10n/translations_test.dart lists what is missing.

final class SpanishStrings extends EnglishStrings {
  const SpanishStrings();

  @override
  AppLanguage get language => AppLanguage.es;
  @override
  NarrationPack get pack => spanishPack;
  @override
  OnlineStrings get online => const SpanishOnlineStrings();
  @override
  ShopStrings get shop => const SpanishShopStrings();
  @override
  Map<String, String> get messages => spanishMessages;
}

final class SpanishOnlineStrings extends EnglishOnlineStrings {
  const SpanishOnlineStrings();
}

final class SpanishShopStrings extends EnglishShopStrings {
  const SpanishShopStrings();
}

/// The keyed messages (the keys and placeholders of lib/l10n/messages_en.dart).
const spanishMessages = <String, String>{};

/// The narrator's script, read on screen (no recorded voice yet).
const spanishPack = englishPack;
