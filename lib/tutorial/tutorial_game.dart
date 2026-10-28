import 'dart:math';

import '../rules/game_engine.dart';
import '../rules/game_setup.dart';
import '../rules/intent.dart';
import '../rules/player.dart';
import '../rules/role.dart';

/// I momenti del tutorial, nell'ordine in cui arrivano.
enum TutorialBeat {
  welcome,
  card,
  night,
  finding,
  dawn,
  talk,
  vote,
  verdict,
  win,
  ready,
}

/// La partita di prova: sei posti, tu sei il Commissario, gli altri cinque
/// sono bot con il copione già scritto. Il motore è quello vero, il mazzo e
/// il dado sono fissi: la storia è sempre la stessa.
///
/// Notte 1: la Famiglia uccide Bruno, tu scopri Vito. Giorno 1: la piazza
/// lincia Vito. Notte 2: Carmela prova a prendere te, Dora ti salva, tu
/// scopri Carmela. Giorno 2: la piazza lincia Carmela e la città vince.
class TutorialGame {
  static const seed = 1931;

  final Player you;
  static const vito = Player(id: 'vito', name: 'Vito');
  static const bruno = Player(id: 'bruno', name: 'Bruno');
  static const carmela = Player(id: 'carmela', name: 'Carmela');
  static const dora = Player(id: 'dora', name: 'Dora');
  static const enzo = Player(id: 'enzo', name: 'Enzo');

  late final GameSetup setup = GameSetup.fromRoles({
    you: Role.detective,
    vito: Role.mafioso,
    bruno: Role.cittadino,
    carmela: Role.mafioso,
    dora: Role.medico,
    enzo: Role.cittadino,
  });
  late final GameEngine engine = GameEngine(setup, random: Random(seed));

  TutorialBeat beat = TutorialBeat.welcome;
  Exposure? finding;
  DawnReport? dawn;
  LynchReport? verdict;

  /// Chi ha votato chi, nell'ultimo giro: per le mani puntate.
  Map<Player, Player> votes = const {};

  /// Chi ha già detto la sua in piazza oggi: tu, dopo i bot.
  bool spoke = false;

  TutorialGame({String youName = 'Tu'}) : you = Player(id: 'you', name: youName);

  List<Player> get players => setup.players;
  int get round => engine.round;

  /// Chi va indagato e votato in questo giro.
  Player get suspect => round == 1 ? vito : carmela;

  /// Le mosse dei bot, notte per notte.
  Map<Player, Player?> get _botNight => round == 1
      ? {vito: bruno, carmela: bruno, dora: enzo, bruno: null, enzo: null}
      : {carmela: you, dora: you, enzo: null};

  /// I voti dei bot, giorno per giorno: i mafiosi votano altrove.
  Map<Player, Player> get _botVotes =>
      round == 1 ? {dora: vito, enzo: vito, carmela: enzo, vito: you} : {dora: carmela, enzo: carmela, carmela: you};

  /// Gli unici passi senza azione: si va avanti col pulsante.
  bool get passive => switch (beat) {
    TutorialBeat.night || TutorialBeat.talk || TutorialBeat.vote || TutorialBeat.ready => false,
    _ => true,
  };

  void next() {
    switch (beat) {
      case TutorialBeat.welcome:
        beat = TutorialBeat.card;
      case TutorialBeat.card:
        beat = TutorialBeat.night;
      case TutorialBeat.finding:
        dawn = engine.resolveNight();
        spoke = false;
        beat = TutorialBeat.dawn;
      case TutorialBeat.dawn:
        beat = TutorialBeat.talk;
      case TutorialBeat.verdict:
        beat = engine.winner == null ? TutorialBeat.night : TutorialBeat.win;
      case TutorialBeat.win:
        beat = TutorialBeat.ready;
      case TutorialBeat.night || TutorialBeat.talk || TutorialBeat.vote || TutorialBeat.ready:
        throw StateError('$beat aspetta una mossa');
    }
  }

  /// Di notte il Commissario indaga: solo sul sospettato del copione.
  void investigate(Player target) {
    if (beat != TutorialBeat.night || target != suspect) throw StateError('non è il momento');
    finding = engine.submitNightChoice(you, target);
    _botNight.forEach(engine.submitNightChoice);
    beat = TutorialBeat.finding;
  }

  /// In piazza dici quello che hai scoperto.
  void speak() {
    if (beat != TutorialBeat.talk) throw StateError('non è il momento');
    spoke = true;
    beat = TutorialBeat.vote;
  }

  /// Punti il dito: votano tutti, e la piazza decide.
  void vote(Player target) {
    if (beat != TutorialBeat.vote || target != suspect) throw StateError('non è il momento');
    votes = {you: target, ..._botVotes};
    votes.forEach((voter, accused) => engine.apply(DayVote(voter.id, accused.id)));
    verdict = engine.closeDayVote();
    beat = TutorialBeat.verdict;
  }
}
