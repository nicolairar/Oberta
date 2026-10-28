// Avatar style demos, side by side, before anything changes in the game:
// `flutter test tool/demo_avatar/demo_avatar_render_test.dart` writes
// build/demo_avatar/<style>/{cast,skins}_{256,table}.png.
//
// 1 refined current style, 2 cartoon noir, 3 deco poster. Each sheet shows
// the same characters as 256 px busts and in the game's seat card at table
// size (a 64 px portrait in a 74 px card, drawn at 3x like a phone).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'demo_cast.dart';
import 'style_deco.dart';
import 'style_noir.dart';
import 'style_refined.dart';

final out = Platform.environment['OUT'] ?? 'build/demo_avatar';

final _styles = <String, BustPainter>{
  '1': paintRefined,
  '2': paintNoir,
  '3': paintDeco,
};

Future<void> _fonts() async {
  const dir = '/System/Library/Fonts/Supplemental';
  final loader = FontLoader('Georgia');
  for (final file in ['Georgia.ttf', 'Georgia Bold.ttf']) {
    final f = File('$dir/$file');
    if (f.existsSync()) loader.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
  }
  await loader.load();
}

Future<void> _save(ui.Picture picture, int w, int h, String path) async {
  final image = await picture.toImage(w, h);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!.buffer.asUint8List());
}

void _backdrop(Canvas canvas, Size size) {
  canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF14110F));
}

Future<void> _busts(List<DemoChar> cast, BustPainter bust, String path) async {
  const side = 256.0;
  const gap = 16.0;
  final size = Size(cast.length * (side + gap) + gap, side + gap * 2);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  _backdrop(canvas, size);
  for (var i = 0; i < cast.length; i++) {
    final at = Offset(gap + i * (side + gap), gap);
    final tile = at & const Size.square(side);
    canvas.drawRRect(
      RRect.fromRectAndRadius(tile, const Radius.circular(18)),
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -0.3),
          colors: [Color(0xFF3A2A1E), Color(0xFF120C08)],
        ).createShader(tile),
    );
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(tile, const Radius.circular(18)));
    canvas.translate(at.dx, at.dy);
    bust(canvas, cast[i], side);
    canvas.restore();
  }
  await _save(recorder.endRecording(), size.width.round(), size.height.round(), path);
}

Future<void> _table(List<DemoChar> cast, BustPainter bust, String path) async {
  const ratio = 3.0;
  const width = 74.0;
  const gap = 18.0;
  final size = Size(cast.length * (width + gap) + gap, width * 1.32 + gap * 2);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.scale(ratio);
  canvas.drawRect(
    Offset.zero & size,
    Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFF1F5B40), Color(0xFF0B2A1C)],
        radius: 1.2,
      ).createShader(Offset.zero & size),
  );
  for (var i = 0; i < cast.length; i++) {
    paintSeatCard(canvas, Offset(gap + i * (width + gap), gap), width, cast[i], bust);
  }
  await _save(recorder.endRecording(), (size.width * ratio).round(), (size.height * ratio).round(), path);
}

void main() {
  test('avatar style demos', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _fonts();
    for (final MapEntry(key: name, value: bust) in _styles.entries) {
      await _busts(demoCast, bust, '$out/$name/cast_256.png');
      await _table(demoCast, bust, '$out/$name/cast_table.png');
      await _busts(demoSkins, bust, '$out/$name/skins_256.png');
      await _table(demoSkins, bust, '$out/$name/skins_table.png');
    }
  });
}
