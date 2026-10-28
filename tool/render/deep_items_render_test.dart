// The dearest shelf of the shop, as the live painter draws it: every scene,
// shoulder piece, head effect, face mark, eye shine, dye, held item and
// front effect, each worn by a different player. `flutter test
// tool/render/deep_items_render_test.dart` writes
// build/deep_items/{contact,table}.png.
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/ui/avatar/avatar_look.dart';
import 'package:oberta/ui/avatar/look_painter.dart';
import 'package:oberta/ui/widgets/noir_avatar.dart' show AvatarHead;

final out = Platform.environment['OUT'] ?? 'build/deep_items';

AvatarLook _look(String seed, {SkinTone tone = SkinTone.olive, FaceMark mark = FaceMark.clean, AvatarHead hat = AvatarHead.slicked, String outfit = 'charcoal_pinstripe', AvatarAccessory accessory = AvatarAccessory.tie, AvatarGlasses glasses = AvatarGlasses.none, required FaceFeatures features}) =>
    AvatarLook.fallback(seed).copyWith(base: AvatarBase.of(tone, mark), hat: hat, glasses: glasses, outfit: AvatarOutfit.byId(outfit), accessory: accessory, features: features);

final _cast = [
  _look('Vito', hat: AvatarHead.fedora, mark: FaceMark.mustache, features: const FaceFeatures(hair: HairStyle.slicked, presentation: Presentation.man, shape: FaceShape.square, brows: BrowShape.angled)),
  _look('Luna', tone: SkinTone.porcelain, outfit: 'black_dress', accessory: AvatarAccessory.pearls, features: const FaceFeatures(hair: HairStyle.fingerWaves, hairColor: HairColor.platinum, presentation: Presentation.woman, mouth: MouthShape.lipstick, lips: LipColor.red, shape: FaceShape.heart)),
  _look('Santo', tone: SkinTone.umber, mark: FaceMark.fullBeard, outfit: 'cream_dinner', accessory: AvatarAccessory.bowTie, features: const FaceFeatures(hair: HairStyle.curly, hairColor: HairColor.white, presentation: Presentation.man, shape: FaceShape.round)),
  _look('Ossa', tone: SkinTone.ivory, outfit: 'midnight_double', features: const FaceFeatures(hair: HairStyle.pompadour, hairColor: HairColor.blonde, presentation: Presentation.man, shape: FaceShape.long)),
  _look('Nonna', tone: SkinTone.rose, hat: AvatarHead.wideBrim, glasses: AvatarGlasses.round, outfit: 'powder_blouse', accessory: AvatarAccessory.pearls, features: const FaceFeatures(hair: HairStyle.bun, hairColor: HairColor.grey, presentation: Presentation.woman, age: FaceAge.lines, shape: FaceShape.round)),
  _look('Oro', tone: SkinTone.honey, hat: AvatarHead.topHat, outfit: 'gold_brocade', accessory: AvatarAccessory.carnation, features: const FaceFeatures(hair: HairStyle.wavy, hairColor: HairColor.red, presentation: Presentation.man, mouth: MouthShape.smirk)),
  _look('Rosa', tone: SkinTone.espresso, outfit: 'emerald_dress', accessory: AvatarAccessory.none, features: const FaceFeatures(hair: HairStyle.long, hairColor: HairColor.black, presentation: Presentation.woman, shape: FaceShape.oval)),
];

/// Every new piece: its slot, its id, and how to wear it.
final _pieces = <(String, String, AvatarLook Function(AvatarLook))>[
  for (final a in Aura.values.skip(1)) ('aura', a.name, (l) => l.copyWith(aura: a)),
  for (final b in BackItem.values.skip(1)) ('back', b.name, (l) => l.copyWith(back: b)),
  for (final h in HeadFx.values.skip(1)) ('headFx', h.name, (l) => l.copyWith(headFx: h)),
  for (final f in FaceExtra.values) ('faceExtras', f.name, (l) => l.marked(f)),
  for (final e in EyeShine.values.skip(1)) ('eyeShine', e.name, (l) => l.copyWith(eyeShine: e, glasses: AvatarGlasses.none)),
  for (final d in HairDye.values.skip(1)) ('hairDye', d.name, (l) => l.copyWith(hairDye: d, hat: AvatarHead.slicked)),
  for (final i in HeldItem.values.skip(1)) ('held', i.name, (l) => l.holding(i, hand: Hand.right)),
  for (final f in FrontFx.values.skip(1)) ('frontFx', f.name, (l) => l.copyWith(frontFx: f)),
];

void _text(Canvas c, String s, Offset center, double size, Color color) {
  final tp = TextPainter(
    text: TextSpan(text: s, style: TextStyle(fontFamily: 'Georgia', fontSize: size, color: color, fontWeight: FontWeight.bold)),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
  tp.dispose();
}

Future<void> _save(ui.Picture picture, Size size, String path) async {
  final image = await picture.toImage(size.width.round(), size.height.round());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!.buffer.asUint8List());
}

/// One shop tile: the warm ground, the bust with its scene, the label.
void _tile(Canvas c, AvatarLook look, Offset at, double side, String label) {
  final r = at & Size.square(side);
  final rr = RRect.fromRectAndRadius(r, Radius.circular(side * 0.06));
  c.save();
  c.clipRRect(rr);
  c.drawRect(r, Paint()..shader = ui.Gradient.radial(r.center.translate(0, -side * 0.1), side * 0.7, const [Color(0xFF3A2A1E), Color(0xFF120C08)]));
  c.translate(at.dx, at.dy);
  LookPainter.bust(c, look, side);
  c.restore();
  c.drawRRect(rr, Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2
    ..color = const Color(0xFF8C6A26));
  _text(c, label, at + Offset(side / 2, side + 14), 13, const Color(0xFFD8C8B0));
}

/// The seat card at the table: the scene fills the arch, the bust sits in
/// its 86% square (as SeatCard and PlayerAvatar do).
void _seat(Canvas c, AvatarLook look, Offset at, double width) {
  final height = width * 1.32;
  final plate = max(20.0, width * 0.27);
  final portrait = Rect.fromLTWH(at.dx, at.dy, width, height - plate * 0.45);
  final arch = RRect.fromRectAndCorners(portrait, topLeft: Radius.circular(width / 2), topRight: Radius.circular(width / 2), bottomLeft: Radius.circular(width * 0.12), bottomRight: Radius.circular(width * 0.12));
  c.save();
  c.clipRRect(arch);
  c.drawRect(portrait, Paint()..shader = ui.Gradient.linear(portrait.topCenter, portrait.bottomCenter, const [Color(0xFF3A2A1E), Color(0xFF120C08)]));
  final a = width * 0.86;
  final square = Offset(portrait.left + (width - a) / 2, portrait.top + (portrait.height - a) * 0.45);
  c.save();
  c.translate(square.dx, square.dy);
  LookPainter.aura(c, look, a, area: portrait.shift(-square));
  LookPainter.bust(c, look, a, aura: false);
  c.restore();
  c.restore();
  c.drawRRect(arch, Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.4
    ..color = const Color(0xFF8C6A26));
  final plateRect = RRect.fromRectAndRadius(Rect.fromLTWH(at.dx - width * 0.08, at.dy + height - plate, width * 1.16, plate), Radius.circular(plate / 2));
  c.drawRRect(plateRect, Paint()..color = const Color(0xFF0C0907));
  c.drawRRect(plateRect, Paint()
    ..style = PaintingStyle.stroke
    ..color = const Color(0xFFD9B45A));
}

void main() {
  test('deep items contact sheet and table sheet', () async {
    final loader = FontLoader('Georgia');
    for (final file in ['Georgia.ttf', 'Georgia Bold.ttf']) {
      final f = File('/System/Library/Fonts/Supplemental/$file');
      if (f.existsSync()) loader.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
    }
    await loader.load();
    const side = 200.0;
    const gap = 16.0;
    const cols = 10;
    final rows = (_pieces.length / cols).ceil();
    final size = Size(cols * (side + gap) + gap, rows * (side + gap + 26) + gap);
    var rec = ui.PictureRecorder();
    var c = Canvas(rec);
    c.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF0E0B09));
    for (var i = 0; i < _pieces.length; i++) {
      final (slot, id, wear) = _pieces[i];
      final look = wear(_cast[i % _cast.length]);
      _tile(c, look, Offset(gap + (i % cols) * (side + gap), gap + (i ~/ cols) * (side + gap + 26)), side, '$slot.$id');
    }
    await _save(rec.endRecording(), size, '$out/contact.png');

    // The table: 74 px cards drawn at 3x, every piece once.
    const ratio = 3.0;
    const width = 74.0;
    const tcols = 16;
    final trows = (_pieces.length / tcols).ceil();
    final tsize = Size(tcols * (width + 18) + 18, trows * (width * 1.32 + 18) + 18);
    rec = ui.PictureRecorder();
    c = Canvas(rec);
    c.scale(ratio);
    c.drawRect(Offset.zero & tsize, Paint()..shader = ui.Gradient.radial(tsize.center(Offset.zero), tsize.longestSide * 0.7, const [Color(0xFF1F5B40), Color(0xFF0B2A1C)]));
    for (var i = 0; i < _pieces.length; i++) {
      final (_, _, wear) = _pieces[i];
      _seat(c, wear(_cast[i % _cast.length]), Offset(18 + (i % tcols) * (width + 18), 18 + (i ~/ tcols) * (width * 1.32 + 18)), width);
    }
    await _save(rec.endRecording(), tsize * ratio, '$out/table.png');
  });
}
