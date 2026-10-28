import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../l10n/app_strings.dart';
import '../../../l10n/safety_strings.dart';
import '../../../online/game/bot_brain.dart';
import '../../../online/join_code.dart';
import '../../../online/online_services.dart';
import '../../../sound/screen_music.dart';
import '../../../sound/sound_stage.dart';
import '../../../l10n/desktop_online_strings.dart';
import '../../desktop/desktop_canvas.dart';
import '../../theme/app_theme.dart';
import 'cafe_room.dart';
import 'chat_panel.dart';
import 'game/noir_ui.dart';
import 'online_game_screen.dart';
import 'match_results_screen.dart' show showMatchResults;
import 'online_widgets.dart';
import 'safety_sheets.dart';
import 'voice/voice_dock.dart';
import '../../../online/voice/voice_controller.dart';
import '../../widgets/noir_modal.dart';


/// La stanza online prima della partita, nella saletta riservata del caffè:
/// il tavolo con chi è già seduto (volti e nomi, dal vivo), il codice grande
/// e il QR per chi deve ancora entrare, la chat. Toccando qualcuno al tavolo
/// si apre il suo fascicolo (profilo, segnalazione, blocco); il «+» gli
/// chiede l'amicizia. Il padrone di casa dà le carte; a chi aspetta, la
/// partita si apre da sola quando comincia. I bot non li sceglie nessuno:
/// nel periodo di prova li mette il server.
///
/// Uscendo dalla schermata si esce anche dalla stanza.
class OnlineRoomScreen extends StatefulWidget {
  final OnlineServices services;
  final Room room;
  final Profile me;

  const OnlineRoomScreen({super.key, required this.services, required this.room, required this.me});

  @override
  State<OnlineRoomScreen> createState() => _OnlineRoomScreenState();
}

class _OnlineRoomScreenState extends State<OnlineRoomScreen> with ScreenMusic {
  @override
  MusicMood get screenMood => MusicMood.menu;

  /// Dalla partita ai risultati la musica della vittoria resta: la stanza
  /// rimette la sua solo quando i risultati se ne vanno.
  @override
  bool get musicHeld => _afterGame;
  bool _afterGame = false;

  late Room _room = widget.room;
  List<RoomMember> _members = const [];

  /// La voce della stanza (la stessa che la partita usa sopra): nella stanza
  /// ognuno è il suo posto, "m3".
  late final VoiceDirectory _voiceSeats = (
    profileOf: (String id) => _memberAt(id)?.profile.id,
    nameOf: (String id) => _memberAt(id)?.profile.name,
  );
  late final VoiceController? _voice = switch (widget.services.voice) {
    final source? => VoiceController.acquire(source, widget.room.id, directory: _voiceSeats),
    null => null,
  };

  RoomMember? _memberAt(String identity) =>
      _members.where((m) => identity == 'm${m.seat}').firstOrNull;

  void _voicePhase() => _voice?.phase('${_room.status.name}|${[for (final m in _members) m.seat]}', from: this);
  StreamSubscription<List<RoomMember>>? _watch;
  StreamSubscription<List<ChatMessage>>? _chatWatch;
  List<ChatMessage> _chat = const [];

  /// Con chi c'è già un legame (amici o richiesta in corso): niente pulsante.
  final Set<String> _linked = {};
  bool _left = false;

  /// Vero mentre la schermata della partita è aperta sopra la stanza.
  bool _inGame = false;
  bool _busy = false;

  /// Vero se si è usciti dalla partita mentre era ancora in corso: allora
  /// non ci si risiede da soli, si rientra col pulsante.
  bool _stayedOut = false;

  /// Meno persone di così non si danno le carte. Nel periodo di prova ne
  /// bastano due: i posti vuoti li riempie il server con i bot (il server
  /// decide, qui si mostra solo il pulsante acceso).
  static const minPlayers = botsEnabled ? 2 : 4;

  @override
  void initState() {
    super.initState();
    _watch = widget.services.rooms
        .watchMembers(_room.id)
        .listen(
          _seated,
          onError: (Object error) {
            if (mounted) showFailure(context, error);
          },
        );
    _chatWatch = widget.services.game.watchChat(_room.id).listen(
      (messages) {
        if (mounted) setState(() => _chat = [for (final m in messages) if (m.channel == ChatChannel.lobby) m]);
      },
      onError: (Object _) {},
    );
    _loadFriends();
    _voicePhase();
    // Chi rientra in una stanza che sta già giocando torna al tavolo.
    if (_room.status == RoomStatus.playing) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _joinGame());
    }
  }

  Future<void> _loadFriends() async {
    try {
      final links = await widget.services.friends.list();
      if (mounted) setState(() => _linked.addAll(links.map((link) => link.other.id)));
    } catch (_) {
      // Senza l'elenco degli amici si vede solo qualche pulsante in più.
    }
  }

  Future<void> _seated(List<RoomMember> members) async {
    setState(() => _members = members);
    _voicePhase();
    // Chi è padrone di casa può cambiare quando qualcuno esce.
    try {
      final room = await widget.services.rooms.fetch(_room.id);
      if (room != null && mounted) {
        setState(() {
          _room = room;
          if (room.status != RoomStatus.playing) _stayedOut = false;
        });
        _voicePhase();
        if (room.status == RoomStatus.playing && !_inGame && !_stayedOut) _joinGame();
      }
    } catch (_) {}
  }

  bool get _isHost => _room.hostId == widget.me.id;

  /// Il padrone di casa apre la partita: le carte le dà il server, e da lì
  /// in poi il suo telefono è uno come gli altri.
  Future<void> _start() async {
    if (_busy || _inGame) return;
    HapticFeedback.mediumImpact();
    // Da subito: la stanza che passa a «si gioca» non deve aprire la
    // partita due volte.
    _inGame = true;
    setState(() => _busy = true);
    try {
      await widget.services.game.startGame(_room.id);
    } catch (error) {
      _inGame = false;
      if (mounted) {
        setState(() => _busy = false);
        showFailure(context, error);
      }
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    await _showGame();
  }

  /// La partita è cominciata (o si rientra): ci si siede.
  Future<void> _joinGame() async {
    if (_inGame || !mounted) return;
    _inGame = true;
    _stayedOut = false;
    await _showGame();
  }

  Future<void> _showGame() async {
    final started = DateTime.now().subtract(const Duration(seconds: 5));
    _afterGame = true;
    try {
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => OnlineGameScreen(services: widget.services, room: _room, me: widget.me),
      ));
      _inGame = false;
      if (mounted) await showMatchResults(context, widget.services, since: started);
    } finally {
      _afterGame = false;
      // Fuori dai risultati la vittoria si spegne: torna la musica della stanza.
      if (mounted) playScreenMusic();
    }
    try {
      final room = await widget.services.rooms.fetch(_room.id);
      if (room != null && mounted) {
        setState(() {
          _room = room;
          _stayedOut = room.status == RoomStatus.playing;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _stayedOut = _room.status == RoomStatus.playing);
    }
  }

  @override
  void dispose() {
    _watch?.cancel();
    _chatWatch?.cancel();
    _voice?.release(directory: _voiceSeats);
    // Uscita senza un gesto (l'app che si chiude): la stanza passa da sola
    // al primo arrivato, nessuno resta senza padrone di casa.
    if (!_left) widget.services.rooms.leave(_room.id, autoHeir: true).ignore();
    super.dispose();
  }

  /// Quanto si aspetta il server prima di uscire comunque dalla stanza.
  static const leaveTimeout = Duration(seconds: 6);

  /// Uscire è una scelta: prima si conferma, e il padrone di casa con altra
  /// gente al tavolo sceglie a chi lasciare la stanza.
  Future<void> _askToLeave() async {
    if (_left) return;
    final t = AppStrings.of(context).online;
    final others = [
      for (final member in _members)
        if (member.profile.id != widget.me.id) member,
    ];
    String? heir;
    if (_room.hostId == widget.me.id && others.isNotEmpty) {
      heir = await showNoirMenu<String>(
        context,
        title: t.chooseHostTitle,
        subtitle: t.chooseHostBody,
        items: [
          for (final member in others)
            NoirMenuItem(
              key: Key('online.heir.${member.profile.id}'),
              value: member.profile.id,
              icon: Icons.vpn_key_outlined,
              label: member.profile.name,
            ),
        ],
      );
      if (heir == null || !mounted) return;
    } else {
      final sure = await confirmNoir(
        context,
        title: t.leaveConfirmTitle,
        body: t.leaveConfirmBody,
        icon: Icons.door_back_door_outlined,
        cancel: t.stay,
        confirm: t.leaveConfirm,
        confirmKey: const Key('online.leaveConfirm'),
      );
      if (!sure || !mounted) return;
    }
    try {
      await widget.services.rooms.leave(_room.id, newHostId: heir).timeout(leaveTimeout);
    } on TimeoutException {
      // Il server non risponde: si esce lo stesso, l'uscita resta in viaggio
      // (e la stanza passa da sola al primo arrivato).
    } catch (error) {
      if (mounted) showFailure(context, error);
      return;
    }
    _left = true;
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _addFriend(Profile other) async {
    HapticFeedback.selectionClick();
    final t = AppStrings.of(context).online;
    try {
      final status = await widget.services.friends.request(other.id);
      if (!mounted) return;
      setState(() => _linked.add(other.id));
      showNote(context, status == FriendStatus.accepted ? t.nowFriends(other.name) : t.friendRequestSent(other.name));
    } catch (error) {
      if (mounted) showFailure(context, error);
    }
  }

  /// Chi siede, nell'ordine della stanza, poi i bot (solo a partita aperta:
  /// li mette il server quando si danno le carte).
  List<CafeGuest> _guests() => [
        for (final member in _members)
          CafeGuest(
            profile: member.profile,
            host: member.profile.id == _room.hostId,
            me: member.profile.id == widget.me.id,
            canBefriend: member.profile.id != widget.me.id && !_linked.contains(member.profile.id),
          ),
        for (var i = 0; i < _room.bots; i++) CafeGuest(profile: Profile(id: 'bot-$i', handle: botName(i)), bot: true),
      ];

  /// Vero mentre si gioca: la stanza è solo la porta per tornare al tavolo
  /// (niente invito, niente chat della stanza, niente voce della stanza).
  bool get _playing => _room.status == RoomStatus.playing;

  /// Il pulsante grande per parlare, sopra la chat (col microfono scelto).
  /// Mentre si gioca la voce è quella del tavolo: si parla solo da lì.
  Widget? _talk({required bool desk}) {
    final voice = _voice;
    if (voice == null || _playing) return null;
    return ListenableBuilder(
      listenable: voice,
      builder: (context, _) => !VoiceTalkButton.shows(voice)
          ? const SizedBox.shrink()
          : Padding(
              padding: desk ? const EdgeInsets.only(bottom: DeskSize.gap) : const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: VoiceTalkButton(controller: voice, direction: Axis.horizontal),
              ),
            ),
    );
  }

  /// Un volto al tavolo della stanza: il foglio del giocatore.
  void _guestActions(CafeGuest guest) {
    final seat = _members.where((m) => m.profile.id == guest.profile.id).firstOrNull?.seat;
    showPlayerActions(
      context,
      services: widget.services,
      profileId: guest.profile.id,
      name: guest.profile.name,
      myId: widget.me.id,
      voice: seat == null ? null : voiceMuteFor(context, _voice, 'm$seat'),
      status: guest.host ? AppStrings.of(context).online.hostBadge : SafetyStrings.of(context).inRoom,
      canBefriend: guest.canBefriend,
    );
  }

  Widget _table() => CafeTable(
        key: const Key('online.table'),
        guests: _guests(),
        size: _room.maxPlayers,
        befriendLabel: AppStrings.of(context).online.addFriend,
        onGuest: _guestActions,
        onBefriend: (guest) => _addFriend(guest.profile),
      );

  String? get _hostName {
    for (final member in _members) {
      if (member.profile.id == _room.hostId) return member.profile.name;
    }
    return null;
  }

  /// Il QR su carta crema.
  Widget _qr(double size) => DecoratedBox(
        decoration: BoxDecoration(
          color: Cafe.cream,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Saloon.brassDeep, width: 1.5),
          boxShadow: [BoxShadow(color: Saloon.brass.withValues(alpha: 0.18), blurRadius: 24)],
        ),
        child: Padding(
          padding: EdgeInsets.all(size * 0.06),
          child: QrImageView(
            data: JoinCode.qrPayload(_room.code),
            size: size,
            padding: EdgeInsets.zero,
            backgroundColor: Cafe.cream,
            eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Saloon.paperInk),
            dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Saloon.paperInk),
            semanticsLabel: _room.code,
          ),
        ),
      );

  /// L'invito: il QR, il codice grande d'ottone e come si usa.
  Widget _invite({required bool desk}) {
    final t = AppStrings.of(context).online;
    final d = DesktopOnlineStrings.of(context);
    return CafePanel(
      title: desk ? d.invite : null,
      child: Row(
        children: [
          _qr(desk ? 176 : 96),
          SizedBox(width: desk ? 32 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.codeLabel.toUpperCase(),
                  style: desk
                      ? DeskText.overline(color: AppColors.textSecondary)
                      : AppText.overline.copyWith(color: AppColors.textSecondary, fontSize: 10, letterSpacing: 2.4),
                ),
                SizedBox(height: desk ? 8 : 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: SelectableText(
                    _room.code,
                    key: const Key('online.roomCode'),
                    style: AppText.display(desk ? 68 : 38, color: Saloon.brass)
                        .copyWith(letterSpacing: desk ? 12 : 6, shadows: const [Shadow(color: Colors.black, blurRadius: 8)]),
                  ),
                ),
                SizedBox(height: desk ? 10 : 4),
                Text(
                  t.roomShareHint,
                  style: desk
                      ? DeskText.text(size: DeskText.label, color: AppColors.textSecondary)
                      : AppText.body.copyWith(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Quanti siedono, chi tiene la stanza e cosa si aspetta.
  Widget _status({required bool desk}) {
    final t = AppStrings.of(context).online;
    final people = _members.length;
    final host = _hostName;
    final lobby = _room.status == RoomStatus.lobby;
    final String line;
    final bool lit;
    if (!lobby) {
      line = t.gameRunning;
      lit = false;
    } else if (!_isHost) {
      line = t.waitingForHost;
      lit = false;
    } else if (people < minPlayers) {
      line = t.startNeeds(minPlayers);
      lit = false;
    } else {
      line = botsEnabled ? t.testBotsNote : t.startGame;
      lit = !botsEnabled;
    }
    final secondary = desk ? DeskText.text(size: DeskText.label, color: AppColors.textSecondary) : AppText.body.copyWith(fontSize: 12, color: AppColors.textSecondary);
    return Column(
      crossAxisAlignment: desk ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Semantics(
          liveRegion: true,
          child: Text(
            t.roomSeated(people + _room.bots, _room.maxPlayers),
            key: const Key('online.seats'),
            textAlign: desk ? TextAlign.start : TextAlign.center,
            style: desk ? DeskText.display(DeskText.heading, color: Saloon.paper) : AppText.overline.copyWith(color: Saloon.paper, fontSize: 12),
          ),
        ),
        SizedBox(height: desk ? 10 : 2),
        if (host != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.vpn_key, size: desk ? 20 : 13, color: Saloon.brass),
              SizedBox(width: desk ? 8 : 5),
              Text(
                t.hostBadge,
                style: desk
                    ? DeskText.overline(color: Saloon.brass)
                    : AppText.overline.copyWith(color: Saloon.brass, fontSize: 10, letterSpacing: 2),
              ),
              SizedBox(width: desk ? 10 : 6),
              Flexible(
                child: Text(host, maxLines: 1, overflow: TextOverflow.ellipsis, style: secondary.copyWith(color: Saloon.paper)),
              ),
            ],
          ),
        SizedBox(height: desk ? 10 : 4),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Text(
            line,
            key: lobby && !_isHost ? const Key('online.waitingForHost') : ValueKey(line),
            textAlign: desk ? TextAlign.start : TextAlign.center,
            style: (desk ? DeskText.text(size: DeskText.lead) : AppText.body.copyWith(fontSize: 13)).copyWith(
              color: lit ? Saloon.brass : AppColors.textSecondary,
              fontWeight: lit ? FontWeight.w700 : null,
            ),
          ),
        ),
      ],
    );
  }

  /// Il grande pulsante: dare le carte (il padrone di casa) o tornare al
  /// tavolo. Chi aspetta non ha pulsante.
  Widget? _cta({required bool desk}) {
    final t = AppStrings.of(context).online;
    if (_room.status == RoomStatus.playing && !_inGame) {
      return NoirButton(
        key: const Key('online.rejoinTable'),
        icon: Icons.login,
        label: t.rejoin,
        onPressed: _joinGame,
      );
    }
    if (!_isHost || _room.status != RoomStatus.lobby) return null;
    return NoirButton(
      key: const Key('online.start'),
      icon: Icons.style,
      label: t.startGame,
      feel: Press.confirm,
      onPressed: _busy || _members.length < minPlayers ? null : _start,
    );
  }

  Widget _chatBox({required bool desk}) {
    final t = AppStrings.of(context).online;
    return ChatPanel(
      key: const Key('online.lobbyChat'),
      title: t.chatLobby,
      messages: _chat,
      myId: widget.me.id,
      accent: Saloon.brass,
      decoration: Saloon.scrim(radius: desk ? DeskSize.radius : 14),
      note: _room.status == RoomStatus.lobby ? null : t.chatNightClosed,
      hint: t.chatHint,
      empty: t.chatEmpty,
      sendLabel: t.chatSend,
      trailing: _voice == null
          ? null
          : VoiceDock(
              controller: _voice,
              onPerson: (id) {
                if (_memberAt(id)?.profile case final p?) {
                  showPlayerActions(context, services: widget.services, profileId: p.id, name: p.name, myId: widget.me.id);
                }
              },
            ),
      onSend: (body) => widget.services.game.sendChat(_room.id, ChatChannel.lobby, body),
      onHold: (message) => showPlayerActions(
        context,
        services: widget.services,
        profileId: message.profileId,
        name: message.name,
        myId: widget.me.id,
        message: message,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _left,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _askToLeave();
      },
      child: DesktopCanvas.of(context) ? _desk(context) : _phone(context),
    );
  }

  /// Sul telefono, come la sala d'attesa della classificata: il tavolo
  /// riservato in alto, sotto quanti siedono, l'invito, il pulsante grande,
  /// la chat e l'uscita. Tutto scorre se lo schermo è basso.
  Widget _phone(BuildContext context) {
    final t = AppStrings.of(context).online;
    final cta = _cta(desk: false);
    return CafeScaffold(
      title: t.roomTitle,
      onBack: _askToLeave,
      child: LayoutBuilder(
        builder: (context, box) => SingleChildScrollView(
          padding: EdgeInsets.only(bottom: 16 + MediaQuery.paddingOf(context).bottom),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: (box.maxHeight * 0.5).clamp(300.0, 460.0),
                    child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: _table()),
                  ),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: _status(desk: false)),
                  if (!_playing) ...[
                    const SizedBox(height: 14),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: _invite(desk: false)),
                  ],
                  if (cta != null) ...[
                    const SizedBox(height: 14),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: cta),
                  ],
                  ?_talk(desk: false),
                  if (!_playing) ...[
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: SizedBox(height: 220, child: _chatBox(desk: false)),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: NoirButton(
                      key: const Key('online.leave'),
                      kind: NoirButtonKind.brass,
                      compact: true,
                      icon: Icons.door_back_door_outlined,
                      label: t.leaveRoom,
                      onPressed: _askToLeave,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Sul PC, come la sala d'attesa della classificata: il tavolo grande a
  /// sinistra; a destra l'invito, chi siede, la chat e il pulsante grande.
  Widget _desk(BuildContext context) {
    final t = AppStrings.of(context).online;
    final cta = _cta(desk: true);
    return CafeDesk(
      title: t.roomTitle,
      onBack: _askToLeave,
      actions: [
        SizedBox(
          width: 360,
          child: NoirButton(
            key: const Key('online.leave'),
            kind: NoirButtonKind.brass,
            compact: true,
            icon: Icons.door_back_door_outlined,
            label: t.leaveRoom,
            onPressed: _askToLeave,
          ),
        ),
      ],
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _table()),
          const SizedBox(width: 48),
          SizedBox(
            width: 660,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!_playing) ...[
                  _invite(desk: true),
                  const SizedBox(height: DeskSize.gap),
                ],
                CafePanel(child: _status(desk: true)),
                const SizedBox(height: DeskSize.gap),
                ?_talk(desk: true),
                Expanded(child: _playing ? const SizedBox.shrink() : _chatBox(desk: true)),
                if (cta != null) ...[const SizedBox(height: DeskSize.gap), cta],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
