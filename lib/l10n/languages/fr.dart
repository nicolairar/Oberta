import '../../narration/english_pack.dart';
import '../../narration/narration_pack.dart';
import '../app_language.dart';
import '../online_strings.dart';
import '../shop_strings.dart';
import '../strings_en.dart';

// The whole of the French translation: interface, keyed messages and the
// narrator's script. French.
//
// Each class extends the English one, so anything not overridden here stays
// in English; test/l10n/translations_test.dart lists what is missing.

final class FrenchStrings extends EnglishStrings {
  const FrenchStrings();

  @override
  AppLanguage get language => AppLanguage.fr;
  @override
  NarrationPack get pack => frenchPack;
  @override
  OnlineStrings get online => const FrenchOnlineStrings();
  @override
  ShopStrings get shop => const FrenchShopStrings();
  @override
  Map<String, String> get messages => frenchMessages;
}

final class FrenchOnlineStrings extends EnglishOnlineStrings {
  const FrenchOnlineStrings();
}

final class FrenchShopStrings extends EnglishShopStrings {
  const FrenchShopStrings();
}

/// The keyed messages (the keys and placeholders of lib/l10n/messages_en.dart).
const frenchMessages = <String, String>{};

/// The narrator's script, read on screen (no recorded voice yet).
const frenchPack = englishPack;
