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

  /// Standing in the city: +1 for every game that counts, +2 more for a
  /// win, plus what missions pay. Shown in the dossier and the missions.
  static const reputation = 'reputation';

  /// How many different roles won at least once (derived from [roleWin]).
  static const rolesWon = 'roles_won';

  /// The same, per side: every role of the town, the family, the lone ones
  /// (derived from [roleWin], never stored).
  static const rolesWonTown = 'roles_won_town';
  static const rolesWonMafia = 'roles_won_mafia';
  static const rolesWonLone = 'roles_won_lone';

  static String rolesWonOf(Team team) => switch (team) {
        Team.citizens => rolesWonTown,
        Team.mafia => rolesWonMafia,
        Team.neutral => rolesWonLone,
      };

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
  add(Metric.reputation, won ? 3 : 1);
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

  /// The role a card achievement unlocks (`role_<name>`), or null.
  Role? get role => roleOf(id);

  static Role? roleOf(String id) =>
      id.startsWith(rolePrefix) ? Role.values.where((r) => roleId(r) == id).firstOrNull : null;

  static const rolePrefix = 'role_';

  /// The card of [role] in the roles collection: won once with it. The
  /// name in snake_case (`capoSetta` -> `role_capo_setta`), as the ids of
  /// Steam, Game Center and the database want.
  static String roleId(Role role) => roleIdOf(role.name);

  static String roleIdOf(String roleName) =>
      '$rolePrefix${roleName.replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]!.toLowerCase()}')}';
}

/// One card achievement per role, in the order of [Role.values]: a new role
/// gets its own (and its Steam / Game Center twin, docs/steam.md) for free.
/// No coins or XP: the reward is the card itself.
final List<Achievement> roleAchievements = [
  for (final role in Role.values)
    Achievement(Achievement.roleId(role), 'role', 1, Metric.roleWin(role), 1, xp: 0, coins: 0),
];

int _rolesOf(Team team) => Role.values.where((r) => r.team == team).length;

/// The achievements, in display order. Never rename an id: they are the
/// Steam, Game Center and Play Games ids too (lib/platform/achievements.dart).
final List<Achievement> achievements = <Achievement>[
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
  Achievement('roles_won_all', 'roles_won', 3, Metric.rolesWon, Role.values.length,
      xp: 1000, coins: 500, title: 'chameleon', item: 'border.flame'),
  Achievement('roles_town_all', 'roles_side', 2, Metric.rolesWonTown, _rolesOf(Team.citizens), xp: 400, coins: 200),
  Achievement('roles_mafia_all', 'roles_side', 2, Metric.rolesWonMafia, _rolesOf(Team.mafia), xp: 400, coins: 200),
  Achievement('roles_lone_all', 'roles_side', 2, Metric.rolesWonLone, _rolesOf(Team.neutral), xp: 400, coins: 200),
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
  ...roleAchievements,
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
  return withRolesWon(out);
}

/// [stats] with the derived role counters ([Metric.rolesWon] and one per
/// side) computed from the `role_win:` ones.
Map<String, int> withRolesWon(Map<String, int> stats) {
  final out = {...stats};
  final won = [
    for (final role in Role.values)
      if ((out[Metric.roleWin(role)] ?? 0) > 0) role,
  ];
  out[Metric.rolesWon] =
      out.entries.where((e) => e.key.startsWith(Metric.roleWinPrefix) && e.value > 0).length;
  for (final team in Team.values) {
    out[Metric.rolesWonOf(team)] = won.where((r) => r.team == team).length;
  }
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

/// One mission of the pool, as `internal.mission_defs` holds it (the SQL is
/// the source the server reads; a test keeps the two equal). Daily and
/// weekly missions are dealt three per period, one from each [pool]; long
/// ones ("obiettivi") are always there and move with the lifetime counters.
/// [item] is a shop piece nobody can buy: only claiming this mission gives
/// it. XP is paid when a game completes a daily or weekly mission; coins,
/// [reputation] and the item when the player claims it.
class MissionDef {
  final String id;
  final String cadence;
  final int pool;
  final String metric;
  final int target;
  final int xp;
  final int coins;
  final int reputation;
  final String? item;

  const MissionDef(
    this.id,
    this.cadence,
    this.pool,
    this.metric,
    this.target, {
    required this.xp,
    required this.coins,
    required this.reputation,
    this.item,
  });

  bool get long => cadence == 'long';

  static MissionDef? byId(String id) => missionPool.where((m) => m.id == id).firstOrNull;

  /// The long mission that gives [itemId], if any.
  static MissionDef? unlocking(String itemId) => missionPool.where((m) => m.item == itemId).firstOrNull;
}

/// The pool. Daily coins 25-50, weekly 120-250, long ones 150-800 with the
/// mission-only pieces. Never rename an id.
const missionPool = <MissionDef>[
  // Daily, pool 1: show up.
  MissionDef('daily_play_3', 'daily', 1, Metric.games, 3, xp: 60, coins: 30, reputation: 2),
  MissionDef('daily_nights_2', 'daily', 1, Metric.nights, 2, xp: 60, coins: 25, reputation: 2),
  MissionDef('daily_ranked_1', 'daily', 1, Metric.rankedGames, 1, xp: 80, coins: 35, reputation: 2),
  MissionDef('daily_friends_play_2', 'daily', 1, Metric.friendsGames, 2, xp: 60, coins: 30, reputation: 2),
  // Daily, pool 2: win.
  MissionDef('daily_win_1', 'daily', 2, Metric.wins, 1, xp: 80, coins: 40, reputation: 3),
  MissionDef('daily_town_win_1', 'daily', 2, Metric.townWins, 1, xp: 90, coins: 45, reputation: 3),
  MissionDef('daily_mafia_win_1', 'daily', 2, Metric.mafiaWins, 1, xp: 100, coins: 50, reputation: 3),
  MissionDef('daily_friends_win_2', 'daily', 2, Metric.friendsWins, 2, xp: 100, coins: 50, reputation: 3),
  MissionDef('daily_win_alive_1', 'daily', 2, Metric.winsAlive, 1, xp: 90, coins: 45, reputation: 3),
  // Daily, pool 3: a nose for it.
  MissionDef('daily_lynch_hits_3', 'daily', 3, Metric.lynchHits, 3, xp: 100, coins: 45, reputation: 3),
  MissionDef('daily_survive_1', 'daily', 3, Metric.survived, 1, xp: 70, coins: 35, reputation: 2),
  MissionDef('daily_survive_2', 'daily', 3, Metric.survived, 2, xp: 90, coins: 45, reputation: 3),
  // Weekly, pool 1: a regular.
  MissionDef('weekly_play_10', 'weekly', 1, Metric.games, 10, xp: 200, coins: 120, reputation: 8),
  MissionDef('weekly_play_15', 'weekly', 1, Metric.games, 15, xp: 250, coins: 160, reputation: 10),
  MissionDef('weekly_nights_12', 'weekly', 1, Metric.nights, 12, xp: 250, coins: 140, reputation: 8),
  MissionDef('weekly_ranked_5', 'weekly', 1, Metric.rankedGames, 5, xp: 300, coins: 180, reputation: 10),
  // Weekly, pool 2: a winner.
  MissionDef('weekly_wins_4', 'weekly', 2, Metric.wins, 4, xp: 250, coins: 150, reputation: 10),
  MissionDef('weekly_wins_7', 'weekly', 2, Metric.wins, 7, xp: 300, coins: 200, reputation: 12),
  MissionDef('weekly_town_wins_3', 'weekly', 2, Metric.townWins, 3, xp: 250, coins: 160, reputation: 10),
  MissionDef('weekly_mafia_wins_2', 'weekly', 2, Metric.mafiaWins, 2, xp: 300, coins: 180, reputation: 10),
  MissionDef('weekly_ranked_wins_3', 'weekly', 2, Metric.rankedWins, 3, xp: 350, coins: 220, reputation: 12),
  MissionDef('weekly_neutral_win_1', 'weekly', 2, Metric.neutralWins, 1, xp: 300, coins: 250, reputation: 12),
  // Weekly, pool 3: the right role at the right time.
  MissionDef('weekly_lynch_hits_10', 'weekly', 3, Metric.lynchHits, 10, xp: 300, coins: 180, reputation: 10),
  MissionDef('weekly_saves_2', 'weekly', 3, Metric.saves, 2, xp: 300, coins: 200, reputation: 12),
  MissionDef('weekly_finds_3', 'weekly', 3, Metric.finds, 3, xp: 300, coins: 180, reputation: 12),
  MissionDef('weekly_kills_5', 'weekly', 3, Metric.kills, 5, xp: 300, coins: 180, reputation: 10),
  MissionDef('weekly_detective_win_1', 'weekly', 3, 'role_win:detective', 1, xp: 250, coins: 160, reputation: 10),
  MissionDef('weekly_doctor_win_1', 'weekly', 3, 'role_win:medico', 1, xp: 250, coins: 160, reputation: 10),
  // Long: the obiettivi, with the pieces nobody can buy.
  MissionDef('long_nights_10', 'long', 0, Metric.nights, 10, xp: 0, coins: 150, reputation: 15, item: 'nameStyle.moonlight'),
  MissionDef('long_lynch_hits_3', 'long', 0, Metric.lynchHits, 3, xp: 0, coins: 150, reputation: 15, item: 'border.noose'),
  MissionDef('long_detective_wins_5', 'long', 0, 'role_win:detective', 5, xp: 0, coins: 400, reputation: 50, item: 'hat.sbirro'),
  MissionDef('long_finds_5', 'long', 0, Metric.finds, 5, xp: 0, coins: 300, reputation: 30, item: 'border.badge'),
  MissionDef('long_mafia_wins_10', 'long', 0, Metric.mafiaWins, 10, xp: 0, coins: 400, reputation: 40, item: 'nameStyle.bloodInk'),
  MissionDef('long_town_wins_10', 'long', 0, Metric.townWins, 10, xp: 0, coins: 400, reputation: 40, item: 'nameStyle.siren'),
  MissionDef('long_wins_50', 'long', 0, Metric.wins, 50, xp: 0, coins: 800, reputation: 80, item: 'border.laurel'),
  MissionDef('long_games_25', 'long', 0, Metric.games, 25, xp: 0, coins: 300, reputation: 25),
  MissionDef('long_friends_games_20', 'long', 0, Metric.friendsGames, 20, xp: 0, coins: 300, reputation: 30),
  MissionDef('long_ranked_games_20', 'long', 0, Metric.rankedGames, 20, xp: 0, coins: 400, reputation: 30),
  MissionDef('long_saves_5', 'long', 0, Metric.saves, 5, xp: 0, coins: 400, reputation: 40),
  MissionDef('long_survived_25', 'long', 0, Metric.survived, 25, xp: 0, coins: 400, reputation: 30),
  MissionDef('long_neutral_wins_3', 'long', 0, Metric.neutralWins, 3, xp: 0, coins: 500, reputation: 40),
];
