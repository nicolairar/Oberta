import 'dart:math';

import 'player.dart';
import 'role.dart';

/// Numero minimo di giocatori con un ruolo (narratore escluso).
const minRolePlayers = 3;

/// Numero massimo di giocatori con un ruolo: oltre, il tavolo non si regge.
const maxRolePlayers = 16;

/// Mazzo bilanciato per [count] giocatori: circa un mafioso ogni quattro,
/// ruoli speciali che entrano man mano che il tavolo cresce, il resto cittadini.
List<Role> rolesForPlayerCount(int count) {
  if (count < minRolePlayers) {
    throw ArgumentError.value(count, 'count', 'servono almeno $minRolePlayers giocatori');
  }
  final special = <Role>[
    ...List.filled(max(1, count ~/ 4), Role.mafioso),
    if (count >= 4) Role.detective,
    if (count >= 5) Role.medico,
    if (count >= 7) Role.cecchino,
    if (count >= 8) Role.giornalista,
  ];
  return [...special, ...List.filled(count - special.length, Role.cittadino)];
}

/// Distribuisce a caso un mazzo bilanciato. L'ordine della mappa segue [players].
Map<Player, Role> assignRoles(List<Player> players, [Random? random]) {
  final deck = rolesForPlayerCount(players.length)..shuffle(random ?? Random());
  return Map.fromIterables(players, deck);
}
