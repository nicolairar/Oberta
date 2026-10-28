import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/online/reactions.dart';
import 'package:oberta/online/shop_models.dart';
import 'package:oberta/ui/screens/online/game/noir_ui.dart';
import 'package:oberta/ui/screens/online/game/table_gestures.dart';

/// I gesti disegnati, in build/gestures: il campionario e un volo a
/// fotogrammi, per guardarli a occhio.
Future<void> _save(WidgetTester tester, String name, Size size, void Function(Canvas canvas) draw) async {
  await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(Offset.zero & size, Paint()..color = Saloon.feltDeep);
    draw(canvas);
    final image = await recorder.endRecording().toImage(size.width.toInt(), size.height.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/gestures/$name.png')..createSync(recursive: true);
    file.writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  test('ogni gesto è un pezzo della bottega, e i sei di casa sono gratis', () {
    expect(TableGesture.values.length, gestureDrop.length);
    for (final gesture in TableGesture.values) {
      expect(gesture.item.id, 'gesture.${gesture.name}');
    }
    expect(TableGesture.values.where((g) => g.free).length, 6);
    expect(TableGesture.values.where((g) => g.legendary), [TableGesture.horse, TableGesture.tommy]);
  });

  testWidgets('il campionario e un volo', (tester) async {
    const cell = 140.0;
    await _save(tester, 'sheet', const Size(cell * 5, cell * 3), (canvas) {
      for (final (i, gesture) in TableGesture.values.indexed) {
        canvas.save();
        canvas.translate((i % 5) * cell + cell / 2, (i ~/ 5) * cell + cell / 2);
        canvas.scale(cell * 0.8);
        GestureArt.paintUnit(canvas, gesture, t: 0.2);
        canvas.restore();
      }
    });
    for (final gesture in [TableGesture.cigar, TableGesture.horse, TableGesture.tommy, TableGesture.cash]) {
      const frames = 8;
      await _save(tester, 'flight_${gesture.name}', const Size(260.0 * frames, 300), (canvas) {
        final total = GestureLayer.lengthOf(gesture);
        for (var f = 0; f < frames; f++) {
          canvas.save();
          canvas.translate(f * 260.0, 0);
          canvas.clipRect(const Rect.fromLTWH(0, 0, 258, 300));
          const card = Size(70, 92);
          const from = Offset(50, 240);
          const to = Offset(190, 90);
          for (final c in [from, to]) {
            canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: card.width, height: card.height), const Radius.circular(10)),
                Paint()..color = Saloon.wood);
          }
          paintFlight(canvas, gesture, from, to, card, total * (f + 0.5) / frames);
          canvas.restore();
        }
      });
    }
  });
}
