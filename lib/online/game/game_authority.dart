import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../l10n/app_language.dart';
import '../../rules/game_engine.dart';
import '../../rules/game_settings.dart';
import '../../rules/game_setup.dart';
import '../../rules/game_snapshot.dart';
import '../../rules/intent.dart';
import '../../rules/player.dart';
import '../../table/seating.dart';
import '../online_models.dart';
import 'bot_brain.dart';
import 'game_backend.dart';
import 'game_clock.dart';
import 'game_protocol.dart';

/// I tempi della partita online. L'autorità chiude una fase quando hanno
/// agito tutti, o allo scadere: chi non ha scelto di notte passa, chi non ha
/// votato di giorno si astiene. Le scadenze sono larghe: prima di agire i
/// telefoni guardano i filmati e leggono il narratore.
class OnlinePacing {
  /// La notte, dopo il verdetto (o dopo le carte, la prima).
  final Duration night;
  final Duration firstNight;

  /// Di giorno, per ogni agguato da guardare all'alba, e per le pagine.
  final Duration perFilm;
  final Duration dawnPages;

  /// Di giorno, dopo la discussione, per votare.
  final Duration voting;

  /// Quanto ci mette un bot a scegliere: di notte, e di giorno.
  final Duration botNightMin;
  final Duration botNightMax;
  final Duration botDayMin;
  final Duration botDayMax;

  const OnlinePacing({
    this.night = const Duration(seconds: 120),
    this.firstNight = const Duration(seconds: 180),
    this.perFilm = const Duration(seconds: 25),
    this.dawnPages = const Duration(seconds: 30),
    this.voting = const Duration(seconds: 60),
    this.botNightMin = const Duration(milliseconds: 1500),
    this.botNightMax = const Duration(seconds: 5),
    this.botDayMin = const Duration(seconds: 8),
    this.botDayMax = const Duration(seconds: 25),
  });
}

/// Le regole della partita online: la discussione è più corta, il voto è
/// già aperto mentre si discute.
const onlineSettings = GameSettings(discussion: Duration(minutes: 2));

/// L'autorità di una partita fra amici: gira sul telefono del padrone di
/// casa. Tiene il motore (e tutti i ruoli) per sé, valida le intenzioni che
/// arrivano dal server, fa giocare i bot e pubblica a ogni cambio il tavolo
/// pubblico e la vista di ciascun posto umano. Niente di quello che sa
/// finisce sullo schermo: il telefono del padrone di casa gioca con un
/// [GameClient] come tutti gli altri.
class GameAuthority {
  final GameBackend backend;
  final String roomId;
  final Seating seating;
  final AppLanguage language;
  final int narrationSeed;
  final GameClock clock;
  final OnlinePacing pacing;
  final Random _random;
  final BotBrain _brain;
  final GameEngine _engine;

  int _version;
  int _lastIntent;
  DateTime? _deadline;
  final Map<String, Map<String, Object?>> _receipts;

  StreamSubscription<List<IntentEnvelope>>? _intents;
  final Map<String, GameTimer> _botTimers = {};
  final Map<String, String> _botTurns = {};
  GameTimer? _deadlineTimer;
  GameTimer? _retry;
  Future<void> _sending = Future.value();
  bool _disposed = false;

  /// Chi ascolta sa quando una pubblicazione non è andata (per dirlo a
  /// schermo, senza mostrare niente della partita).
  final ValueNotifier<Object?> lastError = ValueNotifier(null);

  GameAuthority._({
    required this.backend,
    required this.roomId,
    required this.seating,
    required this.language,
    required this.narrationSeed,
    required this.clock,
    required this.pacing,
    required Random random,
    required this._engine,
    this._version = 0,
    this._lastIntent = 0,
    this._deadline,
    Map<String, Map<String, Object?>>? receipts,
  })  : _random = random,
        _brain = BotBrain(random),
        _receipts = receipts ?? {};

  /// Solo per i test: il motore, che il resto dell'app non vede mai.
  @visibleForTesting
  GameEngine get engine => _engine;

  int get version => _version;

  /// Chi siede dove: prima le persone della stanza, nell'ordine dei loro
  /// posti, poi i bot.
  static Seating seatTable(List<RoomMember> members, int bots) {
    final people = [...members]..sort((a, b) => a.seat.compareTo(b.seat));
    return Seating.open([
      for (final member in people) (name: member.profile.name, profileId: member.profile.id),
      for (var i = 0; i < bots; i++) (name: botName(i), profileId: null),
    ]);
  }

  /// Apre la partita: il server registra i posti, il motore dà le carte, e
  /// la prima versione parte subito.
  static Future<GameAuthority> start({
    required GameBackend backend,
    required String roomId,
    required List<RoomMember> members,
    required int bots,
    required AppLanguage language,
    GameClock clock = const SystemGameClock(),
    OnlinePacing pacing = const OnlinePacing(),
    Random? random,
  }) async {
    final rng = random ?? Random.secure();
    final seating = seatTable(members, bots);
    await backend.startGame(roomId, [
      for (final occupant in seating.occupants)
        SeatPlan(seat: occupant.seat, profileId: occupant.profileId, name: occupant.name),
    ]);
    final engine = GameEngine(
      GameSetup.deal(lobby: seating.players, random: rng),
      settings: onlineSettings,
      seed: rng.nextInt(1 << 32),
    );
    final authority = GameAuthority._(
      backend: backend,
      roomId: roomId,
      seating: seating,
      language: language,
      narrationSeed: rng.nextInt(1 << 31),
      clock: clock,
      pacing: pacing,
      random: rng,
      engine: engine,
      deadline: clock.now().add(pacing.firstNight),
    );
    authority._listen();
    authority._update();
    await authority.flushed;
    return authority;
  }

  /// Riprende la partita salvata all'ultima pubblicazione (il telefono del
  /// padrone di casa che si è riavviato). Null se non c'è niente da riprendere.
  static Future<GameAuthority?> resume({
    required GameBackend backend,
    required String roomId,
    GameClock clock = const SystemGameClock(),
    OnlinePacing pacing = const OnlinePacing(),
    Random? random,
  }) async {
    final state = await backend.loadHostState(roomId);
    if (state == null || state['snapshot'] == null) return null;
    final seating = Seating.fromJson(state['seating'] as Map<String, Object?>);
    final snapshot = GameSnapshot.fromJson(state['snapshot'] as Map<String, Object?>, seating.playerAt);
    final deadline = state['deadline'] as int?;
    final authority = GameAuthority._(
      backend: backend,
      roomId: roomId,
      seating: seating,
      language: state['language'] == 'en' ? AppLanguage.en : AppLanguage.it,
      narrationSeed: state['narrationSeed'] as int,
      clock: clock,
      pacing: pacing,
      random: random ?? Random.secure(),
      engine: GameEngine.fromSnapshot(snapshot),
      version: state['version'] as int,
      lastIntent: state['lastIntent'] as int? ?? 0,
      deadline: deadline == null ? null : DateTime.fromMillisecondsSinceEpoch(deadline),
      receipts: {
        for (final MapEntry(:key, :value) in ((state['receipts'] as Map<String, Object?>?) ?? const {}).entries)
          key: value as Map<String, Object?>,
      },
    );
    authority._listen();
    authority._update();
    await authority.flushed;
    return authority;
  }

  /// Si completa quando tutto quello che è stato pubblicato finora è sul server.
  Future<void> get flushed => _sending;

  void _listen() {
    _intents = backend.watchIntents(roomId).listen(_received, onError: (Object error) {
      if (!_disposed) lastError.value = error;
    });
  }

  bool _isBot(String seat) => seating.occupantOf(seat)?.profileId == null;

  void _received(List<IntentEnvelope> envelopes) {
    if (_disposed) return;
    var changed = false;
    for (final envelope in [...envelopes]..sort((a, b) => a.id.compareTo(b.id))) {
      if (envelope.id <= _lastIntent) continue;
      _lastIntent = envelope.id;
      changed = true;
      final IntentResult result;
      if (_isBot(envelope.seat) || seating.occupantOf(envelope.seat) == null) {
        result = IntentRejected(IntentError.unknownSeat, 'il posto ${envelope.seat} non è di una persona');
      } else {
        PlayerIntent? intent;
        try {
          intent = PlayerIntent.fromJson(envelope.intent);
        } catch (_) {
          intent = null;
        }
        if (intent == null) {
          result = const IntentRejected(IntentError.notYourAction, 'intenzione illeggibile');
        } else if (intent.seat != envelope.seat) {
          result = IntentRejected(IntentError.unknownSeat, '${envelope.seat} non può agire per ${intent.seat}');
        } else {
          result = _engine.apply(intent);
        }
      }
      _receipts[envelope.seat] = {'id': envelope.id, 'result': result.toJson()};
    }
    // Anche solo per pulire le intenzioni gestite si pubblica.
    if (changed) _update();
  }

  /// Dopo ogni mossa: le fasi che si chiudono da sole, i bot, la scadenza,
  /// e una nuova versione per tutti.
  void _update() {
    if (_disposed) return;
    _advance();
    _scheduleBots();
    _armDeadline();
    _publish();
  }

  void _advance() {
    while (true) {
      if (_engine.phase == GamePhase.night && _engine.nightComplete) {
        final dawn = _engine.resolveNight();
        _deadline = _engine.phase == GamePhase.day
            ? clock
                .now()
                .add(pacing.perFilm * dawn.attacks.length)
                .add(pacing.dawnPages)
                .add(_engine.settings.discussion)
                .add(pacing.voting)
            : null;
        continue;
      }
      if (_engine.phase == GamePhase.day && _engine.pendingDayVoters.isEmpty) {
        _engine.closeDayVote();
        _deadline = _engine.phase == GamePhase.night ? clock.now().add(pacing.night) : null;
        continue;
      }
      if (_engine.phase == GamePhase.ended) _deadline = null;
      return;
    }
  }

  Duration _between(Duration low, Duration high) =>
      low + Duration(milliseconds: _random.nextInt(max(1, (high - low).inMilliseconds)));

  void _scheduleBots() {
    final turn = '${_engine.phase.name}-${_engine.round}';
    for (final occupant in seating.occupants) {
      if (occupant.profileId != null) continue;
      final seat = occupant.seat;
      final player = seating.playerAt(seat);
      final waiting = _engine.isAlive(player) &&
          switch (_engine.phase) {
            GamePhase.night => _engine.pendingNightPlayers.contains(player),
            GamePhase.day => !_engine.dayVotes.containsKey(player),
            GamePhase.ended => false,
          };
      if (!waiting) {
        _botTimers.remove(seat)?.cancel();
        _botTurns.remove(seat);
        continue;
      }
      if (_botTurns[seat] == turn) continue;
      _botTimers.remove(seat)?.cancel();
      _botTurns[seat] = turn;
      final delay = _engine.phase == GamePhase.night
          ? _between(pacing.botNightMin, pacing.botNightMax)
          : _between(pacing.botDayMin, pacing.botDayMax);
      _botTimers[seat] = clock.schedule(delay, () => _botActs(seat, turn));
    }
  }

  void _botActs(String seat, String turn) {
    if (_disposed) return;
    _botTimers.remove(seat);
    if ('${_engine.phase.name}-${_engine.round}' != turn) return;
    // Il bot vede solo la sua vista, come un telefono.
    final intent = _brain.decide(_engine.viewFor(seat)) ?? Pass(seat);
    final result = _engine.apply(intent);
    if (!result.accepted) _engine.apply(Pass(seat));
    _update();
  }

  void _armDeadline() {
    _deadlineTimer?.cancel();
    _deadlineTimer = null;
    final deadline = _deadline;
    if (deadline == null) return;
    final left = deadline.difference(clock.now());
    _deadlineTimer = clock.schedule(left.isNegative ? Duration.zero : left, _timeUp);
  }

  /// Allo scadere: chi non ha scelto passa, il voto si chiude.
  void _timeUp() {
    if (_disposed) return;
    _deadlineTimer = null;
    switch (_engine.phase) {
      case GamePhase.night:
        for (final player in _engine.pendingNightPlayers) {
          _engine.apply(Pass(player.id));
        }
      case GamePhase.day:
        _engine.closeDayVote();
        _deadline = _engine.phase == GamePhase.night ? clock.now().add(pacing.night) : null;
      case GamePhase.ended:
        return;
    }
    _update();
  }

  void _publish() {
    if (_disposed) return;
    final publication = _build();
    _sending = _sending.then((_) async {
      if (_disposed) return;
      try {
        await backend.publish(roomId, publication);
        if (!_disposed) lastError.value = null;
      } catch (error) {
        debugPrint('Pubblicazione non riuscita: $error');
        if (_disposed) return;
        lastError.value = error;
        // Si riprova con una versione nuova: la vecchia potrebbe essere già
        // arrivata a metà strada, e il server rifiuta le versioni vecchie.
        _retry?.cancel();
        _retry = clock.schedule(const Duration(seconds: 2), _publish);
      }
    });
  }

  GamePublication _build() {
    _version++;
    return GamePublication(
      version: _version,
      board: publicPayload(
        engine: _engine,
        seating: seating,
        narrationSeed: narrationSeed,
        language: language,
        deadline: _deadline,
      ),
      seatViews: {
        for (final occupant in seating.occupants)
          if (occupant.profileId != null)
            occupant.seat: seatPayload(_engine.viewFor(occupant.seat), receipt: _receipts[occupant.seat]),
      },
      hostState: {
        'version': _version,
        'snapshot': _engine.snapshot().toJson(),
        'seating': seating.toJson(),
        'narrationSeed': narrationSeed,
        'language': language.name,
        'lastIntent': _lastIntent,
        'deadline': _deadline?.millisecondsSinceEpoch,
        'receipts': _receipts,
      },
      lastIntent: _lastIntent == 0 ? null : _lastIntent,
      finished: _engine.phase == GamePhase.ended,
    );
  }

  /// Il nome di un posto, per i messaggi.
  Player playerAt(String seat) => seating.playerAt(seat);

  void dispose() {
    _disposed = true;
    _intents?.cancel();
    _deadlineTimer?.cancel();
    _retry?.cancel();
    for (final timer in _botTimers.values) {
      timer.cancel();
    }
    _botTimers.clear();
    lastError.dispose();
  }
}
