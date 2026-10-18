import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_language.dart';
import '../../../l10n/app_strings.dart';
import '../../../online/online_services.dart';
import '../../../rules/role.dart';
import '../../theme/app_theme.dart';
import 'game/chat_dock.dart';
import 'game/noir_ui.dart';
import 'online_game_screen.dart';
import 'online_widgets.dart';
import 'ranked_lobby.dart';

/// La classificata: lingua, poi subito la sala d'attesa. Il server fa
/// sedere chi entra al tavolo di una sala (stessa lingua, livello vicino):
/// i posti si riempiono dal vivo, a tavolo pieno parte il conto alla
/// rovescia, poi la partita. Mentre si aspetta: la chat della sala, i
/// consigli e le carte dei ruoli. Uscire prima dell'inizio non costa nulla.
///
/// Chiusa in questa build: ci si arriva solo con RANKED_DEBUG.
class RankedQueueScreen extends StatefulWidget {
  final OnlineServices services;
  final Duration poll;

  const RankedQueueScreen({super.key, required this.services, this.poll = const Duration(seconds: 2)});

  @override
  State<RankedQueueScreen> createState() => _RankedQueueScreenState();
}

class _RankedQueueScreenState extends State<RankedQueueScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  AppLanguage _language = AppLanguage.it;
  RankedStatus _status = const RankedStatus();
  Timer? _timer;
  Timer? _second;

  /// Quarti di secondo passati qui (per i consigli che girano e il conto).
  int _ticks = 0;

  /// Ora del server meno ora del telefono (vedi [GameClient.serverNow]).
  Duration _offset = Duration.zero;
  Duration? _bestTrip;
  final ValueNotifier<int> _chatVersion = ValueNotifier(0);
  bool _entering = false;

  /// La sala d'attesa in cui si siede, con chi c'è e la sua chat.
  Room? _lobby;
  List<RoomMember> _members = const [];
  List<ChatMessage> _chat = const [];
  StreamSubscription<List<RoomMember>>? _membersWatch;
  StreamSubscription<List<ChatMessage>>? _chatWatch;
  String? _myId;

  RankedRepository get _ranked => widget.services.ranked!;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(widget.poll, (_) => _refresh());
    _second = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted) setState(() => _ticks++);
    });
    widget.services.profiles.me().then((me) {
      if (mounted) setState(() => _myId = me.id);
    }).ignore();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _second?.cancel();
    _sweep.dispose();
    _chatVersion.dispose();
    _unwatch();
    if (_status.queued || _lobby != null) unawaited(_ranked.leave().catchError((_) {}));
    super.dispose();
  }

  void _unwatch() {
    _membersWatch?.cancel();
    _chatWatch?.cancel();
    _membersWatch = null;
    _chatWatch = null;
  }

  void _watch(String roomId) {
    _unwatch();
    _membersWatch = widget.services.rooms.watchMembers(roomId).listen((members) {
      if (mounted) setState(() => _members = members);
    }, onError: (Object _) {});
    _chatWatch = widget.services.game.watchChat(roomId).listen((messages) {
      if (mounted) {
        setState(
          () => _chat = [
            for (final m in messages)
              if (m.channel == ChatChannel.lobby) m,
          ],
        );
        _chatVersion.value++;
      }
    }, onError: (Object _) {});
    _bestTrip = null;
    _ping(roomId);
  }

  /// L'ora del server, per il conto alla rovescia: il telefono può sbagliare.
  DateTime get _serverNow => DateTime.now().add(_offset);

  Future<void> _ping(String roomId) async {
    try {
      final sent = DateTime.now();
      final server = await widget.services.game.ping(roomId);
      final trip = DateTime.now().difference(sent);
      if (_bestTrip == null || trip <= _bestTrip!) {
        _bestTrip = trip;
        _offset = DateTime.fromMillisecondsSinceEpoch(server).difference(sent.add(trip ~/ 2));
      }
    } catch (_) {
      // Senza risposta si resta sull'ora del telefono.
    }
  }

  Future<void> _refresh() async {
    if (_entering) return;
    try {
      final status = await _ranked.status();
      if (!mounted) return;
      final roomId = status.roomId;
      Room? room;
      if (roomId != null) room = await widget.services.rooms.fetch(roomId);
      if (!mounted) return;
      if (room != null && room.status == RoomStatus.playing) {
        setState(() => _status = status);
        await _enter(room);
        return;
      }
      if (room?.id != _lobby?.id) {
        if (room == null) {
          _unwatch();
          _members = const [];
          _chat = const [];
        } else {
          _watch(room.id);
        }
      }
      setState(() {
        _status = status;
        _lobby = room;
      });
    } catch (_) {
      // La rete torna: il prossimo giro riprova.
    }
  }

  Future<void> _start() async {
    HapticFeedback.selectionClick();
    try {
      final status = await _ranked.enqueue(_language);
      if (mounted) setState(() => _status = status);
      await _refresh();
    } catch (error) {
      if (mounted) showFailure(context, error);
    }
  }

  Future<void> _cancel() async {
    HapticFeedback.selectionClick();
    try {
      await _ranked.leave();
      _unwatch();
      if (mounted) {
        setState(() {
          _status = const RankedStatus();
          _lobby = null;
          _members = const [];
          _chat = const [];
        });
      }
    } catch (error) {
      if (mounted) showFailure(context, error);
    }
  }

  Future<void> _enter(Room room) async {
    if (_entering) return;
    _entering = true;
    _timer?.cancel();
    _unwatch();
    final navigator = Navigator.of(context);
    try {
      final me = await widget.services.profiles.me();
      if (!mounted) return;
      _status = const RankedStatus();
      _lobby = null;
      _members = const [];
      _chat = const [];
      HapticFeedback.heavyImpact();
      await navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => OnlineGameScreen(services: widget.services, room: room, me: me),
        ),
      );
      if (!mounted) return;
      await widget.services.rooms.leave(room.id, autoHeir: true).catchError((_) {});
      if (mounted) await showMatchResults(context, widget.services);
    } finally {
      _entering = false;
      if (mounted) {
        _timer = Timer.periodic(widget.poll, (_) => _refresh());
        setState(() {});
      }
    }
  }

  String _clock(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context).online;
    final lobby = _lobby;
    if (lobby != null) return _lobbyView(context, lobby);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(t.rankedQueueTitle), backgroundColor: AppColors.background),
      body: _queue(context),
    );
  }

  Widget _queue(BuildContext context) {
    final t = AppStrings.of(context).online;
    final cooldown = _status.cooldownUntil;
    return OnlineBody(
      children: [
        SizedBox(
          height: 220,
          child: AnimatedBuilder(
            animation: _sweep,
            builder: (context, _) => CustomPaint(painter: _SearchlightPainter(_status.queued ? _sweep.value : null)),
          ),
        ),
        const SizedBox(height: 16),
        if (_status.queued) ...[
          Text(t.rankedSearching, key: const Key('ranked.searching'), textAlign: TextAlign.center, style: AppText.display(20)),
          const SizedBox(height: 20),
          OutlinedButton(key: const Key('ranked.cancel'), onPressed: _cancel, child: Text(t.rankedCancel)),
        ] else ...[
          SegmentedButton<AppLanguage>(
            segments: const [
              ButtonSegment(value: AppLanguage.it, label: Text('Italiano')),
              ButtonSegment(value: AppLanguage.en, label: Text('English')),
            ],
            selected: {_language},
            onSelectionChanged: (s) => setState(() => _language = s.first),
          ),
          const SizedBox(height: 20),
          if (cooldown != null)
            Text(t.rankedCooldown(_clock(cooldown.difference(DateTime.now()))), textAlign: TextAlign.center, style: AppText.body)
          else
            FilledButton(key: const Key('ranked.start'), onPressed: _start, child: Text(t.rankedStart)),
        ],
        if (_status.warning) ...[
          const SizedBox(height: 16),
          Text(t.rankedWarning, textAlign: TextAlign.center, style: AppText.body.copyWith(fontSize: 12)),
        ],
      ],
    );
  }

  Widget _lobbyView(BuildContext context, Room lobby) {
    final strings = AppStrings.of(context);
    final t = strings.online;
    final size = lobby.maxPlayers;
    final startsAt = lobby.startsAt;
    final left = startsAt == null ? null : max(0, startsAt.difference(_serverNow).inMilliseconds) / 1000;
    final tips = t.rankedTips;
    final roles = Role.values;
    final slot = (_ticks ~/ 28) % (tips.length + roles.length);
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final lobbyView = ChatChannelView(channel: ChatChannel.lobby, title: t.chatLobby, accent: Saloon.brass);
    return Scaffold(
      backgroundColor: const Color(0xFF120C08),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.35),
            radius: 1.1,
            colors: [Color(0xFF3A2414), Color(0xFF1A100A), Color(0xFF0A0605)],
            stops: [0, 0.55, 1],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 2, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back, color: Saloon.brass),
                    ),
                    Expanded(
                      child: Text(
                        t.rankedLobbyTitle.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: AppText.overline.copyWith(color: Saloon.brass, fontSize: 13, letterSpacing: 3),
                      ),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
              ),
              if (lobby.testMatch)
                Text(
                  t.rankedTestMatch,
                  textAlign: TextAlign.center,
                  style: AppText.overline.copyWith(color: AppColors.gold),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: LobbyTable(key: const Key('ranked.table'), members: _members, size: size, myId: _myId, countdown: left?.toDouble()),
                ),
              ),
              Semantics(
                liveRegion: true,
                child: Text(
                  t.rankedSeats(_members.length, size),
                  key: const Key('ranked.seats'),
                  textAlign: TextAlign.center,
                  style: AppText.overline.copyWith(color: Saloon.paper, fontSize: 12),
                ),
              ),
              const SizedBox(height: 2),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Text(
                  left == null ? t.rankedMissing(max(0, size - _members.length)) : t.rankedStartsIn(left.ceil()),
                  key: ValueKey(left == null ? 'wait' : 'go${left.ceil()}'),
                  textAlign: TextAlign.center,
                  style: AppText.body.copyWith(
                    color: left == null ? AppColors.textSecondary : Saloon.brass,
                    fontWeight: left == null ? null : FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  height: 104,
                  child: AnimatedSwitcher(
                    duration: Duration(milliseconds: still ? 0 : 500),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween(
                          begin: const Offset(0.15, 0),
                          end: Offset.zero,
                        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                        child: child,
                      ),
                    ),
                    child: Align(
                      key: ValueKey('tip$slot'),
                      alignment: Alignment.center,
                      child: slot < tips.length
                          ? LobbyCard(kicker: t.rankedTipsTitle, title: '❦', body: tips[slot])
                          : Builder(
                              builder: (context) {
                                final role = strings.role(roles[slot - tips.length]);
                                return LobbyCard(kicker: role.motto, title: role.label.toUpperCase(), body: role.description);
                              },
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  width: double.infinity,
                  child: NoirButton(
                    key: const Key('ranked.leaveLobby'),
                    kind: NoirButtonKind.brass,
                    compact: true,
                    icon: Icons.door_back_door_outlined,
                    label: t.rankedLeaveLobby,
                    onPressed: _cancel,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                t.rankedNoPenalty,
                textAlign: TextAlign.center,
                style: AppText.body.copyWith(fontSize: 11, color: AppColors.textSecondary),
              ),
              ChatDock(
                key: const Key('ranked.lobbyChat'),
                view: lobbyView,
                messages: _chat,
                myId: _myId ?? '',
                labels: ChatLabels(hint: t.chatHint, empty: t.chatEmpty, send: t.chatSend),
                onSend: (body) => widget.services.game.sendChat(lobby.id, ChatChannel.lobby, body),
                source: _chatVersion,
                read: () => (view: lobbyView, messages: _chat),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Un faro che spazza una piazza di sagome: gira mentre si cerca.
class _SearchlightPainter extends CustomPainter {
  final double? turn;

  _SearchlightPainter(this.turn);

  @override
  void paint(Canvas canvas, Size size) {
    final ground = size.height * 0.82;
    final figures = Paint()..color = const Color(0xFF0B0908);
    for (var i = 0; i < 9; i++) {
      final x = size.width * (0.08 + i * 0.105);
      final h = 26.0 + (i * 37 % 13);
      canvas.drawCircle(Offset(x, ground - h - 7), 7, figures);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x - 9, ground - h, 18, h), const Radius.circular(6)), figures);
    }
    final t = turn;
    if (t == null) return;
    final origin = Offset(size.width / 2, 0);
    final angle = pi / 2 + sin(t * 2 * pi) * 0.7;
    final beam = Path()
      ..moveTo(origin.dx, origin.dy)
      ..lineTo(origin.dx + cos(angle - 0.18) * size.height * 1.3, sin(angle - 0.18) * size.height * 1.3)
      ..lineTo(origin.dx + cos(angle + 0.18) * size.height * 1.3, sin(angle + 0.18) * size.height * 1.3)
      ..close();
    canvas.drawPath(
      beam,
      Paint()
        ..shader = RadialGradient(colors: [AppColors.gold.withValues(alpha: 0.45), AppColors.gold.withValues(alpha: 0)])
            .createShader(Rect.fromCircle(center: origin, radius: size.height * 1.2)),
    );
  }

  @override
  bool shouldRepaint(_SearchlightPainter old) => old.turn != turn;
}

/// I risultati dell'ultima partita: esperienza, livello, monete e, in
/// classificata, se il grado sale o scende (il numero resta nascosto).
Future<void> showMatchResults(BuildContext context, OnlineServices services) async {
  final ranked = services.ranked;
  if (ranked == null) return;
  MatchResult? result;
  try {
    result = await ranked.lastResult();
  } catch (_) {
    return;
  }
  if (result == null || !context.mounted) return;
  final r = result;
  final t = AppStrings.of(context).online;
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    builder: (context) => SafeArea(
      child: Padding(
        key: const Key('results.sheet'),
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              t.resultsTitle,
              textAlign: TextAlign.center,
              style: AppText.overline.copyWith(color: AppColors.gold),
            ),
            if (r.testMatch) Text(t.rankedTestMatch, textAlign: TextAlign.center, style: AppText.body.copyWith(fontSize: 11)),
            const SizedBox(height: 8),
            Text(
              r.abandoned ? t.resultsLeft : (r.won ? t.resultsWon : t.resultsLost),
              textAlign: TextAlign.center,
              style: AppText.display(26, color: r.won ? AppColors.gold : AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            Text(t.resultsXp(r.xpGained), textAlign: TextAlign.center, style: AppText.body),
            if (r.leveledUp) Text(t.resultsLevelUp(r.levelAfter), textAlign: TextAlign.center, style: AppText.display(20)),
            if (r.coinsGained > 0) Text(t.resultsCoins(r.coinsGained), textAlign: TextAlign.center, style: AppText.body),
            if (r.ratingDelta case final delta?) ...[
              const SizedBox(height: 8),
              Text(
                '${delta >= 0 ? t.resultsRatingUp : t.resultsRatingDown} · ${t.tierName(r.tier!)}',
                textAlign: TextAlign.center,
                style: AppText.body,
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(onPressed: () => Navigator.of(context).pop(), child: Text(t.resultsContinue)),
          ],
        ),
      ),
    ),
  );
}
