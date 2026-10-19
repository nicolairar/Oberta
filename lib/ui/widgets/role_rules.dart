import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../l10n/roles_sheet_strings.dart';
import '../../rules/role.dart';

/// Le regole di un ruolo, riga per riga: squadra, di notte, vinci se e
/// l'eventuale avvertenza. L'etichetta in grassetto, poi la regola secca.
class RoleRules extends StatelessWidget {
  final Role role;
  final Color color;
  final Color labelColor;
  final double fontSize;
  final bool center;

  const RoleRules(
    this.role, {
    super.key,
    required this.color,
    required this.labelColor,
    this.fontSize = 13,
    this.center = false,
  });

  @override
  Widget build(BuildContext context) {
    final text = AppStrings.of(context).role(role);
    final s = RolesSheetStrings.of(context);
    final team = switch (role.team) {
      Team.mafia => s.teamFamily,
      Team.citizens => s.teamTown,
      Team.neutral => s.teamAlone,
    };
    final rows = [
      (s.teamLabel, '$team.'),
      (s.nightLabel, text.night),
      (s.winLabel, text.win),
      if (text.twist case final twist?) (s.twistLabel, twist),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        for (final (label, rule) in rows)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: TextStyle(color: labelColor, fontWeight: FontWeight.w900),
                  ),
                  TextSpan(text: rule),
                ],
              ),
              textAlign: center ? TextAlign.center : TextAlign.start,
              style: TextStyle(color: color, fontSize: fontSize, height: 1.3),
            ),
          ),
      ],
    );
  }
}
