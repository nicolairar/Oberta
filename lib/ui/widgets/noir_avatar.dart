import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Il ritratto di un giocatore: una foto segnaletica da film noir. Una sagoma
/// scura davanti alle righe dell'altezza, un filo di luce di taglio, e pochi
/// dettagli chiari che fanno la faccia. Tutto si ricava dal [seed], così la
/// stessa persona ha sempre la stessa faccia su ogni telefono.
class NoirAvatar extends StatelessWidget {
  final String seed;
  final double size;

  /// I morti restano nella griglia, ma in bianco e nero e sbiaditi.
  final bool faded;

  const NoirAvatar({super.key, required this.seed, this.size = 44, this.faded = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _AvatarPainter(_Look.from(seed), faded)),
    );
  }
}

/// Cappello o pettinatura di un ritratto.
enum AvatarHead { fedora, bowler, coppola, slicked, bob, bun, wideBrim }

/// Il cappello che spetta a [seed]: serve a chi vuole disegnare la stessa
/// persona altrove, per esempio come sagoma in una scena.
AvatarHead avatarHeadFor(String seed) => _Look.from(seed).head;

enum _Face { eyes, mustache, lips, scar, glasses, monocle, shades }

enum _Extra { none, cigarette, earring, toothpick, none2 }

enum _Collar { tie, bowTie, pearls, scarf }

class _Look {
  final Color background;
  final AvatarHead head;
  final _Face face;
  final _Extra extra;
  final _Collar collar;
  final bool mirrored;

  const _Look(this.background, this.head, this.face, this.extra, this.collar, this.mirrored);

  static const _backgrounds = [
    Color(0xFF9C2B34),
    Color(0xFF2A5C8C),
    Color(0xFF27775C),
    Color(0xFF8A6427),
    Color(0xFF6A478C),
    Color(0xFFB8862B),
    Color(0xFF2F7584),
    Color(0xFF8C4660),
    Color(0xFFA8553A),
    Color(0xFF3E6B3A),
  ];

  /// FNV-1a: un hash piccolo e uguale su ogni piattaforma, a differenza di
  /// `String.hashCode`, che non promette di restare stabile.
  factory _Look.from(String seed) {
    var hash = 0x811C9DC5;
    for (final unit in seed.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xFFFFFFFF;
    }
    int take(int options) {
      final value = hash % options;
      hash = hash ~/ options + 0x9E37;
      return value;
    }

    return _Look(
      _backgrounds[take(_backgrounds.length)],
      AvatarHead.values[take(AvatarHead.values.length)],
      _Face.values[take(_Face.values.length)],
      _Extra.values[take(_Extra.values.length)],
      _Collar.values[take(_Collar.values.length)],
      take(2) == 1,
    );
  }
}

class _AvatarPainter extends CustomPainter {
  final _Look look;
  final bool faded;

  _AvatarPainter(this.look, this.faded);

  static const _ink = Color(0xFF0B0908);
  static const _paper = Color(0xFFF2EAE1);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final bounds = Offset.zero & Size.square(s);
    final background = faded ? const Color(0xFF4A4642) : look.background;
    final light = Color.lerp(background, Colors.white, 0.55)!;
    Offset at(double x, double y) => Offset(s * x, s * y);

    canvas.save();
    canvas.clipPath(Path()..addOval(bounds));

    // Il fondale: un riflettore in alto, e le righe dell'altezza dietro.
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.25, -0.55),
          radius: 1.15,
          colors: [
            Color.lerp(background, Colors.white, 0.28)!,
            background,
            Color.lerp(background, Colors.black, 0.55)!,
          ],
          stops: const [0, 0.45, 1],
        ).createShader(bounds),
    );
    final ruler = Paint()
      ..color = Colors.black.withValues(alpha: 0.16)
      ..strokeWidth = max(0.6, s * 0.008);
    for (var i = 1; i < 8; i++) {
      canvas.drawLine(at(0, i * 0.125), at(i.isEven ? 1 : 0.16, i * 0.125), ruler);
    }

    if (look.mirrored) {
      canvas.translate(s, 0);
      canvas.scale(-1, 1);
    }

    void figure(Paint paint) {
      // Spalle larghe da soprabito, collo, testa.
      canvas.drawPath(
        Path()
          ..moveTo(s * 0.02, s * 1.02)
          ..quadraticBezierTo(s * 0.04, s * 0.80, s * 0.30, s * 0.755)
          ..lineTo(s * 0.70, s * 0.755)
          ..quadraticBezierTo(s * 0.96, s * 0.80, s * 0.98, s * 1.02)
          ..close(),
        paint,
      );
      canvas.drawRect(Rect.fromLTRB(s * 0.425, s * 0.58, s * 0.575, s * 0.80), paint);
      canvas.drawPath(
        Path()
          ..moveTo(s * 0.335, s * 0.40)
          ..quadraticBezierTo(s * 0.33, s * 0.235, s * 0.50, s * 0.235)
          ..quadraticBezierTo(s * 0.67, s * 0.235, s * 0.665, s * 0.40)
          ..quadraticBezierTo(s * 0.66, s * 0.56, s * 0.565, s * 0.645)
          ..quadraticBezierTo(s * 0.50, s * 0.685, s * 0.435, s * 0.645)
          ..quadraticBezierTo(s * 0.34, s * 0.56, s * 0.335, s * 0.40)
          ..close(),
        paint,
      );
      _paintHead(canvas, s, paint);
    }

    // Prima la figura in chiaro, un filo spostata verso il riflettore, poi
    // il nero sopra: resta un bordo di luce che stacca la sagoma dal fondo.
    canvas.save();
    canvas.translate(-s * 0.022, -s * 0.014);
    figure(Paint()..color = light.withValues(alpha: faded ? 0.45 : 0.9));
    canvas.restore();
    figure(Paint()..color = _ink);

    _paintBand(canvas, s, background);
    _paintCollar(canvas, s);
    _paintFace(canvas, s, light);
    _paintExtra(canvas, s);
    canvas.restore();

    // La cornice: un anello scuro e uno d'oro, come una moneta.
    canvas.drawCircle(
      bounds.center,
      s / 2 - s * 0.012,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.05
        ..color = Colors.black.withValues(alpha: 0.55),
    );
    canvas.drawCircle(
      bounds.center,
      s / 2 - max(0.75, s * 0.012),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.5, s * 0.024)
        ..color = (faded ? AppColors.textSecondary : AppColors.gold).withValues(alpha: 0.9),
    );
  }

  void _paintHead(Canvas canvas, double s, Paint paint) {
    Offset at(double x, double y) => Offset(s * x, s * y);
    switch (look.head) {
      case AvatarHead.fedora:
        canvas.save();
        canvas.translate(s * 0.5, s * 0.315);
        canvas.rotate(-0.06);
        canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: s * 0.68, height: s * 0.105), paint);
        canvas.restore();
        canvas.drawPath(
          Path()
            ..moveTo(s * 0.315, s * 0.315)
            ..quadraticBezierTo(s * 0.30, s * 0.085, s * 0.45, s * 0.095)
            ..quadraticBezierTo(s * 0.50, s * 0.135, s * 0.55, s * 0.095)
            ..quadraticBezierTo(s * 0.70, s * 0.085, s * 0.685, s * 0.315)
            ..close(),
          paint,
        );
      case AvatarHead.bowler:
        canvas.drawOval(Rect.fromCenter(center: at(0.5, 0.315), width: s * 0.58, height: s * 0.09), paint);
        canvas.drawArc(Rect.fromCenter(center: at(0.5, 0.315), width: s * 0.40, height: s * 0.44), pi, pi, true, paint);
      case AvatarHead.coppola:
        canvas.drawPath(
          Path()
            ..moveTo(s * 0.29, s * 0.315)
            ..quadraticBezierTo(s * 0.27, s * 0.15, s * 0.50, s * 0.155)
            ..quadraticBezierTo(s * 0.72, s * 0.16, s * 0.715, s * 0.30)
            ..lineTo(s * 0.50, s * 0.335)
            ..quadraticBezierTo(s * 0.30, s * 0.355, s * 0.13, s * 0.345)
            ..quadraticBezierTo(s * 0.16, s * 0.305, s * 0.29, s * 0.315)
            ..close(),
          paint,
        );
      case AvatarHead.slicked:
        canvas.drawPath(
          Path()
            ..moveTo(s * 0.325, s * 0.40)
            ..quadraticBezierTo(s * 0.31, s * 0.20, s * 0.52, s * 0.20)
            ..quadraticBezierTo(s * 0.70, s * 0.21, s * 0.675, s * 0.40)
            ..quadraticBezierTo(s * 0.62, s * 0.29, s * 0.42, s * 0.30)
            ..quadraticBezierTo(s * 0.35, s * 0.31, s * 0.325, s * 0.40)
            ..close(),
          paint,
        );
      case AvatarHead.bob:
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTRB(s * 0.265, s * 0.19, s * 0.735, s * 0.66), Radius.circular(s * 0.19)),
          paint,
        );
      case AvatarHead.bun:
        canvas.drawCircle(at(0.5, 0.165), s * 0.095, paint);
        canvas.drawArc(Rect.fromCenter(center: at(0.5, 0.42), width: s * 0.42, height: s * 0.46), pi, pi, true, paint);
      case AvatarHead.wideBrim:
        canvas.save();
        canvas.translate(s * 0.5, s * 0.30);
        canvas.rotate(-0.14);
        canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: s * 0.88, height: s * 0.12), paint);
        canvas.drawArc(
          Rect.fromCenter(center: Offset(0, s * 0.01), width: s * 0.38, height: s * 0.28),
          pi,
          pi,
          true,
          paint,
        );
        canvas.restore();
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTRB(s * 0.295, s * 0.30, s * 0.705, s * 0.64), Radius.circular(s * 0.15)),
          paint,
        );
    }
  }

  /// Il nastro del cappello, nel colore del fondo: lega la figura al suo ritratto.
  void _paintBand(Canvas canvas, double s, Color background) {
    final band = Paint()..color = Color.lerp(background, Colors.white, 0.30)!;
    switch (look.head) {
      case AvatarHead.fedora:
        canvas.drawPath(
          Path()
            ..moveTo(s * 0.318, s * 0.255)
            ..lineTo(s * 0.682, s * 0.255)
            ..lineTo(s * 0.685, s * 0.300)
            ..lineTo(s * 0.315, s * 0.300)
            ..close(),
          band,
        );
      case AvatarHead.bowler:
        canvas.drawRect(Rect.fromLTRB(s * 0.305, s * 0.265, s * 0.695, s * 0.300), band);
      case AvatarHead.wideBrim:
        canvas.save();
        canvas.translate(s * 0.5, s * 0.30);
        canvas.rotate(-0.14);
        canvas.drawRect(Rect.fromLTRB(-s * 0.185, -s * 0.050, s * 0.185, -s * 0.014), band);
        canvas.restore();
      case AvatarHead.bun:
        canvas.drawLine(
          Offset(s * 0.42, s * 0.105),
          Offset(s * 0.60, s * 0.20),
          Paint()
            ..color = AppColors.gold
            ..strokeWidth = s * 0.016
            ..strokeCap = StrokeCap.round,
        );
      case AvatarHead.coppola || AvatarHead.slicked || AvatarHead.bob:
        break;
    }
  }

  void _paintCollar(Canvas canvas, double s) {
    Offset at(double x, double y) => Offset(s * x, s * y);
    final paper = Paint()..color = _paper.withValues(alpha: faded ? 0.5 : 0.94);
    final accent = faded ? AppColors.textSecondary : AppColors.accent;
    final lapel = Paint()
      ..color = Colors.white.withValues(alpha: 0.13)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.014
      ..strokeCap = StrokeCap.round;

    void shirt() {
      canvas.drawPath(
        Path()
          ..moveTo(s * 0.405, s * 0.765)
          ..lineTo(s * 0.50, s * 0.95)
          ..lineTo(s * 0.595, s * 0.765)
          ..close(),
        paper,
      );
      // I risvolti della giacca.
      canvas.drawLine(at(0.405, 0.765), at(0.30, 0.93), lapel);
      canvas.drawLine(at(0.595, 0.765), at(0.70, 0.93), lapel);
    }

    switch (look.collar) {
      case _Collar.tie:
        shirt();
        canvas.drawPath(
          Path()
            ..moveTo(s * 0.47, s * 0.775)
            ..lineTo(s * 0.53, s * 0.775)
            ..lineTo(s * 0.52, s * 0.82)
            ..lineTo(s * 0.55, s * 1.0)
            ..lineTo(s * 0.45, s * 1.0)
            ..lineTo(s * 0.48, s * 0.82)
            ..close(),
          Paint()..color = accent,
        );
      case _Collar.bowTie:
        shirt();
        canvas.drawPath(
          Path()
            ..moveTo(s * 0.50, s * 0.805)
            ..lineTo(s * 0.405, s * 0.765)
            ..lineTo(s * 0.405, s * 0.845)
            ..close()
            ..moveTo(s * 0.50, s * 0.805)
            ..lineTo(s * 0.595, s * 0.765)
            ..lineTo(s * 0.595, s * 0.845)
            ..close(),
          Paint()..color = accent,
        );
        canvas.drawCircle(at(0.50, 0.805), s * 0.018, Paint()..color = Color.lerp(accent, Colors.black, 0.3)!);
      case _Collar.pearls:
        for (var i = 0; i < 9; i++) {
          final t = i / 8;
          canvas.drawCircle(at(0.385 + 0.23 * t, 0.77 + 0.065 * sin(pi * t)), s * 0.017, paper);
        }
      case _Collar.scarf:
        canvas.drawPath(
          Path()
            ..moveTo(s * 0.37, s * 0.735)
            ..quadraticBezierTo(s * 0.50, s * 0.845, s * 0.63, s * 0.735)
            ..lineTo(s * 0.61, s * 0.805)
            ..quadraticBezierTo(s * 0.50, s * 0.90, s * 0.39, s * 0.805)
            ..close(),
          Paint()..color = (faded ? AppColors.textSecondary : AppColors.gold).withValues(alpha: 0.92),
        );
    }
  }

  /// I pochi tratti chiari che, nel buio della sagoma, fanno una faccia.
  void _paintFace(Canvas canvas, double s, Color light) {
    Offset at(double x, double y) => Offset(s * x, s * y);
    final glint = Paint()..color = _paper.withValues(alpha: faded ? 0.5 : 0.92);
    final line = Paint()
      ..color = _paper.withValues(alpha: faded ? 0.5 : 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.018
      ..strokeCap = StrokeCap.round;

    void eyes() {
      for (final x in [0.435, 0.565]) {
        canvas.drawOval(Rect.fromCenter(center: at(x, 0.455), width: s * 0.062, height: s * 0.022), glint);
      }
    }

    switch (look.face) {
      case _Face.eyes:
        eyes();
      case _Face.mustache:
        eyes();
        canvas.drawPath(
          Path()
            ..moveTo(s * 0.50, s * 0.545)
            ..quadraticBezierTo(s * 0.44, s * 0.535, s * 0.405, s * 0.575)
            ..quadraticBezierTo(s * 0.46, s * 0.585, s * 0.50, s * 0.565)
            ..quadraticBezierTo(s * 0.54, s * 0.585, s * 0.595, s * 0.575)
            ..quadraticBezierTo(s * 0.56, s * 0.535, s * 0.50, s * 0.545)
            ..close(),
          Paint()..color = _paper.withValues(alpha: faded ? 0.4 : 0.75),
        );
      case _Face.lips:
        eyes();
        canvas.drawOval(
          Rect.fromCenter(center: at(0.50, 0.578), width: s * 0.085, height: s * 0.030),
          Paint()..color = faded ? AppColors.textSecondary : const Color(0xFFD9303C),
        );
      case _Face.scar:
        eyes();
        canvas.drawLine(at(0.585, 0.40), at(0.615, 0.545), line..strokeWidth = s * 0.012);
        for (final y in [0.44, 0.48, 0.52]) {
          canvas.drawLine(at(0.575 + (y - 0.40) * 0.2, y), at(0.612 + (y - 0.40) * 0.2, y - 0.008), line);
        }
      case _Face.glasses:
        canvas.drawCircle(at(0.435, 0.455), s * 0.052, line);
        canvas.drawCircle(at(0.565, 0.455), s * 0.052, line);
        canvas.drawLine(at(0.487, 0.455), at(0.513, 0.455), line);
        canvas.drawCircle(at(0.42, 0.44), s * 0.012, glint);
        canvas.drawCircle(at(0.55, 0.44), s * 0.012, glint);
      case _Face.monocle:
        canvas.drawOval(Rect.fromCenter(center: at(0.435, 0.455), width: s * 0.062, height: s * 0.022), glint);
        canvas.drawCircle(at(0.565, 0.455), s * 0.056, line);
        canvas.drawLine(at(0.60, 0.50), at(0.635, 0.68), line..strokeWidth = s * 0.009);
      case _Face.shades:
        final lens = Paint()..color = light.withValues(alpha: faded ? 0.35 : 0.55);
        for (final x in [0.43, 0.57]) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(center: at(x, 0.455), width: s * 0.115, height: s * 0.07),
              Radius.circular(s * 0.025),
            ),
            lens,
          );
        }
        canvas.drawLine(at(0.488, 0.445), at(0.512, 0.445), line..strokeWidth = s * 0.012);
    }
  }

  void _paintExtra(Canvas canvas, double s) {
    Offset at(double x, double y) => Offset(s * x, s * y);
    final paper = _paper.withValues(alpha: faded ? 0.5 : 0.92);
    switch (look.extra) {
      case _Extra.none || _Extra.none2:
        break;
      case _Extra.cigarette:
        canvas.drawLine(
          at(0.545, 0.585),
          at(0.70, 0.565),
          Paint()
            ..color = paper
            ..strokeWidth = s * 0.024
            ..strokeCap = StrokeCap.round,
        );
        canvas.drawCircle(at(0.71, 0.563), s * 0.018, Paint()..color = const Color(0xFFFF7A3B));
        canvas.drawPath(
          Path()
            ..moveTo(s * 0.72, s * 0.54)
            ..quadraticBezierTo(s * 0.78, s * 0.47, s * 0.72, s * 0.41)
            ..quadraticBezierTo(s * 0.67, s * 0.35, s * 0.75, s * 0.29),
          Paint()
            ..color = _paper.withValues(alpha: 0.38)
            ..style = PaintingStyle.stroke
            ..strokeWidth = s * 0.022
            ..strokeCap = StrokeCap.round,
        );
      case _Extra.earring:
        canvas.drawCircle(at(0.34, 0.545), s * 0.024, Paint()..color = AppColors.gold);
      case _Extra.toothpick:
        canvas.drawLine(
          at(0.53, 0.585),
          at(0.64, 0.62),
          Paint()
            ..color = paper
            ..strokeWidth = s * 0.011
            ..strokeCap = StrokeCap.round,
        );
    }
  }

  @override
  bool shouldRepaint(_AvatarPainter old) => old.look != look || old.faded != faded;
}
