// La pagina «Statistiche» del fascicolo, sul telefono (393x852) e sul
// desktop (1920x1080). `flutter test tool/render/stats_render_test.dart`
// scrive i PNG in OUT.
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
import 'package:oberta/online/online_services.dart';
import 'package:oberta/rules/role.dart';
import 'package:oberta/ui/desktop/desktop_frame.dart';
import 'package:oberta/ui/desktop/desktop_platform.dart';
import 'package:oberta/settings/display_settings.dart';
import 'package:oberta/ui/screens/online/profile_sheet.dart';
import 'package:oberta/ui/theme/app_theme.dart';

final out = Platform.environment['OUT'] ?? 'build/render/stats';

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

FakeOnline _online() {
  final online = FakeOnline()..signInReady(handle: 'nicolai', level: 9, xp: 320, coins: 1850);
  MatchResult m(String role, String team, bool won,
          {bool ranked = false, bool test = false, bool survived = true, int? secs = 1260, bool abandoned = false, bool afk = false}) =>
      MatchResult(
        gameId: 'g',
        role: role,
        team: team,
        won: won,
        ranked: ranked,
        testMatch: test,
        survived: survived,
        abandoned: abandoned,
        afk: afk,
        durationSeconds: secs,
        xpGained: 40,
        levelBefore: 9,
        levelAfter: 9,
      );
  online.history['me'] = [
    m('cittadino', 'citizens', false, secs: null, survived: false),
    m('detective', 'citizens', true, secs: null),
    m('mafioso', 'mafia', true),
    m('mafioso', 'mafia', true, ranked: true, secs: 1500),
    m('medico', 'citizens', true, ranked: true),
    m('detective', 'citizens', true, secs: 980),
    m('fesso', 'neutral', false, survived: false),
    m('padrino', 'mafia', false, ranked: true, survived: false),
    m('cittadino', 'citizens', false, abandoned: true, survived: false, secs: 400),
    m('detective', 'citizens', true, test: true, secs: 600),
    m('sicario', 'neutral', true, test: true, secs: 700),
    m('cecchino', 'citizens', false, afk: true, survived: false),
    m('mafioso', 'mafia', true, ranked: true, secs: 1720),
    m('detective', 'citizens', false, test: true, secs: 500),
    m('sarto', 'mafia', true),
    m('cittadino', 'citizens', true),
  ];
  online.progress.stats['me'] = {
    'nights': 31, 'lynch_hits': 14, 'saves': 3, 'finds': 6, 'snipes': 2, 'kills': 9, 'framed': 4,
    'godfather_lynch': 1, 'wins_alive': 7, 'role_win:${Role.detective.name}': 3,
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

Widget _opener(OnlineAccount account) => Builder(
      builder: (context) => Scaffold(
        backgroundColor: const Color(0xFF15100C),
        body: Center(
          child: TextButton(
            onPressed: () => showProfileSheet(context, account: account, onShop: () {}, onSettings: () {}),
            child: const Text('go'),
          ),
        ),
      ),
    );

void main() {
  setUpAll(_loadFonts);

  for (final language in [AppLanguage.it, AppLanguage.en]) {
    testWidgets('statistiche telefono ${language.name}', (tester) async {
      addTearDown(tester.view.reset);
      tester.view.physicalSize = const Size(393, 852) * 3;
      tester.view.devicePixelRatio = 3;
      tester.view.padding = const FakeViewPadding(top: 59 * 3, bottom: 34 * 3);
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
      final online = _online();
      final account = OnlineAccount(online.services);
      await tester.pumpWidget(_app(_opener(account), language));
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await _shot(tester, 'phone_${language.name}_1_file', 2);
      await tester.tap(find.byKey(const Key('profile.tab.stats')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('stats.page')), findsOneWidget);
      await _shot(tester, 'phone_${language.name}_2_stats', 2);
      await tester.drag(find.byKey(const Key('stats.page')), const Offset(0, -520));
      await tester.pumpAndSettle();
      await _shot(tester, 'phone_${language.name}_3_roles', 2);
      await tester.drag(find.byKey(const Key('stats.page')), const Offset(0, -1400));
      await tester.pumpAndSettle();
      await _shot(tester, 'phone_${language.name}_4_feats', 2);
    });

    testWidgets('statistiche desktop ${language.name}', (tester) async {
      DesktopPlatform.debugOverride = true;
      addTearDown(() => DesktopPlatform.debugOverride = null);
      addTearDown(tester.view.reset);
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
      final online = _online();
      final account = OnlineAccount(online.services);
      await tester.pumpWidget(_app(_opener(account), language, desk: true));
      await tester.tap(find.text('go'));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.tap(find.byKey(const Key('profile.tab.stats')));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await _shot(tester, 'desktop_${language.name}_stats', 1);
      await tester.tap(find.byKey(const Key('stats.tests')));
      await tester.pump(const Duration(milliseconds: 400));
      await _shot(tester, 'desktop_${language.name}_stats_with_tests', 1);
    });
  }
}
