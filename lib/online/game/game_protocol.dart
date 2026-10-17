import 'dart:convert';

import '../../rules/game_engine.dart';
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
/// non si sa. Si fa su ogni tavolo che lascia il server.
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
/// senza profilo), il seme del narratore, la lingua (`it`, `en`), la
/// scadenza della fase e, se nessuno giocava più, che la partita è chiusa.
Map<String, Object?> publicPayload({
  required GameEngine engine,
  required Seating seating,
  required int narrationSeed,
  required String language,
  required DateTime? deadline,
  bool abandoned = false,
}) =>
    {
      'board': sanitizeBoard(engine.publicView().toJson()),
      'seating': seating.toJson(),
      'narrationSeed': narrationSeed,
      'language': language,
      'settings': settingsToJson(engine.settings),
      'deadline': deadline?.millisecondsSinceEpoch,
      'abandoned': abandoned,
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
