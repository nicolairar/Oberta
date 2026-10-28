import 'dart:convert';

import 'game_engine.dart';
import 'rules_json.dart';

/// Quello che un posto chiede di fare. È tutto ciò che un client manda
/// all'autorità: un posto e, se serve, un bersaglio. Mai nomi né ruoli.
///
/// L'autorità la passa a [GameEngine.apply], che la valida contro le regole
/// e risponde con un [IntentResult].
sealed class PlayerIntent {
  /// Il posto di chi agisce (es. `s3`).
  final String seat;

  const PlayerIntent(this.seat);

  Map<String, Object?> toJson();

  factory PlayerIntent.fromJson(Map<String, Object?> json) {
    final seat = json['seat'] as String;
    return switch (json['type']) {
      'nightAction' => NightAction(seat, json['target'] as String),
      'mafiaVote' => MafiaVote(seat, json['target'] as String),
      'dayVote' => DayVote(seat, json['target'] as String),
      'pass' => Pass(seat),
      'revealMayor' => RevealMayor(seat),
      'pacify' => Pacify(seat, json['target'] as String),
      final type => throw FormatException('intenzione sconosciuta: $type'),
    };
  }

  @override
  bool operator ==(Object other) =>
      other is PlayerIntent && other.runtimeType == runtimeType && jsonEncode(other.toJson()) == jsonEncode(toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'PlayerIntent${toJson()}';
}

/// La mossa notturna di un ruolo che non spara: proteggere, indagare,
/// scavare, cucire, fare da scorta, il colpo del Cecchino, lo scoop, o il
/// compito di copertura di chi non ha poteri.
class NightAction extends PlayerIntent {
  final String target;

  const NightAction(super.seat, this.target);

  @override
  Map<String, Object?> toJson() => {'type': 'nightAction', 'seat': seat, 'target': target};
}

/// Il voto della famiglia per l'agguato della notte. Lo manda chi, di notte,
/// ha il compito [NightTaskKind.kill].
class MafiaVote extends PlayerIntent {
  final String target;

  const MafiaVote(super.seat, this.target);

  @override
  Map<String, Object?> toJson() => {'type': 'mafiaVote', 'seat': seat, 'target': target};
}

/// Il voto della piazza, di giorno. Si può cambiare finché il voto è aperto.
class DayVote extends PlayerIntent {
  final String target;

  const DayVote(super.seat, this.target);

  @override
  Map<String, Object?> toJson() => {'type': 'dayVote', 'seat': seat, 'target': target};
}

/// Di notte: passo, nessuna mossa. Di giorno: mi astengo.
class Pass extends PlayerIntent {
  const Pass(super.seat);

  @override
  Map<String, Object?> toJson() => {'type': 'pass', 'seat': seat};
}

/// Di giorno, il Sindaco si rivela: da quel momento, per il voto di oggi,
/// il suo voto vale due. Una volta per partita.
class RevealMayor extends PlayerIntent {
  const RevealMayor(super.seat);

  @override
  Map<String, Object?> toJson() => {'type': 'revealMayor', 'seat': seat};
}

/// Di giorno, in discussione, il Pacifista chiede la tregua: svela a tutti
/// il ruolo esatto di [target], si scopre, e oggi non si vota. Una volta per
/// partita.
class Pacify extends PlayerIntent {
  final String target;

  const Pacify(super.seat, this.target);

  @override
  Map<String, Object?> toJson() => {'type': 'pacify', 'seat': seat, 'target': target};
}

/// Perché un'intenzione è stata rifiutata.
enum IntentError {
  /// La partita è finita.
  gameOver,

  /// Il posto non è al tavolo (o è il narratore, che non gioca).
  unknownSeat,

  /// Chi agisce è morto.
  deadSeat,

  /// Non è il momento: un voto di giorno di notte, o viceversa.
  wrongPhase,

  /// Stanotte questo posto ha già fatto la sua mossa.
  alreadyActed,

  /// Non è la mossa di questo ruolo (es. un [MafiaVote] da chi non spara).
  notYourAction,

  /// Il bersaglio non si può scegliere (morto, sconosciuto, se stesso,
  /// la stessa persona protetta la notte prima...).
  targetNotAllowed,
}

/// La risposta dell'autorità a un'intenzione.
sealed class IntentResult {
  const IntentResult();

  bool get accepted => this is IntentAccepted;

  Map<String, Object?> toJson();

  factory IntentResult.fromJson(Map<String, Object?> json, [SeatResolver resolve = seatPlayer]) {
    if (json['ok'] == true) {
      final finding = json['finding'];
      return IntentAccepted(finding == null ? null : exposureFromJson(finding as Map<String, Object?>, resolve));
    }
    return IntentRejected(IntentError.values.byName(json['error'] as String), json['message'] as String);
  }
}

class IntentAccepted extends IntentResult {
  /// Quello che la mossa ha scoperto, solo per chi l'ha fatta: l'esito di
  /// un'indagine o di uno scavo.
  final Exposure? finding;

  const IntentAccepted([this.finding]);

  @override
  Map<String, Object?> toJson() => {'ok': true, 'finding': finding == null ? null : exposureToJson(finding!)};
}

class IntentRejected extends IntentResult {
  final IntentError error;

  /// Spiegazione per chi sviluppa, non per chi gioca: la UI traduce [error].
  final String message;

  const IntentRejected(this.error, this.message);

  @override
  Map<String, Object?> toJson() => {'ok': false, 'error': error.name, 'message': message};

  @override
  String toString() => 'IntentRejected(${error.name}: $message)';
}

/// Una riga del registro della partita: un'intenzione accettata, o un
/// comando dell'autorità. Con il seme, il registro rigioca la partita.
sealed class GameCommand {
  const GameCommand();

  Map<String, Object?> toJson();

  factory GameCommand.fromJson(Map<String, Object?> json) => switch (json['type']) {
    'intent' => IntentCommand(PlayerIntent.fromJson(json['intent'] as Map<String, Object?>)),
    'resolveNight' => const ResolveNightCommand(),
    'closeDayVote' => const CloseDayVoteCommand(),
    'lynch' => LynchCommand(json['seat'] as String?),
    'leaveTown' => LeaveTownCommand(json['seat'] as String),
    final type => throw FormatException('comando sconosciuto: $type'),
  };

  @override
  bool operator ==(Object other) => other is GameCommand && jsonEncode(other.toJson()) == jsonEncode(toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;
}

class IntentCommand extends GameCommand {
  final PlayerIntent intent;

  const IntentCommand(this.intent);

  @override
  Map<String, Object?> toJson() => {'type': 'intent', 'intent': intent.toJson()};
}

/// L'autorità chiude la notte ([GameEngine.resolveNight]).
class ResolveNightCommand extends GameCommand {
  const ResolveNightCommand();

  @override
  Map<String, Object?> toJson() => {'type': 'resolveNight'};
}

/// L'autorità chiude il voto della piazza ([GameEngine.closeDayVote]).
class CloseDayVoteCommand extends GameCommand {
  const CloseDayVoteCommand();

  @override
  Map<String, Object?> toJson() => {'type': 'closeDayVote'};
}

/// Il narratore condanna qualcuno direttamente ([GameEngine.lynch]), come
/// nel gioco su un telefono solo. `null`: nessuna condanna.
class LynchCommand extends GameCommand {
  final String? seat;

  const LynchCommand(this.seat);

  @override
  Map<String, Object?> toJson() => {'type': 'lynch', 'seat': seat};
}

/// Chi se n'è andato davvero (online: il telefono spento oltre la
/// tolleranza) lascia la città ([GameEngine.leaveTown]).
class LeaveTownCommand extends GameCommand {
  final String seat;

  const LeaveTownCommand(this.seat);

  @override
  Map<String, Object?> toJson() => {'type': 'leaveTown', 'seat': seat};
}
