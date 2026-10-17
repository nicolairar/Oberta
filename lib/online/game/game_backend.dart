import '../../rules/intent.dart';

/// Un posto per la partita, come lo manda chi la apre: un giocatore della
/// stanza (con il suo profilo) o un bot (senza).
class SeatPlan {
  final String seat;
  final String? profileId;
  final String name;

  const SeatPlan({required this.seat, required this.profileId, required this.name});

  bool get isBot => profileId == null;

  Map<String, Object?> toJson() => {'seat': seat, 'profile_id': profileId, 'name': name};
}

/// Una versione del tavolo pubblico, come la legge chiunque sia nella stanza.
class PublicFrame {
  final int version;
  final Map<String, Object?> payload;

  const PublicFrame(this.version, this.payload);
}

/// Una versione della vista di un posto, come la legge solo chi ci siede.
class SeatFrame {
  final String seat;
  final int version;
  final Map<String, Object?> payload;

  const SeatFrame(this.seat, this.version, this.payload);
}

/// Quello che un telefono riceve: il tavolo pubblico e, se ha un posto, la
/// sua vista. Mai la vista di un altro.
class GameFeed {
  final PublicFrame? board;
  final SeatFrame? seat;

  const GameFeed({this.board, this.seat});
}

/// Un'intenzione arrivata all'autorità: chi l'ha mandata (il posto lo mette
/// il server, non il client) e cosa chiede.
class IntentEnvelope {
  final int id;
  final String seat;
  final Map<String, Object?> intent;

  const IntentEnvelope({required this.id, required this.seat, required this.intent});
}

/// Una pubblicazione dell'autorità: il tavolo pubblico, una vista per ogni
/// posto umano, lo stato salvato per riprendere la partita, l'ultima
/// intenzione gestita. Va sul server tutta insieme, o niente.
class GamePublication {
  final int version;
  final Map<String, Object?> board;
  final Map<String, Map<String, Object?>> seatViews;
  final Map<String, Object?> hostState;
  final int? lastIntent;
  final bool finished;

  const GamePublication({
    required this.version,
    required this.board,
    required this.seatViews,
    required this.hostState,
    this.lastIntent,
    this.finished = false,
  });
}

/// Il tubo della partita online. Il server non conosce le regole: controlla
/// solo chi può leggere e scrivere cosa (vedi la migrazione
/// `20261017160000_online_games.sql`). Ogni chiamata agisce per l'account
/// che è entrato su questo telefono.
abstract class GameBackend {
  /// Il padrone di casa mette (o toglie) i bot di prova nella stanza.
  Future<void> setBots(String roomId, int count);

  /// Il padrone di casa apre la partita: chi siede dove. Da qui il suo
  /// telefono è l'autorità della partita.
  Future<void> startGame(String roomId, List<SeatPlan> seats);

  /// Solo l'autorità: una nuova versione della partita.
  Future<void> publish(String roomId, GamePublication publication);

  /// Solo l'autorità: le intenzioni ancora da gestire, aggiornate a ogni
  /// arrivo (e subito, all'ascolto: chi riprende la partita le ritrova).
  Stream<List<IntentEnvelope>> watchIntents(String roomId);

  /// Solo l'autorità: lo stato salvato all'ultima pubblicazione.
  Future<Map<String, Object?>?> loadHostState(String roomId);

  /// Il tavolo pubblico e la propria vista, ogni volta che cambiano; subito
  /// la versione attuale, così chi ricarica l'app riprende da dove era.
  Stream<GameFeed> watchGame(String roomId);

  /// Manda un'intenzione per il proprio posto. Torna il suo numero: la
  /// risposta dell'autorità arriva nella vista con lo stesso numero.
  Future<int> sendIntent(String roomId, PlayerIntent intent);
}
