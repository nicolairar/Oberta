import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/l10n/app_strings.dart';
import 'package:oberta/ui/screens/online/game/seat_card.dart';
import 'package:oberta/l10n/app_language.dart';
import 'package:oberta/online/fake_online.dart';
import 'package:oberta/online/online_services.dart';
import 'package:oberta/narration/italian_pack.dart';
import 'package:oberta/rules/role.dart';
import 'package:oberta/ui/screens/online/game/saloon_table.dart';
import 'package:oberta/ui/screens/online/online_game_screen.dart';
import 'package:oberta/ui/widgets/noir_modal.dart';

import '../support/languages.dart';
import '../support/manual_clock.dart';
import 'online_game_screen_test.dart' show flush, settled;

void _usePhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(375, 667) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

/// Una partita di Bruno con il dado [seed], fino alla prima notte già
/// cominciata. Null se la partita non ci arriva.
Future<({FakeOnline online, Room room, ManualClock clock})?> _toTheNight(WidgetTester tester, int seed, {int bots = 5}) async {
  final clock = ManualClock();
  final online = FakeOnline(accountId: 'bruno', clock: clock, random: Random(seed))
    ..signInReady(handle: 'bruno')
    ..addPlayer('anna', handle: 'anna');
  final room = online.openRoomAs('anna', AppLanguage.it);
  online.joinAs('bruno', room.code);
  await settled(tester, online.gameAs('anna').setBots(room.id, bots));
  await settled(tester, online.gameAs('anna').startGame(room.id));
  final me = await settled(tester, online.services.profiles.me());
  await tester.pumpWidget(appIn(AppLanguage.it, OnlineGameScreen(services: online.services, room: room, me: me, clock: clock)));
  await flush(tester);
  for (var i = 0; i < 40 && find.byKey(const Key('online.night')).evaluate().isEmpty; i++) {
    clock.fireNext();
    await flush(tester);
  }
  if (find.byKey(const Key('online.night')).evaluate().isEmpty) return null;
  // Si aspetta l'inizio comune della notte.
  clock.elapse(const Duration(seconds: 2));
  await flush(tester);
  return (online: online, room: room, clock: clock);
}

/// I posti che adesso si possono toccare.
List<Element> _tappable() => [
  for (final row in find.descendant(of: find.byKey(const Key('online.night')), matching: find.byType(InkWell)).evaluate())
    if ((row.widget as InkWell).onTap != null && _choosable(row)) row,
];

String _status(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('online.moveRegistered'))).data!;


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
  testWidgets('di notte si tocca e la scelta parte subito; si cambia fino allo scadere, e resta segnata', (tester) async {
    _usePhone(tester);
    for (var seed = 1; seed < 30; seed++) {
      final game = await _toTheNight(tester, seed);
      if (game == null) continue;
      // L'indagine e lo scavo chiedono conferma: qui si prova una mossa dell'alba.
      if (find.text('Su chi vuoi indagare?').evaluate().isNotEmpty ||
          find.text('Quale fossa scavi stanotte?').evaluate().isNotEmpty) {
        await tester.pumpWidget(const SizedBox());
        continue;
      }
      expect(find.byKey(const Key('online.confirm')), findsNothing, reason: 'niente «conferma»: il tocco è la scelta');
      final seats = _tappable();
      expect(seats.length, greaterThanOrEqualTo(2));
      await tester.tap(find.byWidget(seats.first.widget));
      await tester.pump();
      expect(find.byKey(const Key('online.askImmediate')), findsNothing);
      expect(_status(tester), startsWith('Hai scelto'), reason: 'la scelta si vede subito');
      await flush(tester);
      final first = _status(tester);

      // Cambia idea: un altro posto.
      final other = _tappable().first;
      await tester.tap(find.byWidget(other.widget));
      await flush(tester);
      final second = _status(tester);
      expect(second, startsWith('Hai scelto'));
      expect(second, isNot(first), reason: 'conta l\'ultima scelta');
      expect(find.byKey(const Key('online.night')), findsOneWidget, reason: 'la notte non si chiude: si va a tempo');

      // E «passo» resta una scelta, anche lei da cambiare.
      await tester.tap(find.byKey(const Key('online.pass')));
      await flush(tester);
      expect(_status(tester), startsWith('Hai passato'));
      expect(tester.widget<NoirModalButton>(find.byKey(const Key('online.pass'))).action.onPressed, isNull);
      expect(_tappable(), isNotEmpty, reason: 'dopo il passo si può ancora scegliere');
      await tester.pumpWidget(const SizedBox());
      return;
    }
    fail('nessuna partita con una mossa dell\'alba');
  });

  testWidgets('l\'indagine chiede conferma, e dopo la risposta la scelta è chiusa', (tester) async {
    _usePhone(tester);
    for (var seed = 1; seed < 80; seed++) {
      final game = await _toTheNight(tester, seed);
      if (game == null) continue;
      if (find.text('Su chi vuoi indagare?').evaluate().isEmpty) {
        await tester.pumpWidget(const SizedBox());
        continue;
      }
      await tester.tap(find.byWidget(_tappable().first.widget));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('online.askImmediate')), findsOneWidget, reason: 'prima di indagare si chiede');

      // «Annulla»: non parte niente.
      await tester.tap(find.byKey(const Key('online.cancel')));
      await flush(tester);
      expect(find.byKey(const Key('online.askImmediate')), findsNothing);
      expect(find.byKey(const Key('online.moveRegistered')), findsNothing, reason: 'annullata, nessuna mossa');

      await tester.tap(find.byWidget(_tappable().first.widget));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const Key('online.confirm')));
      await flush(tester);
      expect(find.byKey(const Key('online.waiting')), findsOneWidget, reason: 'la risposta, sul panno');
      expect(find.text('LA TUA INDAGINE'), findsOneWidget);
      expect(_tappable(), isEmpty, reason: 'dopo la risposta non si cambia');
      await tester.pumpWidget(const SizedBox());
      return;
    }
    fail('nessuna partita con Bruno Commissario');
  });

  testWidgets('la famiglia vota toccando, e le mani restano sul tavolo tutta la notte', (tester) async {
    _usePhone(tester);
    for (var seed = 1; seed < 60; seed++) {
      final game = await _toTheNight(tester, seed);
      if (game == null) continue;
      if (find.text('Chi eliminate stanotte?').evaluate().isEmpty) {
        await tester.pumpWidget(const SizedBox());
        continue;
      }
      List<SeatHand> hands() => tester.widget<PointingHands>(find.byType(PointingHands)).hands;
      final before = hands().where((h) => h.mine).length;
      expect(before, 0);
      await tester.tap(find.byWidget(_tappable().first.widget));
      await tester.pump();
      expect(hands().where((h) => h.mine), hasLength(1), reason: 'la mano parte subito');
      // Passa il tempo (i complici bot votano): la mano resta fino alla fine.
      for (var i = 0; i < 6; i++) {
        game.clock.elapse(const Duration(seconds: 3));
        await flush(tester);
        if (find.byKey(const Key('online.night')).evaluate().isEmpty) break;
        expect(hands().where((h) => h.mine), hasLength(1), reason: 'la mano resta puntata');
        expect(find.byKey(const Key('online.pass')), findsOneWidget, reason: 'si può ancora cambiare');
      }
      await tester.pumpWidget(const SizedBox());
      return;
    }
    fail('nessuna partita con Bruno nella famiglia');
  });

  testWidgets('il Compare, come tutta la famiglia, ha il voto dell\'agguato e non la domanda di copertura', (tester) async {
    _usePhone(tester);
    final familyRoles = <Role>{};
    // Nove al tavolo: sotto i 9 la Famiglia non ha poteri (docs/ruoli.md, 2.2).
    for (var seed = 1; seed < 120 && !familyRoles.contains(Role.compare); seed++) {
      final game = await _toTheNight(tester, seed, bots: 7);
      if (game == null) continue;
      final frame = game.online.deliveries.lastWhere((d) => d.user == 'bruno' && d.feed.seat != null).feed.seat!;
      final role = Role.values.byName((frame.payload['view'] as Map)['role'] as String);
      // La Prostituta non vota l'agguato: ha la sua domanda.
      if (role.team != Team.mafia || !role.isKiller) {
        await tester.pumpWidget(const SizedBox());
        continue;
      }
      familyRoles.add(role);
      expect(find.text('Chi eliminate stanotte?'), findsOneWidget, reason: '$role, seed $seed');
      for (final decoy in italianPack.decoyPrompts) {
        expect(find.text(decoy), findsNothing, reason: '$role non è un Onesto: niente «$decoy»');
      }
      // Tocca: la sua mano va sul tavolo con quelle della famiglia.
      await tester.tap(find.byWidget(_tappable().first.widget));
      await tester.pump();
      expect(tester.widget<PointingHands>(find.byType(PointingHands)).hands.where((h) => h.mine), hasLength(1),
          reason: '$role vede la sua mano tra quelle della famiglia');
      await flush(tester);
      await tester.pumpWidget(const SizedBox());
    }
    expect(familyRoles, contains(Role.compare), reason: 'nessuna partita con Bruno Compare');
  });

  testWidgets('a face on the table that is not a choice opens the player sheet, never the role', (tester) async {
    _usePhone(tester);
    for (var seed = 1; seed < 40; seed++) {
      final game = await _toTheNight(tester, seed);
      if (game == null) continue;
      // Bruno chooses Anna; her face, already chosen, is no longer a choice.
      final pick = find.byWidgetPredicate((w) => w is SeatCard && w.name == 'anna' && w.selectable);
      if (pick.evaluate().isEmpty || find.text('Su chi vuoi indagare?').evaluate().isNotEmpty ||
          find.text('Quale fossa scavi stanotte?').evaluate().isNotEmpty) {
        await tester.pumpWidget(const SizedBox());
        continue;
      }
      await tester.tap(pick);
      await flush(tester);
      final anna = find.byWidgetPredicate((w) => w is SeatCard && w.name == 'anna' && !w.selectable);
      if (anna.evaluate().isEmpty) {
        await tester.pumpWidget(const SizedBox());
        continue;
      }
      final before = _status(tester);
      await tester.tap(anna);
      await flush(tester);
      expect(find.byKey(const Key('safety.actions')), findsOneWidget);
      expect(find.byKey(const Key('player.header')), findsOneWidget);
      expect(find.textContaining('Posto '), findsOneWidget, reason: 'the seat, as everyone sees it');
      expect(find.textContaining('Al tavolo'), findsOneWidget);
      for (final key in ['safety.profile', 'safety.muteChat', 'safety.block', 'safety.report']) {
        expect(find.byKey(Key(key)), findsOneWidget, reason: key);
      }
      final roleShown = AppStrings.of(tester.element(anna)).role;
      for (final role in Role.values) {
        expect(find.descendant(of: find.byKey(const Key('safety.actions')), matching: find.text(roleShown(role).label)), findsNothing,
            reason: 'the sheet never tells a role');
      }
      expect(_status(tester), before, reason: 'opening the sheet chose nothing');
      await tester.pumpWidget(const SizedBox());
      return;
    }
    fail('no night with a face that is not a choice');
  });
}
