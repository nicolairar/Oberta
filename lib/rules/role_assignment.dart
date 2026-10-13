import 'dart:math';

import 'player.dart';
import 'role.dart';

/// Numero minimo di giocatori con un ruolo (narratore escluso).
const minRolePlayers = 3;

/// Numero massimo di giocatori con un ruolo: oltre, il tavolo non si regge.
const maxRolePlayers = 16;

/// Mazzo bilanciato per [count] giocatori: circa uno della famiglia ogni
/// quattro, ruoli speciali che entrano man mano che il tavolo cresce, il
/// resto Onesti (almeno uno, a ogni tavolo).
///
/// Nella famiglia, da otto giocatori uno è il Padrino e da dieci uno è il
/// Sarto; gli altri sono Picciotti. Il Padrino spara, quindi c'è sempre
/// qualcuno che può uccidere.
List<Role> rolesForPlayerCount(int count) {
  if (count < minRolePlayers) {
    throw ArgumentError.value(count, 'count', 'servono almeno $minRolePlayers giocatori');
  }
  if (count > maxRolePlayers) {
    throw ArgumentError.value(count, 'count', 'si gioca al massimo in $maxRolePlayers');
  }
  final family = <Role>[
    if (count >= 8) Role.padrino,
    if (count >= 10) Role.sarto,
  ];
  final special = <Role>[
    ...family,
    ...List.filled(max(1, count ~/ 4) - family.length, Role.mafioso),
    if (count >= 4) Role.detective,
    if (count >= 5) Role.medico,
    if (count >= 7) Role.cecchino,
    if (count >= 8) Role.giornalista,
    if (count >= 8) Role.becchino,
    if (count >= 9) Role.reduce,
    if (count >= 10) Role.guardaspalle,
    if (count >= 11) Role.pregiudicato,
  ];
  return [...special, ...List.filled(count - special.length, Role.cittadino)];
}

/// Distribuisce a caso un mazzo bilanciato. L'ordine della mappa segue [players].
Map<Player, Role> assignRoles(List<Player> players, [Random? random]) {
  final deck = rolesForPlayerCount(players.length)..shuffle(random ?? Random());
  return Map.fromIterables(players, deck);
}
