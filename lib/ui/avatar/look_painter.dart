import 'dart:math';

import 'package:flutter/material.dart';

import '../widgets/noir_avatar.dart' show AvatarHead;
import 'avatar_look.dart';

/// Quello che si muove in un personaggio fermo al tavolo.
@immutable
class CharacterPose {
  /// Il respiro, da -1 a 1: le spalle salgono e scendono di un filo.
  final double breath;

  /// Dove guarda, da -1 (a sinistra di chi guarda lo schermo) a 1.
  final double glance;

  /// Da 0 (seduto) a 1 (in piedi, con le mani puntate sul tavolo).
  final double rise;

  /// I secondi che passano, per il fumo.
  final double time;

  /// Da dove arriva la luce della lampada, in coordinate dello schermo.
  final Offset light;

  /// Come tiene le mani sul panno (si sceglie dal nome, così ognuno ha il suo).
  final int hands;

  const CharacterPose({
    this.breath = 0,
    this.glance = 0,
    this.rise = 0,
    this.time = 0,
    this.light = const Offset(0, -1),
    this.hands = 0,
  });
}

/// Il pennello dei personaggi: la stessa persona, con quello che indossa,
/// seduta dietro il bordo di un tavolo ([seated]) o in un ritratto a mezzo
/// busto ([bust]). Lo stile è quello dei filmati della notte: sagome scure
/// staccate dal buio da un filo di luce calda, e la lampada che cade dall'alto
/// e lascia gli occhi nell'ombra della tesa.
///
/// Le misure sono in [s], la larghezza delle spalle; l'origine è il punto
/// del bordo del tavolo davanti al petto. In su è negativo.
abstract final class LookPainter {
  static const ink = Color(0xFF07070A);
  static const rim = Color(0xFFC9A066);
  static const gold = Color(0xFFFFD27A);
  static const paper = Color(0xFFF2EAE1);
  static const ember = Color(0xFFFF7A3B);

  /// Una persona seduta col petto contro il bordo in [base]: sotto il bordo
  /// non si vede niente, sopra il panno si posano gli avambracci.
  static void seated(
    Canvas canvas,
    AvatarLook look, {
    required Offset base,
    required double s,
    CharacterPose pose = const CharacterPose(),
    bool lit = false,
    double cut = 0.012,
    bool hands = true,
    bool chair = true,
  }) {
    if (s < 2) return;
    canvas.save();
    canvas.translate(base.dx, base.dy);
    canvas.scale(s);
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(-3, -4, 3, cut));
    if (hands && chair) _chair(canvas, empty: false, lit: lit);
    _figure(canvas, look, pose, lit: lit, hands: hands);
    if (!hands) {
      // Chi sta in piedi dietro sfuma nel buio sotto il petto.
      canvas.drawRect(
        Rect.fromLTRB(-0.7, cut - 0.3, 0.7, cut),
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x00000000), Color(0xE6000000)],
          ).createShader(Rect.fromLTRB(-0.7, cut - 0.3, 0.7, cut)),
      );
    }
    canvas.restore();
    if (hands) _forearms(canvas, look, pose, lit: lit);
    _smoke(canvas, look, pose);
    canvas.restore();
  }

  /// Il posto di chi non c'è più: la sedia vuota, scostata, e un garofano
  /// posato sul bordo del tavolo.
  static void emptyChair(Canvas canvas, {required Offset base, required double s}) {
    if (s < 2) return;
    canvas.save();
    canvas.translate(base.dx, base.dy);
    canvas.scale(s);
    canvas.save();
    canvas.clipRect(const Rect.fromLTRB(-3, -4, 3, 0.012));
    _chair(canvas, empty: true, lit: false);
    canvas.restore();
    carnation(canvas, const Offset(0.16, 0.07), 0.07, angle: -0.6);
    canvas.restore();
  }

  /// Solo la sedia, al suo posto, mentre chi ci siede gira per la sala.
  static void chair(Canvas canvas, {required Offset base, required double s}) {
    if (s < 2) return;
    canvas.save();
    canvas.translate(base.dx, base.dy);
    canvas.scale(s);
    canvas.clipRect(const Rect.fromLTRB(-3, -4, 3, 0.012));
    _chair(canvas, empty: false, lit: false);
    canvas.restore();
  }

  /// Un ritratto a mezzo busto in un quadrato di lato [side], senza fondo:
  /// la testa nel mezzo, le spalle che escono dal basso.
  static void bust(Canvas canvas, AvatarLook look, double side, {CharacterPose pose = const CharacterPose(light: Offset(-0.6, -0.8))}) {
    final s = side * 0.98;
    canvas.save();
    canvas.translate(side * 0.5, side * 0.47 + 0.86 * s);
    canvas.scale(s);
    _figure(canvas, look, pose, lit: false, hands: false);
    canvas.restore();
  }

  static Color _dark(Color c, double t) => Color.lerp(c, ink, t)!;
  static Color _bright(Color c, double t) => Color.lerp(c, const Color(0xFFFFF1D6), t)!;

  static void _chair(Canvas canvas, {required bool empty, required bool lit}) {
    // Uno schienale alto di cuoio, più largo delle spalle: si vede ai lati
    // e, quando la sedia è vuota, tutto intero.
    final back = RRect.fromRectAndCorners(
      const Rect.fromLTRB(-0.6, -0.86, 0.6, 0.2),
      topLeft: const Radius.elliptical(0.34, 0.26),
      topRight: const Radius.elliptical(0.34, 0.26),
    );
    final bounds = back.outerRect;
    canvas.drawRRect(
      back.shift(const Offset(0, -0.018)),
      Paint()..color = (lit ? gold : rim).withValues(alpha: empty ? 0.25 : 0.45),
    );
    canvas.drawRRect(back, Paint()..color = empty ? const Color(0xFF1E1C1B) : const Color(0xFF1C0D08));
    final leather = back.deflate(0.06);
    canvas.drawRRect(
      leather,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: empty
              ? const [Color(0xFF4A4542), Color(0xFF221F1D)]
              : const [Color(0xFF4A1916), Color(0xFF1A0807)],
        ).createShader(bounds),
    );
    // Le trapuntature del capitonné.
    final tuft = Paint()..color = Colors.black.withValues(alpha: 0.4);
    for (var row = 0; row < 3; row++) {
      for (var col = -2; col <= 2; col++) {
        final c = Offset(col * 0.2 + (row.isOdd ? 0.1 : 0), -0.66 + row * 0.2);
        if (!leather.contains(c)) continue;
        canvas.drawCircle(c, 0.018, tuft);
      }
    }
    final stud = Paint()..color = (empty ? const Color(0xFF8A847C) : const Color(0xFFB08E45)).withValues(alpha: 0.6);
    for (var i = 0; i <= 12; i++) {
      final a = pi + i * pi / 12;
      final c = Offset(cos(a) * 0.53, -0.6 + sin(a) * 0.21);
      canvas.drawCircle(c, 0.012, stud);
    }
  }

  /// La persona: busto, collo, testa, capelli, cappello e quello che porta.
  static void _figure(Canvas canvas, AvatarLook look, CharacterPose pose, {required bool lit, required bool hands}) {
    final lift = -0.42 * pose.rise + pose.breath * 0.012;
    final light = pose.light.distance == 0 ? const Offset(0, -1) : pose.light / pose.light.distance;
    final glow = lit ? gold : rim;
    canvas.save();
    canvas.translate(0, lift);

    final broad = look.dame ? 0.86 : 1.0;
    final torso = _torso(broad);
    final head = Rect.fromCenter(center: const Offset(0, -0.86), width: 0.32, height: 0.40);

    // Il filo di luce: la sagoma intera in chiaro, spostata verso la lampada,
    // poi tutto il resto sopra.
    canvas.save();
    canvas.translate(light.dx * 0.03, light.dy * 0.03);
    final halo = Paint()..color = glow.withValues(alpha: lit ? 0.95 : 0.75);
    canvas.drawPath(torso, halo);
    _hairBack(canvas, look, halo);
    canvas.drawOval(head, halo);
    _hat(canvas, look, halo, silhouette: true);
    canvas.restore();

    _hairBack(canvas, look, Paint()..color = _hairColor(look));
    _coat(canvas, look, torso, light);
    _neck(canvas, look);
    _face(canvas, look, head, pose, light);
    _hairFront(canvas, look);
    _glasses(canvas, look, pose);
    _hat(canvas, look, Paint(), silhouette: false);
    if (look.accessory == AvatarAccessory.carnation) carnation(canvas, Offset(0.2 * broad, -0.44), 0.05);
    _mouthProp(canvas, look);
    canvas.restore();
  }

  static Path _torso(double broad) {
    final w = 0.5 * broad;
    return Path()
      ..moveTo(-0.40 * broad, 0.6)
      ..lineTo(-w * 0.9, -0.3)
      ..quadraticBezierTo(-w * 1.02, -0.47, -w * 0.84, -0.555)
      ..quadraticBezierTo(-w * 0.5, -0.63, -0.1, -0.635)
      ..lineTo(0.1, -0.635)
      ..quadraticBezierTo(w * 0.5, -0.63, w * 0.84, -0.555)
      ..quadraticBezierTo(w * 1.02, -0.47, w * 0.9, -0.3)
      ..lineTo(0.40 * broad, 0.6)
      ..close();
  }

  static void _coat(Canvas canvas, AvatarLook look, Path torso, Offset light) {
    final outfit = look.outfit;
    final bounds = torso.getBounds();
    canvas.drawPath(
      torso,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment(-light.dx * 0.6, -1),
          end: Alignment(light.dx * 0.3, 1),
          colors: [_bright(outfit.coat, 0.1), outfit.coat, _dark(outfit.coat, 0.6), _dark(outfit.coat, 0.85)],
          stops: const [0, 0.22, 0.75, 1],
        ).createShader(Rect.fromLTRB(bounds.left, -0.66, bounds.right, 0.05)),
    );
    canvas.save();
    canvas.clipPath(torso);
    final thread = Paint()
      ..color = _bright(outfit.coat, 0.5).withValues(alpha: 0.28)
      ..strokeWidth = 0.008;
    switch (outfit.pattern) {
      case CoatPattern.plain:
        break;
      case CoatPattern.pinstripe:
        for (var x = -0.49; x < 0.5; x += 0.065) {
          canvas.drawLine(Offset(x, -0.7), Offset(x * 0.9, 0.6), thread);
        }
      case CoatPattern.check:
        thread.color = _bright(outfit.coat, 0.4).withValues(alpha: 0.22);
        for (var x = -0.5; x < 0.5; x += 0.09) {
          canvas.drawLine(Offset(x, -0.7), Offset(x, 0.6), thread);
        }
        for (var y = -0.62; y < 0.6; y += 0.09) {
          canvas.drawLine(Offset(-0.6, y), Offset(0.6, y), thread);
        }
      case CoatPattern.doubleBreasted:
        final button = Paint()..color = _bright(outfit.coat, 0.35);
        for (final y in [-0.26, -0.12, 0.02]) {
          canvas.drawCircle(Offset(-0.09, y), 0.016, button);
          canvas.drawCircle(Offset(0.09, y), 0.016, button);
        }
    }
    // Le braccia lungo i fianchi, un po' più scure del petto.
    final sleeve = Paint()
      ..color = _dark(outfit.coat, 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.02;
    canvas.drawLine(const Offset(-0.33, -0.42), const Offset(-0.34, 0.6), sleeve);
    canvas.drawLine(const Offset(0.33, -0.42), const Offset(0.34, 0.6), sleeve);
    // L'ombra del mento sul petto.
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, -0.6), width: 0.42, height: 0.16),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.04),
    );
    canvas.restore();

    if (look.dame) {
      // Uno scollo a V, senza risvolti.
      canvas.drawPath(
        Path()
          ..moveTo(-0.14, -0.62)
          ..lineTo(0.14, -0.62)
          ..lineTo(0, -0.36)
          ..close(),
        Paint()..color = _dark(look.base.skin, 0.35),
      );
      return;
    }
    // La camicia nello scollo della giacca, e i risvolti.
    canvas.drawPath(
      Path()
        ..moveTo(-0.13, -0.625)
        ..lineTo(0.13, -0.625)
        ..lineTo(0, -0.24)
        ..close(),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [outfit.shirt, _dark(outfit.shirt, 0.45)],
        ).createShader(const Rect.fromLTRB(-0.13, -0.63, 0.13, -0.24)),
    );
    final lapel = Paint()..color = _dark(outfit.coat, 0.3);
    final edge = Paint()
      ..color = _bright(outfit.coat, 0.35).withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.012;
    for (final side in [-1.0, 1.0]) {
      final path = Path()
        ..moveTo(side * 0.13, -0.625)
        ..lineTo(side * 0.25, -0.585)
        ..lineTo(side * 0.17, -0.44)
        ..lineTo(side * 0.22, -0.4)
        ..lineTo(side * 0.02, -0.15)
        ..lineTo(0, -0.24)
        ..close();
      canvas.drawPath(path, lapel);
      canvas.drawPath(path, edge);
    }
  }

  static void _neck(Canvas canvas, AvatarLook look) {
    final skin = look.base.skin;
    canvas.drawRect(const Rect.fromLTRB(-0.075, -0.72, 0.075, -0.58), Paint()..color = _dark(skin, 0.62));
    final accent = look.outfit.accent;
    switch (look.accessory) {
      case AvatarAccessory.tie:
        if (look.dame) break;
        final tie = Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_bright(accent, 0.15), _dark(accent, 0.45)],
          ).createShader(const Rect.fromLTRB(-0.06, -0.62, 0.06, -0.2));
        canvas.drawPath(
          Path()
            ..moveTo(-0.035, -0.615)
            ..lineTo(0.035, -0.615)
            ..lineTo(0.025, -0.56)
            ..lineTo(0.055, -0.27)
            ..lineTo(0, -0.22)
            ..lineTo(-0.055, -0.27)
            ..lineTo(-0.025, -0.56)
            ..close(),
          tie,
        );
        canvas.drawLine(
          const Offset(-0.03, -0.56),
          const Offset(0.03, -0.56),
          Paint()
            ..color = _dark(accent, 0.6)
            ..strokeWidth = 0.01,
        );
      case AvatarAccessory.bowTie:
        final bow = Paint()..color = look.outfit.id == 'black_tuxedo' ? ink : _dark(accent, 0.1);
        canvas.drawPath(
          Path()
            ..moveTo(0, -0.585)
            ..lineTo(-0.085, -0.625)
            ..lineTo(-0.085, -0.545)
            ..close()
            ..moveTo(0, -0.585)
            ..lineTo(0.085, -0.625)
            ..lineTo(0.085, -0.545)
            ..close(),
          bow,
        );
        canvas.drawCircle(const Offset(0, -0.585), 0.02, Paint()..color = _dark(accent, 0.4));
      case AvatarAccessory.pearls:
        final pearl = Paint()..color = paper.withValues(alpha: 0.92);
        for (var i = 0; i <= 10; i++) {
          final t = i / 10;
          canvas.drawCircle(Offset(-0.12 + 0.24 * t, -0.6 + 0.07 * sin(pi * t)), 0.014, pearl);
        }
      case AvatarAccessory.scarf:
        canvas.drawPath(
          Path()
            ..moveTo(-0.13, -0.63)
            ..quadraticBezierTo(0, -0.54, 0.13, -0.63)
            ..lineTo(0.06, -0.42)
            ..quadraticBezierTo(0, -0.36, -0.05, -0.43)
            ..close(),
          Paint()
            ..shader = LinearGradient(
              colors: [_bright(accent, 0.3), _dark(accent, 0.3)],
            ).createShader(const Rect.fromLTRB(-0.13, -0.63, 0.13, -0.36)),
        );
      case AvatarAccessory.none ||
          AvatarAccessory.carnation ||
          AvatarAccessory.cigar ||
          AvatarAccessory.cigarette ||
          AvatarAccessory.toothpick:
        // Il colletto aperto della camicia.
        if (look.dame) break;
        final collar = Paint()..color = _dark(look.outfit.shirt, 0.1);
        canvas.drawPath(
          Path()
            ..moveTo(-0.08, -0.64)
            ..lineTo(-0.13, -0.55)
            ..lineTo(-0.02, -0.5)
            ..close()
            ..moveTo(0.08, -0.64)
            ..lineTo(0.13, -0.55)
            ..lineTo(0.02, -0.5)
            ..close(),
          collar,
        );
    }
  }

  static Color _hairColor(AvatarLook look) => switch (look.base.tone) {
    SkinTone.porcelain || SkinTone.rose => const Color(0xFF2A1C14),
    _ => const Color(0xFF0E0B0A),
  };

  static void _hairBack(Canvas canvas, AvatarLook look, Paint paint) {
    switch (look.hat) {
      case AvatarHead.bob || AvatarHead.wideBrim:
        canvas.drawRRect(
          RRect.fromRectAndRadius(const Rect.fromLTRB(-0.215, -1.07, 0.215, -0.68), const Radius.circular(0.15)),
          paint,
        );
      case AvatarHead.bun:
        canvas.drawCircle(const Offset(0, -1.1), 0.075, paint);
      case AvatarHead.fedora || AvatarHead.bowler || AvatarHead.coppola || AvatarHead.slicked:
        break;
    }
  }

  static void _face(Canvas canvas, AvatarLook look, Rect head, CharacterPose pose, Offset light) {
    final skin = look.base.skin;
    // Le orecchie, poi la faccia: la lampada accende la fronte e uno zigomo,
    // il resto affonda nel buio.
    final ear = Paint()..color = _dark(skin, 0.55);
    canvas.drawOval(Rect.fromCenter(center: const Offset(-0.165, -0.85), width: 0.05, height: 0.09), ear);
    canvas.drawOval(Rect.fromCenter(center: const Offset(0.165, -0.85), width: 0.05, height: 0.09), ear);
    final face = Path()
      ..moveTo(-0.16, -0.9)
      ..quadraticBezierTo(-0.16, -1.06, 0, -1.06)
      ..quadraticBezierTo(0.16, -1.06, 0.16, -0.9)
      ..quadraticBezierTo(0.16, -0.76, 0.09, -0.7)
      ..quadraticBezierTo(0, -0.64, -0.09, -0.7)
      ..quadraticBezierTo(-0.16, -0.76, -0.16, -0.9)
      ..close();
    canvas.drawPath(
      face,
      Paint()
        ..shader = RadialGradient(
          center: Alignment(light.dx * 0.45, -0.25),
          radius: 0.95,
          colors: [_bright(skin, 0.06), _dark(skin, 0.3), _dark(skin, 0.72)],
          stops: const [0, 0.5, 1],
        ).createShader(head),
    );
    canvas.save();
    canvas.clipPath(face);
    // Sotto la tesa gli occhi restano in ombra.
    final brim = switch (look.hat) {
      AvatarHead.fedora || AvatarHead.wideBrim => 0.42,
      AvatarHead.bowler || AvatarHead.coppola => 0.32,
      _ => 0.0,
    };
    if (brim > 0) {
      canvas.drawRect(
        const Rect.fromLTRB(-0.2, -1.1, 0.2, -0.82),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withValues(alpha: brim + 0.3), Colors.transparent],
          ).createShader(const Rect.fromLTRB(-0.2, -0.97, 0.2, -0.82)),
      );
    }
    final mark = look.base.mark;
    if (mark == FaceMark.stubble || mark == FaceMark.goatee) {
      canvas.drawPath(
        Path()
          ..moveTo(-0.15, -0.82)
          ..quadraticBezierTo(-0.1, -0.76, 0, -0.77)
          ..quadraticBezierTo(0.1, -0.76, 0.15, -0.82)
          ..lineTo(0.15, -0.6)
          ..lineTo(-0.15, -0.6)
          ..close(),
        Paint()..color = const Color(0xFF14100E).withValues(alpha: mark == FaceMark.stubble ? 0.4 : 0.22),
      );
    }
    canvas.restore();

    // Gli occhi: un lampo di bianco e la pupilla che si sposta.
    final look1 = pose.glance.clamp(-1.0, 1.0);
    final white = Paint()..color = paper.withValues(alpha: 0.82);
    final pupil = Paint()..color = ink;
    final brow = Paint()
      ..color = _dark(_hairColor(look), 0.2)
      ..strokeWidth = 0.022
      ..strokeCap = StrokeCap.round;
    for (final x in [-0.065, 0.065]) {
      final eye = Offset(x + look1 * 0.006, -0.875);
      if (look.glasses != AvatarGlasses.shades) {
        canvas.drawOval(Rect.fromCenter(center: eye, width: 0.058, height: 0.024), white);
        canvas.drawCircle(eye.translate(look1 * 0.016, 0), 0.0125, pupil);
      }
      final inner = x < 0 ? 1.0 : -1.0;
      canvas.drawLine(Offset(x - inner * 0.035, -0.915), Offset(x + inner * 0.03, -0.905 + (look.dame ? -0.006 : 0.004)), brow);
    }
    // Il naso, solo un'ombra e un filo di luce.
    canvas.drawLine(
      const Offset(0.008, -0.865),
      const Offset(0.018, -0.8),
      Paint()
        ..color = _dark(skin, 0.6)
        ..strokeWidth = 0.018
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(const Offset(-0.006, -0.81), 0.008, Paint()..color = _bright(skin, 0.3).withValues(alpha: 0.7));
    // La bocca.
    final mouth = Paint()
      ..color = _dark(skin, 0.72)
      ..strokeWidth = 0.014
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(-0.035, -0.762), const Offset(0.035, -0.765), mouth);

    final dark = Paint()..color = _dark(_hairColor(look), 0.1);
    switch (mark) {
      case FaceMark.clean || FaceMark.stubble:
        break;
      case FaceMark.mustache:
        canvas.drawPath(
          Path()
            ..moveTo(0, -0.79)
            ..quadraticBezierTo(-0.05, -0.8, -0.075, -0.765)
            ..quadraticBezierTo(-0.04, -0.775, 0, -0.772)
            ..quadraticBezierTo(0.04, -0.775, 0.075, -0.765)
            ..quadraticBezierTo(0.05, -0.8, 0, -0.79)
            ..close(),
          dark,
        );
      case FaceMark.lips:
        canvas.drawOval(
          Rect.fromCenter(center: const Offset(0, -0.763), width: 0.08, height: 0.028),
          Paint()..color = const Color(0xFFB8202E),
        );
        canvas.drawOval(
          Rect.fromCenter(center: const Offset(-0.01, -0.768), width: 0.03, height: 0.008),
          Paint()..color = Colors.white.withValues(alpha: 0.35),
        );
      case FaceMark.scar:
        final scar = Paint()
          ..color = _bright(skin, 0.55).withValues(alpha: 0.85)
          ..strokeWidth = 0.011
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(const Offset(0.085, -0.9), const Offset(0.115, -0.8), scar);
        for (final y in [-0.875, -0.85, -0.825]) {
          final x = 0.085 + (y + 0.9) * 0.3;
          canvas.drawLine(Offset(x - 0.015, y), Offset(x + 0.017, y - 0.006), scar);
        }
      case FaceMark.goatee:
        canvas.drawPath(
          Path()
            ..moveTo(-0.03, -0.745)
            ..quadraticBezierTo(0, -0.75, 0.03, -0.745)
            ..lineTo(0.018, -0.69)
            ..quadraticBezierTo(0, -0.675, -0.018, -0.69)
            ..close(),
          dark,
        );
        canvas.drawLine(
          const Offset(-0.05, -0.783),
          const Offset(0.05, -0.783),
          Paint()
            ..color = dark.color
            ..strokeWidth = 0.012
            ..strokeCap = StrokeCap.round,
        );
      case FaceMark.mole:
        canvas.drawCircle(const Offset(0.07, -0.79), 0.01, Paint()..color = const Color(0xFF1A0E0A));
    }
  }

  static void _hairFront(Canvas canvas, AvatarLook look) {
    final hair = Paint()..color = _hairColor(look);
    final shine = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.014
      ..strokeCap = StrokeCap.round;
    switch (look.hat) {
      case AvatarHead.slicked:
        canvas.drawPath(
          Path()
            ..moveTo(-0.168, -0.86)
            ..quadraticBezierTo(-0.18, -1.1, 0.02, -1.095)
            ..quadraticBezierTo(0.19, -1.09, 0.168, -0.86)
            ..quadraticBezierTo(0.15, -0.97, 0.05, -0.985)
            ..quadraticBezierTo(-0.1, -1.0, -0.168, -0.86)
            ..close(),
          hair,
        );
        canvas.drawArc(Rect.fromCenter(center: const Offset(0.0, -0.99), width: 0.22, height: 0.12), pi * 1.1, pi * 0.55, false, shine);
      case AvatarHead.bob:
        canvas.drawPath(
          Path()
            ..moveTo(-0.19, -0.8)
            ..quadraticBezierTo(-0.21, -1.085, 0, -1.085)
            ..quadraticBezierTo(0.21, -1.085, 0.19, -0.8)
            ..quadraticBezierTo(0.15, -0.94, 0.04, -0.96)
            ..quadraticBezierTo(-0.06, -0.93, -0.1, -0.97)
            ..quadraticBezierTo(-0.16, -0.92, -0.19, -0.8)
            ..close(),
          hair,
        );
        canvas.drawArc(Rect.fromCenter(center: const Offset(-0.04, -1.0), width: 0.24, height: 0.13), pi * 1.1, pi * 0.5, false, shine);
      case AvatarHead.bun:
        canvas.drawPath(
          Path()
            ..moveTo(-0.17, -0.86)
            ..quadraticBezierTo(-0.18, -1.09, 0, -1.09)
            ..quadraticBezierTo(0.18, -1.09, 0.17, -0.86)
            ..quadraticBezierTo(0.12, -0.98, 0, -0.99)
            ..quadraticBezierTo(-0.12, -0.98, -0.17, -0.86)
            ..close(),
          hair,
        );
        canvas.drawLine(
          const Offset(-0.07, -1.14),
          const Offset(0.09, -1.07),
          Paint()
            ..color = gold
            ..strokeWidth = 0.014
            ..strokeCap = StrokeCap.round,
        );
      case AvatarHead.wideBrim:
        canvas.drawPath(
          Path()
            ..moveTo(-0.2, -0.78)
            ..quadraticBezierTo(-0.2, -0.95, -0.12, -0.97)
            ..lineTo(-0.15, -0.8)
            ..close()
            ..moveTo(0.2, -0.78)
            ..quadraticBezierTo(0.2, -0.95, 0.12, -0.97)
            ..lineTo(0.15, -0.8)
            ..close(),
          hair,
        );
      case AvatarHead.fedora || AvatarHead.bowler || AvatarHead.coppola:
        // Le basette sotto il cappello.
        canvas.drawRect(const Rect.fromLTRB(-0.165, -0.95, -0.14, -0.86), hair);
        canvas.drawRect(const Rect.fromLTRB(0.14, -0.95, 0.165, -0.86), hair);
    }
  }

  static void _glasses(Canvas canvas, AvatarLook look, CharacterPose pose) {
    final frame = Paint()
      ..color = const Color(0xFFD9C9A8).withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.012;
    final glint = Paint()..color = Colors.white.withValues(alpha: 0.7);
    switch (look.glasses) {
      case AvatarGlasses.none:
        break;
      case AvatarGlasses.round:
        for (final x in [-0.065, 0.065]) {
          canvas.drawCircle(Offset(x, -0.875), 0.046, frame);
          canvas.drawCircle(Offset(x - 0.018, -0.89), 0.009, glint);
        }
        canvas.drawLine(const Offset(-0.02, -0.88), const Offset(0.02, -0.88), frame);
      case AvatarGlasses.monocle:
        canvas.drawCircle(const Offset(0.065, -0.875), 0.05, frame..color = const Color(0xFFE2C46A));
        canvas.drawCircle(const Offset(0.048, -0.892), 0.009, glint);
        canvas.drawPath(
          Path()
            ..moveTo(0.11, -0.86)
            ..quadraticBezierTo(0.2, -0.72, 0.16, -0.5),
          frame..strokeWidth = 0.007,
        );
      case AvatarGlasses.shades:
        final lens = Paint()..color = const Color(0xFF0B0B10);
        for (final x in [-0.068, 0.068]) {
          final r = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x, -0.872), width: 0.105, height: 0.064), const Radius.circular(0.025));
          canvas.drawRRect(r, lens);
          canvas.drawRRect(r, frame..color = const Color(0xFF3A3A40)..strokeWidth = 0.01);
          canvas.drawLine(Offset(x - 0.035, -0.885), Offset(x - 0.01, -0.893), Paint()
            ..color = Colors.white.withValues(alpha: 0.55)
            ..strokeWidth = 0.01
            ..strokeCap = StrokeCap.round);
        }
        canvas.drawLine(const Offset(-0.016, -0.88), const Offset(0.016, -0.88), frame);
    }
  }

  static const _felt = Color(0xFF1C1A1E);

  static void _hat(Canvas canvas, AvatarLook look, Paint paint, {required bool silhouette}) {
    final felt = silhouette ? paint : (Paint()..color = _felt);
    final accent = look.outfit.accent;
    final band = silhouette ? paint : (Paint()..color = _dark(accent, 0.35));
    final top = silhouette
        ? paint
        : (Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF3A3640), _felt],
            ).createShader(const Rect.fromLTRB(-0.2, -1.22, 0.2, -0.96)));
    void brim(double width, double height, {double tilt = 0, double y = -0.965}) {
      canvas.save();
      canvas.translate(0, y);
      canvas.rotate(tilt);
      final r = Rect.fromCenter(center: Offset.zero, width: width, height: height);
      canvas.drawOval(r, felt);
      if (!silhouette) {
        canvas.drawArc(
          r.deflate(0.004),
          0.15,
          pi - 0.3,
          false,
          Paint()
            ..color = Colors.black.withValues(alpha: 0.6)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.014,
        );
        canvas.drawArc(
          r,
          pi + 0.2,
          pi - 0.4,
          false,
          Paint()
            ..color = rim.withValues(alpha: 0.5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.008,
        );
      }
      canvas.restore();
    }

    switch (look.hat) {
      case AvatarHead.fedora:
        brim(0.62, 0.09, tilt: -0.04);
        canvas.drawPath(
          Path()
            ..moveTo(-0.18, -0.97)
            ..lineTo(-0.165, -1.15)
            ..quadraticBezierTo(-0.1, -1.2, -0.02, -1.16)
            ..quadraticBezierTo(0, -1.15, 0.02, -1.16)
            ..quadraticBezierTo(0.1, -1.2, 0.165, -1.15)
            ..lineTo(0.18, -0.97)
            ..close(),
          top,
        );
        canvas.drawRect(const Rect.fromLTRB(-0.179, -1.03, 0.179, -0.985), band);
        if (!silhouette) {
          canvas.drawLine(
            const Offset(0, -1.15),
            const Offset(0, -1.06),
            Paint()
              ..color = Colors.black.withValues(alpha: 0.45)
              ..strokeWidth = 0.014,
          );
        }
      case AvatarHead.wideBrim:
        brim(0.84, 0.12, tilt: -0.1, y: -0.99);
        canvas.save();
        canvas.translate(0, -0.99);
        canvas.rotate(-0.1);
        canvas.drawPath(
          Path()
            ..moveTo(-0.15, 0)
            ..quadraticBezierTo(-0.15, -0.15, 0, -0.15)
            ..quadraticBezierTo(0.15, -0.15, 0.15, 0)
            ..close(),
          top,
        );
        canvas.drawRect(const Rect.fromLTRB(-0.148, -0.055, 0.148, -0.015), Paint()..color = silhouette ? paint.color : accent);
        canvas.restore();
      case AvatarHead.bowler:
        brim(0.46, 0.075, y: -0.975);
        canvas.drawPath(
          Path()
            ..moveTo(-0.17, -0.975)
            ..quadraticBezierTo(-0.18, -1.19, 0, -1.19)
            ..quadraticBezierTo(0.18, -1.19, 0.17, -0.975)
            ..close(),
          top,
        );
        canvas.drawRect(const Rect.fromLTRB(-0.172, -1.02, 0.172, -0.985), band);
      case AvatarHead.coppola:
        final cap = silhouette ? paint : (Paint()..color = const Color(0xFF4A3D30));
        canvas.drawPath(
          Path()
            ..moveTo(-0.19, -0.95)
            ..quadraticBezierTo(-0.22, -1.11, 0, -1.12)
            ..quadraticBezierTo(0.22, -1.11, 0.19, -0.95)
            ..close(),
          cap,
        );
        if (!silhouette) {
          final weave = Paint()
            ..color = const Color(0xFF8A7458).withValues(alpha: 0.35)
            ..strokeWidth = 0.008;
          for (var x = -0.16; x < 0.17; x += 0.05) {
            canvas.drawLine(Offset(x, -1.1), Offset(x * 1.1, -0.95), weave);
          }
        }
        canvas.drawPath(
          Path()
            ..moveTo(-0.16, -0.955)
            ..quadraticBezierTo(0, -0.88, 0.16, -0.955)
            ..quadraticBezierTo(0, -0.99, -0.16, -0.955)
            ..close(),
          silhouette ? paint : (Paint()..color = const Color(0xFF2E251D)),
        );
      case AvatarHead.slicked || AvatarHead.bob || AvatarHead.bun:
        break;
    }
  }

  static void _mouthProp(Canvas canvas, AvatarLook look) {
    switch (look.accessory) {
      case AvatarAccessory.cigarette:
        canvas.drawLine(
          const Offset(0.03, -0.765),
          const Offset(0.14, -0.745),
          Paint()
            ..color = paper
            ..strokeWidth = 0.018
            ..strokeCap = StrokeCap.round,
        );
        canvas.drawCircle(const Offset(0.145, -0.744), 0.012, Paint()..color = ember);
      case AvatarAccessory.cigar:
        canvas.drawLine(
          const Offset(0.025, -0.765),
          const Offset(0.16, -0.735),
          Paint()
            ..color = const Color(0xFF5A3A22)
            ..strokeWidth = 0.032
            ..strokeCap = StrokeCap.round,
        );
        canvas.drawLine(
          const Offset(0.06, -0.757),
          const Offset(0.075, -0.754),
          Paint()
            ..color = const Color(0xFFC9A54E)
            ..strokeWidth = 0.034,
        );
        canvas.drawCircle(const Offset(0.165, -0.734), 0.016, Paint()..color = ember);
      case AvatarAccessory.toothpick:
        canvas.drawLine(
          const Offset(0.025, -0.763),
          const Offset(0.11, -0.735),
          Paint()
            ..color = const Color(0xFFE8D5A8)
            ..strokeWidth = 0.008
            ..strokeCap = StrokeCap.round,
        );
      case AvatarAccessory.none ||
          AvatarAccessory.tie ||
          AvatarAccessory.bowTie ||
          AvatarAccessory.pearls ||
          AvatarAccessory.scarf ||
          AvatarAccessory.carnation:
        break;
    }
  }

  /// Il garofano rosso: all'occhiello di chi se lo può permettere, sul
  /// tavolo davanti a chi non c'è più.
  static void carnation(Canvas canvas, Offset at, double r, {double angle = 0}) {
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(angle);
    canvas.drawLine(
      Offset(0, r * 0.6),
      Offset(r * 0.3, r * 2.4),
      Paint()
        ..color = const Color(0xFF2F5A2A)
        ..strokeWidth = r * 0.3
        ..strokeCap = StrokeCap.round,
    );
    for (var i = 0; i < 7; i++) {
      final a = i * 2 * pi / 7;
      canvas.drawCircle(Offset(cos(a), sin(a)) * (r * 0.5), r * 0.55, Paint()..color = const Color(0xFFA3172A));
    }
    canvas.drawCircle(Offset.zero, r * 0.55, Paint()..color = const Color(0xFFD23246));
    canvas.drawCircle(Offset(-r * 0.2, -r * 0.2), r * 0.22, Paint()..color = const Color(0xFFF06A78));
    canvas.restore();
  }

  /// Gli avambracci posati sul panno, le mani nella luce della lampada.
  /// Chi si alza tiene le mani puntate dove sono e porta su i gomiti.
  static void _forearms(Canvas canvas, AvatarLook look, CharacterPose pose, {required bool lit}) {
    final lift = -0.42 * pose.rise + pose.breath * 0.012;
    final coat = look.outfit.coat;
    final skin = look.base.skin;
    final apart = pose.hands % 3;
    final hands = switch (apart) {
      0 => const [Offset(-0.07, 0.085), Offset(0.07, 0.09)],
      1 => const [Offset(-0.2, 0.09), Offset(0.2, 0.09)],
      _ => const [Offset(-0.16, 0.09), Offset(0.1, 0.095)],
    };
    if (apart == 1) {
      // Due carte coperte tra le mani.
      for (final (i, dx) in [-0.05, 0.03].indexed) {
        canvas.save();
        canvas.translate(dx, 0.1);
        canvas.rotate(-0.25 + i * 0.4);
        final card = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: 0.1, height: 0.07), const Radius.circular(0.01));
        canvas.drawRRect(card.shift(const Offset(0, 0.01)), Paint()..color = Colors.black.withValues(alpha: 0.4));
        canvas.drawRRect(card, Paint()..color = paper);
        canvas.drawRRect(card.deflate(0.01), Paint()..color = const Color(0xFF8E1D28));
        canvas.restore();
      }
    }
    for (final (i, hand) in hands.indexed) {
      final side = i == 0 ? -1.0 : 1.0;
      final elbow = Offset(side * 0.42 * (look.dame ? 0.9 : 1), 0.0 + lift * 0.9);
      final along = hand - elbow;
      final unit = along / along.distance;
      final cross = Offset(-unit.dy, unit.dx);
      final wrist = hand - unit * 0.06;
      final sleeve = Path()
        ..moveTo(elbow.dx + cross.dx * 0.0585, elbow.dy + cross.dy * 0.0585)
        ..quadraticBezierTo(
          (elbow.dx + wrist.dx) / 2 + cross.dx * 0.0585,
          (elbow.dy + wrist.dy) / 2 + cross.dy * 0.0585,
          wrist.dx + cross.dx * 0.058,
          wrist.dy + cross.dy * 0.058,
        )
        ..lineTo(wrist.dx - cross.dx * 0.058, wrist.dy - cross.dy * 0.058)
        ..quadraticBezierTo(
          (elbow.dx + wrist.dx) / 2 - cross.dx * 0.0585,
          (elbow.dy + wrist.dy) / 2 - cross.dy * 0.0585,
          elbow.dx - cross.dx * 0.0585,
          elbow.dy - cross.dy * 0.0585,
        )
        ..close();
      canvas.drawPath(sleeve.shift(Offset(pose.light.dx * 0.012, pose.light.dy * 0.012)), Paint()..color = (lit ? gold : rim).withValues(alpha: 0.6));
      canvas.drawPath(
        sleeve,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_dark(coat, 0.7), _dark(coat, 0.15)],
          ).createShader(Rect.fromPoints(elbow, wrist).inflate(0.1)),
      );
      // Il polsino della camicia.
      canvas.drawLine(
        wrist + cross * 0.055,
        wrist - cross * 0.055,
        Paint()
          ..color = look.dame ? _dark(coat, 0.2) : _dark(look.outfit.shirt, 0.15)
          ..strokeWidth = 0.03,
      );
      canvas.drawOval(
        Rect.fromCenter(center: hand.translate(0, 0.02), width: 0.15, height: 0.06),
        Paint()..color = Colors.black.withValues(alpha: 0.4),
      );
      canvas.drawOval(
        Rect.fromCenter(center: hand, width: 0.115, height: 0.075),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_bright(skin, 0.15), _dark(skin, 0.4)],
          ).createShader(Rect.fromCenter(center: hand, width: 0.115, height: 0.075)),
      );
      if (look.dame && i == 1) {
        canvas.drawCircle(hand.translate(-0.02, -0.02), 0.012, Paint()..color = gold);
      }
    }
  }

  /// Il fumo che sale dalla brace, piano, e si allarga.
  static void _smoke(Canvas canvas, AvatarLook look, CharacterPose pose) {
    if (!look.accessory.smokes) return;
    final lift = -0.42 * pose.rise + pose.breath * 0.012;
    final tip = (look.accessory == AvatarAccessory.cigar ? const Offset(0.165, -0.75) : const Offset(0.145, -0.76)).translate(0, lift);
    paintSmoke(canvas, tip, 1, pose.time, seed: look.hashCode % 97);
  }

  /// Una voluta di fumo alta [height] che parte da [from]: la usa anche il
  /// tavolo per la nebbia sotto la lampada.
  static void paintSmoke(Canvas canvas, Offset from, double height, double time, {int seed = 0, double alpha = 0.22}) {
    const puffs = 7;
    for (var i = 0; i < puffs; i++) {
      final p = (time * 0.22 + i / puffs + seed * 0.013) % 1;
      final y = -p * 0.75 * height;
      final x = sin(time * 1.1 + p * 7 + seed) * 0.06 * height * p + p * 0.08 * height;
      final r = (0.02 + 0.09 * p) * height;
      canvas.drawCircle(
        from + Offset(x, y),
        r,
        Paint()
          ..color = const Color(0xFFD8D2CA).withValues(alpha: alpha * sin(pi * p) * (1 - p * 0.4))
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.6),
      );
    }
  }
}
