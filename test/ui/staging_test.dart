import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/narration/death_story.dart';
import 'package:oberta/narration/narration_pack.dart';
import 'package:oberta/narration/narrator_script.dart';
import 'package:oberta/ui/widgets/death_scene.dart';

void main() {
  test('la regia di una storia dipende solo da quello che la storia è', () {
    DeathStory story(String text) => DeathStory(
      scene: StoryPiece('palermo-vucciria', text),
      method: const StoryPiece('pugnale', 'Un pugnale.'),
      epilogue: const StoryPiece('gatto', 'Un gatto.'),
      fact: 'Morto.',
    );
    // Lo stesso copione in un'altra lingua: stessi id, altre parole.
    expect(stagingFor(story('Esterno, notte.')), stagingFor(story('Exterior, night.')));
  });

  test('online ogni telefono gira lo stesso filmato, e le regie girano tutte', () {
    final seen = <Staging>{};
    for (var seed = 0; seed < 60; seed++) {
      final mine = NarratorScript(random: Random(seed)).composeDeath();
      final theirs = NarratorScript(random: Random(seed)).composeDeath();
      expect(stagingFor(mine), stagingFor(theirs), reason: 'seme $seed');
      seen.add(stagingFor(mine));
    }
    expect(seen, {Staging.classic, ...Staging.demos});
  });

  test('una coreografia non ancora provata con la regia resta classica', () {
    for (final staging in Staging.demos) {
      expect(staging.forAct(DeathAct.piano).isClassic, isTrue);
      expect(staging.forAct(DeathAct.knife), staging);
      // L'auto non ha nessuno dietro l'angolo, e reagisce ai fari a modo suo.
      final car = staging.forAct(DeathAct.car);
      expect(car.cover, Cover.corner);
      expect(car.reaction, Reaction.unaware);
      expect(car.mirrored, staging.mirrored);
    }
  });

  test('ogni coreografia si disegna con ogni regia, dall\'inizio alla fine', () {
    const size = Size(390, 844);
    for (final staging in [Staging.classic, ...Staging.demos]) {
      for (final act in DeathAct.values) {
        for (var i = 0; i <= 40; i++) {
          final recorder = ui.PictureRecorder();
          DeathScenePainter(t: i / 40, act: act, staging: staging).paint(Canvas(recorder), size);
          recorder.endRecording().dispose();
        }
      }
    }
  });
}
