// The two finishes side by side: primary, secondary, icon buttons, the back
// control, the purse, the timer badge and the filter chips.
import 'package:flutter/material.dart';

import '../demo_bottega2/kit.dart' show cream, brass;
import 'finish.dart';

class StyleSheet3 extends StatelessWidget {
  const StyleSheet3({super.key});

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      gradient: RadialGradient(center: Alignment(0, -0.6), radius: 1.3, colors: [Color(0xFF3A2216), Color(0xFF0E0A08)]),
    ),
    padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
    child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: _Column(finish: Finish.targa, title: 'A · TARGA', note: 'Smalto granata in cornice d\'ottone smussata, medaglioni tondi.')),
      SizedBox(width: 28),
      Expanded(child: _Column(finish: Finish.deco, title: 'B · DECO', note: 'Oro champagne e lacca nera, angoli tagliati da biglietto di teatro.')),
    ]),
  );
}

class _Column extends StatelessWidget {
  final Finish finish;
  final String title;
  final String note;
  const _Column({required this.finish, required this.title, required this.note});

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 8),
    child: Text(t, style: const TextStyle(color: Color(0xFF9A8A78), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 2)),
  );

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title, style: const TextStyle(fontFamily: 'Georgia', color: brass, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 3)),
    const SizedBox(height: 4),
    Text(note, style: const TextStyle(color: cream, fontSize: 13, fontStyle: FontStyle.italic, fontFamily: 'Georgia')),
    _label('INTESTAZIONE: INDIETRO E BORSELLINO'),
    Row(children: [BackControl(finish: finish), const Spacer(), Purse3(finish: finish, coins: 3800)]),
    _label('PRIMARIO'),
    PrimaryButton(finish: finish, price: 700),
    const SizedBox(height: 12),
    PrimaryButton(finish: finish, label: 'COMPRA TUTTO', price: 2400, expand: true),
    _label('SECONDARIO'),
    Row(children: [
      SecondaryButton(finish: finish, label: 'REGALA', icon: Icons.card_giftcard),
      const SizedBox(width: 10),
      SecondaryButton(finish: finish, label: 'INDOSSA', icon: Icons.check),
    ]),
    _label('ICONE'),
    Row(children: [
      IconPlate(finish: finish, icon: Icons.tune, badge: 2),
      const SizedBox(width: 12),
      IconPlate(finish: finish, icon: Icons.card_giftcard),
      const SizedBox(width: 12),
      IconPlate(finish: finish, icon: Icons.search),
      const SizedBox(width: 12),
      IconPlate(finish: finish, icon: Icons.close),
    ]),
    _label('TEMPO E FILTRI'),
    Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
      TimerBadge(finish: finish, text: '2g 14h'),
      FilterChip3(finish: finish, label: 'Ognissanti', on: true, dot: const Color(0xFFE07A1F)),
      FilterChip3(finish: finish, label: 'Epico+'),
      FilterChip3(finish: finish, label: 'Non miei'),
    ]),
  ]);
}
