import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_strings.dart';
import '../../../narration/death_story.dart';
import '../../../narration/narrator_script.dart';
import '../../../online/game/game_authority.dart';
import '../../../online/game/game_client.dart';
import '../../../online/game/game_protocol.dart';
import '../../../online/online_services.dart';
import '../../../rules/game_engine.dart';
import '../../../rules/intent.dart';
import '../../../rules/knowledge.dart';
import '../../../rules/player.dart';
import '../../../rules/player_view.dart';
import '../../../rules/role.dart';
import '../../../sound/cue_sounds.dart';
import '../../../sound/narrator_voice.dart';
import '../../../sound/sound_stage.dart';
import '../../../sound/verdict_stage.dart';
import '../../press.dart';
import '../../seating.dart';
import '../../theme/app_theme.dart';
import '../../theme/role_style.dart';
import '../../widgets/avatar_spotlight.dart';
import '../../widgets/day_board.dart';
import '../../widgets/death_scene.dart';
import '../../widgets/flip_role_card.dart';
import '../../widgets/player_avatar.dart';
import '../../widgets/player_grid.dart';
import '../../widgets/scene_scaffold.dart';
import '../../widgets/script_page_view.dart';
import '../../widgets/verdict_scene.dart';
import 'online_widgets.dart';

/// Che cosa mostra il telefono adesso. Le prime sono momenti da guardare
/// (si va avanti col pulsante o a filmato finito); le altre seguono la
/// partita dal vivo.
enum _Stage { connecting, card, page, film, verdictFilm, task, waiting, vote, end }

/// La partita online, vista dal proprio telefono: la propria carta, le
/// proprie mosse, il narratore automatico e i filmati dal tavolo pubblico.
/// Lo schermo conosce solo il [GameClient]: la vista del proprio posto e il
/// tavolo di tutti. Anche sul telefono del padrone di casa, dove intanto
/// gira l'[authority], che qui si tiene solo in vita.
class OnlineGameScreen extends StatefulWidget {
  final OnlineServices services;
  final Room room;
  final Profile me;

  /// Solo sul telefono del padrone di casa: la partita, che vive finché
  /// vive questa schermata. Non si legge mai.
  final GameAuthority? authority;

  /// Il dado dei tavoli segreti (per i test).
  final Random? seating;

  const OnlineGameScreen({
    super.key,
    required this.services,
    required this.room,
    required this.me,
    this.authority,
    this.seating,
  });

  @override
  State<OnlineGameScreen> createState() => _OnlineGameScreenState();
}

class _OnlineGameScreenState extends State<OnlineGameScreen> {
  static const _mafiaRed = Color(0xFFE5606A);
  static const _cleanGreen = Color(0xFF6FBF9A);

  late final GameClient _client = GameClient(backend: widget.services.game, roomId: widget.room.id);
  late final AppStrings _t = widget.room.language.strings;
  late final Random _shuffle = widget.seating ?? Random();
  Timer? _ticker;

  _Stage _stage = _Stage.connecting;
  int _step = 0;

  // Fin dove questo telefono ha già mostrato la partita.
  bool _first = true;
  bool _cardSeen = false;
  int _nightShown = 0;

  /// L'ultimo fatto già raccontato: l'alba del giro r vale 2r, il verdetto 2r+1.
  int _eventShown = 0;

  ScriptPage? _page;
  List<DeathStory> _stories = const [];
  DawnReport? _dawn;
  int _film = 0;
  LynchReport? _verdict;
  String _verdictTake = VerdictScene.variants.first;

  Player? _selected;
  List<Player> _secret = const [];
  String? _secretTurn;

  /// Quello che l'ultima mossa ha scoperto (un'indagine, una fossa).
  Exposure? _finding;
  int? _findingFor;

  @override
  void initState() {
    super.initState();
    _client.addListener(_changed);
    // Il cronometro del voto, e l'occhio sul padrone di casa che tace.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && (_stage == _Stage.vote || _stage == _Stage.waiting || _stage == _Stage.task)) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _client.removeListener(_changed);
    _client.dispose();
    widget.authority?.dispose();
    NarratorVoice.instance.hush();
    SoundStage.instance.ambience(null);
    super.dispose();
  }

  OnlineBoard get _board => _client.board!;
  PlayerView get _view => _client.seat!.view;
  PublicView get _public => _board.view;

  bool get _live => const {_Stage.connecting, _Stage.task, _Stage.waiting, _Stage.vote}.contains(_stage);

  void _changed() {
    if (!mounted) return;
    if (_client.takeRejection() != null) showNote(context, _t.online.rejected);
    final seat = _client.seat;
    if (seat?.receipt case (:final id, result: IntentAccepted(:final finding?)) when id != _findingFor) {
      _findingFor = id;
      _finding = finding;
    }
    setState(() {
      if (_live) _route();
    });
  }

  // ---------------------------------------------------------------------
  // Il copione: lo stesso su ogni telefono, dallo stesso seme.

  late final _city = _t.pack.cities[(_board.narrationSeed) % _t.pack.cities.length];

  NarratorScript _script(String event) {
    var hash = 0x811c9dc5;
    for (final unit in event.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0x7fffffff;
    }
    return NarratorScript(pack: _t.pack, city: _city, random: Random(_board.narrationSeed ^ hash));
  }

  SkylineStyle get _style => skylineFor(_city.id);

  // ---------------------------------------------------------------------
  // Dove si va: il prossimo momento da mostrare.

  void _go(_Stage stage) {
    NarratorVoice.instance.hush();
    _stage = stage;
    _selected = null;
    _step++;
  }

  void _next() => setState(_route);

  void _route() {
    if (!_client.ready) {
      _stage = _Stage.connecting;
      return;
    }
    final board = _public;
    final dawnKey = board.lastDawn == null ? 0 : board.lastDawn!.round * 2;
    final lynchKey = board.lastLynch == null ? 0 : board.lastLynch!.round * 2 + 1;
    if (_first) {
      _first = false;
      final fresh = board.round == 1 && board.phase == GamePhase.night && board.lastDawn == null;
      if (!fresh) {
        // Chi rientra riparte da adesso: niente filmati vecchi.
        _eventShown = max(dawnKey, lynchKey);
        _nightShown = board.round;
      }
    }
    if (!_cardSeen) {
      if (_stage != _Stage.card) _go(_Stage.card);
      return;
    }
    final pending = [
      if (dawnKey > _eventShown) dawnKey,
      if (lynchKey > _eventShown) lynchKey,
    ]..sort();
    if (pending.isNotEmpty) {
      final key = pending.first;
      if (key.isEven) {
        _startDawn(board.lastDawn!);
      } else {
        _startVerdict(board.lastLynch!);
      }
      return;
    }
    switch (board.phase) {
      case GamePhase.night:
        if (_nightShown < board.round) {
          _nightShown = board.round;
          _nightPage(board.round);
          return;
        }
        final next = _view.action != null ? _Stage.task : _Stage.waiting;
        if (_stage != next) _go(next);
      case GamePhase.day:
        if (_stage != _Stage.vote) {
          _go(_Stage.vote);
          SoundStage.instance.music(MusicMood.day);
          SoundStage.instance.ambience(null);
        }
      case GamePhase.ended:
        if (_stage != _Stage.end) {
          _go(_Stage.end);
          final winner = board.winner!;
          SoundStage.instance.music(winner == Team.mafia ? MusicMood.winFamily : MusicMood.winTown);
          SoundStage.instance.cue(winner == Team.mafia ? Cue.familyWins : Cue.townWins);
        }
    }
  }

  void _nightPage(int round) {
    final script = _script('night-$round');
    SoundStage.instance.music(MusicMood.night);
    SoundStage.instance.cue(Cue.nightfall);
    _page = ScriptPage(
      icon: Icons.nightlight_round,
      title: round == 1 ? script.city.title : _t.nightFalls,
      lines: [if (round == 1) ...script.opening(), ...script.nightFalls(round)],
      nightfall: true,
      action: _t.startTheNight,
      onAction: _next,
    );
    _go(_Stage.page);
  }

  void _startDawn(DawnReport dawn) {
    final script = _script('dawn-${dawn.round}');
    _dawn = dawn;
    _stories = script.stage(dawn);
    final lines = script.dawn(dawn, discussion: _board.settings.discussion, stories: _stories);
    SoundStage.instance.prepare([
      for (final story in _stories) ...[filmFor(story).act, ?filmFor(story).save],
    ]);
    _page = ScriptPage(
      icon: Icons.wb_twilight,
      nightfall: false,
      title: dawn.victims.isEmpty ? _t.everyoneAlive : _t.crimePage,
      lines: lines,
      portraits: [for (final attack in dawn.attacks) if (attack.isFatal) attack.target.name],
      portraitsFallen: dawn.victims.isNotEmpty,
      action: dawn.winner != null ? _t.finale : _t.openTheFloor,
      onAction: () {
        _eventShown = dawn.round * 2;
        _next();
      },
    );
    if (_stories.isEmpty) {
      _go(_Stage.page);
    } else {
      _film = 0;
      _go(_Stage.film);
    }
  }

  void _afterFilm() => setState(() {
        if (_film + 1 < _stories.length) {
          _film++;
          _step++;
        } else {
          _go(_Stage.page);
        }
      });

  void _startVerdict(LynchReport report) {
    _verdict = report;
    _verdictTake = VerdictScene.variants[Random(_board.narrationSeed + report.round).nextInt(VerdictScene.variants.length)];
    SoundStage.instance.prepareVerdicts();
    _go(_Stage.verdictFilm);
  }

  void _afterVerdictFilm() => setState(() {
        final report = _verdict!;
        final condemned = report.condemned;
        if (report.role != null) SoundStage.instance.cue(Cue.drumroll);
        _page = ScriptPage(
          icon: Icons.gavel,
          title: condemned?.name ?? _t.noConviction,
          lines: _script('lynch-${report.round}').lynch(report),
          portraits: [if (condemned != null) condemned.name],
          revealed: report.role,
          action: report.winner != null ? _t.finale : _t.continueLabel,
          onAction: () {
            _eventShown = report.round * 2 + 1;
            _next();
          },
        );
        _go(_Stage.page);
      });

  // ---------------------------------------------------------------------
  // Le mosse.

  Future<void> _send(PlayerIntent intent) async {
    HapticFeedback.selectionClick();
    try {
      await _client.send(intent);
    } catch (error) {
      if (mounted) showFailure(context, error);
    }
  }

  Knowledge _knowledgeOf(Player player) {
    final view = _view;
    if (player == view.seat) return Knowledge(role: view.role, team: view.team);
    for (final known in view.known) {
      if (known.seat == player) return known.knowledge;
    }
    return const Knowledge();
  }

  bool _isAlive(Player player) => _public.alive.contains(player);

  /// Il tavolo segreto di questo turno: rimescolato a ogni notte, e diverso
  /// dal tavolo pubblico.
  List<Player> _secretTable() {
    final turn = '${_public.phase.name}-${_public.round}';
    if (_secretTurn != turn) {
      _secretTurn = turn;
      _secret = secretSeating(_public.seats, _shuffle, avoid: [_secret, publicSeating(_public.seats)]);
    }
    return _secret;
  }

  // ---------------------------------------------------------------------

  Future<void> _confirmExit() async {
    if (_stage == _Stage.end) {
      Navigator.of(context).pop();
      return;
    }
    final host = widget.authority != null;
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(_t.leaveQuestion),
        content: Text(host ? _t.online.hostLeaveWarning : _t.leaveWarning),
        actions: [
          TextButton(onPressed: pressed(() => Navigator.of(context).pop(false), Press.back), child: Text(_t.stay)),
          TextButton(onPressed: pressed(() => Navigator.of(context).pop(true), Press.tap), child: Text(_t.leave)),
        ],
      ),
    );
    if (leave == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final screen = _screen();
    if (identical(AppStrings.of(context), _t)) return screen;
    return Localizations.override(context: context, locale: _t.language.locale, child: screen);
  }

  Widget _screen() {
    if (_stage == _Stage.film) {
      final story = _stories[_film];
      final film = filmFor(story);
      final attack = _dawn!.attacks[_film];
      return PopScope(
        canPop: false,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: DeathScene(
            key: ValueKey('online-crime-$_step'),
            act: film.act,
            save: film.save,
            victimName: attack.isFatal ? attack.target.name : _t.someoneSaved,
            caption: story.scene.text,
            epilogue: story.epilogue?.id ?? '',
            style: _style,
            onFinished: _afterFilm,
          ),
        ),
      );
    }
    if (_stage == _Stage.verdictFilm) {
      final condemned = _verdict!.condemned;
      return PopScope(
        canPop: false,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: condemned == null
              ? VerdictScene.acquittal(key: ValueKey('online-verdict-$_step'), style: _style, onFinished: _afterVerdictFilm)
              : VerdictScene(
                  key: ValueKey('online-verdict-$_step'),
                  condemnedName: condemned.name,
                  variant: _verdictTake,
                  town: _city.name,
                  style: _style,
                  onFinished: _afterVerdictFilm,
                ),
        ),
      );
    }
    final ready = _client.ready;
    final mood = !ready
        ? SceneMood.night
        : switch (_public.phase) {
            GamePhase.night => _stage == _Stage.page && _page?.nightfall == false ? SceneMood.dawn : SceneMood.night,
            GamePhase.day => SceneMood.day,
            GamePhase.ended => _public.winner == Team.mafia ? SceneMood.night : SceneMood.dawn,
          };
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: SceneScaffold(
        mood: mood,
        style: ready ? _style : SkylineStyle.metropolis,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: _t.leaveTooltip,
            onPressed: pressed(_confirmExit, Press.back),
          ),
          title: Text(ready ? _title() : widget.room.code),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              children: [
                if (ready && _hostSilent) _banner(_t.online.hostSilent),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    child: KeyedSubtree(key: ValueKey(_step), child: _stageView()),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Il padrone di casa tace da ben oltre la scadenza: forse ha chiuso l'app.
  bool get _hostSilent {
    final deadline = _board.deadline;
    return deadline != null && DateTime.now().isAfter(deadline.add(const Duration(seconds: 45)));
  }

  Widget _banner(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, key: const Key('online.hostSilent'), textAlign: TextAlign.center, style: AppText.body),
      );

  String _title() => switch (_stage) {
        _Stage.card => _t.online.yourCard,
        _Stage.end => _t.endTitle,
        _Stage.vote => _t.dayTitle(_public.round),
        _ when _public.phase == GamePhase.night => _t.nightTitle(_public.round),
        _ => _t.dawnTitle,
      };

  Widget _stageView() => switch (_stage) {
        _Stage.connecting => _connectingView(),
        _Stage.card => _cardView(),
        _Stage.page => ScriptPageView(page: _page!, reader: null, strings: _t),
        _Stage.task => _taskView(),
        _Stage.waiting => _waitingView(),
        _Stage.vote => _voteView(),
        _Stage.end => _endView(),
        _Stage.film || _Stage.verdictFilm => const SizedBox.shrink(),
      };

  Widget _connectingView() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.gold),
            const SizedBox(height: 18),
            Text(_t.online.gameConnecting, style: AppText.body),
          ],
        ),
      );

  bool _cardTurned = false;

  Widget _cardView() {
    final view = _view;
    return Column(
      key: const Key('online.card'),
      children: [
        Text(widget.me.name.toUpperCase(), style: AppText.display(24, color: AppColors.textPrimary)),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
              child: FlipRoleCard(
                role: view.role,
                teammates: view.teammates,
                onRevealed: () => setState(() => _cardTurned = true),
              ),
            ),
          ),
        ),
        Text(_t.online.yourCardHint, textAlign: TextAlign.center, style: AppText.body),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            key: const Key('online.cardSeen'),
            onPressed: pressed(
              _cardTurned
                  ? () {
                      _cardSeen = true;
                      _next();
                    }
                  : null,
              Press.confirm,
            ),
            child: Text(_t.gotIt),
          ),
        ),
      ],
    );
  }

  Widget _taskView() {
    final option = _view.action!;
    final task = NightTask(option.kind!, option.targets);
    final script = _script('task');
    final selected = _selected;
    final busy = _client.busy;
    return Column(
      children: [
        Text(
          script.taskPrompt(task, _public.round),
          textAlign: TextAlign.center,
          style: AppText.display(23, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 6),
        Text(script.taskHint(task), textAlign: TextAlign.center, style: AppText.body.copyWith(fontSize: 14)),
        const SizedBox(height: 14),
        Expanded(
          child: PlayerGrid(
            players: _secretTable(),
            isAlive: _isAlive,
            knowledgeOf: _knowledgeOf,
            viewer: _view.seat,
            selectable: option.targets,
            selected: selected,
            onSelect: (player) => setState(() => _selected = player),
            shuffled: true,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                key: const Key('online.pass'),
                onPressed: pressed(busy ? null : () => _send(Pass(_view.seat.id)), Press.tap),
                child: Text(_t.pass),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                key: const Key('online.confirm'),
                onPressed: pressed(
                  selected == null || busy
                      ? null
                      : () => _send(option.type == ActionType.mafiaVote
                          ? MafiaVote(_view.seat.id, selected.id)
                          : NightAction(_view.seat.id, selected.id)),
                  Press.tap,
                ),
                child: Text(_t.confirm),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _waitingView() {
    final view = _view;
    final finding = view.nightChoice != null ? _finding : null;
    final found = finding?.role;
    final isMafia = finding?.team == Team.mafia;
    return Column(
      key: const Key('online.waiting'),
      children: [
        const Spacer(),
        if (!view.alive) ...[
          const Icon(Icons.visibility, color: AppColors.gold, size: 56),
          const SizedBox(height: 20),
          Text(_t.online.youAreOut, textAlign: TextAlign.center, style: AppText.body),
        ] else if (finding == null) ...[
          const Icon(Icons.check_circle_outline, color: AppColors.gold, size: 56),
          const SizedBox(height: 20),
          Text(_t.doneTitle, style: AppText.display(36)),
          const SizedBox(height: 12),
          Text(_t.nobodyWillKnow, style: AppText.body),
        ] else ...[
          AvatarSpotlight(seed: finding.subject.name, size: 130, fallen: found != null),
          const SizedBox(height: 18),
          Text(found == null ? _t.yourInvestigation : _t.inTheGrave, style: AppText.overline),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(finding.subject.name.toUpperCase(), style: AppText.display(32, color: AppColors.textPrimary)),
          ),
          const SizedBox(height: 10),
          Text(
            found != null
                ? _t.wasRole(_t.role(found).label)
                : isMafia
                    ? _t.isFamily
                    : _t.isInnocent,
            style: AppText.display(20, color: isMafia ? _mafiaRed : _cleanGreen),
          ),
        ],
        const SizedBox(height: 24),
        if (_public.phase == GamePhase.night && _public.nightPending > 0)
          Text(_t.online.waitingForOthers(_public.nightPending), textAlign: TextAlign.center, style: AppText.body),
        const Spacer(),
      ],
    );
  }

  String _clock(Duration left) {
    final seconds = max(0, left.inSeconds);
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  Widget _voteView() {
    final view = _view;
    final option = view.action;
    final table = publicSeating(_public.seats);
    final votes = _public.dayVotes;
    final mine = [for (final vote in votes) if (vote.voter == view.seat) vote].firstOrNull;
    final deadline = _board.deadline;
    final selected = option?.current;
    return Column(
      key: const Key('online.vote'),
      children: [
        Text(_t.online.voteTitle, style: AppText.display(26)),
        const SizedBox(height: 6),
        Text(
          view.alive ? _t.online.voteHint : _t.online.youAreOut,
          textAlign: TextAlign.center,
          style: AppText.body.copyWith(fontSize: 14),
        ),
        const SizedBox(height: 6),
        Text(
          [
            _t.online.votesCast(votes.length, _public.alive.length),
            if (deadline != null) _t.online.closesIn(_clock(deadline.difference(DateTime.now()))),
          ].join(' · '),
          style: AppText.overline,
        ),
        const SizedBox(height: 10),
        Expanded(
          child: PlayerGrid(
            players: table,
            isAlive: _isAlive,
            knowledgeOf: (player) {
              for (final known in _public.revealed) {
                if (known.seat == player) return known.knowledge;
              }
              return const Knowledge();
            },
            selectable: option == null ? const [] : option.targets,
            selected: selected,
            silenced: _public.lastDawn?.silenced,
            stamp: _t.accusedStamp,
            onSelect: (player) {
              if (option == null || _client.busy || player == selected) return;
              _send(DayVote(view.seat.id, player.id));
            },
          ),
        ),
        const SizedBox(height: 8),
        if (mine != null)
          Text(
            mine.target == null ? _t.online.abstained : _t.online.votedFor(mine.target!.name),
            style: AppText.body.copyWith(color: AppColors.textPrimary),
          ),
        const SizedBox(height: 8),
        if (option != null)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              key: const Key('online.abstain'),
              onPressed: pressed(_client.busy ? null : () => _send(Pass(view.seat.id)), Press.tap),
              child: Text(_t.online.abstain),
            ),
          ),
      ],
    );
  }

  String _fateOf(Player player) {
    for (final record in _public.history) {
      if (record.nightVictims.contains(player)) return _t.fateNight(record.round);
      if (record.lynched == player) return _t.fateGallows(record.round);
    }
    return _t.stillStanding;
  }

  Widget _endView() {
    final winner = _public.winner;
    final mafiaWon = winner == Team.mafia;
    final roles = _public.finalRoles;
    return ListView(
      key: const Key('online.end'),
      children: [
        Icon(mafiaWon ? Icons.theater_comedy : Icons.balance, color: mafiaWon ? _mafiaRed : AppColors.gold, size: 48),
        const SizedBox(height: 12),
        Text(
          mafiaWon ? _t.familyWins : _t.townWins,
          textAlign: TextAlign.center,
          style: AppText.display(36, color: mafiaWon ? _mafiaRed : AppColors.gold),
        ),
        const SizedBox(height: 20),
        Text(_t.whoWasWho, style: AppText.overline),
        const SizedBox(height: 10),
        for (final player in publicSeating(_public.seats))
          if (roles[player] case final role?)
            RevealRow(
              name: player.name,
              role: role,
              roleLabel: _t.role(role).label,
              fate: _fateOf(player),
              alive: _isAlive(player),
              winner: role.team == winner,
            ),
        const SizedBox(height: 28),
        Row(
          children: [
            PlayerAvatar(seed: widget.me.name, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _t.role(_view.role).label,
                style: AppText.body.copyWith(color: _view.role.color),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          key: const Key('online.backToRoom'),
          onPressed: pressed(() => Navigator.of(context).pop(), Press.confirm),
          child: Text(_t.online.backToRoom),
        ),
      ],
    );
  }
}
