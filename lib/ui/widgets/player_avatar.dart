import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'noir_avatar.dart';

/// Quello che un giocatore indossa sopra il ritratto: oggi niente, domani
/// cappelli, abiti e cornici guadagnati in partita. Il ritratto resta quello
/// di [NoirAvatar] (o la foto dell'elenco); i pezzi si posano sopra o dietro.
@immutable
class AvatarDress {
  final List<AvatarLayer> layers;

  const AvatarDress({this.layers = const []});

  static const none = AvatarDress();

  bool get isEmpty => layers.isEmpty;
}

/// Un pezzo del guardaroba. Si disegna in un riquadro grande quanto il
/// ritratto, ma può uscirne (un cappello sporge sopra la testa).
abstract class AvatarLayer {
  const AvatarLayer();

  /// Davanti al ritratto (un cappello, un colletto) o dietro (un alone).
  bool get inFront => true;

  Widget build(BuildContext context, double size);
}

/// Il ritratto di un giocatore, ovunque compaia in partita: la faccia, quello
/// che indossa e, se è morto, il pugnale. Chi mostra un giocatore passa da
/// qui, così il guardaroba arriva dappertutto in un colpo solo.
class PlayerAvatar extends StatelessWidget {
  final String seed;
  final double size;

  /// Chi è morto compare sbiadito, con il pugnale sopra.
  final bool fallen;

  final AvatarDress dress;

  const PlayerAvatar({
    super.key,
    required this.seed,
    this.size = 64,
    this.fallen = false,
    this.dress = AvatarDress.none,
  });

  // Il pugnale tipografico, non la croce: iOS disegna "✝" come emoji.
  static const dagger = '†';

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          for (final layer in dress.layers)
            if (!layer.inFront) Positioned.fill(child: layer.build(context, size)),
          NoirAvatar(seed: seed, size: size, faded: fallen),
          for (final layer in dress.layers)
            if (layer.inFront) Positioned.fill(child: layer.build(context, size)),
          if (fallen)
            Text(
              dagger,
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: size * 0.58,
                height: 1,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                shadows: [Shadow(color: Colors.black, blurRadius: size * 0.08)],
              ),
            ),
        ],
      ),
    );
  }
}
