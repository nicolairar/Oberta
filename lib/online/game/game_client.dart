import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../rules/intent.dart';
import 'game_backend.dart';
import 'game_clock.dart';
import 'game_feed.dart';
import 'game_schedule.dart';

/// La partita vista da un telefono: il tavolo pubblico e la propria vista,
/// l'orologio del server, la chat, e il modo di mandare le proprie mosse e
/// conferme. È tutto quello che lo schermo della partita online conosce:
/// la partita gira sul server, e nessun telefono sa i ruoli degli altri.
class GameClient extends ChangeNotifier {
  final GameBackend backend;
  final String roomId;
  final GameClock clock;

  /// Ogni quanto il telefono dice al server «ci sono».
  final Duration heartbeat;

  /// Il profilo di questo telefono, per mostrare subito i propri messaggi.
  final String? me;

  /// I propri messaggi già scritti e non ancora arrivati dal feed.
  final Map<int, ChatMessage> _sent = {};
  List<ChatMessage> _fed = const [];

  StreamSubscription<GameFeed>? _feed;
  StreamSubscription<List<ChatMessage>>? _chatFeed;
  GameTimer? _beat;
  OnlineBoard? _board;
  OnlineSeat? _seat;
  Object? _error;
  List<ChatMessage> _chat = const [];
  bool _disposed = false;

  /// Di quanto l'orologio del server è avanti rispetto a questo telefono,
  /// misurato al ping col viaggio più breve.
  Duration _offset = Duration.zero;
  Duration? _bestTrip;

  /// L'intenzione mandata e non ancora vista nella risposta del server.
  int? _waitingFor;
  bool _sending = false;

  /// L'ultima intenzione rifiutata, finché qualcuno non la legge.
  IntentRejected? _rejected;

  /// Le fasi già confermate da qui.
  final Set<String> _acked = {};

  GameClient({
    required this.backend,
    required this.roomId,
    this.clock = const SystemGameClock(),
    this.heartbeat = const Duration(seconds: 5),
    this.me,
  }) {
    _listen();
    _ping();
  }

  void _listen() {
    _feed = backend.watchGame(roomId).listen(_received, onError: (Object error) {
      _error = error;
      _reconnecting = false;
      notifyListeners();
    });
    _chatFeed = backend.watchChat(roomId).listen((messages) {
      _fed = messages;
      _mergeChat();
      notifyListeners();
    }, onError: (Object _) {});
  }

  bool _reconnecting = false;
  int _rejoins = 0;

  /// Vero mentre si rientra al tavolo, finché il server non ridà la partita.
  bool get reconnecting => _reconnecting;

  /// Rientra al tavolo (di ritorno dallo sfondo, o col bottone): accesso
  /// rinnovato, collegamento in tempo reale riaperto, un «ci sono» subito
  /// (il server rimette il posto fra i presenti), poi tavolo e vista riletti
  /// così come sono adesso. La fase già confermata resta confermata.
  Future<void> rejoin() async {
    if (_disposed) return;
    final attempt = ++_rejoins;
    _reconnecting = true;
    notifyListeners();
    try {
      await backend.resume();
    } catch (_) {
      // Si prova lo stesso: il ping e la lettura diranno se la rete c'è.
    }
    if (_disposed || attempt != _rejoins) return;
    await _feed?.cancel();
    await _chatFeed?.cancel();
    if (_disposed || attempt != _rejoins) return;
    _pendingBoard = null;
    _pendingSeat = null;
    _beat?.cancel();
    _beat = null;
    _listen();
    await _ping();
    if (_disposed || attempt != _rejoins) return;
    if (_reconnecting && _error != null) {
      _reconnecting = false;
      notifyListeners();
    }
  }

  OnlineBoard? get board => _board;
  OnlineSeat? get seat => _seat;
  Object? get error => _error;
  List<ChatMessage> get chat => _chat;

  /// La fase in corso, con le sue ore (del server).
  StageWindow? get schedule => _board?.schedule;

  /// L'ora del server, adesso, secondo questo telefono.
  DateTime get serverNow => clock.now().add(_offset);

  /// Quanto manca alla fine della fase in corso (zero se è finita).
  Duration get timeLeft {
    final window = schedule;
    if (window == null) return Duration.zero;
    final left = window.endsAt.difference(serverNow);
    return left.isNegative ? Duration.zero : left;
  }

  /// Da quanto è cominciata la fase in corso (negativo se deve ancora
  /// cominciare: si aspetta, per partire tutti insieme).
  Duration get elapsed {
    final window = schedule;
    return window == null ? Duration.zero : serverNow.difference(window.startsAt);
  }

  /// Vero quando tavolo e vista sono della stessa versione: lo schermo può
  /// mostrare la partita.
  bool get ready => _board != null && _seat != null;

  /// Vero mentre un'intenzione è in viaggio, o aspetta la risposta.
  bool get busy => _sending || _waitingFor != null;

  IntentRejected? takeRejection() {
    final rejected = _rejected;
    _rejected = null;
    return rejected;
  }

  Future<void> _ping() async {
    if (_disposed) return;
    try {
      final sent = clock.now();
      final server = await backend.ping(roomId);
      final back = clock.now();
      final trip = back.difference(sent);
      if (_bestTrip == null || trip <= _bestTrip!) {
        _bestTrip = trip;
        final middle = sent.add(trip ~/ 2);
        _offset = DateTime.fromMillisecondsSinceEpoch(server).difference(middle);
      }
    } catch (_) {
      // Un ping perso non conta: il server aspetta prima di dire «offline».
    }
    if (_disposed) return;
    _beat?.cancel();
    _beat = clock.schedule(heartbeat, _ping);
  }

  PublicFrame? _pendingBoard;
  SeatFrame? _pendingSeat;

  void _received(GameFeed feed) {
    _error = null;
    if (_reconnecting && feed.board != null) {
      _reconnecting = false;
      notifyListeners();
    }
    if (feed.board case final board?) _pendingBoard = board;
    if (feed.seat case final seat?) _pendingSeat = seat;
    final board = _pendingBoard;
    final seat = _pendingSeat;
    if (board == null || board.payload.isEmpty) return;
    // Tavolo e vista vanno mostrati insieme: si aspetta che siano della
    // stessa versione (arrivano dal server una alla volta).
    if (seat == null || seat.version != board.version) return;
    if (_board?.version == board.version) return;
    final parsed = OnlineBoard.fromPayload(board.version, board.payload);
    _board = parsed;
    _seat = OnlineSeat.fromPayload(seat.version, seat.payload, parsed.seating);
    _checkReceipt();
    notifyListeners();
  }

  void _checkReceipt() {
    final receipt = _seat?.receipt;
    final waiting = _waitingFor;
    if (receipt == null || waiting == null || receipt.id < waiting) return;
    _waitingFor = null;
    if (receipt.id == waiting && receipt.result is IntentRejected) _rejected = receipt.result as IntentRejected;
  }

  /// Manda un'intenzione per il proprio posto. La mossa conta solo quando
  /// torna la risposta del server ([busy] torna falso, la vista cambia).
  Future<void> send(PlayerIntent intent) async {
    _sending = true;
    notifyListeners();
    try {
      _waitingFor = await backend.sendIntent(roomId, intent);
      // La risposta può arrivare prima del numero.
      _checkReceipt();
    } catch (error) {
      _error = error;
      rethrow;
    } finally {
      _sending = false;
      notifyListeners();
    }
  }

  /// Conferma la fase in corso (carta vista, film finito, letto). Una volta
  /// sola per fase; la conferma arrivata al server si vede in [OnlineSeat.acked].
  Future<void> ack() async {
    final window = schedule;
    final seat = _seat?.view.seat.id;
    if (window == null || seat == null || !window.stage.acknowledged || !_acked.add(window.key)) return;
    try {
      await backend.sendAck(roomId, seat, window.key);
    } catch (_) {
      _acked.remove(window.key);
    }
  }

  /// Vero se da qui si è già confermata la fase in corso.
  bool get ackedHere => schedule != null && _acked.contains(schedule!.key);

  /// Manda un messaggio e lo mostra subito, senza aspettare il feed (che
  /// poi lo sostituisce, stesso id). [name] e [profileId] facoltativi: di
  /// norma il nome del proprio posto e [me].
  Future<int> sendChat(ChatChannel channel, String body, {String? name, String? profileId}) async {
    final id = await backend.sendChat(roomId, channel, body);
    final author = profileId ?? me;
    final view = _seat?.view;
    if (_disposed || author == null) return id;
    final lobby = channel == ChatChannel.lobby;
    _sent[id] = ChatMessage(
      id: id,
      channel: channel,
      profileId: author,
      seat: lobby ? null : view?.seat.id,
      name: name ?? view?.seat.name ?? '',
      body: body.trim(),
      at: serverNow,
    );
    _mergeChat();
    notifyListeners();
    return id;
  }

  void _mergeChat() {
    final fed = {for (final message in _fed) message.id};
    _sent.removeWhere((id, _) => fed.contains(id));
    _chat = [..._fed, ..._sent.values]..sort((a, b) => a.id.compareTo(b.id));
  }

  @override
  void dispose() {
    _disposed = true;
    _feed?.cancel();
    _chatFeed?.cancel();
    _beat?.cancel();
    super.dispose();
  }
}
