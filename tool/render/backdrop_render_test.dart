// Fotogrammi di prova dei fondali e delle scenette, per guardarli senza
// telefono: `flutter test tool/render` scrive i PNG nella cartella OUT.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/ui/widgets/city_backdrop.dart';
import 'package:oberta/ui/widgets/sky_events.dart';

final out = Platform.environment['OUT'] ?? 'build/render';

Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 0.5);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$out/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

Widget stage(GlobalKey key, SceneMood mood, SkylineStyle style, {bool rain = false, List<SkyMoment> moments = const []}) =>
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: RepaintBoundary(
        key: key,
        child: Stack(fit: StackFit.expand, children: [
          CityBackdrop(mood: mood, style: style, rain: rain, child: const SizedBox()),
          if (moments.isNotEmpty) CustomPaint(painter: SkyEventsPainter(moments, dark: switch (mood) { SceneMood.night => 1.0, SceneMood.dusk => 0.66, SceneMood.dawn => 0.33, SceneMood.day => 0.0 })),
        ]),
      ),
    );

void main() {
  testWidgets('fondali', (tester) async {
    tester.view.physicalSize = const Size(786, 1704);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    for (final style in SkylineStyle.values) {
      for (final mood in SceneMood.values) {
        await tester.pumpWidget(stage(key, mood, style));
        await tester.pump(const Duration(seconds: 2));
        await capture(tester, key, 'sky_${style.name}_${mood.name}');
      }
    }
    for (final mood in [SceneMood.night, SceneMood.dawn, SceneMood.day]) {
      for (final event in SkyEvent.values) {
        await tester.pumpWidget(stage(key, mood, SkylineStyle.mediterranean, moments: [(event: event, t: 0.5, seed: 3)]));
        await tester.pump(const Duration(seconds: 2));
        await capture(tester, key, 'event_${mood.name}_${event.name}');
      }
    }
  });
}
