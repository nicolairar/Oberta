import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/sound/scene_cues.dart';
import 'package:oberta/sound/verdict_cues.dart';
import 'package:oberta/ui/widgets/death_scene.dart';
import 'package:oberta/ui/widgets/verdict_scene.dart';

void main() {
  void checkSheet(List<SceneCue> cues, String name) {
    expect(cues, isNotEmpty, reason: name);
    for (var i = 0; i < cues.length; i++) {
      final cue = cues[i];
      expect(cue.t, inInclusiveRange(0, 1), reason: name);
      expect(cue.gain, inInclusiveRange(0.1, 1), reason: '$name: niente oltre il volume scelto');
      if (i > 0) expect(cue.t, greaterThanOrEqualTo(cues[i - 1].t), reason: '$name: in ordine di tempo');
      if (cue.sample != null) {
        expect(File('assets/sounds/${cue.sample}.wav').existsSync(), isTrue, reason: '$name: ${cue.sample}');
      }
      if (cue.fx != null) {
        expect(File('assets/${cue.fx!.asset(1)}').existsSync(), isTrue, reason: '$name: ${cue.fx}');
      }
    }
  }

  test('ogni scena della notte ha i suoi suoni, al fotogramma giusto e coi file che esistono', () {
    for (final act in DeathAct.values) {
      final cues = sceneCuesFor(act);
      checkSheet(cues, act.name);
      expect(cues.where((cue) => cue.meme != null), isEmpty, reason: 'senza modalità meme, niente meme');
      // Qualcosa suona intorno al momento che conta.
      expect(cues.any((cue) => (cue.t - DeathScenePainter.strike).abs() < 0.1 || act == DeathAct.burst || act == DeathAct.driveBy),
          isTrue, reason: act.name);
    }
  });

  test('in modalità meme i meme arrivano, ma solo dove li abbiamo messi', () {
    final kiss = sceneCuesFor(DeathAct.kiss, memes: true);
    expect(kiss.where((cue) => cue.meme != null), isNotEmpty);
    expect(sceneCuesFor(DeathAct.manhole, memes: true).where((cue) => cue.meme != null), isNotEmpty);
  });

  test('ogni filmato del verdetto ha i suoi suoni', () {
    for (final take in VerdictTake.values) {
      checkSheet(verdictCuesFor(take), take.name);
    }
  });
}
