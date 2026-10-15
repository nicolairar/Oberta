import 'dart:math';

import 'package:flutter/material.dart';

/// Le piccole scene della città che accompagnano un rumore: chi sente un
/// gatto lo vede passare, chi sente una sirena vede il bagliore in fondo.
/// Nessun suono senza qualcosa da vedere.
enum SkyEvent {
  /// Due fari che passano in fondo alla strada.
  car(Duration(milliseconds: 3200)),

  /// Il bagliore rosso e blu di una volante, all'orizzonte.
  siren(Duration(milliseconds: 5000)),

  /// Un gatto nero che attraversa, con gli occhi che brillano.
  cat(Duration(milliseconds: 4200)),

  /// Due occhi gialli nel buio che si aprono, sbattono, si chiudono.
  owl(Duration(milliseconds: 4200)),

  /// I finestrini accesi di un treno lontano.
  train(Duration(milliseconds: 9000)),

  /// La nebbia che sale dal porto.
  fog(Duration(milliseconds: 5500)),

  /// Una finestra che si accende (il cane ha svegliato qualcuno) e si spegne.
  window(Duration(milliseconds: 3600)),

  /// Il gallo sul tetto, che alza la testa e canta.
  rooster(Duration(milliseconds: 3000)),

  /// Uno stormo che passa nel cielo.
  birds(Duration(milliseconds: 5200));

  final Duration length;

  const SkyEvent(this.length);
}

/// Una scenetta in corso: quale, a che punto (da 0 a 1), e un seme per
/// variare posizione e direzione da una volta all'altra.
typedef SkyMoment = ({SkyEvent event, double t, int seed});

/// Disegna le scenette sopra il fondale e sotto i contenuti.
///
/// Ogni scenetta ha un corpo vero (la macchina, il treno, il gatto), che si
/// vede di giorno contro il cielo e di notte contro i palazzi; fari e
/// finestrini si accendono solo quando è buio ([dark]).
class SkyEventsPainter extends CustomPainter {
  final List<SkyMoment> moments;

  /// Da 0 (pieno giorno) a 1 (notte fonda).
  final double dark;

  SkyEventsPainter(this.moments, {this.dark = 1});

  static const _ink = Color(0xFF0B0A0E);
  static const _lamp = Color(0xFFFFE7A8);
  static const _lit = Color(0xFFFFD27A);

  @override
  void paint(Canvas canvas, Size size) {
    for (final moment in moments) {
      final rng = Random(moment.seed);
      switch (moment.event) {
        case SkyEvent.car:
          _car(canvas, size, moment.t, rng.nextBool(), rng.nextInt(3));
        case SkyEvent.siren:
          _siren(canvas, size, moment.t, rng.nextBool());
        case SkyEvent.cat:
          _cat(canvas, size, moment.t, rng.nextBool());
        case SkyEvent.owl:
          _owl(canvas, size, moment.t, size.width * (0.15 + 0.7 * rng.nextDouble()));
        case SkyEvent.train:
          _train(canvas, size, moment.t, rng.nextBool());
        case SkyEvent.fog:
          _fog(canvas, size, moment.t);
        case SkyEvent.window:
          _window(canvas, size, moment.t, Offset(size.width * (0.15 + 0.7 * rng.nextDouble()), size.height * (0.80 + 0.06 * rng.nextDouble())));
        case SkyEvent.rooster:
          _rooster(canvas, size, moment.t, size.width * (0.14 + 0.2 * rng.nextDouble()));
        case SkyEvent.birds:
          _birds(canvas, size, moment.t, rng);
      }
    }
  }

  /// Entra, resta, esce: 0 ai bordi, 1 nel mezzo.
  static double _bell(double t, [double edge = 0.15]) => (min(t, 1 - t) / edge).clamp(0.0, 1.0);

  Paint _fill(Color color) => Paint()..color = color;

  /// Una berlina anni Quaranta: parafanghi tondi, tetto a cupola, cromature.
  void _car(Canvas canvas, Size size, double t, bool leftToRight, int paint) {
    final s = size.width * 0.20;
    final x = leftToRight ? -0.35 + 1.7 * t : 1.35 - 1.7 * t;
    final ground = size.height * 0.985;
    final body = const [Color(0xFF5A1E22), Color(0xFF1F2B3A), Color(0xFF2B2B2B)][paint];
    final shine = Color.lerp(body, Colors.white, 0.35)!;
    final bounce = sin(t * 70) * s * 0.008;
    canvas.save();
    canvas.translate(size.width * x, ground + bounce);
    if (!leftToRight) canvas.scale(-1, 1);

    // I fari prima della macchina, così il fascio le sta dietro.
    if (dark > 0.05) {
      final beam = Path()
        ..moveTo(s * 0.48, -s * 0.20)
        ..lineTo(s * 2.6, -s * 0.42)
        ..lineTo(s * 2.6, s * 0.05)
        ..close();
      canvas.drawPath(
        beam,
        Paint()
          ..shader = LinearGradient(colors: [_lamp.withValues(alpha: 0.45 * dark), _lamp.withValues(alpha: 0)])
              .createShader(beam.getBounds()),
      );
    }
    final shell = Path()
      ..moveTo(-s * 0.52, -s * 0.10)
      ..quadraticBezierTo(-s * 0.55, -s * 0.30, -s * 0.38, -s * 0.30)
      ..quadraticBezierTo(-s * 0.26, -s * 0.52, s * 0.0, -s * 0.52)
      ..quadraticBezierTo(s * 0.20, -s * 0.52, s * 0.26, -s * 0.32)
      ..quadraticBezierTo(s * 0.50, -s * 0.30, s * 0.52, -s * 0.16)
      ..lineTo(s * 0.52, -s * 0.08)
      ..close();
    canvas.drawPath(shell, _fill(body));
    // Il riflesso sul tetto e la cromatura lungo la fiancata.
    canvas.drawPath(
      Path()
        ..moveTo(-s * 0.30, -s * 0.46)
        ..quadraticBezierTo(-s * 0.05, -s * 0.54, s * 0.16, -s * 0.46),
      Paint()
        ..color = shine.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.02
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(Offset(-s * 0.50, -s * 0.17), Offset(s * 0.50, -s * 0.17), Paint()
      ..color = const Color(0xFFD8D8D0).withValues(alpha: 0.75)
      ..strokeWidth = s * 0.014);
    // I finestrini: cielo di giorno, buio (o una luce di cruscotto) di notte.
    final glass = Color.lerp(const Color(0xFF9FC3DE), const Color(0xFF151A22), dark)!;
    for (final rect in [
      Rect.fromLTRB(-s * 0.26, -s * 0.46, -s * 0.02, -s * 0.31),
      Rect.fromLTRB(s * 0.02, -s * 0.46, s * 0.20, -s * 0.31),
    ]) {
      canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(s * 0.03)), _fill(glass));
    }
    // Ruote con il cerchione che gira.
    for (final wx in [-s * 0.32, s * 0.32]) {
      final hub = Offset(wx, -s * 0.06);
      canvas.drawCircle(hub, s * 0.11, _fill(_ink));
      canvas.drawCircle(hub, s * 0.055, _fill(const Color(0xFFBFBFB8)));
      final spin = t * 90;
      canvas.drawLine(hub + Offset(cos(spin), sin(spin)) * s * 0.05, hub - Offset(cos(spin), sin(spin)) * s * 0.05,
          Paint()..color = _ink..strokeWidth = s * 0.012);
    }
    // Faro e fanalino.
    canvas.drawCircle(Offset(s * 0.49, -s * 0.20), s * 0.035, _fill(Color.lerp(const Color(0xFFE8E2C8), const Color(0xFFFFF6CC), dark)!));
    if (dark > 0.05) {
      canvas.drawCircle(Offset(s * 0.49, -s * 0.20), s * 0.09,
          Paint()..color = _lamp.withValues(alpha: 0.5 * dark)..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.06));
    }
    canvas.drawCircle(Offset(-s * 0.51, -s * 0.18), s * 0.022, _fill(const Color(0xFFD4302F)));
    canvas.restore();
  }

  /// La volante che passa in fondo, col lampeggiante che colora i muri.
  void _siren(Canvas canvas, Size size, double t, bool leftToRight) {
    final fade = _bell(t, 0.2);
    final swing = 0.5 + 0.5 * sin(t * pi * 2 * 8);
    final x = leftToRight ? -0.2 + 1.4 * t : 1.2 - 1.4 * t;
    final roof = Offset(size.width * x, size.height * 0.955);
    for (final (color, weight, dx) in [(const Color(0xFFE23A4A), swing, -1.0), (const Color(0xFF3B6BFF), 1 - swing, 1.0)]) {
      canvas.drawCircle(
        roof.translate(dx * size.width * 0.02, 0),
        size.width * 0.32,
        Paint()
          ..color = color.withValues(alpha: (0.18 + 0.2 * dark) * fade * weight)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.13),
      );
    }
    // La sagoma della volante, piccola e lontana.
    final s = size.width * 0.12;
    canvas.save();
    canvas.translate(roof.dx, roof.dy + s * 0.32);
    if (!leftToRight) canvas.scale(-1, 1);
    canvas.drawRRect(RRect.fromLTRBR(-s * 0.5, -s * 0.28, s * 0.5, -s * 0.06, Radius.circular(s * 0.1)), _fill(const Color(0xFF15151A)));
    canvas.drawRRect(RRect.fromLTRBR(-s * 0.25, -s * 0.44, s * 0.22, -s * 0.24, Radius.circular(s * 0.08)), _fill(const Color(0xFF15151A)));
    canvas.drawRect(Rect.fromLTRB(-s * 0.5, -s * 0.2, s * 0.5, -s * 0.13), _fill(const Color(0xFFE8E8E0)));
    canvas.drawCircle(Offset(-s * 0.05, -s * 0.48), s * 0.05, _fill(Color.lerp(const Color(0xFF3B6BFF), const Color(0xFFE23A4A), swing)!));
    for (final wx in [-s * 0.3, s * 0.3]) {
      canvas.drawCircle(Offset(wx, -s * 0.05), s * 0.08, _fill(_ink));
    }
    canvas.restore();
  }

  /// Un gatto nero che attraversa sui tetti bassi, coda alta.
  void _cat(Canvas canvas, Size size, double t, bool leftToRight) {
    final s = size.width * 0.11;
    final x = leftToRight ? -0.1 + 1.2 * t : 1.1 - 1.2 * t;
    final base = Offset(size.width * x, size.height - 3);
    canvas.save();
    canvas.translate(base.dx, base.dy);
    if (!leftToRight) canvas.scale(-1, 1);
    // Di giorno è un gatto nero col pelo lucido; di notte una sagoma.
    final coat = Color.lerp(const Color(0xFF2A2630), _ink, dark)!;
    final ink = _fill(coat);
    final step = t * 60;
    final legs = Paint()
      ..color = coat
      ..strokeWidth = s * 0.12
      ..strokeCap = StrokeCap.round;
    for (final (dx, phase) in [(-0.35, 0.0), (-0.2, pi), (0.25, pi), (0.4, 0.0)]) {
      canvas.drawLine(Offset(s * dx, -s * 0.45), Offset(s * dx + sin(step + phase) * s * 0.15, 0), legs);
    }
    canvas.drawOval(Rect.fromCenter(center: Offset(0, -s * 0.55), width: s * 1.1, height: s * 0.42), ink);
    final head = Offset(s * 0.62, -s * 0.78);
    canvas.drawCircle(head, s * 0.22, ink);
    for (final dx in [-0.1, 0.1]) {
      canvas.drawPath(
        Path()
          ..moveTo(head.dx + s * (dx - 0.09), head.dy - s * 0.12)
          ..lineTo(head.dx + s * dx, head.dy - s * 0.36)
          ..lineTo(head.dx + s * (dx + 0.09), head.dy - s * 0.12)
          ..close(),
        ink,
      );
    }
    canvas.drawPath(
      Path()
        ..moveTo(-s * 0.5, -s * 0.6)
        ..quadraticBezierTo(-s * 0.95, -s * 0.7, -s * 0.85, -s * (1.2 + 0.1 * sin(step * 0.4))),
      Paint()
        ..color = coat
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.12
        ..strokeCap = StrokeCap.round,
    );
    // Il riflesso del pelo sulla schiena, di giorno.
    if (dark < 0.9) {
      canvas.drawArc(Rect.fromCenter(center: Offset(0, -s * 0.58), width: s * 0.9, height: s * 0.3), pi * 1.1, pi * 0.8, false,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.18 * (1 - dark))
            ..style = PaintingStyle.stroke
            ..strokeWidth = s * 0.04);
    }
    final eye = head.translate(s * 0.08, -s * 0.02);
    canvas.drawCircle(eye, s * 0.05, _fill(const Color(0xFFE8D24A)));
    if (dark > 0.3) {
      canvas.drawCircle(eye, s * 0.12, Paint()..color = const Color(0x66E8D24A)..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.06));
    }
    canvas.restore();
  }

  /// Un gufo appollaiato su un comignolo: si gira, sbatte le palpebre.
  void _owl(Canvas canvas, Size size, double t, double x) {
    final open = _bell(t, 0.2);
    final s = size.width * 0.075;
    final base = Offset(x, size.height * 0.885);
    canvas.save();
    canvas.translate(base.dx, base.dy);
    final feathers = Color.lerp(const Color(0xFF5B4632), const Color(0xFF14110F), dark)!;
    // Il comignolo.
    canvas.drawRect(Rect.fromLTRB(-s * 0.35, 0, s * 0.35, s * 0.9), _fill(Color.lerp(const Color(0xFF4A3A36), _ink, dark)!));
    canvas.drawOval(Rect.fromCenter(center: Offset(0, -s * 0.45), width: s * 0.8, height: s * 0.95), _fill(feathers));
    final head = Offset(0, -s * 1.0);
    canvas.drawCircle(head, s * 0.34, _fill(feathers));
    for (final dx in [-1.0, 1.0]) {
      canvas.drawPath(
        Path()
          ..moveTo(dx * s * 0.30, head.dy - s * 0.15)
          ..lineTo(dx * s * 0.34, head.dy - s * 0.48)
          ..lineTo(dx * s * 0.12, head.dy - s * 0.28)
          ..close(),
        _fill(feathers),
      );
    }
    final blink = (t > 0.48 && t < 0.56) ? 0.1 : 1.0;
    final eye = const Color(0xFFFFD54A).withValues(alpha: max(open, 0.4));
    for (final dx in [-1.0, 1.0]) {
      final c = Offset(dx * s * 0.14, head.dy - s * 0.02);
      canvas.drawCircle(c, s * 0.12, _fill(Color.lerp(const Color(0xFFE9DCC0), feathers, 0.2)!));
      canvas.drawOval(Rect.fromCenter(center: c, width: s * 0.18, height: s * 0.18 * blink), _fill(eye));
      canvas.drawCircle(c, s * 0.04 * blink, _fill(_ink));
      if (dark > 0.3) {
        canvas.drawCircle(c, s * 0.2, Paint()..color = const Color(0x55FFD54A)..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.1));
      }
    }
    canvas.drawPath(
      Path()
        ..moveTo(-s * 0.05, head.dy + s * 0.08)
        ..lineTo(s * 0.05, head.dy + s * 0.08)
        ..lineTo(0, head.dy + s * 0.2)
        ..close(),
      _fill(const Color(0xFFD9A441)),
    );
    canvas.restore();
  }

  /// Un treno a vapore su un viadotto lontano: locomotiva, fumo, carrozze.
  void _train(Canvas canvas, Size size, double t, bool leftToRight) {
    final fade = _bell(t, 0.08);
    final s = size.width * 0.075;
    final head = leftToRight ? -0.3 + 2.4 * t : 1.3 - 2.4 * t;
    final rail = size.height * 0.845;
    final dir = leftToRight ? 1.0 : -1.0;
    final steel = Color.lerp(const Color(0xFF2E3A34), const Color(0xFF0F1412), dark)!.withValues(alpha: fade);
    final roofLine = Color.lerp(const Color(0xFF6E7F76), const Color(0xFF26302B), dark)!.withValues(alpha: fade);
    final pane = Color.lerp(const Color(0xFFB9D3E4), _lit, dark)!.withValues(alpha: fade * (0.6 + 0.4 * dark));
    // Il viadotto: un filo con gli archi.
    canvas.drawLine(Offset(0, rail), Offset(size.width, rail), Paint()..color = steel..strokeWidth = s * 0.08);
    canvas.save();
    canvas.translate(size.width * head, rail);
    canvas.scale(dir, 1);
    // La locomotiva.
    canvas.drawRRect(RRect.fromLTRBR(-s * 1.6, -s * 0.62, 0, -s * 0.06, Radius.circular(s * 0.1)), _fill(steel));
    canvas.drawRect(Rect.fromLTRB(-s * 1.6, -s * 0.95, -s * 1.0, -s * 0.5), _fill(steel));
    canvas.drawRect(Rect.fromLTRB(-s * 0.45, -s * 0.95, -s * 0.28, -s * 0.6), _fill(steel));
    canvas.drawCircle(Offset(-s * 0.02, -s * 0.36), s * 0.08, _fill(Color.lerp(const Color(0xFFDCD6C0), const Color(0xFFFFF3C4), dark)!.withValues(alpha: fade)));
    if (dark > 0.05) {
      canvas.drawCircle(Offset(s * 0.1, -s * 0.36), s * 0.35,
          Paint()..color = _lamp.withValues(alpha: 0.4 * dark * fade)..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.25));
    }
    canvas.drawRect(Rect.fromLTRB(-s * 1.5, -s * 0.88, -s * 1.12, -s * 0.66), _fill(pane));
    // Il fumo, che resta indietro.
    for (var i = 0; i < 6; i++) {
      final age = (t * 30 + i / 6) % 1;
      canvas.drawCircle(
        Offset(-s * 0.37 - age * s * 2.2, -s * 1.0 - age * s * 0.9),
        s * (0.14 + 0.32 * age),
        Paint()
          ..color = Color.lerp(const Color(0xFFE6E6E6), const Color(0xFF55585E), dark)!.withValues(alpha: 0.5 * (1 - age) * fade)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.08),
      );
    }
    // Le carrozze, con i finestrini.
    for (var c = 0; c < 5; c++) {
      final right = -s * 1.7 - c * s * 1.75;
      final car = Rect.fromLTRB(right - s * 1.65, -s * 0.70, right, -s * 0.06);
      canvas.drawRRect(RRect.fromRectAndRadius(car, Radius.circular(s * 0.08)), _fill(steel));
      canvas.drawLine(Offset(car.left, car.top), Offset(car.right, car.top), Paint()..color = roofLine..strokeWidth = s * 0.05);
      for (var w = 0; w < 4; w++) {
        final left = car.left + s * 0.14 + w * s * 0.38;
        canvas.drawRect(Rect.fromLTWH(left, car.top + s * 0.14, s * 0.26, s * 0.2), _fill(pane));
      }
    }
    // Le ruote che girano.
    for (var i = 0; i < 18; i++) {
      final wx = -s * 0.25 - i * s * 0.55;
      canvas.drawCircle(Offset(wx, -s * 0.05), s * 0.09, _fill(Color.lerp(const Color(0xFF1A1A1A), _ink, dark)!.withValues(alpha: fade)));
    }
    canvas.restore();
  }

  void _fog(Canvas canvas, Size size, double t) {
    final fade = _bell(t, 0.3);
    final rect = Rect.fromLTRB(0, size.height * 0.62, size.width, size.height);
    final drift = sin(t * pi) * size.width * 0.08;
    for (var i = 0; i < 3; i++) {
      final band = rect.shift(Offset(drift * (i - 1), i * size.height * 0.04));
      canvas.drawRect(
        band,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [const Color(0x00C8CED8), const Color(0xFFC8CED8).withValues(alpha: 0.22 * fade), const Color(0x00C8CED8)],
          ).createShader(band),
      );
    }
  }

  /// Una finestra che si accende: tende, e dietro qualcuno che guarda fuori.
  void _window(Canvas canvas, Size size, double t, Offset at) {
    final lit = t < 0.08 || t > 0.85 ? 0.0 : 1.0;
    final w = size.width * 0.06;
    final frame = Rect.fromCenter(center: at, width: w, height: w * 1.35);
    final day = 1 - dark;
    final light = Color.lerp(const Color(0xFF2A2A30), _lit, lit * (0.4 + 0.6 * dark))!;
    canvas.drawRect(frame.inflate(w * 0.08), _fill(Color.lerp(const Color(0xFF6B5446), _ink, dark)!));
    canvas.drawRect(frame, _fill(light));
    if (lit > 0) {
      // Qualcuno si affaccia.
      final who = Offset(at.dx + w * 0.05, frame.bottom);
      canvas.drawOval(Rect.fromCenter(center: who.translate(0, -w * 0.18), width: w * 0.55, height: w * 0.45), _fill(_ink.withValues(alpha: 0.85)));
      canvas.drawCircle(who.translate(0, -w * 0.55), w * 0.16, _fill(_ink.withValues(alpha: 0.85)));
      if (dark > 0.1) {
        canvas.drawCircle(at, w * 1.6, Paint()..color = _lit.withValues(alpha: 0.3 * dark)..maskFilter = MaskFilter.blur(BlurStyle.normal, w));
      }
    }
    // Le tende ai lati e la croce dell'infisso.
    final curtain = _fill(Color.lerp(const Color(0xFF8E2A2E), const Color(0xFF4A1416), dark * (1 - lit * 0.5))!);
    canvas.drawRect(Rect.fromLTWH(frame.left, frame.top, w * 0.2, frame.height), curtain);
    canvas.drawRect(Rect.fromLTWH(frame.right - w * 0.2, frame.top, w * 0.2, frame.height), curtain);
    final bar = Paint()..color = Color.lerp(const Color(0xFF6B5446), _ink, dark)!..strokeWidth = w * 0.06;
    canvas.drawLine(Offset(at.dx, frame.top), Offset(at.dx, frame.bottom), bar);
    canvas.drawLine(Offset(frame.left, at.dy), Offset(frame.right, at.dy), bar);
    if (day > 0.5 && lit == 0) {
      canvas.drawLine(frame.topLeft.translate(w * 0.3, w * 0.1), frame.topLeft.translate(w * 0.45, w * 0.35),
          Paint()..color = Colors.white.withValues(alpha: 0.3)..strokeWidth = w * 0.05);
    }
  }

  /// Il gallo sul tetto: piume rosse e brune, cresta, coda a ventaglio.
  void _rooster(Canvas canvas, Size size, double t, double x) {
    final rise = Curves.easeOut.transform((t / 0.2).clamp(0.0, 1.0)) * (1 - Curves.easeIn.transform(((t - 0.85) / 0.15).clamp(0.0, 1.0)));
    if (rise <= 0) return;
    final s = size.width * 0.11;
    final base = Offset(x, size.height * 0.86 + (1 - rise) * s * 2);
    final crow = (t > 0.3 && t < 0.75) ? 1.0 : 0.0;
    final body = Color.lerp(const Color(0xFF8A3A1E), _ink, dark * 0.8)!;
    final neckColor = Color.lerp(const Color(0xFFD9822B), _ink, dark * 0.8)!;
    final tail = Color.lerp(const Color(0xFF1F3B2E), _ink, dark * 0.8)!;
    canvas.save();
    canvas.translate(base.dx, base.dy);
    // La coda a ventaglio, verde scuro lucido.
    for (var i = 0; i < 4; i++) {
      canvas.drawPath(
        Path()
          ..moveTo(-s * 0.3, -s * 0.5)
          ..quadraticBezierTo(-s * (0.9 + 0.05 * i), -s * (1.15 - 0.2 * i), -s * (0.55 + 0.1 * i), -s * (0.2 + 0.05 * i)),
        Paint()
          ..color = tail
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.1
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.drawOval(Rect.fromCenter(center: Offset(0, -s * 0.5), width: s * 0.9, height: s * 0.7), _fill(body));
    // Le zampe gialle.
    for (final dx in [-0.1, 0.12]) {
      canvas.drawLine(Offset(s * dx, -s * 0.2), Offset(s * dx, 0), Paint()..color = const Color(0xFFE8B93E)..strokeWidth = s * 0.05);
    }
    final neck = Offset(s * 0.3, -s * (0.95 + 0.15 * crow));
    canvas.drawLine(Offset(s * 0.15, -s * 0.6), neck, Paint()..color = neckColor..strokeWidth = s * 0.24..strokeCap = StrokeCap.round);
    canvas.drawCircle(neck, s * 0.17, _fill(neckColor));
    // Cresta e bargigli rossi, becco aperto quando canta.
    for (final (dx, dy, r) in const [(-0.08, -0.17, 0.07), (0.02, -0.21, 0.08), (0.11, -0.16, 0.06)]) {
      canvas.drawCircle(neck.translate(s * dx, s * dy), s * r, _fill(const Color(0xFFD02A2F)));
    }
    canvas.drawOval(Rect.fromCenter(center: neck.translate(s * 0.12, s * 0.14), width: s * 0.08, height: s * 0.14), _fill(const Color(0xFFD02A2F)));
    canvas.drawCircle(neck.translate(s * 0.06, -s * 0.04), s * 0.03, _fill(_ink));
    canvas.drawPath(
      Path()
        ..moveTo(neck.dx + s * 0.14, neck.dy - s * 0.02)
        ..lineTo(neck.dx + s * 0.34, neck.dy - s * 0.05 - s * 0.08 * crow)
        ..lineTo(neck.dx + s * 0.14, neck.dy + s * 0.05)
        ..close(),
      _fill(const Color(0xFFE8B93E)),
    );
    canvas.restore();
  }

  /// Uno stormo a V che attraversa il cielo, ali che battono.
  void _birds(Canvas canvas, Size size, double t, Random rng) {
    final leftToRight = rng.nextBool();
    final y0 = size.height * (0.16 + 0.22 * rng.nextDouble());
    final paint = Paint()
      ..color = Color.lerp(const Color(0xFF2A2A30), _ink, dark)!.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.006
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 9; i++) {
      final rank = (i + 1) ~/ 2;
      final side = i.isOdd ? -1 : 1;
      final lag = rank * 0.025;
      final x = leftToRight ? -0.2 + 1.4 * (t - lag) : 1.2 - 1.4 * (t - lag);
      final center = Offset(size.width * x, y0 + side * rank * size.height * 0.018 + sin(t * 9 + i) * 3);
      final span = size.width * (0.04 - rank * 0.002);
      final flap = span * (0.25 + 0.35 * sin(t * 45 + i));
      canvas.drawPath(
        Path()
          ..moveTo(center.dx - span, center.dy - flap)
          ..quadraticBezierTo(center.dx - span * 0.4, center.dy - flap * 1.6, center.dx, center.dy)
          ..quadraticBezierTo(center.dx + span * 0.4, center.dy - flap * 1.6, center.dx + span, center.dy - flap),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(SkyEventsPainter old) => true;
}
