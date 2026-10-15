import '../ui/widgets/death_scene.dart';
import 'fx_groups.dart';

/// Gli effetti registrati che si sentono nel momento del colpo, per ogni
/// scena. Si sommano alla colonna sonora della scena.
List<FxGroup> strikeEffectsFor(DeathAct act) => switch (act) {
      DeathAct.knife || DeathAct.garrote => [FxGroup.whoosh],
      DeathAct.gun => [FxGroup.revolver],
      DeathAct.burst || DeathAct.driveBy => [FxGroup.tommy],
      DeathAct.lupara => [FxGroup.shotgun],
      DeathAct.sniper => [FxGroup.revolver, FxGroup.ricochet],
      DeathAct.car => [FxGroup.carhorn, FxGroup.screech],
      DeathAct.piano => [FxGroup.pianocrash],
      DeathAct.chandelier => [FxGroup.glassbreak],
      DeathAct.pot => [FxGroup.glassbreak],
      DeathAct.safe => [FxGroup.faint],
      DeathAct.blast => [FxGroup.explosion],
      DeathAct.poison => [FxGroup.cough],
      DeathAct.noose => [FxGroup.whoosh],
      DeathAct.grab => [FxGroup.faint],
      DeathAct.bat => [FxGroup.faint],
      DeathAct.manhole => [FxGroup.splash, FxGroup.fallwhist],
      DeathAct.blackout => [FxGroup.match],
      DeathAct.kiss => [FxGroup.kiss],
      DeathAct.rescue => [FxGroup.revolver],
      DeathAct.lucky => [FxGroup.ricochet],
    };

/// Come reagisce la vittima: un urlo, un "ahia", un lamento, un'esclamazione.
/// Chi si salva mugugna, non urla.
FxGroup? reactionFor(DeathAct act) => switch (act) {
      DeathAct.kiss => FxGroup.wolfwhistle,
      DeathAct.rescue || DeathAct.lucky => FxGroup.gasp,
      DeathAct.poison => FxGroup.groan,
      DeathAct.blackout => FxGroup.gasp,
      DeathAct.piano || DeathAct.safe || DeathAct.pot => FxGroup.ouch,
      DeathAct.manhole => FxGroup.scream,
      _ => FxGroup.scream,
    };
