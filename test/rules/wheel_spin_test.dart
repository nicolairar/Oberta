import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:omerta/rules/wheel_spin.dart';

void main() {
  test('la ruota si ferma sempre sullo spicchio deciso in partenza', () {
    final random = Random(11);
    for (var count = 2; count <= 16; count++) {
      for (var winner = 0; winner < count; winner++) {
        for (var attempt = 0; attempt < 20; attempt++) {
          final spin = WheelSpin.towards(segmentCount: count, winnerIndex: winner, random: random);
          expect(
            WheelSpin.indexAtAngle(spin.finalAngle, count),
            winner,
            reason: 'count=$count winner=$winner',
          );
        }
      }
    }
  });

  test('senza scarto si ferma esattamente al centro, come una camera sotto il cane', () {
    for (var count = 3; count <= 12; count++) {
      for (var winner = 0; winner < count; winner++) {
        final spin = WheelSpin.towards(segmentCount: count, winnerIndex: winner, spread: 0);
        final sweep = 2 * pi / count;
        final local = -spin.finalAngle % (2 * pi);
        expect(local, closeTo((winner + 0.5) * sweep, 1e-9), reason: 'count=$count winner=$winner');
      }
    }
  });

  test('fa diversi giri completi prima di fermarsi', () {
    final spin = WheelSpin.towards(segmentCount: 6, winnerIndex: 0, random: Random(1));
    expect(spin.finalAngle, greaterThan(2 * pi * 4));
  });

  test('da ferma la freccia indica il primo spicchio', () {
    expect(WheelSpin.indexAtAngle(0, 8), 0);
  });

  test('girando in senso orario passano sotto la freccia gli spicchi precedenti', () {
    const count = 4;
    const sweep = 2 * pi / count;
    expect(WheelSpin.indexAtAngle(sweep * 0.5, count), 3);
    expect(WheelSpin.indexAtAngle(sweep * 1.5, count), 2);
  });

  test('il sorteggio casuale copre tutti gli spicchi', () {
    final random = Random(2);
    final winners = {
      for (var i = 0; i < 200; i++) WheelSpin.random(segmentCount: 5, random: random).winnerIndex,
    };
    expect(winners, {0, 1, 2, 3, 4});
  });

  test('rifiuta un vincitore fuori dalla ruota', () {
    expect(() => WheelSpin.towards(segmentCount: 4, winnerIndex: 4), throwsRangeError);
  });
}
