import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_language.dart';
import '../../../l10n/app_strings.dart';
import '../../../online/online_services.dart';
import '../../theme/app_theme.dart';
import 'online_game_screen.dart';
import 'online_widgets.dart';

/// La coda della classificata: lingua, la ricerca (un faro che spazza la
/// piazza), quanti aspettano, l'attesa stimata, annulla. Quando il server
/// apre il tavolo si entra da soli nella partita; alla fine, i risultati.
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
  bool _entering = false;

  RankedRepository get _ranked => widget.services.ranked!;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(widget.poll, (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sweep.dispose();
    if (_status.queued) unawaited(_ranked.leave().catchError((_) {}));
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final status = await _ranked.status();
      if (!mounted) return;
      setState(() => _status = status);
      if (status.roomId case final room?) await _enter(room);
    } catch (_) {
      // La rete torna: il prossimo giro riprova.
    }
  }

  Future<void> _start() async {
    HapticFeedback.selectionClick();
    try {
      final status = await _ranked.enqueue(_language);
      if (mounted) setState(() => _status = status);
    } catch (error) {
      if (mounted) showFailure(context, error);
    }
  }

  Future<void> _cancel() async {
    HapticFeedback.selectionClick();
    try {
      await _ranked.leave();
      if (mounted) setState(() => _status = const RankedStatus());
    } catch (error) {
      if (mounted) showFailure(context, error);
    }
  }

  Future<void> _enter(String roomId) async {
    if (_entering) return;
    _entering = true;
    _timer?.cancel();
    final navigator = Navigator.of(context);
    try {
      final room = await widget.services.rooms.fetch(roomId);
      final me = await widget.services.profiles.me();
      if (room == null || !mounted) return;
      _status = const RankedStatus();
      await navigator.push(MaterialPageRoute<void>(
        builder: (_) => OnlineGameScreen(services: widget.services, room: room, me: me),
      ));
      if (!mounted) return;
      await widget.services.rooms.leave(roomId, autoHeir: true).catchError((_) {});
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
    final cooldown = _status.cooldownUntil;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(t.rankedQueueTitle), backgroundColor: AppColors.background),
      body: OnlineBody(
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
            const SizedBox(height: 8),
            Text(t.rankedWaiting(_status.waiting), textAlign: TextAlign.center, style: AppText.body),
            if (_status.estimate case final estimate?)
              Text(t.rankedEstimate(_clock(estimate)), textAlign: TextAlign.center, style: AppText.body),
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
