import '../../narration/english_pack.dart';
import '../../narration/narration_pack.dart';
import '../app_language.dart';
import '../online_strings.dart';
import '../shop_strings.dart';
import '../strings_en.dart';

// The whole of the German translation: interface, keyed messages and the
// narrator's script. German.
//
// Each class extends the English one, so anything not overridden here stays
// in English; test/l10n/translations_test.dart lists what is missing.

final class GermanStrings extends EnglishStrings {
  const GermanStrings();

  @override
  AppLanguage get language => AppLanguage.de;
  @override
  NarrationPack get pack => germanPack;
  @override
  OnlineStrings get online => const GermanOnlineStrings();
  @override
  ShopStrings get shop => const GermanShopStrings();
  @override
  Map<String, String> get messages => germanMessages;
}

final class GermanOnlineStrings extends EnglishOnlineStrings {
  const GermanOnlineStrings();
}

final class GermanShopStrings extends EnglishShopStrings {
  const GermanShopStrings();
}

/// The keyed messages (the keys and placeholders of lib/l10n/messages_en.dart).
const germanMessages = <String, String>{};

/// The narrator's script, read on screen (no recorded voice yet).
const germanPack = englishPack;
