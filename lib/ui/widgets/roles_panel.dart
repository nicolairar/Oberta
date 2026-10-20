import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../l10n/roles_sheet_strings.dart';
import '../../rules/role.dart';
import '../theme/app_theme.dart';
import '../theme/role_style.dart';
import 'roles_sheet.dart';

/// Su schermo largo, sopra la chat: il mazzo di questa partita a colpo
/// d'occhio. Ogni carta è la sua icona col nome sotto; quelle già scoperte
/// morte sono spente e barrate, con quante ne sono uscite. Un tocco (o il
/// mouse sopra) dice cosa fa il ruolo.
class RolesPanel extends StatelessWidget {
  final Map<Role, int> deck;
  final List<RevealedRole> revealed;

  /// L'altezza fissa: due file, poi si scorre.
  static const double height = 132;

  const RolesPanel({super.key, required this.deck, required this.revealed});

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    final s = RolesSheetStrings.of(context);
    return Container(
      key: const Key('rolesPanel'),
      height: height,
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.55), width: 1.1),
      ),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            s.title.toUpperCase(),
            style: const TextStyle(color: AppColors.gold, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.6),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final MapEntry(key: role, value: count) in deck.entries)
                    _tile(t, role, count, revealed.where((r) => r.role == role).length.clamp(0, count)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(AppStrings t, Role role, int count, int gone) {
    final text = t.role(role);
    final allGone = gone >= count;
    final badge = gone > 0 ? '†$gone/$count' : (count > 1 ? '×$count' : null);
    return Tooltip(
      key: Key('rolesPanel.${role.name}'),
      triggerMode: TooltipTriggerMode.tap,
      showDuration: const Duration(seconds: 6),
      constraints: const BoxConstraints(maxWidth: 260),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: role.color, width: 1.2),
      ),
      textStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 12, height: 1.3),
      richMessage: TextSpan(
        children: [
          TextSpan(
            text: '${text.label}\n',
            style: TextStyle(color: role.color, fontWeight: FontWeight.w800, fontSize: 13),
          ),
          TextSpan(text: text.description),
        ],
      ),
      child: SizedBox(
        width: 60,
        child: Opacity(
          opacity: allGone ? 0.4 : 1,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  if (allGone)
                    ColorFiltered(
                      colorFilter: const ColorFilter.matrix(<double>[
                        0.33, 0.33, 0.33, 0, 0, //
                        0.33, 0.33, 0.33, 0, 0, //
                        0.33, 0.33, 0.33, 0, 0, //
                        0, 0, 0, 1, 0,
                      ]),
                      child: RoleIcon(role, size: 30),
                    )
                  else
                    RoleIcon(role, size: 30),
                  if (allGone) const Positioned.fill(child: CustomPaint(painter: _CrossPainter())),
                  if (badge != null)
                    Positioned(
                      right: -16,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                        decoration: BoxDecoration(
                          color: gone > 0 ? const Color(0xFF7A1E26) : AppColors.surface,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.gold.withValues(alpha: 0.5), width: 0.6),
                        ),
                        child: Text(
                          badge,
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 8, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                text.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: role.team == Team.mafia ? const Color(0xFFE5606A) : AppColors.textPrimary,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  decoration: allGone ? TextDecoration.lineThrough : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CrossPainter extends CustomPainter {
  const _CrossPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFFB0303C)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(3, 3), Offset(size.width - 3, size.height - 3), p);
    canvas.drawLine(Offset(size.width - 3, 3), Offset(3, size.height - 3), p);
  }

  @override
  bool shouldRepaint(_CrossPainter old) => false;
}
