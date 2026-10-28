part of 'look_painter.dart';

/// Le misure della testa dei pittori di sempre (i cappelli, le pettinature
/// della bottega, i tatuaggi, le barbe strane): la testa al centro in
/// (0, -0.86), larga 0.32, gli occhi a -0.868. Il cartoon noir ([_Noir]) li
/// porta sulla sua testa grande.
abstract final class _Face {
  /// La sommità, la fronte, gli zigomi, l'angolo della mascella e il mento.
  static ({double top, double fw, double cw, double jw, double jy, double chin, double cr}) geometry(FaceShape shape) =>
      switch (shape) {
        FaceShape.oval => (top: -1.06, fw: 0.152, cw: 0.158, jw: 0.116, jy: -0.728, chin: -0.655, cr: 0.05),
        FaceShape.round => (top: -1.055, fw: 0.158, cw: 0.17, jw: 0.14, jy: -0.738, chin: -0.668, cr: 0.09),
        FaceShape.square => (top: -1.06, fw: 0.16, cw: 0.162, jw: 0.15, jy: -0.714, chin: -0.66, cr: 0.085),
        FaceShape.long => (top: -1.075, fw: 0.145, cw: 0.148, jw: 0.11, jy: -0.706, chin: -0.633, cr: 0.048),
        FaceShape.heart => (top: -1.06, fw: 0.164, cw: 0.163, jw: 0.1, jy: -0.734, chin: -0.652, cr: 0.03),
        FaceShape.diamond => (top: -1.066, fw: 0.138, cw: 0.168, jw: 0.108, jy: -0.73, chin: -0.652, cr: 0.036),
        FaceShape.pear => (top: -1.055, fw: 0.142, cw: 0.156, jw: 0.148, jy: -0.73, chin: -0.662, cr: 0.085),
        FaceShape.chiselled => (top: -1.062, fw: 0.155, cw: 0.16, jw: 0.142, jy: -0.708, chin: -0.648, cr: 0.058),
      };

  static final Map<FaceShape, Path> _paths = {};

  static Path path(FaceShape shape) => _paths[shape] ??= _build(shape);

  static Path _build(FaceShape shape) {
    final g = geometry(shape);
    final jawDrop = g.jy + (g.chin - g.jy) * 0.78;
    return Path()
      ..moveTo(0, g.top)
      ..cubicTo(0.62 * g.fw, g.top, g.fw, g.top + 0.045, g.fw, -0.935)
      ..cubicTo(g.fw, -0.895, g.cw, -0.875, g.cw, -0.832)
      ..cubicTo(g.cw, -0.785, g.jw + 0.014, g.jy - 0.022, g.jw, g.jy)
      ..cubicTo(g.jw - 0.008, jawDrop, g.cr, g.chin, 0, g.chin)
      ..cubicTo(-g.cr, g.chin, -(g.jw - 0.008), jawDrop, -g.jw, g.jy)
      ..cubicTo(-(g.jw + 0.014), g.jy - 0.022, -g.cw, -0.785, -g.cw, -0.832)
      ..cubicTo(-g.cw, -0.875, -g.fw, -0.895, -g.fw, -0.935)
      ..cubicTo(-g.fw, g.top + 0.045, -0.62 * g.fw, g.top, 0, g.top)
      ..close();
  }

  /// Il collo: largo, come si conviene a una testa grande.
  static final Path neckPath = Path()
    ..moveTo(-0.086, -0.76)
    ..lineTo(0.086, -0.76)
    ..quadraticBezierTo(0.088, -0.64, 0.112, -0.58)
    ..lineTo(-0.112, -0.58)
    ..quadraticBezierTo(-0.088, -0.64, -0.086, -0.76)
    ..close();

  /// Le teste che coprono tutto: niente capelli.
  static const _covered = {
    AvatarHead.clownWig,
    AvatarHead.roosterHead,
    AvatarHead.fishHead,
    AvatarHead.dinoHood,
    AvatarHead.octopusHat,
    AvatarHead.rainbowAfro,
    AvatarHead.flamingHair,
  };

  /// Quello che si posa sopra i capelli pettinati: l'aureola, le corna.
  static const _onTop = {
    AvatarHead.angelHalo,
    AvatarHead.devilHorns,
    AvatarHead.astronautHelmet,
    AvatarHead.unicornHorn,
    AvatarHead.spaghettiHat,
    AvatarHead.ufoHat,
    AvatarHead.birthdayCake,
    AvatarHead.starHalo,
    AvatarHead.catOnHead,
  };

  static bool _full(AvatarLook look) => look.bareHead || _onTop.contains(look.hat);

  /// Fin dove salgono i capelli liberi (senza un cappello che li schiacci),
  /// nelle misure della testa e già portati sulla forma della faccia: ci si
  /// posano sopra l'aureola, le corna, il gatto.
  static double hairTop(AvatarLook look) {
    if (_covered.contains(look.hat) || !_full(look)) return -1.1;
    final top = switch (look.features.hair) {
      HairStyle.afro => -1.2,
      HairStyle.coils => -1.15,
      HairStyle.curly => -1.13,
      HairStyle.bun => -1.175,
      HairStyle.updo => -1.185,
      HairStyle.pompadour => -1.16,
      HairStyle.quiff => -1.15,
      HairStyle.flatTop => -1.14,
      HairStyle.bald => -1.06,
      _ => -1.1,
    };
    final g = geometry(look.features.shape);
    return -0.8 + (top + 0.8) * (-0.8 - g.top) / 0.26;
  }

  /// I capelli sono disegnati sulla testa ovale; [fit] li porta sulla testa
  /// vera: larghi quanto la fronte e le tempie, con l'attaccatura alla stessa
  /// distanza dalla sommità. Così una testa tonda non spunta dai lati e una
  /// lunga non resta scoperta in cima.
  static void fit(Canvas canvas, FaceShape shape) {
    final g = geometry(shape);
    final kx = (g.fw + g.cw) / 0.31;
    final ky = (-0.8 - g.top) / 0.26;
    canvas.translate(0, -0.8);
    canvas.scale(kx, ky);
    canvas.translate(0, 0.8);
  }

}
