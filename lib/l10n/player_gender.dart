import '../online/online_models.dart';

/// How Italian agrees with a player: «è stata linciata» for a woman, «è stato
/// linciato» for a man, and a phrasing that needs no agreement when nobody
/// has said («la piazza ha linciato Vito»).
enum Gender { feminine, masculine, unknown }

/// What the app knows about a player's grammar, by name. A player chooses it
/// in the barber's mirror (`presentation`: «Donna», «Uomo», «Altro»), and the
/// saved look arrives with every profile ([WornLooks]). The tutorial's bots
/// say theirs with [remember]. Nobody is guessed from a face or a name.
abstract final class PlayerGenders {
  static final Map<String, Gender> _byName = {};

  /// The table writes names as «3 Carmela»: the seat number goes.
  static final _seat = RegExp(r'^\d+\s+');

  static void remember(String name, Gender gender) => _byName[name] = gender;

  static Gender of(String name) {
    final bare = name.replaceFirst(_seat, '');
    for (final key in {name, bare}) {
      if (_byName[key] case final known?) return known;
      switch (WornLooks.of(key)?['presentation']) {
        case 'woman':
          return Gender.feminine;
        case 'man':
          return Gender.masculine;
        case 'other':
          return Gender.unknown;
      }
    }
    return Gender.unknown;
  }

  /// For tests.
  static void clear() => _byName.clear();
}

/// The Italian word or sentence that agrees with [gender]: [f] for a woman,
/// [m] for a man, [n] (no agreement needed) when unknown; [n] defaults to [m]
/// where Italian has no neutral way to say it.
String agree(Gender gender, {required String m, required String f, String? n}) => switch (gender) {
  Gender.feminine => f,
  Gender.masculine => m,
  Gender.unknown => n ?? m,
};
