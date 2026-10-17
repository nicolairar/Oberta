import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/l10n/app_language.dart';
import 'package:oberta/online/fake_online.dart';
import 'package:oberta/online/game/game_schedule.dart';
import 'package:oberta/online/online_services.dart';
import 'package:oberta/ui/screens/online/online_game_screen.dart';
import 'package:oberta/ui/screens/online/online_room_screen.dart';
import 'package:oberta/ui/widgets/death_scene.dart';
import 'package:oberta/ui/widgets/flip_role_card.dart';
import 'package:oberta/ui/widgets/verdict_scene.dart';

import '../support/languages.dart';
import '../support/manual_clock.dart';

void _usePhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1179, 2556);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

Widget _app(Widget home) => appIn(AppLanguage.it, home);

/// Aspetta [future] facendo andare il tempo finto dei test.
Future<T> settled<T>(WidgetTester tester, Future<T> future) async {
  var done = false;
  late T value;
  future.then((v) {
    value = v;
    done = true;
  });
  for (var i = 0; i < 200 && !done; i++) {
    await tester.pump(const Duration(milliseconds: 1));
  }
  expect(done, isTrue, reason: 'la chiamata non finisce');
  return value;
}

/// Lascia arrivare le novità del server. Lo schermo della partita ha un
/// cronometro sempre acceso: niente pumpAndSettle.
Future<void> flush(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 1));
  }
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  test('i film online durano quanto dice il server', () {
    expect(DeathScene.length, OnlinePacing.deathFilm);
    expect(VerdictTake.molo.length, OnlinePacing.verdictFilm(condemns: true));
    expect(VerdictTake.assoluzione.length, OnlinePacing.verdictFilm(condemns: false));
  });

  testWidgets('la partita segue l\'orologio del server: carta, notte, e via fino alla fine', (tester) async {
    _usePhone(tester);
    final clock = ManualClock();
    final online = FakeOnline(accountId: 'bruno', clock: clock)
      ..signInReady(handle: 'bruno')
      ..addPlayer('anna', handle: 'anna');
    final room = online.openRoomAs('anna', AppLanguage.it);
    online.joinAs('bruno', room.code);
    await settled(tester, online.gameAs('anna').setBots(room.id, 3));
    await settled(tester, online.gameAs('anna').startGame(room.id));
    final me = await settled(tester, online.services.profiles.me());

    await tester.pumpWidget(_app(OnlineGameScreen(services: online.services, room: room, me: me, clock: clock)));
    await flush(tester);
    expect(find.byKey(const Key('online.card')), findsOneWidget);
    expect(find.byKey(const Key('online.countdown')), findsOneWidget);
    expect(find.text('LEGGETE AD ALTA VOCE'), findsNothing);

    // La carta si gira, poi «pronto»; quando conferma anche Anna, è notte.
    // La carta si guarda tenendola premuta.
    final hold = await tester.startGesture(tester.getCenter(find.byType(FlipRoleCard)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await hold.up();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.byKey(const Key('online.ready')));
    await flush(tester);
    await settled(tester, online.gameAs('anna').sendAck(room.id, 's1', 'reveal-1'));
    await flush(tester);
    clock.elapse(const Duration(seconds: 2));
    await flush(tester);
    expect(find.byKey(const Key('online.night')), findsOneWidget);

    // Da qui nessuno tocca niente: le scadenze mandano avanti la partita,
    // e i film partono da soli.
    final seen = <String>{};
    for (var i = 0; i < 600 && online.roomOf(room.id)!.status == RoomStatus.playing; i++) {
      for (final key in ['online.night', 'online.dawn', 'online.discussion', 'online.vote', 'online.verdict']) {
        if (find.byKey(Key(key)).evaluate().isNotEmpty) seen.add(key);
      }
      if (find.byType(DeathScene).evaluate().isNotEmpty) seen.add('film');
      clock.fireNext();
      await flush(tester);
    }
    await flush(tester);
    expect(seen, containsAll(['online.night', 'online.discussion', 'online.vote']));
    expect(online.roomOf(room.id)!.status, RoomStatus.lobby);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('nella stanza, chi aspetta si siede da solo quando la partita comincia', (tester) async {
    _usePhone(tester);
    final online = FakeOnline(accountId: 'bruno', clock: ManualClock())
      ..signInReady(handle: 'bruno')
      ..addPlayer('anna', handle: 'anna');
    final room = online.openRoomAs('anna', AppLanguage.it);
    online.joinAs('bruno', room.code);
    final me = await online.services.profiles.me();
    await tester.pumpWidget(_app(OnlineRoomScreen(services: online.services, room: room, me: me)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('online.waitingForHost')), findsOneWidget);
    expect(find.byKey(const Key('online.start')), findsNothing, reason: 'solo il padrone di casa dà le carte');

    await settled(tester, online.gameAs('anna').setBots(room.id, 2));
    await tester.pumpAndSettle();
    expect(find.text('bot.alfa'), findsOneWidget, reason: 'i bot si vedono da tutti');
    await settled(tester, online.gameAs('anna').startGame(room.id));
    await flush(tester);
    await flush(tester);
    expect(find.byType(OnlineGameScreen), findsOneWidget);
    expect(find.byKey(const Key('online.card')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('il padrone di casa dà le carte e gioca con la sua carta soltanto', (tester) async {
    _usePhone(tester);
    final host = FakeOnline(accountId: 'anna', clock: ManualClock())
      ..signInReady(handle: 'anna')
      ..addPlayer('bruno', handle: 'bruno');
    final mine = host.openRoomAs('anna', AppLanguage.it);
    host.joinAs('bruno', mine.code);
    final me = await host.services.profiles.me();
    await tester.pumpWidget(_app(OnlineRoomScreen(services: host.services, room: mine, me: me)));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.byKey(const Key('online.addBot')), 100, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const Key('online.addBot')));
    await flush(tester);
    await tester.tap(find.byKey(const Key('online.addBot')));
    await flush(tester);
    await tester.pumpAndSettle();
    expect(host.roomOf(mine.id)!.bots, 2);
    await tester.ensureVisible(find.byKey(const Key('online.start')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('online.start')));
    await flush(tester);
    await flush(tester);

    expect(find.byType(OnlineGameScreen), findsOneWidget);
    expect(find.byKey(const Key('online.card')), findsOneWidget);
    expect(host.roomOf(mine.id)!.status, RoomStatus.playing);
    expect(host.published, greaterThan(0), reason: 'il server ha dato le carte');
    await tester.pumpWidget(const SizedBox());
  });
}
