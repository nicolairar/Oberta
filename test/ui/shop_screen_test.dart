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

  String coins(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('shop.coins'))).data!;

  testWidgets('si prova davanti allo specchio, si compra, si indossa', (tester) async {
    online.award('me', coins: 1000);
    await open(tester);
    expect(find.text('LA BOTTEGA'), findsOneWidget);
    expect(find.text('IN VETRINA'), findsOneWidget);
    expect(coins(tester), '1000');

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
    expect(find.text('INDOSSA'), findsOneWidget);

    await tester.tap(find.byKey(const Key('shop.action')));
    await tester.pumpAndSettle();
    expect(online.profileOf('me')!.avatar['hat'], 'borsalino');
    expect(find.text('TOGLI'), findsOneWidget);
    expect(find.text('INDOSSATO'), findsWidgets);
  });

  testWidgets('senza monete il padrone non fa credito', (tester) async {
    online.award('me', coins: 300);
    await open(tester);
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
    await tester.tap(find.byKey(const Key('shop.tab.wardrobe')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('shop.slot.outfit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('shop.item.outfit.grey_flannel')), findsOneWidget);
    expect(find.byKey(const Key('shop.item.outfit.white_dinner')), findsNothing);
    expect(find.byKey(const Key('shop.item.outfit.charcoal_pinstripe')), findsOneWidget, reason: 'la base è di tutti');

    await tester.tap(find.byKey(const Key('shop.item.outfit.grey_flannel')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('shop.action')));
    await tester.pumpAndSettle();
    expect(online.profileOf('me')!.avatar['outfit'], 'grey_flannel');
  });
}
