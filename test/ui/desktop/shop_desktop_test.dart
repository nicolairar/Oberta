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

        // Un reparto: la griglia a sinistra, lo specchio grande a destra.
        await tester.tap(find.byKey(const Key('shop.tab.hats')));
        await desktopFrames(tester, 6);
        await tester.scrollUntilVisible(
          find.byKey(const Key('shop.item.hat.borsalino')),
          300,
          scrollable: find.descendant(of: find.byKey(const Key('shop.grid')), matching: find.byType(Scrollable)).first,
        );
        await tester.ensureVisible(find.byKey(const Key('shop.item.hat.borsalino')));
        await desktopFrames(tester, 4);
        await tester.tap(find.byKey(const Key('shop.item.hat.borsalino')));
        await desktopFrames(tester, 6);
        expect(find.byKey(const Key('shop.action')), findsOneWidget);
        await saveDesktopShot(tester, 'shop_hats_$label');

        // I pacchetti.
        await tester.tap(find.byKey(const Key('shop.tab.bundles')));
        await desktopFrames(tester, 6);
        await saveDesktopShot(tester, 'shop_bundles_$label');

        // Un pacchetto cliccato va nello specchio del bancone.
        await tester.tap(find.byKey(const Key('shop.bundle.padrino')));
        await desktopFrames(tester, 6);
        expect(find.byKey(const Key('shop.bundle.buy')), findsOneWidget);
        await saveDesktopShot(tester, 'shop_bundle_open_$label');

        // Le firme.
        await tester.tap(find.byKey(const Key('shop.tab.brands')));
        await desktopFrames(tester, 6);
        await saveDesktopShot(tester, 'shop_brands_$label');
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
