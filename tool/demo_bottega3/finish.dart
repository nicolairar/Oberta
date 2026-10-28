// Bottega demos, round three: two finishes for the shop's buttons, back
// plate and purse. A, "Targa": oxblood enamel in a bevelled brass frame,
// round medallions. B, "Deco": champagne gold and black lacquer with cut
// corners, like a 1920s theatre ticket. Nothing here is used by the game.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:oberta/ui/street/street_facade.dart';
import 'package:oberta/ui/street/street_neon.dart';
import 'package:oberta/ui/street/street_section.dart';
import 'package:oberta/ui/street/street_wall.dart';

import '../demo_bottega2/kit.dart' show Coin, cream, brass, brassDeep, ink;

enum Finish { targa, deco }

const _gold = [Color(0xFFFFE7A8), Color(0xFFD9B45A), Color(0xFF9C7424), Color(0xFFC9A23E)];
const _goldStops = [0.0, 0.42, 0.78, 1.0];
const _champagne = [Color(0xFFF7E6B5), Color(0xFFE2C27A), Color(0xFFB8913E)];

TextStyle _caps(double size, Color color, {double spacing = 2.4}) => TextStyle(
  fontFamily: 'Georgia',
  fontSize: size,
  fontWeight: FontWeight.bold,
  letterSpacing: spacing,
  color: color,
  height: 1.0,
);

/// The two frames every control is cut from.
ShapeBorder _shape(Finish f, double radius) => f == Finish.targa
    ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius))
    : BeveledRectangleBorder(borderRadius: BorderRadius.circular(radius * 0.8));

/// A frame of brass, a hairline inside it, and the face.
class _Framed extends StatelessWidget {
  final Finish finish;
  final double radius;
  final double rim;
  final Gradient face;
  final Color hairline;
  final bool glow;
  final Widget child;
  const _Framed({
    required this.finish,
    required this.radius,
    required this.face,
    required this.child,
    this.rim = 2,
    this.hairline = const Color(0x66FFE7A8),
    this.glow = false,
  });

  @override
  Widget build(BuildContext context) => Container(
    decoration: ShapeDecoration(
      shape: _shape(finish, radius),
      gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: _gold, stops: _goldStops),
      shadows: [
        const BoxShadow(color: Color(0xB3000000), blurRadius: 10, offset: Offset(0, 5)),
        if (glow) const BoxShadow(color: Color(0x40FFB443), blurRadius: 20),
      ],
    ),
    padding: EdgeInsets.all(rim),
    child: Container(
      decoration: ShapeDecoration(shape: _shape(finish, radius - rim), gradient: face),
      child: Container(
        margin: EdgeInsets.all(rim * 0.9),
        decoration: ShapeDecoration(shape: _shape(finish, radius - rim * 2).copyWith(side: BorderSide(color: hairline, width: 0.8))),
        child: child,
      ),
    ),
  );
}

extension on ShapeBorder {
  ShapeBorder copyWith({required BorderSide side}) => switch (this) {
    final RoundedRectangleBorder r => r.copyWith(side: side),
    final BeveledRectangleBorder b => b.copyWith(side: side),
    _ => this,
  };
}

/// The main action: Compra with the price set into it.
class PrimaryButton extends StatelessWidget {
  final Finish finish;
  final String label;
  final int? price;
  final double height;
  final bool expand;
  const PrimaryButton({super.key, required this.finish, this.label = 'COMPRA', this.price, this.height = 54, this.expand = false});

  @override
  Widget build(BuildContext context) {
    final k = height / 54;
    final targa = finish == Finish.targa;
    final text = targa ? const Color(0xFFFFF1D6) : const Color(0xFF1A1006);
    final face = targa
        ? const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFB3242E), Color(0xFF7E111A), Color(0xFF4A070D)], stops: [0, 0.55, 1])
        : const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: _champagne);
    final row = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(width: 18 * k),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label, style: _caps(17 * k, text, spacing: 3 * k).copyWith(
              shadows: targa ? const [Shadow(color: Color(0x99000000), offset: Offset(0, 1.5), blurRadius: 1)] : const [Shadow(color: Color(0x66FFFFFF), offset: Offset(0, 1))],
            )),
          ),
        ),
        if (price != null) ...[
          SizedBox(width: 14 * k),
          // The price sits in a recessed socket, like a coin slot.
          Container(
            height: height * 0.62,
            padding: EdgeInsets.fromLTRB(6 * k, 0, 10 * k, 0),
            decoration: ShapeDecoration(
              shape: targa ? const StadiumBorder() : BeveledRectangleBorder(borderRadius: BorderRadius.circular(8 * k)),
              color: targa ? const Color(0xCC1A0306) : const Color(0xFF15100A),
              shadows: const [BoxShadow(color: Color(0x55FFFFFF), offset: Offset(0, 1))],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Coin(size: 20 * k),
                SizedBox(width: 6 * k),
                Text('$price', style: TextStyle(color: const Color(0xFFFFE7A8), fontSize: 16 * k, fontWeight: FontWeight.w800, fontFeatures: const [FontFeature.tabularFigures()])),
              ],
            ),
          ),
          SizedBox(width: 8 * k),
        ] else
          SizedBox(width: 18 * k),
      ],
    );
    final body = SizedBox(height: height, child: Stack(children: [
      // A soft gloss across the top half.
      Positioned(left: 4, right: 4, top: 1, height: height * 0.36, child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: _shape(finish, 8),
          gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x38FFFFFF), Color(0x00FFFFFF)]),
        ),
      )),
      Center(child: row),
    ]));
    return _Framed(finish: finish, radius: targa ? 14 * k : 14 * k, rim: 2.2 * k, face: face, glow: true, hairline: targa ? const Color(0x77FFD9A0) : const Color(0x88553A10), child: body);
  }
}

/// The second action (Regala, Prova, Equip): dark lacquer, brass letters.
class SecondaryButton extends StatelessWidget {
  final Finish finish;
  final String label;
  final IconData? icon;
  final double height;
  final bool expand;
  const SecondaryButton({super.key, required this.finish, required this.label, this.icon, this.height = 54, this.expand = false});

  @override
  Widget build(BuildContext context) {
    final k = height / 54;
    return _Framed(
      finish: finish,
      radius: 14 * k,
      rim: 1.4 * k,
      face: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF2A211B), Color(0xFF15100C), ink]),
      hairline: const Color(0x33FFE7A8),
      child: SizedBox(
        height: height - 4.2 * k,
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(width: 16 * k),
            if (icon != null) ...[Icon(icon, size: 18 * k, color: brass), SizedBox(width: 8 * k)],
            Text(label, style: _caps(14 * k, brass, spacing: 2.4 * k)),
            SizedBox(width: 16 * k),
          ],
        ),
      ),
    );
  }
}

/// A round (A) or cut-diamond (B) plate holding one icon.
class IconPlate extends StatelessWidget {
  final Finish finish;
  final IconData icon;
  final double size;
  final int? badge;
  const IconPlate({super.key, required this.finish, required this.icon, this.size = 44, this.badge});

  @override
  Widget build(BuildContext context) {
    final face = const RadialGradient(center: Alignment(0, -0.5), radius: 1, colors: [Color(0xFF2E241C), Color(0xFF0E0A08)]);
    final inner = Icon(icon, size: size * 0.46, color: const Color(0xFFF0D590));
    final plate = finish == Finish.targa
        ? Container(
            width: size,
            height: size,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: _gold, stops: _goldStops),
              boxShadow: [BoxShadow(color: Color(0xB3000000), blurRadius: 8, offset: Offset(0, 4))],
            ),
            padding: EdgeInsets.all(size * 0.05),
            child: Container(
              decoration: BoxDecoration(shape: BoxShape.circle, gradient: face, border: Border.all(color: const Color(0x55FFE7A8), width: 0.8)),
              child: Center(child: inner),
            ),
          )
        : SizedBox.square(dimension: size, child: _Framed(finish: finish, radius: size * 0.3, rim: 1.6, face: face, child: Center(child: inner)));
    if (badge == null) return plate;
    return Stack(clipBehavior: Clip.none, children: [
      plate,
      Positioned(
        right: -3,
        top: -3,
        child: Container(
          width: 18,
          height: 18,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: const Color(0xFFB3242E), shape: BoxShape.circle, border: Border.all(color: const Color(0xFFFFE7A8), width: 1.2)),
          child: Text('$badge', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
        ),
      ),
    ]);
  }
}

/// The way back: a slim chevron in the finish's plate.
class BackControl extends StatelessWidget {
  final Finish finish;
  final double size;
  const BackControl({super.key, required this.finish, this.size = 44});

  @override
  Widget build(BuildContext context) => IconPlate(finish: finish, icon: Icons.arrow_back_ios_new_rounded, size: size);
}

/// The purse: the coin bigger than its pill and sitting over its edge, the
/// sum in tabular figures, a small + to top up.
class Purse3 extends StatelessWidget {
  final Finish finish;
  final int coins;
  final double scale;
  const Purse3({super.key, required this.finish, required this.coins, this.scale = 1});

  @override
  Widget build(BuildContext context) {
    final k = scale;
    final targa = finish == Finish.targa;
    final h = 30 * k;
    final text = Text(
      _thousands(coins),
      style: TextStyle(color: cream, fontSize: 15 * k, fontWeight: FontWeight.w800, letterSpacing: 0.6, fontFeatures: const [FontFeature.tabularFigures()]),
    );
    final plus = Container(
      width: h - 8 * k,
      height: h - 8 * k,
      decoration: ShapeDecoration(
        shape: targa ? const CircleBorder() : BeveledRectangleBorder(borderRadius: BorderRadius.circular(6 * k)),
        gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: _gold, stops: _goldStops),
      ),
      child: Icon(Icons.add, size: 14 * k, color: const Color(0xFF2A1A06)),
    );
    return SizedBox(
      height: 38 * k,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          Container(
            margin: EdgeInsets.only(left: 14 * k),
            height: h,
            padding: EdgeInsets.fromLTRB(26 * k, 0, 4 * k, 0),
            decoration: ShapeDecoration(
              shape: targa
                  ? const StadiumBorder(side: BorderSide(color: Color(0x99D9B45A), width: 1))
                  : BeveledRectangleBorder(borderRadius: BorderRadius.circular(9 * k), side: const BorderSide(color: Color(0xCCD9B45A), width: 1)),
              gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xF2201812), Color(0xF20A0807)]),
              shadows: const [BoxShadow(color: Color(0x99000000), blurRadius: 8, offset: Offset(0, 3))],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [text, SizedBox(width: 8 * k), plus]),
          ),
          Container(
            decoration: const BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: Color(0xAA000000), blurRadius: 6, offset: Offset(0, 2))]),
            child: Coin(size: 36 * k),
          ),
        ],
      ),
    );
  }
}

String _thousands(int n) {
  final s = '$n';
  return s.length <= 3 ? s : '${s.substring(0, s.length - 3)}.${s.substring(s.length - 3)}';
}

/// Time left on a featured or seasonal piece.
class TimerBadge extends StatelessWidget {
  final Finish finish;
  final String text;
  final double scale;
  const TimerBadge({super.key, required this.finish, required this.text, this.scale = 1});

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: 7 * scale, vertical: 3 * scale),
    decoration: ShapeDecoration(
      shape: finish == Finish.targa ? const StadiumBorder() : BeveledRectangleBorder(borderRadius: BorderRadius.circular(5 * scale)),
      color: const Color(0xFFE07A1F),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.schedule, size: 11 * scale, color: const Color(0xFF1A0E04)),
      SizedBox(width: 3 * scale),
      Text(text, style: TextStyle(color: const Color(0xFF1A0E04), fontSize: 10.5 * scale, fontWeight: FontWeight.w900, letterSpacing: 0.4)),
    ]),
  );
}

/// A filter chip: thin outline, filled when on.
class FilterChip3 extends StatelessWidget {
  final Finish finish;
  final String label;
  final bool on;
  final Color? dot;
  final double scale;
  final bool close;
  const FilterChip3({super.key, required this.finish, required this.label, this.on = false, this.dot, this.scale = 1, this.close = false});

  @override
  Widget build(BuildContext context) => Container(
    height: 28 * scale,
    padding: EdgeInsets.symmetric(horizontal: 11 * scale),
    decoration: ShapeDecoration(
      shape: finish == Finish.targa
          ? StadiumBorder(side: BorderSide(color: on ? brass : const Color(0xFF4A3A2A)))
          : BeveledRectangleBorder(borderRadius: BorderRadius.circular(7 * scale), side: BorderSide(color: on ? brass : const Color(0xFF4A3A2A))),
      color: on ? const Color(0x40D9B45A) : const Color(0xCC0C0907),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      if (dot != null) ...[Container(width: 7 * scale, height: 7 * scale, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)), SizedBox(width: 6 * scale)],
      Text(label, style: TextStyle(color: on ? cream : const Color(0xFFB0A090), fontSize: 12 * scale, fontWeight: on ? FontWeight.w800 : FontWeight.w600)),
      if (close) ...[SizedBox(width: 5 * scale), Icon(Icons.close, size: 13 * scale, color: brass)],
    ]),
  );
}

/// The wall and the neon, with the new back control and purse.
class Stage3 extends StatelessWidget {
  final Finish finish;
  final bool desk;
  final int coins;
  final Widget Function(BuildContext context, StreetFacadeLayout layout) builder;
  const Stage3({super.key, required this.finish, required this.builder, this.desk = false, this.coins = 3800});

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final layout = StreetFacadeLayout(media.size, media.padding, desk: desk);
    const section = StreetSection.shop;
    final mid = layout.neon.center.dy;
    final k = desk ? 1.3 : 1.0;
    return Scaffold(
      backgroundColor: const Color(0xFF07070B),
      body: Stack(
        fit: StackFit.expand,
        children: [
          StreetWallLayer(wall: layout.wall, index: 1, fixed: const [], own: layout.lightsOf(section)),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x00000000), Color(0x66000000), Color(0xEE07060A)],
                stops: [0.12, 0.45, 0.78],
              ),
            ),
          ),
          Positioned.fromRect(rect: desk ? layout.neon : Rect.fromLTRB(60, layout.neon.top, layout.size.width - 108, layout.neon.bottom), child: CustomPaint(painter: StreetNeonPainter(text: section.it, color: section.neon, power: 1))),
          builder(context, layout),
          Positioned(left: desk ? 28 : 10, top: mid - 22 * k, child: BackControl(finish: finish, size: 44 * k)),
          Positioned(right: desk ? 28 : 8, top: mid - 19 * k, child: Purse3(finish: finish, coins: coins, scale: desk ? k : 0.8)),
        ],
      ),
    );
  }
}

/// The brass dial of the mobile shop.
class Dial3Painter extends CustomPainter {
  final double inner;
  const Dial3Painter({this.inner = 112});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    canvas.drawCircle(c.translate(0, -6), r + 4, Paint()
      ..color = const Color(0xAA000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18));
    canvas.drawCircle(c, r, Paint()
      ..shader = const SweepGradient(colors: [Color(0xFFFFE29A), Color(0xFF8C6A14), Color(0xFFC9A227), Color(0xFF5A420C), Color(0xFFFFE29A)])
          .createShader(Rect.fromCircle(center: c, radius: r)));
    canvas.drawCircle(c, r - 6, Paint()
      ..shader = const RadialGradient(colors: [Color(0xFF0C0907), Color(0xFF1E1510), Color(0xFF2A1D14)], stops: [0.5, 0.86, 1])
          .createShader(Rect.fromCircle(center: c, radius: r)));
    final tick = Paint()
      ..color = const Color(0x55D9B45A)
      ..strokeWidth = 1.2;
    for (var i = 0; i < 120; i++) {
      final a = i * 2 * pi / 120;
      final d = Offset(sin(a), -cos(a));
      canvas.drawLine(c + d * (r - 11), c + d * (r - (i % 5 == 0 ? 20 : 15)), tick);
    }
    canvas.drawCircle(c, r - inner, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x44D9B45A));
  }

  @override
  bool shouldRepaint(Dial3Painter old) => old.inner != inner;
}

class Notch3Painter extends CustomPainter {
  const Notch3Painter();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(p.shift(const Offset(0, 2)), Paint()..color = const Color(0xAA000000));
    canvas.drawPath(p, Paint()..color = const Color(0xFFFFE29A));
    canvas.drawPath(p, Paint()
      ..style = PaintingStyle.stroke
      ..color = brassDeep);
  }

  @override
  bool shouldRepaint(Notch3Painter old) => false;
}
