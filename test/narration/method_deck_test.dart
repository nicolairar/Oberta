import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/narration/method_deck.dart';
import 'package:oberta/narration/narration_pack.dart';

void main() {
  const methods = [
    StoryPiece('a', 'a'),
    StoryPiece('b', 'b'),
    StoryPiece('c', 'c'),
    StoryPiece('d', 'd'),
    StoryPiece('e', 'e'),
  ];

  test('ogni azione esce una volta prima che una si ripeta', () {
    for (var seed = 0; seed < 20; seed++) {
      final deck = MethodDeck(Random(seed));
      for (var round = 0; round < 6; round++) {
        final hand = [for (var i = 0; i < methods.length; i++) deck.draw(methods).id];
        expect(hand.toSet(), hasLength(methods.length), reason: 'seme $seed, giro $round');
      }
    }
  });

  test('anche a cavallo di due mazzi non esce mai la stessa due volte di fila', () {
    for (var seed = 0; seed < 50; seed++) {
      final deck = MethodDeck(Random(seed));
      var previous = deck.draw(methods).id;
      for (var i = 0; i < 60; i++) {
        final current = deck.draw(methods).id;
        expect(current, isNot(previous), reason: 'seme $seed, pescata $i');
        previous = current;
      }
    }
  });

  test('con una sola azione, esce sempre quella', () {
    final deck = MethodDeck(Random(1));
    expect(deck.draw(const [StoryPiece('solo', 'solo')]).id, 'solo');
    expect(deck.draw(const [StoryPiece('solo', 'solo')]).id, 'solo');
  });
}
