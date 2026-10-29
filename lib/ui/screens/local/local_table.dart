import 'dart:math';

import 'package:flutter/material.dart';

import '../../../l10n/player_gender.dart';
import '../../../l10n/local_table_strings.dart';
import '../../../l10n/table_strings.dart';
import '../../../l10n/app_strings.dart';
import '../../../rules/knowledge.dart';
import '../../../rules/player.dart';
import '../../../rules/player_view.dart';
import '../../../rules/role.dart';
import '../../desktop/desktop_canvas.dart';
import '../../press.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar_spotlight.dart';
import '../../widgets/lynch_mark.dart';
import '../online/game/felt_text.dart';
import '../online/game/noir_ui.dart';
import '../online/game/saloon_table.dart';
import '../online/game/seat_card.dart';

/// The table of the one-phone game: the same seats, felt and hands as the
/// online table ([SaloonTable], [SeatCard]), drawn from what the phone
/// knows right now. [seats] is the order around the table (seat 0 at the
/// bottom); [numbers] the stable seat numbers, the same for the whole game
/// whatever the order on screen.
class LocalTable extends StatelessWidget {
  final List<Player> seats;
  final Map<Player, int> numbers;

  /// The player holding the phone, drawn as "me" (none when the phone is in
  /// the middle of the table).
  final Player? holder;
  final bool Function(Player player) isAlive;
  final Knowledge Function(Player player) knowledgeOf;
  final Set<Player> selectable;
  final Player? selected;
  final void Function(Player player)? onTap;
  final List<SeatVote> votes;
  final Color voteColor;

  /// The Mayor who revealed: his vote counts twice.
  final Player? mayor;
  final Player? silenced;
  final Player? lynched;
  final Widget? center;

  /// By day an abstention shows on the voter's seat; at night only the
  /// family's picks show.
  final bool day;
  final bool accusing;

  const LocalTable({
    super.key,
    required this.seats,
    required this.numbers,
    required this.isAlive,
    required this.knowledgeOf,
    this.holder,
    this.selectable = const {},
    this.selected,
    this.onTap,
    this.votes = const [],
    this.voteColor = Saloon.blood,
    this.mayor,
    this.silenced,
    this.lynched,
    this.center,
    this.day = true,
    this.accusing = true,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    final ts = TableStrings(t.language);
    final ls = LocalTableStrings(t.language);
    final desk = DesktopCanvas.of(context);
    final tally = <Player, int>{};
    for (final vote in votes) {
      final weight = day && vote.voter == mayor ? 2 : 1;
      if (vote.target case final target?) tally[target] = (tally[target] ?? 0) + weight;
    }
    final top = tally.values.fold(0, max);
    final leaders = [
      for (final e in tally.entries)
        if (e.value == top) e.key,
    ];
    // L'accusato è solo del voto di giorno: di notte i voti sono quelli della
    // Famiglia, e il loro bersaglio ha il mirino, mai il nastro.
    final leading = day && accusing && top > 0 && leaders.length == 1 ? leaders.single : null;
    final index = {for (var i = 0; i < seats.length; i++) seats[i]: i};
    final italian = t.language.locale.languageCode == 'it';
    return SaloonTable(
      count: seats.length,
      maxCard: desk ? 152 : 118,
      center: center,
      leading: leading == null ? null : index[leading],
      seatBuilder: (context, i, width) {
        final player = seats[i];
        final vote = votes.where((v) => v.voter == player).firstOrNull;
        // Di notte il proprio posto non mostra la propria carta (la si sa);
        // di giorno quello che è pubblico lo vedono tutti, anche su chi vota.
        final known = player == holder && !day ? Knowledge.none : knowledgeOf(player);
        final role = known.role;
        // Quello che si sa senza la carta (un'indagine): la squadra, scritta
        // sotto il nome, perché sul telefono di tutti non si prendono appunti.
        final team = role == null ? known.team : null;
        final can = selectable.contains(player);
        final hush = silenced == player;
        final pizzino = switch (vote?.target) {
          _ when vote == null => null,
          final target? => '${numbers[target] ?? target.name}',
          null when !day => null,
          null when italian && PlayerGenders.of(player.name) == Gender.feminine => 'astenuta',
          null => t.online.abstainTag,
        };
        final seat = SeatCard(
          key: ValueKey('seat-${player.id}'),
          name: player.name,
          number: numbers[player],
          width: width,
          fallen: !isAlive(player),
          me: player == holder,
          selected: player == selected,
          accused: player == leading,
          accusedLabel: t.online.accusedTag,
          nightTarget: !day && (tally[player] ?? 0) > 0,
          votes: day ? tally[player] ?? 0 : 0,
          pizzino: pizzino,
          pizzinoKey: ValueKey('pizzino-${player.id}'),
          pizzinoColor: voteColor,
          stamped: player == lynched,
          note: player == lynched
              ? null
              : hush
              ? ts.silenced(PlayerGenders.of(player.name))
              : role != null && desk
              ? t.role(role).label
              : team != null
              ? (team == Team.mafia ? ls.familyNote : ls.cleanNote)
              : null,
          noteColor: hush
              ? AppColors.textSecondary
              : (role?.team ?? team) == Team.mafia
              ? Saloon.mafia
              : Saloon.brass,
          role: role,
          selectable: can && onTap != null && player != selected,
          dimmed: selectable.isNotEmpty && !can && isAlive(player) && player != selected && player != holder,
          onTap: can && onTap != null && player != selected ? () => onTap!(player) : null,
        );
        if (player != lynched) return seat;
        return LynchMark(
          key: ValueKey('lynch-${player.id}'),
          label: ts.lynched(PlayerGenders.of(player.name)),
          child: seat,
        );
      },
    );
  }
}

/// The words on the felt, in the free space between the seats: the same
/// dark plate as the online table, a title and a few lines.
class LocalFelt extends StatelessWidget {
  final List<FeltLine> lines;

  const LocalFelt(this.lines, {super.key});

  static double _k(BuildContext context) => DesktopCanvas.of(context) ? 1.55 : 1.0;

  static TextStyle titleStyle(BuildContext context, {Color color = AppColors.textPrimary}) {
    final desk = DesktopCanvas.of(context);
    return AppText.display(desk ? 28 : 17, color: color).copyWith(
      letterSpacing: desk ? 1.2 : 0.6,
      height: 1.2,
      shadows: const [Shadow(color: Colors.black, blurRadius: 6)],
    );
  }

  static TextStyle lineStyle(
    BuildContext context, {
    Color color = AppColors.textPrimary,
    FontWeight? weight,
    FontStyle? style,
  }) => TextStyle(
    color: color,
    fontSize: DesktopCanvas.of(context) ? 21 : 15,
    fontWeight: weight,
    fontStyle: style,
    height: 1.3,
    shadows: const [Shadow(color: Colors.black, blurRadius: 6)],
  );

  @override
  Widget build(BuildContext context) {
    final desk = DesktopCanvas.of(context);
    final k = _k(context);
    return LayoutBuilder(
      builder: (context, box) => Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: min(box.maxWidth, desk ? 560.0 : 320.0), maxHeight: box.maxHeight),
          padding: desk
              ? const EdgeInsets.symmetric(horizontal: 24, vertical: 16)
              : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: const Color(0xB0080605), borderRadius: BorderRadius.circular(12 * k)),
          child: FeltText(lines, gap: 4 * k),
        ),
      ),
    );
  }
}

/// The privacy curtain between two hands: nothing secret on screen, only
/// who must take the phone now ("Passa il telefono a 4 Dario") and the
/// button they press once it is in their hands.
class LocalCurtain extends StatelessWidget {
  final Player player;
  final int? number;
  final VoidCallback onReady;

  const LocalCurtain({
    super.key,
    required this.player,
    required this.number,
    required this.onReady,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    final desk = DesktopCanvas.of(context);
    final tag = number == null ? player.name : '$number ${player.name}';
    return DecoratedBox(
      key: const Key('local.curtain'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF3A0A0E), Color(0xFF1C0507), Color(0xFF0C0304)],
        ),
        border: Border.all(color: Saloon.brassDeep, width: 1.4),
        boxShadow: const [BoxShadow(color: Color(0xCC000000), blurRadius: 24, offset: Offset(0, 10))],
      ),
      child: CustomPaint(
        painter: const _VelvetFolds(),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: desk ? 48 : 24, vertical: desk ? 40 : 24),
          child: Column(
            children: [
              const Spacer(),
              Flexible(
                flex: 6,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: AvatarSpotlight(seed: player.name, size: desk ? 260 : 176),
                ),
              ),
              SizedBox(height: desk ? 32 : 22),
              Text(t.passThePhoneTo, textAlign: TextAlign.center, style: Saloon.plate(desk ? 20 : 14, color: Saloon.brass)),
              SizedBox(height: desk ? 12 : 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(tag.toUpperCase(), key: const Key('local.curtainName'), style: Saloon.plate(desk ? 56 : 36)),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: NoirButton(
                  key: const Key('local.itsMe'),
                  label: t.itsMe,
                  feel: Press.confirm,
                  onPressed: onReady,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The folds of the curtain: soft vertical shadows.
class _VelvetFolds extends CustomPainter {
  const _VelvetFolds();

  @override
  void paint(Canvas canvas, Size size) {
    final folds = max(6, (size.width / 56).round());
    final step = size.width / folds;
    for (var i = 0; i < folds; i++) {
      final rect = Rect.fromLTWH(i * step, 0, step, size.height);
      canvas.drawRect(
        rect,
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0x22000000), Color(0x10FFFFFF), Color(0x33000000)],
          ).createShader(rect),
      );
    }
  }

  @override
  bool shouldRepaint(_VelvetFolds oldDelegate) => false;
}
