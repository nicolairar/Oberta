import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/l10n/app_language.dart';
import 'package:oberta/ui/widgets/city_backdrop.dart';
import 'package:oberta/ui/widgets/noir_avatar.dart';
import 'package:oberta/ui/widgets/particle_sprites.dart';
import 'package:oberta/ui/widgets/verdict_scene.dart';

final out = Platform.environment['OUT'] ?? 'build/render';

Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$out/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

/// I fotogrammi chiave di ogni film, intorno ai suoi colpi di scena.
const _times = <VerdictTake, List<double>>{
  VerdictTake.molo: [0.15, 0.30, 0.36, 0.38, 0.40, 0.55, 0.62, 0.65, 0.68, 0.70, 0.72, 0.78],
  VerdictTake.cartello: [0.15, 0.30, 0.44, 0.50, 0.56, 0.59, 0.61, 0.64, 0.70, 0.74, 0.80],
  VerdictTake.treno: [0.15, 0.24, 0.27, 0.30, 0.33, 0.45, 0.48, 0.55, 0.63, 0.70, 0.78],
  VerdictTake.cannone: [0.20, 0.27, 0.30, 0.34, 0.44, 0.50, 0.555, 0.565, 0.60, 0.70, 0.76, 0.79, 0.82],
  VerdictTake.assoluzione: [0.10, 0.25, 0.40, 0.47, 0.55, 0.62, 0.68, 0.76],
};

void main() {
  testWidgets('verdetti — fotogrammi chiave', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    final sprites = await tester.runAsync(() => ParticleSprites.shared);
    final strings = AppLanguage.it.strings;
    final only = Platform.environment['TAKE'];
    final extra = Platform.environment['TIMES'];
    for (final MapEntry(key: take, value: preset) in _times.entries) {
      if (only != null && only != take.name) continue;
      final times = extra == null ? preset : [for (final s in extra.split(',')) double.parse(s)];
      for (final time in times) {
        await tester.pumpWidget(
          MaterialApp(
            home: RepaintBoundary(
              key: key,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CityBackdrop(mood: SceneMood.dusk, style: SkylineStyle.metropolis, child: const SizedBox.expand()),
                  CustomPaint(
                    painter: VerdictScenePainter(
                      t: time,
                      take: take,
                      strings: strings,
                      hat: AvatarHead.fedora,
                      town: 'Palermo',
                      sprites: sprites,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pump();
        await capture(tester, key, 'verdict_${take.name}_${time.toStringAsFixed(3)}');
      }
    }
  });
}
