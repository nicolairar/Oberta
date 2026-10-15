import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
import '../../sound/memes.dart';
import '../../sound/sound_stage.dart';
import '../../sound/verdict_stage.dart';
import '../theme/app_theme.dart';
import '../theme/role_style.dart';
import '../widgets/avatar_spotlight.dart';
import '../widgets/death_scene.dart';
import '../widgets/handoff_view.dart';
import '../widgets/narrator_roles_sheet.dart';
import '../widgets/player_grid.dart';
import '../widgets/role_reveal_card.dart';
import '../widgets/city_backdrop.dart';
import '../widgets/sky_events.dart';
import '../widgets/scene_scaffold.dart';
import '../widgets/script_card.dart';
import '../widgets/verdict_scene.dart';

/// La partita su un solo telefono: il copione si legge ad alta voce, di notte
/// il telefono fa il giro del tavolo, di giorno resta in mezzo.
class GameScreen extends StatefulWidget {
  final GameSetup setup;
  final GameSettings settings;
  final Random? random;

  const GameScreen({
    super.key,
    required this.setup,
    this.settings = const GameSettings(),
    this.random,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

enum _Stage { script, handoff, task, taskDone, crimeIntro, crime, toNarrator, day, vote, verdict, end }

class _ScriptPage {
  final IconData icon;
  final String title;
  final List<ScriptLine> lines;

  /// Di chi parla la pagina: i loro ritratti prendono il posto dell'icona.
  final List<String> portraits;
  final bool portraitsFallen;

  /// Il ruolo che questa pagina svela. Resta coperto, insieme alle battute
  /// dopo la prima, finché chi legge non gira la carta.
  final Role? revealed;
  final String action;
  final VoidCallback onAction;

  const _ScriptPage({
    required this.icon,
    required this.title,
    required this.lines,
    this.portraits = const [],
    this.portraitsFallen = false,
    this.revealed,
    required this.action,
    required this.onAction,
  });
}

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
  late _ScriptPage _page;
  List<Player> _queue = const [];
  int _turn = 0;
  Player? _selected;
  Exposure? _finding;
  late DawnReport _dawn;
  // Il verdetto della piazza, tra il filmato e la pagina della carta. Il
  // filmato si sceglie con un dado tutto suo: non guarda mai il ruolo.
  final Random _dice = Random();
  Player? _condemned;
  late LynchReport _verdict;
  late String _verdictTake;
  List<DeathStory> _deaths = const [];
  int _crime = 0;
  List<ScriptLine> _voteLines = const [];
  List<ScriptLine> _endingLines = const [];

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
    setState(() {
      change();
      _selected = null;
      _step++;
    });
  }

  void _enterNight() {
    final round = _engine.round;
    SoundStage.instance.music(MusicMood.night);
    _nightAtmosphere();
    _title = _t.nightTitle(round);
    _mood = SceneMood.night;
    _stage = _Stage.script;
    _page = _ScriptPage(
      icon: Icons.nightlight_round,
      title: round == 1 ? _script.city.title : _t.nightFalls,
      lines: [if (round == 1) ..._script.opening(), ..._script.nightFalls(round)],
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
      _finding = _engine.submitNightChoice(_queue[_turn], target);
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
      SoundStage.instance.prepare([for (final story in _deaths) deathActFor(story.method.id)]);
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
    if (report.scoop?.team == Team.mafia) SoundStage.instance.meme(Meme.vineBoom, after: const Duration(seconds: 2));
    _title = _t.dawnTitle;
    _mood = SceneMood.dawn;
    _stage = _Stage.script;
    _page = _ScriptPage(
      icon: Icons.wb_twilight,
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
          // La piazza di giorno: gli uccelli passano, e dove c'è il campanile suonano le ore.
          _seenAndHeard(_hasBellTower && _atmosphere.nextBool() ? FxGroup.church : FxGroup.birds);
          SoundStage.instance.prepareVerdicts();
          _stage = _Stage.day;
        }
      }),
    );
  }

  /// La piazza ha votato: prima il filmato (che non dice niente del ruolo),
  /// poi la pagina del verdetto con la carta da girare.
  void _enterVerdict(Player? condemned) {
    _verdict = _engine.lynch(condemned);
    _condemned = condemned;
    _verdictTake = VerdictScene.variants[_dice.nextInt(VerdictScene.variants.length)];
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
    SoundStage.instance.ambience(raining ? FxGroup.rain : _pick(const [FxGroup.crickets, FxGroup.wind]));
    final night = [
      FxGroup.owl, FxGroup.dog, FxGroup.cat, FxGroup.siren, FxGroup.train, FxGroup.carpass,
      if (_portCity) FxGroup.foghorn,
      if (raining) ...[FxGroup.thunder, FxGroup.thunder],
    ];
    _nightSound(_pick(night), const Duration(milliseconds: 900));
    if (_atmosphere.nextBool()) _nightSound(_pick(night), const Duration(seconds: 6), volume: 0.7);
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
  bool get _hasBellTower => {SkylineStyle.mediterranean, SkylineStyle.volcano}.contains(skylineFor(_script.city.id));

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
    if (group == FxGroup.thunder) CityBackdrop.flash();
    if (scene != null) CityBackdrop.show(scene);
    stage.effect(group, after: Duration(milliseconds: delay), volume: volume);
  }

  /// L'alba: il gallo, gli uccelli, a volte le campane.
  void _dawnAtmosphere() {
    final stage = SoundStage.instance;
    stage.ambience(null);
    _thunders.add(Timer(const Duration(milliseconds: 300), () {
      if (mounted) _seenAndHeard(FxGroup.rooster);
    }));
    _thunders.add(Timer(const Duration(seconds: 3), () {
      if (mounted) _seenAndHeard(FxGroup.birds, volume: 0.8);
    }));
    // Le campane solo dove c'è un campanile all'orizzonte.
    if (_hasBellTower && _atmosphere.nextBool()) stage.effect(FxGroup.church, after: const Duration(seconds: 4), volume: 0.7);
  }

  void _afterVerdictScene() => _advance(_enterVerdictPage);

  void _enterVerdictPage() {
    final report = _verdict;
    final condemned = _condemned;
    final winner = report.winner;
    // Il rullo di tamburi accompagna il condannato fino alla carta.
    if (report.role != null) SoundStage.instance.cue(Cue.drumroll);
    // Nessuna condanna: il silenzio imbarazzato della battuta che non ride nessuno.
    if (condemned == null) SoundStage.instance.meme(Meme.chicken, after: const Duration(milliseconds: 600));
    _title = _t.verdictTitle;
    _mood = SceneMood.dusk;
    _stage = _Stage.script;
    _page = _ScriptPage(
      icon: Icons.gavel,
      title: condemned?.name ?? _t.noConviction,
      lines: _script.lynch(report),
      portraits: [if (condemned != null) condemned.name],
      revealed: report.role,
      action: winner != null ? _t.finale : _t.continueLabel,
      onAction: () => _advance(() => winner != null ? _enterEnd(winner) : _enterNight()),
    );
  }

  void _enterEnd(Team winner) {
    SoundStage.instance.music(winner == Team.mafia ? MusicMood.winFamily : MusicMood.winTown);
    SoundStage.instance.cue(winner == Team.mafia ? Cue.familyWins : Cue.townWins);
    if (winner == Team.mafia) SoundStage.instance.meme(Meme.catLaugh, after: const Duration(milliseconds: 800));
    _title = _t.endTitle;
    _mood = winner == Team.mafia ? SceneMood.night : SceneMood.dawn;
    _endingLines = _script.ending(winner);
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
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(_t.stay)),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(_t.leave)),
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
    // Fuori dalla partita si torna al sottofondo del menu.
    SoundStage.instance.music(MusicMood.menu);
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
    if (_stage == _Stage.verdict) {
      final condemned = _condemned;
      final style = skylineFor(_script.city.id);
      return PopScope(
        canPop: false,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: condemned == null
              ? VerdictScene.acquittal(key: ValueKey('verdict-$_step'), style: style, onFinished: _afterVerdictScene)
              : VerdictScene(
                  key: ValueKey('verdict-$_step'),
                  condemnedName: condemned.name,
                  variant: _verdictTake,
                  town: _script.city.name,
                  style: style,
                  onFinished: _afterVerdictScene,
                ),
        ),
      );
    }
    if (_stage == _Stage.crime) {
      // Il delitto va in scena a tutto schermo, senza barre né pulsanti.
      final story = _deaths[_crime];
      return PopScope(
        canPop: false,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: DeathScene(
            key: ValueKey('crime-$_step'),
            act: deathActFor(story.method.id),
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
            onPressed: _confirmExit,
          ),
          title: Text(_title),
          actions: [
            if (_narrator != null && phoneIsWithNarrator)
              IconButton(
                icon: const Icon(Icons.visibility),
                tooltip: _t.rolesTooltip,
                onPressed: () => NarratorRolesSheet.show(
                  context,
                  setup: widget.setup,
                  isAlive: _engine.isAlive,
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
        _Stage.script => _ScriptView(page: _page, reader: _narrator?.name, strings: _t),
        _Stage.handoff => HandoffView(
            name: _queue[_turn].name,
            onReady: () => _advance(() => _stage = _Stage.task),
          ),
        _Stage.task => _taskView(_queue[_turn]),
        _Stage.taskDone => _taskDoneView(),
        _Stage.crimeIntro => _crimeIntroView(),
        _Stage.crime || _Stage.verdict => const SizedBox.shrink(),
        _Stage.toNarrator => HandoffView(name: _narrator!.name, onReady: () => _advance(_enterDawn)),
        _Stage.day => _DayView(
            strings: _t,
            duration: widget.settings.discussion,
            grid: _publicGrid(),
            onVote: () => _advance(() {
              SoundStage.instance.meme(Meme.dexter);
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
            onPressed: () => _advance(() => _stage = _Stage.crime),
            child: Text(_t.lightsDown),
          ),
        ),
      ],
    );
  }

  Widget _taskView(Player actor) {
    final task = _engine.taskFor(actor);
    final selected = _selected;
    return Column(
      children: [
        Text(
          _script.taskPrompt(task, _engine.round),
          textAlign: TextAlign.center,
          style: AppText.display(24, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 8),
        Text(_script.taskHint(task), textAlign: TextAlign.center, style: AppText.body),
        const SizedBox(height: 12),
        Expanded(
          child: PlayerGrid(
            players: widget.setup.players,
            isAlive: _engine.isAlive,
            knowledgeOf: (player) => _engine.knowledgeOf(actor, player),
            viewer: actor,
            selectable: task.targets,
            selected: selected,
            onSelect: (player) => setState(() => _selected = player),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(onPressed: () => _submit(null), child: Text(_t.pass)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: selected == null ? null : () => _submit(selected),
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
          Icon(found?.icon ?? Icons.search, color: AppColors.gold, size: 56),
          const SizedBox(height: 20),
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
          child: ElevatedButton(onPressed: _afterTask, child: Text(_t.done)),
        ),
      ],
    );
  }

  /// La griglia del giorno, uguale per tutti: sta in mezzo al tavolo.
  Widget _publicGrid({List<Player>? selectable}) {
    return PlayerGrid(
      players: widget.setup.players,
      isAlive: _engine.isAlive,
      knowledgeOf: (player) => _engine.knowledgeOf(null, player),
      selectable: selectable,
      selected: _selected,
      silenced: _dawn.silenced,
      onSelect: (player) => setState(() => _selected = player),
    );
  }

  Widget _voteView() {
    final selected = _selected;
    return Column(
      children: [
        ScriptCard(reader: _narrator?.name, lines: _voteLines),
        const SizedBox(height: 12),
        Expanded(child: _publicGrid(selectable: _engine.alivePlayers)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _advance(() => _enterVerdict(null)),
                child: Text(_t.nobody),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: selected == null ? null : () => _advance(() => _enterVerdict(selected)),
                child: Text(_t.condemn),
              ),
            ),
          ],
        ),
      ],
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
          mafiaWon ? _t.familyWins : _t.townWins,
          textAlign: TextAlign.center,
          style: AppText.display(36, color: mafiaWon ? _mafiaRed : AppColors.gold),
        ),
        const SizedBox(height: 20),
        ScriptCard(reader: _narrator?.name, lines: _endingLines),
        const SizedBox(height: 28),
        Text(_t.whoWasWho, style: AppText.overline),
        const SizedBox(height: 4),
        for (final entry in widget.setup.roles.entries)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: entry.value.color,
              child: Icon(entry.value.icon, size: 20, color: AppColors.textPrimary),
            ),
            title: Text(
              entry.key.name,
              style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              _t.role(entry.value).label,
              style: TextStyle(
                color: entry.value.team == Team.mafia ? _mafiaRed : AppColors.textSecondary,
              ),
            ),
            trailing: Text(_fateOf(entry.key), style: AppText.body.copyWith(fontSize: 13)),
          ),
        if (suspects.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(_t.mostSuspicious, style: AppText.overline),
          const SizedBox(height: 6),
          Text(
            _t.suspicion(
              suspects.first.key.name,
              suspects.first.value,
              rightly: widget.setup.roleOf(suspects.first.key).team == Team.mafia,
            ),
            style: AppText.body.copyWith(color: AppColors.textPrimary),
          ),
        ],
        const SizedBox(height: 28),
        ElevatedButton(onPressed: _goHome, child: Text(_t.backHome)),
      ],
    );
  }
}

/// Una pagina di copione. Se il testo non sta nello schermo, il pulsante
/// accompagna chi legge fino in fondo prima di lasciarlo andare avanti: le
/// istruzioni che contano stanno spesso nelle ultime righe.
class _ScriptView extends StatefulWidget {
  final _ScriptPage page;
  final String? reader;
  final AppStrings strings;

  const _ScriptView({required this.page, required this.reader, required this.strings});

  @override
  State<_ScriptView> createState() => _ScriptViewState();
}

class _ScriptViewState extends State<_ScriptView> {
  final _scroll = ScrollController();
  bool _cardTurned = false;
  bool _moreBelow = false;

  /// Una volta arrivati in fondo non si torna indietro: se il pulsante
  /// cambiando etichetta spostasse il testo di qualche punto, lo stato
  /// rimbalzerebbe all'infinito tra "c'è altro" e "finito".
  bool _reachedEnd = false;

  @override
  void initState() {
    super.initState();
    _checkAfterLayout();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _checkAfterLayout() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) _update(_scroll.position);
    });
  }

  bool _update(ScrollMetrics metrics) {
    if (metrics.extentAfter <= 12) _reachedEnd = true;
    final more = !_reachedEnd;
    if (more != _moreBelow) setState(() => _moreBelow = more);
    return false;
  }

  void _readOn() {
    final position = _scroll.position;
    _scroll.animateTo(
      min(position.maxScrollExtent, position.pixels + position.viewportDimension * 0.7),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
  }

  void _turnCard() {
    HapticFeedback.heavyImpact();
    final caught = widget.page.revealed?.team == Team.mafia;
    final stage = SoundStage.instance;
    if (stage.memeMode) {
      stage.meme(cardMeme(caught: caught));
    } else {
      stage.cue(caught ? Cue.caught : Cue.innocent);
    }
    setState(() {
      _cardTurned = true;
      _reachedEnd = false;
    });
    _checkAfterLayout();
  }

  @override
  Widget build(BuildContext context) {
    final page = widget.page;
    final revealed = page.revealed;
    final cardCovered = revealed != null && !_cardTurned;
    final (label, onPressed) = _moreBelow
        ? (widget.strings.keepReading, _readOn)
        : cardCovered
            ? (widget.strings.flipTheCard, _turnCard)
            : (page.action, page.onAction);

    return Column(
      children: [
        if (page.portraits.isEmpty)
          Icon(page.icon, color: AppColors.gold, size: 36)
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final name in page.portraits)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: AvatarSpotlight(
                    seed: name,
                    size: page.portraits.length > 1 ? 72 : 92,
                    fallen: page.portraitsFallen,
                  ),
                ),
            ],
          ),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(page.title, style: AppText.display(28)),
        ),
        if (revealed != null) ...[
          const SizedBox(height: 12),
          RoleRevealCard(role: revealed, faceUp: !cardCovered),
        ],
        const SizedBox(height: 16),
        Expanded(
          child: Stack(
            children: [
              NotificationListener<ScrollMetricsNotification>(
                onNotification: (notification) => _update(notification.metrics),
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notification) => _update(notification.metrics),
                  child: SingleChildScrollView(
                    controller: _scroll,
                    child: ScriptCard(
                      reader: widget.reader,
                      lines: cardCovered ? page.lines.sublist(0, 1) : page.lines,
                    ),
                  ),
                ),
              ),
              if (_moreBelow)
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 40,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0x0014110F), AppColors.background],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onPressed,
            child: FittedBox(fit: BoxFit.scaleDown, child: Text(label, maxLines: 1)),
          ),
        ),
      ],
    );
  }
}

class _DayView extends StatefulWidget {
  final AppStrings strings;
  final Duration duration;
  final Widget grid;
  final VoidCallback onVote;

  const _DayView({required this.strings, required this.duration, required this.grid, required this.onVote});

  @override
  State<_DayView> createState() => _DayViewState();
}

class _DayViewState extends State<_DayView> {
  static const _second = Duration(seconds: 1);

  late Duration _left = widget.duration;
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_second, (_) {
      if (_left == Duration.zero) return;
      setState(() => _left -= _second);
      if (_left == Duration.zero) {
        HapticFeedback.heavyImpact();
        SoundStage.instance.memeMode ? SoundStage.instance.meme(Meme.error) : SoundStage.instance.cue(Cue.timeUp);
      } else if (_left <= const Duration(seconds: 10)) {
        SoundStage.instance.cue(Cue.tick);
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final expired = _left == Duration.zero;
    final minutes = _left.inMinutes;
    final seconds = (_left.inSeconds % 60).toString().padLeft(2, '0');
    final t = widget.strings;
    return Column(
      children: [
        Text(
          '$minutes:$seconds',
          style: AppText.display(64, color: expired ? AppColors.accent : AppColors.gold),
        ),
        Text(expired ? t.timeUp : t.floorIsOpen, style: AppText.overline),
        const SizedBox(height: 16),
        Expanded(child: widget.grid),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _left += const Duration(minutes: 1)),
                child: Text(t.plusMinute),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(onPressed: widget.onVote, child: Text(t.callTheVote)),
            ),
          ],
        ),
      ],
    );
  }
}
