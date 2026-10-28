// The live game at the vote with 12 seats, on the phone and on the 1080p
// desk, to check the vote marks on the seats and the chat (seat numbers,
// colours, separators, tabs): `flutter test tool/render/vote_chat_render_test.dart`
// writes build/render/vote_chat/{phone,desk}_vote.png. Bruno plays in the
// family, so the chat has both tabs.
import 'dart:io';
import 'dart:math';
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
import 'package:oberta/settings/display_settings.dart';
import 'package:oberta/ui/desktop/desktop_frame.dart';
import 'package:oberta/ui/desktop/desktop_platform.dart';
import 'package:oberta/ui/screens/online/online_game_screen.dart';
import 'package:oberta/ui/theme/app_theme.dart';

import '../../test/support/manual_clock.dart';

final out = Platform.environment['OUT'] ?? 'build/render/vote_chat';

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
  const label = WidgetStatePropertyAll(TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w700, letterSpacing: 1.6, fontSize: 14));
  return theme.copyWith(
    textTheme: theme.textTheme.apply(fontFamily: 'Roboto'),
    elevatedButtonTheme: ElevatedButtonThemeData(style: theme.elevatedButtonTheme.style!.copyWith(textStyle: label)),
    outlinedButtonTheme: OutlinedButtonThemeData(style: theme.outlinedButtonTheme.style!.copyWith(textStyle: label)),
    textButtonTheme: const TextButtonThemeData(style: ButtonStyle(textStyle: label)),
  );
}

Future<void> _flush(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 1));
  }
  await tester.pump(const Duration(milliseconds: 400));
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

/// A table of 12 where Bruno is in the family: the first seed that deals it.
Future<({FakeOnline online, Room room, ManualClock clock})> _table(WidgetTester tester) async {
  for (var seed = 1; seed < 80; seed++) {
    final clock = ManualClock();
    final online = FakeOnline(accountId: 'bruno', clock: clock, random: Random(seed))
      ..signInReady(handle: 'bruno')
      ..addPlayer('anna', handle: 'anna');
    final room = online.openRoomAs('anna', AppLanguage.it);
    online.joinAs('bruno', room.code);
    await _settled(tester, online.gameAs('anna').setBots(room.id, 10));
    await _settled(tester, online.gameAs('anna').startGame(room.id));
    final feed = await _settled(tester, online.services.game.watchGame(room.id).first);
    if ((feed.seat?.payload['view'] as Map?)?['team'] == 'mafia') return (online: online, room: room, clock: clock);
  }
  throw StateError('no seed puts Bruno in the family');
}

Future<void> _play(WidgetTester tester, {required bool desk}) async {
  await tester.runAsync(_loadFonts);
  final (:online, :room, :clock) = await _table(tester);
  final me = await _settled(tester, online.services.profiles.me());
  if (desk) {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = FakeViewPadding.zero;
  } else {
    tester.view.physicalSize = const Size(393, 852) * 3;
    tester.view.devicePixelRatio = 3;
    tester.view.padding = const FakeViewPadding(top: 47 * 3, bottom: 34 * 3);
    tester.view.viewPadding = const FakeViewPadding(top: 47 * 3, bottom: 34 * 3);
  }
  addTearDown(tester.view.reset);
  tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  await tester.pumpWidget(
    RepaintBoundary(
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
        builder: desk ? (context, child) => DesktopFrame(orientation: DesktopOrientation.landscape, child: child!) : null,
        home: OnlineGameScreen(services: online.services, room: room, me: me, clock: clock),
      ),
    ),
  );
  await tester.pump(const Duration(seconds: 4));
  var talked = false;
  for (var i = 0; i < 400 && find.byKey(const Key('online.vote')).evaluate().isEmpty; i++) {
    if (!talked && find.byKey(const Key('online.discussion')).evaluate().isNotEmpty) {
      talked = true;
      clock.elapse(const Duration(seconds: 2));
      await _flush(tester);
      for (final (game, text) in [
        (online.gameAs('anna'), 'Stanotte ho sentito dei passi vicino al porto.'),
        (online.services.game, "Chi era fuori a quell'ora?"),
        (online.gameAs('anna'), 'Il 2 non ha detto una parola. Strano, no?'),
        (online.services.game, 'Ascoltavo. Il 5 cambia versione ogni giro.'),
        (online.gameAs('anna'), 'Io voto 5, non ho altri nomi.'),
      ]) {
        await _settled(tester, game.sendChat(room.id, ChatChannel.day, text).then((_) => true, onError: (_) => false));
      }
      await _flush(tester);
    }
    clock.fireNext();
    await _flush(tester);
  }
  expect(find.byKey(const Key('online.vote')), findsOneWidget, reason: 'the vote opens');
  // The bots vote while the clock runs; then Bruno votes too.
  clock.elapse(const Duration(seconds: 12));
  await _flush(tester);
  final seats = find.descendant(of: find.byKey(const Key('online.vote')), matching: find.byType(InkWell));
  final target = [
    for (final e in seats.evaluate())
      if ((e.widget as InkWell).onTap != null) e,
  ].firstOrNull;
  if (target != null) {
    await tester.tap(find.byWidget(target.widget));
    await _flush(tester);
  }
  await _shot(tester, desk ? 'desk_vote' : 'phone_vote', desk ? 1 : 2);
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 5));
}

void main() {
  testWidgets('phone', (tester) => _play(tester, desk: false));
  testWidgets('desk', (tester) async {
    DesktopPlatform.debugOverride = true;
    addTearDown(() => DesktopPlatform.debugOverride = null);
    await _play(tester, desk: true);
  });
}
