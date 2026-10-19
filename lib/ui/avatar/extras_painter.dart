part of 'look_painter.dart';

/// Il barbiere stravagante e il tatuatore: le pettinature della bottega (che
/// coprono quella dello specchio) e i tatuaggi alla marinara, dove la pelle
/// si vede (il collo, la guancia, lo scollo). Coordinate di [LookPainter].
abstract final class _Extras {
  static const _ink = Color(0xFF1E3346);
  static const _red = Color(0xFFA8262E);
  static const _green = Color(0xFF2F6A3A);
  static const _yellow = Color(0xFFD9A43A);

  static Paint _fill(Color c) => Paint()..color = c;
  static Paint _line(Color c, double w) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round;

  /// Il colore della pettinatura: le più matte hanno il loro.
  static Color _color(AvatarLook look) => switch (look.hairdo) {
    Hairdo.punkSpikes => const Color(0xFFFF3FA4),
    Hairdo.mermaidWaves => const Color(0xFF9FE3F0),
    Hairdo.flameBouffant => const Color(0xFFD8341E),
    _ => look.features.hairColor.color,
  };

  static Paint _shade(Color c, Rect r) => Paint()
    ..shader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [LookPainter._bright(c, 0.3), c, LookPainter._dark(c, 0.45)],
    ).createShader(r);

  // ---- Le pettinature ----

  static void hairdoBack(Canvas canvas, AvatarLook look, Paint? halo) {
    final c = _color(look);
    final back = halo ?? _fill(LookPainter._dark(c, 0.3));
    switch (look.hairdo) {
      case Hairdo.none:
        return;
      case Hairdo.mermaidWaves:
        final path = Path()
          ..moveTo(-0.2, -1.0)
          ..quadraticBezierTo(-0.3, -0.7, -0.24, -0.42)
          ..quadraticBezierTo(-0.3, -0.3, -0.2, -0.2)
          ..lineTo(0.2, -0.2)
          ..quadraticBezierTo(0.3, -0.3, 0.24, -0.42)
          ..quadraticBezierTo(0.3, -0.7, 0.2, -1.0)
          ..close();
        canvas.drawPath(path, back);
      case Hairdo.rainbowPonytail:
        if (halo != null) {
          canvas.drawPath(_ponytail(), halo);
        } else {
          _rainbowTail(canvas);
        }
      case Hairdo.glitterAfro || Hairdo.birdNestMane:
        canvas.drawCircle(const Offset(0, -0.95), 0.29, back);
      case Hairdo.flameBouffant:
        canvas.drawOval(Rect.fromCenter(center: const Offset(0, -0.96), width: 0.56, height: 0.42), back);
      case Hairdo.flowerCrown || Hairdo.beehive || Hairdo.spaceBuns || Hairdo.toweringPompadour:
        canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(-0.2, -1.04, 0.2, -0.78), const Radius.circular(0.12)), back);
      case Hairdo.punkSpikes || Hairdo.samuraiTopknot || Hairdo.stripedUndercut:
        break;
    }
  }

  static const _rainbow = [
    Color(0xFFD23A2E),
    Color(0xFFE8842A),
    Color(0xFFE9C23A),
    Color(0xFF2E9E4A),
    Color(0xFF2E5BC8),
    Color(0xFF8A3EB0),
  ];

  /// La coda lunghissima: raccolta stretta nel fiocco sulla tempia, si gonfia
  /// scendendo dietro la spalla e si assottiglia in punta. I due bordi sono
  /// campionati lungo la linea mediana, così le fasce seguono la forma.
  static (List<Offset>, List<Offset>) _tailEdges() {
    const p0 = Offset(0.2, -1.0), p1 = Offset(0.44, -0.98), p2 = Offset(0.46, -0.6), p3 = Offset(0.27, -0.2);
    const n = 40;
    final left = <Offset>[], right = <Offset>[];
    for (var i = 0; i <= n; i++) {
      final t = i / n, u = 1 - t;
      final pt = p0 * (u * u * u) + p1 * (3 * u * u * t) + p2 * (3 * u * t * t) + p3 * (t * t * t);
      final d = (p1 - p0) * (3 * u * u) + (p2 - p1) * (6 * u * t) + (p3 - p2) * (3 * t * t);
      final normal = Offset(-d.dy, d.dx) / d.distance;
      final w = 0.022 * u + 0.075 * pow(sin(pi * t), 0.6) * (1 - 0.3 * t);
      left.add(pt - normal * w);
      right.add(pt + normal * w);
    }
    return (left, right);
  }

  static Path _strip(List<Offset> a, List<Offset> b) {
    final path = Path()..moveTo(a.first.dx, a.first.dy);
    for (final p in a.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    for (final p in b.reversed) {
      path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  static Path _ponytail() {
    final (l, r) = _tailEdges();
    return _strip(l, r);
  }

  /// Le fasce arcobaleno corrono lungo la coda, una accanto all'altra.
  static void _rainbowTail(Canvas canvas) {
    final (l, r) = _tailEdges();
    final tail = _strip(l, r);
    final bands = _rainbow.length;
    List<Offset> at(double k) => [for (var i = 0; i < l.length; i++) Offset.lerp(l[i], r[i], k)!];
    canvas.save();
    canvas.clipPath(tail);
    for (var i = 0; i < bands; i++) {
      // Un filo di sovrapposizione, perché tra due fasce non resti una crepa.
      canvas.drawPath(_strip(at(i / bands), at(min(1.0, (i + 1.15) / bands))), _fill(_rainbow[i]));
    }
    final b = tail.getBounds();
    canvas.drawRect(
      b,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white.withValues(alpha: 0.18), Colors.white.withValues(alpha: 0), Colors.black.withValues(alpha: 0.35)],
        ).createShader(b),
    );
    // Il lucido: un filo chiaro lungo la curva, verso l'esterno.
    final shine = Path();
    final sh = at(0.72);
    for (var i = 4; i < 24; i++) {
      i == 4 ? shine.moveTo(sh[i].dx, sh[i].dy) : shine.lineTo(sh[i].dx, sh[i].dy);
    }
    canvas.drawPath(shine, _line(Colors.white.withValues(alpha: 0.4), 0.012));
    canvas.restore();
    canvas.drawPath(tail, _line(LookPainter._dark(_rainbow[5], 0.6), 0.008)..strokeJoin = StrokeJoin.round);
  }

  /// La calotta sulla fronte, comune a quasi tutte.
  static Path _cap({double top = -1.1, double fringe = -0.96}) => Path()
    ..moveTo(-0.17, -0.86)
    ..quadraticBezierTo(-0.19, top + 0.02, 0, top)
    ..quadraticBezierTo(0.19, top + 0.02, 0.17, -0.86)
    ..quadraticBezierTo(0.12, fringe - 0.02, 0, fringe)
    ..quadraticBezierTo(-0.12, fringe - 0.02, -0.17, -0.86)
    ..close();

  static void hairdoFront(Canvas canvas, AvatarLook look) {
    final c = _color(look);
    const box = Rect.fromLTRB(-0.3, -1.5, 0.3, -0.8);
    final hair = _shade(c, box);
    final shine = _line(Colors.white.withValues(alpha: 0.35), 0.012);
    switch (look.hairdo) {
      case Hairdo.none:
        return;
      case Hairdo.beehive:
        canvas.drawPath(_cap(), hair);
        final hive = Rect.fromCenter(center: const Offset(0, -1.27), width: 0.36, height: 0.5);
        canvas.drawOval(hive, hair);
        for (var y = -1.45; y < -1.08; y += 0.07) {
          canvas.drawArc(Rect.fromCenter(center: Offset(0, y), width: 0.3, height: 0.06), 0.2, pi - 0.4, false,
              _line(LookPainter._dark(c, 0.4), 0.008));
        }
        canvas.drawArc(hive.deflate(0.04), pi * 1.1, pi * 0.3, false, shine);
      case Hairdo.punkSpikes:
        // I lati rasati, poi le creste.
        canvas.drawPath(_cap(top: -1.06, fringe: -1.0), _fill(LookPainter._dark(look.features.hairColor.color, 0.2)));
        for (var i = 0; i < 7; i++) {
          final x = -0.15 + i * 0.05;
          final tip = Offset(x * 1.6, -1.42 + (i - 3).abs() * 0.04);
          canvas.drawPath(
            Path()
              ..moveTo(x - 0.03, -1.03)
              ..lineTo(tip.dx, tip.dy)
              ..lineTo(x + 0.03, -1.03)
              ..close(),
            hair,
          );
        }
      case Hairdo.spaceBuns:
        canvas.drawPath(_cap(), hair);
        for (final side in [-1.0, 1.0]) {
          final bun = Offset(side * 0.17, -1.12);
          canvas.drawCircle(bun, 0.09, hair);
          canvas.drawArc(Rect.fromCircle(center: bun, radius: 0.06), 0, pi * 1.5, false, _line(LookPainter._dark(c, 0.45), 0.008));
        }
        canvas.drawLine(const Offset(0, -1.1), const Offset(0, -0.97), _line(LookPainter._dark(c, 0.5), 0.008));
      case Hairdo.toweringPompadour:
        canvas.drawPath(_cap(top: -1.08), hair);
        final tower = Path()
          ..moveTo(-0.16, -1.0)
          ..quadraticBezierTo(-0.24, -1.42, 0.04, -1.46)
          ..quadraticBezierTo(0.26, -1.42, 0.18, -1.02)
          ..close();
        canvas.drawPath(tower, hair);
        // Il ricciolo che cade sulla fronte.
        canvas.drawArc(Rect.fromCenter(center: const Offset(0.02, -0.98), width: 0.07, height: 0.07), -pi / 2, pi * 1.6, false,
            _line(LookPainter._dark(c, 0.15), 0.016));
        canvas.drawArc(Rect.fromCenter(center: const Offset(0.0, -1.3), width: 0.2, height: 0.26), pi * 1.1, pi * 0.4, false, shine);
      case Hairdo.flowerCrown:
        canvas.drawPath(_cap(top: -1.08), hair);
        // La treccia a corona.
        for (var a = 0.0; a <= 1.0; a += 0.1) {
          final x = -0.19 + a * 0.38;
          final y = -1.04 - sin(a * pi) * 0.05;
          canvas.drawOval(Rect.fromCenter(center: Offset(x, y), width: 0.06, height: 0.045), hair);
          canvas.drawArc(Rect.fromCenter(center: Offset(x, y), width: 0.05, height: 0.03), 0.3, pi - 0.6, false,
              _line(LookPainter._dark(c, 0.5), 0.006));
        }
        for (final (x, col) in [(-0.14, const Color(0xFFE88AA8)), (-0.04, const Color(0xFFF4E3A0)), (0.07, const Color(0xFFE88AA8)), (0.16, const Color(0xFFB8D4F0))]) {
          final y = -1.06 - sin((x + 0.19) / 0.38 * pi) * 0.05;
          for (var k = 0; k < 5; k++) {
            final a = k * 2 * pi / 5;
            canvas.drawCircle(Offset(x + cos(a) * 0.016, y + sin(a) * 0.016), 0.013, _fill(col));
          }
          canvas.drawCircle(Offset(x, y), 0.008, _fill(_yellow));
        }
      case Hairdo.mermaidWaves:
        canvas.drawPath(_cap(), hair);
        for (final side in [-1.0, 1.0]) {
          final wave = Path()..moveTo(side * 0.16, -0.98);
          for (var i = 0; i < 4; i++) {
            final y = -0.9 + i * 0.12;
            wave.quadraticBezierTo(side * (0.27 + (i.isOdd ? 0.04 : -0.02)), y - 0.04, side * 0.2, y + 0.04);
          }
          wave
            ..lineTo(side * 0.14, -0.5)
            ..quadraticBezierTo(side * 0.17, -0.8, side * 0.12, -0.96)
            ..close();
          canvas.drawPath(wave, hair);
        }
        for (var i = 0; i < 6; i++) {
          canvas.drawCircle(Offset(-0.12 + i * 0.05, -1.04 + (i.isOdd ? 0.02 : 0)), 0.006, _fill(Colors.white.withValues(alpha: 0.8)));
        }
      case Hairdo.flameBouffant:
        final puff = Path()
          ..moveTo(-0.2, -0.82)
          ..quadraticBezierTo(-0.36, -1.15, -0.12, -1.24)
          ..quadraticBezierTo(0, -1.36, 0.12, -1.24)
          ..quadraticBezierTo(0.36, -1.15, 0.2, -0.82)
          ..quadraticBezierTo(0.12, -0.98, 0, -0.97)
          ..quadraticBezierTo(-0.12, -0.98, -0.2, -0.82)
          ..close();
        canvas.drawPath(puff, hair);
        for (final x in [-0.12, 0.0, 0.12]) {
          canvas.drawPath(
            Path()
              ..moveTo(x - 0.03, -1.18)
              ..quadraticBezierTo(x, -1.32, x + 0.02, -1.38)
              ..quadraticBezierTo(x + 0.04, -1.26, x + 0.03, -1.18)
              ..close(),
            _fill(const Color(0xFFF2A23A)),
          );
        }
      case Hairdo.glitterAfro:
        canvas.drawPath(_cap(top: -1.15, fringe: -0.98), hair);
        canvas.drawArc(Rect.fromCircle(center: const Offset(0, -0.95), radius: 0.29), pi, pi, true, hair);
        final rnd = Random(7);
        for (var i = 0; i < 40; i++) {
          final a = pi + rnd.nextDouble() * pi;
          final r = 0.08 + rnd.nextDouble() * 0.2;
          final p = Offset(cos(a) * r, -0.95 + sin(a) * r);
          final col = [const Color(0xFFFFE57A), const Color(0xFFFF8AD8), const Color(0xFF9AE8FF), Colors.white][i % 4];
          canvas.drawCircle(p, 0.006 + rnd.nextDouble() * 0.006, _fill(col));
        }
      case Hairdo.samuraiTopknot:
        canvas.drawPath(_cap(top: -1.08, fringe: -1.04), hair);
        canvas.drawLine(const Offset(0, -1.08), const Offset(0, -0.98), _line(LookPainter._dark(c, 0.4), 0.01));
        canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(-0.025, -1.2, 0.025, -1.08), const Radius.circular(0.02)), hair);
        canvas.drawRect(const Rect.fromLTRB(-0.03, -1.13, 0.03, -1.11), _fill(_red));
        canvas.drawOval(Rect.fromCenter(center: const Offset(0, -1.22), width: 0.07, height: 0.05), hair);
      case Hairdo.stripedUndercut:
        canvas.drawPath(_cap(top: -1.06, fringe: -1.02), _fill(LookPainter._dark(c, 0.15).withValues(alpha: 0.55)));
        // Le strisce rasate sul lato, e il ciuffo lungo pettinato di là.
        for (var i = 0; i < 3; i++) {
          canvas.drawLine(Offset(-0.17, -0.94 - i * 0.03), Offset(-0.1, -0.98 - i * 0.03), _line(look.base.skin, 0.008));
        }
        final top = Path()
          ..moveTo(-0.08, -1.08)
          ..quadraticBezierTo(0.1, -1.2, 0.22, -1.0)
          ..quadraticBezierTo(0.2, -0.9, 0.16, -0.86)
          ..quadraticBezierTo(0.12, -1.0, -0.06, -1.03)
          ..close();
        canvas.drawPath(top, hair);
      case Hairdo.rainbowPonytail:
        canvas.drawPath(_cap(), hair);
        canvas.drawCircle(const Offset(0.2, -0.99), 0.022, _fill(const Color(0xFFFF4FA0)));
      case Hairdo.birdNestMane:
        canvas.drawPath(_cap(top: -1.15, fringe: -0.97), hair);
        for (var a = 0.0; a <= 1.0; a += 0.08) {
          final ang = pi + a * pi;
          canvas.drawCircle(Offset(cos(ang) * 0.25, -0.95 + sin(ang) * 0.24), 0.06, hair);
        }
        // L'uccellino che fa capolino.
        const bird = Offset(0.12, -1.17);
        canvas.drawOval(Rect.fromCenter(center: bird, width: 0.08, height: 0.06), _fill(const Color(0xFF4A86C8)));
        canvas.drawCircle(bird + const Offset(0.03, -0.03), 0.024, _fill(const Color(0xFF4A86C8)));
        canvas.drawCircle(bird + const Offset(0.038, -0.034), 0.006, _fill(Colors.black));
        canvas.drawPath(
          Path()
            ..moveTo(bird.dx + 0.05, bird.dy - 0.035)
            ..lineTo(bird.dx + 0.08, bird.dy - 0.025)
            ..lineTo(bird.dx + 0.05, bird.dy - 0.02)
            ..close(),
          _fill(_yellow),
        );
    }
  }

  // ---- I tatuaggi ----

  static Path _neckPath() => Path()
    ..moveTo(-0.066, -0.76)
    ..lineTo(0.066, -0.76)
    ..quadraticBezierTo(0.068, -0.64, 0.09, -0.58)
    ..lineTo(-0.09, -0.58)
    ..quadraticBezierTo(-0.068, -0.64, -0.066, -0.76)
    ..close();

  static void tattoo(Canvas canvas, AvatarLook look) {
    final t = look.tattoo;
    if (t == Tattoo.none) return;
    final ink = _line(_ink.withValues(alpha: 0.85), 0.007);
    final fillInk = _fill(_ink.withValues(alpha: 0.8));
    final red = _fill(_red.withValues(alpha: 0.8));
    // Sulla faccia: piccoli, sotto l'occhio o sullo zigomo.
    if (t == Tattoo.teardrop || t == Tattoo.cheekStar) {
      canvas.save();
      canvas.clipPath(_Face.path(look.features.shape));
      if (t == Tattoo.teardrop) {
        canvas.drawPath(
          Path()
            ..moveTo(-0.075, -0.84)
            ..quadraticBezierTo(-0.09, -0.81, -0.075, -0.8)
            ..quadraticBezierTo(-0.06, -0.81, -0.075, -0.84)
            ..close(),
          fillInk,
        );
      } else {
        canvas.drawPath(_star(const Offset(0.1, -0.81), 0.018), fillInk);
      }
      canvas.restore();
      return;
    }
    // Sul collo (e nello scollo, per chi lo ha aperto).
    final area = _neckPath();
    if (look.dame || look.outfit.pattern.feminine) {
      area.addPath(
        Path()
          ..moveTo(-0.14, -0.62)
          ..lineTo(0.14, -0.62)
          ..lineTo(0, -0.36)
          ..close(),
        Offset.zero,
      );
    }
    canvas.save();
    canvas.clipPath(area);
    // Un poco più grandi del vero: si devono leggere anche nel ritratto piccolo.
    canvas.translate(0, -0.64);
    canvas.scale(1.4);
    canvas.translate(0, 0.64);
    const side = Offset(0.04, -0.66);
    switch (t) {
      case Tattoo.anchor:
        canvas.drawLine(side + const Offset(0, -0.03), side + const Offset(0, 0.03), ink);
        canvas.drawLine(side + const Offset(-0.015, -0.02), side + const Offset(0.015, -0.02), ink);
        canvas.drawArc(Rect.fromCenter(center: side + const Offset(0, 0.015), width: 0.04, height: 0.03), 0, pi, false, ink);
      case Tattoo.swallow:
        canvas.drawPath(
          Path()
            ..moveTo(side.dx - 0.03, side.dy - 0.01)
            ..quadraticBezierTo(side.dx, side.dy + 0.01, side.dx + 0.03, side.dy - 0.02)
            ..lineTo(side.dx + 0.01, side.dy + 0.01)
            ..lineTo(side.dx + 0.025, side.dy + 0.03)
            ..lineTo(side.dx - 0.005, side.dy + 0.012)
            ..close(),
          fillInk,
        );
        canvas.drawCircle(side + const Offset(0.01, 0.0), 0.006, red);
      case Tattoo.roseDagger:
        canvas.drawLine(side + const Offset(-0.02, 0.035), side + const Offset(0.02, -0.035), ink);
        canvas.drawLine(side + const Offset(-0.008, 0.02), side + const Offset(0.004, 0.028), ink);
        canvas.drawCircle(side, 0.014, red);
        canvas.drawCircle(side + const Offset(-0.014, 0.012), 0.007, _fill(_green.withValues(alpha: 0.8)));
      case Tattoo.mammaHeart:
        const c = Offset(0, -0.64);
        canvas.drawPath(_heart(c, 0.03), red);
        canvas.drawRect(Rect.fromCenter(center: c + const Offset(0, 0.006), width: 0.09, height: 0.014), _fill(const Color(0xFFEDE4D0).withValues(alpha: 0.9)));
        final text = TextPainter(
          text: const TextSpan(text: 'MAMMA', style: TextStyle(fontSize: 0.011, color: _ink, fontWeight: FontWeight.w900)),
          textDirection: TextDirection.ltr,
        )..layout();
        text.paint(canvas, c + Offset(-text.width / 2, 0.006 - text.height / 2));
      case Tattoo.spiderWeb:
        const c = Offset(0.06, -0.62);
        for (var k = 0; k < 6; k++) {
          final a = pi + k * pi / 5;
          canvas.drawLine(c, c + Offset(cos(a), sin(a)) * 0.1, ink);
        }
        for (final r in [0.03, 0.055, 0.08]) {
          canvas.drawArc(Rect.fromCircle(center: c, radius: r), pi, pi, false, ink);
        }
      case Tattoo.koi:
        final body = Path()
          ..moveTo(-0.05, -0.72)
          ..quadraticBezierTo(0.06, -0.7, 0.04, -0.63)
          ..quadraticBezierTo(0.0, -0.58, -0.04, -0.6)
          ..quadraticBezierTo(0.0, -0.64, -0.05, -0.72)
          ..close();
        canvas.drawPath(body, _fill(const Color(0xFFE0702A).withValues(alpha: 0.85)));
        canvas.drawPath(body, ink);
        for (var y = -0.7; y < -0.6; y += 0.02) {
          canvas.drawArc(Rect.fromCenter(center: Offset(0.0, y), width: 0.03, height: 0.015), 0, pi, false, _line(_ink.withValues(alpha: 0.5), 0.004));
        }
        canvas.drawLine(const Offset(-0.06, -0.58), const Offset(0.08, -0.6), _line(const Color(0xFF3A6EA8).withValues(alpha: 0.7), 0.01));
      case Tattoo.playingCards:
        for (final (dx, a) in [(-0.012, -0.25), (0.012, 0.2)]) {
          canvas.save();
          canvas.translate(side.dx + dx, side.dy);
          canvas.rotate(a);
          final r = Rect.fromCenter(center: Offset.zero, width: 0.026, height: 0.038);
          canvas.drawRect(r, _fill(const Color(0xFFEDE4D0).withValues(alpha: 0.9)));
          canvas.drawRect(r, ink);
          canvas.drawPath(_heart(Offset.zero, 0.008), red);
          canvas.restore();
        }
      case Tattoo.skullTopHat:
        canvas.drawCircle(side + const Offset(0, 0.01), 0.018, _fill(const Color(0xFFEDE4D0).withValues(alpha: 0.9)));
        canvas.drawCircle(side + const Offset(-0.007, 0.008), 0.005, fillInk);
        canvas.drawCircle(side + const Offset(0.007, 0.008), 0.005, fillInk);
        canvas.drawRect(Rect.fromCenter(center: side + const Offset(0, -0.022), width: 0.022, height: 0.024), fillInk);
        canvas.drawRect(Rect.fromCenter(center: side + const Offset(0, -0.01), width: 0.04, height: 0.005), fillInk);
      case Tattoo.familyCrest:
        const c = Offset(0, -0.635);
        final shield = Path()
          ..moveTo(c.dx - 0.035, c.dy - 0.035)
          ..lineTo(c.dx + 0.035, c.dy - 0.035)
          ..lineTo(c.dx + 0.035, c.dy + 0.005)
          ..quadraticBezierTo(c.dx + 0.03, c.dy + 0.03, c.dx, c.dy + 0.045)
          ..quadraticBezierTo(c.dx - 0.03, c.dy + 0.03, c.dx - 0.035, c.dy + 0.005)
          ..close();
        canvas.drawPath(shield, _fill(_red.withValues(alpha: 0.6)));
        canvas.drawPath(shield, ink..strokeWidth = 0.008);
        canvas.drawLine(Offset(c.dx, c.dy - 0.035), Offset(c.dx, c.dy + 0.045), ink);
        canvas.drawLine(Offset(c.dx - 0.035, c.dy - 0.005), Offset(c.dx + 0.035, c.dy - 0.005), ink);
        canvas.drawPath(_star(c + const Offset(0, -0.055), 0.012), _fill(_yellow.withValues(alpha: 0.85)));
      case Tattoo.none || Tattoo.teardrop || Tattoo.cheekStar:
        break;
    }
    canvas.restore();
  }

  static Path _star(Offset c, double r) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final a = -pi / 2 + i * pi / 5;
      final d = i.isEven ? r : r * 0.45;
      final p = c + Offset(cos(a), sin(a)) * d;
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  static Path _heart(Offset c, double s) => Path()
    ..moveTo(c.dx, c.dy + s * 0.9)
    ..cubicTo(c.dx - s * 1.2, c.dy, c.dx - s * 0.6, c.dy - s * 0.9, c.dx, c.dy - s * 0.35)
    ..cubicTo(c.dx + s * 0.6, c.dy - s * 0.9, c.dx + s * 1.2, c.dy, c.dx, c.dy + s * 0.9)
    ..close();
}
