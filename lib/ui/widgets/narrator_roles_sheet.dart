import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../rules/game_setup.dart';
import '../../rules/player.dart';
import '../../rules/role.dart';
import '../theme/app_theme.dart';
import '../theme/role_style.dart';
import 'noir_modal.dart';

/// Elenco completo dei ruoli, riservato al narratore umano: resta coperto e
/// si legge solo a dito premuto, così non rimane mai in vista sul tavolo.
class NarratorRolesSheet extends StatefulWidget {
  final GameSetup setup;
  final bool Function(Player) isAlive;

  const NarratorRolesSheet({super.key, required this.setup, required this.isAlive});

  static Future<void> show(
    BuildContext context, {
    required GameSetup setup,
    required bool Function(Player) isAlive,
  }) {
    return showNoirSheet<void>(
      context,
      heightFactor: 0.7,
      builder: (_) => NoirSheet(
        scroll: false,
        children: [Expanded(child: NarratorRolesSheet(setup: setup, isAlive: isAlive))],
      ),
    );
  }

  @override
  State<NarratorRolesSheet> createState() => _NarratorRolesSheetState();
}

class _NarratorRolesSheetState extends State<NarratorRolesSheet> {
  bool _visible = false;

  // Il rilascio può arrivare dopo che il foglio è uscito dallo schermo.
  void _show(bool visible) {
    if (mounted) setState(() => _visible = visible);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    return Listener(
      onPointerDown: (_) => _show(true),
      onPointerUp: (_) => _show(false),
      onPointerCancel: (_) => _show(false),
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
          child: _visible
              ? ListView(
                  key: const ValueKey('roles'),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    for (final entry in widget.setup.roles.entries)
                      _row(t, entry.key, entry.value, widget.isAlive(entry.key)),
                  ],
                )
              : Column(
                  key: const ValueKey('hidden'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.visibility_off, color: AppColors.textSecondary, size: 36),
                    const SizedBox(height: 12),
                    Text(t.narratorOnly, style: AppText.overline),
                    const SizedBox(height: 6),
                    Text(t.holdToSeeRoles, style: AppText.body),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _row(AppStrings t, Player player, Role role, bool alive) {
    return Opacity(
      opacity: alive ? 1 : 0.4,
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: role.color,
          child: RoleIcon(role, size: 30),
        ),
        title: Text(
          player.name,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            decoration: alive ? null : TextDecoration.lineThrough,
          ),
        ),
        trailing: Text(
          t.role(role).label,
          style: TextStyle(
            color: role.team == Team.mafia ? const Color(0xFFE5606A) : AppColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
