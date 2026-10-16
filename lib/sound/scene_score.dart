import 'dart:math';
import 'dart:typed_data';

import '../ui/widgets/death_scene.dart';
import 'sample_bank.dart';
import 'synth.dart';

/// La colonna sonora di una scena notturna: musica ed effetti incisi su un
/// unico nastro, già a tempo col film. Chi la suona deve solo farla partire
/// insieme alla scena.
Uint8List composeScene(DeathAct act, [SampleBank bank = const {}]) => SceneScore(act, bank: bank).record();

/// Come [composeScene], per chi può passare solo un numero (un altro isolate).
Uint8List composeSceneByIndex((int, SampleBank) job) => composeScene(DeathAct.values[job.$1], job.$2);

/// Compone il nastro di una scena. I tempi sono quelli del film: ogni
/// rumore è agganciato allo stesso istante in cui il pittore disegna il gesto.
class SceneScore {
  /// Il nastro dura più del film: la coda accompagna il ritratto finale.
  static const seconds = 17.5;
  static const strike = DeathScenePainter.strike;

  static const _d3 = 146.83;
  static const _f3 = 174.61;
  static const _fSharp3 = 185.00;
  static const _a3 = 220.00;

  final DeathAct act;
  final Tape tape;

  /// I suoni registrati da incollare sul nastro; senza, tutto è sintetico.
  final SampleBank bank;
  int _take = 0;

  SceneScore(this.act, {this.bank = const {}}) : tape = Tape(seconds, seed: 11 + act.index);

  /// Incolla il primo campione disponibile tra [names] (a rotazione, così
  /// due passi di fila non sono identici). Restituisce `false` se non ce
  /// n'è nessuno, e chi chiama ripiega sul sintetico.
  bool _recorded(List<String> names, double when, {double gain = 1}) {
    final present = [for (final name in names) if (bank[name] != null) bank[name]!];
    if (present.isEmpty) return false;
    tape.sample(when, present[_take++ % present.length], gain: gain);
    return true;
  }

  /// A che secondo del nastro cade il momento [t] del film.
  static double at(double t) => filmClock(t) * DeathScene.length.inMilliseconds / 1000;

  /// Il momento che la musica sottolinea: di solito il colpo, ma un bacio
  /// avvelenato fa effetto più tardi, e una raffica comincia un attimo prima.
  double get _accent => switch (act) {
        DeathAct.kiss => 0.66,
        DeathAct.burst => 0.55,
        DeathAct.driveBy => 0.535,
        _ => strike,
      };

  bool get _smokes => switch (act) {
        DeathAct.car || DeathAct.piano || DeathAct.safe || DeathAct.chandelier => false,
        DeathAct.blast || DeathAct.poison || DeathAct.noose || DeathAct.grab || DeathAct.kiss => false,
        _ => true,
      };

  Uint8List record() {
    // Con i suoni registrati la musica la fa la colonna sonora vera, che
    // continua sotto la scena: qui restano solo i rumori. Senza (nei test,
    // o se mancano gli asset) si suona tutto in sintetico come prima.
    final synthetic = bank.isEmpty;
    if (synthetic) {
      _entrance();
      _suspense();
      _stinger();
    } else {
      _steps();
    }
    _effects();
    if (synthetic) _aftermath();
    tape.room();
    return tape.toWav();
  }

  /// I passi della vittima che arriva sotto il lampione.
  void _steps() {
    for (var step = 0; step < 9; step++) {
      _footstep(at(0.04 + 0.30 * (step + 0.5) / 9), 0.5);
    }
  }

  // ------------------------------------------------------------------- musica

  /// La vittima arriva: un contrabbasso che cammina con lei, un passo una
  /// nota, e le spazzole sul rullante. Quando si ferma, resta un accordo.
  void _entrance() {
    const walk = [146.83, 174.61, 220.00, 261.63, 233.08, 220.00, 196.00, 174.61, 164.81];
    for (var step = 0; step < walk.length; step++) {
      final when = at(0.04 + 0.30 * (step + 0.5) / walk.length);
      _footstep(when, 0.4);
      tape.pluck(when, walk[step], length: 0.55, gain: 0.27, brightness: 0.35);
      tape.pluck(when, walk[step] / 2, length: 0.55, gain: 0.17, brightness: 0.25);
      tape.noise(when + 0.158, 0.07, gain: step.isOdd ? 0.10 : 0.05, highpass: 3000, envelope: Env.hit(5, 0.2));
    }
    // L'accordo del mistero: re minore con la settima maggiore, arpeggiato.
    final stop = at(0.345);
    for (final (i, freq) in const [146.83, 174.61, 220.00, 277.18].indexed) {
      tape.pluck(stop + i * 0.045, freq, length: 2.2, gain: 0.20, brightness: 0.6, damping: 0.998);
    }
    if (_smokes) _match(at(0.375));
  }

  /// L'attesa: archi che tremano e crescono, una nota che sale, e un cuore
  /// che batte sempre più in fretta. Un attimo prima del colpo, silenzio.
  void _suspense() {
    final from = at(0.36);
    final to = at(_accent) - 0.14;
    final length = to - from;
    for (final (freq, gain) in const [(293.66, 0.13), (311.13, 0.115), (440.0, 0.07), (466.16, 0.06)]) {
      tape.tone(
        from,
        length,
        freq,
        gain: gain,
        partials: Tape.saw(6),
        envelope: (life) =>
            pow(life, 1.6).toDouble() * (0.55 + 0.45 * sin(2 * pi * 10.5 * life * length)) * min(1.0, (1 - life) * 80),
      );
    }
    tape.tone(to - 2.4, 2.4, 180, to: 760, gain: 0.09, envelope: Env.rise(2.4));

    var beat = from + 0.25;
    var gap = 0.95;
    while (beat < to - 0.15) {
      _heartbeat(beat, 0.6 + 0.6 * (beat - from) / length);
      gap = max(0.40, gap * 0.89);
      beat += gap;
    }
  }

  /// Il colpo d'orchestra che cade sul momento che conta.
  void _stinger() {
    final hit = at(_accent);
    final soft = act == DeathAct.kiss || act == DeathAct.manhole ? 0.55 : 1.0;
    tape.noise(hit, 0.5, gain: 0.45 * soft, lowpass: 2500, lowpassTo: 300, envelope: Env.hit(6, 0.008));
    tape.tone(hit, 0.6, 110, to: 42, gain: 0.6 * soft, partials: const [(1, 1), (2, 0.4)], envelope: Env.hit(5, 0.008));
    for (final freq in const [146.83, 207.65, 293.66, 311.13, 440.0]) {
      tape.tone(hit, 1.9, freq, gain: 0.10 * soft, partials: Tape.saw(8), envelope: Env.hit(3.2, 0.004), vibrato: 0.004);
    }
  }

  /// Dopo: un accordo basso che resta lì. Per chi è morto, due rintocchi di
  /// campana sul ritratto; per chi si è salvato, l'accordo si apre in maggiore.
  void _aftermath() {
    final from = at(_accent) + 0.6;
    final card = at(0.86);
    void pad(double start, double length, List<double> chord, double gain) {
      for (final freq in chord) {
        tape.tone(
          start,
          length,
          freq,
          gain: gain,
          partials: Tape.saw(4),
          envelope: (life) => min(1.0, min(life, 1 - life) / 0.2) * (0.85 + 0.15 * sin(2 * pi * 0.9 * life * length)),
        );
        tape.tone(start, length, freq * 2, gain: gain * 0.4, envelope: Env.hold(0.25));
      }
    }

    if (act.survives) {
      final relief = at(act == DeathAct.rescue ? 0.765 : 0.70);
      pad(from, relief - from + 0.3, const [_d3, _f3, _a3], 0.055);
      pad(relief, seconds - relief - 0.3, const [_d3, _fSharp3, _a3], 0.07);
      for (final (i, freq) in const [293.66, 369.99, 440.00, 587.33, 739.99].indexed) {
        tape.pluck(card + i * 0.13, freq, length: 2.4, gain: 0.34, brightness: 0.8, damping: 0.998);
      }
    } else {
      pad(from, seconds - from - 0.3, const [_d3, _f3, _a3], 0.06);
      tape.pluck(from + 0.9, _d3 / 2, length: 2.0, gain: 0.35, brightness: 0.3, damping: 0.998);
      tape.pluck(from + 2.5, 110, length: 2.0, gain: 0.30, brightness: 0.3, damping: 0.998);
      _bell(card, 0.9);
      _bell(card + 2.1, 0.65);
    }
  }

  // ------------------------------------------------------------------ effetti

  void _effects() {
    final hit = at(strike);
    switch (act) {
      case DeathAct.knife:
        _slash(hit);
        _stabs(hit + 0.05, 3);
        _thud(at(strike + 0.13));
      case DeathAct.gun:
        _gunshot(hit);
        _thud(at(strike + 0.13));
      case DeathAct.burst:
        for (final shot in const [0.55, 0.575, 0.60, 0.625, 0.65]) {
          _gunshot(at(shot), size: 0.75, tail: 0.14);
        }
        _thud(at(0.78));
      case DeathAct.car:
        _engine(at(0.44), at(0.64) - at(0.44), 70, 190);
        _screech(at(0.50), hit - at(0.50));
        _thud(hit, weight: 1.6);
        _crash(hit, pieces: 10, low: 400, high: 1800);
        _whistle(hit + 0.15, 0.9, 500, 1400, gain: 0.10);
      case DeathAct.piano:
        _whistle(at(0.50), hit - at(0.50), 1500, 420);
        _thud(hit, weight: 1.8);
        for (var i = 0; i < 14; i++) {
          tape.pluck(hit + i * 0.012, 65.0 * pow(2, (i * 7 % 36) / 12), length: 2.6, gain: 0.30, damping: 0.998);
        }
        tape.pluck(at(0.70), 1046.5, length: 1.5, gain: 0.25, brightness: 0.9, damping: 0.998);
      case DeathAct.safe:
        _whistle(at(0.50), hit - at(0.50), 1300, 380);
        _thud(hit, weight: 2);
        _clang(hit, 170);
      case DeathAct.chandelier:
        _whistle(at(0.50), hit - at(0.50), 1700, 600, gain: 0.10);
        _crash(at(0.46), pieces: 8, low: 2500, high: 6000, spread: hit - at(0.46), gain: 0.10);
        _thud(hit, weight: 1.4);
        _crash(hit, pieces: 46, low: 1800, high: 7000, spread: 0.7);
      case DeathAct.blast:
        tape.noise(at(0.40), hit - at(0.40), gain: 0.07, highpass: 4000, envelope: Env.rise(1.2));
        _boom(hit);
      case DeathAct.poison:
        _cough(at(0.51));
        _cough(at(0.535));
        _crash(hit + 0.1, pieces: 7, low: 2200, high: 5200, spread: 0.2, gain: 0.16);
        _thud(at(strike + 0.16));
      case DeathAct.noose:
        _swoosh(hit - 0.08, 0.2);
        _creak(hit, 1.4);
        _stabs(hit + 0.05, 4);
      case DeathAct.grab:
        _scuffle(hit, 4);
        tape.noise(at(strike + 0.03), at(strike + 0.20) - at(strike + 0.03), gain: 0.10, lowpass: 900, envelope: Env.hold(0.1));
        _thud(at(strike + 0.22), weight: 1.5);
        tape.noise(at(strike + 0.22), 0.7, gain: 0.3, lowpass: 1200, lowpassTo: 250, envelope: Env.hit(4, 0.02));
      case DeathAct.bat:
        _swoosh(hit - 0.14, 0.16);
        _knock(hit, 330);
        _whistle(hit + 0.06, 0.8, 1900, 2100, gain: 0.07);
        _thud(at(strike + 0.19));
      case DeathAct.lupara:
        _gunshot(hit, size: 1.35, tail: 0.7, tone: 2600);
        _gunshot(hit + 0.035, size: 0.8, tail: 0.5, tone: 2000);
        _thud(at(strike + 0.14), weight: 1.3);
      case DeathAct.driveBy:
        _engine(at(0.40), at(0.74) - at(0.40), 120, 88);
        for (final shot in const [0.535, 0.552, 0.569, 0.586, 0.603, 0.620]) {
          _gunshot(at(shot), size: 0.7, tail: 0.12);
        }
        _crash(at(0.63), pieces: 16, low: 2500, high: 6500, spread: 0.3);
        _thud(at(0.71));
      case DeathAct.garrote:
        _scuffle(hit, 2);
        _stabs(hit + 0.05, 5);
        _thud(at(0.82));
      case DeathAct.pot:
        _whistle(at(0.46), hit - at(0.46), 1600, 520);
        _knock(hit, 520);
        _crash(hit, pieces: 20, low: 900, high: 3600, spread: 0.3);
        _whistle(hit + 0.06, 0.8, 1900, 2100, gain: 0.07);
        _thud(at(strike + 0.20));
      case DeathAct.manhole:
        tape.noise(at(0.50), at(0.555) - at(0.50), gain: 0.28, lowpass: 2600, highpass: 700, envelope: Env.hold(0.1));
        _clang(at(0.555), 330, gain: 0.12);
        _whistle(hit, at(strike + 0.075) - hit, 1300, 320);
        _splash(at(strike + 0.075));
        _clang(at(strike + 0.19), 260);
      case DeathAct.blackout:
        _buzz(at(0.44), at(0.50) - at(0.44));
        _knock(at(0.50), 1400, gain: 0.3);
        _slash(hit);
        _thud(at(strike + 0.07));
        _buzz(at(0.655), at(0.70) - at(0.655));
      case DeathAct.kiss:
        for (var step = 0; step < 6; step++) {
          _knock(at(0.38 + step * 0.022), 1500, gain: 0.14);
        }
        _smack(hit);
        tape.pluck(hit + 0.1, 880, length: 1.2, gain: 0.22, brightness: 0.9, damping: 0.998);
        tape.pluck(hit + 0.22, 1108.7, length: 1.2, gain: 0.20, brightness: 0.9, damping: 0.998);
        _heartbeat(at(0.60), 0.9);
        _heartbeat(at(0.625), 0.6);
        _heartbeat(at(0.648), 0.3);
        _thud(at(0.77));
      case DeathAct.bowling:
        _knock(at(0.505), 140, gain: 0.4);
        tape.noise(at(0.51), hit - at(0.51), gain: 0.12, lowpass: 500, envelope: Env.hold(0.1));
        _knock(hit, 260);
        _crash(hit, pieces: 9, low: 500, high: 1600, spread: 0.25, gain: 0.18);
        _thud(at(0.66), weight: 1.3);
      case DeathAct.swordfish:
        _swoosh(hit - 0.12, 0.14);
        _stabs(hit, 2);
        _splash(hit + 0.02);
        _thud(at(0.72));
        _splash(at(0.72));
      case DeathAct.harpoon:
        _swoosh(at(0.54), hit - at(0.54) + 0.05);
        _stabs(hit, 1);
        _creak(at(0.60), 0.4);
        tape.noise(at(0.605), at(0.70) - at(0.605), gain: 0.16, lowpass: 900, envelope: Env.hold(0.1));
        _thud(at(0.70), weight: 1.2);
      case DeathAct.pie:
        _swoosh(at(0.50), 0.18);
        _splash(at(0.52));
        _knock(at(0.538), 2400, gain: 0.2);
        _boom(hit);
        _thud(at(0.775));
      case DeathAct.trombone:
        for (final (i, note) in const [196.0, 220.0, 246.9, 196.0].indexed) {
          tape.tone(at(0.42 + i * 0.02), 0.35, note, gain: 0.12, partials: const [(1.0, 1.0), (2.0, 0.6), (3.0, 0.4)], envelope: Env.hold(0.1));
        }
        _gunshot(hit, size: 1.2, tail: 0.5, tone: 2400);
        for (final (i, note) in const [233.1, 220.0, 207.7, 196.0].indexed) {
          tape.tone(at(0.60 + i * 0.02), i == 3 ? 1.1 : 0.4, note, to: i == 3 ? 185 : note, gain: 0.14, partials: const [(1.0, 1.0), (2.0, 0.6), (3.0, 0.4)], envelope: Env.hold(0.1));
        }
        _thud(at(0.72));
      case DeathAct.tango:
        for (var step = 0; step < 4; step++) {
          _knock(at(0.48 + step * 0.014), 900, gain: 0.16);
        }
        _swoosh(at(0.535), 0.12);
        _slash(hit);
        _thud(at(0.66));
      case DeathAct.bouquet:
        tape.noise(at(0.49), 0.25, gain: 0.08, highpass: 3000, envelope: Env.hit(3, 0.05));
        for (final shot in const [0.555, 0.57, 0.585, 0.60, 0.615]) {
          _gunshot(at(shot), size: 0.75, tail: 0.14);
        }
        _thud(at(0.72));
      case DeathAct.laundry:
        _engine(at(0.42), at(0.50) - at(0.42), 90, 70);
        _knock(at(0.505), 600, gain: 0.3);
        _scuffle(hit, 3);
        _clang(at(0.61), 210);
        _thud(at(0.63));
        _thud(at(0.66), weight: 0.8);
        _engine(at(0.70), at(0.80) - at(0.70), 80, 160);
      case DeathAct.sniper:
        _knock(at(0.50), 1900, gain: 0.16);
        _gunshot(hit, size: 0.9, tail: 0.5, tone: 2200);
        _gunshot(hit + 0.33, size: 0.28, tail: 0.5, tone: 1100);
        _gunshot(hit + 0.66, size: 0.12, tail: 0.5, tone: 800);
        _thud(at(strike + 0.11));
      case DeathAct.rescue:
        _gunshot(hit);
        _thud(at(strike + 0.07));
        for (var step = 0; step < 7; step++) {
          _footstep(at(0.62 + step * 0.0125), 0.8);
        }
        _knock(at(0.715), 260, gain: 0.3);
        for (final (i, beat) in const [0.765, 0.795, 0.825].indexed) {
          _heartbeat(at(beat), 0.8 + i * 0.15);
        }
      case DeathAct.lucky:
        _gunshot(hit, size: 0.9);
        _ricochet(hit + 0.01);
        for (var step = 0; step < 6; step++) {
          _footstep(at(0.675 + step * 0.012), 0.7);
        }
        tape.pluck(at(0.72), 1318.5, length: 1.4, gain: 0.25, brightness: 0.9, damping: 0.998);
    }
  }

  void _footstep(double when, double gain) {
    if (_recorded(const ['step_1', 'step_2', 'step_3', 'step_4'], when, gain: 0.9 * gain)) return;
    tape.noise(when, 0.05, gain: 0.30 * gain, lowpass: 1800, highpass: 300, envelope: Env.hit(6, 0.05));
    tape.tone(when, 0.06, 190, to: 120, gain: 0.28 * gain, envelope: Env.hit(6, 0.05));
  }

  void _heartbeat(double when, double strength) {
    const body = [(1.0, 1.0), (2.0, 0.55), (3.0, 0.3), (4.0, 0.15)];
    tape.tone(when, 0.14, 150, to: 70, gain: 0.42 * strength, partials: body, envelope: Env.hit(4, 0.08));
    tape.tone(when + 0.17, 0.12, 170, to: 85, gain: 0.30 * strength, partials: body, envelope: Env.hit(4, 0.08));
  }

  /// Il fiammifero: uno sfregamento, e la fiammata.
  void _match(double when) {
    tape.noise(when, 0.14, gain: 0.10, highpass: 2800, envelope: Env.rise(1.5));
    tape.noise(when + 0.14, 0.35, gain: 0.14, lowpass: 3500, lowpassTo: 900, highpass: 600, envelope: Env.hit(5, 0.03));
  }

  void _bell(double when, double strength) {
    _recorded(const ['bell', 'bell_2'], when, gain: 0.8 * strength);
    tape.tone(
      when,
      4.2,
      220,
      gain: 0.15 * strength,
      partials: const [(0.5, 0.6), (1, 1), (1.2, 0.7), (1.5, 0.4), (2, 0.6), (2.5, 0.25), (3, 0.2), (4, 0.12)],
      envelope: Env.hit(3.6, 0.002),
    );
  }

  void _gunshot(double when, {double size = 1, double tail = 0.32, double tone = 3800}) {
    tape.noise(when, tail, gain: 0.95 * size, lowpass: tone, lowpassTo: 500, envelope: Env.hit(7, 0.01));
    tape.noise(when, 0.03, gain: 0.55 * size, highpass: 2500, envelope: Env.hit(4, 0.08));
    tape.tone(when, 0.16, 160, to: 48, gain: 0.75 * size, partials: const [(1, 1), (2, 0.5)], envelope: Env.hit(5, 0.02));
  }

  void _swoosh(double when, double length, {double gain = 0.3}) {
    tape.noise(when, length, gain: gain, lowpass: 500, lowpassTo: 5000, highpass: 300, envelope: Env.swell());
  }

  /// La lama: un soffio e il canto dell'acciaio.
  void _slash(double when) {
    _swoosh(when - 0.09, 0.14);
    if (_recorded(const ['knife', 'knife_2'], when - 0.03, gain: 1.2)) return;
    tape.tone(
      when,
      0.5,
      3100,
      gain: 0.10,
      partials: const [(1, 1), (1.37, 0.7), (1.71, 0.5), (2.3, 0.3)],
      envelope: Env.hit(7, 0.004),
    );
  }

  /// Gli archi che strillano, come sotto la doccia di un motel.
  void _stabs(double when, int count) {
    for (var i = 0; i < count; i++) {
      for (final freq in const [1244.5, 1318.5, 1864.7]) {
        tape.tone(when + i * 0.17, 0.14, freq, gain: 0.07, partials: Tape.saw(3), envelope: Env.hit(3, 0.06));
      }
    }
  }

  void _thud(double when, {double weight = 1}) {
    // Il tonfo vero, e sotto un colpo basso che dà peso.
    final real = _recorded(const ['body_fall', 'body_fall_2'], when, gain: min(1.4, weight));
    tape.tone(when, 0.24, 120, to: 45, gain: (real ? 0.25 : 0.55) * weight, partials: const [(1, 1), (2, 0.5), (3, 0.2)], envelope: Env.hit(5, 0.02));
    tape.noise(when, 0.14, gain: 0.3 * weight, lowpass: 500, envelope: Env.hit(5, 0.03));
  }

  /// Un colpo secco su qualcosa di duro: legno, coccio, un tacco.
  void _knock(double when, double freq, {double gain = 0.5}) {
    final names = freq <= 700 ? const ['wood_heavy', 'wood_heavy_2'] : (freq >= 1400 ? const ['latch'] : const ['plank']);
    if (_recorded(names, when, gain: 2 * gain)) return;
    tape.tone(when, 0.09, freq, gain: gain, partials: const [(1, 1), (2.4, 0.5), (4.1, 0.25)], envelope: Env.hit(6, 0.02));
    tape.noise(when, 0.02, gain: gain * 0.6, lowpass: 5000, envelope: Env.hit(3, 0.1));
  }

  /// Qualcosa va in pezzi: tanti tintinnii sparsi nel tempo.
  void _crash(
    double when, {
    required int pieces,
    required double low,
    required double high,
    double spread = 0.4,
    double gain = 0.2,
  }) {
    final rng = Random(pieces * 31 + low.round());
    final names = low >= 1800 ? const ['glass_heavy', 'glass_heavy_2'] : (low < 1000 ? const ['plate', 'plate_2'] : const ['glass_medium']);
    if (_recorded(names, when, gain: 4 * gain)) gain *= 0.5;
    tape.noise(when, 0.25, gain: gain * 1.4, highpass: low, envelope: Env.hit(6, 0.02));
    for (var i = 0; i < pieces; i++) {
      final late = pow(rng.nextDouble(), 1.6) * spread;
      tape.tone(
        when + late,
        0.05 + rng.nextDouble() * 0.16,
        low + rng.nextDouble() * (high - low),
        gain: gain * (0.4 + 0.6 * rng.nextDouble()),
        partials: const [(1, 1), (2.76, 0.4)],
        envelope: Env.hit(6, 0.02),
      );
    }
  }

  void _clang(double when, double base, {double gain = 0.2}) {
    final names = base < 250 ? const ['metal_heavy', 'metal_heavy_2'] : const ['metal_medium'];
    if (_recorded(names, when, gain: 5 * gain)) gain *= 0.4;
    tape.tone(
      when,
      1.3,
      base,
      gain: gain,
      partials: const [(1, 1), (1.59, 0.8), (2.14, 0.7), (2.83, 0.5), (3.9, 0.35), (5.4, 0.2)],
      envelope: Env.hit(4.5, 0.003),
    );
    tape.noise(when, 0.05, gain: gain * 1.5, highpass: 1500, envelope: Env.hit(4, 0.05));
  }

  void _boom(double when) {
    tape.noise(when, 2.2, gain: 1.1, lowpass: 1800, lowpassTo: 160, envelope: Env.hit(3.5, 0.004));
    tape.tone(when, 1.0, 90, to: 28, gain: 0.9, partials: const [(1, 1), (2, 0.5), (3, 0.3)], envelope: Env.hit(4, 0.005));
    _crash(when + 0.3, pieces: 14, low: 500, high: 2600, spread: 1.4, gain: 0.10);
  }

  void _engine(double when, double length, double from, double to) {
    tape.tone(
      when,
      length,
      from,
      to: to,
      gain: 0.20,
      partials: Tape.saw(10),
      envelope: (life) => sin(pi * life) * (0.8 + 0.2 * sin(2 * pi * 23 * life * length)),
    );
    tape.noise(when, length, gain: 0.12, lowpass: 700, envelope: Env.swell());
  }

  void _screech(double when, double length) {
    tape.noise(when, length, gain: 0.22, lowpass: 3600, highpass: 1700, envelope: Env.hold(0.1));
    tape.tone(when, length, 2150, to: 1850, gain: 0.07, partials: Tape.saw(2), envelope: Env.hold(0.1), vibrato: 0.02, vibratoRate: 27);
  }

  /// Il fischio di qualcosa (o qualcuno) che cade, come nei cartoni.
  void _whistle(double when, double length, double from, double to, {double gain = 0.16}) {
    tape.tone(when, length, from, to: to, gain: gain, envelope: Env.hold(0.12), vibrato: 0.01, vibratoRate: 9);
  }

  void _splash(double when) {
    tape.noise(when, 0.9, gain: 0.5, lowpass: 3600, lowpassTo: 500, highpass: 200, envelope: Env.hit(4, 0.02));
    for (final (i, freq) in const [320.0, 410.0, 540.0, 460.0].indexed) {
      tape.tone(when + 0.25 + i * 0.11, 0.08, freq, to: freq * 1.8, gain: 0.12, envelope: Env.swell());
    }
  }

  void _cough(double when) {
    tape.noise(when, 0.11, gain: 0.25, lowpass: 2200, highpass: 500, envelope: Env.hit(4, 0.1));
  }

  void _smack(double when) {
    tape.tone(when, 0.05, 1100, to: 300, gain: 0.5, envelope: Env.hit(4, 0.05));
    tape.noise(when, 0.03, gain: 0.3, highpass: 1800, envelope: Env.hit(3, 0.1));
  }

  /// Il proiettile che rimbalza sul metallo e se ne va fischiando.
  void _ricochet(double when) {
    _recorded(const ['metal_light'], when, gain: 1.2);
    tape.tone(when, 0.06, 2600, gain: 0.35, partials: const [(1, 1), (1.5, 0.6), (2.6, 0.4)], envelope: Env.hit(5, 0.01));
    tape.tone(when + 0.02, 0.6, 3400, to: 1100, gain: 0.20, envelope: Env.hit(3.5, 0.02), vibrato: 0.05, vibratoRate: 28);
  }

  void _buzz(double when, double length) {
    final rng = Random(length.hashCode);
    var cursor = when;
    while (cursor < when + length) {
      final burst = 0.03 + rng.nextDouble() * 0.09;
      tape.tone(cursor, burst, 100, gain: 0.10, partials: Tape.square(9), envelope: Env.hold(0.1));
      tape.noise(cursor, 0.012, gain: 0.2, highpass: 3000, envelope: Env.hit(3, 0.1));
      cursor += burst + rng.nextDouble() * 0.08;
    }
  }

  void _creak(double when, double length) {
    if (_recorded(const ['creak'], when, gain: 1.2)) return;
    tape.tone(
      when,
      length,
      92,
      to: 74,
      gain: 0.12,
      partials: Tape.saw(14),
      envelope: (life) => sin(pi * life) * (sin(2 * pi * 13 * life * length) > 0.2 ? 1 : 0.15),
    );
  }

  void _scuffle(double when, int count) {
    _recorded(const ['punch', 'punch_2'], when, gain: 0.9);
    for (var i = 0; i < count; i++) {
      if (_recorded(const ['cloth_1', 'cloth_2'], when + i * 0.11)) continue;
      tape.noise(when + i * 0.11, 0.09, gain: 0.25, lowpass: 1500, highpass: 250, envelope: Env.swell());
    }
  }
}
