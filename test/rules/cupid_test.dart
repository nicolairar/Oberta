import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/rules/game_engine.dart';
import 'package:oberta/rules/game_setup.dart';
import 'package:oberta/rules/game_snapshot.dart';
import 'package:oberta/rules/intent.dart';
import 'package:oberta/rules/player.dart';
import 'package:oberta/rules/role.dart';

import 'player_view_test.dart' show leaksIn, wire;

// Cupido e gli innamorati (docs/ruoli.md, 0 e 3.7).

Player _p(String id) => Player(id: id, name: id);

final mob = _p('mob');
final mob2 = _p('mob2');
final cupid = _p('cupid');
final doc = _p('doc');
final messiah = _p('messiah');
final a = _p('a');
final b = _p('b');
final c = _p('c');

GameEngine table(Map<Player, Role> roles) => GameEngine(GameSetup.fromRoles(roles), seed: 4);

Map<Player, Role> roles() => {
  mob: Role.mafioso,
  mob2: Role.mafioso,
  cupid: Role.cupido,
  doc: Role.medico,
  a: Role.cittadino,
  b: Role.cittadino,
  c: Role.cittadino,
};

DawnReport endNight(GameEngine engine) {
  for (final player in engine.pendingNightPlayers) {
    engine.apply(Pass(player.id));
  }
  return engine.resolveNight();
}

void main() {
  test('la prima notte Cupido lega due persone, una volta sola; poi non fa più niente', () {
    final engine = table(roles());
    expect(engine.taskFor(cupid).kind, NightTaskKind.link);
    expect(engine.taskFor(cupid).targets, contains(cupid), reason: 'anche se stesso');
    expect(engine.apply(NightAction(cupid.id, a.id)), isA<IntentRejected>(), reason: 'servono due nomi');
    expect(engine.apply(Link(cupid.id, a.id, a.id)), isA<IntentRejected>());
    expect(engine.apply(Link(cupid.id, mob.id, a.id)).accepted, isTrue);
    expect(engine.apply(Link(cupid.id, b.id, c.id)), isA<IntentRejected>(), reason: 'non si cambia');
    // Cupido li conosce subito; loro dalla prima alba, solo il nome.
    expect(engine.viewFor(cupid.id).lovers, [mob, a]);
    expect(engine.viewFor(a.id).lovers, isEmpty);
    endNight(engine);
    expect(engine.viewFor(a.id).lovers, [mob, a]);
    expect(engine.viewFor(mob.id).lovers, [mob, a]);
    expect(engine.viewFor(b.id).lovers, isEmpty);
    expect(engine.knowledgeOf(a, mob).isEmpty, isTrue, reason: 'il nome, non il ruolo');
    expect(leaksIn(engine, a, wire(engine.viewFor(a.id).toJson())), isEmpty);
    engine.lynch(null);
    expect(engine.taskFor(cupid).kind, NightTaskKind.decoy);
  });

  test('se uno muore di notte, l\'altro muore di crepacuore, e niente lo ferma', () {
    final engine = table(roles());
    engine.apply(Link(cupid.id, a.id, b.id));
    engine.apply(MafiaVote(mob.id, a.id));
    engine.apply(MafiaVote(mob2.id, a.id));
    engine.apply(NightAction(doc.id, b.id));
    final dawn = endNight(engine);
    expect(dawn.heartbroken, [b]);
    expect(dawn.victims, containsAll([a, b]));
    expect(engine.isAlive(b), isFalse);
    expect(engine.knowledgeOf(null, b).isEmpty, isTrue, reason: 'la carta resta coperta');
  });

  test('se uno sale sul patibolo, l\'altro lo segue sul posto', () {
    final engine = table(roles());
    engine.apply(Link(cupid.id, a.id, b.id));
    endNight(engine);
    final report = engine.lynch(a);
    expect(report.heartbroken, b);
    expect(engine.isAlive(b), isFalse);
    expect(engine.history.last.dayVictims, [b]);
  });

  test('vincono solo vivi tutti e due, chiunque vinca: anche contro la loro squadra', () {
    final engine = table({mob: Role.mafioso, cupid: Role.cupido, a: Role.cittadino, b: Role.cittadino, c: Role.cittadino});
    engine.apply(Link(cupid.id, mob.id, a.id));
    endNight(engine);
    engine.lynch(b);
    engine.apply(MafiaVote(mob.id, c.id));
    endNight(engine);
    engine.lynch(cupid);
    expect(engine.winner, Team.mafia);
    expect(engine.hasWon(mob), isTrue);
    expect(engine.hasWon(a), isTrue, reason: 'innamorato del mafioso, vivo: vince anche lui');
    expect(engine.loversWon, isTrue);
    expect(engine.hasWon(cupid), isFalse);
  });

  test('un innamorato morto: la sua squadra può vincere, lui no', () {
    final engine = table(roles());
    engine.apply(Link(cupid.id, a.id, b.id));
    engine.apply(MafiaVote(mob.id, a.id));
    engine.apply(MafiaVote(mob2.id, a.id));
    endNight(engine);
    engine.lynch(mob);
    endNight(engine);
    engine.lynch(mob2);
    expect(engine.winner, Team.citizens);
    expect(engine.hasWon(c), isTrue);
    expect(engine.hasWon(a), isFalse);
    expect(engine.hasWon(b), isFalse);
  });

  test('il Messia riporta un innamorato: torna solo lui, e il legame si spezza', () {
    final engine = table({...roles(), messiah: Role.messia, c: Role.cittadino});
    engine.apply(Link(cupid.id, a.id, b.id));
    endNight(engine);
    engine.lynch(a);
    expect(engine.isAlive(b), isFalse);
    engine.apply(NightAction(messiah.id, a.id));
    endNight(engine);
    expect(engine.isAlive(a), isTrue);
    expect(engine.isAlive(b), isFalse);
    expect(engine.viewFor(a.id).lovers, isEmpty);
  });

  test('la fotografia e il registro riportano gli innamorati', () {
    final engine = table(roles());
    engine.apply(Link(cupid.id, a.id, b.id));
    endNight(engine);
    final again = GameEngine.fromSnapshot(GameSnapshot.fromJson(wire(engine.snapshot().toJson())));
    expect(jsonEncode(again.snapshot().toJson()), jsonEncode(engine.snapshot().toJson()));
    final replayed = GameEngine.replay(engine.setup, seed: engine.seed!, log: engine.log);
    expect(replayed.viewFor(a.id).lovers.map((p) => p.id), [a.id, b.id]);
  });
}
