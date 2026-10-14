import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/sound/cue_sounds.dart';
import 'package:oberta/sound/synth.dart';

List<double> samplesOf(Uint8List wav) {
  final data = ByteData.sublistView(wav, 44);
  return [for (var i = 0; i < data.lengthInBytes; i += 2) data.getInt16(i, Endian.little) / 32768];
}

void main() {
  test('ogni suono breve si incide, suona davvero e resta breve', () {
    final seen = <int>{};
    for (final cue in Cue.values) {
      final wav = composeCue(cue);
      expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF', reason: cue.name);
      final samples = samplesOf(wav);
      final seconds = samples.length / Tape.rate;
      expect(seconds, lessThanOrEqualTo(4.5), reason: '${cue.name} è troppo lungo');
      final peak = samples.map((sample) => sample.abs()).reduce(max);
      expect(peak, greaterThan(0.5), reason: '${cue.name} è muto');
      expect(seen.add(Object.hashAll(wav)), isTrue, reason: '${cue.name} suona come un altro');
    }
  });

  test('gli scatti del tamburo e del timer sono secchi, pronti a ripetersi', () {
    for (final cue in [Cue.click, Cue.tick]) {
      expect(samplesOf(composeCue(cue)).length / Tape.rate, lessThan(0.1), reason: cue.name);
    }
  });

  test('lo stesso suono è sempre uguale, anche da un altro isolate', () {
    expect(composeCueByIndex(Cue.innocent.index), composeCue(Cue.innocent));
  });
}
