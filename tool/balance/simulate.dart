// Bilanciamento dei mazzi: tante partite giocate dai bot del server, per
// ogni misura di tavolo, con e senza i ruoli nuovi. Stampa le vittorie per
// squadra e per ruolo (la tabella di docs/ruoli.md, sezione 2.5).
//
//   dart run tool/balance/simulate.dart [partite per tavolo, di base 3000] [fiuto]
// ignore_for_file: avoid_print
import 'package:oberta/online/game/deck_balance.dart';
import 'package:oberta/rules/role.dart';

void main(List<String> args) {
  final games = args.isEmpty ? 3000 : int.parse(args.first);
  final hunch = args.length < 2 ? defaultHunch : double.parse(args[1]);
  String pct(double x) => '${(x * 100).round()}%';
  for (final (label, exclude) in [('con i ruoli nuovi', <Role>{}), ('senza i ruoli nuovi', newRoles)]) {
    print('## $label ($games partite per tavolo, fiuto $hunch)\n');
    print('| n | Città | Famiglia | Neutrali | non finite |');
    print('|---|---|---|---|---|');
    final dealt = <Role, int>{};
    final won = <Role, int>{};
    for (var n = 4; n <= 12; n++) {
      final r = simulateDecks(n, games, seed: n * 1000 + exclude.length, exclude: exclude, hunch: hunch);
      print(
        '| $n | ${pct(r.share('citizens'))} | ${pct(r.share('mafia'))} | ${pct(r.share('neutral'))} | ${pct(r.share('none'))} |',
      );
      r.dealt.forEach((role, c) => dealt[role] = (dealt[role] ?? 0) + c);
      r.won.forEach((role, c) => won[role] = (won[role] ?? 0) + c);
    }
    print('\n| Ruolo | carte | vittorie |');
    print('|---|---|---|');
    for (final role in Role.values) {
      final d = dealt[role] ?? 0;
      if (d == 0) continue;
      print('| ${role.name} | $d | ${pct((won[role] ?? 0) / d)} |');
    }
    print('');
  }
}
