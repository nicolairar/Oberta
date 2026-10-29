// Le prove delle feste sulle schermate vere: il vicolo, la strada (a metà
// della camminata verso il caffè degli amici), il tavolo da dodici di notte,
// sul telefono (393×852 @3x) e sul desktop (1920×1080). Il Natale: A «Natale
// in vicolo», B «Cenone della Famiglia», C «Natale di sangue». Halloween: A
// «Zucche nel vicolo», B «Notte dei morti», C «Nebbia e pipistrelli».
// `flutter test tool/render/season_render_test.dart` scrive i PNG in
// docs/demo/<festa>/; SEASON=natale,halloween, LOOK=A,B,C,none,
// DEVICE=phone,desktop e SCENE=alley,street,table per farne meno.
import 'dart:io';
import 'dart:math' show Random, min;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/l10n/app_language.dart';
import 'package:oberta/l10n/app_strings.dart';
import 'package:oberta/l10n/lobby_language.dart';
import 'package:oberta/online/fake_online.dart';
import 'package:oberta/online/online_services.dart';
import 'package:oberta/ui/desktop/desktop_frame.dart';
import 'package:oberta/ui/desktop/desktop_platform.dart';
import 'package:oberta/settings/display_settings.dart';
import 'package:oberta/ui/screens/home_screen.dart';
import 'package:oberta/ui/screens/online/online_game_screen.dart';
import 'package:oberta/ui/street/street_route.dart';
import 'package:oberta/ui/widgets/home_posters.dart';
import 'package:oberta/ui/season/season.dart';
import 'package:oberta/ui/theme/app_theme.dart';

import '../../test/support/manual_clock.dart';

final out = Platform.environment['OUT'] ?? 'docs/demo';

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

final _key = GlobalKey();

/// Le misure: il telefono di riferimento e lo schermo del PC.
typedef _Device = ({String name, Size size, double ratio, double top, double bottom, bool desk});

const _phone = (name: 'phone', size: Size(393, 852), ratio: 3.0, top: 59.0, bottom: 34.0, desk: false);
const _desktop = (name: 'desktop', size: Size(1920, 1080), ratio: 1.0, top: 0.0, bottom: 0.0, desk: true);

Widget _app(Widget home, SeasonLook? look, {required bool desk}) => RepaintBoundary(
  key: _key,
  child: SeasonScope(
    look: look,
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
      builder: desk ? (context, child) => DesktopFrame(orientation: DesktopOrientation.landscape, child: child!) : null,
      home: home,
    ),
  ),
);

void _view(WidgetTester tester, _Device d) {
  tester.view.physicalSize = d.size * d.ratio;
  tester.view.devicePixelRatio = d.ratio;
  tester.view.padding = FakeViewPadding(top: d.top * d.ratio, bottom: d.bottom * d.ratio);
}

Future<void> _flush(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 1));
  }
  await tester.pump(const Duration(milliseconds: 300));
}

Future<T?> _settled<T>(WidgetTester tester, Future<T> future) async {
  T? value;
  var done = false;
  future.then<void>((v) {
    value = v;
    done = true;
  }, onError: (Object _) {
    done = true;
  });
  for (var i = 0; i < 200 && !done; i++) {
    await tester.pump(const Duration(milliseconds: 1));
  }
  return value;
}

/// La lettera della prova: A, B, C nell'ordine in cui la festa le elenca.
String _prefix(SeasonLook? look) => switch (look) {
  null => 'base',
  final Enum look => 'ABC'[look.index],
  _ => '?',
};

Future<void> _shot(WidgetTester tester, _Device d, SeasonLook? look, String scene) async {
  await tester.pump(const Duration(milliseconds: 400));
  await tester.runAsync(() async {
    final boundary = _key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: d.ratio);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$out/${_season(look)}/${_prefix(look)}_${scene}_${d.name}.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

Future<void> _clear(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 5));
}

String _season(SeasonLook? look) => look?.season.name ?? Platform.environment['BASE'] ?? 'natale';

Set<String>? _only(String name) => Platform.environment[name]?.split(',').map((s) => s.trim()).toSet();

void main() {
  final looks = _only('LOOK');
  final devices = _only('DEVICE');
  final scenes = _only('SCENE');
  final seasons = _only('SEASON');
  for (final look in <SeasonLook?>[null, ...NataleLook.values, ...HalloweenLook.values]) {
    if (looks != null && !looks.contains(_prefix(look).replaceAll('base', 'none'))) continue;
    if (look != null && seasons != null && !seasons.contains(look.season.name)) continue;
    for (final d in [_phone, _desktop]) {
      if (devices != null && !devices.contains(d.name)) continue;
      testWidgets('${look?.key ?? 'base'} ${d.name}', (tester) async {
        await tester.runAsync(_loadFonts);
        addTearDown(tester.view.reset);
        addTearDown(() => OnlineServices.instance = null);
        if (d.desk) {
          DesktopPlatform.debugOverride = true;
          addTearDown(() => DesktopPlatform.debugOverride = null);
        }
        _view(tester, d);
        if (scenes == null || scenes.contains('alley')) await _alley(tester, d, look);
        if (scenes == null || scenes.contains('street')) await _street(tester, d, look);
        if (scenes == null || scenes.contains('table')) await _table(tester, d, look);
      });
    }
  }
}

/// Il vicolo di casa, fermo nel momento tranquillo del giro.
Future<void> _alley(WidgetTester tester, _Device d, SeasonLook? look) async {
  tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
  final online = FakeOnline(accountId: 'nicolai')..signInReady(handle: 'nicolai', level: 7, xp: 420, coins: 2400);
  OnlineServices.instance = online.services;
  await tester.pumpWidget(_app(HomeScreen(onSettings: () {}), look, desk: d.desk));
  await tester.pumpAndSettle();
  await _shot(tester, d, look, 'alley');
  await _clear(tester);
  tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
}

/// La strada: dal vicolo l'uomo si avvia verso il caffè degli amici, il
/// muro scorre, l'insegna AMICI si è appena accesa. Si ferma la camminata a
/// [walkAt] (la frazione della strada, da 0 a 1).
Future<void> _street(WidgetTester tester, _Device d, SeasonLook? look) async {
  final online = FakeOnline(accountId: 'nicolai')..signInReady(handle: 'nicolai', level: 7, xp: 420, coins: 2400);
  OnlineServices.instance = online.services;
  await tester.pumpWidget(_app(HomeScreen(onSettings: () {}), look, desk: d.desk));
  // Il vicolo si apre, poi si aspetta un momento senza lettere in corto.
  for (var i = 0; i < 16; i++) {
    await tester.pump(const Duration(milliseconds: 500));
  }
  await tester.tap(find.byType(HomeSoonPoster).first);
  await tester.pump();
  final at = double.tryParse(Platform.environment['WALK'] ?? '') ?? (d.desk ? 0.39 : 0.38);
  final total = StreetTiming.duration.inMilliseconds * at;
  for (var ms = 0.0; ms < total; ms += 100) {
    await tester.pump(Duration(milliseconds: min(100, (total - ms).round())));
  }
  await _shot(tester, d, look, 'street');
  await _clear(tester);
}

/// Il tavolo da dodici, la prima notte.
Future<void> _table(WidgetTester tester, _Device d, SeasonLook? look) async {
  final clock = ManualClock();
  final online = FakeOnline(accountId: 'bruno', clock: clock, random: Random(16))
    ..signInReady(handle: 'bruno')
    ..addPlayer('anna', handle: 'anna');
  final room = online.openRoomAs('anna', LobbyLanguage.it);
  online.joinAs('bruno', room.code);
  await _settled(tester, online.gameAs('anna').setBots(room.id, 10));
  await _settled(tester, online.gameAs('anna').startGame(room.id));
  final me = (await _settled(tester, online.services.profiles.me()))!;
  await tester.pumpWidget(
    _app(OnlineGameScreen(key: UniqueKey(), services: online.services, room: room, me: me, clock: clock, seating: Random(3)), look, desk: d.desk),
  );
  await _flush(tester);
  await tester.pump(const Duration(seconds: 4));
  for (var i = 0; i < 120 && find.byKey(const Key('online.night')).evaluate().isEmpty; i++) {
    clock.fireNext();
    await _flush(tester);
  }
  clock.elapse(const Duration(seconds: 2));
  await _flush(tester);
  await tester.pump(const Duration(seconds: 2));
  await _shot(tester, d, look, 'table');
  await _clear(tester);
}
