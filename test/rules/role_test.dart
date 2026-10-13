import 'package:flutter_test/flutter_test.dart';
import 'package:omerta/rules/role.dart';

void main() {
  test('i ruoli sono dodici, ognuno col suo nome di scena', () {
    expect(Role.values, hasLength(12));
    final labels = {for (final role in Role.values) role.label};
    expect(labels, hasLength(Role.values.length));
    for (final label in labels) {
      expect(label, matches(RegExp(r"^(Il |L')\p{Lu}", unicode: true)), reason: label);
    }
  });

  test('ogni ruolo ha un motto tra caporali e una spiegazione breve', () {
    for (final role in Role.values) {
      expect(role.motto, startsWith('«'), reason: role.name);
      expect(role.motto, endsWith('»'), reason: role.name);
      expect(role.motto.length, lessThanOrEqualTo(48), reason: 'sulla carta sta in due righe');
      expect(role.description, endsWith('.'), reason: role.name);
      expect(role.description.length, inInclusiveRange(40, 100), reason: role.name);
      expect(RegExp(r'[.!?](\s|$)').allMatches(role.description).length, lessThanOrEqualTo(3),
          reason: '${role.name}: una frase o due, al massimo tre brevi');
    }
  });

  test('la famiglia è fatta di Picciotto, Padrino e Sarto', () {
    expect(
      Role.values.where((role) => role.team == Team.mafia),
      [Role.mafioso, Role.padrino, Role.sarto],
    );
  });

  test('in famiglia sparano il Picciotto e il Padrino, non il Sarto', () {
    expect(Role.values.where((role) => role.isKiller), [Role.mafioso, Role.padrino]);
  });

  test('solo il Padrino e il Pregiudicato sembrano quello che non sono', () {
    expect(Role.padrino.apparentTeam, Team.citizens);
    expect(Role.pregiudicato.apparentTeam, Team.mafia);
    for (final role in Role.values) {
      if (role == Role.padrino || role == Role.pregiudicato) continue;
      expect(role.apparentTeam, role.team, reason: role.name);
    }
  });
}
