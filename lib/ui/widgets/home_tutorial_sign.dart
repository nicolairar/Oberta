import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/script_fonts.dart';

/// Il cartello del tutorial, fissato al palo del lampione con due fascette
/// di ferro: una freccia di smalto color crema, filetto rosso, che punta
/// verso i manifesti. Una parola sola, ben leggibile.
class HomeTutorialSign extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  /// Dove passa il palo, da sinistra del cartello: lì stanno le fascette.
  final double pole;

  const HomeTutorialSign({super.key, required this.label, required this.onTap, required this.pole});

  @override
  State<HomeTutorialSign> createState() => _HomeTutorialSignState();
}

class _HomeTutorialSignState extends State<HomeTutorialSign> {
  bool _lit = false;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final h = box.maxHeight;
        final tip = h * 0.42;
        return Semantics(
          button: true,
          label: widget.label,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _lit = true),
            onExit: (_) => setState(() => _lit = false),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                HapticFeedback.selectionClick();
                widget.onTap();
              },
              child: CustomPaint(
                painter: _SignPainter(pole: widget.pole, lit: _lit),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(h * 0.30, h * 0.20, tip + h * 0.06, h * 0.20),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        widget.label.toUpperCase(),
                        maxLines: 1,
                        style: TextStyle(
                          fontFamily: 'Georgia',
                          fontFamilyFallback: serifFallback,
                          fontSize: h * 0.40,
                          height: 1,
                          fontWeight: FontWeight.w800,
                          letterSpacing: h * 0.05,
                          color: const Color(0xFF1C140E),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      });
}

class _SignPainter extends CustomPainter {
  final double pole;
  final bool lit;

  const _SignPainter({required this.pole, required this.lit});

  static const _enamel = Color(0xFFEFE4CB);
  static const _enamelShade = Color(0xFFC9B892);
  static const _red = Color(0xFF8E1E24);
  static const _iron = Color(0xFF15100C);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final tip = h * 0.42;
    final r = h * 0.12;
    Path arrow(double inset) {
      final top = inset;
      final bottom = h - inset;
      final right = w - inset * 1.4;
      return Path()
        ..moveTo(inset + r, top)
        ..lineTo(right - tip, top)
        ..lineTo(right, h / 2)
        ..lineTo(right - tip, bottom)
        ..lineTo(inset + r, bottom)
        ..quadraticBezierTo(inset, bottom, inset, bottom - r)
        ..lineTo(inset, top + r)
        ..quadraticBezierTo(inset, top, inset + r, top)
        ..close();
    }

    final plate = arrow(0);
    // L'ombra sul muro.
    canvas.drawPath(
      plate.shift(Offset(h * 0.06, h * 0.10)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.6)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, h * 0.06),
    );
    // Lo smalto (più chiaro sotto il mouse).
    canvas.drawPath(
      plate,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: lit ? const [Color(0xFFFFF4DA), Color(0xFFE2D2AC)] : const [_enamel, _enamelShade],
        ).createShader(Offset.zero & size),
    );
    // Il filetto rosso a un dito dal bordo.
    canvas.drawPath(
      arrow(h * 0.09),
      Paint()
        ..color = _red
        ..style = PaintingStyle.stroke
        ..strokeWidth = h * 0.045
        ..strokeJoin = StrokeJoin.round,
    );
    // Il bordo, appena più scuro.
    canvas.drawPath(
      plate,
      Paint()
        ..color = const Color(0xFF6E5A3C)
        ..style = PaintingStyle.stroke
        ..strokeWidth = h * 0.025,
    );
    // Una scheggiatura dello smalto, in basso a destra.
    canvas.drawCircle(Offset(w - tip * 1.25, h * 0.86), h * 0.035, Paint()..color = const Color(0xFF3A2C20));

    // Le due fascette di ferro intorno al palo, con il bullone.
    final band = Paint()..color = _iron;
    final bolt = Paint()..color = const Color(0xFF7A6338);
    for (final y in [h * 0.22, h * 0.78]) {
      final strap = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(pole, y), width: h * 0.34, height: h * 0.13),
        Radius.circular(h * 0.04),
      );
      canvas.drawRRect(strap, band);
      canvas.drawCircle(Offset(pole, y), h * 0.035, bolt);
    }
  }

  @override
  bool shouldRepaint(_SignPainter old) => old.pole != pole || old.lit != lit;
}
