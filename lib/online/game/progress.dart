import '../../rules/role.dart';

// Missions and achievements, the pure part. The server runs it inside
// settle (compiled into engine.js with match_rewards.dart): from what a
// person really did in a finished game it builds a tally of counters, moves
// their missions forward and unlocks achievements. The client never claims
// anything; it only reads the result and draws it.
//
// Achievement ids are stable snake_case: they will be mirrored to Steam
// with the same ids (docs/steam.md). The mission pool lives in the database
// (internal.mission_defs); its ids are stable too.

/// What the game server counts during a game, per human seat.
abstract final class Feats {
  /// Nights seen through to the dawn.
  static const nights = 'nights';

  /// Votes on a condemned mafioso.
  static const lynchHits = 'lynchHits';

  /// Doctor: a protected target attacked and saved.
  static const saves = 'saves';

  /// Detective: a real mafioso found (who also looks like one).
  static const finds = 'finds';

  /// Sniper: a mafioso shot dead.
  static const snipes = 'snipes';

  /// Family: a night the family's attack killed, for who voted it.
  static const kills = 'kills';

  /// Detective voted the Godfather onto the gallows.
  static const godfather = 'godfather';

  /// A mafioso voted an honest citizen onto the gallows.
  static const framed = 'framed';
}

/// The counters missions and achievements look at.
abstract final class Metric {
  static const games = 'games';
  static const wins = 'wins';
  static const friendsGames = 'friends_games';
  static const friendsWins = 'friends_wins';
  static const rankedGames = 'ranked_games';
  static const rankedWins = 'ranked_wins';
  static const survived = 'survived';
  static const winsAlive = 'wins_alive';
  static const townWins = 'town_wins';
  static const mafiaWins = 'mafia_wins';
  static const neutralWins = 'neutral_wins';
  static const nights = 'nights';
  static const lynchHits = 'lynch_hits';
  static const saves = 'saves';
  static const finds = 'finds';
  static const snipes = 'snipes';
  static const kills = 'kills';
  static const framed = 'framed';
  static const godfatherLynch = 'godfather_lynch';
  static const doctorSaveSurvive = 'doctor_save_survive';
  static const foolWin = 'fool_win';

  /// How many different roles won at least once (derived from [roleWin]).
  static const rolesWon = 'roles_won';

  static String roleWin(Role role) => 'role_win:${role.name}';
  static const roleWinPrefix = 'role_win:';
}

/// One finished game for one person, as far as progress is concerned.
/// [counts] false (abandoned, AFK, left, short game, bots-only room): the
/// tally is empty and nothing moves.
Map<String, int> progressTally({
  required bool counts,
  required bool ranked,
  required String team,
  required String role,
  required bool won,
  required bool survived,
  Map<String, int> feats = const {},
}) {
  if (!counts) return const {};
  final tally = <String, int>{};
  void add(String metric, [int n = 1]) {
    if (n > 0) tally[metric] = (tally[metric] ?? 0) + n;
  }

  add(Metric.games);
  add(ranked ? Metric.rankedGames : Metric.friendsGames);
  if (survived) add(Metric.survived);
  if (won) {
    add(Metric.wins);
    add(ranked ? Metric.rankedWins : Metric.friendsWins);
    if (survived) add(Metric.winsAlive);
    switch (team) {
      case 'citizens':
        add(Metric.townWins);
      case 'mafia':
        add(Metric.mafiaWins);
      case 'neutral':
        add(Metric.neutralWins);
    }
    if (Role.values.where((r) => r.name == role).firstOrNull case final r?) {
      add(Metric.roleWin(r));
      if (r == Role.fesso) add(Metric.foolWin);
    }
  }
  int n(String feat) => feats[feat] ?? 0;
  add(Metric.nights, n(Feats.nights));
  add(Metric.lynchHits, n(Feats.lynchHits));
  add(Metric.saves, n(Feats.saves));
  add(Metric.finds, n(Feats.finds));
  add(Metric.snipes, n(Feats.snipes));
  add(Metric.kills, n(Feats.kills));
  add(Metric.framed, n(Feats.framed));
  if (role == Role.detective.name) add(Metric.godfatherLynch, n(Feats.godfather));
  if (role == Role.medico.name && survived && n(Feats.saves) > 0) add(Metric.doctorSaveSurvive);
  return tally;
}

/// A mission assigned to a person for a day or a week, as the server hands
/// it to settle (only the ones not completed yet).
class MissionSlot {
  final String id;
  final String cadence;
  final String period;
  final String metric;
  final int target;
  final int progress;
  final int xp;
  final int coins;

  const MissionSlot({
    required this.id,
    required this.cadence,
    required this.period,
    required this.metric,
    required this.target,
    this.progress = 0,
    required this.xp,
    required this.coins,
  });

  factory MissionSlot.fromJson(Map<String, Object?> json) => MissionSlot(
        id: json['id'] as String,
        cadence: json['cadence'] as String,
        period: json['period'] as String,
        metric: json['metric'] as String,
        target: (json['target'] as num).toInt(),
        progress: (json['progress'] as num?)?.toInt() ?? 0,
        xp: (json['xp'] as num?)?.toInt() ?? 0,
        coins: (json['coins'] as num?)?.toInt() ?? 0,
      );
}

/// A permanent achievement. Tiers share a [family]; [title] and [item] are
/// the cosmetic rewards (a title for the dossier, a shop item given free).
class Achievement {
  final String id;
  final String family;
  final int tier;
  final String metric;
  final int target;
  final int xp;
  final int coins;
  final String? title;
  final String? item;

  const Achievement(
    this.id,
    this.family,
    this.tier,
    this.metric,
    this.target, {
    required this.xp,
    required this.coins,
    this.title,
    this.item,
  });

  static Achievement? byId(String id) => achievements.where((a) => a.id == id).firstOrNull;
}

/// The achievements, in display order. Never rename an id: they are the
/// future Steam ids.
const achievements = <Achievement>[
  Achievement('wins_10', 'wins', 1, Metric.wins, 10, xp: 100, coins: 50),
  Achievement('wins_50', 'wins', 2, Metric.wins, 50, xp: 300, coins: 150, title: 'man_of_honor'),
  Achievement('wins_200', 'wins', 3, Metric.wins, 200, xp: 800, coins: 400, title: 'legend', item: 'border.artDeco'),
  Achievement('games_25', 'games', 1, Metric.games, 25, xp: 100, coins: 50),
  Achievement('games_100', 'games', 2, Metric.games, 100, xp: 300, coins: 150),
  Achievement('games_500', 'games', 3, Metric.games, 500, xp: 800, coins: 400, title: 'veteran'),
  Achievement('ranked_wins_10', 'ranked_wins', 1, Metric.rankedWins, 10, xp: 200, coins: 100),
  Achievement('ranked_wins_50', 'ranked_wins', 2, Metric.rankedWins, 50,
      xp: 500, coins: 250, title: 'boss', item: 'border.mosaic'),
  Achievement('friends_wins_25', 'friends_wins', 1, Metric.friendsWins, 25, xp: 200, coins: 100),
  Achievement('town_wins_25', 'town_wins', 1, Metric.townWins, 25, xp: 200, coins: 100, title: 'model_citizen'),
  Achievement('mafia_wins_25', 'mafia_wins', 1, Metric.mafiaWins, 25, xp: 250, coins: 120, title: 'made_man'),
  Achievement('neutral_wins_1', 'neutral_wins', 1, Metric.neutralWins, 1, xp: 100, coins: 50),
  Achievement('neutral_wins_10', 'neutral_wins', 2, Metric.neutralWins, 10, xp: 300, coins: 150, title: 'lone_wolf'),
  Achievement('roles_won_5', 'roles_won', 1, Metric.rolesWon, 5, xp: 150, coins: 75),
  Achievement('roles_won_12', 'roles_won', 2, Metric.rolesWon, 12, xp: 400, coins: 200),
  Achievement('roles_won_all', 'roles_won', 3, Metric.rolesWon, 24,
      xp: 1000, coins: 500, title: 'chameleon', item: 'border.flame'),
  Achievement('wins_alive_25', 'wins_alive', 1, Metric.winsAlive, 25, xp: 300, coins: 150),
  Achievement('lynch_hits_10', 'lynch_hits', 1, Metric.lynchHits, 10, xp: 100, coins: 50),
  Achievement('lynch_hits_50', 'lynch_hits', 2, Metric.lynchHits, 50, xp: 300, coins: 150, title: 'bloodhound'),
  Achievement('lynch_hits_200', 'lynch_hits', 3, Metric.lynchHits, 200, xp: 600, coins: 300),
  Achievement('nights_25', 'nights', 1, Metric.nights, 25, xp: 100, coins: 50),
  Achievement('nights_100', 'nights', 2, Metric.nights, 100, xp: 300, coins: 150, title: 'night_owl'),
  Achievement('saves_1', 'saves', 1, Metric.saves, 1, xp: 100, coins: 50),
  Achievement('saves_10', 'saves', 2, Metric.saves, 10, xp: 300, coins: 150, title: 'guardian_angel'),
  Achievement('doctor_save_survive', 'doctor_save_survive', 1, Metric.doctorSaveSurvive, 1, xp: 150, coins: 75),
  Achievement('finds_10', 'finds', 1, Metric.finds, 10, xp: 200, coins: 100),
  Achievement('godfather_lynch', 'godfather_lynch', 1, Metric.godfatherLynch, 1,
      xp: 200, coins: 100, title: 'inspector'),
  Achievement('snipes_1', 'snipes', 1, Metric.snipes, 1, xp: 150, coins: 75),
  Achievement('kills_25', 'kills', 1, Metric.kills, 25, xp: 300, coins: 150),
  Achievement('framed_5', 'framed', 1, Metric.framed, 5, xp: 200, coins: 100, title: 'schemer'),
  Achievement('fool_win', 'fool_win', 1, Metric.foolWin, 1, xp: 150, coins: 75),
];

/// What a game moved: missions (only the ones that changed), the ones just
/// completed, the achievements just unlocked and what they pay.
class ProgressUpdate {
  final List<({MissionSlot mission, int progress, bool completed})> missions;
  final List<Achievement> unlocked;

  const ProgressUpdate({this.missions = const [], this.unlocked = const []});

  Iterable<MissionSlot> get completed => [for (final m in missions) if (m.completed) m.mission];
  int get xp => completed.fold(0, (sum, m) => sum + m.xp) + unlocked.fold(0, (sum, a) => sum + a.xp);
  int get missionCoins => completed.fold(0, (sum, m) => sum + m.coins);
  int get achievementCoins => unlocked.fold(0, (sum, a) => sum + a.coins);
}

/// The counters after adding [tally] to [stats], with [Metric.rolesWon]
/// recomputed.
Map<String, int> mergeStats(Map<String, int> stats, Map<String, int> tally) {
  final out = {...stats};
  for (final MapEntry(:key, :value) in tally.entries) {
    out[key] = (out[key] ?? 0) + value;
  }
  out[Metric.rolesWon] =
      out.entries.where((e) => e.key.startsWith(Metric.roleWinPrefix) && e.value > 0).length;
  return out;
}

/// Moves [missions] and unlocks achievements from one game's [tally].
/// [stats] are the lifetime counters before the game; [achieved] the ids
/// already unlocked.
ProgressUpdate applyProgress({
  required Map<String, int> tally,
  List<MissionSlot> missions = const [],
  Map<String, int> stats = const {},
  Set<String> achieved = const {},
}) {
  if (tally.isEmpty) return const ProgressUpdate();
  final moved = [
    for (final m in missions)
      if ((tally[m.metric] ?? 0) > 0 && m.progress < m.target)
        () {
          final progress = (m.progress + tally[m.metric]!).clamp(0, m.target);
          return (mission: m, progress: progress, completed: progress >= m.target);
        }(),
  ];
  final after = mergeStats(stats, tally);
  final unlocked = [
    for (final a in achievements)
      if (!achieved.contains(a.id) && (after[a.metric] ?? 0) >= a.target) a,
  ];
  return ProgressUpdate(missions: moved, unlocked: unlocked);
}
