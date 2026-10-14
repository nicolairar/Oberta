import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omerta/l10n/app_language.dart';
import 'package:omerta/l10n/app_strings.dart';
import 'package:omerta/narration/english_pack.dart';
import 'package:omerta/narration/italian_pack.dart';
import 'package:omerta/rules/role.dart';

import '../support/languages.dart';

/// Il titolo è il nome del gioco, uguale in tutte le lingue.
Map<String, String> uiOf(AppStrings strings) => {...strings.catalog}..remove('homeTitle');

void main() {
  group('la lingua del telefono', () {
    test('un telefono in italiano gioca in italiano', () {
      expect(AppLanguage.forDevice(const [Locale('it')]), AppLanguage.it);
      expect(AppLanguage.forDevice(const [Locale('it', 'IT')]), AppLanguage.it);
      expect(AppLanguage.forDevice(const [Locale('it', 'CH')]), AppLanguage.it);
    });

    test('tutti gli altri giocano in inglese', () {
      for (final locale in const [Locale('de'), Locale('en', 'US'), Locale('en', 'GB'), Locale('fr', 'FR')]) {
        expect(AppLanguage.forDevice([locale]), AppLanguage.en, reason: '$locale');
      }
      expect(AppLanguage.forDevice(const []), AppLanguage.en);
      expect(AppLanguage.forDevice(null), AppLanguage.en);
    });

    test('conta la prima lingua scelta sul telefono', () {
      expect(AppLanguage.forDevice(const [Locale('de'), Locale('it')]), AppLanguage.en);
      expect(AppLanguage.forDevice(const [Locale('it'), Locale('en')]), AppLanguage.it);
    });

    test('ogni lingua ha il suo nome, il suo copione e i suoi testi', () {
      expect(AppLanguage.it.nativeName, 'Italiano');
      expect(AppLanguage.en.nativeName, 'English');
      expect(AppLanguage.it.pack, same(italianPack));
      expect(AppLanguage.en.pack, same(englishPack));
      for (final language in AppLanguage.values) {
        expect(language.strings.language, language);
        expect(AppLanguage.forLocale(language.locale), language);
      }
    });
  });

  group('i testi dell\'interfaccia', () {
    test('ogni testo c\'è, in tutte e due le lingue, e nessuno è vuoto', () {
      final italian = AppLanguage.it.strings.catalog;
      final english = AppLanguage.en.strings.catalog;
      expect(english.keys, italian.keys);
      for (final language in AppLanguage.values) {
        for (final entry in language.strings.catalog.entries) {
          expect(entry.value.trim(), isNotEmpty, reason: '${language.name}.${entry.key}');
        }
      }
    });

    test('le due lingue non si copiano: quasi ogni testo cambia', () {
      final italian = uiOf(AppLanguage.it.strings);
      final english = uiOf(AppLanguage.en.strings);
      const same = {'plusMinute', 'lobbyDebugAdd', 'lobbyEmptyPlaceholder'};
      for (final key in italian.keys) {
        if (same.contains(key)) continue;
        expect(english[key], isNot(italian[key]), reason: key);
      }
    });

    test('nell\'inglese non resta niente di italiano', () {
      for (final entry in uiOf(AppLanguage.en.strings).entries) {
        expect(italianWords.hasMatch(entry.value.toLowerCase()), isFalse, reason: '${entry.key}: ${entry.value}');
      }
    });

    test('il filtro dell\'italiano funziona: sui testi italiani scatta', () {
      final italian = uiOf(AppLanguage.it.strings).values;
      final caught = italian.where((text) => italianWords.hasMatch(text.toLowerCase())).length;
      expect(caught, greaterThan(italian.length * 0.5));
    });

    test('in inglese nessun giocatore è "he" o "she", e nessuno chiude gli occhi', () {
      for (final entry in uiOf(AppLanguage.en.strings).entries) {
        expect(genderedWords.hasMatch(entry.value), isFalse, reason: '${entry.key}: ${entry.value}');
        expect(entry.value.toLowerCase(), isNot(contains('close your eyes')), reason: entry.key);
      }
    });

    test('il titolo resta OBERTÀ in tutte le lingue', () {
      for (final language in AppLanguage.values) {
        expect(language.strings.homeTitle, 'OBERTÀ');
      }
    });

    test('le didascalie del vicolo sono tante quante, e tutte diverse', () {
      final italian = AppLanguage.it.strings.homeCaptions;
      final english = AppLanguage.en.strings.homeCaptions;
      expect(english, hasLength(italian.length));
      expect(english.toSet(), hasLength(english.length));
    });

    test('i testi con un numero dicono il numero, al singolare e al plurale', () {
      final en = AppLanguage.en.strings;
      final it = AppLanguage.it.strings;
      expect(en.cardOf(2, 5), 'CARD 2 OF 5');
      expect(it.cardOf(2, 5), 'CARTA 2 DI 5');
      expect(en.needAtLeast(4), 'You need at least 4 players');
      expect(en.nightTitle(3), 'NIGHT 3');
      expect(en.dayTitle(3), 'DAY 3');
      expect(en.suspicion('Sara', 1, rightly: true), 'Sara, with 1 finger pointed in the dark. Rightly so.');
      expect(en.suspicion('Sara', 2, rightly: false), startsWith('Sara, with 2 fingers pointed in the dark. Wrongly'));
      expect(it.suspicion('Sara', 1, rightly: true), 'Sara, con 1 dito puntato nel buio. A ragione.');
      expect(it.suspicion('Sara', 2, rightly: false), 'Sara, con 2 dita puntate nel buio. A torto.');
      expect(en.readerReadsAloud('Sara'), 'SARA READS IT OUT LOUD');
      expect(en.wasRole(en.role(Role.medico).label), 'WAS THE DOC');
    });
  });

  group('AppStrings.of', () {
    testWidgets('senza una lingua installata si parla italiano', (tester) async {
      late AppStrings strings;
      await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
        strings = AppStrings.of(context);
        return const SizedBox();
      })));
      expect(strings, same(AppLanguage.it.strings));
    });

    testWidgets('con la lingua installata, parla quella', (tester) async {
      for (final language in AppLanguage.values) {
        late AppStrings strings;
        await tester.pumpWidget(appIn(language, Builder(builder: (context) {
          strings = AppStrings.of(context);
          return const SizedBox();
        })));
        expect(strings, same(language.strings));
      }
    });
  });
}
