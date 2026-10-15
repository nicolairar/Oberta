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
  owl(Duration(milliseconds: 3200)),

  /// I finestrini accesi di un treno lontano.
  train(Duration(milliseconds: 6500)),

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
class SkyEventsPainter extends CustomPainter {
  final List<SkyMoment> moments;

  SkyEventsPainter(this.moments);

  static const _ink = Color(0xFF050407);

  @override
  void paint(Canvas canvas, Size size) {
    for (final moment in moments) {
      final rng = Random(moment.seed);
      switch (moment.event) {
        case SkyEvent.car:
          _car(canvas, size, moment.t, rng.nextBool());
        case SkyEvent.siren:
          _siren(canvas, size, moment.t, 0.2 + 0.6 * rng.nextDouble());
        case SkyEvent.cat:
          _cat(canvas, size, moment.t, rng.nextBool());
        case SkyEvent.owl:
          _owl(canvas, size, moment.t, Offset(size.width * (0.1 + 0.8 * rng.nextDouble()), size.height * (0.62 + 0.1 * rng.nextDouble())));
        case SkyEvent.train:
          _train(canvas, size, moment.t, rng.nextBool());
        case SkyEvent.fog:
          _fog(canvas, size, moment.t);
        case SkyEvent.window:
          _window(canvas, size, moment.t, Offset(size.width * (0.1 + 0.8 * rng.nextDouble()), size.height * (0.76 + 0.1 * rng.nextDouble())));
        case SkyEvent.rooster:
          _rooster(canvas, size, moment.t, size.width * (0.12 + 0.2 * rng.nextDouble()));
        case SkyEvent.birds:
          _birds(canvas, size, moment.t, rng);
      }
    }
  }

  /// Entra, resta, esce: 0 ai bordi, 1 nel mezzo.
  static double _bell(double t, [double edge = 0.15]) => (min(t, 1 - t) / edge).clamp(0.0, 1.0);

  void _car(Canvas canvas, Size size, double t, bool leftToRight) {
    final x = leftToRight ? -0.3 + 1.6 * t : 1.3 - 1.6 * t;
    final lamp = Offset(size.width * x, size.height * 0.965);
    final dir = leftToRight ? 1.0 : -1.0;
    final beam = Path()
      ..moveTo(lamp.dx, lamp.dy - 3)
      ..lineTo(lamp.dx + dir * size.width * 0.55, lamp.dy - size.height * 0.05)
      ..lineTo(lamp.dx + dir * size.width * 0.55, lamp.dy + size.height * 0.03)
      ..close();
    canvas.drawPath(
      beam,
      Paint()
        ..shader = LinearGradient(
          begin: leftToRight ? Alignment.centerLeft : Alignment.centerRight,
          end: leftToRight ? Alignment.centerRight : Alignment.centerLeft,
          colors: const [Color(0x66FFE7A8), Color(0x00FFE7A8)],
        ).createShader(beam.getBounds()),
    );
    canvas.drawCircle(lamp, 4, Paint()..color = const Color(0xFFFFF3C4));
  }

  void _siren(Canvas canvas, Size size, double t, double x) {
    final fade = _bell(t, 0.2);
    final swing = 0.5 + 0.5 * sin(t * pi * 2 * 6);
    final center = Offset(size.width * x, size.height * 0.78);
    for (final (color, weight) in [(const Color(0xFFE23A4A), swing), (const Color(0xFF3B6BFF), 1 - swing)]) {
      canvas.drawCircle(
        center,
        size.width * 0.28,
        Paint()
          ..color = color.withValues(alpha: 0.22 * fade * weight)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.12),
      );
    }
  }

  void _cat(Canvas canvas, Size size, double t, bool leftToRight) {
    final s = size.width * 0.07;
    final x = leftToRight ? -0.1 + 1.2 * t : 1.1 - 1.2 * t;
    final base = Offset(size.width * x, size.height - 2);
    canvas.save();
    canvas.translate(base.dx, base.dy);
    if (!leftToRight) canvas.scale(-1, 1);
    final ink = Paint()..color = _ink;
    final step = t * 60;
    final legs = Paint()
      ..color = _ink
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
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.12
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(head.translate(s * 0.08, -s * 0.02), s * 0.045, Paint()..color = const Color(0xFFE8D24A));
    canvas.restore();
  }

  void _owl(Canvas canvas, Size size, double t, Offset at) {
    final open = _bell(t, 0.2);
    // Un battito di ciglia a metà.
    final blink = (t > 0.48 && t < 0.56) ? 0.1 : 1.0;
    final eye = Paint()..color = const Color(0xFFFFD54A).withValues(alpha: open);
    final r = size.width * 0.012;
    for (final dx in [-1.5, 1.5]) {
      canvas.drawOval(Rect.fromCenter(center: at.translate(dx * r * 1.6, 0), width: r * 2, height: r * 2 * blink * open), eye);
    }
  }

  void _train(Canvas canvas, Size size, double t, bool leftToRight) {
    final fade = _bell(t, 0.12);
    final x = leftToRight ? -0.6 + 2.0 * t : 1.6 - 2.0 * t;
    final y = size.height * 0.805;
    final paint = Paint()..color = const Color(0xFFFFD27A).withValues(alpha: 0.85 * fade);
    final car = size.width * 0.035;
    for (var i = 0; i < 14; i++) {
      final left = size.width * x + (leftToRight ? -i : i) * car * 1.25;
      canvas.drawRect(Rect.fromLTWH(left, y, car, car * 0.45), paint);
    }
    canvas.drawCircle(
      Offset(size.width * x + (leftToRight ? car * 1.4 : -car * 0.4), y + car * 0.2),
      car * 0.9,
      Paint()
        ..color = const Color(0xFFFFF3C4).withValues(alpha: 0.35 * fade)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, car),
    );
  }

  void _fog(Canvas canvas, Size size, double t) {
    final fade = _bell(t, 0.3);
    final rect = Rect.fromLTRB(0, size.height * 0.68, size.width, size.height);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [const Color(0x00B8C0CC), const Color(0xFFB8C0CC).withValues(alpha: 0.28 * fade), const Color(0x00B8C0CC)],
        ).createShader(rect),
    );
  }

  void _window(Canvas canvas, Size size, double t, Offset at) {
    final lit = t < 0.08 ? 0.0 : (t > 0.85 ? 0.0 : 1.0);
    if (lit == 0) return;
    final w = size.width * 0.022;
    canvas.drawRect(Rect.fromCenter(center: at, width: w, height: w * 1.3), Paint()..color = const Color(0xFFFFD27A));
    canvas.drawCircle(
      at,
      w * 2,
      Paint()
        ..color = const Color(0x55FFD27A)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 1.5),
    );
  }

  void _rooster(Canvas canvas, Size size, double t, double x) {
    final rise = Curves.easeOut.transform((t / 0.2).clamp(0.0, 1.0)) * (1 - Curves.easeIn.transform(((t - 0.85) / 0.15).clamp(0.0, 1.0)));
    if (rise <= 0) return;
    final s = size.width * 0.06;
    final base = Offset(x, size.height * 0.80 + (1 - rise) * s * 2);
    final crow = (t > 0.3 && t < 0.75) ? 1.0 : 0.0;
    canvas.save();
    canvas.translate(base.dx, base.dy);
    final ink = Paint()..color = _ink;
    canvas.drawOval(Rect.fromCenter(center: Offset(0, -s * 0.5), width: s * 0.9, height: s * 0.7), ink);
    final neck = Offset(s * 0.3, -s * (0.95 + 0.15 * crow));
    canvas.drawLine(Offset(s * 0.15, -s * 0.6), neck, ink..strokeWidth = s * 0.22..strokeCap = StrokeCap.round);
    canvas.drawCircle(neck, s * 0.17, Paint()..color = _ink);
    // Cresta rossa e becco aperto quando canta.
    canvas.drawCircle(neck.translate(-s * 0.02, -s * 0.18), s * 0.09, Paint()..color = const Color(0xFFC2222D));
    canvas.drawPath(
      Path()
        ..moveTo(neck.dx + s * 0.14, neck.dy - s * 0.02)
        ..lineTo(neck.dx + s * 0.32, neck.dy - s * 0.04 - s * 0.08 * crow)
        ..lineTo(neck.dx + s * 0.14, neck.dy + s * 0.05)
        ..close(),
      Paint()..color = const Color(0xFFE8B93E),
    );
    // La coda a ventaglio.
    for (var i = 0; i < 3; i++) {
      canvas.drawLine(
        Offset(-s * 0.35, -s * 0.55),
        Offset(-s * (0.7 + 0.08 * i), -s * (0.95 - 0.2 * i)),
        Paint()
          ..color = _ink
          ..strokeWidth = s * 0.12
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.restore();
  }

  void _birds(Canvas canvas, Size size, double t, Random rng) {
    final leftToRight = rng.nextBool();
    final y0 = size.height * (0.2 + 0.25 * rng.nextDouble());
    final paint = Paint()
      ..color = _ink.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 7; i++) {
      final lag = i * 0.03;
      final x = leftToRight ? -0.2 + 1.4 * (t - lag) : 1.2 - 1.4 * (t - lag);
      final center = Offset(size.width * x, y0 + (i.isEven ? -1 : 1) * i * size.height * 0.012 + sin(t * 9 + i) * 4);
      final flap = 4 + 4 * sin(t * 40 + i);
      final span = size.width * 0.025;
      canvas.drawPath(
        Path()
          ..moveTo(center.dx - span, center.dy - flap * 0.5)
          ..quadraticBezierTo(center.dx - span * 0.4, center.dy - flap, center.dx, center.dy)
          ..quadraticBezierTo(center.dx + span * 0.4, center.dy - flap, center.dx + span, center.dy - flap * 0.5),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(SkyEventsPainter old) => true;
}
