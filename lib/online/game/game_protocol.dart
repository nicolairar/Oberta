import 'dart:convert';

import '../../l10n/app_language.dart';
import '../../rules/game_engine.dart';
import '../../rules/game_settings.dart';
import '../../rules/intent.dart';
import '../../rules/player.dart';
import '../../rules/player_view.dart';
import '../../rules/rules_json.dart';
import '../../table/seating.dart';

/// Il posto segnaposto di chi è stato preso di mira e l'ha scampata: al
/// tavolo resta anonimo, e così sul filo.
const anonymousSeat = '?';

/// Copia profonda di un JSON, come se avesse fatto il giro del server.
Map<String, Object?> wireCopy(Map<String, Object?> json) => jsonDecode(jsonEncode(json)) as Map<String, Object?>;

/// Toglie dal tavolo pubblico quello che il narratore non dice: chi è stato
/// preso di mira e si è salvato resta «qualcuno», e chi ha sparato a vuoto
/// non si sa. Si fa su ogni tavolo che lascia il telefono dell'autorità.
Map<String, Object?> sanitizeBoard(Map<String, Object?> board) {
  final copy = wireCopy(board);
  final dawn = copy['lastDawn'] as Map<String, Object?>?;
  if (dawn != null) {
    dawn['attacks'] = [
      for (final attack in (dawn['attacks'] as List<Object?>).cast<Map<String, Object?>>())
        if (attack['outcome'] == AttackOutcome.killed.name)
          attack
        else
          {'target': anonymousSeat, 'source': AttackSource.family.name, 'outcome': attack['outcome']},
    ];
  }
  return copy;
}

/// Il tavolo di tutti: la vista pubblica ripulita, chi siede dove (i bot
/// senza profilo), il seme del narratore e la scadenza della fase.
Map<String, Object?> publicPayload({
  required GameEngine engine,
  required Seating seating,
  required int narrationSeed,
  required AppLanguage language,
  required DateTime? deadline,
}) =>
    {
      'board': sanitizeBoard(engine.publicView().toJson()),
      'seating': seating.toJson(),
      'narrationSeed': narrationSeed,
      'language': language.name,
      'settings': settingsToJson(engine.settings),
      'deadline': deadline?.millisecondsSinceEpoch,
    };

/// La vista di un posto, e la risposta all'ultima intenzione che ha mandato.
Map<String, Object?> seatPayload(PlayerView view, {Map<String, Object?>? receipt}) {
  final json = wireCopy(view.toJson());
  json['board'] = sanitizeBoard(json['board'] as Map<String, Object?>);
  return {'view': json, 'receipt': receipt};
}

/// Il resolver dei telefoni: i posti della partita col loro nome; il
/// segnaposto anonimo (e ogni posto sconosciuto) senza nome.
SeatResolver resolverFor(Seating seating) => (seat) {
      final occupant = seating.occupantOf(seat);
      return Player(id: seat, name: occupant?.name ?? '');
    };

/// Il tavolo pubblico, letto da un telefono.
class OnlineBoard {
  final int version;
  final PublicView view;
  final Seating seating;
  final int narrationSeed;
  final AppLanguage language;
  final GameSettings settings;
  final DateTime? deadline;

  const OnlineBoard({
    required this.version,
    required this.view,
    required this.seating,
    required this.narrationSeed,
    required this.language,
    required this.settings,
    required this.deadline,
  });

  factory OnlineBoard.fromPayload(int version, Map<String, Object?> json) {
    final seating = Seating.fromJson(json['seating'] as Map<String, Object?>);
    final deadline = json['deadline'] as int?;
    return OnlineBoard(
      version: version,
      view: PublicView.fromJson(json['board'] as Map<String, Object?>, resolverFor(seating)),
      seating: seating,
      narrationSeed: json['narrationSeed'] as int,
      language: json['language'] == 'en' ? AppLanguage.en : AppLanguage.it,
      settings: settingsFromJson(json['settings'] as Map<String, Object?>),
      deadline: deadline == null ? null : DateTime.fromMillisecondsSinceEpoch(deadline),
    );
  }

  /// Vero se [seat] è un bot.
  bool isBot(String seat) {
    final occupant = seating.occupantOf(seat);
    return occupant != null && occupant.profileId == null;
  }
}

/// La risposta dell'autorità a un'intenzione: il suo numero e l'esito.
typedef IntentReceipt = ({int id, IntentResult result});

/// La vista di un posto, letta dal telefono di chi ci siede.
class OnlineSeat {
  final int version;
  final PlayerView view;
  final IntentReceipt? receipt;

  const OnlineSeat({required this.version, required this.view, this.receipt});

  factory OnlineSeat.fromPayload(int version, Map<String, Object?> json, Seating seating) {
    final resolve = resolverFor(seating);
    final receipt = json['receipt'] as Map<String, Object?>?;
    return OnlineSeat(
      version: version,
      view: PlayerView.fromJson(json['view'] as Map<String, Object?>, resolve),
      receipt: receipt == null
          ? null
          : (
              id: receipt['id'] as int,
              result: IntentResult.fromJson(receipt['result'] as Map<String, Object?>, resolve),
            ),
    );
  }
}
