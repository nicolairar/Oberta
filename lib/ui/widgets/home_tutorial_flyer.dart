import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Il volantino del tutorial, legato al palo del lampione con lo spago:
/// carta strappata, due righe a macchina, un asso disegnato a mano.
class HomeTutorialFlyer extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const HomeTutorialFlyer({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Transform.rotate(
        angle: -0.06,
        child: CustomPaint(
          painter: _FlyerPainter(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 16, 6, 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  '?',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontFamilyFallback: ['serif'],
                    fontSize: 26,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF8E1E24),
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Courier',
                      fontFamilyFallback: ['monospace'],
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      color: Color(0xFF241C14),
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

class _FlyerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // Il bordo in basso strappato.
    final paper = Path()
      ..moveTo(0, 8)
      ..lineTo(w, 8)
      ..lineTo(w, h - 4);
    for (var x = w; x > 0; x -= 7) {
      paper.lineTo(x - 3.5, h - ((x ~/ 7).isEven ? 6 : 1));
      paper.lineTo(x - 7, h - 3);
    }
    paper
      ..lineTo(0, h - 2)
      ..close();
    canvas.drawPath(paper.shift(const Offset(2, 3)), Paint()..color = Colors.black.withValues(alpha: 0.55));
    canvas.drawPath(
      paper,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFD9CDAE), Color(0xFFB4A684)],
        ).createShader(Offset.zero & size),
    );
    // Lo spago intorno al palo.
    final twine = Paint()
      ..color = const Color(0xFF6B5636)
      ..strokeWidth = 2;
    canvas.drawLine(Offset(-4, 4), Offset(w + 4, 2), twine);
    canvas.drawCircle(Offset(w / 2, 9), 3.5, Paint()..color = const Color(0xFF8E1E24));
  }

  @override
  bool shouldRepaint(_FlyerPainter old) => false;
}
