import 'dart:async';

import '../rules/player.dart';
import '../rules/room_code.dart';
import 'game_session.dart';

/// Sessione finta per giocare su un solo telefono, prima che esista una vera
/// rete locale (HostLocale). Nessuno si collega: chi siede al tavolo lo
/// decide questo telefono, e lo dice alla stanza con [seat].
class FakeLocalSession implements GameSession {
  @override
  final String roomCode;

  @override
  final Player me;

  final _players = <Player>[];
  final _controller = StreamController<List<Player>>.broadcast();

  FakeLocalSession({required String hostName})
      : roomCode = generateRoomCode(),
        me = Player(id: 'host', name: hostName) {
    _players.add(me);
  }

  @override
  List<Player> get currentPlayers => List.unmodifiable(_players);

  @override
  Stream<List<Player>> get playersStream => _controller.stream;

  /// Mette [table] al posto di chi c'era nella stanza. Su un telefono solo
  /// non c'è un "io" che gioca: il tavolo è l'elenco di chi se lo passa.
  void seat(List<Player> table) {
    _players
      ..clear()
      ..addAll(table);
    if (!_controller.isClosed) _controller.add(List.unmodifiable(_players));
  }

  @override
  void dispose() {
    _controller.close();
  }
}
