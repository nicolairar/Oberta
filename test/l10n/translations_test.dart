import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/l10n/app_language.dart';
import 'package:oberta/l10n/message_format.dart';
import 'package:oberta/l10n/messages_en.dart';
import 'package:oberta/l10n/messages_it.dart';
import 'package:oberta/narration/english_pack.dart';

/// The languages translated from English (everything but the two sources).
final translations = AppLanguage.values.where((l) => l != AppLanguage.en && l != AppLanguage.it);

void main() {
  for (final language in translations) {
    group('${language.nativeName} (${language.code})', () {
      test('every keyed message is there, and nothing else', () {
        final keys = language.messages.keys.toSet();
        expect(englishMessages.keys.toSet().difference(keys), isEmpty, reason: 'missing in ${language.code}');
        expect(keys.difference(englishMessages.keys.toSet()), isEmpty, reason: 'unknown keys in ${language.code}');
      });

      test('placeholders match: every name the English says, and only names the code passes', () {
        for (final MapEntry(:key, :value) in language.messages.entries) {
          expect(value.trim(), isNotEmpty, reason: key);
          final mine = messagePlaceholders(value);
          final english = messagePlaceholders(englishMessages[key]!);
          final passed = {...english, ...messagePlaceholders(italianMessages[key]!)};
          expect(mine, containsAll(english), reason: '$key: $value');
          expect(passed, containsAll(mine), reason: '$key uses a placeholder the code never passes: $value');
        }
      });

      test('the interface is translated: almost no text is left in English', () {
        final english = AppLanguage.en.strings.catalog;
        final mine = language.strings.catalog;
        expect(mine.keys, english.keys);
        final same = [for (final key in english.keys) if (mine[key] == english[key]) key];
        // Brand names, "+1 MIN", rank tiers and a few words shared with English.
        expect(same.length, lessThan(english.length * 0.08), reason: same.join(', '));
      });

      test('the keyed messages are translated too', () {
        final same = [for (final key in englishMessages.keys) if (language.messages[key] == englishMessages[key]) key];
        expect(same.length, lessThan(englishMessages.length * 0.05), reason: same.join(', '));
      });

      test('it has its own narrator script, read on screen', () {
        expect(identical(language.pack, englishPack), isFalse);
        expect(language.hasVoice, isFalse);
        expect(language.textDirection, isNotNull);
      });
    });
  }
}
