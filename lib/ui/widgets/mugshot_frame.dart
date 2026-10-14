import 'dart:math';

import 'package:flutter/material.dart';

import '../../roster/portrait_registry.dart';
import '../theme/app_theme.dart';
import 'noir_avatar.dart';
import 'noir_photo.dart';

// I testi del widget, tutti qui: la traduzione li prenderà da qui.
const _serialLabel = 'N.';

/// Una foto segnaletica come esce dalla questura: la stampa col bordo
/// chiaro, il muro con le tacche dell'altezza, e sotto la lavagnetta col
/// nome. Dentro c'è la foto vera, o il ritratto disegnato di chi non ne ha.
class MugshotFrame extends StatelessWidget {
  final String name;

  /// La foto da mostrare. Senza, il ritratto è quello disegnato per [name].
  final PortraitPhoto? photo;

  /// Cosa c'è scritto sulla lavagnetta quando il nome è ancora vuoto.
  final String placeholder;

  /// Il timbro di traverso sulla foto, se c'è.
  final String? stamp;

  /// Una riga piccola in fondo alla foto, per dire cosa ci si può fare.
  final String? caption;

  /// Falso per la sola stampa, senza la lavagnetta col nome.
  final bool placard;

  /// Il morto: tutto più spento.
  final bool faded;

  const MugshotFrame({
    super.key,
    required this.name,
    this.photo,
    this.placeholder = '',
    this.stamp,
    this.caption,
    this.placard = true,
    this.faded = false,
  });

  static const _paper = Color(0xFFE9DFCF);
  static const _slate = Color(0xFF151210);

  /// Il numero di matricola: inventato, ma sempre lo stesso per lo stesso nome.
  static String serialOf(String name) {
    var hash = 0x811C9DC5;
    for (final unit in name.toLowerCase().codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xFFFFFFFF;
    }
    return (hash % 9000 + 1000).toString();
  }

  @override
  Widget build(BuildContext context) {
    final shown = name.trim();
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final edge = width * 0.045;
        final side = width - edge * 2;
        final drawn = Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(painter: _WallPainter(faded)),
            Align(
              alignment: const Alignment(0, 0.3),
              child: NoirAvatar.drawn(seed: shown, size: side * 0.80, faded: faded),
            ),
          ],
        );
        return Container(
          padding: EdgeInsets.all(edge),
          decoration: BoxDecoration(
            color: faded ? Color.lerp(_paper, Colors.black, 0.35) : _paper,
            borderRadius: BorderRadius.circular(width * 0.02),
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 18, offset: Offset(0, 8))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(
                dimension: side,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (photo == null)
                      drawn
                    else
                      NoirPhoto(
                        photo: photo!,
                        faded: faded,
                        frame: const _TicksPainter(),
                        fallback: drawn,
                      ),
                    if (caption != null)
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          margin: EdgeInsets.all(side * 0.035),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.62),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              caption!,
                              maxLines: 1,
                              style: const TextStyle(color: AppColors.textPrimary, fontSize: 11.5, height: 1.2),
                            ),
                          ),
                        ),
                      ),
                    // Il timbro sta basso: la faccia deve restare in vista.
                    if (stamp != null)
                      Align(alignment: const Alignment(0, 0.66), child: _Stamp(text: stamp!, size: side)),
                  ],
                ),
              ),
              if (!placard)
                // Il margine largo delle stampe istantanee, buono per scriverci.
                SizedBox(height: edge * 3.4)
              else ...[
                SizedBox(height: edge),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: side * 0.05, vertical: side * 0.035),
                  color: _slate,
                  child: Column(
                    children: [
                      SizedBox(
                        height: side * 0.14,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            shown.isEmpty ? placeholder : shown.toUpperCase(),
                            maxLines: 1,
                            style: TextStyle(
                              fontFamily: 'Courier',
                              fontFamilyFallback: const ['monospace'],
                              fontSize: side * 0.12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: side * 0.012,
                              height: 1,
                              color: shown.isEmpty ? AppColors.textSecondary : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: side * 0.012),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '$_serialLabel ${serialOf(shown)}',
                          style: TextStyle(
                            fontFamily: 'Courier',
                            fontFamilyFallback: const ['monospace'],
                            fontSize: max(9, side * 0.055),
                            letterSpacing: side * 0.02,
                            height: 1,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Il muro della questura: grigio, con le righe dell'altezza.
class _WallPainter extends CustomPainter {
  final bool faded;

  const _WallPainter(this.faded);

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final base = faded ? const Color(0xFF4A4642) : const Color(0xFF8C8377);
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.2, -0.5),
          radius: 1.1,
          colors: [Color.lerp(base, Colors.white, 0.25)!, base, Color.lerp(base, Colors.black, 0.6)!],
          stops: const [0, 0.5, 1],
        ).createShader(bounds),
    );
    final line = Paint()
      ..color = Colors.black.withValues(alpha: 0.22)
      ..strokeWidth = max(0.8, size.height * 0.006);
    for (var i = 1; i < 8; i++) {
      final y = size.height * i / 8;
      canvas.drawLine(Offset(0, y), Offset(i.isEven ? size.width : size.width * 0.14, y), line);
    }
  }

  @override
  bool shouldRepaint(_WallPainter old) => old.faded != faded;
}

/// Sopra una foto vera il muro non si vede: restano le tacche sul bordo.
class _TicksPainter extends CustomPainter {
  const _TicksPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final tick = Paint()
      ..color = AppColors.textPrimary.withValues(alpha: 0.55)
      ..strokeWidth = max(0.8, size.height * 0.006);
    for (var i = 1; i < 16; i++) {
      final y = size.height * i / 16;
      canvas.drawLine(Offset(0, y), Offset(size.width * (i.isEven ? 0.075 : 0.04), y), tick);
    }
  }

  @override
  bool shouldRepaint(_TicksPainter old) => false;
}

/// Il timbro rosso della questura: arriva dall'alto, sbatte e resta storto.
class _Stamp extends StatelessWidget {
  final String text;
  final double size;

  const _Stamp({required this.text, required this.size});

  static const _ink = Color(0xFFE2323D);

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: still ? Duration.zero : const Duration(milliseconds: 420),
      curve: Curves.easeIn,
      builder: (context, hit, child) => Opacity(
        opacity: (hit * 2).clamp(0.0, 1.0),
        child: Transform.rotate(
          angle: -0.21,
          child: Transform.scale(scale: 2.4 - 1.4 * hit, child: child),
        ),
      ),
      child: Container(
        constraints: BoxConstraints(maxWidth: size * 0.92),
        padding: EdgeInsets.symmetric(horizontal: size * 0.05, vertical: size * 0.025),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.28),
          border: Border.all(color: _ink, width: max(2, size * 0.022)),
          borderRadius: BorderRadius.circular(size * 0.03),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            text,
            maxLines: 1,
            style: TextStyle(
              fontFamily: 'Georgia',
              fontFamilyFallback: const ['serif'],
              fontSize: size * 0.15,
              fontWeight: FontWeight.w900,
              letterSpacing: size * 0.012,
              height: 1.05,
              color: _ink,
            ),
          ),
        ),
      ),
    );
  }
}
