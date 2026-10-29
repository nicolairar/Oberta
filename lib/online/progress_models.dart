import '../l10n/lobby_language.dart';
import 'game/match_rewards.dart' show RankTier;
import 'game/progress.dart';
import 'online_models.dart' show PlayerMarks, Profile;

export 'game/progress.dart' show Achievement, achievements, Metric, MissionDef, missionPool;

/// A mission as the phone sees it: the server deals it, moves it and pays
/// it when claimed. Long missions ("obiettivi") move with the lifetime
/// counters and some give a piece nobody can buy ([item]).
class MissionProgress {
  final String id;
  final String cadence;
  final String metric;
  final int target;
  final int progress;
  final int xp;
  final int coins;
  final int reputation;

  /// The mission-only shop piece it gives, or null.
  final String? item;
  final bool completed;
  final bool claimed;

  /// From an earlier day or week, done and still to claim.
  final bool late;
  final DateTime? endsAt;

  const MissionProgress({
    required this.id,
    required this.cadence,
    required this.metric,
    required this.target,
    this.progress = 0,
    this.xp = 0,
    this.coins = 0,
    this.reputation = 0,
    this.item,
    this.completed = false,
    this.claimed = false,
    this.late = false,
    this.endsAt,
  });

  bool get weekly => cadence == 'weekly';
  bool get long => cadence == 'long';

  /// Done and not paid yet: the button to press.
  bool get claimable => completed && !claimed;
  double get fraction => target <= 0 ? 1 : (progress / target).clamp(0.0, 1.0);

  MissionProgress copyWith({int? progress, bool? completed, bool? claimed}) => MissionProgress(
        id: id,
        cadence: cadence,
        metric: metric,
        target: target,
        progress: progress ?? this.progress,
        xp: xp,
        coins: coins,
        reputation: reputation,
        item: item,
        completed: completed ?? this.completed,
        claimed: claimed ?? this.claimed,
        late: late,
        endsAt: endsAt,
      );

  /// What the pool says about [def], at [progress].
  factory MissionProgress.of(MissionDef def, {int progress = 0, bool claimed = false, DateTime? endsAt}) => MissionProgress(
        id: def.id,
        cadence: def.cadence,
        metric: def.metric,
        target: def.target,
        progress: progress.clamp(0, def.target),
        xp: def.xp,
        coins: def.coins,
        reputation: def.reputation,
        item: def.item,
        completed: progress >= def.target,
        claimed: claimed,
        endsAt: endsAt,
      );

  factory MissionProgress.fromJson(Map<String, Object?> json) => MissionProgress(
        id: json['id'] as String,
        cadence: json['cadence'] as String? ?? 'daily',
        metric: json['metric'] as String? ?? '',
        target: (json['target'] as num?)?.toInt() ?? 1,
        progress: (json['progress'] as num?)?.toInt() ?? 0,
        xp: (json['xp'] as num?)?.toInt() ?? 0,
        coins: (json['coins'] as num?)?.toInt() ?? 0,
        reputation: (json['reputation'] as num?)?.toInt() ?? 0,
        item: json['item'] as String?,
        completed: json['completed'] == true,
        claimed: json['claimed'] == true,
        late: json['late'] == true,
        endsAt: json['ends_at'] == null ? null : DateTime.fromMillisecondsSinceEpoch((json['ends_at'] as num).toInt()),
      );
}

/// What a claim paid: the coins, the reputation, the piece (if any) and the
/// new balance.
class MissionClaim {
  final int coins;
  final int reputation;
  final String? item;
  final int? balance;

  const MissionClaim({this.coins = 0, this.reputation = 0, this.item, this.balance});

  factory MissionClaim.fromJson(Map<String, Object?> json) => MissionClaim(
        coins: (json['coins'] as num?)?.toInt() ?? 0,
        reputation: (json['reputation'] as num?)?.toInt() ?? 0,
        item: json['item'] as String?,
        balance: (json['balance'] as num?)?.toInt(),
      );
}

/// Everything about a player's progress: missions, lifetime counters and
/// the achievements unlocked (id → when).
class PlayerProgress {
  final List<MissionProgress> missions;
  final Map<String, int> stats;
  final Map<String, DateTime> unlocked;

  const PlayerProgress({this.missions = const [], this.stats = const {}, this.unlocked = const {}});

  int statOf(String metric) => stats[metric] ?? 0;

  /// Standing in the city: from games and claimed missions.
  int get reputation => statOf(Metric.reputation);

  /// Missions done and waiting for the claim.
  int get claimable => missions.where((m) => m.claimable).length;

  /// The title to show: from the last unlocked achievement that gives one.
  String? get title {
    String? best;
    DateTime? at;
    for (final a in achievements) {
      final when = unlocked[a.id];
      if (a.title == null || when == null) continue;
      if (at == null || !when.isBefore(at)) {
        best = a.title;
        at = when;
      }
    }
    return best;
  }

  factory PlayerProgress.fromJson(Map<String, Object?> json) => PlayerProgress(
        missions: [
          for (final row in (json['missions'] as List<Object?>? ?? const []))
            MissionProgress.fromJson((row as Map).cast<String, Object?>()),
        ],
        stats: {
          for (final MapEntry(:key, :value) in ((json['stats'] as Map?) ?? const {}).entries)
            if (value is num) key as String: value.toInt(),
        },
        unlocked: {
          for (final row in (json['achievements'] as List<Object?>? ?? const []))
            ((row as Map)['id'] as String): DateTime.fromMillisecondsSinceEpoch(((row['at'] as num?) ?? 0).toInt()),
        },
      );
}

/// What one game completed for the player: the banners after the game.
class GameUnlocks {
  final List<({String id, int coins, int xp})> missions;
  final List<String> achievements;

  const GameUnlocks({this.missions = const [], this.achievements = const []});

  bool get isEmpty => missions.isEmpty && achievements.isEmpty;

  factory GameUnlocks.fromJson(Map<String, Object?> json) => GameUnlocks(
        missions: [
          for (final row in (json['missions'] as List<Object?>? ?? const []))
            (
              id: (row as Map)['id'] as String,
              coins: (row['coins'] as num?)?.toInt() ?? 0,
              xp: (row['xp'] as num?)?.toInt() ?? 0,
            ),
        ],
        achievements: [
          for (final row in (json['achievements'] as List<Object?>? ?? const [])) (row as Map)['id'] as String,
        ],
      );
}

/// One row of the ranked leaderboard: a place, a handle, a tier, and the
/// platform marks (a Steam / Apple logo next to the name). Nothing else.
class LeaderboardEntry {
  final int rank;
  final String handle;
  final RankTier tier;
  final bool steam;
  final bool apple;

  const LeaderboardEntry(this.rank, this.handle, this.tier, {this.steam = false, this.apple = false});
}

class Leaderboard {
  final List<LeaderboardEntry> top;

  /// The caller's place and tier; null without ranked games in that language.
  final ({int rank, RankTier tier})? me;

  const Leaderboard({this.top = const [], this.me});

  static RankTier _tier(Object? name) =>
      RankTier.values.where((t) => t.name == name).firstOrNull ?? RankTier.picciotto;

  factory Leaderboard.fromJson(Map<String, Object?> json) {
    final me = (json['me'] as Map?)?.cast<String, Object?>();
    for (final row in (json['top'] as List<Object?>? ?? const [])) {
      if (row case {'handle': final String handle}) {
        PlayerMarks.rememberPlatforms(handle, steam: row['steam'] == true, apple: row['apple'] == true);
      }
    }
    return Leaderboard(
      top: [
        for (final row in (json['top'] as List<Object?>? ?? const []))
          LeaderboardEntry(
            ((row as Map)['rank'] as num).toInt(),
            row['handle'] as String? ?? '?',
            _tier(row['tier']),
            steam: row['steam'] == true,
            apple: row['apple'] == true,
          ),
      ],
      me: me == null ? null : (rank: (me['rank'] as num).toInt(), tier: _tier(me['tier'])),
    );
  }
}

/// One card of the roles collection ("I ruoli"): the games that counted
/// with that role and how they went. Written by the server only
/// (`internal.role_stats`, record_match); the card is unlocked by the first
/// win.
class RoleRecord {
  final String role;
  final int played;
  final int wins;
  final int streak;
  final int bestStreak;
  final DateTime? firstWin;
  final DateTime? lastPlayed;

  const RoleRecord({
    required this.role,
    this.played = 0,
    this.wins = 0,
    this.streak = 0,
    this.bestStreak = 0,
    this.firstWin,
    this.lastPlayed,
  });

  bool get unlocked => wins > 0;
  int get losses => played - wins;
  double get winRate => played == 0 ? 0 : wins / played;

  /// The record after one more counted game (the fake server's
  /// record_role).
  RoleRecord after({required bool won, required DateTime at}) {
    final run = won ? streak + 1 : 0;
    return RoleRecord(
      role: role,
      played: played + 1,
      wins: wins + (won ? 1 : 0),
      streak: run,
      bestStreak: run > bestStreak ? run : bestStreak,
      firstWin: firstWin ?? (won ? at : null),
      lastPlayed: at,
    );
  }

  static DateTime? _at(Object? ms) => ms is num ? DateTime.fromMillisecondsSinceEpoch(ms.toInt()) : null;

  factory RoleRecord.fromJson(Map<String, Object?> json) => RoleRecord(
        role: json['role'] as String,
        played: (json['played'] as num?)?.toInt() ?? 0,
        wins: (json['wins'] as num?)?.toInt() ?? 0,
        streak: (json['streak'] as num?)?.toInt() ?? 0,
        bestStreak: (json['best_streak'] as num?)?.toInt() ?? 0,
        firstWin: _at(json['first_win']),
        lastPlayed: _at(json['last_played']),
      );

  static Map<String, RoleRecord> listFromJson(Object? json) => {
        for (final row in (json as List<Object?>? ?? const []))
          if (row is Map && row['role'] is String)
            row['role'] as String: RoleRecord.fromJson(row.cast<String, Object?>()),
      };
}

/// Missions, achievements and the leaderboard. The server moves everything
/// when it settles a game; the phone only reads and claims.
abstract class ProgressRepository {
  Future<PlayerProgress> mine();

  /// Pays a completed mission (coins, reputation, a mission-only piece).
  /// The server checks everything; nothing here is trusted.
  Future<MissionClaim> claim(String missionId);

  /// The caller's role cards, by role name (`my_role_stats`). A role with
  /// no record was never played: locked.
  Future<Map<String, RoleRecord>> roleStats();
  Future<GameUnlocks> unlocksFor(String gameId);
  Future<Leaderboard> leaderboard(LobbyLanguage language);
}

/// Another player's public dossier (`public_stats`): account-level numbers
/// from real games only. Never abandons, AFK, conduct, coins or the Steam
/// name. With the profile private ([open] false) only the handle, the level
/// and the portrait come back.
class PublicProfile {
  final Profile profile;
  final bool open;
  final RankTier? tier;
  final String? title;

  /// The three rarest achievements unlocked, rarest first.
  final List<String> featured;
  final int games;
  final int wins;
  final int longestStreak;
  final int seconds;
  final int timed;

  /// The five most played roles, most played first.
  final List<({String role, int games, int wins})> roles;

  /// How many role cards are unlocked; null on a closed profile.
  final int? rolesUnlocked;

  const PublicProfile({
    required this.profile,
    this.open = true,
    this.tier,
    this.title,
    this.featured = const [],
    this.games = 0,
    this.wins = 0,
    this.longestStreak = 0,
    this.seconds = 0,
    this.timed = 0,
    this.roles = const [],
    this.rolesUnlocked,
  });

  double get winRate => games == 0 ? 0 : wins / games;
  String? get favouriteRole => roles.firstOrNull?.role;

  static int _int(Object? v) => (v as num?)?.toInt() ?? 0;

  factory PublicProfile.fromJson(Map<String, Object?> json) => PublicProfile(
        profile: Profile.fromJson(json.cast<String, dynamic>()),
        open: json['public'] != false,
        tier: json['tier'] == null ? null : Leaderboard._tier(json['tier']),
        title: json['title'] as String?,
        featured: [for (final id in (json['featured'] as List<Object?>? ?? const [])) if (id is String) id],
        games: _int(json['games']),
        wins: _int(json['wins']),
        longestStreak: _int(json['longest_streak']),
        seconds: _int(json['seconds']),
        timed: _int(json['timed']),
        rolesUnlocked: (json['roles_unlocked'] as num?)?.toInt(),
        roles: [
          for (final row in (json['roles'] as List<Object?>? ?? const []))
            if (row is Map && row['role'] is String)
              (role: row['role'] as String, games: _int(row['games']), wins: _int(row['wins'])),
        ],
      );
}
