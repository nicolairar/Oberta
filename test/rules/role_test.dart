import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/rules/role.dart';

void main() {
  // I nomi, i motti e le spiegazioni stanno nei pacchetti di lingua: vedi
  // test/l10n/role_texts_test.dart.
  test('i ruoli sono ventinove', () {
    expect(Role.values, hasLength(29));
  });

  test('la famiglia è fatta di Picciotto, Padrino, Sarto, Compare e Prostituta', () {
    expect(
      Role.values.where((role) => role.team == Team.mafia),
      [Role.mafioso, Role.padrino, Role.sarto, Role.compare, Role.prostituta],
    );
  });

  test('in famiglia votano l\'agguato tutti, anche il Compare, ma non la Prostituta', () {
    expect(Role.values.where((role) => role.isKiller), [Role.mafioso, Role.padrino, Role.sarto, Role.compare]);
  });

  test('solo il Compare esiste solo online: i ruoli nuovi anche sul telefono unico', () {
    const online = {Role.compare};
    for (final role in Role.values) {
      expect(role.playableIn(PlayMode.online), isTrue, reason: role.name);
      expect(role.playableIn(PlayMode.sharedPhone), !online.contains(role), reason: role.name);
    }
  });

  test('i livelli: punti da 0 a 5, il Pregiudicato pesa meno di zero', () {
    expect([for (final tier in RoleTier.values) tier.points], [0, 1, 2, 3, 5]);
    expect(Role.pregiudicato.points, -1);
    expect(Role.cittadino.points, 0);
    expect(Role.detective.rule.tier, RoleTier.l3);
    expect(Role.carceriere.rule.tier, RoleTier.l3);
    expect(Role.prostituta.rule.tier, RoleTier.l2);
    expect(Role.pacifista.rule.tier, RoleTier.l2);
    expect(Role.piromane.rule.tier, RoleTier.l4);
    expect(Role.sicario.rule.tier, RoleTier.l3);
    expect([for (final role in Role.values) if (role.isBlocker) role], [Role.prostituta, Role.carceriere]);
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
