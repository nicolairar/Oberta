// Chat demos for the online game, before anything changes in the live
// screen: `flutter test tool/demo_chat/demo_chat_render_test.dart` writes
// build/demo_chat/{a,b}_desk.png (1920x1080) and the phone frames
// (393x852 at 2x): a_phone, b_phone_closed, b_phone_open, b_phone_family.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/l10n/app_language.dart';
import 'package:oberta/l10n/app_strings.dart';
import 'package:oberta/ui/theme/app_theme.dart';

import 'demo_chat_layouts.dart';

final out = Platform.environment['OUT'] ?? 'build/demo_chat';

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
  await tester.pump();
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      await precacheImage((element.widget as Image).image, element);
    }
  });
  await tester.pump(const Duration(milliseconds: 600));
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
  const desk = Size(1920, 1080);
  const phone = Size(393, 852);
  setUpAll(() {});
  testWidgets('desk A', (tester) async {
    await tester.runAsync(_loadFonts);
    await _render(tester, const DeskA(), desk, 1, 'a_desk');
  });
  testWidgets('desk B', (tester) async {
    await tester.runAsync(_loadFonts);
    await _render(tester, const DeskB(), desk, 1, 'b_desk');
  });
  testWidgets('phone A', (tester) async {
    await tester.runAsync(_loadFonts);
    await _render(tester, const PhoneA(), phone, 2, 'a_phone');
  });
  testWidgets('phone B', (tester) async {
    await tester.runAsync(_loadFonts);
    await _render(tester, const PhoneB(), phone, 2, 'b_phone_closed');
    await _render(tester, const PhoneB(open: true), phone, 2, 'b_phone_open');
    await _render(tester, const PhoneB(open: true, family: true), phone, 2, 'b_phone_family');
  });
}
