import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/rules/game_engine.dart';
import 'package:oberta/rules/game_setup.dart';
import 'package:oberta/rules/game_snapshot.dart';
import 'package:oberta/rules/intent.dart';
import 'package:oberta/rules/player.dart';
import 'package:oberta/rules/role.dart';

import '../support/random_game.dart';

const maxSteps = 3000;

String snap(GameEngine engine) => jsonEncode(engine.snapshot().toJson());

/// Fotografa, passa per il JSON come farebbe sulla rete o su disco, riprende.
GameEngine roundTrip(GameEngine engine) =>
    GameEngine.fromSnapshot(GameSnapshot.fromJson(jsonDecode(snap(engine)) as Map<String, Object?>));

/// Quello che un comando restituisce, in JSON, per confrontare due motori.
Object? runAndReport(GameEngine engine, GameCommand command) => switch (command) {
      IntentCommand(:final intent) => engine.apply(intent).toJson(),
      ResolveNightCommand() => jsonEncode(engine.resolveNight().victims.map((p) => p.id).toList()),
      CloseDayVoteCommand() => engine.closeDayVote().condemned?.id,
      LynchCommand() => (engine..run(command)).phase.name,
    };

void main() {
  test('una fotografia ripassata dal JSON è identica', () {
    final random = Random(7);
    for (var game = 0; game < 30; game++) {
      final engine = randomEngine(random);
      for (var step = 0; step < maxSteps; step++) {
        expect(snap(roundTrip(engine)), snap(engine));
        final command = randomCommand(engine, random);
        if (command == null) break;
        engine.run(command);
      }
    }
  });

  test('ripresa da una fotografia, la partita prosegue identica', () {
    final random = Random(42);
    var draws = 0;
    for (var game = 0; game < 200; game++) {
      final original = randomEngine(random);
      final stopAt = random.nextInt(60);
      for (var step = 0; step < stopAt; step++) {
        final command = randomCommand(original, random);
        if (command == null) break;
        original.run(command);
      }

      final restored = roundTrip(original);
      for (var step = 0; step < maxSteps; step++) {
        final command = randomCommand(original, random);
        if (command == null) break;
        expect(runAndReport(restored, command), runAndReport(original, command), reason: 'gioco $game, $command');
        expect(snap(restored), snap(original));
        for (final player in original.setup.players) {
          expect(jsonEncode(restored.viewFor(player.id).toJson()), jsonEncode(original.viewFor(player.id).toJson()));
        }
      }
      expect(original.phase, GamePhase.ended, reason: 'la partita $game deve finire');
      expect(restored.winner, original.winner);
      draws += original.snapshot().draws.length;
    }
    // Qualche spareggio a sorte deve esserci stato, o la prova non prova niente.
    expect(draws, greaterThan(10));
  });

  test('il registro con il seme rigioca la partita da capo', () {
    final random = Random(3);
    for (var game = 0; game < 100; game++) {
      final engine = randomEngine(random);
      for (var step = 0; step < maxSteps; step++) {
        final command = randomCommand(engine, random);
        if (command == null) break;
        engine.run(command);
      }
      final log = [for (final command in engine.log) GameCommand.fromJson(jsonDecode(jsonEncode(command.toJson())))];
      final replayed = GameEngine.replay(engine.setup, settings: engine.settings, seed: engine.seed!, log: log);
      expect(snap(replayed), snap(engine));
    }
  });

  test('i pareggi della famiglia si sorteggiano allo stesso modo dopo la ripresa', () {
    const a = Player(id: 's1', name: 'A');
    const b = Player(id: 's2', name: 'B');
    const c = Player(id: 's3', name: 'C');
    const d = Player(id: 's4', name: 'D');
    const e = Player(id: 's5', name: 'E');
    const f = Player(id: 's6', name: 'F');
    const g = Player(id: 's7', name: 'G');
    const h = Player(id: 's8', name: 'H');
    final setup = GameSetup.fromRoles({
      a: Role.mafioso,
      b: Role.mafioso,
      c: Role.cittadino,
      d: Role.cittadino,
      e: Role.cittadino,
      f: Role.cittadino,
      g: Role.cittadino,
      h: Role.cittadino,
    });
    for (var seed = 0; seed < 20; seed++) {
      final original = GameEngine(setup, seed: seed);
      GameEngine? restored;
      for (var night = 0; night < 3 && original.phase != GamePhase.ended; night++) {
        restored ??= night == 1 ? roundTrip(original) : null;
        for (final engine in [original, ?restored]) {
          final targets = [
            for (final p in engine.alivePlayers)
              if (p != a && p != b) p,
          ];
          for (final player in engine.alivePlayers) {
            final kill = player == a
                ? targets[0]
                : player == b
                    ? targets[1]
                    : null;
            engine.apply(kill == null ? Pass(player.id) : MafiaVote(player.id, kill.id));
          }
        }
        final victims = original.resolveNight().victims;
        if (restored != null) expect(restored.resolveNight().victims, victims);
        for (final engine in [original, ?restored]) {
          if (engine.phase == GamePhase.day) engine.lynch(null);
        }
      }
      expect(snap(restored!), snap(original));
    }
  });

  test('un motore con un Random esterno gira ma non si fotografa', () {
    final engine = GameEngine(
      GameSetup.fromRoles({
        const Player(id: 's1', name: 'A'): Role.mafioso,
        const Player(id: 's2', name: 'B'): Role.cittadino,
        const Player(id: 's3', name: 'C'): Role.cittadino,
      }),
      random: Random(1),
    );
    expect(engine.seed, isNull);
    expect(engine.snapshot, throwsStateError);
  });

  test('random e seed insieme non hanno senso', () {
    final setup = GameSetup.fromRoles({
      const Player(id: 's1', name: 'A'): Role.mafioso,
      const Player(id: 's2', name: 'B'): Role.cittadino,
      const Player(id: 's3', name: 'C'): Role.cittadino,
    });
    expect(() => GameEngine(setup, random: Random(1), seed: 1), throwsArgumentError);
  });

  test('il resolver ridà i nomi ai posti', () {
    final engine = GameEngine(
      GameSetup.fromRoles({
        const Player(id: 's1', name: 'Anna'): Role.mafioso,
        const Player(id: 's2', name: 'Bruno'): Role.cittadino,
        const Player(id: 's3', name: 'Carla'): Role.cittadino,
      }),
      seed: 5,
    );
    final json = jsonDecode(snap(engine)) as Map<String, Object?>;
    expect(jsonEncode(json), isNot(contains('Anna')));

    const names = {'s1': 'Anna', 's2': 'Bruno', 's3': 'Carla'};
    final restored = GameEngine.fromSnapshot(
      GameSnapshot.fromJson(json, (seat) => Player(id: seat, name: names[seat]!)),
    );
    expect([for (final p in restored.alivePlayers) p.name], ['Anna', 'Bruno', 'Carla']);
  });

  test('una versione sconosciuta viene rifiutata', () {
    final engine = randomEngine(Random(1));
    final json = engine.snapshot().toJson()..['version'] = 99;
    expect(() => GameSnapshot.fromJson(json), throwsFormatException);
  });
}
