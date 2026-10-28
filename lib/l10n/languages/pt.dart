import '../../narration/english_pack.dart';
import '../../narration/narration_pack.dart';
import '../app_language.dart';
import '../online_strings.dart';
import '../shop_strings.dart';
import '../strings_en.dart';

// The whole of the Portuguese translation: interface, keyed messages and the
// narrator's script. Brazilian Portuguese ("você").
//
// Each class extends the English one, so anything not overridden here stays
// in English; test/l10n/translations_test.dart lists what is missing.

final class PortugueseStrings extends EnglishStrings {
  const PortugueseStrings();

  @override
  AppLanguage get language => AppLanguage.pt;
  @override
  NarrationPack get pack => portuguesePack;
  @override
  OnlineStrings get online => const PortugueseOnlineStrings();
  @override
  ShopStrings get shop => const PortugueseShopStrings();
  @override
  Map<String, String> get messages => portugueseMessages;
}

final class PortugueseOnlineStrings extends EnglishOnlineStrings {
  const PortugueseOnlineStrings();
}

final class PortugueseShopStrings extends EnglishShopStrings {
  const PortugueseShopStrings();
}

/// The keyed messages (the keys and placeholders of lib/l10n/messages_en.dart).
const portugueseMessages = <String, String>{};

/// The narrator's script, read on screen (no recorded voice yet).
const portuguesePack = englishPack;
