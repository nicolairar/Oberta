import 'dart:math';

import 'player.dart';
import 'role.dart';
import 'role_assignment.dart';

/// Esito della preparazione: chi racconta e chi ha quale ruolo.
/// L'ordine di [roles] è l'ordine dei posti al tavolo.
class GameSetup {
  /// `null` quando il narratore è automatico.
  final Player? narrator;
  final Map<Player, Role> roles;

  GameSetup.fromRoles(Map<Player, Role> roles, {this.narrator}) : roles = Map.unmodifiable(roles);

  /// Il narratore umano non riceve un ruolo: giocano tutti gli altri.
  factory GameSetup.deal({
    required List<Player> lobby,
    Player? narrator,
    Random? random,
    PlayMode mode = PlayMode.sharedPhone,
  }) {
    final players = [
      for (final player in lobby)
        if (player != narrator) player,
    ];
    return GameSetup.fromRoles(assignRoles(players, random, mode), narrator: narrator);
  }

  List<Player> get players => roles.keys.toList();

  Role roleOf(Player player) => roles[player]!;

  /// I complici che [player] ha diritto di conoscere: solo i mafiosi si vedono
  /// tra loro. La Prostituta non conosce nessuno, e nessuno conosce lei.
  List<Player> teammatesOf(Player player) {
    if (!roleOf(player).knowsFamily) return const [];
    return [
      for (final entry in roles.entries)
        if (entry.key != player && entry.value.knowsFamily) entry.key,
    ];
  }
}
