part of 'look_painter.dart';

/// Il cartoon noir: teste grandi e mascelle squadrate, una sagoma
/// d'inchiostro spessa con linee interne sottili, colori pieni con una sola
/// ombra netta tagliata dalla parte lontana dalla lampada, un filo di luce
/// calda sul bordo acceso, gli occhi persi sotto la tesa.
///
/// Si disegna in un quadrato di lato 1 (il ritratto): la testa, i capelli, i
/// cappelli classici, gli abiti da sera e i lineamenti hanno qui la loro
/// forma; i pezzi più strani della bottega (le maschere, le ali, i costumi)
/// sono quelli di sempre, portati sulla testa e sulle spalle di qui e
/// ripassati con la stessa ombra.

const _nInk = Color(0xFF0B0809);
const _nNight = Color(0xFF1A1236);
const _nLamp = Color(0xFFFFD27A);

Paint _nFill(Color c) => Paint()..color = c;

Paint _nStroke(Color c, double w, {StrokeCap cap = StrokeCap.round}) => Paint()
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = cap
  ..strokeJoin = StrokeJoin.round;

Color _nDark(Color c) => Color.lerp(c, _nNight, 0.55)!;

/// Una forma simmetrica intorno a x = [cx]: [right] sono i tratti cubici
/// (c1, c2, fine) della metà destra, dalla cima giù fino a un punto
/// dell'asse; la metà sinistra è lo specchio.
Path _mirrored(double cx, Offset top, List<List<Offset>> right) {
  final p = Path()..moveTo(top.dx, top.dy);
  for (final s in right) {
    p.cubicTo(s[0].dx, s[0].dy, s[1].dx, s[1].dy, s[2].dx, s[2].dy);
  }
  Offset m(Offset o) => Offset(2 * cx - o.dx, o.dy);
  for (var i = right.length - 1; i >= 0; i--) {
    final s = right[i];
    final start = i == 0 ? top : right[i - 1][2];
    p.cubicTo(m(s[1]).dx, m(s[1]).dy, m(s[0]).dx, m(s[0]).dy, m(start).dx, m(start).dy);
  }
  return p..close();
}

/// Le proporzioni della persona, nel quadrato del ritratto: tutte le forme
/// vengono da questi numeri.
class _NB {
  double get cx => 0.5;
  final double cy;
  final double w;
  final double h;

  /// Quanto resta larga la mascella, in frazioni della testa.
  final double jaw;

  /// Quanto è largo il mento.
  final double chin;
  final double shoulderY;
  final double shoulderW;
  final double neckW;

  /// Fin dove scende il busto (al tavolo, fino al bordo).
  final double base;

  const _NB({
    required this.cy,
    required this.w,
    required this.h,
    required this.jaw,
    required this.chin,
    required this.shoulderY,
    required this.shoulderW,
    required this.neckW,
    this.base = 1.02,
  });

  /// La testa di [look]: la forma scelta allo specchio, più stretta e col
  /// mento fine per le signore.
  factory _NB.of(AvatarLook look, {double base = 1.02}) {
    final (w, h, jaw, chin) = switch (look.features.shape) {
      FaceShape.oval => (0.46, 0.5, 0.82, 0.36),
      FaceShape.round => (0.5, 0.48, 0.92, 0.52),
      FaceShape.square => (0.48, 0.5, 1.0, 0.62),
      FaceShape.long => (0.43, 0.54, 0.84, 0.4),
      FaceShape.heart => (0.47, 0.5, 0.62, 0.16),
      FaceShape.diamond => (0.44, 0.52, 0.7, 0.22),
      FaceShape.pear => (0.45, 0.5, 1.06, 0.62),
      FaceShape.chiselled => (0.47, 0.51, 0.96, 0.5),
    };
    final dame = look.dame;
    return _NB(
      cy: 0.47,
      w: dame ? w * 0.94 : w,
      h: h,
      jaw: dame ? jaw * 0.68 : jaw,
      chin: dame ? chin * 0.36 : chin,
      shoulderY: 0.83,
      shoulderW: dame ? 0.84 : 1.04,
      neckW: dame ? 0.32 : 0.5,
      base: base,
    );
  }

  double get r => w / 2;
  double get top => cy - h / 2;
  double get bottom => cy + h / 2;
  double get eyeY => cy + h * 0.05;
  double get eyeDx => r * 0.43;
  double get browY => eyeY - h * 0.105;
  double get noseY => cy + h * 0.21;
  double get mouthY => cy + h * 0.325;

  /// Dove si posa un cappello: la riga della tesa.
  double get brimY => top + h * 0.2;

  Path face() => _mirrored(cx, Offset(cx, top), [
        [Offset(cx + r * 0.6, top), Offset(cx + r, top + h * 0.17), Offset(cx + r, cy - h * 0.02)],
        [Offset(cx + r, cy + h * 0.15), Offset(cx + r * jaw, cy + h * 0.29), Offset(cx + r * jaw * 0.9, cy + h * 0.35)],
        [Offset(cx + r * jaw * 0.7, cy + h * 0.45), Offset(cx + r * chin, bottom), Offset(cx, bottom)],
      ]);

  Rect ear(int side) => Rect.fromCenter(center: Offset(cx + side * r * 0.97, cy + h * 0.06), width: w * 0.15, height: h * 0.2);

  Path neck() {
    final nw = w * neckW;
    return Path()
      ..moveTo(cx - nw / 2, cy + h * 0.25)
      ..lineTo(cx + nw / 2, cy + h * 0.25)
      ..lineTo(cx + nw / 2 + 0.01, shoulderY + 0.04)
      ..quadraticBezierTo(cx, shoulderY + 0.09, cx - nw / 2 - 0.01, shoulderY + 0.04)
      ..close();
  }

  Path torso() {
    final sw = shoulderW / 2;
    return Path()
      ..moveTo(cx - w * neckW * 0.62, shoulderY - 0.015)
      ..cubicTo(cx - sw * 0.6, shoulderY - 0.01, cx - sw * 0.95, shoulderY + 0.01, cx - sw, shoulderY + 0.09)
      ..lineTo(cx - sw - 0.03, base)
      ..lineTo(cx + sw + 0.03, base)
      ..lineTo(cx + sw, shoulderY + 0.09)
      ..cubicTo(cx + sw * 0.95, shoulderY + 0.01, cx + sw * 0.6, shoulderY - 0.01, cx + w * neckW * 0.62, shoulderY - 0.015)
      ..close();
  }

  Path vee({double depth = 0.17, double width = 0.5}) {
    final nw = w * neckW * width * 1.3;
    return Path()
      ..moveTo(cx - nw, shoulderY - 0.02)
      ..lineTo(cx + nw, shoulderY - 0.02)
      ..lineTo(cx, shoulderY + depth)
      ..close();
  }

  Path scoop() {
    final nw = w * neckW * 0.95;
    return Path()
      ..moveTo(cx - nw, shoulderY - 0.02)
      ..quadraticBezierTo(cx, shoulderY + 0.17, cx + nw, shoulderY - 0.02)
      ..close();
  }

  Path lapel(int side, {bool wide = false}) {
    final nw = w * neckW * 0.65;
    final s = side.toDouble();
    final k = wide ? 1.35 : 1.0;
    return Path()
      ..moveTo(cx + s * nw, shoulderY - 0.02)
      ..lineTo(cx + s * 0.005, shoulderY + 0.17)
      ..lineTo(cx + s * 0.06, shoulderY + 0.24)
      ..lineTo(cx + s * 0.075 * k, shoulderY + 0.09)
      ..lineTo(cx + s * 0.12 * k, shoulderY + 0.06)
      ..lineTo(cx + s * (nw + 0.06 * k), shoulderY + 0.0)
      ..close();
  }

  Path mustache({double scale = 1, double drop = 0, double flat = 1}) => Path()
    ..moveTo(cx, mouthY - h * 0.055 * flat + drop)
    ..cubicTo(cx + w * 0.06 * scale, mouthY - h * 0.085 * flat + drop, cx + w * 0.15 * scale, mouthY - h * 0.07 * flat + drop,
        cx + w * 0.17 * scale, mouthY - h * 0.005 + drop * 1.6)
    ..cubicTo(cx + w * 0.11 * scale, mouthY - h * 0.03 + drop, cx + w * 0.05 * scale, mouthY - h * 0.02 + drop, cx, mouthY - h * 0.03 + drop)
    ..cubicTo(cx - w * 0.05 * scale, mouthY - h * 0.02 + drop, cx - w * 0.11 * scale, mouthY - h * 0.03 + drop, cx - w * 0.17 * scale,
        mouthY - h * 0.005 + drop * 1.6)
    ..cubicTo(cx - w * 0.15 * scale, mouthY - h * 0.07 * flat + drop, cx - w * 0.06 * scale, mouthY - h * 0.085 * flat + drop, cx,
        mouthY - h * 0.055 * flat + drop)
    ..close();

  /// La barba piena: la parte bassa della faccia da un orecchio all'altro,
  /// con il buco della bocca. Segue la mascella di ogni forma.
  Path beard() {
    final beard = _mirrored(cx, Offset(cx, noseY + h * 0.05), [
      [Offset(cx + r * 0.45, noseY + h * 0.02), Offset(cx + r * 0.75, noseY + h * 0.02), Offset(cx + r * 0.99, cy + h * 0.06)],
      [Offset(cx + r * 1.04, cy + h * 0.2), Offset(cx + r * max(jaw, 0.8) * 1.0, cy + h * 0.42), Offset(cx + r * max(chin, 0.4) * 1.1, bottom + h * 0.05)],
      [Offset(cx + r * 0.3, bottom + h * 0.1), Offset(cx + r * 0.1, bottom + h * 0.11), Offset(cx, bottom + h * 0.11)],
    ]);
    final mouth = Path()..addOval(Rect.fromCenter(center: Offset(cx, mouthY + h * 0.01), width: w * 0.26, height: h * 0.06));
    return Path.combine(PathOperation.difference, beard, mouth);
  }

  // --- I capelli ------------------------------------------------------------

  static Path _union(Iterable<Path> parts) {
    Path? out;
    for (final p in parts) {
      out = out == null ? p : Path.combine(PathOperation.union, out, p);
    }
    return out ?? Path();
  }

  Path _circle(Offset at, double radius) => Path()..addOval(Rect.fromCircle(center: at, radius: radius));

  Path _slick(double s, {double wide = 1.0, double lift = 0}) => Path()
    ..moveTo(cx - s * r * 1.03 * wide, cy + h * 0.02)
    ..cubicTo(cx - s * r * 1.12 * wide, top - h * (0.02 + lift), cx - s * r * 0.4, top - h * (0.1 + lift), cx + s * r * 0.1, top - h * (0.07 + lift))
    ..cubicTo(cx + s * r * 0.8, top - h * (0.05 + lift), cx + s * r * 1.12 * wide, top + h * 0.1, cx + s * r * 1.03 * wide, cy + h * 0.02)
    ..lineTo(cx + s * r * 0.9, cy - h * 0.06)
    ..cubicTo(cx + s * r * 0.75, top + h * 0.2, cx + s * r * 0.1, top + h * 0.12, cx - s * r * 0.25, top + h * 0.15)
    ..cubicTo(cx - s * r * 0.7, top + h * 0.18, cx - s * r * 0.86, top + h * 0.3, cx - s * r * 0.9, cy - h * 0.06)
    ..close();

  Path _crop() => Path()
    ..moveTo(cx - r * 1.0, cy - h * 0.02)
    ..cubicTo(cx - r * 1.08, top - h * 0.03, cx + r * 1.08, top - h * 0.03, cx + r * 1.0, cy - h * 0.02)
    ..lineTo(cx + r * 0.92, cy - h * 0.08)
    ..cubicTo(cx + r * 0.88, top + h * 0.24, cx + r * 0.2, top + h * 0.2, cx - r * 0.25, top + h * 0.2)
    ..lineTo(cx - r * 0.3, top + h * 0.16)
    ..lineTo(cx - r * 0.38, top + h * 0.205)
    ..cubicTo(cx - r * 0.8, top + h * 0.23, cx - r * 0.9, top + h * 0.32, cx - r * 0.92, cy - h * 0.08)
    ..close();

  Path _curls({int n = 9, double spread = 0.92, double size = 1.0}) {
    final parts = <Path>[];
    for (var i = 0; i < n; i++) {
      final a = pi + pi * i / (n - 1);
      parts.add(_circle(Offset(cx + cos(a) * r * spread, cy - h * 0.06 + sin(a) * h * 0.5 * (0.96 + spread * 0.04)), w * (i.isEven ? 0.17 : 0.15) * size));
    }
    parts.add(_circle(Offset(cx - r * 0.25, top + h * 0.06), w * 0.17 * size));
    parts.add(_circle(Offset(cx + r * 0.3, top + h * 0.05), w * 0.16 * size));
    return _union(parts);
  }

  Path _waveFront({int waves = 1}) {
    if (waves <= 1) {
      return Path()
        ..moveTo(cx - r * 1.08, cy + h * 0.06)
        ..cubicTo(cx - r * 1.2, top - h * 0.06, cx + r * 1.2, top - h * 0.1, cx + r * 1.08, cy + h * 0.06)
        ..cubicTo(cx + r * 0.98, cy - h * 0.06, cx + r * 0.92, top + h * 0.28, cx + r * 0.55, top + h * 0.2)
        ..cubicTo(cx + r * 0.3, top + h * 0.3, cx + r * 0.05, top + h * 0.14, cx - r * 0.25, top + h * 0.22)
        ..cubicTo(cx - r * 0.55, top + h * 0.3, cx - r * 0.85, top + h * 0.22, cx - r * 0.95, cy - h * 0.02)
        ..close();
    }
    // Le onde a dito: la frangia che fa la esse tre volte.
    final p = Path()
      ..moveTo(cx - r * 1.08, cy + h * 0.06)
      ..cubicTo(cx - r * 1.2, top - h * 0.08, cx + r * 1.2, top - h * 0.1, cx + r * 1.08, cy + h * 0.06)
      ..cubicTo(cx + r * 0.98, cy - h * 0.04, cx + r * 0.95, top + h * 0.3, cx + r * 0.7, top + h * 0.22);
    for (var i = 0; i < 4; i++) {
      final x0 = cx + r * (0.7 - i * 0.42);
      p.quadraticBezierTo(x0 - r * 0.21, top + h * (i.isEven ? 0.32 : 0.12), x0 - r * 0.42, top + h * 0.22);
    }
    p
      ..cubicTo(cx - r * 0.98, top + h * 0.3, cx - r * 0.95, cy - h * 0.04, cx - r * 1.0, cy)
      ..close();
    return p;
  }

  Path _bobBack({double drop = 0.0}) => _mirrored(cx, Offset(cx, top - h * 0.05), [
        [Offset(cx + r * 0.85, top - h * 0.05), Offset(cx + r * 1.2, top + h * 0.15), Offset(cx + r * 1.18, cy + h * 0.1)],
        [Offset(cx + r * 1.28, cy + h * (0.26 + drop)), Offset(cx + r * 1.05, cy + h * (0.33 + drop)), Offset(cx + r * 0.88, cy + h * (0.26 + drop))],
        [Offset(cx + r * 0.6, cy + h * 0.2), Offset(cx + r * 0.2, cy + h * 0.15), Offset(cx, cy + h * 0.15)],
      ]);

  Path _waveBack() => _mirrored(cx, Offset(cx, top - h * 0.07), [
        [Offset(cx + r * 0.85, top - h * 0.07), Offset(cx + r * 1.28, top + h * 0.12), Offset(cx + r * 1.22, cy + h * 0.12)],
        [Offset(cx + r * 1.2, cy + h * 0.27), Offset(cx + r * 1.15, cy + h * 0.36), Offset(cx + r * 0.9, cy + h * 0.35)],
        [Offset(cx + r * 0.6, cy + h * 0.34), Offset(cx + r * 0.2, cy + h * 0.2), Offset(cx, cy + h * 0.2)],
      ]);

  Path _longBack() => _mirrored(cx, Offset(cx, top - h * 0.06), [
        [Offset(cx + r * 0.9, top - h * 0.06), Offset(cx + r * 1.25, top + h * 0.15), Offset(cx + r * 1.2, cy + h * 0.2)],
        [Offset(cx + r * 1.22, bottom + h * 0.1), Offset(cx + r * 1.3, shoulderY + 0.04), Offset(cx + r * 0.95, shoulderY + 0.07)],
        [Offset(cx + r * 0.55, shoulderY + 0.05), Offset(cx + r * 0.3, cy + h * 0.3), Offset(cx, cy + h * 0.3)],
      ]);

  Path _sideFront({double part = 0.0}) => _mirrored(cx, Offset(cx, top + h * 0.05), [
        [Offset(cx + r * 0.5, top - h * 0.1), Offset(cx + r * 1.12, top), Offset(cx + r * 1.06, cy + h * 0.04)],
        [Offset(cx + r * 0.98, cy - h * 0.05), Offset(cx + r * 0.85, top + h * 0.28), Offset(cx + r * 0.35, top + h * 0.22)],
        [Offset(cx + r * 0.15, top + h * 0.16), Offset(cx + r * 0.05, top + h * 0.08 + part), Offset(cx, top + h * 0.06 + part)],
      ]);

  Path _updoFront() => Path()
    ..moveTo(cx - r * 1.02, cy - h * 0.0)
    ..cubicTo(cx - r * 1.1, top - h * 0.05, cx + r * 1.1, top - h * 0.05, cx + r * 1.02, cy - h * 0.0)
    ..lineTo(cx + r * 0.92, cy - h * 0.1)
    ..cubicTo(cx + r * 0.8, top + h * 0.16, cx - r * 0.8, top + h * 0.16, cx - r * 0.92, cy - h * 0.1)
    ..close();

  Path _softFront() => Path()
    ..moveTo(cx - r * 1.08, cy + h * 0.04)
    ..cubicTo(cx - r * 1.15, top, cx + r * 1.15, top, cx + r * 1.08, cy + h * 0.04)
    ..cubicTo(cx + r * 0.9, cy - h * 0.05, cx + r * 0.6, top + h * 0.3, cx + r * 0.1, top + h * 0.27)
    ..cubicTo(cx - r * 0.4, top + h * 0.27, cx - r * 0.9, top + h * 0.3, cx - r * 0.98, cy + h * 0.02)
    ..close();

  Path _braid(int side) {
    final parts = <Path>[];
    for (var i = 0; i < 7; i++) {
      final y = cy + h * 0.12 + i * h * 0.085;
      final x = cx + side * (r * 1.06 + i * 0.004);
      parts.add(Path()..addOval(Rect.fromCenter(center: Offset(x + (i.isEven ? 0.006 : -0.006), y), width: w * 0.15 - i * 0.003, height: h * 0.11)));
    }
    return _union(parts);
  }

  /// I capelli dietro la testa (i caschetti, lo chignon, le lunghezze).
  Path? backHair(HairStyle style) => switch (style) {
        HairStyle.bob || HairStyle.pinCurls => _bobBack(),
        HairStyle.pageboy => _bobBack(drop: 0.03),
        HairStyle.wavy || HairStyle.fingerWaves => _waveBack(),
        HairStyle.victoryRolls => _bobBack(drop: 0.06),
        HairStyle.long || HairStyle.braids => _longBack(),
        HairStyle.updo => _circle(Offset(cx + r * 0.1, top - h * 0.07), w * 0.24),
        HairStyle.bun => _circle(Offset(cx, top - h * 0.14), w * 0.17),
        HairStyle.afro => _circle(Offset(cx, top + h * 0.16), w * 0.74),
        HairStyle.coils => _curls(n: 11, spread: 1.08, size: 1.05),
        HairStyle.ponytail => Path()
          ..moveTo(cx + r * 0.6, top + h * 0.02)
          ..cubicTo(cx + r * 1.45, top - h * 0.02, cx + r * 1.55, cy + h * 0.2, cx + r * 1.3, bottom + h * 0.08)
          ..cubicTo(cx + r * 1.2, cy + h * 0.25, cx + r * 1.15, cy, cx + r * 0.9, top + h * 0.18)
          ..close(),
        _ => null,
      };

  /// I capelli sopra la testa, davanti alla faccia.
  Path? frontHair(HairStyle style) => switch (style) {
        HairStyle.bald => null,
        HairStyle.slicked => _slick(1),
        HairStyle.sidePart => _slick(-1),
        HairStyle.ducktail => _slick(1, wide: 1.12, lift: 0.03),
        HairStyle.pompadour => _mirrored(cx, Offset(cx, top - h * 0.24), [
            [Offset(cx + r * 0.75, top - h * 0.28), Offset(cx + r * 1.14, top - h * 0.02), Offset(cx + r * 1.03, cy)],
            [Offset(cx + r * 0.95, cy - h * 0.08), Offset(cx + r * 0.85, top + h * 0.15), Offset(cx + r * 0.4, top + h * 0.12)],
            [Offset(cx + r * 0.2, top + h * 0.06), Offset(cx + r * 0.1, top + h * 0.02), Offset(cx, top + h * 0.03)],
          ]),
        HairStyle.crewCut => _crop(),
        HairStyle.quiff => _union([
            _crop(),
            Path()
              ..moveTo(cx - r * 0.75, top + h * 0.1)
              ..cubicTo(cx - r * 0.75, top - h * 0.2, cx + r * 0.3, top - h * 0.26, cx + r * 0.55, top - h * 0.05)
              ..lineTo(cx + r * 0.2, top + h * 0.08)
              ..close(),
          ]),
        HairStyle.flatTop => _mirrored(cx, Offset(cx, top - h * 0.13), [
            [Offset(cx + r * 0.6, top - h * 0.13), Offset(cx + r * 1.0, top - h * 0.13), Offset(cx + r * 1.04, top)],
            [Offset(cx + r * 1.05, top + h * 0.1), Offset(cx + r * 1.02, cy - h * 0.05), Offset(cx + r * 1.0, cy - h * 0.02)],
            [Offset(cx + r * 0.92, cy - h * 0.1), Offset(cx + r * 0.6, top + h * 0.12), Offset(cx, top + h * 0.12)],
          ]),
        HairStyle.receding => _mirrored(cx, Offset(cx, top - h * 0.03), [
            [Offset(cx + r * 0.6, top - h * 0.04), Offset(cx + r * 1.08, top + h * 0.05), Offset(cx + r * 1.0, cy - h * 0.02)],
            [Offset(cx + r * 0.94, cy - h * 0.1), Offset(cx + r * 0.75, top + h * 0.02), Offset(cx + r * 0.5, top + h * 0.06)],
            [Offset(cx + r * 0.3, top + h * 0.1), Offset(cx + r * 0.1, top + h * 0.16), Offset(cx, top + h * 0.16)],
          ]),
        HairStyle.middlePart || HairStyle.long || HairStyle.braids => _sideFront(),
        HairStyle.curly => _curls(),
        HairStyle.coils => _curls(n: 11, spread: 0.98, size: 0.85),
        HairStyle.afro => Path.combine(
            PathOperation.difference,
            _circle(Offset(cx, top + h * 0.18), w * 0.66),
            Path()..addOval(Rect.fromCenter(center: Offset(cx, cy + h * 0.16), width: w * 0.92, height: h * 0.92)),
          ),
        HairStyle.wavy => _waveFront(),
        HairStyle.fingerWaves => _waveFront(waves: 3),
        HairStyle.bob => _softFront(),
        HairStyle.pageboy => _mirrored(cx, Offset(cx, top - h * 0.05), [
            [Offset(cx + r * 0.85, top - h * 0.05), Offset(cx + r * 1.15, top + h * 0.1), Offset(cx + r * 1.1, cy + h * 0.05)],
            [Offset(cx + r * 1.0, cy), Offset(cx + r * 0.95, top + h * 0.3), Offset(cx + r * 0.7, top + h * 0.3)],
            [Offset(cx + r * 0.4, top + h * 0.3), Offset(cx + r * 0.2, top + h * 0.3), Offset(cx, top + h * 0.3)],
          ]),
        HairStyle.pinCurls => _union([
            _softFront(),
            for (var i = 0; i < 6; i++) _circle(Offset(cx + r * (-0.75 + i * 0.3), top + h * 0.22), w * 0.075),
          ]),
        HairStyle.victoryRolls => _union([
            _updoFront(),
            _circle(Offset(cx - r * 0.55, top + h * 0.0), w * 0.2),
            _circle(Offset(cx + r * 0.55, top + h * 0.0), w * 0.2),
          ]),
        HairStyle.bun || HairStyle.updo || HairStyle.ponytail => _updoFront(),
      };

  /// Le trecce, sopra le spalle.
  Path? braids(HairStyle style) => style == HairStyle.braids ? _union([_braid(-1), _braid(1)]) : null;

  // --- I cappelli classici ----------------------------------------------------

  /// La tesa, la cupola e la fascia dei cappelli disegnati qui; null per
  /// quelli che si prendono dalla bottega di sempre.
  ({Path? brim, Path crown, Path? band})? hat(AvatarHead hat) {
    final by = brimY;
    ({Path? brim, Path crown, Path? band}) fedora({double brimW = 0.86, double height = 0.36, double flat = 0, double tilt = 0}) {
      final bw = w * brimW;
      final brim = Path()
        ..moveTo(cx - bw, by + h * (0.02 + tilt))
        ..cubicTo(cx - bw * 0.9, by - h * (0.08 - tilt), cx + bw * 0.9, by - h * (0.08 + tilt), cx + bw, by + h * (0.02 - tilt))
        ..cubicTo(cx + bw * 0.7, by + h * 0.1, cx + bw * 0.3, by + h * 0.12, cx, by + h * 0.12)
        ..cubicTo(cx - bw * 0.3, by + h * 0.12, cx - bw * 0.7, by + h * 0.1, cx - bw, by + h * (0.02 + tilt))
        ..close();
      final cw = r * 0.98;
      final ct = by - h * height;
      final crown = Path()
        ..moveTo(cx - cw, by)
        ..cubicTo(cx - cw * 1.0, by - h * height * 0.55, cx - cw * 0.85, ct, cx - cw * 0.45, ct + h * 0.01)
        ..quadraticBezierTo(cx, ct + h * 0.1 * (1 - flat), cx + cw * 0.45, ct + h * 0.01)
        ..cubicTo(cx + cw * 0.85, ct, cx + cw * 1.0, by - h * height * 0.55, cx + cw, by)
        ..close();
      final band = Path()
        ..moveTo(cx - cw * 1.0, by - h * 0.005)
        ..lineTo(cx - cw * 0.99, by - h * 0.08)
        ..quadraticBezierTo(cx, by - h * 0.06, cx + cw * 0.99, by - h * 0.08)
        ..lineTo(cx + cw * 1.0, by - h * 0.005)
        ..quadraticBezierTo(cx, by + h * 0.02, cx - cw * 1.0, by - h * 0.005)
        ..close();
      return (brim: brim, crown: crown, band: band);
    }

    ({Path? brim, Path crown, Path? band}) flatTop({double brimW = 0.72, double height = 0.26, double flare = 1.0}) {
      final bw = w * brimW;
      final cw = r * 0.96;
      final brim = Path()..addOval(Rect.fromCenter(center: Offset(cx, by + h * 0.03), width: bw * 2, height: h * 0.13));
      final crown = Path()
        ..moveTo(cx - cw, by)
        ..lineTo(cx - cw * flare, by - h * height)
        ..quadraticBezierTo(cx, by - h * (height + 0.03), cx + cw * flare, by - h * height)
        ..lineTo(cx + cw, by)
        ..close();
      final band = Path()..addRect(Rect.fromLTRB(cx - cw * 1.0, by - h * 0.08, cx + cw * 1.0, by - h * 0.005));
      return (brim: brim, crown: crown, band: band);
    }

    switch (hat) {
      case AvatarHead.fedora || AvatarHead.pearlFedora:
        return fedora();
      case AvatarHead.borsalino:
        return fedora(brimW: 0.92, height: 0.38);
      case AvatarHead.wideBrim:
        return fedora(brimW: 1.2, height: 0.3, tilt: 0.03);
      case AvatarHead.trilby:
        return fedora(brimW: 0.66, height: 0.32, tilt: 0.04);
      case AvatarHead.homburg:
        return fedora(brimW: 0.74, height: 0.38, flat: 0.3);
      case AvatarHead.panama:
        return fedora(brimW: 0.84, height: 0.32);
      case AvatarHead.porkPie:
        return flatTop(brimW: 0.68, height: 0.22);
      case AvatarHead.boater:
        return flatTop(brimW: 0.84, height: 0.2);
      case AvatarHead.sbirro:
        // Il berretto da sbirro: la cupola che si allarga in alto, la fascia
        // e la visiera corta davanti.
        final t = flatTop(brimW: 0.6, height: 0.24, flare: 1.18);
        final visor = Path()
          ..moveTo(cx - r * 0.9, by + h * 0.005)
          ..quadraticBezierTo(cx, by + h * 0.1, cx + r * 0.9, by + h * 0.005)
          ..quadraticBezierTo(cx, by + h * 0.05, cx - r * 0.9, by + h * 0.005)
          ..close();
        return (brim: visor, crown: t.crown, band: t.band);
      case AvatarHead.topHat:
        final t = flatTop(brimW: 0.72, height: 0.62, flare: 1.06);
        return (brim: t.brim, crown: t.crown, band: Path()..addRect(Rect.fromLTRB(cx - r * 0.97, by - h * 0.11, cx + r * 0.97, by - h * 0.01)));
      case AvatarHead.bowler:
        final bw = w * 0.66;
        final brim = Path()
          ..moveTo(cx - bw, by - h * 0.03)
          ..quadraticBezierTo(cx - bw * 0.9, by + h * 0.04, cx, by + h * 0.06)
          ..quadraticBezierTo(cx + bw * 0.9, by + h * 0.04, cx + bw, by - h * 0.03)
          ..quadraticBezierTo(cx, by - h * 0.0, cx - bw, by - h * 0.03)
          ..close();
        final crown = Path()
          ..moveTo(cx - r * 0.9, by)
          ..cubicTo(cx - r * 0.98, by - h * 0.42, cx + r * 0.98, by - h * 0.42, cx + r * 0.9, by)
          ..close();
        final band = Path()
          ..moveTo(cx - r * 0.91, by - h * 0.005)
          ..lineTo(cx - r * 0.93, by - h * 0.065)
          ..quadraticBezierTo(cx, by - h * 0.045, cx + r * 0.93, by - h * 0.065)
          ..lineTo(cx + r * 0.91, by - h * 0.005)
          ..close();
        return (brim: brim, crown: crown, band: band);
      case AvatarHead.coppola:
        final crown = Path()
          ..moveTo(cx - r * 1.06, by + h * 0.02)
          ..cubicTo(cx - r * 1.18, by - h * 0.3, cx + r * 1.25, by - h * 0.34, cx + r * 1.14, by)
          ..quadraticBezierTo(cx, by + h * 0.04, cx - r * 1.06, by + h * 0.02)
          ..close();
        final brim = Path()
          ..moveTo(cx - r * 0.8, by + h * 0.02)
          ..quadraticBezierTo(cx, by + h * 0.13, cx + r * 0.85, by + h * 0.01)
          ..quadraticBezierTo(cx, by + h * 0.05, cx - r * 0.8, by + h * 0.02)
          ..close();
        return (brim: brim, crown: crown, band: null);
      case AvatarHead.beret:
        final crown = Path()..addOval(Rect.fromCenter(center: Offset(cx + r * 0.18, by - h * 0.1), width: w * 1.22, height: h * 0.26));
        final band = Path()
          ..moveTo(cx - r * 0.95, by - h * 0.02)
          ..quadraticBezierTo(cx, by + h * 0.04, cx + r * 0.95, by - h * 0.02)
          ..lineTo(cx + r * 0.95, by - h * 0.07)
          ..quadraticBezierTo(cx, by - h * 0.01, cx - r * 0.95, by - h * 0.07)
          ..close();
        final brim = Path()..addOval(Rect.fromCircle(center: Offset(cx + r * 0.25, by - h * 0.24), radius: w * 0.03));
        return (brim: brim, crown: crown, band: band);
      case AvatarHead.crown:
        final by = top + h * 0.12;
        final cw = r * 0.95;
        final crown = Path()
          ..moveTo(cx - cw, by)
          ..lineTo(cx - cw * 1.08, by - h * 0.3)
          ..lineTo(cx - cw * 0.55, by - h * 0.14)
          ..lineTo(cx, by - h * 0.36)
          ..lineTo(cx + cw * 0.55, by - h * 0.14)
          ..lineTo(cx + cw * 1.08, by - h * 0.3)
          ..lineTo(cx + cw, by)
          ..close();
        final band = Path()..addRect(Rect.fromLTRB(cx - cw * 1.0, by - h * 0.07, cx + cw * 1.0, by));
        // Per la corona la «tesa» sono i rubini.
        final jewels = Path()
          ..addOval(Rect.fromCircle(center: Offset(cx, by - h * 0.035), radius: w * 0.04))
          ..addOval(Rect.fromCircle(center: Offset(cx - cw * 0.6, by - h * 0.035), radius: w * 0.03))
          ..addOval(Rect.fromCircle(center: Offset(cx + cw * 0.6, by - h * 0.035), radius: w * 0.03));
        return (brim: jewels, crown: crown, band: band);
      case AvatarHead.cloche:
        final cy0 = browY - h * 0.005;
        final crown = Path()
          ..moveTo(cx - r * 1.12, cy0)
          ..cubicTo(cx - r * 1.22, top - h * 0.12, cx + r * 1.22, top - h * 0.12, cx + r * 1.12, cy0)
          ..close();
        final brim = Path()
          ..moveTo(cx - r * 1.24, cy0 + h * 0.07)
          ..quadraticBezierTo(cx - r * 1.2, cy0 - h * 0.06, cx - r * 0.9, cy0 - h * 0.04)
          ..quadraticBezierTo(cx, cy0 - h * 0.0, cx + r * 0.9, cy0 - h * 0.04)
          ..quadraticBezierTo(cx + r * 1.2, cy0 - h * 0.06, cx + r * 1.24, cy0 + h * 0.07)
          ..quadraticBezierTo(cx, cy0 + h * 0.03, cx - r * 1.24, cy0 + h * 0.07)
          ..close();
        final band = Path()
          ..moveTo(cx - r * 1.13, cy0 - h * 0.06)
          ..quadraticBezierTo(cx, cy0 - h * 0.03, cx + r * 1.13, cy0 - h * 0.06)
          ..lineTo(cx + r * 1.08, cy0 - h * 0.13)
          ..quadraticBezierTo(cx, cy0 - h * 0.1, cx - r * 1.08, cy0 - h * 0.13)
          ..close();
        return (brim: brim, crown: crown, band: band);
      default:
        return null;
    }
  }
}

/// I colori dei cappelli disegnati qui: la cupola e la fascia.
(Color, Color) _hatColors(AvatarLook look) {
  final accent = look.outfit.accent;
  return switch (look.hat) {
    AvatarHead.fedora => (const Color(0xFF34302E), Color.lerp(accent, _nInk, 0.35)!),
    AvatarHead.pearlFedora => (const Color(0xFFB9B6B0), const Color(0xFF1C1A1A)),
    AvatarHead.borsalino => (const Color(0xFF4A3A2C), const Color(0xFF1A1210)),
    AvatarHead.wideBrim => (const Color(0xFF1C1A20), Color.lerp(accent, _nInk, 0.2)!),
    AvatarHead.trilby => (const Color(0xFF5A4030), const Color(0xFF2A1C12)),
    AvatarHead.homburg => (const Color(0xFF1E1C22), const Color(0xFF101014)),
    AvatarHead.panama => (const Color(0xFFE6D8B0), const Color(0xFF1C1A1A)),
    AvatarHead.porkPie => (const Color(0xFF4A3A2C), const Color(0xFF2A1C12)),
    AvatarHead.boater => (const Color(0xFFE0CB8C), Color.lerp(accent, _nInk, 0.1)!),
    AvatarHead.topHat => (const Color(0xFF18161A), Color.lerp(accent, _nInk, 0.25)!),
    AvatarHead.bowler => (const Color(0xFF1C1A1A), const Color(0xFF4A1018)),
    AvatarHead.coppola => (const Color(0xFF5A4C3C), const Color(0xFF3A3026)),
    AvatarHead.beret => (const Color(0xFF5A1A26), const Color(0xFF3A0E16)),
    AvatarHead.cloche => (const Color(0xFF6E1626), const Color(0xFF151010)),
    AvatarHead.crown => (const Color(0xFFF2C14E), const Color(0xFFB3141E)),
    AvatarHead.sbirro => (const Color(0xFF1B2A4A), const Color(0xFF0E0E12)),
    _ => (const Color(0xFF2A2626), const Color(0xFF0E0C0C)),
  };
}

/// Le forme di una persona, calcolate una volta e tenute da parte: al tavolo
/// si ridisegna a ogni fotogramma.
class _NParts {
  final _NB b;
  final Path face;
  final Path neck;
  final Path torso;
  final List<Path> ears;
  final Path? back;
  final Path? front;
  final Path? braids;
  final ({Path? brim, Path crown, Path? band})? hat;

  /// Fin dove sale la persona (il cappello, i capelli), nel quadrato.
  final double crown;

  /// Fin dove salgono i capelli.
  final double hairTop;

  /// Fin dove sale quello che c'è in testa (i capelli, il cappello), senza
  /// l'effetto che ci galleggia sopra: lì si posa [HeadFx].
  final double headTop;
  final Map<(Path, double), (Path, Path)> _toon = {};

  _NParts(this.b, {required this.face, required this.neck, required this.torso, required this.ears, this.back, this.front, this.braids, this.hat, required this.crown, required this.hairTop, required this.headTop});

  /// L'ombra netta (la forma meno sé stessa spostata verso la lampada) e il
  /// filo di luce (meno sé stessa spostata dall'altra parte). [side] è il
  /// lato in ombra: 1 a destra.
  (Path, Path) toon(Path p, double d, double side) => _toon[(p, side)] ??= (
        Path.combine(PathOperation.difference, p, p.shift(Offset(-d * side, -d * 0.8))),
        Path.combine(PathOperation.difference, p, p.shift(Offset(0.014 * side, 0.012))),
      );
}

abstract final class _Noir {
  static final Map<int, _NParts> _cache = {};

  static bool _real(AvatarLook look) =>
      !look.bareHead && !_Face._onTop.contains(look.hat) && !_Face._covered.contains(look.hat) && look.hairdo == Hairdo.none;

  static _NParts parts(AvatarLook look, {double base = 1.02}) {
    final key = Object.hash(look, base);
    final hit = _cache[key];
    if (hit != null) return hit;
    if (_cache.length > 96) _cache.clear();
    final b = _NB.of(look, base: base);
    final style = look.features.hair;
    final hidden = _Face._covered.contains(look.hat) || look.hairdo != Hairdo.none;
    var back = hidden ? null : b.backHair(style);
    var front = hidden ? null : b.frontHair(style);
    final native = look.hairdo == Hairdo.none ? b.hat(look.hat) : null;
    if (_real(look)) {
      // Sotto un cappello resta solo quello che scende sotto la tesa: le
      // basette, i lati, la nuca, la coda.
      final line = native == null ? hatMap(b).transform(const Offset(0, -0.92)).dy : (look.hat == AvatarHead.cloche ? b.browY + b.h * 0.08 : b.brimY + b.h * 0.04);
      final below = Path()..addRect(Rect.fromLTRB(-1, line, 2, 3));
      if (back != null) back = Path.combine(PathOperation.intersect, back, below);
      if (front != null) front = Path.combine(PathOperation.intersect, front, below);
    }
    final braids = hidden ? null : b.braids(style);
    var crown = b.top;
    for (final p in [back, front]) {
      if (p != null) crown = min(crown, p.getBounds().top);
    }
    final hairTop = crown;
    var hat = native;
    if (hat != null && look.hat == AvatarHead.crown) {
      final dy = min(0.0, hairTop - (b.top - b.h * 0.04));
      if (dy < 0) hat = (brim: hat.brim?.shift(Offset(0, dy)), crown: hat.crown.shift(Offset(0, dy)), band: hat.band?.shift(Offset(0, dy)));
    }
    if (hat != null) crown = min(crown, hat.crown.getBounds().top);
    if (native == null && !look.bareHead && look.hairdo == Hairdo.none) {
      crown = min(crown, hatMap(b).transform(Offset(0, LookPainter.crown(look.copyWith(hairdo: Hairdo.none)))).dy + lift(look, b, hairTop: crown));
    }
    if (look.hairdo != Hairdo.none) crown = min(crown, hatMap(b).transform(Offset(0, LookPainter.crown(look))).dy);
    final wings = look.accessory == AvatarAccessory.balloons || look.back == BackItem.dragonWings ? bodyMap(b, look).transform(const Offset(0, -1.34)).dy : 1.0;
    crown = min(crown, wings);
    final headTop = crown;
    // L'effetto in testa galleggia sopra: si fa spazio anche lui.
    if (look.headFx.rise > 0) crown = min(crown, headTop - look.headFx.rise);
    return _cache[key] = _NParts(
      b,
      face: b.face(),
      neck: b.neck(),
      torso: b.torso(),
      ears: [for (final s in [-1, 1]) Path()..addOval(b.ear(s))],
      back: back,
      front: front,
      braids: braids,
      hat: hat,
      crown: crown,
      hairTop: hairTop,
      headTop: headTop,
    );
  }

  /// Le cose che si posano sui capelli liberi (l'aureola, le corna, il
  /// gatto) salgono quanto i capelli.
  static double lift(AvatarLook look, _NB b, {required double hairTop}) {
    if (!_Face._onTop.contains(look.hat) || look.hairdo != Hairdo.none) return 0;
    final rest = hatMap(b).transform(const Offset(0, -1.1)).dy;
    return min(0.0, hairTop - rest);
  }

  /// Dai pittori di sempre al quadrato del ritratto: la testa (cappelli,
  /// pettinature della bottega) con la sommità del cranio al suo posto.
  static _M hatMap(_NB b) => _M(b.cx, b.top, b.w / 0.316, 0, -1.06);
  static _M eyeMap(_NB b) => _M(b.cx, b.eyeY, b.eyeDx / 0.064, 0, -0.868);
  static _M mouthMap(_NB b) => _M(b.cx, b.mouthY, b.w / 0.316, 0, -0.762);
  static _M bodyMap(_NB b, AvatarLook look) => _M(b.cx, b.shoulderY + 0.035, look.dame ? 0.98 : 1.04, 0, -0.58);

  static final Map<(AvatarLook, String, double), ui.Picture> _pieces = {};

  /// Un pezzo strano di [look] ([draw], nelle misure dei pittori di sempre
  /// portate qui da [m]), disegnato una volta sulla tela noir e tenuto da
  /// parte: al tavolo si ridisegna a ogni fotogramma.
  static ui.Picture piece(AvatarLook look, String key, double side, _M m, void Function(Canvas c) draw) {
    final hit = _pieces[(look, key, side)];
    if (hit != null) return hit;
    if (_pieces.length > 400) _pieces.clear();
    final recorder = ui.PictureRecorder();
    final ink = _InkCanvas(Canvas(recorder), side);
    final previous = LookPainter._style;
    LookPainter._style = const _Style(noir: true);
    _with(ink, m, () => draw(ink));
    LookPainter._style = previous;
    return _pieces[(look, key, side)] = recorder.endRecording();
  }

  static void _with(Canvas canvas, _M m, void Function() paint) {
    canvas.save();
    canvas.translate(m.x0 - m.fx * m.k, m.y0 - m.fy * m.k);
    canvas.scale(m.k);
    paint();
    canvas.restore();
  }

  /// La scala del ritratto quando quello che porta in testa salirebbe oltre
  /// il bordo: si rimpicciolisce tutto verso il basso, le spalle restano.
  static double fit(_NParts p) => p.crown < 0.03 ? (1 - 0.03) / (1 - p.crown) : 1.0;

  /// Quanto si rimpicciolisce chi tiene qualcosa in mano o sulle spalle, per
  /// fargli posto nel ritratto.
  static const roomy = 0.86;

  /// La scala del ritratto: [fit], e un poco meno per chi chiede spazio.
  static double scale(AvatarLook look, _NParts p) => fit(p) * (look.roomy ? roomy : 1.0);

  /// La scena di [look] nel ritratto di lato [side], sull'area [area] (in pixel).
  static void aura(Canvas canvas, AvatarLook look, double side, Rect area) {
    if (look.aura == Aura.none) return;
    final p = parts(look);
    final b = p.b;
    final k = scale(look, p);
    final head = Offset(0.5 + (b.cx - 0.5) * k, 1 + ((b.top + b.bottom) / 2 - 1) * k);
    final box = Rect.fromLTRB(area.left / side, area.top / side, area.right / side, area.bottom / side);
    canvas.save();
    canvas.scale(side);
    _Deep.begin(side);
    _Deep.pic(canvas, ('aura', look.aura, box, head), (c) => _Deep.aura(c, look.aura, box, head));
    canvas.restore();
  }

  /// Il ritratto di [look] in un quadrato di lato [side].
  static void bust(Canvas canvas, AvatarLook look, double side, {Offset light = const Offset(-0.6, -0.8), double glance = 0, Set<LookLayer>? only, bool aura = true}) {
    final p = parts(look);
    final k = scale(look, p);
    if (aura && only == null) _Noir.aura(canvas, look, side, Offset.zero & Size.square(side));
    canvas.save();
    canvas.scale(side);
    canvas.translate(0.5, 1);
    canvas.scale(k);
    canvas.translate(-0.5, -1);
    paint(canvas, look, p, side * k, light: light, glance: glance, only: only, gilt: _gilded(look) && only == null, layered: true);
    canvas.restore();
  }

  /// Quello che sta dietro le spalle: le ali, i palloncini, il guscio, il
  /// razzo, e i fumogeni e le bandiere delle curve (le sciarpe no).
  static bool _winged(AvatarLook look) => look.back.wing || _wingedVice(look.accessory);

  static bool _wingedVice(AvatarAccessory a) =>
      const {AvatarAccessory.balloons, AvatarAccessory.snailShell, AvatarAccessory.jetpack}.contains(a) ||
      (CalcioTeam.of(a.name) != null && !a.name.endsWith('Scarf'));

  static bool _gilded(AvatarLook look) => look.base.mark == FaceMark.goldStatue || const {'gold_brocade', 'versalli_baroque'}.contains(look.outfit.id);

  /// La persona, pezzo per pezzo nell'ordine di [LookLayer].
  static void paint(
    Canvas canvas,
    AvatarLook look,
    _NParts p,
    double side, {
    required Offset light,
    double glance = 0,
    Set<LookLayer>? only,
    bool gilt = false,
    bool layered = false,
  }) {
    final b = p.b;
    final ow = max(0.024, 2.2 / side);
    final thin = max(0.009, 1.0 / side);
    final small = side < 110;
    final sx = light.dx <= 0 ? 1.0 : -1.0; // il lato in ombra
    final bare = only != null;
    final f = look.features;
    final gold = look.base.mark == FaceMark.goldStatue;
    final skin = gold ? const Color(0xFFD9A93E) : (look.base.mark == FaceMark.mimeFace ? const Color(0xFFF4F0E8) : look.base.skin);
    final hair = gold ? const Color(0xFFB98A26) : f.hairColor.color;
    final styled = look.hairdo != Hairdo.none;
    final hatLift = lift(look, b, hairTop: p.hairTop);
    final previous = LookPainter._style;
    LookPainter._style = _Style(small: small, noir: true, bare: bare);

    void toon(Path path, Color base, {double d = 0.06, bool rim = true, bool line = true, double glow = 0.45}) {
      canvas.drawPath(path, _nFill(base));
      if (bare) return;
      final (shadow, lit) = p.toon(path, d, sx);
      canvas.drawPath(shadow, _nFill(_nDark(base)));
      if (rim) canvas.drawPath(lit, _nFill(Color.lerp(base, _nLamp, glow)!));
      if (line) canvas.drawPath(path, _nStroke(_nInk, thin));
    }

    // I posti più cari: le linee del ritratto, e dove sta la faccia.
    _Deep.begin(side);
    final g = _DGeo.of(p, crown: p.headTop);
    final dye = styled || gold ? HairDye.none : look.hairDye;

    /// I capelli: col loro colore, o con la tinta, una sfumatura dall'alto
    /// in basso che tiene l'ombra netta e il filo di luce.
    void hairToon(Path path, Color base, {required double d, double glow = 0.3}) {
      if (dye == HairDye.none) return toon(path, base, d: d, glow: glow);
      final band = Rect.fromLTRB(0, p.hairTop, 1, max(b.bottom + 0.12, path.getBounds().bottom));
      final colors = dye.colors;
      final stops = colors.length == 3 ? const [0.2, 0.5, 0.8] : const [0.15, 0.85];
      Paint shade(List<Color> c) => Paint()..shader = ui.Gradient.linear(band.topCenter, band.bottomCenter, c, stops);
      canvas.drawPath(path, shade(colors));
      if (bare) return;
      final (shadow, lit) = p.toon(path, d, sx);
      canvas.drawPath(shadow, shade([for (final c in colors) _nDark(c)]));
      canvas.drawPath(lit, shade([for (final c in colors) Color.lerp(c, _nLamp, glow)!]));
      canvas.drawPath(path, _nStroke(_nInk, thin));
    }

    final hatAt = hatMap(b);
    final liftedHat = _M(hatAt.x0, hatAt.y0 + hatLift, hatAt.k, hatAt.fx, hatAt.fy);
    final legacyHat = p.hat == null && !look.bareHead && !styled;
    final nativeOutfit = _nativeOutfit(look.outfit.pattern);

    // Un pezzo strano della bottega: disegnato una volta sulla tela noir
    // ([_InkCanvas]) e tenuto da parte.
    void pic(String key, _M m, void Function(Canvas c) draw, {AvatarLook? as}) => canvas.drawPicture(piece(as ?? look, key, sx, m, draw));
    final bowed = look.accessory == AvatarAccessory.bowTie || look.accessory == AvatarAccessory.polkaBowTie;
    final neckLook = bowed ? look.copyWith(accessory: AvatarAccessory.none) : look;
    final broad = look.dame ? 0.86 : 1.0;
    final faceTattoo = look.tattoo == Tattoo.teardrop || look.tattoo == Tattoo.cheekStar;

    // The ink pass only outlines what has an edge: the stadium glow and the
    // flare's smoke would turn into a dark disc behind the shoulders.
    void wings({bool ink = false}) => pic(ink ? 'wingsInk' : 'wings', bodyMap(b, look), (c) {
          _Calcio.glow = !ink;
          _Oddities.wings(c, look);
          _Calcio.glow = true;
        });
    void oddHat() => pic('hat', liftedHat, (c) => LookPainter._hat(c, look, Paint(), silhouette: false));
    void hairdoBack() => pic('hairdoBack', hatAt, (c) => _Extras.hairdoBack(c, look, null));
    void hairdoFront() => pic('hairdoFront', hatAt, (c) => _Extras.hairdoFront(c, look));
    void coat() => pic('coat', bodyMap(b, look), (c) => LookPainter._coat(c, look, LookPainter._torso(broad), const Offset(-0.6, -0.8)));
    void oddGlasses() => pic('glasses', eyeMap(b), (c) => LookPainter._glasses(c, look, const CharacterPose()));
    // Quello che sta in bocca segue la bocca; quello che sta sul petto o in
    // mano (il pappagallo, la fisarmonica) segue le spalle.
    // La paperella e la fisarmonica salgono un poco, che il bordo non le tagli.
    final chestAt = bodyMap(b, look);
    final low = look.accessory == AvatarAccessory.rubberDuck || look.accessory == AvatarAccessory.accordion;
    final propAt = !_onChest(look.accessory) ? mouthMap(b) : (low ? _M(chestAt.x0, chestAt.y0 - 0.1, chestAt.k, chestAt.fx, chestAt.fy) : chestAt);
    void oddProp() => pic('prop', propAt, (c) => LookPainter._mouthProp(c, look));
    // Gli orologi da taschino e il fazzoletto stavano sul petto lungo di
    // una volta: qui salgono dove il busto si vede ancora.
    final pocket = const {AvatarAccessory.pocketWatch, AvatarAccessory.ricciWatch, AvatarAccessory.ricciChain, AvatarAccessory.pocketSquare}.contains(look.accessory);
    final chestMap = pocket ? _M(chestAt.x0, chestAt.y0 - 0.09, chestAt.k, chestAt.fx, chestAt.fy) : chestAt;
    void chest() => pic('chest', chestMap, (c) => LookPainter._chest(c, look, broad));
    void neckwear() => pic('neck', bodyMap(b, look), (c) {
          LookPainter._neck(c, neckLook, const Offset(-0.6, -0.8));
          if (!faceTattoo) _Extras.tattoo(c, neckLook);
        }, as: neckLook);

    bool on(LookLayer layer) => only == null || only.contains(layer);

    void eyeShine() {
      if (look.eyeShine == EyeShine.none) return;
      final pupils = _pupils(look, b, glance);
      _Deep.pic(canvas, ('eyes', look.eyeShine, pupils.$1, pupils.$2), (c) => _Deep.eyeShine(c, look.eyeShine, pupils.$1, pupils.$2));
    }

    // --- Dietro a tutto: le spalle e il bagliore, con la loro sagoma ---
    if (on(LookLayer.back)) {
      if (_winged(look)) {
        if (!bare && layered) {
          canvas.saveLayer(
            const Rect.fromLTRB(-0.5, -0.5, 1.5, 1.5),
            Paint()
              ..imageFilter = ui.ImageFilter.dilate(radiusX: ow, radiusY: ow)
              ..colorFilter = const ColorFilter.mode(_nInk, BlendMode.srcIn),
          );
          wings(ink: true);
          canvas.restore();
        }
        wings();
      }
      if (layered && look.back.roomy) _Deep.pic(canvas, ('back', look.back, g), (c) => _Deep.back(c, look.back, g));
    }
    if (on(LookLayer.headGlow) && !bare && look.headFx.glow != null) {
      _Deep.pic(canvas, ('glow', look.headFx, look), (c) => _Deep.headGlow(c, [p.back, p.neck, ...p.ears, p.face, p.front, p.braids, p.hat?.crown, p.hat?.brim].whereType<Path>().toList(), look.headFx.glow!));
    }

    // --- La sagoma d'inchiostro ---
    if (!bare) {
      final heavy = _nStroke(_nInk, ow * 2);
      for (final path in [p.back, p.neck, if (nativeOutfit) p.torso, ...p.ears, p.face, p.front, p.braids, p.hat?.crown, if (look.hat != AvatarHead.crown) p.hat?.brim]) {
        if (path != null) canvas.drawPath(path, heavy);
      }
      if (look.base.mark == FaceMark.fullBeard || look.base.mark == FaceMark.muttonChops) canvas.drawPath(b.beard(), heavy);
    }

    // --- La sagoma d'inchiostro dei pezzi strani: allargati e neri, dietro ---
    if (!bare) {
      final odd = legacyHat || styled || !nativeOutfit || !_nativeGlasses(look.glasses) || !_nativeProp(look.accessory);
      if (odd && layered) {
        canvas.saveLayer(
          const Rect.fromLTRB(-0.5, -0.5, 1.5, 1.5),
          Paint()
            ..imageFilter = ui.ImageFilter.dilate(radiusX: ow, radiusY: ow)
            ..colorFilter = const ColorFilter.mode(_nInk, BlendMode.srcIn),
        );
        if (legacyHat) oddHat();
        if (styled) {
          hairdoBack();
          hairdoFront();
        }
        if (!nativeOutfit) coat();
        if (!_nativeGlasses(look.glasses)) oddGlasses();
        if (!_nativeProp(look.accessory)) oddProp();
        chest();
        canvas.restore();
      }
    }

    for (final layer in LookLayer.values) {
      if (only != null && !only.contains(layer)) continue;
      switch (layer) {
        case LookLayer.back || LookLayer.headGlow:
          break; // Già dipinti, prima della sagoma.
        case LookLayer.hairBack:
          if (styled) {
            hairdoBack();
          } else if (p.back != null) {
            hairToon(p.back!, Color.lerp(hair, _nInk, 0.12)!, d: 0.08);
          }
        case LookLayer.body:
          toon(p.neck, Color.lerp(skin, _nNight, 0.5)!, rim: false);
          if (nativeOutfit) {
            _outfit(canvas, look, p, thin, toon);
          } else {
            coat();
          }
        case LookLayer.neck:
          // A tie, the braces and the lapels stop at the hem, as the suit
          // does: they would hang below it where the bust is drawn whole.
          canvas.save();
          if (nativeOutfit) canvas.clipRect(Rect.fromLTRB(-1, -1, 2, b.base));
          neckwear();
          if (bowed) _bowTie(canvas, look, b, thin);
          if (nativeOutfit && !const {CoatPattern.dress, CoatPattern.blouse, CoatPattern.jersey}.contains(look.outfit.pattern)) {
            final lapel = Color.lerp(look.outfit.coat, _nInk, look.outfit.pattern == CoatPattern.tuxedo ? 0.7 : 0.3)!;
            for (final s in [-1, 1]) {
              toon(b.lapel(s, wide: look.outfit.pattern == CoatPattern.doubleBreasted || look.outfit.pattern == CoatPattern.trench), lapel, d: 0.025, rim: s < 0);
            }
          }
          canvas.restore();
        case LookLayer.face:
          for (final e in p.ears) {
            toon(e, skin, d: 0.03);
          }
          toon(p.face, skin, d: 0.075);
          _faceDetails(canvas, look, b, skin, thin, small, bare);
          if (p.hat != null && !bare) _brimShadow(canvas, look, p, skin);
          _features(canvas, look, b, skin, thin, small, glance: glance, shaded: p.hat != null);
          if (faceTattoo) pic('tattoo', mouthMap(b), (c) => _Extras.tattoo(c, look));
          if (!look.glasses.dark) eyeShine();
        case LookLayer.beard:
          _beard(canvas, look, b, hair, thin, toon, pic);
          // I segni sulla faccia, sopra i baffi e il rossetto.
          if (look.faceExtras.isNotEmpty) _Deep.pic(canvas, ('face', AvatarLook.extrasId(look.faceExtras), g), (c) => _Deep.faceExtras(c, look.faceExtras, g));
        case LookLayer.hairFront:
          if (styled) {
            hairdoFront();
          } else {
            if (p.front != null) {
              hairToon(p.front!, hair, d: 0.07);
              _hairDetail(canvas, look, p, dye == HairDye.none ? hair : _nDark(Color.lerp(dye.top, dye.bottom, 0.5)!), thin, small);
            } else if (!_Face._covered.contains(look.hat) && f.hair == HairStyle.bald && !bare) {
              // La testa calva prende la luce.
              canvas.drawArc(Rect.fromCenter(center: Offset(b.cx - sx * b.r * 0.3, b.top + b.h * 0.1), width: b.w * 0.4, height: b.h * 0.12), pi * 1.1, pi * 0.6, false,
                  _nStroke(Color.lerp(skin, _nLamp, 0.6)!, thin * 2));
            }
            if (p.braids != null) hairToon(p.braids!, hair, d: 0.03);
          }
        case LookLayer.glasses:
          if (_nativeGlasses(look.glasses)) {
            _glasses(canvas, look, b, thin, ow);
          } else {
            oddGlasses();
          }
          // Dietro le lenti scure la luce negli occhi passa lo stesso.
          if (look.glasses.dark) eyeShine();
        case LookLayer.headFx:
          if (layered && look.headFx != HeadFx.none && !look.headFx.glows) _Deep.pic(canvas, ('headFx', look.headFx, g), (c) => _Deep.headFx(c, look.headFx, g));
        case LookLayer.held:
          if (!layered) break;
          final skinTone = skin;
          final sleeve = look.outfit.coat;
          if (look.heldBoth case final both?) {
            _Deep.pic(canvas, ('both', both, g, sleeve, skinTone), (c) => _Deep.heldBoth(c, both, g, sleeve: sleeve, skin: skinTone));
          } else {
            for (final hand in Hand.values) {
              final item = look.held(hand);
              if (item == HeldItem.none) continue;
              final side = hand == Hand.left ? -1.0 : 1.0;
              _Deep.pic(canvas, ('held', item, side, g, sleeve, skinTone, look.outfit.shirt), (c) => _Deep.held(c, item, g, side: side, sleeve: sleeve, skin: skinTone, cuff: look.outfit.shirt));
            }
          }
        case LookLayer.frontFx:
          if (layered && look.frontFx != FrontFx.none) _Deep.pic(canvas, ('front', look.frontFx, g), (c) => _Deep.frontFx(c, look.frontFx, g));
        case LookLayer.hat:
          if (p.hat != null) {
            _nativeHat(canvas, look, p, thin, toon);
          } else if (legacyHat) {
            oddHat();
          }
        case LookLayer.chest:
          _chest(canvas, look, b, thin);
          chest();
        case LookLayer.mouthProp:
          if (_nativeProp(look.accessory)) {
            _prop(canvas, look, b, thin);
          } else {
            oddProp();
          }
      }
    }
    if (gilt) {
      // The shine lies on the gold only: the statue's whole figure, or the
      // gold suit. Never a square of light over the background.
      const area = Rect.fromLTRB(0, 0, 1, 1);
      final shining = [
        if (gold) ...[p.back, p.neck, ...p.ears, p.face, p.front, p.braids, p.hat?.crown, p.hat?.brim],
        if (const {'gold_brocade', 'versalli_baroque'}.contains(look.outfit.id)) p.torso,
      ].whereType<Path>();
      canvas.save();
      canvas.clipPath(shining.fold(Path(), (all, path) => all..addPath(path, Offset.zero)));
      canvas.drawRect(
        area.inflate(0.5),
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = const LinearGradient(
            begin: Alignment(-1, -0.6),
            end: Alignment(1, 0.6),
            colors: [Color(0x00000000), Color(0x00000000), Color(0x55FFF2C0), Color(0x00000000), Color(0x00000000), Color(0x33FFF2C0), Color(0x00000000)],
            stops: [0, 0.3, 0.38, 0.46, 0.6, 0.66, 0.72],
          ).createShader(area),
      );
      canvas.restore();
    }
    LookPainter._style = previous;
  }

  // --- Gli abiti --------------------------------------------------------------

  static bool _nativeOutfit(CoatPattern p) => switch (p) {
        CoatPattern.plain ||
        CoatPattern.pinstripe ||
        CoatPattern.check ||
        CoatPattern.doubleBreasted ||
        CoatPattern.chalkstripe ||
        CoatPattern.windowpane ||
        CoatPattern.herringbone ||
        CoatPattern.sharkskin ||
        CoatPattern.tuxedo ||
        CoatPattern.velvet ||
        CoatPattern.trench ||
        CoatPattern.dress ||
        CoatPattern.blouse ||
        CoatPattern.jersey => true,
        _ => false,
      };

  static void _outfit(Canvas canvas, AvatarLook look, _NParts p, double thin, void Function(Path, Color, {double d, bool rim, bool line}) toon) {
    final b = p.b;
    final o = look.outfit;
    final torso = p.torso;
    switch (o.pattern) {
      case CoatPattern.jersey:
        // La maglia d'epoca: righe, fascia o due metà, il collo a V col
        // bordo e il tondo dello stemma.
        final team = CalcioTeam.of(o.id);
        final primary = team?.primary ?? o.coat;
        final second = team?.secondary ?? o.shirt;
        final trim = team?.trim ?? o.accent;
        toon(torso, primary, d: 0.1, line: false);
        canvas.save();
        canvas.clipPath(torso);
        switch (team?.kit) {
          case CalcioKit.stripes:
            for (var x = b.cx - 0.07 - 0.28; x < 1; x += 0.14) {
              canvas.drawRect(Rect.fromLTWH(x, 0, 0.07, 2), _nFill(second));
            }
          case CalcioKit.sash:
            canvas.drawPath(
              Path()
                ..moveTo(b.cx - 0.3, b.shoulderY - 0.05)
                ..lineTo(b.cx - 0.18, b.shoulderY - 0.05)
                ..lineTo(b.cx + 0.4, b.base)
                ..lineTo(b.cx + 0.28, b.base)
                ..close(),
              _nFill(second),
            );
          case CalcioKit.halves:
            canvas.drawRect(Rect.fromLTRB(b.cx, 0, 2, 2), _nFill(second));
          default:
            break;
        }
        canvas.drawPath(Path.combine(PathOperation.difference, torso, torso.shift(const Offset(-0.1, -0.08))), _nFill(const Color(0x88140A28)));
        canvas.restore();
        canvas.drawPath(torso, _nStroke(_nInk, thin));
        final collar = b.vee(depth: 0.1, width: 0.55);
        canvas.drawPath(collar, _nFill(Color.lerp(look.base.skin, _nNight, 0.35)!));
        canvas.drawPath(collar, _nStroke(_nInk, max(0.03, thin * 2.6)));
        canvas.drawPath(collar, _nStroke(trim, max(0.016, thin * 1.4)));
        final badge = Rect.fromLTWH(b.cx + 0.13, b.shoulderY + 0.07, 0.06, 0.07);
        canvas.drawOval(badge.inflate(0.008), _nFill(_nInk));
        canvas.drawOval(badge, _nFill(trim));
      case CoatPattern.dress || CoatPattern.blouse:
        toon(torso, o.coat, d: 0.1);
        final neckline = o.pattern == CoatPattern.blouse ? b.vee(depth: 0.08, width: 0.45) : b.scoop();
        canvas.drawPath(neckline, _nFill(Color.lerp(look.base.skin, _nNight, 0.3)!));
        canvas.drawPath(neckline, _nStroke(_nInk, thin));
        if (o.pattern == CoatPattern.blouse) {
          for (final s in [-1, 1]) {
            final collar = Path()
              ..moveTo(b.cx + s * b.w * b.neckW * 0.62, b.shoulderY - 0.02)
              ..lineTo(b.cx + s * 0.01, b.shoulderY + 0.085)
              ..lineTo(b.cx + s * 0.1, b.shoulderY + 0.07)
              ..close();
            toon(collar, o.shirt, d: 0.02, rim: false);
          }
        }
      default:
        toon(torso, o.coat, d: 0.1);
        canvas.save();
        canvas.clipPath(torso);
        final light = Color.lerp(o.coat, _nLamp, 0.25)!.withValues(alpha: 0.7);
        final dark = Color.lerp(o.coat, _nInk, 0.4)!.withValues(alpha: 0.7);
        final fine = max(0.004, thin * 0.6);
        switch (o.pattern) {
          case CoatPattern.pinstripe || CoatPattern.chalkstripe:
            final step = o.pattern == CoatPattern.chalkstripe ? 0.06 : 0.05;
            for (var x = 0.03; x < 1; x += step) {
              canvas.drawLine(Offset(x, b.shoulderY - 0.05), Offset(x + 0.012, 1.6), _nStroke(light, o.pattern == CoatPattern.chalkstripe ? fine * 1.6 : fine));
            }
          case CoatPattern.check || CoatPattern.windowpane:
            final step = o.pattern == CoatPattern.windowpane ? 0.09 : 0.05;
            for (var x = 0.0; x < 1; x += step) {
              canvas.drawLine(Offset(x, b.shoulderY - 0.05), Offset(x, 1.6), _nStroke(o.pattern == CoatPattern.check ? dark : light, fine));
            }
            for (var y = b.shoulderY; y < 1.6; y += step) {
              canvas.drawLine(Offset(0, y), Offset(1, y), _nStroke(o.pattern == CoatPattern.check ? dark : light, fine));
            }
          case CoatPattern.herringbone:
            for (var x = 0.0; x < 1; x += 0.04) {
              for (var y = b.shoulderY; y < 1.6; y += 0.04) {
                canvas.drawLine(Offset(x, y), Offset(x + 0.02, y + 0.02), _nStroke(dark, fine));
                canvas.drawLine(Offset(x + 0.02, y + 0.02), Offset(x + 0.04, y), _nStroke(dark, fine));
              }
            }
          case CoatPattern.sharkskin || CoatPattern.velvet:
            canvas.drawPath(
              Path.combine(PathOperation.difference, torso, torso.shift(const Offset(0.05, 0.05))),
              _nFill(Color.lerp(o.coat, _nLamp, o.pattern == CoatPattern.velvet ? 0.18 : 0.3)!.withValues(alpha: 0.6)),
            );
          case CoatPattern.trench:
            canvas.drawRect(Rect.fromLTRB(0, b.shoulderY + 0.2, 1, b.shoulderY + 0.24), _nFill(Color.lerp(o.coat, _nInk, 0.35)!));
          default:
            break;
        }
        canvas.restore();
        final vee = b.vee(depth: o.pattern == CoatPattern.doubleBreasted ? 0.14 : 0.18);
        canvas.drawPath(vee, _nFill(o.shirt));
        canvas.drawPath(vee, _nStroke(_nInk, thin));
        if (o.pattern == CoatPattern.doubleBreasted) {
          for (final s in [-1, 1]) {
            // Beside the bottom of the vee, where the jacket still shows.
            for (final dy in [0.1, 0.155]) {
              canvas.drawCircle(Offset(b.cx + s * 0.07, b.shoulderY + dy), 0.011, _nFill(Color.lerp(o.accent, _nInk, 0.2)!));
            }
          }
        }
    }
  }

  // --- La faccia --------------------------------------------------------------

  static void _faceDetails(Canvas canvas, AvatarLook look, _NB b, Color skin, double thin, bool small, bool bare) {
    final f = look.features;
    final mark = look.base.mark;
    canvas.save();
    canvas.clipPath(b.face());
    if (mark == FaceMark.stubble || mark == FaceMark.goatee || mark == FaceMark.horseshoe || mark == FaceMark.vandyke) {
      // L'ombra della barba: piena e netta sulla parte bassa della faccia.
      final shadow = Path()
        ..moveTo(b.cx - b.w, b.noseY + b.h * 0.02)
        ..quadraticBezierTo(b.cx, b.noseY + b.h * 0.08, b.cx + b.w, b.noseY + b.h * 0.02)
        ..lineTo(b.cx + b.w, 1)
        ..lineTo(b.cx - b.w, 1)
        ..close();
      canvas.drawPath(shadow, _nFill(Color.lerp(skin, f.hairColor.color, 0.45)!.withValues(alpha: mark == FaceMark.stubble ? 0.55 : 0.25)));
    }
    final rosy = f.detail == FaceDetail.rosyCheeks;
    if (rosy || (look.dame && !small)) {
      for (final s in [-1, 1]) {
        canvas.drawOval(Rect.fromCenter(center: Offset(b.cx + s * b.r * 0.55, b.noseY - b.h * 0.02), width: b.w * 0.16, height: b.h * 0.07),
            _nFill(const Color(0xFFC8505A).withValues(alpha: rosy ? 0.4 : 0.16)));
      }
    }
    switch (f.detail) {
      case FaceDetail.freckles:
        final rnd = Random(3);
        for (var i = 0; i < (small ? 6 : 12); i++) {
          final s = i.isEven ? -1 : 1;
          canvas.drawCircle(
            Offset(b.cx + s * b.r * (0.25 + rnd.nextDouble() * 0.45), b.noseY - b.h * 0.05 + rnd.nextDouble() * b.h * 0.07),
            small ? 0.008 : 0.006,
            _nFill(const Color(0xFF8E3A1C)),
          );
        }
      case FaceDetail.beautyMark:
        canvas.drawCircle(Offset(b.cx - b.r * 0.38, b.mouthY - b.h * 0.04), 0.008, _nFill(_nInk));
      case FaceDetail.mole:
        canvas.drawCircle(Offset(b.cx + b.r * 0.4, b.noseY - b.h * 0.03), 0.008, _nFill(const Color(0xFF3A2216)));
      case FaceDetail.scar:
        canvas.drawLine(Offset(b.cx - b.eyeDx - b.w * 0.04, b.browY - b.h * 0.06), Offset(b.cx - b.eyeDx + b.w * 0.02, b.eyeY + b.h * 0.06),
            _nStroke(Color.lerp(skin, const Color(0xFFFFF4E0), 0.5)!, thin * 1.6));
      case FaceDetail.cheekScar:
        canvas.drawLine(Offset(b.cx - b.r * 0.8, b.eyeY + b.h * 0.08), Offset(b.cx - b.r * 0.45, b.noseY + b.h * 0.06), _nStroke(const Color(0xFFC07A70), thin * 1.6));
      case FaceDetail.dimples:
        for (final s in [-1, 1]) {
          canvas.drawArc(Rect.fromCenter(center: Offset(b.cx + s * b.w * 0.2, b.mouthY), width: b.w * 0.04, height: b.h * 0.05), s < 0 ? pi * 0.6 : -pi * 0.4, pi * 0.8,
              false, _nStroke(Color.lerp(skin, _nInk, 0.5)!, thin));
        }
      case FaceDetail.none || FaceDetail.rosyCheeks:
        break;
    }
    if (f.age != FaceAge.none && !small) {
      final line = _nStroke(Color.lerp(skin, _nInk, 0.45)!.withValues(alpha: 0.8), thin * 0.9);
      for (final s in [-1, 1]) {
        canvas.drawPath(
          Path()
            ..moveTo(b.cx + s * b.w * 0.12, b.noseY - b.h * 0.01)
            ..quadraticBezierTo(b.cx + s * b.w * 0.2, b.noseY + b.h * 0.05, b.cx + s * b.w * 0.19, b.mouthY + b.h * 0.02),
          line,
        );
        if (f.age == FaceAge.deep) {
          canvas.drawLine(Offset(b.cx + s * (b.eyeDx + b.w * 0.13), b.eyeY - b.h * 0.01), Offset(b.cx + s * (b.eyeDx + b.w * 0.17), b.eyeY + b.h * 0.02), line);
        }
      }
      for (final dy in f.age == FaceAge.deep ? const [0.0, 0.035] : const [0.0]) {
        final y = b.top + b.h * (0.16 + dy);
        canvas.drawPath(Path()..moveTo(b.cx - b.w * 0.16, y)..quadraticBezierTo(b.cx, y - b.h * 0.02, b.cx + b.w * 0.16, y), line);
      }
    }
    canvas.restore();
  }

  static void _brimShadow(Canvas canvas, AvatarLook look, _NParts p, Color skin) {
    final b = p.b;
    final brimmed = const {
      AvatarHead.fedora, AvatarHead.pearlFedora, AvatarHead.borsalino, AvatarHead.wideBrim, AvatarHead.trilby, //
      AvatarHead.homburg, AvatarHead.panama, AvatarHead.porkPie, AvatarHead.boater, AvatarHead.topHat, AvatarHead.bowler, AvatarHead.coppola,
    }.contains(look.hat);
    if (!brimmed && look.hat != AvatarHead.cloche) return;
    canvas.save();
    canvas.clipPath(p.face);
    final low = brimmed ? b.eyeY + b.h * 0.03 : b.browY + b.h * 0.02;
    final band = Path()
      ..moveTo(0, 0)
      ..lineTo(1, 0)
      ..lineTo(1, low - 0.02)
      ..quadraticBezierTo(b.cx + 0.1, low + 0.02, b.cx - 0.05, low)
      ..quadraticBezierTo(b.cx - 0.15, low - 0.015, 0, low + 0.02)
      ..close();
    canvas.drawPath(band, _nFill(_nDark(skin).withValues(alpha: 0.92)));
    canvas.restore();
  }

  /// Larghezza, altezza, quanto salgono gli angoli esterni (uguale dai due
  /// lati), quanta palpebra scende.
  static ({double w, double h, double tilt, double cover}) _eye(EyeShape shape) => switch (shape) {
        EyeShape.almond => (w: 1.0, h: 1.0, tilt: 0.0, cover: 0.0),
        EyeShape.round => (w: 0.9, h: 1.5, tilt: 0.0, cover: 0.0),
        EyeShape.hooded => (w: 1.0, h: 0.95, tilt: 0.0, cover: 0.35),
        EyeShape.narrow => (w: 1.1, h: 0.6, tilt: 0.0, cover: 0.0),
        EyeShape.upturned => (w: 1.0, h: 0.95, tilt: 0.3, cover: 0.0),
        EyeShape.downturned => (w: 1.0, h: 0.95, tilt: -0.3, cover: 0.1),
        EyeShape.monolid => (w: 1.05, h: 0.75, tilt: 0.1, cover: 0.25),
        EyeShape.sleepy => (w: 1.0, h: 1.0, tilt: -0.05, cover: 0.5),
        EyeShape.wide => (w: 1.2, h: 1.15, tilt: 0.0, cover: 0.0),
        EyeShape.catEye => (w: 1.06, h: 0.85, tilt: 0.45, cover: 0.05),
        EyeShape.deepSet => (w: 0.95, h: 0.9, tilt: 0.0, cover: 0.15),
        EyeShape.doe => (w: 0.95, h: 1.7, tilt: -0.08, cover: 0.0),
      };

  static double _size(EyeSize size) => switch (size) {
        EyeSize.small => 0.82,
        EyeSize.medium => 1.0,
        EyeSize.large => 1.18,
        EyeSize.huge => 1.38,
      };

  /// Spessore, quanto scende l'attacco verso il naso, l'arco, quanto sale.
  static ({double t, double slope, double arch, double raise}) _brow(BrowShape shape) => switch (shape) {
        BrowShape.straight => (t: 1.0, slope: 0.5, arch: 0.0, raise: 0.0),
        BrowShape.arched => (t: 0.9, slope: 0.2, arch: 0.035, raise: 0.01),
        BrowShape.thick => (t: 1.4, slope: 0.6, arch: 0.0, raise: 0.0),
        BrowShape.thin => (t: 0.55, slope: 0.3, arch: 0.01, raise: 0.0),
        BrowShape.angled => (t: 1.0, slope: 0.9, arch: 0.02, raise: 0.0),
        BrowShape.rounded => (t: 0.9, slope: 0.3, arch: 0.03, raise: 0.0),
        BrowShape.bushy => (t: 1.6, slope: 0.45, arch: 0.01, raise: 0.0),
        BrowShape.pencil => (t: 0.4, slope: 0.15, arch: 0.04, raise: 0.015),
        BrowShape.sloped => (t: 0.9, slope: -0.35, arch: 0.0, raise: 0.0),
        BrowShape.furrowed => (t: 1.2, slope: 1.1, arch: 0.0, raise: -0.01),
        BrowShape.heavy => (t: 1.9, slope: 0.7, arch: 0.0, raise: -0.005),
        BrowShape.highArch => (t: 0.7, slope: 0.1, arch: 0.06, raise: 0.03),
      };

  static void _features(Canvas canvas, AvatarLook look, _NB b, Color skin, double thin, bool small, {required double glance, required bool shaded}) {
    final f = look.features;
    final e = _eye(f.eyes);
    final size = _size(f.eyeSize);
    final iris = Color.lerp(f.eyeColor.color, _nLamp, 0.15)!;
    final br = _brow(f.brows);
    final browColor = Color.lerp(look.base.mark == FaceMark.goldStatue ? const Color(0xFFB98A26) : f.hairColor.color, _nInk, look.dame ? 0.45 : 0.75)!;
    final g = glance.clamp(-1.0, 1.0) * b.w * 0.02;
    for (final s in [-1.0, 1.0]) {
      // Gli occhi stanno sempre sulla stessa riga e sono speculari.
      final at = Offset(b.cx + s * b.eyeDx, b.eyeY);
      final ew = b.w * 0.21 * e.w * size;
      final rise = e.tilt * b.h * 0.03;
      final inner = Offset(at.dx - s * ew / 2, at.dy);
      final outer = Offset(at.dx + s * ew / 2, at.dy - rise);
      if (look.dame) {
        final eh = ew * 0.38 * e.h;
        if (f.shadow != EyeShadow.none) {
          canvas.drawPath(
            Path()
              ..moveTo(inner.dx, inner.dy)
              ..quadraticBezierTo(at.dx, at.dy - eh * 3.0, outer.dx + s * ew * 0.12, outer.dy - eh * 0.4)
              ..quadraticBezierTo(at.dx, at.dy - eh * 1.2, inner.dx, inner.dy)
              ..close(),
            _nFill(f.shadow.color.withValues(alpha: f.shadow == EyeShadow.liner ? 0.0 : 0.75)),
          );
        }
        if (!look.glasses.dark) {
          // La mandorla nera a palpebra bassa, con la coda.
          final eye = Path()
            ..moveTo(inner.dx, inner.dy)
            ..quadraticBezierTo(at.dx, at.dy - eh * 1.3, outer.dx, outer.dy)
            ..quadraticBezierTo(at.dx, at.dy + eh * 0.9, inner.dx, inner.dy)
            ..close();
          canvas.drawPath(eye, _nFill(_nInk));
          final wing = Path()
            ..moveTo(outer.dx - s * ew * 0.2, outer.dy - eh * 0.55)
            ..lineTo(outer.dx + s * ew * 0.25, outer.dy - eh * (1.0 + e.tilt))
            ..lineTo(outer.dx, outer.dy + eh * 0.1)
            ..close();
          canvas.drawPath(wing, _nFill(_nInk));
          canvas.save();
          canvas.clipPath(eye);
          if (e.cover > 0) canvas.clipRect(Rect.fromLTRB(at.dx - ew, at.dy - eh * (0.9 - e.cover * 1.6), at.dx + ew, at.dy + eh * 2));
          canvas.drawCircle(Offset(at.dx + s * ew * 0.05 + g, at.dy + eh * 0.05), eh * 0.42 * (e.h > 1.3 ? 1.25 : 1.0), _nFill(iris));
          canvas.restore();
          if (!small) canvas.drawCircle(Offset(at.dx - ew * 0.05 + g, at.dy - eh * 0.1), max(eh * 0.2, 0.006), _nFill(const Color(0xFFFFFFFF)));
        }
        // Il sopracciglio sottile e alto.
        final brow = Path()
          ..moveTo(b.cx + s * b.w * 0.08, b.browY + b.h * 0.005 - br.raise * b.h)
          ..quadraticBezierTo(b.cx + s * b.w * 0.24, b.browY - b.h * (0.07 + br.arch) - br.raise * b.h, b.cx + s * b.w * 0.36, b.browY - br.raise * b.h);
        canvas.drawPath(brow, _nStroke(browColor, max(thin * 1.6, b.h * 0.018) * (0.6 + br.t * 0.4) * (small ? 1.3 : 1)));
      } else {
        final eh = ew * 0.32 * e.h;
        if (!look.glasses.dark) {
          // La fessura bianca con la pupilla dura.
          final eye = Path()
            ..moveTo(inner.dx, inner.dy)
            ..quadraticBezierTo(at.dx, at.dy - eh * 1.2, outer.dx, outer.dy)
            ..quadraticBezierTo(at.dx, at.dy + eh * 0.8, inner.dx, inner.dy)
            ..close();
          canvas.drawPath(eye, _nStroke(_nInk, thin * 1.4));
          canvas.drawPath(eye, _nFill(shaded ? const Color(0xFFFFF1CC) : const Color(0xFFF3EADC)));
          canvas.save();
          canvas.clipPath(eye);
          final pupil = Offset(at.dx + s * ew * 0.06 + g, at.dy);
          if (!small) canvas.drawCircle(pupil, eh * 1.0, _nFill(iris));
          canvas.drawCircle(pupil, eh * (small ? 0.75 : 0.55), _nFill(_nInk));
          if (e.cover > 0) {
            canvas.drawRect(Rect.fromLTRB(at.dx - ew, at.dy - eh * 2, at.dx + ew, at.dy - eh * (1.2 - e.cover * 2.2)), _nFill(Color.lerp(skin, _nNight, 0.4)!));
          }
          canvas.restore();
          canvas.drawPath(
            Path()
              ..moveTo(inner.dx, inner.dy)
              ..quadraticBezierTo(at.dx, at.dy - eh * 1.2 + e.cover * eh * 1.2, outer.dx, outer.dy),
            _nStroke(_nInk, thin * 1.6),
          );
        }
        // Il sopracciglio a cuneo, pesante: l'attacco scende verso il naso.
        final t = b.h * 0.05 * br.t * (small ? 1.2 : 1);
        final iy = b.browY + b.h * (0.02 + 0.05 * br.slope) - br.raise * b.h;
        final oy = b.browY - b.h * 0.025 - br.raise * b.h;
        final ix = b.cx + s * b.w * 0.05;
        final ox = b.cx + s * b.w * 0.37;
        final brow = Path()
          ..moveTo(ix, iy + t * 0.5)
          ..quadraticBezierTo((ix + ox) / 2, (iy + oy) / 2 - br.arch * b.h + t * 0.4, ox, oy + t * 0.25)
          ..lineTo(ox - s * b.w * 0.01, oy - t * 0.25)
          ..quadraticBezierTo((ix + ox) / 2, (iy + oy) / 2 - br.arch * b.h - t * 0.6, ix + s * b.w * 0.01, iy - t * 0.5)
          ..close();
        canvas.drawPath(brow, _nFill(browColor));
        if (f.brows == BrowShape.bushy && !small) {
          for (var i = 1; i < 6; i++) {
            final x = ix + (ox - ix) * i / 6;
            final y = iy + (oy - iy) * i / 6 - br.arch * b.h * sin(pi * i / 6);
            canvas.drawLine(Offset(x, y + t * 0.4), Offset(x + s * 0.008, y - t * 0.8), _nStroke(browColor, thin * 0.8));
          }
        }
      }
    }
    _nose(canvas, look, b, skin, thin, small);
    _mouth(canvas, look, b, skin, thin, small);
  }

  /// Dove stanno le pupille (come le disegna [_features]) e quanto sono grandi.
  static (List<Offset>, double) _pupils(AvatarLook look, _NB b, double glance) {
    final e = _eye(look.features.eyes);
    final ew = b.w * 0.21 * e.w * _size(look.features.eyeSize);
    final g = glance.clamp(-1.0, 1.0) * b.w * 0.02;
    final eh = ew * (look.dame ? 0.38 : 0.32) * e.h;
    final r = max(b.eyeDx * 0.2, eh * 0.7);
    return ([for (final s in [-1.0, 1.0]) Offset(b.cx + s * b.eyeDx + s * ew * (look.dame ? 0.05 : 0.06) + g, b.eyeY + (look.dame ? eh * 0.05 : 0))], r);
  }

  static void _nose(Canvas canvas, AvatarLook look, _NB b, Color skin, double thin, bool small) {
    final cx = b.cx, w = b.w, h = b.h;
    final ink = _nStroke(_nInk, thin * (small ? 1.8 : 1.4));
    final shade = _nFill(_nDark(skin).withValues(alpha: 0.85));
    // Il segno angolare dal lato in ombra: dove parte, quanto sporge la
    // punta, quanto è larga la base.
    final (start, tip, base, drop) = switch (look.features.nose) {
      NoseShape.straight => (0.04, 0.08, 0.03, 0.005),
      NoseShape.button => (0.1, 0.05, 0.03, 0.0),
      NoseShape.roman => (0.02, 0.1, 0.035, 0.01),
      NoseShape.broad => (0.05, 0.08, 0.07, 0.01),
      NoseShape.pointed => (0.03, 0.12, 0.02, 0.005),
      NoseShape.snub => (0.07, 0.06, 0.03, -0.015),
      NoseShape.wide => (0.05, 0.07, 0.09, 0.01),
      NoseShape.crooked => (0.03, 0.09, 0.035, 0.008),
      NoseShape.small => (0.1, 0.045, 0.02, 0.0),
      NoseShape.long => (0.0, 0.09, 0.03, 0.045),
      NoseShape.hooked => (0.02, 0.1, 0.03, 0.04),
      NoseShape.bulb => (0.06, 0.07, 0.04, 0.01),
    };
    final ty = b.noseY + h * drop;
    final top = Offset(cx + w * 0.02, b.eyeY + h * start);
    final point = Offset(cx + w * tip, ty + h * 0.005);
    final end = Offset(cx - w * base, ty + h * 0.02);
    final path = Path()..moveTo(top.dx, top.dy);
    switch (look.features.nose) {
      case NoseShape.roman || NoseShape.hooked:
        // La gobba, e il becco che piega in giù.
        path.quadraticBezierTo(cx + w * (tip + 0.04), b.eyeY + h * 0.12, point.dx, point.dy);
        if (look.features.nose == NoseShape.hooked) path.quadraticBezierTo(point.dx + w * 0.005, point.dy + h * 0.03, point.dx - w * 0.03, point.dy + h * 0.035);
      case NoseShape.crooked:
        path.lineTo(cx + w * 0.07, b.eyeY + h * 0.1);
        path.lineTo(point.dx, point.dy);
      case NoseShape.snub:
        path.quadraticBezierTo(cx + w * 0.02, ty - h * 0.03, point.dx, point.dy - h * 0.015);
      default:
        path.lineTo(point.dx, point.dy);
    }
    path.lineTo(end.dx, end.dy);
    // L'ombra sotto, dalla punta alla base.
    canvas.drawPath(Path()..moveTo(top.dx, top.dy)..lineTo(point.dx, point.dy)..lineTo(end.dx, end.dy)..close(), shade);
    canvas.drawPath(path, ink);
    switch (look.features.nose) {
      case NoseShape.button || NoseShape.bulb:
        final r = w * (look.features.nose == NoseShape.bulb ? 0.055 : 0.035);
        final c = Offset(cx + w * 0.01, ty - h * 0.005);
        canvas.drawCircle(c, r, _nFill(Color.lerp(skin, const Color(0xFFC8505A), 0.15)!));
        canvas.drawArc(Rect.fromCircle(center: c, radius: r), -pi * 0.1, pi * 1.2, false, ink);
      case NoseShape.broad || NoseShape.wide:
        for (final s in [-1.0, 1.0]) {
          canvas.drawArc(Rect.fromCenter(center: Offset(cx + s * w * base * 0.8, ty + h * 0.005), width: w * 0.05, height: h * 0.04), s < 0 ? pi * 0.5 : -pi * 0.2,
              pi * 0.9, false, ink);
        }
      default:
        if (!small) canvas.drawCircle(Offset(cx - w * base * 0.3, ty + h * 0.012), w * 0.008, _nFill(_nInk));
    }
  }

  static void _mouth(Canvas canvas, AvatarLook look, _NB b, Color skin, double thin, bool small) {
    final f = look.features;
    if (look.base.mark == FaceMark.fullBeard) {
      canvas.drawLine(Offset(b.cx - b.w * 0.08, b.mouthY + b.h * 0.01), Offset(b.cx + b.w * 0.08, b.mouthY + b.h * 0.005), _nStroke(_nInk, thin * 1.6));
      return;
    }
    final my = b.mouthY;
    final cx = b.cx, w = b.w, h = b.h;
    final lips = f.lipstick ?? (f.mouth == MouthShape.full || f.mouth == MouthShape.pout || f.mouth == MouthShape.cupid || look.dame
        ? Color.lerp(skin, const Color(0xFFB0303A), look.dame ? 0.45 : 0.3)
        : null);
    final (mw, lift, open) = switch (f.mouth) {
      MouthShape.neutral => (0.13, 0.0, 0.0),
      MouthShape.smile => (0.14, 0.035, 0.0),
      MouthShape.smirk => (0.13, 0.0, 0.0),
      MouthShape.full => (0.14, 0.01, 0.0),
      MouthShape.thin => (0.12, 0.0, 0.0),
      MouthShape.stern => (0.13, -0.03, 0.0),
      MouthShape.grin => (0.16, 0.04, 0.05),
      MouthShape.pout => (0.1, -0.005, 0.0),
      MouthShape.cupid => (0.12, 0.01, 0.0),
      MouthShape.wide => (0.18, 0.01, 0.0),
      MouthShape.lipstick => (0.14, 0.005, 0.0),
      MouthShape.lipstickSmile => (0.15, 0.03, 0.0),
    };
    final half = w * mw;
    final left = Offset(cx - half, my - h * lift);
    final right = Offset(cx + half, my - h * (lift + (f.mouth == MouthShape.smirk ? 0.04 : 0)));
    if (open > 0) {
      // Il ghigno: la bocca aperta, i denti.
      final grin = Path()
        ..moveTo(left.dx, left.dy)
        ..quadraticBezierTo(cx, my + h * 0.02, right.dx, right.dy)
        ..quadraticBezierTo(cx, my + h * (0.02 + open * 1.6), left.dx, left.dy)
        ..close();
      canvas.drawPath(grin, _nFill(const Color(0xFFF4EEE4)));
      canvas.drawPath(grin, _nStroke(_nInk, thin * 1.4));
      canvas.drawLine(Offset(cx - half * 0.7, my + h * 0.035), Offset(cx + half * 0.7, my + h * 0.035), _nStroke(_nInk, thin * 0.8));
      return;
    }
    if (lips != null) {
      final up = f.mouth == MouthShape.thin ? 0.015 : (f.mouth == MouthShape.full || f.mouth == MouthShape.pout ? 0.045 : 0.035);
      final bow = f.mouth == MouthShape.cupid ? 0.025 : 0.015;
      final p = Path()
        ..moveTo(left.dx, left.dy)
        ..lineTo(cx - half * 0.3, my - h * up)
        ..lineTo(cx, my - h * (up - bow))
        ..lineTo(cx + half * 0.3, my - h * up)
        ..lineTo(right.dx, right.dy)
        ..quadraticBezierTo(cx, my + h * (up * 2), left.dx, left.dy)
        ..close();
      canvas.drawPath(p, _nStroke(_nInk, thin * 1.2));
      canvas.drawPath(p, _nFill(lips));
      canvas.drawPath(Path()..moveTo(left.dx, left.dy)..quadraticBezierTo(cx, my + h * lift * 0.5, right.dx, right.dy), _nStroke(_nInk, thin));
      return;
    }
    canvas.drawPath(Path()..moveTo(left.dx, left.dy)..quadraticBezierTo(cx, my + h * lift * 0.8, right.dx, right.dy - h * 0.008), _nStroke(_nInk, thin * (f.mouth == MouthShape.thin ? 1.2 : 1.6)));
    if (!small) {
      canvas.drawLine(Offset(cx - half * 0.35, my + h * 0.055), Offset(cx + half * 0.35, my + h * 0.055), _nStroke(_nInk, thin));
    }
  }

  static void _beard(Canvas canvas, AvatarLook look, _NB b, Color hair, double thin, void Function(Path, Color, {double d, bool rim, bool line}) toon,
      void Function(String, _M, void Function(Canvas c), {AvatarLook? as}) pic) {
    final mark = look.base.mark;
    switch (mark) {
      case FaceMark.fullBeard:
        toon(b.beard(), hair, d: 0.06);
        final m = b.mustache();
        canvas.drawPath(m, _nStroke(_nInk, thin * 1.5));
        toon(m, Color.lerp(hair, _nLamp, 0.08)!, d: 0.02, line: false);
      case FaceMark.muttonChops:
        // I basettoni: la barba piena senza il mento, attaccata ai baffi.
        final chin = Path()..addRect(Rect.fromLTRB(b.cx - b.w * 0.17, b.mouthY - b.h * 0.035, b.cx + b.w * 0.17, 2));
        toon(Path.combine(PathOperation.difference, b.beard(), chin), hair, d: 0.05);
        final m = b.mustache();
        canvas.drawPath(m, _nStroke(_nInk, thin * 1.5));
        toon(m, hair, d: 0.02, line: false);
      case FaceMark.mustache || FaceMark.walrus || FaceMark.chevron || FaceMark.handlebar:
        final m = switch (mark) {
          FaceMark.walrus => b.mustache(scale: 1.15, drop: b.h * 0.02, flat: 1.3),
          FaceMark.chevron => b.mustache(scale: 1.05, flat: 0.7),
          _ => b.mustache(),
        };
        canvas.drawPath(m, _nStroke(_nInk, thin * 1.5));
        toon(m, hair, d: 0.02, line: false);
        if (mark == FaceMark.handlebar) {
          for (final s in [-1.0, 1.0]) {
            final tip = Offset(b.cx + s * b.w * 0.17, b.mouthY - b.h * 0.005);
            canvas.drawPath(
              Path()
                ..moveTo(tip.dx, tip.dy)
                ..quadraticBezierTo(tip.dx + s * b.w * 0.06, tip.dy, tip.dx + s * b.w * 0.05, tip.dy - b.h * 0.06),
              _nStroke(hair, thin * 2.2),
            );
          }
        }
      case FaceMark.pencil:
        for (final s in [-1.0, 1.0]) {
          canvas.drawLine(Offset(b.cx + s * b.w * 0.015, b.mouthY - b.h * 0.045), Offset(b.cx + s * b.w * 0.13, b.mouthY - b.h * 0.03), _nStroke(hair, thin * 2));
        }
      case FaceMark.clean || FaceMark.stubble || FaceMark.mimeFace:
        if (mark == FaceMark.mimeFace) pic('mark', mouthMap(b), (c) => _Oddities.mark(c, mark, hair));
      default:
        // Le barbe della bottega, portate sulla bocca di qui.
        pic('beard', mouthMap(b), (c) => LookPainter._beard(c, look));
    }
  }

  static void _hairDetail(Canvas canvas, AvatarLook look, _NParts p, Color hair, double thin, bool small) {
    final b = p.b;
    final front = p.front!;
    if (look.features.hairColor == HairColor.saltPepper || look.features.age == FaceAge.deep) {
      canvas.save();
      canvas.clipPath(front);
      for (final s in [-1, 1]) {
        canvas.drawRect(Rect.fromCenter(center: Offset(b.cx + s * b.r, b.cy - b.h * 0.02), width: b.w * 0.2, height: b.h * 0.14), _nFill(const Color(0xFF8E8A86)));
      }
      canvas.restore();
    }
    // Il colpo di lucido sui capelli.
    canvas.save();
    canvas.clipPath(front);
    final gloss = Path()
      ..moveTo(b.cx - b.r * 0.75, b.top + b.h * 0.12)
      ..quadraticBezierTo(b.cx - b.r * 0.2, b.top - b.h * 0.03, b.cx + b.r * 0.35, b.top + b.h * 0.0)
      ..quadraticBezierTo(b.cx - b.r * 0.2, b.top - b.h * 0.005, b.cx - b.r * 0.75, b.top + b.h * 0.1)
      ..close();
    canvas.drawPath(gloss, _nFill(Color.lerp(hair, _nLamp, hair.computeLuminance() < 0.03 ? 0.3 : 0.2)!));
    canvas.restore();
    if (look.features.hair == HairStyle.sidePart && !small) {
      canvas.drawLine(Offset(b.cx + b.r * 0.35, b.top - b.h * 0.02), Offset(b.cx + b.r * 0.5, b.top + b.h * 0.14), _nStroke(_nInk, thin));
    }
    if ((look.features.hair == HairStyle.middlePart || look.features.hair == HairStyle.long || look.features.hair == HairStyle.braids) && !small) {
      canvas.drawLine(Offset(b.cx, b.top - b.h * 0.04), Offset(b.cx, b.top + b.h * 0.06), _nStroke(_nInk, thin));
    }
  }

  // --- Occhiali, cappelli, oggetti --------------------------------------------

  static bool _nativeGlasses(AvatarGlasses g) => const {
        AvatarGlasses.none, AvatarGlasses.round, AvatarGlasses.shades, AvatarGlasses.monocle, AvatarGlasses.tortoise, //
        AvatarGlasses.goldRims, AvatarGlasses.pinceNez, AvatarGlasses.aviator, AvatarGlasses.browline, AvatarGlasses.catEye,
      }.contains(g);

  static void _glasses(Canvas canvas, AvatarLook look, _NB b, double thin, double ow) {
    final g = look.glasses;
    if (g == AvatarGlasses.none) return;
    if (!_nativeGlasses(g)) return;
    final y = b.eyeY;
    final dx = b.eyeDx;
    final rr = b.w * 0.13;
    final lw = thin * 1.2;
    void shape(Path p, Color c) {
      canvas.drawPath(p, _nStroke(_nInk, lw * 2.2));
      canvas.drawPath(p, _nFill(c));
    }

    switch (g) {
      case AvatarGlasses.round || AvatarGlasses.tortoise || AvatarGlasses.goldRims || AvatarGlasses.pinceNez:
        final frame = switch (g) {
          AvatarGlasses.tortoise => const Color(0xFF6A3A1C),
          AvatarGlasses.goldRims => const Color(0xFFD9B45A),
          _ => const Color(0xFF2A1C10),
        };
        final k = g == AvatarGlasses.pinceNez ? 0.8 : 1.0;
        for (final s in [-1, 1]) {
          final at = Offset(b.cx + s * dx, y);
          canvas.drawCircle(at, rr * k, _nFill(const Color(0x22CFE6FF)));
          canvas.drawCircle(at, rr * k, _nStroke(_nInk, lw * (g == AvatarGlasses.tortoise ? 3.4 : 2.8)));
          canvas.drawCircle(at, rr * k, _nStroke(frame, lw * (g == AvatarGlasses.tortoise ? 2.2 : (g == AvatarGlasses.goldRims ? 1.2 : 1.6))));
          canvas.drawArc(Rect.fromCircle(center: at, radius: rr * 0.7 * k), pi * 1.1, pi * 0.35, false, _nStroke(const Color(0x99FFFFFF), lw));
        }
        canvas.drawLine(Offset(b.cx - dx + rr * k, y - rr * 0.2), Offset(b.cx + dx - rr * k, y - rr * 0.2), _nStroke(frame, lw * 1.4));
      case AvatarGlasses.shades || AvatarGlasses.aviator || AvatarGlasses.catEye:
        for (final s in [-1, 1]) {
          final r = Rect.fromCenter(center: Offset(b.cx + s * dx, y + b.h * 0.005), width: rr * 2.3, height: rr * 1.5);
          final Path p;
          if (g == AvatarGlasses.catEye) {
            p = Path()
              ..moveTo(r.center.dx - s * r.width / 2, r.top + r.height * 0.3)
              ..lineTo(r.center.dx + s * r.width * 0.62, r.top - r.height * 0.15)
              ..quadraticBezierTo(r.center.dx + s * r.width * 0.45, r.bottom, r.center.dx, r.bottom)
              ..quadraticBezierTo(r.center.dx - s * r.width * 0.5, r.bottom, r.center.dx - s * r.width / 2, r.top + r.height * 0.3)
              ..close();
          } else {
            p = Path()
              ..addRRect(RRect.fromRectAndCorners(r,
                  topLeft: Radius.circular(rr * 0.3),
                  topRight: Radius.circular(rr * 0.3),
                  bottomLeft: Radius.circular(rr * (g == AvatarGlasses.aviator ? 1.2 : 0.9)),
                  bottomRight: Radius.circular(rr * (g == AvatarGlasses.aviator ? 1.2 : 0.9))));
          }
          final lens = switch (g) {
            AvatarGlasses.aviator => const Color(0xFF3A3020),
            AvatarGlasses.catEye => const Color(0x33FFFFFF),
            _ => const Color(0xFF0E0C10),
          };
          shape(p, lens);
          if (g == AvatarGlasses.aviator) canvas.drawPath(p, _nStroke(const Color(0xFFD9B45A), lw));
          if (g == AvatarGlasses.catEye) canvas.drawPath(p, _nStroke(look.outfit.accent, lw * 1.4));
          canvas.drawLine(r.topLeft.translate(rr * 0.4, rr * 0.35), r.topLeft.translate(rr * 0.9, rr * 0.35), _nStroke(const Color(0x88FFFFFF), lw * 1.2));
        }
        canvas.drawLine(Offset(b.cx - dx + rr * 1.1, y - rr * 0.3), Offset(b.cx + dx - rr * 1.1, y - rr * 0.3), _nStroke(const Color(0xFF0E0C10), lw * 2));
      case AvatarGlasses.browline:
        for (final s in [-1, 1]) {
          final at = Offset(b.cx + s * dx, y);
          canvas.drawCircle(at, rr, _nStroke(const Color(0xFF8A8478), lw));
          canvas.drawArc(Rect.fromCircle(center: at, radius: rr), pi * 1.05, pi * 0.9, false, _nStroke(_nInk, lw * 3.4));
        }
        canvas.drawLine(Offset(b.cx - dx + rr, y - rr * 0.4), Offset(b.cx + dx - rr, y - rr * 0.4), _nStroke(_nInk, lw * 2));
      case AvatarGlasses.monocle:
        final at = Offset(b.cx + dx, y);
        canvas.drawCircle(at, rr * 1.05, _nFill(const Color(0x22FFFFFF)));
        canvas.drawCircle(at, rr * 1.05, _nStroke(_nInk, lw * 3.4));
        canvas.drawCircle(at, rr * 1.05, _nStroke(const Color(0xFFD9B45A), lw * 2.2));
        final chain = Path()
          ..moveTo(at.dx + rr, at.dy + rr * 0.3)
          ..quadraticBezierTo(at.dx + rr * 1.6, b.cy + b.h * 0.4, at.dx + rr * 0.6, b.shoulderY + 0.06);
        canvas.drawPath(chain, _nStroke(const Color(0xFFD9B45A), lw * 0.9));
      default:
        break;
    }
  }

  static void _nativeHat(Canvas canvas, AvatarLook look, _NParts p, double thin, void Function(Path, Color, {double d, bool rim, bool line}) toon) {
    final hat = p.hat!;
    final (color, band) = _hatColors(look);
    final b = p.b;
    if (look.hat == AvatarHead.crown) {
      toon(hat.crown, color, d: 0.05);
      canvas.drawPath(hat.band!, _nFill(_nDark(color)));
      canvas.drawPath(hat.band!, _nStroke(_nInk, thin));
      canvas.drawPath(hat.brim!, _nStroke(_nInk, thin * 1.5));
      canvas.drawPath(hat.brim!, _nFill(band));
      return;
    }
    if (hat.brim != null && look.hat == AvatarHead.coppola) toon(hat.brim!, Color.lerp(color, _nInk, 0.15)!, d: 0.03);
    toon(hat.crown, color, d: 0.07);
    if (look.hat == AvatarHead.coppola && !LookPainter._style.small) {
      canvas.save();
      canvas.clipPath(hat.crown);
      for (var x = b.cx - b.w; x < b.cx + b.w; x += 0.035) {
        canvas.drawLine(Offset(x, b.brimY - b.h * 0.4), Offset(x + 0.02, b.brimY + 0.02), _nStroke(Color.lerp(color, _nInk, 0.35)!.withValues(alpha: 0.6), thin * 0.6));
      }
      canvas.restore();
    }
    if (hat.band != null) {
      canvas.drawPath(hat.band!, _nFill(band));
      canvas.drawPath(hat.band!, _nStroke(_nInk, thin));
    }
    if (hat.brim != null && look.hat != AvatarHead.coppola) {
      if (look.hat == AvatarHead.beret) {
        canvas.drawPath(hat.brim!, _nFill(Color.lerp(color, _nInk, 0.3)!));
      } else {
        toon(hat.brim!, color, d: 0.035);
      }
    }
    if (look.hat == AvatarHead.cloche) {
      final pin = Offset(b.cx + b.r * 0.72, b.browY - b.h * 0.09);
      canvas.drawCircle(pin, b.w * 0.065, _nFill(_nInk));
      canvas.drawCircle(pin, b.w * 0.05, _nFill(const Color(0xFFEDE6DA)));
    }
    if (look.hat == AvatarHead.pearlFedora) {
      for (var i = 0; i < 7; i++) {
        canvas.drawCircle(Offset(b.cx - b.r * 0.85 + i * b.r * 0.28, b.brimY - b.h * 0.04), b.w * 0.018, _nFill(const Color(0xFFF4EEE6)));
      }
    }
  }

  /// Da dove sale il fumo, nel quadrato del ritratto.
  static Offset smokeFrom(AvatarLook look, _NB b) {
    final a = look.accessory;
    if (a == AvatarAccessory.cigar || a == AvatarAccessory.cigarette) {
      final from = Offset(b.cx + b.w * 0.08, b.mouthY + b.h * 0.005);
      return from + Offset(b.w * (a == AvatarAccessory.cigar ? 0.36 : 0.34), b.h * (a == AvatarAccessory.cigar ? 0.08 : -0.03));
    }
    final old = switch (a) {
      AvatarAccessory.pipe => const Offset(0.125, -0.78),
      AvatarAccessory.cigaretteHolder => const Offset(0.245, -0.81),
      AvatarAccessory.baguetteCigar => const Offset(0.47, -0.69),
      _ => const Offset(0.145, -0.76),
    };
    return mouthMap(b).transform(old);
  }

  /// Il farfallino della demo: seta nera, il nodo appena più chiaro; quello a
  /// pois ha i pois.
  static void _bowTie(Canvas canvas, AvatarLook look, _NB b, double thin) {
    final y = b.shoulderY + 0.03;
    final p = Path()
      ..moveTo(b.cx, y)
      ..lineTo(b.cx - 0.07, y - 0.035)
      ..lineTo(b.cx - 0.07, y + 0.035)
      ..close()
      ..moveTo(b.cx, y)
      ..lineTo(b.cx + 0.07, y - 0.035)
      ..lineTo(b.cx + 0.07, y + 0.035)
      ..close();
    final polka = look.accessory == AvatarAccessory.polkaBowTie;
    final silk = polka ? const Color(0xFF7A1424) : const Color(0xFF151313);
    canvas.drawPath(p, _nStroke(_nInk, thin * 2.6));
    canvas.drawPath(p, _nFill(silk));
    if (polka) {
      canvas.save();
      canvas.clipPath(p);
      for (var x = b.cx - 0.065; x < b.cx + 0.07; x += 0.025) {
        for (final dy in [-0.015, 0.012]) {
          canvas.drawCircle(Offset(x, y + dy), 0.006, _nFill(const Color(0xFFF4EEE2)));
        }
      }
      canvas.restore();
    }
    canvas.drawCircle(Offset(b.cx, y), 0.018, _nFill(Color.lerp(silk, const Color(0xFFFFF4E0), 0.2)!));
  }

  /// Il vezzo davanti che il noir non disegna da sé: la pipa, il bocchino, le
  /// stramberie davanti al petto e le sciarpe e i trofei delle curve. Questi
  /// vengono dai pittori di sempre ([LookPainter._mouthProp]).
  static bool _nativeProp(AvatarAccessory a) =>
      !const {
        AvatarAccessory.pipe, AvatarAccessory.cigaretteHolder, AvatarAccessory.baguetteCigar, //
        AvatarAccessory.clownNose, AvatarAccessory.parrot, AvatarAccessory.rubberDuck, AvatarAccessory.accordion,
        AvatarAccessory.giantBowTie, AvatarAccessory.pigeon, AvatarAccessory.plungerSword,
      }.contains(a) &&
      CalcioTeam.of(a.name) == null;

  static bool _onChest(AvatarAccessory a) => const {
        AvatarAccessory.parrot, AvatarAccessory.rubberDuck, AvatarAccessory.accordion, AvatarAccessory.pigeon, AvatarAccessory.plungerSword, //
      }.contains(a);

  static void _prop(Canvas canvas, AvatarLook look, _NB b, double thin) {
    final a = look.accessory;
    if (!_nativeProp(a)) return;
    if (a != AvatarAccessory.cigar && a != AvatarAccessory.cigarette && a != AvatarAccessory.toothpick) return;
    final lw = thin * 1.2;
    final cigar = a == AvatarAccessory.cigar;
    final pick = a == AvatarAccessory.toothpick;
    final from = Offset(b.cx + b.w * 0.08, b.mouthY + b.h * 0.005);
    final to = from + Offset(b.w * (cigar ? 0.36 : (pick ? 0.26 : 0.34)), b.h * (cigar ? 0.08 : -0.03));
    // The toothpick keeps at least a pixel of wood at the table's size.
    final t = cigar ? b.w * 0.07 : (pick ? max(b.w * 0.02, thin * 1.1) : b.w * 0.035);
    canvas.drawLine(from, to, _nStroke(_nInk, t + lw * 2.2, cap: StrokeCap.butt));
    canvas.drawLine(from, to, _nStroke(cigar ? const Color(0xFF6B3E20) : (pick ? const Color(0xFFD8B87A) : const Color(0xFFF4EEE4)), t, cap: StrokeCap.butt));
    if (pick) return;
    if (cigar) canvas.drawLine(Offset.lerp(from, to, 0.3)!, Offset.lerp(from, to, 0.4)!, _nStroke(const Color(0xFFC9372C), t, cap: StrokeCap.butt));
    canvas.drawCircle(to, t * 0.55, _nFill(const Color(0xFFFF7A3B)));
    final smoke = Path()
      ..moveTo(to.dx, to.dy - t * 0.6)
      ..cubicTo(to.dx + 0.04, to.dy - 0.06, to.dx - 0.03, to.dy - 0.1, to.dx + 0.01, to.dy - 0.17)
      ..cubicTo(to.dx + 0.04, to.dy - 0.22, to.dx + 0.0, to.dy - 0.26, to.dx + 0.03, to.dy - 0.3);
    canvas.drawPath(smoke, _nStroke(const Color(0x55E8E2D8), max(lw * 1.6, 0.012)));
  }

  static void _chest(Canvas canvas, AvatarLook look, _NB b, double thin) {
    final white = look.accessory == AvatarAccessory.whiteCarnation;
    if (look.accessory == AvatarAccessory.carnation || white) {
      final at = Offset(b.cx - 0.2, b.shoulderY + 0.08);
      canvas.drawLine(at, at + const Offset(0.02, 0.06), _nStroke(const Color(0xFF2E5A2A), thin * 1.8));
      canvas.drawCircle(at, 0.036, _nFill(_nInk));
      for (var i = 0; i < 6; i++) {
        final a = i * pi / 3;
        canvas.drawCircle(at + Offset(cos(a), sin(a)) * 0.016, 0.016, _nFill(white ? const Color(0xFFF4EEE2) : const Color(0xFFC8102E)));
      }
      canvas.drawCircle(at, 0.015, _nFill(white ? const Color(0xFFD8D0C0) : const Color(0xFF8E0A20)));
    }
  }
}

/// Una mappa dai pittori di sempre al quadrato del ritratto: il punto
/// ([fx], [fy]) va in ([x0], [y0]) e tutto si scala di [k].
@immutable
class _M {
  final double x0;
  final double y0;
  final double k;
  final double fx;
  final double fy;

  const _M(this.x0, this.y0, this.k, this.fx, this.fy);

  Offset transform(Offset p) => Offset(x0 + (p.dx - fx) * k, y0 + (p.dy - fy) * k);
}

/// La tela dei pezzi strani: passa tutto alla tela vera, ma ogni forma
/// grande (un cappello, un'ala, una maschera, un costume) esce nel cartoon
/// noir: il colore pieno, l'ombra netta tagliata dalla parte lontana dalla
/// lampada, un filo di luce sul bordo acceso e la linea d'inchiostro
/// sottile. Le cose piccole (i puntini, le righe, i bottoni) restano come
/// sono. Si registra una volta in un'immagine vettoriale ([_Noir.piece]).
class _InkCanvas implements Canvas {
  final Canvas c;

  /// Il lato in ombra: 1 a destra.
  final double side;

  _InkCanvas(this.c, this.side);

  static const _big = 0.05;
  static const _cut = 0.05;
  static const _line = 0.009;

  /// La scala e l'inversa della trasformazione di adesso, dal quadrato del
  /// ritratto alle misure del pittore.
  (double, Offset Function(Offset)) _local() {
    final m = c.getTransform();
    final a = m[0], b = m[1], cc = m[4], d = m[5];
    final det = a * d - b * cc;
    final scale = sqrt((a * a + b * b).abs());
    Offset back(Offset v) => det == 0 ? v : Offset((d * v.dx - cc * v.dy) / det, (-b * v.dx + a * v.dy) / det);
    return (scale, back);
  }

  void _shape(Path path, Paint paint) {
    c.drawPath(path, paint);
    if (paint.style != PaintingStyle.fill || paint.blendMode != BlendMode.srcOver || paint.color.a < 0.6 || paint.maskFilter != null) return;
    final (scale, back) = _local();
    final box = path.getBounds();
    if (max(box.width, box.height) * scale < _big) return;
    final shadow = Path.combine(PathOperation.difference, path, path.shift(back(Offset(-_cut * side, -_cut * 0.8))));
    c.drawPath(shadow, Paint()..color = _nNight.withValues(alpha: 0.5));
    final lit = Path.combine(PathOperation.difference, path, path.shift(back(Offset(0.012 * side, 0.01))));
    c.drawPath(lit, Paint()..color = _nLamp.withValues(alpha: 0.3));
    c.drawPath(
      path,
      Paint()
        ..color = _nInk
        ..style = PaintingStyle.stroke
        ..strokeWidth = _line / max(scale, 1e-6)
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  void drawPath(Path path, Paint paint) => _shape(path, paint);
  @override
  void drawRect(Rect rect, Paint paint) => _shape(Path()..addRect(rect), paint);
  @override
  void drawRRect(RRect rrect, Paint paint) => _shape(Path()..addRRect(rrect), paint);
  @override
  void drawDRRect(RRect outer, RRect inner, Paint paint) => _shape(Path()
    ..fillType = PathFillType.evenOdd
    ..addRRect(outer)
    ..addRRect(inner), paint);
  @override
  void drawOval(Rect rect, Paint paint) => _shape(Path()..addOval(rect), paint);
  @override
  void drawCircle(Offset center, double radius, Paint paint) => _shape(Path()..addOval(Rect.fromCircle(center: center, radius: radius)), paint);
  @override
  void drawArc(Rect rect, double startAngle, double sweepAngle, bool useCenter, Paint paint) {
    if (!useCenter || paint.style != PaintingStyle.fill) {
      c.drawArc(rect, startAngle, sweepAngle, useCenter, paint);
      return;
    }
    _shape(
      Path()
        ..moveTo(rect.center.dx, rect.center.dy)
        ..arcTo(rect, startAngle, sweepAngle, false)
        ..close(),
      paint,
    );
  }

  @override
  void save() => c.save();
  @override
  void saveLayer(Rect? bounds, Paint paint) => c.saveLayer(bounds, paint);
  @override
  void restore() => c.restore();
  @override
  void restoreToCount(int count) => c.restoreToCount(count);
  @override
  int getSaveCount() => c.getSaveCount();
  @override
  void translate(double dx, double dy) => c.translate(dx, dy);
  @override
  void scale(double sx, [double? sy]) => c.scale(sx, sy);
  @override
  void rotate(double radians) => c.rotate(radians);
  @override
  void skew(double sx, double sy) => c.skew(sx, sy);
  @override
  void transform(Float64List matrix4) => c.transform(matrix4);
  @override
  Float64List getTransform() => c.getTransform();
  @override
  void clipRect(Rect rect, {ui.ClipOp clipOp = ui.ClipOp.intersect, bool doAntiAlias = true}) => c.clipRect(rect, clipOp: clipOp, doAntiAlias: doAntiAlias);
  @override
  void clipRRect(RRect rrect, {bool doAntiAlias = true}) => c.clipRRect(rrect, doAntiAlias: doAntiAlias);
  @override
  void clipRSuperellipse(RSuperellipse rsuperellipse, {bool doAntiAlias = true}) => c.clipRSuperellipse(rsuperellipse, doAntiAlias: doAntiAlias);
  @override
  void clipPath(Path path, {bool doAntiAlias = true}) => c.clipPath(path, doAntiAlias: doAntiAlias);
  @override
  Rect getLocalClipBounds() => c.getLocalClipBounds();
  @override
  Rect getDestinationClipBounds() => c.getDestinationClipBounds();
  @override
  void drawColor(Color color, BlendMode blendMode) => c.drawColor(color, blendMode);
  @override
  void drawLine(Offset p1, Offset p2, Paint paint) => c.drawLine(p1, p2, paint);
  @override
  void drawPaint(Paint paint) => c.drawPaint(paint);
  @override
  void drawRSuperellipse(RSuperellipse rsuperellipse, Paint paint) => c.drawRSuperellipse(rsuperellipse, paint);
  @override
  void drawImage(ui.Image image, Offset offset, Paint paint) => c.drawImage(image, offset, paint);
  @override
  void drawImageRect(ui.Image image, Rect src, Rect dst, Paint paint) => c.drawImageRect(image, src, dst, paint);
  @override
  void drawImageNine(ui.Image image, Rect center, Rect dst, Paint paint) => c.drawImageNine(image, center, dst, paint);
  @override
  void drawPicture(ui.Picture picture) => c.drawPicture(picture);
  @override
  void drawParagraph(ui.Paragraph paragraph, Offset offset) => c.drawParagraph(paragraph, offset);
  @override
  void drawPoints(ui.PointMode pointMode, List<Offset> points, Paint paint) => c.drawPoints(pointMode, points, paint);
  @override
  void drawRawPoints(ui.PointMode pointMode, Float32List points, Paint paint) => c.drawRawPoints(pointMode, points, paint);
  @override
  void drawVertices(ui.Vertices vertices, BlendMode blendMode, Paint paint) => c.drawVertices(vertices, blendMode, paint);
  @override
  void drawAtlas(ui.Image atlas, List<RSTransform> transforms, List<Rect> rects, List<Color>? colors, BlendMode? blendMode, Rect? cullRect, Paint paint) =>
      c.drawAtlas(atlas, transforms, rects, colors, blendMode, cullRect, paint);
  @override
  void drawRawAtlas(ui.Image atlas, Float32List rstTransforms, Float32List rects, Int32List? colors, BlendMode? blendMode, Rect? cullRect, Paint paint) =>
      c.drawRawAtlas(atlas, rstTransforms, rects, colors, blendMode, cullRect, paint);
  @override
  void drawShadow(Path path, Color color, double elevation, bool transparentOccluder) => c.drawShadow(path, color, elevation, transparentOccluder);
}
