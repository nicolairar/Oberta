import '../ui/widgets/death_scene.dart';
import 'fx_groups.dart';
import 'memes.dart';

/// Un suono di una scena, agganciato al momento esatto del film in cui
/// succede la cosa che si vede: il passo quando il piede tocca terra, lo
/// sparo quando esce il lampo, il tonfo quando il corpo arriva giù.
///
/// Il suono è o un gruppo di effetti registrati ([fx], una registrazione a
/// caso) o un campione dei pacchetti Kenney ([sample]). [gain] lo dosa
/// rispetto agli altri: è il mixaggio della scena.
class SceneCue {
  final double t;
  final FxGroup? fx;
  final String? sample;
  final Meme? meme;
  final double gain;

  const SceneCue.fx(this.t, FxGroup this.fx, [this.gain = 1])
      : sample = null,
        meme = null;

  const SceneCue.sample(this.t, String this.sample, [this.gain = 1])
      : fx = null,
        meme = null;

  const SceneCue.meme(this.t, Meme this.meme)
      : fx = null,
        sample = null,
        gain = 1;
}

const _s = DeathScenePainter.strike;

/// I passi della vittima che arriva sotto il lampione: uno per ogni volta
/// che un piede tocca terra nell'animazione.
List<SceneCue> _entrance() => [
      for (var step = 0; step < 9; step++)
        SceneCue.sample(0.04 + 0.30 * (step + 0.5) / 9, 'step_${step % 4 + 1}', 0.35),
    ];

/// Tutti i suoni di una scena, in ordine di tempo. [memes] mette, dove ha
/// senso, un meme al posto della reazione.
List<SceneCue> sceneCuesFor(DeathAct act, {bool memes = false}) {
  SceneCue reaction(double t, FxGroup fx, [double gain = 0.8]) {
    if (memes) {
      final meme = reactionMeme(act);
      if (meme != null) return SceneCue.meme(t, meme);
    }
    return SceneCue.fx(t, fx, gain);
  }

  final cues = <SceneCue>[
    ..._entrance(),
    ...switch (act) {
      DeathAct.knife => [
          const SceneCue.sample(_s - 0.012, 'knife', 0.9),
          reaction(_s + 0.02, FxGroup.scream),
          const SceneCue.fx(_s + 0.13, FxGroup.faint, 0.7),
        ],
      DeathAct.gun => [
          const SceneCue.fx(_s, FxGroup.revolver, 0.75),
          reaction(_s + 0.025, FxGroup.ouch),
          const SceneCue.fx(_s + 0.13, FxGroup.faint, 0.7),
        ],
      DeathAct.burst => [
          const SceneCue.fx(0.55, FxGroup.tommy, 0.7),
          reaction(0.66, FxGroup.scream),
          const SceneCue.fx(0.78, FxGroup.faint, 0.7),
        ],
      DeathAct.car => [
          const SceneCue.fx(0.47, FxGroup.carhorn, 0.6),
          const SceneCue.fx(0.51, FxGroup.screech, 0.6),
          reaction(_s - 0.01, FxGroup.scream),
          const SceneCue.sample(_s, 'metal_heavy', 0.8),
          const SceneCue.sample(_s + 0.01, 'glass_medium', 0.5),
        ],
      DeathAct.piano => [
          const SceneCue.fx(0.47, FxGroup.fallwhist, 0.5),
          const SceneCue.fx(_s, FxGroup.pianocrash, 0.8),
          reaction(_s + 0.04, FxGroup.ouch),
        ],
      DeathAct.safe => [
          const SceneCue.fx(0.47, FxGroup.fallwhist, 0.5),
          const SceneCue.sample(_s, 'metal_heavy', 1),
          const SceneCue.sample(_s + 0.005, 'body_fall', 0.8),
          reaction(_s + 0.04, FxGroup.ouch),
        ],
      DeathAct.chandelier => [
          const SceneCue.fx(0.47, FxGroup.fallwhist, 0.4),
          const SceneCue.fx(_s, FxGroup.glassbreak, 0.8),
          reaction(_s + 0.03, FxGroup.scream),
        ],
      DeathAct.blast => [
          const SceneCue.fx(0.41, FxGroup.fuse, 0.4),
          const SceneCue.fx(_s, FxGroup.explosion, 0.8),
        ],
      DeathAct.poison => [
          const SceneCue.fx(0.51, FxGroup.cough, 0.6),
          const SceneCue.sample(_s + 0.01, 'glass_medium', 0.4),
          reaction(_s + 0.04, FxGroup.groan),
          const SceneCue.fx(_s + 0.16, FxGroup.faint, 0.6),
        ],
      DeathAct.noose => [
          const SceneCue.fx(_s - 0.05, FxGroup.whoosh, 0.5),
          const SceneCue.sample(_s, 'creak', 0.8),
          reaction(_s + 0.03, FxGroup.gasp),
        ],
      DeathAct.grab => [
          const SceneCue.sample(_s, 'punch', 0.8),
          reaction(_s + 0.02, FxGroup.gasp),
          const SceneCue.sample(_s + 0.06, 'cloth_1', 0.5),
          const SceneCue.fx(_s + 0.22, FxGroup.faint, 0.7),
        ],
      DeathAct.bat => [
          const SceneCue.fx(_s - 0.02, FxGroup.whoosh, 0.5),
          const SceneCue.sample(_s, 'wood_heavy', 0.9),
          reaction(_s + 0.04, FxGroup.ouch),
          const SceneCue.fx(_s + 0.19, FxGroup.faint, 0.7),
        ],
      DeathAct.lupara => [
          const SceneCue.fx(_s, FxGroup.shotgun, 0.8),
          reaction(_s + 0.03, FxGroup.scream),
          const SceneCue.fx(_s + 0.14, FxGroup.faint, 0.7),
        ],
      DeathAct.driveBy => [
          const SceneCue.fx(0.44, FxGroup.carpass, 0.5),
          const SceneCue.fx(0.535, FxGroup.tommy, 0.7),
          reaction(0.625, FxGroup.scream),
          const SceneCue.fx(0.635, FxGroup.glassbreak, 0.5),
          const SceneCue.fx(0.71, FxGroup.faint, 0.7),
        ],
      DeathAct.garrote => [
          const SceneCue.sample(_s, 'cloth_2', 0.6),
          reaction(_s + 0.02, FxGroup.gasp),
          const SceneCue.fx(0.82, FxGroup.faint, 0.7),
        ],
      DeathAct.pot => [
          const SceneCue.fx(0.47, FxGroup.fallwhist, 0.4),
          const SceneCue.sample(_s, 'plate', 0.9),
          reaction(_s + 0.04, FxGroup.ouch),
          const SceneCue.fx(_s + 0.20, FxGroup.faint, 0.7),
        ],
      DeathAct.manhole => [
          const SceneCue.sample(0.50, 'metal_medium', 0.5),
          const SceneCue.fx(_s, FxGroup.fallwhist, 0.6),
          reaction(_s + 0.01, FxGroup.scream),
          const SceneCue.fx(_s + 0.075, FxGroup.splash, 0.7),
          const SceneCue.sample(_s + 0.19, 'metal_heavy', 0.6),
        ],
      DeathAct.blackout => [
          const SceneCue.sample(0.50, 'latch', 0.6),
          const SceneCue.sample(_s, 'knife_2', 0.9),
          reaction(_s + 0.02, FxGroup.scream),
          const SceneCue.fx(_s + 0.07, FxGroup.faint, 0.7),
        ],
      DeathAct.kiss => [
          if (memes) const SceneCue.meme(0.47, Meme.rizz),
          const SceneCue.fx(_s, FxGroup.kiss, 0.8),
          reaction(0.62, FxGroup.groan),
          const SceneCue.fx(0.77, FxGroup.faint, 0.6),
        ],
      DeathAct.sniper => [
          const SceneCue.fx(_s, FxGroup.revolver, 0.55),
          reaction(_s + 0.02, FxGroup.ouch),
          const SceneCue.fx(_s + 0.11, FxGroup.faint, 0.7),
        ],
      DeathAct.rescue => [
          const SceneCue.fx(_s, FxGroup.revolver, 0.75),
          const SceneCue.fx(_s + 0.07, FxGroup.faint, 0.6),
          for (var step = 0; step < 7; step++) SceneCue.sample(0.62 + step * 0.0125, 'step_${step % 4 + 1}', 0.5),
          if (memes) const SceneCue.meme(0.715, Meme.applePay) else const SceneCue.sample(0.715, 'bag', 0.7),
          const SceneCue.fx(0.765, FxGroup.heartbeat, 0.7),
          const SceneCue.fx(0.845, FxGroup.gasp, 0.6),
        ],
      DeathAct.lucky => [
          const SceneCue.fx(_s, FxGroup.revolver, 0.75),
          const SceneCue.sample(_s + 0.003, 'metal_light', 0.8),
          const SceneCue.fx(_s + 0.01, FxGroup.ricochet, 0.6),
          const SceneCue.fx(_s + 0.04, FxGroup.gasp, 0.6),
          for (var step = 0; step < 6; step++) SceneCue.sample(0.675 + step * 0.012, 'step_${step % 4 + 1}', 0.45),
        ],
    },
  ];
  // In modalità meme, ogni tanto il colpo si porta dietro il suo meme.
  if (memes) {
    final meme = strikeMeme(act);
    if (meme != null && act != DeathAct.kiss && act != DeathAct.rescue) cues.add(SceneCue.meme(_s, meme));
  }
  cues.sort((a, b) => a.t.compareTo(b.t));
  return cues;
}
