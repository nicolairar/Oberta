import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../theme/app_theme.dart';
import 'avatar_spotlight.dart';
import '../press.dart';

/// Schermo neutro tra un giocatore e l'altro quando il telefono è uno solo:
/// non mostra nulla di segreto finché chi lo riceve non dice che è pronto.
class HandoffView extends StatelessWidget {
  final String name;
  final VoidCallback onReady;

  const HandoffView({super.key, required this.name, required this.onReady});

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    return Column(
      children: [
        const Spacer(),
        AvatarSpotlight(seed: name, size: 140),
        const SizedBox(height: 28),
        Text(t.passThePhoneTo, style: AppText.overline),
        const SizedBox(height: 10),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(name.toUpperCase(), style: AppText.display(40)),
        ),
        const SizedBox(height: 16),
        Text(
          t.nobodyElseLooks,
          textAlign: TextAlign.center,
          style: AppText.body,
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(onPressed: pressed(onReady, Press.confirm), child: Text(t.itsMe)),
        ),
      ],
    );
  }
}
