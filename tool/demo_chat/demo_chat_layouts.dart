// The two variants of the in-game screen, desk and phone.
//
// A "Registro": the chat is a ledger beside (desk) or under (phone) the
// table, phases are thin rules, events are tinted slips.
// B "Taccuino": the chat is the main column on the left (desk) or a bottom
// sheet over the table (phone); phases are filled bands, events are bare
// accent lines, the densest of the two.
import 'package:flutter/material.dart';
import 'package:oberta/ui/screens/online/game/noir_ui.dart';
import 'package:oberta/ui/theme/app_theme.dart';

import 'demo_chat.dart';

const _quick = ['Voto 4', 'Chi era fuori?', 'Sono cittadino', 'Sospetto 10'];
const _quickFamily = ['Stanotte 3', 'Io copro', 'Votate con me', 'Zitti in piazza'];

Widget _panel({required Widget child, EdgeInsets padding = const EdgeInsets.all(14), Color border = Saloon.brassDeep}) => Container(
  padding: padding,
  decoration: BoxDecoration(
    color: Saloon.ink.withValues(alpha: 0.94),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: border.withValues(alpha: 0.7), width: 1.2),
    boxShadow: const [BoxShadow(color: Colors.black, blurRadius: 18, offset: Offset(0, 6))],
  ),
  child: child,
);

Widget _caption(String text, double size, {Color color = AppColors.gold}) => Text(
  text.toUpperCase(),
  style: TextStyle(color: color, fontSize: size, fontWeight: FontWeight.w900, letterSpacing: size * 0.18),
);

/// The whole chat block: tabs, log, input.
Widget chatBlock({
  required ChatScale s,
  bool family = false,
  bool band = false,
  int? tagged,
  String typed = '',
  int? newBelow,
  bool quick = true,
  List<Entry>? log,
}) {
  final color = family ? Saloon.mafia : Saloon.brass;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TabBarRow(tabs(family: family), s),
      Expanded(
        child: Container(
          decoration: BoxDecoration(
            color: family ? const Color(0xFF140809) : const Color(0xFF0C0907),
            border: Border.all(color: color.withValues(alpha: 0.45)),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(s.font * 0.6)),
          ),
          child: ChatLog(log ?? (family ? familyLog : dayLog), s, band: band, newBelow: newBelow),
        ),
      ),
      SizedBox(height: s.font * 0.6),
      ChatInput(
        s,
        channel: family ? 'famiglia' : 'piazza',
        color: color,
        tagged: tagged,
        typed: typed,
        quick: quick ? (family ? _quickFamily : _quick) : const [],
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Desk, 1920x1080.

class DeskA extends StatelessWidget {
  const DeskA({super.key});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: felt(),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(40, 24, 28, 28),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Column(
              children: [
                const DemoHud(k: 1.25),
                const Spacer(),
                const SeatGrid(width: 182, columns: 4, hGap: 60, vGap: 34, tagged: 4),
                const Spacer(),
                const DemoStrip(k: 1.2, desk: true),
              ],
            ),
          ),
          const SizedBox(width: 32),
          SizedBox(
            width: 660,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _panel(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _caption('In gioco · 12 carte', 13),
                          const Spacer(),
                          Text(
                            '† scoperti: 2',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const RolesStrip(icon: 44),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _panel(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
                    child: chatBlock(s: ChatScale.desk, tagged: 4, typed: 'cambia versione ogni giro, guardate', newBelow: null),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class DeskB extends StatelessWidget {
  const DeskB({super.key});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: felt(),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 640,
            child: _panel(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
              child: chatBlock(s: ChatScale.desk, band: true, tagged: null, newBelow: 3),
            ),
          ),
          const SizedBox(width: 28),
          Expanded(
            child: Column(
              children: [
                const DemoHud(k: 1.15),
                const Spacer(),
                const SeatGrid(width: 158, columns: 4, hGap: 44, vGap: 38),
                const Spacer(),
                const DemoStrip(k: 1.1, desk: true),
              ],
            ),
          ),
          const SizedBox(width: 28),
          SizedBox(
            width: 290,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _panel(child: const VoteTally(k: 1.05)),
                const SizedBox(height: 16),
                Expanded(
                  child: _panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _caption('Ruoli in gioco', 13),
                        const SizedBox(height: 10),
                        const RolesStrip(icon: 40, vertical: true, labels: true),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Phone, 393x852.

class _PhoneFrame extends StatelessWidget {
  final Widget child;
  const _PhoneFrame({required this.child});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: felt(),
    child: Padding(padding: const EdgeInsets.fromLTRB(0, 50, 0, 30), child: child),
  );
}

/// A: a fixed split, table on top, chat below.
class PhoneA extends StatelessWidget {
  const PhoneA({super.key});

  @override
  Widget build(BuildContext context) => _PhoneFrame(
    child: Column(
      children: [
        const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: DemoHud(k: 0.72)),
        const SizedBox(height: 14),
        const SeatGrid(width: 68, columns: 4, hGap: 22, vGap: 16, tagged: 4),
        const SizedBox(height: 10),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Center(child: RolesStrip(icon: 25)),
        ),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: DemoStrip(k: 0.74, status: 'Accusi 4 Dario.'),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: chatBlock(s: ChatScale.phone, tagged: 4, typed: 'cambia versione', quick: false),
          ),
        ),
      ],
    ),
  );
}

/// B: the table full size, the chat a bottom sheet. [open] pulls it up and
/// turns the table into a row of seat numbers to tap.
class PhoneB extends StatelessWidget {
  final bool open;
  final bool family;
  const PhoneB({super.key, this.open = false, this.family = false});

  @override
  Widget build(BuildContext context) {
    const s = ChatScale.phone;
    final sheetColor = family ? Saloon.mafia : Saloon.brass;
    final table = Column(
      children: [
        const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: DemoHud(k: 0.72)),
        const SizedBox(height: 18),
        const SeatGrid(width: 76, columns: 4, hGap: 14, vGap: 22),
        const SizedBox(height: 14),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Center(child: RolesStrip(icon: 27)),
        ),
        const SizedBox(height: 10),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: DemoStrip(k: 0.74, status: 'Accusi 4 Dario.'),
        ),
      ],
    );
    final quickSeats = Wrap(
      alignment: WrapAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final d in seats)
          Opacity(
            opacity: d.dead ? 0.45 : 1,
            child: Container(
              padding: const EdgeInsets.fromLTRB(3, 3, 7, 3),
              decoration: BoxDecoration(
                color: d.n == 4 ? Saloon.brass.withValues(alpha: 0.25) : Saloon.ink.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: d.n == 4 ? Saloon.brass : Saloon.brassDeep, width: d.n == 4 ? 1.6 : 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SeatChip(d.n, size: 18, faded: d.dead),
                  const SizedBox(width: 4),
                  Text(
                    d.name,
                    style: TextStyle(color: d.dead ? AppColors.textSecondary : hueOf(d.n), fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                  if (d.votes > 0) ...[
                    const SizedBox(width: 3),
                    Icon(Icons.front_hand, size: 11, color: Saloon.blood),
                    Text(
                      '${d.votes}',
                      style: const TextStyle(color: Saloon.blood, fontSize: 11, fontWeight: FontWeight.w900),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
    final peek = <Entry>[for (final e in dayLog.sublist(dayLog.length - 5)) e];
    final sheet = Container(
      decoration: BoxDecoration(
        color: const Color(0xF20C0907),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: sheetColor.withValues(alpha: 0.8), width: 1.4),
        boxShadow: const [BoxShadow(color: Colors.black, blurRadius: 24, offset: Offset(0, -6))],
      ),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(color: Saloon.brassDeep, borderRadius: BorderRadius.circular(3)),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: open
                ? chatBlock(
                    s: s,
                    band: true,
                    family: family,
                    tagged: family ? 3 : 4,
                    quick: true,
                    typed: family ? 'stanotte lei, troppe domande' : '',
                  )
                : chatBlock(s: s, band: true, log: peek, quick: false),
          ),
        ],
      ),
    );
    return _PhoneFrame(
      child: Stack(
        children: [
          if (!open) Positioned.fill(child: table),
          if (open)
            Positioned(
              left: 10,
              right: 10,
              top: 0,
              child: Column(children: [const DemoHud(k: 0.6), const SizedBox(height: 10), quickSeats]),
            ),
          Positioned(left: 0, right: 0, bottom: 0, top: open ? 150 : 518, child: sheet),
        ],
      ),
    );
  }
}
