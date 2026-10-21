// Fotogrammi del desktop (Mac/PC) dentro il riquadro 16:9 o 9:16 col letterbox:
// `flutter test tool/render/desktop_render_test.dart` scrive i PNG in OUT.
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
import 'package:oberta/settings/app_settings.dart';
import 'package:oberta/settings/display_settings.dart';
import 'package:oberta/settings/settings_store.dart';
import 'package:oberta/ui/desktop/desktop_frame.dart';
import 'package:oberta/ui/desktop/desktop_platform.dart';
import 'package:oberta/ui/screens/home_screen.dart';
import 'package:oberta/ui/screens/online/online_game_screen.dart';
import 'package:oberta/ui/screens/online/sign_in_sheet.dart';
import 'package:oberta/ui/screens/settings_screen.dart';
import 'package:oberta/ui/screens/online/ranked_queue_screen.dart';
import 'package:oberta/ui/theme/app_theme.dart';

import '../../test/support/manual_clock.dart';

final out = Platform.environment['OUT'] ?? 'build/render/desktop';

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

/// Il tema dell'app, con i caratteri caricati anche dove i test non li mettono.
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
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$out/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

Future<void> _flush(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 1));
  }
  await tester.pump(const Duration(milliseconds: 600));
}

Future<void> _app(WidgetTester tester, Size window, Widget home,
    {DesktopOrientation orientation = DesktopOrientation.landscape}) async {
  tester.view.physicalSize = window;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = FakeViewPadding.zero;
  tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
  await tester.pumpWidget(RepaintBoundary(
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
      builder: (context, child) => DesktopFrame(orientation: orientation, child: child!),
      home: home,
    ),
  ));
  await _flush(tester);
}

Future<T> _settled<T>(WidgetTester tester, Future<T> future) async {
  late T value;
  var done = false;
  future.then((v) {
    value = v;
    done = true;
  });
  for (var i = 0; i < 200 && !done; i++) {
    await tester.pump(const Duration(milliseconds: 1));
  }
  return value;
}

Future<void> _clear(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 5));
}

void main() {
  setUp(() => DesktopPlatform.debugOverride = true);
  tearDown(() => DesktopPlatform.debugOverride = null);

  testWidgets('home desktop', (tester) async {
    await tester.runAsync(_loadFonts);
    for (final (name, window, orientation, signedIn) in [
      ('00_home_1600x900', const Size(1600, 900), DesktopOrientation.landscape, true),
      ('01_home_ultrawide_2560x1080', const Size(2560, 1080), DesktopOrientation.landscape, false),
      ('02_home_portrait_1600x900', const Size(1600, 900), DesktopOrientation.portrait, true),
    ]) {
      final online = FakeOnline(accountId: 'bruno');
      if (signedIn) online.signInReady(handle: 'bruno', level: 4, coins: 320);
      OnlineServices.instance = online.services;
      await _app(tester, window, HomeScreen(onSettings: () {}), orientation: orientation);
      await tester.pump(const Duration(seconds: 4));
      await _shot(tester, name);
      await _clear(tester);
    }
    OnlineServices.instance = null;
  });

  testWidgets('accesso con Steam', (tester) async {
    await tester.runAsync(_loadFonts);
    final online = FakeOnline(accountId: 'bruno');
    online.auth
      ..steamAvailable = true
      ..appleAvailable = false
      ..googleAvailable = false;
    await _app(
      tester,
      const Size(1600, 900),
      Scaffold(
        backgroundColor: AppColors.surface,
        body: Center(
          child: SizedBox(width: 420, child: SignInPanel(auth: online.auth)),
        ),
      ),
    );
    await _shot(tester, '03_sign_in_steam');
    await _clear(tester);
  });

  testWidgets('impostazioni desktop', (tester) async {
    await tester.runAsync(_loadFonts);
    final online = FakeOnline(accountId: 'bruno')..signInReady(handle: 'bruno');
    final settings = AppSettings(MemorySettingsStore());
    await _app(tester, const Size(1600, 900),
        SettingsScreen(settings: settings, online: online.services, versionLabel: '1.0.0 (59)'));
    await _shot(tester, '04_settings');
    await tester.ensureVisible(find.byKey(const Key('settings.link')));
    await _flush(tester);
    await tester.tap(find.byKey(const Key('settings.link')));
    await _flush(tester);
    await tester.tap(find.byKey(const Key('link.make')));
    await _flush(tester);
    await _shot(tester, '05_link_code');
    await _clear(tester);
  });

  testWidgets('ingresso classificata desktop', (tester) async {
    await tester.runAsync(_loadFonts);
    final clock = ManualClock();
    final online = FakeOnline(accountId: 'bruno', clock: clock)..signInReady(handle: 'bruno');
    online.ratings[('bruno', AppLanguage.it)] = const Rating(33, 5);
    for (var i = 0; i < 24; i++) {
      online.rankedQueue['q$i'] = (AppLanguage.it, clock.now());
    }
    await _app(tester, const Size(1920, 1080), RankedQueueScreen(services: online.services));
    await _shot(tester, '06_ranked_entry_1920x1080');
    online.rankedQueue.clear();
    await _clear(tester);
  });

  testWidgets('partita desktop', (tester) async {
    await tester.runAsync(_loadFonts);
    for (final (name, window, orientation) in [
      ('07_game_wide_1600x900', const Size(1600, 900), DesktopOrientation.landscape),
      ('08_game_portrait_1600x900', const Size(1600, 900), DesktopOrientation.portrait),
      ('09_game_1920x1080', const Size(1920, 1080), DesktopOrientation.landscape),
    ]) {
      final clock = ManualClock();
      final online = FakeOnline(accountId: 'bruno', clock: clock)
        ..signInReady(handle: 'bruno')
        ..addPlayer('anna', handle: 'anna');
      final room = online.openRoomAs('anna', AppLanguage.it);
      online.joinAs('bruno', room.code);
      await _settled(tester, online.gameAs('anna').setBots(room.id, 10));
      await _settled(tester, online.gameAs('anna').startGame(room.id));
      final me = await _settled(tester, online.services.profiles.me());
      await _app(tester, window,
          OnlineGameScreen(services: online.services, room: room, me: me, clock: clock),
          orientation: orientation);
      await tester.pump(const Duration(seconds: 4));
      for (var i = 0; i < 60 && find.byKey(const Key('online.discussion')).evaluate().isEmpty; i++) {
        clock.fireNext();
        await _flush(tester);
      }
      clock.elapse(const Duration(seconds: 2));
      await _flush(tester);
      for (final (game, text) in [
        (online.gameAs('anna'), 'Stanotte ho sentito dei passi vicino al porto.'),
        (online.services.game, "Chi era fuori a quell'ora?"),
        (online.gameAs('anna'), 'Il 5 non ha detto una parola. Strano, no?'),
      ]) {
        await _settled(tester, game.sendChat(room.id, ChatChannel.day, text).then((_) => true, onError: (_) => false));
      }
      await _flush(tester);
      await _shot(tester, name);
      await _clear(tester);
    }
  });
}
