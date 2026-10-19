import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
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
import '../theme/role_style.dart';
import '../widgets/avatar_spotlight.dart';
import '../widgets/day_board.dart';
import '../widgets/night_notes.dart';
import '../widgets/death_scene.dart';
import '../widgets/handoff_view.dart';
import '../widgets/narrator_roles_sheet.dart';
import '../widgets/roles_sheet.dart';
import '../widgets/player_avatar.dart';
import '../widgets/player_grid.dart';
import '../widgets/city_backdrop.dart';
import '../widgets/sky_events.dart';
import '../widgets/scene_scaffold.dart';
import '../widgets/script_page_view.dart';
import '../widgets/spoken_script_card.dart';
import '../press.dart';
import '../seating.dart';

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

enum _Stage { script, handoff, task, taskDone, crimeIntro, crime, toNarrator, day, vote, verdict, end }

class _GameScreenState extends State<GameScreen> {
  static const _mafiaRed = Color(0xFFE5606A);
  static const _cleanGreen = Color(0xFF6FBF9A);

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
  /// ha il telefono adesso, rimescolato a ogni turno (vedi `seating.dart`).
  late final List<Player> _table = publicSeating(widget.setup.players);
  late final Random _seating = widget.seating ?? Random();
  List<Player> _seats = const [];

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

  void _submit(Player? target) {
    _advance(() {
      _finding = _engine.submitNightChoice(_queue[_turn], target, alternative: _alternative && target != null);
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

  /// La piazza ha votato e l'ha visto tutto il tavolo: niente film. Il posto
  /// del condannato fa il linciaggio sul posto e mostra la carta, se ora è
  /// pubblica; sotto, il copione del verdetto da leggere.
  void _enterVerdict(Player? condemned) {
    _verdict = _engine.lynch(condemned);
    _condemned = condemned;
    final report = _verdict;
    if (report.role != null) SoundStage.instance.cue(report.role!.team == Team.mafia ? Cue.caught : Cue.drumroll);
    // Nessuna condanna: il silenzio imbarazzato della battuta che non ride nessuno.
    if (condemned == null) beat(MemeMoment.noConviction, after: const Duration(milliseconds: 600));
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
    SoundStage.instance.music(dark ? MusicMood.winFamily : MusicMood.winTown);
    SoundStage.instance.ambience(null);
    SoundStage.instance.cue(dark ? Cue.familyWins : Cue.townWins);
    beat(dark ? MemeMoment.mafiaWins : MemeMoment.townWins, after: const Duration(milliseconds: 800));
    _title = _t.endTitle;
    _mood = dark ? SceneMood.night : SceneMood.dawn;
    _endingLines = _script.ending(
      winner,
      assassin: _engine.personalWins.any((player) => widget.setup.roleOf(player) == Role.sicario),
    );
    _stage = _Stage.end;
  }

  void _goHome() => Navigator.of(context).popUntil((route) => route.isFirst);

  Future<void> _confirmExit() async {
    if (_stage == _Stage.end) {
      _goHome();
      return;
    }
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(_t.leaveQuestion),
        content: Text(_t.leaveWarning),
        actions: [
          TextButton(onPressed: pressed(() => Navigator.of(context).pop(false), Press.back), child: Text(_t.stay)),
          TextButton(onPressed: pressed(() => Navigator.of(context).pop(true), Press.tap), child: Text(_t.leave)),
        ],
      ),
    );
    if (leave == true && mounted) _goHome();
  }

  @override
  void dispose() {
    for (final thunder in _thunders) {
      thunder.cancel();
    }
    SoundStage.instance.ambience(null);
    NarratorVoice.instance.hush();
    // La musica del vicolo la rimette il vicolo, quando ci si torna.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screen = _screen();
    // Se intanto l'app ha cambiato lingua, la partita resta in quella in cui
    // è cominciata: anche i pezzi che i testi li cercano da sé.
    if (identical(AppStrings.of(context), _t)) return screen;
    return Localizations.override(context: context, locale: _t.language.locale, child: screen);
  }

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
    final phoneIsWithNarrator =
        _stage == _Stage.script || _stage == _Stage.day || _stage == _Stage.vote;
    return PopScope(
      canPop: false,
      child: SceneScaffold(
        mood: _mood,
        style: skylineFor(_script.city.id),
        rain: _mood == SceneMood.night && _engine.round.isOdd,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: _t.leaveTooltip,
            onPressed: pressed(_confirmExit, Press.back),
          ),
          title: Text(_title),
          actions: [
            RolesButton(
              onPressed: pressed(
                () {
                  final board = _engine.publicView();
                  RolesSheet.show(context, deck: board.deck, revealed: publicReveals(board));
                },
                Press.card,
              ),
            ),
            if (_narrator != null && phoneIsWithNarrator)
              IconButton(
                icon: const Icon(Icons.visibility),
                tooltip: _t.rolesTooltip,
                onPressed: pressed(
                  () => NarratorRolesSheet.show(
                    context,
                    setup: widget.setup,
                    isAlive: _engine.isAlive,
                  ),
                  Press.card,
                ),
              ),
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

  Widget _stageView() => switch (_stage) {
        _Stage.script => ScriptPageView(page: _page, reader: _narrator?.name, strings: _t),
        _Stage.handoff => HandoffView(
            name: _queue[_turn].name,
            onReady: () => _advance(() {
              // Chi siede accanto non deve poter leggere il bersaglio dal
              // posto del dito: a ogni turno le facce cambiano posto.
              _seats = secretSeating(widget.setup.players, _seating, avoid: [_seats, _table]);
              _stage = _Stage.task;
            }),
          ),
        _Stage.task => _taskView(_queue[_turn]),
        _Stage.taskDone => _taskDoneView(),
        _Stage.crimeIntro => _crimeIntroView(),
        _Stage.crime => const SizedBox.shrink(),
        _Stage.verdict => _verdictView(),
        _Stage.toNarrator => HandoffView(name: _narrator!.name, onReady: () => _advance(_enterDawn)),
        _Stage.day => DayBoard(
            strings: _t,
            duration: widget.settings.discussion,
            table: _publicGrid(),
            alive: _engine.alivePlayers.length,
            total: widget.setup.players.length,
            onVote: () => _advance(() {
              beat(MemeMoment.voteCall);
              _voteLines = _script.voteCall();
              _stage = _Stage.vote;
            }),
          ),
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

  Widget _taskView(Player actor) {
    final offered = _engine.taskFor(actor);
    final alternative = offered.alternative;
    final task =
        _alternative && alternative != null ? NightTask(alternative, offered.alternativeTargets) : offered;
    final selected = _selected;
    final labels = alternativeLabels(_t, alternative);
    final watches = _engine.watchesOf(actor);
    final lastWatch = watches.isNotEmpty && watches.last.round == _engine.round - 1 ? watches.last : null;
    return Column(
      children: [
        NightNotes(
          lastWatch: lastWatch,
          doused: [
            if (widget.setup.roleOf(actor) == Role.piromane)
              for (final player in _seats)
                if (_engine.doused.contains(player)) player,
          ],
          bounty: _engine.bountyOf(actor),
        ),
        if (alternative != null) ...[
          SegmentedButton<bool>(
            key: const Key('task.alternative'),
            segments: [
              ButtonSegment(value: false, label: Text(labels.$1)),
              ButtonSegment(value: true, label: Text(labels.$2)),
            ],
            selected: {_alternative},
            showSelectedIcon: false,
            onSelectionChanged: (choice) => setState(() {
              _alternative = choice.single;
              // Il fiammifero si accende scegliendo se stessi: già scelto.
              _selected = _alternative && alternative == NightTaskKind.ignite ? actor : null;
            }),
          ),
          const SizedBox(height: 12),
        ],
        Text(
          _script.taskPrompt(task, _engine.round),
          textAlign: TextAlign.center,
          style: AppText.display(23, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 6),
        Text(_script.taskHint(task), textAlign: TextAlign.center, style: AppText.body.copyWith(fontSize: 14)),
        const SizedBox(height: 14),
        Expanded(
          child: PlayerGrid(
            players: _seats,
            isAlive: _engine.isAlive,
            knowledgeOf: (player) => _engine.knowledgeOf(actor, player),
            viewer: actor,
            selectable: task.targets,
            selected: selected,
            onSelect: (player) => setState(() => _selected = player),
            shuffled: true,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(onPressed: pressed(() => _submit(null), Press.tap), child: Text(_t.pass)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: pressed(selected == null ? null : () => _submit(selected), Press.tap),
                child: Text(_t.confirm),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _taskDoneView() {
    final finding = _finding;
    final found = finding?.role;
    final isMafia = finding?.team == Team.mafia;
    return Column(
      children: [
        const Spacer(),
        if (finding == null) ...[
          const Icon(Icons.check_circle_outline, color: AppColors.gold, size: 56),
          const SizedBox(height: 20),
          Text(_t.doneTitle, style: AppText.display(36)),
          const SizedBox(height: 12),
          Text(_t.nobodyWillKnow, style: AppText.body),
        ] else ...[
          // L'indagine dice da che parte sta; la fossa dice chi era.
          SizedBox.square(
            dimension: 150,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                AvatarSpotlight(seed: finding.subject.name, size: 140, fallen: found != null),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: found?.color ?? (isMafia ? AppColors.accent : const Color(0xFF1E6B52)),
                      border: Border.all(color: AppColors.background, width: 3),
                    ),
                    child: found == null
                        ? const Icon(Icons.search, color: AppColors.textPrimary, size: 26)
                        : RoleIcon(found, size: 44),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(found == null ? _t.yourInvestigation : _t.inTheGrave, style: AppText.overline),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              finding.subject.name.toUpperCase(),
              style: AppText.display(36, color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              found != null
                  ? _t.wasRole(_t.role(found).label)
                  : isMafia
                      ? _t.isFamily
                      : _t.isInnocent,
              style: AppText.display(20, color: isMafia ? _mafiaRed : _cleanGreen),
            ),
          ),
          if (found != null) ...[
            const SizedBox(height: 10),
            Text(
              isMafia ? _t.wasWithFamily : _t.wasWithTown,
              style: AppText.overline,
            ),
          ],
        ],
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(onPressed: pressed(_afterTask, Press.confirm), child: Text(_t.done)),
        ),
      ],
    );
  }

  /// La griglia del giorno, uguale per tutti: sta in mezzo al tavolo.
  Widget _publicGrid({List<Player>? selectable, Player? lynched}) {
    return PlayerGrid(
      lynched: lynched,
      lynchedLabel: _t.language.locale.languageCode == 'it' ? 'Linciato' : 'Lynched',
      players: _table,
      isAlive: _engine.isAlive,
      knowledgeOf: (player) => _engine.knowledgeOf(null, player),
      selectable: selectable,
      selected: _selected,
      silenced: _dawn.silenced,
      stamp: _t.accusedStamp,
      onSelect: (player) {
        // Il dito punta qualcuno in piazza: sus.
        if (player != _selected) beat(_selected == null ? MemeMoment.accused : MemeMoment.voteChanged);
        setState(() => _selected = player);
      },
    );
  }

  /// Il verdetto sul tavolo: il linciaggio sul posto, il copione sotto.
  Widget _verdictView() {
    final winner = _verdict.winner;
    return LayoutBuilder(
      key: const Key('game.verdict'),
      builder: (context, box) => Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _condemned?.name ?? _t.noConviction,
              key: const Key('game.verdictTitle'),
              style: AppText.display(26, color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: _publicGrid(lynched: _condemned)),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: box.maxHeight * 0.3),
            child: SingleChildScrollView(child: SpokenScriptCard(reader: _narrator?.name, lines: _verdictLines)),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: pressed(
                () => _advance(() => winner != null ? _enterEnd(winner) : _enterNight()),
                Press.confirm,
              ),
              child: Text(winner != null ? _t.finale : _t.continueLabel),
            ),
          ),
        ],
      ),
    );
  }

  Widget _voteView() {
    final selected = _selected;
    return LayoutBuilder(
      builder: (context, box) => Column(
      children: [
        // Il copione del voto resta in alto e non ruba il tavolo: se è lungo
        // scorre, e la voce lo segue da sola.
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: box.maxHeight * 0.26),
          child: SingleChildScrollView(child: SpokenScriptCard(reader: _narrator?.name, lines: _voteLines)),
        ),
        const SizedBox(height: 14),
        Expanded(child: _publicGrid(selectable: _engine.alivePlayers)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: pressed(() => _advance(() => _enterVerdict(null)), Press.tap),
                child: Text(_t.nobody),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: pressed(selected == null ? null : () => _advance(() => _enterVerdict(selected)), Press.tap),
                child: Text(_t.condemn),
              ),
            ),
          ],
        ),
      ],
      ),
    );
  }

  String _fateOf(Player player) {
    for (final record in _engine.history) {
      if (record.nightVictims.contains(player)) return _t.fateNight(record.round);
      if (record.lynched == player) return _t.fateGallows(record.round);
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
          arsonistWon
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
        ElevatedButton(onPressed: pressed(_goHome, Press.confirm), child: Text(_t.backHome)),
      ],
    );
  }
}
