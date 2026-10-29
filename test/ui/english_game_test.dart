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
import '../support/local_game.dart' show curtainName, tapSeat;

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
  expect(curtainName(tester), contains(actor.name.toUpperCase()), reason: 'it is ${actor.name}\'s turn');
  await tap(tester, 'IT\'S ME');
  if (pick == null) {
    await tap(tester, 'PASS');
  } else {
    await tapSeat(tester, pick);
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
    expect(find.text('Nobody will know what you chose.'), findsOneWidget);
    expect(find.text('Pass the phone to the next one.'), findsOneWidget);
    await tap(tester, 'DONE');

    await nightTurn(tester, bruno, pick: ada);
    expect(find.text('YOUR INVESTIGATION'), findsOneWidget);
    expect(find.text('1 ADA'), findsOneWidget);
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
    expect(find.text("Among last night's dead: Carla. Their role stays secret."), findsOneWidget);
    expect(find.textContaining('Honest Citizen'), findsNothing, reason: 'at night the role stays secret');
    expect(find.text('You have one minute to discuss. Then vote on who to eliminate.'), findsOneWidget);
    await tap(tester, 'OPEN THE FLOOR');

    expect(find.text('DAY 1'), findsOneWidget);
    expect(find.text('1:00'), findsOneWidget);
    expect(find.text('Talk it over out loud. Then you vote.'), findsOneWidget);
    expect(find.text('family'), findsNothing, reason: 'l\'indagine non è pubblica');
    await tester.tap(find.text('+1 MIN'));
    await tester.pump();
    expect(find.text('2:00'), findsOneWidget);
    await tap(tester, 'CALL THE VOTE');

    expect(find.textContaining('You can also choose to eliminate nobody.'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('local.voterTurn'))).data, '1 Ada votes: tap who to condemn.');
    await tap(tester, 'I ABSTAIN');
    await tapSeat(tester, ada);
    await tapSeat(tester, ada);
    // No film: everyone saw the vote. The seat plays the lynch in place.
    await tester.pumpAndSettle();

    expect(find.text('THE VERDICT'), findsOneWidget);
    expect(find.text('LYNCHED'), findsOneWidget);
    expect(find.text('The card flips. Ada was… THE SOLDIER. On the Family\'s side.'), findsOneWidget);
    await tap(tester, 'THE FINALE');

    expect(find.text('THE END'), findsOneWidget);
    expect(find.text('The town\nwins'), findsOneWidget);
    expect(find.text('The town wins: the whole Family has been eliminated.'), findsOneWidget);
    expect(find.text('WHO WAS WHO'), findsOneWidget);
    expect(find.text('Soldier'), findsOneWidget);
    expect(find.text('Detective'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('BACK TO THE ALLEY'), 200);
    await tester.pumpAndSettle();
    expect(find.text('Night 1'), findsOneWidget);
    expect(find.text('Gallows, day 1'), findsOneWidget);
    expect(find.text('Still standing'), findsWidgets);
    expect(find.text('Honest Citizen'), findsWidgets);
    await tap(tester, 'BACK TO THE ALLEY');
    expect(find.text('PLAY'), findsOneWidget);
  });

  testWidgets('in inglese la carta del Commissioner e quella della fossa dicono chi era', (tester) async {
    await pumpGame(tester, AppLanguage.en);
    await tap(tester, 'START THE NIGHT');
    await tap(tester, 'IT\'S ME');
    expect(find.text('Who does the Family eliminate tonight?'), findsOneWidget);
    await tapSeat(tester, carla);
    await tap(tester, 'CONFIRM');
    await tap(tester, 'DONE');
    await nightTurn(tester, bruno, pick: dino);
    expect(find.text('IS INNOCENT'), findsOneWidget);
    await tap(tester, 'DONE');
    await tap(tester, 'IT\'S ME');
    expect(find.text('clean'), findsNothing, reason: 'Carla non sa cosa ha scoperto il Commissario');
    await tap(tester, 'PASS');
    await tap(tester, 'DONE');
    await tap(tester, 'IT\'S ME');
    await tap(tester, 'PASS');
    await tap(tester, 'DONE');
    await tester.tap(find.text('LIGHTS DOWN'));
    await tester.pump(const Duration(milliseconds: 500));
    await tap(tester, 'SKIP');
    await tap(tester, 'NEXT');
    await tap(tester, 'OPEN THE FLOOR');
    await tap(tester, 'CALL THE VOTE');
    for (var i = 0; i < 3; i++) {
      await tap(tester, 'I ABSTAIN');
    }
    await tap(tester, 'CONTINUE');
    await tap(tester, 'START THE NIGHT');
    await nightTurn(tester, ada);
    await tap(tester, 'DONE');
    await tap(tester, 'IT\'S ME');
    expect(find.text('clean'), findsOneWidget, reason: 'il Commissario ritrova la sua indagine sotto il nome');
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
