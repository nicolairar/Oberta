import 'dart:math';

import 'package:flutter/material.dart';

import 'noir_ui.dart';

/// La sala sul retro del bar, vista dall'alto di tre quarti: le pareti di
/// legno, il pavimento a scacchi, la lampada che scalda il tavolo. Di notte
/// la lampada è più bassa e la stanza più fredda.
class SaloonBackdrop extends StatelessWidget {
  final bool night;
  final Widget child;

  const SaloonBackdrop({super.key, this.night = false, required this.child});

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _RoomPainter(night: night),
        child: child,
      );
}

class _RoomPainter extends CustomPainter {
  final bool night;

  _RoomPainter({required this.night});

  @override
  void paint(Canvas canvas, Size size) {
    final all = Offset.zero & size;
    // Pareti: legno scuro, a doghe.
    canvas.drawRect(
      all,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: night
              ? const [Color(0xFF0B0D14), Color(0xFF120E0D), Color(0xFF080606)]
              : const [Color(0xFF2B170C), Color(0xFF1A0F09), Color(0xFF0B0705)],
        ).createShader(all),
    );
    final plank = Paint()..color = Colors.black.withValues(alpha: 0.22);
    for (var x = 0.0; x < size.width; x += 38) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 1.2, size.height * 0.3), plank);
    }
    // Il pavimento a scacchi, in prospettiva, che si perde nel buio.
    final floorTop = size.height * 0.3;
    final tile = size.width / 9;
    for (var row = 0; row * tile * 0.6 < size.height; row++) {
      for (var col = 0; col < 10; col++) {
        if ((row + col).isEven) continue;
        canvas.drawRect(
          Rect.fromLTWH(col * tile - (row.isOdd ? tile / 2 : 0), floorTop + row * tile * 0.6, tile, tile * 0.6),
          Paint()..color = Colors.white.withValues(alpha: night ? 0.025 : 0.04),
        );
      }
    }
    // La lampada: una pozza di luce calda sul tavolo.
    final lamp = Offset(size.width * 0.5, size.height * 0.42);
    canvas.drawCircle(
      lamp,
      size.longestSide * 0.62,
      Paint()
        ..shader = RadialGradient(
          colors: night
              ? [const Color(0x55E0A860), const Color(0x22303860), Colors.transparent]
              : [const Color(0x88F0B868), const Color(0x33A06030), Colors.transparent],
          stops: const [0, 0.45, 1],
        ).createShader(Rect.fromCircle(center: lamp, radius: size.longestSide * 0.62)),
    );
    // Vignetta.
    canvas.drawRect(
      all,
      Paint()
        ..shader = RadialGradient(
          radius: 0.95,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.75)],
          stops: const [0.55, 1],
        ).createShader(all),
    );
  }

  @override
  bool shouldRepaint(_RoomPainter old) => old.night != night;
}

/// Il tavolo ovale: bordo di legno, panno verde con il filetto d'oro.
class _TablePainter extends CustomPainter {
  final Rect felt;

  _TablePainter(this.felt);

  @override
  void paint(Canvas canvas, Size size) {
    final rim = felt.inflate(felt.shortestSide * 0.07);
    canvas.drawOval(rim.shift(const Offset(0, 14)), Paint()
      ..color = Colors.black.withValues(alpha: 0.6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18));
    canvas.drawOval(
      rim,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF7A4724), Saloon.wood, Saloon.woodDark],
        ).createShader(rim),
    );
    canvas.drawOval(
      felt,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -0.2),
          radius: 0.8,
          colors: [Color(0xFF2E6A48), Saloon.felt, Saloon.feltDeep],
          stops: [0, 0.55, 1],
        ).createShader(felt),
    );
    canvas.drawOval(
      felt.deflate(felt.shortestSide * 0.06),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Saloon.brass.withValues(alpha: 0.45),
    );
  }

  @override
  bool shouldRepaint(_TablePainter old) => old.felt != felt;
}

/// Una freccia dal votante all'accusato.
typedef SeatArrow = ({int from, int to, Color color});

/// I giocatori seduti intorno al tavolo, tutti grandi uguali: i posti
/// dipendono solo da quanti sono. [seatBuilder] disegna il posto [index]
/// largo [width]; [arrows] uniscono i posti (chi accusa chi); [center] sta
/// sul panno.
class SaloonTable extends StatelessWidget {
  final int count;
  final Widget Function(BuildContext context, int index, double width) seatBuilder;
  final List<SeatArrow> arrows;
  final Widget? center;

  /// Il rapporto altezza/larghezza delle carte dei posti.
  static const cardAspect = 1.32;

  const SaloonTable({super.key, required this.count, required this.seatBuilder, this.arrows = const [], this.center});

  /// La larghezza delle carte per [count] posti in [box].
  static double cardWidth(int count, Size box) {
    // Le carte stanno su un ovale: abbastanza piccole da non toccarsi.
    final perimeter = pi * (box.width + box.height) * 0.42;
    final fit = perimeter / max(count, 1) * 0.82;
    return fit.clamp(54.0, min(box.width * 0.28, 118.0));
  }

  /// I centri dei posti: si parte da mezzogiorno e si gira in senso orario.
  static List<Offset> seats(int count, Size box, double width) {
    final height = width * cardAspect;
    final rx = (box.width - width) / 2;
    final ry = (box.height - height) / 2;
    final center = box.center(Offset.zero);
    return [
      for (var i = 0; i < count; i++)
        center + Offset(rx * sin(2 * pi * i / count), -ry * cos(2 * pi * i / count)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final size = box.biggest;
      final width = cardWidth(count, size);
      final height = width * cardAspect;
      final centers = seats(count, size, width);
      final felt = Rect.fromCenter(
        center: size.center(Offset.zero),
        width: max(40, size.width - width * 0.9),
        height: max(40, size.height - height * 0.75),
      );
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: CustomPaint(painter: _TablePainter(felt))),
          if (center != null)
            Positioned.fromRect(
              rect: Rect.fromCenter(center: felt.center, width: felt.width * 0.62, height: felt.height * 0.5),
              child: Center(child: center),
            ),
          for (var i = 0; i < count; i++)
            Positioned(
              left: centers[i].dx - width / 2,
              top: centers[i].dy - height / 2,
              width: width,
              height: height,
              child: seatBuilder(context, i, width),
            ),
          if (arrows.isNotEmpty)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _ArrowPainter(arrows, centers, Size(width, height))),
              ),
            ),
        ],
      );
    });
  }
}

/// Le frecce delle accuse: un filo d'inchiostro curvo dal ritratto di chi
/// vota a quello dell'accusato, con la punta.
class _ArrowPainter extends CustomPainter {
  final List<SeatArrow> arrows;
  final List<Offset> centers;
  final Size card;

  _ArrowPainter(this.arrows, this.centers, this.card);

  Offset _edge(Offset from, Offset toward) {
    final d = toward - from;
    final len = d.distance;
    if (len == 0) return from;
    final dir = d / len;
    // Fino al bordo della carta, a occhio (un'ellisse dentro la carta).
    final t = 1 / sqrt(pow(dir.dx / (card.width * 0.5), 2) + pow(dir.dy / (card.height * 0.5), 2));
    return from + dir * t;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final middle = size.center(Offset.zero);
    for (final arrow in arrows) {
      if (arrow.from == arrow.to || arrow.from >= centers.length || arrow.to >= centers.length) continue;
      final a = centers[arrow.from];
      final b = centers[arrow.to];
      // Si curva verso il centro del tavolo, così le frecce stanno sul panno.
      final control = Offset.lerp(Offset.lerp(a, b, 0.5)!, middle, 0.45)!;
      final start = _edge(a, control);
      final end = _edge(b, control);
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..color = Colors.black.withValues(alpha: 0.55),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round
          ..color = arrow.color,
      );
      final dir = (end - control) / max((end - control).distance, 0.001);
      final normal = Offset(-dir.dy, dir.dx);
      final head = Path()
        ..moveTo(end.dx, end.dy)
        ..lineTo(end.dx - dir.dx * 12 + normal.dx * 6, end.dy - dir.dy * 12 + normal.dy * 6)
        ..lineTo(end.dx - dir.dx * 12 - normal.dx * 6, end.dy - dir.dy * 12 - normal.dy * 6)
        ..close();
      canvas.drawPath(head, Paint()..color = arrow.color);
      canvas.drawCircle(start, 3.2, Paint()..color = arrow.color);
    }
  }

  @override
  bool shouldRepaint(_ArrowPainter old) => true;
}
