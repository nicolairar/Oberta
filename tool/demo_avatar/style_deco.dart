// Demo 3: deco poster. Faces sculpted in hard bands of light like a 1920s
// poster (Lempicka, the cinema bills): glossy hair, heavy-lidded sideways
// looks, gold piping and a gold sunburst behind every head. No outlines.
import 'dart:math';

import 'package:flutter/painting.dart';

import 'demo_cast.dart';

const _gold = Color(0xFFD9B45A);
const _umber = Color(0xFF1E120C);

void paintDeco(Canvas canvas, DemoChar c, double side) {
  canvas.save();
  canvas.scale(side);
  final b = Build(
    cy: 0.46,
    w: c.woman ? 0.38 : 0.41,
    h: 0.5,
    jaw: c.woman ? 0.55 : 0.85,
    chin: c.woman ? 0.12 : 0.36,
    shoulderY: 0.83,
    shoulderW: c.woman ? 0.82 : 0.98,
    neckW: c.woman ? 0.32 : 0.44,
  );
  final lw = max(0.0065, 0.9 / side);
  final small = side < 110;

  // Hard bands of light from the top left: light, base, shade, deep shade.
  void sculpt(Path p, Color base, {double light = 0.3, double dark = 0.32, bool gloss = false}) {
    final r = p.getBounds();
    final colors = gloss
        ? [tint(base, 0.08), tint(base, 0.32), base, base, tint(base, 0.18), shade(base, 0.25), shade(base, 0.45)]
        : [tint(base, light), base, shade(base, dark * 0.6), shade(base, dark)];
    final stops = gloss ? [0.0, 0.2, 0.26, 0.55, 0.6, 0.66, 0.88] : [0.0, 0.3, 0.62, 0.85];
    // Duplicate every stop so each band ends hard.
    final hardColors = <Color>[];
    final hardStops = <double>[];
    for (var i = 0; i < colors.length; i++) {
      final end = i + 1 < stops.length ? stops[i + 1] : 1.0;
      hardColors.addAll([colors[i], colors[i]]);
      hardStops.addAll([stops[i], end]);
    }
    canvas.drawPath(
      p,
      Paint()
        ..shader = LinearGradient(
          begin: const Alignment(-0.9, -1),
          end: const Alignment(0.9, 1),
          colors: hardColors,
          stops: hardStops,
        ).createShader(r),
    );
  }

  // The sunburst.
  final sun = Offset(b.cx, b.cy - b.h * 0.05);
  final rays = Path();
  const n = 18;
  for (var i = 0; i < n; i++) {
    final a0 = -pi + (i + 0.0) * 2 * pi / n;
    final a1 = a0 + pi / n;
    rays
      ..moveTo(sun.dx, sun.dy)
      ..lineTo(sun.dx + cos(a0) * 0.9, sun.dy + sin(a0) * 0.9)
      ..lineTo(sun.dx + cos(a1) * 0.9, sun.dy + sin(a1) * 0.9)
      ..close();
  }
  canvas.drawPath(rays, fill(_gold.withValues(alpha: 0.09)));
  canvas.drawCircle(sun, b.w * 0.78, stroke(_gold.withValues(alpha: 0.35), max(0.006, 1.0 / side)));
  canvas.drawCircle(sun, b.w * 0.86, stroke(_gold.withValues(alpha: 0.18), max(0.004, 0.8 / side)));

  final back = b.backHair(c);
  if (back != null) sculpt(back, c.hair, gloss: true);
  final neck = b.neck();
  sculpt(neck, shade(c.skin, 0.2));
  _outfit(canvas, c, b, lw, sculpt);

  for (final s in [-1, 1]) {
    final ear = Path()..addOval(b.ear(s));
    sculpt(ear, shade(c.skin, 0.05));
  }
  final face = b.face();
  sculpt(face, c.skin, light: 0.22, dark: 0.3);
  canvas.save();
  canvas.clipPath(face);
  // The planes of the face: under the cheekbone and down the nose.
  for (final s in [-1, 1]) {
    final cheek = Path()
      ..moveTo(b.cx + s * b.r * 1.05, b.noseY - b.h * 0.06)
      ..quadraticBezierTo(b.cx + s * b.r * 0.55, b.noseY + b.h * 0.02, b.cx + s * b.r * 0.5, b.mouthY + b.h * 0.08)
      ..lineTo(b.cx + s * b.r * 1.1, b.mouthY + b.h * 0.2)
      ..close();
    canvas.drawPath(cheek, fill(shade(c.skin, s > 0 ? 0.24 : 0.12).withValues(alpha: 0.75)));
  }
  final plane = Path()
    ..moveTo(b.cx + b.w * 0.02, b.eyeY - b.h * 0.02)
    ..lineTo(b.cx + b.w * 0.085, b.noseY + b.h * 0.01)
    ..lineTo(b.cx + b.w * 0.01, b.noseY + b.h * 0.035)
    ..close();
  canvas.drawPath(plane, fill(shade(c.skin, 0.28)));
  if (c.hat == DemoHat.fedora || c.hat == DemoHat.bowler) {
    canvas.drawRect(Rect.fromLTRB(0, 0, 1, b.top + b.h * 0.3), fill(shade(c.skin, 0.45).withValues(alpha: 0.85)));
  }
  canvas.restore();

  _features(canvas, c, b, lw, small);

  if (c.beard == DemoBeard.full) sculpt(b.beard(), c.hair, gloss: true);
  if (c.beard != DemoBeard.none) sculpt(b.mustache(), c.hair, gloss: true);

  final front = b.frontHair(c);
  sculpt(front, c.hair, gloss: true);
  if (c.greyTemples) {
    canvas.save();
    canvas.clipPath(front);
    for (final s in [-1, 1]) {
      canvas.drawRect(Rect.fromCenter(center: Offset(b.cx + s * b.r, b.cy - b.h * 0.02), width: b.w * 0.22, height: b.h * 0.16), fill(const Color(0xFFA8A29A)));
    }
    canvas.restore();
  }
  // Gold rim light along the top of the hair.
  canvas.save();
  canvas.clipRect(Rect.fromLTRB(0, 0, b.cx + b.r * 0.2, b.cy));
  canvas.drawPath(front, stroke(_gold.withValues(alpha: 0.8), lw * 1.2));
  canvas.restore();

  final extras = Extras(canvas, b, ink: _umber, lw: lw);
  extras.glasses(c);
  extras.prop(c);

  if (c.hat != DemoHat.none) {
    final (brim, crown, band) = b.hat(c);
    if (c.hat == DemoHat.crown) {
      sculpt(crown, c.hatColor, light: 0.5, dark: 0.35);
      sculpt(band, shade(c.hatColor, 0.15));
      canvas.drawPath(brim, fill(c.hatBand));
    } else {
      sculpt(crown, c.hatColor, light: 0.35);
      canvas.drawPath(band, fill(c.hatBand));
      sculpt(brim, c.hatColor, light: 0.4);
      // Gold piping on the brim and the band.
      canvas.drawPath(band, stroke(_gold.withValues(alpha: 0.9), lw));
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(0, 0, b.cx, 1));
      canvas.drawPath(crown, stroke(_gold.withValues(alpha: 0.7), lw));
      canvas.restore();
      if (c.hat == DemoHat.cloche) {
        // A deco fan pin.
        final pin = Offset(b.cx + b.r * 0.72, b.browY - b.h * 0.1);
        for (var i = 0; i < 5; i++) {
          final a = -pi / 2 + (i - 2) * 0.35;
          canvas.drawLine(pin, pin + Offset(cos(a), sin(a)) * b.w * 0.12, stroke(_gold, lw * 1.6));
        }
        canvas.drawCircle(pin, b.w * 0.03, fill(_gold));
      }
    }
  }
  if (c.golden) extras.gilt();
  canvas.restore();
}

void _outfit(Canvas canvas, DemoChar c, Build b, double lw, void Function(Path, Color, {double light, double dark, bool gloss}) sculpt) {
  final torso = b.torso();
  switch (c.outfit) {
    case DemoOutfit.suit:
      sculpt(torso, c.cloth, light: 0.22, dark: 0.4);
      if (c.stripes) {
        canvas.save();
        canvas.clipPath(torso);
        for (var x = 0.02; x < 1; x += 0.045) {
          canvas.drawLine(Offset(x, b.shoulderY - 0.05), Offset(x + 0.01, 1.05), stroke(_gold.withValues(alpha: 0.35), max(0.003, 0.6 / 256)));
        }
        canvas.restore();
      }
      sculpt(b.vee(depth: 0.18), c.shirt, light: 0.1, dark: 0.2);
      if (c.neck == DemoNeck.tie) sculpt(b.tie(), c.accent, light: 0.35);
      for (final s in [-1, 1]) {
        final lapel = b.lapel(s);
        sculpt(lapel, shade(c.cloth, 0.2), light: 0.3, dark: 0.3);
        canvas.drawPath(lapel, stroke(_gold.withValues(alpha: 0.6), lw));
      }
      Extras(canvas, b, ink: _umber, lw: lw).neckwear(c);
    case DemoOutfit.dress:
      sculpt(torso, c.cloth, light: 0.2, dark: 0.4);
      final scoop = b.scoop();
      sculpt(scoop, shade(c.skin, 0.12));
      canvas.drawPath(scoop, stroke(_gold.withValues(alpha: 0.75), lw * 1.2));
      if (c.pearls) {
        for (var i = 0; i <= 10; i++) {
          final t = i / 10;
          final at = Offset(b.cx + (t - 0.5) * b.w * b.neckW * 1.6, b.shoulderY + 0.005 + sin(t * pi) * 0.055);
          canvas.drawCircle(at, 0.011, fill(const Color(0xFFEDE5D8)));
          canvas.drawCircle(at.translate(-0.003, -0.003), 0.004, fill(const Color(0xFFFFFFFF)));
        }
      }
      if (c.accent == const Color(0xFFE2B54E)) {
        for (final s in [-1, 1]) {
          final ear = b.ear(s);
          final top = Offset(ear.center.dx, ear.bottom);
          final drop = Path()
            ..moveTo(top.dx, top.dy)
            ..lineTo(top.dx + 0.014, top.dy + 0.03)
            ..lineTo(top.dx, top.dy + 0.06)
            ..lineTo(top.dx - 0.014, top.dy + 0.03)
            ..close();
          canvas.drawPath(drop, fill(c.accent));
        }
      }
      if (c.hat == DemoHat.cloche && c.name == 'Greta') {
        for (final s in [-1, 1]) {
          final p = Path()
            ..moveTo(b.cx + s * b.w * b.neckW * 0.9, b.shoulderY - 0.02)
            ..lineTo(b.cx + s * 0.22, b.shoulderY + 0.05)
            ..lineTo(b.cx + s * 0.05, b.shoulderY + 0.2)
            ..close();
          sculpt(p, shade(c.cloth, 0.15), light: 0.35);
          canvas.drawPath(p, stroke(_gold.withValues(alpha: 0.6), lw));
        }
      }
    case DemoOutfit.calcio:
      sculpt(torso, c.cloth, light: 0.25, dark: 0.4);
      if (c.shirt != c.cloth) {
        canvas.save();
        canvas.clipPath(torso);
        for (var x = 0.5 - 0.06 - 0.24; x < 1; x += 0.12) {
          sculpt(Path()..addRect(Rect.fromLTWH(x, b.shoulderY - 0.05, 0.06, 0.3)), c.shirt, light: 0.25);
        }
        canvas.restore();
      }
      final collar = b.vee(depth: 0.1, width: 0.55);
      sculpt(collar, shade(c.skin, 0.2));
      canvas.drawPath(collar, stroke(c.accent, max(0.014, 1.4 / 256)));
      final badge = Offset(b.cx + 0.16, b.shoulderY + 0.1);
      canvas.drawCircle(badge, 0.032, fill(_gold));
      canvas.drawCircle(badge, 0.022, fill(c.accent));
  }
}

void _features(Canvas canvas, DemoChar c, Build b, double lw, bool small) {
  // Everyone glances a little to the side, like a poster.
  const look = -0.25;
  for (final s in [-1.0, 1.0]) {
    final e = Offset(b.cx + s * b.eyeDx, b.eyeY);
    final ew = b.w * 0.21;
    final eh = ew * 0.5;
    final almond = Path()
      ..moveTo(e.dx - ew / 2, e.dy + eh * 0.1)
      ..quadraticBezierTo(e.dx - ew * 0.05, e.dy - eh * 1.1, e.dx + ew / 2, e.dy - eh * 0.15)
      ..quadraticBezierTo(e.dx, e.dy + eh * 0.85, e.dx - ew / 2, e.dy + eh * 0.1)
      ..close();
    if (small) {
      canvas.drawPath(almond, fill(_umber));
      canvas.drawCircle(Offset(e.dx + look * ew * 0.3, e.dy + eh * 0.05), ew * 0.1, fill(const Color(0xBBFFF4E0)));
    } else {
      canvas.drawPath(almond, fill(const Color(0xFFEDE2D0)));
      canvas.save();
      canvas.clipPath(almond);
      final iris = Offset(e.dx + look * ew * 0.6, e.dy + eh * 0.08);
      canvas.drawCircle(iris, eh * 0.62, fill(c.eye));
      canvas.drawCircle(iris, eh * 0.28, fill(_umber));
      canvas.drawCircle(iris.translate(eh * 0.2, -eh * 0.22), eh * 0.12, fill(const Color(0xFFFFFFFF)));
      // The heavy lid: half the eye under it.
      canvas.drawRect(Rect.fromLTRB(e.dx - ew, e.dy - eh * 1.2, e.dx + ew, e.dy - eh * 0.2), fill(shade(c.skin, c.woman ? 0.4 : 0.3)));
      canvas.restore();
      canvas.drawLine(Offset(e.dx - ew / 2, e.dy - eh * 0.15), Offset(e.dx + ew / 2, e.dy - eh * 0.25), stroke(_umber, lw * (c.woman ? 2.2 : 1.6)));
    }
    if (c.woman) {
      // Eye shadow swept up to the brow.
      final lid = Path()
        ..moveTo(e.dx - ew / 2, e.dy - eh * 0.1)
        ..quadraticBezierTo(e.dx, e.dy - eh * 1.6, e.dx + s * ew * 0.7, e.dy - eh * 0.9)
        ..quadraticBezierTo(e.dx, e.dy - eh * 0.9, e.dx - ew / 2, e.dy - eh * 0.1)
        ..close();
      canvas.drawPath(lid, fill(shade(c.cloth, 0.2).withValues(alpha: 0.55)));
    }
    // Brows: a long thin arch, a little heavier on the men.
    final brow = Path()
      ..moveTo(b.cx + s * b.w * 0.07, b.browY + b.h * (c.woman ? 0.01 : 0.02))
      ..quadraticBezierTo(b.cx + s * b.w * 0.25, b.browY - b.h * (c.woman ? 0.065 : 0.03), b.cx + s * b.w * 0.37, b.browY + b.h * 0.005);
    canvas.drawPath(brow, stroke(shade(c.hair, 0.2), max(lw * 1.3, b.h * (c.woman ? 0.012 : 0.022))));
  }
  final my = b.mouthY;
  final lips = c.lips ?? shade(Color.lerp(c.skin, const Color(0xFFA04040), 0.25)!, 0.2);
  final mw = b.w * (c.lips != null ? 0.14 : 0.13);
  final upper = Path()
    ..moveTo(b.cx - mw, my)
    ..quadraticBezierTo(b.cx - mw * 0.5, my - b.h * 0.04, b.cx - mw * 0.12, my - b.h * 0.032)
    ..lineTo(b.cx, my - b.h * 0.02)
    ..lineTo(b.cx + mw * 0.12, my - b.h * 0.032)
    ..quadraticBezierTo(b.cx + mw * 0.5, my - b.h * 0.04, b.cx + mw, my)
    ..close();
  final lower = Path()
    ..moveTo(b.cx - mw * 0.9, my)
    ..lineTo(b.cx + mw * 0.9, my)
    ..quadraticBezierTo(b.cx + mw * 0.5, my + b.h * (c.lips != null ? 0.055 : 0.035), b.cx, my + b.h * (c.lips != null ? 0.055 : 0.035))
    ..quadraticBezierTo(b.cx - mw * 0.5, my + b.h * (c.lips != null ? 0.055 : 0.035), b.cx - mw * 0.9, my)
    ..close();
  canvas.drawPath(upper, fill(shade(lips, 0.3)));
  canvas.drawPath(lower, fill(lips));
  if (!small) canvas.drawRect(Rect.fromLTWH(b.cx - mw * 0.4, my + b.h * 0.015, mw * 0.35, b.h * 0.012), fill(tint(lips, 0.5).withValues(alpha: 0.7)));
  if (c.freckles) {
    final rnd = Random(5);
    for (var i = 0; i < (small ? 5 : 14); i++) {
      final s = i.isEven ? -1 : 1;
      canvas.drawCircle(
        Offset(b.cx + s * b.r * (0.25 + rnd.nextDouble() * 0.45), b.noseY - b.h * 0.05 + rnd.nextDouble() * b.h * 0.07),
        small ? 0.006 : 0.004,
        fill(const Color(0xFFA0522D).withValues(alpha: 0.8)),
      );
    }
  }
}
