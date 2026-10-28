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

import 'player_view_test.dart' show leaksIn, wire;

// L'Artigliere (docs/ruoli.md, 3.5).

Player _p(String id) => Player(id: id, name: id);

final mob = _p('mob');
final mob2 = _p('mob2');
final gun = _p('gun');
final doc = _p('doc');
final vet = _p('vet');
final pres = _p('pres');
final paci = _p('paci');
final a = _p('a');
final b = _p('b');
final c = _p('c');

GameEngine table() => GameEngine(
  GameSetup.fromRoles({
    mob: Role.mafioso,
    mob2: Role.mafioso,
    gun: Role.artigliere,
    doc: Role.medico,
    vet: Role.reduce,
    pres: Role.presidente,
    paci: Role.pacifista,
    a: Role.cittadino,
    b: Role.cittadino,
    c: Role.cittadino,
  }),
  seed: 3,
);

void quietNight(GameEngine engine, {Player? save}) {
  if (save != null) engine.apply(NightAction(doc.id, save.id));
  for (final player in engine.pendingNightPlayers) {
    engine.apply(Pass(player.id));
  }
  engine.resolveNight();
}

/// Al secondo giorno, con la prima notte e il primo giorno tranquilli.
GameEngine dayTwo() {
  final engine = table();
  quietNight(engine);
  expect(engine.fireTargets(gun), isEmpty, reason: 'il primo giorno non spara');
  expect(engine.apply(Fire(gun.id, mob.id)).accepted, isFalse);
  engine.closeDayVote();
  quietNight(engine);
  return engine;
}

void main() {
  test('entra da 10 giocatori, L3, colpo extra', () {
    expect(Role.artigliere.rule.minPlayers, 10);
    expect(Role.artigliere.rule.tier, RoleTier.l3);
    expect(Role.artigliere.rule.category, RoleCategory.extraKill);
    expect(Role.artigliere.team, Team.citizens);
  });

  test('mai con Cecchino, Piromane o Sicario', () {
    for (var seed = 0; seed < 400; seed++) {
      final deck = rolesForPlayerCount(12, random: Random(seed), mode: PlayMode.online);
      if (!deck.contains(Role.artigliere)) continue;
      expect(deck, isNot(contains(Role.cecchino)));
      expect(deck, isNot(contains(Role.piromane)));
      expect(deck, isNot(contains(Role.sicario)));
    }
  });

  test('di giorno dal secondo: il colpito muore subito, carte pubbliche', () {
    final engine = dayTwo();
    expect(engine.phase, GamePhase.day);
    expect(engine.knowledgeOf(null, gun).role, isNull, reason: 'segreto fino al primo colpo');
    expect(engine.fireTargets(gun), isNot(contains(pres)), reason: 'al Presidente non spara');
    expect(engine.fireTargets(gun), isNot(contains(gun)));
    engine.apply(DayVote(a.id, vet.id));
    expect(engine.apply(Fire(gun.id, vet.id)).accepted, isTrue);
    // Di giorno il Reduce non ha pelle dura.
    expect(engine.isAlive(vet), isFalse);
    expect(engine.knowledgeOf(null, vet).role, Role.reduce);
    expect(engine.knowledgeOf(null, gun).role, Role.artigliere);
    expect(engine.dayVotes.values, isNot(contains(vet)), reason: 'i voti sul morto si annullano');
    expect(engine.history.last.dayVictims, [vet]);
    expect(engine.shotsLeft, 1);
    // Uno al giorno.
    expect(engine.apply(Fire(gun.id, a.id)).accepted, isFalse);
    expect(engine.viewFor(gun.id).fireTargets, isEmpty);
    expect(engine.viewFor(gun.id).shotsLeft, 1);
    expect(engine.viewFor(a.id).shotsLeft, isNull);
    final board = engine.publicView();
    expect(board.shots.single.target, vet);
    expect(board.shots.single.role, Role.reduce);
  });

  test('il Dottore non salva dal colpo di giorno; due colpi in tutto', () {
    final engine = table();
    quietNight(engine);
    engine.closeDayVote();
    quietNight(engine, save: a);
    engine.fire(gun, a);
    expect(engine.isAlive(a), isFalse);
    engine.closeDayVote();
    quietNight(engine);
    engine.fire(gun, b);
    engine.closeDayVote();
    quietNight(engine);
    expect(engine.shotsLeft, 0);
    expect(engine.canFire(gun), isFalse);
    expect(engine.apply(Fire(gun.id, c.id)).accepted, isFalse);
  });

  test('la tregua del Pacifista non lo ferma; il colpo all\'ultimo mafioso chiude la partita', () {
    final engine = dayTwo();
    engine.pacify(paci, b);
    engine.fire(gun, mob);
    expect(engine.phase, GamePhase.day);
    engine.closeDayVote();
    quietNight(engine);
    if (!engine.isAlive(mob2)) return;
    engine.fire(gun, mob2);
    expect(engine.phase, GamePhase.ended);
    expect(engine.winner, Team.citizens);
  });

  test('colpire un innamorato uccide anche l\'altro, a carta coperta', () {
    final engine = GameEngine(
      GameSetup.fromRoles({
        mob: Role.mafioso,
        gun: Role.artigliere,
        _p('cupid'): Role.cupido,
        a: Role.cittadino,
        b: Role.cittadino,
        c: Role.cittadino,
      }),
      seed: 1,
    );
    engine.apply(Link('cupid', a.id, b.id));
    quietNight(engine);
    engine.closeDayVote();
    quietNight(engine);
    final shot = engine.fire(gun, a);
    expect(shot.heartbroken, b);
    expect(engine.isAlive(b), isFalse);
    expect(engine.knowledgeOf(null, b).role, isNull);
  });

  test('la taglia colpita scade: il Cacciatore passa con la Città', () {
    final hunter = _p('hunter');
    final engine = GameEngine(
      GameSetup.fromRoles({
        mob: Role.mafioso,
        mob2: Role.mafioso,
        gun: Role.artigliere,
        hunter: Role.cacciatore,
        a: Role.cittadino,
        b: Role.cittadino,
        c: Role.cittadino,
      }),
      seed: 4,
    );
    final mark = engine.bountyOf(hunter)!;
    quietNight(engine);
    engine.closeDayVote();
    quietNight(engine);
    if (mark == gun) return;
    engine.fire(gun, mark);
    expect(engine.bountyLapsed(hunter), isTrue);
  });

  test('fotografia, filo e rigiocata tengono i colpi', () {
    final engine = dayTwo();
    engine.fire(gun, a);
    final copy = GameEngine.fromSnapshot(GameSnapshot.fromJson(jsonDecode(jsonEncode(engine.snapshot().toJson()))));
    expect(copy.shotsLeft, 1);
    expect(copy.firedToday, isTrue);
    expect(copy.shots.single.target.id, a.id);
    final replay = GameEngine.replay(engine.setup, seed: engine.seed!, log: engine.log);
    expect(replay.isAlive(a), isFalse);
    expect(replay.shots.single.role, Role.cittadino);
    final view = PlayerView.fromJson(wire(engine.viewFor(gun.id).toJson()));
    expect(view.shotsLeft, 1);
    expect(view.board.shots.single.target.id, a.id);
    for (final player in engine.setup.players) {
      expect(leaksIn(engine, player, wire(engine.viewFor(player.id).toJson())), isEmpty, reason: player.id);
    }
    expect(leaksIn(engine, null, wire(engine.publicView().toJson())), isEmpty);
  });

  test('di notte non si spara', () {
    final engine = table();
    expect(engine.apply(Fire(gun.id, a.id)), isA<IntentRejected>());
    expect(engine.taskFor(gun).kind, NightTaskKind.decoy);
  });
}
