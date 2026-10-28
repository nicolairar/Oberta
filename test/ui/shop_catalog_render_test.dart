// Every piece in the catalogue draws something you can see where the shop
// shows it: worn on the bust, its thumbnail differs from the same thumbnail
// with nothing in that slot. `SHOP_IDS=<file of ids>` checks another list
// (the live catalogue, say).
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/online/shop_models.dart';
import 'package:oberta/ui/avatar/avatar_look.dart';
import 'package:oberta/ui/avatar/look_painter.dart';
import 'package:oberta/ui/widgets/cosmetics/seat_preview.dart';

const _side = 96.0;

Rect _focus(String slot) => switch (slot) {
  // The same zooms as the shop's thumbnails (shop_parts.dart, _focusOf).
  'hat' => const Rect.fromLTWH(0.12, 0.0, 0.76, 0.6),
  'hairdo' || 'hairDye' => const Rect.fromLTWH(0.06, 0.0, 0.88, 0.7),
  'headFx' => const Rect.fromLTWH(0.06, -0.04, 0.88, 0.72),
  'face' || 'glasses' || 'tattoo' || 'faceExtras' => const Rect.fromLTWH(0.2, 0.22, 0.6, 0.55),
  'eyeShine' => const Rect.fromLTWH(0.26, 0.3, 0.48, 0.34),
  'outfit' => const Rect.fromLTWH(0.0, 0.58, 1.0, 0.45),
  'aura' || 'back' || 'held' || 'frontFx' => const Rect.fromLTWH(0, 0, 1, 1),
  _ => const Rect.fromLTWH(0.06, 0.12, 0.88, 0.88),
};

Future<Uint8List> _bust(AvatarLook look, [String slot = '']) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final focus = _focus(slot);
  final scale = _side / focus.width;
  canvas.translate(_side / 2 - focus.center.dx * scale, _side / 2 - focus.center.dy * scale);
  LookPainter.bust(canvas, look, scale);
  final image = await recorder.endRecording().toImage(_side.toInt(), _side.toInt());
  final bytes = await image.toByteData();
  image.dispose();
  return bytes!.buffer.asUint8List();
}

int _diff(Uint8List a, Uint8List b) {
  var n = 0;
  for (var i = 0; i < a.length; i += 4) {
    if ((a[i] - b[i]).abs() + (a[i + 1] - b[i + 1]).abs() + (a[i + 2] - b[i + 2]).abs() + (a[i + 3] - b[i + 3]).abs() > 24) n++;
  }
  return n;
}

void main() {
  test('every worn piece of the catalogue shows on the bust', () async {
    final ids = Platform.environment['SHOP_IDS'] != null
        ? File(Platform.environment['SHOP_IDS']!).readAsLinesSync()
        : [for (final item in initialShopCatalog) item.id];
    final failures = <String>[];
    for (final seed in ['anna', 'bruno']) {
      final base = AvatarLook.fallback(seed);
      for (final id in ids) {
        final slotName = id.substring(0, id.indexOf('.'));
        final lookId = id.substring(id.indexOf('.') + 1);
        if (slotName == 'gesture' || slotName == 'border' || slotName == 'nameStyle') continue;
        final slot = LookSlot.values.where((s) => s.name == slotName).firstOrNull;
        if (slot == null) {
          failures.add('$id: unknown slot');
          continue;
        }
        final worn = base.wearing(slot, lookId);
        if (worn == null) {
          failures.add('$id: not drawable');
          continue;
        }
        // Against the same bust with nothing in the slot (or, for hats and
        // suits, the house piece): the piece itself must show.
        final empty = switch (slot) {
          LookSlot.face => 'clean',
          LookSlot.hat || LookSlot.outfit => null,
          _ => 'none',
        };
        final bare = empty == null ? base : base.wearing(slot, empty)!;
        if (worn == bare) continue;
        final changed = _diff(await _bust(bare, slotName), await _bust(worn, slotName));
        // Small things (a mark, a shine, a dye under a cap) change few pixels in
        // the thumbnail; the big ones (a scene, a hat, a suit) many.
        final least = switch (slot) {
          LookSlot.tattoo || LookSlot.face || LookSlot.accessory || LookSlot.faceExtras || LookSlot.eyeShine || LookSlot.hairDye => 12,
          LookSlot.frontFx || LookSlot.headFx => 25,
          _ => 150,
        };
        if (changed < least) failures.add('$id ($seed): only $changed pixels change');
      }
    }
    expect(failures, isEmpty, reason: failures.join('\n'));
  });

  test('every vice and football piece shows at the table too, on the 64 px seat portrait', () async {
    Future<Uint8List> seat(AvatarLook look) async {
      final recorder = ui.PictureRecorder();
      LookPainter.bust(Canvas(recorder), look, 64, aura: false);
      final image = await recorder.endRecording().toImage(64, 64);
      final bytes = await image.toByteData();
      image.dispose();
      return bytes!.buffer.asUint8List();
    }

    final pieces = [
      for (final item in initialShopCatalog)
        if (item.slot == 'accessory' && !item.free || const {'back', 'held', 'headFx'}.contains(item.slot) && !item.free) item,
    ];
    // The ones the owner saw blank in build 65, by name.
    for (final id in ['accessory.azzurriFlag', 'accessory.azzurriScarf', 'accessory.giallorossiFlare', 'accessory.giallorossiScarf', 'accessory.bianconeriTrophy']) {
      expect(pieces.map((item) => item.id), contains(id));
    }
    final failures = <String>[];
    for (final seed in ['anna', 'bruno']) {
      final base = AvatarLook.fallback(seed);
      for (final item in pieces) {
        final slot = LookSlot.values.byName(item.slot);
        final bare = base.wearing(slot, 'none')!;
        final changed = _diff(await seat(bare), await seat(base.wearing(slot, item.lookId)!));
        if (changed < 6) failures.add('${item.id} ($seed): only $changed pixels change at the table');
      }
    }
    expect(failures, isEmpty, reason: failures.join('\n'));
  });

  testWidgets('every frame and name ink shows on the seat card the shop previews', (tester) async {
    final key = GlobalKey();
    Future<Uint8List> card(AvatarLook look) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: RepaintBoundary(
              key: key,
              child: SizedBox(
                width: 160,
                height: 160 * SeatPreview.aspect,
                child: SeatPreview(look: look, name: 'anna'),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      return (await tester.runAsync(() async {
        final image = await (key.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage();
        final bytes = await image.toByteData();
        image.dispose();
        return bytes!.buffer.asUint8List();
      }))!;
    }

    final base = AvatarLook.fallback('anna');
    final plain = await card(base);
    final failures = <String>[];
    for (final item in initialShopCatalog.where((item) => item.around && !item.free)) {
      final worn = base.wearing(LookSlot.values.byName(item.slot), item.lookId)!;
      final changed = _diff(plain, await card(worn));
      if (changed < 40) failures.add('${item.id}: only $changed pixels change');
    }
    expect(failures, isEmpty, reason: failures.join('\n'));
    // The plate is part of the card: the name ink shows there.
    expect(find.byKey(const Key('seatPreview.plate')), findsOneWidget);
  });
}
