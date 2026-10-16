import 'dart:math';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../rules/knowledge.dart';
import '../../rules/player.dart';
import '../../rules/role.dart';
import '../theme/app_theme.dart';
import '../theme/role_style.dart';
import 'deal_table.dart' show PokerFelt;
import 'player_avatar.dart';
import '../press.dart';

/// Il tavolo da poker della partita, visto da una sedia in fondo alla sala:
/// il panno verde in prospettiva, il bordo di legno, e intorno i giocatori
/// seduti, più grandi davanti e più piccoli in fondo, ognuno con la sua
/// targhetta d'ottone. Chi siede si vede sempre intero, col suo ritratto e
/// quello che indossa ([PlayerAvatar]).
///
/// L'ordine è quello di [players], in senso orario a partire dal posto in
/// fondo: chi chiama decide se è il tavolo pubblico o uno segreto
/// rimescolato (vedi `seating.dart`). Dove cade un posto dipende solo dal
/// numero dei posti, mai da chi ci siede.
class PlayerGrid extends StatefulWidget {
  final List<Player> players;
  final bool Function(Player) isAlive;
  final Knowledge Function(Player) knowledgeOf;

  /// Chi tiene il telefono, se il tavolo è personale.
  final Player? viewer;

  /// Chi si può toccare. `null` rende il tavolo di sola lettura. Di solito
  /// sono i vivi, ma non per forza: il Becchino sceglie tra i morti.
  final List<Player>? selectable;
  final Player? selected;
  final ValueChanged<Player>? onSelect;

  /// Chi oggi ha la bocca cucita: lo si vede dal segno sul ritratto.
  final Player? silenced;

  /// Il timbro sul ritratto scelto (al voto, "imputato"). Senza, un segno d'oro.
  final String? stamp;

  /// I posti sono appena stati rimescolati: all'arrivo i giocatori si alzano
  /// e cambiano sedia attraverso il tavolo. Da dove partono dipende solo dal
  /// posto d'arrivo, così il giro non racconta niente del turno prima.
  final bool shuffled;

  const PlayerGrid({
    super.key,
    required this.players,
    required this.isAlive,
    required this.knowledgeOf,
    this.viewer,
    this.selectable,
    this.selected,
    this.onSelect,
    this.silenced,
    this.stamp,
    this.shuffled = false,
  });

  @override
  State<PlayerGrid> createState() => _PlayerGridState();
}

class _PlayerGridState extends State<PlayerGrid> with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: widget.shuffled ? 1100 : 600),
  )..addStatusListener((status) {
      // A giro finito, chi siede in fondo torna dietro il bordo del tavolo.
      if (status == AnimationStatus.completed && mounted) setState(() {});
    });
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _play();
  }

  @override
  void didUpdateWidget(PlayerGrid old) {
    super.didUpdateWidget(old);
    if (widget.shuffled && !_sameOrder(old.players, widget.players)) _play();
  }

  void _play() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _motion.value = 1;
    } else {
      _motion.forward(from: 0);
    }
  }

  static bool _sameOrder(List<Player> a, List<Player> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final players = widget.players;
        final layout = PokerTableLayout.fit(players.length, box.biggest);
        final rim = layout.oval(PokerTableLayout.rimRadius);
        final chosen = widget.selected == null ? -1 : players.indexOf(widget.selected!);
        // Prima chi siede in fondo, poi via via chi è più vicino: chi sta
        // davanti copre chi sta dietro. Il prescelto si alza sopra tutti.
        final order = [for (var i = 0; i < players.length; i++) i]
          ..sort((a, b) {
            if (a == chosen) return 1;
            if (b == chosen) return -1;
            return layout.seats[a].portrait.dy.compareTo(layout.seats[b].portrait.dy);
          });
        return SizedBox(
          width: box.maxWidth,
          height: box.maxHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: IgnorePointer(child: CustomPaint(painter: _TablePainter(layout))),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: _Spotlight(seat: chosen < 0 ? null : layout.seats[chosen], layout: layout),
                ),
              ),
              for (final index in order) _seat(index, players[index], layout, rim),
            ],
          ),
        );
      },
    );
  }

  Widget _seat(int index, Player player, PokerTableLayout layout, Path rim) {
    final seat = layout.seats[index];
    final open = widget.selectable?.contains(player) ?? false;
    final box = PokerTableLayout.footprint(seat.portrait, seat.size);
    final origin = box.topLeft;
    final selected = player == widget.selected;
    // Chi siede in fondo ha le spalle dietro il bordo; chi viene scelto si
    // alza e si vede intero. Mentre si cambia sedia, nessuno è dietro niente.
    final behind = seat.depth < 0.5 && !selected && (_motion.isCompleted || !widget.shuffled);
    return Positioned(
      key: ValueKey(player.id),
      left: origin.dx,
      top: origin.dy,
      width: box.width,
      height: box.height,
      child: AnimatedBuilder(
        animation: _motion,
        builder: (context, child) => widget.shuffled
            ? _travel(index, layout, child!)
            : _arrive(index, layout.seats.length, child!),
        child: _Seat(
          player: player,
          size: seat.size,
          occluder: behind ? rim.shift(-origin) : null,
          alive: widget.isAlive(player),
          knowledge: widget.knowledgeOf(player),
          isViewer: player == widget.viewer,
          selected: selected,
          othersChosen: widget.selected != null && !selected,
          silenced: player == widget.silenced,
          stamp: widget.stamp,
          choice: widget.selectable == null
              ? _Choice.none
              : open
              ? _Choice.open
              : _Choice.closed,
          onTap: open && widget.onSelect != null ? () => widget.onSelect!(player) : null,
        ),
      ),
    );
  }

  /// Al tavolo di tutti i giocatori si siedono uno dopo l'altro, in giro.
  Widget _arrive(int index, int count, Widget child) {
    final t = _motion.value;
    if (t >= 1) return child;
    final start = 0.45 * index / max(1, count);
    final p = Curves.easeOutBack.transform(((t - start) / 0.55).clamp(0.0, 1.0));
    return Opacity(
      opacity: p.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(0, -14 * (1 - p)),
        child: Transform.scale(scale: 0.85 + 0.15 * p, child: child),
      ),
    );
  }

  /// Al tavolo segreto tutti si alzano e girano intorno al tavolo fino alla
  /// sedia nuova, metà in un verso e metà nell'altro, incrociandosi. Si parte
  /// dalla sedia di fronte: il giro dipende solo dal posto d'arrivo.
  Widget _travel(int index, PokerTableLayout layout, Widget child) {
    final t = _motion.value;
    if (t >= 1) return child;
    final count = layout.seats.length;
    final to = layout.seats[index];
    final from = layout.seats[PokerTableLayout.shuffleSource(index, count)];
    final start = 0.2 * index / max(1, count);
    final p = Curves.easeInOutCubic.transform(((t - start) / 0.8).clamp(0.0, 1.0));
    var path = (to.turn - from.turn) % 1;
    if (index.isOdd) path -= 1;
    final here = layout.place(from.turn + path * p);
    final hop = sin(pi * p);
    // Chi gira in un verso passa dentro, verso il panno; l'altro passa fuori.
    final inward = (layout.center - here.portrait) * (index.isOdd ? 0.16 : -0.06) * hop;
    return Transform.translate(
      offset: here.portrait - to.portrait + inward + Offset(0, -to.size * 0.18 * hop),
      child: Transform.scale(scale: here.size / to.size * (1 + 0.06 * hop), child: child),
    );
  }
}

/// Un posto intorno al tavolo: dove sta il centro del ritratto, quanto è
/// grande, quanto è vicino (0 in fondo, 1 davanti) e il punto del bordo che
/// ha davanti.
/// [turn] dice dove sta nel giro del tavolo, da 0 a 1 (vedi [PokerTableLayout.outline]).
typedef TableSeat = ({Offset portrait, double size, double depth, Offset rim, double turn});

/// La geometria del tavolo per [count] posti in uno spazio: un tavolo da
/// poker (due lati dritti e due teste tonde) visto in prospettiva, più
/// stretto in fondo, e i posti distribuiti in modo che nessuno copra il
/// vicino, con i ritratti più grandi che lo spazio concede.
class PokerTableLayout {
  final Size space;
  final Offset center;

  /// I semiassi dell'anello dove siedono i giocatori; il bordo del tavolo è
  /// poco più dentro.
  final double rx;
  final double ry;

  /// Il ritratto di chi siede proprio davanti.
  final double frontSize;
  final List<TableSeat> seats;

  /// Quanto rimpicciolisce chi siede in fondo rispetto a chi sta davanti.
  final double backScale;

  const PokerTableLayout._(this.space, this.center, this.rx, this.ry, this.frontSize, this.backScale, this.seats);

  /// La prospettiva piena; con tanti giocatori in poco spazio si appiattisce,
  /// perché chi siede in fondo resti riconoscibile.
  static const _deepest = 0.72;
  static const _smallestBack = 30.0;

  /// La misura minima di un posto da toccare, anche con sedici giocatori.
  static const minTap = 46.0;
  static const maxSize = 104.0;
  static const _gap = 1.0;

  /// Il bordo esterno e il panno, in frazioni dell'anello dei posti.
  static const rimRadius = 0.86;
  static const feltRadius = 0.75;

  /// Metà del tratto dritto dei lati lunghi, in frazioni della profondità.
  static const _straight = 0.34;

  /// La scala di un punto dalla sua profondità [z] (-1 in fondo, 1 davanti).
  double scaleAt(double z) => _scale(backScale, z);
  static double _scale(double back, double z) => back + (1 - back) * (z + 1) / 2;

  static double boxWidth(double size) => max(size * 1.28, minTap);
  static double chairTop(double size) => max(size * 0.12, minTap - size * 0.8 - plaqueHeight(size));
  static double plaqueHeight(double size) => max(14.0, size * 0.25);

  /// La targhetta copre il fondo del ritratto, le spalle: la faccia resta.
  static double plaqueTop(double size) => chairTop(size) + size * 0.8;
  static double boxHeight(double size) => plaqueTop(size) + plaqueHeight(size);

  /// Lo spazio che occupa (e che si tocca) un posto col ritratto in [portrait].
  static Rect footprint(Offset portrait, double size) => Rect.fromLTWH(
    portrait.dx - boxWidth(size) / 2,
    portrait.dy - _above(size),
    boxWidth(size),
    boxHeight(size),
  );

  /// Quanto il posto sporge sopra e sotto il centro del ritratto.
  static double _above(double size) => size / 2 + chairTop(size);
  static double _below(double size) => boxHeight(size) - _above(size);

  /// Chi siede in fondo sta un po' più dentro e più in alto, con le spalle
  /// dietro il bordo; davanti ci si siede sul bordo stesso.
  static double _ring(double depth) => lerpDouble(0.9, 1, depth)!;
  static double _lift(double size, double depth) => size * lerpDouble(-0.16, 0.04, depth)!;

  /// Da quale sedia arriva chi siede al posto [index] quando si rimescola:
  /// quella di fronte. Dipende solo dal posto, non da chi c'era prima.
  static int shuffleSource(int index, int count) => count < 2 ? index : (index + count ~/ 2) % count;

  /// Il contorno del tavolo, prima della prospettiva: [u] da 0 a 1 fa il giro
  /// in senso orario dal centro del lato in fondo. `x` va da -1 a 1, `z` da
  /// -1 (in fondo) a 1 (davanti).
  static Offset outline(double u) {
    const h = _straight, e = 1 - _straight;
    const arc = pi / 2 * (1 + e) / 2;
    const side = 2 * h;
    const total = 4 * arc + 2 * side;
    var at = (u % 1) * total;
    if (at < arc) return Offset(sin(at / arc * pi / 2), -h - e * cos(at / arc * pi / 2));
    at -= arc;
    if (at < side) return Offset(1, -h + at);
    at -= side;
    if (at < 2 * arc) {
      final a = at / arc * pi / 2;
      return Offset(cos(a), h + e * sin(a));
    }
    at -= 2 * arc;
    if (at < side) return Offset(-1, h - at);
    at -= side;
    final a = at / arc * pi / 2;
    return Offset(-cos(a), -h - e * sin(a));
  }

  /// Un punto del tavolo in prospettiva, a [r] volte l'anello dei posti.
  Offset project(Offset unit, double r) => _project(backScale, center, rx, ry, unit, r);

  static Offset _project(double back, Offset center, double rx, double ry, Offset unit, double r) {
    final z = unit.dy * r;
    return center + Offset(rx * r * unit.dx * _scale(back, z) / _scale(back, 0), ry * z);
  }

  /// Dove starebbe e quanto sarebbe grande un ritratto al punto [turn] del
  /// giro: serve a chi cammina intorno al tavolo.
  ({Offset portrait, double size}) place(double turn) {
    final unit = outline(turn);
    final depth = (unit.dy + 1) / 2;
    final size = frontSize * scaleAt(unit.dy);
    return (portrait: project(unit, _ring(depth)) + Offset(0, _lift(size, depth)), size: size);
  }

  /// Il contorno del tavolo a [r], abbassato di [drop] davanti (lo spessore).
  Path oval(double r, {double drop = 0}) {
    final path = Path();
    const steps = 120;
    for (var i = 0; i <= steps; i++) {
      final unit = outline(i / steps);
      final p = project(unit, r) + Offset(0, drop * scaleAt(unit.dy));
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  factory PokerTableLayout.fit(int count, Size space) {
    final n = max(1, count);
    PokerTableLayout? attempt(double front, {bool force = false}) {
      final deep = max(_deepest, min(1.0, _smallestBack / front));
      double scaleAt(double z) => _scale(deep, z);
      final back = front * deep;
      final above = -_lift(back, 0) + _above(back);
      final below = _lift(front, 1) + _below(front);
      // In fondo l'anello è più stretto: l'altezza si divide di conseguenza.
      var ry = (space.height - above - below) / (_ring(0) + _ring(1));
      if (ry < 12 && !force) return null;
      ry = max(ry, 12);
      var rx = double.infinity;
      for (var i = 0; i < 96; i++) {
        final unit = outline(i / 96);
        final depth = (unit.dy + 1) / 2;
        final r = _ring(depth);
        final reach = unit.dx.abs() * r * scaleAt(unit.dy * r) / scaleAt(0);
        if (reach < 0.05) continue;
        rx = min(rx, (space.width / 2 - boxWidth(front * scaleAt(unit.dy)) / 2) / reach);
      }
      if (rx < 12 && !force) return null;
      rx = max(rx, 12);
      // Né un biliardo né un tombino: il tavolo resta un tavolo.
      ry = min(ry, rx * 1.75);
      rx = min(rx, ry * 1.4);
      final top = above + ry * _ring(0);
      final bottom = space.height - below - ry * _ring(1);
      final center = Offset(space.width / 2, (top + bottom) / 2);

      ({Offset at, double size, double depth}) seatAt(double u) {
        final unit = outline(u);
        final depth = (unit.dy + 1) / 2;
        final size = front * scaleAt(unit.dy);
        return (
          at: _project(deep, center, rx, ry, unit, _ring(depth)) + Offset(0, _lift(size, depth)),
          size: size,
          depth: depth,
        );
      }

      // Il giro del tavolo misurato in posti: ogni tratto vale quanto è lungo
      // diviso quanto spazio chiede lì un posto, nella direzione del giro.
      const steps = 480;
      final room = List<double>.filled(steps + 1, 0);
      var previous = seatAt(0).at;
      for (var i = 1; i <= steps; i++) {
        final here = seatAt(i / steps);
        final step = here.at - previous;
        final length = step.distance;
        final need = length == 0
            ? 1.0
            : (step.dx.abs() * (boxWidth(here.size) + _gap) + step.dy.abs() * (boxHeight(here.size) + _gap)) / length;
        room[i] = room[i - 1] + length / need;
        previous = here.at;
      }
      final total = room[steps];
      if (total < n && !force) return null;

      final seats = <TableSeat>[];
      var k = 0;
      for (var s = 0; s < n; s++) {
        final target = s * total / n;
        while (k < steps - 1 && room[k + 1] < target) {
          k++;
        }
        final span = room[k + 1] - room[k];
        final f = span == 0 ? 0.0 : (target - room[k]) / span;
        final u = (k + f) / steps;
        final seat = seatAt(u);
        seats.add((
          portrait: seat.at,
          turn: u,
          size: seat.size,
          depth: seat.depth,
          rim: _project(deep, center, rx, ry, outline(u), rimRadius),
        ));
      }
      // La misura lungo il giro è una stima: sulle curve due posti vicini
      // possono ancora toccarsi. Qui si controlla davvero.
      if (!force) {
        final boxes = [for (final seat in seats) footprint(seat.portrait, seat.size)];
        for (var i = 0; i < boxes.length; i++) {
          for (var j = i + 1; j < boxes.length; j++) {
            final overlap = boxes[i].intersect(boxes[j]);
            if (overlap.width > 0.5 && overlap.height > 0.5) return null;
          }
        }
      }
      return PokerTableLayout._(space, center, rx, ry, front, deep, seats);
    }

    var low = 24.0, high = min(maxSize, space.width * 0.3);
    final floor = attempt(low);
    if (floor == null) return attempt(low, force: true)!;
    var best = floor;
    for (var i = 0; i < 18; i++) {
      final mid = (low + high) / 2;
      final fit = attempt(mid);
      if (fit != null) {
        best = fit;
        low = mid;
      } else {
        high = mid;
      }
    }
    return attempt(high) ?? best;
  }
}

/// Il tavolo: l'ombra sul pavimento, lo spessore del legno davanti, il bordo,
/// il panno con la linea d'oro, la luce della lampada e due pile di fiches.
class _TablePainter extends CustomPainter {
  final PokerTableLayout layout;

  _TablePainter(this.layout);

  @override
  void paint(Canvas canvas, Size size) {
    final rim = layout.oval(PokerTableLayout.rimRadius);
    final bounds = rim.getBounds();
    final thick = layout.frontSize * 0.16;

    canvas.drawPath(
      layout.oval(PokerTableLayout.rimRadius * 1.03, drop: thick * 2.2),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.6)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, thick * 1.6),
    );
    // Lo spessore: il fianco del tavolo, visto solo davanti.
    final side = layout.oval(PokerTableLayout.rimRadius, drop: thick);
    canvas.drawPath(
      side,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2A160A), Color(0xFF4A2A14), Color(0xFF1C0F07)],
        ).createShader(bounds.inflate(thick)),
    );
    canvas.drawPath(
      rim,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: PokerFelt.wood,
        ).createShader(bounds),
    );
    // Il lucido della vernice sul legno, dove batte la lampada.
    canvas.drawPath(
      layout.oval(PokerTableLayout.rimRadius * 0.97),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.0, thick * 0.18)
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [const Color(0xFFE8B98A).withValues(alpha: 0.55), Colors.transparent],
        ).createShader(bounds),
    );

    final felt = layout.oval(PokerTableLayout.feltRadius);
    final feltBounds = felt.getBounds();
    canvas.drawPath(
      felt,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.2),
          radius: 0.85,
          colors: PokerFelt.felt,
          stops: const [0, 0.6, 1],
        ).createShader(feltBounds),
    );
    // Il bordo imbottito getta un'ombra sul panno.
    canvas.save();
    canvas.clipPath(felt);
    canvas.drawPath(
      felt,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = thick * 1.2
        ..color = Colors.black.withValues(alpha: 0.5)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, thick * 0.7),
    );
    canvas.restore();
    canvas.drawPath(
      layout.oval(PokerTableLayout.feltRadius * 0.8),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..color = AppColors.gold.withValues(alpha: 0.38),
    );
    // La lampada appesa sopra il tavolo: un cerchio di luce calda sul panno.
    canvas.drawPath(
      felt,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          center: const Alignment(0, -0.1),
          radius: 0.6,
          colors: [const Color(0xFF6E5A20).withValues(alpha: 0.55), Colors.transparent],
        ).createShader(feltBounds),
    );
    _chips(canvas);
  }

  /// Tre pile di fiches nel piatto, schiacciate dalla prospettiva.
  void _chips(Canvas canvas) {
    final unit = layout.frontSize * 0.11;
    if (unit < 3) return;
    const piles = [
      (dx: -1.6, dy: -0.3, color: Color(0xFF9C2B34), height: 4),
      (dx: 0.0, dy: 0.45, color: Color(0xFF1A1714), height: 6),
      (dx: 1.55, dy: -0.15, color: Color(0xFFE6DCCB), height: 3),
    ];
    for (final pile in piles) {
      final base = layout.center + Offset(pile.dx * unit * 1.5, pile.dy * unit * 1.5 - layout.ry * 0.06);
      for (var i = 0; i < pile.height; i++) {
        final chip = Rect.fromCenter(center: base - Offset(0, i * unit * 0.32), width: unit * 1.9, height: unit * 0.95);
        canvas.drawOval(chip.shift(Offset(0, unit * 0.18)), Paint()..color = Colors.black.withValues(alpha: 0.45));
        canvas.drawOval(chip, Paint()..color = pile.color);
        canvas.drawOval(
          chip.deflate(unit * 0.22),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = max(0.6, unit * 0.12)
            ..color = Colors.white.withValues(alpha: pile.color.computeLuminance() > 0.5 ? 0.0 : 0.55),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_TablePainter old) =>
      old.layout.space != layout.space || old.layout.seats.length != layout.seats.length;
}

/// Il riflettore su chi è stato scelto: un fascio dall'alto e una pozza di
/// luce sul panno davanti al suo posto.
class _Spotlight extends StatelessWidget {
  final TableSeat? seat;
  final PokerTableLayout layout;

  const _Spotlight({required this.seat, required this.layout});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      child: seat == null
          ? const SizedBox.expand()
          : SizedBox.expand(
              key: ValueKey(seat!.portrait),
              child: CustomPaint(painter: _SpotlightPainter(seat!, layout)),
            ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  final TableSeat seat;
  final PokerTableLayout layout;

  _SpotlightPainter(this.seat, this.layout);

  @override
  void paint(Canvas canvas, Size size) {
    final pool = Offset.lerp(seat.rim, layout.center, 0.18)!;
    final reach = seat.size * 1.5;
    final top = min(0.0, seat.portrait.dy - seat.size * 3);
    final beam = Path()
      ..moveTo(seat.portrait.dx - seat.size * 0.2, top)
      ..lineTo(seat.portrait.dx + seat.size * 0.2, top)
      ..lineTo(pool.dx + reach, pool.dy)
      ..lineTo(pool.dx - reach, pool.dy)
      ..close();
    canvas.drawPath(
      beam,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, const Color(0xFF5A4A1E).withValues(alpha: 0.5)],
        ).createShader(Rect.fromLTRB(pool.dx - reach, top, pool.dx + reach, pool.dy))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, seat.size * 0.12),
    );
    final oval = Rect.fromCenter(center: pool, width: reach * 2.2, height: reach * 1.1);
    canvas.drawOval(
      oval,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          colors: [const Color(0xFF8A7230).withValues(alpha: 0.9), Colors.transparent],
        ).createShader(oval),
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) => old.seat != seat;
}

/// Se su un posto c'è da scegliere: niente (il tavolo si guarda e basta),
/// sì, oppure no perché stavolta tocca ad altri.
enum _Choice { none, open, closed }

/// Un giocatore al suo posto: lo schienale della sedia, il ritratto, i segni
/// di ruolo dove chi guarda ha diritto di saperli e la targhetta col nome.
/// Chi non c'è più lascia la sedia vuota, col pugnale e un fiore.
class _Seat extends StatelessWidget {
  final Player player;
  final double size;
  final bool alive;
  final Knowledge knowledge;
  final bool isViewer;
  final bool selected;
  final bool othersChosen;
  final bool silenced;
  final String? stamp;
  final _Choice choice;
  final VoidCallback? onTap;

  /// Il bordo del tavolo, nelle coordinate del posto, se ci si siede dietro.
  final Path? occluder;

  const _Seat({
    required this.player,
    required this.size,
    required this.occluder,
    required this.alive,
    required this.knowledge,
    required this.isViewer,
    required this.selected,
    required this.othersChosen,
    required this.silenced,
    required this.stamp,
    required this.choice,
    required this.onTap,
  });

  static const _mafiaRed = Color(0xFFE5606A);
  static const _cleanGreen = Color(0xFF6FBF9A);
  static const _ink = Color(0xFFE2323D);

  /// Chi si può scegliere sta in piena luce, anche da morto: resta il
  /// pugnale a dire che non c'è più. Gli altri sfumano, i morti più dei vivi.
  double get _opacity => switch (choice) {
    _Choice.open => othersChosen ? 0.78 : 1,
    _Choice.closed => alive ? 0.5 : 0.4,
    _Choice.none => alive ? 1 : 0.55,
  };

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    final d = size;
    final width = PokerTableLayout.boxWidth(d);
    final top = PokerTableLayout.chairTop(d);
    final plaque = PokerTableLayout.plaqueHeight(d);
    final chair = d * 1.14;
    final role = knowledge.role;
    final chip = max(15.0, d * 0.3);
    final badge = _badge(t, d);
    // Il timbro si legge anche sul ritratto più piccolo: sporge, ma il
    // prescelto sta sopra tutti.
    final stampWidth = max(d * 1.15, 64.0);
    Widget sitter = Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: (width - chair) / 2,
          top: 0,
          width: chair,
          height: top + d * (alive ? 0.8 : 1.0),
          child: CustomPaint(painter: _ChairPainter(empty: !alive, lit: selected)),
        ),
        if (alive)
          Positioned(left: (width - d) / 2, top: top, child: _portrait(d))
        else
          Positioned(left: (width - d) / 2, top: top, width: d, height: d, child: _emptyChair(d)),
      ],
    );
    if (occluder != null) sitter = ClipPath(clipper: _Behind(occluder!), child: sitter);
    final seat = Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(child: sitter),
        if (role != null)
          Positioned(left: (width - d) / 2 - chip * 0.2, top: top + d * 0.8 - chip * 0.85, child: _chip(chip, role.color, role.icon)),
        if (silenced && alive)
          Positioned(
            left: (width + d) / 2 - chip * 0.8,
            top: top - chip * 0.15,
            child: _chip(chip, AppColors.gold, Icons.voice_over_off, ink: AppColors.background),
          ),
        if (selected && stamp == null)
          Positioned(
            left: (width + d) / 2 - chip * 0.8,
            top: top + d * 0.8 - chip * 0.85,
            child: _chip(chip, AppColors.gold, Icons.check, ink: AppColors.background),
          ),
        if (badge != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: plaque * 0.86,
            height: max(11.0, d * 0.17),
            child: Center(child: badge),
          ),
        Positioned(left: 0, right: 0, bottom: 0, height: plaque, child: _plaque(d, plaque)),
        if (selected && stamp != null)
          Positioned(
            left: (width - stampWidth) / 2,
            width: stampWidth,
            top: top + d * 0.5 - stampWidth * 0.2,
            height: stampWidth * 0.4,
            child: _Stamp(text: stamp!, width: stampWidth),
          ),
      ],
    );
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: _opacity,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: selected ? 1 : 0),
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutBack,
        // Il prescelto si alza dalla sedia, sotto il riflettore.
        builder: (context, rise, child) => Transform.translate(
          offset: Offset(0, -d * 0.12 * rise),
          child: Transform.scale(scale: 1 + 0.09 * rise, alignment: Alignment.bottomCenter, child: child),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(d * 0.2),
            onTap: pressed(onTap, Press.card),
            child: seat,
          ),
        ),
      ),
    );
  }

  Widget _portrait(double d) {
    return Container(
      width: d,
      height: d,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.55), blurRadius: d * 0.12, offset: Offset(0, d * 0.06)),
          if (selected) BoxShadow(color: AppColors.gold.withValues(alpha: 0.6), blurRadius: d * 0.35, spreadRadius: d * 0.03),
        ],
      ),
      foregroundDecoration: selected
          ? BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.gold, width: max(2.5, d * 0.06)),
            )
          : null,
      child: PlayerAvatar(seed: player.name, size: d),
    );
  }

  /// La sedia di chi non c'è più: il pugnale piantato nello schienale e un
  /// garofano posato sul cuscino.
  Widget _emptyChair(double d) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Text(
          PlayerAvatar.dagger,
          style: TextStyle(
            fontFamily: 'Georgia',
            fontFamilyFallback: const ['serif'],
            fontSize: d * 0.62,
            height: 1,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            shadows: [Shadow(color: Colors.black, blurRadius: d * 0.08)],
          ),
        ),
        Positioned(
          right: d * 0.06,
          bottom: d * 0.02,
          child: Transform.rotate(
            angle: -0.5,
            child: Icon(Icons.local_florist, size: d * 0.3, color: const Color(0xFF8C4A4E)),
          ),
        ),
      ],
    );
  }

  Widget _plaque(double d, double height) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: height * 0.3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(height * 0.22),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: alive
              ? (selected
                    ? const [Color(0xFFFFE9A3), Color(0xFFE1B94A), Color(0xFF9A7424)]
                    : const [Color(0xFFE6CB7C), Color(0xFFB8922F), Color(0xFF7D5E1D)])
              : const [Color(0xFF9A948C), Color(0xFF6E6963), Color(0xFF4A4642)],
          stops: const [0, 0.55, 1],
        ),
        border: Border.all(color: const Color(0xFF2A1D0C), width: 0.8),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 3, offset: const Offset(0, 1.5))],
      ),
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          player.name,
          maxLines: 1,
          style: TextStyle(
            fontFamily: 'Georgia',
            fontFamilyFallback: const ['serif'],
            color: const Color(0xFF241809),
            fontSize: height * 0.66,
            height: 1.1,
            fontWeight: FontWeight.w700,
            decoration: alive ? null : TextDecoration.lineThrough,
            decorationColor: const Color(0xFF241809),
            shadows: const [Shadow(color: Color(0x66FFFFFF), offset: Offset(0, 0.6))],
          ),
        ),
      ),
    );
  }

  static Widget _chip(double size, Color color, IconData icon, {Color ink = AppColors.textPrimary}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF14110F), width: max(1.5, size * 0.08)),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 4)],
      ),
      child: Icon(icon, size: size * 0.56, color: ink),
    );
  }

  Widget? _badge(AppStrings t, double d) {
    if (isViewer) return _label(t.youBadge, AppColors.gold, d);
    if (knowledge.role != null) return null;
    return switch (knowledge.team) {
      Team.mafia => _label(t.familyBadge, _mafiaRed, d),
      Team.citizens => _label(t.innocentBadge, _cleanGreen, d),
      null => null,
    };
  }

  static Widget _label(String text, Color color, double d) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: max(4.0, d * 0.07)),
      decoration: BoxDecoration(
        color: Color.lerp(AppColors.background, color, 0.22),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.8)),
      ),
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          style: TextStyle(color: color, fontSize: max(8.0, d * 0.12), fontWeight: FontWeight.w800, letterSpacing: 1),
        ),
      ),
    );
  }
}

/// Tutto tranne il tavolo: quello che ci sta dietro non si vede.
class _Behind extends CustomClipper<Path> {
  final Path table;

  _Behind(this.table);

  @override
  Path getClip(Size size) => Path.combine(
    PathOperation.difference,
    Path()..addRect(Rect.fromLTRB(-size.width, -size.height, size.width * 2, size.height * 2)),
    table,
  );

  @override
  bool shouldReclip(_Behind old) => old.table.getBounds() != table.getBounds();
}

/// Lo schienale di una sedia da bisca: cuoio color vino, bordo di legno e
/// borchie d'ottone. Vuota, perde il colore.
class _ChairPainter extends CustomPainter {
  final bool empty;
  final bool lit;

  const _ChairPainter({required this.empty, required this.lit});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final back = Path()
      ..moveTo(0, h)
      ..lineTo(0, w * 0.42)
      ..quadraticBezierTo(0, 0, w * 0.5, 0)
      ..quadraticBezierTo(w, 0, w, w * 0.42)
      ..lineTo(w, h)
      ..close();
    final bounds = Offset.zero & size;
    canvas.drawPath(
      back.shift(Offset(0, w * 0.04)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.5)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.05),
    );
    canvas.drawPath(back, Paint()..color = empty ? const Color(0xFF2E2A27) : const Color(0xFF2B160C));
    final leather = Path()
      ..moveTo(w * 0.1, h)
      ..lineTo(w * 0.1, w * 0.44)
      ..quadraticBezierTo(w * 0.1, w * 0.09, w * 0.5, w * 0.09)
      ..quadraticBezierTo(w * 0.9, w * 0.09, w * 0.9, w * 0.44)
      ..lineTo(w * 0.9, h)
      ..close();
    canvas.drawPath(
      leather,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: empty
              ? const [Color(0xFF5B5550), Color(0xFF34302C)]
              : lit
              ? const [Color(0xFF9A3A34), Color(0xFF4E1612)]
              : const [Color(0xFF7A2626), Color(0xFF3A0F0E)],
        ).createShader(bounds),
    );
    // Le borchie lungo l'arco dello schienale.
    final stud = Paint()..color = (empty ? const Color(0xFF8A847C) : const Color(0xFFC9A54E)).withValues(alpha: 0.9);
    for (var i = 0; i <= 8; i++) {
      final a = pi + i * pi / 8;
      final c = Offset(w * 0.5 + cos(a) * w * 0.4, w * 0.46 + sin(a) * w * 0.37);
      canvas.drawCircle(c, max(0.7, w * 0.022), stud);
    }
  }

  @override
  bool shouldRepaint(_ChairPainter old) => old.empty != empty || old.lit != lit;
}

/// Il timbro rosso sul ritratto dell'imputato, storto come vuole la mano.
class _Stamp extends StatelessWidget {
  final String text;
  final double width;

  const _Stamp({required this.text, required this.width});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Transform.rotate(
        angle: -0.2,
        child: Container(
          constraints: BoxConstraints(maxWidth: width),
          padding: EdgeInsets.symmetric(horizontal: width * 0.05, vertical: width * 0.025),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            border: Border.all(color: _Seat._ink, width: max(1.5, width * 0.025)),
            borderRadius: BorderRadius.circular(width * 0.04),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              text,
              maxLines: 1,
              style: TextStyle(
                fontFamily: 'Georgia',
                fontFamilyFallback: const ['serif'],
                fontSize: width * 0.17,
                fontWeight: FontWeight.w900,
                letterSpacing: width * 0.012,
                height: 1.2,
                color: _Seat._ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
