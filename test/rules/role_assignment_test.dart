import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:omerta/rules/player.dart';
import 'package:omerta/rules/role.dart';
import 'package:omerta/rules/role_assignment.dart';

List<Player> _players(int count) => [for (var i = 0; i < count; i++) Player(id: 'p$i', name: 'P$i')];

int _count(Iterable<Role> roles, Role role) => roles.where((r) => r == role).length;

Map<Role, int> _tally(Iterable<Role> roles) => {
      for (final role in Role.values)
        if (_count(roles, role) > 0) role: _count(roles, role),
    };

const _sizes = [3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16];

void main() {
  group('rolesForPlayerCount', () {
    test('rifiuta tavoli troppo piccoli', () {
      expect(() => rolesForPlayerCount(2), throwsArgumentError);
    });

    test('rifiuta tavoli troppo grandi', () {
      expect(maxRolePlayers, 16);
      expect(rolesForPlayerCount(maxRolePlayers), hasLength(maxRolePlayers));
      expect(() => rolesForPlayerCount(maxRolePlayers + 1), throwsArgumentError);
      expect(() => rolesForPlayerCount(20), throwsArgumentError);
    });

    test('produce sempre un mazzo grande quanto il tavolo', () {
      expect(_sizes.first, minRolePlayers);
      expect(_sizes.last, maxRolePlayers);
      for (final n in _sizes) {
        expect(rolesForPlayerCount(n), hasLength(n), reason: 'n=$n');
      }
    });

    test('la famiglia è sempre in minoranza, circa uno su quattro', () {
      for (final n in _sizes) {
        final family = rolesForPlayerCount(n).where((role) => role.team == Team.mafia).length;
        expect(family, max(1, n ~/ 4), reason: 'n=$n');
        expect(family * 2, lessThan(n), reason: 'n=$n');
      }
    });

    test('in famiglia c\'è sempre qualcuno che può uccidere', () {
      for (final n in _sizes) {
        expect(rolesForPlayerCount(n).where((role) => role.isKiller), isNotEmpty, reason: 'n=$n');
      }
    });

    test('a ogni tavolo resta almeno un Onesto', () {
      for (final n in _sizes) {
        expect(_count(rolesForPlayerCount(n), Role.cittadino), greaterThanOrEqualTo(1), reason: 'n=$n');
      }
    });

    test('fino a sette giocatori il mazzo è quello di sempre', () {
      const m = Role.mafioso, o = Role.cittadino;
      expect(rolesForPlayerCount(3), [m, o, o]);
      expect(rolesForPlayerCount(4), [m, Role.detective, o, o]);
      expect(rolesForPlayerCount(5), [m, Role.detective, Role.medico, o, o]);
      expect(rolesForPlayerCount(6), [m, Role.detective, Role.medico, o, o, o]);
      expect(rolesForPlayerCount(7), [m, Role.detective, Role.medico, Role.cecchino, o, o, o]);
    });

    test('i ruoli speciali entrano man mano che il tavolo cresce', () {
      // Da quanti giocatori in su si trova ciascun ruolo, uno per mazzo.
      const unlocks = {
        Role.detective: 4,
        Role.medico: 5,
        Role.cecchino: 7,
        Role.giornalista: 8,
        Role.becchino: 8,
        Role.padrino: 8,
        Role.reduce: 9,
        Role.guardaspalle: 10,
        Role.sarto: 10,
        Role.pregiudicato: 11,
      };
      for (final n in _sizes) {
        final deck = rolesForPlayerCount(n);
        unlocks.forEach((role, from) {
          expect(_count(deck, role), n >= from ? 1 : 0, reason: '${role.name} a $n giocatori');
        });
      }
    });

    test('i mazzi dei tavoli grandi, uno per uno', () {
      const specials = {
        Role.detective: 1,
        Role.medico: 1,
        Role.cecchino: 1,
        Role.giornalista: 1,
        Role.becchino: 1,
      };
      expect(_tally(rolesForPlayerCount(8)), {Role.padrino: 1, Role.mafioso: 1, ...specials, Role.cittadino: 1});
      expect(_tally(rolesForPlayerCount(9)), {
        Role.padrino: 1,
        Role.mafioso: 1,
        ...specials,
        Role.reduce: 1,
        Role.cittadino: 1,
      });
      expect(_tally(rolesForPlayerCount(10)), {
        Role.padrino: 1,
        Role.sarto: 1,
        ...specials,
        Role.reduce: 1,
        Role.guardaspalle: 1,
        Role.cittadino: 1,
      });

      const everyone = {...specials, Role.reduce: 1, Role.guardaspalle: 1, Role.pregiudicato: 1};
      const picciotti = {11: 0, 12: 1, 13: 1, 14: 1, 15: 1, 16: 2};
      const onesti = {11: 1, 12: 1, 13: 2, 14: 3, 15: 4, 16: 4};
      for (final n in picciotti.keys) {
        expect(
          _tally(rolesForPlayerCount(n)),
          {
            Role.padrino: 1,
            Role.sarto: 1,
            if (picciotti[n]! > 0) Role.mafioso: picciotti[n]!,
            ...everyone,
            Role.cittadino: onesti[n]!,
          },
          reason: 'n=$n',
        );
      }
    });

    test('dagli undici in su tutti e dodici i ruoli sono al tavolo, o quasi', () {
      expect(rolesForPlayerCount(11).toSet(), Role.values.toSet().difference({Role.mafioso}));
      for (var n = 12; n <= maxRolePlayers; n++) {
        expect(rolesForPlayerCount(n).toSet(), Role.values.toSet(), reason: 'n=$n');
      }
    });
  });

  group('assignRoles', () {
    test('ogni giocatore riceve un ruolo e il mazzo resta quello previsto', () {
      for (final n in _sizes) {
        final players = _players(n);
        final roles = assignRoles(players, Random(7));
        expect(roles.keys, players);
        List<Role> sorted(Iterable<Role> r) => r.toList()..sort((a, b) => a.index.compareTo(b.index));
        expect(sorted(roles.values), sorted(rolesForPlayerCount(n)), reason: 'n=$n');
      }
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

    test('non si distribuisce a un tavolo fuori misura', () {
      expect(() => assignRoles(_players(2)), throwsArgumentError);
      expect(() => assignRoles(_players(17)), throwsArgumentError);
    });
  });
}
