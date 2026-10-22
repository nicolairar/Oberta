import '../l10n/app_language.dart';
import 'game/match_rewards.dart';

export 'game/match_rewards.dart' show RankTier, Rating, Progression;

/// La classificata vista dal telefono: in coda o no, da quando, quanto si
/// aspetta, la stanza quando il server l'ha aperta, la pausa dopo troppi
/// abbandoni (solo la fine, mai il conteggio) e un avviso generico.
class RankedStatus {
  final bool queued;
  final AppLanguage? language;
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
  });

  static DateTime? _ms(Object? v) => v == null ? null : DateTime.fromMillisecondsSinceEpoch((v as num).toInt());

  factory RankedStatus.fromJson(Map<String, Object?> json) => RankedStatus(
        queued: json['queued'] == true,
        language: switch (json['language']) { 'it' => AppLanguage.it, 'en' => AppLanguage.en, _ => null },
        since: _ms(json['since']),
        waiting: (json['waiting'] as num?)?.toInt() ?? 0,
        estimate: json['estimate'] == null ? null : Duration(seconds: (json['estimate'] as num).toInt()),
        roomId: json['room'] as String?,
        seated: (json['seated'] as num?)?.toInt() ?? 0,
        testMatch: json['test'] == true,
        cooldownUntil: _ms(json['cooldown_until']),
        warning: json['warning'] == true,
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
      );
}

/// Quanti giocatori ci sono adesso, per la locandina della home.
class OnlineCounts {
  final int online;
  final Map<AppLanguage, int> queued;

  const OnlineCounts({this.online = 0, this.queued = const {}});

  /// Sotto questa soglia la locandina tace: pochi numeri fanno sembrare la
  /// città vuota.
  static const encouraging = 20;

  factory OnlineCounts.fromJson(Map<String, Object?> json) {
    final queued = (json['queued'] as Map?)?.cast<String, Object?>() ?? const {};
    return OnlineCounts(
      online: (json['online'] as num?)?.toInt() ?? 0,
      queued: {
        for (final language in AppLanguage.values)
          if (queued[language.name] case final num n) language: n.toInt(),
      },
    );
  }
}

/// La coda della classificata e i risultati. Il server decide tutto.
abstract class RankedRepository {
  Future<RankedStatus> status();
  Future<RankedStatus> enqueue(AppLanguage language);
  Future<void> leave();

  /// Quanti sono in giro (in partita, in sala, in coda) e quanti in coda per
  /// lingua: solo numeri, presi da una cache del server.
  Future<OnlineCounts> counts();

  /// Il proprio rating per lingua (solo per il grado: il numero non si mostra).
  Future<Map<AppLanguage, Rating>> ratings();

  /// L'ultima partita giocata, se c'è.
  /// L'ultima partita registrata; con [since], solo se registrata da allora
  /// (così chi esce prima della fine non vede la partita precedente).
  Future<MatchResult?> lastResult({DateTime? since});

  /// Le ultime [limit] partite giocate, dalla più recente.
  Future<List<MatchResult>> history({int limit = 5});
}

/// La classificata è pronta ma chiusa in questa build: la coda si apre solo
/// con `--dart-define=RANKED_DEBUG=true`.
const rankedDebug = bool.fromEnvironment('RANKED_DEBUG');
