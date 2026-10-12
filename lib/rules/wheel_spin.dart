import 'dart:math';

/// Risultato di un giro di ruota, deciso prima che l'animazione parta.
///
/// Chi decide (host o server) pubblica solo [finalAngle]: ogni telefono anima
/// la stessa rotazione e si ferma nello stesso punto.
class WheelSpin {
  final int segmentCount;
  final int winnerIndex;

  /// Rotazione totale in radianti, in senso orario, partendo da zero.
  final double finalAngle;

  const WheelSpin._(this.segmentCount, this.winnerIndex, this.finalAngle);

  factory WheelSpin.towards({
    required int segmentCount,
    required int winnerIndex,
    Random? random,
    int fullTurns = 6,
  }) {
    RangeError.checkValidIndex(winnerIndex, null, 'winnerIndex', segmentCount);
    final sweep = 2 * pi / segmentCount;
    // Non si ferma mai al centro esatto né sul bordo dello spicchio.
    final jitter = ((random ?? Random()).nextDouble() - 0.5) * 0.7;
    final angle = 2 * pi * fullTurns - (winnerIndex + 0.5 + jitter) * sweep;
    return WheelSpin._(segmentCount, winnerIndex, angle);
  }

  factory WheelSpin.random({required int segmentCount, Random? random}) {
    final rng = random ?? Random();
    return WheelSpin.towards(
      segmentCount: segmentCount,
      winnerIndex: rng.nextInt(segmentCount),
      random: rng,
    );
  }

  /// Spicchio sotto la freccia (in alto) quando la ruota è ruotata di [angle].
  /// Lo spicchio 0 parte da ore 12 e gli indici crescono in senso orario.
  static int indexAtAngle(double angle, int segmentCount) {
    final sweep = 2 * pi / segmentCount;
    return ((-angle % (2 * pi)) / sweep).floor() % segmentCount;
  }
}
