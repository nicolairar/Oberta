part of 'look_painter.dart';

/// La testa: la forma, la pelle sotto la lampada, gli occhi, il naso, la
/// bocca e i capelli. Nelle stesse coordinate del busto di [LookPainter]:
/// la testa al centro in (0, -0.86), larga 0.32, gli occhi a -0.868 (a metà
/// tra la sommità e il mento), le orecchie tra le sopracciglia e il naso.
///
/// Lo stile è quello dei ritratti dei manifesti anni Quaranta: forme morbide,
/// una lampada calda da un lato e un filo di luce fredda sull'altro.
abstract final class _Face {
  static Color _dark(Color c, double t) => LookPainter._dark(c, t);
  static Color _bright(Color c, double t) => LookPainter._bright(c, t);
  static Color _shade(Color skin, double t) => LookPainter._skinShade(skin, t);
  static Color _light(Color skin, double t) => LookPainter._skinLight(skin, t);
  static const _ink = LookPainter.ink;

  /// La luce fredda che ritaglia il lato in ombra.
  static const _rim = Color(0xFFA9C1E0);

  /// Il rosa delle guance e delle labbra senza trucco.
  static const _flush = Color(0xFFC8505A);

  static const _eyeY = -0.868;
  static const _mouthY = -0.762;

  static Paint _fill(Color c) => Paint()..color = c;

  static double _pw(double x, double e) => pow(max(0.0, x), e).toDouble();

  static Paint _line(Color c, double width) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  /// Una macchia morbida: il colore al centro che sfuma ai bordi.
  static void _soft(Canvas canvas, Rect rect, Color color) {
    canvas.drawOval(
      rect,
      Paint()
        ..shader = RadialGradient(colors: [color, color.withValues(alpha: 0)]).createShader(rect),
    );
  }

  /// Una curva morbida che passa vicino a [points]; continua [path] se c'è.
  static Path _smooth(List<Offset> points, {Path? path}) {
    final p = path ?? (Path()..moveTo(points.first.dx, points.first.dy));
    if (path != null) p.lineTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length - 1; i++) {
      final m = Offset.lerp(points[i], points[i + 1], 0.5)!;
      p.quadraticBezierTo(points[i].dx, points[i].dy, m.dx, m.dy);
    }
    p.lineTo(points.last.dx, points.last.dy);
    return p;
  }

  // --- La forma -------------------------------------------------------------

  /// La sommità, la fronte, gli zigomi, l'angolo della mascella e il mento.
  static ({double top, double fw, double cw, double jw, double jy, double chin, double cr}) geometry(FaceShape shape) =>
      switch (shape) {
        FaceShape.oval => (top: -1.06, fw: 0.152, cw: 0.158, jw: 0.116, jy: -0.728, chin: -0.655, cr: 0.05),
        FaceShape.round => (top: -1.055, fw: 0.158, cw: 0.17, jw: 0.14, jy: -0.738, chin: -0.668, cr: 0.09),
        FaceShape.square => (top: -1.06, fw: 0.16, cw: 0.162, jw: 0.15, jy: -0.714, chin: -0.66, cr: 0.085),
        FaceShape.long => (top: -1.075, fw: 0.145, cw: 0.148, jw: 0.11, jy: -0.706, chin: -0.633, cr: 0.048),
        FaceShape.heart => (top: -1.06, fw: 0.164, cw: 0.163, jw: 0.1, jy: -0.734, chin: -0.652, cr: 0.03),
        FaceShape.diamond => (top: -1.066, fw: 0.138, cw: 0.168, jw: 0.108, jy: -0.73, chin: -0.652, cr: 0.036),
        FaceShape.pear => (top: -1.055, fw: 0.142, cw: 0.156, jw: 0.148, jy: -0.73, chin: -0.662, cr: 0.085),
        FaceShape.chiselled => (top: -1.062, fw: 0.155, cw: 0.16, jw: 0.142, jy: -0.708, chin: -0.648, cr: 0.058),
      };

  static final Map<FaceShape, Path> _paths = {};

  static Path path(FaceShape shape) => _paths[shape] ??= _build(shape);

  static Path _build(FaceShape shape) {
    final g = geometry(shape);
    final jawDrop = g.jy + (g.chin - g.jy) * 0.78;
    return Path()
      ..moveTo(0, g.top)
      ..cubicTo(0.62 * g.fw, g.top, g.fw, g.top + 0.045, g.fw, -0.935)
      ..cubicTo(g.fw, -0.895, g.cw, -0.875, g.cw, -0.832)
      ..cubicTo(g.cw, -0.785, g.jw + 0.014, g.jy - 0.022, g.jw, g.jy)
      ..cubicTo(g.jw - 0.008, jawDrop, g.cr, g.chin, 0, g.chin)
      ..cubicTo(-g.cr, g.chin, -(g.jw - 0.008), jawDrop, -g.jw, g.jy)
      ..cubicTo(-(g.jw + 0.014), g.jy - 0.022, -g.cw, -0.785, -g.cw, -0.832)
      ..cubicTo(-g.cw, -0.875, -g.fw, -0.895, -g.fw, -0.935)
      ..cubicTo(-g.fw, g.top + 0.045, -0.62 * g.fw, g.top, 0, g.top)
      ..close();
  }

  // --- Il collo -------------------------------------------------------------

  static void neck(Canvas canvas, Color skin, Offset light) {
    final neck = Path()
      ..moveTo(-0.066, -0.76)
      ..lineTo(0.066, -0.76)
      ..quadraticBezierTo(0.068, -0.64, 0.09, -0.58)
      ..lineTo(-0.09, -0.58)
      ..quadraticBezierTo(-0.068, -0.64, -0.066, -0.76)
      ..close();
    const bounds = Rect.fromLTRB(-0.09, -0.76, 0.09, -0.58);
    canvas.drawPath(
      neck,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment(light.dx.sign, 0),
          end: Alignment(-light.dx.sign, 0),
          colors: [_shade(skin, 0.1), _shade(skin, 0.22), _shade(skin, 0.42)],
        ).createShader(bounds),
    );
    canvas.save();
    canvas.clipPath(neck);
    // L'ombra che la mascella getta sul collo, e il filo freddo dal buio.
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_shade(skin, 0.7).withValues(alpha: 0.6), _shade(skin, 0.7).withValues(alpha: 0)],
        ).createShader(const Rect.fromLTRB(-0.09, -0.72, 0.09, -0.65)),
    );
    final far = -light.dx.sign;
    canvas.drawLine(Offset(far * 0.07, -0.7), Offset(far * 0.088, -0.58), _line(_rim.withValues(alpha: 0.3), 0.01));
    canvas.restore();
  }

  // --- Orecchie e pelle -------------------------------------------------------

  static void ears(Canvas canvas, AvatarLook look, Color skin, Offset light) {
    final g = geometry(look.features.shape);
    for (final side in [-1.0, 1.0]) {
      final lit = side.sign == light.dx.sign;
      final x = side * (g.cw - 0.004);
      final ear = Path()
        ..moveTo(x, -0.892)
        ..cubicTo(x + side * 0.03, -0.9, x + side * 0.038, -0.875, x + side * 0.032, -0.848)
        ..cubicTo(x + side * 0.028, -0.826, x + side * 0.016, -0.808, x, -0.81)
        ..close();
      canvas.drawPath(ear, _fill(_shade(skin, lit ? 0.12 : 0.48)));
      // La conca e l'elice.
      canvas.drawPath(
        Path()
          ..moveTo(x + side * 0.006, -0.882)
          ..cubicTo(x + side * 0.026, -0.884, x + side * 0.028, -0.86, x + side * 0.022, -0.842)
          ..quadraticBezierTo(x + side * 0.016, -0.83, x + side * 0.008, -0.832),
        _line(_shade(skin, lit ? 0.42 : 0.7), 0.0055),
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x + side * 0.01, -0.85), width: 0.012, height: 0.02),
        _fill(_shade(skin, lit ? 0.32 : 0.62).withValues(alpha: 0.7)),
      );
      if (!lit) canvas.drawPath(ear, _line(_rim.withValues(alpha: 0.28), 0.004));
    }
  }

  static void skin(Canvas canvas, AvatarLook look, Path face, Color skin, Offset light) {
    final f = look.features;
    final g = geometry(f.shape);
    final bounds = Rect.fromLTRB(-g.cw, g.top, g.cw, g.chin);
    final lx = light.dx.clamp(-1.0, 1.0);
    final far = lx <= 0 ? 1.0 : -1.0; // il lato in ombra
    canvas.drawPath(
      face,
      Paint()
        ..shader = RadialGradient(
          center: Alignment(lx * 0.42, -0.32),
          radius: 0.98,
          colors: [_light(skin, 0.18), _light(skin, 0.06), skin, _shade(skin, 0.14), _shade(skin, 0.32)],
          stops: const [0, 0.24, 0.52, 0.82, 1],
        ).createShader(bounds),
    );
    canvas.save();
    canvas.clipPath(face);
    // Il lato lontano dalla lampada: un'ombra un poco fredda.
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment(-far, 0),
          end: Alignment(far, 0),
          colors: [Colors.transparent, Colors.transparent, _shade(skin, 0.6).withValues(alpha: 0.28)],
          stops: const [0, 0.52, 1],
        ).createShader(bounds),
    );
    // Le orbite, appena incavate.
    for (final side in [-1.0, 1.0]) {
      _soft(canvas, Rect.fromCenter(center: Offset(side * 0.064, _eyeY - 0.006), width: 0.11, height: 0.07),
          _shade(skin, 0.55).withValues(alpha: f.eyes == EyeShape.deepSet ? 0.3 : 0.16));
    }
    // Gli zigomi: la luce sopra, l'incavo sotto, il rosa sulle guance.
    for (final side in [-1.0, 1.0]) {
      final lit = side != far;
      _soft(canvas, Rect.fromCenter(center: Offset(side * (g.cw - 0.05), -0.832), width: 0.08, height: 0.04),
          _light(skin, 0.5).withValues(alpha: lit ? 0.4 : 0.1));
      // L'incavo sotto lo zigomo: appena accennato, che non sembri un livido.
      _soft(canvas, Rect.fromCenter(center: Offset(side * (g.jw - 0.006), -0.778), width: 0.08, height: 0.07),
          _shade(skin, 0.5).withValues(alpha: lit ? 0.05 : 0.11));
      // Il rosa delle guance: sulle pelli scure un rosso più profondo e più
      // leggero, che non diventi una macchia viola.
      final rosy = f.detail == FaceDetail.rosyCheeks;
      final deep = (1 - skin.computeLuminance() * 2.4).clamp(0.0, 1.0);
      final flush = Color.lerp(_flush, const Color(0xFFA8433A), deep)!;
      _soft(canvas, Rect.fromCenter(center: Offset(side * 0.09, -0.802), width: rosy ? 0.08 : 0.07, height: rosy ? 0.05 : 0.04),
          flush.withValues(alpha: (rosy ? 0.42 : (look.dame ? 0.2 : 0.11)) * (1 - deep * 0.8)));
    }
    // La fronte prende la luce; la mascella e il mento affondano.
    _soft(canvas, Rect.fromCenter(center: Offset(lx * 0.035, -0.985), width: 0.2, height: 0.09), _light(skin, 0.55).withValues(alpha: 0.28));
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, _shade(skin, 0.6).withValues(alpha: 0.22)],
        ).createShader(Rect.fromLTRB(-g.cw, g.jy - 0.03, g.cw, g.chin)),
    );
    _soft(canvas, Rect.fromCenter(center: Offset(-lx * 0.008, g.chin + 0.026), width: 0.06, height: 0.025), _light(skin, 0.4).withValues(alpha: 0.3));
    // Il filo di luce fredda sul bordo in ombra.
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(far < 0 ? -1 : 0.02, -1.2, far < 0 ? -0.02 : 1, -0.6));
    canvas.drawPath(face, _line(_rim.withValues(alpha: 0.42), 0.014));
    canvas.restore();
    canvas.restore();
    // Il contorno, perché la testa si legga anche nella moneta piccola.
    canvas.drawPath(face, _line(_shade(skin, 0.8).withValues(alpha: 0.55), 0.005));
  }

  // --- Rughe e segni ----------------------------------------------------------

  static void age(Canvas canvas, AvatarLook look, Color skin) {
    final age = look.features.age;
    if (age == FaceAge.none) return;
    final deep = age == FaceAge.deep;
    final line = _line(_shade(skin, 0.5).withValues(alpha: deep ? 0.5 : 0.34), deep ? 0.0055 : 0.0045);
    final light = _line(_light(skin, 0.4).withValues(alpha: 0.3), 0.004);
    for (final side in [-1.0, 1.0]) {
      // Dal naso agli angoli della bocca, con il filo di luce accanto.
      final fold = Path()
        ..moveTo(side * 0.034, -0.812)
        ..quadraticBezierTo(side * 0.062, -0.792, side * 0.056, -0.748);
      canvas.drawPath(fold, line);
      canvas.drawPath(fold.shift(Offset(side * 0.006, 0)), light);
      if (deep) {
        // Le zampe di gallina e le borse sotto gli occhi.
        for (final dy in [-0.008, 0.0, 0.008]) {
          canvas.drawLine(Offset(side * 0.1, _eyeY + dy * 0.5), Offset(side * 0.12, _eyeY + dy * 1.6), line);
        }
        canvas.drawArc(
          Rect.fromCenter(center: Offset(side * 0.064, _eyeY + 0.016), width: 0.048, height: 0.018),
          0.15 * pi,
          0.7 * pi,
          false,
          line,
        );
        canvas.drawLine(Offset(side * 0.064, -0.728), Offset(side * 0.072, -0.7), line);
      }
    }
    for (final y in deep ? const [-0.99, -0.968] : const [-0.978]) {
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
      case FaceDetail.none || FaceDetail.rosyCheeks:
        break;
      case FaceDetail.freckles:
        final dot = _fill(Color.lerp(_shade(skin, 0.3), const Color(0xFF8A4A2A), 0.45)!.withValues(alpha: 0.6));
        const spots = [
          Offset(-0.104, -0.832), Offset(-0.088, -0.818), Offset(-0.072, -0.83), Offset(-0.11, -0.81), //
          Offset(-0.06, -0.814), Offset(-0.094, -0.8), Offset(0.104, -0.832), Offset(0.088, -0.818),
          Offset(0.072, -0.83), Offset(0.11, -0.81), Offset(0.06, -0.814), Offset(0.094, -0.8),
          Offset(-0.014, -0.838), Offset(0.012, -0.832), Offset(-0.004, -0.826),
        ];
        for (var i = 0; i < spots.length; i++) {
          canvas.drawCircle(spots[i], i.isEven ? 0.0042 : 0.0032, dot);
        }
      case FaceDetail.beautyMark:
        canvas.drawCircle(const Offset(-0.058, -0.784), 0.0068, _fill(const Color(0xFF241510)));
      case FaceDetail.mole:
        canvas.drawCircle(const Offset(0.05, -0.83), 0.0062, _fill(Color.lerp(_shade(skin, 0.6), const Color(0xFF3A2216), 0.5)!));
      case FaceDetail.scar:
        // Un taglio che attraversa il sopracciglio sinistro.
        final scar = _line(_light(skin, 0.45).withValues(alpha: 0.9), 0.008);
        canvas.drawLine(const Offset(-0.096, -0.94), const Offset(-0.078, -0.892), scar);
        canvas.drawLine(const Offset(-0.073, -0.878), const Offset(-0.067, -0.858), scar..strokeWidth = 0.006);
      case FaceDetail.cheekScar:
        final scar = _line(Color.lerp(_light(skin, 0.3), const Color(0xFFC07A70), 0.4)!.withValues(alpha: 0.85), 0.006);
        canvas.drawLine(const Offset(-0.122, -0.842), const Offset(-0.078, -0.79), scar);
        final stitch = _line(_shade(skin, 0.5).withValues(alpha: 0.6), 0.003);
        for (var t = 0.2; t < 0.9; t += 0.22) {
          final p = Offset.lerp(const Offset(-0.122, -0.842), const Offset(-0.078, -0.79), t)!;
          canvas.drawLine(p.translate(-0.006, 0.005), p.translate(0.006, -0.005), stitch);
        }
      case FaceDetail.dimples:
        for (final side in [-1.0, 1.0]) {
          canvas.drawArc(
            Rect.fromCenter(center: Offset(side * 0.066, _mouthY - 0.004), width: 0.014, height: 0.022),
            side < 0 ? pi * 0.6 : -pi * 0.4,
            pi * 0.8,
            false,
            _line(_shade(skin, 0.45).withValues(alpha: 0.55), 0.004),
          );
        }
    }
  }

  // --- Gli occhi ----------------------------------------------------------------

  /// Larghezza, altezza, inclinazione, quanta palpebra copre l'occhio, se c'è
  /// la piega, quanto è grande l'iride.
  static ({double w, double h, double tilt, double cover, bool crease, double iris}) _eye(EyeShape shape) => switch (shape) {
        EyeShape.almond => (w: 0.058, h: 0.024, tilt: 0.004, cover: 0.0, crease: true, iris: 1.0),
        EyeShape.round => (w: 0.054, h: 0.031, tilt: 0.0, cover: 0.0, crease: true, iris: 0.95),
        EyeShape.hooded => (w: 0.058, h: 0.025, tilt: 0.0, cover: 0.3, crease: false, iris: 1.0),
        EyeShape.narrow => (w: 0.062, h: 0.017, tilt: 0.002, cover: 0.0, crease: true, iris: 1.05),
        EyeShape.upturned => (w: 0.058, h: 0.023, tilt: 0.01, cover: 0.0, crease: true, iris: 1.0),
        EyeShape.downturned => (w: 0.058, h: 0.023, tilt: -0.008, cover: 0.1, crease: true, iris: 1.0),
        EyeShape.monolid => (w: 0.06, h: 0.02, tilt: 0.005, cover: 0.12, crease: false, iris: 1.05),
        EyeShape.sleepy => (w: 0.058, h: 0.026, tilt: -0.002, cover: 0.42, crease: true, iris: 1.0),
        EyeShape.wide => (w: 0.064, h: 0.03, tilt: 0.002, cover: 0.0, crease: true, iris: 0.92),
        EyeShape.catEye => (w: 0.06, h: 0.021, tilt: 0.013, cover: 0.05, crease: true, iris: 1.0),
        EyeShape.deepSet => (w: 0.056, h: 0.023, tilt: 0.0, cover: 0.16, crease: true, iris: 1.0),
        EyeShape.doe => (w: 0.056, h: 0.033, tilt: -0.002, cover: 0.0, crease: true, iris: 1.1),
      };

  static void eyes(Canvas canvas, AvatarLook look, CharacterPose pose, Color skin) {
    final f = look.features;
    final e = _eye(f.eyes);
    final glance = pose.glance.clamp(-1.0, 1.0);
    final made = f.shadow != EyeShadow.none;
    final lashes = look.dame || made;
    for (final side in [-1.0, 1.0]) {
      final c = Offset(side * 0.064, _eyeY);
      final inner = Offset(c.dx - side * e.w / 2, c.dy + 0.003);
      final outer = Offset(c.dx + side * e.w / 2, c.dy - e.tilt);
      final top = c.dy - e.h;
      final bottom = c.dy + e.h * 0.72;
      // L'ombretto, dalla palpebra verso il sopracciglio.
      if (made && f.shadow != EyeShadow.liner) {
        _soft(canvas, Rect.fromCenter(center: Offset(c.dx + side * 0.006, top - 0.002), width: e.w * 1.6, height: 0.05),
            f.shadow.color.withValues(alpha: 0.75));
      }
      if (look.glasses.dark) continue;
      final upper = Path()
        ..moveTo(inner.dx, inner.dy)
        ..cubicTo(inner.dx + side * e.w * 0.18, top, outer.dx - side * e.w * 0.28, top - e.tilt * 0.6, outer.dx, outer.dy);
      final eye = Path.from(upper)
        ..cubicTo(outer.dx - side * e.w * 0.22, bottom - e.tilt * 0.3, inner.dx + side * e.w * 0.32, bottom, inner.dx, inner.dy)
        ..close();
      canvas.drawPath(eye, _fill(const Color(0xFFEDE5D8)));
      canvas.save();
      canvas.clipPath(eye);
      // L'iride: più chiara in basso, dove la luce entra dall'occhio.
      final r = max(e.h * 0.66, 0.0128) * e.iris;
      final iris = Offset(c.dx + glance * 0.011, c.dy + e.h * 0.06);
      final col = f.eyeColor.color;
      canvas.drawCircle(
        iris,
        r,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(0, 0.35),
            colors: [_bright(col, 0.35), col, _dark(col, 0.6)],
            stops: const [0, 0.55, 1],
          ).createShader(Rect.fromCircle(center: iris, radius: r)),
      );
      canvas.drawCircle(iris, r, _line(_dark(col, 0.72), 0.003));
      canvas.drawCircle(iris, r * 0.44, _fill(_ink));
      // La palpebra getta la sua ombra sul bianco e sull'iride.
      canvas.drawRect(
        Rect.fromLTRB(c.dx - e.w, top - 0.01, c.dx + e.w, c.dy + e.h),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_ink.withValues(alpha: 0.5), _ink.withValues(alpha: 0)],
          ).createShader(Rect.fromLTRB(c.dx - e.w, top, c.dx + e.w, c.dy + 0.002)),
      );
      canvas.drawCircle(iris.translate(-r * 0.36, -r * 0.34), r * 0.3, _fill(Colors.white.withValues(alpha: 0.92)));
      canvas.drawCircle(iris.translate(r * 0.38, r * 0.3), r * 0.13, _fill(Colors.white.withValues(alpha: 0.55)));
      // La palpebra che scende: incappucciati, assonnati, monopalpebra.
      if (e.cover > 0) {
        final drop = e.cover * e.h * 1.5;
        canvas.drawPath(
          Path.from(upper.shift(Offset(0, drop)))
            ..lineTo(outer.dx, top - 0.03)
            ..lineTo(inner.dx, top - 0.03)
            ..close(),
          _fill(_shade(skin, 0.14)),
        );
      }
      canvas.restore();
      final lid = e.cover > 0 ? upper.shift(Offset(0, e.cover * e.h * 1.5)) : upper;
      // La rima delle ciglia, spessa; sotto, un filo sottile.
      canvas.drawPath(lid, _line(_ink.withValues(alpha: 0.92), lashes ? 0.0095 : 0.0072));
      canvas.drawPath(
        Path()
          ..moveTo(outer.dx, outer.dy)
          ..cubicTo(outer.dx - side * e.w * 0.22, bottom - e.tilt * 0.3, inner.dx + side * e.w * 0.32, bottom, inner.dx, inner.dy),
        _line(_shade(skin, 0.5).withValues(alpha: f.shadow == EyeShadow.liner || f.shadow == EyeShadow.smoky ? 0.8 : 0.4), 0.0035),
      );
      canvas.drawCircle(inner.translate(side * 0.003, 0), 0.0035, _fill(const Color(0xFFC07A78).withValues(alpha: 0.7)));
      // La coda: la matita, o l'occhio a mandorla da gatta.
      if (f.eyes == EyeShape.catEye || f.shadow == EyeShadow.liner || f.shadow == EyeShadow.smoky) {
        canvas.drawPath(
          Path()
            ..moveTo(outer.dx - side * 0.012, outer.dy - 0.004)
            ..quadraticBezierTo(outer.dx, outer.dy - 0.002, outer.dx + side * 0.016, outer.dy - 0.011),
          _line(_ink, 0.0065),
        );
      }
      if (lashes) {
        for (final t in const [0.62, 0.8, 0.96]) {
          final m = upper.computeMetrics().first;
          final p = m.getTangentForOffset(m.length * t)!.position;
          final len = 0.008 + t * 0.006;
          canvas.drawLine(p, p.translate(side * len * 0.7, -len), _line(_ink, 0.0035));
        }
      }
      // La piega della palpebra.
      if (e.crease) {
        canvas.drawPath(
          Path()
            ..moveTo(inner.dx + side * e.w * 0.12, top + e.h * 0.2)
            ..quadraticBezierTo(c.dx + side * 0.004, top - 0.014, outer.dx - side * e.w * 0.04, outer.dy - e.h * 0.85),
          _line(_shade(skin, 0.55).withValues(alpha: 0.45), 0.0042),
        );
      }
    }
  }

  // --- Le sopracciglia ------------------------------------------------------------

  /// L'attacco e la coda, quanto si alza, dove sta il colmo, lo spessore
  /// all'attacco e in coda, se fa l'angolo.
  static ({double iy, double oy, double lift, double peak, double ti, double to, bool sharp}) _brow(BrowShape shape) =>
      switch (shape) {
        BrowShape.straight => (iy: -0.907, oy: -0.906, lift: 0.006, peak: 0.55, ti: 0.016, to: 0.009, sharp: false),
        BrowShape.arched => (iy: -0.905, oy: -0.9, lift: 0.024, peak: 0.62, ti: 0.014, to: 0.006, sharp: false),
        BrowShape.thick => (iy: -0.906, oy: -0.904, lift: 0.01, peak: 0.55, ti: 0.024, to: 0.013, sharp: false),
        BrowShape.thin => (iy: -0.907, oy: -0.902, lift: 0.018, peak: 0.58, ti: 0.008, to: 0.004, sharp: false),
        BrowShape.angled => (iy: -0.905, oy: -0.899, lift: 0.024, peak: 0.66, ti: 0.016, to: 0.007, sharp: true),
        BrowShape.rounded => (iy: -0.905, oy: -0.9, lift: 0.02, peak: 0.5, ti: 0.013, to: 0.007, sharp: false),
        BrowShape.bushy => (iy: -0.905, oy: -0.904, lift: 0.012, peak: 0.5, ti: 0.028, to: 0.018, sharp: false),
        BrowShape.pencil => (iy: -0.909, oy: -0.9, lift: 0.03, peak: 0.55, ti: 0.006, to: 0.003, sharp: false),
        BrowShape.sloped => (iy: -0.915, oy: -0.893, lift: 0.01, peak: 0.4, ti: 0.015, to: 0.008, sharp: false),
        BrowShape.furrowed => (iy: -0.896, oy: -0.912, lift: 0.004, peak: 0.6, ti: 0.02, to: 0.01, sharp: false),
      };

  static Color _browColor(HairColor hair) => switch (hair) {
        HairColor.white || HairColor.grey || HairColor.platinum => _dark(hair.color, 0.32),
        HairColor.blonde || HairColor.strawberry => _dark(hair.color, 0.4),
        _ => _dark(hair.color, 0.3),
      };

  static void brows(Canvas canvas, AvatarLook look) {
    final f = look.features;
    final b = _brow(f.brows);
    final color = _browColor(f.hairColor);
    for (final side in [-1.0, 1.0]) {
      final top = <Offset>[];
      final under = <Offset>[];
      const n = 10;
      for (var i = 0; i <= n; i++) {
        final t = i / n;
        final x = side * (0.026 + 0.078 * t);
        final arch = b.sharp
            ? (t < b.peak ? t / b.peak : (1 - t) / (1 - b.peak))
            : sin(pi * (t < b.peak ? t / b.peak * 0.5 : 0.5 + (t - b.peak) / (1 - b.peak) * 0.5));
        final y = b.iy + (b.oy - b.iy) * t - b.lift * arch;
        // L'attacco è arrotondato, la coda va a punta.
        final thick = (b.ti + (b.to - b.ti) * t) * (t < 0.12 ? 0.6 + t / 0.12 * 0.4 : 1) * (t > 0.85 ? 1 - (t - 0.85) / 0.15 * 0.75 : 1);
        top.add(Offset(x, y - thick * 0.55));
        under.add(Offset(x, y + thick * 0.45));
      }
      final shape = _smooth(top);
      _smooth(under.reversed.toList(), path: shape);
      shape.close();
      canvas.drawPath(shape, _fill(color));
      // I peli, nelle sopracciglia folte.
      if (f.brows == BrowShape.bushy || f.brows == BrowShape.thick || f.brows == BrowShape.furrowed) {
        final hair = _line(_bright(color, 0.2).withValues(alpha: 0.5), 0.0028);
        for (var i = 1; i < n; i += 2) {
          canvas.drawLine(under[i], Offset.lerp(top[i], top[i + 1], 0.7)!, hair);
        }
      }
    }
  }

  // --- Il naso ----------------------------------------------------------------------

  /// La punta, la larghezza delle ali, la gobba, quanto pende di lato, la
  /// grandezza della punta.
  static ({double tip, double w, double bump, double skew, double r}) _nose(NoseShape shape) => switch (shape) {
        NoseShape.straight => (tip: -0.8, w: 0.042, bump: 0.0, skew: 0.0, r: 0.01),
        NoseShape.button => (tip: -0.808, w: 0.038, bump: -0.002, skew: 0.0, r: 0.013),
        NoseShape.roman => (tip: -0.795, w: 0.044, bump: 0.012, skew: 0.0, r: 0.009),
        NoseShape.broad => (tip: -0.803, w: 0.058, bump: 0.0, skew: 0.0, r: 0.013),
        NoseShape.pointed => (tip: -0.791, w: 0.034, bump: 0.003, skew: 0.0, r: 0.007),
        NoseShape.snub => (tip: -0.811, w: 0.04, bump: -0.005, skew: 0.0, r: 0.012),
        NoseShape.wide => (tip: -0.805, w: 0.066, bump: 0.0, skew: 0.0, r: 0.014),
        NoseShape.crooked => (tip: -0.8, w: 0.044, bump: 0.006, skew: 0.009, r: 0.01),
        NoseShape.small => (tip: -0.814, w: 0.032, bump: 0.0, skew: 0.0, r: 0.008),
        NoseShape.long => (tip: -0.785, w: 0.04, bump: 0.004, skew: 0.0, r: 0.009),
      };

  static void nose(Canvas canvas, AvatarLook look, Color skin, Offset light) {
    final n = _nose(look.features.nose);
    final sx = light.dx <= 0 ? 1.0 : -1.0; // il lato in ombra
    final tipX = n.skew;
    // Il fianco in ombra: dalla radice, lungo il dorso, fino all'ala.
    final side = Path()
      ..moveTo(sx * 0.016, -0.885)
      ..quadraticBezierTo(sx * (0.014 + n.bump), -0.845, tipX + sx * n.w * 0.42, n.tip - 0.012)
      ..lineTo(tipX + sx * n.w * 0.5, n.tip + 0.004)
      ..quadraticBezierTo(tipX + sx * n.w * 0.2, n.tip - 0.01, sx * 0.004, -0.88)
      ..close();
    canvas.drawPath(side, _fill(_shade(skin, 0.5).withValues(alpha: 0.3)));
    // Sotto la punta, l'ombra che cade sul labbro.
    _soft(canvas, Rect.fromCenter(center: Offset(tipX + sx * 0.004, n.tip + 0.012), width: n.w * 1.3, height: 0.024), _shade(skin, 0.6).withValues(alpha: 0.45));
    for (final s in [-1.0, 1.0]) {
      // Le ali e le narici.
      canvas.drawArc(
        Rect.fromCenter(center: Offset(tipX + s * n.w * 0.36, n.tip - 0.002), width: 0.022, height: 0.022),
        s < 0 ? pi * 0.55 : -pi * 0.55,
        s < 0 ? pi * 0.95 : -pi * 0.95,
        false,
        _line(_shade(skin, 0.5).withValues(alpha: s == sx ? 0.6 : 0.4), 0.0045),
      );
      canvas.save();
      canvas.translate(tipX + s * n.w * 0.2, n.tip + 0.005);
      canvas.rotate(s * 0.35);
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 0.013, height: 0.0065), _fill(_shade(skin, 0.72)));
      canvas.restore();
    }
    // La luce sul dorso e sulla punta.
    canvas.drawLine(Offset(-sx * 0.005, -0.868), Offset(tipX - sx * 0.006, n.tip - 0.02), _line(_light(skin, 0.35).withValues(alpha: 0.4), 0.006));
    _soft(canvas, Rect.fromCircle(center: Offset(tipX - sx * 0.004, n.tip - n.r * 0.6), radius: n.r * 1.4), _light(skin, 0.55).withValues(alpha: 0.7));
  }

  // --- La bocca ---------------------------------------------------------------------

  /// Mezza larghezza, labbro sopra e sotto, quanto salgono gli angoli, la
  /// fossetta dell'arco di Cupido, quanto sale l'angolo destro, quanto è aperta.
  static ({double w, double up, double low, double lift, double bow, double skew, double open}) _mouth(MouthShape shape) =>
      switch (shape) {
        MouthShape.neutral => (w: 0.038, up: 0.008, low: 0.011, lift: 0.0, bow: 0.004, skew: 0.0, open: 0.0),
        MouthShape.smile => (w: 0.044, up: 0.007, low: 0.011, lift: 0.011, bow: 0.003, skew: 0.0, open: 0.0),
        MouthShape.smirk => (w: 0.04, up: 0.007, low: 0.01, lift: 0.0, bow: 0.003, skew: 0.013, open: 0.0),
        MouthShape.full => (w: 0.042, up: 0.012, low: 0.016, lift: 0.002, bow: 0.006, skew: 0.0, open: 0.0),
        MouthShape.thin => (w: 0.037, up: 0.0035, low: 0.006, lift: -0.001, bow: 0.0015, skew: 0.0, open: 0.0),
        MouthShape.stern => (w: 0.039, up: 0.006, low: 0.009, lift: -0.007, bow: 0.002, skew: 0.0, open: 0.0),
        MouthShape.grin => (w: 0.048, up: 0.007, low: 0.011, lift: 0.013, bow: 0.003, skew: 0.0, open: 0.013),
        MouthShape.pout => (w: 0.033, up: 0.011, low: 0.016, lift: -0.002, bow: 0.006, skew: 0.0, open: 0.0),
        MouthShape.cupid => (w: 0.039, up: 0.011, low: 0.013, lift: 0.003, bow: 0.009, skew: 0.0, open: 0.0),
        MouthShape.wide => (w: 0.052, up: 0.007, low: 0.011, lift: 0.004, bow: 0.003, skew: 0.0, open: 0.0),
        MouthShape.lipstick => (w: 0.04, up: 0.011, low: 0.014, lift: 0.003, bow: 0.008, skew: 0.0, open: 0.0),
        MouthShape.lipstickSmile => (w: 0.045, up: 0.01, low: 0.013, lift: 0.011, bow: 0.007, skew: 0.0, open: 0.0),
      };

  static void mouth(Canvas canvas, AvatarLook look, Color skin) {
    final f = look.features;
    final m = _mouth(f.mouth);
    const y = _mouthY;
    final paint = f.lipstick;
    // Le labbra nude sono la pelle un poco più rossa: sulle pelli scure il rosa
    // si spegne, se no sembra rossetto.
    final deep = (1 - skin.computeLuminance() * 2.4).clamp(0.0, 1.0);
    final lip = paint ?? Color.lerp(_shade(skin, 0.18 + deep * 0.1), _flush, (look.dame ? 0.42 : 0.3) * (1 - deep * 0.55))!;
    double mid(double t) => y - m.lift * t * t - m.skew * _pw((t + 1) / 2, 2);
    double gap(double t) => m.open / 2 * (1 - t * t);
    const n = 12;
    final ts = [for (var i = 0; i <= n; i++) -1 + 2 * i / n];
    Offset at(double t, double dy) => Offset(t * m.w, dy);
    // L'ombra sotto il labbro inferiore, e il solco sopra quello superiore.
    _soft(canvas, Rect.fromCenter(center: Offset(0, y + m.low + 0.012), width: 0.05, height: 0.016), _ink.withValues(alpha: 0.22));
    canvas.drawLine(Offset(0, y - m.up - 0.018), Offset(0, y - m.up - 0.004), _line(_shade(skin, 0.4).withValues(alpha: 0.18), 0.008));
    // Il labbro inferiore.
    final lower = _smooth([for (final t in ts) at(t, mid(t) + gap(t))]);
    _smooth([for (final t in ts.reversed) at(t, mid(t) + m.low * _pw(1 - t * t, 0.7))], path: lower);
    lower.close();
    canvas.drawPath(
      lower,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_dark(lip, 0.15), lip, _dark(lip, 0.2)],
        ).createShader(Rect.fromLTRB(-m.w, y, m.w, y + m.low + 0.004)),
    );
    // La bocca aperta: il buio e i denti.
    if (m.open > 0) {
      final inside = _smooth([for (final t in ts) at(t, mid(t) - gap(t))]);
      _smooth([for (final t in ts.reversed) at(t, mid(t) + gap(t))], path: inside);
      inside.close();
      canvas.drawPath(inside, _fill(const Color(0xFF3A1212)));
      canvas.save();
      canvas.clipPath(inside);
      canvas.drawRect(Rect.fromLTRB(-m.w, y - 0.04, m.w, mid(0) + 0.001), _fill(const Color(0xFFF0E9DC)));
      canvas.restore();
    }
    // Il labbro superiore, con l'arco di Cupido.
    final upper = _smooth([
      for (final t in ts) at(t, mid(t) - m.up * _pw(1 - t * t, 0.5) + m.bow * exp(-_pw(t / 0.2, 2))),
    ]);
    _smooth([for (final t in ts.reversed) at(t, mid(t) - gap(t))], path: upper);
    upper.close();
    canvas.drawPath(upper, _fill(_dark(lip, paint != null ? 0.12 : 0.2)));
    // La linea tra le labbra e gli angoli.
    final seam = _smooth([for (final t in ts) at(t, mid(t) - gap(t))]);
    canvas.drawPath(seam, _line(_dark(paint ?? skin, paint != null ? 0.6 : 0.72), 0.0048));
    // Il lucido sul labbro di sotto.
    _soft(
      canvas,
      Rect.fromCenter(center: Offset(-0.008, mid(0) + m.low * 0.55), width: m.w * 0.9, height: m.low * 0.7),
      Colors.white.withValues(alpha: paint != null ? 0.45 : 0.25),
    );
    // Quando si sorride, la guancia fa la piega.
    if (m.lift > 0.008 || m.skew > 0) {
      for (final s in [-1.0, 1.0]) {
        if (m.lift <= 0.008 && s < 0) continue;
        final corner = Offset(s * m.w, mid(s));
        canvas.drawArc(
          Rect.fromCenter(center: corner.translate(s * 0.002, -0.002), width: 0.016, height: 0.022),
          s < 0 ? pi * 0.65 : -pi * 0.35,
          pi * 0.7,
          false,
          _line(_shade(skin, 0.5).withValues(alpha: 0.5), 0.004),
        );
      }
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
      begin: const Alignment(-0.8, -1),
      end: const Alignment(0.7, 1),
      colors: [_bright(c, 0.2), c, _dark(c, 0.45)],
      stops: const [0, 0.42, 1],
    ).createShader(const Rect.fromLTRB(-0.25, -1.2, 0.25, -0.6));

  /// Il riflesso: caldo sui capelli chiari, freddo e netto su quelli scuri.
  static Color _sheen(Color c) {
    final dark = c.computeLuminance() < 0.05;
    return Color.lerp(_bright(c, dark ? 0.5 : 0.6), _rim, dark ? 0.45 : 0.1)!.withValues(alpha: dark ? 0.5 : 0.55);
  }

  /// Riempie una ciocca, con il bordo scuro che la stacca dalla fronte.
  static void _mass(Canvas canvas, Path path, Color c) {
    canvas.drawPath(path, _hairPaint(c));
    canvas.drawPath(path, _line(_dark(c, 0.55).withValues(alpha: 0.55), 0.0045));
  }

  /// I fili e i riflessi, dentro la ciocca [clip].
  static void _comb(Canvas canvas, Path clip, Color c, {List<Path> strands = const [], List<Path> shine = const [], double shineWidth = 0.014}) {
    canvas.save();
    canvas.clipPath(clip);
    final dark = _line(_dark(c, 0.5).withValues(alpha: 0.5), 0.0035);
    for (final s in strands) {
      canvas.drawPath(s, dark);
    }
    final bright = _line(_sheen(c), shineWidth);
    for (final s in shine) {
      canvas.drawPath(s, bright);
    }
    canvas.restore();
  }

  static Path _q(Offset a, Offset ctrl, Offset b) => Path()
    ..moveTo(a.dx, a.dy)
    ..quadraticBezierTo(ctrl.dx, ctrl.dy, b.dx, b.dy);

  /// Fili che vanno da una curva all'altra, come i denti di un pettine.
  static List<Path> _flow(int n, Offset Function(double t) from, Offset Function(double t) ctrl, Offset Function(double t) to) => [
        for (var i = 0; i < n; i++)
          () {
            final t = (i + 0.5) / n;
            return _q(from(t), ctrl(t), to(t));
          }(),
      ];

  /// La calotta: dalla tempia sinistra sopra la testa alla destra, alta [top].
  static Path _shell({double top = -1.1, double side = 0.17, double y = -0.86, double bulge = 0.185}) => Path()
    ..moveTo(-side, y)
    ..cubicTo(-bulge, -0.98, -bulge * 0.8, top, 0, top)
    ..cubicTo(bulge * 0.8, top, bulge, -0.98, side, y);

  /// I capelli sono disegnati sulla testa ovale; [fit] li porta sulla testa
  /// vera: larghi quanto la fronte e le tempie, con l'attaccatura alla stessa
  /// distanza dalla sommità. Così una testa tonda non spunta dai lati e una
  /// lunga non resta scoperta in cima.
  static void fit(Canvas canvas, FaceShape shape) {
    final g = geometry(shape);
    final kx = (g.fw + g.cw) / 0.31;
    final ky = (-0.8 - g.top) / 0.26;
    canvas.translate(0, -0.8);
    canvas.scale(kx, ky);
    canvas.translate(0, 0.8);
  }

  static void hairBack(Canvas canvas, AvatarLook look, Paint? halo) {
    canvas.save();
    fit(canvas, look.features.shape);
    _hairBack(canvas, look, halo);
    canvas.restore();
  }

  static void hairFront(Canvas canvas, AvatarLook look) {
    canvas.save();
    fit(canvas, look.features.shape);
    _hairFront(canvas, look);
    canvas.restore();
  }

  static void _hairBack(Canvas canvas, AvatarLook look, Paint? halo) {
    if (_covered.contains(look.hat)) return;
    final c = look.features.hairColor.color;
    final paint = halo ?? _fill(_dark(c, 0.32));
    final style = look.features.hair;
    final full = _full(look);
    final top = full ? -1.08 : -0.97;
    switch (style) {
      case HairStyle.bob:
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(-0.212, top, 0.212, -0.7), const Radius.circular(0.14)), paint);
      case HairStyle.pageboy:
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(-0.208, top, 0.208, -0.72), const Radius.circular(0.12)), paint);
      case HairStyle.long:
        canvas.drawPath(_longBack(top), paint);
      case HairStyle.wavy:
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(-0.205, top, 0.205, -0.76), const Radius.circular(0.12)), paint);
        for (final x in const [-0.17, -0.11, 0.11, 0.17]) {
          canvas.drawCircle(Offset(x, -0.765), 0.036, paint);
        }
      case HairStyle.victoryRolls || HairStyle.pinCurls:
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(-0.21, top, 0.21, -0.7), const Radius.circular(0.12)), paint);
        for (final x in const [-0.18, -0.12, 0.12, 0.18]) {
          canvas.drawCircle(Offset(x, -0.69), 0.04, paint);
        }
      case HairStyle.curly:
        if (full) {
          for (var a = 0.85; a <= 2.15; a += 0.13) {
            canvas.drawCircle(Offset(cos(a * pi) * 0.178, -0.9 - sin(a * pi) * 0.172), 0.05, paint);
          }
        } else {
          canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(-0.205, -0.97, 0.205, -0.76), const Radius.circular(0.1)), paint);
        }
      case HairStyle.afro:
        if (full) {
          canvas.drawCircle(const Offset(0, -0.95), 0.25, paint);
        } else {
          for (final side in [-1.0, 1.0]) {
            canvas.drawCircle(Offset(side * 0.19, -0.88), 0.075, paint);
          }
        }
      case HairStyle.coils:
        if (full) {
          canvas.drawOval(Rect.fromCenter(center: const Offset(0, -0.97), width: 0.42, height: 0.36), paint);
        } else {
          for (final side in [-1.0, 1.0]) {
            canvas.drawCircle(Offset(side * 0.18, -0.9), 0.05, paint);
          }
        }
      case HairStyle.bun:
        if (full) canvas.drawCircle(const Offset(0, -1.1), 0.075, paint);
      case HairStyle.updo:
        if (full) canvas.drawOval(Rect.fromCenter(center: const Offset(0, -1.12), width: 0.2, height: 0.13), paint);
      case HairStyle.fingerWaves:
        if (full) canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(-0.19, -1.08, 0.19, -0.8), const Radius.circular(0.12)), paint);
      case HairStyle.ponytail:
        final tail = Path()
          ..moveTo(0.08, -1.08)
          ..cubicTo(0.26, -1.08, 0.27, -0.9, 0.23, -0.8)
          ..cubicTo(0.21, -0.74, 0.2, -0.7, 0.21, -0.64)
          ..cubicTo(0.17, -0.7, 0.16, -0.82, 0.17, -0.9)
          ..quadraticBezierTo(0.16, -1.0, 0.08, -1.02)
          ..close();
        canvas.drawPath(tail, halo ?? _hairPaint(c));
        if (halo == null) {
          _comb(canvas, tail, c, strands: [
            _q(const Offset(0.12, -1.06), const Offset(0.24, -1.0), const Offset(0.2, -0.7)),
            _q(const Offset(0.1, -1.04), const Offset(0.21, -0.95), const Offset(0.19, -0.74)),
          ], shine: [
            _q(const Offset(0.16, -1.06), const Offset(0.25, -0.98), const Offset(0.225, -0.84)),
          ], shineWidth: 0.01);
        }
      case HairStyle.bald ||
            HairStyle.slicked ||
            HairStyle.sidePart ||
            HairStyle.crewCut ||
            HairStyle.pompadour ||
            HairStyle.quiff ||
            HairStyle.ducktail ||
            HairStyle.flatTop ||
            HairStyle.middlePart ||
            HairStyle.receding ||
            HairStyle.braids:
        break;
    }
  }

  static Path _longBack(double top) => Path()
    ..moveTo(-0.2, -0.95)
    ..quadraticBezierTo(-0.22, top - 0.02, 0, top - 0.01)
    ..quadraticBezierTo(0.22, top - 0.02, 0.2, -0.95)
    ..lineTo(0.218, -0.6)
    ..quadraticBezierTo(0.15, -0.56, 0.1, -0.6)
    ..lineTo(-0.1, -0.6)
    ..quadraticBezierTo(-0.15, -0.56, -0.218, -0.6)
    ..close();

  /// Le due trecce sulle spalle.
  static void _braids(Canvas canvas, Color c) {
    for (final side in [-1.0, 1.0]) {
      for (var i = 0; i < 6; i++) {
        final y = -0.84 + i * 0.042;
        final x = side * (0.168 + i * 0.004);
        final r = 0.028 - i * 0.0015;
        final lobe = Rect.fromCenter(center: Offset(x + (i.isEven ? 0.006 : -0.006), y), width: r * 1.7, height: r * 1.9);
        canvas.drawOval(lobe, _hairPaint(c));
        canvas.drawOval(lobe, _line(_dark(c, 0.55).withValues(alpha: 0.6), 0.004));
        canvas.drawArc(lobe.deflate(r * 0.3), pi * 1.1, pi * 0.6, false, _line(_sheen(c), 0.006));
      }
      canvas.drawLine(Offset(side * 0.19, -0.6), Offset(side * 0.194, -0.57), _line(_dark(c, 0.3), 0.012));
      canvas.drawCircle(Offset(side * 0.19, -0.608), 0.008, _fill(const Color(0xFFB0303A)));
    }
  }

  /// Le ciocche che scendono ai lati del viso fino a [bottom].
  static Path _curtain(double side, {double bottom = -0.74, double width = 0.04, double start = -0.97}) => Path()
    ..moveTo(side * 0.12, start)
    ..quadraticBezierTo(side * 0.205, start + 0.02, side * (0.17 + width), bottom)
    ..quadraticBezierTo(side * (0.15 + width * 0.6), bottom + 0.015, side * 0.165, bottom - 0.01)
    ..quadraticBezierTo(side * 0.158, -0.88, side * 0.11, start + 0.02)
    ..close();

  static void _hairFront(Canvas canvas, AvatarLook look) {
    if (_covered.contains(look.hat)) return;
    final c = look.features.hairColor.color;
    final style = look.features.hair;
    if (!_full(look)) {
      _underHat(canvas, style, c);
      return;
    }
    switch (style) {
      case HairStyle.bald:
        for (final side in [-1.0, 1.0]) {
          final fringe = Path()
            ..moveTo(side * 0.15, -0.95)
            ..quadraticBezierTo(side * 0.175, -0.9, side * 0.165, -0.83)
            ..lineTo(side * 0.152, -0.84)
            ..quadraticBezierTo(side * 0.155, -0.9, side * 0.14, -0.94)
            ..close();
          _mass(canvas, fringe, c);
        }
        canvas.drawArc(
          Rect.fromCenter(center: const Offset(-0.02, -1.0), width: 0.18, height: 0.1),
          pi * 1.15,
          pi * 0.45,
          false,
          _line(Colors.white.withValues(alpha: 0.24), 0.016),
        );
      case HairStyle.receding:
        final hair = _shell(top: -1.095)
          ..quadraticBezierTo(0.155, -0.99, 0.1, -1.035)
          ..quadraticBezierTo(0.04, -1.005, 0, -1.0)
          ..quadraticBezierTo(-0.04, -1.005, -0.1, -1.035)
          ..quadraticBezierTo(-0.155, -0.99, -0.17, -0.86)
          ..close();
        _mass(canvas, hair, c);
        _comb(canvas, hair, c, strands: _flow(7, (t) => Offset(-0.12 + t * 0.24, -1.02), (t) => Offset(-0.1 + t * 0.2, -1.07), (t) => Offset(-0.08 + t * 0.16, -1.1)));
      case HairStyle.slicked:
        final hair = _shell(top: -1.1)
          ..quadraticBezierTo(0.155, -0.975, 0.06, -0.988)
          ..quadraticBezierTo(0.02, -0.99, 0, -0.978)
          ..quadraticBezierTo(-0.02, -0.99, -0.06, -0.988)
          ..quadraticBezierTo(-0.155, -0.975, -0.17, -0.86)
          ..close();
        _mass(canvas, hair, c);
        _comb(canvas, hair, c,
            strands: _flow(9, (t) => Offset(-0.15 + t * 0.3, -0.98), (t) => Offset(-0.16 + t * 0.32, -1.06), (t) => Offset(-0.1 + t * 0.2, -1.11)),
            shine: [_q(const Offset(-0.11, -1.03), const Offset(0, -1.08), const Offset(0.11, -1.03))]);
      case HairStyle.sidePart:
        final hair = _shell(top: -1.105)
          ..quadraticBezierTo(0.16, -0.95, 0.09, -0.972)
          ..quadraticBezierTo(-0.02, -0.985, -0.072, -1.03)
          ..quadraticBezierTo(-0.12, -0.97, -0.17, -0.86)
          ..close();
        _mass(canvas, hair, c);
        _comb(canvas, hair, c,
            strands: _flow(8, (t) => Offset(-0.07 + t * 0.01, -1.04 - t * 0.05), (t) => Offset(0.04 + t * 0.06, -1.07 + t * 0.05), (t) => Offset(0.12 + t * 0.06, -0.96 + t * 0.06))
              ..add(_q(const Offset(-0.072, -1.03), const Offset(-0.068, -1.07), const Offset(-0.062, -1.1))),
            shine: [_q(const Offset(-0.04, -1.05), const Offset(0.06, -1.07), const Offset(0.13, -1.0))]);
        canvas.drawLine(const Offset(-0.072, -1.03), const Offset(-0.062, -1.098), _line(_dark(c, 0.55), 0.006));
      case HairStyle.crewCut:
        final hair = _shell(top: -1.085, side: 0.163, y: -0.9, bulge: 0.172)
          ..quadraticBezierTo(0.13, -0.988, 0, -0.992)
          ..quadraticBezierTo(-0.13, -0.988, -0.163, -0.9)
          ..close();
        _mass(canvas, hair, c);
        final tick = _line(_bright(c, 0.35).withValues(alpha: 0.35), 0.004);
        for (var x = -0.13; x <= 0.131; x += 0.026) {
          for (final y in const [-1.0, -1.03, -1.06]) {
            canvas.drawLine(Offset(x, y), Offset(x + 0.004, y - 0.012), tick);
          }
        }
      case HairStyle.flatTop:
        final hair = Path()
          ..moveTo(-0.165, -0.88)
          ..quadraticBezierTo(-0.172, -1.04, -0.13, -1.13)
          ..lineTo(0.13, -1.13)
          ..quadraticBezierTo(0.172, -1.04, 0.165, -0.88)
          ..quadraticBezierTo(0.13, -0.985, 0, -0.99)
          ..quadraticBezierTo(-0.13, -0.985, -0.165, -0.88)
          ..close();
        _mass(canvas, hair, c);
        _comb(canvas, hair, c,
            strands: [for (var x = -0.11; x <= 0.111; x += 0.022) _q(Offset(x, -0.995), Offset(x, -1.06), Offset(x, -1.13))],
            shine: [_q(const Offset(-0.12, -1.12), const Offset(0, -1.125), const Offset(0.12, -1.12))],
            shineWidth: 0.01);
      case HairStyle.pompadour:
        final hair = Path()
          ..moveTo(-0.17, -0.86)
          ..cubicTo(-0.19, -1.0, -0.16, -1.14, -0.04, -1.165)
          ..cubicTo(0.06, -1.185, 0.17, -1.14, 0.18, -1.04)
          ..quadraticBezierTo(0.185, -0.95, 0.17, -0.86)
          ..quadraticBezierTo(0.15, -0.98, 0.07, -0.992)
          ..quadraticBezierTo(0, -1.0, -0.07, -0.992)
          ..quadraticBezierTo(-0.15, -0.98, -0.17, -0.86)
          ..close();
        _mass(canvas, hair, c);
        _comb(canvas, hair, c,
            strands: _flow(8, (t) => Offset(-0.12 + t * 0.24, -0.99), (t) => Offset(-0.16 + t * 0.26, -1.12), (t) => Offset(-0.02 + t * 0.14, -1.17 + t * 0.04)),
            shine: [_q(const Offset(-0.12, -1.1), const Offset(-0.02, -1.17), const Offset(0.12, -1.13))]);
      case HairStyle.quiff:
        final hair = Path()
          ..moveTo(-0.165, -0.86)
          ..cubicTo(-0.18, -1.0, -0.15, -1.15, -0.02, -1.19)
          ..cubicTo(0.1, -1.22, 0.2, -1.16, 0.14, -1.09)
          ..cubicTo(0.1, -1.05, 0.08, -1.02, 0.06, -0.97)
          ..quadraticBezierTo(0.04, -1.03, 0.0, -1.0)
          ..quadraticBezierTo(-0.15, -0.98, -0.165, -0.86)
          ..close();
        final sides = _shell(top: -1.08, side: 0.168, bulge: 0.18)
          ..quadraticBezierTo(0.15, -0.98, 0.05, -0.99)
          ..lineTo(-0.05, -0.99)
          ..quadraticBezierTo(-0.15, -0.98, -0.168, -0.86)
          ..close();
        _mass(canvas, sides, c);
        _mass(canvas, hair, c);
        _comb(canvas, hair, c,
            strands: _flow(7, (t) => Offset(-0.12 + t * 0.1, -0.99), (t) => Offset(-0.14 + t * 0.2, -1.17), (t) => Offset(0.06 + t * 0.08, -1.19 + t * 0.1)),
            shine: [_q(const Offset(-0.1, -1.13), const Offset(0.0, -1.2), const Offset(0.13, -1.16))]);
        // Il ricciolo che cade sulla fronte.
        canvas.drawArc(Rect.fromCenter(center: const Offset(0.055, -0.975), width: 0.03, height: 0.034), -pi * 0.3, pi * 1.4, false, _line(_dark(c, 0.15), 0.006));
      case HairStyle.ducktail:
        final hair = _shell(top: -1.13, bulge: 0.19)
          ..quadraticBezierTo(0.15, -0.975, 0.05, -0.99)
          ..quadraticBezierTo(0.01, -0.985, 0.0, -0.97)
          ..quadraticBezierTo(-0.02, -0.99, -0.05, -0.99)
          ..quadraticBezierTo(-0.15, -0.975, -0.17, -0.86)
          ..close();
        _mass(canvas, hair, c);
        _comb(canvas, hair, c,
            strands: [
              ..._flow(4, (t) => Offset(-0.17 + t * 0.02, -0.88 - t * 0.1), (t) => Offset(-0.14, -1.06), (t) => Offset(-0.02, -1.12)),
              ..._flow(4, (t) => Offset(0.17 - t * 0.02, -0.88 - t * 0.1), (t) => Offset(0.14, -1.06), (t) => Offset(0.02, -1.12)),
              _q(const Offset(0, -0.98), const Offset(0.0, -1.06), const Offset(0, -1.13)),
            ],
            shine: [
              _q(const Offset(-0.13, -1.0), const Offset(-0.11, -1.08), const Offset(-0.03, -1.11)),
              _q(const Offset(0.13, -1.0), const Offset(0.11, -1.08), const Offset(0.03, -1.11)),
            ],
            shineWidth: 0.01);
      case HairStyle.middlePart:
        final hair = _shell(top: -1.1)
          ..quadraticBezierTo(0.16, -0.94, 0.09, -0.97)
          ..quadraticBezierTo(0.03, -0.99, 0.0, -1.04)
          ..quadraticBezierTo(-0.03, -0.99, -0.09, -0.97)
          ..quadraticBezierTo(-0.16, -0.94, -0.17, -0.86)
          ..close();
        _mass(canvas, hair, c);
        _comb(canvas, hair, c,
            strands: [
              ..._flow(4, (t) => Offset(0.0, -1.045 - t * 0.05), (t) => Offset(0.06 + t * 0.03, -1.06 + t * 0.04), (t) => Offset(0.13 + t * 0.04, -0.96 + t * 0.06)),
              ..._flow(4, (t) => Offset(0.0, -1.045 - t * 0.05), (t) => Offset(-0.06 - t * 0.03, -1.06 + t * 0.04), (t) => Offset(-0.13 - t * 0.04, -0.96 + t * 0.06)),
            ],
            shine: [
              _q(const Offset(-0.02, -1.07), const Offset(-0.09, -1.06), const Offset(-0.13, -0.99)),
              _q(const Offset(0.02, -1.07), const Offset(0.09, -1.06), const Offset(0.13, -0.99)),
            ],
            shineWidth: 0.011);
        canvas.drawLine(const Offset(0, -1.04), const Offset(0, -1.1), _line(_dark(c, 0.55), 0.005));
      case HairStyle.curly:
        final hair = _shell(top: -1.12, side: 0.18, y: -0.8, bulge: 0.2)
          ..quadraticBezierTo(0.16, -0.95, 0, -0.985)
          ..quadraticBezierTo(-0.16, -0.95, -0.18, -0.8)
          ..close();
        _mass(canvas, hair, c);
        final curl = _hairPaint(c);
        final edge = _line(_dark(c, 0.55).withValues(alpha: 0.5), 0.004);
        final shine = _line(_sheen(c), 0.007);
        for (final p in const [
          Offset(-0.12, -0.99), Offset(-0.065, -1.0), Offset(-0.01, -0.995), Offset(0.05, -1.0), Offset(0.11, -0.99), //
          Offset(-0.165, -0.92), Offset(0.165, -0.92), Offset(-0.09, -1.06), Offset(0.0, -1.075), Offset(0.09, -1.06),
        ]) {
          canvas.drawCircle(p, 0.032, curl);
          canvas.drawCircle(p, 0.032, edge);
          canvas.drawArc(Rect.fromCircle(center: p, radius: 0.02), pi * 1.05, pi * 0.8, false, shine);
        }
      case HairStyle.wavy:
        final hair = _shell(top: -1.105, side: 0.175, y: -0.82, bulge: 0.195)
          ..quadraticBezierTo(0.15, -0.93, 0.1, -0.95)
          ..quadraticBezierTo(0.06, -0.995, 0.02, -0.968)
          ..quadraticBezierTo(-0.04, -1.0, -0.08, -0.962)
          ..quadraticBezierTo(-0.14, -0.95, -0.175, -0.82)
          ..close();
        _mass(canvas, hair, c);
        _comb(canvas, hair, c,
            strands: [
              for (var i = 0; i < 4; i++)
                _smooth([for (var x = -0.16; x <= 0.161; x += 0.04) Offset(x, -1.07 + i * 0.03 + sin(x * 40 + i) * 0.008)]),
            ],
            shine: [_smooth([for (var x = -0.12; x <= 0.121; x += 0.04) Offset(x, -1.05 + sin(x * 40) * 0.01)])]);
      case HairStyle.afro:
        final hair = _shell(top: -1.14, side: 0.175, y: -0.87, bulge: 0.21)
          ..quadraticBezierTo(0.14, -0.99, 0, -0.995)
          ..quadraticBezierTo(-0.14, -0.99, -0.175, -0.87)
          ..close();
        _mass(canvas, hair, c);
        _texture(canvas, hair, c, 26, 0.17, -0.98, 0.15);
      case HairStyle.coils:
        final hair = _shell(top: -1.13, side: 0.172, y: -0.88, bulge: 0.2)
          ..quadraticBezierTo(0.14, -0.99, 0, -0.995)
          ..quadraticBezierTo(-0.14, -0.99, -0.172, -0.88)
          ..close();
        _mass(canvas, hair, c);
        _texture(canvas, hair, c, 22, 0.16, -0.99, 0.13);
      case HairStyle.bun:
        final hair = _shell(top: -1.09)
          ..quadraticBezierTo(0.12, -0.98, 0, -0.99)
          ..quadraticBezierTo(-0.12, -0.98, -0.17, -0.86)
          ..close();
        _mass(canvas, hair, c);
        _comb(canvas, hair, c,
            strands: [
              ..._flow(4, (t) => Offset(-0.15 + t * 0.12, -0.95 - t * 0.04), (t) => Offset(-0.12, -1.06), (t) => Offset(-0.02, -1.09)),
              ..._flow(4, (t) => Offset(0.15 - t * 0.12, -0.95 - t * 0.04), (t) => Offset(0.12, -1.06), (t) => Offset(0.02, -1.09)),
            ],
            shine: [_q(const Offset(-0.1, -1.04), const Offset(-0.02, -1.08), const Offset(0.08, -1.05))]);
        canvas.drawLine(const Offset(-0.07, -1.14), const Offset(0.09, -1.07), _line(LookPainter.gold, 0.012));
      case HairStyle.updo:
        final roll = Path()
          ..moveTo(-0.17, -0.86)
          ..cubicTo(-0.2, -1.0, -0.18, -1.13, -0.06, -1.15)
          ..cubicTo(0.0, -1.16, 0.04, -1.16, 0.08, -1.15)
          ..cubicTo(0.18, -1.13, 0.2, -1.0, 0.17, -0.86)
          ..quadraticBezierTo(0.14, -0.99, 0.0, -1.0)
          ..quadraticBezierTo(-0.14, -0.99, -0.17, -0.86)
          ..close();
        _mass(canvas, roll, c);
        _comb(canvas, roll, c,
            strands: _flow(7, (t) => Offset(-0.14 + t * 0.28, -0.995), (t) => Offset(-0.15 + t * 0.3, -1.1), (t) => Offset(-0.06 + t * 0.12, -1.15)),
            shine: [
              _q(const Offset(-0.15, -1.04), const Offset(-0.14, -1.12), const Offset(-0.05, -1.14)),
              _q(const Offset(0.15, -1.04), const Offset(0.14, -1.12), const Offset(0.05, -1.14)),
            ]);
      case HairStyle.bob:
        final hair = Path()
          ..moveTo(-0.19, -0.78)
          ..cubicTo(-0.215, -0.98, -0.17, -1.09, 0, -1.09)
          ..cubicTo(0.17, -1.09, 0.215, -0.98, 0.19, -0.78)
          ..quadraticBezierTo(0.17, -0.72, 0.13, -0.74)
          ..quadraticBezierTo(0.17, -0.9, 0.04, -0.96)
          ..quadraticBezierTo(-0.06, -0.93, -0.1, -0.97)
          ..quadraticBezierTo(-0.16, -0.9, -0.15, -0.76)
          ..quadraticBezierTo(-0.17, -0.74, -0.19, -0.78)
          ..close();
        _mass(canvas, hair, c);
        _comb(canvas, hair, c,
            strands: [
              ..._flow(5, (t) => Offset(-0.1, -1.0 - t * 0.08), (t) => Offset(-0.18, -0.98 + t * 0.02), (t) => Offset(-0.17 - t * 0.02, -0.77)),
              ..._flow(6, (t) => Offset(-0.09 + t * 0.03, -1.0 - t * 0.08), (t) => Offset(0.12 + t * 0.06, -1.04), (t) => Offset(0.15 + t * 0.03, -0.76)),
            ],
            shine: [_q(const Offset(-0.06, -1.06), const Offset(0.1, -1.07), const Offset(0.17, -0.94))]);
      case HairStyle.pageboy:
        final hair = Path()
          ..moveTo(-0.19, -0.76)
          ..cubicTo(-0.215, -0.98, -0.17, -1.09, 0, -1.09)
          ..cubicTo(0.17, -1.09, 0.215, -0.98, 0.19, -0.76)
          ..quadraticBezierTo(0.165, -0.72, 0.14, -0.76)
          ..quadraticBezierTo(0.15, -0.88, 0.14, -0.955)
          ..quadraticBezierTo(0.0, -0.95, -0.14, -0.955)
          ..quadraticBezierTo(-0.15, -0.88, -0.14, -0.76)
          ..quadraticBezierTo(-0.165, -0.72, -0.19, -0.76)
          ..close();
        _mass(canvas, hair, c);
        _comb(canvas, hair, c,
            strands: [
              for (var x = -0.12; x <= 0.121; x += 0.03) _q(Offset(x * 0.7, -1.08), Offset(x, -1.04), Offset(x, -0.955)),
              for (final s in [-1.0, 1.0]) _q(Offset(s * 0.17, -0.98), Offset(s * 0.18, -0.85), Offset(s * 0.16, -0.75)),
            ],
            shine: [_q(const Offset(-0.12, -1.03), const Offset(0, -1.07), const Offset(0.12, -1.03))]);
      case HairStyle.long:
        final hair = Path()
          ..moveTo(-0.205, -0.7)
          ..cubicTo(-0.22, -0.98, -0.18, -1.09, 0, -1.09)
          ..cubicTo(0.18, -1.09, 0.22, -0.98, 0.205, -0.7)
          ..lineTo(0.165, -0.72)
          ..quadraticBezierTo(0.16, -0.93, 0.006, -0.988)
          ..quadraticBezierTo(-0.16, -0.93, -0.165, -0.72)
          ..close();
        _mass(canvas, hair, c);
        _comb(canvas, hair, c,
            strands: [
              ..._flow(5, (t) => Offset(0.0, -1.0 - t * 0.08), (t) => Offset(0.13 + t * 0.06, -1.0), (t) => Offset(0.17 + t * 0.03, -0.72)),
              ..._flow(5, (t) => Offset(0.0, -1.0 - t * 0.08), (t) => Offset(-0.13 - t * 0.06, -1.0), (t) => Offset(-0.17 - t * 0.03, -0.72)),
            ],
            shine: [
              _q(const Offset(-0.03, -1.07), const Offset(-0.15, -1.04), const Offset(-0.18, -0.9)),
              _q(const Offset(0.03, -1.07), const Offset(0.14, -1.04), const Offset(0.17, -0.92)),
            ],
            shineWidth: 0.011);
        canvas.drawLine(const Offset(0.006, -0.988), const Offset(0.003, -1.085), _line(_dark(c, 0.5), 0.006));
      case HairStyle.fingerWaves:
        final hair = Path()
          ..moveTo(-0.18, -0.8)
          ..cubicTo(-0.2, -0.98, -0.17, -1.1, 0, -1.1)
          ..cubicTo(0.17, -1.1, 0.2, -0.98, 0.18, -0.8)
          ..quadraticBezierTo(0.16, -0.86, 0.15, -0.92)
          ..quadraticBezierTo(0.08, -0.95, 0.04, -0.985)
          ..quadraticBezierTo(-0.03, -0.96, -0.08, -1.0)
          ..quadraticBezierTo(-0.14, -0.95, -0.155, -0.88)
          ..quadraticBezierTo(-0.165, -0.84, -0.18, -0.8)
          ..close();
        _mass(canvas, hair, c);
        // Le onde scolpite: un'ombra e un riflesso per ogni cresta.
        final waves = [
          for (var i = 0; i < 4; i++) _smooth([for (var t = -1.0; t <= 1.01; t += 0.25) Offset(t * 0.19, -1.08 + i * 0.045 + sin(t * 5 + i * pi) * 0.012)]),
        ];
        _comb(canvas, hair, c, strands: waves, shine: [for (final w in waves) w.shift(const Offset(0, -0.012))], shineWidth: 0.009);
        for (final side in [-1.0, 1.0]) {
          final p = Offset(side * 0.17, -0.82);
          canvas.drawCircle(p, 0.02, _hairPaint(c));
          canvas.drawArc(Rect.fromCircle(center: p, radius: 0.012), 0, pi * 1.6, false, _line(_dark(c, 0.5), 0.004));
        }
      case HairStyle.victoryRolls:
        final hair = _shell(top: -1.08)
          ..quadraticBezierTo(0.16, -0.97, 0.0, -0.99)
          ..quadraticBezierTo(-0.16, -0.97, -0.17, -0.86)
          ..close();
        _mass(canvas, hair, c);
        for (final side in [-1.0, 1.0]) {
          final roll = Rect.fromCenter(center: Offset(side * 0.08, -1.1), width: 0.14, height: 0.1);
          canvas.drawOval(roll, _hairPaint(c));
          canvas.drawOval(roll, _line(_dark(c, 0.55).withValues(alpha: 0.6), 0.0045));
          canvas.drawOval(roll.deflate(0.022), _line(_dark(c, 0.45), 0.004));
          canvas.drawArc(roll.deflate(0.008), pi * 1.05, pi * 0.7, false, _line(_sheen(c), 0.01));
          final curls = _curtain(side, bottom: -0.72, width: 0.035);
          _mass(canvas, curls, c);
          canvas.drawCircle(Offset(side * 0.19, -0.725), 0.024, _hairPaint(c));
          canvas.drawArc(Rect.fromCircle(center: Offset(side * 0.19, -0.725), radius: 0.014), 0, pi * 1.5, false, _line(_dark(c, 0.5), 0.004));
        }
      case HairStyle.pinCurls:
        final hair = _shell(top: -1.1, side: 0.18, y: -0.78, bulge: 0.2)
          ..quadraticBezierTo(0.16, -0.94, 0.0, -0.97)
          ..quadraticBezierTo(-0.16, -0.94, -0.18, -0.78)
          ..close();
        _mass(canvas, hair, c);
        final shine = _line(_sheen(c), 0.006);
        final edge = _line(_dark(c, 0.5), 0.004);
        for (final p in const [
          Offset(-0.1, -0.985), Offset(-0.04, -0.995), Offset(0.03, -0.995), Offset(0.095, -0.985), //
          Offset(-0.18, -0.86), Offset(0.18, -0.86), Offset(-0.19, -0.79), Offset(0.19, -0.79),
        ]) {
          canvas.drawCircle(p, 0.026, _hairPaint(c));
          canvas.drawArc(Rect.fromCircle(center: p, radius: 0.016), pi * 0.2, pi * 1.5, false, edge);
          canvas.drawArc(Rect.fromCircle(center: p, radius: 0.022), pi * 1.1, pi * 0.6, false, shine);
        }
      case HairStyle.ponytail:
        final hair = _shell(top: -1.1)
          ..quadraticBezierTo(0.15, -0.97, 0.06, -0.985)
          ..quadraticBezierTo(-0.04, -0.99, -0.07, -1.02)
          ..quadraticBezierTo(-0.13, -0.96, -0.17, -0.86)
          ..close();
        _mass(canvas, hair, c);
        _comb(canvas, hair, c,
            strands: _flow(8, (t) => Offset(-0.15 + t * 0.3, -0.95 - (1 - (t - 0.5).abs() * 2) * 0.04), (t) => Offset(-0.06 + t * 0.2, -1.08), (t) => const Offset(0.13, -1.07)),
            shine: [_q(const Offset(-0.08, -1.06), const Offset(0.04, -1.09), const Offset(0.13, -1.05))]);
        canvas.drawOval(Rect.fromCenter(center: const Offset(0.15, -1.06), width: 0.03, height: 0.04), _fill(const Color(0xFFB0303A)));
      case HairStyle.braids:
        final hair = _shell(top: -1.09)
          ..quadraticBezierTo(0.15, -0.95, 0.06, -0.98)
          ..quadraticBezierTo(0.01, -0.99, 0.0, -1.02)
          ..quadraticBezierTo(-0.01, -0.99, -0.06, -0.98)
          ..quadraticBezierTo(-0.15, -0.95, -0.17, -0.86)
          ..close();
        _mass(canvas, hair, c);
        _comb(canvas, hair, c,
            strands: [
              ..._flow(4, (t) => Offset(0.0, -1.02 - t * 0.06), (t) => Offset(0.1, -1.04 + t * 0.03), (t) => Offset(0.16, -0.9 + t * 0.03)),
              ..._flow(4, (t) => Offset(0.0, -1.02 - t * 0.06), (t) => Offset(-0.1, -1.04 + t * 0.03), (t) => Offset(-0.16, -0.9 + t * 0.03)),
            ],
            shine: [_q(const Offset(-0.03, -1.07), const Offset(-0.1, -1.06), const Offset(-0.15, -0.97))]);
        _braids(canvas, c);
    }
  }

  /// I riccioli fitti: puntini di luce e d'ombra sparsi nella massa.
  static void _texture(Canvas canvas, Path clip, Color c, int n, double rx, double cy, double ry) {
    canvas.save();
    canvas.clipPath(clip);
    final light = _fill(_sheen(c).withValues(alpha: 0.35));
    final dark = _fill(_dark(c, 0.5).withValues(alpha: 0.4));
    for (var i = 0; i < n; i++) {
      final a = i * 2.399;
      final d = sqrt((i + 0.5) / n);
      final p = Offset(cos(a) * rx * d, cy - sin(a).abs() * ry * d - 0.03);
      canvas.drawCircle(p, 0.011, i.isEven ? light : dark);
    }
    canvas.restore();
  }

  /// Sotto il cappello: le basette, o le ciocche di chi le porta lunghe.
  static void _underHat(Canvas canvas, HairStyle style, Color c) {
    switch (style) {
      case HairStyle.bald:
        return;
      case HairStyle.afro || HairStyle.coils:
        return; // i lati sono già nel retro
      case HairStyle.braids:
        for (final side in [-1.0, 1.0]) {
          _mass(canvas, _curtain(side, bottom: -0.84, width: 0.01), c);
        }
        _braids(canvas, c);
      case HairStyle.bob || HairStyle.long || HairStyle.wavy || HairStyle.curly || HairStyle.victoryRolls || HairStyle.pinCurls || HairStyle.pageboy:
        for (final side in [-1.0, 1.0]) {
          final lock = _curtain(side, bottom: style == HairStyle.long ? -0.7 : -0.74);
          _mass(canvas, lock, c);
          _comb(canvas, lock, c, shine: [_q(Offset(side * 0.15, -0.96), Offset(side * 0.19, -0.92), Offset(side * 0.19, -0.82))], shineWidth: 0.008);
        }
      case _:
        for (final side in [-1.0, 1.0]) {
          final burn = Path()
            ..moveTo(side * 0.142, -0.95)
            ..lineTo(side * 0.168, -0.95)
            ..quadraticBezierTo(side * 0.17, -0.9, side * 0.162, -0.858)
            ..lineTo(side * 0.146, -0.866)
            ..close();
          _mass(canvas, burn, c);
        }
    }
  }
}
