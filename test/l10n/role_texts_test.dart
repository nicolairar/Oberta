import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/l10n/app_language.dart';
import 'package:oberta/narration/english_pack.dart';
import 'package:oberta/narration/italian_pack.dart';
import 'package:oberta/rules/role.dart';

import '../support/languages.dart';

void main() {
  test('ogni lingua presenta tutti e dodici i ruoli', () {
    for (final language in AppLanguage.values) {
      expect(language.pack.roles.keys.toSet(), Role.values.toSet(), reason: language.name);
      final labels = {for (final role in Role.values) language.pack.role(role).label};
      expect(labels, hasLength(Role.values.length), reason: '${language.name}: nomi tutti diversi');
    }
  });

  test('i nomi di scena: "Il Dottore" in italiano, "The Doc" in inglese', () {
    for (final role in Role.values) {
      expect(italianPack.role(role).label, matches(RegExp(r"^(Il |Lo |L')\p{Lu}", unicode: true)), reason: role.name);
      expect(englishPack.role(role).label, matches(RegExp(r'^The \p{Lu}', unicode: true)), reason: role.name);
    }
    expect(englishPack.role(Role.medico).label, 'The Doc');
    expect(englishPack.role(Role.cittadino).label, 'The Honest One');
    expect(englishPack.role(Role.pregiudicato).label, 'The Ex-Con');
  });

  test('ogni motto tra virgolette della sua lingua, e una spiegazione semplice', () {
    const quotes = {AppLanguage.it: ('«', '»'), AppLanguage.en: ('“', '”')};
    for (final language in AppLanguage.values) {
      final (open, close) = quotes[language]!;
      for (final role in Role.values) {
        final text = language.pack.role(role);
        final reason = '${language.name}.${role.name}';
        expect(text.motto, startsWith(open), reason: reason);
        expect(text.motto, endsWith(close), reason: reason);
        expect(text.motto.length, lessThanOrEqualTo(48), reason: '$reason: sulla carta sta in due righe');
        // Poche frasi semplici: chiare, non un romanzo.
        expect(text.description, endsWith('.'), reason: reason);
        expect(text.description.length, inInclusiveRange(40, 170), reason: '$reason: ${text.description}');
        expect(RegExp(r'[.!?](\s|$)').allMatches(text.description).length, lessThanOrEqualTo(3), reason: reason);
      }
    }
  });

  test('i ruoli in inglese sono tutti in inglese, e nessuno ha un genere', () {
    for (final role in Role.values) {
      final text = englishPack.role(role);
      for (final line in [text.label, text.motto, text.description]) {
        expect(italianWords.hasMatch(line.toLowerCase()), isFalse, reason: '${role.name}: $line');
        expect(genderedWords.hasMatch(line), isFalse, reason: '${role.name}: $line');
      }
    }
  });

  test('le fazioni inglesi si chiamano "the Family" e "the town"', () {
    final all = [
      for (final role in Role.values) ...[englishPack.role(role).motto, englishPack.role(role).description],
    ].join(' ');
    expect(all, isNot(contains('the family')));
    expect(all, isNot(contains('mafia')));
    expect(all.toLowerCase(), isNot(contains('doctor')));
    expect(englishPack.role(Role.mafioso).description, contains('the Family'));
    expect(englishPack.role(Role.pregiudicato).description, contains('the town'));
  });
}
