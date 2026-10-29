import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_strings.dart';
import '../../../l10n/progress_strings.dart';
import '../../../online/online_services.dart';
import '../../../sound/sound_stage.dart' show Press;
import '../../theme/app_theme.dart';
import '../../widgets/home_account.dart' show CoinPainter;
import '../../widgets/noir_notice.dart';
import '../../widgets/targa.dart';
import 'game/noir_ui.dart';
import 'progress_widgets.dart';

/// The missions, as typed orders pinned to the wall: the day's, the week's
/// and the long goals. Each one says what to do, how far along it is and
/// what it pays; once a game completes it, the RISCUOTI plate pays the
/// coins, the respect and (for some goals) a piece the shop never sells.
/// The server moves and checks everything; this screen reads and claims.
class MissionsScreen extends StatefulWidget {
  final ProgressRepository progress;

  /// The tab to open on: 0 today, 1 the week, 2 the goals.
  final int tab;

  const MissionsScreen({super.key, required this.progress, this.tab = 0});

  static Future<void> open(BuildContext context, ProgressRepository progress, {int tab = 0}) => Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => MissionsScreen(progress: progress, tab: tab)));

  @override
  State<MissionsScreen> createState() => _MissionsScreenState();
}

class _MissionsScreenState extends State<MissionsScreen> {
  late int _tab = widget.tab;
  PlayerProgress? _mine;
  Object? _error;

  /// The mission being claimed (its plate waits), and the ones just paid
  /// (their stamp falls).
  String? _claiming;
  final Set<String> _justClaimed = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final mine = await widget.progress.mine();
      if (mounted) setState(() => (_mine = mine, _error = null));
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _claim(MissionProgress m) async {
    if (_claiming != null) return;
    final s = ProgressStrings.of(context);
    final language = AppStrings.of(context).language;
    final overlay = Overlay.of(context, rootOverlay: true);
    setState(() => _claiming = m.id);
    try {
      final paid = await widget.progress.claim(m.id);
      HapticFeedback.heavyImpact();
      showNoticeIn(overlay, s.claimDone(paid.coins, paid.reputation), kind: NoticeKind.done);
      if (paid.item case final id?) {
        final item = initialShopCatalog.where((i) => i.id == id).firstOrNull;
        showNoticeIn(overlay, s.itemWon(item?.name(language) ?? id), kind: NoticeKind.done);
      }
      if (!mounted) return;
      setState(() => _justClaimed.add(m.id));
      await _load();
    } catch (_) {
      showNoticeIn(overlay, s.loadFailed, kind: NoticeKind.error);
    } finally {
      if (mounted) setState(() => _claiming = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ProgressStrings.of(context);
    final mine = _mine;
    return ProgressRoom(
      title: s.missions,
      child: mine == null
          ? (_error == null
              ? const Center(child: CircularProgressIndicator(color: Saloon.brass))
              : Center(
                  child: NoirButton(kind: NoirButtonKind.brass, label: s.retry, onPressed: _load),
                ))
          : _body(context, s, mine),
    );
  }

  Widget _body(BuildContext context, ProgressStrings s, PlayerProgress mine) {
    final now = DateTime.now();
    final cadence = const ['daily', 'weekly', 'long'][_tab];
    final list = [for (final m in mine.missions) if (m.cadence == cadence) m];
    int waiting(String c) => mine.missions.where((m) => m.cadence == c && m.claimable).length;
    final ends = list.where((m) => !m.late).map((m) => m.endsAt).whereType<DateTime>().firstOrNull;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: _Standing(reputation: mine.reputation, waiting: mine.claimable, strings: s),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              for (final (i, label, c) in [(0, s.tabDaily, 'daily'), (1, s.tabWeekly, 'weekly'), (2, s.tabGoals, 'long')]) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: _Tab(
                    key: Key('missions.tab.$c'),
                    label: label,
                    selected: _tab == i,
                    dot: waiting(c),
                    onTap: () => setState(() => _tab = i),
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            color: Saloon.brass,
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              children: [
                if (ends != null && ends.isAfter(now) && cadence != 'long')
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(s.endsIn(ends.difference(now)),
                        textAlign: TextAlign.right,
                        style: AppText.body.copyWith(color: AppColors.textSecondary, fontSize: 12)),
                  ),
                for (final m in list)
                  _MissionCard(
                    key: Key('mission.${m.id}'),
                    mission: m,
                    strings: s,
                    busy: _claiming == m.id,
                    stamped: _justClaimed.contains(m.id),
                    onClaim: m.claimable && _claiming == null ? () => _claim(m) : null,
                  ),
                const SizedBox(height: 12),
                Text(
                  cadence == 'long' ? s.goalsHint : s.missionsHint,
                  textAlign: TextAlign.center,
                  style: AppText.body.copyWith(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The player's standing: respect, and how many orders wait to be paid.
class _Standing extends StatelessWidget {
  final int reputation;
  final int waiting;
  final ProgressStrings strings;

  const _Standing({required this.reputation, required this.waiting, required this.strings});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: Saloon.scrim(radius: 10),
        child: Row(
          children: [
            const Icon(Icons.workspace_premium, color: Saloon.brass, size: 20),
            const SizedBox(width: 8),
            Text(strings.reputation, style: AppText.overline.copyWith(color: Saloon.brass, letterSpacing: 3, fontSize: 11)),
            const SizedBox(width: 8),
            Text('$reputation',
                key: const Key('missions.reputation'),
                style: Saloon.plate(18, color: Targa.cream)),
            const SizedBox(width: 10),
            Expanded(
              child: waiting > 0
                  ? Text(strings.toClaim(waiting),
                      key: const Key('missions.waiting'),
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body.copyWith(color: Saloon.blood, fontWeight: FontWeight.w800, fontSize: 13))
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      );
}

/// A small plate on the tab bar, with a red dot for what waits inside.
class _Tab extends StatelessWidget {
  final String label;
  final bool selected;
  final int dot;
  final VoidCallback onTap;

  const _Tab({super.key, required this.label, required this.selected, required this.dot, required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        label: label,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: SizedBox(
            height: 38,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: TargaPainter(kind: selected ? TargaKind.primary : TargaKind.secondary, radius: 10),
                  ),
                ),
                Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(label,
                          style: Targa.label(12, selected ? Targa.cream : Targa.brass)),
                    ),
                  ),
                ),
                if (dot > 0)
                  Positioned(
                    right: -3,
                    top: -5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: Saloon.blood,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Saloon.ink, width: 1.2),
                      ),
                      child: Text('$dot',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
}

class _MissionCard extends StatefulWidget {
  final MissionProgress mission;
  final ProgressStrings strings;
  final bool busy;

  /// Just claimed here: the stamp falls on the paper, coins fly off.
  final bool stamped;
  final VoidCallback? onClaim;

  const _MissionCard({
    super.key,
    required this.mission,
    required this.strings,
    required this.busy,
    required this.stamped,
    required this.onClaim,
  });

  @override
  State<_MissionCard> createState() => _MissionCardState();
}

class _MissionCardState extends State<_MissionCard> with SingleTickerProviderStateMixin {
  late final AnimationController _stamp = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    value: widget.stamped ? 0 : 1,
  );

  @override
  void initState() {
    super.initState();
    if (widget.stamped) _stamp.forward();
  }

  @override
  void didUpdateWidget(_MissionCard old) {
    super.didUpdateWidget(old);
    if (widget.stamped && !old.stamped) _stamp.forward(from: 0);
  }

  @override
  void dispose() {
    _stamp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.mission;
    final s = widget.strings;
    final language = AppStrings.of(context).language;
    final item = m.item == null ? null : initialShopCatalog.where((i) => i.id == m.item).firstOrNull;
    const ink = TextStyle(color: Saloon.paperInk, fontWeight: FontWeight.w700, fontSize: 12);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: m.claimed ? const Color(0xFFDCCFAE) : Saloon.paper,
        borderRadius: BorderRadius.circular(4),
        border: m.claimable ? Border.all(color: Saloon.brassDeep, width: 2) : null,
        boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 6, offset: Offset(0, 3))],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (m.late)
                Text(s.late, style: ink.copyWith(color: Saloon.enamel, letterSpacing: 2, fontSize: 10)),
              Padding(
                padding: const EdgeInsets.only(right: 70),
                child: Text(
                  s.mission(m.id, metric: m.metric, target: m.target),
                  style: const TextStyle(
                    fontFamily: 'Courier',
                    fontFamilyFallback: ['monospace'],
                    color: Saloon.paperInk,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
              if (item != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(m.claimed ? Icons.redeem : Icons.lock_outline, size: 14, color: Saloon.enamel),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(s.reward(item.name(language)),
                          style: ink.copyWith(color: Saloon.enamel, fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: BrassBar(m.fraction, done: m.completed)),
                  const SizedBox(width: 10),
                  Text('${m.progress}/${m.target}', style: ink.copyWith(fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (m.xp > 0) Text('+${m.xp} XP', style: ink),
                        CoinAmount(m.coins, color: Saloon.paperInk),
                        if (m.reputation > 0) Text(s.reputationGain(m.reputation), style: ink),
                      ],
                    ),
                  ),
                  if (m.claimable)
                    SizedBox(
                      height: 36,
                      child: TargaButton(
                        key: Key('mission.${m.id}.claim'),
                        label: s.claim,
                        compact: true,
                        feel: Press.confirm,
                        onPressed: widget.busy ? null : widget.onClaim,
                      ),
                    ),
                ],
              ),
            ],
          ),
          if (m.claimed || widget.stamped)
            Positioned(
              right: 0,
              top: -4,
              child: AnimatedBuilder(
                animation: _stamp,
                builder: (context, child) {
                  final t = Curves.easeOutBack.transform(_stamp.value.clamp(0.0, 1.0));
                  return Opacity(
                    opacity: _stamp.value.clamp(0.0, 1.0),
                    child: Transform.scale(scale: 2.2 - 1.2 * t, child: Transform.rotate(angle: -0.12, child: child)),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(border: Border.all(color: Saloon.enamel, width: 2)),
                  child: Text(s.claimed,
                      style: const TextStyle(color: Saloon.enamel, fontWeight: FontWeight.w900, letterSpacing: 2)),
                ),
              ),
            ),
          if (widget.stamped)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _stamp,
                  builder: (context, _) => CustomPaint(painter: _CoinBurst(_stamp.value)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A handful of coins thrown up from the claim plate, falling away.
class _CoinBurst extends CustomPainter {
  final double t;

  _CoinBurst(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    final from = Offset(size.width - 50, size.height - 18);
    const coin = CoinPainter();
    for (var i = 0; i < 9; i++) {
      final a = -pi / 2 + (i - 4) * 0.28;
      final speed = 90.0 + (i * 37 % 50);
      final p = from + Offset(cos(a) * speed * t, sin(a) * speed * t + 160 * t * t);
      final r = 7.0 * (1 - t * 0.4);
      canvas.save();
      canvas.translate(p.dx - r, p.dy - r);
      canvas.saveLayer(Rect.fromLTWH(0, 0, r * 2, r * 2), Paint()..color = Color.fromRGBO(0, 0, 0, 1 - t));
      coin.paint(canvas, Size.square(r * 2));
      canvas.restore();
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_CoinBurst old) => old.t != t;
}
