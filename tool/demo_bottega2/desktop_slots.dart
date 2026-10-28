// Concept 1 on a 1920x1080 desktop: the slots become a rail on the left,
// the dummy stands huge in the middle behind the counter, the open slot's
// pieces fill a case on the right with the picked one's Buy under them.
import 'package:flutter/material.dart';
import 'package:oberta/ui/theme/app_theme.dart';
import 'package:oberta/ui/widgets/noir_notice.dart';

import 'concept_slots.dart';
import 'kit.dart';

class SlotsDesktop extends StatefulWidget {
  const SlotsDesktop({super.key});

  @override
  State<SlotsDesktop> createState() => _SlotsDesktopState();
}

class _SlotsDesktopState extends State<SlotsDesktop> {
  var _slot = Slot.hat;
  var _pick = 1;

  @override
  Widget build(BuildContext context) {
    final row = piecesOf(_slot);
    final picked = row[_pick.clamp(0, row.length - 1)];
    return BottegaStage(
      desk: true,
      builder: (context, layout) {
        const counterTop = 900.0;
        const bust = 720.0;
        const bustLeft = 860.0 - bust / 2;
        return Stack(
          children: [
            const Positioned(left: 560, top: 80, width: 600, height: counterTop - 60, child: CustomPaint(painter: LampConePainter())),
            Positioned(left: bustLeft, top: counterTop + 34 - bust, child: HeroBust(look: picked.apply(player), size: bust)),
            Positioned(
              left: 470,
              width: 780,
              top: counterTop,
              bottom: 0,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF5A3A22), Color(0xFF2A1A0E), Color(0xFF120A06)]),
                  border: Border(top: BorderSide(color: brass, width: 3)),
                  boxShadow: [BoxShadow(color: Color(0xCC000000), blurRadius: 20, offset: Offset(0, -6))],
                  borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
                ),
              ),
            ),
            Positioned(left: 60, top: 170, width: 380, child: _rail()),
            Positioned(left: 1290, top: 130, right: 50, bottom: 40, child: _case(row, picked)),
            const Positioned(
              left: 960 - 230,
              top: 104,
              width: 460,
              child: NoticeSlip(text: 'Bombetta nera provata. Comprala e resta tua.', kind: NoticeKind.info, wide: true),
            ),
          ],
        );
      },
    );
  }

  Widget _rail() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final s in Slot.values)
        GestureDetector(
          onTap: () => setState(() {
            _slot = s;
            _pick = 0;
          }),
          child: Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.fromLTRB(14, 12, 16, 8),
            decoration: BoxDecoration(
              color: s == _slot ? const Color(0xE6241911) : const Color(0xB30C0907),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: s == _slot ? brass : const Color(0xFF3A2A1E), width: s == _slot ? 2 : 1),
              boxShadow: const [BoxShadow(color: Color(0xAA000000), blurRadius: 12, offset: Offset(0, 5))],
            ),
            child: Row(
              children: [
                SlotMedal(slot: s, worn: wornIn(s), on: s == _slot, scale: 1.2),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(wornIn(s)?.name ?? 'Niente', style: TextStyle(fontFamily: 'Georgia', fontStyle: FontStyle.italic, color: wornIn(s) == null ? AppColors.textSecondary : cream, fontSize: 21)),
                      const SizedBox(height: 4),
                      Text('${piecesOf(s).length} pezzi in bottega', style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: s == _slot ? brass : const Color(0xFF5A4A3A), size: 26),
              ],
            ),
          ),
        ),
    ],
  );

  Widget _case(List<Piece> row, Piece picked) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xF2241911), Color(0xF21B130E), Color(0xF20E0A08)]),
      border: Border.all(color: brassDeep, width: 1.5),
      boxShadow: const [BoxShadow(color: Color(0xEE000000), blurRadius: 30, offset: Offset(0, 10))],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(_slot.icon, color: brass, size: 22),
            const SizedBox(width: 10),
            Text('${_slot.label}  ·  ${row.length}', style: const TextStyle(color: brass, fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: 2.4)),
            const Spacer(),
            const Text('Tutte le classi', style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
            const Icon(Icons.expand_more, color: AppColors.textSecondary),
          ],
        ),
        const SizedBox(height: 18),
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 16, crossAxisSpacing: 16, childAspectRatio: 0.68),
            itemCount: row.length,
            itemBuilder: (context, i) => LayoutBuilder(
              builder: (context, box) => GestureDetector(
                onTap: () => setState(() => _pick = i),
                child: PieceCard(piece: row[i], on: row[i] == picked, width: box.maxWidth, height: box.maxHeight),
              ),
            ),
          ),
        ),
        const Divider(color: Color(0xFF3A2A1E), height: 28),
        Text(picked.name, style: const TextStyle(fontFamily: 'Georgia', fontStyle: FontStyle.italic, color: cream, fontSize: 30)),
        const SizedBox(height: 8),
        RarityTag(picked.rarity, brand: picked.brand, scale: 1.3),
        const SizedBox(height: 10),
        const Text('Feltro rigido, nastro granata. Si vede dall\'altra parte del tavolo.', style: TextStyle(color: AppColors.textSecondary, fontSize: 16, height: 1.35)),
        const SizedBox(height: 18),
        if (picked.worn) const BuyButton(label: 'INDOSSATO', brassy: true, height: 62, expand: true) else BuyButton(price: picked.price, height: 62, expand: true),
      ],
    ),
  );
}
