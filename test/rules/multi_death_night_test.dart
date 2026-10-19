import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/narration/narrator_script.dart';
import 'package:oberta/rules/game_engine.dart';
import 'package:oberta/rules/game_setup.dart';
import 'package:oberta/rules/player.dart';
import 'package:oberta/rules/role.dart';

Player _p(String id) => Player(id: id, name: id);

void main() {
  test('una notte con famiglia, Sicario e Dottore: due morti, tutti e due sul giornale', () {
    final mob = _p('mob'), hit = _p('hit'), doc = _p('doc');
    final a = _p('anna'), b = _p('bruno'), c = _p('carla'), d = _p('dario'), e = _p('elsa');
    final engine = GameEngine(
      GameSetup.fromRoles({
        mob: Role.mafioso,
        hit: Role.sicario,
        doc: Role.medico,
        a: Role.cittadino,
        b: Role.cittadino,
        c: Role.cittadino,
        d: Role.cittadino,
        e: Role.cittadino,
      }),
      seed: 3,
    );
    engine.submitNightChoice(mob, a);
    engine.submitNightChoice(hit, b);
    engine.submitNightChoice(doc, c);
    for (final player in engine.pendingNightPlayers) {
      engine.submitNightChoice(player, null);
    }
    final dawn = engine.resolveNight();
    expect(dawn.victims, [a, b]);
    expect(dawn.attacks.map((x) => (x.target, x.outcome)), [(a, AttackOutcome.killed), (b, AttackOutcome.killed)]);
    final lines = NarratorScript(random: Random(1)).dawn(dawn, discussion: const Duration(seconds: 60), online: true);
    final text = lines.map((line) => line.text).join('\n');
    expect(text, contains('anna'));
    expect(text, contains('bruno'));
  });
}
