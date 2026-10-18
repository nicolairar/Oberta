import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/l10n/app_language.dart';
import 'package:oberta/rules/game_setup.dart';
import 'package:oberta/rules/player.dart';
import 'package:oberta/rules/role.dart';
import 'package:oberta/ui/screens/game_screen.dart';
import 'package:oberta/ui/widgets/death_scene.dart';

import '../support/languages.dart';

const ada = Player(id: 'ada', name: 'Ada');
const bruno = Player(id: 'bruno', name: 'Bruno');
const carla = Player(id: 'carla', name: 'Carla');
const dino = Player(id: 'dino', name: 'Dino');

final roles = {
  ada: Role.mafioso,
  bruno: Role.detective,
  carla: Role.cittadino,
  dino: Role.cittadino,
};

Widget _launcher() => Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => GameScreen(setup: GameSetup.fromRoles(roles), random: Random(1)),
            )),
            child: const Text('PLAY'),
          ),
        ),
      ),
    );

Future<void> pumpGame(WidgetTester tester, AppLanguage language) async {
  tester.view.physicalSize = const Size(393, 852) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  await tester.pumpWidget(appIn(language, _launcher()));
  await tester.tap(find.text('PLAY'));
  await tester.pumpAndSettle();
}

/// Tocca un pulsante; se il copione è più lungo dello schermo, prima lo
/// legge fino in fondo.
Future<void> tap(WidgetTester tester, String label, {String readOn = 'KEEP READING'}) async {
  while (find.text(label).evaluate().isEmpty && find.text(readOn).evaluate().isNotEmpty) {
    await tester.tap(find.text(readOn));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

Future<void> nightTurn(WidgetTester tester, Player actor, {Player? pick}) async {
  expect(find.text('PASS THE PHONE TO'), findsOneWidget);
  expect(find.text(actor.name.toUpperCase()), findsOneWidget, reason: 'it is ${actor.name}\'s turn');
  await tap(tester, 'IT\'S ME');
  if (pick == null) {
    await tap(tester, 'PASS');
  } else {
    await tap(tester, pick.name);
    await tap(tester, 'CONFIRM');
  }
}

void main() {
  testWidgets('una partita intera in inglese: notte, scena, alba, voto, verdetto', (tester) async {
    await pumpGame(tester, AppLanguage.en);

    expect(find.text('NIGHT 1'), findsOneWidget);
    expect(find.text('THE NARRATOR SPEAKS'), findsOneWidget);
    expect(find.textContaining(RegExp(r'^(Chicago|New York|Palermo|Naples|Las Vegas), 19\d\d$')), findsOneWidget);
    expect(find.textContaining('At night the Family eliminates one person.'), findsOneWidget);
    expect(find.textContaining('Pass the phone around.'), findsOneWidget);
    expect(find.byTooltip('Leave the game'), findsOneWidget);
    await tap(tester, 'START THE NIGHT');

    await nightTurn(tester, ada, pick: carla);
    expect(find.text('Done.'), findsOneWidget);
    expect(find.text('Nobody will know what you chose.'), findsOneWidget);
    await tap(tester, 'DONE');

    await nightTurn(tester, bruno, pick: ada);
    expect(find.text('YOUR INVESTIGATION'), findsOneWidget);
    expect(find.text('ADA'), findsOneWidget);
    expect(find.text('IS WITH THE FAMILY'), findsOneWidget);
    await tap(tester, 'DONE');

    await nightTurn(tester, carla);
    await tap(tester, 'DONE');
    await nightTurn(tester, dino);
    await tap(tester, 'DONE');

    expect(find.text('Phone\non the table'), findsOneWidget);
    await tester.tap(find.text('LIGHTS DOWN'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(DeathScene), findsOneWidget);
    expect(find.text('SKIP'), findsOneWidget);
    await tester.pump(DeathScene.length + const Duration(milliseconds: 100));
    await tester.pump();
    expect(find.textContaining(RegExp(r'^(Exterior|Interior), night')), findsOneWidget,
        reason: 'la didascalia della scena è quella inglese');
    expect(find.text('CARLA'), findsOneWidget);
    expect(find.text('WON\'T SEE THE DAWN'), findsOneWidget);
    await tap(tester, 'NEXT');
    expect(find.byType(DeathScene), findsNothing);

    expect(find.text('DAWN'), findsOneWidget);
    expect(find.text('The crime page'), findsOneWidget);
    expect(find.text('Last night one person died: Carla. Their role stays secret.'), findsOneWidget);
    expect(find.textContaining('The Honest One'), findsNothing, reason: 'at night the role stays secret');
    expect(find.text('You have one minute to discuss. Then vote on who to eliminate.'), findsOneWidget);
    await tap(tester, 'OPEN THE FLOOR');

    expect(find.text('DAY 1'), findsOneWidget);
    expect(find.text('1:00'), findsOneWidget);
    expect(find.text('THE FLOOR IS OPEN'), findsOneWidget);
    expect(find.text('INNOCENT'), findsNothing, reason: 'l\'indagine non è pubblica');
    await tester.tap(find.text('+1 MIN'));
    await tester.pump();
    expect(find.text('2:00'), findsOneWidget);
    await tap(tester, 'CALL THE VOTE');

    expect(find.textContaining('You can also choose to eliminate nobody.'), findsOneWidget);
    expect(find.text('NOBODY'), findsOneWidget);
    await tap(tester, 'Ada');
    await tap(tester, 'CONDEMN');
    // The town square's film comes first; skip it to the portrait.
    if (find.text('SKIP').evaluate().isNotEmpty) {
      await tester.tap(find.text('SKIP'));
      await tester.pump();
    }
    await tester.tap(find.text('NEXT'));
    await tester.pumpAndSettle();

    expect(find.text('THE VERDICT'), findsOneWidget);
    expect(find.textContaining('SOLDIER'), findsNothing, reason: 'the card is still face down');
    await tap(tester, 'FLIP THE CARD');
    expect(find.text('THE SOLDIER'), findsOneWidget, reason: 'la carta girata, in inglese');
    expect(find.text('FAMILY'), findsOneWidget);
    expect(find.text('The card flips. Ada was… THE SOLDIER. On the Family\'s side.'), findsOneWidget);
    await tap(tester, 'THE FINALE');

    expect(find.text('THE END'), findsOneWidget);
    expect(find.text('The town\nwins'), findsOneWidget);
    expect(find.text('The town wins: the whole Family has been eliminated.'), findsOneWidget);
    expect(find.text('WHO WAS WHO'), findsOneWidget);
    expect(find.text('The Soldier'), findsOneWidget);
    expect(find.text('The Commissioner'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('BACK TO THE ALLEY'), 200);
    await tester.pumpAndSettle();
    expect(find.text('Night 1'), findsOneWidget);
    expect(find.text('Gallows, day 1'), findsOneWidget);
    expect(find.text('Still standing'), findsWidgets);
    expect(find.text('The Honest One'), findsWidgets);
    await tap(tester, 'BACK TO THE ALLEY');
    expect(find.text('PLAY'), findsOneWidget);
  });

  testWidgets('in inglese la carta del Commissioner e quella della fossa dicono chi era', (tester) async {
    await pumpGame(tester, AppLanguage.en);
    await tap(tester, 'START THE NIGHT');
    await tap(tester, 'IT\'S ME');
    expect(find.text('Who does the Family eliminate tonight?'), findsOneWidget);
    expect(find.text('YOU'), findsOneWidget, reason: 'il proprio segno sulla griglia');
    await tap(tester, 'Carla');
    await tap(tester, 'CONFIRM');
    await tap(tester, 'DONE');
    await nightTurn(tester, bruno, pick: dino);
    expect(find.text('IS INNOCENT'), findsOneWidget);
    await tap(tester, 'DONE');
    await nightTurn(tester, carla);
    await tap(tester, 'DONE');

    // Nella notte di Dino, la griglia del Commissario non si vede: ognuno la sua.
    await tap(tester, 'IT\'S ME');
    expect(find.text('INNOCENT'), findsNothing);
    expect(find.text('You have no move tonight: answer anyway, so nobody can tell who you are.'), findsOneWidget);
  });

  testWidgets('una partita cominciata in italiano resta in italiano, anche se l\'app cambia lingua',
      (tester) async {
    await pumpGame(tester, AppLanguage.it);
    expect(find.text('NOTTE 1'), findsOneWidget);
    expect(find.text('PARLA IL NARRATORE'), findsOneWidget);

    await tester.pumpWidget(appIn(AppLanguage.en, _launcher()));
    await tester.pumpAndSettle();
    expect(find.text('NOTTE 1'), findsOneWidget);
    expect(find.text('PARLA IL NARRATORE'), findsOneWidget, reason: 'anche il copione resta com\'era');
    expect(find.text('THE NARRATOR SPEAKS'), findsNothing);

    await tap(tester, 'COMINCIA LA NOTTE', readOn: 'CONTINUA A LEGGERE');
    expect(find.text('PASSA IL TELEFONO A'), findsOneWidget);
    expect(find.text('PASS THE PHONE TO'), findsNothing);
    await tester.tap(find.text('SONO IO'));
    await tester.pumpAndSettle();
    expect(find.text('Chi eliminate stanotte?'), findsOneWidget);
  });
}
