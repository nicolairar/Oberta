// Every combination of the wardrobe, checked on the pixels: no hair above or
// through a hat, beards on the jaw, glasses on the eye line and cigars at
// the mouth, for every face shape. Each piece is painted alone
// ([LookPainter.bustLayers]) in a grid of tiles, one image per hat.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/ui/avatar/avatar_look.dart';
import 'package:oberta/ui/avatar/look_painter.dart';
import 'package:oberta/ui/widgets/noir_avatar.dart' show AvatarHead;

const _tile = 96.0;
const _cols = 16;

/// Hats that hide all the hair (masks, wigs, hoods): nothing to check.
const _covering = {
  AvatarHead.clownWig,
  AvatarHead.roosterHead,
  AvatarHead.fishHead,
  AvatarHead.dinoHood,
  AvatarHead.octopusHat,
  AvatarHead.rainbowAfro,
  AvatarHead.flamingHair,
};

/// Things that rest on top of free hair instead of pressing it down.
const _resting = {
  AvatarHead.angelHalo,
  AvatarHead.devilHorns,
  AvatarHead.astronautHelmet,
  AvatarHead.unicornHorn,
  AvatarHead.spaghettiHat,
  AvatarHead.ufoHat,
  AvatarHead.birthdayCake,
  AvatarHead.starHalo,
  AvatarHead.catOnHead,
};

AvatarLook _look({
  AvatarHead hat = AvatarHead.slicked,
  HairStyle hair = HairStyle.slicked,
  FaceShape shape = FaceShape.oval,
  FaceMark mark = FaceMark.clean,
  AvatarGlasses glasses = AvatarGlasses.none,
  AvatarAccessory accessory = AvatarAccessory.none,
}) =>
    AvatarLook(
      base: AvatarBase.of(SkinTone.olive, mark),
      hat: hat,
      glasses: glasses,
      outfit: AvatarOutfit.catalog.first,
      accessory: accessory,
      features: FaceFeatures(hair: hair, shape: shape),
    );

/// The alpha of every pixel of each tile, painted with [layers] only.
class _Sheet {
  final Uint8List rgba;
  final int width;

  _Sheet(this.rgba, this.width);

  int alpha(int tile, int x, int y) {
    final ox = (tile % _cols) * _tile.toInt();
    final oy = (tile ~/ _cols) * _tile.toInt();
    return rgba[((oy + y) * width + ox + x) * 4 + 3];
  }

  /// The topmost painted row in column [x], or null.
  int? top(int tile, int x) {
    for (var y = 0; y < _tile; y++) {
      if (alpha(tile, x, y) > 128) return y;
    }
    return null;
  }

  /// The painted box of the tile, or null if empty.
  Rect? box(int tile) {
    var l = 1 << 30, t = 1 << 30, r = -1, b = -1;
    for (var y = 0; y < _tile; y++) {
      for (var x = 0; x < _tile; x++) {
        if (alpha(tile, x, y) > 128) {
          if (x < l) l = x;
          if (x > r) r = x;
          if (y < t) t = y;
          if (y > b) b = y;
        }
      }
    }
    return r < 0 ? null : Rect.fromLTRB(l.toDouble(), t.toDouble(), r + 1.0, b + 1.0);
  }
}

Future<_Sheet> _paint(List<AvatarLook> looks, Set<LookLayer> layers) async {
  final rows = (looks.length / _cols).ceil();
  final w = (_cols * _tile).toInt();
  final h = (rows * _tile).toInt();
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  for (var i = 0; i < looks.length; i++) {
    canvas.save();
    canvas.translate((i % _cols) * _tile, (i ~/ _cols) * _tile);
    canvas.clipRect(Offset.zero & const Size.square(_tile));
    LookPainter.bustLayers(canvas, looks[i], _tile, layers);
    canvas.restore();
  }
  final image = await recorder.endRecording().toImage(w, h);
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  return _Sheet(data!.buffer.asUint8List(), w);
}

/// Where a point of the head lands in the tile of [look].
Offset _px(AvatarLook look, Offset head) {
  final frame = LookPainter.bustFrame(look);
  final s = _tile * frame.scale;
  final eye = LookPainter.headPoint(const Offset(0, -0.868)).dy;
  final p = LookPainter.headPoint(head);
  return Offset(_tile * 0.5 + p.dx * s, _tile * frame.eyes + (p.dy - eye) * s);
}

double _unit(AvatarLook look) => _tile * LookPainter.bustFrame(look).scale * LookPainter.headScale;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the layers are painted in one fixed order', () {
    expect(LookLayer.values, [
      LookLayer.wings,
      LookLayer.hairBack,
      LookLayer.body,
      LookLayer.neck,
      LookLayer.face,
      LookLayer.beard,
      LookLayer.hairFront,
      LookLayer.glasses,
      LookLayer.hat,
      LookLayer.chest,
      LookLayer.mouthProp,
    ]);
  });

  test('no hair pokes above or through any hat, for every hairstyle and face', () async {
    final failures = <String>[];
    for (final hat in AvatarHead.values) {
      if (hat == AvatarHead.slicked || hat == AvatarHead.bob || hat == AvatarHead.bun || _covering.contains(hat)) continue;
      final looks = [
        for (final hair in HairStyle.values)
          for (final shape in FaceShape.values) _look(hat: hat, hair: hair, shape: shape),
      ];
      final hair = await _paint(looks, {LookLayer.hairBack, LookLayer.hairFront});
      final worn = await _paint(looks, {LookLayer.hat});
      for (var i = 0; i < looks.length; i++) {
        final label = '${hat.name} + ${looks[i].features.hair.name} (${looks[i].features.shape.name})';
        if (_resting.contains(hat)) {
          // It sits on the hair: its top is above the top of the hair.
          final h = hair.box(i), t = worn.box(i);
          if (h != null && t != null && t.top > h.top + 1) failures.add('$label: buried in the hair');
          continue;
        }
        for (var x = 0; x < _tile; x++) {
          final crown = worn.top(i, x);
          final top = hair.top(i, x);
          if (crown == null || top == null) continue;
          if (top < crown - 1) {
            failures.add('$label: hair above the hat at x=$x');
            break;
          }
        }
      }
    }
    expect(failures, isEmpty, reason: failures.join('\n'));
  });

  test('beards and moustaches sit on the jaw of every face shape', () async {
    const marks = [
      FaceMark.mustache, FaceMark.stubble, FaceMark.goatee, FaceMark.pencil, FaceMark.handlebar, FaceMark.walrus, //
      FaceMark.imperial, FaceMark.chevron, FaceMark.horseshoe, FaceMark.vandyke, FaceMark.muttonChops, FaceMark.fullBeard,
      FaceMark.curledMoustache, FaceMark.giantMoustache, FaceMark.vikingBeard,
    ];
    final looks = [
      for (final mark in marks)
        for (final shape in FaceShape.values) _look(mark: mark, shape: shape, hair: HairStyle.bald),
    ];
    final beards = await _paint(looks, {LookLayer.beard});
    final failures = <String>[];
    for (var i = 0; i < looks.length; i++) {
      final look = looks[i];
      final box = beards.box(i);
      if (box == null) continue;
      final label = '${look.base.mark.name} (${look.features.shape.name})';
      final u = _unit(look);
      final nose = _px(look, const Offset(0, -0.9)).dy;
      if (box.top < nose - 0.02 * u) failures.add('$label: above the eyes');
      if ((box.center.dx - _tile / 2).abs() > 0.02 * u) failures.add('$label: off centre');
      if (box.bottom > _px(look, const Offset(0, -0.655)).dy + 0.22 * u) failures.add('$label: below the chest');
    }
    expect(failures, isEmpty, reason: failures.join('\n'));
  });

  test('glasses sit on the eye line and mouth props at the mouth, for every face', () async {
    final glasses = [for (final g in AvatarGlasses.values) if (g != AvatarGlasses.none) g];
    final looks = [
      for (final g in glasses)
        for (final shape in FaceShape.values) _look(glasses: g, shape: shape),
    ];
    final sheet = await _paint(looks, {LookLayer.glasses});
    final failures = <String>[];
    for (var i = 0; i < looks.length; i++) {
      final box = sheet.box(i);
      final eye = _px(looks[i], const Offset(0, -0.868)).dy;
      if (box == null || box.top > eye || box.bottom < eye) failures.add('${looks[i].glasses.name} (${looks[i].features.shape.name}) off the eyes');
    }
    const props = [
      AvatarAccessory.cigar, AvatarAccessory.cigarette, AvatarAccessory.toothpick, AvatarAccessory.pipe, //
      AvatarAccessory.cigaretteHolder, AvatarAccessory.baguetteCigar,
    ];
    final smokers = [
      for (final p in props)
        for (final shape in FaceShape.values) _look(accessory: p, shape: shape),
    ];
    final mouths = await _paint(smokers, {LookLayer.mouthProp});
    for (var i = 0; i < smokers.length; i++) {
      final box = mouths.box(i);
      final mouth = _px(smokers[i], const Offset(0.03, -0.762));
      if (box == null || !box.inflate(2).contains(mouth)) failures.add('${smokers[i].accessory.name} (${smokers[i].features.shape.name}) away from the mouth');
    }
    expect(failures, isEmpty, reason: failures.join('\n'));
  });
}
