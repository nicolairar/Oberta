import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../widgets/deal_table.dart' show PokerFelt;
import 'avatar_look.dart';
import 'look_painter.dart';

/// Il tempo che passa al tavolo, in secondi, per i piccoli gesti di chi
/// aspetta: il respiro, uno sguardo, il fumo. Fermo a zero quando il
/// telefono chiede meno movimento.
class IdleClock extends StatefulWidget {
  final Widget Function(BuildContext context, ValueListenable<double> time) builder;

  const IdleClock({super.key, required this.builder});

  @override
  State<IdleClock> createState() => _IdleClockState();
}

class _IdleClockState extends State<IdleClock> with SingleTickerProviderStateMixin {
  final _time = ValueNotifier<double>(0);
  late final Ticker _ticker = createTicker((elapsed) => _time.value = elapsed.inMicroseconds / 1e6);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.disableAnimationsOf(context);
    if (still && _ticker.isActive) {
      _ticker.stop();
      _time.value = 0;
    } else if (!still && !_ticker.isActive) {
      _ticker.start();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _time);
}

/// I gesti di chi aspetta al tavolo al tempo [time]: ognuno ha i suoi tempi,
/// presi da [phase], così non respirano tutti insieme.
CharacterPose idlePose(double time, int phase, {double rise = 0, Offset light = const Offset(0, -1)}) {
  final offset = (phase % 1000) / 1000 * 2 * pi;
  final breath = sin(time * 1.6 + offset);
  // Ogni tanto lo sguardo va da una parte, resta lì un momento e torna.
  final cycle = (time / 6.5 + offset / (2 * pi)) % 1;
  final side = (phase ~/ 7).isEven ? 1.0 : -1.0;
  final glance = cycle < 0.15
      ? 0.0
      : cycle < 0.25
      ? side * Curves.easeInOut.transform((cycle - 0.15) / 0.1)
      : cycle < 0.45
      ? side
      : cycle < 0.55
      ? side * (1 - Curves.easeInOut.transform((cycle - 0.45) / 0.1))
      : 0.0;
  return CharacterPose(breath: breath, glance: glance, rise: rise, time: time + offset * 3, light: light, hands: phase);
}

/// Un personaggio seduto dietro un pezzo di bordo di tavolo, alto [size]
/// (la larghezza delle spalle): lo stesso che siede al tavolo della partita,
/// da usare dove serve una persona intera e non una moneta.
class SeatedCharacter extends StatelessWidget {
  final AvatarLook look;
  final double size;

  /// Da dove arriva il conto dei gesti: di solito il nome.
  final String seed;

  /// Il bordo del tavolo sotto il petto. Al tavolo della partita lo disegna
  /// il tavolo stesso.
  final bool edge;

  const SeatedCharacter({super.key, required this.look, required this.size, this.seed = '', this.edge = true});

  static Size boxFor(double size) => Size(size * 1.3, size * 1.5);

  @override
  Widget build(BuildContext context) {
    final box = boxFor(size);
    return SizedBox.fromSize(
      size: box,
      child: IdleClock(
        builder: (context, time) => CustomPaint(
          painter: SeatedCharacterPainter(
            look: look,
            base: Offset(box.width / 2, size * 1.25),
            size: size,
            time: time,
            phase: stableHash(seed) & 0x3FF,
            edge: edge,
          ),
        ),
      ),
    );
  }
}

/// Il pennello di [SeatedCharacter], da usare anche dentro un tavolo intero:
/// [base] è il punto del bordo davanti al petto, nelle coordinate della tela.
class SeatedCharacterPainter extends CustomPainter {
  final AvatarLook? look;
  final Offset base;
  final double size;
  final ValueListenable<double>? time;
  final int phase;
  final double rise;
  final bool lit;
  final bool edge;
  final Offset light;

  /// Dove il corpo sparisce dietro il tavolo, in spalle sotto [base].
  final double cut;

  /// Gli avambracci sul panno; chi sta in piedi dietro non ci arriva.
  final bool hands;

  /// La sedia dietro; chi cammina intorno al tavolo l'ha lasciata al posto.
  final bool chair;

  /// Nessuno: la sedia vuota di chi non c'è più ([look] non serve).
  final bool empty;

  SeatedCharacterPainter({
    required this.look,
    required this.base,
    required this.size,
    this.time,
    this.phase = 0,
    this.rise = 0,
    this.lit = false,
    this.edge = false,
    this.empty = false,
    this.light = const Offset(0, -1),
    this.cut = 0.012,
    this.hands = true,
    this.chair = true,
  }) : super(repaint: time);

  @override
  void paint(Canvas canvas, Size canvasSize) {
    // Il bordo sta davanti al petto ma sotto le mani: va prima di tutto.
    if (edge) _edge(canvas, canvasSize);
    final look = this.look;
    if (empty || look == null) {
      LookPainter.emptyChair(canvas, base: base, s: size);
    } else {
      final pose = idlePose(time?.value ?? 0, phase, rise: rise, light: light);
      LookPainter.seated(canvas, look, base: base, s: size, pose: pose, lit: lit, cut: cut, hands: hands, chair: chair);
    }
  }

  void _edge(Canvas canvas, Size canvasSize) {
    final rail = Rect.fromLTRB(0, base.dy - size * 0.004, canvasSize.width, base.dy + size * 0.08);
    final felt = Rect.fromLTRB(0, rail.bottom, canvasSize.width, canvasSize.height);
    canvas.drawRect(
      felt,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [PokerFelt.felt[0], PokerFelt.felt[2]],
        ).createShader(felt),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rail, Radius.circular(size * 0.04)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: PokerFelt.wood,
        ).createShader(rail),
    );
  }

  @override
  bool shouldRepaint(SeatedCharacterPainter old) =>
      old.look != look ||
      old.base != base ||
      old.size != size ||
      old.rise != rise ||
      old.lit != lit ||
      old.empty != empty ||
      old.light != light ||
      old.phase != phase ||
      old.cut != cut ||
      old.hands != hands ||
      old.chair != chair ||
      old.time != time;
}
