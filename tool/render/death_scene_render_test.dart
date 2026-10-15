import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/ui/widgets/city_backdrop.dart';
import 'package:oberta/ui/widgets/death_scene.dart';
import 'package:oberta/ui/widgets/particle_sprites.dart';

final out = Platform.environment['OUT'] ?? 'build/render';

Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$out/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  testWidgets('scene armi — fotogrammi chiave', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const acts = [
      DeathAct.knife,
      DeathAct.gun,
      DeathAct.burst,
      DeathAct.lupara,
      DeathAct.sniper,
    ];
    const times = [0.46, 0.53, 0.56, 0.59, 0.66];
    final key = GlobalKey();
    final sprites = await tester.runAsync(() => ParticleSprites.shared);
    for (final act in acts) {
      for (final time in times) {
        await tester.pumpWidget(
          MaterialApp(
            home: RepaintBoundary(
              key: key,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CityBackdrop(
                    style: SkylineStyle.metropolis,
                    rain: true,
                    child: const SizedBox.expand(),
                  ),
                  CustomPaint(
                    painter: DeathScenePainter(
                      t: time,
                      act: act,
                      sprites: sprites,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pump();
        await capture(
          tester,
          key,
          'death_${act.name}_${time.toStringAsFixed(2)}',
        );
      }
    }
  });
}
