import 'package:flutter_test/flutter_test.dart';
import 'package:omerta/rules/role.dart';

void main() {
  // I nomi, i motti e le spiegazioni stanno nei pacchetti di lingua: vedi
  // test/l10n/role_texts_test.dart.
  test('i ruoli sono dodici', () {
    expect(Role.values, hasLength(12));
  });

  test('la famiglia è fatta di Picciotto, Padrino e Sarto', () {
    expect(Role.values.where((role) => role.team == Team.mafia), [Role.mafioso, Role.padrino, Role.sarto]);
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
