import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/l10n/app_language.dart';
import 'package:oberta/rules/role.dart';
import 'package:oberta/rules/role_catalog.dart';

void main() {
  test('il catalogo ha ogni ruolo una volta, con le sue regole e i testi in ogni lingua', () {
    expect([for (final entry in roleCatalog) entry.role], Role.values);
    for (final entry in roleCatalog) {
      expect(entry.id, entry.role.name);
      expect(entry.team, entry.role.team);
      expect(entry.points, entry.role.points);
      expect(entry.minPlayers, entry.role.rule.minPlayers);
      for (final language in AppLanguage.values) {
        expect(language.pack.role(entry.role).label, isNotEmpty);
      }
    }
    expect(rolesOfTeam(Team.mafia).map((e) => e.role), contains(Role.prostituta));
    expect(roleCatalog.where((e) => e.hostile).map((e) => e.role), containsAll([Role.piromane, Role.sicario]));
  });
}
