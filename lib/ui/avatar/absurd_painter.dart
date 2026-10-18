part of 'look_painter.dart';

/// L'assurdo: le stramberie più rumorose della bottega. Teste di pesce,
/// dinosauri, razzi, piccioni. Stesse coordinate del busto di [LookPainter]
/// (la testa al centro in (0, -0.86), le spalle a -0.6); i pezzi grossi
/// escono dal busto, sopra la testa o dietro le spalle.
abstract final class _Absurd {
  static Color _dark(Color c, double t) => LookPainter._dark(c, t);
  static Color _bright(Color c, double t) => LookPainter._bright(c, t);
  static const _ink = LookPainter.ink;

  static Paint _fill(Color c) => Paint()..color = c;

  static Paint _line(Color c, double width) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round;

  static const _rainbow = [
    Color(0xFFD23A2E),
    Color(0xFFE8842A),
    Color(0xFFE9C23A),
    Color(0xFF2E9E4A),
    Color(0xFF2E5BC8),
    Color(0xFF8A3EB0),
  ];

  static Path _star(Offset c, double r) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final a = -pi / 2 + i * pi / 5;
      final k = i.isEven ? r : r * 0.45;
      final p = Offset(c.dx + cos(a) * k, c.dy + sin(a) * k);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  /// Un cappuccio che lascia scoperta la faccia.
  static Path _hood(double top, double side) => Path()
    ..fillType = PathFillType.evenOdd
    ..moveTo(-side, -0.66)
    ..quadraticBezierTo(-side - 0.05, top, 0, top)
    ..quadraticBezierTo(side + 0.05, top, side, -0.66)
    ..close()
    ..addOval(Rect.fromCenter(center: const Offset(0, -0.85), width: 0.27, height: 0.3));

  // --- Le stoffe dei costumi ------------------------------------------------

  static void fabric(Canvas canvas, AvatarOutfit outfit) {
    switch (outfit.pattern) {
      case CoatPattern.pizza:
        // La fetta: la crosta in alto, il pomodoro, la mozzarella, i salami.
        canvas.drawRect(const Rect.fromLTRB(-0.6, -0.7, 0.6, 0.6), _fill(const Color(0xFFD8402E)));
        final cheese = _fill(outfit.coat);
        canvas.drawPath(
          Path()
            ..moveTo(-0.6, -0.56)
            ..lineTo(0.6, -0.56)
            ..lineTo(0.5, -0.2)
            ..quadraticBezierTo(0.42, -0.1, 0.38, -0.24)
            ..lineTo(0.2, 0.1)
            ..quadraticBezierTo(0.12, 0.2, 0.06, 0.06)
            ..lineTo(-0.16, 0.3)
            ..quadraticBezierTo(-0.24, 0.36, -0.28, 0.2)
            ..lineTo(-0.6, 0.0)
            ..close(),
          cheese,
        );
        for (final c in const [Offset(-0.3, -0.36), Offset(0.24, -0.4), Offset(0.02, -0.18), Offset(-0.36, -0.05), Offset(0.36, 0.1), Offset(-0.06, 0.32)]) {
          canvas.drawCircle(c, 0.075, _fill(const Color(0xFFB0202C)));
          canvas.drawCircle(c, 0.075, _line(const Color(0xFF7A1418), 0.01));
          canvas.drawCircle(c.translate(-0.02, -0.02), 0.012, _fill(const Color(0xFFF2C9B0)));
        }
        for (final c in const [Offset(-0.14, -0.44), Offset(0.42, -0.3), Offset(0.16, -0.1), Offset(-0.22, 0.1)]) {
          canvas.drawOval(Rect.fromCenter(center: c, width: 0.07, height: 0.04), _fill(const Color(0xFF2E7A2E)));
        }
        canvas.drawRect(const Rect.fromLTRB(-0.6, -0.7, 0.6, -0.56), _fill(const Color(0xFFC8862E)));
        canvas.drawLine(const Offset(-0.6, -0.56), const Offset(0.6, -0.56), _line(const Color(0xFF8A5A1E), 0.014));
      case CoatPattern.cactus:
        // Le costole verdi e le spine, con un fiore rosa sul petto.
        final rib = _line(_dark(outfit.coat, 0.3), 0.03);
        for (final x in [-0.45, -0.27, -0.09, 0.09, 0.27, 0.45]) {
          canvas.drawLine(Offset(x, -0.7), Offset(x * 1.05, 0.6), rib);
        }
        final spine = _line(const Color(0xFFF6EED2), 0.01);
        for (var y = -0.55; y < 0.6; y += 0.13) {
          for (final x in [-0.36, -0.18, 0.0, 0.18, 0.36]) {
            final c = Offset(x + ((y * 10).round().isOdd ? 0.03 : 0), y);
            canvas.drawLine(c, c.translate(-0.025, -0.03), spine);
            canvas.drawLine(c, c.translate(0.025, -0.03), spine);
          }
        }
        for (var i = 0; i < 6; i++) {
          final a = i * pi / 3;
          canvas.drawCircle(Offset(0.25 + cos(a) * 0.04, -0.3 + sin(a) * 0.04), 0.035, _fill(outfit.accent));
        }
        canvas.drawCircle(const Offset(0.25, -0.3), 0.025, _fill(const Color(0xFFF2CC2E)));
      case CoatPattern.ghost:
        // Il lenzuolo: pieghe grigie e due buchi neri sul petto, "buu".
        final fold = _line(_dark(outfit.coat, 0.14), 0.02);
        for (final x in [-0.4, -0.2, 0.2, 0.4]) {
          canvas.drawPath(
            Path()
              ..moveTo(x * 0.5, -0.6)
              ..quadraticBezierTo(x * 1.1, -0.1, x, 0.6),
            fold,
          );
        }
        for (final x in [-0.1, 0.1]) {
          canvas.drawOval(Rect.fromCenter(center: Offset(x, -0.3), width: 0.08, height: 0.12), _fill(outfit.accent));
        }
        canvas.drawOval(const Rect.fromLTRB(-0.05, -0.18, 0.05, -0.06), _fill(outfit.accent));
      case CoatPattern.mummy:
        // Le bende storte, una che penzola, qualche macchia di polvere.
        final band = _line(_dark(outfit.coat, 0.22), 0.012);
        for (var y = -0.66; y < 0.6; y += 0.085) {
          canvas.drawLine(Offset(-0.6, y + 0.03), Offset(0.6, y - 0.03), band);
        }
        for (var y = -0.6; y < 0.6; y += 0.26) {
          canvas.drawLine(Offset(-0.6, y - 0.05), Offset(0.6, y + 0.08), band);
        }
        canvas.drawPath(
          Path()
            ..moveTo(0.3, -0.2)
            ..lineTo(0.36, -0.2)
            ..quadraticBezierTo(0.42, 0.05, 0.34, 0.2)
            ..lineTo(0.29, 0.18)
            ..quadraticBezierTo(0.36, 0.04, 0.3, -0.2)
            ..close(),
          _fill(_bright(outfit.coat, 0.1)),
        );
        for (final c in const [Offset(-0.3, -0.3), Offset(0.12, 0.1), Offset(-0.1, 0.35)]) {
          canvas.drawOval(Rect.fromCenter(center: c, width: 0.09, height: 0.05), _fill(outfit.accent.withValues(alpha: 0.35)));
        }
      default:
        break;
    }
  }

  static void collar(Canvas canvas, AvatarOutfit outfit) {
    switch (outfit.pattern) {
      case CoatPattern.cactus:
        // Il vaso di terracotta in vita.
        canvas.drawRect(const Rect.fromLTRB(-0.6, 0.3, 0.6, 0.6), _fill(const Color(0xFFC0623A)));
        canvas.drawRect(const Rect.fromLTRB(-0.6, 0.26, 0.6, 0.34), _fill(const Color(0xFFA34E2C)));
      case CoatPattern.ghost:
        // Il lenzuolo sale fino alla nuca.
        canvas.drawOval(const Rect.fromLTRB(-0.2, -0.7, 0.2, -0.56), _fill(outfit.coat));
      case CoatPattern.mummy:
        canvas.drawRect(const Rect.fromLTRB(-0.1, -0.68, 0.1, -0.58), _fill(outfit.coat));
        canvas.drawLine(const Offset(-0.1, -0.64), const Offset(0.1, -0.66), _line(_dark(outfit.coat, 0.22), 0.01));
      default:
        break;
    }
  }

  // --- La barba ------------------------------------------------------------

  static void mark(Canvas canvas, FaceMark mark, Color hair) {
    if (mark != FaceMark.vikingBeard) return;
    // La barba del vichingo, rossa, fino al petto, in due trecce.
    const red = Color(0xFFC0582A);
    final beard = Path()
      ..moveTo(-0.16, -0.86)
      ..quadraticBezierTo(-0.2, -0.6, -0.1, -0.5)
      ..lineTo(0.1, -0.5)
      ..quadraticBezierTo(0.2, -0.6, 0.16, -0.86)
      ..quadraticBezierTo(0.14, -0.74, 0.06, -0.73)
      ..quadraticBezierTo(0, -0.76, -0.06, -0.73)
      ..quadraticBezierTo(-0.14, -0.74, -0.16, -0.86)
      ..close();
    canvas.drawPath(beard, _fill(red));
    for (final side in [-1.0, 1.0]) {
      for (var i = 0; i < 4; i++) {
        canvas.drawOval(
          Rect.fromCenter(center: Offset(side * 0.06, -0.47 + i * 0.065), width: 0.06, height: 0.075),
          _fill(i.isEven ? red : _dark(red, 0.12)),
        );
      }
      canvas.drawRect(Rect.fromCenter(center: Offset(side * 0.06, -0.21), width: 0.05, height: 0.025), _fill(const Color(0xFFC9A54E)));
      canvas.drawPath(
        Path()
          ..moveTo(side * 0.04, -0.2)
          ..lineTo(side * 0.08, -0.2)
          ..lineTo(side * 0.07, -0.14)
          ..lineTo(side * 0.05, -0.14)
          ..close(),
        _fill(red),
      );
    }
    // I baffi a manubrio sopra la bocca.
    canvas.drawPath(
      Path()
        ..moveTo(0, -0.8)
        ..quadraticBezierTo(0.1, -0.82, 0.15, -0.76)
        ..quadraticBezierTo(0.08, -0.77, 0, -0.765)
        ..quadraticBezierTo(-0.08, -0.77, -0.15, -0.76)
        ..quadraticBezierTo(-0.1, -0.82, 0, -0.8)
        ..close(),
      _fill(_dark(red, 0.15)),
    );
    canvas.drawOval(const Rect.fromLTRB(-0.03, -0.765, 0.03, -0.74), _fill(const Color(0xFF6A2018)));
    final strand = _line(_bright(red, 0.25), 0.006);
    for (final x in [-0.1, -0.04, 0.04, 0.1]) {
      canvas.drawLine(Offset(x, -0.7), Offset(x * 0.8, -0.56), strand);
    }
  }

  // --- Gli occhiali --------------------------------------------------------

  static void glasses(Canvas canvas, AvatarGlasses glasses) {
    switch (glasses) {
      case AvatarGlasses.googlyEyes:
        // Gli occhi mobili, enormi, che guardano ciascuno per conto suo.
        for (final (x, pupil) in const [(-0.07, Offset(-0.02, 0.02)), (0.07, Offset(0.015, -0.025))]) {
          final c = Offset(x, -0.88);
          canvas.drawCircle(c, 0.06, _fill(Colors.white));
          canvas.drawCircle(c, 0.06, _line(_ink, 0.01));
          canvas.drawCircle(c + pupil, 0.03, _fill(_ink));
          canvas.drawCircle(c + pupil.translate(-0.01, -0.01), 0.008, _fill(Colors.white));
        }
      case AvatarGlasses.glasses3d:
        // Gli occhialini del cinema: montatura bianca, rosso e blu.
        canvas.drawRRect(
          RRect.fromRectAndRadius(const Rect.fromLTRB(-0.15, -0.92, 0.15, -0.835), const Radius.circular(0.012)),
          _fill(const Color(0xFFF4F0E6)),
        );
        canvas.drawRect(const Rect.fromLTRB(-0.13, -0.905, -0.02, -0.85), _fill(const Color(0xFFE02A2A).withValues(alpha: 0.85)));
        canvas.drawRect(const Rect.fromLTRB(0.02, -0.905, 0.13, -0.85), _fill(const Color(0xFF2AB0E8).withValues(alpha: 0.85)));
        canvas.drawLine(const Offset(-0.11, -0.895), const Offset(-0.07, -0.895), _line(Colors.white.withValues(alpha: 0.6), 0.006));
      case AvatarGlasses.bulbMonocle:
        // Il monocolo con la lampadina accesa sopra: un'idea.
        canvas.drawCircle(const Offset(0.065, -0.875), 0.05, _line(LookPainter.gold, 0.014));
        canvas.drawCircle(const Offset(0.065, -0.875), 0.044, _fill(Colors.white.withValues(alpha: 0.18)));
        canvas.drawLine(const Offset(0.1, -0.91), const Offset(0.2, -1.04), _line(LookPainter.gold, 0.01));
        const bulb = Offset(0.22, -1.12);
        canvas.drawCircle(bulb, 0.11, _fill(const Color(0xFFFFE680).withValues(alpha: 0.25)));
        canvas.drawCircle(bulb, 0.058, _fill(const Color(0xFFFFE680)));
        canvas.drawRect(Rect.fromCenter(center: bulb.translate(0, 0.07), width: 0.05, height: 0.04), _fill(const Color(0xFF9A948A)));
        canvas.drawPath(
          Path()
            ..moveTo(bulb.dx - 0.02, bulb.dy + 0.03)
            ..lineTo(bulb.dx - 0.01, bulb.dy - 0.01)
            ..lineTo(bulb.dx + 0.01, bulb.dy + 0.01)
            ..lineTo(bulb.dx + 0.02, bulb.dy - 0.02),
          _line(const Color(0xFFE8842A), 0.008),
        );
        final ray = _line(const Color(0xFFFFE680), 0.012);
        for (var i = 0; i < 5; i++) {
          final a = -pi * 0.95 + i * pi * 0.225;
          canvas.drawLine(bulb + Offset(cos(a), sin(a)) * 0.08, bulb + Offset(cos(a), sin(a)) * 0.12, ray);
        }
      default:
        break;
    }
  }

  // --- I cappelli ----------------------------------------------------------

  static void hat(Canvas canvas, AvatarHead hat, Paint? silhouette) {
    Paint p(Color c) => silhouette ?? _fill(c);
    Color k(Color c) => silhouette?.color ?? c;
    final detail = silhouette == null;
    switch (hat) {
      case AvatarHead.fishHead:
        // La testa di pesce: la faccia esce dalla bocca spalancata.
        const scale = Color(0xFF3E9EC0);
        canvas.drawPath(
          Path()
            ..moveTo(0, -1.12)
            ..lineTo(-0.1, -1.3)
            ..lineTo(0.1, -1.3)
            ..close(),
          p(const Color(0xFFE8842A)),
        );
        final body = Path()
          ..fillType = PathFillType.evenOdd
          ..addOval(const Rect.fromLTRB(-0.27, -1.18, 0.27, -0.6))
          ..addOval(Rect.fromCenter(center: const Offset(0, -0.85), width: 0.27, height: 0.3));
        canvas.drawPath(body, p(scale));
        if (detail) {
          final lip = _line(const Color(0xFFE85A6A), 0.03);
          canvas.drawOval(Rect.fromCenter(center: const Offset(0, -0.85), width: 0.28, height: 0.31), lip);
          final scaleLine = _line(_dark(scale, 0.3), 0.008);
          for (final c in const [Offset(-0.21, -0.9), Offset(-0.2, -0.78), Offset(0.21, -0.9), Offset(0.2, -0.78), Offset(-0.12, -1.06), Offset(0.12, -1.06)]) {
            canvas.drawArc(Rect.fromCenter(center: c, width: 0.06, height: 0.05), 0, pi, false, scaleLine);
          }
          for (final side in [-1.0, 1.0]) {
            final eye = Offset(side * 0.13, -1.08);
            canvas.drawCircle(eye, 0.055, _fill(Colors.white));
            canvas.drawCircle(eye, 0.055, _line(_ink, 0.008));
            canvas.drawCircle(eye.translate(side * 0.012, 0.005), 0.026, _fill(_ink));
            canvas.drawPath(
              Path()
                ..moveTo(side * 0.26, -0.82)
                ..lineTo(side * 0.38, -0.9)
                ..lineTo(side * 0.36, -0.72)
                ..close(),
              _fill(const Color(0xFFE8842A)),
            );
          }
        }
      case AvatarHead.dinoHood:
        // Il cappuccio da dinosauro: verde, le placche arancio, i dentini.
        const green = Color(0xFF4CAF50);
        for (var i = 0; i < 5; i++) {
          final a = pi * (1.15 + i * 0.175);
          final c = Offset(cos(a) * 0.22, -0.92 + sin(a) * 0.24);
          canvas.drawPath(
            Path()
              ..moveTo(c.dx - 0.05, c.dy + 0.02)
              ..lineTo(c.dx + cos(a) * 0.09, c.dy + sin(a) * 0.09)
              ..lineTo(c.dx + 0.05, c.dy + 0.02)
              ..close(),
            p(const Color(0xFFE8842A)),
          );
        }
        canvas.drawPath(_hood(-1.17, 0.21), p(green));
        if (detail) {
          final teeth = _fill(Colors.white);
          for (var i = 0; i < 7; i++) {
            final x = -0.12 + i * 0.04;
            canvas.drawPath(
              Path()
                ..moveTo(x - 0.015, -0.99)
                ..lineTo(x, -0.955)
                ..lineTo(x + 0.015, -0.99)
                ..close(),
              teeth,
            );
          }
          for (final x in [-0.08, 0.08]) {
            canvas.drawCircle(Offset(x, -1.08), 0.03, _fill(Colors.white));
            canvas.drawCircle(Offset(x, -1.08), 0.016, _fill(_ink));
          }
          for (final c in const [Offset(-0.19, -0.8), Offset(0.19, -0.76), Offset(0.15, -1.02)]) {
            canvas.drawCircle(c, 0.018, _fill(_dark(green, 0.25)));
          }
        }
      case AvatarHead.astronautHelmet:
        // La bolla di vetro dell'astronauta, con il collare e l'antenna.
        canvas.drawLine(const Offset(0.16, -1.1), const Offset(0.22, -1.26), _line(k(const Color(0xFFB8BCC6)), 0.014));
        canvas.drawCircle(const Offset(0.22, -1.27), 0.025, p(const Color(0xFFE02A2A)));
        if (!detail) {
          canvas.drawCircle(const Offset(0, -0.88), 0.28, _line(k(Colors.white), 0.03));
          return;
        }
        canvas.drawCircle(const Offset(0, -0.88), 0.28, _fill(const Color(0xFF9FD8F0).withValues(alpha: 0.18)));
        canvas.drawCircle(const Offset(0, -0.88), 0.28, _line(const Color(0xFFDCEFF8), 0.016));
        canvas.drawArc(
          Rect.fromCircle(center: const Offset(0, -0.88), radius: 0.23),
          pi * 1.1,
          pi * 0.35,
          false,
          _line(Colors.white.withValues(alpha: 0.8), 0.022),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(const Rect.fromLTRB(-0.26, -0.66, 0.26, -0.57), const Radius.circular(0.03)),
          _fill(const Color(0xFFE6E8EE)),
        );
        for (final x in [-0.16, -0.08, 0.0, 0.08, 0.16]) {
          canvas.drawCircle(Offset(x, -0.615), 0.014, _fill(const Color(0xFF8A8E9A)));
        }
      case AvatarHead.unicornHorn:
        // Il cerchietto con il corno d'oro a spirale e due orecchie.
        canvas.drawArc(
          const Rect.fromLTRB(-0.18, -1.12, 0.18, -0.8),
          pi,
          pi,
          false,
          _line(k(const Color(0xFFE85A9A)), 0.03),
        );
        for (final side in [-1.0, 1.0]) {
          canvas.drawPath(
            Path()
              ..moveTo(side * 0.09, -1.08)
              ..lineTo(side * 0.16, -1.2)
              ..lineTo(side * 0.17, -1.04)
              ..close(),
            p(Colors.white),
          );
        }
        final horn = Path()
          ..moveTo(-0.045, -1.1)
          ..lineTo(0.0, -1.38)
          ..lineTo(0.045, -1.1)
          ..close();
        canvas.drawPath(horn, p(const Color(0xFFF2CC4E)));
        if (detail) {
          final twist = _line(const Color(0xFFC9963A), 0.009);
          for (var y = -1.13; y > -1.33; y -= 0.045) {
            final w = 0.045 * (y + 1.38) / 0.28;
            canvas.drawLine(Offset(-w, y), Offset(w, y - 0.025), twist);
          }
          for (final (i, x) in [-0.11, -0.06, 0.06, 0.11].indexed) {
            canvas.drawCircle(Offset(x, -1.08 + (i == 1 || i == 2 ? -0.02 : 0)), 0.022, _fill(_rainbow[i * 2 % 6]));
          }
        }
      case AvatarHead.spaghettiHat:
        // Un piatto di spaghetti al pomodoro in testa, con la forchetta.
        canvas.drawOval(const Rect.fromLTRB(-0.26, -1.08, 0.26, -0.98), p(Colors.white));
        if (detail) canvas.drawOval(const Rect.fromLTRB(-0.26, -1.08, 0.26, -0.98), _line(const Color(0xFF2E5BC8), 0.01));
        canvas.drawOval(const Rect.fromLTRB(-0.18, -1.2, 0.18, -1.0), p(const Color(0xFFF2D27A)));
        if (detail) {
          final noodle = _line(const Color(0xFFD8B050), 0.008);
          for (var i = 0; i < 7; i++) {
            canvas.drawArc(
              Rect.fromCenter(center: Offset(-0.12 + i * 0.04, -1.08 - (i % 3) * 0.02), width: 0.1, height: 0.07),
              i * 0.9,
              pi * 1.2,
              false,
              noodle,
            );
          }
          // Due spaghetti che pendono sulla fronte.
          canvas.drawPath(
            Path()
              ..moveTo(-0.08, -1.0)
              ..quadraticBezierTo(-0.11, -0.94, -0.07, -0.92),
            _line(const Color(0xFFF2D27A), 0.012),
          );
          canvas.drawPath(
            Path()
              ..moveTo(0.12, -1.0)
              ..quadraticBezierTo(0.15, -0.9, 0.12, -0.86),
            _line(const Color(0xFFF2D27A), 0.012),
          );
          canvas.drawOval(const Rect.fromLTRB(-0.09, -1.2, 0.09, -1.11), _fill(const Color(0xFFC8282E)));
          for (final c in const [Offset(-0.03, -1.19), Offset(0.04, -1.17)]) {
            canvas.drawCircle(c, 0.028, _fill(const Color(0xFF7A4A2E)));
          }
          canvas.drawOval(const Rect.fromLTRB(0.01, -1.22, 0.05, -1.2), _fill(const Color(0xFF2E9E4A)));
          final fork = _line(const Color(0xFFB8BCC6), 0.014);
          canvas.drawLine(const Offset(0.06, -1.14), const Offset(0.2, -1.34), fork);
          for (final dx in [-0.02, 0.0, 0.02]) {
            canvas.drawLine(Offset(0.05 + dx, -1.12), Offset(0.05 + dx, -1.06), _line(const Color(0xFFB8BCC6), 0.007));
          }
        }
      case AvatarHead.octopusHat:
        // Il polpo viola abbracciato alla testa, i tentacoli giù sulle guance.
        const purple = Color(0xFF8A3EB0);
        final tentacle = _line(k(purple), 0.045);
        for (final side in [-1.0, 1.0]) {
          for (var i = 0; i < 2; i++) {
            final x = side * (0.15 + i * 0.07);
            canvas.drawPath(
              Path()
                ..moveTo(x, -0.95)
                ..quadraticBezierTo(x + side * 0.08, -0.8, x - side * 0.02, -0.7 + i * 0.02)
                ..quadraticBezierTo(x - side * 0.06, -0.66, x - side * 0.03, -0.62 + i * 0.03),
              tentacle,
            );
          }
        }
        canvas.drawOval(const Rect.fromLTRB(-0.22, -1.3, 0.22, -0.94), p(purple));
        canvas.drawPath(
          Path()
            ..moveTo(-0.19, -0.99)
            ..quadraticBezierTo(0, -1.06, 0.19, -0.99)
            ..lineTo(0.17, -0.92)
            ..quadraticBezierTo(0, -0.98, -0.17, -0.92)
            ..close(),
          p(_dark(purple, 0.1)),
        );
        if (detail) {
          for (final side in [-1.0, 1.0]) {
            for (var i = 0; i < 3; i++) {
              canvas.drawCircle(Offset(side * (0.2 + i * 0.01), -0.86 + i * 0.07), 0.01, _fill(const Color(0xFFE6B8F0)));
            }
            canvas.drawCircle(Offset(side * 0.08, -1.12), 0.04, _fill(Colors.white));
            canvas.drawCircle(Offset(side * 0.075, -1.115), 0.02, _fill(_ink));
          }
          canvas.drawArc(const Rect.fromLTRB(-0.04, -1.08, 0.04, -1.03), 0, pi, false, _line(_ink, 0.01));
          canvas.drawOval(const Rect.fromLTRB(-0.12, -1.27, -0.04, -1.22), _fill(Colors.white.withValues(alpha: 0.3)));
        }
      case AvatarHead.ufoHat:
        // Il disco volante con il raggio traente e l'alieno verde nella cupola.
        if (detail) {
          canvas.drawPath(
            Path()
              ..moveTo(-0.08, -1.12)
              ..lineTo(0.08, -1.12)
              ..lineTo(0.22, -0.98)
              ..lineTo(-0.22, -0.98)
              ..close(),
            _fill(const Color(0xFFB8F06A).withValues(alpha: 0.28)),
          );
        }
        canvas.drawOval(const Rect.fromLTRB(-0.11, -1.3, 0.11, -1.12), p(const Color(0xFFBFE6F2)));
        if (detail) {
          canvas.drawCircle(const Offset(0, -1.19), 0.04, _fill(const Color(0xFF6AD04A)));
          for (final x in [-0.016, 0.016]) {
            canvas.drawOval(Rect.fromCenter(center: Offset(x, -1.195), width: 0.018, height: 0.026), _fill(_ink));
          }
          canvas.drawLine(const Offset(-0.02, -1.23), const Offset(-0.04, -1.27), _line(const Color(0xFF6AD04A), 0.008));
          canvas.drawLine(const Offset(0.02, -1.23), const Offset(0.04, -1.27), _line(const Color(0xFF6AD04A), 0.008));
          canvas.drawOval(const Rect.fromLTRB(-0.11, -1.3, 0.11, -1.12), _fill(Colors.white.withValues(alpha: 0.18)));
        }
        canvas.drawOval(const Rect.fromLTRB(-0.28, -1.2, 0.28, -1.1), p(const Color(0xFF9AA2B0)));
        if (detail) {
          canvas.drawOval(const Rect.fromLTRB(-0.28, -1.17, 0.28, -1.1), _fill(const Color(0xFF6E7684)));
          for (final (i, x) in [-0.2, -0.1, 0.0, 0.1, 0.2].indexed) {
            canvas.drawCircle(Offset(x, -1.14), 0.014, _fill(i.isEven ? const Color(0xFFFFE680) : const Color(0xFFE02A2A)));
          }
        }
      case AvatarHead.birthdayCake:
        // La torta a due piani con le candeline accese.
        canvas.drawRect(const Rect.fromLTRB(-0.2, -1.1, 0.2, -0.98), p(const Color(0xFFF2B8C8)));
        canvas.drawRect(const Rect.fromLTRB(-0.13, -1.2, 0.13, -1.1), p(const Color(0xFFF8EEDC)));
        for (final x in [-0.08, 0.0, 0.08]) {
          canvas.drawRect(Rect.fromLTRB(x - 0.01, -1.28, x + 0.01, -1.2), p(_rainbow[((x + 0.08) * 25).round() * 2 % 6]));
        }
        if (detail) {
          final icing = _fill(Colors.white);
          for (var x = -0.2; x < 0.2; x += 0.05) {
            canvas.drawCircle(Offset(x + 0.025, -1.1), 0.025, icing);
          }
          for (var x = -0.13; x < 0.13; x += 0.052) {
            canvas.drawCircle(Offset(x + 0.026, -1.2), 0.02, _fill(const Color(0xFFE85A9A)));
          }
          for (final (i, c) in const [Offset(-0.15, -1.04), Offset(-0.05, -1.03), Offset(0.06, -1.045), Offset(0.15, -1.035)].indexed) {
            canvas.drawCircle(c, 0.012, _fill(_rainbow[i + 1]));
          }
          canvas.drawCircle(const Offset(0.1, -1.23), 0.018, _fill(const Color(0xFFC8282E)));
          for (final x in [-0.08, 0.0, 0.08]) {
            canvas.drawOval(Rect.fromCenter(center: Offset(x, -1.305), width: 0.026, height: 0.045), _fill(const Color(0xFFFFB02E)));
            canvas.drawOval(Rect.fromCenter(center: Offset(x, -1.298), width: 0.012, height: 0.022), _fill(const Color(0xFFFFF0A0)));
          }
        }
      case AvatarHead.rainbowAfro:
        // L'afro gigante a fasce arcobaleno.
        for (final (i, c) in _rainbow.indexed) {
          final r = 0.36 - i * 0.04;
          canvas.drawPath(
            Path.combine(
              PathOperation.difference,
              Path()..addOval(Rect.fromCircle(center: Offset(0, -0.94 - i * 0.012), radius: r)),
              Path()..addOval(Rect.fromCenter(center: const Offset(0, -0.84), width: 0.29, height: 0.34)),
            ),
            p(c),
          );
        }
        if (detail) {
          final curl = _line(Colors.black.withValues(alpha: 0.16), 0.008);
          for (var i = 0; i < 14; i++) {
            final a = i * pi / 7;
            final c = Offset(cos(a) * 0.3, -0.94 + sin(a) * 0.3);
            canvas.drawArc(Rect.fromCenter(center: c, width: 0.06, height: 0.05), a, pi * 1.3, false, curl);
          }
        }
      case AvatarHead.flamingHair:
        // I capelli in fiamme: rosso fuori, giallo dentro.
        for (final (k, c) in const [(1.0, Color(0xFFD8322E)), (0.75, Color(0xFFF07A1E)), (0.5, Color(0xFFFFD23A))]) {
          final flame = Path()..moveTo(-0.19 * (0.6 + k * 0.4), -0.86);
          const tips = [(-0.2, -1.2), (-0.1, -1.1), (-0.05, -1.36), (0.03, -1.14), (0.1, -1.3), (0.16, -1.1), (0.22, -1.18)];
          for (final (i, (x, y)) in tips.indexed) {
            final tip = Offset(x * (0.6 + k * 0.4), -0.98 + (y + 0.98) * k);
            final dip = Offset((x + (i == tips.length - 1 ? 0 : (tips[i + 1].$1 - x) / 2)) * (0.6 + k * 0.4), -1.0 - 0.02 * k);
            flame
              ..quadraticBezierTo(tip.dx - 0.04, (tip.dy - 0.98) / 2, tip.dx, tip.dy)
              ..quadraticBezierTo(tip.dx, dip.dy - 0.02, dip.dx, dip.dy);
          }
          flame
            ..lineTo(0.19 * (0.6 + k * 0.4), -0.86)
            ..quadraticBezierTo(0, -1.02, -0.19 * (0.6 + k * 0.4), -0.86)
            ..close();
          canvas.drawPath(flame, p(c));
          if (!detail) break;
        }
      case AvatarHead.starHalo:
        // Un giro di stelle che gli girano attorno alla testa, come nei fumetti.
        final orbit = Rect.fromCenter(center: const Offset(0, -1.1), width: 0.5, height: 0.14);
        if (detail) canvas.drawOval(orbit, _line(const Color(0xFFFFE680).withValues(alpha: 0.5), 0.008));
        for (var i = 0; i < 6; i++) {
          final a = i * pi / 3 + 0.3;
          final c = Offset(cos(a) * 0.25, -1.1 + sin(a) * 0.07);
          final r = 0.04 + (sin(a) + 1) * 0.012;
          canvas.drawPath(_star(c, r), p(i.isEven ? const Color(0xFFFFD23A) : const Color(0xFFF2EEE6)));
        }
      case AvatarHead.catOnHead:
        // Il gatto rosso acciambellato in testa, la coda che pende.
        const orange = Color(0xFFE8862E);
        canvas.drawPath(
          Path()
            ..moveTo(0.2, -1.04)
            ..quadraticBezierTo(0.3, -0.95, 0.24, -0.82),
          _line(k(orange), 0.04),
        );
        canvas.drawOval(const Rect.fromLTRB(-0.22, -1.2, 0.22, -1.0), p(orange));
        canvas.drawCircle(const Offset(-0.12, -1.18), 0.085, p(orange));
        for (final x in [-0.18, -0.06]) {
          canvas.drawPath(
            Path()
              ..moveTo(x - 0.035, -1.23)
              ..lineTo(x, -1.32)
              ..lineTo(x + 0.035, -1.23)
              ..close(),
            p(orange),
          );
        }
        if (detail) {
          final stripe = _line(_dark(orange, 0.3), 0.014);
          for (final x in [0.0, 0.07, 0.14]) {
            canvas.drawArc(Rect.fromCenter(center: Offset(x, -1.1), width: 0.06, height: 0.16), pi * 1.2, pi * 0.6, false, stripe);
          }
          for (final x in [-0.15, -0.09]) {
            canvas.drawArc(Rect.fromCenter(center: Offset(x, -1.18), width: 0.035, height: 0.025), 0, pi, false, _line(_ink, 0.009));
          }
          canvas.drawCircle(const Offset(-0.12, -1.155), 0.009, _fill(const Color(0xFFE85A9A)));
          final whisker = _line(Colors.white.withValues(alpha: 0.8), 0.004);
          for (final side in [-1.0, 1.0]) {
            canvas.drawLine(Offset(-0.12 + side * 0.03, -1.15), Offset(-0.12 + side * 0.1, -1.16), whisker);
            canvas.drawLine(Offset(-0.12 + side * 0.03, -1.145), Offset(-0.12 + side * 0.1, -1.13), whisker);
          }
          for (final x in [-0.1, 0.02]) {
            canvas.drawOval(Rect.fromCenter(center: Offset(x, -1.0), width: 0.06, height: 0.035), _fill(orange));
          }
        }
      default:
        break;
    }
  }

  // --- Dietro le spalle ----------------------------------------------------

  static void back(Canvas canvas, AvatarAccessory accessory) {
    switch (accessory) {
      case AvatarAccessory.snailShell:
        // Il guscio di lumaca sulla schiena, la spirale che sporge di lato.
        const shell = Rect.fromLTRB(0.06, -1.04, 0.62, -0.44);
        canvas.drawOval(shell, _fill(const Color(0xFFC08A4A)));
        canvas.drawOval(shell, _line(const Color(0xFF7A4E22), 0.02));
        final spiral = Path()..moveTo(0.34, -0.74);
        for (var t = 0.0; t < pi * 5; t += 0.2) {
          final r = 0.012 * t;
          spiral.lineTo(0.34 + cos(t) * r, -0.74 + sin(t) * r);
        }
        canvas.drawPath(spiral, _line(const Color(0xFF7A4E22), 0.018));
        canvas.drawArc(shell.deflate(0.04), pi * 1.1, pi * 0.4, false, _line(Colors.white.withValues(alpha: 0.35), 0.02));
      case AvatarAccessory.jetpack:
        // Lo zaino a razzo: due bombole rosse e le fiamme sotto.
        for (final side in [-1.0, 1.0]) {
          final tank = Rect.fromLTRB(side > 0 ? 0.36 : -0.56, -0.9, side > 0 ? 0.56 : -0.36, -0.2);
          canvas.drawPath(
            Path()
              ..moveTo(tank.left + 0.03, tank.bottom)
              ..lineTo(tank.center.dx, tank.bottom + 0.26)
              ..lineTo(tank.right - 0.03, tank.bottom)
              ..close(),
            _fill(const Color(0xFFF07A1E)),
          );
          canvas.drawPath(
            Path()
              ..moveTo(tank.left + 0.06, tank.bottom)
              ..lineTo(tank.center.dx, tank.bottom + 0.15)
              ..lineTo(tank.right - 0.06, tank.bottom)
              ..close(),
            _fill(const Color(0xFFFFE680)),
          );
          canvas.drawRRect(RRect.fromRectAndRadius(tank, const Radius.circular(0.1)), _fill(const Color(0xFFC8282E)));
          canvas.drawRect(Rect.fromLTRB(tank.left, tank.top + 0.18, tank.right, tank.top + 0.22), _fill(const Color(0xFFB8BCC6)));
          canvas.drawLine(
            Offset(tank.left + 0.05, tank.top + 0.08),
            Offset(tank.left + 0.05, tank.bottom - 0.08),
            _line(Colors.white.withValues(alpha: 0.4), 0.02),
          );
        }
      case AvatarAccessory.dragonWings:
        // Le ali del drago, verdi, enormi, con gli artigli in cima.
        const membrane = Color(0xFF2E8A4A);
        for (final side in [-1.0, 1.0]) {
          final wing = Path()
            ..moveTo(side * 0.18, -0.6)
            ..lineTo(side * 0.32, -1.25)
            ..lineTo(side * 0.6, -1.12)
            ..quadraticBezierTo(side * 0.5, -1.0, side * 0.6, -0.9)
            ..quadraticBezierTo(side * 0.5, -0.8, side * 0.6, -0.68)
            ..quadraticBezierTo(side * 0.5, -0.6, side * 0.56, -0.46)
            ..close();
          canvas.drawPath(wing, _fill(membrane));
          final bone = _line(const Color(0xFF1E5A30), 0.018);
          canvas.drawLine(Offset(side * 0.2, -0.6), Offset(side * 0.32, -1.25), bone);
          for (final y in [-1.12, -0.9, -0.68]) {
            canvas.drawLine(Offset(side * 0.3, -1.05), Offset(side * 0.6, y), bone);
          }
          canvas.drawPath(
            Path()
              ..moveTo(side * 0.3, -1.24)
              ..lineTo(side * 0.33, -1.33)
              ..lineTo(side * 0.35, -1.23)
              ..close(),
            _fill(const Color(0xFFF2EAD8)),
          );
        }
      case AvatarAccessory.balloons:
        // Il mazzo di palloncini legato alla spalla.
        const balloons = [
          (Offset(0.36, -1.2), Color(0xFFD23A2E)),
          (Offset(0.5, -1.06), Color(0xFF2E5BC8)),
          (Offset(0.24, -1.04), Color(0xFFE9C23A)),
          (Offset(0.46, -0.86), Color(0xFF2E9E4A)),
          (Offset(0.56, -1.24), Color(0xFFE85A9A)),
        ];
        final string = _line(const Color(0xFFDCD6CA), 0.006);
        for (final (c, _) in balloons) {
          canvas.drawLine(c.translate(0, 0.1), const Offset(0.36, -0.56), string);
        }
        for (final (c, color) in balloons) {
          canvas.drawOval(Rect.fromCenter(center: c, width: 0.15, height: 0.19), _fill(color));
          canvas.drawOval(Rect.fromCenter(center: c.translate(-0.03, -0.04), width: 0.03, height: 0.05), _fill(Colors.white.withValues(alpha: 0.5)));
          canvas.drawPath(
            Path()
              ..moveTo(c.dx - 0.015, c.dy + 0.1)
              ..lineTo(c.dx, c.dy + 0.09)
              ..lineTo(c.dx + 0.015, c.dy + 0.1)
              ..close(),
            _fill(color),
          );
        }
      default:
        break;
    }
  }

  // --- Davanti -------------------------------------------------------------

  static void prop(Canvas canvas, AvatarLook look) {
    switch (look.accessory) {
      case AvatarAccessory.giantBowTie:
        // Il papillon gigante a pois, largo quanto le spalle.
        const red = Color(0xFFD23A2E);
        for (final side in [-1.0, 1.0]) {
          final wing = Path()
            ..moveTo(0, -0.58)
            ..lineTo(side * 0.32, -0.72)
            ..quadraticBezierTo(side * 0.36, -0.58, side * 0.32, -0.42)
            ..close();
          canvas.drawPath(wing, _fill(red));
          canvas.drawPath(wing, _line(_dark(red, 0.35), 0.012));
          for (final c in [Offset(side * 0.14, -0.62), Offset(side * 0.24, -0.66), Offset(side * 0.25, -0.5), Offset(side * 0.16, -0.54)]) {
            canvas.drawCircle(c, 0.02, _fill(Colors.white));
          }
        }
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromCenter(center: const Offset(0, -0.58), width: 0.1, height: 0.13), const Radius.circular(0.03)),
          _fill(_dark(red, 0.2)),
        );
      case AvatarAccessory.pigeon:
        // Il piccione grigio sulla spalla destra, impettito.
        const grey = Color(0xFF8A90A0);
        canvas.drawOval(const Rect.fromLTRB(0.28, -0.76, 0.48, -0.6), _fill(grey));
        canvas.drawPath(
          Path()
            ..moveTo(0.46, -0.7)
            ..lineTo(0.56, -0.62)
            ..lineTo(0.46, -0.62)
            ..close(),
          _fill(_dark(grey, 0.25)),
        );
        canvas.drawOval(const Rect.fromLTRB(0.34, -0.72, 0.46, -0.64), _fill(_dark(grey, 0.15)));
        canvas.drawCircle(const Offset(0.3, -0.8), 0.05, _fill(const Color(0xFF5A6E7A)));
        canvas.drawOval(const Rect.fromLTRB(0.27, -0.78, 0.35, -0.7), _fill(const Color(0xFF6A9A8A)));
        canvas.drawPath(
          Path()
            ..moveTo(0.26, -0.81)
            ..lineTo(0.22, -0.795)
            ..lineTo(0.26, -0.785)
            ..close(),
          _fill(const Color(0xFF3A3530)),
        );
        canvas.drawCircle(const Offset(0.29, -0.81), 0.012, _fill(const Color(0xFFE8842A)));
        canvas.drawCircle(const Offset(0.29, -0.81), 0.005, _fill(_ink));
        final foot = _line(const Color(0xFFE85A6A), 0.01);
        canvas.drawLine(const Offset(0.36, -0.61), const Offset(0.35, -0.58), foot);
        canvas.drawLine(const Offset(0.4, -0.61), const Offset(0.41, -0.58), foot);
      case AvatarAccessory.plungerSword:
        // Lo sturalavandini brandito come una spada, la ventosa in alto.
        canvas.drawLine(const Offset(0.1, 0.2), const Offset(0.44, -0.9), _line(const Color(0xFFC08A4A), 0.04));
        canvas.drawLine(const Offset(0.11, 0.16), const Offset(0.43, -0.86), _line(Colors.white.withValues(alpha: 0.2), 0.01));
        canvas.save();
        canvas.translate(0.46, -0.96);
        canvas.rotate(0.3);
        canvas.drawPath(
          Path()
            ..moveTo(-0.11, 0.04)
            ..quadraticBezierTo(-0.1, -0.1, 0, -0.1)
            ..quadraticBezierTo(0.1, -0.1, 0.11, 0.04)
            ..close(),
          _fill(const Color(0xFFC8282E)),
        );
        canvas.drawOval(const Rect.fromLTRB(-0.11, 0.02, 0.11, 0.06), _fill(const Color(0xFF8A1418)));
        canvas.drawArc(const Rect.fromLTRB(-0.07, -0.08, 0.03, 0.02), pi * 1.1, pi * 0.4, false, _line(Colors.white.withValues(alpha: 0.4), 0.012));
        canvas.restore();
        // L'elsa: una guardia di spago e la mano.
        canvas.drawLine(const Offset(0.1, -0.02), const Offset(0.28, 0.06), _line(const Color(0xFFDCD6CA), 0.025));
      default:
        break;
    }
  }
}
