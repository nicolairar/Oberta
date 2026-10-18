import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/online/game/game_schedule.dart';
import 'package:oberta/rules/role.dart';
import 'package:oberta/sound/meme_beat.dart';
import 'package:oberta/sound/memes.dart';
import 'package:oberta/ui/screens/online/game/meme_director.dart';

void main() {
  late DateTime now;
  late MemeSnapshot snapshot;
  late List<(Meme, Duration)> played;
  late MemeDirector director;

  void at(MemeSnapshot next, {int seconds = 0}) {
    now = now.add(Duration(seconds: seconds));
    snapshot = next;
    director.update();
  }

  setUp(() {
    now = DateTime(2026);
    played = [];
    snapshot = const MemeSnapshot();
    final beat = MemeBeat(clock: () => now, dice: Random(3), play: (meme, after) => played.add((meme, after)))
      ..enabled = () => true;
    director = MemeDirector(read: () => snapshot, beat: beat, clock: () => now);
    director.update();
  });

  test('the first look at a game in progress plays nothing', () {
    at(const MemeSnapshot(stage: Stage.vote, round: 2, votes: {'a': 'b'}, timeLeft: Duration(seconds: 3)));
    // Rejoining a vote in its last seconds: still nothing.
    expect(played, isEmpty);
  });

  test('a fresh game opens with a meme', () {
    at(const MemeSnapshot(stage: Stage.reveal, round: 1));
    expect(played, isNotEmpty);
  });

  test('votes: accused leader, then casts paced so they never overlap', () {
    at(const MemeSnapshot(stage: Stage.discussion, round: 1));
    at(const MemeSnapshot(stage: Stage.vote, round: 1), seconds: 1);
    at(const MemeSnapshot(stage: Stage.vote, round: 1, votes: {'a': 'b'}), seconds: 12);
    at(const MemeSnapshot(stage: Stage.vote, round: 1, votes: {'a': 'b', 'c': 'd'}), seconds: 1);
    at(const MemeSnapshot(stage: Stage.vote, round: 1, votes: {'a': 'b', 'c': 'd', 'e': 'f'}), seconds: 12);
    // Vote call, accused, one cast (the middle one fell inside the gap).
    expect(played, hasLength(3));
    for (var i = 1; i < played.length; i++) {
      expect(played[i].$1, isNot(played[i - 1].$1));
    }
  });

  test('timer panic fires once per window', () {
    at(const MemeSnapshot(stage: Stage.discussion, round: 1, timeLeft: Duration(seconds: 30)));
    at(const MemeSnapshot(stage: Stage.discussion, round: 1, timeLeft: Duration(seconds: 5)), seconds: 25);
    at(const MemeSnapshot(stage: Stage.discussion, round: 1, timeLeft: Duration(seconds: 4)), seconds: 10);
    expect(played, hasLength(1));
  });

  test('a chat burst and a player dropping each get a beat', () {
    at(const MemeSnapshot(stage: Stage.discussion, round: 1));
    at(MemeSnapshot(stage: Stage.discussion, round: 1, dayChat: [now, now, now]), seconds: 1);
    expect(played, hasLength(1));
    at(MemeSnapshot(stage: Stage.discussion, round: 1, offline: const {'x'}), seconds: 10);
    expect(played, hasLength(2));
  });

  test('the verdict and the end use only public facts', () {
    at(const MemeSnapshot(stage: Stage.verdictFilm, round: 1));
    at(const MemeSnapshot(stage: Stage.verdict, round: 1, lynchRound: 1), seconds: 1);
    expect(played.single.$1, anyOf(Meme.chicken, Meme.heeHee));
    at(const MemeSnapshot(stage: Stage.ended, round: 1, winner: Team.mafia), seconds: 200);
    expect(played.last.$1, anyOf(Meme.catLaugh, Meme.hellNah));
  });
}
