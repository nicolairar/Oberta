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
import 'package:oberta/rules/role.dart';
import 'package:oberta/ui/avatar/avatar_look.dart';
import 'package:oberta/ui/widgets/flip_role_card.dart';

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

/// How many frames of the card flip, after the face-down one.
const flipFrames = 14;

/// Tony's look as his profile wears it, set by [shootPlates].
late AvatarLook brotherLook;

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
/// (the dusk city the verdict film plays over) and `flip_00`…`flip_14`, the
/// role card turning over.
Future<Map<String, ui.Image>> shootPlates(WidgetTester tester) async {
  final plates = <String, ui.Image>{};
  final seed = int.tryParse(Platform.environment['SEED'] ?? '') ?? 16;
  final clock = ManualClock();
  // Tony, the brother, dresses first: the real shop and the real barber, so
  // his seat at the table wears exactly the look the promo paints big.
  final online = FakeOnline(accountId: 'tony', clock: clock, random: Random(seed))..signInReady(handle: 'tony', coins: 100000);
  for (final (item, tone) in [('hat.fedora', null), ('face.scar', 'olive'), ('outfit.charcoal_pinstripe', null), ('accessory.cigar', null)]) {
    await _settled(tester, online.shop.buy(item));
    await _settled(tester, online.shop.equip(item, tone: tone));
  }
  await _settled(tester, online.services.profiles.saveFace(
    const {'hair': 'slicked', 'presentation': 'man', 'shape': 'square', 'brows': 'angled', 'mouth': 'smirk'},
    tone: 'olive',
  ));
  // As when his profile arrives from the server: the table paints his seat
  // from what the app remembers he wears (WornLooks), and so does the promo.
  WornLooks.remember((await _settled(tester, online.services.profiles.me()))!);
  brotherLook = AvatarLook.of('tony');
  // Then the phone is yours: Bruno, on a test account of the fake backend.
  online.addPlayer('test-1', handle: 'bruno');
  await _settled(tester, online.services.auth.signOut());
  await _settled(tester, online.services.auth.signInWithTestAccount(email: 'bruno@promo.test', password: 'promo-only'));
  OnlineServices.instance = online.services;
  final room = online.openRoomAs('tony', AppLanguage.it);
  online.joinAs('test-1', room.code);
  await _settled(tester, online.gameAs('tony').setBots(room.id, 6));
  await _settled(tester, online.gameAs('tony').startGame(room.id));
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
        // The table before anyone votes, then again once the bots have.
        plates['day'] = await grab(tester);
        clock.elapse(const Duration(seconds: 10));
        await _flush(tester);
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

  // The game's own role card, turning over: one frame every 40 ms of its
  // 520 ms flip, while a finger holds it down.
  final card = GlobalKey();
  await tester.pumpWidget(
    _app(
      Center(
        child: RepaintBoundary(
          key: card,
          child: SizedBox(
            width: 380,
            height: 520,
            child: Center(
              child: Material(
                type: MaterialType.transparency,
                child: SizedBox(width: 300, child: FlipRoleCard(role: Role.mafioso)),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
  plates['flip_00'] = await grab(tester, key: card);
  final finger = await tester.startGesture(tester.getCenter(find.byType(FlipRoleCard)));
  for (var i = 1; i <= flipFrames; i++) {
    await tester.pump(const Duration(milliseconds: 40));
    plates['flip_${i.toString().padLeft(2, '0')}'] = await grab(tester, key: card);
  }
  await finger.up();
  await tester.pump(const Duration(seconds: 1));
  return plates;
}
