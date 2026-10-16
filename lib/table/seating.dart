import '../rules/player.dart';

/// Chi siede a un posto: un nome da mostrare e, se c'è, un profilo.
class Occupant {
  /// L'id del posto in questa partita (es. `s3`): è tutto ciò che il motore
  /// conosce, e tutto ciò che viaggia nelle intenzioni e nelle viste.
  final String seat;
  final String displayName;

  /// L'account, quando chi gioca ne ha uno. Facoltativo: un ospite non ce
  /// l'ha, e al tavolo di un telefono solo non serve.
  final String? profileId;

  const Occupant({required this.seat, required this.displayName, this.profileId});

  Map<String, Object?> toJson() => {'seat': seat, 'displayName': displayName, 'profileId': profileId};

  factory Occupant.fromJson(Map<String, Object?> json) => Occupant(
        seat: json['seat'] as String,
        displayName: json['displayName'] as String,
        profileId: json['profileId'] as String?,
      );
}

/// Chi siede dove, per una partita. Sta fuori dal motore: il motore conosce
/// solo i posti, e i profili (con statistiche e classifica) si agganciano ai
/// posti qui, a fine partita.
///
/// I posti si danno nell'ordine di [Seating.open]: `s1`, `s2`, ... Non
/// dicono nulla di chi c'è seduto, né da una partita all'altra.
class Seating {
  final List<Occupant> occupants;

  Seating(List<Occupant> occupants) : occupants = List.unmodifiable(occupants) {
    final seats = {for (final occupant in occupants) occupant.seat};
    if (seats.length != occupants.length) throw ArgumentError('due persone sullo stesso posto');
    final profiles = [
      for (final occupant in occupants)
        if (occupant.profileId != null) occupant.profileId,
    ];
    if (profiles.toSet().length != profiles.length) throw ArgumentError('lo stesso profilo su due posti');
  }

  /// Dà un posto nuovo a ciascuno, nell'ordine in cui arrivano.
  factory Seating.open(List<({String displayName, String? profileId})> guests) => Seating([
        for (final (index, guest) in guests.indexed)
          Occupant(seat: 's${index + 1}', displayName: guest.displayName, profileId: guest.profileId),
      ]);

  Occupant? occupantOf(String seat) {
    for (final occupant in occupants) {
      if (occupant.seat == seat) return occupant;
    }
    return null;
  }

  String? seatOfProfile(String profileId) {
    for (final occupant in occupants) {
      if (occupant.profileId == profileId) return occupant.seat;
    }
    return null;
  }

  String? profileOf(String seat) => occupantOf(seat)?.profileId;

  /// Il [Player] del motore per [seat]: l'id è il posto, il nome quello da
  /// mostrare. Va bene come resolver per `GameSnapshot.fromJson` e le viste.
  Player playerAt(String seat) {
    final occupant = occupantOf(seat);
    if (occupant == null) throw ArgumentError.value(seat, 'seat', 'posto vuoto');
    return Player(id: seat, name: occupant.displayName);
  }

  /// I giocatori da passare al motore, in ordine di posto.
  List<Player> get players => [for (final occupant in occupants) playerAt(occupant.seat)];

  Map<String, Object?> toJson() => {
        'occupants': [for (final occupant in occupants) occupant.toJson()],
      };

  factory Seating.fromJson(Map<String, Object?> json) => Seating([
        for (final row in (json['occupants'] as List<Object?>).cast<Map<String, Object?>>()) Occupant.fromJson(row),
      ]);
}
