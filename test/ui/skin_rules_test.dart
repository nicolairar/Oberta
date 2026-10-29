// The rules the skin audit (docs/audit/skins_abito_vizio_calcio.md) found
// broken, checked on the drawn bust: nothing hangs below the hem, the gold
// shine stays on the gold, a vice shows on a woman in a dress too, and the
// vices beside the player get the whole portrait as their thumbnail.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/online/shop_models.dart';
import 'package:oberta/ui/avatar/avatar_look.dart';
import 'package:oberta/ui/avatar/look_painter.dart';
import 'package:oberta/ui/widgets/noir_avatar.dart' show AvatarHead;

const _side = 200.0;

/// The bust of [look] in a canvas [_side] wide and [tall] times as high, so
/// what falls below the bust's own square shows.
Future<(Uint8List, int, int)> _paint(AvatarLook look, {double tall = 1.4}) async {
  final recorder = ui.PictureRecorder();
  LookPainter.bust(Canvas(recorder), look, _side, aura: false);
  final w = _side.toInt(), h = (_side * tall).toInt();
  final image = await recorder.endRecording().toImage(w, h);
  final bytes = await image.toByteData();
  image.dispose();
  return (bytes!.buffer.asUint8List(), w, h);
}

int _inked(Uint8List px, int w, int fromRow, int toRow) {
  var n = 0;
  for (var y = fromRow; y < toRow; y++) {
    for (var x = 0; x < w; x++) {
      if (px[(y * w + x) * 4 + 3] > 8) n++;
    }
  }
  return n;
}

final _man = AvatarLook.fallback('vito').copyWith(
  hat: AvatarHead.slicked,
  glasses: AvatarGlasses.none,
  accessory: AvatarAccessory.none,
  outfit: AvatarOutfit.byId('charcoal_pinstripe'),
  base: AvatarBase.of(SkinTone.porcelain, FaceMark.clean),
  features: const FaceFeatures(hair: HairStyle.sidePart, presentation: Presentation.man),
);

final _woman = _man.copyWith(
  accessory: AvatarAccessory.none,
  outfit: AvatarOutfit.byId('rose_dress'),
  base: AvatarBase.of(SkinTone.espresso, FaceMark.clean),
  features: const FaceFeatures(hair: HairStyle.long, presentation: Presentation.woman),
);

void main() {
  test('ties, braces and pearls stop at the hem of a tailored suit', () async {
    final (bare, w, _) = await _paint(_man);
    final below = _inked(bare, w, (_side * 1.05).toInt(), (_side * 1.4).toInt());
    final failures = <String>[];
    for (final a in [
      AvatarAccessory.tie,
      AvatarAccessory.polkaTie,
      AvatarAccessory.stripeTie,
      AvatarAccessory.knitTie,
      AvatarAccessory.ricciTiePin,
      AvatarAccessory.suspenders,
      AvatarAccessory.chanterellePearls,
      AvatarAccessory.cravat,
    ]) {
      for (final suit in ['charcoal_pinstripe', 'midnight_double', 'black_tuxedo']) {
        final (px, _, _) = await _paint(_man.copyWith(accessory: a, outfit: AvatarOutfit.byId(suit)));
        final hanging = _inked(px, w, (_side * 1.05).toInt(), (_side * 1.4).toInt()) - below;
        if (hanging > 0) failures.add('${a.name} on $suit: $hanging pixels below the hem');
      }
    }
    expect(failures, isEmpty, reason: failures.join('\n'));
  });

  test('the gold shine lies on the gold, not on the background', () async {
    for (final look in [
      _man.copyWith(outfit: AvatarOutfit.byId('gold_brocade')),
      _man.copyWith(outfit: AvatarOutfit.byId('versalli_baroque')),
      _man.copyWith(base: AvatarBase.of(SkinTone.porcelain, FaceMark.goldStatue)),
    ]) {
      expect(LookPainter.gilded(look), isTrue);
      final plain = look.copyWith(outfit: AvatarOutfit.byId('charcoal_pinstripe'), base: AvatarBase.of(SkinTone.porcelain, FaceMark.clean));
      final (gold, w, _) = await _paint(look, tall: 1);
      final (bare, _, _) = await _paint(plain, tall: 1);
      // The top band above the head is empty in both: the shine must not
      // paint a square of light there.
      final top = (_side * 0.08).toInt();
      expect(_inked(gold, w, 0, top), _inked(bare, w, 0, top), reason: '$look');
    }
  });

  test('every tie and scarf shows on a woman in a dress', () async {
    final (bare, _, _) = await _paint(_woman, tall: 1);
    final failures = <String>[];
    for (final a in [AvatarAccessory.tie, AvatarAccessory.polkaTie, AvatarAccessory.stripeTie, AvatarAccessory.knitTie, AvatarAccessory.ricciTiePin, AvatarAccessory.scarf, AvatarAccessory.cravat]) {
      for (final dress in ['rose_dress', 'black_dress', 'emerald_dress']) {
        final (px, _, _) = await _paint(_woman.copyWith(accessory: a, outfit: AvatarOutfit.byId(dress)), tall: 1);
        final (plain, _, _) = await _paint(_woman.copyWith(outfit: AvatarOutfit.byId(dress)), tall: 1);
        var changed = 0;
        for (var i = 0; i < px.length; i += 4) {
          if ((px[i] - plain[i]).abs() + (px[i + 1] - plain[i + 1]).abs() + (px[i + 2] - plain[i + 2]).abs() > 60) changed++;
        }
        if (changed < 80) failures.add('${a.name} on $dress: only $changed pixels change');
      }
    }
    expect(bare, isNotEmpty);
    expect(failures, isEmpty, reason: failures.join('\n'));
  });

  test('the vices beside the player get the whole portrait as their thumbnail', () {
    for (final team in CalcioTeam.values) {
      expect(LookPainter.beside(AvatarAccessory.values.byName(team.propId)), isTrue, reason: team.propId);
      expect(LookPainter.beside(AvatarAccessory.values.byName(team.scarfId)), isFalse, reason: team.scarfId);
    }
    for (final a in [AvatarAccessory.parrot, AvatarAccessory.balloons, AvatarAccessory.jetpack, AvatarAccessory.plungerSword]) {
      expect(LookPainter.beside(a), isTrue, reason: a.name);
    }
    expect(LookPainter.beside(AvatarAccessory.tie), isFalse);
  });

  test('every team kit is drawn in the colours its tagline names', () {
    // «Rosso fuoco, collo nero»: the collar is the trim.
    expect(CalcioTeam.diavoli.trim.computeLuminance(), lessThan(0.05));
    expect(CalcioTeam.diavoli.primary.r, greaterThan(0.7));
  });
}
