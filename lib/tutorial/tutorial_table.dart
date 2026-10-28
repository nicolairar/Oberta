import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';

import '../l10n/app_language.dart';
import '../online/game/game_backend.dart';
import '../online/game/game_clock.dart';
import '../online/game/game_schedule.dart';
import '../online/game/game_server.dart';
import '../online/reactions.dart';
import '../rules/intent.dart';
import '../rules/role.dart';
import 'tutorial_script.dart';

/// L'orologio della mano di prova: quello del telefono, che nei test va
/// col tempo finto.
class TutorialClock implements GameClock {
  const TutorialClock();

  @override
  DateTime now() => clock.now();

  @override
  GameTimer schedule(Duration after, void Function() action) => _Timer(Timer(after, action));
}

class _Timer implements GameTimer {
  final Timer _timer;

  _Timer(this._timer);

  @override
  void cancel() => _timer.cancel();
}

/// Il tavolo della mano di prova, sul telefono: lo stesso server della
/// partita online ([ServerGame]), con le carte date dal copione e i bot che
/// recitano la loro parte. Lo schermo della partita vera lo legge come
/// leggerebbe Supabase. Nessuna fase scade: si va avanti quando hai fatto.
class TutorialTable implements GameBackend {
  final TutorialScript script;
  final AppLanguage language;
  final GameClock clock;

  static const roomId = 'tutorial';
  static const you = TutorialScript.you;
  static const youId = 'tutorial.you';

  /// Niente orologi che mettono fretta: ogni fase dura un'ora, e chiude
  /// appena hai fatto la tua parte.
  static const pacing = OnlinePacing(
    lead: Duration(milliseconds: 600),
    reveal: Duration(hours: 1),
    night: Duration(hours: 1),
    dawn: Duration(hours: 1),
    discussion: Duration(hours: 1),
    vote: Duration(hours: 1),
  );

  /// La riga del narratore di adesso.
  final ValueNotifier<TutorialCoach?> coach = ValueNotifier(null);

  /// Le risposte già pronte di adesso (vuote: niente da dire).
  final ValueNotifier<List<String>> replies = ValueNotifier(const []);

  /// La mano è finita (vinta): si mostra «Ora sei pronto».
  final ValueNotifier<bool> finished = ValueNotifier(false);

  late final ServerGame _game;
  final List<IntentEnvelope> _inbox = [];
  int _ids = 0;
  int _chatIds = 0;
  int _reactionIds = 0;
  int _eventIds = 0;
  GameFeed _feed = const GameFeed();
  final List<ChatMessage> _chat = [];
  final List<TableReaction> _reactions = [];
  final _feeds = StreamController<GameFeed>.broadcast();
  final _chats = StreamController<List<ChatMessage>>.broadcast();
  final _gestures = StreamController<List<TableReaction>>.broadcast();
  GameTimer? _due;
  GameTimer? _cueTimer;
  DateTime? _endAt;
  String? _stageKey;
  Scene _scene = const Scene();
  final List<Cue> _queue = [];
  bool _answered = false;
  bool _closed = false;
  bool _fresh = true;
  int _days = 0;

  TutorialTable(this.script, {required String youName, required this.language, this.clock = const TutorialClock()}) {
    _game = ServerGame.scripted(
      seats: [
        SeatPlan(seat: you, profileId: youId, name: youName),
        for (final MapEntry(key: seat, value: name) in TutorialScript.names.entries)
          SeatPlan(seat: seat, profileId: null, name: name),
      ],
      roles: script.roles,
      language: language.name,
      now: clock.now(),
      seed: script.seed,
      pacing: pacing,
    );
    _serve();
  }

  /// Il gesto lanciato da te: arriva come quelli dei bot.
  late final ReactionsRepository reactions = _TutorialReactions(this);

  void dispose() {
    _closed = true;
    _due?.cancel();
    _cueTimer?.cancel();
    _feeds.close();
    _chats.close();
    _gestures.close();
  }

  // Il server: un passo con le intenzioni arrivate, poi l'appuntamento.

  void _serve() {
    if (_closed) return;
    _due?.cancel();
    final intents = [..._inbox];
    _inbox.clear();
    final step = _game.step(now: clock.now(), intents: intents, pacing: pacing, fresh: _fresh);
    _fresh = false;
    // A partita vinta lo schermo della partita lascia il posto alla fine
    // della mano di prova: niente schermata dei risultati, niente musica.
    if (step.finished && !finished.value) finished.value = true;
    if (step.changed) {
      final view = step.seatViews[you];
      _feed = GameFeed(
        board: PublicFrame(step.version, _wire(step.board)),
        seat: view == null ? null : SeatFrame(you, step.version, _wire(view)),
      );
      _feeds.add(_feed);
      // Le righe del server nella chat (chi è morto, chi ha votato chi):
      // quelle pubbliche e quelle per te, come in partita.
      var added = false;
      for (final event in _wire({'e': step.events})['e'] as List<Object?>) {
        final row = (event as Map).cast<String, Object?>();
        final to = row['to'] as String?;
        if (to != null && to != you) continue;
        _chat.add(ChatMessage.event(
          kind: row['kind'] as String,
          data: (row['data'] as Map).cast<String, Object?>(),
          private: to != null,
          n: ++_eventIds,
          at: clock.now(),
        ));
        added = true;
      }
      if (added) _chats.add([..._chat]);
      _stageChanged();
    }
    final next = step.nextDue;
    if (next != null && !step.finished) {
      final wait = next.difference(clock.now());
      _due = clock.schedule(wait.isNegative ? Duration.zero : wait, _serve);
    }
  }

  void _stageChanged() {
    final key = _game.window.key;
    if (key == _stageKey) return;
    _stageKey = key;
    // Il verdetto si apre col turno dopo (o con lo stesso, se la partita
    // finisce): nel copione si conta per giornate.
    final stage = _game.stage;
    if (stage == Stage.vote) _days++;
    final scene = stage == Stage.verdict || stage == Stage.verdictFilm ? '${stage.name}-$_days' : key;
    _scene = script.scenes[scene] ?? const Scene();
    _answered = false;
    final youAlive = _game.engine.isAlive(_game.seating.playerAt(you));
    if (_game.finished || (_game.stage == Stage.verdict && !youAlive)) {
      _endAt ??= clock.now().add(const Duration(milliseconds: 3500));
    }
    _cueTimer?.cancel();
    _queue
      ..clear()
      ..addAll(_scene.opening);
    coach.value = _scene.coach;
    replies.value = _scene.answer.isEmpty ? const [] : _scene.replies;
    _nextCue();
  }

  /// Chi guarda il tavolo lo chiama spesso: dopo l'ultima scena, la fine.
  void tick() {
    final end = _endAt;
    if (!_closed && end != null && !clock.now().isBefore(end)) finished.value = true;
  }

  /// Le pause fra una riga e l'altra: quanto ci mette una persona a scrivere.
  Duration _pause(Cue cue) => switch (cue) {
    Say(:final text) => Duration(milliseconds: 900 + 28 * text.length),
    Move() => const Duration(milliseconds: 1100),
    Toss() => const Duration(milliseconds: 900),
  };

  void _nextCue() {
    if (_queue.isEmpty || _closed) return;
    _cueTimer = clock.schedule(_pause(_queue.first), () {
      if (_closed || _queue.isEmpty) return;
      _play(_queue.removeAt(0));
      _nextCue();
    });
  }

  void _play(Cue cue) {
    switch (cue) {
      case Say(:final seat, :final text, :final family):
        _post(seat, null, text, family ? ChatChannel.family : ChatChannel.day);
      case Move(:final intent):
        _inbox.add(IntentEnvelope(id: ++_ids, seat: intent.seat, intent: intent.toJson()));
        _serve();
      case Toss(:final from, :final to, :final gesture):
        _toss(from, to, gesture);
    }
  }

  void _post(String seat, String? profile, String body, ChatChannel channel) {
    _chat.add(ChatMessage(
      id: 'tutorial-${++_chatIds}',
      n: _chatIds,
      channel: channel,
      profileId: profile ?? 'bot.$seat',
      seat: seat,
      name: _game.seating.occupantOf(seat)!.name,
      body: body,
      at: clock.now(),
    ));
    _chats.add([..._chat]);
  }

  void _toss(String from, String to, TableGesture gesture) {
    _reactions.add(TableReaction(
      id: ++_reactionIds,
      profileId: from == you ? youId : 'bot.$from',
      fromSeat: from,
      toSeat: to,
      gesture: gesture,
      at: clock.now(),
    ));
    _gestures.add([..._reactions]);
  }

  /// Le mosse dei bot ancora in copione vanno subito sul tavolo, prima
  /// della tua: così il risultato è sempre lo stesso.
  void _flushMoves() {
    final moves = [for (final cue in _queue) if (cue is Move) cue];
    _queue.removeWhere((cue) => cue is Move);
    for (final move in moves) {
      _inbox.add(IntentEnvelope(id: ++_ids, seat: move.intent.seat, intent: move.intent.toJson()));
    }
  }

  bool _onScript(PlayerIntent intent) {
    final expect = _scene.expect;
    if (expect == null) return true;
    return switch (intent) {
      NightAction(:final target) || MafiaVote(:final target) => expect.contains(target),
      DayVote(:final target) => expect.contains(target),
      _ => false,
    };
  }

  // Il tubo, come lo vede lo schermo della partita.

  @override
  Future<void> startGame(String roomId) async {}

  @override
  Stream<GameFeed> watchGame(String roomId) {
    late final StreamController<GameFeed> out;
    StreamSubscription<GameFeed>? sub;
    out = StreamController<GameFeed>(
      onListen: () {
        scheduleMicrotask(() {
          if (!out.isClosed) out.add(_feed);
        });
        sub = _feeds.stream.listen(out.add);
      },
      onCancel: () => sub?.cancel(),
    );
    return out.stream;
  }

  @override
  Future<int> sendIntent(String roomId, PlayerIntent intent) async {
    final id = ++_ids;
    if (_onScript(intent)) {
      _flushMoves();
      _inbox.add(IntentEnvelope(id: id, seat: you, intent: intent.toJson()));
      if (_scene.acted case final acted?) coach.value = acted;
    } else {
      // Fuori copione: il server la rifiuta, e la mano torna indietro.
      _inbox.add(IntentEnvelope(id: id, seat: you, intent: {'type': 'offScript', 'seat': you}));
      coach.value = _answered ? (_scene.answered ?? _scene.coach) : _scene.coach;
    }
    scheduleMicrotask(_serve);
    return id;
  }

  @override
  Future<void> sendAck(String roomId, String seat, String stage) async {
    _inbox.add(IntentEnvelope(id: ++_ids, seat: you, intent: {'type': 'ack', 'seat': you, 'stage': stage}));
    scheduleMicrotask(_serve);
  }

  @override
  Future<int> ping(String roomId) async => clock.now().millisecondsSinceEpoch;

  @override
  Future<void> leaveGame(String roomId) async {}

  @override
  Future<void> resume() async {}

  @override
  Future<String> sendChat(String roomId, ChatChannel channel, String body) async {
    final text = body.trim();
    if (text.isEmpty) return 'tutorial-$_chatIds';
    _post(you, youId, text, channel);
    if (!_answered && _scene.answer.isNotEmpty) {
      _answered = true;
      replies.value = const [];
      if (_scene.answered case final answered?) coach.value = answered;
      final busy = _queue.isNotEmpty;
      _queue.addAll(_scene.answer);
      if (!busy) _nextCue();
    }
    return 'tutorial-$_chatIds';
  }

  @override
  Stream<List<ChatMessage>> watchChat(String roomId) => _snapshotStream(_chats.stream, () => [..._chat]);

  Stream<T> _snapshotStream<T>(Stream<T> source, T Function() now) {
    late final StreamController<T> out;
    StreamSubscription<T>? sub;
    out = StreamController<T>(
      onListen: () {
        scheduleMicrotask(() {
          if (!out.isClosed) out.add(now());
        });
        sub = source.listen(out.add);
      },
      onCancel: () => sub?.cancel(),
    );
    return out.stream;
  }

  /// Chi ha vinto la partita (null: non è finita).
  Team? get winner => _game.engine.winner;

  /// Hai vinto tu (anche da solo, come il Fesso linciato).
  bool get youWon => _game.engine.hasWon(_game.seating.playerAt(you));

  /// La fase in corso (`night-1`...).
  String get stage => _game.window.key;

  /// Il canale in cui rispondere adesso: di notte la famiglia, di giorno la piazza.
  ChatChannel get replyChannel => _game.stage.chat == 'night' ? ChatChannel.family : ChatChannel.day;
}

class _TutorialReactions implements ReactionsRepository {
  final TutorialTable _table;

  _TutorialReactions(this._table);

  @override
  Future<int?> send(String roomId, String toSeat, TableGesture gesture) async {
    _table._toss(TutorialTable.you, toSeat, gesture);
    return _table._reactionIds;
  }

  @override
  Stream<List<TableReaction>> watch(String roomId) =>
      _table._snapshotStream(_table._gestures.stream, () => [..._table._reactions]);

  @override
  Future<Set<TableGesture>> owned() async => const {};
}

Map<String, Object?> _wire(Map<String, Object?> json) => jsonDecode(jsonEncode(json)) as Map<String, Object?>;
