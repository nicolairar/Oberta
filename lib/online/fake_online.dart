import 'dart:async';
import 'dart:convert';
import 'dart:math';

import '../l10n/app_language.dart';
import '../rules/intent.dart';
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

  /// La partita vista da un altro account, come dal suo telefono.
  FakeGame gameAs(String userId) => FakeGame._(this, () => userId);

  final Map<String, _FakeGameRoom> _games = {};
  final List<void Function()> _gameWatchers = [];
  int _intentIds = 0;

  /// Quante pubblicazioni dell'autorità sono arrivate.
  int published = 0;

  /// Tutto quello che il server ha consegnato a ogni telefono, in ordine:
  /// i test controllano che nessuno riceva quello che non deve.
  final List<({String user, GameFeed feed})> deliveries = [];

  /// Se vero, ogni chiamata aspetta un giro come la rete vera.
  bool slow = true;

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

  FakeOnline({this.accountId = 'me', Random? random}) : _random = random ?? Random(7);

  OnlineServices get services =>
      OnlineServices(auth: auth, profiles: profiles, friends: friends, rooms: rooms, game: game);

  /// Gli account di prova: email → (password, id dell'account).
  final Map<String, (String, String)> _testAccounts = {};

  /// Se falso, il server finge di avere il provider Email spento.
  bool emailEnabled = true;

  /// Qualcun altro, già con il suo profilo.
  Profile addPlayer(String id, {required String handle}) => _profiles[id] = Profile(id: id, handle: handle);

  /// Entra già con il profilo pronto, come chi ha giocato altre volte.
  void signInReady({String handle = 'tu', int level = 1, int xp = 0, int coins = 0}) {
    _profiles[accountId] = Profile(id: accountId, handle: handle, level: level, xp: xp, coins: coins);
    auth._signIn(accountId);
  }

  /// Quello che solo il server scrive: livello, esperienza, monete.
  void award(String id, {int? level, int? xp, int? coins}) =>
      _profiles[id] = _profiles[id]!.copyWith(level: level, xp: xp, coins: coins);

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
    if (room.seats.isEmpty) {
      // Come il server: la stanza vuota sparisce.
      room.room = _copy(room.room, status: RoomStatus.ended);
      _rooms.remove(roomId);
      _games.remove(roomId);
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

  List<RoomMember> members(FakeOnline online) => [
        for (final MapEntry(key: id, value: seat) in seats.entries)
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
  String? suggestedName;

  /// Se vero, la prossima finestra di accesso viene chiusa senza entrare.
  bool cancelNext = false;

  /// Se c'è, il prossimo accesso fallisce così (per esempio col provider
  /// spento sul server).
  OnlineException? failNext;

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

  bool _taken(String handle, String me) => _online._profiles.values
      .any((profile) => profile.id != me && profile.handle?.toLowerCase() == Profile.normalizeHandle(handle));

  @override
  Future<bool> handleAvailable(String handle) async => !_taken(handle, _online._me);

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
    return room.room;
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

/// La partita di una stanza, sul server finto: le stesse righe e le stesse
/// regole di accesso delle tabelle `game_*` del database.
class _FakeGameRoom {
  final String host;
  int version = 0;
  Map<String, Object?>? board;
  final Map<String, SeatPlan> seats;
  final Map<String, ({String profile, int version, Map<String, Object?> view})> seatViews = {};
  final List<({int id, String seat, String profile, Map<String, Object?> intent})> intents = [];
  Map<String, Object?>? hostState;

  _FakeGameRoom(this.host, this.seats);
}

/// La partita online sul server finto, vista dall'account [userId]: ogni
/// chiamata controlla quello che controllerebbero le policy e le funzioni
/// del database, e ognuno riceve solo le righe che potrebbe leggere.
class FakeGame implements GameBackend {
  final FakeOnline _online;
  final String? Function() _user;

  FakeGame._(this._online, this._user);

  String get _me => _user() ?? (throw const OnlineException(OnlineFailure.notSignedIn));

  _FakeRoom _room(String roomId) =>
      _online._rooms[roomId] ?? (throw const OnlineException(OnlineFailure.roomNotFound));

  bool _member(String roomId, String id) => _online._rooms[roomId]?.seats.containsKey(id) ?? false;

  @override
  Future<void> setBots(String roomId, int count) async {
    await _online._network();
    final room = _room(roomId);
    if (room.room.hostId != _me) throw const OnlineException(OnlineFailure.notAllowed);
    if (room.room.status != RoomStatus.lobby) throw const OnlineException(OnlineFailure.roomClosed);
    if (count < 0 || count + room.seats.length > room.room.maxPlayers) {
      throw const OnlineException(OnlineFailure.roomFull);
    }
    room.room = room.room.copyWith(bots: count);
    room.notify(_online);
  }

  @override
  Future<void> startGame(String roomId, List<SeatPlan> seats) async {
    await _online._network();
    final me = _me;
    final room = _room(roomId);
    if (room.room.hostId != me) throw const OnlineException(OnlineFailure.notAllowed);
    if (room.room.status != RoomStatus.lobby) throw const OnlineException(OnlineFailure.roomClosed);
    if (seats.length < 4 || seats.length > room.room.maxPlayers) throw const OnlineException(OnlineFailure.notAllowed);
    final placed = <String, SeatPlan>{};
    final humans = <String>{};
    for (final (index, plan) in seats.indexed) {
      if (plan.seat != 's${index + 1}') throw const OnlineException(OnlineFailure.notAllowed);
      final profile = plan.profileId;
      if (profile == null) {
        if (!RegExp(r'^bot\.[a-z]{1,8}$').hasMatch(plan.name)) throw const OnlineException(OnlineFailure.notAllowed);
        placed[plan.seat] = plan;
      } else {
        if (!room.seats.containsKey(profile) || !humans.add(profile)) {
          throw const OnlineException(OnlineFailure.notAllowed);
        }
        // Come il server: una persona siede col suo nome unico, qualunque
        // cosa mandi il padrone di casa.
        placed[plan.seat] = SeatPlan(seat: plan.seat, profileId: profile, name: _online._profiles[profile]!.name);
      }
    }
    if (humans.length != room.seats.length) throw const OnlineException(OnlineFailure.notAllowed);
    _online._games[roomId] = _FakeGameRoom(me, placed);
    room.room = room.room.copyWith(status: RoomStatus.playing);
    room.notify(_online);
  }

  @override
  Future<void> publish(String roomId, GamePublication publication) async {
    await _online._network();
    final me = _me;
    final game = _online._games[roomId];
    if (game == null || game.host != me || !_member(roomId, me)) throw const OnlineException(OnlineFailure.notAllowed);
    if (publication.version <= game.version) throw const OnlineException(OnlineFailure.notAllowed, null, 'stale_version');
    game.version = publication.version;
    game.board = _wire(publication.board);
    for (final plan in game.seats.values) {
      final profile = plan.profileId;
      final view = publication.seatViews[plan.seat];
      if (profile == null || view == null) continue;
      // La vista va a chi siede a quel posto, qualunque cosa dica l'host.
      game.seatViews[plan.seat] = (profile: profile, version: publication.version, view: _wire(view));
    }
    game.hostState = _wire(publication.hostState);
    if (publication.lastIntent case final last?) game.intents.removeWhere((intent) => intent.id <= last);
    _online.published++;
    if (publication.finished) {
      final room = _room(roomId);
      room.room = room.room.copyWith(status: RoomStatus.lobby);
      room.notify(_online);
    }
    _online._notifyGame(roomId);
  }

  List<IntentEnvelope> _intentsFor(String roomId) {
    final game = _online._games[roomId];
    if (game == null) return const [];
    return [
      for (final intent in game.intents) IntentEnvelope(id: intent.id, seat: intent.seat, intent: _wire(intent.intent)),
    ];
  }

  bool _isHost(String roomId, String id) => _online._games[roomId]?.host == id && _member(roomId, id);

  @override
  Stream<List<IntentEnvelope>> watchIntents(String roomId) {
    final me = _me;
    late final StreamController<List<IntentEnvelope>> controller;
    void push() {
      if (controller.isClosed) return;
      // Come la policy: solo l'host della partita legge le intenzioni.
      if (!_isHost(roomId, me)) return;
      controller.add(_intentsFor(roomId));
    }

    controller = StreamController<List<IntentEnvelope>>(
      onListen: () {
        _online._gameWatchers.add(push);
        scheduleMicrotask(push);
      },
      onCancel: () => _online._gameWatchers.remove(push),
    );
    return controller.stream;
  }

  @override
  Future<Map<String, Object?>?> loadHostState(String roomId) async {
    await _online._network();
    final me = _me;
    final game = _online._games[roomId];
    if (game == null || game.host != me || !_member(roomId, me)) return null;
    final state = game.hostState;
    return state == null ? null : _wire(state);
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
      if (controller.isClosed) return;
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

  @override
  Future<int> sendIntent(String roomId, PlayerIntent intent) async {
    await _online._network();
    final me = _me;
    final game = _online._games[roomId];
    final room = _online._rooms[roomId];
    if (game == null || room == null || !_member(roomId, me) || room.room.status != RoomStatus.playing) {
      throw const OnlineException(OnlineFailure.notAllowed);
    }
    final seat = game.seats.values.where((plan) => plan.profileId == me).firstOrNull?.seat;
    if (seat == null) throw const OnlineException(OnlineFailure.notAllowed);
    final json = _wire(intent.toJson());
    if (json['seat'] != seat) throw const OnlineException(OnlineFailure.notAllowed, null, 'not_your_seat');
    if (game.intents.where((i) => i.profile == me).length >= 20) {
      throw const OnlineException(OnlineFailure.notAllowed, null, 'too_many_intents');
    }
    final id = ++_online._intentIds;
    game.intents.add((id: id, seat: seat, profile: me, intent: json));
    _online._notifyGame(roomId);
    return id;
  }

  /// Solo per i test: manda un'intenzione così com'è, come farebbe un
  /// client modificato. Il server controlla comunque il posto.
  Future<int> sendRaw(String roomId, Map<String, Object?> json) async {
    final me = _me;
    final game = _online._games[roomId];
    if (game == null || !_member(roomId, me)) throw const OnlineException(OnlineFailure.notAllowed);
    final seat = game.seats.values.where((plan) => plan.profileId == me).firstOrNull?.seat;
    if (seat == null || json['seat'] != seat) throw const OnlineException(OnlineFailure.notAllowed, null, 'not_your_seat');
    final id = ++_online._intentIds;
    game.intents.add((id: id, seat: seat, profile: me, intent: _wire(json)));
    _online._notifyGame(roomId);
    return id;
  }
}

Map<String, Object?> _wire(Map<String, Object?> json) => jsonDecode(jsonEncode(json)) as Map<String, Object?>;
