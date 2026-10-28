import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/online/fake_online.dart';
import 'package:oberta/online/online_account.dart';
import 'package:oberta/online/online_models.dart';
import 'package:oberta/ui/screens/avatar/barber_mirror_screen.dart';
import 'package:oberta/ui/screens/shop/shop_screen.dart';

import '../../support/desktop_shots.dart';

void main() {
  for (final MapEntry(key: label, value: size) in desktopSizes.entries) {
    group('desktop $label', () {
      testWidgets('la bottega', (tester) async {
        await useDesktop(tester, size);
        WornLooks.clear();
        final online = FakeOnline()..signInReady(handle: 'anna', coins: 1200);
        final account = OnlineAccount(online.services);
        await shootDesktopPage(tester, 'shop_$label', (_) => ShopScreen(account: account, shop: online.shop));

        // Un reparto dalla colonna di sinistra; la ricerca stringe la vetrinetta.
        await tester.tap(find.byKey(const Key('shop.dept.hats')));
        await desktopFrames(tester, 6);
        await tester.enterText(find.byKey(const Key('shop.search')), 'borsa');
        await desktopFrames(tester, 6);
        expect(find.byKey(const Key('shop.item.hat.panama')), findsNothing);
        await tester.tap(find.byKey(const Key('shop.item.hat.borsalino')));
        await desktopFrames(tester, 6);
        expect(find.byKey(const Key('shop.action')), findsOneWidget);
        await saveDesktopShot(tester, 'shop_hats_$label');

        // La vetrina: i completi, e un pacchetto sul manichino.
        await tester.tap(find.byKey(const Key('shop.dept.window')));
        await desktopFrames(tester, 6);
        await tester.tap(find.byKey(const Key('shop.section.sets')));
        await desktopFrames(tester, 6);
        await tester.tap(find.byKey(const Key('shop.bundle.padrino')));
        await desktopFrames(tester, 6);
        expect(find.byKey(const Key('shop.bundle.buy')), findsOneWidget);
        await saveDesktopShot(tester, 'shop_bundle_open_$label');
        await tester.pumpWidget(const SizedBox());
      });

      testWidgets('lo specchio del barbiere', (tester) async {
        await useDesktop(tester, size);
        WornLooks.clear();
        final online = FakeOnline()..signInReady(handle: 'anna');
        final profile = await tester.runAsync(online.profiles.me);
        await shootDesktopPage(
          tester,
          'barber_ask_$label',
          (_) => BarberMirrorScreen(services: online.services, profile: profile!),
        );
        await tester.tap(find.byKey(const Key('mirror.present.woman')));
        await desktopFrames(tester, 8);
        await saveDesktopShot(tester, 'barber_$label');
        await tester.pumpWidget(const SizedBox());
      });
    });
  }
}
