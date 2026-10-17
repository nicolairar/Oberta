import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';

import 'noir_ui.dart';

/// La sala sul retro del bar, vista dall'alto di tre quarti: le pareti di
/// legno, il pavimento a scacchi, la lampada che scalda il tavolo. Di notte
/// la lampada è più bassa e la stanza più fredda.
class SaloonBackdrop extends StatelessWidget {
  final bool night;
  final Widget child;

  const SaloonBackdrop({super.key, this.night = false, required this.child});

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _RoomPainter(night: night),
        child: child,
      );
}

class _RoomPainter extends CustomPainter {
  final bool night;

  _RoomPainter({required this.night});

  @override
  void paint(Canvas canvas, Size size) {
    final all = Offset.zero & size;
    // Pareti: legno scuro, a doghe.
    canvas.drawRect(
      all,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: night
              ? const [Color(0xFF0B0D14), Color(0xFF120E0D), Color(0xFF080606)]
              : const [Color(0xFF2B170C), Color(0xFF1A0F09), Color(0xFF0B0705)],
        ).createShader(all),
    );
    final plank = Paint()..color = Colors.black.withValues(alpha: 0.22);
    for (var x = 0.0; x < size.width; x += 38) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 1.2, size.height * 0.3), plank);
    }
    // Il pavimento a scacchi, in prospettiva, che si perde nel buio.
    final floorTop = size.height * 0.3;
    final tile = size.width / 9;
    for (var row = 0; row * tile * 0.6 < size.height; row++) {
      for (var col = 0; col < 10; col++) {
        if ((row + col).isEven) continue;
        canvas.drawRect(
          Rect.fromLTWH(col * tile - (row.isOdd ? tile / 2 : 0), floorTop + row * tile * 0.6, tile, tile * 0.6),
          Paint()..color = Colors.white.withValues(alpha: night ? 0.025 : 0.04),
        );
      }
    }
    // La lampada: una pozza di luce calda sul tavolo.
    final lamp = Offset(size.width * 0.5, size.height * 0.42);
    canvas.drawCircle(
      lamp,
      size.longestSide * 0.62,
      Paint()
        ..shader = RadialGradient(
          colors: night
              ? [const Color(0x55E0A860), const Color(0x22303860), Colors.transparent]
              : [const Color(0x88F0B868), const Color(0x33A06030), Colors.transparent],
          stops: const [0, 0.45, 1],
        ).createShader(Rect.fromCircle(center: lamp, radius: size.longestSide * 0.62)),
    );
    // Vignetta.
    canvas.drawRect(
      all,
      Paint()
        ..shader = RadialGradient(
          radius: 0.95,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.75)],
          stops: const [0.55, 1],
        ).createShader(all),
    );
  }

  @override
  bool shouldRepaint(_RoomPainter old) => old.night != night;
}

/// Il tavolo ovale: bordo di legno, panno verde con il filetto d'oro.
class _TablePainter extends CustomPainter {
  final Rect felt;

  _TablePainter(this.felt);

  @override
  void paint(Canvas canvas, Size size) {
    final rim = felt.inflate(felt.shortestSide * 0.07);
    RRect round(Rect r) => RRect.fromRectAndRadius(r, Radius.circular(r.shortestSide * 0.48));
    canvas.drawRRect(round(rim.shift(const Offset(0, 14))), Paint()
      ..color = Colors.black.withValues(alpha: 0.6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18));
    canvas.drawRRect(
      round(rim),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF7A4724), Saloon.wood, Saloon.woodDark],
        ).createShader(rim),
    );
    canvas.drawRRect(
      round(felt),
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -0.2),
          radius: 0.8,
          colors: [Color(0xFF2E6A48), Saloon.felt, Saloon.feltDeep],
          stops: [0, 0.55, 1],
        ).createShader(felt),
    );
    canvas.drawRRect(
      round(felt.deflate(felt.shortestSide * 0.06)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Saloon.brass.withValues(alpha: 0.45),
    );
  }

  @override
  bool shouldRepaint(_TablePainter old) => old.felt != felt;
}

/// Una mano che indica: da chi vota ([from]) verso l'accusato ([to]). La
/// manica ha il colore del vestito di chi vota ([sleeve]), la pelle il suo
/// incarnato ([skin]); [mine] è la propria (polsino d'ottone), [accent] il
/// colore del voto (sangue di giorno, la famiglia di notte).
typedef SeatHand = ({int from, int to, Color sleeve, Color skin, bool mine, Color accent});

/// I giocatori seduti intorno al tavolo, tutti grandi uguali: i posti
/// dipendono solo da quanti sono. Il posto 0 è in basso al centro (il più
/// vicino: chi guarda ci mette sé stesso), gli altri girano in senso orario
/// lungo un anello arrotondato che usa anche gli angoli dello schermo.
/// [seatBuilder] disegna il posto [index] largo [width]; [hands] indicano
/// chi accusa chi ([leading]: l'accusato in testa, le altre mani sbiadiscono
/// un poco quando i posti sono tanti); [center] sta sul panno.
class SaloonTable extends StatelessWidget {
  final int count;
  final Widget Function(BuildContext context, int index, double width) seatBuilder;
  final List<SeatHand> hands;
  final int? leading;
  final Widget? center;

  /// Il rapporto altezza/larghezza delle carte dei posti.
  static const cardAspect = 1.32;

  /// Mai più strette di così: restano un bersaglio da 44 punti buoni.
  static const minCard = 50.0;

  const SaloonTable({
    super.key,
    required this.count,
    required this.seatBuilder,
    this.hands = const [],
    this.leading,
    this.center,
  });

  /// La larghezza delle carte per [count] posti in [box]: la più grande per
  /// cui nessuna carta tocca la vicina.
  static double cardWidth(int count, Size box) {
    final top = min(min(box.width * 0.3, box.height * 0.3 / cardAspect), 118.0);
    for (var width = top; width > minCard; width -= 1.5) {
      if (_fits(seats(count, box, width), width)) return width;
    }
    return minCard;
  }

  static bool _fits(List<Offset> centers, double width) {
    final height = width * cardAspect;
    for (var i = 0; i < centers.length; i++) {
      for (var j = i + 1; j < centers.length; j++) {
        final d = centers[i] - centers[j];
        // Un filo di respiro, e lo spazio per la targhetta e il pizzino.
        if (d.dx.abs() < width * 1.04 && d.dy.abs() < height * 1.1) return false;
      }
    }
    return true;
  }

  /// I centri dei posti su un rettangolo dagli angoli tondi, a passi uguali:
  /// il primo in basso al centro, poi in senso orario (verso sinistra).
  static List<Offset> seats(int count, Size box, double width) {
    if (count == 0) return const [];
    final height = width * cardAspect;
    final ring = Rect.fromLTRB(width / 2, height / 2, box.width - width / 2, box.height - height / 2);
    final radius = min(ring.shortestSide / 2, max(ring.shortestSide * 0.42, 0.0));
    final metric = (Path()..addRRect(RRect.fromRectAndRadius(ring, Radius.circular(radius)))).computeMetrics().first;
    // Il punto in basso al centro: lo si cerca lungo il bordo.
    final length = metric.length;
    final target = Offset(ring.center.dx, ring.bottom);
    var bottom = 0.0;
    var best = double.infinity;
    for (var d = 0.0; d < length; d += length / 240) {
      final miss = (metric.getTangentForOffset(d)!.position - target).distanceSquared;
      if (miss < best) {
        best = miss;
        bottom = d;
      }
    }
    return [
      for (var i = 0; i < count; i++)
        metric.getTangentForOffset((bottom + length * i / count) % length)!.position,
    ];
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final size = box.biggest;
      final width = cardWidth(count, size);
      final height = width * cardAspect;
      final centers = seats(count, size, width);
      final felt = Rect.fromCenter(
        center: size.center(Offset.zero),
        width: max(40, size.width - width * 1.1),
        height: max(40, size.height - height * 1.0),
      );
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: CustomPaint(painter: _TablePainter(felt))),
          if (center != null)
            Positioned.fromRect(
              rect: Rect.fromCenter(center: felt.center, width: felt.width * 0.62, height: felt.height * 0.5),
              child: Center(child: center),
            ),
          for (var i = 0; i < count; i++)
            Positioned(
              left: centers[i].dx - width / 2,
              top: centers[i].dy - height / 2,
              width: width,
              height: height,
              child: seatBuilder(context, i, width),
            ),
          Positioned.fill(
            child: IgnorePointer(
              child: PointingHands(hands: hands, centers: centers, card: Size(width, height), leading: leading),
            ),
          ),
        ],
      );
    });
  }
}

/// Le mani delle accuse, animate: quando un voto arriva la mano si allunga,
/// quando cambia si ritira e riparte verso il nuovo accusato, quando sparisce
/// si ritira. Con il movimento ridotto le mani compaiono già ferme.
class PointingHands extends StatefulWidget {
  final List<SeatHand> hands;
  final List<Offset> centers;
  final Size card;
  final int? leading;

  const PointingHands({super.key, required this.hands, required this.centers, required this.card, this.leading});

  @override
  State<PointingHands> createState() => _PointingHandsState();
}

class _Reach {
  SeatHand hand;
  SeatHand? next;
  bool leaving = false;
  double t;

  _Reach(this.hand, this.t);
}

class _PointingHandsState extends State<PointingHands> with SingleTickerProviderStateMixin {
  final Map<int, _Reach> _reach = {};
  late final _ticker = createTicker(_tick);
  Duration _last = Duration.zero;

  /// Un allungo intero dura così (in secondi).
  static const _stroke = 0.38;

  bool get _still => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(PointingHands old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final wanted = {for (final hand in widget.hands) if (hand.from != hand.to) hand.from: hand};
    final still = _still;
    for (final MapEntry(key: from, value: hand) in wanted.entries) {
      final reach = _reach[from];
      if (reach == null) {
        _reach[from] = _Reach(hand, still ? 1 : 0);
      } else if (reach.hand.to != hand.to) {
        if (still) {
          reach
            ..hand = hand
            ..next = null
            ..t = 1;
        } else {
          reach.next = hand;
        }
        reach.leaving = false;
      } else {
        reach
          ..hand = hand
          ..next = null
          ..leaving = false;
      }
    }
    for (final from in _reach.keys.toList()) {
      if (!wanted.containsKey(from)) {
        if (still) {
          _reach.remove(from);
        } else {
          _reach[from]!.leaving = true;
        }
      }
    }
    final moving = _reach.values.any((r) => r.leaving || r.next != null || r.t < 1);
    if (moving && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  void _tick(Duration now) {
    final dt = _last == Duration.zero ? 0.016 : (now - _last).inMicroseconds / 1e6;
    _last = now;
    final step = dt / _stroke;
    var moving = false;
    for (final from in _reach.keys.toList()) {
      final reach = _reach[from]!;
      if (reach.leaving || reach.next != null) {
        reach.t -= step * 1.4;
        if (reach.t <= 0) {
          reach.t = 0;
          if (reach.leaving) {
            _reach.remove(from);
            continue;
          }
          reach
            ..hand = reach.next!
            ..next = null;
        }
        moving = true;
      } else if (reach.t < 1) {
        reach.t = min(1, reach.t + step);
        moving = true;
      }
    }
    if (!moving) _ticker.stop();
    setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shown = [
      for (final reach in _reach.values)
        if (reach.t > 0 && reach.hand.from < widget.centers.length && reach.hand.to < widget.centers.length)
          (hand: reach.hand, t: Curves.easeOutCubic.transform(reach.t.clamp(0.0, 1.0))),
    ];
    return CustomPaint(
      painter: _HandPainter(shown, widget.centers, widget.card, widget.leading),
      size: Size.infinite,
    );
  }
}

/// Le mani, disegnate: la manica dal posto di chi vota, il polsino, il pugno
/// chiuso e l'indice teso verso l'accusato, con l'ombra morbida sul panno.
/// Più mani verso lo stesso accusato si aprono a ventaglio intorno a lui.
class _HandPainter extends CustomPainter {
  final List<({SeatHand hand, double t})> hands;
  final List<Offset> centers;
  final Size card;
  final int? leading;

  _HandPainter(this.hands, this.centers, this.card, this.leading);

  /// Dal centro della carta al suo bordo, nella direzione [dir] (un'ellisse
  /// dentro la carta, a occhio).
  double _edge(Offset dir) =>
      1 / sqrt(pow(dir.dx / (card.width * 0.5), 2) + pow(dir.dy / (card.height * 0.5), 2));

  @override
  void paint(Canvas canvas, Size size) {
    if (hands.isEmpty) return;
    final many = centers.length >= 11;
    final middle = size.center(Offset.zero);
    // Il ventaglio: per ogni accusato, gli angoli da cui arrivano le mani,
    // allargati finché non stanno ad almeno [gap] l'uno dall'altro.
    final angles = <int, double>{};
    final byTarget = <int, List<SeatHand>>{};
    for (final entry in hands) {
      byTarget.putIfAbsent(entry.hand.to, () => []).add(entry.hand);
    }
    final gap = many ? 0.34 : 0.42;
    for (final MapEntry(key: to, value: group) in byTarget.entries) {
      final b = centers[to];
      final list = [
        for (final hand in group) (from: hand.from, a: atan2(centers[hand.from].dy - b.dy, centers[hand.from].dx - b.dx)),
      ]..sort((x, y) => x.a.compareTo(y.a));
      final spread = [for (final e in list) e.a];
      for (var pass = 0; pass < 6; pass++) {
        for (var i = 1; i < spread.length; i++) {
          final d = spread[i] - spread[i - 1];
          if (d < gap) {
            spread[i - 1] -= (gap - d) / 2;
            spread[i] += (gap - d) / 2;
          }
        }
      }
      for (var i = 0; i < list.length; i++) {
        angles[list[i].from] = spread[i];
      }
    }

    final base = (card.width * 0.17).clamp(6.0, 13.0);
    // Prima le mani sbiadite, poi quelle verso l'accusato in testa, la propria
    // per ultima (sopra tutte).
    final ordered = [...hands]..sort((x, y) => _rank(x.hand).compareTo(_rank(y.hand)));
    for (final entry in ordered) {
      final hand = entry.hand;
      final a = centers[hand.from];
      final b = centers[hand.to];
      final angle = angles[hand.from]!;
      final toward = Offset(cos(angle), sin(angle));
      final tip = b + toward * (_edge(toward) * 0.82 + 2);
      final w = hand.mine ? base * 1.08 : base;
      final handLength = w * _handScale * 2.1;
      final control = Offset.lerp(Offset.lerp(a, tip, 0.5)!, middle, 0.22)!;
      final startDir = control - a;
      final start = a + startDir / max(startDir.distance, 0.001) * _edge(startDir / max(startDir.distance, 0.001)) * 0.7;
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..quadraticBezierTo(control.dx, control.dy, tip.dx, tip.dy);
      final metric = path.computeMetrics().first;
      final total = metric.length;
      if (total < handLength + 4) continue;
      final reach = (total - handLength) * entry.t;
      final at = metric.getTangentForOffset(reach)!;
      final faded = many && leading != null && hand.to != leading && !hand.mine;
      final alpha = faded ? 0.55 : 1.0;
      // Con tanti posti la manica è corta: prima c'è solo un filo d'inchiostro.
      final sleeveFrom = many ? max(0.0, reach - card.width * 1.5) : 0.0;
      if (sleeveFrom > 0) {
        final trail = metric.extractPath(0, sleeveFrom);
        _dotted(canvas, trail, hand.accent.withValues(alpha: 0.5 * alpha), w * 0.22);
      }
      final sleeve = metric.extractPath(sleeveFrom, reach);
      _drawArm(canvas, sleeve, at.position, at.vector, w, hand, alpha);
    }
  }

  /// La mano è più larga della manica: si deve leggere il dito.
  static const _handScale = 1.5;

  int _rank(SeatHand hand) => hand.mine ? 2 : (hand.to == leading ? 1 : 0);

  void _dotted(Canvas canvas, Path path, Color color, double width) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = max(1.2, width)
      ..strokeCap = StrokeCap.round;
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 7) {
        final p = metric.getTangentForOffset(d)!.position;
        canvas.drawPoints(PointMode.points, [p], paint);
      }
    }
  }

  void _drawArm(Canvas canvas, Path sleeve, Offset wrist, Offset dir, double w, SeatHand hand, double alpha) {
    Color fade(Color c) => c.withValues(alpha: c.a * alpha);
    final normal = Offset(-dir.dy, dir.dx);
    final coat = hand.sleeve;
    final dark = Color.lerp(coat, Colors.black, 0.55)!;
    final light = Color.lerp(coat, const Color(0xFFFFF1D6), 0.32)!;
    final h = w * _handScale;
    final silhouette = _handPath(wrist, dir, normal, h);

    // L'ombra morbida, spostata in basso a destra come la luce della lampada.
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.42 * alpha)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.5);
    canvas.save();
    canvas.translate(w * 0.25, w * 0.4);
    canvas.drawPath(
      sleeve,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 1.05
        ..strokeCap = StrokeCap.round
        ..color = shadow.color
        ..maskFilter = shadow.maskFilter,
    );
    canvas.drawPath(silhouette, shadow);
    canvas.restore();

    // La manica: bordo scuro, stoffa, un filo di luce sul lato in alto.
    canvas.drawPath(
      sleeve,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w + 2
        ..strokeCap = StrokeCap.butt
        ..color = fade(Color.lerp(dark, Colors.black, 0.4)!),
    );
    canvas.drawPath(
      sleeve,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w
        ..strokeCap = StrokeCap.butt
        ..color = fade(coat),
    );
    canvas.save();
    canvas.translate(-normal.dx * w * 0.22, -normal.dy * w * 0.22);
    canvas.drawPath(
      sleeve,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.22
        ..strokeCap = StrokeCap.round
        ..color = fade(light.withValues(alpha: 0.55)),
    );
    canvas.restore();

    // Il polsino: bianco, d'ottone per la propria mano, con il filo del voto.
    final cuffColor = hand.mine ? Saloon.brass : const Color(0xFFF2EAE1);
    final cuffBack = wrist - dir * w * 0.42;
    final cuff = Path()
      ..moveTo(cuffBack.dx + normal.dx * w * 0.6, cuffBack.dy + normal.dy * w * 0.6)
      ..lineTo(wrist.dx + normal.dx * w * 0.6, wrist.dy + normal.dy * w * 0.6)
      ..lineTo(wrist.dx - normal.dx * w * 0.6, wrist.dy - normal.dy * w * 0.6)
      ..lineTo(cuffBack.dx - normal.dx * w * 0.6, cuffBack.dy - normal.dy * w * 0.6)
      ..close();
    canvas.drawPath(cuff, Paint()..color = fade(cuffColor));
    canvas.drawPath(
      cuff,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = fade(hand.mine ? Saloon.brassDeep : const Color(0xFF8A7F74)),
    );
    final band = cuffBack + dir * w * 0.12;
    canvas.drawLine(
      band + normal * w * 0.6,
      band - normal * w * 0.6,
      Paint()
        ..strokeWidth = max(1.2, w * 0.14)
        ..color = fade(hand.accent),
    );

    // La mano: pugno, pollice e indice teso.
    final skin = hand.skin;
    final shade = Color.lerp(skin, Colors.black, 0.45)!;
    canvas.drawPath(
      silhouette,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [fade(Color.lerp(skin, Colors.white, 0.12)!), fade(skin), fade(Color.lerp(skin, Colors.black, 0.25)!)],
        ).createShader(silhouette.getBounds()),
    );
    canvas.drawPath(
      silhouette,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(0.8, h * 0.08)
        ..color = fade(shade),
    );
    // Le nocche delle dita chiuse.
    final knuckle = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(0.7, h * 0.07)
      ..strokeCap = StrokeCap.round
      ..color = fade(shade.withValues(alpha: 0.8));
    for (var k = 0; k < 3; k++) {
      final y = -0.05 + k * 0.22;
      final p = wrist + dir * h * 0.78 + normal * h * y;
      canvas.drawLine(p - dir * h * 0.2, p, knuckle);
    }
    // L'unghia sulla punta dell'indice.
    final nail = wrist + dir * h * 1.92 + normal * h * -0.36;
    canvas.drawCircle(nail, h * 0.09, Paint()..color = fade(Color.lerp(skin, Colors.white, 0.45)!));
  }

  /// Il profilo della mano che indica, con il polso in [wrist] e l'indice
  /// verso [dir]: x lungo [dir], y lungo [normal] (negativo: il lato
  /// dell'indice e del pollice).
  Path _handPath(Offset wrist, Offset dir, Offset normal, double w) {
    final fist = Path()
      ..addRRect(RRect.fromRectAndRadius(Rect.fromLTRB(0, -0.56, 0.98, 0.58), const Radius.circular(0.3)));
    final finger = Path()
      ..addRRect(RRect.fromRectAndRadius(Rect.fromLTRB(0.7, -0.56, 2.05, -0.18), const Radius.circular(0.19)));
    final thumb = Path()..addOval(Rect.fromLTRB(0.18, -0.7, 0.86, -0.34));
    final local = Path.combine(PathOperation.union, Path.combine(PathOperation.union, fist, finger), thumb);
    // Dalle unità della mano allo schermo.
    final matrix = Float64List.fromList([
      dir.dx * w, dir.dy * w, 0, 0,
      normal.dx * w, normal.dy * w, 0, 0,
      0, 0, 1, 0,
      wrist.dx, wrist.dy, 0, 1,
    ]);
    return local.transform(matrix);
  }

  @override
  bool shouldRepaint(_HandPainter old) => true;
}
