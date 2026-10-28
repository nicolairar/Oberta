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

import 'player_view_test.dart' show wire;

// Il Presidente (docs/ruoli.md, 0 e 3.8).

Player _p(String id) => Player(id: id, name: id);

final mob = _p('mob');
final mob2 = _p('mob2');
final pres = _p('pres');
final doc = _p('doc');
final sniper = _p('sniper');
final a = _p('a');
final b = _p('b');
final c = _p('c');

GameEngine table() => GameEngine(
  GameSetup.fromRoles({
    mob: Role.mafioso,
    mob2: Role.mafioso,
    pres: Role.presidente,
    doc: Role.medico,
    sniper: Role.cecchino,
    a: Role.cittadino,
    b: Role.cittadino,
    c: Role.cittadino,
  }),
  seed: 2,
);

DawnReport night(GameEngine engine, {Player? hit, Player? save}) {
  if (hit != null) {
    engine.apply(MafiaVote(mob.id, hit.id));
    engine.apply(MafiaVote(mob2.id, hit.id));
  }
  if (save != null) engine.apply(NightAction(doc.id, save.id));
  for (final player in engine.pendingNightPlayers) {
    engine.apply(Pass(player.id));
  }
  return engine.resolveNight();
}

void main() {
  test('tutti lo sanno dall\'inizio, e nessuno lo vota né gli spara', () {
    final engine = table();
    expect(engine.knowledgeOf(null, pres).role, Role.presidente);
    expect(engine.publicView().escortLeft, 2);
    expect(engine.taskFor(sniper).targets, isNot(contains(pres)));
    night(engine);
    expect(engine.viewFor(a.id).action!.targets, isNot(contains(pres)));
    expect(engine.apply(DayVote(a.id, pres.id)), isA<IntentRejected>());
    expect(() => engine.lynch(pres), throwsArgumentError);
  });

  test('la scorta para le prime due notti di attacco; alla terza muore e la Città perde', () {
    final engine = table();
    var dawn = night(engine, hit: pres);
    expect(dawn.attacks.single.outcome, AttackOutcome.escorted);
    expect(engine.isAlive(pres), isTrue);
    expect(engine.publicView().escortLeft, 1);
    engine.lynch(null);
    // Il Dottore lo copre: la scorta non si spende.
    dawn = night(engine, hit: pres, save: pres);
    expect(dawn.attacks.single.outcome, AttackOutcome.healed);
    expect(engine.publicView().escortLeft, 1);
    engine.lynch(null);
    dawn = night(engine, hit: pres);
    expect(dawn.attacks.single.outcome, AttackOutcome.escorted);
    engine.lynch(null);
    dawn = night(engine, hit: pres);
    expect(dawn.attacks.single.outcome, AttackOutcome.killed);
    expect(engine.winner, Team.mafia);
    expect(engine.presidentFallen, isTrue);
  });

  test('la fotografia riporta la scorta spesa', () {
    final engine = table();
    night(engine, hit: pres);
    final again = GameEngine.fromSnapshot(GameSnapshot.fromJson(wire(engine.snapshot().toJson())));
    expect(jsonEncode(again.snapshot().toJson()), jsonEncode(engine.snapshot().toJson()));
    expect(again.escortLeft, 1);
  });

  test('nel mazzo: da 10 giocatori, pesa −2, mai con chi uccide in proprio', () {
    expect(Role.presidente.points, -2);
    final random = Random(9);
    var seen = false;
    for (var i = 0; i < 3000; i++) {
      final deck = rolesForPlayerCount(10 + random.nextInt(3), random: random, mode: PlayMode.online);
      if (!deck.contains(Role.presidente)) continue;
      seen = true;
      expect(deck.any((r) => r.isHostileNeutral), isFalse, reason: '$deck');
    }
    expect(seen, isTrue);
  });
}
