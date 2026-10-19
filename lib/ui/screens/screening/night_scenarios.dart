import '../../../rules/game_engine.dart';
import '../../../rules/game_setup.dart';
import '../../../rules/intent.dart';
import '../../../rules/player.dart';
import '../../../rules/role.dart';

/// Com'è andata una notte di prova: il motore vero, dopo le mosse scritte.
class ScenarioRun {
  final GameEngine engine;
  final List<Player> players;
  final DawnReport dawn;
  final LynchReport? lynch;

  /// Il Sindaco che si è rivelato prima del voto.
  final Player? mayor;

  /// I voti della piazza, se c'è stato un voto.
  final Map<Player, Player?> votes;

  const ScenarioRun({
    required this.engine,
    required this.players,
    required this.dawn,
    this.lynch,
    this.mayor,
    this.votes = const {},
  });
}

/// Una notte da rivedere: titolo e riassunto in italiano e in inglese, e
/// come giocarla.
class NightScenario {
  final String id;
  final ({String it, String en}) title;
  final ({String it, String en}) blurb;
  final ScenarioRun Function() run;

  const NightScenario(this.id, {required this.title, required this.blurb, required this.run});

  String titleIn(bool italian) => italian ? title.it : title.en;
  String blurbIn(bool italian) => italian ? blurb.it : blurb.en;
}

/// Il tavolo: otto sedie, gli stessi nomi in ogni prova.
class _Table {
  final Map<String, Player> _byName = {};
  late final GameEngine engine;

  _Table(List<(String, Role)> seats, {int seed = 7}) {
    final roles = <Player, Role>{};
    for (final (name, role) in seats) {
      final player = Player(id: name.toLowerCase(), name: name);
      _byName[name] = player;
      roles[player] = role;
    }
    engine = GameEngine(GameSetup.fromRoles(roles), seed: seed);
  }

  Player operator [](String name) => _byName[name]!;
  List<Player> get players => engine.setup.players;

  /// Le mosse della notte ([moves]: chi → su chi); chi non c'è passa.
  DawnReport night(Map<String, String> moves, {Set<String> alternative = const {}}) {
    for (final MapEntry(:key, :value) in moves.entries) {
      engine.submitNightChoice(this[key], this[value], alternative: alternative.contains(key));
    }
    for (final player in engine.pendingNightPlayers) {
      engine.submitNightChoice(player, null);
    }
    return engine.resolveNight();
  }

  /// La piazza vota ([votes]: chi → contro chi) e chiude.
  ({LynchReport report, Map<Player, Player?> votes}) vote(Map<String, String> votes) {
    for (final MapEntry(:key, :value) in votes.entries) {
      final result = engine.apply(DayVote(this[key].id, this[value].id));
      if (result is IntentRejected) throw StateError('voto respinto: $key → $value');
    }
    final cast = engine.dayVotes;
    return (report: engine.closeDayVote(), votes: cast);
  }

  ScenarioRun done(DawnReport dawn, {LynchReport? lynch, Player? mayor, Map<Player, Player?> votes = const {}}) =>
      ScenarioRun(engine: engine, players: players, dawn: dawn, lynch: lynch, mayor: mayor, votes: votes);
}

/// Le otto sedie di base: due della famiglia, sei in città. [extra]
/// sostituisce i ruoli di qualcuno.
_Table _table(Map<String, Role> extra, {int seed = 7}) => _Table([
  for (final (name, role) in const [
    ('Tano', Role.mafioso),
    ('Rocco', Role.mafioso),
    ('Anna', Role.cittadino),
    ('Bruno', Role.cittadino),
    ('Carla', Role.cittadino),
    ('Dario', Role.cittadino),
    ('Elsa', Role.cittadino),
    ('Fede', Role.cittadino),
  ])
    (name, extra[name] ?? role),
], seed: seed);

final nightScenarios = <NightScenario>[
  NightScenario(
    'doctor-save',
    title: (it: 'Il Dottore salva', en: 'The Doctor saves'),
    blurb: (
      it: 'La famiglia spara ad Anna, ma il Dottore era al suo capezzale.',
      en: 'The Family shoots Anna, but the Doctor was at her bedside.',
    ),
    run: () {
      final t = _table({'Bruno': Role.medico});
      return t.done(t.night({'Tano': 'Anna', 'Rocco': 'Anna', 'Bruno': 'Anna'}));
    },
  ),
  NightScenario(
    'family-and-hitman',
    title: (it: 'Famiglia e Sicario', en: 'Family and Hitman'),
    blurb: (
      it: 'La famiglia uccide Anna, il Sicario per conto suo uccide Carla: due morti.',
      en: 'The Family kills Anna, the Hitman on his own kills Carla: two dead.',
    ),
    run: () {
      final t = _table({'Bruno': Role.sicario});
      return t.done(t.night({'Tano': 'Anna', 'Rocco': 'Anna', 'Bruno': 'Carla'}));
    },
  ),
  NightScenario(
    'same-target',
    title: (it: 'Stesso bersaglio', en: 'Same target'),
    blurb: (
      it: 'Famiglia e Sicario scelgono tutti e due Anna: un agguato solo, un morto.',
      en: 'Family and Hitman both pick Anna: a single attack, one dead.',
    ),
    run: () {
      final t = _table({'Bruno': Role.sicario});
      return t.done(t.night({'Tano': 'Anna', 'Rocco': 'Anna', 'Bruno': 'Anna'}));
    },
  ),
  NightScenario(
    'fire-and-family',
    title: (it: 'Rogo e agguato', en: 'Fire and ambush'),
    blurb: (
      it: 'Il Piromane accende Carla (cosparsa la notte prima) mentre la famiglia uccide Anna.',
      en: 'The Arsonist lights Carla (doused the night before) while the Family kills Anna.',
    ),
    run: () {
      final t = _table({'Bruno': Role.piromane});
      t.night({'Bruno': 'Carla'});
      t.engine.lynch(null);
      return t.done(t.night({'Tano': 'Anna', 'Rocco': 'Anna', 'Bruno': 'Bruno'}, alternative: {'Bruno'}));
    },
  ),
  NightScenario(
    'veteran',
    title: (it: 'La pelle dura del Reduce', en: "The Veteran's thick skin"),
    blurb: (
      it: 'La famiglia spara al Reduce Anna: il primo colpo non la ferma.',
      en: 'The Family shoots Anna the Veteran: the first hit does not stop her.',
    ),
    run: () {
      final t = _table({'Anna': Role.reduce});
      return t.done(t.night({'Tano': 'Anna', 'Rocco': 'Anna'}));
    },
  ),
  NightScenario(
    'bodyguard',
    title: (it: 'Il Guardaspalle si sacrifica', en: 'The Bodyguard takes the bullet'),
    blurb: (
      it: 'La famiglia spara ad Anna; Bruno, il suo Guardaspalle, prende il colpo e muore.',
      en: 'The Family shoots Anna; Bruno, her Bodyguard, takes the hit and dies.',
    ),
    run: () {
      final t = _table({'Bruno': Role.guardaspalle});
      return t.done(t.night({'Tano': 'Anna', 'Rocco': 'Anna', 'Bruno': 'Anna'}));
    },
  ),
  NightScenario(
    'loan-shark',
    title: (it: 'Lo Strozzino protegge', en: 'The Loan Shark protects'),
    blurb: (
      it: 'Lo Strozzino ha prestato soldi ad Anna: un debitore morto non paga, e il colpo va a vuoto.',
      en: 'The Loan Shark lent Anna money: a dead debtor does not pay, so the hit fails.',
    ),
    run: () {
      final t = _table({'Bruno': Role.strozzino});
      return t.done(t.night({'Tano': 'Anna', 'Rocco': 'Anna', 'Bruno': 'Anna'}));
    },
  ),
  NightScenario(
    'scoop',
    title: (it: 'Lo scoop del Cronista', en: "The Journalist's scoop"),
    blurb: (
      it: 'Il Cronista pubblica la squadra di Tano (famiglia); la famiglia uccide Anna.',
      en: "The Journalist prints Tano's team (Family); the Family kills Anna.",
    ),
    run: () {
      final t = _table({'Bruno': Role.giornalista});
      return t.done(t.night({'Tano': 'Anna', 'Rocco': 'Anna', 'Bruno': 'Tano'}));
    },
  ),
  NightScenario(
    'tailor',
    title: (it: 'Il Sarto cuce una bocca', en: 'The Tailor sews a mouth'),
    blurb: (
      it: 'Il Sarto cuce la bocca a Carla invece di votare; la famiglia uccide Anna.',
      en: 'The Tailor sews Carla’s mouth instead of voting; the Family kills Anna.',
    ),
    run: () {
      final t = _table({'Rocco': Role.sarto});
      return t.done(t.night({'Tano': 'Anna', 'Rocco': 'Carla'}, alternative: {'Rocco'}));
    },
  ),
  NightScenario(
    'messiah',
    title: (it: 'Il Messia resuscita', en: 'The Messiah resurrects'),
    blurb: (
      it: 'Carla, innocente, è stata linciata ieri; stanotte il Messia la riporta in vita.',
      en: 'Carla, innocent, was lynched yesterday; tonight the Messiah brings her back.',
    ),
    run: () {
      final t = _table({'Bruno': Role.messia});
      t.night({});
      t.engine.lynch(t['Carla']);
      return t.done(t.night({'Bruno': 'Carla'}));
    },
  ),
  NightScenario(
    'sniper',
    title: (it: 'Il Cecchino colpisce', en: 'The Sniper hits'),
    blurb: (
      it: 'Il Cecchino abbatte Tano della famiglia; la famiglia uccide Anna.',
      en: 'The Sniper takes down Tano of the Family; the Family kills Anna.',
    ),
    run: () {
      final t = _table({'Bruno': Role.cecchino});
      return t.done(t.night({'Tano': 'Anna', 'Rocco': 'Anna', 'Bruno': 'Tano'}));
    },
  ),
  NightScenario(
    'lynch-family',
    title: (it: 'Linciato uno della famiglia', en: 'A Family member lynched'),
    blurb: (
      it: 'Notte tranquilla; la piazza vota Tano, ed era della famiglia.',
      en: 'A quiet night; the square votes Tano, and he was Family.',
    ),
    run: () {
      final t = _table({});
      final dawn = t.night({});
      final day = t.vote({'Anna': 'Tano', 'Bruno': 'Tano', 'Carla': 'Tano', 'Tano': 'Anna'});
      return t.done(dawn, lynch: day.report, votes: day.votes);
    },
  ),
  NightScenario(
    'lynch-fool',
    title: (it: 'Linciato il Fesso', en: 'The Fool lynched'),
    blurb: (
      it: 'La piazza lincia Elsa, il Fesso: voleva proprio questo, e vince.',
      en: 'The square lynches Elsa, the Fool: it is what she wanted, and she wins.',
    ),
    run: () {
      final t = _table({'Elsa': Role.fesso});
      final dawn = t.night({});
      final day = t.vote({'Anna': 'Elsa', 'Bruno': 'Elsa', 'Tano': 'Elsa'});
      return t.done(dawn, lynch: day.report, votes: day.votes);
    },
  ),
  NightScenario(
    'lynch-bounty',
    title: (it: 'La taglia è pagata', en: 'The bounty is paid'),
    blurb: (
      it: 'La piazza lincia la taglia del Cacciatore Fede: lui incassa e la partita finisce.',
      en: "The square lynches Fede the Bounty Hunter's mark: he cashes in and the game ends.",
    ),
    run: () {
      final t = _table({'Fede': Role.cacciatore});
      final mark = t.engine.bountyOf(t['Fede'])!;
      final dawn = t.night({});
      final voters = [
        for (final p in t.players)
          if (p != mark) p.name,
      ].take(3);
      final day = t.vote({for (final v in voters) v: mark.name});
      return t.done(dawn, lynch: day.report, votes: day.votes);
    },
  ),
  NightScenario(
    'mayor',
    title: (it: 'Il Sindaco si rivela', en: 'The Mayor reveals'),
    blurb: (
      it: 'Dario si rivela Sindaco: il suo voto vale due e porta Rocco al patibolo.',
      en: 'Dario reveals as Mayor: his vote counts double and sends Rocco to the gallows.',
    ),
    run: () {
      final t = _table({'Dario': Role.sindaco});
      final dawn = t.night({});
      t.engine.revealMayor(t['Dario']);
      final day = t.vote({'Dario': 'Rocco', 'Tano': 'Anna'});
      return t.done(dawn, lynch: day.report, mayor: t['Dario'], votes: day.votes);
    },
  ),
  NightScenario(
    'quiet',
    title: (it: 'Nessun morto', en: 'Nobody dies'),
    blurb: (
      it: 'La famiglia non si mette d’accordo: all’alba sono tutti vivi.',
      en: 'The Family passes: at dawn everyone is alive.',
    ),
    run: () {
      final t = _table({});
      return t.done(t.night({}));
    },
  ),
];
