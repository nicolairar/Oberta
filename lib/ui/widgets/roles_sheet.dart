import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../l10n/roles_sheet_strings.dart';
import '../../rules/player_view.dart';
import '../../rules/role.dart';
import '../theme/app_theme.dart';
import '../theme/role_style.dart';
import 'role_rules.dart';

/// Un ruolo scoperto davanti a tutti: chi era e cosa era.
typedef RevealedRole = ({Role role, String name});

/// I ruoli già scoperti in pubblico: i fatti del tabellone e, a partita
/// finita, tutte le carte. Solo quello che vede chiunque.
List<RevealedRole> publicReveals(PublicView board) {
  final seen = <String>{};
  return [
    for (final known in board.revealed)
      if (known.knowledge.role case final role? when seen.add(known.seat.id)) (role: role, name: known.seat.name),
    for (final entry in board.finalRoles.entries)
      if (seen.add(entry.key.id)) (role: entry.value, name: entry.key.name),
  ];
}

/// Il bottone «RUOLI» nell'intestazione: un mazzo di carte con la scritta.
class RolesButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Color color;

  const RolesButton({super.key, required this.onPressed, this.color = AppColors.gold});

  @override
  Widget build(BuildContext context) {
    final s = RolesSheetStrings.of(context);
    return Tooltip(
      message: s.title,
      child: InkWell(
        key: const Key('rolesSheet.button'),
        borderRadius: BorderRadius.circular(8),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.style, color: color, size: 22),
              Text(s.button, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Il foglio «I ruoli»: il mazzo di questa partita con cosa fa ogni carta,
/// quelle già scoperte, e la legenda dei simboli. Mai un segreto: solo la
/// composizione del mazzo e i fatti pubblici.
class RolesSheet extends StatelessWidget {
  final Map<Role, int> deck;
  final List<RevealedRole> revealed;

  const RolesSheet({super.key, required this.deck, required this.revealed});

  static Future<void> show(BuildContext context, {required Map<Role, int> deck, required List<RevealedRole> revealed}) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.background,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheet) => Localizations.override(
        context: sheet,
        locale: Localizations.localeOf(context),
        child: FractionallySizedBox(
          heightFactor: 0.85,
          child: RolesSheet(deck: deck, revealed: revealed),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    final s = RolesSheetStrings.of(context);
    final cards = <Widget>[];
    for (final MapEntry(key: role, value: count) in deck.entries) {
      final reveals = [for (final r in revealed) if (r.role == role) r.name];
      for (var i = 0; i < reveals.length && i < count; i++) {
        cards.add(_card(t, s, role, 1, reveals[i]));
      }
      if (count > reveals.length) cards.add(_card(t, s, role, count - reveals.length, null));
    }
    return ListView(
      key: const Key('rolesSheet'),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      children: [
        Text(s.title, style: AppText.display(22, color: AppColors.gold)),
        const SizedBox(height: 4),
        Text(s.subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        const SizedBox(height: 12),
        if (cards.isEmpty) Text(s.deckEmpty, style: const TextStyle(color: AppColors.textSecondary)),
        ...cards,
        const SizedBox(height: 18),
        Text(s.legendTitle, style: AppText.display(16, color: AppColors.gold)),
        const SizedBox(height: 6),
        for (final (symbol, text) in [
          ('🤐', s.silencedLegend),
          ('⚪', s.offlineLegend),
          ('🌹', s.deadLegend),
          ('🎗️', s.accusedLegend),
          ('🔴', s.votesLegend),
          ('📝', s.voteNoteLegend),
          ('🃏', s.revealedRoleLegend),
          ('⭐', s.meLegend),
        ])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 28, child: Text(symbol, style: const TextStyle(fontSize: 16))),
                Expanded(child: Text(text, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13))),
              ],
            ),
          ),
      ],
    );
  }

  Widget _card(AppStrings t, RolesSheetStrings s, Role role, int count, String? revealedName) {
    final text = t.role(role);
    final done = revealedName != null;
    return Opacity(
      opacity: done ? 0.45 : 1,
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border(left: BorderSide(color: role.color, width: 4)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RoleIcon(role, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    count > 1 ? '${text.label} ×$count' : text.label,
                    style: TextStyle(
                      color: role.team == Team.mafia ? const Color(0xFFE5606A) : AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      decoration: done ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  if (done)
                    Text(s.revealedBy(revealedName), style: const TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w700)),
                  Text(text.motto, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontStyle: FontStyle.italic)),
                  const SizedBox(height: 2),
                  RoleRules(role, color: AppColors.textPrimary, labelColor: AppColors.gold),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
