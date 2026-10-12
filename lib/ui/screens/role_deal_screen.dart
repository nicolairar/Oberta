import 'dart:math';

import 'package:flutter/material.dart';

import '../../rules/game_setup.dart';
import '../../rules/role.dart';
import '../theme/app_theme.dart';
import '../theme/role_style.dart';
import '../widgets/spin_wheel.dart';
import 'role_reveal_screen.dart';

/// La ruota mescola il mazzo davanti a tutti. I ruoli in gioco sono pubblici,
/// chi ha preso cosa no: per questo la ruota non ha freccia né vincitore.
class RoleDealScreen extends StatefulWidget {
  final GameSetup setup;

  const RoleDealScreen({super.key, required this.setup});

  @override
  State<RoleDealScreen> createState() => _RoleDealScreenState();
}

class _RoleDealScreenState extends State<RoleDealScreen> {
  late final List<Role> _deck = widget.setup.roles.values.toList()
    ..sort((a, b) => a.index.compareTo(b.index));
  late final double _finalAngle = 2 * pi * (5 + Random().nextDouble());
  bool _stopped = false;

  Map<Role, int> get _counts {
    final counts = <Role, int>{};
    for (final role in _deck) {
      counts[role] = (counts[role] ?? 0) + 1;
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    final narrator = widget.setup.narrator;
    return Scaffold(
      appBar: AppBar(title: const Text('I RUOLI')),
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
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: SpinWheel(
                      segments: [for (final role in _deck) WheelSegment(role.label, role.color)],
                      finalAngle: _finalAngle,
                      duration: const Duration(milliseconds: 4200),
                      showPointer: false,
                      onStopped: () => setState(() => _stopped = true),
                    ),
                  ),
                ),
              ),
              Text(
                _stopped ? 'Le carte sono pronte' : 'Si mescolano le carte…',
                style: AppText.display(22, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in _counts.entries) _RoleChip(role: entry.key, count: entry.value),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _stopped
                      ? () => Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => RoleRevealScreen(setup: widget.setup),
                            ),
                          )
                      : null,
                  child: const Text('DISTRIBUISCI LE CARTE'),
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
        color: role.color.withValues(alpha: 0.55),
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
