import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:omerta/rules/game_engine.dart';
import 'package:omerta/rules/game_settings.dart';
import 'package:omerta/rules/game_setup.dart';
import 'package:omerta/rules/player.dart';
import 'package:omerta/rules/role.dart';

const boss = Player(id: 'boss', name: 'Boss');
const picciotto = Player(id: 'picciotto', name: 'Picciotto');
const detective = Player(id: 'detective', name: 'Commissario');
const doctor = Player(id: 'doctor', name: 'Dottore');
const sniper = Player(id: 'sniper', name: 'Cecchino');
const reporter = Player(id: 'reporter', name: 'Cronista');
const anna = Player(id: 'anna', name: 'Anna');
const bruno = Player(id: 'bruno', name: 'Bruno');

/// Un tavolo da otto con tutti i ruoli, in ordine di posto.
GameEngine fullTable({TieBreak tieBreak = TieBreak.random, int seed = 1}) {
  return GameEngine(
    GameSetup.fromRoles({
      boss: Role.mafioso,
      picciotto: Role.mafioso,
      detective: Role.detective,
      doctor: Role.medico,
      sniper: Role.cecchino,
      reporter: Role.giornalista,
      anna: Role.cittadino,
      bruno: Role.cittadino,
    }),
    settings: GameSettings(mafiaTieBreak: tieBreak),
    random: Random(seed),
  );
}

GameEngine smallTable() {
  return GameEngine(GameSetup.fromRoles({
    boss: Role.mafioso,
    detective: Role.detective,
    anna: Role.cittadino,
    bruno: Role.cittadino,
  }));
}

/// Gioca una notte: chi non compare in [choices] passa.
DawnReport playNight(GameEngine engine, [Map<Player, Player?> choices = const {}]) {
  for (final player in engine.alivePlayers) {
    engine.submitNightChoice(player, choices[player]);
  }
  return engine.resolveNight();
}

void main() {
  group('notte', () {
    test('la vittima della mafia muore e il suo ruolo resta segreto', () {
      final engine = fullTable();
      final report = playNight(engine, {boss: anna, picciotto: anna});

      expect(report.victims, [anna]);
      expect(engine.isAlive(anna), isFalse);
      expect(engine.phase, GamePhase.day);
      expect(engine.knowledgeOf(null, anna).isEmpty, isTrue);
      expect(engine.knowledgeOf(bruno, anna).isEmpty, isTrue);
    });

    test('se tutti passano non muore nessuno', () {
      final engine = fullTable();
      expect(playNight(engine).victims, isEmpty);
      expect(engine.alivePlayers, hasLength(8));
    });

    test('il Dottore salva chi protegge', () {
      final engine = fullTable();
      final report = playNight(engine, {boss: anna, picciotto: anna, doctor: anna});
      expect(report.victims, isEmpty);
      expect(engine.isAlive(anna), isTrue);
    });

    test('il Dottore può proteggere se stesso', () {
      final engine = fullTable();
      final report = playNight(engine, {boss: doctor, picciotto: doctor, doctor: doctor});
      expect(report.victims, isEmpty);
    });

    test('il Dottore non può proteggere la stessa persona due notti di fila', () {
      final engine = fullTable();
      playNight(engine, {doctor: anna});
      engine.lynch(null);

      expect(engine.taskFor(doctor).targets, isNot(contains(anna)));
      expect(() => engine.submitNightChoice(doctor, anna), throwsArgumentError);

      playNight(engine, {doctor: bruno});
      engine.lynch(null);
      expect(engine.taskFor(doctor).targets, contains(anna));
    });

    test('la famiglia può colpire anche uno dei suoi, ma nessuno sé stesso', () {
      final engine = fullTable();
      expect(engine.taskFor(boss).targets, contains(picciotto));
      expect(engine.taskFor(boss).targets, isNot(contains(boss)));
      expect(() => engine.submitNightChoice(boss, boss), throwsArgumentError);

      final report = playNight(engine, {boss: picciotto});
      expect(report.victims, [picciotto]);
      expect(engine.isAlive(picciotto), isFalse);
    });

    test('ogni agguato finisce nel rapporto così com\'è andato', () {
      final engine = fullTable();
      final report = playNight(engine, {boss: anna, picciotto: anna, doctor: anna, sniper: bruno});

      expect(report.victims, [bruno]);
      expect(report.attacks.map((attack) => attack.target), [anna, bruno]);
      final saved = report.attacks.first;
      expect(saved.source, AttackSource.family);
      expect(saved.outcome, AttackOutcome.healed);
      expect(saved.isFatal, isFalse);
      final shot = report.attacks.last;
      expect(shot.source, AttackSource.sniper);
      expect(shot.isFatal, isTrue);
    });

    test('chi finisce nel mirino di tutti e due conta una volta, per la famiglia', () {
      final engine = fullTable();
      final report = playNight(engine, {boss: anna, picciotto: anna, sniper: anna});
      expect(report.attacks, hasLength(1));
      expect(report.attacks.single.source, AttackSource.family);
      expect(report.victims, [anna]);
    });

    test('una notte senza agguati non lascia niente da mettere in scena', () {
      expect(playNight(fullTable()).attacks, isEmpty);
    });

    test('chi muore stanotte ha fatto in tempo ad agire', () {
      final engine = fullTable();
      final report = playNight(engine, {boss: doctor, picciotto: doctor, doctor: anna, sniper: anna});
      expect(report.victims, [doctor]);
      expect(engine.isAlive(anna), isTrue, reason: 'la protezione vale anche se il Dottore muore');
    });

    test('ognuno sceglie una volta sola e solo se è vivo', () {
      final engine = fullTable();
      engine.submitNightChoice(anna, bruno);
      expect(() => engine.submitNightChoice(anna, boss), throwsStateError);

      for (final player in engine.pendingNightPlayers) {
        engine.submitNightChoice(player, player == boss || player == picciotto ? bruno : null);
      }
      engine.resolveNight();
      engine.lynch(null);
      expect(() => engine.submitNightChoice(bruno, anna), throwsStateError);
    });

    test('la notte non si chiude finché manca qualcuno', () {
      final engine = fullTable();
      engine.submitNightChoice(boss, anna);
      expect(engine.nightComplete, isFalse);
      expect(engine.resolveNight, throwsStateError);
    });
  });

  group('voto della mafia', () {
    test('vince la maggioranza', () {
      final engine = GameEngine(GameSetup.fromRoles({
        boss: Role.mafioso,
        picciotto: Role.mafioso,
        sniper: Role.mafioso,
        anna: Role.cittadino,
        bruno: Role.cittadino,
        detective: Role.cittadino,
        doctor: Role.cittadino,
        reporter: Role.cittadino,
      }));
      final report = playNight(engine, {boss: anna, picciotto: bruno, sniper: bruno});
      expect(report.victims, [bruno]);
    });

    test('chi si astiene non conta', () {
      final engine = fullTable();
      expect(playNight(engine, {boss: null, picciotto: anna}).victims, [anna]);
    });

    test('parità con "nessuno muore"', () {
      final engine = fullTable(tieBreak: TieBreak.nobody);
      expect(playNight(engine, {boss: anna, picciotto: bruno}).victims, isEmpty);
    });

    test('parità con sorteggio: muore uno dei due votati', () {
      final victims = <Player>{};
      for (var seed = 0; seed < 30; seed++) {
        final report = playNight(fullTable(seed: seed), {boss: anna, picciotto: bruno});
        expect(report.victims, hasLength(1));
        victims.add(report.victims.single);
      }
      expect(victims, {anna, bruno});
    });

    test('parità con il capo: decide il primo mafioso', () {
      for (var seed = 0; seed < 10; seed++) {
        final engine = fullTable(tieBreak: TieBreak.boss, seed: seed);
        expect(playNight(engine, {boss: anna, picciotto: bruno}).victims, [anna]);
      }
    });
  });

  group('ruoli speciali', () {
    test('il Commissario scopre la fazione, e la scopre solo lui', () {
      final engine = fullTable();
      final finding = engine.submitNightChoice(detective, boss)!;
      expect(finding.subject, boss);
      expect(finding.team, Team.mafia);

      expect(engine.knowledgeOf(detective, boss).team, Team.mafia);
      expect(engine.knowledgeOf(detective, boss).role, isNull, reason: 'sa la fazione, non il ruolo');
      expect(engine.knowledgeOf(anna, boss).isEmpty, isTrue);
      expect(engine.knowledgeOf(null, boss).isEmpty, isTrue);
    });

    test('indagare su un onesto lo scagiona', () {
      final engine = fullTable();
      expect(engine.submitNightChoice(detective, doctor)!.team, Team.citizens);
    });

    test('le altre mosse non danno nessuna risposta', () {
      final engine = fullTable();
      expect(engine.submitNightChoice(boss, anna), isNull);
      expect(engine.submitNightChoice(doctor, anna), isNull);
      expect(engine.submitNightChoice(anna, bruno), isNull);
    });

    test('il Cecchino ha un colpo solo', () {
      final engine = fullTable();
      expect(engine.taskFor(sniper).kind, NightTaskKind.snipe);
      expect(playNight(engine, {sniper: picciotto}).victims, [picciotto]);
      engine.lynch(null);

      expect(engine.taskFor(sniper).kind, NightTaskKind.decoy);
      expect(playNight(engine, {sniper: boss}).victims, isEmpty);
    });

    test('se il Cecchino passa, il colpo gli resta', () {
      final engine = fullTable();
      playNight(engine);
      engine.lynch(null);
      expect(engine.taskFor(sniper).kind, NightTaskKind.snipe);
    });

    test('il Dottore ferma anche il Cecchino', () {
      final engine = fullTable();
      expect(playNight(engine, {sniper: anna, doctor: anna}).victims, isEmpty);
    });

    test('mafia e Cecchino possono fare due morti nella stessa notte', () {
      final engine = fullTable();
      final report = playNight(engine, {boss: anna, picciotto: anna, sniper: bruno});
      expect(report.victims, [anna, bruno]);
    });

    test('lo scoop del Cronista diventa pubblico all\'alba', () {
      final engine = fullTable();
      final report = playNight(engine, {reporter: boss});
      expect(report.scoop!.subject, boss);
      expect(report.scoop!.team, Team.mafia);
      expect(engine.knowledgeOf(null, boss).team, Team.mafia);
      expect(engine.knowledgeOf(anna, boss).role, isNull);

      engine.lynch(null);
      expect(engine.taskFor(reporter).kind, NightTaskKind.decoy);
    });

    test('se il Cronista muore quella notte, lo scoop non esce', () {
      final engine = fullTable();
      final report = playNight(engine, {reporter: boss, boss: reporter, picciotto: reporter});
      expect(report.victims, [reporter]);
      expect(report.scoop, isNull);
      expect(engine.knowledgeOf(null, boss).isEmpty, isTrue);
    });
  });

  group('chi sa cosa', () {
    test('ognuno conosce il proprio ruolo', () {
      final engine = fullTable();
      expect(engine.knowledgeOf(doctor, doctor).role, Role.medico);
      expect(engine.knowledgeOf(anna, anna).role, Role.cittadino);
    });

    test('i mafiosi si conoscono tra loro, gli altri no', () {
      final engine = fullTable();
      expect(engine.knowledgeOf(boss, picciotto).role, Role.mafioso);
      expect(engine.knowledgeOf(picciotto, boss).role, Role.mafioso);
      expect(engine.knowledgeOf(anna, boss).isEmpty, isTrue);
      expect(engine.knowledgeOf(boss, detective).isEmpty, isTrue);
    });

    test('all\'inizio niente è pubblico', () {
      final engine = fullTable();
      for (final player in engine.alivePlayers) {
        expect(engine.knowledgeOf(null, player).isEmpty, isTrue, reason: player.name);
      }
    });
  });

  group('giorno', () {
    test('il linciaggio rivela il ruolo a tutti e porta alla notte dopo', () {
      final engine = fullTable();
      playNight(engine);
      final report = engine.lynch(doctor);

      expect(report.condemned, doctor);
      expect(report.role, Role.medico);
      expect(report.winner, isNull);
      expect(engine.isAlive(doctor), isFalse);
      expect(engine.knowledgeOf(null, doctor).role, Role.medico);
      expect(engine.phase, GamePhase.night);
      expect(engine.round, 2);
    });

    test('la piazza può non condannare nessuno', () {
      final engine = fullTable();
      playNight(engine);
      final report = engine.lynch(null);
      expect(report.condemned, isNull);
      expect(report.role, isNull);
      expect(engine.alivePlayers, hasLength(8));
      expect(engine.round, 2);
    });

    test('non si lincia di notte, né chi è già morto', () {
      final engine = fullTable();
      expect(() => engine.lynch(anna), throwsStateError);
      playNight(engine, {boss: anna, picciotto: anna});
      expect(() => engine.lynch(anna), throwsArgumentError);
    });

    test('di giorno non si fanno mosse notturne', () {
      final engine = fullTable();
      playNight(engine);
      expect(() => engine.submitNightChoice(boss, anna), throwsStateError);
    });
  });

  group('vittoria', () {
    test('gli onesti vincono quando cade l\'ultimo mafioso', () {
      final engine = smallTable();
      playNight(engine);
      final report = engine.lynch(boss);
      expect(report.winner, Team.citizens);
      expect(engine.winner, Team.citizens);
      expect(engine.phase, GamePhase.ended);
    });

    test('la famiglia vince quando non può più essere messa in minoranza', () {
      final engine = smallTable();
      playNight(engine, {boss: anna});
      expect(engine.winner, isNull, reason: 'uno contro due: si gioca ancora');

      final report = engine.lynch(bruno);
      expect(report.winner, Team.mafia);
      expect(engine.phase, GamePhase.ended);
    });

    test('la famiglia può vincere anche all\'alba', () {
      final engine = GameEngine(GameSetup.fromRoles({
        boss: Role.mafioso,
        anna: Role.cittadino,
        bruno: Role.cittadino,
      }));
      final report = playNight(engine, {boss: anna});
      expect(report.winner, Team.mafia);
      expect(engine.phase, GamePhase.ended);
    });

    test('a partita finita non si gioca più', () {
      final engine = smallTable();
      playNight(engine);
      engine.lynch(boss);
      expect(() => engine.taskFor(anna), throwsStateError);
      expect(() => engine.lynch(anna), throwsStateError);
    });
  });

  group('memoria della partita', () {
    test('la cronaca ricorda morti e condanne turno per turno', () {
      final engine = fullTable();
      playNight(engine, {boss: anna, picciotto: anna});
      engine.lynch(bruno);
      playNight(engine);
      engine.lynch(null);

      final history = engine.history;
      expect(history, hasLength(2));
      expect(history[0].round, 1);
      expect(history[0].nightVictims, [anna]);
      expect(history[0].lynched, bruno);
      expect(history[1].nightVictims, isEmpty);
      expect(history[1].lynched, isNull);
    });

    test('i compiti di copertura contano i sospetti, le mosse vere no', () {
      final engine = fullTable();
      playNight(engine, {anna: boss, bruno: boss, detective: boss, doctor: boss});
      expect(engine.suspicion, {boss: 2});
    });
  });

  test('partite casuali finiscono sempre con un vincitore', () {
    for (var seed = 0; seed < 200; seed++) {
      final random = Random(seed);
      final lobby = [for (var i = 0; i < 3 + seed % 10; i++) Player(id: 'p$i', name: 'P$i')];
      final engine = GameEngine(
        GameSetup.deal(lobby: lobby, random: random),
        settings: GameSettings(mafiaTieBreak: TieBreak.values[seed % 3]),
        random: random,
      );

      var rounds = 0;
      while (engine.phase != GamePhase.ended) {
        expect(rounds++, lessThan(100), reason: 'seed=$seed: la partita non finisce');
        for (final player in engine.alivePlayers) {
          final targets = engine.taskFor(player).targets;
          final skip = targets.isEmpty || random.nextInt(5) == 0;
          engine.submitNightChoice(player, skip ? null : targets[random.nextInt(targets.length)]);
        }
        engine.resolveNight();
        if (engine.phase != GamePhase.day) break;
        final alive = engine.alivePlayers;
        engine.lynch(alive[random.nextInt(alive.length)]);
      }
      expect(engine.winner, isNotNull, reason: 'seed=$seed');
    }
  });
}
