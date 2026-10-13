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
enum NightTaskKind { kill, protect, investigate, snipe, scoop, decoy }

class NightTask {
  final NightTaskKind kind;

  /// Chi può essere scelto. Passare è sempre permesso.
  final List<Player> targets;

  const NightTask(this.kind, this.targets);
}

/// La fazione di qualcuno, venuta a galla.
class Exposure {
  final Player subject;
  final Team team;

  const Exposure(this.subject, this.team);
}

/// Chi ha colpito, di notte.
enum AttackSource { family, sniper }

/// Com'è finito un agguato: a segno, o fermato in tempo dal Dottore.
enum AttackOutcome { killed, healed }

/// Un agguato della notte. All'alba va in scena così com'è andato.
class NightAttack {
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
  final Team? winner;

  const DawnReport({required this.round, this.attacks = const [], this.scoop, this.winner});

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
  Knowledge knowledgeOf(Player? viewer, Player subject) {
    Role? role;
    Team? team;
    for (final fact in _facts) {
      if (fact.subject != subject || !fact.visibleTo(viewer)) continue;
      team = fact.team;
      role ??= fact.role;
    }
    return Knowledge(role: role, team: team);
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
    return switch (setup.roleOf(actor)) {
      // La famiglia può colpire chiunque, anche uno dei suoi: un morto in
      // casa, a volte, è il bluff migliore.
      Role.mafioso => NightTask(NightTaskKind.kill, others),
      Role.medico => NightTask(NightTaskKind.protect, [
          for (final player in _alive)
            if (player != _lastProtected) player,
        ]),
      Role.detective => NightTask(NightTaskKind.investigate, others),
      Role.cecchino => NightTask(_sniperSpent ? NightTaskKind.decoy : NightTaskKind.snipe, others),
      Role.giornalista => NightTask(_scoopSpent ? NightTaskKind.decoy : NightTaskKind.scoop, others),
      Role.cittadino => NightTask(NightTaskKind.decoy, others),
    };
  }

  /// Registra la mossa notturna di [actor]; `target` nullo significa "passo".
  /// Solo l'indagine dà una risposta immediata, e la dà solo al detective.
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
      final team = _teamOf(target);
      _facts.add(Fact(
        subject: target,
        team: team,
        visibility: Visibility.acquired,
        audience: {actor},
      ));
      return Exposure(target, team);
    }
    return null;
  }

  /// Chiude la notte: tutte le mosse si risolvono insieme, quindi chi muore
  /// stanotte ha comunque fatto in tempo ad agire.
  DawnReport resolveNight() {
    if (!nightComplete) throw StateError('la notte non è finita: manca qualcuno');

    final mafiaTarget = _resolveMafiaVote();
    final protected = _targetOf(NightTaskKind.protect);
    final sniped = _targetOf(NightTaskKind.snipe);
    final scoopTarget = _targetOf(NightTaskKind.scoop);
    final journalist = _actorOf(NightTaskKind.scoop);

    final attacks = [
      for (final player in _alive)
        if (player == mafiaTarget || player == sniped)
          NightAttack(
            player,
            player == mafiaTarget ? AttackSource.family : AttackSource.sniper,
            player == protected ? AttackOutcome.healed : AttackOutcome.killed,
          ),
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
    _alive.removeWhere(victims.contains);
    _choices.clear();
    _history.add(RoundRecord(round: _round, nightVictims: victims));
    _phase = _updateWinner() ? GamePhase.ended : GamePhase.day;

    return DawnReport(round: _round, attacks: attacks, scoop: scoop, winner: _winner);
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

    final boss = _alive.firstWhere((player) => _teamOf(player) == Team.mafia);
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
