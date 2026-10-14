import 'dart:math';
import 'dart:typed_data';

import 'synth.dart';

/// I suoni brevi del resto della partita: quelli che non accompagnano un
/// film ma un gesto, un cambio di scena, un verdetto.
enum Cue {
  /// Uno scatto del tamburo del revolver che gira.
  click,

  /// Il colpo che ferma il tamburo sul narratore sorteggiato.
  bang,

  /// Una carta che scivola sul panno verde.
  deal,

  /// Una carta che si gira.
  flip,

  /// Cala la notte: un accordo basso e un gong lontano.
  nightfall,

  /// L'alba: due rintocchi di campana.
  dawn,

  /// Il ticchettio degli ultimi secondi di discussione.
  tick,

  /// Tempo scaduto: il campanello di una sveglia.
  timeUp,

  /// Il rullo di tamburi prima di girare la carta del condannato.
  drumroll,

  /// La carta girata è della famiglia: colpo di scena.
  caught,

  /// La carta girata è di un innocente: il trombone triste.
  innocent,

  /// Vincono gli onesti: fanfara.
  townWins,

  /// Vince la famiglia: l'organo nella cattedrale vuota.
  familyWins,
}

/// Il nastro di un suono breve, come file WAV.
Uint8List composeCue(Cue cue) => _CueScore(cue).record();

/// Come [composeCue], per chi può passare solo un numero (un altro isolate).
Uint8List composeCueByIndex(int index) => composeCue(Cue.values[index]);

class _CueScore {
  final Cue cue;
  final Tape tape;

  _CueScore(this.cue) : tape = Tape(_length(cue), seed: 101 + cue.index);

  static double _length(Cue cue) => switch (cue) {
        Cue.click => 0.08,
        Cue.bang => 1.4,
        Cue.deal => 0.3,
        Cue.flip => 0.45,
        Cue.nightfall => 3.2,
        Cue.dawn => 4.5,
        Cue.tick => 0.08,
        Cue.timeUp => 1.6,
        Cue.drumroll => 2.0,
        Cue.caught => 2.4,
        Cue.innocent => 3.0,
        Cue.townWins => 3.2,
        Cue.familyWins => 4.0,
      };

  Uint8List record() {
    switch (cue) {
      case Cue.click:
        tape.tone(0, 0.05, 2400, gain: 0.5, partials: const [(1, 1), (1.7, 0.6), (2.9, 0.4)], envelope: Env.hit(9, 0.02));
        tape.noise(0, 0.03, gain: 0.5, highpass: 3000, envelope: Env.hit(6, 0.05));
      case Cue.bang:
        tape.noise(0, 0.9, gain: 1.0, lowpass: 4200, lowpassTo: 300, envelope: Env.hit(6, 0.004));
        tape.noise(0, 0.03, gain: 0.6, highpass: 2500, envelope: Env.hit(4, 0.08));
        tape.tone(0, 0.25, 150, to: 40, gain: 0.9, partials: const [(1, 1), (2, 0.5)], envelope: Env.hit(5, 0.01));
        // Il bossolo che rimbalza sul pavimento.
        for (final (i, at) in const [0.45, 0.62, 0.74].indexed) {
          tape.tone(at, 0.06, 4200 - i * 300.0, gain: 0.18 - i * 0.04, partials: const [(1, 1), (1.5, 0.5)], envelope: Env.hit(7, 0.02));
        }
        tape.room(mix: 0.3);
      case Cue.deal:
        tape.noise(0, 0.22, gain: 0.35, lowpass: 900, lowpassTo: 6000, highpass: 400, envelope: Env.swell());
        tape.noise(0.2, 0.05, gain: 0.25, lowpass: 2500, envelope: Env.hit(6, 0.05));
      case Cue.flip:
        tape.noise(0, 0.28, gain: 0.4, lowpass: 600, lowpassTo: 7000, highpass: 300, envelope: Env.swell());
        tape.noise(0.27, 0.06, gain: 0.5, lowpass: 3500, envelope: Env.hit(6, 0.04));
        tape.tone(0.27, 0.12, 520, to: 380, gain: 0.25, envelope: Env.hit(6, 0.03));
      case Cue.nightfall:
        for (final (i, freq) in const [73.42, 110.0, 146.83, 174.61].indexed) {
          tape.pluck(i * 0.05, freq, length: 3.0, gain: 0.32, brightness: 0.35, damping: 0.999);
        }
        _gong(0.15, 98, 0.22);
        tape.room(mix: 0.35);
      case Cue.dawn:
        _bell(0, 330, 1.0);
        _bell(1.6, 330, 0.75);
        tape.room(mix: 0.35);
      case Cue.tick:
        tape.tone(0, 0.04, 1800, gain: 0.45, partials: const [(1, 1), (2.3, 0.5)], envelope: Env.hit(8, 0.03));
        tape.noise(0, 0.015, gain: 0.3, highpass: 2500, envelope: Env.hit(4, 0.1));
      case Cue.timeUp:
        // Il martelletto della sveglia contro la campana, a raffica.
        for (var i = 0; i < 18; i++) {
          _bell(i * 0.075, i.isEven ? 1320 : 1250, 0.35, length: 0.3);
        }
      case Cue.drumroll:
        final rng = Random(7);
        for (var t = 0.0; t < 1.75; t += 0.032) {
          final swell = 0.25 + 0.75 * pow(t / 1.75, 1.5);
          tape.noise(t, 0.06, gain: 0.32 * swell * (0.85 + 0.3 * rng.nextDouble()), lowpass: 5200, highpass: 900, envelope: Env.hit(6, 0.05));
          tape.tone(t, 0.04, 190, gain: 0.12 * swell, envelope: Env.hit(6, 0.05));
        }
        tape.room(mix: 0.2);
      case Cue.caught:
        // Dun, dun, DUN: tre colpi d'orchestra, l'ultimo che resta.
        for (final (at, chord, length) in const [
          (0.0, [146.83, 174.61, 220.0], 0.35),
          (0.42, [138.59, 164.81, 207.65], 0.35),
          (0.84, [116.54, 146.83, 174.61, 233.08], 1.5),
        ]) {
          for (final freq in chord) {
            tape.tone(at, length, freq, gain: 0.13, partials: Tape.saw(9), envelope: Env.hit(2.5, 0.01), vibrato: 0.004);
          }
          tape.tone(at, 0.4, 70, to: 40, gain: 0.5, envelope: Env.hit(5, 0.01));
          tape.noise(at, 0.3, gain: 0.25, lowpass: 2000, lowpassTo: 300, envelope: Env.hit(6, 0.01));
        }
        tape.room(mix: 0.3);
      case Cue.innocent:
        // Wah, wah, wah, waaah: un trombone che si scusa.
        for (final (at, from, to, length) in const [
          (0.0, 233.08, 228.0, 0.42),
          (0.5, 220.0, 215.0, 0.42),
          (1.0, 207.65, 202.0, 0.42),
          (1.5, 196.0, 185.0, 1.3),
        ]) {
          final last = at > 1.4;
          tape.tone(
            at,
            length,
            from,
            to: to,
            gain: 0.22,
            partials: const [(1, 1), (2, 0.7), (3, 0.45), (4, 0.25), (5, 0.12)],
            envelope: (life) => min(1.0, life * 8) * min(1.0, (1 - life) * 6) * (last ? 0.6 + 0.4 * sin(2 * pi * 6 * life * length) : 1),
            vibrato: last ? 0.025 : 0.006,
            vibratoRate: last ? 6 : 5,
          );
        }
        tape.room(mix: 0.2);
      case Cue.townWins:
        // Una fanfara di ottoni, re maggiore.
        for (final (at, freq, length) in const [
          (0.0, 293.66, 0.18),
          (0.2, 293.66, 0.18),
          (0.4, 293.66, 0.18),
          (0.6, 369.99, 0.5),
          (1.15, 329.63, 0.18),
          (1.35, 369.99, 0.18),
          (1.55, 440.0, 1.4),
        ]) {
          tape.tone(at, length, freq, gain: 0.2, partials: Tape.saw(7), envelope: Env.hit(1.5, 0.04), vibrato: 0.006);
          tape.tone(at, length, freq / 2, gain: 0.1, partials: Tape.saw(5), envelope: Env.hit(1.5, 0.04));
        }
        for (final freq in const [146.83, 185.0, 220.0, 293.66]) {
          tape.tone(1.55, 1.5, freq, gain: 0.08, partials: Tape.saw(5), envelope: Env.hit(1.6, 0.05));
        }
        tape.noise(1.55, 1.2, gain: 0.25, highpass: 5000, envelope: Env.hit(3, 0.01));
        tape.room(mix: 0.3);
      case Cue.familyWins:
        // L'organo: re minore, poi la sesta napoletana, poi di nuovo giù.
        for (final (at, chord) in const [
          (0.0, [73.42, 146.83, 174.61, 220.0, 293.66]),
          (1.3, [77.78, 155.56, 196.0, 233.08, 311.13]),
          (2.4, [73.42, 146.83, 174.61, 220.0, 293.66]),
        ]) {
          for (final freq in chord) {
            tape.tone(at, at > 2 ? 1.6 : 1.25, freq, gain: 0.07, partials: Tape.square(6), envelope: Env.hold(0.12));
          }
        }
        _gong(2.4, 73.42, 0.3);
        tape.room(mix: 0.45);
    }
    return tape.toWav();
  }

  void _bell(double at, double base, double strength, {double length = 3.0}) {
    tape.tone(
      at,
      length,
      base,
      gain: 0.16 * strength,
      partials: const [(0.5, 0.55), (1, 1), (1.2, 0.7), (1.5, 0.4), (2, 0.6), (2.5, 0.25), (3, 0.2), (4, 0.12)],
      envelope: Env.hit(3.6, 0.002),
    );
  }

  void _gong(double at, double base, double gain) {
    tape.tone(
      at,
      2.8,
      base,
      gain: gain,
      partials: const [(1, 1), (1.48, 0.7), (2.12, 0.5), (2.77, 0.35), (3.5, 0.2)],
      envelope: Env.hit(2.2, 0.01),
      vibrato: 0.003,
      vibratoRate: 3,
    );
  }
}
