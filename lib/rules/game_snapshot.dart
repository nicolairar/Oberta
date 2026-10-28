import 'game_engine.dart';
import 'game_settings.dart';
import 'game_setup.dart';
import 'intent.dart';
import 'knowledge.dart';
import 'player.dart';
import 'role.dart';
import 'rules_json.dart';

/// Una partita ferma in un istante: tutto quello che serve per riprenderla
/// con [GameEngine.fromSnapshot] e farla proseguire identica.
///
/// Contiene tutti i ruoli: resta all'autorità (host o server), non va mai a
/// un client. Ai client vanno le viste ([GameEngine.viewFor]).
///
/// Il sorteggio si riprende dal seme più l'elenco dei `nextInt` già chiesti
/// ([draws]); il registro ([log]) basta da solo a rigiocare la partita da
/// capo con [GameEngine.replay], ed è quello che lo storico conserva.
class GameSnapshot {
  /// Cambia quando il formato del JSON cambia in modo incompatibile.
  static const version = 1;

  final GameSetup setup;
  final GameSettings settings;
  final int seed;
  final List<int> draws;
  final GamePhase phase;
  final int round;
  final Team? winner;
  final List<Player> alive;

  /// Le mosse della notte in corso, nell'ordine in cui sono arrivate.
  final List<({Player seat, NightTaskKind kind, Player? target})> nightChoices;

  /// I voti della piazza di oggi, nell'ordine in cui sono arrivati.
  final List<({Player voter, Player? target})> dayVotes;
  final List<Fact> facts;
  final Map<Player, int> suspicion;
  final List<RoundRecord> history;
  final bool sniperSpent;
  final bool scoopSpent;
  final Player? lastProtected;
  final Player? lastSilenced;

  /// Il Sarto ha già usato il suo unico silenzio.
  final bool silenceSpent;
  final Set<Player> scarred;
  final DawnReport? lastDawn;
  final LynchReport? lastLynch;

  /// Chi il Piromane ha cosparso ed è ancora vivo.
  final Set<Player> doused;

  /// Quello che ogni Portinaio ha visto.
  final List<({Player watcher, WatchReport report})> watches;

  /// Chi ha vinto da solo (Fesso, Piromane).
  final List<Player> personalWins;

  /// Il Messia ha già usato la sua resurrezione.
  final bool resurrectionSpent;

  /// Il giro in cui il Sindaco si è rivelato.
  final int? mayorRound;

  /// La taglia di ogni Cacciatore: cacciatore -> bersaglio.
  final Map<Player, Player> bounties;

  /// A chi lo Strozzino ha prestato la notte scorsa.
  final Player? lastLent;

  /// Chi il Carceriere ha chiuso in cella, e con chi la Prostituta ha
  /// passato la notte, la notte scorsa; chi è stato tenuto occupato.
  final Player? lastJailed;
  final Player? lastBlocked;
  final Player? busy;

  /// Il giro della tregua del Pacifista, e chi ha svelato.
  final int? truceRound;
  final Player? truceTarget;

  /// Le risposte arrivate all'alba, notte per notte.
  final List<({Player actor, int round, Exposure exposure})> findings;
  final List<GameCommand> log;

  const GameSnapshot({
    required this.setup,
    required this.settings,
    required this.seed,
    required this.draws,
    required this.phase,
    required this.round,
    required this.winner,
    required this.alive,
    required this.nightChoices,
    required this.dayVotes,
    required this.facts,
    required this.suspicion,
    required this.history,
    required this.sniperSpent,
    required this.scoopSpent,
    required this.lastProtected,
    required this.lastSilenced,
    this.silenceSpent = false,
    required this.scarred,
    required this.lastDawn,
    required this.lastLynch,
    this.doused = const {},
    this.watches = const [],
    this.personalWins = const [],
    this.resurrectionSpent = false,
    this.mayorRound,
    this.bounties = const {},
    this.lastLent,
    this.lastJailed,
    this.lastBlocked,
    this.busy,
    this.truceRound,
    this.truceTarget,
    this.findings = const [],
    required this.log,
  });

  Map<String, Object?> toJson() => {
        'version': version,
        'setup': setupToJson(setup),
        'settings': settingsToJson(settings),
        'seed': seed,
        'draws': draws,
        'phase': phase.name,
        'round': round,
        'winner': winner?.name,
        'alive': seatsOf(alive),
        'nightChoices': [
          for (final choice in nightChoices)
            {'seat': choice.seat.id, 'kind': choice.kind.name, 'target': seatOf(choice.target)},
        ],
        'dayVotes': [
          for (final vote in dayVotes) {'seat': vote.voter.id, 'target': seatOf(vote.target)},
        ],
        'facts': [for (final fact in facts) factToJson(fact)],
        'suspicion': [
          for (final entry in suspicion.entries) {'seat': entry.key.id, 'count': entry.value},
        ],
        'history': [for (final record in history) roundToJson(record)],
        'sniperSpent': sniperSpent,
        'scoopSpent': scoopSpent,
        'lastProtected': seatOf(lastProtected),
        'lastSilenced': seatOf(lastSilenced),
        'silenceSpent': silenceSpent,
        'scarred': seatsOf(scarred),
        'lastDawn': lastDawn == null ? null : dawnToJson(lastDawn!),
        'lastLynch': lastLynch == null ? null : lynchToJson(lastLynch!),
    'doused': seatsOf(doused),
    'watches': [
      for (final watch in watches)
        {
          'watcher': watch.watcher.id,
          'round': watch.report.round,
          'seat': watch.report.target.id,
          'visited': watch.report.visited,
        },
    ],
    'personalWins': seatsOf(personalWins),
    'resurrectionSpent': resurrectionSpent,
    'mayorRound': mayorRound,
    'bounties': [
      for (final entry in bounties.entries) {'hunter': entry.key.id, 'seat': entry.value.id},
    ],
    'lastLent': seatOf(lastLent),
    if (lastJailed != null) 'lastJailed': seatOf(lastJailed),
    if (lastBlocked != null) 'lastBlocked': seatOf(lastBlocked),
    if (busy != null) 'busy': seatOf(busy),
    if (truceRound != null) 'truceRound': truceRound,
    if (truceTarget != null) 'truceTarget': seatOf(truceTarget),
    if (findings.isNotEmpty)
      'findings': [
        for (final finding in findings)
          {'actor': finding.actor.id, 'round': finding.round, 'exposure': exposureToJson(finding.exposure)},
      ],
        'log': [for (final command in log) command.toJson()],
      };

  /// [resolve] trasforma un posto nel [Player] che lo occupa: di base il
  /// posto fa anche da nome.
  factory GameSnapshot.fromJson(Map<String, Object?> json, [SeatResolver resolve = seatPlayer]) {
    if (json['version'] != version) {
      throw FormatException('versione della fotografia non supportata: ${json['version']}');
    }
    // Ogni posto diventa un solo Player, lo stesso ovunque compaia.
    final players = <String, Player>{};
    Player seat(String id) => players.putIfAbsent(id, () => resolve(id));
    List<Map<String, Object?>> rows(String key) => (json[key] as List<Object?>).cast<Map<String, Object?>>();
    Map<String, Object?>? object(String key) => json[key] as Map<String, Object?>?;

    return GameSnapshot(
      setup: setupFromJson(json['setup'] as Map<String, Object?>, seat),
      settings: settingsFromJson(json['settings'] as Map<String, Object?>),
      seed: json['seed'] as int,
      draws: List.unmodifiable((json['draws'] as List<Object?>).cast<int>()),
      phase: GamePhase.values.byName(json['phase'] as String),
      round: json['round'] as int,
      winner: optionalEnum(Team.values, json['winner']),
      alive: seatsFrom(json['alive'], seat),
      nightChoices: [
        for (final row in rows('nightChoices'))
          (
            seat: seat(row['seat'] as String),
            kind: NightTaskKind.values.byName(row['kind'] as String),
            target: optionalSeat(row['target'], seat),
          ),
      ],
      dayVotes: [
        for (final row in rows('dayVotes'))
          (voter: seat(row['seat'] as String), target: optionalSeat(row['target'], seat)),
      ],
      facts: [for (final row in rows('facts')) factFromJson(row, seat)],
      suspicion: {for (final row in rows('suspicion')) seat(row['seat'] as String): row['count'] as int},
      history: [for (final row in rows('history')) roundFromJson(row, seat)],
      sniperSpent: json['sniperSpent'] as bool,
      scoopSpent: json['scoopSpent'] as bool,
      lastProtected: optionalSeat(json['lastProtected'], seat),
      lastSilenced: optionalSeat(json['lastSilenced'], seat),
      // Le fotografie di prima: il silenzio è speso se qualcuno l'ha già avuto.
      silenceSpent: json['silenceSpent'] as bool? ?? json['lastSilenced'] != null,
      scarred: seatsFrom(json['scarred'], seat).toSet(),
      lastDawn: object('lastDawn') == null ? null : dawnFromJson(object('lastDawn')!, seat),
      lastLynch: object('lastLynch') == null ? null : lynchFromJson(object('lastLynch')!, seat),
      // Le fotografie di prima dei neutrali non hanno questi campi.
      doused: json['doused'] == null ? const {} : seatsFrom(json['doused'], seat).toSet(),
      watches: [
        for (final row in (json['watches'] as List<Object?>? ?? const []).cast<Map<String, Object?>>())
          (
            watcher: seat(row['watcher'] as String),
            report: (round: row['round'] as int, target: seat(row['seat'] as String), visited: row['visited'] as bool),
          ),
      ],
      personalWins: json['personalWins'] == null ? const [] : seatsFrom(json['personalWins'], seat),
      resurrectionSpent: json['resurrectionSpent'] as bool? ?? false,
      mayorRound: json['mayorRound'] as int?,
      bounties: {
        for (final row in (json['bounties'] as List<Object?>? ?? const []).cast<Map<String, Object?>>())
          seat(row['hunter'] as String): seat(row['seat'] as String),
      },
      lastLent: optionalSeat(json['lastLent'], seat),
      lastJailed: optionalSeat(json['lastJailed'], seat),
      lastBlocked: optionalSeat(json['lastBlocked'], seat),
      busy: optionalSeat(json['busy'], seat),
      truceRound: json['truceRound'] as int?,
      truceTarget: optionalSeat(json['truceTarget'], seat),
      findings: [
        for (final row in (json['findings'] as List<Object?>? ?? const []).cast<Map<String, Object?>>())
          (
            actor: seat(row['actor'] as String),
            round: row['round'] as int,
            exposure: exposureFromJson(row['exposure'] as Map<String, Object?>, seat),
          ),
      ],
      log: [for (final row in rows('log')) GameCommand.fromJson(row)],
    );
  }
}
