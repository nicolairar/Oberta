import 'dart:math';

import 'package:flutter/material.dart';

/// L'ora del giorno che il fondale mette in scena.
enum SceneMood { night, dawn, day, dusk }

/// Il profilo della città: grattacieli, tetti bassi con cupola e palme,
/// un vulcano che fuma, o insegne al neon nel deserto.
enum SkylineStyle { metropolis, mediterranean, volcano, desert }

/// Fondale animato dietro alle schermate: cielo, luna o sole, profilo della
/// città a sagome nere, finestre accese, nebbia e pioggia. Quando cambia
/// [mood] il cielo sfuma da un'ora all'altra, con la luna che tramonta e il
/// sole che sorge dietro i palazzi.
///
/// Chi ha chiesto al sistema di ridurre le animazioni vede il fondale fermo.
class CityBackdrop extends StatefulWidget {
  final SceneMood mood;
  final SkylineStyle style;
  final bool rain;
  final Widget child;

  const CityBackdrop({
    super.key,
    required this.child,
    this.mood = SceneMood.night,
    this.style = SkylineStyle.metropolis,
    this.rain = false,
  });

  @override
  State<CityBackdrop> createState() => _CityBackdropState();
}

class _CityBackdropState extends State<CityBackdrop> with TickerProviderStateMixin {
  late final AnimationController _ambient;
  late final AnimationController _shift;
  late _Sky _from;
  late _Sky _to;
  bool _animate = true;

  _Sky get _target => _Sky.of(widget.mood).withRain(widget.rain ? 1 : 0);

  _Sky get _current => _Sky.lerp(_from, _to, Curves.easeInOut.transform(_shift.value));

  @override
  void initState() {
    super.initState();
    _ambient = AnimationController(vsync: this, duration: const Duration(seconds: 24));
    _shift = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800), value: 1);
    _from = _to = _target;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _animate = !MediaQuery.disableAnimationsOf(context);
    if (!_animate) {
      _ambient.stop();
    } else if (!_ambient.isAnimating) {
      _ambient.repeat();
    }
  }

  @override
  void didUpdateWidget(CityBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mood == widget.mood && oldWidget.rain == widget.rain) return;
    _from = _current;
    _to = _target;
    if (_animate) {
      _shift.forward(from: 0);
    } else {
      _shift.value = 1;
    }
  }

  @override
  void dispose() {
    _ambient.dispose();
    _shift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: Listenable.merge([_ambient, _shift]),
            builder: (context, _) => CustomPaint(
              painter: _BackdropPainter(_current, widget.style, _ambient.value),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

/// Tutto ciò che distingue un'ora dall'altra, in numeri e colori che si
/// possono sfumare: è così che la notte diventa alba senza stacchi.
class _Sky {
  final Color top;
  final Color mid;
  final Color horizon;
  final Color far;
  final Color near;

  /// Da 0 a 1: quanto si vedono le stelle, quante finestre sono accese,
  /// quanta nebbia c'è, quanto va scurito tutto per leggere il testo sopra.
  final double stars;
  final double lights;
  final double fog;
  final double scrim;
  final double rain;

  /// Altezza sull'orizzonte: sotto zero l'astro è tramontato.
  final double moon;
  final double sun;

  const _Sky({
    required this.top,
    required this.mid,
    required this.horizon,
    required this.far,
    required this.near,
    required this.stars,
    required this.lights,
    required this.fog,
    required this.scrim,
    required this.moon,
    required this.sun,
    this.rain = 0,
  });

  static const night = _Sky(
    top: Color(0xFF04060C),
    mid: Color(0xFF0D1626),
    horizon: Color(0xFF3A2F4A),
    far: Color(0xFF1C2742),
    near: Color(0xFF050608),
    stars: 1,
    lights: 0.6,
    fog: 0.8,
    scrim: 0.10,
    moon: 0.78,
    sun: -0.5,
  );

  static const dawn = _Sky(
    top: Color(0xFF18213C),
    mid: Color(0xFF8A4A5E),
    horizon: Color(0xFFF2A65A),
    far: Color(0xFF3A2E45),
    near: Color(0xFF100C13),
    stars: 0.12,
    lights: 0.2,
    fog: 1,
    scrim: 0.24,
    moon: -0.3,
    sun: 0.05,
  );

  static const day = _Sky(
    top: Color(0xFF1E2A3A),
    mid: Color(0xFF47566A),
    horizon: Color(0xFFA9967A),
    far: Color(0xFF3A4654),
    near: Color(0xFF12171D),
    stars: 0,
    lights: 0,
    fog: 0.3,
    scrim: 0.34,
    moon: -0.5,
    sun: 0.62,
  );

  static const dusk = _Sky(
    top: Color(0xFF170F24),
    mid: Color(0xFF6E2A38),
    horizon: Color(0xFFD9703A),
    far: Color(0xFF34202E),
    near: Color(0xFF0C080B),
    stars: 0.2,
    lights: 0.4,
    fog: 0.5,
    scrim: 0.26,
    moon: -0.4,
    sun: 0.02,
  );

  static _Sky of(SceneMood mood) => switch (mood) {
        SceneMood.night => night,
        SceneMood.dawn => dawn,
        SceneMood.day => day,
        SceneMood.dusk => dusk,
      };

  _Sky withRain(double rain) => _Sky(
        top: top,
        mid: mid,
        horizon: horizon,
        far: far,
        near: near,
        stars: stars,
        lights: lights,
        fog: fog,
        scrim: scrim,
        moon: moon,
        sun: sun,
        rain: rain,
      );

  static _Sky lerp(_Sky a, _Sky b, double t) {
    double mix(double x, double y) => x + (y - x) * t;
    return _Sky(
      top: Color.lerp(a.top, b.top, t)!,
      mid: Color.lerp(a.mid, b.mid, t)!,
      horizon: Color.lerp(a.horizon, b.horizon, t)!,
      far: Color.lerp(a.far, b.far, t)!,
      near: Color.lerp(a.near, b.near, t)!,
      stars: mix(a.stars, b.stars),
      lights: mix(a.lights, b.lights),
      fog: mix(a.fog, b.fog),
      scrim: mix(a.scrim, b.scrim),
      moon: mix(a.moon, b.moon),
      sun: mix(a.sun, b.sun),
      rain: mix(a.rain, b.rain),
    );
  }
}

class _BackdropPainter extends CustomPainter {
  final _Sky sky;
  final SkylineStyle style;

  /// Da 0 a 1, in ciclo continuo. Ogni moto la moltiplica per un numero
  /// intero di giri, così quando il ciclo ricomincia non si vede lo scatto.
  final double phase;

  _BackdropPainter(this.sky, this.style, this.phase);

  static const _windowColor = Color(0xFFFFD27A);
  static const _moonColor = Color(0xFFE9E4D0);

  bool get _lowTown => style != SkylineStyle.metropolis;

  double _wave(double turns, double offset) => sin(2 * pi * (phase * turns + offset));

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [sky.top, sky.mid, sky.horizon],
          stops: const [0, 0.55, 0.88],
        ).createShader(rect),
    );

    _stars(canvas, size);
    _moon(canvas, size);
    _sun(canvas, size);
    _landmark(canvas, size);
    _layer(canvas, size, seed: 11, far: true);
    _farDetails(canvas, size);
    _fog(canvas, size);
    _layer(canvas, size, seed: 23, far: false);
    _nearDetails(canvas, size);
    _rain(canvas, size);

    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.25),
          radius: 1.2,
          colors: [
            Colors.black.withValues(alpha: sky.scrim),
            Colors.black.withValues(alpha: min(1, sky.scrim + 0.34)),
          ],
        ).createShader(rect),
    );
  }

  void _stars(Canvas canvas, Size size) {
    if (sky.stars < 0.02) return;
    final rng = Random(7);
    final paint = Paint();
    for (var i = 0; i < 80; i++) {
      final center = Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height * 0.6);
      final radius = 0.5 + rng.nextDouble() * 1.1;
      final twinkle = 0.55 + 0.45 * _wave(3.0 + rng.nextInt(9), rng.nextDouble());
      paint.color = Colors.white.withValues(alpha: sky.stars * twinkle * 0.9);
      canvas.drawCircle(center, radius, paint);
    }
  }

  void _moon(Canvas canvas, Size size) {
    if (sky.moon < -0.25) return;
    final center = Offset(size.width * 0.83, size.height * (0.79 - 0.5 * sky.moon));
    final radius = size.width * 0.07;
    _glow(canvas, center, radius * 3.4, _moonColor.withValues(alpha: 0.30));
    canvas.drawCircle(center, radius, Paint()..color = _moonColor);
    final crater = Paint()..color = Colors.black.withValues(alpha: 0.10);
    canvas.drawCircle(center + Offset(-radius * 0.30, -radius * 0.22), radius * 0.22, crater);
    canvas.drawCircle(center + Offset(radius * 0.34, radius * 0.10), radius * 0.16, crater);
    canvas.drawCircle(center + Offset(-radius * 0.05, radius * 0.46), radius * 0.12, crater);
  }

  void _sun(Canvas canvas, Size size) {
    if (sky.sun < -0.25) return;
    final center = Offset(size.width * 0.30, size.height * (0.74 - 0.5 * sky.sun));
    final radius = size.width * 0.10;
    _glow(canvas, center, radius * 5.5, const Color(0xFFFFC37A).withValues(alpha: 0.45));
    canvas.drawCircle(center, radius, Paint()..color = const Color(0xFFFFE2A8));
  }

  void _glow(Canvas canvas, Offset center, double radius, Color color) {
    final bounds = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()..shader = RadialGradient(colors: [color, color.withValues(alpha: 0)]).createShader(bounds),
    );
  }

  /// La sagoma lontana che fa riconoscere il posto: un promontorio, un
  /// vulcano, gli altipiani del deserto.
  void _landmark(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()..color = Color.lerp(sky.far, sky.horizon, 0.42)!;
    final base = h * 0.86;
    final path = Path();

    switch (style) {
      case SkylineStyle.metropolis:
        return;
      case SkylineStyle.mediterranean:
        path
          ..moveTo(w * 0.40, base)
          ..quadraticBezierTo(w * 0.52, h * 0.66, w * 0.64, h * 0.63)
          ..lineTo(w * 0.88, h * 0.61)
          ..quadraticBezierTo(w * 0.96, h * 0.63, w * 1.02, h * 0.74)
          ..lineTo(w * 1.02, base)
          ..close();
      case SkylineStyle.volcano:
        path
          ..moveTo(w * 0.10, base)
          ..quadraticBezierTo(w * 0.36, h * 0.74, w * 0.48, h * 0.615)
          ..quadraticBezierTo(w * 0.53, h * 0.655, w * 0.58, h * 0.635)
          ..quadraticBezierTo(w * 0.72, h * 0.74, w * 1.0, base)
          ..close();
        _smoke(canvas, Offset(w * 0.485, h * 0.61), w);
      case SkylineStyle.desert:
        path
          ..moveTo(w * 0.02, base)
          ..lineTo(w * 0.08, h * 0.71)
          ..lineTo(w * 0.36, h * 0.70)
          ..lineTo(w * 0.44, base)
          ..moveTo(w * 0.52, base)
          ..lineTo(w * 0.60, h * 0.67)
          ..lineTo(w * 0.80, h * 0.665)
          ..lineTo(w * 0.86, h * 0.72)
          ..lineTo(w * 0.98, h * 0.725)
          ..lineTo(w * 1.02, base)
          ..close();
    }
    canvas.drawPath(path, paint);
  }

  void _smoke(Canvas canvas, Offset crater, double width) {
    final paint = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    for (var i = 0; i < 6; i++) {
      final rise = (phase * 3 + i / 6) % 1;
      paint.color = Color.lerp(sky.far, Colors.white, 0.45)!.withValues(alpha: 0.55 * (1 - rise));
      canvas.drawCircle(
        crater + Offset(width * 0.10 * rise + 4 * _wave(2, i / 6), -width * 0.22 * rise),
        width * (0.02 + 0.045 * rise),
        paint,
      );
    }
  }

  /// Una fila di palazzi. Ogni palazzo ha il suo generatore di numeri, così
  /// le finestre restano le stesse a ogni fotogramma qualunque cosa si salti.
  void _layer(Canvas canvas, Size size, {required int seed, required bool far}) {
    final w = size.width;
    final h = size.height;
    final rng = Random(seed);
    final fill = Paint()..color = far ? sky.far : sky.near;

    final (minW, maxW) = _lowTown ? (38.0, 72.0) : (far ? (26.0, 50.0) : (34.0, 64.0));
    final (minH, maxH) = _lowTown
        ? (far ? (0.09, 0.15) : (0.045, 0.095))
        : (far ? (0.17, 0.35) : (0.10, 0.25));

    var x = -rng.nextDouble() * 24;
    for (var i = 0; x < w; i++) {
      final width = minW + rng.nextDouble() * (maxW - minW);
      final height = (minH + rng.nextDouble() * (maxH - minH)) * h;
      final building = Rect.fromLTWH(x, h - height, width, height + 2);
      canvas.drawRect(building, fill);
      _roof(canvas, building, rng.nextDouble(), rng.nextDouble(), fill);
      _windows(canvas, building, Random(seed * 997 + i), far);
      x += width - 1;
    }
  }

  void _roof(Canvas canvas, Rect building, double pick, double amount, Paint fill) {
    final top = building.top;
    final cx = building.center.dx;
    if (_lowTown) {
      if (pick < 0.30) {
        canvas.drawRect(Rect.fromLTWH(building.left + 6 + amount * 12, top - 7, 5, 8), fill);
      } else if (pick < 0.55) {
        canvas.drawPath(
          Path()
            ..moveTo(building.left - 2, top + 1)
            ..lineTo(cx, top - 6 - amount * 5)
            ..lineTo(building.right + 2, top + 1)
            ..close(),
          fill,
        );
      }
      return;
    }
    if (pick < 0.22) {
      final tank = Rect.fromLTWH(cx - 6, top - 17, 12, 9);
      canvas.drawRect(tank, fill);
      canvas.drawPath(
        Path()
          ..moveTo(tank.left - 1, tank.top)
          ..lineTo(cx, tank.top - 5)
          ..lineTo(tank.right + 1, tank.top)
          ..close(),
        fill,
      );
      final legs = Paint()
        ..color = fill.color
        ..strokeWidth = 1.5;
      canvas.drawLine(Offset(tank.left + 1, tank.bottom), Offset(tank.left - 1, top), legs);
      canvas.drawLine(Offset(tank.right - 1, tank.bottom), Offset(tank.right + 1, top), legs);
    } else if (pick < 0.42) {
      canvas.drawLine(
        Offset(cx, top),
        Offset(cx, top - 14 - amount * 18),
        Paint()
          ..color = fill.color
          ..strokeWidth = 1.5,
      );
    } else if (pick < 0.58) {
      final step = Rect.fromLTWH(
        building.left + building.width * 0.2,
        top - 10 - amount * 16,
        building.width * 0.6,
        12 + amount * 16,
      );
      canvas.drawRect(step, fill);
    }
  }

  void _windows(Canvas canvas, Rect building, Random rng, bool far) {
    if (sky.lights < 0.02) return;
    final paint = Paint();
    final columns = max(1, ((building.width - 8) / 9).floor());
    final rows = max(1, ((building.height - 10) / 12).floor());
    for (var row = 0; row < rows; row++) {
      for (var column = 0; column < columns; column++) {
        final lit = rng.nextDouble() < (far ? 0.30 : 0.38);
        final restless = rng.nextDouble() < 0.12;
        final turns = 2.0 + rng.nextInt(6);
        final offset = rng.nextDouble();
        if (!lit) continue;
        final flicker = restless ? 0.5 + 0.5 * _wave(turns, offset) : 1.0;
        paint.color = _windowColor.withValues(alpha: sky.lights * flicker * (far ? 0.55 : 0.9));
        canvas.drawRect(
          Rect.fromLTWH(building.left + 5 + column * 9, building.top + 7 + row * 12, 3.2, 4.6),
          paint,
        );
      }
    }
  }

  void _farDetails(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final fill = Paint()..color = sky.far;
    switch (style) {
      case SkylineStyle.metropolis:
        // La torre a gradoni con la guglia, come nei film.
        for (final (inset, top) in [(0.0, 0.50), (0.016, 0.455), (0.034, 0.425)]) {
          canvas.drawRect(
            Rect.fromLTRB(w * (0.63 + inset), h * top, w * (0.74 - inset), h),
            fill,
          );
        }
        canvas.drawLine(
          Offset(w * 0.685, h * 0.425),
          Offset(w * 0.685, h * 0.365),
          Paint()
            ..color = sky.far
            ..strokeWidth = 2,
        );
      case SkylineStyle.mediterranean:
        _dome(canvas, Offset(w * 0.30, h * 0.845), w * 0.065, fill);
        _bellTower(canvas, Rect.fromLTRB(w * 0.43, h * 0.74, w * 0.475, h), fill);
      case SkylineStyle.volcano:
        _dome(canvas, Offset(w * 0.20, h * 0.855), w * 0.05, fill);
      case SkylineStyle.desert:
        break;
    }
  }

  void _dome(Canvas canvas, Offset base, double radius, Paint fill) {
    canvas.drawRect(
      Rect.fromLTRB(base.dx - radius * 1.1, base.dy - radius * 0.2, base.dx + radius * 1.1, base.dy + radius * 3),
      fill,
    );
    canvas.drawArc(
      Rect.fromCircle(center: base.translate(0, -radius * 0.2), radius: radius),
      pi,
      pi,
      true,
      fill,
    );
    canvas.drawRect(
      Rect.fromCenter(center: base.translate(0, -radius * 1.3), width: radius * 0.3, height: radius * 0.4),
      fill,
    );
    canvas.drawCircle(base.translate(0, -radius * 1.6), radius * 0.13, fill);
  }

  void _bellTower(Canvas canvas, Rect tower, Paint fill) {
    canvas.drawRect(tower, fill);
    canvas.drawPath(
      Path()
        ..moveTo(tower.left - 2, tower.top)
        ..lineTo(tower.center.dx, tower.top - tower.width * 0.9)
        ..lineTo(tower.right + 2, tower.top)
        ..close(),
      fill,
    );
  }

  void _nearDetails(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    switch (style) {
      case SkylineStyle.metropolis:
        break;
      case SkylineStyle.mediterranean:
        _palm(canvas, Offset(w * 0.11, h), h * 0.17, 9);
        _palm(canvas, Offset(w * 0.90, h), h * 0.14, -7);
        _palm(canvas, Offset(w * 0.80, h), h * 0.19, 5);
      case SkylineStyle.volcano:
        _pine(canvas, Offset(w * 0.85, h), h * 0.19);
        _pine(canvas, Offset(w * 0.08, h), h * 0.15);
      case SkylineStyle.desert:
        _palm(canvas, Offset(w * 0.13, h), h * 0.16, 8);
        _palm(canvas, Offset(w * 0.93, h), h * 0.18, -6);
        _neon(canvas, Offset(w * 0.33, h * 0.905), const Color(0xFFFF3B5C), 0);
        _neon(canvas, Offset(w * 0.56, h * 0.89), const Color(0xFFFFC23B), 1);
        _neon(canvas, Offset(w * 0.74, h * 0.91), const Color(0xFF3BE0FF), 2);
    }
  }

  void _palm(Canvas canvas, Offset foot, double height, double lean) {
    final stroke = Paint()
      ..color = sky.near
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.4;
    final sway = 2.5 * _wave(2, foot.dx / 400);
    final top = foot + Offset(lean + sway, -height);
    canvas.drawPath(
      Path()
        ..moveTo(foot.dx, foot.dy)
        ..quadraticBezierTo(foot.dx + lean * 0.2, foot.dy - height * 0.6, top.dx, top.dy),
      stroke,
    );
    stroke.strokeWidth = 2.6;
    final reach = height * 0.36;
    for (var i = 0; i < 7; i++) {
      final angle = pi + i * pi / 6;
      final tip = top + Offset(cos(angle) * reach, sin(angle) * reach * 0.45 + reach * 0.42);
      final bend = top + Offset(cos(angle) * reach * 0.55, sin(angle) * reach * 0.9 - 3);
      canvas.drawPath(
        Path()
          ..moveTo(top.dx, top.dy)
          ..quadraticBezierTo(bend.dx, bend.dy, tip.dx + sway, tip.dy),
        stroke,
      );
    }
  }

  void _pine(Canvas canvas, Offset foot, double height) {
    final fill = Paint()..color = sky.near;
    final top = foot.translate(0, -height);
    canvas.drawLine(
      foot,
      top.translate(0, height * 0.12),
      Paint()
        ..color = sky.near
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawOval(Rect.fromCenter(center: top, width: height * 0.62, height: height * 0.20), fill);
    canvas.drawOval(
      Rect.fromCenter(center: top.translate(-height * 0.16, height * 0.05), width: height * 0.36, height: height * 0.15),
      fill,
    );
    canvas.drawOval(
      Rect.fromCenter(center: top.translate(height * 0.17, height * 0.04), width: height * 0.34, height: height * 0.14),
      fill,
    );
  }

  /// Un'insegna verticale su un palo. Di notte brilla e ogni tanto sfarfalla.
  void _neon(Canvas canvas, Offset foot, Color color, int index) {
    final board = Rect.fromLTWH(foot.dx - 8, foot.dy - 62, 16, 44);
    canvas.drawLine(
      foot,
      foot.translate(0, -20),
      Paint()
        ..color = sky.near
        ..strokeWidth = 2.5,
    );
    canvas.drawRRect(RRect.fromRectAndRadius(board, const Radius.circular(3)), Paint()..color = sky.near);

    final stutter = (phase * 96 + index * 7).floor() % 23 == 0 ? 0.25 : 1.0;
    final glow = sky.lights * stutter * (0.8 + 0.2 * _wave(5, index / 3));
    if (glow < 0.03) return;
    final lit = color.withValues(alpha: min(1, glow * 1.5));
    canvas.drawRRect(
      RRect.fromRectAndRadius(board.inflate(4), const Radius.circular(6)),
      Paint()
        ..color = color.withValues(alpha: min(1, glow * 0.7))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(board.deflate(2), const Radius.circular(2)),
      Paint()
        ..color = lit
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
    for (var i = 0; i < 4; i++) {
      canvas.drawCircle(Offset(board.center.dx, board.top + 8 + i * 9.5), 2.2, Paint()..color = lit);
    }
  }

  void _fog(Canvas canvas, Size size) {
    if (sky.fog < 0.02) return;
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: sky.fog * 0.07)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28);
    for (final (height, offset) in [(0.74, 0.0), (0.84, 0.4)]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(size.width * (0.5 + 0.10 * _wave(1, offset)), size.height * height),
          width: size.width * 1.5,
          height: size.height * 0.09,
        ),
        paint,
      );
    }
  }

  void _rain(Canvas canvas, Size size) {
    if (sky.rain < 0.02) return;
    final rng = Random(99);
    final paint = Paint()
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: sky.rain * 0.17);
    for (var i = 0; i < 90; i++) {
      final x = rng.nextDouble() * size.width * 1.2;
      final fall = (phase * (28 + rng.nextInt(16)) + rng.nextDouble()) % 1;
      final length = 10 + rng.nextDouble() * 14;
      final top = Offset(x, fall * size.height * 1.2 - size.height * 0.1);
      canvas.drawLine(top, top + Offset(-length * 0.22, length), paint);
    }
  }

  @override
  bool shouldRepaint(_BackdropPainter old) =>
      old.phase != phase || old.sky != sky || old.style != style;
}
