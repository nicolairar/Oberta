import 'dart:math';

import 'package:flutter/material.dart';

import 'home_neon_sign.dart';

double _span(double t, double from, double to) => ((t - from) / (to - from)).clamp(0.0, 1.0);

double _mix(double a, double b, double t) => a + (b - a) * t;

double _smooth(double t) => Curves.easeInOut.transform(t);

/// Le misure del vicolo della schermata iniziale: dove stanno l'insegna, i
/// manifesti, il lampione e l'uomo che fuma. Le calcola una volta sola chi
/// costruisce la schermata, e le usano sia i pittori sia i widget: così
/// carta e mattoni restano allineati su ogni telefono.
class HomeAlleyLayout {
  final Size size;

  /// Le zone dello schermo da lasciare libere (tacca, barra in basso).
  final EdgeInsets safe;

  /// L'angolo in alto a destra, riservato alla targhetta delle impostazioni:
  /// niente altro ci finisce sopra, e se la targhetta manca lì c'è solo muro.
  late final Rect slot;

  /// La targa con il nome del vicolo, in alto a sinistra.
  late final Rect plaque;

  /// La targhetta «Accedi», accanto all'ingranaggio, per chi non è entrato.
  late final Rect signIn;

  /// Il cartellino di chi è entrato, in alto a sinistra al posto della targa.
  late final Rect badge;

  /// L'insegna appesa della bottega: dopo l'accesso al posto della targhetta
  /// «Accedi», alta come il cartellino; prima, stretta tra la targa del
  /// vicolo e «Accedi» (null se lì non ci sta).
  late final Rect shop;
  late final Rect? shopCompact;

  /// L'insegna del barbiere, appesa con le sue catenelle sotto la bottega.
  late final Rect barber;

  /// Il riquadro delle lettere al neon (accento compreso) e la loro altezza.
  late final Rect sign;
  late final double cap;

  /// Dove il muro incontra il marciapiede, e dove il marciapiede finisce
  /// nell'asfalto bagnato.
  late final double ground;
  late final double curb;

  /// Il manifesto di stasera e i due «prossimamente» sotto.
  late final Rect mainPoster;
  late final Rect leftPoster;
  late final Rect rightPoster;

  late final Offset lampFoot;
  late final Offset lampHead;

  /// L'uomo sotto il lampione: dove poggia i piedi e quanto è alto.
  late final Offset smokerFeet;
  late final double smoker;

  /// La striscia in basso dove si batte a macchina la didascalia.
  late final Rect caption;

  HomeAlleyLayout(this.size, this.safe) {
    final w = size.width;
    final h = size.height;
    final top = safe.top;
    final usable = h - top - safe.bottom;

    slot = Rect.fromLTWH(w - 62, top + 4, 50, 50);
    plaque = Rect.fromLTWH(18, top + 12, min(138, w * 0.36), 34);
    final signInWidth = min(112.0, slot.left - 8 - plaque.right - 12);
    signIn = Rect.fromLTWH(slot.left - 8 - signInWidth, slot.center.dy - 17, signInWidth, 34);
    badge = Rect.fromLTWH(12, top + 4, min(196.0, slot.left - 22), 50);
    final shopLeft = max(badge.right + 8, slot.left - 10 - 120);
    shop = Rect.fromLTRB(shopLeft, top + 2, slot.left - 10, top + 54);
    barber = Rect.fromLTRB(shop.left, shop.bottom - 4, shop.right, shop.bottom + 44);
    final compactRight = signIn.left - 6;
    final compactLeft = max(plaque.right + 6, compactRight - 46);
    shopCompact = compactRight - compactLeft >= 34 ? Rect.fromLTRB(compactLeft, top + 6, compactRight, top + 50) : null;

    cap = min((w - 56) / HomeNeonSign.width, usable * 0.118);
    sign = Rect.fromLTWH(
      (w - cap * HomeNeonSign.width) / 2,
      top + 54,
      cap * HomeNeonSign.width,
      cap * HomeNeonSign.height,
    );

    final street = (usable * 0.122).clamp(80.0, 112.0);
    ground = h - safe.bottom - street;
    curb = ground + street * 0.34;

    final zoneTop = sign.bottom + cap * 0.34;
    final zone = ground - 12 - zoneTop;
    final column = w * 0.275;
    final left = column + 2;
    final right = w - 16;
    final gap = zone * 0.035;
    // Il manifesto grande tiene le sue proporzioni; sugli schermi lunghi lo
    // spazio in più va ai due piccoli, che ne hanno bisogno per il testo.
    final mainHeight = ((right - left) * 0.80).clamp(zone * 0.50, zone * 0.58);
    mainPoster = Rect.fromLTRB(left, zoneTop, right, zoneTop + mainHeight);
    final half = (right - left - 10) / 2;
    leftPoster = Rect.fromLTRB(left, mainPoster.bottom + gap, left + half, zoneTop + zone);
    rightPoster = Rect.fromLTRB(right - half, mainPoster.bottom + gap, right, zoneTop + zone);

    smoker = min(zone * 0.40, w * 0.42);
    lampFoot = Offset(column * 0.26, ground + street * 0.20);
    lampHead = Offset(lampFoot.dx + smoker * 0.27, zoneTop + cap * 0.12);
    smokerFeet = Offset(lampFoot.dx + smoker * 0.31, ground + street * 0.25);

    caption = Rect.fromLTRB(20, curb + 2, w - 20, h - safe.bottom - 2);
  }

  /// Quanta luce del lampione arriva in un punto del muro, da 0 a 1: un
  /// cono che scende appena inclinato verso i manifesti.
  double lampLight(Offset point) {
    final v = point - lampHead;
    if (v.dy < -smoker * 0.05) return 0;
    final angle = atan2(v.dx, v.dy) - 0.16;
    final cone = exp(-pow(angle / 0.62, 2).toDouble());
    final reach = v.distance / (smoker * 1.25);
    return cone / (1 + reach * reach);
  }

  /// Quanta luce dell'insegna arriva in un punto del muro, da 0 a 1.
  double neonLight(Offset point) {
    final band = Rect.fromLTRB(sign.left, sign.top + cap * HomeNeonSign.headroom, sign.right, sign.bottom);
    final dx = max(0.0, max(band.left - point.dx, point.dx - band.right));
    final dy = max(0.0, max(band.top - point.dy, point.dy - band.bottom));
    final reach = sqrt(dx * dx + dy * dy) / (cap * 0.60);
    return 1 / (1 + reach * reach);
  }

  @override
  bool operator ==(Object other) => other is HomeAlleyLayout && other.size == size && other.safe == safe;

  @override
  int get hashCode => Object.hash(size, safe);
}

/// Il muro del vicolo e il selciato: tutto quello che non si muove. Ogni
/// mattone prende il colore dalla luce che gli arriva (il rosso dell'insegna,
/// il giallo del lampione), come nelle tavole di un fumetto.
class HomeWallPainter extends CustomPainter {
  final HomeAlleyLayout layout;

  /// Il nome del vicolo, inciso sulla targa. Null quando al suo posto c'è il
  /// cartellino di chi è entrato.
  final String? plaque;

  /// Vero se accanto all'ingranaggio è avvitata la targhetta «Accedi»: i
  /// colpi sul muro le lasciano posto.
  final bool signIn;

  HomeWallPainter(this.layout, {required this.plaque, this.signIn = false});

  static const _mortar = Color(0xFF07070B);

  // La luce si somma canale per canale: notte blu, neon rosso, lampione caldo.
  static const _night = (0.15, 0.20, 0.38);
  static const _neon = (1.05, 0.20, 0.15);
  static const _lamp = (0.92, 0.72, 0.42);

  Color _lit((double, double, double) albedo, Offset point, {double gain = 1}) {
    final neon = layout.neonLight(point) * 0.95;
    final lamp = layout.lampLight(point) * 1.25;
    int channel(double surface, double night, double red, double warm) =>
        (255 * surface * gain * (night + red * neon + warm * lamp)).round().clamp(0, 255);
    return Color.fromARGB(
      255,
      channel(albedo.$1, _night.$1, _neon.$1, _lamp.$1),
      channel(albedo.$2, _night.$2, _neon.$2, _lamp.$2),
      channel(albedo.$3, _night.$3, _neon.$3, _lamp.$3),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.drawRect(Offset.zero & size, Paint()..color = _mortar);
    _bricks(canvas, w);
    _holes(canvas);
    if (plaque case final plaque?) _plaque(canvas, plaque);

    // Lo sporco che sale dal marciapiede.
    final grime = Rect.fromLTRB(0, layout.ground - layout.cap * 0.9, w, layout.ground);
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
    final asphalt = Rect.fromLTRB(0, layout.curb, w, h);
    canvas.drawRect(
      asphalt,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0E1016), Color(0xFF030304)],
        ).createShader(asphalt),
    );
  }

  void _bricks(Canvas canvas, double w) {
    final rng = Random(41);
    final course = max(9.0, layout.cap * 0.185);
    final length = course * 2.55;
    final paint = Paint();
    for (var row = 0, y = layout.ground - course; y > -course; row++, y -= course) {
      final shift = row.isOdd ? length / 2 : 0.0;
      for (var x = -shift; x < w; x += length) {
        final tone = rng.nextDouble();
        final chipped = rng.nextDouble() < 0.04;
        final center = Offset(x + length / 2, y + course / 2);
        final albedo = (0.44 + 0.16 * tone, 0.27 + 0.07 * tone, 0.25 + 0.05 * tone);
        final brick = Rect.fromLTWH(x + 0.8, y + 0.8, length - 1.6, course - 1.6);
        paint.color = _lit(albedo, center, gain: chipped ? 0.55 : 1);
        canvas.drawRect(brick, paint);
        // Un filo di luce sul bordo alto dà spessore al mattone.
        paint.color = _lit(albedo, center, gain: 1.45);
        canvas.drawRect(Rect.fromLTWH(brick.left, brick.top, brick.width, 1), paint);
      }
    }
  }

  /// La raffica che ha mancato qualcuno, tanto tempo fa.
  void _holes(Canvas canvas) {
    final r = layout.cap * 0.045;
    final from = plaque == null ? Offset(layout.badge.right, layout.plaque.center.dy) : layout.plaque.centerRight;
    final room = (signIn ? layout.signIn.left : layout.slot.left) - from.dx - 14;
    final crack = Paint()
      ..color = Colors.black.withValues(alpha: 0.7)
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    final rng = Random(5);
    // Dove il muro è stretto (la targhetta «Accedi» è avvitata lì) i colpi
    // sono due, non quattro ammucchiati.
    final burst = room > r * 40
        ? const [(0.16, -0.20), (0.40, 0.14), (0.66, -0.06), (0.92, 0.26)]
        : const [(0.30, -0.16), (0.82, 0.20)];
    for (final (along, drop) in burst) {
      final center = from + Offset(room * along, layout.plaque.height * drop);
      canvas.drawCircle(center, r * 2.0, Paint()..color = _lit((0.62, 0.50, 0.46), center));
      for (var i = 0; i < 5; i++) {
        final angle = rng.nextDouble() * 2 * pi;
        final reach = r * (2.4 + rng.nextDouble() * 2.2);
        canvas.drawLine(center, center + Offset(cos(angle), sin(angle)) * reach, crack);
      }
      canvas.drawCircle(center, r * 1.15, Paint()..color = const Color(0xFF020203));
    }
  }

  /// La targa di marmo con il nome del vicolo, come agli angoli delle strade.
  void _plaque(Canvas canvas, String plaque) {
    final plate = layout.plaque;
    final marble = _lit((0.86, 0.84, 0.76), plate.center, gain: 1.25);
    final ink = _lit((0.10, 0.09, 0.09), plate.center);
    final shape = RRect.fromRectAndRadius(plate, const Radius.circular(3));
    canvas.drawRRect(shape.shift(const Offset(1.5, 2.5)), Paint()..color = Colors.black.withValues(alpha: 0.6));
    canvas.drawRRect(shape, Paint()..color = marble);
    canvas.drawRRect(
      shape.deflate(3),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = ink,
    );
    for (final x in [plate.left + 7, plate.right - 7]) {
      canvas.drawCircle(Offset(x, plate.center.dy), 1.6, Paint()..color = ink);
    }
    final text = TextPainter(
      text: TextSpan(
        text: plaque,
        style: TextStyle(
          fontFamily: 'Georgia',
          fontFamilyFallback: const ['serif'],
          fontSize: 9.5,
          height: 1.15,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
          color: ink,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 2,
    )..layout(maxWidth: plate.width - 26);
    text.paint(canvas, plate.center - Offset(text.width / 2, text.height / 2));
    // Un colpo ha preso anche lei.
    final hit = plate.bottomRight - Offset(plate.width * 0.13, plate.height * 0.22);
    canvas.drawCircle(hit, 3.4, Paint()..color = Colors.black.withValues(alpha: 0.35));
    canvas.drawCircle(hit, 2.2, Paint()..color = const Color(0xFF020203));
  }

  void _pavement(Canvas canvas, double w) {
    final slab = layout.smoker * 0.42;
    final paint = Paint();
    final depth = layout.curb - layout.ground;
    for (var x = -slab * 0.3; x < w; x += slab) {
      final center = Offset(x + slab / 2, layout.ground - layout.smoker * 0.15);
      paint.color = _lit((0.50, 0.50, 0.54), center, gain: 0.8);
      canvas.drawRect(Rect.fromLTWH(x + 0.8, layout.ground, slab - 1.6, depth * 0.78), paint);
      paint.color = _lit((0.50, 0.50, 0.54), center, gain: 0.42);
      canvas.drawRect(Rect.fromLTWH(x + 0.8, layout.ground + depth * 0.78, slab - 1.6, depth * 0.22), paint);
    }
    canvas.drawRect(Rect.fromLTWH(0, layout.ground, w, 1.2), Paint()..color = Colors.white.withValues(alpha: 0.10));
  }

  @override
  bool shouldRepaint(HomeWallPainter old) => old.layout != layout || old.plaque != plaque || old.signIn != signIn;
}

/// Tutto quello che nel vicolo si muove, davanti ai manifesti: la luce del
/// lampione, l'uomo che fuma, i riflessi sull'asfalto, il gatto, i fari di
/// una berlina che passa, la pioggia.
class HomeStreetPainter extends CustomPainter {
  final HomeAlleyLayout layout;

  /// Il giro d'ambiente, da 0 a 1 in [loop] secondi, e l'apertura della
  /// schermata, da 0 a 1 in [opening] secondi.
  final Animation<double> ambient;
  final Animation<double> intro;
  final HomeNeonState neon;

  HomeStreetPainter({required this.layout, required this.ambient, required this.intro, required this.neon})
    : super(repaint: Listenable.merge([ambient, intro, neon]));

  static const loop = 60.0;
  static const opening = 3.0;

  static const _ink = Color(0xFF050506);
  static const _rim = Color(0xFF7A6338);
  static const _warm = Color(0xFFFFD27A);
  static const _red = Color(0xFFFF2E24);

  // Quando l'uomo porta la sigaretta alla bocca, in secondi del giro.
  static const _drags = [10.0, 18.5, 27.0, 35.0, 45.0, 55.0];

  // Quando passa una berlina: secondo d'inizio, durata, verso.
  static const _cars = [(21.0, 2.3, 1), (50.6, 2.0, -1)];

  double get _seconds => ambient.value * loop;

  /// Ogni moto fa un numero intero di giri, così quando il ciclo ricomincia
  /// non si vede lo scatto.
  double _wave(double turns, [double offset = 0]) => sin(2 * pi * (ambient.value * turns + offset));

  /// Il lampione che si accende a singhiozzo quando si apre la schermata.
  double get _lampPower {
    const stutter = [0.8, 0.0, 0.5, 0.0, 1.0, 0.6];
    final since = intro.value * opening - 0.40;
    if (since < 0) return 0;
    final step = (since * 14).floor();
    return step < stutter.length ? stutter[step] : 1;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final lamp = _lampPower;
    _lampLight(canvas, size, lamp);
    _reflections(canvas, size, lamp);
    _headlights(canvas, size);
    _cat(canvas, size);
    _lampPost(canvas, lamp);
    _drip(canvas, lamp);
    _smoker(canvas, lamp);
    _rain(canvas, size);

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
    final dark = 1 - _smooth(_span(intro.value * opening, 0, 0.7));
    if (dark > 0) canvas.drawRect(rect, Paint()..color = Colors.black.withValues(alpha: dark));
  }

  // ------------------------------------------------------------------ la luce

  (Offset, Offset) get _coneFeet {
    final head = layout.lampHead;
    final floor = layout.curb;
    return (Offset(head.dx - layout.smoker * 0.50, floor), Offset(head.dx + layout.smoker * 0.92, floor));
  }

  bool _inCone(Offset point) {
    final head = layout.lampHead;
    final (left, right) = _coneFeet;
    final down = (point.dy - head.dy) / (left.dy - head.dy);
    if (down < 0 || down > 1) return false;
    return point.dx > _mix(head.dx, left.dx, down) && point.dx < _mix(head.dx, right.dx, down);
  }

  void _lampLight(Canvas canvas, Size size, double lamp) {
    final u = layout.smoker;
    final head = layout.lampHead;
    final (left, right) = _coneFeet;

    // I mattoni sono dipinti già illuminati: a lampione spento, buio sopra.
    if (lamp < 0.98) {
      final center = head + Offset(u * 0.25, u * 1.0);
      final bounds = Rect.fromCircle(center: center, radius: u * 2.6);
      canvas.drawRect(
        bounds,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFF05060B).withValues(alpha: 0.82 * (1 - lamp)),
              const Color(0xFF05060B).withValues(alpha: 0.6 * (1 - lamp)),
              const Color(0x0005060B),
            ],
            stops: const [0, 0.55, 1],
          ).createShader(bounds),
      );
    }
    if (lamp < 0.02) return;

    final flicker = lamp * (0.93 + 0.07 * _wave(173));
    canvas.drawPath(
      Path()
        ..moveTo(head.dx - u * 0.04, head.dy)
        ..lineTo(head.dx + u * 0.04, head.dy)
        ..lineTo(right.dx, right.dy)
        ..lineTo(left.dx, left.dy)
        ..close(),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _warm.withValues(alpha: 0.26 * flicker),
            _warm.withValues(alpha: 0.04 * flicker),
          ],
        ).createShader(Rect.fromLTRB(0, head.dy, size.width, left.dy)),
    );
    final pool = Rect.fromCenter(
      center: Offset((left.dx + right.dx) / 2, (layout.ground + layout.curb) / 2),
      width: (right.dx - left.dx) * 1.15,
      height: (layout.curb - layout.ground) * 1.5,
    );
    canvas.drawOval(
      pool,
      Paint()
        ..shader = RadialGradient(
          colors: [
            _warm.withValues(alpha: 0.22 * flicker),
            _warm.withValues(alpha: 0),
          ],
        ).createShader(pool),
    );
  }

  /// L'asfalto bagnato rimanda le luci a strisce tremolanti: una colonna
  /// rossa sotto ogni lettera accesa, una gialla sotto il lampione.
  void _reflections(Canvas canvas, Size size, double lamp) {
    final cap = layout.cap;
    final top = layout.curb + 2;
    final depth = size.height - top;
    const dashes = 11;
    final paint = Paint();

    void column(double x, double width, Color color, double strength, int seed) {
      if (strength < 0.02) return;
      for (var k = 0; k < dashes; k++) {
        final far = k / dashes;
        final sway = _wave(7 + (seed + k) % 5, seed * 0.37 + k * 0.21) * width * 0.10;
        paint.color = color.withValues(alpha: strength * pow(1 - far, 1.6));
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(x + sway, top + depth * (far + 0.5 / dashes)),
              width: width * (1 - 0.35 * far) * (k.isEven ? 1 : 0.72),
              height: depth / dashes * 0.42,
            ),
            const Radius.circular(3),
          ),
          paint,
        );
      }
    }

    // Sotto, un bagliore continuo che si perde nel buio; sopra, i trattini
    // che tremano.
    void pool(double x, double width, Color color, double strength) {
      final bounds = Rect.fromCenter(center: Offset(x, top), width: width, height: depth * 2.3);
      canvas.drawOval(
        bounds,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: strength),
              color.withValues(alpha: 0),
            ],
          ).createShader(bounds),
      );
    }

    canvas.save();
    canvas.clipRect(Rect.fromLTRB(0, top - 2, size.width, size.height));
    pool(layout.sign.center.dx, layout.sign.width * 1.35, _red, 0.30 * neon.glow);
    pool(layout.lampHead.dx, layout.smoker * 1.3, _warm, 0.22 * lamp);
    canvas.restore();
    for (var i = 0; i < HomeNeonSign.letters; i++) {
      final width = HomeNeonSign.widthOf(i) * cap;
      column(layout.sign.left + HomeNeonSign.leftOf(i) * cap + width / 2, width, _red, 0.55 * neon.light(i), i);
    }
    column(layout.lampHead.dx, layout.smoker * 0.34, _warm, 0.42 * lamp, 9);

    // Le pozzanghere, con i cerchi delle gocce che cadono.
    final rng = Random(17);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 0; i < 12; i++) {
      final center = Offset(
        rng.nextDouble() * size.width,
        layout.ground + rng.nextDouble() * (size.height - layout.ground),
      );
      final life = (ambient.value * (41 + rng.nextInt(20)) + rng.nextDouble()) % 1;
      final reach = 3 + 13 * life;
      ring.color = Colors.white.withValues(alpha: 0.22 * (1 - life));
      canvas.drawOval(Rect.fromCenter(center: center, width: reach * 2, height: reach * 0.62), ring);
    }
  }

  /// I fari di una berlina che passa in fondo al vicolo: due lame di luce
  /// che spazzano il muro e per un attimo scoprono tutto.
  void _headlights(Canvas canvas, Size size) {
    for (final (start, length, way) in _cars) {
      final pass = (_seconds - start) / length;
      if (pass <= 0 || pass >= 1) continue;
      final w = size.width;
      final along = way > 0 ? pass : 1 - pass;
      final swell = sin(pi * pass);
      canvas.save();
      canvas.transform(Matrix4.skewX(-0.22 * way).storage);
      for (final lead in [0.0, 0.34]) {
        final x = _mix(-w * 0.9, w * 1.6, along) + w * lead * way + layout.ground * 0.22 * way;
        final beam = Rect.fromLTWH(x, 0, w * 0.30, layout.ground);
        canvas.drawRect(
          beam,
          Paint()
            ..blendMode = BlendMode.plus
            ..shader = LinearGradient(
              colors: [
                const Color(0x00FFF0C8),
                const Color(0xFFFFF0C8).withValues(alpha: 0.30 * swell),
                const Color(0x00FFF0C8),
              ],
            ).createShader(beam),
        );
      }
      canvas.restore();
      final glare = Rect.fromCenter(
        center: Offset(_mix(-w * 0.3, w * 1.3, along), (layout.curb + size.height) / 2),
        width: w * 0.9,
        height: (size.height - layout.curb) * 0.5,
      );
      canvas.drawOval(
        glare,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFFFFF0C8).withValues(alpha: 0.20 * swell),
              const Color(0x00FFF0C8),
            ],
          ).createShader(glare),
      );
    }
  }

  // --------------------------------------------------------------- le sagome

  void _lampPost(Canvas canvas, double lamp) {
    final u = layout.smoker;
    final foot = layout.lampFoot;
    final head = layout.lampHead;
    final shoulder = Offset(foot.dx, head.dy + u * 0.16);
    final iron = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = u * 0.042;
    final arm = Path()
      ..moveTo(foot.dx, foot.dy)
      ..lineTo(shoulder.dx, shoulder.dy)
      ..quadraticBezierTo(foot.dx + u * 0.01, head.dy - u * 0.13, head.dx, head.dy - u * 0.06);

    // Un filo di luce sul fianco del palo, dalla parte dell'insegna.
    canvas.drawPath(
      arm.shift(Offset(u * 0.012, 0)),
      Paint()
        ..color = Color.lerp(_ink, _rim, 0.25 + 0.6 * lamp)!
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = u * 0.042,
    );
    canvas.drawPath(arm, iron);
    final fill = Paint()..color = _ink;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: foot.translate(0, -u * 0.07), width: u * 0.12, height: u * 0.14),
        Radius.circular(u * 0.02),
      ),
      fill,
    );
    canvas.drawRect(Rect.fromCenter(center: foot.translate(0, -u * 0.30), width: u * 0.075, height: u * 0.03), fill);
    // Il cappello della lanterna.
    canvas.drawPath(
      Path()
        ..moveTo(head.dx - u * 0.035, head.dy - u * 0.085)
        ..lineTo(head.dx + u * 0.035, head.dy - u * 0.085)
        ..lineTo(head.dx + u * 0.105, head.dy - u * 0.005)
        ..lineTo(head.dx - u * 0.105, head.dy - u * 0.005)
        ..close(),
      fill,
    );
    if (lamp < 0.02) return;
    final glow = Rect.fromCircle(center: head.translate(0, u * 0.03), radius: u * 0.36);
    canvas.drawOval(
      glow,
      Paint()
        ..shader = RadialGradient(
          colors: [
            _warm.withValues(alpha: 0.55 * lamp),
            _warm.withValues(alpha: 0),
          ],
        ).createShader(glow),
    );
    canvas.drawOval(
      Rect.fromCenter(center: head.translate(0, u * 0.02), width: u * 0.13, height: u * 0.075),
      Paint()..color = Color.lerp(const Color(0xFF3A3020), const Color(0xFFFFF3C4), lamp)!,
    );
  }

  /// La goccia che ogni cinque secondi si stacca dal cappello della
  /// lanterna, cade e si rompe sul marciapiede.
  void _drip(Canvas canvas, double lamp) {
    final u = layout.smoker;
    final from = layout.lampHead.translate(-u * 0.10, -u * 0.002);
    final floor = layout.ground + (layout.curb - layout.ground) * 0.45;
    final life = (ambient.value * 12) % 1;
    final water = Paint()..color = Color.lerp(const Color(0xFF8A8FA0), const Color(0xFFFFE9B8), lamp)!;
    if (life < 0.55) {
      canvas.drawCircle(from.translate(0, u * 0.012 * life), u * 0.006 + u * 0.016 * life, water);
    } else if (life < 0.70) {
      final fall = _span(life, 0.55, 0.70);
      final y = _mix(from.dy, floor, fall * fall);
      canvas.drawLine(
        Offset(from.dx, y - u * 0.05 * fall),
        Offset(from.dx, y),
        water
          ..strokeWidth = u * 0.016
          ..strokeCap = StrokeCap.round,
      );
    } else if (life < 0.86) {
      final burst = _span(life, 0.70, 0.86);
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = water.color.withValues(alpha: 0.8 * (1 - burst));
      canvas.drawOval(
        Rect.fromCenter(center: Offset(from.dx, floor), width: u * 0.22 * burst, height: u * 0.07 * burst),
        ring,
      );
      for (final side in [-1.0, 1.0]) {
        canvas.drawCircle(
          Offset(from.dx + side * u * 0.07 * burst, floor - u * 0.09 * sin(pi * burst)),
          u * 0.008,
          Paint()..color = water.color.withValues(alpha: 1 - burst),
        );
      }
    }
  }

  /// Un arto: più largo all'attaccatura, più stretto in fondo.
  void _limb(Canvas canvas, Offset from, Offset to, double fromRadius, double toRadius, Paint paint) {
    final delta = to - from;
    final length = delta.distance;
    canvas.drawCircle(from, fromRadius, paint);
    canvas.drawCircle(to, toRadius, paint);
    if (length < 0.01) return;
    final side = Offset(-delta.dy, delta.dx) / length;
    canvas.drawPath(
      Path()
        ..moveTo(from.dx + side.dx * fromRadius, from.dy + side.dy * fromRadius)
        ..lineTo(to.dx + side.dx * toRadius, to.dy + side.dy * toRadius)
        ..lineTo(to.dx - side.dx * toRadius, to.dy - side.dy * toRadius)
        ..lineTo(from.dx - side.dx * fromRadius, from.dy - side.dy * fromRadius)
        ..close(),
      paint,
    );
  }

  /// Dove si piega un arto di due pezzi teso tra [from] e [to]: delle due
  /// pieghe possibili sceglie quella più in basso (gomito) o più avanti
  /// (ginocchio).
  Offset _joint(Offset from, Offset to, double upper, double lower, {required bool low}) {
    final delta = to - from;
    final length = max(delta.distance, 0.001);
    final reach = min(length, upper + lower - 0.001);
    final along = delta / length;
    final base = (upper * upper - lower * lower + reach * reach) / (2 * reach);
    final rise = sqrt(max(0.0, upper * upper - base * base));
    final middle = from + along * base;
    final side = Offset(along.dy, -along.dx);
    final a = middle + side * rise;
    final b = middle - side * rise;
    if (low) return a.dy > b.dy ? a : b;
    return a.dx > b.dx ? a : b;
  }

  /// Che cosa sta facendo l'uomo con la sigaretta: quanto ha la mano alla
  /// bocca, quanto arde la brace, e a che punto è la boccata di fumo che ha
  /// appena soffiato (o NaN se non ce n'è).
  (double, double, double) get _smoking {
    final s = _seconds;
    var raised = 0.0;
    var ember = 0.35 + 0.12 * _wave(31);
    var puff = double.nan;
    for (final start in _drags) {
      final local = s - start;
      if (local < 0 || local > 6.5) continue;
      raised = _smooth(_span(local, 0, 0.6)) * (1 - _smooth(_span(local, 1.6, 2.3)));
      ember = max(ember, sin(pi * _span(local, 0.6, 1.7)));
      if (local > 2.0) puff = _span(local, 2.0, 6.5);
    }
    return (raised, ember, puff);
  }

  /// Il fiammifero: una volta a giro, e subito all'apertura, si accende una
  /// sigaretta nuova. Restituisce quanto ha le mani al viso e quanto è viva
  /// la fiamma.
  (double, double) get _match {
    final s = _seconds;
    final cupped = _smooth(_span(s, 1.1, 1.6)) * (1 - _smooth(_span(s, 3.2, 3.9)));
    final rise = _span(s, 1.7, 1.82);
    final fade = 1 - _span(s, 2.6, 3.1);
    final flame = rise * fade * (0.78 + 0.22 * _wave(613));
    return (cupped, flame);
  }

  void _smoker(Canvas canvas, double lamp) {
    final h = layout.smoker;
    final (raised, burning, puff) = _smoking;
    final (cupped, flame) = _match;
    final pose = max(raised, cupped);
    // Tra una sigaretta e l'altra, per un attimo, non c'è brace.
    final alight = _seconds > 2.3 && _seconds < 59.0;
    final ember = alight ? burning : 0.0;

    canvas.save();
    canvas.translate(layout.smokerFeet.dx, layout.smokerFeet.dy);
    canvas.rotate(-0.05);

    final hip = Offset(0, -h * 0.50);
    final lips = hip + Offset(h * 0.112, -h * 0.432);
    final hand = Offset.lerp(hip + Offset(h * 0.170, -h * 0.200), lips + Offset(h * 0.052, h * 0.020), pose)!;
    final butt = Offset.lerp(hand + Offset(h * 0.012, -h * 0.022), lips, pose)!;
    final tip = butt + Offset.lerp(Offset(h * 0.050, -h * 0.062), Offset(h * 0.086, h * 0.008), pose)!;

    void body(Paint paint) {
      void leg(Offset foot) {
        final knee = _joint(hip, foot, h * 0.265, h * 0.265, low: false);
        _limb(canvas, hip, knee, h * 0.058, h * 0.046, paint);
        _limb(canvas, knee, foot.translate(0, -h * 0.03), h * 0.046, h * 0.034, paint);
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTRB(foot.dx - h * 0.04, foot.dy - h * 0.048, foot.dx + h * 0.115, foot.dy),
            topLeft: Radius.circular(h * 0.02),
            topRight: Radius.circular(h * 0.045),
            bottomRight: Radius.circular(h * 0.012),
          ),
          paint,
        );
      }

      leg(Offset(-h * 0.06, 0));
      leg(Offset(h * 0.085, 0));

      canvas.save();
      canvas.translate(hip.dx, hip.dy);
      // Il braccio dietro, con la mano in tasca.
      final back = Offset(-h * 0.035, -h * 0.325);
      final elbow = back + Offset(-h * 0.075, h * 0.165);
      _limb(canvas, back, elbow, h * 0.046, h * 0.038, paint);
      _limb(canvas, elbow, Offset(h * 0.005, -h * 0.045), h * 0.038, h * 0.032, paint);

      // Il soprabito: spalle larghe, vita segnata, la falda che si apre dietro.
      canvas.drawPath(
        Path()
          ..moveTo(-h * 0.145, -h * 0.335)
          ..quadraticBezierTo(-h * 0.10, -h * 0.385, 0, -h * 0.385)
          ..quadraticBezierTo(h * 0.11, -h * 0.385, h * 0.135, -h * 0.325)
          ..quadraticBezierTo(h * 0.16, -h * 0.20, h * 0.11, -h * 0.085)
          ..quadraticBezierTo(h * 0.13, h * 0.08, h * 0.165, h * 0.215)
          ..lineTo(-h * 0.205, h * 0.215)
          ..quadraticBezierTo(-h * 0.15, h * 0.04, -h * 0.115, -h * 0.085)
          ..quadraticBezierTo(-h * 0.17, -h * 0.22, -h * 0.145, -h * 0.335)
          ..close(),
        paint,
      );
      // Il bavero alzato, la testa di profilo, il cappello calato.
      canvas.drawPath(
        Path()
          ..moveTo(-h * 0.07, -h * 0.375)
          ..lineTo(-h * 0.055, -h * 0.435)
          ..lineTo(h * 0.01, -h * 0.385)
          ..lineTo(h * 0.085, -h * 0.425)
          ..lineTo(h * 0.075, -h * 0.365)
          ..close(),
        paint,
      );
      final head = Offset(h * 0.03, -h * 0.485);
      canvas.drawOval(Rect.fromCenter(center: head, width: h * 0.150, height: h * 0.172), paint);
      canvas.drawPath(
        Path()
          ..moveTo(head.dx + h * 0.060, head.dy - h * 0.030)
          ..lineTo(head.dx + h * 0.102, head.dy + h * 0.022)
          ..lineTo(head.dx + h * 0.074, head.dy + h * 0.032)
          ..lineTo(head.dx + h * 0.080, head.dy + h * 0.062)
          ..quadraticBezierTo(head.dx + h * 0.065, head.dy + h * 0.105, head.dx + h * 0.010, head.dy + h * 0.095)
          ..lineTo(head.dx, head.dy)
          ..close(),
        paint,
      );
      canvas.save();
      canvas.translate(head.dx + h * 0.025, head.dy - h * 0.046);
      canvas.rotate(0.16);
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: h * 0.36, height: h * 0.05), paint);
      canvas.restore();
      canvas.drawPath(
        Path()
          ..moveTo(head.dx - h * 0.082, head.dy - h * 0.050)
          ..quadraticBezierTo(head.dx - h * 0.090, head.dy - h * 0.160, head.dx - h * 0.040, head.dy - h * 0.160)
          ..quadraticBezierTo(head.dx + h * 0.010, head.dy - h * 0.130, head.dx + h * 0.055, head.dy - h * 0.165)
          ..quadraticBezierTo(head.dx + h * 0.105, head.dy - h * 0.150, head.dx + h * 0.100, head.dy - h * 0.040)
          ..close(),
        paint,
      );
      canvas.restore();

      // Il braccio davanti, che porta la sigaretta alla bocca.
      final shoulder = hip + Offset(h * 0.035, -h * 0.325);
      final bend = _joint(shoulder, hand, h * 0.185, h * 0.175, low: true);
      _limb(canvas, shoulder, bend, h * 0.046, h * 0.038, paint);
      _limb(canvas, bend, hand, h * 0.038, h * 0.030, paint);
      canvas.drawCircle(hand, h * 0.034, paint);
    }

    // Tre passate: un filo rosso dalla parte dell'insegna, un filo caldo
    // dalla parte del lampione, poi il nero sopra. Sono quei due bordi a
    // staccare la sagoma dal muro.
    canvas.save();
    canvas.translate(h * 0.014, -h * 0.006);
    body(Paint()..color = Color.lerp(_ink, const Color(0xFF9A2226), 0.85 * neon.glow)!);
    canvas.restore();
    canvas.save();
    canvas.translate(-h * 0.016, -h * 0.011);
    body(Paint()..color = Color.lerp(Color.lerp(_ink, _rim, lamp)!, _warm, 0.7 * flame)!);
    canvas.restore();
    body(Paint()..color = _ink);

    // Il nastro del cappello.
    final head = hip + Offset(h * 0.03, -h * 0.485);
    canvas.drawRect(
      Rect.fromLTRB(head.dx - h * 0.084, head.dy - h * 0.082, head.dx + h * 0.102, head.dy - h * 0.058),
      Paint()..color = Color.lerp(_ink, _rim, 0.3 + 0.7 * lamp)!,
    );

    canvas.drawLine(
      butt,
      tip,
      Paint()
        ..color = const Color(0xFFE9E4D8)
        ..strokeWidth = h * 0.015,
    );
    if (flame > 0.02) {
      final fire = tip.translate(h * 0.012, 0);
      final halo = Rect.fromCircle(center: fire, radius: h * 0.62);
      canvas.drawOval(
        halo,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFFFFE2A0).withValues(alpha: 0.62 * flame),
              const Color(0xFFFF9A3B).withValues(alpha: 0.22 * flame),
              const Color(0x00FF9A3B),
            ],
            stops: const [0, 0.35, 1],
          ).createShader(halo),
      );
      final tall = h * 0.085 * flame;
      canvas.drawPath(
        Path()
          ..moveTo(fire.dx, fire.dy - tall)
          ..quadraticBezierTo(fire.dx + h * 0.030, fire.dy - tall * 0.2, fire.dx, fire.dy + h * 0.012)
          ..quadraticBezierTo(fire.dx - h * 0.030, fire.dy - tall * 0.2, fire.dx, fire.dy - tall)
          ..close(),
        Paint()..color = const Color(0xFFFFF3C4),
      );
    }
    if (ember > 0.02) {
      final halo = Rect.fromCircle(center: tip, radius: h * (0.05 + 0.07 * ember));
      canvas.drawOval(
        halo,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFFFF7A3B).withValues(alpha: 0.75 * ember),
              const Color(0x00FF7A3B),
            ],
          ).createShader(halo),
      );
      canvas.drawCircle(tip, h * (0.011 + 0.008 * ember), Paint()..color = const Color(0xFFFF8A4B));
    }
    if (alight) {
      // Il filo di fumo che sale dalla brace.
      final wisp = Path()..moveTo(tip.dx, tip.dy);
      for (var i = 1; i <= 18; i++) {
        final up = i / 18;
        wisp.lineTo(tip.dx + _wave(23, up * 0.9) * h * 0.07 * up + h * 0.05 * up * up, tip.dy - up * h * 0.46);
      }
      canvas.drawPath(
        wisp,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.17)
          ..style = PaintingStyle.stroke
          ..strokeWidth = h * 0.014
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
    if (!puff.isNaN) {
      // La boccata: nuvolette che si allargano e se ne vanno verso la luce.
      for (var i = 0; i < 5; i++) {
        final life = (puff * 1.25 - i * 0.06).clamp(0.0, 1.0);
        if (life <= 0 || life >= 1) continue;
        final drift = Curves.easeOut.transform(life);
        final center =
            lips +
            Offset(h * (0.10 + 0.50 * drift + 0.03 * i), -h * (0.02 + 0.42 * drift * drift + 0.035 * i)) +
            Offset(_wave(11, i * 0.2) * h * 0.02, 0);
        final cloud = Rect.fromCircle(center: center, radius: h * (0.045 + 0.15 * drift));
        canvas.drawOval(
          cloud,
          Paint()
            ..shader = RadialGradient(
              colors: [
                Colors.white.withValues(alpha: 0.20 * (1 - life)),
                const Color(0x00FFFFFF),
              ],
            ).createShader(cloud),
        );
      }
    }
    canvas.restore();
  }

  /// Un gatto nero attraversa il marciapiede, si ferma a guardarti, riparte.
  void _cat(Canvas canvas, Size size) {
    final s = _seconds;
    if (s < 37 || s > 48) return;
    final u = layout.smoker * 0.82;
    final walked = 0.46 * _span(s, 37, 41) + 0.54 * _span(s, 43.6, 48);
    final still = s > 41 && s < 43.6;
    final step = walked * 46;
    final x = _mix(size.width + u * 0.4, -u * 0.5, walked);
    final floor = layout.ground + (layout.curb - layout.ground) * 0.62;
    final y = floor - u * 0.13;
    final ink = Paint()..color = _ink;
    final legs = Paint()
      ..color = _ink
      ..strokeWidth = u * 0.024
      ..strokeCap = StrokeCap.round;

    for (final (dx, phase) in [(-0.10, 0.0), (-0.06, pi), (0.08, pi), (0.12, 0.0)]) {
      canvas.drawLine(
        Offset(x + u * dx, y + u * 0.02),
        Offset(x + u * dx + (still ? 0 : sin(step + phase) * u * 0.04), floor),
        legs,
      );
    }
    // Un filo di luce sulla schiena, poi il nero.
    canvas.drawOval(
      Rect.fromCenter(center: Offset(x, y - u * 0.012), width: u * 0.32, height: u * 0.11),
      Paint()..color = Color.lerp(_ink, _rim, 0.7)!,
    );
    canvas.drawOval(Rect.fromCenter(center: Offset(x, y), width: u * 0.32, height: u * 0.11), ink);
    final head = Offset(x - u * 0.19, y - u * (still ? 0.075 : 0.06));
    canvas.drawCircle(head, u * 0.058, ink);
    for (final dx in [-0.04, 0.03]) {
      canvas.drawPath(
        Path()
          ..moveTo(head.dx + u * (dx - 0.022), head.dy - u * 0.035)
          ..lineTo(head.dx + u * dx, head.dy - u * 0.105)
          ..lineTo(head.dx + u * (dx + 0.022), head.dy - u * 0.035)
          ..close(),
        ink,
      );
    }
    canvas.drawPath(
      Path()
        ..moveTo(x + u * 0.15, y)
        ..quadraticBezierTo(
          x + u * 0.30,
          y - u * 0.02,
          x + u * (0.27 + 0.03 * _wave(47)),
          y - u * (0.24 + 0.03 * _wave(29)),
        ),
      Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = u * 0.028
        ..strokeCap = StrokeCap.round,
    );
    final eye = Paint()..color = const Color(0xFFE8D24A);
    if (still) {
      // Fermo, ti guarda: due occhi gialli, e ogni tanto li chiude.
      final open = _wave(140) > -0.9;
      if (open) {
        canvas.drawCircle(head.translate(-u * 0.024, -u * 0.004), u * 0.013, eye);
        canvas.drawCircle(head.translate(u * 0.022, -u * 0.004), u * 0.013, eye);
      }
    } else {
      canvas.drawCircle(head.translate(-u * 0.025, -u * 0.005), u * 0.011, eye);
    }
  }

  void _rain(Canvas canvas, Size size) {
    final rng = Random(99);
    final paint = Paint()
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    final cold = Colors.white.withValues(alpha: 0.15);
    final lit = _warm.withValues(alpha: 0.42 * _lampPower);
    for (var i = 0; i < 84; i++) {
      final x = rng.nextDouble() * size.width * 1.2;
      final fall = (ambient.value * (70 + rng.nextInt(40)) + rng.nextDouble()) % 1;
      final length = 10 + rng.nextDouble() * 14;
      final top = Offset(x, fall * size.height * 1.2 - size.height * 0.1);
      // Dentro il cono del lampione le gocce si accendono.
      paint.color = _inCone(top) ? lit : cold;
      canvas.drawLine(top, top + Offset(-length * 0.22, length), paint);
    }
  }

  @override
  bool shouldRepaint(HomeStreetPainter old) =>
      old.layout != layout || old.ambient != ambient || old.intro != intro || old.neon != neon;
}

/// La chiusura a iride dei vecchi film: il nero si stringe intorno a un
/// punto finché non resta niente.
class HomeIrisPainter extends CustomPainter {
  final Animation<double> closing;
  final Offset focus;

  HomeIrisPainter({required this.closing, required this.focus}) : super(repaint: closing);

  @override
  void paint(Canvas canvas, Size size) {
    if (closing.value <= 0) return;
    final widest = [
      focus.distance,
      (focus - size.topRight(Offset.zero)).distance,
      (focus - size.bottomLeft(Offset.zero)).distance,
      (focus - size.bottomRight(Offset.zero)).distance,
    ].reduce(max);
    final radius = widest * (1 - Curves.easeInOut.transform(closing.value));
    canvas.drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(Offset.zero & size)
        ..addOval(Rect.fromCircle(center: focus, radius: radius)),
      Paint()..color = Colors.black,
    );
    if (radius > 1) {
      canvas.drawCircle(
        focus,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFFC9A227).withValues(alpha: 0.5),
      );
    }
  }

  @override
  bool shouldRepaint(HomeIrisPainter old) => old.closing != closing || old.focus != focus;
}
