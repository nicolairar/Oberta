import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Il passaggio tra giorno e notte, in piccolo, in cima alla pagina che lo
/// annuncia: il sole tramonta dietro la città, il cielo si fa blu, sale la
/// luna, si accendono le finestre e la città chiude gli occhi. All'alba lo
/// stesso film al contrario, e l'occhio si riapre.
class PhaseShift extends StatefulWidget {
  /// Vero quando cala la notte, falso quando si fa giorno.
  final bool toNight;
  final String label;

  const PhaseShift({super.key, required this.toNight, required this.label});

  @override
  State<PhaseShift> createState() => _PhaseShiftState();
}

class _PhaseShiftState extends State<PhaseShift> with SingleTickerProviderStateMixin {
  late final AnimationController _film = AnimationController(vsync: this, duration: const Duration(milliseconds: 4200));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _film.value = 1;
    } else if (!_film.isAnimating && _film.value == 0) {
      _film.forward();
    }
  }

  @override
  void dispose() {
    _film.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 150,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.45)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: AnimatedBuilder(
              animation: _film,
              builder: (context, _) => CustomPaint(
                size: Size.infinite,
                painter: PhaseShiftPainter(t: _film.value, toNight: widget.toNight),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(widget.label.toUpperCase(), style: AppText.overline.copyWith(color: AppColors.gold)),
      ],
    );
  }
}

class PhaseShiftPainter extends CustomPainter {
  final double t;
  final bool toNight;

  PhaseShiftPainter({required this.t, required this.toNight});

  static const _daySky = [Color(0xFF3B78BE), Color(0xFF9FC6E8)];
  static const _duskSky = [Color(0xFF3A1E3E), Color(0xFFE07A3E)];
  static const _nightSky = [Color(0xFF04060C), Color(0xFF1A2440)];
  static const _ink = Color(0xFF0A0A0E);
  static const _lit = Color(0xFFFFD27A);

  static double _span(double t, double from, double to) => ((t - from) / (to - from)).clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // Quanto è notte, da 0 a 1: all'alba il film va al contrario.
    final dusk = Curves.easeInOut.transform(_span(t, 0.0, 0.62));
    final night = toNight ? dusk : 1 - dusk;
    final rect = Offset.zero & size;

    List<Color> sky(double n) => n < 0.5
        ? [Color.lerp(_daySky[0], _duskSky[0], n * 2)!, Color.lerp(_daySky[1], _duskSky[1], n * 2)!]
        : [Color.lerp(_duskSky[0], _nightSky[0], n * 2 - 1)!, Color.lerp(_duskSky[1], _nightSky[1], n * 2 - 1)!];
    final colors = sky(night);
    canvas.drawRect(
      rect,
      Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors).createShader(rect),
    );

    // Le stelle, che si accendono una alla volta.
    final rng = Random(5);
    for (var i = 0; i < 28; i++) {
      final at = Offset(rng.nextDouble() * w, rng.nextDouble() * h * 0.6);
      final on = ((night - 0.55 - rng.nextDouble() * 0.3) / 0.15).clamp(0.0, 1.0);
      if (on > 0) canvas.drawCircle(at, 0.6 + rng.nextDouble(), Paint()..color = Colors.white.withValues(alpha: 0.85 * on));
    }

    final horizon = h * 0.74;
    // Il sole scende (o sale) dietro i palazzi, rosso quando è basso.
    final sunY = h * 0.22 + (horizon + h * 0.18 - h * 0.22) * night;
    final sun = Offset(w * 0.30, sunY);
    final sunColor = Color.lerp(const Color(0xFFFFF4C8), const Color(0xFFFF7A3A), (night * 1.6).clamp(0.0, 1.0))!;
    canvas.drawCircle(sun, h * 0.30, Paint()..color = sunColor.withValues(alpha: 0.25)..maskFilter = MaskFilter.blur(BlurStyle.normal, h * 0.12));
    canvas.drawCircle(sun, h * 0.12, Paint()..color = sunColor);

    // La luna dall'altra parte, al contrario del sole.
    final moonY = horizon + h * 0.2 - (horizon + h * 0.2 - h * 0.20) * Curves.easeOut.transform(((night - 0.25) / 0.75).clamp(0.0, 1.0));
    final moon = Offset(w * 0.74, moonY);
    canvas.drawCircle(moon, h * 0.22, Paint()..color = const Color(0x33E9E4D0)..maskFilter = MaskFilter.blur(BlurStyle.normal, h * 0.08));
    canvas.drawCircle(moon, h * 0.09, Paint()..color = const Color(0xFFE9E4D0));
    canvas.drawCircle(moon + Offset(h * 0.04, -h * 0.02), h * 0.08, Paint()..color = colors[0].withValues(alpha: 0.9));

    // La città, con le finestre che si accendono quando fa buio.
    final city = Random(17);
    var x = -4.0;
    final building = Color.lerp(const Color(0xFF3A3540), _ink, night)!;
    while (x < w) {
      final bw = w * (0.06 + 0.07 * city.nextDouble());
      final bh = h * (0.14 + 0.22 * city.nextDouble());
      final r = Rect.fromLTWH(x, horizon + h * 0.26 - bh, bw, bh + 2);
      canvas.drawRect(r, Paint()..color = building);
      for (var wy = r.top + 5; wy < r.bottom - 6; wy += 8) {
        for (var wx = r.left + 4; wx < r.right - 5; wx += 7) {
          final on = ((night - 0.45 - city.nextDouble() * 0.4) / 0.08).clamp(0.0, 1.0);
          if (on > 0) canvas.drawRect(Rect.fromLTWH(wx, wy, 3, 4), Paint()..color = _lit.withValues(alpha: 0.85 * on));
        }
      }
      x += bw + 1;
    }
    canvas.drawRect(Rect.fromLTRB(0, h - 4, w, h), Paint()..color = _ink);

    _eye(canvas, size);
  }

  /// L'occhio della città: si chiude quando cala la notte, con gli zeta del
  /// sonno; all'alba si riapre.
  void _eye(Canvas canvas, Size size) {
    final appear = _span(t, 0.62, 0.72);
    if (appear <= 0) return;
    final shut = Curves.easeInOut.transform(_span(t, 0.74, 0.92));
    final open = toNight ? 1 - shut : shut;
    final center = Offset(size.width * 0.5, size.height * 0.42);
    final ew = size.width * 0.20;
    final eh = size.height * 0.24;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(0.8 + 0.2 * appear);
    final alpha = appear;
    final almond = Path()
      ..moveTo(-ew / 2, 0)
      ..quadraticBezierTo(0, -eh * open, ew / 2, 0)
      ..quadraticBezierTo(0, eh * open, -ew / 2, 0)
      ..close();
    canvas.drawPath(almond, Paint()..color = Colors.white.withValues(alpha: 0.95 * alpha));
    canvas.save();
    canvas.clipPath(almond);
    canvas.drawCircle(Offset.zero, eh * 0.42, Paint()..color = const Color(0xFF6A4A2A).withValues(alpha: alpha));
    canvas.drawCircle(Offset.zero, eh * 0.2, Paint()..color = _ink.withValues(alpha: alpha));
    canvas.drawCircle(Offset(-eh * 0.1, -eh * 0.1), eh * 0.07, Paint()..color = Colors.white.withValues(alpha: alpha));
    canvas.restore();
    // La palpebra, con le ciglia quando è chiusa.
    final lid = Paint()
      ..color = AppColors.gold.withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(-ew / 2, 0)
        ..quadraticBezierTo(0, -eh * open, ew / 2, 0),
      lid,
    );
    canvas.drawPath(
      Path()
        ..moveTo(-ew / 2, 0)
        ..quadraticBezierTo(0, eh * max(open, 0.25), ew / 2, 0),
      lid,
    );
    if (open < 0.2) {
      for (var i = -2; i <= 2; i++) {
        final base = Offset(i * ew * 0.18, eh * 0.2);
        canvas.drawLine(base, base + Offset(i * 2.0, eh * 0.28), lid);
      }
    }
    canvas.restore();

    if (toNight && shut > 0.5) {
      // Gli zeta che salgono.
      for (var i = 0; i < 3; i++) {
        final life = ((t - 0.86 - i * 0.04) / 0.14).clamp(0.0, 1.0);
        if (life <= 0) continue;
        final tp = TextPainter(
          text: TextSpan(
            text: 'z',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9 * (1 - life * 0.4)),
              fontSize: 12.0 + i * 5,
              fontWeight: FontWeight.w800,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, center + Offset(ew * 0.55 + i * 10, -eh * 0.4 - i * 12 - life * 10));
      }
    }
  }

  @override
  bool shouldRepaint(PhaseShiftPainter old) => old.t != t || old.toNight != toNight;
}
