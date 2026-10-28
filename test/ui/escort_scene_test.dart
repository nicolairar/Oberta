import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/narration/death_story.dart';
import 'package:oberta/sound/scene_cues.dart';
import 'package:oberta/ui/widgets/death_scene.dart';

// La scorta del Presidente (docs/ruoli.md, 3.8): l'attentato va a vuoto
// perché una guardia alza la valigetta d'acciaio. Un filmato tutto suo.

void main() {
  test('la scorta ha il suo filmato: un salvataggio che va sopra ogni agguato', () {
    expect(deathActFor(DeathStory.escortId), DeathAct.escort);
    expect(DeathAct.escort.survives, isTrue);
    expect(DeathAct.escort.escortSave, isTrue);
    expect(DeathAct.escort.doctorSaves, isFalse);
    expect(DeathAct.escort.luckyEscape, isFalse);
    for (final attack in DeathAct.values.where((act) => !act.survives)) {
      expect(spliceOf(attack, DeathAct.escort), Splice.alone, reason: attack.name);
    }
    final cues = sceneCuesFor(DeathAct.gun, save: DeathAct.escort);
    expect(cues, isNotEmpty);
  });

  testWidgets('si disegna dal primo all\'ultimo fotogramma, sopra qualunque agguato', (tester) async {
    for (final attack in [DeathAct.gun, DeathAct.knife, DeathAct.car, DeathAct.burst]) {
      for (var frame = 0; frame <= 60; frame++) {
        await tester.pumpWidget(CustomPaint(
          size: const Size(393, 852),
          painter: DeathScenePainter(t: frame / 60, act: attack, save: DeathAct.escort),
        ));
        expect(tester.takeException(), isNull, reason: '${attack.name} fotogramma $frame');
      }
    }
  });

  testWidgets('a film finito chi era nel mirino resta anonimo e vedrà l\'alba', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(
      MaterialApp(
        home: DeathScene(
          act: DeathAct.gun,
          save: DeathAct.escort,
          victimName: 'qualcuno',
          caption: 'Esterno, notte.',
          onFinished: () {},
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(DeathScene.length * 0.5);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('SALTA'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('VEDRÀ L\'ALBA'), findsOneWidget);
    expect(find.text('QUALCUNO'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
