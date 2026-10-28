import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/main.dart';
import 'package:oberta/online/fake_online.dart';
import 'package:oberta/l10n/app_language.dart';
import 'package:oberta/online/online_services.dart';
import 'package:oberta/ui/screens/online/ranked_queue_screen.dart';
import 'package:oberta/ui/street/street_route.dart';
import 'package:oberta/ui/street/street_section.dart';
import 'package:oberta/ui/street/street_stage.dart';
import 'package:oberta/ui/widgets/baked.dart';
import 'package:oberta/ui/widgets/home_alley.dart';

import '../support/languages.dart';

/// La strada dei menu: l'insegna OBERTÀ mai coperta dalle insegne della
/// bottega e del barbiere, il volantino del tutorial sul lampione, e la
/// camminata verso un locale e indietro, saltabile con un tocco; la sala da
/// gioco della classificata con la sua porta; il ritorno più svelto.

void _phone(WidgetTester tester, Size size, double top, double bottom) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = FakeViewPadding(top: top, bottom: bottom);
  addTearDown(tester.view.reset);
}

void main() {
  late FakeOnline online;

  setUp(() {
    online = FakeOnline()..signInReady(handle: 'anna', coins: 120);
    OnlineServices.instance = online.services;
  });

  test('sui telefoni le insegne in alto non toccano mai le lettere di OBERTÀ', () {
    for (final (size, top, bottom) in const [
      (Size(375, 667), 20.0, 0.0),
      (Size(390, 844), 47.0, 34.0),
      (Size(393, 852), 59.0, 34.0),
      (Size(430, 932), 59.0, 34.0),
    ]) {
      final layout = HomeAlleyLayout(size, EdgeInsets.only(top: top, bottom: bottom));
      for (final sign in [layout.shop, layout.barber, layout.badge, layout.slot]) {
        expect(sign.bottom, lessThanOrEqualTo(layout.sign.top + 1), reason: '$size $sign');
      }
      expect(layout.shop.right, lessThanOrEqualTo(layout.barber.left), reason: '$size');
      expect(layout.badge.right, lessThanOrEqualTo(layout.shop.left), reason: '$size');
      expect(layout.barber.right, lessThanOrEqualTo(layout.slot.left), reason: '$size');
      expect(layout.tutorial, isNotNull, reason: '$size: il volantino del tutorial');
      expect(layout.tutorial!.left, greaterThanOrEqualTo(0));
      expect(layout.tutorial!.right, lessThanOrEqualTo(layout.mainPoster.left), reason: '$size');
    }
  });

  testWidgets('l\'uomo cammina fino alla bottega, entra, e torna indietro', (tester) async {
    _phone(tester, const Size(393, 852), 59, 34);
    await tester.pumpWidget(const ObertaApp());
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(const Key('home.tutorial')), findsOneWidget);

    await tester.tap(find.byKey(const Key('home.shopSign')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(StreetStage.walking.value, 1, reason: 'si è appena avviato');
    // A passo tranquillo: a metà del tempo è ancora per strada.
    for (var i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 60));
      expect(tester.takeException(), isNull);
    }
    expect(StreetStage.walking.value, 1, reason: 'a metà strada');
    for (var i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 80));
      expect(tester.takeException(), isNull);
    }
    await tester.pump(const Duration(milliseconds: 300));
    expect(StreetStage.walking.value, 0, reason: 'arrivato, entrato');
    expect(find.text('LA BOTTEGA'), findsWidgets);

    // Indietro: esce, si gira, cammina a sinistra; un tocco salta il resto.
    await tester.tap(find.byKey(const Key('shop.back')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(StreetStage.walking.value, 1);
    await tester.tapAt(const Offset(200, 400));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(StreetStage.walking.value, 0, reason: 'il tocco ha saltato la camminata');
    expect(find.text('LA BOTTEGA'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('un trascinamento dal bordo lasciato a metà non congela la bottega', (tester) async {
    _phone(tester, const Size(393, 852), 59, 34);
    await tester.pumpWidget(const ObertaApp());
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.byKey(const Key('home.shopSign')));
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(const Key('shop.dept.window')), findsOneWidget);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);

    // Si scorrono le insegne partendo dal bordo sinistro: il gesto del
    // «indietro» parte, la pagina si sposta appena, e lui lascia andare.
    final tabs = tester.getRect(find.byKey(const Key('shop.dept.window')));
    final drag = await tester.startGesture(Offset(6, tabs.center.dy));
    for (var i = 0; i < 6; i++) {
      await drag.moveBy(const Offset(8, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(navigator.userGestureInProgress, isTrue);
    await drag.up();
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(navigator.userGestureInProgress, isFalse, reason: 'il gesto si è chiuso: la pagina sente di nuovo i tocchi');
    expect(find.byKey(const Key('shop.dept.window')), findsOneWidget, reason: 'tornata al suo posto');

    // E risponde: un reparto si apre.
    await tester.tap(find.byKey(const Key('shop.dept.hats')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('shop.back')));
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(const Key('shop.dept.window')), findsNothing, reason: 'la targhetta riporta nel vicolo');
    await tester.pumpWidget(const SizedBox());
  });
  test('al ritorno la camminata va come prima, l\'uscita dalla porta è più svelta', () {
    final back = StreetTiming.back.inMilliseconds;
    expect(back, lessThan(2700), reason: 'prima erano 3 secondi');
    expect(back, greaterThan(2300));
    final curve = StreetTiming.backCurve;
    expect(curve.transform(0), 0);
    expect(curve.transform(1), 1);
    var last = 0.0;
    for (var i = 1; i <= 100; i++) {
      final t = curve.transform(i / 100);
      expect(t, greaterThan(last), reason: 'sempre avanti, senza salti');
      expect(t - last, lessThan(0.03), reason: 'senza salti');
      last = t;
    }
    // Il controller va da 1 a 0 a velocità costante: il tratto a piedi (da
    // quando è fuori dalla porta a casa) dura quanto prima, 0,64 × 3 s.
    var knee = 0.0;
    while (curve.transform(knee) < StreetTiming.arrive) {
      knee += 0.0005;
    }
    expect(knee * back, closeTo(0.64 * 3000, 5));
    // L'uscita (pannelli, porta, passo fuori) prende il 40% in meno.
    expect((1 - knee) * back, closeTo(0.36 * 3000 * 0.6, 5));
  });

  test('mentre si cammina le due pagine si toccano su pixel interi, sovrapposte di uno', () {
    for (final ratio in [1.0, 2.0, 3.0, 2.625]) {
      const width = 393.0;
      for (var i = 1; i < 100; i++) {
        final camera = i / 100 + 0.0037;
        final out = StreetTiming.leaving(width, camera, ratio) * ratio;
        final into = StreetTiming.arriving(width, camera, ratio) * ratio;
        expect(out, closeTo(out.roundToDouble(), 1e-6), reason: 'pagina di prima su un pixel intero ($ratio)');
        expect(into - out, closeTo(width * ratio - 1, 1e-6), reason: 'la nuova copre un pixel della vecchia ($ratio)');
      }
    }
    expect(StreetTiming.arriving(393, 1, 3), 0, reason: 'arrivati: la pagina è al suo posto');
    expect(StreetTiming.leaving(393, 0, 3), 0);
  });

  testWidgets('dal manifesto entra nella saletta: il quadro grande e le targhe larghe; e torna svelto', (tester) async {
    _phone(tester, const Size(393, 852), 59, 34);
    await tester.pumpWidget(const ObertaApp());
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.text('GIOCA\nCON AMICI'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(StreetStage.walking.value, 1, reason: 'cammina fino al caffè');
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(StreetStage.walking.value, 0);
    final painting = tester.getRect(find.byKey(const Key('online.painting')));
    final create = tester.getRect(find.byKey(const Key('online.create')));
    final join = tester.getRect(find.byKey(const Key('online.join')));
    final friends = tester.getRect(find.byKey(const Key('online.friends')));
    expect(painting.height, greaterThan(300), reason: 'il quadro è il protagonista');
    expect(painting.bottom, lessThan(create.top));
    for (final plate in [create, join, friends]) {
      expect(plate.width, greaterThan(340), reason: 'targhe larghe quanto la pagina');
      expect(plate.height, greaterThanOrEqualTo(52));
    }
    expect(join.top, greaterThan(create.bottom));
    expect(friends.top, greaterThan(join.bottom));
    expect(friends.bottom, lessThanOrEqualTo(852 - 34), reason: 'sopra la barra in basso');
    // Il quadro è fermo: un'immagine sola, rimessa a ogni fotogramma.
    final baked = tester.renderObject<RenderBaked>(find.descendant(of: find.byKey(const Key('online.painting')), matching: find.byType(Baked)));
    final image = baked.debugImage;
    expect(image, isNotNull);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(baked.debugImage, same(image));

    // Indietro: la porta e il passo fuori vanno svelti, la camminata no.
    await tester.tap(find.byKey(const Key('cafe.back')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1800));
    expect(StreetStage.walking.value, 1, reason: 'cammina ancora verso il vicolo');
    await tester.pump(const Duration(milliseconds: 900));
    expect(StreetStage.walking.value, 0, reason: 'a casa prima dei 3 secondi di una volta');
    expect(find.byKey(const Key('online.painting')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('la classificata: cammina fino alla sala da gioco, entra, e dentro c\'è il tavolo', (tester) async {
    _phone(tester, const Size(393, 852), 59, 34);
    final ranked = FakeOnline(accountId: 'anna')
      ..signInReady(handle: 'anna')
      ..slow = false;
    late StreetRoute<void> route;
    await tester.pumpWidget(appIn(
      AppLanguage.it,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () {
              route = StreetRoute.of<void>(context, StreetSection.ranked, (_) => RankedQueueScreen(services: ranked.services));
              Navigator.of(context).push(route);
            },
            child: const Text('vai'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('vai'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1500));
    expect(StreetStage.walking.value, 1, reason: 'per strada');
    expect(StreetStage.spotOf(route)?.door, isNotNull, reason: 'la sala ha la sua porta');
    for (var i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
    }
    expect(StreetStage.walking.value, 0, reason: 'entrato');
    expect(find.text('CLASSIFICATA'), findsWidgets);
    expect(find.byKey(const Key('ranked.start')), findsOneWidget, reason: 'il tavolo e «Siediti»');

    Navigator.of(tester.element(find.byKey(const Key('ranked.start')))).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2700));
    expect(StreetStage.walking.value, 0);
    expect(find.byKey(const Key('ranked.start')), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
