import 'dart:math';

import 'game_settings.dart';
import 'game_setup.dart';
import 'knowledge.dart';
import 'player.dart';
import 'role.dart';
import 'vote.dart';

enum GamePhase { night, day, ended }

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

typedef _Choice = ({NightTaskKind kind, Player? target});

/// Il motore di una partita: riceve intenzioni ("di notte scelgo Marco",
/// "la piazza condanna Sara") e decide cosa succede. Niente rete, niente UI.
class GameEngine {
  final GameSetup setup;
  final GameSettings settings;
  final Random _random;

  final List<Player> _alive;
  final List<Fact> _facts = [];
  final Map<Player, _Choice> _choices = {};
  final Map<Player, int> _suspicion = {};
  final List<RoundRecord> _history = [];

  GamePhase _phase = GamePhase.night;
  int _round = 1;
  bool _sniperSpent = false;
  bool _scoopSpent = false;
  Player? _lastProtected;
  Player? _lastSilenced;

  /// I Reduci che hanno già incassato il loro colpo: il prossimo va a segno.
  final Set<Player> _scarred = {};
  Team? _winner;

  GameEngine(this.setup, {this.settings = const GameSettings(), Random? random})
      : _random = random ?? Random(),
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

    return DawnReport(
      round: _round,
      attacks: attacks,
      scoop: scoop,
      silenced: victims.contains(silenceTarget) ? null : silenceTarget,
      winner: _winner,
    );
  }

  /// Applica il verdetto della piazza; `condemned` nullo significa nessuna condanna.
  LynchReport lynch(Player? condemned) {
    _require(GamePhase.day);
    if (condemned != null && !isAlive(condemned)) {
      throw ArgumentError.value(condemned.name, 'condemned', 'non è più in gioco');
    }

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

    final report = LynchReport(
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
    return leaders[_random.nextInt(leaders.length)];
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

  void _require(GamePhase expected) {
    if (_phase != expected) {
      throw StateError('mossa non valida: la fase è ${_phase.name}, non ${expected.name}');
    }
  }
}
