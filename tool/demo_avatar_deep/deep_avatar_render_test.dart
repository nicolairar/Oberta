// DEMO: deep avatar customisation. Six showcase characters, each wearing
// most of the proposed slots (tool/demo_avatar_deep/slots.dart), drawn with
// the live cartoon-noir bust (LookPainter.bust) plus demo painters for the
// new slots (deep_painters.dart). Nothing in lib/ changes.
//
// `flutter test tool/demo_avatar_deep/deep_avatar_render_test.dart` writes
// build/demo_avatar_deep/{shop_busts,table,layers}.png and one
// bust_<name>.png per character.
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/ui/avatar/avatar_look.dart' hide HairDye;
import 'package:oberta/ui/avatar/look_painter.dart';
import 'package:oberta/ui/widgets/noir_avatar.dart' show AvatarHead;

import 'deep_painters.dart';
import 'slots.dart';

final out = Platform.environment['OUT'] ?? 'build/demo_avatar_deep';

AvatarLook _look(
  String seed, {
  SkinTone tone = SkinTone.olive,
  FaceMark mark = FaceMark.clean,
  AvatarHead hat = AvatarHead.slicked,
  AvatarGlasses glasses = AvatarGlasses.none,
  required String outfit,
  AvatarAccessory accessory = AvatarAccessory.none,
  required FaceFeatures features,
}) =>
    AvatarLook.fallback(seed)
        .copyWith(base: AvatarBase.of(tone, mark), hat: hat, glasses: glasses, outfit: AvatarOutfit.byId(outfit) ?? AvatarOutfit.catalog.first, accessory: accessory, features: features);

final cast = <DeepLook>[
  DeepLook(
    name: 'Don Fuoco',
    look: _look(
      'Vito',
      hat: AvatarHead.fedora,
      mark: FaceMark.mustache,
      outfit: 'charcoal_pinstripe',
      accessory: AvatarAccessory.tie,
      features: const FaceFeatures(hair: HairStyle.slicked, hairColor: HairColor.black, presentation: Presentation.man, shape: FaceShape.square, brows: BrowShape.angled),
    ),
    aura: 'inferno',
    back: 'violinCase',
    headFx: 'sparks',
    faceExtras: {'stitchScar', 'goldTooth'},
    eyeShine: 'glint',
    heldRight: 'revolver',
    frontFx: 'smokeRings',
    frame: 'deco',
  ),
  DeepLook(
    name: 'La Luna',
    look: _look(
      'Luna',
      tone: SkinTone.porcelain,
      outfit: 'black_dress',
      accessory: AvatarAccessory.pearls,
      features: const FaceFeatures(
        hair: HairStyle.fingerWaves,
        hairColor: HairColor.platinum,
        presentation: Presentation.woman,
        mouth: MouthShape.lipstick,
        lips: LipColor.red,
        shape: FaceShape.heart,
        shadow: EyeShadow.smoky,
      ),
    ),
    aura: 'moon',
    headFx: 'starOrbit',
    dye: const HairDye(Color(0xFF6A7CE8), Color(0xFF8A3AB8)),
    faceExtras: {'beautyStar', 'blush'},
    eyeShine: 'star',
    heldLeft: 'rose',
    heldRight: 'coupe',
    frontFx: 'petals',
    frame: 'silverMoon',
  ),
  DeepLook(
    name: 'Il Santo',
    look: _look(
      'Santo',
      tone: SkinTone.umber,
      mark: FaceMark.fullBeard,
      outfit: 'cream_dinner',
      accessory: AvatarAccessory.bowTie,
      features: const FaceFeatures(hair: HairStyle.curly, hairColor: HairColor.white, presentation: Presentation.man, age: FaceAge.lines, shape: FaceShape.round),
    ),
    aura: 'sunburst',
    back: 'decoWings',
    headFx: 'halo',
    faceExtras: {'tear'},
    heldLeft: 'candle',
    heldRight: 'grappa',
    frontFx: 'sparkles',
    frame: 'cathedral',
  ),
  DeepLook(
    name: 'Lo Scheletro',
    look: _look(
      'Ossa',
      tone: SkinTone.ivory,
      outfit: 'midnight_double',
      accessory: AvatarAccessory.tie,
      features: const FaceFeatures(hair: HairStyle.pompadour, hairColor: HairColor.platinum, presentation: Presentation.man, shape: FaceShape.long),
    ),
    aura: 'neon',
    back: 'skeleton',
    headFx: 'horns',
    glow: const Color(0xFF3FE0D0),
    dye: const HairDye(Color(0xFF3FE0D0), Color(0xFFFF4FA3)),
    faceExtras: {'skullPaint'},
    eyeShine: 'spiral',
    heldRight: 'cards',
    frontFx: 'bats',
    frame: 'neonTube',
  ),
  DeepLook(
    name: 'Nonna Gatta',
    look: _look(
      'Nonna',
      tone: SkinTone.rose,
      hat: AvatarHead.wideBrim,
      glasses: AvatarGlasses.round,
      outfit: 'powder_blouse',
      accessory: AvatarAccessory.pearls,
      features: const FaceFeatures(hair: HairStyle.bun, hairColor: HairColor.grey, presentation: Presentation.woman, age: FaceAge.lines, mouth: MouthShape.smile, shape: FaceShape.round),
    ),
    aura: 'smoke',
    back: 'parasol',
    headFx: 'hearts',
    faceExtras: {'blush', 'freckles'},
    eyeShine: 'heart',
    heldBoth: 'cat',
    frontFx: 'yarn',
    frame: 'lace',
  ),
  DeepLook(
    name: 'Mister Oro',
    look: _look(
      'Oro',
      tone: SkinTone.honey,
      hat: AvatarHead.topHat,
      glasses: AvatarGlasses.monocle,
      outfit: 'gold_brocade',
      accessory: AvatarAccessory.carnation,
      features: const FaceFeatures(hair: HairStyle.curly, hairColor: HairColor.platinum, presentation: Presentation.man, mouth: MouthShape.smirk),
    ),
    aura: 'marquee',
    back: 'saxophone',
    headFx: 'coins',
    dye: const HairDye(Color(0xFFFFD27A), Color(0xFFB8501E)),
    faceExtras: {'goldTooth'},
    eyeShine: 'dollar',
    heldBoth: 'teddy',
    frontFx: 'sparkles',
    frame: 'bulbs',
  ),
];

/// How far the build-up goes (for the layers sheet): each stage adds one
/// group of slots.
enum Stage { base, aura, back, head, face, held, front, all }

/// The whole composition in a square of [side] logical pixels.
void paintDeep(Canvas c, DeepLook d, double side, {bool table = false, Stage upTo = Stage.all}) {
  ow = max(0.022, 2.2 / side);
  thin = max(0.008, 1.0 / side);
  // The bust shrinks toward the bottom centre so the aura, back items and
  // held items have room around it.
  final z = table ? 0.9 : 0.82;
  final g = Geo.of(d);
  bool on(Stage s) => upTo.index >= s.index;
  final small = side * z < 110;
  c.save();
  c.scale(side);
  if (on(Stage.aura)) paintAura(c, d.aura, g.map(z), table: table);
  c.restore();
  c.save();
  c.translate(side * (1 - z) / 2, side * (1 - z));
  side *= z;
  c.save();
  c.scale(side);
  if (on(Stage.back) && d.back != null) paintBack(c, d.back!, g, d.look.outfit.coat);
  c.restore();
  if (on(Stage.head) && d.glow != null) paintHeadGlow(c, d, side, d.glow!);
  LookPainter.bust(c, d.look, side);
  if (on(Stage.head) && d.dye != null) paintHairDye(c, d, side, d.dye!, g);
  c.save();
  c.scale(side);
  if (on(Stage.face)) {
    paintFaceExtras(c, d.faceExtras, g, small: small);
    if (d.eyeShine != null && !(small && d.eyeShine == 'dollar')) paintEyeShine(c, d.eyeShine!, g);
  }
  if (on(Stage.head) && d.headFx != null) paintHeadFx(c, d.headFx!, g);
  if (on(Stage.held)) {
    final skin = d.look.base.skin;
    final sleeve = d.look.outfit.coat;
    if (d.heldBoth != null) {
      paintHeldBoth(c, d.heldBoth!, g, sleeve: sleeve, skin: skin);
    } else {
      if (d.heldLeft != null) paintHeld(c, d.heldLeft!, g, side: -1, sleeve: sleeve, skin: skin);
      if (d.heldRight != null) paintHeld(c, d.heldRight!, g, side: 1, sleeve: sleeve, skin: skin);
    }
  }
  if (on(Stage.front) && d.frontFx != null) paintFrontFx(c, d.frontFx!, g, table: table);
  c.restore();
  c.restore();
}

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

void _text(Canvas c, String s, Offset center, double size, Color color, {bool bold = true, double spacing = 1}) {
  final tp = TextPainter(
    text: TextSpan(
      text: s,
      style: TextStyle(fontFamily: 'Georgia', fontSize: size, fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: color, letterSpacing: spacing),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
  tp.dispose();
}

/// One shop tile: the composition clipped to a rounded square, the frame.
void _tile(Canvas c, DeepLook d, Offset at, double side) {
  final r = at & Size.square(side);
  final rr = RRect.fromRectAndRadius(r, Radius.circular(side * 0.05));
  c.save();
  c.clipRRect(rr);
  c.translate(at.dx, at.dy);
  paintDeep(c, d, side);
  c.restore();
  paintFrame(c, d.frame, r);
}

Future<void> _shop(String path) async {
  const side = 600.0;
  const gap = 40.0;
  const caption = 70.0;
  const cols = 3;
  final rows = (cast.length / cols).ceil();
  final size = Size(cols * (side + gap) + gap, rows * (side + gap + caption) + gap);
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  c.drawRect(Offset.zero & size, fill(const Color(0xFF14110F)));
  for (var i = 0; i < cast.length; i++) {
    final at = Offset(gap + (i % cols) * (side + gap), gap + (i ~/ cols) * (side + gap + caption));
    _tile(c, cast[i], at, side);
    _text(c, cast[i].name.toUpperCase(), at + Offset(side / 2, side + 26), 28, cream, spacing: 3);
    final d = cast[i];
    final kit = [
      d.aura,
      d.back,
      d.headFx,
      d.heldBoth ?? [d.heldLeft, d.heldRight].whereType<String>().join(' + '),
      d.frontFx,
    ].whereType<String>().join('  ·  ');
    _text(c, kit, at + Offset(side / 2, side + 56), 17, const Color(0xFFB8A890), bold: false, spacing: 0.5);
  }
  await _save(rec.endRecording(), size.width.round(), size.height.round(), path);
}

Future<void> _single(DeepLook d, String path) async {
  const side = 600.0;
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  c.drawRect(const Rect.fromLTWH(0, 0, side + 40, side + 40), fill(const Color(0xFF14110F)));
  _tile(c, d, const Offset(20, 20), side);
  await _save(rec.endRecording(), (side + 40).round(), (side + 40).round(), path);
}

/// The seat card at table size (74 px card, 64 px portrait, drawn at 3x):
/// the aura fills the arch, the frame colours its edge.
void _seat(Canvas c, Offset at, double width, DeepLook d) {
  const ink = Color(0xFF0C0907);
  final height = width * 1.32;
  final plate = max(20.0, width * 0.27);
  c.save();
  c.translate(at.dx, at.dy);
  final portrait = Rect.fromLTWH(0, 0, width, height - plate * 0.45);
  final arch = RRect.fromRectAndCorners(
    portrait,
    topLeft: Radius.circular(width / 2),
    topRight: Radius.circular(width / 2),
    bottomLeft: Radius.circular(width * 0.12),
    bottomRight: Radius.circular(width * 0.12),
  );
  c.drawRRect(arch.shift(const Offset(0, 4)), fill(const Color(0x88000000)));
  c.save();
  c.clipRRect(arch);
  c.drawRect(portrait, fill(const Color(0xFF120C08)));
  final a = width * 0.86;
  // The aura fills the whole arch, so paint it on a larger square.
  c.save();
  c.translate((width - a) / 2, (portrait.height - a) * 0.45);
  paintDeep(c, d, a, table: true);
  c.restore();
  c.restore();
  final accent = frameAccent(d.frame);
  c.drawRRect(
    arch.deflate(0.7),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..color = accent,
  );
  final plateRect = RRect.fromRectAndRadius(Rect.fromLTWH(-width * 0.08, height - plate, width * 1.16, plate), Radius.circular(plate / 2));
  c.drawRRect(plateRect, fill(ink));
  c.drawRRect(
    plateRect.deflate(0.5),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = accent,
  );
  final first = d.name.split(' ').last.toUpperCase();
  _text(c, first, plateRect.center, plate * 0.5, cream, spacing: 0.6);
  c.restore();
}

Future<void> _table(String path) async {
  const ratio = 3.0;
  const width = 74.0;
  const gap = 20.0;
  final size = Size(cast.length * (width + gap) + gap, width * 1.32 + gap * 2);
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  c.scale(ratio);
  c.drawRect(Offset.zero & size, Paint()..shader = const RadialGradient(colors: [Color(0xFF1F5B40), Color(0xFF0B2A1C)], radius: 1.2).createShader(Offset.zero & size));
  for (var i = 0; i < cast.length; i++) {
    _seat(c, Offset(gap + i * (width + gap), gap), width, cast[i]);
  }
  await _save(rec.endRecording(), (size.width * ratio).round(), (size.height * ratio).round(), path);
}

/// One character built up slot group by slot group.
Future<void> _layers(DeepLook d, String path) async {
  const side = 300.0;
  const gap = 20.0;
  const caption = 40.0;
  final stages = Stage.values;
  final size = Size(stages.length * (side + gap) + gap, side + caption + gap * 2);
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  c.drawRect(Offset.zero & size, fill(const Color(0xFF14110F)));
  const labels = ['live bust', '+ aura', '+ back item', '+ head fx, dye', '+ face extras, eyes', '+ held items', '+ front fx', '+ frame'];
  for (var i = 0; i < stages.length; i++) {
    final at = Offset(gap + i * (side + gap), gap);
    final r = at & const Size.square(side);
    final rr = RRect.fromRectAndRadius(r, const Radius.circular(15));
    c.save();
    c.clipRRect(rr);
    c.drawRect(r, Paint()..shader = const RadialGradient(center: Alignment(0, -0.3), colors: [Color(0xFF3A2A1E), Color(0xFF120C08)]).createShader(r));
    c.translate(at.dx, at.dy);
    paintDeep(c, d, side, upTo: stages[i]);
    c.restore();
    if (stages[i] == Stage.all) paintFrame(c, d.frame, r);
    _text(c, labels[i], at + const Offset(side / 2, side + 24), 17, const Color(0xFFB8A890), bold: false);
  }
  await _save(rec.endRecording(), size.width.round(), size.height.round(), path);
}

void main() {
  test('deep avatar demo', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _fonts();
    await _shop('$out/shop_busts.png');
    await _table('$out/table.png');
    await _layers(cast[0], '$out/layers_fuoco.png');
    await _layers(cast[3], '$out/layers_scheletro.png');
    for (final d in cast) {
      await _single(d, '$out/bust_${d.name.toLowerCase().replaceAll(' ', '_')}.png');
    }
    // Every slot appears in the slot list, in z order.
    expect(DeepSlot.values.first, DeepSlot.aura);
    expect(DeepSlot.values.last, DeepSlot.frame);
  });
}
