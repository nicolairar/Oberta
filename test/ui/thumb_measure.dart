// Where a head or face piece is on the bust, measured on its pixels: shared
// by the thumbnail test (shop_thumb_fit_test.dart) and the tool that writes
// the zoom table (tool/audit/thumb_focus_gen_test.dart).
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:oberta/ui/avatar/avatar_look.dart';
import 'package:oberta/ui/avatar/look_painter.dart';
import 'package:oberta/ui/widgets/noir_avatar.dart' show AvatarHead;

/// The slots whose thumbnails zoom on the piece itself.
const focusSlots = {'hat', 'hairdo', 'headFx', 'face', 'glasses', 'tattoo', 'faceExtras', 'eyeShine'};

/// Three players far apart: a man with a short crop and light skin, a woman
/// with a huge afro and dark skin, a woman with long hair.
final measureBases = <AvatarLook>[
  AvatarLook.fallback('Vito').copyWith(
    hat: AvatarHead.slicked,
    glasses: AvatarGlasses.none,
    accessory: AvatarAccessory.tie,
    outfit: AvatarOutfit.byId('charcoal_pinstripe'),
    base: AvatarBase.of(SkinTone.porcelain, FaceMark.clean),
    features: const FaceFeatures(hair: HairStyle.crewCut, hairColor: HairColor.darkBrown, shape: FaceShape.square, presentation: Presentation.man),
  ),
  AvatarLook.fallback('Nadia').copyWith(
    hat: AvatarHead.slicked,
    glasses: AvatarGlasses.none,
    accessory: AvatarAccessory.none,
    outfit: AvatarOutfit.byId('black_dress'),
    base: AvatarBase.of(SkinTone.ebony, FaceMark.clean),
    features: const FaceFeatures(hair: HairStyle.afro, shape: FaceShape.round, eyes: EyeShape.doe, mouth: MouthShape.lipstick, lips: LipColor.wine, presentation: Presentation.woman),
  ),
  AvatarLook.fallback('Rosalinda').copyWith(
    hat: AvatarHead.slicked,
    glasses: AvatarGlasses.none,
    accessory: AvatarAccessory.pearls,
    outfit: AvatarOutfit.byId('rose_dress'),
    base: AvatarBase.of(SkinTone.olive, FaceMark.clean),
    features: const FaceFeatures(hair: HairStyle.long, hairColor: HairColor.chestnut, shape: FaceShape.heart, mouth: MouthShape.lipstickSmile, lips: LipColor.red, presentation: Presentation.woman),
  ),
];

const _unit = 240.0;
const _margin = 0.35;
final _px = ((1 + 2 * _margin) * _unit).round();

Future<Uint8List> _raster(void Function(Canvas canvas) paint) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.translate(_margin * _unit, _margin * _unit);
  paint(canvas);
  final image = await recorder.endRecording().toImage(_px, _px);
  final bytes = await image.toByteData();
  image.dispose();
  return bytes!.buffer.asUint8List();
}

Offset _at(int i) => Offset((i % _px) / _unit - _margin, (i ~/ _px) / _unit - _margin);

/// The points (in bust units) where the piece of [slot] that [worn] has and
/// [base] has not shows. Hats, hairdos and head effects are painted alone
/// (they can shrink the whole player to fit); the rest is the difference of
/// the two busts.
Future<List<Offset>> piecePixels(AvatarLook base, AvatarLook worn, LookSlot slot) async {
  final points = <Offset>[];
  final layers = switch (slot) {
    LookSlot.hat => {LookLayer.hat},
    LookSlot.hairdo => {LookLayer.hairBack, LookLayer.hairFront, LookLayer.hat},
    LookSlot.headFx => {LookLayer.headFx},
    _ => null,
  };
  if (layers != null) {
    var alone = await _raster((c) => LookPainter.bustLayers(c, worn, _unit, layers));
    var count = 0;
    for (var i = 3; i < alone.length; i += 4) {
      if (alone[i] > 40) count++;
    }
    // A glow has no layer of its own: the head it outlines.
    if (count < 30) {
      alone = await _raster((c) => LookPainter.bustLayers(c, worn, _unit, {LookLayer.hairBack, LookLayer.hairFront, LookLayer.face}));
    }
    for (var i = 3; i < alone.length; i += 8) {
      // Hair that falls down the back past the shoulders is not the point.
      if (alone[i] > 40 && _at(i ~/ 4).dy < 0.82) points.add(_at(i ~/ 4));
    }
    if (points.isEmpty) return points;
    // A little of the face under it: the eyes.
    final a = LookPainter.bustAnchors(worn, 1);
    points
      ..add(a.leftEye)
      ..add(a.rightEye);
    return points;
  }
  final before = await _raster((c) => LookPainter.bust(c, base, _unit, aura: false));
  final after = await _raster((c) => LookPainter.bust(c, worn, _unit, aura: false));
  for (var i = 0; i < before.length; i += 8) {
    final d = (before[i] - after[i]).abs() + (before[i + 1] - after[i + 1]).abs() + (before[i + 2] - after[i + 2]).abs() + (before[i + 3] - after[i + 3]).abs();
    if (d > 48) points.add(_at(i ~/ 4));
  }
  return points;
}

/// The smallest a thumbnail zooms: a mole or a shine still shows the face
/// around it.
double minSide(String slot) => switch (slot) {
  'eyeShine' => 0.36,
  'face' || 'faceExtras' || 'tattoo' || 'glasses' => 0.46,
  'hat' => 0.52,
  _ => 0.56,
};

/// The square around [points] (bounded by [box]) whose inscribed circle
/// holds almost all of them, with a margin. It stays on the middle of the face: a
/// mark on one cheek shows the whole face, not half of it.
Rect focusAround(Rect box, List<Offset> points, String slot) {
  // The tips of a wide brim may touch the ring: the farthest 1.5% of the
  // piece does not count.
  double reach(Offset c) {
    final d = [for (final p in points) (p - c).distance]..sort();
    return d[min(d.length - 1, (d.length * 0.985).floor())];
  }

  // A piece that hangs to one side (a ponytail) is followed there.
  var c = Offset(0.5, box.center.dy);
  if (reach(c) > reach(box.center) * 1.2) c = box.center;
  // The pieces alone are painted without their ink outline: room for it.
  final side = max(minSide(slot), 2 * (reach(c) + 0.03) * 1.05);
  return Rect.fromCenter(center: c, width: side, height: side);
}

/// How much of [points] falls outside the circle inscribed in [focus].
double outside(Rect focus, List<Offset> points) {
  if (points.isEmpty) return 0;
  var n = 0;
  for (final p in points) {
    if ((p - focus.center).distance > focus.width / 2) n++;
  }
  return n / points.length;
}
