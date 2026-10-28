import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/rules/game_engine.dart';
import 'package:oberta/rules/game_setup.dart';
import 'package:oberta/rules/game_snapshot.dart';
import 'package:oberta/rules/intent.dart';
import 'package:oberta/rules/player.dart';
import 'package:oberta/rules/player_view.dart';
import 'package:oberta/rules/role.dart';
import 'package:oberta/rules/role_assignment.dart';

import 'player_view_test.dart' show wire;

// Il Tiratore scelto (docs/ruoli.md, 3.6).

Player _p(String id) => Player(id: id, name: id);

final mob = _p('mob');
final mob2 = _p('mob2');
final tir = _p('tir');
final hooker = _p('hooker');
final fool = _p('fool');
final con = _p('con');
final a = _p('a');
final b = _p('b');
final c = _p('c');
final d = _p('d');

GameEngine table() => GameEngine(
  GameSetup.fromRoles({
    mob: Role.mafioso,
    mob2: Role.mafioso,
    tir: Role.tiratoreScelto,
    fool: Role.fesso,
    con: Role.pregiudicato,
    a: Role.cittadino,
    b: Role.cittadino,
    c: Role.cittadino,
    d: Role.cittadino,
  }),
  seed: 3,
);

/// Una notte: il Tiratore mira ad [aim] (o passa), la Famiglia non spara.
DawnReport night(GameEngine engine, {Player? aim, Player? hit}) {
  if (aim != null) expect(engine.apply(NightAction(tir.id, aim.id)).accepted, isTrue);
  if (hit != null) {
    for (final mafioso in [mob, mob2]) {
      if (engine.isAlive(mafioso)) engine.apply(MafiaVote(mafioso.id, hit.id));
    }
  }
  for (final player in engine.pendingNightPlayers) {
    engine.apply(Pass(player.id));
  }
  return engine.resolveNight();
}

void main() {
  test('di notte mira (non è una visita), e la mira resta se passa', () {
    final engine = table();
    final task = engine.taskFor(tir);
    expect(task.kind, NightTaskKind.aim);
    expect(task.targets, isNot(contains(tir)));
    expect(NightTaskKind.aim.visits, isFalse);
    expect(engine.viewFor(tir.id).aim, isNull);
    night(engine, aim: mob);
    expect(engine.aimed, mob);
    expect(engine.viewFor(tir.id).aim, mob);
    expect(engine.viewFor(tir.id).shotsLeft, 2);
    expect(engine.viewFor(tir.id).action!.canShoot, isTrue);
    // Gli altri non sanno niente.
    expect(engine.viewFor(a.id).aim, isNull);
    expect(engine.viewFor(a.id).shotsLeft, isNull);
    expect(engine.viewFor(a.id).action!.canShoot, isFalse);
    engine.closeDayVote();
    // Passa: la mira vecchia resta.
    night(engine);
    expect(engine.aimed, mob);
  });

  test('cambia mira la notte dopo', () {
    final engine = table();
    night(engine, aim: a);
    engine.closeDayVote();
    night(engine, aim: mob2);
    expect(engine.aimed, mob2);
  });

  test('spara alla Famiglia: il bersaglio muore, il Tiratore resta anonimo', () {
    final engine = table();
    night(engine, aim: mob);
    expect(engine.apply(Shoot(tir.id)).accepted, isTrue);
    expect(engine.isAlive(mob), isFalse);
    expect(engine.isAlive(tir), isTrue);
    final shot = engine.lastShot!;
    expect(shot.victim, mob);
    expect(shot.role, Role.mafioso);
    expect(shot.backfired, isFalse);
    expect(engine.knowledgeOf(null, mob).role, Role.mafioso);
    expect(engine.knowledgeOf(null, tir).role, isNull);
    expect(engine.history.last.dayVictims, [mob]);
    expect(engine.marksmanShotsLeft, 1);
    // La mira si consuma: oggi niente secondo colpo.
    expect(engine.aimed, isNull);
    expect(engine.apply(Shoot(tir.id)).accepted, isFalse);
    final board = wire(engine.publicView().toJson());
    expect(board['lastShot'], {'round': 1, 'seat': 'mob', 'role': 'mafioso', 'winner': null});
  });

  test('spara a un neutrale: muore lui (il Fesso non vince)', () {
    final engine = table();
    night(engine, aim: fool);
    engine.shoot(tir);
    expect(engine.isAlive(fool), isFalse);
    expect(engine.isAlive(tir), isTrue);
    expect(engine.personalWins, isEmpty);
  });

  test('spara alla Città (Pregiudicato compreso): il colpo torna indietro', () {
    final engine = table();
    night(engine, aim: con);
    final shot = engine.shoot(tir);
    expect(shot.backfired, isTrue);
    expect(shot.victim, tir);
    expect(shot.role, Role.tiratoreScelto);
    expect(engine.isAlive(con), isTrue);
    expect(engine.isAlive(tir), isFalse);
    // La carta del Tiratore si scopre; di chi era il bersaglio non si dice.
    expect(engine.knowledgeOf(null, tir).role, Role.tiratoreScelto);
    expect(engine.knowledgeOf(null, con).role, isNull);
    final board = wire(engine.publicView().toJson());
    expect(jsonEncode(board['lastShot']), isNot(contains('con')));
  });

  test('due colpi in tutta la partita, poi solo copertura', () {
    final engine = table();
    night(engine, aim: mob);
    engine.shoot(tir);
    engine.closeDayVote();
    night(engine, aim: fool);
    engine.shoot(tir);
    expect(engine.marksmanShotsLeft, 0);
    engine.closeDayVote();
    expect(engine.taskFor(tir).kind, NightTaskKind.decoy);
    night(engine);
    expect(engine.apply(Shoot(tir.id)), isA<IntentRejected>());
  });

  test('non spara di notte, non spara chi non è il Tiratore', () {
    final engine = table();
    expect(engine.apply(Shoot(tir.id)), isA<IntentRejected>());
    night(engine, aim: mob);
    expect((engine.apply(Shoot(a.id)) as IntentRejected).error, IntentError.notYourAction);
  });

  test('un morto nel mirino non vale più', () {
    final engine = table();
    night(engine, aim: a);
    engine.closeDayVote();
    night(engine, hit: a);
    expect(engine.aimed, isNull);
    expect(engine.viewFor(tir.id).action!.canShoot, isFalse);
  });

  test('bloccato dalla Prostituta non cambia mira, ma spara alla vecchia', () {
    final engine = GameEngine(
      GameSetup.fromRoles({
        mob: Role.mafioso,
        hooker: Role.prostituta,
        tir: Role.tiratoreScelto,
        a: Role.cittadino,
        b: Role.cittadino,
        c: Role.cittadino,
        d: Role.cittadino,
      }),
      seed: 1,
    );
    engine.apply(NightAction(tir.id, mob.id));
    for (final player in engine.pendingNightPlayers) {
      engine.apply(Pass(player.id));
    }
    engine.resolveNight();
    engine.closeDayVote();
    engine.apply(NightAction(tir.id, a.id));
    engine.apply(NightAction(hooker.id, tir.id));
    for (final player in engine.pendingNightPlayers) {
      engine.apply(Pass(player.id));
    }
    engine.resolveNight();
    expect(engine.aimed, mob);
    engine.shoot(tir);
    expect(engine.isAlive(mob), isFalse);
  });

  test('l\'ultimo della Famiglia colpito: vince la Città', () {
    final engine = table();
    night(engine, aim: mob);
    engine.shoot(tir);
    engine.closeDayVote();
    night(engine, aim: mob2);
    final shot = engine.shoot(tir);
    expect(shot.winner, Team.citizens);
    expect(engine.phase, GamePhase.ended);
  });

  test('il crepacuore: colpito un innamorato, muore anche l\'altro', () {
    final cupid = _p('cupid');
    final engine = GameEngine(
      GameSetup.fromRoles({
        mob: Role.mafioso,
        mob2: Role.mafioso,
        tir: Role.tiratoreScelto,
        cupid: Role.cupido,
        a: Role.cittadino,
        b: Role.cittadino,
        c: Role.cittadino,
        d: Role.cittadino,
      }),
      seed: 1,
    );
    engine.apply(Link(cupid.id, mob.id, a.id));
    engine.apply(NightAction(tir.id, mob.id));
    for (final player in engine.pendingNightPlayers) {
      engine.apply(Pass(player.id));
    }
    engine.resolveNight();
    final shot = engine.shoot(tir);
    expect(shot.heartbroken, a);
    expect(engine.isAlive(a), isFalse);
    expect(engine.history.last.dayVictims, [mob, a]);
  });

  test('il voto di chi muore sparato non conta più', () {
    final engine = table();
    night(engine, aim: mob);
    engine.apply(DayVote(mob.id, a.id));
    engine.apply(DayVote(b.id, mob.id));
    engine.shoot(tir);
    expect(engine.dayVotes, isEmpty);
  });

  test('fotografia e registro: mira, colpi e ultimo sparo tornano uguali', () {
    final engine = table();
    night(engine, aim: mob);
    engine.shoot(tir);
    engine.closeDayVote();
    night(engine, aim: b);
    final snapshot = engine.snapshot();
    final copy = GameEngine.fromSnapshot(GameSnapshot.fromJson(wire(snapshot.toJson())));
    expect(copy.aimed, b);
    expect(copy.marksmanShotsLeft, 1);
    expect(copy.lastShot!.victim.id, mob.id);
    final replayed = GameEngine.replay(engine.setup, seed: engine.seed!, log: engine.log);
    expect(replayed.aimed, b);
    expect(replayed.marksmanShotsLeft, 1);
    final view = PlayerView.fromJson(wire(engine.viewFor(tir.id).toJson()));
    expect(view.aim?.id, b.id);
    expect(view.shotsLeft, 1);
  });

  test('il mazzo: Tiratore dai 9, mai con il Cecchino; il Cecchino resta ai tavoli piccoli', () {
    expect(Role.tiratoreScelto.team, Team.citizens);
    expect(Role.tiratoreScelto.rule.minPlayers, 9);
    expect(Role.tiratoreScelto.rule.tier, RoleTier.l3);
    expect(Role.tiratoreScelto.rule.category, RoleCategory.extraKill);
    final random = Random(5);
    var marksmen = 0;
    for (var i = 0; i < 400; i++) {
      for (final count in [7, 8]) {
        expect(rolesForPlayerCount(count, random: random), isNot(contains(Role.tiratoreScelto)));
      }
      for (final count in [9, 10, 11, 12]) {
        final deck = rolesForPlayerCount(count, random: random, mode: PlayMode.online);
        expect(deck, isNot(contains(Role.cecchino)));
        if (deck.contains(Role.tiratoreScelto)) {
          marksmen++;
          expect(deck.where((r) => r.isHostileNeutral), isEmpty);
        }
      }
    }
    expect(marksmen, greaterThan(0));
    // Senza il Tiratore (un telefono vecchio al tavolo) torna il Cecchino.
    var snipers = 0;
    for (var i = 0; i < 200; i++) {
      final deck = rolesForPlayerCount(10, random: random, exclude: {Role.tiratoreScelto});
      if (deck.contains(Role.cecchino)) snipers++;
    }
    expect(snipers, greaterThan(0));
  });
}
