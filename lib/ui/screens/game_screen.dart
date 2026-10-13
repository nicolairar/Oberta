import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../narration/death_story.dart';
import '../../narration/narrator_script.dart';
import '../../rules/game_engine.dart';
import '../../rules/game_settings.dart';
import '../../rules/game_setup.dart';
import '../../rules/player.dart';
import '../../rules/role.dart';
import '../theme/app_theme.dart';
import '../theme/role_style.dart';
import '../widgets/avatar_spotlight.dart';
import '../widgets/death_scene.dart';
import '../widgets/handoff_view.dart';
import '../widgets/narrator_roles_sheet.dart';
import '../widgets/player_grid.dart';
import '../widgets/role_reveal_card.dart';
import '../widgets/scene_scaffold.dart';
import '../widgets/script_card.dart';

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

enum _Stage { script, handoff, task, taskDone, crimeIntro, crime, toNarrator, day, vote, end }

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
  late final NarratorScript _script = NarratorScript(random: widget.random);

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
  List<DeathStory> _deaths = const [];
  int _crime = 0;
  List<ScriptLine> _voteLines = const [];
  List<ScriptLine> _endingLines = const [];

  Player? get _narrator => widget.setup.narrator;

  @override
  void initState() {
    super.initState();
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
    _title = 'NOTTE $round';
    _mood = SceneMood.night;
    _stage = _Stage.script;
    _page = _ScriptPage(
      icon: Icons.nightlight_round,
      title: round == 1 ? _script.city.title : 'Cala la notte',
      lines: [if (round == 1) ..._script.opening(), ..._script.nightFalls(round)],
      action: 'COMINCIA LA NOTTE',
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
      // La notte è finita. Ogni morte si compone una volta sola: la stessa
      // storia va prima in scena e poi nel copione del narratore.
      _dawn = _engine.resolveNight();
      _deaths = [for (var i = 0; i < _dawn.victims.length; i++) _script.composeDeath()];
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
    _title = 'ALBA';
    _mood = SceneMood.dawn;
    _stage = _Stage.script;
    _page = _ScriptPage(
      icon: Icons.wb_twilight,
      title: report.victims.isEmpty ? 'Tutti vivi' : 'Cronaca nera',
      lines: _script.dawn(report, discussion: widget.settings.discussion, stories: _deaths),
      portraits: [for (final victim in report.victims) victim.name],
      portraitsFallen: true,
      action: winner != null ? 'FINALE' : 'APRI LA DISCUSSIONE',
      onAction: () => _advance(() {
        if (winner != null) {
          _enterEnd(winner);
        } else {
          _title = 'GIORNO ${_engine.round}';
          _mood = SceneMood.day;
          _stage = _Stage.day;
        }
      }),
    );
  }

  void _enterVerdict(Player? condemned) {
    final report = _engine.lynch(condemned);
    final winner = report.winner;
    _title = 'IL VERDETTO';
    _mood = SceneMood.dusk;
    _stage = _Stage.script;
    _page = _ScriptPage(
      icon: Icons.gavel,
      title: condemned?.name ?? 'Nessuna condanna',
      lines: _script.lynch(report),
      portraits: [if (condemned != null) condemned.name],
      revealed: report.role,
      action: winner != null ? 'FINALE' : 'CONTINUA',
      onAction: () => _advance(() => winner != null ? _enterEnd(winner) : _enterNight()),
    );
  }

  void _enterEnd(Team winner) {
    _title = 'FINE';
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
        title: const Text('Abbandonare la partita?'),
        content: const Text('La partita in corso andrà persa.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('RESTA')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('ESCI')),
        ],
      ),
    );
    if (leave == true && mounted) _goHome();
  }

  @override
  Widget build(BuildContext context) {
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
            victimName: _dawn.victims[_crime].name,
            caption: story.scene.text,
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
            tooltip: 'Abbandona la partita',
            onPressed: _confirmExit,
          ),
          title: Text(_title),
          actions: [
            if (_narrator != null && phoneIsWithNarrator)
              IconButton(
                icon: const Icon(Icons.visibility),
                tooltip: 'Ruoli, solo per il narratore',
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
        _Stage.script => _ScriptView(page: _page, reader: _narrator?.name),
        _Stage.handoff => HandoffView(
            name: _queue[_turn].name,
            onReady: () => _advance(() => _stage = _Stage.task),
          ),
        _Stage.task => _taskView(_queue[_turn]),
        _Stage.taskDone => _taskDoneView(),
        _Stage.crimeIntro => _crimeIntroView(),
        _Stage.crime => const SizedBox.shrink(),
        _Stage.toNarrator => HandoffView(name: _narrator!.name, onReady: () => _advance(_enterDawn)),
        _Stage.day => _DayView(
            duration: widget.settings.discussion,
            grid: _publicGrid(),
            onVote: () => _advance(() {
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
          'Telefono\nsul tavolo',
          textAlign: TextAlign.center,
          style: AppText.display(34),
        ),
        const SizedBox(height: 14),
        const Text(
          'Mettetelo al centro e guardate tutti.\nStanotte è successo qualcosa.',
          textAlign: TextAlign.center,
          style: AppText.body,
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => _advance(() => _stage = _Stage.crime),
            child: const Text('BUIO IN SALA'),
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
              child: OutlinedButton(onPressed: () => _submit(null), child: const Text('PASSO')),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: selected == null ? null : () => _submit(selected),
                child: const Text('CONFERMA'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _taskDoneView() {
    final finding = _finding;
    return Column(
      children: [
        const Spacer(),
        if (finding == null) ...[
          const Icon(Icons.check_circle_outline, color: AppColors.gold, size: 56),
          const SizedBox(height: 20),
          Text('Fatto.', style: AppText.display(36)),
          const SizedBox(height: 12),
          const Text('Nessuno saprà cosa hai scelto.', style: AppText.body),
        ] else ...[
          const Icon(Icons.search, color: AppColors.gold, size: 56),
          const SizedBox(height: 20),
          const Text('LA TUA INDAGINE', style: AppText.overline),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              finding.subject.name.toUpperCase(),
              style: AppText.display(36, color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            finding.team == Team.mafia ? 'È DELLA FAMIGLIA' : 'È INNOCENTE',
            style: AppText.display(
              20,
              color: finding.team == Team.mafia ? _mafiaRed : _cleanGreen,
            ),
          ),
        ],
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(onPressed: _afterTask, child: const Text('FATTO')),
        ),
      ],
    );
  }

  Widget _publicGrid({List<Player>? selectable}) {
    return PlayerGrid(
      players: widget.setup.players,
      isAlive: _engine.isAlive,
      knowledgeOf: (player) => _engine.knowledgeOf(null, player),
      selectable: selectable,
      selected: _selected,
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
                child: const Text('NESSUNO'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: selected == null ? null : () => _advance(() => _enterVerdict(selected)),
                child: const Text('CONDANNA'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _fateOf(Player player) {
    for (final record in _engine.history) {
      if (record.nightVictims.contains(player)) return 'Notte ${record.round}';
      if (record.lynched == player) return 'Patibolo, giorno ${record.round}';
    }
    return 'Ancora in piedi';
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
          mafiaWon ? 'Vince\nla famiglia' : 'Vincono\ngli onesti',
          textAlign: TextAlign.center,
          style: AppText.display(36, color: mafiaWon ? _mafiaRed : AppColors.gold),
        ),
        const SizedBox(height: 20),
        ScriptCard(reader: _narrator?.name, lines: _endingLines),
        const SizedBox(height: 28),
        const Text('CHI ERA CHI', style: AppText.overline),
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
              entry.value.label,
              style: TextStyle(
                color: entry.value.team == Team.mafia ? _mafiaRed : AppColors.textSecondary,
              ),
            ),
            trailing: Text(_fateOf(entry.key), style: AppText.body.copyWith(fontSize: 13)),
          ),
        if (suspects.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text('LA FACCIA PIÙ SOSPETTA', style: AppText.overline),
          const SizedBox(height: 6),
          Text(
            '${suspects.first.key.name}, con ${suspects.first.value} '
            '${suspects.first.value == 1 ? 'dito puntato' : 'dita puntate'} nel buio. '
            '${widget.setup.roleOf(suspects.first.key).team == Team.mafia ? 'A ragione.' : 'A torto.'}',
            style: AppText.body.copyWith(color: AppColors.textPrimary),
          ),
        ],
        const SizedBox(height: 28),
        ElevatedButton(onPressed: _goHome, child: const Text('TORNA ALLA HOME')),
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

  const _ScriptView({required this.page, required this.reader});

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
        ? ('CONTINUA A LEGGERE', _readOn)
        : cardCovered
            ? ('GIRA LA CARTA', _turnCard)
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
  final Duration duration;
  final Widget grid;
  final VoidCallback onVote;

  const _DayView({required this.duration, required this.grid, required this.onVote});

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
      if (_left == Duration.zero) HapticFeedback.heavyImpact();
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
    return Column(
      children: [
        Text(
          '$minutes:$seconds',
          style: AppText.display(64, color: expired ? AppColors.accent : AppColors.gold),
        ),
        Text(expired ? 'TEMPO SCADUTO' : 'LA PIAZZA DISCUTE', style: AppText.overline),
        const SizedBox(height: 16),
        Expanded(child: widget.grid),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _left += const Duration(minutes: 1)),
                child: const Text('+1 MIN'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(onPressed: widget.onVote, child: const Text('AL VOTO')),
            ),
          ],
        ),
      ],
    );
  }
}
