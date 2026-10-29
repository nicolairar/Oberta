import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/ui/widgets/city_backdrop.dart';
import 'package:oberta/ui/widgets/death_scene.dart';
import 'package:oberta/ui/widgets/particle_sprites.dart';

import 'comic_font.dart';

/// Renders the key frames of a group of night films, for contact sheets.
/// `OUT` is the output folder, `ACTS` an optional comma list of act names.
final out = Platform.environment['OUT'] ?? 'build/render';
final only = (Platform.environment['ACTS'] ?? '')
    .split(',')
    .where((name) => name.isNotEmpty)
    .toSet();

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
  testWidgets('night films, saves and sniper variants: key frames', (tester) async {
    await tester.runAsync(loadComicFont);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const doctor = [0.50, 0.57, 0.62, 0.66, 0.69, 0.71, 0.735, 0.75, 0.765, 0.775, 0.79, 0.81, 0.83, 0.86];
    const sniper = [0.30, 0.40, 0.46, 0.53, 0.56, 0.57, 0.585, 0.60, 0.64, 0.70, 0.78, 0.86];
    const lucky = [0.40, 0.48, 0.52, 0.545, 0.56, 0.575, 0.59, 0.62, 0.65, 0.68, 0.72, 0.78];
    const acts = {
      DeathAct.defibrillator: doctor,
      DeathAct.pliers: doctor,
      DeathAct.ambulance: doctor,
      DeathAct.stitches: doctor,
      DeathAct.belfry: sniper,
      DeathAct.phoneBooth: sniper,
      DeathAct.carDoor: sniper,
      DeathAct.bible: lucky,
      DeathAct.jam: lucky,
      DeathAct.banana: lucky,
      DeathAct.blackCat: lucky,
    };
    final key = GlobalKey();
    // `NOSPRITES=1` renders the fallbacks used before the sprites load.
    final sprites = Platform.environment['NOSPRITES'] == '1'
        ? null
        : await tester.runAsync(() => ParticleSprites.shared);
    for (final MapEntry(key: act, value: times) in acts.entries) {
      if (only.isNotEmpty && !only.contains(act.name)) continue;
      for (final (index, time) in times.indexed) {
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
          '${act.name}_${index}_${time.toStringAsFixed(3)}',
        );
      }
    }
  });
}
