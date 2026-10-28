import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../widgets/baked.dart';
import '../widgets/home_neon_sign.dart';
import 'street_route.dart';
import 'street_stage.dart';

/// Le misure del muro che corre lungo tutta la strada dei menu: il vicolo di
/// casa e i locali sono pezzi dello stesso muro, con gli stessi mattoni alla
/// stessa altezza e lo stesso marciapiede. Ogni pagina ne mostra un tratto
/// largo quanto lo schermo: la pagina numero [StreetPlace.index] sta subito
/// a destra di quella prima, così quando la strada scorre i mattoni non
/// fanno salti.
@immutable
class StreetWall {
  final Size size;
  final EdgeInsets safe;

  late final double ground;
  late final double curb;

  /// L'altezza delle lettere di OBERTÀ: dà la misura ai mattoni.
  late final double cap;
  late final double course;
  late final double length;
  late final double slab;

  StreetWall(this.size, this.safe) {
    final w = size.width;
    final h = size.height;
    final usable = h - safe.top - safe.bottom;
    final street = (usable * 0.122).clamp(80.0, 112.0);
    ground = h - safe.bottom - street;
    curb = ground + street * 0.34;
    cap = min((w - 56) / HomeNeonSign.width, usable * 0.118);
    course = max(9.0, cap * 0.185);
    length = course * 2.55;
    slab = course * 5;
  }

  @override
  bool operator ==(Object other) => other is StreetWall && other.size == size && other.safe == safe;

  @override
  int get hashCode => Object.hash(size, safe);

  static const mortar = Color(0xFF07070B);

  /// La notte: un blu freddo che arriva dappertutto.
  static const night = (0.15, 0.20, 0.38);

  /// Il colore di una superficie [albedo] in [point], sotto la notte e tutte
  /// le [lights] della strada (la luce si somma canale per canale).
  static Color lit((double, double, double) albedo, Offset point, List<StreetLight> lights, {double gain = 1}) {
    var r = night.$1, g = night.$2, b = night.$3;
    for (final light in lights) {
      final k = light.at(point);
      if (k <= 0) continue;
      r += light.color.$1 * k;
      g += light.color.$2 * k;
      b += light.color.$3 * k;
    }
    int channel(double surface, double light) => (255 * surface * gain * light).round().clamp(0, 255);
    return Color.fromARGB(255, channel(albedo.$1, r), channel(albedo.$2, g), channel(albedo.$3, b));
  }

  /// La vignettatura dell'obiettivo: ferma sullo schermo, non sul muro.
  static void vignette(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -0.15),
          radius: 1.15,
          colors: [Color(0x00000000), Color(0x00000000), Color(0x99000000)],
          stops: [0, 0.55, 1],
        ).createShader(rect),
    );
  }
}

/// Una luce che cade sul muro: quanta ne arriva in un punto, di che colore
/// (già moltiplicato per la sua forza), e da dove viene (per il filo di luce
/// sul bordo dei mattoni che la guardano).
@immutable
abstract class StreetLight {
  final (double, double, double) color;

  const StreetLight(this.color);

  double at(Offset point);

  /// Il punto della sorgente più vicino a [point].
  Offset from(Offset point);

  /// La stessa luce, spostata di [dx] lungo la strada.
  StreetLight shift(double dx);

  static (double, double, double) tint(Color c, double gain) => (c.r * gain, c.g * gain, c.b * gain);
}

/// Un'insegna al neon: una striscia di tubi. Vicino tinge forte, poi la sua
/// luce si allarga sul muro sempre più debole ([wash] e [spread]), e si
/// mescola con quella delle insegne accanto.
class StreetSignLight extends StreetLight {
  final Rect band;
  final double reach;
  final double wash;
  final double spread;

  const StreetSignLight({required this.band, required this.reach, required this.wash, required this.spread, required (double, double, double) color})
      : super(color);

  @override
  double at(Offset point) {
    final dx = max(0.0, max(band.left - point.dx, point.dx - band.right));
    final dy = max(0.0, max(band.top - point.dy, point.dy - band.bottom));
    final d2 = dx * dx + dy * dy;
    return 1 / (1 + d2 / (reach * reach)) + wash / (1 + d2 / (spread * spread));
  }

  @override
  Offset from(Offset point) => Offset(point.dx.clamp(band.left, band.right), point.dy.clamp(band.top, band.bottom));

  @override
  StreetLight shift(double dx) => StreetSignLight(band: band.shift(Offset(dx, 0)), reach: reach, wash: wash, spread: spread, color: color);

  @override
  bool operator ==(Object other) =>
      other is StreetSignLight && other.band == band && other.reach == reach && other.wash == wash && other.spread == spread && other.color == color;

  @override
  int get hashCode => Object.hash(band, reach, wash, spread, color);
}

/// Il lampione: un cono che scende appena inclinato.
class StreetLampLight extends StreetLight {
  final Offset head;
  final double size;

  const StreetLampLight({required this.head, required this.size, required (double, double, double) color}) : super(color);

  @override
  double at(Offset point) {
    final v = point - head;
    if (v.dy < -size * 0.05) return 0;
    final angle = atan2(v.dx, v.dy) - 0.16;
    final cone = exp(-pow(angle / 0.62, 2).toDouble());
    final reach = v.distance / (size * 1.25);
    return cone / (1 + reach * reach);
  }

  @override
  Offset from(Offset point) => head;

  @override
  StreetLight shift(double dx) => StreetLampLight(head: head.translate(dx, 0), size: size, color: color);

  @override
  bool operator ==(Object other) => other is StreetLampLight && other.head == head && other.size == size && other.color == color;

  @override
  int get hashCode => Object.hash(head, size, color);
}

/// Dove sta una pagina lungo la strada e che luci ha: le legge la pagina
/// dopo, per avere sul suo tratto di muro la luce che arriva da qui, e
/// quella prima, per la luce che arriva da là.
@immutable
class StreetPlace {
  final int index;
  final List<StreetLight> lights;

  const StreetPlace(this.index, this.lights);
}

double _noise(int row, int col, int salt) {
  var h = (row * 73856093) ^ (col * 19349663) ^ (salt * 83492791);
  h = (h ^ (h >> 13)) & 0x7fffffff;
  h = (h * 1274126177) & 0x7fffffff;
  h ^= h >> 16;
  return (h & 0xffff) / 0x10000;
}

/// Il tratto di muro di una pagina, col marciapiede e l'asfalto: i mattoni
/// sono quelli della strada intera (lo stesso mattone ha lo stesso colore di
/// fondo su qualunque pagina lo mostri), accesi da tutte le [lights].
class StreetWallPainter extends CustomPainter {
  final StreetWall wall;
  final int index;
  final List<StreetLight> lights;

  StreetWallPainter({required this.wall, required this.index, required this.lights});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, Paint()..color = StreetWall.mortar);
    _bricks(canvas, w);
    final grime = Rect.fromLTRB(0, wall.ground - wall.cap * 0.9, w, wall.ground);
    canvas.drawRect(
      grime,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00000000), Color(0xB0000000)],
        ).createShader(grime),
    );
    _pavement(canvas, w);
    final asphalt = Rect.fromLTRB(0, wall.curb, w, h);
    canvas.drawRect(
      asphalt,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0E1016), Color(0xFF030304)],
        ).createShader(asphalt),
    );
    canvas.restore();
  }

  void _bricks(Canvas canvas, double w) {
    final course = wall.course;
    final length = wall.length;
    final origin = index * wall.size.width;
    final paint = Paint();
    for (var row = 0, y = wall.ground - course; y > -course; row++, y -= course) {
      final shift = row.isOdd ? length / 2 : 0.0;
      final first = ((origin + shift) / length).floor();
      for (var col = first, x = col * length - shift - origin; x < w; col++, x += length) {
        final tone = _noise(row, col, 1);
        final chipped = _noise(row, col, 2) < 0.04;
        final center = Offset(x + length / 2, y + course / 2);
        final albedo = (0.44 + 0.16 * tone, 0.27 + 0.07 * tone, 0.25 + 0.05 * tone);
        final brick = Rect.fromLTWH(x + 0.8, y + 0.8, length - 1.6, course - 1.6);
        paint.color = StreetWall.lit(albedo, center, lights, gain: chipped ? 0.55 : 1);
        canvas.drawRect(brick, paint);
        // Il filo di luce sui bordi che guardano ogni sorgente: sopra per
        // le insegne in alto, di lato per quelle accanto; il bordo opposto
        // resta in ombra.
        var top = 0.0, left = 0.0, right = 0.0;
        var r = 0.0, g = 0.0, b = 0.0;
        for (final light in lights) {
          final k = light.at(center);
          if (k < 0.01) continue;
          final v = light.from(center) - center;
          final d = v.distance;
          final ux = d < 1 ? 0.0 : v.dx / d;
          final uy = d < 1 ? -1.0 : v.dy / d;
          final luma = k * (light.color.$1 + light.color.$2 + light.color.$3);
          top += luma * max(0.0, -uy);
          left += luma * max(0.0, -ux);
          right += luma * max(0.0, ux);
          r += light.color.$1 * k;
          g += light.color.$2 * k;
          b += light.color.$3 * k;
        }
        Color edge(double facing) {
          final f = 1 + 1.6 * facing;
          int c(double a, double n, double l) => (255 * a * (n * 1.45 + l * f)).round().clamp(0, 255);
          return Color.fromARGB(255, c(albedo.$1, StreetWall.night.$1, r), c(albedo.$2, StreetWall.night.$2, g), c(albedo.$3, StreetWall.night.$3, b));
        }

        final sum = r + g + b;
        final norm = sum <= 0 ? 0.0 : 1 / sum;
        paint.color = edge(top * norm);
        canvas.drawRect(Rect.fromLTWH(brick.left, brick.top, brick.width, 1), paint);
        final side = (left - right) * norm;
        if (side.abs() > 0.08) {
          final lit = side > 0 ? brick.left : brick.right - 1;
          final dark = side > 0 ? brick.right - 1 : brick.left;
          paint.color = edge(side.abs());
          canvas.drawRect(Rect.fromLTWH(lit, brick.top, 1, brick.height), paint);
          paint.color = Colors.black.withValues(alpha: min(0.5, side.abs() * 0.6));
          canvas.drawRect(Rect.fromLTWH(dark, brick.top + 1, 1, brick.height - 1), paint);
        }
      }
    }
  }

  void _pavement(Canvas canvas, double w) {
    final slab = wall.slab;
    final origin = index * wall.size.width;
    final depth = wall.curb - wall.ground;
    final paint = Paint();
    final first = ((origin + slab * 0.3) / slab).floor();
    for (var n = first, x = n * slab - slab * 0.3 - origin; x < w; n++, x += slab) {
      final center = Offset(x + slab / 2, wall.ground - wall.course * 2.5);
      paint.color = StreetWall.lit((0.50, 0.50, 0.54), center, lights, gain: 0.8);
      canvas.drawRect(Rect.fromLTWH(x + 0.8, wall.ground, slab - 1.6, depth * 0.78), paint);
      paint.color = StreetWall.lit((0.50, 0.50, 0.54), center, lights, gain: 0.42);
      canvas.drawRect(Rect.fromLTWH(x + 0.8, wall.ground + depth * 0.78, slab - 1.6, depth * 0.22), paint);
    }
    canvas.drawRect(Rect.fromLTWH(0, wall.ground, w, 1.2), Paint()..color = Colors.white.withValues(alpha: 0.10));
  }

  @override
  bool shouldRepaint(StreetWallPainter old) => old.wall != wall || old.index != index || !listEquals(old.lights, lights);
}

/// La vignettatura, ferma sullo schermo mentre la strada scorre sotto.
class StreetVignettePainter extends CustomPainter {
  const StreetVignettePainter();

  @override
  void paint(Canvas canvas, Size size) => StreetWall.vignette(canvas, size);

  @override
  bool shouldRepaint(StreetVignettePainter old) => false;
}

/// Il tratto di muro di una pagina, già dipinto in immagini: una con le luci
/// fisse, e sopra, in dissolvenza, quella con le insegne che si accendono.
/// Le immagini sono lineari nella luce, quindi sfumarle una sull'altra è
/// proprio accendere l'insegna a metà.
///
/// [fixed] sono le luci sempre accese (le proprie, o quelle della pagina di
/// prima che arrivano fin qui); [own] l'insegna della pagina, accesa quanto
/// dice [power] (null: accesa e basta). Mentre si cammina verso la pagina
/// dopo, arriva anche la luce della sua insegna, quando si accende.
class StreetWallLayer extends StatelessWidget {
  final StreetWall wall;
  final int index;
  final List<StreetLight> fixed;
  final List<StreetLight> own;
  final double? power;

  const StreetWallLayer({super.key, required this.wall, required this.index, required this.fixed, this.own = const [], this.power});

  static const _dark = ValueKey('dark');
  static const _lit = ValueKey('lit');
  static const _spill = ValueKey('spill');

  Widget _layer(List<StreetLight> lights) =>
      Baked(child: CustomPaint(painter: StreetWallPainter(wall: wall, index: index, lights: lights)));

  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context);
    final all = [...fixed, ...own];
    return ValueListenableBuilder<StreetAhead?>(
      valueListenable: StreetStage.ahead,
      builder: (context, ahead, _) {
        final next = ahead != null && ahead.from == route ? ahead : null;
        Widget stack(double spill, List<StreetLight> spilled) => Stack(
          fit: StackFit.expand,
          children: [
            if (power != null) KeyedSubtree(key: _dark, child: _layer(fixed)),
            KeyedSubtree(key: _lit, child: Opacity(opacity: (power ?? 1).clamp(0.0, 1.0), child: _layer(all))),
            if (spilled.isNotEmpty)
              KeyedSubtree(key: _spill, child: Opacity(opacity: spill, child: _layer([...all, ...spilled]))),
          ],
        );
        if (next == null) return stack(0, const []);
        return AnimatedBuilder(
          animation: next.animation,
          builder: (context, _) {
            final place = StreetStage.placeOf(next.to);
            final spilled = [for (final light in place?.lights ?? const <StreetLight>[]) light.shift(wall.size.width)];
            return stack(StreetTiming.neon(next.animation.value), spilled);
          },
        );
      },
    );
  }
}
