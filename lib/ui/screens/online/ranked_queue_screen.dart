import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_language.dart';
import '../../../l10n/app_strings.dart';
import '../../../online/online_services.dart';
import '../../../rules/role.dart';
import '../../theme/app_theme.dart';
import '../../widgets/deal_table.dart' show PokerFelt;
import '../../widgets/noir_avatar.dart';
import 'chat_panel.dart';
import 'online_game_screen.dart';
import 'online_widgets.dart';

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
  int _seconds = 0;
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
    _second = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
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
    _membersWatch = widget.services.rooms.watchMembers(roomId).listen(
      (members) {
        if (mounted) setState(() => _members = members);
      },
      onError: (Object _) {},
    );
    _chatWatch = widget.services.game.watchChat(roomId).listen(
      (messages) {
        if (mounted) setState(() => _chat = [for (final m in messages) if (m.channel == ChatChannel.lobby) m]);
      },
      onError: (Object _) {},
    );
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
      await navigator.push(MaterialPageRoute<void>(
        builder: (_) => OnlineGameScreen(services: widget.services, room: room, me: me),
      ));
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(lobby == null ? t.rankedQueueTitle : t.rankedLobbyTitle),
        backgroundColor: AppColors.background,
      ),
      body: lobby == null ? _queue(context) : _lobbyView(context, lobby),
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
            builder: (context, _) => CustomPaint(
              painter: _SearchlightPainter(_status.queued ? _sweep.value : null),
            ),
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
    final left = startsAt == null ? null : max(0, startsAt.difference(DateTime.now()).inSeconds);
    final tips = t.rankedTips;
    final roles = Role.values;
    final slot = (_seconds ~/ 7) % (tips.length + roles.length);
    return OnlineBody(
      children: [
        if (lobby.testMatch)
          Text(t.rankedTestMatch, textAlign: TextAlign.center, style: AppText.overline.copyWith(color: AppColors.gold)),
        SizedBox(
          height: 280,
          child: LobbyTable(key: const Key('ranked.table'), members: _members, size: size, myId: _myId),
        ),
        const SizedBox(height: 8),
        Text(
          t.rankedSeats(_members.length, size),
          key: const Key('ranked.seats'),
          textAlign: TextAlign.center,
          style: AppText.display(24),
        ),
        const SizedBox(height: 4),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Text(
            left == null ? t.rankedMissing(max(0, size - _members.length)) : t.rankedStartsIn(left),
            key: ValueKey(left == null ? 'wait' : 'go$left'),
            textAlign: TextAlign.center,
            style: AppText.body.copyWith(color: left == null ? null : AppColors.gold, fontWeight: left == null ? null : FontWeight.w700),
          ),
        ),
        const SizedBox(height: 16),
        OnlineSection(t.rankedTipsTitle),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: OnlinePanel(
            key: ValueKey('tip$slot'),
            child: slot < tips.length
                ? Text(tips[slot], textAlign: TextAlign.center, style: AppText.body)
                : Builder(builder: (context) {
                    final role = strings.role(roles[slot - tips.length]);
                    return Column(
                      children: [
                        Text(role.label.toUpperCase(), style: AppText.display(20)),
                        const SizedBox(height: 2),
                        Text(role.motto, textAlign: TextAlign.center, style: AppText.body.copyWith(fontStyle: FontStyle.italic)),
                        const SizedBox(height: 6),
                        Text(role.description, textAlign: TextAlign.center, style: AppText.body.copyWith(fontSize: 13)),
                      ],
                    );
                  }),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 220,
          child: ChatPanel(
            key: const Key('ranked.lobbyChat'),
            title: t.chatLobby,
            messages: _chat,
            myId: _myId ?? '',
            note: null,
            hint: t.chatHint,
            empty: t.chatEmpty,
            sendLabel: t.chatSend,
            onSend: (body) => widget.services.game.sendChat(lobby.id, ChatChannel.lobby, body),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton(key: const Key('ranked.leaveLobby'), onPressed: _cancel, child: Text(t.rankedLeaveLobby)),
        const SizedBox(height: 6),
        Text(t.rankedNoPenalty, textAlign: TextAlign.center, style: AppText.body.copyWith(fontSize: 12)),
      ],
    );
  }
}

/// Il tavolo della sala d'attesa: lo stesso panno verde della partita, i
/// posti intorno; chi arriva compare al suo posto, i posti vuoti aspettano.
class LobbyTable extends StatelessWidget {
  final List<RoomMember> members;
  final int size;
  final String? myId;

  const LobbyTable({super.key, required this.members, required this.size, this.myId});

  @override
  Widget build(BuildContext context) {
    final bySeat = {for (final m in members) m.seat: m};
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth;
      final h = box.maxHeight;
      const avatar = 40.0;
      final table = Rect.fromCenter(center: Offset(w / 2, h / 2), width: w * 0.62, height: h * 0.5);
      final rx = w / 2 - avatar * 0.75;
      final ry = h / 2 - avatar * 0.75;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: CustomPaint(painter: _FeltPainter(table))),
          for (var i = 0; i < size; i++)
            Builder(builder: (context) {
              final angle = -pi / 2 + 2 * pi * i / size;
              final x = w / 2 + cos(angle) * rx;
              final y = h / 2 + sin(angle) * ry;
              final member = bySeat[i + 1];
              return Positioned(
                left: x - avatar / 2 - 10,
                top: y - avatar / 2,
                width: avatar + 20,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 450),
                  transitionBuilder: (child, animation) => ScaleTransition(
                    scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
                    child: FadeTransition(opacity: animation, child: child),
                  ),
                  child: member == null
                      ? Container(
                          key: ValueKey('empty$i'),
                          width: avatar,
                          height: avatar,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withValues(alpha: 0.25),
                            border: Border.all(color: AppColors.gold.withValues(alpha: 0.25)),
                          ),
                        )
                      : Column(
                          key: ValueKey(member.profile.id),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: member.profile.id == myId ? Border.all(color: AppColors.gold, width: 2) : null,
                              ),
                              child: NoirAvatar.drawn(seed: member.profile.avatarSeed, size: avatar),
                            ),
                            Text(
                              member.profile.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.body.copyWith(fontSize: 10, color: AppColors.textPrimary),
                            ),
                          ],
                        ),
                ),
              );
            }),
        ],
      );
    });
  }
}

class _FeltPainter extends CustomPainter {
  final Rect table;

  _FeltPainter(this.table);

  @override
  void paint(Canvas canvas, Size size) {
    final rim = table.shortestSide * 0.07;
    canvas.drawOval(
      table.inflate(rim).shift(Offset(0, rim)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.6)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, rim * 1.2),
    );
    canvas.drawOval(
      table.inflate(rim),
      Paint()..shader = const LinearGradient(colors: PokerFelt.wood).createShader(table.inflate(rim)),
    );
    canvas.drawOval(
      table,
      Paint()
        ..shader = const RadialGradient(colors: PokerFelt.felt, stops: [0, 0.6, 1]).createShader(table),
    );
  }

  @override
  bool shouldRepaint(_FeltPainter old) => old.table != table;
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
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x - 9, ground - h, 18, h), const Radius.circular(6)),
        figures,
      );
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
        ..shader = RadialGradient(
          colors: [AppColors.gold.withValues(alpha: 0.45), AppColors.gold.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: origin, radius: size.height * 1.2)),
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
            Text(t.resultsTitle, textAlign: TextAlign.center, style: AppText.overline.copyWith(color: AppColors.gold)),
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
