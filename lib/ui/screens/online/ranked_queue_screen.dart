import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../sound/screen_music.dart';
import '../../../sound/sound_stage.dart';
import '../../../l10n/app_language.dart';
import '../../../l10n/app_strings.dart';
import '../../../online/online_services.dart';
import '../../../rules/role.dart';
import '../../desktop/desktop_canvas.dart';
import '../../theme/app_theme.dart';
import 'game/noir_ui.dart';
import 'online_game_screen.dart';
import 'online_widgets.dart';
import 'match_results_screen.dart';
import 'ranked_entry.dart';
import 'leaderboard_screen.dart';
import 'ranked_lobby.dart';
import '../../widgets/wide_scale.dart';
import '../../widgets/content_width.dart';

/// La classificata: lingua, poi subito la sala d'attesa. Il server fa
/// sedere chi entra al tavolo di una sala (stessa lingua, livello vicino):
/// i posti si riempiono dal vivo, a tavolo pieno parte il conto alla
/// rovescia, poi la partita. Mentre si aspetta: i consigli e le carte dei
/// ruoli. Prima dell'inizio non si sa chi c'è (né nomi né facce, né chat:
/// lo garantisce anche il server), così nessuno se ne va per antipatia.
/// Uscire prima dell'inizio non costa nulla.
///
/// Chiusa in questa build: ci si arriva solo con RANKED_DEBUG.
class RankedQueueScreen extends StatefulWidget {
  final OnlineServices services;
  final Duration poll;

  const RankedQueueScreen({super.key, required this.services, this.poll = const Duration(seconds: 2)});

  @override
  State<RankedQueueScreen> createState() => _RankedQueueScreenState();
}

class _RankedQueueScreenState extends State<RankedQueueScreen> with SingleTickerProviderStateMixin, ScreenMusic {
  @override
  MusicMood get screenMood => MusicMood.menu;

  /// Dalla partita ai risultati la musica della vittoria resta.
  @override
  bool get musicHeld => _entering;

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
  bool _entering = false;

  /// La sala d'attesa in cui si siede: solo quanti sono, mai chi.
  Room? _lobby;
  StreamSubscription<List<RoomMember>>? _lobbyWatch;
  Profile? _me;

  /// Il proprio rating per lingua e quanti sono in coda (per le carte).
  Map<AppLanguage, Rating> _ratings = const {};
  OnlineCounts? _counts;

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
      if (mounted) setState(() => _me = me);
    }).ignore();
    _ranked.ratings().then((ratings) {
      if (mounted) setState(() => _ratings = ratings);
    }).ignore();
    _ranked.counts().then((counts) {
      if (mounted) setState(() => _counts = counts);
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
    _lobbyWatch?.cancel();
    _lobbyWatch = null;
  }

  void _watch(String roomId) {
    _unwatch();
    // Ogni cambio della sala (qualcuno si siede, il conto parte) fa rileggere
    // lo stato: chi sia l'altro non arriva, la policy mostra solo sé stessi.
    _lobbyWatch = widget.services.rooms.watchMembers(roomId).listen((_) => _refresh(), onError: (Object _) {});
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
      HapticFeedback.heavyImpact();
      final started = DateTime.now().subtract(const Duration(seconds: 5));
      await navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => OnlineGameScreen(services: widget.services, room: room, me: me),
        ),
      );
      if (!mounted) return;
      await widget.services.rooms.leave(room.id, autoHeir: true).catchError((_) {});
      if (mounted && await showMatchResults(context, widget.services, offerReplay: true, since: started) && mounted) _start();
    } finally {
      _entering = false;
      if (mounted) {
        // Fuori dai risultati la vittoria si spegne: torna la musica della coda.
        playScreenMusic();
        _timer = Timer.periodic(widget.poll, (_) => _refresh());
        setState(() {});
      }
    }
  }

  /// Sul PC: il tavolo grande a sinistra; a destra i posti, il conto, i
  /// consigli che girano e l'uscita (anche con Esc).
  Widget _deskLobby(
    BuildContext context,
    Room lobby, {
    required int seated,
    required double? left,
    required String status,
    required Widget card,
    required int slot,
    required bool still,
  }) {
    final t = AppStrings.of(context).online;
    final size = lobby.maxPlayers;
    return Scaffold(
      backgroundColor: const Color(0xFF120C08),
      body: NoirDesk(
        child: DeskTheme(
          child: DeskEscape(
            onEscape: _cancel,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.3, -0.2),
                  radius: 1.2,
                  colors: [Color(0xFF3A2414), Color(0xFF1A100A), Color(0xFF0A0605)],
                  stops: [0, 0.55, 1],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DeskTopBar(title: t.rankedLobbyTitle, onBack: _cancel),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(DeskSize.gutter, 0, DeskSize.gutter, DeskSize.gutter),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: LobbyTable(
                              key: const Key('ranked.table'),
                              seated: seated,
                              size: size,
                              me: _me,
                              countdown: left,
                            ),
                          ),
                          const SizedBox(width: 48),
                          Container(
                            width: 620,
                            padding: const EdgeInsets.fromLTRB(44, 40, 44, 40),
                            decoration: Saloon.scrim(radius: DeskSize.radius),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (lobby.testMatch) ...[
                                  Text(t.rankedTestMatch.toUpperCase(), style: DeskText.overline(color: AppColors.gold)),
                                  const SizedBox(height: 16),
                                ],
                                Semantics(
                                  liveRegion: true,
                                  child: Text(
                                    t.rankedSeats(seated, size),
                                    key: const Key('ranked.seats'),
                                    style: DeskText.display(DeskText.heading, color: Saloon.paper),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 250),
                                  layoutBuilder: (current, previous) => Stack(
                                    alignment: Alignment.centerLeft,
                                    children: [...previous, ?current],
                                  ),
                                  child: Text(
                                    status,
                                    key: ValueKey(left == null ? 'wait' : 'go${left.ceil()}'),
                                    style: DeskText.text(
                                      size: DeskText.lead,
                                      color: left == null ? AppColors.textSecondary : Saloon.brass,
                                      weight: left == null ? FontWeight.w400 : FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 40),
                                Expanded(
                                  child: Center(
                                    child: AnimatedSwitcher(
                                      duration: Duration(milliseconds: still ? 0 : 500),
                                      transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
                                      child: KeyedSubtree(key: ValueKey('tip$slot'), child: card),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 32),
                                NoirButton(
                                  key: const Key('ranked.leaveLobby'),
                                  kind: NoirButtonKind.brass,
                                  icon: Icons.door_back_door_outlined,
                                  label: t.rankedLeaveLobby,
                                  onPressed: _cancel,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  t.rankedNoPenalty,
                                  textAlign: TextAlign.center,
                                  style: DeskText.text(size: DeskText.label, color: AppColors.textSecondary),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  t.rankedStrangers,
                                  key: const Key('ranked.strangers'),
                                  textAlign: TextAlign.center,
                                  style: DeskText.text(size: DeskText.label, color: AppColors.textSecondary)
                                      .copyWith(fontStyle: FontStyle.italic),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
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

  String _clock(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) => WideScale(child: Builder(builder: _build));

  Widget _build(BuildContext context) {
    final t = AppStrings.of(context).online;
    final lobby = _lobby;
    if (lobby != null) return _lobbyView(context, lobby);
    final cooldown = _status.cooldownUntil;
    final ordinal = (_ratings[_language] ?? Rating.initial).ordinal;
    final tier = RankTier.of(ordinal);
    return RankedEntryView(
      language: _language,
      onLanguage: (language) => setState(() => _language = language),
      queued: _status.queued,
      sweep: _sweep,
      cooldown: cooldown == null ? null : t.rankedCooldown(_clock(cooldown.difference(DateTime.now()))),
      warning: _status.warning,
      onStart: _start,
      onCancel: _cancel,
      tier: tier,
      progress: tier.progress(ordinal),
      queuedCounts: _counts?.queued ?? const {},
      onLeaderboard: switch (widget.services.progress) {
        final progress? => () => LeaderboardScreen.open(context, progress, _language),
        null => null,
      },
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
    // Il server conta chi siede (sé compresi): mai meno di sé stessi.
    final seated = max(1, max(lobby.seated, _status.roomId == lobby.id ? _status.seated : 0));
    final status = left == null ? t.rankedMissing(max(0, size - seated)) : t.rankedStartsIn(left.ceil());
    final Widget card = slot < tips.length
        ? LobbyCard(kicker: t.rankedTipsTitle, title: '❦', body: tips[slot])
        : Builder(
            builder: (context) {
              final role = strings.role(roles[slot - tips.length]);
              return LobbyCard(kicker: role.motto, title: role.label.toUpperCase(), body: role.description);
            },
          );
    if (DesktopCanvas.of(context)) {
      return _deskLobby(context, lobby, seated: seated, left: left?.toDouble(), status: status, card: card, slot: slot, still: still);
    }
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
        child: ContentWidth(maxWidth: 760, child: SafeArea(
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
                  child: LobbyTable(key: const Key('ranked.table'), seated: seated, size: size, me: _me, countdown: left?.toDouble()),
                ),
              ),
              Semantics(
                liveRegion: true,
                child: Text(
                  t.rankedSeats(seated, size),
                  key: const Key('ranked.seats'),
                  textAlign: TextAlign.center,
                  style: AppText.overline.copyWith(color: Saloon.paper, fontSize: 12),
                ),
              ),
              const SizedBox(height: 2),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Text(
                  status,
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
                      child: card,
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
              const SizedBox(height: 2),
              Text(
                t.rankedStrangers,
                key: const Key('ranked.strangers'),
                textAlign: TextAlign.center,
                style: AppText.body.copyWith(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.textSecondary),
              ),
              SizedBox(height: 12 + MediaQuery.paddingOf(context).bottom),
            ],
          ),
        )),
      ),
    );
  }
}
