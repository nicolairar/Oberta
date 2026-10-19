import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../rules/role.dart';

/// Cosa fa un ruolo e quando vince, in poche frasi.
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
  Widget build(BuildContext context) => Text(
    AppStrings.of(context).role(role).description,
    textAlign: center ? TextAlign.center : TextAlign.start,
    style: TextStyle(color: color, fontSize: fontSize, height: 1.35),
  );
}
