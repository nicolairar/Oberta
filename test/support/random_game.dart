import 'dart:math';

import 'package:oberta/rules/game_engine.dart';
import 'package:oberta/rules/game_settings.dart';
import 'package:oberta/rules/game_setup.dart';
import 'package:oberta/rules/intent.dart';
import 'package:oberta/rules/player.dart';
import 'package:oberta/rules/player_view.dart';
import 'package:oberta/rules/role.dart';
import 'package:oberta/rules/role_assignment.dart';

/// Un tavolo a caso da 3 a 12 posti (`s1`, `s2`, ...), un mazzo a caso (una
/// volta su due online, con i ruoli che esistono solo lì) e regole di
/// spareggio a caso, con un seme.
GameEngine randomEngine(Random random) {
  final count = minRolePlayers + random.nextInt(maxRolePlayers - minRolePlayers + 1);
  final lobby = [for (var i = 1; i <= count; i++) Player(id: 's$i', name: 's$i')];
  final mode = random.nextBool() ? PlayMode.online : PlayMode.sharedPhone;
  return GameEngine(
    GameSetup.deal(lobby: lobby, random: random, mode: mode),
    settings: GameSettings(mafiaTieBreak: TieBreak.values[random.nextInt(TieBreak.values.length)]),
    seed: random.nextInt(1 << 32),
  );
}

T _pick<T>(Random random, List<T> options) => options[random.nextInt(options.length)];

/// Un comando valido a caso per lo stato attuale, scelto come lo sceglierebbe
/// un client: guardando solo la vista del posto che agisce. `null` a partita
/// finita.
GameCommand? randomCommand(GameEngine engine, Random random) {
  switch (engine.phase) {
    case GamePhase.ended:
      return null;
    case GamePhase.night:
      final pending = engine.pendingNightPlayers;
      if (pending.isEmpty) return const ResolveNightCommand();
      final seat = _pick(random, pending).id;
      final option = engine.viewFor(seat).action;
      // In cella non si sceglie: il prigioniero ha già passato.
      if (option == null) return const ResolveNightCommand();
      // Ogni tanto il compito alternativo: il Sarto che cuce, il Piromane che accende.
      final alternatives = option.alternativeTargets ?? option.targets;
      if (option.alternative != null && alternatives.isNotEmpty && random.nextInt(3) == 0) {
        return IntentCommand(NightAction(seat, _pick(random, alternatives).id));
      }
      if (option.targets.isEmpty || random.nextInt(5) == 0) return IntentCommand(Pass(seat));
      // Cupido lega due persone diverse.
      if (option.kind == NightTaskKind.link) {
        if (option.targets.length < 2) return IntentCommand(Pass(seat));
        final first = _pick(random, option.targets);
        final second = _pick(random, [for (final p in option.targets) if (p != first) p]);
        return IntentCommand(Link(seat, first.id, second.id));
      }
      final target = _pick(random, option.targets).id;
      return IntentCommand(option.type == ActionType.mafiaVote ? MafiaVote(seat, target) : NightAction(seat, target));
    case GamePhase.day:
      final alive = engine.alivePlayers;
      // Ogni tanto il narratore condanna di persona, come su un telefono solo.
      if (random.nextInt(12) == 0) {
        // Il Presidente non si lincia.
        final hangable = [for (final p in alive) if (engine.setup.roleOf(p) != Role.presidente) p];
        return LynchCommand(random.nextBool() || engine.truceToday || hangable.isEmpty ? null : _pick(random, hangable).id);
      }
      if (engine.pendingDayVoters.isEmpty || random.nextInt(alive.length * 2) == 0) {
        return const CloseDayVoteCommand();
      }
      final seat = _pick(random, alive).id;
      final option = engine.viewFor(seat).action;
      // La tregua: oggi non si vota.
      if (option == null) return const CloseDayVoteCommand();
      if (option.canReveal && random.nextInt(3) == 0) return IntentCommand(RevealMayor(seat));
      if (option.canPacify && random.nextInt(4) == 0) {
        return IntentCommand(Pacify(seat, _pick(random, option.targets).id));
      }
      if (random.nextInt(6) == 0) return IntentCommand(Pass(seat));
      return IntentCommand(DayVote(seat, _pick(random, option.targets).id));
  }
}
