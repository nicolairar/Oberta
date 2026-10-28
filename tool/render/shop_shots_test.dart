// Screenshots of the shop, one per department, phone and desktop:
// `flutter test tool/render/shop_shots_test.dart` writes
// build/shop_shots/<layout>_<dept>.png.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/online/fake_online.dart';
import 'package:oberta/online/online_account.dart';
import 'package:oberta/online/online_services.dart';
import 'package:oberta/ui/desktop/desktop_canvas.dart';
import 'package:oberta/ui/screens/shop/shop_screen.dart';

final out = Platform.environment['OUT'] ?? 'build/shop_shots';

Future<void> _shot(WidgetTester tester, GlobalKey key, String name) async {
  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$out/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  for (final desk in [false, true]) {
    testWidgets('shop shots ${desk ? 'desktop' : 'phone'}', (tester) async {
      WornLooks.clear();
      final online = FakeOnline()..signInReady(handle: 'anna');
      online.award('me', coins: 99999);
      tester.view.physicalSize = desk ? const Size(1600, 1000) : const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final key = GlobalKey();
      final account = OnlineAccount(online.services);
      Widget shop = ShopScreen(account: account, shop: online.shop);
      if (desk) shop = DesktopCanvas(child: shop);
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(home: shop),
        ),
      );
      await tester.pumpAndSettle();
      for (final dept in ShopDept.values) {
        await tester.ensureVisible(find.byKey(Key('shop.dept.${dept.name}')).first);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.byKey(Key('shop.dept.${dept.name}')).first);
        await tester.pump(const Duration(milliseconds: 600));
        await _shot(tester, key, '${desk ? 'desktop' : 'phone'}_${dept.name}');
        if (!desk) {
          await tester.drag(find.byKey(const Key('shop.dial')), const Offset(-200, 0));
          await tester.pump(const Duration(milliseconds: 600));
          await _shot(tester, key, 'phone_${dept.name}_turned');
        }
      }
    });
  }
}
