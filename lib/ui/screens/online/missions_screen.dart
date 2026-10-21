import 'package:flutter/material.dart';

import '../../../l10n/progress_strings.dart';
import '../../../online/online_services.dart';
import '../../theme/app_theme.dart';
import 'game/noir_ui.dart';
import 'progress_widgets.dart';

/// The day's and the week's missions, as typed orders pinned to the wall:
/// what to do, how far along, what it pays. The server moves them when a
/// game is settled; this screen only reads.
class MissionsScreen extends StatelessWidget {
  final ProgressRepository progress;

  const MissionsScreen({super.key, required this.progress});

  static Future<void> open(BuildContext context, ProgressRepository progress) => Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => MissionsScreen(progress: progress)));

  @override
  Widget build(BuildContext context) {
    final s = ProgressStrings.of(context);
    return ProgressRoom(
      title: s.missions,
      child: ProgressLoader<PlayerProgress>(
        load: progress.mine,
        builder: (context, mine, reload) {
          final now = DateTime.now();
          Widget section(String label, bool weekly) {
            final list = [for (final m in mine.missions) if (m.weekly == weekly) m];
            final ends = list.map((m) => m.endsAt).whereType<DateTime>().firstOrNull;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(label, style: AppText.overline.copyWith(color: Saloon.brass, letterSpacing: 3, fontSize: 11)),
                    const Spacer(),
                    if (ends != null && ends.isAfter(now))
                      Text(s.endsIn(ends.difference(now)),
                          style: AppText.body.copyWith(color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 8),
                for (final m in list) _MissionCard(mission: m, strings: s),
              ],
            );
          }

          return RefreshIndicator(
            color: Saloon.brass,
            onRefresh: reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                section(s.daily, false),
                const SizedBox(height: 20),
                section(s.weekly, true),
                const SizedBox(height: 20),
                Text(
                  s.missionsHint,
                  textAlign: TextAlign.center,
                  style: AppText.body.copyWith(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MissionCard extends StatelessWidget {
  final MissionProgress mission;
  final ProgressStrings strings;

  const _MissionCard({required this.mission, required this.strings});

  @override
  Widget build(BuildContext context) {
    final m = mission;
    return Container(
      key: Key('mission.${m.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: m.completed ? const Color(0xFFDCCFAE) : Saloon.paper,
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 6, offset: Offset(0, 3))],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.mission(m.id, metric: m.metric, target: m.target),
                style: const TextStyle(
                  fontFamily: 'Courier',
                  fontFamilyFallback: ['monospace'],
                  color: Saloon.paperInk,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: BrassBar(m.fraction, done: m.completed)),
                  const SizedBox(width: 10),
                  Text(
                    '${m.progress}/${m.target}',
                    style: const TextStyle(color: Saloon.paperInk, fontWeight: FontWeight.w800, fontSize: 12),
                  ),
                  const SizedBox(width: 12),
                  Text('+${m.xp} XP',
                      style: const TextStyle(color: Saloon.paperInk, fontWeight: FontWeight.w700, fontSize: 12)),
                  const SizedBox(width: 8),
                  CoinAmount(m.coins, color: Saloon.paperInk),
                ],
              ),
            ],
          ),
          if (m.completed)
            Positioned(
              right: 0,
              top: -4,
              child: Transform.rotate(
                angle: -0.12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(border: Border.all(color: Saloon.enamel, width: 2)),
                  child: Text(strings.done,
                      style: const TextStyle(color: Saloon.enamel, fontWeight: FontWeight.w900, letterSpacing: 2)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
