import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/narration/death_story.dart';
import 'package:oberta/narration/english_pack.dart';
import 'package:oberta/narration/italian_pack.dart';
import 'package:oberta/narration/method_deck.dart';
import 'package:oberta/narration/narration_pack.dart';
import 'package:oberta/narration/narrator_script.dart';
import 'package:oberta/narration/picker.dart';
import 'package:oberta/rules/game_engine.dart';
import 'package:oberta/rules/player.dart';

const sara = Player(id: 'sara', name: 'Sara');

DawnReport spared(AttackOutcome outcome, {AttackSource source = AttackSource.family}) =>
    DawnReport(round: 2, attacks: [NightAttack(sara, source, outcome)]);

void main() {
  group('gli agguati andati a vuoto pescano dal mazzo delle morti', () {
    test('il Dottore rimedia ad agguati sempre diversi, con un rimedio che ci sta', () {
      final script = NarratorScript(random: Random(4));
      final attacks = <String>[];
      final variants = <String>{};
      for (var i = 0; i < 40; i++) {
        final story = script.stage(spared(AttackOutcome.healed)).single;
        final attack = story.attack!;
        expect(italianPack.methods.map((method) => method.id), contains(attack.id));
        expect(DeathStory.rescuesFor(attack.id), contains(story.method.id), reason: attack.id);
        expect(story.survived, isTrue);
        expect(story.fact, italianPack.savedFact);
        attacks.add(attack.id);
        variants.add(story.method.id);
      }
      expect(attacks.toSet().length, greaterThanOrEqualTo(15), reason: 'non sempre lo stesso agguato');
      for (var i = 1; i < attacks.length; i++) {
        expect(attacks[i], isNot(attacks[i - 1]), reason: 'mai lo stesso due volte di fila');
      }
      expect(variants, DeathStory.rescueIds.toSet(), reason: 'tutti i rimedi del Dottore');
    });

    test('la fortuna ferma agguati diversi, con un colpo di fortuna che ci sta', () {
      final script = NarratorScript(random: Random(9));
      final attacks = <String>{};
      final variants = <String>{};
      for (var i = 0; i < 40; i++) {
        final story = script.stage(spared(AttackOutcome.shrugged)).single;
        final attack = story.attack!;
        expect(DeathStory.luckFor(attack.id), contains(story.method.id), reason: attack.id);
        expect(story.fact, italianPack.shruggedFact);
        attacks.add(attack.id);
        variants.add(story.method.id);
      }
      expect(attacks.length, greaterThanOrEqualTo(5));
      expect(variants, DeathStory.luckyIds.toSet());
    });

    test('anche quando spara il Cecchino: al tavolo non si capisce chi è stato', () {
      final script = NarratorScript(random: Random(2));
      for (final outcome in [AttackOutcome.healed, AttackOutcome.shrugged]) {
        final story = script.stage(spared(outcome, source: AttackSource.sniper)).single;
        expect(story.attack, isNotNull);
        expect(DeathStory.sniperIds, isNot(contains(story.method.id)));
      }
    });

    test('morti e salvataggi si passano lo stesso mazzo: un agguato non torna subito', () {
      final script = NarratorScript(random: Random(11));
      String idOf(DeathStory story) => (story.attack ?? story.method).id;
      final drawn = <String>[];
      for (var i = 0; i < 60; i++) {
        final outcome = i.isEven ? AttackOutcome.killed : AttackOutcome.healed;
        drawn.add(idOf(script.stage(spared(outcome)).single));
      }
      for (var i = 1; i < drawn.length; i++) {
        expect(drawn[i], isNot(drawn[i - 1]), reason: 'pescata $i');
      }
    });

    test('solo gli agguati che lasciano la vittima sulla strada hanno il Dottore', () {
      for (final id in ['pianoforte', 'cassaforte', 'lampadario', 'cappio', 'cemento', 'tombino', 'arpione', 'lavanderia']) {
        expect(DeathStory.rescuesFor(id), isEmpty, reason: id);
      }
      expect(DeathStory.rescuesFor('veleno'), isNot(contains(DeathStory.pliersId)), reason: 'nel caffè non c\'è piombo');
      expect(DeathStory.rescuesFor('lupara'), contains(DeathStory.pliersId));
      expect(DeathStory.rescuesFor('pugnale'), contains(DeathStory.stitchesId));
      expect(DeathStory.rescuesFor('pugnale'), isNot(contains(DeathStory.pliersId)));
    });
  });

  group('le battute dicono quello che si vede', () {
    // Le varianti che vanno anche con agguati senza pistola non parlano di
    // spari: l'agguato può essere un pugnale, un caffè, una torta.
    void checkNoShots(NarrationPack pack, RegExp shots) {
      final unarmed = {
        for (final method in pack.methods) ...[
          if (!{'silenziatore', 'violino', 'lupara', 'raffica', 'trombone', 'rose'}.contains(method.id)) ...[
            ...DeathStory.rescuesFor(method.id),
            ...DeathStory.luckFor(method.id),
          ],
        ],
      };
      for (final id in unarmed) {
        for (final line in [...?pack.rescues[id], ...?pack.shrugs[id]]) {
          expect(line, isNot(contains(shots)), reason: '$id: $line');
        }
      }
      for (final fact in [pack.savedFact, pack.shruggedFact]) {
        expect(fact, isNot(contains(shots)), reason: fact);
      }
    }

    test('in italiano', () => checkNoShots(italianPack, RegExp(r'spar|proiettil|pistol|piombo', caseSensitive: false)));
    test('in inglese', () => checkNoShots(englishPack, RegExp(r'shot|bullet|\bgun\b|lead\b|slug', caseSensitive: false)));

    test('chi la scampa resta anonimo, qualunque sia l\'agguato', () {
      final script = NarratorScript(random: Random(5));
      for (var i = 0; i < 40; i++) {
        final outcome = i.isEven ? AttackOutcome.healed : AttackOutcome.shrugged;
        final lines = script.dawn(spared(outcome), discussion: const Duration(minutes: 3));
        expect(lines.map((line) => line.text).join(' '), isNot(contains('Sara')));
      }
    });
  });

  group('il mazzo e il sorteggio sanno pescare solo fra quelli buoni', () {
    const methods = [
      StoryPiece('a', 'a'),
      StoryPiece('b', 'b'),
      StoryPiece('c', 'c'),
      StoryPiece('d', 'd'),
      StoryPiece('e', 'e'),
    ];

    test('il mazzo dà la più in alto fra quelle buone, e lascia le altre al loro posto', () {
      for (var seed = 0; seed < 20; seed++) {
        final deck = MethodDeck(Random(seed));
        final picked = deck.draw(methods, where: (method) => method.id == 'c' || method.id == 'd');
        expect(['c', 'd'], contains(picked.id));
        // Il resto del giro: le altre quattro, una volta sola ciascuna.
        final rest = [for (var i = 0; i < 4; i++) deck.draw(methods).id];
        expect(rest.toSet(), methods.map((method) => method.id).toSet().difference({picked.id}), reason: 'seme $seed');
      }
    });

    test('se nel mazzo non ce ne sono più, ne pesca una lo stesso', () {
      final deck = MethodDeck(Random(3));
      for (var i = 0; i < 10; i++) {
        expect(deck.draw(methods, where: (method) => method.id == 'a').id, 'a');
      }
    });

    test('il sorteggio tiene la memoria anche quando si sceglie fra pochi', () {
      final picker = Picker(Random(7));
      const options = ['a', 'b', 'c', 'd'];
      final picks = [for (var i = 0; i < 40; i++) picker.pick('pool', options, where: (o) => o != 'd')];
      expect(picks, isNot(contains('d')));
      for (var i = 1; i < picks.length; i++) {
        expect(picks[i], isNot(picks[i - 1]));
      }
      expect(picker.pick('pool', options, where: (o) => o == 'a'), 'a', reason: 'anche se è fresca di memoria');
    });
  });
}
