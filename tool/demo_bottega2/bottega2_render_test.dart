// Bottega, second round of demos: three new shop structures on iPhone
// (393x852) and the strongest on a 1920x1080 desktop, with the cartoon-noir
// busts. `flutter test tool/demo_bottega2/bottega2_render_test.dart` writes
// build/demo_bottega2/*.png. Nothing here is part of the game.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/ui/theme/app_theme.dart';

import 'concept_ruota.dart';
import 'concept_slots.dart';
import 'concept_vetrina.dart';
import 'desktop_slots.dart';

final out = Platform.environment['OUT'] ?? 'build/demo_bottega2';

Future<void> _loadFonts() async {
  const dir = '/System/Library/Fonts/Supplemental';
  const fonts = {
    'Georgia': ['Georgia.ttf', 'Georgia Bold.ttf', 'Georgia Italic.ttf'],
    'serif': ['Georgia.ttf', 'Georgia Bold.ttf'],
  };
  for (final MapEntry(key: family, value: files) in fonts.entries) {
    final loader = FontLoader(family);
    for (final file in files) {
      final f = File('$dir/$file');
      if (f.existsSync()) loader.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
    }
    await loader.load();
  }
  final material = '${Platform.environment['FLUTTER_ROOT'] ?? '/opt/homebrew/share/flutter'}/bin/cache/artifacts/material_fonts';
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

Widget _app(Widget home) {
  final theme = buildAppTheme();
  return RepaintBoundary(
    key: _key,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme.copyWith(textTheme: theme.textTheme.apply(fontFamily: 'Roboto')),
      home: DefaultTextStyle(style: const TextStyle(fontFamily: 'Roboto'), child: home),
    ),
  );
}

Future<void> _shot(WidgetTester tester, String name, double ratio) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
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
  final phones = <String, Widget>{
    '1_manichino_iphone': const SlotsConcept(),
    '2_vetrina_iphone': const VetrinaConcept(),
    '3_ruota_iphone': const RuotaConcept(),
  };
  for (final MapEntry(key: name, value: concept) in phones.entries) {
    testWidgets('bottega2 $name', (tester) async {
      await tester.runAsync(_loadFonts);
      tester.view.physicalSize = const Size(393, 852) * 3;
      tester.view.devicePixelRatio = 3;
      tester.view.padding = const FakeViewPadding(top: 59 * 3, bottom: 34 * 3);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(concept));
      await _shot(tester, name, 2);
    });
  }

  testWidgets('bottega2 desktop', (tester) async {
    await tester.runAsync(_loadFonts);
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = FakeViewPadding.zero;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(const SlotsDesktop()));
    await _shot(tester, '1_manichino_desktop', 1);
  });
}
