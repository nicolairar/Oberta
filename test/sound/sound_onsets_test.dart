import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/sound/fx_groups.dart';
import 'package:oberta/sound/scene_cues.dart';
import 'package:oberta/sound/sound_onsets.dart';
import 'package:oberta/sound/verdict_cues.dart';
import 'package:oberta/ui/widgets/death_scene.dart';
import 'package:oberta/ui/widgets/verdict_scene.dart';

/// Tutti i file che una scena può suonare, per ogni suono.
List<String> assetsOf(SceneCue cue) => [
      if (cue.fx case final fx?) for (var take = 1; take <= fx.count; take++) fx.asset(take),
      if (cue.sample case final name?) 'sounds/$name.wav',
      if (cue.meme case final meme?) meme.asset,
    ];

void main() {
  test('ogni file che le scene suonano ha il suo inizio e la sua durata, e l\'inizio sta dentro il file', () {
    final used = {
      for (final act in DeathAct.values)
        for (final memes in [false, true])
          for (final cue in sceneCuesFor(act, memes: memes)) ...assetsOf(cue),
      for (final take in VerdictTake.values)
        for (final cue in verdictCuesFor(take, memes: true)) ...assetsOf(cue),
    };
    for (final asset in used) {
      final shape = soundShapes[asset];
      expect(shape, isNotNull, reason: '$asset: rigenerare con tool/sound/onsets.py');
      expect(shape!.$1, lessThan(shape.$2), reason: asset);
    }
  });

  test('la tabella copre tutti i file degli effetti, e solo quelli', () {
    final files = {
      for (final folder in ['sfx', 'sounds', 'meme'])
        for (final file in Directory('assets/$folder').listSync())
          if (file.path.endsWith('.m4a') || file.path.endsWith('.wav')) file.path.substring('assets/'.length),
    };
    expect(soundShapes.keys.toSet(), files, reason: 'rigenerare con tool/sound/onsets.py');
    // Il silenzio che si salta: lo scricchiolio del cappio, tra gli altri.
    expect(soundShapes['sounds/creak.wav']!.$1, greaterThan(100));
    expect(soundShapes[FxGroup.revolver.asset(1)]!.$1, 0, reason: 'lo sparo comincia subito');
  });
}
