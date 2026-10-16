part of 'death_scene.dart';

// I filmati composti: un agguato della famiglia che stavolta va a vuoto.
// L'agguato si gira com'è, con la sua coreografia; sopra, un secondo pittore
// mette in scena chi lo manda a vuoto: il Dottore che arriva dove la vittima
// è caduta, o la fortuna che ferma il colpo. I due si parlano con un
// [_Handover]: l'agguato dice dove sta la vittima e il killer, l'altro li
// prende da lì.

/// Quale parte di un filmato composto disegna un pittore.
enum _Cut {
  /// Il filmato intero, da solo.
  whole,

  /// L'agguato della famiglia: senza sangue a terra, senza killer che saluta,
  /// e la vittima la lascia all'altro pittore.
  attack,

  /// Chi manda a vuoto l'agguato, sopra l'agguato.
  rescue,
}

/// Come si monta un agguato che va a vuoto.
enum Splice {
  /// L'agguato intero fino alla caduta; poi il Dottore arriva dove la vittima
  /// è a terra, e la rimette in piedi.
  doctor,

  /// L'agguato intero, ma il colpo si ferma su qualcosa nel taschino.
  stopped,

  /// L'agguato intero, ma l'arma fa clic.
  jammed,

  /// Il filmato del colpo a vuoto, col killer armato come nell'agguato.
  armed,

  /// Il filmato del colpo a vuoto così com'è: l'agguato era già il suo.
  alone,
}

/// Quello che l'agguato fa sapere, fotogramma per fotogramma, a chi lo
/// manda a vuoto.
class _Handover {
  final Splice splice;

  /// Dove ha i piedi la vittima, se è già a terra.
  double? downAt;

  /// Dove sta la vittima in piedi, e verso dove guarda, da quando l'agguato
  /// la lascia all'altro pittore.
  double? standAt;
  int facing = -1;

  /// Dove ha i piedi il killer.
  Offset? killer;

  _Handover(this.splice);
}

/// Dove e quando l'agguato lascia la vittima a terra: i piedi rispetto a
/// dove si era fermata (in altezze di figura), verso dove ha la testa, e il
/// momento del film in cui è stesa del tutto. Le scene che non la lasciano
/// stesa sulla strada (appesa, schiacciata, portata via) non ci sono: lì il
/// Dottore non ha dove inginocchiarsi.
const Map<DeathAct, (double, int, double)> _downs = {
  DeathAct.knife: (0.0, -1, 0.695),
  DeathAct.gun: (-0.07, -1, 0.695),
  DeathAct.burst: (-0.07, -1, 0.78),
  DeathAct.car: (0.94, -1, 0.675),
  DeathAct.blast: (0.0, -1, 0.775),
  DeathAct.poison: (-0.10, -1, 0.72),
  DeathAct.bat: (0.0, -1, 0.75),
  DeathAct.lupara: (-0.25, -1, 0.705),
  DeathAct.driveBy: (-0.08, 1, 0.71),
  DeathAct.garrote: (0.0, -1, 0.82),
  DeathAct.pot: (0.0, -1, 0.76),
  DeathAct.blackout: (0.0, -1, 0.635),
  DeathAct.kiss: (0.0, -1, 0.77),
  DeathAct.bowling: (-0.05, -1, 0.66),
  DeathAct.swordfish: (0.0, -1, 0.72),
  DeathAct.pie: (0.0, -1, 0.775),
  DeathAct.trombone: (0.0, -1, 0.77),
  DeathAct.tango: (0.12, -1, 0.64),
  DeathAct.bouquet: (0.0, -1, 0.72),
};

/// Le armi che fanno clic, e quelle con cui il colpo può fermarsi nel
/// taschino: le scene in cui l'agguato è un colpo solo, dritto al petto.
const _jams = {DeathAct.burst, DeathAct.lupara, DeathAct.trombone};
const _stops = {DeathAct.knife, DeathAct.lupara, DeathAct.trombone};

/// Chi scivola sulla buccia di banana con la sua arma in mano, e chi si
/// prende il gatto nero sul braccio.
const _slips = {DeathAct.knife, DeathAct.bat};
const _scratches = {DeathAct.lupara, DeathAct.burst};

/// Quando l'agguato che va a vuoto per fortuna lascia la vittima all'altro
/// pittore: un attimo prima del colpo, quando chi era nel mirino sussulta.
const _luckHands = DeathScenePainter.strike - 0.012;

/// Il momento, nel filmato composto, in cui l'agguato deve aver messo a terra
/// la vittima: il Dottore è già per strada.
const _handoff = 0.645;

/// Come si monta il filmato in cui [save] manda a vuoto l'agguato di
/// [attack], o `null` se le due cose insieme non hanno senso.
Splice? spliceOf(DeathAct attack, DeathAct save) {
  if (attack.survives) return null;
  if (save.doctorSaves) return _downs.containsKey(attack) ? Splice.doctor : null;
  if (!save.luckyEscape) return null;
  if (attack == DeathAct.gun) return Splice.alone;
  return switch (save) {
    DeathAct.lucky || DeathAct.bible when _stops.contains(attack) => Splice.stopped,
    DeathAct.jam when _jams.contains(attack) => Splice.jammed,
    DeathAct.banana when _slips.contains(attack) => Splice.armed,
    DeathAct.blackCat when _scratches.contains(attack) => Splice.armed,
    _ => null,
  };
}

/// Vero se un filmato sa mettere in scena [save] che manda a vuoto l'agguato
/// di [attack].
bool canSpare(DeathAct attack, DeathAct save) => spliceOf(attack, save) != null;

/// A che punto è l'agguato [attack] quando il filmato composto con [save] è
/// a [t]. Quando arriva il Dottore, la caduta delle scene lente si accelera:
/// la vittima dev'essere a terra quando lui arriva. Poi l'agguato riprende
/// il suo passo.
double spliceClock(DeathAct attack, DeathAct save, double t) {
  const strike = DeathScenePainter.strike;
  final down = _downs[attack]?.$3;
  if (spliceOf(attack, save) != Splice.doctor || down == null) return t;
  if (down <= _handoff || t <= strike) return t;
  final pace = (down - strike) / (_handoff - strike);
  if (t <= _handoff) return strike + (t - strike) * pace;
  return down + (t - _handoff);
}

/// L'inverso di [spliceClock]: quando, nel filmato composto, l'agguato
/// arriva al suo momento [attackT].
double spliceTime(DeathAct attack, DeathAct save, double attackT) {
  const strike = DeathScenePainter.strike;
  final down = _downs[attack]?.$3;
  if (spliceOf(attack, save) != Splice.doctor || down == null) return attackT;
  if (down <= _handoff || attackT <= strike) return attackT;
  final pace = (down - strike) / (_handoff - strike);
  if (attackT <= down) return strike + (attackT - strike) / pace;
  return _handoff + (attackT - down);
}

/// Per i test: dove e quando la vittima di [attack] finisce a terra, girato
/// col Dottore. I piedi sono misurati da dove si era fermata, in altezze di
/// figura; `null` se a [t] non è ancora stesa.
@visibleForTesting
double? debugDownAt(DeathAct attack, double t, {Size size = const Size(390, 844)}) {
  final handover = _Handover(Splice.doctor);
  final painter = DeathScenePainter._part(_Cut.attack, t: t, act: attack, save: DeathAct.rescue, handover: handover)
    .._frame(size);
  final recorder = ui.PictureRecorder();
  painter._stage(Canvas(recorder));
  recorder.endRecording().dispose();
  final down = handover.downAt;
  return down == null ? null : (down - painter._victimX) / painter._u;
}

/// Per i test: dove il Dottore va a cercare la vittima di [attack], nella
/// stessa misura di [debugDownAt], e quando la aspetta stesa.
@visibleForTesting
({double at, double down})? debugLieOf(DeathAct attack) {
  final lie = _downs[attack];
  return lie == null ? null : (at: lie.$1, down: lie.$3);
}

extension _SplicedFilms on DeathScenePainter {
  // ---------------------------------------------------------- le due metà

  /// L'agguato va a vuoto: niente sangue sull'asfalto, niente killer che si
  /// affaccia a salutare.
  bool get _spared => _cut == _Cut.attack;

  /// L'agguato va a vuoto per fortuna: il colpo non arriva, o si ferma.
  bool get _missed => _spared && _handover!.splice != Splice.doctor;

  /// L'arma fa clic: niente lampi, niente scie, niente fumo.
  bool get _holdsFire => _spared && _handover!.splice == Splice.jammed;

  /// Il Dottore, sopra l'agguato.
  bool get _doctorLayer => _cut == _Cut.rescue && act.doctorSaves;

  /// La vittima, che il pittore della fortuna disegna solo da quando
  /// l'agguato gliela lascia.
  bool get _victimOffstage => _cut == _Cut.rescue && act.luckyEscape && t < _luckHands;

  /// Se l'agguato deve lasciare la vittima all'altro pittore: lo dice, con
  /// dove sta e verso dove guarda, e non la disegna.
  bool _yields(double x, int facing) {
    if (!_missed || t < _luckHands) return false;
    _handover!
      ..standAt = x
      ..facing = facing;
    return true;
  }

  /// Verso dove guarda la vittima nelle scene della fortuna: da sola, o come
  /// la lascia l'agguato.
  int _luckyFacing(int alone) => _cut == _Cut.rescue ? _handover!.facing : alone;

  // ------------------------------------------------------------ il montaggio

  void _paintSpliced(Canvas canvas, Size size) {
    final save = this.save!;
    final splice = spliceOf(act, save);
    if (splice == null || splice == Splice.alone || splice == Splice.armed) {
      // Un filmato solo: il colpo a vuoto, al più con l'arma dell'agguato.
      DeathScenePainter._part(
        _Cut.whole,
        t: t,
        act: save,
        armedWith: splice == Splice.armed ? act : null,
        victimHat: victimHat,
        sprites: sprites,
      ).paint(canvas, size);
      return;
    }

    final handover = _Handover(splice);
    final attack = DeathScenePainter._part(
      _Cut.attack,
      t: spliceClock(act, save, t),
      act: act,
      save: save,
      handover: handover,
      victimHat: victimHat,
      sprites: sprites,
    ).._frame(size);
    final rescue = DeathScenePainter._part(
      _Cut.rescue,
      t: t,
      act: save,
      handover: handover,
      victimHat: victimHat,
      sprites: sprites,
    ).._frame(size);
    final down = _downs[act];
    final mirrored = splice == Splice.doctor && down!.$2 > 0;
    rescue._victimX = attack._victimX + (splice == Splice.doctor ? down!.$1 * _u : 0);

    canvas.save();
    // La cinepresa segue l'agguato; quando arriva il Dottore si allarga
    // come nei suoi filmati, per tenere in campo anche lui.
    var lens = attack._lens;
    if (splice == Splice.doctor) {
      var (zoom, focus) = rescue._lens;
      if (mirrored) focus = 2 * rescue._victimX - focus;
      final turn = _smooth(_span(t, 0.57, 0.66));
      lens = (_mix(lens.$1, zoom, turn), _mix(lens.$2, focus, turn));
    }
    _shoot(canvas, lens);
    if (splice != Splice.jammed) attack._quake(canvas);
    attack._street(canvas);
    attack._stage(canvas);
    rescue._victimX = handover.standAt ?? rescue._victimX;
    if (mirrored) {
      // La testa verso destra: il Dottore arriva dall'altra parte.
      canvas.save();
      canvas.translate(2 * rescue._victimX, 0);
      canvas.scale(-1, 1);
    }
    rescue._stage(canvas);
    if (mirrored) canvas.restore();
    attack._sfx(canvas);
    rescue._sfx(canvas);
    canvas.restore();
    _closing(canvas, size, survives: true);
  }
}
