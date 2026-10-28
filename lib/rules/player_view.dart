import 'game_engine.dart';
import 'game_recap.dart';
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

  /// Chi si può scegliere per il compito alternativo, se non sono gli stessi
  /// [targets]: il Piromane accende scegliendo se stesso.
  final List<Player>? alternativeTargets;

  /// Di giorno, il Sindaco può ancora rivelarsi ([RevealMayor]).
  final bool canReveal;

  const ActionOption({
    required this.type,
    this.kind,
    required this.targets,
    this.current,
    this.alternative,
    this.alternativeTargets,
    this.canReveal = false,
  });

  Map<String, Object?> toJson() => {
    'type': type.name,
    'kind': kind?.name,
    'targets': seatsOf(targets),
    'current': seatOf(current),
    'alternative': alternative?.name,
    if (alternativeTargets != null) 'alternativeTargets': seatsOf(alternativeTargets!),
    if (canReveal) 'canReveal': true,
  };

  factory ActionOption.fromJson(Map<String, Object?> json, SeatResolver resolve) => ActionOption(
    type: ActionType.values.byName(json['type'] as String),
    kind: optionalEnum(NightTaskKind.values, json['kind']),
    targets: seatsFrom(json['targets'], resolve),
    current: optionalSeat(json['current'], resolve),
    alternative: optionalEnum(NightTaskKind.values, json['alternative']),
    alternativeTargets: json['alternativeTargets'] == null ? null : seatsFrom(json['alternativeTargets'], resolve),
    canReveal: json['canReveal'] as bool? ?? false,
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

  /// Il mazzo della partita: quanti di ogni ruolo. È pubblico (chi c'è al
  /// tavolo, non chi è chi). Vuoto se il server è vecchio.
  final Map<Role, int> deck;

  /// Chi ha vinto da solo: il Fesso linciato (anche a partita in corso), il
  /// Piromane rimasto in piedi.
  final List<Player> personalWins;

  /// Il Sindaco che si è rivelato oggi: il suo voto vale due.
  final Player? mayor;

  /// Il resoconto completo (tutte le mosse, tutti i ruoli). Solo a partita
  /// finita: fino ad allora `null`, e sul filo non c'è.
  final GameRecap? recap;

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
    this.deck = const {},
    this.personalWins = const [],
    this.mayor,
    this.recap,
  });

  /// [player] ha vinto: con la sua fazione o da solo. Si sa a partita finita
  /// (le carte di tutti), o da subito per chi vince da solo.
  bool won(Player player) =>
      personalWins.contains(player) || (winner != null && winner != Team.neutral && finalRoles[player]?.team == winner);

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
    'deck': [
      for (final entry in deck.entries) {'role': entry.key.name, 'count': entry.value},
    ],
    'personalWins': seatsOf(personalWins),
    'mayor': seatOf(mayor),
    if (recap != null) 'recap': recap!.toJson(),
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
    deck: {
      for (final row in _rows(json['deck'] ?? const [])) Role.values.byName(row['role'] as String): row['count'] as int,
    },
    personalWins: json['personalWins'] == null ? const [] : seatsFrom(json['personalWins'], resolve),
    mayor: optionalSeat(json['mayor'], resolve),
    recap: json['recap'] == null ? null : GameRecap.fromJson(json['recap'] as Map<String, Object?>, resolve),
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

  /// Per il Piromane: chi ha cosparso ed è ancora vivo. Vuoto per tutti gli
  /// altri: nessuno sa di essere cosparso.
  final List<Player> doused;

  /// Per il Cacciatore di taglie: chi deve far linciare. `null` per tutti
  /// gli altri.
  final Player? bounty;

  /// Per il Portinaio: le porte che ha guardato e se qualcuno ci è passato.
  final List<WatchReport> watches;
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
    this.doused = const [],
    this.bounty,
    this.watches = const [],
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
    'nightChoice': nightChoice == null ? null : {'kind': nightChoice!.kind.name, 'target': seatOf(nightChoice!.target)},
    'familyVotes': [for (final vote in familyVotes) _voteToJson(vote)],
    'silenced': silenced,
    'familyChat': familyChat,
    'doused': seatsOf(doused),
    if (bounty != null) 'bounty': seatOf(bounty),
    'watches': [
      for (final watch in watches) {'round': watch.round, 'seat': watch.target.id, 'visited': watch.visited},
    ],
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
      doused: json['doused'] == null ? const [] : seatsFrom(json['doused'], resolve),
      bounty: optionalSeat(json['bounty'], resolve),
      watches: [
        for (final row in _rows(json['watches'] ?? const []))
          (round: row['round'] as int, target: resolve(row['seat'] as String), visited: row['visited'] as bool),
      ],
      board: PublicView.fromJson(json['board'] as Map<String, Object?>, resolve),
    );
  }
}

/// Quanti di ogni ruolo, nell'ordine delle carte.
Map<Role, int> deckOf(Iterable<Role> roles) {
  final counts = <Role, int>{};
  for (final role in roles) {
    counts[role] = (counts[role] ?? 0) + 1;
  }
  return {for (final role in Role.values) role: ?counts[role]};
}
