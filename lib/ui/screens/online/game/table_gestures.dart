import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../../online/reactions.dart';
import 'noir_ui.dart';

/// Un gesto disegnato a mano, nello stile del tavolo: inchiostro scuro,
/// ottone, carta e sangue. [t] è il tempo che gira (fumo, brace, monete);
/// [land] va da 0 a 1 quando il gesto arriva al posto (la scena d'arrivo).
class GestureArt extends CustomPainter {
  final TableGesture gesture;
  final double t;
  final double land;

  const GestureArt(this.gesture, {this.t = 0, this.land = 0});

  static const _ink = Color(0xFF120C08);
  static const _cream = Color(0xFFF3E9D2);
  static const _ember = Color(0xFFFF8A2A);
  static const _steel = Color(0xFF3A3D44);
  static const _leaf = Color(0xFF3E7A3A);
  static const _skin = Color(0xFFE2B48C);
  static const _amber = Color(0xFFC8781E);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(s);
    paintUnit(canvas, gesture, t: t, land: land);
    canvas.restore();
  }

  /// Disegna [gesture] in un quadrato unitario centrato sull'origine.
  static void paintUnit(Canvas canvas, TableGesture gesture, {double t = 0, double land = 0}) {
    switch (gesture) {
      case TableGesture.cigar:
        _cigar(canvas, t);
      case TableGesture.toast:
        _toast(canvas, t, land);
      case TableGesture.hatTip:
        _hat(canvas, t);
      case TableGesture.omerta:
        _omerta(canvas, t);
      case TableGesture.eye:
        _eye(canvas, t);
      case TableGesture.coin:
        _coin(canvas, t);
      case TableGesture.fish:
        _fish(canvas, t);
      case TableGesture.gun:
        _gun(canvas, t);
      case TableGesture.cash:
        _cash(canvas, t, land);
      case TableGesture.rose:
        _rose(canvas, t, land);
      case TableGesture.kiss:
        _kiss(canvas, t);
      case TableGesture.horse:
        _horse(canvas, t, land);
      case TableGesture.tommy:
        _tommy(canvas, t, land);
    }
  }

  static Paint _fill(Color c) => Paint()..color = c;
  static Paint _line(Color c, double w) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  static void _shadow(Canvas canvas, Path path) =>
      canvas.drawShadow(path, Colors.black, 0.03, false);

  static void _smoke(Canvas canvas, Offset from, double t, {double scale = 1}) {
    for (var i = 0; i < 3; i++) {
      final k = (t + i / 3) % 1;
      final p = Path()..moveTo(from.dx, from.dy);
      for (var j = 1; j <= 6; j++) {
        final y = from.dy - j * 0.045 * scale - k * 0.12 * scale;
        final x = from.dx + sin(j * 1.3 + t * 2 * pi + i) * 0.03 * scale * (j / 6) + j * 0.008;
        p.lineTo(x, y);
      }
      canvas.drawPath(p, _line(Colors.white.withValues(alpha: 0.38 * (1 - k)), 0.022 * scale));
    }
  }

  static void _cigar(Canvas canvas, double t) {
    canvas.save();
    canvas.rotate(-0.42);
    final body = RRect.fromRectAndRadius(const Rect.fromLTWH(-0.36, -0.07, 0.68, 0.14), const Radius.circular(0.07));
    _shadow(canvas, Path()..addRRect(body));
    canvas.drawRRect(body, _fill(const Color(0xFF7A4423)));
    canvas.drawRRect(body, _line(_ink, 0.02));
    for (var i = 0; i < 4; i++) {
      canvas.drawLine(Offset(-0.28 + i * 0.14, -0.05), Offset(-0.24 + i * 0.14, 0.05), _line(const Color(0xFF5A3018), 0.012));
    }
    canvas.drawRect(const Rect.fromLTWH(-0.2, -0.072, 0.1, 0.144), _fill(Saloon.brass));
    canvas.drawRect(const Rect.fromLTWH(-0.17, -0.03, 0.04, 0.06), _fill(Saloon.enamel));
    final glow = 0.75 + 0.25 * sin(t * 2 * pi * 3);
    canvas.drawCircle(const Offset(0.33, 0), 0.09 * glow, _fill(_ember.withValues(alpha: 0.35)));
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(0.29, -0.065, 0.06, 0.13), const Radius.circular(0.03)),
      _fill(Color.lerp(const Color(0xFF9A2A10), _ember, glow)!),
    );
    canvas.restore();
    _smoke(canvas, const Offset(0.27, -0.16), t);
  }

  static void _toast(Canvas canvas, double t, double land) {
    canvas.save();
    canvas.rotate(-0.18 + 0.06 * sin(t * 2 * pi));
    final glass = Path()
      ..moveTo(-0.2, -0.24)
      ..lineTo(0.2, -0.24)
      ..lineTo(0.16, 0.26)
      ..lineTo(-0.16, 0.26)
      ..close();
    _shadow(canvas, glass);
    canvas.drawPath(glass, _fill(Colors.white.withValues(alpha: 0.18)));
    final whiskey = Path()
      ..moveTo(-0.185, -0.04)
      ..lineTo(0.185, -0.08)
      ..lineTo(0.16, 0.24)
      ..lineTo(-0.16, 0.24)
      ..close();
    canvas.drawPath(whiskey, _fill(_amber.withValues(alpha: 0.9)));
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-0.08, -0.12, 0.13, 0.12), const Radius.circular(0.02)),
        _fill(Colors.white.withValues(alpha: 0.55)));
    canvas.drawPath(glass, _line(_cream, 0.022));
    canvas.drawLine(const Offset(-0.15, 0.2), const Offset(0.15, 0.2), _line(_cream.withValues(alpha: 0.6), 0.016));
    canvas.drawLine(const Offset(0.12, -0.2), const Offset(0.1, 0.1), _line(Colors.white.withValues(alpha: 0.5), 0.02));
    canvas.restore();
    if (land > 0) _sparkle(canvas, const Offset(0.24, -0.3), land);
  }

  static void _sparkle(Canvas canvas, Offset at, double k) {
    final a = (1 - k).clamp(0.0, 1.0);
    final r = 0.06 + 0.14 * k;
    for (var i = 0; i < 8; i++) {
      final d = Offset(cos(i * pi / 4), sin(i * pi / 4));
      canvas.drawLine(at + d * r * 0.5, at + d * r, _line(Saloon.brass.withValues(alpha: a), 0.025));
    }
  }

  static void _hat(Canvas canvas, double t) {
    canvas.save();
    final lift = max(0.0, sin(t * 2 * pi));
    canvas.translate(0, 0.08 - lift * 0.08);
    canvas.rotate(-0.25 * lift);
    final brim = Rect.fromCenter(center: const Offset(0, 0.1), width: 0.82, height: 0.2);
    _shadow(canvas, Path()..addOval(brim));
    canvas.drawOval(brim, _fill(const Color(0xFF26201C)));
    final crown = Path()
      ..moveTo(-0.26, 0.1)
      ..cubicTo(-0.3, -0.12, -0.24, -0.26, -0.08, -0.24)
      ..quadraticBezierTo(0, -0.16, 0.08, -0.24)
      ..cubicTo(0.24, -0.26, 0.3, -0.12, 0.26, 0.1)
      ..close();
    canvas.drawPath(crown, _fill(const Color(0xFF332A24)));
    canvas.drawRect(const Rect.fromLTRB(-0.27, 0.0, 0.27, 0.08), _fill(Saloon.enamelDeep));
    canvas.drawLine(const Offset(-0.27, 0.0), const Offset(0.27, 0.0), _line(Saloon.brass.withValues(alpha: 0.7), 0.012));
    canvas.drawPath(crown, _line(_ink, 0.02));
    canvas.drawOval(brim, _line(_ink, 0.02));
    canvas.restore();
  }

  static void _omerta(Canvas canvas, double t) {
    final lips = Path()
      ..moveTo(-0.3, 0.06)
      ..cubicTo(-0.18, -0.08, -0.08, -0.06, 0, -0.02)
      ..cubicTo(0.08, -0.06, 0.18, -0.08, 0.3, 0.06)
      ..cubicTo(0.16, 0.22, -0.16, 0.22, -0.3, 0.06)
      ..close();
    _shadow(canvas, lips);
    canvas.drawPath(lips, _fill(Saloon.enamel));
    canvas.drawLine(const Offset(-0.26, 0.06), const Offset(0.26, 0.06), _line(Saloon.enamelDeep, 0.02));
    canvas.drawPath(lips, _line(_ink, 0.02));
    final finger = RRect.fromRectAndRadius(const Rect.fromLTWH(-0.065, -0.34, 0.13, 0.5), const Radius.circular(0.065));
    _shadow(canvas, Path()..addRRect(finger));
    canvas.drawRRect(finger, _fill(_skin));
    canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(-0.04, -0.32, 0.08, 0.09), const Radius.circular(0.03)), _fill(_cream));
    canvas.drawRRect(finger, _line(_ink, 0.02));
    final k = (t * 2) % 1;
    for (final side in [-1.0, 1.0]) {
      for (var i = 0; i < 2; i++) {
        final r = 0.12 + i * 0.07 + k * 0.04;
        canvas.drawArc(Rect.fromCircle(center: Offset(side * 0.32, -0.16), radius: r * 0.6), side > 0 ? -0.6 : pi - 0.6 + 0.0,
            1.2, false, _line(_cream.withValues(alpha: 0.7 * (1 - k)), 0.018));
      }
    }
  }

  static void _eye(Canvas canvas, double t) {
    final blink = (t % 1) > 0.9 ? sin(((t % 1) - 0.9) / 0.1 * pi) : 0.0;
    final h = 0.22 * (1 - blink * 0.92);
    final eye = Path()
      ..moveTo(-0.4, 0)
      ..quadraticBezierTo(0, -h * 2, 0.4, 0)
      ..quadraticBezierTo(0, h * 2, -0.4, 0)
      ..close();
    for (var i = 0; i < 7; i++) {
      final a = -pi / 2 + (i - 3) * 0.32;
      canvas.drawLine(Offset(cos(a) * 0.36, sin(a) * 0.36 - 0.02), Offset(cos(a) * 0.46, sin(a) * 0.46 - 0.02),
          _line(Saloon.brass.withValues(alpha: 0.75), 0.02));
    }
    _shadow(canvas, eye);
    canvas.drawPath(eye, _fill(_cream));
    canvas.save();
    canvas.clipPath(eye);
    final look = Offset(sin(t * 2 * pi) * 0.06, 0);
    canvas.drawCircle(look, 0.15, _fill(Saloon.brassDeep));
    canvas.drawCircle(look, 0.11, _fill(Saloon.brass));
    canvas.drawCircle(look, 0.06, _fill(_ink));
    canvas.drawCircle(look + const Offset(-0.035, -0.04), 0.022, _fill(Colors.white));
    canvas.restore();
    canvas.drawPath(eye, _line(_ink, 0.026));
  }

  static void _coin(Canvas canvas, double t) {
    final turn = cos(t * 2 * pi * 2);
    canvas.save();
    canvas.translate(0, -0.06 * sin(t * 2 * pi).abs());
    canvas.scale(max(0.08, turn.abs()), 1);
    final face = turn >= 0;
    _shadow(canvas, Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: 0.34)));
    canvas.drawCircle(Offset.zero, 0.34, _fill(Saloon.brassDeep));
    canvas.drawCircle(Offset.zero, 0.3, _fill(face ? Saloon.brass : const Color(0xFFC9A04A)));
    canvas.drawCircle(Offset.zero, 0.25, _line(Saloon.brassDeep, 0.016));
    if (face) {
      final star = Path();
      for (var i = 0; i < 10; i++) {
        final r = i.isEven ? 0.16 : 0.07;
        final a = -pi / 2 + i * pi / 5;
        final p = Offset(cos(a) * r, sin(a) * r);
        i == 0 ? star.moveTo(p.dx, p.dy) : star.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(star..close(), _fill(Saloon.brassDeep));
    } else {
      canvas.drawCircle(Offset.zero, 0.12, _line(Saloon.brassDeep, 0.035));
      canvas.drawLine(const Offset(0, -0.12), const Offset(0, 0.12), _line(Saloon.brassDeep, 0.03));
    }
    canvas.drawCircle(Offset.zero, 0.34, _line(_ink, 0.02));
    canvas.restore();
  }

  static void _fish(Canvas canvas, double t) {
    canvas.save();
    canvas.rotate(-0.3 + 0.05 * sin(t * 2 * pi * 2));
    // La coda e la testa che escono dal giornale.
    final tail = Path()
      ..moveTo(0.26, 0)
      ..lineTo(0.44, -0.12)
      ..lineTo(0.4, 0)
      ..lineTo(0.44, 0.12)
      ..close();
    canvas.drawPath(tail, _fill(const Color(0xFF8AA6B8)));
    canvas.drawPath(tail, _line(_ink, 0.018));
    final head = Path()
      ..moveTo(-0.22, -0.1)
      ..quadraticBezierTo(-0.44, -0.06, -0.44, 0)
      ..quadraticBezierTo(-0.44, 0.06, -0.22, 0.1)
      ..close();
    canvas.drawPath(head, _fill(const Color(0xFFA9C2D2)));
    canvas.drawPath(head, _line(_ink, 0.018));
    canvas.drawCircle(const Offset(-0.34, -0.02), 0.026, _fill(_ink));
    canvas.drawLine(const Offset(-0.33, -0.03), const Offset(-0.36, 0.0), _line(Colors.white, 0.008));
    // Il giornale arrotolato.
    final paper = Path()
      ..moveTo(-0.26, -0.16)
      ..lineTo(0.3, -0.12)
      ..lineTo(0.3, 0.12)
      ..lineTo(-0.26, 0.16)
      ..close();
    _shadow(canvas, paper);
    canvas.drawPath(paper, _fill(Saloon.paper));
    for (var i = 0; i < 4; i++) {
      final y = -0.09 + i * 0.055;
      canvas.drawLine(Offset(-0.18, y), Offset(0.22, y * 0.85), _line(Saloon.paperInk.withValues(alpha: 0.45), 0.016));
    }
    canvas.drawRect(const Rect.fromLTWH(-0.2, -0.13, 0.16, 0.05), _fill(Saloon.paperInk.withValues(alpha: 0.7)));
    canvas.drawPath(paper, _line(_ink, 0.02));
    canvas.drawLine(const Offset(0.0, -0.14), const Offset(0.0, 0.14), _line(const Color(0xFF8C6A3A), 0.022));
    canvas.restore();
  }

  static void _revolver(Canvas canvas, {Color body = _steel}) {
    final gun = Path()
      ..moveTo(-0.08, -0.12)
      ..lineTo(0.4, -0.12)
      ..lineTo(0.4, -0.04)
      ..lineTo(0.06, -0.04)
      ..lineTo(0.04, 0.0)
      ..lineTo(-0.06, 0.0)
      ..lineTo(-0.12, 0.26)
      ..lineTo(-0.28, 0.26)
      ..lineTo(-0.2, -0.04)
      ..lineTo(-0.22, -0.1)
      ..close();
    _shadow(canvas, gun);
    canvas.drawPath(gun, _fill(body));
    canvas.drawPath(
        Path()
          ..moveTo(-0.11, 0.04)
          ..lineTo(-0.15, 0.24)
          ..lineTo(-0.25, 0.24)
          ..lineTo(-0.19, 0.0)
          ..close(),
        _fill(const Color(0xFF6A3A1E)));
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-0.08, -0.15, 0.16, 0.13), const Radius.circular(0.03)),
        _fill(const Color(0xFF4C5058)));
    canvas.drawArc(const Rect.fromLTWH(-0.06, -0.02, 0.1, 0.1), 0, pi, false, _line(_ink, 0.02));
    canvas.drawPath(gun, _line(_ink, 0.02));
  }

  static void _gun(Canvas canvas, double t) {
    canvas.save();
    canvas.rotate(-0.2);
    _revolver(canvas);
    canvas.restore();
    _smoke(canvas, const Offset(0.38, -0.2), t, scale: 1.2);
  }

  static void _bill(Canvas canvas, Offset at, double angle, double alpha) {
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(angle);
    final r = Rect.fromCenter(center: Offset.zero, width: 0.22, height: 0.11);
    canvas.drawRect(r, _fill(const Color(0xFF6E9A5E).withValues(alpha: alpha)));
    canvas.drawRect(r.deflate(0.015), _line(const Color(0xFF2E4A26).withValues(alpha: alpha), 0.008));
    canvas.drawCircle(Offset.zero, 0.025, _fill(const Color(0xFF2E4A26).withValues(alpha: alpha)));
    canvas.restore();
  }

  static void _cash(Canvas canvas, double t, double land) {
    for (var i = 0; i < 3; i++) {
      _bill(canvas, Offset(-0.12 + i * 0.12, -0.17 - i * 0.015), -0.3 + i * 0.3, 1);
    }
    final lid = RRect.fromRectAndRadius(const Rect.fromLTWH(-0.36, -0.14, 0.72, 0.4), const Radius.circular(0.05));
    _shadow(canvas, Path()..addRRect(lid));
    canvas.drawRRect(lid, _fill(const Color(0xFF5A3420)));
    canvas.drawRRect(lid.deflate(0.03), _line(const Color(0xFF7C4C2E), 0.014));
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-0.1, -0.22, 0.2, 0.1), const Radius.circular(0.04)),
        _line(const Color(0xFF3A2014), 0.035));
    for (final x in [-0.22, 0.16]) {
      canvas.drawRect(Rect.fromLTWH(x, -0.15, 0.06, 0.07), _fill(Saloon.brass));
    }
    canvas.drawRRect(lid, _line(_ink, 0.02));
    if (land > 0) {
      for (var i = 0; i < 6; i++) {
        final k = land;
        final a = -pi / 2 + (i - 2.5) * 0.45;
        final p = Offset(cos(a) * 0.5 * k, sin(a) * 0.45 * k + k * k * 0.5);
        _bill(canvas, p, i * 0.9 + k * 4, (1 - k).clamp(0.0, 1.0));
      }
    }
  }

  static void _petal(Canvas canvas, Offset at, double angle, double alpha) {
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(angle);
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 0.07, height: 0.045), _fill(Saloon.enamel.withValues(alpha: alpha)));
    canvas.restore();
  }

  static void _rose(Canvas canvas, double t, double land) {
    final coffin = Path()
      ..moveTo(-0.14, -0.4)
      ..lineTo(0.14, -0.4)
      ..lineTo(0.24, -0.18)
      ..lineTo(0.14, 0.4)
      ..lineTo(-0.14, 0.4)
      ..lineTo(-0.24, -0.18)
      ..close();
    _shadow(canvas, coffin);
    canvas.drawPath(coffin, _fill(const Color(0xFF3A2216)));
    canvas.drawPath(coffin, _line(_ink, 0.02));
    canvas.drawLine(const Offset(0, -0.28), const Offset(0, -0.08), _line(Saloon.brass.withValues(alpha: 0.8), 0.02));
    canvas.drawLine(const Offset(-0.07, -0.21), const Offset(0.07, -0.21), _line(Saloon.brass.withValues(alpha: 0.8), 0.02));
    canvas.save();
    canvas.rotate(0.55);
    canvas.drawLine(const Offset(0, 0.02), const Offset(0, 0.36), _line(_leaf, 0.028));
    canvas.drawOval(Rect.fromCenter(center: const Offset(0.06, 0.2), width: 0.1, height: 0.05), _fill(_leaf));
    final sway = 0.04 * sin(t * 2 * pi);
    canvas.drawCircle(Offset(sway * 0.1, 0), 0.1, _fill(Saloon.enamelDeep));
    canvas.drawCircle(Offset(sway * 0.1, -0.01), 0.075, _fill(Saloon.enamel));
    canvas.drawArc(Rect.fromCircle(center: const Offset(0, -0.01), radius: 0.045), 0.2, 4.2, false, _line(Saloon.enamelDeep, 0.016));
    canvas.restore();
    if (land > 0) {
      for (var i = 0; i < 5; i++) {
        final p = Offset(-0.25 + i * 0.13 + sin(land * 6 + i) * 0.05, -0.3 + land * 0.6 + (i % 2) * 0.08);
        _petal(canvas, p, land * 5 + i, (1 - land).clamp(0.0, 1.0));
      }
    }
  }

  static void _kiss(Canvas canvas, double t) {
    canvas.save();
    canvas.translate(0.06, -0.04);
    final hand = Path()
      ..moveTo(-0.42, 0.18)
      ..lineTo(-0.12, 0.12)
      ..cubicTo(0.0, 0.1, 0.1, 0.04, 0.32, 0.02)
      ..quadraticBezierTo(0.38, 0.06, 0.32, 0.1)
      ..lineTo(0.12, 0.14)
      ..quadraticBezierTo(0.3, 0.16, 0.3, 0.2)
      ..quadraticBezierTo(0.28, 0.25, 0.1, 0.24)
      ..cubicTo(-0.04, 0.3, -0.2, 0.32, -0.42, 0.34)
      ..close();
    _shadow(canvas, hand);
    canvas.drawPath(hand, _fill(_skin));
    canvas.drawPath(hand, _line(_ink, 0.02));
    canvas.drawRect(const Rect.fromLTRB(-0.46, 0.14, -0.38, 0.38), _fill(_cream));
    canvas.drawRect(const Rect.fromLTRB(-0.5, 0.12, -0.44, 0.4), _fill(const Color(0xFF26201C)));
    canvas.drawOval(Rect.fromCenter(center: const Offset(0.16, 0.08), width: 0.07, height: 0.12), _fill(Saloon.brass));
    final shine = 0.5 + 0.5 * sin(t * 2 * pi * 2);
    canvas.drawCircle(const Offset(0.16, 0.05), 0.035, _fill(Color.lerp(Saloon.enamelDeep, Saloon.blood, shine)!));
    // Il bacio, stampato sopra.
    canvas.save();
    canvas.translate(0.0, -0.18);
    canvas.rotate(-0.2);
    canvas.scale(1.5);
    for (final dir in [-1.0, 1.0]) {
      canvas.drawPath(
          Path()
            ..moveTo(-0.13, 0)
            ..quadraticBezierTo(0, dir * 0.12, 0.13, 0)
            ..quadraticBezierTo(0, dir * 0.04, -0.13, 0),
          _fill(Saloon.enamel.withValues(alpha: 0.9)));
    }
    canvas.restore();
    canvas.restore();
  }

  static void _horse(Canvas canvas, double t, double land) {
    // La testa spunta dal lenzuolo all'arrivo, con un sobbalzo.
    final rise = land <= 0 ? 1.0 : Curves.easeOutBack.transform((land / 0.35).clamp(0.0, 1.0));
    canvas.save();
    canvas.translate(0, (1 - rise) * 0.45);
    final head = Path()
      ..moveTo(-0.08, 0.36)
      ..lineTo(-0.16, 0.0)
      ..cubicTo(-0.2, -0.16, -0.12, -0.3, 0.0, -0.34)
      ..lineTo(0.04, -0.44)
      ..lineTo(0.08, -0.33)
      ..cubicTo(0.2, -0.3, 0.3, -0.18, 0.36, -0.02)
      ..quadraticBezierTo(0.4, 0.08, 0.3, 0.1)
      ..quadraticBezierTo(0.18, 0.08, 0.12, 0.04)
      ..lineTo(0.16, 0.36)
      ..close();
    _shadow(canvas, head);
    canvas.drawPath(head, _fill(const Color(0xFF5A3A26)));
    final mane = Path()
      ..moveTo(0.0, -0.34)
      ..quadraticBezierTo(-0.24, -0.2, -0.16, 0.2)
      ..lineTo(-0.1, 0.2)
      ..quadraticBezierTo(-0.14, -0.1, 0.04, -0.3)
      ..close();
    canvas.drawPath(mane, _fill(const Color(0xFF241610)));
    canvas.drawCircle(const Offset(0.12, -0.16), 0.03, _fill(_ink));
    canvas.drawCircle(const Offset(0.3, 0.02), 0.016, _fill(_ink));
    canvas.drawPath(head, _line(_ink, 0.02));
    canvas.restore();
    final top = 0.12 + 0.015 * sin(t * 2 * pi * 2);
    final sheet = Path()
      ..moveTo(-0.46, top + 0.04)
      ..quadraticBezierTo(0, top - 0.06, 0.46, top + 0.04)
      ..lineTo(0.48, 0.44)
      ..lineTo(-0.48, 0.44)
      ..close();
    canvas.drawPath(sheet, _fill(_cream));
    for (var i = 0; i < 3; i++) {
      canvas.drawLine(Offset(-0.24 + i * 0.22, top + 0.04), Offset(-0.3 + i * 0.26, 0.42), _line(const Color(0xFFCFC3A8), 0.014));
    }
    canvas.drawPath(sheet, _line(_ink, 0.02));
    if (land > 0.3) {
      final k = (land - 0.3) / 0.7;
      canvas.drawCircle(Offset.zero, 0.3 + 0.25 * k, _line(Saloon.blood.withValues(alpha: 0.6 * (1 - k)), 0.03));
    }
  }

  static void _tommy(Canvas canvas, double t, double land) {
    canvas.save();
    canvas.rotate(-0.15);
    final body = Path()
      ..moveTo(-0.44, -0.04)
      ..lineTo(-0.2, -0.08)
      ..lineTo(0.3, -0.08)
      ..lineTo(0.3, 0.0)
      ..lineTo(-0.2, 0.02)
      ..lineTo(-0.44, 0.1)
      ..close();
    _shadow(canvas, body);
    canvas.drawPath(body, _fill(_steel));
    canvas.drawRect(const Rect.fromLTRB(0.3, -0.065, 0.44, -0.035), _fill(_steel));
    for (var i = 0; i < 4; i++) {
      canvas.drawLine(Offset(0.12 + i * 0.04, -0.08), Offset(0.12 + i * 0.04, 0.0), _line(_ink, 0.012));
    }
    canvas.drawPath(
        Path()
          ..moveTo(-0.44, -0.04)
          ..lineTo(-0.26, -0.06)
          ..lineTo(-0.28, 0.06)
          ..lineTo(-0.44, 0.1)
          ..close(),
        _fill(const Color(0xFF6A3A1E)));
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(0.08, 0.0, 0.06, 0.14), const Radius.circular(0.02)),
        _fill(const Color(0xFF6A3A1E)));
    canvas.drawCircle(const Offset(-0.06, 0.08), 0.1, _fill(const Color(0xFF2A2C31)));
    canvas.drawCircle(const Offset(-0.06, 0.08), 0.1, _line(_ink, 0.018));
    canvas.drawCircle(const Offset(-0.06, 0.08), 0.03, _fill(_steel));
    canvas.drawPath(body, _line(_ink, 0.02));
    final flash = ((t * 12) % 1) < 0.5;
    if (flash) {
      final star = Path();
      for (var i = 0; i < 8; i++) {
        final r = i.isEven ? 0.12 : 0.05;
        final a = i * pi / 4;
        final p = Offset(0.5 + cos(a) * r, -0.05 + sin(a) * r);
        i == 0 ? star.moveTo(p.dx, p.dy) : star.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(star..close(), _fill(const Color(0xFFFFC83A)));
    }
    canvas.restore();
    if (land > 0) {
      // I fori sul posto, uno dopo l'altro, con le crepe.
      const holes = [Offset(-0.3, -0.3), Offset(0.28, -0.22), Offset(-0.18, 0.28), Offset(0.32, 0.3), Offset(0.02, -0.4)];
      for (var i = 0; i < holes.length; i++) {
        if (land < i * 0.1) continue;
        final a = land > 0.8 ? (1 - land) / 0.2 : 1.0;
        final h = holes[i];
        for (var j = 0; j < 5; j++) {
          final d = Offset(cos(j * 1.3 + i), sin(j * 1.3 + i));
          canvas.drawLine(h + d * 0.03, h + d * 0.08, _line(_cream.withValues(alpha: 0.7 * a), 0.01));
        }
        canvas.drawCircle(h, 0.032, _fill(_ink.withValues(alpha: a)));
        canvas.drawCircle(h, 0.032, _line(const Color(0xFF8A7A66).withValues(alpha: a), 0.01));
      }
    }
  }

  @override
  bool shouldRepaint(GestureArt old) => old.gesture != gesture || old.t != t || old.land != land;
}

/// Un gesto in volo da un posto all'altro (gli indici sono quelli del
/// [SaloonTable]).
typedef GestureFlight = ({int id, int from, int to, TableGesture gesture});

/// Lo strato dei gesti sopra il tavolo: ogni gesto nuovo parte dal posto di
/// chi lo lancia, vola ad arco fino al bersaglio e lì fa la sua scena. Con
/// il movimento ridotto compare già sul bersaglio, fermo, e sparisce.
class GestureLayer extends StatefulWidget {
  final List<GestureFlight> flights;
  final List<Offset> centers;
  final Size card;

  const GestureLayer({super.key, required this.flights, required this.centers, required this.card});

  /// Quanto dura il volo, l'arrivo e la scena dei leggendari.
  static const flight = 0.8;
  static const stay = 1.5;
  static const legendaryStay = 2.6;

  static double lengthOf(TableGesture gesture) => flight + (gesture.legendary ? legendaryStay : stay);

  @override
  State<GestureLayer> createState() => _GestureLayerState();
}

class _GestureLayerState extends State<GestureLayer> with SingleTickerProviderStateMixin {
  final Set<int> _seen = {};
  final Map<int, ({GestureFlight flight, double start})> _live = {};
  late final Ticker _ticker = createTicker((elapsed) {
    _now = elapsed.inMicroseconds / 1e6;
    _live.removeWhere((_, f) => _now - f.start > GestureLayer.lengthOf(f.flight.gesture));
    if (_live.isEmpty) _ticker.stop();
    setState(() {});
  });
  double _now = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(GestureLayer old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    for (final flight in widget.flights) {
      if (!_seen.add(flight.id)) continue;
      if (!_ticker.isActive) {
        _now = 0;
        _ticker.start();
      }
      _live[flight.id] = (flight: flight, start: _now);
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return CustomPaint(
      size: Size.infinite,
      painter: _FlightPainter(
        [for (final f in _live.values) (flight: f.flight, age: _now - f.start)],
        widget.centers,
        widget.card,
        still: still,
      ),
    );
  }
}

class _FlightPainter extends CustomPainter {
  final List<({GestureFlight flight, double age})> flights;
  final List<Offset> centers;
  final Size card;
  final bool still;

  _FlightPainter(this.flights, this.centers, this.card, {required this.still});

  @override
  void paint(Canvas canvas, Size size) {
    for (final (:flight, :age) in flights) {
      if (flight.from >= centers.length || flight.to >= centers.length) continue;
      paintFlight(canvas, flight.gesture, centers[flight.from], centers[flight.to], card, age, still: still);
    }
  }

  @override
  bool shouldRepaint(_FlightPainter old) =>
      flights.isNotEmpty || old.flights.isNotEmpty || !listEquals(old.centers, centers) || old.card != card;
}

/// Un gesto all'età [age] (in secondi) del suo viaggio da [from] a [to].
/// Pubblico per le prove e per disegnarne i fotogrammi.
void paintFlight(Canvas canvas, TableGesture gesture, Offset from, Offset to, Size card, double age, {bool still = false}) {
  final total = GestureLayer.lengthOf(gesture);
  final landAt = still ? 0.0 : GestureLayer.flight;
  final target = to - Offset(0, card.height * 0.12);
  final side = card.width * (gesture.legendary ? 0.95 : 0.7);
  Offset at;
  double scale;
  double spin = 0;
  double land = 0;
  if (age < landAt) {
    final k = Curves.easeInOutCubic.transform(age / landAt);
    final lift = Offset(0, -((to - from).distance * 0.35 + card.height * 0.3));
    final control = Offset.lerp(from, target, 0.5)! + lift;
    at = Offset(
      (1 - k) * (1 - k) * from.dx + 2 * (1 - k) * k * control.dx + k * k * target.dx,
      (1 - k) * (1 - k) * from.dy + 2 * (1 - k) * k * control.dy + k * k * target.dy,
    );
    scale = 0.55 + 0.45 * sin(k * pi / 2) + 0.25 * sin(k * pi);
    spin = (1 - k) * (gesture == TableGesture.coin ? 0 : -0.6);
  } else {
    at = target;
    final k = ((age - landAt) / 0.22).clamp(0.0, 1.0);
    scale = still ? 1.0 : 1.0 + 0.25 * sin(k * pi);
    land = still ? 0.0 : ((age - landAt) / (total - landAt)).clamp(0.0, 1.0);
  }
  final fade = still
      ? (age < 0.2 ? age / 0.2 : (total - age) / 0.4)
      : (total - age) / 0.35;
  final alpha = fade.clamp(0.0, 1.0);
  if (alpha <= 0) return;
  if (land > 0) {
    // L'arrivo: un anello d'ottone che si allarga sul posto.
    final k = (land * 3).clamp(0.0, 1.0);
    canvas.drawCircle(
      target,
      side * (0.35 + 0.4 * k),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * (1 - k)
        ..color = Saloon.brass.withValues(alpha: 0.8 * (1 - k) * alpha),
    );
  }
  canvas.saveLayer(Rect.fromCircle(center: at, radius: side * 1.6), Paint()..color = Colors.white.withValues(alpha: alpha));
  canvas.translate(at.dx, at.dy);
  canvas.rotate(spin);
  canvas.scale(side * scale);
  // L'ombra sul panno: il gesto è sollevato quando vola.
  canvas.drawOval(
    Rect.fromCenter(center: const Offset(0.04, 0.42), width: 0.7, height: 0.14),
    Paint()
      ..color = Colors.black.withValues(alpha: 0.28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.04),
  );
  GestureArt.paintUnit(canvas, gesture, t: still ? 0 : age / 1.6, land: land);
  canvas.restore();
}
