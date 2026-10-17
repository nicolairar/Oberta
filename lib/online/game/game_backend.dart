import '../../rules/intent.dart';

/// Un posto della partita, come lo registra il server quando la apre: un
/// giocatore della stanza (con il suo profilo) o un bot (senza).
class SeatPlan {
  final String seat;
  final String? profileId;
  final String name;

  const SeatPlan({required this.seat, required this.profileId, required this.name});

  bool get isBot => profileId == null;

  Map<String, Object?> toJson() => {'seat': seat, 'profile_id': profileId, 'name': name};

  factory SeatPlan.fromJson(Map<String, Object?> json) =>
      SeatPlan(seat: json['seat'] as String, profileId: json['profile_id'] as String?, name: json['name'] as String);
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

/// Un'intenzione arrivata al server: chi l'ha mandata (il posto lo mette
/// il database, non il client) e cosa chiede.
class IntentEnvelope {
  final int id;
  final String seat;
  final Map<String, Object?> intent;

  const IntentEnvelope({required this.id, required this.seat, required this.intent});

  Map<String, Object?> toJson() => {'id': id, 'seat': seat, 'intent': intent};

  factory IntentEnvelope.fromJson(Map<String, Object?> json) => IntentEnvelope(
        id: (json['id'] as num).toInt(),
        seat: json['seat'] as String,
        intent: (json['intent'] as Map).cast<String, Object?>(),
      );
}

/// Il tubo della partita online, visto da un telefono. La partita gira sul
/// server (la Edge Function `game`, vedi `game_server.dart`): il telefono
/// non conosce i ruoli degli altri, nemmeno quello del padrone di casa.
/// Ogni chiamata agisce per l'account che è entrato su questo telefono.
abstract class GameBackend {
  /// Il padrone di casa mette (o toglie) i bot di prova nella stanza.
  Future<void> setBots(String roomId, int count);

  /// Il padrone di casa apre la partita. I posti li decide il server (le
  /// persone nell'ordine della stanza, poi i bot), e le carte le dà lui.
  Future<void> startGame(String roomId);

  /// Il tavolo pubblico e la propria vista, ogni volta che cambiano; subito
  /// la versione attuale, così chi ricarica l'app riprende da dove era.
  Stream<GameFeed> watchGame(String roomId);

  /// Manda un'intenzione per il proprio posto. Torna il suo numero: la
  /// risposta del server arriva nella vista con lo stesso numero.
  Future<int> sendIntent(String roomId, PlayerIntent intent);

  /// Conferma al server di aver finito la fase [stage] (`dawn-2`): carta
  /// vista, film finito, letto.
  Future<void> sendAck(String roomId, String seat, String stage);

  /// «Ci sono»: il telefono lo dice ogni pochi secondi finché è in partita.
  /// Torna l'ora del server, in millisecondi.
  Future<int> ping(String roomId);

  /// Di ritorno dallo sfondo, o dopo una rete persa: rinnova l'accesso se
  /// è scaduto e riapre il collegamento in tempo reale. Dopo, chi guarda la
  /// partita si riabbona a [watchGame] e [watchChat].
  Future<void> resume();

  /// Scrive nella chat [channel] della stanza. Il server controlla chi può
  /// scrivere dove e quando, e le parole.
  /// Restituisce l'id del messaggio appena scritto.
  Future<int> sendChat(String roomId, ChatChannel channel, String body);

  /// I messaggi che questo telefono può leggere, dal più vecchio al più nuovo.
  Stream<List<ChatMessage>> watchChat(String roomId);
}

/// Le chat di una stanza: quella della stanza prima della partita, quella
/// della piazza di giorno (per i vivi), quella della famiglia di notte.
enum ChatChannel { lobby, day, family }

class ChatMessage {
  final int id;
  final ChatChannel channel;
  final String profileId;
  final String? seat;
  final String name;
  final String body;
  final DateTime at;

  const ChatMessage({
    required this.id,
    required this.channel,
    required this.profileId,
    required this.seat,
    required this.name,
    required this.body,
    required this.at,
  });

  factory ChatMessage.fromJson(Map<String, Object?> json) => ChatMessage(
        id: (json['id'] as num).toInt(),
        channel: ChatChannel.values.byName(json['channel'] as String),
        profileId: json['profile_id'] as String,
        seat: json['seat'] as String?,
        name: json['name'] as String,
        body: json['body'] as String,
        at: DateTime.parse(json['created_at'] as String),
      );
}
