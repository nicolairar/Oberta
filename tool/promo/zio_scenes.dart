// The storytime short, "Zio Vito", frame by frame: every scene, cut on the
// beat of assets/music/day_2.m4a (139.5 bpm). zio_render_test.dart shoots
// the plates (zio_plates.dart) and calls [zioFrame] for every frame;
// zio_encode.swift mixes the sound on the same beat numbers.
// The script, scene by scene: docs/promo/short_zio.md.
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:oberta/l10n/app_language.dart';
import 'package:oberta/ui/avatar/avatar_look.dart';
import 'package:oberta/ui/avatar/look_painter.dart';
import 'package:oberta/ui/avatar/seated_character.dart';
import 'package:oberta/ui/widgets/home_neon_sign.dart';
import 'package:oberta/ui/widgets/noir_avatar.dart' show AvatarHead;
import 'package:oberta/ui/widgets/particle_sprites.dart';
import 'package:oberta/ui/widgets/verdict_scene.dart';

import 'neon_end.dart';
import 'promo_plates.dart' show flipFrames, logical;
import 'zio_plates.dart' show Seats, looks, vito;

const fps = 60;
const W = 1080.0, H = 1920.0;

/// day_2.m4a runs at 139.5 bpm from its first beat: every cut and every hit
/// sits on one of these.
const beat = 60 / 139.5;
double B(num n) => n * beat;

// ── the edit, in beats (zio_encode.swift uses the same numbers) ──────────
const cuts = <String, double>{
  'hook': 0, 'calcio': 6, 'neon': 11, 'vito': 15, 'nonna': 22, 'dottore': 29, 'notte2': 34, 'prostituta': 39,
  'cella': 43, 'urla': 53, 'credeva': 58, 'voti': 63, 'fiume': 70, 'carta': 77, 'pena': 84, 'vestiti': 88, 'fine': 95,
};
const lengthBeats = 104.0;
final length = B(lengthBeats);
double cut(String name) => B(cuts[name]!);

/// The card lands face up a beat and a half into its scene.
final face = B(1.5);

/// The votes: one per beat, then the stamp.
final voteTicks = [for (var i = 0; i < 6; i++) B(0.75 + i)];
final accusedAt = B(6.25);

// ── what the test hands over ─────────────────────────────────────────────
late Map<String, ui.Image> plates;
late Map<String, Seats> seats;
late List<ui.Image> grain;
late Map<String, ui.Image> badges;
late Map<String, ui.Image> icons;
ParticleSprites? sprites;

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

// ── hits: shakes and flashes (absolute times) ────────────────────────────
final _shakes = <(double, double)>[
  (B(2), 30),
  (cut('calcio'), 10),
  (B(11.5), 34),
  (B(19), 30),
  (B(25.2), 26),
  (B(31), 18),
  (B(40), 20),
  (B(44.5), 40),
  (B(53.6), 24),
  for (final t in voteTicks) (cut('voti') + t, 12),
  (cut('voti') + accusedAt, 34),
  (B(73), 22),
  (cut('carta') + face, 60),
  (B(86), 36),
  for (var i = 88; i < 95; i++) (B(i), 10),
  (cut('fine'), 8),
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
  (B(2), const Color(0xFFFF2E24), 0.32),
  (B(11.5), Colors.white, 0.55),
  (B(19), const Color(0xFFFF2E24), 0.35),
  (B(44.5), Colors.white, 0.25),
  (cut('carta'), Colors.white, 0.45),
  (cut('carta') + face, const Color(0xFFFF2E24), 0.75),
];

// ── one frame ────────────────────────────────────────────────────────────
double _clock = 0;

final _scenes = <String, void Function(Canvas, double)>{
  'hook': _hook, 'calcio': _calcio, 'neon': _neonScene, 'vito': _vitoScene, 'nonna': _nonna, 'dottore': _dottore,
  'notte2': _notte2, 'prostituta': _prostituta, 'cella': _cella, 'urla': _urla, 'credeva': _credeva, 'voti': _voti,
  'fiume': _fiume, 'carta': _carta, 'pena': _pena, 'vestiti': _vestiti, 'fine': _end,
};

Future<ui.Image> zioFrame(double t) {
  _clock = t;
  final r = ui.PictureRecorder();
  final c = Canvas(r, const Rect.fromLTWH(0, 0, W, H));
  c.clipRect(const Rect.fromLTWH(0, 0, W, H));
  c.drawRect(const Rect.fromLTWH(0, 0, W, H), Paint()..color = const Color(0xFF0A0807));
  var scene = cuts.keys.first;
  for (final MapEntry(key: name, value: at) in cuts.entries) {
    if (t >= B(at)) scene = name;
  }
  _scenes[scene]!(c, t - cut(scene));
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
  c.scale(s * 1.02);
  c.translate(-fx, -fy);
  c.drawImage(img, Offset.zero, paint);
  overlay?.call(c);
  c.restore();
}

double punch(double u, [double amount = 0.14]) => 1 + amount * (1 - outCubic(u / 0.24));
double hitAt(double u, double at, [double amount = 0.08]) => u < at ? 0 : amount * (1 - outCubic((u - at) / 0.3));

/// The portrait above a name tag, as a fraction of the plate.
Offset _face(String plate, String name) => seats[plate]![name]! - const Offset(0, 0.052);

// ── word-by-word captions: bold, thick outline, safe area ────────────────
const _cx = W * 0.47;
const _maxW = W * 0.82;
const yellow = Color(0xFFFFD54A);
const red = Color(0xFFFF3B30);
const pink = Color(0xFFFF6FA8);
const cream = Color(0xFFFFF4E0);

ui.Paragraph _para(String text, Color color, double size, {Paint? stroke}) {
  final b = ui.ParagraphBuilder(ui.ParagraphStyle(fontFamily: 'Georgia', height: 1.05))
    ..pushStyle(ui.TextStyle(fontFamily: 'Georgia', fontSize: size, fontWeight: FontWeight.w700, letterSpacing: size * 0.01, foreground: stroke ?? (Paint()..color = color)))
    ..addText(text);
  final p = b.build()..layout(const ui.ParagraphConstraints(width: 6000));
  return p..layout(ui.ParagraphConstraints(width: p.longestLine.ceilToDouble() + 2));
}

typedef Word = (String text, Color color, double at);

void words(Canvas c, List<Word> line, double y, double now, {double size = 108, double tilt = 0}) {
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
      c.save();
      c.translate(x + p.width / 2, 0);
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

List<Word> say(String text, double from, {double step = 0.12, Color color = Colors.white, Map<String, Color> keys = const {}}) {
  final ws = text.split(' ');
  return [for (var i = 0; i < ws.length; i++) (ws[i], keys[ws[i]] ?? color, from + i * step)];
}

/// Caption rows: the three lines of the top safe area, the three of the lower one.
const top1 = H * 0.13, top2 = H * 0.2, top3 = H * 0.27;
const low1 = H * 0.585, low2 = H * 0.65, low3 = H * 0.715;

void _band(Canvas c, {required bool bottom}) {
  final (a, b) = bottom ? (H * 0.5, H) : (H * 0.34, 0.0);
  c.drawRect(
    Rect.fromLTRB(0, min(a, b), W, max(a, b)),
    Paint()
      ..shader = ui.Gradient.linear(Offset(0, a), Offset(0, b), [
        Colors.black.withValues(alpha: 0),
        Colors.black.withValues(alpha: 0.72),
        Colors.black.withValues(alpha: 0.82),
      ], const [0, 0.35, 1]),
  );
}

ui.Paragraph _sans(String text, Color color, double size, {bool bold = false, String family = 'Roboto'}) {
  final b = ui.ParagraphBuilder(ui.ParagraphStyle(fontFamily: family))
    ..pushStyle(ui.TextStyle(fontFamily: family, fontSize: size, color: color, fontWeight: bold ? FontWeight.w700 : FontWeight.w500, letterSpacing: bold ? 2 : 0))
    ..addText(text);
  final p = b.build()..layout(const ui.ParagraphConstraints(width: 2000));
  return p..layout(ui.ParagraphConstraints(width: p.longestLine.ceilToDouble() + 2));
}

/// A chat bubble in the game's colours, its tail toward the speaker.
void _bubble(Canvas c, Offset centre, Offset speaker, String name, String text, double since, {double size = 58}) {
  if (since < 0) return;
  final pop = since < 0.18 ? lerp(0.4, 1, outBack(since / 0.18)) : 1.0;
  final who = _sans(name, const Color(0xFFE6C77A), size * 0.6, bold: true);
  final body = _sans(text, cream, size);
  final w = max(who.width, body.width) + size, h = who.height + body.height + size * 0.7;
  final box = Rect.fromCenter(center: Offset.zero, width: w, height: h);
  c.save();
  c.translate(centre.dx, centre.dy);
  c.scale(pop);
  final dir = speaker - centre;
  final tip = dir / dir.distance * min(dir.distance, w / 2 + 70);
  final side = Offset(-dir.dy, dir.dx) / dir.distance * size * 0.45;
  final fill = Paint()..color = const Color(0xF2150F0B);
  final rim = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = size * 0.07
    ..color = const Color(0xFFC9A24A);
  final tail = Path()..moveTo(side.dx, side.dy)..lineTo(tip.dx, tip.dy)..lineTo(-side.dx, -side.dy)..close();
  final rr = RRect.fromRectAndRadius(box, Radius.circular(size * 0.45));
  c.drawRRect(rr.shift(const Offset(0, 10)), Paint()
    ..color = Colors.black54
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
  c.drawPath(tail, fill);
  c.drawPath(tail, rim);
  c.drawRRect(rr, fill);
  c.drawRRect(rr, rim);
  c.drawParagraph(who, Offset(box.left + size * 0.48, box.top + size * 0.28));
  c.drawParagraph(body, Offset(box.left + size * 0.48, box.top + size * 0.34 + who.height));
  c.restore();
}

/// A role icon popping toward the camera, with a soft glow behind it.
void _icon(Canvas c, ui.Image img, Offset at, double side, double since, {double spin = 0.4}) {
  if (since < 0) return;
  final shake = shakeAt(_clock);
  for (var k = since < 0.2 ? 4 : 0; k >= 0; k--) {
    final a = since - k / fps / 1.5;
    if (a < 0) continue;
    final grow = outBack(a / 0.28);
    final s = side * lerp(0.35, 1, grow) * (1 + 0.015 * sin(_clock * 8));
    c.save();
    c.translate(at.dx + shake.dx, at.dy + shake.dy + sin(_clock * 3) * 6);
    c.rotate(lerp(spin, -0.05, outCubic(a / 0.28)));
    if (k == 0) {
      c.drawCircle(const Offset(0, 14), s * 0.56, Paint()
        ..color = Colors.black.withValues(alpha: 0.55)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.08));
      c.drawCircle(Offset.zero, s * 0.62, Paint()
        ..shader = ui.Gradient.radial(Offset.zero, s * 0.62, [const Color(0x66FFD27A), const Color(0x00FFD27A)]));
    }
    c.drawImageRect(img, Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()), Rect.fromCenter(center: Offset.zero, width: s, height: s), Paint()
      ..filterQuality = FilterQuality.high
      ..color = Colors.white.withValues(alpha: k == 0 ? 1 : 0.2));
    c.restore();
  }
}

/// A bust, popping in at [since] with a little trail, bobbing on the beat.
void _bust(Canvas c, AvatarLook look, Offset centre, double side, double since, {double tilt = 0}) {
  if (since < 0) return;
  final shake = shakeAt(_clock);
  for (var k = since < 0.12 ? 3 : 0; k >= 0; k--) {
    final at = since - k / fps / 1.5;
    if (at < 0) continue;
    final s = lerp(1.3, 1, outCubic(at / 0.2)) * (1 + 0.012 * sin(_clock * 6));
    c.save();
    c.translate(centre.dx + shake.dx, centre.dy + shake.dy);
    c.scale(s);
    c.rotate(tilt + lerp(0.06, 0, outCubic(at / 0.2)));
    c.translate(-side / 2, -side / 2);
    if (k > 0) c.saveLayer(Rect.fromLTWH(-side * 0.5, -side * 0.5, side * 2, side * 2), Paint()..color = Colors.white.withValues(alpha: 0.25));
    LookPainter.bust(c, look, side);
    if (k > 0) c.restore();
    c.restore();
  }
}

const _noir = ColorFilter.matrix([
  0.75, 0.35, 0.05, 0, 6, //
  0.10, 0.55, 0.05, 0, 0,
  0.08, 0.20, 0.45, 0, 0,
  0, 0, 0, 1, 0,
]);

/// A big live seated character over the night table, under one lamp.
void _character(Canvas c, AvatarLook look, double u, {required double zoom, required Color lamp, bool blur = false, double y = 0.88}) {
  const all = Rect.fromLTWH(0, 0, W, H);
  _plate(c, plates['night']!, (u) => (focus: const Offset(0.5, 0.31), zoom: 2.2, angle: 0), u, grade: _noir);
  c.drawRect(all, Paint()..color = Colors.black.withValues(alpha: 0.8));
  c.drawRect(all, Paint()..shader = ui.Gradient.radial(const Offset(W / 2, H * 0.32), H * 0.5, [lamp, Colors.transparent]));
  final s = W / 1.3 * 0.98;
  final shake = shakeAt(_clock);
  final base = Offset(W / 2, H * y);
  final samples = blur ? 4 : 1;
  for (var k = samples - 1; k >= 0; k--) {
    c.save();
    c.translate(base.dx + shake.dx, base.dy + shake.dy);
    c.scale(zoom * (1 + k * 0.012));
    c.translate(-base.dx, -base.dy);
    if (k > 0) c.saveLayer(all, Paint()..color = Colors.white.withValues(alpha: 0.25));
    SeatedCharacterPainter(look: look, base: base, size: s, time: ValueNotifier(u * 1.4 + 2), phase: 211, lit: true, edge: true).paint(c, const Size(W, H));
    if (k > 0) c.restore();
    c.restore();
  }
}

/// The brass name plate of the game, under a character.
void _nameplate(Canvas c, String name, Offset at, double since) {
  if (since < 0) return;
  final pop = since < 0.2 ? lerp(1.6, 1, outBack(since / 0.2)) : 1.0;
  final label = _para(name, const Color(0xFFF3E3B8), 50);
  final box = Rect.fromCenter(center: Offset.zero, width: label.width + 70, height: label.height + 26);
  final rr = RRect.fromRectAndRadius(box, const Radius.circular(18));
  c.save();
  c.translate(at.dx, at.dy);
  c.scale(pop);
  c.drawRRect(rr.shift(const Offset(0, 8)), Paint()..color = Colors.black54);
  c.drawRRect(rr, Paint()..color = const Color(0xFF1A1310));
  c.drawRRect(rr, Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 5
    ..color = const Color(0xFFC9A24A));
  c.drawParagraph(label, Offset(-label.width / 2, -label.height / 2));
  c.restore();
}

// ── 1 · the hook: this game ruined my family ─────────────────────────────
void _hook(Canvas c, double u) {
  _plate(c, plates['day']!, (u) => (focus: const Offset(0.5, 0.3), zoom: lerp(1.5, 1.22, outCubic(u / 0.35)) + hitAt(u, B(2), 0.1) + u * 0.03, angle: -0.015), u);
  _band(c, bottom: false);
  words(c, say('QUESTO GIOCO', 0, step: 0.14), top1, u);
  words(c, say('HA ROVINATO', 0.3, step: 0.16, keys: {'ROVINATO': red}), top2, u);
  words(c, [('LA', Colors.white, 0.62), ('MIA', Colors.white, 0.74), ('FAMIGLIA.', yellow, B(2))], top3, u, size: 118, tilt: -0.02);
}

// ── 2 · sundays used to be about football ────────────────────────────────
final _fans = <(String, AvatarHead)>[('papà', AvatarHead.rossoneriCap), ('vito', AvatarHead.azzurriCap), ('cugino', AvatarHead.nerazzurriCap)];

void _calcio(Canvas c, double u) {
  // A sunny pitch: mown stripes and a white line.
  const all = Rect.fromLTWH(0, 0, W, H);
  final drift = u * 40;
  for (var i = -1; i < 12; i++) {
    c.drawRect(Rect.fromLTWH(0, i * 190.0 + drift % 380, W, 190), Paint()..color = i.isEven ? const Color(0xFF2F6B32) : const Color(0xFF3A7A3B));
  }
  c.drawCircle(const Offset(W / 2, H * 0.62), 300, Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 14
    ..color = Colors.white.withValues(alpha: 0.5));
  c.drawRect(all, Paint()..shader = ui.Gradient.radial(const Offset(W / 2, H * 0.35), H * 0.7, [const Color(0x55FFE9A8), const Color(0x99000000)]));
  for (var i = 0; i < _fans.length; i++) {
    final (name, cap) = _fans[i];
    final look = looks[name]!.copyWith(hat: cap, accessory: AvatarAccessory.none, features: looks[name]!.features.copyWith(mouth: MouthShape.grin));
    final x = W * (0.2 + i * 0.3);
    final hop = -sin(clamp01(((u / beat) % 1) * 1.0) * pi) * 18 * (i.isEven ? 1 : -1);
    _bust(c, look, Offset(x, H * 0.55 + (i == 1 ? -70 : 40) + hop), i == 1 ? W * 0.56 : W * 0.46, u - B(0.25 + i * 0.5), tilt: (i - 1) * 0.08);
  }
  words(c, say('PRIMA LA DOMENICA', 0.05, step: 0.14), top1, u);
  words(c, say('SI PARLAVA DI CALCIO.', 0.6, step: 0.14, keys: {'CALCIO.': yellow}), top2, u);
}

// ── 3 · then Obertà arrived: the neon strikes ────────────────────────────
final _neon = HomeNeonState();

void _neonSign(Canvas c, double u, {required double intro, required double y, double zoom = 1}) {
  final power = HomeNeonSign.powerAt(1.0, intro);
  _neon.set(power);
  _bricks(c, _neon.glow);
  final cap = W * 0.80 / HomeNeonSign.width;
  final sign = Rect.fromCenter(center: Offset(_cx, y), width: HomeNeonSign.width * cap, height: HomeNeonSign.height * cap);
  final shake = shakeAt(_clock);
  c.save();
  c.translate(shake.dx, shake.dy);
  c.translate(_cx, y);
  c.scale(zoom);
  c.translate(-_cx, -y);
  HomeNeonPainter(sign: sign, cap: cap, state: _neon).paint(c, const Size(W, H));
  c.restore();
}

void _neonScene(Canvas c, double u) {
  // The letters strike one by one up to the beat, then it's lit.
  _neonSign(c, u, intro: 0.72 + u * 2.4, y: H * 0.36, zoom: lerp(1.25, 1.0, outCubic(u / 0.5)) + hitAt(u, B(0.5), 0.1));
  words(c, say('POI È ARRIVATO', 0.0, step: 0.13), top1, u);
  words(c, [('OBERTÀ.', yellow, B(0.5))], H * 0.53, u, size: 150, tilt: -0.03);
}

// ── 4 · uncle Vito was in the Family … the wrong one ─────────────────────
void _vitoScene(Canvas c, double u) {
  final second = B(4);
  final zoom = lerp(1.25, 1.0, outCubic(u / 0.35)) + hitAt(u, second, 0.12) + u * 0.02;
  final lamp = Color.lerp(const Color(0x4DFFD27A), const Color(0x66FF3B30), clamp01((u - second) / 0.1))!;
  _character(c, vito, u, zoom: zoom, lamp: lamp, blur: u < 0.25 || (u > second && u < second + 0.15));
  _nameplate(c, 'ZIO VITO', const Offset(W / 2, H * 0.70), u - 0.3);
  words(c, say('ZIO VITO', 0.05, step: 0.14, keys: {'VITO': yellow}), top1, u);
  words(c, say('ERA DELLA FAMIGLIA.', 0.35, step: 0.15), top2, u);
  words(c, [('QUELLA', Colors.white, second - 0.2), ('SBAGLIATA.', red, second)], top3, u, size: 116, tilt: -0.025);
}

// ── 5 · the first night he tried to take out Nonna ───────────────────────
void _nonna(Canvas c, double u) {
  final pick = B(3.2);
  final target = _face('night', 'nonna');
  final img = plates[u < pick ? 'night' : 'nightPick']!;
  _plate(c, img, (u) {
    final go = inOutSine((u - 0.2) / (pick - 0.2));
    return (
      focus: Offset.lerp(const Offset(0.5, 0.36), target + const Offset(0, 0.06), go)!,
      zoom: lerp(1.15, 2.1, go) * punch(u, 0.12) + hitAt(u, pick, 0.12) + max(0, u - pick) * 0.05,
      angle: 0.02 * go,
    );
  }, u, overlay: (c) {
    // A finger-tap ring on her seat, as the pick lands.
    final since = u - pick + 0.12;
    if (since > 0 && since < 0.5) {
      final p = Offset(target.dx * img.width, target.dy * img.height);
      c.drawCircle(p, lerp(40, 190, outCubic(since / 0.5)), Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..color = red.withValues(alpha: 1 - since / 0.5));
    }
  });
  _band(c, bottom: true);
  words(c, say('LA PRIMA NOTTE', 0.05, step: 0.13), low1, u);
  words(c, say('HA PROVATO A FAR FUORI', 0.5, step: 0.12), low2, u);
  words(c, [('LA', Colors.white, pick - 0.15), ('NONNA.', yellow, pick)], low3, u, size: 116, tilt: -0.02);
}

// ── 6 · the Doctor saved her ──────────────────────────────────────────────
void _dottore(Canvas c, double u) {
  final img = plates['day']!;
  const line = Offset(0.5, 0.866);
  _plate(c, img, (u) => (focus: Offset.lerp(const Offset(0.5, 0.6), const Offset(0.5, 0.80), outCubic(u / 0.5))!, zoom: lerp(1.3, 1.75, outCubic(u / 0.5)) * punch(u, 0.1) + hitAt(u, B(2), 0.06), angle: 0), u, overlay: (c) {
    // The game's own dawn line, glowing.
    final since = u - B(1);
    if (since < 0) return;
    final glow = (1 - outCubic(since / 0.6)) * 0.6 + 0.25;
    final r = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(line.dx * img.width, line.dy * img.height), width: img.width * 0.86, height: img.height * 0.072), const Radius.circular(18));
    c.drawRRect(r, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..color = yellow.withValues(alpha: glow)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
  });
  _band(c, bottom: false);
  _icon(c, icons['medico']!, const Offset(W * 0.5, H * 0.43), W * 0.42, u - B(1));
  words(c, say('IL DOTTORE', 0.05, step: 0.15), top1, u);
  words(c, [("L'HA", Colors.white, 0.45), ('SALVATA.', yellow, B(2))], top2, u, size: 116, tilt: -0.02);
}

// ── 7 · the second night he killed nobody ────────────────────────────────
void _notte2(Canvas c, double u) {
  final zoom = lerp(1.2, 1.0, outCubic(u / 0.35)) + u * 0.03;
  final look = vito.copyWith(features: vito.features.copyWith(mouth: MouthShape.grin));
  _character(c, look, u, zoom: zoom, lamp: const Color(0x553C6AFF), blur: u < 0.2);
  words(c, say('LA SECONDA NOTTE', 0.05, step: 0.13), top1, u);
  words(c, say('NON HA UCCISO', 0.5, step: 0.13), top2, u);
  words(c, [('NESSUNO.', yellow, B(2.2))], top3, u, size: 124, tilt: -0.025);
}

// ── 8 · he was with the Prostituta ───────────────────────────────────────
void _prostituta(Canvas c, double u) {
  const all = Rect.fromLTWH(0, 0, W, H);
  c.drawRect(all, Paint()..shader = ui.Gradient.radial(const Offset(W * 0.5, H * 0.5), H * 0.6, [const Color(0xFF5A1430), const Color(0xFF12060A)]));
  // Little hearts rising.
  final rnd = Random(3);
  for (var i = 0; i < 14; i++) {
    final x = rnd.nextDouble() * W, speed = 140 + rnd.nextDouble() * 160, size = 26 + rnd.nextDouble() * 30;
    final y = H * 0.85 - ((u + rnd.nextDouble() * 3) * speed) % (H * 0.7);
    final heart = _sans('♥', pink.withValues(alpha: 0.35), size);
    c.drawParagraph(heart, Offset(x, y));
  }
  final card = plates['prostituta']!;
  final slide = outBack(clamp01((u - 0.05) / 0.3));
  final shake = shakeAt(_clock);
  c.save();
  c.translate(lerp(W * 1.3, W * 0.70, slide) + shake.dx, H * 0.52 + shake.dy);
  c.rotate(lerp(0.4, 0.1, slide));
  final cw = W * 0.56, ch = cw * card.height / card.width;
  c.drawImageRect(card, Rect.fromLTWH(0, 0, card.width.toDouble(), card.height.toDouble()), Rect.fromCenter(center: Offset.zero, width: cw, height: ch), Paint()..filterQuality = FilterQuality.high);
  c.restore();
  final look = vito.marked(FaceExtra.lipstickKiss).marked(FaceExtra.blush).copyWith(eyeShine: EyeShine.heart);
  _bust(c, look, Offset(W * 0.32 + shake.dx, H * 0.56), W * 0.62, 0, tilt: -0.06);
  _icon(c, icons['prostituta']!, const Offset(W * 0.72, H * 0.33), W * 0.3, u - B(1));
  words(c, say('ERA CON', 0.05, step: 0.14), top1, u);
  words(c, [('LA', Colors.white, 0.4), ('PROSTITUTA.', pink, B(1))], top2, u, size: 116, tilt: -0.03);
}

// ── 9 · the Jailer locked him up ──────────────────────────────────────────
void _cella(Canvas c, double u) {
  const all = Rect.fromLTWH(0, 0, W, H);
  c.drawRect(all, Paint()..color = const Color(0xFF16110E));
  // Stone wall.
  final rnd = Random(11);
  const bw = 210.0, bh = 120.0;
  for (var row = 0; row * bh < H; row++) {
    final shift = row.isEven ? 0.0 : bw / 2;
    for (var x = -shift; x < W; x += bw) {
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x + 5, row * bh + 5, bw - 10, bh - 10), const Radius.circular(14)), Paint()..color = Color.lerp(const Color(0xFF2B2521), const Color(0xFF3A322C), rnd.nextDouble())!);
    }
  }
  c.drawRect(all, Paint()..shader = ui.Gradient.radial(const Offset(W / 2, H * 0.42), H * 0.55, [const Color(0x44FFD27A), const Color(0xCC000000)]));
  final messa = B(7);
  final look = u < messa ? vito : vito.copyWith(hat: AvatarHead.angelHalo, features: vito.features.copyWith(mouth: MouthShape.smile), eyeShine: EyeShine.diamond);
  _bust(c, look, const Offset(W / 2, H * 0.47), W * 0.74, u < messa ? 0 : u - messa);
  // The bars slam down on the beat.
  final slam = B(1.5);
  final drop = outBack(clamp01((u - slam + 0.18) / 0.18));
  final shake = shakeAt(_clock);
  final barY = lerp(-H * 0.7, 0, drop);
  c.save();
  c.translate(shake.dx, barY + shake.dy);
  for (var i = 0; i < 7; i++) {
    final x = W * (0.07 + i * 0.143);
    final r = Rect.fromLTWH(x - 20, 0, 40, H * 0.66);
    c.drawRect(r.shift(const Offset(12, 0)), Paint()..color = Colors.black54);
    c.drawRect(r, Paint()..shader = ui.Gradient.linear(r.centerLeft, r.centerRight, const [Color(0xFF2A2A2E), Color(0xFF9A9AA2), Color(0xFF3A3A40)], const [0, 0.4, 1]));
  }
  for (final y in [H * 0.08, H * 0.6]) {
    final r = Rect.fromLTWH(0, y, W, 34);
    c.drawRect(r, Paint()..shader = ui.Gradient.linear(r.topCenter, r.bottomCenter, const [Color(0xFF3A3A40), Color(0xFF9A9AA2), Color(0xFF2A2A2E)], const [0, 0.4, 1]));
  }
  c.restore();
  _icon(c, icons['carceriere']!, const Offset(W * 0.17, H * 0.55), W * 0.27, u - B(4) + 0.1, spin: -0.4);
  _bubble(c, const Offset(W * 0.5, H * 0.69), const Offset(W * 0.5, H * 0.5), 'VITO', 'Io? Ero a messa.', u - messa, size: 62);
  _bubble(c, const Offset(W * 0.56, H * 0.585), const Offset(W * 0.17, H * 0.55), 'CARCERIERE', "Dov'eri ieri notte?", u - B(4), size: 62);
  words(c, say('IL CARCERIERE', 0.05, step: 0.15), top1, u);
  words(c, [("L'HA", Colors.white, 0.45), ('CHIUSO', Colors.white, 0.57), ('IN', Colors.white, slam - 0.12), ('CELLA.', red, slam)], top2, u);
}

// ── 10 · by day he shouted louder than anyone ────────────────────────────
void _urla(Canvas c, double u) {
  final img = plates['day']!;
  final target = _face('day', 'vito');
  final word = B(0.6);
  _plate(c, img, (u) => (focus: Offset.lerp(const Offset(0.5, 0.33), target + const Offset(-0.05, 0.08), outCubic(u / 0.45))!, zoom: lerp(1.2, 2.2, outCubic(u / 0.45)) * punch(u, 0.1) + hitAt(u, word, 0.1) + 0.03 * sin(u * 30) * clamp01(u - word) , angle: 0.015), u, overlay: (c) {
    // The speaking ring on his seat: the game's red, pulsing.
    final p = Offset(target.dx * img.width, target.dy * img.height + 10);
    final pr = img.width * 0.095;
    final pulse = 0.5 + 0.5 * sin(u * 26);
    c.drawCircle(p, pr, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14 + 8 * pulse
      ..color = const Color(0xFFE53935)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    for (var k = 0; k < 3; k++) {
      final ph = ((u * 2.2 + k / 3) % 1);
      c.drawCircle(p, pr * (1 + ph * 0.9), Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..color = const Color(0xFFE53935).withValues(alpha: (1 - ph) * 0.7));
    }
  });
  _band(c, bottom: false);
  _talkButton(c, const Offset(W * 0.5, H * 0.64), u);
  words(c, say('DI GIORNO', 0.05, step: 0.14), top1, u);
  words(c, [('URLAVA', red, word)], top2, u, size: 140, tilt: -0.03);
  words(c, say('PIÙ DI TUTTI.', word + 0.35, step: 0.13), top3, u);
}

/// The push-to-talk button, held down: blood red, the mic icon, waves.
void _talkButton(Canvas c, Offset at, double u) {
  final since = u - 0.15;
  if (since < 0) return;
  final pop = since < 0.2 ? lerp(0.3, 1, outBack(since / 0.2)) : 1.0;
  final press = 0.94 + 0.03 * sin(u * 26);
  const r = 118.0;
  c.save();
  c.translate(at.dx, at.dy);
  c.scale(pop * press);
  for (var k = 0; k < 3; k++) {
    final ph = ((u * 1.8 + k / 3) % 1);
    c.drawCircle(Offset.zero, r * (1 + ph * 0.8), Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..color = const Color(0xFFE53935).withValues(alpha: (1 - ph) * 0.6));
  }
  c.drawCircle(const Offset(0, 10), r, Paint()
    ..color = Colors.black54
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14));
  c.drawCircle(Offset.zero, r, Paint()..shader = ui.Gradient.radial(const Offset(-30, -40), r * 1.4, const [Color(0xFFE85A4F), Color(0xFF8E1B1B)]));
  c.drawCircle(Offset.zero, r, Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 8
    ..color = const Color(0xFFE6C77A));
  final mic = _sans(String.fromCharCode(Icons.mic.codePoint), Colors.white, 130, family: 'MaterialIcons');
  c.drawParagraph(mic, Offset(-mic.width / 2, -mic.height / 2));
  c.restore();
}

// ── 11 · nobody believed me ──────────────────────────────────────────────
void _credeva(Canvas c, double u) {
  final img = plates['day']!;
  final pw = img.width.toDouble(), ph = img.height.toDouble();
  _plate(c, img, (u) => (focus: const Offset(0.5, 0.36), zoom: 1.18 * punch(u, 0.2) + u * 0.03, angle: 0), u, overlay: (c) {
    final mamma = _face('day', 'mamma'), nonna = _face('day', 'nonna');
    _bubble(c, Offset(pw * 0.6, ph * 0.255), nonna.scale(pw, ph), 'NONNA', 'Zio Vito è un santo.', u - B(2.5), size: 80);
    _bubble(c, Offset(pw * 0.58, ph * 0.355), mamma.scale(pw, ph), 'MAMMA', 'Lo zio? Ma dai!', u - B(1), size: 80);
  });
  _band(c, bottom: true);
  words(c, say('NESSUNO MI CREDEVA.', 0.05, step: 0.15, keys: {'NESSUNO': red}), low2, u);
}

// ── 12 · I convinced everyone: the votes pile up on Vito ─────────────────
void _voti(Canvas c, double u) {
  final img = plates['day']!;
  final pw = img.width.toDouble(), ph = img.height.toDouble();
  final count = voteTicks.where((t) => u >= t).length;
  final target = _face('day', 'vito');
  _plate(c, img, (u) {
    final go = inOutSine((u - voteTicks.first + 0.3) / (accusedAt - voteTicks.first + 0.3));
    var bump = 0.0;
    for (final t in voteTicks) {
      bump += hitAt(u, t, 0.05);
    }
    return (
      focus: Offset.lerp(const Offset(0.5, 0.35), target + const Offset(-0.04, 0.05), go)!,
      zoom: lerp(1.2, 2.3, go) * punch(u, 0.12) + bump + hitAt(u, accusedAt, 0.12),
      angle: 0.02 * go,
    );
  }, u, overlay: (c) {
    final centre = Offset(target.dx * pw, target.dy * ph);
    if (count > 0) {
      final since = u - voteTicks[count - 1];
      final pop = since < 0.18 ? lerp(1.9, 1, outBack(since / 0.18)) : 1.0;
      c.save();
      c.translate(centre.dx - 70, centre.dy - 40);
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
    if (u >= accusedAt) {
      final since = u - accusedAt;
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
  words(c, say('HO CONVINTO', 0.05, step: 0.18), top1, u);
  words(c, [('TUTTI.', yellow, B(1))], top2, u, size: 130, tilt: -0.025);
}

// ── 13 · we threw him in the river: the game's pier film ─────────────────
/// Scene time → film time: fast walk, slow-motion push, fast splash.
double film(double u) {
  final d = B(7);
  final x = clamp01(u / d);
  const slow = 0.35;
  double speed(double x) => 1 - (1 - slow) * exp(-pow((x - 0.70) / 0.14, 2));
  double area(double to) {
    var a = 0.0;
    const n = 60;
    for (var i = 0; i < n; i++) {
      a += speed(to * (i + 0.5) / n) * to / n;
    }
    return a;
  }

  return lerp(0.34, 0.80, area(x) / area(1));
}

void _fiume(Canvas c, double u) {
  final d = B(7);
  final zoom = lerp(1.22, 1.40, inOutSine(u / d)) * punch(u, 0.12) + hitAt(u, B(3), 0.06);
  final sky = plates['verdictSky']!;
  final shake = shakeAt(_clock);
  c.save();
  c.translate(W / 2 + shake.dx, H * 0.70 + shake.dy);
  c.scale(zoom);
  c.translate(-W / 2, -H * 0.70);
  c.drawImageRect(sky, Rect.fromLTWH(0, 0, sky.width.toDouble(), sky.height.toDouble()), const Rect.fromLTWH(0, 0, W, H), Paint()..filterQuality = FilterQuality.medium);
  c.scale(W / logical.width);
  VerdictScenePainter(t: film(u), take: VerdictTake.molo, strings: AppLanguage.it.strings, hat: AvatarHead.fedora, town: 'Palermo', sprites: sprites).paint(c, logical);
  c.restore();
  words(c, say('LO ABBIAMO BUTTATO', 0.05, step: 0.15), top1, u);
  words(c, [('NEL', Colors.white, 0.6), ('FIUME.', const Color(0xFF6FC3FF), B(3))], top2, u, size: 130, tilt: -0.03);
}

// ── 14 · he really was a mafioso: the card turns, no pause ───────────────
void _carta(Canvas c, double u) {
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
  final start = face - B(0.8);
  final k = (clamp01((u - start) / (face - start)) * flipFrames).floor();
  final img = plates['flip_${k.toString().padLeft(2, '0')}']!;
  final enter = lerp(0.55, 1, outBack(u / 0.25));
  final zoom = enter * (1 + hitAt(u, face, 0.16)) + max(0, u - face) * 0.02;
  final shake = shakeAt(_clock);
  final w = W * 0.80, h = w * img.height / img.width;
  c.save();
  c.translate(W / 2 + shake.dx, H * 0.52 + shake.dy);
  c.rotate(lerp(-0.25, 0, outCubic(u / 0.3)));
  c.scale(zoom);
  c.drawImageRect(img, Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()), Rect.fromCenter(center: Offset.zero, width: w, height: h), Paint()..filterQuality = FilterQuality.high);
  c.restore();
  if (u >= face) {
    final since = u - face;
    final y = H * lerp(0.50, 0.335, outCubic(since / 0.28));
    _icon(c, icons['mafioso']!, Offset(W / 2, y), W * 0.33, since);
  }
  words(c, say('ERA DAVVERO', 0.1, step: 0.16), top1, u);
  words(c, [('UN', Colors.white, face - 0.1), ('MAFIOSO.', red, face)], top2, u, size: 124, tilt: -0.025);
}

// ── 15 · it was worth it ─────────────────────────────────────────────────
final _ghost = vito.copyWith(hat: AvatarHead.devilHorns, headFx: HeadFx.rainCloud, aura: Aura.inferno).marked(FaceExtra.tear);

void _pena(Canvas c, double u) {
  final last = B(2);
  final zoom = lerp(1.15, 1.0, outCubic(u / 0.3)) + hitAt(u, last, 0.14) + u * 0.02;
  _character(c, _ghost, u, zoom: zoom, lamp: const Color(0x55FF3B30), blur: u < 0.2 || (u > last && u < last + 0.15));
  words(c, say('NE È VALSA', 0.08, step: 0.15), top1, u);
  words(c, [('LA', Colors.white, last - 0.2), ('PENA.', yellow, last)], top2, u, size: 140, tilt: -0.03);
}

// ── 16 · and at least now he dresses better ──────────────────────────────
final _outfits = <(AvatarLook, int)>[
  (vito.copyWith(hat: AvatarHead.fishHead, outfit: AvatarOutfit.byId('banana_suit'), aura: Aura.spaghettiStorm, eyeShine: EyeShine.spiral).holding(HeldItem.cannolo, hand: Hand.right), 0xFF3A2A1E),
  (vito.copyWith(hat: AvatarHead.spaghettiHat, outfit: AvatarOutfit.byId('pizza_suit'), aura: Aura.vesuvio, headFx: HeadFx.coins, eyeShine: EyeShine.heart).holding(HeldItem.moka, hand: Hand.right), 0xFF3E1A12),
  (vito.copyWith(hat: AvatarHead.astronautHelmet, outfit: AvatarOutfit.byId('gold_brocade'), back: BackItem.gildedWings, frontFx: FrontFx.sparkles, aura: Aura.sunburst), 0xFF14243A),
  (vito.copyWith(hat: AvatarHead.unicornHorn, outfit: AvatarOutfit.byId('clown_suit'), hairDye: HairDye.neonPop, aura: Aura.neonAlley, frontFx: FrontFx.petals).holding(HeldItem.cat), 0xFF2E1438),
  (vito.copyWith(hat: AvatarHead.flamingHair, outfit: AvatarOutfit.byId('delacroix_cape'), back: BackItem.dragonWings, aura: Aura.inferno, eyeShine: EyeShine.flame).holding(HeldItem.revolver, hand: Hand.right), 0xFF3A1208),
  (vito.copyWith(hat: AvatarHead.birthdayCake, outfit: AvatarOutfit.byId('cactus_suit'), aura: Aura.varietyCurtain, frontFx: FrontFx.musicNotes).holding(HeldItem.teddy), 0xFF2A1430),
  (vito.copyWith(hat: AvatarHead.crown, outfit: AvatarOutfit.byId('magician_cape'), aura: Aura.vault, frontFx: FrontFx.banknotes, eyeShine: EyeShine.diamond), 0xFF2A2410),
];

void _vestiti(Canvas c, double u) {
  final i = (u / beat).floor().clamp(0, _outfits.length - 1);
  final local = u - i * beat;
  final (look, hue) = _outfits[i];
  c.drawRect(
    const Rect.fromLTWH(0, 0, W, H),
    Paint()..shader = ui.Gradient.radial(const Offset(W / 2, H * 0.52), H * 0.6, [Color(hue), const Color(0xFF0C0806)]),
  );
  _bust(c, look, const Offset(W / 2, H * 0.56), W * 0.84, local, tilt: (i.isEven ? 1 : -1) * 0.02);
  words(c, say('E ALMENO ORA', 0.05, step: 0.14), top1, u);
  words(c, say('SI VESTE MEGLIO.', 0.55, step: 0.15, keys: {'MEGLIO.': yellow}), top2, u, size: 116);
}

// ── 17 · the neon sign, coming soon, the store badges; dark for the loop ─
void _end(Canvas c, double u) {
  final d = length - cut('fine');
  wireEndNeon(_neon, u, d);
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
  final fade = 1 - clamp01((u - (d - 0.3)) / 0.25);
  c.saveLayer(const Rect.fromLTWH(0, 0, W, H), Paint()..color = Colors.white.withValues(alpha: fade));
  words(c, say('GIOCA GRATIS', 0.3, step: 0.15, keys: {'GRATIS': yellow}), H * 0.41, u, size: 116);
  words(c, say('CON GLI AMICI', 0.65, step: 0.13), H * 0.48, u, size: 100);
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
