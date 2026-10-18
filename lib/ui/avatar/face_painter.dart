part of 'look_painter.dart';

/// La testa: la forma, la pelle sotto la lampada, gli occhi, il naso, la
/// bocca e i capelli. Nelle stesse coordinate del busto di [LookPainter]:
/// la testa al centro in (0, -0.86), larga 0.32, gli occhi a -0.875.
abstract final class _Face {
  static Color _dark(Color c, double t) => LookPainter._dark(c, t);
  static Color _bright(Color c, double t) => LookPainter._bright(c, t);
  static const _ink = LookPainter.ink;

  static Paint _fill(Color c) => Paint()..color = c;

  static Paint _line(Color c, double width) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  // --- La forma -------------------------------------------------------------

  /// La sommità, la fronte, gli zigomi, l'angolo della mascella e il mento.
  static ({double top, double fw, double cw, double jw, double jy, double chin, double cr}) geometry(FaceShape shape) =>
      switch (shape) {
        FaceShape.oval => (top: -1.06, fw: 0.152, cw: 0.158, jw: 0.118, jy: -0.726, chin: -0.655, cr: 0.055),
        FaceShape.round => (top: -1.055, fw: 0.158, cw: 0.17, jw: 0.142, jy: -0.738, chin: -0.668, cr: 0.095),
        FaceShape.square => (top: -1.06, fw: 0.16, cw: 0.162, jw: 0.152, jy: -0.712, chin: -0.66, cr: 0.088),
        FaceShape.long => (top: -1.075, fw: 0.145, cw: 0.148, jw: 0.112, jy: -0.705, chin: -0.633, cr: 0.05),
        FaceShape.heart => (top: -1.06, fw: 0.166, cw: 0.165, jw: 0.1, jy: -0.732, chin: -0.652, cr: 0.026),
      };

  static final Map<FaceShape, Path> _paths = {};

  static Path path(FaceShape shape) => _paths[shape] ??= _build(shape);

  static Path _build(FaceShape shape) {
    final g = geometry(shape);
    final jawDrop = g.jy + (g.chin - g.jy) * 0.8;
    return Path()
      ..moveTo(0, g.top)
      ..cubicTo(0.6 * g.fw, g.top, g.fw, g.top + 0.05, g.fw, -0.93)
      ..cubicTo(g.fw, -0.89, g.cw, -0.87, g.cw, -0.83)
      ..cubicTo(g.cw, -0.785, g.jw + 0.012, g.jy - 0.02, g.jw, g.jy)
      ..cubicTo(g.jw - 0.006, jawDrop, g.cr, g.chin, 0, g.chin)
      ..cubicTo(-g.cr, g.chin, -(g.jw - 0.006), jawDrop, -g.jw, g.jy)
      ..cubicTo(-(g.jw + 0.012), g.jy - 0.02, -g.cw, -0.785, -g.cw, -0.83)
      ..cubicTo(-g.cw, -0.87, -g.fw, -0.89, -g.fw, -0.93)
      ..cubicTo(-g.fw, g.top + 0.05, -0.6 * g.fw, g.top, 0, g.top)
      ..close();
  }

  // --- Il collo -------------------------------------------------------------

  static void neck(Canvas canvas, Color skin, Offset light) {
    final neck = Path()
      ..moveTo(-0.068, -0.76)
      ..lineTo(0.068, -0.76)
      ..quadraticBezierTo(0.07, -0.64, 0.088, -0.58)
      ..lineTo(-0.088, -0.58)
      ..quadraticBezierTo(-0.07, -0.64, -0.068, -0.76)
      ..close();
    const bounds = Rect.fromLTRB(-0.09, -0.76, 0.09, -0.58);
    canvas.drawPath(
      neck,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment(light.dx.sign, 0),
          end: Alignment(-light.dx.sign, 0),
          colors: [_dark(skin, 0.3), _dark(skin, 0.5), _dark(skin, 0.72)],
        ).createShader(bounds),
    );
    // L'ombra che la mascella getta sul collo.
    canvas.drawPath(
      neck,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_ink.withValues(alpha: 0.55), _ink.withValues(alpha: 0)],
        ).createShader(const Rect.fromLTRB(-0.09, -0.72, 0.09, -0.64)),
    );
  }

  // --- Orecchie e pelle -------------------------------------------------------

  static void ears(Canvas canvas, AvatarLook look, Color skin, Offset light) {
    final g = geometry(look.features.shape);
    for (final side in [-1.0, 1.0]) {
      final lit = side.sign == light.dx.sign;
      final center = Offset(side * (g.cw + 0.004), -0.85);
      final ear = Rect.fromCenter(center: center, width: 0.05, height: 0.09);
      canvas.drawOval(ear, _fill(_dark(skin, lit ? 0.18 : 0.5)));
      canvas.drawArc(
        ear.deflate(0.012).shift(Offset(side * 0.003, 0)),
        side < 0 ? pi * 0.6 : -pi * 0.4,
        pi * 0.9,
        false,
        _line(_dark(skin, lit ? 0.5 : 0.75), 0.007),
      );
    }
  }

  static void skin(Canvas canvas, AvatarLook look, Path face, Color skin, Offset light) {
    final g = geometry(look.features.shape);
    final bounds = Rect.fromLTRB(-g.cw, g.top, g.cw, g.chin);
    final lx = light.dx.clamp(-1.0, 1.0);
    canvas.drawPath(
      face,
      Paint()
        ..shader = RadialGradient(
          center: Alignment(lx * 0.5, -0.3),
          radius: 0.95,
          colors: [_bright(skin, 0.14), skin, _dark(skin, 0.28), _dark(skin, 0.58)],
          stops: const [0, 0.42, 0.78, 1],
        ).createShader(bounds),
    );
    canvas.save();
    canvas.clipPath(face);
    // Il lato lontano dalla lampada affonda nel buio.
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment(lx.sign, 0),
          end: Alignment(-lx.sign, 0),
          colors: [Colors.transparent, Colors.transparent, _ink.withValues(alpha: 0.38)],
          stops: const [0, 0.5, 1],
        ).createShader(bounds),
    );
    // Gli zigomi: la luce sopra, l'incavo sotto.
    for (final side in [-1.0, 1.0]) {
      final lit = side.sign == lx.sign;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(side * (g.cw - 0.045), -0.835), width: 0.06, height: 0.03),
        _fill(_bright(skin, 0.4).withValues(alpha: lit ? 0.32 : 0.08)),
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(side * (g.jw - 0.01), -0.775), width: 0.06, height: 0.05),
        _fill(_ink.withValues(alpha: lit ? 0.07 : 0.16)),
      );
      // Un filo di colore sulle guance.
      canvas.drawOval(
        Rect.fromCenter(center: Offset(side * 0.085, -0.805), width: 0.055, height: 0.03),
        _fill(const Color(0xFFC0504A).withValues(alpha: 0.09)),
      );
    }
    // La fronte prende la luce; sotto il mento, l'ombra.
    canvas.drawOval(
      Rect.fromCenter(center: Offset(lx * 0.035, -0.985), width: 0.15, height: 0.065),
      _fill(_bright(skin, 0.5).withValues(alpha: 0.2)),
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(0, g.chin + 0.004), width: g.cr * 2 + 0.06, height: 0.03),
      _fill(_ink.withValues(alpha: 0.16)),
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(-lx * 0.01, g.chin + 0.022), width: 0.05, height: 0.018),
      _fill(_bright(skin, 0.35).withValues(alpha: 0.22)),
    );
    canvas.restore();
    // Il contorno, perché la testa si legga anche nella moneta piccola.
    canvas.drawPath(face, _line(_dark(skin, 0.8).withValues(alpha: 0.5), 0.006));
  }

  // --- Rughe e segni ----------------------------------------------------------

  static void age(Canvas canvas, AvatarLook look, Color skin) {
    final age = look.features.age;
    if (age == FaceAge.none) return;
    final deep = age == FaceAge.deep;
    final line = _line(_dark(skin, 0.55).withValues(alpha: deep ? 0.6 : 0.42), deep ? 0.006 : 0.005);
    for (final side in [-1.0, 1.0]) {
      // Dal naso agli angoli della bocca.
      canvas.drawPath(
        Path()
          ..moveTo(side * 0.034, -0.81)
          ..quadraticBezierTo(side * 0.058, -0.79, side * 0.052, -0.752),
        line,
      );
      if (deep) {
        // Le zampe di gallina e le borse sotto gli occhi.
        for (final dy in [-0.006, 0.006]) {
          canvas.drawLine(Offset(side * 0.103, -0.875 + dy), Offset(side * 0.122, -0.875 + dy * 2.2), line);
        }
        canvas.drawArc(
          Rect.fromCenter(center: Offset(side * 0.065, -0.855), width: 0.05, height: 0.02),
          0.15 * pi,
          0.7 * pi,
          false,
          line,
        );
        canvas.drawLine(Offset(side * 0.06, -0.73), Offset(side * 0.07, -0.7), line);
      }
    }
    for (final y in deep ? const [-0.985, -0.962] : const [-0.975]) {
      canvas.drawPath(
        Path()
          ..moveTo(-0.07, y)
          ..quadraticBezierTo(0, y - 0.008, 0.07, y),
        line,
      );
    }
  }

  static void detail(Canvas canvas, AvatarLook look, Color skin) {
    switch (look.features.detail) {
      case FaceDetail.none:
        break;
      case FaceDetail.freckles:
        final dot = _fill(Color.lerp(_dark(skin, 0.35), const Color(0xFF8A4A2A), 0.4)!.withValues(alpha: 0.75));
        const spots = [
          Offset(-0.1, -0.83), Offset(-0.085, -0.815), Offset(-0.07, -0.828), Offset(-0.105, -0.808), //
          Offset(-0.06, -0.81), Offset(0.1, -0.83), Offset(0.085, -0.815), Offset(0.07, -0.828),
          Offset(0.105, -0.808), Offset(0.06, -0.81), Offset(-0.012, -0.835), Offset(0.014, -0.83),
        ];
        for (final spot in spots) {
          canvas.drawCircle(spot, 0.0048, dot);
        }
      case FaceDetail.beautyMark:
        canvas.drawCircle(const Offset(-0.056, -0.783), 0.0075, _fill(const Color(0xFF241510)));
      case FaceDetail.scar:
        // Un taglio che attraversa il sopracciglio sinistro.
        canvas.drawLine(
          const Offset(-0.098, -0.94),
          const Offset(-0.078, -0.89),
          _line(_bright(skin, 0.45).withValues(alpha: 0.9), 0.009),
        );
        canvas.drawLine(const Offset(-0.072, -0.875), const Offset(-0.066, -0.855), _line(_bright(skin, 0.45).withValues(alpha: 0.7), 0.007));
    }
  }

  // --- Occhi, sopracciglia, naso, bocca -----------------------------------------

  static void eyes(Canvas canvas, AvatarLook look, CharacterPose pose, Color skin) {
    final f = look.features;
    final glance = pose.glance.clamp(-1.0, 1.0);
    final (w, h, tilt) = switch (f.eyes) {
      EyeShape.almond => (0.062, 0.026, 0.003),
      EyeShape.round => (0.056, 0.034, 0.0),
      EyeShape.hooded => (0.06, 0.022, 0.0),
      EyeShape.narrow => (0.064, 0.016, 0.002),
      EyeShape.upturned => (0.06, 0.024, 0.01),
      EyeShape.downturned => (0.06, 0.024, -0.008),
    };
    for (final side in [-1.0, 1.0]) {
      final c = Offset(side * 0.065, -0.875);
      // L'incavo dell'occhio, in ombra sotto la fronte.
      canvas.drawOval(
        Rect.fromCenter(center: c.translate(0, -0.006), width: w * 1.55, height: h + 0.03),
        _fill(_dark(skin, 0.55).withValues(alpha: 0.22)),
      );
      if (look.glasses.dark) continue;
      final inner = Offset(c.dx - side * w / 2, c.dy + 0.002);
      final outer = Offset(c.dx + side * w / 2, c.dy - tilt);
      final lift = f.eyes == EyeShape.hooded ? 0.65 : 0.95;
      final upper = Path()
        ..moveTo(inner.dx, inner.dy)
        ..cubicTo(inner.dx + side * w * 0.25, c.dy - h * lift, outer.dx - side * w * 0.22, c.dy - h * lift - tilt * 0.6,
            outer.dx, outer.dy);
      final eye = Path.from(upper)
        ..cubicTo(outer.dx - side * w * 0.2, c.dy + h * 0.72 - tilt * 0.3, inner.dx + side * w * 0.3, c.dy + h * 0.7,
            inner.dx, inner.dy)
        ..close();
      canvas.drawPath(eye, _fill(LookPainter.paper.withValues(alpha: 0.9)));
      canvas.save();
      canvas.clipPath(eye);
      final iris = c.translate(glance * 0.012, 0.0);
      final r = max(h * 0.52, 0.0118);
      canvas.drawCircle(iris, r, _fill(f.eyeColor.color));
      canvas.drawCircle(iris, r, _line(_dark(f.eyeColor.color, 0.5), 0.004));
      canvas.drawCircle(iris, r * 0.48, _fill(_ink));
      canvas.drawCircle(iris.translate(-0.004, -0.004), r * 0.28, _fill(Colors.white.withValues(alpha: 0.85)));
      // La palpebra getta un filo d'ombra sull'occhio.
      canvas.drawPath(upper, _line(_ink.withValues(alpha: 0.35), 0.012));
      canvas.restore();
      canvas.drawPath(upper, _line(_ink.withValues(alpha: 0.9), look.dame ? 0.0095 : 0.0075));
      if (look.dame) {
        canvas.drawLine(outer, outer.translate(side * 0.012, -0.008), _line(_ink, 0.006));
      }
      // La piega della palpebra.
      canvas.drawPath(
        Path()
          ..moveTo(inner.dx + side * w * 0.15, c.dy - h * 0.9)
          ..quadraticBezierTo(c.dx, c.dy - h - (f.eyes == EyeShape.hooded ? 0.004 : 0.012), outer.dx - side * w * 0.05,
              outer.dy - h * 0.75),
        _line(_dark(skin, 0.6).withValues(alpha: f.eyes == EyeShape.hooded ? 0.75 : 0.35), 0.005),
      );
    }
  }

  static void brows(Canvas canvas, AvatarLook look) {
    final f = look.features;
    final hair = f.hairColor.color;
    final color = f.hairColor == HairColor.white || f.hairColor == HairColor.grey ? _dark(hair, 0.2) : _dark(hair, 0.3);
    final (lift, width) = switch (f.brows) {
      BrowShape.straight => (0.006, 0.017),
      BrowShape.arched => (0.026, 0.014),
      BrowShape.thick => (0.01, 0.025),
      BrowShape.thin => (0.02, 0.008),
      BrowShape.angled => (0.0, 0.016),
    };
    for (final side in [-1.0, 1.0]) {
      final inner = Offset(side * 0.03, -0.907);
      final outer = Offset(side * 0.103, f.brows == BrowShape.arched ? -0.9 : -0.905);
      final path = Path()..moveTo(inner.dx, inner.dy);
      if (f.brows == BrowShape.angled) {
        path
          ..lineTo(side * 0.076, -0.928)
          ..lineTo(outer.dx, outer.dy + 0.004);
      } else {
        path.quadraticBezierTo(side * 0.07, -0.91 - lift, outer.dx, outer.dy);
      }
      canvas.drawPath(path, _line(color, width));
    }
  }

  static void nose(Canvas canvas, AvatarLook look, Color skin, Offset light) {
    final sx = light.dx <= 0 ? 1.0 : -1.0; // il lato in ombra
    final (base, w) = switch (look.features.nose) {
      NoseShape.straight => (-0.8, 0.044),
      NoseShape.button => (-0.808, 0.04),
      NoseShape.roman => (-0.794, 0.046),
      NoseShape.broad => (-0.802, 0.062),
      NoseShape.pointed => (-0.79, 0.036),
    };
    final shade = Path()..moveTo(sx * 0.012, -0.872);
    if (look.features.nose == NoseShape.roman) {
      shade.quadraticBezierTo(sx * 0.032, -0.845, sx * w * 0.38, base - 0.012);
    } else {
      shade.quadraticBezierTo(sx * 0.016, -0.84, sx * w * 0.38, base - 0.012);
    }
    canvas.drawPath(shade, _line(_dark(skin, 0.5).withValues(alpha: 0.7), 0.012));
    // Sotto la punta, l'ombra e le narici.
    canvas.drawOval(Rect.fromCenter(center: Offset(sx * 0.004, base + 0.007), width: w * 0.85, height: 0.016), _fill(_dark(skin, 0.5).withValues(alpha: 0.55)));
    for (final side in [-1.0, 1.0]) {
      canvas.drawOval(Rect.fromCenter(center: Offset(side * w * 0.28, base + 0.004), width: 0.013, height: 0.007), _fill(_dark(skin, 0.75)));
      if (look.features.nose == NoseShape.broad) {
        canvas.drawArc(
          Rect.fromCenter(center: Offset(side * w * 0.38, base), width: 0.024, height: 0.022),
          side < 0 ? pi * 0.5 : -pi * 0.5,
          pi,
          false,
          _line(_dark(skin, 0.6).withValues(alpha: 0.6), 0.005),
        );
      }
    }
    // La luce sul dorso e sulla punta.
    canvas.drawLine(Offset(-sx * 0.004, -0.865), Offset(-sx * 0.006, base - 0.02), _line(_bright(skin, 0.3).withValues(alpha: 0.4), 0.007));
    canvas.drawCircle(
      Offset(-sx * 0.005, base - 0.01),
      look.features.nose == NoseShape.button ? 0.011 : 0.008,
      _fill(_bright(skin, 0.35).withValues(alpha: 0.6)),
    );
  }

  static void mouth(Canvas canvas, AvatarLook look, Color skin) {
    final lip = Color.lerp(_dark(skin, 0.3), const Color(0xFF9A3B3B), 0.35)!;
    final ink = _dark(skin, 0.78);
    const y = -0.762;
    // L'ombra sotto il labbro inferiore.
    canvas.drawOval(Rect.fromCenter(center: const Offset(0, y + 0.017), width: 0.042, height: 0.011), _fill(_ink.withValues(alpha: 0.2)));
    switch (look.features.mouth) {
      case MouthShape.neutral:
        canvas.drawOval(Rect.fromCenter(center: const Offset(0, y + 0.007), width: 0.05, height: 0.012), _fill(lip.withValues(alpha: 0.7)));
        canvas.drawPath(Path()..moveTo(-0.036, y)..quadraticBezierTo(0, y - 0.004, 0.036, y), _line(ink, 0.011));
      case MouthShape.smile:
        canvas.drawOval(Rect.fromCenter(center: const Offset(0, y + 0.009), width: 0.05, height: 0.012), _fill(lip.withValues(alpha: 0.7)));
        canvas.drawPath(Path()..moveTo(-0.042, y - 0.008)..quadraticBezierTo(0, y + 0.014, 0.042, y - 0.008), _line(ink, 0.011));
        for (final side in [-1.0, 1.0]) {
          canvas.drawLine(Offset(side * 0.046, y - 0.014), Offset(side * 0.05, y - 0.003), _line(_dark(skin, 0.55).withValues(alpha: 0.6), 0.005));
        }
      case MouthShape.smirk:
        canvas.drawOval(Rect.fromCenter(center: const Offset(0.004, y + 0.007), width: 0.048, height: 0.011), _fill(lip.withValues(alpha: 0.7)));
        canvas.drawPath(Path()..moveTo(-0.034, y + 0.001)..quadraticBezierTo(0.008, y + 0.002, 0.042, y - 0.012), _line(ink, 0.011));
        canvas.drawLine(const Offset(0.047, y - 0.017), const Offset(0.049, y - 0.006), _line(_dark(skin, 0.55).withValues(alpha: 0.6), 0.005));
      case MouthShape.full:
        canvas.drawPath(
          Path()
            ..moveTo(-0.042, y)
            ..quadraticBezierTo(-0.02, y - 0.016, 0, y - 0.01)
            ..quadraticBezierTo(0.02, y - 0.016, 0.042, y)
            ..quadraticBezierTo(0.02, y + 0.024, 0, y + 0.022)
            ..quadraticBezierTo(-0.02, y + 0.024, -0.042, y)
            ..close(),
          _fill(lip),
        );
        canvas.drawPath(Path()..moveTo(-0.04, y)..quadraticBezierTo(0, y + 0.002, 0.04, y), _line(ink, 0.008));
        canvas.drawOval(Rect.fromCenter(center: const Offset(-0.008, y + 0.012), width: 0.022, height: 0.006), _fill(Colors.white.withValues(alpha: 0.25)));
      case MouthShape.thin:
        canvas.drawLine(const Offset(-0.03, y), const Offset(0.03, y), _line(ink, 0.008));
      case MouthShape.stern:
        canvas.drawOval(Rect.fromCenter(center: const Offset(0, y + 0.006), width: 0.046, height: 0.01), _fill(lip.withValues(alpha: 0.6)));
        canvas.drawPath(Path()..moveTo(-0.038, y + 0.005)..quadraticBezierTo(0, y - 0.008, 0.038, y + 0.005), _line(ink, 0.011));
    }
  }

  // --- I capelli --------------------------------------------------------------

  /// Le teste che coprono tutto: niente capelli.
  static const _covered = {
    AvatarHead.clownWig,
    AvatarHead.roosterHead,
    AvatarHead.fishHead,
    AvatarHead.dinoHood,
    AvatarHead.octopusHat,
    AvatarHead.rainbowAfro,
    AvatarHead.flamingHair,
  };

  /// Quello che si posa sopra i capelli pettinati: l'aureola, le corna.
  static const _onTop = {
    AvatarHead.angelHalo,
    AvatarHead.devilHorns,
    AvatarHead.astronautHelmet,
    AvatarHead.unicornHorn,
    AvatarHead.spaghettiHat,
    AvatarHead.ufoHat,
    AvatarHead.birthdayCake,
    AvatarHead.starHalo,
    AvatarHead.catOnHead,
  };

  static bool _full(AvatarLook look) => look.bareHead || _onTop.contains(look.hat);

  static Paint _hairPaint(Color c) => Paint()
    ..shader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [_bright(c, 0.16), c, _dark(c, 0.4)],
      stops: const [0, 0.4, 1],
    ).createShader(const Rect.fromLTRB(-0.25, -1.15, 0.25, -0.7));

  static void hairBack(Canvas canvas, AvatarLook look, Paint? halo) {
    if (_covered.contains(look.hat)) return;
    final c = look.features.hairColor.color;
    final paint = halo ?? _fill(_dark(c, 0.3));
    final style = look.features.hair;
    if (_full(look)) {
      switch (style) {
        case HairStyle.bob:
          canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(-0.215, -1.08, 0.215, -0.69), const Radius.circular(0.15)), paint);
        case HairStyle.long:
          canvas.drawPath(_longBack(), paint);
        case HairStyle.wavy:
          canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(-0.2, -1.08, 0.2, -0.77), const Radius.circular(0.13)), paint);
          for (final x in const [-0.17, -0.11, 0.11, 0.17]) {
            canvas.drawCircle(Offset(x, -0.772), 0.034, paint);
          }
        case HairStyle.curly:
          for (var a = 0.85; a <= 2.15; a += 0.1625) {
            canvas.drawCircle(Offset(cos(a * pi) * 0.175, -0.9 - sin(a * pi) * 0.17), 0.05, paint);
          }
        case HairStyle.afro:
          canvas.drawCircle(const Offset(0, -0.95), 0.245, paint);
        case HairStyle.bun:
          canvas.drawCircle(const Offset(0, -1.1), 0.075, paint);
        case HairStyle.bald || HairStyle.slicked || HairStyle.sidePart || HairStyle.crewCut:
          break;
      }
      return;
    }
    // Sotto un cappello si vede solo quello che scende.
    switch (style) {
      case HairStyle.bob:
        canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(-0.215, -0.97, 0.215, -0.69), const Radius.circular(0.12)), paint);
      case HairStyle.long:
        canvas.drawPath(_longBack(), paint);
      case HairStyle.wavy || HairStyle.curly:
        canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(-0.2, -0.97, 0.2, -0.77), const Radius.circular(0.1)), paint);
      case HairStyle.afro:
        for (final side in [-1.0, 1.0]) {
          canvas.drawCircle(Offset(side * 0.19, -0.88), 0.07, paint);
        }
      case HairStyle.bald || HairStyle.slicked || HairStyle.sidePart || HairStyle.crewCut || HairStyle.bun:
        break;
    }
  }

  static Path _longBack() => Path()
    ..moveTo(-0.2, -0.95)
    ..quadraticBezierTo(-0.22, -1.1, 0, -1.09)
    ..quadraticBezierTo(0.22, -1.1, 0.2, -0.95)
    ..lineTo(0.215, -0.6)
    ..quadraticBezierTo(0.15, -0.56, 0.1, -0.6)
    ..lineTo(-0.1, -0.6)
    ..quadraticBezierTo(-0.15, -0.56, -0.215, -0.6)
    ..close();

  static void hairFront(Canvas canvas, AvatarLook look) {
    if (_covered.contains(look.hat)) return;
    final c = look.features.hairColor.color;
    final hair = _hairPaint(c);
    final shine = _line(_bright(c, 0.5).withValues(alpha: 0.4), 0.013);
    final style = look.features.hair;
    if (!_full(look)) {
      // Le basette sotto il cappello, e le ciocche di chi le porta lunghe.
      if (style == HairStyle.bald) return;
      if (style.falls && style != HairStyle.afro) {
        for (final side in [-1.0, 1.0]) {
          canvas.drawPath(
            Path()
              ..moveTo(side * 0.13, -0.97)
              ..quadraticBezierTo(side * 0.2, -0.95, side * 0.205, -0.74)
              ..lineTo(side * 0.165, -0.76)
              ..quadraticBezierTo(side * 0.16, -0.88, side * 0.12, -0.95)
              ..close(),
            hair,
          );
        }
      } else {
        canvas.drawRect(const Rect.fromLTRB(-0.165, -0.95, -0.14, -0.86), hair);
        canvas.drawRect(const Rect.fromLTRB(0.14, -0.95, 0.165, -0.86), hair);
      }
      return;
    }
    switch (style) {
      case HairStyle.bald:
        for (final side in [-1.0, 1.0]) {
          canvas.drawOval(Rect.fromCenter(center: Offset(side * 0.156, -0.885), width: 0.03, height: 0.075), hair);
        }
        canvas.drawArc(
          Rect.fromCenter(center: const Offset(-0.02, -1.0), width: 0.18, height: 0.1),
          pi * 1.15,
          pi * 0.45,
          false,
          _line(Colors.white.withValues(alpha: 0.22), 0.016),
        );
      case HairStyle.slicked:
        canvas.drawPath(
          Path()
            ..moveTo(-0.168, -0.86)
            ..quadraticBezierTo(-0.18, -1.1, 0.02, -1.095)
            ..quadraticBezierTo(0.19, -1.09, 0.168, -0.86)
            ..quadraticBezierTo(0.15, -0.97, 0.05, -0.985)
            ..quadraticBezierTo(-0.1, -1.0, -0.168, -0.86)
            ..close(),
          hair,
        );
        canvas.drawArc(Rect.fromCenter(center: const Offset(0.0, -0.99), width: 0.22, height: 0.12), pi * 1.1, pi * 0.55, false, shine);
      case HairStyle.sidePart:
        canvas.drawPath(
          Path()
            ..moveTo(-0.168, -0.86)
            ..quadraticBezierTo(-0.185, -1.1, 0.01, -1.1)
            ..quadraticBezierTo(0.195, -1.09, 0.168, -0.86)
            ..quadraticBezierTo(0.16, -0.95, 0.09, -0.97)
            ..quadraticBezierTo(-0.02, -0.985, -0.075, -1.03)
            ..quadraticBezierTo(-0.12, -0.97, -0.168, -0.86)
            ..close(),
          hair,
        );
        canvas.drawLine(const Offset(-0.075, -1.03), const Offset(-0.062, -1.092), _line(_dark(c, 0.5), 0.008));
        canvas.drawArc(Rect.fromCenter(center: const Offset(0.04, -1.0), width: 0.2, height: 0.1), pi * 1.15, pi * 0.5, false, shine);
      case HairStyle.crewCut:
        canvas.drawPath(
          Path()
            ..moveTo(-0.162, -0.9)
            ..quadraticBezierTo(-0.17, -1.085, 0, -1.085)
            ..quadraticBezierTo(0.17, -1.085, 0.162, -0.9)
            ..quadraticBezierTo(0.12, -0.99, 0, -0.995)
            ..quadraticBezierTo(-0.12, -0.99, -0.162, -0.9)
            ..close(),
          hair,
        );
      case HairStyle.curly:
        canvas.drawPath(
          Path()
            ..moveTo(-0.17, -0.88)
            ..quadraticBezierTo(-0.19, -1.11, 0, -1.11)
            ..quadraticBezierTo(0.19, -1.11, 0.17, -0.88)
            ..quadraticBezierTo(0.14, -0.99, 0, -1.0)
            ..quadraticBezierTo(-0.14, -0.99, -0.17, -0.88)
            ..close(),
          hair,
        );
        for (var x = -0.12; x <= 0.121; x += 0.06) {
          canvas.drawCircle(Offset(x, -1.0 + (x.abs() * 0.4)), 0.034, hair);
        }
        for (var x = -0.09; x <= 0.091; x += 0.06) {
          canvas.drawArc(Rect.fromCircle(center: Offset(x, -1.065), radius: 0.025), pi, pi * 0.8, false, shine);
        }
      case HairStyle.wavy:
        canvas.drawPath(
          Path()
            ..moveTo(-0.172, -0.84)
            ..quadraticBezierTo(-0.19, -1.1, 0, -1.1)
            ..quadraticBezierTo(0.19, -1.1, 0.172, -0.84)
            ..quadraticBezierTo(0.15, -0.93, 0.1, -0.95)
            ..quadraticBezierTo(0.06, -0.99, 0.02, -0.97)
            ..quadraticBezierTo(-0.04, -1.0, -0.08, -0.965)
            ..quadraticBezierTo(-0.14, -0.95, -0.172, -0.84)
            ..close(),
          hair,
        );
        canvas.drawArc(Rect.fromCenter(center: const Offset(-0.03, -1.02), width: 0.2, height: 0.1), pi * 1.1, pi * 0.5, false, shine);
      case HairStyle.afro:
        canvas.drawPath(
          Path()
            ..moveTo(-0.17, -0.88)
            ..quadraticBezierTo(-0.2, -1.13, 0, -1.13)
            ..quadraticBezierTo(0.2, -1.13, 0.17, -0.88)
            ..quadraticBezierTo(0.14, -0.99, 0, -0.995)
            ..quadraticBezierTo(-0.14, -0.99, -0.17, -0.88)
            ..close(),
          hair,
        );
        final grain = _fill(_bright(c, 0.3).withValues(alpha: 0.18));
        for (var i = 0; i < 14; i++) {
          final a = i * 2.4;
          canvas.drawCircle(Offset(cos(a) * 0.17 * (0.4 + (i % 4) * 0.2), -0.98 - sin(a).abs() * 0.15), 0.012, grain);
        }
      case HairStyle.bun:
        canvas.drawPath(
          Path()
            ..moveTo(-0.17, -0.86)
            ..quadraticBezierTo(-0.18, -1.09, 0, -1.09)
            ..quadraticBezierTo(0.18, -1.09, 0.17, -0.86)
            ..quadraticBezierTo(0.12, -0.98, 0, -0.99)
            ..quadraticBezierTo(-0.12, -0.98, -0.17, -0.86)
            ..close(),
          hair,
        );
        canvas.drawLine(const Offset(-0.07, -1.14), const Offset(0.09, -1.07), _line(LookPainter.gold, 0.014));
      case HairStyle.bob:
        canvas.drawPath(
          Path()
            ..moveTo(-0.19, -0.8)
            ..quadraticBezierTo(-0.21, -1.085, 0, -1.085)
            ..quadraticBezierTo(0.21, -1.085, 0.19, -0.8)
            ..quadraticBezierTo(0.15, -0.94, 0.04, -0.96)
            ..quadraticBezierTo(-0.06, -0.93, -0.1, -0.97)
            ..quadraticBezierTo(-0.16, -0.92, -0.19, -0.8)
            ..close(),
          hair,
        );
        canvas.drawArc(Rect.fromCenter(center: const Offset(-0.04, -1.0), width: 0.24, height: 0.13), pi * 1.1, pi * 0.5, false, shine);
      case HairStyle.long:
        canvas.drawPath(
          Path()
            ..moveTo(-0.205, -0.72)
            ..quadraticBezierTo(-0.215, -1.09, 0, -1.09)
            ..quadraticBezierTo(0.215, -1.09, 0.205, -0.72)
            ..lineTo(0.165, -0.74)
            ..quadraticBezierTo(0.16, -0.93, 0.008, -0.985)
            ..quadraticBezierTo(-0.16, -0.93, -0.165, -0.74)
            ..close(),
          hair,
        );
        canvas.drawLine(const Offset(0.008, -0.985), const Offset(0.004, -1.085), _line(_dark(c, 0.45), 0.007));
        canvas.drawArc(Rect.fromCenter(center: const Offset(-0.06, -1.0), width: 0.2, height: 0.14), pi * 1.05, pi * 0.45, false, shine);
    }
  }
}
