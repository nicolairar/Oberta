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

  Future<void> tab(WidgetTester tester, String name) async {
    await tester.ensureVisible(find.byKey(Key('shop.tab.$name')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('shop.tab.$name')));
  }

  Future<void> show(WidgetTester tester, String key) async {
    await tester.scrollUntilVisible(
      find.byKey(Key(key)),
      300,
      scrollable: find.descendant(of: find.byKey(const Key('shop.grid')), matching: find.byType(Scrollable)).first,
    );
    await tester.pumpAndSettle();
  }

  String coins(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('shop.coins'))).data!;

  testWidgets('si prova davanti allo specchio, si compra, si indossa', (tester) async {
    online.award('me', coins: 1000);
    await open(tester);
    expect(find.text('LA BOTTEGA'), findsOneWidget);
    expect(find.text('IN VETRINA'), findsOneWidget);
    expect(coins(tester), '1000');

    await tab(tester, 'hats');
    await tester.pumpAndSettle();
    await show(tester, 'shop.item.hat.borsalino');
    await tester.tap(find.byKey(const Key('shop.item.hat.borsalino')));
    await tester.pumpAndSettle();
    expect(find.text('Borsalino · Raro'), findsOneWidget);
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
    await tester.tap(find.byKey(const Key('shop.tryOn.back')));
    await tester.pumpAndSettle();
    expect(find.text('INDOSSATO'), findsWidgets, reason: 'sulla fascia del pezzo, nello scaffale');
  });

  testWidgets('senza monete il padrone non fa credito', (tester) async {
    online.award('me', coins: 300);
    await open(tester);
    await tab(tester, 'hats');
    await tester.pumpAndSettle();
    await show(tester, 'shop.item.hat.topHat');
    await tester.tap(find.byKey(const Key('shop.item.hat.topHat')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('shop.action')));
    await tester.pumpAndSettle();
    expect(find.text('Ti mancano 400 monete.'), findsOneWidget);
    expect(find.byKey(const Key('shop.confirm')), findsNothing);
    expect(coins(tester), '300');
  });

  testWidgets('nel guardaroba c\'è solo quello che si possiede', (tester) async {
    online.award('me', coins: 1100);
    await online.shop.buy('outfit.grey_flannel');
    await open(tester);
    await tab(tester, 'wardrobe');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('shop.slot.outfit')));
    await tester.pumpAndSettle();
    await show(tester, 'shop.item.outfit.grey_flannel');
    expect(find.byKey(const Key('shop.item.outfit.grey_flannel')), findsOneWidget);
    expect(find.byKey(const Key('shop.item.outfit.white_dinner')), findsNothing);
    await show(tester, 'shop.item.outfit.charcoal_pinstripe');
    expect(find.byKey(const Key('shop.item.outfit.charcoal_pinstripe')), findsOneWidget, reason: 'la base è di tutti');
    await show(tester, 'shop.item.outfit.grey_flannel');

    await tester.tap(find.byKey(const Key('shop.item.outfit.grey_flannel')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('shop.action')));
    await tester.pumpAndSettle();
    expect(online.profileOf('me')!.avatar['outfit'], 'grey_flannel');
  });

  testWidgets('le firme sono insegne grandi: si apre una casa e si torna indietro', (tester) async {
    await open(tester);
    await tab(tester, 'brands');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('shop.brand.vaugirard')), findsOneWidget);
    await tester.tap(find.byKey(const Key('shop.brand.vaugirard')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('shop.item.outfit.vaugirard_travel')), findsOneWidget);
    await tester.tap(find.byKey(const Key('shop.opened.back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('shop.brand.arminio')), findsOneWidget);
  });

  testWidgets('i filtri: la classe e il portafoglio', (tester) async {
    online.award('me', coins: 400);
    await open(tester);
    await tab(tester, 'hats');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('shop.affordable')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('shop.affordable')));
    await tester.pumpAndSettle();
    expect(find.text('RARO'), findsNothing);
    expect(find.text('COMUNE'), findsWidgets);
    await tester.tap(find.byKey(const Key('shop.affordable')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('shop.rarity.raro')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('shop.rarity.raro')));
    await tester.pumpAndSettle();
    expect(find.text('COMUNE'), findsNothing);
    expect(find.byKey(const Key('shop.item.hat.borsalino')), findsOneWidget);
  });

  testWidgets('i pacchetti: lo sconto, i pezzi uno per uno, si compra tutto', (tester) async {
    online.award('me', coins: 2500);
    await open(tester);
    expect(find.byKey(const Key('shop.bundle.pirata')), findsOneWidget, reason: 'in vetrina, il completo che conviene');
    await tab(tester, 'bundles');
    await tester.pumpAndSettle();
    expect(find.text('RISPARMI IL 35%'), findsWidgets);
    await tester.tap(find.byKey(const Key('shop.bundle.detective')));
    await tester.pumpAndSettle();
    expect(find.text('Il Detective'), findsOneWidget);
    expect(find.text('3200'), findsOneWidget, reason: 'la somma dei pezzi, barrata');
    expect(find.text('1800'), findsOneWidget, reason: 'ogni pezzo col suo prezzo da solo');
    await tester.tap(find.byKey(const Key('shop.bundle.buy')));
    await tester.pumpAndSettle();
    expect(find.text('Comprare Il Detective?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('shop.confirm')));
    await tester.pumpAndSettle();
    expect(coins(tester), '420');
    expect(find.text('COMPLETO'), findsOneWidget);
    expect(online.shop.ownedBy('me'), containsAll(['outfit.trench_coat', 'accessory.pipe']));
  });
}
