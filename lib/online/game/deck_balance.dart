import 'dart:math';

import '../../rules/game_engine.dart';
import '../../rules/game_setup.dart';
import '../../rules/intent.dart';
import '../../rules/player.dart';
import '../../rules/role.dart';
import '../../rules/role_assignment.dart';
import 'bot_brain.dart';

/// I ruoli entrati con il primo gruppo di novità (`docs/ruoli.md`, batch 1):
/// la simulazione li confronta con il mazzo di prima.
const newRoles = {
  Role.prostituta,
  Role.carceriere,
  Role.pacifista,
  Role.cupido,
  Role.presidente,
  Role.capoSetta,
  Role.artigliere,
  Role.tiratoreScelto,
};

/// Le vittorie di tante partite giocate dai bot, per un tavolo di una certa
/// misura: per squadra e, per ruolo, quante volte chi l'aveva ha vinto.
class BalanceReport {
  final int players;
  final int games;

  /// Chi ha chiuso la partita: `citizens`, `mafia`, `neutral` (un neutrale
  /// da solo), `none` (troppo lunga, non finita).
  final Map<String, int> endings;
  final Map<Role, int> dealt;
  final Map<Role, int> won;

  BalanceReport(this.players, this.games, this.endings, this.dealt, this.won);

  double share(String ending) => games == 0 ? 0 : (endings[ending] ?? 0) / games;

  double roleWinRate(Role role) => (dealt[role] ?? 0) == 0 ? 0 : (won[role] ?? 0) / dealt[role]!;
}

/// Gioca [games] partite online da [players] posti, tutti bot ([BotBrain],
/// gli stessi del server), con il mazzo automatico ([rolesForPlayerCount])
/// senza i ruoli in [exclude]. L'Artigliere spara un giorno su due, dal
/// secondo: col fiuto su qualcuno della Famiglia, se no a caso. Il
/// Pacifista chiede la tregua una volta, in
/// un giorno a caso dal secondo, su un nome a caso. Il Tiratore scelto, di
/// notte, con il fiuto ([hunch]) mira a uno della Famiglia, sennò come il
/// bot; di giorno spara una volta su due.
///
/// I bot da soli votano quasi a caso, mentre la Famiglia si conosce: così
/// la Famiglia stravince qualunque mazzo. [hunch] simula il fiuto di un
/// tavolo vero: al voto, chi non è della Famiglia con questa probabilità
/// punta qualcuno della Famiglia ancora vivo (senza sapere chi sia: lo
/// sceglie il simulatore), altrimenti vota come il bot.
///
/// [deal] cambia il mazzo (di base quello automatico, per esempio quello
/// della classificata); [onGame] riceve ogni partita finita, col suo mazzo.
BalanceReport simulateDecks(
  int players,
  int games, {
  required int seed,
  Set<Role> exclude = const {},
  double hunch = defaultHunch,
  List<Role> Function(Random random)? deal,
  void Function(List<Role> deck, GameEngine engine)? onGame,
}) {
  final random = Random(seed);
  final brain = BotBrain(random);
  final endings = <String, int>{};
  final dealt = <Role, int>{};
  final won = <Role, int>{};
  final lobby = [for (var i = 1; i <= players; i++) Player(id: 's$i', name: 's$i')];
  for (var game = 0; game < games; game++) {
    final deck =
        (deal?.call(random) ?? rolesForPlayerCount(players, random: random, mode: PlayMode.online, exclude: exclude))
          ..shuffle(random);
    final engine = GameEngine(GameSetup.fromRoles(Map.fromIterables(lobby, deck)), seed: random.nextInt(seedRange));
    for (var turn = 0; turn < 40 && engine.phase != GamePhase.ended; turn++) {
      if (engine.phase == GamePhase.night) {
        for (final player in [...engine.alivePlayers]..shuffle(random)) {
          if (!engine.pendingNightPlayers.contains(player)) continue;
          final view = engine.viewFor(player.id);
          if (view.action?.kind == NightTaskKind.aim && random.nextDouble() < hunch) {
            final family = [
              for (final other in view.action!.targets)
                if (engine.setup.roleOf(other).team == Team.mafia) other,
            ];
            if (family.isNotEmpty &&
                engine.apply(NightAction(player.id, family[random.nextInt(family.length)].id)).accepted) {
              continue;
            }
          }
          final intent = brain.decide(view) ?? Pass(player.id);
          if (!engine.apply(intent).accepted) engine.apply(Pass(player.id));
        }
        for (final player in engine.pendingNightPlayers) {
          engine.apply(Pass(player.id));
        }
        engine.resolveNight();
      } else {
        for (final player in engine.alivePlayers) {
          final option = engine.viewFor(player.id).action;
          if (option != null && option.canPacify && engine.round > 1 && random.nextInt(3) == 0) {
            final others = option.targets;
            if (others.isNotEmpty) engine.apply(Pacify(player.id, others[random.nextInt(others.length)].id));
          }
          if (option != null && option.canShoot && random.nextBool()) engine.apply(Shoot(player.id));
          if (engine.phase != GamePhase.day) break;
        }
        for (final player in engine.alivePlayers) {
          final aim = engine.fireTargets(player);
          if (aim.isEmpty || !random.nextBool()) continue;
          final family = [
            for (final other in aim)
              if (engine.setup.roleOf(other).team == Team.mafia) other,
          ];
          final hit = family.isNotEmpty && random.nextDouble() < hunch
              ? family[random.nextInt(family.length)]
              : aim[random.nextInt(aim.length)];
          engine.apply(Fire(player.id, hit.id));
          break;
        }
        if (engine.phase != GamePhase.day) continue;
        for (final player in [...engine.alivePlayers]..shuffle(random)) {
          final view = engine.viewFor(player.id);
          final family = [
            for (final other in view.action?.targets ?? const <Player>[])
              if (engine.setup.roleOf(other).team == Team.mafia) other,
          ];
          if (view.team != Team.mafia && family.isNotEmpty && random.nextDouble() < hunch) {
            engine.apply(DayVote(player.id, family[random.nextInt(family.length)].id));
            continue;
          }
          final intent = brain.decide(view);
          if (intent != null) engine.apply(intent);
        }
        engine.closeDayVote();
      }
    }
    final ending = engine.phase != GamePhase.ended ? 'none' : engine.winner!.name;
    endings[ending] = (endings[ending] ?? 0) + 1;
    onGame?.call(deck, engine);
    for (final player in lobby) {
      final role = engine.setup.roleOf(player);
      dealt[role] = (dealt[role] ?? 0) + 1;
      if (engine.hasWon(player)) won[role] = (won[role] ?? 0) + 1;
    }
  }
  return BalanceReport(players, games, endings, dealt, won);
}

/// Il fiuto di base della simulazione: con questo il tavolo più semplice
/// (un Picciotto, il Commissario, gli Onesti) sta intorno alla parità.
const defaultHunch = 0.3;

/// Le partite della classificata: sempre in 12, col mazzo della classificata
/// ([rankedRoles]), e senza i ruoli in [exclude].
BalanceReport simulateRanked(
  int games, {
  required int seed,
  Set<Role> exclude = const {},
  double hunch = defaultHunch,
  void Function(List<Role> deck, GameEngine engine)? onGame,
}) => simulateDecks(
  rankedPlayers,
  games,
  seed: seed,
  hunch: hunch,
  deal: (random) => rankedRoles(random: random, exclude: exclude),
  onGame: onGame,
);
