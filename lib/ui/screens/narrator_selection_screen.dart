import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../rules/player.dart';
import '../../rules/role_assignment.dart';
import '../theme/app_theme.dart';
import '../widgets/scene_scaffold.dart';
import 'narrator_draw_screen.dart';
import 'vote_mode_screen.dart';
import '../press.dart';
import '../widgets/noir_modal.dart';

class NarratorSelectionScreen extends StatelessWidget {
  final List<Player> players;

  const NarratorSelectionScreen({super.key, required this.players});

  /// Un narratore umano non gioca: serve un giocatore in più al tavolo.
  bool get _canSpareAPlayer => players.length - 1 >= minRolePlayers;

  /// Scelto il narratore, l'ultima domanda: come vota la piazza. Le carte
  /// si danno dopo.
  void _deal(BuildContext context, Player? narrator) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => VoteModeScreen(players: players, narrator: narrator)),
    );
  }

  Future<void> _chooseFromGroup(BuildContext context) async {
    final narrator = await showNoirMenu<Player>(
      context,
      title: AppStrings.of(context).whoNarrates,
      items: [
        for (final player in players)
          NoirMenuItem(value: player, icon: Icons.record_voice_over_outlined, label: player.name),
      ],
    );
    if (narrator != null && context.mounted) _deal(context, narrator);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    final needMore = t.needAtLeast(minRolePlayers + 1);
    return SceneScaffold(
      appBar: AppBar(title: Text(t.narratorTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(t.whoPullsTheStrings, style: AppText.display(34)),
            const SizedBox(height: 8),
            Text(t.narratorIntro, style: AppText.body),
            const SizedBox(height: 28),
            _OptionCard(
              icon: Icons.how_to_reg,
              title: t.pickedByGroup,
              subtitle: _canSpareAPlayer ? t.pickedByGroupHint : needMore,
              onTap: _canSpareAPlayer ? () => _chooseFromGroup(context) : null,
            ),
            _OptionCard(
              icon: Icons.casino,
              title: t.drawnByCylinder,
              subtitle: _canSpareAPlayer ? t.drawnByCylinderHint : needMore,
              onTap: _canSpareAPlayer
                  ? () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => NarratorDrawScreen(players: players)),
                      )
                  : null,
            ),
            _OptionCard(
              icon: Icons.smart_toy,
              title: t.automaticNarrator,
              subtitle: t.automaticNarratorHint,
              onTap: () => _deal(context, null),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _OptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: pressed(onTap),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
              ),
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(icon, color: AppColors.gold, size: 34),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(subtitle, style: AppText.body.copyWith(fontSize: 14)),
                      ],
                    ),
                  ),
                  if (enabled) const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
