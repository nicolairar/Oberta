import 'dart:async';
import 'dart:convert';
import 'dart:math';

import '../l10n/app_language.dart';
import '../rules/intent.dart';
import 'game/bot_brain.dart';
import 'game/game_clock.dart';
import 'game/game_schedule.dart';
import 'game/game_server.dart';
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
  final List<({String room, String? game, ChatMessage message})> _chat = [];
  int _intentIds = 0;
  int _chatIds = 0;
  int _gameIds = 0;

  /// L'orologio del server finto: quello vero, o uno a mano nei test.
  GameClock clock;

  /// I tempi della partita.
  OnlinePacing pacing;

  /// Se vero, il server guarda chi si fa sentire (offline, chi lascia la
  /// città). Spento, tutti risultano sempre collegati.
  bool trackPresence = false;

  /// Quante versioni della partita ha pubblicato il server.
  int published = 0;

  /// Gli abbandoni annotati dal server in una partita (i posti), per i test.
  List<String> abandonsIn(String roomId) => [...?_games[roomId]?.abandons];

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

  FakeOnline({this.accountId = 'me', Random? random, GameClock? clock, this.pacing = const OnlinePacing()})
      : _random = random ?? Random(7),
        clock = clock ?? const SystemGameClock();

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
  final List<({int id, String seat, String profile, Map<String, Object?> intent})> intents = [];
  final Map<String, DateTime> lastSeen = {};
  String chatMode = 'closed';
  Map<String, Object?> chatSeats = const {};
  Set<String> offline = {};
  final List<String> abandons = [];
  GameTimer? timer;
  bool finished = false;

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
  Future<void> startGame(String roomId) async {
    await _online._network();
    final me = _me;
    final room = _room(roomId);
    if (room.room.hostId != me) throw const OnlineException(OnlineFailure.notAllowed);
    if (room.room.status != RoomStatus.lobby) throw const OnlineException(OnlineFailure.roomClosed);
    final total = room.seats.length + room.room.bots;
    if (total < 4 || total > room.room.maxPlayers) throw const OnlineException(OnlineFailure.notAllowed);
    // Come il server: le persone nell'ordine dei posti, poi i bot.
    final people = room.members(_online);
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
        _FakeGameRoom('game-${++_online._gameIds}', seats, room.room.language.name);
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

  Future<int> _submit(String roomId, Map<String, Object?> json) async {
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
    final id = ++_online._intentIds;
    game.intents.add((id: id, seat: seat, profile: me, intent: _wire(json)));
    game.lastSeen[seat] = _online.clock.now();
    _online._wake(roomId);
    return id;
  }

  @override
  Future<int> sendIntent(String roomId, PlayerIntent intent) => _submit(roomId, intent.toJson());

  @override
  Future<void> sendAck(String roomId, String seat, String stage) =>
      _submit(roomId, {'type': 'ack', 'seat': seat, 'stage': stage});

  /// Solo per i test: manda un'intenzione così com'è, come farebbe un
  /// client modificato. Il server controlla comunque il posto.
  Future<int> sendRaw(String roomId, Map<String, Object?> json) => _submit(roomId, json);

  @override
  Future<int> ping(String roomId) async {
    await _online._network();
    final me = _me;
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
  Future<void> sendChat(String roomId, ChatChannel channel, String body) async {
    await _online._network();
    final me = _me;
    final text = body.trim();
    if (!_member(roomId, me)) throw const OnlineException(OnlineFailure.notAllowed);
    if (text.isEmpty || text.length > 300) throw const OnlineException(OnlineFailure.chatClosed);
    final now = _online.clock.now();
    final recent = _online._chat.where(
      (m) => m.message.profileId == me && now.difference(m.message.at) < const Duration(seconds: 3),
    );
    if (recent.length >= 3) throw const OnlineException(OnlineFailure.tooManyMessages);
    if (HandleRules.offensive(text)) throw const OnlineException(OnlineFailure.messageBlocked);
    final room = _room(roomId);
    String? seat;
    String? gameId;
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
        ChatChannel.family => game.chatMode == 'night' && rights['family'] == true,
        ChatChannel.lobby => false,
      };
      if (!allowed) throw const OnlineException(OnlineFailure.chatClosed);
      gameId = game.gameId;
      name = game.seats[seat]!.name;
    }
    _online._chat.add((
      room: roomId,
      game: gameId,
      message: ChatMessage(
        id: ++_online._chatIds,
        channel: channel,
        profileId: me,
        seat: seat,
        name: name,
        body: text,
        at: now,
      ),
    ));
    _online._notifyGame(roomId);
  }

  /// Come la policy di game_chat: stanza e piazza per chi è nella stanza,
  /// la famiglia solo per i suoi vivi, nella partita in corso.
  List<ChatMessage> _chatFor(String roomId, String me) {
    if (!_member(roomId, me)) return const [];
    final game = _online._games[roomId];
    final seat = game == null ? null : _seatOf(game, me);
    final rights = seat == null ? const <String, Object?>{} : game!.rightsOf(seat);
    final family = rights['family'] == true && rights['alive'] != false;
    return [
      for (final m in _online._chat)
        if (m.room == roomId &&
            (m.message.channel != ChatChannel.family || (family && m.game == game?.gameId)))
          m.message,
    ];
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
          for (final i in game.intents) {'id': i.id, 'seat': i.seat, 'intent': i.intent},
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
      published++;
      if (out['finished'] == true) {
        game.finished = true;
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
