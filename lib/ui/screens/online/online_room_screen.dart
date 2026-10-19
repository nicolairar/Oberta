import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../l10n/app_strings.dart';
import '../../../online/game/bot_brain.dart';
import '../../../online/join_code.dart';
import '../../../online/online_services.dart';
import '../../theme/app_theme.dart';
import '../../widgets/scene_scaffold.dart';
import 'chat_panel.dart';
import 'online_game_screen.dart';
import 'match_results_screen.dart' show showMatchResults;
import 'online_widgets.dart';
import 'safety_sheets.dart';
import '../../../l10n/safety_strings.dart';

/// La stanza online prima della partita: il codice grande e il QR per chi
/// deve ancora entrare, e la fila di chi è già seduto, aggiornata dal vivo.
/// Da qui si chiede l'amicizia a chi siede al tavolo. Il padrone di casa
/// mette i bot di prova e dà le carte; a chi aspetta, la partita si apre da
/// sola quando comincia.
///
/// Sotto, la chat della stanza.
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

class _OnlineRoomScreenState extends State<OnlineRoomScreen> {
  late Room _room = widget.room;
  List<RoomMember> _members = const [];
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

  /// Meno di così non si danno le carte.
  static const minPlayers = 4;

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
    // Chi è padrone di casa può cambiare quando qualcuno esce.
    try {
      final room = await widget.services.rooms.fetch(_room.id);
      if (room != null && mounted) {
        setState(() {
          _room = room;
          if (room.status != RoomStatus.playing) _stayedOut = false;
        });
        if (room.status == RoomStatus.playing && !_inGame && !_stayedOut) _joinGame();
      }
    } catch (_) {}
  }

  bool get _isHost => _room.hostId == widget.me.id;

  Future<void> _setBots(int count) async {
    if (_busy) return;
    HapticFeedback.selectionClick();
    setState(() => _busy = true);
    try {
      await widget.services.game.setBots(_room.id, count);
      final room = await widget.services.rooms.fetch(_room.id);
      if (room != null && mounted) setState(() => _room = room);
    } catch (error) {
      if (mounted) showFailure(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

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
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => OnlineGameScreen(services: widget.services, room: _room, me: widget.me),
    ));
    _inGame = false;
    if (mounted) await showMatchResults(context, widget.services);
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
    // Uscita senza un gesto (l'app che si chiude): la stanza passa da sola
    // al primo arrivato, nessuno resta senza padrone di casa.
    if (!_left) widget.services.rooms.leave(_room.id, autoHeir: true).ignore();
    super.dispose();
  }

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
      heir = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: AppColors.surface,
        builder: (context) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            children: [
              Text(t.chooseHostTitle, style: AppText.display(22, color: AppColors.textPrimary)),
              const SizedBox(height: 6),
              Text(t.chooseHostBody, style: AppText.body),
              const SizedBox(height: 12),
              for (final member in others)
                ListTile(
                  key: Key('online.heir.${member.profile.id}'),
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.vpn_key, color: AppColors.gold),
                  title: Text(member.profile.name, style: AppText.body),
                  onTap: () => Navigator.of(context).pop(member.profile.id),
                ),
            ],
          ),
        ),
      );
      if (heir == null || !mounted) return;
    } else {
      final sure = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(t.leaveConfirmTitle, style: AppText.display(22, color: AppColors.textPrimary)),
          content: Text(t.leaveConfirmBody, style: AppText.body),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(t.stay)),
            TextButton(
              key: const Key('online.leaveConfirm'),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                t.leaveConfirm,
                style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
      if (sure != true || !mounted) return;
    }
    try {
      await widget.services.rooms.leave(_room.id, newHostId: heir);
      _left = true;
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) showFailure(context, error);
    }
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

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final t = strings.online;
    return PopScope(
      canPop: _left,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _askToLeave();
      },
      child: SceneScaffold(
        appBar: AppBar(title: Text(t.roomTitle)),
        body: OnlineBody(
          children: [
            OnlinePanel(
              child: Column(
                children: [
                  Text(t.codeLabel.toUpperCase(), style: AppText.overline),
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: SelectableText(
                      _room.code,
                      key: const Key('online.roomCode'),
                      style: AppText.display(46, color: AppColors.gold).copyWith(letterSpacing: 10),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DecoratedBox(
                    decoration: BoxDecoration(color: const Color(0xFFEDE2C8), borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: QrImageView(
                        data: JoinCode.qrPayload(_room.code),
                        size: 180,
                        backgroundColor: const Color(0xFFEDE2C8),
                        eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF14110F)),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: Color(0xFF14110F),
                        ),
                        semanticsLabel: _room.code,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(t.roomShareHint, textAlign: TextAlign.center, style: AppText.body),
                ],
              ),
            ),
            OnlineSection(t.roomSeated(_members.length, _room.maxPlayers)),
            OnlinePanel(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Column(
                children: [
                  for (final member in _members)
                    ProfileRow(
                      key: ValueKey(member.profile.id),
                      profile: member.profile,
                      badges: [
                        if (member.profile.id == _room.hostId) OnlineBadge(t.hostBadge),
                        if (member.profile.id == widget.me.id)
                          OnlineBadge(strings.youBadge, color: AppColors.textSecondary),
                      ],
                      trailing: member.profile.id == widget.me.id
                          ? null
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!_linked.contains(member.profile.id))
                                  IconButton(
                                    tooltip: t.addFriend,
                                    icon: const Icon(Icons.person_add_alt_1, color: AppColors.gold),
                                    onPressed: () => _addFriend(member.profile),
                                  ),
                                if (widget.services.safety != null)
                                  IconButton(
                                    key: Key('online.memberActions.${member.profile.id}'),
                                    tooltip: SafetyStrings.of(context).report,
                                    icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
                                    onPressed: () => showPlayerActions(
                                      context,
                                      services: widget.services,
                                      profileId: member.profile.id,
                                      name: member.profile.name,
                                      myId: widget.me.id,
                                    ),
                                  ),
                              ],
                            ),
                    ),
                  for (var i = 0; i < _room.bots; i++)
                    ProfileRow(
                      key: ValueKey('bot-$i'),
                      profile: Profile(id: 'bot-$i', handle: botName(i)),
                      badges: [OnlineBadge(t.botBadge, color: AppColors.textSecondary)],
                      trailing: _isHost && _room.status == RoomStatus.lobby
                          ? IconButton(
                              key: Key('online.removeBot.$i'),
                              tooltip: t.removeBot,
                              icon: const Icon(Icons.remove_circle_outline, color: AppColors.textSecondary),
                              onPressed: _busy ? null : () => _setBots(_room.bots - 1),
                            )
                          : null,
                    ),
                ],
              ),
            ),
            if (_isHost && botsEnabled && _room.status == RoomStatus.lobby) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const Key('online.addBot'),
                onPressed: _busy || _members.length + _room.bots >= _room.maxPlayers || _room.bots >= maxBots
                    ? null
                    : () => _setBots(_room.bots + 1),
                icon: const Icon(Icons.smart_toy_outlined),
                label: Text(t.addBot),
              ),
            ],
            const SizedBox(height: 24),
            if (_room.status == RoomStatus.playing && !_inGame)
              ElevatedButton.icon(
                key: const Key('online.rejoinTable'),
                onPressed: _joinGame,
                icon: const Icon(Icons.login),
                label: Text(t.rejoin),
              )
            else if (_isHost) ...[
              ElevatedButton(
                key: const Key('online.start'),
                onPressed: _busy || _members.length + _room.bots < minPlayers ? null : _start,
                child: Text(t.startGame),
              ),
              if (_members.length + _room.bots < minPlayers) ...[
                const SizedBox(height: 8),
                Text(t.startNeeds(minPlayers), textAlign: TextAlign.center, style: AppText.body),
              ],
            ] else
              Text(t.waitingForHost, key: const Key('online.waitingForHost'), textAlign: TextAlign.center, style: AppText.body),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: ChatPanel(
                key: const Key('online.lobbyChat'),
                title: t.chatLobby,
                messages: _chat,
                myId: widget.me.id,
                note: _room.status == RoomStatus.lobby ? null : t.chatNightClosed,
                hint: t.chatHint,
                empty: t.chatEmpty,
                sendLabel: t.chatSend,
                onSend: (body) => widget.services.game.sendChat(_room.id, ChatChannel.lobby, body),
                onHold: (message) => showPlayerActions(
                  context,
                  services: widget.services,
                  profileId: message.profileId,
                  name: message.name,
                  myId: widget.me.id,
                  message: message,
                ),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _askToLeave, child: Text(t.leaveRoom)),
          ],
        ),
      ),
    );
  }
}
