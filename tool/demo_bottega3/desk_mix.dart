// The desktop Manichino, kept as the owner liked it, with the organisation
// that scales: IN VETRINA heads the slot rail (featured looks with a timer),
// the case on the right gets sections, filters by collection, class and
// owned, a search, and a count. Buttons, back and purse in the Targa finish.
import 'package:flutter/material.dart';
import 'package:oberta/ui/screens/shop/shop_screen.dart' show rarityColor;
import 'package:oberta/ui/theme/app_theme.dart';
import 'package:oberta/ui/widgets/noir_notice.dart';

import '../demo_bottega2/concept_slots.dart' show LampConePainter, SlotMedal, PieceCard;
import '../demo_bottega2/kit.dart';
import 'finish.dart';
import 'mix_mobile.dart' show featured, season, seasonal;

class DeskMix extends StatelessWidget {
  const DeskMix({super.key});

  static const _f = Finish.targa;

  @override
  Widget build(BuildContext context) {
    final row = piecesOf(Slot.hat);
    final picked = row[3];
    return Stage3(
      finish: _f,
      desk: true,
      builder: (context, layout) {
        const counterTop = 900.0;
        const bust = 720.0;
        return Stack(children: [
          const Positioned(left: 560, top: 80, width: 600, height: counterTop - 60, child: CustomPaint(painter: LampConePainter())),
          Positioned(left: 860 - bust / 2, top: counterTop + 34 - bust, child: HeroBust(look: picked.apply(player), size: bust)),
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
              ),
            ),
          ),
          Positioned(left: 60, top: 130, width: 380, child: _rail()),
          Positioned(left: 1290, top: 130, right: 50, bottom: 40, child: _case(row, picked)),
          const Positioned(
            left: 960 - 230,
            top: 104,
            width: 460,
            child: NoticeSlip(text: 'Nuova collezione d\'Ognissanti: fino al 3 novembre.', kind: NoticeKind.info, wide: true),
          ),
        ]);
      },
    );
  }

  Widget _rail() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    // The window comes first: featured looks, seasonal, with time left.
    Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(colors: [Color(0xF2401C08), Color(0xF2160D08)]),
        border: Border.all(color: const Color(0xFFE0A050), width: 1.5),
        boxShadow: const [BoxShadow(color: Color(0xAA000000), blurRadius: 14, offset: Offset(0, 6)), BoxShadow(color: Color(0x33E07A1F), blurRadius: 24)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.star_rounded, color: Color(0xFFFFD27A), size: 18),
          SizedBox(width: 6),
          Text('IN VETRINA', style: TextStyle(color: Color(0xFFFFD27A), fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 2.4)),
          Spacer(),
          TimerBadge(finish: _f, text: '2g 14h', scale: 1.2),
        ]),
        const SizedBox(height: 6),
        const Text('Collezione d\'Ognissanti', style: TextStyle(fontFamily: 'Georgia', fontStyle: FontStyle.italic, color: cream, fontSize: 22)),
        const SizedBox(height: 10),
        Row(children: [
          for (final l in featured.take(4))
            Container(
              width: 76,
              height: 76,
              margin: const EdgeInsets.only(right: 9),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: rarityColor(l.rarity), width: 2), color: const Color(0xFF1E1510)),
              clipBehavior: Clip.antiAlias,
              child: CustomPaint(painter: NoirBustPainter(l.on(player), focus: const Rect.fromLTWH(0.1, 0.08, 0.8, 0.8))),
            ),
        ]),
      ]),
    ),
    for (final s in Slot.values)
      Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(12, 8, 14, 4),
        decoration: BoxDecoration(
          color: s == Slot.hat ? const Color(0xE6241911) : const Color(0xB30C0907),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: s == Slot.hat ? brass : const Color(0xFF3A2A1E), width: s == Slot.hat ? 2 : 1),
        ),
        child: Row(children: [
          SlotMedal(slot: s, worn: wornIn(s), on: s == Slot.hat, scale: 0.95),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(wornIn(s)?.name ?? 'Niente', style: TextStyle(fontFamily: 'Georgia', fontStyle: FontStyle.italic, color: wornIn(s) == null ? AppColors.textSecondary : cream, fontSize: 19)),
              const SizedBox(height: 3),
              Text('${piecesOf(s).length * 8} pezzi  ·  ${s == Slot.hat ? 4 : 2} nuovi', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            ]),
          ),
          Icon(Icons.chevron_right, color: s == Slot.hat ? brass : const Color(0xFF5A4A3A)),
        ]),
      ),
  ]);

  Widget _case(List<Piece> row, Piece picked) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xF2241911), Color(0xF21B130E), Color(0xF20E0A08)]),
      border: Border.all(color: brassDeep, width: 1.5),
      boxShadow: const [BoxShadow(color: Color(0xEE000000), blurRadius: 30, offset: Offset(0, 10))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        const Icon(Icons.school_outlined, color: brass, size: 22),
        const SizedBox(width: 10),
        const Text('CAPPELLO', style: TextStyle(color: brass, fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: 2.4)),
        const Spacer(),
        Container(
          width: 200,
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(color: const Color(0xFF0C0907), borderRadius: BorderRadius.circular(17), border: Border.all(color: const Color(0xFF4A3A2A))),
          child: const Row(children: [
            Icon(Icons.search, size: 18, color: Color(0xFF8E8070)),
            SizedBox(width: 6),
            Text('Cerca un pezzo', style: TextStyle(color: Color(0xFF8E8070), fontSize: 14)),
          ]),
        ),
      ]),
      const SizedBox(height: 14),
      // Sections first, then the filters that narrow them.
      const Wrap(spacing: 8, runSpacing: 8, children: [
        FilterChip3(finish: _f, label: 'Tutti  48', scale: 1.15),
        FilterChip3(finish: _f, label: 'Nuovi  4', scale: 1.15),
        FilterChip3(finish: _f, label: 'Ognissanti', on: true, dot: season, scale: 1.15),
        FilterChip3(finish: _f, label: 'Tutte le classi', scale: 1.15),
        FilterChip3(finish: _f, label: 'Non miei', scale: 1.15),
      ]),
      const SizedBox(height: 8),
      const Text('5 di 48  ·  ordinati per novità', style: TextStyle(color: Color(0xFF8E8070), fontSize: 13)),
      const SizedBox(height: 12),
      Expanded(
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 14, crossAxisSpacing: 14, childAspectRatio: 0.74),
          itemCount: row.length,
          itemBuilder: (context, i) => LayoutBuilder(
            builder: (context, box) => Stack(clipBehavior: Clip.none, children: [
              PieceCard(piece: row[i], on: row[i] == picked, width: box.maxWidth, height: box.maxHeight),
              if (seasonal.contains(row[i].name))
                Positioned(
                  left: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: season, borderRadius: BorderRadius.circular(5)),
                    child: const Text('OGNISSANTI', style: TextStyle(color: Color(0xFF1A0E04), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
                  ),
                ),
            ]),
          ),
        ),
      ),
      const Divider(color: Color(0xFF3A2A1E), height: 24),
      Row(children: [
        Text(picked.name, style: const TextStyle(fontFamily: 'Georgia', fontStyle: FontStyle.italic, color: cream, fontSize: 28)),
        const SizedBox(width: 10),
        const TimerBadge(finish: _f, text: '2g 14h', scale: 1.2),
      ]),
      const SizedBox(height: 8),
      RarityTag(picked.rarity, brand: picked.brand, scale: 1.3),
      const SizedBox(height: 16),
      Row(children: [
        const IconPlate(finish: _f, icon: Icons.card_giftcard, size: 58),
        const SizedBox(width: 12),
        Expanded(child: PrimaryButton(finish: _f, price: picked.price, height: 60, expand: true)),
      ]),
    ]),
  );
}
