import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omerta/main.dart';
import 'package:omerta/narration/italian_pack.dart';
import 'package:omerta/ui/widgets/city_backdrop.dart';
import 'package:omerta/ui/widgets/deal_table.dart';
import 'package:omerta/ui/widgets/death_scene.dart';
import 'package:omerta/ui/widgets/noir_avatar.dart';
import 'package:omerta/ui/widgets/revolver_cylinder.dart';
import 'package:omerta/ui/widgets/scene_scaffold.dart';

void main() {
  testWidgets('ogni città e ogni ora del giorno si disegnano, anche in movimento', (tester) async {
    for (final style in SkylineStyle.values) {
      for (final mood in SceneMood.values) {
        await tester.pumpWidget(MaterialApp(
          home: CityBackdrop(mood: mood, style: style, rain: true, child: const SizedBox()),
        ));
        for (var frame = 0; frame < 5; frame++) {
          await tester.pump(const Duration(milliseconds: 700));
        }
        expect(tester.takeException(), isNull, reason: '$style $mood');
      }
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('il cielo sfuma da un\'ora all\'altra e poi si ferma', (tester) async {
    Widget scene(SceneMood mood) => MaterialApp(home: CityBackdrop(mood: mood, child: const SizedBox()));

    await tester.pumpWidget(scene(SceneMood.night));
    await tester.pumpWidget(scene(SceneMood.dawn));
    for (var frame = 0; frame < 12; frame++) {
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('con le animazioni ridotte il fondale resta fermo', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await tester.pumpWidget(const OmertaApp());
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(find.text('OMERTÀ'), findsOneWidget);
  });

  test('ogni città del copione ha il suo profilo', () {
    expect(skylineFor('chicago'), SkylineStyle.metropolis);
    expect(skylineFor('new-york'), SkylineStyle.metropolis);
    expect(skylineFor('palermo'), SkylineStyle.mediterranean);
    expect(skylineFor('napoli'), SkylineStyle.volcano);
    expect(skylineFor('las-vegas'), SkylineStyle.desert);
  });

  testWidgets('tanti nomi, tanti ritratti: nessuno fa crollare il pittore', (tester) async {
    const names = [
      'Tu', 'Marco', 'Giulia', 'Luca', 'Sara', 'Paolo', 'Elena', 'Davide',
      'Chiara', 'Matteo', 'Anna', 'Simone', 'Marta', 'Żaneta', '李雷', '',
    ];
    await tester.pumpWidget(MaterialApp(
      home: Wrap(
        children: [
          for (final name in names) ...[
            NoirAvatar(seed: name),
            NoirAvatar(seed: name, size: 120, faded: true),
          ],
        ],
      ),
    ));
    expect(tester.takeException(), isNull);
    expect(find.byType(NoirAvatar), findsNWidgets(names.length * 2));
  });

  test('ogni azione del copione ha la sua coreografia', () {
    final staged = {for (final method in italianPack.methods) deathActFor(method.id)};
    expect(staged, DeathAct.values.toSet(), reason: 'nessuna coreografia resta senza copione');
    expect(deathActFor('pugnale'), DeathAct.knife);
    expect(deathActFor('violino'), DeathAct.burst);
    expect(deathActFor('azione-senza-scena'), DeathAct.knife);
  });

  testWidgets('ogni coreografia si disegna dal primo all\'ultimo fotogramma', (tester) async {
    for (final act in DeathAct.values) {
      for (final hat in AvatarHead.values) {
        for (var frame = 0; frame <= 40; frame++) {
          await tester.pumpWidget(CustomPaint(
            size: const Size(393, 852),
            painter: DeathScenePainter(t: frame / 40, act: act, victimHat: hat),
          ));
          expect(tester.takeException(), isNull, reason: '$act $hat fotogramma $frame');
        }
      }
    }
  });

  testWidgets('la scena del delitto dura qualche secondo, poi passa la mano', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    var finished = 0;
    await tester.pumpWidget(MaterialApp(
      home: DeathScene(
        act: DeathAct.piano,
        victimName: 'Marco',
        caption: 'Esterno, notte. Un vicolo.',
        onFinished: () => finished++,
      ),
    ));
    await tester.pump(const Duration(seconds: 3));
    expect(finished, 0);
    expect(find.text('Esterno, notte. Un vicolo.'), findsOneWidget, reason: 'la didascalia è scritta per intero');
    await tester.pumpAndSettle();
    expect(finished, 1);
  });

  testWidgets('il tamburo si ferma sulla camera sorteggiata e avvisa una volta sola', (tester) async {
    var stopped = 0;
    await tester.pumpWidget(MaterialApp(
      home: Center(
        child: SizedBox(
          width: 320,
          child: RevolverCylinder(
            names: const ['Tu', 'Marco', 'Giulia', 'Luca', 'Sara'],
            finalAngle: 30,
            winnerIndex: 2,
            onStopped: () => stopped++,
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(seconds: 2));
    expect(stopped, 0);
    await tester.pumpAndSettle();
    expect(stopped, 1);
    expect(find.byType(NoirAvatar), findsNWidgets(6), reason: 'cinque nelle camere, più il sorteggiato in primo piano');
  });

  testWidgets('il tavolo serve una carta a ogni giocatore, anche a tavoli pieni', (tester) async {
    for (final seats in [3, 6, 12]) {
      var dealt = 0;
      await tester.pumpWidget(MaterialApp(
        home: Center(
          child: SizedBox(
            width: 340,
            height: 380,
            child: DealTable(
              key: ValueKey(seats),
              names: [for (var i = 0; i < seats; i++) 'Giocatore $i'],
              onDealt: () => dealt++,
            ),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 500));
      expect(dealt, 0, reason: '$seats posti');
      await tester.pumpAndSettle();
      expect(dealt, 1, reason: '$seats posti');
      expect(find.byType(NoirAvatar), findsNWidgets(seats));
      expect(tester.takeException(), isNull);
    }
  });
}
