import 'dart:math';

import 'game_settings.dart';
import 'game_setup.dart';
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
enum NightTaskKind { kill, silence, protect, guard, investigate, dig, snipe, scoop, decoy }

class NightTask {
  final NightTaskKind kind;

  /// Chi può essere scelto. Passare è sempre permesso.
  final List<Player> targets;

  const NightTask(this.kind, this.targets);
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
enum AttackSource { family, sniper }

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
  final Team? winner;

  const DawnReport({
    required this.round,
    this.attacks = const [],
    this.scoop,
    this.silenced,
    this.winner,
  });

  /// Morti della notte, in ordine di posto. I loro ruoli restano segreti.
  List<Player> get victims => [
        for (final attack in attacks)
          if (attack.isFatal) attack.target,
      ];
}

class LynchReport {
  final int round;

  /// `null` se la piazza non ha condannato nessuno.
  final Player? condemned;

  /// Il ruolo del condannato, che il linciaggio rende pubblico.
  final Role? role;
  final Team? winner;

  const LynchReport({required this.round, this.condemned, this.role, this.winner});
}

class RoundRecord {
  final int round;
  final List<Player> nightVictims;
  final Player? lynched;

  const RoundRecord({required this.round, required this.nightVictims, this.lynched});
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
  DawnReport? _lastDawn;
  LynchReport? _lastLynch;

  /// I Reduci che hanno già incassato il loro colpo: il prossimo va a segno.
  final Set<Player> _scarred = {};
  Team? _winner;

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
      _facts.add(Fact(
        subject: player,
        team: _teamOf(player),
        role: setup.roleOf(player),
        visibility: isMafia ? Visibility.team : Visibility.private,
        audience: isMafia ? mafiosi : {player},
      ));
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
    _lastDawn = snapshot.lastDawn;
    _lastLynch = snapshot.lastLynch;
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
      scarred: Set.unmodifiable(_scarred),
      lastDawn: _lastDawn,
      lastLynch: _lastLynch,
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
  Team? get winner => _winner;
  List<Player> get alivePlayers => List.unmodifiable(_alive);
  List<RoundRecord> get history => List.unmodifiable(_history);

  /// Quante volte ciascuno è stato indicato nei compiti di copertura.
  Map<Player, int> get suspicion => Map.unmodifiable(_suspicion);

  bool isAlive(Player player) => _alive.contains(player);

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
    final familyCanKill = _alive.any((player) => player != actor && setup.roleOf(player).isKiller);
    return switch (setup.roleOf(actor)) {
      // La famiglia può colpire chiunque, anche uno dei suoi: un morto in
      // casa, a volte, è il bluff migliore.
      Role.mafioso || Role.padrino => NightTask(NightTaskKind.kill, others),
      // Finché in famiglia c'è chi spara, il Sarto cuce. Se resta solo lui,
      // posa l'ago e prende la pistola.
      Role.sarto => familyCanKill
          ? NightTask(NightTaskKind.silence, [
              for (final player in others)
                if (player != _lastSilenced) player,
            ])
          : NightTask(NightTaskKind.kill, others),
      Role.medico => NightTask(NightTaskKind.protect, [
          for (final player in _alive)
            if (player != _lastProtected) player,
        ]),
      Role.guardaspalle => NightTask(NightTaskKind.guard, others),
      Role.detective => NightTask(NightTaskKind.investigate, others),
      // Senza morti da riesumare il Becchino fa finta, come gli altri.
      Role.becchino =>
        graves.isEmpty ? NightTask(NightTaskKind.decoy, others) : NightTask(NightTaskKind.dig, graves),
      Role.cecchino => NightTask(_sniperSpent ? NightTaskKind.decoy : NightTaskKind.snipe, others),
      Role.giornalista => NightTask(_scoopSpent ? NightTaskKind.decoy : NightTaskKind.scoop, others),
      Role.cittadino || Role.reduce || Role.pregiudicato => NightTask(NightTaskKind.decoy, others),
    };
  }

  /// Registra la mossa notturna di [actor]; `target` nullo significa "passo".
  /// Solo l'indagine e lo scavo danno una risposta immediata, e la danno
  /// solo a chi ha fatto la mossa.
  Exposure? submitNightChoice(Player actor, Player? target) {
    final task = taskFor(actor);
    if (_choices.containsKey(actor)) throw StateError('${actor.name} ha già scelto');
    if (target != null && !task.targets.contains(target)) {
      throw ArgumentError.value(target.name, 'target', 'non può essere scelto da ${actor.name}');
    }
    _choices[actor] = (kind: task.kind, target: target);
    _log.add(
      IntentCommand(switch ((task.kind, target)) {
        (_, null) => Pass(actor.id),
        (NightTaskKind.kill, final target?) => MafiaVote(actor.id, target.id),
        (_, final target?) => NightAction(actor.id, target.id),
      }),
    );
    if (target == null) return null;

    if (task.kind == NightTaskKind.decoy) {
      _suspicion[target] = (_suspicion[target] ?? 0) + 1;
    }
    if (task.kind == NightTaskKind.investigate) {
      // Il Commissario legge le carte, e le carte a volte mentono.
      final team = setup.roleOf(target).apparentTeam;
      _facts.add(Fact(
        subject: target,
        team: team,
        visibility: Visibility.acquired,
        audience: {actor},
        apparent: true,
      ));
      return Exposure(target, team);
    }
    if (task.kind == NightTaskKind.dig) {
      final role = setup.roleOf(target);
      _facts.add(Fact(
        subject: target,
        team: role.team,
        role: role,
        visibility: Visibility.acquired,
        audience: {actor},
      ));
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

    final protected = _targetOf(NightTaskKind.protect);
    final guard = _actorOf(NightTaskKind.guard);
    final guarded = _targetOf(NightTaskKind.guard);
    final sniped = _targetOf(NightTaskKind.snipe);
    final silenceTarget = _targetOf(NightTaskKind.silence);
    final scoopTarget = _targetOf(NightTaskKind.scoop);
    final journalist = _actorOf(NightTaskKind.scoop);

    // Chi viene colpito davvero, e da chi. La famiglia passa per prima.
    final struck = <Player, AttackSource>{};
    void aim(Player? target, AttackSource source) {
      if (target == null) return;
      final shielded = target == guarded && target != protected;
      struck.putIfAbsent(shielded ? guard! : target, () => source);
    }

    aim(_resolveMafiaVote(), AttackSource.family);
    aim(sniped, AttackSource.sniper);

    AttackOutcome land(Player target) {
      if (target == protected) return AttackOutcome.healed;
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

    if (sniped != null) _sniperSpent = true;
    Exposure? scoop;
    if (scoopTarget != null) {
      _scoopSpent = true;
      if (!victims.contains(journalist)) {
        scoop = Exposure(scoopTarget, _teamOf(scoopTarget));
        _facts.add(Fact(subject: scoopTarget, team: scoop.team, visibility: Visibility.public));
      }
    }

    _lastProtected = protected;
    _lastSilenced = silenceTarget;
    _alive.removeWhere(victims.contains);
    _choices.clear();
    _history.add(RoundRecord(round: _round, nightVictims: victims));
    _phase = _updateWinner() ? GamePhase.ended : GamePhase.day;

    return _lastDawn = DawnReport(
      round: _round,
      attacks: attacks,
      scoop: scoop,
      silenced: victims.contains(silenceTarget) ? null : silenceTarget,
      winner: _winner,
    );
  }

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
  LynchReport closeDayVote() {
    _require(GamePhase.day);
    final leaders = tallyVotes(_dayVotes).leaders;
    _log.add(const CloseDayVoteCommand());
    return _lynch(leaders.length == 1 ? leaders.single : null);
  }

  /// Applica il verdetto della piazza; `condemned` nullo significa nessuna condanna.
  LynchReport lynch(Player? condemned) {
    _require(GamePhase.day);
    if (condemned != null && !isAlive(condemned)) {
      throw ArgumentError.value(condemned.name, 'condemned', 'non è più in gioco');
    }
    _log.add(LynchCommand(condemned?.id));
    return _lynch(condemned);
  }

  LynchReport _lynch(Player? condemned) {
    _dayVotes.clear();
    Role? role;
    if (condemned != null) {
      role = setup.roleOf(condemned);
      _alive.remove(condemned);
      _facts.add(Fact(
        subject: condemned,
        team: role.team,
        role: role,
        visibility: Visibility.public,
      ));
    }
    final record = _history.removeLast();
    _history.add(RoundRecord(
      round: record.round,
      nightVictims: record.nightVictims,
      lynched: condemned,
    ));

    final report = _lastLynch = LynchReport(
      round: _round,
      condemned: condemned,
      role: role,
      winner: _updateWinner() ? _winner : null,
    );
    if (_winner != null) {
      _phase = GamePhase.ended;
    } else {
      _phase = GamePhase.night;
      _round++;
    }
    return report;
  }

  /// Qualcuno lascia la città a partita in corso (online: se n'è andato e
  /// non è tornato in tempo). Esce come un morto, la sua carta si scopre per
  /// tutti, e si controlla subito se qualcuno ha vinto. Le mosse e i voti
  /// che lo riguardavano si annullano: chi li aveva fatti sceglie di nuovo.
  /// Torna la squadra che vince, se adesso vince qualcuno.
  Team? leaveTown(Player player) {
    if (_phase == GamePhase.ended || !isAlive(player)) return null;
    _log.add(LeaveTownCommand(player.id));
    final role = setup.roleOf(player);
    _alive.remove(player);
    _facts.add(Fact(subject: player, team: role.team, role: role, visibility: Visibility.public));
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

  Player? _actorOf(NightTaskKind kind) {
    for (final entry in _choices.entries) {
      if (entry.value.kind == kind) return entry.key;
    }
    return null;
  }

  Player? _targetOf(NightTaskKind kind) => _choices[_actorOf(kind)]?.target;

  Player? _resolveMafiaVote() {
    final votes = {
      for (final entry in _choices.entries)
        if (entry.value.kind == NightTaskKind.kill) entry.key: entry.value.target,
    };
    if (votes.isEmpty) return null;

    // Il capo è il Padrino; senza di lui, il primo al tavolo tra chi vota.
    final voters = _alive.where(votes.containsKey);
    final boss = voters.firstWhere(
      (player) => setup.roleOf(player) == Role.padrino,
      orElse: () => voters.first,
    );
    final weights = settings.mafiaTieBreak == TieBreak.boss ? {boss: 2} : const <Player, int>{};
    final leaders = tallyVotes(votes, weights: weights).leaders;
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

  /// La mafia vince quando non può più essere messa in minoranza.
  bool _updateWinner() {
    final mafiosi = _alive.where((player) => _teamOf(player) == Team.mafia).length;
    final others = _alive.length - mafiosi;
    _winner = mafiosi == 0
        ? Team.citizens
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
    if (intent is DayVote) return const IntentRejected(IntentError.wrongPhase, 'di notte la piazza non vota');
    if (_choices.containsKey(actor)) {
      return IntentRejected(IntentError.alreadyActed, '${actor.id} ha già fatto la sua mossa stanotte');
    }
    final task = taskFor(actor);
    final killing = task.kind == NightTaskKind.kill;
    final targetSeat = switch (intent) {
      NightAction(:final target) when !killing => target,
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
      if (target == null || !task.targets.contains(target)) {
        return IntentRejected(IntentError.targetNotAllowed, '${actor.id} non può scegliere $targetSeat');
      }
    }
    return IntentAccepted(submitNightChoice(actor, target));
  }

  IntentResult _applyDay(Player actor, PlayerIntent intent) {
    Player? target;
    switch (intent) {
      case NightAction() || MafiaVote():
        return const IntentRejected(IntentError.wrongPhase, 'di giorno non si fanno mosse notturne');
      case DayVote(target: final seat):
        target = _seat(seat);
        if (target == null || !isAlive(target) || target == actor) {
          return IntentRejected(IntentError.targetNotAllowed, '${actor.id} non può votare $seat');
        }
      case Pass():
        break;
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
      );

  /// Quello che il posto [seat], e solo lui, ha diritto di vedere adesso.
  /// Tutto passa dai fatti ([knowledgeOf]): un ruolo altrui compare solo se
  /// un fatto visibile a questo posto lo concede.
  PlayerView viewFor(String seat) {
    final viewer = _seat(seat);
    if (viewer == null) throw ArgumentError.value(seat, 'seat', 'non gioca');
    final role = setup.roleOf(viewer);
    final alive = isAlive(viewer);
    final family = alive && _phase == GamePhase.night && role.team == Team.mafia;
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
      familyVotes: [
        if (family)
          for (final entry in _choices.entries)
            if (entry.value.kind == NightTaskKind.kill) (voter: entry.key, target: entry.value.target),
      ],
      board: publicView(),
    );
  }

  ActionOption? _optionFor(Player viewer) {
    if (!isAlive(viewer)) return null;
    switch (_phase) {
      case GamePhase.night:
        if (_choices.containsKey(viewer)) return null;
        final task = taskFor(viewer);
        return ActionOption(
          type: task.kind == NightTaskKind.kill ? ActionType.mafiaVote : ActionType.nightAction,
          kind: task.kind,
          targets: task.targets,
        );
      case GamePhase.day:
        return ActionOption(
          type: ActionType.dayVote,
          targets: [
            for (final player in _alive)
              if (player != viewer) player,
          ],
          current: _dayVotes[viewer],
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
