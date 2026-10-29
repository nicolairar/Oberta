// Bilanciamento della classificata: tante partite in 12, col mazzo della
// classificata (rankedRoles), giocate dai bot del server col fiuto di base.
// Stampa le vittorie per squadra, per ruolo e per composizione del mazzo,
// con l'intervallo di confidenza al 95% (la tabella di docs/ruoli.md, 2.6).
//
//   dart run tool/balance/ranked.dart [partite, di base 20000] [seme]
//   dart run tool/balance/ranked.dart 20000 1 auto   (il mazzo automatico a 12)
// ignore_for_file: avoid_print
import 'dart:math';

import 'package:oberta/online/game/deck_balance.dart';
import 'package:oberta/rules/game_engine.dart';
import 'package:oberta/rules/role.dart';
import 'package:oberta/rules/role_assignment.dart';

String ci(int k, int n) {
  if (n == 0) return '-';
  final p = k / n;
  final h = 1.96 * sqrt(p * (1 - p) / n);
  return '${(p * 100).toStringAsFixed(1)}% ± ${(h * 100).toStringAsFixed(1)}';
}

void main(List<String> args) {
  final games = args.isEmpty ? 20000 : int.parse(args[0]);
  final seed = args.length < 2 ? 1 : int.parse(args[1]);
  final auto = args.length > 2 && args[2] == 'auto';
  // Per composizione: partite, Città, Famiglia, neutrale da solo.
  final groups = <String, List<int>>{};
  void count(String key, String ending) {
    final g = groups.putIfAbsent(key, () => [0, 0, 0, 0]);
    g[0]++;
    g[switch (ending) {
      'citizens' => 1,
      'mafia' => 2,
      _ => 3,
    }]++;
  }

  void onGame(List<Role> deck, GameEngine engine) {
    final ending = engine.phase == GamePhase.ended ? engine.winner!.name : 'none';
    String names(Iterable<Role> roles) => (roles.map((r) => r.name).toList()..sort()).join(' + ');
    count('Famiglia: ${names(deck.where((r) => r.team == Team.mafia && r != Role.mafioso))}', ending);
    count('Neutrale: ${names(deck.where((r) => r.team == Team.neutral))}', ending);
    final points = deck.where((r) => r.team == Team.citizens).fold(0, (sum, r) => sum + r.points);
    count('Punti Città: ${points.toString().padLeft(2)}', ending);
  }

  final r = auto
      ? simulateDecks(rankedPlayers, games, seed: seed, onGame: onGame)
      : simulateRanked(games, seed: seed, onGame: onGame);
  print('## ${auto ? 'Mazzo automatico a 12' : 'Classificata'} ($games partite, seme $seed, fiuto $defaultHunch)\n');
  print('| Squadra | vittorie (IC 95%) |');
  print('|---|---|');
  print('| Città | ${ci(r.endings['citizens'] ?? 0, games)} |');
  print('| Famiglia | ${ci(r.endings['mafia'] ?? 0, games)} |');
  print('| Neutrale da solo | ${ci(r.endings['neutral'] ?? 0, games)} |');
  if ((r.endings['none'] ?? 0) > 0) print('| non finite | ${ci(r.endings['none']!, games)} |');
  print('\n| Ruolo | esce (per partita) | vince quando esce | vittorie sul totale |');
  print('|---|---|---|---|');
  for (final role in Role.values) {
    final d = r.dealt[role] ?? 0;
    if (d == 0) continue;
    final w = r.won[role] ?? 0;
    final often = role == Role.mafioso || role == Role.cittadino
        ? '${(d / games).toStringAsFixed(2)} carte'
        : '${(d / games * 100).toStringAsFixed(1)}%';
    print('| ${role.name} | $often | ${ci(w, d)} | ${role.team == Team.neutral ? ci(w, games) : ''} |');
  }
  print('\n| Composizione | partite | Città | Famiglia | Neutrale |');
  print('|---|---|---|---|---|');
  for (final key in groups.keys.toList()..sort()) {
    final g = groups[key]!;
    if (g[0] < games / 100) continue;
    print('| $key | ${g[0]} | ${ci(g[1], g[0])} | ${ci(g[2], g[0])} | ${ci(g[3], g[0])} |');
  }
}
