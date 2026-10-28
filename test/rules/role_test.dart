import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/rules/role.dart';

void main() {
  // I nomi, i motti e le spiegazioni stanno nei pacchetti di lingua: vedi
  // test/l10n/role_texts_test.dart.
  test('i ruoli sono ventuno', () {
    expect(Role.values, hasLength(21));
  });

  test('la famiglia è fatta di Picciotto, Padrino, Sarto e Compare', () {
    expect(
      Role.values.where((role) => role.team == Team.mafia),
      [Role.mafioso, Role.padrino, Role.sarto, Role.compare],
    );
  });

  test('in famiglia votano l\'agguato tutti, anche il Compare', () {
    expect(Role.values.where((role) => role.isKiller), [Role.mafioso, Role.padrino, Role.sarto, Role.compare]);
  });

  test('il Compare esiste solo online', () {
    expect(Role.compare.playableIn(PlayMode.online), isTrue);
    expect(Role.compare.playableIn(PlayMode.sharedPhone), isFalse);
    for (final role in Role.values) {
      if (role != Role.compare) expect(role.playableIn(PlayMode.sharedPhone), isTrue, reason: role.name);
    }
  });

  test('solo il Padrino e il Pregiudicato sembrano quello che non sono', () {
    expect(Role.padrino.apparentTeam, Team.citizens);
    expect(Role.pregiudicato.apparentTeam, Team.mafia);
    for (final role in Role.values) {
      if (role == Role.padrino || role == Role.pregiudicato) continue;
      // Il Sicario ha la faccia del mestiere: alle carte risulta della famiglia.
      if (role == Role.sicario) {
        expect(role.apparentTeam, Team.mafia);
        continue;
      }
      // Gli altri neutrali non sono della famiglia: alle carte risultano onesti.
      if (role.team == Team.neutral) {
        expect(role.apparentTeam, Team.citizens, reason: role.name);
        continue;
      }
      expect(role.apparentTeam, role.team, reason: role.name);
    }
  });
}
