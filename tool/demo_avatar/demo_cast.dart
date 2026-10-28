// Avatar style demos: the shared cast, the shared geometry and the seat card
// frame. Nothing here is used by the game; see demo_avatar_render_test.dart.
import 'dart:math';

import 'package:flutter/painting.dart';

enum DemoHair { slick, crop, curly, waveBob, updo, softBob }

enum DemoHat { none, fedora, cloche, bowler, crown }

enum DemoGlasses { none, round, shades, monocle }

enum DemoProp { none, cigar, cigarette, carnation }

enum DemoNeck { tie, bowTie, none }

enum DemoBeard { none, mustache, full }

enum DemoOutfit { suit, dress, calcio }

/// One of the six demo characters. Every style paints the same six.
class DemoChar {
  final String name;
  final bool woman;
  final Color skin;
  final Color hair;
  final DemoHair hairStyle;
  final DemoHat hat;
  final Color hatColor;
  final Color hatBand;
  final DemoBeard beard;
  final DemoOutfit outfit;
  final Color cloth;
  final Color shirt;
  final Color accent;
  final Color eye;
  final Color? lips;
  final bool freckles;
  final bool greyTemples;
  final bool pearls;
  final bool stripes;
  final DemoGlasses glasses;
  final DemoProp prop;
  final DemoNeck neck;

  /// The rare skin of the shop: a statue in gold leaf.
  final bool golden;

  const DemoChar({
    required this.name,
    required this.woman,
    required this.skin,
    required this.hair,
    required this.hairStyle,
    this.hat = DemoHat.none,
    this.hatColor = const Color(0xFF2A2626),
    this.hatBand = const Color(0xFF0E0C0C),
    this.beard = DemoBeard.none,
    required this.outfit,
    required this.cloth,
    this.shirt = const Color(0xFFF1E8DA),
    this.accent = const Color(0xFFA3202A),
    this.eye = const Color(0xFF4A2E1C),
    this.lips,
    this.freckles = false,
    this.greyTemples = false,
    this.pearls = false,
    this.stripes = false,
    this.glasses = DemoGlasses.none,
    this.prop = DemoProp.none,
    this.neck = DemoNeck.tie,
    this.golden = false,
  });
}

const demoCast = [
  DemoChar(
    name: 'Vito',
    woman: false,
    skin: Color(0xFFDDAE86),
    hair: Color(0xFF1C1714),
    hairStyle: DemoHair.slick,
    hat: DemoHat.fedora,
    hatColor: Color(0xFF34302E),
    hatBand: Color(0xFF0F0D0D),
    beard: DemoBeard.mustache,
    outfit: DemoOutfit.suit,
    cloth: Color(0xFF2B2D36),
    accent: Color(0xFFA3202A),
    greyTemples: true,
    stripes: true,
  ),
  DemoChar(
    name: 'Rosa',
    woman: true,
    skin: Color(0xFFC68B5E),
    hair: Color(0xFF15100E),
    hairStyle: DemoHair.waveBob,
    outfit: DemoOutfit.dress,
    cloth: Color(0xFF5E1F3C),
    lips: Color(0xFFB0182A),
    eye: Color(0xFF3B2416),
    pearls: true,
  ),
  DemoChar(
    name: 'Tano',
    woman: false,
    skin: Color(0xFF6E4229),
    hair: Color(0xFF110D0B),
    hairStyle: DemoHair.crop,
    beard: DemoBeard.full,
    outfit: DemoOutfit.suit,
    cloth: Color(0xFF1F2B46),
    shirt: Color(0xFFE9DFC8),
    accent: Color(0xFFC8962E),
    eye: Color(0xFF24150D),
  ),
  DemoChar(
    name: 'Lucia',
    woman: true,
    skin: Color(0xFF4B2C1D),
    hair: Color(0xFF0D0908),
    hairStyle: DemoHair.updo,
    outfit: DemoOutfit.dress,
    cloth: Color(0xFF1C5A46),
    lips: Color(0xFF8A2238),
    eye: Color(0xFF1E110A),
    accent: Color(0xFFE2B54E),
  ),
  DemoChar(
    name: 'Totò',
    woman: false,
    skin: Color(0xFFF0C6A0),
    hair: Color(0xFF5A3A22),
    hairStyle: DemoHair.curly,
    outfit: DemoOutfit.calcio,
    cloth: Color(0xFFB3141E),
    shirt: Color(0xFF151313),
    accent: Color(0xFFF4EEE2),
    eye: Color(0xFF5B7A3A),
  ),
  DemoChar(
    name: 'Greta',
    woman: true,
    skin: Color(0xFFF5D6C0),
    hair: Color(0xFFA4471F),
    hairStyle: DemoHair.softBob,
    hat: DemoHat.cloche,
    hatColor: Color(0xFF1F4A4E),
    hatBand: Color(0xFFD9B45A),
    outfit: DemoOutfit.dress,
    cloth: Color(0xFF9C7A52),
    lips: Color(0xFFC2423E),
    eye: Color(0xFF3D6E78),
    freckles: true,
  ),
];

/// The same faces dressed with shop items: hats, suits, glasses, a cigar, a
/// calcio kit and one rare skin.
const demoSkins = [
  DemoChar(
    name: 'Nino',
    woman: false,
    skin: Color(0xFFE6B994),
    hair: Color(0xFF2A1E16),
    hairStyle: DemoHair.slick,
    hat: DemoHat.bowler,
    hatColor: Color(0xFF1C1A1A),
    hatBand: Color(0xFF4A1018),
    beard: DemoBeard.mustache,
    outfit: DemoOutfit.suit,
    cloth: Color(0xFFE8DFCC),
    shirt: Color(0xFFFFFFFF),
    accent: Color(0xFF151313),
    glasses: DemoGlasses.round,
    prop: DemoProp.cigar,
    neck: DemoNeck.bowTie,
  ),
  DemoChar(
    name: 'Mara',
    woman: true,
    skin: Color(0xFF9A6342),
    hair: Color(0xFF2B1A12),
    hairStyle: DemoHair.waveBob,
    hat: DemoHat.cloche,
    hatColor: Color(0xFF6E1626),
    hatBand: Color(0xFF151010),
    outfit: DemoOutfit.dress,
    cloth: Color(0xFF151318),
    lips: Color(0xFF9E1022),
    accent: Color(0xFFEDE6DA),
    glasses: DemoGlasses.shades,
    prop: DemoProp.cigarette,
    pearls: true,
  ),
  DemoChar(
    name: 'Ottavio',
    woman: false,
    skin: Color(0xFF8A5638),
    hair: Color(0xFFBDB6AE),
    hairStyle: DemoHair.crop,
    hat: DemoHat.fedora,
    hatColor: Color(0xFFCDBB98),
    hatBand: Color(0xFF3A2416),
    beard: DemoBeard.full,
    outfit: DemoOutfit.suit,
    cloth: Color(0xFF6B4A2E),
    shirt: Color(0xFFF1E8DA),
    accent: Color(0xFF2E5A3A),
    glasses: DemoGlasses.monocle,
    prop: DemoProp.carnation,
  ),
  DemoChar(
    name: 'Gigi',
    woman: false,
    skin: Color(0xFFC9946A),
    hair: Color(0xFF16110E),
    hairStyle: DemoHair.slick,
    outfit: DemoOutfit.calcio,
    cloth: Color(0xFF1D4FA8),
    shirt: Color(0xFF1D4FA8),
    accent: Color(0xFFF4EEE2),
    eye: Color(0xFF3A2A1C),
    beard: DemoBeard.mustache,
    neck: DemoNeck.none,
  ),
  DemoChar(
    name: 'Nora',
    woman: true,
    skin: Color(0xFFEFC9AE),
    hair: Color(0xFFE8D7A8),
    hairStyle: DemoHair.updo,
    outfit: DemoOutfit.suit,
    cloth: Color(0xFF141416),
    shirt: Color(0xFFF4EEE6),
    accent: Color(0xFF141416),
    lips: Color(0xFFB0182A),
    eye: Color(0xFF3A6A8A),
    neck: DemoNeck.bowTie,
    prop: DemoProp.carnation,
  ),
  DemoChar(
    name: 'Oro',
    woman: false,
    skin: Color(0xFFD9A93E),
    hair: Color(0xFFB98A26),
    hairStyle: DemoHair.curly,
    hat: DemoHat.crown,
    hatColor: Color(0xFFF2C14E),
    hatBand: Color(0xFFB3141E),
    outfit: DemoOutfit.suit,
    cloth: Color(0xFFC79A35),
    shirt: Color(0xFFF6DD8C),
    accent: Color(0xFFB3141E),
    eye: Color(0xFF7A5414),
    golden: true,
    prop: DemoProp.cigar,
  ),
];

Color shade(Color c, double t) => Color.lerp(c, const Color(0xFF0A0610), t)!;
Color tint(Color c, double t) => Color.lerp(c, const Color(0xFFFFF4E0), t)!;

Paint fill(Color c) => Paint()
  ..color = c
  ..isAntiAlias = true;

Paint stroke(Color c, double w, {StrokeCap cap = StrokeCap.round}) => Paint()
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = cap
  ..strokeJoin = StrokeJoin.round;

/// A path symmetric around x = [cx]: [right] are cubic segments (c1, c2, end)
/// of the right half, from the top point down to a point on the axis.
Path mirrored(double cx, Offset top, List<List<Offset>> right) {
  final p = Path()..moveTo(top.dx, top.dy);
  for (final s in right) {
    p.cubicTo(s[0].dx, s[0].dy, s[1].dx, s[1].dy, s[2].dx, s[2].dy);
  }
  // Back up the left side, reversing each segment.
  Offset m(Offset o) => Offset(2 * cx - o.dx, o.dy);
  for (var i = right.length - 1; i >= 0; i--) {
    final s = right[i];
    final start = i == 0 ? top : right[i - 1][2];
    p.cubicTo(m(s[1]).dx, m(s[1]).dy, m(s[0]).dx, m(s[0]).dy, m(start).dx, m(start).dy);
  }
  return p..close();
}

/// The head and body proportions a style asks for, in units of the bust
/// square (0..1). Every shape below comes from these numbers.
class Build {
  final double cx;
  final double cy;
  final double w;
  final double h;

  /// How wide the jaw stays, 0..1 of the head width.
  final double jaw;

  /// How wide the chin is.
  final double chin;
  final double shoulderY;
  final double shoulderW;
  final double neckW;

  const Build({
    this.cx = 0.5,
    required this.cy,
    required this.w,
    required this.h,
    required this.jaw,
    required this.chin,
    required this.shoulderY,
    required this.shoulderW,
    required this.neckW,
  });

  double get r => w / 2;
  double get top => cy - h / 2;
  double get bottom => cy + h / 2;
  double get eyeY => cy + h * 0.05;
  double get eyeDx => r * 0.43;
  double get browY => eyeY - h * 0.105;
  double get noseY => cy + h * 0.21;
  double get mouthY => cy + h * 0.325;

  Path face() => mirrored(cx, Offset(cx, top), [
        [Offset(cx + r * 0.6, top), Offset(cx + r, top + h * 0.17), Offset(cx + r, cy - h * 0.02)],
        [Offset(cx + r, cy + h * 0.15), Offset(cx + r * jaw, cy + h * 0.29), Offset(cx + r * jaw * 0.9, cy + h * 0.35)],
        [Offset(cx + r * jaw * 0.7, cy + h * 0.45), Offset(cx + r * chin, bottom), Offset(cx, bottom)],
      ]);

  Rect ear(int side) => Rect.fromCenter(center: Offset(cx + side * r * 0.97, cy + h * 0.06), width: w * 0.15, height: h * 0.2);

  Path neck() {
    final nw = w * neckW;
    return Path()
      ..moveTo(cx - nw / 2, cy + h * 0.25)
      ..lineTo(cx + nw / 2, cy + h * 0.25)
      ..lineTo(cx + nw / 2 + 0.01, shoulderY + 0.04)
      ..quadraticBezierTo(cx, shoulderY + 0.09, cx - nw / 2 - 0.01, shoulderY + 0.04)
      ..close();
  }

  Path torso() {
    final sw = shoulderW / 2;
    return Path()
      ..moveTo(cx - w * neckW * 0.62, shoulderY - 0.015)
      ..cubicTo(cx - sw * 0.6, shoulderY - 0.01, cx - sw * 0.95, shoulderY + 0.01, cx - sw, shoulderY + 0.09)
      ..lineTo(cx - sw - 0.03, 1.02)
      ..lineTo(cx + sw + 0.03, 1.02)
      ..lineTo(cx + sw, shoulderY + 0.09)
      ..cubicTo(cx + sw * 0.95, shoulderY + 0.01, cx + sw * 0.6, shoulderY - 0.01, cx + w * neckW * 0.62, shoulderY - 0.015)
      ..close();
  }

  /// The open front of a jacket or a neckline: a V down the chest.
  Path vee({double depth = 0.17, double width = 0.5}) {
    final nw = w * neckW * width * 1.3;
    return Path()
      ..moveTo(cx - nw, shoulderY - 0.02)
      ..lineTo(cx + nw, shoulderY - 0.02)
      ..lineTo(cx, shoulderY + depth)
      ..close();
  }

  Path scoop() {
    final nw = w * neckW * 0.95;
    return Path()
      ..moveTo(cx - nw, shoulderY - 0.02)
      ..quadraticBezierTo(cx, shoulderY + 0.17, cx + nw, shoulderY - 0.02)
      ..close();
  }

  Path lapel(int side) {
    final nw = w * neckW * 0.65;
    final s = side.toDouble();
    return Path()
      ..moveTo(cx + s * nw, shoulderY - 0.02)
      ..lineTo(cx + s * 0.005, shoulderY + 0.17)
      ..lineTo(cx + s * 0.06, shoulderY + 0.24)
      ..lineTo(cx + s * 0.075, shoulderY + 0.09)
      ..lineTo(cx + s * 0.12, shoulderY + 0.06)
      ..lineTo(cx + s * (nw + 0.06), shoulderY + 0.0)
      ..close();
  }

  Path tie() => Path()
    ..moveTo(cx - 0.018, shoulderY + 0.02)
    ..lineTo(cx + 0.018, shoulderY + 0.02)
    ..lineTo(cx + 0.012, shoulderY + 0.045)
    ..lineTo(cx + 0.032, shoulderY + 0.2)
    ..lineTo(cx, shoulderY + 0.24)
    ..lineTo(cx - 0.032, shoulderY + 0.2)
    ..lineTo(cx - 0.012, shoulderY + 0.045)
    ..close();

  /// Hair that falls behind the face (bobs, the bun).
  Path? backHair(DemoChar c) {
    switch (c.hairStyle) {
      case DemoHair.waveBob:
        return mirrored(cx, Offset(cx, top - h * 0.07), [
          [Offset(cx + r * 0.85, top - h * 0.07), Offset(cx + r * 1.28, top + h * 0.12), Offset(cx + r * 1.22, cy + h * 0.12)],
          [Offset(cx + r * 1.2, cy + h * 0.27), Offset(cx + r * 1.15, cy + h * 0.36), Offset(cx + r * 0.9, cy + h * 0.35)],
          [Offset(cx + r * 0.6, cy + h * 0.34), Offset(cx + r * 0.2, cy + h * 0.2), Offset(cx, cy + h * 0.2)],
        ]);
      case DemoHair.softBob:
        return mirrored(cx, Offset(cx, top - h * 0.05), [
          [Offset(cx + r * 0.85, top - h * 0.05), Offset(cx + r * 1.2, top + h * 0.15), Offset(cx + r * 1.18, cy + h * 0.1)],
          [Offset(cx + r * 1.28, cy + h * 0.26), Offset(cx + r * 1.05, cy + h * 0.33), Offset(cx + r * 0.88, cy + h * 0.26)],
          [Offset(cx + r * 0.6, cy + h * 0.2), Offset(cx + r * 0.2, cy + h * 0.15), Offset(cx, cy + h * 0.15)],
        ]);
      case DemoHair.updo:
        return Path()..addOval(Rect.fromCircle(center: Offset(cx + r * 0.1, top - h * 0.07), radius: w * 0.24));
      default:
        return null;
    }
  }

  /// The hair on top of the head, in front of the face.
  Path frontHair(DemoChar c) {
    switch (c.hairStyle) {
      case DemoHair.slick:
        return Path()
          ..moveTo(cx - r * 1.03, cy + h * 0.02)
          ..cubicTo(cx - r * 1.12, top - h * 0.02, cx - r * 0.4, top - h * 0.1, cx + r * 0.1, top - h * 0.07)
          ..cubicTo(cx + r * 0.8, top - h * 0.05, cx + r * 1.12, top + h * 0.1, cx + r * 1.03, cy + h * 0.02)
          ..lineTo(cx + r * 0.9, cy - h * 0.06)
          ..cubicTo(cx + r * 0.75, top + h * 0.2, cx + r * 0.1, top + h * 0.12, cx - r * 0.25, top + h * 0.15)
          ..cubicTo(cx - r * 0.7, top + h * 0.18, cx - r * 0.86, top + h * 0.3, cx - r * 0.9, cy - h * 0.06)
          ..close();
      case DemoHair.crop:
        return Path()
          ..moveTo(cx - r * 1.0, cy - h * 0.02)
          ..cubicTo(cx - r * 1.08, top - h * 0.03, cx + r * 1.08, top - h * 0.03, cx + r * 1.0, cy - h * 0.02)
          ..lineTo(cx + r * 0.92, cy - h * 0.08)
          ..cubicTo(cx + r * 0.85, top + h * 0.16, cx + r * 0.2, top + h * 0.13, cx - r * 0.25, top + h * 0.13)
          ..lineTo(cx - r * 0.3, top + h * 0.09)
          ..lineTo(cx - r * 0.38, top + h * 0.135)
          ..cubicTo(cx - r * 0.8, top + h * 0.16, cx - r * 0.9, top + h * 0.3, cx - r * 0.92, cy - h * 0.08)
          ..close();
      case DemoHair.curly:
        // One outline around all the curls, so no curl shows a seam.
        var p = Path();
        void curl(Offset at, double radius) =>
            p = Path.combine(PathOperation.union, p, Path()..addOval(Rect.fromCircle(center: at, radius: radius)));
        const n = 9;
        for (var i = 0; i < n; i++) {
          final a = pi + pi * i / (n - 1);
          curl(Offset(cx + cos(a) * r * 0.92, cy - h * 0.06 + sin(a) * h * 0.5), w * (i.isEven ? 0.17 : 0.15));
        }
        curl(Offset(cx - r * 0.25, top + h * 0.06), w * 0.17);
        curl(Offset(cx + r * 0.3, top + h * 0.05), w * 0.16);
        return p;
      case DemoHair.waveBob:
        return Path()
          ..moveTo(cx - r * 1.08, cy + h * 0.06)
          ..cubicTo(cx - r * 1.2, top - h * 0.06, cx + r * 1.2, top - h * 0.1, cx + r * 1.08, cy + h * 0.06)
          ..cubicTo(cx + r * 0.98, cy - h * 0.06, cx + r * 0.92, top + h * 0.28, cx + r * 0.55, top + h * 0.2)
          ..cubicTo(cx + r * 0.3, top + h * 0.3, cx + r * 0.05, top + h * 0.14, cx - r * 0.25, top + h * 0.22)
          ..cubicTo(cx - r * 0.55, top + h * 0.3, cx - r * 0.85, top + h * 0.22, cx - r * 0.95, cy - h * 0.02)
          ..close();
      case DemoHair.updo:
        return Path()
          ..moveTo(cx - r * 1.02, cy - h * 0.0)
          ..cubicTo(cx - r * 1.1, top - h * 0.05, cx + r * 1.1, top - h * 0.05, cx + r * 1.02, cy - h * 0.0)
          ..lineTo(cx + r * 0.92, cy - h * 0.1)
          ..cubicTo(cx + r * 0.8, top + h * 0.16, cx - r * 0.8, top + h * 0.16, cx - r * 0.92, cy - h * 0.1)
          ..close();
      case DemoHair.softBob:
        return Path()
          ..moveTo(cx - r * 1.08, cy + h * 0.04)
          ..cubicTo(cx - r * 1.15, top, cx + r * 1.15, top, cx + r * 1.08, cy + h * 0.04)
          ..cubicTo(cx + r * 0.9, cy - h * 0.05, cx + r * 0.6, top + h * 0.3, cx + r * 0.1, top + h * 0.27)
          ..cubicTo(cx - r * 0.4, top + h * 0.27, cx - r * 0.9, top + h * 0.3, cx - r * 0.98, cy + h * 0.02)
          ..close();
    }
  }

  /// The brim of a hat ([fedora]) and its crown, as separate shapes.
  (Path brim, Path crown, Path band) hat(DemoChar c) {
    if (c.hat == DemoHat.fedora) {
      final by = top + h * 0.2;
      final bw = w * 0.86;
      final brim = Path()
        ..moveTo(cx - bw, by + h * 0.02)
        ..cubicTo(cx - bw * 0.9, by - h * 0.08, cx + bw * 0.9, by - h * 0.08, cx + bw, by + h * 0.02)
        ..cubicTo(cx + bw * 0.7, by + h * 0.1, cx + bw * 0.3, by + h * 0.12, cx, by + h * 0.12)
        ..cubicTo(cx - bw * 0.3, by + h * 0.12, cx - bw * 0.7, by + h * 0.1, cx - bw, by + h * 0.02)
        ..close();
      final cw = r * 0.98;
      final ct = by - h * 0.36;
      final crown = Path()
        ..moveTo(cx - cw, by)
        ..cubicTo(cx - cw * 1.0, by - h * 0.2, cx - cw * 0.85, ct, cx - cw * 0.45, ct + h * 0.01)
        ..quadraticBezierTo(cx, ct + h * 0.1, cx + cw * 0.45, ct + h * 0.01)
        ..cubicTo(cx + cw * 0.85, ct, cx + cw * 1.0, by - h * 0.2, cx + cw, by)
        ..close();
      final band = Path()
        ..moveTo(cx - cw * 1.0, by - h * 0.005)
        ..lineTo(cx - cw * 0.99, by - h * 0.08)
        ..quadraticBezierTo(cx, by - h * 0.06, cx + cw * 0.99, by - h * 0.08)
        ..lineTo(cx + cw * 1.0, by - h * 0.005)
        ..quadraticBezierTo(cx, by + h * 0.02, cx - cw * 1.0, by - h * 0.005)
        ..close();
      return (brim, crown, band);
    }
    if (c.hat == DemoHat.bowler) {
      final by = top + h * 0.2;
      final bw = w * 0.66;
      final brim = Path()
        ..moveTo(cx - bw, by - h * 0.03)
        ..quadraticBezierTo(cx - bw * 0.9, by + h * 0.04, cx, by + h * 0.06)
        ..quadraticBezierTo(cx + bw * 0.9, by + h * 0.04, cx + bw, by - h * 0.03)
        ..quadraticBezierTo(cx, by - h * 0.0, cx - bw, by - h * 0.03)
        ..close();
      final crown = Path()
        ..moveTo(cx - r * 0.9, by)
        ..cubicTo(cx - r * 0.98, by - h * 0.42, cx + r * 0.98, by - h * 0.42, cx + r * 0.9, by)
        ..close();
      final band = Path()
        ..moveTo(cx - r * 0.91, by - h * 0.005)
        ..lineTo(cx - r * 0.93, by - h * 0.065)
        ..quadraticBezierTo(cx, by - h * 0.045, cx + r * 0.93, by - h * 0.065)
        ..lineTo(cx + r * 0.91, by - h * 0.005)
        ..close();
      return (brim, crown, band);
    }
    if (c.hat == DemoHat.crown) {
      final by = top + h * 0.12;
      final cw = r * 0.95;
      final crown = Path()
        ..moveTo(cx - cw, by)
        ..lineTo(cx - cw * 1.08, by - h * 0.3)
        ..lineTo(cx - cw * 0.55, by - h * 0.14)
        ..lineTo(cx, by - h * 0.36)
        ..lineTo(cx + cw * 0.55, by - h * 0.14)
        ..lineTo(cx + cw * 1.08, by - h * 0.3)
        ..lineTo(cx + cw, by)
        ..close();
      final band = Path()..addRect(Rect.fromLTRB(cx - cw * 1.0, by - h * 0.07, cx + cw * 1.0, by));
      // For the crown the "brim" is its jewels.
      final brim = Path()
        ..addOval(Rect.fromCircle(center: Offset(cx, by - h * 0.035), radius: w * 0.04))
        ..addOval(Rect.fromCircle(center: Offset(cx - cw * 0.6, by - h * 0.035), radius: w * 0.03))
        ..addOval(Rect.fromCircle(center: Offset(cx + cw * 0.6, by - h * 0.035), radius: w * 0.03));
      return (brim, crown, band);
    }
    // The cloche: a bell down to the brows, with a short flared brim.
    final by = browY - h * 0.005;
    final crown = Path()
      ..moveTo(cx - r * 1.12, by)
      ..cubicTo(cx - r * 1.22, top - h * 0.12, cx + r * 1.22, top - h * 0.12, cx + r * 1.12, by)
      ..close();
    final brim = Path()
      ..moveTo(cx - r * 1.24, by + h * 0.07)
      ..quadraticBezierTo(cx - r * 1.2, by - h * 0.06, cx - r * 0.9, by - h * 0.04)
      ..quadraticBezierTo(cx, by - h * 0.0, cx + r * 0.9, by - h * 0.04)
      ..quadraticBezierTo(cx + r * 1.2, by - h * 0.06, cx + r * 1.24, by + h * 0.07)
      ..quadraticBezierTo(cx, by + h * 0.03, cx - r * 1.24, by + h * 0.07)
      ..close();
    final band = Path()
      ..moveTo(cx - r * 1.13, by - h * 0.06)
      ..quadraticBezierTo(cx, by - h * 0.03, cx + r * 1.13, by - h * 0.06)
      ..lineTo(cx + r * 1.08, by - h * 0.13)
      ..quadraticBezierTo(cx, by - h * 0.1, cx - r * 1.08, by - h * 0.13)
      ..close();
    return (brim, crown, band);
  }

  Path mustache() => Path()
    ..moveTo(cx, mouthY - h * 0.055)
    ..cubicTo(cx + w * 0.06, mouthY - h * 0.085, cx + w * 0.15, mouthY - h * 0.07, cx + w * 0.17, mouthY - h * 0.005)
    ..cubicTo(cx + w * 0.11, mouthY - h * 0.03, cx + w * 0.05, mouthY - h * 0.02, cx, mouthY - h * 0.03)
    ..cubicTo(cx - w * 0.05, mouthY - h * 0.02, cx - w * 0.11, mouthY - h * 0.03, cx - w * 0.17, mouthY - h * 0.005)
    ..cubicTo(cx - w * 0.15, mouthY - h * 0.07, cx - w * 0.06, mouthY - h * 0.085, cx, mouthY - h * 0.055)
    ..close();

  /// A full beard: the lower face from ear to ear, with a gap for the mouth.
  Path beard() {
    final beard = mirrored(cx, Offset(cx, noseY + h * 0.05), [
      [Offset(cx + r * 0.45, noseY + h * 0.02), Offset(cx + r * 0.75, noseY + h * 0.02), Offset(cx + r * 0.99, cy + h * 0.06)],
      [Offset(cx + r * 1.04, cy + h * 0.2), Offset(cx + r * 0.95, cy + h * 0.42), Offset(cx + r * 0.55, bottom + h * 0.05)],
      [Offset(cx + r * 0.3, bottom + h * 0.1), Offset(cx + r * 0.1, bottom + h * 0.11), Offset(cx, bottom + h * 0.11)],
    ]);
    final mouth = Path()..addOval(Rect.fromCenter(center: Offset(cx, mouthY + h * 0.01), width: w * 0.26, height: h * 0.06));
    return Path.combine(PathOperation.difference, beard, mouth);
  }
}

/// Shop props, shared by the styles: glasses, cigars, flowers, bow ties.
/// [ink] is the line of the style, [lw] its weight, [bold] draws a heavy
/// silhouette first (the noir style).
class Extras {
  final Canvas canvas;
  final Build b;
  final Color ink;
  final double lw;
  final bool bold;
  const Extras(this.canvas, this.b, {required this.ink, required this.lw, this.bold = false});

  void _shape(Path p, Color color) {
    if (bold) canvas.drawPath(p, stroke(ink, lw * 2.2));
    canvas.drawPath(p, fill(color));
    if (!bold) canvas.drawPath(p, stroke(ink, lw));
  }

  void glasses(DemoChar c) {
    final y = b.eyeY;
    final dx = b.eyeDx;
    final rr = b.w * 0.13;
    switch (c.glasses) {
      case DemoGlasses.none:
        return;
      case DemoGlasses.round:
        for (final s in [-1, 1]) {
          final at = Offset(b.cx + s * dx, y);
          canvas.drawCircle(at, rr, fill(const Color(0x22CFE6FF)));
          canvas.drawCircle(at, rr, stroke(const Color(0xFF2A1C10), lw * (bold ? 2.2 : 1.5)));
          canvas.drawArc(Rect.fromCircle(center: at, radius: rr * 0.7), pi * 1.1, pi * 0.35, false, stroke(const Color(0x99FFFFFF), lw));
        }
        canvas.drawLine(Offset(b.cx - dx + rr, y - rr * 0.2), Offset(b.cx + dx - rr, y - rr * 0.2), stroke(const Color(0xFF2A1C10), lw * 1.4));
      case DemoGlasses.shades:
        for (final s in [-1, 1]) {
          final r = Rect.fromCenter(center: Offset(b.cx + s * dx, y + b.h * 0.005), width: rr * 2.3, height: rr * 1.5);
          final p = Path()
            ..addRRect(RRect.fromRectAndCorners(r,
                topLeft: Radius.circular(rr * 0.3),
                topRight: Radius.circular(rr * 0.3),
                bottomLeft: Radius.circular(rr * 0.9),
                bottomRight: Radius.circular(rr * 0.9)));
          _shape(p, const Color(0xFF0E0C10));
          canvas.drawLine(r.topLeft.translate(rr * 0.4, rr * 0.35), r.topLeft.translate(rr * 0.9, rr * 0.35), stroke(const Color(0x88FFFFFF), lw * 1.2));
        }
        canvas.drawLine(Offset(b.cx - dx + rr * 1.1, y - rr * 0.3), Offset(b.cx + dx - rr * 1.1, y - rr * 0.3), stroke(const Color(0xFF0E0C10), lw * 2));
      case DemoGlasses.monocle:
        final at = Offset(b.cx + dx, y);
        canvas.drawCircle(at, rr * 1.05, fill(const Color(0x22FFFFFF)));
        canvas.drawCircle(at, rr * 1.05, stroke(const Color(0xFFD9B45A), lw * (bold ? 2.4 : 1.6)));
        final chain = Path()
          ..moveTo(at.dx + rr, at.dy + rr * 0.3)
          ..quadraticBezierTo(at.dx + rr * 1.6, b.cy + b.h * 0.4, at.dx + rr * 0.6, b.shoulderY + 0.06);
        canvas.drawPath(chain, stroke(const Color(0xFFD9B45A), lw * 0.9));
    }
  }

  void neckwear(DemoChar c) {
    if (c.outfit != DemoOutfit.suit || c.neck != DemoNeck.bowTie) return;
    final y = b.shoulderY + 0.03;
    final p = Path()
      ..moveTo(b.cx, y)
      ..lineTo(b.cx - 0.07, y - 0.035)
      ..lineTo(b.cx - 0.07, y + 0.035)
      ..close()
      ..moveTo(b.cx, y)
      ..lineTo(b.cx + 0.07, y - 0.035)
      ..lineTo(b.cx + 0.07, y + 0.035)
      ..close();
    _shape(p, c.accent);
    canvas.drawCircle(Offset(b.cx, y), 0.018, fill(tint(c.accent, 0.2)));
  }

  void prop(DemoChar c) {
    switch (c.prop) {
      case DemoProp.none:
        return;
      case DemoProp.cigar:
      case DemoProp.cigarette:
        final cigar = c.prop == DemoProp.cigar;
        final from = Offset(b.cx + b.w * 0.08, b.mouthY + b.h * 0.005);
        final to = from + Offset(b.w * (cigar ? 0.36 : 0.34), b.h * (cigar ? 0.08 : -0.03));
        final t = cigar ? b.w * 0.07 : b.w * 0.035;
        canvas.drawLine(from, to, stroke(ink, t + lw * (bold ? 2.2 : 1.2), cap: StrokeCap.butt));
        canvas.drawLine(from, to, stroke(cigar ? const Color(0xFF6B3E20) : const Color(0xFFF4EEE4), t, cap: StrokeCap.butt));
        if (cigar) {
          canvas.drawLine(Offset.lerp(from, to, 0.3)!, Offset.lerp(from, to, 0.4)!, stroke(const Color(0xFFC9372C), t, cap: StrokeCap.butt));
        }
        canvas.drawCircle(to, t * 0.55, fill(const Color(0xFFFF7A3B)));
        final smoke = Path()
          ..moveTo(to.dx, to.dy - t * 0.6)
          ..cubicTo(to.dx + 0.04, to.dy - 0.06, to.dx - 0.03, to.dy - 0.1, to.dx + 0.01, to.dy - 0.17)
          ..cubicTo(to.dx + 0.04, to.dy - 0.22, to.dx + 0.0, to.dy - 0.26, to.dx + 0.03, to.dy - 0.3);
        canvas.drawPath(smoke, stroke(const Color(0x55E8E2D8), max(lw * 1.6, 0.012)));
      case DemoProp.carnation:
        final at = Offset(b.cx - 0.2, b.shoulderY + 0.08);
        canvas.drawLine(at, at + const Offset(0.02, 0.06), stroke(const Color(0xFF2E5A2A), lw * 1.5));
        if (bold) canvas.drawCircle(at, 0.036, fill(ink));
        for (var i = 0; i < 6; i++) {
          final a = i * pi / 3;
          canvas.drawCircle(at + Offset(cos(a), sin(a)) * 0.016, 0.016, fill(const Color(0xFFC8102E)));
        }
        canvas.drawCircle(at, 0.015, fill(const Color(0xFF8E0A20)));
    }
  }

  /// The gold-leaf skin: a sheen across the whole figure.
  void gilt() {
    const area = Rect.fromLTRB(0, 0, 1, 1);
    canvas.drawRect(
      area,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = const LinearGradient(
          begin: Alignment(-1, -0.6),
          end: Alignment(1, 0.6),
          colors: [Color(0x00000000), Color(0x00000000), Color(0x55FFF2C0), Color(0x00000000), Color(0x00000000), Color(0x33FFF2C0), Color(0x00000000)],
          stops: [0, 0.3, 0.38, 0.46, 0.6, 0.66, 0.72],
        ).createShader(area),
    );
  }
}

/// A bust style:paints [c] into a square of side [side], no background.
typedef BustPainter = void Function(Canvas canvas, DemoChar c, double side);

/// The seat card of the game table (lib/ui/screens/online/game/seat_card.dart),
/// redrawn here so the demos can sit in it: the arch, the brass edge, the
/// dark wood gradient and the name plate. [avatar] is the portrait size the
/// real card would give it (86% of the card width).
void paintSeatCard(Canvas canvas, Offset at, double width, DemoChar c, BustPainter bust) {
  const brassDeep = Color(0xFF8C6A26);
  const ink = Color(0xFF0C0907);
  const textPrimary = Color(0xFFF2EAE1);
  final height = width * 1.32;
  final plate = max(20.0, width * 0.27);
  canvas.save();
  canvas.translate(at.dx, at.dy);
  final portrait = Rect.fromLTWH(0, 0, width, height - plate * 0.45);
  final arch = RRect.fromRectAndCorners(
    portrait,
    topLeft: Radius.circular(width / 2),
    topRight: Radius.circular(width / 2),
    bottomLeft: Radius.circular(width * 0.12),
    bottomRight: Radius.circular(width * 0.12),
  );
  canvas.drawRRect(arch.shift(const Offset(0, 5)), Paint()
    ..color = const Color(0xAA000000)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
  canvas.drawRRect(
    arch,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF3A2A1E), Color(0xFF120C08)],
      ).createShader(portrait),
  );
  canvas.save();
  canvas.clipRRect(arch);
  final a = width * 0.86;
  canvas.save();
  canvas.translate((width - a) / 2, (portrait.height - a) * 0.45);
  bust(canvas, c, a);
  canvas.restore();
  canvas.restore();
  canvas.drawRRect(arch.deflate(0.7), stroke(brassDeep, 1.4));
  final plateRect = RRect.fromRectAndRadius(Rect.fromLTWH(-width * 0.08, height - plate, width * 1.16, plate), Radius.circular(plate / 2));
  canvas.drawRRect(plateRect.shift(const Offset(0, 2)), Paint()
    ..color = const Color(0xFF000000)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
  canvas.drawRRect(plateRect, fill(ink));
  canvas.drawRRect(plateRect.deflate(0.5), stroke(brassDeep, 1));
  final tp = TextPainter(
    text: TextSpan(
      text: c.name.toUpperCase(),
      style: TextStyle(fontFamily: 'Georgia', fontSize: plate * 0.64, fontWeight: FontWeight.bold, color: textPrimary, letterSpacing: 0.6, height: 1.05),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final fit = min(1.0, (plateRect.width - plate * 0.56) / tp.width);
  canvas.save();
  canvas.translate(plateRect.center.dx, plateRect.center.dy);
  canvas.scale(fit);
  tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
  canvas.restore();
  tp.dispose();
  canvas.restore();
}
