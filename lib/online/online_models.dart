
import '../l10n/app_language.dart';
import 'game/match_rewards.dart';
import 'handle_rules.dart';

/// I look indossati dai giocatori online, per nome: ogni profilo che arriva
/// dal server lascia qui il suo, così il ritratto di quel nome (in una
/// stanza, al tavolo, tra gli amici) lo indossa senza che chi lo disegna
/// debba passarlo a mano.
abstract final class WornLooks {
  static final Map<String, Map<String, String>> _byName = {};

  static void remember(Profile profile) {
    final name = profile.handle;
    if (name == null) return;
    if (profile.avatar.isEmpty) {
      _byName.remove(name);
    } else {
      _byName[name] = profile.avatar;
    }
  }

  /// Il look salvato di chi si chiama [name], se c'è.
  static Map<String, String>? of(String name) => _byName[name];

  /// Per i test.
  static void clear() => _byName.clear();
}

/// Un profilo online: chi è una persona per gli altri giocatori, su ogni
/// telefono dove entra con lo stesso account.
/// Livello, esperienza e monete: la riga `wallets` che il server spinge con
/// Realtime. Solo il server la scrive; l'app la mostra e basta.
class Wallet {
  final int level;
  final int xp;
  final int coins;

  const Wallet({required this.level, required this.xp, required this.coins});

  factory Wallet.fromJson(Map<String, dynamic> json) => Wallet(
        level: (json['level'] as num).toInt(),
        xp: (json['xp'] as num).toInt(),
        coins: (json['coins'] as num).toInt(),
      );
}

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
  /// La stessa scala del server (`match_rewards.dart`): 150 + 25·L.
  static int xpToNext(int level) => Progression.xpToNext(level);

  /// Quanto manca al prossimo livello, da 0 a 1: la barra del profilo.
  double get levelProgress => (xp / xpToNext(level)).clamp(0.0, 1.0);

  Profile copyWith({String? handle, AppLanguage? language, Map<String, String>? avatar, int? level, int? xp, int? coins}) => Profile(
        id: id,
        handle: handle ?? this.handle,
        language: language ?? this.language,
        avatar: avatar ?? this.avatar,
        level: level ?? this.level,
        xp: xp ?? this.xp,
        coins: coins ?? this.coins,
      );

  factory Profile.fromJson(Map<String, dynamic> json) {
    final profile = Profile._fromJson(json);
    WornLooks.remember(profile);
    return profile;
  }

  factory Profile._fromJson(Map<String, dynamic> json) => Profile(
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

  /// I bot di prova che il padrone di casa ha messo al tavolo.
  final int bots;

  /// Aperta dal matchmaking della classificata: niente padrone di casa,
  /// niente bot. [testMatch]: partita di prova (bot, non classificata).
  final bool ranked;
  final bool testMatch;

  /// La classificata: quando parte il conto alla rovescia del tavolo pieno
  /// finisce e la partita comincia. Null mentre si aspetta.
  final DateTime? startsAt;

  const Room({
    required this.id,
    required this.code,
    required this.hostId,
    required this.language,
    this.status = RoomStatus.lobby,
    this.maxPlayers = 16,
    this.bots = 0,
    this.ranked = false,
    this.testMatch = false,
    this.startsAt,
  });

  factory Room.fromJson(Map<String, dynamic> json) => Room(
        id: json['id'] as String,
        code: json['code'] as String,
        hostId: json['host'] as String,
        language: json['language'] == 'en' ? AppLanguage.en : AppLanguage.it,
        status: RoomStatus.values.byName(json['status'] as String),
        maxPlayers: (json['max_players'] as num).toInt(),
        bots: (json['bots'] as num?)?.toInt() ?? 0,
        ranked: json['ranked'] == true,
        testMatch: json['test_match'] == true,
        startsAt: json['starts_at'] == null ? null : DateTime.parse(json['starts_at'] as String),
      );

  static const _keep = Object();

  Room copyWith({String? hostId, RoomStatus? status, int? bots, Object? startsAt = _keep}) => Room(
        id: id,
        code: code,
        hostId: hostId ?? this.hostId,
        language: language,
        status: status ?? this.status,
        maxPlayers: maxPlayers,
        bots: bots ?? this.bots,
        ranked: ranked,
        testMatch: testMatch,
        startsAt: identical(startsAt, _keep) ? this.startsAt : startsAt as DateTime?,
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

  /// La chat: parole che non passano, troppi messaggi di fila, o adesso non
  /// si può scrivere lì (di notte, da morti, con la bocca cucita).
  messageBlocked,
  tooManyMessages,
  chatClosed,

  /// La bottega: monete che non bastano, un pezzo già posseduto, un pezzo
  /// da comprare prima di indossarlo, un pezzo che il catalogo non ha più.
  notEnoughCoins,
  alreadyOwned,
  notOwned,
  itemNotFound,
  cancelled,

  /// La classificata: in pausa dopo troppi abbandoni, o già in partita.
  rankedCooldown,
  alreadyInGame,
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
