// Fotogrammi del vicolo con l'account: fuori, col suggerimento, dentro.
// `flutter test tool/render/home_online_render_test.dart` scrive i PNG in OUT.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/online/fake_online.dart';
import 'package:oberta/online/online_services.dart';
import 'package:oberta/ui/screens/home_screen.dart';
import 'package:oberta/ui/theme/app_theme.dart';

final out = Platform.environment['OUT'] ?? 'build/render/home';

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

Future<void> _shot(WidgetTester tester, String name) async {
  await tester.pump(const Duration(milliseconds: 400));
  await tester.runAsync(() async {
    final boundary = _key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1.5);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$out/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

Future<void> _pump(WidgetTester tester, Size screen, double top, double bottom, OnlineServices? online) async {
  tester.view.physicalSize = screen * 3;
  tester.view.devicePixelRatio = 3;
  tester.view.padding = FakeViewPadding(top: top * 3, bottom: bottom * 3);
  tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
  OnlineServices.instance = online;
  await tester.pumpWidget(
    RepaintBoundary(
      key: _key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: _theme(),
        home: HomeScreen(onSettings: () {}),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(_loadFonts);
  const phones = {
    's': (Size(375, 667), 20.0, 0.0),
    'm': (Size(393, 852), 59.0, 34.0),
    'l': (Size(430, 932), 59.0, 34.0),
  };

  for (final MapEntry(key: phone, value: (size, top, bottom)) in phones.entries) {
    testWidgets('vicolo $phone', (tester) async {
      addTearDown(tester.view.reset);
      final online = FakeOnline()..addPlayer('bruno', handle: 'bruno');
      online.auth.googleAvailable = false;
      await _pump(tester, size, top, bottom, online.services);
      await _shot(tester, '${phone}_1_signed_out');

      await tester.tap(find.text('GIOCA\nCON AMICI'));
      await tester.pumpAndSettle();
      await _shot(tester, '${phone}_2_coach_mark');

      await tester.tap(find.text('ACCEDI'), warnIfMissed: false);
      await tester.pumpAndSettle();
      await _shot(tester, '${phone}_3_sign_in_sheet');

      online.auth.failNext = const OnlineException(
        OnlineFailure.appleDisabled,
        null,
        'validation_failed · 400 · Unsupported provider: provider is not enabled',
      );
      await tester.tap(find.text('Entra con Apple'));
      await tester.pumpAndSettle();
      await _shot(tester, '${phone}_4_sign_in_error');

      await tester.longPress(find.byKey(const Key('online.signInTitle')));
      await tester.pumpAndSettle();
      await _shot(tester, '${phone}_5_test_account');

      await tester.longPress(find.byKey(const Key('online.signInTitle')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Entra con Apple'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('online.handle')), 'Bruno');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      await _shot(tester, '${phone}_6_setup_taken');
      await tester.enterText(find.byKey(const Key('online.handle')), 'Nicolai');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      await _shot(tester, '${phone}_7_setup_free');
      online.award('me', level: 7, xp: 420, coins: 1250);
      await tester.tap(find.text('SALVA'));
      await tester.pumpAndSettle();
      await _shot(tester, '${phone}_8_signed_in');

      await tester.tap(find.byKey(const Key('home.badge')));
      await tester.pumpAndSettle();
      await _shot(tester, '${phone}_9_profile_sheet');
    });
  }
}
