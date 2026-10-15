import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../rules/wheel_spin.dart';
import '../../sound/cue_sounds.dart';
import '../../sound/sound_stage.dart';
import '../theme/app_theme.dart';
import 'noir_avatar.dart';
import '../../sound/memes.dart';

/// Il tamburo di un revolver visto da dietro, con un giocatore in ogni
/// camera. Gira scattando, rallenta, e la camera che si ferma sotto il cane
/// è quella sorteggiata. Dove si ferma lo decide chi chiama, prima del giro.
class RevolverCylinder extends StatefulWidget {
  /// Un nome per camera, in senso orario a partire dall'alto.
  final List<String> names;
  final double finalAngle;
  final int winnerIndex;
  final VoidCallback? onStopped;

  const RevolverCylinder({
    super.key,
    required this.names,
    required this.finalAngle,
    required this.winnerIndex,
    this.onStopped,
  });

  @override
  State<RevolverCylinder> createState() => _RevolverCylinderState();
}

class _RevolverCylinderState extends State<RevolverCylinder> with TickerProviderStateMixin {
  late final AnimationController _spin;
  late final AnimationController _bang;
  late final Animation<double> _angle;
  int _lastIndex = 0;

  @override
  void initState() {
    super.initState();
    _bang = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _spin = AnimationController(vsync: this, duration: const Duration(milliseconds: 5200))
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          HapticFeedback.heavyImpact();
          SoundStage.instance.cue(Cue.bang);
          // Il narratore estratto: "hell nah".
          SoundStage.instance.meme(Meme.hellNah, after: const Duration(milliseconds: 500));
          _bang.forward();
          widget.onStopped?.call();
        }
      });
    _angle = Tween<double>(begin: 0, end: widget.finalAngle).animate(
      CurvedAnimation(parent: _spin, curve: Curves.easeOutQuart),
    )..addListener(_click);
    _spin.forward();
  }

  /// Uno scatto ogni volta che una camera passa sotto il cane.
  void _click() {
    final index = WheelSpin.indexAtAngle(_angle.value, widget.names.length);
    if (index != _lastIndex) {
      _lastIndex = index;
      HapticFeedback.selectionClick();
      SoundStage.instance.cue(Cue.click);
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    _bang.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.names.length;
    final sweep = 2 * pi / count;

    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final radius = constraints.biggest.shortestSide / 2;
          final orbit = radius * 0.60;
          final chamber = min(radius * 0.25, orbit * sin(pi / count) * 0.86);
          final portrait = chamber * 1.74;

          final cylinder = RepaintBoundary(
            child: Stack(
              children: [
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _bang,
                    builder: (context, _) => CustomPaint(
                      painter: _CylinderPainter(
                        count: count,
                        chamber: chamber / radius,
                        winner: _spin.isCompleted ? widget.winnerIndex : null,
                        glow: min(1, _bang.value * 4),
                      ),
                    ),
                  ),
                ),
                for (var i = 0; i < count; i++)
                  Positioned(
                    left: radius + orbit * cos(-pi / 2 + (i + 0.5) * sweep) - portrait / 2,
                    top: radius + orbit * sin(-pi / 2 + (i + 0.5) * sweep) - portrait / 2,
                    // Ogni ritratto ha la testa verso l'esterno: quello che
                    // arriva in cima si ritrova dritto.
                    child: Transform.rotate(
                      angle: (i + 0.5) * sweep,
                      child: NoirAvatar(seed: widget.names[i], size: portrait),
                    ),
                  ),
              ],
            ),
          );

          return AnimatedBuilder(
            animation: Listenable.merge([_angle, _bang]),
            builder: (context, _) {
              final recoil = sin(pi * min(1.0, _bang.value * 2.2));
              // Dopo il rinculo il sorteggiato esce dalla sua camera e viene
              // avanti, in primo piano.
              final closeUp = Curves.easeOutBack.transform(((_bang.value - 0.4) / 0.6).clamp(0.0, 1.0));
              return Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.topCenter,
                children: [
                  Positioned.fill(
                    child: Transform.translate(
                      offset: Offset(0, recoil * 8),
                      child: Transform.scale(
                        scale: 1 + recoil * 0.04,
                        child: Transform.rotate(angle: _angle.value, child: cylinder),
                      ),
                    ),
                  ),
                  if (_bang.value > 0.4)
                    Positioned.fill(
                      child: Align(
                        alignment: Alignment.lerp(const Alignment(0, -0.60), Alignment.center, closeUp)!,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFFC24A).withValues(alpha: 0.5 * closeUp.clamp(0.0, 1.0)),
                                blurRadius: radius * 0.35,
                                spreadRadius: radius * 0.04,
                              ),
                            ],
                          ),
                          child: NoirAvatar(
                            seed: widget.names[widget.winnerIndex],
                            size: portrait + (radius * 1.25 - portrait) * closeUp,
                          ),
                        ),
                      ),
                    ),
                  if (_bang.isAnimating && _bang.value < 0.5)
                    Positioned(
                      top: -radius * 0.5,
                      width: radius * 1.6,
                      height: radius * 1.6,
                      child: IgnorePointer(
                        child: Opacity(
                          opacity: (1 - _bang.value * 2) * (1 - _bang.value * 2),
                          child: const DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [Color(0xFFFFF3C4), Color(0x99FF9A3B), Color(0x00FF9A3B)],
                                stops: [0, 0.35, 1],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top: -radius * 0.10 - recoil * 6,
                    child: CustomPaint(
                      size: Size(radius * 0.22, radius * 0.26),
                      painter: const _HammerPainter(),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _CylinderPainter extends CustomPainter {
  final int count;

  /// Raggio di una camera, come frazione del raggio del tamburo.
  final double chamber;
  final int? winner;
  final double glow;

  _CylinderPainter({required this.count, required this.chamber, this.winner, this.glow = 0});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final sweep = 2 * pi / count;
    Offset polar(double distance, double angle) =>
        center + Offset(cos(angle), sin(angle)) * (radius * distance);

    // Il profilo: un disco con una scanalatura tra una camera e l'altra.
    var body = Path()..addOval(Rect.fromCircle(center: center, radius: radius * 0.98));
    final flute = min(0.17, sin(pi / count) * 0.40);
    for (var i = 0; i < count; i++) {
      body = Path.combine(
        PathOperation.difference,
        body,
        Path()..addOval(Rect.fromCircle(center: polar(1.02, -pi / 2 + i * sweep), radius: radius * flute)),
      );
    }

    canvas.drawPath(
      body.shift(Offset(0, radius * 0.05)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.6)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.08),
    );
    final bounds = Rect.fromCircle(center: center, radius: radius);
    canvas.drawPath(
      body,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.45),
          radius: 1.1,
          colors: [Color(0xFFB4BAC2), Color(0xFF6A7078), Color(0xFF2A2D32), Color(0xFF15171A)],
          stops: [0, 0.38, 0.8, 1],
        ).createShader(bounds),
    );
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.012
        ..color = Colors.white.withValues(alpha: 0.18),
    );

    for (var i = 0; i < count; i++) {
      final hole = polar(0.60, -pi / 2 + (i + 0.5) * sweep);
      final r = radius * chamber;
      canvas.drawCircle(hole, r * 1.10, Paint()..color = Colors.black.withValues(alpha: 0.35));
      canvas.drawCircle(hole, r, Paint()..color = const Color(0xFF08090B));
      final isWinner = i == winner;
      if (isWinner && glow > 0) {
        canvas.drawCircle(
          hole,
          r * 1.08,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.22
            ..color = const Color(0xFFFFC24A).withValues(alpha: min(1, glow))
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.25),
        );
      }
      canvas.drawCircle(
        hole,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * 0.016
          ..color = isWinner ? const Color(0xFFFFD77A) : AppColors.gold.withValues(alpha: 0.75),
      );
    }

    // Il perno, con la stella dell'estrattore.
    canvas.drawCircle(
      center,
      radius * 0.17,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF4A4F56), Color(0xFF17191C)],
        ).createShader(Rect.fromCircle(center: center, radius: radius * 0.17)),
    );
    final notch = Paint()
      ..color = Colors.black.withValues(alpha: 0.7)
      ..strokeWidth = radius * 0.02
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 6; i++) {
      final angle = i * pi / 3;
      canvas.drawLine(polar(0.07, angle), polar(0.14, angle), notch);
    }
    canvas.drawCircle(center, radius * 0.045, Paint()..color = AppColors.gold);
  }

  @override
  bool shouldRepaint(_CylinderPainter old) =>
      old.winner != winner || old.glow != glow || old.count != count || old.chamber != chamber;
}

/// Il cane del revolver, fermo in alto: indica la camera che conta.
class _HammerPainter extends CustomPainter {
  const _HammerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.18, 0)
      ..lineTo(w * 0.82, 0)
      ..lineTo(w * 0.92, h * 0.38)
      ..lineTo(w * 0.5, h)
      ..lineTo(w * 0.08, h * 0.38)
      ..close();
    canvas.drawShadow(path, Colors.black, 6, true);
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFD0D5DB), Color(0xFF5D636B), Color(0xFF22252A)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeJoin = StrokeJoin.round
        ..color = AppColors.gold.withValues(alpha: 0.8),
    );
  }

  @override
  bool shouldRepaint(_HammerPainter old) => false;
}
