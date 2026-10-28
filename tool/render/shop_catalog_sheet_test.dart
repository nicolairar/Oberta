// Every piece of the catalogue as its shop thumbnail, worn by two players:
// `flutter test tool/render/shop_catalog_sheet_test.dart` writes
// build/shop_catalog/<slot>.png.
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/online/shop_models.dart';
import 'package:oberta/ui/avatar/avatar_look.dart';
import 'package:oberta/ui/avatar/look_painter.dart';

final out = Platform.environment['OUT'] ?? 'build/shop_catalog';

Rect _focus(String slot) => switch (slot) {
  'hat' => const Rect.fromLTWH(0.12, 0.0, 0.76, 0.6),
  'hairdo' => const Rect.fromLTWH(0.06, 0.0, 0.88, 0.7),
  'face' || 'glasses' || 'tattoo' => const Rect.fromLTWH(0.2, 0.22, 0.6, 0.55),
  'outfit' => const Rect.fromLTWH(0.0, 0.58, 1.0, 0.45),
  _ => const Rect.fromLTWH(0.06, 0.12, 0.88, 0.88),
};

void main() {
  test('catalogue sheet', () async {
    final only = Platform.environment['ONLY']?.split(',');
    final side = only == null ? 90.0 : 220.0;
    const cols = 12;
    final bySlot = <String, List<ShopItem>>{};
    for (final item in initialShopCatalog) {
      if (item.isGesture || item.around || (only != null && !only.contains(item.lookId))) continue;
      (bySlot[item.slot] ??= []).add(item);
    }
    for (final MapEntry(key: slot, value: items) in bySlot.entries) {
      final rows = (items.length / cols).ceil() * 2;
      final size = Size(cols * side, rows * side);
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      c.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF2A1F17));
      for (var i = 0; i < items.length; i++) {
        for (final (row, seed) in [(0, 'anna'), (1, 'bruno')]) {
          final look = AvatarLook.fallback(seed).wearing(LookSlot.values.byName(slot), items[i].lookId)!;
          final at = Offset((i % cols) * side, ((i ~/ cols) * 2 + row) * side);
          final focus = Platform.environment['FULL'] != null ? const Rect.fromLTWH(0, 0, 1, 1) : _focus(slot);
          final scale = max(side / focus.width, side / focus.height);
          c.save();
          c.clipRect(at & Size.square(side));
          c.translate(at.dx + side / 2 - focus.center.dx * scale, at.dy + side / 2 - focus.center.dy * scale);
          LookPainter.bust(c, look, scale);
          c.restore();
          c.drawRect(
            (at & Size.square(side)).deflate(0.5),
            Paint()
              ..style = PaintingStyle.stroke
              ..color = const Color(0xFF000000),
          );
        }
      }
      final image = await rec.endRecording().toImage(size.width.toInt(), size.height.toInt());
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File('$out/$slot.png')
        ..createSync(recursive: true)
        ..writeAsBytesSync(bytes!.buffer.asUint8List());
    }
  });
}
