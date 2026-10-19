import 'dart:math';

import 'package:flutter/material.dart';

/// Il linciaggio, sul posto: la corda cala sulla carta del condannato, la
/// carta trema, il timbro rosso «LINCIATO» la batte e il posto si spegne.
/// Dura [length]; poi resta il timbro, piccolo, sul posto caduto. Chi
/// arriva tardi parte da [startAt]; con il movimento ridotto è già finito.
class LynchMark extends StatefulWidget {
  final Widget child;
  final String label;
  final Duration startAt;

  static const length = Duration(milliseconds: 1800);

  const LynchMark({super.key, required this.child, required this.label, this.startAt = Duration.zero});

  @override
  State<LynchMark> createState() => _LynchMarkState();
}

class _LynchMarkState extends State<LynchMark> with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(vsync: this, duration: LynchMark.length);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final from = widget.startAt.inMicroseconds / LynchMark.length.inMicroseconds;
    if (still || from >= 1) {
      _t.value = 1;
    } else {
      _t.value = from.clamp(0.0, 1.0);
      _t.forward();
    }
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  static double _span(double t, double a, double b) => ((t - a) / (b - a)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _t,
        child: widget.child,
        builder: (context, child) {
          final t = _t.value;
          // La corda: cala, tira, poi sparisce.
          final drop = Curves.easeOutBack.transform(_span(t, 0, 0.3));
          final rope = 1 - _span(t, 0.7, 0.95);
          // Il tremito: forte allo strappo, poi si spegne.
          final shake = t < 0.25 || t > 0.75 ? 0.0 : sin(t * 90) * 5 * (1 - _span(t, 0.25, 0.75));
          // Il timbro: arriva grande e si schiaccia sul petto.
          final slam = _span(t, 0.3, 0.45);
          final stampScale = 2.4 - 1.4 * Curves.easeIn.transform(slam);
          final settle = _span(t, 0.75, 1);
          final flash = t < 0.42 ? 0.0 : (1 - _span(t, 0.42, 0.7)) * 0.45;
          return LayoutBuilder(builder: (context, box) {
            final w = box.maxWidth.isFinite ? box.maxWidth : 80.0;
            final h = box.maxHeight.isFinite ? box.maxHeight : 100.0;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Transform.translate(offset: Offset(shake, 0), child: child),
                if (flash > 0)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xFFB0121B).withValues(alpha: flash),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                if (rope > 0 && drop > 0)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: -h * 0.9,
                    height: h * 0.9 + h * 0.42 * drop,
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: rope,
                        child: CustomPaint(painter: _NoosePainter(sway: shake / 5)),
                      ),
                    ),
                  ),
                if (slam > 0)
                  Positioned(
                    left: -w * 0.1,
                    right: -w * 0.1,
                    top: h * (0.34 + 0.1 * settle),
                    child: IgnorePointer(
                      child: Center(
                        child: Opacity(
                          opacity: slam,
                          child: Transform.rotate(
                            angle: -0.2,
                            child: Transform.scale(
                              scale: stampScale * (1 - 0.25 * settle),
                              child: _Stamp(label: widget.label, size: max(9, w * 0.15)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          });
        },
      );
}

class _Stamp extends StatelessWidget {
  final String label;
  final double size;

  const _Stamp({required this.label, required this.size});

  @override
  Widget build(BuildContext context) => Container(
        key: const Key('lynch.stamp'),
        padding: EdgeInsets.symmetric(horizontal: size * 0.4, vertical: size * 0.12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A0505).withValues(alpha: 0.55),
          border: Border.all(color: const Color(0xFFD7262E), width: max(1.5, size * 0.16)),
          borderRadius: BorderRadius.circular(size * 0.25),
        ),
        child: Text(
          label.toUpperCase(),
          maxLines: 1,
          style: TextStyle(
            color: const Color(0xFFE8343C),
            fontSize: size,
            fontWeight: FontWeight.w900,
            letterSpacing: size * 0.12,
          ),
        ),
      );
}

/// La corda che scende dall'alto e il cappio che si chiude sopra la testa.
class _NoosePainter extends CustomPainter {
  final double sway;

  _NoosePainter({required this.sway});

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width / 2 + sway * 3;
    final loop = size.width * 0.16;
    final bottom = size.height - loop * 1.6;
    final rope = Paint()
      ..color = const Color(0xFFC79A5B)
      ..strokeWidth = max(2, size.width * 0.035)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final shade = Paint()
      ..color = Colors.black.withValues(alpha: 0.45)
      ..strokeWidth = rope.strokeWidth + 2
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(x, bottom);
    final noose = Rect.fromCenter(center: Offset(x, bottom + loop * 0.8), width: loop * 1.3, height: loop * 1.6);
    canvas.drawPath(path, shade);
    canvas.drawOval(noose, shade);
    canvas.drawPath(path, rope);
    canvas.drawOval(noose, rope);
    // Il nodo: tre giri stretti.
    for (var i = 0; i < 3; i++) {
      final y = bottom - loop * 0.5 + i * loop * 0.32;
      canvas.drawLine(Offset(x - loop * 0.3, y), Offset(x + loop * 0.3, y + loop * 0.1), rope);
    }
  }

  @override
  bool shouldRepaint(_NoosePainter old) => old.sway != sway;
}
