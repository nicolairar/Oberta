import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'player_avatar.dart';

/// Un ritratto in primo piano: entra con uno zoom, sotto un alone di luce.
/// Serve ogni volta che la partita punta il dito su qualcuno.
class AvatarSpotlight extends StatelessWidget {
  final String seed;
  final double size;

  /// Chi è morto compare sbiadito, con il pugnale sopra.
  final bool fallen;

  const AvatarSpotlight({super.key, required this.seed, this.size = 128, this.fallen = false});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 750),
      curve: Curves.easeOutBack,
      builder: (context, zoom, child) => Opacity(
        opacity: zoom.clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.35 + 0.65 * zoom, child: child),
      ),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: (fallen ? AppColors.accent : AppColors.gold).withValues(alpha: 0.45),
              blurRadius: size * 0.32,
              spreadRadius: size * 0.02,
            ),
          ],
        ),
        child: PlayerAvatar(seed: seed, size: size, fallen: fallen),
      ),
    );
  }
}
