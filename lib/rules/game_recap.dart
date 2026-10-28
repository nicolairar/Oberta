import 'game_engine.dart';
import 'intent.dart';
import 'player.dart';
import 'player_view.dart';
import 'role.dart';
import 'rules_json.dart';

/// Una mossa vera della notte (niente copertura, niente "passo"), con quello
/// che ha fruttato a chi l'ha fatta: la fazione che risultava al
/// Commissario, il ruolo trovato dal Becchino, se il Portinaio ha visto
/// passare qualcuno.
class RecapMove {
  final Player actor;
  final NightTaskKind kind;
  final Player target;
  final Team? seen;
  final Role? role;
  final bool? visited;

  const RecapMove(this.actor, this.kind, this.target, {this.seen, this.role, this.visited});

  Map<String, Object?> toJson() => {
    'actor': actor.id,
    'kind': kind.name,
    'target': target.id,
    'seen': seen?.name,
    'role': role?.name,
    'visited': visited,
  };

  factory RecapMove.fromJson(Map<String, Object?> json, SeatResolver resolve) => RecapMove(
    resolve(json['actor'] as String),
    NightTaskKind.values.byName(json['kind'] as String),
    resolve(json['target'] as String),
    seen: optionalEnum(Team.values, json['seen']),
    role: optionalEnum(Role.values, json['role']),
    visited: json['visited'] as bool?,
  );
}

/// Una notte per intero: chi la famiglia ha votato, le mosse di tutti, e
/// l'alba così com'è andata davvero (anche chi si è salvato, e da chi).
class RecapNight {
  final int round;
  final List<SeatVote> familyVotes;
  final List<RecapMove> moves;
  final DawnReport dawn;

  const RecapNight({required this.round, required this.familyVotes, required this.moves, required this.dawn});

  Map<String, Object?> toJson() => {
    'round': round,
    'familyVotes': [
      for (final vote in familyVotes) {'seat': vote.voter.id, 'target': seatOf(vote.target)},
    ],
    'moves': [for (final move in moves) move.toJson()],
    'dawn': dawnToJson(dawn),
  };

  factory RecapNight.fromJson(Map<String, Object?> json, SeatResolver resolve) => RecapNight(
    round: json['round'] as int,
    familyVotes: [
      for (final row in _rows(json['familyVotes']))
        (voter: resolve(row['seat'] as String), target: optionalSeat(row['target'], resolve)),
    ],
    moves: [for (final row in _rows(json['moves'])) RecapMove.fromJson(row, resolve)],
    dawn: dawnFromJson(json['dawn'] as Map<String, Object?>, resolve),
  );
}

/// Un giorno: chi ha votato chi, se il Sindaco si è rivelato, il verdetto.
class RecapDay {
  final int round;
  final Player? mayor;
  final List<SeatVote> votes;
  final LynchReport lynch;

  const RecapDay({required this.round, this.mayor, required this.votes, required this.lynch});

  Map<String, Object?> toJson() => {
    'round': round,
    'mayor': seatOf(mayor),
    'votes': [
      for (final vote in votes) {'seat': vote.voter.id, 'target': seatOf(vote.target)},
    ],
    'lynch': lynchToJson(lynch),
  };

  factory RecapDay.fromJson(Map<String, Object?> json, SeatResolver resolve) => RecapDay(
    round: json['round'] as int,
    mayor: optionalSeat(json['mayor'], resolve),
    votes: [
      for (final row in _rows(json['votes']))
        (voter: resolve(row['seat'] as String), target: optionalSeat(row['target'], resolve)),
    ],
    lynch: lynchFromJson(json['lynch'] as Map<String, Object?>, resolve),
  );
}

/// Chi se n'è andato a partita in corso, e quando.
typedef RecapExit = ({int round, GamePhase phase, Player seat});

/// Il resoconto di una partita finita: tutte le carte, chi ha vinto, e
/// notte per notte, giorno per giorno, chi ha fatto cosa. Si ricava dal
/// registro del motore rigiocandolo, quindi è la verità; esce dal server
/// solo a partita finita ([GameEngine.publicView]).
class GameRecap {
  final Map<Player, Role> roles;
  final Team? winner;
  final List<Player> personalWins;
  final List<Player> survivors;
  final List<RecapNight> nights;
  final List<RecapDay> days;
  final List<RecapExit> exits;

  /// Le taglie dei Cacciatori: cacciatore -> bersaglio.
  final Map<Player, Player> bounties;

  const GameRecap({
    required this.roles,
    required this.winner,
    required this.personalWins,
    required this.survivors,
    required this.nights,
    required this.days,
    this.exits = const [],
    this.bounties = const {},
  });

  /// [player] ha vinto: con la sua fazione o da solo.
  bool won(Player player) =>
      personalWins.contains(player) || (winner != null && winner != Team.neutral && roles[player]?.team == winner);

  /// Il resoconto di [engine], rigiocando il suo registro. `null` se la
  /// partita non ha un seme (non si può rigiocare).
  static GameRecap? of(GameEngine engine) {
    final seed = engine.seed;
    if (seed == null) return null;
    final replay = GameEngine(engine.setup, settings: engine.settings, seed: seed);
    final nights = <RecapNight>[];
    final days = <RecapDay>[];
    final exits = <RecapExit>[];
    final bounties = <Player, Player>{
      for (final hunter in engine.setup.players) hunter: ?replay.bountyOf(hunter),
    };
    for (final command in engine.log) {
      switch (command) {
        case ResolveNightCommand():
          final round = replay.round;
          final choices = replay.nightChoices;
          final dawn = replay.resolveNight();
          nights.add(
            RecapNight(
              round: round,
              familyVotes: [
                for (final entry in choices.entries)
                  if (entry.value.kind == NightTaskKind.kill) (voter: entry.key, target: entry.value.target),
              ],
              moves: [
                for (final entry in choices.entries)
                  if (entry.value case (kind: final kind, target: final target?)
                      when kind != NightTaskKind.kill && kind != NightTaskKind.decoy)
                    RecapMove(
                      entry.key,
                      kind,
                      target,
                      seen: kind == NightTaskKind.investigate ? engine.setup.roleOf(target).apparentTeam : null,
                      role: kind == NightTaskKind.dig ? engine.setup.roleOf(target) : null,
                      visited: kind == NightTaskKind.watch
                          ? replay.watchesOf(entry.key).where((w) => w.round == round).firstOrNull?.visited
                          : null,
                    ),
              ],
              dawn: dawn,
            ),
          );
        case CloseDayVoteCommand():
          final round = replay.round;
          final mayor = replay.mayor;
          final votes = [for (final entry in replay.dayVotes.entries) (voter: entry.key, target: entry.value)];
          days.add(RecapDay(round: round, mayor: mayor, votes: votes, lynch: replay.closeDayVote()));
        case LynchCommand(:final seat):
          final round = replay.round;
          final mayor = replay.mayor;
          final votes = [for (final entry in replay.dayVotes.entries) (voter: entry.key, target: entry.value)];
          final condemned = seat == null ? null : engine.setup.players.firstWhere((p) => p.id == seat);
          days.add(RecapDay(round: round, mayor: mayor, votes: votes, lynch: replay.lynch(condemned)));
        case LeaveTownCommand(:final seat):
          final player = engine.setup.players.firstWhere((p) => p.id == seat);
          exits.add((round: replay.round, phase: replay.phase, seat: player));
          replay.run(command);
        case IntentCommand():
          replay.run(command);
      }
    }
    return GameRecap(
      roles: engine.setup.roles,
      winner: engine.winner,
      personalWins: engine.personalWins,
      survivors: engine.alivePlayers,
      nights: nights,
      days: days,
      exits: exits,
      bounties: bounties,
    );
  }

  Map<String, Object?> toJson() => {
    'roles': [
      for (final entry in roles.entries) {'seat': entry.key.id, 'role': entry.value.name},
    ],
    'winner': winner?.name,
    'personalWins': seatsOf(personalWins),
    'survivors': seatsOf(survivors),
    'nights': [for (final night in nights) night.toJson()],
    'days': [for (final day in days) day.toJson()],
    'exits': [
      for (final exit in exits) {'round': exit.round, 'phase': exit.phase.name, 'seat': exit.seat.id},
    ],
    'bounties': [
      for (final entry in bounties.entries) {'hunter': entry.key.id, 'seat': entry.value.id},
    ],
  };

  factory GameRecap.fromJson(Map<String, Object?> json, [SeatResolver resolve = seatPlayer]) => GameRecap(
    roles: {
      for (final row in _rows(json['roles'])) resolve(row['seat'] as String): Role.values.byName(row['role'] as String),
    },
    winner: optionalEnum(Team.values, json['winner']),
    personalWins: seatsFrom(json['personalWins'], resolve),
    survivors: seatsFrom(json['survivors'], resolve),
    nights: [for (final row in _rows(json['nights'])) RecapNight.fromJson(row, resolve)],
    days: [for (final row in _rows(json['days'])) RecapDay.fromJson(row, resolve)],
    exits: [
      for (final row in _rows(json['exits']))
        (
          round: row['round'] as int,
          phase: GamePhase.values.byName(row['phase'] as String),
          seat: resolve(row['seat'] as String),
        ),
    ],
    bounties: {
      for (final row in _rows(json['bounties'])) resolve(row['hunter'] as String): resolve(row['seat'] as String),
    },
  );
}

List<Map<String, Object?>> _rows(Object? json) =>
    ((json as List<Object?>?) ?? const []).cast<Map<String, Object?>>();
