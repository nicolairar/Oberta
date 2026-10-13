import 'package:flutter/material.dart';

import '../../rules/game_setup.dart';
import '../../rules/role.dart';
import '../theme/app_theme.dart';
import '../theme/role_style.dart';
import '../widgets/deal_table.dart';
import '../widgets/scene_scaffold.dart';
import 'role_reveal_screen.dart';

/// Le carte si distribuiscono davanti a tutti, coperte. Quali ruoli sono in
/// gioco è pubblico; chi ha preso cosa no.
class RoleDealScreen extends StatefulWidget {
  final GameSetup setup;

  const RoleDealScreen({super.key, required this.setup});

  @override
  State<RoleDealScreen> createState() => _RoleDealScreenState();
}

class _RoleDealScreenState extends State<RoleDealScreen> {
  bool _dealt = false;

  Map<Role, int> get _counts {
    final deck = widget.setup.roles.values.toList()..sort((a, b) => a.index.compareTo(b.index));
    final counts = <Role, int>{};
    for (final role in deck) {
      counts[role] = (counts[role] ?? 0) + 1;
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    final narrator = widget.setup.narrator;
    return SceneScaffold(
      appBar: AppBar(title: const Text('LE CARTE')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Text('NARRATORE', style: AppText.overline),
              const SizedBox(height: 4),
              Text(
                narrator?.name ?? 'Automatico',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: DealTable(
                    names: [for (final player in widget.setup.players) player.name],
                    onDealt: () => setState(() => _dealt = true),
                  ),
                ),
              ),
              Text(
                _dealt ? 'Le carte sono servite' : 'Si mescola il mazzo…',
                style: AppText.display(22, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 14),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in _counts.entries) _RoleChip(role: entry.key, count: entry.value),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _dealt
                      ? () => Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => RoleRevealScreen(setup: widget.setup),
                            ),
                          )
                      : null,
                  child: const Text('GUARDATE LE CARTE'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  final Role role;
  final int count;

  const _RoleChip({required this.role, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Color.lerp(role.color, Colors.black, 0.25),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(role.icon, size: 16, color: AppColors.textPrimary),
          const SizedBox(width: 6),
          Text(
            '$count × ${role.label}',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
