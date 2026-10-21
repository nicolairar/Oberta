import 'package:flutter/material.dart';

import '../../../l10n/progress_strings.dart';
import '../../../online/online_services.dart';
import '../../theme/app_theme.dart';
import 'game/noir_ui.dart';
import 'progress_widgets.dart';

/// The medals: a velvet tray, each medal bright when earned, a dark shape
/// with its progress when not. Tiers of the same family sit side by side.
class AchievementsScreen extends StatelessWidget {
  final ProgressRepository progress;

  const AchievementsScreen({super.key, required this.progress});

  static Future<void> open(BuildContext context, ProgressRepository progress) => Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => AchievementsScreen(progress: progress)));

  @override
  Widget build(BuildContext context) {
    final s = ProgressStrings.of(context);
    return ProgressRoom(
      title: s.achievements,
      child: ProgressLoader<PlayerProgress>(
        load: progress.mine,
        builder: (context, mine, reload) {
          final earned = achievements.where((a) => mine.unlocked.containsKey(a.id)).length;
          return RefreshIndicator(
            color: Saloon.brass,
            onRefresh: reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Text(
                  s.unlockedCount(earned, achievements.length),
                  key: const Key('achievements.count'),
                  textAlign: TextAlign.center,
                  style: AppText.display(22, color: Saloon.paper),
                ),
                if (mine.title case final title?) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${s.title}: ${s.titleName(title)}',
                    textAlign: TextAlign.center,
                    style: AppText.overline.copyWith(color: Saloon.brass, letterSpacing: 2),
                  ),
                ],
                const SizedBox(height: 16),
                for (final a in achievements)
                  _Medal(achievement: a, at: mine.unlocked[a.id], value: mine.statOf(a.metric), strings: s),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Medal extends StatelessWidget {
  final Achievement achievement;
  final DateTime? at;
  final int value;
  final ProgressStrings strings;

  const _Medal({required this.achievement, required this.at, required this.value, required this.strings});

  @override
  Widget build(BuildContext context) {
    final a = achievement;
    final earned = at != null;
    final (name, ask) = strings.achievement(a.id);
    final colors = switch (a.tier) {
      1 => const [Color(0xFFD08A4E), Color(0xFF7A4520)],
      2 => const [Color(0xFFE2E2E2), Color(0xFF7C7C80)],
      _ => const [Color(0xFFF3D27A), Color(0xFF9C7420)],
    };
    return Container(
      key: Key('achievement.${a.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF3A0E14), Color(0xFF1E070A)]),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: earned ? Saloon.brass : Saloon.brassDeep.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: earned ? RadialGradient(colors: colors) : null,
              color: earned ? null : const Color(0xFF2A1A14),
              border: Border.all(color: earned ? colors.last : const Color(0xFF4A3426), width: 2),
            ),
            child: Icon(
              earned ? Icons.military_tech : Icons.lock_outline,
              color: earned ? const Color(0xFF2A1C14) : const Color(0xFF6A5040),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppText.body.copyWith(
                    color: earned ? Saloon.paper : Saloon.paper.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                Text(ask, style: AppText.body.copyWith(color: AppColors.textSecondary, fontSize: 12)),
                if (!earned && a.target > 1) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(child: BrassBar(value / a.target)),
                      const SizedBox(width: 8),
                      Text('${value.clamp(0, a.target)}/${a.target}',
                          style: AppText.body.copyWith(color: AppColors.textSecondary, fontSize: 11)),
                    ],
                  ),
                ],
                if (a.title != null || a.item != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (a.title case final t?) strings.rewardTitle(strings.titleName(t)),
                      if (a.item != null) strings.rewardFrame,
                    ].join(' · '),
                    style: AppText.body.copyWith(color: Saloon.brass, fontSize: 11, fontStyle: FontStyle.italic),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              CoinAmount(a.coins),
              Text('+${a.xp} XP', style: AppText.body.copyWith(color: AppColors.textSecondary, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}
