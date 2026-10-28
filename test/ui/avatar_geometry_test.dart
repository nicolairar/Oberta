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
  AvatarHead.crown,
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

  (int, int, int, int) pixel(int tile, int x, int y) {
    final ox = (tile % _cols) * _tile.toInt();
    final oy = (tile ~/ _cols) * _tile.toInt();
    final i = ((oy + y) * width + ox + x) * 4;
    return (rgba[i], rgba[i + 1], rgba[i + 2], rgba[i + 3]);
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

/// Where the eyes, nose, mouth and chin of [look] land in its tile.
({Offset leftEye, Offset rightEye, double nose, double mouth, double chin, double brow, double width}) _at(AvatarLook look) => LookPainter.bustAnchors(look, _tile);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the layers are painted in one fixed order', () {
    expect(LookLayer.values, [
      LookLayer.back,
      LookLayer.headGlow,
      LookLayer.hairBack,
      LookLayer.body,
      LookLayer.neck,
      LookLayer.face,
      LookLayer.beard,
      LookLayer.hairFront,
      LookLayer.glasses,
      LookLayer.headFx,
      LookLayer.hat,
      LookLayer.chest,
      LookLayer.mouthProp,
      LookLayer.held,
      LookLayer.frontFx,
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
      final a = _at(look);
      // A viking beard is braided from the temples and falls to the chest.
      if (box.top < (look.base.mark == FaceMark.vikingBeard ? a.brow : a.leftEye.dy)) failures.add('$label: above the eyes');
      if ((box.center.dx - _tile / 2).abs() > 0.04 * a.width) failures.add('$label: off centre');
      if (box.bottom > a.chin + (look.base.mark == FaceMark.vikingBeard ? 1.2 : 0.6) * a.width) failures.add('$label: below the chest');
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
      final eye = _at(looks[i]).leftEye.dy;
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
      final a = _at(smokers[i]);
      final mouth = Offset(_tile / 2 + a.width * 0.1, a.mouth);
      if (box == null || !box.inflate(3).contains(mouth)) failures.add('${smokers[i].accessory.name} (${smokers[i].features.shape.name}) away from the mouth');
    }
    expect(failures, isEmpty, reason: failures.join('\n'));
  });

  test('the eyes are always level and mirrored, for every eye shape, size, face and presentation', () async {
    final looks = [
      for (final shape in EyeShape.values)
        for (final size in EyeSize.values)
          for (final p in Presentation.values)
            for (final face in FaceShape.values)
              AvatarLook(
                base: AvatarBase.of(SkinTone.olive, FaceMark.clean),
                hat: AvatarHead.slicked,
                glasses: AvatarGlasses.none,
                outfit: AvatarOutfit.catalog.first,
                accessory: AvatarAccessory.none,
                features: FaceFeatures(hair: HairStyle.bald, eyes: shape, eyeSize: size, presentation: p, shape: face, eyeColor: EyeColor.values[(shape.index + size.index) % EyeColor.values.length]),
              ),
    ];
    final sheet = await _paint(looks, {LookLayer.face});
    final failures = <String>[];
    for (var i = 0; i < looks.length; i++) {
      final a = _at(looks[i]);
      final label = '${looks[i].features.eyes.name}/${looks[i].features.eyeSize.name}/${looks[i].features.presentation.name}/${looks[i].features.shape.name}';
      if ((a.leftEye.dy - a.rightEye.dy).abs() > 0.01 || (a.leftEye.dx + a.rightEye.dx - _tile).abs() > 0.01) failures.add('$label: anchors not level');
      // The band from the brows to the eye line: the nose starts below it.
      final top = (a.brow - a.width * 0.12).floor().clamp(0, _tile.toInt() - 1);
      final bottom = a.leftEye.dy.floor().clamp(0, _tile.toInt() - 1);
      var bad = 0, all = 0;
      for (var y = top; y <= bottom; y++) {
        for (var x = 0; x < _tile ~/ 2; x++) {
          final l = sheet.pixel(i, x, y), r = sheet.pixel(i, _tile.toInt() - 1 - x, y);
          all++;
          if ((l.$1 - r.$1).abs() + (l.$2 - r.$2).abs() + (l.$3 - r.$3).abs() + (l.$4 - r.$4).abs() > 160) bad++;
        }
      }
      if (bad > all * 0.02) failures.add('$label: eyes not mirrored ($bad of $all pixels)');
    }
    expect(failures, isEmpty, reason: failures.join('\n'));
  });
}
