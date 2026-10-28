import 'package:flutter/widgets.dart';

import '../../avatar/avatar_look.dart';
import '../../avatar/look_painter.dart';
import '../baked.dart';

/// La scena della bottega ([AvatarLook.aura]) dietro un ritratto ad arco: riempie
/// tutto il suo riquadro, con la testa dove la mette il ritratto di lato
/// [portrait] posato con [alignment] (come fanno [SeatCard] e [SeatPreview]).
/// È ferma: si tiene da parte in un'immagine ([Baked]).
class AuraBackdrop extends StatelessWidget {
  final AvatarLook look;
  final double portrait;
  final Alignment alignment;

  const AuraBackdrop({super.key, required this.look, required this.portrait, this.alignment = const Alignment(0, -0.1)});

  @override
  Widget build(BuildContext context) {
    if (look.aura == Aura.none) return const SizedBox.shrink();
    return Baked(child: CustomPaint(painter: _AuraPainter(look, portrait, alignment), child: const SizedBox.expand()));
  }
}

class _AuraPainter extends CustomPainter {
  final AvatarLook look;
  final double portrait;
  final Alignment alignment;

  _AuraPainter(this.look, this.portrait, this.alignment);

  @override
  void paint(Canvas canvas, Size size) {
    final at = alignment.inscribe(Size.square(portrait), Offset.zero & size).topLeft;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(at.dx, at.dy);
    LookPainter.aura(canvas, look, portrait, area: (Offset.zero & size).shift(-at));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_AuraPainter old) => old.look.aura != look.aura || old.portrait != portrait || old.alignment != alignment || old.look != look;
}
