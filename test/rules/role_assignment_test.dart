import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:omerta/rules/player.dart';
import 'package:omerta/rules/role.dart';
import 'package:omerta/rules/role_assignment.dart';

List<Player> _players(int count) => [for (var i = 0; i < count; i++) Player(id: 'p$i', name: 'P$i')];

int _count(Iterable<Role> roles, Role role) => roles.where((r) => r == role).length;

void main() {
  group('rolesForPlayerCount', () {
    test('rifiuta tavoli troppo piccoli', () {
      expect(() => rolesForPlayerCount(2), throwsArgumentError);
    });

    test('produce sempre un mazzo grande quanto il tavolo', () {
      for (var n = minRolePlayers; n <= 20; n++) {
        expect(rolesForPlayerCount(n), hasLength(n), reason: 'n=$n');
      }
    });

    test('i mafiosi sono sempre in minoranza e almeno uno', () {
      for (var n = minRolePlayers; n <= 20; n++) {
        final mafiosi = _count(rolesForPlayerCount(n), Role.mafioso);
        expect(mafiosi, greaterThanOrEqualTo(1), reason: 'n=$n');
        expect(mafiosi * 2, lessThan(n), reason: 'n=$n');
      }
    });

    test('i ruoli speciali entrano man mano che il tavolo cresce', () {
      expect(rolesForPlayerCount(3), [Role.mafioso, Role.cittadino, Role.cittadino]);
      expect(_count(rolesForPlayerCount(4), Role.detective), 1);
      expect(_count(rolesForPlayerCount(4), Role.medico), 0);
      expect(_count(rolesForPlayerCount(5), Role.medico), 1);
      expect(_count(rolesForPlayerCount(7), Role.cecchino), 1);
      expect(_count(rolesForPlayerCount(8), Role.giornalista), 1);
      expect(_count(rolesForPlayerCount(8), Role.mafioso), 2);
    });

    test('nessun ruolo speciale compare due volte', () {
      final deck = rolesForPlayerCount(20);
      for (final role in [Role.detective, Role.medico, Role.cecchino, Role.giornalista]) {
        expect(_count(deck, role), 1, reason: role.name);
      }
    });
  });

  group('assignRoles', () {
    test('ogni giocatore riceve un ruolo e il mazzo resta quello previsto', () {
      final players = _players(9);
      final roles = assignRoles(players, Random(7));
      expect(roles.keys, players);
      List<Role> sorted(Iterable<Role> r) => r.toList()..sort((a, b) => a.index.compareTo(b.index));
      expect(sorted(roles.values), sorted(rolesForPlayerCount(9)));
    });

    test('stesso seme, stessa distribuzione', () {
      final players = _players(8);
      expect(assignRoles(players, Random(3)), assignRoles(players, Random(3)));
    });

    test('il mafioso non capita sempre allo stesso posto', () {
      final players = _players(6);
      final seats = {
        for (var seed = 0; seed < 40; seed++)
          assignRoles(players, Random(seed)).entries.firstWhere((e) => e.value == Role.mafioso).key,
      };
      expect(seats.length, greaterThan(3));
    });
  });
}
