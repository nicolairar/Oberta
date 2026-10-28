import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/online/game/deck_balance.dart';
import 'package:oberta/rules/role.dart';

// La simulazione dei mazzi (docs/ruoli.md, 2.5): partite giocate dai bot del
// server, con il fiuto di base, per ogni tavolo da 4 a 12. La tabella
// completa (3000 partite per tavolo) la stampa tool/balance/simulate.dart.

void main() {
  const games = 400;

  test('nessuna squadra stravince: sopra il 60% solo a 6 e 7 (salto da 1 a 2 della Famiglia)', () {
    for (var n = 4; n <= 12; n++) {
      final report = simulateDecks(n, games, seed: n);
      final top = ['citizens', 'mafia', 'neutral'].map(report.share).reduce((a, b) => a > b ? a : b);
      final cap = n == 6 || n == 7 ? 0.8 : 0.64;
      expect(top, lessThanOrEqualTo(cap), reason: 'n=$n ${report.endings}');
      expect(report.share('none'), lessThan(0.01), reason: 'n=$n: le partite finiscono');
    }
  });

  test('i ruoli nuovi non spostano nessun tavolo di più di 8 punti', () {
    for (var n = 8; n <= 12; n++) {
      final with_ = simulateDecks(n, games, seed: 100 + n);
      final without = simulateDecks(n, games, seed: 100 + n, exclude: newRoles);
      for (final team in ['citizens', 'mafia', 'neutral']) {
        expect((with_.share(team) - without.share(team)).abs(), lessThan(0.08), reason: 'n=$n $team');
      }
    }
  });

  test('nessun ruolo vince più del 60% delle volte che esce', () {
    final dealt = <Role, int>{};
    final won = <Role, int>{};
    for (var n = 4; n <= 12; n++) {
      final report = simulateDecks(n, games, seed: 200 + n);
      report.dealt.forEach((role, count) => dealt[role] = (dealt[role] ?? 0) + count);
      report.won.forEach((role, count) => won[role] = (won[role] ?? 0) + count);
    }
    for (final role in dealt.keys) {
      if (dealt[role]! < 100) continue;
      expect((won[role] ?? 0) / dealt[role]!, lessThanOrEqualTo(0.6), reason: role.name);
    }
    expect(dealt.keys, containsAll(newRoles));
  });
}
