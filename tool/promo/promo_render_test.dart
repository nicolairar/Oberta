// The 15-second vertical short (Reels / TikTok / Shorts), frame by frame:
// `flutter test tool/promo/promo_render_test.dart` shoots the real game
// screens once, then composes 900 frames at 60 fps into build/promo/frames/
// (plus the poster), cut on the beat of assets/music/day.m4a.
// `swift tool/promo/encode.swift` turns them into the MP4 with the sound.
// FRAMES=0,90,500 renders only those frames; PLATES=1 also saves the plates.
// The script, scene by scene: docs/promo/short_15s.md.
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/ui/avatar/avatar_look.dart';
import 'package:oberta/ui/avatar/look_painter.dart';
import 'package:oberta/ui/avatar/seated_character.dart';
import 'package:oberta/ui/widgets/home_neon_sign.dart';
import 'package:oberta/l10n/app_language.dart';
import 'package:oberta/ui/widgets/noir_avatar.dart' show AvatarHead;
import 'package:oberta/ui/widgets/particle_sprites.dart';
import 'package:oberta/ui/widgets/verdict_scene.dart';

import 'promo_plates.dart';

const out = 'build/promo';
const fps = 60;
const length = 15.0;
const W = 1080.0, H = 1920.0;

/// day.m4a runs at 136.4 bpm: every cut sits on one of these.
const beat = 60 / 136.4;
double B(num n) => n * beat;

// ── the edit: when every scene starts ────────────────────────────────────
final hook = B(0), night = B(4), day = B(8), vote = B(12), verdict = B(15), reveal = B(19);
final shop = B(22), modes = B(27), cta = B(30);

// ── easing ───────────────────────────────────────────────────────────────
double clamp01(double x) => x.clamp(0.0, 1.0);
double outCubic(double x) => 1 - pow(1 - clamp01(x), 3).toDouble();
double inOutSine(double x) => -(cos(pi * clamp01(x)) - 1) / 2;
double outBack(double x) {
  const c1 = 1.70158, c3 = c1 + 1;
  final t = clamp01(x) - 1;
  return 1 + c3 * t * t * t + c1 * t * t;
}

double lerp(double a, double b, double t) => a + (b - a) * t;

// ── hits: shakes and flashes, all on beats ───────────────────────────────
final _shakes = <(double, double)>[
  (B(2), 38), (B(6), 12), (B(10), 10), (B(14), 18), (B(19), 56), //
  for (var i = 22; i < 27; i++) (B(i), 9),
  for (var i = 27; i < 30; i++) (B(i), 16),
  (B(30), 8),
];

Offset shakeAt(double t) {
  var dx = 0.0, dy = 0.0;
  for (final (at, amp) in _shakes) {
    final s = t - at;
    if (s < 0 || s > 0.6) continue;
    final a = amp * exp(-s * 9);
    dx += a * sin(s * 71 + at * 3);
    dy += a * cos(s * 59 + at * 5);
  }
  return Offset(dx, dy);
}

final _flashes = <(double, Color, double)>[
  (B(2), const Color(0xFFFF2E24), 0.45),
  (B(19), Colors.white, 0.85),
  (B(27), const Color(0xFFFFE9B0), 0.25),
];

// ── the cast of the shop: one absurd look per beat ───────────────────────
AvatarLook _look(String seed, {required AvatarHead hat, required String outfit, SkinTone tone = SkinTone.olive, FaceMark mark = FaceMark.clean, AvatarAccessory accessory = AvatarAccessory.none, AvatarGlasses glasses = AvatarGlasses.none}) =>
    AvatarLook.fallback(seed).copyWith(base: AvatarBase.of(tone, mark), hat: hat, outfit: AvatarOutfit.byId(outfit), accessory: accessory, glasses: glasses);

final _cast = <(AvatarLook, String)>[
  (_look('Banana', hat: AvatarHead.fishHead, outfit: 'banana_suit', mark: FaceMark.mustache).copyWith(aura: Aura.spaghettiStorm, eyeShine: EyeShine.spiral).holding(HeldItem.cannolo, hand: Hand.right), 'PESCE + BANANA'),
  (_look('Pizza', hat: AvatarHead.spaghettiHat, outfit: 'pizza_suit', tone: SkinTone.honey).copyWith(aura: Aura.vesuvio, headFx: HeadFx.coins, eyeShine: EyeShine.heart).holding(HeldItem.moka, hand: Hand.right), 'PIZZA BOSS'),
  (_look('Astro', hat: AvatarHead.astronautHelmet, outfit: 'gold_brocade', tone: SkinTone.umber).copyWith(back: BackItem.gildedWings, frontFx: FrontFx.sparkles, aura: Aura.sunburst), 'ASTRO PADRINO'),
  (_look('Unica', hat: AvatarHead.unicornHorn, outfit: 'clown_suit', tone: SkinTone.porcelain).copyWith(hairDye: HairDye.neonPop, aura: Aura.neonAlley, frontFx: FrontFx.petals).holding(HeldItem.cat), 'UNICORNO CLOWN'),
  (_look('Fuoco', hat: AvatarHead.flamingHair, outfit: 'delacroix_cape', tone: SkinTone.ivory, mark: FaceMark.goatee).copyWith(back: BackItem.dragonWings, aura: Aura.inferno, eyeShine: EyeShine.flame).holding(HeldItem.revolver, hand: Hand.right), 'DRAGO DI FUOCO'),
];

// ── the plates and the prepared layers ───────────────────────────────────
late Map<String, ui.Image> plates;
late ui.Image icon;
late ui.Image modesBg;
late List<ui.Image> grain;
ParticleSprites? sprites;

void main() {
  setUpAll(loadFonts);
  testWidgets('promo short', (tester) async {
    addTearDown(tester.view.reset);
    setView(tester);
    plates = await shootPlates(tester);
    if (Platform.environment['PLATES'] != null) {
      for (final e in plates.entries) {
        await savePng(tester, e.value, '$out/plates/${e.key}.png');
      }
    }
    final only = Platform.environment['FRAMES']?.split(',').map(int.parse).toList();
    await tester.runAsync(() async {
      sprites = await ParticleSprites.shared;
      icon = await _decode(File('assets/roles/mafioso.png').readAsBytesSync());
      modesBg = await _blurred(plates['vote']!);
      grain = [for (var i = 0; i < 6; i++) await _noise(Random(i))];
      final dir = Directory('$out/frames')..createSync(recursive: true);
      if (only == null) {
        for (final f in dir.listSync()) {
          f.deleteSync();
        }
      }
      final total = (length * fps).round();
      final watch = Stopwatch()..start();
      // With FRAMES, also a contact sheet of them, five to a row, at 1/4.
      final sheet = ui.PictureRecorder();
      final sheetCanvas = Canvas(sheet);
      var n = 0;
      for (final i in only ?? [for (var i = 0; i < total; i++) i]) {
        final image = await frame(i / fps);
        if (only != null) {
          sheetCanvas.drawImageRect(image, const Rect.fromLTWH(0, 0, W, H), Rect.fromLTWH(n % 5 * W / 4, n ~/ 5 * H / 4, W / 4, H / 4), Paint()..filterQuality = FilterQuality.medium);
          n++;
        }
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        File('${dir.path}/f_${i.toString().padLeft(4, '0')}.png').writeAsBytesSync(png!.buffer.asUint8List());
        if (i == (1.30 * fps).round()) File('$out/oberta_short_15s_poster.png').writeAsBytesSync(png.buffer.asUint8List());
        image.dispose();
        if (i % 60 == 0) debugPrint('frame $i  ${watch.elapsed.inSeconds}s');
      }
      if (only != null) {
        final rows = (n + 4) ~/ 5;
        final img = await sheet.endRecording().toImage((W / 4 * min(n, 5)).round(), (H / 4 * rows).round());
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        File('$out/contact.png').writeAsBytesSync(png!.buffer.asUint8List());
      }
    });
  }, timeout: const Timeout(Duration(minutes: 40)));
}

Future<ui.Image> _decode(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  return (await codec.getNextFrame()).image;
}

Future<ui.Image> _blurred(ui.Image src) async {
  final r = ui.PictureRecorder();
  final c = Canvas(r);
  c.drawImageRect(
    src,
    Rect.fromLTWH(0, 0, src.width.toDouble(), src.height.toDouble()),
    const Rect.fromLTWH(0, 0, W, H),
    Paint()
      ..imageFilter = ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22, tileMode: TileMode.clamp)
      ..colorFilter = const ColorFilter.mode(Color(0xB0100A08), BlendMode.srcATop),
  );
  return r.endRecording().toImage(W.toInt(), H.toInt());
}

/// A film-grain tile at half resolution, drawn stretched over the frame.
Future<ui.Image> _noise(Random random) {
  const w = 540, h = 960;
  final pixels = Uint8List(w * h * 4);
  for (var i = 0; i < w * h; i++) {
    final v = 128 + ((random.nextDouble() + random.nextDouble() - 1) * 110).round();
    pixels[i * 4] = v;
    pixels[i * 4 + 1] = v;
    pixels[i * 4 + 2] = v;
    pixels[i * 4 + 3] = 255;
  }
  final done = Completer<ui.Image>();
  ui.decodeImageFromPixels(pixels, w, h, ui.PixelFormat.rgba8888, done.complete);
  return done.future;
}

// ── one frame ────────────────────────────────────────────────────────────
Future<ui.Image> frame(double t) {
  final r = ui.PictureRecorder();
  final c = Canvas(r, const Rect.fromLTWH(0, 0, W, H));
  c.clipRect(const Rect.fromLTWH(0, 0, W, H));
  c.drawRect(const Rect.fromLTWH(0, 0, W, H), Paint()..color = const Color(0xFF0A0807));
  if (t < night) {
    _hook(c, t - hook);
  } else if (t < day) {
    _night(c, t - night);
  } else if (t < vote) {
    _day(c, t - day);
  } else if (t < verdict) {
    _vote(c, t - vote);
  } else if (t < reveal) {
    _verdict(c, t - verdict);
  } else if (t < shop) {
    _reveal(c, t - reveal);
  } else if (t < modes) {
    _shop(c, t - shop);
  } else if (t < cta) {
    _modes(c, t - modes);
  } else {
    _cta(c, t - cta);
  }
  _finish(c, t);
  return r.endRecording().toImage(W.toInt(), H.toInt());
}

/// Flashes, vignette and grain over everything.
void _finish(Canvas c, double t) {
  const all = Rect.fromLTWH(0, 0, W, H);
  for (final (at, color, peak) in _flashes) {
    final s = t - at;
    if (s < 0 || s > 0.35) continue;
    c.drawRect(all, Paint()..color = color.withValues(alpha: peak * pow(1 - s / 0.35, 2)));
  }
  c.drawRect(
    all,
    Paint()
      ..shader = ui.Gradient.radial(const Offset(W / 2, H * 0.47), H * 0.62, [
        Colors.transparent,
        Colors.transparent,
        Colors.black.withValues(alpha: 0.55),
      ], const [0, 0.55, 1]),
  );
  final g = grain[(t * fps).round() % grain.length];
  c.drawImageRect(
    g,
    Rect.fromLTWH(0, 0, g.width.toDouble(), g.height.toDouble()),
    all,
    Paint()
      ..blendMode = BlendMode.overlay
      ..color = const Color(0x1F000000)
      ..filterQuality = FilterQuality.none,
  );
}

// ── the camera over a plate, with motion blur when it moves fast ─────────
typedef Cam = ({Offset focus, double zoom, double angle});

void _plate(Canvas c, ui.Image img, Cam Function(double u) cam, double u, {ColorFilter? grade}) {
  final now = cam(u);
  final before = cam(u - 1 / fps);
  final speed = (now.zoom - before.zoom).abs() * 40 + (now.focus - before.focus).distance * 30 + (now.angle - before.angle).abs() * 30;
  final shake = shakeAt(_clock) - shakeAt(_clock - 1 / fps);
  final samples = speed + shake.distance / 25 > 0.05 ? 5 : 1;
  for (var k = 0; k < samples; k++) {
    final du = k / samples / fps;
    final at = cam(u - du);
    final paint = Paint()
      ..filterQuality = FilterQuality.medium
      ..colorFilter = grade
      ..color = Colors.white.withValues(alpha: 1 / (k + 1));
    _drawCam(c, img, at, shakeAt(_clock - du), paint);
  }
}

double _clock = 0;

void _drawCam(Canvas c, ui.Image img, Cam cam, Offset shake, Paint paint) {
  final pw = img.width.toDouble(), ph = img.height.toDouble();
  final s = cam.zoom * W / pw;
  final hx = W / 2 / s, hy = H / 2 / s;
  final fx = (cam.focus.dx * pw).clamp(hx, pw - hx);
  final fy = (cam.focus.dy * ph).clamp(hy, ph - hy);
  c.save();
  c.translate(W / 2 + shake.dx, H / 2 + shake.dy);
  c.rotate(cam.angle);
  c.scale(s * 1.02); // a little bleed, so the shake never shows an edge
  c.translate(-fx, -fy);
  c.drawImage(img, Offset.zero, paint);
  c.restore();
}

/// Every cut lands with a punch: the new shot starts a touch closer and
/// settles in a quarter of a second.
double punch(double u, [double amount = 0.14]) => 1 + amount * (1 - outCubic(u / 0.24));

// ── TikTok captions: bold, thick outline, centred in the safe area ───────
const _cx = W * 0.47; // a little left of centre: the app's buttons sit right
const _maxW = W * 0.80;
const yellow = Color(0xFFFFD54A);
const red = Color(0xFFFF3B30);
const cream = Color(0xFFFFF4E0);

ui.Paragraph _para(List<(String, Color)> spans, double size, {Paint? stroke}) {
  final b = ui.ParagraphBuilder(ui.ParagraphStyle(textAlign: TextAlign.center, fontFamily: 'Georgia', height: 1.05));
  for (final (text, color) in spans) {
    b.pushStyle(
      ui.TextStyle(
        fontFamily: 'Georgia',
        fontSize: size,
        fontWeight: FontWeight.w700,
        letterSpacing: size * 0.01,
        foreground: stroke ?? (Paint()..color = color),
      ),
    );
    b.addText(text);
    b.pop();
  }
  final p = b.build()..layout(const ui.ParagraphConstraints(width: 6000));
  return p..layout(ui.ParagraphConstraints(width: p.longestLine.ceilToDouble() + 2));
}

/// One line of caption, popping in at [since] seconds (negative: not yet).
void caption(Canvas c, List<(String, Color)> spans, double y, double since, {double size = 104, double tilt = 0, double out = 99}) {
  if (since < 0) return;
  final pop = since < 0.2 ? lerp(1.45, 1, outBack(since / 0.2)) : 1.0;
  final alpha = clamp01(since / 0.05) * clamp01((out) / 0.06);
  if (alpha <= 0) return;
  var fill = _para(spans, size);
  if (fill.longestLine > _maxW) {
    size *= _maxW / fill.longestLine;
    fill = _para(spans, size);
  }
  final stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = size * 0.2
    ..strokeJoin = StrokeJoin.round
    ..color = Colors.black;
  final edge = _para(spans, size, stroke: stroke);
  final shadow = _para(spans, size, stroke: Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = size * 0.2
    ..strokeJoin = StrokeJoin.round
    ..color = Colors.black.withValues(alpha: 0.5)
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, size * 0.12));
  final w = fill.width, h = fill.height;
  c.save();
  c.translate(_cx, y);
  c.rotate(tilt);
  c.scale(pop);
  c.saveLayer(Rect.fromCenter(center: Offset.zero, width: w + size, height: h + size), Paint()..color = Colors.white.withValues(alpha: alpha));
  final at = Offset(-w / 2, -h / 2);
  c.drawParagraph(shadow, at + Offset(0, size * 0.08));
  c.drawParagraph(edge, at);
  c.drawParagraph(fill, at);
  c.restore();
  c.restore();
}

// ── 1 · the hook ─────────────────────────────────────────────────────────
const _noir = ColorFilter.matrix([
  0.75, 0.35, 0.05, 0, 6, //
  0.10, 0.55, 0.05, 0, 0,
  0.08, 0.20, 0.45, 0, 0,
  0, 0, 0, 1, 0,
]);

/// The friend at the table: a nice smile, until the beat drops.
final _friend = _look('Tonino', hat: AvatarHead.coppola, outfit: 'grey_flannel', tone: SkinTone.olive, accessory: AvatarAccessory.scarf);
final _mafioso = _friend.copyWith(
  hat: AvatarHead.fedora,
  outfit: AvatarOutfit.byId('charcoal_pinstripe'),
  accessory: AvatarAccessory.cigar,
  glasses: AvatarGlasses.shades,
  base: AvatarBase.of(SkinTone.olive, FaceMark.scar),
  aura: Aura.inferno,
);

void _hook(Canvas c, double u) {
  _clock = hook + u;
  final turned = u >= B(2);
  const all = Rect.fromLTWH(0, 0, W, H);
  // The table at night behind him, blurred and dark.
  _plate(c, plates['night']!, (u) => (focus: const Offset(0.5, 0.31), zoom: 2.2 * punch(u, 0.2), angle: 0), u, grade: _noir);
  c.drawRect(all, Paint()..color = Colors.black.withValues(alpha: 0.68));
  // One lamp over him.
  c.drawRect(
    all,
    Paint()
      ..shader = ui.Gradient.radial(const Offset(W / 2, H * 0.30), H * 0.5, [
        (turned ? const Color(0xFFFF3B30) : const Color(0xFFFFD27A)).withValues(alpha: turned ? 0.45 : 0.30),
        Colors.transparent,
      ]),
  );
  final s = W / 1.3 * 0.98;
  final shake = shakeAt(_clock);
  final hit = turned ? 0.10 * (1 - outCubic((u - B(2)) / 0.3)) : 0.0;
  final zoom = lerp(1.25, 1.0, outCubic(u / 0.35)) + hit + u * 0.03;
  final samples = u < 0.3 || (turned && u - B(2) < 0.15) ? 4 : 1;
  for (var k = samples - 1; k >= 0; k--) {
    final du = k / samples / fps;
    final z = lerp(1.25, 1.0, outCubic((u - du) / 0.35)) + hit + u * 0.03;
    c.save();
    c.translate(W / 2 + shake.dx, H * 0.86 + shake.dy);
    c.scale(k == 0 ? zoom : z);
    c.translate(-W / 2, -H * 0.86);
    if (k > 0) c.saveLayer(all, Paint()..color = Colors.white.withValues(alpha: 0.3));
    SeatedCharacterPainter(
      look: turned ? _mafioso : _friend,
      base: Offset(W / 2, H * 0.86),
      size: s,
      time: ValueNotifier(u * 1.4 + 2),
      phase: 211,
      lit: true,
      edge: true,
    ).paint(c, const Size(W, H));
    if (k > 0) c.restore();
    c.restore();
  }
  caption(c, const [('UNO DEI TUOI ', Colors.white), ('AMICI', yellow)], H * 0.15, u + 0.2, size: 100);
  caption(c, const [('È UN MAFIOSO.', red)], H * 0.245, u - B(2), size: 132, tilt: -0.03);
}

// ── 2 · night: the family chat ───────────────────────────────────────────
void _night(Canvas c, double u) {
  _clock = night + u;
  // The table, then a punch on "who do you kill tonight?" on the second beat.
  _plate(c, plates['night']!, (u) {
    final go = outCubic((u - B(2)) / 0.25);
    return (
      focus: Offset(0.5, lerp(0.33, 0.315, go)),
      zoom: lerp(1.5, 2.25, go) * punch(u) + u * 0.03,
      angle: -0.02 * go,
    );
  }, u);
  caption(c, const [('DI NOTTE', Colors.white)], H * 0.64, u - 0.02, size: 112);
  caption(c, const [('LA ', Colors.white), ('FAMIGLIA', red), (' UCCIDE.', Colors.white)], H * 0.725, u - B(1));
}

// ── 3 · day: the table, white seat numbers ───────────────────────────────
void _day(Canvas c, double u) {
  _clock = day + u;
  _plate(c, plates['day']!, (u) => (
    focus: const Offset(0.5, 0.32),
    zoom: 1.42 * punch(u) + inOutSine(u / B(4)) * 0.12,
    angle: 0,
  ), u);
  caption(c, const [('DI GIORNO', Colors.white)], H * 0.46, u - 0.02);
  caption(c, const [('SI ', Colors.white), ('ACCUSA.', yellow)], H * 0.55, u - B(1));
}

// ── 4 · the vote: push on the accused ────────────────────────────────────
void _vote(Canvas c, double u) {
  _clock = vote + u;
  _plate(c, plates['vote']!, (u) {
    final go = inOutSine((u - B(1)) / B(1.2));
    return (
      focus: Offset.lerp(const Offset(0.5, 0.32), const Offset(0.30, 0.42), go)!,
      zoom: lerp(1.42, 2.15, go) * punch(u, 0.1),
      angle: -0.015 * go,
    );
  }, u);
  caption(c, const [('VOTA CHI ', Colors.white), ('MENTE.', red)], H * 0.24, u - 0.02);
}

// ── 5 · the verdict film, the game's own ─────────────────────────────────
void _verdict(Canvas c, double u) {
  _clock = verdict + u;
  final d = B(4);
  final zoom = lerp(1.22, 1.38, inOutSine(u / d)) * punch(u, 0.08);
  final sky = plates['verdictSky']!;
  final shake = shakeAt(_clock);
  c.save();
  c.translate(W / 2 + shake.dx, H * 0.70 + shake.dy);
  c.scale(zoom);
  c.translate(-W / 2, -H * 0.70);
  c.drawImageRect(sky, Rect.fromLTWH(0, 0, sky.width.toDouble(), sky.height.toDouble()), const Rect.fromLTWH(0, 0, W, H), Paint()..filterQuality = FilterQuality.medium);
  c.scale(W / logical.width);
  // The film, sped up: from the walk to the splash.
  final film = lerp(0.20, 0.80, u / d);
  VerdictScenePainter(t: film, take: VerdictTake.molo, strings: AppLanguage.it.strings, hat: AvatarHead.fedora, town: 'Palermo', sprites: sprites)
      .paint(c, logical);
  c.restore();
  caption(c, const [('E IL ', Colors.white), ('CONDANNATO', yellow), ('…', Colors.white)], H * 0.20, u - 0.02);
  // Cut to black on the last half beat, before the reveal.
  final dark = clamp01((u - (d - beat * 0.5)) / (beat * 0.5));
  if (dark > 0) c.drawRect(const Rect.fromLTWH(0, 0, W, H), Paint()..color = Colors.black.withValues(alpha: dark));
}

// ── 6 · the reveal ───────────────────────────────────────────────────────
void _reveal(Canvas c, double u) {
  _clock = reveal + u;
  final shake = shakeAt(_clock);
  const all = Rect.fromLTWH(0, 0, W, H);
  c.drawRect(
    all,
    Paint()
      ..shader = ui.Gradient.radial(Offset(W / 2, H * 0.40), H * 0.55, [
        const Color(0xFF7A0A0A),
        const Color(0xFF2A0405),
        const Color(0xFF070203),
      ], const [0, 0.5, 1]),
  );
  // Light rays turning slowly behind the card.
  c.save();
  c.translate(W / 2, H * 0.38);
  c.rotate(u * 0.35);
  final ray = Paint()..color = const Color(0x16FFD27A);
  for (var i = 0; i < 12; i++) {
    c.rotate(pi / 6);
    c.drawPath(Path()..moveTo(0, 0)..lineTo(-70, -H)..lineTo(70, -H)..close(), ray);
  }
  c.restore();
  // The role icon slams in, with a trail.
  final side = W * 0.46;
  for (var k = 4; k >= 0; k--) {
    final at = u - k / fps / 2;
    final s = lerp(2.6, 1, outCubic(at / 0.16));
    if (at < 0) continue;
    c.save();
    c.translate(W / 2 + shake.dx, H * 0.37 + shake.dy);
    c.scale(s * (1 + 0.02 * sin(u * 9)));
    c.rotate(lerp(-0.25, -0.04, outCubic(at / 0.16)));
    final rect = Rect.fromCenter(center: Offset.zero, width: side, height: side);
    c.drawCircle(Offset.zero, side * 0.62, Paint()..color = Colors.black.withValues(alpha: 0.35 / (k + 1)));
    c.drawImageRect(icon, const Rect.fromLTWH(0, 0, 250, 250), rect, Paint()
      ..filterQuality = FilterQuality.high
      ..color = Colors.white.withValues(alpha: k == 0 ? 1 : 0.18));
    c.restore();
  }
  caption(c, const [('ERA IL', Colors.white)], H * 0.585, u - 0.04, size: 88);
  caption(c, const [('PICCIOTTO.', red)], H * 0.665, u - 0.10, size: 150, tilt: -0.04);
}

// ── 7 · the shop: one absurd boss per beat ───────────────────────────────
void _shop(Canvas c, double u) {
  _clock = shop + u;
  final i = (u / beat).floor().clamp(0, _cast.length - 1);
  final local = u - i * beat;
  const all = Rect.fromLTWH(0, 0, W, H);
  final hues = [0xFF3A2A1E, 0xFF3E1A12, 0xFF14243A, 0xFF2E1438, 0xFF3A1208];
  c.drawRect(
    all,
    Paint()
      ..shader = ui.Gradient.radial(Offset(W / 2, H * 0.45), H * 0.6, [Color(hues[i]), const Color(0xFF0C0806)]),
  );
  final (look, label) = _cast[i];
  final shake = shakeAt(_clock);
  final side = W * 0.84;
  final trail = local < 0.12 ? 4 : 1;
  for (var k = trail - 1; k >= 0; k--) {
    final at = local - k / fps / 1.5;
    final s = lerp(1.35, 1, outCubic(at / 0.2)) * (1 + 0.015 * sin(u * 6));
    c.save();
    c.translate(W / 2 + shake.dx, H * 0.50 + shake.dy);
    c.scale(s);
    c.rotate((i.isEven ? 1 : -1) * lerp(0.08, 0.02, outCubic(at / 0.2)));
    c.translate(-side / 2, -side / 2);
    if (k > 0) {
      c.saveLayer(Rect.fromLTWH(-side * 0.5, -side * 0.5, side * 2, side * 2), Paint()..color = Colors.white.withValues(alpha: 0.25));
    }
    LookPainter.bust(c, look, side);
    if (k > 0) c.restore();
    c.restore();
  }
  caption(c, const [('LA ', Colors.white), ('BOTTEGA', yellow)], H * 0.14, u, size: 96);
  caption(c, [(label, cream)], H * 0.225, local - 0.03, size: 72);
}

// ── 8 · the modes: three Targa plates, one per beat ──────────────────────
void _modes(Canvas c, double u) {
  _clock = modes + u;
  final shake = shakeAt(_clock);
  c.drawImage(modesBg, Offset(shake.dx * 0.3, shake.dy * 0.3), Paint());
  caption(c, const [('GIOCA ', Colors.white), ('COME VUOI', yellow)], H * 0.18, u, size: 96);
  final names = ['amici', 'classificata', 'telefono'];
  for (var i = 0; i < 3; i++) {
    final at = u - B(i);
    if (at < 0) continue;
    final img = plates['targa_${names[i]}']!;
    final w = W * 0.84;
    final h = w * img.height / img.width;
    final y = H * (0.34 + i * 0.13);
    final drop = lerp(-H * 0.25, 0, outBack(at / 0.22));
    for (var k = at < 0.15 ? 3 : 0; k >= 0; k--) {
      final dy = lerp(-H * 0.25, 0, outBack((at - k / fps) / 0.22));
      c.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        Rect.fromCenter(center: Offset(_cx + shake.dx, y + (k == 0 ? drop : dy) + shake.dy), width: w, height: h),
        Paint()
          ..filterQuality = FilterQuality.high
          ..color = Colors.white.withValues(alpha: k == 0 ? 1 : 0.2),
      );
    }
  }
}

// ── 9 · the neon sign and the CTA, then dark again for the loop ──────────
final _neon = HomeNeonState();

void _cta(Canvas c, double u) {
  _clock = cta + u;
  final d = length - cta;
  final intro = 0.85 + u * 1.6;
  var power = HomeNeonSign.powerAt(1.0, intro);
  // The last quarter second: the sign shorts out, back to the dark open.
  final end = u - (d - 0.28);
  if (end > 0) {
    final jolt = end > 0.2 ? 0.0 : HomeNeonSign.shortAt(end / 0.2);
    power = [for (final p in power) p * jolt];
  }
  _neon.set(power);
  final glow = _neon.glow;
  _bricks(c, glow);
  final cap = W * 0.80 / HomeNeonSign.width;
  final sign = Rect.fromCenter(center: const Offset(_cx, H * 0.36), width: HomeNeonSign.width * cap, height: HomeNeonSign.height * cap);
  final shake = shakeAt(_clock);
  c.save();
  c.translate(shake.dx, shake.dy);
  final zoom = lerp(1.12, 1.0, outCubic(u / 0.5));
  c.translate(_cx, H * 0.36);
  c.scale(zoom);
  c.translate(-_cx, -H * 0.36);
  HomeNeonPainter(sign: sign, cap: cap, state: _neon).paint(c, const Size(W, H));
  c.restore();
  final out = end > 0.1 ? -1.0 : 99.0;
  caption(c, const [('GRATIS', yellow)], H * 0.53, u - B(1), size: 140, out: out);
  caption(c, const [('IPHONE • STEAM', Colors.white)], H * 0.625, u - B(2), size: 100, out: out);
}

void _bricks(Canvas c, double glow) {
  const all = Rect.fromLTWH(0, 0, W, H);
  c.drawRect(all, Paint()..color = const Color(0xFF120B0A));
  const bw = 150.0, bh = 62.0;
  final brick = Paint();
  final rnd = Random(7);
  for (var row = 0; row * bh < H; row++) {
    final shift = row.isEven ? 0.0 : bw / 2;
    for (var x = -shift; x < W; x += bw) {
      final v = rnd.nextDouble();
      brick.color = Color.lerp(const Color(0xFF2A1714), const Color(0xFF3A1E18), v)!;
      c.drawRect(Rect.fromLTWH(x + 3, row * bh + 3, bw - 6, bh - 6), brick);
    }
  }
  c.drawRect(
    all,
    Paint()
      ..shader = ui.Gradient.radial(const Offset(_cx, H * 0.36), H * 0.55, [
        const Color(0xFFFF2E24).withValues(alpha: 0.28 * glow),
        Colors.black.withValues(alpha: 0.35),
        Colors.black.withValues(alpha: 0.85),
      ], const [0, 0.45, 1]),
  );
}
