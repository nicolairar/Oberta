import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_strings.dart';
import '../../../l10n/app_language.dart';
import '../../../online/online_account.dart';
import '../../avatar/avatar_look.dart';
import '../avatar/barber_mirror_screen.dart';
import '../../../online/online_services.dart';
import '../../theme/app_theme.dart';
import '../../widgets/home_account.dart';
import '../../widgets/player_avatar.dart';
import 'online_widgets.dart';

/// Il cartellino del giocatore, dal ritratto in alto a sinistra nel vicolo:
/// chi è, a che livello, quante monete. E la porta per uscire.
Future<void> showProfileSheet(BuildContext context, {required OnlineAccount account}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (context) => SafeArea(
      top: false,
      child: ListenableBuilder(
        listenable: account,
        builder: (context, _) => switch (account.profile) {
          final profile? => _ProfileCard(account: account, profile: profile),
          null => const SizedBox(height: 160, child: Center(child: CircularProgressIndicator(color: AppColors.gold))),
        },
      ),
    ),
  );
}

class _ProfileCard extends StatelessWidget {
  final OnlineAccount account;
  final Profile profile;

  const _ProfileCard({required this.account, required this.profile});

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context).online;
    final next = Profile.xpToNext(profile.level);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: PlayerAvatar(seed: profile.avatarSeed, look: profile.look, size: 92)),
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              key: const Key('profile.mirror'),
              onPressed: () async {
                final saved = await BarberMirrorScreen.open(context, services: account.services, profile: profile);
                if (saved != null) account.saved(saved);
              },
              icon: const Icon(Icons.face_retouching_natural),
              label: Text(AppStrings.of(context).language == AppLanguage.en ? "The barber's mirror" : 'Lo specchio del barbiere'),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            profile.name.isEmpty ? t.pickHandle : profile.name,
            textAlign: TextAlign.center,
            style: AppText.display(22, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _Stat(label: t.level, value: '${profile.level}')),
              const SizedBox(width: 12),
              Expanded(
                child: _Stat(
                  label: t.coins,
                  value: '${profile.coins}',
                  icon: const SizedBox.square(dimension: 18, child: CustomPaint(painter: CoinPainter())),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              key: const Key('profile.xp'),
              value: profile.levelProgress,
              minHeight: 8,
              color: AppColors.gold,
              backgroundColor: AppColors.surfaceHigh,
            ),
          ),
          const SizedBox(height: 6),
          Text(t.xpProgress(profile.xp, next), textAlign: TextAlign.center, style: AppText.body.copyWith(fontSize: 12)),
          const SizedBox(height: 22),
          OutlinedButton.icon(
            onPressed: () async {
              HapticFeedback.selectionClick();
              final navigator = Navigator.of(context);
              try {
                await account.services.auth.signOut();
                navigator.pop();
              } catch (error) {
                if (context.mounted) showFailure(context, error);
              }
            },
            icon: const Icon(Icons.logout),
            label: Text(t.signOut),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Widget? icon;

  const _Stat({required this.label, required this.value, this.icon});

  @override
  Widget build(BuildContext context) => OnlinePanel(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        child: Column(
          children: [
            Text(label, style: AppText.overline.copyWith(color: AppColors.gold, fontSize: 11)),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon case final icon?) ...[icon, const SizedBox(width: 6)],
                Text(value, style: AppText.display(20, color: AppColors.textPrimary)),
              ],
            ),
          ],
        ),
      );
}
