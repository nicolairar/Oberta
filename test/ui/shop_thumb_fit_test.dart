// The Cappello and Volto pieces, checked on their pixels: each one fits the
// round thumbnail of the shop (its zoom in shop_focus.dart), and each one
// still shows on the small seat portrait of the table, on light and on dark
// skin.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/online/shop_models.dart';
import 'package:oberta/ui/avatar/avatar_look.dart';
import 'package:oberta/ui/avatar/look_painter.dart';
import 'package:oberta/ui/screens/shop/shop_focus.dart';

import 'thumb_measure.dart';

void main() {
  final pieces = [
    for (final item in initialShopCatalog)
      if (focusSlots.contains(item.slot) && !const {'none', 'clean', 'slicked', 'bob', 'bun'}.contains(item.lookId)) item,
  ];

  test('every head and face piece has a measured thumbnail zoom', () {
    final missing = [for (final item in pieces) if (pieceFocus[item.id] == null) item.id];
    expect(missing, isEmpty, reason: 'run flutter test tool/audit/thumb_focus_gen_test.dart\n${missing.join('\n')}');
  });

  test('every head and face piece fits inside its round thumbnail', () async {
    final failures = <String>[];
    for (final item in pieces) {
      final focus = pieceFocus[item.id];
      if (focus == null) continue;
      final slot = LookSlot.values.byName(item.slot);
      for (final (i, base) in measureBases.indexed) {
        final worn = base.wearing(slot, item.lookId)!;
        final points = await piecePixels(base, worn, slot);
        final out = outside(focus, points);
        if (out > 0.04) failures.add('${item.id} (base $i): ${(out * 100).toStringAsFixed(1)}% outside the thumbnail');
      }
    }
    expect(failures, isEmpty, reason: failures.join('\n'));
  });

  test('every head and face piece shows on the 64 px seat portrait, on every skin', () async {
    Future<Uint8List> seat(AvatarLook look) async {
      final recorder = ui.PictureRecorder();
      LookPainter.bust(Canvas(recorder), look, 64, aura: false);
      final image = await recorder.endRecording().toImage(64, 64);
      final bytes = await image.toByteData();
      image.dispose();
      return bytes!.buffer.asUint8List();
    }

    int diff(Uint8List a, Uint8List b) {
      var n = 0;
      for (var i = 0; i < a.length; i += 4) {
        if ((a[i] - b[i]).abs() + (a[i + 1] - b[i + 1]).abs() + (a[i + 2] - b[i + 2]).abs() > 30) n++;
      }
      return n;
    }

    final failures = <String>[];
    for (final (i, base) in measureBases.indexed) {
      final plain = await seat(base);
      for (final item in pieces) {
        final slot = LookSlot.values.byName(item.slot);
        final worn = base.wearing(slot, item.lookId)!;
        if (worn == base) continue;
        final changed = diff(plain, await seat(worn));
        // A mole or a gold tooth is small by nature; a beard or a hat is not.
        final least = switch (item.slot) {
          'hat' || 'hairdo' => 60,
          'glasses' || 'headFx' => 20,
          _ => 5,
        };
        if (changed < least) failures.add('${item.id} (base $i): only $changed pixels change at the table');
      }
    }
    expect(failures, isEmpty, reason: failures.join('\n'));
  });
}
