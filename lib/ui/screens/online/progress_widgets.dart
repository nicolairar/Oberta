import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/progress_strings.dart';
import '../../../online/online_services.dart';
import '../../theme/app_theme.dart';
import '../../widgets/home_account.dart' show CoinPainter;
import 'game/noir_ui.dart';

/// The back room the progress screens share: lamp-lit wood, a brass title,
/// a back arrow, the content in a narrow column.
class ProgressRoom extends StatelessWidget {
  final String title;
  final Widget child;

  const ProgressRoom({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF0A0706),
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.8),
              radius: 1.3,
              colors: [Color(0xFF2E1C10), Color(0xFF140C07), Color(0xFF070504)],
              stops: [0, 0.5, 1],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 2, 16, 4),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.chevron_left, color: Saloon.brass, size: 30),
                      ),
                      Expanded(
                        child: Text(
                          title.toUpperCase(),
                          textAlign: TextAlign.center,
                          style: AppText.overline.copyWith(color: Saloon.brass, fontSize: 13, letterSpacing: 4),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: child),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

/// Loading, failure with a retry, or the content.
class ProgressLoader<T> extends StatefulWidget {
  final Future<T> Function() load;
  final Widget Function(BuildContext context, T value, Future<void> Function() reload) builder;

  const ProgressLoader({super.key, required this.load, required this.builder});

  @override
  State<ProgressLoader<T>> createState() => _ProgressLoaderState<T>();
}

class _ProgressLoaderState<T> extends State<ProgressLoader<T>> {
  late Future<T> _future = widget.load();

  Future<void> _reload() async {
    final next = widget.load();
    setState(() => _future = next);
    await next.then((_) {}, onError: (_) {});
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasData) return widget.builder(context, snap.data as T, _reload);
          if (snap.hasError) {
            final s = ProgressStrings.of(context);
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(s.loadFailed, textAlign: TextAlign.center, style: AppText.body.copyWith(color: Saloon.paper)),
                    const SizedBox(height: 16),
                    NoirButton(kind: NoirButtonKind.brass, label: s.retry, onPressed: _reload),
                  ],
                ),
              ),
            );
          }
          return const Center(child: CircularProgressIndicator(color: Saloon.brass));
        },
      );
}

/// A small coin and a number.
class CoinAmount extends StatelessWidget {
  final int coins;
  final Color color;

  const CoinAmount(this.coins, {super.key, this.color = Saloon.brass});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox.square(dimension: 14, child: CustomPaint(painter: CoinPainter())),
          const SizedBox(width: 4),
          Text('$coins', style: AppText.body.copyWith(color: color, fontSize: 13, fontWeight: FontWeight.w800)),
        ],
      );
}

/// A thin brass bar for progress.
class BrassBar extends StatelessWidget {
  final double value;
  final bool done;

  const BrassBar(this.value, {super.key, this.done = false});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: SizedBox(
          height: 6,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: Color(0x33EFE4CB)),
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: value.clamp(0.0, 1.0),
                child: ColoredBox(color: done ? Saloon.clean : Saloon.brass),
              ),
            ],
          ),
        ),
      );
}

/// The banners after a game: one enamel plate per mission completed and
/// achievement unlocked, sliding in one after the other at the top.
class ProgressToasts extends StatefulWidget {
  final GameUnlocks unlocks;

  const ProgressToasts({super.key, required this.unlocks});

  @override
  State<ProgressToasts> createState() => _ProgressToastsState();
}

class _ProgressToastsState extends State<ProgressToasts> with SingleTickerProviderStateMixin {
  late final AnimationController _show = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
  int _index = 0;

  int get _count => widget.unlocks.missions.length + widget.unlocks.achievements.length;

  @override
  void initState() {
    super.initState();
    if (_count > 0) _next();
  }

  Future<void> _next() async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    while (mounted && _index < _count) {
      HapticFeedback.mediumImpact();
      await _show.forward(from: 0);
      await Future<void>.delayed(const Duration(milliseconds: 2600));
      if (!mounted) return;
      await _show.reverse();
      if (!mounted) return;
      setState(() => _index++);
    }
  }

  @override
  void dispose() {
    _show.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_index >= _count) return const SizedBox.shrink();
    final s = ProgressStrings.of(context);
    final missions = widget.unlocks.missions;
    final String text;
    final int? coins;
    final IconData icon;
    if (_index < missions.length) {
      final m = missions[_index];
      text = s.missionDone(s.mission(m.id));
      coins = m.coins;
      icon = Icons.task_alt;
    } else {
      final id = widget.unlocks.achievements[_index - missions.length];
      text = s.achievementDone(s.achievement(id).$1);
      coins = Achievement.byId(id)?.coins;
      icon = Icons.military_tech;
    }
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, -1.4), end: Offset.zero)
              .animate(CurvedAnimation(parent: _show, curve: Curves.easeOutBack)),
          child: Container(
            key: const Key('progress.toast'),
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: const BoxConstraints(maxWidth: 460),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Saloon.enamel, Saloon.enamelDeep]),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Saloon.brass, width: 1.4),
              boxShadow: const [BoxShadow(color: Color(0xAA000000), blurRadius: 12, offset: Offset(0, 4))],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Saloon.brass),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    text,
                    style: AppText.body.copyWith(color: Saloon.paper, fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                ),
                if (coins case final c? when c > 0) ...[
                  const SizedBox(width: 10),
                  CoinAmount(c, color: Saloon.paper),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
