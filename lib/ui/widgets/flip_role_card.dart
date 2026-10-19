import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_strings.dart';
import '../../rules/player.dart';
import '../../rules/role.dart';
import '../../sound/cue_sounds.dart';
import '../../sound/sound_stage.dart';
import '../theme/app_theme.dart';
import '../theme/role_style.dart';
import 'role_rules.dart';
import '../../sound/meme_beat.dart';

/// Carta ruolo coperta: si gira in 3D finché il dito resta premuto e torna
/// coperta al rilascio, così il ruolo non resta mai in vista per sbaglio.
class FlipRoleCard extends StatefulWidget {
  final Role role;
  final List<Player> teammates;

  /// Chiamata la prima volta che la carta arriva completamente scoperta.
  final VoidCallback? onRevealed;

  const FlipRoleCard({
    super.key,
    required this.role,
    this.teammates = const [],
    this.onRevealed,
  });

  @override
  State<FlipRoleCard> createState() => _FlipRoleCardState();
}

class _FlipRoleCardState extends State<FlipRoleCard> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _notified = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && !_notified) {
          _notified = true;
          widget.onRevealed?.call();
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _press() {
    HapticFeedback.mediumImpact();
    SoundStage.instance.cue(Cue.flip);
    // A caso, mai legato al ruolo: lo sentono tutti, non deve svelare niente.
    beat(MemeMoment.roleReveal, after: const Duration(milliseconds: 250));
    _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    // Listener e non GestureDetector: la carta deve reagire subito al tocco,
    // senza aspettare che il sistema decida se è un tap o un long press.
    return Listener(
      onPointerDown: (_) => _press(),
      onPointerUp: (_) => _controller.reverse(),
      onPointerCancel: (_) => _controller.reverse(),
      child: AspectRatio(
        aspectRatio: 5 / 7,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final angle = Curves.easeInOutCubic.transform(_controller.value) * pi;
            final faceUp = angle > pi / 2;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0014)
                ..rotateY(angle),
              child: faceUp
                  ? Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.rotationY(pi),
                      child: _RoleFace(role: widget.role, teammates: widget.teammates),
                    )
                  : const _CardBack(),
            );
          },
        ),
      ),
    );
  }
}

class _CardFrame extends StatelessWidget {
  final Gradient gradient;
  final Widget child;

  const _CardFrame({required this.gradient, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.gold, width: 2.5),
        boxShadow: const [
          BoxShadow(color: Colors.black87, blurRadius: 28, offset: Offset(0, 14)),
        ],
      ),
      padding: const EdgeInsets.all(10),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.45)),
        ),
        padding: const EdgeInsets.all(18),
        child: child,
      ),
    );
  }
}

class _CardBack extends StatelessWidget {
  const _CardBack();

  @override
  Widget build(BuildContext context) {
    return _CardFrame(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF3A2A22), AppColors.surface, Color(0xFF120E0C)],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('O', style: AppText.display(96)),
          const SizedBox(height: 28),
          const Icon(Icons.fingerprint, color: AppColors.textSecondary, size: 40),
          const SizedBox(height: 10),
          Text(AppStrings.of(context).pressAndHold, style: AppText.overline),
        ],
      ),
    );
  }
}

class _RoleFace extends StatelessWidget {
  final Role role;
  final List<Player> teammates;

  const _RoleFace({required this.role, required this.teammates});

  @override
  Widget build(BuildContext context) {
    final isMafia = role.team == Team.mafia;
    final t = AppStrings.of(context);
    final text = t.role(role);
    return _CardFrame(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [role.color, Color.lerp(role.color, Colors.black, 0.72)!],
      ),
      // Su uno schermo piccolo, o con tanti complici da elencare, la faccia
      // si rimpicciolisce tutta insieme invece di uscire dal bordo.
      child: LayoutBuilder(
        builder: (context, box) => FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: box.maxWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RoleIcon(role, size: 104),
                const SizedBox(height: 18),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    text.label.toUpperCase(),
                    style: AppText.display(30, color: AppColors.textPrimary),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  text.motto,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Georgia',
                    fontStyle: FontStyle.italic,
                    fontSize: 15,
                    color: AppColors.gold,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    isMafia ? t.youAreFamily : role.team == Team.neutral ? t.youAreNeutral : t.youAreTown,
                    style: AppText.overline.copyWith(color: AppColors.textPrimary, fontSize: 11),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: RoleRules(role, color: AppColors.textPrimary, labelColor: AppColors.gold, fontSize: 14),
                ),
                if (isMafia) ...[
                  const SizedBox(height: 20),
                  Text(
                    teammates.isEmpty ? t.youActAlone : t.yourAccomplices,
                    style: AppText.overline.copyWith(color: AppColors.gold),
                  ),
                  if (teammates.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      teammates.map((player) => player.name).join(' · '),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
