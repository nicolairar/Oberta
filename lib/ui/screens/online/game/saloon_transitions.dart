import 'dart:math';

import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import 'noir_ui.dart';

/// L'attesa, in sala: la lampada che dondola sopra il panno e le carte che
/// vengono distribuite, una alla volta. Sotto, una riga che dice cosa si
/// sta aspettando.
class DealingTable extends StatefulWidget {
  final String status;
  final Widget? below;

  const DealingTable({super.key, required this.status, this.below});

  @override
  State<DealingTable> createState() => _DealingTableState();
}

class _DealingTableState extends State<DealingTable> with SingleTickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat();

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: AnimatedBuilder(
            animation: _loop,
            builder: (context, _) => CustomPaint(painter: _DealPainter(_loop.value), size: Size.infinite),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: Saloon.scrim(radius: 12, border: Saloon.brass),
          child: Text(
            widget.status,
            textAlign: TextAlign.center,
            style: AppText.display(17, color: AppColors.textPrimary).copyWith(letterSpacing: 1.2),
          ),
        ),
        if (widget.below != null) ...[const SizedBox(height: 14), widget.below!],
        const SizedBox(height: 12),
      ],
    );
  }
}

class _DealPainter extends CustomPainter {
  final double t;

  _DealPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.58);
    final felt = Rect.fromCenter(center: center, width: size.width * 0.9, height: size.height * 0.5);
    // La lampada che dondola: il cono di luce si sposta sul panno.
    final swing = sin(t * 2 * pi) * 0.12;
    final lampTop = Offset(size.width / 2, 0);
    final lamp = lampTop + Offset(sin(swing) * size.height * 0.28, cos(swing) * size.height * 0.28);
    canvas.drawOval(felt.inflate(14), Paint()..color = Saloon.woodDark);
    canvas.drawOval(
      felt,
      Paint()
        ..shader = const RadialGradient(colors: [Color(0xFF2E6A48), Saloon.felt, Saloon.feltDeep], stops: [0, 0.5, 1])
            .createShader(felt),
    );
    final pool = Offset(lamp.dx * 1.0, center.dy);
    canvas.drawCircle(
      pool,
      size.width * 0.45,
      Paint()
        ..shader = RadialGradient(colors: [const Color(0x66FFD27A), Colors.transparent])
            .createShader(Rect.fromCircle(center: pool, radius: size.width * 0.45)),
    );
    canvas.drawLine(lampTop, lamp, Paint()
      ..color = const Color(0xFF3A2A1A)
      ..strokeWidth = 2);
    final shade = Path()
      ..moveTo(lamp.dx - 30, lamp.dy + 18)
      ..quadraticBezierTo(lamp.dx, lamp.dy - 16, lamp.dx + 30, lamp.dy + 18)
      ..close();
    canvas.drawPath(shade, Paint()..color = const Color(0xFF6B4A22));
    canvas.drawCircle(lamp + const Offset(0, 18), 7, Paint()..color = const Color(0xFFFFE2A0));
    canvas.drawCircle(lamp + const Offset(0, 18), 22, Paint()
      ..color = const Color(0x55FFD27A)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));

    // Le carte: dal mazzo al centro verso i posti, una dopo l'altra.
    const seats = 6;
    final deck = center;
    for (var i = 0; i < seats; i++) {
      final angle = -pi / 2 + 2 * pi * i / seats + 0.3;
      final target = deck + Offset(cos(angle) * felt.width * 0.38, sin(angle) * felt.height * 0.36);
      final start = i / seats;
      final local = ((t - start) * seats / 1.6).clamp(0.0, 1.0);
      final eased = Curves.easeOutCubic.transform(local);
      final at = Offset.lerp(deck, target, eased)!;
      _card(canvas, at, angle + pi / 2 + eased * 0.6, local > 0 ? 1 : 0);
    }
    for (var k = 0; k < 4; k++) {
      _card(canvas, deck + Offset(0, -k * 1.5), 0.05 * k, 1);
    }
  }

  void _card(Canvas canvas, Offset at, double angle, double opacity) {
    if (opacity == 0) return;
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(angle);
    final rect = Rect.fromCenter(center: Offset.zero, width: 26, height: 38);
    canvas.drawRRect(RRect.fromRectAndRadius(rect.shift(const Offset(2, 3)), const Radius.circular(3)),
        Paint()..color = Colors.black.withValues(alpha: 0.5));
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(3)), Paint()..color = const Color(0xFF7A111B));
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(3), const Radius.circular(2)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Saloon.brass,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DealPainter old) => old.t != t;
}

/// Il momento in cui tutti sono pronti e si parte insieme: lo schermo si
/// oscura, il titolo della fase entra come un cartello di film.
class StageCurtain extends StatelessWidget {
  final String title;
  final String? subtitle;

  const StageCurtain({super.key, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => ColoredBox(
        color: Colors.black.withValues(alpha: 0.82 * v),
        child: Center(
          child: Opacity(
            opacity: v,
            child: Transform.scale(
              scale: 1.25 - 0.25 * v,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 120 * v, height: 1.4, color: Saloon.brass),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(title.toUpperCase(), style: Saloon.plate(40, color: const Color(0xFFFFF1D6))),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 10),
                    Text(subtitle!.toUpperCase(),
                        key: const Key('online.filmSoon'),
                        style: AppText.overline.copyWith(color: Saloon.brass, fontSize: 13, letterSpacing: 3)),
                  ],
                  const SizedBox(height: 14),
                  Container(width: 120 * v, height: 1.4, color: Saloon.brass),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
