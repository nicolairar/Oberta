part of 'season.dart';

/// Le tre prove del Natale. Per chi gioca si accende quella in
/// [SeasonLooks.picked]; le altre solo in `tool/render/season_render_test.dart`.
enum NataleLook implements SeasonLook {
  /// A, «Natale in vicolo»: la neve che cade e si posa, le lucine calde
  /// lungo il muro, la corona sulla porta, la nebbiolina del fiato.
  vicolo,

  /// B, «Cenone della Famiglia»: rosso e oro, il festone d'abete, candele e
  /// panettone sul panno, l'agrifoglio sulle targhette, un neon di auguri.
  cenone,

  /// C, «Natale di sangue»: la notte fredda e blu, un'insegna sola, BUON
  /// NATALE, con una lettera che sfarfalla; un nastrino rosso sul coltello.
  sangue;

  @override
  Season get season => Season.natale;

  @override
  String get key => 'natale.$name';
}

/// Il bianco della neve in [p]: azzurra sotto la luna, rosa sotto OBERTÀ,
/// calda sotto il lampione. [shade] la scurisce (il fianco in ombra).
Color _snowAt(Offset p, List<StreetLight> lights, NataleLook look, {double shade = 1}) {
  final moon = look == NataleLook.sangue ? (0.32, 0.40, 0.56) : (0.52, 0.54, 0.52);
  return _lit((0.92, 0.96, 0.84), p, lights, gain: shade, glow: (moon.$1 * shade, moon.$2 * shade, moon.$3 * shade));
}

/// Un rametto d'agrifoglio: [leaves] foglie spinose e tre bacche rosse.
/// [dark] lo scurisce verso la notte.
void _holly(Canvas canvas, Offset at, double s, double angle, {int leaves = 3, double dark = 0}) {
  canvas.save();
  canvas.translate(at.dx, at.dy);
  canvas.rotate(angle);
  const outline = [
    (0.10, -0.10), (0.22, -0.25), (0.34, -0.15), (0.48, -0.28), (0.60, -0.16), (0.74, -0.23), (0.86, -0.10), (1.0, 0.0),
    (0.86, 0.10), (0.74, 0.23), (0.60, 0.16), (0.48, 0.28), (0.34, 0.15), (0.22, 0.25), (0.10, 0.10),
  ];
  final directions = switch (leaves) {
    1 => const [-0.5],
    2 => const [-2.55, -0.55],
    _ => const [-2.6, -0.55, 1.15],
  };
  final ink = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = max(0.6, s * 0.05)
    ..strokeJoin = StrokeJoin.round
    ..color = const Color(0xFF06120A);
  for (final dir in directions) {
    canvas.save();
    canvas.rotate(dir);
    final leaf = Path()..moveTo(0, 0);
    for (final (x, y) in outline) {
      leaf.lineTo(x * s, y * s * 1.1);
    }
    leaf.close();
    canvas.drawPath(
      leaf,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_dim(_C.hollyLight, dark), _dim(_C.holly, dark), _dim(_C.hollyDark, dark)],
          stops: const [0, 0.5, 1],
        ).createShader(Rect.fromLTRB(0, -s * 0.3, s, s * 0.3)),
    );
    canvas.drawLine(
      Offset(s * 0.06, 0),
      Offset(s * 0.90, 0),
      Paint()
        ..strokeWidth = max(0.5, s * 0.04)
        ..color = _dim(const Color(0xFF7CC08A), dark).withValues(alpha: 0.75),
    );
    canvas.drawPath(leaf, ink);
    canvas.restore();
  }
  for (final (x, y) in const [(-0.02, -0.10), (0.14, 0.04), (-0.13, 0.08)]) {
    final c = Offset(x * s, y * s);
    final r = s * 0.15;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.4, -0.4),
          colors: [_dim(const Color(0xFFFF6A72), dark), _dim(_C.berry, dark), _dim(const Color(0xFF6A0612), dark)],
          stops: const [0, 0.5, 1],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawCircle(c, r, ink);
    canvas.drawCircle(c + Offset(-r * 0.35, -r * 0.35), r * 0.25, Paint()..color = Colors.white.withValues(alpha: 0.8 * (1 - dark)));
  }
  canvas.restore();
}

/// La corona d'abete appesa al chiodo col suo nastro, il fiocco sotto, le
/// bacche e (per il cenone) le palline d'oro.
void _wreath(Canvas canvas, Offset c, double r, List<StreetLight> lights, NataleLook look, {double squash = 1}) {
  final thick = r * 0.46;
  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.scale(squash, 1);
  canvas.translate(-c.dx, -c.dy);
  // Il nastro che sale al chiodo.
  final nail = c - Offset(0, r * 1.75);
  final ribbon = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = max(1.2, r * 0.10)
    ..color = _C.redDark;
  canvas.drawLine(nail, c - Offset(r * 0.32, r * 0.92), ribbon);
  canvas.drawLine(nail, c - Offset(-r * 0.32, r * 0.92), ribbon);
  canvas.drawCircle(nail, max(1.4, r * 0.09), Paint()..color = _C.goldDark);
  // L'ombra sul legno.
  canvas.drawCircle(
    c + Offset(r * 0.10, r * 0.16),
    r,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thick * 1.05
      ..color = Colors.black.withValues(alpha: 0.5)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.12),
  );
  _garland(canvas, Path()..addOval(Rect.fromCircle(center: c, radius: r)), thick, lights, seed: 11, gain: 0.8);
  final rng = Random(4);
  // Le bacche, a grappoli di tre.
  for (var i = 0; i < 7; i++) {
    final a = -pi / 2 + i * 2 * pi / 7 + 0.3;
    final p = c + Offset(cos(a), sin(a)) * r * (0.92 + 0.12 * rng.nextDouble());
    for (var k = 0; k < 3; k++) {
      final q = p + Offset(cos(a + k * 2.1), sin(a + k * 2.1)) * r * 0.08;
      canvas.drawCircle(q, r * 0.075, Paint()..color = _C.berry);
      canvas.drawCircle(q - Offset(r * 0.025, r * 0.025), r * 0.025, Paint()..color = Colors.white.withValues(alpha: 0.7));
    }
  }
  if (look == NataleLook.cenone) {
    for (var i = 0; i < 5; i++) {
      final a = -pi / 2 + i * 2 * pi / 5 + 0.62;
      final p = c + Offset(cos(a), sin(a)) * r;
      _bauble(canvas, p - Offset(0, r * 0.12), r * 0.13, _C.gold);
    }
  }
  _bow(canvas, c + Offset(0, r * 0.88), r * 0.55);
  canvas.restore();
}

/// I colori delle insegne di Natale: ognuna il suo, nessuna rossa (il rosso
/// è di OBERTÀ).
const _augurGreen = Color(0xFF3DF08A);
const _festeGold = Color(0xFFFFC24A);
const _iceWhite = Color(0xFFDDEBFF);

/// I colori delle lucine: calde per il vicolo, rosse, oro e verdi per il cenone.
List<Color> _bulbColors(NataleLook look) => switch (look) {
  NataleLook.cenone => const [Color(0xFFFF4A3D), Color(0xFFFFC94A), Color(0xFF52E07E), Color(0xFFFFE2A0)],
  _ => const [_C.warm],
};

// ------------------------------------------------------------- la neve

/// Un fiocco morbido, bianco: lo tinge il colore di ogni fiocco.
final ui.Image _flake = () {
  const side = 32.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  const c = Offset(side / 2, side / 2);
  canvas.drawCircle(
    c,
    side / 2,
    Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFFFFFFFF), Color(0xFFFFFFFF), Color(0x66FFFFFF), Color(0x00FFFFFF)],
        stops: [0, 0.32, 0.6, 1],
      ).createShader(Rect.fromCircle(center: c, radius: side / 2)),
  );
  return recorder.endRecording().toImageSync(side.toInt(), side.toInt());
}();

typedef _Flake = ({double x, double phase, double fall, double sway, double swayTurns, double size, double alpha});

/// La neve che cade: un pittore solo, tutti i fiocchi in un colpo
/// ([Canvas.drawRawAtlas]), ognuno del colore della luce in cui passa
/// (rosa sotto OBERTÀ, caldo nel cono del lampione, azzurro altrove).
class NataleSnow extends StatefulWidget {
  final NataleLook look;
  final List<StreetLight> lights;

  /// Sopra la vignettatura: i fiocchi agli angoli si scuriscono da soli.
  final bool vignette;

  /// All'apertura del vicolo la neve arriva col resto.
  final Animation<double>? reveal;

  const NataleSnow({super.key, required this.look, required this.lights, this.vignette = true, this.reveal});

  @override
  State<NataleSnow> createState() => _NataleSnowState();
}

class _NataleSnowState extends State<NataleSnow> with SingleTickerProviderStateMixin {
  static const _loop = Duration(seconds: 40);
  late final AnimationController _time = AnimationController(vsync: this, duration: _loop);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _time
        ..stop()
        ..value = 0.37;
    } else if (!_time.isAnimating) {
      _time.repeat();
    }
  }

  @override
  void dispose() {
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: _SnowPainter(
          time: _time,
          look: widget.look,
          lights: widget.lights,
          vignette: widget.vignette,
          reveal: widget.reveal,
        ),
      ),
    ),
  );
}

class _SnowPainter extends CustomPainter {
  final Animation<double> time;
  final NataleLook look;
  final List<StreetLight> lights;
  final bool vignette;
  final Animation<double>? reveal;

  _SnowPainter({required this.time, required this.look, required this.lights, required this.vignette, this.reveal})
    : super(repaint: Listenable.merge([time, ?reveal]));

  static final _flakes = <(NataleLook, int), List<_Flake>>{};

  /// I fiocchi di un giro, sempre gli stessi: [count] per lo schermo.
  static List<_Flake> _make(NataleLook look, int count) => _flakes[(look, count)] ??= () {
    final rng = Random(31);
    final cold = look == NataleLook.sangue;
    return [
      for (var i = 0; i < count; i++)
        () {
          // Tre piani: lontani e fitti, in mezzo, vicini e grandi (pochi).
          final depth = i % 10 == 0 ? 2 : (i % 3 == 0 ? 1 : 0);
          return (
            x: rng.nextDouble(),
            phase: rng.nextDouble(),
            fall: [3.0, 4.0, 6.0][depth] + rng.nextInt(2),
            sway: [3.0, 7.0, 13.0][depth] * (0.6 + 0.8 * rng.nextDouble()) * (cold ? 1.4 : 1),
            swayTurns: 5.0 + rng.nextInt(7),
            size: [2.8, 4.4, 7.5][depth] * (0.75 + 0.5 * rng.nextDouble()),
            alpha: [0.62, 0.88, 0.55][depth],
          );
        }(),
    ];
  }();

  /// La luce sulla neve, letta su una griglia: si calcola una volta per
  /// schermo, poi ogni fiocco la prende dalla sua cella.
  static final _grids = <(Size, NataleLook, int), List<Color>>{};
  static const _cols = 14, _rows = 28;

  List<Color> _grid(Size size) {
    if (_grids.length > 12) _grids.clear();
    return _grids[(size, look, Object.hashAll(lights))] ??= _fill(size);
  }

  List<Color> _fill(Size size) => [
    for (var r = 0; r < _rows; r++)
      for (var c = 0; c < _cols; c++)
        () {
          final p = Offset((c + 0.5) / _cols * size.width, (r + 0.5) / _rows * size.height);
          final tone = _snowAt(p, lights, look);
          return vignette ? _dim(tone, _vignetteAt(p, size)) : tone;
        }(),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final shown = reveal == null ? 1.0 : Curves.easeInOut.transform(_span(reveal!.value * 3.0, 0.4, 1.1));
    if (shown <= 0) return;
    final area = size.width * size.height;
    final scale = (size.shortestSide / 393).clamp(1.0, 2.2);
    final base = look == NataleLook.sangue ? 240 : (look == NataleLook.cenone ? 150 : 210);
    final count = (base * (area / (393 * 852)).clamp(1.0, 3.2)).round();
    final flakes = _make(look, count);
    final grid = _grid(size);
    final wind = look == NataleLook.sangue ? 0.16 : 0.06;
    final t = time.value;
    final transforms = Float32List(flakes.length * 4);
    final rects = Float32List(flakes.length * 4);
    final colors = Int32List(flakes.length);
    final tall = size.height * 1.12;
    final wide = size.width * 1.2;
    for (var i = 0; i < flakes.length; i++) {
      final f = flakes[i];
      final fall = (t * f.fall + f.phase) % 1.0;
      final y = fall * tall - size.height * 0.06;
      var x = (f.x * wide + fall * wide * wind + sin(2 * pi * (t * f.swayTurns + f.phase * 3)) * f.sway * scale) % wide;
      x -= size.width * 0.1;
      final cell = grid[(y / size.height * _rows).floor().clamp(0, _rows - 1) * _cols + (x / size.width * _cols).floor().clamp(0, _cols - 1)];
      final s = f.size * scale / 32;
      transforms
        ..[i * 4] = s
        ..[i * 4 + 1] = 0
        ..[i * 4 + 2] = x - 16 * s
        ..[i * 4 + 3] = y - 16 * s;
      rects
        ..[i * 4] = 0
        ..[i * 4 + 1] = 0
        ..[i * 4 + 2] = 32
        ..[i * 4 + 3] = 32;
      colors[i] = cell.withValues(alpha: f.alpha * shown).toARGB32();
    }
    canvas.drawRawAtlas(_flake, transforms, rects, colors, BlendMode.modulate, null, Paint()..filterQuality = FilterQuality.low);
  }

  @override
  bool shouldRepaint(_SnowPainter old) => old.time != time || old.look != look || old.vignette != vignette || old.reveal != reveal;
}

// ------------------------------------------------------------ la neve a terra

/// Il marciapiede innevato e i mattoni con la neve sui bordi, per un tratto
/// di muro lungo la strada ([origin]: da dove parte, in punti di strada).
void _groundSnow(Canvas canvas, Size size, StreetWall wall, double origin, List<StreetLight> lights, NataleLook look, {bool footprints = false}) {
  final w = size.width;
  // La neve sui bordi dei mattoni: qualche filo bianco, più fitto in basso.
  final course = wall.course;
  final length = wall.length;
  final ledge = Paint();
  for (var row = 0, y = wall.ground - course; y > -course; row++, y -= course) {
    final shift = row.isOdd ? length / 2 : 0.0;
    final first = ((origin + shift) / length).floor();
    final low = (y / wall.ground).clamp(0.0, 1.0);
    for (var col = first, x = col * length - shift - origin; x < w; col++, x += length) {
      final h = _hash(row, col, 7);
      if (h > 0.035 + 0.16 * low * low * low) continue;
      final from = x + length * (0.05 + 0.4 * _hash(row, col, 8));
      final run = length * (0.18 + 0.36 * _hash(row, col, 9));
      final p = Offset(from + run / 2, y + 1);
      ledge.color = _snowAt(p, lights, look, shade: 0.82).withValues(alpha: 0.75);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(from, y - 0.2, run, max(1.2, course * 0.10)), const Radius.circular(1)), ledge);
    }
  }

  // Il marciapiede: una coltre che sale un poco contro il muro.
  final depth = wall.curb - wall.ground;
  final top = wall.ground - depth * 0.10;
  final drift = Path()..moveTo(0, wall.ground + depth * 0.80);
  drift.lineTo(0, top);
  const steps = 24;
  for (var i = 1; i <= steps; i++) {
    final x = w * i / steps;
    final world = origin + x;
    final lift = depth * (0.10 + 0.16 * (0.5 + 0.5 * sin(world / 37.0) * cos(world / 23.0)));
    drift.lineTo(x, wall.ground - lift);
  }
  drift
    ..lineTo(w, wall.ground + depth * 0.80)
    ..close();
  const samples = 9;
  final tones = [for (var i = 0; i < samples; i++) _snowAt(Offset(w * i / (samples - 1), wall.ground - depth * 2), lights, look, shade: 0.95)];
  final shades = [for (var i = 0; i < samples; i++) _snowAt(Offset(w * i / (samples - 1), wall.ground - depth * 2), lights, look, shade: 0.70)];
  canvas.drawPath(drift, Paint()..shader = LinearGradient(colors: tones).createShader(Rect.fromLTWH(0, 0, w, 1)));
  // In basso la coltre gira sul bordo del marciapiede ed è in ombra.
  final edge = Rect.fromLTRB(0, wall.ground + depth * 0.50, w, wall.ground + depth * 0.86);
  canvas.drawRect(
    edge,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [shades[samples ~/ 2].withValues(alpha: 0), shades[samples ~/ 2].withValues(alpha: 0.85)],
      ).createShader(edge),
  );
  // Le orme di chi è passato, verso il lampione.
  if (footprints) {
    final rng = Random(2);
    final ink = Paint()..color = const Color(0xFF1A2238).withValues(alpha: 0.42);
    for (var i = 0; i < 11; i++) {
      final x = w * (0.98 - i * 0.075) + rng.nextDouble() * 3;
      final y = wall.ground + depth * (0.30 + (i.isEven ? 0.0 : 0.14));
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(-0.12);
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: depth * 0.26, height: depth * 0.09), ink);
      canvas.drawOval(Rect.fromCenter(center: Offset(-depth * 0.17, 0), width: depth * 0.09, height: depth * 0.07), ink);
      canvas.restore();
    }
  }
  // L'asfalto resta bagnato: sul ciglio, la poltiglia grigia.
  final slush = Rect.fromLTRB(0, wall.curb - 2, w, wall.curb + depth * 0.5);
  canvas.drawRect(
    slush,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [shades[samples ~/ 2].withValues(alpha: 0.45), shades[samples ~/ 2].withValues(alpha: 0)],
      ).createShader(slush),
  );
}

// ------------------------------------------------------------- il vicolo

/// Il Natale del vicolo di casa: dove vanno le lucine, l'insegna degli
/// auguri, la neve sulle cose. Lo costruisce la schermata iniziale con le
/// sue stesse misure, e ne prende gli strati da mettere tra i suoi.
class NataleAlley implements SeasonAlley {
  final NataleLook look;
  final HomeAlleyLayout layout;

  /// Sul PC: niente manifesto di stasera, la barra in alto al posto delle targhe.
  final bool desktop;
  final bool canvas;
  final bool signedIn;

  NataleAlley(this.look, this.layout, {required this.desktop, required this.canvas, required this.signedIn});

  /// Al posto della pioggia, la neve.
  @override
  bool get rain => false;

  Size get size => layout.size;

  /// Il filo delle lucine: dal cappello del lampione a destra, sotto le
  /// lettere di OBERTÀ, sopra i manifesti.
  late final List<Offset> hooks = () {
    final top = (layout.sign.bottom + layout.mainPoster.top) / 2 - layout.cap * 0.10;
    final left = Offset(layout.lampHead.dx + layout.smoker * 0.06, layout.lampHead.dy - layout.smoker * 0.07);
    final right = size.width + 6;
    final n = max(3, ((right - left.dx) / (desktop ? 230 : 96)).round());
    return [
      left,
      for (var i = 1; i <= n; i++) Offset(left.dx + (right - left.dx) * i / n, top - (i.isOdd ? 0 : layout.cap * 0.04)),
    ];
  }();

  double get sag => min(layout.cap * 0.20, (layout.mainPoster.top - layout.sign.bottom) * 0.62 + layout.cap * 0.05);

  late final Path festoon = _swags(hooks, sag);

  late final List<(Offset, Offset)> bulbs = switch (look) {
    NataleLook.sangue => const [],
    _ => _along(festoon, desktop ? 34 : 19),
  };

  double get bulbSize => desktop ? 5.8 : 3.1;

  /// L'insegna di Natale sul muro, se questa prova ne ha una: in alto a
  /// destra di OBERTÀ sul PC, sul telefono tra il lampione e i cartelli.
  late final _NeonSign? _sign = () {
    final lines = switch (look) {
      NataleLook.cenone => const ['AUGURI'],
      NataleLook.sangue => const ['BUON', 'NATALE'],
      NataleLook.vicolo => null,
    };
    if (lines == null) return null;
    final Rect box;
    if (size.width > 700) {
        // Sul PC, tra il lampione e OBERTÀ: mentre si cammina per strada esce
      // di scena con il vicolo, senza restare a metà sul bordo.
      box = Rect.fromLTRB(layout.lampHead.dx + layout.smoker * 0.30, layout.sign.top + layout.cap * 0.35, layout.sign.left - layout.cap * 0.45, layout.sign.bottom + layout.cap * 0.25);
    } else {
      final top = layout.lampHead.dy + layout.smoker * 0.34;
      final bottom = (layout.tutorial?.top ?? top + layout.smoker * 0.6) - 10;
      // Sul muro dietro il palo: il palo gli passa davanti.
      box = Rect.fromLTRB(layout.lampFoot.dx + layout.smoker * 0.05, top, layout.mainPoster.left - 7, bottom);
    }
    return _NeonSign(box, lines, slant: look == NataleLook.cenone ? StreetNeon.slant : 0, swash: look == NataleLook.cenone, maxCap: layout.cap * 0.42);
  }();

  Color get neonColor => look == NataleLook.cenone ? _augurGreen : _iceWhite;

  /// Le luci del vicolo, con quelle di Natale: sui mattoni si mescolano.
  @override
  late final List<StreetLight> lights = [
    ...layout.lights,
    if (_sign case final sign?) sign.light(neonColor, size),
    for (final (i, (socket, down)) in bulbs.indexed)
      StreetSignLight(
        band: Rect.fromCircle(center: socket + down * bulbSize * 1.5, radius: 1),
        reach: bulbSize * 8,
        wash: 0,
        spread: 1,
        color: StreetLight.tint(_bulbColors(look)[i % _bulbColors(look).length], 0.5),
      ),
  ];

  /// Le posizioni dei manifesti, come le mette la schermata.
  List<(Rect, double)> get _posters {
    final friends = desktop ? Rect.fromLTRB(layout.leftPoster.left, layout.mainPoster.top, layout.leftPoster.right, layout.leftPoster.bottom) : layout.leftPoster;
    final ranked = desktop ? Rect.fromLTRB(layout.rightPoster.left, layout.mainPoster.top, layout.rightPoster.right, layout.rightPoster.bottom) : layout.rightPoster;
    return [if (!desktop) (layout.mainPoster, -0.016), (friends, 0.030), (ranked, -0.038)];
  }

  /// Sul muro, dietro i manifesti: la neve sui bordi dei mattoni e
  /// l'insegna di Natale.
@override
  Widget get wall => IgnorePointer(child: Baked(child: CustomPaint(painter: _AlleyWallPainter(this))));

  /// Sulle lettere di OBERTÀ (che scivolano via con l'insegna).
@override
  Widget get letters => IgnorePointer(
    child: StreetDrift(depth: 0.25, fade: 0, child: Baked(child: CustomPaint(painter: _AlleyLettersPainter(this)))),
  );

  /// Sui manifesti (che scivolano via con loro).
@override
  Widget get posters => IgnorePointer(
    child: StreetDrift(depth: 0.55, child: Baked(child: CustomPaint(painter: _AlleyPostersPainter(this)))),
  );

  /// Davanti ai manifesti: le lucine (o il festone), la neve sulle targhe e
  /// sul marciapiede.
@override
  Widget get front => IgnorePointer(child: Baked(child: CustomPaint(painter: _AlleyFrontPainter(this))));

  /// Sopra il lampione e l'uomo: la neve sul cappello, sul lampione e sui
  /// cartelli, e quella che cade.
@override
  Widget top(Animation<double> intro) => IgnorePointer(
    child: FadeTransition(
      opacity: intro.drive(CurveTween(curve: const Interval(0.13, 0.36, curve: Curves.easeInOut))),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ValueListenableBuilder<int>(
            valueListenable: StreetStage.walking,
            builder: (context, walking, _) => Baked(child: CustomPaint(painter: _AlleyTopPainter(this, smoker: walking == 0))),
          ),
          NataleSnow(look: look, lights: lights),
        ],
      ),
    ),
  );
}

class _AlleyWallPainter extends CustomPainter {
  final NataleAlley alley;

  _AlleyWallPainter(this.alley);

  @override
  void paint(Canvas canvas, Size size) {
    _groundSnow(canvas, size, alley.layout.wall, 0, alley.lights, alley.look, footprints: alley.look != NataleLook.cenone);
    // Il freddo di C sul muro e sulla neve, sotto le insegne: i tubi restano accesi.
    if (alley.look == NataleLook.sangue) _cold(canvas, size);
    if (alley._sign case final sign?) {
      sign.paint(canvas, alley.neonColor, flicker: alley.look == NataleLook.sangue ? (sign.lines.length - 1, sign.lines.last.length - 4) : null);
    }
  }

  @override
  bool shouldRepaint(_AlleyWallPainter old) => old.alley.look != alley.look || old.alley.layout != alley.layout;
}

class _AlleyLettersPainter extends CustomPainter {
  final NataleAlley alley;

  _AlleyLettersPainter(this.alley);

  @override
  void paint(Canvas canvas, Size size) {
    final layout = alley.layout;
    final cap = layout.cap;
    final top = layout.sign.top + HomeNeonSign.headroom * cap;
    Offset at(int i) => Offset(layout.sign.left + HomeNeonSign.leftOf(i) * cap, top);
    final depth = cap * 0.055;
    Color tone(Offset p, [double shade = 1]) => _snowAt(p, alley.lights, alley.look, shade: shade);
    void flat(int i, double from, double to, int seed) {
      final a = at(i) + Offset(from * cap, -cap * 0.045);
      final b = at(i) + Offset(to * cap, -cap * 0.045);
      _cap(canvas, a, b, depth, tone(a), tone(a, 0.7), seed: seed, drip: 0.25);
    }

    // La O: la neve sulla curva in cima.
    final o = at(0);
    _rim(
      canvas,
      Path()..addArc(Rect.fromLTWH(o.dx + cap * 0.01, o.dy - cap * 0.038, 0.60 * cap, 0.62 * cap), pi * 1.24, pi * 0.52),
      depth * 1.2,
      tone(o),
      tone(o, 0.7),
    );
    flat(1, -0.02, 0.26, 2); // B
    flat(2, -0.02, 0.50, 3); // E
    flat(3, -0.02, 0.28, 4); // R
    flat(4, -0.02, 0.62, 5); // T
    // I due pomelli del telaio.
    for (final x in [layout.sign.left - cap * 0.16, layout.sign.right + cap * 0.16]) {
      final p = Offset(x, top + cap * 0.10 - cap * 0.05);
      _cap(canvas, p - Offset(cap * 0.04, 0), p + Offset(cap * 0.04, 0), depth * 0.8, tone(p), tone(p, 0.7), seed: 9, drip: 0);
    }
  }

  @override
  bool shouldRepaint(_AlleyLettersPainter old) => old.alley.look != alley.look || old.alley.layout != alley.layout;
}

class _AlleyPostersPainter extends CustomPainter {
  final NataleAlley alley;

  _AlleyPostersPainter(this.alley);

  @override
  void paint(Canvas canvas, Size size) {
    final look = alley.look;
    for (final (i, (rect, tilt)) in alley._posters.indexed) {
      canvas.save();
      canvas.translate(rect.center.dx, rect.center.dy);
      canvas.rotate(tilt);
      canvas.translate(-rect.center.dx, -rect.center.dy);
      if (look == NataleLook.sangue) {
        canvas.drawRect(
          rect.deflate(1),
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [const Color(0xFF0C1A40).withValues(alpha: 0.30), const Color(0xFF0C1A40).withValues(alpha: 0.18)],
            ).createShader(rect),
        );
      }
      final a = rect.topLeft + const Offset(4, 1);
      final b = rect.topRight + const Offset(-4, 1);
      final depth = alley.desktop ? 5.0 : 3.2;
      _cap(canvas, a, b, depth, _snowAt(rect.topCenter, alley.lights, look), _snowAt(rect.topCenter, alley.lights, look, shade: 0.7), seed: 20 + i, drip: 0.2);
      if (look == NataleLook.cenone) {
        // L'agrifoglio appuntato agli angoli in alto, sopra lo scotch.
        final s = alley.desktop ? 30.0 : 15.0;
        _holly(canvas, rect.topLeft + Offset(s * 0.5, s * 0.35), s, 0.15, dark: 0.15);
        _holly(canvas, rect.topRight + Offset(-s * 0.5, s * 0.35), s, pi - 0.15, dark: 0.15);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_AlleyPostersPainter old) => old.alley.look != alley.look || old.alley.layout != alley.layout;
}

class _AlleyFrontPainter extends CustomPainter {
  final NataleAlley alley;

  _AlleyFrontPainter(this.alley);

  @override
  void paint(Canvas canvas, Size size) {
    final layout = alley.layout;
    final look = alley.look;
    final lights = alley.lights;
    Color tone(Offset p, [double shade = 1]) => _snowAt(p, lights, look, shade: shade);

    // La neve sulle targhe in alto.
    if (!alley.canvas) {
      final slot = layout.slot;
      final r = slot.shortestSide * 0.33;
      final c = slot.center;
      _rim(canvas, Path()..addArc(Rect.fromCircle(center: c, radius: r + 1), pi * 1.2, pi * 0.6), 3.2, tone(c), tone(c, 0.7));
      if (alley.signedIn) {
        for (final (i, sign) in [layout.shop, layout.barber].indexed) {
          final y = sign.top + 11;
          _cap(canvas, Offset(sign.left + 2, y), Offset(sign.right - 2, y), 3.0, tone(sign.topCenter), tone(sign.topCenter, 0.7), seed: 30 + i);
          _cap(canvas, Offset(sign.left + 4, sign.top + 1.5), Offset(sign.right - 4, sign.top + 1.5), 1.6, tone(sign.topCenter), tone(sign.topCenter, 0.7), seed: 40 + i, drip: 0);
        }
        final badge = layout.badge;
        _cap(canvas, Offset(badge.left + badge.height * 0.95, badge.top + badge.height * 0.18), Offset(badge.right - badge.height * 0.4, badge.top + badge.height * 0.18), 2.6, tone(badge.topCenter), tone(badge.topCenter, 0.7), seed: 50);
        final ring = Offset(badge.left + badge.height * 0.5, badge.center.dy);
        _rim(canvas, Path()..addArc(Rect.fromCircle(center: ring, radius: badge.height * 0.50), pi * 1.22, pi * 0.55), 3.0, tone(ring), tone(ring, 0.7));
      } else if (layout.shopCompact case final sign?) {
        _cap(canvas, Offset(sign.left + 2, sign.top + 11), Offset(sign.right - 2, sign.top + 11), 3.0, tone(sign.topCenter), tone(sign.topCenter, 0.7), seed: 30);
      }
    }

    // Il festone del cenone, d'abete con i fiocchi e le palline.
    if (look == NataleLook.cenone) {
      final thick = alley.desktop ? 20.0 : 10.5;
      _garland(canvas, alley.festoon, thick, lights, seed: 5, gain: 0.62);
      final metric = alley.festoon.computeMetrics().first;
      final golds = [_C.gold, const Color(0xFFB3121C), _C.gold, const Color(0xFFE8D9A8)];
      var k = 0;
      for (var d = 26.0; d < metric.length; d += alley.desktop ? 70 : 34) {
        final t = metric.getTangentForOffset(d)!;
        _bauble(canvas, t.position + Offset(0, thick * 0.18), thick * 0.30, golds[k++ % golds.length], dark: 0.1);
      }
    }
    // Il filo e le lampadine (nel cenone il filo sta dentro il festone).
    if (alley.bulbs.isNotEmpty) {
      if (look == NataleLook.vicolo) {
        canvas.drawPath(
          alley.festoon,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = alley.desktop ? 1.6 : 1.1
            ..color = _C.wire,
        );
      }
      final colors = _bulbColors(look);
      for (final (i, (socket, down)) in alley.bulbs.indexed) {
        _bulb(canvas, socket, down, colors[i % colors.length], alley.bulbSize);
      }
    }
    if (look == NataleLook.cenone) {
      for (final hook in alley.hooks.skip(1)) {
        if (hook.dx > size.width) continue;
        _bow(canvas, hook + const Offset(0, 1), alley.desktop ? 17 : 8.5, dim: 0.08);
      }
    }

    if (look == NataleLook.vicolo) _fog(canvas, size, layout.ground, layout.curb);
    if (look == NataleLook.sangue) _fog(canvas, size, layout.ground, layout.curb, strength: 0.7, color: const Color(0xFF8EA6DA));
  }

  @override
  bool shouldRepaint(_AlleyFrontPainter old) => old.alley.look != alley.look || old.alley.layout != alley.layout || old.alley.signedIn != alley.signedIn;
}

class _AlleyTopPainter extends CustomPainter {
  final NataleAlley alley;
  final bool smoker;

  _AlleyTopPainter(this.alley, {required this.smoker});

  @override
  void paint(Canvas canvas, Size size) {
    final layout = alley.layout;
    final look = alley.look;
    Color tone(Offset p, [double shade = 1]) => _dim(_snowAt(p, alley.lights, look, shade: shade), _vignetteAt(p, size));
    final u = layout.smoker;
    final head = layout.lampHead;
    final foot = layout.lampFoot;

    // Il cappello della lanterna e il braccio del lampione.
    final hat = head - Offset(0, u * 0.085);
    _cap(canvas, hat - Offset(u * 0.05, 0), hat + Offset(u * 0.05, 0), u * 0.030, tone(hat), tone(hat, 0.7), seed: 60, drip: 0.3);
    final shoulder = Offset(foot.dx, head.dy + u * 0.16);
    final arm = Path()
      ..moveTo(shoulder.dx, shoulder.dy - u * 0.02)
      ..quadraticBezierTo(foot.dx + u * 0.01, head.dy - u * 0.13 - u * 0.025, head.dx - u * 0.05, head.dy - u * 0.06 - u * 0.03);
    _rim(canvas, arm, u * 0.020, tone(shoulder), tone(shoulder, 0.7));
    if (look == NataleLook.vicolo) {
      // La corona appesa al palo, sotto il braccio.
      final c = Offset(foot.dx, head.dy + u * 0.36);
      if (layout.tutorial == null || c.dy + u * 0.16 < layout.tutorial!.top) _wreath(canvas, c, u * 0.085, alley.lights, look);
    }
    if (look == NataleLook.cenone) {
      // Il nastro rosso a spirale lungo il palo, col fiocco sotto la lanterna.
      final ribbon = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = u * 0.026
        ..strokeCap = StrokeCap.butt
        ..color = _dim(_C.red, 0.15);
      final from = shoulder.dy + u * 0.08;
      final to = foot.dy - u * 0.32;
      final signs = [?layout.tutorial, ?layout.rules];
      for (var y = from; y < to; y += u * 0.11) {
        if (signs.any((r) => y + u * 0.05 > r.top - 2 && y - u * 0.01 < r.bottom + 2)) continue;
        canvas.drawLine(Offset(foot.dx - u * 0.022, y + u * 0.035), Offset(foot.dx + u * 0.022, y), ribbon);
        canvas.drawLine(
          Offset(foot.dx - u * 0.012, y + u * 0.018),
          Offset(foot.dx + u * 0.010, y + u * 0.003),
          Paint()
            ..strokeWidth = u * 0.006
            ..color = _C.redLight.withValues(alpha: 0.8),
        );
      }
      _bow(canvas, Offset(foot.dx, shoulder.dy + u * 0.03), u * 0.075, dim: 0.1);
    }

    // I cartelli del tutorial e delle regole.
    for (final (i, (sign, tilt)) in [(layout.tutorial, -0.02), (layout.rules, 0.018)].indexed) {
      if (sign == null) continue;
      canvas.save();
      canvas.translate(sign.center.dx, sign.center.dy);
      canvas.rotate(tilt);
      canvas.translate(-sign.center.dx, -sign.center.dy);
      final h = sign.height;
      if (look == NataleLook.sangue) {
        canvas.drawPath(
          Path()
            ..moveTo(sign.left, sign.top)
            ..lineTo(sign.right - h * 0.42, sign.top)
            ..lineTo(sign.right, sign.center.dy)
            ..lineTo(sign.right - h * 0.42, sign.bottom)
            ..lineTo(sign.left, sign.bottom)
            ..close(),
          Paint()..color = const Color(0xFF0C1A40).withValues(alpha: 0.24),
        );
      }
      _cap(canvas, Offset(sign.left + h * 0.14, sign.top + 0.5), Offset(sign.right - h * 0.55, sign.top + 0.5), h * 0.11, tone(sign.topCenter), tone(sign.topCenter, 0.7), seed: 70 + i);
      canvas.restore();
    }

    // L'uomo sotto il lampione: neve sul cappello e sulle spalle.
    if (smoker && look != NataleLook.cenone) {
      final h = layout.smoker;
      canvas.save();
      canvas.translate(layout.smokerFeet.dx, layout.smokerFeet.dy);
      canvas.rotate(-0.05);
      final hip = Offset(0, -h * 0.50);
      final hd = hip + Offset(h * 0.03, -h * 0.485);
      final p = layout.smokerFeet + Offset(0, -h);
      final crown = Path()
        ..moveTo(hd.dx - h * 0.078, hd.dy - h * 0.138)
        ..quadraticBezierTo(hd.dx - h * 0.060, hd.dy - h * 0.168, hd.dx - h * 0.040, hd.dy - h * 0.166)
        ..quadraticBezierTo(hd.dx + h * 0.010, hd.dy - h * 0.138, hd.dx + h * 0.055, hd.dy - h * 0.170)
        ..quadraticBezierTo(hd.dx + h * 0.085, hd.dy - h * 0.165, hd.dx + h * 0.094, hd.dy - h * 0.120);
      _rim(canvas, crown, h * 0.020, tone(p), tone(p, 0.65));
      canvas.save();
      canvas.translate(hd.dx + h * 0.025, hd.dy - h * 0.046);
      canvas.rotate(0.16);
      _rim(canvas, Path()
        ..moveTo(h * 0.085, -h * 0.026)
        ..quadraticBezierTo(h * 0.13, -h * 0.024, h * 0.168, -h * 0.010), h * 0.014, tone(p), tone(p, 0.65));
      _rim(canvas, Path()
        ..moveTo(-h * 0.170, -h * 0.008)
        ..quadraticBezierTo(-h * 0.14, -h * 0.024, -h * 0.110, -h * 0.026), h * 0.012, tone(p), tone(p, 0.65));
      canvas.restore();
      final shoulders = Path()
        ..moveTo(hip.dx - h * 0.138, hip.dy - h * 0.338)
        ..quadraticBezierTo(hip.dx - h * 0.10, hip.dy - h * 0.383, hip.dx - h * 0.04, hip.dy - h * 0.386);
      _rim(canvas, shoulders, h * 0.011, tone(p, 0.9), tone(p, 0.6));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_AlleyTopPainter old) => old.alley.look != alley.look || old.alley.layout != alley.layout || old.smoker != smoker;
}

// ------------------------------------------------------------ la strada

/// Il Natale davanti a un locale della strada: la corona sulla porta, le
/// lucine sopra la tenda, la neve sulla tenda, sul davanzale e sul
/// marciapiede, l'insegna degli auguri accanto a quella del locale.
class NataleStreet implements SeasonStreet {
  final NataleLook look;
  final StreetFacadeLayout layout;
  final StreetSection section;

  /// Il posto lungo la strada: la neve a terra continua da una pagina all'altra.
  final int index;

  /// Le luci della pagina di prima, che arrivano fin qui.
  final List<StreetLight> before;

  NataleStreet(this.look, this.layout, this.section, {required this.index, this.before = const []});

  /// Tutte le luci che cadono su questo tratto: per la neve.
  late final List<StreetLight> _all = [for (final light in before) light.shift(-size.width), ...lights];

  Size get size => layout.size;

  bool get desk => layout.desk;

  late final List<Offset> hooks = () {
    final y = layout.awning.top - (desk ? 70 : 34);
    final n = desk ? 6 : 3;
    return [for (var i = 0; i <= n; i++) Offset(-6 + (size.width + 12) * i / n, y - (i.isOdd ? (desk ? 10 : 5) : 0))];
  }();

  late final Path festoon = _swags(hooks, desk ? 34 : 17);

  late final List<(Offset, Offset)> bulbs = look == NataleLook.sangue ? const [] : _along(festoon, desk ? 36 : 20);

  double get bulbSize => desk ? 5.8 : 3.1;

  /// L'insegna degli auguri, sul muro tra quella del locale e la tenda.
  late final _NeonSign? _sign = () {
    final lines = switch (look) {
      NataleLook.cenone => const ['BUONE FESTE'],
      NataleLook.sangue => const ['BUON NATALE'],
      NataleLook.vicolo => null,
    };
    if (lines == null) return null;
    // Sul PC c'è muro libero a sinistra della tenda (si vede già mentre
    // l'uomo arriva); sul telefono sopra.
    final box = desk
        ? Rect.fromLTRB(70, layout.awning.top - 10, layout.awning.left - 60, layout.door.top + layout.door.height * 0.30)
        : Rect.fromLTRB(size.width * 0.12, layout.neon.bottom + 36, size.width * 0.88, hooks.first.dy - 26);
    return _NeonSign(box, lines, slant: look == NataleLook.cenone ? StreetNeon.slant : 0, swash: look == NataleLook.cenone, maxCap: layout.neon.height * (desk ? 0.50 : 0.46));
  }();

  Color get neonColor => look == NataleLook.cenone ? _festeGold : _iceWhite;

  @override
  late final List<StreetLight> lights = [
    ...layout.lightsOf(section),
    if (_sign case final sign?) sign.light(neonColor, size, gain: 0.8, reach: 1.0),
    for (final (i, (socket, down)) in bulbs.indexed)
      StreetSignLight(
        band: Rect.fromCircle(center: socket + down * bulbSize * 1.5, radius: 1),
        reach: bulbSize * 8,
        wash: 0,
        spread: 1,
        color: StreetLight.tint(_bulbColors(look)[i % _bulbColors(look).length], 0.5),
      ),
  ];

  /// Sotto la facciata: la neve a terra e sui mattoni, l'insegna degli auguri.
  @override
  Widget get ground => IgnorePointer(child: Baked(child: CustomPaint(painter: _StreetGroundPainter(this))));

  /// Sopra la facciata: la neve sulla tenda e sul davanzale, le lucine, la
  /// corona sulla porta (che si apre con lei, [door]), la vignettatura.
  @override
  Widget front({required double door, required bool vignette}) => IgnorePointer(
    child: Stack(
      fit: StackFit.expand,
      children: [
        Baked(child: CustomPaint(painter: _StreetFrontPainter(this))),
        RepaintBoundary(child: CustomPaint(painter: _StreetDoorPainter(this, door))),
        if (vignette) const CustomPaint(painter: StreetVignettePainter()),
      ],
    ),
  );

  @override
  Widget get air => NataleSnow(look: look, lights: _all, vignette: false);
}

class _StreetGroundPainter extends CustomPainter {
  final NataleStreet street;

  _StreetGroundPainter(this.street);

  @override
  void paint(Canvas canvas, Size size) {
    _groundSnow(canvas, size, street.layout.wall, street.index * size.width, street._all, street.look);
  }

  @override
  bool shouldRepaint(_StreetGroundPainter old) => old.street.look != street.look || old.street.layout != street.layout || old.street.index != street.index;
}

class _StreetFrontPainter extends CustomPainter {
  final NataleStreet street;

  _StreetFrontPainter(this.street);

  @override
  void paint(Canvas canvas, Size size) {
    final layout = street.layout;
    final look = street.look;
    final lights = street._all;
    Color tone(Offset p, [double shade = 1]) => _snowAt(p, lights, look, shade: shade);
    final a = layout.awning;
    final door = layout.door;
    final win = layout.window;
    final u = door.width;

    // Il vetro gelato agli angoli.
    if (look != NataleLook.cenone && street.section.front != StreetFront.club) {
      canvas.save();
      canvas.clipRect(win);
      for (final corner in [win.topLeft, win.topRight, win.bottomLeft, win.bottomRight]) {
        final r = win.shortestSide * 0.42;
        canvas.drawCircle(
          corner,
          r,
          Paint()
            ..shader = RadialGradient(
              colors: [const Color(0xCCE8F0FF), const Color(0x55C8D8F0), const Color(0x00C8D8F0)],
              stops: const [0, 0.45, 1],
            ).createShader(Rect.fromCircle(center: corner, radius: r)),
        );
      }
      canvas.restore();
    }
    if (look != NataleLook.sangue && street.section.front == StreetFront.cafe) {
      // Dentro la vetrina, l'alberello con le sue lucine (A) o le candele sui tavolini (B).
      canvas.save();
      canvas.clipRect(win);
      final ink = Paint()..color = _C.ink.withValues(alpha: 0.92);
      if (look == NataleLook.vicolo) {
        final base = Offset(win.left + win.width * 0.86, win.bottom);
        final tall = win.height * 0.62;
        final tree = Path()
          ..moveTo(base.dx, base.dy - tall)
          ..lineTo(base.dx + tall * 0.30, base.dy - tall * 0.12)
          ..lineTo(base.dx - tall * 0.30, base.dy - tall * 0.12)
          ..close();
        canvas.drawPath(tree, ink);
        canvas.drawRect(Rect.fromCenter(center: base - Offset(0, tall * 0.06), width: tall * 0.07, height: tall * 0.12), ink);
        final rng = Random(6);
        for (var i = 0; i < 14; i++) {
          final v = 0.12 + 0.82 * rng.nextDouble();
          final x = base.dx + (rng.nextDouble() - 0.5) * tall * 0.52 * v;
          final p = Offset(x, base.dy - tall + tall * 0.88 * v);
          canvas.drawCircle(p, max(1.0, u * 0.012), Paint()..color = const Color(0xFFFFE6A8));
          canvas.drawCircle(p, max(2.0, u * 0.03), Paint()..color = const Color(0x44FFC870));
        }
      } else {
        for (final f in [0.28, 0.72]) {
          final x = win.left + win.width * f;
          final top = win.bottom - win.height * 0.26;
          canvas.drawRect(Rect.fromLTRB(x - 1.6, top - win.height * 0.09, x + 1.6, top), Paint()..color = const Color(0xFFF2E6CC));
          final flame = Offset(x, top - win.height * 0.115);
          canvas.drawCircle(flame, win.height * 0.07, Paint()..color = const Color(0x55FFB050));
          canvas.drawOval(Rect.fromCenter(center: flame, width: win.height * 0.018, height: win.height * 0.04), Paint()..color = const Color(0xFFFFF0C0));
        }
      }
      canvas.restore();
    }

    // La neve sulla tenda, sul davanzale, sullo stipite.
    final depth = street.desk ? 9.0 : 5.0;
    _cap(canvas, Offset(a.left, a.top - 3), Offset(a.right, a.top - 3), depth, tone(a.topCenter), tone(a.topCenter, 0.7), seed: 80);
    final sill = win.bottom + 6;
    _cap(canvas, Offset(win.left, sill), Offset(win.right, sill), depth * 0.7, tone(Offset(win.center.dx, sill)), tone(Offset(win.center.dx, sill), 0.7), seed: 81);
    final frame = door.inflate(door.width * 0.07);
    _cap(canvas, frame.topLeft, frame.topRight, depth * 0.75, tone(frame.topCenter), tone(frame.topCenter, 0.7), seed: 82);

    // Il festone d'abete sulla tenda (B).
    if (look == NataleLook.cenone) {
      final thick = street.desk ? 18.0 : 10.0;
      final swag = _swags([Offset(a.left + 4, a.top + 2), Offset(a.center.dx - a.width * 0.17, a.top + 2), Offset(a.center.dx + a.width * 0.17, a.top + 2), Offset(a.right - 4, a.top + 2)], thick * 0.7);
      _garland(canvas, swag, thick, lights, seed: 7, gain: 0.5);
      final metric = swag.computeMetrics().first;
      var k = 0;
      for (var d = thick; d < metric.length; d += street.desk ? 60 : 30) {
        final t = metric.getTangentForOffset(d)!;
        _bauble(canvas, t.position + Offset(0, thick * 0.18), thick * 0.28, (k++).isEven ? _C.gold : _C.red, dark: 0.05);
      }
      for (final x in [a.left + 4, a.center.dx - a.width * 0.17, a.center.dx + a.width * 0.17, a.right - 4]) {
        _bow(canvas, Offset(x, a.top + 2), thick * 0.85);
      }
    }

    // Le lucine sopra la tenda.
    if (street.bulbs.isNotEmpty) {
      canvas.drawPath(
        street.festoon,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = street.desk ? 1.6 : 1.1
          ..color = _C.wire,
      );
      for (final hook in street.hooks) {
        canvas.drawCircle(hook, street.desk ? 2.4 : 1.6, Paint()..color = _C.wire);
      }
      final colors = _bulbColors(look);
      for (final (i, (socket, down)) in street.bulbs.indexed) {
        _bulb(canvas, socket, down, colors[i % colors.length], street.bulbSize);
      }
    }
    if (look == NataleLook.vicolo) _fog(canvas, size, layout.ground, layout.curb);
    if (look == NataleLook.sangue) {
      _fog(canvas, size, layout.ground, layout.curb, strength: 0.7, color: const Color(0xFF8EA6DA));
      _cold(canvas, size);
    }
    // L'insegna degli auguri, sopra il freddo: i tubi restano accesi.
    if (street._sign case final sign?) {
      sign.paint(canvas, street.neonColor, flicker: look == NataleLook.sangue ? (0, 7) : null);
    }
  }

  @override
  bool shouldRepaint(_StreetFrontPainter old) => old.street.look != street.look || old.street.layout != street.layout;
}

/// La corona (A, B) o il solo fiocco rosso sulla maniglia (C), sul battente
/// della porta: quando si apre, si stringe con lui verso i cardini.
class _StreetDoorPainter extends CustomPainter {
  final NataleStreet street;
  final double open;

  _StreetDoorPainter(this.street, this.open);

  @override
  void paint(Canvas canvas, Size size) {
    final door = street.layout.door;
    final squash = 1 - 0.82 * Curves.easeInOut.transform(open.clamp(0.0, 1.0));
    if (squash < 0.2) return;
    canvas.save();
    canvas.translate(door.left, 0);
    canvas.scale(squash, 1);
    canvas.translate(-door.left, 0);
    if (street.look == NataleLook.sangue) {
      final knob = Offset(door.right - door.width * 0.14, door.center.dy + door.height * 0.04);
      _bow(canvas, knob + Offset(-door.width * 0.02, -door.width * 0.09), door.width * 0.11, dim: 0.1);
    } else {
      _wreath(canvas, Offset(door.center.dx, door.top + door.height * 0.25), door.width * (street.look == NataleLook.cenone ? 0.27 : 0.24), street.lights, street.look);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StreetDoorPainter old) => old.street.look != street.look || old.street.layout != street.layout || old.open != open;
}

// -------------------------------------------------------------- il tavolo

/// Il Natale della sala sul retro: la luna fredda (C) sulle pareti e sul
/// pavimento. Null dove il Natale non tocca la sala.
Widget? _nataleRoom(NataleLook look, {required bool night}) {
  if (look != NataleLook.sangue) return null;
  return Positioned.fill(child: IgnorePointer(child: Baked(child: CustomPaint(painter: _RoomPainter(look)))));
}

class _RoomPainter extends CustomPainter {
  final NataleLook look;

  _RoomPainter(this.look);

  @override
  void paint(Canvas canvas, Size size) => _cold(canvas, size);

  @override
  bool shouldRepaint(_RoomPainter old) => old.look != look;
}

/// Il Natale sul tavolo: sul panno e sul bordo ([felt]), poi sulle targhette
/// dei posti ([_nataleSeats]).
Widget _nataleFelt(NataleLook look, {required Rect felt, required List<Offset> centers, required double card, required Rect area}) =>
    Positioned.fill(
      child: IgnorePointer(
        child: Baked(overflow: const EdgeInsets.all(64), child: CustomPaint(painter: _FeltPainter(look, felt, centers, card, area))),
      ),
    );

Widget? _nataleSeats(NataleLook look, {required List<Offset> centers, required double card}) {
  if (look != NataleLook.cenone) return null;
  return Positioned.fill(child: IgnorePointer(child: Baked(child: CustomPaint(painter: _PlatesPainter(centers, card)))));
}

class _FeltPainter extends CustomPainter {
  final NataleLook look;
  final Rect felt;
  final List<Offset> centers;
  final double card;
  final Rect area;

  _FeltPainter(this.look, this.felt, this.centers, this.card, this.area);

  RRect get _ring {
    final band = felt.inflate(felt.shortestSide * 0.035);
    return RRect.fromRectAndRadius(band, Radius.circular(band.shortestSide * 0.48));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final unit = (felt.shortestSide / 240).clamp(0.8, 2.6);
    switch (look) {
      case NataleLook.vicolo:
        _rimLights(canvas, unit, const [_C.warm]);
      case NataleLook.cenone:
        _rimGarland(canvas, unit);
        _feast(canvas, unit);
      case NataleLook.sangue:
        _moonlight(canvas);
        _knife(canvas, unit);
    }
  }

  /// Le lucine calde lungo il bordo di legno, il panno com'è.
  void _rimLights(Canvas canvas, double unit, List<Color> colors) {
    final path = Path()..addRRect(_ring);
    final metric = path.computeMetrics().first;
    final wire = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1 * unit
      ..color = _C.wire;
    // Il filo fa onde leggere sul legno.
    final wavy = Path();
    const steps = 220;
    for (var i = 0; i <= steps; i++) {
      final t = metric.getTangentForOffset(metric.length * i / steps)!;
      final n = Offset(-t.vector.dy, t.vector.dx);
      final p = t.position + n * sin(i * 0.9) * 2.2 * unit;
      i == 0 ? wavy.moveTo(p.dx, p.dy) : wavy.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(wavy, wire);
    final gap = 21.0 * unit;
    var k = 0;
    for (var d = 0.0; d < metric.length; d += gap) {
      final t = metric.getTangentForOffset(d)!;
      final out = Offset(t.vector.dy, -t.vector.dx);
      final color = colors[k++ % colors.length];
      final c = t.position + out * 3.2 * unit;
      final glow = Rect.fromCircle(center: c, radius: 16 * unit);
      canvas.drawOval(
        glow,
        Paint()
          ..shader = RadialGradient(colors: [color.withValues(alpha: 0.34), color.withValues(alpha: 0)]).createShader(glow),
      );
      _bulb(canvas, t.position, out, color, 2.3 * unit);
    }
  }

  /// Il festone d'abete sul bordo, coi fiocchi rossi e le palline d'oro.
  void _rimGarland(Canvas canvas, double unit) {
    final path = Path()..addRRect(_ring);
    final light = <StreetLight>[
      StreetLampLight(head: felt.center - Offset(0, felt.height * 0.9), size: felt.height * 1.4, color: (0.9, 0.7, 0.45)),
    ];
    _garland(canvas, path, 9.5 * unit, light, seed: 9, gain: 1.3);
    final metric = path.computeMetrics().first;
    var k = 0;
    for (var d = 0.0; d < metric.length; d += 26 * unit) {
      final t = metric.getTangentForOffset(d)!;
      if (k % 4 == 0) {
        _bow(canvas, t.position, 9 * unit, tails: 0.8);
      } else {
        _bauble(canvas, t.position - Offset(0, 2 * unit), 3.2 * unit, k.isEven ? _C.gold : const Color(0xFFC8102E));
      }
      k++;
    }
    final colors = _bulbColors(NataleLook.cenone);
    for (var d = 13 * unit; d < metric.length; d += 26 * unit) {
      final t = metric.getTangentForOffset(d)!;
      final out = Offset(t.vector.dy, -t.vector.dx);
      _bulb(canvas, t.position + out * 2 * unit, out, colors[k++ % colors.length], 1.9 * unit);
    }
  }

  /// Il cenone al centro del panno: il panettone sul piatto d'oro, le due
  /// candele rosse, il torrone, l'agrifoglio. Sotto il testo, mai sopra.
  void _feast(Canvas canvas, double unit) {
    final below = Rect.fromLTRB(area.left, area.center.dy + area.height * 0.22, area.right, area.bottom);
    final room = below.height;
    final base = Offset(area.center.dx, below.bottom - room * 0.10);
    final w = min(room * 0.72, area.width * 0.17).clamp(18.0, 124.0);
    // La luce calda delle candele sul panno.
    final pool = Rect.fromCenter(center: base - Offset(0, w * 0.3), width: w * 5.5, height: w * 2.6);
    canvas.drawOval(
      pool,
      Paint()
        ..shader = RadialGradient(colors: [const Color(0x55FFC070), const Color(0x00FFC070)]).createShader(pool),
    );
    _holly(canvas, base + Offset(-w * 1.55, w * 0.02), w * 0.40, -0.2, dark: 0.1);
    _holly(canvas, base + Offset(w * 1.55, w * 0.02), w * 0.40, pi + 0.2, dark: 0.1);
    _torrone(canvas, base + Offset(-w * 1.18, w * 0.12), w * 0.44, -0.25);
    _torrone(canvas, base + Offset(w * 1.14, w * 0.14), w * 0.44, 0.3);
    for (final side in [-1.0, 1.0]) {
      _candle(canvas, base + Offset(side * w * 0.98, -w * 0.16), w * 0.17, w * 0.80);
    }
    _panettone(canvas, base, w);
  }

  void _candle(Canvas canvas, Offset base, double w, double h) {
    final dish = Rect.fromCenter(center: base, width: w * 2.4, height: w * 0.8);
    canvas.drawOval(dish.shift(Offset(w * 0.2, w * 0.25)), Paint()..color = Colors.black.withValues(alpha: 0.35));
    canvas.drawOval(
      dish,
      Paint()..shader = const LinearGradient(colors: [Color(0xFF8C6A26), Color(0xFFFFE7A8), Color(0xFF9C7424)]).createShader(dish),
    );
    canvas.drawOval(dish.deflate(w * 0.25), Paint()..color = const Color(0xFF6E521C));
    final body = Rect.fromLTRB(base.dx - w / 2, base.dy - h, base.dx + w / 2, base.dy - w * 0.1);
    canvas.drawRect(
      body,
      Paint()
        ..shader = const LinearGradient(colors: [Color(0xFF5E0910), Color(0xFFD0242E), Color(0xFF7A0E16)], stops: [0, 0.45, 1])
            .createShader(body),
    );
    final top = Rect.fromCenter(center: Offset(base.dx, body.top), width: w, height: w * 0.34);
    canvas.drawOval(top, Paint()..color = const Color(0xFFE0505A));
    // La cera colata.
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(body.left + w * 0.12, body.top, w * 0.16, h * 0.22), Radius.circular(w * 0.08)), Paint()..color = const Color(0xFFE0505A));
    canvas.drawLine(Offset(base.dx, body.top), Offset(base.dx, body.top - w * 0.32), Paint()
      ..color = const Color(0xFF1A1008)
      ..strokeWidth = max(0.8, w * 0.10));
    final flame = Offset(base.dx, body.top - w * 0.78);
    final halo = Rect.fromCircle(center: flame, radius: w * 3.0);
    canvas.drawOval(
      halo,
      Paint()..shader = RadialGradient(colors: [const Color(0x88FFD27A), const Color(0x22FF9A3B), const Color(0x00FF9A3B)], stops: const [0, 0.35, 1]).createShader(halo),
    );
    final drop = Path()
      ..moveTo(flame.dx, flame.dy - w * 0.62)
      ..quadraticBezierTo(flame.dx + w * 0.42, flame.dy + w * 0.05, flame.dx, flame.dy + w * 0.36)
      ..quadraticBezierTo(flame.dx - w * 0.42, flame.dy + w * 0.05, flame.dx, flame.dy - w * 0.62)
      ..close();
    canvas.drawPath(drop, Paint()..color = const Color(0xFFFFB347));
    final inner = Offset(flame.dx, flame.dy + w * 0.08);
    canvas.drawPath(
      Path()
        ..moveTo(inner.dx, inner.dy - w * 0.36)
        ..quadraticBezierTo(inner.dx + w * 0.24, inner.dy + w * 0.03, inner.dx, inner.dy + w * 0.22)
        ..quadraticBezierTo(inner.dx - w * 0.24, inner.dy + w * 0.03, inner.dx, inner.dy - w * 0.36)
        ..close(),
      Paint()..color = const Color(0xFFFFF6D8),
    );
  }

  void _panettone(Canvas canvas, Offset base, double w) {
    final ink = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(0.8, w * 0.025)
      ..color = const Color(0xFF2A1608);
    // Il piatto d'oro e la sua ombra.
    final plate = Rect.fromCenter(center: base, width: w * 1.55, height: w * 0.46);
    canvas.drawOval(plate.shift(Offset(w * 0.06, w * 0.10)), Paint()
      ..color = Colors.black.withValues(alpha: 0.45)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.06));
    canvas.drawOval(plate, Paint()..shader = const LinearGradient(colors: [Color(0xFF8C6A26), Color(0xFFFFE7A8), Color(0xFFB8902A)]).createShader(plate));
    canvas.drawOval(plate.deflate(w * 0.07), Paint()..color = const Color(0xFFF2EAD8));
    canvas.drawOval(plate, ink);
    // La fascia di carta, a pieghe.
    final half = w * 0.5;
    final bottom = base.dy - w * 0.04;
    final top = bottom - w * 0.46;
    final rise = w * 0.13;
    final band = Path()
      ..moveTo(base.dx - half, top)
      ..lineTo(base.dx - half, bottom)
      ..arcToPoint(Offset(base.dx + half, bottom), radius: Radius.elliptical(half, rise), clockwise: false)
      ..lineTo(base.dx + half, top)
      ..arcToPoint(Offset(base.dx - half, top), radius: Radius.elliptical(half, rise))
      ..close();
    final bandRect = Rect.fromLTRB(base.dx - half, top, base.dx + half, bottom + rise);
    canvas.drawPath(
      band,
      Paint()..shader = const LinearGradient(colors: [Color(0xFFB89A5C), Color(0xFFF2E2B0), Color(0xFFC9AE6E), Color(0xFF8E7038)], stops: [0, 0.35, 0.7, 1]).createShader(bandRect),
    );
    canvas.save();
    canvas.clipPath(band);
    final pleat = Paint()
      ..color = const Color(0xFF7A5A28).withValues(alpha: 0.55)
      ..strokeWidth = max(0.6, w * 0.012);
    for (var x = base.dx - half + w * 0.06; x < base.dx + half; x += w * 0.075) {
      canvas.drawLine(Offset(x, top - rise), Offset(x, bottom + rise), pleat);
    }
    // Il filetto rosso e oro sulla carta.
    canvas.drawRect(Rect.fromLTRB(base.dx - half, top + w * 0.22, base.dx + half, top + w * 0.27), Paint()..color = const Color(0xFFB3121C));
    canvas.restore();
    canvas.drawPath(band, ink);
    // La cupola dorata che esce dalla carta.
    final dome = Path()
      ..moveTo(base.dx - half * 1.08, top + rise * 0.3)
      ..cubicTo(base.dx - half * 1.12, top - w * 0.52, base.dx + half * 1.12, top - w * 0.52, base.dx + half * 1.08, top + rise * 0.3)
      ..arcToPoint(Offset(base.dx - half * 1.08, top + rise * 0.3), radius: Radius.elliptical(half * 1.08, rise * 1.2))
      ..close();
    final domeRect = Rect.fromLTRB(base.dx - half * 1.1, top - w * 0.42, base.dx + half * 1.1, top + rise * 1.4);
    canvas.drawPath(
      dome,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.3, -0.45),
          radius: 0.9,
          colors: [Color(0xFFF0B868), Color(0xFFC07A30), Color(0xFF7A421A)],
          stops: [0, 0.5, 1],
        ).createShader(domeRect),
    );
    // Il taglio a croce in cima, e l'uvetta.
    final crest = Offset(base.dx, top - w * 0.24);
    final cut = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(0.8, w * 0.03)
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF5A2C0E);
    canvas.drawLine(crest - Offset(w * 0.20, w * 0.03), crest + Offset(w * 0.20, w * 0.03), cut);
    canvas.drawLine(crest - Offset(w * 0.04, w * 0.09), crest + Offset(w * 0.04, w * 0.09), cut);
    final rng = Random(12);
    for (var i = 0; i < 9; i++) {
      final p = Offset(base.dx + (rng.nextDouble() - 0.5) * w * 0.85, top - w * (0.02 + rng.nextDouble() * 0.26));
      if (!dome.contains(p)) continue;
      canvas.drawOval(Rect.fromCenter(center: p, width: w * 0.05, height: w * 0.035), Paint()..color = const Color(0xFF3A1A0A));
    }
    for (var i = 0; i < 14; i++) {
      final p = Offset(base.dx + (rng.nextDouble() - 0.5) * w * 0.8, top - w * (rng.nextDouble() * 0.3));
      if (!dome.contains(p)) continue;
      canvas.drawCircle(p, max(0.5, w * 0.012), Paint()..color = Colors.white.withValues(alpha: 0.8));
    }
    canvas.drawPath(dome, ink);
  }

  void _torrone(Canvas canvas, Offset c, double w, double angle) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(angle);
    final ink = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(0.7, w * 0.04)
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFF2A1608);
    final len = w * 1.5, deep = w * 0.48, tall = w * 0.30;
    canvas.drawRect(Rect.fromLTWH(-len / 2 + w * 0.06, -deep / 2 + w * 0.1, len, deep + tall), Paint()
      ..color = Colors.black.withValues(alpha: 0.4)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.05));
    final topFace = Rect.fromLTWH(-len / 2, -deep / 2, len, deep);
    final front = Rect.fromLTWH(-len / 2, deep / 2, len, tall);
    canvas.drawRect(front, Paint()..color = const Color(0xFFD9CBA6));
    canvas.drawRect(topFace, Paint()..color = const Color(0xFFF4ECD8));
    final rng = Random(3);
    for (var i = 0; i < 7; i++) {
      final p = Offset(-len / 2 + len * (0.08 + 0.84 * rng.nextDouble()), -deep / 2 + deep * (0.2 + 0.6 * rng.nextDouble()));
      canvas.drawOval(Rect.fromCenter(center: p, width: w * 0.16, height: w * 0.09), Paint()..color = const Color(0xFFC08A4E));
    }
    // L'ostia ai bordi, e la carta rossa e oro su un capo.
    canvas.drawRect(Rect.fromLTWH(-len / 2, -deep / 2, len, w * 0.05), Paint()..color = const Color(0xFFFFFAEE));
    final wrap = Rect.fromLTRB(len * 0.12, -deep / 2 - w * 0.03, len / 2 + w * 0.03, deep / 2 + tall + w * 0.02);
    canvas.drawRect(wrap, Paint()..color = const Color(0xFFB3121C));
    canvas.drawRect(Rect.fromLTWH(wrap.left, wrap.top, w * 0.07, wrap.height), Paint()..color = _C.gold);
    canvas.drawRect(topFace, ink);
    canvas.drawRect(front, ink);
    canvas.drawRect(wrap, ink);
    canvas.restore();
  }

  /// La luna dalla finestra: un riquadro freddo a croce sul panno.
  void _moonlight(Canvas canvas) {
    final from = felt.topLeft + Offset(felt.width * 0.08, felt.height * 0.06);
    final w = felt.width * 0.40, h = felt.height * 0.36;
    final skew = w * 0.35;
    Path pane(double x0, double y0, double x1, double y1) {
      Offset p(double u, double v) => from + Offset(u * w + v * skew, v * h);
      return Path()
        ..moveTo(p(x0, y0).dx, p(x0, y0).dy)
        ..lineTo(p(x1, y0).dx, p(x1, y0).dy)
        ..lineTo(p(x1, y1).dx, p(x1, y1).dy)
        ..lineTo(p(x0, y1).dx, p(x0, y1).dy)
        ..close();
    }

    final glow = Paint()
      ..color = const Color(0xFFA8C0F0).withValues(alpha: 0.22)
      ..blendMode = BlendMode.screen
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, felt.shortestSide * 0.012);
    const bar = 0.05;
    for (final (x0, x1) in [(0.0, 0.5 - bar), (0.5 + bar, 1.0)]) {
      for (final (y0, y1) in [(0.0, 0.5 - bar), (0.5 + bar, 1.0)]) {
        canvas.drawPath(pane(x0, y0, x1, y1), glow);
      }
    }
  }

  /// Il coltello sul panno, col nastrino rosso di Natale legato all'elsa.
  void _knife(Canvas canvas, double unit) {
    // Sotto le parole del panno, dove il cenone mette il panettone.
    final below = Rect.fromLTRB(area.left, area.center.dy + area.height * 0.22, area.right, area.bottom);
    final len = min(area.width * 0.42, (felt.shortestSide * 0.38).clamp(60.0, 230.0));
    const angle = -0.30;
    final dir = Offset(cos(angle), sin(angle));
    final at = Offset(below.center.dx, below.center.dy + below.height * 0.10) - dir * len * 0.16;
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(angle);
    final ink = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(0.8, len * 0.012)
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFF0A0A0C);
    final blade = Path()
      ..moveTo(0, -len * 0.030)
      ..lineTo(len * 0.62, 0)
      ..lineTo(0, len * 0.030)
      ..close();
    final handle = RRect.fromRectAndRadius(Rect.fromLTRB(-len * 0.30, -len * 0.026, -len * 0.02, len * 0.026), Radius.circular(len * 0.02));
    // L'ombra sul panno, in basso a destra come la luce della lampada.
    canvas.save();
    canvas.translate(len * 0.02, len * 0.035);
    final shade = Paint()
      ..color = Colors.black.withValues(alpha: 0.45)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, len * 0.015);
    canvas.drawPath(blade, shade);
    canvas.drawRRect(handle, shade);
    canvas.restore();
    canvas.drawPath(
      blade,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFEFF3F6), Color(0xFF9AA6B2), Color(0xFF55606C)],
        ).createShader(Rect.fromLTRB(0, -len * 0.03, len * 0.62, len * 0.03)),
    );
    canvas.drawLine(Offset(len * 0.02, 0), Offset(len * 0.55, 0), Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..strokeWidth = max(0.5, len * 0.005));
    canvas.drawPath(blade, ink);
    canvas.drawRRect(handle, Paint()..color = const Color(0xFF2B1A12));
    for (final x in [-len * 0.24, -len * 0.10]) {
      canvas.drawRect(Rect.fromLTRB(x - len * 0.008, -len * 0.027, x + len * 0.008, len * 0.027), Paint()..color = _C.gold);
    }
    canvas.drawRRect(handle, ink);
    final guard = RRect.fromRectAndRadius(Rect.fromLTRB(-len * 0.022, -len * 0.075, len * 0.004, len * 0.075), Radius.circular(len * 0.01));
    canvas.drawRRect(guard, Paint()..color = const Color(0xFF3A3A42));
    canvas.drawRRect(guard, ink);
    canvas.drawCircle(Offset(-len * 0.31, 0), len * 0.032, Paint()..color = _C.gold);
    canvas.drawCircle(Offset(-len * 0.31, 0), len * 0.032, ink);
    // Il nastrino che gira intorno all'impugnatura, e il fiocco.
    final ribbon = Paint()
      ..strokeWidth = len * 0.016
      ..color = _C.red;
    canvas.drawLine(Offset(-len * 0.07, -len * 0.03), Offset(-len * 0.04, len * 0.03), ribbon);
    canvas.restore();
    final knot = at - dir * len * 0.055;
    _bow(canvas, knot, len * 0.10, tails: 1.1);
  }

  @override
  bool shouldRepaint(_FeltPainter old) =>
      old.look != look || old.felt != felt || old.card != card || old.area != area || old.centers.length != centers.length;
}

/// L'agrifoglio sulla punta destra di ogni targhetta.
class _PlatesPainter extends CustomPainter {
  final List<Offset> centers;
  final double card;

  _PlatesPainter(this.centers, this.card);

  @override
  void paint(Canvas canvas, Size size) {
    final height = card * 1.32;
    final plate = max(20.0, card * 0.27);
    for (final (i, c) in centers.indexed) {
      final right = c.dx + card / 2 + card * 0.08;
      final top = c.dy + height / 2 - plate;
      _holly(canvas, Offset(right - plate * 0.30, top + plate * 0.08), plate * 0.62, i.isEven ? -0.25 : -0.05, leaves: 2);
    }
  }

  @override
  bool shouldRepaint(_PlatesPainter old) => old.card != card || old.centers.length != centers.length;
}
