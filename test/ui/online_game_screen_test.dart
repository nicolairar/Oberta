import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/ui/screens/online/game/seat_card.dart';
import 'package:oberta/l10n/app_language.dart';
import 'package:oberta/l10n/lobby_language.dart';
import 'package:oberta/online/fake_online.dart';
import 'package:oberta/online/game/game_schedule.dart';
import 'package:oberta/online/online_services.dart';
import 'package:oberta/ui/screens/online/online_game_screen.dart';
import 'package:oberta/ui/screens/online/online_room_screen.dart';
import 'package:oberta/ui/widgets/death_scene.dart';
import 'package:oberta/ui/screens/online/game/noir_role_card.dart';
import 'package:oberta/ui/widgets/noir_modal.dart';
import 'package:oberta/ui/widgets/lynch_mark.dart';

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


/// Un posto che si sceglie (gli altri volti, toccati, aprono il foglio del
/// giocatore): niente SeatCard sopra, o una che si può scegliere.
bool _choosable(Element row) {
  SeatCard? card;
  row.visitAncestorElements((e) {
    if (e.widget is SeatCard) {
      card = e.widget as SeatCard;
      return false;
    }
    return true;
  });
  return card?.selectable ?? true;
}

void main() {
  test('i film online durano quanto dice il server', () {
    expect(DeathScene.length, OnlinePacing.deathFilm);
    expect(OnlinePacing.verdictFilm(condemns: true) >= LynchMark.length, isTrue,
        reason: 'il linciaggio sul tavolo finisce prima della fase');
  });

  testWidgets('la partita segue l\'orologio del server: carta, notte, e via fino alla fine', (tester) async {
    _usePhone(tester);
    final clock = ManualClock();
    final online = FakeOnline(accountId: 'bruno', clock: clock)
      ..signInReady(handle: 'bruno')
      ..addPlayer('anna', handle: 'anna');
    final room = online.openRoomAs('anna', LobbyLanguage.it);
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
    final hold = await tester.startGesture(tester.getCenter(find.byType(NoirRoleCard)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await hold.up();
    await tester.pump(const Duration(milliseconds: 600));
    // Prima dell'inizio comune non si conferma niente.
    expect(tester.widget<NoirModalButton>(find.byKey(const Key('online.ready'))).action.onPressed, isNull);
    clock.elapse(const Duration(seconds: 2));
    await flush(tester);
    await tester.tap(find.byKey(const Key('online.ready')));
    await flush(tester);
    expect(find.textContaining(RegExp('aspettiamo gli altri', caseSensitive: false)), findsOneWidget, reason: 'confermato: si aspettano gli altri, senza «registrato»');
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
    final room = online.openRoomAs('anna', LobbyLanguage.it);
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
      ..addPlayer('bruno', handle: 'bruno')
      // Il periodo di prova: in due si parte, i bot li mette il server.
      ..friendsTestBots = true
      ..friendsTestSize = 4;
    final mine = host.openRoomAs('anna', LobbyLanguage.it);
    host.joinAs('bruno', mine.code);
    final me = await host.services.profiles.me();
    await tester.pumpWidget(_app(OnlineRoomScreen(services: host.services, room: mine, me: me)));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('online.addBot')), findsNothing, reason: 'nessuno sceglie i bot');
    await tester.ensureVisible(find.byKey(const Key('online.start')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('online.start')));
    await flush(tester);
    await flush(tester);

    expect(find.byType(OnlineGameScreen), findsOneWidget);
    expect(find.byKey(const Key('online.card')), findsOneWidget);
    expect(host.roomOf(mine.id)!.status, RoomStatus.playing);
    expect(host.roomOf(mine.id)!.bots, 2, reason: 'il server ha riempito i posti vuoti');
    expect(host.published, greaterThan(0), reason: 'il server ha dato le carte');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('al voto i pizzini dicono chi accusa chi, e «registrato» arriva solo dal server', (tester) async {
    _usePhone(tester);
    final clock = ManualClock();
    final online = FakeOnline(accountId: 'bruno', clock: clock, random: Random(1))
      ..signInReady(handle: 'bruno')
      ..addPlayer('anna', handle: 'anna');
    final room = online.openRoomAs('anna', LobbyLanguage.it);
    online.joinAs('bruno', room.code);
    await settled(tester, online.gameAs('anna').setBots(room.id, 3));
    await settled(tester, online.gameAs('anna').startGame(room.id));
    final me = await settled(tester, online.services.profiles.me());
    await tester.pumpWidget(_app(OnlineGameScreen(services: online.services, room: room, me: me, clock: clock)));
    await flush(tester);

    // Le scadenze portano al voto; da vivo, Bruno ha la sua riga per votare.
    var voting = false;
    for (var i = 0; i < 400 && online.roomOf(room.id)!.status == RoomStatus.playing; i++) {
      if (find.byKey(const Key('online.vote')).evaluate().isNotEmpty &&
          find.byKey(const Key('online.abstain')).evaluate().isNotEmpty) {
        final start = clock.now();
        // Si aspetta l'inizio comune del voto.
        clock.elapse(const Duration(seconds: 2));
        await flush(tester);
        voting = clock.now().isAfter(start) && find.byKey(const Key('online.vote')).evaluate().isNotEmpty;
        if (voting) break;
      }
      clock.fireNext();
      await flush(tester);
    }
    expect(voting, isTrue, reason: 'Bruno arriva vivo al voto');

    final rows = find.descendant(of: find.byKey(const Key('online.vote')), matching: find.byType(InkWell));
    final target = [
      for (final row in rows.evaluate())
        if ((row.widget as InkWell).onTap != null && _choosable(row)) row,
    ].first;
    await tester.tap(find.byWidget(target.widget));
    await tester.pump();
    expect(find.byKey(const Key('online.myVote')), findsOneWidget, reason: 'il pizzino si vede subito, prima della risposta');
    expect(find.textContaining('Invio'), findsNothing, reason: 'niente «invio…»: si vede solo un errore');
    await flush(tester);
    expect(find.byKey(const Key('online.myVote')), findsOneWidget);
    expect(find.textContaining('registrato'), findsNothing);
    expect(find.byWidgetPredicate((w) => w.key is ValueKey<String> && '${w.key}'.contains('pizzino-')), findsWidgets,
        reason: 'il bollo di Bruno è sul tavolo di tutti');
    expect(find.byKey(const Key('seat.votes')), findsWidgets, reason: 'sull\'accusato, quanti voti ha');
    expect(find.text('1').evaluate().length + find.text('2').evaluate().length, greaterThan(0), reason: 'il bollo con i voti');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('chi sparisce risulta assente, poi lascia la città', (tester) async {
    _usePhone(tester);
    final clock = ManualClock();
    final online = FakeOnline(accountId: 'bruno', clock: clock)
      ..signInReady(handle: 'bruno')
      ..addPlayer('anna', handle: 'anna')
      ..trackPresence = true;
    final room = online.openRoomAs('anna', LobbyLanguage.it);
    online.joinAs('bruno', room.code);
    await settled(tester, online.gameAs('anna').setBots(room.id, 3));
    await settled(tester, online.gameAs('anna').startGame(room.id));
    final me = await settled(tester, online.services.profiles.me());
    await tester.pumpWidget(_app(OnlineGameScreen(services: online.services, room: room, me: me, clock: clock)));
    await flush(tester);

    // Anna non si fa più sentire; Bruno sì (il suo telefono bussa da solo).
    var announced = false;
    final start = clock.now();
    for (var i = 0; i < 400 && clock.now().difference(start) < const Duration(minutes: 3); i++) {
      if (find.text('anna esce di scena.').evaluate().isNotEmpty) {
        announced = true;
        break;
      }
      clock.fireNext();
      await flush(tester);
    }
    expect(announced, isTrue);
    expect(find.textContaining('Era '), findsNothing, reason: 'la carta di chi se ne va resta coperta');
    expect(find.byKey(const Key('online.youLookOffline')), findsNothing, reason: 'Bruno è collegato');
    expect(find.byKey(const Key('online.youLeftTown')), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  // QA P2-2: after an idle close the window stays at the last night, and
  // 12 s later "Il server non risponde… RIENTRA" sat on the closed table.
  testWidgets('una partita chiusa perché nessuno gioca più non chiede di rientrare', (tester) async {
    _usePhone(tester);
    final clock = ManualClock();
    final online = FakeOnline(accountId: 'bruno', clock: clock, pacing: const OnlinePacing(idleTimeouts: 1))
      ..signInReady(handle: 'bruno')
      ..addPlayer('anna', handle: 'anna');
    final room = online.openRoomAs('anna', LobbyLanguage.it);
    online.joinAs('bruno', room.code);
    await settled(tester, online.gameAs('anna').setBots(room.id, 3));
    await settled(tester, online.gameAs('anna').startGame(room.id));
    final me = await settled(tester, online.services.profiles.me());
    await tester.pumpWidget(_app(OnlineGameScreen(services: online.services, room: room, me: me, clock: clock)));
    await flush(tester);

    // Nessuno tocca il telefono: la notte scade a vuoto e il server chiude.
    for (var i = 0; i < 200 && find.byKey(const Key('online.closed')).evaluate().isEmpty; i++) {
      clock.fireNext();
      await flush(tester);
    }
    expect(find.byKey(const Key('online.closed')), findsOneWidget);
    clock.elapse(const Duration(seconds: 40));
    await flush(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const Key('online.closed')), findsOneWidget);
    expect(find.byKey(const Key('online.serverSilent')), findsNothing, reason: 'non c\'è un tavolo a cui rientrare');
    expect(find.byKey(const Key('online.reconnect')), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('chi esce dalla partita in corso ci rientra col pulsante, non da solo', (tester) async {
    _usePhone(tester);
    final online = FakeOnline(accountId: 'bruno', clock: ManualClock())
      ..signInReady(handle: 'bruno')
      ..addPlayer('anna', handle: 'anna');
    final room = online.openRoomAs('anna', LobbyLanguage.it);
    online.joinAs('bruno', room.code);
    await settled(tester, online.gameAs('anna').setBots(room.id, 3));
    await settled(tester, online.gameAs('anna').startGame(room.id));
    final me = await settled(tester, online.services.profiles.me());
    final playing = online.roomOf(room.id)!;
    await tester.pumpWidget(_app(OnlineRoomScreen(services: online.services, room: playing, me: me)));
    await flush(tester);
    await flush(tester);
    expect(find.byType(OnlineGameScreen), findsOneWidget, reason: 'chi entra in una stanza che gioca si siede');

    await tester.tap(find.byTooltip('Abbandona la partita'));
    await flush(tester);
    await tester.tap(find.text('ESCI'));
    await flush(tester);
    await flush(tester);
    expect(find.byType(OnlineGameScreen), findsNothing);
    expect(find.byKey(const Key('online.rejoinTable')), findsOneWidget);
    // While the game goes on the room is only the way back: no invite, no
    // closed lobby chat, no talk button; leaving the room is still there.
    expect(find.byKey(const Key('online.roomCode')), findsNothing);
    expect(find.byKey(const Key('online.lobbyChat')), findsNothing);
    expect(find.byKey(const Key('voice.talk')), findsNothing);
    expect(find.byKey(const Key('online.leave')), findsOneWidget);
    expect(find.text('La partita è in corso.'), findsOneWidget);

    await flush(tester);
    expect(find.byType(OnlineGameScreen), findsNothing, reason: 'non lo si rimette a sedere da solo');

    await tester.ensureVisible(find.byKey(const Key('online.rejoinTable')));
    await tester.tap(find.byKey(const Key('online.rejoinTable')));
    await flush(tester);
    await flush(tester);
    expect(find.byType(OnlineGameScreen), findsOneWidget);
    expect(find.byKey(const Key('online.card')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
