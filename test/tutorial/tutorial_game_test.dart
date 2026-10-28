import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/rules/game_engine.dart';
import 'package:oberta/rules/role.dart';
import 'package:oberta/tutorial/tutorial_game.dart';

void main() {
  test('the scripted tutorial always tells the same story and the city wins', () {
    for (var run = 0; run < 3; run++) {
      final game = TutorialGame();
      game
        ..next()
        ..next();
      expect(game.beat, TutorialBeat.night);
      game.investigate(TutorialGame.vito);
      expect(game.finding!.team, Team.mafia);
      game.next();
      expect(game.dawn!.attacks.single.target, TutorialGame.bruno);
      expect(game.engine.isAlive(TutorialGame.bruno), isFalse);
      game
        ..next()
        ..speak()
        ..vote(TutorialGame.vito);
      expect(game.verdict!.condemned, TutorialGame.vito);
      expect(game.verdict!.role, Role.mafioso);
      game.next();
      expect(game.beat, TutorialBeat.night);
      expect(game.round, 2);
      game.investigate(TutorialGame.carmela);
      expect(game.finding!.team, Team.mafia);
      game.next();
      expect(game.dawn!.attacks.single.outcome, AttackOutcome.healed);
      expect(game.engine.isAlive(game.you), isTrue);
      game
        ..next()
        ..speak()
        ..vote(TutorialGame.carmela);
      expect(game.verdict!.winner, Team.citizens);
      game
        ..next()
        ..next();
      expect(game.beat, TutorialBeat.ready);
    }
  });

  test('off-script moves are refused', () {
    final game = TutorialGame()
      ..next()
      ..next();
    expect(() => game.investigate(TutorialGame.dora), throwsStateError);
  });
}
