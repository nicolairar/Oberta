// Demo 2: bold cartoon noir. Big heads and square jaws, a heavy ink
// silhouette with thin inner lines, flat colour with one hard shadow cut
// away from the lamp, a warm rim of light, eyes lost under the brim.
import 'dart:math';

import 'package:flutter/painting.dart';

import 'demo_cast.dart';

const _ink = Color(0xFF0B0809);
const _night = Color(0xFF1A1236);
const _lamp = Color(0xFFFFD27A);

void paintNoir(Canvas canvas, DemoChar c, double side) {
  canvas.save();
  canvas.scale(side);
  final b = Build(
    cy: 0.47,
    w: c.woman ? 0.44 : 0.47,
    h: 0.5,
    jaw: c.woman ? 0.58 : 0.95,
    chin: c.woman ? 0.14 : 0.5,
    shoulderY: 0.83,
    shoulderW: c.woman ? 0.84 : 1.04,
    neckW: c.woman ? 0.32 : 0.5,
  );
  final ow = max(0.024, 2.2 / side);
  final thin = max(0.009, 1.0 / side);
  final small = side < 110;

  Color dark(Color base) => Color.lerp(base, _night, 0.55)!;

  // Flat colour, the hard shadow on the side away from the lamp, a rim of
  // warm light on the lit edge and a thin inner line.
  void toon(Path p, Color base, {double d = 0.06, bool rim = true, bool line = true}) {
    canvas.drawPath(p, fill(base));
    final shadow = Path.combine(PathOperation.difference, p, p.shift(Offset(-d, -d * 0.8)));
    canvas.drawPath(shadow, fill(dark(base)));
    if (rim) {
      final lit = Path.combine(PathOperation.difference, p, p.shift(const Offset(0.014, 0.012)));
      canvas.drawPath(lit, fill(Color.lerp(base, _lamp, 0.45)!));
    }
    if (line) canvas.drawPath(p, stroke(_ink, thin));
  }

  void silhouette(Iterable<Path?> parts) {
    for (final p in parts) {
      if (p != null) canvas.drawPath(p, stroke(_ink, ow * 2));
    }
  }

  final back = b.backHair(c);
  final neck = b.neck();
  final torso = b.torso();
  final face = b.face();
  final front = b.frontHair(c);
  final beard = c.beard == DemoBeard.full ? b.beard() : null;
  final ears = [for (final s in [-1, 1]) Path()..addOval(b.ear(s))];
  final hat = c.hat == DemoHat.none ? null : b.hat(c);

  // One heavy outline around the whole figure.
  silhouette([back, neck, torso, ...ears, face, front, beard, hat?.$2, if (c.hat != DemoHat.crown) hat?.$1]);

  if (back != null) toon(back, c.hair, d: 0.08);
  toon(neck, dark(c.skin), rim: false);
  _outfit(canvas, c, b, thin, toon);
  for (final e in ears) {
    toon(e, c.skin, d: 0.03);
  }
  toon(face, c.skin, d: 0.075);

  // The brim's shadow, a hard band across the eyes.
  final brimmed = c.hat == DemoHat.fedora || c.hat == DemoHat.bowler;
  if (brimmed || c.hat == DemoHat.cloche) {
    canvas.save();
    canvas.clipPath(face);
    final low = brimmed ? b.eyeY + b.h * 0.03 : b.browY + b.h * 0.02;
    final band = Path()
      ..moveTo(0, 0)
      ..lineTo(1, 0)
      ..lineTo(1, low - 0.02)
      ..quadraticBezierTo(b.cx + 0.1, low + 0.02, b.cx - 0.05, low)
      ..quadraticBezierTo(b.cx - 0.15, low - 0.015, 0, low + 0.02)
      ..close();
    canvas.drawPath(band, fill(dark(c.skin).withValues(alpha: 0.92)));
    canvas.restore();
  }

  _features(canvas, c, b, thin, ow, small, shaded: brimmed);

  if (beard != null) {
    toon(beard, c.hair, d: 0.06);
  }
  if (c.beard != DemoBeard.none) {
    final m = b.mustache();
    canvas.drawPath(m, stroke(_ink, thin * 1.5));
    toon(m, beard != null ? Color.lerp(c.hair, _lamp, 0.08)! : c.hair, d: 0.02, line: false);
  }
  toon(front, c.hair, d: 0.07);
  if (c.greyTemples) {
    canvas.save();
    canvas.clipPath(front);
    for (final s in [-1, 1]) {
      canvas.drawRect(Rect.fromCenter(center: Offset(b.cx + s * b.r, b.cy - b.h * 0.02), width: b.w * 0.2, height: b.h * 0.14), fill(const Color(0xFF8E8A86)));
    }
    canvas.restore();
  }
  // A hard gloss streak on the hair.
  canvas.save();
  canvas.clipPath(front);
  final gloss = Path()
    ..moveTo(b.cx - b.r * 0.75, b.top + b.h * 0.12)
    ..quadraticBezierTo(b.cx - b.r * 0.2, b.top - b.h * 0.03, b.cx + b.r * 0.35, b.top + b.h * 0.0)
    ..quadraticBezierTo(b.cx - b.r * 0.2, b.top + b.h * 0.03, b.cx - b.r * 0.75, b.top + b.h * 0.12)
    ..close();
  canvas.drawPath(gloss, fill(Color.lerp(c.hair, _lamp, 0.4)!));
  canvas.restore();

  final extras = Extras(canvas, b, ink: _ink, lw: thin * 1.2, bold: true);
  extras.glasses(c);
  extras.prop(c);

  if (hat != null) {
    final (brim, crown, band) = hat;
    if (c.hat == DemoHat.crown) {
      toon(crown, c.hatColor, d: 0.05);
      canvas.drawPath(band, fill(dark(c.hatColor)));
      canvas.drawPath(band, stroke(_ink, thin));
      canvas.drawPath(brim, stroke(_ink, thin * 1.5));
      canvas.drawPath(brim, fill(c.hatBand));
    } else {
      toon(crown, c.hatColor, d: 0.07);
      canvas.drawPath(band, fill(c.hatBand));
      canvas.drawPath(band, stroke(_ink, thin));
      toon(brim, c.hatColor, d: 0.035);
      if (c.hat == DemoHat.cloche) {
        final pin = Offset(b.cx + b.r * 0.72, b.browY - b.h * 0.09);
        canvas.drawCircle(pin, b.w * 0.065, fill(_ink));
        canvas.drawCircle(pin, b.w * 0.05, fill(c.accent));
      }
    }
  }
  if (c.golden) extras.gilt();
  canvas.restore();
}

void _outfit(Canvas canvas, DemoChar c, Build b, double thin, void Function(Path, Color, {double d, bool rim, bool line}) toon) {
  final torso = b.torso();
  switch (c.outfit) {
    case DemoOutfit.suit:
      toon(torso, c.cloth, d: 0.1);
      if (c.stripes) {
        canvas.save();
        canvas.clipPath(torso);
        for (var x = 0.03; x < 1; x += 0.05) {
          canvas.drawLine(Offset(x, b.shoulderY - 0.05), Offset(x + 0.012, 1.05), stroke(Color.lerp(c.cloth, _lamp, 0.25)!.withValues(alpha: 0.7), max(0.004, 0.7 / 256)));
        }
        canvas.restore();
      }
      final vee = b.vee(depth: 0.18);
      canvas.drawPath(vee, fill(c.shirt));
      canvas.drawPath(vee, stroke(_ink, thin));
      if (c.neck == DemoNeck.tie) toon(b.tie(), c.accent, d: 0.02, rim: false);
      for (final s in [-1, 1]) {
        toon(b.lapel(s), Color.lerp(c.cloth, _ink, 0.3)!, d: 0.025, rim: s < 0);
      }
      Extras(canvas, b, ink: _ink, lw: thin * 1.2, bold: true).neckwear(c);
    case DemoOutfit.dress:
      toon(torso, c.cloth, d: 0.1);
      final scoop = b.scoop();
      canvas.drawPath(scoop, fill(Color.lerp(c.skin, _night, 0.3)!));
      canvas.drawPath(scoop, stroke(_ink, thin));
      if (c.pearls) {
        for (var i = 0; i <= 8; i++) {
          final t = i / 8;
          final at = Offset(b.cx + (t - 0.5) * b.w * b.neckW * 1.7, b.shoulderY + 0.005 + sin(t * pi) * 0.06);
          canvas.drawCircle(at, 0.016, fill(_ink));
          canvas.drawCircle(at, 0.012, fill(const Color(0xFFF4EEE6)));
        }
      }
      if (c.accent == const Color(0xFFE2B54E)) {
        for (final s in [-1, 1]) {
          final ear = b.ear(s);
          final drop = Offset(ear.center.dx, ear.bottom + 0.025);
          canvas.drawCircle(drop, 0.02, fill(_ink));
          canvas.drawCircle(drop, 0.015, fill(c.accent));
        }
      }
      if (c.hat == DemoHat.cloche && c.name == 'Greta') {
        for (final s in [-1, 1]) {
          final p = Path()
            ..moveTo(b.cx + s * b.w * b.neckW * 0.9, b.shoulderY - 0.02)
            ..lineTo(b.cx + s * 0.22, b.shoulderY + 0.05)
            ..lineTo(b.cx + s * 0.05, b.shoulderY + 0.2)
            ..close();
          toon(p, Color.lerp(c.cloth, _ink, 0.2)!, d: 0.02);
        }
      }
    case DemoOutfit.calcio:
      toon(torso, c.cloth, d: 0.1, line: false);
      if (c.shirt != c.cloth) {
        canvas.save();
        canvas.clipPath(torso);
        for (var x = 0.5 - 0.07 - 0.28; x < 1; x += 0.14) {
          canvas.drawRect(Rect.fromLTWH(x, 0, 0.07, 1.1), fill(c.shirt));
        }
        canvas.drawPath(Path.combine(PathOperation.difference, torso, torso.shift(const Offset(-0.1, -0.08))), fill(const Color(0x88140A28)));
        canvas.restore();
      }
      canvas.drawPath(torso, stroke(_ink, thin));
      final collar = b.vee(depth: 0.1, width: 0.55);
      canvas.drawPath(collar, fill(Color.lerp(c.skin, _night, 0.35)!));
      canvas.drawPath(collar, stroke(_ink, max(0.03, 2.6 / 256)));
      canvas.drawPath(collar, stroke(c.accent, max(0.016, 1.4 / 256)));
      final badge = Rect.fromLTWH(b.cx + 0.13, b.shoulderY + 0.07, 0.06, 0.07);
      canvas.drawOval(badge.inflate(0.008), fill(_ink));
      canvas.drawOval(badge, fill(c.accent));
  }
}

void _features(Canvas canvas, DemoChar c, Build b, double thin, double ow, bool small, {required bool shaded}) {
  for (final s in [-1.0, 1.0]) {
    final e = Offset(b.cx + s * b.eyeDx, b.eyeY);
    final ew = b.w * 0.21;
    if (c.woman) {
      // Heavy lids: a black almond, half closed, with a wing.
      final eh = ew * 0.38;
      final eye = Path()
        ..moveTo(e.dx - ew / 2, e.dy)
        ..quadraticBezierTo(e.dx, e.dy - eh * 1.3, e.dx + ew / 2, e.dy)
        ..quadraticBezierTo(e.dx, e.dy + eh * 0.9, e.dx - ew / 2, e.dy)
        ..close();
      canvas.drawPath(eye, fill(_ink));
      final corner = Offset(e.dx + s * ew / 2, e.dy);
      final wing = Path()
        ..moveTo(corner.dx - s * ew * 0.2, corner.dy - eh * 0.55)
        ..lineTo(corner.dx + s * ew * 0.25, corner.dy - eh * 1.0)
        ..lineTo(corner.dx, corner.dy + eh * 0.1)
        ..close();
      canvas.drawPath(wing, fill(_ink));
      canvas.drawCircle(Offset(e.dx + s * ew * 0.05, e.dy + eh * 0.05), eh * 0.42, fill(Color.lerp(c.eye, _lamp, 0.15)!));
      canvas.drawCircle(Offset(e.dx - ew * 0.05, e.dy - eh * 0.1), max(eh * 0.2, 0.006), fill(const Color(0xFFFFFFFF)));
      // Thin high brow.
      final brow = Path()
        ..moveTo(b.cx + s * b.w * 0.08, b.browY + b.h * 0.005)
        ..quadraticBezierTo(b.cx + s * b.w * 0.24, b.browY - b.h * 0.07, b.cx + s * b.w * 0.36, b.browY);
      canvas.drawPath(brow, stroke(_ink, max(thin * 1.6, b.h * 0.018)));
    } else {
      // Narrow white slits with a hard pupil, under a heavy wedge brow.
      final eh = ew * 0.32;
      final eye = Path()
        ..moveTo(e.dx - ew / 2, e.dy)
        ..quadraticBezierTo(e.dx, e.dy - eh * 1.2, e.dx + ew / 2, e.dy)
        ..quadraticBezierTo(e.dx, e.dy + eh * 0.8, e.dx - ew / 2, e.dy)
        ..close();
      canvas.drawPath(eye, stroke(_ink, thin * 1.4));
      canvas.drawPath(eye, fill(shaded ? const Color(0xFFFFF1CC) : const Color(0xFFF3EADC)));
      canvas.save();
      canvas.clipPath(eye);
      canvas.drawCircle(Offset(e.dx + s * ew * 0.06, e.dy), eh * 0.75, fill(_ink));
      canvas.restore();
      final brow = Path()
        ..moveTo(b.cx + s * b.w * 0.05, b.browY + b.h * 0.045)
        ..lineTo(b.cx + s * b.w * 0.37, b.browY - b.h * 0.025)
        ..lineTo(b.cx + s * b.w * 0.36, b.browY + b.h * 0.025)
        ..lineTo(b.cx + s * b.w * 0.07, b.browY + b.h * 0.075)
        ..close();
      canvas.drawPath(brow, fill(_ink));
    }
  }
  // The nose: one angular stroke on the shadow side.
  final nose = Path()
    ..moveTo(b.cx + b.w * 0.02, b.eyeY + b.h * 0.04)
    ..lineTo(b.cx + b.w * 0.08, b.noseY + b.h * 0.005)
    ..lineTo(b.cx - b.w * 0.03, b.noseY + b.h * 0.02);
  canvas.drawPath(nose, stroke(_ink, thin * 1.4));
  final my = b.mouthY;
  if (c.lips != null) {
    final mw = b.w * 0.14;
    final lips = Path()
      ..moveTo(b.cx - mw, my)
      ..lineTo(b.cx - mw * 0.3, my - b.h * 0.035)
      ..lineTo(b.cx, my - b.h * 0.02)
      ..lineTo(b.cx + mw * 0.3, my - b.h * 0.035)
      ..lineTo(b.cx + mw, my)
      ..quadraticBezierTo(b.cx, my + b.h * 0.07, b.cx - mw, my)
      ..close();
    canvas.drawPath(lips, stroke(_ink, thin * 1.2));
    canvas.drawPath(lips, fill(c.lips!));
    canvas.drawLine(Offset(b.cx - mw, my), Offset(b.cx + mw, my), stroke(_ink, thin));
  } else {
    final mw = b.w * 0.13;
    canvas.drawLine(Offset(b.cx - mw, my), Offset(b.cx + mw * 0.9, my - b.h * 0.012), stroke(_ink, thin * 1.6));
    canvas.drawLine(Offset(b.cx - mw * 0.35, my + b.h * 0.055), Offset(b.cx + mw * 0.35, my + b.h * 0.055), stroke(_ink, thin));
  }
  if (c.freckles) {
    final rnd = Random(3);
    for (var i = 0; i < (small ? 6 : 12); i++) {
      final s = i.isEven ? -1 : 1;
      canvas.drawCircle(
        Offset(b.cx + s * b.r * (0.25 + rnd.nextDouble() * 0.45), b.noseY - b.h * 0.05 + rnd.nextDouble() * b.h * 0.07),
        small ? 0.008 : 0.006,
        fill(const Color(0xFF8E3A1C)),
      );
    }
  }
}
