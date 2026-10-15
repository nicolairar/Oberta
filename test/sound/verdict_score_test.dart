import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/sound/synth.dart';
import 'package:oberta/sound/verdict_score.dart';
import 'package:oberta/ui/widgets/verdict_scene.dart';

import 'scene_score_test.dart' show loudness, samplesOf;

void main() {
  test('ogni verdetto ha la sua musica, lunga quanto il film più la coda, e mai muta', () {
    final seen = <int>{};
    for (final take in VerdictTake.values) {
      final wav = composeVerdict(take);
      final seconds = VerdictScore.secondsOf(take);
      expect(seconds, take.length.inMilliseconds / 1000 + VerdictScore.tail);
      expect(wav.length, 44 + (seconds * Tape.rate).ceil() * 2, reason: take.name);
      final samples = samplesOf(wav);
      expect(samples.every((sample) => sample.abs() <= 1), isTrue, reason: '${take.name}: nessun picco oltre il massimo');
      final score = VerdictScore(take);
      final payoff = score.at(take.payoff);
      expect(loudness(samples, 0.3, score.at(0.28)), greaterThan(0.01), reason: '${take.name}: la folla in marcia');
      expect(loudness(samples, payoff - 0.1, payoff + 0.6), greaterThan(0.03), reason: '${take.name}: la battuta');
      expect(loudness(samples, score.at(VerdictBeats.card), score.at(VerdictBeats.card) + 1.5), greaterThan(0.01),
          reason: '${take.name}: la chiusa sulla carta');
      // Mai un buco di silenzio lungo, dal primo all'ultimo secondo del film.
      for (var from = 0.2; from < take.length.inMilliseconds / 1000 - 0.5; from += 0.5) {
        expect(loudness(samples, from, from + 0.5), greaterThan(0.002), reason: '${take.name} a $from s');
      }
      expect(seen.add(Object.hashAll(wav)), isTrue, reason: '${take.name} suona come un altro verdetto');
    }
  });

  test('lo stesso verdetto suona sempre uguale, anche chiesto per numero', () {
    expect(composeVerdict(VerdictTake.treno), composeVerdict(VerdictTake.treno));
    for (final take in VerdictTake.values) {
      expect(composeVerdictByIndex(take.index), composeVerdict(take), reason: take.name);
    }
  });

  test('i rumori cadono sul fotogramma giusto', () {
    for (final take in VerdictTake.values) {
      final score = VerdictScore(take);
      expect(score.at(0), 0);
      expect(score.at(1), closeTo(take.length.inMilliseconds / 1000, 1e-9));
    }
    final splash = VerdictScore(VerdictTake.molo).at(VerdictBeats.splash);
    final samples = samplesOf(composeVerdict(VerdictTake.molo));
    expect(loudness(samples, splash, splash + 0.3), greaterThan(loudness(samples, splash - 0.6, splash - 0.3)),
        reason: 'lo splash si sente quando l\'acqua schizza');
  });
}
