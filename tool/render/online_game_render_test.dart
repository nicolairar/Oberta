// Fotogrammi della partita online, per guardarli senza telefono:
// `flutter test tool/render/online_game_render_test.dart` scrive i PNG in OUT.
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
import 'package:oberta/ui/screens/online/game/noir_role_card.dart';
import 'package:oberta/ui/screens/online/online_game_screen.dart';
import 'package:oberta/ui/theme/app_theme.dart';

import '../../test/support/manual_clock.dart';

final out = Platform.environment['OUT'] ?? 'build/render/online';

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

Future<void> _shot(WidgetTester tester, String name, {bool settle = true}) async {
  if (settle) await tester.pump(const Duration(milliseconds: 400));
  await tester.runAsync(() async {
    final boundary = _key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: tester.view.devicePixelRatio > 2 ? 1.5 : 1);
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
  await tester.pump(const Duration(milliseconds: 300));
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

void main() {
  testWidgets('partita online', (tester) => _play(tester, bots: 6, prefix: ''));
  testWidgets('partita online a quindici', (tester) => _play(tester, bots: 13, prefix: 'big_', voteOnly: true));
}

Future<void> _play(WidgetTester tester, {required int bots, required String prefix, bool voteOnly = false}) async {
    await tester.runAsync(_loadFonts);
    final dims = (Platform.environment['SIZE'] ?? '390x844').split('x').map(double.parse).toList();
    final ratio = dims[0] > 600 ? 2.0 : 3.0;
    tester.view.physicalSize = Size(dims[0], dims[1]) * ratio;
    tester.view.devicePixelRatio = ratio;
    final clock = ManualClock();
    final online = FakeOnline(accountId: 'bruno', clock: clock)
      ..signInReady(handle: 'bruno')
      ..addPlayer('anna', handle: 'anna');
    final room = online.openRoomAs('anna', AppLanguage.it);
    online.joinAs('bruno', room.code);
    await _settled(tester, online.gameAs('anna').setBots(room.id, bots));
    await _settled(tester, online.gameAs('anna').startGame(room.id));
    final me = await _settled(tester, online.services.profiles.me());
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
        home: OnlineGameScreen(services: online.services, room: room, me: me, clock: clock),
      ),
    ));
    await _flush(tester);
    await tester.pump(const Duration(milliseconds: 900));
    await _shot(tester, '${prefix}00_arrival', settle: false);
    await tester.pump(const Duration(milliseconds: 1800));
    await _shot(tester, '${prefix}00_dealing');
    await tester.pump(const Duration(seconds: 2));
    clock.elapse(const Duration(seconds: 2));
    await _flush(tester);
    await _shot(tester, '${prefix}01_card_back');
    final hold = await tester.startGesture(tester.getCenter(find.byType(NoirRoleCard)));
    await tester.pump(const Duration(milliseconds: 700));
    await _shot(tester, '${prefix}02_card_face', settle: false);
    await hold.up();
    await tester.pump(const Duration(milliseconds: 700));
    final shot = <String>{};
    for (var i = 0; i < 300 && online.roomOf(room.id)!.status == RoomStatus.playing; i++) {
      for (final key in ['online.night', 'online.dawn', 'online.discussion', 'online.vote', 'online.verdict']) {
        final name = key.substring(7);
        if (shot.contains(name) || find.byKey(Key(key)).evaluate().isEmpty) continue;
        clock.elapse(const Duration(seconds: 2));
        await _flush(tester);
        if (find.byKey(Key(key)).evaluate().isEmpty) continue;
        shot.add(name);
        if (name == 'discussion') {
          for (final (game, text) in [
            (online.gameAs('anna'), 'Stanotte ho sentito dei passi vicino al porto.'),
            (online.services.game, "Chi era fuori a quell'ora?"),
          ]) {
            await _settled(tester, game.sendChat(room.id, ChatChannel.day, text).then((_) => true, onError: (_) => false));
          }
          await _flush(tester);
        }
        if (name == 'vote') {
          clock.elapse(const Duration(seconds: 10));
          await _flush(tester);
          final seats = find.descendant(of: find.byKey(const Key('online.vote')), matching: find.byType(InkWell));
          final target = [for (final e in seats.evaluate()) if ((e.widget as InkWell).onTap != null) e].firstOrNull;
          if (target != null) {
            await tester.tap(find.byWidget(target.widget));
            await _flush(tester);
          }
        }
        await _shot(tester, '${prefix}stage_${shot.length}_$name');
        if (voteOnly && name == 'vote') return;
      }
      clock.fireNext();
      await _flush(tester);
      if (find.byKey(const Key('online.end')).evaluate().isNotEmpty) break;
    }
    for (var i = 0; i < 400 && find.byKey(const Key('online.end')).evaluate().isEmpty; i++) {
      clock.fireNext();
      await _flush(tester);
    }
    clock.elapse(const Duration(seconds: 2));
    await _flush(tester);
    await _shot(tester, '${prefix}stage_9_end');
}
