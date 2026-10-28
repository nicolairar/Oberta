import '../l10n/app_language.dart';
import 'game/match_rewards.dart' show RankTier;
import 'game/progress.dart';
import 'online_models.dart' show PlayerMarks, Profile;

export 'game/progress.dart' show Achievement, achievements, Metric;

/// A mission as the phone sees it: the server assigns it and moves it.
class MissionProgress {
  final String id;
  final String cadence;
  final String metric;
  final int target;
  final int progress;
  final int xp;
  final int coins;
  final bool completed;
  final DateTime? endsAt;

  const MissionProgress({
    required this.id,
    required this.cadence,
    required this.metric,
    required this.target,
    this.progress = 0,
    this.xp = 0,
    this.coins = 0,
    this.completed = false,
    this.endsAt,
  });

  bool get weekly => cadence == 'weekly';
  double get fraction => target <= 0 ? 1 : (progress / target).clamp(0.0, 1.0);

  factory MissionProgress.fromJson(Map<String, Object?> json) => MissionProgress(
        id: json['id'] as String,
        cadence: json['cadence'] as String? ?? 'daily',
        metric: json['metric'] as String? ?? '',
        target: (json['target'] as num?)?.toInt() ?? 1,
        progress: (json['progress'] as num?)?.toInt() ?? 0,
        xp: (json['xp'] as num?)?.toInt() ?? 0,
        coins: (json['coins'] as num?)?.toInt() ?? 0,
        completed: json['completed'] == true,
        endsAt: json['ends_at'] == null ? null : DateTime.fromMillisecondsSinceEpoch((json['ends_at'] as num).toInt()),
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

/// Missions, achievements and the leaderboard. Read-only: the server moves
/// everything when it settles a game.
abstract class ProgressRepository {
  Future<PlayerProgress> mine();
  Future<GameUnlocks> unlocksFor(String gameId);
  Future<Leaderboard> leaderboard(AppLanguage language);
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
        roles: [
          for (final row in (json['roles'] as List<Object?>? ?? const []))
            if (row is Map && row['role'] is String)
              (role: row['role'] as String, games: _int(row['games']), wins: _int(row['wins'])),
        ],
      );
}
