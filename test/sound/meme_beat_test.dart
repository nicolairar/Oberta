import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/sound/meme_beat.dart';
import 'package:oberta/sound/memes.dart';

void main() {
  late DateTime now;
  late List<(Meme, Duration)> played;
  late MemeBeat beat;

  setUp(() {
    now = DateTime(2026);
    played = [];
    beat = MemeBeat(clock: () => now, dice: Random(1), play: (meme, after) => played.add((meme, after)))
      ..enabled = () => true;
  });

  test('silent when meme mode is off', () {
    beat.enabled = () => false;
    expect(beat.hit(MemeMoment.accused), isNull);
    expect(played, isEmpty);
  });

  test('small memes respect the gap', () {
    expect(beat.hit(MemeMoment.voteCast), isNotNull);
    now = now.add(const Duration(seconds: 3));
    expect(beat.hit(MemeMoment.voteCast), isNull);
    now = now.add(MemeBeat.smallGap);
    expect(beat.hit(MemeMoment.voteCast), isNotNull);
    expect(beat.hit(MemeMoment.chatBurst), isNull);
  });

  test('a big beat during another meme waits for it to end, and is short', () {
    beat.heard(Meme.catLaugh);
    now = now.add(const Duration(seconds: 3));
    final meme = beat.hit(MemeMoment.accused)!;
    expect(meme.isLong, isFalse);
    expect(played.single.$2, const Duration(milliseconds: 250));
  });

  test('a big beat right on top of the last meme is skipped', () {
    beat.hit(MemeMoment.accused);
    now = now.add(const Duration(seconds: 1));
    expect(beat.hit(MemeMoment.verdictMafia), isNull);
  });

  test('never the same meme twice in a row', () {
    Meme? last;
    for (var i = 0; i < 50; i++) {
      now = now.add(const Duration(seconds: 20));
      final meme = beat.hit(MemeMoment.save)!;
      expect(meme, isNot(last));
      last = meme;
    }
  });

  test('a win always plays the victory song, even right after a long meme', () {
    beat.heard(Meme.hellNah);
    now = now.add(const Duration(seconds: 1));
    expect(beat.hit(MemeMoment.victory), Meme.auraFarming);
  });

  test('a broken heart plays the lovers rizz', () {
    expect(beat.hit(MemeMoment.lovers), Meme.rizzLove);
  });

  test('long memes stay rare', () {
    var longs = 0;
    for (var i = 0; i < 60; i++) {
      now = now.add(const Duration(seconds: 30));
      if (beat.hit(MemeMoment.verdictInnocent)!.isLong) longs++;
    }
    // Half an hour: at most one long meme every two minutes.
    expect(longs, lessThanOrEqualTo(16));
  });
}
