import 'dart:math';

import '../l10n/app_language.dart';
import 'handle_rules.dart';

/// Un profilo online: chi è una persona per gli altri giocatori, su ogni
/// telefono dove entra con lo stesso account.
class Profile {
  final String id;

  /// Il nome unico, ed è l'unico nome: quello che gli altri vedono nella
  /// stanza, al tavolo e tra gli amici, così nessuno si spaccia per un altro.
  /// Regole in [HandleRules]. Vuoto finché la persona non l'ha scelto.
  final String? handle;
  final AppLanguage language;

  /// L'aspetto indossato, per id di catalogo: `{base, hat, glasses, ...}`.
  final Map<String, String> avatar;

  /// Livello, esperienza verso il prossimo livello e monete. Li scrive solo
  /// il server, e solo il padrone del profilo li legge (vedi `my_profile()`
  /// nel database): nei profili degli altri restano ai valori di partenza.
  final int level;
  final int xp;
  final int coins;

  const Profile({
    required this.id,
    this.handle,
    this.language = AppLanguage.it,
    this.avatar = const {},
    this.level = 1,
    this.xp = 0,
    this.coins = 0,
  });

  /// Senza nome unico non si entra nelle stanze.
  bool get isComplete => handle != null;

  /// Il nome che vedono tutti: il nome unico.
  String get name => handle ?? '';

  /// Il seme del ritratto disegnato: sempre la stessa faccia per lo stesso account.
  String get avatarSeed => avatar['base'] ?? handle ?? id;

  /// Quanta esperienza serve per passare dal livello [level] al seguente.
  /// Provvisorio: quando il server darà l'esperienza deciderà lui la scala.
  static int xpToNext(int level) => 100 * max(1, level);

  /// Quanto manca al prossimo livello, da 0 a 1: la barra del profilo.
  double get levelProgress => (xp / xpToNext(level)).clamp(0.0, 1.0);

  Profile copyWith({String? handle, AppLanguage? language, int? level, int? xp, int? coins}) => Profile(
        id: id,
        handle: handle ?? this.handle,
        language: language ?? this.language,
        avatar: avatar,
        level: level ?? this.level,
        xp: xp ?? this.xp,
        coins: coins ?? this.coins,
      );

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'] as String,
        handle: json['handle'] as String?,
        language: json['language'] == 'en' ? AppLanguage.en : AppLanguage.it,
        avatar: {
          for (final MapEntry(:key, :value) in ((json['avatar'] as Map?) ?? const {}).entries)
            if (value is String) key as String: value,
        },
        level: (json['level'] as num?)?.toInt() ?? 1,
        xp: (json['xp'] as num?)?.toInt() ?? 0,
        coins: (json['coins'] as num?)?.toInt() ?? 0,
      );

  static const minHandle = HandleRules.minLength;
  static const maxHandle = HandleRules.maxLength;

  /// Il nome unico come lo si salva: in minuscolo, senza spazi intorno.
  static String normalizeHandle(String typed) => HandleRules.normalize(typed);
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

  /// Il server non ha acceso questo modo di entrare (Supabase, Authentication
  /// → Providers).
  appleDisabled,
  googleDisabled,
  emailDisabled,

  /// L'account di prova: password sbagliata, troppo debole, email storta,
  /// o il server vuole la conferma via email.
  wrongPassword,
  weakPassword,
  invalidEmail,
  emailNotConfirmed,
  profileIncomplete,
  handleTaken,
  invalidHandle,

  /// Il nome offende, finge di essere lo staff o un bot.
  handleNotAllowed,
  roomNotFound,
  roomClosed,
  roomFull,

  /// Il padrone di casa esce mentre altri sono seduti: prima deve scegliere
  /// a chi lasciare la stanza.
  hostMustChoose,
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

  /// Il motivo tecnico (codice e messaggio di Apple, Google o Supabase), da
  /// mostrare in piccolo sotto il messaggio gentile: chi prova l'app in
  /// TestFlight lo può copiare in una segnalazione.
  final String? detail;

  const OnlineException(this.failure, [this.cause, this.detail]);

  /// Il motivo tecnico, se c'è.
  String? get reason => detail ?? cause?.toString();

  @override
  String toString() => 'OnlineException(${failure.name}${reason == null ? '' : ': $reason'})';
}
