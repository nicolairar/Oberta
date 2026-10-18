import '../../rules/game_settings.dart';

// Le fasi della partita online e le loro ore. Puro Dart: lo usano il server
// (che le decide) e i telefoni (che le seguono).

/// Le fasi della partita online, nell'ordine in cui si susseguono. Ogni
/// telefono mostra la schermata della fase in corso, dall'inizio alla fine
/// decisi dal server.
enum Stage {
  /// Ognuno guarda la propria carta. Si chiude quando l'hanno vista tutti.
  reveal(chat: 'night'),

  /// Le mosse della notte, tutte insieme.
  night(chat: 'night', acceptsActions: true),

  /// I film degli agguati, uno dopo l'altro, per tutti nello stesso momento.
  dawnFilms,

  /// Il racconto dell'alba.
  dawn,

  /// Si discute in piazza (si scrive nella chat del giorno).
  discussion(chat: 'day'),

  /// Si vota.
  vote(chat: 'day', acceptsActions: true),

  /// Il film del verdetto.
  verdictFilm,

  /// La carta del condannato, o l'assoluzione.
  verdict,

  /// Fine: le carte si scoprono.
  ended;

  /// La chat aperta in questa fase: `day` (la piazza, per i vivi), `night`
  /// (solo la famiglia), `closed`.
  final String chat;

  /// Vero se il server accetta mosse in questa fase.
  final bool acceptsActions;

  const Stage({this.chat = 'closed', this.acceptsActions = false});

  /// Le fasi in cui ogni telefono conferma di aver finito (carta vista,
  /// film finito, letto): quando l'hanno fatto tutti si va avanti.
  bool get acknowledged => !acceptsActions && this != ended;
}

/// I tempi della partita online. Ogni fase dura al massimo quanto scritto
/// qui; i film durano esattamente quanto i film.
class OnlinePacing {
  static const defaultNight = GameSettings.defaultNight;
  static const defaultDiscussion = GameSettings.defaultDiscussion;
  static const defaultVote = GameSettings.defaultVote;

  /// Un film d'agguato (`DeathScene.length`).
  static const deathFilm = Duration(seconds: 14);

  /// Il film del verdetto (`VerdictScene.length`): la condanna è più lunga
  /// dell'assoluzione.
  static Duration verdictFilm({required bool condemns}) =>
      condemns ? const Duration(seconds: 11) : const Duration(seconds: 7);

  /// Fra la pubblicazione di una fase e il suo inizio: il tempo perché
  /// arrivi a tutti, così tutti cambiano schermata insieme.
  final Duration lead;

  /// Dopo la fine, prima di chiudere davvero: le mosse dei telefoni in
  /// ritardo arrivano ancora.
  final Duration grace;

  final Duration reveal;
  final Duration night;
  final Duration dawn;
  final Duration discussion;
  final Duration vote;
  final Duration verdict;

  /// Quanto ci mette un bot a scegliere, dall'inizio della fase.
  final Duration botNightMin;
  final Duration botNightMax;
  final Duration botVoteMin;
  final Duration botVoteMax;

  /// Senza notizie da un telefono per tanto, il suo posto è «offline» per
  /// tutti: non blocca più nessuno (allo scadere passa o si astiene), ma
  /// resta in gioco. I brevi buchi di rete sotto questa soglia non contano.
  final Duration offlineAfter;

  /// Da offline, il tempo per tornare. Poi il personaggio lascia la città:
  /// esce come un morto e la sua carta si scopre.
  final Duration reconnectGrace;

  /// Quante notti o votazioni di fila possono scadere senza che una persona
  /// tocchi il telefono, prima che il server chiuda la partita.
  final int idleTimeouts;

  const OnlinePacing({
    this.lead = const Duration(milliseconds: 1500),
    this.grace = const Duration(seconds: 2),
    this.reveal = const Duration(seconds: 15),
    this.night = defaultNight,
    this.dawn = const Duration(seconds: 15),
    this.discussion = defaultDiscussion,
    this.vote = defaultVote,
    this.verdict = const Duration(seconds: 10),
    this.botNightMin = const Duration(milliseconds: 1500),
    this.botNightMax = const Duration(seconds: 6),
    this.botVoteMin = const Duration(seconds: 3),
    this.botVoteMax = const Duration(seconds: 15),
    this.offlineAfter = const Duration(seconds: 15),
    this.reconnectGrace = const Duration(seconds: 60),
    this.idleTimeouts = 4,
  });
}

/// Una fase con le sue ore, come la pubblica il server: [startsAt] è già un
/// po' dopo la pubblicazione ([OnlinePacing.lead]).
class StageWindow {
  final Stage stage;
  final int round;
  final DateTime startsAt;
  final DateTime endsAt;

  const StageWindow({required this.stage, required this.round, required this.startsAt, required this.endsAt});

  factory StageWindow.open(Stage stage, int round, DateTime now, Duration length, OnlinePacing pacing) {
    final start = now.add(pacing.lead);
    return StageWindow(stage: stage, round: round, startsAt: start, endsAt: start.add(length));
  }

  /// Il nome di questa fase, unico nella partita: le conferme lo citano.
  String get key => '${stage.name}-$round';

  Duration get length => endsAt.difference(startsAt);

  /// Quando il server la chiude se non hanno finito tutti prima.
  DateTime due(OnlinePacing pacing) => endsAt.add(pacing.grace);

  Map<String, Object?> toJson() => {
        'stage': stage.name,
        'round': round,
        'key': key,
        'startsAt': startsAt.millisecondsSinceEpoch,
        'endsAt': endsAt.millisecondsSinceEpoch,
      };

  factory StageWindow.fromJson(Map<String, Object?> json) => StageWindow(
        stage: Stage.values.byName(json['stage'] as String),
        round: (json['round'] as num).toInt(),
        startsAt: DateTime.fromMillisecondsSinceEpoch((json['startsAt'] as num).toInt()),
        endsAt: DateTime.fromMillisecondsSinceEpoch((json['endsAt'] as num).toInt()),
      );
}
