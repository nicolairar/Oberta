import 'dart:math';

import 'game_settings.dart';
import 'game_setup.dart';
import 'game_recap.dart';
import 'game_snapshot.dart';
import 'intent.dart';
import 'knowledge.dart';
import 'player.dart';
import 'player_view.dart';
import 'role.dart';
import 'vote.dart';

enum GamePhase { night, day, ended }

/// Quanti semi ci sono: 2^32. Scritto per esteso e non come `1 << 32`, che
/// compilato in JavaScript (il motore gira anche sul server) fa zero.
const seedRange = 0x100000000;

/// Cosa fa davvero un giocatore di notte. [decoy] è il compito di copertura:
/// stesso gesto degli altri, nessun effetto sulla partita.
enum NightTaskKind {
  kill,
  silence,
  protect,
  guard,
  investigate,
  dig,
  snipe,
  scoop,

  /// Il Piromane cosparge di benzina qualcuno.
  douse,

  /// Il Piromane dà fuoco a tutti quelli cosparsi (il compito alternativo).
  ignite,

  /// Il Messia riporta in vita un cittadino linciato.
  resurrect,

  /// Lo Strozzino presta soldi a qualcuno: un debitore morto non paga, e
  /// stanotte nessuno glielo tocca.
  lend,

  /// Il Sicario colpisce, in proprio, ogni notte.
  stab,

  /// Il Portinaio guarda una porta: saprà se qualcuno ci è passato.
  watch,
  decoy,

  /// Il Carceriere chiude qualcuno in cella: stanotte non agisce e non
  /// muore. Si decide una volta, e subito: il prigioniero lo sa.
  jail,

  /// La Prostituta passa la notte con qualcuno: la sua mossa salta.
  block,

  /// Cupido, la prima notte, lega due innamorati ([Link]).
  link,
}

/// Quello che il Portinaio ha visto dalla sua guardiola: se stanotte
/// qualcuno è passato da [target]. Chi, non lo sa.
typedef WatchReport = ({int round, Player target, bool visited});

class NightTask {
  final NightTaskKind kind;

  /// Chi può essere scelto. Passare è sempre permesso.
  final List<Player> targets;

  /// Un secondo compito che si può fare al posto di [kind], sugli stessi
  /// [targets]: il Sarto, finché ha l'ago, vota l'agguato oppure cuce.
  final NightTaskKind? alternative;

  /// Chi si può scegliere per il compito alternativo: di solito gli stessi
  /// [targets]; per il Piromane che accende il fiammifero, solo se stesso.
  final List<Player> alternativeTargets;

  const NightTask(this.kind, this.targets, {this.alternative, List<Player>? alternativeTargets})
    : alternativeTargets = alternativeTargets ?? targets;
}

/// Qualcosa su qualcuno, venuto a galla: la fazione, a volte anche il ruolo.
class Exposure {
  final Player subject;

  /// La fazione così come risulta a chi l'ha scoperta. Il giornale scrive
  /// quella vera; al Commissario arriva quella che sembra.
  final Team team;

  /// Il ruolo esatto, quando salta fuori anche quello: lo trova il Becchino.
  final Role? role;

  const Exposure(this.subject, this.team, {this.role});
}

/// Chi ha colpito, di notte.
enum AttackSource { family, sniper, fire, assassin }

/// Com'è finito un agguato: a segno, fermato in tempo dal Dottore, o
/// incassato da chi ha la pelle dura.
enum AttackOutcome { killed, healed, shrugged }

/// Un agguato della notte. All'alba va in scena così com'è andato.
class NightAttack {
  /// Chi è stato colpito, per come lo vede il tavolo. Se un Guardaspalle si
  /// è messo in mezzo c'è lui, e di chi fosse il vero bersaglio non resta
  /// traccia.
  final Player target;
  final AttackSource source;
  final AttackOutcome outcome;

  const NightAttack(this.target, this.source, this.outcome);

  bool get isFatal => outcome == AttackOutcome.killed;
}

class DawnReport {
  final int round;

  /// Gli agguati della notte, uno per persona presa di mira, in ordine di
  /// posto. Chi è finito nel mirino di tutti e due conta per la famiglia.
  final List<NightAttack> attacks;

  /// Lo scoop pubblicato dal giornale, se il giornalista ha visto l'alba.
  final Exposure? scoop;

  /// A chi il Sarto ha cucito la bocca: oggi non può parlare. `null` se non
  /// ha scelto nessuno, o se chi aveva scelto non ha visto l'alba.
  final Player? silenced;

  /// Chi il Messia ha riportato in vita stanotte: torna con il suo ruolo,
  /// già noto a tutti. `null` se nessuno, o se il Messia non ha visto l'alba.
  final Player? resurrected;

  /// Chi è morto di crepacuore stanotte: l'innamorato di un morto.
  final List<Player> heartbroken;
  final Team? winner;

  const DawnReport({
    required this.round,
    this.attacks = const [],
    this.scoop,
    this.silenced,
    this.resurrected,
    this.heartbroken = const [],
    this.winner,
  });

  /// Il Piromane ha acceso il fiammifero stanotte (e qualcuno era cosparso).
  bool get ignited => attacks.any((attack) => attack.source == AttackSource.fire);

  /// Morti della notte, in ordine di posto (chi è morto di crepacuore in
  /// fondo). I loro ruoli restano segreti.
  List<Player> get victims => [
    for (final attack in attacks)
      if (attack.isFatal) attack.target,
    ...heartbroken,
  ];
}

class LynchReport {
  final int round;

  /// `null` se la piazza non ha condannato nessuno.
  final Player? condemned;

  /// Il ruolo del condannato, che il linciaggio rende pubblico.
  final Role? role;
  final Team? winner;

  /// Il condannato vince da solo: il Fesso voleva proprio questo.
  final bool personalWin;

  /// Il Cacciatore di taglie che incassa: il condannato era la sua taglia.
  final Player? bountyHunter;

  /// Oggi il Pacifista ha chiesto la tregua: niente voto, niente condanna.
  final bool truce;

  /// L'innamorato del condannato, morto di crepacuore sul posto.
  final Player? heartbroken;

  const LynchReport({
    required this.round,
    this.condemned,
    this.role,
    this.winner,
    this.personalWin = false,
    this.bountyHunter,
    this.truce = false,
    this.heartbroken,
  });
}

class RoundRecord {
  final int round;
  final List<Player> nightVictims;
  final Player? lynched;

  /// Chi è morto di giorno senza il voto: di crepacuore, o colpito.
  final List<Player> dayVictims;

  const RoundRecord({required this.round, required this.nightVictims, this.lynched, this.dayVictims = const []});
}

/// La mossa notturna di qualcuno: cosa faceva e su chi (`null`: ha passato).
typedef NightChoice = ({NightTaskKind kind, Player? target});

/// Il motore di una partita: riceve intenzioni ("di notte scelgo Marco",
/// "la piazza condanna Sara") e decide cosa succede. Niente rete, niente UI.
///
/// Il motore conosce solo i **posti**: per lui `Player.id` è l'id del posto
/// in partita. Chi siede dove, con quale nome o profilo, sta fuori dal
/// motore (vedi `Seating`).
///
/// Si guida in due modi, che si possono mescolare:
/// - **un telefono per tutti:** [taskFor], [submitNightChoice],
///   [resolveNight], [lynch]. Una mossa non valida lancia un errore;
/// - **un'autorità in rete** (il telefono host, o il server): [apply] riceve
///   una [PlayerIntent] da un client, non lancia mai e risponde con un
///   [IntentResult]; [viewFor] calcola cosa mandare a ciascun posto, e
///   [publicView] cosa può mostrare lo schermo di tutti.
///
/// Con un seme la partita si fotografa ([snapshot]), si riprende
/// ([GameEngine.fromSnapshot]) e si rigioca ([GameEngine.replay]).
class GameEngine {
  final GameSetup setup;
  final GameSettings settings;
  final Random _random;

  /// Il seme del sorteggio. `null` se il [Random] è arrivato da fuori: la
  /// partita gira lo stesso, ma non si può fotografare.
  final int? seed;

  /// Il `max` di ogni `nextInt` chiesto a [_random], in ordine: con il seme
  /// basta a riportare il generatore esattamente dov'era.
  final List<int> _draws = [];
  final List<GameCommand> _log = [];

  final List<Player> _alive;
  final List<Fact> _facts = [];
  final Map<Player, NightChoice> _choices = {};
  final Map<Player, Player?> _dayVotes = {};
  final Map<Player, int> _suspicion = {};
  final List<RoundRecord> _history = [];

  GamePhase _phase = GamePhase.night;
  int _round = 1;
  bool _sniperSpent = false;
  bool _scoopSpent = false;
  Player? _lastProtected;
  Player? _lastSilenced;
  bool _silenceSpent = false;
  DawnReport? _lastDawn;
  LynchReport? _lastLynch;

  /// I Reduci che hanno già incassato il loro colpo: il prossimo va a segno.
  final Set<Player> _scarred = {};

  /// Chi il Piromane ha cosparso e non è ancora bruciato. Lo sa solo lui.
  final Set<Player> _doused = {};

  /// La taglia di ogni Cacciatore: un cittadino da far linciare, tirato a
  /// sorte all'inizio. Lo sa solo lui.
  final Map<Player, Player> _bounties = {};

  /// A chi lo Strozzino ha prestato la notte scorsa: mai due notti di fila.
  Player? _lastLent;

  /// Quello che il Portinaio ha visto, notte per notte.
  final List<({Player watcher, WatchReport report})> _watches = [];

  /// Le risposte arrivate all'alba ([findingsAtDawn]), notte per notte.
  final List<({Player actor, int round, Exposure exposure})> _findings = [];

  /// Chi ha vinto da solo, nell'ordine: il Fesso linciato, il Piromane.
  final List<Player> _personalWins = [];
  bool _resurrectionSpent = false;

  /// Il giro in cui il Sindaco si è rivelato: quel giorno il suo voto vale due.
  int? _mayorRound;
  Team? _winner;

  /// Gli innamorati di Cupido (due, o nessuno), e se lo sanno già (dalla
  /// prima alba). Il legame si spezza se uno torna dai morti o se ne va.
  final List<Player> _lovers = [];
  bool _loversTold = false;

  /// Chi il Carceriere ha chiuso in cella la notte scorsa: mai due di fila.
  Player? _lastJailed;

  /// Con chi la Prostituta ha passato la notte scorsa: mai due di fila.
  Player? _lastBlocked;

  /// Chi la Prostituta ha tenuto occupato l'ultima notte: lo sa solo lui,
  /// all'alba.
  Player? _busy;

  /// Il giro della tregua del Pacifista (una per partita) e chi ha svelato.
  int? _truceRound;
  Player? _truceTarget;

  /// Con qualcuno che blocca al tavolo (Prostituta, Carceriere) l'indagine e
  /// lo scavo rispondono all'alba, e solo se chi li fa non è stato fermato.
  late final bool findingsAtDawn = setup.roles.values.any((role) => role.isBlocker);

  /// [random] e [seed] si escludono. Senza nessuno dei due il motore tira un
  /// seme a caso, e la partita resta fotografabile.
  factory GameEngine(GameSetup setup, {GameSettings settings = const GameSettings(), Random? random, int? seed}) {
    if (random != null && seed != null) throw ArgumentError('random e seed si escludono');
    return GameEngine._start(setup, settings, random, random != null ? null : seed ?? Random().nextInt(seedRange));
  }

  GameEngine._start(this.setup, this.settings, Random? random, this.seed)
    : _random = random ?? Random(seed),
      _alive = setup.players {
    final mafiosi = {
      for (final player in _alive)
        if (_teamOf(player) == Team.mafia) player,
    };
    for (final player in _alive) {
      final isMafia = mafiosi.contains(player);
      _facts.add(
        Fact(
          subject: player,
          team: _teamOf(player),
          role: setup.roleOf(player),
          visibility: isMafia ? Visibility.team : Visibility.private,
          audience: isMafia ? mafiosi : {player},
        ),
      );
    }
    // Ogni Cacciatore di taglie riceve la sua: un cittadino, a sorte.
    for (final hunter in _alive) {
      if (setup.roleOf(hunter) != Role.cacciatore) continue;
      final marks = [
        for (final player in _alive)
          if (_teamOf(player) == Team.citizens) player,
      ];
      if (marks.isNotEmpty) _bounties[hunter] = marks[_draw(marks.length)];
    }
  }

  /// Riprende una partita da una sua fotografia: da qui in poi va avanti
  /// esattamente come sarebbe andata quella da cui è stata scattata.
  GameEngine.fromSnapshot(GameSnapshot snapshot)
    : setup = snapshot.setup,
      settings = snapshot.settings,
      seed = snapshot.seed,
      _random = Random(snapshot.seed),
      _alive = [...snapshot.alive] {
    snapshot.draws.forEach(_draw);
    _log.addAll(snapshot.log);
    _facts.addAll(snapshot.facts);
    for (final choice in snapshot.nightChoices) {
      _choices[choice.seat] = (kind: choice.kind, target: choice.target);
    }
    for (final vote in snapshot.dayVotes) {
      _dayVotes[vote.voter] = vote.target;
    }
    _suspicion.addAll(snapshot.suspicion);
    _history.addAll(snapshot.history);
    _scarred.addAll(snapshot.scarred);
    _phase = snapshot.phase;
    _round = snapshot.round;
    _winner = snapshot.winner;
    _sniperSpent = snapshot.sniperSpent;
    _scoopSpent = snapshot.scoopSpent;
    _lastProtected = snapshot.lastProtected;
    _lastSilenced = snapshot.lastSilenced;
    _silenceSpent = snapshot.silenceSpent;
    _lastDawn = snapshot.lastDawn;
    _lastLynch = snapshot.lastLynch;
    _doused.addAll(snapshot.doused);
    _watches.addAll(snapshot.watches);
    _personalWins.addAll(snapshot.personalWins);
    _resurrectionSpent = snapshot.resurrectionSpent;
    _mayorRound = snapshot.mayorRound;
    _bounties.addAll(snapshot.bounties);
    _lastLent = snapshot.lastLent;
    _lastJailed = snapshot.lastJailed;
    _lastBlocked = snapshot.lastBlocked;
    _busy = snapshot.busy;
    _truceRound = snapshot.truceRound;
    _truceTarget = snapshot.truceTarget;
    _findings.addAll(snapshot.findings);
    _lovers.addAll(snapshot.lovers);
    _loversTold = snapshot.loversTold;
  }

  /// Rigioca una partita dal principio: stesso tavolo, stesso seme, stessi
  /// comandi ([log]). Lancia uno [StateError] se un comando non sta in piedi.
  factory GameEngine.replay(
    GameSetup setup, {
    GameSettings settings = const GameSettings(),
    required int seed,
    required List<GameCommand> log,
  }) {
    final engine = GameEngine(setup, settings: settings, seed: seed);
    log.forEach(engine.run);
    return engine;
  }

  /// La partita così com'è adesso, pronta per il JSON. Serve un seme.
  GameSnapshot snapshot() {
    final seed = this.seed;
    if (seed == null) {
      throw StateError('una partita con un Random esterno non si può fotografare: usa seed');
    }
    return GameSnapshot(
      setup: setup,
      settings: settings,
      seed: seed,
      draws: List.unmodifiable(_draws),
      phase: _phase,
      round: _round,
      winner: _winner,
      alive: List.unmodifiable(_alive),
      nightChoices: [
        for (final entry in _choices.entries) (seat: entry.key, kind: entry.value.kind, target: entry.value.target),
      ],
      dayVotes: [for (final entry in _dayVotes.entries) (voter: entry.key, target: entry.value)],
      facts: List.unmodifiable(_facts),
      suspicion: Map.unmodifiable(_suspicion),
      history: List.unmodifiable(_history),
      sniperSpent: _sniperSpent,
      scoopSpent: _scoopSpent,
      lastProtected: _lastProtected,
      lastSilenced: _lastSilenced,
      silenceSpent: _silenceSpent,
      scarred: Set.unmodifiable(_scarred),
      lastDawn: _lastDawn,
      lastLynch: _lastLynch,
      doused: Set.unmodifiable(_doused),
      watches: List.unmodifiable(_watches),
      personalWins: List.unmodifiable(_personalWins),
      resurrectionSpent: _resurrectionSpent,
      mayorRound: _mayorRound,
      bounties: Map.unmodifiable(_bounties),
      lastLent: _lastLent,
      lastJailed: _lastJailed,
      lastBlocked: _lastBlocked,
      busy: _busy,
      truceRound: _truceRound,
      truceTarget: _truceTarget,
      findings: List.unmodifiable(_findings),
      lovers: List.unmodifiable(_lovers),
      loversTold: _loversTold,
      log: List.unmodifiable(_log),
    );
  }

  /// Tutto quello che è successo, in ordine: le intenzioni accettate e i
  /// comandi dell'autorità. Con il seme basta a rigiocare la partita.
  List<GameCommand> get log => List.unmodifiable(_log);

  /// Esegue un comando del registro, come fa [GameEngine.replay].
  void run(GameCommand command) {
    switch (command) {
      case IntentCommand(:final intent):
        if (apply(intent) case IntentRejected(:final error, :final message)) {
          throw StateError('intenzione rifiutata (${error.name}): $message');
        }
      case ResolveNightCommand():
        resolveNight();
      case CloseDayVoteCommand():
        closeDayVote();
      case LynchCommand(:final seat):
        final condemned = seat == null ? null : _seat(seat);
        if (seat != null && condemned == null) throw StateError('posto sconosciuto: $seat');
        lynch(condemned);
      case LeaveTownCommand(:final seat):
        final player = _seat(seat);
        if (player == null) throw StateError('posto sconosciuto: $seat');
        leaveTown(player);
    }
  }

  GamePhase get phase => _phase;
  int get round => _round;

  /// La fazione che ha vinto; [Team.neutral] se ha vinto il Piromane.
  Team? get winner => _winner;

  /// Chi ha vinto da solo, anche a partita ancora in corso (il Fesso).
  List<Player> get personalWins => List.unmodifiable(_personalWins);

  /// [player] ha vinto: con la sua fazione, o da solo.
  ///
  /// Il Cacciatore la cui taglia è morta senza passare dalla piazza si mette
  /// con la città: vince se vince lei.
  ///
  /// Gli innamorati vincono solo se a fine partita sono vivi tutti e due,
  /// chiunque vinca (e allora sono tra i [personalWins]).
  bool hasWon(Player player) {
    if (_lovers.contains(player)) return _personalWins.contains(player);
    return _personalWins.contains(player) ||
        (_winner != null && _winner != Team.neutral && _teamOf(player) == _winner) ||
        (_winner == Team.citizens && bountyLapsed(player));
  }

  bool _everDied(Player player) => _history.any(
    (record) =>
        record.lynched == player || record.nightVictims.contains(player) || record.dayVictims.contains(player),
  );

  /// Gli innamorati, per chi li può conoscere: Cupido da quando li ha
  /// legati, loro due dalla prima alba. Vuoto per tutti gli altri.
  List<Player> loversFor(Player viewer) {
    if (_lovers.isEmpty) return const [];
    if (setup.roleOf(viewer) == Role.cupido || (_loversTold && _lovers.contains(viewer))) {
      return List.unmodifiable(_lovers);
    }
    return const [];
  }

  /// Gli innamorati hanno vinto: vivi tutti e due a fine partita.
  bool get loversWon => _lovers.length == 2 && _lovers.every(_personalWins.contains);

  /// Gli innamorati vivi e che si conoscono: online hanno la loro chat.
  List<Player> get loversTogether =>
      _loversTold && _lovers.length == 2 && _lovers.every(isAlive) ? List.unmodifiable(_lovers) : const [];

  /// Chi muore di crepacuore se muoiono [dead]: l'innamorato ancora vivo.
  List<Player> _heartbreak(Iterable<Player> dead) {
    if (_lovers.length != 2) return const [];
    final gone = dead.toSet();
    return [
      for (final lover in _lovers)
        if (!gone.contains(lover) && isAlive(lover) && _lovers.any(gone.contains)) lover,
    ];
  }

  /// La taglia del Cacciatore [hunter], se ce l'ha.
  Player? bountyOf(Player hunter) => _bounties[hunter];

  /// La taglia di [hunter] è morta e lui non ha incassato: adesso gioca con
  /// la città.
  /// Una volta morta, la taglia resta scaduta anche se il Messia la
  /// riporta in vita.
  bool bountyLapsed(Player hunter) {
    final mark = _bounties[hunter];
    return mark != null && !_personalWins.contains(hunter) && (!isAlive(mark) || _everDied(mark));
  }

  /// Le risposte che [actor] ha avuto all'alba (indagini e scavi, quando
  /// al tavolo c'è chi blocca), con la notte. Sul telefono unico si leggono
  /// al turno dopo.
  List<({int round, Exposure exposure})> findingsOf(Player actor) => [
    for (final finding in _findings)
      if (finding.actor == actor) (round: finding.round, exposure: finding.exposure),
  ];

  /// Chi il Carceriere ha chiuso in cella l'ultima notte.
  Player? get lastJailed => _lastJailed;

  /// La Prostituta ha tenuto occupato [player] l'ultima notte (vale fino
  /// alla notte dopo: sul telefono unico lo si legge al proprio turno).
  bool wasBusy(Player player) => _busy == player;

  /// Quello che [watcher] ha visto dalla guardiola, notte per notte.
  List<WatchReport> watchesOf(Player watcher) => [
    for (final watch in _watches)
      if (watch.watcher == watcher) watch.report,
  ];

  /// Chi il Piromane ha cosparso ed è ancora vivo.
  Set<Player> get doused => Set.unmodifiable(_doused);

  /// Il Sindaco che si è rivelato oggi: il suo voto vale due.
  Player? get mayor {
    if (_mayorRound != _round || _phase != GamePhase.day) return null;
    for (final player in _alive) {
      if (setup.roleOf(player) == Role.sindaco) return player;
    }
    return null;
  }

  /// Il Sindaco si è già rivelato (lo fa una volta per partita).
  bool get mayorRevealed => _mayorRound != null;

  /// Il Pacifista ha già chiesto la sua tregua (una per partita).
  bool get truceSpent => _truceRound != null;

  /// Oggi c'è la tregua: il voto salta.
  bool get truceToday => _truceRound == _round && _phase == GamePhase.day;

  /// Il Pacifista che oggi ha chiesto la tregua, e chi ha svelato.
  Player? get pacifist => truceToday ? _roleHolder(Role.pacifista) : null;
  Player? get pacified => truceToday ? _truceTarget : null;

  Player? _roleHolder(Role role) {
    for (final player in setup.players) {
      if (setup.roleOf(player) == role) return player;
    }
    return null;
  }

  /// Chi è in cella stanotte (lo sanno il Carceriere, lui, e la Famiglia se
  /// è dei loro). `null` di giorno.
  Player? get jailedTonight => _phase == GamePhase.night ? _targetOf(NightTaskKind.jail) : null;

  /// Il Carceriere che stanotte ha chiuso qualcuno in cella.
  Player? get jailerTonight => jailedTonight == null ? null : _actorOf(NightTaskKind.jail);

  /// Chi la Prostituta ha tenuto occupato l'ultima notte: lo sa all'alba.
  bool isBusy(Player player) => _phase == GamePhase.day && _busy == player;
  List<Player> get alivePlayers => List.unmodifiable(_alive);
  List<RoundRecord> get history => List.unmodifiable(_history);

  /// Quante volte ciascuno è stato indicato nei compiti di copertura.
  Map<Player, int> get suspicion => Map.unmodifiable(_suspicion);

  bool isAlive(Player player) => _alive.contains(player);

  /// Il Sarto ha già cucito la sua bocca: lo fa una volta per partita.
  bool get silenceSpent => _silenceSpent;

  /// Oggi [player] non può scrivere nella chat della piazza: il Sarto gli
  /// ha cucito la bocca stanotte. Legge, vota e agisce come tutti.
  bool isSilenced(Player player) =>
      _phase == GamePhase.day && _lastDawn?.round == _round && _lastDawn?.silenced == player;

  /// Finché c'è un Compare vivo, la famiglia ha la sua chat anche di giorno.
  bool get familyDayChat => _alive.any((player) => setup.roleOf(player) == Role.compare);

  /// [player] può scrivere e leggere adesso nella chat della famiglia: vivo,
  /// della famiglia, di notte, o di giorno se c'è un Compare vivo.
  /// In cella non si parla con la Famiglia.
  bool canUseFamilyChat(Player player) =>
      isAlive(player) &&
      _teamOf(player) == Team.mafia &&
      player != jailedTonight &&
      (_phase == GamePhase.night || (_phase == GamePhase.day && familyDayChat));

  Team _teamOf(Player player) => setup.roleOf(player).team;

  /// Cosa [viewer] ha diritto di sapere su [subject]. Con `viewer` nullo
  /// restituisce solo ciò che è pubblico.
  ///
  /// Un'indagine dice la fazione che sembra; se sulla stessa persona c'è
  /// anche un fatto certo (uno scoop, un ruolo svelato), vale quello.
  Knowledge knowledgeOf(Player? viewer, Player subject) {
    Role? role;
    Team? certain;
    Team? apparent;
    for (final fact in _facts) {
      if (fact.subject != subject || !fact.visibleTo(viewer)) continue;
      role ??= fact.role;
      if (fact.apparent) {
        apparent = fact.team;
      } else {
        certain = fact.team;
      }
    }
    return Knowledge(role: role, team: certain ?? apparent);
  }

  List<Player> get pendingNightPlayers => [
    for (final player in _alive)
      if (!_choices.containsKey(player)) player,
  ];

  bool get nightComplete => _phase == GamePhase.night && pendingNightPlayers.isEmpty;

  /// La scelta di stanotte di [actor] non si cambia più: un'indagine o uno
  /// scavo hanno già dato la risposta. Ogni altra scelta (anche «passo») si
  /// può cambiare fino a quando la notte si chiude.
  bool nightChoiceLocked(Player actor) {
    final choice = _choices[actor];
    return choice != null && choice.target != null && _locks(choice.kind);
  }

  /// La mossa, una volta fatta, non si cambia: la cella si chiude subito,
  /// l'indagine e lo scavo danno subito la risposta (se nessuno blocca).
  bool _locks(NightTaskKind kind) =>
      kind == NightTaskKind.jail || kind == NightTaskKind.link || (kind.immediate && !findingsAtDawn);

  /// Ritira la scelta di stanotte di [actor], per sostituirla: anche il
  /// sospetto di una mossa di copertura torna indietro.
  void _retractNightChoice(Player actor) {
    final choice = _choices.remove(actor);
    if (choice == null) return;
    final target = choice.target;
    if (choice.kind == NightTaskKind.decoy && target != null) {
      final left = (_suspicion[target] ?? 0) - 1;
      if (left > 0) {
        _suspicion[target] = left;
      } else {
        _suspicion.remove(target);
      }
    }
  }

  NightTask taskFor(Player actor) {
    _require(GamePhase.night);
    if (!isAlive(actor)) throw StateError('${actor.name} non è più in gioco');
    final others = [
      for (final player in _alive)
        if (player != actor) player,
    ];
    // Le fosse ancora da scavare: chi è morto senza che il suo ruolo venisse
    // fuori, e che chi scava non ha già riesumato.
    final graves = [
      for (final player in setup.players)
        if (!isAlive(player) && knowledgeOf(actor, player).role == null) player,
    ];
    return switch (setup.roleOf(actor)) {
      // La famiglia può colpire chiunque, anche uno dei suoi: un morto in
      // casa, a volte, è il bluff migliore.
      // Il Compare vota come un Picciotto: il suo potere in più è la chat di
      // giorno, non un'altra mossa al posto dell'agguato.
      Role.mafioso || Role.padrino || Role.compare => NightTask(NightTaskKind.kill, others),
      // Il Sarto vota l'agguato come un Picciotto; una volta per partita,
      // al posto del voto, può cucire la bocca a qualcuno.
      Role.sarto => NightTask(NightTaskKind.kill, others, alternative: _silenceSpent ? null : NightTaskKind.silence),
      Role.medico => NightTask(NightTaskKind.protect, [
        for (final player in _alive)
          if (player != _lastProtected) player,
      ]),
      Role.guardaspalle => NightTask(NightTaskKind.guard, others),
      Role.detective => NightTask(NightTaskKind.investigate, others),
      // Senza morti da riesumare il Becchino fa finta, come gli altri.
      Role.becchino => graves.isEmpty ? NightTask(NightTaskKind.decoy, others) : NightTask(NightTaskKind.dig, graves),
      Role.cecchino => NightTask(_sniperSpent ? NightTaskKind.decoy : NightTaskKind.snipe, others),
      Role.giornalista => NightTask(_scoopSpent ? NightTaskKind.decoy : NightTaskKind.scoop, others),
      Role.portinaio => NightTask(NightTaskKind.watch, others),
      // Il Messia, una volta per partita, sceglie un morto qualsiasi.
      Role.messia =>
        _resurrectionSpent || _resurrectable.isEmpty
            ? NightTask(NightTaskKind.decoy, others)
            : NightTask(NightTaskKind.resurrect, _resurrectable),
      // Il Piromane cosparge chi non è ancora cosparso; se c'è qualcuno da
      // bruciare, può invece accendere (scegliendo se stesso).
      Role.piromane => NightTask(
        NightTaskKind.douse,
        [
          for (final player in others)
            if (!_doused.contains(player)) player,
        ],
        alternative: _doused.any(isAlive) ? NightTaskKind.ignite : null,
        alternativeTargets: [actor],
      ),
      // Lo Strozzino presta a chi vuole, ma non alla stessa persona due notti
      // di fila: un debitore morto non paga, e stanotte lo protegge.
      Role.strozzino => NightTask(NightTaskKind.lend, [
        for (final player in others)
          if (player != _lastLent) player,
      ]),
      // Il Sicario lavora da solo, ogni notte.
      Role.sicario => NightTask(NightTaskKind.stab, others),
      // Il Carceriere chiude in cella chi vuole, mai lo stesso due notti di fila.
      Role.carceriere => NightTask(NightTaskKind.jail, [
        for (final player in others)
          if (player != _lastJailed) player,
      ]),
      // La Prostituta non vota l'agguato, finché nella Famiglia c'è un altro
      // che lo vota: se resta sola, vota, e può ancora passare la notte fuori.
      Role.prostituta =>
        _alive.any((player) => player != actor && setup.roleOf(player).isKiller)
            ? NightTask(NightTaskKind.block, [
                for (final player in others)
                  if (player != _lastBlocked) player,
              ])
            : NightTask(
                NightTaskKind.kill,
                others,
                alternative: NightTaskKind.block,
                alternativeTargets: [
                  for (final player in others)
                    if (player != _lastBlocked) player,
                ],
              ),
      // Cupido, solo la prima notte, lega due persone (anche se stesso).
      Role.cupido =>
        _round == 1 && _lovers.isEmpty ? NightTask(NightTaskKind.link, [..._alive]) : NightTask(NightTaskKind.decoy, others),
      Role.cittadino ||
      Role.cacciatore ||
      Role.reduce ||
      Role.pregiudicato ||
      Role.sindaco ||
      Role.pacifista ||
      Role.fesso => NightTask(NightTaskKind.decoy, others),
    };
  }

  /// I morti, comunque siano morti: il Messia può scegliere chiunque tra
  /// loro, anche uno della Famiglia se si sbaglia. Chi torna da una morte
  /// di notte resta con il ruolo segreto.
  List<Player> get _resurrectable => [
    for (final player in setup.players)
      if (!isAlive(player)) player,
  ];

  /// Registra la mossa notturna di [actor]; `target` nullo significa "passo".
  /// Solo l'indagine e lo scavo danno una risposta immediata, e la danno
  /// solo a chi ha fatto la mossa.
  ///
  /// Con [alternative] fa il compito alternativo ([NightTask.alternative]):
  /// il Sarto che cuce invece di votare.
  ///
  /// Cupido lega due persone: [target] e [second].
  Exposure? submitNightChoice(Player actor, Player? target, {bool alternative = false, Player? second}) {
    final task = taskFor(actor);
    if (_choices.containsKey(actor)) throw StateError('${actor.name} ha già scelto');
    final kind = alternative ? task.alternative : task.kind;
    if (kind == null) throw StateError('${actor.name} non ha un compito alternativo');
    if (target != null && !(alternative ? task.alternativeTargets : task.targets).contains(target)) {
      throw ArgumentError.value(target.name, 'target', 'non può essere scelto da ${actor.name}');
    }
    if (alternative && target == null) throw ArgumentError('il compito alternativo vuole un bersaglio');
    if (kind == NightTaskKind.link && target != null) {
      if (second == null || second == target || !task.targets.contains(second)) {
        throw ArgumentError('Cupido lega due persone diverse');
      }
      _lovers
        ..clear()
        ..addAll([target, second]);
    }
    _choices[actor] = (kind: kind, target: target);
    _log.add(
      IntentCommand(switch ((kind, target)) {
        (_, null) => Pass(actor.id),
        (NightTaskKind.kill, final target?) => MafiaVote(actor.id, target.id),
        (NightTaskKind.link, final target?) => Link(actor.id, target.id, second!.id),
        (_, final target?) => NightAction(actor.id, target.id),
      }),
    );
    if (target == null) return null;

    if (kind == NightTaskKind.decoy) {
      _suspicion[target] = (_suspicion[target] ?? 0) + 1;
    }
    if (kind == NightTaskKind.jail) {
      // La cella si chiude adesso: la mossa del prigioniero salta, e
      // stanotte non ne fa altre.
      final task = taskFor(target);
      _retractNightChoice(target);
      _choices[target] = (kind: task.kind, target: null);
      return null;
    }
    // Con chi blocca al tavolo la risposta arriva all'alba (resolveNight).
    if (findingsAtDawn) return null;
    if (kind == NightTaskKind.investigate) {
      // Il Commissario legge le carte, e le carte a volte mentono.
      final team = setup.roleOf(target).apparentTeam;
      _facts.add(Fact(subject: target, team: team, visibility: Visibility.acquired, audience: {actor}, apparent: true));
      return Exposure(target, team);
    }
    if (kind == NightTaskKind.dig) {
      final role = setup.roleOf(target);
      _facts.add(
        Fact(subject: target, team: role.team, role: role, visibility: Visibility.acquired, audience: {actor}),
      );
      return Exposure(target, role.team, role: role);
    }
    return null;
  }

  /// Chiude la notte: tutte le mosse si risolvono insieme, quindi chi muore
  /// stanotte ha comunque fatto in tempo ad agire.
  ///
  /// L'ordine in cui si fanno i conti:
  /// 1. **I bersagli.** La famiglia vota il suo, il Cecchino sceglie il suo.
  ///    Chi finisce nel mirino di tutti e due subisce un agguato solo, e
  ///    conta per la famiglia.
  /// 2. **Il Dottore.** Un agguato contro chi è protetto si ferma lì
  ///    ([AttackOutcome.healed]), e nessun altro ci va di mezzo.
  /// 3. **Il Guardaspalle.** Se il bersaglio è la persona che scorta, e il
  ///    Dottore non la stava già coprendo, il colpo lo prende lui. Se il
  ///    Dottore proteggeva il Guardaspalle, vivono tutti e due. Nel rapporto
  ///    resta solo chi è stato colpito davvero.
  /// 4. **Il Reduce.** Il primo colpo che lo ucciderebbe va a vuoto
  ///    ([AttackOutcome.shrugged]) e la pelle dura è spesa. Un colpo fermato
  ///    dal Dottore non la consuma.
  /// 5. **I morti.** Chi resta colpito non vede l'alba, e il suo ruolo resta
  ///    segreto.
  ///
  /// Poi il resto: lo scoop esce solo se il Cronista è ancora vivo, e il
  /// silenzio del Sarto si annuncia solo se chi deve tacere ha visto l'alba.
  DawnReport resolveNight() {
    if (!nightComplete) throw StateError('la notte non è finita: manca qualcuno');
    _log.add(const ResolveNightCommand());

    // Prima la cella, poi la Prostituta: chi è fermo stanotte non fa niente
    // (la cella si chiude comunque). Una mossa fermata si spende lo stesso.
    final jailed = _targetOf(NightTaskKind.jail);
    final hooker = _actorOf(NightTaskKind.block);
    final hooked = _targetOf(NightTaskKind.block);
    final busy = hooker != null && hooker != jailed ? hooked : null;
    final stopped = {?jailed, ?busy};
    final live = {
      for (final entry in _choices.entries)
        if (!stopped.contains(entry.key) || entry.value.kind == NightTaskKind.jail) entry.key: entry.value,
    };
    Player? actorOf(NightTaskKind kind) => _actorIn(live, kind);
    Player? targetOf(NightTaskKind kind) => live[actorOf(kind)]?.target;

    final protected = {?targetOf(NightTaskKind.protect), ?targetOf(NightTaskKind.lend)};
    final lent = _targetOf(NightTaskKind.lend);
    final guard = actorOf(NightTaskKind.guard);
    final guarded = targetOf(NightTaskKind.guard);
    final sniped = targetOf(NightTaskKind.snipe);
    final sniperSpent = _targetOf(NightTaskKind.snipe) != null;
    final silenceTarget = targetOf(NightTaskKind.silence);
    final silenceSpent = _targetOf(NightTaskKind.silence) != null;
    final scoopTarget = targetOf(NightTaskKind.scoop);
    final scoopSpent = _targetOf(NightTaskKind.scoop) != null;
    final journalist = actorOf(NightTaskKind.scoop);
    final dousedTonight = targetOf(NightTaskKind.douse);
    final ignited = actorOf(NightTaskKind.ignite) != null;
    final messiah = actorOf(NightTaskKind.resurrect);
    final risen = targetOf(NightTaskKind.resurrect);
    final resurrectionSpent = _targetOf(NightTaskKind.resurrect) != null;

    // La famiglia sceglie una sola porta: solo chi ha votato quella ci va
    // davvero. Il sorteggio dello spareggio si fa qui, una volta sola.
    final familyTarget = _resolveMafiaVote(live);

    // Le risposte che aspettavano l'alba: a chi ha indagato o scavato e non
    // è stato fermato.
    if (findingsAtDawn) {
      for (final MapEntry(key: actor, value: choice) in live.entries) {
        final target = choice.target;
        if (target == null) continue;
        final role = setup.roleOf(target);
        if (choice.kind == NightTaskKind.investigate) {
          _facts.add(
            Fact(
              subject: target,
              team: role.apparentTeam,
              visibility: Visibility.acquired,
              audience: {actor},
              apparent: true,
            ),
          );
          _findings.add((actor: actor, round: _round, exposure: Exposure(target, role.apparentTeam)));
        } else if (choice.kind == NightTaskKind.dig) {
          _facts.add(
            Fact(subject: target, team: role.team, role: role, visibility: Visibility.acquired, audience: {actor}),
          );
          _findings.add((actor: actor, round: _round, exposure: Exposure(target, role.team, role: role)));
        }
      }
    }

    // Il Portinaio: qualcuno è passato dalla porta che guardava? Contano le
    // mosse vere, non i compiti di copertura, né i voti della famiglia
    // finiti su un'altra porta, né le mosse di chi è stato fermato.
    for (final entry in live.entries) {
      if (entry.value.kind != NightTaskKind.watch) continue;
      final watched = entry.value.target;
      if (watched == null) continue;
      final visited = live.entries.any(
        (other) =>
            other.key != entry.key &&
            other.value.target == watched &&
            other.value.kind.visits &&
            (other.value.kind != NightTaskKind.kill || watched == familyTarget),
      );
      _watches.add((watcher: entry.key, report: (round: _round, target: watched, visited: visited)));
    }

    // Chi viene colpito davvero, e da chi. La famiglia passa per prima.
    final struck = <Player, AttackSource>{};
    void aim(Player? target, AttackSource source) {
      // In cella non arriva nessuno.
      if (target == null || target == jailed) return;
      final shielded = target == guarded && !protected.contains(target);
      struck.putIfAbsent(shielded ? guard! : target, () => source);
    }

    aim(familyTarget, AttackSource.family);
    aim(sniped, AttackSource.sniper);
    aim(targetOf(NightTaskKind.stab), AttackSource.assassin);
    // Il fuoco non si ferma: niente Dottore, Strozzino, Guardaspalle o pelle
    // dura del Reduce. Chi brucia, brucia. Solo la cella lo tiene fuori: chi
    // è dentro resta cosparso.
    final burning = <Player>{};
    if (ignited) {
      for (final player in _alive) {
        if (!_doused.contains(player) || player == jailed) continue;
        burning.add(player);
        // Protetto dagli altri colpi ma cosparso: lo prende il fuoco.
        if (protected.contains(player) || setup.roleOf(player) == Role.reduce) {
          struck[player] = AttackSource.fire;
        } else {
          struck.putIfAbsent(player, () => AttackSource.fire);
        }
      }
      _doused.removeWhere((player) => player != jailed);
    }

    AttackOutcome land(Player target) {
      if (burning.contains(target)) return AttackOutcome.killed;
      if (protected.contains(target)) return AttackOutcome.healed;
      final tough = setup.roleOf(target) == Role.reduce && _scarred.add(target);
      return tough ? AttackOutcome.shrugged : AttackOutcome.killed;
    }

    final attacks = [
      for (final player in _alive)
        if (struck[player] case final source?) NightAttack(player, source, land(player)),
    ];
    final victims = [
      for (final attack in attacks)
        if (attack.isFatal) attack.target,
    ];

    // Il crepacuore: l'innamorato di chi muore stanotte muore con lui, e
    // niente lo ferma.
    final heartbroken = _heartbreak(victims);
    victims.addAll(heartbroken);

    if (sniperSpent) _sniperSpent = true;
    Exposure? scoop;
    if (scoopSpent) _scoopSpent = true;
    if (scoopTarget != null) {
      if (!victims.contains(journalist)) {
        scoop = Exposure(scoopTarget, _teamOf(scoopTarget));
        _facts.add(Fact(subject: scoopTarget, team: scoop.team, visibility: Visibility.public));
      }
    }

    _lastProtected = _targetOf(NightTaskKind.protect);
    _lastLent = lent;
    _lastJailed = jailed;
    _lastBlocked = hooked;
    _busy = busy;
    _lastSilenced = silenceTarget;
    if (silenceSpent) _silenceSpent = true;
    _alive.removeWhere(victims.contains);
    if (dousedTonight != null && _alive.contains(dousedTonight)) _doused.add(dousedTonight);
    _doused.removeWhere((player) => !_alive.contains(player));
    // Il Messia: se ha visto l'alba, chi ha scelto torna tra i vivi, prima
    // che si contino i vincitori.
    Player? resurrected;
    // Passare non spende la resurrezione: la spende solo una scelta vera
    // (anche se la Prostituta ferma il Messia).
    if (resurrectionSpent) _resurrectionSpent = true;
    if (messiah != null && risen != null) {
      if (!victims.contains(messiah)) {
        resurrected = risen;
        // Si conoscono solo loro due: chi torna sa chi l'ha riportato (e che
        // è il Messia), il Messia sa che carta ha chi è tornato. Nessun altro.
        final messiahRole = setup.roleOf(messiah);
        final risenRole = setup.roleOf(risen);
        _facts
          ..add(
            Fact(
              subject: messiah,
              team: messiahRole.team,
              role: messiahRole,
              visibility: Visibility.acquired,
              audience: {risen},
            ),
          )
          ..add(
            Fact(
              subject: risen,
              team: risenRole.team,
              role: risenRole,
              visibility: Visibility.acquired,
              audience: {messiah},
            ),
          );
        _alive
          ..add(risen)
          ..sort((a, b) => setup.players.indexOf(a).compareTo(setup.players.indexOf(b)));
        // Chi torna dai morti torna da solo: il legame degli innamorati si spezza.
        if (_lovers.contains(risen)) _lovers.clear();
      }
    }
    if (_lovers.isNotEmpty) _loversTold = true;
    _choices.clear();
    _history.add(RoundRecord(round: _round, nightVictims: victims));
    _phase = _updateWinner() ? GamePhase.ended : GamePhase.day;

    return _lastDawn = DawnReport(
      round: _round,
      attacks: attacks,
      scoop: scoop,
      silenced: victims.contains(silenceTarget) ? null : silenceTarget,
      resurrected: resurrected,
      heartbroken: heartbroken,
      winner: _winner,
    );
  }

  /// Le mosse notturne arrivate finora (chi, cosa, su chi). Solo per chi
  /// tiene i conti a fine notte (il server, per missioni e traguardi).
  Map<Player, NightChoice> get nightChoices => Map.unmodifiable(_choices);

  /// I voti della piazza finora, in ordine di voto. `null` è un'astensione.
  Map<Player, Player?> get dayVotes => Map.unmodifiable(_dayVotes);

  /// Chi, tra i vivi, non ha ancora votato oggi.
  List<Player> get pendingDayVoters => [
    for (final player in _alive)
      if (!_dayVotes.containsKey(player)) player,
  ];

  /// Chiude il voto della piazza e condanna il più votato. Con un pareggio,
  /// o se si astengono tutti, non si condanna nessuno. Chi non ha votato
  /// conta come astenuto: l'autorità può chiudere allo scadere del tempo.
  /// Con la tregua del Pacifista non si conta niente: nessuna condanna.
  LynchReport closeDayVote() {
    _require(GamePhase.day);
    final mayor = this.mayor;
    final leaders = tallyVotes(_dayVotes, weights: {?mayor: 2}).leaders;
    _log.add(const CloseDayVoteCommand());
    return _lynch(leaders.length == 1 && !truceToday ? leaders.single : null);
  }

  /// Applica il verdetto della piazza; `condemned` nullo significa nessuna condanna.
  LynchReport lynch(Player? condemned) {
    _require(GamePhase.day);
    if (condemned != null && !isAlive(condemned)) {
      throw ArgumentError.value(condemned.name, 'condemned', 'non è più in gioco');
    }
    if (condemned != null && truceToday) throw StateError('oggi c\'è la tregua: non si condanna nessuno');
    _log.add(LynchCommand(condemned?.id));
    return _lynch(condemned);
  }

  LynchReport _lynch(Player? condemned) {
    final truce = truceToday;
    _dayVotes.clear();
    Role? role;
    Player? heartbroken;
    if (condemned != null) {
      role = setup.roleOf(condemned);
      heartbroken = _heartbreak([condemned]).firstOrNull;
      _alive.remove(condemned);
      _doused.remove(condemned);
      _facts.add(Fact(subject: condemned, team: role.team, role: role, visibility: Visibility.public));
      // Il crepacuore, sul posto: la sua carta resta coperta.
      if (heartbroken != null) {
        _alive.remove(heartbroken);
        _doused.remove(heartbroken);
      }
    }
    final record = _history.removeLast();
    _history.add(
      RoundRecord(
        round: record.round,
        nightVictims: record.nightVictims,
        lynched: condemned,
        dayVictims: [...record.dayVictims, ?heartbroken],
      ),
    );

    // Il Fesso voleva farsi linciare: ha vinto lui, e la partita va avanti.
    final personalWin = role == Role.fesso;
    if (personalWin) _personalWins.add(condemned!);
    // Il Cacciatore di taglie vivo la cui taglia sale sul patibolo incassa:
    // vince da solo, si scopre, e la partita finisce lì.
    Player? hunter;
    for (final entry in _bounties.entries) {
      if (condemned == null || entry.value != condemned || !isAlive(entry.key)) continue;
      if (_personalWins.contains(entry.key)) continue;
      hunter = entry.key;
      _personalWins.add(hunter);
      _facts.add(Fact(subject: hunter, team: Team.neutral, role: Role.cacciatore, visibility: Visibility.public));
    }
    final report = _lastLynch = LynchReport(
      round: _round,
      condemned: condemned,
      role: role,
      winner: hunter != null ? _bountyWin() : (_updateWinner() ? _winner : null),
      personalWin: personalWin,
      bountyHunter: hunter,
      truce: truce,
      heartbroken: heartbroken,
    );
    if (_winner != null) {
      _phase = GamePhase.ended;
    } else {
      _phase = GamePhase.night;
      _round++;
    }
    return report;
  }

  /// Il Sindaco si rivela alla piazza: il suo ruolo diventa pubblico e,
  /// per il voto di oggi, il suo voto vale due. Una volta per partita.
  void revealMayor(Player mayor) {
    _require(GamePhase.day);
    if (!isAlive(mayor) || setup.roleOf(mayor) != Role.sindaco) {
      throw ArgumentError.value(mayor.name, 'mayor', 'non è il Sindaco in gioco');
    }
    if (mayorRevealed) throw StateError('il Sindaco si è già rivelato');
    _mayorRound = _round;
    _facts.add(Fact(subject: mayor, team: Team.citizens, role: Role.sindaco, visibility: Visibility.public));
    _log.add(IntentCommand(RevealMayor(mayor.id)));
  }

  /// Il Pacifista ferma la piazza: il ruolo esatto di [target] diventa
  /// pubblico, la sua carta anche, e oggi non si vota. Una volta per partita.
  void pacify(Player pacifist, Player target) {
    _require(GamePhase.day);
    if (!isAlive(pacifist) || setup.roleOf(pacifist) != Role.pacifista) {
      throw ArgumentError.value(pacifist.name, 'pacifist', 'non è il Pacifista in gioco');
    }
    if (truceSpent) throw StateError('il Pacifista ha già chiesto la tregua');
    if (!isAlive(target) || target == pacifist) {
      throw ArgumentError.value(target.name, 'target', 'non si può svelare');
    }
    _truceRound = _round;
    _truceTarget = target;
    _dayVotes.clear();
    final role = setup.roleOf(target);
    _facts
      ..add(Fact(subject: pacifist, team: Team.citizens, role: Role.pacifista, visibility: Visibility.public))
      ..add(Fact(subject: target, team: role.team, role: role, visibility: Visibility.public));
    _log.add(IntentCommand(Pacify(pacifist.id, target.id)));
  }

  /// Qualcuno lascia la città a partita in corso (online: se n'è andato e
  /// non è tornato in tempo). Esce come un morto della notte: la sua carta
  /// resta coperta (la scopre solo il resoconto a fine partita), e si
  /// controlla subito se qualcuno ha vinto. Ai fini della vittoria conta
  /// per quello che era davvero, come ogni morto: un mafioso che se ne va
  /// toglie un voto alla famiglia, un cittadino uno alla città. Le mosse e
  /// i voti che lo riguardavano si annullano: chi li aveva fatti sceglie di
  /// nuovo. Torna la squadra che vince, se adesso vince qualcuno.
  Team? leaveTown(Player player) {
    if (_phase == GamePhase.ended || !isAlive(player)) return null;
    _log.add(LeaveTownCommand(player.id));
    _alive.remove(player);
    _doused.remove(player);
    // Chi se ne va non muore: il legame degli innamorati si spezza e basta.
    if (_lovers.contains(player)) _lovers.clear();
    // Se se ne va il Carceriere, il prigioniero esce e sceglie di nuovo.
    if (_choices[player] case (kind: NightTaskKind.jail, target: final prisoner?)) _choices.remove(prisoner);
    _choices.remove(player);
    _choices.removeWhere((_, choice) => choice.target == player);
    _dayVotes.remove(player);
    _dayVotes.removeWhere((_, target) => target == player);
    if (_updateWinner()) {
      _phase = GamePhase.ended;
      return _winner;
    }
    return null;
  }

  Player? _actorOf(NightTaskKind kind) => _actorIn(_choices, kind);

  static Player? _actorIn(Map<Player, NightChoice> choices, NightTaskKind kind) {
    for (final entry in choices.entries) {
      if (entry.value.kind == kind) return entry.key;
    }
    return null;
  }

  Player? _targetOf(NightTaskKind kind) => _choices[_actorOf(kind)]?.target;

  Player? _resolveMafiaVote(Map<Player, NightChoice> choices) {
    final votes = {
      for (final entry in choices.entries)
        if (entry.value.kind == NightTaskKind.kill) entry.key: entry.value.target,
    };
    if (votes.isEmpty) return null;

    // Ogni voto vale uno, anche quello del Padrino.
    final leaders = tallyVotes(votes).leaders;
    if (leaders.isEmpty) return null;
    if (leaders.length == 1) return leaders.single;
    if (settings.mafiaTieBreak == TieBreak.nobody) return null;
    return leaders[_draw(leaders.length)];
  }

  /// Un numero a caso in `[0, max)`, annotato perché la fotografia possa
  /// riportare il generatore allo stesso punto.
  int _draw(int max) {
    _draws.add(max);
    return _random.nextInt(max);
  }

  /// Chi ha vinto, se qualcuno ha vinto:
  /// - il Piromane o il Sicario, solo se resta l'ultimo vivo;
  /// - la mafia, quando non può più essere messa in minoranza (i neutrali
  ///   contano come non mafiosi);
  /// - la città, quando non c'è più mafia né un Piromane vivo.
  bool _updateWinner() {
    final won = _decideWinner();
    if (won) _payLoanSharks();
    return won;
  }

  /// La taglia linciata chiude la partita: vince il Cacciatore (e lo
  /// Strozzino vivo, come a ogni fine partita).
  Team _bountyWin() {
    _winner = Team.neutral;
    _payLoanSharks();
    return Team.neutral;
  }

  /// Lo Strozzino vivo a fine partita incassa, chiunque abbia vinto; e gli
  /// innamorati vivi tutti e due vincono insieme.
  void _payLoanSharks() {
    for (final player in _alive) {
      if (setup.roleOf(player) == Role.strozzino && !_personalWins.contains(player)) _personalWins.add(player);
    }
    if (_lovers.length == 2 && _lovers.every(isAlive)) {
      for (final lover in _lovers) {
        if (!_personalWins.contains(lover)) _personalWins.add(lover);
      }
    }
  }

  bool _decideWinner() {
    final arsonists = [
      for (final player in _alive)
        if (setup.roleOf(player).isHostileNeutral) player,
    ];
    // Il Piromane e il Sicario vincono solo se restano l'ultimo vivo: con un
    // altro la partita va avanti (lo cosparge e lo brucia, lo colpisce).
    // Contro un mafioso, però, vince la parità della famiglia.
    final soloWinners = [
      for (final player in arsonists)
        if (_alive.length == 1) player,
    ];
    if (soloWinners.isNotEmpty) {
      _winner = Team.neutral;
      for (final player in soloWinners) {
        if (!_personalWins.contains(player)) _personalWins.add(player);
      }
      return true;
    }
    final mafiosi = _alive.where((player) => _teamOf(player) == Team.mafia).length;
    final others = _alive.length - mafiosi;
    _winner = mafiosi == 0
        ? (arsonists.isEmpty ? Team.citizens : null)
        : mafiosi >= others
        ? Team.mafia
        : null;
    return _winner != null;
  }

  /// I posti al tavolo, per id. Il narratore umano non ha un posto: non gioca.
  late final Map<String, Player> _seats = {for (final player in setup.players) player.id: player};

  Player? _seat(String id) => _seats[id];

  /// Valida l'intenzione di un posto e, se sta nelle regole, la applica.
  /// Non lancia mai: una mossa non valida torna come [IntentRejected], e la
  /// partita resta com'era.
  ///
  /// Di notte un'indagine o uno scavo riuscito tornano in
  /// [IntentAccepted.finding], da mandare solo a chi ha agito.
  IntentResult apply(PlayerIntent intent) {
    if (_phase == GamePhase.ended) return const IntentRejected(IntentError.gameOver, 'la partita è finita');
    final actor = _seat(intent.seat);
    if (actor == null) return IntentRejected(IntentError.unknownSeat, 'il posto ${intent.seat} non gioca');
    if (!isAlive(actor)) return IntentRejected(IntentError.deadSeat, '${actor.id} non è più in gioco');
    return _phase == GamePhase.night ? _applyNight(actor, intent) : _applyDay(actor, intent);
  }

  IntentResult _applyNight(Player actor, PlayerIntent intent) {
    if (intent is DayVote || intent is RevealMayor || intent is Pacify) {
      return const IntentRejected(IntentError.wrongPhase, 'di notte la piazza non vota');
    }
    if (actor == jailedTonight) {
      return IntentRejected(IntentError.alreadyActed, '${actor.id} è in cella stanotte');
    }
    if (intent is Link) {
      if (nightChoiceLocked(actor)) {
        return IntentRejected(IntentError.alreadyActed, '${actor.id} ha già legato gli innamorati');
      }
      final task = taskFor(actor);
      final first = _seat(intent.target);
      final second = _seat(intent.second);
      if (task.kind != NightTaskKind.link) {
        return IntentRejected(IntentError.notYourAction, '${actor.id} non è Cupido la prima notte');
      }
      if (first == null || second == null || first == second || !task.targets.contains(first) || !task.targets.contains(second)) {
        return IntentRejected(IntentError.targetNotAllowed, '${actor.id} deve legare due persone diverse');
      }
      _retractNightChoice(actor);
      return IntentAccepted(submitNightChoice(actor, first, second: second));
    }
    // Si cambia idea fino alla fine della notte, tranne dopo una risposta.
    if (nightChoiceLocked(actor)) {
      return IntentRejected(IntentError.alreadyActed, '${actor.id} ha già fatto la sua mossa stanotte');
    }
    final task = taskFor(actor);
    final killing = task.kind == NightTaskKind.kill;
    // Cupido lega in due: serve un Link (o si passa).
    if (task.kind == NightTaskKind.link && intent is! Pass) {
      return IntentRejected(IntentError.notYourAction, 'stanotte ${actor.id} lega due persone: serve un Link');
    }
    // Un NightAction da chi vota l'agguato è il compito alternativo (il
    // Sarto che cuce), se ce l'ha.
    final alternative =
        intent is NightAction &&
        task.alternative != null &&
        (killing ||
            (task.alternativeTargets.any((player) => player.id == intent.target) &&
                !task.targets.any((player) => player.id == intent.target)));
    final targetSeat = switch (intent) {
      NightAction(:final target) when !killing || alternative => target,
      MafiaVote(:final target) when killing => target,
      Pass() => null,
      _ => '',
    };
    if (targetSeat == '') {
      return IntentRejected(
        IntentError.notYourAction,
        killing
            ? 'stanotte ${actor.id} vota l\'agguato: serve un MafiaVote'
            : 'stanotte ${actor.id} non vota l\'agguato: il suo compito è ${task.kind.name}',
      );
    }
    Player? target;
    if (targetSeat != null) {
      target = _seat(targetSeat);
      if (target == null || !(alternative ? task.alternativeTargets : task.targets).contains(target)) {
        return IntentRejected(IntentError.targetNotAllowed, '${actor.id} non può scegliere $targetSeat');
      }
    }
    _retractNightChoice(actor);
    return IntentAccepted(submitNightChoice(actor, target, alternative: alternative));
  }

  IntentResult _applyDay(Player actor, PlayerIntent intent) {
    Player? target;
    switch (intent) {
      case NightAction() || MafiaVote() || Link():
        return const IntentRejected(IntentError.wrongPhase, 'di giorno non si fanno mosse notturne');
      case DayVote() || RevealMayor() when truceToday:
        return const IntentRejected(IntentError.wrongPhase, 'oggi c\'è la tregua: non si vota');
      case DayVote(target: final seat):
        target = _seat(seat);
        if (target == null || !isAlive(target) || target == actor) {
          return IntentRejected(IntentError.targetNotAllowed, '${actor.id} non può votare $seat');
        }
      case Pass():
        break;
      case RevealMayor():
        if (setup.roleOf(actor) != Role.sindaco) {
          return IntentRejected(IntentError.notYourAction, '${actor.id} non è il Sindaco');
        }
        if (mayorRevealed) return IntentRejected(IntentError.alreadyActed, 'il Sindaco si è già rivelato');
        revealMayor(actor);
        return const IntentAccepted();
      case Pacify(target: final seat):
        if (setup.roleOf(actor) != Role.pacifista) {
          return IntentRejected(IntentError.notYourAction, '${actor.id} non è il Pacifista');
        }
        if (truceSpent) return const IntentRejected(IntentError.alreadyActed, 'la tregua è già stata chiesta');
        final revealed = _seat(seat);
        if (revealed == null || !isAlive(revealed) || revealed == actor) {
          return IntentRejected(IntentError.targetNotAllowed, '${actor.id} non può svelare $seat');
        }
        pacify(actor, revealed);
        return const IntentAccepted();
    }
    // Il voto si può cambiare: conta l'ultimo, nell'ordine dell'ultimo dato.
    _dayVotes.remove(actor);
    _dayVotes[actor] = target;
    _log.add(IntentCommand(intent));
    return const IntentAccepted();
  }

  /// Quello che lo schermo di tutti può mostrare adesso.
  PublicView publicView() => PublicView(
    round: _round,
    phase: _phase,
    winner: _winner,
    seats: setup.players,
    alive: alivePlayers,
    revealed: [
      for (final player in setup.players)
        if (knowledgeOf(null, player) case final known when !known.isEmpty) SeatKnowledge(player, known),
    ],
    history: history,
    lastDawn: _lastDawn,
    lastLynch: _lastLynch,
    nightPending: _phase == GamePhase.night ? pendingNightPlayers.length : 0,
    dayVotes: _phase == GamePhase.day
        ? [for (final entry in _dayVotes.entries) (voter: entry.key, target: entry.value)]
        : const [],
    finalRoles: _phase == GamePhase.ended ? setup.roles : const {},
    deck: deckOf(setup.roles.values),
    personalWins: personalWins,
    mayor: mayor,
    pacifist: pacifist,
    pacified: pacified,
    recap: recap,
  );

  GameRecap? _recap;

  /// Il resoconto della partita: solo quando è finita, mai prima.
  GameRecap? get recap => _phase == GamePhase.ended ? _recap ??= GameRecap.of(this) : null;

  /// Quello che il posto [seat], e solo lui, ha diritto di vedere adesso.
  /// Tutto passa dai fatti ([knowledgeOf]): un ruolo altrui compare solo se
  /// un fatto visibile a questo posto lo concede.
  PlayerView viewFor(String seat) {
    final viewer = _seat(seat);
    if (viewer == null) throw ArgumentError.value(seat, 'seat', 'non gioca');
    final role = setup.roleOf(viewer);
    final alive = isAlive(viewer);
    final family = alive && _phase == GamePhase.night && role.team == Team.mafia && viewer != jailedTonight;
    // Chi è in cella stanotte, per chi lo può sapere: il Carceriere, il
    // prigioniero, e la Famiglia se è uno dei loro. Mai chi l'ha chiuso.
    final jailed = jailedTonight;
    final cell =
        jailed != null &&
            alive &&
            (viewer == jailed || viewer == jailerTonight || (role.team == Team.mafia && _teamOf(jailed) == Team.mafia))
        ? jailed
        : null;
    return PlayerView(
      seat: viewer,
      alive: alive,
      role: role,
      team: role.team,
      teammates: [
        for (final player in setup.players)
          if (player != viewer &&
              _facts.any(
                (fact) => fact.subject == player && fact.visibility == Visibility.team && fact.visibleTo(viewer),
              ))
            player,
      ],
      known: [
        for (final player in setup.players)
          if (player != viewer)
            if (knowledgeOf(viewer, player) case final known when !known.isEmpty) SeatKnowledge(player, known),
      ],
      action: _optionFor(viewer),
      nightChoice: _phase == GamePhase.night ? _choices[viewer] : null,
      silenced: isSilenced(viewer),
      familyChat: canUseFamilyChat(viewer),
      doused: role == Role.piromane
          ? [
              for (final player in setup.players)
                if (_doused.contains(player)) player,
            ]
          : const [],
      bounty: _bounties[viewer],
      watches: [
        for (final watch in _watches)
          if (watch.watcher == viewer) watch.report,
      ],
      familyVotes: [
        if (family)
          for (final entry in _choices.entries)
            if (entry.value.kind == NightTaskKind.kill) (voter: entry.key, target: entry.value.target),
      ],
      cell: cell,
      busy: isBusy(viewer),
      lovers: loversFor(viewer),
      board: publicView(),
    );
  }

  ActionOption? _optionFor(Player viewer) {
    if (!isAlive(viewer)) return null;
    switch (_phase) {
      case GamePhase.night:
        // Fino all'alba la scelta resta aperta (con quella fatta in
        // [ActionOption.current]); dopo una risposta immediata, no.
        // In cella non si fa niente.
        if (nightChoiceLocked(viewer) || viewer == jailedTonight) return null;
        final task = taskFor(viewer);
        return ActionOption(
          type: task.kind == NightTaskKind.kill ? ActionType.mafiaVote : ActionType.nightAction,
          kind: task.kind,
          targets: task.targets,
          current: _choices[viewer]?.target,
          alternative: task.alternative,
          alternativeTargets: task.alternative == null || task.alternativeTargets == task.targets
              ? null
              : task.alternativeTargets,
        );
      case GamePhase.day:
        // La tregua: oggi non si vota.
        if (truceToday) return null;
        return ActionOption(
          type: ActionType.dayVote,
          targets: [
            for (final player in _alive)
              if (player != viewer) player,
          ],
          current: _dayVotes[viewer],
          canReveal: setup.roleOf(viewer) == Role.sindaco && !mayorRevealed && !truceToday,
          canPacify: setup.roleOf(viewer) == Role.pacifista && !truceSpent,
        );
      case GamePhase.ended:
        return null;
    }
  }

  void _require(GamePhase expected) {
    if (_phase != expected) {
      throw StateError('mossa non valida: la fase è ${_phase.name}, non ${expected.name}');
    }
  }
}

extension NightTaskTiming on NightTaskKind {
  /// La mossa dà la sua risposta subito, a chi la fa (l'indagine, lo
  /// scavo): per questo si conferma, e poi non si cambia.
  bool get immediate => this == NightTaskKind.investigate || this == NightTaskKind.dig;
}

extension NightTaskVisits on NightTaskKind {
  /// La mossa porta qualcuno alla porta del bersaglio: è quello che vede il
  /// Portinaio. Il compito di copertura, il fiammifero e lo scavo no.
  bool get visits => switch (this) {
    NightTaskKind.decoy || NightTaskKind.ignite || NightTaskKind.dig || NightTaskKind.resurrect => false,
    _ => true,
  };
}
