// Il fascicolo del giocatore e l'insegna della bottega nel vicolo.
// `flutter test tool/render/dossier_render_test.dart` scrive i PNG in OUT.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/l10n/app_language.dart';
import 'package:oberta/l10n/lobby_language.dart';
import 'package:oberta/l10n/app_strings.dart';
import 'package:oberta/online/fake_online.dart';
import 'package:oberta/online/online_services.dart';
import 'package:oberta/ui/screens/home_screen.dart';
import 'package:oberta/ui/theme/app_theme.dart';

final out = Platform.environment['OUT'] ?? 'build/render/dossier';

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

Future<void> _pump(WidgetTester tester, Size screen, double top, double bottom, OnlineServices? online, AppLanguage language) async {
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
        locale: language.locale,
        supportedLocales: AppLanguage.locales,
        localizationsDelegates: const [
          AppStrings.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
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
    'l': (Size(430, 932), 59.0, 34.0),
  };

  for (final MapEntry(key: phone, value: (size, top, bottom)) in phones.entries) {
    for (final lang in ['it', 'en']) {
      testWidgets('fascicolo $phone $lang', (tester) async {
        addTearDown(tester.view.reset);
        final online = FakeOnline()..addPlayer('bruno', handle: 'bruno');
        online.auth.googleAvailable = false;
        online
          ..signInReady(handle: 'nicolai')
          ..award('me', level: 7, xp: 210, coins: 1250)
          ..ratings[('me', LobbyLanguage.it)] = const Rating(40, 4);
        await _pump(tester, size, top, bottom, online.services, lang == 'en' ? AppLanguage.en : AppLanguage.it);
        await _shot(tester, '${phone}_${lang}_1_home');

        await tester.tap(find.byKey(const Key('home.badge')));
        await tester.pumpAndSettle();
        await _shot(tester, '${phone}_${lang}_2_dossier');

        online.award('me', xp: 300, coins: 1300);
        await tester.pumpAndSettle();
        await _shot(tester, '${phone}_${lang}_3_dossier_more_xp');

        await tester.drag(find.byKey(const Key('profile.dossier')), const Offset(0, -500));
        await tester.pumpAndSettle();
        await _shot(tester, '${phone}_${lang}_4_dossier_scrolled');
      });
    }
  }
}
