import 'dart:async';
import 'dart:math';

import '../l10n/app_language.dart';
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

  FakeOnline({this.accountId = 'me', Random? random}) : _random = random ?? Random(7);

  OnlineServices get services => OnlineServices(auth: auth, profiles: profiles, friends: friends, rooms: rooms);

  /// Qualcun altro, già con il suo profilo.
  Profile addPlayer(String id, {required String handle, required String displayName}) =>
      _profiles[id] = Profile(id: id, handle: handle, displayName: displayName);

  /// Entra già con il profilo pronto, come chi ha giocato altre volte.
  void signInReady({String handle = 'tu', String displayName = 'Tu'}) {
    addPlayer(accountId, handle: handle, displayName: displayName);
    auth._signIn();
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
      room.room = _copy(room.room, status: RoomStatus.ended);
    } else if (room.room.hostId == id) {
      room.room = _copy(room.room, hostId: room.seats.keys.first);
    }
    room.notify(this);
  }

  Room _copy(Room room, {String? hostId, RoomStatus? status}) => Room(
        id: room.id,
        code: room.code,
        hostId: hostId ?? room.hostId,
        language: room.language,
        status: status ?? room.status,
        maxPlayers: room.maxPlayers,
      );
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

  void _signIn() {
    _online._profiles.putIfAbsent(_online.accountId, () => Profile(id: _online.accountId));
    _userId = _online.accountId;
    notifyListeners();
  }

  Future<void> _provider() async {
    await Future<void>.delayed(Duration.zero);
    if (cancelNext) {
      cancelNext = false;
      throw const OnlineException(OnlineFailure.cancelled);
    }
    _signIn();
  }

  @override
  Future<void> signInWithApple() => _provider();

  @override
  Future<void> signInWithGoogle() => _provider();

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
  Future<Profile> update({required String handle, required String displayName, AppLanguage? language}) async {
    final me = _online._me;
    if (!Profile.handlePattern.hasMatch(handle) ||
        displayName.trim() != displayName ||
        displayName.isEmpty ||
        displayName.length > Profile.maxDisplayName) {
      throw const OnlineException(OnlineFailure.invalidHandle);
    }
    if (_online._profiles.values.any((profile) => profile.id != me && profile.handle == handle)) {
      throw const OnlineException(OnlineFailure.handleTaken);
    }
    return _online._profiles[me] =
        _online._profiles[me]!.copyWith(handle: handle, displayName: displayName, language: language);
  }

  @override
  Future<List<Profile>> search(String handlePrefix) async {
    final me = _online._me;
    final prefix = handlePrefix.toLowerCase().replaceAll(RegExp('[^a-z0-9_]'), '');
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
  Future<void> leave(String roomId) async => _online._leave(roomId, _online._me);

  @override
  Future<Room?> fetch(String roomId) async {
    final room = _online._rooms[roomId];
    if (room == null || !room.seats.containsKey(_online._me)) return null;
    return room.room;
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
