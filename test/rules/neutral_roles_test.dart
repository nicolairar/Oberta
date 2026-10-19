import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/rules/game_engine.dart';
import 'package:oberta/rules/game_setup.dart';
import 'package:oberta/rules/game_snapshot.dart';
import 'package:oberta/rules/intent.dart';
import 'package:oberta/rules/player.dart';
import 'package:oberta/rules/role.dart';
import 'package:oberta/rules/role_assignment.dart';

import '../support/random_game.dart';
import 'player_view_test.dart' show leaksIn, wire;

Player _p(String id) => Player(id: id, name: id);

final mob = _p('mob');
final fool = _p('fool');
final arsonist = _p('arsonist');
final messiah = _p('messiah');
final mayor = _p('mayor');
final doorman = _p('doorman');
final a = _p('a');
final b = _p('b');
final c = _p('c');
final d = _p('d');

GameEngine table(Map<Player, Role> roles) => GameEngine(GameSetup.fromRoles(roles), seed: 7);

/// Fa passare tutti quelli che non hanno ancora scelto, poi chiude la notte.
DawnReport endNight(GameEngine engine) {
  for (final player in engine.pendingNightPlayers) {
    engine.submitNightChoice(player, null);
  }
  return engine.resolveNight();
}

void main() {
  group('Fesso', () {
    test('linciato vince da solo e la partita continua', () {
      final engine = table({
        mob: Role.mafioso,
        fool: Role.fesso,
        a: Role.cittadino,
        b: Role.cittadino,
        c: Role.cittadino,
      });
      endNight(engine);
      final report = engine.lynch(fool);
      expect(report.personalWin, isTrue);
      expect(report.winner, isNull);
      expect(engine.phase, GamePhase.night);
      expect(engine.personalWins, [fool]);
      expect(engine.hasWon(fool), isTrue);
      expect(engine.publicView().personalWins, [fool]);
    });

    test('ucciso di notte non vince', () {
      final engine = table({
        mob: Role.mafioso,
        fool: Role.fesso,
        a: Role.cittadino,
        b: Role.cittadino,
        c: Role.cittadino,
      });
      engine.submitNightChoice(mob, fool);
      endNight(engine);
      expect(engine.personalWins, isEmpty);
    });

    test('conta come non mafioso alla parità', () {
      final engine = table({mob: Role.mafioso, fool: Role.fesso, a: Role.cittadino});
      engine.submitNightChoice(mob, a);
      final dawn = endNight(engine);
      expect(dawn.winner, Team.mafia);
    });
  });

  group('Piromane', () {
    Map<Player, Role> roles() => {
      mob: Role.mafioso,
      arsonist: Role.piromane,
      a: Role.cittadino,
      b: Role.cittadino,
      c: Role.cittadino,
      d: Role.cittadino,
    };

    test('cosparge in segreto e poi brucia tutti i cosparsi', () {
      final engine = table(roles());
      expect(engine.taskFor(arsonist).kind, NightTaskKind.douse);
      expect(engine.taskFor(arsonist).alternative, isNull);
      expect(engine.taskFor(arsonist).targets, isNot(contains(arsonist)));
      engine.submitNightChoice(arsonist, a);
      endNight(engine);
      expect(engine.doused, {a});
      expect(engine.viewFor(arsonist.id).doused, [a]);
      expect(engine.viewFor(a.id).doused, isEmpty);
      expect(wire(engine.publicView().toJson()).toString(), isNot(contains('doused')));
      engine.lynch(null);
      engine.submitNightChoice(arsonist, b);
      endNight(engine);
      engine.lynch(null);
      final task = engine.taskFor(arsonist);
      expect(task.alternative, NightTaskKind.ignite);
      expect(task.alternativeTargets, [arsonist]);
      expect(engine.apply(NightAction(arsonist.id, arsonist.id)).accepted, isTrue);
      final dawn = endNight(engine);
      expect(dawn.ignited, isTrue);
      expect(dawn.victims, [a, b]);
      expect(engine.doused, isEmpty);
    });

    test('la città non vince finché il Piromane è vivo', () {
      final engine = table({mob: Role.mafioso, arsonist: Role.piromane, a: Role.cittadino, b: Role.cittadino});
      endNight(engine);
      final report = engine.lynch(mob);
      expect(report.winner, isNull);
    });

    test('vince da solo solo quando resta l\'ultimo vivo', () {
      final engine = table({mob: Role.mafioso, arsonist: Role.piromane, a: Role.cittadino, b: Role.cittadino});
      endNight(engine);
      engine.lynch(mob);
      engine.submitNightChoice(arsonist, a);
      endNight(engine);
      expect(engine.lynch(b).winner, isNull);
      engine.submitNightChoice(arsonist, arsonist, alternative: true);
      expect(endNight(engine).winner, Team.neutral);
      expect(engine.hasWon(arsonist), isTrue);
      expect(engine.hasWon(a), isFalse);
    });

    test('il Commissario lo vede non mafioso', () {
      expect(Role.piromane.apparentTeam, Team.citizens);
      expect(Role.fesso.apparentTeam, Team.citizens);
    });
  });

  group('Messia', () {
    Map<Player, Role> roles() => {
      mob: Role.mafioso,
      _p('mob2'): Role.mafioso,
      messiah: Role.messia,
      a: Role.detective,
      b: Role.cittadino,
      c: Role.cittadino,
      d: Role.cittadino,
    };

    test('riporta in vita un cittadino linciato, con il suo ruolo', () {
      final engine = table(roles());
      expect(engine.taskFor(messiah).kind, NightTaskKind.decoy);
      endNight(engine);
      engine.lynch(a);
      expect(engine.taskFor(messiah).kind, NightTaskKind.resurrect);
      expect(engine.taskFor(messiah).targets, [a]);
      engine.submitNightChoice(messiah, a);
      final dawn = endNight(engine);
      expect(dawn.resurrected, a);
      expect(engine.isAlive(a), isTrue);
      expect(engine.knowledgeOf(null, a).role, Role.detective);
      engine.lynch(null);
      expect(engine.taskFor(a).kind, NightTaskKind.investigate);
      expect(engine.taskFor(messiah).kind, NightTaskKind.decoy);
    });

    test('se il Messia muore quella notte, la resurrezione fallisce', () {
      final engine = table(roles());
      endNight(engine);
      engine.lynch(a);
      engine.submitNightChoice(messiah, a);
      engine.submitNightChoice(mob, messiah);
      final dawn = endNight(engine);
      expect(dawn.resurrected, isNull);
      expect(engine.isAlive(a), isFalse);
    });

    test('non riporta un mafioso', () {
      final engine = table(roles());
      endNight(engine);
      engine.lynch(mob);
      expect(engine.taskFor(messiah).kind, NightTaskKind.decoy);
    });
  });

  group('Sindaco', () {
    test('si rivela una volta e quel giorno vale doppio', () {
      final engine = table({
        mob: Role.mafioso,
        mayor: Role.sindaco,
        a: Role.cittadino,
        b: Role.cittadino,
        c: Role.cittadino,
      });
      endNight(engine);
      expect(engine.viewFor(mayor.id).action!.canReveal, isTrue);
      expect(engine.viewFor(a.id).action!.canReveal, isFalse);
      expect(engine.apply(RevealMayor(a.id)).accepted, isFalse);
      expect(engine.apply(RevealMayor(mayor.id)).accepted, isTrue);
      expect(engine.apply(RevealMayor(mayor.id)).accepted, isFalse);
      expect(engine.knowledgeOf(null, mayor).role, Role.sindaco);
      expect(engine.publicView().mayor, mayor);
      engine.apply(DayVote(mayor.id, mob.id));
      engine.apply(DayVote(a.id, b.id));
      final report = engine.closeDayVote();
      expect(report.condemned, mob);
      expect(report.winner, Team.citizens);
    });
  });

  group('Portinaio', () {
    test('sa se qualcuno è passato, non chi', () {
      final engine = table({
        mob: Role.mafioso,
        doorman: Role.portinaio,
        a: Role.cittadino,
        b: Role.cittadino,
        c: Role.cittadino,
      });
      engine.submitNightChoice(doorman, a);
      engine.submitNightChoice(mob, a);
      engine.submitNightChoice(b, a); // copertura: non conta
      endNight(engine);
      engine.lynch(null);
      engine.submitNightChoice(doorman, c);
      engine.submitNightChoice(b, c);
      endNight(engine);
      final watches = engine.viewFor(doorman.id).watches;
      expect(watches.map((w) => (w.target, w.visited)), [(a, true), (c, false)]);
      expect(engine.viewFor(b.id).watches, isEmpty);
    });
  });

  test('il mazzo rispetta le regole dei ruoli nuovi', () {
    final random = Random(3);
    var neutrals = 0;
    for (var i = 0; i < 2000; i++) {
      final count = minRolePlayers + random.nextInt(maxRolePlayers - minRolePlayers + 1);
      final deck = rolesForPlayerCount(count, random: random, mode: PlayMode.online);
      for (final role in [Role.fesso, Role.piromane, Role.messia, Role.sindaco, Role.portinaio]) {
        expect(deck.where((r) => r == role).length, lessThanOrEqualTo(1));
        if (deck.contains(role)) expect(count, greaterThanOrEqualTo(role.rule.minPlayers));
      }
      expect(deck.where((r) => r.team == Team.neutral).length, lessThanOrEqualTo(maxNeutralsFor(count)));
      if (deck.contains(Role.piromane)) expect(deck, isNot(contains(Role.cecchino)));
      neutrals += deck.where((r) => r.team == Team.neutral).length;
    }
    expect(neutrals, greaterThan(0));
  });

  test('le fughe non passano neanche con tutti i ruoli nuovi al tavolo', () {
    final random = Random(17);
    final roles = [
      Role.mafioso,
      Role.mafioso,
      Role.sarto,
      Role.fesso,
      Role.piromane,
      Role.messia,
      Role.sindaco,
      Role.portinaio,
      Role.detective,
      Role.becchino,
      Role.cittadino,
      Role.cittadino,
      Role.cittadino,
    ];
    var finished = 0;
    for (var game = 0; game < 120; game++) {
      final players = [for (var i = 1; i <= roles.length; i++) _p('s$i')];
      final deck = [...roles]..shuffle(random);
      final engine = GameEngine(GameSetup.fromRoles(Map.fromIterables(players, deck)), seed: random.nextInt(1 << 32));
      for (var step = 0; step < 3000; step++) {
        expect(leaksIn(engine, null, wire(engine.publicView().toJson())), isEmpty, reason: 'gioco $game');
        for (final player in engine.setup.players) {
          final view = engine.viewFor(player.id);
          if (engine.setup.roleOf(player) != Role.piromane) expect(view.doused, isEmpty);
          if (engine.setup.roleOf(player) != Role.portinaio) expect(view.watches, isEmpty);
          expect(leaksIn(engine, player, wire(view.toJson())), isEmpty, reason: 'vista di ${player.id}, gioco $game');
        }
        final command = randomCommand(engine, random);
        if (command == null) break;
        engine.run(command);
      }
      if (engine.phase == GamePhase.ended) finished++;
      // La fotografia e il registro riportano la stessa partita.
      final snapshot = GameSnapshot.fromJson(wire(engine.snapshot().toJson()));
      expect(jsonEncode(GameEngine.fromSnapshot(snapshot).snapshot().toJson()), jsonEncode(engine.snapshot().toJson()));
      final replayed = GameEngine.replay(engine.setup, seed: engine.seed!, log: engine.log);
      expect(jsonEncode(replayed.snapshot().toJson()), jsonEncode(engine.snapshot().toJson()));
    }
    expect(finished, greaterThan(100));
  });
}
