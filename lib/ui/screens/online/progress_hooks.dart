import 'package:flutter/material.dart';

import '../../../l10n/lobby_language.dart';
import '../../../l10n/collection_strings.dart';
import '../../../l10n/progress_strings.dart';
import '../../../online/online_services.dart';
import 'achievements_screen.dart';
import 'leaderboard_screen.dart';
import 'missions_screen.dart';
import '../roles_screen.dart';

/// The doors to missions, achievements, the roles collection and the
/// leaderboard, for screens that
/// draw them in their own style (the dossier's plates). Empty without the
/// progress service.
List<({Key key, String label, IconData icon, VoidCallback open})> progressLinks(
  BuildContext context,
  ProgressRepository? progress,
  LobbyLanguage language, {
  OnlineServices? services,
}) {
  if (progress == null) return const [];
  final s = ProgressStrings.of(context);
  return [
    (
      key: const Key('profile.missions'),
      label: s.missions,
      icon: Icons.assignment_outlined,
      open: () => MissionsScreen.open(context, progress),
    ),
    (
      key: const Key('profile.achievements'),
      label: s.achievements,
      icon: Icons.military_tech_outlined,
      open: () => AchievementsScreen.open(context, progress),
    ),
    (
      key: const Key('profile.roles'),
      label: CollectionStrings.of(context).title,
      icon: Icons.style_outlined,
      open: () => RolesScreen.open(context, services: services),
    ),
    (
      key: const Key('profile.leaderboard'),
      label: s.leaderboard,
      icon: Icons.leaderboard_outlined,
      open: () => LeaderboardScreen.open(context, progress, language),
    ),
  ];
}

/// The title earned with an achievement, typed under the name in the
/// dossier. Nothing until there is one.
class DossierTitle extends StatefulWidget {
  final ProgressRepository? progress;
  final TextStyle style;

  const DossierTitle({super.key, required this.progress, required this.style});

  @override
  State<DossierTitle> createState() => _DossierTitleState();
}

class _DossierTitleState extends State<DossierTitle> {
  String? _title;

  @override
  void initState() {
    super.initState();
    widget.progress?.mine().then((mine) {
      if (mounted && mine.title != null) setState(() => _title = mine.title);
    }, onError: (_) {});
  }

  @override
  Widget build(BuildContext context) {
    final title = _title;
    if (title == null) return const SizedBox.shrink();
    final s = ProgressStrings.of(context);
    return Padding(
      key: const Key('profile.title'),
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        '«${s.titleName(title)}»',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: widget.style.copyWith(fontSize: 13, fontStyle: FontStyle.italic, fontWeight: FontWeight.w700),
      ),
    );
  }
}
