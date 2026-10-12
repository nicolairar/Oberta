import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../rules/wheel_spin.dart';
import '../theme/app_theme.dart';

class WheelSegment {
  final String label;
  final Color color;

  const WheelSegment(this.label, this.color);
}

/// Ruota che parte da ferma, gira fino a [finalAngle] rallentando e si ferma.
/// Il punto di arrivo è deciso da fuori: il widget si limita ad animarlo.
class SpinWheel extends StatefulWidget {
  final List<WheelSegment> segments;
  final double finalAngle;
  final Duration duration;
  final bool showPointer;
  final VoidCallback? onStopped;

  const SpinWheel({
    super.key,
    required this.segments,
    required this.finalAngle,
    this.duration = const Duration(milliseconds: 5200),
    this.showPointer = true,
    this.onStopped,
  });

  @override
  State<SpinWheel> createState() => _SpinWheelState();
}

class _SpinWheelState extends State<SpinWheel> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _angle;
  int _lastIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          HapticFeedback.heavyImpact();
          widget.onStopped?.call();
        }
      });
    _angle = Tween<double>(begin: 0, end: widget.finalAngle).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart),
    )..addListener(_tick);
    _controller.forward();
  }

  void _tick() {
    final index = WheelSpin.indexAtAngle(_angle.value, widget.segments.length);
    if (index != _lastIndex) {
      _lastIndex = index;
      HapticFeedback.selectionClick();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _angle,
                builder: (context, _) => CustomPaint(
                  painter: _WheelPainter(widget.segments, _angle.value),
                ),
              ),
            ),
          ),
          if (widget.showPointer)
            const Positioned(
              top: -16,
              child: CustomPaint(size: Size(36, 44), painter: _PointerPainter()),
            ),
        ],
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  final List<WheelSegment> segments;
  final double angle;

  _WheelPainter(this.segments, this.angle);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final rim = radius * 0.05;
    final sweep = 2 * pi / segments.length;
    final disc = Rect.fromCircle(center: Offset.zero, radius: radius - rim);

    canvas.drawCircle(
      center + Offset(0, radius * 0.05),
      radius * 0.98,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.6)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.1),
    );

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);

    final divider = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.5, radius * 0.012)
      ..color = AppColors.gold.withValues(alpha: 0.75);
    final labelStyle = TextStyle(
      color: AppColors.textPrimary,
      fontWeight: FontWeight.w700,
      fontSize: (radius * 0.085).clamp(10.0, 18.0),
      letterSpacing: 0.5,
    );

    for (var i = 0; i < segments.length; i++) {
      final start = -pi / 2 + i * sweep;
      canvas.drawArc(disc, start, sweep, true, Paint()..color = segments[i].color);
      canvas.drawArc(disc, start, sweep, true, divider);

      final label = TextPainter(
        text: TextSpan(text: segments[i].label, style: labelStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: radius * 0.55);
      canvas.save();
      canvas.rotate(start + sweep / 2);
      label.paint(canvas, Offset(radius * 0.8 - label.width, -label.height / 2));
      canvas.restore();
    }

    canvas.drawCircle(
      Offset.zero,
      radius - rim,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.10),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.35),
          ],
          stops: const [0, 0.55, 1],
        ).createShader(disc),
    );
    canvas.restore();

    canvas.drawCircle(
      center,
      radius - rim / 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = rim
        ..color = AppColors.gold,
    );
    canvas.drawCircle(center, radius * 0.15, Paint()..color = AppColors.background);
    canvas.drawCircle(
      center,
      radius * 0.15,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = rim * 0.7
        ..color = AppColors.gold,
    );
    canvas.drawCircle(center, radius * 0.045, Paint()..color = AppColors.gold);
  }

  @override
  bool shouldRepaint(_WheelPainter old) => old.angle != angle || old.segments != segments;
}

class _PointerPainter extends CustomPainter {
  const _PointerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawShadow(path, Colors.black, 6, true);
    canvas.drawPath(path, Paint()..color = AppColors.textPrimary);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round
        ..color = AppColors.accent,
    );
  }

  @override
  bool shouldRepaint(_PointerPainter old) => false;
}
