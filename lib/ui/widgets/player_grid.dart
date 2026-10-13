import 'package:flutter/material.dart';

import '../../rules/knowledge.dart';
import '../../rules/player.dart';
import '../../rules/role.dart';
import '../theme/app_theme.dart';
import '../theme/role_style.dart';
import 'noir_avatar.dart';

/// Il tavolo visto dall'alto: la stessa griglia per tutti, con i segni di
/// ruolo solo dove chi guarda ha diritto di saperlo.
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
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 0.78,
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: [
        for (final (index, player) in players.indexed)
          _Entrance(
            index: index,
            child: _PlayerTile(
              player: player,
              alive: isAlive(player),
              knowledge: knowledgeOf(player),
              isViewer: player == viewer,
              selected: player == selected,
              silenced: player == silenced,
              choice: selectable == null
                  ? _Choice.none
                  : selectable!.contains(player)
                      ? _Choice.open
                      : _Choice.closed,
              onTap: selectable != null && selectable!.contains(player) && onSelect != null
                  ? () => onSelect!(player)
                  : null,
            ),
          ),
      ],
    );
  }
}

/// Le tessere si posano sul tavolo una dopo l'altra, come carte servite.
class _Entrance extends StatelessWidget {
  final int index;
  final Widget child;

  const _Entrance({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    final wait = 55.0 * index;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: (320 + wait).round()),
      curve: Interval(wait / (320 + wait), 1, curve: Curves.easeOutBack),
      builder: (context, landed, child) => Opacity(
        opacity: landed.clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.7 + 0.3 * landed, child: child),
      ),
      child: child,
    );
  }
}

/// Se su una tessera c'è da scegliere: niente (la griglia si guarda e basta),
/// sì, oppure no perché stavolta tocca ad altri.
enum _Choice { none, open, closed }

class _PlayerTile extends StatelessWidget {
  final Player player;
  final bool alive;
  final Knowledge knowledge;
  final bool isViewer;
  final bool selected;
  final bool silenced;
  final _Choice choice;
  final VoidCallback? onTap;

  const _PlayerTile({
    required this.player,
    required this.alive,
    required this.knowledge,
    required this.isViewer,
    required this.selected,
    required this.silenced,
    required this.choice,
    required this.onTap,
  });

  /// Chi si può scegliere sta in piena luce, anche da morto: resta la croce
  /// a dire che non c'è più. Gli altri sfumano, i morti più dei vivi.
  double get _opacity => switch (choice) {
        _Choice.open => 1,
        _Choice.closed => alive ? 0.55 : 0.38,
        _Choice.none => alive ? 1 : 0.38,
      };

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: _opacity,
      child: Material(
        color: selected ? AppColors.surfaceHigh : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? AppColors.gold : AppColors.gold.withValues(alpha: 0.18),
                width: selected ? 2.5 : 1,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    NoirAvatar(seed: player.name, size: 50, faded: !alive),
                    if (silenced && alive)
                      const Positioned(
                        right: -8,
                        top: -6,
                        child: CircleAvatar(
                          radius: 11,
                          backgroundColor: AppColors.gold,
                          child: Icon(Icons.voice_over_off, size: 14, color: AppColors.background),
                        ),
                      ),
                    // Il pugnale tipografico, non la croce: iOS disegna "✝" come emoji.
                    if (!alive)
                      const Text(
                        '†',
                        style: TextStyle(
                          fontFamily: 'Georgia',
                          color: AppColors.textPrimary,
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          shadows: [Shadow(color: Colors.black, blurRadius: 6)],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  player.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    decoration: alive ? null : TextDecoration.lineThrough,
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(height: 20, child: _badge()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _badge() {
    final role = knowledge.role;
    if (role != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 10,
            backgroundColor: role.color,
            child: Icon(role.icon, size: 12, color: AppColors.textPrimary),
          ),
          if (isViewer) ...[
            const SizedBox(width: 5),
            const Text('TU', style: AppText.overline),
          ],
        ],
      );
    }
    return switch (knowledge.team) {
      Team.mafia => _teamLabel('FAMIGLIA', const Color(0xFFE5606A)),
      Team.citizens => _teamLabel('INNOCENTE', const Color(0xFF6FBF9A)),
      null => const SizedBox.shrink(),
    };
  }

  static Widget _teamLabel(String text, Color color) {
    return Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.4,
      ),
    );
  }
}
