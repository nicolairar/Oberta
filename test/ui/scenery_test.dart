import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/main.dart';
import 'package:oberta/narration/death_story.dart';
import 'package:oberta/narration/italian_pack.dart';
import 'package:oberta/ui/widgets/city_backdrop.dart';
import 'package:oberta/ui/widgets/deal_table.dart';
import 'package:oberta/ui/widgets/death_scene.dart';
import 'package:oberta/ui/widgets/noir_avatar.dart';
import 'package:oberta/ui/widgets/revolver_cylinder.dart';
import 'package:oberta/ui/widgets/scene_scaffold.dart';

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

    await tester.pumpWidget(const ObertaApp());
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(find.text('OBERTÀ'), findsOneWidget);
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
    final staged = {
      for (final method in italianPack.methods) deathActFor(method.id),
      deathActFor(DeathStory.sniperId),
      deathActFor(DeathStory.rescueId),
      deathActFor(DeathStory.luckyId),
    };
    expect(staged, DeathAct.values.toSet(), reason: 'nessuna coreografia resta senza copione');
    expect(deathActFor(DeathStory.sniperId), DeathAct.sniper);
    expect(deathActFor(DeathStory.rescueId), DeathAct.rescue);
    expect(deathActFor(DeathStory.luckyId), DeathAct.lucky);
    expect(DeathAct.rescue.survives, isTrue);
    expect(DeathAct.lucky.survives, isTrue);
    expect(DeathAct.sniper.survives, isFalse);
    expect(deathActFor('pugnale'), DeathAct.knife);
    expect(deathActFor('violino'), DeathAct.burst);
    expect(deathActFor('azione-senza-scena'), DeathAct.knife);
  });

  testWidgets('ogni coreografia si disegna dal primo all\'ultimo fotogramma', (tester) async {
    final endings = ['', ...italianPack.epilogues.map((piece) => piece.id)];
    var take = 0;
    for (final act in DeathAct.values) {
      for (final hat in AvatarHead.values) {
        final epilogue = endings[take++ % endings.length];
        for (var frame = 0; frame <= 50; frame++) {
          await tester.pumpWidget(CustomPaint(
            size: const Size(393, 852),
            painter: DeathScenePainter(t: frame / 50, act: act, victimHat: hat, epilogue: epilogue),
          ));
          expect(tester.takeException(), isNull, reason: '$act $hat $epilogue fotogramma $frame');
        }
      }
    }
  });

  test('il film rallenta sul colpo, e il suo orologio si può leggere al contrario', () {
    expect(filmTime(0), 0);
    expect(filmTime(1), 1);
    var previous = 0.0;
    for (var i = 1; i <= 200; i++) {
      final now = filmTime(i / 200);
      expect(now, greaterThan(previous), reason: 'il film non torna mai indietro');
      expect(filmClock(now), closeTo(i / 200, 1e-9));
      previous = now;
    }
    final strike = filmClock(DeathScenePainter.strike);
    final entrance = filmTime(0.10) - filmTime(0.05);
    final slowMotion = filmTime(strike + 0.025) - filmTime(strike - 0.025);
    expect(slowMotion, lessThan(entrance * 0.6), reason: 'sul colpo il tempo si dilata');
  });

  testWidgets('la scena del delitto si ferma sul ritratto e aspetta il tavolo', (tester) async {
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
    expect(find.text('AVANTI'), findsNothing);
    expect(find.text('SALTA'), findsOneWidget);

    await tester.pump(DeathScene.length);
    await tester.pump();
    expect(finished, 0, reason: 'finito il film nessuno viene portato via dal ritratto');
    expect(find.text('MARCO'), findsOneWidget);
    expect(find.text('NON VEDRÀ L\'ALBA'), findsOneWidget);
    expect(find.text('SALTA'), findsNothing);

    await tester.tap(find.text('AVANTI'));
    await tester.tap(find.text('AVANTI'));
    expect(finished, 1);
  });

  testWidgets('chi salta la scena arriva al ritratto, non oltre', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    var finished = 0;
    await tester.pumpWidget(MaterialApp(
      home: DeathScene(
        act: DeathAct.rescue,
        victimName: 'Giulia',
        caption: 'Esterno, notte. Il porto.',
        onFinished: () => finished++,
      ),
    ));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('SALTA'));
    await tester.pump();

    expect(finished, 0);
    expect(find.text('GIULIA'), findsOneWidget);
    expect(find.text('VEDRÀ L\'ALBA'), findsOneWidget, reason: 'il Dottore è arrivato in tempo');
    expect(find.text('†'), findsNothing);
    await tester.tap(find.text('AVANTI'));
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

  testWidgets('a metà scena la vittima si accorge di qualcosa, e arriva il suo primo piano', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(MaterialApp(
      home: DeathScene(act: DeathAct.gun, victimName: 'Giulia', caption: 'Esterno, notte.', onFinished: () {}),
    ));
    Duration at(double t) => Duration(milliseconds: (filmClock(t) * DeathScene.length.inMilliseconds).round());

    await tester.pump(at(0.30));
    expect(find.text('?!'), findsNothing, reason: 'all\'inizio la vittima cammina tranquilla');
    await tester.pump(at(0.43) - at(0.30));
    expect(find.text('?!'), findsOneWidget);
    expect(find.byType(NoirAvatar), findsOneWidget, reason: 'solo la faccia della vittima');
    await tester.pump(at(0.60) - at(0.43));
    expect(find.text('?!'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
