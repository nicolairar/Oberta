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
import '../../../online/voice/voice_controller.dart';
import '../../../rules/game_engine.dart';
import '../../../rules/intent.dart';
import '../../../rules/knowledge.dart';
import '../../../rules/player.dart';
import '../../../rules/player_view.dart';
import '../../../rules/role.dart';
import '../../../sound/cue_sounds.dart';
import '../../../sound/sound_stage.dart';
import '../../press.dart';
import '../../seating.dart';
import '../../theme/app_theme.dart';
import '../../theme/role_style.dart';
import '../../widgets/death_scene.dart';
import '../../widgets/night_notes.dart' show alternativeLabels;
import '../../widgets/scene_scaffold.dart';
import '../../widgets/content_width.dart';
import '../../widgets/roles_panel.dart';
import '../../widgets/wide_scale.dart';
import '../../widgets/lynch_mark.dart';
import '../../../l10n/local_role_strings.dart';
import '../../../l10n/table_strings.dart';
import '../../../l10n/player_gender.dart';
import '../../../l10n/safety_strings.dart';
import '../../../l10n/voice_strings.dart';
import 'game/action_strip.dart';
import 'game/chat_dock.dart';
import 'game/chronicle_headlines.dart';
import 'game/felt_text.dart';
import 'game/front_page.dart';
import 'game/noir_role_card.dart';
import 'game/noir_ui.dart';
import 'game/saloon_table.dart';
import 'game/gesture_picker.dart';
import 'game/saloon_transitions.dart';
import 'game/seat_card.dart';
import 'game/verdict_line.dart';
import 'online_widgets.dart';
import 'recap_screen.dart';
import '../../../l10n/recap_strings.dart';
import 'safety_sheets.dart';
import 'voice/voice_dock.dart';
import '../../../l10n/roles_sheet_strings.dart';
import '../../widgets/roles_sheet.dart';
import '../../widgets/noir_modal.dart';
import '../../widgets/noir_notice.dart';
import '../../widgets/targa.dart';

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

  /// Il conto alla rovescia in alto. La mano di prova lo spegne: lì non
  /// corre nessuno.
  final bool showClock;

  /// Nell'angolo in alto a destra, quando l'orologio è spento (la mano di
  /// prova ci mette «salta»).
  final Widget? corner;

  const OnlineGameScreen({
    super.key,
    required this.services,
    required this.room,
    required this.me,
    this.seating,
    this.clock = const SystemGameClock(),
    this.showClock = true,
    this.corner,
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

  /// La voce al tavolo: chi parla e chi ascolta lo decide il server, fase
  /// per fase (Edge Function voice-token). La stessa della stanza sotto.
  late final VoiceDirectory _voiceSeats = (
    profileOf: (String id) => _client.board?.seating.occupantOf(id)?.profileId,
    nameOf: (String id) => _client.board?.seating.occupantOf(id)?.name,
  );
  late final VoiceController? _voice = switch (widget.services.voice) {
    final source? => VoiceController.acquire(source, widget.room.id, directory: _voiceSeats),
    null => null,
  };

  /// Chi si sente nella voce: segnalarlo o bloccarlo, come dal suo posto.
  void _voicePerson(String seat) {
    final player = _client.board?.view.seats.where((p) => p.id == seat).firstOrNull;
    if (player != null) _seatSheet(player);
  }

  /// Questo posto è morto, a partita in corso: ascolta soltanto.
  bool get _deadHere => _client.ready && _client.seat != null && !_view.alive && _stage != Stage.ended;

  String get _voiceKey => '${_client.schedule?.key}|${_client.seat?.view.alive}';
  late final Random _shuffle = widget.seating ?? Random();
  Timer? _ticker;

  /// Su PC: il menu di Esc è aperto (la partita intanto va avanti).
  bool _paused = false;
  late final DesktopGameStrings _dt = DesktopGameStrings(widget.room.language.app);
  final FocusNode _chatFocus = FocusNode(debugLabel: 'online.chat');

  /// Questo build è sulla tela desktop coricata.
  bool _deskMode = false;

  /// Quanto crescono le parole sul panno e nella striscia sul desktop.
  double get _k => _deskMode ? 1.55 : 1.0;

  late final TableStrings _ts = TableStrings(widget.room.language.app);

  /// La mossa appena fatta, mostrata subito (mano, pizzino) mentre viaggia:
  /// il server poi la conferma (resta) o la rifiuta (la mano torna indietro).
  /// `target` null: astensione. [family]: è un voto dell'agguato.
  ({Player? target, String stage, bool family})? _hope;

  /// Il Sarto ha scelto di cucire invece di votare l'agguato (il Piromane
  /// di accendere). Null: come dice la scelta già registrata.
  bool? _alternative;

  /// Il Pacifista sta scegliendo chi svelare.
  bool _pacifying = false;

  /// L'Artigliere sta scegliendo chi colpire.
  bool _aiming = false;

  /// Quanti colpi dell'Artigliere si sono già sentiti su questo telefono.
  int? _shotsHeard;

  /// La domanda aperta prima di un'indagine o di uno scavo: si chiude da
  /// sola se la notte finisce prima della risposta.
  BuildContext? _asking;

  /// Di giorno, con un Compare vivo, la famiglia guarda la sua chat.
  bool _familyTab = false;

  /// Di notte, un innamorato della Famiglia guarda la chat degli innamorati.
  bool _loversTab = false;

  /// Cupido ha toccato il primo innamorato, e aspetta il secondo.
  Player? _firstLover;
  List<Player> _secret = const [];
  String? _secretTurn;
  bool _cardTurned = false;

  /// Quello che l'ultima mossa ha scoperto (un'indagine, una fossa).
  Exposure? _finding;
  String? _findingFor;

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

  /// I gesti del tavolo arrivati da quando si è seduti (quelli di prima non
  /// volano più), i gesti comprati e quando si può lanciare il prossimo.
  StreamSubscription<List<TableReaction>>? _gestureFeed;
  int? _gestureFloor;
  List<TableReaction> _gestures = const [];
  Set<TableGesture> _ownedGestures = const {};
  DateTime _nextGesture = DateTime.fromMillisecondsSinceEpoch(0);

  void _watchGestures() {
    final reactions = widget.services.reactions;
    if (reactions == null) return;
    reactions.owned().then((owned) {
      if (mounted) setState(() => _ownedGestures = owned);
    }, onError: (_) {});
    _gestureFeed = reactions.watch(widget.room.id).listen((rows) {
      if (!mounted) return;
      final floor = _gestureFloor ??= rows.fold<int>(0, (top, r) => max(top, r.id));
      final fresh = [for (final r in rows) if (r.id > floor) r];
      setState(() => _gestures = fresh.length > 12 ? fresh.sublist(fresh.length - 12) : fresh);
    }, onError: (_) {});
  }

  /// Di giorno, fra vivi, verso un altro posto.
  bool _canGesture(Player player) =>
      widget.services.reactions != null &&
      (_stage == Stage.discussion || _stage == Stage.vote) &&
      player != _view.seat &&
      _isAlive(player) &&
      _isAlive(_view.seat);

  /// Il foglio di chi siede in [player]: solo quello che si vede adesso
  /// (il posto, se è al tavolo, caduto o assente), mai il ruolo.
  void _seatSheet(Player player) {
    if (player == _view.seat) return;
    final s = SafetyStrings.of(context);
    final silenced = _public.lastDawn?.silenced == player && _public.lastDawn?.round == _public.round;
    showSeatActions(
      context,
      services: widget.services,
      name: player.name,
      myId: widget.me.id,
      profileId: _client.board?.seating.occupantOf(player.id)?.profileId,
      voice: voiceMuteFor(context, _voice, player.id),
      seat: switch (_numberOf(player)) { final n? => s.seat(n), null => null },
      status: !_isAlive(player)
          ? s.outOfGame
          : _offline(player)
          ? _t.online.offlineBadge
          : silenced
          ? _ts.silenced(PlayerGenders.of(player.name))
          : s.atTable,
    );
  }

  /// Tenuto premuto: di giorno fra vivi i gesti (col foglio a un tocco),
  /// altrimenti il foglio del giocatore.
  void _seatHeld(Player player) {
    if (!_canGesture(player)) {
      _seatSheet(player);
      return;
    }
    _throwGesture(player, onReport: widget.services.safety == null ? null : () => _seatSheet(player));
  }

  void _throwGesture(Player player, {VoidCallback? onReport}) {
    final wait = _nextGesture.difference(DateTime.now());
    showGesturePicker(
      context,
      name: player.name,
      language: _t.language,
      owned: _ownedGestures,
      wait: wait.isNegative ? Duration.zero : wait,
      onReport: onReport,
      voice: voiceMuteFor(context, _voice, player.id),
    ).then((gesture) async {
      if (gesture == null || !mounted) return;
      HapticFeedback.selectionClick();
      _nextGesture = DateTime.now().add(ReactionRules.cooldown);
      try {
        await widget.services.reactions!.send(widget.room.id, player.id, gesture);
      } catch (error) {
        if (mounted) showFailure(context, error);
      }
    });
  }

  /// Di giorno, da vivi: il bottone dei gesti accanto alla chat.
  bool get _gesturesOpen =>
      widget.services.reactions != null && (_stage == Stage.discussion || _stage == Stage.vote) && _isAlive(_view.seat);

  Widget? _gestureButton() =>
      _gesturesOpen ? GestureButton(language: _t.language, desk: _deskMode, onTap: _pickGestureTarget) : null;

  /// Dal bottone: prima a chi, poi quale gesto.
  Future<void> _pickGestureTarget() async {
    final seats = _public.seats;
    final targets = [
      for (var i = 0; i < seats.length; i++)
        if (_canGesture(seats[i])) (player: seats[i], number: i + 1, name: seats[i].name),
    ];
    if (targets.isEmpty) return;
    final player = await showGestureTargetPicker<Player>(context, language: _t.language, targets: targets);
    if (player == null || !mounted || !_canGesture(player)) return;
    _throwGesture(player);
  }

  /// Il primo giorno in assoluto, un suggerimento discreto sui gesti.
  void _hintGestures() {
    if (!_gesturesOpen) return;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    GestureHint.claim().then((first) {
      if (first && overlay != null) showNoticeIn(overlay, GestureStrings(_t.language).firstHint);
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    RecapShelf.last = null;
    _client;
    _voice?.listenOnly = _deadHere;
    _voice?.phase(_voiceKey);
    _watchGestures();
    MemeDirector.attach(_client, alive: () => mounted);
    // Il cronometro, l'inizio dei film e la fine delle fasi.
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _gestureFeed?.cancel();
    _chatFocus.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _client.removeListener(_changed);
    _client.dispose();
    _voice?.release(directory: _voiceSeats);
    SoundStage.instance.ambience(null);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Di ritorno dallo sfondo il collegamento può essersi perso: ci si
    // risiede, e il server ridà subito il tavolo com'è adesso.
    // Sempre: lo sfondo può aver lasciato il server senza notizie (e gli
    // altri ci vedono assenti) anche se qui sembra tutto a posto.
    if (state == AppLifecycleState.resumed) {
      _rejoin();
      _voice?.refresh();
    }
  }

  /// Rientra al tavolo: accesso rinnovato, tempo reale riaperto, un «ci
  /// sono» subito e la partita riletta com'è adesso (vedi [GameClient.rejoin]).
  void _rejoin() => _client.rejoin();

  OnlineBoard get _board => _client.board!;
  PlayerView get _view => _client.seat!.view;
  PublicView get _public => _board.view;
  StageWindow? get _window => _client.board?.schedule;
  Stage get _stage => _window?.stage ?? Stage.ended;

  void _changed() {
    if (!mounted) return;
    // Morto (linciato, ucciso, colpito di giorno): la parola se ne va
    // adesso, nello stesso istante in cui il telefono lo sa.
    _voice?.listenOnly = _deadHere;
    _voice?.phase(_voiceKey);
    if (_client.takeRejection() != null) showNote(context, _t.online.rejected, kind: NoticeKind.error);
    if (!_client.busy) _hope = null;
    final seat = _client.seat;
    if (seat?.receipt case (:final token?, result: IntentAccepted(:final finding?)) when token != _findingFor) {
      _findingFor = token;
      _finding = finding;
    }
    if (_client.ready) {
      if (_stage == Stage.vote) _lastVotes = _public.dayVotes;
      if (_stage == Stage.night && _view.familyVotes.isNotEmpty) _lastFamilyVotes = _view.familyVotes;
      if (_stage == Stage.discussion) _lastFamilyVotes = const [];
      _enterStage();
      _announceDepartures();
      _hearCannon();
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
    _hope = null;
    _alternative = null;
    // Una domanda rimasta aperta della fase di prima non vale più.
    if (_asking case final asking? when asking.mounted) Navigator.of(asking).pop(false);
    _asking = null;
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
        _hintGestures();
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

  /// Il colpo dell'Artigliere: il boato lo sente tutta la città, e poi la
  /// carta del colpito si gira.
  void _hearCannon() {
    final shots = _public.shots;
    final heard = _shotsHeard;
    _shotsHeard = shots.length;
    if (heard == null || shots.length <= heard) return;
    final stage = SoundStage.instance;
    stage.cue(Cue.bang);
    stage.cue(shots.last.role.team == Team.mafia ? Cue.caught : Cue.innocent);
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
    if (key != null && intent is! RevealMayor && intent is! Pacify && intent is! Link && intent is! Fire && intent is! Shoot) {
      final family = _view.action?.type == ActionType.mafiaVote;
      final hope = switch (intent) {
        DayVote(:final target) || NightAction(:final target) => (target: _seatOf(target), stage: key, family: false),
        MafiaVote(:final target) => (target: _seatOf(target), stage: key, family: true),
        Pass() || RevealMayor() || Pacify() || Link() || Fire() || Shoot() => (target: null, stage: key, family: family),
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

  /// I voti del server con, al posto del proprio, la mossa appena fatta. Di
  /// notte, fra i voti della famiglia: [family] (il Sarto che cuce non vota).
  List<SeatVote> _withHope(List<SeatVote> votes, {bool? family}) {
    final hope = _hope;
    if (hope == null || hope.stage != _window?.key) return votes;
    final mine = family == null || hope.family == family;
    return [
      for (final vote in votes)
        if (vote.voter != _view.seat) vote,
      if (mine) (voter: _view.seat, target: hope.target),
    ];
  }

  /// La scelta di stanotte, com'è adesso: quella appena mandata, se c'è,
  /// altrimenti quella che il server ha registrato. [made]: c'è una scelta
  /// (anche «passo»).
  ({bool made, Player? target}) get _nightPick {
    final hope = _hope;
    if (hope != null && hope.stage == _window?.key) return (made: true, target: hope.target);
    final choice = _view.nightChoice;
    return (made: choice != null, target: choice?.target);
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
    // Senza tavolo (ancora in collegamento, o un tavolo che questa build non
    // sa leggere) si esce lo stesso: mai leggere tavolo o vista qui.
    final ready = _client.ready;
    if (ready && (_stage == Stage.ended || _board.abandoned)) {
      Navigator.of(context).pop();
      return;
    }
    final alive = !ready || _view.alive;
    if (_deskMode) {
      final leave = await confirmDeskLeave(
        context,
        title: _t.leaveQuestion,
        body: alive ? _t.online.leaveAbandonWarning : _t.online.leaveDeadWarning,
      );
      if (!leave || !mounted) return;
      setState(() => _paused = false);
      unawaited(widget.services.game.leaveGame(widget.room.id).catchError((Object _) {}));
      Navigator.of(context).pop();
      return;
    }
    final leave = await confirmNoir(
      context,
      key: const Key('online.leaveDialog'),
      title: _t.leaveQuestion,
      body: alive ? _t.online.leaveAbandonWarning : _t.online.leaveDeadWarning,
      icon: Icons.door_back_door_outlined,
      danger: true,
      cancel: _t.stay,
      confirm: _t.leave,
      cancelKey: const Key('online.leave.stay'),
      confirmKey: const Key('online.leave.confirm'),
    );
    if (!leave || !mounted) return;
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
    final showClock = widget.showClock && ready && _stage != Stage.ended && !_board.abandoned;
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
            child: Stack(
              children: [
                Column(
                  children: [
                    StageHeader(
                      title: ready ? _title() : widget.room.code,
                      ribbon: ready && !_board.abandoned ? _ribbon() : null,
                      countdown: showClock ? (_beforeStart ? '…' : _clock(left)) : null,
                      urgent: showClock && !_beforeStart && left < const Duration(seconds: 10) && _stage.acceptsActions,
                      leading: HeaderIconButton(
                        icon: Icons.close,
                        tooltip: _t.leaveTooltip,
                        onPressed: pressed(_confirmExit, Press.back),
                      ),
                      action: ready
                          ? HeaderIconButton(
                              key: const Key('rolesSheet.button'),
                              icon: Icons.style,
                              tooltip: RolesSheetStrings.of(context).title,
                              onPressed: pressed(
                                () => RolesSheet.show(context, deck: _public.deck, revealed: publicReveals(_public)),
                                Press.card,
                              ),
                            )
                          : null,
                      corner: widget.corner,
                    ),
                    Expanded(
                      child: _inlineChat
                          ? _gamePage()
                          : ContentWidth(
                              maxWidth: 780,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                                child: AnimatedSwitcher(
                                  duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : phaseFade,
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
                // Il collegamento che non va: un cartello sopra il tavolo,
                // così sotto non si sposta niente.
                if (_connectionBanner() case final banner?)
                  Positioned(left: 0, right: 0, top: StageHeader.height, child: ContentWidth(maxWidth: 780, child: banner)),
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
      final showClock = widget.showClock && ready && _stage != Stage.ended && !_board.abandoned;
      final side = ready && !_board.abandoned;
      page = Scaffold(
        backgroundColor: Saloon.ink,
        body: SaloonBackdrop(
          night: night,
          child: Stack(
            children: [
              Column(
            children: [
              DeskGameHud(
                title: ready ? _title() : widget.room.code,
                ribbon: ready && !_board.abandoned ? _ribbon() : null,
                countdown: showClock ? (_beforeStart ? '…' : _clock(left)) : null,
                urgent: showClock && !_beforeStart && left < const Duration(seconds: 10) && _stage.acceptsActions,
                onMenu: _openPause,
                strings: _dt,
                corner: widget.corner,
              ),
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
              if (_connectionBanner() case final banner?)
                Positioned(left: 0, right: 0, top: DeskGameHud.height, child: banner),
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
                      onRoles: () {
                        if (_client.ready) RolesSheet.show(context, deck: _public.deck, revealed: publicReveals(_public));
                      },
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
        return _withTalk(
          desk: true,
          expand: true,
          KeyedSubtree(
            key: phase.key,
            child: Column(
              children: [
                Expanded(
                  child: SizedBox(key: const Key('game.tableSlot'), width: double.infinity, child: phase.table),
                ),
                _stripSlot(phase, desk: true, maxWidth: 860),
              ],
            ),
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
                      trailing: _chatTrailing(),
                      tabs: _chatTabs(now.view),
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
        const SizedBox(height: 16),
        SizedBox(width: 860, child: _cardStrip()),
      ],
    );
  }

  /// Sotto la carta: girala, poi «pronto», poi si aspettano gli altri.
  Widget _cardStrip() => ActionStrip(
    status: !_cardTurned ? _ts.holdTheCard : _readyStatus(_t.online.yourCardHint),
    tone: !_cardTurned ? StripTone.act : _readyTone,
    actions: [?_readyAction(enabled: _cardTurned)],
  );

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
                            role: roles[player],
                            noteColor: roles[player]!.team == Team.mafia ? Saloon.mafia : Saloon.brass,
                            onTap: player == _view.seat ? null : () => _seatSheet(player),
                            onLongPress: player == _view.seat ? null : () => _seatSheet(player),
                          ),
                          const SizedBox(height: 12),
                          _castLine(player, roles[player]!),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(width: 640, child: NoirActions(actions: _endActions())),
      ],
    );
  }

  /// Sotto ogni posto, alla fine: il ruolo che aveva e com'è finita.
  Widget _castLine(Player player, Role role) {
    final m = NoirMetrics(_deskMode);
    final fate = _public.personalWins.contains(player) ? '${_t.wonAlone} · ${_fateOf(player)}' : _fateOf(player);
    return Column(
      children: [
        Text(
          _t.role(role).label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: role.team == Team.mafia ? Saloon.mafia : AppColors.textPrimary,
            fontSize: m.body,
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
        ),
        Text(
          fate,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: AppColors.textSecondary, fontSize: m.small + 0.5, height: 1.3),
        ),
      ],
    );
  }

  /// I pulsanti della fine: il resoconto (se c'è) e l'uscita.
  List<NoirAction> _endActions() => [
    if (_public.recap case final recap?)
      NoirAction(
        key: const Key('online.recap'),
        label: RecapStrings.of(context).open,
        feel: Press.card,
        onPressed: () => showGameRecap(context, recap, me: _view.seat),
      ),
    NoirAction(
      key: const Key('online.backToRoom'),
      label: _ts.leave,
      style: NoirButtonStyle.primary,
      feel: Press.confirm,
      onPressed: () => Navigator.of(context).pop(),
    ),
  ];

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
    final m = NoirMetrics(_deskMode);
    return Container(
      margin: _deskMode
          ? const EdgeInsets.fromLTRB(DeskSize.gutter, 0, DeskSize.gutter + _deskSideWidth + 36, 10)
          : const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: _deskMode ? const EdgeInsets.fromLTRB(24, 8, 8, 8) : const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: Saloon.scrim(radius: 12, border: Saloon.blood),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              key: key,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppColors.textPrimary, fontSize: m.body, height: 1.3),
            ),
          ),
          if (rejoin) ...[
            SizedBox(width: m.gap),
            NoirModalButton(
              key: const Key('online.reconnect'),
              action: NoirAction(label: _ts.rejoin, feel: Press.confirm, onPressed: _rejoin),
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

  /// La fase sotto il titolo, come una frase: «Il voto della piazza».
  String? _ribbon() => switch (_stage) {
    Stage.reveal => _city.title,
    Stage.discussion => _sentence(_t.online.discussionTitle),
    Stage.vote => _sentence(_t.online.voteTitle),
    _ => null,
  };

  static String _sentence(String text) =>
      text.isEmpty ? text : text[0].toUpperCase() + text.substring(1).toLowerCase();

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

  Widget _connectingView() => _client.unreadable
      ? DealingTable(
          key: const Key('online.unreadable'),
          status: _t.online.updateServer,
          below: NoirModalButton(
            key: const Key('online.unreadable.leave'),
            action: NoirAction(
              label: _ts.leave,
              style: NoirButtonStyle.primary,
              feel: Press.back,
              onPressed: _confirmExit,
            ),
          ),
        )
      : _client.error == null
      ? DealingTable(status: _t.online.gameConnecting)
      : DealingTable(
          status: _t.online.connectionLost,
          below: NoirModalButton(
            key: const Key('online.reconnect'),
            action: NoirAction(
              label: _ts.rejoin,
              style: NoirButtonStyle.primary,
              feel: Press.confirm,
              onPressed: _rejoin,
            ),
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
      NoirActions(
        actions: [
          NoirAction(
            label: _ts.leave,
            style: NoirButtonStyle.primary,
            feel: Press.confirm,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    ],
  );

  /// «Pronto»: la conferma della fase. Chi è fuori dal gioco non conferma
  /// niente (il server non lo aspetta): per lui nessun pulsante.
  NoirAction? _readyAction({bool enabled = true}) => !_view.alive
      ? null
      : NoirAction(
          key: const Key('online.ready'),
          label: _t.online.ready,
          style: NoirButtonStyle.primary,
          feel: Press.confirm,
          // Niente «invio…» né «registrato»: si vede solo se qualcosa va storto.
          onPressed: _acked || !enabled || !_open ? null : _ack,
        );

  /// La riga della striscia nelle fasi da confermare: [todo] finché non si
  /// è confermato, poi l'attesa degli altri; da morti, si guarda soltanto.
  String _readyStatus(String todo) => !_view.alive
      ? _t.online.youAreOut
      : _acked
      ? _t.online.readyWaiting
      : todo;

  StripTone get _readyTone => !_view.alive
      ? StripTone.out
      : _acked
      ? StripTone.wait
      : StripTone.act;

  // ---------------------------------------------------------------------
  // La chat, sempre in fondo.

  /// Stanotte questo posto è nella cella: il Carceriere o il prigioniero.
  bool get _inJailChat {
    final cell = _view.cell;
    return _stage.chat == 'night' && _view.alive && cell != null && (cell == _view.seat || _view.role == Role.carceriere);
  }

  /// La setta: il convertito sa solo di esserlo; il Capo vede chi c'è, e
  /// l'ultima porta rimasta chiusa.
  List<String> get _sectNotes => [
    if (_view.converted) _ts.converted,
    if (_view.sect.isNotEmpty) _ts.sectLine(_view.sect.map(_tag).join(', ')),
    if (_view.doors.isNotEmpty && _view.doors.last.round == _public.round - 1) _ts.doorClosed(_tag(_view.doors.last.target)),
  ];

  /// Gli innamorati, per chi li conosce: Cupido vede la coppia, ognuno dei
  /// due il nome dell'altro.
  List<String> get _loverNotes {
    final lovers = _view.lovers;
    if (lovers.length != 2) return const [];
    if (lovers.contains(_view.seat)) {
      return [_ts.inLoveWith(_tag(lovers.firstWhere((p) => p != _view.seat)))];
    }
    return [_ts.loversLine(_tag(lovers.first), _tag(lovers.last))];
  }

  /// Stanotte gli innamorati, vivi tutti e due, si scrivono.
  bool get _inLoversChat =>
      _stage.chat == 'night' &&
      _view.alive &&
      _view.lovers.contains(_view.seat) &&
      _view.lovers.every(_public.alive.contains) &&
      _view.cell != _view.seat;

  ChatChannelView _chatView() {
    if (_inJailChat) {
      return ChatChannelView(channel: ChatChannel.jail, title: _ts.jailChat, accent: Saloon.brass);
    }
    // Un innamorato della Famiglia sceglie quale chat guardare.
    if (_inLoversChat && (!_inFamilyChat || _loversTab)) {
      return ChatChannelView(channel: ChatChannel.lovers, title: _ts.loversChat, accent: const Color(0xFFE58AB0));
    }
    final familyNight = _stage.chat == 'night' && _inFamilyChat;
    // Di giorno, con un Compare vivo, la famiglia sceglie quale chat guardare.
    final familyDay = _stage.chat == 'day' && _view.familyChat && _familyTab;
    if (familyNight || familyDay) {
      return ChatChannelView(channel: ChatChannel.family, title: _t.online.chatFamily, accent: Saloon.mafia);
    }
    // Chiusa: di notte la piazza tace; all'alba e al verdetto si aspetta la
    // discussione; alla fine non si parla più.
    final note = switch (_stage) {
      _ when _stage.chat == 'day' => _townChatNote,
      Stage.reveal || Stage.night => _t.online.chatNightClosed,
      Stage.ended => _ts.chatOver,
      _ => _ts.chatOpensLater,
    };
    return ChatChannelView(channel: ChatChannel.day, title: _t.online.chatTown, accent: Saloon.brass, note: note);
  }

  ({ChatChannelView view, List<ChatMessage> messages}) _chatNow() {
    final view = _chatView();
    return (
      view: view,
      messages: [
        // The server's lines show in every chat of the game.
        for (final m in _client.chat)
          if (m.channel == view.channel || m.channel == ChatChannel.event) _signed(m),
      ],
    );
  }

  /// In cella il Carceriere non ha nome: le sue righe si firmano «Il
  /// Carceriere», e per lui sono le sue.
  ChatMessage _signed(ChatMessage m) => !m.fromJailer
      ? m
      : ChatMessage(
          id: m.id,
          n: m.n,
          channel: m.channel,
          profileId: _view.role == Role.carceriere ? widget.me.id : '',
          seat: null,
          name: _ts.jailer,
          body: m.body,
          at: m.at,
          thread: m.thread,
        );

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
      trailing: _dockTrailing(),
    );
  }

  /// Nella striscia della chat: i gesti di giorno, e la voce.
  Widget? _dockTrailing() {
    final gestures = _gestureButton();
    final voice = _voice;
    final dock = voice == null ? null : VoiceDock(controller: voice, onPerson: _voicePerson);
    if (gestures == null) return dock;
    return Row(mainAxisSize: MainAxisSize.min, children: [?dock, Padding(padding: const EdgeInsets.only(left: 4), child: gestures)]);
  }

  /// In testa alla chat, accanto alle linguette: la voce e i gesti.
  Widget? _chatTrailing() {
    final gestures = _gestureButton();
    final voice = _voice;
    final items = [
      if (voice != null) VoiceDock(controller: voice, onPerson: _voicePerson),
      if (gestures != null) Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: gestures),
    ];
    if (items.isEmpty) return null;
    if (items.length == 1) return items.single;
    return Row(mainAxisSize: MainAxisSize.min, children: items);
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
  Set<String>? _mentionSeen;

  void _feelMentions() {
    final chat = _client.chat;
    if (chat.isEmpty) return;
    final seen = _mentionSeen;
    _mentionSeen = {for (final m in chat) m.id};
    if (seen == null) return;
    final seats = _chatSeats;
    final caller =
        chat.where((m) => !seen.contains(m.id) && seats.calls(m, mine: m.profileId == widget.me.id)).lastOrNull;
    if (caller != null) {
      HapticFeedback.lightImpact();
      showNote(context, RecapStrings.of(context).calledOut(caller.name), kind: NoticeKind.mention);
    }
  }

  /// La striscia dei comandi tra il tavolo e la chat, sempre alta uguale.
  /// Col microfono scelto lascia a destra il posto al pulsante per parlare.
  Widget _stripSlot(_Phase phase, {required bool desk, required double maxWidth}) {
    final strip = Center(
      child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: phase.strip),
    );
    final voice = _voice;
    return SizedBox(
      key: const Key('game.stripSlot'),
      height: ActionStrip.heightFor(desk: desk),
      width: double.infinity,
      child: voice == null
          ? strip
          : ListenableBuilder(
              listenable: voice,
              child: strip,
              builder: (context, strip) => Padding(
                padding: EdgeInsets.only(
                  right: VoiceTalkButton.shows(voice) ? VoiceTalkButton.widthFor(desk: desk) + (desk ? 24 : 8) : 0,
                ),
                child: strip,
              ),
            ),
    );
  }

  /// Il pulsante grande per parlare, a destra della striscia: sopra la
  /// pagina della fase e fuori dalla sua dissolvenza, così lo si può tenere
  /// premuto mentre la fase cambia senza perderlo.
  Widget _withTalk(Widget page, {required bool desk, bool expand = false}) {
    final voice = _voice;
    if (voice == null) return page;
    return Stack(
      fit: expand ? StackFit.expand : StackFit.loose,
      children: [
        page,
        Positioned(
          right: 0,
          bottom: 0,
          height: ActionStrip.heightFor(desk: desk),
          child: Align(
            widthFactor: 1,
            child: VoiceTalkButton(controller: voice, reason: _voiceWhy),
          ),
        ),
      ],
    );
  }

  /// Perché adesso non si parla, dalla fase e dal proprio posto (le regole
  /// le applica il server: qui solo le parole).
  String? _voiceWhy(VoiceStrings t) {
    if (!_client.ready || _client.seat == null) return null;
    final alive = _view.alive;
    return switch (_stage) {
      Stage.night when alive && _view.cell == _view.seat => t.jailed,
      _ when !alive && _stage != Stage.ended => t.deadListen,
      Stage.night when _inFamilyChat => null,
      Stage.night => t.nightFamily,
      // Il voto si fa in silenzio: nessuno fa rumore per rovinarlo.
      Stage.vote || Stage.verdictFilm || Stage.verdict => t.voteSilence,
      Stage.discussion when _view.silenced => t.sewn,
      Stage.discussion => null,
      _ => t.nobodyNow,
    };
  }

  /// Su schermo largo la chat è una colonna a destra, larga così.
  static const _wideChatWidth = 300.0;

  /// Il tavolo: la stessa altezza in ogni fase, poco più di un terzo dello
  /// schermo, così la chat resta grande.
  double get _tableHeight => (_media.size.height * 0.38).clamp(200.0, 330.0);

  /// Il tavolo del telefono in piedi: basso e stretto, il panno non basta
  /// per le frasi lunghe (il verdetto va nella striscia).
  bool get _narrowTable => !_deskMode && !WideScale.isWide(_media.size);

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
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: ChatLog(
        view: now.view,
        messages: now.messages,
        myId: widget.me.id,
        labels: ChatLabels(hint: _t.online.chatHint, empty: _t.online.chatEmpty, send: _t.online.chatSend),
        onSend: (body) => _client.sendChat(_chatView().channel, body),
        seats: _chatSeats,
        onHold: _holdMessage,
        trailing: _chatTrailing(),
        tabs: _chatTabs(now.view),
      ),
    );
    final bottom = typing ? 8.0 : max(_media.viewPadding.bottom - 8, 8.0);
    if (WideScale.isWide(_media.size)) {
      return Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, bottom),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _withTalk(
                desk: false,
                expand: true,
                _phaseSwitch(KeyedSubtree(
                  key: phase.key,
                  child: Column(
                    children: [
                      Expanded(
                        child: SizedBox(key: const Key('game.tableSlot'), width: double.infinity, child: phase.table),
                      ),
                      _stripSlot(phase, desk: false, maxWidth: 560),
                    ],
                  ),
                )),
              ),
            ),
            const SizedBox(width: 16),
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          if (!typing)
            _withTalk(
              desk: false,
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
                    _stripSlot(phase, desk: false, maxWidth: 560),
                  ],
                ),
              )),
            ),
          if (!typing) const SizedBox(height: 8),
          Expanded(
            child: SizedBox(key: const Key('game.chatSlot'), width: double.infinity, child: chatBox),
          ),
          SizedBox(height: bottom),
        ],
      ),
    );
  }

  /// Quanti messaggi di ogni chat si sono già visti: le linguette contano
  /// gli altri.
  final _seenChat = <ChatChannel, int>{};

  /// Le linguette della chat, per chi ha anche la famiglia: la piazza e la
  /// famiglia, coi non letti. Di giorno, con un Compare vivo, si sceglie; se
  /// no apre quella della fase e l'altra resta spenta.
  List<ChatTab>? _chatTabs(ChatChannelView view) {
    // Di notte, un innamorato della Famiglia: la Famiglia o l'innamorato.
    if (_inLoversChat && _inFamilyChat) return _loversTabs(view);
    if (!_inFamilyChat && !_view.familyChat) return null;
    int count(ChatChannel channel) => _client.chat.where((m) => m.channel == channel).length;
    for (final channel in const [ChatChannel.day, ChatChannel.family]) {
      // La prima volta conta solo quello che arriva da adesso.
      if (channel == view.channel || !_seenChat.containsKey(channel)) _seenChat[channel] = count(channel);
    }
    int unread(ChatChannel channel) => max(0, count(channel) - (_seenChat[channel] ?? 0));
    final swap = _stage.chat == 'day' && _view.familyChat;
    return [
      ChatTab(
        key: const Key('online.chatTab.town'),
        label: _t.online.chatTown,
        accent: Saloon.brass,
        icon: Icons.forum,
        active: view.channel == ChatChannel.day,
        unread: unread(ChatChannel.day),
        onTap: swap ? () => setState(() => _familyTab = false) : null,
      ),
      ChatTab(
        key: const Key('online.chatTab.family'),
        label: _t.online.chatFamily,
        accent: Saloon.mafia,
        icon: Icons.theater_comedy,
        active: view.channel == ChatChannel.family,
        unread: unread(ChatChannel.family),
        onTap: swap ? () => setState(() => _familyTab = true) : null,
      ),
    ];
  }

  List<ChatTab> _loversTabs(ChatChannelView view) {
    int count(ChatChannel channel) => _client.chat.where((m) => m.channel == channel).length;
    for (final channel in const [ChatChannel.family, ChatChannel.lovers]) {
      if (channel == view.channel || !_seenChat.containsKey(channel)) _seenChat[channel] = count(channel);
    }
    int unread(ChatChannel channel) => max(0, count(channel) - (_seenChat[channel] ?? 0));
    return [
      ChatTab(
        key: const Key('online.chatTab.family'),
        label: _t.online.chatFamily,
        accent: Saloon.mafia,
        icon: Icons.theater_comedy,
        active: view.channel == ChatChannel.family,
        unread: unread(ChatChannel.family),
        onTap: () => setState(() => _loversTab = false),
      ),
      ChatTab(
        key: const Key('online.chatTab.lovers'),
        label: _ts.loversChat,
        accent: const Color(0xFFE58AB0),
        icon: Icons.favorite,
        active: view.channel == ChatChannel.lovers,
        unread: unread(ChatChannel.lovers),
        onTap: () => setState(() => _loversTab = true),
      ),
    ];
  }

  /// Le parole sul panno, al centro del tavolo: poche, grandi, sempre a
  /// misura leggibile. Vanno a capo nella larghezza che c'è; solo se sono
  /// troppo alte si stringono un poco.
  Widget _felt(List<Widget> lines, {Key? key}) => LayoutBuilder(
    key: key,
    builder: (context, box) => FittedBox(
      fit: BoxFit.scaleDown,
      child: Container(
        constraints: BoxConstraints(maxWidth: min(box.maxWidth, _deskMode ? 560.0 : 320.0)),
        padding: _deskMode
            ? const EdgeInsets.symmetric(horizontal: 24, vertical: 16)
            : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xB0080605),
          borderRadius: BorderRadius.circular(12 * _k),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: lines),
      ),
    ),
  );

  /// Il panno per i testi che vanno letti tutti (il verdetto): niente
  /// puntini, il carattere si adatta allo spazio fra i posti.
  Widget _feltFit(List<FeltLine> lines, {Key? key, Widget? footer}) => LayoutBuilder(
    key: key,
    builder: (context, box) => Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: min(box.maxWidth, _deskMode ? 560.0 : 320.0), maxHeight: box.maxHeight),
        padding: _deskMode
            ? const EdgeInsets.symmetric(horizontal: 24, vertical: 16)
            : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xB0080605),
          borderRadius: BorderRadius.circular(12 * _k),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (lines.isNotEmpty) Flexible(child: FeltText(lines, gap: 4 * _k)),
            // La carta del linciato si rimpicciolisce, ma non si taglia.
            if (footer != null) ...[
              if (lines.isNotEmpty) SizedBox(height: 6 * _k),
              Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: footer)),
            ],
          ],
        ),
      ),
    ),
  );

  /// La carta del linciato, piccola sul panno: l'icona e il nome del ruolo.
  /// Un tocco apre i dettagli (cosa fa, con chi vince).
  Widget _verdictRoleChip(Role role) {
    final text = _t.role(role);
    final color = Color.lerp(stampColorFor(role), Colors.white, 0.35)!;
    return Semantics(
      button: true,
      label: text.label,
      child: InkWell(
        key: const Key('online.verdictRole'),
        borderRadius: BorderRadius.circular(8 * _k),
        onTap: () => showNoirDialog<void>(
          context,
          builder: (context) => NoirDialog(
            key: const Key('online.verdictRoleDetails'),
            lead: RoleIcon(role, size: _deskMode ? 72 : 56),
            title: text.label,
            overline: text.motto,
            body: text.description,
            closeButton: true,
          ),
        ),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10 * _k, vertical: 4 * _k),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(8 * _k),
            border: Border.all(color: color.withValues(alpha: 0.8), width: 1.2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              RoleIcon(role, size: _deskMode ? 30 : 22),
              SizedBox(width: 6 * _k),
              Text(
                text.label,
                maxLines: 1,
                style: _feltLineStyle(color: color, weight: FontWeight.w600).copyWith(fontSize: _deskMode ? 18 : 13),
              ),
              SizedBox(width: 4 * _k),
              Icon(Icons.info_outline, size: _deskMode ? 18 : 14, color: color),
            ],
          ),
        ),
      ),
    );
  }

  TextStyle _feltTitleStyle(Color color) => AppText.display(_deskMode ? 28 : 17, color: color).copyWith(
    letterSpacing: _deskMode ? 1.2 : 0.6,
    height: 1.2,
    shadows: const [Shadow(color: Colors.black, blurRadius: 6)],
  );

  TextStyle _feltLineStyle({Color color = AppColors.textPrimary, FontWeight? weight, FontStyle? style}) => TextStyle(
    color: color,
    fontSize: _deskMode ? 21 : 15,
    fontWeight: weight,
    fontStyle: style,
    height: 1.3,
    shadows: const [Shadow(color: Colors.black, blurRadius: 6)],
  );

  /// Il titolo sul panno: la domanda della notte, il verdetto.
  Text _feltTitle(String text, {Key? key, Color color = AppColors.textPrimary, int maxLines = 3}) => Text(
    text,
    key: key,
    textAlign: TextAlign.center,
    maxLines: maxLines,
    overflow: TextOverflow.ellipsis,
    style: _feltTitleStyle(color),
  );

  /// Una riga di testo sul panno: corpo pieno (15 sul telefono, 21 su PC).
  Text _feltLine(
    String text, {
    Key? key,
    Color color = AppColors.textPrimary,
    FontWeight? weight,
    FontStyle? style,
    int maxLines = 3,
  }) => Text(
    text,
    key: key,
    textAlign: TextAlign.center,
    maxLines: maxLines,
    overflow: TextOverflow.ellipsis,
    style: _feltLineStyle(color: color, weight: weight, style: style),
  );

  // ---------------------------------------------------------------------
  // Il tavolo: tutti grandi uguali, intorno al panno.

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
    fallen: {for (final p in _public.seats) if (!_isAlive(p)) p.id},
    mayor: _public.mayor?.id,
    roster: [
      for (var i = 0; i < _public.seats.length; i++)
        (number: i + 1, name: _public.seats[i].name, alive: _isAlive(_public.seats[i])),
    ],
  );

  /// Il voto di chi ha votato, sul suo posto: il numero di posto
  /// dell'accusato (chi si astiene di giorno ha un trattino). Di notte, chi
  /// passa non ha niente. Niente mani sul tavolo: bastano i numeri.
  String? _pizzinoOf(SeatVote? vote, {required bool day}) => switch (vote?.target) {
    _ when vote == null => null,
    final target? => '${_numberOf(target) ?? target.name}',
    null when !day => null,
    null when _italian && PlayerGenders.of(vote.voter.name) == Gender.feminine => 'astenuta',
    null => _t.online.abstainTag,
  };

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
    bool accusing = true,
    bool day = true,
  }) {
    // I morti restano al loro posto, segnati come caduti.
    final present = [...players];
    // Il proprio posto è sempre in basso al centro: si gira il tavolo.
    final mine = present.indexOf(_view.seat);
    final seats = mine <= 0 ? present : [...present.skip(mine), ...present.take(mine)];
    final tally = <Player, int>{};
    for (final vote in votes) {
      // Il voto del Sindaco rivelato vale doppio.
      final weight = day && vote.voter == _public.mayor ? 2 : 1;
      if (vote.target case final target?) tally[target] = (tally[target] ?? 0) + weight;
    }
    final top = tally.values.fold(0, max);
    final leaders = [
      for (final e in tally.entries)
        if (e.value == top) e.key,
    ];
    // L'accusato è solo del voto di giorno: di notte i voti sono quelli della
    // Famiglia, e il loro bersaglio ha il mirino, mai il nastro.
    final leading = day && accusing && top > 0 && leaders.length == 1 ? leaders.single : null;
    final index = {for (var i = 0; i < seats.length; i++) seats[i]: i};
    final byId = {for (var i = 0; i < seats.length; i++) seats[i].id: i};
    return SaloonTable(
      count: seats.length,
      maxCard: _deskMode ? 152 : 118,
      center: center,
      leading: leading == null ? null : index[leading],
      gestures: [
        for (final g in _gestures)
          if (byId[g.fromSeat] case final from?)
            if (byId[g.toSeat] case final to?) (id: g.id, from: from, to: to, gesture: g.gesture),
      ],
      seatBuilder: (context, i, width) {
        final player = seats[i];
        final vote = votes.where((v) => v.voter == player).firstOrNull;
        // Il ruolo, se si sa: quello pubblico per tutti, quello dei complici
        // per la famiglia. Sul posto basta l'icona; il nome solo su PC, dove
        // c'è spazio per leggerlo.
        final role = _publicKnowledge(player).role ?? (player == _view.seat ? null : _knowledgeOf(player).role);
        final silenced = _public.lastDawn?.silenced == player && _public.lastDawn?.round == _public.round;
        final can = selectable.contains(player);
        final seat = VoiceRing(
          controller: _voice,
          identity: player.id,
          width: width,
          child: SeatCard(
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
          nightTarget: !day && (tally[player] ?? 0) > 0,
          votes: day ? tally[player] ?? 0 : 0,
          pizzino: _pizzinoOf(vote, day: day),
          pizzinoKey: ValueKey('pizzino-${player.id}'),
          pizzinoColor: voteColor,
          stamped: player == lynched,
          // Sul posto del linciato il timbro dice già tutto: niente nota.
          note: player == lynched
              ? null
              : _offline(player)
              ? _t.online.offlineBadge
              : silenced
              ? _ts.silenced(PlayerGenders.of(player.name))
              : role != null && _deskMode
              ? _t.role(role).label
              : null,
          noteColor: _offline(player) || silenced
              ? AppColors.textSecondary
              : role?.team == Team.mafia
              ? Saloon.mafia
              : Saloon.brass,
          role: role,
          selectable: can && onTap != null && player != selected,
          dimmed: selectable.isNotEmpty && !can && _isAlive(player) && player != selected && player != _view.seat,
          // Il posto da scegliere si sceglie; ogni altro volto apre il
          // foglio del giocatore (il posto già scelto non si ritocca).
          onTap: can && onTap != null && player != selected
              ? () => onTap(player)
              : player == _view.seat
              ? null
              : () => _seatSheet(player),
          onLongPress: player == _view.seat ? null : () => _seatHeld(player),
          ),
        );
        if (player == lynched) {
          return LynchMark(
            key: ValueKey('lynch-${_public.lastLynch?.round}-${player.id}'),
            label: _ts.lynched(PlayerGenders.of(player.name)),
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
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, height: 1.35, fontStyle: FontStyle.italic),
          ),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: NoirRoleCard(
                role: view.role,
                teammates: view.teammates,
                bounty: view.bounty,
                onRevealed: () => setState(() => _cardTurned = true),
              ),
            ),
          ),
        ),
        ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: _cardStrip()),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // La notte.

  /// La Famiglia che si conosce: la Prostituta non entra mai nella sua chat.
  bool get _inFamilyChat => _view.alive && _view.role.knowsFamily;

  /// La notte, per chi ha una mossa: si tocca un posto e la scelta parte
  /// subito; si cambia toccandone un altro (o «passo») fino allo scadere, e
  /// resta segnata sul tavolo. La famiglia vede le mani di tutti i suoi. Solo
  /// l'indagine e lo scavo, che rispondono subito, chiedono conferma.
  _Phase _taskPhase() {
    final option = _view.action!;
    final script = _script('task');
    final open = _open;
    final pick = _nightPick;
    final choice = _view.nightChoice;
    final hasAlternative = option.alternative != null;
    final alternative = hasAlternative && (_alternative ?? (choice != null && choice.kind == option.alternative));
    final family = option.type == ActionType.mafiaVote && !alternative;
    final targets = alternative ? (option.alternativeTargets ?? option.targets) : option.targets;
    final kind = alternative ? option.alternative! : option.kind!;
    final shown = NightTask(kind, targets);
    final labels = alternativeLabels(_t, option.alternative);
    final lastWatch = _view.watches.isEmpty ? null : _view.watches.last;
    final familyVotes = option.type == ActionType.mafiaVote
        ? _withHope(_view.familyVotes.isNotEmpty ? _view.familyVotes : _lastFamilyVotes, family: true)
        : const <SeatVote>[];
    final notes = [
      if (lastWatch != null && lastWatch.round == _public.round - 1)
        (lastWatch.visited ? _t.pack.watchVisited : _t.pack.watchQuiet).replaceAll('{name}', _tag(lastWatch.target)),
      if (_view.doused.isNotEmpty) '${_t.dousedBadge}: ${_view.doused.map(_tag).join(', ')}',
      if (_view.bounty case final mark?) _t.bountyLine.replaceAll('{name}', _tag(mark)),
      if (_view.role == Role.prostituta && option.type == ActionType.mafiaVote) _ts.lastOfFamily,
      if (_view.cell case final mate? when mate != _view.seat && _view.role != Role.carceriere) _ts.mateInCell(_tag(mate)),
      if (_findingsAtDawn && (kind == NightTaskKind.investigate || kind == NightTaskKind.dig)) _ts.answerAtDawn,
      ..._loverNotes,
      ..._sectNotes,
    ];
    final String status;
    final StripTone tone;
    if (kind == NightTaskKind.link && !pick.made) {
      status = _firstLover == null ? _ts.linkFirst : _ts.linkSecond(_tag(_firstLover!));
      tone = StripTone.act;
    } else if (!pick.made) {
      status = script.taskHint(shown);
      tone = StripTone.act;
    } else if (pick.target case final target?) {
      status = _ts.picked(_tag(target));
      tone = StripTone.done;
    } else {
      status = _ts.passed;
      tone = StripTone.done;
    }
    return (
      key: const Key('online.night'),
      table: _table(
        players: _secretTable(),
        selectable: targets.toSet(),
        selected: kind == NightTaskKind.link ? _firstLover : pick.target,
        onTap: open ? (player) => _pickNight(player, kind: kind, family: family) : null,
        votes: familyVotes,
        voteColor: Saloon.mafia,
        day: false,
        center: _felt([
          _feltTitle(script.taskPrompt(shown, _public.round), color: family ? const Color(0xFFFFB3B3) : AppColors.textPrimary),
          for (final note in notes) ...[
            SizedBox(height: 4 * _k),
            _feltLine(note, color: Saloon.brass, maxLines: 2),
          ],
        ]),
      ),
      strip: ActionStrip(
        status: status,
        statusKey: pick.made ? const Key('online.moveRegistered') : null,
        tone: tone,
        control: hasAlternative
            ? SizedBox(
                height: NoirMetrics(_deskMode).button,
                child: TargaSegmented<bool>(
                  key: const Key('online.alternative'),
                  desk: _deskMode,
                  height: NoirMetrics(_deskMode).button,
                  segments: [(false, labels.$1), (true, labels.$2)],
                  selected: alternative,
                  // Cambia solo cosa si tocca: la scelta registrata resta
                  // finché non si tocca un posto.
                  onChanged: open ? (choice) => setState(() => _alternative = choice) : null,
                ),
              )
            : null,
        actions: [
          NoirAction(
            key: const Key('online.pass'),
            label: _t.pass,
            feel: Press.tap,
            onPressed: !open || (pick.made && pick.target == null) ? null : () => _send(Pass(_view.seat.id)),
          ),
        ],
      ),
    );
  }

  /// Un posto toccato di notte. Le mosse che si risolvono all'alba partono
  /// subito (si possono cambiare); l'indagine e lo scavo, che rispondono
  /// subito e poi non si cambiano, prima chiedono conferma.
  Future<void> _pickNight(Player target, {required NightTaskKind kind, required bool family}) async {
    final pick = _nightPick;
    if (pick.made && pick.target == target) return;
    // Cupido: il primo tocco sceglie il primo innamorato, il secondo chiede
    // conferma e lega tutti e due.
    if (kind == NightTaskKind.link) {
      final first = _firstLover;
      if (first == null || first == target) {
        setState(() => _firstLover = first == target ? null : target);
        return;
      }
      final stage = _window?.key;
      final yes = await confirmNoir(
        context,
        key: const Key('online.askLink'),
        title: _ts.link(_tag(first), _tag(target)),
        body: _ts.linkBody,
        cancel: _ts.cancel,
        confirm: _t.confirm,
        cancelKey: const Key('online.cancel'),
        confirmKey: const Key('online.confirm'),
      );
      if (!mounted) return;
      setState(() => _firstLover = null);
      if (!yes || _window?.key != stage || !_open) return;
      await _send(Link(_view.seat.id, first.id, target.id));
      return;
    }
    final intent = family ? MafiaVote(_view.seat.id, target.id) : NightAction(_view.seat.id, target.id);
    if (_locks(kind)) {
      final stage = _window?.key;
      final yes = await _confirmImmediate(target, kind);
      if (!yes || !mounted || _window?.key != stage || !_open) return;
    }
    await _send(intent);
  }

  Future<bool> _confirmImmediate(Player target, NightTaskKind kind) async {
    final yes = await showNoirDialog<bool>(
      context,
      builder: (context) {
        _asking = context;
        return NoirDialog(
          key: const Key('online.askImmediate'),
          title: switch (kind) {
            NightTaskKind.dig => _ts.dig(_tag(target)),
            NightTaskKind.jail => _ts.jail(_tag(target)),
            _ => _ts.investigate(_tag(target)),
          },
          body: kind == NightTaskKind.jail ? _ts.jailBody : _ts.instantAnswer,
          onEnter: () => Navigator.of(context).pop(true),
          actions: [
            NoirAction(
              key: const Key('online.cancel'),
              label: _ts.cancel,
              feel: Press.back,
              onPressed: () => Navigator.of(context).pop(false),
            ),
            NoirAction(
              key: const Key('online.confirm'),
              label: _t.confirm,
              style: NoirButtonStyle.primary,
              feel: Press.confirm,
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );
    _asking = null;
    return yes == true;
  }

  /// La notte di chi non ha (più) mosse: chi è fuori, chi ha già avuto la
  /// risposta dell'indagine o dello scavo. Sul panno la risposta, o la notte
  /// che scende.
  /// Quello che l'indagine o lo scavo di stanotte hanno scoperto: dalla
  /// risposta del server o, per chi rientra al tavolo, da quello che sa.
  /// Con chi blocca al tavolo (il mazzo è pubblico) le indagini rispondono
  /// all'alba, come dice il motore ([GameEngine.findingsAtDawn]).
  bool get _findingsAtDawn => _public.deck.keys.any((role) => role.isBlocker);

  /// La mossa, una volta fatta, non si cambia: la cella, e l'indagine o lo
  /// scavo quando rispondono subito.
  bool _locks(NightTaskKind kind) => kind == NightTaskKind.jail || (kind.immediate && !_findingsAtDawn);

  Exposure? get _nightFinding {
    final choice = _view.nightChoice;
    final target = choice?.target;
    if (choice == null || target == null || !choice.kind.immediate || _findingsAtDawn) return null;
    if (_finding case final finding? when finding.subject == target) return finding;
    final known = _knowledgeOf(target);
    final team = known.team;
    if (team == null) return null;
    return Exposure(target, team, role: choice.kind == NightTaskKind.dig ? known.role : null);
  }

  _Phase _waitingPhase() {
    final view = _view;
    final finding = _nightFinding;
    final found = finding?.role;
    final isMafia = finding?.team == Team.mafia;
    final Widget center;
    final cell = view.alive ? view.cell : null;
    if (cell != null && cell == view.seat) {
      center = _felt(key: const Key('online.jailed'), [
        _feltTitle(_ts.youAreJailed, color: Saloon.brass, maxLines: 2),
        SizedBox(height: 4 * _k),
        _feltLine(_ts.jailerWantsYou, style: FontStyle.italic, maxLines: 2),
      ]);
    } else if (cell != null && view.role == Role.carceriere) {
      center = _felt(key: const Key('online.jailer'), [
        _feltTitle(_ts.inYourCell(_tag(cell)), color: Saloon.brass, maxLines: 3),
      ]);
    } else if (finding == null && (_loverNotes.isNotEmpty || _sectNotes.isNotEmpty)) {
      center = _felt(key: const Key('online.lovers'), [
        for (final note in [..._loverNotes, ..._sectNotes])
          _feltLine(note, color: const Color(0xFFE58AB0), weight: FontWeight.w700, maxLines: 3),
      ]);
    } else if (finding == null) {
      center = _felt(key: const Key('online.waiting'), [
        _feltLine(
          !view.alive
              ? _script('night-${_public.round}').nightFalls(_public.round, online: true).map((l) => l.text).join('\n')
              : _t.nobodyWillKnow,
          style: FontStyle.italic,
          maxLines: 4,
        ),
      ]);
    } else {
      center = _felt(key: const Key('online.waiting'), [
        _feltLine(found == null ? _t.yourInvestigation : _t.inTheGrave, color: Saloon.brass, weight: FontWeight.w700),
        SizedBox(height: 4 * _k),
        _feltTitle(_tag(finding.subject), maxLines: 1),
        SizedBox(height: 4 * _k),
        _feltTitle(
          found != null
              ? _t.wasRole(_t.role(found).label)
              : isMafia
              ? _t.isFamily
              : _t.isInnocent,
          color: isMafia ? Saloon.mafia : Saloon.clean,
          maxLines: 2,
        ),
      ]);
    }
    return (
      key: const Key('online.night'),
      table: _table(players: _secretTable(), selected: finding?.subject, center: center, day: false),
      strip: ActionStrip(
        status: !view.alive ? _t.online.youAreOut : _ts.nightRunsOut,
        statusKey: view.nightChoice != null ? const Key('online.moveRegistered') : null,
        tone: !view.alive ? StripTone.out : StripTone.done,
      ),
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

  String get _masthead => _t.language.message('courier.masthead', {'city': _city.name});

  String _dateLine(String edition) =>
      _t.language.message('courier.dateLine', {'round': _public.round, 'edition': edition});

  List<FrontPageLine> _printed(List<ScriptLine> lines) => [for (final l in lines) (text: l.text, fact: l.isFact)];

  _Phase _waitingPhaseFor(Key key) => (
    key: key,
    table: _connectingView(),
    strip: ActionStrip(status: _t.online.startingSoon, tone: StripTone.wait),
  );

  _Phase _dawnPhase() {
    final dawn = _public.lastDawn;
    if (dawn == null) return _waitingPhaseFor(const Key('online.dawn'));
    final lines = _script('dawn-${dawn.round}')
        .dawn(dawn, discussion: _board.settings.discussion, stories: _storiesOf(dawn), online: true);
    final (:headline, :dead) = dawnHeadline(dawn, language: _t.language, everyoneAlive: _t.everyoneAlive);
    return (
      key: const Key('online.dawn'),
      strip: ActionStrip(
        status: _readyStatus(_ts.readTheNews),
        tone: _readyTone,
        actions: [?_readyAction()],
      ),
      table: _deskPaper(FrontPage(
        key: ValueKey('front-dawn-${dawn.round}'),
        compact: !_deskMode,
        scale: _deskMode ? 1.5 : 1,
        masthead: _masthead,
        dateLine: _dateLine(_t.language.message('courier.dawnEdition')),
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
  /// mostra la carta, se la piazza l'ha vista. Le mani restano puntate
  /// finché il linciaggio non finisce, poi si ritirano e il panno resta
  /// libero per il titolo; i pizzini dicono ancora chi ha votato chi.
  _Phase _verdictPhase() {
    final report = _public.lastLynch;
    if (report == null) return _waitingPhaseFor(const Key('online.verdict'));
    final condemned = report.condemned;
    final role = report.role;
    // Sul panno una riga tecnica e corta: chi, e che carta aveva. Il racconto
    // resta al narratore e al giornale, non qui in mezzo.
    final verdict = condemned == null
        ? (report.truce ? _ts.truceVerdict : _ts.noLynch)
        : _ts.lynchedLine(_tag(condemned), role == null ? null : _t.role(role).label, gender: PlayerGenders.of(condemned.name));
    final extra = [
      if (condemned != null && report.personalWin) _t.pack.foolWinsFact.replaceAll('{name}', _tag(condemned)),
      if (report.bountyHunter case final hunter?) _t.pack.bountyWinsFact.replaceAll('{name}', _tag(hunter)),
    ];
    final film = _stage == Stage.verdictFilm;
    final into = film ? _client.elapsed : LynchMark.length;
    final headlineColor = role == null ? Saloon.brass : Color.lerp(stampColorFor(role), Colors.white, 0.45)!;
    final chip = role == null || condemned == null ? null : _verdictRoleChip(role);
    final extraLines = [
      for (final line in extra) (text: line, key: null, style: _feltLineStyle(color: Saloon.brass)),
    ];
    // Sul telefono il panno è piccolo: la frase va nella striscia, sopra
    // «Pronto», e sul panno restano la carta del linciato e le note. Sul
    // tavolo grande la frase sta sul panno, nello spazio libero fra i posti.
    final narrow = _narrowTable;
    final Widget? center = narrow
        ? (extraLines.isEmpty && chip == null ? null : _feltFit(extraLines, footer: chip))
        : _feltFit(
            [
              (text: verdict, key: const Key('online.verdictHeadline'), style: _feltTitleStyle(headlineColor)),
              ...extraLines,
            ],
            footer: chip,
          );
    final m = NoirMetrics(_deskMode);
    final tallyStyle = TextStyle(
      color: AppColors.textSecondary,
      fontSize: m.body * 0.9,
      height: 1.3,
      fontWeight: FontWeight.w500,
      shadows: const [Shadow(color: Colors.black, blurRadius: 8)],
    );
    final actions = [if (!film) ?_readyAction()];
    return (
      key: const Key('online.verdict'),
      table: _table(
        players: publicSeating(_public.seats),
        votes: _lastVotes,
        accusing: false,
        lynched: condemned,
        lynchedAt: into < Duration.zero ? Duration.zero : into,
        center: center,
      ),
      strip: ActionStrip(
        status: narrow ? '$verdict ${_verdictTally()}' : _verdictTally(),
        tone: film || !_view.alive ? StripTone.out : (_acked ? StripTone.wait : StripTone.done),
        // Il verdetto si legge tutto, mai i puntini; lo scrutinio scorre di
        // lato se i voti sono tanti.
        detail: VerdictLine(
          headline: narrow ? verdict : null,
          headlineKey: const Key('online.verdictHeadline'),
          headlineStyle: TextStyle(
            color: Color.lerp(headlineColor, Colors.white, 0.25),
            fontSize: m.body,
            height: 1.3,
            fontWeight: FontWeight.w700,
            shadows: const [Shadow(color: Colors.black, blurRadius: 8)],
          ),
          tally: _verdictTally(),
          tallyKey: const Key('online.verdictVotes'),
          tallyStyle: tallyStyle,
          height: ActionStrip.heightFor(desk: _deskMode) - m.gap * (_deskMode ? 3 : 2) - (actions.isEmpty ? 0 : m.button),
        ),
        actions: actions,
      ),
    );
  }

  /// Lo scrutinio in una riga: quanti voti a chi, dal più votato, e quanti
  /// si sono astenuti. Chi ha votato chi lo dicono i pizzini sul tavolo.
  String _verdictTally() {
    final counts = <Player, int>{};
    var abstained = 0;
    for (final vote in _lastVotes) {
      final target = vote.target;
      if (target == null) {
        abstained++;
      } else {
        counts[target] = (counts[target] ?? 0) + (vote.voter == _public.mayor ? 2 : 1);
      }
    }
    final order = counts.keys.toList()..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    final parts = [
      for (final target in order) '${_tag(target)}: ${_t.online.votesFor(counts[target]!)}',
      if (abstained > 0) _ts.abstainedVotes(abstained),
    ];
    return parts.isEmpty ? _t.online.verdictWaiting : parts.join('  ·  ');
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

  /// La discussione: sul panno il titolo dell'alba (chi è morto stanotte),
  /// sotto «pronto» per andare al voto.
  _Phase _discussionPhase() {
    final dawn = _public.lastDawn;
    final headline = dawn == null || dawn.round != _public.round
        ? null
        : dawnHeadline(dawn, language: _t.language, everyoneAlive: _t.everyoneAlive).headline;
    final silenced = _view.alive && _view.silenced;
    final option = _view.action;
    final canPacify = option != null && option.canPacify && _open;
    final picking = canPacify && _pacifying;
    final pacifist = _public.pacifist;
    final pacified = _public.pacified;
    final shown = pacified == null ? null : _publicKnowledge(pacified).role;
    final truce = pacifist == null || pacified == null || shown == null
        ? null
        : _ts.truceLine(_tag(pacifist), _tag(pacified), _lowerFirst(_t.role(shown).label));
    // Il colpo del Tiratore scelto, oggi: chi è caduto e la sua carta.
    final marksmanShot = _public.lastShot;
    final shotLine = marksmanShot == null || marksmanShot.round != _public.round
        ? null
        : _ts.shotLine(_tag(marksmanShot.victim), _lowerFirst(_t.role(marksmanShot.role).label), backfired: marksmanShot.backfired);
    final aim = _view.aim;
    final canShoot = option != null && option.canShoot && aim != null && _open;
    // L'Artigliere: chi può colpire adesso, e il boato di oggi.
    final fireTargets = _open && _view.alive ? _view.fireTargets : const <Player>[];
    final aiming = fireTargets.isNotEmpty && _aiming && !picking;
    final shot = _public.shots.lastOrNull;
    final cannon = shot == null || shot.round != _public.round || _public.phase != GamePhase.day
        ? null
        : _ts.cannonLine(_tag(shot.target), _lowerFirst(_t.role(shot.role).label));
    final shotsLeft = _view.shotsLeft;
    final felt = [
      if (cannon != null) _feltLine(cannon, key: const Key('online.cannon'), color: Saloon.mafia, weight: FontWeight.w700, maxLines: 4),
      if (shotLine != null) _feltLine(shotLine, key: const Key('online.shot'), color: Saloon.mafia, weight: FontWeight.w700, maxLines: 4),
      if (truce != null) _feltLine(truce, key: const Key('online.truce'), color: Saloon.brass, weight: FontWeight.w700, maxLines: 4),
      if (cannon != null && shotsLeft != null && _view.alive)
        _feltLine(_ts.shotsLeft(shotsLeft), key: const Key('online.shotsLeft'), color: Saloon.brass, maxLines: 2),
    ];
    return (
      key: const Key('online.discussion'),
      table: _table(
        players: publicSeating(_public.seats),
        selectable: picking
            ? option.targets.toSet()
            : aiming
            ? fireTargets.toSet()
            : const {},
        onTap: picking
            ? _pacify
            : aiming
            ? _fire
            : null,
        center: felt.isNotEmpty
            ? _felt(felt)
            : headline == null
            ? null
            : _felt([_feltTitle(headline, maxLines: 2)]),
      ),
      strip: ActionStrip(
        status: picking
            ? _ts.truceHint
            : aiming
            ? _ts.fireHint
            : silenced && !_acked
            ? _t.online.chatSilenced
            : _readyStatus(_t.online.discussionHint),
        tone: picking || aiming
            ? StripTone.act
            : silenced && !_acked
            ? StripTone.muted
            : _readyTone,
        actions: [
          if (option != null && option.canPacify)
            NoirAction(
              key: const Key('online.truce'),
              label: _ts.truce,
              onPressed: canPacify ? () => setState(() => _pacifying = !_pacifying) : null,
            ),
          if (canShoot)
            NoirAction(
              key: const Key('online.shoot'),
              label: _ts.fire,
              onPressed: () => _shoot(aim),
            ),
          if (fireTargets.isNotEmpty)
            NoirAction(
              key: const Key('online.fire'),
              label: _ts.fire,
              onPressed: () => setState(() {
                _aiming = !_aiming;
                _pacifying = false;
              }),
            ),
          ?_readyAction(),
        ],
      ),
    );
  }

  String _lowerFirst(String text) => !_t.language.capitalizesRoles && text.isNotEmpty ? text[0].toLowerCase() + text.substring(1) : text;

  /// La tregua non si disfa: prima si chiede, con il nome scelto.
  Future<void> _pacify(Player target) async {
    final stage = _window?.key;
    final yes = await confirmNoir(
      context,
      key: const Key('online.askTruce'),
      title: _ts.truceTitle(_tag(target)),
      body: _ts.truceBody,
      cancel: _ts.cancel,
      confirm: _ts.truce,
      cancelKey: const Key('online.cancel'),
      confirmKey: const Key('online.confirm'),
    );
    if (!mounted) return;
    setState(() => _pacifying = false);
    if (!yes || _window?.key != stage || !_open) return;
    await _send(Pacify(_view.seat.id, target.id));
  }

  /// Il colpo non si ritira: prima si chiede, con il nome scelto.
  Future<void> _fire(Player target) async {
    final stage = _window?.key;
    final left = _view.shotsLeft;
    final yes = await confirmNoir(
      context,
      key: const Key('online.askFire'),
      title: _ts.fireTitle(_tag(target)),
      body: left == null ? _ts.fireBody : '${_ts.fireBody} ${_ts.shotsLeft(left)}',
      cancel: _ts.cancel,
      confirm: _ts.fire,
      cancelKey: const Key('online.cancel'),
      confirmKey: const Key('online.confirm'),
    );
    if (!mounted) return;
    setState(() => _aiming = false);
    if (!yes || _window?.key != stage || !_open) return;
    await _send(Fire(_view.seat.id, target.id));
  }

  /// Il colpo non si disfa: prima si chiede, con il nome nel mirino.
  Future<void> _shoot(Player target) async {
    final stage = _window?.key;
    final yes = await confirmNoir(
      context,
      key: const Key('online.askShot'),
      title: _ts.shootTitle(_tag(target)),
      body: _ts.shootBody(_view.shotsLeft ?? 0),
      cancel: _ts.cancel,
      confirm: _ts.fire,
      cancelKey: const Key('online.cancel'),
      confirmKey: const Key('online.confirm'),
    );
    if (!mounted || !yes || _window?.key != stage || !_open) return;
    await _send(Shoot(_view.seat.id));
  }

  /// Il voto: si tocca chi condannare (il voto parte subito e si cambia
  /// toccando un altro), o ci si astiene. Il Sindaco può rivelarsi.
  _Phase _votePhase() {
    final view = _view;
    final option = view.action;
    final votes = _withHope(_public.dayVotes);
    final mine = [
      for (final vote in votes)
        if (vote.voter == view.seat) vote,
    ].firstOrNull;
    final canVote = option != null && _open;
    final selected = mine?.target;
    final cast = votes.length;
    final alive = _public.alive.length;
    final String status;
    final StripTone tone;
    Key? statusKey;
    if (!view.alive || option == null) {
      status = _t.online.youAreOut;
      tone = StripTone.out;
    } else if (mine == null) {
      status = _t.online.voteHint;
      tone = StripTone.act;
    } else {
      status = mine.target == null ? _ts.abstained(PlayerGenders.of(view.seat.name)) : _ts.votedFor(_tag(mine.target!));
      statusKey = const Key('online.myVote');
      tone = StripTone.done;
    }
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
        center: _public.mayor == null
            ? null
            : _felt([
                _feltLine(
                  _t.pack.mayorRevealed.replaceAll('{name}', _tag(_public.mayor!)),
                  key: const Key('online.mayor'),
                  color: Saloon.brass,
                  weight: FontWeight.w700,
                ),
              ]),
      ),
      strip: ActionStrip(
        status: status,
        statusKey: statusKey,
        tone: tone,
        count: '$cast/$alive',
        countTooltip: _t.online.votesCast(cast, alive),
        actions: [
          if (option != null && option.canReveal)
            NoirAction(
              key: const Key('online.revealMayor'),
              label: _ts.revealMayor,
              onPressed: canVote ? _revealMayor : null,
            ),
          if (option != null)
            NoirAction(
              key: const Key('online.abstain'),
              label: _t.online.abstain,
              onPressed: canVote && (mine == null || mine.target != null) ? () => _send(Pass(view.seat.id)) : null,
            ),
        ],
      ),
    );
  }

  /// Rivelarsi Sindaco non si disfa: prima si chiede.
  Future<void> _revealMayor() async {
    final stage = _window?.key;
    final yes = await confirmNoir(
      context,
      key: const Key('online.askMayor'),
      title: _ts.revealMayorTitle,
      body: _ts.revealMayorBody,
      cancel: _ts.cancel,
      confirm: _ts.revealMayor,
      cancelKey: const Key('online.cancel'),
      confirmKey: const Key('online.confirm'),
    );
    if (!yes || !mounted || _window?.key != stage || !_open) return;
    await _send(RevealMayor(_view.seat.id));
  }

  // ---------------------------------------------------------------------

  String _fateOf(Player player) {
    if (_board.departed.contains(player.id)) return _t.online.fateLeft;
    for (final record in _public.history) {
      if (record.nightVictims.contains(player)) return _t.fateNight(record.round);
      if (record.lynched == player) return _t.fateGallows(record.round);
      if (record.dayVictims.contains(player)) return LocalRoleStrings(_t).fateDay(record.round);
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
        const SizedBox(height: 16),
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) {
              const columns = 3;
              const gap = 8.0;
              final cell = (box.maxWidth - gap * (columns - 1)) / columns;
              return SingleChildScrollView(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: gap,
                  runSpacing: 24,
                  children: [
                    for (final player in players)
                      SizedBox(
                        width: cell,
                        child: Column(
                          children: [
                            SeatCard(
                              name: player.name,
                              number: _numberOf(player),
                              width: cell * 0.78,
                              fallen: !_isAlive(player),
                              me: player == _view.seat,
                              selected: _public.won(player),
                              role: roles[player],
                              noteColor: roles[player]!.team == Team.mafia ? Saloon.mafia : Saloon.brass,
                            ),
                            const SizedBox(height: 8),
                            _castLine(player, roles[player]!),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        NoirActions(actions: _endActions()),
        const SizedBox(height: 8),
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

