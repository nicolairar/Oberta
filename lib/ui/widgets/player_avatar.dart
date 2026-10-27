import 'dart:math';

import 'package:flutter/material.dart';

import '../../roster/portrait_registry.dart';
import '../avatar/avatar_look.dart';
import '../avatar/look_painter.dart';
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
///
/// La persona è la stessa che siede al tavolo ([AvatarLook], disegnata da
/// [LookPainter]) a mezzo busto in una moneta; chi si è fatto fotografare
/// compare con la sua foto.
class PlayerAvatar extends StatelessWidget {
  final String seed;
  final double size;

  /// Il look da indossare; senza, quello che spetta a [seed].
  final AvatarLook? look;

  /// Chi è morto compare sbiadito, con il pugnale sopra.
  final bool fallen;

  final AvatarDress dress;

  const PlayerAvatar({
    super.key,
    required this.seed,
    this.size = 64,
    this.fallen = false,
    this.dress = AvatarDress.none,
    this.look,
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
          ListenableBuilder(
            listenable: PortraitRegistry.instance,
            builder: (context, _) => PortraitRegistry.instance.photoOf(seed) != null
                ? NoirAvatar(seed: seed, size: size, faded: fallen)
                : CustomPaint(
                    size: Size.square(size),
                    painter: AvatarBustPainter(look ?? AvatarLook.of(seed), faded: fallen),
                  ),
          ),
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

/// La moneta del ritratto: il fondo nel colore del vezzo, le righe
/// dell'altezza, la persona a mezzo busto e la cornice d'oro.
class AvatarBustPainter extends CustomPainter {
  final AvatarLook look;
  final bool faded;

  AvatarBustPainter(this.look, {this.faded = false});

  static const _grey = ColorFilter.matrix([
    0.30, 0.55, 0.15, 0, 0, //
    0.30, 0.55, 0.15, 0, 0,
    0.30, 0.55, 0.15, 0, 0,
    0, 0, 0, 0.75, 0,
  ]);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    // In un riquadro non quadrato (la scheda della bottega) la moneta sta nel
    // mezzo, non schiacciata in un angolo.
    canvas.save();
    canvas.translate((size.width - s) / 2, (size.height - s) / 2);
    final bounds = Offset.zero & Size.square(s);
    final background = look.outfit.accent;
    if (faded) canvas.saveLayer(bounds, Paint()..colorFilter = _grey);
    canvas.save();
    canvas.clipPath(Path()..addOval(bounds));
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.25, -0.55),
          radius: 1.15,
          colors: [
            Color.lerp(background, Colors.white, 0.22)!,
            Color.lerp(background, Colors.black, 0.2)!,
            Color.lerp(background, Colors.black, 0.7)!,
          ],
          stops: const [0, 0.45, 1],
        ).createShader(bounds),
    );
    final ruler = Paint()
      ..color = Colors.black.withValues(alpha: 0.16)
      ..strokeWidth = max(0.6, s * 0.008);
    for (var i = 1; i < 8; i++) {
      canvas.drawLine(Offset(0, s * i / 8), Offset(i.isEven ? s : s * 0.16, s * i / 8), ruler);
    }
    LookPainter.bust(canvas, look, s);
    canvas.restore();
    canvas.drawCircle(
      bounds.center,
      s / 2 - s * 0.012,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.05
        ..color = Colors.black.withValues(alpha: 0.55),
    );
    canvas.drawCircle(
      bounds.center,
      s / 2 - max(0.75, s * 0.012),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.5, s * 0.024)
        ..color = AppColors.gold.withValues(alpha: 0.9),
    );
    if (faded) canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(AvatarBustPainter old) => old.look != look || old.faded != faded;
}
