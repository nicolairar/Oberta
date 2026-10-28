import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/online/game/match_rewards.dart';

SettleSeat _seat(
  String id, {
  required bool won,
  bool abandoned = false,
  Rating rating = Rating.initial,
  int xp = 0,
  int friendsGamesToday = 0,
}) =>
    SettleSeat(
      profile: id,
      seat: id,
      team: won ? 'mafia' : 'citizens',
      role: 'x',
      won: won,
      survived: true,
      abandoned: abandoned,
      rating: rating,
      xp: xp,
      friendsGamesToday: friendsGamesToday,
    );

void main() {
  group('esperienza, livelli e monete', () {
    test('la scala: 150 + 25·L, 50 monete a livello e 200 in più ogni cinque', () {
      expect(Progression.xpToNext(1), 175);
      expect(Progression.xpToNext(4), 250);
      expect(Progression.coinsForLevel(2), 50);
      expect(Progression.coinsForLevel(5), 250);
      final up = Progression.addXp(4, 200, 100);
      expect((up.level, up.xp, up.levelsGained, up.coins), (5, 50, 1, 250));
      final many = Progression.addXp(1, 0, 175 + 200 + 10);
      expect((many.level, many.xp, many.coins), (3, 10, 100));
    });

    test('vittoria 100, sconfitta 30, prima vittoria del giorno +100, chi abbandona nulla', () {
      expect(Progression.xpFor(won: true, abandoned: false, firstWinOfDay: true), 200);
      expect(Progression.xpFor(won: true, abandoned: false, firstWinOfDay: false), 100);
      expect(Progression.xpFor(won: false, abandoned: false, firstWinOfDay: false), 30);
      expect(Progression.xpFor(won: true, abandoned: true, firstWinOfDay: true), 0);
    });

    test('tra amici: esperienza sì, monete solo nelle prime cinque partite del giorno, niente da soli coi bot', () {
      final early = settle(ranked: false, humans: 2, seats: [_seat('a', won: true, xp: 100)]).single;
      expect((early.xpGained, early.level, early.coins, early.rating), (200, 2, 50 + 10 + 30, null), reason: 'level, win, first win of the day');
      expect(early.matchCoins, 40);
      final late = settle(ranked: false, humans: 2, seats: [_seat('a', won: true, xp: 100, friendsGamesToday: 5)]).single;
      expect((late.xpGained, late.level, late.coins), (200, 2, 0));
      final alone = settle(ranked: false, humans: 1, seats: [_seat('a', won: true)]).single;
      expect(alone.xpGained, 0);
    });
  });

  group('rating Weng-Lin', () {
    test('chi vince sale, chi perde scende, l\'incertezza cala', () {
      final out = settle(ranked: true, seats: [
        _seat('m1', won: true),
        _seat('m2', won: true),
        for (var i = 0; i < 6; i++) _seat('c$i', won: false),
      ]);
      for (final o in out) {
        expect(o.rating!.sigma, lessThan(WengLin.sigma0));
        expect(o.rating!.mu, o.seat.won ? greaterThan(25) : lessThan(25));
        expect(o.ordinalDelta! > 0, o.seat.won);
      }
    });

    test('battere i più forti vale di più; chi abbandona perde anche se la sua squadra vince', () {
      const strong = Rating(35, 3);
      final upset = settle(ranked: true, seats: [_seat('a', won: true), _seat('b', won: false, rating: strong)]);
      final expected = settle(ranked: true, seats: [_seat('a', won: true, rating: strong), _seat('b', won: false)]);
      expect(upset.first.rating!.mu - 25, greaterThan(expected.first.rating!.mu - 35));
      final left = settle(ranked: true, seats: [
        _seat('a', won: true),
        _seat('b', won: true, abandoned: true),
        _seat('c', won: false),
      ]);
      expect(left[1].rating!.mu, lessThan(25));
      expect(left[1].xpGained, 0);
    });

    test('i gradi', () {
      expect(RankTier.of(Rating.initial.ordinal), RankTier.picciotto);
      expect(RankTier.of(16), RankTier.caporegime);
      expect(RankTier.of(40), RankTier.don);
      expect(RankTier.don.progress(50), 1);
    });
  });
}
