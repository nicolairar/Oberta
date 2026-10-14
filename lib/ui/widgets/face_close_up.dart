import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'noir_avatar.dart';

/// Il primo piano da fumetto che entra in scena quando la vittima si
/// accorge di qualcosa: la sua faccia (la foto, se c'è) in un riquadro
/// tondo, su uno scoppio di raggi, con un "?!" sopra. Solo la vittima: di
/// chi colpisce non si vede mai la faccia.
class FaceCloseUp extends StatelessWidget {
  final String name;

  /// Da 0 a 1 lungo tutta l'apparizione: entra di scatto, trema, se ne va.
  final double life;
  final double size;

  const FaceCloseUp({super.key, required this.name, required this.life, this.size = 128});

  @override
  Widget build(BuildContext context) {
    if (life <= 0 || life >= 1) return const SizedBox.shrink();
    final pop = Curves.elasticOut.transform((life / 0.25).clamp(0.0, 1.0));
    final leave = Curves.easeIn.transform(((life - 0.8) / 0.2).clamp(0.0, 1.0));
    final shake = sin(life * 70) * 2.5 * (1 - leave);
    return IgnorePointer(
      child: Opacity(
        opacity: 1 - leave,
        child: Transform.translate(
          offset: Offset(shake, -leave * 18),
          child: Transform.scale(
            scale: 0.3 + 0.7 * pop,
            child: SizedBox.square(
              dimension: size * 1.7,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  CustomPaint(size: Size.square(size * 1.7), painter: _Burst(spin: life)),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.gold, width: 4),
                      boxShadow: const [BoxShadow(color: Colors.black, blurRadius: 16)],
                    ),
                    child: NoirAvatar(seed: name, size: size),
                  ),
                  Positioned(
                    top: size * 0.02,
                    right: size * 0.12,
                    child: Transform.rotate(
                      angle: 0.18,
                      child: Text(
                        '?!',
                        style: TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: size * 0.34,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFFFFE27A),
                          shadows: const [
                            Shadow(color: Colors.black, offset: Offset(2, 2)),
                            Shadow(color: Colors.black, blurRadius: 6),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// I raggi dello stupore, dietro la faccia.
class _Burst extends CustomPainter {
  final double spin;

  const _Burst({required this.spin});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;
    const rays = 14;
    final path = Path();
    for (var i = 0; i < rays * 2; i++) {
      final angle = spin * 0.6 + i * pi / rays;
      final r = i.isEven ? radius : radius * 0.62;
      final point = center + Offset(cos(angle), sin(angle)) * r;
      i == 0 ? path.moveTo(point.dx, point.dy) : path.lineTo(point.dx, point.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = const Color(0xFFB3202A));
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.black,
    );
  }

  @override
  bool shouldRepaint(_Burst old) => old.spin != spin;
}
