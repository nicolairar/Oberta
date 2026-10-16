import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/narration/death_story.dart';
import 'package:oberta/narration/italian_pack.dart';
import 'package:oberta/narration/narrator_script.dart';
import 'package:oberta/rules/game_engine.dart';
import 'package:oberta/rules/player.dart';
import 'package:oberta/sound/fx_groups.dart';
import 'package:oberta/sound/scene_cues.dart';
import 'package:oberta/ui/widgets/death_scene.dart';

const _strike = DeathScenePainter.strike;

/// Tutte le coppie che il copione può pescare: l'agguato della famiglia e
/// chi lo manda a vuoto.
List<(String, String)> get pairs => [
      for (final method in italianPack.methods) ...[
        for (final id in DeathStory.rescuesFor(method.id)) (method.id, id),
        for (final id in DeathStory.luckFor(method.id)) (method.id, id),
      ],
    ];

void main() {
  test('ogni coppia che il copione può pescare ha il suo filmato', () {
    expect(pairs, isNotEmpty);
    for (final (method, variant) in pairs) {
      final attack = deathActFor(method);
      final save = deathActFor(variant);
      expect(attack.survives, isFalse, reason: method);
      expect(save.survives, isTrue, reason: variant);
      expect(canSpare(attack, save), isTrue, reason: '$method + $variant');
    }
  });

  test('e ogni filmato composto è una coppia che il copione sa raccontare', () {
    final told = {for (final (method, variant) in pairs) (deathActFor(method), deathActFor(variant))};
    for (final attack in DeathAct.values) {
      for (final save in DeathAct.values) {
        if (!canSpare(attack, save) || spliceOf(attack, save) == Splice.alone) continue;
        // Le pinze vanno solo dove c'è un proiettile, ma il filmato le sa
        // girare ovunque il Dottore si inginocchi.
        if (save.doctorSaves) {
          expect(told.any((pair) => pair.$1 == attack && pair.$2.doctorSaves), isTrue, reason: attack.name);
        } else {
          expect(told, contains((attack, save)), reason: '${attack.name} + ${save.name}');
        }
      }
    }
  });

  test('la storia di un salvataggio dice al filmato agguato e rimedio', () {
    final script = NarratorScript(random: Random(3));
    for (final outcome in [AttackOutcome.healed, AttackOutcome.shrugged]) {
      for (var i = 0; i < 20; i++) {
        final story = script.stage(DawnReport(
          round: 1,
          attacks: [NightAttack(const Player(id: 's', name: 'Sara'), AttackSource.family, outcome)],
        )).single;
        final film = filmFor(story);
        expect(film.act, deathActFor(story.attack!.id));
        expect(film.save, deathActFor(story.method.id));
        expect(film.save!.survives, isTrue);
        expect(film.save!.doctorSaves, outcome == AttackOutcome.healed);
      }
    }
    final death = script.composeDeath();
    expect(filmFor(death), (act: deathActFor(death.method.id), save: null));
  });

  test('il Dottore arriva dove l\'agguato lascia la vittima, e quando è già stesa', () {
    for (final attack in DeathAct.values) {
      final lie = debugLieOf(attack);
      if (lie == null) {
        expect(canSpare(attack, DeathAct.rescue), isFalse, reason: attack.name);
        continue;
      }
      expect(debugDownAt(attack, lie.down - 0.01), isNull, reason: '${attack.name}: prima è ancora in piedi');
      expect(debugDownAt(attack, lie.down + 0.002), closeTo(lie.at, 0.001), reason: attack.name);
      // Nel filmato composto è a terra prima che il Dottore si inginocchi.
      final arrives = spliceClock(attack, DeathAct.rescue, 0.66);
      expect(debugDownAt(attack, arrives), isNotNull, reason: attack.name);
    }
  });

  test('il tempo dell\'agguato e quello del filmato composto vanno avanti e indietro uguali', () {
    for (final attack in DeathAct.values) {
      for (var t = 0.0; t <= 1; t += 0.01) {
        final clock = spliceClock(attack, DeathAct.pliers, t);
        expect(spliceTime(attack, DeathAct.pliers, clock), closeTo(t, 1e-9), reason: '${attack.name} $t');
        expect(clock, greaterThanOrEqualTo(t - 1e-9), reason: 'l\'agguato non torna indietro');
      }
      // Prima del colpo e coi colpi di fortuna, l'agguato va al suo passo.
      expect(spliceClock(attack, DeathAct.pliers, 0.5), 0.5);
      expect(spliceClock(attack, DeathAct.jam, 0.7), 0.7);
    }
  });

  test('ogni filmato composto si disegna per tutto il film', () {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    for (final attack in DeathAct.values) {
      for (final save in DeathAct.values.where((act) => act.survives)) {
        if (!canSpare(attack, save)) continue;
        for (var t = 0.0; t <= 1; t += 0.05) {
          DeathScenePainter(t: t, act: attack, save: save).paint(canvas, const Size(390, 844));
        }
      }
    }
    recorder.endRecording().dispose();
  });

  group('i suoni seguono il montaggio', () {
    test('col Dottore: l\'agguato coi suoi suoni, poi il Dottore senza il suo sparo', () {
      for (final attack in DeathAct.values) {
        if (!canSpare(attack, DeathAct.defibrillator)) continue;
        final alone = sceneCuesFor(attack);
        final cues = sceneCuesFor(attack, save: DeathAct.defibrillator);
        for (var i = 1; i < cues.length; i++) {
          expect(cues[i].t, greaterThanOrEqualTo(cues[i - 1].t));
        }
        // Il colpo dell'agguato c'è, allo stesso fotogramma.
        final hit = alone.where((cue) => (cue.t - _strike).abs() < 0.001 && cue.fx != null).map((cue) => cue.fx);
        for (final fx in hit) {
          expect(cues.any((cue) => cue.fx == fx && (cue.t - _strike).abs() < 0.001), isTrue, reason: attack.name);
        }
        // Lo sparo con cui cominciano i filmati del Dottore, no.
        if (!alone.any((cue) => cue.fx == FxGroup.revolver)) {
          expect(cues.where((cue) => cue.fx == FxGroup.revolver), isEmpty, reason: attack.name);
        }
        // Le scosse del defibrillatore, sì.
        expect(cues.where((cue) => cue.fx == FxGroup.spark && cue.t > 0.70), isNotEmpty, reason: attack.name);
        // Il tonfo della caduta arriva prima del Dottore in ginocchio.
        final falls = cues.where((cue) => cue.fx == FxGroup.faint);
        for (final fall in falls) {
          expect(fall.t, lessThan(0.69), reason: '${attack.name}: cade prima che il Dottore arrivi');
        }
      }
    });

    test('l\'arma inceppata fa clic e non spara', () {
      for (final attack in [DeathAct.burst, DeathAct.lupara, DeathAct.trombone]) {
        final cues = sceneCuesFor(attack, save: DeathAct.jam);
        final shots = {FxGroup.tommy, FxGroup.shotgun, FxGroup.revolver};
        expect(cues.where((cue) => shots.contains(cue.fx)), isEmpty, reason: attack.name);
        expect(cues.where((cue) => cue.sample == 'click'), isNotEmpty, reason: attack.name);
      }
    });

    test('il colpo fermato nel taschino parte davvero, e poi fa «ding»', () {
      final cues = sceneCuesFor(DeathAct.lupara, save: DeathAct.lucky);
      expect(cues.where((cue) => cue.fx == FxGroup.shotgun), isNotEmpty);
      expect(cues.where((cue) => cue.fx == FxGroup.scream), isEmpty, reason: 'nessuno muore');
      expect(cues.where((cue) => cue.sample == 'metal_light'), isNotEmpty);
    });

    test('chi scivola sulla buccia col pugnale non spara', () {
      final knife = sceneCuesFor(DeathAct.knife, save: DeathAct.banana);
      expect(knife.where((cue) => cue.fx == FxGroup.revolver), isEmpty);
      expect(knife.where((cue) => cue.fx == FxGroup.slidewhist), isNotEmpty);
      final tommy = sceneCuesFor(DeathAct.burst, save: DeathAct.blackCat);
      expect(tommy.where((cue) => cue.fx == FxGroup.tommy), isNotEmpty);
      expect(tommy.where((cue) => cue.fx == FxGroup.revolver), isEmpty);
    });
  });

  testWidgets('sopra un agguato, chi si salva resta anonimo e vedrà l\'alba', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DeathScene(
          act: DeathAct.poison,
          save: DeathAct.defibrillator,
          victimName: 'qualcuno',
          caption: 'Esterno, notte.',
          onFinished: () {},
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('SALTA'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('VEDRÀ L\'ALBA'), findsOneWidget);
    expect(find.text('QUALCUNO'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
