// ignore_for_file: invalid_use_of_visible_for_testing_member
// Il tavolo pieno, al voto e al verdetto, su iPhone (393x852) con 6, 9 e 12
// posti, sul desktop a 1080p e nella mano di prova: per vedere che il testo
// sul panno, i pizzini, i timbri e le righe del coach non si coprono.
// `flutter test tool/render/table_fit_render_test.dart` scrive i PNG in OUT.
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
import 'package:oberta/tutorial/tutorial_story.dart';
import 'package:oberta/ui/desktop/desktop_frame.dart';
import 'package:oberta/ui/desktop/desktop_platform.dart';
import 'package:oberta/ui/screens/online/game/noir_role_card.dart';
import 'package:oberta/ui/screens/online/game/seat_card.dart';
import 'package:oberta/ui/screens/online/online_game_screen.dart';
import 'package:oberta/ui/screens/tutorial_screen.dart';
import 'package:oberta/ui/theme/app_theme.dart';
import 'package:oberta/ui/widgets/noir_modal.dart';

import '../../test/support/manual_clock.dart';

final out = Platform.environment['OUT'] ?? 'build/render/table_fit';

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

Future<void> _shot(WidgetTester tester, String name, {double ratio = 1.5}) async {
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

Widget _app(Widget home, {bool desk = false}) => RepaintBoundary(
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
    home: home,
  ),
);

void main() {
  for (final seats in [6, 9, 12]) {
    testWidgets('tavolo da $seats su iPhone', (tester) async {
      await tester.runAsync(_loadFonts);
      tester.view.physicalSize = const Size(393, 852) * 3;
      tester.view.devicePixelRatio = 3;
      tester.view.padding = const FakeViewPadding(top: 59 * 3, bottom: 34 * 3);
      addTearDown(tester.view.reset);
      await _game(tester, seats: seats, name: 'phone_$seats');
    });
  }

  testWidgets('tavolo da 12 sul desktop', (tester) async {
    await tester.runAsync(_loadFonts);
    DesktopPlatform.debugOverride = true;
    addTearDown(() => DesktopPlatform.debugOverride = null);
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = FakeViewPadding.zero;
    addTearDown(tester.view.reset);
    await _game(tester, seats: 12, name: 'desktop_12', desk: true);
  });

  testWidgets('la mano di prova, al verdetto del secondo giorno', (tester) async {
    await tester.runAsync(_loadFonts);
    tester.view.physicalSize = const Size(393, 852) * 3;
    tester.view.devicePixelRatio = 3;
    tester.view.padding = const FakeViewPadding(top: 59 * 3, bottom: 34 * 3);
    addTearDown(tester.view.reset);
    final settings = AppSettings(MemorySettingsStore());
    await tester.pumpWidget(_app(Builder(
      builder: (context) => Scaffold(
        body: TextButton(onPressed: () => TutorialScreen.open(context, settings: settings), child: const Text('go')),
      ),
    )));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('tutorial.story.${TutorialStory.city.id}')));
    await tester.pump(const Duration(milliseconds: 500));
    final shot = <String>{};
    for (var i = 0; i < 4000; i++) {
      await tester.pump(const Duration(milliseconds: 200));
      final table = TutorialScreen.lastTable!;
      final stage = table.stage;
      if (stage.startsWith('ended')) break;
      final line = table.coach.value?.line;
      if (stage.startsWith('verdict-') && line != null && !shot.contains(line)) {
        shot.add(line);
        await tester.pump(const Duration(seconds: 2));
        await _shot(tester, 'tutorial_verdict_${shot.length}');
        continue;
      }
      final reply = find.byKey(const Key('tutorial.reply.0'));
      if (reply.evaluate().isNotEmpty) {
        await tester.tap(reply);
        continue;
      }
      final ready = find.byKey(const Key('online.ready'));
      final waitingForChat = stage.startsWith('discussion') && table.replies.value.isNotEmpty;
      if (!waitingForChat && _enabled(tester, ready)) {
        await tester.tap(ready.last);
        continue;
      }
      if (stage.startsWith('reveal') && i % 10 == 5 && find.byType(NoirRoleCard).evaluate().isNotEmpty) {
        final hold = await tester.startGesture(tester.getCenter(find.byType(NoirRoleCard)));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        await hold.up();
        await tester.pump(const Duration(milliseconds: 600));
        continue;
      }
      if (stage.startsWith('night') || stage.startsWith('vote')) {
        if (table.replies.value.isNotEmpty) continue;
        final spot = table.coach.value?.spot;
        final seat = spot is ValueKey<String> && spot.value.startsWith('seat-') ? spot : const Key('seat-s2');
        final confirm = find.byKey(const Key('online.confirm'));
        if (_enabled(tester, confirm)) {
          await tester.tap(confirm.last);
          continue;
        }
        if (find.byKey(seat).evaluate().isNotEmpty && table.coach.value != null) {
          await tester.tap(find.byKey(seat).first, warnIfMissed: false);
        }
      }
    }
    if (shot.isEmpty) fail('never reached a verdict');
  });
}

bool _enabled(WidgetTester tester, Finder finder) {
  if (finder.evaluate().isEmpty) return false;
  final widget = tester.widget(finder.last);
  final onPressed = widget is NoirModalButton ? widget.action.onPressed : (widget as dynamic).onPressed;
  return onPressed != null;
}

Future<void> _game(WidgetTester tester, {required int seats, required String name, bool desk = false}) async {
  final clock = ManualClock();
  final online = FakeOnline(accountId: 'bruno', clock: clock)
    ..signInReady(handle: 'bruno')
    ..addPlayer('anna', handle: 'anna');
  final room = online.openRoomAs('anna', AppLanguage.it);
  online.joinAs('bruno', room.code);
  await _settled(tester, online.gameAs('anna').setBots(room.id, seats - 2));
  await _settled(tester, online.gameAs('anna').startGame(room.id));
  final me = await _settled(tester, online.services.profiles.me());
  await tester.pumpWidget(_app(OnlineGameScreen(services: online.services, room: room, me: me, clock: clock), desk: desk));
  await _flush(tester);
  await tester.pump(const Duration(seconds: 4));
  final ratio = desk ? 1.0 : 1.5;
  var voted = false;
  for (var i = 0; i < 400 && online.roomOf(room.id)!.status == RoomStatus.playing; i++) {
    if (!voted && find.byKey(const Key('online.vote')).evaluate().isNotEmpty) {
      // Si lascia votare quasi tutti, poi si vota anche noi.
      for (var s = 0; s < 6; s++) {
        clock.elapse(const Duration(seconds: 3));
        await _flush(tester);
      }
      // Il voto va al più accusato: così la piazza lincia qualcuno.
      final seats = [
        for (final e in find.byType(SeatCard).evaluate())
          if ((e.widget as SeatCard).selectable) e.widget as SeatCard,
      ]..sort((a, b) => b.votes.compareTo(a.votes));
      if (seats.isNotEmpty) {
        await tester.tap(find.byWidget(seats.first), warnIfMissed: false);
        await _flush(tester);
      }
      await _shot(tester, '${name}_vote', ratio: ratio);
      voted = true;
    }
    if (voted && find.byKey(const Key('online.ready')).evaluate().isNotEmpty && find.byKey(const Key('online.verdictHeadline')).evaluate().isNotEmpty) {
      clock.elapse(const Duration(seconds: 3));
      await _flush(tester);
      await tester.pump(const Duration(seconds: 2));
      await _shot(tester, '${name}_verdict', ratio: ratio);
      return;
    }
    clock.fireNext();
    await _flush(tester);
  }
  fail('no verdict');
}
