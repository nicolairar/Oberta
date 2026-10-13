import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:omerta/sound/scene_score.dart';
import 'package:omerta/sound/synth.dart';
import 'package:omerta/ui/widgets/death_scene.dart';

/// I campioni di un file WAV a 16 bit, da -1 a 1.
List<double> samplesOf(Uint8List wav) {
  final data = ByteData.sublistView(wav, 44);
  return [for (var i = 0; i < data.lengthInBytes; i += 2) data.getInt16(i, Endian.little) / 32768];
}

/// Quanto è forte il nastro tra [from] e [to] secondi.
double loudness(List<double> samples, double from, double to) {
  final slice = samples.sublist((from * Tape.rate).round(), (to * Tape.rate).round());
  return sqrt(slice.fold<double>(0, (sum, sample) => sum + sample * sample) / slice.length);
}

void main() {
  group('Tape', () {
    test('incide un WAV mono a 16 bit, lungo quanto il nastro', () {
      final tape = Tape(0.5)..tone(0, 0.5, 440);
      final wav = tape.toWav();
      expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
      final header = ByteData.sublistView(wav);
      expect(header.getUint16(22, Endian.little), 1, reason: 'mono');
      expect(header.getUint32(24, Endian.little), Tape.rate);
      expect(header.getUint16(34, Endian.little), 16);
      expect(wav.length, 44 + (0.5 * Tape.rate).ceil() * 2);
      expect(header.getUint32(40, Endian.little), wav.length - 44);
    });

    test('porta il volume al massimo senza mai sforare', () {
      final quiet = Tape(0.2)..tone(0, 0.2, 440, gain: 0.001, envelope: Env.hold());
      final loud = Tape(0.2)..tone(0, 0.2, 440, gain: 50, envelope: Env.hold());
      for (final tape in [quiet, loud]) {
        final peak = samplesOf(tape.toWav()).map((sample) => sample.abs()).reduce(max);
        expect(peak, inInclusiveRange(0.9, 1.0));
      }
    });

    test('un nastro vuoto resta in silenzio, senza dividere per zero', () {
      expect(samplesOf(Tape(0.1).toWav()), everyElement(0));
    });

    test('quello che cade fuori dal nastro viene tagliato, non fa danni', () {
      final tape = Tape(0.1)
        ..tone(-0.05, 0.1, 300)
        ..noise(0.08, 1.0)
        ..pluck(5, 200);
      expect(tape.samples.every((sample) => sample.isFinite), isTrue);
    });

    test('la corda pizzicata si spegne da sola', () {
      final tape = Tape(2)..pluck(0, 220, length: 2, damping: 0.99);
      final samples = tape.samples;
      double level(int from) => samples.sublist(from, from + 2000).map((s) => s.abs()).reduce(max);
      expect(level(0), greaterThan(level(20000) * 5));
    });
  });

  group('la colonna sonora di una scena', () {
    final strike = SceneScore.at(SceneScore.strike);

    test('ogni scena ha la sua, lunga più del film e mai muta', () {
      final seen = <int>{};
      for (final act in DeathAct.values) {
        final wav = composeScene(act);
        expect(wav.length, 44 + (SceneScore.seconds * Tape.rate).ceil() * 2, reason: act.name);
        final samples = samplesOf(wav);
        expect(samples.every((sample) => sample.abs() <= 1), isTrue, reason: act.name);
        expect(loudness(samples, 0.4, 3.0), greaterThan(0.01), reason: '${act.name}: i passi e il contrabbasso');
        expect(loudness(samples, strike - 0.2, strike + 1.2), greaterThan(0.05), reason: '${act.name}: il colpo');
        expect(loudness(samples, 12.6, 15), greaterThan(0.005), reason: '${act.name}: il finale sul ritratto');
        expect(seen.add(Object.hashAll(wav)), isTrue, reason: '${act.name} suona come un\'altra scena');
      }
      expect(SceneScore.seconds, greaterThan(DeathScene.length.inSeconds));
    });

    test('la stessa scena suona sempre uguale', () {
      expect(composeScene(DeathAct.piano), composeScene(DeathAct.piano));
      expect(composeSceneByIndex(DeathAct.kiss.index), composeScene(DeathAct.kiss));
    });

    test('il colpo spicca su tutto, e un attimo prima la musica trattiene il fiato', () {
      // Le armi da fuoco: lì prima del colpo non c'è nemmeno il fruscio di una lama.
      for (final act in [DeathAct.gun, DeathAct.lupara, DeathAct.sniper, DeathAct.rescue]) {
        final samples = samplesOf(composeScene(act));
        final hit = loudness(samples, strike, strike + 0.25);
        expect(hit, greaterThan(loudness(samples, 1, 3) * 1.5), reason: act.name);
        expect(hit, greaterThan(loudness(samples, strike - 0.05, strike - 0.01) * 2), reason: act.name);
      }
    });

    test('i rumori cadono sul fotogramma giusto del film', () {
      expect(SceneScore.at(0), 0);
      expect(SceneScore.at(1), DeathScene.length.inSeconds);
      expect(strike, closeTo(filmClock(DeathScenePainter.strike) * 14, 1e-9));
      expect(strike, inInclusiveRange(7, 8.5), reason: 'il rallentatore porta il colpo oltre metà film');
    });
  });
}
