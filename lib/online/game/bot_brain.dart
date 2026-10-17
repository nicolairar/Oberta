import 'dart:math';

import '../../rules/game_engine.dart';
import '../../rules/intent.dart';
import '../../rules/player.dart';
import '../../rules/player_view.dart';
import '../../rules/role.dart';
import '../handle_rules.dart';

/// I bot si accendono nelle build di prova. Una build per l'App Store li
/// spegne con `--dart-define=OBERTA_BOTS=false`.
const botsEnabled = bool.fromEnvironment('OBERTA_BOTS', defaultValue: true);

/// I nomi dei bot, nell'ordine in cui si siedono: `bot.alfa`, `bot.bravo`...
/// Hanno la forma dei nomi unici, ma nessun umano li può prendere.
const _nato = [
  'alfa', 'bravo', 'charlie', 'delta', 'echo', 'foxtrot', 'golf', 'hotel',
  'india', 'juliett', 'kilo', 'lima', 'mike', 'november', 'oscar',
];

const maxBots = 15;

String botName(int index) => HandleRules.botHandle(_nato[index % _nato.length]);

/// Un bot di prova: guarda solo la sua [PlayerView], come un telefono vero,
/// e sceglie una mossa permessa. Le scelte sono a caso, con qualche regola
/// di buon senso:
/// - la famiglia non colpisce uno dei suoi se c'è un altro bersaglio, e di
///   giorno non vota un complice;
/// - chi sa che qualcuno è della famiglia (un'indagine, uno scoop, una
///   carta girata) lo vota;
/// - il Medico ogni tanto protegge sé stesso.
class BotBrain {
  final Random random;

  const BotBrain(this.random);

  /// La mossa di adesso, o null se il bot non ha niente da fare.
  PlayerIntent? decide(PlayerView view) {
    final option = view.action;
    if (option == null) return null;
    final seat = view.seat.id;
    final mafia = view.team == Team.mafia;
    final friends = {...view.teammates};
    final known = {for (final k in view.known) k.seat: k.knowledge};
    bool knownMafia(Player p) => known[p]?.team == Team.mafia;

    List<Player> preferred(List<Player> all) {
      final avoid = mafia ? [for (final p in all) if (!friends.contains(p)) p] : all;
      return avoid.isEmpty ? all : avoid;
    }

    switch (option.type) {
      case ActionType.mafiaVote:
        final targets = preferred(option.targets);
        if (targets.isEmpty) return Pass(seat);
        // Se un complice ha già votato, la famiglia lo segue: niente pareggi.
        for (final vote in view.familyVotes) {
          final target = vote.target;
          if (target != null && targets.contains(target)) return MafiaVote(seat, target.id);
        }
        return MafiaVote(seat, _pick(targets).id);
      case ActionType.nightAction:
        if (option.targets.isEmpty) return Pass(seat);
        final kind = option.kind;
        if (kind == NightTaskKind.protect && option.targets.contains(view.seat) && random.nextInt(3) == 0) {
          return NightAction(seat, seat);
        }
        if (kind == NightTaskKind.investigate || kind == NightTaskKind.scoop) {
          final unknown = [for (final p in option.targets) if (known[p]?.team == null) p];
          if (unknown.isNotEmpty) return NightAction(seat, _pick(unknown).id);
        }
        if (kind == NightTaskKind.snipe) {
          final suspects = [for (final p in option.targets) if (knownMafia(p)) p];
          if (suspects.isNotEmpty) return NightAction(seat, _pick(suspects).id);
          // Il Cecchino senza indizi aspetta: un colpo solo, non va sprecato.
          return Pass(seat);
        }
        if (kind == NightTaskKind.silence || kind == NightTaskKind.guard) {
          return NightAction(seat, _pick(preferred(option.targets)).id);
        }
        return NightAction(seat, _pick(option.targets).id);
      case ActionType.dayVote:
        final targets = option.targets;
        if (targets.isEmpty) return Pass(seat);
        if (!mafia) {
          final suspects = [for (final p in targets) if (knownMafia(p)) p];
          if (suspects.isNotEmpty) return DayVote(seat, _pick(suspects).id);
        }
        // Chi ha già un voto in piazza attira altri voti: così si decide.
        final votes = <Player, int>{};
        for (final vote in view.board.dayVotes) {
          final target = vote.target;
          if (target != null && targets.contains(target)) votes[target] = (votes[target] ?? 0) + 1;
        }
        final pool = preferred(targets);
        final leading = [for (final p in pool) if ((votes[p] ?? 0) > 0) p];
        if (leading.isNotEmpty && random.nextBool()) return DayVote(seat, _pick(leading).id);
        return DayVote(seat, _pick(pool).id);
    }
  }

  T _pick<T>(List<T> options) => options[random.nextInt(options.length)];
}
