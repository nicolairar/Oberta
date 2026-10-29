// The storytime short "Zio Vito" (Reels / TikTok / Shorts), frame by frame:
// `flutter test tool/promo/zio_render_test.dart` shoots the family game once
// (zio_plates.dart), then composes every frame at 60 fps (zio_scenes.dart)
// into build/promo/zio_frames/, plus the poster.
// Before it: `swift tool/promo/badges.swift` (the store badges); after it:
// `swift tool/promo/zio_encode.swift` (the MP4 with the sound).
// FRAMES=0,90,500 renders only those frames and build/promo/zio_contact.png;
// PLATES=1 also saves the plates. The script: docs/promo/short_zio.md.
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/ui/widgets/particle_sprites.dart';

import 'promo_plates.dart' show loadFonts, setView;
import 'zio_plates.dart';
import 'zio_scenes.dart' as zio;

const out = 'build/promo';

void main() {
  setUpAll(loadFonts);
  testWidgets('zio short', (tester) async {
    addTearDown(tester.view.reset);
    setView(tester);
    // The sprites first, for real: the game screens touch them too, and a
    // first load inside the test's fake time would never finish.
    await tester.runAsync(() async => zio.sprites = await ParticleSprites.shared);
    final (shot, seats) = await shootZioPlates(tester);
    zio.plates = shot;
    zio.seats = seats;
    if (Platform.environment['PLATES'] != null) await savePlates(tester, shot, '$out/zio_plates');
    final only = Platform.environment['FRAMES']?.split(',').map(int.parse).toList();
    await tester.runAsync(() async {
      zio.grain = [for (var i = 0; i < 6; i++) await _noise(Random(i))];
      zio.icons = {
        for (final name in ['mafioso', 'prostituta', 'carceriere', 'medico']) name: await _decode(File('assets/roles/$name.png').readAsBytesSync()),
      };
      zio.badges = {
        for (final name in ['app-store-it', 'google-play-it', 'steam-logo-white'])
          name: await _decode(File('$out/badges/$name.png').readAsBytesSync()),
      };
      final dir = Directory('$out/zio_frames')..createSync(recursive: true);
      if (only == null) {
        for (final f in dir.listSync()) {
          f.deleteSync();
        }
      }
      for (final f in [0.62, 0.70, 0.725]) {
        var u = 0.0;
        while (zio.film(u) < f) {
          u += 0.005;
        }
        debugPrint('film $f at ${(zio.cut('fiume') + u).toStringAsFixed(2)}s');
      }
      final W = zio.W, H = zio.H;
      final total = (zio.length * zio.fps).round();
      final watch = Stopwatch()..start();
      final sheet = ui.PictureRecorder();
      final sheetCanvas = Canvas(sheet);
      var n = 0;
      for (final i in only ?? [for (var i = 0; i < total; i++) i]) {
        final image = await zio.zioFrame(i / zio.fps);
        if (only != null) {
          sheetCanvas.drawImageRect(image, Rect.fromLTWH(0, 0, W, H), Rect.fromLTWH(n % 5 * W / 4, n ~/ 5 * H / 4, W / 4, H / 4), Paint()..filterQuality = FilterQuality.medium);
          n++;
        }
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        File('${dir.path}/f_${i.toString().padLeft(4, '0')}.png').writeAsBytesSync(png!.buffer.asUint8List());
        if (i == (1.2 * zio.fps).round()) File('$out/oberta_short_zio_poster.png').writeAsBytesSync(png.buffer.asUint8List());
        image.dispose();
        if (i % 240 == 0) debugPrint('frame $i/$total  ${watch.elapsed.inSeconds}s');
      }
      if (only != null) {
        final rows = (n + 4) ~/ 5;
        final img = await sheet.endRecording().toImage((W / 4 * min(n, 5)).round(), (H / 4 * rows).round());
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        File('$out/zio_contact.png').writeAsBytesSync(png!.buffer.asUint8List());
      }
    });
  }, timeout: const Timeout(Duration(minutes: 90)));
}

Future<ui.Image> _decode(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  return (await codec.getNextFrame()).image;
}

/// A film-grain tile at half resolution, drawn stretched over the frame.
Future<ui.Image> _noise(Random random) {
  const w = 540, h = 960;
  final pixels = Uint8List(w * h * 4);
  for (var i = 0; i < w * h; i++) {
    final v = 128 + ((random.nextDouble() + random.nextDouble() - 1) * 110).round();
    pixels[i * 4] = v;
    pixels[i * 4 + 1] = v;
    pixels[i * 4 + 2] = v;
    pixels[i * 4 + 3] = 255;
  }
  final done = Completer<ui.Image>();
  ui.decodeImageFromPixels(pixels, w, h, ui.PixelFormat.rgba8888, done.complete);
  return done.future;
}
