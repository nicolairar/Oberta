import 'dart:math';

import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../rules/knowledge.dart';
import '../../rules/player.dart';
import '../../rules/role.dart';
import '../theme/app_theme.dart';
import '../theme/role_style.dart';
import 'player_avatar.dart';
import '../press.dart';

/// Il tavolo visto dall'alto: le facce posate come foto sparse, grandi
/// quanto lo spazio permette, con i segni di ruolo solo dove chi guarda ha
/// diritto di saperlo.
///
/// L'ordine è quello di [players], così com'è: chi chiama decide se è il
/// tavolo pubblico o uno segreto rimescolato (vedi `seating.dart`). Anche la
/// piega delle carte dipende dal posto, mai da chi ci siede.
class PlayerGrid extends StatelessWidget {
  final List<Player> players;
  final bool Function(Player) isAlive;
  final Knowledge Function(Player) knowledgeOf;

  /// Chi tiene il telefono, se la griglia è personale.
  final Player? viewer;

  /// Chi si può toccare. `null` rende la griglia di sola lettura. Di solito
  /// sono i vivi, ma non per forza: il Becchino sceglie tra i morti.
  final List<Player>? selectable;
  final Player? selected;
  final ValueChanged<Player>? onSelect;

  /// Chi oggi ha la bocca cucita: lo si vede dal segno sul ritratto.
  final Player? silenced;

  /// Il timbro sulla carta scelta (al voto, "imputato"). Senza, un segno d'oro.
  final String? stamp;

  const PlayerGrid({
    super.key,
    required this.players,
    required this.isAlive,
    required this.knowledgeOf,
    this.viewer,
    this.selectable,
    this.selected,
    this.onSelect,
    this.silenced,
    this.stamp,
  });

  /// Larghezza su altezza di una carta.
  static const aspect = 0.76;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final layout = TableLayout.fit(players.length, box.biggest);
        return SizedBox(
          width: box.maxWidth,
          height: box.maxHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (final (index, player) in players.indexed)
                if (player != selected) _seat(index, player, layout),
              // La carta scelta sta sopra le altre: si alza dal tavolo.
              for (final (index, player) in players.indexed)
                if (player == selected) _seat(index, player, layout),
            ],
          ),
        );
      },
    );
  }

  Widget _seat(int index, Player player, TableLayout layout) {
    final slot = layout.slot(index);
    final open = selectable?.contains(player) ?? false;
    return Positioned(
      key: ValueKey(player.id),
      left: slot.center.dx - layout.card.width / 2,
      top: slot.center.dy - layout.card.height / 2,
      width: layout.card.width,
      height: layout.card.height,
      child: _Entrance(
        index: index,
        child: _PlayerCard(
          player: player,
          tilt: slot.tilt,
          alive: isAlive(player),
          knowledge: knowledgeOf(player),
          isViewer: player == viewer,
          selected: player == selected,
          othersChosen: selected != null && player != selected,
          silenced: player == silenced,
          stamp: stamp,
          choice: selectable == null
              ? _Choice.none
              : open
              ? _Choice.open
              : _Choice.closed,
          onTap: open && onSelect != null ? () => onSelect!(player) : null,
        ),
      ),
    );
  }
}

/// Un posto sul tavolo: dove cade il centro della carta e quanto è storta.
typedef TableSlot = ({Offset center, double tilt});

/// Come si dispongono [count] carte in uno spazio: righe e colonne scelte
/// per avere le carte più grandi possibile, l'ultima riga centrata, e ogni
/// carta spostata e piegata un poco, come foto lasciate cadere sul tavolo.
class TableLayout {
  final int count;
  final int columns;
  final Size cell;
  final Size card;
  final Offset origin;

  const TableLayout._(this.count, this.columns, this.cell, this.card, this.origin, this.gap, this.stagger);

  /// La carta più larga che si concede, anche con pochi giocatori.
  static const maxCardWidth = 172.0;

  factory TableLayout.fit(int count, Size space) {
    final n = max(1, count);
    double widthFor(int columns) {
      final rows = (n / columns).ceil();
      return min(min(space.width / columns, space.height / rows * PlayerGrid.aspect), maxCardWidth / 0.9);
    }

    // Le carte più grandi possibile, ma senza un'ultima riga quasi vuota:
    // sedici facce stanno meglio quattro per quattro che cinque per tre più una.
    double score(int columns) {
      final last = n - (columns * ((n - 1) ~/ columns));
      return widthFor(columns) * (0.9 + 0.1 * last / columns);
    }

    var columns = 1;
    for (var c = 2; c <= min(n, 6); c++) {
      if (score(c) >= score(columns) * 0.99) columns = c;
    }
    final rows = (n / columns).ceil();
    final cellWidth = widthFor(columns);
    final cell = Size(cellWidth, cellWidth / PlayerGrid.aspect);
    final card = Size(cell.width * 0.9, cell.height * 0.9);
    // Lo spazio che avanza non resta tutto ai bordi: un po' va tra le righe,
    // e le righe si sfalsano come mattoni, così il tavolo non sembra un modulo.
    final spareX = max(0.0, space.width - cell.width * columns);
    final spareY = max(0.0, space.height - cell.height * rows);
    final gap = rows > 1 ? min(spareY / (rows + 1), cell.height * 0.1) : 0.0;
    final stagger = columns > 1 && rows > 1 ? min(spareX / 2, cell.width * 0.2) : 0.0;
    final origin = Offset(spareX / 2, (space.height - cell.height * rows - gap * (rows - 1)) / 2);
    return TableLayout._(n, columns, cell, card, origin, gap, stagger);
  }

  /// Lo spazio in più tra una riga e l'altra, e quanto si sfalsano.
  final double gap;
  final double stagger;

  int get rows => (count / columns).ceil();

  TableSlot slot(int index) {
    final row = index ~/ columns;
    final column = index % columns;
    final inRow = row == rows - 1 ? count - row * columns : columns;
    final rowShift = (columns - inRow) * cell.width / 2 + (inRow == columns ? (row.isEven ? -1 : 1) * stagger / 2 : 0);
    final base = origin + Offset(rowShift + (column + 0.5) * cell.width, (row + 0.5) * cell.height + row * gap);
    // Il caso dipende solo dal posto: due tavoli con le stesse facce in
    // ordine diverso hanno le stesse pieghe negli stessi punti.
    final dice = Random(index * 7919 + count * 104729);
    final slackX = cell.width - card.width;
    final slackY = cell.height - card.height;
    final jitter = Offset((dice.nextDouble() - 0.5) * slackX * 0.8, (dice.nextDouble() - 0.5) * slackY * 0.8);
    final tilt = (dice.nextDouble() - 0.5) * 0.085;
    return (center: base + jitter, tilt: tilt);
  }
}

/// Le carte si posano sul tavolo una dopo l'altra, come carte servite.
class _Entrance extends StatelessWidget {
  final int index;
  final Widget child;

  const _Entrance({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final wait = 40.0 * index;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: (340 + wait).round()),
      curve: Interval(wait / (340 + wait), 1, curve: Curves.easeOutBack),
      builder: (context, landed, child) => Opacity(
        opacity: landed.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, 18 * (1 - landed)),
          child: Transform.scale(scale: 0.8 + 0.2 * landed, child: child),
        ),
      ),
      child: child,
    );
  }
}

/// Se su una carta c'è da scegliere: niente (il tavolo si guarda e basta),
/// sì, oppure no perché stavolta tocca ad altri.
enum _Choice { none, open, closed }

class _PlayerCard extends StatelessWidget {
  final Player player;
  final double tilt;
  final bool alive;
  final Knowledge knowledge;
  final bool isViewer;
  final bool selected;
  final bool othersChosen;
  final bool silenced;
  final String? stamp;
  final _Choice choice;
  final VoidCallback? onTap;

  const _PlayerCard({
    required this.player,
    required this.tilt,
    required this.alive,
    required this.knowledge,
    required this.isViewer,
    required this.selected,
    required this.othersChosen,
    required this.silenced,
    required this.stamp,
    required this.choice,
    required this.onTap,
  });

  static const _mafiaRed = Color(0xFFE5606A);
  static const _cleanGreen = Color(0xFF6FBF9A);
  static const _ink = Color(0xFFE2323D);

  /// Chi si può scegliere sta in piena luce, anche da morto: resta il
  /// pugnale a dire che non c'è più. Gli altri sfumano, i morti più dei vivi.
  double get _opacity => switch (choice) {
    _Choice.open => othersChosen ? 0.78 : 1,
    _Choice.closed => alive ? 0.5 : 0.4,
    _Choice.none => alive ? 1 : 0.55,
  };

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        final radius = w * 0.09;
        final avatar = w * 0.8;
        final card = AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: selected
                  ? const [Color(0xFF4A3B22), Color(0xFF2A211B)]
                  : alive
                  ? const [Color(0xFF332A25), Color(0xFF1C1714)]
                  : const [Color(0xFF26221F), Color(0xFF161312)],
            ),
            border: Border.all(
              color: selected ? AppColors.gold : AppColors.gold.withValues(alpha: alive ? 0.22 : 0.1),
              width: selected ? 2.5 : 1,
            ),
            boxShadow: [
              if (selected)
                BoxShadow(color: AppColors.gold.withValues(alpha: 0.5), blurRadius: w * 0.22, spreadRadius: 1),
              BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: w * 0.08, offset: Offset(0, w * 0.04)),
            ],
          ),
          padding: EdgeInsets.fromLTRB(w * 0.06, w * 0.07, w * 0.06, w * 0.05),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
              width: w * 0.88,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _portrait(avatar),
                  SizedBox(height: w * 0.04),
                  SizedBox(
                    height: w * 0.16,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        player.name,
                        maxLines: 1,
                        style: TextStyle(
                          color: alive ? AppColors.textPrimary : AppColors.textSecondary,
                          fontSize: max(12.0, w * 0.135),
                          fontWeight: FontWeight.w700,
                          decoration: alive ? null : TextDecoration.lineThrough,
                          decorationColor: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: w * 0.13,
                    child: Center(child: _badge(t, w)),
                  ),
                ],
              ),
            ),
          ),
        );
        return AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: _opacity,
          child: AnimatedRotation(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutBack,
            // La carta scelta si raddrizza e si alza: le altre restano dove sono cadute.
            turns: (selected ? 0 : tilt) / (2 * pi),
            child: AnimatedScale(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              scale: selected ? 1.07 : 1,
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  borderRadius: BorderRadius.circular(radius),
                  onTap: pressed(onTap, Press.card),
                  child: card,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _portrait(double size) {
    final role = knowledge.role;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Un filo di luce dietro la faccia, come una lampada sul tavolo.
          if (alive)
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    (selected ? AppColors.gold : AppColors.textPrimary).withValues(alpha: selected ? 0.35 : 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          PlayerAvatar(seed: player.name, size: size * 0.94, fallen: !alive),
          if (role != null)
            Positioned(left: -size * 0.04, bottom: -size * 0.02, child: _chip(size * 0.3, role.color, role.icon)),
          if (silenced && alive)
            Positioned(
              right: -size * 0.04,
              top: -size * 0.02,
              child: _chip(size * 0.3, AppColors.gold, Icons.voice_over_off, ink: AppColors.background),
            ),
          if (selected && stamp == null)
            Positioned(
              right: -size * 0.04,
              bottom: -size * 0.02,
              child: _chip(size * 0.3, AppColors.gold, Icons.check, ink: AppColors.background),
            ),
          if (selected && stamp != null)
            Align(
              alignment: const Alignment(0, 0.62),
              child: _Stamp(text: stamp!, width: size),
            ),
        ],
      ),
    );
  }

  static Widget _chip(double size, Color color, IconData icon, {Color ink = AppColors.textPrimary}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF14110F), width: max(1.5, size * 0.08)),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 4)],
      ),
      child: Icon(icon, size: size * 0.56, color: ink),
    );
  }

  Widget _badge(AppStrings t, double w) {
    if (isViewer) return _label(t.youBadge, AppColors.gold, w);
    if (knowledge.role != null) return const SizedBox.shrink();
    return switch (knowledge.team) {
      Team.mafia => _label(t.familyBadge, _mafiaRed, w),
      Team.citizens => _label(t.innocentBadge, _cleanGreen, w),
      null => const SizedBox.shrink(),
    };
  }

  static Widget _label(String text, Color color, double w) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: w * 0.06, vertical: w * 0.012),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: max(9.0, w * 0.085),
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}

/// Il timbro rosso sulla carta dell'imputato, storto come vuole la mano.
class _Stamp extends StatelessWidget {
  final String text;
  final double width;

  const _Stamp({required this.text, required this.width});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.2,
      child: Container(
        constraints: BoxConstraints(maxWidth: width * 1.05),
        padding: EdgeInsets.symmetric(horizontal: width * 0.06, vertical: width * 0.04),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          border: Border.all(color: _PlayerCard._ink, width: max(1.5, width * 0.025)),
          borderRadius: BorderRadius.circular(width * 0.04),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            text,
            maxLines: 1,
            style: TextStyle(
              fontFamily: 'Georgia',
              fontFamilyFallback: const ['serif'],
              fontSize: width * 0.17,
              fontWeight: FontWeight.w900,
              letterSpacing: width * 0.012,
              height: 1.2,
              color: _PlayerCard._ink,
            ),
          ),
        ),
      ),
    );
  }
}
