import 'package:flutter/material.dart';

import '../../rules/knowledge.dart';
import '../../rules/player.dart';
import '../../rules/role.dart';
import '../theme/app_theme.dart';
import '../theme/role_style.dart';

/// Il tavolo visto dall'alto: la stessa griglia per tutti, con i segni di
/// ruolo solo dove chi guarda ha diritto di saperlo.
class PlayerGrid extends StatelessWidget {
  final List<Player> players;
  final bool Function(Player) isAlive;
  final Knowledge Function(Player) knowledgeOf;

  /// Chi tiene il telefono, se la griglia è personale.
  final Player? viewer;

  /// Chi si può toccare. `null` rende la griglia di sola lettura.
  final List<Player>? selectable;
  final Player? selected;
  final ValueChanged<Player>? onSelect;

  const PlayerGrid({
    super.key,
    required this.players,
    required this.isAlive,
    required this.knowledgeOf,
    this.viewer,
    this.selectable,
    this.selected,
    this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 0.8,
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: [
        for (final player in players)
          _PlayerTile(
            player: player,
            alive: isAlive(player),
            knowledge: knowledgeOf(player),
            isViewer: player == viewer,
            selected: player == selected,
            enabled: selectable?.contains(player) ?? true,
            onTap: selectable != null && selectable!.contains(player) && onSelect != null
                ? () => onSelect!(player)
                : null,
          ),
      ],
    );
  }
}

class _PlayerTile extends StatelessWidget {
  final Player player;
  final bool alive;
  final Knowledge knowledge;
  final bool isViewer;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  const _PlayerTile({
    required this.player,
    required this.alive,
    required this.knowledge,
    required this.isViewer,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: !alive
          ? 0.38
          : enabled
              ? 1
              : 0.55,
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
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.background,
                  // Il pugnale tipografico, non la croce: iOS disegna "✝" come emoji.
                  child: Text(
                    alive ? player.name.characters.first.toUpperCase() : '†',
                    style: TextStyle(
                      fontFamily: alive ? null : 'Georgia',
                      color: alive ? AppColors.gold : AppColors.textSecondary,
                      fontSize: alive ? 18 : 26,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
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
