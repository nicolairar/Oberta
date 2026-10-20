import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/online/game/bot_brain.dart';
import 'package:oberta/online/game/game_schedule.dart';
import 'package:oberta/online/game/game_server.dart';
import 'package:oberta/online/game/match_rewards.dart';
import 'package:oberta/rules/intent.dart';
import 'package:oberta/rules/player_view.dart';

import 'game_server_test.dart' show ServerHarness, table;

/// Come gioca ogni posto umano.
enum Style { full, votesOnly, passesAtNightAndVotes, idle }

/// Gioca fino alla fine con uno stile per posto; torna il risultato.
Map<String, Object?> play(int seed, Map<String, Style> styles, {int humans = 4, int bots = 3}) {
  final server = ServerHarness(table(humans: humans, bots: bots), seed: seed);
  final random = Random(seed);
  server.step();
  for (var i = 0; i < 4000 && server.last['finished'] != true; i++) {
    var acted = false;
    final key = server.schedule['key'] as String;
    for (final seat in (server.last['seatViews'] as Map).keys.cast<String>()) {
      final style = styles[seat] ?? Style.full;
      if (style == Style.idle || server.queue.any((q) => q['seat'] == seat)) continue;
      final payload = server.seatView(seat);
      final view = PlayerView.fromJson(payload['view'] as Map<String, Object?>);
      if (server.stage.acceptsActions) {
        if (view.action == null || server.actedIn[seat] == key) continue;
        final night = server.stage == Stage.night;
        if (night && style == Style.votesOnly) continue;
        server.actedIn[seat] = key;
        final PlayerIntent? intent = night && style == Style.passesAtNightAndVotes
            ? Pass(seat)
            : !night && style == Style.passesAtNightAndVotes
                ? Pass(seat) // il pulsante «mi astengo»
                : BotBrain(random).decide(view);
        if (intent == null) continue;
        server.send(seat, intent.toJson());
        acted = true;
      } else if (style == Style.full && server.stage.acknowledged && payload['acked'] != true && view.alive) {
        server.send(seat, {'type': 'ack', 'seat': seat, 'stage': key});
        acted = true;
      }
    }
    if (!acted) server.now = max(server.now, server.last['nextDue'] as int);
    server.step();
  }
  expect(server.last['finished'], isTrue);
  return server.last['result'] as Map<String, Object?>;
}

Map<String, Object?> seatOf(Map<String, Object?> result, String seat) =>
    ((result['seats'] as Map)[seat] as Map).cast<String, Object?>();

void main() {
  group('Attendance', () {
    Attendance run(String turns) {
      final a = Attendance();
      for (final t in turns.split('')) {
        a.record(present: t == 'x');
      }
      return a;
    }

    test('muto quasi sempre e 3 turni di fila: assente', () {
      expect(run('---').afk, isTrue);
      expect(run('x----').afk, isTrue);
      expect(run('---x---').afk, isTrue);
    });

    test('chi vota ogni giorno non è mai assente, anche muto di notte', () {
      // Notte, giorno, notte, giorno…: le notti mute, i voti dati.
      expect(run('-x-x-x-x-x').afk, isFalse);
      expect(run('-x' * 20).afk, isFalse);
    });

    test('meno del 70% o nessuna fila di 3: non assente', () {
      expect(run('--x--x--').afk, isFalse);
      expect(run('xx---xx').afk, isFalse);
      expect(run('--').afk, isFalse);
    });
  });

  group('sul server', () {
    test('chi gioca tutto non è assente, chi non tocca mai il telefono sì', () {
      var judged = 0;
      for (var seed = 1; seed <= 6; seed++) {
        final result = play(seed, {'s4': Style.idle});
        expect(seatOf(result, 's1')['afk'], isFalse, reason: 'partita $seed');
        final idle = seatOf(result, 's4');
        // Se è morto presto non ha avuto 3 turni da saltare.
        if (idle['afk'] == true) judged++;
      }
      expect(judged, greaterThan(0));
    });

    test('il bluffatore che tace ma vota ogni giorno non è assente', () {
      for (var seed = 1; seed <= 8; seed++) {
        final result = play(seed, {'s2': Style.votesOnly, 's3': Style.passesAtNightAndVotes});
        expect(seatOf(result, 's2')['afk'], isFalse, reason: 'partita $seed');
        expect(seatOf(result, 's3')['afk'], isFalse, reason: 'partita $seed');
      }
    });

    test('anche la chat conta come esserci', () {
      final server = ServerHarness(table(humans: 2, bots: 3));
      server.step();
      final game = ServerGame.fromJson(server.state!, random: Random(1));
      game.step(now: DateTime.fromMillisecondsSinceEpoch(server.now), chat: [(id: 5, seat: 's2')]);
      expect(game.spoke, contains('s2'));
      expect(game.lastChat, 5);
      game.step(now: DateTime.fromMillisecondsSinceEpoch(server.now), chat: [(id: 5, seat: 's1')]);
      expect(game.spoke, isNot(contains('s1')), reason: 'un messaggio già contato non conta due volte');
    });
  });

  group('premi', () {
    SettleSeat seat(String p, {bool won = true, bool afk = false, bool leftDead = false, bool short = false, bool abandoned = false}) =>
        SettleSeat(profile: p, seat: p, team: 'citizens', role: 'cittadino', won: won, survived: true,
            abandoned: abandoned, afk: afk, leftDead: leftDead, short: short, level: 1, xp: 95);

    test('assente: niente XP, monete né punteggio in più, anche se vince', () {
      final out = settle(ranked: true, seats: [seat('a'), seat('b', afk: true), seat('c', won: false), seat('d', won: false)]);
      final a = out.firstWhere((o) => o.seat.profile == 'a');
      final b = out.firstWhere((o) => o.seat.profile == 'b');
      expect(a.xpGained, greaterThan(0));
      expect(a.coins, greaterThan(0));
      expect(b.xpGained, 0);
      expect(b.coins, 0);
      expect(b.ordinalDelta!, lessThanOrEqualTo(0));
    });

    test('uscito da morto: niente premi, punteggio fermo', () {
      final out = settle(ranked: true, seats: [seat('a'), seat('b', leftDead: true), seat('c', won: false)]);
      final b = out.firstWhere((o) => o.seat.profile == 'b');
      expect(b.xpGained, 0);
      expect(b.coins, 0);
      expect(b.ordinalDelta, 0);
    });

    test('partita troppo breve per un abbandono: nessuno prende niente', () {
      final out = settle(ranked: false, humans: 4, seats: [for (final p in ['a', 'b', 'c', 'd']) seat(p, short: true)]);
      expect(out.every((o) => o.xpGained == 0 && o.coins == 0), isTrue);
    });

    test('al sesto gioco fra amici del giorno le monete non arrivano più', () {
      final s = SettleSeat(profile: 'a', seat: 's1', team: 'citizens', role: 'cittadino', won: true, survived: true,
          abandoned: false, level: 1, xp: 95, friendsGamesToday: Progression.friendsCoinGames);
      final out = settle(ranked: false, humans: 4, seats: [s]);
      expect(out.single.xpGained, greaterThan(0));
      expect(out.single.coins, 0);
    });
  });
}
