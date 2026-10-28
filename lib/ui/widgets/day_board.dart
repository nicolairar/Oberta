import 'package:flutter/material.dart';

import '../../rules/role.dart';
import '../theme/app_theme.dart';
import '../theme/role_style.dart';
import 'player_avatar.dart';

/// Una riga del "chi era chi": la faccia col segno del ruolo, il nome, il
/// ruolo (in rosso chi stava con la famiglia) e com'è finita.
class RevealRow extends StatelessWidget {
  final String name;
  final Role role;
  final String roleLabel;
  final String fate;
  final bool alive;
  final bool winner;

  const RevealRow({
    super.key,
    required this.name,
    required this.role,
    required this.roleLabel,
    required this.fate,
    required this.alive,
    required this.winner,
  });

  static const familyRed = Color(0xFFE5606A);

  @override
  Widget build(BuildContext context) {
    final family = role.team == Team.mafia;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.88),
            border: Border(left: BorderSide(color: family ? familyRed : role.color, width: 4)),
          ),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 56,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    PlayerAvatar(seed: name, size: 52, fallen: !alive),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: role.color,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.background, width: 2),
                        ),
                        child: RoleIcon(role, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      roleLabel,
                      style: TextStyle(color: family ? familyRed : AppColors.textSecondary, fontSize: 13.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (winner) const Icon(Icons.emoji_events, size: 16, color: AppColors.gold),
                    Text(fate, textAlign: TextAlign.end, style: AppText.body.copyWith(fontSize: 12.5)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
