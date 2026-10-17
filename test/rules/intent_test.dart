import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/rules/game_engine.dart';
import 'package:oberta/rules/game_setup.dart';
import 'package:oberta/rules/intent.dart';
import 'package:oberta/rules/role.dart';

import 'game_engine_test.dart'
    show anna, boss, bruno, detective, doctor, fullTable, picciotto, reporter, sniper, smallTable;

IntentError? errorOf(IntentResult result) => switch (result) {
      IntentRejected(:final error) => error,
      IntentAccepted() => null,
    };

/// Tutti passano, tranne chi è in [moves].
void passTheRest(GameEngine engine, [Map<String, PlayerIntent> moves = const {}]) {
  for (final player in engine.pendingNightPlayers) {
    expect(engine.apply(moves[player.id] ?? Pass(player.id)).accepted, isTrue);
  }
}

void main() {
  group('JSON', () {
    test('ogni intenzione torna uguale dal JSON', () {
      const intents = <PlayerIntent>[NightAction('s1', 's2'), MafiaVote('s3', 's4'), DayVote('s5', 's6'), Pass('s7')];
      for (final intent in intents) {
        final json = jsonDecode(jsonEncode(intent.toJson())) as Map<String, Object?>;
        expect(PlayerIntent.fromJson(json), intent);
      }
      expect(() => PlayerIntent.fromJson({'type': 'teleport', 'seat': 's1'}), throwsFormatException);
    });

    test('le risposte tornano uguali dal JSON', () {
      final engine = fullTable();
      final result = engine.apply(NightAction(detective.id, boss.id));
      final json = jsonDecode(jsonEncode(result.toJson())) as Map<String, Object?>;
      expect(json, {
        'ok': true,
        'finding': {'seat': 'boss', 'team': 'mafia'},
      });
      final back = IntentResult.fromJson(json) as IntentAccepted;
      expect(back.finding!.subject.id, 'boss');
      expect(back.finding!.team, Team.mafia);

      final rejected = engine.apply(NightAction(detective.id, anna.id));
      final again = IntentResult.fromJson(jsonDecode(jsonEncode(rejected.toJson())) as Map<String, Object?>);
      expect(errorOf(again), IntentError.alreadyActed);
    });

    test('i comandi del registro tornano uguali dal JSON', () {
      const commands = <GameCommand>[
        IntentCommand(Pass('s1')),
        ResolveNightCommand(),
        CloseDayVoteCommand(),
        LynchCommand('s2'),
        LynchCommand(null),
        LeaveTownCommand('s3'),
      ];
      for (final command in commands) {
        expect(GameCommand.fromJson(jsonDecode(jsonEncode(command.toJson())) as Map<String, Object?>), command);
      }
    });
  });

  group('validazione', () {
    test('un posto che non gioca viene rifiutato', () {
      final engine = fullTable();
      expect(errorOf(engine.apply(const Pass('nessuno'))), IntentError.unknownSeat);
    });

    test('il narratore non gioca', () {
      final engine = GameEngine(
        GameSetup.fromRoles({boss: Role.mafioso, anna: Role.cittadino, bruno: Role.cittadino}, narrator: doctor),
      );
      expect(errorOf(engine.apply(Pass(doctor.id))), IntentError.unknownSeat);
    });

    test('un morto non agisce', () {
      final engine = fullTable();
      passTheRest(engine, {boss.id: MafiaVote(boss.id, anna.id), picciotto.id: MafiaVote(picciotto.id, anna.id)});
      engine.resolveNight();
      expect(engine.isAlive(anna), isFalse);
      expect(errorOf(engine.apply(DayVote(anna.id, boss.id))), IntentError.deadSeat);
    });

    test('ogni mossa a suo tempo', () {
      final engine = fullTable();
      expect(errorOf(engine.apply(DayVote(anna.id, boss.id))), IntentError.wrongPhase);
      passTheRest(engine);
      engine.resolveNight();
      expect(errorOf(engine.apply(NightAction(doctor.id, anna.id))), IntentError.wrongPhase);
      expect(errorOf(engine.apply(MafiaVote(boss.id, anna.id))), IntentError.wrongPhase);
    });

    test('una mossa a notte', () {
      final engine = fullTable();
      expect(engine.apply(NightAction(doctor.id, anna.id)).accepted, isTrue);
      expect(errorOf(engine.apply(NightAction(doctor.id, bruno.id))), IntentError.alreadyActed);
      expect(errorOf(engine.apply(Pass(doctor.id))), IntentError.alreadyActed);
    });

    test('ognuno fa la mossa del suo ruolo', () {
      final engine = fullTable();
      expect(errorOf(engine.apply(MafiaVote(detective.id, boss.id))), IntentError.notYourAction);
      expect(errorOf(engine.apply(NightAction(boss.id, anna.id))), IntentError.notYourAction);
      expect(errorOf(engine.apply(MafiaVote(anna.id, bruno.id))), IntentError.notYourAction);
    });

    test('il bersaglio deve essere tra quelli permessi', () {
      final engine = fullTable();
      expect(errorOf(engine.apply(NightAction(detective.id, detective.id))), IntentError.targetNotAllowed);
      expect(errorOf(engine.apply(NightAction(sniper.id, 'nessuno'))), IntentError.targetNotAllowed);
      expect(engine.apply(NightAction(doctor.id, anna.id)).accepted, isTrue);
      passTheRest(engine);
      engine.resolveNight();
      engine.lynch(null);
      // Non due notti di fila sulla stessa persona.
      expect(errorOf(engine.apply(NightAction(doctor.id, anna.id))), IntentError.targetNotAllowed);
    });

    test('di giorno non si vota per sé né per un morto', () {
      final engine = fullTable();
      passTheRest(engine, {boss.id: MafiaVote(boss.id, anna.id), picciotto.id: MafiaVote(picciotto.id, anna.id)});
      engine.resolveNight();
      expect(errorOf(engine.apply(DayVote(bruno.id, bruno.id))), IntentError.targetNotAllowed);
      expect(errorOf(engine.apply(DayVote(bruno.id, anna.id))), IntentError.targetNotAllowed);
    });

    test('a partita finita non si muove più nulla', () {
      final engine = smallTable();
      passTheRest(engine);
      engine.resolveNight();
      engine.lynch(boss);
      expect(engine.phase, GamePhase.ended);
      expect(errorOf(engine.apply(Pass(anna.id))), IntentError.gameOver);
    });

    test('una mossa rifiutata non cambia la partita', () {
      final engine = GameEngine(fullTable().setup, seed: 9);
      final before = jsonEncode(engine.snapshot().toJson());
      engine
        ..apply(MafiaVote(detective.id, boss.id))
        ..apply(NightAction(detective.id, detective.id))
        ..apply(DayVote(anna.id, boss.id))
        ..apply(const Pass('nessuno'));
      expect(jsonEncode(engine.snapshot().toJson()), before);
    });
  });

  group('effetti', () {
    test('l\'indagine risponde solo a chi l\'ha fatta', () {
      final engine = fullTable();
      final result = engine.apply(NightAction(detective.id, boss.id)) as IntentAccepted;
      expect(result.finding!.team, Team.mafia);
      expect((engine.apply(NightAction(doctor.id, anna.id)) as IntentAccepted).finding, isNull);
    });

    test('le intenzioni e le chiamate dirette danno la stessa partita', () {
      final direct = GameEngine(fullTable().setup, seed: 4);
      final viaIntents = GameEngine(fullTable().setup, seed: 4);
      final choices = {boss: anna, picciotto: bruno, doctor: anna, detective: boss, reporter: picciotto};
      for (final player in direct.alivePlayers) {
        direct.submitNightChoice(player, choices[player]);
      }
      passTheRest(viaIntents, {
        boss.id: MafiaVote(boss.id, anna.id),
        picciotto.id: MafiaVote(picciotto.id, bruno.id),
        doctor.id: NightAction(doctor.id, anna.id),
        detective.id: NightAction(detective.id, boss.id),
        reporter.id: NightAction(reporter.id, picciotto.id),
      });
      expect(viaIntents.resolveNight().victims, direct.resolveNight().victims);
      expect(jsonEncode(viaIntents.snapshot().toJson()), jsonEncode(direct.snapshot().toJson()));
    });
  });

  group('voto della piazza', () {
    GameEngine dayOfFullTable() {
      final engine = fullTable();
      passTheRest(engine);
      engine.resolveNight();
      return engine;
    }

    test('il più votato viene condannato e il suo ruolo diventa pubblico', () {
      final engine = dayOfFullTable();
      engine
        ..apply(DayVote(anna.id, boss.id))
        ..apply(DayVote(bruno.id, boss.id))
        ..apply(DayVote(boss.id, anna.id))
        ..apply(Pass(doctor.id));
      expect(engine.pendingDayVoters, isNot(contains(anna)));
      final report = engine.closeDayVote();
      expect(report.condemned, boss);
      expect(report.role, Role.mafioso);
      expect(engine.knowledgeOf(null, boss).role, Role.mafioso);
      expect(engine.phase, GamePhase.night);
      expect(engine.dayVotes, isEmpty);
    });

    test('il voto si può cambiare: conta l\'ultimo', () {
      final engine = dayOfFullTable();
      engine
        ..apply(DayVote(anna.id, boss.id))
        ..apply(DayVote(bruno.id, boss.id))
        ..apply(DayVote(anna.id, picciotto.id))
        ..apply(DayVote(bruno.id, picciotto.id));
      expect(engine.closeDayVote().condemned, picciotto);
    });

    test('con un pareggio non si condanna nessuno', () {
      final engine = dayOfFullTable();
      engine
        ..apply(DayVote(anna.id, boss.id))
        ..apply(DayVote(bruno.id, picciotto.id));
      final report = engine.closeDayVote();
      expect(report.condemned, isNull);
      expect(engine.alivePlayers, hasLength(8));
      expect(engine.round, 2);
    });

    test('se nessuno vota non si condanna nessuno', () {
      final engine = dayOfFullTable();
      expect(engine.closeDayVote().condemned, isNull);
    });
  });
}
