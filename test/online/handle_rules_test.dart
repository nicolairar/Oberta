import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/online/handle_rules.dart';
import 'package:oberta/online/reserved_words.dart';

void main() {
  group('la forma', () {
    test('i nomi buoni passano', () {
      for (final good in ['anna', 'anna.rossi', 'anna_r_92', '9anna', 'a___b', 'abcdefghijkl', 'a.b_c', 'abc']) {
        expect(HandleRules.check(good), isNull, reason: good);
      }
    });

    test('ogni regola ha il suo problema', () {
      final cases = {
        'ab': HandleProblem.tooShort,
        '': HandleProblem.tooShort,
        'abcdefghijklm': HandleProblem.tooLong,
        'Anna': HandleProblem.characters,
        'an-na': HandleProblem.characters,
        'an na': HandleProblem.characters,
        'ànna': HandleProblem.characters,
        '.anna': HandleProblem.start,
        '_anna': HandleProblem.start,
        'anna.': HandleProblem.endsWithDot,
        'an..na': HandleProblem.doubleDot,
        'a_._.b': HandleProblem.tooManySymbols,
        'a____b': HandleProblem.tooManySymbols,
      };
      for (final MapEntry(key: handle, value: problem) in cases.entries) {
        expect(HandleRules.check(handle), problem, reason: handle);
      }
    });

    test('si salva in minuscolo, senza spazi intorno', () {
      expect(HandleRules.normalize('  Anna.R '), 'anna.r');
    });
  });

  group('i nomi dei bot', () {
    test('sono solo dei bot', () {
      for (final bot in ['bot', 'bot.alfa', 'bot_1', 'bot7', 'b0t.x', 'b0t']) {
        expect(HandleRules.check(bot), HandleProblem.botName, reason: bot);
      }
      for (final human in ['bottega', 'botticelli', 'robot', 'abbot']) {
        expect(HandleRules.check(human), isNull, reason: human);
      }
    });

    test('i nomi che si danno ai bot hanno la forma giusta', () {
      for (final word in ['alfa', 'bravo', 'charlie', 'november', 'foxtrot']) {
        final handle = HandleRules.botHandle(word);
        expect(handle.length, lessThanOrEqualTo(HandleRules.maxLength), reason: handle);
        expect(HandleRules.check(handle), HandleProblem.botName, reason: 'nessun umano può prendere $handle');
      }
    });
  });

  group('la moderazione', () {
    test('le forme di controllo disfano leetspeak, segni e lettere ripetute', () {
      final forms = HandleRules.moderationForms('h1tl3r_88');
      expect(forms.map((f) => f.plain), containsAll(['hitler', 'hltler']));
      expect(HandleRules.moderationForms('f.u.u.u.c.k').single.collapsed, 'fuck');
      expect(HandleRules.moderationForms('5tr0nz0').single.plain, 'stronzo');
      expect(HandleRules.moderationForms('p4zz0').single.plain, 'pazzo');
      expect(HandleRules.moderationForms('m7t').single.plain, 'mtt');
    });

    test('offese, odio e finto staff, in italiano e in inglese', () {
      for (final bad in [
        'fuck', 'f.u.c.k', 'fuuuck', 'fuck_off', 'sh1t', 'b1tch',
        'h1tl3r', 'heil', 'siegheil', 'n4zi', 'kkk',
        'nigger', 'n1gga', 'frocio', 'fr0c10', 'ricchione', 'faggot',
        'stronzo', 'str0nz0_92', 'cazzo', 'c4zz0', 'puttana', 'vaffanculo',
        'porcodio', 'dio.cane', 'ritardato', 'retard',
        'uccidi.ebrei', 'killthejews', 'kys', 'ucciditi',
        'admin', 'moderatore', 'narratore', 'oberta', 'omerta', 'staff.it', 'supporto',
      ]) {
        expect(HandleRules.check(bad), HandleProblem.notAllowed, reason: bad);
      }
    });

    test('i nomi innocenti che somigliano non si toccano', () {
      for (final good in [
        'roberta', 'mood', 'pedone', 'negroni', 'nazionale', 'penisola', 'therapist', 'classico',
        'grape', 'peacock', 'cocktail', 'finocchiona', 'condor', 'rotella', 'sussex',
      ]) {
        expect(HandleRules.check(good), isNull, reason: good);
      }
    });

    test('la lista dell\'app è la stessa del database', () {
      final sql = File('supabase/migrations/20261017140000_instagram_handles.sql').readAsStringSync();
      final rows = RegExp(r"\('([a-z]+)', '(it|en|any)', '(contains|exact)'\)").allMatches(sql);
      final database = {for (final row in rows) '${row[1]}|${row[2]}|${row[3]}'};
      final app = {for (final word in reservedWords) '${word.word}|${word.lang}|${word.match.name}'};
      expect(database, app);
      expect(app, hasLength(reservedWords.length), reason: 'niente doppioni');
    });
  });
}
