import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/rules/player.dart';
import 'package:oberta/rules/role.dart';
import 'package:oberta/rules/role_assignment.dart';

List<Player> _players(int count) => [for (var i = 0; i < count; i++) Player(id: 'p$i', name: 'P$i')];

int _count(Iterable<Role> roles, Role role) => roles.where((r) => r == role).length;


const _sizes = [3, 4, 5, 6, 7, 8, 9, 10, 11, 12];

void main() {
  group('rolesForPlayerCount', () {
    test('rifiuta tavoli troppo piccoli', () {
      expect(() => rolesForPlayerCount(2), throwsArgumentError);
    });

    test('rifiuta tavoli troppo grandi', () {
      expect(maxRolePlayers, 12);
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

    test('la famiglia è proporzionale: 1 fino a 6, 2 fino a 10, 3 a 11 e 12', () {
      const expected = {3: 1, 4: 1, 6: 1, 7: 2, 10: 2, 11: 3, 12: 3};
      expected.forEach((n, family) {
        for (var seed = 0; seed < 20; seed++) {
          final deck = rolesForPlayerCount(n, random: Random(seed));
          expect(deck.where((role) => role.team == Team.mafia).length, family, reason: 'n=$n');
        }
      });
    });

    test('lo stesso seme dà lo stesso mazzo', () {
      for (final n in _sizes) {
        expect(rolesForPlayerCount(n, random: Random(5)), rolesForPlayerCount(n, random: Random(5)));
      }
    });

    // Le regole di composizione, controllate su tanti mazzi per ogni tavolo
    // e in tutte e due le modalità.
    for (final mode in PlayMode.values) {
      test('i vincoli tengono sempre (${mode.name})', () {
        final seen = <int, Set<Role>>{};
        for (final n in _sizes) {
          for (var seed = 0; seed < 300; seed++) {
            final deck = rolesForPlayerCount(n, random: Random(seed * 31 + n), mode: mode);
            final why = 'n=$n seed=$seed $deck';
            seen.putIfAbsent(n, () => {}).addAll(deck);
            expect(deck, hasLength(n), reason: why);
            int category(RoleCategory c) => deck.where((role) => role.rule.category == c).length;

            // La famiglia.
            final family = deck.where((role) => role.team == Team.mafia).toList();
            expect(family.length * 2, lessThan(n), reason: why);
            expect(family.any((role) => role.isKiller), isTrue, reason: why);
            expect(category(RoleCategory.familyPower), lessThanOrEqualTo(n < 11 ? 1 : 2), reason: why);
            expect(
              family.toSet().containsAll({Role.padrino, Role.sarto, Role.compare}),
              isFalse,
              reason: why,
            );

            // Ogni ruolo: soglia, copie, modalità.
            for (final role in deck.toSet()) {
              expect(n, greaterThanOrEqualTo(role.rule.minPlayers), reason: '${role.name} $why');
              expect(role.playableIn(mode), isTrue, reason: '${role.name} $why');
              final copies = role.rule.maxCopies;
              if (copies != null) expect(_count(deck, role), lessThanOrEqualTo(copies), reason: why);
            }
            if (n < 10) expect(deck, isNot(contains(Role.padrino)), reason: why);

            // Le categorie dei cittadini.
            final pairs = n < 12 ? 1 : 2;
            expect(category(RoleCategory.investigator), lessThanOrEqualTo(pairs), reason: why);
            expect(category(RoleCategory.protector), lessThanOrEqualTo(pairs), reason: why);
            expect(category(RoleCategory.extraKill), lessThanOrEqualTo(1), reason: why);

            // Gli speciali al massimo due terzi dei cittadini: gli Onesti restano almeno un terzo.
            final citizens = n - family.length;
            final onesti = _count(deck, Role.cittadino);
            expect(onesti * 3, greaterThanOrEqualTo(citizens), reason: why);
            expect(citizens - onesti, lessThanOrEqualTo((citizens * 2) ~/ 3), reason: why);
          }
        }
        // La pesca è davvero a caso: ai tavoli grandi escono ruoli diversi.
        expect(seen[12]!.length, greaterThan(8));
        if (mode == PlayMode.online) {
          expect(seen[12], contains(Role.compare));
        } else {
          for (final roles in seen.values) {
            expect(roles, isNot(contains(Role.compare)));
          }
        }
        expect(seen[12], containsAll([Role.padrino, Role.sarto]));
      });
    }

    test('un investigatore e un protettore escono per primi, appena possibile', () {
      for (var seed = 0; seed < 50; seed++) {
        final deck = rolesForPlayerCount(4, random: Random(seed));
        expect(deck, contains(Role.detective));
        final six = rolesForPlayerCount(6, random: Random(seed));
        expect(six, containsAll([Role.detective, Role.medico]));
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
        expect(sorted(roles.values), sorted(rolesForPlayerCount(n, random: Random(7))), reason: 'n=$n');
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
