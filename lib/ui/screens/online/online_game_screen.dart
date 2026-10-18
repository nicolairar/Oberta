import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_strings.dart';
import '../../../narration/death_story.dart';
import '../../../narration/narrator_script.dart';
import '../../../online/game/game_client.dart';
import 'game/meme_director.dart';
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
import '../../avatar/avatar_look.dart';
import '../../seating.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar_spotlight.dart';
import '../../widgets/death_scene.dart';
import '../../widgets/scene_scaffold.dart';
import '../../widgets/verdict_scene.dart';
import 'game/chat_dock.dart';
import 'game/front_page.dart';
import 'game/noir_role_card.dart';
import 'game/noir_ui.dart';
import 'game/saloon_table.dart';
import 'game/saloon_transitions.dart';
import 'game/seat_card.dart';
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
  late final GameClient _client = _connect();

  GameClient _connect() =>
      GameClient(backend: widget.services.game, roomId: widget.room.id, clock: widget.clock, me: widget.me.id)..addListener(_changed);
  late final AppStrings _t = widget.room.language.strings;
  late final Random _shuffle = widget.seating ?? Random();
  Timer? _ticker;

  Player? _selected;

  /// Il Sarto ha scelto di cucire invece di votare l'agguato.
  bool _alternative = false;

  /// Di giorno, con un Compare vivo, la famiglia guarda la sua chat.
  bool _familyTab = false;
  List<Player> _secret = const [];
  String? _secretTurn;
  bool _cardTurned = false;

  /// Quello che l'ultima mossa ha scoperto (un'indagine, una fossa).
  Exposure? _finding;
  int? _findingFor;

  /// Gli ultimi voti della piazza visti al voto: il verdetto li ricorda
  /// (il tavolo pubblico li cancella appena il voto si chiude).
  List<SeatVote> _lastVotes = const [];

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
    MemeDirector.attach(_client, alive: () => mounted);
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
    // Sempre: lo sfondo può aver lasciato il server senza notizie (e gli
    // altri ci vedono assenti) anche se qui sembra tutto a posto.
    if (state == AppLifecycleState.resumed) _rejoin();
  }

  /// Rientra al tavolo: accesso rinnovato, tempo reale riaperto, un «ci
  /// sono» subito e la partita riletta com'è adesso (vedi [GameClient.rejoin]).
  void _rejoin() => _client.rejoin();

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
      if (_stage == Stage.vote) _lastVotes = _public.dayVotes;
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
    _alternative = false;
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

  /// Prima dell'inizio comune della fase (l'orologio non corre ancora).
  bool get _beforeStart => _client.ready && _client.elapsed < Duration.zero;

  Widget _screen() {
    final ready = _client.ready;
    if (ready && !_board.abandoned && (_stage == Stage.dawnFilms || _stage == Stage.verdictFilm)) {
      return PopScope(
        canPop: false,
        child: Scaffold(backgroundColor: Colors.black, body: _stage == Stage.dawnFilms ? _dawnFilm() : _verdictFilm()),
      );
    }
    final night = !ready || _stage == Stage.reveal || _stage == Stage.night || (_stage == Stage.ended && _public.winner == Team.mafia);
    final left = _client.timeLeft;
    final showClock = ready && _stage != Stage.ended && !_board.abandoned;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        backgroundColor: Saloon.ink,
        body: SaloonBackdrop(
          night: night,
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                StageHeader(
                  title: ready ? _title() : widget.room.code,
                  ribbon: ready && !_board.abandoned ? _ribbon() : null,
                  countdown: showClock ? (_beforeStart ? '…' : _clock(left)) : null,
                  urgent: showClock && !_beforeStart && left < const Duration(seconds: 10) && _stage.acceptsActions,
                  leading: IconButton(
                    icon: const Icon(Icons.close, color: Saloon.brass),
                    tooltip: _t.leaveTooltip,
                    onPressed: pressed(_confirmExit, Press.back),
                  ),
                ),
                ?_connectionBanner(),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 350),
                            child: KeyedSubtree(
                              key: ValueKey(ready ? '${_window?.key}-${_board.abandoned}' : 'connecting'),
                              child: _stageView(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (ready && !_board.abandoned && _stage.chat == 'day' && _view.familyChat)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: SegmentedButton<bool>(
                      key: const Key('online.chatSwitch'),
                      segments: [
                        ButtonSegment(value: false, label: Text(_t.online.chatTown)),
                        ButtonSegment(value: true, label: Text(_t.online.chatFamily)),
                      ],
                      selected: {_familyTab},
                      showSelectedIcon: false,
                      onSelectionChanged: (choice) => setState(() => _familyTab = choice.single),
                    ),
                  ),
                if (ready && !_board.abandoned) _chatDock(),
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
    } else if (_client.reconnecting) {
      text = _t.online.reconnecting;
      key = const Key('online.reconnecting');
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
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 6),
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      decoration: Saloon.scrim(radius: 10, border: Saloon.blood),
      child: Row(
        children: [
          Expanded(
            child: Text(text, key: key, style: AppText.body.copyWith(color: AppColors.textPrimary, fontSize: 13)),
          ),
          if (rejoin) ...[
            const SizedBox(width: 8),
            NoirButton(
              key: const Key('online.reconnect'),
              compact: true,
              label: _t.online.rejoin,
              onPressed: _rejoin,
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

  String? _ribbon() => switch (_stage) {
        Stage.reveal => _city.title,
        Stage.discussion => _t.online.discussionTitle,
        Stage.vote => _t.online.voteTitle,
        _ => null,
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

  Widget _connectingView() => _client.error == null
      ? DealingTable(status: _t.online.gameConnecting)
      : DealingTable(
          status: _t.online.connectionLost,
          below: NoirButton(
            key: const Key('online.reconnect'),
            label: _t.online.rejoin,
            feel: Press.confirm,
            onPressed: _rejoin,
          ),
        );

  Widget _closedView() => Column(
        key: const Key('online.closed'),
        children: [
          const Spacer(),
          const Icon(Icons.door_back_door_outlined, color: Saloon.brass, size: 56),
          const SizedBox(height: 16),
          ScrimText(_t.online.gameClosed),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: NoirButton(
              label: _t.online.backToRoom,
              feel: Press.confirm,
              onPressed: () => Navigator.of(context).pop(),
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
          child: NoirButton(
            key: const Key('online.ready'),
            feel: Press.confirm,
            kind: _acked ? NoirButtonKind.brass : NoirButtonKind.enamel,
            icon: _ackReceived ? Icons.check : null,
            onPressed: _acked || !enabled || !_open ? null : _ack,
            label: _ackReceived ? _t.online.readyWaiting : _acked ? _t.online.sending : _t.online.ready,
          ),
        );

  // ---------------------------------------------------------------------
  // La chat, sempre in fondo.

  ChatChannelView _chatView() {
    final familyNight = _stage.chat == 'night' && _inFamilyChat;
    // Di giorno, con un Compare vivo, la famiglia sceglie quale chat guardare.
    final familyDay = _stage.chat == 'day' && _view.familyChat && _familyTab;
    if (familyNight || familyDay) {
      return ChatChannelView(channel: ChatChannel.family, title: _t.online.chatFamily, accent: Saloon.mafia);
    }
    final String? note;
    if (_stage.chat != 'day') {
      note = _t.online.chatNightClosed;
    } else {
      note = _townChatNote;
    }
    return ChatChannelView(channel: ChatChannel.day, title: _t.online.chatTown, accent: Saloon.brass, note: note);
  }

  ({ChatChannelView view, List<ChatMessage> messages}) _chatNow() {
    final view = _chatView();
    return (view: view, messages: [for (final m in _client.chat) if (m.channel == view.channel) m]);
  }

  Widget _chatDock() {
    final now = _chatNow();
    return ChatDock(
      key: Key(now.view.channel == ChatChannel.family ? 'online.familyChat' : 'online.townChat'),
      view: now.view,
      messages: now.messages,
      myId: widget.me.id,
      labels: ChatLabels(hint: _t.online.chatHint, empty: _t.online.chatEmpty, send: _t.online.chatSend),
      onSend: (body) => _client.sendChat(_chatView().channel, body),
      source: _client,
      read: _chatNow,
    );
  }

  // ---------------------------------------------------------------------
  // Il tavolo: tutti grandi uguali, intorno al panno.

  /// I nomi brevi sui pizzini.
  String _short(Player? player) => player == null ? _t.online.abstainTag : player.name;

  SeatHand _handOf(Player voter, int from, int to, Color accent) {
    final look = AvatarLook.fallback(voter.name);
    return (from: from, to: to, sleeve: look.outfit.coat, skin: look.base.skin, mine: voter == _view.seat, accent: accent);
  }

  Widget _table({
    required List<Player> players,
    Set<Player> selectable = const {},
    Player? selected,
    void Function(Player player)? onTap,
    List<SeatVote> votes = const [],
    Color voteColor = Saloon.blood,
    bool showDead = true,
    Widget? center,
    Animation<double>? arrival,
  }) {
    final present = [for (final p in players) if (showDead || _isAlive(p)) p];
    // Il proprio posto è sempre in basso al centro: si gira il tavolo.
    final mine = present.indexOf(_view.seat);
    final seats = mine <= 0 ? present : [...present.skip(mine), ...present.take(mine)];
    final tally = <Player, int>{};
    for (final vote in votes) {
      if (vote.target case final target?) tally[target] = (tally[target] ?? 0) + 1;
    }
    final top = tally.values.fold(0, max);
    final leaders = [for (final e in tally.entries) if (e.value == top) e.key];
    final leading = top > 0 && leaders.length == 1 ? leaders.single : null;
    final index = {for (var i = 0; i < seats.length; i++) seats[i]: i};
    return SaloonTable(
      count: seats.length,
      center: center,
      leading: leading == null ? null : index[leading],
      hands: [
        for (final vote in votes)
          if (vote.target != null && index.containsKey(vote.voter) && index.containsKey(vote.target))
            _handOf(vote.voter, index[vote.voter]!, index[vote.target]!, voteColor),
      ],
      seatBuilder: (context, i, width) {
        final player = seats[i];
        final vote = votes.where((v) => v.voter == player).firstOrNull;
        final role = _publicKnowledge(player).role ?? (player == _view.seat ? null : _knowledgeOf(player).role);
        final silenced = _public.lastDawn?.silenced == player && _public.lastDawn?.round == _public.round;
        final can = selectable.contains(player);
        final seat = SeatCard(
          key: ValueKey('seat-${player.id}'),
          name: player.name,
          width: width,
          fallen: !_isAlive(player),
          offline: _offline(player),
          me: player == _view.seat,
          selected: player == selected,
          accused: player == leading,
          accusedLabel: _t.online.accusedTag,
          votes: tally[player] ?? 0,
          pizzino: vote == null ? null : '→ ${_short(vote.target)}',
          pizzinoKey: ValueKey('pizzino-${player.id}'),
          pizzinoColor: voteColor,
          note: _offline(player)
              ? _t.online.offlineBadge
              : silenced
                  ? '🤐'
                  : role == null
                      ? null
                      : _t.role(role).label,
          noteColor: role?.team == Team.mafia ? Saloon.mafia : Saloon.brass,
          dimmed: selectable.isNotEmpty && !can && _isAlive(player) && player != selected && player != _view.seat,
          onTap: can && onTap != null ? () => onTap(player) : null,
        );
        if (arrival == null) return seat;
        // L'arrivo: ognuno entra dal bordo dello schermo dietro il suo posto
        // e si siede, uno dopo l'altro.
        final direction = pi / 2 + 2 * pi * i / seats.length;
        final delay = 0.5 * i / seats.length;
        return AnimatedBuilder(
          animation: arrival,
          builder: (context, child) {
            final t = Curves.easeOutBack.transform(((arrival.value - delay) / 0.45).clamp(0.0, 1.0));
            final away = (1 - t) * 260;
            return Opacity(
              opacity: ((arrival.value - delay) / 0.2).clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(cos(direction) * away, sin(direction) * away),
                child: Transform.scale(scale: 0.9 + 0.1 * t, child: child),
              ),
            );
          },
          child: seat,
        );
      },
    );
  }

  // ---------------------------------------------------------------------
  // La carta.

  /// L'inizio della partita, una volta sola su questo telefono: i giocatori
  /// arrivano e si siedono, poi si danno le carte, poi la propria carta.
  /// Chi arriva tardi (o vuole meno movimento) va dritto alla carta.
  bool? _introPlayed;

  Widget _cardView() {
    _introPlayed ??= MediaQuery.disableAnimationsOf(context) || _client.elapsed > const Duration(seconds: 3);
    if (_introPlayed == false) {
      return _RevealIntro(
        key: const Key('online.arrival'),
        table: (arrival) => _table(players: publicSeating(_public.seats), arrival: arrival),
        dealing: DealingTable(status: _city.title),
        onDone: () => setState(() => _introPlayed = true),
      );
    }
    return _roleCardView();
  }

  Widget _roleCardView() {
    final view = _view;
    final opening = _script('night-1').opening(online: true);
    return Column(
      key: const Key('online.card'),
      children: [
        if (opening.isNotEmpty) ScrimText(opening.map((l) => l.text).join('\n'), style: AppText.body.copyWith(color: AppColors.textPrimary, fontSize: 13.5, fontStyle: FontStyle.italic)),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
              child: NoirRoleCard(
                role: view.role,
                teammates: view.teammates,
                onRevealed: () => setState(() => _cardTurned = true),
              ),
            ),
          ),
        ),
        ScrimText(_t.online.yourCardHint),
        const SizedBox(height: 10),
        _readyButton(enabled: _cardTurned),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // La notte.

  bool get _inFamilyChat => _view.alive && _view.team == Team.mafia;

  Widget _nightView() {
    final acting = _view.action != null;
    return KeyedSubtree(key: const Key('online.night'), child: acting ? _taskView() : _waitingView());
  }

  Widget _taskView() {
    final option = _view.action!;
    final task = NightTask(option.kind!, option.targets);
    final script = _script('task');
    final selected = _selected;
    final busy = _client.busy || !_open;
    final alternative = _alternative && option.alternative != null;
    final family = option.type == ActionType.mafiaVote && !alternative;
    final shown = alternative ? NightTask(option.alternative!, option.targets) : task;
    return Column(
      children: [
        if (option.alternative != null) ...[
          SegmentedButton<bool>(
            key: const Key('online.alternative'),
            segments: [
              ButtonSegment(value: false, label: Text(_t.voteTheHit)),
              ButtonSegment(value: true, label: Text(_t.sewAMouth)),
            ],
            selected: {_alternative},
            showSelectedIcon: false,
            onSelectionChanged: busy ? null : (choice) => setState(() => _alternative = choice.single),
          ),
          const SizedBox(height: 6),
        ],
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: Saloon.scrim(radius: 12, border: family ? Saloon.mafia : Saloon.brass),
          child: Column(
            children: [
              Text(script.taskPrompt(shown, _public.round), textAlign: TextAlign.center, style: AppText.display(19, color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              Text(script.taskHint(shown), textAlign: TextAlign.center, style: AppText.body.copyWith(color: const Color(0xFFD8CCBE), fontSize: 13)),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: _table(
            players: _secretTable(),
            selectable: option.targets.toSet(),
            selected: selected,
            onTap: busy ? null : (player) => setState(() => _selected = player),
            votes: family ? _view.familyVotes : const [],
            voteColor: Saloon.mafia,
          ),
        ),
        const SizedBox(height: 8),
        if (_client.busy) ScrimText(_t.online.sending),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: NoirButton(
                key: const Key('online.pass'),
                kind: NoirButtonKind.brass,
                label: _t.pass,
                onPressed: busy ? null : () => _send(Pass(_view.seat.id)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: NoirButton(
                key: const Key('online.confirm'),
                label: selected == null ? _t.confirm : '${_t.confirm} · ${selected.name}',
                onPressed: selected == null || busy
                    ? null
                    : () => _send(family ? MafiaVote(_view.seat.id, selected.id) : NightAction(_view.seat.id, selected.id)),
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
    final pending = _public.phase == GamePhase.night && _public.nightPending > 0
        ? _t.online.waitingForOthers(_public.nightPending)
        : null;
    if (finding == null) {
      final status = !view.alive
          ? _t.online.youAreOut
          : view.nightChoice == null
              ? _script('night-${_public.round}').nightFalls(_public.round, online: true).map((l) => l.text).join('\n')
              : _t.online.moveRegistered;
      return Column(
        key: const Key('online.waiting'),
        children: [
          Expanded(
            child: DealingTable(
              key: view.nightChoice != null && finding == null ? const Key('online.moveRegistered') : null,
              status: status,
            ),
          ),
          if (view.nightChoice != null) ScrimText(_t.nobodyWillKnow),
          if (pending != null) ...[const SizedBox(height: 6), ScrimText(pending)],
        ],
      );
    }
    return Column(
      key: const Key('online.waiting'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AvatarSpotlight(seed: finding.subject.name, size: 130, fallen: found != null),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: Saloon.scrim(radius: 14, border: isMafia ? Saloon.mafia : Saloon.brass),
          child: Column(
            children: [
              Text(found == null ? _t.yourInvestigation : _t.inTheGrave, style: AppText.overline.copyWith(color: Saloon.brass)),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(finding.subject.name.toUpperCase(), style: AppText.display(30, color: AppColors.textPrimary)),
              ),
              const SizedBox(height: 8),
              Text(
                found != null ? _t.wasRole(_t.role(found).label) : isMafia ? _t.isFamily : _t.isInnocent,
                style: AppText.display(20, color: isMafia ? Saloon.mafia : Saloon.clean),
              ),
            ],
          ),
        ),
        if (pending != null) ...[const SizedBox(height: 12), ScrimText(pending)],
      ],
    );
  }

  // ---------------------------------------------------------------------
  // I film, per tutti nello stesso momento.

  /// Prima del film (l'attimo dell'inizio comune): solo il buio, niente
  /// cartelli. Il film poi si vede tutto: nessuna conferma anticipata, il
  /// server passa oltre solo allo scadere, e intanto resta l'ultima scena.
  Widget _waitingFilm() => const ColoredBox(color: Colors.black, child: SizedBox.expand());

  Widget _dawnFilm() {
    final dawn = _public.lastDawn;
    if (dawn == null || dawn.attacks.isEmpty) return _waitingFilm();
    final elapsed = _client.elapsed;
    if (elapsed < Duration.zero) return _waitingFilm();
    final index = min(elapsed.inMilliseconds ~/ DeathScene.length.inMilliseconds, dawn.attacks.length - 1);
    final story = _storiesOf(dawn)[index];
    final film = filmFor(story);
    final attack = dawn.attacks[index];
    final into = elapsed - DeathScene.length * index;
    return DeathScene(
      key: ValueKey('online-crime-${dawn.round}-$index'),
      act: film.act,
      save: film.save,
      victimName: attack.isFatal ? attack.target.name : _t.someoneSaved,
      caption: story.scene.text,
      epilogue: story.epilogue?.id ?? '',
      style: _style,
      startAt: into > DeathScene.length ? DeathScene.length : into,
      onFinished: () {
        if (mounted) setState(() {});
      },
    );
  }

  Widget _verdictFilm() {
    final report = _public.lastLynch;
    final elapsed = _client.elapsed;
    if (report == null || elapsed < Duration.zero) return _waitingFilm();
    final length = OnlinePacing.verdictFilm(condemns: report.condemned != null);
    final startAt = elapsed > length ? length : elapsed;
    final condemned = report.condemned;
    void done() {
      if (mounted) setState(() {});
    }

    final key = ValueKey('online-verdict-${report.round}');
    return condemned == null
        ? VerdictScene.acquittal(key: key, style: _style, startAt: startAt, onFinished: done)
        : VerdictScene(
            key: key,
            condemnedName: condemned.name,
            variant: VerdictScene.variants[Random(_board.narrationSeed + report.round).nextInt(VerdictScene.variants.length)],
            town: _city.name,
            style: _style,
            startAt: startAt,
            onFinished: done,
          );
  }

  // ---------------------------------------------------------------------
  // La cronaca: l'alba e il verdetto, solo il racconto, su un giornale.

  bool get _italian => _t.language.locale.languageCode == 'it';

  String get _masthead =>
      _italian ? 'Il Corriere di ${_city.name}' : 'The ${_city.name} Courier';

  String _dateLine(String edition) => _italian
      ? 'Anno XIX  ·  Giorno ${_public.round}  ·  $edition'
      : 'Vol. XIX  ·  Day ${_public.round}  ·  $edition';

  List<FrontPageLine> _printed(List<ScriptLine> lines) => [for (final l in lines) (text: l.text, fact: l.isFact)];

  Widget _chronicle({required Key key, required Widget page}) => Column(
        key: key,
        children: [
          Expanded(child: page),
          const SizedBox(height: 12),
          _readyButton(),
        ],
      );

  Widget _dawnView() {
    final dawn = _public.lastDawn;
    if (dawn == null) return _connectingView();
    final lines = _script('dawn-${dawn.round}')
        .dawn(dawn, discussion: _board.settings.discussion, stories: _storiesOf(dawn), online: true);
    final dead = [for (final attack in dawn.attacks) if (attack.isFatal) attack.target.name];
    final names = dead.join(_italian ? ' E ' : ' AND ');
    final headline = dawn.victims.isEmpty
        ? _t.everyoneAlive
        : _italian
            ? (dead.length > 1 ? 'Trovati morti $names' : 'Trovato morto $names')
            : '$names found dead';
    return _chronicle(
      key: const Key('online.dawn'),
      page: FrontPage(
        key: ValueKey('front-dawn-${dawn.round}'),
        masthead: _masthead,
        dateLine: _dateLine(_italian ? "Edizione dell'alba" : 'Dawn edition'),
        headline: headline,
        kicker: _t.crimePage,
        portraits: dead,
        fallen: dawn.victims.isNotEmpty,
        lines: _printed(lines),
      ),
    );
  }

  Widget _verdictView() {
    final report = _public.lastLynch;
    if (report == null) return _connectingView();
    final condemned = report.condemned;
    final role = report.role;
    final mafia = role?.team == Team.mafia;
    final String headline;
    if (condemned == null) {
      headline = _italian ? 'La piazza non si decide' : 'The square cannot decide';
    } else if (role == null) {
      headline = _italian ? 'Linciato ${condemned.name}' : '${condemned.name} lynched';
    } else {
      headline = _italian
          ? 'Linciato ${condemned.name}: ${mafia ? 'era della Famiglia' : 'era innocente'}'
          : '${condemned.name} lynched: ${mafia ? 'one of the Family' : 'an innocent man'}';
    }
    return _chronicle(
      key: const Key('online.verdict'),
      page: FrontPage(
        key: ValueKey('front-verdict-${report.round}'),
        masthead: _masthead,
        dateLine: _dateLine(_italian ? 'Edizione della sera' : 'Evening edition'),
        headline: headline,
        kicker: condemned == null ? _t.noConviction : null,
        portraits: [if (condemned != null) condemned.name],
        fallen: condemned != null,
        stamp: role == null ? null : _t.role(role).label,
        stampTeam: role == null ? null : (mafia ? _t.familyBadge : _t.townBadge),
        stampColor: role == null ? Colors.black : stampColorFor(role),
        tallyTitle: _italian ? 'Lo scrutinio' : 'The tally',
        tallyKey: const Key('online.verdictVotes'),
        tally: [for (final vote in _lastVotes) '${vote.voter.name} → ${_short(vote.target)}'],
        lines: _printed(_script('lynch-${report.round}').lynch(report)),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Il giorno: si discute in chat, poi si vota a viso aperto.

  String? get _townChatNote {
    if (!_view.alive) return _t.online.chatDead;
    if (_view.silenced) {
      return _t.online.chatSilenced;
    }
    return null;
  }

  Widget _discussionView() => Column(
        key: const Key('online.discussion'),
        children: [
          ScrimText(_t.online.discussionHint),
          const SizedBox(height: 6),
          Expanded(child: _table(players: publicSeating(_public.seats))),
          const SizedBox(height: 10),
          _readyButton(),
        ],
      );

  Widget _voteView() {
    final view = _view;
    final option = view.action;
    final votes = _public.dayVotes;
    final mine = [for (final vote in votes) if (vote.voter == view.seat) vote].firstOrNull;
    final canVote = option != null && _open && !_client.busy;
    final selected = mine?.target;
    final cast = votes.length;
    final alive = _public.alive.length;
    return Column(
      key: const Key('online.vote'),
      children: [
        ScrimText(view.alive ? _t.online.voteHint : _t.online.youAreOut),
        const SizedBox(height: 4),
        Expanded(
          child: _table(
            players: publicSeating(_public.seats),
            selectable: canVote ? {for (final p in option.targets) if (p != selected) p} : const {},
            selected: selected,
            onTap: (player) => _send(DayVote(view.seat.id, player.id)),
            votes: votes,
            showDead: false,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: Saloon.scrim(radius: 12),
          child: Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 1,
                  runSpacing: 1,
                  children: [
                    for (var i = 0; i < alive; i++)
                      Icon(Icons.person, size: alive > 10 ? 13 : 16, color: i < cast ? Saloon.blood : const Color(0xFF4A423C)),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(_t.online.votesCast(cast, alive), style: AppText.overline.copyWith(color: AppColors.textPrimary, fontSize: 11)),
            ],
          ),
        ),
        if (_client.busy || mine != null) ...[
          const SizedBox(height: 6),
          if (_client.busy)
            ScrimText(_t.online.sending)
          else
            ScrimText(
              mine!.target == null
                  ? '${_t.online.abstained} · ${_t.online.voteRegistered}'
                  : '${_t.online.votedFor(mine.target!.name)} · ${_t.online.voteRegistered}',
              key: const Key('online.voteRegistered'),
              style: AppText.body.copyWith(color: Saloon.brass, fontSize: 14, fontWeight: FontWeight.w700),
            ),
        ],
        if (option != null) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: NoirButton(
              key: const Key('online.abstain'),
              kind: NoirButtonKind.brass,
              label: _t.online.abstain,
              onPressed: canVote && mine?.target != null || canVote && mine == null ? () => _send(Pass(view.seat.id)) : null,
            ),
          ),
        ],
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
    final players = [for (final p in publicSeating(_public.seats)) if (roles[p] != null) p];
    return Column(
      key: const Key('online.end'),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: Saloon.scrim(radius: 14, border: mafiaWon ? Saloon.mafia : Saloon.brass),
          child: Column(
            children: [
              Icon(mafiaWon ? Icons.theater_comedy : Icons.balance, color: mafiaWon ? Saloon.mafia : Saloon.brass, size: 40),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(mafiaWon ? _t.familyWins : _t.townWins,
                    style: Saloon.plate(32, color: mafiaWon ? Saloon.mafia : Saloon.brass)),
              ),
              const SizedBox(height: 4),
              Text(_t.whoWasWho, style: AppText.overline.copyWith(color: AppColors.textPrimary)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: LayoutBuilder(builder: (context, box) {
            const columns = 3;
            final width = (box.maxWidth - 24) / columns * 0.8;
            return SingleChildScrollView(
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 30,
                children: [
                  for (final player in players)
                    SizedBox(
                      width: (box.maxWidth - 24) / columns,
                      child: Column(
                        children: [
                          SeatCard(
                            name: player.name,
                            width: width,
                            fallen: !_isAlive(player),
                            me: player == _view.seat,
                            selected: roles[player]!.team == winner,
                            note: _t.role(roles[player]!).label,
                            noteColor: roles[player]!.team == Team.mafia ? Saloon.mafia : Saloon.brass,
                          ),
                          const SizedBox(height: 4),
                          Text(_fateOf(player),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              style: AppText.body.copyWith(color: const Color(0xFFD8CCBE), fontSize: 11.5, height: 1.2)),
                        ],
                      ),
                    ),
                ],
              ),
            );
          }),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: NoirButton(
            key: const Key('online.backToRoom'),
            label: _t.online.backToRoom,
            feel: Press.confirm,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ],
    );
  }
}

/// L'arrivo al tavolo e la distribuzione delle carte, prima della propria.
class _RevealIntro extends StatefulWidget {
  final Widget Function(Animation<double> arrival) table;
  final Widget dealing;
  final VoidCallback onDone;

  const _RevealIntro({super.key, required this.table, required this.dealing, required this.onDone});

  @override
  State<_RevealIntro> createState() => _RevealIntroState();
}

class _RevealIntroState extends State<_RevealIntro> with SingleTickerProviderStateMixin {
  /// L'arrivo dura così, poi le carte.
  static const _arrive = Duration(milliseconds: 2300);
  static const _deal = Duration(milliseconds: 1700);

  late final _arrival = AnimationController(vsync: this, duration: _arrive)..forward();
  Timer? _dealt;
  bool _dealing = false;

  @override
  void initState() {
    super.initState();
    _arrival.addStatusListener((status) {
      if (status != AnimationStatus.completed || !mounted) return;
      setState(() => _dealing = true);
      _dealt = Timer(_deal, () {
        if (mounted) widget.onDone();
      });
    });
  }

  @override
  void dispose() {
    _dealt?.cancel();
    _arrival.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 380),
        child: _dealing
            ? KeyedSubtree(key: const ValueKey('deal'), child: widget.dealing)
            : KeyedSubtree(key: const ValueKey('arrive'), child: widget.table(_arrival)),
      );
}
