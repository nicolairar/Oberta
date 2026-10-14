import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../roster/portrait_registry.dart';
import '../theme/app_theme.dart';
import 'mugshot_frame.dart';
import 'noir_avatar.dart';

/// Il ritratto che chiude la scena del delitto: chi non vedrà l'alba, o chi
/// stavolta l'ha scampata. Sempre e solo la vittima: di chi ha colpito non
/// si mostra mai niente.
///
/// Chi ha una foto arriva come la stampa sbattuta sul tavolo del
/// commissario, e la cinepresa continua a stringere piano sulla faccia. Chi
/// non ce l'ha ha il suo ritratto disegnato, come sempre.
class VictimCard extends StatelessWidget {
  final String name;
  final bool survives;

  /// Da 0 a 1 mentre il ritratto entra in scena.
  final double reveal;

  const VictimCard({super.key, required this.name, required this.survives, required this.reveal});

  // Il pugnale tipografico, non la croce: iOS disegna "✝" come emoji.
  static const _dagger = '†';

  @override
  Widget build(BuildContext context) {
    final registry = PortraitRegistry.instance;
    return ListenableBuilder(
      listenable: registry,
      builder: (context, _) {
        final photo = registry.photoOf(name);
        if (photo == null) {
          return Transform.scale(
            scale: 1.25 - 0.25 * Curves.easeOut.transform(reveal),
            child: Stack(
              alignment: Alignment.center,
              children: [
                NoirAvatar(seed: name, size: 132, faded: !survives),
                if (!survives)
                  const Text(
                    _dagger,
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 78,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      shadows: [Shadow(color: Colors.black, blurRadius: 12)],
                    ),
                  ),
              ],
            ),
          );
        }
        final landed = Curves.easeOutCubic.transform(reveal);
        return Transform.rotate(
          angle: lerpDouble(-0.6, -0.045, landed)!,
          child: Transform.scale(
            scale: lerpDouble(2.6, 1, landed)!,
            child: _SlowPush(
              child: SizedBox(
                width: 190,
                // La faccia resta scoperta: il pugnale va sul margine della
                // stampa, come un appunto a penna.
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    MugshotFrame(name: name, photo: photo, placard: false, faded: !survives),
                    if (!survives)
                      const Positioned(
                        bottom: 3,
                        child: Text(
                          _dagger,
                          style: TextStyle(
                            fontFamily: 'Georgia',
                            fontSize: 30,
                            height: 1,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1B1613),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// La cinepresa che stringe piano, finché il tavolo non va avanti.
class _SlowPush extends StatelessWidget {
  final Widget child;

  const _SlowPush({required this.child});

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1, end: 1.08),
      duration: const Duration(seconds: 10),
      curve: Curves.easeOut,
      builder: (context, zoom, child) => Transform.scale(scale: zoom, child: child),
      child: child,
    );
  }
}
