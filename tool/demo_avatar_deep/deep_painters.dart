// ignore_for_file: invalid_use_of_visible_for_testing_member
// Demo painters for the new slots, in the live cartoon-noir language: a
// heavy ink silhouette, flat fills with a hard shadow band and a lamp-lit
// rim, thin inner lines. Only paths and gradients, no blur.
//
// Everything here draws in "bust units": the canvas is scaled so the bust
// square is 0..1, the same frame the live painter uses.
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:oberta/ui/avatar/look_painter.dart';

import 'slots.dart';

const ink = Color(0xFF0B0809);
const night = Color(0xFF1A1236);
const lamp = Color(0xFFFFD27A);
const cream = Color(0xFFF2EAE1);
const brass = Color(0xFFC9A066);
const gold = Color(0xFFE8B84A);

/// The outline widths of the current paint, in bust units.
double ow = 0.022;
double thin = 0.008;

/// The local scale of the current item (lines are divided by it).
double _k = 1;

Paint fill(Color c) => Paint()..color = c;
Paint line(Color c, double w) => Paint()
  ..style = PaintingStyle.stroke
  ..strokeWidth = w / _k
  ..color = c
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;
Color dark(Color c, [double t = 0.55]) => Color.lerp(c, night, t)!;
Color lit(Color c, [double t = 0.45]) => Color.lerp(c, lamp, t)!;

/// The live toon fill: base, a hard shadow band on the right, a thin lit
/// rim on the left, the inner ink line.
void toon(Canvas c, Path p, Color base, {double d = 0.05, double glow = 0.45, bool rim = true, bool outline = true}) {
  c.drawPath(p, fill(base));
  c.drawPath(Path.combine(PathOperation.difference, p, p.shift(Offset(-d, -d * 0.8))), fill(dark(base)));
  if (rim) c.drawPath(Path.combine(PathOperation.difference, p, p.shift(Offset(d * 0.25, d * 0.22))), fill(lit(base, glow)));
  if (outline) c.drawPath(p, line(ink, thin));
}

/// A piece made of several parts: one heavy ink silhouette around all of
/// them, then each part toon-filled in order.
void piece(Canvas c, List<(Path, Color)> parts, {double d = 0.05, bool silhouette = true, double weight = 1}) {
  if (silhouette) {
    for (final (p, _) in parts) {
      c.drawPath(p, line(ink, ow * 2 * weight));
    }
  }
  for (final (p, col) in parts) {
    toon(c, p, col, d: d);
  }
}

/// Draws [draw] at [o], turned by [turn] radians, scaled by [s].
void at(Canvas c, Offset o, double s, double turn, void Function() draw) {
  c.save();
  c.translate(o.dx, o.dy);
  c.rotate(turn);
  c.scale(s);
  final previous = _k;
  _k *= s;
  draw();
  _k = previous;
  c.restore();
}

Path oval(Offset center, double w, double h) => Path()..addOval(Rect.fromCenter(center: center, width: w, height: h));
Path rrect(Rect r, double radius) => Path()..addRRect(RRect.fromRectAndRadius(r, Radius.circular(radius)));
Path poly(List<Offset> pts) => Path()..addPolygon(pts, true);
Path star(Offset c, double r, int n, double inner, {double turn = -pi / 2}) {
  final pts = <Offset>[];
  for (var i = 0; i < n * 2; i++) {
    final a = turn + i * pi / n;
    final rr = i.isEven ? r : r * inner;
    pts.add(c + Offset(cos(a), sin(a)) * rr);
  }
  return poly(pts);
}

Path heart(Offset c, double s) => Path()
  ..moveTo(c.dx, c.dy + s * 0.9)
  ..cubicTo(c.dx - s * 1.3, c.dy + s * 0.1, c.dx - s * 0.9, c.dy - s * 1.0, c.dx, c.dy - s * 0.35)
  ..cubicTo(c.dx + s * 0.9, c.dy - s * 1.0, c.dx + s * 1.3, c.dy + s * 0.1, c.dx, c.dy + s * 0.9)
  ..close();

/// Where the face sits in the bust, in bust units, from the live anchors.
class Geo {
  final Offset leftEye, rightEye;
  final double brow, nose, mouth, chin, width;
  Geo(this.leftEye, this.rightEye, this.brow, this.nose, this.mouth, this.chin, this.width);

  factory Geo.of(DeepLook d) {
    final a = LookPainter.bustAnchors(d.look, 1);
    return Geo(a.leftEye, a.rightEye, a.brow, a.nose, a.mouth, a.chin, a.width);
  }

  /// The same face after the bust is shrunk by [z] toward the bottom centre.
  Geo map(double z) {
    Offset m(Offset p) => Offset((1 - z) / 2 + p.dx * z, (1 - z) + p.dy * z);
    double y(double v) => (1 - z) + v * z;
    return Geo(m(leftEye), m(rightEye), y(brow), y(nose), y(mouth), y(chin), width * z);
  }

  double get cx => (leftEye.dx + rightEye.dx) / 2;
  double get eyeY => leftEye.dy;
  double get eyeDx => (rightEye.dx - leftEye.dx) / 2;

  /// The top of the skull, estimated from the face proportions.
  double get top => brow - (chin - brow) * 0.78;
  Offset get head => Offset(cx, (top + chin) / 2);
  double get headH => chin - top;
}

// ---------------------------------------------------------------- AURAS ---

/// The aura fills the whole square behind the figure.
void paintAura(Canvas c, String id, Geo g, {required bool table}) {
  const box = Rect.fromLTRB(0, 0, 1, 1);
  final h = g.head;
  switch (id) {
    case 'inferno':
      c.drawRect(box, fill(const Color(0xFF1A0705)));
      c.drawRect(
        box,
        Paint()
          ..shader = RadialGradient(
            center: Alignment(0, h.dy * 2 - 1 + 0.5),
            radius: 0.9,
            colors: const [Color(0xFF8A2410), Color(0xFF3A0C06), Color(0xFF140504)],
            stops: const [0, 0.55, 1],
          ).createShader(box),
      );
      for (final (row, col, height, w) in [(0, const Color(0xFFB8321A), 0.62, 0.17), (1, const Color(0xFFE8642A), 0.46, 0.14), (2, const Color(0xFFFFB347), 0.3, 0.11)]) {
        final p = Path()..moveTo(-0.05, 1.05);
        final n = (1.1 / w).ceil();
        for (var i = 0; i < n; i++) {
          final x0 = -0.05 + i * w;
          final centre = (x0 + w / 2 - 0.5).abs();
          final tall = height * (1 - centre * 0.9) * (0.75 + 0.25 * sin(i * 2.3 + row));
          final tip = Offset(x0 + w * (0.5 + 0.25 * sin(i * 1.7 + row * 2)), 1.0 - tall);
          p.quadraticBezierTo(x0 + w * 0.05, 1 - tall * 0.45, tip.dx, tip.dy);
          p.quadraticBezierTo(x0 + w * 0.85, 1 - tall * 0.4, x0 + w, 1.0 - tall * 0.12);
        }
        p
          ..lineTo(1.05, 1.05)
          ..close();
        c.drawPath(p, fill(col));
        if (!table) c.drawPath(p, line(ink.withValues(alpha: 0.55), thin * 0.8));
      }
      // Embers.
      for (var i = 0; i < (table ? 5 : 12); i++) {
        final x = 0.08 + (i * 0.618 % 1) * 0.84;
        final y = 0.1 + (i * 0.381 % 1) * 0.45;
        c.drawPath(star(Offset(x, y), 0.012 + 0.006 * (i % 3), 4, 0.35, turn: i * 0.4), fill(const Color(0xFFFFD27A)));
      }
    case 'moon':
      c.drawRect(
        box,
        Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF0E1838), Color(0xFF1E2C5C), Color(0xFF2A1E48)]).createShader(box),
      );
      // A city skyline at the bottom.
      final sky = Path()..moveTo(0, 1);
      var x = 0.0;
      var i = 0;
      while (x < 1) {
        final w = 0.06 + (i * 0.37 % 1) * 0.07;
        final top = 0.66 + (i * 0.53 % 1) * 0.16;
        sky
          ..lineTo(x, top)
          ..lineTo(x + w, top);
        x += w;
        i++;
      }
      sky
        ..lineTo(1, 1)
        ..close();
      c.drawPath(sky, fill(const Color(0xFF0A0F24)));
      if (!table) {
        for (var j = 0; j < 14; j++) {
          final wx = 0.04 + (j * 0.618 % 1) * 0.92;
          final wy = 0.74 + (j * 0.29 % 1) * 0.2;
          c.drawRect(Rect.fromLTWH(wx, wy, 0.012, 0.016), fill(const Color(0xFFFFC965).withValues(alpha: 0.8)));
        }
      }
      // A huge crescent moon behind the head, off to one side.
      final m = Offset(h.dx + 0.16, h.dy - 0.12);
      const r = 0.33;
      c.drawCircle(m, r * 1.18, fill(const Color(0xFFF4E7C0).withValues(alpha: 0.08)));
      c.drawCircle(m, r * 1.07, fill(const Color(0xFFF4E7C0).withValues(alpha: 0.10)));
      final moon = Path.combine(PathOperation.difference, oval(m, r * 2, r * 2), oval(m + const Offset(0.13, -0.06), r * 1.8, r * 1.8));
      c.drawPath(moon, fill(const Color(0xFFF4E7C0)));
      c.drawPath(Path.combine(PathOperation.difference, moon, moon.shift(const Offset(0.03, 0.02))), fill(const Color(0xFFD8C38E)));
      for (final (o, s) in [(const Offset(-0.2, 0.08), 0.05), (const Offset(-0.24, -0.06), 0.03), (const Offset(-0.12, 0.2), 0.035)]) {
        c.drawCircle(m + o, s / 2, fill(const Color(0xFFD8C38E)));
      }
      c.drawPath(moon, line(ink, thin));
      for (var j = 0; j < (table ? 4 : 9); j++) {
        final sx = 0.06 + (j * 0.73 % 1) * 0.88;
        final sy = 0.05 + (j * 0.41 % 1) * 0.5;
        c.drawPath(star(Offset(sx, sy), 0.014 + 0.008 * (j % 3), 4, 0.3), fill(cream));
      }
    case 'sunburst':
      c.drawRect(box, fill(const Color(0xFF2A1A0E)));
      final o = Offset(h.dx, h.dy - 0.02);
      const rays = 28;
      for (var j = 0; j < rays; j++) {
        final a0 = j * 2 * pi / rays;
        final a1 = a0 + pi / rays;
        final p = Path()
          ..moveTo(o.dx, o.dy)
          ..lineTo(o.dx + cos(a0) * 1.6, o.dy + sin(a0) * 1.6)
          ..lineTo(o.dx + cos(a1) * 1.6, o.dy + sin(a1) * 1.6)
          ..close();
        c.drawPath(p, fill(j.isEven ? const Color(0xFFB8862E) : const Color(0xFF8C6420)));
      }
      c.drawRect(
        box,
        Paint()
          ..shader = RadialGradient(
            center: Alignment(o.dx * 2 - 1, o.dy * 2 - 1),
            radius: 0.85,
            colors: const [Color(0x00000000), Color(0x00000000), Color(0xCC1A0F06)],
            stops: const [0, 0.35, 1],
          ).createShader(box),
      );
      for (final rr in [0.3, 0.37, 0.44]) {
        c.drawCircle(o, rr, line(const Color(0xFFFFE2A0).withValues(alpha: 0.55), thin * (rr == 0.37 ? 2.2 : 1)));
      }
      // Deco steps at the bottom corners.
      for (final s in [-1.0, 1.0]) {
        for (var j = 0; j < 4; j++) {
          final w = 0.1 + j * 0.06;
          final x0 = s < 0 ? 0.0 : 1 - w;
          c.drawRect(Rect.fromLTWH(x0, 0.72 + j * 0.07, w, 0.07), fill(j.isEven ? const Color(0xFF3A2412) : const Color(0xFF4A3018)));
        }
      }
    case 'neon':
      c.drawRect(box, Paint()..shader = const RadialGradient(center: Alignment(0, -0.2), radius: 0.9, colors: [Color(0xFF2A1438), Color(0xFF0C0614)]).createShader(box));
      // Brick wall.
      if (!table) {
        final brick = line(const Color(0xFF3A1E48).withValues(alpha: 0.6), thin * 0.7);
        for (var row = 0; row < 14; row++) {
          final y = row * 0.075;
          c.drawLine(Offset(0, y), Offset(1, y), brick);
          for (var col = 0; col < 7; col++) {
            final bx = col * 0.16 + (row.isOdd ? 0.08 : 0);
            c.drawLine(Offset(bx, y), Offset(bx, y + 0.075), brick);
          }
        }
      }
      // A neon tube ring behind the head: wide faint, medium, white core.
      final o = Offset(h.dx, h.dy + 0.02);
      for (final (w, a) in [(0.09, 0.10), (0.05, 0.22), (0.025, 0.55)]) {
        c.drawCircle(o, 0.36, line(const Color(0xFFFF4FA3).withValues(alpha: a), w));
      }
      c.drawCircle(o, 0.36, line(const Color(0xFFFFD6EC), 0.008));
      for (final (w, a) in [(0.06, 0.12), (0.03, 0.3)]) {
        c.drawCircle(o, 0.43, line(const Color(0xFF3FE0D0).withValues(alpha: a), w));
      }
      c.drawCircle(o, 0.43, line(const Color(0xFFCFFFF8), 0.006));
    case 'smoke':
      c.drawRect(
        box,
        Paint()..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF3E4A52), Color(0xFF1E2428), Color(0xFF2E2420)]).createShader(box),
      );
      // Big cartoon smoke billows, three tones.
      for (final (dy, col, n) in [(0.18, const Color(0xFF55626A), 6), (0.42, const Color(0xFF6E7B82), 5), (0.78, const Color(0xFF8A969C), 6)]) {
        final cloud = Path();
        for (var j = 0; j < n; j++) {
          final cxj = (j + 0.5) / n + 0.05 * sin(j * 3.1 + dy * 10);
          final rj = 0.1 + 0.05 * ((j * 7 + (dy * 10).round()) % 3);
          cloud.addOval(Rect.fromCircle(center: Offset(cxj, dy + 0.03 * cos(j * 2.0)), radius: rj));
        }
        c.drawPath(cloud, fill(col.withValues(alpha: 0.55)));
      }
      if (!table) {
        for (var j = 0; j < 4; j++) {
          final o = Offset(0.12 + j * 0.26, 0.3 + (j.isEven ? 0.05 : -0.05));
          final swirl = Path()..moveTo(o.dx - 0.06, o.dy + 0.04);
          swirl.cubicTo(o.dx - 0.08, o.dy - 0.06, o.dx + 0.06, o.dy - 0.08, o.dx + 0.04, o.dy);
          swirl.cubicTo(o.dx + 0.02, o.dy + 0.04, o.dx - 0.02, o.dy + 0.02, o.dx, o.dy - 0.01);
          c.drawPath(swirl, line(const Color(0xFFB8C4C8).withValues(alpha: 0.6), thin * 1.4));
        }
      }
    case 'marquee':
      c.drawRect(box, fill(const Color(0xFF3A0A12)));
      // Velvet curtain folds.
      for (var j = 0; j < 9; j++) {
        final x0 = j / 8 - 0.06;
        c.drawRect(
          Rect.fromLTWH(x0, 0, 0.125, 1),
          Paint()..shader = const LinearGradient(colors: [Color(0xFF5A0E1C), Color(0xFF8C1C2C), Color(0xFF4A0A16)]).createShader(Rect.fromLTWH(x0, 0, 0.125, 1)),
        );
      }
      c.drawRect(box, Paint()..shader = RadialGradient(center: Alignment(0, h.dy * 2 - 1), radius: 0.7, colors: const [Color(0x55FFD27A), Color(0x00000000)]).createShader(box));
      // A bulb arch.
      final o = Offset(h.dx, h.dy + 0.12);
      const n = 15;
      for (var j = 0; j <= n; j++) {
        final a = pi + j * pi / n;
        final p = o + Offset(cos(a) * 0.43, sin(a) * 0.47);
        if (!table) c.drawCircle(p, 0.028, fill(const Color(0x33FFD27A)));
        c.drawCircle(p, 0.017, fill(const Color(0xFFFFC94A)));
        c.drawCircle(p, 0.017, line(ink, thin * 0.8));
        c.drawCircle(p - const Offset(0.005, 0.005), 0.006, fill(const Color(0xFFFFF6D8)));
      }
  }
}

// ------------------------------------------------------------ BACK ITEMS --

void paintBack(Canvas c, String id, Geo g, Color coat) {
  final h = g.head;
  switch (id) {
    case 'violinCase':
      // A violin case slung over the right shoulder, diagonally.
      at(c, Offset(h.dx + 0.27, h.dy + 0.12), 1, 0.42, () {
        final body = Path()
          ..moveTo(0, -0.34)
          ..cubicTo(0.07, -0.34, 0.09, -0.24, 0.07, -0.14)
          ..cubicTo(0.06, -0.06, 0.12, 0.0, 0.12, 0.12)
          ..cubicTo(0.12, 0.27, 0.06, 0.32, 0, 0.32)
          ..cubicTo(-0.06, 0.32, -0.12, 0.27, -0.12, 0.12)
          ..cubicTo(-0.12, 0.0, -0.06, -0.06, -0.07, -0.14)
          ..cubicTo(-0.09, -0.24, -0.07, -0.34, 0, -0.34)
          ..close();
        piece(c, [(body, const Color(0xFF3A2216))]);
        c.drawLine(const Offset(0, -0.3), const Offset(0, 0.28), line(const Color(0xFF6A4A2A), thin));
        for (final y in [-0.2, 0.05, 0.2]) {
          final clasp = rrect(Rect.fromCenter(center: Offset(0.0, y), width: 0.05, height: 0.025), 0.006);
          toon(c, clasp, gold, d: 0.01);
        }
      });
      // The strap across the chest.
      c.drawLine(Offset(h.dx + 0.2, 0.82), Offset(h.dx - 0.3, 1.05), line(ink, ow * 2 + 0.03));
      c.drawLine(Offset(h.dx + 0.2, 0.82), Offset(h.dx - 0.3, 1.05), line(const Color(0xFF4A2E1C), 0.03));
    case 'decoWings':
      // Gilded deco wings: three rows of long rounded feathers fanning up
      // and out from behind each shoulder.
      for (final sd in [-1.0, 1.0]) {
        final root = Offset(h.dx + sd * 0.2, 0.7);
        for (final (row, len, col) in [(0, 0.64, const Color(0xFFA87A2A)), (1, 0.5, const Color(0xFFC99A3E)), (2, 0.34, const Color(0xFFE8C46A))]) {
          final feathers = <(Path, Color)>[];
          const n = 6;
          for (var j = 0; j < n; j++) {
            final a = -pi / 2 + sd * (0.3 + j * 0.24);
            final l = len * (1 - j * 0.07);
            final tip = root + Offset(cos(a), sin(a)) * l;
            final nrm = Offset(-sin(a), cos(a)) * (0.03 + row * 0.004);
            final f = Path()
              ..moveTo(root.dx + nrm.dx * 0.5, root.dy + nrm.dy * 0.5)
              ..quadraticBezierTo(root.dx + (tip.dx - root.dx) * 0.6 + nrm.dx * 1.6, root.dy + (tip.dy - root.dy) * 0.6 + nrm.dy * 1.6, tip.dx, tip.dy)
              ..quadraticBezierTo(root.dx + (tip.dx - root.dx) * 0.6 - nrm.dx * 1.6, root.dy + (tip.dy - root.dy) * 0.6 - nrm.dy * 1.6, root.dx - nrm.dx * 0.5, root.dy - nrm.dy * 0.5)
              ..close();
            feathers.add((f, col));
          }
          piece(c, feathers.reversed.toList(), d: 0.02, weight: 0.6);
          for (final (f, _) in feathers) {
            final m = f.computeMetrics().first;
            final tip = m.getTangentForOffset(m.length / 2)!.position;
            c.drawLine(root, Offset.lerp(root, tip, 0.85)!, line(const Color(0xFF8C6420), thin * 0.6));
          }
        }
      }
    case 'skeleton':
      // A giant cartoon skeleton looming behind, a shade darker than night.
      const bone = Color(0xFF4E3E6E);
      final o = Offset(h.dx - 0.27, g.top + 0.04);
      final skull = Path()
        ..addOval(Rect.fromCenter(center: o, width: 0.4, height: 0.37))
        ..addRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: o + const Offset(0, 0.16), width: 0.24, height: 0.13), const Radius.circular(0.04)));
      c.drawPath(skull, fill(bone));
      final sockets = Path()
        ..addOval(Rect.fromCenter(center: o + const Offset(-0.085, 0.02), width: 0.1, height: 0.11))
        ..addOval(Rect.fromCenter(center: o + const Offset(0.085, 0.02), width: 0.1, height: 0.11));
      c.drawPath(sockets, fill(const Color(0xFF120A1C)));
      c.drawPath(poly([o + const Offset(-0.015, 0.1), o + const Offset(0.015, 0.1), o + const Offset(0, 0.07)]), fill(const Color(0xFF120A1C)));
      for (var t = -2; t <= 2; t++) {
        c.drawLine(o + Offset(t * 0.035, 0.13), o + Offset(t * 0.035, 0.2), line(const Color(0xFF120A1C), thin));
      }
      for (final s in [-1.0, 1.0]) {
        c.drawCircle(o + Offset(s * 0.085, 0.03), 0.018, fill(const Color(0xFF3FE0D0)));
      }
    case 'parasol':
      at(c, Offset(h.dx + 0.24, g.top - 0.02), 1, 0.35, () {
        final canopy = Path()
          ..moveTo(-0.3, 0.04)
          ..quadraticBezierTo(-0.28, -0.24, 0, -0.26)
          ..quadraticBezierTo(0.28, -0.24, 0.3, 0.04);
        for (var j = 0; j < 4; j++) {
          final x0 = 0.3 - j * 0.15;
          canopy.quadraticBezierTo(x0 - 0.075, -0.02, x0 - 0.15, 0.04);
        }
        canopy.close();
        c.drawLine(const Offset(0, -0.3), const Offset(0, 0.5), line(ink, 0.012 + ow * 2));
        c.drawLine(const Offset(0, -0.3), const Offset(0, 0.5), line(const Color(0xFF6A4A2A), 0.012));
        piece(c, [(canopy, const Color(0xFFE6C9D2))], d: 0.03);
        for (var j = 0; j < 5; j++) {
          final x = -0.3 + j * 0.15;
          c.drawLine(const Offset(0, -0.26), Offset(x, 0.04), line(const Color(0xFFB88C9C), thin));
        }
        // Lace edge.
        for (var j = 0; j < 8; j++) {
          c.drawCircle(Offset(-0.26 + j * 0.075, 0.055), 0.013, line(cream, thin * 0.8));
        }
      });
    case 'saxophone':
      at(c, Offset(h.dx - 0.3, h.dy + 0.16), 1, -0.25, () {
        final tube = Path()
          ..moveTo(-0.02, -0.36)
          ..lineTo(0.03, -0.36)
          ..lineTo(0.05, 0.12)
          ..quadraticBezierTo(0.06, 0.24, -0.04, 0.26)
          ..quadraticBezierTo(-0.12, 0.27, -0.14, 0.16)
          ..lineTo(-0.2, 0.06)
          ..lineTo(-0.1, 0.03)
          ..lineTo(-0.08, 0.13)
          ..quadraticBezierTo(-0.06, 0.18, -0.02, 0.16)
          ..lineTo(-0.02, -0.36)
          ..close();
        final neck = Path()
          ..moveTo(-0.02, -0.36)
          ..quadraticBezierTo(0.0, -0.44, 0.08, -0.44)
          ..lineTo(0.08, -0.41)
          ..quadraticBezierTo(0.03, -0.41, 0.03, -0.36)
          ..close();
        piece(c, [(tube, gold), (neck, gold)], d: 0.02);
        for (var j = 0; j < 5; j++) {
          final y = -0.25 + j * 0.07;
          c.drawCircle(Offset(0.012, y), 0.014, fill(const Color(0xFFFFF0C8)));
          c.drawCircle(Offset(0.012, y), 0.014, line(ink, thin * 0.7));
        }
      });
  }
}

// ---------------------------------------------------------- HEAD EFFECTS --

/// The glow outline drawn behind the head: dilated silhouettes of the hair
/// and head, a wide faint one and a tight bright one (no blur).
void paintHeadGlow(Canvas c, DeepLook d, double side, Color color) {
  final area = Rect.fromLTWH(-side * 0.2, -side * 0.2, side * 1.4, side * 1.4);
  for (final (r, a) in [(side * 0.03, 0.25), (side * 0.016, 0.7)]) {
    c.saveLayer(
      area,
      Paint()
        ..imageFilter = ui.ImageFilter.dilate(radiusX: r, radiusY: r)
        ..colorFilter = ColorFilter.mode(color.withValues(alpha: a), BlendMode.srcIn),
    );
    LookPainter.bustLayers(c, d.look, side, {LookLayer.hairBack, LookLayer.face, LookLayer.hairFront, LookLayer.hat});
    c.restore();
  }
}

void paintHeadFx(Canvas c, String id, Geo g) {
  final h = g.head;
  switch (id) {
    case 'halo':
      final o = Offset(h.dx, g.top - 0.06);
      final ring = Path.combine(PathOperation.difference, oval(o, 0.36, 0.1), oval(o, 0.27, 0.055));
      c.drawPath(oval(o, 0.46, 0.17), fill(const Color(0x22FFE2A0)));
      piece(c, [(ring, const Color(0xFFFFD86A))], d: 0.012, weight: 0.6);
    case 'horns':
      for (final s in [-1.0, 1.0]) {
        final b = Offset(h.dx + s * g.width * 0.34, g.top + 0.03);
        final horn = Path()
          ..moveTo(b.dx - s * 0.04, b.dy + 0.02)
          ..quadraticBezierTo(b.dx + s * 0.02, b.dy - 0.09, b.dx + s * 0.08, b.dy - 0.15)
          ..quadraticBezierTo(b.dx + s * 0.05, b.dy - 0.06, b.dx + s * 0.05, b.dy + 0.02)
          ..close();
        piece(c, [(horn, const Color(0xFFC8283A))], d: 0.018);
      }
    case 'starOrbit':
      final o = Offset(h.dx, g.top + 0.03);
      final orbit = Rect.fromCenter(center: o, width: g.width * 1.7, height: 0.12);
      c.drawArc(orbit, pi * 1.05, pi * 0.9, false, line(const Color(0xAAE8E0FF), thin * 0.9));
      for (final a in [pi * 1.1, pi * 1.5, pi * 1.85]) {
        final p = orbit.center + Offset(cos(a) * orbit.width / 2, sin(a) * orbit.height / 2);
        piece(c, [(star(p, 0.03, 5, 0.45), const Color(0xFFF4E7C0))], d: 0.008, weight: 0.3);
      }
    case 'sparks':
      for (var j = 0; j < 6; j++) {
        final a = pi * (1.05 + j * 0.18);
        final p = Offset(h.dx, h.dy) + Offset(cos(a) * g.width * 0.95, sin(a) * g.headH * 0.85);
        final s = 0.018 + 0.008 * (j % 2);
        c.drawPath(star(p, s * 1.6, 4, 0.3, turn: j * 0.3), fill(const Color(0x66FF9A3A)));
        c.drawPath(star(p, s, 4, 0.3, turn: j * 0.3), fill(const Color(0xFFFFE08A)));
      }
    case 'hearts':
      for (final (dx, dy, s, turn) in [(-0.29, -0.02, 0.024, -0.3), (0.31, -0.08, 0.03, 0.25), (0.22, -0.2, 0.02, 0.1), (-0.2, -0.17, 0.018, -0.15)]) {
        at(c, Offset(h.dx + dx, g.top + dy), 1, turn, () {
          piece(c, [(heart(Offset.zero, s), const Color(0xFFE8506E))], d: s * 0.35, weight: 0.35);
        });
      }
    case 'coins':
      final o = Offset(h.dx, g.top + 0.0);
      final orbit = Rect.fromCenter(center: o, width: g.width * 1.9, height: 0.14);
      c.drawArc(orbit, pi * 1.05, pi * 0.9, false, line(const Color(0x88FFD27A), thin * 0.8));
      for (final a in [pi * 1.15, pi * 1.5, pi * 1.82]) {
        final p = orbit.center + Offset(cos(a) * orbit.width / 2, sin(a) * orbit.height / 2);
        _coin(c, p, 0.028);
      }
  }
}

void _coin(Canvas c, Offset p, double r) {
  piece(c, [(oval(p, r * 2, r * 2), gold)], d: r * 0.3, weight: 0.3);
  c.drawCircle(p, r * 0.62, line(const Color(0xFF8C6420), thin * 0.8));
}

// ----------------------------------------------------------- FACE EXTRAS --

void paintFaceExtras(Canvas c, Set<String> ids, Geo g, {required bool small}) {
  final dx = g.eyeDx;
  for (final id in ids) {
    switch (id) {
      case 'blush':
        for (final s in [-1.0, 1.0]) {
          final o = Offset(g.cx + s * dx * 1.25, (g.eyeY + g.mouth) / 2 + 0.004);
          c.drawOval(Rect.fromCenter(center: o, width: dx * 0.95, height: dx * 0.45), fill(const Color(0x66FF6F7A)));
          if (!small) {
            for (var j = -1; j <= 1; j++) {
              final x = o.dx + j * dx * 0.2;
              c.drawLine(Offset(x + dx * 0.06, o.dy - dx * 0.1), Offset(x - dx * 0.06, o.dy + dx * 0.1), line(const Color(0xAAE0485A), thin * 0.7));
            }
          }
        }
      case 'freckles':
        if (small) break;
        for (final s in [-1.0, 1.0]) {
          for (var j = 0; j < 5; j++) {
            final o = Offset(g.cx + s * dx * (0.6 + (j % 3) * 0.28), (g.eyeY + g.nose) / 2 + dx * (0.1 + (j ~/ 3) * 0.22 + (j % 2) * 0.08));
            c.drawCircle(o, dx * 0.045, fill(const Color(0xAA6A3A20)));
          }
        }
      case 'tear':
        final o = Offset(g.leftEye.dx - dx * 0.1, g.eyeY + dx * 0.42);
        final drop = Path()
          ..moveTo(o.dx, o.dy - dx * 0.2)
          ..quadraticBezierTo(o.dx + dx * 0.16, o.dy + dx * 0.06, o.dx, o.dy + dx * 0.13)
          ..quadraticBezierTo(o.dx - dx * 0.16, o.dy + dx * 0.06, o.dx, o.dy - dx * 0.2)
          ..close();
        c.drawPath(drop, fill(const Color(0xFF8FD8FF)));
        c.drawPath(drop, line(ink, thin * 0.8));
        c.drawCircle(o + Offset(-dx * 0.03, 0), dx * 0.03, fill(Colors.white));
      case 'stitchScar':
        final a = Offset(g.rightEye.dx + dx * 0.05, g.eyeY - dx * 0.55);
        final b = Offset(g.rightEye.dx + dx * 0.45, g.eyeY + dx * 0.55);
        c.drawLine(a, b, line(const Color(0xFF8A3A3A), thin * 1.3));
        for (var j = 1; j < 5; j++) {
          final p = Offset.lerp(a, b, j / 5)!;
          c.drawLine(p + Offset(-dx * 0.1, -dx * 0.03), p + Offset(dx * 0.1, dx * 0.03), line(ink, thin * 0.8));
        }
      case 'skullPaint':
        // Calavera make-up: dark sockets with petal rims, a stitched mouth.
        for (final s in [-1.0, 1.0]) {
          final o = Offset(g.cx + s * dx, g.eyeY);
          c.drawCircle(o, dx * 0.62, fill(const Color(0xCC1A0E22)));
          if (!small) {
            for (var j = 0; j < 8; j++) {
              final a = j * pi / 4;
              c.drawCircle(o + Offset(cos(a), sin(a)) * dx * 0.72, dx * 0.08, fill(const Color(0xFF3FE0D0)));
            }
          }
        }
        if (!small) {
          final m = Offset(g.cx, g.mouth);
          c.drawLine(m - Offset(dx * 0.8, 0), m + Offset(dx * 0.8, 0), line(ink, thin));
          for (var j = -3; j <= 3; j++) {
            c.drawLine(m + Offset(j * dx * 0.22, -dx * 0.12), m + Offset(j * dx * 0.22, dx * 0.12), line(ink, thin * 0.8));
          }
        }
      case 'beautyStar':
        final o = Offset(g.rightEye.dx + dx * 0.35, g.eyeY + dx * 0.6);
        c.drawPath(star(o, dx * 0.16, 5, 0.45), fill(const Color(0xFF1A1236)));
      case 'goldTooth':
        if (small) break;
        final o = Offset(g.cx + dx * 0.25, g.mouth + dx * 0.02);
        final tooth = rrect(Rect.fromCenter(center: o, width: dx * 0.16, height: dx * 0.15), dx * 0.03);
        c.drawPath(tooth, fill(gold));
        c.drawPath(tooth, line(ink, thin * 0.6));
        c.drawPath(star(o + Offset(dx * 0.12, -dx * 0.1), dx * 0.07, 4, 0.3), fill(Colors.white));
    }
  }
}

/// The eye shine: a shape over each pupil.
void paintEyeShine(Canvas c, String id, Geo g) {
  final r = g.eyeDx * 0.2;
  for (final e in [g.leftEye, g.rightEye]) {
    switch (id) {
      case 'heart':
        c.drawPath(heart(e, r * 0.95), fill(const Color(0xFFE8304E)));
        c.drawPath(heart(e, r * 0.95), line(ink, thin * 0.6));
        c.drawCircle(e + Offset(-r * 0.35, -r * 0.35), r * 0.22, fill(Colors.white));
      case 'star':
        c.drawPath(star(e, r * 1.25, 5, 0.45), fill(const Color(0xFFFFE08A)));
        c.drawPath(star(e, r * 1.25, 5, 0.45), line(ink, thin * 0.5));
      case 'spiral':
        final p = Path()..moveTo(e.dx, e.dy);
        for (var t = 0.0; t < 4 * pi; t += 0.3) {
          final rr = r * 1.1 * t / (4 * pi);
          p.lineTo(e.dx + cos(t) * rr, e.dy + sin(t) * rr);
        }
        c.drawCircle(e, r * 1.15, fill(Colors.white));
        c.drawPath(p, line(ink, thin * 0.6));
      case 'dollar':
        c.drawCircle(e, r * 1.05, fill(const Color(0xFF2E8A4A)));
        final tp = TextPainter(
          text: TextSpan(
            text: r'$',
            style: TextStyle(fontSize: r * 1.9, fontWeight: FontWeight.bold, color: const Color(0xFFE8FFD8), fontFamily: 'Georgia', height: 1),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(c, e - Offset(tp.width / 2, tp.height / 2));
      case 'glint':
        c.drawPath(star(e + Offset(-r * 0.4, -r * 0.4), r * 0.9, 4, 0.25), fill(Colors.white));
    }
  }
}

// ------------------------------------------------------------ HAIR DYE ----

/// Two-tone dye: the live hair is painted platinum, then this multiplies a
/// top-to-bottom gradient onto exactly the visible hair (the bare hair
/// layers, minus what covers them), so the toon shading survives.
void paintHairDye(Canvas c, DeepLook d, double side, HairDye dye, Geo g) {
  final area = Rect.fromLTWH(0, 0, side, side);
  c.saveLayer(area, Paint()..blendMode = BlendMode.multiply);
  LookPainter.bustLayers(c, d.look, side, {LookLayer.hairBack});
  c.saveLayer(area, Paint()..blendMode = BlendMode.dstOut);
  LookPainter.bustLayers(c, d.look, side, {LookLayer.body, LookLayer.neck, LookLayer.face, LookLayer.beard});
  c.restore();
  LookPainter.bustLayers(c, d.look, side, {LookLayer.hairFront});
  c.saveLayer(area, Paint()..blendMode = BlendMode.dstOut);
  LookPainter.bustLayers(c, d.look, side, {LookLayer.glasses, LookLayer.hat, LookLayer.chest, LookLayer.mouthProp});
  c.restore();
  final band = Rect.fromLTRB(0, g.top * side - side * 0.03, side, g.chin * side + side * 0.12);
  c.drawRect(
    area,
    Paint()
      ..blendMode = BlendMode.srcIn
      ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [dye.top, dye.bottom]).createShader(band),
  );
  c.restore();
}

// ------------------------------------------------------------ HELD ITEMS --

/// A hand rising from the bottom edge holding [item] at the grip (local
/// origin, item pointing up). [side] is -1 for the left of the picture.
void paintHeld(Canvas c, String id, Geo g, {required double side, required Color sleeve, required Color skin}) {
  final grip = Offset(g.cx + side * g.width * 0.88, 0.82);
  final turn = side * 0.16;
  // Sleeve from below the frame up to the wrist.
  final elbow = Offset(grip.dx + side * 0.12, 1.2);
  final wrist = grip + Offset(side * 0.02, 0.07);
  c.drawLine(elbow, wrist, line(ink, 0.12 + ow * 2));
  c.drawLine(elbow, wrist, line(sleeve, 0.12));
  c.drawLine(elbow + Offset(side * 0.03, 0), wrist + Offset(side * 0.025, 0.0), line(dark(sleeve), 0.05));
  final cuff = Path()..addOval(Rect.fromCenter(center: wrist + const Offset(0, -0.005), width: 0.12, height: 0.05));
  piece(c, [(cuff, cream)], d: 0.01, silhouette: false);
  at(c, grip, 1, turn, () {
    final palm = oval(const Offset(0, 0.02), 0.11, 0.1);
    piece(c, [(palm, skin)], d: 0.02);
    _item(c, id);
    // Curled fingers over the grip.
    final fingers = <(Path, Color)>[for (var j = 0; j < 4; j++) (rrect(Rect.fromCenter(center: Offset(-side * 0.035, -0.022 + j * 0.026), width: 0.075, height: 0.03), 0.015), skin)];
    final thumb = rrect(Rect.fromCenter(center: Offset(side * 0.04, -0.03), width: 0.03, height: 0.07), 0.015);
    piece(c, [...fingers, (thumb, skin)], d: 0.012);
  });
}

/// The item itself, grip at the origin, pointing up.
void _item(Canvas c, String id) {
  switch (id) {
    case 'grappa':
      final bottle = Path()
        ..moveTo(-0.022, -0.3)
        ..lineTo(0.022, -0.3)
        ..lineTo(0.022, -0.2)
        ..quadraticBezierTo(0.065, -0.17, 0.065, -0.1)
        ..lineTo(0.06, 0.08)
        ..quadraticBezierTo(0.06, 0.1, 0.04, 0.1)
        ..lineTo(-0.04, 0.1)
        ..quadraticBezierTo(-0.06, 0.1, -0.06, 0.08)
        ..lineTo(-0.065, -0.1)
        ..quadraticBezierTo(-0.065, -0.17, -0.022, -0.2)
        ..close();
      final cork = rrect(const Rect.fromLTRB(-0.02, -0.34, 0.02, -0.29), 0.008);
      piece(c, [(bottle, const Color(0xFF5E8C6A)), (cork, const Color(0xFFB8864A))], d: 0.02);
      final label = rrect(const Rect.fromLTRB(-0.05, -0.1, 0.05, -0.02), 0.006);
      toon(c, label, cream, d: 0.01);
      c.drawLine(const Offset(-0.035, -0.07), const Offset(0.035, -0.07), line(const Color(0xFF8C1C2C), thin));
      c.drawLine(const Offset(-0.035, -0.045), const Offset(0.02, -0.045), line(ink, thin * 0.6));
      c.drawLine(const Offset(-0.045, -0.17), const Offset(-0.05, 0.05), line(const Color(0x88FFFFFF), thin * 1.4));
    case 'rose':
      final stem = Path()
        ..moveTo(0, 0.1)
        ..quadraticBezierTo(0.02, -0.1, -0.01, -0.24);
      c.drawPath(stem, line(ink, 0.014 + ow * 2));
      c.drawPath(stem, line(const Color(0xFF3A6A2E), 0.014));
      for (final s in [-1.0, 1.0]) {
        final leaf = Path()
          ..moveTo(0.008, -0.08 + s * 0.02)
          ..quadraticBezierTo(0.06 * s, -0.14, 0.09 * s, -0.11 + s * 0.02)
          ..quadraticBezierTo(0.05 * s, -0.06, 0.008, -0.08 + s * 0.02)
          ..close();
        piece(c, [(leaf, const Color(0xFF4A8A3A))], d: 0.01);
      }
      final bloom = Offset(-0.01, -0.28);
      final petals = <(Path, Color)>[
        (oval(bloom + const Offset(0, 0.015), 0.12, 0.09), const Color(0xFFA8182C)),
        (oval(bloom + const Offset(-0.025, -0.005), 0.07, 0.07), const Color(0xFFC8283A)),
        (oval(bloom + const Offset(0.025, -0.005), 0.07, 0.07), const Color(0xFFC8283A)),
        (oval(bloom + const Offset(0, -0.02), 0.06, 0.05), const Color(0xFFE0485A)),
      ];
      piece(c, petals, d: 0.012);
      c.drawArc(Rect.fromCenter(center: bloom + const Offset(0, -0.015), width: 0.03, height: 0.025), 0, pi * 1.5, false, line(ink, thin * 0.8));
    case 'revolver':
      final barrel = rrect(const Rect.fromLTRB(-0.018, -0.3, 0.018, -0.1), 0.008);
      final drum = rrect(const Rect.fromLTRB(-0.04, -0.12, 0.04, -0.04), 0.02);
      final grip = Path()
        ..moveTo(-0.03, -0.05)
        ..lineTo(0.03, -0.05)
        ..lineTo(0.045, 0.09)
        ..quadraticBezierTo(0.0, 0.11, -0.035, 0.08)
        ..close();
      final sight = rrect(const Rect.fromLTRB(-0.006, -0.32, 0.006, -0.29), 0.003);
      piece(c, [(grip, const Color(0xFF6A3A1E)), (barrel, const Color(0xFF5A5E66)), (drum, const Color(0xFF6A6E76)), (sight, const Color(0xFF5A5E66))], d: 0.018);
      for (final y in [-0.1, -0.06]) {
        c.drawLine(Offset(-0.025, y), Offset(0.025, y), line(ink, thin * 0.7));
      }
      c.drawLine(const Offset(-0.008, -0.28), const Offset(-0.008, -0.13), line(const Color(0xAAFFFFFF), thin));
    case 'cards':
      for (var j = 0; j < 5; j++) {
        at(c, const Offset(0, 0.05), 1, (j - 2) * 0.26, () {
          final card = rrect(const Rect.fromLTRB(-0.045, -0.26, 0.045, -0.12), 0.012);
          piece(c, [(card, cream)], d: 0.012);
          final red = j.isOdd;
          final mark = Offset(0, -0.21);
          final col = red ? const Color(0xFFC0272D) : ink;
          if (j == 4) {
            c.drawPath(star(mark, 0.022, 4, 0.4), fill(col));
          } else if (red) {
            c.drawPath(heart(mark, 0.016), fill(col));
          } else {
            c.drawCircle(mark + const Offset(0, -0.006), 0.011, fill(col));
            c.drawCircle(mark + const Offset(-0.01, 0.006), 0.011, fill(col));
            c.drawCircle(mark + const Offset(0.01, 0.006), 0.011, fill(col));
          }
          c.drawLine(const Offset(-0.03, -0.245), const Offset(-0.022, -0.245), line(col, thin));
        });
      }
    case 'coupe':
      final bowl = Path()
        ..moveTo(-0.08, -0.22)
        ..lineTo(0.08, -0.22)
        ..quadraticBezierTo(0.07, -0.14, 0.0, -0.13)
        ..quadraticBezierTo(-0.07, -0.14, -0.08, -0.22)
        ..close();
      final stem = rrect(const Rect.fromLTRB(-0.008, -0.14, 0.008, 0.06), 0.004);
      final foot = oval(const Offset(0, 0.07), 0.09, 0.025);
      piece(c, [(stem, const Color(0xFFD8E4EC)), (foot, const Color(0xFFD8E4EC)), (bowl, const Color(0xFFF0D27A))], d: 0.014);
      c.drawPath(oval(const Offset(0, -0.22), 0.16, 0.03), fill(const Color(0xFFFFE8A8)));
      c.drawPath(oval(const Offset(0, -0.22), 0.16, 0.03), line(ink, thin * 0.7));
      for (final b in [const Offset(-0.02, -0.17), const Offset(0.025, -0.19), const Offset(0.0, -0.25), const Offset(0.03, -0.27)]) {
        c.drawCircle(b, 0.006, line(Colors.white, thin * 0.6));
      }
    case 'candle':
      final wax = rrect(const Rect.fromLTRB(-0.03, -0.22, 0.03, 0.08), 0.01);
      piece(c, [(wax, const Color(0xFFF4ECD8))], d: 0.016);
      final drip = Path()
        ..moveTo(-0.03, -0.2)
        ..quadraticBezierTo(-0.034, -0.14, -0.02, -0.15)
        ..quadraticBezierTo(-0.01, -0.18, 0.0, -0.2)
        ..close();
      c.drawPath(drip, fill(const Color(0xFFFFFAEC)));
      c.drawCircle(const Offset(0, -0.27), 0.05, fill(const Color(0x22FFD27A)));
      final flame = Path()
        ..moveTo(0, -0.32)
        ..quadraticBezierTo(0.03, -0.26, 0, -0.23)
        ..quadraticBezierTo(-0.03, -0.26, 0, -0.32)
        ..close();
      piece(c, [(flame, const Color(0xFFFFB347))], d: 0.008, weight: 0.4);
      c.drawPath(oval(const Offset(0, -0.25), 0.014, 0.025), fill(const Color(0xFFFFF4C8)));
  }
}

/// An item carried in both hands in front of the chest: the cat, the teddy.
void paintHeldBoth(Canvas c, String id, Geo g, {required Color sleeve, required Color skin}) {
  final o = Offset(g.cx, 0.86);
  // Both forearms rising from the bottom corners.
  for (final s in [-1.0, 1.0]) {
    final elbow = Offset(o.dx + s * 0.34, 1.12);
    final wrist = Offset(o.dx + s * 0.17, 0.93);
    c.drawLine(elbow, wrist, line(ink, 0.12 + ow * 2));
    c.drawLine(elbow, wrist, line(sleeve, 0.12));
    c.drawLine(elbow + Offset(s * 0.03, 0), wrist + Offset(s * 0.025, 0), line(dark(sleeve), 0.05));
  }
  switch (id) {
    case 'cat':
      const fur = Color(0xFF26222A);
      final body = oval(o + const Offset(0, 0.05), 0.3, 0.2);
      final headP = oval(o + const Offset(0.0, -0.08), 0.2, 0.17);
      final ears = <Path>[
        for (final s in [-1.0, 1.0]) poly([o + Offset(s * 0.09, -0.12), o + Offset(s * 0.085, -0.2), o + Offset(s * 0.03, -0.15)]),
      ];
      final tail = Path()
        ..moveTo(o.dx + 0.12, o.dy + 0.08)
        ..quadraticBezierTo(o.dx + 0.3, o.dy + 0.02, o.dx + 0.24, o.dy - 0.14)
        ..quadraticBezierTo(o.dx + 0.22, o.dy - 0.17, o.dx + 0.21, o.dy - 0.13)
        ..quadraticBezierTo(o.dx + 0.25, o.dy + 0.0, o.dx + 0.1, o.dy + 0.04)
        ..close();
      piece(c, [(tail, fur), (body, fur), for (final e in ears) (e, fur), (headP, fur)], d: 0.03);
      for (final s in [-1.0, 1.0]) {
        final eye = o + Offset(s * 0.045, -0.085);
        c.drawOval(Rect.fromCenter(center: eye, width: 0.045, height: 0.04), fill(const Color(0xFFE8D84A)));
        c.drawOval(Rect.fromCenter(center: eye, width: 0.01, height: 0.035), fill(ink));
        for (var j = -1; j <= 1; j++) {
          c.drawLine(o + Offset(s * 0.04, -0.04 + j * 0.008), o + Offset(s * 0.12, -0.05 + j * 0.02), line(const Color(0xFFB8B0C0), thin * 0.6));
        }
      }
      c.drawPath(poly([o + const Offset(-0.012, -0.055), o + const Offset(0.012, -0.055), o + const Offset(0, -0.042)]), fill(const Color(0xFFE88A9A)));
      // A red bow at the neck.
      for (final s in [-1.0, 1.0]) {
        c.drawPath(poly([o + const Offset(0, -0.005), o + Offset(s * 0.05, -0.025), o + Offset(s * 0.05, 0.015)]), fill(const Color(0xFFC0272D)));
      }
      c.drawCircle(o + const Offset(0, -0.005), 0.013, fill(const Color(0xFF8E1B2B)));
    case 'teddy':
      const fur = Color(0xFFA8743E);
      final body = oval(o + const Offset(0, 0.06), 0.24, 0.2);
      final headP = oval(o + const Offset(0, -0.07), 0.19, 0.16);
      final ears = [
        for (final s in [-1.0, 1.0]) oval(o + Offset(s * 0.08, -0.14), 0.07, 0.07),
      ];
      piece(c, [(body, fur), for (final e in ears) (e, fur), (headP, fur)], d: 0.028);
      for (final s in [-1.0, 1.0]) {
        c.drawCircle(o + Offset(s * 0.08, -0.14), 0.018, fill(const Color(0xFFD8A878)));
        c.drawCircle(o + Offset(s * 0.04, -0.085), 0.012, fill(ink));
      }
      c.drawPath(oval(o + const Offset(0, -0.045), 0.08, 0.055), fill(const Color(0xFFE0BC8C)));
      c.drawPath(oval(o + const Offset(0, -0.055), 0.025, 0.018), fill(ink));
      // A tiny bow tie and a stitched patch.
      for (final s in [-1.0, 1.0]) {
        c.drawPath(poly([o + const Offset(0, 0.01), o + Offset(s * 0.04, -0.005), o + Offset(s * 0.04, 0.025)]), fill(const Color(0xFF1A1236)));
      }
      final patch = rrect(Rect.fromCenter(center: o + const Offset(0.05, 0.08), width: 0.05, height: 0.05), 0.008);
      c.drawPath(patch, fill(const Color(0xFF6A8AA8)));
      c.drawPath(patch, line(ink, thin * 0.6));
  }
  // Hands holding it from the sides.
  for (final s in [-1.0, 1.0]) {
    final hand = oval(Offset(o.dx + s * 0.15, 0.93), 0.1, 0.09);
    piece(c, [(hand, skin)], d: 0.018);
    for (var j = 0; j < 3; j++) {
      c.drawLine(Offset(o.dx + s * 0.12, 0.905 + j * 0.022), Offset(o.dx + s * 0.1, 0.905 + j * 0.022), line(ink, thin * 0.8));
    }
  }
}

// --------------------------------------------------------- FRONT EFFECTS --

void paintFrontFx(Canvas c, String id, Geo g, {required bool table}) {
  switch (id) {
    case 'smokeRings':
      final from = Offset(g.cx + g.width * 1.0, 0.56);
      for (var j = 0; j < (table ? 2 : 3); j++) {
        final o = from + Offset(j * 0.03, -j * 0.09);
        final w = 0.07 + j * 0.035;
        c.drawOval(Rect.fromCenter(center: o, width: w, height: w * 0.5), line(const Color(0xAADCE2E6), thin * (2.2 - j * 0.5)));
      }
    case 'petals':
      for (final (x, y, turn) in [(0.12, 0.3, 0.5), (0.86, 0.22, -0.7), (0.8, 0.55, 1.2), (0.18, 0.62, -0.4)]) {
        at(c, Offset(x, y), 1, turn, () {
          final p = Path()
            ..moveTo(0, -0.022)
            ..quadraticBezierTo(0.024, 0, 0, 0.022)
            ..quadraticBezierTo(-0.012, 0, 0, -0.022)
            ..close();
          piece(c, [(p, const Color(0xFFC8283A))], d: 0.006, weight: 0.35);
        });
      }
    case 'sparkles':
      for (final (x, y, s) in [(0.14, 0.22, 0.03), (0.86, 0.3, 0.024), (0.9, 0.62, 0.018), (0.1, 0.55, 0.02)]) {
        c.drawPath(star(Offset(x, y), s, 4, 0.25), fill(const Color(0xFFFFF0C0)));
      }
    case 'bats':
      for (final (x, y, s) in [(0.14, 0.18, 1.0), (0.85, 0.12, 0.8), (0.9, 0.4, 0.6)]) {
        at(c, Offset(x, y), s, 0, () {
          final bat = Path()..moveTo(0, -0.008);
          for (final side in [1.0, -1.0]) {
            bat
              ..moveTo(0, -0.008)
              ..quadraticBezierTo(side * 0.03, -0.03, side * 0.06, -0.01)
              ..quadraticBezierTo(side * 0.045, 0.0, side * 0.04, 0.012)
              ..quadraticBezierTo(side * 0.025, 0.0, side * 0.015, 0.012)
              ..quadraticBezierTo(side * 0.008, 0.0, 0, 0.012)
              ..close();
          }
          c.drawPath(bat, fill(const Color(0xFF0C0614)));
          c.drawPath(bat, line(const Color(0xFF3FE0D0).withValues(alpha: 0.6), thin * 0.5));
        });
      }
    case 'yarn':
      final o = Offset(g.cx - g.width * 1.15, 0.9);
      piece(c, [(oval(o, 0.1, 0.1), const Color(0xFFE88A9A))], d: 0.016);
      for (var j = 0; j < 3; j++) {
        c.drawArc(Rect.fromCenter(center: o, width: 0.08 - j * 0.02, height: 0.1), -0.6 + j, 2.2, false, line(const Color(0xFFB85A6A), thin * 0.7));
      }
      final strand = Path()
        ..moveTo(o.dx + 0.04, o.dy - 0.02)
        ..quadraticBezierTo(o.dx + 0.12, o.dy - 0.12, o.dx + 0.2, o.dy - 0.03);
      c.drawPath(strand, line(const Color(0xFFE88A9A), thin * 1.2));
    case 'coinRain':
      for (final (x, y, r) in [(0.1, 0.12, 0.022), (0.88, 0.2, 0.026), (0.84, 0.48, 0.02), (0.13, 0.42, 0.018)]) {
        _coin(c, Offset(x, y), r);
      }
  }
}

// ----------------------------------------------------------------- FRAMES -

/// A frame around the shop bust tile [r] (pixels).
void paintFrame(Canvas c, String id, Rect r) {
  final w = r.width;
  Paint st(Color col, double width) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..color = col;
  final round = RRect.fromRectAndRadius(r, Radius.circular(w * 0.05));
  switch (id) {
    case 'deco':
      c.drawRRect(round.deflate(w * 0.012), st(ink, w * 0.04));
      c.drawRRect(round.deflate(w * 0.012), st(const Color(0xFFC99A3E), w * 0.026));
      c.drawRRect(round.deflate(w * 0.012), st(const Color(0xFFFFE2A0), w * 0.006));
      c.drawRRect(round.deflate(w * 0.04), st(const Color(0xFF8C6420), w * 0.006));
      for (final corner in [r.topLeft, r.topRight, r.bottomLeft, r.bottomRight]) {
        final sx = corner.dx == r.left ? 1.0 : -1.0;
        final sy = corner.dy == r.top ? 1.0 : -1.0;
        for (var j = 0; j < 3; j++) {
          final o = corner + Offset(sx * w * (0.06 + j * 0.035), sy * w * 0.06);
          c.drawLine(o, o + Offset(0, sy * w * (0.06 - j * 0.015)), st(const Color(0xFFFFD27A), w * 0.008));
        }
        c.drawPath(star(corner + Offset(sx * w * 0.035, sy * w * 0.035), w * 0.03, 4, 0.35, turn: pi / 4), fill(const Color(0xFFFFD27A)));
      }
    case 'silverMoon':
      c.drawRRect(round.deflate(w * 0.012), st(ink, w * 0.036));
      c.drawRRect(round.deflate(w * 0.012), st(const Color(0xFFB8C4D8), w * 0.022));
      c.drawRRect(round.deflate(w * 0.012), st(const Color(0xFFF0F4FF), w * 0.005));
      for (var j = 0; j < 9; j++) {
        final x = r.left + w * (0.15 + j * 0.0875);
        c.drawPath(star(Offset(x, r.bottom - w * 0.012), w * (j.isEven ? 0.018 : 0.011), 4, 0.35), fill(const Color(0xFFF0F4FF)));
      }
      final m = Offset(r.center.dx, r.top + w * 0.012);
      c.drawCircle(m, w * 0.04, fill(ink));
      c.drawPath(Path.combine(PathOperation.difference, oval(m, w * 0.07, w * 0.07), oval(m + Offset(w * 0.02, -w * 0.008), w * 0.06, w * 0.06)), fill(const Color(0xFFF0F4FF)));
    case 'cathedral':
      c.drawRRect(round.deflate(w * 0.012), st(ink, w * 0.05));
      c.drawRRect(round.deflate(w * 0.012), st(const Color(0xFFB8862E), w * 0.034));
      for (var j = 0; j < 24; j++) {
        final t = j / 24;
        final p = Path()..addRRect(round.deflate(w * 0.012));
        final metric = p.computeMetrics().first;
        final tan = metric.getTangentForOffset(metric.length * t)!;
        c.drawCircle(tan.position, w * 0.01, fill(j.isEven ? const Color(0xFFC0272D) : const Color(0xFF2E6AB8)));
        c.drawCircle(tan.position, w * 0.01, st(ink, w * 0.003));
      }
      c.drawRRect(round.deflate(w * 0.036), st(const Color(0xFFFFE2A0), w * 0.004));
    case 'neonTube':
      for (final (col, width) in [(const Color(0x33FF4FA3), w * 0.05), (const Color(0x77FF4FA3), w * 0.025), (const Color(0xFFFFD6EC), w * 0.007)]) {
        c.drawRRect(round.deflate(w * 0.02), st(col, width));
      }
      for (final (col, width) in [(const Color(0x553FE0D0), w * 0.02), (const Color(0xFFCFFFF8), w * 0.004)]) {
        c.drawRRect(round.deflate(w * 0.045), st(col, width));
      }
    case 'lace':
      c.drawRRect(round.deflate(w * 0.014), st(ink, w * 0.034));
      c.drawRRect(round.deflate(w * 0.014), st(const Color(0xFFF2EAE1), w * 0.022));
      final p = Path()..addRRect(round.deflate(w * 0.03));
      final metric = p.computeMetrics().first;
      for (var j = 0; j < 40; j++) {
        final tan = metric.getTangentForOffset(metric.length * j / 40)!;
        c.drawCircle(tan.position, w * 0.012, st(const Color(0xFFF2EAE1), w * 0.004));
      }
      c.drawRRect(round.deflate(w * 0.014), st(const Color(0xFFB8A898), w * 0.003));
    case 'bulbs':
      c.drawRRect(round.deflate(w * 0.016), st(ink, w * 0.05));
      c.drawRRect(round.deflate(w * 0.016), st(const Color(0xFF8C1C2C), w * 0.036));
      final p = Path()..addRRect(round.deflate(w * 0.016));
      final metric = p.computeMetrics().first;
      for (var j = 0; j < 32; j++) {
        final tan = metric.getTangentForOffset(metric.length * j / 32)!;
        c.drawCircle(tan.position, w * 0.016, fill(const Color(0x44FFD27A)));
        c.drawCircle(tan.position, w * 0.009, fill(const Color(0xFFFFD27A)));
        c.drawCircle(tan.position - Offset(w * 0.003, w * 0.003), w * 0.003, fill(Colors.white));
      }
  }
}

/// The frame's accent colour for the seat card edge at the table.
Color frameAccent(String id) => switch (id) {
  'deco' => const Color(0xFFC99A3E),
  'silverMoon' => const Color(0xFFB8C4D8),
  'cathedral' => const Color(0xFFB8862E),
  'neonTube' => const Color(0xFFFF4FA3),
  'lace' => const Color(0xFFF2EAE1),
  'bulbs' => const Color(0xFFFFD27A),
  _ => brass,
};

class Colors {
  static const white = Color(0xFFFFFFFF);
}
