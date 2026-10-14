import 'dart:math';

import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../rules/role.dart';
import '../theme/app_theme.dart';
import '../theme/role_style.dart';

/// La carta del condannato: resta coperta sul tavolo e si gira davanti a
/// tutti quando [faceUp] diventa vero.
class RoleRevealCard extends StatelessWidget {
  final Role role;
  final bool faceUp;
  final double height;

  const RoleRevealCard({super.key, required this.role, required this.faceUp, this.height = 156});

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    return SizedBox(
      height: height,
      width: height * 5 / 7,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: faceUp ? 1 : 0),
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeInOutCubic,
        builder: (context, turn, _) {
          final angle = turn * pi;
          final showFace = angle > pi / 2;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0016)
              ..rotateY(angle)
              // La carta si alza dal tavolo a metà giro.
              ..scaleByDouble(1 + 0.12 * sin(angle), 1 + 0.12 * sin(angle), 1, 1),
            child: showFace
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.rotationY(pi),
                    child: _face(t),
                  )
                : _back(),
          );
        },
      ),
    );
  }

  BoxDecoration _frame(Gradient gradient) => BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black87, blurRadius: 18, offset: Offset(0, 8))],
      );

  Widget _back() {
    return Container(
      decoration: _frame(const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF3A2A22), AppColors.surface, Color(0xFF120E0C)],
      )),
      alignment: Alignment.center,
      child: Text('O', style: AppText.display(height * 0.34)),
    );
  }

  Widget _face(AppStrings t) {
    return Container(
      decoration: _frame(LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [role.color, Color.lerp(role.color, Colors.black, 0.7)!],
      )),
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(role.icon, color: AppColors.textPrimary, size: height * 0.28),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              t.role(role).label.toUpperCase(),
              style: AppText.display(15, color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            role.team == Team.mafia ? t.familyBadge : t.townBadge,
            style: AppText.overline.copyWith(color: AppColors.gold, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
