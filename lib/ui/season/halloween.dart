part of 'season.dart';

/// Le tre prove di Halloween (fino ai Morti, il 2 novembre), sulle stesse
/// schermate del Natale. Per chi gioca si accende quella in
/// [SeasonLooks.picked]; le altre solo in `tool/render/season_render_test.dart`.
enum HalloweenLook implements SeasonLook {
  /// A, «Zucche nel vicolo»: le zucche intagliate sul marciapiede con la
  /// candela dentro, la loro luce arancione sui mattoni, le ragnatele, i
  /// pipistrelli davanti a OBERTÀ; continua a piovere.
  zucche,

  /// B, «Notte dei morti»: un neon viola NOTTE DEI MORTI con una lettera che
  /// sfarfalla, il festone di calendule, i lumini rossi dei cimiteri, il
  /// teschio di zucchero sul panno.
  morti,

  /// C, «Nebbia e pipistrelli»: niente pioggia, la nebbia bassa e fitta, uno
  /// stormo davanti alle insegne, la luna nelle pozzanghere; sul panno solo
  /// una ragnatela. La più trattenuta.
  nebbia;

  @override
  Season get season => Season.halloween;

  @override
  String get key => 'halloween.$name';
}

abstract final class _H {
  static const ink = Color(0xFF0A0604);
  static const pumpkin = Color(0xFFD8661A);
  static const pumpkinDark = Color(0xFF7A300A);
  static const pumpkinLight = Color(0xFFF29A3E);
  static const flame = Color(0xFFFFB347);
  static const flameCore = Color(0xFFFFF0B8);
  static const marigold = Color(0xFFFF8A12);
  static const marigoldDeep = Color(0xFFC94A06);
  static const marigoldLight = Color(0xFFFFC24A);
  static const violet = Color(0xFFB27BFF);
  static const web = Color(0xFFE6E8EE);
}

/// La luce di una candela dentro una zucca o un lumino: calda, bassa, corta.
StreetLight _candleLight(Offset at, double reach, Color color, {double gain = 0.9}) => StreetSignLight(
  band: Rect.fromCircle(center: at, radius: 1),
  reach: reach,
  wash: 0.04,
  spread: reach * 3,
  color: StreetLight.tint(color, gain),
);

// ------------------------------------------------------------- i pezzi

/// Una zucca, poggiata in [base] (il centro del fondo), larga [w]. Intagliata
/// ([face] da 0 a 2: tre facce diverse) ha la candela dentro e la faccia che
/// brucia; la buccia la scurisce la notte ([dark]).
void _pumpkin(Canvas canvas, Offset base, double w, {int? face, double dark = 0.3, double tilt = 0}) {
  final h = w * 0.74;
  final ink = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = max(0.8, w * 0.025)
    ..strokeJoin = StrokeJoin.round
    ..color = _H.ink;
  canvas.drawOval(Rect.fromCenter(center: base + Offset(w * 0.06, 0), width: w * 1.15, height: w * 0.18), Paint()..color = Colors.black.withValues(alpha: 0.55));
  canvas.save();
  canvas.translate(base.dx, base.dy);
  canvas.rotate(tilt);
  final c = Offset(0, -h / 2);
  // Gli spicchi: prima quelli in fondo, poi quello davanti.
  const lobes = [(-0.30, 0.44, 0.0), (0.30, 0.44, 0.0), (-0.15, 0.50, 0.5), (0.15, 0.50, 0.5), (0.0, 0.52, 1.0)];
  for (final (x, width, front) in lobes) {
    final r = Rect.fromCenter(center: c + Offset(x * w, 0), width: width * w, height: h);
    canvas.drawOval(
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.45),
          radius: 0.85,
          colors: [
            _dim(Color.lerp(_H.pumpkin, _H.pumpkinLight, 0.4 + 0.4 * front)!, dark),
            _dim(_H.pumpkin, dark + 0.08 * (1 - front)),
            _dim(_H.pumpkinDark, dark),
          ],
          stops: const [0, 0.55, 1],
        ).createShader(r),
    );
    canvas.drawOval(r, ink..color = _H.ink.withValues(alpha: 0.75));
  }
  final body = Rect.fromCenter(center: c, width: w, height: h);
  canvas.drawOval(body, ink..color = _H.ink);
  // Il picciolo, storto.
  final stem = Path()
    ..moveTo(-w * 0.05, -h * 0.97)
    ..quadraticBezierTo(-w * 0.03, -h * 1.18, w * 0.07, -h * 1.22)
    ..lineTo(w * 0.09, -h * 1.12)
    ..quadraticBezierTo(w * 0.03, -h * 1.10, w * 0.05, -h * 0.96)
    ..close();
  canvas.drawPath(stem, Paint()..color = _dim(const Color(0xFF5A4A1E), dark));
  canvas.drawPath(stem, ink);
  if (face != null) {
    final glow = Rect.fromCircle(center: c + Offset(0, h * 0.05), radius: w * 1.1);
    canvas.drawOval(
      glow,
      Paint()
        ..shader = RadialGradient(colors: [_H.flame.withValues(alpha: 0.42), _H.flame.withValues(alpha: 0.10), _H.flame.withValues(alpha: 0)], stops: const [0, 0.45, 1]).createShader(glow),
    );
    final cut = Path();
    void tri(List<(double, double)> points) {
      cut.moveTo(points.first.$1 * w, points.first.$2 * h);
      for (final (x, y) in points.skip(1)) {
        cut.lineTo(x * w, y * h);
      }
      cut.close();
    }

    switch (face % 3) {
      case 0:
        tri([(-0.30, -0.62), (-0.10, -0.62), (-0.20, -0.82)]);
        tri([(0.10, -0.62), (0.30, -0.62), (0.20, -0.82)]);
        tri([(-0.05, -0.50), (0.05, -0.50), (0.0, -0.60)]);
        tri([(-0.34, -0.38), (-0.22, -0.30), (-0.12, -0.38), (0.0, -0.28), (0.12, -0.38), (0.22, -0.30), (0.34, -0.38), (0.24, -0.18), (0.08, -0.24), (0.0, -0.14), (-0.08, -0.24), (-0.24, -0.18)]);
      case 1:
        tri([(-0.30, -0.70), (-0.08, -0.60), (-0.26, -0.56)]);
        tri([(0.30, -0.70), (0.08, -0.60), (0.26, -0.56)]);
        tri([(-0.30, -0.36), (0.30, -0.36), (0.18, -0.20), (0.06, -0.28), (-0.06, -0.20), (-0.18, -0.28)]);
      default:
        cut.addOval(Rect.fromCenter(center: Offset(-w * 0.17, -h * 0.66), width: w * 0.16, height: h * 0.18));
        cut.addOval(Rect.fromCenter(center: Offset(w * 0.17, -h * 0.66), width: w * 0.16, height: h * 0.18));
        tri([(-0.26, -0.40), (-0.10, -0.34), (0.0, -0.42), (0.10, -0.34), (0.26, -0.40), (0.0, -0.22)]);
    }
    final faceBox = Rect.fromLTRB(-w * 0.4, -h * 0.9, w * 0.4, -h * 0.1);
    canvas.drawPath(cut, Paint()..color = const Color(0xFF3A1404));
    canvas.drawPath(
      cut.shift(Offset(w * 0.012, h * 0.02)),
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, 0.25),
          colors: const [_H.flameCore, _H.flame, Color(0xFFE0601A)],
          stops: const [0, 0.5, 1],
        ).createShader(faceBox),
    );
  } else {
    // Le coste che scendono dal picciolo.
    for (final x in [-0.22, -0.07, 0.07, 0.22]) {
      canvas.drawPath(
        Path()
          ..moveTo(x * w * 0.4, -h * 0.94)
          ..quadraticBezierTo(x * w * 1.6, -h * 0.5, x * w * 0.6, -h * 0.05),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(0.6, w * 0.018)
          ..color = _dim(_H.pumpkinDark, dark).withValues(alpha: 0.7),
      );
    }
  }
  canvas.restore();
}

/// Un lumino da cimitero: il bicchiere rosso, il coperchio d'oro forato, la
/// fiammella dentro.
void _lumino(Canvas canvas, Offset base, double s) {
  final cup = Rect.fromLTRB(base.dx - s * 0.32, base.dy - s, base.dx + s * 0.32, base.dy);
  final glow = Rect.fromCircle(center: cup.center, radius: s * 1.6);
  canvas.drawOval(
    glow,
    Paint()..shader = RadialGradient(colors: [const Color(0x66FF4A2A), const Color(0x00FF4A2A)]).createShader(glow),
  );
  canvas.drawRRect(
    RRect.fromRectAndCorners(cup, bottomLeft: Radius.circular(s * 0.1), bottomRight: Radius.circular(s * 0.1)),
    Paint()
      ..shader = const LinearGradient(colors: [Color(0xFF6A0610), Color(0xFFE8303A), Color(0xFF7A0812)], stops: [0, 0.5, 1]).createShader(cup),
  );
  canvas.drawOval(Rect.fromCenter(center: cup.center + Offset(0, s * 0.1), width: s * 0.3, height: s * 0.45), Paint()..color = const Color(0xCCFFD27A));
  final lid = Rect.fromLTRB(cup.left - s * 0.04, cup.top - s * 0.16, cup.right + s * 0.04, cup.top + s * 0.02);
  canvas.drawRRect(RRect.fromRectAndRadius(lid, Radius.circular(s * 0.06)), Paint()..color = const Color(0xFFC9A227));
  for (final dx in [-0.14, 0.0, 0.14]) {
    canvas.drawCircle(Offset(cup.center.dx + dx * s, lid.center.dy), s * 0.035, Paint()..color = const Color(0xFF5A4510));
  }
  canvas.drawRect(cup, Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = max(0.6, s * 0.04)
    ..color = _H.ink);
}

/// Una calendula: un pompon di petali arancioni.
void _marigold(Canvas canvas, Offset c, double r, {bool yellow = false, double dark = 0}) {
  final outer = _dim(yellow ? _H.marigoldLight : _H.marigold, dark);
  final deep = _dim(_H.marigoldDeep, dark);
  canvas.drawCircle(c, r, Paint()..color = deep);
  final rng = Random((c.dx * 7 + c.dy * 13).round());
  for (var ring = 0; ring < 3; ring++) {
    final rr = r * (0.80 - ring * 0.26);
    final n = 9 - ring * 2;
    for (var i = 0; i < n; i++) {
      final a = i * 2 * pi / n + ring * 0.4 + rng.nextDouble() * 0.2;
      canvas.drawCircle(c + Offset(cos(a), sin(a)) * rr * 0.62, r * (0.30 - ring * 0.04), Paint()..color = Color.lerp(outer, Colors.white, ring * 0.12)!);
    }
  }
  canvas.drawCircle(c, r * 0.16, Paint()..color = deep);
  canvas.drawCircle(c, r, Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = max(0.5, r * 0.08)
    ..color = _H.ink.withValues(alpha: 0.6));
}

/// La ragnatela in un angolo: [corner], i fili verso [from]..[to] (radianti).
void _cobweb(Canvas canvas, Offset corner, double r, double from, double to, {double alpha = 0.42}) {
  final thread = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = max(0.5, r * 0.012)
    ..color = _H.web.withValues(alpha: alpha);
  const spokes = 6;
  final ends = [for (var i = 0; i <= spokes; i++) from + (to - from) * i / spokes];
  for (final a in ends) {
    canvas.drawLine(corner, corner + Offset(cos(a), sin(a)) * r, thread);
  }
  for (var k = 1; k <= 5; k++) {
    final rr = r * k / 5.4;
    final path = Path();
    for (var i = 0; i < ends.length; i++) {
      final p = corner + Offset(cos(ends[i]), sin(ends[i])) * rr;
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        // Il filo tra due raggi pende un poco verso l'angolo.
        final mid = corner + Offset(cos((ends[i] + ends[i - 1]) / 2), sin((ends[i] + ends[i - 1]) / 2)) * rr * 0.86;
        path.quadraticBezierTo(mid.dx, mid.dy, p.dx, p.dy);
      }
    }
    canvas.drawPath(path, thread);
  }
}

/// Un pipistrello in [c], largo [s] ad ali aperte; [flap] da -1 (ali giù) a 1.
void _bat(Canvas canvas, Offset c, double s, double flap, {Color rim = const Color(0x00000000)}) {
  final lift = flap * s * 0.22;
  Path wing(double side) => Path()
    ..moveTo(c.dx + side * s * 0.06, c.dy - s * 0.02)
    ..quadraticBezierTo(c.dx + side * s * 0.26, c.dy - s * 0.16 - lift, c.dx + side * s * 0.50, c.dy - s * 0.06 - lift * 1.4)
    ..quadraticBezierTo(c.dx + side * s * 0.42, c.dy + s * 0.02 - lift * 0.8, c.dx + side * s * 0.36, c.dy + s * 0.08 - lift * 0.6)
    ..quadraticBezierTo(c.dx + side * s * 0.30, c.dy + s * 0.01 - lift * 0.5, c.dx + side * s * 0.24, c.dy + s * 0.09 - lift * 0.4)
    ..quadraticBezierTo(c.dx + side * s * 0.18, c.dy + s * 0.02 - lift * 0.3, c.dx + side * s * 0.12, c.dy + s * 0.09 - lift * 0.2)
    ..quadraticBezierTo(c.dx + side * s * 0.08, c.dy + s * 0.04, c.dx + side * s * 0.04, c.dy + s * 0.06)
    ..close();
  final body = Path()
    ..addOval(Rect.fromCenter(center: c + Offset(0, s * 0.03), width: s * 0.11, height: s * 0.16))
    ..addOval(Rect.fromCenter(center: c - Offset(0, s * 0.06), width: s * 0.09, height: s * 0.08))
    ..moveTo(c.dx - s * 0.04, c.dy - s * 0.08)
    ..lineTo(c.dx - s * 0.035, c.dy - s * 0.14)
    ..lineTo(c.dx - s * 0.01, c.dy - s * 0.09)
    ..moveTo(c.dx + s * 0.04, c.dy - s * 0.08)
    ..lineTo(c.dx + s * 0.035, c.dy - s * 0.14)
    ..lineTo(c.dx + s * 0.01, c.dy - s * 0.09);
  final all = Path()
    ..addPath(wing(-1), Offset.zero)
    ..addPath(wing(1), Offset.zero)
    ..addPath(body, Offset.zero);
  if (rim.a > 0) {
    canvas.drawPath(all.shift(Offset(0, -max(0.6, s * 0.02))), Paint()..color = rim);
  }
  canvas.drawPath(all, Paint()..color = const Color(0xFF050506));
}

/// Una foglia secca d'acero, posata a terra.
void _leaf(Canvas canvas, Offset c, double s, double angle, Color color) {
  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.rotate(angle);
  canvas.scale(1, 0.55);
  final path = Path()..moveTo(0, s * 0.5);
  const tips = [(-0.5, 0.05), (-0.32, -0.12), (-0.28, -0.42), (-0.08, -0.28), (0.0, -0.55), (0.08, -0.28), (0.28, -0.42), (0.32, -0.12), (0.5, 0.05), (0.12, 0.12)];
  for (final (x, y) in tips) {
    path.lineTo(x * s, y * s);
  }
  path.close();
  canvas.drawPath(path, Paint()..color = color);
  canvas.drawLine(Offset(0, s * 0.5), Offset(0, -s * 0.3), Paint()
    ..strokeWidth = max(0.5, s * 0.04)
    ..color = _dim(color, 0.4));
  canvas.restore();
}

/// La luna nelle pozzanghere: un disco pallido rotto dalle increspature.
void _moonPuddle(Canvas canvas, Offset c, double r) {
  final glow = Rect.fromCenter(center: c, width: r * 5, height: r * 1.6);
  canvas.drawOval(glow, Paint()..shader = RadialGradient(colors: [const Color(0x44CFDAF0), const Color(0x00CFDAF0)]).createShader(glow));
  for (var k = 0; k < 6; k++) {
    final y = c.dy - r * 0.35 + k * r * 0.14;
    final half = r * sqrt(max(0.0, 1 - pow((k - 2.5) / 3.0, 2).toDouble())) * (k.isEven ? 1 : 0.8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTRB(c.dx - half + (k.isOdd ? r * 0.1 : 0), y, c.dx + half, y + r * 0.08), Radius.circular(r * 0.04)),
      Paint()..color = const Color(0xFFE4ECF8).withValues(alpha: 0.55 - k * 0.05),
    );
  }
}

/// La nebbia fitta di C: banchi bassi che coprono il marciapiede e salgono
/// sui mattoni.
void _thickFog(Canvas canvas, Size size, double ground, double curb) {
  _fog(canvas, size, ground, curb, strength: 2.4, color: const Color(0xFFB4C2CC));
  final rng = Random(8);
  for (var i = 0; i < 9; i++) {
    final c = Offset(size.width * (i / 8.0) + (rng.nextDouble() - 0.5) * 40, ground - (curb - ground) * (0.2 + rng.nextDouble() * 1.2));
    final r = Rect.fromCenter(center: c, width: size.width * (0.35 + 0.2 * rng.nextDouble()), height: (curb - ground) * (1.4 + rng.nextDouble()));
    canvas.drawOval(r, Paint()..shader = RadialGradient(colors: [const Color(0x30C4D0DA), const Color(0x00C4D0DA)]).createShader(r));
  }
}

/// Il freddo di C a Halloween: un velo verde-grigio, da cimitero.
void _grave(Canvas canvas, Size size, {double strength = 1}) {
  final all = Offset.zero & size;
  canvas.drawRect(
    all,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF0A1A1C).withValues(alpha: 0.36 * strength),
          const Color(0xFF0C1C1A).withValues(alpha: 0.18 * strength),
          const Color(0xFF081414).withValues(alpha: 0.26 * strength),
        ],
        stops: const [0, 0.55, 1],
      ).createShader(all),
  );
}

// ------------------------------------------------------------ l'aria

typedef _Flier = ({Offset at, double size, double speed, double phase, double sway});

/// Quello che vola: i pipistrelli che passano davanti alle insegne (in
/// controluce, col filo del colore della luce dove passano) e, per la
/// nebbia, i banchi che scivolano piano. Un pittore solo.
class _HalloweenAir extends StatefulWidget {
  final List<_Flier> bats;
  final List<StreetLight> lights;
  final Rect? fogBand;

  const _HalloweenAir({ required this.bats, required this.lights, this.fogBand});

  @override
  State<_HalloweenAir> createState() => _HalloweenAirState();
}

class _HalloweenAirState extends State<_HalloweenAir> with SingleTickerProviderStateMixin {
  late final AnimationController _time = AnimationController(vsync: this, duration: const Duration(seconds: 30));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _time
        ..stop()
        ..value = 0;
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
      child: CustomPaint(size: Size.infinite, painter: _AirPainter(_time, widget.bats, widget.lights, widget.fogBand)),
    ),
  );
}

class _AirPainter extends CustomPainter {
  final Animation<double> time;
  final List<_Flier> bats;
  final List<StreetLight> lights;
  final Rect? fogBand;

  _AirPainter(this.time, this.bats, this.lights, this.fogBand) : super(repaint: time);

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    if (fogBand case final band?) {
      // Tre banchi che scivolano, in giri interi: il giro non si vede.
      for (var i = 0; i < 3; i++) {
        final x = ((t * (i + 1) + i * 0.37) % 1.0) * size.width * 1.6 - size.width * 0.3;
        final r = Rect.fromCenter(center: Offset(x, band.center.dy + (i - 1) * band.height * 0.2), width: size.width * 0.9, height: band.height);
        canvas.drawOval(r, Paint()..shader = RadialGradient(colors: [const Color(0x26D0DAE2), const Color(0x00D0DAE2)]).createShader(r));
      }
    }
    final wide = size.width * 1.4;
    for (final bat in bats) {
      // Nel fermo immagine (t = 0) ogni pipistrello sta al suo posto.
      final x = (bat.at.dx + size.width * 0.2 + t * bat.speed * wide) % wide - size.width * 0.2;
      final y = bat.at.dy + sin(2 * pi * (t * 9 + bat.phase)) * bat.sway;
      final flap = sin(2 * pi * (t * 60 * bat.speed + bat.phase));
      final (r, g, b) = _light(Offset(x, y), lights);
      final rim = Color.fromARGB(255, (90 * r).round().clamp(0, 255), (90 * g).round().clamp(0, 255), (90 * b).round().clamp(0, 255));
      _bat(canvas, Offset(x, y), bat.size, flap, rim: rim);
    }
  }

  @override
  bool shouldRepaint(_AirPainter old) => old.time != time || old.fogBand != fogBand || old.bats.length != bats.length;
}

// ------------------------------------------------------------- il vicolo

/// Halloween nel vicolo di casa, con le sue misure.
class HalloweenAlley implements SeasonAlley {
  final HalloweenLook look;
  final HomeAlleyLayout layout;
  final bool desktop;
  final bool canvas;
  final bool signedIn;

  HalloweenAlley(this.look, this.layout, {required this.desktop, required this.canvas, required this.signedIn});

  Size get size => layout.size;

  double get _u => desktop ? 1.8 : 1.0;

  @override
  bool get rain => look == HalloweenLook.zucche;

  /// Le zucche sul marciapiede: dove, quanto grandi, che faccia.
  late final List<(Offset, double, int?)> pumpkins = look != HalloweenLook.zucche
      ? const []
      : () {
          final y = layout.ground + (layout.curb - layout.ground) * 0.42;
          final w = size.width;
          return desktop
              ? [(Offset(w * 0.25, y), 84.0, 0), (Offset(w * 0.305, y + 4), 50.0, null), (Offset(w * 0.64, y), 76.0, 1), (Offset(w * 0.93, y), 66.0, 2)]
              : [(Offset(w * 0.46, y), 50.0, 0), (Offset(w * 0.585, y + 2), 28.0, null), (Offset(w * 0.86, y), 42.0, 2)];
        }();

  /// I lumini dei Morti, in fila lungo il muro.
  late final List<Offset> lumini = look != HalloweenLook.morti
      ? const []
      : [
          for (var i = 0; i < (desktop ? 14 : 7); i++)
            Offset(layout.mainPoster.left + (size.width - 20 - layout.mainPoster.left) * (i + 0.5) / (desktop ? 14 : 7), layout.ground + (layout.curb - layout.ground) * 0.40),
        ];

  /// Il festone di calendule, dove a Natale vanno le lucine.
  late final List<Offset> hooks = () {
    final top = (layout.sign.bottom + layout.mainPoster.top) / 2 - layout.cap * 0.10;
    final left = Offset(layout.lampHead.dx + layout.smoker * 0.06, layout.lampHead.dy - layout.smoker * 0.07);
    final right = size.width + 6;
    final n = max(3, ((right - left.dx) / (desktop ? 230 : 96)).round());
    return [left, for (var i = 1; i <= n; i++) Offset(left.dx + (right - left.dx) * i / n, top - (i.isOdd ? 0 : layout.cap * 0.04))];
  }();

  late final _NeonSign? _sign = look != HalloweenLook.morti
      ? null
      : () {
          final Rect box;
          if (size.width > 700) {
            // Sul PC, tra il lampione e OBERTÀ: mentre si cammina per strada
            // esce di scena con il vicolo, senza restare a metà sul bordo.
            box = Rect.fromLTRB(layout.lampHead.dx + layout.smoker * 0.30, layout.sign.top + layout.cap * 0.35, layout.sign.left - layout.cap * 0.45, layout.sign.bottom + layout.cap * 0.25);
          } else {
            final top = layout.lampHead.dy + layout.smoker * 0.34;
            final bottom = (layout.tutorial?.top ?? top + layout.smoker * 0.6) - 10;
            box = Rect.fromLTRB(layout.lampFoot.dx + layout.smoker * 0.05, top, layout.mainPoster.left - 7, bottom);
          }
          return _NeonSign(box, size.width > 700 ? const ['NOTTE', 'DEI MORTI'] : const ['NOTTE', 'DEI', 'MORTI'], maxCap: layout.cap * 0.40);
        }();

  @override
  late final List<StreetLight> lights = [
    ...layout.lights,
    if (_sign case final sign?) sign.light(_H.violet, size),
    for (final (at, w, face) in pumpkins)
      if (face != null) _candleLight(at - Offset(0, w * _u * 0.4), w * _u * 2.0, const Color(0xFFFF8A2A), gain: 1.3),
    for (final at in lumini) _candleLight(at - Offset(0, 6 * _u), 16 * _u, const Color(0xFFFF3A2A), gain: 0.5),
  ];

  /// I pipistrelli: nel fermo immagine, davanti alle lettere di OBERTÀ.
  List<_Flier> get _bats {
    final s = layout.sign;
    final n = look == HalloweenLook.nebbia ? 2.0 : 1.6;
    return [
      (at: Offset(s.left + s.width * 0.18, s.top + s.height * 0.20), size: 30 * _u * n, speed: 0.30, phase: 0.1, sway: 6),
      (at: Offset(s.left + s.width * 0.47, s.top - s.height * 0.05), size: 22 * _u * n, speed: 0.40, phase: 0.5, sway: 4),
      (at: Offset(s.left + s.width * 0.80, s.top + s.height * 0.45), size: 26 * _u * n, speed: 0.35, phase: 0.8, sway: 5),
      if (look == HalloweenLook.nebbia) ...[
        (at: Offset(s.left + s.width * 0.62, s.top + s.height * 0.32), size: 30 * _u, speed: 0.45, phase: 0.3, sway: 3),
        (at: Offset(size.width * 0.90, (s.bottom + layout.mainPoster.top) / 2 + layout.cap * 0.05), size: 30 * _u, speed: 0.38, phase: 0.7, sway: 4),
        (at: Offset(s.left + s.width * 0.33, s.bottom + layout.cap * 0.1), size: 26 * _u, speed: 0.50, phase: 0.2, sway: 3),
      ],
    ];
  }

  List<(Rect, double)> get _posters {
    final friends = desktop ? Rect.fromLTRB(layout.leftPoster.left, layout.mainPoster.top, layout.leftPoster.right, layout.leftPoster.bottom) : layout.leftPoster;
    final ranked = desktop ? Rect.fromLTRB(layout.rightPoster.left, layout.mainPoster.top, layout.rightPoster.right, layout.rightPoster.bottom) : layout.rightPoster;
    return [if (!desktop) (layout.mainPoster, -0.016), (friends, 0.030), (ranked, -0.038)];
  }

  @override
  Widget get wall => IgnorePointer(child: Baked(child: CustomPaint(painter: _HAlleyWall(this))));

  @override
  Widget? get letters => look == HalloweenLook.morti
      ? null
      : IgnorePointer(child: StreetDrift(depth: 0.25, fade: 0, child: Baked(child: CustomPaint(painter: _HAlleyLetters(this)))));

  @override
  Widget get posters => IgnorePointer(child: StreetDrift(depth: 0.55, child: Baked(child: CustomPaint(painter: _HAlleyPosters(this)))));

  @override
  Widget get front => IgnorePointer(child: Baked(child: CustomPaint(painter: _HAlleyFront(this))));

  @override
  Widget top(Animation<double> intro) => IgnorePointer(
    child: FadeTransition(
      opacity: intro.drive(CurveTween(curve: const Interval(0.13, 0.36, curve: Curves.easeInOut))),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Baked(child: CustomPaint(painter: _HAlleyTop(this))),
          if (look != HalloweenLook.morti)
            _HalloweenAir(
              bats: _bats,
              lights: lights,
              fogBand: look == HalloweenLook.nebbia ? Rect.fromLTRB(0, layout.ground - 40 * _u, size.width, layout.curb + 20 * _u) : null,
            ),
        ],
      ),
    ),
  );
}

class _HAlleyWall extends CustomPainter {
  final HalloweenAlley alley;

  _HAlleyWall(this.alley);

  @override
  void paint(Canvas canvas, Size size) {
    if (alley.look == HalloweenLook.nebbia) _grave(canvas, size);
    if (alley._sign case final sign?) sign.paint(canvas, _H.violet, flicker: (sign.lines.length - 1, sign.lines.last.length - 3));
  }

  @override
  bool shouldRepaint(_HAlleyWall old) => old.alley.look != alley.look || old.alley.layout != alley.layout;
}

class _HAlleyLetters extends CustomPainter {
  final HalloweenAlley alley;

  _HAlleyLetters(this.alley);

  @override
  void paint(Canvas canvas, Size size) {
    final layout = alley.layout;
    final cap = layout.cap;
    final top = layout.sign.top + HomeNeonSign.headroom * cap;
    // La ragnatela tra il palo del telaio e la O, e quella sotto la À.
    _cobweb(canvas, Offset(layout.sign.left - cap * 0.16, top + cap * 0.10), cap * 0.55, -0.05, pi / 2 - 0.25);
    _cobweb(canvas, Offset(layout.sign.right + cap * 0.16, top + cap * 0.92), cap * 0.45, pi + 0.2, pi * 1.5 - 0.1, alpha: 0.32);
  }

  @override
  bool shouldRepaint(_HAlleyLetters old) => old.alley.look != alley.look || old.alley.layout != alley.layout;
}

class _HAlleyPosters extends CustomPainter {
  final HalloweenAlley alley;

  _HAlleyPosters(this.alley);

  @override
  void paint(Canvas canvas, Size size) {
    for (final (i, (rect, tilt)) in alley._posters.indexed) {
      canvas.save();
      canvas.translate(rect.center.dx, rect.center.dy);
      canvas.rotate(tilt);
      canvas.translate(-rect.center.dx, -rect.center.dy);
      if (alley.look == HalloweenLook.nebbia) {
        canvas.drawRect(rect.deflate(1), Paint()..color = const Color(0xFF0C1C1A).withValues(alpha: 0.24));
      }
      if (alley.look == HalloweenLook.zucche && i == 0) {
        _cobweb(canvas, rect.topRight + const Offset(-2, 2), rect.width * 0.22, pi / 2 + 0.15, pi - 0.1);
      }
      if (alley.look == HalloweenLook.morti) {
        final r = alley.desktop ? 13.0 : 7.0;
        for (final (corner, dx) in [(rect.topLeft, 1.0), (rect.topRight, -1.0)]) {
          _marigold(canvas, corner + Offset(dx * r * 1.1, r * 0.9), r, dark: 0.12);
          _marigold(canvas, corner + Offset(dx * r * 2.6, r * 0.5), r * 0.75, yellow: true, dark: 0.12);
        }
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_HAlleyPosters old) => old.alley.look != alley.look || old.alley.layout != alley.layout;
}

class _HAlleyFront extends CustomPainter {
  final HalloweenAlley alley;

  _HAlleyFront(this.alley);

  @override
  void paint(Canvas canvas, Size size) {
    final layout = alley.layout;
    final look = alley.look;
    final u = alley._u;
    if (look == HalloweenLook.zucche) {
      // Le foglie secche sul marciapiede.
      final rng = Random(3);
      const colors = [Color(0xFF7A3A12), Color(0xFF9A5A1A), Color(0xFF5A2A10), Color(0xFF8A4A16)];
      for (var i = 0; i < (alley.desktop ? 26 : 12); i++) {
        final c = Offset(rng.nextDouble() * size.width, layout.ground + (layout.curb - layout.ground) * (0.15 + rng.nextDouble() * 0.6));
        _leaf(canvas, c, (7 + rng.nextDouble() * 5) * u, rng.nextDouble() * 2 * pi, _dim(colors[i % colors.length], 0.25));
      }
      for (final (at, w, face) in alley.pumpkins) {
        _pumpkin(canvas, at, w * u, face: face, dark: face == null ? 0.40 : 0.18, tilt: face == null ? 0.08 : 0);
      }
      _fog(canvas, size, layout.ground, layout.curb, strength: 0.6, color: const Color(0xFFC8B8A8));
    }
    if (look == HalloweenLook.morti) {
      // Il festone di calendule, tra il lampione e il bordo dello schermo.
      final path = _swags(alley.hooks, min(layout.cap * 0.20, (layout.mainPoster.top - layout.sign.bottom) * 0.62 + layout.cap * 0.05));
      canvas.drawPath(path, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1 * u
        ..color = _C.wire);
      var k = 0;
      for (final m in path.computeMetrics()) {
        for (var d = 3.0 * u; d < m.length; d += 7.5 * u) {
          final p = m.getTangentForOffset(d)!.position;
          _marigold(canvas, p + Offset(0, 1.5 * u), (k % 3 == 0 ? 4.6 : 3.8) * u, yellow: k % 4 == 1, dark: 0.15);
          k++;
        }
      }
      for (final at in alley.lumini) {
        _lumino(canvas, at, 11 * u);
      }
    }
    if (look == HalloweenLook.nebbia) {
      _moonPuddle(canvas, Offset(size.width * 0.80, layout.curb + (size.height - layout.curb) * 0.22), 26 * u);
      _thickFog(canvas, size, layout.ground, layout.curb);
    }
  }

  @override
  bool shouldRepaint(_HAlleyFront old) => old.alley.look != alley.look || old.alley.layout != alley.layout;
}

class _HAlleyTop extends CustomPainter {
  final HalloweenAlley alley;

  _HAlleyTop(this.alley);

  @override
  void paint(Canvas canvas, Size size) {
    final layout = alley.layout;
    final u = layout.smoker;
    if (alley.look != HalloweenLook.morti) {
      // La ragnatela nell'angolo tra il palo e il braccio del lampione.
      final corner = Offset(layout.lampFoot.dx + u * 0.02, layout.lampHead.dy + u * 0.16);
      _cobweb(canvas, corner, u * 0.24, -pi / 2 + 0.25, -0.15, alpha: 0.34);
    }
  }

  @override
  bool shouldRepaint(_HAlleyTop old) => old.alley.look != alley.look || old.alley.layout != alley.layout;
}

// ------------------------------------------------------------ la strada

/// Halloween davanti a un locale della strada.
class HalloweenStreet implements SeasonStreet {
  final HalloweenLook look;
  final StreetFacadeLayout layout;
  final StreetSection section;
  final int index;
  final List<StreetLight> before;

  HalloweenStreet(this.look, this.layout, this.section, {required this.index, this.before = const []});

  Size get size => layout.size;

  bool get desk => layout.desk;

  double get _u => layout.door.width / 112;

  late final List<(Offset, double, int?)> pumpkins = look != HalloweenLook.zucche
      ? const []
      : () {
          final d = layout.door;
          final win = layout.window;
          final y = layout.ground + (layout.curb - layout.ground) * 0.40;
          return [
            (Offset(win.left + win.width * 0.16, y), d.width * 0.50, 1),
            (Offset(win.left + win.width * 0.40, y + 2), d.width * 0.30, null),
            (Offset(d.right + d.width * 0.30, y), d.width * 0.42, 0),
          ];
        }();

  late final List<Offset> lumini = look != HalloweenLook.morti
      ? const []
      : [
          for (var i = 0; i < 6; i++) Offset(layout.window.left + layout.window.width * (i + 0.5) / 6, layout.window.bottom + 4),
          for (final f in [-0.30, 1.30]) Offset(layout.door.left + layout.door.width * f, layout.ground + (layout.curb - layout.ground) * 0.38),
        ];

  late final _NeonSign? _sign = look != HalloweenLook.morti
      ? null
      : () {
          final box = desk
              ? Rect.fromLTRB(70, layout.awning.top - 10, layout.awning.left - 60, layout.door.top + layout.door.height * 0.30)
              : Rect.fromLTRB(size.width * 0.10, layout.neon.bottom + 36, size.width * 0.90, layout.awning.top - 60);
          return _NeonSign(box, desk ? const ['NOTTE', 'DEI MORTI'] : const ['NOTTE DEI MORTI'], maxCap: layout.neon.height * (desk ? 0.50 : 0.40));
        }();

  @override
  late final List<StreetLight> lights = [
    ...layout.lightsOf(section),
    if (_sign case final sign?) sign.light(_H.violet, size, gain: 0.8, reach: 1.0),
    for (final (at, w, face) in pumpkins)
      if (face != null) _candleLight(at - Offset(0, w * 0.4), w * 2.6, const Color(0xFFFF8A2A), gain: 1.4),
    for (final at in lumini) _candleLight(at - Offset(0, 6 * _u), 18 * _u, const Color(0xFFFF3A2A), gain: 0.5),
  ];

  late final List<StreetLight> _all = [for (final light in before) light.shift(-size.width), ...lights];

  @override
  Widget get ground => IgnorePointer(child: Baked(child: CustomPaint(painter: _HStreetGround(this))));

  @override
  Widget front({required double door, required bool vignette}) => IgnorePointer(
    child: Stack(
      fit: StackFit.expand,
      children: [
        Baked(child: CustomPaint(painter: _HStreetFront(this))),
        if (vignette) const CustomPaint(painter: StreetVignettePainter()),
      ],
    ),
  );

  @override
  Widget? get air {
    if (look == HalloweenLook.morti) return null;
    final n = layout.neon;
    final big = look == HalloweenLook.nebbia ? 2.0 : 1.6;
    return _HalloweenAir(
      lights: _all,
      bats: [
        (at: Offset(n.left + n.width * 0.15, n.center.dy + n.height * 0.1), size: 28 * _u * big, speed: 0.32, phase: 0.1, sway: 6),
        (at: Offset(n.left + n.width * 0.70, n.top + n.height * 0.05), size: 22 * _u * big, speed: 0.42, phase: 0.6, sway: 4),
        if (look == HalloweenLook.nebbia) ...[
          (at: Offset(n.left + n.width * 0.45, n.bottom + n.height * 0.6), size: 30 * _u, speed: 0.50, phase: 0.3, sway: 3),
          (at: Offset(size.width * 0.72, layout.awning.top - layout.door.height * 0.30), size: 36 * _u, speed: 0.36, phase: 0.9, sway: 5),
        ],
      ],
      fogBand: look == HalloweenLook.nebbia ? Rect.fromLTRB(0, layout.ground - 40 * _u, size.width, layout.curb + 20 * _u) : null,
    );
  }
}

class _HStreetGround extends CustomPainter {
  final HalloweenStreet street;

  _HStreetGround(this.street);

  @override
  void paint(Canvas canvas, Size size) {
    if (street.look == HalloweenLook.nebbia) _grave(canvas, size);
  }

  @override
  bool shouldRepaint(_HStreetGround old) => old.street.look != street.look || old.street.layout != street.layout;
}

class _HStreetFront extends CustomPainter {
  final HalloweenStreet street;

  _HStreetFront(this.street);

  @override
  void paint(Canvas canvas, Size size) {
    final layout = street.layout;
    final look = street.look;
    final u = street._u;
    final win = layout.window;
    final door = layout.door;
    final a = layout.awning;
    if (look != HalloweenLook.morti) {
      _cobweb(canvas, win.topLeft, win.shortestSide * 0.34, 0.05, pi / 2 - 0.05, alpha: 0.38);
      _cobweb(canvas, door.topRight, door.width * 0.40, pi / 2 + 0.1, pi - 0.05, alpha: 0.30);
    }
    if (look == HalloweenLook.zucche) {
      final rng = Random(5);
      const colors = [Color(0xFF7A3A12), Color(0xFF9A5A1A), Color(0xFF5A2A10)];
      for (var i = 0; i < 10; i++) {
        final c = Offset(rng.nextDouble() * size.width, layout.ground + (layout.curb - layout.ground) * (0.15 + rng.nextDouble() * 0.6));
        _leaf(canvas, c, (7 + rng.nextDouble() * 5) * u, rng.nextDouble() * 2 * pi, _dim(colors[i % 3], 0.2));
      }
      // Una zucchina sul davanzale, e quelle sui gradini.
      _pumpkin(canvas, Offset(win.left + win.width * 0.18, win.bottom + 5), 22 * u, dark: 0.45);
      for (final (at, w, face) in street.pumpkins) {
        _pumpkin(canvas, at, w, face: face, dark: face == null ? 0.45 : 0.25, tilt: face == null ? -0.08 : 0);
      }
      _fog(canvas, size, layout.ground, layout.curb, strength: 0.6, color: const Color(0xFFC8B8A8));
    }
    if (look == HalloweenLook.morti) {
      // Il festone di calendule sulla tenda, i lumini sul davanzale e ai lati della porta.
      final swag = _swags([Offset(a.left + 4, a.top + 2), Offset(a.center.dx, a.top + 2), Offset(a.right - 4, a.top + 2)], 9 * u);
      var k = 0;
      for (final m in swag.computeMetrics()) {
        for (var d = 2.0; d < m.length; d += 8 * u) {
          _marigold(canvas, m.getTangentForOffset(d)!.position, (k % 3 == 0 ? 5.2 : 4.4) * u, yellow: k % 4 == 1, dark: 0.1);
          k++;
        }
      }
      for (final at in street.lumini) {
        _lumino(canvas, at, 12 * u);
      }
    }
    if (look == HalloweenLook.nebbia) {
      _moonPuddle(canvas, Offset(size.width * 0.20, layout.curb + (size.height - layout.curb) * 0.40), 34 * u);
      _thickFog(canvas, size, layout.ground, layout.curb);
    }
    if (street._sign case final sign?) {
      sign.paint(canvas, _H.violet, flicker: (sign.lines.length - 1, sign.lines.last.length - 3));
    }
  }

  @override
  bool shouldRepaint(_HStreetFront old) => old.street.look != street.look || old.street.layout != street.layout;
}

// -------------------------------------------------------------- il tavolo

/// La nebbia (C) che entra nella sala e sta bassa sul pavimento.
Widget? _halloweenRoom(HalloweenLook look, {required bool night}) {
  if (look != HalloweenLook.nebbia) return null;
  return Positioned.fill(child: IgnorePointer(child: Baked(child: CustomPaint(painter: _HRoom()))));
}

class _HRoom extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    _grave(canvas, size);
    final rng = Random(4);
    for (var i = 0; i < 8; i++) {
      final c = Offset(size.width * rng.nextDouble(), size.height * (0.45 + 0.5 * rng.nextDouble()));
      final r = Rect.fromCenter(center: c, width: size.width * (0.5 + 0.3 * rng.nextDouble()), height: size.height * 0.10);
      canvas.drawOval(r, Paint()..shader = RadialGradient(colors: [const Color(0x22C4D0DA), const Color(0x00C4D0DA)]).createShader(r));
    }
  }

  @override
  bool shouldRepaint(_HRoom old) => false;
}

Widget _halloweenFelt(HalloweenLook look, {required Rect felt, required List<Offset> centers, required double card, required Rect area}) => Positioned.fill(
  child: IgnorePointer(
    child: Baked(overflow: const EdgeInsets.all(64), child: CustomPaint(painter: _HFelt(look, felt, card, area))),
  ),
);

Widget? _halloweenSeats(HalloweenLook look, {required List<Offset> centers, required double card}) {
  if (look != HalloweenLook.morti) return null;
  return Positioned.fill(child: IgnorePointer(child: Baked(child: CustomPaint(painter: _HPlates(centers, card)))));
}

class _HFelt extends CustomPainter {
  final HalloweenLook look;
  final Rect felt;
  final double card;
  final Rect area;

  _HFelt(this.look, this.felt, this.card, this.area);

  @override
  void paint(Canvas canvas, Size size) {
    // Sotto le parole del panno, mai sopra.
    final below = Rect.fromLTRB(area.left, area.center.dy + area.height * 0.22, area.right, area.bottom);
    final base = Offset(area.center.dx, below.bottom - below.height * 0.10);
    final w = min(below.height * 0.72, area.width * 0.17).clamp(18.0, 124.0);
    switch (look) {
      case HalloweenLook.zucche:
        final pool = Rect.fromCenter(center: base - Offset(0, w * 0.3), width: w * 5, height: w * 2.4);
        canvas.drawOval(pool, Paint()..shader = RadialGradient(colors: [const Color(0x55FF9A3A), const Color(0x00FF9A3A)]).createShader(pool));
        final rng = Random(9);
        for (var i = 0; i < 7; i++) {
          final c = base + Offset((rng.nextDouble() - 0.5) * w * 3.6, (rng.nextDouble() - 0.6) * w * 0.7);
          _leaf(canvas, c, w * (0.22 + 0.1 * rng.nextDouble()), rng.nextDouble() * 2 * pi, [const Color(0xFFB8561A), const Color(0xFF8A3A12), const Color(0xFFD8862A)][i % 3]);
        }
        _pumpkin(canvas, base + Offset(-w * 0.95, w * 0.04), w * 0.52, dark: 0.15, tilt: -0.1);
        _pumpkin(canvas, base + Offset(w * 0.98, w * 0.06), w * 0.42, dark: 0.15, tilt: 0.12);
        _pumpkin(canvas, base, w * 1.05, face: 0, dark: 0.05);
      case HalloweenLook.morti:
        for (final (dx, dy) in [(-1.2, 0.05), (1.2, 0.05), (-0.85, 0.25), (0.85, 0.25)]) {
          _marigold(canvas, base + Offset(dx * w, dy * w), w * 0.13, yellow: dx > 0 == dy > 0.1);
        }
        for (final dx in [-1.0, 1.0]) {
          _lumino(canvas, base + Offset(dx * w * 0.78, -w * 0.02), w * 0.36);
        }
        _calavera(canvas, base, w * 0.92);
      case HalloweenLook.nebbia:
        // La nebbia che sale sul bordo del tavolo, e una candela nera che cola.
        final rng = Random(6);
        for (var i = 0; i < 7; i++) {
          final a = i * 2 * pi / 7 + rng.nextDouble() * 0.4;
          final c = felt.center + Offset(cos(a) * felt.width * 0.52, sin(a) * felt.height * 0.52);
          final r = Rect.fromCenter(center: c, width: felt.width * 0.55, height: felt.height * 0.22);
          canvas.drawOval(r, Paint()..shader = RadialGradient(colors: [const Color(0x2AC4D0DA), const Color(0x00C4D0DA)]).createShader(r));
        }
        _blackCandle(canvas, base, w * 0.9);
        // Una ragnatela nell'angolo del panno, e il ragno appeso al suo filo.
        final r = RRect.fromRectAndRadius(felt, Radius.circular(felt.shortestSide * 0.48));
        final corner = Offset(felt.right - r.trRadiusX * 0.32, felt.top + r.trRadiusY * 0.32);
        _cobweb(canvas, corner, felt.shortestSide * 0.26, pi / 2 + 0.2, pi - 0.2, alpha: 0.30);
        final spider = corner + Offset(-felt.shortestSide * 0.10, felt.shortestSide * 0.16);
        canvas.drawLine(corner + Offset(-felt.shortestSide * 0.10, 0), spider, Paint()
          ..strokeWidth = 0.7
          ..color = _H.web.withValues(alpha: 0.5));
        final s = felt.shortestSide * 0.02;
        for (var i = 0; i < 4; i++) {
          for (final side in [-1.0, 1.0]) {
            final a = -0.9 + i * 0.6;
            canvas.drawPath(
              Path()
                ..moveTo(spider.dx, spider.dy)
                ..quadraticBezierTo(spider.dx + side * s * 1.4, spider.dy + a * s - s, spider.dx + side * s * 2.2, spider.dy + a * s * 1.4 + s * 0.6),
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = max(0.7, s * 0.2)
                ..color = _H.ink,
            );
          }
        }
        canvas.drawOval(Rect.fromCenter(center: spider + Offset(0, s * 0.5), width: s * 1.4, height: s * 1.8), Paint()..color = _H.ink);
        canvas.drawCircle(spider - Offset(0, s * 0.6), s * 0.6, Paint()..color = _H.ink);
    }
  }

  /// Una candela nera mezza consumata, la cera che cola sul piattino di peltro.
  void _blackCandle(Canvas canvas, Offset base, double w) {
    final ink = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(0.8, w * 0.02)
      ..color = _H.ink;
    final dish = Rect.fromCenter(center: base, width: w * 0.95, height: w * 0.28);
    canvas.drawOval(dish.shift(Offset(w * 0.04, w * 0.06)), Paint()
      ..color = Colors.black.withValues(alpha: 0.45)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.04));
    canvas.drawOval(dish, Paint()..shader = const LinearGradient(colors: [Color(0xFF4A4E56), Color(0xFFB8BEC6), Color(0xFF5A5E66)]).createShader(dish));
    canvas.drawOval(dish.deflate(w * 0.06), Paint()..color = const Color(0xFF2A2C32));
    canvas.drawOval(dish, ink);
    // La pozza di cera sul piattino.
    canvas.drawOval(Rect.fromCenter(center: base - Offset(w * 0.04, w * 0.02), width: w * 0.42, height: w * 0.12), Paint()..color = const Color(0xFF16161A));
    final body = Rect.fromLTRB(base.dx - w * 0.11, base.dy - w * 0.62, base.dx + w * 0.11, base.dy - w * 0.03);
    canvas.drawRect(body, Paint()..shader = const LinearGradient(colors: [Color(0xFF060608), Color(0xFF34343C), Color(0xFF0A0A0E)], stops: [0, 0.4, 1]).createShader(body));
    for (final (x, len) in [(-0.07, 0.22), (0.03, 0.12), (0.08, 0.30)]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(base.dx + x * w - w * 0.025, body.top, w * 0.05, w * len), Radius.circular(w * 0.025)),
        Paint()..color = const Color(0xFF1E1E24),
      );
    }
    canvas.drawOval(Rect.fromCenter(center: Offset(base.dx, body.top), width: w * 0.22, height: w * 0.07), Paint()..color = const Color(0xFF2A2A32));
    canvas.drawRect(body, ink);
    canvas.drawLine(Offset(base.dx, body.top), Offset(base.dx + w * 0.01, body.top - w * 0.07), Paint()
      ..strokeWidth = max(0.8, w * 0.02)
      ..color = const Color(0xFF0A0604));
    final flame = Offset(base.dx + w * 0.012, body.top - w * 0.17);
    final halo = Rect.fromCircle(center: flame, radius: w * 0.9);
    canvas.drawOval(halo, Paint()..shader = RadialGradient(colors: [const Color(0x55E8E4FF), const Color(0x00E8E4FF)]).createShader(halo));
    canvas.drawPath(
      Path()
        ..moveTo(flame.dx, flame.dy - w * 0.13)
        ..quadraticBezierTo(flame.dx + w * 0.06, flame.dy + w * 0.02, flame.dx, flame.dy + w * 0.07)
        ..quadraticBezierTo(flame.dx - w * 0.06, flame.dy + w * 0.02, flame.dx, flame.dy - w * 0.13)
        ..close(),
      Paint()..color = const Color(0xFFF4F0FF),
    );
  }

  /// Il teschio di zucchero dei Morti: bianco, gli occhi a fiore, i denti a
  /// punti, una calendula in fronte.
  void _calavera(Canvas canvas, Offset base, double w) {
    final ink = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(0.8, w * 0.025)
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFF241812);
    final plate = Rect.fromCenter(center: base, width: w * 1.3, height: w * 0.40);
    canvas.drawOval(plate.shift(Offset(w * 0.05, w * 0.08)), Paint()
      ..color = Colors.black.withValues(alpha: 0.45)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.05));
    canvas.drawOval(plate, Paint()..color = const Color(0xFFE9E1D0));
    canvas.drawOval(plate.deflate(w * 0.05), Paint()..color = const Color(0xFFF6F0E4));
    canvas.drawOval(plate, ink);
    final c = base - Offset(0, w * 0.42);
    final skull = Path()
      ..addOval(Rect.fromCenter(center: c - Offset(0, w * 0.06), width: w * 0.70, height: w * 0.62))
      ..addRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: c + Offset(0, w * 0.22), width: w * 0.42, height: w * 0.26), Radius.circular(w * 0.08)));
    final shape = Path.combine(PathOperation.union, Path()..addOval(Rect.fromCenter(center: c - Offset(0, w * 0.06), width: w * 0.70, height: w * 0.62)), Path()..addRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: c + Offset(0, w * 0.22), width: w * 0.42, height: w * 0.26), Radius.circular(w * 0.08))));
    canvas.drawPath(
      shape,
      Paint()
        ..shader = const RadialGradient(center: Alignment(-0.3, -0.4), colors: [Color(0xFFFFFFFF), Color(0xFFEDE6D8), Color(0xFFC9BFAE)], stops: [0, 0.6, 1]).createShader(skull.getBounds()),
    );
    // Gli occhi: un fiore di petali colorati intorno al buio.
    for (final (side, color) in [(-1.0, const Color(0xFFFF5FA2)), (1.0, const Color(0xFF3CC8C8))]) {
      final eye = c + Offset(side * w * 0.15, -w * 0.02);
      for (var i = 0; i < 8; i++) {
        final a = i * pi / 4;
        canvas.drawCircle(eye + Offset(cos(a), sin(a)) * w * 0.10, w * 0.045, Paint()..color = color);
      }
      canvas.drawOval(Rect.fromCenter(center: eye, width: w * 0.15, height: w * 0.16), Paint()..color = const Color(0xFF1A1014));
      canvas.drawCircle(eye - Offset(w * 0.025, w * 0.03), w * 0.018, Paint()..color = Colors.white);
    }
    // Il naso a cuore rovesciato.
    canvas.drawPath(
      Path()
        ..moveTo(c.dx, c.dy + w * 0.16)
        ..quadraticBezierTo(c.dx - w * 0.07, c.dy + w * 0.10, c.dx - w * 0.03, c.dy + w * 0.07)
        ..quadraticBezierTo(c.dx, c.dy + w * 0.09, c.dx + w * 0.03, c.dy + w * 0.07)
        ..quadraticBezierTo(c.dx + w * 0.07, c.dy + w * 0.10, c.dx, c.dy + w * 0.16)
        ..close(),
      Paint()..color = const Color(0xFF1A1014),
    );
    // I denti: una cucitura di punti.
    final mouth = c.dy + w * 0.25;
    canvas.drawLine(Offset(c.dx - w * 0.15, mouth), Offset(c.dx + w * 0.15, mouth), Paint()
      ..strokeWidth = max(0.8, w * 0.02)
      ..color = const Color(0xFF241812));
    for (var i = 0; i < 6; i++) {
      final x = c.dx - w * 0.125 + i * w * 0.05;
      canvas.drawLine(Offset(x, mouth - w * 0.035), Offset(x, mouth + w * 0.035), Paint()
        ..strokeWidth = max(0.6, w * 0.014)
        ..color = const Color(0xFF241812));
    }
    // Gli svolazzi sulle guance e la calendula in fronte.
    for (final side in [-1.0, 1.0]) {
      canvas.drawArc(Rect.fromCircle(center: c + Offset(side * w * 0.25, w * 0.12), radius: w * 0.05), side > 0 ? pi : 0, pi * 1.2, false, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(0.7, w * 0.018)
        ..color = const Color(0xFFFFB21A));
      canvas.drawCircle(c + Offset(side * w * 0.29, w * 0.04), w * 0.016, Paint()..color = const Color(0xFF3CC8C8));
    }
    _marigold(canvas, c - Offset(0, w * 0.24), w * 0.075);
    for (final side in [-1.0, 1.0]) {
      canvas.drawCircle(c + Offset(side * w * 0.10, -w * 0.26), w * 0.022, Paint()..color = const Color(0xFFFF5FA2));
    }
    canvas.drawPath(shape, ink);
  }

  @override
  bool shouldRepaint(_HFelt old) => old.look != look || old.felt != felt || old.card != card || old.area != area;
}

/// Una calendula sulla punta destra di ogni targhetta.
class _HPlates extends CustomPainter {
  final List<Offset> centers;
  final double card;

  _HPlates(this.centers, this.card);

  @override
  void paint(Canvas canvas, Size size) {
    final height = card * 1.32;
    final plate = max(20.0, card * 0.27);
    for (final c in centers) {
      final right = c.dx + card / 2 + card * 0.08;
      final top = c.dy + height / 2 - plate;
      _marigold(canvas, Offset(right - plate * 0.30, top + plate * 0.12), plate * 0.30);
    }
  }

  @override
  bool shouldRepaint(_HPlates old) => old.card != card || old.centers.length != centers.length;
}
