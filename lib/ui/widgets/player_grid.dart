import 'dart:math';
import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../rules/knowledge.dart';
import '../../rules/player.dart';
import '../../rules/role.dart';
import '../avatar/avatar_look.dart';
import '../avatar/look_painter.dart';
import '../avatar/seated_character.dart';
import '../press.dart';
import '../theme/app_theme.dart';
import '../theme/role_style.dart';
import 'deal_table.dart' show PokerFelt;
import 'player_avatar.dart';

/// Il tavolo da poker della partita, visto dalla propria sedia: il bordo
/// di legno qui davanti, le proprie mani sul panno, il tavolo che si
/// allontana sotto la lampada e intorno gli altri, seduti, ognuno col suo
/// look ([AvatarLook]), più grandi ai lati e più piccoli di fronte. Davanti
/// a ognuno una targhetta d'ottone col nome.
///
/// L'ordine è quello di [players], da sinistra a destra lungo il giro del
/// tavolo: chi chiama decide se è il tavolo pubblico o uno segreto
/// rimescolato (vedi `seating.dart`). Dove cade un posto dipende solo dal
/// numero dei posti, mai da chi ci siede. Chi tiene il telefono ([viewer])
/// non siede di fronte: è la sedia da cui si guarda, in basso.
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

  /// Chi oggi ha la bocca cucita: lo si vede dal segno accanto alla testa.
  final Player? silenced;

  /// Il timbro sul petto di chi è scelto (al voto, "imputato"). Senza, un
  /// segno d'oro.
  final String? stamp;

  /// I posti sono appena stati rimescolati: all'arrivo i giocatori si alzano
  /// e cambiano sedia lungo il tavolo. Da dove partono dipende solo dal
  /// posto d'arrivo, così il giro non racconta niente del turno prima.
  final bool shuffled;

  /// Il look di ognuno; senza, quello che gli spetta dal nome.
  final AvatarLook Function(Player)? lookOf;

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
    this.lookOf,
  });

  @override
  State<PlayerGrid> createState() => _PlayerGridState();
}

class _PlayerGridState extends State<PlayerGrid> with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: widget.shuffled ? 1300 : 900),
  );
  bool _started = false;
  PokerTableLayout? _layout;

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

  AvatarLook _lookOf(Player player) => widget.lookOf?.call(player) ?? AvatarLook.of(player.name);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final viewer = widget.viewer != null && widget.players.contains(widget.viewer) ? widget.viewer : null;
        final across = [for (final p in widget.players) if (p != viewer) p];
        final space = box.biggest;
        var layout = _layout;
        if (layout == null || layout.space != space || layout.seats.length != across.length || layout.hasOwn != (viewer != null)) {
          layout = _layout = PokerTableLayout.fit(across.length, space, own: viewer != null);
        }
        final table = layout;
        return SizedBox(
          width: space.width,
          height: space.height,
          child: IdleClock(
            builder: (context, time) => AnimatedBuilder(
              animation: _motion,
              builder: (context, _) => _scene(table, across, viewer, time),
            ),
          ),
        );
      },
    );
  }

  Widget _scene(PokerTableLayout layout, List<Player> across, Player? viewer, ValueListenable<double> time) {
    final chosen = widget.selected == null ? -1 : across.indexOf(widget.selected!);
    final places = [for (var i = 0; i < across.length; i++) _placeOf(i, layout)];
    // Prima chi siede in fondo, poi via via chi è più vicino: chi sta
    // davanti copre chi sta dietro. Il prescelto si alza sopra tutti.
    final order = [for (var i = 0; i < across.length; i++) i]
      ..sort((a, b) {
        if (a == chosen) return 1;
        if (b == chosen) return -1;
        return places[a].seat.base.dy.compareTo(places[b].seat.base.dy);
      });
    final ownChosen = viewer != null && viewer == widget.selected;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(child: CustomPaint(painter: _TablePainter(layout))),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(child: CustomPaint(painter: _HazePainter(layout, time))),
        ),
        // Mentre si cambia posto le sedie restano dove sono.
        if (widget.shuffled && _motion.value < 1)
          Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _ChairsPainter(layout)))),
        for (final index in order)
          if (index != chosen) _seat(across[index], places[index], layout, time),
        if (viewer != null && !ownChosen) _own(viewer, layout),
        if (chosen >= 0 || ownChosen)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _SpotlightPainter(
                  ownChosen ? layout.own!.center : places[chosen].seat.base,
                  ownChosen ? layout.own!.width * 0.35 : places[chosen].seat.size,
                  layout,
                ),
              ),
            ),
          ),
        if (chosen >= 0) _seat(across[chosen], places[chosen], layout, time),
        if (viewer != null && ownChosen) _own(viewer, layout),
      ],
    );
  }

  /// Dove sta adesso chi siede al posto [index]: al suo posto, o in giro per
  /// il tavolo mentre cambia sedia, o mentre arriva e si siede.
  _Place _placeOf(int index, PokerTableLayout layout) {
    final seat = layout.seats[index];
    final t = _motion.value;
    if (t >= 1) return (seat: seat, rise: 0, opacity: 1);
    final count = layout.seats.length;
    if (!widget.shuffled) {
      final start = 0.45 * index / max(1, count);
      final p = Curves.easeOut.transform(((t - start) / 0.55).clamp(0.0, 1.0));
      return (seat: seat, rise: 1 - p, opacity: p);
    }
    final from = layout.seats[PokerTableLayout.shuffleSource(index, count)];
    final start = 0.25 * index / max(1, count);
    final p = Curves.easeInOutCubic.transform(((t - start) / 0.75).clamp(0.0, 1.0));
    final up = Curves.easeOut.transform((p / 0.2).clamp(0.0, 1.0)) * (1 - Curves.easeIn.transform(((p - 0.8) / 0.2).clamp(0.0, 1.0)));
    // Si gira intorno al tavolo, non lo si attraversa: la strada lungo il
    // giro, partendo e arrivando esattamente alle due sedie.
    final here = layout.place(lerpDouble(from.turn, seat.turn, p)!).base;
    final straight = Offset.lerp(layout.place(from.turn).base, layout.place(seat.turn).base, p)!;
    final size = lerpDouble(from.size, seat.size, p)!;
    final base = Offset.lerp(from.base, seat.base, p)! + (here - straight) - Offset(0, size * 0.12 * sin(pi * p));
    return (
      seat: (
        base: base,
        size: size,
        depth: lerpDouble(from.depth, seat.depth, p)!,
        turn: seat.turn,
        light: Offset.lerp(from.light, seat.light, p)!,
      ),
      rise: up,
      opacity: 1,
    );
  }

  _Choice _choiceOf(Player player) => widget.selectable == null
      ? _Choice.none
      : (widget.selectable!.contains(player) ? _Choice.open : _Choice.closed);

  Widget _seat(Player player, _Place place, PokerTableLayout layout, ValueListenable<double> time) {
    final seat = place.seat;
    final box = PokerTableLayout.footprint(seat);
    final open = _choiceOf(player) == _Choice.open;
    return Positioned(
      key: ValueKey(player.id),
      left: box.left,
      top: box.top,
      width: box.width,
      height: box.height,
      child: Opacity(
        opacity: place.opacity,
        child: _Seat(
          player: player,
          look: _lookOf(player),
          seat: seat,
          origin: box.topLeft,
          walking: place.rise,
          moving: widget.shuffled && _motion.value < 1,
          time: time,
          alive: widget.isAlive(player),
          knowledge: widget.knowledgeOf(player),
          selected: player == widget.selected,
          othersChosen: widget.selected != null && player != widget.selected,
          silenced: player == widget.silenced,
          stamp: widget.stamp,
          choice: _choiceOf(player),
          onTap: open && widget.onSelect != null ? () => widget.onSelect!(player) : null,
        ),
      ),
    );
  }

  /// La propria sedia: le proprie mani sul bordo del tavolo, le carte
  /// coperte e la targhetta. Si tocca anche questa, se ci si può scegliere.
  Widget _own(Player viewer, PokerTableLayout layout) {
    final box = layout.own!;
    final open = _choiceOf(viewer) == _Choice.open;
    return Positioned(
      key: ValueKey(viewer.id),
      left: box.left,
      top: box.top,
      width: box.width,
      height: box.height,
      child: _OwnSeat(
        player: viewer,
        look: _lookOf(viewer),
        knowledge: widget.knowledgeOf(viewer),
        alive: widget.isAlive(viewer),
        selected: viewer == widget.selected,
        silenced: viewer == widget.silenced,
        choice: _choiceOf(viewer),
        onTap: open && widget.onSelect != null ? () => widget.onSelect!(viewer) : null,
      ),
    );
  }
}

typedef _Place = ({TableSeat seat, double rise, double opacity});

/// Un posto intorno al tavolo. [base] è il punto del bordo davanti al petto
/// di chi siede, [size] la larghezza delle sue spalle, [depth] quanto è
/// vicino (0 di fronte, 1 ai lati più vicini), [turn] dove sta lungo il giro
/// (da -1 a sinistra a 1 a destra). Sotto [base] il corpo sparisce dietro
/// il tavolo; [light] è da dove arriva la lampada.
/// [base]) il corpo sparisce dietro il tavolo; [light] è da dove arriva la
/// lampada.
typedef TableSeat = ({Offset base, double size, double depth, double turn, Offset light});

/// La geometria del tavolo visto dalla propria sedia, per [count] posti di
/// fronte in uno spazio: un tavolo da poker (due lati dritti e due teste
/// tonde) in prospettiva, e i posti lungo la metà lontana, disposti in modo
/// che nessuno copra il vicino, con le persone più grandi che lo spazio
/// concede. Con tanti giocatori il tavolo si allunga e chi siede in fondo
/// si fa piccolo, ma resta da toccare.
class PokerTableLayout {
  final Size space;
  final Offset center;
  final double rx;
  final double ry;

  /// Le spalle di chi siederebbe proprio qui davanti.
  final double frontSize;

  /// Quanto rimpicciolisce chi siede in fondo rispetto a chi sta davanti.
  final double backScale;
  final List<TableSeat> seats;

  /// La propria sedia, in basso, se chi guarda è al tavolo.
  final Rect? own;

  /// La fascia in basso col bordo vicino del tavolo.
  final double near;

  const PokerTableLayout._(this.space, this.center, this.rx, this.ry, this.frontSize, this.backScale, this.span, this.seats, this.own, this.near);

  /// Fin dove arrivano i posti lungo il giro, da una parte e dall'altra del
  /// posto di fronte: oltre ci sono le proprie mani. Quando si è in tanti
  /// in poco spazio, si scende lungo i lati fino quasi a toccarle.
  final double span;

  bool get hasOwn => own != null;

  /// La misura minima di un posto da toccare, anche con sedici giocatori.
  static const minTap = 44.0;
  static const maxSize = 132.0;
  static const _gap = 2.0;

  /// Il bordo esterno del legno, il panno e la riga d'oro, in frazioni
  /// dell'anello dove si siede.
  static const rimRadius = 1.0;
  static const feltRadius = 0.88;
  static const lineRadius = 0.7;

  /// Metà del tratto dritto dei lati lunghi, in frazioni della profondità.
  static const _straight = 0.34;

  static const _spans = [0.36, 0.42, 0.47];


  double scaleAt(double z) => _scale(backScale, z);
  static double _scale(double back, double z) => back + (1 - back) * (z + 1) / 2;

  static double plaqueHeight(double size) => max(13.0, size * 0.2);
  static double plaqueWidth(double size) => max(42.0, size * 1.05);

  /// Quanto il cappello più alto sporge sopra [TableSeat.base], in spalle.
  static const _headroom = 1.22;

  /// Lo spazio che occupa (e che si tocca) un posto: dalla tesa del
  /// cappello alla targhetta sul bordo.
  static Rect footprint(TableSeat seat) {
    final s = seat.size;
    final width = max(max(minTap + 0.01, s * 1.08), plaqueWidth(s) + 2);
    final plaque = plaqueCenter(seat);
    final bottom = plaque.dy + plaqueHeight(s) / 2 + 1;
    final top = min(seat.base.dy - _headroom * s, bottom - minTap - 0.01);
    return Rect.fromLTWH(seat.base.dx - width / 2, top, width, bottom - top);
  }

  /// Dove sta la targhetta: sul bordo, tra gli avambracci; per chi sta in
  /// piedi dietro, appuntata sul petto.
  static Offset plaqueCenter(TableSeat seat) =>
      seat.base + Offset(0, seat.size * 0.03);

  /// Da quale sedia arriva chi siede al posto [index] quando si rimescola:
  /// quella dall'altra parte del giro. Dipende solo dal posto, non da chi
  /// c'era prima.
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

  /// Un punto del piano del tavolo in prospettiva, a [r] volte l'anello.
  Offset project(Offset unit, double r) => _project(backScale, center, rx, ry, unit, r);

  static Offset _project(double back, Offset center, double rx, double ry, Offset unit, double r) {
    final z = unit.dy * r;
    return center + Offset(rx * r * unit.dx * _scale(back, z) / _scale(back, 0), ry * z);
  }

  /// Il posto al punto [turn] del giro (da -1 a 1): serve
  /// a chi cammina intorno al tavolo.
  TableSeat place(double turn) => _seatAt(span, backScale, center, rx, ry, frontSize, turn);

  static TableSeat _seatAt(double span, double back, Offset center, double rx, double ry, double front, double turn) {
    final unit = outline(turn * span);
    final z = unit.dy;
    final size = front * _scale(back, z);
    final rim = _project(back, center, rx, ry, unit, rimRadius);
    // Chi siede ai lati sta un po' fuori dal bordo, non sopra il panno.
    final base = rim + Offset(unit.dx * unit.dx.abs() * size * 0.3, 0);
    final lamp = center - Offset(0, ry * 2.2);
    final head = base - Offset(0, size * 0.9);
    return (
      base: base,
      size: size,
      depth: (z + 1) / (1 + outline(span).dy),
      turn: turn,
      light: (lamp - head) / max(1, (lamp - head).distance),
    );
  }

  /// Il contorno del tavolo a [r], abbassato di [drop] davanti (lo spessore).
  Path oval(double r, {double drop = 0}) {
    final path = Path();
    const steps = 160;
    for (var i = 0; i <= steps; i++) {
      final unit = outline(i / steps);
      var p = project(unit, r) + Offset(0, drop * scaleAt(unit.dy));
      // Il bordo vicino si allarga verso chi guarda, fino a uscire dallo
      // schermo: ci si è seduti contro.
      final z = unit.dy * r;
      if (z > 0.6) p = Offset(center.dx + (p.dx - center.dx) * (1 + 4 * (z - 0.6) * (z - 0.6)), p.dy);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }


  factory PokerTableLayout.fit(int count, Size space, {bool own = false}) {
    final n = max(1, count);
    // La propria sedia si fa più piccola quando al tavolo si è in tanti.
    final crowd = ((n - 8) / 7).clamp(0.0, 1.0);
    final near = own
        ? (space.height * lerpDouble(0.17, 0.12, crowd)!).clamp(50.0, 120.0)
        : (space.height * 0.1).clamp(30.0, 80.0);
    final ownBox = own
        ? Rect.fromCenter(
            center: Offset(space.width / 2, space.height - near / 2),
            width: (space.width * lerpDouble(0.44, 0.34, crowd)!).clamp(110.0, 230.0),
            height: near,
          )
        : null;

    final uniform = [for (var i = 0; i < n; i++) n == 1 ? 0.0 : -1 + 2 * (i + 0.5) / n];

    PokerTableLayout? attempt(double span, double front, {bool force = false}) {
      final back = (30 / front).clamp(0.42, 0.8);
      final bottom = space.height - near * 0.55;

      // Il tavolo più grande che lascia tutti dentro lo schermo, coi posti
      // ai punti [turns] del giro: prima con un tavolo di misura uno, poi
      // lo si stira.
      List<TableSeat> placed(List<double> turns, Offset center, double rx, double ry) => [
        for (final t in turns) _seatAt(span, back, center, rx, ry, front, t),
      ];

      ({double rx, double ry, Offset center})? geometry(List<double> turns) {
        final unitSeats = placed(turns, Offset.zero, 1, 1);
        var rx = double.infinity;
        for (final seat in unitSeats) {
          final rim = _seatAt(span, back, Offset.zero, 1, 1, 0, seat.turn).base.dx;
          if (rim.abs() < 0.05) continue;
          final side = footprint(seat).width / 2 + (seat.base.dx - rim).abs();
          rx = min(rx, (space.width / 2 - side - _gap) / rim.abs());
        }
        if (rx < 20 && !force) return null;
        rx = max(rx, 20);
        var ry = double.infinity;
        for (final seat in unitSeats) {
          final above = seat.base.dy - footprint(seat).top;
          final rimY = _seatAt(span, back, Offset.zero, 0, 1, 0, seat.turn).base.dy;
          ry = min(ry, (bottom - _gap - above + seat.base.dy - rimY) / (rimRadius - rimY));
        }
        // Lungo, che si allontana sotto la lampada, ma non un corridoio.
        ry = min(ry, rx * 1.8);
        if (ry < 16 && !force) return null;
        ry = max(ry, 16);
        return (rx: rx, ry: ry, center: Offset(space.width / 2, bottom - ry * rimRadius));
      }

      var fit = geometry(uniform);
      if (fit == null) return null;
      var turns = uniform;
      // Il giro misurato in posti: ogni tratto vale quanto è lungo diviso
      // quanto spazio chiede lì un posto, nella direzione del giro. Così in
      // fondo, dove le persone sono piccole, ci si stringe. Cambiando i
      // posti cambia il tavolo: due giri bastano perché si assesti.
      for (var round = 0; round < 3 && n > 1; round++) {
        final table = fit!;
        const steps = 400;
        final room = List<double>.filled(steps + 1, 0);
        TableSeat at(double t) => _seatAt(span, back, table.center, table.rx, table.ry, front, t);
        var previous = at(-1);
        for (var i = 1; i <= steps; i++) {
          final here = at(-1 + 2 * i / steps);
          final step = here.base - previous.base;
          final length = step.distance;
          final box = footprint(here);
          final need = length == 0 ? 1.0 : (step.dx.abs() * (box.width + _gap) + step.dy.abs() * (box.height + _gap)) / length * 1.03;
          room[i] = room[i - 1] + length / need;
          previous = here;
        }
        final total = room[steps];
        if (total < (n - 1) * 0.98 && !force) return null;
        final next = <double>[];
        var k = 0;
        for (var i = 0; i < n; i++) {
          final target = i * total / (n - 1);
          while (k < steps - 1 && room[k + 1] < target) {
            k++;
          }
          final span = room[k + 1] - room[k];
          final f = span == 0 ? 0.0 : ((target - room[k]) / span).clamp(0.0, 1.0);
          next.add(-1 + 2 * (k + f) / steps);
        }
        turns = next;
        final again = geometry(turns);
        if (again == null) {
          if (!force) return null;
          break;
        }
        fit = again;
      }
      final (:rx, :ry, :center) = fit!;
      final seats = placed(turns, center, rx, ry);
      final layout = PokerTableLayout._(space, center, rx, ry, front, back, span, seats, ownBox, near);
      if (force) return layout;
      final boxes = [for (final seat in seats) footprint(seat)];
      final screen = (Offset.zero & space).inflate(0.5);
      for (var i = 0; i < boxes.length; i++) {
        if (!screen.contains(boxes[i].topLeft) || !screen.contains(boxes[i].bottomRight)) return null;
        if (ownBox != null && boxes[i].overlaps(ownBox.deflate(0.5))) return null;
        for (var j = i + 1; j < boxes.length; j++) {
          final overlap = boxes[i].intersect(boxes[j]);
          if (overlap.width > 0.5 && overlap.height > 0.5) return null;
        }
      }
      return layout;
    }

    // Il più grande che ci sta: si scende a passi dal più grande possibile
    // (stare dentro non migliora sempre rimpicciolendo, quindi niente
    // bisezione), poi si affina tra l'ultimo che sta e il primo che no.
    PokerTableLayout? largest(double span) {
      final top = min(maxSize, space.width * 0.34);
      const floor = 16.0;
      for (var front = top; front >= floor; front -= 3) {
        final fit = attempt(span, front);
        if (fit == null) continue;
        var best = fit;
        var low = front, high = front + 3;
        for (var i = 0; i < 5; i++) {
          final mid = (low + high) / 2;
          final better = mid <= top ? attempt(span, mid) : null;
          if (better != null) {
            best = better;
            low = mid;
          } else {
            high = mid;
          }
        }
        return best;
      }
      return null;
    }

    // Il giro corto finché le persone restano grandi; se si stringe troppo,
    // si scende lungo i lati.
    PokerTableLayout? chosen;
    for (final span in _spans) {
      final fit = largest(span);
      if (fit == null) continue;
      if (chosen == null || fit.frontSize > chosen.frontSize * 1.2) chosen = fit;
    }
    return chosen ?? attempt(_spans.last, 16, force: true)!;
  }
}

/// La sala e il tavolo: il buio intorno, il cono della lampada, l'ombra sul
/// pavimento, lo spessore del legno, il bordo imbottito, il panno con la riga
/// d'oro, il piatto di fiches e il bordo vicino, quello su cui si posano le
/// proprie mani.
class _TablePainter extends CustomPainter {
  final PokerTableLayout layout;

  _TablePainter(this.layout);

  @override
  void paint(Canvas canvas, Size size) {
    final area = Offset.zero & size;
    final rim = layout.oval(PokerTableLayout.rimRadius);
    final bounds = rim.getBounds();
    final thick = layout.frontSize * 0.22;
    final lamp = Offset(layout.center.dx, max(0.0, layout.center.dy - layout.ry * 2.2));

    // Il buio della bisca: scende dietro il tavolo e sfuma verso i bordi,
    // così la scena si posa sulla città senza una cornice.
    final room = area.inflate(24);
    canvas.saveLayer(room, Paint());
    canvas.drawRect(
      room,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0E0B09), Color(0xFF080605)],
        ).createShader(room),
    );
    // La carta da parati del retro, a righe, appena visibile.
    final stripe = Paint()..color = const Color(0xFF2A1A12).withValues(alpha: 0.35);
    final step = max(10.0, size.width / 22);
    for (var x = room.left; x < room.right; x += step) {
      canvas.drawRect(Rect.fromLTWH(x, room.top, step * 0.45, layout.center.dy - room.top), stripe);
    }
    // I bordi sfumano nella città, così la scena non ha cornice.
    canvas.drawRect(
      room,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = RadialGradient(
          center: Alignment(0, (layout.center.dy / size.height) * 2 - 1.2),
          radius: 1.15,
          colors: [Colors.black, Colors.black.withValues(alpha: 0.93), Colors.transparent],
          stops: const [0, 0.7, 1],
        ).createShader(area),
    );
    // In alto la sala si perde nel buio, senza un bordo.
    canvas.drawRect(
      room,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [Colors.transparent, Colors.black],
          stops: [0, min(0.35, 70 / size.height)],
        ).createShader(area),
    );
    canvas.restore();
    canvas.save();
    canvas.clipRect(area);
    // Il cono della lampada, dall'alto fino al panno.
    final cone = Path()
      ..moveTo(lamp.dx - layout.rx * 0.12, lamp.dy)
      ..lineTo(lamp.dx + layout.rx * 0.12, lamp.dy)
      ..lineTo(bounds.right - layout.rx * 0.08, layout.center.dy + layout.ry * 0.3)
      ..lineTo(bounds.left + layout.rx * 0.08, layout.center.dy + layout.ry * 0.3)
      ..close();
    canvas.drawPath(
      cone,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [const Color(0xFF3A2E14).withValues(alpha: 0.5), const Color(0xFF2A2210).withValues(alpha: 0.12)],
        ).createShader(cone.getBounds())
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, layout.rx * 0.08),
    );

    canvas.drawPath(
      layout.oval(PokerTableLayout.rimRadius * 1.04, drop: thick * 2),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.7)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, thick * 1.4),
    );
    // Lo spessore: il fianco del tavolo, visto solo davanti e ai lati.
    canvas.drawPath(
      layout.oval(PokerTableLayout.rimRadius, drop: thick),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2A160A), Color(0xFF3A2010), Color(0xFF120904)],
        ).createShader(bounds.inflate(thick)),
    );
    canvas.drawPath(
      rim,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [PokerFelt.wood[1], PokerFelt.wood[0], PokerFelt.wood[2]],
        ).createShader(bounds),
    );
    // Il lucido della vernice sul legno, dove batte la lampada.
    canvas.drawPath(
      layout.oval(PokerTableLayout.rimRadius * 0.95),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.0, thick * 0.12)
        ..shader = RadialGradient(
          center: Alignment(0, -0.2),
          radius: 0.7,
          colors: [const Color(0xFFE8B98A).withValues(alpha: 0.6), Colors.transparent],
        ).createShader(bounds),
    );

    final felt = layout.oval(PokerTableLayout.feltRadius);
    final feltBounds = felt.getBounds();
    canvas.drawPath(
      felt,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.15),
          radius: 0.75,
          colors: [const Color(0xFF2E7A55), PokerFelt.felt[1], PokerFelt.felt[2], const Color(0xFF061A11)],
          stops: const [0, 0.45, 0.8, 1],
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
        ..color = Colors.black.withValues(alpha: 0.55)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, thick * 0.6),
    );
    canvas.restore();
    canvas.drawPath(
      layout.oval(PokerTableLayout.lineRadius),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = AppColors.gold.withValues(alpha: 0.32),
    );
    // La lampada: un cerchio di luce calda sul panno.
    canvas.drawPath(
      felt,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          center: const Alignment(0, -0.2),
          radius: 0.55,
          colors: [const Color(0xFF6E5A20).withValues(alpha: 0.6), Colors.transparent],
        ).createShader(feltBounds),
    );
    _pot(canvas);
    canvas.restore();
    _lamp(canvas, lamp, size);
  }

  /// Il piatto: tre pile di fiches e due carte scoperte, schiacciate dalla
  /// prospettiva.
  void _pot(Canvas canvas) {
    final unit = layout.frontSize * 0.09;
    if (unit < 2.5) return;
    final middle = layout.center + Offset(0, layout.ry * 0.05);
    for (final (i, dx) in [-1.3, 0.2].indexed) {
      canvas.save();
      canvas.translate(middle.dx + dx * unit * 2.4, middle.dy - unit * 1.6);
      canvas.rotate(-0.2 + i * 0.35);
      final card = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: unit * 2.6, height: unit * 1.7), Radius.circular(unit * 0.25));
      canvas.drawRRect(card.shift(Offset(0, unit * 0.2)), Paint()..color = Colors.black.withValues(alpha: 0.4));
      canvas.drawRRect(card, Paint()..color = const Color(0xFFF1E9DA));
      canvas.drawCircle(Offset.zero, unit * 0.32, Paint()..color = i == 0 ? const Color(0xFFB3202A) : const Color(0xFF14110F));
      canvas.restore();
    }
    const piles = [
      (dx: -2.6, dy: 0.5, color: Color(0xFF9C2B34), height: 5),
      (dx: -0.6, dy: 1.1, color: Color(0xFF1A1714), height: 7),
      (dx: 1.6, dy: 0.7, color: Color(0xFFE6DCCB), height: 4),
      (dx: 3.2, dy: 1.3, color: Color(0xFF2A5C8C), height: 3),
    ];
    for (final pile in piles) {
      final base = middle + Offset(pile.dx * unit * 1.4, pile.dy * unit);
      for (var i = 0; i < pile.height; i++) {
        final chip = Rect.fromCenter(center: base - Offset(0, i * unit * 0.32), width: unit * 1.9, height: unit * 0.9);
        canvas.drawOval(chip.shift(Offset(0, unit * 0.2)), Paint()..color = Colors.black.withValues(alpha: 0.45));
        canvas.drawOval(chip, Paint()..color = pile.color);
        canvas.drawOval(
          chip.deflate(unit * 0.22),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = max(0.6, unit * 0.12)
            ..color = Colors.white.withValues(alpha: pile.color.computeLuminance() > 0.5 ? 0.0 : 0.5),
        );
      }
    }
  }

  /// La lampada appesa sopra il tavolo, se in alto c'è posto per vederla.
  void _lamp(Canvas canvas, Offset at, Size size) {
    final top = layout.seats.isEmpty ? 0.0 : layout.seats.map((s) => PokerTableLayout.footprint(s).top).reduce(min);
    final room = top - 6;
    if (room < 26) return;
    final w = min(layout.rx * 0.7, room * 2.2);
    final h = w * 0.32;
    final y = min(room - h * 0.4, max(h * 0.9, room * 0.55));
    final c = Offset(at.dx, y);
    canvas.drawLine(Offset(c.dx, -10), Offset(c.dx, c.dy - h * 0.6), Paint()
      ..color = const Color(0xFF2A2522)
      ..strokeWidth = 1.5);
    canvas.drawOval(
      Rect.fromCenter(center: c.translate(0, h * 0.42), width: w * 1.6, height: h * 1.4),
      Paint()
        ..color = const Color(0xFFFFD27A).withValues(alpha: 0.28)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, h * 0.6),
    );
    final shade = Path()
      ..moveTo(c.dx - w * 0.18, c.dy - h * 0.55)
      ..lineTo(c.dx + w * 0.18, c.dy - h * 0.55)
      ..quadraticBezierTo(c.dx + w * 0.42, c.dy - h * 0.1, c.dx + w * 0.5, c.dy + h * 0.4)
      ..lineTo(c.dx - w * 0.5, c.dy + h * 0.4)
      ..quadraticBezierTo(c.dx - w * 0.42, c.dy - h * 0.1, c.dx - w * 0.18, c.dy - h * 0.55)
      ..close();
    canvas.drawPath(
      shade,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0F2A1E), Color(0xFF1F5A3E)],
        ).createShader(shade.getBounds()),
    );
    canvas.drawOval(
      Rect.fromCenter(center: c.translate(0, h * 0.4), width: w, height: h * 0.26),
      Paint()..color = const Color(0xFFFFE6A8),
    );
    canvas.drawPath(
      Path()
        ..moveTo(c.dx - w * 0.15, c.dy - h * 0.48)
        ..quadraticBezierTo(c.dx - w * 0.36, c.dy - h * 0.1, c.dx - w * 0.43, c.dy + h * 0.3),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.0, h * 0.06)
        ..color = const Color(0xFF8FD3A8).withValues(alpha: 0.45),
    );
  }

  @override
  bool shouldRepaint(_TablePainter old) =>
      old.layout.space != layout.space || old.layout.seats.length != layout.seats.length || old.layout.own != layout.own;
}

/// Le sedie vuote, mentre tutti girano intorno al tavolo.
class _ChairsPainter extends CustomPainter {
  final PokerTableLayout layout;

  _ChairsPainter(this.layout);

  @override
  void paint(Canvas canvas, Size size) {
    for (final seat in layout.seats) {
      LookPainter.chair(canvas, base: seat.base, s: seat.size);
    }
  }

  @override
  bool shouldRepaint(_ChairsPainter old) => old.layout != layout;
}

/// Il fumo che resta sospeso sotto la lampada e si muove piano.
class _HazePainter extends CustomPainter {
  final PokerTableLayout layout;
  final ValueListenable<double> time;

  _HazePainter(this.layout, this.time) : super(repaint: time);

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    for (var i = 0; i < 5; i++) {
      final drift = sin(t * 0.08 + i * 1.7);
      final c = layout.center + Offset(layout.rx * (drift * 0.5 + (i - 2) * 0.22), -layout.ry * (0.55 + 0.25 * sin(i * 2.3 + t * 0.05)));
      final r = layout.rx * (0.32 + 0.08 * (i % 3));
      canvas.drawOval(
        Rect.fromCenter(center: c, width: r * 2.4, height: r * 0.7),
        Paint()
          ..color = const Color(0xFFCFC6B8).withValues(alpha: 0.05 + 0.02 * sin(t * 0.3 + i))
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.4),
      );
    }
  }

  @override
  bool shouldRepaint(_HazePainter old) => old.layout != layout;
}

/// Il riflettore su chi è stato scelto: un fascio dall'alto e una pozza di
/// luce d'oro sul panno davanti al suo posto.
class _SpotlightPainter extends CustomPainter {
  final Offset at;
  final double size;
  final PokerTableLayout layout;

  _SpotlightPainter(this.at, this.size, this.layout);

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final pool = Offset.lerp(at, layout.center, 0.12)! + Offset(0, size * 0.12);
    final reach = size * 0.95;
    final top = min(-20.0, at.dy - size * 4);
    final beam = Path()
      ..moveTo(at.dx - size * 0.25, top)
      ..lineTo(at.dx + size * 0.25, top)
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
          colors: [Colors.transparent, const Color(0xFF6A5622).withValues(alpha: 0.55)],
        ).createShader(Rect.fromLTRB(pool.dx - reach, top, pool.dx + reach, pool.dy))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, size * 0.12),
    );
    final oval = Rect.fromCenter(center: pool, width: reach * 2.3, height: reach * 0.8);
    canvas.drawOval(
      oval,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          colors: [const Color(0xFF8A7230).withValues(alpha: 0.9), Colors.transparent],
        ).createShader(oval),
    );
    canvas.drawOval(
      oval.deflate(reach * 0.12),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.5, size * 0.035)
        ..color = AppColors.gold.withValues(alpha: 0.85),
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) => old.at != at || old.size != size;
}

/// Se su un posto c'è da scegliere: niente (il tavolo si guarda e basta),
/// sì, oppure no perché stavolta tocca ad altri.
enum _Choice { none, open, closed }

const _mafiaRed = Color(0xFFE5606A);
const _cleanGreen = Color(0xFF6FBF9A);
const _ink = Color(0xFFE2323D);

/// Chi si può scegliere sta in piena luce, anche da morto. Gli altri
/// affondano nel buio, i morti più dei vivi.
double _opacityOf(_Choice choice, {required bool alive, required bool othersChosen}) => switch (choice) {
  _Choice.open => othersChosen ? 0.8 : 1,
  _Choice.closed => alive ? 0.5 : 0.4,
  _Choice.none => alive ? 1 : 0.55,
};

/// Un giocatore al suo posto: la sedia, la persona col suo look che respira
/// e si guarda intorno, i segni di ruolo dove chi guarda ha diritto di
/// saperli, e la targhetta col nome. Chi viene scelto si alza. Chi non c'è
/// più lascia la sedia vuota, col pugnale nello schienale e un garofano.
class _Seat extends StatelessWidget {
  final Player player;
  final AvatarLook look;
  final TableSeat seat;
  final Offset origin;

  /// Quanto è in piedi mentre cambia sedia o arriva.
  final double walking;

  /// Sta cambiando sedia: la sua è rimasta al posto.
  final bool moving;
  final ValueListenable<double> time;
  final bool alive;
  final Knowledge knowledge;
  final bool selected;
  final bool othersChosen;
  final bool silenced;
  final String? stamp;
  final _Choice choice;
  final VoidCallback? onTap;

  const _Seat({
    required this.player,
    required this.look,
    required this.seat,
    required this.origin,
    required this.walking,
    required this.moving,
    required this.time,
    required this.alive,
    required this.knowledge,
    required this.selected,
    required this.othersChosen,
    required this.silenced,
    required this.stamp,
    required this.choice,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    final s = seat.size;
    final base = seat.base - origin;
    final plaque = PokerTableLayout.plaqueCenter(seat) - origin;
    final plaqueW = PokerTableLayout.plaqueWidth(s), plaqueH = PokerTableLayout.plaqueHeight(s);
    final chip = max(15.0, s * 0.26);
    final role = knowledge.role;
    final badge = _badge(t, s);
    final stampWidth = max(s * 1.15, 64.0);
    final phase = stableHash(player.name) & 0x3FF;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: _opacityOf(choice, alive: alive, othersChosen: othersChosen),
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: selected ? 1 : 0),
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutBack,
        builder: (context, stand, _) {
          final rise = max(stand, walking);
          // Chi si alza porta su anche quello che ha sul petto.
          final up = Offset(0, -s * 0.42 * stand);
          return Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(s * 0.2),
              onTap: pressed(onTap, Press.card),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: SeatedCharacterPainter(
                        look: alive ? look : null,
                        empty: !alive,
                        base: base,
                        size: s,
                        time: time,
                        phase: phase,
                        rise: rise,
                        lit: selected,
                        light: seat.light,
                        chair: walking == 0 || !moving,
                      ),
                    ),
                  ),
                  if (!alive)
                    Positioned(
                      left: base.dx - s * 0.3,
                      width: s * 0.6,
                      top: base.dy - s * 0.82,
                      height: s * 0.6,
                      child: Center(child: _dagger(s)),
                    ),
                  if (silenced && alive)
                    Positioned(
                      left: base.dx + s * 0.2,
                      top: base.dy - s * 1.15 + up.dy,
                      child: _chip(chip, AppColors.gold, Icons.voice_over_off, ink: AppColors.background),
                    ),
                  if (badge != null)
                    Positioned(
                      left: base.dx - plaqueW / 2,
                      width: plaqueW,
                      top: base.dy - s * 0.42 + up.dy,
                      height: max(11.0, s * 0.15),
                      child: Center(child: badge),
                    ),
                  Positioned(
                    left: plaque.dx - plaqueW / 2,
                    top: plaque.dy - plaqueH / 2,
                    width: plaqueW,
                    height: plaqueH,
                    child: _Plaque(name: player.name, alive: alive, selected: selected),
                  ),
                  if (role != null)
                    Positioned(
                      left: plaque.dx - plaqueW / 2 - chip * 0.55,
                      top: plaque.dy - chip / 2,
                      child: _chip(chip, role.color, role.icon),
                    ),
                  if (selected && stamp == null)
                    Positioned(
                      left: plaque.dx + plaqueW / 2 - chip * 0.45,
                      top: plaque.dy - chip / 2,
                      child: _chip(chip, AppColors.gold, Icons.check, ink: AppColors.background),
                    ),
                  // Il timbro sul petto di chi si è alzato: la faccia resta scoperta.
                  if (selected && stamp != null)
                    Positioned(
                      left: base.dx - stampWidth / 2,
                      width: stampWidth,
                      top: base.dy - s * 0.4 + up.dy * 0.7 - stampWidth * 0.2,
                      height: stampWidth * 0.4,
                      child: Opacity(opacity: stand.clamp(0.0, 1.0), child: _Stamp(text: stamp!, width: stampWidth)),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget? _badge(AppStrings t, double d) {
    if (knowledge.role != null) return null;
    return switch (knowledge.team) {
      Team.mafia => _label(t.familyBadge, _mafiaRed, d),
      Team.citizens => _label(t.innocentBadge, _cleanGreen, d),
      null => null,
    };
  }
}

/// La propria sedia vista da seduti: due maniche che entrano dal basso, le
/// mani posate sul bordo, le carte coperte, la targhetta "tu".
class _OwnSeat extends StatelessWidget {
  final Player player;
  final AvatarLook look;
  final Knowledge knowledge;
  final bool alive;
  final bool selected;
  final bool silenced;
  final _Choice choice;
  final VoidCallback? onTap;

  const _OwnSeat({
    required this.player,
    required this.look,
    required this.knowledge,
    required this.alive,
    required this.selected,
    required this.silenced,
    required this.choice,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth, h = box.maxHeight;
        final plaqueH = (h * 0.24).clamp(15.0, 24.0);
        final plaqueW = min(w * 0.62, 150.0);
        final chip = (h * 0.3).clamp(16.0, 30.0);
        final role = knowledge.role;
        return AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: _opacityOf(choice, alive: alive, othersChosen: false),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: pressed(onTap, Press.card),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(child: CustomPaint(painter: _OwnHandsPainter(look, lit: selected))),
                  Positioned(
                    left: (w - plaqueW) / 2,
                    width: plaqueW,
                    top: h * 0.08,
                    height: plaqueH,
                    child: _Plaque(name: player.name, alive: alive, selected: selected, prefix: t.youBadge),
                  ),
                  if (role != null)
                    Positioned(
                      left: (w - plaqueW) / 2 - chip * 0.8,
                      top: h * 0.08 + plaqueH / 2 - chip / 2,
                      child: _chip(chip, role.color, role.icon),
                    ),
                  if (silenced)
                    Positioned(
                      left: (w + plaqueW) / 2 - chip * 0.2,
                      top: h * 0.08 + plaqueH / 2 - chip / 2,
                      child: _chip(chip, AppColors.gold, Icons.voice_over_off, ink: AppColors.background),
                    ),
                  if (selected)
                    Positioned(
                      left: (w + plaqueW) / 2 - chip * 0.2,
                      top: h * 0.08 + plaqueH / 2 - chip / 2,
                      child: _chip(chip, AppColors.gold, Icons.check, ink: AppColors.background),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _OwnHandsPainter extends CustomPainter {
  final AvatarLook look;
  final bool lit;

  _OwnHandsPainter(this.look, {required this.lit});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final coat = look.outfit.coat;
    final skin = look.base.skin;
    if (lit) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(w / 2, h * 0.62), width: w * 1.1, height: h * 0.9),
        Paint()
          ..color = AppColors.gold.withValues(alpha: 0.35)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, h * 0.2),
      );
    }
    // Le proprie carte, coperte, un angolo alzato.
    for (final (i, dx) in [-0.08, 0.05].indexed) {
      canvas.save();
      canvas.translate(w * (0.5 + dx), h * 0.6);
      canvas.rotate(-0.12 + i * 0.22);
      final card = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: h * 0.36, height: h * 0.5), Radius.circular(h * 0.04));
      canvas.drawRRect(card.shift(Offset(0, h * 0.03)), Paint()..color = Colors.black.withValues(alpha: 0.5));
      canvas.drawRRect(card, Paint()..color = LookPainter.paper);
      canvas.drawRRect(card.deflate(h * 0.025), Paint()..color = const Color(0xFF8E1D28));
      canvas.restore();
    }
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (final side in [-1.0, 1.0]) {
      final elbow = Offset(w / 2 + side * w * 0.5, h * 1.3);
      final hand = Offset(w / 2 + side * w * 0.25, h * 0.6);
      final along = hand - elbow;
      final unit = along / along.distance;
      final cross = Offset(-unit.dy, unit.dx);
      final wrist = hand - unit * (h * 0.16);
      final thick = h * 0.22;
      final sleeve = Path()
        ..moveTo(elbow.dx + cross.dx * thick, elbow.dy + cross.dy * thick)
        ..lineTo(wrist.dx + cross.dx * thick * 0.7, wrist.dy + cross.dy * thick * 0.7)
        ..lineTo(wrist.dx - cross.dx * thick * 0.7, wrist.dy - cross.dy * thick * 0.7)
        ..lineTo(elbow.dx - cross.dx * thick, elbow.dy - cross.dy * thick)
        ..close();
      canvas.drawPath(sleeve.shift(Offset(-side * h * 0.015, -h * 0.02)), Paint()..color = (lit ? LookPainter.gold : LookPainter.rim).withValues(alpha: 0.6));
      canvas.drawPath(
        sleeve,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color.lerp(coat, Colors.black, 0.25)!, Color.lerp(coat, Colors.black, 0.9)!],
          ).createShader(Rect.fromPoints(wrist, elbow)),
      );
      canvas.drawLine(
        wrist + cross * (thick * 0.66),
        wrist - cross * (thick * 0.66),
        Paint()
          ..color = look.dame ? Color.lerp(coat, Colors.black, 0.3)! : Color.lerp(look.outfit.shirt, Colors.black, 0.2)!
          ..strokeWidth = h * 0.06,
      );
      // Il dorso della mano, le dita in avanti e il pollice verso le carte.
      final skinPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(skin, Colors.white, 0.12)!, Color.lerp(skin, Colors.black, 0.5)!],
        ).createShader(Rect.fromCenter(center: hand, width: h * 0.4, height: h * 0.4));
      canvas.save();
      canvas.translate(hand.dx, hand.dy);
      canvas.rotate(atan2(unit.dy, unit.dx) + pi / 2);
      final u = h * 0.1;
      canvas.drawOval(Rect.fromCenter(center: Offset(0, u * 0.6), width: u * 3.2, height: u * 1.6), Paint()..color = Colors.black.withValues(alpha: 0.4));
      for (var f = 0; f < 4; f++) {
        final x = (f - 1.5) * u * 0.62;
        final reach = u * (1.25 - (f - 1.2).abs() * 0.16);
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(x - u * 0.3, -u * 0.4 - reach, u * 0.58, reach + u * 0.5), Radius.circular(u * 0.3)),
          skinPaint,
        );
      }
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(0, u * 0.2), width: u * 2.6, height: u * 1.5), Radius.circular(u * 0.6)),
        skinPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(-side * u * 1.0 - u * 0.35 - (side > 0 ? u * 0.5 : 0), -u * 0.1, u * 1.2, u * 0.55),
          Radius.circular(u * 0.27),
        ),
        skinPaint,
      );
      // Le nocche nella luce.
      final knuckle = Paint()..color = Colors.white.withValues(alpha: 0.18);
      for (var f = 0; f < 4; f++) {
        canvas.drawCircle(Offset((f - 1.5) * u * 0.62, -u * 0.35), u * 0.13, knuckle);
      }
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_OwnHandsPainter old) => old.look != look || old.lit != lit;
}

Widget _dagger(double s) => Text(
  PlayerAvatar.dagger,
  style: TextStyle(
    fontFamily: 'Georgia',
    fontFamilyFallback: const ['serif'],
    fontSize: s * 0.5,
    height: 1,
    fontWeight: FontWeight.w700,
    color: AppColors.textSecondary,
    shadows: [Shadow(color: Colors.black, blurRadius: s * 0.08)],
  ),
);

Widget _chip(double size, Color color, IconData icon, {Color ink = AppColors.textPrimary}) {
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

Widget _label(String text, Color color, double d) {
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
        style: TextStyle(color: color, fontSize: max(8.0, d * 0.11), fontWeight: FontWeight.w800, letterSpacing: 1),
      ),
    ),
  );
}

/// La targhetta d'ottone col nome. Di chi non c'è più, sbiadita e barrata.
class _Plaque extends StatelessWidget {
  final String name;
  final bool alive;
  final bool selected;

  /// Davanti al nome, in piccolo: "tu" sulla propria sedia.
  final String? prefix;

  const _Plaque({required this.name, required this.alive, required this.selected, this.prefix});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final height = box.maxHeight;
        const ink = Color(0xFF241809);
        final style = TextStyle(
          fontFamily: 'Georgia',
          fontFamilyFallback: const ['serif'],
          color: ink,
          fontSize: height * 0.66,
          height: 1.1,
          fontWeight: FontWeight.w700,
          decoration: alive ? null : TextDecoration.lineThrough,
          decorationColor: ink,
          shadows: const [Shadow(color: Color(0x66FFFFFF), offset: Offset(0, 0.6))],
        );
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
                        : const [Color(0xFFD9BC6C), Color(0xFFA9842A), Color(0xFF6E521A)])
                  : const [Color(0xFF9A948C), Color(0xFF6E6963), Color(0xFF4A4642)],
              stops: const [0, 0.55, 1],
            ),
            border: Border.all(color: const Color(0xFF2A1D0C), width: 0.8),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.7), blurRadius: 3, offset: const Offset(0, 1.5))],
          ),
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: prefix == null
                ? Text(name, maxLines: 1, style: style)
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(prefix!, style: style.copyWith(fontSize: height * 0.5, letterSpacing: 1.2, decoration: TextDecoration.none)),
                      Text('  ', style: style),
                      Text(name, maxLines: 1, style: style),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

/// Il timbro rosso sul petto dell'imputato, storto come vuole la mano.
class _Stamp extends StatelessWidget {
  final String text;
  final double width;

  const _Stamp({required this.text, required this.width});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Transform.rotate(
        angle: -0.16,
        child: Container(
          constraints: BoxConstraints(maxWidth: width),
          padding: EdgeInsets.symmetric(horizontal: width * 0.05, vertical: width * 0.025),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            border: Border.all(color: _ink, width: max(1.5, width * 0.025)),
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
                color: _ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
