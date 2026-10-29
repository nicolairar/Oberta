import 'dart:math';

import 'player.dart';
import 'role.dart';
import 'role_assignment.dart';

/// Come vota la piazza sul telefono unico. Online ognuno vota dal suo
/// telefono e questa scelta non c'entra.
enum LocalVote {
  /// A voce, tutti insieme: poi uno tocca chi condannate, o il pareggio.
  voice,

  /// Il telefono passa di mano e ognuno vota da solo: si vede solo il risultato.
  secret,
}

/// Esito della preparazione: chi racconta, chi ha quale ruolo e come si vota.
/// L'ordine di [roles] è l'ordine dei posti al tavolo.
class GameSetup {
  /// `null` quando il narratore è automatico.
  final Player? narrator;
  final Map<Player, Role> roles;

  /// Il voto della piazza sul telefono unico: si sceglie a ogni partita, e
  /// si parte sempre dal voto a voce. Non va nel JSON: online non serve.
  final LocalVote vote;

  GameSetup.fromRoles(Map<Player, Role> roles, {this.narrator, this.vote = LocalVote.voice})
      : roles = Map.unmodifiable(roles);

  /// Il narratore umano non riceve un ruolo: giocano tutti gli altri.
  factory GameSetup.deal({
    required List<Player> lobby,
    Player? narrator,
    Random? random,
    PlayMode mode = PlayMode.sharedPhone,
    LocalVote vote = LocalVote.voice,
  }) {
    final players = [
      for (final player in lobby)
        if (player != narrator) player,
    ];
    return GameSetup.fromRoles(assignRoles(players, random, mode), narrator: narrator, vote: vote);
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
