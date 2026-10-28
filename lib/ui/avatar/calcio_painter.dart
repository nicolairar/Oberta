part of 'look_painter.dart';

/// Il calcio: la curva d'anteguerra. Maglie di lana col collo allacciato,
/// berretti col pompon, sciarpe a fasce, fumogeni, megafoni di latta, coppe
/// e bandiere. Soprannomi e colori di città, mai stemmi veri: sul petto c'è
/// un segno inventato ([CalcioEmblem]). Stesse coordinate di [LookPainter]
/// (la testa in (0, -0.86), le spalle a -0.6).
abstract final class _Calcio {
  static Color _dark(Color c, double t) => LookPainter._dark(c, t);
  static Color _bright(Color c, double t) => LookPainter._bright(c, t);

  static Paint _fill(Color c) => Paint()..color = c;

  static Paint _line(Color c, double width) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  /// Il colore che si legge sopra [c]: inchiostro sul chiaro, panna sullo scuro.
  static Color _onto(Color c) => c.computeLuminance() > 0.45 ? _dark(c, 0.75) : const Color(0xFFF6F0E2);

  static CalcioTeam? _team(String id) => CalcioTeam.of(id);

  // --- La maglia -------------------------------------------------------------

  static void fabric(Canvas canvas, AvatarOutfit outfit) {
    if (outfit.pattern != CoatPattern.jersey) return;
    final team = _team(outfit.id);
    if (team == null) return;
    final second = _fill(team.secondary);
    switch (team.kit) {
      case CalcioKit.stripes:
        // Righe larghe, che si piegano un filo sul petto.
        for (var x = -0.55; x < 0.6; x += 0.2) {
          canvas.drawPath(
            Path()
              ..moveTo(x, -0.7)
              ..quadraticBezierTo(x * 1.06, -0.1, x * 0.92, 0.62)
              ..lineTo(x * 0.92 + 0.09, 0.62)
              ..quadraticBezierTo(x * 1.06 + 0.1, -0.1, x + 0.1, -0.7)
              ..close(),
            second,
          );
        }
      case CalcioKit.sash:
        // La fascia di traverso, dalla spalla al fianco, coi due fili d'oro.
        final band = Path()
          ..moveTo(-0.46, -0.66)
          ..lineTo(-0.3, -0.66)
          ..lineTo(0.62, 0.36)
          ..lineTo(0.62, 0.56)
          ..close();
        canvas.drawPath(band, second);
        final edge = _line(_dark(team.secondary, 0.3), 0.01);
        canvas.drawLine(const Offset(-0.46, -0.66), const Offset(0.62, 0.56), edge);
        canvas.drawLine(const Offset(-0.3, -0.66), const Offset(0.62, 0.36), edge);
      case CalcioKit.halves:
        canvas.drawRect(const Rect.fromLTRB(0, -0.7, 0.62, 0.62), second);
        canvas.drawLine(const Offset(0, -0.7), const Offset(0, 0.62), _line(_dark(team.secondary, 0.35), 0.008));
      case CalcioKit.plain:
        break;
    }
    // La maglia di lana: righine fitte, appena visibili.
    final knit = _line(Colors.black.withValues(alpha: 0.07), 0.004);
    for (var y = -0.6; y < 0.6; y += 0.028) {
      canvas.drawLine(Offset(-0.6, y), Offset(0.6, y), knit);
    }
    // Le spalle cucite in un colore solo: il carré dei palloni d'epoca.
    if (team.kit == CalcioKit.plain) {
      canvas.drawPath(
        Path()
          ..moveTo(-0.6, -0.48)
          ..quadraticBezierTo(-0.3, -0.53, 0, -0.53)
          ..quadraticBezierTo(0.3, -0.53, 0.6, -0.48),
        _line(_dark(team.primary, 0.22), 0.012),
      );
    }
    // Il distintivo cucito sul cuore.
    badge(canvas, team, const Offset(0.21, -0.41), 0.062);
  }

  /// Il distintivo: un tondo di feltro, l'orlo nel colore del colletto e il
  /// segno della squadra nel mezzo.
  static void badge(Canvas canvas, CalcioTeam team, Offset c, double r) {
    final felt = team.kit == CalcioKit.plain ? team.secondary : team.trim;
    canvas.drawCircle(c.translate(0.004, 0.006), r, _fill(Colors.black.withValues(alpha: 0.35)));
    canvas.drawCircle(c, r, _fill(felt));
    canvas.drawCircle(c, r * 0.86, _line(_dark(felt, 0.35), r * 0.08));
    emblem(canvas, team.emblem, c, r * 0.62, _onto(felt) == const Color(0xFFF6F0E2) ? team.trim : team.primary);
  }

  static Path _star(Offset c, double r, {int points = 5, double inner = 0.45}) {
    final path = Path();
    for (var i = 0; i < points * 2; i++) {
      final a = -pi / 2 + i * pi / points;
      final k = i.isEven ? r : r * inner;
      final p = Offset(c.dx + cos(a) * k, c.dy + sin(a) * k);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  /// Le figure inventate: nessuna somiglia a uno stemma vero.
  static void emblem(Canvas canvas, CalcioEmblem emblem, Offset c, double r, Color color) {
    final p = _fill(color);
    final l = _line(color, r * 0.16);
    switch (emblem) {
      case CalcioEmblem.comet:
        canvas.drawPath(
          Path()
            ..moveTo(c.dx + r * 0.35, c.dy - r * 0.55)
            ..lineTo(c.dx - r * 0.95, c.dy + r * 0.55)
            ..lineTo(c.dx + r * 0.05, c.dy - r * 0.05)
            ..close(),
          p,
        );
        canvas.drawPath(_star(c.translate(r * 0.32, -r * 0.32), r * 0.5), p);
      case CalcioEmblem.sun:
        canvas.drawCircle(c, r * 0.42, p);
        for (var i = 0; i < 12; i++) {
          final a = i * pi / 6;
          canvas.drawLine(c + Offset(cos(a), sin(a)) * r * 0.6, c + Offset(cos(a), sin(a)) * r * (i.isEven ? 1.0 : 0.82), l);
        }
      case CalcioEmblem.moon:
        canvas.drawPath(
          Path.combine(
            PathOperation.difference,
            Path()..addOval(Rect.fromCircle(center: c, radius: r * 0.85)),
            Path()..addOval(Rect.fromCircle(center: c.translate(r * 0.38, -r * 0.2), radius: r * 0.7)),
          ),
          p,
        );
        canvas.drawPath(_star(c.translate(r * 0.5, r * 0.25), r * 0.3), p);
      case CalcioEmblem.bolt:
        canvas.drawPath(
          Path()
            ..moveTo(c.dx + r * 0.3, c.dy - r)
            ..lineTo(c.dx - r * 0.5, c.dy + r * 0.12)
            ..lineTo(c.dx - r * 0.02, c.dy + r * 0.12)
            ..lineTo(c.dx - r * 0.3, c.dy + r)
            ..lineTo(c.dx + r * 0.5, c.dy - r * 0.15)
            ..lineTo(c.dx + r * 0.02, c.dy - r * 0.15)
            ..close(),
          p,
        );
      case CalcioEmblem.anchor:
        canvas.drawCircle(c.translate(0, -r * 0.72), r * 0.2, l);
        canvas.drawLine(c.translate(0, -r * 0.52), c.translate(0, r * 0.82), l);
        canvas.drawLine(c.translate(-r * 0.42, -r * 0.3), c.translate(r * 0.42, -r * 0.3), l);
        canvas.drawArc(Rect.fromCircle(center: c.translate(0, r * 0.12), radius: r * 0.72), pi * 0.12, pi * 0.76, false, l);
      case CalcioEmblem.star:
        canvas.drawPath(_star(c, r), p);
      case CalcioEmblem.compass:
        canvas.drawPath(_star(c, r, points: 4, inner: 0.28), p);
        canvas.drawCircle(c, r * 0.62, _line(color, r * 0.1));
      case CalcioEmblem.horseshoe:
        canvas.drawArc(Rect.fromCircle(center: c.translate(0, -r * 0.08), radius: r * 0.66), pi * 0.72, pi * 1.56, false, _line(color, r * 0.3));
        canvas.drawPath(_star(c.translate(0, r * 0.3), r * 0.3), p);
      case CalcioEmblem.laurel:
        for (final side in [-1.0, 1.0]) {
          canvas.drawArc(
            Rect.fromCircle(center: c, radius: r * 0.78),
            side < 0 ? pi * 0.6 : pi * -0.05,
            pi * 0.65,
            false,
            _line(color, r * 0.1),
          );
          for (var k = 0; k < 4; k++) {
            final a = (side < 0 ? pi * 0.7 : pi * 0.3) - side * k * pi * 0.17;
            final at = c + Offset(cos(a), sin(a)) * r * 0.78;
            canvas.save();
            canvas.translate(at.dx, at.dy);
            canvas.rotate(a + side * 0.9);
            canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: r * 0.42, height: r * 0.2), p);
            canvas.restore();
          }
        }
        canvas.drawPath(_star(c.translate(0, -r * 0.08), r * 0.34), p);
      case CalcioEmblem.volcano:
        canvas.drawPath(
          Path()
            ..moveTo(c.dx - r, c.dy + r * 0.7)
            ..lineTo(c.dx - r * 0.25, c.dy - r * 0.2)
            ..lineTo(c.dx + r * 0.25, c.dy - r * 0.2)
            ..lineTo(c.dx + r, c.dy + r * 0.7)
            ..close(),
          p,
        );
        for (final k in [-0.5, 0.0, 0.5]) {
          canvas.drawCircle(c.translate(k * r * 0.6, -r * (0.55 + (k == 0 ? 0.25 : 0))), r * 0.16, p);
        }
    }
  }

  /// Il colletto rovesciato e lo scollo allacciato con la stringa.
  static void collar(Canvas canvas, AvatarOutfit outfit) {
    if (outfit.pattern != CoatPattern.jersey) return;
    final team = _team(outfit.id);
    if (team == null) return;
    final trim = team.trim;
    // Lo spacco sul davanti: l'ombra del petto e la stringa incrociata.
    canvas.drawPath(
      Path()
        ..moveTo(-0.04, -0.63)
        ..lineTo(0.04, -0.63)
        ..lineTo(0, -0.47)
        ..close(),
      _fill(_dark(team.primary, 0.7)),
    );
    final lace = _line(_bright(trim, 0.25), 0.009);
    for (final y in [-0.6, -0.555, -0.51]) {
      final w = 0.034 * (y + 0.45) / -0.18;
      canvas.drawLine(Offset(-w - 0.006, y - 0.018), Offset(w + 0.006, y + 0.012), lace);
      canvas.drawLine(Offset(w + 0.006, y - 0.018), Offset(-w - 0.006, y + 0.012), lace);
    }
    canvas.drawPath(
      Path()
        ..moveTo(0, -0.47)
        ..quadraticBezierTo(-0.03, -0.43, -0.02, -0.39)
        ..moveTo(0, -0.47)
        ..quadraticBezierTo(0.03, -0.44, 0.035, -0.4),
      lace,
    );
    // Le due punte del colletto, rovesciate sulle spalle.
    for (final side in [-1.0, 1.0]) {
      final flap = Path()
        ..moveTo(side * 0.025, -0.64)
        ..quadraticBezierTo(side * 0.12, -0.665, side * 0.19, -0.635)
        ..lineTo(side * 0.13, -0.53)
        ..quadraticBezierTo(side * 0.07, -0.57, side * 0.03, -0.6)
        ..close();
      canvas.drawPath(flap.shift(const Offset(0.005, 0.012)), _fill(Colors.black.withValues(alpha: 0.3)));
      canvas.drawPath(flap, _fill(trim));
      canvas.drawPath(flap, _line(_dark(trim, 0.4), 0.007));
      canvas.drawLine(Offset(side * 0.05, -0.63), Offset(side * 0.15, -0.62), _line(_bright(trim, 0.4).withValues(alpha: 0.6), 0.006));
    }
  }

  // --- Il berretto col pompon --------------------------------------------------

  static void hat(Canvas canvas, AvatarHead hat, Paint? silhouette) {
    final team = _team(hat.name);
    if (team == null) return;
    Paint p(Color c) => silhouette ?? _fill(c);
    final dome = Path()
      ..moveTo(-0.19, -0.95)
      ..cubicTo(-0.2, -1.2, 0.2, -1.2, 0.19, -0.95)
      ..close();
    const cuff = Rect.fromLTRB(-0.2, -0.99, 0.2, -0.915);
    const pom = Offset(0.02, -1.19);
    if (silhouette != null) {
      canvas.drawPath(dome, silhouette);
      canvas.drawRRect(RRect.fromRectAndRadius(cuff, const Radius.circular(0.03)), silhouette);
      canvas.drawCircle(pom, 0.065, silhouette);
      return;
    }
    // La cupola a fasce, nei due colori.
    canvas.drawPath(dome, p(team.primary));
    canvas.save();
    canvas.clipPath(dome);
    for (var k = 0; k < 4; k++) {
      final top = -0.99 - 0.055 * (2 * k + 1);
      canvas.drawRect(Rect.fromLTRB(-0.3, top - 0.05, 0.3, top), _fill(team.secondary));
    }
    // La maglia a coste e l'ombra sul lato lontano dalla lampada.
    final rib = _line(Colors.black.withValues(alpha: 0.12), 0.006);
    for (var x = -0.18; x <= 0.18; x += 0.035) {
      canvas.drawLine(Offset(x, -0.95), Offset(x * 0.4, -1.18), rib);
    }
    canvas.drawRect(
      const Rect.fromLTRB(-0.22, -1.2, 0.22, -0.9),
      Paint()
        ..shader = LookPainter._gs(const LinearGradient(
          colors: [Color(0x22FFFFFF), Color(0x00000000), Color(0x55000000)],
        ), const Rect.fromLTRB(-0.22, -1.2, 0.22, -0.9)),
    );
    canvas.restore();
    // Il risvolto, a coste fitte, con il distintivo.
    final band = RRect.fromRectAndRadius(cuff, const Radius.circular(0.03));
    canvas.drawRRect(band.shift(const Offset(0, 0.012)), _fill(Colors.black.withValues(alpha: 0.3)));
    canvas.drawRRect(band, _fill(team.trim));
    final cuffRib = _line(_dark(team.trim, 0.25), 0.006);
    for (var x = -0.18; x <= 0.18; x += 0.024) {
      canvas.drawLine(Offset(x, -0.982), Offset(x, -0.923), cuffRib);
    }
    canvas.drawRRect(band, _line(_dark(team.trim, 0.45), 0.006));
    badge(canvas, team, const Offset(-0.1, -0.952), 0.034);
    // Il pompon: un batuffolo di fili.
    final fluff = team.kit == CalcioKit.plain ? team.secondary : team.trim;
    canvas.drawCircle(pom.translate(0.006, 0.01), 0.066, _fill(Colors.black.withValues(alpha: 0.3)));
    for (var i = 0; i < 14; i++) {
      final a = i * pi / 7;
      canvas.drawCircle(pom + Offset(cos(a), sin(a)) * 0.046, 0.024, _fill(_dark(fluff, 0.18)));
    }
    canvas.drawCircle(pom, 0.052, _fill(fluff));
    for (var i = 0; i < 9; i++) {
      final a = i * 2 * pi / 9 + 0.3;
      canvas.drawLine(pom + Offset(cos(a), sin(a)) * 0.012, pom + Offset(cos(a), sin(a)) * 0.05, _line(_bright(fluff, 0.45), 0.006));
    }
  }

  // --- Dietro: l'alone, il fumo e la bandiera ---------------------------------

  static void back(Canvas canvas, AvatarAccessory accessory) {
    final team = _team(accessory.name);
    if (team == null || accessory.name.endsWith('Scarf')) return;
    _aura(canvas, team);
    switch (team.prop) {
      case CalcioProp.flare:
        _smoke(canvas, team);
      case CalcioProp.flag:
        _flag(canvas, team);
      case CalcioProp.megaphone || CalcioProp.trophy:
        break;
    }
  }

  /// L'alone della curva: un bagliore nei colori della squadra e i fasci dei
  /// riflettori dietro le spalle.
  static void _aura(Canvas canvas, CalcioTeam team) {
    const c = Offset(0, -0.9);
    canvas.drawCircle(
      c,
      0.78,
      Paint()
        ..shader = LookPainter._gs(RadialGradient(
          colors: [
            _bright(team.primary, 0.35).withValues(alpha: 0.75),
            team.primary.withValues(alpha: 0.45),
            team.secondary.withValues(alpha: 0.22),
            team.secondary.withValues(alpha: 0),
          ],
          stops: const [0, 0.35, 0.7, 1],
        ), Rect.fromCircle(center: c, radius: 0.78)),
    );
    for (var i = 0; i < 10; i++) {
      final a = -pi / 2 + (i - 4.5) * 0.3;
      final color = (i.isEven ? team.primary : team.secondary);
      canvas.drawPath(
        Path()
          ..moveTo(c.dx, c.dy)
          ..lineTo(c.dx + cos(a - 0.07) * 0.9, c.dy + sin(a - 0.07) * 0.9)
          ..lineTo(c.dx + cos(a + 0.07) * 0.9, c.dy + sin(a + 0.07) * 0.9)
          ..close(),
        Paint()
          ..shader = LookPainter._gs(RadialGradient(
            colors: [_bright(color, 0.5).withValues(alpha: 0.5), color.withValues(alpha: 0)],
          ), Rect.fromCircle(center: c, radius: 0.9)),
      );
    }
    // Le stelline dei flash, come dagli spalti.
    final spark = _fill(const Color(0xFFFFF4D6).withValues(alpha: 0.85));
    for (final s in const [Offset(-0.42, -1.18), Offset(-0.3, -1.3), Offset(0.36, -1.24), Offset(-0.46, -0.84), Offset(0.44, -1.04)]) {
      canvas.drawPath(_star(s, 0.024, points: 4, inner: 0.25), spark);
    }
  }

  /// Il fumo colorato del fumogeno: sale dalla mano e si allarga sopra la testa.
  static void _smoke(Canvas canvas, CalcioTeam team) {
    final rnd = Random(team.index * 31 + 7);
    for (var i = 0; i < 26; i++) {
      final t = i / 25;
      final at = Offset(0.4 - t * 0.55 + (rnd.nextDouble() - 0.5) * 0.18 * t, -0.68 - t * 0.66);
      final color = (i ~/ 3).isEven ? team.primary : team.secondary;
      canvas.drawCircle(
        at,
        0.05 + t * 0.15,
        Paint()
          ..color = _bright(color, 0.12).withValues(alpha: 0.5 - t * 0.2)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 0.02 + t * 0.03),
      );
    }
  }

  /// La bandiera: un'asta dietro la spalla e il drappo che sventola sopra la testa.
  static void _flag(Canvas canvas, CalcioTeam team) {
    const top = Offset(0.4, -1.32);
    canvas.drawLine(const Offset(0.44, -0.3), top, _line(const Color(0xFF6A4A2A), 0.024));
    canvas.drawLine(const Offset(0.435, -0.3), top.translate(-0.006, 0), _line(const Color(0xFFB08A5A), 0.008));
    canvas.drawCircle(top.translate(0, -0.02), 0.028, _fill(LookPainter.gold));
    Path cloth(double dy) => Path()
      ..moveTo(top.dx, top.dy + 0.02 + dy)
      ..cubicTo(0.2, top.dy - 0.06 + dy, 0.0, top.dy + 0.1 + dy, -0.42, top.dy + 0.04 + dy);
    final flag = Path()
      ..moveTo(top.dx, top.dy + 0.02)
      ..cubicTo(0.2, top.dy - 0.06, 0.0, top.dy + 0.1, -0.42, top.dy + 0.04)
      ..lineTo(-0.42, top.dy + 0.38)
      ..cubicTo(0.0, top.dy + 0.44, 0.2, top.dy + 0.28, top.dx, top.dy + 0.36)
      ..close();
    canvas.drawPath(flag, _fill(team.primary));
    canvas.save();
    canvas.clipPath(flag);
    final second = _fill(team.secondary);
    switch (team.kit) {
      case CalcioKit.stripes:
        for (var x = -0.42; x < 0.42; x += 0.18) {
          canvas.drawRect(Rect.fromLTRB(x + 0.09, -1.5, x + 0.18, -0.8), second);
        }
      case CalcioKit.halves || CalcioKit.sash:
        canvas.drawRect(const Rect.fromLTRB(-0.01, -1.5, 0.5, -0.8), second);
      case CalcioKit.plain:
        for (final dy in [0.1, 0.24]) {
          canvas.drawPath(cloth(dy), _line(team.secondary, 0.05));
        }
    }
    // Le pieghe del drappo, luce e ombra.
    canvas.drawRect(
      const Rect.fromLTRB(-0.45, -1.4, 0.45, -0.9),
      Paint()
        ..shader = LookPainter._gs(const LinearGradient(
          colors: [Color(0x40000000), Color(0x18FFFFFF), Color(0x40000000), Color(0x22FFFFFF), Color(0x30000000)],
        ), const Rect.fromLTRB(-0.45, -1.4, 0.45, -0.9)),
    );
    canvas.restore();
    canvas.drawPath(flag, _line(_dark(team.primary, 0.5), 0.008));
    badge(canvas, team, const Offset(-0.26, -1.14), 0.075);
  }

  // --- Davanti: la sciarpa e il pezzo forte ----------------------------------

  static void prop(Canvas canvas, AvatarLook look) {
    final accessory = look.accessory;
    final team = _team(accessory.name);
    if (team == null) return;
    if (accessory.name.endsWith('Scarf')) {
      _scarf(canvas, team);
      return;
    }
    switch (team.prop) {
      case CalcioProp.flare:
        _flare(canvas, team);
      case CalcioProp.megaphone:
        _megaphone(canvas, team);
      case CalcioProp.trophy:
        _trophy(canvas, team);
      case CalcioProp.flag:
        // La mano che stringe l'asta, col nastro della squadra.
        canvas.drawRect(const Rect.fromLTRB(0.41, -0.52, 0.47, -0.46), _fill(team.secondary));
        canvas.drawRect(const Rect.fromLTRB(0.41, -0.46, 0.47, -0.42), _fill(team.primary));
    }
  }

  /// La sciarpa di lana a fasce: un giro al collo, un capo sul petto e
  /// l'altro buttato dietro la spalla.
  static void _scarf(Canvas canvas, CalcioTeam team) {
    // Il capo che scende sul petto, a fasce, con le frange.
    final tail = Path()
      ..moveTo(0.03, -0.62)
      ..lineTo(0.14, -0.62)
      ..quadraticBezierTo(0.17, -0.3, 0.2, 0.02)
      ..lineTo(0.07, 0.04)
      ..quadraticBezierTo(0.07, -0.3, 0.03, -0.62)
      ..close();
    canvas.drawPath(tail.shift(const Offset(0.012, 0.012)), _fill(Colors.black.withValues(alpha: 0.35)));
    canvas.drawPath(tail, _fill(team.primary));
    canvas.save();
    canvas.clipPath(tail);
    for (var y = -0.56; y < 0.05; y += 0.12) {
      canvas.drawRect(Rect.fromLTRB(0, y, 0.25, y + 0.06), _fill(team.secondary));
      canvas.drawLine(Offset(0, y - 0.003), Offset(0.25, y - 0.003), _line(team.trim, 0.006));
    }
    final rib = _line(Colors.black.withValues(alpha: 0.12), 0.005);
    for (var k = 0; k < 4; k++) {
      final x = 0.06 + k * 0.03;
      canvas.drawLine(Offset(x - 0.02, -0.62), Offset(x + 0.03, 0.04), rib);
    }
    canvas.restore();
    final fringe = _line(team.secondary, 0.008);
    for (var k = 0; k <= 6; k++) {
      final x = 0.075 + k * 0.021;
      canvas.drawLine(Offset(x, 0.035), Offset(x + 0.004, 0.09), fringe);
    }
    // Il giro intorno al collo: un rotolo morbido, a fasce larghe.
    final wrap = Path()
      ..moveTo(-0.2, -0.68)
      ..quadraticBezierTo(0, -0.6, 0.2, -0.68)
      ..lineTo(0.21, -0.6)
      ..quadraticBezierTo(0, -0.5, -0.21, -0.6)
      ..close();
    canvas.drawPath(wrap.shift(const Offset(0, 0.016)), _fill(Colors.black.withValues(alpha: 0.35)));
    canvas.drawPath(wrap, _fill(team.primary));
    canvas.save();
    canvas.clipPath(wrap);
    for (var x = -0.2; x < 0.22; x += 0.1) {
      canvas.drawRect(Rect.fromLTRB(x, -0.72, x + 0.05, -0.48), _fill(team.secondary));
    }
    canvas.drawRect(
      const Rect.fromLTRB(-0.22, -0.7, 0.22, -0.5),
      Paint()
        ..shader = LookPainter._gs(const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x30FFFFFF), Color(0x00000000), Color(0x50000000)],
        ), const Rect.fromLTRB(-0.22, -0.7, 0.22, -0.5)),
    );
    canvas.restore();
    canvas.drawPath(wrap, _line(_dark(team.primary, 0.5), 0.006));
    // Il nodo, dove il capo esce dal giro.
    canvas.drawOval(const Rect.fromLTRB(0.03, -0.64, 0.15, -0.56), _fill(_dark(team.primary, 0.12)));
    canvas.drawOval(const Rect.fromLTRB(0.03, -0.64, 0.15, -0.56), _line(_dark(team.primary, 0.5), 0.006));
  }

  /// Il fumogeno acceso, stretto contro la spalla: il cartone a fasce e la
  /// fiamma bianca.
  static void _flare(Canvas canvas, CalcioTeam team) {
    canvas.save();
    canvas.translate(0.31, -0.52);
    canvas.rotate(0.22);
    const tube = Rect.fromLTRB(-0.035, -0.16, 0.035, 0.2);
    canvas.drawRRect(RRect.fromRectAndRadius(tube.shift(const Offset(0.01, 0.01)), const Radius.circular(0.01)), _fill(Colors.black.withValues(alpha: 0.4)));
    canvas.drawRRect(RRect.fromRectAndRadius(tube, const Radius.circular(0.01)), _fill(team.primary));
    for (final y in [-0.09, 0.03, 0.15]) {
      canvas.drawRect(Rect.fromLTRB(-0.035, y, 0.035, y + 0.05), _fill(team.secondary));
    }
    canvas.drawRect(const Rect.fromLTRB(-0.035, -0.16, 0, 0.2), _fill(Colors.white.withValues(alpha: 0.14)));
    canvas.drawRect(const Rect.fromLTRB(-0.04, -0.18, 0.04, -0.15), _fill(const Color(0xFF3A3A3A)));
    // La fiamma: un cuore bianco, l'alone caldo e le scintille.
    const flame = Offset(0, -0.22);
    canvas.drawCircle(
      flame,
      0.11,
      Paint()
        ..shader = LookPainter._gs(RadialGradient(
          colors: [
            const Color(0xFFFFFFFF),
            const Color(0xFFFFE7A0),
            _bright(team.primary, 0.3).withValues(alpha: 0.7),
            team.primary.withValues(alpha: 0),
          ],
          stops: const [0, 0.25, 0.55, 1],
        ), Rect.fromCircle(center: flame, radius: 0.11)),
    );
    canvas.drawPath(
      Path()
        ..moveTo(-0.025, -0.17)
        ..quadraticBezierTo(-0.04, -0.24, 0, -0.3)
        ..quadraticBezierTo(0.04, -0.24, 0.025, -0.17)
        ..close(),
      _fill(const Color(0xFFFFFDF2)),
    );
    final rnd = Random(team.index + 3);
    for (var i = 0; i < 9; i++) {
      final a = -pi / 2 + (rnd.nextDouble() - 0.5) * 2.4;
      final d = 0.08 + rnd.nextDouble() * 0.08;
      canvas.drawCircle(flame + Offset(cos(a), sin(a)) * d, 0.007 + rnd.nextDouble() * 0.006, _fill(const Color(0xFFFFE9A8)));
    }
    canvas.restore();
  }

  /// Il megafono di latta dipinta, la bocca larga verso l'alto.
  static void _megaphone(Canvas canvas, CalcioTeam team) {
    canvas.save();
    canvas.translate(0.2, -0.62);
    canvas.rotate(-1.0);
    final cone = Path()
      ..moveTo(0, -0.03)
      ..lineTo(0.3, -0.11)
      ..lineTo(0.3, 0.11)
      ..lineTo(0, 0.03)
      ..close();
    canvas.drawPath(cone.shift(const Offset(0.012, 0.012)), _fill(Colors.black.withValues(alpha: 0.4)));
    canvas.drawPath(
      cone,
      Paint()
        ..shader = LookPainter._gs(LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_bright(team.primary, 0.35), team.primary, _dark(team.primary, 0.45)],
        ), const Rect.fromLTRB(0, -0.11, 0.3, 0.11)),
    );
    canvas.save();
    canvas.clipPath(cone);
    canvas.drawRect(const Rect.fromLTRB(0.14, -0.2, 0.2, 0.2), _fill(team.secondary));
    canvas.drawRect(const Rect.fromLTRB(0.26, -0.2, 0.3, 0.2), _fill(team.trim));
    canvas.restore();
    // La bocca, vista di sbieco, con il bordo arrotolato.
    final mouth = Rect.fromCenter(center: const Offset(0.3, 0), width: 0.06, height: 0.23);
    canvas.drawOval(mouth, _fill(_dark(team.primary, 0.7)));
    canvas.drawOval(mouth, _line(LookPainter.gold, 0.014));
    // Il bocchino e l'impugnatura.
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(-0.05, -0.028, 0.01, 0.028), const Radius.circular(0.012)), _fill(const Color(0xFF2A2420)));
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(0.06, 0.03, 0.1, 0.12), const Radius.circular(0.012)), _fill(const Color(0xFF4A3424)));
    canvas.drawLine(const Offset(0.03, -0.05), const Offset(0.28, -0.1), _line(Colors.white.withValues(alpha: 0.35), 0.008));
    // Il grido: tre archi davanti alla bocca.
    final shout = _line(const Color(0xFFFFF4D6).withValues(alpha: 0.8), 0.012);
    for (final r in [0.07, 0.12, 0.17]) {
      canvas.drawArc(Rect.fromCircle(center: const Offset(0.3, 0), radius: r), -0.55, 1.1, false, shout);
    }
    canvas.restore();
  }

  /// La coppa d'argento coi nastri della squadra, appoggiata sulla spalla.
  static void _trophy(Canvas canvas, CalcioTeam team) {
    canvas.save();
    canvas.translate(0.36, -0.6);
    final silver = Paint()
      ..shader = LookPainter._gs(const LinearGradient(
        colors: [Color(0xFF8E8A84), Color(0xFFF6F2EA), Color(0xFFC8C2B8), Color(0xFF6E6A64)],
        stops: [0, 0.35, 0.6, 1],
      ), const Rect.fromLTRB(-0.12, -0.42, 0.12, 0.02));
    // Lo zoccolo di legno scuro.
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(-0.08, -0.05, 0.08, 0.03), const Radius.circular(0.01)), _fill(const Color(0xFF2A1A12)));
    canvas.drawRect(const Rect.fromLTRB(-0.08, -0.03, 0.08, -0.015), _fill(LookPainter.gold));
    // Il gambo e la coppa.
    canvas.drawPath(
      Path()
        ..moveTo(-0.05, -0.05)
        ..quadraticBezierTo(-0.015, -0.1, -0.015, -0.17)
        ..lineTo(0.015, -0.17)
        ..quadraticBezierTo(0.015, -0.1, 0.05, -0.05)
        ..close(),
      silver,
    );
    final bowl = Path()
      ..moveTo(-0.11, -0.4)
      ..quadraticBezierTo(-0.11, -0.2, 0, -0.17)
      ..quadraticBezierTo(0.11, -0.2, 0.11, -0.4)
      ..close();
    // Le anse grandi, alla vecchia maniera.
    final handle = _line(const Color(0xFFD8D2C6), 0.018);
    for (final side in [-1.0, 1.0]) {
      canvas.drawPath(
        Path()
          ..moveTo(side * 0.1, -0.37)
          ..cubicTo(side * 0.22, -0.4, side * 0.2, -0.24, side * 0.06, -0.22),
        handle,
      );
    }
    canvas.drawPath(bowl, silver);
    canvas.drawOval(const Rect.fromLTRB(-0.11, -0.42, 0.11, -0.38), _fill(const Color(0xFF5A5650)));
    canvas.drawOval(const Rect.fromLTRB(-0.11, -0.42, 0.11, -0.38), _line(const Color(0xFFF6F2EA), 0.008));
    canvas.drawLine(const Offset(-0.06, -0.36), const Offset(-0.05, -0.22), _line(Colors.white.withValues(alpha: 0.75), 0.012));
    badge(canvas, team, const Offset(0.02, -0.29), 0.04);
    // I nastri annodati alle anse.
    for (final side in [-1.0, 1.0]) {
      final knot = Offset(side * 0.17, -0.33);
      for (final (k, color) in [(0, team.primary), (1, team.secondary)]) {
        canvas.drawPath(
          Path()
            ..moveTo(knot.dx, knot.dy)
            ..quadraticBezierTo(knot.dx + side * (0.03 + k * 0.02), knot.dy + 0.08, knot.dx + side * (0.01 + k * 0.03), knot.dy + 0.18)
            ..lineTo(knot.dx + side * (0.04 + k * 0.03), knot.dy + 0.17)
            ..quadraticBezierTo(knot.dx + side * (0.05 + k * 0.02), knot.dy + 0.08, knot.dx + side * 0.02, knot.dy)
            ..close(),
          _fill(color),
        );
      }
      canvas.drawCircle(knot, 0.016, _fill(team.trim));
    }
    canvas.restore();
  }

}
