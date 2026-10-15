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
          // La lama esce dalla giacca mentre il braccio si alza, fischia
          // nell'aria e affonda; poi il corpo a terra e i passi che scappano.
          const SceneCue.fx(0.465, FxGroup.unsheath, 0.45),
          const SceneCue.fx(_s - 0.015, FxGroup.swish, 0.5),
          const SceneCue.fx(_s, FxGroup.stab, 0.85),
          reaction(_s + 0.02, FxGroup.scream),
          const SceneCue.fx(_s + 0.13, FxGroup.faint, 0.7),
          const SceneCue.fx(0.71, FxGroup.running, 0.35),
        ],
      DeathAct.gun => [
          // Il cane armato quando la pistola esce dall'angolo, il colpo
          // smorzato del silenziatore, il bossolo che tintinna a terra.
          const SceneCue.fx(0.505, FxGroup.cock, 0.55),
          const SceneCue.fx(_s, FxGroup.silencer, 0.85),
          const SceneCue.fx(_s + 0.005, FxGroup.impact, 0.45),
          reaction(_s + 0.025, FxGroup.ouch),
          const SceneCue.fx(_s + 0.035, FxGroup.casing, 0.4),
          const SceneCue.fx(_s + 0.13, FxGroup.faint, 0.7),
          const SceneCue.fx(0.69, FxGroup.running, 0.35),
        ],
      DeathAct.burst => [
          const SceneCue.fx(0.50, FxGroup.bolt, 0.5),
          const SceneCue.fx(0.55, FxGroup.tommy, 0.75),
          const SceneCue.fx(0.585, FxGroup.casing, 0.4),
          const SceneCue.fx(0.625, FxGroup.casing, 0.35),
          reaction(0.66, FxGroup.scream),
          const SceneCue.fx(0.78, FxGroup.faint, 0.7),
          const SceneCue.fx(0.775, FxGroup.running, 0.35),
        ],
      DeathAct.car => [
          const SceneCue.fx(0.44, FxGroup.engine, 0.55),
          const SceneCue.fx(0.47, FxGroup.carhorn, 0.6),
          const SceneCue.fx(0.51, FxGroup.screech, 0.6),
          reaction(_s - 0.01, FxGroup.scream),
          const SceneCue.sample(_s, 'metal_heavy', 0.8),
          const SceneCue.sample(_s + 0.01, 'glass_medium', 0.5),
          // La vittima ricade lontano, dopo il volo sopra il tetto.
          const SceneCue.fx(0.675, FxGroup.faint, 0.6),
        ],
      DeathAct.piano => [
          // La corda che scricchiola, poi cede.
          const SceneCue.sample(0.44, 'creak', 0.45),
          const SceneCue.fx(0.50, FxGroup.rope, 0.45),
          const SceneCue.fx(0.505, FxGroup.fallwhist, 0.5),
          const SceneCue.fx(_s, FxGroup.pianocrash, 0.8),
          const SceneCue.fx(_s + 0.01, FxGroup.debris, 0.45),
          reaction(_s + 0.04, FxGroup.ouch),
        ],
      DeathAct.safe => [
          const SceneCue.sample(0.44, 'creak', 0.45),
          const SceneCue.fx(0.50, FxGroup.rope, 0.45),
          const SceneCue.fx(0.505, FxGroup.fallwhist, 0.5),
          const SceneCue.fx(_s, FxGroup.thud, 0.85),
          const SceneCue.sample(_s + 0.003, 'metal_heavy', 0.7),
          const SceneCue.fx(_s + 0.012, FxGroup.debris, 0.45),
          reaction(_s + 0.04, FxGroup.ouch),
        ],
      DeathAct.chandelier => [
          // La catena che cede, poi i cristalli in pezzi.
          const SceneCue.fx(0.50, FxGroup.chain, 0.5),
          const SceneCue.fx(0.505, FxGroup.fallwhist, 0.4),
          const SceneCue.fx(_s, FxGroup.glassbreak, 0.8),
          const SceneCue.fx(_s + 0.005, FxGroup.chain, 0.45),
          reaction(_s + 0.03, FxGroup.scream),
        ],
      DeathAct.blast => [
          const SceneCue.fx(0.41, FxGroup.fuse, 0.4),
          const SceneCue.fx(_s, FxGroup.explosion, 0.8),
          const SceneCue.fx(_s + 0.03, FxGroup.debris, 0.5),
          // Annerito, va giù tutto d'un pezzo.
          const SceneCue.fx(0.775, FxGroup.faint, 0.6),
        ],
      DeathAct.poison => [
          const SceneCue.fx(0.42, FxGroup.gulp, 0.5),
          const SceneCue.fx(0.505, FxGroup.cough, 0.6),
          const SceneCue.fx(0.53, FxGroup.cough, 0.45),
          // La tazzina scivola di mano e va in pezzi sull'asfalto.
          const SceneCue.fx(_s + 0.037, FxGroup.ceramic, 0.55),
          reaction(_s + 0.045, FxGroup.groan),
          const SceneCue.fx(_s + 0.16, FxGroup.faint, 0.6),
        ],
      DeathAct.noose => [
          const SceneCue.fx(_s - 0.05, FxGroup.whoosh, 0.5),
          const SceneCue.sample(_s, 'creak', 0.8),
          const SceneCue.fx(_s + 0.01, FxGroup.rope, 0.55),
          reaction(_s + 0.03, FxGroup.gasp),
          // Gli altri due strattoni.
          const SceneCue.sample(0.60, 'creak', 0.55),
          const SceneCue.sample(0.64, 'creak', 0.5),
          const SceneCue.fx(0.70, FxGroup.rope, 0.35),
        ],
      DeathAct.grab => [
          const SceneCue.fx(_s, FxGroup.punch, 0.8),
          reaction(_s + 0.02, FxGroup.gasp),
          const SceneCue.sample(_s + 0.035, 'cloth_1', 0.45),
          // I tacchi che strisciano mentre la trascinano dietro il muro.
          const SceneCue.fx(_s + 0.045, FxGroup.drag, 0.5),
          // Da dietro l'angolo: il tonfo, e il cemento che si sbriciola.
          const SceneCue.fx(_s + 0.22, FxGroup.thud, 0.65),
          const SceneCue.fx(_s + 0.235, FxGroup.debris, 0.35),
        ],
      DeathAct.bat => [
          const SceneCue.fx(_s - 0.012, FxGroup.swish, 0.55),
          const SceneCue.fx(_s, FxGroup.bathit, 0.85),
          const SceneCue.sample(_s + 0.002, 'wood_heavy', 0.6),
          reaction(_s + 0.04, FxGroup.ouch),
          const SceneCue.fx(_s + 0.19, FxGroup.faint, 0.7),
          const SceneCue.fx(0.73, FxGroup.running, 0.35),
        ],
      DeathAct.lupara => [
          const SceneCue.fx(0.50, FxGroup.cock, 0.55),
          const SceneCue.fx(_s, FxGroup.shotgun, 0.85),
          reaction(_s + 0.03, FxGroup.scream),
          const SceneCue.fx(_s + 0.14, FxGroup.faint, 0.75),
          const SceneCue.fx(0.72, FxGroup.pump, 0.4),
          const SceneCue.fx(0.75, FxGroup.running, 0.35),
        ],
      DeathAct.driveBy => [
          const SceneCue.fx(0.42, FxGroup.engine, 0.5),
          const SceneCue.fx(0.44, FxGroup.carpass, 0.5),
          const SceneCue.fx(0.535, FxGroup.tommy, 0.75),
          const SceneCue.fx(0.545, FxGroup.whiz, 0.35),
          const SceneCue.fx(0.59, FxGroup.ricochet, 0.35),
          reaction(0.625, FxGroup.scream),
          // L'ultimo colpo si porta via il lampione.
          const SceneCue.fx(0.63, FxGroup.bulb, 0.6),
          const SceneCue.fx(0.71, FxGroup.faint, 0.7),
        ],
      DeathAct.garrote => [
          const SceneCue.sample(_s, 'cloth_2', 0.6),
          const SceneCue.fx(_s + 0.005, FxGroup.rope, 0.6),
          reaction(_s + 0.02, FxGroup.gasp),
          // Scalcia finché ha fiato: le suole sull'asfalto.
          const SceneCue.fx(0.61, FxGroup.scrape, 0.35),
          const SceneCue.fx(0.82, FxGroup.faint, 0.7),
          const SceneCue.fx(0.77, FxGroup.running, 0.3),
        ],
      DeathAct.pot => [
          const SceneCue.fx(0.47, FxGroup.fallwhist, 0.4),
          const SceneCue.fx(_s, FxGroup.ceramic, 0.8),
          const SceneCue.sample(_s + 0.003, 'plate', 0.5),
          reaction(_s + 0.04, FxGroup.ouch),
          const SceneCue.fx(_s + 0.20, FxGroup.faint, 0.7),
        ],
      DeathAct.manhole => [
          // Il chiusino che scivola via, e poi torna al suo posto.
          const SceneCue.fx(0.50, FxGroup.scrape, 0.5),
          const SceneCue.fx(_s, FxGroup.fallwhist, 0.6),
          reaction(_s + 0.01, FxGroup.scream),
          const SceneCue.fx(_s + 0.075, FxGroup.splash, 0.7),
          const SceneCue.fx(_s + 0.13, FxGroup.scrape, 0.4),
          const SceneCue.sample(_s + 0.19, 'metal_heavy', 0.6),
          const SceneCue.fx(0.78, FxGroup.bubbles, 0.35),
        ],
      DeathAct.blackout => [
          // Il lampione che sfrigola e muore, la lama nel buio, la luce che torna.
          const SceneCue.fx(0.44, FxGroup.spark, 0.5),
          const SceneCue.fx(0.475, FxGroup.spark, 0.45),
          const SceneCue.sample(0.50, 'latch', 0.6),
          const SceneCue.fx(_s, FxGroup.stab, 0.85),
          reaction(_s + 0.02, FxGroup.scream),
          const SceneCue.fx(_s + 0.07, FxGroup.faint, 0.7),
          const SceneCue.fx(0.655, FxGroup.spark, 0.45),
        ],
      DeathAct.kiss => [
          if (memes) const SceneCue.meme(0.47, Meme.rizz),
          const SceneCue.fx(_s, FxGroup.kiss, 0.8),
          const SceneCue.fx(0.60, FxGroup.gulp, 0.45),
          reaction(0.62, FxGroup.groan),
          const SceneCue.fx(0.77, FxGroup.faint, 0.6),
        ],
      DeathAct.sniper => [
          // L'otturatore lontano mentre il mirino cerca, poi il colpo con la
          // sua eco, e la pallottola che arriva un attimo dopo.
          const SceneCue.fx(0.44, FxGroup.bolt, 0.3),
          const SceneCue.fx(_s, FxGroup.sniper, 0.8),
          const SceneCue.fx(_s + 0.004, FxGroup.impact, 0.5),
          reaction(_s + 0.02, FxGroup.ouch),
          const SceneCue.fx(_s + 0.11, FxGroup.faint, 0.7),
          const SceneCue.fx(0.70, FxGroup.bolt, 0.25),
        ],
      DeathAct.rescue => [
          const SceneCue.fx(0.505, FxGroup.cock, 0.5),
          const SceneCue.fx(_s, FxGroup.revolver, 0.75),
          const SceneCue.fx(_s + 0.07, FxGroup.faint, 0.6),
          const SceneCue.fx(0.61, FxGroup.running, 0.3),
          for (var step = 0; step < 7; step++) SceneCue.sample(0.62 + step * 0.0125, 'step_${step % 4 + 1}', 0.5),
          if (memes) const SceneCue.meme(0.715, Meme.applePay) else const SceneCue.sample(0.715, 'bag', 0.7),
          // La cura: il cerotto strappato, la siringa, la garza.
          const SceneCue.fx(0.73, FxGroup.bandage, 0.5),
          const SceneCue.fx(0.748, FxGroup.syringe, 0.45),
          const SceneCue.fx(0.765, FxGroup.heartbeat, 0.7),
          const SceneCue.fx(0.79, FxGroup.bandage, 0.45),
          const SceneCue.fx(0.845, FxGroup.gasp, 0.6),
        ],
      DeathAct.lucky => [
          const SceneCue.fx(0.505, FxGroup.cock, 0.5),
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
