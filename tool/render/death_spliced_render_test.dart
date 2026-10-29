import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/ui/widgets/city_backdrop.dart';
import 'package:oberta/ui/widgets/death_scene.dart';
import 'package:oberta/ui/widgets/particle_sprites.dart';

import 'comic_font.dart';

/// Renders the key frames of night films where an ambush fails: a Family
/// attack, then the Doctor or a stroke of luck. `OUT` is the output folder;
/// `FILMS` an optional comma list of `attack+save` act names (or a single
/// act name); `TIMES` an optional comma list of film times.
final out = Platform.environment['OUT'] ?? 'build/render';
final films = (Platform.environment['FILMS'] ?? '')
    .split(',')
    .where((name) => name.isNotEmpty)
    .toList();
final times = (Platform.environment['TIMES'] ?? '')
    .split(',')
    .where((time) => time.isNotEmpty)
    .map(double.parse)
    .toList();

const _doctor = [0.50, 0.56, 0.60, 0.63, 0.66, 0.70, 0.735, 0.76, 0.78, 0.81, 0.86];
const _luck = [0.50, 0.545, 0.565, 0.58, 0.60, 0.63, 0.66, 0.70, 0.75, 0.80];

const _defaults = [
  'knife+defibrillator',
  'poison+rescue',
  'bowling+stitches',
  'lupara+pliers',
  'driveBy+ambulance',
  'kiss+defibrillator',
  'pie+ambulance',
  'tango+stitches',
  'car+rescue',
  'trombone+pliers',
  'knife+lucky',
  'lupara+bible',
  'burst+jam',
  'trombone+jam',
  'knife+banana',
  'bat+banana',
  'lupara+blackCat',
  'burst+blackCat',
];

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

void main() {
  testWidgets('night films where the ambush fails: key frames', (tester) async {
    await tester.runAsync(loadComicFont);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    final sprites = await tester.runAsync(() => ParticleSprites.shared);
    for (final film in films.isEmpty ? _defaults : films) {
      final parts = film.split('+');
      final act = DeathAct.values.byName(parts.first);
      final save = parts.length > 1 ? DeathAct.values.byName(parts[1]) : null;
      final frames = times.isNotEmpty ? times : ((save ?? act).doctorSaves ? _doctor : _luck);
      for (final (index, time) in frames.indexed) {
        await tester.pumpWidget(
          MaterialApp(
            home: RepaintBoundary(
              key: key,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CityBackdrop(style: SkylineStyle.metropolis, rain: true, child: const SizedBox.expand()),
                  CustomPaint(
                    painter: DeathScenePainter(t: time, act: act, save: save, sprites: sprites),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pump();
        await capture(tester, key, '${film}_${index}_${time.toStringAsFixed(3)}');
      }
    }
  });
}
