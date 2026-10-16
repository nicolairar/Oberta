import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/rules/game_engine.dart';
import 'package:oberta/rules/intent.dart';
import 'package:oberta/rules/player.dart';
import 'package:oberta/rules/player_view.dart';
import 'package:oberta/rules/role.dart';

import '../support/random_game.dart';
import 'game_engine_test.dart'
    show anna, boss, bruno, detective, doctor, fullTable, grandTable, picciotto, don, convict;

final _roleNames = {for (final role in Role.values) role.name};

/// Le violazioni nel JSON di una vista: ogni ruolo o fazione di un posto
/// deve essere quello che [viewer] (o il pubblico, se nullo) ha diritto di
/// sapere, e un nome di ruolo può comparire solo sotto la chiave `role`.
/// A partita finita le carte si scoprono: `finalRoles` non conta.
List<String> leaksIn(GameEngine engine, Player? viewer, Object? json) {
  final leaks = <String>[];
  final seats = {for (final player in engine.setup.players) player.id: player};

  void walk(Object? node, String path) {
    switch (node) {
      case Map<String, Object?>():
        final seat = (node['seat'] ?? node['condemned']) as String?;
        final role = node['role'] as String?;
        final team = node['team'] as String?;
        if (role != null || team != null) {
          final subject = seats[seat];
          if (subject == null) {
            leaks.add('$path: ruolo o fazione senza un posto');
          } else {
            final known = engine.knowledgeOf(viewer, subject);
            if (role != null && role != known.role?.name) leaks.add('$path: ruolo di $seat ($role)');
            if (team != null && team != known.team?.name) leaks.add('$path: fazione di $seat ($team)');
          }
        }
        for (final MapEntry(:key, :value) in node.entries) {
          if (key == 'finalRoles' && engine.phase == GamePhase.ended) continue;
          if (value is String && _roleNames.contains(value) && key != 'role') leaks.add('$path.$key: $value');
          walk(value, '$path.$key');
        }
      case List<Object?>():
        for (final (index, item) in node.indexed) {
          if (item is String && _roleNames.contains(item)) leaks.add('$path[$index]: $item');
          walk(item, '$path[$index]');
        }
    }
  }

  walk(json, r'$');
  return leaks;
}

Map<String, Object?> wire(Map<String, Object?> json) => jsonDecode(jsonEncode(json)) as Map<String, Object?>;

void main() {
  test('nessuna vista lascia trapelare ruoli altrui', () {
    final random = Random(11);
    var checked = 0;
    for (var game = 0; game < 150; game++) {
      final engine = randomEngine(random);
      for (var step = 0; step < 3000; step++) {
        final board = wire(engine.publicView().toJson());
        expect(leaksIn(engine, null, board), isEmpty, reason: 'schermo di tutti, gioco $game');
        if (engine.phase != GamePhase.ended) expect(board['finalRoles'], isEmpty);
        for (final player in engine.setup.players) {
          final view = wire(engine.viewFor(player.id).toJson());
          expect(leaksIn(engine, player, view), isEmpty, reason: 'vista di ${player.id}, gioco $game');
          checked++;
        }
        final command = randomCommand(engine, random);
        if (command == null) break;
        engine.run(command);
      }
    }
    expect(checked, greaterThan(10000));
  });

  test('il controllo delle fughe se ne accorge', () {
    // Posti neutri: un posto che si chiama come un ruolo farebbe scattare il controllo.
    final engine = randomEngine(Random(2));
    final viewer = engine.setup.players.firstWhere((p) => engine.setup.roleOf(p).team == Team.citizens);
    final mafioso = engine.setup.players.firstWhere((p) => engine.setup.roleOf(p).team == Team.mafia);
    final view = wire(engine.viewFor(viewer.id).toJson());
    expect(leaksIn(engine, viewer, view), isEmpty);
    (view['known'] as List).add({'seat': mafioso.id, 'team': 'mafia', 'role': engine.setup.roleOf(mafioso).name});
    view['note'] = 'detective';
    expect(leaksIn(engine, viewer, view), hasLength(3));
  });

  test('ogni vista torna uguale dal JSON', () {
    final random = Random(5);
    for (var game = 0; game < 20; game++) {
      final engine = randomEngine(random);
      for (var step = 0; step < 3000; step++) {
        final board = engine.publicView().toJson();
        expect(jsonEncode(PublicView.fromJson(wire(board)).toJson()), jsonEncode(board));
        for (final player in engine.setup.players) {
          final view = engine.viewFor(player.id).toJson();
          expect(jsonEncode(PlayerView.fromJson(wire(view)).toJson()), jsonEncode(view));
        }
        final command = randomCommand(engine, random);
        if (command == null) break;
        engine.run(command);
      }
    }
  });

  group('cosa vede ciascuno', () {
    test('un onesto vede solo il suo ruolo e la sua mossa', () {
      final view = fullTable().viewFor(anna.id);
      expect(view.role, Role.cittadino);
      expect(view.team, Team.citizens);
      expect(view.teammates, isEmpty);
      expect(view.known, isEmpty);
      expect(view.action!.type, ActionType.nightAction);
      expect(view.action!.kind, NightTaskKind.decoy);
      expect(view.action!.targets, isNot(contains(anna)));
      expect(view.familyVotes, isEmpty);
    });

    test('la famiglia si conosce e vede i voti per l\'agguato', () {
      final engine = fullTable();
      engine.apply(MafiaVote(picciotto.id, anna.id));
      final view = engine.viewFor(boss.id);
      expect(view.teammates, [picciotto]);
      expect(view.known.single.seat, picciotto);
      expect(view.known.single.knowledge.role, Role.mafioso);
      expect(view.action!.type, ActionType.mafiaVote);
      expect(view.familyVotes, [(voter: picciotto, target: anna)]);
      // Gli altri non vedono il voto della famiglia.
      expect(engine.viewFor(anna.id).familyVotes, isEmpty);
    });

    test('il Commissario vede la fazione che risulta, non quella vera', () {
      final engine = grandTable();
      engine.apply(NightAction(detective.id, don.id));
      final view = engine.viewFor(detective.id);
      expect(view.known.single.seat, don);
      expect(view.known.single.knowledge.team, Team.citizens);
      expect(view.known.single.knowledge.role, isNull);
      // Ha già agito: nessuna mossa, ma la sua scelta resta.
      expect(view.action, isNull);
      expect(view.nightChoice, (kind: NightTaskKind.investigate, target: don));
      expect(engine.viewFor(convict.id).known, isEmpty);
    });

    test('di notte lo schermo di tutti dice solo quanti mancano', () {
      final engine = fullTable();
      engine.apply(NightAction(doctor.id, anna.id));
      final board = engine.publicView();
      expect(board.nightPending, 7);
      expect(jsonEncode(board.toJson()), isNot(contains(NightTaskKind.protect.name)));
    });

    test('di giorno i voti sono pubblici e ognuno vede il suo', () {
      final engine = fullTable();
      for (final player in engine.alivePlayers) {
        engine.apply(Pass(player.id));
      }
      engine.resolveNight();
      engine.apply(DayVote(anna.id, boss.id));
      expect(engine.publicView().dayVotes, [(voter: anna, target: boss)]);
      final view = engine.viewFor(anna.id);
      expect(view.action!.type, ActionType.dayVote);
      expect(view.action!.current, boss);
      expect(view.action!.targets, isNot(contains(anna)));
      expect(view.board.lastDawn!.victims, isEmpty);
    });

    test('un linciato diventa pubblico, i morti di notte no', () {
      final engine = fullTable();
      for (final player in engine.alivePlayers) {
        engine.apply(player == boss || player == picciotto ? MafiaVote(player.id, bruno.id) : Pass(player.id));
      }
      engine.resolveNight();
      engine.lynch(boss);
      final board = engine.publicView();
      expect(board.revealed.single.seat, boss);
      expect(board.revealed.single.knowledge.role, Role.mafioso);
      expect(board.lastLynch!.condemned, boss);
      expect(board.history.single.nightVictims, [bruno]);

      final dead = engine.viewFor(bruno.id);
      expect(dead.alive, isFalse);
      expect(dead.action, isNull);
      expect(dead.role, Role.cittadino);
    });

    test('a partita finita le carte si scoprono', () {
      final engine = fullTable();
      for (final player in engine.alivePlayers) {
        engine.apply(Pass(player.id));
      }
      engine.resolveNight();
      engine.lynch(boss);
      for (final player in engine.alivePlayers) {
        engine.apply(Pass(player.id));
      }
      engine.resolveNight();
      engine.lynch(picciotto);
      expect(engine.phase, GamePhase.ended);
      final board = engine.publicView();
      expect(board.winner, Team.citizens);
      expect(board.finalRoles, engine.setup.roles);
      expect(engine.viewFor(anna.id).action, isNull);
    });

    test('il narratore e i posti sconosciuti non hanno una vista', () {
      expect(() => fullTable().viewFor('nessuno'), throwsArgumentError);
    });
  });
}
