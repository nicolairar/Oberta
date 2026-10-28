import 'dart:math';

import 'package:flutter/material.dart';

/// La sagoma dell'uomo col soprabito e il cappello: la stessa nel vicolo,
/// dove fuma sotto il lampione, e per strada, quando cammina verso una porta.
/// Si disegna con l'origine tra i piedi, rivolto a destra, alto [h].
abstract final class NoirSmoker {
  /// Un arto: più largo all'attaccatura, più stretto in fondo.
  static void limb(Canvas canvas, Offset from, Offset to, double fromRadius, double toRadius, Paint paint) {
    final delta = to - from;
    final length = delta.distance;
    canvas.drawCircle(from, fromRadius, paint);
    canvas.drawCircle(to, toRadius, paint);
    if (length < 0.01) return;
    final side = Offset(-delta.dy, delta.dx) / length;
    canvas.drawPath(
      Path()
        ..moveTo(from.dx + side.dx * fromRadius, from.dy + side.dy * fromRadius)
        ..lineTo(to.dx + side.dx * toRadius, to.dy + side.dy * toRadius)
        ..lineTo(to.dx - side.dx * toRadius, to.dy - side.dy * toRadius)
        ..lineTo(from.dx - side.dx * fromRadius, from.dy - side.dy * fromRadius)
        ..close(),
      paint,
    );
  }

  /// Dove si piega un arto di due pezzi teso tra [from] e [to]: delle due
  /// pieghe possibili sceglie quella più in basso (gomito) o più avanti
  /// (ginocchio).
  static Offset joint(Offset from, Offset to, double upper, double lower, {required bool low}) {
    final delta = to - from;
    final length = max(delta.distance, 0.001);
    final reach = min(length, upper + lower - 0.001);
    final along = delta / length;
    final base = (upper * upper - lower * lower + reach * reach) / (2 * reach);
    final rise = sqrt(max(0.0, upper * upper - base * base));
    final middle = from + along * base;
    final side = Offset(along.dy, -along.dx);
    final a = middle + side * rise;
    final b = middle - side * rise;
    if (low) return a.dy > b.dy ? a : b;
    return a.dx > b.dx ? a : b;
  }

  /// L'anca, rispetto ai piedi.
  static Offset hip(double h) => Offset(0, -h * 0.50);

  /// Dove sta la mano della sigaretta quando è giù, lungo il fianco.
  static Offset handDown(double h) => hip(h) + Offset(h * 0.170, -h * 0.200);

  /// Le labbra, dove va la sigaretta.
  static Offset lips(double h) => hip(h) + Offset(h * 0.112, -h * 0.432);

  /// Il corpo intero in un colore solo. [hand] è la mano della sigaretta;
  /// i piedi e la mano dietro (in tasca, se null) si muovono quando cammina.
  static void body(
    Canvas canvas,
    double h,
    Paint paint, {
    required Offset hand,
    Offset? backFoot,
    Offset? frontFoot,
    Offset? backHand,
  }) {
    final hip = NoirSmoker.hip(h);
    void leg(Offset foot) {
      final knee = joint(hip, foot, h * 0.265, h * 0.265, low: false);
      limb(canvas, hip, knee, h * 0.058, h * 0.046, paint);
      limb(canvas, knee, foot.translate(0, -h * 0.03), h * 0.046, h * 0.034, paint);
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTRB(foot.dx - h * 0.04, foot.dy - h * 0.048, foot.dx + h * 0.115, foot.dy),
          topLeft: Radius.circular(h * 0.02),
          topRight: Radius.circular(h * 0.045),
          bottomRight: Radius.circular(h * 0.012),
        ),
        paint,
      );
    }

    leg(backFoot ?? Offset(-h * 0.06, 0));
    leg(frontFoot ?? Offset(h * 0.085, 0));

    canvas.save();
    canvas.translate(hip.dx, hip.dy);
    // Il braccio dietro, con la mano in tasca (o che dondola, se cammina).
    final back = Offset(-h * 0.035, -h * 0.325);
    if (backHand == null) {
      final elbow = back + Offset(-h * 0.075, h * 0.165);
      limb(canvas, back, elbow, h * 0.046, h * 0.038, paint);
      limb(canvas, elbow, Offset(h * 0.005, -h * 0.045), h * 0.038, h * 0.032, paint);
    } else {
      final elbow = joint(back, backHand, h * 0.17, h * 0.16, low: true);
      limb(canvas, back, elbow, h * 0.046, h * 0.038, paint);
      limb(canvas, elbow, backHand, h * 0.038, h * 0.032, paint);
    }

    // Il soprabito: spalle larghe, vita segnata, la falda che si apre dietro.
    canvas.drawPath(
      Path()
        ..moveTo(-h * 0.145, -h * 0.335)
        ..quadraticBezierTo(-h * 0.10, -h * 0.385, 0, -h * 0.385)
        ..quadraticBezierTo(h * 0.11, -h * 0.385, h * 0.135, -h * 0.325)
        ..quadraticBezierTo(h * 0.16, -h * 0.20, h * 0.11, -h * 0.085)
        ..quadraticBezierTo(h * 0.13, h * 0.08, h * 0.165, h * 0.215)
        ..lineTo(-h * 0.205, h * 0.215)
        ..quadraticBezierTo(-h * 0.15, h * 0.04, -h * 0.115, -h * 0.085)
        ..quadraticBezierTo(-h * 0.17, -h * 0.22, -h * 0.145, -h * 0.335)
        ..close(),
      paint,
    );
    // Il bavero alzato, la testa di profilo, il cappello calato.
    canvas.drawPath(
      Path()
        ..moveTo(-h * 0.07, -h * 0.375)
        ..lineTo(-h * 0.055, -h * 0.435)
        ..lineTo(h * 0.01, -h * 0.385)
        ..lineTo(h * 0.085, -h * 0.425)
        ..lineTo(h * 0.075, -h * 0.365)
        ..close(),
      paint,
    );
    final head = Offset(h * 0.03, -h * 0.485);
    canvas.drawOval(Rect.fromCenter(center: head, width: h * 0.150, height: h * 0.172), paint);
    canvas.drawPath(
      Path()
        ..moveTo(head.dx + h * 0.060, head.dy - h * 0.030)
        ..lineTo(head.dx + h * 0.102, head.dy + h * 0.022)
        ..lineTo(head.dx + h * 0.074, head.dy + h * 0.032)
        ..lineTo(head.dx + h * 0.080, head.dy + h * 0.062)
        ..quadraticBezierTo(head.dx + h * 0.065, head.dy + h * 0.105, head.dx + h * 0.010, head.dy + h * 0.095)
        ..lineTo(head.dx, head.dy)
        ..close(),
      paint,
    );
    canvas.save();
    canvas.translate(head.dx + h * 0.025, head.dy - h * 0.046);
    canvas.rotate(0.16);
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: h * 0.36, height: h * 0.05), paint);
    canvas.restore();
    canvas.drawPath(
      Path()
        ..moveTo(head.dx - h * 0.082, head.dy - h * 0.050)
        ..quadraticBezierTo(head.dx - h * 0.090, head.dy - h * 0.160, head.dx - h * 0.040, head.dy - h * 0.160)
        ..quadraticBezierTo(head.dx + h * 0.010, head.dy - h * 0.130, head.dx + h * 0.055, head.dy - h * 0.165)
        ..quadraticBezierTo(head.dx + h * 0.105, head.dy - h * 0.150, head.dx + h * 0.100, head.dy - h * 0.040)
        ..close(),
      paint,
    );
    canvas.restore();

    // Il braccio davanti, che porta la sigaretta alla bocca.
    final shoulder = hip + Offset(h * 0.035, -h * 0.325);
    final bend = joint(shoulder, hand, h * 0.185, h * 0.175, low: true);
    limb(canvas, shoulder, bend, h * 0.046, h * 0.038, paint);
    limb(canvas, bend, hand, h * 0.038, h * 0.030, paint);
    canvas.drawCircle(hand, h * 0.034, paint);
  }

  /// L'uomo che cammina: [phase] è il passo (in radianti), [walk] quanto sta
  /// camminando (0 = fermo), [rim] il filo di luce dietro di lui.
  static void walker(
    Canvas canvas,
    double h, {
    required double phase,
    double walk = 1,
    Color rim = const Color(0xFF9A2226),
    double opacity = 1,
  }) {
    final swing = cos(phase) * walk;
    final lift = h * 0.07 * walk;
    final front = Offset(h * 0.012 + h * 0.13 * swing, -lift * max(0.0, sin(phase)));
    final back = Offset(h * 0.012 - h * 0.13 * swing, -lift * max(0.0, -sin(phase)));
    final bob = -h * 0.012 * walk * cos(2 * phase).abs();
    final hand = handDown(h) + Offset(-h * 0.05 * swing, h * 0.02 * walk);
    final backHand = Offset(h * 0.005 + h * 0.07 * swing, -h * 0.045 + h * 0.02 * walk);
    canvas.save();
    canvas.translate(0, bob);
    void pass(Paint paint) => body(
      canvas,
      h,
      paint,
      hand: hand,
      frontFoot: front.translate(0, -bob),
      backFoot: back.translate(0, -bob),
      backHand: walk > 0 ? backHand : null,
    );
    canvas.save();
    canvas.translate(-h * 0.016, -h * 0.008);
    pass(Paint()..color = rim.withValues(alpha: opacity));
    canvas.restore();
    pass(Paint()..color = const Color(0xFF050506).withValues(alpha: opacity));
    // La sigaretta tra le dita, con la brace.
    final butt = hand + Offset(h * 0.012, -h * 0.022);
    final tip = butt + Offset(h * 0.050, -h * 0.062);
    canvas.drawLine(
      butt,
      tip,
      Paint()
        ..color = const Color(0xFFE9E4D8).withValues(alpha: opacity)
        ..strokeWidth = h * 0.015,
    );
    canvas.drawCircle(tip, h * 0.016, Paint()..color = const Color(0xFFFF8A4B).withValues(alpha: opacity));
    canvas.restore();
  }
}
