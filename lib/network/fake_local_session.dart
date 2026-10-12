import 'dart:async';

import '../rules/player.dart';
import '../rules/room_code.dart';
import 'game_session.dart';

/// Sessione finta per sviluppare la UI su un solo telefono, prima che esista
/// una vera rete locale (HostLocale). Il narratore/host è l'unico giocatore
/// reale; gli altri si possono aggiungere a mano per provare il flusso.
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

  void addFakePlayer(String name) {
    _players.add(Player(id: 'fake-${_players.length}', name: name));
    _controller.add(List.unmodifiable(_players));
  }

  @override
  void dispose() {
    _controller.close();
  }
}
