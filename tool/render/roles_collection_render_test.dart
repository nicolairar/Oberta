// «I ruoli», la collezione delle carte, sul telefono (393x852) e sul
// desktop (1920x1080), con l'accesso e senza.
// `flutter test tool/render/roles_collection_render_test.dart` scrive i PNG
// in OUT.
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
import 'package:oberta/online/online_services.dart';
import 'package:oberta/rules/role.dart';
import 'package:oberta/ui/desktop/desktop_frame.dart';
import 'package:oberta/ui/desktop/desktop_platform.dart';
import 'package:oberta/settings/display_settings.dart';
import 'package:oberta/ui/screens/roles_screen.dart';
import 'package:oberta/ui/theme/app_theme.dart';

final out = Platform.environment['OUT'] ?? 'build/render/roles_collection';

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
  final material = '${Platform.environment['FLUTTER_ROOT'] ?? '/opt/homebrew/share/flutter'}'
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

Future<void> _shot(WidgetTester tester, String name, double ratio) async {
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      await precacheImage((element.widget as Image).image, element);
    }
  });
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

FakeOnline _online({bool signedIn = true}) {
  final online = FakeOnline();
  if (signedIn) online.signInReady(handle: 'nicolai', level: 9, xp: 320, coins: 1850);
  final at = DateTime(2026, 10, 26, 22, 40);
  RoleRecord r(Role role, int played, int wins, {int best = 1}) =>
      RoleRecord(role: role.name, played: played, wins: wins, bestStreak: best, streak: 0, lastPlayed: at, firstWin: wins > 0 ? at : null);
  online.progress.roles['me'] = {
    for (final rec in [
      r(Role.cittadino, 14, 6, best: 3),
      r(Role.detective, 9, 5, best: 2),
      r(Role.medico, 4, 2),
      r(Role.cecchino, 3, 0),
      r(Role.mafioso, 11, 7, best: 4),
      r(Role.padrino, 2, 1),
      r(Role.fesso, 2, 0),
      r(Role.sicario, 1, 1),
    ])
      rec.role: rec,
  };
  return online;
}

Widget _app(Widget home, AppLanguage language, {bool desk = false}) => RepaintBoundary(
      key: _key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        locale: language.locale,
        supportedLocales: AppLanguage.locales,
        localizationsDelegates: const [
          AppStrings.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        builder: desk ? (context, child) => DesktopFrame(orientation: DesktopOrientation.landscape, child: child!) : null,
        home: home,
      ),
    );

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void _phone(WidgetTester tester) {
  addTearDown(tester.view.reset);
  tester.view.physicalSize = const Size(393, 852) * 3;
  tester.view.devicePixelRatio = 3;
  tester.view.padding = const FakeViewPadding(top: 59 * 3, bottom: 34 * 3);
  tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
}

void main() {
  setUpAll(_loadFonts);

  for (final language in [AppLanguage.it, AppLanguage.en]) {
    testWidgets('ruoli telefono ${language.name}', (tester) async {
      _phone(tester);
      final online = _online();
      await tester.pumpWidget(_app(RolesScreen(services: online.services), language));
      await _settle(tester);
      expect(find.byKey(const Key('roles.count')), findsOneWidget);
      await _shot(tester, 'phone_${language.name}_1_grid', 2);
      if (language != AppLanguage.it) return;
      await tester.drag(find.byType(ListView), const Offset(0, -700));
      await _settle(tester);
      await _shot(tester, 'phone_${language.name}_2_grid_scrolled', 2);
      await tester.drag(find.byType(ListView), const Offset(0, 700));
      await _settle(tester);
      await tester.tap(find.byKey(const Key('roles.card.detective')));
      await _settle(tester);
      await _shot(tester, 'phone_${language.name}_3_unlocked', 2);
      await tester.tapAt(const Offset(20, 80));
      await _settle(tester);
      await tester.tap(find.byKey(const Key('roles.card.cecchino')));
      await _settle(tester);
      expect(find.byKey(const Key('roles.detail.locked')), findsOneWidget);
      await _shot(tester, 'phone_${language.name}_4_locked', 2);
    });
  }

  testWidgets('ruoli telefono senza accesso', (tester) async {
    _phone(tester);
    final online = _online(signedIn: false);
    await tester.pumpWidget(_app(RolesScreen(services: online.services), AppLanguage.it));
    await _settle(tester);
    expect(find.byKey(const Key('roles.signIn')), findsOneWidget);
    await _shot(tester, 'phone_it_5_signed_out', 2);
  });

  testWidgets('ruoli desktop', (tester) async {
    DesktopPlatform.debugOverride = true;
    addTearDown(() => DesktopPlatform.debugOverride = null);
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    final online = _online();
    await tester.pumpWidget(_app(RolesScreen(services: online.services), AppLanguage.it, desk: true));
    await _settle(tester);
    await _shot(tester, 'desktop_it_1_grid', 1);
    await tester.tap(find.byKey(const Key('roles.card.detective')));
    await _settle(tester);
    await _shot(tester, 'desktop_it_2_unlocked', 1);
  });
}
