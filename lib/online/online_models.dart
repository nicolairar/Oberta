import '../l10n/app_language.dart';

/// Un profilo online: chi è una persona per gli altri giocatori, su ogni
/// telefono dove entra con lo stesso account.
class Profile {
  final String id;

  /// Il nome unico per farsi trovare, in minuscolo. Vuoto finché la persona
  /// non ha finito di prepararsi il profilo.
  final String? handle;
  final String? displayName;
  final AppLanguage language;

  /// L'aspetto indossato, per id di catalogo: `{base, hat, glasses, ...}`.
  final Map<String, String> avatar;

  const Profile({
    required this.id,
    this.handle,
    this.displayName,
    this.language = AppLanguage.it,
    this.avatar = const {},
  });

  /// Senza nome unico e nome da mostrare non si entra nelle stanze.
  bool get isComplete => handle != null && (displayName?.isNotEmpty ?? false);

  /// Il nome da mostrare, o il nome unico se manca.
  String get name => displayName ?? handle ?? '';

  /// Il seme del ritratto disegnato: sempre la stessa faccia per lo stesso account.
  String get avatarSeed => avatar['base'] ?? handle ?? id;

  Profile copyWith({String? handle, String? displayName, AppLanguage? language}) => Profile(
        id: id,
        handle: handle ?? this.handle,
        displayName: displayName ?? this.displayName,
        language: language ?? this.language,
        avatar: avatar,
      );

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'] as String,
        handle: json['handle'] as String?,
        displayName: json['display_name'] as String?,
        language: json['language'] == 'en' ? AppLanguage.en : AppLanguage.it,
        avatar: {
          for (final MapEntry(:key, :value) in ((json['avatar'] as Map?) ?? const {}).entries)
            if (value is String) key as String: value,
        },
      );

  /// Un nome unico valido: da 3 a 20 fra lettere minuscole, cifre e trattini bassi.
  static final handlePattern = RegExp(r'^[a-z0-9_]{3,20}$');

  static const maxDisplayName = 24;
}

enum FriendStatus { pending, accepted, blocked }

/// Un legame fra il giocatore e un altro profilo, visto dalla sua parte.
class Friendship {
  final Profile other;
  final FriendStatus status;

  /// Vero se la richiesta l'ha mandata l'altro: tocca a noi rispondere.
  final bool incoming;

  const Friendship({required this.other, required this.status, required this.incoming});
}

enum RoomStatus { lobby, playing, ended }

class Room {
  final String id;

  /// Sei caratteri, senza 0/O e 1/I/L: si legge ad alta voce senza equivoci.
  final String code;
  final String hostId;
  final AppLanguage language;
  final RoomStatus status;
  final int maxPlayers;

  const Room({
    required this.id,
    required this.code,
    required this.hostId,
    required this.language,
    this.status = RoomStatus.lobby,
    this.maxPlayers = 16,
  });

  factory Room.fromJson(Map<String, dynamic> json) => Room(
        id: json['id'] as String,
        code: json['code'] as String,
        hostId: json['host'] as String,
        language: json['language'] == 'en' ? AppLanguage.en : AppLanguage.it,
        status: RoomStatus.values.byName(json['status'] as String),
        maxPlayers: (json['max_players'] as num).toInt(),
      );
}

/// Chi siede in una stanza, e a che posto.
class RoomMember {
  final Profile profile;
  final int seat;

  const RoomMember({required this.profile, required this.seat});
}

/// Che cosa è andato storto, in parole che la UI sa tradurre.
enum OnlineFailure {
  notSignedIn,
  profileIncomplete,
  handleTaken,
  invalidHandle,
  roomNotFound,
  roomClosed,
  roomFull,
  playerNotFound,
  notAllowed,
  requestNotFound,
  cancelled,
  network,
  unknown,
}

class OnlineException implements Exception {
  final OnlineFailure failure;
  final Object? cause;

  const OnlineException(this.failure, [this.cause]);

  @override
  String toString() => 'OnlineException(${failure.name}${cause == null ? '' : ': $cause'})';
}
