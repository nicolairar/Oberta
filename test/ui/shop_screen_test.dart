import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/online/fake_online.dart';
import 'package:oberta/online/online_account.dart';
import 'package:oberta/online/online_services.dart';
import 'package:oberta/ui/screens/shop/shop_screen.dart';

void main() {
  late FakeOnline online;
  late OnlineAccount account;

  setUp(() {
    WornLooks.clear();
    online = FakeOnline()..signInReady(handle: 'anna');
  });

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    account = OnlineAccount(online.services);
    await tester.pumpWidget(
      MaterialApp(
        home: ShopScreen(account: account, shop: online.shop),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> dept(WidgetTester tester, String name) async {
    // Ten medallions: on the phone the row scrolls.
    await tester.ensureVisible(find.byKey(Key('shop.dept.$name')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('shop.dept.$name')));
    await tester.pumpAndSettle();
  }

  /// Turns the dial until [key] is on the rim and on screen, then taps it.
  Future<void> pick(WidgetTester tester, String key, {double step = -90}) async {
    for (var i = 0; i < 80; i++) {
      if (find.byKey(Key(key)).hitTestable().evaluate().isNotEmpty) {
        await tester.tap(find.byKey(Key(key)).hitTestable());
        await tester.pumpAndSettle();
        return;
      }
      await tester.drag(find.byKey(const Key('shop.dial')), Offset(step, 0));
      await tester.pumpAndSettle();
    }
    fail('$key never came round on the dial');
  }

  String tagName(WidgetTester tester) => tester
      .widgetList<Text>(find.descendant(of: find.byKey(const Key('shop.tag')), matching: find.byType(Text)))
      .first
      .data!;

  String coins(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('purse.coins'))).data!;

  testWidgets('un reparto dai medaglioni, la ruota, si compra, si indossa', (tester) async {
    online.award('me', coins: 1000);
    await open(tester);
    expect(find.text('LA BOTTEGA'), findsOneWidget);
    expect(find.byKey(const Key('shop.dept.window')), findsOneWidget);
    expect(coins(tester), '1.000');

    await dept(tester, 'hats');
    // Turning the dial puts another piece under the notch, and on the bust.
    final before = tagName(tester);
    await tester.drag(find.byKey(const Key('shop.dial')), const Offset(-120, 0));
    await tester.pumpAndSettle();
    expect(tagName(tester), isNot(before));

    await pick(tester, 'shop.item.hat.borsalino');
    expect(tagName(tester), 'Borsalino');
    expect(find.text('COMPRA'), findsOneWidget);

    await tester.tap(find.byKey(const Key('shop.action')));
    await tester.pumpAndSettle();
    expect(find.text('Comprare Borsalino?'), findsOneWidget);
    expect(find.text('Costa 700 monete. Te ne restano 300.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('shop.confirm')));
    await tester.pumpAndSettle();
    expect(coins(tester), '300');
    expect(account.profile!.coins, 300, reason: 'il cartellino del vicolo lo sa subito');
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('INDOSSA'), findsOneWidget);

    await tester.tap(find.byKey(const Key('shop.action')));
    await tester.pumpAndSettle();
    expect(online.profileOf('me')!.avatar['hat'], 'borsalino');
    expect(find.text('TOGLI'), findsOneWidget);
  });

  testWidgets('senza monete il padrone non fa credito', (tester) async {
    online.award('me', coins: 300);
    await open(tester);
    await dept(tester, 'hats');
    await pick(tester, 'shop.item.hat.topHat');
    await tester.tap(find.byKey(const Key('shop.action')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Ti mancano'), findsOneWidget);
    expect(find.byKey(const Key('shop.confirm')), findsNothing);
    expect(coins(tester), '300');
  });

  testWidgets('«Miei» lascia sulla ruota solo quello che si possiede', (tester) async {
    online.award('me', coins: 1100);
    await online.shop.buy('outfit.grey_flannel');
    await open(tester);
    await dept(tester, 'outfit');
    await tester.tap(find.byKey(const Key('shop.filter.mine')));
    await tester.pumpAndSettle();
    await pick(tester, 'shop.item.outfit.grey_flannel', step: 90);
    await tester.tap(find.byKey(const Key('shop.action')));
    await tester.pumpAndSettle();
    expect(online.profileOf('me')!.avatar['outfit'], 'grey_flannel');
    // Nothing for sale comes round: every piece left is owned or the house's.
    for (var i = 0; i < 6; i++) {
      expect(find.text('COMPRA'), findsNothing);
      await tester.drag(find.byKey(const Key('shop.dial')), const Offset(-100, 0));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('il foglio dei filtri: la classe', (tester) async {
    await open(tester);
    await dept(tester, 'hats');
    final all = tester.widget<Text>(find.byKey(const Key('shop.count'))).data!;
    await tester.tap(find.byKey(const Key('shop.filters')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('shop.rarity.raro')));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(20, 80));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const Key('shop.count'))).data, isNot(all));
    expect(find.text('RARO'), findsOneWidget, reason: 'il pezzo sotto la tacca è raro');
    await pick(tester, 'shop.item.hat.borsalino');
    expect(tagName(tester), 'Borsalino');
  });

  testWidgets('la vetrina: i completi, lo sconto, si compra tutto', (tester) async {
    online.award('me', coins: 2500);
    await open(tester);
    expect(find.byKey(const Key('shop.section.featured')), findsOneWidget, reason: 'i pezzi a tempo, con la data del server');
    await tester.tap(find.byKey(const Key('shop.section.sets')));
    await tester.pumpAndSettle();
    await pick(tester, 'shop.bundle.detective');
    expect(tagName(tester), 'Il Detective');
    expect(find.text('RISPARMI IL 35%'), findsOneWidget);
    await tester.tap(find.byKey(const Key('shop.bundle.buy')));
    await tester.pumpAndSettle();
    expect(find.text('Comprare Il Detective?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('shop.confirm')));
    await tester.pumpAndSettle();
    expect(coins(tester), '420');
    expect(find.text('COMPLETO'), findsOneWidget);
    expect(online.shop.ownedBy('me'), containsAll(['outfit.trench_coat', 'accessory.pipe']));
  });

  testWidgets('cornici e nomi si provano sulla carta del tavolo; il resto sul personaggio, a scelta', (tester) async {
    await open(tester);
    await dept(tester, 'frames');
    expect(find.byKey(const Key('shop.hero.seat')), findsOneWidget, reason: 'la cornice si vede sulla carta');
    expect(find.descendant(of: find.byKey(const Key('shop.hero.seat')), matching: find.byKey(const Key('seatPreview.plate'))), findsOneWidget);
    await tester.tap(find.byKey(const Key('shop.view.bust')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('shop.hero.seat')), findsNothing);

    await dept(tester, 'hats');
    expect(find.byKey(const Key('shop.hero.seat')), findsNothing);
    await tester.tap(find.byKey(const Key('shop.view.card')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('shop.hero.seat')), findsOneWidget, reason: 'anche un cappello si prova sulla carta');
  });
}
