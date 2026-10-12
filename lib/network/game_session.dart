import '../rules/player.dart';

/// Interfaccia di comunicazione per una stanza di gioco.
///
/// Implementazioni possibili: [FakeLocalSession] (fase 1, un solo telefono,
/// per sviluppare la UI), HostLocale (fase 1 reale, rete locale), ServerRemoto
/// (fase 2, Supabase). La UI dipende solo da questa interfaccia.
abstract class GameSession {
  String get roomCode;
  Player get me;

  /// Lista giocatori al momento della lettura (per lo stato iniziale della UI).
  List<Player> get currentPlayers;

  /// Emette la lista aggiornata dei giocatori ogni volta che cambia.
  Stream<List<Player>> get playersStream;

  void dispose();
}
