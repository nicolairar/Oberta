import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_strings.dart';
import '../../../l10n/desktop_game_strings.dart';
import '../../desktop/desktop_canvas.dart';
import '../settings_screen.dart';
import 'game/desk_game.dart';
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
import '../../press.dart';
import '../../avatar/avatar_look.dart';
import '../../seating.dart';
import '../../theme/app_theme.dart';
import '../../widgets/death_scene.dart';
import '../../widgets/night_notes.dart';
import '../../widgets/scene_scaffold.dart';
import '../../widgets/content_width.dart';
import '../../widgets/roles_panel.dart';
import '../../widgets/wide_scale.dart';
import '../../widgets/lynch_mark.dart';
import 'game/chat_dock.dart';
import 'game/chronicle_headlines.dart';
import 'game/front_page.dart';
import 'game/noir_role_card.dart';
import 'game/noir_ui.dart';
import 'game/saloon_table.dart';
import 'game/saloon_transitions.dart';
import 'game/seat_card.dart';
import 'online_widgets.dart';
import 'recap_screen.dart';
import '../../../l10n/recap_strings.dart';
import 'safety_sheets.dart';
import '../../../l10n/roles_sheet_strings.dart';
import '../../widgets/roles_sheet.dart';

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
/// Una fase del gioco: chi la riconosce, il tavolo (o il giornale) e la
/// striscia dei comandi. Le misure le dà la pagina, sempre le stesse.
typedef _Phase = ({Key key, Widget table, Widget strip});

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
      GameClient(backend: widget.services.game, roomId: widget.room.id, clock: widget.clock, me: widget.me.id)
        ..addListener(_changed);
  late final AppStrings _t = widget.room.language.strings;
  late final Random _shuffle = widget.seating ?? Random();
  Timer? _ticker;

  /// Su PC: il menu di Esc è aperto (la partita intanto va avanti).
  bool _paused = false;
  late final DesktopGameStrings _dt = DesktopGameStrings(widget.room.language);
  final FocusNode _chatFocus = FocusNode(debugLabel: 'online.chat');

  /// Questo build è sulla tela desktop coricata.
  bool _deskMode = false;

  /// Quanto crescono le parole sul panno e nella striscia sul desktop.
  double get _k => _deskMode ? 1.55 : 1.0;

  Player? _selected;

  /// La mossa appena fatta, mostrata subito (mano, pizzino) mentre viaggia:
  /// il server poi la conferma (resta) o la rifiuta (la mano torna indietro).
  /// `target` null: astensione.
  ({Player? target, String stage})? _hope;

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

  /// Le scelte della famiglia di questa notte: restano sul tavolo fino al
  /// film, anche quando il server ha già chiuso la notte.
  List<SeatVote> _lastFamilyVotes = const [];

  /// La fase già vista da qui: al cambio, musica e suoni.
  String? _stageShown;

  /// Quanti addii sono già stati annunciati (null: non si è ancora visto il
  /// tavolo; chi rientra non si sente ripetere quelli vecchi).
  int? _departedShown;

  /// Chi risultava assente l'ultima volta: per dire chi va e chi torna.
  Set<String>? _offlineShown;

  /// Le scene degli agguati di ogni alba: le stesse per il film e per la
  /// cronaca, e su ogni telefono (stesso seme).
  final Map<int, List<DeathStory>> _stories = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    RecapShelf.last = null;
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
    _chatFocus.dispose();
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
    if (_client.takeRejection() != null) showNote(context, _t.online.rejected, kind: NoticeKind.error);
    if (!_client.busy) _hope = null;
    final seat = _client.seat;
    if (seat?.receipt case (:final id, result: IntentAccepted(:final finding?)) when id != _findingFor) {
      _findingFor = id;
      _finding = finding;
    }
    if (_client.ready) {
      if (_stage == Stage.vote) _lastVotes = _public.dayVotes;
      if (_stage == Stage.night && _view.familyVotes.isNotEmpty) _lastFamilyVotes = _view.familyVotes;
      if (_stage == Stage.discussion) _lastFamilyVotes = const [];
      _enterStage();
      _announceDepartures();
      if (_public.recap case final recap?) {
        RecapShelf.last = recap;
        RecapShelf.me = _view.seat;
      }
      _feelMentions();
    }
    setState(() {});
  }

  void _enterStage() {
    final window = _window;
    if (window == null || window.key == _stageShown) return;
    _stageShown = window.key;
    _selected = null;
    _hope = null;
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
        if (_public.lastLynch?.condemned != null) stage.cue(Cue.drumroll);
      case Stage.discussion || Stage.vote:
        stage.music(MusicMood.day);
        stage.ambience(null);
      case Stage.ended:
        final winner = _public.winner;
        if (winner != null) {
          // La partita è finita: quando la vittoria smette di suonare, il menu.
          stage.screenLoop = MusicMood.menu;
          stage.music(winner != Team.citizens ? MusicMood.winFamily : MusicMood.winTown);
          stage.cue(winner != Team.citizens ? Cue.familyWins : Cue.townWins);
        }
      case Stage.dawn || Stage.verdict:
        break;
    }
  }

  /// Chi ha lasciato la città (telefono spento oltre la tolleranza): lo si
  /// dice a tutti, ma la sua carta resta coperta fino al resoconto. E chi si
  /// allontana dal tavolo, o ci torna, con un biglietto.
  void _announceDepartures() {
    final r = RecapStrings.of(context);
    final departed = _board.departed;
    final shown = _departedShown;
    _departedShown = departed.length;
    if (shown != null && departed.length > shown) {
      for (final seat in departed.skip(shown)) {
        final player = _board.seating.occupantOf(seat);
        if (player != null) showNote(context, r.leftTown(player.name), kind: NoticeKind.leave);
      }
    }
    final offline = {..._board.offline};
    final before = _offlineShown;
    _offlineShown = offline;
    if (before == null || _stage == Stage.ended) return;
    for (final seat in offline.difference(before)) {
      if (seat == _view.seat.id || departed.contains(seat)) continue;
      final player = _board.seating.occupantOf(seat);
      if (player != null) showNote(context, r.wentAway(player.name), kind: NoticeKind.away);
    }
    for (final seat in before.difference(offline)) {
      if (seat == _view.seat.id || departed.contains(seat)) continue;
      final player = _board.seating.occupantOf(seat);
      if (player != null) showNote(context, r.cameBack(player.name), kind: NoticeKind.arrive);
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
    final key = _window?.key;
    if (key != null && intent is! RevealMayor) {
      final hope = switch (intent) {
        DayVote(:final target) ||
        MafiaVote(:final target) ||
        NightAction(:final target) => (target: _seatOf(target), stage: key),
        Pass() || RevealMayor() => (target: null, stage: key),
      };
      setState(() => _hope = hope);
    }
    try {
      await _client.send(intent);
    } catch (error) {
      if (mounted) {
        setState(() => _hope = null);
        showFailure(context, error);
      }
    }
  }

  Player? _seatOf(String id) => publicSeating(_public.seats).where((p) => p.id == id).firstOrNull;

  /// I voti del server con, al posto del proprio, la mossa appena fatta.
  List<SeatVote> _withHope(List<SeatVote> votes) {
    final hope = _hope;
    if (hope == null || hope.stage != _window?.key) return votes;
    return [
      for (final vote in votes)
        if (vote.voter != _view.seat) vote,
      (voter: _view.seat, target: hope.target),
    ];
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
    if (_deskMode) {
      final leave = await confirmDeskLeave(
        context,
        title: _t.leaveQuestion,
        body: _view.alive ? _t.online.leaveAbandonWarning : _t.online.leaveDeadWarning,
      );
      if (!leave || !mounted) return;
      setState(() => _paused = false);
      unawaited(widget.services.game.leaveGame(widget.room.id).catchError((Object _) {}));
      Navigator.of(context).pop();
      return;
    }
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(_t.leaveQuestion),
        content: Text(_view.alive ? _t.online.leaveAbandonWarning : _t.online.leaveDeadWarning),
        actions: [
          TextButton(onPressed: pressed(() => Navigator.of(context).pop(false), Press.back), child: Text(_t.stay)),
          TextButton(onPressed: pressed(() => Navigator.of(context).pop(true), Press.tap), child: Text(_t.leave)),
        ],
      ),
    );
    if (leave != true || !mounted) return;
    // Da vivo, uscire è un abbandono: il server lo sa subito, così niente
    // premi nemmeno se la squadra vince dopo. Da morto non si paga niente,
    // ma non si prende niente.
    // Prima l'uscita dal gioco, poi dalla stanza: altrimenti il server non
    // sa più a che tavolo eri.
    try {
      await widget.services.game.leaveGame(widget.room.id).timeout(const Duration(seconds: 4));
    } catch (_) {}
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    _deskMode = DesktopCanvas.of(context);
    if (_deskMode) {
      _scaled = null;
      final desk = _deskShell();
      if (identical(AppStrings.of(context), _t)) return desk;
      return Localizations.override(context: context, locale: _t.language.locale, child: desk);
    }
    final screen = WideScale(
      child: Builder(
        builder: (inner) {
          _scaled = inner;
          return _screen();
        },
      ),
    );
    if (identical(AppStrings.of(context), _t)) return screen;
    return Localizations.override(context: context, locale: _t.language.locale, child: screen);
  }

  /// Il contesto dentro [WideScale]: le misure dello schermo ingrandito.
  BuildContext? _scaled;

  MediaQueryData get _media => MediaQuery.of(_scaled ?? context);

  /// Prima dell'inizio comune della fase (l'orologio non corre ancora).
  bool get _beforeStart => _client.ready && _client.elapsed < Duration.zero;

  /// I film dell'alba prendono tutto lo schermo: si entra e si esce con
  /// una dissolvenza sul nero, non con un taglio.
  Widget _filmSwitch(Widget page) => AnimatedSwitcher(
    duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : phaseFade,
    switchInCurve: Curves.easeOutCubic,
    switchOutCurve: Curves.easeInCubic,
    child: KeyedSubtree(key: ValueKey(_inFilm), child: page),
  );

  bool get _inFilm => _client.ready && !_board.abandoned && _stage == Stage.dawnFilms;

  Widget _screen() => _filmSwitch(_screenPage());

  Widget _screenPage() {
    final ready = _client.ready;
    if (ready && !_board.abandoned && _stage == Stage.dawnFilms) {
      return PopScope(
        canPop: false,
        child: Scaffold(backgroundColor: Colors.black, body: _dawnFilm()),
      );
    }
    final night =
        !ready ||
        _stage == Stage.reveal ||
        _stage == Stage.night ||
        (_stage == Stage.ended && _public.winner == Team.mafia);
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
                  action: ready
                      ? RolesButton(
                          color: Saloon.brass,
                          onPressed: pressed(
                            () => RolesSheet.show(context, deck: _public.deck, revealed: publicReveals(_public)),
                            Press.card,
                          ),
                        )
                      : null,
                ),
                ?_connectionBanner(),
                Expanded(
                  child: _inlineChat
                      ? _gamePage()
                      : ContentWidth(
                          maxWidth: 780,
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
                ),
                if (ready && !_board.abandoned && !_inlineChat) ContentWidth(maxWidth: 780, child: _chatDock()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Su PC: la partita a schermo intero. In alto la barra (menu, fase,
  // orologio); a sinistra il tavolo con la striscia dei comandi sotto; a
  // destra, fissi, il mazzo e la chat. Esc apre il menu, INVIO porta alla
  // chat.

  /// Sul desktop la colonna di destra (mazzo e chat) è larga così.
  static const _deskSideWidth = 540.0;

  /// La striscia dei comandi sotto il tavolo, sul desktop.
  static const _deskStripHeight = 112.0;

  void _openPause() {
    if (_paused) return;
    _chatFocus.unfocus();
    setState(() => _paused = true);
  }

  void _closePause() {
    if (!_paused) return;
    setState(() => _paused = false);
  }

  /// La chat accetta messaggi adesso.
  bool get _chatWritable => _client.ready && !_board.abandoned && _chatView().note == null;

  KeyEventResult _deskKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      // Prima si esce dalla chat, poi il menu (e da lì di nuovo al tavolo).
      if (_chatFocus.hasFocus) {
        _chatFocus.unfocus();
      } else if (_paused) {
        _closePause();
      } else {
        _openPause();
      }
      return KeyEventResult.handled;
    }
    final enter = key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter;
    // Nel campo INVIO manda il messaggio: qui non si tocca.
    if (enter && !_chatFocus.hasFocus && !_paused && _chatWritable) {
      _chatFocus.requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Widget _deskShell() {
    final ready = _client.ready;
    final Widget page;
    if (ready && !_board.abandoned && _stage == Stage.dawnFilms) {
      page = Scaffold(backgroundColor: Colors.black, body: _dawnFilm());
    } else {
      final night =
          !ready ||
          _stage == Stage.reveal ||
          _stage == Stage.night ||
          (_stage == Stage.ended && _public.winner == Team.mafia);
      final left = _client.timeLeft;
      final showClock = ready && _stage != Stage.ended && !_board.abandoned;
      final side = ready && !_board.abandoned;
      page = Scaffold(
        backgroundColor: Saloon.ink,
        body: SaloonBackdrop(
          night: night,
          child: Column(
            children: [
              DeskGameHud(
                title: ready ? _title() : widget.room.code,
                ribbon: ready && !_board.abandoned ? _ribbon() : null,
                countdown: showClock ? (_beforeStart ? '…' : _clock(left)) : null,
                urgent: showClock && !_beforeStart && left < const Duration(seconds: 10) && _stage.acceptsActions,
                onMenu: _openPause,
                strings: _dt,
              ),
              ?_connectionBanner(),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(DeskSize.gutter, 4, DeskSize.gutter, 36),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 350),
                          child: KeyedSubtree(
                            key: ValueKey(ready ? '${_window?.key}-${_board.abandoned}' : 'connecting'),
                            child: _deskStage(),
                          ),
                        ),
                      ),
                      if (side) ...[
                        const SizedBox(width: 36),
                        SizedBox(width: _deskSideWidth, child: _deskSide()),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: Focus(
        autofocus: true,
        onKeyEvent: _deskKey,
        child: DeskTheme(
          child: NoirDesk(
            child: Stack(
              children: [
                Positioned.fill(child: _filmSwitch(page)),
                if (_paused)
                  Positioned.fill(
                    child: DeskPauseMenu(
                      strings: _dt,
                      onResume: _closePause,
                      onRoles: () => RolesSheet.show(context, deck: _public.deck, revealed: publicReveals(_public)),
                      onSettings: () => SettingsScreen.open(context),
                      onLeave: _confirmExit,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// La parte sinistra: il tavolo (o la carta, il giornale, la fine).
  Widget _deskStage() {
    if (!_client.ready) return _connectingView();
    if (_board.abandoned) {
      return Center(child: SizedBox(width: 640, height: 520, child: _closedView()));
    }
    switch (_stage) {
      case Stage.reveal:
        return _cardView();
      case Stage.ended:
        return _deskEndView();
      default:
        final phase = _phase();
        return KeyedSubtree(
          key: phase.key,
          child: Column(
            children: [
              Expanded(
                child: SizedBox(key: const Key('game.tableSlot'), width: double.infinity, child: phase.table),
              ),
              const SizedBox(height: 12),
              SizedBox(
                key: const Key('game.stripSlot'),
                height: _deskStripHeight,
                width: double.infinity,
                child: Center(
                  child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 860), child: phase.strip),
                ),
              ),
            ],
          ),
        );
    }
  }

  /// La colonna di destra: il mazzo in alto, la chat sotto (tutta l'altezza
  /// che resta), e come si usa con la tastiera.
  Widget _deskSide() {
    final now = _chatNow();
    final family = now.view.channel == ChatChannel.family;
    final writable = now.view.note == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DeskRolesPanel(
          deck: _public.deck,
          revealed: publicReveals(_public),
          onOpen: () => RolesSheet.show(context, deck: _public.deck, revealed: publicReveals(_public)),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: AnimatedContainer(
            key: Key(family ? 'online.familyChat' : 'online.townChat'),
            duration: const Duration(milliseconds: 220),
            decoration: BoxDecoration(
              color: const Color(0xF00F0B09),
              borderRadius: BorderRadius.circular(DeskSize.radius),
              border: Border.all(color: now.view.accent.withValues(alpha: 0.7), width: 1.4),
              boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 32, offset: Offset(0, 12))],
            ),
            padding: const EdgeInsets.fromLTRB(24, 20, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SizedBox(
                    key: const Key('game.chatSlot'),
                    child: ChatLog(
                      view: now.view,
                      messages: now.messages,
                      myId: widget.me.id,
                      focusNode: _chatFocus,
                      labels: ChatLabels(hint: _t.online.chatHint, empty: _t.online.chatEmpty, send: _t.online.chatSend),
                      onSend: (body) => _client.sendChat(_chatView().channel, body),
                      seats: _chatSeats,
                      onHold: _holdMessage,
                      trailing: _stage.chat == 'day' && _view.familyChat ? _chatSwitch() : null,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (writable) ...[
                      DeskKeycap(_dt.keyEnter),
                      const SizedBox(width: 8),
                      Text(_dt.chatKeys.split(' ').skip(1).join(' '),
                          style: DeskText.text(size: DeskText.caption, color: AppColors.textSecondary)),
                      const SizedBox(width: 16),
                    ],
                    Expanded(
                      child: Text(
                        _dt.rightClick,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: writable ? TextAlign.right : TextAlign.left,
                        style: DeskText.text(size: 13, color: AppColors.textSecondary.withValues(alpha: 0.75)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// La carta, sul desktop: il racconto in alto, la carta grande al centro
  /// (si tiene premuto il tasto del mouse per girarla), sotto «pronto».
  Widget _deskCardView() {
    final view = _view;
    final opening = _script('night-1').opening(online: true);
    return Column(
      key: const Key('online.card'),
      children: [
        if (opening.isNotEmpty)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: ScrimText(
              opening.map((l) => l.text).join('\n'),
              style: DeskText.text(size: DeskText.lead).copyWith(fontStyle: FontStyle.italic),
            ),
          ),
        const SizedBox(height: 24),
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) {
              final height = min(box.maxHeight, 620.0);
              return Center(
                child: SizedBox(
                  height: height,
                  width: height * 5 / 7.4,
                  child: NoirRoleCard(
                    role: view.role,
                    teammates: view.teammates,
                    bounty: view.bounty,
                    onRevealed: () => setState(() => _cardTurned = true),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        ScrimText(_t.online.yourCardHint),
        const SizedBox(height: 18),
        SizedBox(width: 560, child: _readyButton(enabled: _cardTurned)),
      ],
    );
  }

  /// La fine, sul desktop: chi ha vinto in una targa larga, poi tutti i
  /// giocatori con la loro carta e com'è finita.
  Widget _deskEndView() {
    final winner = _public.winner;
    final mafiaWon = winner == Team.mafia;
    final arsonistWon = winner == Team.neutral;
    final roles = _public.finalRoles;
    final accent = mafiaWon ? Saloon.mafia : Saloon.brass;
    final players = [
      for (final p in publicSeating(_public.seats))
        if (roles[p] != null) p,
    ];
    return Column(
      key: const Key('online.end'),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 40),
          decoration: Saloon.scrim(radius: DeskSize.radius, border: accent),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(mafiaWon ? Icons.theater_comedy : Icons.balance, color: accent, size: 64),
              const SizedBox(width: 28),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    arsonistWon
                        ? _t.arsonistWins
                        : mafiaWon
                        ? _t.familyWins
                        : _t.townWins,
                    style: Saloon.plate(DeskText.heading + 8, color: accent),
                  ),
                  const SizedBox(height: 6),
                  Text(_t.whoWasWho.toUpperCase(), style: DeskText.overline(color: AppColors.textPrimary)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Expanded(
          child: SingleChildScrollView(
            child: Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 36,
                runSpacing: 44,
                children: [
                  for (final player in players)
                    SizedBox(
                      width: 168,
                      child: Column(
                        children: [
                          SeatCard(
                            name: player.name,
                            number: _numberOf(player),
                            width: 132,
                            fallen: !_isAlive(player),
                            me: player == _view.seat,
                            selected: _public.won(player),
                            note: _t.role(roles[player]!).label,
                            noteColor: roles[player]!.team == Team.mafia ? Saloon.mafia : Saloon.brass,
                            onLongPress: player == _view.seat
                                ? null
                                : () => showSeatActions(context,
                                    services: widget.services, name: player.name, myId: widget.me.id),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _public.personalWins.contains(player)
                                ? '${_t.wonAlone}\n${_fateOf(player)}'
                                : _fateOf(player),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            style: DeskText.text(size: DeskText.label, color: const Color(0xFFD8CCBE)).copyWith(height: 1.25),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: 560,
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
      margin: _deskMode
          ? const EdgeInsets.fromLTRB(DeskSize.gutter, 0, DeskSize.gutter + _deskSideWidth + 36, 10)
          : const EdgeInsets.fromLTRB(14, 0, 14, 6),
      padding: _deskMode ? const EdgeInsets.fromLTRB(22, 10, 10, 10) : const EdgeInsets.fromLTRB(12, 6, 6, 6),
      decoration: Saloon.scrim(radius: 10, border: Saloon.blood),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              key: key,
              style: AppText.body.copyWith(color: AppColors.textPrimary, fontSize: 13 * _k),
            ),
          ),
          if (rejoin) ...[
            const SizedBox(width: 8),
            NoirButton(key: const Key('online.reconnect'), compact: true, label: _t.online.rejoin, onPressed: _rejoin),
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
      Stage.ended => _endView(),
      // Le fasi del gioco hanno la loro pagina fissa (_gamePage).
      _ => const SizedBox.shrink(),
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
  Widget _readyButton({bool enabled = true, bool compact = false}) => !_view.alive
      ? const SizedBox.shrink()
      : SizedBox(
          width: double.infinity,
          child: NoirButton(
            key: const Key('online.ready'),
            compact: compact,
            feel: Press.confirm,
            kind: _acked ? NoirButtonKind.brass : NoirButtonKind.enamel,
            onPressed: _acked || !enabled || !_open ? null : _ack,
            // Niente «invio…» né «registrato»: si vede solo se qualcosa va storto.
            label: _acked ? _t.online.readyWaiting : _t.online.ready,
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
    return (
      view: view,
      messages: [
        for (final m in _client.chat)
          if (m.channel == view.channel) m,
      ],
    );
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
      seats: _chatSeats,
      onHold: _holdMessage,
    );
  }

  /// Il messaggio di un altro, tenuto premuto: segnalarlo o bloccarlo.
  void _holdMessage(ChatMessage message) => showPlayerActions(
    context,
    services: widget.services,
    profileId: message.profileId,
    name: message.name,
    myId: widget.me.id,
    message: message,
  );

  /// Le fasi del gioco hanno tutte la stessa pagina, con le stesse misure:
  /// il tavolo, la striscia dei comandi, la chat.
  bool get _inlineChat =>
      _client.ready &&
      !_board.abandoned &&
      const {Stage.night, Stage.dawn, Stage.discussion, Stage.vote, Stage.verdict, Stage.verdictFilm}.contains(_stage);

  /// I messaggi già visti: una chiamata in causa nuova dà un colpetto.
  int? _mentionSeen;

  void _feelMentions() {
    final chat = _client.chat;
    if (chat.isEmpty) return;
    final last = chat.last.id;
    final seen = _mentionSeen;
    _mentionSeen = last;
    if (seen == null) return;
    final seats = _chatSeats;
    final caller = chat.where((m) => m.id > seen && seats.calls(m, mine: m.profileId == widget.me.id)).lastOrNull;
    if (caller != null) {
      HapticFeedback.lightImpact();
      showNote(context, RecapStrings.of(context).calledOut(caller.name), kind: NoticeKind.mention);
    }
  }

  /// La striscia dei comandi tra il tavolo e la chat: sempre alta così.
  static const _stripHeight = 70.0;

  /// Su schermo largo la chat è una colonna a destra, larga così.
  static const _wideChatWidth = 300.0;

  /// Il tavolo: la stessa altezza in ogni fase, poco più di un terzo dello
  /// schermo, così la chat resta grande.
  double get _tableHeight => (_media.size.height * 0.38).clamp(200.0, 330.0);

  _Phase _phase() => switch (_stage) {
    Stage.night => _view.action != null ? _taskPhase() : _waitingPhase(),
    Stage.dawn => _dawnPhase(),
    Stage.discussion => _discussionPhase(),
    Stage.vote => _votePhase(),
    _ => _verdictPhase(),
  };

  /// Il passaggio da una fase all'altra (notte, alba, discussione, voto,
  /// verdetto): la pagina nuova entra in dissolvenza sopra la vecchia. Le
  /// misure sono le stesse, quindi niente salta; col movimento ridotto è un
  /// taglio netto.
  Widget _phaseSwitch(Widget child) => AnimatedSwitcher(
    duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : phaseFade,
    switchInCurve: Curves.easeOutCubic,
    switchOutCurve: Curves.easeInCubic,
    layoutBuilder: (current, previous) =>
        Stack(alignment: Alignment.topCenter, children: [...previous, ?current]),
    child: child,
  );

  /// Quanto dura la dissolvenza tra una fase e l'altra (e verso i film).
  static const phaseFade = Duration(milliseconds: 300);

  /// La pagina di ogni fase: il tavolo in alto, sotto la striscia dei
  /// comandi della fase, poi la chat (sempre la stessa, anche di notte). Con
  /// la tastiera aperta resta solo la chat.
  Widget _gamePage() {
    final typing = _media.viewInsets.bottom > 0;
    final phase = _phase();
    final now = _chatNow();
    final family = now.view.channel == ChatChannel.family;
    final chatBox = Container(
      key: Key(family ? 'online.familyChat' : 'online.townChat'),
      decoration: BoxDecoration(
        color: Saloon.ink.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: now.view.accent.withValues(alpha: 0.8), width: 1.3),
      ),
      padding: const EdgeInsets.fromLTRB(12, 6, 8, 8),
      child: ChatLog(
        view: now.view,
        messages: now.messages,
        myId: widget.me.id,
        labels: ChatLabels(hint: _t.online.chatHint, empty: _t.online.chatEmpty, send: _t.online.chatSend),
        onSend: (body) => _client.sendChat(_chatView().channel, body),
        seats: _chatSeats,
        onHold: _holdMessage,
        trailing: _stage.chat == 'day' && _view.familyChat ? _chatSwitch() : null,
      ),
    );
    final bottom = typing ? 6.0 : max(_media.viewPadding.bottom - 6, 8.0);
    if (WideScale.isWide(_media.size)) {
      return Padding(
        padding: EdgeInsets.fromLTRB(10, 0, 10, bottom),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _phaseSwitch(KeyedSubtree(
                key: phase.key,
                child: Column(
                  children: [
                    Expanded(
                      child: SizedBox(key: const Key('game.tableSlot'), width: double.infinity, child: phase.table),
                    ),
                    SizedBox(
                      key: const Key('game.stripSlot'),
                      height: _stripHeight,
                      width: double.infinity,
                      child: Center(
                        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: phase.strip),
                      ),
                    ),
                  ],
                ),
              )),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: _wideChatWidth,
              child: Column(
                children: [
                  RolesPanel(deck: _public.deck, revealed: publicReveals(_public)),
                  const SizedBox(height: 8),
                  Expanded(
                    child: SizedBox(key: const Key('game.chatSlot'), width: double.infinity, child: chatBox),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
      child: Column(
        children: [
          if (!typing)
            _phaseSwitch(KeyedSubtree(
              key: phase.key,
              child: Column(
                children: [
                  SizedBox(
                    key: const Key('game.tableSlot'),
                    height: _tableHeight,
                    width: double.infinity,
                    child: phase.table,
                  ),
                  SizedBox(
                    key: const Key('game.stripSlot'),
                    height: _stripHeight,
                    width: double.infinity,
                    child: Center(
                      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: phase.strip),
                    ),
                  ),
                ],
              ),
            )),
          Expanded(
            child: SizedBox(key: const Key('game.chatSlot'), width: double.infinity, child: chatBox),
          ),
          SizedBox(height: typing ? 6 : max(_media.viewPadding.bottom - 6, 8)),
        ],
      ),
    );
  }

  /// Di giorno, con un Compare vivo: la piazza o la famiglia.
  Widget _chatSwitch() => SizedBox(
    height: _deskMode ? 40 : 28,
    child: SegmentedButton<bool>(
      key: const Key('online.chatSwitch'),
      style: ButtonStyle(
        visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: WidgetStatePropertyAll(TextStyle(fontSize: _deskMode ? 15 : 12)),
      ),
      segments: [
        ButtonSegment(value: false, label: Text(_t.online.chatTown)),
        ButtonSegment(value: true, label: Text(_t.online.chatFamily)),
      ],
      selected: {_familyTab},
      showSelectedIcon: false,
      onSelectionChanged: (choice) => setState(() => _familyTab = choice.single),
    ),
  );

  /// Le parole sul panno, al centro del tavolo: si stringono per starci.
  Widget _felt(List<Widget> lines, {Key? key}) => FittedBox(
    key: key,
    fit: BoxFit.scaleDown,
    child: Container(
      width: _deskMode ? 430 : 230,
      padding: _deskMode ? const EdgeInsets.symmetric(horizontal: 24, vertical: 16) : const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xB0080605),
        borderRadius: BorderRadius.circular(12 * _k),
        border: _deskMode ? Border.all(color: Saloon.brassDeep.withValues(alpha: 0.5)) : null,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: lines),
    ),
  );

  Text _feltLine(
    String text, {
    Key? key,
    double size = 13.5,
    Color color = AppColors.textPrimary,
    FontWeight? weight,
    int maxLines = 4,
  }) => Text(
    text,
    key: key,
    textAlign: TextAlign.center,
    maxLines: maxLines,
    overflow: TextOverflow.ellipsis,
    style: AppText.body.copyWith(
      color: color,
      fontSize: size * _k,
      fontWeight: weight,
      height: _deskMode ? 1.35 : 1.25,
      shadows: const [Shadow(color: Colors.black, blurRadius: 6)],
    ),
  );

  // ---------------------------------------------------------------------
  // Il tavolo: tutti grandi uguali, intorno al panno.

  /// I nomi brevi sui pizzini.
  String _short(Player? player) => player == null ? _t.online.abstainTag : _tag(player);

  /// Il numero di posto (1..N), lo stesso per tutta la partita: l'ordine
  /// dei seggi sul tavolo pubblico del server.
  int? _numberOf(Player player) {
    final i = _public.seats.indexOf(player);
    return i < 0 ? null : i + 1;
  }

  /// «3 anna».
  String _tag(Player player) => switch (_numberOf(player)) {
    final n? => '$n ${player.name}',
    null => player.name,
  };

  ChatSeats get _chatSeats => ChatSeats(
    numbers: {for (var i = 0; i < _public.seats.length; i++) _public.seats[i].id: i + 1},
    myNumber: _numberOf(_view.seat),
    myName: _view.seat.name,
  );

  SeatHand _handOf(Player voter, int from, int to, Color accent) {
    final look = AvatarLook.fallback(voter.name);
    return (
      from: from,
      to: to,
      sleeve: look.outfit.coat,
      skin: look.base.skin,
      mine: voter == _view.seat,
      accent: accent,
    );
  }

  Widget _table({
    required List<Player> players,
    Set<Player> selectable = const {},
    Player? selected,
    void Function(Player player)? onTap,
    List<SeatVote> votes = const [],
    Color voteColor = Saloon.blood,
    Widget? center,
    Animation<double>? arrival,
    Player? lynched,
    Duration lynchedAt = Duration.zero,
  }) {
    // I morti restano al loro posto, segnati come caduti.
    final present = [...players];
    // Il proprio posto è sempre in basso al centro: si gira il tavolo.
    final mine = present.indexOf(_view.seat);
    final seats = mine <= 0 ? present : [...present.skip(mine), ...present.take(mine)];
    final tally = <Player, int>{};
    for (final vote in votes) {
      if (vote.target case final target?) tally[target] = (tally[target] ?? 0) + 1;
    }
    final top = tally.values.fold(0, max);
    final leaders = [
      for (final e in tally.entries)
        if (e.value == top) e.key,
    ];
    final leading = top > 0 && leaders.length == 1 ? leaders.single : null;
    final index = {for (var i = 0; i < seats.length; i++) seats[i]: i};
    return SaloonTable(
      count: seats.length,
      maxCard: _deskMode ? 152 : 118,
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
          number: _numberOf(player),
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
              ? '🤐 ${RolesSheetStrings.of(context).silenced}'
              : role == null
              ? null
              : _t.role(role).label,
          noteColor: role?.team == Team.mafia ? Saloon.mafia : Saloon.brass,
          role: _publicKnowledge(player).role,
          selectable: can && onTap != null && player != selected,
          dimmed: selectable.isNotEmpty && !can && _isAlive(player) && player != selected && player != _view.seat,
          onTap: can && onTap != null ? () => onTap(player) : null,
          onLongPress: player == _view.seat
              ? null
              : () => showSeatActions(context, services: widget.services, name: player.name, myId: widget.me.id),
        );
        if (player == lynched) {
          return LynchMark(
            key: ValueKey('lynch-${_public.lastLynch?.round}-${player.id}'),
            label: _italian ? 'Linciato' : 'Lynched',
            startAt: lynchedAt,
            child: seat,
          );
        }
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
    return _deskMode ? _deskCardView() : _roleCardView();
  }

  Widget _roleCardView() {
    final view = _view;
    final opening = _script('night-1').opening(online: true);
    return Column(
      key: const Key('online.card'),
      children: [
        if (opening.isNotEmpty)
          ScrimText(
            opening.map((l) => l.text).join('\n'),
            style: AppText.body.copyWith(color: AppColors.textPrimary, fontSize: 13.5, fontStyle: FontStyle.italic),
          ),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
              child: NoirRoleCard(
                role: view.role,
                teammates: view.teammates,
                bounty: view.bounty,
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

  _Phase _taskPhase() {
    final option = _view.action!;
    final task = NightTask(option.kind!, option.targets);
    final script = _script('task');
    final selected = _hope?.target ?? _selected;
    final busy = _client.busy || !_open;
    final alternative = _alternative && option.alternative != null;
    final family = option.type == ActionType.mafiaVote && !alternative;
    final alternativeTargets = option.alternativeTargets ?? option.targets;
    final shown = alternative ? NightTask(option.alternative!, alternativeTargets) : task;
    final labels = alternativeLabels(_t, option.alternative);
    final lastWatch = _view.watches.isEmpty ? null : _view.watches.last;
    return (
      key: const Key('online.night'),
      table: _table(
        players: _secretTable(),
        selectable: (alternative ? alternativeTargets : option.targets).toSet(),
        selected: selected,
        onTap: busy ? null : (player) => setState(() => _selected = player),
        votes: family ? _withHope(_view.familyVotes.isNotEmpty ? _view.familyVotes : _lastFamilyVotes) : const [],
        voteColor: Saloon.mafia,
        center: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (option.alternative != null)
              Padding(
                padding: EdgeInsets.only(bottom: 4 * _k),
                child: SizedBox(
                  height: 32 * _k,
                  child: SegmentedButton<bool>(
                    key: const Key('online.alternative'),
                    style: ButtonStyle(
                      visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
                      textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 12 * _k)),
                    ),
                    segments: [
                      ButtonSegment(value: false, label: Text(labels.$1)),
                      ButtonSegment(value: true, label: Text(labels.$2)),
                    ],
                    selected: {_alternative},
                    showSelectedIcon: false,
                    onSelectionChanged: busy
                        ? null
                        : (choice) => setState(() {
                            _alternative = choice.single;
                            // Il fiammifero si accende scegliendo se stessi: già scelto.
                            _selected = _alternative && option.alternativeTargets != null
                                ? alternativeTargets.first
                                : null;
                          }),
                  ),
                ),
              ),
            Flexible(
              child: _felt([
                NightNotes(
                  lastWatch: lastWatch != null && lastWatch.round == _public.round - 1 ? lastWatch : null,
                  doused: _view.doused,
                  bounty: _view.bounty,
                ),
                Text(
                  script.taskPrompt(shown, _public.round),
                  textAlign: TextAlign.center,
                  style: AppText.display(17 * _k, color: family ? const Color(0xFFFFB3B3) : AppColors.textPrimary),
                ),
                SizedBox(height: 4 * _k),
                _feltLine(script.taskHint(shown), size: 12, color: const Color(0xFFD8CCBE)),
              ]),
            ),
          ],
        ),
      ),
      strip: Row(
        children: [
          Expanded(
            flex: 2,
            child: NoirButton(
              key: const Key('online.pass'),
              compact: true,
              kind: NoirButtonKind.brass,
              label: _t.pass,
              onPressed: busy ? null : () => _send(Pass(_view.seat.id)),
            ),
          ),
          SizedBox(width: 10 * _k),
          Expanded(
            flex: 3,
            child: NoirButton(
              key: const Key('online.confirm'),
              compact: true,
              label: selected == null ? _t.confirm : '${_t.confirm} · ${_tag(selected)}',
              onPressed: selected == null || busy
                  ? null
                  : () =>
                        _send(family ? MafiaVote(_view.seat.id, selected.id) : NightAction(_view.seat.id, selected.id)),
            ),
          ),
        ],
      ),
    );
  }

  _Phase _waitingPhase() {
    final view = _view;
    final finding = view.nightChoice != null ? _finding : null;
    final found = finding?.role;
    final isMafia = finding?.team == Team.mafia;
    final pending = _public.phase == GamePhase.night && _public.nightPending > 0
        ? _t.online.waitingForOthers(_public.nightPending)
        : null;
    final Widget center;
    if (finding == null) {
      final status = !view.alive
          ? _t.online.youAreOut
          : view.nightChoice == null
          ? _script('night-${_public.round}').nightFalls(_public.round, online: true).map((l) => l.text).join('\n')
          : _t.online.moveRegistered;
      center = _felt(key: const Key('online.waiting'), [
        _feltLine(
          status,
          key: view.nightChoice != null ? const Key('online.moveRegistered') : null,
          size: 13,
          maxLines: 6,
        ),
        if (view.nightChoice != null) ...[
          const SizedBox(height: 4),
          _feltLine(_t.nobodyWillKnow, size: 11.5, color: Saloon.brass),
        ],
      ]);
    } else {
      center = _felt(key: const Key('online.waiting'), [
        Text(
          found == null ? _t.yourInvestigation : _t.inTheGrave,
          style: AppText.overline.copyWith(color: Saloon.brass, fontSize: AppText.overline.fontSize! * _k),
        ),
        const SizedBox(height: 4),
        Text(_tag(finding.subject).toUpperCase(), style: AppText.display(24 * _k, color: AppColors.textPrimary)),
        const SizedBox(height: 4),
        Text(
          found != null
              ? _t.wasRole(_t.role(found).label)
              : isMafia
              ? _t.isFamily
              : _t.isInnocent,
          textAlign: TextAlign.center,
          style: AppText.display(18 * _k, color: isMafia ? Saloon.mafia : Saloon.clean),
        ),
      ]);
    }
    return (
      key: const Key('online.night'),
      table: _table(players: _secretTable(), selected: finding?.subject, center: center),
      strip: pending == null ? const SizedBox.shrink() : ScrimText(pending),
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

  // ---------------------------------------------------------------------
  // La cronaca: l'alba e il verdetto, solo il racconto, su un giornale.

  bool get _italian => _t.language.locale.languageCode == 'it';

  String get _masthead => _italian ? 'Il Corriere di ${_city.name}' : 'The ${_city.name} Courier';

  String _dateLine(String edition) =>
      _italian ? 'Anno XIX  ·  Giorno ${_public.round}  ·  $edition' : 'Vol. XIX  ·  Day ${_public.round}  ·  $edition';

  List<FrontPageLine> _printed(List<ScriptLine> lines) => [for (final l in lines) (text: l.text, fact: l.isFact)];

  _Phase _waitingPhaseFor(Key key) => (key: key, table: _connectingView(), strip: const SizedBox.shrink());

  _Phase _dawnPhase() {
    final dawn = _public.lastDawn;
    if (dawn == null) return _waitingPhaseFor(const Key('online.dawn'));
    final lines = _script('dawn-${dawn.round}')
        .dawn(dawn, discussion: _board.settings.discussion, stories: _storiesOf(dawn), online: true);
    final (:headline, :dead) = dawnHeadline(dawn, italian: _italian, everyoneAlive: _t.everyoneAlive);
    return (
      key: const Key('online.dawn'),
      strip: _readyButton(compact: true),
      table: _deskPaper(FrontPage(
        key: ValueKey('front-dawn-${dawn.round}'),
        compact: !_deskMode,
        scale: _deskMode ? 1.5 : 1,
        masthead: _masthead,
        dateLine: _dateLine(_italian ? "Edizione dell'alba" : 'Dawn edition'),
        headline: headline,
        kicker: _t.crimePage,
        portraits: dead,
        fallen: dawn.victims.isNotEmpty,
        lines: _printed(lines),
      )),
    );
  }

  /// Sul desktop il giornale non si stira su tutto il tavolo: una pagina
  /// vera, al centro, larga quanto basta per leggerla da lontano.
  Widget _deskPaper(Widget paper) => !_deskMode
      ? paper
      : Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: paper),
          ),
        );

  /// Il verdetto, sul tavolo: tutti hanno appena visto il voto, quindi
  /// niente film. Il posto del condannato fa il linciaggio sul posto e poi
  /// mostra la carta, se la piazza l'ha vista; sopra, il titolo della sera,
  /// il racconto e lo scrutinio in poche righe.
  _Phase _verdictPhase() {
    final report = _public.lastLynch;
    if (report == null) return _waitingPhaseFor(const Key('online.verdict'));
    final condemned = report.condemned;
    final role = report.role;
    final headline = lynchHeadline(report, italian: _italian, tag: _tag, roleLabel: (r) => _t.role(r).label);
    final story = [for (final line in _script('lynch-${report.round}').lynch(report)) line.text].join(' ');
    final tally = [for (final vote in _lastVotes) '${_tag(vote.voter)} → ${_short(vote.target)}'].join('  ·  ');
    final film = _stage == Stage.verdictFilm;
    final into = film ? _client.elapsed : LynchMark.length;
    return (
      key: const Key('online.verdict'),
      table: _table(
        players: publicSeating(_public.seats),
        // Le mani del voto restano puntate finché il linciaggio non finisce.
        votes: _lastVotes,
        lynched: condemned,
        lynchedAt: into < Duration.zero ? Duration.zero : into,
        center: _felt([
          _feltLine(
            headline,
            key: const Key('online.verdictHeadline'),
            size: 15,
            weight: FontWeight.w800,
            color: role == null ? Saloon.brass : Color.lerp(stampColorFor(role), Colors.white, 0.45)!,
            maxLines: 3,
          ),
          if (story.isNotEmpty) ...[
            const SizedBox(height: 4),
            _feltLine(story, key: const Key('online.verdictStory'), size: 12, maxLines: 5),
          ],
        ]),
      ),
      strip: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (tally.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(bottom: 4 * _k),
              child: Text(
                tally,
                key: const Key('online.verdictVotes'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.body.copyWith(color: Saloon.brass, fontSize: 11.5 * _k),
              ),
            ),
          if (!film) _readyButton(compact: true),
        ],
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

  _Phase _discussionPhase() => (
    key: const Key('online.discussion'),
    table: _table(
      players: publicSeating(_public.seats),
      center: _felt([_feltLine(_t.online.discussionHint, size: 12.5, maxLines: 5)]),
    ),
    strip: _readyButton(compact: true),
  );

  _Phase _votePhase() {
    final view = _view;
    final option = view.action;
    final votes = _withHope(_public.dayVotes);
    final mine = [
      for (final vote in votes)
        if (vote.voter == view.seat) vote,
    ].firstOrNull;
    final canVote = option != null && _open && !_client.busy;
    final selected = mine?.target;
    final cast = votes.length;
    final alive = _public.alive.length;
    return (
      key: const Key('online.vote'),
      table: _table(
        players: publicSeating(_public.seats),
        selectable: canVote
            ? {
                for (final p in option.targets)
                  if (p != selected) p,
              }
            : const {},
        selected: selected,
        onTap: (player) => _send(DayVote(view.seat.id, player.id)),
        votes: votes,
        center: _felt([
          _feltLine(view.alive ? _t.online.voteHint : _t.online.youAreOut, size: 12.5, maxLines: 4),
          if (_public.mayor case final mayor?) ...[
            const SizedBox(height: 4),
            _feltLine(
              _t.pack.mayorRevealed.replaceAll('{name}', _tag(mayor)),
              key: const Key('online.mayor'),
              color: Saloon.brass,
              size: 12.5,
              weight: FontWeight.w700,
            ),
          ],
        ]),
      ),
      strip: Container(
        padding: _deskMode ? const EdgeInsets.fromLTRB(24, 10, 10, 10) : const EdgeInsets.fromLTRB(12, 6, 6, 6),
        decoration: Saloon.scrim(radius: 12 * _k),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(Icons.how_to_vote, size: 14 * _k, color: cast > 0 ? Saloon.blood : const Color(0xFF4A423C)),
                      SizedBox(width: 6 * _k),
                      Flexible(
                        child: Text(
                          _t.online.votesCast(cast, alive),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.overline.copyWith(color: AppColors.textPrimary, fontSize: 11 * _k),
                        ),
                      ),
                    ],
                  ),
                  if (mine != null)
                    Text(
                      mine.target == null ? _t.online.abstained : _t.online.votedFor(_tag(mine.target!)),
                      key: const Key('online.myVote'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body.copyWith(color: Saloon.brass, fontSize: 13 * _k, fontWeight: FontWeight.w700),
                    ),
                ],
              ),
            ),
            if (option != null && option.canReveal) ...[
              SizedBox(width: 6 * _k),
              NoirButton(
                key: const Key('online.revealMayor'),
                compact: true,
                label: _t.revealAsMayor,
                onPressed: canVote ? () => _send(RevealMayor(view.seat.id)) : null,
              ),
            ],
            if (option != null) ...[
              SizedBox(width: 6 * _k),
              NoirButton(
                key: const Key('online.abstain'),
                compact: true,
                kind: NoirButtonKind.brass,
                label: _t.online.abstain,
                onPressed: canVote && mine?.target != null || canVote && mine == null
                    ? () => _send(Pass(view.seat.id))
                    : null,
              ),
            ],
          ],
        ),
      ),
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
    final arsonistWon = winner == Team.neutral;
    final roles = _public.finalRoles;
    final players = [
      for (final p in publicSeating(_public.seats))
        if (roles[p] != null) p,
    ];
    return Column(
      key: const Key('online.end'),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: Saloon.scrim(radius: 14, border: mafiaWon ? Saloon.mafia : Saloon.brass),
          child: Column(
            children: [
              Icon(
                mafiaWon ? Icons.theater_comedy : Icons.balance,
                color: mafiaWon ? Saloon.mafia : Saloon.brass,
                size: 40,
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  arsonistWon
                      ? _t.arsonistWins
                      : mafiaWon
                      ? _t.familyWins
                      : _t.townWins,
                  style: Saloon.plate(32, color: mafiaWon ? Saloon.mafia : Saloon.brass),
                ),
              ),
              const SizedBox(height: 4),
              Text(_t.whoWasWho, style: AppText.overline.copyWith(color: AppColors.textPrimary)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) {
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
                              number: _numberOf(player),
                              width: width,
                              fallen: !_isAlive(player),
                              me: player == _view.seat,
                              selected: _public.won(player),
                              note: _t.role(roles[player]!).label,
                              noteColor: roles[player]!.team == Team.mafia ? Saloon.mafia : Saloon.brass,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _public.personalWins.contains(player)
                                  ? '${_t.wonAlone}\n${_fateOf(player)}'
                                  : _fateOf(player),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              style: AppText.body.copyWith(color: const Color(0xFFD8CCBE), fontSize: 11.5, height: 1.2),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        if (_public.recap case final recap?) ...[
          SizedBox(
            width: double.infinity,
            child: NoirButton(
              key: const Key('online.recap'),
              kind: NoirButtonKind.brass,
              label: RecapStrings.of(context).open,
              onPressed: () => showGameRecap(context, recap, me: _view.seat),
            ),
          ),
          const SizedBox(height: 8),
        ],
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
