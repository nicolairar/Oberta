import 'package:flutter/material.dart';

import '../../../l10n/app_language.dart';
import '../../../l10n/app_strings.dart';
import '../../../l10n/progress_strings.dart';
import '../../../online/online_services.dart';
import '../../theme/app_theme.dart';
import '../../widgets/platform_marks.dart';
import 'game/noir_ui.dart';
import 'profile_sheet.dart';
import 'progress_widgets.dart';

/// The ranked board, chalked on the wall of the back room: the top hundred
/// of a language, by handle and tier only, and your own place.
class LeaderboardScreen extends StatefulWidget {
  final ProgressRepository progress;
  final AppLanguage language;

  const LeaderboardScreen({super.key, required this.progress, required this.language});

  static Future<void> open(BuildContext context, ProgressRepository progress, AppLanguage language) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => LeaderboardScreen(progress: progress, language: language),
        ),
      );

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  late AppLanguage _language = widget.language;

  @override
  Widget build(BuildContext context) {
    final s = ProgressStrings.of(context);
    final t = AppStrings.of(context).online;
    return ProgressRoom(
      title: s.leaderboard,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SegmentedButton<AppLanguage>(
              segments: [
                for (final lang in AppLanguage.values)
                  ButtonSegment(value: lang, label: Text(lang.nativeName), icon: const SizedBox.shrink()),
              ],
              selected: {_language},
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                foregroundColor: Saloon.paper,
                selectedForegroundColor: Saloon.ink,
                selectedBackgroundColor: Saloon.brass,
                side: const BorderSide(color: Saloon.brassDeep),
              ),
              onSelectionChanged: (set) => setState(() => _language = set.first),
            ),
          ),
          Expanded(
            child: ProgressLoader<Leaderboard>(
              key: ValueKey(_language),
              load: () => widget.progress.leaderboard(_language),
              builder: (context, board, reload) => RefreshIndicator(
                color: Saloon.brass,
                onRefresh: reload,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    Container(
                      key: const Key('leaderboard.me'),
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: Saloon.scrim(),
                      child: Text(
                        switch (board.me) {
                          final me? => '${s.yourPlace(me.rank)} · ${t.tierName(me.tier)}',
                          null => s.notRanked,
                        },
                        textAlign: TextAlign.center,
                        style: AppText.body.copyWith(color: Saloon.brass, fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (board.top.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          s.leaderboardEmpty,
                          textAlign: TextAlign.center,
                          style: AppText.body.copyWith(color: AppColors.textSecondary),
                        ),
                      ),
                    for (final row in board.top)
                      InkWell(
                        onTap: switch (OnlineServices.instance) {
                          final services? => () => showPublicProfile(context, services: services, target: row.handle),
                          null => null,
                        },
                        child: Container(
                          key: Key('leaderboard.row.${row.rank}'),
                          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
                          decoration: const BoxDecoration(
                            border: Border(bottom: BorderSide(color: Color(0x22EFE4CB))),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 40,
                                child: Text(
                                  '${row.rank}',
                                  style: AppText.display(
                                    row.rank <= 3 ? 20 : 16,
                                    color: row.rank <= 3 ? Saloon.brass : Saloon.paper,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        '@${row.handle}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppText.body.copyWith(color: Saloon.paper, fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                    PlatformBadges.of(
                                      steam: row.steam,
                                      apple: row.apple,
                                      size: 13,
                                      color: Saloon.paper.withValues(alpha: 0.7),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                t.tierName(row.tier).toUpperCase(),
                                style: AppText.overline.copyWith(color: Saloon.mafia, fontSize: 10, letterSpacing: 1.6),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Text(
                      s.leaderboardHint,
                      textAlign: TextAlign.center,
                      style: AppText.body.copyWith(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
