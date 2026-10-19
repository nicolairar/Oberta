import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../rules/game_engine.dart';
import '../../rules/player.dart';
import '../theme/app_theme.dart';

/// Le due etichette della scelta tra il compito e il suo alternativo: il
/// Sarto vota o cuce, il Piromane cosparge o accende.
(String, String) alternativeLabels(AppStrings t, NightTaskKind? alternative) => switch (alternative) {
  NightTaskKind.ignite => (t.dousePick, t.lightTheMatch),
  _ => (t.voteTheHit, t.sewAMouth),
};

/// Sopra la scelta della notte, solo per chi la fa: quello che il Portinaio
/// ha visto la notte prima, e chi il Piromane ha già cosparso.
class NightNotes extends StatelessWidget {
  final WatchReport? lastWatch;
  final List<Player> doused;

  /// Per il Cacciatore di taglie: chi deve far linciare.
  final Player? bounty;

  const NightNotes({super.key, this.lastWatch, this.doused = const [], this.bounty});

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    final watch = lastWatch;
    final lines = [
      if (watch != null)
        (watch.visited ? t.pack.watchVisited : t.pack.watchQuiet).replaceAll('{name}', watch.target.name),
      if (doused.isNotEmpty) '${t.dousedBadge}: ${doused.map((p) => p.name).join(', ')}',
      if (bounty case final mark?) t.bountyLine.replaceAll('{name}', mark.name),
    ];
    if (lines.isEmpty) return const SizedBox.shrink();
    return Padding(
      key: const Key('night.notes'),
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        children: [
          for (final line in lines)
            Text(
              line,
              textAlign: TextAlign.center,
              style: AppText.body.copyWith(fontSize: 13, color: AppColors.gold),
            ),
        ],
      ),
    );
  }
}
