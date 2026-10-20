import 'dart:math';

// What a finished online game is worth: experience, levels, coins and, in
// ranked, the rating. Pure Dart: the server runs it (compiled into
// engine.js, `globalThis.obertaSettle`, called by the Edge Function in the
// same transaction that saves the game's end), the fake backend runs it in
// tests, and the phone uses [Progression] and [RankTier] to draw the bars.
//
// The numbers are the ones in docs/visione.md, in one place so they can be
// tuned: a win is worth 100 XP, a loss 30, the first win of the (UTC) day
// +100; from level L to L+1 takes 150 + 25·L XP; every level gives 50
// coins, every fifth level 200 more.
//
// Friends games give experience too. Coins from levels reached in friends
// games are paid only for the first [Progression.friendsCoinGames] friends
// games of the day, and only in games with at least two people: a room full
// of bots must not become a coin farm. Ranked games always pay.

/// Experience, levels and coins.
abstract final class Progression {
  static const winXp = 100;
  static const lossXp = 30;
  static const firstWinOfDayXp = 100;

  /// Friends games per (UTC) day whose level-ups pay coins.
  static const friendsCoinGames = 5;

  /// People (not bots) a friends game needs to give anything.
  static const friendsMinHumans = 2;

  /// Experience to go from [level] to the next one.
  static int xpToNext(int level) => 150 + 25 * max(1, level);

  /// Coins for reaching [level].
  static int coinsForLevel(int level) => 50 + (level % 5 == 0 ? 200 : 0);

  /// Experience for a game: nothing to who abandoned it.
  static int xpFor({required bool won, required bool abandoned, required bool firstWinOfDay}) {
    if (abandoned) return 0;
    if (!won) return lossXp;
    return winXp + (firstWinOfDay ? firstWinOfDayXp : 0);
  }

  /// Adds [gain] experience to a profile at [level] with [xp] towards the
  /// next level: the new level and remainder, and the coins the levels
  /// reached are worth (paid or not is the caller's business).
  static ({int level, int xp, int levelsGained, int coins}) addXp(int level, int xp, int gain) {
    int l = max(1, level);
    int x = max(0, xp) + max(0, gain);
    var coins = 0;
    var gained = 0;
    while (x >= xpToNext(l)) {
      x -= xpToNext(l);
      l++;
      gained++;
      coins += coinsForLevel(l);
    }
    return (level: l, xp: x, levelsGained: gained, coins: coins);
  }
}

/// A Bayesian skill estimate: mean and uncertainty (Weng–Lin).
class Rating {
  final double mu;
  final double sigma;

  const Rating(this.mu, this.sigma);

  static const initial = Rating(WengLin.mu0, WengLin.sigma0);

  /// The conservative estimate the tiers use: three sigmas below the mean.
  /// A new player sits at 0 and climbs as the server grows sure of them.
  double get ordinal => mu - 3 * sigma;

  @override
  String toString() => 'Rating(${mu.toStringAsFixed(2)}, ${sigma.toStringAsFixed(2)})';
}

/// Weng & Lin (2011), the Plackett–Luce model, as OpenSkill implements it:
/// any number of teams, each with a rank (0 best, ties share a rank).
///
/// Hidden-role teams are lopsided (two mafiosi against six townsfolk), so a
/// team's strength is the *mean* of its players' skill, not the sum: a big
/// team is not a strong team. Each player then moves by their own share of
/// the uncertainty, like in OpenSkill.
abstract final class WengLin {
  static const mu0 = 25.0;
  static const sigma0 = 25.0 / 3;
  static const beta = sigma0 / 2;
  static const kappa = 0.0001;

  /// Uncertainty added before each game, so a rating can still move after
  /// hundreds of games.
  static const tau = mu0 / 300;

  /// The new ratings: [teams] are lists of ratings, [ranks] one per team.
  static List<List<Rating>> rate(List<List<Rating>> teams, List<int> ranks) {
    assert(teams.length == ranks.length && teams.length >= 2);
    final players = [
      for (final team in teams) [for (final r in team) Rating(r.mu, sqrt(r.sigma * r.sigma + tau * tau))],
    ];
    final teamMu = [for (final team in players) team.map((r) => r.mu).reduce((a, b) => a + b) / team.length];
    final teamSigmaSq = [
      for (final team in players) team.map((r) => r.sigma * r.sigma).reduce((a, b) => a + b) / team.length,
    ];
    final n = players.length;
    final c = sqrt(List.generate(n, (i) => teamSigmaSq[i] + beta * beta).reduce((a, b) => a + b));
    final expMu = [for (final m in teamMu) exp(m / c)];
    // For each team q: the sum of exp(mu/c) over the teams ranked q or worse.
    final sumQ = [
      for (var q = 0; q < n; q++)
        [for (var s = 0; s < n; s++) if (ranks[s] >= ranks[q]) expMu[s]].reduce((a, b) => a + b),
    ];
    final tied = [for (var q = 0; q < n; q++) ranks.where((r) => r == ranks[q]).length];

    return [
      for (var i = 0; i < n; i++)
        () {
          var omega = 0.0;
          var delta = 0.0;
          for (var q = 0; q < n; q++) {
            if (ranks[q] > ranks[i]) continue;
            final share = expMu[i] / sumQ[q];
            omega += (q == i ? 1 - share : -share) / tied[q];
            delta += share * (1 - share) / tied[q];
          }
          final sq = teamSigmaSq[i];
          final gamma = sqrt(sq) / c;
          final teamOmega = omega * sq / c;
          final teamDelta = gamma * delta * sq / (c * c);
          return [
            for (final r in players[i])
              Rating(
                r.mu + (r.sigma * r.sigma / sq) * teamOmega,
                r.sigma * sqrt(max(1 - (r.sigma * r.sigma / sq) * teamDelta, kappa)),
              ),
          ];
        }(),
    ];
  }
}

/// The rank shown on the profile, from the rating's [Rating.ordinal]. The
/// number itself stays hidden. Thresholds are provisional, to be tuned on
/// real games.
enum RankTier {
  picciotto(double.negativeInfinity),
  capodecina(8),
  caporegime(15),
  consigliere(22),
  don(29);

  final double from;

  const RankTier(this.from);

  static RankTier of(double ordinal) => values.lastWhere((tier) => ordinal >= tier.from);

  RankTier? get next => index + 1 < values.length ? values[index + 1] : null;

  /// How far between this tier and the next, 0..1 (1 for Don).
  double progress(double ordinal) {
    final up = next;
    if (up == null) return 1;
    final start = from.isFinite ? from : 0;
    return ((ordinal - start) / (up.from - start)).clamp(0.0, 1.0);
  }
}

/// One person at the end of a game, as the server reads them.
class SettleSeat {
  /// Whether this seat may gain anything from the game.
  bool get earns => !abandoned && !afk && !leftDead && !short;

  final String profile;
  final String seat;
  final String team;
  final String role;
  final bool won;
  final bool survived;
  final bool abandoned;

  /// Present but idle for the game (see `Attendance` in game_server.dart):
  /// nothing gained, rated as a loss, a soft conduct hit in ranked.
  final bool afk;

  /// Left the table after dying: nothing gained, rating untouched, no
  /// penalty.
  final bool leftDead;

  /// The game ended before day 2 because someone left: nobody gains.
  final bool short;
  final int level;
  final int xp;
  final Rating rating;

  /// True if this person already won a game today (UTC), before this one.
  final bool wonToday;

  /// Friends games this person finished today (UTC), before this one.
  final int friendsGamesToday;

  const SettleSeat({
    required this.profile,
    required this.seat,
    required this.team,
    required this.role,
    required this.won,
    required this.survived,
    required this.abandoned,
    this.afk = false,
    this.leftDead = false,
    this.short = false,
    this.level = 1,
    this.xp = 0,
    this.rating = Rating.initial,
    this.wonToday = false,
    this.friendsGamesToday = 0,
  });

  factory SettleSeat.fromJson(Map<String, Object?> json) => SettleSeat(
        profile: json['profile'] as String,
        seat: json['seat'] as String,
        team: json['team'] as String,
        role: json['role'] as String,
        won: json['won'] == true,
        survived: json['survived'] == true,
        abandoned: json['abandoned'] == true,
        afk: json['afk'] == true,
        leftDead: json['leftDead'] == true,
        short: json['short'] == true,
        level: (json['level'] as num?)?.toInt() ?? 1,
        xp: (json['xp'] as num?)?.toInt() ?? 0,
        rating: Rating(
          (json['mu'] as num?)?.toDouble() ?? WengLin.mu0,
          (json['sigma'] as num?)?.toDouble() ?? WengLin.sigma0,
        ),
        wonToday: json['wonToday'] == true,
        friendsGamesToday: (json['friendsGamesToday'] as num?)?.toInt() ?? 0,
      );
}

/// What one person gets.
class SettleOutcome {
  final SettleSeat seat;
  final int xpGained;
  final int level;
  final int xp;
  final int levelsGained;
  final int coins;

  /// Null outside ranked.
  final Rating? rating;

  const SettleOutcome({
    required this.seat,
    required this.xpGained,
    required this.level,
    required this.xp,
    required this.levelsGained,
    required this.coins,
    this.rating,
  });

  double? get ordinalDelta => rating == null ? null : rating!.ordinal - seat.rating.ordinal;

  Map<String, Object?> toJson() => {
        'profile': seat.profile,
        'seat': seat.seat,
        'team': seat.team,
        'role': seat.role,
        'won': seat.won,
        'survived': seat.survived,
        'abandoned': seat.abandoned,
        'afk': seat.afk,
        'leftDead': seat.leftDead,
        'short': seat.short,
        'xpGained': xpGained,
        'levelBefore': seat.level,
        'level': level,
        'xp': xp,
        'levelsGained': levelsGained,
        'coins': coins,
        if (rating case final r?) ...{
          'muBefore': seat.rating.mu,
          'sigmaBefore': seat.rating.sigma,
          'mu': r.mu,
          'sigma': r.sigma,
          'ratingDelta': ordinalDelta,
        },
      };
}

/// Settles a game. [ranked] moves ratings; otherwise it is a friends game
/// (and [humans] is how many people sat at it).
///
/// In ranked, players who abandoned are rated as a team of their own that
/// finished last, whatever their side did: leaving never pays. Idle (AFK)
/// players lose the same way; who left after dying is not rated at all.
List<SettleOutcome> settle({required bool ranked, required List<SettleSeat> seats, int? humans}) {
  final people = humans ?? seats.length;
  final rewarded = ranked || people >= Progression.friendsMinHumans;
  final ratings = <String, Rating>{};
  if (ranked) {
    final groups = <(int, List<SettleSeat>)>[
      (0, [for (final s in seats) if (s.won && !s.abandoned && !s.afk && !s.leftDead) s]),
      (1, [for (final s in seats) if (!s.won && !s.abandoned && !s.afk && !s.leftDead) s]),
      for (final s in seats) if (s.abandoned || (s.afk && !s.leftDead)) (2, [s]),
    ].where((g) => g.$2.isNotEmpty).toList();
    if (groups.length >= 2) {
      final rated = WengLin.rate([for (final g in groups) [for (final s in g.$2) s.rating]], [for (final g in groups) g.$1]);
      for (var i = 0; i < groups.length; i++) {
        for (var j = 0; j < groups[i].$2.length; j++) {
          ratings[groups[i].$2[j].profile] = rated[i][j];
        }
      }
    }
  }
  return [
    for (final s in seats)
      () {
        final gain = rewarded
            ? Progression.xpFor(won: s.won, abandoned: !s.earns, firstWinOfDay: s.won && !s.wonToday)
            : 0;
        final next = Progression.addXp(s.level, s.xp, gain);
        final pays = ranked || s.friendsGamesToday < Progression.friendsCoinGames;
        return SettleOutcome(
          seat: s,
          xpGained: gain,
          level: next.level,
          xp: next.xp,
          levelsGained: next.levelsGained,
          coins: pays ? next.coins : 0,
          rating: ranked ? _noGain(s, ratings[s.profile] ?? s.rating) : null,
        );
      }(),
  ];
}

/// Who does not earn never climbs: their rating can only stay or fall.
Rating _noGain(SettleSeat s, Rating rated) =>
    s.earns || rated.ordinal <= s.rating.ordinal ? rated : s.rating;

/// The JSON entry point the Edge Function calls: `{ranked, humans, seats:
/// [...]}` in, `{players: [...]}` out.
Map<String, Object?> settleJson(Map<String, Object?> input) => {
      'players': [
        for (final o in settle(
          ranked: input['ranked'] == true,
          humans: (input['humans'] as num?)?.toInt(),
          seats: [for (final row in input['seats'] as List<Object?>) SettleSeat.fromJson((row as Map).cast<String, Object?>())],
        ))
          o.toJson(),
      ],
    };
