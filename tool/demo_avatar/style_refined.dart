// Demo 1: the current style, refined. Bigger heads, real eyes with irises
// and lids, expressive brows, soft lamp shading and one consistent line.
import 'dart:math';

import 'package:flutter/painting.dart';

import 'demo_cast.dart';

void paintRefined(Canvas canvas, DemoChar c, double side) {
  canvas.save();
  canvas.scale(side);
  final b = Build(
    cy: 0.45,
    w: 0.4,
    h: 0.47,
    jaw: c.woman ? 0.6 : 0.8,
    chin: c.woman ? 0.16 : 0.3,
    shoulderY: 0.82,
    shoulderW: c.woman ? 0.8 : 0.94,
    neckW: c.woman ? 0.34 : 0.42,
  );
  // One line weight for everything, never thinner than a pixel.
  final lw = max(0.0075, 1.0 / side);
  final small = side < 110;
  final skinLine = shade(c.skin, 0.62);

  void soft(Path p, Color base, {Color? line, double lift = 0.14, double drop = 0.34}) {
    final r = p.getBounds();
    canvas.drawPath(
      p,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [tint(base, lift), base, shade(base, drop)],
          stops: const [0, 0.42, 1],
        ).createShader(r),
    );
    if (line != null) canvas.drawPath(p, stroke(line, lw));
  }

  // Hair behind the face.
  final back = b.backHair(c);
  if (back != null) soft(back, c.hair, line: shade(c.hair, 0.6), lift: 0.22);

  // Neck, with the chin's shadow.
  final neck = b.neck();
  soft(neck, shade(c.skin, 0.12), line: skinLine);
  canvas.save();
  canvas.clipPath(neck);
  canvas.drawRect(
    Rect.fromLTRB(0, b.cy + b.h * 0.25, 1, b.bottom + 0.05),
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [shade(c.skin, 0.55), shade(c.skin, 0.55).withValues(alpha: 0)],
      ).createShader(Rect.fromLTRB(0, b.bottom - 0.03, 1, b.bottom + 0.05)),
  );
  canvas.restore();

  _outfit(canvas, c, b, lw, soft);

  // Ears, then the face over them.
  for (final s in [-1, 1]) {
    final ear = b.ear(s);
    canvas.drawOval(ear, fill(shade(c.skin, 0.1)));
    canvas.drawOval(ear, stroke(skinLine, lw));
    if (!small) canvas.drawArc(ear.deflate(ear.width * 0.25), s < 0 ? pi * 0.6 : -pi * 0.6, s < 0 ? pi * 0.8 : pi * 0.8, false, stroke(shade(c.skin, 0.4), lw * 0.8));
  }
  final face = b.face();
  canvas.drawPath(
    face,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.45),
        radius: 1.05,
        colors: [tint(c.skin, 0.16), c.skin, shade(c.skin, 0.3)],
        stops: const [0, 0.5, 1],
      ).createShader(face.getBounds()),
  );
  canvas.save();
  canvas.clipPath(face);
  // Warm cheeks.
  for (final s in [-1, 1]) {
    final at = Offset(b.cx + s * b.r * 0.55, b.cy + b.h * 0.2);
    canvas.drawCircle(
      at,
      b.w * 0.16,
      Paint()
        ..shader = RadialGradient(colors: [const Color(0xFFD0574A).withValues(alpha: c.woman ? 0.28 : 0.14), const Color(0x00D0574A)])
            .createShader(Rect.fromCircle(center: at, radius: b.w * 0.16)),
    );
  }
  // The hair and the hat throw a shadow on the forehead.
  final brimmed = c.hat == DemoHat.fedora || c.hat == DemoHat.bowler;
  final shadowTop = brimmed ? b.top + b.h * 0.26 : b.top + b.h * 0.14;
  final shadowDepth = brimmed ? 0.11 : 0.05;
  canvas.drawRect(
    Rect.fromLTRB(0, 0, 1, shadowTop + shadowDepth),
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [shade(c.skin, 0.55).withValues(alpha: 0.8), shade(c.skin, 0.55).withValues(alpha: 0)],
      ).createShader(Rect.fromLTRB(0, shadowTop - 0.02, 1, shadowTop + shadowDepth)),
  );
  canvas.restore();
  canvas.drawPath(face, stroke(skinLine, lw));

  _features(canvas, c, b, lw, small);

  if (c.beard == DemoBeard.full) {
    final beard = b.beard();
    soft(beard, c.hair, line: shade(c.hair, 0.5), lift: 0.2);
    if (!small) {
      for (var i = 0; i < 7; i++) {
        final x = b.cx - b.r * 0.7 + i * b.r * 0.23;
        canvas.drawLine(Offset(x, b.bottom - b.h * 0.02), Offset(x + 0.004, b.bottom + b.h * 0.06), stroke(tint(c.hair, 0.18), lw * 0.7));
      }
    }
  }
  if (c.beard != DemoBeard.none) {
    final m = b.mustache();
    soft(m, c.beard == DemoBeard.full ? shade(c.hair, 0.15) : c.hair, line: shade(c.hair, 0.6), lift: 0.25);
  }

  // Hair over the face, with a sheen where the lamp catches it.
  final front = b.frontHair(c);
  soft(front, c.hair, line: shade(c.hair, 0.6), lift: 0.24);
  if (c.greyTemples) {
    for (final s in [-1, 1]) {
      canvas.save();
      canvas.clipPath(front);
      canvas.drawCircle(Offset(b.cx + s * b.r * 1.02, b.cy), b.w * 0.12, fill(const Color(0xFF8C8782)));
      canvas.restore();
    }
  }
  canvas.save();
  canvas.clipPath(front);
  canvas.drawArc(
    Rect.fromCenter(center: Offset(b.cx - b.r * 0.15, b.top + b.h * 0.12), width: b.w * 0.9, height: b.h * 0.3),
    pi * 1.1,
    pi * 0.45,
    false,
    stroke(tint(c.hair, 0.45).withValues(alpha: 0.7), max(0.012, 1.2 / side)),
  );
  if (c.hairStyle == DemoHair.waveBob && !small) {
    for (var i = 0; i < 3; i++) {
      final y = b.top + b.h * (0.02 + i * 0.07);
      final p = Path()..moveTo(b.cx - b.r * 1.1, y + 0.03);
      p.cubicTo(b.cx - b.r * 0.5, y - 0.03, b.cx, y + 0.05, b.cx + b.r * 1.1, y);
      canvas.drawPath(p, stroke(shade(c.hair, 0.6), lw));
    }
  }
  canvas.restore();

  final extras = Extras(canvas, b, ink: const Color(0xFF140C08), lw: lw);
  extras.glasses(c);
  extras.prop(c);

  if (c.hat != DemoHat.none) {
    final (brim, crown, band) = b.hat(c);
    final hatLine = shade(c.hatColor, 0.7);
    if (c.hat == DemoHat.bowler) {
      soft(crown, c.hatColor, line: hatLine, lift: 0.3);
      canvas.drawPath(band, fill(c.hatBand));
      soft(brim, tint(c.hatColor, 0.08), line: hatLine, lift: 0.25);
    } else if (c.hat == DemoHat.crown) {
      soft(crown, c.hatColor, line: shade(c.hatColor, 0.6), lift: 0.4);
      canvas.drawPath(band, fill(shade(c.hatColor, 0.2)));
      canvas.drawPath(band, stroke(shade(c.hatColor, 0.6), lw));
      soft(brim, c.hatBand, line: shade(c.hatBand, 0.6), lift: 0.4);
    } else if (c.hat == DemoHat.fedora) {
      soft(crown, c.hatColor, line: hatLine, lift: 0.2);
      canvas.drawPath(band, fill(c.hatBand));
      soft(brim, tint(c.hatColor, 0.05), line: hatLine, lift: 0.22);
      // The pinch of the crown.
      final dent = Path()
        ..moveTo(b.cx - b.r * 0.2, b.top - b.h * 0.12)
        ..quadraticBezierTo(b.cx, b.top - b.h * 0.04, b.cx + b.r * 0.2, b.top - b.h * 0.12);
      canvas.drawPath(dent, stroke(shade(c.hatColor, 0.5), lw));
    } else {
      soft(crown, c.hatColor, line: hatLine, lift: 0.2);
      canvas.drawPath(band, fill(c.hatBand));
      soft(brim, tint(c.hatColor, 0.06), line: hatLine, lift: 0.18);
      final pin = Offset(b.cx + b.r * 0.7, b.browY - b.h * 0.09);
      canvas.drawCircle(pin, b.w * 0.06, fill(c.accent));
      canvas.drawCircle(pin, b.w * 0.06, stroke(shade(c.accent, 0.6), lw));
      canvas.drawCircle(pin, b.w * 0.025, fill(c.hatBand));
    }
  }
  if (c.golden) extras.gilt();
  canvas.restore();
}

void _outfit(Canvas canvas, DemoChar c, Build b, double lw, void Function(Path, Color, {Color? line, double lift, double drop}) soft) {
  final torso = b.torso();
  final clothLine = shade(c.cloth, 0.7);
  switch (c.outfit) {
    case DemoOutfit.suit:
      soft(torso, c.cloth, line: clothLine);
      if (c.stripes) {
        canvas.save();
        canvas.clipPath(torso);
        for (var x = 0.02; x < 1; x += 0.04) {
          canvas.drawLine(Offset(x, b.shoulderY - 0.05), Offset(x + 0.01, 1.05), stroke(tint(c.cloth, 0.22).withValues(alpha: 0.55), max(0.0035, 0.6 / 256)));
        }
        canvas.restore();
      }
      final vee = b.vee();
      canvas.drawPath(vee, fill(c.shirt));
      canvas.drawPath(vee, stroke(shade(c.shirt, 0.5), lw));
      if (c.neck == DemoNeck.tie) soft(b.tie(), c.accent, line: shade(c.accent, 0.6), lift: 0.2);
      for (final s in [-1, 1]) {
        final lapel = b.lapel(s);
        soft(lapel, shade(c.cloth, 0.18), line: clothLine, lift: 0.1);
      }
      Extras(canvas, b, ink: shade(c.accent, 0.6), lw: lw).neckwear(c);
    case DemoOutfit.dress:
      soft(torso, c.cloth, line: clothLine, lift: 0.18);
      final scoop = b.scoop();
      canvas.drawPath(scoop, fill(shade(c.skin, 0.08)));
      canvas.drawPath(scoop, stroke(shade(c.skin, 0.6), lw));
      if (c.pearls) {
        for (var i = 0; i <= 10; i++) {
          final t = i / 10;
          final x = b.cx + (t - 0.5) * b.w * b.neckW * 1.6;
          final y = b.shoulderY + 0.005 + sin(t * pi) * 0.055;
          canvas.drawCircle(Offset(x, y), 0.011, fill(const Color(0xFFF4EEE6)));
          canvas.drawCircle(Offset(x, y), 0.011, stroke(const Color(0xFF8E8478), lw * 0.7));
        }
      }
      if (c.accent == const Color(0xFFE2B54E)) {
        for (final s in [-1, 1]) {
          final ear = b.ear(s);
          final drop = Offset(ear.center.dx, ear.bottom + 0.022);
          canvas.drawLine(Offset(ear.center.dx, ear.bottom - 0.005), drop, stroke(c.accent, lw));
          canvas.drawCircle(drop, 0.014, fill(c.accent));
        }
      }
      if (c.hat == DemoHat.cloche) {
        // A coat collar.
        for (final s in [-1, 1]) {
          final p = Path()
            ..moveTo(b.cx + s * b.w * b.neckW * 0.9, b.shoulderY - 0.02)
            ..lineTo(b.cx + s * 0.2, b.shoulderY + 0.05)
            ..lineTo(b.cx + s * 0.05, b.shoulderY + 0.2)
            ..close();
          soft(p, shade(c.cloth, 0.15), line: clothLine);
        }
      }
    case DemoOutfit.calcio:
      soft(torso, c.cloth, line: clothLine, lift: 0.2);
      canvas.save();
      canvas.clipPath(torso);
      for (var x = 0.5 - 0.06 - 0.24; x < 1; x += 0.12) {
        canvas.drawRect(Rect.fromLTWH(x, 0, 0.06, 1.1), fill(c.shirt));
      }
      canvas.drawRect(
        Rect.fromLTRB(0, b.shoulderY - 0.05, 1, 1.05),
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0x22FFFFFF), Color(0x00000000), Color(0x66000000)],
          ).createShader(Rect.fromLTRB(0, b.shoulderY - 0.05, 1, 1.05)),
      );
      canvas.restore();
      canvas.drawPath(torso, stroke(clothLine, lw));
      final collar = b.vee(depth: 0.09, width: 0.55);
      canvas.drawPath(collar, fill(shade(c.skin, 0.12)));
      canvas.drawPath(collar, stroke(c.accent, max(0.014, 1.4 / 256)));
      final badge = Path()
        ..moveTo(b.cx + 0.13, b.shoulderY + 0.07)
        ..lineTo(b.cx + 0.19, b.shoulderY + 0.07)
        ..lineTo(b.cx + 0.19, b.shoulderY + 0.11)
        ..quadraticBezierTo(b.cx + 0.19, b.shoulderY + 0.14, b.cx + 0.16, b.shoulderY + 0.15)
        ..quadraticBezierTo(b.cx + 0.13, b.shoulderY + 0.14, b.cx + 0.13, b.shoulderY + 0.11)
        ..close();
      canvas.drawPath(badge, fill(c.accent));
      canvas.drawPath(badge, stroke(const Color(0xFFD9B45A), lw));
  }
}

void _features(Canvas canvas, DemoChar c, Build b, double lw, bool small) {
  final brow = shade(c.hair, 0.05);
  final skinLine = shade(c.skin, 0.62);
  for (final s in [-1.0, 1.0]) {
    final e = Offset(b.cx + s * b.eyeDx, b.eyeY);
    final ew = b.w * (small ? 0.19 : 0.2);
    final eh = ew * (c.woman ? 0.56 : 0.48);
    final almond = Path()
      ..moveTo(e.dx - ew / 2, e.dy + eh * 0.05)
      ..quadraticBezierTo(e.dx - ew * 0.1, e.dy - eh * 1.15, e.dx + ew / 2, e.dy - eh * 0.1)
      ..quadraticBezierTo(e.dx + ew * 0.05, e.dy + eh * 0.95, e.dx - ew / 2, e.dy + eh * 0.05)
      ..close();
    final upper = Path()
      ..moveTo(e.dx - ew / 2, e.dy + eh * 0.05)
      ..quadraticBezierTo(e.dx - ew * 0.1, e.dy - eh * 1.15, e.dx + ew / 2, e.dy - eh * 0.1);
    if (small) {
      canvas.drawPath(almond, fill(const Color(0xFF140C08)));
      canvas.drawCircle(Offset(e.dx - ew * 0.12, e.dy - eh * 0.18), ew * 0.12, fill(const Color(0xCCFFF6E8)));
    } else {
      canvas.drawPath(almond, fill(const Color(0xFFF3EADC)));
      canvas.save();
      canvas.clipPath(almond);
      final iris = Offset(e.dx + s * ew * 0.04, e.dy + eh * 0.02);
      canvas.drawCircle(iris, eh * 0.66, fill(c.eye));
      canvas.drawCircle(iris, eh * 0.66, stroke(shade(c.eye, 0.6), lw * 0.7));
      canvas.drawCircle(iris, eh * 0.3, fill(const Color(0xFF0B0706)));
      canvas.drawCircle(iris.translate(-eh * 0.22, -eh * 0.24), eh * 0.15, fill(const Color(0xFFFFFFFF)));
      // The lid shadow on the white.
      canvas.drawRect(Rect.fromLTRB(e.dx - ew, e.dy - eh, e.dx + ew, e.dy - eh * 0.35), fill(shade(c.skin, 0.4).withValues(alpha: 0.35)));
      canvas.restore();
      // The crease above.
      final crease = Path()
        ..moveTo(e.dx - ew * 0.4, e.dy - eh * 0.8)
        ..quadraticBezierTo(e.dx, e.dy - eh * 1.35, e.dx + ew * 0.45, e.dy - eh * 0.75);
      canvas.drawPath(crease, stroke(skinLine.withValues(alpha: 0.5), lw * 0.7));
    }
    canvas.drawPath(upper, stroke(const Color(0xFF120A08), lw * (c.woman ? 2.0 : 1.5)));
    if (c.woman) {
      final outer = Offset(e.dx + s * ew / 2, e.dy - eh * (s > 0 ? 0.1 : -0.05));
      final wing = s > 0 ? Offset(outer.dx + ew * 0.16, outer.dy - eh * 0.45) : Offset(e.dx - ew / 2 - ew * 0.16, e.dy - eh * 0.4);
      canvas.drawLine(s > 0 ? outer : Offset(e.dx - ew / 2, e.dy + eh * 0.05), wing, stroke(const Color(0xFF120A08), lw * 1.6));
    }
    // Brows: a tapered stroke, low and angled for the men, arched for women.
    final bw = b.w * 0.24;
    final inner = Offset(b.cx + s * b.w * 0.08, b.browY + (c.woman ? 0.0 : b.h * 0.025));
    final outer = Offset(b.cx + s * (b.w * 0.08 + bw), b.browY + (c.woman ? b.h * 0.01 : -b.h * 0.005));
    final peak = Offset(b.cx + s * (b.w * 0.08 + bw * 0.62), b.browY - b.h * (c.woman ? 0.045 : 0.025));
    final thick = (c.woman ? b.h * 0.022 : b.h * 0.038) * (small ? 0.8 : 1);
    final browPath = Path()
      ..moveTo(inner.dx, inner.dy + thick * 0.5)
      ..quadraticBezierTo(peak.dx, peak.dy - thick * 0.2, outer.dx, outer.dy)
      ..quadraticBezierTo(peak.dx, peak.dy - thick * 1.3, inner.dx, inner.dy - thick * 0.6)
      ..close();
    canvas.drawPath(browPath, fill(brow));
    if (small) canvas.drawPath(browPath, stroke(brow, 0.6 / 64));
  }
  // The nose: a lit ridge, a shadow on the far side and the nostrils.
  final nose = Path()
    ..moveTo(b.cx + b.w * 0.03, b.eyeY + b.h * 0.03)
    ..quadraticBezierTo(b.cx + b.w * 0.07, b.noseY - b.h * 0.04, b.cx + b.w * 0.065, b.noseY);
  canvas.drawPath(nose, stroke(skinLine.withValues(alpha: 0.75), lw));
  final base = Path()
    ..moveTo(b.cx - b.w * 0.07, b.noseY - b.h * 0.005)
    ..quadraticBezierTo(b.cx - b.w * 0.04, b.noseY + b.h * 0.03, b.cx, b.noseY + b.h * 0.025)
    ..quadraticBezierTo(b.cx + b.w * 0.04, b.noseY + b.h * 0.03, b.cx + b.w * 0.07, b.noseY - b.h * 0.005);
  canvas.drawPath(base, stroke(skinLine, lw));
  if (!small) canvas.drawCircle(Offset(b.cx - b.w * 0.015, b.noseY - b.h * 0.01), b.w * 0.022, fill(tint(c.skin, 0.35).withValues(alpha: 0.7)));

  // The mouth.
  final my = b.mouthY;
  if (c.lips != null) {
    final mw = b.w * 0.15;
    final upper = Path()
      ..moveTo(b.cx - mw, my)
      ..quadraticBezierTo(b.cx - mw * 0.5, my - b.h * 0.035, b.cx - mw * 0.15, my - b.h * 0.03)
      ..lineTo(b.cx, my - b.h * 0.018)
      ..lineTo(b.cx + mw * 0.15, my - b.h * 0.03)
      ..quadraticBezierTo(b.cx + mw * 0.5, my - b.h * 0.035, b.cx + mw, my)
      ..quadraticBezierTo(b.cx, my + b.h * 0.005, b.cx - mw, my)
      ..close();
    final lower = Path()
      ..moveTo(b.cx - mw, my)
      ..quadraticBezierTo(b.cx, my + b.h * 0.01, b.cx + mw, my)
      ..quadraticBezierTo(b.cx + mw * 0.6, my + b.h * 0.05, b.cx, my + b.h * 0.05)
      ..quadraticBezierTo(b.cx - mw * 0.6, my + b.h * 0.05, b.cx - mw, my)
      ..close();
    canvas.drawPath(upper, fill(shade(c.lips!, 0.15)));
    canvas.drawPath(lower, fill(c.lips!));
    if (!small) canvas.drawCircle(Offset(b.cx - mw * 0.25, my + b.h * 0.025), b.w * 0.018, fill(const Color(0x66FFFFFF)));
    canvas.drawLine(Offset(b.cx - mw, my), Offset(b.cx + mw, my), stroke(shade(c.lips!, 0.6), lw * 0.8));
  } else {
    final mw = b.w * 0.14;
    final m = Path()
      ..moveTo(b.cx - mw, my - b.h * 0.004)
      ..quadraticBezierTo(b.cx, my + b.h * 0.012, b.cx + mw, my - b.h * 0.012);
    canvas.drawPath(m, stroke(shade(c.skin, 0.7), lw * 1.3));
    if (!small) {
      final lip = Path()
        ..moveTo(b.cx - mw * 0.5, my + b.h * 0.035)
        ..quadraticBezierTo(b.cx, my + b.h * 0.05, b.cx + mw * 0.5, my + b.h * 0.035);
      canvas.drawPath(lip, stroke(shade(c.skin, 0.4).withValues(alpha: 0.6), lw));
    }
  }
  if (c.freckles) {
    final rnd = Random(7);
    for (var i = 0; i < (small ? 6 : 16); i++) {
      final s = i.isEven ? -1 : 1;
      final at = Offset(b.cx + s * b.r * (0.25 + rnd.nextDouble() * 0.5), b.noseY - b.h * 0.06 + rnd.nextDouble() * b.h * 0.08);
      canvas.drawCircle(at, small ? 0.006 : 0.004, fill(const Color(0xFFB0643A).withValues(alpha: 0.7)));
    }
  }
}
