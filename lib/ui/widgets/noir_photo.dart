import 'package:flutter/material.dart';

import '../../roster/portrait_registry.dart';

/// Una foto vera trattata come il resto del gioco: seppia, contrastata, con
/// i bordi che affogano nel buio. Finché la foto non è pronta, o se non si
/// riesce a leggerla, al suo posto c'è [fallback].
class NoirPhoto extends StatelessWidget {
  final PortraitPhoto photo;

  /// I morti in bianco e nero, spenti.
  final bool faded;

  /// Tonda come una moneta o squadrata come una foto segnaletica.
  final BoxShape shape;

  /// Disegnato sopra la foto, quando c'è: la cornice.
  final CustomPainter? frame;
  final Widget fallback;

  const NoirPhoto({
    super.key,
    required this.photo,
    required this.fallback,
    this.faded = false,
    this.shape = BoxShape.rectangle,
    this.frame,
  });

  /// Toglie il colore, alza il contrasto e scalda (o spegne) i grigi.
  static ColorFilter filter({required bool faded}) {
    final (contrast, lift, red, green, blue) =
        faded ? (0.70, -18.0, 0.96, 0.96, 1.00) : (1.22, 4.0, 1.07, 0.98, 0.84);
    final offset = 127.5 * (1 - contrast) + lift;
    List<double> channel(double tint) =>
        [tint * contrast * 0.2126, tint * contrast * 0.7152, tint * contrast * 0.0722, 0, tint * offset];
    return ColorFilter.matrix([...channel(red), ...channel(green), ...channel(blue), 0, 0, 0, 1, 0]);
  }

  @override
  Widget build(BuildContext context) {
    return Image(
      image: photo.image,
      fit: BoxFit.cover,
      alignment: photo.alignment,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
      excludeFromSemantics: true,
      errorBuilder: (context, _, _) => fallback,
      frameBuilder: (context, image, frame, _) {
        if (frame == null) return fallback;
        final treated = CustomPaint(
          foregroundPainter: _ShadePainter(shape, faded, this.frame),
          child: ColorFiltered(colorFilter: filter(faded: faded), child: SizedBox.expand(child: image)),
        );
        return shape == BoxShape.circle ? ClipOval(child: treated) : ClipRect(child: treated);
      },
    );
  }
}

/// Il riflettore in alto a sinistra e il buio ai bordi, come nei ritratti
/// disegnati; poi la cornice, se c'è.
class _ShadePainter extends CustomPainter {
  final BoxShape shape;
  final bool faded;
  final CustomPainter? frame;

  _ShadePainter(this.shape, this.faded, this.frame);

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.15, -0.30),
          radius: shape == BoxShape.circle ? 0.78 : 0.95,
          colors: [
            Colors.white.withValues(alpha: faded ? 0 : 0.07),
            Colors.black.withValues(alpha: 0),
            Colors.black.withValues(alpha: faded ? 0.72 : 0.62),
          ],
          stops: const [0, 0.52, 1],
        ).createShader(bounds),
    );
    frame?.paint(canvas, size);
  }

  @override
  bool shouldRepaint(_ShadePainter old) =>
      old.shape != shape || old.faded != faded || (frame != null && (old.frame == null || frame!.shouldRepaint(old.frame!)));
}
