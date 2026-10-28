import 'dart:math';

import '../../rules/game_engine.dart';
import '../../rules/game_settings.dart';
import '../../rules/game_setup.dart';
import '../../rules/game_snapshot.dart';
import '../../rules/intent.dart';
import '../../rules/player.dart';
import '../../rules/role.dart';
import '../../table/seating.dart';
import 'bot_brain.dart';
import 'game_events.dart';
import 'game_backend.dart';
import 'game_protocol.dart';
import 'game_schedule.dart';
import 'progress.dart' show Feats;

// La partita online gira sul server. Questo file è puro Dart (niente
// Flutter): si compila in JavaScript con `tool/edge/build.sh` e lo chiama la
// Edge Function `supabase/functions/game`. I test e il server finto
// (`fake_online.dart`) chiamano lo stesso [serverStep], con lo stesso JSON.
//
// Tutto va con l'orologio del server. Ogni fase ([Stage]) ha un inizio e una
// fine decisi qui e pubblicati sul tavolo; i telefoni cambiano schermata da
// soli a quelle ore. Una fase si chiude prima solo se hanno finito tutti: di
// notte e al voto quando hanno agito tutti i vivi, nelle altre quando tutti i
// vivi collegati hanno confermato (carta vista, film finito, pronto). Chi non
// è collegato non blocca nessuno: allo scadere chi non ha scelto passa, chi
// non ha votato si astiene.

/// Le regole della partita online.
const onlineSettings = GameSettings(
  night: OnlinePacing.defaultNight,
  discussion: OnlinePacing.defaultDiscussion,
  vote: OnlinePacing.defaultVote,
);

/// Quello che esce da un passo del server, pronto per il database: lo stato
/// segreto da salvare, il tavolo pubblico, una vista per ogni posto umano e
/// chi può scrivere in quale chat.
class ServerStep {
  /// Falso se non è cambiato niente: non si pubblica nulla.
  final bool changed;
  final int version;

  /// Lo stato segreto (motore compreso). Lo legge solo il server.
  final Map<String, Object?> state;
  final Map<String, Object?> board;
  final Map<String, Map<String, Object?>> seatViews;

  /// L'ultima intenzione gestita: quelle fino a qui si cancellano.
  final int? lastIntent;

  /// Quando il server deve tornare a guardare questa partita (un bot, una
  /// scadenza), anche se nessuno manda niente. Null: mai più.
  final DateTime? nextDue;
  final bool finished;

  /// Le chat: `mode` (`day`, `night`, `closed`) e per ogni posto se è vivo,
  /// se è della famiglia, se il Sarto gli ha cucito la bocca. Il database
  /// lo tiene in tabelle che nessun telefono legge.
  final Map<String, Object?> chat;

  /// I posti umani che in questo passo hanno lasciato la città (telefono
  /// spento oltre la tolleranza): il database lo annota.
  final List<String> departed;

  /// At the end of a game with a winner: the winning team and, for every
  /// human seat, its team, role, whether it survived and whether it left
  /// town. The server settles experience and ratings from it. Null before.
  final Map<String, Object?>? result;

  /// The lines for the chat (see game_events.dart): `{to, kind, data}`,
  /// `to` null for everyone or the only seat that may read it.
  final List<Map<String, Object?>> events;

  const ServerStep({
    required this.changed,
    required this.version,
    required this.state,
    required this.board,
    required this.seatViews,
    required this.lastIntent,
    required this.nextDue,
    required this.finished,
    required this.chat,
    this.departed = const [],
    this.result,
    this.events = const [],
  });

  Map<String, Object?> toJson() => {
        'changed': changed,
        'version': version,
        'state': state,
        'board': board,
        'seatViews': seatViews,
        'lastIntent': lastIntent,
        'nextDue': nextDue?.millisecondsSinceEpoch,
        'finished': finished,
        'chat': chat,
        'departed': departed,
        'result': result,
        'events': events,
      };
}

/// Il passo del server, tutto in JSON: è la funzione che la Edge Function
/// chiama. In ingresso:
///
/// - `state`: lo stato salvato dal passo precedente, o null per dare le carte;
/// - `seats`: i posti, come li ha registrati il database
///   (`[{seat, profile_id, name}]`, servono solo per dare le carte);
/// - `language`: `it` o `en`;
/// - `now`: l'ora del database, in millisecondi;
/// - `intents`: le intenzioni ancora da gestire (`[{id, seat, intent}]`);
/// - `chat`: i messaggi della piazza (`[{id, seat}]`, `id` è il numero `n`
///   del messaggio nella piazza, quelli dopo `state.lastChat`): contano come
///   partecipazione, il testo non serve. Mai quelli della famiglia: non
///   devono cambiare niente di ciò che vedono gli altri;
/// - `seen`: per ogni posto umano, l'ultima volta che il suo telefono si è
///   fatto sentire (millisecondi; null o assente: tutti collegati);
/// - `seed` (facoltativo, per i test): il seme di carte e bot.
///
/// In uscita un [ServerStep] in JSON. Non lancia per un'intenzione storta:
/// quella torna rifiutata a chi l'ha mandata.
Map<String, Object?> serverStep(Map<String, Object?> input, {OnlinePacing pacing = const OnlinePacing()}) {
  final seed = (input['seed'] as num?)?.toInt();
  final random = seed == null ? Random.secure() : Random(seed);
  final now = DateTime.fromMillisecondsSinceEpoch((input['now'] as num).toInt());
  final stateJson = input['state'] as Map<String, Object?>?;
  final game = stateJson == null
      ? ServerGame.deal(
          seats: [for (final row in (input['seats'] as List<Object?>)) SeatPlan.fromJson(row as Map<String, Object?>)],
          language: input['language'] as String? ?? 'it',
          now: now,
          random: random,
          pacing: pacing,
        )
      : ServerGame.fromJson(stateJson, random: random);
  final intents = [
    for (final row in (input['intents'] as List<Object?>? ?? const [])) IntentEnvelope.fromJson(row as Map<String, Object?>),
  ];
  final seen = (input['seen'] as Map?)?.map(
    (key, value) => MapEntry(key as String, DateTime.fromMillisecondsSinceEpoch((value as num).toInt())),
  );
  final chat = [
    for (final row in (input['chat'] as List<Object?>? ?? const []))
      (id: ((row as Map)['id'] as num).toInt(), seat: row['seat'] as String?),
  ];
  return game.step(now: now, intents: intents, chat: chat, seen: seen, pacing: pacing, fresh: stateJson == null).toJson();
}

/// Una partita sul server, fra un passo e l'altro: il motore (con tutti i
/// ruoli), chi siede dove, la fase in corso con le sue ore, le conferme
/// arrivate, i turni dei bot e la risposta all'ultima intenzione di
/// ciascuno. Vive solo nel database, in una tabella che nessun telefono può
/// leggere.
class ServerGame {
  final Seating seating;
  final String language;
  final int narrationSeed;
  final GameEngine engine;
  final Random _random;
  final BotBrain _brain;

  int version;
  int lastIntent;
  StageWindow window;

  /// Chi ha confermato la fase in corso.
  final Set<String> acks;

  /// Le scadenze di fila senza che una persona abbia mandato niente.
  int idle;

  /// Vero se una persona ha mandato qualcosa dall'ultima scadenza.
  bool _heard;
  bool abandoned;
  final Map<String, Map<String, Object?>> receipts;

  /// Quando ogni bot agisce, nella fase in corso.
  final Map<String, DateTime> botDue;

  /// Al voto e di notte, dopo un voto o un'azione la fase resta aperta
  /// almeno fino a qui: così l'ultimo voto si vede prima della chiusura.
  DateTime? settleUntil;

  /// Quanto resta visibile l'ultimo voto prima che la fase chiuda.
  static const settle = Duration(milliseconds: 2500);

  /// I posti umani offline adesso, e quelli che hanno lasciato la città.
  final Set<String> offline;
  final List<String> departed;

  /// La presenza di ogni persona, turno per turno (vedi [Attendance]).
  final Map<String, Attendance> attendance;

  /// Chi ha mandato qualcosa (mossa, voto, conferma, chat) nel turno in
  /// corso: si azzera a ogni notte e a ogni voto chiusi.
  final Set<String> spoke;

  /// L'ultimo messaggio di chat già contato.
  int lastChat;

  /// Quante giornate (discussioni) si sono aperte.
  int days;

  /// What each person did that missions and achievements count (see
  /// [Feats]): seat → feat → how many times. Server side only.
  final Map<String, Map<String, int>> feats;

  /// What the chat has already been told.
  final EventMarks marks;

  /// Private lines written while a phase closed, for this step's events.
  final List<Map<String, Object?>> _closing = [];

  /// La mano di prova: i bot non pensano da soli (le loro mosse arrivano
  /// come intenzioni, dal copione), e la notte e il voto chiudono appena
  /// hanno agito tutti, senza aspettare l'orologio. Non si salva: vive solo
  /// sul telefono, mai sul server.
  bool scripted = false;

  ServerGame._({
    required this.seating,
    required this.language,
    required this.narrationSeed,
    required this.engine,
    required Random random,
    required this.window,
    this.version = 0,
    this.lastIntent = 0,
    this.idle = 0,
    this._heard = false,
    this.abandoned = false,
    Set<String>? acks,
    Map<String, Map<String, Object?>>? receipts,
    Map<String, DateTime>? botDue,
    Set<String>? offline,
    List<String>? departed,
    Map<String, Attendance>? attendance,
    Set<String>? spoke,
    Map<String, Map<String, int>>? feats,
    EventMarks? marks,
    this.lastChat = 0,
    this.days = 0,
    this.settleUntil,
  })  : _random = random,
        attendance = attendance ?? {},
        spoke = spoke ?? {},
        feats = feats ?? {},
        marks = marks ?? EventMarks(),
        offline = offline ?? {},
        departed = departed ?? [],
        _brain = BotBrain(random),
        acks = acks ?? {},
        receipts = receipts ?? {},
        botDue = botDue ?? {};

  /// Apre la partita: le carte le dà il server, con il suo caso. Si comincia
  /// guardando la propria carta.
  factory ServerGame.deal({
    required List<SeatPlan> seats,
    required String language,
    required DateTime now,
    required Random random,
    OnlinePacing pacing = const OnlinePacing(),
  }) {
    final ordered = [...seats]..sort((a, b) => _seatNumber(a.seat).compareTo(_seatNumber(b.seat)));
    final seating = Seating([
      for (final plan in ordered) Occupant(seat: plan.seat, name: plan.name, profileId: plan.profileId),
    ]);
    final engine = GameEngine(
      GameSetup.deal(lobby: seating.players, random: random, mode: PlayMode.online),
      settings: GameSettings(night: pacing.night, discussion: pacing.discussion, vote: pacing.vote),
      seed: random.nextInt(seedRange),
    );
    return ServerGame._(
      seating: seating,
      language: language == 'en' ? 'en' : 'it',
      narrationSeed: random.nextInt(1 << 30),
      engine: engine,
      random: random,
      window: StageWindow.open(Stage.reveal, 1, now, pacing.reveal, pacing),
    );
  }

  /// La mano di prova: carte date a mano, posto per posto, e un dado fisso.
  factory ServerGame.scripted({
    required List<SeatPlan> seats,
    required Map<String, Role> roles,
    required String language,
    required DateTime now,
    required int seed,
    OnlinePacing pacing = const OnlinePacing(),
  }) {
    final seating = Seating([
      for (final plan in seats) Occupant(seat: plan.seat, name: plan.name, profileId: plan.profileId),
    ]);
    final random = Random(seed);
    final engine = GameEngine(
      GameSetup.fromRoles({for (final player in seating.players) player: roles[player.id]!}),
      settings: GameSettings(night: pacing.night, discussion: pacing.discussion, vote: pacing.vote),
      seed: seed,
    );
    return ServerGame._(
      seating: seating,
      language: language == 'en' ? 'en' : 'it',
      narrationSeed: seed,
      engine: engine,
      random: random,
      window: StageWindow.open(Stage.reveal, 1, now, pacing.reveal, pacing),
    )..scripted = true;
  }

  factory ServerGame.fromJson(Map<String, Object?> json, {required Random random}) {
    final seating = Seating.fromJson(json['seating'] as Map<String, Object?>);
    Map<String, Object?> map(String key) => (json[key] as Map?)?.cast<String, Object?>() ?? const {};
    return ServerGame._(
      seating: seating,
      language: json['language'] as String,
      narrationSeed: (json['narrationSeed'] as num).toInt(),
      engine: GameEngine.fromSnapshot(GameSnapshot.fromJson(json['snapshot'] as Map<String, Object?>, seating.playerAt)),
      random: random,
      window: StageWindow.fromJson(json['window'] as Map<String, Object?>),
      version: (json['version'] as num).toInt(),
      lastIntent: (json['lastIntent'] as num?)?.toInt() ?? 0,
      idle: (json['idle'] as num?)?.toInt() ?? 0,
      heard: json['heard'] == true,
      abandoned: json['abandoned'] == true,
      acks: {for (final seat in (json['acks'] as List<Object?>? ?? const [])) seat as String},
      receipts: {
        for (final MapEntry(:key, :value) in map('receipts').entries) key: (value as Map).cast<String, Object?>(),
      },
      botDue: {
        for (final MapEntry(:key, :value) in map('botDue').entries)
          key: DateTime.fromMillisecondsSinceEpoch((value as num).toInt()),
      },
      offline: {for (final seat in (json['offline'] as List<Object?>? ?? const [])) seat as String},
      departed: [for (final seat in (json['departed'] as List<Object?>? ?? const [])) seat as String],
      attendance: {
        for (final MapEntry(:key, :value) in map('attendance').entries)
          key: Attendance.fromJson((value as Map).cast<String, Object?>()),
      },
      spoke: {for (final seat in (json['spoke'] as List<Object?>? ?? const [])) seat as String},
      feats: {
        for (final MapEntry(:key, :value) in map('feats').entries)
          key: {
            for (final MapEntry(key: feat, value: n) in (value as Map).cast<String, Object?>().entries)
              feat: (n as num).toInt(),
          },
      },
      marks: EventMarks.fromJson((json['marks'] as Map?)?.cast<String, Object?>()),
      lastChat: (json['lastChat'] as num?)?.toInt() ?? 0,
      days: (json['days'] as num?)?.toInt() ?? 0,
      settleUntil: json['settleUntil'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch((json['settleUntil'] as num).toInt()),
    );
  }

  Map<String, Object?> toJson() => {
        'version': version,
        'snapshot': engine.snapshot().toJson(),
        'seating': seating.toJson(),
        'narrationSeed': narrationSeed,
        'language': language,
        'lastIntent': lastIntent,
        'window': window.toJson(),
        'acks': [...acks]..sort(),
        'idle': idle,
        'heard': _heard,
        'abandoned': abandoned,
        'receipts': receipts,
        'botDue': {for (final MapEntry(:key, :value) in botDue.entries) key: value.millisecondsSinceEpoch},
        'offline': [...offline]..sort(),
        'departed': departed,
        'attendance': {for (final MapEntry(:key, :value) in attendance.entries) key: value.toJson()},
        'spoke': [...spoke]..sort(),
        if (feats.isNotEmpty) 'feats': feats,
        'marks': marks.toJson(),
        'lastChat': lastChat,
        'days': days,
        if (settleUntil != null) 'settleUntil': settleUntil!.millisecondsSinceEpoch,
      };

  static int _seatNumber(String seat) => int.tryParse(seat.substring(1)) ?? 0;

  Stage get stage => window.stage;

  bool get finished => stage == Stage.ended || abandoned;

  bool _isHuman(String seat) => seating.occupantOf(seat)?.profileId != null;

  bool _alive(String seat) => engine.isAlive(seating.playerAt(seat));

  /// Un passo: le intenzioni arrivate, poi i bot e le scadenze già passate
  /// a [now], e le fasi che hanno finito tutti. [seen]: quando ogni telefono
  /// si è fatto sentire l'ultima volta (null: tutti collegati). [fresh]: le
  /// carte appena date, da pubblicare.
  ServerStep step({
    required DateTime now,
    List<IntentEnvelope> intents = const [],
    List<({int id, String? seat})> chat = const [],
    Map<String, DateTime>? seen,
    OnlinePacing pacing = const OnlinePacing(),
    bool fresh = false,
  }) {
    var changed = fresh;
    // What was published before this step, to tell the chat what changed.
    final before = fresh ? null : _board();
    final beforeSeats = fresh ? const <String, Map<String, Object?>>{} : _views(stage.acceptsActions);
    for (final envelope in [...intents]..sort((a, b) => a.id.compareTo(b.id))) {
      if (envelope.id <= lastIntent) continue;
      lastIntent = envelope.id;
      changed = true;
      if (!_isHuman(envelope.seat)) {
        if (scripted && envelope.intent['type'] != 'ack' && _apply(envelope).accepted) _settle(now);
        continue;
      }
      _heard = true;
      // Partecipa chi manda qualcosa davvero: anche «passo» e l'astensione,
      // mai lo scadere del tempo.
      if (!finished) spoke.add(envelope.seat);
      if (envelope.intent['type'] == 'ack') {
        if (envelope.intent['stage'] == window.key) acks.add(envelope.seat);
        continue;
      }
      final result = _apply(envelope);
      if (result.accepted) _settle(now);
      receipts[envelope.seat] = {'token': envelope.token, 'result': result.toJson()};
    }
    for (final message in chat) {
      if (message.id <= lastChat) continue;
      lastChat = message.id;
      if (message.seat case final seat? when _isHuman(seat) && !finished) spoke.add(seat);
    }
    final gone = _presence(now, seen, pacing);
    if (gone.changed) changed = true;
    final connected = seen == null
        ? null
        : {for (final occupant in seating.occupants) if (!offline.contains(occupant.seat)) occupant.seat};
    while (!finished) {
      // L'attesa passata non trattiene più niente (e non è un appuntamento).
      if (settleUntil case final hold? when !now.isBefore(hold)) settleUntil = null;
      _scheduleBots(pacing);
      final bot = _dueBot(now);
      if (bot != null) {
        _botActs(bot);
        _settle(now);
        changed = true;
        continue;
      }
      final timedOut = !now.isBefore(window.due(pacing));
      if (timedOut || _everyoneDone(connected)) {
        final hold = settleUntil;
        if (hold != null && now.isBefore(hold)) break;
        _close(now, pacing, timedOut: timedOut);
        changed = true;
        continue;
      }
      break;
    }
    if (finished) botDue.clear();
    if (changed) version++;
    final accepting = stage.acceptsActions;
    final board = _board();
    final seatViews = {
      for (final occupant in seating.occupants)
        if (occupant.profileId != null) occupant.seat: _seatView(occupant.seat, accepting),
    };
    final events = !changed
        ? const <Map<String, Object?>>[]
        : [
            ..._closing,
            ...tableEvents(
              before: before,
              after: board,
              beforeSeats: beforeSeats,
              afterSeats: {for (final MapEntry(:key, :value) in seatViews.entries) key: value['view'] as Map<String, Object?>},
              marks: marks,
            ),
          ];
    _closing.clear();
    return ServerStep(
      changed: changed,
      version: version,
      state: toJson(),
      board: board,
      seatViews: seatViews,
      events: events,
      lastIntent: lastIntent == 0 ? null : lastIntent,
      nextDue: _soonest(nextDue(pacing), gone.next),
      finished: finished,
      chat: _chat(),
      departed: gone.departed,
      result: _result(),
    );
  }

  /// The public board, as published.
  Map<String, Object?> _board() => {
        ...publicPayload(
          engine: engine,
          seating: seating,
          narrationSeed: narrationSeed,
          language: language,
          deadline: finished ? null : window.endsAt,
          abandoned: abandoned,
        ),
        'schedule': window.toJson(),
        'offline': [...offline]..sort(),
        'departed': departed,
      };

  /// Every human seat's own view, as published.
  Map<String, Map<String, Object?>> _views(bool accepting) => {
        for (final occupant in seating.occupants)
          if (occupant.profileId != null)
            occupant.seat: _seatView(occupant.seat, accepting)['view'] as Map<String, Object?>,
      };

  String _name(String? seat) => seating.occupantOf(seat ?? '')?.name ?? '?';

  Map<String, Object?>? _result() {
    final winner = engine.winner;
    if (!finished || winner == null) return null;
    // Finita prima della seconda giornata perché qualcuno se n'è andato:
    // non paga nessuno (niente partite brevi fatte apposta).
    final short = days < 2 && departed.isNotEmpty;
    return {
      'short': short,
      'winner': winner.name,
      'seats': {
        for (final occupant in seating.occupants)
          if (occupant.profileId != null)
            occupant.seat: () {
              final view = engine.viewFor(occupant.seat);
              return {
                'team': view.team.name,
                'role': view.role.name,
                // Chi vince da solo (il Fesso linciato, il Piromane) vince
                // anche se la sua fazione no.
                'won': engine.hasWon(view.seat),
                'survived': _alive(occupant.seat),
                'abandoned': departed.contains(occupant.seat),
                'afk': !departed.contains(occupant.seat) && (attendance[occupant.seat]?.afk ?? false),
                'short': short,
                'feats': feats[occupant.seat] ?? const <String, int>{},
              };
            }(),
      },
    };
  }

  static DateTime? _soonest(DateTime? a, DateTime? b) => a == null || (b != null && b.isBefore(a)) ? b : a;

  /// Chi è offline, e chi non è tornato in tempo e lascia la città. Torna
  /// se è cambiato qualcosa, chi se n'è andato adesso e quando ricontrollare.
  ({bool changed, List<String> departed, DateTime? next}) _presence(
    DateTime now,
    Map<String, DateTime>? seen,
    OnlinePacing pacing,
  ) {
    if (seen == null) return (changed: false, departed: const [], next: null);
    var changed = false;
    if (finished) {
      // A partita finita nessuno se ne va più, ma chi torna si vede tornato.
      for (final seat in [...offline]) {
        final last = seen[seat];
        if (last != null && now.difference(last) < pacing.offlineAfter) {
          offline.remove(seat);
          changed = true;
        }
      }
      return (changed: changed, departed: const [], next: null);
    }
    final left = <String>[];
    DateTime? next;
    for (final occupant in seating.occupants) {
      final seat = occupant.seat;
      if (occupant.profileId == null) continue;
      // Chi non si è mai fatto sentire conta dall'inizio della partita.
      final last = seen[seat] ?? window.startsAt.subtract(pacing.lead);
      final away = now.difference(last);
      final isOffline = away >= pacing.offlineAfter;
      if (isOffline != offline.contains(seat)) {
        changed = true;
        isOffline ? offline.add(seat) : offline.remove(seat);
      }
      if (!_alive(seat) || departed.contains(seat)) continue;
      if (away >= pacing.offlineAfter + pacing.reconnectGrace) {
        departed.add(seat);
        left.add(seat);
        changed = true;
        if (engine.leaveTown(seating.playerAt(seat)) != null) _open(Stage.ended, now, Duration.zero, pacing);
        continue;
      }
      next = _soonest(next, last.add(isOffline ? pacing.offlineAfter + pacing.reconnectGrace : pacing.offlineAfter));
    }
    return (changed: changed, departed: left, next: next);
  }

  Map<String, Object?> _seatView(String seat, bool accepting) {
    final payload = seatPayload(engine.viewFor(seat), receipt: receipts[seat]);
    final view = payload['view'] as Map<String, Object?>;
    // Fuori dalla sua finestra una mossa non si può fare: il telefono non
    // la mostra nemmeno.
    if (!accepting) view['action'] = null;
    payload['acked'] = acks.contains(seat);
    return payload;
  }

  Map<String, Object?> _chat() {
    return {
      'mode': finished ? 'closed' : stage.chat,
      'seats': {
        for (final occupant in seating.occupants)
          if (occupant.profileId != null)
            occupant.seat: {
              'alive': _alive(occupant.seat),
              'family': engine.viewFor(occupant.seat).team == Team.mafia,
              // Il motore decide: il Sarto ha cucito, il Compare apre la
              // chat della famiglia anche di giorno.
              'silenced': stage.chat == 'day' && engine.viewFor(occupant.seat).silenced,
              'familyDay': stage.chat == 'day' && engine.viewFor(occupant.seat).familyChat,
            },
      },
    };
  }

  /// Il prossimo momento in cui c'è qualcosa da fare senza che nessuno mandi
  /// niente: il primo bot, o la fine della fase (più la tolleranza).
  DateTime? nextDue([OnlinePacing pacing = const OnlinePacing()]) {
    if (finished) return null;
    var soonest = window.due(pacing);
    for (final due in botDue.values) {
      if (due.isBefore(soonest)) soonest = due;
    }
    final hold = settleUntil;
    if (hold != null && hold.isBefore(soonest)) soonest = hold;
    return soonest;
  }

  IntentResult _apply(IntentEnvelope envelope) {
    if (finished) return const IntentRejected(IntentError.wrongPhase, 'la partita è finita');
    PlayerIntent intent;
    try {
      intent = PlayerIntent.fromJson(envelope.intent);
    } catch (_) {
      return const IntentRejected(IntentError.notYourAction, 'intenzione illeggibile');
    }
    if (intent.seat != envelope.seat) {
      return IntentRejected(IntentError.unknownSeat, '${envelope.seat} non può agire per ${intent.seat}');
    }
    if (!stage.acceptsActions) {
      return IntentRejected(IntentError.wrongPhase, 'adesso non si agisce (${stage.name})');
    }
    return engine.apply(intent);
  }

  /// La fase è finita per tutti prima del tempo? La notte e il voto durano
  /// sempre fino alla scadenza (si può cambiare scelta fino all'ultimo);
  /// altrove quando hanno confermato tutti i vivi collegati (e almeno uno è
  /// collegato: senza nessuno si va a tempo).
  bool _everyoneDone(Set<String>? connected) {
    switch (stage) {
      case Stage.night when scripted:
        return engine.nightComplete;
      case Stage.vote when scripted:
        return seating.occupants.every((o) => !_alive(o.seat) || engine.dayVotes.containsKey(seating.playerAt(o.seat)));
      case Stage.night:
      case Stage.vote:
      case Stage.ended:
        return false;
      default:
        final waiting = [
          for (final occupant in seating.occupants)
            if (occupant.profileId != null &&
                _alive(occupant.seat) &&
                (connected == null || connected.contains(occupant.seat)))
              occupant.seat,
        ];
        return waiting.isNotEmpty && waiting.every(acks.contains);
    }
  }

  void _open(Stage next, DateTime now, Duration length, OnlinePacing pacing) {
    window = StageWindow.open(next, engine.round, now, length, pacing);
    acks.clear();
    botDue.clear();
    settleUntil = null;
  }

  /// Un voto o un'azione appena applicati: la fase non chiude prima di
  /// [settle], perché tutti lo vedano.
  void _settle(DateTime now) {
    if (stage != Stage.vote && stage != Stage.night) return;
    final until = now.add(settle);
    if (settleUntil == null || settleUntil!.isBefore(until)) settleUntil = until;
  }

  /// Chiude la fase in corso e apre la prossima, con il suo anticipo.
  void _close(DateTime now, OnlinePacing pacing, {required bool timedOut}) {
    if (timedOut && (stage == Stage.night || stage == Stage.vote)) {
      idle = _heard ? 0 : idle + 1;
      _heard = false;
      if (idle >= pacing.idleTimeouts) {
        abandoned = true;
        return;
      }
    }
    switch (stage) {
      case Stage.reveal:
        _open(Stage.night, now, engine.settings.night, pacing);
      case Stage.night:
        _judgeTurn({
          for (final player in engine.pendingNightPlayers) player.id,
          for (final seat in spoke) if (_alive(seat)) seat,
        });
        for (final player in engine.pendingNightPlayers) {
          engine.apply(Pass(player.id));
        }
        // The private lines of the night, from the seats' own views.
        _closing.addAll(nightClosing(_views(true), _name));
        final choices = engine.nightChoices;
        final dawn = engine.resolveNight();
        _countNight(choices, dawn);
        if (dawn.attacks.isEmpty) {
          _open(Stage.dawn, now, pacing.dawn, pacing);
        } else {
          _open(Stage.dawnFilms, now, OnlinePacing.deathFilm * dawn.attacks.length, pacing);
        }
      case Stage.dawnFilms:
        _open(Stage.dawn, now, pacing.dawn, pacing);
      case Stage.dawn:
        if (engine.phase == GamePhase.ended) {
          _open(Stage.ended, now, Duration.zero, pacing);
        } else {
          days++;
          _open(Stage.discussion, now, engine.settings.discussion, pacing);
        }
      case Stage.discussion:
        _open(Stage.vote, now, engine.settings.vote, pacing);
      case Stage.vote:
        _judgeTurn({
          for (final occupant in seating.occupants)
            if (_alive(occupant.seat)) occupant.seat,
        });
        // The final tally, from the public board (votes are open).
        marks.tally = voteTally(_board());
        final votes = engine.dayVotes;
        final lynch = engine.closeDayVote();
        _countVote(votes, lynch);
        _open(Stage.verdictFilm, now, OnlinePacing.verdictFilm(condemns: lynch.condemned != null), pacing);
      case Stage.verdictFilm:
        _open(Stage.verdict, now, pacing.verdict, pacing);
      case Stage.verdict:
        if (engine.phase == GamePhase.ended) {
          _open(Stage.ended, now, Duration.zero, pacing);
        } else {
          _open(Stage.night, now, engine.settings.night, pacing);
        }
      case Stage.ended:
        break;
    }
  }

  void _feat(String seat, String feat) {
    if (!_isHuman(seat) || departed.contains(seat)) return;
    final mine = feats[seat] ??= {};
    mine[feat] = (mine[feat] ?? 0) + 1;
  }

  /// What a night was worth to missions and achievements: who saw the dawn,
  /// the Doctor's saves, the Detective's finds, the Sniper's hits and the
  /// family's kills.
  void _countNight(Map<Player, NightChoice> choices, DawnReport dawn) {
    for (final occupant in seating.occupants) {
      if (_alive(occupant.seat)) _feat(occupant.seat, Feats.nights);
    }
    final familyKilled = dawn.attacks.any((a) => a.source == AttackSource.family && a.isFatal);
    for (final MapEntry(key: actor, value: choice) in choices.entries) {
      final target = choice.target;
      if (target == null) continue;
      final role = engine.setup.roleOf(target);
      switch (choice.kind) {
        case NightTaskKind.protect:
          if (dawn.attacks.any((a) => a.target == target && a.outcome == AttackOutcome.healed)) {
            _feat(actor.id, Feats.saves);
          }
        case NightTaskKind.investigate:
          if (role.team == Team.mafia && role.apparentTeam == Team.mafia) _feat(actor.id, Feats.finds);
        case NightTaskKind.snipe:
          if (role.team == Team.mafia &&
              dawn.attacks.any((a) => a.target == target && a.source == AttackSource.sniper && a.isFatal)) {
            _feat(actor.id, Feats.snipes);
          }
        case NightTaskKind.kill:
          if (familyKilled) _feat(actor.id, Feats.kills);
        default:
          break;
      }
    }
  }

  /// What a vote was worth: a vote on a condemned mafioso is a good vote; on
  /// the Godfather, from the Detective, a famous one; a mafioso who sends an
  /// honest citizen to the gallows framed them.
  void _countVote(Map<Player, Player?> votes, LynchReport lynch) {
    final condemned = lynch.condemned;
    final role = lynch.role;
    if (condemned == null || role == null) return;
    for (final MapEntry(key: voter, value: target) in votes.entries) {
      if (target != condemned) continue;
      final mine = engine.setup.roleOf(voter);
      if (role.team == Team.mafia) _feat(voter.id, Feats.lynchHits);
      if (role == Role.padrino && mine == Role.detective) _feat(voter.id, Feats.godfather);
      if (mine.team == Team.mafia && role.team == Team.citizens) _feat(voter.id, Feats.framed);
    }
  }

  /// Chiude un turno (una notte, una giornata) per i posti umani vivi che
  /// avevano qualcosa da fare ([due]): chi non ha mandato niente è stato
  /// assente. I morti e chi ha lasciato la città non si giudicano più.
  void _judgeTurn(Set<String> due) {
    for (final seat in due) {
      if (!_isHuman(seat) || !_alive(seat) || departed.contains(seat)) continue;
      (attendance[seat] ??= Attendance()).record(present: spoke.contains(seat));
    }
    spoke.clear();
  }

  Duration _between(Duration low, Duration high) =>
      low + Duration(milliseconds: _random.nextInt(max(1, (high - low).inMilliseconds)));

  bool _botWaiting(String seat) {
    final player = seating.playerAt(seat);
    if (scripted || !engine.isAlive(player)) return false;
    return switch (stage) {
      Stage.night => engine.phase == GamePhase.night && engine.pendingNightPlayers.contains(player),
      Stage.vote => engine.phase == GamePhase.day && !engine.dayVotes.containsKey(player),
      _ => false,
    };
  }

  /// Ogni bot che deve agire in questa fase riceve la sua ora: dopo l'inizio,
  /// un po' di attesa come una persona che ci pensa, e sempre prima della fine.
  void _scheduleBots(OnlinePacing pacing) {
    for (final occupant in seating.occupants) {
      if (occupant.profileId != null) continue;
      final seat = occupant.seat;
      if (!_botWaiting(seat)) {
        botDue.remove(seat);
        continue;
      }
      if (botDue.containsKey(seat)) continue;
      final think = stage == Stage.night
          ? _between(pacing.botNightMin, pacing.botNightMax)
          : _between(pacing.botVoteMin, pacing.botVoteMax);
      final due = window.startsAt.add(think);
      final latest = window.endsAt.subtract(const Duration(seconds: 3));
      botDue[seat] = due.isAfter(latest) ? latest : due;
    }
  }

  String? _dueBot(DateTime now) {
    String? first;
    for (final MapEntry(key: seat, value: due) in botDue.entries) {
      if (due.millisecondsSinceEpoch == 0 || now.isBefore(due) || !_botWaiting(seat)) continue;
      if (first == null || due.isBefore(botDue[first]!)) first = seat;
    }
    return first;
  }

  void _botActs(String seat) {
    // Resta in botDue (agito) finché la fase non cambia: non agisce due volte.
    botDue[seat] = DateTime.fromMillisecondsSinceEpoch(0);
    // Il bot vede solo la sua vista, come un telefono.
    final intent = _brain.decide(engine.viewFor(seat)) ?? Pass(seat);
    if (!engine.apply(intent).accepted) engine.apply(Pass(seat));
  }
}

/// La presenza di una persona: i turni (notti con un compito, giornate col
/// voto) in cui era viva e doveva fare qualcosa, quelli in cui non ha mandato
/// niente, e la fila più lunga di turni muti. È assente per la partita chi è
/// stato muto in almeno il 70% dei turni E in almeno 3 di fila: chi vota
/// ogni giorno non lo è mai, anche se tace e di notte non fa niente.
class Attendance {
  int turns;
  int silent;
  int streak;
  int longest;

  Attendance({this.turns = 0, this.silent = 0, this.streak = 0, this.longest = 0});

  static const minTurns = 3;
  static const silentShare = 0.7;
  static const silentRun = 3;

  void record({required bool present}) {
    turns++;
    if (present) {
      streak = 0;
    } else {
      silent++;
      streak++;
      if (streak > longest) longest = streak;
    }
  }

  bool get afk => turns >= minTurns && silent >= silentShare * turns && longest >= silentRun;

  factory Attendance.fromJson(Map<String, Object?> json) => Attendance(
        turns: (json['turns'] as num?)?.toInt() ?? 0,
        silent: (json['silent'] as num?)?.toInt() ?? 0,
        streak: (json['streak'] as num?)?.toInt() ?? 0,
        longest: (json['longest'] as num?)?.toInt() ?? 0,
      );

  Map<String, Object?> toJson() => {'turns': turns, 'silent': silent, 'streak': streak, 'longest': longest};
}
