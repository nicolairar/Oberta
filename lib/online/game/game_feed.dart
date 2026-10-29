import '../../l10n/lobby_language.dart';
import '../../rules/game_settings.dart';
import '../../rules/intent.dart';
import '../../rules/player_view.dart';
import '../../rules/rules_json.dart';
import '../../table/seating.dart';
import 'game_protocol.dart';
import 'game_schedule.dart';

/// Il tavolo pubblico, letto da un telefono.
class OnlineBoard {
  final int version;
  final PublicView view;
  final Seating seating;
  final int narrationSeed;
  final LobbyLanguage language;
  final GameSettings settings;
  final DateTime? deadline;

  /// Il server ha chiuso la partita: da un pezzo nessuno giocava più.
  final bool abandoned;

  /// La fase in corso, con l'inizio e la fine secondo l'orologio del server.
  final StageWindow? schedule;

  /// I posti offline adesso, e quelli che hanno lasciato la città.
  final Set<String> offline;
  final List<String> departed;

  const OnlineBoard({
    required this.version,
    required this.view,
    required this.seating,
    required this.narrationSeed,
    required this.language,
    required this.settings,
    required this.deadline,
    this.abandoned = false,
    this.schedule,
    this.offline = const {},
    this.departed = const [],
  });

  factory OnlineBoard.fromPayload(int version, Map<String, Object?> json) {
    final seating = Seating.fromJson(json['seating'] as Map<String, Object?>);
    final deadline = json['deadline'] as int?;
    return OnlineBoard(
      version: version,
      view: PublicView.fromJson(json['board'] as Map<String, Object?>, resolverFor(seating)),
      seating: seating,
      narrationSeed: json['narrationSeed'] as int,
      language: LobbyLanguage.parse(json['language']),
      settings: settingsFromJson(json['settings'] as Map<String, Object?>),
      deadline: deadline == null ? null : DateTime.fromMillisecondsSinceEpoch(deadline),
      abandoned: json['abandoned'] == true,
      schedule: json['schedule'] == null ? null : StageWindow.fromJson(json['schedule'] as Map<String, Object?>),
      offline: {for (final seat in (json['offline'] as List<Object?>? ?? const [])) seat as String},
      departed: [for (final seat in (json['departed'] as List<Object?>? ?? const [])) seat as String],
    );
  }

  /// Vero se [seat] è un bot.
  bool isBot(String seat) {
    final occupant = seating.occupantOf(seat);
    return occupant != null && occupant.profileId == null;
  }
}

/// La risposta del server a un'intenzione: il segno casuale che le ha dato
/// `submit_intent` e l'esito.
typedef IntentReceipt = ({String? token, IntentResult result});

/// La vista di un posto, letta dal telefono di chi ci siede.
class OnlineSeat {
  final int version;
  final PlayerView view;
  final IntentReceipt? receipt;

  /// Il server ha ricevuto la conferma di questo posto per la fase in corso.
  final bool acked;

  const OnlineSeat({required this.version, required this.view, this.receipt, this.acked = false});

  factory OnlineSeat.fromPayload(int version, Map<String, Object?> json, Seating seating) {
    final resolve = resolverFor(seating);
    final receipt = json['receipt'] as Map<String, Object?>?;
    return OnlineSeat(
      version: version,
      view: PlayerView.fromJson(json['view'] as Map<String, Object?>, resolve),
      receipt: receipt == null
          ? null
          : (
              token: receipt['token'] as String?,
              result: IntentResult.fromJson(receipt['result'] as Map<String, Object?>, resolve),
            ),
      acked: json['acked'] == true,
    );
  }
}
