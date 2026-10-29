part of 'season.dart';

// I pennelli comuni a tutte le feste: la luce dei mattoni, la neve posata,
// le lucine, il festone, il fiocco, le insegne di tubi, la nebbia, il freddo.

// ---------------------------------------------------------------- la luce

typedef _Rgb = (double, double, double);

double _span(double t, double from, double to) => ((t - from) / (to - from)).clamp(0.0, 1.0);

/// La luce che arriva in [p]: la notte più tutte le [lights].
_Rgb _light(Offset p, List<StreetLight> lights) {
  var r = StreetWall.night.$1, g = StreetWall.night.$2, b = StreetWall.night.$3;
  for (final light in lights) {
    final k = light.at(p);
    if (k <= 0) continue;
    r += light.color.$1 * k;
    g += light.color.$2 * k;
    b += light.color.$3 * k;
  }
  return (r, g, b);
}

/// Una superficie di colore [albedo] in [p], sotto la stessa luce dei
/// mattoni; [glow] è quanto ne rimanda da sé (la neve, sotto la luna).
Color _lit(_Rgb albedo, Offset p, List<StreetLight> lights, {double gain = 1, _Rgb glow = (0, 0, 0)}) {
  final (r, g, b) = _light(p, lights);
  int c(double a, double l, double e) => (255 * (a * l * gain + e)).round().clamp(0, 255);
  return Color.fromARGB(255, c(albedo.$1, r, glow.$1), c(albedo.$2, g, glow.$2), c(albedo.$3, b, glow.$3));
}

/// Quanto la vignettatura dell'obiettivo scurisce [p] (da 0 a 0,6), come
/// [StreetWall.vignette]: chi disegna sopra di lei si scurisce da sé.
double _vignetteAt(Offset p, Size size) {
  final center = Offset(size.width / 2, size.height * 0.425);
  final t = (p - center).distance / (1.15 * size.shortestSide);
  return (0.6 * _span(t, 0.55, 1.0)).clamp(0.0, 0.6);
}

Color _dim(Color c, double dark) => Color.lerp(c, Colors.black, dark)!;

// -------------------------------------------------------------- i pezzi

abstract final class _C {
  static const ink = Color(0xFF07070A);
  static const wire = Color(0xFF15120F);
  static const red = Color(0xFFB3121C);
  static const redDark = Color(0xFF5E0910);
  static const redLight = Color(0xFFE8464E);
  static const gold = Color(0xFFD9B45A);
  static const goldDark = Color(0xFF7A5A1E);
  static const warm = Color(0xFFFFD58A);
  static const holly = Color(0xFF1F5A33);
  static const hollyLight = Color(0xFF4A9A5C);
  static const hollyDark = Color(0xFF0B2414);
  static const berry = Color(0xFFD0142C);
}

/// La neve posata su uno spigolo, da [a] a [b] (da sinistra a destra):
/// gobbe morbide sopra, qualche goccia che pende sotto.
void _cap(Canvas canvas, Offset a, Offset b, double depth, Color top, Color under, {int seed = 1, double drip = 0.35}) {
  final d = b - a;
  final len = d.distance;
  if (len < 2 || depth < 0.4) return;
  final rng = Random(seed);
  final o = depth * 0.55;
  final base = depth * 0.30;
  final path = Path()..moveTo(-o, base);
  path.quadraticBezierTo(-o * 1.2, -depth * 0.45, 0, -depth * 0.80);
  final n = max(1, (len / (depth * 3.0)).round());
  final step = len / n;
  for (var i = 0; i < n; i++) {
    final x = step * i;
    final h = depth * (0.95 + rng.nextDouble() * 0.40);
    path.quadraticBezierTo(x + step * 0.5, -h * 1.22, x + step, -depth * (0.72 + rng.nextDouble() * 0.16));
  }
  path.quadraticBezierTo(len + o * 1.2, -depth * 0.45, len + o, base);
  var x = len + o;
  final drips = (len / (depth * 6)).floor();
  final spots = [for (var i = 0; i < drips; i++) len * (0.08 + 0.84 * rng.nextDouble())]..sort((p, q) => q.compareTo(p));
  for (final s in spots) {
    final w = depth * (0.35 + 0.3 * rng.nextDouble());
    if (s + w > x) continue;
    path.lineTo(s + w, base);
    path.quadraticBezierTo(s, base + depth * (drip + rng.nextDouble() * drip) * 2, s - w, base);
    x = s - w;
  }
  path
    ..lineTo(-o, base)
    ..close();
  canvas.save();
  canvas.translate(a.dx, a.dy);
  canvas.rotate(atan2(d.dy, d.dx));
  final bounds = Rect.fromLTRB(-o, -depth * 1.4, len + o, base + depth * drip * 4);
  canvas.drawPath(
    path,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [top, Color.lerp(top, under, 0.3)!, under],
        stops: const [0, 0.5, 1],
      ).createShader(bounds),
  );
  canvas.restore();
}

/// La neve lungo una curva (un cappello, una lettera tonda, il braccio del
/// lampione): un filo bianco grosso, più chiaro sopra.
void _rim(Canvas canvas, Path path, double width, Color top, Color under) {
  Paint stroke(double w, Color c) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = c;
  canvas.drawPath(path, stroke(width, under));
  canvas.drawPath(path.shift(Offset(0, -width * 0.22)), stroke(width * 0.62, top));
}

/// Una lampadina appesa al filo in [socket], rivolta verso [down].
void _bulb(Canvas canvas, Offset socket, Offset down, Color color, double s, {double glow = 1}) {
  final c = socket + down * s * 1.5;
  final halo = Rect.fromCircle(center: c, radius: s * 5.5);
  canvas.drawOval(
    halo,
    Paint()
      ..shader = RadialGradient(
        colors: [color.withValues(alpha: 0.55 * glow), color.withValues(alpha: 0.16 * glow), color.withValues(alpha: 0)],
        stops: const [0, 0.35, 1],
      ).createShader(halo),
  );
  canvas.save();
  canvas.translate(socket.dx, socket.dy);
  canvas.rotate(atan2(down.dy, down.dx) - pi / 2);
  canvas.drawRect(Rect.fromLTWH(-s * 0.42, -s * 0.15, s * 0.84, s * 0.72), Paint()..color = _C.wire);
  final glass = Rect.fromCenter(center: Offset(0, s * 1.45), width: s * 1.25, height: s * 1.85);
  canvas.drawOval(
    glass,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -0.2),
        colors: [Color.lerp(color, Colors.white, 0.85)!, Color.lerp(color, Colors.white, 0.2)!, color],
        stops: const [0, 0.45, 1],
      ).createShader(glass),
  );
  canvas.drawOval(
    Rect.fromCenter(center: Offset(-s * 0.18, s * 1.15), width: s * 0.30, height: s * 0.55),
    Paint()..color = Colors.white.withValues(alpha: 0.7),
  );
  canvas.restore();
}

/// Il filo delle lucine, a festoni tra i [hooks]: [sag] è quanto pende.
Path _swags(List<Offset> hooks, double sag) {
  final path = Path()..moveTo(hooks.first.dx, hooks.first.dy);
  for (var i = 1; i < hooks.length; i++) {
    final a = hooks[i - 1], b = hooks[i];
    final mid = Offset.lerp(a, b, 0.5)!;
    path.quadraticBezierTo(mid.dx, mid.dy + sag * 2, b.dx, b.dy);
  }
  return path;
}

/// Dove stanno le lampadine lungo [path], una ogni [gap]: il portalampade e
/// il verso in cui pende (sempre in giù).
List<(Offset, Offset)> _along(Path path, double gap, {double from = 0.5}) {
  final out = <(Offset, Offset)>[];
  for (final m in path.computeMetrics()) {
    for (var d = gap * from; d < m.length; d += gap) {
      final t = m.getTangentForOffset(d)!;
      var n = Offset(-t.vector.dy, t.vector.dx);
      if (n.dy < 0) n = -n;
      // Pendono quasi dritte, non proprio di traverso al filo.
      final down = Offset(n.dx * 0.45, 1);
      out.add((t.position, down / down.distance));
    }
  }
  return out;
}

/// Il festone d'abete lungo [path]: un'anima scura e tanti aghi, accesi
/// dalla stessa luce dei mattoni.
void _garland(Canvas canvas, Path path, double thick, List<StreetLight> lights, {int seed = 3, double gain = 1}) {
  final rng = Random(seed);
  const greens = [(0.05, 0.15, 0.08), (0.07, 0.22, 0.12), (0.10, 0.31, 0.17), (0.17, 0.42, 0.23)];
  Color tone(_Rgb a, Offset p) => _lit(a, p, lights, gain: 2.6 * gain, glow: (0.012, 0.04, 0.025));
  final needle = Paint()
    ..strokeWidth = max(0.8, thick * 0.10)
    ..strokeCap = StrokeCap.round;
  for (final m in path.computeMetrics()) {
    canvas.drawPath(
      m.extractPath(0, m.length),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = thick * 0.72
        ..strokeCap = StrokeCap.round
        ..color = tone((0.025, 0.07, 0.04), m.getTangentForOffset(m.length / 2)!.position),
    );
    final step = thick * 0.30;
    for (var layer = 0; layer < greens.length; layer++) {
      for (var d = rng.nextDouble() * step; d < m.length; d += step) {
        final t = m.getTangentForOffset(d)!;
        final p = t.position;
        needle.color = tone(greens[layer], p);
        final count = layer == greens.length - 1 ? 2 : 3;
        for (var k = 0; k < count; k++) {
          final a = rng.nextDouble() * 2 * pi;
          final out = Offset(cos(a), sin(a));
          // Gli ultimi aghi, i più chiari, stanno sopra: lì batte la luce.
          final lift = layer == greens.length - 1 ? Offset(0, -thick * 0.12) : Offset.zero;
          final from = p + out * thick * (0.04 + 0.14 * rng.nextDouble()) + lift;
          final lean = out * 0.75 + t.vector * (rng.nextBool() ? 0.5 : -0.5);
          final len = thick * (0.30 + 0.28 * rng.nextDouble()) * (1 - layer * 0.10);
          canvas.drawLine(from, from + lean / lean.distance * len, needle);
        }
      }
    }
  }
}

/// Una pallina dell'albero: il gancio d'oro, la sfera lucida.
void _bauble(Canvas canvas, Offset hang, double r, Color color, {double dark = 0}) {
  final c = hang + Offset(0, r * 1.15);
  canvas.drawRect(Rect.fromCenter(center: hang + Offset(0, r * 0.12), width: r * 0.6, height: r * 0.34), Paint()..color = _dim(_C.gold, dark));
  final ball = Rect.fromCircle(center: c, radius: r);
  canvas.drawOval(
    ball,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.4),
        radius: 0.9,
        colors: [_dim(Color.lerp(color, Colors.white, 0.55)!, dark), _dim(color, dark), _dim(Color.lerp(color, Colors.black, 0.6)!, dark)],
        stops: const [0, 0.45, 1],
      ).createShader(ball),
  );
  canvas.drawOval(
    ball,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(0.6, r * 0.10)
      ..color = _C.ink.withValues(alpha: 0.7),
  );
  canvas.drawCircle(c + Offset(-r * 0.35, -r * 0.38), r * 0.18, Paint()..color = Colors.white.withValues(alpha: 0.85 * (1 - dark)));
}

/// Il fiocco: due asole, il nodo, le code tagliate a coda di rondine.
void _bow(Canvas canvas, Offset c, double s, {Color red = _C.red, Color dark = _C.redDark, Color light = _C.redLight, double tails = 1, double dim = 0}) {
  red = _dim(red, dim);
  dark = _dim(dark, dim);
  light = _dim(light, dim);
  final ink = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = max(0.7, s * 0.06)
    ..strokeJoin = StrokeJoin.round
    ..color = const Color(0xFF1A0507);
  if (tails > 0) {
    for (final side in [-1.0, 1.0]) {
      final tail = Path()
        ..moveTo(c.dx + side * s * 0.06, c.dy + s * 0.08)
        ..quadraticBezierTo(c.dx + side * s * 0.28, c.dy + s * 0.55 * tails, c.dx + side * s * 0.44, c.dy + s * 1.05 * tails)
        ..lineTo(c.dx + side * s * 0.29, c.dy + s * 0.90 * tails)
        ..lineTo(c.dx + side * s * 0.15, c.dy + s * 1.08 * tails)
        ..quadraticBezierTo(c.dx + side * s * 0.10, c.dy + s * 0.55 * tails, c.dx - side * s * 0.08, c.dy + s * 0.14)
        ..close();
      canvas.drawPath(tail, Paint()..color = Color.lerp(red, dark, 0.35)!);
      canvas.drawPath(tail, ink);
    }
  }
  for (final side in [-1.0, 1.0]) {
    final loop = Path()
      ..moveTo(c.dx, c.dy)
      ..cubicTo(c.dx + side * s * 0.30, c.dy - s * 0.62, c.dx + side * s * 0.98, c.dy - s * 0.52, c.dx + side * s * 0.90, c.dy - s * 0.02)
      ..cubicTo(c.dx + side * s * 0.86, c.dy + s * 0.32, c.dx + side * s * 0.40, c.dy + s * 0.26, c.dx, c.dy)
      ..close();
    canvas.drawPath(
      loop,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [light, red, dark],
          stops: const [0, 0.45, 1],
        ).createShader(Rect.fromLTRB(c.dx - s, c.dy - s * 0.5, c.dx + s, c.dy + s * 0.3)),
    );
    // La piega dentro l'asola.
    canvas.drawPath(
      Path()
        ..moveTo(c.dx + side * s * 0.16, c.dy - s * 0.05)
        ..quadraticBezierTo(c.dx + side * s * 0.50, c.dy - s * 0.22, c.dx + side * s * 0.70, c.dy - s * 0.04),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(0.6, s * 0.06)
        ..color = dark.withValues(alpha: 0.8),
    );
    canvas.drawPath(loop, ink);
  }
  final knot = RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: s * 0.30, height: s * 0.34), Radius.circular(s * 0.08));
  canvas.drawRRect(knot, Paint()..color = red);
  canvas.drawRRect(
    RRect.fromRectAndRadius(Rect.fromCenter(center: c - Offset(0, s * 0.07), width: s * 0.18, height: s * 0.08), Radius.circular(s * 0.04)),
    Paint()..color = light.withValues(alpha: 0.8),
  );
  canvas.drawRRect(knot, ink);
}

// ------------------------------------------------------------- le insegne

/// Un'insegna di Natale nello stesso alfabeto di tubi delle insegne della
/// strada, dentro [box]; a più righe se serve.
class _NeonSign {
  final Rect box;
  final List<String> lines;
  final double slant;
  final bool swash;

  late final double cap;
  late final List<double> widths;
  late final Rect bounds;

  static const _lead = 1.42;

  _NeonSign(this.box, this.lines, {this.slant = 0, this.swash = false, double maxCap = double.infinity}) {
    widths = [for (final line in lines) _width(line)];
    final wide = widths.reduce(max);
    final tall = 1 + _lead * (lines.length - 1) + (swash ? 0.3 : 0);
    cap = min(min(box.width / wide, box.height / tall), maxCap);
    bounds = Rect.fromCenter(center: box.center, width: wide * cap, height: tall * cap);
  }

  double _width(String line) {
    final letters = line.characters.toList();
    var w = 0.0;
    for (final ch in letters) {
      w += StreetNeon.widthOf(ch);
    }
    return w + StreetNeon.gap * (letters.length - 1) + slant;
  }

  Offset origin(int line) => Offset(bounds.center.dx - widths[line] * cap / 2, bounds.top + line * _lead * cap);

  StreetLight light(Color color, Size size, {double gain = 1.15, double reach = 1.3}) => StreetSignLight(
    band: bounds.deflate(cap * 0.15),
    reach: cap * reach,
    wash: 0.32,
    spread: size.width * 0.32,
    color: StreetLight.tint(color, gain),
  );

  /// I tubi; [flicker] è la lettera che sfarfalla (riga, posto), accesa
  /// appena ([dim]).
  void paint(Canvas canvas, Color color, {(int, int)? flicker, double dim = 0.22}) {
    final glass = Color.lerp(const Color(0xFF15151C), color, 0.22)!;
    final hot = Color.lerp(color, Colors.white, 0.25)!;
    final core = Color.lerp(color, Colors.white, 0.82)!;
    final halo = bounds.inflate(cap * 1.1);
    canvas.drawOval(
      halo,
      Paint()
        ..shader = RadialGradient(
          colors: [color.withValues(alpha: 0.26), color.withValues(alpha: 0)],
        ).createShader(halo),
    );
    final iron = Paint()..color = const Color(0xFF08080B);
    final tube = max(1.4, cap * 0.085);
    Paint stroke(double w, Color c) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = c;
    for (var i = 0; i < lines.length; i++) {
      final o = origin(i);
      final width = widths[i] * cap;
      for (final y in [o.dy + cap * 0.28, o.dy + cap * 0.78]) {
        canvas.drawRect(Rect.fromLTRB(o.dx - cap * 0.12, y - cap * 0.018, o.dx + width + cap * 0.06, y + cap * 0.018), iron);
      }
      for (final x in [o.dx - cap * 0.12, o.dx + width + cap * 0.06]) {
        canvas.drawCircle(Offset(x, o.dy + cap * 0.28), cap * 0.04, iron);
        canvas.drawCircle(Offset(x, o.dy + cap * 0.78), cap * 0.04, iron);
      }
      canvas.save();
      canvas.translate(0, o.dy);
      canvas.transform(Float64List.fromList([1, 0, 0, 0, -slant, 1, 0, 0, 0, 0, 1, 0, slant * cap, 0, 0, 1]));
      var x = o.dx;
      final letters = lines[i].characters.toList();
      for (var j = 0; j < letters.length; j++) {
        final ch = letters[j];
        final path = StreetNeon.letter(ch, cap).shift(Offset(x, 0));
        x += (StreetNeon.widthOf(ch) + StreetNeon.gap) * cap;
        final p = flicker == (i, j) ? dim : 1.0;
        canvas.drawPath(path, stroke(tube * 1.5, Colors.black.withValues(alpha: 0.5)));
        canvas.drawPath(path, stroke(tube, glass));
        if (p < 0.02) continue;
        canvas.drawPath(
          path,
          stroke(tube * 3.2, color.withValues(alpha: 0.6 * p))..maskFilter = MaskFilter.blur(BlurStyle.normal, cap * 0.12),
        );
        canvas.drawPath(path, stroke(tube, Color.lerp(glass, hot, p)!));
        canvas.drawPath(path, stroke(tube * 0.4, core.withValues(alpha: min(1, p * 1.1))));
      }
      if (swash) {
        final tail = Path()
          ..moveTo(o.dx - cap * 0.05, cap * 1.16)
          ..quadraticBezierTo(o.dx + width * 0.5, cap * 1.30, o.dx + width - cap * 0.1, cap * 1.08);
        canvas.drawPath(tail, stroke(tube * 1.5, Colors.black.withValues(alpha: 0.5)));
        canvas.drawPath(
          tail,
          stroke(tube * 3.2, color.withValues(alpha: 0.6))..maskFilter = MaskFilter.blur(BlurStyle.normal, cap * 0.12),
        );
        canvas.drawPath(tail, stroke(tube, hot));
        canvas.drawPath(tail, stroke(tube * 0.4, core));
      }
      canvas.restore();
    }
  }
}

double _hash(int row, int col, int salt) {
  var h = (row * 73856093) ^ (col * 19349663) ^ (salt * 83492791);
  h = (h ^ (h >> 13)) & 0x7fffffff;
  h = (h * 1274126177) & 0x7fffffff;
  h ^= h >> 16;
  return (h & 0xffff) / 0x10000;
}

/// La nebbiolina fredda che sta bassa sulla strada.
void _fog(Canvas canvas, Size size, double ground, double curb, {double strength = 1, Color color = const Color(0xFFB8C8E8)}) {
  final band = Rect.fromLTRB(0, ground - (curb - ground) * 2.2, size.width, size.height);
  canvas.drawRect(
    band,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0), color.withValues(alpha: 0.10 * strength), color.withValues(alpha: 0.05 * strength), color.withValues(alpha: 0)],
        stops: const [0, 0.35, 0.7, 1],
      ).createShader(band),
  );
}

/// Il freddo di C: tutto un poco più blu, come sotto la luna.
///
/// Un velo blu scuro steso sopra (non un filtro sullo sfondo: costa poco e
/// si tiene in un'immagine), più fitto in alto, dove arriva la luna.
void _cold(Canvas canvas, Size size, {double strength = 1}) {
  final all = Offset.zero & size;
  canvas.drawRect(
    all,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF0A1636).withValues(alpha: 0.34 * strength),
          const Color(0xFF0C1A40).withValues(alpha: 0.16 * strength),
          const Color(0xFF081230).withValues(alpha: 0.26 * strength),
        ],
        stops: const [0, 0.55, 1],
      ).createShader(all),
  );
}

