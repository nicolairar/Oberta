import 'dart:math';

import 'package:flutter/material.dart';

/// A small painted flag for a language code (ISO 639-1). Painted rather than
/// an emoji: Windows (Steam) has no flag emoji, and the noir palette wants
/// them slightly faded. The translated languages have a flag; any other
/// lobby gets a brass tag with its code, since a language is not a country.
class LanguageFlag extends StatelessWidget {
  final String code;
  final double height;

  const LanguageFlag(this.code, {super.key, this.height = 14});

  /// The codes with a painted flag.
  static const painted = {'it', 'en', 'es', 'fr', 'de', 'pt'};

  @override
  Widget build(BuildContext context) {
    final width = height * 1.5;
    return Semantics(
      label: code.toUpperCase(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height * 0.12),
        child: SizedBox(
          width: width,
          height: height,
          child: painted.contains(code)
              ? CustomPaint(painter: _FlagPainter(code))
              : DecoratedBox(
                  decoration: const BoxDecoration(color: Color(0xFF3A2A18)),
                  child: Center(
                    child: Text(
                      code.toUpperCase(),
                      style: TextStyle(
                        color: const Color(0xFFD9B46A),
                        fontSize: height * 0.62,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _FlagPainter extends CustomPainter {
  final String code;
  const _FlagPainter(this.code);

  // Slightly desaturated, like an old print.
  static const _green = Color(0xFF2F8A4E);
  static const _white = Color(0xFFF2EDE2);
  static const _red = Color(0xFFC2343B);
  static const _blue = Color(0xFF2A4A8C);
  static const _navy = Color(0xFF1F2D63);
  static const _yellow = Color(0xFFE8C24A);
  static const _black = Color(0xFF1C1C1C);
  static const _gold = Color(0xFFE3B53B);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final paint = Paint();
    void rect(double x, double y, double rw, double rh, Color c) =>
        canvas.drawRect(Rect.fromLTWH(x, y, rw, rh), paint..color = c);
    void vertical(List<Color> colors) {
      for (var i = 0; i < colors.length; i++) {
        rect(w * i / colors.length, 0, w / colors.length + 0.5, h, colors[i]);
      }
    }

    switch (code) {
      case 'it':
        vertical(const [_green, _white, _red]);
      case 'fr':
        vertical(const [_blue, _white, _red]);
      case 'de':
        rect(0, 0, w, h / 3 + 0.5, _black);
        rect(0, h / 3, w, h / 3 + 0.5, _red);
        rect(0, h * 2 / 3, w, h / 3, _gold);
      case 'es':
        rect(0, 0, w, h, _red);
        rect(0, h / 4, w, h / 2, _yellow);
      case 'pt':
        // Brazil: the green field, the gold rhombus and the blue globe.
        rect(0, 0, w, h, _green);
        canvas.drawPath(
          Path()
            ..moveTo(w * 0.5, h * 0.1)
            ..lineTo(w * 0.92, h * 0.5)
            ..lineTo(w * 0.5, h * 0.9)
            ..lineTo(w * 0.08, h * 0.5)
            ..close(),
          paint..color = _yellow,
        );
        canvas.drawCircle(Offset(w / 2, h / 2), h * 0.22, paint..color = _navy);
        canvas.drawArc(
          Rect.fromCircle(center: Offset(w / 2, h * 0.62), radius: h * 0.24),
          pi * 1.15,
          pi * 0.7,
          false,
          paint
            ..color = _white
            ..style = PaintingStyle.stroke
            ..strokeWidth = h * 0.05,
        );
        paint.style = PaintingStyle.fill;
      case 'en':
        // The Union flag, simplified for a few pixels.
        rect(0, 0, w, h, _navy);
        final diagonal = Paint()
          ..color = _white
          ..strokeWidth = h * 0.2;
        canvas.drawLine(Offset.zero, Offset(w, h), diagonal);
        canvas.drawLine(Offset(w, 0), Offset(0, h), diagonal);
        diagonal
          ..color = _red
          ..strokeWidth = h * 0.07;
        canvas.drawLine(Offset.zero, Offset(w, h), diagonal);
        canvas.drawLine(Offset(w, 0), Offset(0, h), diagonal);
        rect(w * 0.42, 0, w * 0.16, h, _white);
        rect(0, h * 0.36, w, h * 0.28, _white);
        rect(w * 0.45, 0, w * 0.1, h, _red);
        rect(0, h * 0.4, w, h * 0.2, _red);
    }
  }

  @override
  bool shouldRepaint(_FlagPainter old) => old.code != code;
}
