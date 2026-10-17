import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_strings.dart';
import '../../../narration/death_story.dart';
import '../../../narration/narrator_script.dart';
import '../../../online/game/game_client.dart';
import '../../../online/game/game_clock.dart';
import '../../../online/game/game_feed.dart';
import '../../../online/game/game_schedule.dart';
import '../../../online/online_services.dart';
import '../../../rules/game_engine.dart';
import '../../../rules/intent.dart';
import '../../../rules/knowledge.dart';
import '../../../rules/player.dart';
import '../../../rules/player_view.dart';
import '../../../rules/role.dart';
import '../../../sound/cue_sounds.dart';
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
import '../../widgets/role_reveal_card.dart';
import '../../widgets/scene_scaffold.dart';
import '../../widgets/verdict_scene.dart';
import 'chat_panel.dart';
import 'online_widgets.dart';

/// La partita online, vista dal proprio telefono. Tutto segue l'orologio del
/// server: ogni fase ([Stage]) ha un inizio e una fine pubblicati sul tavolo,
/// e lo schermo cambia da solo a quelle ore, per tutti insieme. Niente
/// pulsanti per andare avanti: si conferma (carta vista, letto, pronto) e,
/// se hanno confermato tutti, il server passa prima alla fase dopo.
///
/// Online non c'è il narratore: niente voce e niente istruzioni da leggere
/// al tavolo. Del copione resta solo il racconto (la scena, cosa è successo,
/// il verdetto), come cronaca della fase.
///
/// Lo schermo conosce solo il [GameClient]: il tavolo di tutti, la vista del
/// proprio posto e la chat. Nessun telefono sa i ruoli degli altri.
class OnlineGameScreen extends StatefulWidget {
  final OnlineServices services;
  final Room room;
  final Profile me;

  /// Il dado dei tavoli segreti (per i test).
  final Random? seating;

  /// L'orologio di questo telefono (per i test).
  final GameClock clock;

  const OnlineGameScreen({
    super.key,
    required this.services,
    required this.room,
    required this.me,
    this.seating,
    this.clock = const SystemGameClock(),
  });

  @override
  State<OnlineGameScreen> createState() => _OnlineGameScreenState();
}

class _OnlineGameScreenState extends State<OnlineGameScreen> with WidgetsBindingObserver {
  static const _mafiaRed = Color(0xFFE5606A);
  static const _cleanGreen = Color(0xFF6FBF9A);

  late GameClient _client = _connect();

  GameClient _connect() =>
      GameClient(backend: widget.services.game, roomId: widget.room.id, clock: widget.clock)..addListener(_changed);
  late final AppStrings _t = widget.room.language.strings;
  late final Random _shuffle = widget.seating ?? Random();
  Timer? _ticker;

  Player? _selected;
  List<Player> _secret = const [];
  String? _secretTurn;
  bool _cardTurned = false;

  /// Quello che l'ultima mossa ha scoperto (un'indagine, una fossa).
  Exposure? _finding;
  int? _findingFor;

  /// La fase già vista da qui: al cambio, musica e suoni.
  String? _stageShown;

  /// Quanti addii sono già stati annunciati (null: non si è ancora visto il
  /// tavolo; chi rientra non si sente ripetere quelli vecchi).
  int? _departedShown;

  /// Le scene degli agguati di ogni alba: le stesse per il film e per la
  /// cronaca, e su ogni telefono (stesso seme).
  final Map<int, List<DeathStory>> _stories = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _client;
    // Il cronometro, l'inizio dei film e la fine delle fasi.
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _client.removeListener(_changed);
    _client.dispose();
    SoundStage.instance.ambience(null);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Di ritorno dallo sfondo il collegamento può essersi perso: ci si
    // risiede, e il server ridà subito il tavolo com'è adesso.
    if (state == AppLifecycleState.resumed && (_client.error != null || !_client.ready || _serverSilent)) _rejoin();
  }

  /// Rientra al tavolo: un collegamento nuovo, che riparte dalla versione
  /// attuale della partita. La fase già vista resta vista.
  void _rejoin() {
    final old = _client;
    old.removeListener(_changed);
    _client = _connect();
    old.dispose();
    if (mounted) setState(() {});
  }

  OnlineBoard get _board => _client.board!;
  PlayerView get _view => _client.seat!.view;
  PublicView get _public => _board.view;
  StageWindow? get _window => _board.schedule;
  Stage get _stage => _window?.stage ?? Stage.ended;

  void _changed() {
    if (!mounted) return;
    if (_client.takeRejection() != null) showNote(context, _t.online.rejected);
    final seat = _client.seat;
    if (seat?.receipt case (:final id, result: IntentAccepted(:final finding?)) when id != _findingFor) {
      _findingFor = id;
      _finding = finding;
    }
    if (_client.ready) {
      _enterStage();
      _announceDepartures();
    }
    setState(() {});
  }

  void _enterStage() {
    final window = _window;
    if (window == null || window.key == _stageShown) return;
    _stageShown = window.key;
    _selected = null;
    final stage = SoundStage.instance;
    switch (window.stage) {
      case Stage.reveal || Stage.night:
        stage.music(MusicMood.night);
        if (window.stage == Stage.night) stage.cue(Cue.nightfall);
      case Stage.dawnFilms:
        final dawn = _public.lastDawn;
        if (dawn != null) {
          stage.prepare([
            for (final story in _storiesOf(dawn)) ...[filmFor(story).act, ?filmFor(story).save],
          ]);
        }
      case Stage.verdictFilm:
        stage.prepareVerdicts();
      case Stage.discussion || Stage.vote:
        stage.music(MusicMood.day);
        stage.ambience(null);
      case Stage.ended:
        final winner = _public.winner;
        if (winner != null) {
          stage.music(winner == Team.mafia ? MusicMood.winFamily : MusicMood.winTown);
          stage.cue(winner == Team.mafia ? Cue.familyWins : Cue.townWins);
        }
      case Stage.dawn || Stage.verdict:
        break;
    }
  }

  /// Chi ha lasciato la città (telefono spento oltre la tolleranza): lo si
  /// dice a tutti, con la sua carta.
  void _announceDepartures() {
    final departed = _board.departed;
    final shown = _departedShown;
    _departedShown = departed.length;
    if (shown == null || departed.length <= shown) return;
    for (final seat in departed.skip(shown)) {
      final player = _board.seating.occupantOf(seat);
      final role = _public.revealed.where((k) => k.seat.id == seat).firstOrNull?.knowledge.role;
      if (player != null) showNote(context, _t.online.leftTown(player.name, role == null ? '?' : _t.role(role).label));
    }
  }

  // ---------------------------------------------------------------------
  // Il racconto: lo stesso su ogni telefono, dallo stesso seme.

  late final _city = _t.pack.cities[(_board.narrationSeed) % _t.pack.cities.length];

  NarratorScript _script(String event) {
    var hash = 0x811c9dc5;
    for (final unit in event.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0x7fffffff;
    }
    return NarratorScript(pack: _t.pack, city: _city, random: Random(_board.narrationSeed ^ hash));
  }

  SkylineStyle get _style => skylineFor(_city.id);

  List<DeathStory> _storiesOf(DawnReport dawn) =>
      _stories.putIfAbsent(dawn.round, () => _script('dawn-${dawn.round}').stage(dawn));

  // ---------------------------------------------------------------------
  // Il tempo.

  /// La fase è aperta adesso (dopo il suo inizio, prima della sua fine).
  bool get _open => _client.elapsed >= Duration.zero && _client.timeLeft > Duration.zero;

  String _clock(Duration left) {
    final seconds = (left.inMilliseconds / 1000).ceil();
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  /// Il server tace da ben oltre la fine della fase: forse manca la rete.
  bool get _serverSilent {
    final window = _window;
    return window != null &&
        _stage != Stage.ended &&
        _client.serverNow.isAfter(window.endsAt.add(const Duration(seconds: 12)));
  }

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

  void _ack() {
    HapticFeedback.selectionClick();
    _client.ack();
    setState(() {});
  }

  /// La conferma è partita da qui (il pulsante si spegne)…
  bool get _acked => _client.ackedHere || _ackReceived;

  /// …ed è arrivata al server (solo allora «registrato»).
  bool get _ackReceived => _client.seat?.acked ?? false;

  Knowledge _knowledgeOf(Player player) {
    final view = _view;
    if (player == view.seat) return Knowledge(role: view.role, team: view.team);
    for (final known in view.known) {
      if (known.seat == player) return known.knowledge;
    }
    return const Knowledge();
  }

  Knowledge _publicKnowledge(Player player) {
    for (final known in _public.revealed) {
      if (known.seat == player) return known.knowledge;
    }
    return const Knowledge();
  }

  bool _isAlive(Player player) => _public.alive.contains(player);

  bool _offline(Player player) => _board.offline.contains(player.id);

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
    if (_stage == Stage.ended || (_client.ready && _board.abandoned)) {
      Navigator.of(context).pop();
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
    if (leave == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final screen = _screen();
    if (identical(AppStrings.of(context), _t)) return screen;
    return Localizations.override(context: context, locale: _t.language.locale, child: screen);
  }

  Widget _screen() {
    final ready = _client.ready;
    if (ready && !_board.abandoned && (_stage == Stage.dawnFilms || _stage == Stage.verdictFilm)) {
      return PopScope(
        canPop: false,
        child: Scaffold(backgroundColor: Colors.black, body: _stage == Stage.dawnFilms ? _dawnFilm() : _verdictFilm()),
      );
    }
    final mood = !ready
        ? SceneMood.night
        : switch (_stage) {
            Stage.reveal || Stage.night => SceneMood.night,
            Stage.dawn => SceneMood.dawn,
            Stage.ended => _public.winner == Team.mafia ? SceneMood.night : SceneMood.dawn,
            _ => SceneMood.day,
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
          actions: [
            if (ready && _stage != Stage.ended && !_board.abandoned)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Text(
                    _client.elapsed < Duration.zero ? '…' : _clock(_client.timeLeft),
                    key: const Key('online.countdown'),
                    style: AppText.display(20, color: AppColors.textPrimary),
                  ),
                ),
              ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Column(
              children: [
                ?_connectionBanner(),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    child: KeyedSubtree(
                      key: ValueKey(ready ? '${_window?.key}-${_board.abandoned}' : 'connecting'),
                      child: _stageView(),
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

  /// Il collegamento che non va: il server tace, la rete ha dato errore, o
  /// il server non sente più questo telefono. Si rientra al tavolo con un
  /// tocco. Chi ha lasciato la città lo sa, e guarda soltanto.
  Widget? _connectionBanner() {
    if (!_client.ready) return null;
    final String text;
    final Key key;
    var rejoin = true;
    if (_board.departed.contains(_view.seat.id)) {
      text = _t.online.youLeftTown;
      key = const Key('online.youLeftTown');
      rejoin = false;
    } else if (_client.error != null) {
      text = _t.online.connectionLost;
      key = const Key('online.connectionLost');
    } else if (_serverSilent) {
      text = _t.online.serverSilent;
      key = const Key('online.serverSilent');
    } else if (_board.offline.contains(_view.seat.id)) {
      text = _t.online.youLookOffline;
      key = const Key('online.youLookOffline');
    } else {
      return null;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(text, key: key, style: AppText.body.copyWith(fontSize: 13))),
          if (rejoin) ...[
            const SizedBox(width: 8),
            TextButton(
              key: const Key('online.reconnect'),
              onPressed: pressed(_rejoin, Press.tap),
              child: Text(_t.online.rejoin),
            ),
          ],
        ],
      ),
    );
  }

  String _title() => switch (_stage) {
        Stage.reveal => _t.online.yourCard,
        Stage.night => _t.nightTitle(_public.round),
        Stage.dawn || Stage.dawnFilms => _t.dawnTitle,
        Stage.discussion || Stage.vote || Stage.verdict || Stage.verdictFilm => _t.dayTitle(_public.round),
        Stage.ended => _t.endTitle,
      };

  Widget _stageView() {
    if (!_client.ready) return _connectingView();
    if (_board.abandoned) return _closedView();
    return switch (_stage) {
      Stage.reveal => _cardView(),
      Stage.night => _nightView(),
      Stage.dawn => _dawnView(),
      Stage.discussion => _discussionView(),
      Stage.vote => _voteView(),
      Stage.verdict => _verdictView(),
      Stage.ended => _endView(),
      Stage.dawnFilms || Stage.verdictFilm => const SizedBox.shrink(),
    };
  }

  Widget _connectingView() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_client.error == null) ...[
              const CircularProgressIndicator(color: AppColors.gold),
              const SizedBox(height: 18),
              Text(_t.online.gameConnecting, style: AppText.body),
            ] else ...[
              const Icon(Icons.wifi_off, color: AppColors.gold, size: 48),
              const SizedBox(height: 18),
              Text(_t.online.connectionLost, key: const Key('online.connectionLost'), style: AppText.body),
              const SizedBox(height: 12),
              ElevatedButton(
                key: const Key('online.reconnect'),
                onPressed: pressed(_rejoin, Press.confirm),
                child: Text(_t.online.rejoin),
              ),
            ],
          ],
        ),
      );

  Widget _closedView() => Column(
        key: const Key('online.closed'),
        children: [
          const Spacer(),
          const Icon(Icons.door_back_door_outlined, color: AppColors.gold, size: 56),
          const SizedBox(height: 16),
          Text(_t.online.gameClosed, textAlign: TextAlign.center, style: AppText.body),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: pressed(() => Navigator.of(context).pop(), Press.confirm),
              child: Text(_t.online.backToRoom),
            ),
          ),
        ],
      );

  /// Il pulsante della conferma: «pronto», poi l'attesa degli altri.
  /// Chi è fuori dal gioco non conferma niente: il server non lo aspetta.
  Widget _readyButton({bool enabled = true}) => !_view.alive
      ? const SizedBox.shrink()
      : SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            key: const Key('online.ready'),
            onPressed: pressed(_acked || !enabled || !_open ? null : _ack, Press.confirm),
            child: Text(_ackReceived ? _t.online.readyWaiting : _acked ? _t.online.sending : _t.online.ready),
          ),
        );

  // ---------------------------------------------------------------------
  // La carta.

  Widget _cardView() {
    final view = _view;
    final opening = _script('night-1').opening(online: true);
    return Column(
      key: const Key('online.card'),
      children: [
        Text(_city.title, textAlign: TextAlign.center, style: AppText.display(22, color: AppColors.textPrimary)),
        const SizedBox(height: 6),
        for (final line in opening)
          Text(line.text, textAlign: TextAlign.center, style: AppText.body.copyWith(fontSize: 14)),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              child: FlipRoleCard(
                role: view.role,
                teammates: view.teammates,
                onRevealed: () => setState(() => _cardTurned = true),
              ),
            ),
          ),
        ),
        Text(_t.online.yourCardHint, textAlign: TextAlign.center, style: AppText.body),
        const SizedBox(height: 16),
        _readyButton(enabled: _cardTurned),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // La notte.

  bool get _inFamilyChat => _view.alive && _view.team == Team.mafia;

  Widget _nightView() {
    final story = _script('night-${_public.round}').nightFalls(_public.round, online: true);
    final acting = _view.action != null;
    return Column(
      key: const Key('online.night'),
      children: [
        for (final line in story)
          Text(line.text, textAlign: TextAlign.center, style: AppText.body.copyWith(fontSize: 14)),
        const SizedBox(height: 8),
        Expanded(flex: 3, child: acting ? _taskView() : _waitingView()),
        if (_inFamilyChat) ...[
          const SizedBox(height: 10),
          Expanded(flex: 2, child: _familyPanel()),
        ],
      ],
    );
  }

  Widget _familyPanel() {
    final votes = _view.familyVotes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (votes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final vote in votes)
                  _Pizzino(text: '${vote.voter.name} → ${vote.target?.name ?? _t.online.abstainTag}', color: _mafiaRed),
              ],
            ),
          ),
        Expanded(
          child: ChatPanel(
            key: const Key('online.familyChat'),
            title: _t.online.chatFamily,
            accent: _mafiaRed,
            messages: [for (final m in _client.chat) if (m.channel == ChatChannel.family) m],
            myId: widget.me.id,
            note: null,
            hint: _t.online.chatHint,
            empty: _t.online.chatEmpty,
            sendLabel: _t.online.chatSend,
            onSend: (body) => _client.sendChat(ChatChannel.family, body),
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
    final busy = _client.busy || !_open;
    return Column(
      children: [
        Text(
          script.taskPrompt(task, _public.round),
          textAlign: TextAlign.center,
          style: AppText.display(21, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 4),
        Text(script.taskHint(task), textAlign: TextAlign.center, style: AppText.body.copyWith(fontSize: 13)),
        const SizedBox(height: 8),
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
        const SizedBox(height: 8),
        if (_client.busy) Text(_t.online.sending, style: AppText.body.copyWith(fontSize: 13)),
        if (_client.elapsed < Duration.zero) Text(_t.online.startingSoon, style: AppText.body.copyWith(fontSize: 13)),
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
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (!view.alive) ...[
          const Icon(Icons.visibility, color: AppColors.gold, size: 48),
          const SizedBox(height: 16),
          Text(_t.online.youAreOut, textAlign: TextAlign.center, style: AppText.body),
        ] else if (finding == null && view.nightChoice == null) ...[
          const Icon(Icons.hourglass_empty, color: AppColors.gold, size: 48),
        ] else if (finding == null) ...[
          const Icon(Icons.check_circle_outline, color: AppColors.gold, size: 48),
          const SizedBox(height: 12),
          Text(_t.online.moveRegistered, key: const Key('online.moveRegistered'), style: AppText.display(26)),
          const SizedBox(height: 8),
          Text(_t.nobodyWillKnow, style: AppText.body),
        ] else ...[
          AvatarSpotlight(seed: finding.subject.name, size: 110, fallen: found != null),
          const SizedBox(height: 12),
          Text(found == null ? _t.yourInvestigation : _t.inTheGrave, style: AppText.overline),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(finding.subject.name.toUpperCase(), style: AppText.display(30, color: AppColors.textPrimary)),
          ),
          const SizedBox(height: 8),
          Text(
            found != null
                ? _t.wasRole(_t.role(found).label)
                : isMafia
                    ? _t.isFamily
                    : _t.isInnocent,
            style: AppText.display(20, color: isMafia ? _mafiaRed : _cleanGreen),
          ),
        ],
        const SizedBox(height: 16),
        if (_public.phase == GamePhase.night && _public.nightPending > 0)
          Text(_t.online.waitingForOthers(_public.nightPending), textAlign: TextAlign.center, style: AppText.body),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // I film, per tutti nello stesso momento.

  Widget _waitingFilm() => Center(
        child: Text(_t.online.startingSoon, key: const Key('online.filmSoon'), style: AppText.body),
      );

  Widget _dawnFilm() {
    final dawn = _public.lastDawn;
    if (dawn == null || dawn.attacks.isEmpty) return _waitingFilm();
    final elapsed = _client.elapsed;
    if (elapsed < Duration.zero) return _waitingFilm();
    final index = elapsed.inMilliseconds ~/ DeathScene.length.inMilliseconds;
    if (index >= dawn.attacks.length) {
      // Visti tutti: lo si dice al server, e si aspetta l'alba.
      if (!_client.ackedHere) scheduleMicrotask(_client.ack);
      return _waitingFilm();
    }
    final story = _storiesOf(dawn)[index];
    final film = filmFor(story);
    final attack = dawn.attacks[index];
    return DeathScene(
      key: ValueKey('online-crime-${dawn.round}-$index'),
      act: film.act,
      save: film.save,
      victimName: attack.isFatal ? attack.target.name : _t.someoneSaved,
      caption: story.scene.text,
      epilogue: story.epilogue?.id ?? '',
      style: _style,
      startAt: elapsed - DeathScene.length * index,
      onFinished: () {
        if (index == dawn.attacks.length - 1) _client.ack();
        if (mounted) setState(() {});
      },
    );
  }

  Widget _verdictFilm() {
    final report = _public.lastLynch;
    final elapsed = _client.elapsed;
    if (report == null || elapsed < Duration.zero) return _waitingFilm();
    final length = OnlinePacing.verdictFilm(condemns: report.condemned != null);
    if (elapsed >= length) {
      if (!_client.ackedHere) scheduleMicrotask(_client.ack);
      return _waitingFilm();
    }
    final condemned = report.condemned;
    void done() {
      _client.ack();
      if (mounted) setState(() {});
    }

    final key = ValueKey('online-verdict-${report.round}');
    return condemned == null
        ? VerdictScene.acquittal(key: key, style: _style, startAt: elapsed, onFinished: done)
        : VerdictScene(
            key: key,
            condemnedName: condemned.name,
            variant: VerdictScene.variants[Random(_board.narrationSeed + report.round).nextInt(VerdictScene.variants.length)],
            town: _city.name,
            style: _style,
            startAt: elapsed,
            onFinished: done,
          );
  }

  // ---------------------------------------------------------------------
  // La cronaca: l'alba e il verdetto, solo il racconto.

  Widget _chronicle({
    required Key key,
    required String title,
    required List<ScriptLine> lines,
    List<String> portraits = const [],
    bool fallen = false,
    Role? revealed,
  }) =>
      Column(
        key: key,
        children: [
          if (portraits.isNotEmpty || revealed != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final name in portraits)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: AvatarSpotlight(seed: name, size: portraits.length > 1 ? 80 : 110, fallen: fallen),
                  ),
                if (revealed != null) ...[
                  const SizedBox(width: 14),
                  RoleRevealCard(role: revealed, faceUp: true, height: 140),
                ],
              ],
            ),
          const SizedBox(height: 10),
          FittedBox(fit: BoxFit.scaleDown, child: Text(title, style: AppText.display(26))),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final line in lines)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        line.text,
                        textAlign: TextAlign.center,
                        style: line.isFact
                            ? AppText.body.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700)
                            : AppText.body.copyWith(fontStyle: FontStyle.italic),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _readyButton(),
        ],
      );

  Widget _dawnView() {
    final dawn = _public.lastDawn;
    if (dawn == null) return _connectingView();
    final lines = _script('dawn-${dawn.round}')
        .dawn(dawn, discussion: _board.settings.discussion, stories: _storiesOf(dawn), online: true);
    return _chronicle(
      key: const Key('online.dawn'),
      title: dawn.victims.isEmpty ? _t.everyoneAlive : _t.crimePage,
      lines: lines,
      portraits: [for (final attack in dawn.attacks) if (attack.isFatal) attack.target.name],
      fallen: dawn.victims.isNotEmpty,
    );
  }

  Widget _verdictView() {
    final report = _public.lastLynch;
    if (report == null) return _connectingView();
    final condemned = report.condemned;
    return _chronicle(
      key: const Key('online.verdict'),
      title: condemned?.name ?? _t.noConviction,
      lines: _script('lynch-${report.round}').lynch(report),
      portraits: [if (condemned != null) condemned.name],
      revealed: report.role,
    );
  }

  // ---------------------------------------------------------------------
  // Il giorno: si discute in chat, poi si vota a viso aperto.

  String? get _townChatNote {
    if (!_view.alive) return _t.online.chatDead;
    if (_public.lastDawn?.silenced == _view.seat && _public.lastDawn?.round == _public.round) {
      return _t.online.chatSilenced;
    }
    return null;
  }

  Widget _townChat() => ChatPanel(
        key: const Key('online.townChat'),
        title: _t.online.chatTown,
        messages: [for (final m in _client.chat) if (m.channel == ChatChannel.day) m],
        myId: widget.me.id,
        note: _townChatNote,
        hint: _t.online.chatHint,
        empty: _t.online.chatEmpty,
        sendLabel: _t.online.chatSend,
        onSend: (body) => _client.sendChat(ChatChannel.day, body),
      );

  Widget _discussionView() => Column(
        key: const Key('online.discussion'),
        children: [
          Text(_t.online.discussionTitle, style: AppText.display(24)),
          const SizedBox(height: 4),
          Text(_t.online.discussionHint, textAlign: TextAlign.center, style: AppText.body.copyWith(fontSize: 14)),
          const SizedBox(height: 8),
          SizedBox(height: 64, child: _seatStrip()),
          const SizedBox(height: 8),
          Expanded(child: _townChat()),
          const SizedBox(height: 10),
          _readyButton(),
        ],
      );

  /// I vivi in fila, con chi è offline.
  Widget _seatStrip() => ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final player in publicSeating(_public.seats))
            if (_isAlive(player))
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Column(
                  children: [
                    Opacity(opacity: _offline(player) ? 0.4 : 1, child: PlayerAvatar(seed: player.name, size: 36)),
                    const SizedBox(height: 2),
                    Text(
                      _offline(player) ? _t.online.offlineBadge : player.name,
                      style: AppText.body.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
        ],
      );

  Widget _voteView() {
    final view = _view;
    final option = view.action;
    final votes = _public.dayVotes;
    final mine = [for (final vote in votes) if (vote.voter == view.seat) vote].firstOrNull;
    // Il pizzino di ogni votante (chi accusa, o che si astiene) e i voti di
    // ogni accusato, dal vivo. Le righe restano al loro posto: niente
    // salti sotto il dito mentre si sceglie.
    final tally = <Player, int>{};
    final pizzini = <Player, String>{};
    for (final vote in votes) {
      final target = vote.target;
      pizzini[vote.voter] = '${vote.voter.name} → ${target?.name ?? _t.online.abstainTag}';
      if (target != null) tally[target] = (tally[target] ?? 0) + 1;
    }
    final table = [for (final p in publicSeating(_public.seats)) if (_isAlive(p)) p];
    final canVote = option != null && _open && !_client.busy;
    final selected = mine?.target;
    return Column(
      key: const Key('online.vote'),
      children: [
        Text(_t.online.voteTitle, style: AppText.display(24)),
        const SizedBox(height: 4),
        Text(
          view.alive ? _t.online.voteHint : _t.online.youAreOut,
          textAlign: TextAlign.center,
          style: AppText.body.copyWith(fontSize: 13),
        ),
        const SizedBox(height: 4),
        Text(_t.online.votesCast(votes.length, _public.alive.length), style: AppText.overline),
        const SizedBox(height: 6),
        Expanded(
          flex: 3,
          child: ListView(
            children: [
              for (final player in table)
                _VoteRow(
                  key: ValueKey('vote-${player.id}'),
                  player: player,
                  votes: tally[player] ?? 0,
                  votesLabel: _t.online.votesFor(tally[player] ?? 0),
                  pizzino: pizzini[player],
                  offline: _offline(player) ? _t.online.offlineBadge : null,
                  silenced: _public.lastDawn?.silenced == player && _public.lastDawn?.round == _public.round,
                  revealed: switch (_publicKnowledge(player).role) {
                    final role? => _t.role(role).label,
                    null => null,
                  },
                  selected: player == selected,
                  onTap: canVote && option.targets.contains(player) && player != selected
                      ? () => _send(DayVote(view.seat.id, player.id))
                      : null,
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        if (_client.busy)
          Text(_t.online.sending, style: AppText.body.copyWith(fontSize: 13))
        else if (mine != null)
          Text(
            mine.target == null
                ? '${_t.online.abstained} · ${_t.online.voteRegistered}'
                : '${_t.online.votedFor(mine.target!.name)} · ${_t.online.voteRegistered}',
            key: const Key('online.voteRegistered'),
            style: AppText.body.copyWith(color: AppColors.textPrimary, fontSize: 14),
          ),
        if (option != null)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              key: const Key('online.abstain'),
              onPressed: pressed(canVote && mine?.target != null || canVote && mine == null
                  ? () => _send(Pass(view.seat.id))
                  : null, Press.tap),
              child: Text(_t.online.abstain),
            ),
          ),
        const SizedBox(height: 8),
        Expanded(flex: 2, child: _townChat()),
      ],
    );
  }

  // ---------------------------------------------------------------------

  String _fateOf(Player player) {
    if (_board.departed.contains(player.id)) return _t.online.fateLeft;
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

/// Il bigliettino di chi ha votato: «→ marco».
class _Pizzino extends StatelessWidget {
  final String text;
  final Color color;

  const _Pizzino({super.key, required this.text, this.color = AppColors.gold});

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFEDE2C8),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.6)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Text(
            text,
            style: const TextStyle(fontFamily: 'Courier', color: Color(0xFF14110F), fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
      );
}

/// Una riga del voto della piazza: chi è, quanti voti ha, chi accusa lui.
class _VoteRow extends StatelessWidget {
  final Player player;
  final int votes;
  final String votesLabel;
  final String? pizzino;
  final String? offline;
  final bool silenced;
  final String? revealed;
  final bool selected;
  final VoidCallback? onTap;

  const _VoteRow({
    super.key,
    required this.player,
    required this.votes,
    required this.votesLabel,
    required this.pizzino,
    required this.offline,
    required this.silenced,
    required this.revealed,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Material(
          color: selected ? AppColors.accent.withValues(alpha: 0.25) : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                children: [
                  Opacity(opacity: offline != null ? 0.4 : 1, child: PlayerAvatar(seed: player.name, size: 34)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          [player.name, ?offline, if (silenced) '🤐'].join(' · '),
                          style: AppText.body.copyWith(color: AppColors.textPrimary, fontSize: 15),
                        ),
                        if (pizzino != null) ...[
                          const SizedBox(height: 2),
                          _Pizzino(key: ValueKey('pizzino-${player.id}'), text: pizzino!),
                        ],
                      ],
                    ),
                  ),
                  if (votes > 0)
                    Text(votesLabel, key: ValueKey('votes-${player.id}'), style: AppText.display(16, color: AppColors.accent))
                  else if (revealed != null)
                    Text(revealed!, style: AppText.body.copyWith(fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
      );
}
