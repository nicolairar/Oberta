part of 'look_painter.dart';

/// I posti più cari ([Aura], [BackItem], [HeadFx], [FaceExtra], [EyeShine],
/// [HeldItem], [FrontFx]) nella lingua del cartoon noir: la sagoma
/// d'inchiostro spessa, i colori pieni con una sola ombra netta lontano
/// dalla lampada, il filo di luce calda sul bordo, le linee interne sottili.
/// Solo forme e sfumature, niente sfocature.
///
/// Tutto si disegna nel quadrato del ritratto ([_Noir.paint]), una volta: ogni
/// pezzo si registra in un'immagine vettoriale e si rimette tale e quale
/// finché la persona non cambia ([_Deep.pic]). Sotto i 110 px i dettagli fini
/// (le lentiggini, i mattoni, le finestrelle) restano fuori.
abstract final class _Deep {
  static const ink = Color(0xFF0B0809);
  static const night = Color(0xFF1A1236);
  static const lamp = Color(0xFFFFD27A);
  static const cream = Color(0xFFF2EAE1);
  static const gold = Color(0xFFE8B84A);
  static const white = Color(0xFFFFFFFF);

  /// Le linee del pezzo che si sta disegnando, nel quadrato.
  static double _ow = 0.024;
  static double _thin = 0.009;

  /// La scala locale ([at]): le linee si dividono per lei, così restano uguali.
  static double _k = 1;
  static bool _small = false;

  static Paint fill(Color c) => Paint()..color = c;
  static Paint line(Color c, double w) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = w / _k
    ..color = c
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  static Color dark(Color c, [double t = 0.55]) => Color.lerp(c, night, t)!;
  static Color lit(Color c, [double t = 0.45]) => Color.lerp(c, lamp, t)!;

  /// La stoffa noir: il colore, l'ombra netta a destra, il filo di luce a
  /// sinistra, la linea sottile.
  static void toon(Canvas c, Path p, Color base, {double d = 0.05, double glow = 0.45, bool rim = true, bool outline = true}) {
    c.drawPath(p, fill(base));
    c.drawPath(Path.combine(PathOperation.difference, p, p.shift(Offset(-d, -d * 0.8))), fill(dark(base)));
    if (rim) c.drawPath(Path.combine(PathOperation.difference, p, p.shift(Offset(d * 0.25, d * 0.22))), fill(lit(base, glow)));
    if (outline) c.drawPath(p, line(ink, _thin));
  }

  /// Un pezzo fatto di parti: una sagoma d'inchiostro intorno a tutte, poi
  /// ognuna col suo colore, nell'ordine.
  static void piece(Canvas c, List<(Path, Color)> parts, {double d = 0.05, double weight = 1}) {
    for (final (p, _) in parts) {
      c.drawPath(p, line(ink, _ow * 2 * weight));
    }
    for (final (p, col) in parts) {
      toon(c, p, col, d: d);
    }
  }

  /// [draw] in [o], girato di [turn], scalato di [s].
  static void at(Canvas c, Offset o, double s, double turn, void Function() draw) {
    c.save();
    c.translate(o.dx, o.dy);
    c.rotate(turn);
    c.scale(s);
    final previous = _k;
    _k *= s;
    draw();
    _k = previous;
    c.restore();
  }

  static Path oval(Offset center, double w, double h) => Path()..addOval(Rect.fromCenter(center: center, width: w, height: h));
  static Path rrect(Rect r, double radius) => Path()..addRRect(RRect.fromRectAndRadius(r, Radius.circular(radius)));
  static Path poly(List<Offset> pts) => Path()..addPolygon(pts, true);
  static Path star(Offset c, double r, int n, double inner, {double turn = -pi / 2}) => poly([
        for (var i = 0; i < n * 2; i++) c + Offset(cos(turn + i * pi / n), sin(turn + i * pi / n)) * (i.isEven ? r : r * inner),
      ]);
  static Path heart(Offset c, double s) => Path()
    ..moveTo(c.dx, c.dy + s * 0.9)
    ..cubicTo(c.dx - s * 1.3, c.dy + s * 0.1, c.dx - s * 0.9, c.dy - s * 1.0, c.dx, c.dy - s * 0.35)
    ..cubicTo(c.dx + s * 0.9, c.dy - s * 1.0, c.dx + s * 1.3, c.dy + s * 0.1, c.dx, c.dy + s * 0.9)
    ..close();

  // --- La cache -------------------------------------------------------------

  static final Map<Object, ui.Picture> _pictures = {};

  /// [draw] registrato una volta per [key] (che deve dire tutto quello da cui
  /// dipende il disegno) e poi rimesso con un colpo solo.
  static void pic(Canvas canvas, Object key, void Function(Canvas c) draw) {
    final full = (key, _ow, _thin, _small);
    var picture = _pictures[full];
    if (picture == null) {
      if (_pictures.length > 300) _pictures.clear();
      final recorder = ui.PictureRecorder();
      draw(Canvas(recorder));
      picture = _pictures[full] = recorder.endRecording();
    }
    canvas.drawPicture(picture);
  }

  /// Prepara le linee per un ritratto di lato [side] (in pixel).
  static void begin(double side) {
    _ow = max(0.024, 2.2 / side);
    _thin = max(0.009, 1.0 / side);
    _small = side < 110;
    _k = 1;
  }

  // --- Le scene ---------------------------------------------------------------

  /// La scena: riempie [box] (nelle misure del ritratto, anche oltre il
  /// quadrato, per l'arco del tavolo) intorno alla testa in [h].
  static void aura(Canvas c, Aura id, Rect box, Offset h) {
    final w = box.width;
    double x(double t) => box.left + t * w;
    switch (id) {
      case Aura.none:
        return;
      case Aura.inferno:
        c.drawRect(box, fill(const Color(0xFF1A0705)));
        c.drawRect(
          box,
          Paint()
            ..shader = ui.Gradient.radial(Offset(h.dx, box.bottom - 0.05), box.height * 0.95, const [Color(0xFF9A2C12), Color(0xFF3A0C06), Color(0xFF140504)], const [0, 0.55, 1]),
        );
        for (final (row, col, height, fw) in [(0, const Color(0xFFB8321A), 0.62, 0.17), (1, const Color(0xFFE8642A), 0.46, 0.14), (2, const Color(0xFFFFB347), 0.3, 0.11)]) {
          final p = Path()..moveTo(box.left - 0.05, box.bottom + 0.05);
          final n = ((w + 0.1) / fw).ceil();
          for (var i = 0; i < n; i++) {
            final x0 = box.left - 0.05 + i * fw;
            final centre = (x0 + fw / 2 - h.dx).abs();
            final tall = height * (1 - centre * 0.9).clamp(0.25, 1.0) * (0.75 + 0.25 * sin(i * 2.3 + row));
            final tip = Offset(x0 + fw * (0.5 + 0.25 * sin(i * 1.7 + row * 2)), box.bottom - tall);
            p.quadraticBezierTo(x0 + fw * 0.05, box.bottom - tall * 0.45, tip.dx, tip.dy);
            p.quadraticBezierTo(x0 + fw * 0.85, box.bottom - tall * 0.4, x0 + fw, box.bottom - tall * 0.12);
          }
          p
            ..lineTo(box.right + 0.05, box.bottom + 0.05)
            ..close();
          c.drawPath(p, fill(col));
          if (!_small) c.drawPath(p, line(ink.withValues(alpha: 0.5), _thin * 0.8));
        }
        for (var i = 0; i < (_small ? 5 : 12); i++) {
          final p = Offset(x(0.08 + (i * 0.618 % 1) * 0.84), box.top + 0.1 + (i * 0.381 % 1) * 0.45);
          c.drawPath(star(p, 0.012 + 0.006 * (i % 3), 4, 0.35, turn: i * 0.4), fill(lamp));
        }
      case Aura.harbourMoon:
        c.drawRect(box, Paint()..shader = ui.Gradient.linear(box.topCenter, box.bottomCenter, const [Color(0xFF0E1838), Color(0xFF1E2C5C), Color(0xFF2A1E48)], const [0, 0.6, 1]));
        // Il porto: la sagoma dei magazzini e delle gru, l'acqua.
        final sky = Path()..moveTo(box.left, box.bottom);
        var sx = box.left;
        var i = 0;
        while (sx < box.right) {
          final bw = 0.06 + (i * 0.37 % 1) * 0.07;
          final top = box.bottom - 0.34 + (i * 0.53 % 1) * 0.16;
          sky
            ..lineTo(sx, top)
            ..lineTo(sx + bw, top);
          sx += bw;
          i++;
        }
        sky
          ..lineTo(box.right, box.bottom)
          ..close();
        c.drawPath(sky, fill(const Color(0xFF0A0F24)));
        // Una gru del porto.
        final crane = Offset(x(0.86), box.bottom - 0.3);
        c.drawLine(crane, crane + const Offset(0, -0.22), line(const Color(0xFF0A0F24), 0.02));
        c.drawLine(crane + const Offset(-0.14, -0.2), crane + const Offset(0.06, -0.24), line(const Color(0xFF0A0F24), 0.016));
        if (!_small) {
          for (var j = 0; j < 14; j++) {
            final wx = x(0.04 + (j * 0.618 % 1) * 0.92);
            final wy = box.bottom - 0.26 + (j * 0.29 % 1) * 0.2;
            c.drawRect(Rect.fromLTWH(wx, wy, 0.012, 0.016), fill(const Color(0xCCFFC965)));
          }
        }
        final m = Offset(h.dx + 0.16, h.dy - 0.12);
        const r = 0.33;
        c.drawCircle(m, r * 1.18, fill(const Color(0x14F4E7C0)));
        c.drawCircle(m, r * 1.07, fill(const Color(0x1AF4E7C0)));
        final moon = Path.combine(PathOperation.difference, oval(m, r * 2, r * 2), oval(m + const Offset(0.13, -0.06), r * 1.8, r * 1.8));
        c.drawPath(moon, fill(const Color(0xFFF4E7C0)));
        c.drawPath(Path.combine(PathOperation.difference, moon, moon.shift(const Offset(0.03, 0.02))), fill(const Color(0xFFD8C38E)));
        for (final (o, s) in [(const Offset(-0.2, 0.08), 0.05), (const Offset(-0.24, -0.06), 0.03), (const Offset(-0.12, 0.2), 0.035)]) {
          c.drawCircle(m + o, s / 2, fill(const Color(0xFFD8C38E)));
        }
        c.drawPath(moon, line(ink, _thin));
        for (var j = 0; j < (_small ? 4 : 9); j++) {
          c.drawPath(star(Offset(x(0.06 + (j * 0.73 % 1) * 0.88), box.top + 0.05 + (j * 0.41 % 1) * 0.5), 0.014 + 0.008 * (j % 3), 4, 0.3), fill(cream));
        }
      case Aura.sunburst:
        c.drawRect(box, fill(const Color(0xFF2A1A0E)));
        final o = Offset(h.dx, h.dy - 0.02);
        const rays = 28;
        for (var j = 0; j < rays; j++) {
          final a0 = j * 2 * pi / rays;
          final a1 = a0 + pi / rays;
          c.drawPath(poly([o, o + Offset(cos(a0), sin(a0)) * 1.8, o + Offset(cos(a1), sin(a1)) * 1.8]), fill(j.isEven ? const Color(0xFFB8862E) : const Color(0xFF8C6420)));
        }
        c.drawRect(box, Paint()..shader = ui.Gradient.radial(o, 0.75, const [Color(0x00000000), Color(0x00000000), Color(0xCC1A0F06)], const [0, 0.35, 1]));
        for (final rr in [0.3, 0.37, 0.44]) {
          c.drawCircle(o, rr, line(const Color(0x8CFFE2A0), _thin * (rr == 0.37 ? 2.2 : 1)));
        }
        for (final s in [-1.0, 1.0]) {
          for (var j = 0; j < 4; j++) {
            final sw = 0.1 + j * 0.06;
            final x0 = s < 0 ? box.left : box.right - sw;
            c.drawRect(Rect.fromLTWH(x0, box.bottom - 0.28 + j * 0.07, sw, 0.07), fill(j.isEven ? const Color(0xFF3A2412) : const Color(0xFF4A3018)));
          }
        }
      case Aura.neonAlley:
        c.drawRect(box, Paint()..shader = ui.Gradient.radial(Offset(h.dx, h.dy - 0.1), 0.9, const [Color(0xFF2A1438), Color(0xFF0C0614)]));
        if (!_small) {
          final brick = line(const Color(0x993A1E48), _thin * 0.7);
          for (var row = 0; row * 0.075 < box.height; row++) {
            final y = box.top + row * 0.075;
            c.drawLine(Offset(box.left, y), Offset(box.right, y), brick);
            for (var col = 0; col * 0.16 < w + 0.16; col++) {
              final bx = box.left + col * 0.16 + (row.isOdd ? 0.08 : 0);
              c.drawLine(Offset(bx, y), Offset(bx, y + 0.075), brick);
            }
          }
        }
        final o = Offset(h.dx, h.dy + 0.02);
        for (final (lw, a) in [(0.09, 0.10), (0.05, 0.22), (0.025, 0.55)]) {
          c.drawCircle(o, 0.36, line(const Color(0xFFFF4FA3).withValues(alpha: a), lw));
        }
        c.drawCircle(o, 0.36, line(const Color(0xFFFFD6EC), 0.008));
        for (final (lw, a) in [(0.06, 0.12), (0.03, 0.3)]) {
          c.drawCircle(o, 0.43, line(const Color(0xFF3FE0D0).withValues(alpha: a), lw));
        }
        c.drawCircle(o, 0.43, line(const Color(0xFFCFFFF8), 0.006));
      case Aura.cardRoomSmoke:
        c.drawRect(box, Paint()..shader = ui.Gradient.linear(box.topLeft, box.bottomRight, const [Color(0xFF3E4A52), Color(0xFF1E2428), Color(0xFF2E2420)], const [0, 0.5, 1]));
        // La lampada verde della bisca, e il fumo che le gira intorno.
        final lampAt = Offset(h.dx - 0.28, box.top + 0.1);
        c.drawPath(Path()..addArc(Rect.fromCenter(center: lampAt, width: 0.22, height: 0.16), pi, pi), fill(const Color(0xFF1F5A3A)));
        c.drawPath(poly([lampAt + const Offset(-0.11, 0), lampAt + const Offset(0.11, 0), lampAt + const Offset(0.3, 0.5), lampAt + const Offset(-0.3, 0.5)]), fill(const Color(0x14FFE2A0)));
        for (final (dy, col, n) in [(0.18, const Color(0xFF55626A), 6), (0.42, const Color(0xFF6E7B82), 5), (0.78, const Color(0xFF8A969C), 6)]) {
          final cloud = Path();
          for (var j = 0; j < n; j++) {
            final cxj = x((j + 0.5) / n + 0.05 * sin(j * 3.1 + dy * 10));
            final rj = 0.1 + 0.05 * ((j * 7 + (dy * 10).round()) % 3);
            cloud.addOval(Rect.fromCircle(center: Offset(cxj, box.top + dy * box.height + 0.03 * cos(j * 2.0)), radius: rj));
          }
          c.drawPath(cloud, fill(col.withValues(alpha: 0.55)));
        }
        if (!_small) {
          for (var j = 0; j < 4; j++) {
            final o = Offset(x(0.12 + j * 0.26), box.top + 0.3 * box.height + (j.isEven ? 0.05 : -0.05));
            final swirl = Path()
              ..moveTo(o.dx - 0.06, o.dy + 0.04)
              ..cubicTo(o.dx - 0.08, o.dy - 0.06, o.dx + 0.06, o.dy - 0.08, o.dx + 0.04, o.dy)
              ..cubicTo(o.dx + 0.02, o.dy + 0.04, o.dx - 0.02, o.dy + 0.02, o.dx, o.dy - 0.01);
            c.drawPath(swirl, line(const Color(0x99B8C4C8), _thin * 1.4));
          }
        }
      case Aura.varietyCurtain:
        c.drawRect(box, fill(const Color(0xFF3A0A12)));
        final folds = (w / 0.125).ceil() + 1;
        for (var j = 0; j < folds; j++) {
          final r = Rect.fromLTWH(box.left - 0.06 + j * 0.125, box.top, 0.125, box.height);
          c.drawRect(r, Paint()..shader = ui.Gradient.linear(r.centerLeft, r.centerRight, const [Color(0xFF5A0E1C), Color(0xFF8C1C2C), Color(0xFF4A0A16)], const [0, 0.5, 1]));
        }
        // La mantovana con le nappe d'oro.
        final valance = Path()..moveTo(box.left, box.top);
        for (var j = 0; j <= (w / 0.2).ceil(); j++) {
          final x0 = box.left + j * 0.2;
          valance.quadraticBezierTo(x0 + 0.1, box.top + 0.13, x0 + 0.2, box.top + 0.06);
        }
        valance
          ..lineTo(box.right + 0.2, box.top - 0.1)
          ..lineTo(box.left, box.top - 0.1)
          ..close();
        c.drawPath(valance, fill(const Color(0xFF6A1020)));
        c.drawPath(valance, line(gold, _thin * 1.6));
        c.drawRect(box, Paint()..shader = ui.Gradient.radial(h, 0.7, const [Color(0x55FFD27A), Color(0x00000000)]));
        final o = Offset(h.dx, h.dy + 0.12);
        const n = 15;
        for (var j = 0; j <= n; j++) {
          final a = pi + j * pi / n;
          final p = o + Offset(cos(a) * 0.43, sin(a) * 0.47);
          if (!_small) c.drawCircle(p, 0.028, fill(const Color(0x33FFD27A)));
          c.drawCircle(p, 0.017, fill(const Color(0xFFFFC94A)));
          c.drawCircle(p, 0.017, line(ink, _thin * 0.8));
          c.drawCircle(p - const Offset(0.005, 0.005), 0.006, fill(const Color(0xFFFFF6D8)));
        }
      case Aura.vault:
        // Il caveau della banca: la porta tonda d'acciaio aperta alle spalle,
        // i lingotti impilati ai lati.
        c.drawRect(box, Paint()..shader = ui.Gradient.linear(box.topCenter, box.bottomCenter, const [Color(0xFF2A3038), Color(0xFF14181E)]));
        if (!_small) {
          for (var row = 0; row * 0.1 < box.height; row++) {
            c.drawLine(Offset(box.left, box.top + row * 0.1), Offset(box.right, box.top + row * 0.1), line(const Color(0x33000000), _thin));
          }
        }
        final o = Offset(h.dx, h.dy + 0.02);
        c.drawCircle(o, 0.47, fill(const Color(0xFF0E1116)));
        final door = oval(o, 0.86, 0.86);
        piece(c, [(door, const Color(0xFF8A939E))], d: 0.05, weight: 0.8);
        c.drawCircle(o, 0.36, line(const Color(0xFF5E6670), 0.03));
        c.drawCircle(o, 0.36, line(const Color(0xFFB8C2CC), _thin));
        for (var j = 0; j < 16; j++) {
          final a = j * pi / 8;
          final bolt = o + Offset(cos(a), sin(a)) * 0.4;
          c.drawCircle(bolt, 0.018, fill(const Color(0xFFC8D0D8)));
          c.drawCircle(bolt, 0.018, line(ink, _thin * 0.7));
        }
        // La ruota della combinazione, dietro la testa: si vedono i raggi.
        for (var j = 0; j < 6; j++) {
          final a = j * pi / 3 + 0.3;
          c.drawLine(o + Offset(cos(a), sin(a)) * 0.08, o + Offset(cos(a), sin(a)) * 0.3, line(const Color(0xFF4A525C), 0.03));
        }
        for (final s in [-1.0, 1.0]) {
          final base = Offset(s < 0 ? box.left + 0.14 : box.right - 0.14, box.bottom - 0.02);
          for (var row = 0; row < 3; row++) {
            for (var col = 0; col < 3 - row; col++) {
              final bx = base.dx + (col - (2 - row) / 2) * 0.1;
              final by = base.dy - 0.045 - row * 0.05;
              final bar = poly([Offset(bx - 0.045, by + 0.022), Offset(bx + 0.045, by + 0.022), Offset(bx + 0.032, by - 0.022), Offset(bx - 0.032, by - 0.022)]);
              piece(c, [(bar, gold)], d: 0.012, weight: 0.45);
            }
          }
        }
      case Aura.vesuvio:
        // Il golfo al tramonto: il cielo rosa e arancio, il vulcano col suo
        // pennacchio, il mare a strisce, una barca.
        c.drawRect(box, Paint()..shader = ui.Gradient.linear(box.topCenter, box.bottomCenter, const [Color(0xFF3A1E4A), Color(0xFFC8505A), Color(0xFFFFB45A)], const [0, 0.5, 0.78]));
        final sun = Offset(h.dx - 0.22, box.bottom - 0.3);
        c.drawCircle(sun, 0.11, fill(const Color(0xFFFFE08A)));
        final volcano = Offset(h.dx + 0.24, box.bottom - 0.27);
        final mountain = Path()
          ..moveTo(volcano.dx - 0.5, box.bottom - 0.2)
          ..quadraticBezierTo(volcano.dx - 0.2, volcano.dy - 0.06, volcano.dx - 0.07, volcano.dy - 0.17)
          ..lineTo(volcano.dx + 0.07, volcano.dy - 0.17)
          ..quadraticBezierTo(volcano.dx + 0.2, volcano.dy - 0.06, volcano.dx + 0.55, box.bottom - 0.2)
          ..close();
        c.drawPath(mountain, fill(const Color(0xFF4A2A3E)));
        c.drawPath(Path.combine(PathOperation.difference, mountain, mountain.shift(const Offset(-0.04, 0))), fill(const Color(0xFF3A1E30)));
        c.drawPath(mountain, line(ink, _thin));
        for (var j = 0; j < 4; j++) {
          c.drawCircle(Offset(volcano.dx - 0.02 + j * 0.03 + sin(j * 1.3) * 0.02, volcano.dy - 0.24 - j * 0.07), 0.045 + j * 0.014, fill(Color.lerp(const Color(0xFF6A5A6E), const Color(0xFFB8A0B0), j / 3)!.withValues(alpha: 0.85)));
        }
        final sea = Rect.fromLTRB(box.left, box.bottom - 0.2, box.right, box.bottom);
        c.drawRect(sea, fill(const Color(0xFF2A3A6A)));
        if (!_small) {
          for (var j = 0; j < 6; j++) {
            final y = sea.top + 0.025 + j * 0.03;
            c.drawLine(Offset(sun.dx - 0.08 + j * 0.01, y), Offset(sun.dx + 0.08 - j * 0.01, y), line(const Color(0xAAFFC96A), _thin * 1.6));
          }
        }
        final boat = Offset(x(0.82), sea.top + 0.06);
        piece(c, [(poly([boat + const Offset(-0.06, 0), boat + const Offset(0.06, 0), boat + const Offset(0.045, 0.025), boat + const Offset(-0.045, 0.025)]), const Color(0xFF1A1236))], d: 0.01, weight: 0.4);
        c.drawPath(poly([boat + const Offset(0, -0.08), boat + const Offset(0, -0.005), boat + const Offset(0.045, -0.005)]), fill(cream));
      case Aura.spaghettiStorm:
        // L'assurdo: una tempesta di spaghetti al pomodoro, con le polpette.
        c.drawRect(box, Paint()..shader = ui.Gradient.radial(h, 0.95, const [Color(0xFFE85A3A), Color(0xFFA8241E), Color(0xFF5A0E0E)], const [0, 0.55, 1]));
        if (!_small) {
          // La tovaglia a quadri sul fondo.
          final cloth = Rect.fromLTRB(box.left, box.bottom - 0.16, box.right, box.bottom);
          c.drawRect(cloth, fill(cream));
          for (var j = 0; j * 0.06 < w; j++) {
            if (j.isEven) c.drawRect(Rect.fromLTWH(box.left + j * 0.06, cloth.top, 0.06, cloth.height), fill(const Color(0x99C8282E)));
          }
          for (var j = 0; j < 3; j++) {
            c.drawRect(Rect.fromLTWH(box.left, cloth.top + j * 0.06, w, 0.03), fill(const Color(0x66C8282E)));
          }
        }
        for (var j = 0; j < (_small ? 6 : 11); j++) {
          final o = Offset(x(0.06 + (j * 0.618 % 1) * 0.88), box.top + 0.08 + (j * 0.41 % 1) * 0.62);
          final strand = Path()..moveTo(o.dx - 0.08, o.dy);
          for (var t = 0; t < 4; t++) {
            strand.quadraticBezierTo(o.dx - 0.06 + t * 0.04, o.dy + (t.isEven ? -0.05 : 0.05), o.dx - 0.04 + t * 0.04, o.dy);
          }
          c.drawPath(strand, line(const Color(0xFF7A4A1A), 0.02));
          c.drawPath(strand, line(const Color(0xFFFFE08A), 0.011));
          if (j % 3 == 0) {
            final ball = oval(o + const Offset(0.05, -0.02), 0.06, 0.055);
            piece(c, [(ball, const Color(0xFF7A3A1E))], d: 0.012, weight: 0.4);
          }
        }
    }
  }

  // --- Sulle spalle -------------------------------------------------------------

  static void back(Canvas c, BackItem id, _DGeo g) {
    final h = g.head;
    switch (id) {
      case BackItem.violinCase:
        at(c, Offset(h.dx + 0.27, h.dy + 0.12), 1, 0.42, () {
          final body = Path()
            ..moveTo(0, -0.34)
            ..cubicTo(0.07, -0.34, 0.09, -0.24, 0.07, -0.14)
            ..cubicTo(0.06, -0.06, 0.12, 0.0, 0.12, 0.12)
            ..cubicTo(0.12, 0.27, 0.06, 0.32, 0, 0.32)
            ..cubicTo(-0.06, 0.32, -0.12, 0.27, -0.12, 0.12)
            ..cubicTo(-0.12, 0.0, -0.06, -0.06, -0.07, -0.14)
            ..cubicTo(-0.09, -0.24, -0.07, -0.34, 0, -0.34)
            ..close();
          piece(c, [(body, const Color(0xFF3A2216))]);
          c.drawLine(const Offset(0, -0.3), const Offset(0, 0.28), line(const Color(0xFF6A4A2A), _thin));
          for (final y in [-0.2, 0.05, 0.2]) {
            toon(c, rrect(Rect.fromCenter(center: Offset(0.0, y), width: 0.05, height: 0.025), 0.006), gold, d: 0.01);
          }
        });
        // La cinghia sul petto.
        c.drawLine(Offset(h.dx + 0.2, 0.84), Offset(h.dx - 0.3, 1.06), line(ink, _ow * 2 + 0.03));
        c.drawLine(Offset(h.dx + 0.2, 0.84), Offset(h.dx - 0.3, 1.06), line(const Color(0xFF4A2E1C), 0.03));
      case BackItem.gildedWings:
        for (final sd in [-1.0, 1.0]) {
          final root = Offset(h.dx + sd * 0.2, 0.72);
          for (final (row, len, col) in [(0, 0.64, const Color(0xFFA87A2A)), (1, 0.5, const Color(0xFFC99A3E)), (2, 0.34, const Color(0xFFE8C46A))]) {
            final feathers = <(Path, Color)>[];
            for (var j = 0; j < 6; j++) {
              final a = -pi / 2 + sd * (0.3 + j * 0.24);
              final l = len * (1 - j * 0.07);
              final tip = root + Offset(cos(a), sin(a)) * l;
              final nrm = Offset(-sin(a), cos(a)) * (0.03 + row * 0.004);
              final mid = Offset.lerp(root, tip, 0.6)!;
              feathers.add((
                Path()
                  ..moveTo(root.dx + nrm.dx * 0.5, root.dy + nrm.dy * 0.5)
                  ..quadraticBezierTo(mid.dx + nrm.dx * 1.6, mid.dy + nrm.dy * 1.6, tip.dx, tip.dy)
                  ..quadraticBezierTo(mid.dx - nrm.dx * 1.6, mid.dy - nrm.dy * 1.6, root.dx - nrm.dx * 0.5, root.dy - nrm.dy * 0.5)
                  ..close(),
                col,
              ));
            }
            piece(c, feathers.reversed.toList(), d: 0.02, weight: 0.6);
            if (!_small) {
              for (final (f, _) in feathers) {
                final m = f.computeMetrics().first;
                final tip = m.getTangentForOffset(m.length / 2)!.position;
                c.drawLine(root, Offset.lerp(root, tip, 0.85)!, line(const Color(0xFF8C6420), _thin * 0.6));
              }
            }
          }
        }
      case BackItem.skeleton:
        // Lo scheletro gigante che si sporge da dietro: un tono sopra il buio.
        const bone = Color(0xFF6A5A8E);
        final o = Offset(h.dx - 0.27, g.top + 0.04);
        final skull = Path()
          ..addOval(Rect.fromCenter(center: o, width: 0.4, height: 0.37))
          ..addRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: o + const Offset(0, 0.16), width: 0.24, height: 0.13), const Radius.circular(0.04)));
        final whole = Path.combine(PathOperation.union, Path()..addOval(Rect.fromCenter(center: o, width: 0.4, height: 0.37)), skull);
        c.drawPath(whole, line(ink, _ow * 2));
        toon(c, whole, bone, d: 0.05);
        final sockets = Path()
          ..addOval(Rect.fromCenter(center: o + const Offset(-0.085, 0.02), width: 0.1, height: 0.11))
          ..addOval(Rect.fromCenter(center: o + const Offset(0.085, 0.02), width: 0.1, height: 0.11));
        c.drawPath(sockets, fill(const Color(0xFF120A1C)));
        c.drawPath(poly([o + const Offset(-0.015, 0.1), o + const Offset(0.015, 0.1), o + const Offset(0, 0.07)]), fill(const Color(0xFF120A1C)));
        for (var t = -2; t <= 2; t++) {
          c.drawLine(o + Offset(t * 0.035, 0.13), o + Offset(t * 0.035, 0.2), line(const Color(0xFF120A1C), _thin));
        }
        for (final s in [-1.0, 1.0]) {
          c.drawCircle(o + Offset(s * 0.085, 0.03), 0.018, fill(const Color(0xFF3FE0D0)));
        }
        // La mano ossuta posata sulla spalla.
        final hand = Offset(h.dx + 0.34, 0.8);
        for (var j = 0; j < 4; j++) {
          final f = rrect(Rect.fromCenter(center: hand + Offset(j * 0.03 - 0.045, 0.02), width: 0.022, height: 0.07), 0.01);
          piece(c, [(f, bone)], d: 0.008, weight: 0.4);
        }
      case BackItem.parasol:
        at(c, Offset(h.dx + 0.24, g.top - 0.02), 1, 0.35, () {
          final canopy = Path()
            ..moveTo(-0.3, 0.04)
            ..quadraticBezierTo(-0.28, -0.24, 0, -0.26)
            ..quadraticBezierTo(0.28, -0.24, 0.3, 0.04);
          for (var j = 0; j < 4; j++) {
            final x0 = 0.3 - j * 0.15;
            canopy.quadraticBezierTo(x0 - 0.075, -0.02, x0 - 0.15, 0.04);
          }
          canopy.close();
          c.drawLine(const Offset(0, -0.3), const Offset(0, 0.5), line(ink, 0.012 + _ow * 2));
          c.drawLine(const Offset(0, -0.3), const Offset(0, 0.5), line(const Color(0xFF6A4A2A), 0.012));
          piece(c, [(canopy, const Color(0xFFE6C9D2))], d: 0.03);
          for (var j = 0; j < 5; j++) {
            c.drawLine(const Offset(0, -0.26), Offset(-0.3 + j * 0.15, 0.04), line(const Color(0xFFB88C9C), _thin));
          }
          if (!_small) {
            for (var j = 0; j < 8; j++) {
              c.drawCircle(Offset(-0.26 + j * 0.075, 0.055), 0.013, line(cream, _thin * 0.8));
            }
          }
        });
      case BackItem.saxophone:
        at(c, Offset(h.dx - 0.3, h.dy + 0.16), 1, -0.25, () {
          final tube = Path()
            ..moveTo(-0.02, -0.36)
            ..lineTo(0.03, -0.36)
            ..lineTo(0.05, 0.12)
            ..quadraticBezierTo(0.06, 0.24, -0.04, 0.26)
            ..quadraticBezierTo(-0.12, 0.27, -0.14, 0.16)
            ..lineTo(-0.2, 0.06)
            ..lineTo(-0.1, 0.03)
            ..lineTo(-0.08, 0.13)
            ..quadraticBezierTo(-0.06, 0.18, -0.02, 0.16)
            ..lineTo(-0.02, -0.36)
            ..close();
          final neck = Path()
            ..moveTo(-0.02, -0.36)
            ..quadraticBezierTo(0.0, -0.44, 0.08, -0.44)
            ..lineTo(0.08, -0.41)
            ..quadraticBezierTo(0.03, -0.41, 0.03, -0.36)
            ..close();
          piece(c, [(tube, gold), (neck, gold)], d: 0.02);
          for (var j = 0; j < 5; j++) {
            final y = -0.25 + j * 0.07;
            c.drawCircle(Offset(0.012, y), 0.014, fill(const Color(0xFFFFF0C8)));
            c.drawCircle(Offset(0.012, y), 0.014, line(ink, _thin * 0.7));
          }
        });
      case BackItem.none || BackItem.angelWings || BackItem.batWings || BackItem.butterflyWings || BackItem.dragonWings:
        break;
    }
  }

  // --- In testa -----------------------------------------------------------------

  /// Il bagliore intorno alla sagoma della testa, dei capelli e del cappello:
  /// due giri larghi intorno all'inchiostro, uno tenue e uno vivo.
  static void headGlow(Canvas c, List<Path> outline, Color color) {
    for (final (wide, alpha) in [(0.07, 0.22), (0.035, 0.6)]) {
      final paint = line(color.withValues(alpha: alpha), _ow * 2 + wide);
      for (final p in outline) {
        c.drawPath(p, paint);
      }
    }
  }

  static void headFx(Canvas c, HeadFx id, _DGeo g) {
    final h = g.head;
    final top = g.crown;
    switch (id) {
      case HeadFx.halo:
        final o = Offset(h.dx, top - 0.05);
        c.drawPath(oval(o, 0.46, 0.17), fill(const Color(0x22FFE2A0)));
        piece(c, [(Path.combine(PathOperation.difference, oval(o, 0.36, 0.1), oval(o, 0.27, 0.055)), const Color(0xFFFFD86A))], d: 0.012, weight: 0.6);
      case HeadFx.starOrbit:
        final o = Offset(h.dx, top - 0.02);
        final orbit = Rect.fromCenter(center: o, width: g.width * 1.7, height: 0.12);
        c.drawArc(orbit, pi * 1.05, pi * 0.9, false, line(const Color(0xAAE8E0FF), _thin * 0.9));
        for (final a in [pi * 1.1, pi * 1.5, pi * 1.85]) {
          final p = orbit.center + Offset(cos(a) * orbit.width / 2, sin(a) * orbit.height / 2);
          piece(c, [(star(p, 0.032, 5, 0.45), const Color(0xFFF4E7C0))], d: 0.008, weight: 0.3);
        }
      case HeadFx.sparks:
        for (var j = 0; j < 6; j++) {
          final a = pi * (1.05 + j * 0.18);
          final p = Offset(h.dx, (top + g.chin) / 2) + Offset(cos(a) * g.width * 0.95, sin(a) * (g.chin - top) * 0.62);
          final s = 0.018 + 0.008 * (j % 2);
          c.drawPath(star(p, s * 1.6, 4, 0.3, turn: j * 0.3), fill(const Color(0x66FF9A3A)));
          c.drawPath(star(p, s, 4, 0.3, turn: j * 0.3), fill(const Color(0xFFFFE08A)));
        }
      case HeadFx.hearts:
        for (final (dx, dy, s, turn) in [(-0.29, 0.02, 0.024, -0.3), (0.31, -0.04, 0.03, 0.25), (0.2, -0.12, 0.02, 0.1), (-0.17, -0.1, 0.018, -0.15)]) {
          at(c, Offset(h.dx + dx, top + dy), 1, turn, () => piece(c, [(heart(Offset.zero, s), const Color(0xFFE8506E))], d: s * 0.35, weight: 0.35));
        }
      case HeadFx.coins:
        final o = Offset(h.dx, top - 0.03);
        final orbit = Rect.fromCenter(center: o, width: g.width * 1.9, height: 0.14);
        c.drawArc(orbit, pi * 1.05, pi * 0.9, false, line(const Color(0x88FFD27A), _thin * 0.8));
        for (final a in [pi * 1.15, pi * 1.5, pi * 1.82]) {
          coin(c, orbit.center + Offset(cos(a) * orbit.width / 2, sin(a) * orbit.height / 2), 0.028);
        }
      case HeadFx.rainCloud:
        // La nuvoletta della sfiga: piove solo su di lui.
        final o = Offset(h.dx + 0.02, top - 0.1);
        final cloud = Path()
          ..addOval(Rect.fromCircle(center: o + const Offset(-0.1, 0.02), radius: 0.06))
          ..addOval(Rect.fromCircle(center: o + const Offset(-0.02, -0.03), radius: 0.08))
          ..addOval(Rect.fromCircle(center: o + const Offset(0.08, 0.0), radius: 0.065))
          ..addRRect(RRect.fromRectAndRadius(Rect.fromLTRB(o.dx - 0.15, o.dy, o.dx + 0.14, o.dy + 0.07), const Radius.circular(0.035)));
        final shape = Path.combine(PathOperation.union, cloud, Path()..addRect(Rect.fromLTRB(o.dx - 0.1, o.dy, o.dx + 0.1, o.dy + 0.05)));
        for (var j = 0; j < 5; j++) {
          final x0 = o.dx - 0.11 + j * 0.055;
          final y0 = o.dy + 0.09 + (j.isOdd ? 0.03 : 0);
          c.drawLine(Offset(x0, y0), Offset(x0 - 0.012, y0 + 0.05), line(const Color(0xFF8FC8F0), _thin * 1.6));
        }
        piece(c, [(shape, const Color(0xFF6A7080))], d: 0.03, weight: 0.7);
        if (!_small) {
          final bolt = poly([o + const Offset(0.01, 0.05), o + const Offset(0.04, 0.05), o + const Offset(0.02, 0.09), o + const Offset(0.045, 0.09), o + const Offset(-0.005, 0.15), o + const Offset(0.01, 0.1), o + const Offset(-0.01, 0.1)]);
          c.drawPath(bolt, fill(const Color(0xFFFFE08A)));
          c.drawPath(bolt, line(ink, _thin * 0.7));
        }
      case HeadFx.dizzyBirds:
        // Dopo il cazzotto: gli uccellini che girano intorno alla testa.
        final o = Offset(h.dx, top - 0.02);
        final orbit = Rect.fromCenter(center: o, width: g.width * 1.6, height: 0.1);
        c.drawArc(orbit, pi * 1.02, pi * 0.96, false, line(const Color(0x99FFFFFF), _thin * 0.8));
        for (final (a, flip) in [(pi * 1.12, -1.0), (pi * 1.5, 1.0), (pi * 1.88, 1.0)]) {
          final p = orbit.center + Offset(cos(a) * orbit.width / 2, sin(a) * orbit.height / 2);
          at(c, p, 1, 0, () {
            final body = oval(Offset.zero, 0.05, 0.036);
            final head = oval(Offset(flip * 0.022, -0.014), 0.026, 0.026);
            final wing = Path()
              ..moveTo(-flip * 0.005, -0.005)
              ..quadraticBezierTo(-flip * 0.02, -0.04, -flip * 0.03, -0.035)
              ..quadraticBezierTo(-flip * 0.02, -0.01, -flip * 0.005, -0.005)
              ..close();
            piece(c, [(body, const Color(0xFFFFD84A)), (head, const Color(0xFFFFD84A)), (wing, const Color(0xFFE8B83A))], d: 0.008, weight: 0.35);
            c.drawPath(poly([Offset(flip * 0.033, -0.017), Offset(flip * 0.046, -0.012), Offset(flip * 0.033, -0.008)]), fill(const Color(0xFFE8742A)));
            c.drawCircle(Offset(flip * 0.026, -0.018), 0.004, fill(ink));
          });
        }
        if (!_small) {
          for (final a in [pi * 1.3, pi * 1.7]) {
            c.drawPath(star(orbit.center + Offset(cos(a) * orbit.width / 2, sin(a) * orbit.height / 2), 0.018, 4, 0.3), fill(white));
          }
        }
      case HeadFx.none || HeadFx.ghostGlow || HeadFx.emberGlow:
        break;
    }
  }

  static void coin(Canvas c, Offset p, double r) {
    piece(c, [(oval(p, r * 2, r * 2), gold)], d: r * 0.3, weight: 0.3);
    c.drawCircle(p, r * 0.62, line(const Color(0xFF8C6420), _thin * 0.8));
  }

  // --- La faccia ------------------------------------------------------------------

  static void faceExtras(Canvas c, List<FaceExtra> ids, _DGeo g) {
    final dx = g.eyeDx;
    for (final id in ids) {
      switch (id) {
        case FaceExtra.blush:
          for (final s in [-1.0, 1.0]) {
            final o = Offset(g.cx + s * dx * 1.25, (g.eyeY + g.mouth) / 2 + 0.004);
            c.drawOval(Rect.fromCenter(center: o, width: dx * 0.95, height: dx * 0.45), fill(const Color(0x66FF6F7A)));
            if (!_small) {
              for (var j = -1; j <= 1; j++) {
                final x = o.dx + j * dx * 0.2;
                c.drawLine(Offset(x + dx * 0.06, o.dy - dx * 0.1), Offset(x - dx * 0.06, o.dy + dx * 0.1), line(const Color(0xAAE0485A), _thin * 0.7));
              }
            }
          }
        case FaceExtra.tear:
          // La lacrima scende sulla guancia, sotto anche le lenti scure.
          final o = Offset(g.leftEye.dx - dx * 0.12, g.eyeY + dx * 0.78);
          c.drawLine(Offset(o.dx + dx * 0.02, g.eyeY + dx * 0.3), o, line(const Color(0x998FD8FF), max(_thin, dx * 0.06)));
          final drop = Path()
            ..moveTo(o.dx, o.dy - dx * 0.26)
            ..quadraticBezierTo(o.dx + dx * 0.22, o.dy + dx * 0.08, o.dx, o.dy + dx * 0.18)
            ..quadraticBezierTo(o.dx - dx * 0.22, o.dy + dx * 0.08, o.dx, o.dy - dx * 0.26)
            ..close();
          c.drawPath(drop, fill(const Color(0xFF8FD8FF)));
          c.drawPath(drop, line(ink, _thin * 0.8));
          c.drawCircle(o + Offset(-dx * 0.03, 0), dx * 0.03, fill(white));
        case FaceExtra.stitchScar:
          // La cicatrice cucita dal sopracciglio alla guancia.
          final a = Offset(g.rightEye.dx + dx * 0.0, g.eyeY - dx * 0.75);
          final b = Offset(g.rightEye.dx + dx * 0.55, g.eyeY + dx * 0.85);
          c.drawLine(a, b, line(const Color(0xFFB0484A), max(_thin * 2.2, dx * 0.09)));
          c.drawLine(a, b, line(const Color(0xFF6A2224), _thin * 0.8));
          for (var j = 1; j < 6; j++) {
            final p = Offset.lerp(a, b, j / 6)!;
            c.drawLine(p + Offset(-dx * 0.16, dx * 0.05), p + Offset(dx * 0.16, -dx * 0.05), line(ink, max(_thin, dx * 0.04)));
          }
        case FaceExtra.skullPaint:
          for (final s in [-1.0, 1.0]) {
            final o = Offset(g.cx + s * dx, g.eyeY);
            c.drawCircle(o, dx * 0.62, fill(const Color(0xCC1A0E22)));
            if (!_small) {
              for (var j = 0; j < 8; j++) {
                c.drawCircle(o + Offset(cos(j * pi / 4), sin(j * pi / 4)) * dx * 0.72, dx * 0.08, fill(const Color(0xFF3FE0D0)));
              }
            }
          }
          final m = Offset(g.cx, g.mouth);
          c.drawLine(m - Offset(dx * 0.8, 0), m + Offset(dx * 0.8, 0), line(ink, _thin));
          if (!_small) {
            for (var j = -3; j <= 3; j++) {
              c.drawLine(m + Offset(j * dx * 0.22, -dx * 0.12), m + Offset(j * dx * 0.22, dx * 0.12), line(ink, _thin * 0.8));
            }
          }
        case FaceExtra.beautyStar:
          c.drawPath(star(Offset(g.rightEye.dx + dx * 0.4, g.eyeY + dx * 0.68), dx * 0.34, 5, 0.45), fill(night));
        case FaceExtra.goldTooth:
          // Il sorriso storto col dente d'oro, e il lampo sopra.
          final o = Offset(g.cx + dx * 0.3, g.mouth + dx * 0.06);
          final grin = rrect(Rect.fromCenter(center: o + Offset(-dx * 0.08, 0), width: dx * 0.62, height: dx * 0.26), dx * 0.12);
          c.drawPath(grin, fill(const Color(0xFF2A1016)));
          c.drawPath(rrect(Rect.fromCenter(center: o + Offset(-dx * 0.26, -dx * 0.03), width: dx * 0.18, height: dx * 0.16), dx * 0.03), fill(cream));
          final tooth = rrect(Rect.fromCenter(center: o + Offset(dx * 0.02, -dx * 0.02), width: dx * 0.22, height: dx * 0.2), dx * 0.04);
          c.drawPath(tooth, fill(gold));
          c.drawPath(tooth, line(ink, _thin * 0.6));
          c.drawPath(grin, line(ink, _thin * 0.8));
          c.drawPath(star(o + Offset(dx * 0.22, -dx * 0.22), dx * 0.14, 4, 0.28), fill(white));
        case FaceExtra.blackEye:
          // L'occhio nero della rissa di ieri sera: viola, con l'alone giallo.
          final o = g.leftEye;
          // Largo abbastanza da spuntare anche da sotto le lenti scure.
          c.drawOval(Rect.fromCenter(center: o + Offset(0, dx * 0.14), width: dx * 1.6, height: dx * 1.3), fill(const Color(0x77C8B83A)));
          c.drawOval(Rect.fromCenter(center: o + Offset(0, dx * 0.1), width: dx * 1.3, height: dx * 1.05), fill(const Color(0xAA5A2A6A)));
          c.drawOval(Rect.fromCenter(center: o + Offset(0, dx * 0.06), width: dx * 0.95, height: dx * 0.7), fill(const Color(0xBB3A1248)));
        case FaceExtra.lipstickKiss:
          // Il bacio col rossetto sulla guancia: chi sarà stata?
          final o = Offset(g.cx + dx * 1.18, (g.nose + g.mouth) / 2);
          at(c, o, 1.5, -0.35, () {
            for (final s in [-1.0, 1.0]) {
              final lip = Path()
                ..moveTo(-dx * 0.3, 0)
                ..quadraticBezierTo(-dx * 0.15, s * -dx * 0.2, 0, s * -dx * 0.06)
                ..quadraticBezierTo(dx * 0.15, s * -dx * 0.2, dx * 0.3, 0)
                ..quadraticBezierTo(0, s * -dx * 0.03, -dx * 0.3, 0)
                ..close();
              c.drawPath(lip.shift(Offset(0, s * -dx * 0.02)), fill(const Color(0xDDD0203A)));
            }
          });
        case FaceExtra.plaster:
          // Il cerotto a croce sullo zigomo.
          final o = Offset(g.cx - dx * 1.15, g.eyeY + dx * 0.8);
          for (final turn in [pi / 4, -pi / 4]) {
            at(c, o, 1.3, turn, () {
              final strip = rrect(Rect.fromCenter(center: Offset.zero, width: dx * 0.75, height: dx * 0.24), dx * 0.06);
              c.drawPath(strip, fill(const Color(0xFFE8C8A0)));
              c.drawPath(strip, line(ink, _thin * 0.7));
              if (!_small) {
                for (final x in [-0.22, 0.22]) {
                  c.drawCircle(Offset(x * dx, 0), dx * 0.025, fill(const Color(0xFFB8946A)));
                }
              }
            });
          }
      }
    }
  }

  /// La luce negli occhi, sopra le pupille in [pupils].
  static void eyeShine(Canvas c, EyeShine id, List<Offset> pupils, double size) {
    // Al tavolo più grande, che si veda.
    final r = _small ? size * 1.35 : size;
    for (final e in pupils) {
      switch (id) {
        case EyeShine.none:
          return;
        case EyeShine.glint:
          c.drawPath(star(e + Offset(-r * 0.4, -r * 0.4), r * 0.95, 4, 0.25), fill(white));
        case EyeShine.star:
          c.drawPath(star(e, r * 1.3, 5, 0.45), fill(const Color(0xFFFFE08A)));
          c.drawPath(star(e, r * 1.3, 5, 0.45), line(ink, _thin * 0.5));
        case EyeShine.heart:
          c.drawPath(heart(e, r), fill(const Color(0xFFE8304E)));
          c.drawPath(heart(e, r), line(ink, _thin * 0.6));
          c.drawCircle(e + Offset(-r * 0.35, -r * 0.35), r * 0.22, fill(white));
        case EyeShine.spiral:
          final p = Path()..moveTo(e.dx, e.dy);
          for (var t = 0.0; t < 4 * pi; t += 0.3) {
            p.lineTo(e.dx + cos(t) * r * 1.1 * t / (4 * pi), e.dy + sin(t) * r * 1.1 * t / (4 * pi));
          }
          c.drawCircle(e, r * 1.15, fill(white));
          c.drawPath(p, line(ink, _thin * 0.6));
        case EyeShine.lira:
          // Gli occhi a lire: la L con le due sbarre, verde banconota.
          c.drawCircle(e, r * 1.1, fill(const Color(0xFF2E8A4A)));
          final ink2 = line(const Color(0xFFE8FFD8), max(_thin * 0.9, r * 0.22));
          final l = Path()
            ..moveTo(e.dx + r * 0.25, e.dy - r * 0.6)
            ..quadraticBezierTo(e.dx - r * 0.3, e.dy - r * 0.7, e.dx - r * 0.15, e.dy - r * 0.05)
            ..quadraticBezierTo(e.dx - r * 0.05, e.dy + r * 0.4, e.dx - r * 0.45, e.dy + r * 0.55)
            ..lineTo(e.dx + r * 0.5, e.dy + r * 0.55);
          c.drawPath(l, ink2);
          c.drawLine(e + Offset(-r * 0.5, -r * 0.08), e + Offset(r * 0.25, -r * 0.08), ink2);
          c.drawLine(e + Offset(-r * 0.5, r * 0.18), e + Offset(r * 0.25, r * 0.18), ink2);
        case EyeShine.flame:
          final f = Path()
            ..moveTo(e.dx, e.dy - r * 1.5)
            ..quadraticBezierTo(e.dx + r * 1.1, e.dy - r * 0.2, e.dx + r * 0.55, e.dy + r * 0.7)
            ..quadraticBezierTo(e.dx, e.dy + r * 1.0, e.dx - r * 0.55, e.dy + r * 0.7)
            ..quadraticBezierTo(e.dx - r * 1.1, e.dy - r * 0.2, e.dx, e.dy - r * 1.5)
            ..close();
          c.drawPath(f, fill(const Color(0xFFFF7A2A)));
          c.drawPath(f.transform((Matrix4.identity()..translateByDouble(e.dx, e.dy + r * 0.25, 0, 1)..scaleByDouble(0.55, 0.55, 1, 1)..translateByDouble(-e.dx, -e.dy, 0, 1)).storage), fill(const Color(0xFFFFE08A)));
          c.drawPath(f, line(ink, _thin * 0.5));
        case EyeShine.diamond:
          final d = poly([e + Offset(0, -r * 1.2), e + Offset(r * 0.9, -r * 0.3), e + Offset(0, r * 1.1), e + Offset(-r * 0.9, -r * 0.3)]);
          c.drawPath(d, fill(const Color(0xFFBFEFFF)));
          c.drawPath(poly([e + Offset(0, -r * 1.2), e + Offset(r * 0.9, -r * 0.3), e + Offset(0, -r * 0.3)]), fill(const Color(0xFF7AC8E8)));
          c.drawPath(d, line(ink, _thin * 0.6));
          c.drawCircle(e + Offset(-r * 0.3, -r * 0.5), r * 0.18, fill(white));
        case EyeShine.crosshair:
          // Il mirino: occhio da sicario.
          final red = line(const Color(0xFFE8303A), max(_thin * 0.7, r * 0.16));
          c.drawCircle(e, r * 0.95, red);
          for (final d in [Offset(r * 1.4, 0), Offset(-r * 1.4, 0), Offset(0, r * 1.4), Offset(0, -r * 1.4)]) {
            c.drawLine(e + d * 0.45, e + d, red);
          }
          c.drawCircle(e, r * 0.18, fill(const Color(0xFFE8303A)));
      }
    }
  }

  // --- In mano ----------------------------------------------------------------------

  /// Una mano che sale dal bordo di sotto con [item] nel pugno (l'origine
  /// locale, la cosa in su). [side] è -1 a sinistra del ritratto.
  static void held(Canvas c, HeldItem item, _DGeo g, {required double side, required Color sleeve, required Color skin, required Color cuff}) {
    final grip = Offset(g.cx + side * g.width * 0.86, 0.8);
    final elbow = Offset(grip.dx + side * 0.12, 1.2);
    final wrist = grip + Offset(side * 0.02, 0.07);
    c.drawLine(elbow, wrist, line(ink, 0.12 + _ow * 2));
    c.drawLine(elbow, wrist, line(sleeve, 0.12));
    c.drawLine(elbow + Offset(side * 0.03, 0), wrist + Offset(side * 0.025, 0.0), line(dark(sleeve), 0.05));
    piece(c, [(oval(wrist + const Offset(0, -0.005), 0.12, 0.05), cuff)], d: 0.01, weight: 0.5);
    // La mano e la cosa un poco più grandi del vero: si leggono anche al tavolo.
    at(c, grip, 1.22, side * 0.16, () {
      piece(c, [(oval(const Offset(0, 0.02), 0.11, 0.1), skin)], d: 0.02);
      _item(c, item);
      final fingers = <(Path, Color)>[
        for (var j = 0; j < 4; j++) (rrect(Rect.fromCenter(center: Offset(-side * 0.035, -0.022 + j * 0.026), width: 0.075, height: 0.03), 0.015), skin),
      ];
      piece(c, [...fingers, (rrect(Rect.fromCenter(center: Offset(side * 0.04, -0.03), width: 0.03, height: 0.07), 0.015), skin)], d: 0.012);
    });
  }

  /// La cosa tenuta, con la presa nell'origine e la punta in su.
  static void _item(Canvas c, HeldItem item) {
    switch (item) {
      case HeldItem.grappa:
        final bottle = Path()
          ..moveTo(-0.022, -0.3)
          ..lineTo(0.022, -0.3)
          ..lineTo(0.022, -0.2)
          ..quadraticBezierTo(0.065, -0.17, 0.065, -0.1)
          ..lineTo(0.06, 0.08)
          ..quadraticBezierTo(0.06, 0.1, 0.04, 0.1)
          ..lineTo(-0.04, 0.1)
          ..quadraticBezierTo(-0.06, 0.1, -0.06, 0.08)
          ..lineTo(-0.065, -0.1)
          ..quadraticBezierTo(-0.065, -0.17, -0.022, -0.2)
          ..close();
        piece(c, [(bottle, const Color(0xFF5E8C6A)), (rrect(const Rect.fromLTRB(-0.02, -0.34, 0.02, -0.29), 0.008), const Color(0xFFB8864A))], d: 0.02);
        toon(c, rrect(const Rect.fromLTRB(-0.05, -0.1, 0.05, -0.02), 0.006), cream, d: 0.01);
        c.drawLine(const Offset(-0.035, -0.07), const Offset(0.035, -0.07), line(const Color(0xFF8C1C2C), _thin));
        if (!_small) c.drawLine(const Offset(-0.035, -0.045), const Offset(0.02, -0.045), line(ink, _thin * 0.6));
        c.drawLine(const Offset(-0.045, -0.17), const Offset(-0.05, 0.05), line(const Color(0x88FFFFFF), _thin * 1.4));
      case HeldItem.rose:
        final stem = Path()
          ..moveTo(0, 0.1)
          ..quadraticBezierTo(0.02, -0.1, -0.01, -0.24);
        c.drawPath(stem, line(ink, 0.014 + _ow * 2));
        c.drawPath(stem, line(const Color(0xFF3A6A2E), 0.014));
        for (final s in [-1.0, 1.0]) {
          final leaf = Path()
            ..moveTo(0.008, -0.08 + s * 0.02)
            ..quadraticBezierTo(0.06 * s, -0.14, 0.09 * s, -0.11 + s * 0.02)
            ..quadraticBezierTo(0.05 * s, -0.06, 0.008, -0.08 + s * 0.02)
            ..close();
          piece(c, [(leaf, const Color(0xFF4A8A3A))], d: 0.01);
        }
        const bloom = Offset(-0.01, -0.28);
        piece(c, [
          (oval(bloom + const Offset(0, 0.015), 0.12, 0.09), const Color(0xFFA8182C)),
          (oval(bloom + const Offset(-0.025, -0.005), 0.07, 0.07), const Color(0xFFC8283A)),
          (oval(bloom + const Offset(0.025, -0.005), 0.07, 0.07), const Color(0xFFC8283A)),
          (oval(bloom + const Offset(0, -0.02), 0.06, 0.05), const Color(0xFFE0485A)),
        ], d: 0.012);
        c.drawArc(Rect.fromCenter(center: bloom + const Offset(0, -0.015), width: 0.03, height: 0.025), 0, pi * 1.5, false, line(ink, _thin * 0.8));
      case HeldItem.revolver:
        final grip = Path()
          ..moveTo(-0.03, -0.05)
          ..lineTo(0.03, -0.05)
          ..lineTo(0.045, 0.09)
          ..quadraticBezierTo(0.0, 0.11, -0.035, 0.08)
          ..close();
        piece(c, [
          (grip, const Color(0xFF6A3A1E)),
          (rrect(const Rect.fromLTRB(-0.018, -0.3, 0.018, -0.1), 0.008), const Color(0xFF5A5E66)),
          (rrect(const Rect.fromLTRB(-0.04, -0.12, 0.04, -0.04), 0.02), const Color(0xFF6A6E76)),
          (rrect(const Rect.fromLTRB(-0.006, -0.32, 0.006, -0.29), 0.003), const Color(0xFF5A5E66)),
        ], d: 0.018);
        for (final y in [-0.1, -0.06]) {
          c.drawLine(Offset(-0.025, y), Offset(0.025, y), line(ink, _thin * 0.7));
        }
        c.drawLine(const Offset(-0.008, -0.28), const Offset(-0.008, -0.13), line(const Color(0xAAFFFFFF), _thin));
      case HeldItem.cards:
        for (var j = 0; j < 5; j++) {
          at(c, const Offset(0, 0.05), 1, (j - 2) * 0.26, () {
            piece(c, [(rrect(const Rect.fromLTRB(-0.045, -0.26, 0.045, -0.12), 0.012), cream)], d: 0.012);
            final red = j.isOdd;
            const mark = Offset(0, -0.21);
            final col = red ? const Color(0xFFC0272D) : ink;
            if (j == 4) {
              c.drawPath(star(mark, 0.022, 4, 0.4), fill(col));
            } else if (red) {
              c.drawPath(heart(mark, 0.016), fill(col));
            } else {
              for (final o in const [Offset(0, -0.006), Offset(-0.01, 0.006), Offset(0.01, 0.006)]) {
                c.drawCircle(mark + o, 0.011, fill(col));
              }
            }
          });
        }
      case HeldItem.coupe:
        final bowl = Path()
          ..moveTo(-0.08, -0.22)
          ..lineTo(0.08, -0.22)
          ..quadraticBezierTo(0.07, -0.14, 0.0, -0.13)
          ..quadraticBezierTo(-0.07, -0.14, -0.08, -0.22)
          ..close();
        piece(c, [
          (rrect(const Rect.fromLTRB(-0.008, -0.14, 0.008, 0.06), 0.004), const Color(0xFFD8E4EC)),
          (oval(const Offset(0, 0.07), 0.09, 0.025), const Color(0xFFD8E4EC)),
          (bowl, const Color(0xFFF0D27A)),
        ], d: 0.014);
        c.drawPath(oval(const Offset(0, -0.22), 0.16, 0.03), fill(const Color(0xFFFFE8A8)));
        c.drawPath(oval(const Offset(0, -0.22), 0.16, 0.03), line(ink, _thin * 0.7));
        if (!_small) {
          for (final b in const [Offset(-0.02, -0.17), Offset(0.025, -0.19), Offset(0.0, -0.25), Offset(0.03, -0.27)]) {
            c.drawCircle(b, 0.006, line(white, _thin * 0.6));
          }
        }
      case HeldItem.candle:
        piece(c, [(rrect(const Rect.fromLTRB(-0.03, -0.22, 0.03, 0.08), 0.01), const Color(0xFFF4ECD8))], d: 0.016);
        c.drawPath(
          Path()
            ..moveTo(-0.03, -0.2)
            ..quadraticBezierTo(-0.034, -0.14, -0.02, -0.15)
            ..quadraticBezierTo(-0.01, -0.18, 0.0, -0.2)
            ..close(),
          fill(const Color(0xFFFFFAEC)),
        );
        c.drawCircle(const Offset(0, -0.27), 0.05, fill(const Color(0x22FFD27A)));
        final flame = Path()
          ..moveTo(0, -0.32)
          ..quadraticBezierTo(0.03, -0.26, 0, -0.23)
          ..quadraticBezierTo(-0.03, -0.26, 0, -0.32)
          ..close();
        piece(c, [(flame, const Color(0xFFFFB347))], d: 0.008, weight: 0.4);
        c.drawPath(oval(const Offset(0, -0.25), 0.014, 0.025), fill(const Color(0xFFFFF4C8)));
      case HeldItem.cannolo:
        // Il cannolo siciliano, grosso come un sigaro di lusso.
        at(c, const Offset(0, -0.1), 1, -0.5, () {
          final shell = rrect(const Rect.fromLTRB(-0.05, -0.17, 0.05, 0.13), 0.04);
          piece(c, [(shell, const Color(0xFFC88A3E))], d: 0.022);
          if (!_small) {
            for (var j = 0; j < 5; j++) {
              c.drawLine(Offset(-0.045, -0.12 + j * 0.055), Offset(0.045, -0.1 + j * 0.055), line(const Color(0xFF8A5A22), _thin));
            }
          }
          for (final (y, s) in [(-0.17, -1.0), (0.13, 1.0)]) {
            final cream = oval(Offset(0, y + s * 0.012), 0.11, 0.055);
            piece(c, [(cream, const Color(0xFFF8F0DC))], d: 0.01, weight: 0.5);
            for (final o in const [Offset(-0.03, 0), Offset(0.01, -0.01), Offset(0.03, 0.008)]) {
              c.drawCircle(Offset(o.dx, y + s * 0.012 + o.dy), 0.009, fill(const Color(0xFF4A9A3A)));
            }
            c.drawCircle(Offset(-0.01, y + s * 0.02), 0.01, fill(const Color(0xFFC8283A)));
          }
        });
      case HeldItem.moka:
        // La moka del caffè, ottagonale, col manico nero.
        final top = poly(const [Offset(-0.05, -0.27), Offset(0.05, -0.27), Offset(0.07, -0.13), Offset(-0.07, -0.13)]);
        final bottom = poly(const [Offset(-0.07, -0.12), Offset(0.07, -0.12), Offset(0.05, 0.03), Offset(-0.05, 0.03)]);
        final waist = rrect(const Rect.fromLTRB(-0.055, -0.14, 0.055, -0.11), 0.006);
        final lid = Path()
          ..moveTo(-0.05, -0.27)
          ..quadraticBezierTo(0, -0.31, 0.05, -0.27)
          ..close();
        final spout = poly(const [Offset(-0.05, -0.26), Offset(-0.09, -0.28), Offset(-0.06, -0.22)]);
        final handle = Path()
          ..moveTo(0.06, -0.25)
          ..quadraticBezierTo(0.13, -0.24, 0.1, -0.15)
          ..lineTo(0.08, -0.15)
          ..quadraticBezierTo(0.1, -0.22, 0.06, -0.22)
          ..close();
        piece(c, [(handle, const Color(0xFF1E1A1E)), (spout, const Color(0xFFB8C0C8)), (bottom, const Color(0xFFB8C0C8)), (top, const Color(0xFFC8D0D8)), (waist, const Color(0xFF8A929A)), (lid, const Color(0xFFC8D0D8))], d: 0.018);
        if (!_small) {
          c.drawCircle(const Offset(0, -0.32), 0.012, fill(ink));
          for (var j = 0; j < 2; j++) {
            c.drawPath(
              Path()
                ..moveTo(-0.08 - j * 0.02, -0.3)
                ..quadraticBezierTo(-0.06 - j * 0.02, -0.34, -0.09 - j * 0.02, -0.38),
              line(const Color(0x99F2EAE1), _thin * 1.2),
            );
          }
        }
      case HeldItem.fish:
        // Il pesce incartato nel giornale: un messaggio che tutti capiscono.
        final paper = poly(const [Offset(-0.07, 0.06), Offset(0.07, 0.06), Offset(0.05, -0.12), Offset(-0.06, -0.1)]);
        final body = Path()
          ..moveTo(0, -0.1)
          ..quadraticBezierTo(0.07, -0.18, 0.02, -0.3)
          ..quadraticBezierTo(0.0, -0.34, -0.02, -0.3)
          ..quadraticBezierTo(-0.07, -0.18, 0, -0.1)
          ..close();
        final tail = poly(const [Offset(0, -0.31), Offset(0.05, -0.37), Offset(-0.05, -0.37)]);
        piece(c, [(tail, const Color(0xFF7A9AB0)), (body, const Color(0xFF9AB8C8)), (paper, const Color(0xFFE8E0CC))], d: 0.016);
        if (!_small) {
          for (var j = 0; j < 4; j++) {
            c.drawLine(Offset(-0.05, -0.06 + j * 0.03), Offset(0.045, -0.065 + j * 0.03), line(const Color(0x885A5048), _thin));
          }
          c.drawPath(Path()..addArc(Rect.fromCenter(center: const Offset(0, -0.2), width: 0.06, height: 0.04), 0.2, 2.7), line(const Color(0xFF5A7A90), _thin * 0.8));
        }
        c.drawCircle(const Offset(-0.012, -0.14), 0.01, fill(white));
        c.drawCircle(const Offset(-0.012, -0.14), 0.005, fill(ink));
      case HeldItem.none || HeldItem.cat || HeldItem.teddy:
        break;
    }
  }

  /// Una cosa tenuta con tutte e due le mani davanti al petto.
  static void heldBoth(Canvas c, HeldItem item, _DGeo g, {required Color sleeve, required Color skin}) {
    final o = Offset(g.cx, 0.86);
    for (final s in [-1.0, 1.0]) {
      final elbow = Offset(o.dx + s * 0.34, 1.12);
      final wrist = Offset(o.dx + s * 0.17, 0.93);
      c.drawLine(elbow, wrist, line(ink, 0.12 + _ow * 2));
      c.drawLine(elbow, wrist, line(sleeve, 0.12));
      c.drawLine(elbow + Offset(s * 0.03, 0), wrist + Offset(s * 0.025, 0), line(dark(sleeve), 0.05));
    }
    switch (item) {
      case HeldItem.cat:
        // Il gatto del padrino, nero, col fiocco rosso.
        const fur = Color(0xFF2E2A34);
        final tail = Path()
          ..moveTo(o.dx + 0.12, o.dy + 0.08)
          ..quadraticBezierTo(o.dx + 0.3, o.dy + 0.02, o.dx + 0.24, o.dy - 0.14)
          ..quadraticBezierTo(o.dx + 0.22, o.dy - 0.17, o.dx + 0.21, o.dy - 0.13)
          ..quadraticBezierTo(o.dx + 0.25, o.dy + 0.0, o.dx + 0.1, o.dy + 0.04)
          ..close();
        piece(c, [
          (tail, fur),
          (oval(o + const Offset(0, 0.05), 0.3, 0.2), fur),
          for (final s in [-1.0, 1.0]) (poly([o + Offset(s * 0.09, -0.12), o + Offset(s * 0.085, -0.2), o + Offset(s * 0.03, -0.15)]), fur),
          (oval(o + const Offset(0.0, -0.08), 0.2, 0.17), fur),
        ], d: 0.03);
        for (final s in [-1.0, 1.0]) {
          final eye = o + Offset(s * 0.045, -0.085);
          c.drawOval(Rect.fromCenter(center: eye, width: 0.045, height: 0.04), fill(const Color(0xFFE8D84A)));
          c.drawOval(Rect.fromCenter(center: eye, width: 0.01, height: 0.035), fill(ink));
          if (!_small) {
            for (var j = -1; j <= 1; j++) {
              c.drawLine(o + Offset(s * 0.04, -0.04 + j * 0.008), o + Offset(s * 0.12, -0.05 + j * 0.02), line(const Color(0xFFB8B0C0), _thin * 0.6));
            }
          }
        }
        c.drawPath(poly([o + const Offset(-0.012, -0.055), o + const Offset(0.012, -0.055), o + const Offset(0, -0.042)]), fill(const Color(0xFFE88A9A)));
        for (final s in [-1.0, 1.0]) {
          c.drawPath(poly([o + const Offset(0, -0.005), o + Offset(s * 0.05, -0.025), o + Offset(s * 0.05, 0.015)]), fill(const Color(0xFFC0272D)));
        }
        c.drawCircle(o + const Offset(0, -0.005), 0.013, fill(const Color(0xFF8E1B2B)));
      case HeldItem.teddy:
        const fur = Color(0xFFA8743E);
        piece(c, [
          (oval(o + const Offset(0, 0.06), 0.24, 0.2), fur),
          for (final s in [-1.0, 1.0]) (oval(o + Offset(s * 0.08, -0.14), 0.07, 0.07), fur),
          (oval(o + const Offset(0, -0.07), 0.19, 0.16), fur),
        ], d: 0.028);
        for (final s in [-1.0, 1.0]) {
          c.drawCircle(o + Offset(s * 0.08, -0.14), 0.018, fill(const Color(0xFFD8A878)));
          c.drawCircle(o + Offset(s * 0.04, -0.085), 0.012, fill(ink));
        }
        c.drawPath(oval(o + const Offset(0, -0.045), 0.08, 0.055), fill(const Color(0xFFE0BC8C)));
        c.drawPath(oval(o + const Offset(0, -0.055), 0.025, 0.018), fill(ink));
        // Il papillon e la toppa cucita: un orsacchiotto da boss.
        for (final s in [-1.0, 1.0]) {
          c.drawPath(poly([o + const Offset(0, 0.01), o + Offset(s * 0.04, -0.005), o + Offset(s * 0.04, 0.025)]), fill(night));
        }
        if (!_small) {
          final patch = rrect(Rect.fromCenter(center: o + const Offset(0.05, 0.08), width: 0.05, height: 0.05), 0.008);
          c.drawPath(patch, fill(const Color(0xFF6A8AA8)));
          c.drawPath(patch, line(ink, _thin * 0.6));
        }
      default:
        break;
    }
    for (final s in [-1.0, 1.0]) {
      piece(c, [(oval(Offset(o.dx + s * 0.15, 0.93), 0.1, 0.09), skin)], d: 0.018);
      if (!_small) {
        for (var j = 0; j < 3; j++) {
          c.drawLine(Offset(o.dx + s * 0.12, 0.905 + j * 0.022), Offset(o.dx + s * 0.1, 0.905 + j * 0.022), line(ink, _thin * 0.8));
        }
      }
    }
  }

  // --- Davanti a tutto --------------------------------------------------------------

  static void frontFx(Canvas c, FrontFx id, _DGeo g) {
    switch (id) {
      case FrontFx.none:
        return;
      case FrontFx.smokeRings:
        final from = Offset(g.cx + g.width * 0.95, 0.58);
        for (var j = 0; j < (_small ? 2 : 3); j++) {
          final o = from + Offset(j * 0.03, -j * 0.1);
          final w = 0.07 + j * 0.035;
          c.drawOval(Rect.fromCenter(center: o, width: w, height: w * 0.5), line(const Color(0x55000000), _thin * (2.2 - j * 0.5) + 0.01));
          c.drawOval(Rect.fromCenter(center: o, width: w, height: w * 0.5), line(const Color(0xCCDCE2E6), _thin * (2.2 - j * 0.5)));
        }
      case FrontFx.petals:
        for (final (x, y, turn) in [(0.12, 0.3, 0.5), (0.86, 0.22, -0.7), (0.82, 0.55, 1.2), (0.16, 0.62, -0.4), (0.3, 0.14, 0.2)]) {
          at(c, Offset(x, y), 1, turn, () {
            final p = Path()
              ..moveTo(0, -0.024)
              ..quadraticBezierTo(0.026, 0, 0, 0.024)
              ..quadraticBezierTo(-0.012, 0, 0, -0.024)
              ..close();
            piece(c, [(p, const Color(0xFFC8283A))], d: 0.006, weight: 0.35);
          });
        }
      case FrontFx.sparkles:
        for (final (x, y, s) in [(0.14, 0.22, 0.032), (0.86, 0.3, 0.026), (0.9, 0.62, 0.018), (0.1, 0.55, 0.022)]) {
          c.drawPath(star(Offset(x, y), s * 1.5, 4, 0.25), fill(const Color(0x44FFE2A0)));
          c.drawPath(star(Offset(x, y), s, 4, 0.25), fill(const Color(0xFFFFF0C0)));
        }
      case FrontFx.bats:
        for (final (x, y, s) in [(0.14, 0.18, 1.1), (0.85, 0.12, 0.9), (0.9, 0.42, 0.7)]) {
          at(c, Offset(x, y), s, 0, () {
            final bat = Path();
            for (final side in [1.0, -1.0]) {
              bat
                ..moveTo(0, -0.008)
                ..quadraticBezierTo(side * 0.03, -0.03, side * 0.06, -0.01)
                ..quadraticBezierTo(side * 0.045, 0.0, side * 0.04, 0.012)
                ..quadraticBezierTo(side * 0.025, 0.0, side * 0.015, 0.012)
                ..quadraticBezierTo(side * 0.008, 0.0, 0, 0.012)
                ..close();
            }
            c.drawPath(bat, fill(const Color(0xFF0C0614)));
            c.drawPath(bat, line(const Color(0x993FE0D0), _thin * 0.6));
          });
        }
      case FrontFx.yarn:
        final o = Offset(g.cx - g.width * 1.1, 0.9);
        piece(c, [(oval(o, 0.1, 0.1), const Color(0xFFE88A9A))], d: 0.016);
        for (var j = 0; j < 3; j++) {
          c.drawArc(Rect.fromCenter(center: o, width: 0.08 - j * 0.02, height: 0.1), -0.6 + j, 2.2, false, line(const Color(0xFFB85A6A), _thin * 0.7));
        }
        c.drawPath(
          Path()
            ..moveTo(o.dx + 0.04, o.dy - 0.02)
            ..quadraticBezierTo(o.dx + 0.12, o.dy - 0.12, o.dx + 0.2, o.dy - 0.03),
          line(const Color(0xFFE88A9A), _thin * 1.2),
        );
      case FrontFx.banknotes:
        // Le lire che volano: il bottino della serata.
        for (final (x, y, turn) in [(0.12, 0.2, -0.4), (0.87, 0.16, 0.5), (0.86, 0.5, -0.2), (0.13, 0.52, 0.3)]) {
          at(c, Offset(x, y), 1, turn, () {
            final note = rrect(Rect.fromCenter(center: Offset.zero, width: 0.11, height: 0.055), 0.006);
            piece(c, [(note, const Color(0xFF9AC88A))], d: 0.008, weight: 0.4);
            c.drawPath(oval(Offset.zero, 0.03, 0.03), fill(const Color(0xFF5A8A4A)));
            if (!_small) {
              c.drawRect(Rect.fromCenter(center: Offset.zero, width: 0.09, height: 0.038), line(const Color(0xFF5A8A4A), _thin * 0.6));
            }
          });
        }
      case FrontFx.musicNotes:
        // Le note del mandolino sotto la finestra.
        for (final (x, y, s, double) in [(0.12, 0.28, 1.0, false), (0.86, 0.2, 1.1, true), (0.88, 0.56, 0.9, false), (0.15, 0.6, 0.8, true)]) {
          at(c, Offset(x, y), s, -0.15, () {
            final heads = double ? const [Offset(-0.02, 0.02), Offset(0.03, 0.01)] : const [Offset(0, 0.02)];
            for (final hd in heads) {
              c.drawPath(oval(hd, 0.032, 0.024), line(ink, _ow * 1.2));
              c.drawPath(oval(hd, 0.032, 0.024), fill(const Color(0xFFF4E7C0)));
              c.drawLine(hd + const Offset(0.014, 0), hd + const Offset(0.014, -0.07), line(const Color(0xFFF4E7C0), _thin * 1.6));
            }
            if (double) {
              c.drawLine(heads[0] + const Offset(0.014, -0.07), heads[1] + const Offset(0.014, -0.07), line(const Color(0xFFF4E7C0), _thin * 3));
            } else {
              c.drawPath(
                Path()
                  ..moveTo(0.014, -0.05)
                  ..quadraticBezierTo(0.04, -0.03, 0.035, 0),
                line(const Color(0xFFF4E7C0), _thin * 1.6),
              );
            }
          });
        }
      case FrontFx.fireflies:
        // Le lucciole d'estate in campagna.
        for (var j = 0; j < (_small ? 5 : 9); j++) {
          final p = Offset(0.06 + (j * 0.618 % 1) * 0.88, 0.1 + (j * 0.381 % 1) * 0.6);
          if ((p.dx - g.cx).abs() < g.width * 0.6 && p.dy < g.chin) continue;
          c.drawCircle(p, 0.028, fill(const Color(0x33D8FF6A)));
          c.drawCircle(p, 0.012, fill(const Color(0xFFEFFF9A)));
        }
    }
  }
}

/// Dove sta la faccia nel quadrato del ritratto, per i pezzi qui sopra.
@immutable
class _DGeo {
  final double cx;
  final double eyeY;
  final double eyeDx;
  final double nose;
  final double mouth;
  final double chin;
  final double width;

  /// La cima del cranio, e quella di tutto quello che c'è in testa.
  final double top;
  final double crown;

  const _DGeo({
    required this.cx,
    required this.eyeY,
    required this.eyeDx,
    required this.nose,
    required this.mouth,
    required this.chin,
    required this.width,
    required this.top,
    required this.crown,
  });

  factory _DGeo.of(_NParts p, {required double crown}) {
    final b = p.b;
    return _DGeo(cx: b.cx, eyeY: b.eyeY, eyeDx: b.eyeDx, nose: b.noseY, mouth: b.mouthY, chin: b.bottom, width: b.w, top: b.top, crown: crown);
  }

  Offset get leftEye => Offset(cx - eyeDx, eyeY);
  Offset get rightEye => Offset(cx + eyeDx, eyeY);
  Offset get head => Offset(cx, (top + chin) / 2);

  @override
  bool operator ==(Object other) =>
      other is _DGeo && other.cx == cx && other.eyeY == eyeY && other.eyeDx == eyeDx && other.mouth == mouth && other.chin == chin && other.width == width && other.top == top && other.crown == crown;

  @override
  int get hashCode => Object.hash(cx, eyeY, eyeDx, nose, mouth, chin, width, top, crown);
}
