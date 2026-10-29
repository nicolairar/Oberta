import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../l10n/local_role_strings.dart';
import '../../narration/death_story.dart';
import '../../narration/narrator_script.dart';
import '../../rules/game_engine.dart';
import '../../rules/game_settings.dart';
import '../../rules/game_setup.dart';
import '../../rules/player.dart';
import '../../rules/role.dart';
import '../../sound/cue_sounds.dart';
import '../../sound/fx_groups.dart';
import '../../sound/meme_beat.dart';
import '../../sound/narrator_voice.dart';
import '../../sound/sound_stage.dart';
import '../theme/app_theme.dart';
import '../widgets/day_board.dart' show RevealRow;
import '../widgets/night_notes.dart' show alternativeLabels;
import '../desktop/desktop_canvas.dart';
import 'online/game/felt_text.dart';
import 'online/game/front_page.dart' show stampColorFor;
import 'online/game/saloon_table.dart' show SaloonBackdrop;
import '../../l10n/local_table_strings.dart';
import '../../l10n/player_gender.dart';
import '../../l10n/recap_strings.dart';
import '../../l10n/table_strings.dart';
import '../../rules/intent.dart';
import '../../rules/player_view.dart';
import 'local/local_table.dart';
import 'online/game/action_strip.dart';
import 'online/game/noir_ui.dart';
import 'online/game/verdict_line.dart';
import 'online/game/chronicle_headlines.dart';
import 'online/online_widgets.dart' show showNote;
import 'online/recap_screen.dart';
import '../widgets/content_width.dart';
import '../widgets/death_scene.dart';
import '../widgets/narrator_roles_sheet.dart';
import '../widgets/roles_sheet.dart';
import '../widgets/player_avatar.dart';
import '../widgets/noir_notice.dart';
import '../widgets/city_backdrop.dart';
import '../widgets/sky_events.dart';
import '../widgets/scene_scaffold.dart';
import '../widgets/script_page_view.dart';
import '../widgets/spoken_lines.dart';
import '../widgets/spoken_script_card.dart';
import '../press.dart';
import '../seating.dart';
import '../widgets/wide_scale.dart';
import '../widgets/noir_modal.dart';
import '../widgets/targa.dart';

/// La partita su un solo telefono: il copione si legge ad alta voce, di notte
/// il telefono fa il giro del tavolo, di giorno resta in mezzo.
class GameScreen extends StatefulWidget {
  final GameSetup setup;
  final GameSettings settings;
  final Random? random;

  /// Il dado che rimescola i tavoli segreti a ogni turno. Non tocca la
  /// partita: decide solo dove sta ognuno sullo schermo.
  final Random? seating;

  const GameScreen({
    super.key,
    required this.setup,
    this.settings = const GameSettings(),
    this.random,
    this.seating,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

enum _Stage { script, handoff, task, taskDone, crimeIntro, crime, toNarrator, day, power, shot, vote, verdict, end }

/// I poteri di giorno, davanti a tutti: la tregua del Pacifista, il colpo
/// dell'Artigliere.
enum _Power { truce, cannon, marksman }

class _GameScreenState extends State<GameScreen> {
  static const _mafiaRed = Color(0xFFE5606A);

  late final GameEngine _engine =
      GameEngine(widget.setup, settings: widget.settings, random: widget.random);

  /// La lingua della partita: quella in uso quando è cominciata. Copione e
  /// pulsanti restano in quella fino alla fine.
  late final AppStrings _t;
  late final NarratorScript _script;
  bool _started = false;

  _Stage _stage = _Stage.script;
  int _step = 0;
  String _title = '';
  SceneMood _mood = SceneMood.night;
  late ScriptPage _page;
  List<Player> _queue = const [];
  int _turn = 0;
  Player? _selected;

  /// Il Sarto ha scelto di cucire invece di votare l'agguato.
  bool _alternative = false;

  /// La cella sul telefono unico: la domanda scritta dal Carceriere e la
  /// risposta del prigioniero, notte per notte. Non escono mai dal telefono.
  final Map<int, String> _questions = {};
  final Map<int, String> _answers = {};

  /// Cupido ha scelto il primo innamorato e cerca il secondo.
  Player? _firstLover;

  /// La tregua del Pacifista o il colpo dell'Artigliere: chi lo usa
  /// (verificato), poi su chi.
  _Power _power = _Power.truce;

  /// Il colpo del Tiratore scelto, appena sparato.
  ShotReport? _marksmanShot;
  Player? _powerUser;

  /// L'ultimo colpo dell'Artigliere, e il copione da leggere.
  CannonShot? _shot;
  List<ScriptLine> _shotLines = const [];
  String? _powerError;
  late final LocalRoleStrings _lr = LocalRoleStrings(_t);
  Exposure? _finding;
  late DawnReport _dawn;
  // Il verdetto della piazza, sul tavolo.
  Player? _condemned;
  late LynchReport _verdict;
  List<ScriptLine> _verdictLines = const [];
  List<DeathStory> _deaths = const [];
  int _crime = 0;
  List<ScriptLine> _voteLines = const [];
  List<ScriptLine> _endingLines = const [];

  /// Il tavolo pubblico, sempre nello stesso ordine; e quello segreto di chi
  /// ha il telefono adesso, rimescolato a ogni mano (vedi `seating.dart`).
  late final List<Player> _table = publicSeating(widget.setup.players);
  late final Random _seating = widget.seating ?? Random();
  List<Player> _seats = const [];

  /// Il numero di posto di ognuno, lo stesso per tutta la partita: l'ordine
  /// in cui si sono seduti. Sui tavoli segreti cambia il posto, mai il numero.
  late final Map<Player, int> _numbers = {
    for (final (i, player) in widget.setup.players.indexed) player: i + 1,
  };

  late final TableStrings _ts = TableStrings(_t.language);
  late final LocalTableStrings _ls = LocalTableStrings(_t.language);

  /// Il voto della piazza, con il telefono in mezzo: chi vota, uno alla volta.
  List<Player> _voters = const [];
  int _voter = 0;

  /// I voti del verdetto: il motore li dimentica quando condanna.
  List<SeatVote> _lastVotes = const [];

  /// Il cronometro della discussione, nel cartiglio.
  Timer? _dayTimer;
  Duration _dayLeft = Duration.zero;

  Player? get _narrator => widget.setup.narrator;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _t = AppStrings.of(context);
    _script = NarratorScript(pack: _t.pack, random: widget.random);
    _enterNight();
  }

  void _advance(VoidCallback change) {
    // Si va avanti: se il narratore automatico stava ancora parlando, tace.
    NarratorVoice.instance.hush();
    setState(() {
      change();
      _selected = null;
      _alternative = false;
      _step++;
    });
  }

  void _enterNight() {
    final round = _engine.round;
    SoundStage.instance.music(MusicMood.night);
    // Cala la notte: il colpo che apre il capitolo, sotto la musica che cambia.
    SoundStage.instance.cue(Cue.nightfall);
    // Si comincia: la prima battuta della serata.
    if (round == 1) beat(MemeMoment.gameStart, after: const Duration(seconds: 1));
    _nightAtmosphere();
    _title = _t.nightTitle(round);
    // Prima il tramonto, poi la notte: il fondale scende con la pagina.
    _mood = SceneMood.dusk;
    _thunders.add(Timer(const Duration(milliseconds: 1400), () {
      if (mounted && _mood == SceneMood.dusk) setState(() => _mood = SceneMood.night);
    }));
    _stage = _Stage.script;
    _page = ScriptPage(
      icon: Icons.nightlight_round,
      title: round == 1 ? _script.city.title : _t.nightFalls,
      lines: [if (round == 1) ..._script.opening(), ..._script.nightFalls(round)],
      nightfall: true,
      action: _t.startTheNight,
      onAction: () => _advance(() {
        _queue = _engine.alivePlayers;
        _turn = 0;
        _stage = _Stage.handoff;
      }),
    );
  }

  /// La mossa della notte, come la manda il telefono online: un'intenzione
  /// che il motore valida. Che cosa si può fare lo dice il compito del ruolo,
  /// quindi un ruolo nuovo funziona anche qui senza toccare lo schermo.
  void _submit(Player? target) {
    final actor = _queue[_turn];
    final option = _engine.viewFor(actor.id).action;
    // Cupido lega in due tocchi: il primo si tiene da parte.
    if (target != null && option?.kind == NightTaskKind.link && _firstLover == null) {
      setState(() {
        _firstLover = target;
        _selected = null;
      });
      return;
    }
    final first = _firstLover;
    final family = option?.type == ActionType.mafiaVote && !_alternative;
    final PlayerIntent intent = target == null
        ? Pass(actor.id)
        : first != null
        ? Link(actor.id, first.id, target.id)
        : family
        ? MafiaVote(actor.id, target.id)
        : NightAction(actor.id, target.id);
    final result = _engine.apply(intent);
    _advance(() {
      _firstLover = null;
      _finding = result is IntentAccepted ? result.finding : null;
      _stage = _Stage.taskDone;
    });
  }

  void _afterTask() {
    _advance(() {
      if (_turn + 1 < _queue.length) {
        _turn++;
        _stage = _Stage.handoff;
        return;
      }
      // La notte è finita. Ogni agguato si compone una volta sola: la stessa
      // storia va prima in scena e poi nel copione del narratore.
      _dawn = _engine.resolveNight();
      _deaths = _script.stage(_dawn);
      SoundStage.instance.prepare([
        for (final story in _deaths) ...[filmFor(story).act, ?filmFor(story).save],
      ]);
      if (_deaths.isNotEmpty) {
        _crime = 0;
        _stage = _Stage.crimeIntro;
      } else if (_narrator != null) {
        _stage = _Stage.toNarrator;
      } else {
        _enterDawn();
      }
    });
  }

  void _afterCrime() {
    _advance(() {
      if (_crime + 1 < _deaths.length) {
        _crime++;
      } else {
        _enterDawn();
      }
    });
  }

  void _enterDawn() {
    final report = _dawn;
    final winner = report.winner;
    _dawnAtmosphere();
    // Il Cronista smaschera uno della famiglia: sus.
    if (report.scoop?.team == Team.mafia) beat(MemeMoment.scoop, after: const Duration(seconds: 2));
    // Nessun morto stanotte: la città l'ha scampata, e se la ride.
    if (report.victims.isEmpty) beat(MemeMoment.nobodyDied, after: const Duration(milliseconds: 1200));
    // Il Sarto ha cucito una bocca: lo vedono tutti sulla griglia.
    if (report.silenced != null) beat(MemeMoment.silenced, after: const Duration(seconds: 4));
    // Uno è morto di crepacuore: ora tutti sanno chi si amava.
    if (report.heartbroken.isNotEmpty) beat(MemeMoment.lovers, after: const Duration(seconds: 4));
    _title = _t.dawnTitle;
    _mood = SceneMood.dawn;
    _stage = _Stage.script;
    _page = ScriptPage(
      icon: Icons.wb_twilight,
      nightfall: false,
      title: report.victims.isEmpty ? _t.everyoneAlive : _t.crimePage,
      lines: _script.dawn(report, discussion: widget.settings.discussion, stories: _deaths),
      // Chi è morto, a lutto. Se non è morto nessuno, chi l'ha scampata.
      // Solo i morti: chi si è salvato resta anonimo.
      portraits: [
        for (final attack in report.attacks)
          if (attack.isFatal) attack.target.name,
      ],
      portraitsFallen: report.victims.isNotEmpty,
      action: winner != null ? _t.finale : _t.openTheFloor,
      onAction: () => _advance(() {
        if (winner != null) {
          _enterEnd(winner);
        } else {
          _title = _t.dayTitle(_engine.round);
          _startDay();
          _mood = SceneMood.day;
          SoundStage.instance.music(MusicMood.day);
          // La piazza di giorno: gli uccelli restano sotto, e dove c'è il
          // campanile suonano le ore, lontane.
          if (_hasBellTower && _atmosphere.nextBool()) _seenAndHeard(FxGroup.bellsfar, volume: 0.6);
          // La piazza di giorno: la strada sveglia, piano, sotto la discussione.
          SoundStage.instance.ambience(FxGroup.morningstreet);
          _stage = _Stage.day;
        }
      }),
    );
  }

  /// Il cronometro della discussione: parte all'apertura, si allunga di un
  /// minuto alla volta, suona allo scadere. Non chiude niente: il voto lo
  /// chiama il tavolo.
  void _startDay() {
    _dayTimer?.cancel();
    _dayLeft = widget.settings.discussion;
    _dayTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _dayLeft == Duration.zero || _stage != _Stage.day) return;
      setState(() => _dayLeft -= const Duration(seconds: 1));
      if (_dayLeft == Duration.zero) {
        if (beat(MemeMoment.timerEnd) == null) SoundStage.instance.cue(Cue.timeUp);
      } else if (_dayLeft <= const Duration(seconds: 10)) {
        if (_dayLeft == const Duration(seconds: 5)) beat(MemeMoment.timerEnd);
        SoundStage.instance.cue(Cue.tick);
      }
    });
  }

  /// Si vota a viso aperto, uno alla volta, nell'ordine dei posti.
  void _enterVote() {
    _dayTimer?.cancel();
    beat(MemeMoment.voteCall);
    _voteLines = _script.voteCall();
    _voters = [
      for (final player in widget.setup.players)
        if (_engine.isAlive(player)) player,
    ];
    _voter = 0;
    _stage = _Stage.vote;
  }

  /// Il voto di chi tocca adesso (`null`: si astiene). Dopo l'ultimo, si conta.
  void _castVote(Player? target) {
    final voter = _voters[_voter];
    final previous = _engine.dayVotes;
    if (target != null && previous[voter] != target) {
      beat(previous.values.contains(target) ? MemeMoment.voteChanged : MemeMoment.accused);
    }
    _engine.apply(target == null ? Pass(voter.id) : DayVote(voter.id, target.id));
    _advance(() {
      if (_voter + 1 < _voters.length) {
        _voter++;
        return;
      }
      _lastVotes = [for (final e in _engine.dayVotes.entries) (voter: e.key, target: e.value)];
      _enterVerdict(_engine.closeDayVote());
    });
  }

  Future<void> _revealMayor() async {
    final voter = _voters[_voter];
    final yes = await confirmNoir(
      context,
      key: const Key('local.askMayor'),
      title: _ts.revealMayorTitle,
      body: _ts.revealMayorBody,
      cancel: _ts.cancel,
      confirm: _ts.revealMayor,
    );
    if (!yes || !mounted || _stage != _Stage.vote) return;
    final result = _engine.apply(RevealMayor(voter.id));
    if (result is IntentRejected) {
      showNote(context, _ls.notTheMayor, kind: NoticeKind.error);
      return;
    }
    setState(() {});
  }

  /// La piazza ha votato e l'ha visto tutto il tavolo: niente film. Il posto
  /// del condannato fa il linciaggio sul posto e mostra la carta, se ora è
  /// pubblica; sotto, il copione del verdetto da leggere.
  void _enterVerdict(LynchReport report) {
    _verdict = report;
    final condemned = report.condemned;
    _condemned = condemned;
    if (report.role != null) SoundStage.instance.cue(report.role!.team == Team.mafia ? Cue.caught : Cue.drumroll);
    // Nessuna condanna: il silenzio imbarazzato della battuta che non ride nessuno.
    if (condemned == null) beat(MemeMoment.noConviction, after: const Duration(milliseconds: 600));
    if (report.heartbroken != null) beat(MemeMoment.lovers, after: const Duration(seconds: 4));
    _verdictLines = _script.lynch(report);
    _title = _t.verdictTitle;
    _mood = SceneMood.dusk;
    _stage = _Stage.verdict;
  }

  final _atmosphere = Random();
  final List<Timer> _thunders = [];

  T _pick<T>(List<T> options) => options[_atmosphere.nextInt(options.length)];

  /// La città di notte: ogni notte un po' diversa, mai la stessa tre volte.
  void _nightAtmosphere() {
    // Pioggia e tuoni solo quando sullo schermo piove: si sente quello che
    // si vede, mai a caso.
    final raining = _engine.round.isOdd;
    // Il sottofondo dura tutta la notte: la pioggia se piove, se no grilli o vento.
    // Dove fa caldo, le cicale; nelle metropoli, il traffico lontano.
    final beds = [
      FxGroup.crickets, FxGroup.windsoft,
      if (_style == SkylineStyle.metropolis) ...[FxGroup.citynight, FxGroup.citynight],
      if (_style != SkylineStyle.metropolis) FxGroup.cicadas,
    ];
    SoundStage.instance.ambience(raining ? FxGroup.rain : _pick(beds));
    // Sopra il letto, un rumore lontano che entra piano e se ne va: un cane
    // in fondo alla valle, i gabbiani del porto, l'orologio della cucina.
    final far = [
      FxGroup.distantdog, FxGroup.clocktick,
      if (_portCity) FxGroup.seagulls,
      if (_style == SkylineStyle.metropolis) FxGroup.citynight,
    ];
    SoundStage.instance.atmosphere(_pick(far), after: const Duration(seconds: 2), volume: 0.7);
    final night = [
      FxGroup.owl, FxGroup.dog, FxGroup.cat, FxGroup.siren, FxGroup.train, FxGroup.carpass,
      if (_portCity) FxGroup.foghorn,
      if (raining) ...[FxGroup.thunder, FxGroup.thunder],
    ];
    _nightSound(_pick(night), const Duration(milliseconds: 2500));
    if (_atmosphere.nextBool()) _nightSound(_pick(night), const Duration(seconds: 8), volume: 0.7);
  }

  /// Un rumore della notte. Il tuono porta con sé il suo lampo, che arriva
  /// prima: la luce corre più veloce del suono.
  void _nightSound(FxGroup group, Duration after, {double volume = 1}) {
    _thunders.add(Timer(after, () {
      if (!mounted || _mood != SceneMood.night) return;
      _seenAndHeard(group, volume: volume);
    }));
  }

  /// Le città che hanno un porto, o un lago con le navi: lì la sirena della
  /// nebbia ha senso.
  bool get _hasBellTower => {SkylineStyle.mediterranean, SkylineStyle.volcano}.contains(_style);

  SkylineStyle get _style => skylineFor(_script.city.id);

  bool get _portCity => const {'chicago', 'new-york', 'palermo', 'napoli'}.contains(_script.city.id);

  /// Un rumore e la sua scenetta, insieme: ogni suono ha qualcosa da vedere.
  void _seenAndHeard(FxGroup group, {double volume = 1}) {
    final stage = SoundStage.instance;
    final (scene, delay) = switch (group) {
      FxGroup.thunder => (null, 450),
      FxGroup.owl => (SkyEvent.owl, 350),
      FxGroup.dog => (SkyEvent.window, 0),
      FxGroup.cat => (SkyEvent.cat, 600),
      FxGroup.siren => (SkyEvent.siren, 0),
      FxGroup.train => (SkyEvent.train, 500),
      FxGroup.carpass => (SkyEvent.car, 300),
      FxGroup.foghorn => (SkyEvent.fog, 400),
      FxGroup.rooster => (SkyEvent.rooster, 700),
      FxGroup.birds => (SkyEvent.birds, 0),
      _ => (null, 0),
    };
    if (scene != null) CityBackdrop.show(scene);
    if (group == FxGroup.thunder) {
      // Il tuono resta secco, come il lampo che lo porta.
      CityBackdrop.flash();
      stage.effect(group, after: Duration(milliseconds: delay), volume: 0.45 * volume);
    } else {
      // Tutto il resto è sottofondo: entra ed esce piano, sotto la musica.
      stage.atmosphere(group, after: Duration(milliseconds: delay), volume: volume);
    }
  }

  /// L'alba: il gallo, gli uccelli, a volte le campane.
  void _dawnAtmosphere() {
    final stage = SoundStage.instance;
    // La notte sfuma negli uccelli: un letto che dura tutta la mattina, e
    // sopra, mentre sale, il gallo. Niente che finisce prima che l'altro cominci.
    stage.ambience(FxGroup.dawnchorus);
    CityBackdrop.show(SkyEvent.birds);
    // La città si sveglia: le saracinesche, una scopa, voci lontane. Al
    // porto, i gabbiani.
    stage.atmosphere(_portCity && _atmosphere.nextBool() ? FxGroup.seagulls : FxGroup.morningstreet,
        after: const Duration(seconds: 4), volume: 0.6);
    _thunders.add(Timer(const Duration(milliseconds: 1200), () {
      if (mounted) _seenAndHeard(FxGroup.rooster, volume: 0.9);
    }));
    // Le campane solo dove c'è un campanile all'orizzonte, lontane.
    if (_hasBellTower && _atmosphere.nextBool()) stage.atmosphere(FxGroup.bellsfar, after: const Duration(seconds: 6), volume: 0.6);
  }

  void _enterEnd(Team winner) {
    // Il Piromane che vince suona come la famiglia: non ha vinto la città.
    final dark = winner != Team.citizens;
    // La partita è finita: quando la vittoria smette di suonare, il menu.
    SoundStage.instance.screenLoop = MusicMood.menu;
    SoundStage.instance.music(dark ? MusicMood.winFamily : MusicMood.winTown);
    SoundStage.instance.ambience(null);
    SoundStage.instance.cue(dark ? Cue.familyWins : Cue.townWins);
    // Su un telefono solo c'è sempre qualcuno che ha vinto: la sua canzone.
    beat(MemeMoment.victory, after: const Duration(milliseconds: 800));
    _title = _t.endTitle;
    _mood = dark ? SceneMood.night : SceneMood.dawn;
    _endingLines = _script.ending(
      winner,
      assassin: _engine.personalWins.any((player) => widget.setup.roleOf(player) == Role.sicario),
      bountyHunter: _engine.personalWins.where((player) => widget.setup.roleOf(player) == Role.cacciatore).firstOrNull,
      loanSharks: [
        for (final player in _engine.personalWins)
          if (widget.setup.roleOf(player) == Role.strozzino) player,
      ],
      lovers: _engine.loversWon,
      presidentFell: _engine.presidentFallen,
      sect: _engine.personalWins.any((player) => widget.setup.roleOf(player) == Role.capoSetta),
    );
    _stage = _Stage.end;
  }

  void _goHome() => Navigator.of(context).popUntil((route) => route.isFirst);

  Future<void> _confirmExit() async {
    if (_stage == _Stage.end) {
      _goHome();
      return;
    }
    final leave = await confirmNoir(
      context,
      title: _t.leaveQuestion,
      body: _t.leaveWarning,
      icon: Icons.door_back_door_outlined,
      danger: true,
      cancel: _t.stay,
      confirm: _t.leave,
    );
    if (leave && mounted) _goHome();
  }

  @override
  void dispose() {
    for (final thunder in _thunders) {
      thunder.cancel();
    }
    _dayTimer?.cancel();
    SoundStage.instance.ambience(null);
    NarratorVoice.instance.hush();
    // La musica del vicolo la rimette il vicolo, quando ci si torna.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screen = WideScale(child: _screen());
    // Se intanto l'app ha cambiato lingua, la partita resta in quella in cui
    // è cominciata: anche i pezzi che i testi li cercano da sé.
    if (identical(AppStrings.of(context), _t)) return screen;
    return Localizations.override(context: context, locale: _t.language.locale, child: screen);
  }

  /// Le fasi del tavolo: lo stesso tavolo dei posti della partita online.
  bool get _atTheTable => switch (_stage) {
        _Stage.handoff || _Stage.task || _Stage.taskDone || _Stage.toNarrator => true,
        _Stage.day || _Stage.power || _Stage.shot || _Stage.vote || _Stage.verdict => true,
        _ => false,
      };

  /// Il telefono è in mano a uno solo: il tavolo è di notte.
  bool get _private =>
      _stage == _Stage.handoff || _stage == _Stage.task || _stage == _Stage.taskDone || _stage == _Stage.toNarrator;

  Widget _screen() {
    if (_stage == _Stage.crime) {
      // Il delitto va in scena a tutto schermo, senza barre né pulsanti.
      final story = _deaths[_crime];
      final film = filmFor(story);
      return PopScope(
        canPop: false,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: DeathScene(
            key: ValueKey('crime-$_step'),
            act: film.act,
            save: film.save,
            victimName: _dawn.attacks[_crime].isFatal ? _dawn.attacks[_crime].target.name : _t.someoneSaved,
            caption: story.scene.text,
            epilogue: story.epilogue?.id ?? '',
            style: skylineFor(_script.city.id),
            onFinished: _afterCrime,
          ),
        ),
      );
    }
    if (_atTheTable) return _tableScreen();
    final phoneIsWithNarrator = _stage == _Stage.script;
    return PopScope(
      canPop: false,
      child: SceneScaffold(
        mood: _mood,
        style: skylineFor(_script.city.id),
        rain: _mood == SceneMood.night && _engine.round.isOdd,
        appBar: AppBar(
          leading: Center(
            child: TargaIconButton(icon: Icons.close, tooltip: _t.leaveTooltip, size: 40, feel: Press.back, onPressed: _confirmExit),
          ),
          title: Text(_title),
          actions: [
            RolesButton(onPressed: pressed(_showDeck, Press.card)),
            if (_narrator != null && phoneIsWithNarrator) _narratorEye(),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              child: KeyedSubtree(key: ValueKey(_step), child: _stageView()),
            ),
          ),
        ),
      ),
    );
  }

  void _showDeck() {
    final board = _engine.publicView();
    RolesSheet.show(context, deck: board.deck, revealed: publicReveals(board));
  }

  Widget _narratorEye() => IconButton(
        icon: const Icon(Icons.visibility),
        tooltip: _t.rolesTooltip,
        onPressed: pressed(
          () => NarratorRolesSheet.show(context, setup: widget.setup, isAlive: _engine.isAlive),
          Press.card,
        ),
      );

  String _clock(Duration left) => '${left.inMinutes}:${(left.inSeconds % 60).toString().padLeft(2, '0')}';

  /// Il tavolo, come online: il cartiglio in alto, i posti intorno al panno,
  /// la striscia dei comandi sotto. Niente chat: si parla a voce.
  Widget _tableScreen() {
    final day = _stage == _Stage.day;
    final narratorHolds = _narrator != null && (day || _stage == _Stage.vote || _stage == _Stage.verdict);
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Saloon.ink,
        body: SaloonBackdrop(
          night: _private,
          child: SafeArea(
            child: Column(
              children: [
                StageHeader(
                  title: _title,
                  ribbon: _ribbon(),
                  countdown: day ? _clock(_dayLeft) : null,
                  urgent: day && _dayLeft <= const Duration(seconds: 10),
                  leading: HeaderIconButton(
                    icon: Icons.close,
                    tooltip: _t.leaveTooltip,
                    onPressed: pressed(_confirmExit, Press.back),
                  ),
                  action: HeaderIconButton(
                    key: const Key('rolesSheet.button'),
                    icon: Icons.style,
                    tooltip: _t.rolesTooltip,
                    onPressed: pressed(_showDeck, Press.card),
                  ),
                  // Durante il voto, l'angolo torna al votante di prima.
                  corner: _stage == _Stage.vote && _voter > 0
                      ? HeaderIconButton(
                          key: const Key('local.undoVote'),
                          icon: Icons.undo,
                          tooltip: _ls.undo,
                          onPressed: pressed(() => _advance(() => _voter--), Press.back),
                        )
                      : narratorHolds
                      ? _narratorEye()
                      : null,
                ),
                Expanded(
                  child: ContentWidth(
                    maxWidth: 780,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: AnimatedSwitcher(
                        duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 300),
                        child: KeyedSubtree(key: ValueKey(_step), child: _stageView()),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// La riga sotto il titolo: a che punto è il giro del telefono, o il voto.
  String? _ribbon() => switch (_stage) {
        _Stage.handoff || _Stage.task || _Stage.taskDone => '${_turn + 1} / ${_queue.length}',
        _Stage.vote => '${_voter + 1} / ${_voters.length}',
        _ => null,
      };

  String _tag(Player player) => switch (_numbers[player]) {
        final n? => '$n ${player.name}',
        null => player.name,
      };

  /// Una pagina del tavolo: i posti, poi (se c'è) il copione da leggere,
  /// poi la striscia.
  Widget _tablePage({
    Key? key,
    required Widget table,
    required ActionStrip strip,
    Widget? script,
    List<ScriptLine> voice = const [],
  }) {
    final desk = DesktopCanvas.of(context);
    final page = LayoutBuilder(
      key: key,
      builder: (context, box) => Column(
        children: [
          Expanded(child: SizedBox(key: const Key('game.tableSlot'), width: double.infinity, child: table)),
          if (script != null) ...[
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: box.maxHeight * 0.24),
              child: SingleChildScrollView(child: script),
            ),
          ],
          const SizedBox(height: 6),
          SizedBox(
            key: const Key('game.stripSlot'),
            height: ActionStrip.heightFor(desk: desk),
            width: double.infinity,
            child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: strip)),
          ),
        ],
      ),
    );
    return voice.isEmpty ? page : SpokenLines(lines: voice, reader: _narrator?.name, child: page);
  }

  /// La tenda fra una mano e l'altra; la voce dice a chi passa il telefono.
  Widget _curtain(Player player, {Key? key, required VoidCallback onReady}) {
    final lines = _script.curtain(player.name);
    return SpokenLines(
      key: key,
      lines: lines,
      reader: _narrator?.name,
      child: LocalCurtain(player: player, number: _numbers[player], hint: lines.last.text, onReady: onReady),
    );
  }

  Widget _stageView() => switch (_stage) {
        _Stage.script => ScriptPageView(page: _page, reader: _narrator?.name, strings: _t),
        _Stage.handoff => _curtain(
            _queue[_turn],
            key: ValueKey('curtain-$_turn'),
            onReady: () => _advance(() {
              // Chi siede accanto non deve poter leggere il bersaglio dal
              // posto del dito: a ogni mano le facce cambiano posto.
              final holder = _queue[_turn];
              _seats = handSeating(widget.setup.players, holder, _seating, avoid: [_seats, _table]);
              _stage = _Stage.task;
            }),
          ),
        _Stage.task => _engine.jailedTonight == _queue[_turn] ? _jailedView(_queue[_turn]) : _taskView(_queue[_turn]),
        _Stage.taskDone => _taskDoneView(_queue[_turn]),
        _Stage.crimeIntro => _crimeIntroView(),
        _Stage.crime => const SizedBox.shrink(),
        _Stage.verdict => _verdictView(),
        _Stage.toNarrator => _curtain(_narrator!, onReady: () => _advance(_enterDawn)),
        _Stage.day => _dayView(),
        _Stage.power => _powerView(),
        _Stage.shot => _shotView(),
        _Stage.vote => _voteView(),
        _Stage.end => _endView(),
      };

  Widget _crimeIntroView() {
    return Column(
      children: [
        const Spacer(),
        const Icon(Icons.theaters, color: AppColors.gold, size: 56),
        const SizedBox(height: 24),
        Text(
          _t.phoneOnTheTable,
          textAlign: TextAlign.center,
          style: AppText.display(34),
        ),
        const SizedBox(height: 14),
        Text(
          _t.phoneOnTheTableHint,
          textAlign: TextAlign.center,
          style: AppText.body,
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: pressed(() => _advance(() => _stage = _Stage.crime), Press.tap),
            child: Text(_t.lightsDown),
          ),
        ),
      ],
    );
  }

  /// Il tavolo segreto di chi ha il telefono: il suo posto in basso, gli
  /// altri rimescolati a ogni mano.
  Widget _secretTable(
    Player actor, {
    Set<Player> selectable = const {},
    Player? selected,
    void Function(Player player)? onTap,
    List<SeatVote> votes = const [],
    Widget? center,
  }) =>
      LocalTable(
        key: const Key('local.secretTable'),
        seats: _seats,
        numbers: _numbers,
        holder: actor,
        isAlive: _engine.isAlive,
        knowledgeOf: (player) => _engine.knowledgeOf(actor, player),
        selectable: selectable,
        selected: selected,
        onTap: onTap,
        votes: votes,
        voteColor: Saloon.mafia,
        day: false,
        center: center,
      );

  /// La mossa della notte, tutta dal compito che il motore dà al ruolo: la
  /// domanda, chi si può scegliere, l'eventuale seconda mossa. Si tocca un
  /// posto, poi si conferma: il telefono è in mano, nessuna fretta.
  Widget _taskView(Player actor) {
    final view = _engine.viewFor(actor.id);
    final offered = _engine.taskFor(actor);
    final alternative = offered.alternative;
    final task =
        _alternative && alternative != null ? NightTask(alternative, offered.alternativeTargets) : offered;
    final selected = _selected;
    final labels = alternativeLabels(_t, alternative);
    final family = offered.kind == NightTaskKind.kill && !_alternative;
    final lastWatch = view.watches.isNotEmpty ? view.watches.last : null;
    final notes = [
      if (lastWatch != null && lastWatch.round == _engine.round - 1)
        (lastWatch.visited ? _t.pack.watchVisited : _t.pack.watchQuiet).replaceAll('{name}', _tag(lastWatch.target)),
      if (view.doused.isNotEmpty) '${_t.dousedBadge}: ${view.doused.map(_tag).join(', ')}',
      if (view.bounty case final mark?) _t.bountyLine.replaceAll('{name}', _tag(mark)),
      if (view.role == Role.prostituta && offered.kind == NightTaskKind.kill) _ts.lastOfFamily,
      ..._privateNotes(actor),
    ];
    final desk = DesktopCanvas.of(context);
    return _tablePage(
      key: const Key('local.night'),
      table: _secretTable(
        actor,
        selectable: {
          for (final player in task.targets)
            if (player != _firstLover) player,
        },
        selected: selected,
        onTap: (player) => setState(() => _selected = player),
        // La famiglia vede dove puntano i complici che hanno già scelto.
        votes: family ? view.familyVotes : const [],
        center: LocalFelt([
          (
            text: _firstLover != null ? _lr.linkSecond : _script.taskPrompt(task, _engine.round),
            key: const Key('local.taskPrompt'),
            style: LocalFelt.titleStyle(context, color: family ? const Color(0xFFFFB3B3) : AppColors.textPrimary),
          ),
          for (final note in notes) (text: note, key: null, style: LocalFelt.lineStyle(context, color: Saloon.brass)),
        ]),
      ),
      strip: ActionStrip(
        status: selected == null ? _script.taskHint(task) : _ls.pickedConfirm(_tag(selected)),
        tone: selected == null ? StripTone.act : StripTone.done,
        control: alternative != null
            ? SizedBox(
                height: NoirMetrics(desk).button,
                child: TargaSegmented<bool>(
                  key: const Key('task.alternative'),
                  desk: desk,
                  height: NoirMetrics(desk).button,
                  segments: [(false, labels.$1), (true, labels.$2)],
                  selected: _alternative,
                  onChanged: (choice) => setState(() {
                    _alternative = choice;
                    // Il fiammifero si accende scegliendo se stessi: già scelto.
                    _selected = _alternative && alternative == NightTaskKind.ignite ? actor : null;
                  }),
                ),
              )
            : null,
        actions: [
          NoirAction(key: const Key('local.pass'), label: _t.pass, feel: Press.tap, onPressed: () => _submit(null)),
          NoirAction(
            key: const Key('local.confirm'),
            label: _t.confirm,
            style: NoirButtonStyle.primary,
            feel: Press.confirm,
            onPressed: selected == null ? null : () => _submit(selected),
          ),
        ],
      ),
    );
  }

  /// Quello che è arrivato all'alba solo a [actor], da leggere al suo turno
  /// (sul telefono unico non c'è altro momento privato): la risposta
  /// dell'indagine o dello scavo, la cella, il blocco, la risposta del
  /// prigioniero al Carceriere, la setta.
  List<String> _privateNotes(Player actor) {
    final last = _engine.round - 1;
    final view = _engine.viewFor(actor.id);
    return [
      for (final finding in _engine.findingsOf(actor))
        if (finding.round == last)
          if (finding.exposure.role case final role?)
            _lr.foundRole(_tag(finding.exposure.subject), _t.role(role).label)
          else if (finding.exposure.team == Team.mafia)
            _lr.foundFamily(_tag(finding.exposure.subject))
          else
            _lr.foundClean(_tag(finding.exposure.subject)),
      if (_engine.wasBusy(actor)) _lr.wasBusy,
      if (_engine.lastJailed == actor && _answers[last] == null) ...[
        _lr.wasJailed,
        if (_questions[last] case final question?) _lr.jailerAsked(question),
      ],
      if (widget.setup.roleOf(actor) == Role.carceriere)
        if ((_answers[last], _engine.lastJailed) case (final answer?, final prisoner?) when answer.isNotEmpty)
          _lr.prisonerAnswered(prisoner.name, answer),
      if (view.converted) _lr.converted,
      if (view.sect.isNotEmpty) _lr.sect(view.sect.map((p) => p.name).join(', ')),
      if (view.doors.isNotEmpty && view.doors.last.round == last) _lr.doorClosed(view.doors.last.target.name),
      if (_engine.loversFor(actor) case [final a, final b])
        if (actor == a || actor == b)
          _lr.inLoveWith(actor == a ? b.name : a.name)
        else
          _lr.linked(a.name, b.name),
      // Il Tiratore scelto: chi ha nel mirino (se passa, resta quello).
      if (widget.setup.roleOf(actor) == Role.tiratoreScelto && _engine.marksmanShotsLeft > 0)
        if (_engine.aimed case final aim?) _lr.aimed(_tag(aim), _engine.marksmanShotsLeft),
    ];
  }

  /// Una riga scritta della cella, sotto il tavolo: la domanda del
  /// Carceriere o la risposta del prigioniero.
  Widget _cellField({required Key key, required String label, required String hint, required ValueChanged<String> onChanged}) =>
      Container(
        decoration: Saloon.scrim(radius: 12),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: LocalFelt.lineStyle(context, color: Saloon.brass, weight: FontWeight.w700)),
            TextField(
              key: key,
              maxLength: 140,
              decoration: InputDecoration(hintText: hint, isDense: true),
              onChanged: (text) => onChanged(text.trim()),
            ),
          ],
        ),
      );

  /// Il prigioniero al suo turno: niente mossa, la domanda del Carceriere e
  /// la risposta, scritta, che il Carceriere leggerà al suo turno dopo.
  Widget _jailedView(Player actor) {
    final question = _questions[_engine.round];
    return _tablePage(
      key: const Key('game.jailed'),
      script: question == null
          ? null
          : _cellField(
              key: const Key('game.cellAnswer'),
              label: '${_lr.jailerAsks} «$question»',
              hint: _lr.answerHint,
              onChanged: (answer) => _answers[_engine.round] = answer,
            ),
      table: _secretTable(
        actor,
        center: LocalFelt([
          (text: _lr.jailedTitle, key: null, style: LocalFelt.titleStyle(context)),
          (text: _lr.jailedBody, key: null, style: LocalFelt.lineStyle(context, style: FontStyle.italic)),
          for (final note in _privateNotes(actor)) (text: note, key: null, style: LocalFelt.lineStyle(context, color: Saloon.brass)),
        ]),
      ),
      strip: ActionStrip(
        status: _script.putPhoneDown().text,
        tone: StripTone.done,
        actions: [
          NoirAction(
            key: const Key('local.done'),
            label: _t.done,
            style: NoirButtonStyle.primary,
            feel: Press.confirm,
            onPressed: () {
              // Ha visto la cella: domani niente avviso «eri in cella».
              _answers.putIfAbsent(_engine.round, () => '');
              _afterTask();
            },
          ),
        ],
      ),
    );
  }

  /// Il Pacifista c'è nel mazzo e la tregua non è ancora spesa (il bottone
  /// resta anche se è morto: sennò il tavolo lo saprebbe).
  bool get _hasTruce => widget.setup.roles.values.contains(Role.pacifista) && !_engine.truceSpent;

  /// Il Tiratore scelto c'è nel mazzo e ha ancora colpi (il bottone resta
  /// anche se è morto). Con la tregua di oggi non si spara.
  bool get _hasShot =>
      widget.setup.roles.values.contains(Role.tiratoreScelto) && _engine.marksmanShotsLeft > 0 && !_engine.truceToday;

  /// Il colpo del Tiratore scelto, davanti a tutti: tocca il suo volto, vede
  /// chi ha nel mirino, spara. Poi il tavolo legge chi è caduto.
  Widget _marksmanView() {
    final user = _powerUser;
    final shot = _marksmanShot;
    final selected = _selected;
    if (shot != null) {
      final lines = _script.marksmanShot(shot);
      return _tablePage(
        key: const Key('game.marksmanShot'),
        voice: lines,
        table: _publicTable(
          center: LocalFelt([
            for (final line in lines.take(2))
              (text: line.text, key: null, style: LocalFelt.lineStyle(context, color: Saloon.brass, weight: FontWeight.w700)),
          ]),
        ),
        strip: ActionStrip(
          status: lines.length > 2 ? lines[2].text : lines.last.text,
          tone: StripTone.done,
          actions: [
            NoirAction(
              key: const Key('game.shotDone'),
              label: _lr.carryOn,
              style: NoirButtonStyle.primary,
              feel: Press.confirm,
              onPressed: () => _advance(() {
                final winner = _engine.winner;
                winner != null ? _enterEnd(winner) : _stage = _Stage.day;
              }),
            ),
          ],
        ),
      );
    }
    final aim = user == null ? null : _engine.aimed;
    final status = user == null
        ? _lr.whoIsMarksman
        : aim == null
        ? _lr.noAim
        : _lr.aimed(_tag(aim), _engine.marksmanShotsLeft);
    return _tablePage(
      key: const Key('game.power'),
      table: _publicTable(
        holder: user,
        selected: user == null ? selected : aim,
        selectable: user == null ? {..._engine.alivePlayers} : const {},
        onTap: user == null ? (player) => setState(() => _selected = player) : null,
        center: LocalFelt([
          (text: status, key: const Key('game.aim'), style: LocalFelt.titleStyle(context)),
          if (_powerError case final error?)
            (text: error, key: const Key('game.powerError'), style: LocalFelt.lineStyle(context, color: Saloon.mafia)),
        ]),
      ),
      strip: ActionStrip(
        status: user == null && selected != null ? _tag(selected) : status,
        tone: StripTone.act,
        actions: [
          NoirAction(
            label: _lr.cancel,
            feel: Press.back,
            onPressed: () => _advance(() => _stage = _Stage.day),
          ),
          if (user == null)
            NoirAction(
              key: const Key('game.powerConfirm'),
              label: _lr.confirm,
              style: NoirButtonStyle.primary,
              feel: Press.confirm,
              onPressed: selected == null
                  ? null
                  : () {
                      final ok = widget.setup.roleOf(selected) == Role.tiratoreScelto && _engine.isAlive(selected);
                      setState(() {
                        _powerUser = ok ? selected : null;
                        _powerError = ok ? null : _lr.notMarksman;
                        _selected = null;
                      });
                    },
            )
          else
            NoirAction(
              key: const Key('game.marksmanFire'),
              label: _lr.fire,
              style: NoirButtonStyle.primary,
              feel: Press.confirm,
              onPressed: aim == null
                  ? null
                  : () => _advance(() {
                      _dayTimer?.cancel();
                      _marksmanShot = _engine.shoot(user);
                    }),
            ),
        ],
      ),
    );
  }

  /// I bottoni dei poteri di giorno, accanto al cronometro.
  Widget? _powerButtons() {
    final buttons = [
      if (_hasTruce) _powerButton(const Key('game.truce'), _lr.truce, _Power.truce),
      if (_hasCannon) _powerButton(const Key('game.fire'), _lr.cannon, _Power.cannon),
      if (_hasShot) _powerButton(const Key('game.marksman'), _lr.marksman, _Power.marksman),
    ];
    if (buttons.length < 2) return buttons.firstOrNull;
    return Row(
      children: [
        for (final (i, button) in buttons.indexed) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: button),
        ],
      ],
    );
  }

  /// L'Artigliere c'è nel mazzo, dal secondo giorno, con un colpo in canna e
  /// senza aver già sparato oggi. Finché non ha sparato il bottone resta
  /// anche se è morto (sennò il tavolo lo saprebbe); dopo il primo colpo è
  /// pubblico, e il bottone c'è solo se è vivo.
  bool get _hasCannon {
    final left = _engine.shotsLeft;
    if (left == null || left == 0 || _engine.round < 2 || _engine.firedToday) return false;
    if (_engine.shots.isEmpty) return true;
    return _engine.isAlive(_engine.shots.first.gunner);
  }

  void _openPower(_Power power) => _advance(() {
        _power = power;
        _powerUser = null;
        _powerError = null;
        _marksmanShot = null;
        _stage = _Stage.power;
      });

  Widget _powerButton(Key key, String label, _Power power) => SizedBox(
        height: NoirMetrics(DesktopCanvas.of(context)).button,
        child: OutlinedButton(
          key: key,
          onPressed: pressed(() => _openPower(power), Press.tap),
          child: FittedBox(fit: BoxFit.scaleDown, child: Text(label, maxLines: 1)),
        ),
      );

  /// I poteri davanti a tutti: chi lo usa tocca il suo volto, poi su chi.
  /// La tregua: il ruolo esatto va sul tavolo e il voto salta. Il colpo:
  /// il bersaglio muore e la sua carta si gira.
  Widget _powerView() {
    if (_power == _Power.marksman) return _marksmanView();
    final user = _powerUser;
    final selected = _selected;
    final cannon = _power == _Power.cannon;
    final whoAreYou = cannon ? _lr.gunnerWhoAreYou : _lr.whoAreYou;
    final whoTo = cannon ? _lr.whoToHit : _lr.whoToReveal;
    final selectable = user == null
        ? {..._engine.alivePlayers}
        : cannon
        ? {..._engine.fireTargets(user)}
        : {
            for (final player in _engine.alivePlayers)
              if (player != user) player,
          };
    return _tablePage(
      key: const Key('game.power'),
      table: _publicTable(
        holder: user,
        selected: selected,
        selectable: selectable,
        onTap: (player) => setState(() => _selected = player),
        center: LocalFelt([
          (text: user == null ? whoAreYou : whoTo, key: null, style: LocalFelt.titleStyle(context)),
          if (_powerError case final error?)
            (text: error, key: const Key('game.powerError'), style: LocalFelt.lineStyle(context, color: Saloon.mafia)),
        ]),
      ),
      strip: ActionStrip(
        status: selected == null ? (user == null ? whoAreYou : whoTo) : _tag(selected),
        tone: selected == null ? StripTone.act : StripTone.done,
        actions: [
          NoirAction(
            label: _lr.cancel,
            feel: Press.back,
            onPressed: () => _advance(() => _stage = _Stage.day),
          ),
          NoirAction(
            key: const Key('game.powerConfirm'),
            label: _lr.confirm,
            style: NoirButtonStyle.primary,
            feel: Press.confirm,
            onPressed: selected == null ? null : () => _usePower(selected),
          ),
        ],
      ),
    );
  }

  void _usePower(Player picked) {
    final user = _powerUser;
    final cannon = _power == _Power.cannon;
    if (user == null) {
      final ok = cannon ? _engine.canFire(picked) : widget.setup.roleOf(picked) == Role.pacifista && _engine.isAlive(picked);
      setState(() {
        _powerUser = ok ? picked : null;
        _powerError = ok ? null : (cannon ? _lr.notTheGunner : _lr.notYou);
        _selected = null;
      });
      return;
    }
    if (cannon) {
      _advance(() => _enterShot(_engine.fire(user, picked)));
      return;
    }
    _advance(() {
      _dayTimer?.cancel();
      _engine.pacify(user, picked);
      _lastVotes = const [];
      _enterVerdict(_engine.lynch(null));
    });
  }

  /// Il boato in piazza: il colpito cade, la sua carta si gira davanti a
  /// tutti, il copione da leggere.
  void _enterShot(CannonShot shot) {
    _shot = shot;
    _shotLines = _script.cannon(shot);
    SoundStage.instance.cue(Cue.bang);
    SoundStage.instance.cue(shot.role.team == Team.mafia ? Cue.caught : Cue.innocent);
    _stage = _Stage.shot;
  }

  Widget _shotView() {
    final shot = _shot!;
    final winner = _engine.winner;
    final role = _t.role(shot.role).label;
    final line = _ts.cannonLine(_tag(shot.target), _lowerFirstLocal(role));
    final left = _engine.shotsLeft ?? 0;
    return _tablePage(
      key: const Key('game.shot'),
      script: SpokenScriptCard(reader: _narrator?.name, lines: _shotLines),
      table: _publicTable(
        center: LocalFelt([
          (
            text: line,
            key: const Key('game.shotLine'),
            style: LocalFelt.titleStyle(context, color: Color.lerp(stampColorFor(shot.role), Colors.white, 0.45)!),
          ),
          if (winner == null)
            (
              text: _ts.gunnerShotsLeft(left),
              key: const Key('game.shotsLeft'),
              style: LocalFelt.lineStyle(context, color: Saloon.brass),
            ),
        ]),
      ),
      strip: ActionStrip(
        status: line,
        tone: StripTone.done,
        actions: [
          NoirAction(
            key: const Key('game.afterShot'),
            label: winner != null ? _t.finale : _t.continueLabel,
            style: NoirButtonStyle.primary,
            feel: Press.confirm,
            onPressed: () => _advance(() => winner != null ? _enterEnd(winner) : _stage = _Stage.day),
          ),
        ],
      ),
    );
  }

  String _lowerFirstLocal(String text) =>
      _t.language.locale.languageCode == 'it' && text.isNotEmpty ? text[0].toLowerCase() + text.substring(1) : text;

  /// La mossa è fatta: sul panno la risposta (l'indagine, la fossa) o la
  /// notte che continua. Il posto scoperto resta acceso.
  Widget _taskDoneView(Player actor) {
    final finding = _finding;
    final found = finding?.role;
    final isMafia = finding?.team == Team.mafia;
    final title = LocalFelt.titleStyle(context);
    final List<FeltLine> lines = finding == null
        ? [
            (text: _t.doneTitle, key: null, style: title),
            (text: _t.nobodyWillKnow, key: null, style: LocalFelt.lineStyle(context, style: FontStyle.italic)),
          ]
        : [
            (
              text: found == null ? _t.yourInvestigation : _t.inTheGrave,
              key: const Key('local.findingKind'),
              style: LocalFelt.lineStyle(context, color: Saloon.brass, weight: FontWeight.w700),
            ),
            (text: _tag(finding.subject).toUpperCase(), key: const Key('local.findingWho'), style: title),
            (
              text: found != null
                  ? _t.wasRole(_t.role(found).label)
                  : isMafia
                  ? _t.isFamily
                  : _t.isInnocent,
              key: const Key('local.findingWhat'),
              style: LocalFelt.titleStyle(context, color: isMafia ? Saloon.mafia : Saloon.clean),
            ),
            if (found != null)
              (
                text: isMafia ? _t.wasWithFamily : _t.wasWithTown,
                key: null,
                style: LocalFelt.lineStyle(context, color: AppColors.textSecondary),
              ),
          ];
    // Il Carceriere: chi è in cella, e una domanda scritta per lui.
    final prisoner = switch (_engine.nightChoices[actor]) {
      (kind: NightTaskKind.jail, target: final prisoner?) => prisoner,
      _ => null,
    };
    return _tablePage(
      key: const Key('local.nightDone'),
      voice: [_script.putPhoneDown()],
      script: prisoner == null
          ? null
          : _cellField(
              key: const Key('game.cellQuestion'),
              label: _lr.jailed(_tag(prisoner)),
              hint: _lr.questionHint,
              onChanged: (question) =>
                  question.isEmpty ? _questions.remove(_engine.round) : _questions[_engine.round] = question,
            ),
      table: _secretTable(actor, selected: finding?.subject ?? prisoner, center: LocalFelt(lines)),
      strip: ActionStrip(
        status: _script.putPhoneDown().text,
        tone: StripTone.done,
        actions: [
          NoirAction(
            key: const Key('local.done'),
            label: _t.done,
            style: NoirButtonStyle.primary,
            feel: Press.confirm,
            onPressed: _afterTask,
          ),
        ],
      ),
    );
  }

  /// Il tavolo di tutti, di giorno: sempre nello stesso ordine.
  Widget _publicTable({
    Set<Player> selectable = const {},
    Player? holder,
    Player? selected,
    void Function(Player player)? onTap,
    List<SeatVote> votes = const [],
    Player? lynched,
    bool accusing = true,
    Widget? center,
  }) =>
      LocalTable(
        key: const Key('local.publicTable'),
        seats: _table,
        numbers: _numbers,
        holder: holder,
        isAlive: _engine.isAlive,
        knowledgeOf: (player) => _engine.knowledgeOf(null, player),
        selectable: selectable,
        selected: selected,
        onTap: onTap,
        votes: votes,
        mayor: _engine.mayorRevealed ? _engine.mayor : null,
        silenced: _stage == _Stage.verdict ? null : _dawn.silenced,
        lynched: lynched,
        accusing: accusing,
        center: center,
      );

  /// La discussione: sul panno chi è morto stanotte, nel cartiglio il
  /// cronometro; sotto, più tempo o al voto.
  Widget _dayView() {
    final italian = _t.language.locale.languageCode == 'it';
    final headline = dawnHeadline(_dawn, italian: italian, everyoneAlive: _t.everyoneAlive).headline;
    final expired = _dayLeft == Duration.zero;
    return _tablePage(
      key: const Key('local.day'),
      table: _publicTable(
        center: LocalFelt([
          (text: headline, key: const Key('local.dawnHeadline'), style: LocalFelt.titleStyle(context)),
        ]),
      ),
      strip: ActionStrip(
        status: expired ? _t.timeUp : _ls.discuss,
        tone: expired ? StripTone.wait : StripTone.act,
        control: _powerButtons(),
        actions: [
          NoirAction(
            key: const Key('local.moreTime'),
            label: _t.plusMinute,
            feel: Press.chips,
            onPressed: () => setState(() => _dayLeft += const Duration(minutes: 1)),
          ),
          NoirAction(
            key: const Key('local.toVote'),
            label: _t.callTheVote,
            style: NoirButtonStyle.primary,
            feel: Press.confirm,
            onPressed: () => _advance(_enterVote),
          ),
        ],
      ),
    );
  }

  /// Il voto a viso aperto: il telefono resta in mezzo, ognuno a turno tocca
  /// chi condanna (o si astiene). Le mani e i bolli dicono a che punto è.
  Widget _voteView() {
    final voter = _voters[_voter];
    final votes = [for (final e in _engine.dayVotes.entries) (voter: e.key, target: e.value)];
    final targets = {
      for (final player in _engine.alivePlayers)
        if (player != voter) player,
    };
    final mayorInPlay = widget.setup.roles.values.contains(Role.sindaco) && !_engine.mayorRevealed;
    final mayor = _engine.mayorRevealed ? _engine.mayor : null;
    final turn = _script.voterTurn(_tag(voter));
    return _tablePage(
      key: const Key('local.vote'),
      // Al primo votante la voce legge il richiamo e poi il suo turno; agli
      // altri, solo il turno.
      script: _voter == 0 ? SpokenScriptCard(reader: _narrator?.name, lines: [..._voteLines, turn]) : null,
      voice: _voter == 0 ? const [] : [turn],
      table: _publicTable(
        holder: voter,
        selectable: targets,
        onTap: _castVote,
        votes: votes,
        center: mayor == null
            ? null
            : LocalFelt([
                (
                  text: _t.pack.mayorRevealed.replaceAll('{name}', _tag(mayor)),
                  key: const Key('local.mayor'),
                  style: LocalFelt.lineStyle(context, color: Saloon.brass, weight: FontWeight.w700),
                ),
              ]),
      ),
      strip: ActionStrip(
        status: turn.text,
        statusKey: const Key('local.voterTurn'),
        tone: StripTone.act,
        count: '${votes.length}/${_voters.length}',
        countTooltip: _t.online.votesCast(votes.length, _voters.length),
        actions: [
          if (mayorInPlay)
            NoirAction(key: const Key('local.revealMayor'), label: _ts.revealMayor, onPressed: _revealMayor),
          NoirAction(
            key: const Key('local.abstain'),
            label: _t.online.abstain,
            onPressed: () => _castVote(null),
          ),
        ],
      ),
    );
  }

  /// Lo scrutinio in una riga: quanti voti a chi, e quanti si sono astenuti.
  String _verdictTally() {
    final counts = <Player, int>{};
    var abstained = 0;
    final mayor = _engine.mayorRevealed ? _engine.mayor : null;
    for (final vote in _lastVotes) {
      final target = vote.target;
      if (target == null) {
        abstained++;
      } else {
        counts[target] = (counts[target] ?? 0) + (vote.voter == mayor ? 2 : 1);
      }
    }
    final order = counts.keys.toList()..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    final parts = [
      for (final target in order) '${_tag(target)}: ${_t.online.votesFor(counts[target]!)}',
      if (abstained > 0) _ts.abstainedVotes(abstained),
    ];
    return parts.join('  ·  ');
  }

  /// Il verdetto sul tavolo: il linciaggio sul posto, i pizzini di chi ha
  /// votato chi, il copione sotto.
  Widget _verdictView() {
    final report = _verdict;
    final winner = report.winner;
    final condemned = _condemned;
    final role = report.role;
    final verdict = condemned == null
        ? _t.noConviction
        : _ts.lynchedLine(_tag(condemned), role == null ? null : _t.role(role).label, gender: PlayerGenders.of(condemned.name));
    final headlineColor = role == null ? Saloon.brass : Color.lerp(stampColorFor(role), Colors.white, 0.45)!;
    final tally = _verdictTally();
    final m = NoirMetrics(DesktopCanvas.of(context));
    return _tablePage(
      key: const Key('game.verdict'),
      script: SpokenScriptCard(reader: _narrator?.name, lines: _verdictLines),
      table: _publicTable(
        votes: _lastVotes,
        accusing: false,
        lynched: condemned,
        center: LocalFelt([
          (text: verdict, key: const Key('game.verdictTitle'), style: LocalFelt.titleStyle(context, color: headlineColor)),
          if (condemned != null && report.personalWin)
            (
              text: _t.pack.foolWinsFact.replaceAll('{name}', _tag(condemned)),
              key: null,
              style: LocalFelt.lineStyle(context, color: Saloon.brass),
            ),
          if (report.bountyHunter case final hunter?)
            (
              text: _t.pack.bountyWinsFact.replaceAll('{name}', _tag(hunter)),
              key: null,
              style: LocalFelt.lineStyle(context, color: Saloon.brass),
            ),
        ]),
      ),
      strip: ActionStrip(
        status: tally.isEmpty ? verdict : tally,
        tone: StripTone.done,
        detail: tally.isEmpty
            ? null
            : VerdictLine(
                tally: tally,
                tallyKey: const Key('local.verdictVotes'),
                tallyStyle: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: m.body * 0.9,
                  height: 1.3,
                  fontWeight: FontWeight.w500,
                  shadows: const [Shadow(color: Colors.black, blurRadius: 8)],
                ),
                headlineStyle: const TextStyle(),
                height: ActionStrip.heightFor(desk: m.desk) - m.gap * (m.desk ? 3 : 2) - m.button,
              ),
        actions: [
          NoirAction(
            key: const Key('local.afterVerdict'),
            label: winner != null ? _t.finale : _t.continueLabel,
            style: NoirButtonStyle.primary,
            feel: Press.confirm,
            onPressed: () => _advance(() => winner != null ? _enterEnd(winner) : _enterNight()),
          ),
        ],
      ),
    );
  }

  String _fateOf(Player player) {
    for (final record in _engine.history) {
      if (record.nightVictims.contains(player)) return _t.fateNight(record.round);
      if (record.lynched == player) return _t.fateGallows(record.round);
      if (record.dayVictims.contains(player)) {
        return _engine.shots.any((shot) => shot.target == player) ? _lr.fateCannon(record.round) : _lr.fateDay(record.round);
      }
    }
    return _t.stillStanding;
  }

  Widget _endView() {
    final mafiaWon = _engine.winner == Team.mafia;
    final arsonistWon = _engine.winner == Team.neutral;
    final suspects = _engine.suspicion.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return ListView(
      children: [
        Icon(
          mafiaWon ? Icons.theater_comedy : Icons.balance,
          color: mafiaWon ? _mafiaRed : AppColors.gold,
          size: 48,
        ),
        const SizedBox(height: 12),
        Text(
          arsonistWon && _engine.personalWins.any((player) => widget.setup.roleOf(player) == Role.capoSetta)
              ? _lr.sectWins
              : arsonistWon
              ? _t.arsonistWins
              : mafiaWon
                  ? _t.familyWins
                  : _t.townWins,
          textAlign: TextAlign.center,
          style: AppText.display(36, color: mafiaWon ? _mafiaRed : AppColors.gold),
        ),
        const SizedBox(height: 20),
        SpokenScriptCard(reader: _narrator?.name, lines: _endingLines, leadIn: const Duration(milliseconds: 900)),
        const SizedBox(height: 28),
        Text(_t.whoWasWho, style: AppText.overline),
        const SizedBox(height: 10),
        for (final player in _table)
          RevealRow(
            name: player.name,
            role: widget.setup.roleOf(player),
            roleLabel: _t.role(widget.setup.roleOf(player)).label,
            fate: _engine.personalWins.contains(player) ? '${_t.wonAlone} · ${_fateOf(player)}' : _fateOf(player),
            alive: _engine.isAlive(player),
            winner: _engine.hasWon(player),
          ),
        if (suspects.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(_t.mostSuspicious, style: AppText.overline),
          const SizedBox(height: 10),
          Row(
            children: [
              PlayerAvatar(seed: suspects.first.key.name, size: 52, fallen: !_engine.isAlive(suspects.first.key)),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  _t.suspicion(
                    suspects.first.key.name,
                    suspects.first.value,
                    rightly: widget.setup.roleOf(suspects.first.key).team == Team.mafia,
                  ),
                  style: AppText.body.copyWith(color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 28),
        if (_engine.recap case final recap?) ...[
          OutlinedButton(
            key: const Key('game.recap'),
            onPressed: pressed(() => showGameRecap(context, recap), Press.tap),
            child: Text(RecapStrings.of(context).open),
          ),
          const SizedBox(height: 12),
        ],
        ElevatedButton(onPressed: pressed(_goHome, Press.confirm), child: Text(_t.backHome)),
      ],
    );
  }
}
