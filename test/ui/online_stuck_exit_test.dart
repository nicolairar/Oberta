import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/l10n/app_language.dart';
import 'package:oberta/l10n/lobby_language.dart';
import 'package:oberta/online/fake_online.dart';
import 'package:oberta/online/online_services.dart';
import 'package:oberta/online/supabase_online.dart' show signOutOrLocal;
import 'package:oberta/rules/intent.dart';
import 'package:oberta/ui/screens/online/online_game_screen.dart';

import '../support/languages.dart';
import '../support/manual_clock.dart';

// Build 65 got stuck at the table: the server dealt a role it did not know,
// the table never parsed, the screen stayed on "connecting", and the exit
// read a table that was not there. Leaving must always work, even when the
// table cannot be read and the server never answers.

/// The fake server's game, with a deck from the future and a server that
/// never answers a leave or a ping.
class _FromTheFuture implements GameBackend {
  final GameBackend inner;
  int leaves = 0;

  _FromTheFuture(this.inner);

  @override
  Stream<GameFeed> watchGame(String roomId) => inner.watchGame(roomId).map((feed) {
    final board = feed.board;
    if (board == null) return feed;
    final view = Map<String, Object?>.of(board.payload);
    final table = Map<String, Object?>.of(view['board'] as Map<String, Object?>);
    table['deck'] = [
      ...(table['deck'] as List<Object?>? ?? const []),
      {'role': 'ruoloDelFuturo', 'count': 1},
    ];
    view['board'] = table;
    return GameFeed(board: PublicFrame(board.version, view), seat: feed.seat);
  });

  @override
  Future<void> leaveGame(String roomId) {
    leaves++;
    return Completer<void>().future;
  }

  @override
  Future<int> ping(String roomId) => Completer<int>().future;

  @override
  Future<void> startGame(String roomId) => inner.startGame(roomId);

  @override
  Future<String> sendIntent(String roomId, PlayerIntent intent) => inner.sendIntent(roomId, intent);

  @override
  Future<void> sendAck(String roomId, String seat, String stage) => inner.sendAck(roomId, seat, stage);

  @override
  Future<void> resume() => inner.resume();

  @override
  Future<String> sendChat(String roomId, ChatChannel channel, String body) => inner.sendChat(roomId, channel, body);

  @override
  Stream<List<ChatMessage>> watchChat(String roomId) => inner.watchChat(roomId);
}

Future<void> _frames(WidgetTester tester, [int n = 20]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('a table this build cannot read: the screen says to update, and leaving works with a silent server', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final clock = ManualClock();
    final online = FakeOnline(accountId: 'bruno', clock: clock)
      ..signInReady(handle: 'bruno')
      ..addPlayer('anna', handle: 'anna');
    final room = online.openRoomAs('anna', LobbyLanguage.it);
    online.joinAs('bruno', room.code);
    await tester.runAsync(() => online.gameAs('anna').setBots(room.id, 3));
    await tester.runAsync(() => online.gameAs('anna').startGame(room.id));
    final me = (await tester.runAsync(() => online.services.profiles.me()))!;
    final real = online.services;
    final game = _FromTheFuture(real.game);
    final services = OnlineServices(
      auth: real.auth,
      profiles: real.profiles,
      friends: real.friends,
      rooms: real.rooms,
      game: game,
    );

    await tester.pumpWidget(
      appIn(
        AppLanguage.it,
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                key: const Key('open'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => OnlineGameScreen(services: services, room: room, me: me, clock: clock),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open')));
    await _frames(tester);
    expect(find.byType(OnlineGameScreen), findsOneWidget);
    expect(find.byKey(const Key('online.unreadable')), findsOneWidget, reason: 'not "connecting" forever');
    expect(tester.takeException(), isNull);

    // The X in the header: the question, then out, even if the server is silent.
    await tester.tap(find.byIcon(Icons.close).first);
    await _frames(tester, 6);
    expect(find.byKey(const Key('online.leave.confirm')), findsOneWidget);
    await tester.tap(find.byKey(const Key('online.leave.confirm')));
    await tester.pump(const Duration(seconds: 5));
    await _frames(tester);
    expect(game.leaves, 1, reason: 'the server is told');
    expect(find.byType(OnlineGameScreen), findsNothing, reason: 'out of the game without an answer');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  test('signing out never hangs on a silent server: it falls back to this phone only', () async {
    var local = 0;
    await signOutOrLocal(
      () => Completer<void>().future,
      () async => local++,
      timeout: const Duration(milliseconds: 20),
    );
    expect(local, 1);
    await signOutOrLocal(() async => throw Exception('offline'), () async => local++);
    expect(local, 2);
    await signOutOrLocal(() async {}, () async => local++);
    expect(local, 2, reason: 'the server answered: nothing else to do');
  });
}
