import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../avatar/avatar_look.dart';
import '../baked.dart';
import '../../theme/script_fonts.dart';

/// La cornice della bottega intorno a una carta del tavolo (o a un ritratto):
/// [child] sta dentro, la cornice si disegna sopra il suo bordo. Con
/// [SeatBorder.none] resta solo [child].
///
/// Le leggendarie ([SeatBorder.animated]) si muovono, se il telefono non ha
/// chiesto di ridurre il movimento.
class SeatFrame extends StatefulWidget {
  final SeatBorder border;
  final Widget child;

  /// Gli angoli della carta.
  final double radius;

  /// Lo spessore della cornice; senza, una frazione del lato corto.
  final double? thickness;

  /// Quanto la cornice entra nella carta: 0 la disegna tutta fuori.
  final double inset;

  const SeatFrame({
    super.key,
    required this.border,
    required this.child,
    this.radius = 10,
    this.thickness,
    this.inset = 0.5,
  });

  /// La cornice di chi si chiama [name] (quella del suo profilo, se la si è vista).
  factory SeatFrame.of(String name, {Key? key, required Widget child, double radius = 10, double? thickness}) =>
      SeatFrame(key: key, border: AvatarLook.of(name).border, radius: radius, thickness: thickness, child: child);

  /// Lo spessore per una carta di lato corto [side].
  static double thicknessFor(double side) => (side * 0.075).clamp(3.0, 14.0);

  @override
  State<SeatFrame> createState() => _SeatFrameState();
}

class _SeatFrameState extends State<SeatFrame> with SingleTickerProviderStateMixin {
  AnimationController? _clock;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(SeatFrame old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final moving = widget.border.animated && !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    if (moving && _clock == null) {
      _clock = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
    } else if (!moving && _clock != null) {
      _clock!.dispose();
      _clock = null;
    }
  }

  @override
  void dispose() {
    _clock?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.border == SeatBorder.none) return widget.child;
    final painter = SeatFramePainter(
      widget.border,
      radius: widget.radius,
      thickness: widget.thickness,
      inset: widget.inset,
      clock: _clock,
    );
    if (_clock == null) {
      // La cornice ferma (con le sue sfumature) è un'immagine sopra il ritratto.
      final glow = (widget.thickness ?? 14) * 5 + 4;
      return Stack(
        fit: StackFit.passthrough,
        clipBehavior: Clip.none,
        children: [
          widget.child,
          Positioned.fill(
            child: IgnorePointer(
              child: Baked(overflow: EdgeInsets.all(glow), child: CustomPaint(painter: painter)),
            ),
          ),
        ],
      );
    }
    // La cornice che si muove sta su uno strato suo: a ogni fotogramma si
    // ridisegna lei, non il ritratto (e il tavolo) che ha sotto.
    return Stack(
      fit: StackFit.passthrough,
      clipBehavior: Clip.none,
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(child: RepaintBoundary(child: CustomPaint(painter: painter))),
        ),
      ],
    );
  }
}

/// Disegna una cornice intorno al rettangolo della carta. [clock] (da 0 a 1,
/// in giro) muove le leggendarie; senza, stanno ferme a metà.
class SeatFramePainter extends CustomPainter {
  final SeatBorder border;
  final double radius;
  final double? thickness;
  final double inset;
  final Animation<double>? clock;

  SeatFramePainter(this.border, {this.radius = 10, this.thickness, this.inset = 0.5, this.clock})
      : super(repaint: clock);

  double get _t => clock?.value ?? 0.35;

  @override
  void paint(Canvas canvas, Size size) {
    final w = thickness ?? SeatFrame.thicknessFor(size.shortestSide);
    // La linea mediana della cornice.
    final mid = (Offset.zero & size).deflate(w * (inset - 0.5));
    final rr = RRect.fromRectAndRadius(mid, Radius.circular(max(0, radius - w * (inset - 0.5))));
    switch (border) {
      case SeatBorder.none:
        return;
      case SeatBorder.brass:
        _brass(canvas, rr, w);
      case SeatBorder.velvet:
        _velvet(canvas, rr, w);
      case SeatBorder.mosaic:
        _mosaic(canvas, rr, w);
      case SeatBorder.filmStrip:
        _film(canvas, rr, w);
      case SeatBorder.suits:
        _suits(canvas, rr, w);
      case SeatBorder.artDeco:
        _deco(canvas, rr, w);
      case SeatBorder.barbedWire:
        _barbed(canvas, rr, w);
      case SeatBorder.roseThorns:
        _roses(canvas, rr, w);
      case SeatBorder.neonPink:
        _neon(canvas, rr, w, const Color(0xFFFF4FB8), const Color(0xFFFFD6EE), 1);
      case SeatBorder.flame:
        _flame(canvas, rr, w);
      case SeatBorder.neonPulse:
        _pulse(canvas, rr, w);
      case SeatBorder.badge:
        _badge(canvas, rr, w);
      case SeatBorder.noose:
        _noose(canvas, rr, w);
      case SeatBorder.laurel:
        _laurel(canvas, rr, w);
    }
  }

  // ---- utilità ----

  static Paint _stroke(double w, {Color color = Colors.white, Shader? shader}) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..color = color
    ..shader = shader
    ..isAntiAlias = true;

  static Path _ring(RRect rr) => Path()..addRRect(rr);

  static Shader _metal(Rect r, List<Color> colors) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors,
        tileMode: TileMode.mirror,
      ).createShader(r);

  /// I punti a passi regolari lungo la cornice, con la tangente.
  static Iterable<ui.Tangent> _along(RRect rr, double step, {double phase = 0}) sync* {
    for (final metric in _ring(rr).computeMetrics()) {
      final n = max(4, (metric.length / step).round());
      for (var i = 0; i < n; i++) {
        final d = ((i + phase) / n * metric.length) % metric.length;
        final tan = metric.getTangentForOffset(d);
        if (tan != null) yield tan;
      }
    }
  }

  static List<Offset> _corners(RRect rr) {
    final k = rr.tlRadiusX * 0.3;
    return [
      Offset(rr.left + k, rr.top + k),
      Offset(rr.right - k, rr.top + k),
      Offset(rr.right - k, rr.bottom - k),
      Offset(rr.left + k, rr.bottom - k),
    ];
  }

  // ---- le cornici ----

  /// Il distintivo: una fascia blu questura con il filo d'argento e la
  /// stella a sei punte del commissario in cima.
  void _badge(Canvas canvas, RRect rr, double w) {
    final r = rr.outerRect;
    canvas.drawRRect(rr, _stroke(w * 1.05, color: const Color(0xFF14213D)));
    final silver = _metal(r, const [Color(0xFF8C9298), Color(0xFFF4F7FA), Color(0xFFA9B0B8), Color(0xFFFFFFFF), Color(0xFF7E848A)]);
    canvas.drawRRect(rr.inflate(w * 0.5), _stroke(w * 0.14, shader: silver));
    canvas.drawRRect(rr.deflate(w * 0.5), _stroke(w * 0.14, shader: silver));
    for (final tan in _along(rr, w * 2.4, phase: 0.5)) {
      canvas.drawCircle(tan.position, w * 0.12, Paint()..color = const Color(0xFFB9C3D6));
    }
    void star(Offset c, double s) {
      final p = Path();
      for (var i = 0; i < 12; i++) {
        final a = -pi / 2 + i * pi / 6;
        final d = i.isEven ? s : s * 0.55;
        final o = c + Offset(cos(a) * d, sin(a) * d);
        i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
      }
      p.close();
      canvas.drawPath(p.shift(Offset(0, s * 0.08)), Paint()..color = const Color(0x99000000));
      canvas.drawPath(p, Paint()..shader = _metal(Rect.fromCircle(center: c, radius: s), const [Color(0xFF9A7A2A), Color(0xFFFFE7A0), Color(0xFFC79A3A)]));
      canvas.drawCircle(c, s * 0.28, Paint()..color = const Color(0xFF14213D));
    }
    star(Offset(r.center.dx, rr.top), w * 1.5);
    for (final c in _corners(rr).skip(2)) {
      star(c, w * 0.75);
    }
  }

  /// Il cappio: una corda di canapa intrecciata, con il nodo in cima.
  void _noose(Canvas canvas, RRect rr, double w) {
    canvas.drawRRect(rr, _stroke(w * 0.9, color: const Color(0xFF6B5030)));
    final twist = _stroke(w * 0.22, color: const Color(0xFFC9A66B))..strokeCap = StrokeCap.round;
    final dark = _stroke(w * 0.14, color: const Color(0xFF3A2814))..strokeCap = StrokeCap.round;
    for (final tan in _along(rr, w * 0.7)) {
      final n = Offset(-tan.vector.dy, tan.vector.dx) * (w * 0.4);
      final t = tan.vector * (w * 0.22);
      canvas.drawLine(tan.position - n - t, tan.position + n + t, dark);
      canvas.drawLine(tan.position - n * 0.8 - t * 0.6, tan.position + n * 0.8 + t * 0.6, twist);
    }
    // Il nodo: le spire avvolte in cima.
    final c = Offset(rr.outerRect.center.dx, rr.top);
    for (var i = -2; i <= 2; i++) {
      final band = RRect.fromRectAndRadius(
        Rect.fromCenter(center: c + Offset(i * w * 0.55, 0), width: w * 0.5, height: w * 1.9),
        Radius.circular(w * 0.25),
      );
      canvas.drawRRect(band, Paint()..color = const Color(0xFF8A6A3E));
      canvas.drawRRect(band, _stroke(w * 0.08, color: const Color(0xFF3A2814)));
    }
  }

  /// L'alloro d'oro: due rami di foglie che salgono dai lati e si
  /// incontrano in cima, su un filo d'oro.
  void _laurel(Canvas canvas, RRect rr, double w) {
    final r = rr.outerRect;
    final gold = _metal(r, const [Color(0xFF8C6420), Color(0xFFFFE7A0), Color(0xFFC79A3A), Color(0xFFFFF4CF), Color(0xFF8C6420)]);
    canvas.drawRRect(rr, _stroke(w * 0.18, shader: gold));
    final leaf = Paint()..shader = gold;
    final vein = _stroke(w * 0.05, color: const Color(0xFF6A4A14));
    var i = 0;
    for (final tan in _along(rr, w * 0.9)) {
      final side = i.isEven ? 1.0 : -1.0;
      i++;
      final angle = atan2(tan.vector.dy, tan.vector.dx) + side * 0.6;
      canvas.save();
      canvas.translate(tan.position.dx, tan.position.dy);
      canvas.rotate(angle);
      final p = Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(w * 0.45, -w * 0.32 * side, w * 0.95, 0)
        ..quadraticBezierTo(w * 0.45, w * 0.18 * side, 0, 0)
        ..close();
      canvas.drawPath(p, leaf);
      canvas.drawLine(Offset.zero, Offset(w * 0.8, 0), vein);
      canvas.restore();
    }
    // Le bacche agli angoli.
    for (final c in _corners(rr)) {
      canvas.drawCircle(c, w * 0.3, Paint()..color = const Color(0xFFB3141E));
      canvas.drawCircle(c - Offset(w * 0.08, w * 0.08), w * 0.1, Paint()..color = const Color(0x88FFFFFF));
    }
  }

  /// Ottone a filigrana: due fili d'ottone, i riccioli negli angoli, i ribattini.
  void _brass(Canvas canvas, RRect rr, double w) {
    final r = rr.outerRect;
    final gold = _metal(r, const [Color(0xFF7A5418), Color(0xFFF3D27A), Color(0xFFA9792B), Color(0xFFFFE9A8), Color(0xFF7A5418)]);
    canvas.drawRRect(rr, _stroke(w, color: const Color(0xFF2A1A0C)));
    canvas.drawRRect(rr.inflate(w * 0.32), _stroke(w * 0.26, shader: gold));
    canvas.drawRRect(rr.deflate(w * 0.32), _stroke(w * 0.2, shader: gold));
    final curl = _stroke(w * 0.16, shader: gold)..strokeCap = StrokeCap.round;
    final corners = _corners(rr);
    for (var i = 0; i < 4; i++) {
      final c = corners[i];
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(i * pi / 2);
      final s = w * 1.6;
      final p = Path()
        ..moveTo(-s * 0.2, s * 1.4)
        ..cubicTo(-s * 0.2, s * 0.3, -s * 0.1, -s * 0.1, s * 0.3, -s * 0.2)
        ..cubicTo(s * 0.9, -s * 0.3, s * 0.9, s * 0.5, s * 0.4, s * 0.45)
        ..moveTo(s * 1.4, -s * 0.2)
        ..cubicTo(s * 0.3, -s * 0.2, -s * 0.1, -s * 0.1, -s * 0.2, s * 0.3)
        ..cubicTo(-s * 0.3, s * 0.9, s * 0.5, s * 0.9, s * 0.45, s * 0.4);
      canvas.drawPath(p, curl);
      canvas.drawCircle(Offset.zero, w * 0.32, Paint()..shader = gold);
      canvas.restore();
    }
    for (final tan in _along(rr, w * 7, phase: 0.5)) {
      canvas.drawCircle(tan.position, w * 0.17, Paint()..color = const Color(0xFFFFE3A0));
    }
  }

  /// Velluto rosso sangue: una fascia morbida con la passamaneria d'oro.
  void _velvet(Canvas canvas, RRect rr, double w) {
    final r = rr.outerRect;
    canvas.drawRRect(
      rr,
      _stroke(w * 1.15,
          shader: RadialGradient(
            center: const Alignment(-0.3, -0.5),
            radius: 1.2,
            colors: const [Color(0xFFB0182A), Color(0xFF6A0612), Color(0xFF2E0207)],
          ).createShader(r)),
    );
    // La luce sul pelo del velluto.
    canvas.drawRRect(rr.deflate(w * 0.15), _stroke(w * 0.3, color: const Color(0x33FF8A90))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.3));
    final gold = _metal(r, const [Color(0xFF8C6420), Color(0xFFF0CF7A), Color(0xFF8C6420)]);
    canvas.drawRRect(rr.deflate(w * 0.62), _stroke(w * 0.14, shader: gold));
    canvas.drawRRect(rr.inflate(w * 0.62), _stroke(w * 0.14, shader: gold));
    // Le cuciture.
    final stitch = _stroke(w * 0.08, color: const Color(0xAAE9C46A))..strokeCap = StrokeCap.round;
    for (final tan in _along(rr, w * 1.1)) {
      final d = tan.vector * (w * 0.22);
      canvas.drawLine(tan.position - d, tan.position + d, stitch);
    }
  }

  /// Mosaico: tessere alterne d'oro, turchese e terracotta, fughe scure.
  void _mosaic(Canvas canvas, RRect rr, double w) {
    canvas.drawRRect(rr, _stroke(w * 1.1, color: const Color(0xFF1A1512)));
    const tiles = [Color(0xFFD9A93E), Color(0xFF2F8C8A), Color(0xFFB4532E), Color(0xFFE9DFC6), Color(0xFF2F8C8A), Color(0xFFD9A93E)];
    var i = 0;
    for (final tan in _along(rr, w * 0.95)) {
      final side = w * 0.78;
      canvas.save();
      canvas.translate(tan.position.dx, tan.position.dy);
      canvas.rotate(atan2(tan.vector.dy, tan.vector.dx));
      final tile = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: side, height: side), Radius.circular(w * 0.1));
      final c = tiles[(i * 7 + i ~/ 3) % tiles.length];
      canvas.drawRRect(
        tile,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color.lerp(c, Colors.white, 0.25)!, c, Color.lerp(c, Colors.black, 0.3)!],
          ).createShader(tile.outerRect),
      );
      canvas.restore();
      i++;
    }
  }

  /// La pellicola: nastro nero con le perforazioni, la luce del proiettore.
  void _film(Canvas canvas, RRect rr, double w) {
    final band = w * 1.25;
    canvas.drawRRect(rr, _stroke(band, color: const Color(0xFF0E0C0B)));
    canvas.drawRRect(rr.inflate(band / 2), _stroke(w * 0.08, color: const Color(0xFF55504A)));
    canvas.drawRRect(rr.deflate(band / 2), _stroke(w * 0.08, color: const Color(0xFF55504A)));
    final hole = Paint()..color = const Color(0xFFEDE3CC);
    for (final tan in _along(rr, w * 1.15)) {
      canvas.save();
      canvas.translate(tan.position.dx, tan.position.dy);
      canvas.rotate(atan2(tan.vector.dy, tan.vector.dx));
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: w * 0.5, height: w * 0.42), Radius.circular(w * 0.08)),
        hole,
      );
      canvas.restore();
    }
  }

  /// Il tavolo verde: una cornice d'avorio e oro con i quattro semi agli angoli.
  void _suits(Canvas canvas, RRect rr, double w) {
    final r = rr.outerRect;
    canvas.drawRRect(rr, _stroke(w, color: const Color(0xFFF1E8D4)));
    final gold = _metal(r, const [Color(0xFF8C6420), Color(0xFFF0CF7A), Color(0xFF8C6420)]);
    canvas.drawRRect(rr.inflate(w * 0.5), _stroke(w * 0.14, shader: gold));
    canvas.drawRRect(rr.deflate(w * 0.5), _stroke(w * 0.14, shader: gold));
    // Il ricamo a rombi sul bordo.
    for (final tan in _along(rr, w * 2.2, phase: 0.5)) {
      canvas.save();
      canvas.translate(tan.position.dx, tan.position.dy);
      canvas.rotate(atan2(tan.vector.dy, tan.vector.dx));
      final p = Path()
        ..moveTo(-w * 0.3, 0)
        ..lineTo(0, -w * 0.18)
        ..lineTo(w * 0.3, 0)
        ..lineTo(0, w * 0.18)
        ..close();
      canvas.drawPath(p, Paint()..color = const Color(0xFFB9A47A));
      canvas.restore();
    }
    const glyphs = ['♠', '♥', '♣', '♦'];
    final corners = _corners(rr);
    for (var i = 0; i < 4; i++) {
      final red = i.isOdd;
      canvas.drawCircle(corners[i], w * 1.05, Paint()..color = const Color(0xFFF7F0DF));
      canvas.drawCircle(corners[i], w * 1.05, _stroke(w * 0.14, shader: gold));
      final tp = TextPainter(
        text: TextSpan(
          text: glyphs[i],
          style: TextStyle(
            fontSize: w * 1.45,
            height: 1,
            color: red ? const Color(0xFFC0182A) : const Color(0xFF15110E),
            fontFamilyFallback: const ['Apple Symbols', 'Noto Sans Symbols', ...serifFallback],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, corners[i] - Offset(tp.width / 2, tp.height / 2));
      tp.dispose();
    }
  }

  /// Art déco: oro a gradini, linee doppie, il ventaglio in alto.
  void _deco(Canvas canvas, RRect rr, double w) {
    final r = rr.outerRect;
    final gold = _metal(r, const [Color(0xFF6E4C12), Color(0xFFF6DC8C), Color(0xFFB88A2E), Color(0xFFFFF1C2), Color(0xFF8A6119)]);
    canvas.drawRRect(rr, _stroke(w * 1.1, color: const Color(0xFF0E0B08)));
    canvas.drawRRect(rr.inflate(w * 0.42), _stroke(w * 0.22, shader: gold));
    canvas.drawRRect(rr.deflate(w * 0.42), _stroke(w * 0.12, shader: gold));
    canvas.drawRRect(rr, _stroke(w * 0.08, shader: gold));
    final fill = Paint()..shader = gold;
    // I gradini negli angoli.
    final corners = [r.topLeft, r.topRight, r.bottomRight, r.bottomLeft];
    for (var i = 0; i < 4; i++) {
      canvas.save();
      canvas.translate(corners[i].dx, corners[i].dy);
      canvas.rotate(i * pi / 2);
      final s = w * 0.9;
      final p = Path()
        ..moveTo(-w * 0.6, -w * 0.6)
        ..lineTo(s * 3, -w * 0.6)
        ..lineTo(s * 3, 0)
        ..lineTo(s * 2, 0)
        ..lineTo(s * 2, s)
        ..lineTo(s, s)
        ..lineTo(s, s * 2)
        ..lineTo(0, s * 2)
        ..lineTo(0, s * 3)
        ..lineTo(-w * 0.6, s * 3)
        ..close();
      canvas.drawPath(p, fill);
      canvas.drawPath(p, _stroke(w * 0.08, color: const Color(0xFF3A2808)));
      canvas.restore();
    }
    // Il ventaglio sopra e sotto, al centro.
    for (final (y, dir) in [(r.top, 1.0), (r.bottom, -1.0)]) {
      final c = Offset(r.center.dx, y - dir * w * 0.5);
      final rad = w * 2.4;
      canvas.drawArc(Rect.fromCircle(center: c, radius: rad), dir > 0 ? 0 : pi, pi, true, Paint()..color = const Color(0xFF0E0B08));
      for (var k = 0; k <= 6; k++) {
        final a = (dir > 0 ? 0 : pi) + pi * k / 6;
        canvas.drawLine(c, c + Offset(cos(a), sin(a)) * rad, _stroke(w * 0.14, shader: gold));
      }
      canvas.drawArc(Rect.fromCircle(center: c, radius: rad), dir > 0 ? 0 : pi, pi, false, _stroke(w * 0.2, shader: gold));
      canvas.drawCircle(c, w * 0.45, fill);
    }
  }

  /// Filo spinato: due fili attorcigliati e le punte a intervalli.
  void _barbed(Canvas canvas, RRect rr, double w) {
    final steel = _metal(rr.outerRect, const [Color(0xFF4A4C4F), Color(0xFFC9CDD2), Color(0xFF55575B), Color(0xFFE6E9EC)]);
    canvas.drawRRect(rr, _stroke(w * 0.9, color: const Color(0x66000000))..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.4));
    for (final metric in _ring(rr).computeMetrics()) {
      for (final strand in [0.0, pi]) {
        final p = Path();
        final n = (metric.length / 1.5).round();
        for (var i = 0; i <= n; i++) {
          final d = metric.length * i / n;
          final tan = metric.getTangentForOffset(d)!;
          final normal = Offset(-tan.vector.dy, tan.vector.dx);
          final pt = tan.position + normal * (sin(d / (w * 0.9) + strand) * w * 0.22);
          i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
        }
        canvas.drawPath(p, _stroke(w * 0.17, shader: steel)..strokeCap = StrokeCap.round);
      }
    }
    final barb = _stroke(w * 0.15, shader: steel)..strokeCap = StrokeCap.round;
    for (final tan in _along(rr, w * 3.2)) {
      final v = tan.vector;
      final n = Offset(-v.dy, v.dx);
      for (final s in [1.0, -1.0]) {
        canvas.drawLine(tan.position, tan.position + (n * s + v * 0.6) * w * 0.65, barb);
        canvas.drawLine(tan.position, tan.position + (n * s - v * 0.6) * w * 0.65, barb);
      }
      canvas.drawCircle(tan.position, w * 0.2, Paint()..shader = steel);
    }
  }

  /// Rose e spine: il ramo verde scuro, le spine, una rosa in ogni angolo.
  void _roses(Canvas canvas, RRect rr, double w) {
    final vine = _stroke(w * 0.32, color: const Color(0xFF203A1E))..strokeCap = StrokeCap.round;
    for (final metric in _ring(rr).computeMetrics()) {
      final p = Path();
      final n = (metric.length / 1.5).round();
      for (var i = 0; i <= n; i++) {
        final d = metric.length * i / n;
        final tan = metric.getTangentForOffset(d)!;
        final normal = Offset(-tan.vector.dy, tan.vector.dx);
        final pt = tan.position + normal * (sin(d / (w * 1.6)) * w * 0.3);
        i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
      }
      canvas.drawPath(p, vine);
      canvas.drawPath(p, _stroke(w * 0.1, color: const Color(0xFF4F7A3A)));
    }
    final thorn = Paint()..color = const Color(0xFF2B4A22);
    var k = 0;
    for (final tan in _along(rr, w * 1.7)) {
      final v = tan.vector;
      final n = Offset(-v.dy, v.dx) * (k.isEven ? 1.0 : -1.0);
      final base = tan.position;
      final p = Path()
        ..moveTo(base.dx + v.dx * w * 0.22, base.dy + v.dy * w * 0.22)
        ..lineTo(base.dx - v.dx * w * 0.22, base.dy - v.dy * w * 0.22)
        ..lineTo(base.dx + n.dx * w * 0.6 - v.dx * w * 0.25, base.dy + n.dy * w * 0.6 - v.dy * w * 0.25)
        ..close();
      canvas.drawPath(p, thorn);
      // Qualche foglia.
      if (k % 3 == 1) {
        canvas.save();
        canvas.translate(base.dx, base.dy);
        canvas.rotate(atan2(n.dy, n.dx) + 0.5);
        canvas.drawOval(Rect.fromLTWH(0, -w * 0.18, w * 0.75, w * 0.36), Paint()..color = const Color(0xFF3E6A2E));
        canvas.restore();
      }
      k++;
    }
    for (final c in _corners(rr)) {
      _rose(canvas, c, w * 0.95);
    }
  }

  static void _rose(Canvas canvas, Offset c, double r) {
    canvas.drawCircle(c, r * 1.1, Paint()..color = const Color(0x66000000)..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.4));
    for (var i = 0; i < 5; i++) {
      final a = i * 2 * pi / 5;
      canvas.drawCircle(c + Offset(cos(a), sin(a)) * r * 0.45, r * 0.6, Paint()..color = const Color(0xFF8E0E1C));
    }
    canvas.drawCircle(c, r * 0.62, Paint()..color = const Color(0xFFC21E30));
    final swirl = _stroke(r * 0.12, color: const Color(0xFF5A0610))..strokeCap = StrokeCap.round;
    final p = Path()..moveTo(c.dx, c.dy);
    for (var i = 0; i < 40; i++) {
      final a = i * 0.32;
      final d = r * 0.03 + i * r * 0.0135;
      p.lineTo(c.dx + cos(a) * d, c.dy + sin(a) * d);
    }
    canvas.drawPath(p, swirl);
    canvas.drawCircle(c + Offset(-r * 0.25, -r * 0.3), r * 0.14, Paint()..color = const Color(0x55FFFFFF));
  }

  /// Un tubo al neon: alone largo, tubo, anima bianca.
  void _neon(Canvas canvas, RRect rr, double w, Color glow, Color core, double strength) {
    canvas.drawRRect(rr, _stroke(w * 1.6, color: glow.withValues(alpha: 0.45 * strength))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 1.1));
    canvas.drawRRect(rr, _stroke(w * 0.62, color: glow)..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.18));
    canvas.drawRRect(rr, _stroke(w * 0.24, color: core));
    // Le staffe che tengono il tubo.
    for (final c in _corners(rr)) {
      canvas.drawCircle(c, w * 0.22, Paint()..color = const Color(0xFF2A2228));
    }
  }

  /// Fiamma leggendaria: lingue di fuoco che salgono tutt'intorno.
  void _flame(Canvas canvas, RRect rr, double w) {
    final t = _t;
    canvas.drawRRect(rr, _stroke(w * 2.2, color: const Color(0x88FF5A12))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 1.4));
    canvas.drawRRect(rr, _stroke(w * 0.9, color: const Color(0xFF3A0A02)));
    final tongues = _along(rr, w * 0.9).toList();
    for (var i = 0; i < tongues.length; i++) {
      final tan = tongues[i];
      final v = tan.vector;
      // Verso fuori dalla carta.
      final out = Offset(v.dy, -v.dx);
      final flicker = 0.55 + 0.45 * sin(t * 2 * pi * 2 + i * 1.7) * sin(t * 2 * pi + i * 0.6);
      final len = w * (1.0 + 1.3 * flicker.abs());
      final up = Offset(0, -1);
      final dir = Offset.lerp(out, up, 0.35)!;
      final tip = tan.position + dir / dir.distance * len;
      final half = v * (w * 0.5);
      final p = Path()
        ..moveTo(tan.position.dx - half.dx, tan.position.dy - half.dy)
        ..quadraticBezierTo(
          tan.position.dx + dir.dx * len * 0.5 - half.dx * 0.8 + v.dx * w * 0.3 * sin(t * 6 + i),
          tan.position.dy + dir.dy * len * 0.5 - half.dy * 0.8,
          tip.dx,
          tip.dy,
        )
        ..quadraticBezierTo(
          tan.position.dx + dir.dx * len * 0.4 + half.dx * 0.8,
          tan.position.dy + dir.dy * len * 0.4 + half.dy * 0.8,
          tan.position.dx + half.dx,
          tan.position.dy + half.dy,
        )
        ..close();
      final colors = i.isEven
          ? const [Color(0xFFFFF3B0), Color(0xFFFFA21F), Color(0x00E8340C)]
          : const [Color(0xFFFFD45A), Color(0xFFF2560F), Color(0x00A3160A)];
      canvas.drawPath(
        p,
        Paint()
          ..shader = ui.Gradient.linear(tan.position, tip, colors, const [0, 0.45, 1])
          ..blendMode = BlendMode.plus,
      );
    }
    final ember = _metal(rr.outerRect, const [Color(0xFFFF7A1A), Color(0xFFFFE08A), Color(0xFFE2410C)]);
    canvas.drawRRect(rr, _stroke(w * 0.32, shader: ember));
    canvas.drawRRect(rr, _stroke(w * 0.1, color: const Color(0xFFFFF6D0)));
  }

  /// Neon leggendario: un tubo che cambia colore in giro e respira.
  void _pulse(Canvas canvas, RRect rr, double w) {
    final t = _t;
    final breath = 0.7 + 0.3 * sin(t * 2 * pi * 2);
    final c = rr.center;
    final sweep = SweepGradient(
      center: Alignment.center,
      colors: const [Color(0xFF29E6FF), Color(0xFFB04BFF), Color(0xFFFF3FA4), Color(0xFFFFC23F), Color(0xFF29E6FF)],
      transform: GradientRotation(t * 2 * pi),
    ).createShader(Rect.fromCircle(center: c, radius: rr.outerRect.longestSide));
    canvas.drawRRect(rr, _stroke(w * 2.0, shader: sweep)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 1.3 * breath)
      ..color = Colors.white.withValues(alpha: breath));
    canvas.drawRRect(rr, _stroke(w * 0.7, shader: sweep)..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.2));
    canvas.drawRRect(rr, _stroke(w * 0.22, color: Colors.white.withValues(alpha: 0.85 + 0.15 * breath)));
    // Una scintilla che corre lungo il tubo.
    for (final metric in _ring(rr).computeMetrics()) {
      for (final off in [0.0, 0.5]) {
        final tan = metric.getTangentForOffset(((t + off) % 1) * metric.length);
        if (tan == null) continue;
        canvas.drawCircle(tan.position, w * 0.9, Paint()
          ..color = Colors.white.withValues(alpha: 0.75)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.6));
        canvas.drawCircle(tan.position, w * 0.3, Paint()..color = Colors.white);
      }
    }
  }

  @override
  bool shouldRepaint(SeatFramePainter old) =>
      old.border != border || old.radius != radius || old.thickness != thickness || old.inset != inset || old.clock != clock;
}
