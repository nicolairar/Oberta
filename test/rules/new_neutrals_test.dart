import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/online/game/bot_brain.dart';
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
final hunter = _p('hunter');
final shark = _p('shark');
final hitman = _p('hitman');
final doc = _p('doc');
final a = _p('a');
final b = _p('b');
final c = _p('c');
final d = _p('d');

GameEngine table(Map<Player, Role> roles, {int seed = 7}) => GameEngine(GameSetup.fromRoles(roles), seed: seed);

DawnReport endNight(GameEngine engine) {
  for (final player in engine.pendingNightPlayers) {
    engine.submitNightChoice(player, null);
  }
  return engine.resolveNight();
}

void main() {
  group('Cacciatore di taglie', () {
    Map<Player, Role> roles() => {
          mob: Role.mafioso,
          hunter: Role.cacciatore,
          a: Role.cittadino,
          b: Role.cittadino,
          c: Role.cittadino,
          d: Role.cittadino,
        };

    test('la taglia è un cittadino, la vede solo lui', () {
      final engine = table(roles());
      final mark = engine.bountyOf(hunter)!;
      expect(engine.setup.roleOf(mark).team, Team.citizens);
      expect(engine.viewFor(hunter.id).bounty, mark);
      expect(engine.viewFor(a.id).bounty, isNull);
      expect(wire(engine.publicView().toJson()).toString(), isNot(contains('bounty')));
      expect(engine.taskFor(hunter).kind, NightTaskKind.decoy);
    });

    test('la taglia linciata: incassa, si scopre, e la partita finisce', () {
      final engine = table(roles());
      final mark = engine.bountyOf(hunter)!;
      endNight(engine);
      final report = engine.lynch(mark);
      expect(report.bountyHunter, hunter);
      expect(report.personalWin, isFalse);
      expect(engine.personalWins, [hunter]);
      expect(engine.hasWon(hunter), isTrue);
      expect(engine.phase, GamePhase.ended);
      expect(engine.winner, Team.neutral);
      expect(engine.knowledgeOf(null, hunter).role, Role.cacciatore);
    });

    test('la taglia morta di notte: gioca con la città', () {
      final engine = table(roles());
      final mark = engine.bountyOf(hunter)!;
      engine.submitNightChoice(mob, mark);
      endNight(engine);
      expect(engine.bountyLapsed(hunter), isTrue);
      engine.lynch(mob);
      expect(engine.winner, Team.citizens);
      expect(engine.hasWon(hunter), isTrue);
      expect(engine.personalWins, isEmpty);
    });

    test('il seme decide la taglia, e fotografia e registro la tengono', () {
      final engine = table(roles(), seed: 99);
      endNight(engine);
      final snapshot = GameSnapshot.fromJson(wire(engine.snapshot().toJson()));
      expect(GameEngine.fromSnapshot(snapshot).bountyOf(hunter)?.id, engine.bountyOf(hunter)!.id);
      final replayed = GameEngine.replay(engine.setup, seed: 99, log: engine.log);
      expect(replayed.bountyOf(hunter), engine.bountyOf(hunter));
    });

    test('il bot cacciatore vota la sua taglia', () {
      final engine = table(roles());
      endNight(engine);
      final mark = engine.bountyOf(hunter)!;
      final intent = BotBrain(Random(1)).decide(engine.viewFor(hunter.id));
      expect(intent, isA<DayVote>().having((vote) => vote.target, 'target', mark.id));
    });
  });

  group('Strozzino', () {
    Map<Player, Role> roles() => {
          mob: Role.mafioso,
          shark: Role.strozzino,
          a: Role.cittadino,
          b: Role.cittadino,
          c: Role.cittadino,
        };

    test('il debitore non muore stanotte, e mai lo stesso due notti di fila', () {
      final engine = table(roles());
      expect(engine.taskFor(shark).kind, NightTaskKind.lend);
      engine.submitNightChoice(shark, a);
      engine.submitNightChoice(mob, a);
      final dawn = endNight(engine);
      expect(dawn.attacks.single.outcome, AttackOutcome.healed);
      expect(engine.isAlive(a), isTrue);
      engine.lynch(null);
      expect(engine.taskFor(shark).targets, isNot(contains(a)));
      expect(engine.taskFor(shark).targets, isNot(contains(shark)));
    });

    test('vivo a fine partita vince, chiunque vinca', () {
      final engine = table(roles());
      endNight(engine);
      engine.lynch(mob);
      expect(engine.winner, Team.citizens);
      expect(engine.personalWins, [shark]);
      expect(engine.hasWon(shark), isTrue);
    });

    test('morto non vince', () {
      final engine = table(roles());
      engine.submitNightChoice(mob, shark);
      endNight(engine);
      engine.lynch(mob);
      expect(engine.winner, Team.citizens);
      expect(engine.hasWon(shark), isFalse);
    });

    test('non blocca la vittoria della città', () {
      expect(Role.strozzino.isHostileNeutral, isFalse);
      expect(Role.strozzino.apparentTeam, Team.citizens);
    });
  });

  group('Sicario', () {
    test('uccide ogni notte, in proprio', () {
      final engine = table({
        mob: Role.mafioso,
        hitman: Role.sicario,
        a: Role.cittadino,
        b: Role.cittadino,
        c: Role.cittadino,
      });
      expect(engine.taskFor(hitman).kind, NightTaskKind.stab);
      engine.submitNightChoice(hitman, a);
      engine.submitNightChoice(mob, b);
      final dawn = endNight(engine);
      expect(dawn.victims, unorderedEquals([a, b]));
      expect(dawn.attacks.firstWhere((x) => x.target == a).source, AttackSource.assassin);
    });

    test('il Dottore lo ferma, il Commissario lo vede della famiglia', () {
      final engine = table({
        mob: Role.mafioso,
        hitman: Role.sicario,
        doc: Role.medico,
        a: Role.cittadino,
        b: Role.cittadino,
      });
      engine.submitNightChoice(hitman, a);
      engine.submitNightChoice(doc, a);
      final dawn = endNight(engine);
      expect(dawn.attacks.single.outcome, AttackOutcome.healed);
      expect(Role.sicario.apparentTeam, Team.mafia);
    });

    test('la città non vince finché è vivo; vince lui se resta con uno', () {
      final engine = table({mob: Role.mafioso, hitman: Role.sicario, a: Role.cittadino, b: Role.cittadino});
      endNight(engine);
      engine.lynch(mob);
      expect(engine.winner, isNull);
      engine.submitNightChoice(hitman, a);
      endNight(engine);
      expect(engine.winner, Team.neutral);
      expect(engine.personalWins, [hitman]);
    });
  });

  group('Il mazzo', () {
    test('mai due assassini, mai due che vincono col voto, il Fesso con al massimo un altro', () {
      final random = Random(5);
      final seen = <Role>{};
      for (var i = 0; i < 5000; i++) {
        final count = minRolePlayers + random.nextInt(maxRolePlayers - minRolePlayers + 1);
        final mode = random.nextBool() ? PlayMode.online : PlayMode.sharedPhone;
        final deck = rolesForPlayerCount(count, random: random, mode: mode);
        final neutrals = [
          for (final r in deck)
            if (r.team == Team.neutral) r,
        ];
        seen.addAll(neutrals);
        expect(neutrals.length, lessThanOrEqualTo(maxNeutralsFor(count)));
        expect(neutrals.length, greaterThanOrEqualTo(minNeutralsFor(count)), reason: '$count: $deck');
        expect(neutrals.where((r) => r.isHostileNeutral).length, lessThanOrEqualTo(1));
        expect(neutrals.where((r) => r.isLynchSeeker).length, lessThanOrEqualTo(1));
        if (neutrals.contains(Role.fesso)) expect(neutrals.length, lessThanOrEqualTo(2));
        if (neutrals.any((r) => r.isHostileNeutral)) expect(deck, isNot(contains(Role.cecchino)));
        for (final role in neutrals) {
          expect(count, greaterThanOrEqualTo(role.rule.minPlayers));
          expect(deck.where((r) => r == role).length, 1);
        }
      }
      expect(seen, containsAll([Role.cacciatore, Role.strozzino, Role.sicario]));
    });

    test('a 12 giocatori: 3 di famiglia, 1-2 neutrali, almeno 2 onesti', () {
      final random = Random(11);
      for (var i = 0; i < 500; i++) {
        final deck = rolesForPlayerCount(12, random: random);
        expect(deck.where((r) => r.team == Team.mafia).length, 3);
        expect(deck.where((r) => r.team == Team.neutral).length, inInclusiveRange(1, 2));
        expect(deck.where((r) => r == Role.cittadino).length, greaterThanOrEqualTo(2));
      }
    });
  });

  test('partite a caso con i neutrali nuovi: niente fughe, fotografie fedeli, vittorie sensate', () {
    final random = Random(23);
    final wins = <String, int>{};
    var games = 0;
    for (var game = 0; game < 300; game++) {
      final count = 9 + random.nextInt(4);
      final players = [for (var i = 1; i <= count; i++) _p('s$i')];
      final deck = rolesForPlayerCount(count, random: random, mode: PlayMode.online)..shuffle(random);
      final engine = GameEngine(GameSetup.fromRoles(Map.fromIterables(players, deck)), seed: random.nextInt(1 << 32));
      for (var step = 0; step < 3000; step++) {
        if (step % 5 == 0) {
          for (final player in engine.setup.players) {
            final view = engine.viewFor(player.id);
            if (engine.setup.roleOf(player) != Role.cacciatore) expect(view.bounty, isNull);
            expect(leaksIn(engine, player, wire(view.toJson())), isEmpty, reason: 'gioco $game');
          }
        }
        final command = randomCommand(engine, random);
        if (command == null) break;
        engine.run(command);
      }
      if (engine.phase != GamePhase.ended) continue;
      games++;
      wins.update(engine.winner!.name, (n) => n + 1, ifAbsent: () => 1);
      for (final player in engine.personalWins) {
        wins.update('solo:${engine.setup.roleOf(player).name}', (n) => n + 1, ifAbsent: () => 1);
      }
      final snapshot = GameSnapshot.fromJson(wire(engine.snapshot().toJson()));
      expect(jsonEncode(GameEngine.fromSnapshot(snapshot).snapshot().toJson()), jsonEncode(engine.snapshot().toJson()));
    }
    printOnFailure('$games partite: $wins');
    // Con mosse a caso nessuno deve stravincere, e i neutrali restano un'eccezione.
    expect(games, greaterThan(250));
    expect(wins['neutral'] ?? 0, lessThan(games * 0.2), reason: '$wins');
    expect(wins['citizens'] ?? 0, greaterThan(games * 0.15), reason: '$wins');
    expect(wins['mafia'] ?? 0, greaterThan(games * 0.15), reason: '$wins');
  });
}
