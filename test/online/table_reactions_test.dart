import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/l10n/app_language.dart';
import 'package:oberta/online/fake_online.dart';
import 'package:oberta/online/online_services.dart';
import 'package:oberta/ui/screens/online/game/seat_card.dart';
import 'package:oberta/ui/screens/online/game/table_gestures.dart';
import 'package:oberta/ui/screens/online/online_game_screen.dart';

import '../support/languages.dart';
import '../support/manual_clock.dart';
import '../ui/online_game_screen_test.dart' show flush, settled;

Matcher _fails(OnlineFailure failure) =>
    throwsA(isA<OnlineException>().having((e) => e.failure, 'failure', failure));

void main() {
  group('i gesti, come li controlla il server', () {
    late FakeOnline online;
    late ManualClock clock;
    late Room room;

    setUp(() {
      clock = ManualClock();
      online = FakeOnline(accountId: 'anna', clock: clock)
        ..signInReady(handle: 'anna')
        ..addPlayer('bruno', handle: 'bruno');
      room = online.openRoomAs('anna', AppLanguage.it);
      online.joinAs('bruno', room.code);
    });

    test('nella stanza si lancia al posto di un altro, poi si aspetta', () async {
      final anna = online.reactionsAs('anna');
      expect(await anna.send(room.id, '2', TableGesture.cigar), isNotNull);
      await expectLater(anna.send(room.id, '2', TableGesture.toast), _fails(OnlineFailure.reactionCooldown));
      clock.elapse(ReactionRules.cooldown);
      expect(await anna.send(room.id, '2', TableGesture.toast), isNotNull);
      await expectLater(anna.send(room.id, '1', TableGesture.eye), _fails(OnlineFailure.reactionClosed), reason: 'non a sé stessi');
      final seen = await online.reactionsAs('bruno').watch(room.id).first;
      expect(seen.map((r) => r.gesture), [TableGesture.cigar, TableGesture.toast]);
    });

    test('i gesti a pagamento si comprano; chi li spegne o blocca non li riceve', () async {
      final bruno = online.reactionsAs('bruno');
      await expectLater(bruno.send(room.id, '1', TableGesture.horse), _fails(OnlineFailure.notOwned));
      await online.profiles.setTableReactions(false);
      expect(await bruno.send(room.id, '1', TableGesture.eye), isNull);
      await online.profiles.setTableReactions(true);
      online.blocks.add(('anna', 'bruno'));
      clock.elapse(ReactionRules.cooldown);
      expect(await bruno.send(room.id, '1', TableGesture.eye), isNull);
      expect(await online.reactionsAs('anna').watch(room.id).first, isEmpty);
    });

    test('di notte niente gesti', () async {
      await online.gameAs('anna').setBots(room.id, 3);
      await online.gameAs('anna').startGame(room.id);
      await expectLater(online.reactionsAs('anna').send(room.id, 's2', TableGesture.cigar), _fails(OnlineFailure.reactionClosed));
    });
  });

  /// Bruno al tavolo con Anna e tre bot, fino alla prima piazza da vivo.
  Future<Finder> toTheSquare(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final clock = ManualClock();
    final online = FakeOnline(accountId: 'bruno', clock: clock, random: Random(1))
      ..signInReady(handle: 'bruno')
      ..addPlayer('anna', handle: 'anna');
    final room = online.openRoomAs('anna', AppLanguage.it);
    online.joinAs('bruno', room.code);
    await settled(tester, online.gameAs('anna').setBots(room.id, 3));
    await settled(tester, online.gameAs('anna').startGame(room.id));
    final me = await settled(tester, online.services.profiles.me());
    await tester.pumpWidget(appIn(AppLanguage.it, OnlineGameScreen(services: online.services, room: room, me: me, clock: clock)));
    await flush(tester);

    Finder livingOther() => find.byWidgetPredicate((w) => w is SeatCard && !w.me && !w.fallen && w.onLongPress != null);
    var day = false;
    for (var i = 0; i < 400 && online.roomOf(room.id)!.status == RoomStatus.playing; i++) {
      if (find.byKey(const Key('online.discussion')).evaluate().isNotEmpty && livingOther().evaluate().isNotEmpty) {
        clock.elapse(const Duration(seconds: 2));
        await flush(tester);
        if (find.byKey(const Key('online.discussion')).evaluate().isNotEmpty) {
          day = true;
          break;
        }
      }
      clock.fireNext();
      await flush(tester);
    }
    expect(day, isTrue, reason: 'Bruno arriva vivo alla piazza');
    return livingOther();
  }

  testWidgets('di giorno, tenendo premuto un posto, il gesto vola sul tavolo', (tester) async {
    final livingOther = await toTheSquare(tester);
    await tester.longPress(livingOther.first);
    await flush(tester);
    expect(find.byKey(const Key('gestures.picker')), findsOneWidget);
    await tester.tap(find.byKey(const Key('gestures.cigar')));
    await flush(tester);
    final layer = tester.widget<GestureLayer>(find.byType(GestureLayer).first);
    expect(layer.flights.map((f) => f.gesture), [TableGesture.cigar]);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('di giorno il bottone «Gesti» resta in vista: prima a chi, poi quale gesto', (tester) async {
    await toTheSquare(tester);
    await tester.tap(find.byKey(const Key('gestures.button')));
    await flush(tester);
    expect(find.byKey(const Key('gestures.targets')), findsOneWidget);
    final target = find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('gestures.target-'));
    await tester.tap(target.first);
    await flush(tester);
    expect(find.byKey(const Key('gestures.picker')), findsOneWidget);
    await tester.tap(find.byKey(const Key('gestures.cigar')));
    await flush(tester);
    final layer = tester.widget<GestureLayer>(find.byType(GestureLayer).first);
    expect(layer.flights.map((f) => f.gesture), [TableGesture.cigar]);
    await tester.pumpWidget(const SizedBox());
  });
}
