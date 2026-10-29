// The polling booth of the secret vote, before anything changes in the
// game: `flutter test tool/demo_seggio/demo_seggio_render_test.dart` writes
// docs/demo/seggio/{A,B,C}_phone.png (393x852 at 3x) and
// {A,B,C}_desktop.png (1920x1080). OUT=dir writes them elsewhere.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/l10n/app_language.dart';
import 'package:oberta/l10n/app_strings.dart';
import 'package:oberta/ui/desktop/desktop_canvas.dart';
import 'package:oberta/ui/theme/app_theme.dart';

import 'demo_seggio.dart';

final out = Platform.environment['OUT'] ?? 'docs/demo/seggio';

const _fonts = {
  'Georgia': ['Georgia.ttf', 'Georgia Bold.ttf', 'Georgia Italic.ttf', 'Georgia Bold Italic.ttf'],
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
  return theme.copyWith(textTheme: theme.textTheme.apply(fontFamily: 'Roboto'));
}

Future<void> _render(WidgetTester tester, Widget screen, Size size, double ratio, String name) async {
  tester.view.physicalSize = size * ratio;
  tester.view.devicePixelRatio = ratio;
  addTearDown(tester.view.reset);
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
        home: DefaultTextStyle(
          style: const TextStyle(fontFamily: 'Roboto'),
          child: Material(type: MaterialType.transparency, child: screen),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 600));
  expect(tester.takeException(), isNull, reason: name);
  await tester.runAsync(() async {
    final boundary = _key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: ratio);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$out/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  const phone = Size(393, 852);
  for (final look in BoothLook.values) {
    final letter = look.name.toUpperCase();
    testWidgets('$letter phone', (tester) async {
      await tester.runAsync(_loadFonts);
      await _render(tester, PollingBoothDemo(look: look), phone, 3, '${letter}_phone');
    });
    testWidgets('$letter desktop', (tester) async {
      await tester.runAsync(_loadFonts);
      await _render(
        tester,
        DesktopCanvas(child: PollingBoothDemo(look: look, desk: true)),
        DesktopCanvas.size,
        1,
        '${letter}_desktop',
      );
    });
  }
}
