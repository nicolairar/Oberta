// Bottega demos, round two: the pieces the three concepts share. The game
// never imports this; it is drawn only by bottega2_render_test.dart, with
// the cartoon-noir busts of tool/demo_avatar/style_noir.dart.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:oberta/online/shop_models.dart';
import 'package:oberta/ui/screens/shop/shop_screen.dart' show rarityColor;
import 'package:oberta/ui/street/street_facade.dart';
import 'package:oberta/ui/street/street_neon.dart';
import 'package:oberta/ui/street/street_section.dart';
import 'package:oberta/ui/street/street_wall.dart';
import 'package:oberta/ui/theme/app_theme.dart';
import 'package:oberta/ui/widgets/home_account.dart' show CoinPainter;

import '../demo_avatar/demo_cast.dart';
import '../demo_avatar/style_noir.dart';

const cream = Color(0xFFF2E6CF);
const brass = Color(0xFFD9B45A);
const brassDeep = Color(0xFF8C6A26);
const ink = Color(0xFF0C0907);
const leather = Color(0xFF1B130E);

/// The places on the body a piece goes.
enum Slot {
  hat('CAPPELLO', Icons.school_outlined),
  face('VOLTO', Icons.visibility_outlined),
  suit('ABITO', Icons.checkroom),
  vice('VIZIO', Icons.local_fire_department_outlined),
  skin('PELLE', Icons.auto_awesome);

  final String label;
  final IconData icon;
  const Slot(this.label, this.icon);
}

String rarityLabel(ShopRarity r) => switch (r) {
  ShopRarity.base => 'BASE',
  ShopRarity.comune => 'COMUNE',
  ShopRarity.raro => 'RARO',
  ShopRarity.epico => 'EPICO',
  ShopRarity.leggendario => 'LEGGENDARIO',
};

/// A copy of [c] with some pieces changed.
DemoChar wear(
  DemoChar c, {
  DemoHat? hat,
  Color? hatColor,
  Color? hatBand,
  DemoGlasses? glasses,
  DemoProp? prop,
  DemoOutfit? outfit,
  Color? cloth,
  Color? shirt,
  Color? accent,
  bool? stripes,
  DemoNeck? neck,
  DemoBeard? beard,
  Color? skin,
  Color? hair,
  bool? golden,
  bool? greyTemples,
}) => DemoChar(
  name: c.name,
  woman: c.woman,
  skin: skin ?? c.skin,
  hair: hair ?? c.hair,
  hairStyle: c.hairStyle,
  hat: hat ?? c.hat,
  hatColor: hatColor ?? c.hatColor,
  hatBand: hatBand ?? c.hatBand,
  beard: beard ?? c.beard,
  outfit: outfit ?? c.outfit,
  cloth: cloth ?? c.cloth,
  shirt: shirt ?? c.shirt,
  accent: accent ?? c.accent,
  eye: c.eye,
  lips: c.lips,
  freckles: c.freckles,
  greyTemples: greyTemples ?? c.greyTemples,
  pearls: c.pearls,
  stripes: stripes ?? c.stripes,
  glasses: glasses ?? c.glasses,
  prop: prop ?? c.prop,
  neck: neck ?? c.neck,
  golden: golden ?? c.golden,
);

/// The player as he walks in: grey borsalino, charcoal pinstripe.
final player = wear(demoCast[0], greyTemples: false);

class Piece {
  final String name;
  final Slot slot;
  final ShopRarity rarity;
  final int price;
  final String? brand;

  /// The part of the bust its thumbnail zooms on, in bust units.
  final Rect focus;
  final DemoChar Function(DemoChar) apply;
  final bool owned;
  final bool worn;

  const Piece(this.name, this.slot, this.rarity, this.price, this.focus, this.apply, {this.brand, this.owned = false, this.worn = false});
}

const _hatFocus = Rect.fromLTWH(0.1, 0.04, 0.8, 0.6);
const _faceFocus = Rect.fromLTWH(0.18, 0.3, 0.64, 0.48);
const _suitFocus = Rect.fromLTWH(0.12, 0.6, 0.76, 0.42);
const _viceFocus = Rect.fromLTWH(0.34, 0.28, 0.62, 0.5);

final pieces = <Piece>[
  Piece('Borsalino grigio', Slot.hat, ShopRarity.comune, 350, _hatFocus, (c) => c, owned: true, worn: true),
  Piece('Bombetta nera', Slot.hat, ShopRarity.raro, 700, _hatFocus,
      (c) => wear(c, hat: DemoHat.bowler, hatColor: const Color(0xFF1C1A1A), hatBand: const Color(0xFF7A1420)), brand: 'Cappelleria Monti'),
  Piece('Panama crema', Slot.hat, ShopRarity.raro, 700, _hatFocus,
      (c) => wear(c, hat: DemoHat.fedora, hatColor: const Color(0xFFD8C7A2), hatBand: const Color(0xFF3A2416))),
  Piece('Feltro bordeaux', Slot.hat, ShopRarity.epico, 1100, _hatFocus,
      (c) => wear(c, hat: DemoHat.fedora, hatColor: const Color(0xFF6E1626), hatBand: const Color(0xFF151010)), brand: 'Arminio Milano'),
  Piece('Fedora blu notte', Slot.hat, ShopRarity.epico, 1100, _hatFocus,
      (c) => wear(c, hat: DemoHat.fedora, hatColor: const Color(0xFF1F2B46), hatBand: const Color(0xFFC8962E))),
  Piece('Corona del Boss', Slot.hat, ShopRarity.leggendario, 1800, _hatFocus,
      (c) => wear(c, hat: DemoHat.crown, hatColor: const Color(0xFFF2C14E), hatBand: const Color(0xFFB3141E))),
  Piece('Occhiali tondi', Slot.face, ShopRarity.comune, 350, _faceFocus, (c) => wear(c, glasses: DemoGlasses.round)),
  Piece('Occhiali scuri', Slot.face, ShopRarity.raro, 700, _faceFocus, (c) => wear(c, glasses: DemoGlasses.shades)),
  Piece('Monocolo d\'oro', Slot.face, ShopRarity.epico, 1100, _faceFocus, (c) => wear(c, glasses: DemoGlasses.monocle)),
  Piece('Barba piena', Slot.face, ShopRarity.raro, 700, _faceFocus, (c) => wear(c, beard: DemoBeard.full)),
  Piece('Gessato antracite', Slot.suit, ShopRarity.comune, 350, _suitFocus, (c) => c, owned: true, worn: true),
  Piece('Smoking bianco', Slot.suit, ShopRarity.epico, 1100, _suitFocus,
      (c) => wear(c, cloth: const Color(0xFFE8DFCC), shirt: const Color(0xFFFFFFFF), accent: const Color(0xFF151313), stripes: false, neck: DemoNeck.bowTie),
      brand: 'Arminio Milano'),
  Piece('Tweed marrone', Slot.suit, ShopRarity.comune, 350, _suitFocus,
      (c) => wear(c, cloth: const Color(0xFF6B4A2E), accent: const Color(0xFF2E5A3A), stripes: false)),
  Piece('Blu notte', Slot.suit, ShopRarity.raro, 700, _suitFocus,
      (c) => wear(c, cloth: const Color(0xFF1F2B46), accent: const Color(0xFFC8962E), stripes: false)),
  Piece('Maglia azzurra', Slot.suit, ShopRarity.raro, 700, _suitFocus,
      (c) => wear(c, outfit: DemoOutfit.calcio, cloth: const Color(0xFF1D4FA8), shirt: const Color(0xFF1D4FA8), accent: const Color(0xFFF4EEE2))),
  Piece('Sigaro cubano', Slot.vice, ShopRarity.raro, 700, _viceFocus, (c) => wear(c, prop: DemoProp.cigar)),
  Piece('Sigaretta', Slot.vice, ShopRarity.comune, 350, _viceFocus, (c) => wear(c, prop: DemoProp.cigarette)),
  Piece('Garofano rosso', Slot.vice, ShopRarity.comune, 350, const Rect.fromLTWH(0.04, 0.6, 0.6, 0.42), (c) => wear(c, prop: DemoProp.carnation)),
  Piece('Papillon', Slot.vice, ShopRarity.comune, 350, const Rect.fromLTWH(0.22, 0.62, 0.56, 0.4), (c) => wear(c, neck: DemoNeck.bowTie)),
  Piece('Statua d\'oro', Slot.skin, ShopRarity.leggendario, 1800, const Rect.fromLTWH(0, 0, 1, 1),
      (c) => wear(c,
          golden: true,
          skin: const Color(0xFFD9A93E),
          hair: const Color(0xFFB98A26),
          hatColor: const Color(0xFFF2C14E),
          hatBand: const Color(0xFFB3141E),
          cloth: const Color(0xFFC79A35),
          shirt: const Color(0xFFF6DD8C),
          stripes: false)),
];

List<Piece> piecesOf(Slot slot) => [
  for (final p in pieces)
    if (p.slot == slot) p,
];

Piece? wornIn(Slot slot) => pieces.where((p) => p.slot == slot && p.worn).firstOrNull;

/// The bust of [look], square, with the cartoon-noir painter.
class NoirBustPainter extends CustomPainter {
  final DemoChar look;
  final Rect focus;
  const NoirBustPainter(this.look, {this.focus = const Rect.fromLTWH(0, 0, 1, 1)});

  @override
  void paint(Canvas canvas, Size size) {
    final scale = max(size.width / focus.width, size.height / focus.height);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(size.width / 2 - focus.center.dx * scale, size.height / 2 - focus.center.dy * scale);
    paintNoir(canvas, look, scale);
    canvas.restore();
  }

  @override
  bool shouldRepaint(NoirBustPainter old) => old.look != look || old.focus != focus;
}

/// The hero: a big bust that breathes, under a warm pool of lamp light.
class HeroBust extends StatefulWidget {
  final DemoChar look;
  final double size;
  final bool glow;
  const HeroBust({super.key, required this.look, required this.size, this.glow = true});

  @override
  State<HeroBust> createState() => _HeroBustState();
}

class _HeroBustState extends State<HeroBust> with SingleTickerProviderStateMixin {
  late final _breath = AnimationController(vsync: this, duration: const Duration(milliseconds: 3400))..repeat(reverse: true);

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: widget.size,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        if (widget.glow)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.15),
                  radius: 0.62,
                  colors: [const Color(0xFFFFC46B).withValues(alpha: 0.34), const Color(0x00FFC46B)],
                ),
              ),
            ),
          ),
        AnimatedBuilder(
          animation: _breath,
          builder: (context, child) {
            final t = Curves.easeInOut.transform(_breath.value);
            return Transform(
              alignment: Alignment.bottomCenter,
              transform: Matrix4.identity()
                ..translateByDouble(0.0, -widget.size * 0.006 * t, 0.0, 1.0)
                ..scaleByDouble(1 + 0.004 * t, 1 + 0.01 * t, 1.0, 1.0),
              child: child,
            );
          },
          child: CustomPaint(painter: NoirBustPainter(widget.look), size: Size.square(widget.size)),
        ),
      ],
    ),
  );
}

/// A piece as a thumbnail: the player wearing it, zoomed on where it goes.
class PieceThumb extends StatelessWidget {
  final Piece piece;
  final DemoChar base;
  final double radius;
  const PieceThumb({super.key, required this.piece, required this.base, this.radius = 8});

  @override
  Widget build(BuildContext context) {
    final color = rarityColor(piece.rarity);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.2),
            radius: 0.9,
            colors: [Color.lerp(const Color(0xFF3A2A1E), color, 0.35)!, const Color(0xFF120C08)],
          ),
        ),
        child: CustomPaint(painter: NoirBustPainter(piece.apply(base), focus: piece.focus), child: const SizedBox.expand()),
      ),
    );
  }
}

class Coin extends StatelessWidget {
  final double size;
  const Coin({super.key, this.size = 14});

  @override
  Widget build(BuildContext context) => SizedBox.square(dimension: size, child: const CustomPaint(painter: CoinPainter()));
}

/// The purse: one small pill, top right.
class Purse extends StatelessWidget {
  final int coins;
  final double scale;
  const Purse({super.key, required this.coins, this.scale = 1});

  @override
  Widget build(BuildContext context) => Container(
    height: 32 * scale,
    padding: EdgeInsets.fromLTRB(6 * scale, 0, 10 * scale, 0),
    decoration: BoxDecoration(
      color: const Color(0xE6140F0C),
      borderRadius: BorderRadius.circular(16 * scale),
      border: Border.all(color: AppColors.gold.withValues(alpha: 0.85), width: 1.4),
      boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 6, offset: Offset(1, 3))],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Coin(size: 18 * scale),
        SizedBox(width: 5 * scale),
        Text('$coins', style: TextStyle(color: cream, fontSize: 14 * scale, fontWeight: FontWeight.w800, letterSpacing: 0.4)),
      ],
    ),
  );
}

/// The way back: the enamel plate of the street pages.
class BackPlate extends StatelessWidget {
  final double size;
  const BackPlate({super.key, this.size = 46});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: const Color(0xFF14202A),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: AppColors.gold.withValues(alpha: 0.7), width: 1.5),
      boxShadow: const [BoxShadow(color: Color(0xAA000000), blurRadius: 6, offset: Offset(1, 3))],
    ),
    child: Icon(Icons.arrow_back, color: AppColors.gold, size: size * 0.52),
  );
}

/// The main button: red enamel, brass edge, the price on it.
class BuyButton extends StatelessWidget {
  final String label;
  final int? price;
  final double height;
  final bool brassy;
  final bool expand;
  const BuyButton({super.key, this.label = 'COMPRA', this.price, this.height = 52, this.brassy = false, this.expand = false});

  @override
  Widget build(BuildContext context) {
    final k = height / 52;
    final text = brassy ? brass : const Color(0xFFFFF3DC);
    return Container(
      height: height,
      padding: EdgeInsets.symmetric(horizontal: 18 * k),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12 * k),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: brassy
              ? const [Color(0xFF2A211B), Color(0xFF15100C), ink]
              : const [Color(0xFFD9333C), Color(0xFFA3161F), Color(0xFF5A0A10)],
        ),
        border: Border.all(color: brass, width: 1.6),
        boxShadow: const [
          BoxShadow(color: Color(0xAA000000), blurRadius: 10, offset: Offset(0, 5)),
          BoxShadow(color: Color(0x33FFB443), blurRadius: 18),
        ],
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label, style: AppText.display(17 * k, color: text).copyWith(letterSpacing: 2.2 * k)),
            ),
          ),
          if (price != null) ...[
            SizedBox(width: 12 * k),
            Container(width: 1, height: height * 0.46, color: brass.withValues(alpha: 0.5)),
            SizedBox(width: 12 * k),
            Coin(size: 18 * k),
            SizedBox(width: 5 * k),
            Text('$price', style: TextStyle(color: text, fontSize: 17 * k, fontWeight: FontWeight.w900)),
          ],
        ],
      ),
    );
  }
}

/// Rarity in one word, on its colour.
class RarityTag extends StatelessWidget {
  final ShopRarity rarity;
  final String? brand;
  final double scale;
  const RarityTag(this.rarity, {super.key, this.brand, this.scale = 1});

  @override
  Widget build(BuildContext context) {
    final color = rarityColor(rarity);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 6 * scale, vertical: 2 * scale),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
          child: Text(rarityLabel(rarity),
              style: TextStyle(color: const Color(0xFF1A1208), fontSize: 9.5 * scale, fontWeight: FontWeight.w900, letterSpacing: 1.3 * scale)),
        ),
        if (brand != null) ...[
          SizedBox(width: 7 * scale),
          Flexible(
            child: Text(brand!.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: brass, fontSize: 10 * scale, fontWeight: FontWeight.w700, letterSpacing: 1.4 * scale)),
          ),
        ],
      ],
    );
  }
}

/// The street wall and the BOTTEGA neon behind a concept, with the back
/// plate and the purse in the corners. [builder] places the rest.
class BottegaStage extends StatelessWidget {
  final bool desk;
  final int coins;
  final Widget Function(BuildContext context, StreetFacadeLayout layout) builder;
  const BottegaStage({super.key, required this.builder, this.desk = false, this.coins = 3800});

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final layout = StreetFacadeLayout(media.size, media.padding, desk: desk);
    const section = StreetSection.shop;
    final mid = layout.neon.center.dy;
    return Scaffold(
      backgroundColor: const Color(0xFF07070B),
      body: Stack(
        fit: StackFit.expand,
        children: [
          StreetWallLayer(wall: layout.wall, index: 1, fixed: const [], own: layout.lightsOf(section)),
          // The street fades into the shop: dark at the bottom, where the
          // pieces are, so the bricks never fight with them.
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
          Positioned.fromRect(
            rect: layout.neon,
            child: CustomPaint(painter: StreetNeonPainter(text: section.it, color: section.neon, power: 1)),
          ),
          builder(context, layout),
          Positioned(left: desk ? 28 : 8, top: mid - (desk ? 28 : 23), child: BackPlate(size: desk ? 56 : 46)),
          Positioned(right: desk ? 28 : 8, top: mid - (desk ? 20 : 16), child: Purse(coins: coins, scale: desk ? 1.25 : 1)),
        ],
      ),
    );
  }
}
