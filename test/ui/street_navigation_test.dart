import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/main.dart';
import 'package:oberta/online/fake_online.dart';
import 'package:oberta/online/online_services.dart';
import 'package:oberta/ui/street/street_stage.dart';
import 'package:oberta/ui/widgets/home_alley.dart';

/// La strada dei menu: l'insegna OBERTÀ mai coperta dalle insegne della
/// bottega e del barbiere, il volantino del tutorial sul lampione, e la
/// camminata verso un locale e indietro, saltabile con un tocco.

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
    expect(StreetStage.walking.value, 1, reason: 'a metà strada');
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 60));
      expect(tester.takeException(), isNull);
    }
    await tester.pump(const Duration(milliseconds: 200));
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
}
