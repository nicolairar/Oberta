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
      log: [for (final row in rows('log')) GameCommand.fromJson(row)],
    );
  }
}
