import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/rules/game_engine.dart';
import 'package:oberta/rules/game_setup.dart';
import 'package:oberta/rules/game_snapshot.dart';
import 'package:oberta/rules/intent.dart';
import 'package:oberta/rules/player.dart';
import 'package:oberta/rules/role.dart';

import 'player_view_test.dart' show leaksIn, wire;

// Il Capo della setta (docs/ruoli.md, 0 e 3.9).

Player _p(String id) => Player(id: id, name: id);

final mob = _p('mob');
final cult = _p('cult');
final cop = _p('cop');
final doc = _p('doc');
final a = _p('a');
final b = _p('b');

GameEngine table() => GameEngine(
  GameSetup.fromRoles({
    mob: Role.mafioso,
    cult: Role.capoSetta,
    cop: Role.detective,
    doc: Role.medico,
    a: Role.cittadino,
    b: Role.cittadino,
  }),
  seed: 6,
);

DawnReport night(GameEngine engine, Map<Player, Player> moves) {
  for (final MapEntry(key: actor, value: target) in moves.entries) {
    final kill = engine.setup.roleOf(actor) == Role.mafioso;
    engine.apply(kill ? MafiaVote(actor.id, target.id) : NightAction(actor.id, target.id));
  }
  for (final player in engine.pendingNightPlayers) {
    engine.apply(Pass(player.id));
  }
  return engine.resolveNight();
}

void main() {
  test('converte: lo sa il Capo e il convertito, nessun altro; il Commissario non lo vede', () {
    final engine = table();
    night(engine, {cult: a});
    expect(engine.viewFor(cult.id).sect, [a]);
    expect(engine.viewFor(a.id).converted, isTrue);
    expect(engine.viewFor(a.id).sect, isEmpty, reason: 'non sa chi è il Capo né chi altro c\'è');
    expect(engine.viewFor(b.id).converted, isFalse);
    expect(leaksIn(engine, a, wire(engine.viewFor(a.id).toJson())), isEmpty);
    engine.lynch(null);
    night(engine, {cop: a});
    expect(engine.knowledgeOf(cop, a).team, Team.citizens);
  });

  test('la Famiglia, chi è protetto e chi è in cella non si convertono: porta chiusa', () {
    final engine = table();
    night(engine, {cult: mob});
    expect(engine.viewFor(cult.id).sect, isEmpty);
    expect(engine.viewFor(cult.id).doors.single.target, mob);
    engine.lynch(null);
    night(engine, {cult: b, doc: b});
    expect(engine.viewFor(b.id).converted, isFalse);
    expect(engine.viewFor(cult.id).doors.length, 2);
  });

  test('vince la setta quando tutti i vivi sono dei suoi; i convertiti vincono con lei, non con la loro squadra', () {
    final engine = GameEngine(
      GameSetup.fromRoles({cult: Role.capoSetta, a: Role.cittadino, b: Role.cittadino, mob: Role.mafioso}),
      seed: 1,
    );
    night(engine, {cult: a});
    engine.lynch(mob);
    expect(engine.winner, isNull, reason: 'finché il Capo vive la Città non vince');
    night(engine, {cult: b});
    expect(engine.winner, Team.neutral);
    expect(engine.personalWins, containsAll([cult, a, b]));
    expect(engine.hasWon(a), isTrue);
  });

  test('morto il Capo la setta si scioglie: i convertiti tornano alla loro squadra', () {
    final engine = table();
    night(engine, {cult: a});
    engine.lynch(cult);
    expect(engine.viewFor(a.id).converted, isFalse);
    night(engine, {});
    engine.lynch(mob);
    expect(engine.winner, Team.citizens);
    expect(engine.hasWon(a), isTrue);
  });

  test('la fotografia riporta la setta', () {
    final engine = table();
    night(engine, {cult: a});
    final again = GameEngine.fromSnapshot(GameSnapshot.fromJson(wire(engine.snapshot().toJson())));
    expect(jsonEncode(again.snapshot().toJson()), jsonEncode(engine.snapshot().toJson()));
  });
}
