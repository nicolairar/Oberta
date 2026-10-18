import 'game_engine.dart';
import 'intent.dart';
import 'knowledge.dart';
import 'player.dart';
import 'role.dart';
import 'rules_json.dart';

/// Quello che un posto sa di un altro.
class SeatKnowledge {
  final Player seat;
  final Knowledge knowledge;

  const SeatKnowledge(this.seat, this.knowledge);

  Map<String, Object?> toJson() => {'seat': seat.id, 'team': knowledge.team?.name, 'role': knowledge.role?.name};

  factory SeatKnowledge.fromJson(Map<String, Object?> json, SeatResolver resolve) => SeatKnowledge(
        resolve(json['seat'] as String),
        Knowledge(role: optionalEnum(Role.values, json['role']), team: optionalEnum(Team.values, json['team'])),
      );
}

/// Un voto: della piazza, o della famiglia per l'agguato. `null`: astensione.
typedef SeatVote = ({Player voter, Player? target});

Map<String, Object?> _voteToJson(SeatVote vote) => {'seat': vote.voter.id, 'target': seatOf(vote.target)};

SeatVote _voteFromJson(Map<String, Object?> json, SeatResolver resolve) =>
    (voter: resolve(json['seat'] as String), target: optionalSeat(json['target'], resolve));

List<Map<String, Object?>> _rows(Object? json) => (json as List<Object?>).cast<Map<String, Object?>>();

/// Che intenzione serve per la mossa di adesso.
enum ActionType {
  /// [NightAction].
  nightAction,

  /// [MafiaVote].
  mafiaVote,

  /// [DayVote].
  dayVote,
}

/// Cosa può fare un posto in questo momento. Passare ([Pass]) è sempre
/// permesso, di notte come di giorno.
class ActionOption {
  final ActionType type;

  /// Il compito della notte; `null` di giorno.
  final NightTaskKind? kind;

  /// Chi si può scegliere, in ordine di posto.
  final List<Player> targets;

  /// Di giorno, il voto già dato (che si può ancora cambiare).
  final Player? current;

  /// Di notte, un compito che si può fare al posto di [kind] sugli stessi
  /// bersagli, mandando un [NightAction]: il Sarto che cuce invece di votare.
  final NightTaskKind? alternative;

  const ActionOption({required this.type, this.kind, required this.targets, this.current, this.alternative});

  Map<String, Object?> toJson() => {
        'type': type.name,
        'kind': kind?.name,
        'targets': seatsOf(targets),
        'current': seatOf(current),
        'alternative': alternative?.name,
      };

  factory ActionOption.fromJson(Map<String, Object?> json, SeatResolver resolve) => ActionOption(
        type: ActionType.values.byName(json['type'] as String),
        kind: optionalEnum(NightTaskKind.values, json['kind']),
        targets: seatsFrom(json['targets'], resolve),
        current: optionalSeat(json['current'], resolve),
        alternative: optionalEnum(NightTaskKind.values, json['alternative']),
      );
}

/// Quello che lo schermo di tutti può mostrare: niente che non sia pubblico.
/// È anche la parte comune di ogni [PlayerView].
class PublicView {
  final int round;
  final GamePhase phase;
  final Team? winner;

  /// Tutti i posti al tavolo, in ordine, vivi e morti.
  final List<Player> seats;
  final List<Player> alive;

  /// I fatti pubblici: i ruoli dei condannati, gli scoop del giornale.
  final List<SeatKnowledge> revealed;
  final List<RoundRecord> history;

  /// L'ultima alba, così come la racconta il narratore.
  final DawnReport? lastDawn;
  final LynchReport? lastLynch;

  /// Di notte, quanti devono ancora fare la loro mossa. Solo il numero: chi
  /// ci mette di più non deve tradirsi.
  final int nightPending;

  /// Di giorno, i voti della piazza: si vota a viso aperto.
  final List<SeatVote> dayVotes;

  /// A partita finita, tutte le carte scoperte. Vuoto fino ad allora.
  final Map<Player, Role> finalRoles;

  const PublicView({
    required this.round,
    required this.phase,
    required this.winner,
    required this.seats,
    required this.alive,
    required this.revealed,
    required this.history,
    required this.lastDawn,
    required this.lastLynch,
    required this.nightPending,
    required this.dayVotes,
    required this.finalRoles,
  });

  Map<String, Object?> toJson() => {
        'round': round,
        'phase': phase.name,
        'winner': winner?.name,
        'seats': seatsOf(seats),
        'alive': seatsOf(alive),
        'revealed': [for (final known in revealed) known.toJson()],
        'history': [for (final record in history) roundToJson(record)],
        'lastDawn': lastDawn == null ? null : dawnToJson(lastDawn!),
        'lastLynch': lastLynch == null ? null : lynchToJson(lastLynch!),
        'nightPending': nightPending,
        'dayVotes': [for (final vote in dayVotes) _voteToJson(vote)],
        'finalRoles': [
          for (final entry in finalRoles.entries) {'seat': entry.key.id, 'role': entry.value.name},
        ],
      };

  factory PublicView.fromJson(Map<String, Object?> json, [SeatResolver resolve = seatPlayer]) => PublicView(
        round: json['round'] as int,
        phase: GamePhase.values.byName(json['phase'] as String),
        winner: optionalEnum(Team.values, json['winner']),
        seats: seatsFrom(json['seats'], resolve),
        alive: seatsFrom(json['alive'], resolve),
        revealed: [for (final row in _rows(json['revealed'])) SeatKnowledge.fromJson(row, resolve)],
        history: [for (final row in _rows(json['history'])) roundFromJson(row, resolve)],
        lastDawn: json['lastDawn'] == null ? null : dawnFromJson(json['lastDawn'] as Map<String, Object?>, resolve),
        lastLynch: json['lastLynch'] == null ? null : lynchFromJson(json['lastLynch'] as Map<String, Object?>, resolve),
        nightPending: json['nightPending'] as int,
        dayVotes: [for (final row in _rows(json['dayVotes'])) _voteFromJson(row, resolve)],
        finalRoles: {
          for (final row in _rows(json['finalRoles']))
            resolve(row['seat'] as String): Role.values.byName(row['role'] as String),
        },
      );
}

/// Quello che un posto, e solo lui, ha diritto di vedere. È tutto ciò che
/// l'autorità gli manda: il proprio ruolo, i complici se la squadra si
/// conosce, quello che ha scoperto, i fatti pubblici e la mossa di adesso.
class PlayerView {
  final Player seat;
  final bool alive;
  final Role role;
  final Team team;

  /// I complici che si conoscono tra loro (la famiglia).
  final List<Player> teammates;

  /// Tutto quello che questo posto sa degli altri, in ordine di posto: i
  /// complici, gli esiti delle indagini, le fosse scavate, i fatti pubblici.
  /// Un'indagine dice la fazione che *risulta*, non per forza quella vera.
  final List<SeatKnowledge> known;

  /// La mossa che può fare adesso; `null` se non ne ha (morto, ha già
  /// scelto stanotte, partita finita).
  final ActionOption? action;

  /// La mossa di stanotte, se l'ha già fatta (`target` nullo: ha passato).
  final NightChoice? nightChoice;

  /// Di notte, per chi è della famiglia: chi ha votato chi per l'agguato.
  final List<SeatVote> familyVotes;

  /// Oggi il Sarto gli ha cucito la bocca: non scrive nella chat della
  /// piazza, ma legge, vota e agisce.
  final bool silenced;

  /// Adesso può usare la chat della famiglia: di notte, o di giorno finché
  /// c'è un Compare vivo.
  final bool familyChat;
  final PublicView board;

  const PlayerView({
    required this.seat,
    required this.alive,
    required this.role,
    required this.team,
    required this.teammates,
    required this.known,
    required this.action,
    required this.nightChoice,
    required this.familyVotes,
    this.silenced = false,
    this.familyChat = false,
    required this.board,
  });

  Map<String, Object?> toJson() => {
        'seat': seat.id,
        'alive': alive,
        'role': role.name,
        'team': team.name,
        'teammates': seatsOf(teammates),
        'known': [for (final known in known) known.toJson()],
        'action': action?.toJson(),
        'nightChoice':
            nightChoice == null ? null : {'kind': nightChoice!.kind.name, 'target': seatOf(nightChoice!.target)},
        'familyVotes': [for (final vote in familyVotes) _voteToJson(vote)],
        'silenced': silenced,
        'familyChat': familyChat,
        'board': board.toJson(),
      };

  factory PlayerView.fromJson(Map<String, Object?> json, [SeatResolver resolve = seatPlayer]) {
    final choice = json['nightChoice'] as Map<String, Object?>?;
    final action = json['action'] as Map<String, Object?>?;
    return PlayerView(
      seat: resolve(json['seat'] as String),
      alive: json['alive'] as bool,
      role: Role.values.byName(json['role'] as String),
      team: Team.values.byName(json['team'] as String),
      teammates: seatsFrom(json['teammates'], resolve),
      known: [for (final row in _rows(json['known'])) SeatKnowledge.fromJson(row, resolve)],
      action: action == null ? null : ActionOption.fromJson(action, resolve),
      nightChoice: choice == null
          ? null
          : (
              kind: NightTaskKind.values.byName(choice['kind'] as String),
              target: optionalSeat(choice['target'], resolve),
            ),
      familyVotes: [for (final row in _rows(json['familyVotes'])) _voteFromJson(row, resolve)],
      silenced: json['silenced'] as bool? ?? false,
      familyChat: json['familyChat'] as bool? ?? false,
      board: PublicView.fromJson(json['board'] as Map<String, Object?>, resolve),
    );
  }
}
