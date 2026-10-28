import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/online/game/match_rewards.dart';
import 'package:oberta/online/game/progress.dart';
import 'package:oberta/online/shop_models.dart';

/// The earn-only economy, as a model (docs/economia.md): how long a player
/// needs to earn each class of the shop with the real numbers of the game
/// (Progression, the mission pool, the prices). Expected values, no luck.
///
/// A casual player: 4 days a week, 3 games a day, wins 45% of them, claims
/// two of the three daily missions and one of the three weekly ones.
class _Player {
  final int daysPerWeek;
  final int gamesPerDay;
  final double winRate;
  final int dailyDone;
  final int weeklyDone;

  const _Player({required this.daysPerWeek, required this.gamesPerDay, required this.winRate, required this.dailyDone, required this.weeklyDone});

  static const casual = _Player(daysPerWeek: 4, gamesPerDay: 3, winRate: 0.45, dailyDone: 2, weeklyDone: 1);
  static const regular = _Player(daysPerWeek: 6, gamesPerDay: 5, winRate: 0.5, dailyDone: 3, weeklyDone: 2);
}

double _avg(Iterable<int> xs) => xs.reduce((a, b) => a + b) / xs.length;

/// The average reward of one mission of [cadence] from pool [k].
(double xp, double coins) _pool(String cadence, int k) {
  final defs = missionPool.where((m) => m.cadence == cadence && m.pool == k);
  return (_avg(defs.map((m) => m.xp)), _avg(defs.map((m) => m.coins)));
}

/// Coins earned day by day, for [days] days, starting at level 1.
List<double> _coinsByDay(_Player p, int days) {
  var level = 1;
  var xp = 0.0;
  var coins = 0.0;
  final out = <double>[];
  for (var day = 0; day < days; day++) {
    final weekDay = day % 7;
    if (weekDay < p.daysPerWeek) {
      final firstWin = 1 - pow(1 - p.winRate, p.gamesPerDay);
      var dayXp = p.gamesPerDay * (p.winRate * Progression.winXp + (1 - p.winRate) * Progression.lossXp) +
          firstWin * Progression.firstWinOfDayXp;
      coins += p.gamesPerDay * (p.winRate * Progression.winCoins + (1 - p.winRate) * Progression.lossCoins) +
          firstWin * Progression.firstWinOfDayCoins;
      for (var k = 1; k <= p.dailyDone; k++) {
        final (mx, mc) = _pool('daily', k);
        dayXp += mx;
        coins += mc;
      }
      if (weekDay == p.daysPerWeek - 1) {
        for (var k = 1; k <= p.weeklyDone; k++) {
          final (mx, mc) = _pool('weekly', k);
          dayXp += mx;
          coins += mc;
        }
      }
      xp += dayXp;
      while (xp >= Progression.xpToNext(level)) {
        xp -= Progression.xpToNext(level);
        level++;
        coins += Progression.coinsForLevel(level);
      }
    }
    out.add(coins);
  }
  return out;
}

/// Days until [price] coins, saving from zero from day [from] on (a new
/// player climbs the first levels fast; a month in, the pace is steady).
int _daysFor(_Player p, int price, {int from = 28}) {
  final byDay = _coinsByDay(p, from + 400);
  final start = from == 0 ? 0.0 : byDay[from - 1];
  for (var d = from; d < byDay.length; d++) {
    if (byDay[d] - start >= price) return d - from + 1;
  }
  return 999;
}

void main() {
  final shopPrices = [for (final item in initialShopCatalog) if (!item.free && !item.exclusive) item.price];
  final dearest = shopPrices.reduce(max);

  test('the targets: a common in two games, a rare in about a week, a legendary in one or two months', () {
    const casual = _Player.casual;
    // Two games on the first day (one of them won): the level, the game
    // and the first win of the day are enough for a common piece.
    final firstDay = Progression.coinsForLevel(2) +
        Progression.winCoins +
        Progression.firstWinOfDayCoins +
        Progression.lossCoins +
        _pool('daily', 1).$2;
    expect(firstDay, greaterThanOrEqualTo(ShopRarity.comune.price));
    expect(_daysFor(casual, ShopRarity.comune.price, from: 0), 1, reason: 'common: the first evening');
    expect(_daysFor(casual, ShopRarity.raro.price), inInclusiveRange(3, 9), reason: 'rare: one week of play');
    expect(_daysFor(casual, ShopRarity.epico.price), inInclusiveRange(8, 21), reason: 'epic: one to three weeks');
    expect(_daysFor(casual, ShopRarity.leggendario.price), inInclusiveRange(21, 40), reason: 'legendary: about a month');
    expect(_daysFor(casual, dearest), inInclusiveRange(35, 65), reason: 'the dearest deep piece: one to two months');
    // A new player climbs fast: the first legendary comes sooner.
    expect(_daysFor(casual, ShopRarity.leggendario.price, from: 0), lessThan(_daysFor(casual, ShopRarity.leggendario.price)));
    // Someone who plays nearly every day gets there at least twice as fast.
    expect(_daysFor(_Player.regular, ShopRarity.leggendario.price), lessThanOrEqualTo(_daysFor(casual, ShopRarity.leggendario.price) / 2));
  });

  test('a casual week, after the first month, is worth about one rare piece', () {
    final byDay = _coinsByDay(_Player.casual, 70);
    final week = byDay[69] - byDay[62];
    expect(week, inInclusiveRange(600, 1000));
  });
}
