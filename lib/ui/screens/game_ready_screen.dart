import 'package:flutter/material.dart';

import '../../rules/game_setup.dart';
import '../../rules/role.dart';
import '../theme/app_theme.dart';
import '../theme/role_style.dart';

class GameReadyScreen extends StatefulWidget {
  final GameSetup setup;

  const GameReadyScreen({super.key, required this.setup});

  @override
  State<GameReadyScreen> createState() => _GameReadyScreenState();
}

class _GameReadyScreenState extends State<GameReadyScreen> {
  bool _showingRoles = false;

  @override
  Widget build(BuildContext context) {
    final narrator = widget.setup.narrator;
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 24),
                const Icon(Icons.nightlight_round, color: AppColors.gold, size: 52),
                const SizedBox(height: 20),
                Text(
                  'La città\nsi addormenta',
                  textAlign: TextAlign.center,
                  style: AppText.display(32),
                ),
                const SizedBox(height: 12),
                Text(
                  narrator == null
                      ? 'Tutti hanno la propria carta.'
                      : 'Passa il telefono a ${narrator.name}: da qui in poi racconta il narratore.',
                  textAlign: TextAlign.center,
                  style: AppText.body,
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: narrator == null
                      ? const SizedBox.shrink()
                      : _NarratorSheet(
                          setup: widget.setup,
                          visible: _showingRoles,
                          onHold: (holding) => setState(() => _showingRoles = holding),
                        ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Notte, giorno e voto arrivano nella prossima fase.',
                  textAlign: TextAlign.center,
                  style: AppText.body,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                    child: const Text('TORNA ALLA HOME'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Elenco completo dei ruoli, riservato al narratore: visibile solo a dito premuto.
class _NarratorSheet extends StatelessWidget {
  final GameSetup setup;
  final bool visible;
  final ValueChanged<bool> onHold;

  const _NarratorSheet({required this.setup, required this.visible, required this.onHold});

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => onHold(true),
      onPointerUp: (_) => onHold(false),
      onPointerCancel: (_) => onHold(false),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
        ),
        clipBehavior: Clip.antiAlias,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: visible
              ? ListView(
                  key: const ValueKey('roles'),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    for (final entry in setup.roles.entries)
                      ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: entry.value.color,
                          child: Icon(entry.value.icon, size: 17, color: AppColors.textPrimary),
                        ),
                        title: Text(
                          entry.key.name,
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
                        ),
                        trailing: Text(
                          entry.value.label,
                          style: TextStyle(
                            color: entry.value.team == Team.mafia
                                ? const Color(0xFFE5606A)
                                : AppColors.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                )
              : const Column(
                  key: ValueKey('hidden'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.visibility_off, color: AppColors.textSecondary, size: 36),
                    SizedBox(height: 12),
                    Text('SOLO PER IL NARRATORE', style: AppText.overline),
                    SizedBox(height: 6),
                    Text('Tieni premuto per vedere tutti i ruoli', style: AppText.body),
                  ],
                ),
        ),
      ),
    );
  }
}
