// Concept 1, "Il manichino": the player big in the middle under the lamp,
// the body slots as enamel medallions around him (what he wears now), and
// a leather drawer under the thumb with the pieces of the open slot in one
// row. Price and Buy belong to the piece picked in the row.
import 'package:flutter/material.dart';
import 'package:oberta/ui/screens/shop/shop_screen.dart' show rarityColor;
import 'package:oberta/ui/theme/app_theme.dart';

import '../demo_avatar/demo_cast.dart';
import 'kit.dart';

class SlotsConcept extends StatefulWidget {
  final Slot slot;
  final int pick;
  const SlotsConcept({super.key, this.slot = Slot.hat, this.pick = 1});

  @override
  State<SlotsConcept> createState() => _SlotsConceptState();
}

class _SlotsConceptState extends State<SlotsConcept> {
  late Slot _slot = widget.slot;
  late int _pick = widget.pick;

  @override
  Widget build(BuildContext context) {
    final row = piecesOf(_slot);
    final picked = row[_pick.clamp(0, row.length - 1)];
    final look = picked.apply(player);
    return BottegaStage(
      builder: (context, layout) {
        final w = layout.size.width;
        final h = layout.size.height;
        final bottom = layout.safe.bottom;
        final drawerTop = h - bottom - 268;
        const bust = 400.0;
        final bustTop = drawerTop + 34 - bust;
        Widget medal(Slot s, double x, double y) => Positioned(
          left: x,
          top: y,
          child: SlotMedal(
            slot: s,
            worn: wornIn(s),
            on: s == _slot,
            onTap: () => setState(() {
              _slot = s;
              _pick = 0;
            }),
          ),
        );
        return Stack(
          children: [
            // The lamp cone over the dummy.
            Positioned(
              left: w / 2 - 170,
              top: layout.neon.bottom - 6,
              width: 340,
              height: drawerTop - layout.neon.bottom + 30,
              child: const CustomPaint(painter: LampConePainter()),
            ),
            Positioned(left: (w - bust) / 2, top: bustTop, child: HeroBust(look: look, size: bust)),
            medal(Slot.hat, 12, bustTop + 46),
            medal(Slot.face, 12, bustTop + 148),
            medal(Slot.suit, w - 12 - SlotMedal.side, bustTop + 46),
            medal(Slot.vice, w - 12 - SlotMedal.side, bustTop + 148),
            Positioned(
              left: 0,
              right: 0,
              top: drawerTop,
              bottom: 0,
              child: _Drawer(
                slot: _slot,
                row: row,
                picked: picked,
                bottomPad: bottom,
                onPick: (i) => setState(() => _pick = i),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// A slot around the dummy: what is worn there, in an enamel ring.
class SlotMedal extends StatelessWidget {
  static const side = 62.0;
  final Slot slot;
  final Piece? worn;
  final bool on;
  final VoidCallback? onTap;
  final double scale;
  const SlotMedal({super.key, required this.slot, this.worn, this.on = false, this.onTap, this.scale = 1});

  @override
  Widget build(BuildContext context) {
    final s = side * scale;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: s,
            height: s,
            padding: EdgeInsets.all(3 * scale),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: on ? const [Color(0xFFFFE29A), Color(0xFFC9A227), Color(0xFF8C6A14)] : const [Color(0xFF6E5424), Color(0xFF3A2C14)],
              ),
              boxShadow: [
                const BoxShadow(color: Color(0xCC000000), blurRadius: 8, offset: Offset(0, 4)),
                if (on) const BoxShadow(color: Color(0x88FFB443), blurRadius: 16),
              ],
            ),
            child: ClipOval(
              child: worn != null
                  ? PieceThumb(piece: worn!, base: player, radius: 0)
                  : Container(
                      color: const Color(0xFF15100C),
                      child: Icon(slot.icon, color: brassDeep, size: s * 0.4),
                    ),
            ),
          ),
          SizedBox(height: 4 * scale),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 6 * scale, vertical: 2 * scale),
            decoration: BoxDecoration(color: const Color(0xCC0C0907), borderRadius: BorderRadius.circular(4)),
            child: Text(slot.label,
                style: TextStyle(color: on ? brass : AppColors.textSecondary, fontSize: 9.5 * scale, fontWeight: FontWeight.w800, letterSpacing: 1.4 * scale)),
          ),
        ],
      ),
    );
  }
}

class _Drawer extends StatelessWidget {
  final Slot slot;
  final List<Piece> row;
  final Piece picked;
  final double bottomPad;
  final ValueChanged<int> onPick;
  const _Drawer({required this.slot, required this.row, required this.picked, required this.bottomPad, required this.onPick});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF241911), leather, Color(0xFF0E0A08)]),
      border: Border(top: BorderSide(color: brassDeep, width: 1.5)),
      boxShadow: [BoxShadow(color: Color(0xEE000000), blurRadius: 24, offset: Offset(0, -8))],
    ),
    child: Padding(
      padding: EdgeInsets.only(bottom: bottomPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 8, bottom: 6),
              width: 38,
              height: 4,
              decoration: BoxDecoration(color: brassDeep, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 6),
            child: Row(
              children: [
                Icon(slot.icon, size: 15, color: brass),
                const SizedBox(width: 6),
                Text('${slot.label}  ·  ${row.length}', style: const TextStyle(color: brass, fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 1.8)),
                const Spacer(),
                const Text('Tutte le classi', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                const Icon(Icons.expand_more, size: 16, color: AppColors.textSecondary),
              ],
            ),
          ),
          SizedBox(
            height: 150,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
              itemCount: row.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, i) => GestureDetector(
                onTap: () => onPick(i),
                child: PieceCard(piece: row[i], on: row[i] == picked, width: 104, height: 134),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(picked.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontFamily: 'Georgia', fontStyle: FontStyle.italic, color: cream, fontSize: 20)),
                      const SizedBox(height: 4),
                      RarityTag(picked.rarity, brand: picked.brand),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                if (picked.worn) const BuyButton(label: 'INDOSSATO', brassy: true) else BuyButton(price: picked.price),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// A piece in the drawer row: the thumbnail, a rarity bar, the price.
class PieceCard extends StatelessWidget {
  final Piece piece;
  final bool on;
  final double width;
  final double height;
  final DemoChar? base;
  const PieceCard({super.key, required this.piece, this.on = false, this.width = 92, this.height = 112, this.base});

  @override
  Widget build(BuildContext context) {
    final color = rarityColor(piece.rarity);
    final k = width / 92;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: width,
      height: height,
      transform: Matrix4.translationValues(0, on ? -4 : 0, 0),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1510),
        borderRadius: BorderRadius.circular(10 * k),
        border: Border.all(color: on ? AppColors.gold : const Color(0xFF3A2A1E), width: on ? 2.4 : 1.2),
        boxShadow: [
          const BoxShadow(color: Color(0xAA000000), blurRadius: 6, offset: Offset(0, 3)),
          if (on) const BoxShadow(color: Color(0x66FFB443), blurRadius: 14),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: PieceThumb(piece: piece, base: base ?? player, radius: 0)),
          Container(height: 3 * k, color: color),
          SizedBox(
            height: 24 * k,
            child: Center(
              child: piece.owned
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(piece.worn ? Icons.check_circle : Icons.check, size: 14 * k, color: AppColors.gold),
                        SizedBox(width: 3 * k),
                        Text(piece.worn ? 'Indossato' : 'Tuo', style: TextStyle(color: AppColors.gold, fontSize: 11 * k, fontWeight: FontWeight.w700)),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Coin(size: 13 * k),
                        SizedBox(width: 4 * k),
                        Text('${piece.price}', style: TextStyle(color: cream, fontWeight: FontWeight.w900, fontSize: 13 * k)),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A soft cone of lamp light falling on the dummy.
class LampConePainter extends CustomPainter {
  const LampConePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cone = Path()
      ..moveTo(w * 0.36, 0)
      ..lineTo(w * 0.64, 0)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
      cone,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x33FFD27A), Color(0x14FFD27A), Color(0x00FFD27A)],
        ).createShader(Offset.zero & size)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
  }

  @override
  bool shouldRepaint(LampConePainter old) => false;
}
