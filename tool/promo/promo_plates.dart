// The real screens the promo cuts between, shot once at 1080×1920 from a
// bot game on the fake backend (as the App Store screenshots are).
import 'dart:io';
import 'dart:math' show Random;
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
import 'package:oberta/ui/screens/online/game/noir_role_card.dart';
import 'package:oberta/ui/screens/online/online_game_screen.dart';
import 'package:oberta/ui/theme/app_theme.dart';
import 'package:oberta/ui/widgets/city_backdrop.dart';
import 'package:oberta/ui/widgets/targa.dart';

import '../../test/support/manual_clock.dart';

/// The frame, in logical pixels, and its density: 405×720 × 8/3 = 1080×1920.
const logical = Size(405, 720);
const ratio = 1080 / 405;

const _fonts = {
  'Georgia': ['Georgia.ttf', 'Georgia Bold.ttf', 'Georgia Italic.ttf'],
  'serif': ['Georgia.ttf', 'Georgia Bold.ttf'],
  'Courier': ['Courier New.ttf', 'Courier New Bold.ttf'],
};

Future<void> loadFonts() async {
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

Future<ui.Image> grab(WidgetTester tester, {GlobalKey? key, double pixelRatio = ratio * 1.5}) async {
  late ui.Image image;
  await tester.runAsync(() async {
    final boundary = (key ?? _key).currentContext!.findRenderObject()! as RenderRepaintBoundary;
    image = await boundary.toImage(pixelRatio: pixelRatio);
  });
  return image;
}

Future<void> savePng(WidgetTester tester, ui.Image image, String path) async {
  await tester.runAsync(() async {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void setView(WidgetTester tester) {
  tester.view.physicalSize = logical * ratio;
  tester.view.devicePixelRatio = ratio;
  tester.view.padding = FakeViewPadding(top: 40 * ratio, bottom: 24 * ratio);
}

/// The plates by name: `night` (the family chat), `day` (the table with the
/// seat numbers), `vote` (the same table once the votes are in), `verdictSky`
/// (the dusk city the verdict film plays over) and the three mode plates.
Future<Map<String, ui.Image>> shootPlates(WidgetTester tester) async {
  final plates = <String, ui.Image>{};
  final seed = int.tryParse(Platform.environment['SEED'] ?? '') ?? 16;
  final clock = ManualClock();
  final online = FakeOnline(accountId: 'bruno', clock: clock, random: Random(seed))
    ..signInReady(handle: 'bruno')
    ..addPlayer('anna', handle: 'anna');
  OnlineServices.instance = online.services;
  final room = online.openRoomAs('anna', AppLanguage.it);
  online.joinAs('bruno', room.code);
  await _settled(tester, online.gameAs('anna').setBots(room.id, 6));
  await _settled(tester, online.gameAs('anna').startGame(room.id));
  final me = (await _settled(tester, online.services.profiles.me()))!;
  await tester.pumpWidget(
    _app(OnlineGameScreen(key: UniqueKey(), services: online.services, room: room, me: me, clock: clock)),
  );
  await _flush(tester);
  await tester.pump(const Duration(milliseconds: 900));
  await tester.pump(const Duration(milliseconds: 1800));
  await tester.pump(const Duration(seconds: 2));
  clock.elapse(const Duration(seconds: 2));
  await _flush(tester);
  final hold = await tester.startGesture(tester.getCenter(find.byType(NoirRoleCard)));
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
  await hold.up();
  await tester.pump(const Duration(milliseconds: 700));

  for (var i = 0; i < 300 && !plates.containsKey('vote') && online.roomOf(room.id)!.status == RoomStatus.playing; i++) {
    for (final name in ['night', 'vote']) {
      final key = Key('online.$name');
      final plate = name == 'vote' ? 'day' : name;
      if (plates.containsKey(plate) || find.byKey(key).evaluate().isEmpty) continue;
      clock.elapse(const Duration(seconds: 2));
      await _flush(tester);
      if (find.byKey(key).evaluate().isEmpty) continue;
      if (name == 'night') {
        for (final text in ['Il dottore è quello col cappello.', 'Stanotte tocca a lui.', 'Zitti al voto, mi raccomando.']) {
          await _settled(tester, online.services.game.sendChat(room.id, ChatChannel.family, text));
        }
        await _flush(tester);
        plates['night'] = await grab(tester);
      } else {
        clock.elapse(const Duration(seconds: 10));
        await _flush(tester);
        plates['day'] = await grab(tester);
        final seats = find.descendant(of: find.byKey(key), matching: find.byType(InkWell));
        final target = [for (final e in seats.evaluate()) if ((e.widget as InkWell).onTap != null) e].firstOrNull;
        if (target != null) {
          await tester.tap(find.byWidget(target.widget));
          await _flush(tester);
        }
        // The bots vote too: let the tally fill up.
        for (var k = 0; k < 6; k++) {
          clock.elapse(const Duration(seconds: 3));
          await _flush(tester);
        }
        plates['vote'] = await grab(tester);
      }
    }
    clock.fireNext();
    await _flush(tester);
  }
  OnlineServices.instance = null;

  // The dusk city behind the verdict film.
  await tester.pumpWidget(
    _app(CityBackdrop(mood: SceneMood.dusk, style: SkylineStyle.metropolis, child: const SizedBox.expand())),
  );
  await tester.pump(const Duration(milliseconds: 100));
  plates['verdictSky'] = await grab(tester);

  // The three mode plates, the game's own Targa buttons.
  final keys = {for (final m in ['amici', 'classificata', 'telefono']) m: GlobalKey()};
  const labels = {'amici': 'CON GLI AMICI', 'classificata': 'CLASSIFICATA', 'telefono': 'UN TELEFONO'};
  const icons = {'amici': Icons.groups, 'classificata': Icons.emoji_events, 'telefono': Icons.smartphone};
  await tester.pumpWidget(
    _app(
      Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final m in keys.keys)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: RepaintBoundary(
                    key: keys[m],
                    child: SizedBox(
                      width: 300,
                      child: TargaButton(
                        label: labels[m]!,
                        icon: icons[m],
                        onPressed: () {},
                        kind: m == 'classificata' ? TargaKind.primary : TargaKind.secondary,
                        height: 64,
                        expand: true,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
  for (final MapEntry(key: m, value: k) in keys.entries) {
    plates['targa_$m'] = await grab(tester, key: k, pixelRatio: ratio * 1.5);
  }
  return plates;
}
