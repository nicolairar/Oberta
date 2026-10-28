import '../../l10n/app_language.dart';
import '../../l10n/app_strings.dart';
import '../../rules/game_engine.dart';

/// Le due etichette della scelta tra il compito e il suo alternativo: il
/// Sarto vota o cuce, il Piromane cosparge o accende.
(String, String) alternativeLabels(AppStrings t, NightTaskKind? alternative) => switch (alternative) {
  NightTaskKind.ignite => (t.dousePick, t.lightTheMatch),
  // La Prostituta rimasta sola: vota l'agguato, o passa la notte fuori.
  NightTaskKind.block => (t.voteTheHit, t.language == AppLanguage.en ? 'Spend the night' : 'Passa la notte'),
  _ => (t.voteTheHit, t.sewAMouth),
};
