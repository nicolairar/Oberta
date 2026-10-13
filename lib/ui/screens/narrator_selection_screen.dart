import 'package:flutter/material.dart';

import '../../rules/game_setup.dart';
import '../../rules/player.dart';
import '../../rules/role_assignment.dart';
import '../theme/app_theme.dart';
import '../widgets/scene_scaffold.dart';
import 'narrator_draw_screen.dart';
import 'role_deal_screen.dart';

class NarratorSelectionScreen extends StatelessWidget {
  final List<Player> players;

  const NarratorSelectionScreen({super.key, required this.players});

  /// Un narratore umano non gioca: serve un giocatore in più al tavolo.
  bool get _canSpareAPlayer => players.length - 1 >= minRolePlayers;

  void _deal(BuildContext context, Player? narrator) {
    final setup = GameSetup.deal(lobby: players, narrator: narrator);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RoleDealScreen(setup: setup)),
    );
  }

  Future<void> _chooseFromGroup(BuildContext context) async {
    final narrator = await showModalBottomSheet<Player>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Text('CHI RACCONTA?', style: AppText.overline),
            ),
            for (final player in players)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                leading: const Icon(Icons.record_voice_over, color: AppColors.gold),
                title: Text(player.name, style: const TextStyle(color: AppColors.textPrimary)),
                onTap: () => Navigator.of(context).pop(player),
              ),
          ],
        ),
      ),
    );
    if (narrator != null && context.mounted) _deal(context, narrator);
  }

  @override
  Widget build(BuildContext context) {
    final needMore = 'Servono almeno ${minRolePlayers + 1} giocatori';
    return SceneScaffold(
      appBar: AppBar(title: const Text('NARRATORE')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('Chi tiene\nle fila?', style: AppText.display(34)),
            const SizedBox(height: 8),
            const Text(
              'Il narratore guida la partita e conosce tutti i ruoli.',
              style: AppText.body,
            ),
            const SizedBox(height: 28),
            _OptionCard(
              icon: Icons.how_to_reg,
              title: 'Scelto dal gruppo',
              subtitle: _canSpareAPlayer ? 'Decidete voi chi racconta. Non riceve un ruolo.' : needMore,
              onTap: _canSpareAPlayer ? () => _chooseFromGroup(context) : null,
            ),
            _OptionCard(
              icon: Icons.casino,
              title: 'Sorteggiato dal tamburo',
              subtitle: _canSpareAPlayer ? 'Un giro di tamburo. Chi esce racconta e non gioca.' : needMore,
              onTap: _canSpareAPlayer
                  ? () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => NarratorDrawScreen(players: players)),
                      )
                  : null,
            ),
            _OptionCard(
              icon: Icons.smart_toy,
              title: 'Narratore automatico',
              subtitle: 'Racconta il telefono: giocano tutti.',
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
            onTap: onTap,
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
