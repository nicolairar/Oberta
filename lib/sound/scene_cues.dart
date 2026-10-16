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

  const SceneCue._(this.t, this.fx, this.sample, this.meme, this.gain);

  /// Lo stesso suono, spostato a [t].
  SceneCue at(double t) => SceneCue._(t, fx, sample, meme, gain);
}

const _s = DeathScenePainter.strike;

/// I passi della vittima che arriva sotto il lampione: uno per ogni volta
/// che un piede tocca terra nell'animazione.
List<SceneCue> _entrance() => [
      for (var step = 0; step < 9; step++)
        SceneCue.sample(0.04 + 0.30 * (step + 0.5) / 9, 'step_${step % 4 + 1}', 0.35),
    ];

/// Il colpo dall'angolo, e il Dottore che arriva di corsa: l'attacco comune
/// delle varianti del salvataggio.
List<SceneCue> _doctorRuns() => [
      const SceneCue.fx(0.505, FxGroup.cock, 0.5),
      const SceneCue.fx(_s, FxGroup.revolver, 0.75),
      const SceneCue.fx(_s + 0.07, FxGroup.faint, 0.6),
      const SceneCue.fx(0.605, FxGroup.running, 0.3),
      for (var step = 0; step < 6; step++) SceneCue.sample(0.60 + step * 0.011, 'step_${step % 4 + 1}', 0.5),
    ];

/// Tutti i suoni di una scena, in ordine di tempo. [memes] mette, dove ha
/// senso, un meme al posto della reazione. Con [save] la scena è un agguato
/// che va a vuoto: i suoni dell'agguato finché va come deve, poi quelli di
/// chi lo manda a vuoto.
List<SceneCue> sceneCuesFor(DeathAct act, {DeathAct? save, bool memes = false}) {
  if (save == null) return _cuesOf(act, memes: memes);
  final splice = spliceOf(act, save);
  final attack = _cuesOf(act, memes: memes);
  final rescue = _cuesOf(save, memes: memes);
  bool entrance(SceneCue cue) => cue.t < 0.34 && (cue.sample?.startsWith('step_') ?? false);
  final cues = switch (splice) {
    // L'agguato fino a quando la vittima è a terra (al passo del filmato
    // composto), più il killer che scappa; poi il Dottore, senza lo sparo
    // con cui nei suoi filmati comincia tutto.
    Splice.doctor => [
        for (final cue in attack)
          if (cue.t <= _downOf(act) || cue.fx == FxGroup.running) cue.at(spliceTime(act, save, cue.t)),
        for (final cue in rescue)
          if (!entrance(cue) && !_ambush(cue))
            // Sopra un agguato l'ambulanza arriva più tardi, e inchioda lì.
            save == DeathAct.ambulance && cue.fx == FxGroup.screech ? cue.at(0.65) : cue,
      ],
    // L'agguato fino al colpo; poi il colpo che si ferma nel taschino.
    Splice.stopped => [
        for (final cue in attack)
          if (cue.t <= _s + 0.005 || cue.fx == FxGroup.running || cue.fx == FxGroup.trombone) cue,
        for (final cue in rescue)
          if (cue.t > _s + 0.001) cue,
      ],
    // L'agguato fino a quando l'arma dovrebbe sparare; poi i clic, il
    // dubbio, la risata. Il killer se ne va coi passi suoi.
    Splice.jammed => [
        for (final cue in attack)
          if (cue.t < _s - 0.02 || cue.fx == FxGroup.running || cue.fx == FxGroup.trombone) cue,
        for (final cue in rescue)
          if (cue.t >= _s && cue.fx != FxGroup.running && cue.sample != 'metal_medium') cue,
      ],
    // Il colpo a vuoto com'è, con l'arma dell'agguato al posto della pistola.
    Splice.armed => [for (final cue in rescue) ..._armed(cue, act)],
    Splice.alone || null => rescue,
  };
  return cues..sort((a, b) => a.t.compareTo(b.t));
}

/// Quando la vittima di [act] è a terra, nel tempo del suo filmato: i suoni
/// dell'agguato fin lì (il tonfo compreso) restano.
double _downOf(DeathAct act) => spliceClock(act, DeathAct.rescue, 0.645) + 0.02;

/// I suoni con cui cominciano i filmati del Dottore: il cane armato, lo
/// sparo dal vicolo, il corpo che cade. Sopra un agguato non servono.
bool _ambush(SceneCue cue) =>
    cue.t < 0.645 &&
    (cue.fx == FxGroup.cock || cue.fx == FxGroup.revolver || cue.fx == FxGroup.faint || cue.meme != null);

/// Un suono del colpo a vuoto, rifatto per l'arma con cui arriva il killer.
List<SceneCue> _armed(SceneCue cue, DeathAct weapon) {
  final shot = cue.fx == FxGroup.revolver;
  final cocked = cue.fx == FxGroup.cock;
  return switch (weapon) {
    DeathAct.lupara when shot => [SceneCue.fx(cue.t, FxGroup.shotgun, cue.gain)],
    DeathAct.burst when shot => [SceneCue.fx(cue.t, FxGroup.tommy, cue.gain)],
    DeathAct.burst when cocked => [SceneCue.fx(cue.t, FxGroup.bolt, cue.gain)],
    // Il pugnale e la mazza non sparano: fischiano in aria, e cadono.
    DeathAct.knife when shot => [
        SceneCue.fx(cue.t, FxGroup.whoosh, 0.6),
        SceneCue.fx(0.605, FxGroup.stab, 0.6),
      ],
    DeathAct.bat when shot => [
        SceneCue.fx(cue.t, FxGroup.swish, 0.6),
        const SceneCue.sample(0.605, 'wood_heavy', 0.6),
        const SceneCue.sample(0.625, 'wood_heavy', 0.35),
      ],
    DeathAct.knife || DeathAct.bat when cocked => [],
    _ => [cue],
  };
}

/// Tutti i suoni del filmato di [act], da solo.
List<SceneCue> _cuesOf(DeathAct act, {required bool memes}) {
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
          // L'ultimo colpo si porta via il lampione, e l'auto riparte
          // sgommando.
          const SceneCue.fx(0.63, FxGroup.bulb, 0.6),
          const SceneCue.fx(0.635, FxGroup.screech, 0.45),
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
          // Il chiusino che si solleva di un dito, per guardare.
          const SceneCue.sample(0.79, 'metal_light', 0.35),
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
      DeathAct.bowling => [
          // La palla che tocca l'asfalto e rotola, i birilli (le caviglie),
          // il volo, e qualcuno che esulta.
          const SceneCue.fx(0.518, FxGroup.thud, 0.45),
          const SceneCue.fx(0.521, FxGroup.scrape, 0.4),
          const SceneCue.sample(_s, 'wood_heavy', 0.85),
          const SceneCue.fx(_s + 0.003, FxGroup.punch, 0.5),
          reaction(_s + 0.02, FxGroup.scream),
          const SceneCue.fx(0.61, FxGroup.cheer, 0.35),
          const SceneCue.fx(0.66, FxGroup.faint, 0.7),
          const SceneCue.fx(0.75, FxGroup.running, 0.3),
        ],
      DeathAct.swordfish => [
          // Il pesce che sbatte la coda, il fendente, l'affondo bagnato; poi
          // il tonfo del pesce sul corpo.
          const SceneCue.fx(0.41, FxGroup.splash, 0.3),
          const SceneCue.fx(_s - 0.014, FxGroup.swish, 0.55),
          const SceneCue.fx(_s, FxGroup.stab, 0.85),
          const SceneCue.fx(_s + 0.004, FxGroup.splash, 0.45),
          reaction(_s + 0.025, FxGroup.ouch),
          const SceneCue.sample(0.605, 'cloth_2', 0.45),
          const SceneCue.fx(0.715, FxGroup.faint, 0.7),
          const SceneCue.fx(0.72, FxGroup.splash, 0.5),
          const SceneCue.fx(0.77, FxGroup.running, 0.3),
        ],
      DeathAct.harpoon => [
          // L'arpione caricato, il fischio, il colpo; la corda che si tende
          // e il corpo trascinato oltre l'angolo.
          const SceneCue.fx(0.47, FxGroup.cock, 0.45),
          const SceneCue.fx(0.54, FxGroup.whoosh, 0.6),
          const SceneCue.fx(_s, FxGroup.stab, 0.8),
          const SceneCue.fx(_s + 0.003, FxGroup.impact, 0.5),
          reaction(_s + 0.02, FxGroup.gasp),
          const SceneCue.fx(0.60, FxGroup.rope, 0.6),
          const SceneCue.fx(0.635, FxGroup.drag, 0.6),
          const SceneCue.fx(0.65, FxGroup.scrape, 0.4),
          const SceneCue.fx(0.70, FxGroup.thud, 0.55),
        ],
      DeathAct.pie => [
          // Il lancio, lo spiaccico della panna, una risatina; poi la
          // levetta della bomba che salta via, e il botto.
          const SceneCue.fx(0.502, FxGroup.whoosh, 0.45),
          const SceneCue.fx(0.52, FxGroup.splash, 0.55),
          const SceneCue.fx(0.525, FxGroup.chuckle, 0.45),
          const SceneCue.sample(0.538, 'metal_light', 0.6),
          const SceneCue.fx(_s, FxGroup.explosion, 0.8),
          const SceneCue.fx(_s + 0.03, FxGroup.debris, 0.45),
          const SceneCue.fx(0.775, FxGroup.faint, 0.6),
        ],
      DeathAct.trombone => [
          // La marcetta, lo sparo dalla campana, e il trombone triste che
          // accompagna giù la vittima.
          const SceneCue.fx(0.42, FxGroup.slidewhist, 0.3),
          const SceneCue.fx(_s, FxGroup.shotgun, 0.8),
          reaction(_s + 0.03, FxGroup.ouch),
          const SceneCue.fx(0.60, FxGroup.trombone, 0.75),
          const SceneCue.fx(0.765, FxGroup.faint, 0.7),
          const SceneCue.fx(0.78, FxGroup.running, 0.3),
        ],
      DeathAct.tango => [
          // Il sax che invita, i passi, la giravolta, la lama nel casqué.
          const SceneCue.sample(0.44, 'sax_13', 0.5),
          const SceneCue.sample(0.49, 'step_1', 0.5),
          const SceneCue.sample(0.505, 'step_3', 0.5),
          const SceneCue.fx(0.53, FxGroup.swish, 0.45),
          const SceneCue.fx(_s, FxGroup.stab, 0.8),
          reaction(_s + 0.02, FxGroup.gasp),
          const SceneCue.fx(0.64, FxGroup.faint, 0.65),
          const SceneCue.sample(0.71, 'cloth_1', 0.3),
        ],
      DeathAct.bouquet => [
          // La carta del mazzo, il carrello armato tra le rose, la raffica.
          const SceneCue.sample(0.48, 'cloth_1', 0.45),
          const SceneCue.fx(0.535, FxGroup.bolt, 0.5),
          const SceneCue.fx(0.555, FxGroup.tommy, 0.75),
          const SceneCue.fx(0.58, FxGroup.casing, 0.35),
          reaction(0.60, FxGroup.scream),
          const SceneCue.fx(0.715, FxGroup.faint, 0.7),
          const SceneCue.fx(0.76, FxGroup.running, 0.3),
        ],
      DeathAct.laundry => [
          // Il furgone in retromarcia, la portiera, la presa; la portiera
          // sbattuta, il furgone che sobbalza e poi riparte.
          const SceneCue.fx(0.42, FxGroup.engine, 0.5),
          const SceneCue.fx(0.49, FxGroup.screech, 0.3),
          const SceneCue.sample(0.505, 'latch', 0.6),
          const SceneCue.fx(_s, FxGroup.punch, 0.7),
          reaction(_s + 0.01, FxGroup.gasp),
          const SceneCue.fx(_s + 0.012, FxGroup.drag, 0.5),
          const SceneCue.fx(0.606, FxGroup.door, 0.7),
          const SceneCue.sample(0.61, 'metal_medium', 0.45),
          const SceneCue.fx(0.635, FxGroup.thud, 0.45),
          const SceneCue.fx(0.665, FxGroup.thud, 0.35),
          const SceneCue.fx(0.70, FxGroup.engine, 0.55),
          const SceneCue.fx(0.705, FxGroup.screech, 0.4),
          const SceneCue.fx(0.75, FxGroup.bubbles, 0.35),
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
          // Il sussulto con cui torna in sé e si tira su.
          const SceneCue.fx(0.80, FxGroup.gasp, 0.6),
        ],
      DeathAct.lucky => [
          const SceneCue.fx(0.505, FxGroup.cock, 0.5),
          const SceneCue.fx(_s, FxGroup.revolver, 0.75),
          const SceneCue.sample(_s + 0.003, 'metal_light', 0.8),
          const SceneCue.fx(_s + 0.01, FxGroup.ricochet, 0.6),
          const SceneCue.fx(_s + 0.04, FxGroup.gasp, 0.6),
          for (var step = 0; step < 6; step++) SceneCue.sample(0.675 + step * 0.012, 'step_${step % 4 + 1}', 0.45),
          // Un sorso dalla fiaschetta che gli ha salvato la pelle.
          const SceneCue.fx(0.79, FxGroup.gulp, 0.45),
        ],
      DeathAct.belfry => [
          // Un primo rintocco mentre il riflesso brilla lassù; il colpo parte
          // insieme al secondo, che lo copre. Poi i piccioni che scappano.
          const SceneCue.fx(0.40, FxGroup.church, 0.35),
          const SceneCue.fx(0.46, FxGroup.bolt, 0.25),
          const SceneCue.fx(_s, FxGroup.church, 0.75),
          const SceneCue.fx(_s, FxGroup.sniper, 0.55),
          const SceneCue.fx(_s + 0.004, FxGroup.impact, 0.5),
          const SceneCue.fx(_s + 0.01, FxGroup.whoosh, 0.35),
          reaction(_s + 0.02, FxGroup.ouch),
          const SceneCue.fx(_s + 0.11, FxGroup.faint, 0.7),
          const SceneCue.fx(0.64, FxGroup.church, 0.4),
        ],
      DeathAct.phoneBooth => [
          // Il telefono della cabina che squilla, la cornetta alzata, poi il
          // vetro che si crepa sotto il colpo e la cornetta che sbatte.
          const SceneCue.fx(0.25, FxGroup.phone, 0.5),
          const SceneCue.sample(0.375, 'click', 0.6),
          const SceneCue.fx(_s, FxGroup.sniper, 0.75),
          const SceneCue.fx(_s + 0.002, FxGroup.glassbreak, 0.7),
          const SceneCue.sample(_s + 0.006, 'glass_medium', 0.5),
          reaction(_s + 0.02, FxGroup.ouch),
          const SceneCue.sample(_s + 0.05, 'metal_light', 0.45),
          const SceneCue.fx(_s + 0.10, FxGroup.faint, 0.7),
          const SceneCue.sample(0.70, 'metal_light', 0.3),
        ],
      DeathAct.carDoor => [
          // Le chiavi, la serratura, la portiera che si apre; il colpo da
          // lontano e le chiavi che tintinnano sull'asfalto.
          const SceneCue.sample(0.37, 'chips_handle', 0.4),
          const SceneCue.sample(0.42, 'latch', 0.6),
          const SceneCue.fx(0.44, FxGroup.door, 0.45),
          const SceneCue.fx(_s, FxGroup.sniper, 0.8),
          const SceneCue.fx(_s + 0.004, FxGroup.impact, 0.5),
          reaction(_s + 0.02, FxGroup.ouch),
          const SceneCue.sample(_s + 0.06, 'metal_light', 0.45),
          const SceneCue.fx(_s + 0.11, FxGroup.faint, 0.7),
        ],
      DeathAct.defibrillator => [
          ..._doctorRuns(),
          const SceneCue.sample(0.665, 'metal_medium', 0.55),
          // Le piastre sfregate che si caricano, le due scosse, il cuore.
          const SceneCue.fx(0.69, FxGroup.spark, 0.45),
          const SceneCue.fx(0.735, FxGroup.spark, 0.8),
          const SceneCue.sample(0.736, 'body_fall', 0.35),
          const SceneCue.fx(0.77, FxGroup.spark, 0.9),
          const SceneCue.sample(0.771, 'body_fall_2', 0.4),
          const SceneCue.fx(0.78, FxGroup.heartbeat, 0.75),
          const SceneCue.fx(0.80, FxGroup.gasp, 0.6),
        ],
      DeathAct.pliers => [
          ..._doctorRuns(),
          if (memes) const SceneCue.meme(0.665, Meme.applePay) else const SceneCue.sample(0.665, 'bag', 0.7),
          // Le pinze che frugano, lo strappo, il piombo nella bacinella.
          const SceneCue.sample(0.70, 'metal_light', 0.35),
          const SceneCue.fx(0.74, FxGroup.groan, 0.5),
          const SceneCue.sample(0.786, 'tin', 0.75),
          const SceneCue.fx(0.79, FxGroup.bandage, 0.5),
          const SceneCue.fx(0.80, FxGroup.gasp, 0.6),
        ],
      DeathAct.ambulance => [
          const SceneCue.fx(0.505, FxGroup.cock, 0.5),
          const SceneCue.fx(_s, FxGroup.revolver, 0.75),
          const SceneCue.fx(_s + 0.07, FxGroup.faint, 0.6),
          const SceneCue.fx(0.61, FxGroup.running, 0.3),
          // La sirena da lontano, la frenata, i portelloni, la barella.
          const SceneCue.fx(0.565, FxGroup.siren, 0.6),
          const SceneCue.fx(0.63, FxGroup.screech, 0.4),
          const SceneCue.fx(0.665, FxGroup.door, 0.45),
          const SceneCue.sample(0.715, 'metal_medium', 0.45),
          const SceneCue.sample(0.735, 'cloth_1', 0.45),
          const SceneCue.sample(0.765, 'metal_medium', 0.4),
          const SceneCue.fx(0.78, FxGroup.gasp, 0.5),
        ],
      DeathAct.stitches => [
          ..._doctorRuns(),
          if (memes) const SceneCue.meme(0.665, Meme.applePay) else const SceneCue.sample(0.665, 'bag', 0.7),
          // Ogni punto: l'ago che entra e il filo che tira. Poi le forbici.
          for (final at in const [0.695, 0.722, 0.749]) ...[
            SceneCue.sample(at + 0.005, 'cloth_2', 0.4),
            SceneCue.fx(at + 0.012, FxGroup.swish, 0.3),
          ],
          const SceneCue.sample(0.785, 'knife_2', 0.45),
          const SceneCue.fx(0.80, FxGroup.gasp, 0.6),
        ],
      DeathAct.bible => [
          const SceneCue.fx(0.505, FxGroup.cock, 0.5),
          const SceneCue.fx(_s, FxGroup.revolver, 0.75),
          // Il piombo che si pianta nella carta, non sul metallo.
          const SceneCue.sample(_s + 0.003, 'punch', 0.6),
          const SceneCue.fx(_s + 0.04, FxGroup.gasp, 0.6),
          for (var step = 0; step < 6; step++) SceneCue.sample(0.675 + step * 0.012, 'step_${step % 4 + 1}', 0.45),
          const SceneCue.sample(0.70, 'flip', 0.5),
          const SceneCue.sample(0.75, 'bell', 0.4),
        ],
      DeathAct.jam => [
          const SceneCue.fx(0.505, FxGroup.cock, 0.55),
          // Tre volte il grilletto, tre volte niente.
          const SceneCue.sample(_s, 'click', 0.9),
          const SceneCue.sample(0.585, 'click', 0.9),
          const SceneCue.sample(0.615, 'metal_light', 0.45),
          const SceneCue.sample(0.635, 'click', 0.7),
          const SceneCue.fx(0.65, FxGroup.gasp, 0.5),
          const SceneCue.sample(0.66, 'metal_medium', 0.5),
          const SceneCue.fx(0.665, FxGroup.running, 0.45),
          const SceneCue.fx(0.73, FxGroup.chuckle, 0.5),
        ],
      DeathAct.banana => [
          for (var step = 0; step < 5; step++) SceneCue.sample(0.47 + step * 0.012, 'step_${step % 4 + 1}', 0.5),
          // La scivolata, il colpo che parte verso il cielo, la schiena giù.
          const SceneCue.fx(0.525, FxGroup.slidewhist, 0.6),
          const SceneCue.fx(_s, FxGroup.revolver, 0.7),
          const SceneCue.fx(0.578, FxGroup.thud, 0.75),
          const SceneCue.fx(0.582, FxGroup.ouch, 0.6),
          const SceneCue.fx(0.60, FxGroup.boing, 0.4),
          const SceneCue.fx(0.70, FxGroup.running, 0.4),
          const SceneCue.fx(0.72, FxGroup.laugh, 0.4),
        ],
      DeathAct.blackCat => [
          const SceneCue.fx(0.505, FxGroup.cock, 0.5),
          // Il gatto che soffia, salta, graffia; il colpo storto, la pistola
          // che cade sull'asfalto.
          const SceneCue.fx(0.50, FxGroup.cat, 0.5),
          const SceneCue.sample(0.535, 'metal_light', 0.5),
          const SceneCue.fx(0.545, FxGroup.cat, 0.8),
          const SceneCue.fx(_s, FxGroup.revolver, 0.7),
          const SceneCue.fx(_s + 0.01, FxGroup.ricochet, 0.4),
          const SceneCue.fx(0.58, FxGroup.scream, 0.45),
          const SceneCue.sample(0.63, 'metal_medium', 0.55),
          const SceneCue.fx(0.65, FxGroup.running, 0.4),
          const SceneCue.fx(0.76, FxGroup.cat, 0.35),
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
