import 'dart:math';

import 'package:flutter/material.dart';
import '../press.dart';

/// Il pulsante delle impostazioni: una targhetta di smalto scuro avvitata al
/// muro, con un ingranaggio. Sta zitta in un angolo e non ruba la scena
/// all'insegna.
class HomeSettingsPlate extends StatefulWidget {
  /// Il nome del pulsante, per chi lo tiene premuto e per VoiceOver.
  final String label;
  final VoidCallback onTap;

  const HomeSettingsPlate({super.key, required this.label, required this.onTap});

  @override
  State<HomeSettingsPlate> createState() => _HomeSettingsPlateState();
}

class _HomeSettingsPlateState extends State<HomeSettingsPlate> {
  bool _pressed = false;

  void _press(bool down) {
    if (_pressed != down) setState(() => _pressed = down);
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.label,
      child: Semantics(
        button: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _press(true),
          onTapUp: (_) => _press(false),
          onTapCancel: () => _press(false),
          onTap: pressed(widget.onTap, Press.toggle),
          child: CustomPaint(painter: _PlatePainter(_pressed), size: Size.infinite),
        ),
      ),
    );
  }
}

class _PlatePainter extends CustomPainter {
  final bool pressed;

  _PlatePainter(this.pressed);

  static const _iron = Color(0xFF08080B);
  static const _cog = Color(0xFFD8CCB2);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * 0.33;
    final plate = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(center.translate(1.5, 2.5), radius, Paint()..color = Colors.black.withValues(alpha: 0.6));
    canvas.drawCircle(center, radius, Paint()..color = _iron);
    // Lo smalto: blu notte, con il riflesso rosso dell'insegna su un fianco.
    canvas.drawCircle(
      center,
      radius * 0.90,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.5, -0.6),
          radius: 1.2,
          colors: pressed
              ? const [Color(0xFF1B1F2C), Color(0xFF0B0D14)]
              : const [Color(0xFF3A3144), Color(0xFF171A27), Color(0xFF0C0E16)],
        ).createShader(plate),
    );
    canvas.drawArc(
      plate.deflate(radius * 0.16),
      pi * 1.05,
      pi * 0.45,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFFF6A5A).withValues(alpha: pressed ? 0.15 : 0.40),
    );

    // L'ingranaggio: otto denti intorno a un anello.
    final ink = Paint()..color = _cog.withValues(alpha: pressed ? 0.6 : 0.88);
    final hub = radius * 0.34;
    final tooth = Rect.fromCenter(center: Offset(0, -hub * 1.12), width: hub * 0.50, height: hub * 0.62);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    for (var i = 0; i < 8; i++) {
      canvas.drawRRect(RRect.fromRectAndRadius(tooth, Radius.circular(hub * 0.10)), ink);
      canvas.rotate(pi / 4);
    }
    canvas.restore();
    canvas.drawCircle(
      center,
      hub * 0.74,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = hub * 0.52
        ..color = ink.color,
    );

    // Le due viti che la tengono al muro.
    for (final side in [-1.0, 1.0]) {
      final screw = center + Offset(side * radius * 0.74, 0);
      canvas.drawCircle(screw, radius * 0.085, Paint()..color = _iron);
      canvas.drawCircle(screw.translate(-0.4, -0.4), radius * 0.035, Paint()..color = Colors.white.withValues(alpha: 0.25));
    }
  }

  @override
  bool shouldRepaint(_PlatePainter old) => old.pressed != pressed;
}
