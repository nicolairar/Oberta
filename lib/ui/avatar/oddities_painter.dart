part of 'look_painter.dart';

/// Le stramberie della bottega: il circo, il carnevale, i travestimenti.
/// Disegnate nelle stesse coordinate del busto di [LookPainter] (la testa
/// al centro in (0, -0.86), le spalle a -0.6).
abstract final class _Oddities {
  static Color _dark(Color c, double t) => LookPainter._dark(c, t);
  static Color _bright(Color c, double t) => LookPainter._bright(c, t);
  static const _ink = LookPainter.ink;

  static Paint _fill(Color c) => Paint()..color = c;

  static Paint _line(Color c, double width) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round;

  // --- Le stoffe (dentro la sagoma del busto) -------------------------------

  static void fabric(Canvas canvas, AvatarOutfit outfit, Color skin) {
    switch (outfit.pattern) {
      case CoatPattern.clown:
        // I pois grandi, rossi, blu e verdi.
        const dots = [Color(0xFFD23A2E), Color(0xFF2E5BC8), Color(0xFF2E9E4A)];
        var i = 0;
        for (var row = 0; row < 9; row++) {
          for (var x = -0.56; x < 0.6; x += 0.15) {
            final c = Offset(x + (row.isOdd ? 0.075 : 0), -0.6 + row * 0.13);
            canvas.drawCircle(c, 0.036, _fill(dots[i++ % dots.length]));
          }
        }
      case CoatPattern.leotard:
        // Le righe del forzuto, e le spalle nude sopra la canottiera.
        final stripe = _fill(outfit.accent);
        for (var y = -0.62; y < 0.6; y += 0.12) {
          canvas.drawRect(Rect.fromLTRB(-0.6, y, 0.6, y + 0.055), stripe);
        }
        final tank = Path()
          ..moveTo(-0.31, -0.3)
          ..lineTo(-0.29, -0.64)
          ..lineTo(-0.19, -0.64)
          ..quadraticBezierTo(0, -0.4, 0.19, -0.64)
          ..lineTo(0.29, -0.64)
          ..lineTo(0.31, -0.3)
          ..close();
        final bare = Path()
          ..fillType = PathFillType.evenOdd
          ..addRect(const Rect.fromLTRB(-0.6, -0.7, 0.6, -0.3))
          ..addPath(tank, Offset.zero);
        canvas.drawPath(bare, _fill(LookPainter._skinShade(skin, 0.2)));
        // I muscoli delle spalle, un filo d'ombra.
        for (final side in [-1.0, 1.0]) {
          canvas.drawArc(
            Rect.fromCenter(center: Offset(side * 0.42, -0.5), width: 0.2, height: 0.16),
            side < 0 ? pi * 0.1 : pi * 0.4,
            pi * 0.5,
            false,
            _line(LookPainter._skinShade(skin, 0.5), 0.012),
          );
        }
      case CoatPattern.breton:
        // La maglia a righe del mimo.
        final stripe = _fill(const Color(0xFF1B2440));
        for (var y = -0.58; y < 0.6; y += 0.075) {
          canvas.drawRect(Rect.fromLTRB(-0.6, y, 0.6, y + 0.032), stripe);
        }
      case CoatPattern.chef:
        // La giacca bianca: una piega d'ombra dove si sovrappone.
        canvas.drawLine(const Offset(0.13, -0.58), const Offset(0.13, 0.6), _line(_dark(outfit.coat, 0.2), 0.01));
      case CoatPattern.banana:
        // Le venature della buccia, e la punta bruna in basso.
        final vein = _line(_dark(outfit.coat, 0.3), 0.012);
        for (final x in [-0.3, -0.12, 0.12, 0.3]) {
          canvas.drawPath(
            Path()
              ..moveTo(x * 0.6, -0.6)
              ..quadraticBezierTo(x * 1.25, -0.1, x * 1.1, 0.6),
            vein,
          );
        }
        final spot = _fill(const Color(0xFF6A4A1E).withValues(alpha: 0.7));
        for (final c in const [Offset(-0.22, -0.3), Offset(0.26, -0.16), Offset(-0.05, -0.05), Offset(0.18, -0.42)]) {
          canvas.drawOval(Rect.fromCenter(center: c, width: 0.035, height: 0.022), spot);
        }
      default:
        _Absurd.fabric(canvas, outfit);
    }
  }

  // --- I colli dei costumi --------------------------------------------------

  static void collar(Canvas canvas, AvatarOutfit outfit, Color skin) {
    switch (outfit.pattern) {
      case CoatPattern.clown:
        // La gorgiera a festoni, bordata di rosso, e i pompon sul petto.
        const pompons = [Color(0xFFD23A2E), Color(0xFF2E5BC8), Color(0xFF2E9E4A)];
        for (final (i, y) in [-0.44, -0.3, -0.16].indexed) {
          canvas.drawCircle(Offset(0, y), 0.034, _fill(pompons[i]));
          canvas.drawCircle(Offset(-0.01, y - 0.01), 0.01, _fill(Colors.white.withValues(alpha: 0.5)));
        }
        for (var i = 0; i < 11; i++) {
          final a = pi + i * pi / 10;
          final c = Offset(cos(a) * 0.25, -0.6 - sin(a) * 0.05 + 0.03);
          canvas.drawCircle(c, 0.052, _fill(outfit.shirt));
          canvas.drawCircle(c, 0.052, _line(outfit.accent, 0.01));
        }
        for (var i = 0; i < 7; i++) {
          final a = pi + i * pi / 6;
          final c = Offset(cos(a) * 0.15, -0.62 - sin(a) * 0.03 + 0.05);
          canvas.drawCircle(c, 0.045, _fill(_dark(outfit.shirt, 0.08)));
          canvas.drawCircle(c, 0.045, _line(outfit.accent, 0.008));
        }
      case CoatPattern.breton || CoatPattern.chef:
        if (outfit.pattern == CoatPattern.chef) {
          // Il colletto alla coreana e due file di bottoni di stoffa.
          canvas.drawRect(const Rect.fromLTRB(-0.11, -0.65, 0.11, -0.6), _fill(_dark(outfit.coat, 0.08)));
          final knot = _fill(_dark(outfit.coat, 0.18));
          for (final y in [-0.5, -0.38, -0.26, -0.14]) {
            for (final x in [-0.06, 0.2]) {
              canvas.drawCircle(Offset(x, y), 0.017, knot);
            }
          }
        }
        // Il fazzoletto rosso annodato al collo.
        final red = _fill(outfit.accent);
        canvas.drawPath(
          Path()
            ..moveTo(-0.1, -0.63)
            ..quadraticBezierTo(0, -0.6, 0.1, -0.63)
            ..lineTo(0.02, -0.52)
            ..close(),
          red,
        );
        canvas.drawPath(
          Path()
            ..moveTo(0.0, -0.58)
            ..lineTo(0.07, -0.47)
            ..lineTo(0.03, -0.46)
            ..close(),
          _fill(_dark(outfit.accent, 0.25)),
        );
        canvas.drawCircle(const Offset(0.01, -0.585), 0.022, red);
      case CoatPattern.banana:
        // La buccia aperta: quattro lembi che ricadono attorno al collo.
        final peel = _fill(_bright(outfit.coat, 0.08));
        final inner = _fill(const Color(0xFFF4ECC8));
        for (final side in [-1.0, 1.0]) {
          for (final (lean, reach) in [(0.16, 0.36), (0.34, 0.26)]) {
            final flap = Path()
              ..moveTo(side * 0.06, -0.64)
              ..quadraticBezierTo(side * (lean + 0.08), -0.66, side * (lean + 0.1), -0.64 + reach)
              ..quadraticBezierTo(side * (lean - 0.02), -0.6, side * 0.03, -0.6)
              ..close();
            canvas.drawPath(flap, peel);
            canvas.drawPath(flap, _line(_dark(outfit.coat, 0.35), 0.008));
          }
        }
        canvas.drawOval(Rect.fromCenter(center: const Offset(0, -0.62), width: 0.17, height: 0.06), inner);
      default:
        _Absurd.collar(canvas, outfit);
    }
  }

  // --- I segni in faccia ----------------------------------------------------

  static void mark(Canvas canvas, FaceMark mark, Color hair) {
    switch (mark) {
      case FaceMark.curledMoustache:
        // Il forzuto e il cuoco: folti nel mezzo, due riccioli alle punte.
        final stroke = _line(hair, 0.022);
        for (final side in [-1.0, 1.0]) {
          canvas.drawPath(
            Path()
              ..moveTo(0, -0.79)
              ..quadraticBezierTo(side * 0.06, -0.8, side * 0.1, -0.78)
              ..arcTo(
                Rect.fromCenter(center: Offset(side * 0.115, -0.8), width: 0.05, height: 0.05),
                side > 0 ? pi * 0.5 : pi * 0.5,
                side * -pi * 1.6,
                false,
              ),
            stroke,
          );
        }
        canvas.drawOval(Rect.fromCenter(center: const Offset(0, -0.788), width: 0.09, height: 0.03), _fill(hair));
      case FaceMark.giantMoustache:
        // Il baffone finto, più largo della faccia.
        final bush = Path()
          ..moveTo(0, -0.81)
          ..quadraticBezierTo(0.12, -0.84, 0.23, -0.79)
          ..quadraticBezierTo(0.25, -0.73, 0.2, -0.72)
          ..quadraticBezierTo(0.17, -0.76, 0.12, -0.745)
          ..quadraticBezierTo(0.06, -0.76, 0, -0.755)
          ..quadraticBezierTo(-0.06, -0.76, -0.12, -0.745)
          ..quadraticBezierTo(-0.17, -0.76, -0.2, -0.72)
          ..quadraticBezierTo(-0.25, -0.73, -0.23, -0.79)
          ..quadraticBezierTo(-0.12, -0.84, 0, -0.81)
          ..close();
        canvas.drawPath(bush, _fill(hair));
        final comb = _line(Colors.white.withValues(alpha: 0.16), 0.006);
        for (var x = -0.18; x <= 0.19; x += 0.045) {
          canvas.drawLine(Offset(x, -0.8), Offset(x * 1.08, -0.76), comb);
        }
      case FaceMark.mimeFace:
        // Il trucco del mimo: le righe sopra e sotto gli occhi, la bocca a
        // cuore e una lacrima.
        final paint = _line(_ink, 0.011);
        for (final x in [-0.065, 0.065]) {
          canvas.drawLine(Offset(x, -0.945), Offset(x, -0.918), paint);
          canvas.drawLine(Offset(x, -0.85), Offset(x, -0.828), paint);
        }
        canvas.drawPath(
          Path()
            ..moveTo(-0.07, -0.83)
            ..quadraticBezierTo(-0.082, -0.81, -0.07, -0.802)
            ..quadraticBezierTo(-0.058, -0.81, -0.07, -0.83)
            ..close(),
          _fill(_ink),
        );
        canvas.drawOval(
          Rect.fromCenter(center: const Offset(0, -0.763), width: 0.045, height: 0.024),
          _fill(const Color(0xFFC8282E)),
        );
      default:
        _Absurd.mark(canvas, mark, hair);
    }
  }

  // --- Gli occhiali da scherzo ----------------------------------------------

  static Path _heart(Offset c, double r) => Path()
    ..moveTo(c.dx, c.dy + r * 0.9)
    ..cubicTo(c.dx - r * 1.5, c.dy - r * 0.1, c.dx - r * 0.8, c.dy - r * 1.2, c.dx, c.dy - r * 0.45)
    ..cubicTo(c.dx + r * 0.8, c.dy - r * 1.2, c.dx + r * 1.5, c.dy - r * 0.1, c.dx, c.dy + r * 0.9)
    ..close();

  static void glasses(Canvas canvas, AvatarGlasses glasses) {
    switch (glasses) {
      case AvatarGlasses.noseDisguise:
        // Il travestimento: occhiali neri, sopracciglia folte, nasone e baffi.
        final frame = _line(_ink, 0.018);
        for (final x in [-0.065, 0.065]) {
          canvas.drawCircle(Offset(x, -0.875), 0.044, frame);
          canvas.drawLine(Offset(x - 0.045, -0.93), Offset(x + 0.045, -0.93), _line(_ink, 0.028));
        }
        canvas.drawLine(const Offset(-0.02, -0.88), const Offset(0.02, -0.88), frame);
        canvas.drawPath(
          Path()
            ..moveTo(-0.085, -0.775)
            ..quadraticBezierTo(0, -0.81, 0.085, -0.775)
            ..quadraticBezierTo(0, -0.765, -0.085, -0.775)
            ..close(),
          _fill(_ink),
        );
        final nose = Rect.fromCenter(center: const Offset(0.004, -0.822), width: 0.075, height: 0.085);
        canvas.drawOval(
          nose,
          Paint()
            ..shader = LookPainter._gs(const RadialGradient(
              center: Alignment(-0.3, -0.4),
              colors: [Color(0xFFF6C0A6), Color(0xFFD0806A)],
            ), nose),
        );
      case AvatarGlasses.heartGlasses:
        for (final x in [-0.068, 0.068]) {
          final heart = _heart(Offset(x, -0.872), 0.055);
          canvas.drawPath(heart, _fill(const Color(0xFFE0305A).withValues(alpha: 0.5)));
          canvas.drawPath(heart, _line(const Color(0xFFD8284A), 0.012));
        }
        canvas.drawLine(const Offset(-0.02, -0.885), const Offset(0.02, -0.885), _line(const Color(0xFFD8284A), 0.01));
      case AvatarGlasses.hypnoGlasses:
        // Le spirali dell'ipnotizzatore.
        for (final x in [-0.066, 0.066]) {
          final c = Offset(x, -0.875);
          canvas.drawCircle(c, 0.05, _fill(LookPainter.paper));
          final spiral = Path()..moveTo(c.dx, c.dy);
          for (var t = 0.0; t < pi * 6; t += 0.2) {
            final r = 0.046 * t / (pi * 6);
            spiral.lineTo(c.dx + cos(t) * r * (x < 0 ? 1 : -1), c.dy + sin(t) * r);
          }
          canvas.drawPath(spiral, _line(_ink, 0.008));
          canvas.drawCircle(c, 0.05, _line(_ink, 0.012));
        }
        canvas.drawLine(const Offset(-0.016, -0.88), const Offset(0.016, -0.88), _line(_ink, 0.012));
      case AvatarGlasses.giantGlasses || AvatarGlasses.giantShades:
        // Gli occhialoni: lenti grandi come piattini.
        final shades = glasses == AvatarGlasses.giantShades;
        final frame = _line(shades ? const Color(0xFFD8284A) : _ink, 0.02);
        for (final x in [-0.11, 0.11]) {
          final c = Offset(x, -0.87);
          if (shades) {
            canvas.drawCircle(c, 0.1, _fill(const Color(0xFF0B0B10)));
            canvas.drawLine(
              c.translate(-0.05, -0.04),
              c.translate(-0.02, -0.06),
              _line(Colors.white.withValues(alpha: 0.6), 0.014),
            );
          } else {
            canvas.drawCircle(c, 0.1, _fill(Colors.white.withValues(alpha: 0.18)));
            canvas.drawCircle(c.translate(-0.04, -0.04), 0.014, _fill(Colors.white.withValues(alpha: 0.7)));
          }
          canvas.drawCircle(c, 0.1, frame);
        }
        canvas.drawLine(const Offset(-0.012, -0.88), const Offset(0.012, -0.88), frame);
      case AvatarGlasses.eyePatch:
        // La benda del pirata, sull'occhio destro.
        canvas.drawLine(const Offset(-0.165, -0.96), const Offset(0.165, -0.83), _line(_ink, 0.012));
        canvas.drawOval(Rect.fromCenter(center: const Offset(0.066, -0.875), width: 0.085, height: 0.068), _fill(_ink));
        canvas.drawArc(
          Rect.fromCenter(center: const Offset(0.066, -0.875), width: 0.06, height: 0.045),
          pi * 1.1,
          pi * 0.5,
          false,
          _line(Colors.white.withValues(alpha: 0.25), 0.006),
        );
      default:
        _Absurd.glasses(canvas, glasses);
    }
  }

  // --- I cappelli -----------------------------------------------------------

  static void hat(Canvas canvas, AvatarHead hat, Paint? silhouette) {
    Paint p(Color c) => silhouette ?? _fill(c);
    final detail = silhouette == null;
    switch (hat) {
      case AvatarHead.clownWig:
        // La parrucca arcobaleno: due nuvole di riccioli e un ciuffo in cima.
        const left = [Color(0xFFD23A2E), Color(0xFFE8842A), Color(0xFFE9C23A)];
        const right = [Color(0xFF2E9E4A), Color(0xFF2E5BC8), Color(0xFF8A3EB0)];
        for (final (side, colors) in [(-1.0, left), (1.0, right)]) {
          canvas.drawCircle(Offset(side * 0.17, -1.0), 0.07, p(colors[0]));
          canvas.drawCircle(Offset(side * 0.23, -0.92), 0.072, p(colors[1]));
          canvas.drawCircle(Offset(side * 0.2, -0.83), 0.062, p(colors[2]));
        }
        canvas.drawCircle(const Offset(-0.045, -1.07), 0.04, p(left[0]));
        canvas.drawCircle(const Offset(0.045, -1.07), 0.04, p(right[1]));
        canvas.drawCircle(const Offset(0, -1.1), 0.042, p(left[2]));
        if (detail) {
          final curl = _line(Colors.black.withValues(alpha: 0.22), 0.008);
          for (final c in const [Offset(-0.2, -0.95), Offset(0.2, -0.95), Offset(-0.19, -0.84), Offset(0.19, -0.84)]) {
            canvas.drawArc(Rect.fromCenter(center: c, width: 0.06, height: 0.05), 0.3, pi * 1.3, false, curl);
          }
        }
      case AvatarHead.magicianHat:
        // Il cilindro del prestigiatore, e il coniglio che fa capolino.
        if (detail) {
          for (final side in [-1.0, 1.0]) {
            canvas.save();
            canvas.translate(side * 0.045, -1.39);
            canvas.rotate(side * 0.22);
            canvas.drawOval(
              Rect.fromCenter(center: Offset.zero, width: 0.055, height: 0.17),
              _fill(const Color(0xFFF4F0E8)),
            );
            canvas.drawOval(
              Rect.fromCenter(center: const Offset(0, 0.01), width: 0.026, height: 0.12),
              _fill(const Color(0xFFE8A0AA)),
            );
            canvas.restore();
          }
        } else {
          for (final side in [-1.0, 1.0]) {
            canvas.drawOval(
              Rect.fromCenter(center: Offset(side * 0.045, -1.39), width: 0.055, height: 0.17),
              silhouette,
            );
          }
        }
        canvas.drawOval(
          Rect.fromCenter(center: const Offset(0, -0.972), width: 0.5, height: 0.075),
          p(const Color(0xFF16141A)),
        );
        canvas.drawPath(
          Path()
            ..moveTo(-0.15, -0.975)
            ..lineTo(-0.17, -1.31)
            ..lineTo(0.17, -1.31)
            ..lineTo(0.15, -0.975)
            ..close(),
          p(const Color(0xFF1E1B22)),
        );
        if (detail) {
          canvas.drawRect(const Rect.fromLTRB(-0.153, -1.05, 0.153, -0.99), _fill(const Color(0xFFB0202C)));
          canvas.drawArc(
            Rect.fromCenter(center: const Offset(0, -1.31), width: 0.34, height: 0.05),
            0,
            pi,
            false,
            _line(const Color(0xFF3A3640), 0.014),
          );
          // Una stella d'oro sul nastro.
          canvas.drawPath(LookPainter._starPath(const Offset(0.09, -1.02), 0.022, 5, 0.45), _fill(LookPainter.gold));
        }
      case AvatarHead.chefToque:
        const white = Color(0xFFF6F2EA);
        canvas.drawRect(const Rect.fromLTRB(-0.15, -1.13, 0.15, -1.03), p(white));
        canvas.drawCircle(const Offset(-0.1, -1.14), 0.085, p(white));
        canvas.drawCircle(const Offset(0.1, -1.14), 0.085, p(white));
        canvas.drawCircle(const Offset(0, -1.2), 0.1, p(white));
        canvas.drawRect(const Rect.fromLTRB(-0.16, -1.06, 0.16, -0.95), p(const Color(0xFFEAE4D8)));
        if (detail) {
          final fold = _line(const Color(0xFFBDB4A4), 0.008);
          for (final x in [-0.08, 0.0, 0.08]) {
            canvas.drawLine(Offset(x, -1.17), Offset(x, -1.07), fold);
          }
          canvas.drawLine(const Offset(-0.16, -1.06), const Offset(0.16, -1.06), fold);
        }
      case AvatarHead.sombrero:
        // Il sombrero di paglia, il nastro ricamato e i pompon sulla tesa: largo,
        // ma dentro lo schermo del telefono e il posto al tavolo.
        const straw = Color(0xFFD8B46A);
        canvas.drawOval(Rect.fromCenter(center: const Offset(0, -0.97), width: 0.8, height: 0.14), p(straw));
        canvas.drawPath(
          Path()
            ..moveTo(-0.14, -0.975)
            ..quadraticBezierTo(-0.15, -1.27, 0, -1.28)
            ..quadraticBezierTo(0.15, -1.27, 0.14, -0.975)
            ..close(),
          p(_bright(straw, 0.08)),
        );
        if (detail) {
          canvas.drawArc(
            Rect.fromCenter(center: const Offset(0, -0.97), width: 0.8, height: 0.14),
            pi,
            pi,
            false,
            _line(_dark(straw, 0.35), 0.014),
          );
          canvas.drawRect(const Rect.fromLTRB(-0.143, -1.06, 0.143, -1.0), _fill(const Color(0xFFB0262A)));
          final zig = Path()..moveTo(-0.14, -1.03);
          for (var i = 1; i <= 10; i++) {
            zig.lineTo(-0.14 + i * 0.028, i.isOdd ? -1.05 : -1.01);
          }
          canvas.drawPath(zig, _line(const Color(0xFF2E9E4A), 0.008));
          const pompons = [Color(0xFFD23A2E), Color(0xFF2E9E4A), Color(0xFFE8842A)];
          var i = 0;
          for (final x in [-0.375, -0.315, -0.25, 0.25, 0.315, 0.375]) {
            final y = -0.97 + 0.07 * sqrt(max(0, 1 - pow(x / 0.4, 2)));
            canvas.drawLine(Offset(x, y - 0.005), Offset(x, y + 0.02), _line(_dark(straw, 0.4), 0.004));
            canvas.drawCircle(Offset(x, y + 0.03), 0.018, _fill(pompons[i++ % 3]));
          }
        }
      case AvatarHead.tricorn:
        // Il tricorno del pirata, bordato d'oro.
        final hatPath = Path()
          ..moveTo(-0.31, -1.02)
          ..quadraticBezierTo(-0.2, -1.24, 0, -1.22)
          ..quadraticBezierTo(0.2, -1.24, 0.31, -1.02)
          ..quadraticBezierTo(0.15, -1.0, 0, -0.92)
          ..quadraticBezierTo(-0.15, -1.0, -0.31, -1.02)
          ..close();
        canvas.drawPath(hatPath, p(const Color(0xFF17151A)));
        if (detail) {
          canvas.drawPath(
            Path()
              ..moveTo(-0.31, -1.02)
              ..quadraticBezierTo(-0.15, -1.0, 0, -0.92)
              ..quadraticBezierTo(0.15, -1.0, 0.31, -1.02),
            _line(LookPainter.gold, 0.016),
          );
          // Il teschio stilizzato no: una coccarda rossa.
          canvas.drawCircle(const Offset(0, -1.06), 0.035, _fill(const Color(0xFFB0202C)));
          canvas.drawCircle(const Offset(0, -1.06), 0.015, _fill(LookPainter.gold));
        }
      case AvatarHead.operaHelmet:
        // L'elmo con le corna della prima donna wagneriana.
        for (final side in [-1.0, 1.0]) {
          canvas.drawPath(
            Path()
              ..moveTo(side * 0.14, -1.0)
              ..quadraticBezierTo(side * 0.32, -1.02, side * 0.31, -1.28)
              ..quadraticBezierTo(side * 0.25, -1.12, side * 0.13, -1.1)
              ..close(),
            p(const Color(0xFFEDE2C8)),
          );
        }
        canvas.drawArc(
          Rect.fromCenter(center: const Offset(0, -0.98), width: 0.36, height: 0.4),
          pi,
          pi,
          true,
          p(const Color(0xFFA8AEB8)),
        );
        canvas.drawRect(const Rect.fromLTRB(-0.185, -1.0, 0.185, -0.95), p(const Color(0xFFC9A04A)));
        if (detail) {
          canvas.drawArc(
            Rect.fromCenter(center: const Offset(-0.03, -1.03), width: 0.24, height: 0.24),
            pi * 1.15,
            pi * 0.35,
            false,
            _line(Colors.white.withValues(alpha: 0.55), 0.014),
          );
          canvas.drawLine(const Offset(0, -1.18), const Offset(0, -1.0), _line(const Color(0xFF7A808A), 0.014));
          for (final x in [-0.15, -0.075, 0.0, 0.075, 0.15]) {
            canvas.drawCircle(Offset(x, -0.975), 0.009, _fill(const Color(0xFF6A5020)));
          }
        }
      case AvatarHead.beekeeper:
        // Il cappello dell'apicoltore con il velo, e un'ape di passaggio.
        const straw = Color(0xFFE2D2A8);
        canvas.drawOval(Rect.fromCenter(center: const Offset(0, -0.97), width: 0.6, height: 0.085), p(straw));
        canvas.drawPath(
          Path()
            ..moveTo(-0.15, -0.975)
            ..quadraticBezierTo(-0.16, -1.17, 0, -1.17)
            ..quadraticBezierTo(0.16, -1.17, 0.15, -0.975)
            ..close(),
          p(straw),
        );
        final veil = Path()
          ..moveTo(-0.28, -0.965)
          ..lineTo(0.28, -0.965)
          ..lineTo(0.22, -0.64)
          ..lineTo(-0.22, -0.64)
          ..close();
        if (detail) {
          canvas.drawPath(veil, _fill(const Color(0xFF2A2A2E).withValues(alpha: 0.35)));
          canvas.save();
          canvas.clipPath(veil);
          final mesh = _line(Colors.black.withValues(alpha: 0.28), 0.004);
          for (var x = -0.3; x < 0.3; x += 0.025) {
            canvas.drawLine(Offset(x, -0.97), Offset(x * 0.8, -0.64), mesh);
          }
          for (var y = -0.95; y < -0.64; y += 0.025) {
            canvas.drawLine(Offset(-0.3, y), Offset(0.3, y), mesh);
          }
          canvas.restore();
          canvas.drawRect(const Rect.fromLTRB(-0.152, -1.03, 0.152, -0.99), _fill(_dark(straw, 0.3)));
          // L'ape.
          const bee = Offset(0.2, -1.1);
          canvas.drawOval(
            Rect.fromCenter(center: bee.translate(-0.01, -0.025), width: 0.03, height: 0.04),
            _fill(Colors.white.withValues(alpha: 0.6)),
          );
          canvas.drawOval(Rect.fromCenter(center: bee, width: 0.05, height: 0.032), _fill(const Color(0xFFE9C23A)));
          for (final dx in [-0.006, 0.01]) {
            canvas.drawLine(bee.translate(dx, -0.015), bee.translate(dx, 0.015), _line(_ink, 0.007));
          }
        }
      case AvatarHead.roosterHead:
        // Il costume da gallo: il cappuccio bianco, la cresta, il becco.
        final hood = Path()
          ..fillType = PathFillType.evenOdd
          ..moveTo(-0.2, -0.72)
          ..quadraticBezierTo(-0.25, -1.16, 0, -1.16)
          ..quadraticBezierTo(0.25, -1.16, 0.2, -0.72)
          ..close()
          ..addOval(Rect.fromCenter(center: const Offset(0, -0.85), width: 0.27, height: 0.3));
        for (final (x, y, r) in [(-0.07, -1.17, 0.045), (0.0, -1.21, 0.05), (0.07, -1.17, 0.045)]) {
          canvas.drawCircle(Offset(x, y), r, p(const Color(0xFFD8322E)));
        }
        canvas.drawPath(hood, p(const Color(0xFFF4EEE2)));
        if (detail) {
          canvas.drawPath(hood, _line(const Color(0xFFBDB4A4), 0.008));
          for (final x in [-0.065, 0.065]) {
            canvas.drawCircle(Offset(x, -1.07), 0.022, _fill(Colors.white));
            canvas.drawCircle(Offset(x + 0.004, -1.068), 0.012, _fill(_ink));
          }
          canvas.drawPath(
            Path()
              ..moveTo(-0.045, -1.04)
              ..lineTo(0.045, -1.04)
              ..lineTo(0, -0.985)
              ..close(),
            _fill(const Color(0xFFE8942A)),
          );
          canvas.drawOval(
            Rect.fromCenter(center: const Offset(0, -0.985), width: 0.03, height: 0.03),
            _fill(const Color(0xFFD8322E)),
          );
        }
      case AvatarHead.angelHalo:
        // L'aureola d'oro che galleggia sopra la testa.
        final ring = Rect.fromCenter(center: const Offset(0, -1.17), width: 0.3, height: 0.08);
        canvas.drawOval(ring, silhouette ?? _line(const Color(0xFFFFE08A), 0.026));
        if (detail) canvas.drawOval(ring, _line(Colors.white.withValues(alpha: 0.6), 0.008));
      case AvatarHead.devilHorns:
        // Due cornetti rossi.
        for (final side in [-1.0, 1.0]) {
          canvas.drawPath(
            Path()
              ..moveTo(side * 0.06, -1.07)
              ..quadraticBezierTo(side * 0.1, -1.16, side * 0.08, -1.24)
              ..quadraticBezierTo(side * 0.17, -1.16, side * 0.15, -1.04)
              ..close(),
            p(const Color(0xFFC81E1E)),
          );
        }
      case AvatarHead.propellerBeanie:
        // Lo zucchetto a spicchi con l'elica in cima.
        const wedges = [Color(0xFFD23A2E), Color(0xFFE9C23A), Color(0xFF2E5BC8), Color(0xFF2E9E4A)];
        final dome = Rect.fromCenter(center: const Offset(0, -0.965), width: 0.36, height: 0.3);
        for (var i = 0; i < 4; i++) {
          canvas.drawArc(dome, pi + i * pi / 4, pi / 4, true, p(wedges[i]));
        }
        canvas.drawLine(
          const Offset(0, -1.11),
          const Offset(0, -1.17),
          silhouette ?? _line(const Color(0xFF3A3640), 0.014),
        );
        canvas.drawOval(
          Rect.fromCenter(center: const Offset(-0.075, -1.175), width: 0.15, height: 0.035),
          p(const Color(0xFFD23A2E)),
        );
        canvas.drawOval(
          Rect.fromCenter(center: const Offset(0.075, -1.175), width: 0.15, height: 0.035),
          p(const Color(0xFFE9C23A)),
        );
        if (detail) {
          canvas.drawRect(const Rect.fromLTRB(-0.18, -0.985, 0.18, -0.955), _fill(const Color(0xFF1E1B22)));
          canvas.drawCircle(const Offset(0, -1.175), 0.016, _fill(const Color(0xFF3A3640)));
        }
      default:
        _Absurd.hat(canvas, hat, silhouette);
    }
  }

  // --- Le ali (dietro al busto) ---------------------------------------------

  /// Le ali sulle spalle ([BackItem]) e, dietro, quello che il vezzo porta
  /// alle spalle (i palloncini, il guscio, il razzo, le curve).
  static void wings(Canvas canvas, AvatarLook look) {
    switch (look.back) {
      case BackItem.angelWings:
        // Tre file di piume bianche per parte.
        for (final side in [-1.0, 1.0]) {
          for (final (i, shade) in [
            const Color(0xFFD8D2C6),
            const Color(0xFFEAE4DA),
            const Color(0xFFFAF6EE),
          ].indexed) {
            final k = 1.0 - i * 0.2;
            canvas.drawPath(
              Path()
                ..moveTo(side * 0.2, -0.5)
                ..quadraticBezierTo(side * 0.3, -1.05 * k - 0.1 * (1 - k), side * 0.52, -1.12 * k)
                ..quadraticBezierTo(side * 0.5, -0.8, side * 0.5, -0.5 + i * 0.05)
                ..close(),
              _fill(shade),
            );
          }
          final quill = _line(const Color(0xFFBDB4A4), 0.006);
          for (var t = 0.0; t < 1; t += 0.2) {
            canvas.drawLine(
              Offset(side * (0.34 + t * 0.15), -0.6 - t * 0.4),
              Offset(side * 0.5, -0.62 - t * 0.38),
              quill,
            );
          }
        }
      case BackItem.batWings:
        // Le ali da pipistrello del diavoletto, e la punta della coda.
        const membrane = Color(0xFF3A1A2E);
        for (final side in [-1.0, 1.0]) {
          final wing = Path()
            ..moveTo(side * 0.2, -0.55)
            ..lineTo(side * 0.36, -1.12)
            ..lineTo(side * 0.52, -1.0)
            ..quadraticBezierTo(side * 0.46, -0.92, side * 0.52, -0.84)
            ..quadraticBezierTo(side * 0.45, -0.76, side * 0.52, -0.68)
            ..quadraticBezierTo(side * 0.44, -0.62, side * 0.48, -0.52)
            ..close();
          canvas.drawPath(wing, _fill(membrane));
          final bone = _line(const Color(0xFF6A3A55), 0.012);
          canvas.drawLine(Offset(side * 0.22, -0.56), Offset(side * 0.36, -1.12), bone);
          for (final y in [-0.84, -0.68]) {
            canvas.drawLine(Offset(side * 0.3, -0.84), Offset(side * 0.52, y), bone);
          }
        }
        canvas.drawPath(
          Path()
            ..moveTo(0.38, -0.1)
            ..quadraticBezierTo(0.5, -0.12, 0.48, -0.26),
          _line(const Color(0xFFC81E1E), 0.016),
        );
        canvas.drawPath(
          Path()
            ..moveTo(0.48, -0.33)
            ..lineTo(0.52, -0.24)
            ..lineTo(0.44, -0.25)
            ..close(),
          _fill(const Color(0xFFC81E1E)),
        );
      case BackItem.butterflyWings:
        // Le ali di farfalla: arancio, nero e i punti bianchi.
        for (final side in [-1.0, 1.0]) {
          final upper = Rect.fromCenter(center: Offset(side * 0.38, -0.92), width: 0.28, height: 0.36);
          final lower = Rect.fromCenter(center: Offset(side * 0.4, -0.62), width: 0.2, height: 0.22);
          for (final r in [upper, lower]) {
            canvas.drawOval(r, _fill(_ink));
            canvas.drawOval(r.deflate(0.025), _fill(const Color(0xFFE8842A)));
          }
          canvas.drawLine(Offset(side * 0.26, -0.8), Offset(side * 0.48, -1.04), _line(_ink, 0.012));
          for (final c in [Offset(side * 0.45, -1.02), Offset(side * 0.48, -0.9), Offset(side * 0.46, -0.6)]) {
            canvas.drawCircle(c, 0.014, _fill(Colors.white));
          }
        }
      case BackItem.dragonWings:
        _Absurd.dragonWings(canvas);
      default:
        break;
    }
    _Absurd.back(canvas, look.accessory);
  }

  // --- Quello che si porta addosso ------------------------------------------

  static void prop(Canvas canvas, AvatarLook look) {
    switch (look.accessory) {
      case AvatarAccessory.clownNose:
        final nose = Rect.fromCircle(center: const Offset(0.006, -0.82), radius: 0.04);
        canvas.drawOval(
          nose,
          Paint()
            ..shader = LookPainter._gs(const RadialGradient(
              center: Alignment(-0.35, -0.4),
              colors: [Color(0xFFFF6A5A), Color(0xFFC81E1E), Color(0xFF7A0E0E)],
              stops: [0, 0.6, 1],
            ), nose),
        );
        canvas.drawCircle(const Offset(-0.008, -0.835), 0.01, _fill(Colors.white.withValues(alpha: 0.75)));
      case AvatarAccessory.parrot:
        // Il pappagallo sulla spalla sinistra, il becco verso l'orecchio.
        const green = Color(0xFF2E9E4A);
        const blue = Color(0xFF2E5BC8);
        const red = Color(0xFFD8322E);
        canvas.drawPath(
          Path()
            ..moveTo(-0.39, -0.64)
            ..lineTo(-0.44, -0.4)
            ..lineTo(-0.4, -0.42)
            ..lineTo(-0.36, -0.64)
            ..close(),
          _fill(blue),
        );
        canvas.drawPath(
          Path()
            ..moveTo(-0.37, -0.64)
            ..lineTo(-0.39, -0.44)
            ..lineTo(-0.36, -0.46)
            ..close(),
          _fill(red),
        );
        canvas.drawOval(Rect.fromCenter(center: const Offset(-0.37, -0.71), width: 0.12, height: 0.19), _fill(green));
        canvas.drawOval(
          Rect.fromCenter(center: const Offset(-0.385, -0.69), width: 0.07, height: 0.14),
          _fill(_dark(green, 0.3)),
        );
        canvas.drawOval(Rect.fromCenter(center: const Offset(-0.39, -0.63), width: 0.05, height: 0.05), _fill(blue));
        canvas.drawCircle(const Offset(-0.355, -0.82), 0.05, _fill(red));
        canvas.drawPath(
          Path()
            ..moveTo(-0.315, -0.84)
            ..quadraticBezierTo(-0.27, -0.835, -0.28, -0.79)
            ..lineTo(-0.315, -0.805)
            ..close(),
          _fill(const Color(0xFFE9C23A)),
        );
        canvas.drawCircle(const Offset(-0.345, -0.835), 0.014, _fill(Colors.white));
        canvas.drawCircle(const Offset(-0.342, -0.835), 0.007, _fill(_ink));
        final claw = _line(const Color(0xFF3A2A1C), 0.01);
        canvas.drawLine(const Offset(-0.38, -0.62), const Offset(-0.39, -0.59), claw);
        canvas.drawLine(const Offset(-0.35, -0.62), const Offset(-0.35, -0.59), claw);
      case AvatarAccessory.rubberDuck:
        // La paperella di gomma che fa capolino dal taschino.
        const yellow = Color(0xFFF2CC2E);
        canvas.drawOval(Rect.fromCenter(center: const Offset(0.215, -0.445), width: 0.11, height: 0.06), _fill(yellow));
        canvas.drawCircle(const Offset(0.245, -0.495), 0.033, _fill(yellow));
        canvas.drawPath(
          Path()
            ..moveTo(0.27, -0.5)
            ..lineTo(0.31, -0.49)
            ..lineTo(0.27, -0.48)
            ..close(),
          _fill(const Color(0xFFE8742A)),
        );
        canvas.drawCircle(const Offset(0.252, -0.503), 0.007, _fill(_ink));
        canvas.drawRect(const Rect.fromLTRB(0.14, -0.43, 0.29, -0.405), _fill(_dark(look.outfit.coat, 0.4)));
      case AvatarAccessory.accordion:
        // La fisarmonica al petto: la tastiera, il mantice, i bottoni.
        const red = Color(0xFFB0202C);
        canvas.save();
        canvas.translate(0, -0.18);
        canvas.drawRRect(
          RRect.fromRectAndRadius(const Rect.fromLTRB(-0.32, -0.36, -0.2, 0.08), const Radius.circular(0.02)),
          _fill(_dark(red, 0.2)),
        );
        canvas.drawRect(const Rect.fromLTRB(-0.3, -0.33, -0.22, 0.05), _fill(const Color(0xFFF2EAD8)));
        for (var y = -0.31; y < 0.04; y += 0.04) {
          canvas.drawRect(Rect.fromLTRB(-0.3, y, -0.25, y + 0.018), _fill(_ink));
        }
        for (var i = 0; i < 10; i++) {
          final x = -0.2 + i * 0.04;
          canvas.drawRect(Rect.fromLTRB(x, -0.33, x + 0.04, 0.05), _fill(i.isEven ? red : _dark(red, 0.35)));
        }
        canvas.drawRRect(
          RRect.fromRectAndRadius(const Rect.fromLTRB(0.2, -0.36, 0.32, 0.08), const Radius.circular(0.02)),
          _fill(_dark(red, 0.2)),
        );
        for (var y = -0.3; y < 0.05; y += 0.06) {
          for (final x in [0.235, 0.285]) {
            canvas.drawCircle(Offset(x, y), 0.012, _fill(const Color(0xFFF2EAD8)));
          }
        }
        canvas.drawLine(const Offset(-0.2, -0.33), const Offset(0.2, -0.33), _line(LookPainter.gold, 0.008));
        canvas.drawLine(const Offset(-0.2, 0.05), const Offset(0.2, 0.05), _line(LookPainter.gold, 0.008));
        canvas.restore();
      case AvatarAccessory.baguetteCigar:
        // Il sigaro lungo quanto un filone di pane.
        canvas.drawLine(
          const Offset(0.03, -0.765),
          const Offset(0.45, -0.69),
          Paint()
            ..color = const Color(0xFF6A4226)
            ..strokeWidth = 0.06
            ..strokeCap = StrokeCap.round,
        );
        canvas.drawLine(
          const Offset(0.06, -0.748),
          const Offset(0.44, -0.68),
          _line(Colors.white.withValues(alpha: 0.12), 0.012),
        );
        canvas.drawLine(
          const Offset(0.1, -0.758),
          const Offset(0.12, -0.754),
          Paint()
            ..color = const Color(0xFFC9A54E)
            ..strokeWidth = 0.064,
        );
        canvas.drawLine(
          const Offset(0.104, -0.757),
          const Offset(0.116, -0.755),
          Paint()
            ..color = const Color(0xFFB0202C)
            ..strokeWidth = 0.03,
        );
        canvas.drawCircle(const Offset(0.46, -0.688), 0.03, _fill(const Color(0xFF9A948A)));
        canvas.drawCircle(const Offset(0.468, -0.687), 0.018, _fill(LookPainter.ember));
      default:
        _Absurd.prop(canvas, look);
    }
  }
}
