import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// L'alfabeto delle insegne di strada: tubi piegati a mano come quelli di
/// OBERTÀ, ma in corsivo e d'un altro colore. OBERTÀ resta il titolo, grande
/// e rosso; queste sono insegne di locale, più piccole, sopra una porta.
abstract final class StreetNeon {
  static const gap = 0.16;
  static const headroom = 0.30;

  /// L'inclinazione del corsivo: la cima delle lettere va avanti di tanto.
  static const slant = 0.22;

  static const _widths = {
    'A': 0.66, 'B': 0.54, 'C': 0.54, 'D': 0.58, 'E': 0.48, 'F': 0.46, 'G': 0.58, 'H': 0.56, 'I': 0.10,
    'J': 0.44, 'K': 0.54, 'L': 0.46, 'M': 0.68, 'N': 0.56, 'O': 0.60, 'P': 0.52, 'Q': 0.60, 'R': 0.56,
    'S': 0.52, 'T': 0.56, 'U': 0.54, 'V': 0.58, 'W': 0.80, 'X': 0.56, 'Y': 0.58, 'Z': 0.52, ' ': 0.34,
  };

  static const _accents = {'À': 'A', 'È': 'E', 'É': 'E', 'Ì': 'I', 'Ò': 'O', 'Ù': 'U'};

  static String _base(String ch) => _accents[ch] ?? (_widths.containsKey(ch) ? ch : ' ');

  static double widthOf(String ch) => _widths[_base(ch)]!;

  /// La larghezza di [text], in altezze di lettera (corsivo e svolazzo compresi).
  static double widthOfText(String text) {
    final letters = text.toUpperCase().characters.toList();
    if (letters.isEmpty) return 0;
    var w = 0.0;
    for (final ch in letters) {
      w += widthOf(ch);
    }
    return w + gap * (letters.length - 1) + slant;
  }

  static double get height => 1 + headroom + 0.22;

  /// I tubi della lettera [ch] alta [cap], con l'angolo in alto a sinistra
  /// delle maiuscole nell'origine (senza corsivo: lo applica chi disegna).
  static Path letter(String ch, double cap) {
    final base = _base(ch);
    final w = _widths[base]!;
    final path = Path();
    void line(List<(double, double)> points) {
      path.moveTo(points.first.$1 * cap, points.first.$2 * cap);
      for (final (x, y) in points.skip(1)) {
        path.lineTo(x * cap, y * cap);
      }
    }

    // Una C (o G) da stadio: due mezze lune unite dai fianchi.
    void hook(double w) {
      final r = w / 2;
      path.arcTo(Rect.fromCircle(center: Offset(r * cap, r * cap), radius: r * cap), -pi / 5, -(pi - pi / 5), true);
      path.lineTo(0, (1 - r) * cap);
      path.arcTo(Rect.fromCircle(center: Offset(r * cap, (1 - r) * cap), radius: r * cap), pi, -(pi - pi / 5), false);
    }

    switch (base) {
      case 'A':
        line([(0, 1), (w / 2, 0), (w, 1)]);
        line([(w * 0.2, 0.64), (w * 0.8, 0.64)]);
      case 'B':
        path
          ..moveTo(0, cap)
          ..lineTo(0, 0)
          ..lineTo(0.28 * cap, 0)
          ..arcToPoint(Offset(0.28 * cap, 0.48 * cap), radius: Radius.circular(0.24 * cap))
          ..lineTo(0, 0.48 * cap)
          ..moveTo(0.28 * cap, 0.48 * cap)
          ..lineTo(0.30 * cap, 0.48 * cap)
          ..arcToPoint(Offset(0.30 * cap, cap), radius: Radius.circular(0.26 * cap))
          ..lineTo(0, cap);
      case 'C':
        hook(w);
      case 'D':
        path
          ..moveTo(0, cap)
          ..lineTo(0, 0)
          ..lineTo(0.08 * cap, 0)
          ..arcToPoint(Offset(0.08 * cap, cap), radius: Radius.circular(0.5 * cap))
          ..lineTo(0, cap);
      case 'E':
        line([(w, 0), (0, 0), (0, 1), (w, 1)]);
        line([(0, 0.5), (w * 0.8, 0.5)]);
      case 'F':
        line([(w, 0), (0, 0), (0, 1)]);
        line([(0, 0.5), (w * 0.82, 0.5)]);
      case 'G':
        hook(w);
        path.lineTo(w * cap, 0.58 * cap);
        path.lineTo(w * 0.52 * cap, 0.58 * cap);
      case 'H':
        line([(0, 0), (0, 1)]);
        line([(w, 0), (w, 1)]);
        line([(0, 0.5), (w, 0.5)]);
      case 'I':
        line([(w / 2, 0), (w / 2, 1)]);
      case 'J':
        path
          ..moveTo(w * cap, 0)
          ..lineTo(w * cap, 0.74 * cap)
          ..arcToPoint(Offset(0, 0.74 * cap), radius: Radius.circular(w / 2 * cap));
      case 'K':
        line([(0, 0), (0, 1)]);
        line([(w, 0), (0, 0.56)]);
        line([(w * 0.3, 0.40), (w, 1)]);
      case 'L':
        line([(0, 0), (0, 1), (w, 1)]);
      case 'M':
        line([(0, 1), (0, 0), (w / 2, 0.58), (w, 0), (w, 1)]);
      case 'N':
        line([(0, 1), (0, 0), (w, 1), (w, 0)]);
      case 'O':
        path.addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w * cap, cap), Radius.circular(w / 2 * cap)));
      case 'P':
        path
          ..moveTo(0, cap)
          ..lineTo(0, 0)
          ..lineTo(0.28 * cap, 0)
          ..arcToPoint(Offset(0.28 * cap, 0.54 * cap), radius: Radius.circular(0.27 * cap))
          ..lineTo(0, 0.54 * cap);
      case 'Q':
        path.addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w * cap, cap), Radius.circular(w / 2 * cap)));
        line([(w * 0.55, 0.72), (w * 1.05, 1.04)]);
      case 'R':
        path
          ..moveTo(0, cap)
          ..lineTo(0, 0)
          ..lineTo(0.30 * cap, 0)
          ..arcToPoint(Offset(0.30 * cap, 0.52 * cap), radius: Radius.circular(0.26 * cap))
          ..lineTo(0, 0.52 * cap);
        line([(0.26, 0.52), (w, 1)]);
      case 'S':
        path
          ..moveTo(w * 0.94 * cap, 0.14 * cap)
          ..cubicTo(w * 0.76 * cap, -0.03 * cap, 0.02 * cap, -0.04 * cap, 0.03 * cap, 0.25 * cap)
          ..cubicTo(0.04 * cap, 0.52 * cap, w * cap, 0.46 * cap, w * cap, 0.74 * cap)
          ..cubicTo(w * cap, 1.03 * cap, 0.12 * cap, 1.05 * cap, 0, 0.86 * cap);
      case 'T':
        line([(0, 0), (w, 0)]);
        line([(w / 2, 0), (w / 2, 1)]);
      case 'U':
        path
          ..moveTo(0, 0)
          ..lineTo(0, 0.72 * cap)
          ..arcToPoint(Offset(w * cap, 0.72 * cap), radius: Radius.circular(w / 2 * cap), clockwise: false)
          ..lineTo(w * cap, 0);
      case 'V':
        line([(0, 0), (w / 2, 1), (w, 0)]);
      case 'W':
        line([(0, 0), (w * 0.24, 1), (w / 2, 0.34), (w * 0.76, 1), (w, 0)]);
      case 'X':
        line([(0, 0), (w, 1)]);
        line([(w, 0), (0, 1)]);
      case 'Y':
        line([(0, 0), (w / 2, 0.5), (w, 0)]);
        line([(w / 2, 0.5), (w / 2, 1)]);
      case 'Z':
        line([(0, 0), (w, 0), (0, 1), (w, 1)]);
    }
    if (_accents.containsKey(ch)) {
      final grave = ch != 'É';
      line(grave ? [(w / 2 - 0.16, -0.30), (w / 2, -0.13)] : [(w / 2 + 0.16, -0.30), (w / 2, -0.13)]);
    }
    return path;
  }
}

/// L'insegna di un posto della strada: telaio di ferro, i tubi in corsivo,
/// uno svolazzo sotto, l'alone colorato sui mattoni. [power] va da 0 (spenta)
/// a 1; sotto 1 i tubi sfarfallano come quando si accendono.
class StreetNeonPainter extends CustomPainter {
  final String text;
  final Color color;
  final double power;

  StreetNeonPainter({required this.text, required this.color, this.power = 1});

  @override
  void paint(Canvas canvas, Size size) {
    final letters = text.toUpperCase().characters.toList();
    if (letters.isEmpty) return;
    final span = StreetNeon.widthOfText(text);
    final cap = min(size.width / span, size.height / StreetNeon.height);
    final width = span * cap;
    final left = (size.width - width) / 2;
    final top = (size.height - StreetNeon.height * cap) / 2 + StreetNeon.headroom * cap;

    final glass = Color.lerp(const Color(0xFF15151C), color, 0.22)!;
    final hot = Color.lerp(color, Colors.white, 0.25)!;
    final core = Color.lerp(color, Colors.white, 0.82)!;

    // L'alone sui mattoni, largo e basso.
    final halo = Rect.fromCenter(
      center: Offset(size.width / 2, top + cap / 2),
      width: width + cap * 2.4,
      height: cap * 3.2,
    );
    canvas.drawOval(
      halo,
      Paint()
        ..shader = RadialGradient(
          colors: [color.withValues(alpha: 0.30 * power), color.withValues(alpha: 0)],
        ).createShader(halo),
    );

    // Il telaio: due binari e i fili che scendono.
    final iron = Paint()..color = const Color(0xFF08080B);
    for (final y in [top + cap * 0.28, top + cap * 0.78]) {
      canvas.drawRect(Rect.fromLTRB(left - cap * 0.12, y - cap * 0.018, left + width + cap * 0.06, y + cap * 0.018), iron);
    }

    final tube = max(1.6, cap * 0.085);
    Paint stroke(double w, Color c) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = c;

    final all = Path();
    var x = left;
    for (final ch in letters) {
      all.addPath(StreetNeon.letter(ch, cap), Offset(x, 0));
      x += (StreetNeon.widthOf(ch) + StreetNeon.gap) * cap;
    }
    // Lo svolazzo del corsivo, sotto le lettere: un tubo solo da un capo all'altro.
    final swash = Path()
      ..moveTo(left - cap * 0.05, cap * 1.16)
      ..quadraticBezierTo(left + width * 0.5, cap * 1.30, left + width - cap * 0.1, cap * 1.08);
    all.addPath(swash, Offset.zero);

    canvas.save();
    canvas.translate(0, top);
    // Il corsivo: le cime vanno avanti, i piedi restano dove sono.
    canvas.transform(Float64List.fromList([1, 0, 0, 0, -StreetNeon.slant, 1, 0, 0, 0, 0, 1, 0, StreetNeon.slant * cap, 0, 0, 1]));
    canvas.drawPath(all, stroke(tube * 1.5, Colors.black.withValues(alpha: 0.5)));
    canvas.drawPath(all, stroke(tube, glass));
    if (power > 0.02) {
      canvas.drawPath(
        all,
        stroke(tube * 3.2, color.withValues(alpha: 0.6 * power))..maskFilter = MaskFilter.blur(BlurStyle.normal, cap * 0.12),
      );
      canvas.drawPath(all, stroke(tube, Color.lerp(glass, hot, power)!));
      canvas.drawPath(all, stroke(tube * 0.4, core.withValues(alpha: min(1, power * 1.1))));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(StreetNeonPainter old) => old.text != text || old.color != color || old.power != power;
}
