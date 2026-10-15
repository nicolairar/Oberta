import 'dart:math';
import 'dart:typed_data';

import '../ui/widgets/verdict_scene.dart';
import 'synth.dart';

/// La colonna sonora di un verdetto, già a tempo col film: il brusio della
/// folla, la marcia col rullante, la battuta comica e la chiusa sulla carta.
///
/// Niente che somigli ai suoni della carta girata (il trombone triste, il
/// colpo di scena): quelli vengono dopo, e dicono il ruolo. Questa musica è
/// la stessa per tutti.
Uint8List composeVerdict(VerdictTake take) => VerdictScore(take).record();

/// Come [composeVerdict], per chi può passare solo un numero (un altro isolate).
Uint8List composeVerdictByIndex(int index) => composeVerdict(VerdictTake.values[index]);

class VerdictScore {
  /// La coda oltre la fine del film, che accompagna la carta finale.
  static const tail = 2.5;

  final VerdictTake take;
  final Tape tape;

  VerdictScore(this.take) : tape = Tape(secondsOf(take), seed: 211 + take.index);

  /// Quanto dura il nastro di [take].
  static double secondsOf(VerdictTake take) => take.length.inMilliseconds / 1000 + tail;

  /// A che secondo del nastro cade il momento [t] del film.
  double at(double t) => t * take.length.inMilliseconds / 1000;

  Uint8List record() {
    if (take.condemns) {
      _murmur(0, at(0.36), 0.7);
      _march(at(VerdictBeats.marchFrom), at(VerdictBeats.marchTo));
      _vamp(at(VerdictBeats.marchTo), at(VerdictBeats.card));
    } else {
      _murmur(0, at(VerdictBeats.shrug), 1.4);
      _vamp(at(VerdictBeats.shrug + 0.08), at(VerdictBeats.card));
    }
    switch (take) {
      case VerdictTake.molo:
        _pier();
      case VerdictTake.cartello:
        _townLine();
      case VerdictTake.treno:
        _station();
      case VerdictTake.cannone:
        _circus();
      case VerdictTake.assoluzione:
        _square();
    }
    tape.room();
    return tape.toWav();
  }

  // ------------------------------------------------------------- canovaccio

  /// La folla che borbotta: tante voci basse che salgono e scendono, e un
  /// fruscio di passi e vestiti sotto.
  void _murmur(double from, double to, double strength) {
    final rng = Random(31 + take.index);
    tape.noise(from, to - from, gain: 0.05 * strength, lowpass: 900, highpass: 150, envelope: Env.hold(0.15));
    for (var voice = 0; voice < 7; voice++) {
      var when = from + rng.nextDouble() * 0.3;
      final pitch = 105.0 + rng.nextDouble() * 120;
      while (when < to - 0.3) {
        final length = 0.12 + rng.nextDouble() * 0.28;
        final rise = 0.85 + rng.nextDouble() * 0.35;
        tape.tone(when, length, pitch * rise, to: pitch * (0.8 + rng.nextDouble() * 0.3), gain: 0.045 * strength, partials: Tape.saw(5), envelope: Env.swell());
        when += length + 0.04 + rng.nextDouble() * 0.25;
      }
    }
  }

  /// La marcia: rullante, grancassa e una tuba che fa oom-pa.
  void _march(double from, double to) {
    const beat = 0.40;
    var n = 0;
    for (var when = from; when < to - 0.1; when += beat / 2, n++) {
      final downbeat = n % 2 == 0;
      _snare(when, downbeat ? 0.8 : 0.45);
      if (n % 8 == 7) {
        _snare(when + beat / 6, 0.4);
        _snare(when + beat / 3, 0.5);
      }
      if (n % 4 == 0) tape.tone(when, 0.22, 85, to: 45, gain: 0.45, partials: const [(1, 1), (2, 0.3)], envelope: Env.hit(5, 0.02));
      if (downbeat) {
        final low = n % 4 == 0;
        tape.tone(when, 0.22, low ? 73.42 : 110.0, gain: 0.20, partials: Tape.saw(7), envelope: Env.hit(3.5, 0.05));
      }
    }
  }

  /// Sotto la scena, in punta di piedi: un contrabbasso pizzicato da film
  /// comico, e le spazzole sul rullante. Riempie le attese senza coprire
  /// le battute.
  void _vamp(double from, double to) {
    const walk = [73.42, 110.0, 98.0, 110.0, 73.42, 87.31, 98.0, 103.83];
    var n = 0;
    for (var when = from; when < to - 0.1; when += 0.30, n++) {
      tape.pluck(when, walk[n % walk.length], length: 0.4, gain: 0.30, brightness: 0.35);
      tape.noise(when + 0.15, 0.08, gain: 0.05, highpass: 3000, envelope: Env.hit(5, 0.2));
    }
  }

  void _snare(double when, double strength) {
    tape.noise(when, 0.12, gain: 0.35 * strength, highpass: 1800, envelope: Env.hit(6, 0.02));
    tape.tone(when, 0.06, 200, to: 160, gain: 0.25 * strength, envelope: Env.hit(6, 0.02));
  }

  /// La chiusa da vaudeville sulla carta: "ta-ta-ta-ta-ta... ta-ta". Senza
  /// condanna mancano le ultime due note.
  void _tag(double when, {bool unfinished = false}) {
    const notes = [(0.0, 523.25), (0.36, 392.0), (0.54, 392.0), (0.72, 440.0), (1.08, 392.0), (1.80, 493.88), (2.16, 523.25)];
    for (final (offset, freq) in unfinished ? notes.take(5) : notes) {
      tape.pluck(when + offset, freq, length: 0.7, gain: 0.32, brightness: 0.9, damping: 0.997);
      tape.pluck(when + offset, freq / 2, length: 0.5, gain: 0.14, brightness: 0.5);
    }
    if (!unfinished) _snare(when + 2.16, 0.6);
  }

  // ----------------------------------------------------------------- varianti

  void _pier() {
    _thud(at(VerdictBeats.cementLands), weight: 1.6);
    _knock(at(VerdictBeats.cementLands), 180, gain: 0.4);
    // "Ciao ciao": due note da carillon, due volte.
    for (final (i, freq) in const [1318.5, 1046.5, 1318.5, 1046.5].indexed) {
      tape.pluck(at(VerdictBeats.wave + 0.01) + i * 0.16, freq, length: 0.4, gain: 0.25, brightness: 0.95, damping: 0.996);
    }
    _knock(at(VerdictBeats.poke + 0.012), 900, gain: 0.25);
    // Le braccia che mulinano: un fischietto che va su e giù.
    tape.tone(at(VerdictBeats.teeter), at(VerdictBeats.hang) - at(VerdictBeats.teeter), 900, gain: 0.12, envelope: Env.hold(0.1), vibrato: 0.25, vibratoRate: 7);
    _whistle(at(VerdictBeats.drop) - 0.05, at(VerdictBeats.splash) - at(VerdictBeats.drop) + 0.1, 1700, 300);
    _splash(at(VerdictBeats.splash));
    for (var i = 0; i < 7; i++) {
      _blub(at(0.74 + i * 0.012), 0.6);
    }
    _blub(at(VerdictBeats.lastBubble), 1.4);
    _tag(at(VerdictBeats.card));
  }

  void _townLine() {
    _shout(at(VerdictBeats.point));
    // Un'armonica solitaria, mentre se ne va a piedi.
    for (final (i, freq) in const [440.0, 392.0, 349.23, 329.63].indexed) {
      tape.tone(at(VerdictBeats.leave) + i * 0.32, 0.36, freq, gain: 0.10, partials: Tape.square(3), envelope: Env.swell(), vibrato: 0.012, vibratoRate: 5);
    }
    final car = at(VerdictBeats.carIn);
    final gone = at(VerdictBeats.carIn + 0.10);
    tape.tone(car - 0.4, gone - car + 0.4, 70, to: 160, gain: 0.20, partials: Tape.saw(10), envelope: Env.swell());
    tape.noise(car - 0.4, gone - car + 0.6, gain: 0.14, lowpass: 900, envelope: Env.swell());
    for (final when in [car + 0.05, car + 0.25]) {
      tape.tone(when, 0.14, 440, gain: 0.12, partials: Tape.square(4), envelope: Env.hold(0.1));
      tape.tone(when, 0.14, 554.37, gain: 0.10, partials: Tape.square(4), envelope: Env.hold(0.1));
    }
    tape.noise(at(VerdictBeats.carPass) - 0.1, 0.5, gain: 0.3, lowpass: 600, lowpassTo: 4000, highpass: 300, envelope: Env.swell());
    _cough(at(VerdictBeats.cough));
    _cough(at(VerdictBeats.cough) + 0.22);
    tape.noise(at(VerdictBeats.tumbleweed), at(0.86) - at(VerdictBeats.tumbleweed), gain: 0.10, lowpass: 700, highpass: 200, envelope: Env.swell());
    _tag(at(VerdictBeats.card));
  }

  void _station() {
    _knock(at(VerdictBeats.board), 300, gain: 0.3);
    _knock(at(VerdictBeats.doorShuts + 0.01), 600, gain: 0.45);
    // Il fischio: "tu" corto e "tuuu" lungo, un accordo di canne.
    final toot = at(VerdictBeats.whistle);
    for (final freq in const [466.16, 587.33, 698.46]) {
      tape.tone(toot, 0.22, freq, gain: 0.08, partials: Tape.saw(4), envelope: Env.hold(0.15));
      tape.tone(toot + 0.30, 0.95, freq * 0.94, gain: 0.08, partials: Tape.saw(4), envelope: Env.hold(0.1), vibrato: 0.004);
    }
    tape.noise(toot, 0.8, gain: 0.22, highpass: 3500, envelope: Env.hit(3, 0.05));
    // Il treno parte: sbuffi e rotaie, sempre più fitti, poi lontani.
    var when = at(VerdictBeats.depart);
    var gap = 0.45;
    final end = at(0.84);
    while (when < end) {
      final far = 1 - 0.8 * ((when - at(VerdictBeats.depart)) / (end - at(VerdictBeats.depart)));
      tape.noise(when, 0.14, gain: 0.25 * far, lowpass: 2500, highpass: 400, envelope: Env.hit(4, 0.1));
      _knock(when + gap * 0.5, 240, gain: 0.25 * far);
      _knock(when + gap * 0.62, 260, gain: 0.2 * far);
      when += gap;
      gap = max(0.13, gap * 0.9);
    }
    // Il naso soffiato nel fazzoletto: un clacson di gomma.
    tape.tone(at(VerdictBeats.sniff), 0.35, 310, to: 260, gain: 0.18, partials: Tape.saw(6), envelope: Env.swell(), vibrato: 0.03, vibratoRate: 18);
    _tag(at(VerdictBeats.card));
  }

  void _circus() {
    _whistle(at(VerdictBeats.jump), at(VerdictBeats.jump + 0.05) - at(VerdictBeats.jump), 400, 1500);
    _whistle(at(VerdictBeats.slide), at(VerdictBeats.slide + 0.035) - at(VerdictBeats.slide), 1200, 250);
    final fuse = at(VerdictBeats.fuse);
    final boom = at(VerdictBeats.boom);
    tape.noise(fuse, boom - fuse, gain: 0.12, highpass: 4000, envelope: Env.rise(0.6));
    final rng = Random(5);
    for (var when = fuse; when < boom - 0.05; when += 0.04 + rng.nextDouble() * 0.06) {
      tape.noise(when, 0.01, gain: 0.25, highpass: 2500, envelope: Env.hit(3, 0.1));
    }
    tape.noise(boom, 2.0, gain: 1.1, lowpass: 2000, lowpassTo: 160, envelope: Env.hit(3.5, 0.004));
    tape.tone(boom, 0.9, 95, to: 30, gain: 0.9, partials: const [(1, 1), (2, 0.5), (3, 0.3)], envelope: Env.hit(4, 0.005));
    _whistle(boom + 0.05, at(VerdictBeats.ping) - boom - 0.05, 500, 2400, gain: 0.13);
    tape.tone(
      at(VerdictBeats.ping),
      1.6,
      2093,
      gain: 0.14,
      partials: const [(1, 1), (2.76, 0.4), (5.4, 0.2)],
      envelope: Env.hit(3.5, 0.003),
    );
    _whistle(at(VerdictBeats.shoe), at(VerdictBeats.bonk) - at(VerdictBeats.shoe), 1800, 500, gain: 0.12);
    _knock(at(VerdictBeats.bonk), 700, gain: 0.6);
    tape.tone(at(VerdictBeats.bonk) + 0.05, 0.6, 330, gain: 0.12, envelope: Env.hit(3, 0.02), vibrato: 0.06, vibratoRate: 14);
    _tag(at(VerdictBeats.card));
  }

  void _square() {
    // Le parolacce: qualche voce che si alza sopra le altre.
    for (var i = 0; i < 6; i++) {
      final when = at(0.04 + i * 0.065);
      tape.tone(when, 0.25, 230 + i * 25, to: 180, gain: 0.08, partials: Tape.saw(6), envelope: Env.swell());
    }
    // "Boh": un fagotto che scende di due note.
    final shrug = at(VerdictBeats.shrug + 0.01);
    tape.tone(shrug, 0.26, 196, gain: 0.16, partials: Tape.saw(7), envelope: Env.swell());
    tape.tone(shrug + 0.30, 0.45, 146.83, to: 138, gain: 0.16, partials: Tape.saw(7), envelope: Env.swell());
    // Tutti a casa: passi che si allontanano.
    final rng = Random(13);
    for (var i = 0; i < 18; i++) {
      final when = at(VerdictBeats.disperse) + rng.nextDouble() * (at(0.84) - at(VerdictBeats.disperse));
      final far = 1 - (when - at(VerdictBeats.disperse)) / (at(0.84) - at(VerdictBeats.disperse));
      tape.noise(when, 0.05, gain: 0.25 * far, lowpass: 1800, highpass: 300, envelope: Env.hit(6, 0.05));
      tape.tone(when, 0.06, 190, to: 120, gain: 0.22 * far, envelope: Env.hit(6, 0.05));
    }
    tape.noise(at(VerdictBeats.emptySquare), at(0.88) - at(VerdictBeats.emptySquare), gain: 0.10, lowpass: 700, highpass: 200, envelope: Env.swell());
    _tag(at(VerdictBeats.card), unfinished: true);
  }

  // ------------------------------------------------------------------ effetti

  void _thud(double when, {double weight = 1}) {
    tape.tone(when, 0.24, 120, to: 45, gain: 0.55 * weight, partials: const [(1, 1), (2, 0.5), (3, 0.2)], envelope: Env.hit(5, 0.02));
    tape.noise(when, 0.14, gain: 0.3 * weight, lowpass: 500, envelope: Env.hit(5, 0.03));
  }

  void _knock(double when, double freq, {double gain = 0.5}) {
    tape.tone(when, 0.09, freq, gain: gain, partials: const [(1, 1), (2.4, 0.5), (4.1, 0.25)], envelope: Env.hit(6, 0.02));
    tape.noise(when, 0.02, gain: gain * 0.6, lowpass: 5000, envelope: Env.hit(3, 0.1));
  }

  void _whistle(double when, double length, double from, double to, {double gain = 0.16}) {
    tape.tone(when, length, from, to: to, gain: gain, envelope: Env.hold(0.12), vibrato: 0.01, vibratoRate: 9);
  }

  void _splash(double when) {
    tape.noise(when, 1.0, gain: 0.7, lowpass: 4000, lowpassTo: 500, highpass: 200, envelope: Env.hit(4, 0.02));
    tape.tone(when, 0.3, 140, to: 60, gain: 0.4, envelope: Env.hit(5, 0.02));
  }

  void _blub(double when, double size) {
    final base = 380 / size;
    tape.tone(when, 0.08 * size, base, to: base * 2.2, gain: 0.16 * size, envelope: Env.swell());
  }

  void _cough(double when) {
    tape.noise(when, 0.12, gain: 0.3, lowpass: 2200, highpass: 400, envelope: Env.hit(4, 0.1));
    tape.tone(when, 0.10, 220, to: 160, gain: 0.08, partials: Tape.saw(4), envelope: Env.hit(4, 0.1));
  }

  void _shout(double when) {
    for (final freq in const [180.0, 215.0, 250.0, 300.0]) {
      tape.tone(when, 0.35, freq * 1.15, to: freq * 0.85, gain: 0.08, partials: Tape.saw(7), envelope: Env.hit(3, 0.08));
    }
    tape.noise(when, 0.3, gain: 0.15, lowpass: 2500, highpass: 400, envelope: Env.hit(4, 0.05));
  }
}
