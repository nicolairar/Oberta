import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/l10n/app_language.dart';
import 'package:oberta/l10n/message_format.dart';
import 'package:oberta/l10n/messages_en.dart';
import 'package:oberta/l10n/messages_it.dart';
import 'package:oberta/l10n/table_strings.dart';
import 'package:oberta/l10n/player_gender.dart';

void main() {
  group('formatMessage', () {
    test('fills names and leaves unknown ones visible', () {
      expect(formatMessage('Hi {name}, {name}!', {'name': 'Sara'}), 'Hi Sara, Sara!');
      expect(formatMessage('Hi {name}', {}), 'Hi {name}');
      expect(formatMessage("L'account di {who}", {'who': 'Vito'}), "L'account di Vito");
    });

    test('plural forms follow the language', () {
      const t = '{n, plural, one{# game} other{# games}}';
      expect(formatMessage(t, {'n': 1}), '1 game');
      expect(formatMessage(t, {'n': 0}), '0 games');
      expect(formatMessage(t, {'n': 5}), '5 games');
      // French counts 0 as singular, Polish has a "few".
      expect(formatMessage('{n, plural, one{# partie} other{# parties}}', {'n': 0}, locale: 'fr'), '0 partie');
      const pl = '{n, plural, one{# gra} few{# gry} many{# gier} other{# gry}}';
      expect(formatMessage(pl, {'n': 3}, locale: 'pl'), '3 gry');
      expect(formatMessage(pl, {'n': 5}, locale: 'pl'), '5 gier');
      expect(formatMessage('{n, plural, =0{none} other{#}}', {'n': 0}), 'none');
    });

    test('select picks by value, with other as the fallback, and nests', () {
      const t = '{gender, select, feminine{{name} è stata linciata.} other{{name} è stato linciato.}}';
      expect(formatMessage(t, {'gender': 'feminine', 'name': 'Dora'}), 'Dora è stata linciata.');
      expect(formatMessage(t, {'gender': 'unknown', 'name': 'Vito'}), 'Vito è stato linciato.');
    });

    test('placeholders are found inside plural and select forms', () {
      expect(messagePlaceholders('{gender, select, feminine{{name} è} other{{name} {by}}}'), {'gender', 'name', 'by'});
      expect(messagePlaceholders('{n, plural, one{# x} other{# y}} {who}'), {'n', 'who'});
    });
  });

  group('the keyed messages', () {
    test('Italian and English have the same keys', () {
      expect(italianMessages.keys.toSet(), englishMessages.keys.toSet());
    });

    test('no message is empty, and every name the English says the Italian says too', () {
      for (final key in englishMessages.keys) {
        expect(englishMessages[key]!.trim(), isNotEmpty, reason: key);
        expect(italianMessages[key]!.trim(), isNotEmpty, reason: key);
        expect(messagePlaceholders(italianMessages[key]!), containsAll(messagePlaceholders(englishMessages[key]!)), reason: key);
      }
    });

    test('a key nobody translated falls back to English, then to itself', () {
      expect(AppLanguage.it.message('no.such.key'), 'no.such.key');
      expect(AppLanguage.es.message('table.cancel'), isNotEmpty);
    });

    test('Italian agrees with the player, English never needs to', () {
      final it = TableStrings(AppLanguage.it);
      final en = TableStrings(AppLanguage.en);
      expect(it.lynchedLine('Dora', 'Il Dottore', gender: Gender.feminine), 'Dora è stata linciata. Era il Dottore.');
      expect(it.lynchedLine('Vito', null, gender: Gender.masculine), 'Vito è stato linciato.');
      expect(it.lynchedLine('Sam', null), 'La piazza ha linciato Sam.');
      expect(en.lynchedLine('Sam', 'Doctor'), 'Sam was lynched. They were the Doctor.');
      expect(it.abstainedVotes(1), '1 astenuto');
      expect(it.abstainedVotes(3), '3 astenuti');
    });
  });
}
