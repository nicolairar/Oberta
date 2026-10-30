import 'dart:math';

import 'package:flutter/material.dart';

import '../../theme/script_fonts.dart';
import '../../widgets/targa.dart';

// The painters of the polling booth: the oak shelf under the closed curtain,
// the printed sheet, the rubber stamp and its ink pad. All hand-drawn, no art
// assets; the booth bakes everything but the stamp.

const _ink = Color(0xFF1C140E);
const stampRed = Color(0xFFB3121E);

class BallotPaperPainter extends CustomPainter {
  final Color color;
  final Color shade;
  final double radius;
  final bool perforated;

  /// How crooked the sheet lies on the shelf, in radians.
  final double tilt;

  const BallotPaperPainter({required this.color, required this.shade, this.radius = 3, this.perforated = false, this.tilt = 0});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(tilt);
    canvas.translate(-size.width / 2, -size.height / 2);
    final rect = Offset.zero & size;
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    canvas.drawRRect(
      rr.shift(const Offset(3, 8)),
      Paint()
        ..color = const Color(0xAA000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.drawRRect(
      rr,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(color, Colors.white, 0.25)!, color, shade],
          stops: const [0, 0.55, 1],
        ).createShader(rect),
    );
    // The grain of cheap paper.
    final rnd = Random(3);
    final fleck = Paint()..color = const Color(0x147A6040);
    for (var i = 0; i < (size.width * size.height / 260).round(); i++) {
      canvas.drawCircle(
        Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height),
        0.5 + rnd.nextDouble() * 0.7,
        fleck,
      );
    }
    // A fold across the middle, from the pocket of whoever brought it.
    canvas.drawLine(
      Offset(0, size.height * 0.5),
      Offset(size.width, size.height * 0.5),
      Paint()
        ..strokeWidth = 1
        ..color = const Color(0x18000000),
    );
    canvas.drawLine(
      Offset(0, size.height * 0.5 + 1),
      Offset(size.width, size.height * 0.5 + 1),
      Paint()
        ..strokeWidth = 1
        ..color = const Color(0x22FFFFFF),
    );
    if (perforated) {
      // The tear line of the stub.
      final hole = Paint()..color = const Color(0x55000000);
      for (var x = 8.0; x < size.width - 4; x += 7) {
        canvas.drawCircle(Offset(x, size.height - 7), 1.1, hole);
      }
    }
    // Lit from the top left (the lamp), shadowed at the bottom.
    canvas.drawRRect(
      rr,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x14FFF1C0), Color(0x00000000), Color(0x22000000)],
        ).createShader(rect),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(BallotPaperPainter oldDelegate) => false;
}

/// The circle where the stamp goes; on the marked row, the red impression.
class StampSpotPainter extends CustomPainter {
  final bool marked;
  final double k;

  const StampSpotPainter({required this.marked, required this.k});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.height * 0.36;
    if (!marked) {
      final dot = Paint()..color = _ink.withValues(alpha: 0.45);
      for (var a = 0.0; a < 2 * pi; a += pi / 14) {
        canvas.drawCircle(c + Offset(cos(a), sin(a)) * r, 0.9 * k, dot);
      }
      return;
    }
    // The impression: bigger than the circle, a little crooked, inked unevenly.
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(-0.22);
    final big = r * 1.75;
    final rnd = Random(7);
    final ink = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt;
    // Two rings, broken where the rubber didn't take.
    for (final (radius, width) in [(big, 3.2 * k), (big * 0.78, 1.6 * k)]) {
      var a = 0.0;
      while (a < 2 * pi) {
        final len = 0.25 + rnd.nextDouble() * 0.6;
        ink
          ..strokeWidth = width
          ..color = stampRed.withValues(alpha: 0.62 + rnd.nextDouble() * 0.3);
        canvas.drawArc(Rect.fromCircle(center: Offset.zero, radius: radius), a, len, false, ink);
        a += len + 0.04 + rnd.nextDouble() * 0.08;
      }
    }
    // The cross in the middle.
    final cross = Paint()
      ..strokeWidth = 4.6 * k
      ..strokeCap = StrokeCap.square
      ..color = stampRed.withValues(alpha: 0.86);
    final x = big * 0.48;
    canvas.drawLine(Offset(-x, -x), Offset(x, x), cross);
    canvas.drawLine(Offset(x, -x), Offset(-x, x), cross);
    // Specks of ink around the edge.
    for (var i = 0; i < 9; i++) {
      final a = rnd.nextDouble() * 2 * pi;
      final d = big * (1.05 + rnd.nextDouble() * 0.15);
      canvas.drawCircle(
        Offset(cos(a), sin(a)) * d,
        (0.6 + rnd.nextDouble()) * k,
        Paint()..color = stampRed.withValues(alpha: 0.55),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(StampSpotPainter oldDelegate) => false;
}

/// The rubber stamp seen from above: a turned wooden knob on a dark base,
/// red ink on the rubber's edge.
class RubberStampPainter extends CustomPainter {
  final double angle;

  const RubberStampPainter({required this.angle});

  @override
  void paint(Canvas canvas, Size size) {
    final s = min(size.width, size.height);
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(angle);
    canvas.drawCircle(
      Offset(s * 0.06, s * 0.1),
      s * 0.42,
      Paint()
        ..color = const Color(0xAA000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    // The base: a square block, red at the edges where the rubber shows.
    final base = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: s * 0.74, height: s * 0.74),
      Radius.circular(s * 0.07),
    );
    canvas.drawRRect(base.inflate(s * 0.025), Paint()..color = const Color(0xFF8E0E18));
    canvas.drawRRect(
      base,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF8A5A34), Color(0xFF5A3418), Color(0xFF3A200E)],
        ).createShader(base.outerRect),
    );
    // Wood grain on the block.
    for (var i = 0; i < 6; i++) {
      final y = base.top + base.height * (0.12 + i * 0.15);
      canvas.drawLine(
        Offset(base.left + 4, y),
        Offset(base.right - 4, y + 2),
        Paint()
          ..strokeWidth = 1
          ..color = const Color(0x22000000),
      );
    }
    // The knob, turned and polished.
    canvas.drawCircle(
      Offset.zero,
      s * 0.25,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.4),
          colors: [Color(0xFFD9A066), Color(0xFF8A5228), Color(0xFF4A2810)],
          stops: [0, 0.6, 1],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: s * 0.25)),
    );
    canvas.drawCircle(Offset(-s * 0.08, -s * 0.09), s * 0.06, Paint()..color = const Color(0x66FFF1D6));
    canvas.restore();
  }

  @override
  bool shouldRepaint(RubberStampPainter oldDelegate) => false;
}

/// The stamp pad: an open tin with a red felt pad, the lid hinged back.
class StampPadPainter extends CustomPainter {
  /// The words printed on the lid.
  final String label;

  const StampPadPainter({required this.label});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.save();
    canvas.translate(w / 2, h / 2);
    canvas.rotate(-0.12);
    canvas.translate(-w / 2, -h / 2);
    final tin = RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.04, h * 0.42, w * 0.9, h * 0.52), Radius.circular(h * 0.06));
    final lid = RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.04, h * 0.02, w * 0.9, h * 0.38), Radius.circular(h * 0.06));
    for (final r in [tin, lid]) {
      canvas.drawRRect(
        r.shift(const Offset(4, 8)),
        Paint()
          ..color = const Color(0x99000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      canvas.drawRRect(
        r,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6E7A74), Color(0xFF3A4440), Color(0xFF262C2A)],
          ).createShader(r.outerRect),
      );
    }
    // The lid's printed label.
    final plate = RRect.fromRectAndRadius(lid.outerRect.deflate(h * 0.07), Radius.circular(h * 0.03));
    canvas.drawRRect(plate, Paint()..color = const Color(0xFF7E111A));
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontFamily: 'Georgia',
          fontFamilyFallback: serifFallback,
          fontSize: min(h * 0.11, plate.width * 1.15 / max(label.length, 1)),
          fontWeight: FontWeight.w700,
          color: const Color(0xFFFFE7A8),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, plate.center - Offset(tp.width / 2, tp.height / 2));
    // The red felt, inked.
    final pad = RRect.fromRectAndRadius(tin.outerRect.deflate(h * 0.06), Radius.circular(h * 0.03));
    canvas.drawRRect(
      pad,
      Paint()..shader = const RadialGradient(colors: [Color(0xFFC0202C), Color(0xFF7A0A12)]).createShader(pad.outerRect),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(StampPadPainter oldDelegate) => oldDelegate.label != label;
}

/// Paints a velvet curtain inside [shape]: a deep base, then for each fold a
/// soft highlight and a dark crease along [line] (fraction 0..1 across, from
/// the top to the bottom of the curtain).
void _velvetFolds(
  Canvas canvas,
  Path shape,
  Rect bounds,
  int folds,
  Offset Function(double f, double t) line, {
  Color base = const Color(0xFF5A0A10),
  Color light = const Color(0xFFB3242E),
  Color dark = const Color(0xFF1C0306),
  double scale = 1,
}) {
  canvas.save();
  canvas.clipPath(shape);
  canvas.drawRect(
    bounds,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color.lerp(base, Colors.black, 0.2)!, base, Color.lerp(base, Colors.black, 0.35)!],
      ).createShader(bounds),
  );
  Path curve(double f) {
    final p = Path();
    for (var i = 0; i <= 24; i++) {
      final o = line(f, i / 24);
      i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
    }
    return p;
  }

  final width = bounds.width / folds;
  for (var i = 0; i < folds; i++) {
    final f = (i + 0.5) / folds;
    canvas.drawPath(
      curve(f),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width * 0.42
        ..color = light.withValues(alpha: 0.55)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, width * 0.22 * scale),
    );
    canvas.drawPath(
      curve(f),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width * 0.1
        ..color = const Color(0x55FFD0C0)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, width * 0.06),
    );
    canvas.drawPath(
      curve(i / folds),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width * 0.3
        ..color = dark.withValues(alpha: 0.75)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, width * 0.14),
    );
  }
  canvas.restore();
}

/// A gold fringe hanging down along [edge] (sampled points), with tassels
/// every few points.
void _fringe(Canvas canvas, List<Offset> edge, double length, {int tasselEvery = 0, double k = 1}) {
  final thread = Paint()
    ..strokeWidth = 1.3 * k
    ..color = const Color(0xFFC9A23E);
  final threadDark = Paint()
    ..strokeWidth = 1.3 * k
    ..color = const Color(0xFF7A5A1C);
  for (var i = 0; i < edge.length; i++) {
    final p = edge[i];
    canvas.drawLine(p, p + Offset(0, length), i.isEven ? thread : threadDark);
  }
  if (tasselEvery <= 0) return;
  for (var i = 0; i < edge.length; i += tasselEvery) {
    final p = edge[i];
    final t = Path()
      ..moveTo(p.dx, p.dy)
      ..quadraticBezierTo(p.dx - 6 * k, p.dy + length * 1.4, p.dx, p.dy + length * 2)
      ..quadraticBezierTo(p.dx + 6 * k, p.dy + length * 1.4, p.dx, p.dy)
      ..close();
    canvas.drawPath(
      t,
      Paint()
        ..shader = const LinearGradient(
          colors: Targa.gold,
          stops: Targa.goldStops,
        ).createShader(Rect.fromLTWH(p.dx - 6 * k, p.dy, 12 * k, length * 2)),
    );
    canvas.drawCircle(p + Offset(0, length * 0.35), 3 * k, Paint()..color = const Color(0xFFFFE7A8));
  }
}

/// Wood with grain, for desks and shelves.
void _wood(
  Canvas canvas,
  Rect rect, {
  required List<Color> colors,
  int seed = 1,
  double density = 1,
  Alignment begin = Alignment.topCenter,
  Alignment end = Alignment.bottomCenter,
}) {
  canvas.drawRect(rect, Paint()..shader = LinearGradient(begin: begin, end: end, colors: colors).createShader(rect));
  final rnd = Random(seed);
  final lines = (rect.height / 7 * density).round();
  canvas.save();
  canvas.clipRect(rect);
  for (var i = 0; i < lines; i++) {
    final y = rect.top + rnd.nextDouble() * rect.height;
    final amp = 1.5 + rnd.nextDouble() * 4;
    final wave = 0.004 + rnd.nextDouble() * 0.01;
    final phase = rnd.nextDouble() * 6;
    final p = Path()..moveTo(rect.left, y);
    for (var x = rect.left; x <= rect.right; x += 8) {
      p.lineTo(x, y + sin(x * wave + phase) * amp);
    }
    canvas.drawPath(
      p,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6 + rnd.nextDouble() * 1.2
        ..color = (rnd.nextInt(4) == 0 ? const Color(0xFFFFD9A0) : Colors.black).withValues(
          alpha: 0.06 + rnd.nextDouble() * 0.08,
        ),
    );
  }
  canvas.restore();
}

class ShelfScenePainter extends CustomPainter {
  final double curtain;
  final bool desk;

  const ShelfScenePainter({required this.curtain, required this.desk});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final k = desk ? 1.6 : 1.0;
    // The shelf, from above: oak planks running across.
    final shelf = Rect.fromLTRB(0, curtain, w, h);
    _wood(canvas, shelf, colors: const [Color(0xFF6B4226), Color(0xFF7A4C2C), Color(0xFF5A361E)], seed: 21, density: 1.6);
    final plank = desk ? 150.0 : 96.0;
    for (var y = curtain + plank; y < h; y += plank) {
      canvas.drawLine(
        Offset(0, y),
        Offset(w, y),
        Paint()
          ..strokeWidth = 2.2 * k
          ..color = const Color(0x55000000),
      );
      canvas.drawLine(
        Offset(0, y + 2 * k),
        Offset(w, y + 2 * k),
        Paint()
          ..strokeWidth = 1 * k
          ..color = const Color(0x22FFD9A0),
      );
    }
    // A pool of light from above.
    final light = Offset(w / 2, curtain + (h - curtain) * 0.42);
    canvas.drawCircle(
      light,
      desk ? 900 : 440,
      Paint()
        ..shader = const RadialGradient(colors: [Color(0x30FFE0A0), Color(0x00FFE0A0)])
            .createShader(Rect.fromCircle(center: light, radius: desk ? 900 : 440)),
    );
    // The curtain at the back, closed, hanging down to the shelf.
    final drape = Path()..addRect(Rect.fromLTWH(0, 0, w, curtain));
    final folds = desk ? 22 : 9;
    _velvetFolds(
      canvas,
      drape,
      Rect.fromLTWH(0, 0, w, curtain),
      folds,
      (f, t) => Offset(f * w + sin(t * pi) * (w / folds) * 0.15, t * curtain),
      base: const Color(0xFF4E0910),
      scale: k,
    );
    // A dark scrim at the top, under the words.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, curtain),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x88000000), Color(0x33000000), Color(0x11000000)],
        ).createShader(Rect.fromLTWH(0, 0, w, curtain)),
    );
    // The hem, with its fringe, falling over the shelf's back edge.
    final hem = Rect.fromLTWH(0, curtain - 12 * k, w, 12 * k);
    canvas.drawRect(
      hem,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF7E111A), Color(0xFF3A060B)],
        ).createShader(hem),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, curtain, w, 10 * k),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x88000000), Color(0x00000000)],
        ).createShader(Rect.fromLTWH(0, curtain, w, 10 * k)),
    );
    _fringe(canvas, [for (var x = 0.0; x < w; x += 3.2 * k) Offset(x, curtain - 1)], 9 * k, k: k);
    // Vignette.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, 0.2),
          radius: 1.05,
          colors: [Color(0x00000000), Color(0x00000000), Color(0xAA000000)],
          stops: [0, 0.55, 1],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(ShelfScenePainter oldDelegate) => false;
}
