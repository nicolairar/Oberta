import 'dart:async';
import 'dart:convert';
import 'dart:math';

import '../l10n/app_language.dart';
import '../rules/intent.dart';
import '../ui/avatar/avatar_look.dart' show AvatarLook, FaceExtra, HeldItem;
import '../ui/avatar/face_features.dart' show FaceFeatures;
import 'game/bot_brain.dart';
import 'game/game_clock.dart';
import 'game/game_schedule.dart';
import 'game/game_server.dart';
import 'game/match_rewards.dart' show settleJson;
import 'game/progress.dart' show mergeStats;
import 'handle_rules.dart';
import 'join_code.dart';
import 'online_services.dart';

/// Un server finto, tutto in memoria, con le stesse regole del database:
/// stanze con posti e capienza, amicizie che si chiedono e si accettano.
/// Serve ai test (e a provare le schermate senza rete); gli altri giocatori
/// si fanno entrare a mano con [addPlayer] e [joinAs].
class FakeOnline {
  final Random _random;
  final Map<String, Profile> _profiles = {};
  final List<_Link> _links = [];
  final Map<String, _FakeRoom> _rooms = {};

  /// L'account che entrerà premendo «Entra con Apple» o «con Google».
  final String accountId;

  late final FakeAuth auth = FakeAuth._(this);
  late final FakeProfiles profiles = FakeProfiles._(this);
  late final FakeFriends friends = FakeFriends._(this);
  late final FakeRooms rooms = FakeRooms._(this);
  late final FakeGame game = FakeGame._(this, () => auth.userId);
  late final FakeShop shop = FakeShop._(this);
  late final FakeReactions reactions = FakeReactions._(this, () => auth.userId);

  /// I gesti visti da [userId].
  FakeReactions reactionsAs(String userId) => FakeReactions._(this, () => userId);

  /// I gesti lanciati, come `table_reactions`.
  final List<({String room, String? game, TableReaction reaction})> _reactions = [];
  late final FakeRanked ranked = FakeRanked._(this);
  late final FakeSafety safety = FakeSafety._(this);
  late final FakeProgress progress = FakeProgress._(this);
  late final FakeDeviceSessions sessions = FakeDeviceSessions(() => auth.userId);

  /// I blocchi, come `player_blocks`: (chi blocca, chi è bloccato).
  final Set<(String, String)> blocks = {};

  /// Le segnalazioni ricevute dal server, come `internal.reports`.
  final List<FakeReport> reports = [];

  bool _blockedBetween(String a, String b) => blocks.contains((a, b)) || blocks.contains((b, a));

  /// La cronologia delle partite di ogni profilo (come `match_history`).
  final Map<String, List<MatchResult>> history = {};

  /// Il rating per profilo e lingua (come `ratings`).
  final Map<(String, AppLanguage), Rating> ratings = {};

  /// La coda della classificata: profilo → (lingua, da quando).
  final Map<String, (AppLanguage, DateTime)> rankedQueue = {};

  /// La pausa dopo troppi abbandoni in classificata, per profilo.
  final Map<String, DateTime> cooldowns = {};

  /// Le mani di prova registrate per profilo (come `tutorial_completions`).
  final Map<String, Set<String>> tutorials = {};

  /// Spento (di base), ognuno conta come se avesse finito le tre mani di
  /// prova; acceso, la classificata le chiede davvero.
  bool requireTutorials = false;

  static const tutorialFactions = {'family', 'town', 'solo'};

  Set<String> tutorialsOf(String me) => requireTutorials ? {...?tutorials[me]} : {...tutorialFactions};

  /// Quanti posti ha una partita classificata: sempre esattamente tanti.
  int rankedSize = 12;

  /// Altri giocatori in giro, per la locandina della home (solo il numero).
  int extraOnline = 0;

  /// Il conto alla rovescia del tavolo pieno.
  Duration rankedCountdown = const Duration(seconds: 10);
  int _rankedIds = 0;

  /// SOLO PROVA: con un numero, tante persone in coda bastano (più i bot),
  /// e la partita non è classificata. Null: spento.
  int? rankedTestHumans;
  late final FakeAccount account = FakeAccount._(this);
  late final FakeAccountLinks links = FakeAccountLinks._(this);

  /// La partita vista da un altro account, come dal suo telefono.
  FakeGame gameAs(String userId) => FakeGame._(this, () => userId);

  final Map<String, _FakeGameRoom> _games = {};
  final List<void Function()> _gameWatchers = [];
  final List<({String room, String? game, ChatMessage message})> _chat = [];

  /// Chi ha scritto, senza firma, i messaggi del Carceriere (id -> profilo):
  /// come la tabella riservata del server, per la moderazione.
  final Map<String, String> _jailers = {};

  /// The server's lines (`game_events`): `to` the only profile that reads it.
  final List<({String room, String game, String? to, ChatMessage message})> _events = [];
  int _intentIds = 0;
  final Random _chatIds = Random();

  /// Like the server's: a random id (a uuid's shape), never a counter. Chat
  /// ids and intent tokens.
  String _chatId() {
    String hex(int digits) => [for (var i = 0; i < digits; i++) _chatIds.nextInt(16).toRadixString(16)].join();
    return '${hex(8)}-${hex(4)}-4${hex(3)}-a${hex(3)}-${hex(12)}';
  }
  int _gameIds = 0;

  /// L'orologio del server finto: quello vero, o uno a mano nei test.
  GameClock clock;

  /// I tempi della partita.
  OnlinePacing pacing;

  /// Se vero, il server guarda chi si fa sentire (offline, chi lascia la
  /// città). Spento, tutti risultano sempre collegati.
  bool trackPresence = false;

  /// Gli account il cui telefono è senza rete (o in sfondo): i ping falliscono
  /// e il tempo reale non consegna più niente, finché non ne escono.
  final Set<String> unreachable = {};

  /// Quante volte un telefono ha ripreso il collegamento.
  int resumes = 0;

  /// Quante versioni della partita ha pubblicato il server.
  int published = 0;

  /// Gli abbandoni annotati dal server in una partita (i posti), per i test.
  List<String> abandonsIn(String roomId) => [...?_games[roomId]?.abandons];

  /// Tutto quello che il server ha consegnato a ogni telefono, in ordine:
  /// i test controllano che nessuno riceva quello che non deve.
  final List<({String user, GameFeed feed})> deliveries = [];

  /// Se vero, ogni chiamata aspetta un giro come la rete vera.
  bool slow = true;

  /// Il periodo di prova del server (`friends_test_bots`): due persone
  /// bastano e i bot riempiono i posti vuoti, fino a [friendsTestSize].
  bool friendsTestBots = false;
  int? friendsTestSize;

  Future<void> _network() => slow ? Future<void>.delayed(Duration.zero) : Future<void>.value();

  void _notifyGame(String roomId) {
    // I telefoni ricevono le novità poco dopo, non durante la chiamata.
    scheduleMicrotask(() {
      for (final watcher in [..._gameWatchers]) {
        watcher();
      }
    });
  }

  /// La stanza com'è adesso sul server.
  Room? roomOf(String roomId) => _rooms[roomId]?.room;

  /// La stanza aperta con questo codice.
  Room? roomByCode(String code) => _rooms.values.where((room) => room.room.code == code).firstOrNull?.room;

  FakeOnline({this.accountId = 'me', Random? random, GameClock? clock, this.pacing = const OnlinePacing()})
      : _random = random ?? Random(7),
        clock = clock ?? const SystemGameClock();

  OnlineServices get services =>
      OnlineServices(auth: auth, profiles: profiles, friends: friends, rooms: rooms, game: game, shop: shop, account: account, ranked: ranked, safety: safety, sessions: sessions, links: links, progress: progress, reactions: reactions);

  /// Gli account di prova: email → (password, id dell'account).
  final Map<String, (String, String)> _testAccounts = {};

  /// Se falso, il server finge di avere il provider Email spento.
  bool emailEnabled = true;

  /// Qualcun altro, già con il suo profilo.
  Profile addPlayer(String id, {required String handle}) => _profiles[id] = Profile(id: id, handle: handle);

  /// [id] spegne «Profilo pubblico».
  void hideProfile(String id) => _profiles[id] = _profiles[id]!.copyWith(publicProfile: false);

  /// Entra già con il profilo pronto, come chi ha giocato altre volte.
  void signInReady({String handle = 'tu', int level = 1, int xp = 0, int coins = 0}) {
    _profiles[accountId] = Profile(id: accountId, handle: handle, level: level, xp: xp, coins: coins);
    auth._signIn(accountId);
  }

  /// Come `steam-auth`: [id] ha un account Steam collegato, con il suo nome
  /// Steam e (se c'è) l'immagine.
  void linkSteam(String id, {required String persona, String? avatar}) {
    final p = _profiles[id]!;
    _profiles[id] = Profile(
      id: id,
      handle: p.handle,
      language: p.language,
      avatar: p.avatar,
      level: p.level,
      xp: p.xp,
      coins: p.coins,
      onSteam: true,
      onApple: p.onApple,
      steamPersona: persona,
      steamAvatar: avatar,
      picture: p.picture,
      pictureUrl: p.picture == ProfilePicture.steam ? avatar : null,
    );
  }

  /// Quello che solo il server scrive: livello, esperienza, monete.
  void award(String id, {int? level, int? xp, int? coins}) {
    _profiles[id] = _profiles[id]!.copyWith(level: level, xp: xp, coins: coins);
    _pushWallet(id);
  }

  /// Come il trigger di `wallets` con Realtime: ogni cambio di saldo arriva.
  final _wallets = StreamController<(String, Wallet)>.broadcast();

  void _pushWallet(String id) {
    final p = _profiles[id]!;
    _wallets.add((id, Wallet(level: p.level, xp: p.xp, coins: p.coins)));
  }

  /// Un vecchio nome unico che con le regole nuove non vale più: come fa la
  /// migrazione, torna vuoto e il profilo va rifatto.
  void forgetHandle(String id) {
    final old = _profiles[id]!;
    _profiles[id] = Profile(
      id: id,
      language: old.language,
      level: old.level,
      xp: old.xp,
      coins: old.coins,
    );
  }

  /// [playerId] apre una stanza dal suo telefono.
  Room openRoomAs(String playerId, AppLanguage language) => _create(playerId, language);

  /// [playerId] entra nella stanza col codice, dal suo telefono.
  Room joinAs(String playerId, String code) => _join(playerId, code);

  void leaveAs(String playerId, String roomId) => _leave(roomId, playerId);

  /// [playerId] chiede l'amicizia al giocatore.
  void requestFrom(String playerId) => _links.add(_Link(playerId, accountId, FriendStatus.pending));

  Profile? profileOf(String id) => _profiles[id];

  String get _me => auth.userId ?? (throw const OnlineException(OnlineFailure.notSignedIn));

  Profile _ready(String id) {
    final profile = _profiles[id];
    if (profile == null || !profile.isComplete) throw const OnlineException(OnlineFailure.profileIncomplete);
    return profile;
  }

  _Link? _linkBetween(String a, String b) {
    for (final link in _links) {
      if ((link.requester == a && link.addressee == b) || (link.requester == b && link.addressee == a)) return link;
    }
    return null;
  }

  Room _create(String id, AppLanguage language) {
    _ready(id);
    _leaveAll(id);
    String code;
    do {
      code = List.generate(JoinCode.length, (_) => JoinCode.alphabet[_random.nextInt(JoinCode.alphabet.length)])
          .join();
    } while (_rooms.values.any((room) => room.room.code == code && room.room.status != RoomStatus.ended));
    final room = _FakeRoom(Room(id: 'room-${_rooms.length + 1}', code: code, hostId: id, language: language));
    _rooms[room.room.id] = room;
    room.seats[id] = 1;
    room.notify(this);
    return room.room;
  }

  Room _join(String id, String typed) {
    _ready(id);
    final code = JoinCode.normalize(typed);
    final room = _rooms.values
        .where((room) => room.room.code == code && room.room.status != RoomStatus.ended)
        .firstOrNull;
    if (room == null) throw const OnlineException(OnlineFailure.roomNotFound);
    if (room.seats.containsKey(id)) return room.room;
    if (room.room.status != RoomStatus.lobby) throw const OnlineException(OnlineFailure.roomClosed);
    if (blocks.contains((room.room.hostId, id))) throw const OnlineException(OnlineFailure.notAllowed);
    if (room.seats.length + room.room.bots >= room.room.maxPlayers) throw const OnlineException(OnlineFailure.roomFull);
    final taken = room.seats.values.toSet();
    final seat = [for (var s = 1; s <= room.room.maxPlayers; s++) s].where((s) => !taken.contains(s)).firstOrNull;
    if (seat == null) throw const OnlineException(OnlineFailure.roomFull);
    _leaveAll(id);
    room.seats[id] = seat;
    room.notify(this);
    return room.room;
  }

  void _leaveAll(String id) {
    for (final room in [..._rooms.values]) {
      if (room.seats.containsKey(id)) _leave(room.room.id, id);
    }
  }

  void _leave(String roomId, String id) {
    final room = _rooms[roomId];
    if (room == null || room.seats.remove(id) == null) return;
    if ((room.room.ranked || room.room.testMatch) && room.room.status == RoomStatus.lobby) {
      // Fuori dalla sala d'attesa, senza penalità: fuori anche dalla coda.
      rankedQueue.remove(id);
      _countdown(room);
    }
    if (room.seats.isEmpty) {
      // Come il server: la stanza vuota sparisce.
      room.room = _copy(room.room, status: RoomStatus.ended);
      _rooms.remove(roomId);
      _games.remove(roomId)?.timer?.cancel();
    } else if (room.room.hostId == id) {
      room.room = _copy(room.room, hostId: room.seats.keys.first);
    }
    room.notify(this);
  }

  Room _copy(Room room, {String? hostId, RoomStatus? status}) => room.copyWith(hostId: hostId, status: status);
}

class _Link {
  final String requester;
  final String addressee;
  FriendStatus status;

  _Link(this.requester, this.addressee, this.status);
}

class _FakeRoom {
  Room room;

  /// Chi siede, nell'ordine in cui è entrato, col suo posto.
  final Map<String, int> seats = {};
  final List<StreamController<List<RoomMember>>> watchers = [];

  _FakeRoom(this.room);

  /// Come la policy del server: nella sala d'attesa della classificata
  /// ognuno vede solo sé stesso.
  List<RoomMember> members(FakeOnline online, {bool all = false}) => [
        for (final MapEntry(key: id, value: seat) in seats.entries)
          if (all || !(room.ranked || room.testMatch) || room.status != RoomStatus.lobby || id == online.auth.userId)
            RoomMember(profile: online._profiles[id]!, seat: seat),
      ]..sort((a, b) => a.seat.compareTo(b.seat));

  void notify(FakeOnline online) {
    for (final watcher in watchers) {
      watcher.add(members(online));
    }
  }
}

class FakeAuth extends OnlineAuth {
  final FakeOnline _online;
  String? _userId;

  FakeAuth._(this._online);

  @override
  String? get userId => _userId;

  @override
  bool appleAvailable = true;

  @override
  bool googleAvailable = true;

  @override
  bool steamAvailable = false;

  @override
  String? suggestedName;

  /// Se vero, la prossima finestra di accesso viene chiusa senza entrare.
  bool cancelNext = false;

  /// Se c'è, il prossimo accesso fallisce così (per esempio col provider
  /// spento sul server).
  OnlineException? failNext;

  /// Per i test: questo telefono passa all'account [id], già esistente.
  void debugSignIn(String id) => _signIn(id);

  void _signIn(String id) {
    _online._profiles.putIfAbsent(id, () => Profile(id: id));
    _userId = id;
    notifyListeners();
  }

  Future<void> _provider() async {
    await Future<void>.delayed(Duration.zero);
    if (cancelNext) {
      cancelNext = false;
      throw const OnlineException(OnlineFailure.cancelled);
    }
    if (failNext case final failure?) {
      failNext = null;
      throw failure;
    }
    _signIn(_online.accountId);
  }

  @override
  Future<void> signInWithApple() => _provider();

  @override
  Future<void> signInWithGoogle() => _provider();

  @override
  Future<void> signInWithSteam() => _provider();

  /// Le stesse regole del server: password di almeno sei caratteri, email
  /// con la chiocciola, e chi c'era già deve azzeccare la password.
  @override
  Future<void> signInWithTestAccount({required String email, required String password}) async {
    await Future<void>.delayed(Duration.zero);
    final address = email.trim().toLowerCase();
    if (!_online.emailEnabled) {
      throw const OnlineException(OnlineFailure.emailDisabled, null, 'email_provider_disabled · 400');
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(address)) {
      throw const OnlineException(OnlineFailure.invalidEmail, null, 'email_address_invalid · 400');
    }
    final existing = _online._testAccounts[address];
    if (existing != null) {
      if (existing.$1 != password) {
        throw const OnlineException(OnlineFailure.wrongPassword, null, 'invalid_credentials · 400');
      }
      _signIn(existing.$2);
      return;
    }
    if (password.length < 6) throw const OnlineException(OnlineFailure.weakPassword, null, 'weak_password · 422');
    final id = 'test-${_online._testAccounts.length + 1}';
    _online._testAccounts[address] = (password, id);
    _signIn(id);
  }

  @override
  Future<void> signOut() async {
    _userId = null;
    notifyListeners();
  }
}

class FakeProfiles implements ProfileRepository {
  final FakeOnline _online;

  FakeProfiles._(this._online);

  @override
  Future<Profile> me() async => _online._profiles[_online._me]!;

  @override
  Stream<Wallet> watchWallet() {
    final me = _online._me;
    return _online._wallets.stream.where((w) => w.$1 == me).map((w) => w.$2);
  }

  bool _taken(String handle, String me) => _online._profiles.values
      .any((profile) => profile.id != me && profile.handle?.toLowerCase() == Profile.normalizeHandle(handle));

  @override
  Future<bool> handleAvailable(String handle) async => !_taken(handle, _online._me);

  @override
  Future<Profile> setPicture(ProfilePicture picture) async {
    final me = _online._me;
    return _online._profiles[me] = _online._profiles[me]!.copyWith(picture: picture);
  }

  @override
  Future<bool> refreshSteam() async => false;

  @override
  Future<Profile> update({required String handle, AppLanguage? language}) async {
    final me = _online._me;
    handle = Profile.normalizeHandle(handle);
    // Come il database: la forma è un vincolo (23514), le parole e i nomi
    // dei bot un trigger (handle_not_allowed).
    switch (HandleRules.check(handle)) {
      case null:
        break;
      case HandleProblem.notAllowed || HandleProblem.botName:
        throw const OnlineException(OnlineFailure.handleNotAllowed);
      case _:
        throw const OnlineException(OnlineFailure.invalidHandle);
    }
    if (_taken(handle, me)) throw const OnlineException(OnlineFailure.handleTaken);
    return _online._profiles[me] = _online._profiles[me]!.copyWith(handle: handle, language: language);
  }

  /// Come `save_face`: solo le chiavi e gli id dello specchio, la pelle tra
  /// quelle conosciute, il segno salvato che resta (o uno di base).
  @override
  Future<Profile> saveFace(Map<String, String> face, {required String tone, String? mark}) async {
    final me = _online._profiles[_online._me]!;
    for (final MapEntry(:key, :value) in face.entries) {
      if (!(FaceFeatures.options[key]?.contains(value) ?? false)) throw const OnlineException(OnlineFailure.notAllowed);
    }
    if (!FakeShop._tones.contains(tone)) throw const OnlineException(OnlineFailure.notAllowed);
    final saved = me.avatar['base'];
    final cut = saved?.indexOf('_') ?? -1;
    final keep = cut > 0
        ? saved!.substring(cut + 1)
        : mark != null && initialShopCatalog.any((i) => i.slot == 'face' && i.lookId == mark && i.free)
            ? mark
            : 'clean';
    return _online._profiles[me.id] = me.copyWith(avatar: {...me.avatar, ...face, 'base': '${tone}_$keep'});
  }

  @override
  Future<List<Profile>> search(String handlePrefix) async {
    final me = _online._me;
    final prefix = handlePrefix.toLowerCase().replaceAll(RegExp('[^a-z0-9._]'), '');
    if (prefix.isEmpty) return const [];
    return [
      for (final profile in _online._profiles.values)
        if (profile.id != me && (profile.handle?.startsWith(prefix) ?? false)) profile,
    ]..sort((a, b) => a.handle!.compareTo(b.handle!));
  }

  @override
  Future<PublicProfile> publicProfile(String handleOrId) async {
    final me = _online._me;
    final key = handleOrId.toLowerCase().replaceFirst('@', '');
    final profile = _online._profiles[handleOrId] ??
        _online._profiles.values.where((p) => p.handle == key).firstOrNull;
    if (profile == null || profile.handle == null) throw const OnlineException(OnlineFailure.playerNotFound);
    if (profile.id != me && _online._blockedBetween(me, profile.id)) {
      throw const OnlineException(OnlineFailure.notAllowed);
    }
    if (!profile.publicProfile && profile.id != me) return PublicProfile(profile: profile, open: false);
    return PublicProfile(profile: profile);
  }

  @override
  Future<Profile> setPublicProfile(bool visible) async {
    final me = _online._me;
    return _online._profiles[me] = _online._profiles[me]!.copyWith(publicProfile: visible);
  }

  @override
  Future<Profile> setTableReactions(bool on) async {
    final me = _online._me;
    return _online._profiles[me] = _online._profiles[me]!.copyWith(tableReactions: on);
  }
}

class FakeFriends implements FriendsRepository {
  final FakeOnline _online;

  FakeFriends._(this._online);

  @override
  Future<List<Friendship>> list() async {
    final me = _online._me;
    return [
      for (final link in _online._links)
        if (link.status != FriendStatus.blocked && (link.requester == me || link.addressee == me))
          Friendship(
            other: _online._profiles[link.requester == me ? link.addressee : link.requester]!,
            status: link.status,
            incoming: link.addressee == me,
          ),
    ];
  }

  @override
  Future<FriendStatus> request(String profileId) async {
    final me = _online._me;
    if (profileId == me || !(_online._profiles[profileId]?.isComplete ?? false)) {
      throw const OnlineException(OnlineFailure.playerNotFound);
    }
    if (_online._blockedBetween(me, profileId)) throw const OnlineException(OnlineFailure.notAllowed);
    final link = _online._linkBetween(me, profileId);
    if (link == null) {
      _online._links.add(_Link(me, profileId, FriendStatus.pending));
      return FriendStatus.pending;
    }
    if (link.status == FriendStatus.blocked) throw const OnlineException(OnlineFailure.notAllowed);
    if (link.status == FriendStatus.pending && link.addressee == me) link.status = FriendStatus.accepted;
    return link.status;
  }

  @override
  Future<void> respond(String requesterId, {required bool accept}) async {
    final me = _online._me;
    final link = _online._links
        .where((l) => l.requester == requesterId && l.addressee == me && l.status == FriendStatus.pending)
        .firstOrNull;
    if (link == null) throw const OnlineException(OnlineFailure.requestNotFound);
    if (accept) {
      link.status = FriendStatus.accepted;
    } else {
      _online._links.remove(link);
    }
  }

  @override
  Future<void> remove(String profileId) async {
    final me = _online._me;
    _online._links.removeWhere(
      (l) =>
          (l.requester == me && l.addressee == profileId) ||
          (l.requester == profileId && l.addressee == me && l.status != FriendStatus.blocked),
    );
  }
}

/// Una segnalazione arrivata al server finto.
class FakeReport {
  final String reporter;
  final String target;
  final ReportReason reason;
  final String? note;
  final String? gameId;
  final String? messageId;

  /// La copia del messaggio segnalato, come la tiene il server.
  final String? messageText;

  const FakeReport({
    required this.reporter,
    required this.target,
    required this.reason,
    this.note,
    this.gameId,
    this.messageId,
    this.messageText,
  });
}

class FakeSafety implements SafetyRepository {
  final FakeOnline _online;

  FakeSafety._(this._online);

  @override
  Future<void> report(String targetId, ReportReason reason, {String? note, String? gameId, String? messageId}) async {
    await _online._network();
    final me = _online._me;
    if (targetId == me || !_online._profiles.containsKey(targetId)) {
      throw const OnlineException(OnlineFailure.playerNotFound);
    }
    final mine = _online.reports.where((r) => r.reporter == me).length;
    if (mine >= 10) throw const OnlineException(OnlineFailure.tooManyReports);
    final again = _online.reports.any(
      (r) => r.reporter == me && (messageId != null ? r.messageId == messageId : r.target == targetId && r.messageId == null),
    );
    if (again) return;
    final message = messageId == null
        ? null
        : _online._chat.where((m) => m.message.id == messageId && m.message.profileId == targetId).firstOrNull;
    final text = note?.trim();
    _online.reports.add(
      FakeReport(
        reporter: me,
        target: targetId,
        reason: reason,
        note: text == null || text.isEmpty ? null : text,
        gameId: gameId ?? message?.game,
        messageId: message == null ? null : messageId,
        messageText: message?.message.body,
      ),
    );
  }

  @override
  Future<List<Profile>> blocked() async {
    final me = _online._me;
    final ids = [
      for (final (blocker, blocked) in _online.blocks)
        if (blocker == me) blocked,
    ];
    BlockedPlayers.set(ids);
    return [
      for (final id in ids) ?_online._profiles[id],
    ];
  }

  @override
  Future<void> block(String profileId) async {
    final me = _online._me;
    if (profileId == me || !_online._profiles.containsKey(profileId)) {
      throw const OnlineException(OnlineFailure.playerNotFound);
    }
    _online._links.removeWhere(
      (l) => (l.requester == me && l.addressee == profileId) || (l.requester == profileId && l.addressee == me),
    );
    _online.blocks.add((me, profileId));
    BlockedPlayers.add(profileId);
    _online._notifyGame('');
  }

  @override
  Future<void> unblock(String profileId) async {
    _online.blocks.remove((_online._me, profileId));
    BlockedPlayers.remove(profileId);
    _online._notifyGame('');
  }
}

class FakeRooms implements RoomRepository {
  final FakeOnline _online;

  FakeRooms._(this._online);

  @override
  Future<Room> create(AppLanguage language) async => _online._create(_online._me, language);

  @override
  Future<Room> join(String code) async => _online._join(_online._me, code);

  @override
  Future<void> leave(String roomId, {String? newHostId, bool autoHeir = false}) async {
    final room = _online._rooms[roomId];
    final me = _online._me;
    if (room != null && room.room.hostId == me && room.seats.length > 1 && !autoHeir) {
      if (newHostId == null) throw const OnlineException(OnlineFailure.hostMustChoose);
      if (newHostId == me || !room.seats.containsKey(newHostId)) throw const OnlineException(OnlineFailure.notAllowed);
      room.room = _online._copy(room.room, hostId: newHostId);
    }
    _online._leave(roomId, me);
  }

  @override
  Future<Room?> fetch(String roomId) async {
    final room = _online._rooms[roomId];
    if (room == null || !room.seats.containsKey(_online._me)) return null;
    return room.room.copyWith(seated: room.seats.length);
  }

  @override
  Future<Room?> current() async {
    final me = _online._me;
    for (final room in _online._rooms.values) {
      if (room.seats.containsKey(me)) return room.room;
    }
    return null;
  }

  @override
  Stream<List<RoomMember>> watchMembers(String roomId) {
    final room = _online._rooms[roomId];
    late final StreamController<List<RoomMember>> controller;
    controller = StreamController<List<RoomMember>>(
      onListen: () {
        if (room == null) {
          controller.add(const []);
          return;
        }
        room.watchers.add(controller);
        controller.add(room.members(_online));
      },
      onCancel: () => room?.watchers.remove(controller),
    );
    return controller.stream;
  }
}

/// La partita di una stanza, sul server finto: le stesse righe del database
/// (tavolo, viste, intenzioni, chat) e lo stato segreto che solo il server
/// legge, mandato avanti dallo stesso [serverStep] della Edge Function.
class _FakeGameRoom {
  final String gameId;
  final Map<String, SeatPlan> seats;
  final String language;
  Map<String, Object?>? state;
  int version = 0;
  Map<String, Object?>? board;
  final Map<String, ({String profile, int version, Map<String, Object?> view})> seatViews = {};
  final List<({int id, String token, String seat, String profile, Map<String, Object?> intent})> intents = [];
  final Map<String, DateTime> lastSeen = {};

  /// Chi ha chiesto di uscire (come `game_seats.left_at`).
  final Set<String> left = {};
  String chatMode = 'closed';
  Map<String, Object?> chatSeats = const {};
  Set<String> offline = {};
  final List<String> abandons = [];
  GameTimer? timer;
  bool finished = false;

  /// Quando sono state date le carte (come `game_public.started_at`).
  DateTime? startedAt;

  _FakeGameRoom(this.gameId, this.seats, this.language);

  Map<String, Object?> rightsOf(String seat) => (chatSeats[seat] as Map?)?.cast<String, Object?>() ?? const {};
}

/// La partita online sul server finto, vista dall'account [userId]: ogni
/// chiamata controlla quello che controllerebbero le policy e le funzioni
/// del database, e ognuno riceve solo le righe che potrebbe leggere. Il
/// server gira qui dentro, con l'orologio [FakeOnline.clock].
class FakeGame implements GameBackend {
  final FakeOnline _online;
  final String? Function() _user;

  FakeGame._(this._online, this._user);

  String get _me => _user() ?? (throw const OnlineException(OnlineFailure.notSignedIn));

  _FakeRoom _room(String roomId) =>
      _online._rooms[roomId] ?? (throw const OnlineException(OnlineFailure.roomNotFound));

  bool _member(String roomId, String id) => _online._rooms[roomId]?.seats.containsKey(id) ?? false;

  String? _seatOf(_FakeGameRoom game, String profile) =>
      game.seats.values.where((plan) => plan.profileId == profile).firstOrNull?.seat;

  /// Solo per i test: mette i bot in una stanza come se ci fossero già.
  /// Il server vero non lo lascia fare a nessun telefono.
  Future<void> setBots(String roomId, int count) async {
    await _online._network();
    final room = _room(roomId);
    if (room.room.hostId != _me || room.room.ranked || room.room.testMatch) {
      throw const OnlineException(OnlineFailure.notAllowed);
    }
    if (room.room.status != RoomStatus.lobby) throw const OnlineException(OnlineFailure.roomClosed);
    if (count < 0 || count + room.seats.length > room.room.maxPlayers) {
      throw const OnlineException(OnlineFailure.roomFull);
    }
    room.room = room.room.copyWith(bots: count);
    room.notify(_online);
  }

  @override
  Future<void> startGame(String roomId) async {
    await _online._network();
    final me = _me;
    final room = _room(roomId);
    if (room.room.hostId != me) throw const OnlineException(OnlineFailure.notAllowed);
    if (room.room.status != RoomStatus.lobby) throw const OnlineException(OnlineFailure.roomClosed);
    if (room.room.ranked || room.room.testMatch) throw const OnlineException(OnlineFailure.notAllowed);
    final people = room.seats.length;
    // Come il server nel periodo di prova: bastano due persone, i posti
    // vuoti li prendono i bot.
    if (_online.friendsTestBots) {
      if (people < 2) throw const OnlineException(OnlineFailure.notAllowed);
      final size = min(room.room.maxPlayers, _online.friendsTestSize ?? room.room.maxPlayers);
      room.room = room.room.copyWith(bots: max(0, size - people));
    }
    final total = people + room.room.bots;
    if (total < 4 || total > room.room.maxPlayers) throw const OnlineException(OnlineFailure.notAllowed);
    _begin(roomId);
  }

  void _begin(String roomId) {
    final room = _room(roomId);
    // Come il server: le persone nell'ordine dei posti, poi i bot.
    final people = room.members(_online, all: true);
    final seats = <String, SeatPlan>{};
    for (final (index, member) in people.indexed) {
      final seat = 's${index + 1}';
      seats[seat] = SeatPlan(seat: seat, profileId: member.profile.id, name: member.profile.name);
    }
    for (var i = 0; i < room.room.bots; i++) {
      final seat = 's${people.length + i + 1}';
      seats[seat] = SeatPlan(seat: seat, profileId: null, name: botName(i));
    }
    _online._games.remove(roomId)?.timer?.cancel();
    _online._chat.removeWhere((m) => m.room == roomId && m.message.channel != ChatChannel.lobby);
    final game = _online._games[roomId] =
        _FakeGameRoom('game-${++_online._gameIds}', seats, room.room.language.name)
          ..startedAt = _online.clock.now();
    for (final plan in seats.values) {
      if (plan.profileId != null) game.lastSeen[plan.seat] = _online.clock.now();
    }
    room.room = room.room.copyWith(status: RoomStatus.playing);
    room.notify(_online);
    _online._wake(roomId);
  }

  GameFeed _feedFor(String roomId, String me) {
    final game = _online._games[roomId];
    if (game == null || !_member(roomId, me)) return const GameFeed();
    final board = game.board;
    final mine = [
      for (final MapEntry(key: seat, value: row) in game.seatViews.entries)
        if (row.profile == me) SeatFrame(seat, row.version, _wire(row.view)),
    ];
    return GameFeed(
      board: board == null ? null : PublicFrame(game.version, _wire(board)),
      seat: mine.firstOrNull,
    );
  }

  @override
  Stream<GameFeed> watchGame(String roomId) {
    final me = _me;
    late final StreamController<GameFeed> controller;
    void push() {
      if (controller.isClosed || _online.unreachable.contains(me)) return;
      final feed = _feedFor(roomId, me);
      _online.deliveries.add((user: me, feed: feed));
      controller.add(feed);
    }

    controller = StreamController<GameFeed>(
      onListen: () {
        _online._gameWatchers.add(push);
        scheduleMicrotask(push);
      },
      onCancel: () => _online._gameWatchers.remove(push),
    );
    return controller.stream;
  }

  Future<String> _submit(String roomId, Map<String, Object?> json) async {
    await _online._network();
    final me = _me;
    final game = _online._games[roomId];
    final room = _online._rooms[roomId];
    if (game == null || room == null || !_member(roomId, me) || room.room.status != RoomStatus.playing) {
      throw const OnlineException(OnlineFailure.notAllowed);
    }
    final seat = _seatOf(game, me);
    if (seat == null) throw const OnlineException(OnlineFailure.notAllowed);
    if (json['seat'] != seat) throw const OnlineException(OnlineFailure.notAllowed, null, 'not_your_seat');
    if (game.intents.where((i) => i.profile == me).length >= 20) {
      throw const OnlineException(OnlineFailure.notAllowed, null, 'too_many_intents');
    }
    // The order stays on the server; the phone gets a random token.
    final token = _online._chatId();
    game.intents.add((id: ++_online._intentIds, token: token, seat: seat, profile: me, intent: _wire(json)));
    game.lastSeen[seat] = _online.clock.now();
    _online._wake(roomId);
    return token;
  }

  @override
  Future<String> sendIntent(String roomId, PlayerIntent intent) => _submit(roomId, intent.toJson());

  @override
  Future<void> sendAck(String roomId, String seat, String stage) =>
      _submit(roomId, {'type': 'ack', 'seat': seat, 'stage': stage});

  /// Solo per i test: manda un'intenzione così com'è, come farebbe un
  /// client modificato. Il server controlla comunque il posto.
  Future<String> sendRaw(String roomId, Map<String, Object?> json) => _submit(roomId, json);

  @override
  Future<void> leaveGame(String roomId) async {
    await _online._network();
    final me = _me;
    final game = _online._games[roomId];
    final seat = game == null ? null : _seatOf(game, me);
    if (game == null || seat == null) return;
    game.lastSeen[seat] = DateTime.fromMillisecondsSinceEpoch(0);
    game.left.add(seat);
    _online._wake(roomId);
  }

  @override
  Future<int> ping(String roomId) async {
    await _online._network();
    final me = _me;
    if (_online.unreachable.contains(me)) throw const OnlineException(OnlineFailure.network);
    if (!_member(roomId, me)) throw const OnlineException(OnlineFailure.notAllowed);
    final game = _online._games[roomId];
    final seat = game == null ? null : _seatOf(game, me);
    if (game != null && seat != null) {
      game.lastSeen[seat] = _online.clock.now();
      if (game.offline.contains(seat)) _online._wake(roomId);
    }
    return _online.clock.now().millisecondsSinceEpoch;
  }

  @override
  Future<void> resume() async {
    await _online._network();
    if (_online.unreachable.contains(_me)) throw const OnlineException(OnlineFailure.network);
    _online.resumes++;
  }

  @override
  Future<String> sendChat(String roomId, ChatChannel channel, String body) async {
    await _online._network();
    final me = _me;
    final text = body.trim();
    if (!_member(roomId, me)) throw const OnlineException(OnlineFailure.notAllowed);
    if (text.isEmpty || text.length > 300) throw const OnlineException(OnlineFailure.chatClosed);
    final now = _online.clock.now();
    final recent = _online._chat.where(
      (m) =>
          (m.message.profileId == me || _online._jailers[m.message.id] == me) &&
          now.difference(m.message.at) < const Duration(seconds: 3),
    );
    if (recent.length >= 3) throw const OnlineException(OnlineFailure.tooManyMessages);
    if (HandleRules.offensive(text)) throw const OnlineException(OnlineFailure.messageBlocked);
    final room = _room(roomId);
    String? seat;
    String? gameId;
    String? thread;
    var jailer = false;
    var name = _online._profiles[me]!.name;
    if (channel == ChatChannel.lobby) {
      if (room.room.status != RoomStatus.lobby) throw const OnlineException(OnlineFailure.chatClosed);
    } else {
      final game = _online._games[roomId];
      seat = game == null ? null : _seatOf(game, me);
      if (game == null || seat == null || room.room.status != RoomStatus.playing) {
        throw const OnlineException(OnlineFailure.chatClosed);
      }
      final rights = game.rightsOf(seat);
      if (rights['alive'] == false) throw const OnlineException(OnlineFailure.chatClosed);
      final allowed = switch (channel) {
        ChatChannel.day => game.chatMode == 'day' && rights['silenced'] != true,
        // Di notte la famiglia; di giorno solo se c'è un Compare vivo.
        ChatChannel.family => rights['family'] == true &&
            (game.chatMode == 'night' || (game.chatMode == 'day' && rights['familyDay'] == true)),
        // La cella: il Carceriere e il prigioniero, la notte della cella.
        ChatChannel.jail => game.chatMode == 'night' && rights['jail'] is String,
        ChatChannel.lobby || ChatChannel.event => false,
      };
      if (!allowed) throw const OnlineException(OnlineFailure.chatClosed);
      gameId = game.gameId;
      name = game.seats[seat]!.name;
      if (channel == ChatChannel.jail) {
        thread = rights['jail'] as String;
        // Il Carceriere resta senza nome: niente profilo, posto, nome.
        if (rights['jailer'] == true) {
          jailer = true;
          seat = null;
          name = '';
        }
      }
    }
    // The order within the channel only, as on the server.
    final n = _online._chat
            .where((m) => m.room == roomId && m.game == gameId && m.message.channel == channel && m.message.thread == thread)
            .length +
        1;
    final id = _online._chatId();
    _online._chat.add((
      room: roomId,
      game: gameId,
      message: ChatMessage(
        id: id,
        n: n,
        channel: channel,
        profileId: jailer ? '' : me,
        seat: seat,
        name: name,
        body: text,
        at: now,
        thread: thread,
      ),
    ));
    if (jailer) _online._jailers[id] = me;
    _online._notifyGame(roomId);
    return id;
  }

  /// Come la policy di game_chat: stanza e piazza per chi è nella stanza,
  /// la famiglia solo per i suoi vivi, nella partita in corso.
  List<ChatMessage> _chatFor(String roomId, String me) {
    if (!_member(roomId, me)) return const [];
    final game = _online._games[roomId];
    final seat = game == null ? null : _seatOf(game, me);
    final rights = seat == null ? const <String, Object?>{} : game!.rightsOf(seat);
    final family = rights['family'] == true && rights['alive'] != false;
    final jail = rights['jail'] as String?;
    return [
      for (final m in _online._chat)
        if (m.room == roomId &&
            !_online.blocks.contains((me, m.message.profileId)) &&
            (m.message.channel != ChatChannel.family || (family && m.game == game?.gameId)) &&
            (m.message.channel != ChatChannel.jail || (jail != null && m.message.thread == jail && m.game == game?.gameId)))
          m.message,
      for (final e in _online._events)
        if (e.room == roomId && e.game == game?.gameId && (e.to == null || e.to == me)) e.message,
    ]..sort(ChatMessage.byTime);
  }

  @override
  Stream<List<ChatMessage>> watchChat(String roomId) {
    final me = _me;
    late final StreamController<List<ChatMessage>> controller;
    void push() {
      if (!controller.isClosed) controller.add(_chatFor(roomId, me));
    }

    controller = StreamController<List<ChatMessage>>(
      onListen: () {
        _online._gameWatchers.add(push);
        scheduleMicrotask(push);
      },
      onCancel: () => _online._gameWatchers.remove(push),
    );
    return controller.stream;
  }
}

extension on FakeOnline {
  /// Come pg_net che sveglia la Edge Function: poco dopo, non durante la
  /// chiamata.
  void _wake(String roomId) => scheduleMicrotask(() => _serve(roomId));

  /// Un passo del server su questa partita, come la Edge Function: lo stato
  /// segreto, le intenzioni, chi si fa sentire; poi si salva tutto come
  /// `internal.game_commit` e ci si dà appuntamento al prossimo momento.
  void _serve(String roomId) {
    final game = _games[roomId];
    final room = _rooms[roomId];
    if (game == null || room == null || game.finished) return;
    game.timer?.cancel();
    game.timer = null;
    final now = clock.now();
    final out = serverStep(
      _wire({
        'state': game.state,
        'seats': [for (final plan in game.seats.values) plan.toJson()],
        'language': game.language,
        'now': now.millisecondsSinceEpoch,
        'intents': [
          for (final i in game.intents) {'id': i.id, 'token': i.token, 'seat': i.seat, 'intent': i.intent},
        ],
        'seen': trackPresence
            ? {for (final MapEntry(:key, :value) in game.lastSeen.entries) key: value.millisecondsSinceEpoch}
            : null,
        'seed': _random.nextInt(1 << 30),
      }),
      pacing: pacing,
    );
    final last = out['lastIntent'] as int?;
    if (last != null) game.intents.removeWhere((i) => i.id <= last);
    game.state = out['state'] as Map<String, Object?>;
    if (out['changed'] == true) {
      game.version = out['version'] as int;
      final board = out['board'] as Map<String, Object?>;
      game.board = board;
      for (final MapEntry(key: seat, value: view) in (out['seatViews'] as Map<String, Object?>).entries) {
        final profile = game.seats[seat]?.profileId;
        // La vista va a chi siede a quel posto, qualunque cosa dica il passo.
        if (profile == null) continue;
        game.seatViews[seat] = (profile: profile, version: game.version, view: view as Map<String, Object?>);
      }
      final chat = out['chat'] as Map<String, Object?>;
      game.chatMode = chat['mode'] as String;
      game.chatSeats = (chat['seats'] as Map).cast<String, Object?>();
      game.offline = {for (final seat in board['offline'] as List<Object?>) seat as String};
      game.abandons.addAll((out['departed'] as List<Object?>).cast<String>());
      // As game_commit: public lines for all, private ones for the person at
      // that seat, none for a bot; earlier games' lines go.
      _events.removeWhere((e) => e.room == roomId && e.game != game.gameId);
      final counts = <String?, int>{};
      for (final event in (out['events'] as List<Object?>? ?? const []).cast<Map<String, Object?>>()) {
        final seat = event['to'] as String?;
        final to = seat == null ? null : game.seats[seat]?.profileId;
        if (seat != null && to == null) continue;
        final n = counts[to] = (counts[to] ?? 0) + 1;
        _events.add((
          room: roomId,
          game: game.gameId,
          to: to,
          message: ChatMessage.event(
            kind: event['kind'] as String,
            data: (event['data'] as Map).cast<String, Object?>(),
            private: to != null,
            n: n,
            at: now,
          ),
        ));
      }
      published++;
      if (out['finished'] == true) {
        game.finished = true;
        if (out['result'] case final Map<String, Object?> result) _settle(room.room, game, result);
        room.room = room.room.copyWith(status: RoomStatus.lobby);
        room.notify(this);
      }
      _notifyGame(roomId);
    }
    final due = out['nextDue'] as int?;
    if (due != null && !game.finished) {
      final wait = DateTime.fromMillisecondsSinceEpoch(due).difference(clock.now());
      game.timer = clock.schedule(wait.isNegative ? Duration.zero : wait, () => _serve(roomId));
    }
  }
}

Map<String, Object?> _wire(Map<String, Object?> json) => jsonDecode(jsonEncode(json)) as Map<String, Object?>;

/// La bottega finta, con le stesse regole delle funzioni del server.
class FakeShop implements ShopRepository {
  final FakeOnline _online;

  /// Il catalogo e la vetrina: quelli di partenza, o altri per un test.
  List<ShopItem> items = initialShopCatalog;
  List<ShopFeature> features = initialShopFeatured;
  List<ShopBundle> packs = initialShopBundles;

  final Map<String, Set<String>> _owned = {};

  FakeShop._(this._online);

  static const _tones = ['porcelain', 'rose', 'olive', 'tan', 'umber', 'ebony', 'ivory', 'honey', 'sienna', 'espresso'];

  /// Quello che possiede un account (per i test).
  Set<String> ownedBy(String id) => {...?_owned[id]};

  ShopItem? _item(String id) => items.where((item) => item.id == id).firstOrNull;

  Profile _me() {
    final id = _online._me;
    return _online._profiles[id] ?? (throw const OnlineException(OnlineFailure.notSignedIn));
  }

  @override
  Future<List<ShopItem>> catalog() async => [...items]..sort((a, b) => a.sort.compareTo(b.sort));

  @override
  Future<List<ShopFeature>> featured() async => [...features]..sort((a, b) => a.sort.compareTo(b.sort));

  @override
  Future<Set<String>> owned() async => ownedBy(_me().id);

  @override
  Future<Profile> buy(String itemId) async {
    final me = _me();
    final item = _item(itemId) ?? (throw const OnlineException(OnlineFailure.itemNotFound));
    if (item.free || (_owned[me.id]?.contains(item.id) ?? false)) {
      throw const OnlineException(OnlineFailure.alreadyOwned);
    }
    if (me.coins < item.price) throw const OnlineException(OnlineFailure.notEnoughCoins);
    (_owned[me.id] ??= {}).add(item.id);
    final bought = _online._profiles[me.id] = me.copyWith(coins: me.coins - item.price);
    _online._pushWallet(me.id);
    return bought;
  }

  @override
  Future<List<ShopBundle>> bundles() async => [...packs]..sort((a, b) => a.sort.compareTo(b.sort));

  @override
  Future<Profile> buyBundle(String bundleId) async {
    final me = _me();
    final bundle = packs.where((b) => b.id == bundleId).firstOrNull ?? (throw const OnlineException(OnlineFailure.itemNotFound));
    final catalog = {for (final item in items) item.id: item};
    if (bundle.itemIds.any((id) => !catalog.containsKey(id))) throw const OnlineException(OnlineFailure.itemNotFound);
    final mine = _owned[me.id] ?? const <String>{};
    final missing = bundle.missing(catalog, mine);
    if (missing.isEmpty) throw const OnlineException(OnlineFailure.alreadyOwned);
    final price = bundle.price(catalog, mine);
    if (me.coins < price) throw const OnlineException(OnlineFailure.notEnoughCoins);
    (_owned[me.id] ??= {}).addAll(missing.map((item) => item.id));
    final bought = _online._profiles[me.id] = me.copyWith(coins: me.coins - price);
    _online._pushWallet(me.id);
    return bought;
  }

  /// Il look mandato dall'app senza i pezzi che non si possiedono, come
  /// fa il server (`_owned_look`).
  Map<String, String> _ownedOnly(String me, Map<String, String> look) {
    bool owns(String id) => (_item(id)?.free ?? false) || (_owned[me]?.contains(id) ?? false);
    final slots = {for (final item in items) item.slot};
    return {
      for (final MapEntry(:key, :value) in look.entries)
        if (switch (key) {
          'heldL' || 'heldR' => owns('held.$value'),
          'faceExtras' => value.split('+').every((t) => owns('faceExtras.$t')),
          'base' => owns('face.${value.substring(value.indexOf('_') + 1)}'),
          _ when slots.contains(key) => owns('$key.$value'),
          _ => true,
        })
          key: value,
    };
  }

  String? _tone(Map<String, String> avatar, String? tone) {
    final saved = avatar['base']?.split('_').first;
    if (_tones.contains(saved)) return saved;
    return _tones.contains(tone) ? tone : null;
  }

  @override
  Future<Profile> equip(String itemId, {String? tone, Map<String, String>? current, String? hand}) async {
    final me = _me();
    final item = _item(itemId) ?? (throw const OnlineException(OnlineFailure.itemNotFound));
    if (!item.free && !(_owned[me.id]?.contains(item.id) ?? false)) throw const OnlineException(OnlineFailure.notOwned);
    // Come il server: sotto il salvato, solo i pezzi posseduti.
    final avatar = {..._ownedOnly(me.id, current ?? const {}), ...me.avatar};
    if (item.slot == 'face') {
      final skin = _tone(avatar, tone) ?? (throw const OnlineException(OnlineFailure.itemNotFound));
      avatar['base'] = '${skin}_${item.lookId}';
    } else if (item.slot == 'held') {
      final held = HeldItem.values.firstWhere((h) => h.name == item.lookId);
      if (held == HeldItem.none || held.twoHanded) {
        avatar['heldL'] = held.name;
        avatar['heldR'] = 'none';
      } else {
        final (key, other) = hand == 'left' ? ('heldL', 'heldR') : ('heldR', 'heldL');
        if (HeldItem.values.where((h) => h.name == avatar[other]).firstOrNull?.twoHanded ?? false) avatar[other] = 'none';
        avatar[key] = held.name;
      }
    } else if (item.slot == 'faceExtras') {
      final worn = AvatarLook.parseExtras(avatar['faceExtras'] ?? 'none');
      final extra = FaceExtra.values.where((e) => e.name == item.lookId).firstOrNull;
      avatar['faceExtras'] = extra == null ? 'none' : AvatarLook.extrasId(AvatarLook.toggledExtras(worn, extra));
    } else {
      avatar[item.slot] = item.lookId;
    }
    return _online._profiles[me.id] = me.copyWith(avatar: avatar);
  }

  @override
  Future<Profile> unequip(String slot, {String? tone, Map<String, String>? current}) async {
    final me = _me();
    final avatar = {..._ownedOnly(me.id, current ?? const {}), ...me.avatar};
    if (slot == 'face') {
      final skin = _tone(avatar, tone);
      if (skin != null) avatar['base'] = '${skin}_clean';
    } else if (slot == 'held') {
      avatar
        ..remove('heldL')
        ..remove('heldR');
    } else {
      avatar.remove(slot);
    }
    return _online._profiles[me.id] = me.copyWith(avatar: avatar);
  }
}

/// «Collega account» finto: il browser non c'è, si collega e basta.
class FakeAccountLinks implements AccountLinkRepository {
  final FakeOnline _online;

  FakeAccountLinks._(this._online);

  @override
  List<LinkProvider> providers = const [LinkProvider.steam];

  /// Quello che si è collegato, per i test: (chi, che cosa).
  final List<(String, LinkProvider)> linked = [];

  /// Se c'è, il prossimo collegamento fallisce così.
  OnlineException? failNext;

  @override
  Future<bool> link(LinkProvider provider) async {
    await _online._network();
    final me = _online.auth.userId ?? (throw const OnlineException(OnlineFailure.notSignedIn));
    if (failNext case final failure?) {
      failNext = null;
      throw failure;
    }
    linked.add((me, provider));
    return false;
  }
}

/// L'account finto: esporta quello che il server finto sa di chi è entrato,
/// e lo dimentica del tutto quando lo si elimina.
class FakeAccount implements AccountRepository {
  final FakeOnline _online;

  FakeAccount._(this._online);

  /// Gli account eliminati, per i test.
  final List<String> deleted = [];

  /// Se c'è, la prossima chiamata fallisce così.
  OnlineException? failNext;

  String _me() => _online.auth.userId ?? (throw const OnlineException(OnlineFailure.notSignedIn));

  void _maybeFail() {
    if (failNext case final failure?) {
      failNext = null;
      throw failure;
    }
  }

  @override
  Future<Map<String, dynamic>> exportData() async {
    await _online._network();
    _maybeFail();
    final me = _me();
    return {
      'account_id': me,
      'profile': {'id': me, 'handle': _online._profiles[me]?.handle},
      'friendships': [
        for (final link in _online._links)
          if (link.requester == me || link.addressee == me) {"requester": link.requester, "addressee": link.addressee},
      ],
      'inventory': <Object>[],
      'coin_ledger': <Object>[],
    };
  }

  @override
  Future<void> deleteAccount() async {
    await _online._network();
    _maybeFail();
    final me = _me();
    _online._profiles.remove(me);
    _online._links.removeWhere((link) => link.requester == me || link.addressee == me);
    deleted.add(me);
    await _online.auth.signOut();
  }
}

extension FakeRankedServer on FakeOnline {
  /// Come `internal.settle_input` + `obertaSettle` + `internal.record_match`.
  void _settle(Room room, _FakeGameRoom game, Map<String, Object?> result) {
    final seats = (result['seats'] as Map).cast<String, Object?>();
    final today = clock.now().toUtc();
    bool sameDay(DateTime d) => d.year == today.year && d.month == today.month && d.day == today.day;
    final rows = [
      for (final MapEntry(key: seat, value: raw) in seats.entries)
        if (game.seats[seat]?.profileId case final id?)
          () {
            final r = (raw as Map).cast<String, Object?>();
            final profile = _profiles[id]!;
            final past = history[id] ?? const [];
            final rating = ratings[(id, room.language)] ?? Rating.initial;
            return {
              ...r,
              'profile': id,
              'seat': seat,
              'level': profile.level,
              'xp': profile.xp,
              'mu': rating.mu,
              'sigma': rating.sigma,
              'wonToday': past.any((m) => m.won && sameDay(_playedAt[m]!)),
              'friendsGamesToday': past.where((m) => !m.ranked && sameDay(_playedAt[m]!)).length,
              'leftDead': game.left.contains(seat) && r['abandoned'] != true,
              'missions': [
                for (final m in progress._missionsOf(id))
                  if (!m.completed)
                    {
                      'id': m.id, 'cadence': m.cadence, 'period': 'now', 'metric': m.metric,
                      'target': m.target, 'progress': m.progress, 'xp': m.xp, 'coins': m.coins,
                    },
              ],
              'stats': progress.stats[id] ?? const <String, int>{},
              'achieved': [...?progress.unlocked[id]?.keys],
            };
          }(),
    ];
    final out = settleJson({'ranked': room.ranked, 'humans': rows.length, 'seats': rows});
    for (final p in (out['players'] as List).cast<Map<String, Object?>>()) {
      final id = p['profile'] as String;
      final profile = _profiles[id]!;
      _profiles[id] = profile.copyWith(level: p['level'] as int, xp: p['xp'] as int, coins: profile.coins + (p['coins'] as int));
      progress._record(id, game.gameId, p);
      _pushWallet(id);
      if (room.ranked) ratings[(id, room.language)] = Rating(p['mu'] as double, p['sigma'] as double);
      final match = MatchResult(
        gameId: game.gameId,
        ranked: room.ranked,
        testMatch: room.testMatch,
        won: p['won'] == true,
        abandoned: p['abandoned'] == true,
        afk: p['afk'] == true,
        role: p['role'] as String,
        xpGained: p['xpGained'] as int,
        levelBefore: p['levelBefore'] as int,
        levelAfter: p['level'] as int,
        coinsGained: p['coins'] as int,
        ratingDelta: (p['ratingDelta'] as num?)?.toDouble(),
        ordinalAfter: room.ranked ? (p['mu'] as double) - 3 * (p['sigma'] as double) : null,
        team: p['team'] as String? ?? '',
        survived: p['survived'] == true,
        durationSeconds: switch (game.startedAt) {
          final start? => max(0, clock.now().difference(start).inSeconds),
          null => null,
        },
      );
      _playedAt[match] = clock.now().toUtc();
      (history[id] ??= []).add(match);
    }
  }

  /// Quante persone fanno pronta una sala d'attesa: il tavolo intero, o col
  /// flag di prova [rankedTestHumans].
  int _need(bool test) => test ? min(rankedSize, rankedTestHumans ?? 1) : rankedSize;

  void _countdown(_FakeRoom lobby) {
    final ready = lobby.seats.length >= _need(lobby.room.testMatch);
    final startsAt = lobby.room.startsAt;
    if (ready && startsAt == null) {
      lobby.room = lobby.room.copyWith(startsAt: clock.now().add(rankedCountdown));
    } else if (!ready && startsAt != null) {
      lobby.room = lobby.room.copyWith(startsAt: null);
    }
  }

  bool _inRankedLobby(_FakeRoom r) => (r.room.ranked || r.room.testMatch) && r.room.status == RoomStatus.lobby;

  /// Fa sedere chi è in coda: la sala d'attesa più piena della sua lingua, o
  /// una nuova.
  void _place(String id) {
    final (language, _) = rankedQueue[id]!;
    if (_rooms.values.any((r) => _inRankedLobby(r) && r.seats.containsKey(id))) return;
    final test = rankedTestHumans != null;
    final lobbies = _rooms.values
        .where((r) =>
            _inRankedLobby(r) && r.room.testMatch == test && r.room.language == language && r.seats.length < rankedSize)
        .toList()
      ..sort((a, b) => b.seats.length.compareTo(a.seats.length));
    var lobby = lobbies.firstOrNull;
    if (lobby == null) {
      final n = ++_rankedIds;
      lobby = _FakeRoom(Room(
        id: 'ranked-$n',
        code: 'RANK${n.toString().padLeft(2, '0')}',
        hostId: id,
        language: language,
        maxPlayers: rankedSize,
        ranked: !test,
        testMatch: test,
      ));
      _rooms[lobby.room.id] = lobby;
    }
    final taken = lobby.seats.values.toSet();
    lobby.seats[id] = [for (var s = 1; s <= rankedSize; s++) s].firstWhere((s) => !taken.contains(s));
    _countdown(lobby);
    lobby.notify(this);
  }

  /// Il giro del matcher: chi aspetta si siede, e le sale col conto alla
  /// rovescia finito cominciano la partita (bot solo nelle prove).
  void tickRanked() {
    for (final id in [...rankedQueue.keys]) {
      _place(id);
    }
    final now = clock.now();
    for (final lobby in [..._rooms.values]) {
      final startsAt = lobby.room.startsAt;
      if (!_inRankedLobby(lobby) || startsAt == null || startsAt.isAfter(now)) continue;
      if (lobby.seats.length < _need(lobby.room.testMatch)) {
        lobby.room = lobby.room.copyWith(startsAt: null);
        continue;
      }
      final players = [...lobby.seats.keys];
      for (final id in players) {
        rankedQueue.remove(id);
      }
      lobby.room = lobby.room.copyWith(
        hostId: players.first,
        bots: lobby.room.testMatch ? rankedSize - players.length : 0,
        startsAt: null,
      );
      gameAs(players.first)._begin(lobby.room.id);
      lobby.notify(this);
    }
  }
}

final Expando<DateTime> _playedAt = Expando();

/// La classificata finta, con le regole del server (in piccolo).
class FakeRanked implements RankedRepository {
  final FakeOnline _online;

  FakeRanked._(this._online);

  String get _me => _online.auth.userId ?? (throw const OnlineException(OnlineFailure.notSignedIn));

  @override
  Future<RankedStatus> status() async {
    await _online._network();
    final me = _me;
    final queued = _online.rankedQueue[me];
    final room = _online._rooms.values
        .where((r) => (r.room.ranked || r.room.testMatch) && r.room.status != RoomStatus.ended && r.seats.containsKey(me))
        .lastOrNull;
    final cooldown = _online.cooldowns[me];
    return RankedStatus(
      queued: queued != null,
      language: queued?.$1,
      since: queued?.$2,
      waiting: queued == null ? 0 : _online.rankedQueue.values.where((q) => q.$1 == queued.$1).length,
      estimate: queued == null ? null : const Duration(seconds: 45),
      roomId: room?.room.id,
      seated: room?.seats.length ?? 0,
      testMatch: room?.room.testMatch ?? false,
      cooldownUntil: cooldown != null && cooldown.isAfter(_online.clock.now()) ? cooldown : null,
      tutorials: _online.tutorialsOf(me),
    );
  }

  @override
  Future<Set<String>> completeTutorial(String faction) async {
    await _online._network();
    final me = _me;
    _online._ready(me);
    if (!FakeOnline.tutorialFactions.contains(faction)) throw const OnlineException(OnlineFailure.notAllowed);
    (_online.tutorials[me] ??= {}).add(faction);
    return _online.tutorialsOf(me);
  }

  @override
  Future<Set<String>> skipTutorials() async {
    await _online._network();
    final me = _me;
    _online._ready(me);
    (_online.tutorials[me] ??= {}).add(RankedStatus.skipTutorialsId);
    return _online.tutorialsOf(me);
  }

  @override
  Future<RankedStatus> enqueue(AppLanguage language) async {
    await _online._network();
    final me = _me;
    _online._ready(me);
    final tutorials = _online.tutorialsOf(me);
    if (!tutorials.contains(RankedStatus.skipTutorialsId) && !tutorials.containsAll(FakeOnline.tutorialFactions)) {
      throw const OnlineException(OnlineFailure.tutorialsRequired);
    }
    if (_online.cooldowns[me]?.isAfter(_online.clock.now()) ?? false) {
      throw const OnlineException(OnlineFailure.rankedCooldown);
    }
    if (_online._rooms.values.any((r) => r.room.status == RoomStatus.playing && r.seats.containsKey(me))) {
      throw const OnlineException(OnlineFailure.alreadyInGame);
    }
    final old = _online.rankedQueue[me];
    if (old == null || old.$1 != language) _online._leaveAll(me);
    _online.rankedQueue[me] = (language, old != null && old.$1 == language ? old.$2 : _online.clock.now());
    _online.tickRanked();
    return status();
  }

  @override
  Future<void> leave() async {
    await _online._network();
    final me = _me;
    _online.rankedQueue.remove(me);
    for (final r in [..._online._rooms.values]) {
      if (_online._inRankedLobby(r)) _online._leave(r.room.id, me);
    }
  }

  @override
  Future<OnlineCounts> counts() async {
    await _online._network();
    final seated = {for (final r in _online._rooms.values) if (r.room.status != RoomStatus.ended) ...r.seats.keys};
    return OnlineCounts(
      online: _online.extraOnline + {...seated, ..._online.rankedQueue.keys}.length,
      queued: {
        for (final language in AppLanguage.values)
          language: _online.rankedQueue.values.where((q) => q.$1 == language).length,
      },
    );
  }

  @override
  Future<Map<AppLanguage, Rating>> ratings() async => {
        for (final MapEntry(:key, :value) in _online.ratings.entries)
          if (key.$1 == _me) key.$2: value,
      };

  @override
  Future<MatchResult?> lastResult({DateTime? since}) async => _online.history[_me]?.lastOrNull;

  @override
  Future<List<MatchResult>> history({int limit = 5}) async =>
      (_online.history[_me] ?? const []).reversed.take(limit).toList();

  @override
  Future<PlayerStats> stats() async {
    await _online._network();
    final me = _me;
    final past = _online.history[me] ?? const <MatchResult>[];
    return PlayerStats(
      all: StatsSlice.of(past),
      real: StatsSlice.of(past.where((m) => !m.testMatch)),
      tests: past.where((m) => m.testMatch).length,
      counters: {
        for (final MapEntry(:key, :value) in (_online.progress.stats[me] ?? const <String, int>{}).entries)
          if (!key.startsWith('role_win:')) key: value,
      },
    );
  }
}

/// Come `internal.active_sessions`: un dispositivo attivo per account, e
/// l'ultimo che ha chiesto di giocare. Più telefoni finti possono usare lo
/// stesso server con [FakeDeviceSessions.withAccount].
class FakeDeviceSessions implements DeviceSessionRepository {
  final String? Function() _account;
  final _FakeSessionTable _table;

  FakeDeviceSessions(String? Function() account) : this._(account, _FakeSessionTable());

  FakeDeviceSessions._(this._account, this._table);

  /// Un altro dispositivo sullo stesso server.
  FakeDeviceSessions withAccount(String? Function() account) => FakeDeviceSessions._(account, _table);

  /// La sessione attiva dell'account, come la guarda il server.
  String? activeSession(String profileId) => _table.rows[profileId]?.session;

  String get _me => _account() ?? (throw const OnlineException(OnlineFailure.notSignedIn));

  @override
  Future<SessionAnswer> claim(String sessionId, String deviceLabel, {bool force = false}) async {
    final me = _me;
    final row = _table.rows[me];
    if (row == null || row.session == sessionId || force) {
      _table.rows[me] = _FakeSession(sessionId, deviceLabel);
    } else {
      row.contender = (sessionId, deviceLabel);
    }
    _table.changes.add(me);
    return status(sessionId);
  }

  @override
  Future<SessionAnswer> status(String sessionId) async {
    final row = _table.rows[_me];
    if (row == null) return const SessionAnswer(active: false);
    final active = row.session == sessionId;
    return SessionAnswer(
      active: active,
      activeLabel: row.label,
      waiting: !active && row.contender?.$1 == sessionId,
      contenderLabel: active ? row.contender?.$2 : null,
    );
  }

  /// Come il controllo prima di ogni scrittura: `other_device` se non tocca a lei.
  void checkWrite(String sessionId) {
    final row = _table.rows[_me];
    if (row != null && row.session != sessionId) throw const OnlineException(OnlineFailure.otherDevice);
  }

  @override
  Stream<void> changes() {
    final me = _account();
    return _table.changes.stream.where((id) => id == me);
  }
}

class _FakeSessionTable {
  final Map<String, _FakeSession> rows = {};
  final changes = StreamController<String>.broadcast();
}

class _FakeSession {
  final String session;
  final String label;
  (String, String)? contender;

  _FakeSession(this.session, this.label);
}

/// Missions, achievements and the leaderboard, like the server's functions
/// (a small fixed pool: the first three daily and weekly missions).
class FakeProgress implements ProgressRepository {
  final FakeOnline _online;

  FakeProgress._(this._online);

  static const pool = [
    MissionProgress(id: 'daily_play_3', cadence: 'daily', metric: 'games', target: 3, xp: 60, coins: 30),
    MissionProgress(id: 'daily_win_1', cadence: 'daily', metric: 'wins', target: 1, xp: 80, coins: 40),
    MissionProgress(id: 'daily_lynch_hits_3', cadence: 'daily', metric: 'lynch_hits', target: 3, xp: 100, coins: 50),
    MissionProgress(id: 'weekly_neutral_win_1', cadence: 'weekly', metric: 'neutral_wins', target: 1, xp: 300, coins: 250),
    MissionProgress(id: 'weekly_wins_7', cadence: 'weekly', metric: 'wins', target: 7, xp: 300, coins: 200),
    MissionProgress(id: 'weekly_play_15', cadence: 'weekly', metric: 'games', target: 15, xp: 250, coins: 150),
  ];

  final Map<String, List<MissionProgress>> missions = {};
  final Map<String, Map<String, int>> stats = {};
  final Map<String, Map<String, DateTime>> unlocked = {};
  final Map<(String, String), GameUnlocks> _unlocks = {};

  String get _me => _online.auth.userId ?? (throw const OnlineException(OnlineFailure.notSignedIn));

  List<MissionProgress> _missionsOf(String id) => missions[id] ??= [...pool];

  void _record(String id, String gameId, Map<String, Object?> p) {
    final tally = (p['tally'] as Map? ?? const {}).cast<String, int>();
    stats[id] = mergeStats(stats[id] ?? const {}, tally);
    final moved = {for (final m in (p['missions'] as List? ?? const [])) (m as Map)['id']: m};
    missions[id] = [
      for (final m in _missionsOf(id))
        if (moved[m.id] case final Map row?)
          MissionProgress(
            id: m.id, cadence: m.cadence, metric: m.metric, target: m.target, xp: m.xp, coins: m.coins,
            progress: row['progress'] as int, completed: row['completed'] == true,
          )
        else
          m,
    ];
    final now = _online.clock.now();
    final ids = [for (final a in (p['unlocked'] as List? ?? const [])) (a as Map)['id'] as String];
    for (final a in ids) {
      (unlocked[id] ??= {})[a] = now;
    }
    _unlocks[(id, gameId)] = GameUnlocks(
      missions: [
        for (final m in moved.values)
          if (m['completed'] == true) (id: m['id'] as String, coins: m['coins'] as int, xp: m['xp'] as int),
      ],
      achievements: ids,
    );
  }

  @override
  Future<PlayerProgress> mine() async {
    await _online._network();
    final me = _me;
    return PlayerProgress(missions: _missionsOf(me), stats: {...?stats[me]}, unlocked: {...?unlocked[me]});
  }

  @override
  Future<GameUnlocks> unlocksFor(String gameId) async {
    await _online._network();
    return _unlocks[(_me, gameId)] ?? const GameUnlocks();
  }

  @override
  Future<Leaderboard> leaderboard(AppLanguage language) async {
    await _online._network();
    final rows = [
      for (final MapEntry(:key, :value) in _online.ratings.entries)
        if (key.$2 == language)
          if (_online._profiles[key.$1]?.handle case final handle?) (key.$1, handle, value.ordinal),
    ]..sort((a, b) => b.$3.compareTo(a.$3));
    final top = [
      for (var i = 0; i < rows.length && i < 100; i++) LeaderboardEntry(i + 1, rows[i].$2, RankTier.of(rows[i].$3)),
    ];
    final mine = rows.indexWhere((r) => r.$1 == _me);
    return Leaderboard(top: top, me: mine < 0 ? null : (rank: mine + 1, tier: RankTier.of(rows[mine].$3)));
  }
}

/// I gesti sul server finto: gli stessi controlli di `send_reaction`.
class FakeReactions implements ReactionsRepository {
  final FakeOnline _online;
  final String? Function() _user;

  FakeReactions._(this._online, this._user);

  String get _me => _user() ?? (throw const OnlineException(OnlineFailure.notSignedIn));

  @override
  Future<Set<TableGesture>> owned() async {
    final ids = _online.shop.ownedBy(_me);
    return {for (final g in TableGesture.values) if (ids.contains(g.item.id)) g};
  }

  @override
  Future<int?> send(String roomId, String toSeat, TableGesture gesture) async {
    await _online._network();
    final me = _me;
    final room = _online._rooms[roomId];
    if (room == null || !room.seats.containsKey(me)) throw const OnlineException(OnlineFailure.notAllowed);
    if (!gesture.free && !_online.shop.ownedBy(me).contains(gesture.item.id)) {
      throw const OnlineException(OnlineFailure.notOwned);
    }
    String from;
    String? target;
    String? gameId;
    if (room.room.status == RoomStatus.lobby) {
      from = '${room.seats[me]}';
      target = room.seats.entries.where((e) => '${e.value}' == toSeat).firstOrNull?.key;
      if (target == null || target == me) throw const OnlineException(OnlineFailure.reactionClosed);
    } else {
      final game = _online._games[roomId];
      final mine = game?.seats.values.where((plan) => plan.profileId == me).firstOrNull?.seat;
      final theirs = game?.seats[toSeat];
      if (game == null ||
          game.chatMode != 'day' ||
          mine == null ||
          theirs == null ||
          mine == toSeat ||
          game.rightsOf(mine)['alive'] == false ||
          game.rightsOf(toSeat)['alive'] == false) {
        throw const OnlineException(OnlineFailure.reactionClosed);
      }
      from = mine;
      target = theirs.profileId;
      gameId = game.gameId;
    }
    final now = _online.clock.now();
    final mineSent = [for (final r in _online._reactions) if (r.reaction.profileId == me) r];
    if (mineSent.any((r) => now.difference(r.reaction.at) < ReactionRules.cooldown)) {
      throw const OnlineException(OnlineFailure.reactionCooldown);
    }
    if (mineSent.where((r) => r.room == roomId && r.game == gameId).length >= ReactionRules.perGame) {
      throw const OnlineException(OnlineFailure.reactionCap);
    }
    if (target != null && (_online._blockedBetween(me, target) || _online._profiles[target]?.tableReactions == false)) {
      return null;
    }
    final reaction = TableReaction(
      id: _online._reactions.length + 1,
      profileId: me,
      fromSeat: from,
      toSeat: toSeat,
      gesture: gesture,
      at: now,
    );
    _online._reactions.add((room: roomId, game: gameId, reaction: reaction));
    _online._notifyGame(roomId);
    return reaction.id;
  }

  @override
  Stream<List<TableReaction>> watch(String roomId) {
    final me = _me;
    late final StreamController<List<TableReaction>> controller;
    void push() {
      if (controller.isClosed) return;
      final member = _online._rooms[roomId]?.seats.containsKey(me) ?? false;
      controller.add([
        if (member)
          for (final r in _online._reactions)
            if (r.room == roomId && !_online.blocks.contains((me, r.reaction.profileId))) r.reaction,
      ]);
    }

    controller = StreamController<List<TableReaction>>(
      onListen: () {
        _online._gameWatchers.add(push);
        scheduleMicrotask(push);
      },
      onCancel: () => _online._gameWatchers.remove(push),
    );
    return controller.stream;
  }
}
