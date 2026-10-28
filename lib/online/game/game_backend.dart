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
/// il database, non il client) e cosa chiede. [id] è l'ordine di arrivo, solo
/// per il server; [token] è il segno casuale che il telefono ha ricevuto da
/// `submit_intent` e ritrova nella risposta (mai l'[id]: conterebbe le mosse
/// di tutti).
class IntentEnvelope {
  final int id;
  final String? token;
  final String seat;
  final Map<String, Object?> intent;

  const IntentEnvelope({required this.id, this.token, required this.seat, required this.intent});

  Map<String, Object?> toJson() => {'id': id, if (token != null) 'token': token, 'seat': seat, 'intent': intent};

  factory IntentEnvelope.fromJson(Map<String, Object?> json) => IntentEnvelope(
        id: (json['id'] as num).toInt(),
        token: json['token'] as String?,
        seat: json['seat'] as String,
        intent: (json['intent'] as Map).cast<String, Object?>(),
      );
}

/// Il tubo della partita online, visto da un telefono. La partita gira sul
/// server (la Edge Function `game`, vedi `game_server.dart`): il telefono
/// non conosce i ruoli degli altri, nemmeno quello del padrone di casa.
/// Ogni chiamata agisce per l'account che è entrato su questo telefono.
abstract class GameBackend {
  /// Il padrone di casa apre la partita. I posti li decide il server (le
  /// persone nell'ordine della stanza, poi i bot), e le carte le dà lui.
  /// I bot non li sceglie nessun telefono: nel periodo di prova (la voce
  /// `friends_test_bots` del server) bastano due persone e il server
  /// riempie da solo i posti vuoti.
  Future<void> startGame(String roomId);

  /// Il tavolo pubblico e la propria vista, ogni volta che cambiano; subito
  /// la versione attuale, così chi ricarica l'app riprende da dove era.
  Stream<GameFeed> watchGame(String roomId);

  /// Manda un'intenzione per il proprio posto. Torna il suo segno (casuale):
  /// la risposta del server arriva nella vista con lo stesso segno.
  Future<String> sendIntent(String roomId, PlayerIntent intent);

  /// Conferma al server di aver finito la fase [stage] (`dawn-2`): carta
  /// vista, film finito, letto.
  Future<void> sendAck(String roomId, String seat, String stage);

  /// «Ci sono»: il telefono lo dice ogni pochi secondi finché è in partita.
  /// Torna l'ora del server, in millisecondi.
  Future<int> ping(String roomId);

  /// Esco dalla partita per davvero: il server mi conta subito come
  /// abbandono, senza aspettare che scada l'attesa del ritorno.
  Future<void> leaveGame(String roomId);

  /// Di ritorno dallo sfondo, o dopo una rete persa: rinnova l'accesso se
  /// è scaduto e riapre il collegamento in tempo reale. Dopo, chi guarda la
  /// partita si riabbona a [watchGame] e [watchChat].
  Future<void> resume();

  /// Scrive nella chat [channel] della stanza. Il server controlla chi può
  /// scrivere dove e quando, e le parole.
  /// Restituisce l'id (casuale) del messaggio appena scritto.
  Future<String> sendChat(String roomId, ChatChannel channel, String body);

  /// I messaggi che questo telefono può leggere, dal più vecchio al più nuovo.
  Stream<List<ChatMessage>> watchChat(String roomId);
}

/// Le chat di una stanza: quella della stanza prima della partita, quella
/// della piazza di giorno (per i vivi), quella della famiglia di notte.
/// [event]: the server's own lines about the game (see game_events.dart),
/// read in every chat of the game, never written by a phone.
/// [jail]: the Jailer and the prisoner, one night only (on the server the
/// channel is `jail:<round>`, see [ChatMessage.thread]).
/// [lovers]: Cupid's couple, at night.
enum ChatChannel { lobby, day, family, event, jail, lovers }

/// A line of the server in the chat: what happened ([kind], with names and
/// enum names in [data]), for the whole table or, [private], for this phone
/// only.
class GameEvent {
  final String kind;
  final Map<String, Object?> data;
  final bool private;

  const GameEvent(this.kind, this.data, {this.private = false});
}

class ChatMessage {
  /// Random (a uuid on the server): it tells nothing about other messages.
  final String id;

  /// The order within its channel (1, 2, 3... for the readers of that
  /// channel only); 0 for a message just sent and not yet in the feed.
  final int n;
  final ChatChannel channel;
  final String profileId;
  final String? seat;
  final String name;
  final String body;
  final DateTime at;

  /// Set on the server's lines ([ChatChannel.event]).
  final GameEvent? event;

  /// The server's channel when it is more than [channel]: the night of a
  /// cell (`jail:3`). Null otherwise.
  final String? thread;

  /// In the cell: the Jailer wrote this (no profile, no seat, no name).
  bool get fromJailer => channel == ChatChannel.jail && seat == null;

  const ChatMessage({
    required this.id,
    this.n = 0,
    required this.channel,
    required this.profileId,
    required this.seat,
    required this.name,
    required this.body,
    required this.at,
    this.event,
    this.thread,
  });

  /// A row of `game_events`. Its id is made up here: the public lines of a
  /// step first, then this phone's own, in order ([n]); at the same time the
  /// events come before the messages.
  factory ChatMessage.event({
    required String kind,
    required Map<String, Object?> data,
    required bool private,
    required int n,
    required DateTime at,
  }) =>
      ChatMessage(
        id: 'event-${private ? 'p' : 't'}-${at.microsecondsSinceEpoch}-$n',
        n: (private ? 500 : 0) + n,
        channel: ChatChannel.event,
        profileId: '',
        seat: null,
        name: '',
        body: '',
        at: at,
        event: GameEvent(kind, data, private: private),
      );

  /// Chat order: by time; at the same time the server's lines first, then
  /// by the order within the channel ([n]), then by id.
  static int byTime(ChatMessage a, ChatMessage b) {
    final at = a.at.compareTo(b.at);
    if (at != 0) return at;
    final events = (b.channel == ChatChannel.event ? 1 : 0) - (a.channel == ChatChannel.event ? 1 : 0);
    if (events != 0) return events;
    final n = a.n.compareTo(b.n);
    return n != 0 ? n : a.id.compareTo(b.id);
  }

  factory ChatMessage.fromJson(Map<String, Object?> json) => ChatMessage(
        id: json['id'] as String,
        n: (json['n'] as num?)?.toInt() ?? 0,
        channel: _channelOf(json['channel'] as String),
        thread: (json['channel'] as String).contains(':') ? json['channel'] as String : null,
        // The Jailer's lines carry no profile: the prisoner must not know.
        profileId: json['profile_id'] as String? ?? '',
        seat: json['seat'] as String?,
        name: json['name'] as String,
        body: json['body'] as String,
        at: DateTime.parse(json['created_at'] as String),
      );
}

ChatChannel _channelOf(String name) =>
    name.startsWith('jail:') ? ChatChannel.jail : ChatChannel.values.byName(name);
