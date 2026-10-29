import '../build_flags.dart';
import '../l10n/lobby_language.dart';
import 'game/match_rewards.dart';

export 'game/match_rewards.dart' show RankTier, Rating, Progression;

/// La classificata vista dal telefono: in coda o no, da quando, quanto si
/// aspetta, la stanza quando il server l'ha aperta, la pausa dopo troppi
/// abbandoni (solo la fine, mai il conteggio) e un avviso generico.
class RankedStatus {
  final bool queued;
  final LobbyLanguage? language;
  final DateTime? since;
  final int waiting;
  final Duration? estimate;
  final String? roomId;

  /// Quanti siedono nella sala d'attesa (mai chi).
  final int seated;

  /// Partita di prova (bot, non classificata): solo col flag di prova del server.
  final bool testMatch;
  final DateTime? cooldownUntil;
  final bool warning;

  /// Le mani di prova finite per il server ('family', 'town', 'solo'): la
  /// classificata le chiede tutte e tre, oppure 'skip' («Conosco già il
  /// gioco», [RankedRepository.skipTutorials]).
  final Set<String> tutorials;

  /// Chi ha detto «Conosco già il gioco»: la classificata è aperta.
  bool get tutorialsSkipped => tutorials.contains(skipTutorialsId);

  static const skipTutorialsId = 'skip';

  const RankedStatus({
    this.queued = false,
    this.language,
    this.since,
    this.waiting = 0,
    this.estimate,
    this.roomId,
    this.seated = 0,
    this.testMatch = false,
    this.cooldownUntil,
    this.warning = false,
    this.tutorials = const {},
  });

  static DateTime? _ms(Object? v) => v == null ? null : DateTime.fromMillisecondsSinceEpoch((v as num).toInt());

  factory RankedStatus.fromJson(Map<String, Object?> json) => RankedStatus(
        queued: json['queued'] == true,
        language: LobbyLanguage.tryParse(json['language'] as String?),
        since: _ms(json['since']),
        waiting: (json['waiting'] as num?)?.toInt() ?? 0,
        estimate: json['estimate'] == null ? null : Duration(seconds: (json['estimate'] as num).toInt()),
        roomId: json['room'] as String?,
        seated: (json['seated'] as num?)?.toInt() ?? 0,
        testMatch: json['test'] == true,
        cooldownUntil: _ms(json['cooldown_until']),
        warning: json['warning'] == true,
        tutorials: {...?(json['tutorials'] as List?)?.whereType<String>()},
      );
}

/// Quello che una partita online ha fruttato a chi l'ha giocata (una riga
/// della sua cronologia).
class MatchResult {
  final String gameId;
  final bool ranked;
  final bool testMatch;
  final bool won;
  final bool abandoned;

  /// Rimasto al tavolo senza giocare: niente premi (lo vede solo lui).
  final bool afk;
  final String role;
  final int xpGained;
  final int levelBefore;
  final int levelAfter;
  final int coinsGained;
  final double? ratingDelta;
  final double? ordinalAfter;

  /// La fazione ('citizens', 'mafia', 'neutral'), se nota.
  final String team;
  final bool survived;

  /// Quanto è durata la partita; null per quelle registrate prima.
  final int? durationSeconds;

  const MatchResult({
    required this.gameId,
    this.ranked = false,
    this.testMatch = false,
    required this.won,
    this.abandoned = false,
    this.afk = false,
    this.role = '',
    required this.xpGained,
    required this.levelBefore,
    required this.levelAfter,
    this.coinsGained = 0,
    this.ratingDelta,
    this.ordinalAfter,
    this.team = '',
    this.survived = false,
    this.durationSeconds,
  });

  bool get leveledUp => levelAfter > levelBefore;
  RankTier? get tier => ordinalAfter == null ? null : RankTier.of(ordinalAfter!);

  factory MatchResult.fromJson(Map<String, Object?> json) => MatchResult(
        gameId: json['game_id'] as String,
        ranked: json['ranked'] == true,
        testMatch: json['test_match'] == true,
        won: json['won'] == true,
        abandoned: json['abandoned'] == true,
        afk: json['afk'] == true,
        role: json['role'] as String? ?? '',
        xpGained: (json['xp_gained'] as num).toInt(),
        levelBefore: (json['level_before'] as num).toInt(),
        levelAfter: (json['level_after'] as num).toInt(),
        coinsGained: (json['coins_gained'] as num?)?.toInt() ?? 0,
        ratingDelta: (json['rating_delta'] as num?)?.toDouble(),
        ordinalAfter: (json['ordinal_after'] as num?)?.toDouble(),
        team: json['team'] as String? ?? '',
        survived: json['survived'] == true,
        durationSeconds: (json['duration_seconds'] as num?)?.toInt(),
      );
}

/// Quanti giocatori ci sono adesso, per la locandina della home.
class OnlineCounts {
  final int online;
  final Map<LobbyLanguage, int> queued;

  const OnlineCounts({this.online = 0, this.queued = const {}});

  /// Sotto questa soglia la locandina tace: pochi numeri fanno sembrare la
  /// città vuota.
  static const encouraging = 20;

  factory OnlineCounts.fromJson(Map<String, Object?> json) {
    final queued = (json['queued'] as Map?)?.cast<String, Object?>() ?? const {};
    return OnlineCounts(
      online: (json['online'] as num?)?.toInt() ?? 0,
      queued: {
        for (final MapEntry(:key, :value) in queued.entries)
          if ((LobbyLanguage.tryParse(key), value) case (final language?, final num n)) language: n.toInt(),
      },
    );
  }
}

/// La coda della classificata e i risultati. Il server decide tutto.
abstract class RankedRepository {
  Future<RankedStatus> status();
  Future<RankedStatus> enqueue(LobbyLanguage language);
  Future<void> leave();

  /// Registra una mano di prova finita ([faction]: 'family', 'town', 'solo').
  /// Ripeterla non cambia nulla. Ritorna quelle registrate.
  Future<Set<String>> completeTutorial(String faction);

  /// «Conosco già il gioco»: salta le tre mani di prova e apre la
  /// classificata (`tutorial_skip`). Ritorna quelle registrate, 'skip' compreso.
  Future<Set<String>> skipTutorials();

  /// Quanti sono in giro (in partita, in sala, in coda) e quanti in coda per
  /// lingua: solo numeri, presi da una cache del server.
  Future<OnlineCounts> counts();

  /// Il proprio rating per lingua (solo per il grado: il numero non si mostra).
  Future<Map<LobbyLanguage, Rating>> ratings();

  /// L'ultima partita giocata, se c'è.
  /// L'ultima partita registrata; con [since], solo se registrata da allora
  /// (così chi esce prima della fine non vede la partita precedente).
  Future<MatchResult?> lastResult({DateTime? since});

  /// Le ultime [limit] partite giocate, dalla più recente.
  Future<List<MatchResult>> history({int limit = 5});

  /// Le proprie statistiche (`my_stats`): solo i propri numeri.
  Future<PlayerStats> stats();
}

/// Partite e vittorie di un gruppo (un ruolo, una fazione, un tipo di tavolo).
class GamesWins {
  final int games;
  final int wins;

  const GamesWins(this.games, this.wins);

  static const none = GamesWins(0, 0);

  /// Da 0 a 1; zero senza partite.
  double get rate => games == 0 ? 0 : wins / games;

  factory GamesWins.fromJson(Object? json) {
    final m = (json as Map?)?.cast<String, Object?>() ?? const {};
    return GamesWins((m['games'] as num?)?.toInt() ?? 0, (m['wins'] as num?)?.toInt() ?? 0);
  }
}

/// I numeri di una fetta della cronologia (con o senza partite di prova).
class StatsSlice {
  final int games;
  final int wins;
  final int survived;
  final int abandoned;
  final int afk;

  /// Secondi al tavolo, sommati sulle [timed] partite misurate.
  final int seconds;
  final int timed;
  final GamesWins friends;
  final GamesWins ranked;
  final int longestStreak;

  /// Per fazione ('citizens', 'mafia', 'neutral') e per ruolo (nome).
  final Map<String, GamesWins> teams;
  final Map<String, GamesWins> roles;

  const StatsSlice({
    this.games = 0,
    this.wins = 0,
    this.survived = 0,
    this.abandoned = 0,
    this.afk = 0,
    this.seconds = 0,
    this.timed = 0,
    this.friends = GamesWins.none,
    this.ranked = GamesWins.none,
    this.longestStreak = 0,
    this.teams = const {},
    this.roles = const {},
  });

  int get losses => games - wins;
  double get winRate => games == 0 ? 0 : wins / games;
  double get survivedRate => games == 0 ? 0 : survived / games;

  /// Il ruolo giocato più spesso (a pari partite, quello con più vittorie).
  String? get favouriteRole {
    String? best;
    GamesWins? top;
    for (final MapEntry(:key, :value) in roles.entries) {
      if (value.games == 0) continue;
      if (top == null ||
          value.games > top.games ||
          (value.games == top.games && value.wins > top.wins) ||
          (value.games == top.games && value.wins == top.wins && key.compareTo(best!) < 0)) {
        best = key;
        top = value;
      }
    }
    return best;
  }

  static Map<String, GamesWins> _groups(Object? json) => {
    for (final MapEntry(:key, :value) in ((json as Map?)?.cast<String, Object?>() ?? const {}).entries)
      key: GamesWins.fromJson(value),
  };

  factory StatsSlice.fromJson(Object? json) {
    final m = (json as Map?)?.cast<String, Object?>() ?? const {};
    int n(String key) => (m[key] as num?)?.toInt() ?? 0;
    return StatsSlice(
      games: n('games'),
      wins: n('wins'),
      survived: n('survived'),
      abandoned: n('abandoned'),
      afk: n('afk'),
      seconds: n('seconds'),
      timed: n('timed'),
      friends: GamesWins.fromJson(m['friends']),
      ranked: GamesWins.fromJson(m['ranked']),
      longestStreak: n('longest_streak'),
      teams: _groups(m['teams']),
      roles: _groups(m['roles']),
    );
  }

  /// Gli stessi conti di `internal.stats_slice`, su una cronologia in ordine
  /// di gioco (per il server finto).
  factory StatsSlice.of(Iterable<MatchResult> matches) {
    var games = 0, wins = 0, survived = 0, abandoned = 0, afk = 0, seconds = 0, timed = 0;
    var streak = 0, longest = 0;
    var friends = GamesWins.none, ranked = GamesWins.none;
    final teams = <String, GamesWins>{};
    final roles = <String, GamesWins>{};
    GamesWins add(GamesWins g, bool won) => GamesWins(g.games + 1, g.wins + (won ? 1 : 0));
    for (final m in matches) {
      games++;
      if (m.won) wins++;
      if (m.survived) survived++;
      if (m.abandoned) abandoned++;
      if (m.afk) afk++;
      if (m.durationSeconds case final d?) {
        seconds += d;
        timed++;
      }
      streak = m.won ? streak + 1 : 0;
      if (streak > longest) longest = streak;
      if (m.ranked) {
        ranked = add(ranked, m.won);
      } else {
        friends = add(friends, m.won);
      }
      teams[m.team] = add(teams[m.team] ?? GamesWins.none, m.won);
      roles[m.role] = add(roles[m.role] ?? GamesWins.none, m.won);
    }
    return StatsSlice(
      games: games,
      wins: wins,
      survived: survived,
      abandoned: abandoned,
      afk: afk,
      seconds: seconds,
      timed: timed,
      friends: friends,
      ranked: ranked,
      longestStreak: longest,
      teams: teams,
      roles: roles,
    );
  }
}

/// Le statistiche del fascicolo: tutte le partite, solo quelle vere (senza
/// le partite di prova), quante erano di prova, e i contatori di sempre.
class PlayerStats {
  final StatsSlice all;
  final StatsSlice real;
  final int tests;
  final Map<String, int> counters;

  const PlayerStats({
    this.all = const StatsSlice(),
    this.real = const StatsSlice(),
    this.tests = 0,
    this.counters = const {},
  });

  StatsSlice slice({required bool withTests}) => withTests ? all : real;

  factory PlayerStats.fromJson(Map<String, Object?> json) => PlayerStats(
    all: StatsSlice.fromJson(json['all']),
    real: StatsSlice.fromJson(json['real']),
    tests: (json['tests'] as num?)?.toInt() ?? 0,
    counters: {
      for (final MapEntry(:key, :value) in ((json['counters'] as Map?)?.cast<String, Object?>() ?? const {}).entries)
        if (value is num) key: value.toInt(),
    },
  );
}

/// La classificata è pronta ma chiusa: la coda si apre solo in una build di
/// prova ([BuildFlags.testBuild]), mai in una da negozio.
const rankedDebug = BuildFlags.testBuild;
