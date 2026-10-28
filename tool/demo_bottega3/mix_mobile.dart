// The mobile mix: the Manichino's slot medallions pick the department, the
// Ruota's dial browses it, and the Vetrina's complete looks live in a
// featured department with timers. Two ways to lay that out:
//
// A "Medaglioni in alto": the medallions in one row under the sign, with
//   IN VETRINA first; the dial's face holds the sections (featured, daily,
//   the season). Drawn on the featured department, in the Targa finish.
// B "Ruota a due anelli": the medallions sit on the dial's inner ring
//   under the thumb, the featured looks are a banner at the top, filters
//   are a plate on the dial. Drawn on the hats, in the Deco finish.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:oberta/online/shop_models.dart';
import 'package:oberta/ui/screens/shop/shop_screen.dart' show rarityColor;
import 'package:oberta/ui/theme/app_theme.dart';

import '../demo_avatar/demo_cast.dart';
import '../demo_bottega2/concept_vetrina.dart' show Look, looks;
import '../demo_bottega2/kit.dart';
import 'finish.dart';

const season = Color(0xFFE07A1F);
const seasonal = {'Feltro bordeaux', 'Corona del Boss', 'Monocolo d\'oro', 'Fedora blu notte'};

Piece _p(String name) => pieces.firstWhere((p) => p.name == name);

final featured = <Look>[
  looks[0],
  Look('Notte d\'Ognissanti', ShopRarity.epico, [_p('Feltro bordeaux'), _p('Monocolo d\'oro'), _p('Blu notte'), _p('Garofano rosso')], 2200),
  looks[1],
  looks[2],
  Look('Il Tifoso', ShopRarity.raro, [_p('Maglia azzurra'), _p('Sigaretta')], 900),
];

/// One thing on the dial's rim: a piece, or a whole look.
class RimEntry {
  final DemoChar look;
  final Rect focus;
  final Color ring;
  final bool seasonal;
  const RimEntry(this.look, this.focus, this.ring, {this.seasonal = false});
}

class MixConcept extends StatelessWidget {
  final bool variantB;
  const MixConcept({super.key, this.variantB = false});

  @override
  Widget build(BuildContext context) => variantB ? const _RingsVariant() : const _TopRowVariant();
}

/// The dial, the notch, the rim and whatever sits on the dial's face.
class _Dial extends StatelessWidget {
  final List<RimEntry> rim;
  final int pick;
  final Widget tag;
  final List<Widget> Function(Offset center, double dialTop) face;
  final DemoChar hero;
  final double bust;
  const _Dial({required this.rim, required this.pick, required this.tag, required this.face, required this.hero, this.bust = 410});

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final w = media.size.width;
    final center = Offset(w / 2, media.size.height - media.padding.bottom + 150);
    const disc = 392.0;
    const r = 334.0;
    final dialTop = center.dy - disc;
    const step = 17.0 * pi / 180;
    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        Positioned(left: (w - bust) / 2, top: dialTop + 46 - bust, child: HeroBust(look: hero, size: bust)),
        Positioned(left: center.dx - disc, top: dialTop, width: disc * 2, height: disc * 2, child: const CustomPaint(painter: Dial3Painter(inner: 150))),
        for (var k = -3; k <= 3; k++)
          if (pick + k >= 0 && pick + k < rim.length) _thumb(rim[pick + k], center + Offset(sin(k * step) * r, -cos(k * step) * r), k == 0, k * step),
        Positioned(left: w / 2 - 12, top: dialTop - 6, child: const CustomPaint(size: Size(24, 18), painter: Notch3Painter())),
        Positioned(left: 12, right: 12, top: dialTop - 80, child: tag),
        ...face(center, dialTop),
      ],
    );
  }

  Widget _thumb(RimEntry e, Offset at, bool on, double a) {
    final side = on ? 82.0 : 60.0;
    return Positioned(
      left: at.dx - side / 2,
      top: at.dy - side / 2,
      child: Transform.rotate(
        angle: a * 0.6,
        child: Stack(clipBehavior: Clip.none, children: [
          Container(
            width: side,
            height: side,
            padding: EdgeInsets.all(on ? 3.5 : 2.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: on ? AppColors.gold : e.ring.withValues(alpha: 0.85),
              boxShadow: [
                const BoxShadow(color: Color(0xCC000000), blurRadius: 8, offset: Offset(0, 4)),
                if (on) const BoxShadow(color: Color(0x99FFB443), blurRadius: 18),
              ],
            ),
            child: ClipOval(
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: RadialGradient(colors: [Color.lerp(const Color(0xFF3A2A1E), e.ring, 0.35)!, const Color(0xFF120C08)])),
                child: CustomPaint(painter: NoirBustPainter(e.look, focus: e.focus), child: const SizedBox.expand()),
              ),
            ),
          ),
          // A seasonal piece: a small orange leaf on the ring.
          if (e.seasonal)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(color: season, shape: BoxShape.circle, border: Border.all(color: ink, width: 1.5)),
                child: const Icon(Icons.eco, size: 12, color: Color(0xFF1A0E04)),
              ),
            ),
        ]),
      ),
    );
  }
}

/// The tag over the chest, in the given finish.
class _Tag extends StatelessWidget {
  final Finish finish;
  final String name;
  final ShopRarity rarity;
  final String? brand;
  final int price;
  final String? timer;
  final String? saving;
  const _Tag({required this.finish, required this.name, required this.rarity, required this.price, this.brand, this.timer, this.saving});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 8, 7, 8),
    decoration: ShapeDecoration(
      shape: finish == Finish.targa
          ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: brassDeep.withValues(alpha: 0.8)))
          : BeveledRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: brassDeep.withValues(alpha: 0.9))),
      color: const Color(0xEB0C0907),
      shadows: const [BoxShadow(color: Color(0xCC000000), blurRadius: 16, offset: Offset(0, 6))],
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Georgia', fontStyle: FontStyle.italic, color: cream, fontSize: 18)),
              const SizedBox(height: 5),
              Row(children: [
                Flexible(child: RarityTag(rarity, brand: timer == null ? brand : null)),
                if (timer != null) ...[const SizedBox(width: 4), TimerBadge(finish: finish, text: timer!)],
                if (saving != null) ...[
                  const SizedBox(width: 4),
                  Text(saving!, style: const TextStyle(color: Color(0xFF7FD39A), fontSize: 12, fontWeight: FontWeight.w900)),
                ],
              ]),
            ],
          ),
        ),
        PrimaryButton(finish: finish, price: price, height: 46),
      ],
    ),
  );
}

/// Variant A: the medallions in a row under the sign.
class _TopRowVariant extends StatelessWidget {
  const _TopRowVariant();

  @override
  Widget build(BuildContext context) {
    const pick = 1;
    final look = featured[pick];
    return Stage3(
      finish: Finish.targa,
      builder: (context, layout) {
        final rim = [for (final l in featured) RimEntry(l.on(player), const Rect.fromLTWH(0.1, 0.12, 0.8, 0.8), rarityColor(l.rarity), seasonal: l.name.contains('Ognissanti'))];
        return Stack(children: [
          _Dial(
            rim: rim,
            pick: pick,
            hero: look.on(player),
            bust: 430,
            tag: _Tag(finish: Finish.targa, name: look.name, rarity: look.rarity, price: look.price, timer: '2g 14h', saving: '−${100 - look.price * 100 ~/ look.full}%'),
            face: (center, top) => [
              Positioned(left: 0, right: 0, top: center.dy - 334 + 82, child: _sections()),
              Positioned(
                left: 0,
                right: 0,
                top: center.dy - 334 + 128,
                child: const Text('Si rinnova tra 14:22:05  ·  5 completi', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF9A8A78), fontSize: 11.5, letterSpacing: 0.4)),
              ),
            ],
          ),
          Positioned(left: 0, right: 0, top: layout.neon.bottom + 6, child: _medals()),
        ]);
      },
    );
  }

  Widget _sections() => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: const [
      FilterChip3(finish: Finish.targa, label: 'In evidenza', on: true),
      SizedBox(width: 8),
      FilterChip3(finish: Finish.targa, label: 'Del giorno'),
      SizedBox(width: 8),
      FilterChip3(finish: Finish.targa, label: 'Ognissanti', dot: season),
    ],
  );

  Widget _medals() => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      _Medal(label: 'VETRINA', icon: Icons.star_rounded, on: true, timer: true),
      for (final s in Slot.values) _Medal(label: s.label, icon: s.icon, worn: wornIn(s)),
    ],
  );
}

/// A slot medallion, small: what is worn there, or the slot's sign.
class _Medal extends StatelessWidget {
  final String label;
  final IconData icon;
  final Piece? worn;
  final bool on;
  final bool timer;
  final double side;
  const _Medal({required this.label, required this.icon, this.worn, this.on = false, this.timer = false, this.side = 50});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: side + 12,
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Stack(clipBehavior: Clip.none, children: [
        Container(
          width: side,
          height: side,
          padding: const EdgeInsets.all(2.5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: on ? const [Color(0xFFFFE7A8), Color(0xFFD9B45A), Color(0xFF9C7424)] : const [Color(0xFF7A5E2A), Color(0xFF3A2C14)],
            ),
            boxShadow: [
              const BoxShadow(color: Color(0xCC000000), blurRadius: 8, offset: Offset(0, 4)),
              if (on) const BoxShadow(color: Color(0x88FFB443), blurRadius: 14),
            ],
          ),
          child: ClipOval(
            child: worn != null
                ? PieceThumb(piece: worn!, base: player, radius: 0)
                : Container(
                    decoration: BoxDecoration(gradient: RadialGradient(colors: on ? const [Color(0xFF5A2A10), Color(0xFF1A0E08)] : const [Color(0xFF2A1F17), Color(0xFF0E0A08)])),
                    child: Icon(icon, color: on ? const Color(0xFFFFD27A) : brassDeep, size: side * 0.46),
                  ),
          ),
        ),
        if (timer)
          Positioned(
            right: -5,
            top: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(color: season, borderRadius: BorderRadius.circular(6), border: Border.all(color: ink, width: 1.2)),
              child: const Text('2g', style: TextStyle(color: Color(0xFF1A0E04), fontSize: 9, fontWeight: FontWeight.w900)),
            ),
          ),
      ]),
      const SizedBox(height: 3),
      Text(label,
          maxLines: 1,
          style: TextStyle(color: on ? cream : AppColors.textSecondary, fontSize: 8.5, fontWeight: FontWeight.w800, letterSpacing: 0.9, shadows: const [Shadow(color: Colors.black, blurRadius: 4)])),
    ]),
  );
}

/// Variant B: medallions on the dial's inner ring, featured on a banner.
class _RingsVariant extends StatelessWidget {
  const _RingsVariant();

  @override
  Widget build(BuildContext context) {
    final row = piecesOf(Slot.hat);
    const pick = 3;
    final picked = row[pick];
    return Stage3(
      finish: Finish.deco,
      builder: (context, layout) {
        final rim = [for (final p in row) RimEntry(p.apply(player), p.focus, rarityColor(p.rarity), seasonal: seasonal.contains(p.name))];
        return Stack(children: [
          _Dial(
            rim: rim,
            pick: pick,
            hero: picked.apply(player),
            bust: 380,
            tag: _Tag(finish: Finish.deco, name: picked.name, rarity: picked.rarity, brand: picked.brand, price: picked.price, timer: '2g 14h'),
            face: (center, top) {
              const ring = 260.0;
              final out = <Widget>[];
              final slots = Slot.values;
              for (var i = 0; i < slots.length; i++) {
                final a = (i - 2) * 19.0 * pi / 180;
                final at = center + Offset(sin(a) * ring, -cos(a) * ring);
                out.add(Positioned(
                  left: at.dx - 26,
                  top: at.dy - 20,
                  child: _Medal(label: slots[i].label, icon: slots[i].icon, worn: wornIn(slots[i]), on: slots[i] == Slot.hat, side: 40),
                ));
              }
              // Filters and the count at the two shoulders of the dial.
              out.add(Positioned(left: 14, top: top + 4, child: const IconPlate(finish: Finish.deco, icon: Icons.tune, size: 40, badge: 2)));
              out.add(Positioned(
                right: 14,
                top: top + 12,
                child: const Text('5 di 48', style: TextStyle(color: Color(0xFFB0A090), fontSize: 12, fontWeight: FontWeight.w700)),
              ));
              return out;
            },
          ),
          Positioned(left: 12, right: 12, top: layout.neon.bottom + 6, child: const _Banner()),
          Positioned(
            left: 12,
            top: layout.neon.bottom + 80,
            child: const Row(children: [
              FilterChip3(finish: Finish.deco, label: 'Ognissanti', on: true, dot: season, close: true),
              SizedBox(width: 6),
              FilterChip3(finish: Finish.deco, label: 'Epico+', on: true, close: true),
            ]),
          ),
        ]);
      },
    );
  }
}

/// The featured looks, folded into one strip: tap to open the window.
class _Banner extends StatelessWidget {
  const _Banner();

  @override
  Widget build(BuildContext context) => Container(
    height: 66,
    padding: const EdgeInsets.fromLTRB(12, 4, 8, 4),
    decoration: ShapeDecoration(
      shape: BeveledRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xCCD9B45A))),
      gradient: const LinearGradient(colors: [Color(0xF23A1A08), Color(0xF2140C08)]),
      shadows: const [BoxShadow(color: Color(0xAA000000), blurRadius: 12, offset: Offset(0, 5))],
    ),
    child: Row(children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Row(children: const [
            Icon(Icons.star_rounded, size: 14, color: Color(0xFFFFD27A)),
            SizedBox(width: 4),
            Text('IN VETRINA', style: TextStyle(color: Color(0xFFFFD27A), fontSize: 10.5, fontWeight: FontWeight.w900, letterSpacing: 2)),
            SizedBox(width: 8),
            TimerBadge(finish: Finish.deco, text: '2g 14h'),
          ]),
          const SizedBox(height: 4),
          const Text('Collezione d\'Ognissanti', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: 'Georgia', fontStyle: FontStyle.italic, color: cream, fontSize: 15)),
        ]),
      ),
      for (final l in featured.take(2))
        Container(
          width: 46,
          height: 46,
          margin: const EdgeInsets.only(left: 5),
          decoration: ShapeDecoration(
            shape: BeveledRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: rarityColor(l.rarity), width: 1.5)),
            color: const Color(0xFF1E1510),
          ),
          child: CustomPaint(painter: NoirBustPainter(l.on(player), focus: const Rect.fromLTWH(0.12, 0.1, 0.76, 0.76))),
        ),
      const Icon(Icons.chevron_right, color: brass),
    ]),
  );
}
