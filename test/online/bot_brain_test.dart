import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/online/game/bot_brain.dart';
import 'package:oberta/rules/game_engine.dart';
import 'package:oberta/rules/intent.dart';
import 'package:oberta/rules/player_view.dart';
import 'package:oberta/rules/role.dart';

import '../support/random_game.dart';

void main() {
  test('i bot fanno solo mosse permesse, la famiglia non colpisce i suoi né li vota', () {
    final random = Random(21);
    var moves = 0;
    for (var game = 0; game < 120; game++) {
      final engine = randomEngine(random);
      final brain = BotBrain(Random(game));
      for (var step = 0; step < 400 && engine.phase != GamePhase.ended; step++) {
        final waiting = engine.phase == GamePhase.night
            ? engine.pendingNightPlayers
            : [for (final p in engine.alivePlayers) if (!engine.dayVotes.containsKey(p)) p];
        if (waiting.isEmpty) {
          engine.phase == GamePhase.night ? engine.resolveNight() : engine.closeDayVote();
          continue;
        }
        final seat = waiting.first.id;
        final view = engine.viewFor(seat);
        final intent = brain.decide(view)!;
        final target = switch (intent) {
          NightAction(:final target) || MafiaVote(:final target) || DayVote(:final target) => target,
          Pass() || RevealMayor() || Pacify() || Link() || Fire() || Shoot() => null,
        };
        final avoidable = view.action!.targets.any((p) => !view.teammates.contains(p));
        if (view.team == Team.mafia && target != null && avoidable &&
            (view.action!.type == ActionType.mafiaVote || view.action!.type == ActionType.dayVote)) {
          expect(view.teammates.map((p) => p.id), isNot(contains(target)), reason: 'gioco $game: ${intent.toJson()}');
        }
        expect(engine.apply(intent).accepted, isTrue, reason: 'gioco $game: ${intent.toJson()}');
        moves++;
      }
    }
    expect(moves, greaterThan(2000));
  });

  test('i nomi dei bot', () {
    expect([for (var i = 0; i < 3; i++) botName(i)], ['bot.alfa', 'bot.bravo', 'bot.charlie']);
    expect(botName(13), 'bot.november');
  });
}
