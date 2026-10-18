// Fotogrammi della sala d'attesa della classificata, per guardarli senza telefono:
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
import 'package:oberta/ui/screens/online/ranked_queue_screen.dart';
import 'package:oberta/ui/theme/app_theme.dart';

import '../../test/support/manual_clock.dart';

final out = Platform.environment['OUT'] ?? 'build/render/ranked';

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
    final image = await boundary.toImage(pixelRatio: 1.5);
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

void main() {
  testWidgets('sala d\'attesa della classificata', (tester) async {
    await tester.runAsync(_loadFonts);
    tester.view.physicalSize = const Size(390, 1400) * 3;
    tester.view.devicePixelRatio = 3;
    final clock = ManualClock();
    final online = FakeOnline(accountId: 'bruno', clock: clock)..signInReady(handle: 'bruno');
    const names = ['rosa', 'tano', 'lilo', 'mimi', 'ciro', 'nina', 'toto', 'enzo', 'pina', 'sasa', 'lucia'];
    void arrive(int from, int to) {
      for (var i = from; i < to; i++) {
        online.addPlayer('p$i', handle: names[i]);
        online.rankedQueue['p$i'] = (AppLanguage.it, clock.now());
      }
      online.tickRanked();
    }

    arrive(0, 6);
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
        home: RankedQueueScreen(services: online.services),
      ),
    ));
    await _flush(tester);
    await tester.tap(find.byKey(const Key('ranked.start')));
    await _flush(tester);
    online.gameAs('p0').sendChat('ranked-1', ChatChannel.lobby, 'buonasera a tutti').ignore();
    await _flush(tester);
    await _shot(tester, '01_waiting');
    arrive(6, 11);
    await tester.pump(const Duration(seconds: 2));
    await _flush(tester);
    await _shot(tester, '02_full_countdown');
    online.rankedQueue.clear();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });
}
