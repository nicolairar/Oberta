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
  testWidgets('scene della Famiglia — fotogrammi chiave', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final only = Platform.environment['ACTS'];
    final acts = [
      DeathAct.bowling,
      DeathAct.swordfish,
      DeathAct.harpoon,
      DeathAct.pie,
      DeathAct.trombone,
      DeathAct.tango,
      DeathAct.bouquet,
      DeathAct.laundry,
    ].where((a) => only == null || only.split(',').contains(a.name));
    final times =
        (Platform.environment['TIMES'] ??
                '0.30,0.40,0.45,0.48,0.50,0.52,0.54,0.555,0.565,0.58,0.60,0.63,0.66,0.70,0.74,0.80')
            .split(',')
            .map(double.parse);
    final key = GlobalKey();
    // NOSPRITES=1 controlla che le scene reggano anche senza sprite.
    final sprites = Platform.environment['NOSPRITES'] != null
        ? null
        : await tester.runAsync(() => ParticleSprites.shared);
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
          'death_${act.name}_${time.toStringAsFixed(3)}',
        );
      }
    }
  });
}
