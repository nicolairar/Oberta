import '../ui/widgets/verdict_scene.dart';
import 'fx_groups.dart';
import 'scene_cues.dart';

/// I suoni dei filmati del verdetto, agganciati ai momenti del film
/// ([VerdictBeats]): la folla quando marcia, il tonfo quando il cemento
/// cade, il tuffo quando il condannato tocca l'acqua.
List<SceneCue> verdictCuesFor(VerdictTake take) {
  final cues = <SceneCue>[
    const SceneCue.fx(VerdictBeats.marchFrom, FxGroup.whisper, 0.35),
    ...switch (take) {
      VerdictTake.molo => [
          const SceneCue.fx(VerdictBeats.cementLands, FxGroup.thud, 0.7),
          const SceneCue.sample(VerdictBeats.cementLands + 0.002, 'body_fall_2', 0.6),
          const SceneCue.sample(VerdictBeats.poke, 'punch_2', 0.5),
          const SceneCue.fx(VerdictBeats.drop - 0.01, FxGroup.fallwhist, 0.55),
          const SceneCue.fx(VerdictBeats.splash, FxGroup.splash, 0.8),
          const SceneCue.fx(VerdictBeats.lastBubble - 0.03, FxGroup.bubbles, 0.45),
        ],
      VerdictTake.cartello => [
          const SceneCue.fx(VerdictBeats.point, FxGroup.boo, 0.55),
          const SceneCue.fx(VerdictBeats.carIn, FxGroup.carhorn, 0.55),
          const SceneCue.fx(VerdictBeats.carIn + 0.01, FxGroup.engine, 0.45),
          const SceneCue.fx(VerdictBeats.carPass - 0.03, FxGroup.carpass, 0.6),
          const SceneCue.fx(VerdictBeats.cough, FxGroup.cough, 0.6),
          const SceneCue.fx(VerdictBeats.tumbleweed, FxGroup.wind, 0.35),
        ],
      VerdictTake.treno => [
          const SceneCue.sample(VerdictBeats.doorShuts, 'wood_heavy_2', 0.5),
          const SceneCue.fx(VerdictBeats.whistle, FxGroup.train, 0.7),
          const SceneCue.fx(VerdictBeats.sniff, FxGroup.cough, 0.4),
        ],
      VerdictTake.cannone => [
          const SceneCue.fx(VerdictBeats.jump, FxGroup.boing, 0.55),
          const SceneCue.fx(VerdictBeats.slide, FxGroup.slidewhist, 0.5),
          const SceneCue.fx(VerdictBeats.torch, FxGroup.match, 0.6),
          const SceneCue.fx(VerdictBeats.fuse, FxGroup.fuse, 0.5),
          const SceneCue.fx(VerdictBeats.boom, FxGroup.explosion, 0.8),
          const SceneCue.sample(VerdictBeats.ping, 'metal_light', 0.6),
          const SceneCue.fx(VerdictBeats.shoe, FxGroup.fallwhist, 0.4),
          const SceneCue.sample(VerdictBeats.bonk, 'wood_heavy', 0.6),
        ],
      VerdictTake.assoluzione => [
          const SceneCue.fx(0.12, FxGroup.boo, 0.5),
          const SceneCue.fx(VerdictBeats.disperse, FxGroup.whisper, 0.3),
          const SceneCue.fx(VerdictBeats.disperse + 0.02, FxGroup.running, 0.3),
          const SceneCue.fx(VerdictBeats.emptySquare, FxGroup.wind, 0.35),
        ],
    },
  ];
  cues.sort((a, b) => a.t.compareTo(b.t));
  return cues;
}
