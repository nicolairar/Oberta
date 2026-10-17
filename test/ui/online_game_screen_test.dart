import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/l10n/app_language.dart';
import 'package:oberta/online/fake_online.dart';
import 'package:oberta/online/game/game_authority.dart';
import 'package:oberta/online/online_services.dart';
import 'package:oberta/rules/game_engine.dart';
import 'package:oberta/rules/role.dart';
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

/// Come il narratore che legge fino in fondo: se il pulsante non c'è ancora,
/// prima si scorre il copione.
Future<void> tapLabel(WidgetTester tester, String label) async {
  for (var i = 0; i < 20 && find.text(label).evaluate().isEmpty; i++) {
    if (find.text('CONTINUA A LEGGERE').evaluate().isNotEmpty) {
      await tester.tap(find.text('CONTINUA A LEGGERE'));
    }
    await tester.pumpAndSettle();
  }
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

/// Aspetta [future] facendo andare il tempo finto dei test: le chiamate al
/// server finto si completano un giro alla volta.
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

/// Lascia arrivare le novità del server.
Future<void> flush(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 1));
  }
}

void main() {
  late FakeOnline online;
  late Room room;

  setUp(() {
    online = FakeOnline(accountId: 'bruno')
      ..signInReady(handle: 'bruno')
      ..addPlayer('anna', handle: 'anna');
    room = online.openRoomAs('anna', AppLanguage.it);
    online.joinAs('bruno', room.code);
  });

  testWidgets('dal telefono di chi non tiene la partita: la propria carta, la notte, il film, il voto', (tester) async {
    _usePhone(tester);
    final clock = ManualClock();
    await settled(tester, online.gameAs('anna').setBots(room.id, 2));
    final members = await settled(tester, online.services.rooms.watchMembers(room.id).first);
    final authority = await settled(tester, GameAuthority.start(
        backend: online.gameAs('anna'),
        roomId: room.id,
        members: members,
        bots: 2,
        language: AppLanguage.it,
        clock: clock,
        random: Random(3),
      ));
    addTearDown(authority.dispose);
    final me = (await online.services.profiles.me());
    final seat = authority.seating.seatOfProfile('bruno')!;
    final role = authority.engine.setup.roles.entries.firstWhere((e) => e.key.id == seat).value;
    final t = AppLanguage.it.strings;

    await tester.pumpWidget(_app(OnlineGameScreen(services: online.services, room: room, me: me, seating: Random(1))));
    await tester.pumpAndSettle();

    // La carta: solo la propria.
    expect(find.byKey(const Key('online.card')), findsOneWidget);
    final hold = await tester.startGesture(tester.getCenter(find.byType(FlipRoleCard)));
    await tester.pumpAndSettle();
    expect(find.text(t.role(role).label.toUpperCase()), findsOneWidget);
    for (final other in authority.engine.setup.roles.entries) {
      if (other.key.id == seat || other.value == role) continue;
      if (role.team == Team.mafia && other.value.team == Team.mafia) continue;
      expect(find.text(t.role(other.value).label.toUpperCase()), findsNothing, reason: 'la carta di un altro');
    }
    await hold.up();
    await tester.pumpAndSettle();
    await tapLabel(tester, 'HO VISTO');

    // La notte: il narratore, poi la propria mossa.
    await tapLabel(tester, 'COMINCIA LA NOTTE');
    expect(find.text('PASSO'), findsOneWidget);
    await tester.tap(find.byKey(const Key('online.pass')));
    await flush(tester);
    expect(find.byKey(const Key('online.waiting')), findsOneWidget);

    // I bot scelgono (e chi tiene la partita passa allo scadere).
    for (var i = 0; i < 6 && authority.engine.phase == GamePhase.night; i++) {
      clock.fireNext();
      await flush(tester);
    }
    if (authority.engine.phase == GamePhase.night) {
      clock.elapse(const Duration(minutes: 5));
      await flush(tester);
    }
    await tester.pump();
    await tester.pump();

    // L'alba: i filmati, poi la pagina; o la fine, se la notte ha deciso.
    final dawn = authority.engine.history.first;
    for (var film = 0; film < 3 && find.byType(DeathScene).evaluate().isNotEmpty; film++) {
      await tester.pump(DeathScene.length + const Duration(milliseconds: 100));
      await tester.pump();
      await tester.tap(find.text('AVANTI'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }
    await tester.pumpAndSettle();
    expect(find.text(dawn.nightVictims.isEmpty ? t.everyoneAlive : t.crimePage), findsOneWidget);
    if (authority.engine.phase == GamePhase.day) {
      await tapLabel(tester, 'APRI LA DISCUSSIONE');
      expect(find.byKey(const Key('online.vote')), findsOneWidget);
      if (authority.engine.isAlive(authority.seating.playerAt(seat))) {
        await tester.tap(find.byKey(const Key('online.abstain')));
        await flush(tester);
        expect(find.text('Ti sei astenuto'), findsOneWidget);
      }
      // Allo scadere il voto si chiude: il verdetto va in scena.
      clock.elapse(const Duration(minutes: 10));
      await flush(tester);
      expect(find.byType(VerdictScene), findsOneWidget);
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('nella stanza, chi aspetta si siede da solo quando la partita comincia', (tester) async {
    _usePhone(tester);
    final me = (await online.services.profiles.me());
    await tester.pumpWidget(_app(OnlineRoomScreen(services: online.services, room: room, me: me)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('online.waitingForHost')), findsOneWidget);
    expect(find.byKey(const Key('online.start')), findsNothing, reason: 'solo il padrone di casa dà le carte');
    expect(find.byKey(const Key('online.addBot')), findsNothing);

    await settled(tester, online.gameAs('anna').setBots(room.id, 2));
    await tester.pumpAndSettle();
    expect(find.text('bot.alfa'), findsOneWidget, reason: 'i bot si vedono da tutti');

    final members = await settled(tester, online.services.rooms.watchMembers(room.id).first);
    final authority = await settled(tester, GameAuthority.start(
        backend: online.gameAs('anna'),
        roomId: room.id,
        members: members,
        bots: 2,
        language: AppLanguage.it,
        clock: ManualClock(),
        random: Random(4),
      ));
    addTearDown(authority.dispose);
    await flush(tester);
    await tester.pumpAndSettle();
    expect(find.byType(OnlineGameScreen), findsOneWidget);
    expect(find.byKey(const Key('online.card')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('il padrone di casa mette i bot, dà le carte e gioca con la sua carta soltanto', (tester) async {
    _usePhone(tester);
    final host = FakeOnline(accountId: 'anna')
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
    await tester.pumpAndSettle();

    expect(find.byType(OnlineGameScreen), findsOneWidget);
    expect(find.byKey(const Key('online.card')), findsOneWidget);
    expect(host.roomOf(mine.id)!.status, RoomStatus.playing);
    expect(host.published, greaterThan(0), reason: 'il telefono del padrone di casa pubblica la partita');
    // Uscendo dalla partita la si ferma: l'autorità si spegne con la schermata.
    await tester.pumpWidget(const SizedBox());
  });
}
