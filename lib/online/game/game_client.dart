import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../rules/intent.dart';
import 'game_backend.dart';
import 'game_protocol.dart';

/// La partita vista da un telefono: il tavolo pubblico e la propria vista,
/// e il modo di mandare le proprie intenzioni. È tutto quello che lo schermo
/// della partita online conosce, anche sul telefono del padrone di casa.
class GameClient extends ChangeNotifier {
  final GameBackend backend;
  final String roomId;

  StreamSubscription<GameFeed>? _feed;
  OnlineBoard? _board;
  OnlineSeat? _seat;
  Object? _error;

  /// L'intenzione mandata e non ancora vista nella risposta dell'autorità.
  int? _waitingFor;
  bool _sending = false;

  /// L'ultima intenzione rifiutata, finché qualcuno non la legge.
  IntentRejected? _rejected;

  GameClient({required this.backend, required this.roomId}) {
    _feed = backend.watchGame(roomId).listen(_received, onError: (Object error) {
      _error = error;
      notifyListeners();
    });
  }

  OnlineBoard? get board => _board;
  OnlineSeat? get seat => _seat;
  Object? get error => _error;

  /// Vero quando tavolo e vista sono della stessa versione: lo schermo può
  /// mostrare la partita.
  bool get ready => _board != null && _seat != null;

  /// Vero mentre un'intenzione è in viaggio.
  bool get busy => _sending || _waitingFor != null;

  IntentRejected? takeRejection() {
    final rejected = _rejected;
    _rejected = null;
    return rejected;
  }

  PublicFrame? _pendingBoard;
  SeatFrame? _pendingSeat;

  void _received(GameFeed feed) {
    _error = null;
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

  /// Manda un'intenzione per il proprio posto.
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

  @override
  void dispose() {
    _feed?.cancel();
    super.dispose();
  }
}
