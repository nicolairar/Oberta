// The vertical POV short (Reels / TikTok / Shorts), frame by frame:
// `flutter test tool/promo/promo_render_test.dart` shoots the real game
// screens once, then composes every frame at 60 fps into build/promo/frames/
// (plus the poster), cut on the beat of assets/music/day.m4a.
// Before it: `swift tool/promo/badges.swift` (the store badges); after it:
// `swift tool/promo/encode.swift` (the MP4 with the sound).
// FRAMES=0,90,500 renders only those frames and a contact sheet of them;
// PLATES=1 also saves the plates; PAYOFF=detto|mamma|sangue picks the line.
// The script, scene by scene: docs/promo/short_pov.md.
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/l10n/app_language.dart';
import 'package:oberta/ui/avatar/avatar_look.dart';
import 'package:oberta/ui/avatar/look_painter.dart';
import 'package:oberta/ui/avatar/seated_character.dart';
import 'package:oberta/ui/widgets/home_neon_sign.dart';
import 'package:oberta/ui/widgets/noir_avatar.dart' show AvatarHead;
import 'package:oberta/ui/widgets/particle_sprites.dart';
import 'package:oberta/ui/widgets/verdict_scene.dart';

import 'promo_plates.dart';

const out = 'build/promo';
const fps = 60;
const W = 1080.0, H = 1920.0;

/// day.m4a runs at 136.4 bpm: every cut and every hit sits on one of these.
const beat = 60 / 136.4;
double B(num n) => n * beat;

// ── the edit (in beats; encode.swift uses the same numbers) ──────────────
final hook = B(0), table = B(6), votes = B(13), lynch = B(24), flip = B(33), payoff = B(41), wardrobe = B(47), end = B(55);
final length = B(64);

/// Straight from the river to the card: it lands face up on beat 34.
final face = B(34) - flip;

// ── the payoff line: PAYOFF=detto (default) | mamma | sangue ─────────────
// Each is two lines; the last word lands alone, on beat 43, with a zoom hit.
const _payoffs = {
  'detto': (["TE", "L'AVEVO"], 'DETTO.'),
  'mamma': (['MAMMA', 'NON', 'DEVE'], 'SAPERLO.'),
  'sangue': (['IL', 'SANGUE', 'NON', 'È'], 'ACQUA.'),
};
final _payoff = _payoffs[Platform.environment['PAYOFF'] ?? 'detto']!;

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

// ── hits: shakes and flashes ─────────────────────────────────────────────
final _voteTicks = [for (var i = 0; i < 6; i++) B(16 + i)];
final _shakes = <(double, double)>[
  (B(2.6), 36), //
  (B(6), 10),
  for (final t in _voteTicks) (t, 12),
  (B(22), 34),
  (B(26), 26),
  (B(34), 60),
  (B(43), 40),
  for (var i = 47; i < 55; i++) (B(i), 10),
  (B(55), 8),
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
  (B(2.6), const Color(0xFFFF2E24), 0.40),
  (B(22), const Color(0xFFFF2E24), 0.30),
  (B(34), const Color(0xFFFF2E24), 0.75),
  (B(43), Colors.white, 0.35),
];

// ── the brother ──────────────────────────────────────────────────────────
/// Tony, exactly as his seat at the table wears him (see [shootPlates]).
AvatarLook get _brother => brotherLook;

/// After the river: horns, a rain cloud of his own and a tear.
final _ghost = _brother.copyWith(hat: AvatarHead.devilHorns, headFx: HeadFx.rainCloud, aura: Aura.inferno).marked(FaceExtra.tear);

// ── the plates and the prepared layers ───────────────────────────────────
late Map<String, ui.Image> plates;
late List<ui.Image> grain;
late Map<String, ui.Image> badges;
late ui.Image icon;
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
      grain = [for (var i = 0; i < 6; i++) await _noise(Random(i))];
      icon = await _decode(File('assets/roles/mafioso.png').readAsBytesSync());
      badges = {
        for (final name in ['app-store-it', 'google-play-it', 'steam-logo-white'])
          name: await _decode(File('$out/badges/$name.png').readAsBytesSync()),
      };
      final dir = Directory('$out/frames')..createSync(recursive: true);
      if (only == null) {
        for (final f in dir.listSync()) {
          f.deleteSync();
        }
      }
      for (final f in [0.66, 0.725]) {
        var u = 0.0;
        while (_film(u) < f) {
          u += 0.005;
        }
        debugPrint('film $f at ${(lynch + u).toStringAsFixed(2)}s');
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
        if (i == (1.9 * fps).round()) File('$out/oberta_short_pov_poster.png').writeAsBytesSync(png.buffer.asUint8List());
        image.dispose();
        if (i % 120 == 0) debugPrint('frame $i/$total  ${watch.elapsed.inSeconds}s');
      }
      if (only != null) {
        final rows = (n + 4) ~/ 5;
        final img = await sheet.endRecording().toImage((W / 4 * min(n, 5)).round(), (H / 4 * rows).round());
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        File('$out/contact.png').writeAsBytesSync(png!.buffer.asUint8List());
      }
    });
  }, timeout: const Timeout(Duration(minutes: 60)));
}

Future<ui.Image> _decode(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  return (await codec.getNextFrame()).image;
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
double _clock = 0;

Future<ui.Image> frame(double t) {
  _clock = t;
  final r = ui.PictureRecorder();
  final c = Canvas(r, const Rect.fromLTWH(0, 0, W, H));
  c.clipRect(const Rect.fromLTWH(0, 0, W, H));
  c.drawRect(const Rect.fromLTWH(0, 0, W, H), Paint()..color = const Color(0xFF0A0807));
  if (t < table) {
    _hook(c, t - hook);
  } else if (t < votes) {
    _table(c, t - table);
  } else if (t < lynch) {
    _votes(c, t - votes);
  } else if (t < flip) {
    _lynch(c, t - lynch);
  } else if (t < payoff) {
    _flip(c, t - flip);
  } else if (t < wardrobe) {
    _payoffScene(c, t - payoff);
  } else if (t < end) {
    _wardrobe(c, t - wardrobe);
  } else {
    _end(c, t - end);
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

/// Draws [img] through [cam] at scene time [u]; [overlay] paints on top in
/// the plate's own pixels, so badges and bubbles ride with the camera.
void _plate(Canvas c, ui.Image img, Cam Function(double u) cam, double u, {ColorFilter? grade, void Function(Canvas c)? overlay}) {
  final now = cam(u);
  final before = cam(u - 1 / fps);
  final speed = (now.zoom - before.zoom).abs() * 40 + (now.focus - before.focus).distance * 30 + (now.angle - before.angle).abs() * 30;
  final shake = shakeAt(_clock) - shakeAt(_clock - 1 / fps);
  final samples = speed + shake.distance / 25 > 0.05 ? 5 : 1;
  for (var k = samples - 1; k >= 0; k--) {
    final du = k / samples / fps;
    final paint = Paint()
      ..filterQuality = FilterQuality.medium
      ..colorFilter = grade
      ..color = Colors.white.withValues(alpha: k == samples - 1 ? 1 : 1 / (samples - k));
    _drawCam(c, img, cam(u - du), shakeAt(_clock - du), paint, k == 0 ? overlay : null);
  }
}

void _drawCam(Canvas c, ui.Image img, Cam cam, Offset shake, Paint paint, void Function(Canvas c)? overlay) {
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
  overlay?.call(c);
  c.restore();
}

/// Every cut lands with a punch: the new shot starts closer and settles.
double punch(double u, [double amount = 0.14]) => 1 + amount * (1 - outCubic(u / 0.24));

/// A quick zoom hit at [at] (scene time), for a word or a beat.
double hitAt(double u, double at, [double amount = 0.08]) => u < at ? 0 : amount * (1 - outCubic((u - at) / 0.3));

// ── word-by-word captions: bold, thick outline, safe area ────────────────
const _cx = W * 0.47; // a little left of centre: the app's buttons sit right
const _maxW = W * 0.82;
const yellow = Color(0xFFFFD54A);
const red = Color(0xFFFF3B30);
const cream = Color(0xFFFFF4E0);

ui.Paragraph _para(String text, Color color, double size, {Paint? stroke}) {
  final b = ui.ParagraphBuilder(ui.ParagraphStyle(fontFamily: 'Georgia', height: 1.05))
    ..pushStyle(ui.TextStyle(fontFamily: 'Georgia', fontSize: size, fontWeight: FontWeight.w700, letterSpacing: size * 0.01, foreground: stroke ?? (Paint()..color = color)))
    ..addText(text);
  final p = b.build()..layout(const ui.ParagraphConstraints(width: 6000));
  return p..layout(ui.ParagraphConstraints(width: p.longestLine.ceilToDouble() + 2));
}

typedef Word = (String text, Color color, double at);

/// One line, its words popping in one by one at their times (scene time).
void words(Canvas c, List<Word> line, double y, double now, {double size = 112, double tilt = 0}) {
  if (line.isEmpty || now < line.first.$3) return;
  var paras = [for (final (text, color, _) in line) _para(text, color, size)];
  final gap = size * 0.26;
  var total = paras.fold(0.0, (a, p) => a + p.width) + gap * (line.length - 1);
  if (total > _maxW) {
    size *= _maxW / total;
    paras = [for (final (text, color, _) in line) _para(text, color, size)];
    total = paras.fold(0.0, (a, p) => a + p.width) + gap * (line.length - 1);
  }
  final stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = size * 0.2
    ..strokeJoin = StrokeJoin.round
    ..color = Colors.black;
  final shadow = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = size * 0.2
    ..strokeJoin = StrokeJoin.round
    ..color = Colors.black.withValues(alpha: 0.5)
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, size * 0.12);
  c.save();
  c.translate(_cx, y);
  c.rotate(tilt);
  var x = -total / 2;
  for (var i = 0; i < line.length; i++) {
    final (text, color, at) = line[i];
    final p = paras[i];
    final since = now - at;
    if (since >= 0) {
      final pop = since < 0.16 ? lerp(1.6, 1, outBack(since / 0.16)) : 1.0;
      final alpha = clamp01(since / 0.04);
      final centre = Offset(x + p.width / 2, 0);
      c.save();
      c.translate(centre.dx, centre.dy);
      c.scale(pop);
      final at0 = Offset(-p.width / 2, -p.height / 2);
      c.saveLayer(Rect.fromCenter(center: Offset.zero, width: p.width + size, height: p.height + size), Paint()..color = Colors.white.withValues(alpha: alpha));
      c.drawParagraph(_para(text, color, size, stroke: shadow), at0 + Offset(0, size * 0.08));
      c.drawParagraph(_para(text, color, size, stroke: stroke), at0);
      c.drawParagraph(p, at0);
      c.restore();
      c.restore();
    }
    x += p.width + gap;
  }
  c.restore();
}

/// Words spaced [step] seconds apart from [from], all in [color] except the
/// ones listed in [keys].
List<Word> say(String text, double from, {double step = 0.13, Color color = Colors.white, Map<String, Color> keys = const {}}) {
  final ws = text.split(' ');
  return [for (var i = 0; i < ws.length; i++) (ws[i], keys[ws[i]] ?? color, from + i * step)];
}

// ── 1 · POV: your brother is a mafioso ───────────────────────────────────
const _noir = ColorFilter.matrix([
  0.75, 0.35, 0.05, 0, 6, //
  0.10, 0.55, 0.05, 0, 0,
  0.08, 0.20, 0.45, 0, 0,
  0, 0, 0, 1, 0,
]);

/// A big live seated character over the night table, under one lamp.
void _character(Canvas c, AvatarLook look, double u, {required double zoom, required Color lamp, bool blur = false}) {
  const all = Rect.fromLTWH(0, 0, W, H);
  _plate(c, plates['night']!, (u) => (focus: const Offset(0.5, 0.31), zoom: 2.2, angle: 0), u, grade: _noir);
  c.drawRect(all, Paint()..color = Colors.black.withValues(alpha: 0.8));
  c.drawRect(all, Paint()..shader = ui.Gradient.radial(const Offset(W / 2, H * 0.32), H * 0.5, [lamp, Colors.transparent]));
  final s = W / 1.3 * 0.98;
  final shake = shakeAt(_clock);
  final samples = blur ? 4 : 1;
  for (var k = samples - 1; k >= 0; k--) {
    c.save();
    c.translate(W / 2 + shake.dx, H * 0.88 + shake.dy);
    c.scale(zoom * (1 + k * 0.012));
    c.translate(-W / 2, -H * 0.88);
    if (k > 0) c.saveLayer(all, Paint()..color = Colors.white.withValues(alpha: 0.25));
    SeatedCharacterPainter(look: look, base: const Offset(W / 2, H * 0.88), size: s, time: ValueNotifier(u * 1.4 + 2), phase: 211, lit: true, edge: true)
        .paint(c, const Size(W, H));
    if (k > 0) c.restore();
    c.restore();
  }
}

void _hook(Canvas c, double u) {
  final open = lerp(1.3, 1.0, outCubic(u / 0.4));
  final zoom = open + hitAt(u, B(2.6), 0.1) + u * 0.025;
  _character(c, _brother, u, zoom: zoom, lamp: Color.lerp(const Color(0x4DFFD27A), const Color(0x66FF3B30), clamp01((u - B(2.6)) / 0.1))!, blur: u < 0.3 || (u > B(2.6) && u < B(2.6) + 0.15));
  words(c, say('POV:', 0, color: yellow), H * 0.13, u, size: 120);
  words(c, say('TUO FRATELLO', 0.22, step: 0.2), H * 0.205, u);
  words(c, [('È', Colors.white, B(2)), ('UN', Colors.white, B(2.3)), ('MAFIOSO.', red, B(2.6))], H * 0.28, u, size: 124, tilt: -0.025);
}

// ── 2 · nobody believes you: the table defends him ───────────────────────
// Seats on the day plate, as fractions of the plate.
const _anna = Offset(0.235, 0.44);
const _seats = {'BRAVO': Offset(0.23, 0.21), 'DELTA': Offset(0.77, 0.21), 'FOXTR…': Offset(0.77, 0.45)};

void _table(Canvas c, double u) {
  final img = plates['day']!;
  final pw = img.width.toDouble(), ph = img.height.toDouble();
  _plate(c, img, (u) => (focus: const Offset(0.5, 0.35), zoom: 1.2 * punch(u, 0.2) + u * 0.03, angle: 0), u, overlay: (c) {
    _brotherTag(c, pw, ph, u);
    final lines = [('DELTA', 'Ma dai, è un santo!', B(1.5)), ('BRAVO', 'Lui? Impossibile.', B(3)), ('FOXTR…', 'Accusi tuo fratello?!', B(4.5))];
    for (var i = 0; i < lines.length; i++) {
      final (name, text, at) = lines[i];
      _bubble(c, Offset(pw * 0.6, ph * (0.255 + i * 0.075)), _seats[name]!.scale(pw, ph), name, text, u - at);
    }
  });
  _band(c, bottom: true);
  words(c, say('NESSUNO TI CREDE.', 0.05, keys: {'NESSUNO': red}), H * 0.70, u);
}

/// A soft dark band behind captions that sit over busy game UI.
void _band(Canvas c, {required bool bottom}) {
  final (a, b) = bottom ? (H * 0.58, H) : (H * 0.30, 0.0);
  c.drawRect(
    Rect.fromLTRB(0, min(a, b), W, max(a, b)),
    Paint()
      ..shader = ui.Gradient.linear(Offset(0, a), Offset(0, b), [
        Colors.black.withValues(alpha: 0),
        Colors.black.withValues(alpha: 0.72),
        Colors.black.withValues(alpha: 0.8),
      ], const [0, 0.35, 1]),
  );
}

/// The yellow tag over his seat.
void _brotherTag(Canvas c, double pw, double ph, double since) {
  final pop = since < 0.2 ? lerp(1.6, 1, outBack(since / 0.2)) : 1.0;
  final at = Offset(_anna.dx * pw + 40, _anna.dy * ph - 250);
  c.save();
  c.translate(at.dx, at.dy + sin(_clock * 7) * 6);
  c.scale(pop);
  final label = _para('TUO FRATELLO', Colors.black, 40);
  final box = Rect.fromCenter(center: Offset.zero, width: label.width + 44, height: label.height + 22);
  final rr = RRect.fromRectAndRadius(box, const Radius.circular(14));
  c.drawRRect(rr.shift(const Offset(0, 6)), Paint()..color = Colors.black54);
  c.drawRRect(rr, Paint()..color = yellow);
  c.drawPath(Path()..moveTo(-20, box.bottom - 1)..lineTo(20, box.bottom - 1)..lineTo(-10, box.bottom + 40)..close(), Paint()..color = yellow);
  c.drawParagraph(label, Offset(-label.width / 2, -label.height / 2));
  c.restore();
}

/// A chat bubble in the game's colours, with its tail toward the speaker.
void _bubble(Canvas c, Offset centre, Offset speaker, String name, String text, double since) {
  if (since < 0) return;
  final pop = since < 0.18 ? lerp(0.4, 1, outBack(since / 0.18)) : 1.0;
  final who = _sans(name, const Color(0xFFE6C77A), 34, bold: true);
  final body = _sans(text, cream, 58);
  final w = max(who.width, body.width) + 56, h = who.height + body.height + 40;
  final box = Rect.fromCenter(center: Offset.zero, width: w, height: h);
  c.save();
  c.translate(centre.dx, centre.dy);
  c.scale(pop);
  final dir = speaker - centre;
  final tip = dir / dir.distance * min(dir.distance, w / 2 + 70);
  final side = Offset(-dir.dy, dir.dx) / dir.distance * 26;
  final fill = Paint()..color = const Color(0xF2150F0B);
  final rim = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 4
    ..color = const Color(0xFFC9A24A);
  final tail = Path()..moveTo(side.dx, side.dy)..lineTo(tip.dx, tip.dy)..lineTo(-side.dx, -side.dy)..close();
  final rr = RRect.fromRectAndRadius(box, const Radius.circular(26));
  c.drawRRect(rr.shift(const Offset(0, 10)), Paint()
    ..color = Colors.black54
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
  c.drawPath(tail, fill);
  c.drawPath(tail, rim);
  c.drawRRect(rr, fill);
  c.drawRRect(rr, rim);
  c.drawParagraph(who, Offset(box.left + 28, box.top + 16));
  c.drawParagraph(body, Offset(box.left + 28, box.top + 20 + who.height));
  c.restore();
}

ui.Paragraph _sans(String text, Color color, double size, {bool bold = false}) {
  final b = ui.ParagraphBuilder(ui.ParagraphStyle(fontFamily: 'Roboto'))
    ..pushStyle(ui.TextStyle(fontFamily: 'Roboto', fontSize: size, color: color, fontWeight: bold ? FontWeight.w700 : FontWeight.w500, letterSpacing: bold ? 2 : 0))
    ..addText(text);
  final p = b.build()..layout(const ui.ParagraphConstraints(width: 2000));
  return p..layout(ui.ParagraphConstraints(width: p.longestLine.ceilToDouble() + 2));
}

// ── 3 · convince the town: the votes pile up on him ──────────────────────
void _votes(Canvas c, double u) {
  final img = plates['day']!;
  final pw = img.width.toDouble(), ph = img.height.toDouble();
  final ticks = [for (final t in _voteTicks) t - votes];
  final count = ticks.where((t) => u >= t).length;
  final accused = B(22) - votes;
  _plate(c, img, (u) {
    final go = inOutSine((u - ticks.first + 0.3) / (accused - ticks.first + 0.3));
    var bump = 0.0;
    for (final t in ticks) {
      bump += hitAt(u, t, 0.05);
    }
    return (
      focus: Offset.lerp(const Offset(0.5, 0.35), const Offset(0.30, 0.41), go)!,
      zoom: lerp(1.2, 2.3, go) * punch(u, 0.12) + bump + hitAt(u, accused, 0.12),
      angle: -0.02 * go,
    );
  }, u, overlay: (c) {
    final centre = Offset(_anna.dx * pw, _anna.dy * ph - 40);
    if (count > 0) {
      final since = u - ticks[count - 1];
      final pop = since < 0.18 ? lerp(1.9, 1, outBack(since / 0.18)) : 1.0;
      c.save();
      c.translate(centre.dx + 30, centre.dy - 10);
      c.scale(pop);
      c.drawCircle(const Offset(0, 6), 60, Paint()..color = Colors.black54);
      c.drawCircle(Offset.zero, 60, Paint()..color = const Color(0xFFC62828));
      c.drawCircle(Offset.zero, 60, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..color = Colors.white);
      final n = _para('$count', Colors.white, 70);
      c.drawParagraph(n, Offset(-n.width / 2, -n.height / 2 + 2));
      c.restore();
    }
    if (u >= accused) {
      final since = u - accused;
      final s = since < 0.16 ? lerp(2.4, 1, outCubic(since / 0.16)) : 1.0;
      c.save();
      c.translate(centre.dx, centre.dy + 110);
      c.rotate(-0.07);
      c.scale(s);
      final label = _para('ACCUSATO', Colors.white, 54);
      final box = Rect.fromCenter(center: Offset.zero, width: label.width + 50, height: label.height + 18);
      c.drawRRect(RRect.fromRectAndRadius(box, const Radius.circular(10)), Paint()..color = const Color(0xFFC62828));
      c.drawRRect(RRect.fromRectAndRadius(box, const Radius.circular(10)), Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = Colors.white);
      c.drawParagraph(label, Offset(-label.width / 2, -label.height / 2));
      c.restore();
    }
  });
  _band(c, bottom: false);
  words(c, say('DEVI CONVINCERE', 0.05, step: 0.2), H * 0.135, u);
  words(c, say('LA CITTÀ.', 0.5, step: 0.18, keys: {'CITTÀ.': yellow}), H * 0.21, u);
}

// ── 4 · lynched: the game's pier film, with a speed ramp ─────────────────
/// Scene time → film time: fast walk, slow-motion push, fast splash.
double _film(double u) {
  final d = flip - lynch;
  final x = clamp01(u / d);
  // Speed: 1 except a slow-motion dip around the push and the splash.
  const slow = 0.35;
  double speed(double x) => 1 - (1 - slow) * exp(-pow((x - 0.74) / 0.13, 2));
  // Integrate numerically and normalise, so the film still spans its range.
  double area(double to) {
    var a = 0.0;
    const n = 60;
    for (var i = 0; i < n; i++) {
      a += speed(to * (i + 0.5) / n) * to / n;
    }
    return a;
  }

  return lerp(0.30, 0.79, area(x) / area(1));
}

void _lynch(Canvas c, double u) {
  final d = flip - lynch;
  final zoom = lerp(1.22, 1.40, inOutSine(u / d)) * punch(u, 0.12) + hitAt(u, B(2), 0.06);
  final sky = plates['verdictSky']!;
  final shake = shakeAt(_clock);
  c.save();
  c.translate(W / 2 + shake.dx, H * 0.70 + shake.dy);
  c.scale(zoom);
  c.translate(-W / 2, -H * 0.70);
  c.drawImageRect(sky, Rect.fromLTWH(0, 0, sky.width.toDouble(), sky.height.toDouble()), const Rect.fromLTWH(0, 0, W, H), Paint()..filterQuality = FilterQuality.medium);
  c.scale(W / logical.width);
  VerdictScenePainter(t: _film(u), take: VerdictTake.molo, strings: AppLanguage.it.strings, hat: AvatarHead.fedora, town: 'Palermo', sprites: sprites)
      .paint(c, logical);
  c.restore();
  words(c, [('LINCIATO.', red, B(2))], H * 0.20, u, size: 150, tilt: -0.03);
}

// ── 5 · straight from the river, his card turns over ──────────────────────────────────
void _flip(Canvas c, double u) {
  const all = Rect.fromLTWH(0, 0, W, H);
  final hot = u >= face ? 1.0 : 0.0;
  c.drawRect(
    all,
    Paint()
      ..shader = ui.Gradient.radial(const Offset(W / 2, H * 0.5), H * 0.6, [
        Color.lerp(const Color(0xFF1A1210), const Color(0xFF7A0A0A), hot)!,
        Color.lerp(const Color(0xFF0A0706), const Color(0xFF2A0405), hot)!,
        const Color(0xFF050303),
      ], const [0, 0.5, 1]),
  );
  if (hot > 0) {
    c.save();
    c.translate(W / 2, H * 0.5);
    c.rotate(u * 0.3);
    final ray = Paint()..color = const Color(0x14FFD27A);
    for (var i = 0; i < 12; i++) {
      c.rotate(pi / 6);
      c.drawPath(Path()..moveTo(0, 0)..lineTo(-80, -H)..lineTo(80, -H)..close(), ray);
    }
    c.restore();
  }
  // The flip: the game's own frames, over the half beat before it lands.
  final start = face - B(0.8);
  final k = (clamp01((u - start) / (face - start)) * flipFrames).floor();
  final img = plates['flip_${k.toString().padLeft(2, '0')}']!;
  final enter = lerp(0.55, 1, outBack(u / 0.25));
  final zoom = enter * (1 + hitAt(u, face, 0.16)) + max(0, u - face) * 0.02;
  final shake = shakeAt(_clock);
  final w = W * 0.80, h = w * img.height / img.width;
  c.save();
  c.translate(W / 2 + shake.dx, H * 0.52 + shake.dy);
  c.scale(zoom);
  c.drawImageRect(img, Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()), Rect.fromCenter(center: Offset.zero, width: w, height: h), Paint()..filterQuality = FilterQuality.high);
  c.restore();
  // The Picciotto's icon jumps out of the card toward the camera.
  if (u >= face) {
    final since = u - face;
    for (var k = since < 0.2 ? 4 : 0; k >= 0; k--) {
      final at = since - k / fps / 1.5;
      if (at < 0) continue;
      final grow = outBack(at / 0.28);
      final side = W * lerp(0.12, 0.33, grow) * (1 + 0.015 * sin(u * 8));
      final y = H * lerp(0.50, 0.335, outCubic(at / 0.28)) + sin(u * 3) * 6;
      c.save();
      c.translate(W / 2 + shake.dx, y + shake.dy);
      c.rotate(lerp(0.4, -0.05, outCubic(at / 0.28)));
      if (k == 0) {
        c.drawCircle(const Offset(0, 14), side * 0.56, Paint()
          ..color = Colors.black.withValues(alpha: 0.55)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, side * 0.08));
        c.drawCircle(Offset.zero, side * 0.62, Paint()
          ..shader = ui.Gradient.radial(Offset.zero, side * 0.62, [const Color(0x66FFD27A), const Color(0x00FFD27A)]));
      }
      c.drawImageRect(icon, const Rect.fromLTWH(0, 0, 250, 250), Rect.fromCenter(center: Offset.zero, width: side, height: side), Paint()
        ..filterQuality = FilterQuality.high
        ..color = Colors.white.withValues(alpha: k == 0 ? 1 : 0.2));
      c.restore();
    }
  }
  words(c, say('ERA DAVVERO', face + 0.15, step: 0.18), H * 0.13, u);
  words(c, [('UN', Colors.white, face + 0.55), ('MAFIOSO.', red, face + 0.7)], H * 0.205, u, size: 124, tilt: -0.025);
}

// ── 6 · the payoff ───────────────────────────────────────────────────────
void _payoffScene(Canvas c, double u) {
  final last = B(2); // beat 43
  final zoom = lerp(1.15, 1.0, outCubic(u / 0.3)) + hitAt(u, last, 0.14) + u * 0.02;
  _character(c, _ghost, u, zoom: zoom, lamp: const Color(0x55FF3B30), blur: u < 0.2 || (u > last && u < last + 0.15));
  final (lead, punchline) = _payoff;
  final first = <Word>[for (var i = 0; i < lead.length; i++) (lead[i], Colors.white, 0.1 + i * 0.16)];
  words(c, first, H * 0.14, u);
  words(c, [(punchline, yellow, last)], H * 0.235, u, size: 150, tilt: -0.03);
}

// ── 7 · and dress him as you like: one absurd outfit per beat ──────────
final _outfits = <(AvatarLook, int)>[
  (_brother.copyWith(hat: AvatarHead.fishHead, outfit: AvatarOutfit.byId('banana_suit'), aura: Aura.spaghettiStorm, eyeShine: EyeShine.spiral).holding(HeldItem.cannolo, hand: Hand.right), 0xFF3A2A1E),
  (_brother.copyWith(hat: AvatarHead.spaghettiHat, outfit: AvatarOutfit.byId('pizza_suit'), aura: Aura.vesuvio, headFx: HeadFx.coins, eyeShine: EyeShine.heart).holding(HeldItem.moka, hand: Hand.right), 0xFF3E1A12),
  (_brother.copyWith(hat: AvatarHead.astronautHelmet, outfit: AvatarOutfit.byId('gold_brocade'), back: BackItem.gildedWings, frontFx: FrontFx.sparkles, aura: Aura.sunburst), 0xFF14243A),
  (_brother.copyWith(hat: AvatarHead.unicornHorn, outfit: AvatarOutfit.byId('clown_suit'), hairDye: HairDye.neonPop, aura: Aura.neonAlley, frontFx: FrontFx.petals).holding(HeldItem.cat), 0xFF2E1438),
  (_brother.copyWith(hat: AvatarHead.flamingHair, outfit: AvatarOutfit.byId('delacroix_cape'), back: BackItem.dragonWings, aura: Aura.inferno, eyeShine: EyeShine.flame).holding(HeldItem.revolver, hand: Hand.right), 0xFF3A1208),
  (_brother.copyWith(hat: AvatarHead.octopusHat, outfit: AvatarOutfit.byId('mummy_wraps'), aura: Aura.harbourMoon, frontFx: FrontFx.bats), 0xFF102A2E),
  (_brother.copyWith(hat: AvatarHead.birthdayCake, outfit: AvatarOutfit.byId('cactus_suit'), aura: Aura.varietyCurtain, frontFx: FrontFx.musicNotes).holding(HeldItem.teddy), 0xFF2A1430),
  (_brother.copyWith(hat: AvatarHead.catOnHead, outfit: AvatarOutfit.byId('magician_cape'), aura: Aura.vault, frontFx: FrontFx.banknotes, eyeShine: EyeShine.diamond), 0xFF2A2410),
];

void _wardrobe(Canvas c, double u) {
  final i = (u / beat).floor().clamp(0, _outfits.length - 1);
  final local = u - i * beat;
  final (look, hue) = _outfits[i];
  c.drawRect(
    const Rect.fromLTWH(0, 0, W, H),
    Paint()..shader = ui.Gradient.radial(const Offset(W / 2, H * 0.52), H * 0.6, [Color(hue), const Color(0xFF0C0806)]),
  );
  final shake = shakeAt(_clock);
  final side = W * 0.84;
  for (var k = local < 0.12 ? 3 : 0; k >= 0; k--) {
    final at = local - k / fps / 1.5;
    final s = lerp(1.35, 1, outCubic(at / 0.2)) * (1 + 0.015 * sin(u * 6));
    c.save();
    c.translate(W / 2 + shake.dx, H * 0.55 + shake.dy);
    c.scale(s);
    c.rotate((i.isEven ? 1 : -1) * lerp(0.08, 0.02, outCubic(at / 0.2)));
    c.translate(-side / 2, -side / 2);
    if (k > 0) c.saveLayer(Rect.fromLTWH(-side * 0.5, -side * 0.5, side * 2, side * 2), Paint()..color = Colors.white.withValues(alpha: 0.25));
    LookPainter.bust(c, look, side);
    if (k > 0) c.restore();
    c.restore();
  }
  words(c, say('E VESTILO', 0.05, step: 0.16), H * 0.13, u);
  words(c, say('COME VUOI.', 0.4, step: 0.16, keys: {'VUOI.': yellow}), H * 0.205, u, size: 124);
}

// ── 8 · the neon sign, coming soon, the store badges; dark for the loop ──
final _neon = HomeNeonState();

void _end(Canvas c, double u) {
  final d = length - end;
  final intro = 0.85 + u * 1.6;
  var power = HomeNeonSign.powerAt(1.0, intro);
  final off = u - (d - 0.3);
  if (off > 0) {
    final jolt = off > 0.2 ? 0.0 : HomeNeonSign.shortAt(off / 0.2);
    power = [for (final p in power) p * jolt];
  }
  _neon.set(power);
  _bricks(c, _neon.glow);
  final cap = W * 0.80 / HomeNeonSign.width;
  const signY = H * 0.25;
  final sign = Rect.fromCenter(center: const Offset(_cx, signY), width: HomeNeonSign.width * cap, height: HomeNeonSign.height * cap);
  final shake = shakeAt(_clock);
  c.save();
  c.translate(shake.dx, shake.dy);
  final zoom = lerp(1.12, 1.0, outCubic(u / 0.5));
  c.translate(_cx, signY);
  c.scale(zoom);
  c.translate(-_cx, -signY);
  HomeNeonPainter(sign: sign, cap: cap, state: _neon).paint(c, const Size(W, H));
  c.restore();
  // Everything but the dark wall fades on the last beat, to loop clean.
  final fade = 1 - clamp01((u - (d - 0.3)) / 0.25);
  c.saveLayer(const Rect.fromLTWH(0, 0, W, H), Paint()..color = Colors.white.withValues(alpha: fade));
  words(c, say('GIOCA GRATIS', 0.35, step: 0.16, keys: {'GRATIS': yellow}), H * 0.41, u, size: 116);
  words(c, say('CON GLI AMICI', 0.75, step: 0.14), H * 0.48, u, size: 100);
  // A clean dark band for the official badges, drawn as they are.
  final band = clamp01((u - B(2.5)) / 0.2);
  c.drawRect(
    const Rect.fromLTWH(0, H * 0.535, W, H * 0.255),
    Paint()
      ..shader = ui.Gradient.linear(const Offset(0, H * 0.535), const Offset(0, H * 0.79), [
        Colors.black.withValues(alpha: 0),
        Colors.black.withValues(alpha: 0.88 * band),
        Colors.black.withValues(alpha: 0.88 * band),
        Colors.black.withValues(alpha: 0),
      ], const [0, 0.18, 0.82, 1]),
  );
  final soon = _sans('PRESTO DISPONIBILE', cream.withValues(alpha: band), 44, bold: true);
  c.drawParagraph(soon, Offset(_cx - soon.width / 2, H * 0.575 - soon.height / 2));
  _badge(c, badges['app-store-it']!, Offset(_cx - 215, H * 0.645), 116, u - B(3));
  _badge(c, badges['google-play-it']!, Offset(_cx + 205, H * 0.645), 130, u - B(3.5));
  _badge(c, badges['steam-logo-white']!, Offset(_cx, H * 0.725), 84, u - B(4));
  c.restore();
}

/// A store badge exactly as the artwork is: only faded and slid in.
void _badge(Canvas c, ui.Image img, Offset centre, double height, double since) {
  if (since < 0) return;
  final a = outCubic(since / 0.22);
  final w = height * img.width / img.height;
  c.drawImageRect(
    img,
    Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
    Rect.fromCenter(center: centre + Offset(0, (1 - a) * 40), width: w, height: height),
    Paint()
      ..filterQuality = FilterQuality.high
      ..color = Colors.white.withValues(alpha: a),
  );
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
      brick.color = Color.lerp(const Color(0xFF2A1714), const Color(0xFF3A1E18), rnd.nextDouble())!;
      c.drawRect(Rect.fromLTWH(x + 3, row * bh + 3, bw - 6, bh - 6), brick);
    }
  }
  c.drawRect(
    all,
    Paint()
      ..shader = ui.Gradient.radial(const Offset(_cx, H * 0.25), H * 0.55, [
        const Color(0xFFFF2E24).withValues(alpha: 0.28 * glow),
        Colors.black.withValues(alpha: 0.35),
        Colors.black.withValues(alpha: 0.85),
      ], const [0, 0.45, 1]),
  );
}
