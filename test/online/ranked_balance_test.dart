import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/online/game/deck_balance.dart';
import 'package:oberta/online/game/role_builds.dart';
import 'package:oberta/rules/role.dart';
import 'package:oberta/rules/role_assignment.dart';

// Il mazzo della classificata (docs/ruoli.md, 2.6): sempre 12 giocatori,
// a posti fissi. La simulazione lunga (20000+ partite, con gli intervalli di
// confidenza) la stampa tool/balance/ranked.dart; qui una corta a seme
// fisso tiene la classificata nella fascia: un ruolo nuovo che la sposta
// rompe questo test.

void main() {
  test('la classificata resta nella fascia: Città 45-55%, Famiglia 40-50%, nessun ruolo sopra il 60%', () {
    const games = 2000;
    final report = simulateRanked(games, seed: 2026);
    final reason = '${report.endings}';
    expect(report.share('citizens'), inInclusiveRange(0.45, 0.55), reason: reason);
    expect(report.share('mafia'), inInclusiveRange(0.40, 0.50), reason: reason);
    expect(report.share('none'), lessThan(0.01), reason: 'le partite finiscono');
    for (final role in report.dealt.keys) {
      final rate = report.roleWinRate(role);
      expect(rate, lessThanOrEqualTo(0.60), reason: '${role.name} vince il ${(rate * 100).round()}% quando esce');
      // Un neutrale vince da solo al massimo il 15% delle partite.
      if (role.team == Team.neutral) {
        expect((report.won[role] ?? 0) / games, lessThanOrEqualTo(0.15), reason: role.name);
      }
    }
  });

  test('il mazzo della classificata: 12 carte a posti fissi', () {
    final random = Random(7);
    final seen = <Role>{};
    for (var i = 0; i < 300; i++) {
      final deck = rankedRoles(random: random);
      seen.addAll(deck);
      expect(deck, hasLength(rankedPlayers));
      expect(deck.where((r) => r.team == Team.mafia), hasLength(3));
      expect(deck.where((r) => r == Role.mafioso), hasLength(1));
      expect(deck.where((r) => r.team == Team.neutral), hasLength(1));
      expect(deck, containsAll(rankedGuns));
      expect(deck.where(rankedInvestigators.contains), hasLength(1));
      expect(deck.where(rankedProtectors.contains), hasLength(1));
      expect(deck.where(rankedCivics.contains), hasLength(2));
      expect(deck.where((r) => r == Role.cittadino), hasLength(2));
      expect(deck.where((r) => r != Role.mafioso && r != Role.cittadino).toSet(), hasLength(9), reason: 'una copia');
      expect(deck.any((r) => r.isHostileNeutral || r == Role.prostituta || r == Role.cecchino), isFalse);
    }
    expect(
      seen,
      containsAll([
        ...rankedFamilyPowers,
        ...rankedNeutrals,
        ...rankedInvestigators,
        ...rankedProtectors,
        ...rankedCivics,
      ]),
    );
  });

  test('un telefono vecchio al tavolo: i ruoli che non sa leggere lasciano il posto', () {
    final exclude = rolesTooNewFor(65);
    final random = Random(3);
    for (var i = 0; i < 100; i++) {
      final deck = rankedRoles(random: random, exclude: exclude);
      expect(deck, hasLength(rankedPlayers));
      expect(deck.where(exclude.contains), isEmpty);
      expect(deck.where((r) => r.team == Team.mafia), hasLength(3));
      expect(deck.where((r) => r.isKiller), isNotEmpty);
    }
  });
}
