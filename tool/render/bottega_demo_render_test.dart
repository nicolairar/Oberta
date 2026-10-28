// Le due prove di disposizione della bottega su iPhone (393x852):
// `flutter test tool/render/bottega_demo_render_test.dart` scrive i PNG in OUT.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/l10n/app_language.dart';
import 'package:oberta/l10n/app_strings.dart';
import 'package:oberta/online/fake_online.dart';
import 'package:oberta/online/online_account.dart';
import 'package:oberta/ui/screens/shop/shop_screen.dart';
import 'package:oberta/ui/theme/app_theme.dart';

final out = Platform.environment['OUT'] ?? 'build/demo_bottega';

const _fonts = {
  'Georgia': ['Georgia.ttf', 'Georgia Bold.ttf', 'Georgia Italic.ttf'],
  'serif': ['Georgia.ttf', 'Georgia Bold.ttf'],
  'Courier': ['Courier New.ttf', 'Courier New Bold.ttf'],
};

Future<void> _loadFonts() async {
  const dir = '/System/Library/Fonts/Supplemental';
  for (final MapEntry(key: family, value: files) in _fonts.entries) {
    final loader = FontLoader(family);
    for (final file in files) {
      final f = File('$dir/$file');
      if (f.existsSync()) loader.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
    }
    await loader.load();
  }
  final material =
      '${Platform.environment['FLUTTER_ROOT'] ?? '/opt/homebrew/share/flutter'}'
      '/bin/cache/artifacts/material_fonts';
  for (final (family, files) in [
    ('MaterialIcons', ['MaterialIcons-Regular.otf']),
    ('Roboto', ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf', 'Roboto-Italic.ttf']),
  ]) {
    final loader = FontLoader(family);
    for (final file in files) {
      final f = File('$material/$file');
      if (f.existsSync()) loader.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
    }
    await loader.load();
  }
}

final _key = GlobalKey();

ThemeData _theme() {
  final theme = buildAppTheme();
  const label = WidgetStatePropertyAll(
    TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w700, letterSpacing: 1.6, fontSize: 14),
  );
  return theme.copyWith(
    textTheme: theme.textTheme.apply(fontFamily: 'Roboto'),
    elevatedButtonTheme: ElevatedButtonThemeData(style: theme.elevatedButtonTheme.style!.copyWith(textStyle: label)),
    outlinedButtonTheme: OutlinedButtonThemeData(style: theme.outlinedButtonTheme.style!.copyWith(textStyle: label)),
    textButtonTheme: const TextButtonThemeData(style: ButtonStyle(textStyle: label)),
  );
}

Future<void> _shot(WidgetTester tester, String name, double ratio) async {
  await tester.pump(const Duration(milliseconds: 400));
  await tester.runAsync(() async {
    final boundary = _key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: ratio);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$out/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

Future<OnlineAccount> _account(FakeOnline online, WidgetTester tester) async {
  await tester.runAsync(() async {
    await online.shop.buy('hat.borsalino');
    await online.shop.equip('hat.borsalino');
  });
  return OnlineAccount(online.services);
}

Widget _app(Widget home) => RepaintBoundary(
  key: _key,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: _theme(),
    locale: AppLanguage.it.locale,
    supportedLocales: AppLanguage.locales,
    localizationsDelegates: const [
      AppStrings.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    home: home,
  ),
);

void main() {
  tearDown(() => ShopScreen.debugDemo = null);

  for (final (name, layout) in [
    ('demo_a_mirror_top', ShopDemoLayout.mirrorTop),
    ('demo_b_fitting_room', ShopDemoLayout.fittingRoom),
  ]) {
    testWidgets(name, (tester) async {
      ShopScreen.debugDemo = layout;
      await tester.runAsync(_loadFonts);
      tester.view.physicalSize = const Size(393, 852) * 3;
      tester.view.devicePixelRatio = 3;
      tester.view.padding = const FakeViewPadding(top: 59 * 3, bottom: 34 * 3);
      addTearDown(tester.view.reset);
      final online = FakeOnline()..signInReady(handle: 'anna', coins: 3800);
      final account = await _account(online, tester);
      await tester.pumpWidget(_app(ShopScreen(account: account, shop: online.shop)));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.ensureVisible(find.byKey(const Key('shop.tab.tailoring')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const Key('shop.tab.tailoring')));
      await tester.pump(const Duration(milliseconds: 300));
      await _shot(tester, name, 2);
    });
  }
}
