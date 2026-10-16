part of 'death_scene.dart';

// Le coreografie della Famiglia aggiunte dopo: stessa strada, stesso
// lampione, stesse sagome. Cambia solo l'arnese del mestiere.

const _hit = DeathScenePainter.strike;
const _inkF = DeathScenePainter._ink;
const _rimF = DeathScenePainter._rim;
const _bloodF = DeathScenePainter._blood;
const _warmF = DeathScenePainter._warm;
const _steelF = DeathScenePainter._steel;

const _brass = Color(0xFFD9A93B);
const _brassDark = Color(0xFF8C6420);
const _cream = Color(0xFFF4EEDF);
const _rose = Color(0xFFC81E32);
const _leaf = Color(0xFF3E7B3A);

extension _FamilyFilms on DeathScenePainter {
  // ---------------------------------------------------------------- attrezzi

  /// Le righe della velocità dietro a qualcosa che corre verso [dir].
  void _speedLines(
    Canvas canvas,
    Offset at,
    Offset dir, {
    double length = 0.5,
    double spread = 0.08,
    double alpha = 0.35,
  }) {
    if (alpha <= 0) return;
    final back = -dir / max(dir.distance, 0.001);
    final side = Offset(-back.dy, back.dx);
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: alpha)
      ..strokeWidth = _u * 0.010
      ..strokeCap = StrokeCap.round;
    for (final (k, len) in const [(-1.0, 0.7), (0.0, 1.0), (1.0, 0.55)]) {
      final from = at + side * (_u * spread * k) + back * (_u * 0.06);
      canvas.drawLine(from, from + back * (_u * length * len), paint);
    }
  }

  /// Un'onomatopea in più, oltre a quella del colpo: stessa grafica, in un
  /// altro punto della scena.
  void _extraWord(
    Canvas canvas,
    String word,
    Offset at,
    double life, {
    Color fill = const Color(0xFFFFE27A),
    double scale = 1,
  }) {
    if (life <= 0 || life >= 1) return;
    final pop = Curves.easeOutBack.transform(min(1, life / 0.2));
    final fade = 1 - Curves.easeIn.transform(_span(life, 0.6, 1));
    final size = _u * 0.26 * scale;
    TextPainter letters({Paint? outline, Color? color}) => TextPainter(
      text: TextSpan(
        text: word,
        style: TextStyle(
          fontSize: size,
          fontWeight: FontWeight.w900,
          fontStyle: FontStyle.italic,
          foreground: outline,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(0.12);
    canvas.scale(0.45 + 0.55 * pop);
    final edge = letters(
      outline: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size * 0.20
        ..strokeJoin = StrokeJoin.round
        ..color = _inkF.withValues(alpha: fade),
    );
    final origin = Offset(-edge.width / 2, -edge.height / 2);
    edge.paint(canvas, origin);
    letters(color: fill.withValues(alpha: fade)).paint(canvas, origin);
    canvas.restore();
  }

  /// Il botto in faccia, da cartone: una vampata stretta intorno alla
  /// testa, un lampo, un anellino, e subito uno sbuffo di fumo nero.
  void _faceBlast(Canvas canvas, Offset centre, double from) {
    final textures = sprites;
    final boom = _span(t, from - 0.001, from + 0.06);
    if (boom > 0 && boom < 1) {
      if (textures != null) {
        final flare = _span(t, from - 0.001, from + 0.018);
        if (flare < 1 && textures.flashes.isNotEmpty) {
          final frames = textures.flashes;
          ParticleSprites.draw(
            canvas,
            frames[(flare * frames.length).floor().clamp(0, frames.length - 1)],
            centre,
            width: _u * 0.95 * (0.6 + 0.4 * flare),
            height: _u * 0.95 * (0.6 + 0.4 * flare),
            opacity: 1 - flare * 0.3,
          );
        }
        for (final (k, rot, dx, dy, scale) in const [
          (0, 0.0, 0.0, 0.0, 1.0),
          (1, 1.3, -0.10, 0.05, 0.7),
          (2, 2.4, 0.10, -0.04, 0.62),
        ]) {
          final p = _span(t, from + k * 0.005, from + 0.045 + k * 0.006);
          if (p <= 0 || p >= 1) continue;
          final grow = 0.5 + 0.5 * Curves.easeOut.transform(p);
          ParticleSprites.draw(
            canvas,
            textures.explosionAt(p),
            centre + Offset(dx, dy - 0.12 * p) * _u,
            width: _u * 0.80 * scale * grow,
            height: _u * 0.80 * scale * grow,
            opacity: 1 - _span(p, 0.5, 1),
            rotation: rot + p * 0.4,
          );
        }
      } else {
        final grow = Curves.easeOut.transform(boom);
        for (final (scale, color) in [
          (1.0, const Color(0xFFFF6A2B)),
          (0.72, const Color(0xFFFFB13B)),
          (0.42, const Color(0xFFFFF3C4)),
        ]) {
          canvas.drawCircle(
            centre,
            _u * 0.34 * grow * scale,
            Paint()
              ..color = color.withValues(alpha: (1 - boom) * 0.95)
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, _u * 0.03),
          );
        }
      }
    }
    final ring = _span(t, from - 0.001, from + 0.03);
    if (ring > 0 && ring < 1) {
      canvas.drawOval(
        Rect.fromCenter(
          center: centre,
          width: _u * (0.25 + 0.8 * ring),
          height: _u * (0.2 + 0.55 * ring),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _u * 0.03 * (1 - ring)
          ..color = Colors.white.withValues(alpha: 0.7 * (1 - ring)),
      );
    }
    // Lo sbuffo di fumo che sale dalla faccia appena spenta la vampata.
    for (final (k, dx) in const [(0, 0.0), (1, -0.10), (2, 0.11)]) {
      final life = _span(t, from + 0.025 + k * 0.006, from + 0.10 + k * 0.008);
      _puff(
        canvas,
        centre + Offset(dx, -0.05 - 0.30 * life) * _u,
        life,
        size: 0.34 + 0.24 * life,
        color: const Color(0xFF2E2C2A),
      );
    }
  }

  /// Dove arriva la mano di una figura in posa, per agganciarci l'arnese.
  (Offset, Offset) _grip(
    Offset feet, {
    int facing = 1,
    double lean = 0,
    double crouch = 0,
    double arm = 0.08,
    double elbow = 0.2,
    bool back = false,
    bool killer = true,
  }) => _handOf(
    feet: feet,
    facing: facing,
    lean: lean,
    crouch: crouch,
    arm: arm,
    elbow: elbow,
    back: back,
    killer: killer,
  );

  // ----------------------------------------------------------------- bowling

  void _bowlingBall(Canvas canvas, Offset center, double spin) {
    final r = _u * 0.085;
    canvas.drawCircle(
      center.translate(-r * 0.10, -r * 0.08),
      r,
      Paint()..color = _rimF,
    );
    canvas.drawCircle(center, r, Paint()..color = const Color(0xFF6A1628));
    canvas.drawCircle(
      center.translate(r * 0.15, r * 0.15),
      r * 0.82,
      Paint()..color = const Color(0xFF4A0E1C),
    );
    for (final (a, d) in const [(0.0, 0.45), (0.55, 0.45), (0.27, 0.05)]) {
      final hole =
          center + Offset(cos(spin + a), sin(spin + a)) * (r * (d + 0.0));
      canvas.drawCircle(
        d < 0.1
            ? center + Offset(cos(spin + 2.4), sin(spin + 2.4)) * (r * 0.5)
            : hole,
        r * 0.14,
        Paint()..color = _inkF,
      );
    }
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r * 0.72),
      pi * 1.05,
      pi * 0.45,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.16
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.55),
    );
  }

  void _bowling(Canvas canvas) {
    final (walkX, walk, stride) = _entrance();
    final r = _u * 0.085;
    // Il lanciatore esce dall'angolo con la palla al petto, prende la
    // rincorsa, porta il braccio indietro e la accompagna fino a terra.
    final peek = _smooth(_span(t, 0.38, 0.44));
    final out = _smooth(_span(t, 0.44, 0.48));
    final leave = _smooth(_span(t, 0.74, 0.86));
    final bowlerX = _mix(
      _mix(_mix(_hiddenX, _peekX, peek), _cornerX - _u * 0.10, out),
      _hiddenX,
      leave,
    );
    const release = 0.505;
    final back = _smooth(_span(t, 0.48, 0.494));
    final through = Curves.easeIn.transform(_span(t, 0.494, release));
    final cheer = _smooth(_span(t, 0.60, 0.635));
    final rest = _smooth(_span(t, 0.70, 0.74));
    var arm = _mix(_mix(1.25, -1.05, back), 0.55, through);
    var elbow = _mix(_mix(1.55, 0.08, back), 0.12, through);
    var lean = _mix(_mix(0.05, 0.25, back), 0.55, through);
    var crouch = _mix(_mix(0.0, 0.25, back), 0.62, through);
    if (cheer > 0) {
      // Il pugno al cielo: strike.
      arm = _mix(arm, 2.75, cheer);
      elbow = _mix(elbow, 1.25 + 0.25 * sin(t * 260), cheer);
      lean = _mix(lean, -0.06, cheer);
      crouch = _mix(crouch, 0.08, cheer);
    }
    if (rest > 0) {
      arm = _mix(arm, 0.1, rest);
      elbow = _mix(elbow, 0.2, rest);
      lean = _mix(lean, 0.04, rest);
      crouch = _mix(crouch, 0, rest);
    }
    final facing = leave > 0.08 ? 1 : -1;
    final moving =
        (out > 0 && out < 1) ||
        (leave > 0 && leave < 1) ||
        (peek > 0 && peek < 1);
    final feet = Offset(bowlerX, _ground);
    _person(
      canvas,
      feet: feet,
      facing: facing,
      walk: _prowl,
      stride: moving ? 0.8 : 0,
      lean: lean,
      crouch: crouch,
      arm: arm,
      elbow: elbow,
      backArm: _mix(-0.1, -1.2, through) * (1 - cheer),
      killer: true,
    );
    // La palla in mano, finché non parte.
    final (hand, _) = _grip(
      feet,
      facing: facing,
      lean: lean,
      crouch: crouch,
      arm: arm,
      elbow: elbow,
    );
    if (t < release) _bowlingBall(canvas, hand.translate(0, r * 0.55), -t * 3);
    _wall(canvas);

    // La palla: un rimbalzo appena lasciata, poi dritta sulle caviglie;
    // dopo l'urto tira avanti, più piano, e se ne va dall'inquadratura.
    final (releaseHand, _) = _grip(
      Offset(_cornerX - _u * 0.10, _ground),
      facing: -1,
      lean: 0.55,
      crouch: 0.62,
      arm: 0.55,
      elbow: 0.12,
    );
    final contactX = _victimX + _u * 0.16;
    if (t >= release) {
      final roll = _span(t, release, _hit);
      final x = t < _hit
          ? _mix(releaseHand.dx, contactX, roll)
          : contactX - _u * 9.0 * (t - _hit);
      final bounce = _span(t, release, release + 0.014);
      final drop = bounce < 1
          ? _mix(releaseHand.dy + r * 0.55, _ground - r, bounce * bounce)
          : _ground -
                r -
                _u *
                    0.05 *
                    sin(pi * _span(t, release + 0.014, release + 0.024));
      final center = Offset(x, drop);
      if (x > -_u) {
        _speedLines(
          canvas,
          center,
          const Offset(-1, 0),
          length: t < _hit ? 0.45 : 0.30,
          spread: 0.045,
          alpha: 0.4,
        );
        _bowlingBall(canvas, center, -(x - releaseHand.dx) / r);
      }
      if (bounce >= 1 && t < _hit) {
        _dust(
          canvas,
          Offset(releaseHand.dx - _u * 0.05, _ground),
          _span(t, release + 0.008, release + 0.09),
          seed: 91,
          count: 3,
          size: 0.35,
        );
      }
    }

    // La vittima vede arrivare la palla, e poi vola come un birillo: un giro
    // e mezzo in aria, e giù di schiena.
    final flight = _span(t, _hit, _hit + 0.10);
    final notice = _span(t, 0.522, _hit);
    if (flight <= 0) {
      _victim(
        canvas,
        x: walkX,
        walk: walk,
        stride: stride,
        lean: -0.14 * _smooth(notice),
        arm: _mix(0.08, 0.9, _smooth(notice)),
        elbow: _mix(0.2, 1.6, _smooth(notice)),
        smoking: t > 0.37,
      );
      _exclaim(
        canvas,
        Offset(_victimX + _u * 0.05, _ground - _u * 1.40),
        _span(t, 0.522, 0.575),
      );
    } else if (flight < 1) {
      final spin = -2.5 * pi * Curves.easeOut.transform(flight);
      final lift = _u * 0.42 * sin(pi * flight);
      final land = Offset(_victimX - _u * 0.05, _ground);
      final center = Offset(
        _mix(_victimX, land.dx - _u * 0.5, Curves.easeInOut.transform(flight)),
        _mix(
              _ground - _u * 0.5,
              _ground - _u * 0.08,
              Curves.easeIn.transform(flight),
            ) -
            lift,
      );
      final down = Offset(_u * 0.5 * sin(spin), -_u * 0.5 * cos(spin));
      _person(
        canvas,
        feet: center - down,
        tilt: spin,
        crouch: 0.35,
        arm: 2.6,
        elbow: 0.4,
        backArm: -2.3,
        backElbow: 0.3,
        hat: victimHat,
        hatOn: false,
      );
    } else {
      _corpse(canvas, _victimX - _u * 0.05, -1);
    }
    final shins = Offset(_victimX + _u * 0.06, _ground - _u * 0.10);
    _impactBurst(canvas, shins, _span(t, _hit, _hit + 0.06), size: 0.85);
    for (var i = 0; i < 4; i++) {
      final life = _span(t, _hit + 0.005 * i, _hit + 0.12);
      if (life <= 0 || life >= 1) continue;
      final a = -pi / 2 + (i - 1.5) * 0.7;
      _cartoonStar(
        canvas,
        shins + Offset(cos(a), sin(a)) * (_u * (0.15 + 0.55 * life)),
        _u * 0.05 * (1 - life * 0.5),
        life * 8 + i,
        AppColors.gold.withValues(alpha: 1 - life),
      );
    }
    _dust(
      canvas,
      Offset(_victimX - _u * 0.45, _ground),
      _span(t, _hit + 0.10, _hit + 0.26),
      seed: 92,
      size: 0.8,
    );
    _hatOff(canvas, _hit, _hit + 0.24, height: 1.6);
    _droppedCigarette(
      canvas,
      Offset(_victimX + _u * 0.17, _ground - _u * 0.92),
      _span(t, _hit, _hit + 0.07),
    );
    _flash(canvas, _span(t, _hit, _hit + 0.03), strength: 0.35);
  }

  // --------------------------------------------------------------- pescespada

  /// Il pesce spada, impugnato per la coda in [grip] e puntato verso [dir]:
  /// [size] è la lunghezza del corpo, il becco è in più.
  void _swordfishShape(
    Canvas canvas,
    Offset grip,
    Offset dir, {
    double flap = 0,
    double size = 0.5,
  }) {
    final l = _u * size;
    canvas.save();
    canvas.translate(grip.dx, grip.dy);
    canvas.rotate(atan2(dir.dy, dir.dx));
    if (dir.dx < 0) canvas.scale(1, -1);
    final back = Paint()..color = const Color(0xFF2E4A66);
    final belly = Paint()..color = const Color(0xFFB9C8D6);
    final fin = Paint()..color = const Color(0xFF1F3550);
    // La coda a mezzaluna, che sbatte.
    canvas.save();
    canvas.rotate(flap * 0.35);
    canvas.drawPath(
      Path()
        ..moveTo(l * 0.06, 0)
        ..lineTo(-l * 0.16, -l * 0.30)
        ..quadraticBezierTo(-l * 0.07, 0, -l * 0.16, l * 0.30)
        ..close(),
      fin,
    );
    canvas.restore();
    // La pinna dorsale a vela.
    canvas.drawPath(
      Path()
        ..moveTo(l * 0.30, -l * 0.15)
        ..quadraticBezierTo(l * 0.36, -l * 0.46, l * 0.50, -l * 0.40)
        ..quadraticBezierTo(l * 0.62, -l * 0.30, l * 0.74, -l * 0.15)
        ..close(),
      fin,
    );
    // Il corpo: dorso scuro, ventre d'argento.
    final body = Path()
      ..moveTo(l * 0.04, -l * 0.04)
      ..quadraticBezierTo(l * 0.45, -l * 0.24, l * 0.96, -l * 0.07)
      ..lineTo(l * 1.0, 0)
      ..quadraticBezierTo(l * 0.97, l * 0.10, l * 0.88, l * 0.11)
      ..quadraticBezierTo(l * 0.45, l * 0.20, l * 0.04, l * 0.04)
      ..close();
    canvas.drawPath(body, belly);
    canvas.save();
    canvas.clipPath(body);
    canvas.drawRect(Rect.fromLTRB(0, -l * 0.3, l * 1.1, l * 0.02), back);
    canvas.restore();
    // Il becco, lungo e dritto: è quello che fa male.
    canvas.drawPath(
      Path()
        ..moveTo(l * 0.95, -l * 0.065)
        ..lineTo(l * 1.95, -l * 0.012)
        ..lineTo(l * 0.97, l * 0.025)
        ..close(),
      Paint()..color = const Color(0xFF3B4F63),
    );
    canvas.drawLine(
      Offset(l * 1.0, -l * 0.04),
      Offset(l * 1.85, -l * 0.012),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.55)
        ..strokeWidth = l * 0.012,
    );
    // Pinna pettorale, branchia, occhio.
    canvas.drawPath(
      Path()
        ..moveTo(l * 0.70, l * 0.07)
        ..lineTo(l * 0.52, l * 0.26)
        ..lineTo(l * 0.62, l * 0.08)
        ..close(),
      fin,
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset(l * 0.78, 0), radius: l * 0.10),
      -1.0,
      2.0,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = l * 0.018
        ..color = const Color(0xFF16263A),
    );
    canvas.drawCircle(
      Offset(l * 0.89, -l * 0.02),
      l * 0.035,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      Offset(l * 0.895, -l * 0.02),
      l * 0.018,
      Paint()..color = _inkF,
    );
    canvas.restore();
  }

  void _swordfish(Canvas canvas) {
    final (walkX, walk, stride) = _entrance();
    const size = 0.40;
    final reach = _u * size * 1.95;
    final chest = Offset(_victimX + _u * 0.06, _ground - _u * 0.72);
    // Si anima la punta del becco: prima spunta dall'angolo, poi si mette
    // in guardia, prende fiato e affonda; il resto (mani e piedi di chi lo
    // impugna) le va dietro.
    final poke = _smooth(_span(t, 0.30, 0.40));
    final guard = _smooth(_span(t, 0.43, 0.49));
    final coil = _smooth(_span(t, 0.50, 0.535));
    final lunge = Curves.easeIn.transform(_span(t, 0.540, _hit));
    final pull = _smooth(_span(t, 0.60, 0.635));
    final toss = _span(t, 0.66, 0.72);
    final leave = _smooth(_span(t, 0.74, 0.86));
    var tipX = _mix(_cornerX + _u * 0.10, _cornerX - _u * 0.30, poke);
    tipX = _mix(tipX, chest.dx + _u * 0.36, guard);
    tipX = _mix(tipX, chest.dx + _u * 0.48, coil);
    tipX = _mix(tipX, chest.dx - _u * 0.36, lunge);
    tipX = _mix(tipX, chest.dx + _u * 0.04, pull);
    // Sfilato il becco, fa un passo avanti col pesce alzato: così, quando
    // la cinepresa va verso il corpo, chi lancia resta in campo.
    final step = _smooth(_span(t, 0.635, 0.665));
    tipX -= _u * 0.45 * step;
    final lean =
        _mix(_mix(0.0, -0.08, guard) - 0.06 * coil, 0.42, lunge) * (1 - pull) +
        0.04 * pull;
    final crouch =
        _mix(_mix(0.0, 0.25, guard) + 0.08 * coil, 0.45, lunge) * (1 - pull) +
        0.1 * pull;
    final arm = _mix(1.55, 1.70, lunge);
    const elbow = 0.12;
    final (local, _) = _grip(
      Offset.zero,
      facing: -1,
      lean: lean,
      crouch: crouch,
      arm: arm,
      elbow: elbow,
    );
    final fishTip = Offset(
      tipX,
      chest.dy +
          _u * 0.10 * (1 - guard) -
          _u * 0.05 * coil +
          _u * 0.03 * lunge -
          _u * 0.42 * step,
    );
    final handX = fishTip.dx + reach;
    var killerX = handX - local.dx;
    final killerFeet = Offset(killerX, _ground);
    final tossing = toss > 0;
    if (leave > 0) killerX = _mix(killerX, _hiddenX, leave);
    final striding =
        (guard > 0 && guard < 1) ||
        (pull > 0 && pull < 1) ||
        (step > 0 && step < 1) ||
        (leave > 0 && leave < 1);
    final throwArm = tossing
        ? _mix(arm, 2.6, sin(pi * min(1, toss * 1.4)))
        : arm;
    _person(
      canvas,
      feet: Offset(killerX, _ground),
      facing: leave > 0.08 ? 1 : -1,
      walk: _prowl,
      stride: striding ? 0.7 : 0,
      lean: leave > 0 ? 0.04 : lean,
      crouch: leave > 0 ? 0 : crouch,
      arm: leave > 0 ? 0.1 : throwArm,
      elbow: leave > 0 ? 0.2 : elbow,
      backArm: leave > 0 ? -0.1 : arm - 0.15,
      backElbow: 0.25,
      killer: true,
    );
    final (holdHand, _) = _grip(
      killerFeet,
      facing: -1,
      lean: lean,
      crouch: crouch,
      arm: arm,
      elbow: elbow,
    );
    final holdDir = fishTip - holdHand;
    if (!tossing) {
      final hand = holdHand;
      final dir = holdDir;
      final wiggle =
          sin(t * 140) *
          (0.6 * _span(t, 0.40, 0.44) * (1 - guard) + 0.5 * coil * (1 - lunge));
      _swordfishShape(canvas, hand, dir, flap: wiggle, size: size);
    }
    _wall(canvas);

    // Infilzato, resta su un attimo; quando il pesce si sfila, va giù.
    final stuck = _span(t, _hit, 0.62);
    final fall = _span(t, 0.62, 0.72);
    _pool(
      canvas,
      Offset(_victimX - _u * 0.50, _ground + _u * 0.04),
      _smooth(_span(t, 0.70, 0.84)),
    );
    _victim(
      canvas,
      x: walkX,
      walk: walk,
      stride: stride,
      fall: fall,
      lean: stuck > 0 && fall == 0
          ? -0.10 + sin(t * 120) * 0.03
          : -0.05 * guard,
      arm: stuck > 0 ? 1.4 : _mix(0.08, 0.6, guard),
      elbow: stuck > 0 ? 1.4 : _mix(0.2, 1.2, guard),
      smoking: t > 0.37 && t < _hit,
    );
    if (t < _hit) {
      _exclaim(
        canvas,
        Offset(_victimX + _u * 0.02, _ground - _u * 1.40),
        _span(t, 0.44, 0.50),
      );
    }
    _hatOff(canvas, 0.62, 0.80, height: 0.5);
    _droppedCigarette(
      canvas,
      Offset(_victimX + _u * 0.16, _ground - _u * 0.92),
      _span(t, _hit, _hit + 0.07),
    );

    // Il pesce, a lavoro fatto, glielo lasciano addosso: dorme coi pesci.
    if (tossing) {
      // Parte da come lo tiene alzato, e atterra sul corpo, tutto in campo.
      final rest = Offset(_victimX - _u * 0.30, _ground - _u * 0.16);
      final arc = Curves.easeInOut.transform(toss);
      final grip =
          Offset.lerp(holdHand, rest, arc)! -
          Offset(0, _u * 0.55 * sin(pi * toss));
      var held = atan2(holdDir.dy, holdDir.dx);
      if (held < 0) held += 2 * pi;
      final angle = _mix(held, pi * 1.06, arc) + 0.6 * sin(pi * toss);
      final flop = _span(t, 0.76, 0.84);
      _swordfishShape(
        canvas,
        grip,
        Offset(cos(angle), sin(angle)),
        flap: toss < 1 ? sin(t * 90) : sin(flop * 30) * (1 - flop) * 1.5,
        size: size,
      );
      _spray(
        canvas,
        rest.translate(-_u * 0.2, 0),
        _span(t, 0.72, 0.80),
        seed: 95,
        color: const Color(0xFF9FC4E0),
        count: 12,
        reach: 0.6,
      );
    }

    // L'acqua di mare e il sangue, dove il becco entra.
    _spray(
      canvas,
      chest,
      _span(t, _hit, _hit + 0.16),
      seed: 93,
      color: const Color(0xFF9FC4E0),
      count: 14,
      bias: const Offset(0.4, -0.8),
    );
    _spray(canvas, chest, _span(t, _hit, _hit + 0.20), seed: 94, count: 14);
    _spray(
      canvas,
      chest,
      _span(t, 0.60, 0.70),
      seed: 96,
      count: 10,
      bias: const Offset(0.5, -0.4),
      reach: 0.7,
    );
    final glint = _span(t, 0.47, 0.51);
    if (glint > 0 && glint < 1) {
      _sprite(
        canvas,
        sprites?.glint,
        Offset(chest.dx + _u * 0.40, chest.dy - _u * 0.04),
        _u * 0.5 * sin(pi * glint),
        opacity: 1,
      );
    }
    _flash(canvas, _span(t, _hit, _hit + 0.03), strength: 0.3);
  }

  // ------------------------------------------------------------------ arpione

  /// Il fucile da sub: calcio di legno, canna d'acciaio, e (se è carico)
  /// l'arpione che spunta davanti.
  void _harpoonGun(
    Canvas canvas,
    Offset hand,
    Offset along, {
    required bool loaded,
  }) {
    final h = _u * 1.08;
    final across = Offset(-along.dy, along.dx);
    Offset p(double x, double y) => hand + along * (h * x) + across * (h * y);
    final stock = [
      p(-0.20, -0.03),
      p(0.04, -0.028),
      p(0.04, 0.028),
      p(-0.02, 0.03),
      p(-0.04, 0.10),
      p(-0.09, 0.10),
      p(-0.08, 0.035),
      p(-0.20, 0.04),
    ];
    canvas.drawPath(
      Path()..addPolygon(stock, true),
      Paint()..color = const Color(0xFF7A5231),
    );
    canvas.drawLine(
      p(0.0, 0.0),
      p(0.32, 0.0),
      Paint()
        ..color = const Color(0xFF8E959E)
        ..strokeWidth = h * 0.032,
    );
    canvas.drawLine(
      p(0.02, -0.010),
      p(0.31, -0.010),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.5)
        ..strokeWidth = h * 0.007,
    );
    // Il rocchetto della sagola, sotto la canna.
    canvas.drawCircle(
      p(0.10, 0.045),
      h * 0.035,
      Paint()..color = const Color(0xFF3B4048),
    );
    canvas.drawCircle(p(0.10, 0.045), h * 0.018, Paint()..color = _cream);
    if (loaded) _harpoonSpear(canvas, p(0.42, 0.0), along);
  }

  /// L'arpione: asta d'acciaio e punta con le alette, che punta verso [dir].
  void _harpoonSpear(Canvas canvas, Offset tip, Offset dir) {
    final d = dir / max(dir.distance, 0.001);
    final side = Offset(-d.dy, d.dx);
    canvas.drawLine(
      tip - d * (_u * 0.26),
      tip - d * (_u * 0.05),
      Paint()
        ..color = _steelF
        ..strokeWidth = _u * 0.016,
    );
    final head = Path()
      ..addPolygon([
        tip,
        tip - d * (_u * 0.10) + side * (_u * 0.045),
        tip - d * (_u * 0.065),
        tip - d * (_u * 0.10) - side * (_u * 0.045),
      ], true);
    canvas.drawPath(head, Paint()..color = const Color(0xFFE6EAEE));
    canvas.drawPath(
      head,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _u * 0.006
        ..color = _inkF,
    );
  }

  /// La sagola: da [from] a [to], con la pancia che si tende fino a sparire.
  void _rope(Canvas canvas, Offset from, Offset to, double slack) {
    final mid = Offset.lerp(from, to, 0.5)! + Offset(0, _u * 0.35 * slack);
    canvas.drawPath(
      Path()
        ..moveTo(from.dx, from.dy)
        ..quadraticBezierTo(mid.dx, mid.dy, to.dx, to.dy),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _u * 0.012
        ..color = const Color(0xFFD8CBA8),
    );
  }

  void _harpoon(Canvas canvas) {
    final (walkX, walk, stride) = _entrance();
    final peek = _smooth(_span(t, 0.38, 0.45));
    final out = _smooth(_span(t, 0.45, 0.51));
    const fire = 0.538;
    final kick = t < fire ? 0.0 : sin(pi * _span(t, fire, fire + 0.04));
    final heave =
        _smooth(_span(t, 0.595, 0.615)) * (1 - _smooth(_span(t, 0.70, 0.74)));
    // Tirato dentro il pesce, arretra dietro l'angolo col fucile.
    final leave = _smooth(_span(t, 0.74, 0.84));
    final killerX =
        _mix(_mix(_hiddenX, _peekX, peek), _cornerX + _u * 0.10, out) +
        _u * 0.10 * heave +
        _u * 0.95 * leave;
    final lean = 0.08 * out - 0.12 * kick - 0.28 * heave;
    final arm = _mix(1.25, 1.50, out) + 0.25 * kick - 0.5 * heave;
    const elbow = 0.10;
    final feet = Offset(killerX, _ground);
    _person(
      canvas,
      feet: feet,
      facing: -1,
      walk: _prowl,
      stride: (out > 0 && out < 1) || (leave > 0 && leave < 1) ? 0.7 : 0,
      lean: lean,
      crouch: 0.15 * heave,
      arm: arm,
      elbow: elbow,
      backArm: _mix(-0.1, 1.2, out) - 0.4 * heave,
      backElbow: 0.4,
      killer: true,
    );
    final (hand, along) = _grip(
      feet,
      facing: -1,
      lean: lean,
      arm: arm,
      elbow: elbow,
    );
    _harpoonGun(canvas, hand, along, loaded: t < fire);
    final muzzle = hand + along * (_u * 1.08 * 0.32);
    _wall(canvas);

    // L'arpione vola dalla canna al petto; poi la sagola si tende e tira.
    final (aimHand, aimAlong) = _grip(
      Offset(_cornerX + _u * 0.10, _ground),
      facing: -1,
      lean: 0.08,
      arm: 1.5,
      elbow: elbow,
    );
    final launch = aimHand + aimAlong * (_u * 1.08 * 0.42);
    final chest = Offset(_victimX + _u * 0.10, _ground - _u * 0.74);
    final topple = _span(t, 0.605, 0.635);
    final drag = Curves.easeIn.transform(_span(t, 0.635, 0.70));
    final dragFeet = _mix(_victimX + _u * 0.05, _cornerX + _u * 0.30, drag);
    // Dove è piantato l'arpione, mentre il corpo va giù e viene trascinato.
    final Offset stuck;
    if (topple <= 0) {
      stuck = chest + Offset(-_u * 0.04 * kick, 0);
    } else if (topple < 1) {
      final a = pi / 2 * Curves.easeIn.transform(topple);
      stuck = Offset(
        _victimX + _u * 0.05 + sin(a) * _u * 0.74,
        _ground - cos(a) * _u * 0.74,
      );
    } else {
      stuck = Offset(dragFeet + _u * 0.55, _ground - _u * 0.10);
    }

    // La striscia che resta sull'asfalto.
    if (drag > 0) {
      canvas.drawRect(
        Rect.fromLTRB(
          _victimX + _u * 0.3,
          _ground + _u * 0.005,
          min(_cornerX, dragFeet + _u * 0.3),
          _ground + _u * 0.03,
        ),
        Paint()..color = _bloodF.withValues(alpha: 0.75),
      );
    }

    canvas.save();
    canvas.clipRect(Rect.fromLTRB(-_w, -_h, _cornerX, _h * 2));
    if (topple <= 0) {
      final jolt = _span(t, _hit, _hit + 0.04);
      _victim(
        canvas,
        x: walkX,
        walk: walk,
        stride: stride,
        lean: t < _hit
            ? -0.08 * _span(t, 0.50, 0.53)
            : -0.22 * sin(pi * min(1, jolt * 1.5)) +
                  0.10 * _span(t, 0.57, 0.60),
        arm: t < _hit ? 0.08 : 1.3,
        elbow: t < _hit ? 0.2 : 1.6,
        smoking: t > 0.37 && t < _hit,
      );
    } else if (topple < 1) {
      _person(
        canvas,
        feet: Offset(_victimX + _u * 0.05, _ground),
        tilt: pi / 2 * Curves.easeIn.transform(topple),
        lean: 0.2,
        arm: 2.6,
        elbow: 0.2,
        backArm: -1.8,
        hat: victimHat,
        hatOn: false,
      );
    } else if (dragFeet < _cornerX + _u * 0.3) {
      _corpse(canvas, dragFeet, 1);
    }
    canvas.restore();
    if (drag > 0 && drag < 1) {
      _dust(
        canvas,
        Offset(min(_cornerX - _u * 0.1, dragFeet + _u * 0.2), _ground),
        drag,
        seed: 101,
        count: 4,
        size: 0.4,
      );
    }
    if (t < _hit) {
      _exclaim(
        canvas,
        Offset(_victimX + _u * 0.05, _ground - _u * 1.40),
        _span(t, 0.50, 0.54),
      );
    }

    // L'arpione in volo, poi piantato: la sagola dalla canna fino a lui.
    if (t >= fire) {
      final fly = _span(t, fire, _hit);
      final tip = fly < 1
          ? Offset.lerp(launch, chest, Curves.easeIn.transform(fly))!
          : stuck;
      final dir = fly < 1 ? chest - launch : tip - muzzle;
      final slack = fly < 1
          ? 0.25 * fly
          : 0.25 * (1 - _smooth(_span(t, _hit, 0.60)));
      final tail = tip - dir / max(dir.distance, 0.001) * (_u * 0.26);
      // La sagola resta tesa dalla canna all'arpione per tutto il traino,
      // anche quando il corpo finisce sotto il fucile; dietro l'angolo
      // sparisce con lui.
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(-_w, -_h, _cornerX, _h * 2));
      _rope(canvas, muzzle, tail, slack);
      _harpoonSpear(canvas, tip, dir);
      canvas.restore();
      if (fly < 1) {
        _speedLines(canvas, tip, dir, length: 0.35, spread: 0.03, alpha: 0.35);
      }
    }
    _muzzleFlash(
      canvas,
      launch,
      _span(t, fire, fire + 0.02),
      toward: const Offset(-1, 0.1),
      size: 0.5,
    );
    _puff(
      canvas,
      launch.translate(_u * 0.05, -_u * 0.05),
      _span(t, fire, fire + 0.10),
      size: 0.35,
    );
    _impactBurst(canvas, chest, _span(t, _hit, _hit + 0.05), size: 0.6);
    _spray(
      canvas,
      chest,
      _span(t, _hit, _hit + 0.18),
      seed: 102,
      count: 16,
      bias: const Offset(-0.6, -0.6),
    );

    // Il cappello e la sigaretta restano lì, dove stava.
    final hatFall = _span(t, 0.605, 0.66);
    if (topple > 0) {
      _looseHat(
        canvas,
        Offset(
          _victimX - _u * 0.10 * hatFall,
          _mix(
            _ground - _u * 1.02,
            _ground - _u * 0.03,
            Curves.easeIn.transform(hatFall),
          ),
        ),
        hatFall < 1 ? -hatFall * 2 : -0.2,
      );
    }
    _droppedCigarette(
      canvas,
      Offset(_victimX + _u * 0.17, _ground - _u * 0.92),
      _span(t, _hit, _hit + 0.07),
    );
    _flash(canvas, _span(t, _hit, _hit + 0.03), strength: 0.25);
  }

  // -------------------------------------------------------------------- torta

  /// La torta alla panna nel suo piatto di latta, con la ciliegina. [face]
  /// ruota la torta: 0 dritta, -pi/2 con la panna verso sinistra.
  void _creamPie(Canvas canvas, Offset center, double face, {double size = 1}) {
    final r = _u * 0.13 * size;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(face);
    canvas.drawPath(
      Path()..addPolygon([
        Offset(-r, 0),
        Offset(r, 0),
        Offset(r * 0.82, r * 0.30),
        Offset(-r * 0.82, r * 0.30),
      ], true),
      Paint()..color = const Color(0xFF9AA0A7),
    );
    canvas.drawRect(
      Rect.fromLTRB(-r * 0.95, -r * 0.10, r * 0.95, r * 0.05),
      Paint()..color = const Color(0xFFC98E4E),
    );
    canvas.drawPath(
      Path()
        ..moveTo(-r * 0.95, -r * 0.08)
        ..quadraticBezierTo(-r * 0.8, -r * 0.55, -r * 0.35, -r * 0.45)
        ..quadraticBezierTo(0, -r * 0.75, r * 0.35, -r * 0.45)
        ..quadraticBezierTo(r * 0.8, -r * 0.55, r * 0.95, -r * 0.08)
        ..close(),
      Paint()..color = _cream,
    );
    canvas.drawCircle(Offset(0, -r * 0.70), r * 0.14, Paint()..color = _rose);
    canvas.drawCircle(
      Offset(-r * 0.04, -r * 0.74),
      r * 0.045,
      Paint()..color = Colors.white.withValues(alpha: 0.7),
    );
    canvas.restore();
  }

  /// La latta vuota della torta, finita per terra.
  void _pieTin(Canvas canvas, Offset center, double spin) {
    final r = _u * 0.12;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(spin);
    canvas.drawPath(
      Path()..addPolygon([
        Offset(-r, -r * 0.15),
        Offset(r, -r * 0.15),
        Offset(r * 0.82, r * 0.15),
        Offset(-r * 0.82, r * 0.15),
      ], true),
      Paint()..color = const Color(0xFF9AA0A7),
    );
    canvas.drawLine(
      Offset(-r * 0.9, -r * 0.1),
      Offset(r * 0.9, -r * 0.1),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.6)
        ..strokeWidth = r * 0.06,
    );
    canvas.drawCircle(
      Offset(-r * 0.3, -r * 0.2),
      r * 0.15,
      Paint()..color = _cream,
    );
    canvas.restore();
  }

  /// La bomba a mano: un ananas verde scuro con la leva.
  void _grenade(
    Canvas canvas,
    Offset center,
    double spin, {
    bool lever = true,
  }) {
    final r = _u * 0.055;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(spin);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: r * 1.7, height: r * 2.1),
      Paint()..color = const Color(0xFF4B5A2A),
    );
    final grid = Paint()
      ..color = const Color(0xFF2C3518)
      ..strokeWidth = r * 0.12;
    for (final y in [-0.45, 0.0, 0.45]) {
      canvas.drawLine(Offset(-r * 0.8, r * y), Offset(r * 0.8, r * y), grid);
    }
    canvas.drawLine(Offset(0, -r), Offset(0, r), grid);
    canvas.drawRect(
      Rect.fromLTRB(-r * 0.30, -r * 1.35, r * 0.30, -r * 0.95),
      Paint()..color = const Color(0xFF6B7078),
    );
    if (lever) {
      canvas.drawLine(
        Offset(r * 0.25, -r * 1.25),
        Offset(r * 0.75, -r * 0.2),
        Paint()
          ..color = const Color(0xFF9AA0A7)
          ..strokeWidth = r * 0.22,
      );
    }
    canvas.restore();
  }

  void _pie(Canvas canvas) {
    final (walkX, walk, stride) = _entrance();
    const throwAt = 0.502;
    const splat = 0.52;
    const pin = 0.538;
    const topple = 0.70;
    const down = 0.775;
    final peek = _smooth(_span(t, 0.38, 0.45));
    final out = _smooth(_span(t, 0.45, 0.48));
    final duck = _smooth(_span(t, 0.528, 0.548));
    final killerX = _mix(
      _mix(_mix(_hiddenX, _peekX, peek), _cornerX - _u * 0.08, out),
      _hiddenX + _u * 0.1,
      duck,
    );
    final windUp = _smooth(_span(t, 0.48, 0.497));
    final release = Curves.easeOut.transform(_span(t, 0.497, throwAt + 0.006));
    final arm = _mix(_mix(1.05, 2.85, windUp), 1.55, release);
    final elbow = _mix(_mix(1.4, 1.3, windUp), 0.15, release);
    final lean = _mix(_mix(0.02, -0.14, windUp), 0.30, release) * (1 - duck);
    final feet = Offset(killerX, _ground);
    // Lanciata la torta, corre a ripararsi dietro l'angolo, mani sulle
    // orecchie.
    _person(
      canvas,
      feet: feet,
      facing: duck > 0.3 ? 1 : -1,
      walk: _prowl,
      stride: (out > 0 && out < 1) || (duck > 0 && duck < 1) ? 0.9 : 0,
      lean: lean,
      arm: duck > 0 ? 2.6 : arm,
      elbow: duck > 0 ? 2.4 : elbow,
      backArm: duck > 0 ? 2.6 : -0.1,
      backElbow: duck > 0 ? 2.4 : 0.2,
      killer: true,
    );
    final (hand, _) = _grip(
      feet,
      facing: -1,
      lean: lean,
      arm: arm,
      elbow: elbow,
    );
    if (t < throwAt) {
      _creamPie(canvas, hand.translate(-_u * 0.02, -_u * 0.05), 0, size: 0.9);
    }
    _wall(canvas);

    final face = Offset(_victimX + _u * 0.10, _ground - _u * 0.97);
    // La torta in volo, che si gira con la panna in avanti.
    if (t >= throwAt && t < splat) {
      final (from, _) = _grip(
        Offset(_cornerX - _u * 0.08, _ground),
        facing: -1,
        lean: 0.30,
        arm: 1.55,
        elbow: 0.15,
      );
      final fly = _span(t, throwAt, splat);
      final at =
          Offset.lerp(from, face.translate(_u * 0.08, 0), fly)! -
          Offset(0, _u * 0.18 * sin(pi * fly));
      _speedLines(
        canvas,
        at,
        const Offset(-1, 0),
        length: 0.4,
        spread: 0.05,
        alpha: 0.35,
      );
      _creamPie(canvas, at, -pi / 2 * min(1, fly * 2.5), size: 0.9);
    }

    if (t < _hit) {
      final knock = _span(t, splat, splat + 0.02);
      final wipe =
          _smooth(_span(t, 0.524, 0.536)) *
          (1 - _smooth(_span(t, 0.542, 0.552)));
      final lean = t < splat ? 0.0 : -0.20 * sin(pi * knock) - 0.06;
      _victim(
        canvas,
        x: walkX,
        walk: walk,
        stride: stride,
        lean: lean,
        arm: _mix(0.08, 2.25, wipe),
        elbow: _mix(0.2, 1.5, wipe),
        smoking: t > 0.37 && t < splat,
      );
      if (t >= splat) {
        // La panna in faccia, che cola.
        final drip = _span(t, splat, _hit);
        final head = _onBody(
          const Offset(0.06, -0.48),
          feet: Offset(walkX, _ground),
          lean: lean,
        );
        final cream = Paint()..color = _cream;
        canvas.drawCircle(head, _u * 0.10, cream);
        canvas.drawCircle(
          head.translate(_u * 0.07, _u * 0.03),
          _u * 0.06,
          cream,
        );
        canvas.drawCircle(
          head.translate(-_u * 0.05, -_u * 0.07),
          _u * 0.06,
          cream,
        );
        final drips = Paint()
          ..color = _cream
          ..strokeWidth = _u * 0.03;
        for (final (dx, len) in const [
          (-0.04, 0.10),
          (0.03, 0.16),
          (0.09, 0.08),
        ]) {
          final y = head.dy + _u * (0.07 + len * drip);
          canvas.drawLine(
            head.translate(_u * dx, _u * 0.05),
            Offset(head.dx + _u * dx, y),
            drips,
          );
          canvas.drawCircle(Offset(head.dx + _u * dx, y), _u * 0.02, cream);
        }
        // Dentro la panna, la bomba: la latta scivola via e si vede.
        _grenade(canvas, head.translate(_u * 0.10, 0), 0.3, lever: t < pin);
        final slide = _span(t, 0.530, 0.548);
        if (slide < 1) {
          _creamPie(
            canvas,
            Offset.lerp(
              head.translate(_u * 0.12, 0),
              Offset(_victimX + _u * 0.30, _ground - _u * 0.02),
              Curves.easeIn.transform(slide),
            )!,
            -pi / 2 + slide * 1.4,
            size: 0.9,
          );
        }
        _exclaim(
          canvas,
          Offset(_victimX + _u * 0.05, _ground - _u * 1.40),
          _span(t, 0.540, 0.575),
        );
      }
    } else if (t < down) {
      // Annerito, i capelli dritti, poi giù come un'asse.
      final tip = _span(t, topple, down);
      final tilt = -pi / 2 * 0.96 * Curves.easeIn.transform(tip);
      final sway = tip == 0 ? sin(t * 60) * 0.02 * _span(t, 0.64, topple) : 0.0;
      _person(
        canvas,
        feet: Offset(_victimX, _ground),
        tilt: tilt + sway,
        lean: -0.12,
        arm: 0.6,
        elbow: 0.3,
        backArm: -0.4,
        hat: victimHat,
        hatOn: false,
      );
      _frazzle(canvas, Offset(_victimX, _ground), tilt + sway, -0.12);
      // Due occhi bianchi nel nero, che sbattono.
      if (tip == 0 && sin(t * 90) > -0.8) {
        final eye = _onBody(
          const Offset(0.08, -0.49),
          feet: Offset(_victimX, _ground),
          lean: -0.12,
          tilt: sway,
        );
        canvas.drawCircle(eye, _u * 0.016, Paint()..color = Colors.white);
        canvas.drawCircle(
          eye.translate(-_u * 0.035, 0),
          _u * 0.016,
          Paint()..color = Colors.white,
        );
      }
      for (var i = 0; i < 3; i++) {
        final life = ((t - _hit) * 9 + i / 3) % 1;
        final top = Offset(
          _victimX + _u * 0.98 * sin(tilt + sway),
          _ground - _u * 0.98 * cos(tilt + sway),
        );
        _puff(
          canvas,
          top.translate(_u * (i - 1) * 0.08, -_u * (0.10 + 0.5 * life)),
          life,
          size: 0.25,
          color: const Color(0xFF3A3836),
        );
      }
    } else {
      _corpse(canvas, _victimX, -1);
      _soot(
        canvas,
        Offset(_victimX - _u * 0.4, _ground - _u * 0.1),
        _span(t, down, 0.95),
        seed: 104,
        count: 4,
        size: 0.5,
      );
    }
    // La latta della torta, rimasta per terra.
    if (t >= 0.548) {
      _pieTin(canvas, Offset(_victimX + _u * 0.32, _ground - _u * 0.02), 0.1);
    }
    _dust(
      canvas,
      Offset(_victimX - _u * 0.55, _ground),
      _span(t, down, down + 0.18),
      seed: 105,
      size: 0.7,
    );

    // La leva che salta via facendo «ping».
    final ping = _span(t, pin, pin + 0.05);
    if (ping > 0 && ping < 1) {
      final from = face.translate(_u * 0.06, -_u * 0.05);
      final at = from + Offset(_u * 0.35 * ping, -_u * 0.6 * sin(pi * ping));
      canvas.save();
      canvas.translate(at.dx, at.dy);
      canvas.rotate(ping * 14);
      canvas.drawLine(
        Offset(-_u * 0.03, 0),
        Offset(_u * 0.03, 0),
        Paint()
          ..color = const Color(0xFFB8BEC6)
          ..strokeWidth = _u * 0.014,
      );
      canvas.restore();
      _sprite(
        canvas,
        sprites?.glint,
        at,
        _u * 0.25 * (1 - ping),
        opacity: 1 - ping,
      );
    }

    // Lo spiaccico.
    _spray(
      canvas,
      face,
      _span(t, splat, splat + 0.06),
      seed: 103,
      color: _cream,
      count: 18,
      bias: const Offset(0.6, -0.7),
      reach: 0.8,
    );
    _extraWord(
      canvas,
      'SPLAT!',
      face.translate(_u * 0.25, -_u * 0.55),
      _span(t, splat, splat + 0.06),
    );

    // Il botto, in faccia: centrato sulla testa annerita.
    final centre = _onBody(
      const Offset(0.06, -0.47),
      feet: Offset(_victimX, _ground),
      lean: -0.12,
    );
    _faceBlast(canvas, centre, _hit);
    _spray(
      canvas,
      centre,
      _span(t, _hit, _hit + 0.08),
      seed: 106,
      color: const Color(0xFFFFB13B),
      count: 12,
      bias: Offset.zero,
      reach: 0.6,
    );
    _spray(
      canvas,
      centre,
      _span(t, _hit, _hit + 0.12),
      seed: 107,
      color: _cream,
      count: 12,
      bias: const Offset(0, -0.4),
      reach: 0.7,
    );
    _flash(canvas, _span(t, _hit - 0.001, _hit + 0.04), strength: 0.45);
  }
  // ----------------------------------------------------------------- trombone

  /// Una nota musicale da fumetto: testa ovale, gambo e bandierina.
  void _musicNote(
    Canvas canvas,
    Offset at,
    double size,
    Color color, {
    double spin = 0,
  }) {
    if (color.a <= 0) return;
    final r = _u * 0.035 * size;
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(spin);
    final ink = Paint()
      ..color = _inkF.withValues(alpha: color.a)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.45;
    final fill = Paint()..color = color;
    final head = Rect.fromCenter(
      center: Offset.zero,
      width: r * 2.2,
      height: r * 1.6,
    );
    final stem = Path()
      ..moveTo(r * 0.95, 0)
      ..lineTo(r * 0.95, -r * 3.6)
      ..quadraticBezierTo(r * 2.4, -r * 3.0, r * 2.2, -r * 1.6);
    canvas.drawOval(head, ink);
    canvas.drawPath(stem, ink);
    canvas.drawOval(head, fill);
    canvas.drawPath(
      stem,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.28,
    );
    canvas.restore();
  }

  /// Il trombone, imboccato in [mouth] e con la coulisse tenuta in [hand]:
  /// la campana punta verso [facing]. Ritorna la bocca della campana.
  Offset _tromboneShape(Canvas canvas, Offset mouth, Offset hand, int facing) {
    final f = facing.toDouble();
    final brass = Paint()
      ..color = _brass
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = _u * 0.022;
    final shade = Paint()
      ..color = _brassDark
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = _u * 0.030;
    final bellStart = mouth.translate(f * _u * 0.03, -_u * 0.035);
    final bellEnd = bellStart.translate(f * _u * 0.30, -_u * 0.01);
    final loop = mouth.translate(-f * _u * 0.17, -_u * 0.02);
    // La coulisse: due canne parallele dalla bocca alla mano, e la curva.
    final slideEnd = hand.translate(f * _u * 0.08, 0);
    final upper = [
      mouth.translate(0, _u * 0.005),
      slideEnd.translate(0, -_u * 0.018),
    ];
    final lower = [
      mouth.translate(0, _u * 0.040),
      slideEnd.translate(0, _u * 0.018),
    ];
    for (final paint in [shade, brass]) {
      canvas.drawLine(bellStart, bellEnd, paint);
      canvas.drawPath(
        Path()
          ..moveTo(bellStart.dx, bellStart.dy)
          ..quadraticBezierTo(
            loop.dx,
            loop.dy - _u * 0.02,
            loop.dx,
            loop.dy + _u * 0.01,
          )
          ..quadraticBezierTo(
            loop.dx,
            loop.dy + _u * 0.05,
            mouth.dx,
            mouth.dy + _u * 0.04,
          ),
        paint,
      );
      canvas.drawLine(upper[0], upper[1], paint);
      canvas.drawLine(lower[0], lower[1], paint);
      canvas.drawArc(
        Rect.fromCenter(center: slideEnd, width: _u * 0.04, height: _u * 0.036),
        f > 0 ? -pi / 2 : pi / 2,
        pi,
        false,
        paint,
      );
    }
    // La campana, svasata, con il riflesso.
    final rim = bellEnd.translate(f * _u * 0.10, 0);
    final bell = Path()
      ..moveTo(bellEnd.dx, bellEnd.dy - _u * 0.015)
      ..quadraticBezierTo(
        rim.dx - f * _u * 0.05,
        bellEnd.dy - _u * 0.02,
        rim.dx,
        rim.dy - _u * 0.10,
      )
      ..lineTo(rim.dx, rim.dy + _u * 0.10)
      ..quadraticBezierTo(
        rim.dx - f * _u * 0.05,
        bellEnd.dy + _u * 0.02,
        bellEnd.dx,
        bellEnd.dy + _u * 0.015,
      )
      ..close();
    canvas.drawPath(bell, Paint()..color = _brass);
    canvas.drawOval(
      Rect.fromCenter(center: rim, width: _u * 0.04, height: _u * 0.20),
      Paint()..color = _brassDark,
    );
    canvas.drawLine(
      bellStart.translate(f * _u * 0.05, -_u * 0.006),
      bellEnd.translate(0, -_u * 0.006),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.6)
        ..strokeWidth = _u * 0.006,
    );
    return rim;
  }

  void _trombone(Canvas canvas) {
    final (walkX, walk, stride) = _entrance();
    final out = _smooth(_span(t, 0.38, 0.47));
    final leave = _smooth(_span(t, 0.76, 0.88));
    final playerX = _mix(
      _mix(_hiddenX, _cornerX - _u * 0.12, out),
      _hiddenX,
      leave,
    );
    // La marcetta: la coulisse va e viene a tempo; poi la mira, il colpo
    // (il rinculo spinge indietro), e le quattro note tristi che scendono.
    final aim = _smooth(_span(t, 0.50, 0.53));
    final kick = t < _hit ? 0.0 : sin(pi * _span(t, _hit, _hit + 0.04));
    final sad = _span(t, 0.60, 0.70);
    var reach = 0.45 + 0.35 * sin(t * 260).abs() * (1 - aim);
    reach = _mix(reach, 1.0, aim);
    if (sad > 0) reach = 0.35 + 0.65 * min(1.0, (sad * 4).floor() / 3 + 0.0);
    final arm = _mix(1.35, 1.62, reach);
    final elbow = _mix(1.1, 0.02, reach);
    final lean =
        -0.14 * kick + 0.06 * sin(t * 130) * (1 - aim) * out + 0.10 * sad;
    final facing = leave > 0.08 ? 1 : -1;
    final feet = Offset(playerX, _ground);
    final playing = leave <= 0;
    _person(
      canvas,
      feet: feet,
      facing: facing,
      walk: _prowl,
      stride: (out > 0 && out < 1) || (leave > 0 && leave < 1) ? 0.6 : 0,
      lean: lean,
      arm: playing ? arm : 0.1,
      elbow: playing ? elbow : 0.2,
      backArm: playing ? 2.0 : -0.1,
      backElbow: playing ? 1.6 : 0.2,
      killer: true,
    );
    final mouth = _onBody(
      const Offset(0.11, -0.44),
      feet: feet,
      facing: facing,
      lean: lean,
      killer: true,
    );
    final (hand, _) = _grip(
      feet,
      facing: facing,
      lean: lean,
      arm: playing ? arm : 0.1,
      elbow: playing ? elbow : 0.2,
    );
    final bell = playing
        ? _tromboneShape(canvas, mouth, hand, facing)
        : _tromboneShape(
            canvas,
            mouth.translate(0, _u * 0.35),
            mouth.translate(_u * 0.25, _u * 0.42),
            facing,
          );
    _wall(canvas);

    // Le note della marcetta salgono dalla campana; dopo il colpo le note
    // tristi cadono giù, come la vittima.
    for (var i = 0; i < 6; i++) {
      final life = _span(t, 0.40 + i * 0.022, 0.40 + i * 0.022 + 0.08);
      if (life <= 0 || life >= 1 || t > _hit - 0.005) continue;
      _musicNote(
        canvas,
        bell +
            Offset(
              -_u * 0.35 * life,
              -_u * (0.2 + 0.5 * life) + sin(life * 8 + i) * _u * 0.05,
            ),
        0.9,
        AppColors.gold.withValues(alpha: 1 - life),
        spin: sin(life * 6 + i) * 0.3,
      );
    }
    for (var i = 0; i < 4; i++) {
      final life = _span(t, 0.60 + i * 0.02, 0.66 + i * 0.03);
      if (life <= 0 || life >= 1) continue;
      _musicNote(
        canvas,
        bell +
            Offset(
              -_u * (0.15 + 0.25 * life),
              _u * (-0.1 + 0.45 * life * life),
            ),
        1.1 - 0.15 * i,
        const Color(0xFF8FA7C9).withValues(alpha: 1 - life),
        spin: 0.4 + life,
      );
    }

    // La vittima: va a tempo con la testa, si prende il colpo, e si affloscia
    // nota dopo nota.
    final droop = sad > 0
        ? min(1.0, (sad * 4).floor() / 4 + _span(sad, 0.0, 0.25) * 0.25)
        : 0.0;
    final fall = _span(t, 0.69, 0.77);
    final jolt = _span(t, _hit, _hit + 0.05);
    _pool(
      canvas,
      Offset(_victimX - _u * 0.50, _ground + _u * 0.04),
      _smooth(_span(t, 0.76, 0.88)),
    );
    if (fall > 0) {
      _victim(canvas, x: walkX, fall: fall);
    } else {
      final bob = t > 0.42 && t < _hit ? sin(t * 260) * 0.05 : 0.0;
      canvas.save();
      // Ogni nota triste lo accorcia un po', come un palloncino che si sgonfia.
      canvas.translate(walkX, _ground);
      canvas.scale(1, 1 - 0.18 * droop);
      canvas.translate(-walkX, -_ground);
      _victim(
        canvas,
        x: walkX,
        walk: walk,
        stride: stride,
        lean: bob - 0.25 * sin(pi * min(1, jolt * 1.5)) + 0.30 * droop,
        arm: t < _hit ? 0.08 : _mix(1.2, 0.1, droop),
        elbow: t < _hit ? 0.2 : _mix(1.7, 0.1, droop),
        smoking: t > 0.37 && t < _hit,
      );
      canvas.restore();
    }
    _hatOff(canvas, 0.69, 0.84, height: 0.4);
    _droppedCigarette(
      canvas,
      Offset(_victimX + _u * 0.17, _ground - _u * 0.92),
      _span(t, _hit, _hit + 0.07),
    );

    // Il colpo esce dalla campana, con le note che schizzano via.
    final bang = _span(t, _hit, _hit + 0.04);
    _muzzleFlash(
      canvas,
      bell,
      _span(t, _hit, _hit + 0.03),
      toward: const Offset(-1, 0),
      size: 1.3,
    );
    if (bang > 0 && bang < 1 && !_holdsFire) {
      _star(
        canvas,
        bell,
        _u * 0.18 * (1 - bang * 0.4),
        const Color(0xFFFFF3C4).withValues(alpha: 1 - bang),
      );
      final target = Offset(_victimX + _u * 0.06, _ground - _u * 0.74);
      final trail = Paint()
        ..color = _warmF.withValues(alpha: 0.9 * (1 - bang))
        ..strokeWidth = _u * 0.012;
      canvas.drawLine(
        Offset.lerp(bell, target, bang * 0.6)!,
        Offset.lerp(bell, target, min(1, bang * 0.6 + 0.4))!,
        trail,
      );
    }
    for (var i = 0; i < 5; i++) {
      final life = _span(t, _hit, _hit + 0.10 + i * 0.01);
      if (life <= 0 || life >= 1 || _holdsFire) continue;
      final a = -pi / 2 + (i - 2) * 0.55;
      _musicNote(
        canvas,
        bell +
            Offset(cos(a), sin(a)) * (_u * 0.55 * life) +
            Offset(0, _u * 0.3 * life * life),
        0.8,
        AppColors.gold.withValues(alpha: 1 - life),
        spin: life * 9 + i,
      );
    }
    _puff(
      canvas,
      bell.translate(-_u * 0.1, -_u * 0.05),
      _span(t, _hit + 0.005, _hit + 0.18),
      size: 0.7,
    );
    _spray(
      canvas,
      Offset(_victimX + _u * 0.04, _ground - _u * 0.74),
      _span(t, _hit, _hit + 0.18),
      seed: 111,
      count: 18,
    );
    _dust(
      canvas,
      Offset(_victimX - _u * 0.5, _ground),
      _span(t, 0.77, 0.90),
      seed: 112,
      size: 0.6,
    );
    _flash(canvas, bang, strength: 0.6);
  }

  // -------------------------------------------------------------------- tango

  /// Una rosa rossa col gambo, girata di [spin].
  void _roseFlower(Canvas canvas, Offset at, double spin, {double size = 1}) {
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(spin);
    canvas.drawLine(
      Offset.zero,
      Offset(_u * 0.16 * size, 0),
      Paint()
        ..color = _leaf
        ..strokeWidth = _u * 0.012 * size,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(_u * 0.09 * size, -_u * 0.02 * size),
        width: _u * 0.05 * size,
        height: _u * 0.025 * size,
      ),
      Paint()..color = _leaf,
    );
    canvas.drawCircle(
      Offset(_u * 0.17 * size, 0),
      _u * 0.035 * size,
      Paint()..color = _rose,
    );
    canvas.drawArc(
      Rect.fromCircle(
        center: Offset(_u * 0.17 * size, 0),
        radius: _u * 0.02 * size,
      ),
      0,
      4,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _u * 0.007 * size
        ..color = const Color(0xFF7A0E1C),
    );
    canvas.restore();
  }

  void _tango(Canvas canvas) {
    final (walkX, walk, stride) = _entrance();
    final come = _smooth(_span(t, 0.37, 0.47));
    final offer = _smooth(_span(t, 0.47, 0.50));
    final step = _smooth(_span(t, 0.50, 0.535));
    final spin = _span(t, 0.535, 0.548);
    final dip = Curves.easeOut.transform(_span(t, 0.548, _hit));
    final drop = Curves.easeIn.transform(_span(t, 0.60, 0.64));
    final toss = _span(t, 0.66, 0.71);
    final leave = _smooth(_span(t, 0.74, 0.86));
    // La coppia fa qualche passo, a tempo, verso l'angolo.
    final shift = _u * 0.12 * step;
    final pairX = _victimX + shift;
    final dameX = _mix(
      _mix(_hiddenX, _victimX + _u * 0.36, come) + shift,
      _hiddenX,
      leave,
    );
    final stepping = step > 0 && step < 1;
    final strolling = (come > 0 && come < 1) || (leave > 0 && leave < 1);
    final hold = dip * (1 - drop);
    final dameLean = 0.10 * offer + 0.40 * hold;
    final dameFeet = Offset(dameX - _u * 0.16 * hold, _ground);
    final rose = toss <= 0 && leave <= 0;
    _person(
      canvas,
      feet: dameFeet,
      facing: leave > 0.08 ? 1 : -1,
      walk: t * 150,
      stride: strolling ? 0.55 : (stepping ? 0.7 : 0),
      lean: leave > 0 ? 0 : dameLean,
      crouch: 0.30 * hold,
      arm: leave > 0
          ? 0.1
          : _mix(_mix(0.1, 1.55, offer), 1.25, hold) +
                (toss > 0 ? 1.3 * sin(pi * toss) : 0),
      elbow: leave > 0 ? 0.2 : _mix(0.2, 0.5, offer),
      backArm: leave > 0 ? -0.1 : _mix(-0.1, 1.9, max(offer * 0.6, hold)),
      backElbow: 0.6,
      dame: true,
    );
    if (rose) {
      final mouth = _onBody(
        const Offset(0.10, -0.43),
        feet: dameFeet,
        facing: -1,
        lean: dameLean,
        crouch: 0.30 * hold,
      );
      _roseFlower(canvas, mouth.translate(_u * 0.06, _u * 0.01), pi, size: 0.9);
    }
    _wall(canvas);

    // La lama: un lampo sotto la schiena, nel casqué.
    final victimFeet = Offset(walkX + shift, _ground);
    final twirl = spin > 0 && spin < 1
        ? (sin(spin * 2 * pi * 1.5) > 0 ? -1 : 1)
        : 1;
    if (drop < 1) {
      final tilt = _mix(-0.78 * dip, -1.45, drop);
      final limp = _span(t, _hit + 0.01, 0.60);
      _person(
        canvas,
        feet: victimFeet,
        facing: twirl,
        walk: walk + (stepping ? t * 300 : 0),
        stride: t < 0.34 ? stride : (stepping ? 0.6 : 0),
        lean: -0.08 * dip + (spin > 0 && spin < 1 ? 0.1 : 0),
        tilt: tilt,
        arm: t < 0.47
            ? 0.08
            : _mix(_mix(_mix(0.08, 1.35, offer), 2.4, dip), 2.9, limp),
        elbow: t < 0.47 ? 0.2 : _mix(0.4, 0.1, limp),
        backArm: _mix(_mix(-0.1, 0.9, offer), -2.6, limp),
        backElbow: 0.3,
        hat: victimHat,
        hatOn: t < 0.548,
        smoking: t > 0.37 && t < 0.47,
      );
    } else {
      _corpse(canvas, victimFeet.dx, -1);
    }
    if (spin > 0 && spin < 1) {
      // La giravolta: un ventaglio chiaro intorno a chi gira.
      canvas.drawArc(
        Rect.fromCenter(
          center: victimFeet.translate(0, -_u * 0.55),
          width: _u * 0.8,
          height: _u * 0.3,
        ),
        0,
        2 * pi * spin,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _u * 0.03
          ..color = Colors.white.withValues(alpha: 0.5 * (1 - spin)),
      );
    }
    _hatOff(canvas, 0.548, 0.70, height: 0.7);
    final back = victimFeet + Offset(-_u * 0.28, -_u * 0.48);
    final stab = _span(t, _hit, _hit + 0.04);
    if (stab > 0 && stab < 1) {
      _sprite(
        canvas,
        sprites?.slash,
        back,
        _u * 0.9,
        opacity: 1 - stab,
        rotation: -0.5,
        tint: const Color(0xFFF2F4F8),
      );
      _sprite(
        canvas,
        sprites?.glint,
        back.translate(_u * 0.1, -_u * 0.05),
        _u * 0.5 * (1 - stab),
        opacity: 1 - stab,
      );
    }
    _spray(
      canvas,
      back,
      _span(t, _hit, _hit + 0.20),
      seed: 121,
      count: 18,
      bias: const Offset(-0.2, -0.6),
    );
    _pool(
      canvas,
      Offset(victimFeet.dx - _u * 0.5, _ground + _u * 0.04),
      _smooth(_span(t, 0.66, 0.84)),
    );
    _dust(
      canvas,
      Offset(victimFeet.dx - _u * 0.5, _ground),
      _span(t, 0.64, 0.78),
      seed: 122,
      size: 0.5,
    );

    // La rosa, tolta dai denti, cade sul petto.
    if (toss > 0) {
      final mouth = _onBody(
        const Offset(0.10, -0.43),
        feet: dameFeet,
        facing: -1,
      );
      final rest = Offset(victimFeet.dx - _u * 0.45, _ground - _u * 0.15);
      final at =
          Offset.lerp(mouth, rest, Curves.easeIn.transform(toss))! -
          Offset(0, _u * 0.25 * sin(pi * toss));
      _roseFlower(canvas, at, pi + toss * 2.2, size: 0.9);
    }
    // Un cuore che spunta all'invito, e uno che si spezza al colpo.
    final love = _span(t, 0.47, 0.53);
    if (love > 0 && love < 1) {
      _heart(
        canvas,
        Offset(pairX + _u * 0.18, _ground - _u * (1.25 + 0.3 * love)),
        _u * 0.08,
        const Color(0xFFE23A4A).withValues(alpha: 1 - love * love),
      );
    }
    _flash(canvas, _span(t, _hit, _hit + 0.03), strength: 0.25);
  }
  // ---------------------------------------------------------------- mazzo

  /// Il mazzo di rose nel cartoccio: la punta in [hand], i fiori verso
  /// [dir]. [roses] dice quante ne restano; [barrel] quanto spunta la canna.
  /// Ritorna la bocca della canna.
  Offset _bouquetShape(
    Canvas canvas,
    Offset hand,
    Offset dir, {
    int roses = 7,
    double barrel = 0,
  }) {
    final d = dir / max(dir.distance, 0.001);
    final side = Offset(-d.dy, d.dx);
    final mouth = hand + d * (_u * 0.24);
    final muzzle = mouth + d * (_u * 0.05 + _u * 0.17 * barrel);
    if (barrel > 0) {
      canvas.drawLine(
        mouth - d * (_u * 0.05),
        muzzle,
        Paint()
          ..color = const Color(0xFF272A30)
          ..strokeWidth = _u * 0.040,
      );
      canvas.drawLine(
        mouth,
        muzzle,
        Paint()
          ..color = const Color(0xFF9AA0A7)
          ..strokeWidth = _u * 0.006,
      );
    }
    final leaves = Paint()..color = _leaf;
    for (var i = -2; i <= 2; i++) {
      final at = mouth + side * (_u * 0.06 * i) - d * (_u * 0.01 * i.abs());
      canvas.save();
      canvas.translate(at.dx, at.dy);
      canvas.rotate(atan2(d.dy, d.dx) + i * 0.35);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(_u * 0.04, 0),
          width: _u * 0.10,
          height: _u * 0.035,
        ),
        leaves,
      );
      canvas.restore();
    }
    const spots = [
      (0.0, 0.02),
      (-0.06, 0.0),
      (0.06, 0.0),
      (-0.035, 0.06),
      (0.035, 0.06),
      (-0.10, 0.04),
      (0.10, 0.04),
    ];
    for (var i = 0; i < min(roses, spots.length); i++) {
      final (s, f) = spots[i];
      final at = mouth + side * (_u * s) + d * (_u * f);
      canvas.drawCircle(at, _u * 0.042, Paint()..color = _rose);
      canvas.drawArc(
        Rect.fromCircle(center: at, radius: _u * 0.022),
        i.toDouble(),
        4,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _u * 0.008
          ..color = const Color(0xFF7A0E1C),
      );
    }
    // Il cartoccio di carta, con il fiocco.
    final paper = Path()
      ..addPolygon([
        hand - d * (_u * 0.04),
        mouth + side * (_u * 0.13) - d * (_u * 0.02),
        mouth - side * (_u * 0.13) - d * (_u * 0.02),
      ], true);
    canvas.drawPath(paper, Paint()..color = _cream);
    canvas.drawPath(
      paper,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _u * 0.006
        ..color = const Color(0xFFBDB29A),
    );
    final bow = hand + d * (_u * 0.04);
    canvas.drawCircle(
      bow + side * (_u * 0.025),
      _u * 0.02,
      Paint()..color = _rose,
    );
    canvas.drawCircle(
      bow - side * (_u * 0.025),
      _u * 0.02,
      Paint()..color = _rose,
    );
    return muzzle;
  }

  /// Un petalo che vola, gira e si posa piano.
  void _petals(
    Canvas canvas,
    Offset from,
    double born, {
    required int seed,
    int count = 10,
  }) {
    final rng = Random(seed);
    final paint = Paint()..color = _rose;
    for (var i = 0; i < count; i++) {
      final vx = -(0.3 + rng.nextDouble() * 1.1) * _u;
      final vy = -(0.2 + rng.nextDouble() * 0.9) * _u;
      final spin = rng.nextDouble() * 8;
      final floor = _ground - _u * (0.005 + rng.nextDouble() * 0.02);
      final age = (t - born) * 9;
      if (age <= 0) continue;
      // Corre via, poi frena nell'aria e scende ondeggiando.
      final slow = 1 - exp(-age * 2.2);
      var at =
          from +
          Offset(vx * slow / 2.2 * 2, vy * slow / 2.2 * 2) +
          Offset(sin(age * 3 + i) * _u * 0.05, _u * 0.18 * age * age * 0.25);
      final landed = at.dy >= floor;
      if (landed) at = Offset(at.dx, floor);
      canvas.save();
      canvas.translate(at.dx, at.dy);
      canvas.rotate(landed ? spin : spin + age * 4);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: _u * 0.035,
          height: _u * (landed ? 0.014 : 0.022),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  void _bouquet(Canvas canvas) {
    final (walkX, walk, stride) = _entrance();
    const shots = [0.555, 0.57, 0.585, 0.60, 0.615];
    final come = _smooth(_span(t, 0.40, 0.48));
    final offer = _smooth(_span(t, 0.48, 0.51));
    final leave = _smooth(_span(t, 0.74, 0.86));
    final suitorX = _mix(
      _mix(_hiddenX, _victimX + _u * 0.92, come),
      _hiddenX,
      leave,
    );
    final barrel = _smooth(_span(t, 0.532, 0.545));
    var recoil = 0.0;
    for (final shot in shots) {
      final k = _span(t, shot, shot + 0.012);
      if (k > 0 && k < 1) recoil = sin(pi * k);
    }
    final arm = _mix(1.25, 1.45, offer) + 0.10 * recoil;
    final elbow = _mix(0.9, 0.5, offer);
    final lean = 0.10 * offer - 0.08 * recoil;
    final facing = leave > 0.08 ? 1 : -1;
    final feet = Offset(suitorX, _ground);
    _person(
      canvas,
      feet: feet,
      facing: facing,
      walk: _prowl,
      stride: (come > 0 && come < 1) || (leave > 0 && leave < 1) ? 0.7 : 0,
      lean: leave > 0 ? 0.04 : lean,
      arm: leave > 0 ? 1.2 : arm,
      elbow: leave > 0 ? 0.8 : elbow,
      backArm: leave > 0 ? -0.1 : _mix(-0.1, 1.2, offer),
      backElbow: 0.4,
      killer: true,
    );
    final (hand, along) = _grip(
      feet,
      facing: facing,
      lean: leave > 0 ? 0.04 : lean,
      arm: leave > 0 ? 1.2 : arm,
      elbow: leave > 0 ? 0.8 : elbow,
    );
    final fired = shots.where((shot) => t >= shot).length;
    final dir = leave > 0 ? along : Offset(-1, 0.05 + 0.1 * (1 - offer));
    // Il mazzo va davanti a chi lo riceve, ma resta dietro l'angolo finché
    // chi lo porta non ne è uscito.
    void bouquet() {
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(-_w, -_h, _cornerX, _h * 2));
      _bouquetShape(
        canvas,
        hand,
        dir,
        roses: 7 - fired,
        barrel: leave > 0 ? 1 : barrel,
      );
      canvas.restore();
    }

    final muzzle =
        hand +
        dir / dir.distance * (_u * (0.29 + 0.17 * (leave > 0 ? 1 : barrel)));
    _wall(canvas);

    // Il colpo di fulmine: si avvicina ad annusare, cuore; poi vede la canna.
    final sniff =
        _smooth(_span(t, 0.50, 0.525)) * (1 - _smooth(_span(t, 0.535, 0.548)));
    var jolt = 0.0;
    for (final (i, shot) in shots.indexed) {
      final k = _span(t, shot, shot + 0.012);
      if (k > 0 && k < 1) jolt = (i.isEven ? -1 : -0.6) * sin(pi * k);
    }
    final fall = _span(t, 0.625, 0.72);
    _pool(
      canvas,
      Offset(_victimX - _u * 0.50, _ground + _u * 0.04),
      _smooth(_span(t, 0.70, 0.86)),
    );
    _victim(
      canvas,
      x: walkX,
      walk: walk,
      stride: stride,
      fall: fall,
      lean:
          0.25 * sniff -
          0.12 * _span(t, 0.535, 0.55) * (t < 0.555 ? 1 : 0) +
          0.25 * jolt,
      arm: t < 0.555 ? _mix(0.08, 0.9, sniff) : 1.6 + jolt,
      elbow: t < 0.555 ? _mix(0.2, 1.2, sniff) : 1.0,
      smoking: t > 0.37 && t < 0.50,
    );
    bouquet();
    _hatOff(canvas, 0.625, 0.80, height: 0.5);
    final love = _span(t, 0.505, 0.545);
    if (love > 0 && love < 1) {
      _heart(
        canvas,
        Offset(_victimX + _u * 0.08, _ground - _u * (1.25 + 0.25 * love)),
        _u * (0.07 + 0.02 * sin(love * 30).abs()),
        const Color(0xFFE23A4A).withValues(alpha: 1 - love * love),
      );
    }
    if (t < 0.555) {
      _exclaim(
        canvas,
        Offset(_victimX + _u * 0.05, _ground - _u * 1.40),
        _span(t, 0.540, 0.575),
      );
    }

    // La raffica fra le rose: lampi, petali dappertutto, bossoli.
    final target = Offset(_victimX + _u * 0.04, _ground - _u * 0.72);
    for (final (i, shot) in shots.indexed) {
      _muzzleFlash(
        canvas,
        muzzle,
        _span(t, shot, shot + 0.012),
        toward: const Offset(-1, 0),
        size: 0.8,
      );
      final bang = _span(t, shot, shot + 0.02);
      if (bang > 0 && bang < 1) {
        final hit = target + Offset(0, _u * 0.07 * (i - 2));
        canvas.drawLine(
          Offset.lerp(muzzle, hit, bang * 0.5)!,
          Offset.lerp(muzzle, hit, min(1, bang * 0.5 + 0.5))!,
          Paint()
            ..color = _warmF.withValues(alpha: 0.9 * (1 - bang))
            ..strokeWidth = _u * 0.010,
        );
      }
      _petals(canvas, muzzle, shot, seed: 130 + i, count: 9);
      _spray(
        canvas,
        target + Offset(0, _u * 0.07 * (i - 2)),
        _span(t, shot, shot + 0.14),
        seed: 140 + i,
        count: 8,
      );
    }
    _casings(canvas, hand.translate(0, -_u * 0.05), shots);
    _puff(
      canvas,
      muzzle.translate(-_u * 0.05, -_u * 0.08),
      _span(t, 0.56, 0.70),
      size: 0.6,
    );
  }

  // ------------------------------------------------------------- lavanderia

  /// Il furgone della lavanderia, visto di fianco, col retro in [rear] e il
  /// muso a sinistra. [door] apre la porta scorrevole (da 0 a 1).
  Rect _laundryVan(
    Canvas canvas,
    double rear, {
    required double door,
    required void Function(Rect) inside,
  }) {
    final ink = Paint()..color = _inkF;
    final paint = Paint()..color = const Color(0xFF34465A);
    final top = _ground - _u * 0.98;
    final base = _ground - _u * 0.12;
    final front = rear - _u * 2.0;
    // Carrozzeria a cassone, cabina più bassa davanti col parabrezza.
    final body = Path()
      ..moveTo(rear, base)
      ..lineTo(rear, top + _u * 0.06)
      ..quadraticBezierTo(rear, top, rear - _u * 0.06, top)
      ..lineTo(front + _u * 0.62, top)
      ..lineTo(front + _u * 0.62, _ground - _u * 0.78)
      ..quadraticBezierTo(
        front + _u * 0.30,
        _ground - _u * 0.78,
        front + _u * 0.16,
        _ground - _u * 0.50,
      )
      ..quadraticBezierTo(front, _ground - _u * 0.46, front, base)
      ..close();
    canvas.save();
    canvas.translate(_u * 0.014, -_u * 0.012);
    canvas.drawPath(body, Paint()..color = _rimF);
    canvas.restore();
    canvas.drawPath(body, paint);
    // Il pannello dipinto: una camicia sulla gruccia, e le bolle di sapone.
    final panel = Rect.fromLTRB(
      front + _u * 0.75,
      top + _u * 0.12,
      rear - _u * 0.10,
      base - _u * 0.20,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(panel, Radius.circular(_u * 0.04)),
      Paint()..color = const Color(0xFFDCD3BC),
    );
    canvas.drawRect(
      Rect.fromLTRB(
        panel.left,
        panel.bottom - _u * 0.08,
        panel.right,
        panel.bottom - _u * 0.05,
      ),
      Paint()..color = const Color(0xFF3F6E8C),
    );
    final logo = Offset(panel.left + _u * 0.30, panel.center.dy - _u * 0.02);
    _shirt(canvas, logo, 1.0, const Color(0xFF3F6E8C));
    for (final (dx, dy, r) in const [
      (0.22, -0.18, 0.05),
      (0.30, -0.06, 0.035),
      (0.20, 0.06, 0.03),
      (-0.24, -0.14, 0.03),
    ]) {
      canvas.drawCircle(
        logo + Offset(dx, dy) * _u,
        _u * r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _u * 0.008
          ..color = const Color(0xFF3F6E8C),
      );
    }
    // Il vano della porta scorrevole: buio, con le camicie appese dentro.
    final hole = Rect.fromLTRB(
      rear - _u * 0.70,
      top + _u * 0.10,
      rear - _u * 0.14,
      base,
    );
    if (door > 0) {
      canvas.drawRect(hole, Paint()..color = const Color(0xFF15171C));
      canvas.save();
      canvas.clipRect(hole);
      canvas.drawLine(
        hole.topLeft.translate(0, _u * 0.08),
        hole.topRight.translate(0, _u * 0.08),
        Paint()
          ..color = const Color(0xFF55585F)
          ..strokeWidth = _u * 0.01,
      );
      for (final dx in [0.12, 0.42]) {
        _shirt(
          canvas,
          Offset(hole.left + _u * dx, hole.top + _u * 0.24),
          1.3,
          const Color(0xFFE8E2D2).withValues(alpha: 0.55),
        );
      }
      inside(hole);
      canvas.restore();
    }
    // La porta: un pannello del cassone che scorre verso il muso.
    final slide = _u * 0.62 * door;
    final panelDoor = hole.shift(Offset(-slide, 0));
    canvas.drawRect(panelDoor, paint);
    canvas.drawRect(
      Rect.fromLTRB(
        panelDoor.left,
        panelDoor.top,
        panelDoor.left + _u * 0.012,
        panelDoor.bottom,
      ),
      Paint()..color = _rimF.withValues(alpha: 0.7),
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: panelDoor.centerLeft.translate(_u * 0.06, 0),
        width: _u * 0.06,
        height: _u * 0.018,
      ),
      Paint()..color = _steelF,
    );
    // Parabrezza, ruote, fanale.
    canvas.drawPath(
      Path()
        ..moveTo(front + _u * 0.56, _ground - _u * 0.74)
        ..lineTo(front + _u * 0.56, _ground - _u * 0.54)
        ..lineTo(front + _u * 0.22, _ground - _u * 0.54)
        ..quadraticBezierTo(
          front + _u * 0.32,
          _ground - _u * 0.72,
          front + _u * 0.50,
          _ground - _u * 0.74,
        )
        ..close(),
      Paint()..color = const Color(0xFF3B4658),
    );
    for (final x in [rear - _u * 0.38, front + _u * 0.40]) {
      canvas.drawCircle(Offset(x, _ground - _u * 0.15), _u * 0.17, ink);
      canvas.drawCircle(
        Offset(x, _ground - _u * 0.14),
        _u * 0.10,
        Paint()..color = const Color(0xFF17181C),
      );
      canvas.drawCircle(
        Offset(x, _ground - _u * 0.14),
        _u * 0.045,
        Paint()..color = _steelF.withValues(alpha: 0.7),
      );
    }
    canvas.drawCircle(
      Offset(rear - _u * 0.03, base - _u * 0.10),
      _u * 0.03,
      Paint()..color = const Color(0xFFB3202A),
    );
    return hole;
  }

  /// Una camicia (il marchio della lavanderia, o quelle appese dentro).
  void _shirt(Canvas canvas, Offset at, double size, Color color) {
    final s = _u * 0.10 * size;
    canvas.drawLine(
      at.translate(-s * 0.8, -s * 0.95),
      at.translate(s * 0.8, -s * 0.95),
      Paint()
        ..color = color
        ..strokeWidth = s * 0.08,
    );
    canvas.drawLine(
      at.translate(0, -s * 1.25),
      at.translate(0, -s * 0.95),
      Paint()
        ..color = color
        ..strokeWidth = s * 0.08,
    );
    canvas.drawPath(
      Path()..addPolygon([
        at.translate(-s * 0.35, -s * 0.9),
        at.translate(-s * 1.0, -s * 0.5),
        at.translate(-s * 0.75, -s * 0.2),
        at.translate(-s * 0.55, -s * 0.35),
        at.translate(-s * 0.55, s * 0.9),
        at.translate(s * 0.55, s * 0.9),
        at.translate(s * 0.55, -s * 0.35),
        at.translate(s * 0.75, -s * 0.2),
        at.translate(s * 1.0, -s * 0.5),
        at.translate(s * 0.35, -s * 0.9),
      ], true),
      Paint()..color = color,
    );
  }

  void _laundry(Canvas canvas) {
    final (walkX, walk, stride) = _entrance();
    // Il furgone arriva in retromarcia e si ferma con la porta proprio dietro
    // la vittima; la porta scorre, due braccia, dentro, la porta si chiude;
    // il furgone sobbalza un po', poi riparte a tutta.
    final arrive = Curves.easeOut.transform(_span(t, 0.42, 0.50));
    final depart = Curves.easeIn.transform(_span(t, 0.70, 0.80));
    final stop = _victimX + _u * 0.95;
    final rear = _mix(-_u * 0.2, stop, arrive) - _w * 1.6 * depart;
    final open = _smooth(_span(t, 0.505, 0.53));
    final shut = _smooth(_span(t, 0.598, 0.612));
    final reach = Curves.easeOut.transform(_span(t, 0.545, _hit));
    final pull = Curves.easeIn.transform(_span(t, _hit + 0.005, 0.595));
    final rock = t > 0.615 && t < 0.70
        ? sin(t * 420) * _span(t, 0.615, 0.62) * (1 - _span(t, 0.68, 0.70))
        : 0.0;
    final victimIn = pull >= 1;
    _wall(canvas);

    // I fari in fondo alla strada, prima che arrivi.
    final glare = _span(t, 0.38, 0.44) * (1 - _span(t, 0.44, 0.48));
    if (glare > 0) {
      canvas.drawCircle(
        Offset(-_u * 0.1, _ground - _u * 0.30),
        _u * (0.3 + 0.7 * glare),
        Paint()
          ..color = _warmF.withValues(alpha: 0.45 * glare)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, _u * 0.25),
      );
    }
    canvas.save();
    canvas.translate(0, _u * 0.02 * rock);
    canvas.translate(rear, _ground);
    canvas.rotate(0.015 * rock);
    canvas.translate(-rear, -_ground);
    final hole = _laundryVan(
      canvas,
      rear,
      door: open * (1 - shut),
      inside: (hole) {
        if (!victimIn || shut >= 1) return;
        // Dentro, la sagola scalcia fra le camicie.
        _person(
          canvas,
          feet: Offset(hole.center.dx, hole.bottom + _u * 0.05),
          tilt: 0.9,
          dangle: 0.5 + 0.3 * sin(t * 300),
          arm: 2.6,
          backArm: -2.4,
          hat: victimHat,
          hatOn: false,
        );
      },
    );
    canvas.restore();
    final doorX = hole.center.dx;

    // Le braccia che escono dal buio e lo afferrano.
    final grab = reach * (1 - shut);
    final chest = Offset(
      _mix(walkX, doorX, pull),
      _mix(_ground - _u * 0.70, hole.center.dy, pull),
    );
    if (grab > 0 && !victimIn) {
      final arm = Paint()..color = _inkF;
      final rim = Paint()..color = _rimF;
      for (final dy in [-0.08, 0.10]) {
        final from = Offset(hole.left + _u * 0.05, chest.dy + _u * dy);
        final to = Offset.lerp(
          from,
          chest.translate(_u * 0.02, _u * dy),
          grab,
        )!;
        _limb(
          canvas,
          from.translate(-_u * 0.01, -_u * 0.01),
          to.translate(-_u * 0.01, -_u * 0.01),
          _u * 0.045,
          _u * 0.036,
          rim,
        );
        _limb(canvas, from, to, _u * 0.045, _u * 0.036, arm);
        canvas.drawCircle(to, _u * 0.042, arm);
        canvas.drawCircle(to, _u * 0.030, Paint()..color = _cream);
      }
    }

    // La vittima: si gira verso il furgone, poi viene tirata su e dentro.
    if (!victimIn) {
      final look = _smooth(_span(t, 0.51, 0.53));
      canvas.save();
      final lift = _u * 0.25 * sin(pi / 2 * pull);
      canvas.translate(_mix(walkX, doorX, pull) - walkX, -lift);
      canvas.translate(walkX, _ground);
      canvas.scale(1 - 0.18 * pull);
      canvas.translate(-walkX, -_ground);
      if (t < _hit) {
        _victim(
          canvas,
          x: walkX,
          walk: walk,
          stride: stride,
          lean: -0.10 * look,
          smoking: t > 0.37 && t < _hit,
        );
      } else {
        _person(
          canvas,
          feet: Offset(walkX, _ground),
          tilt: 0.5 * pull,
          dangle: 0.4 + 0.4 * sin(t * 320),
          arm: 2.5,
          backArm: -2.2,
          hat: victimHat,
          hatOn: false,
        );
      }
      canvas.restore();
    }
    if (t < _hit) {
      _exclaim(
        canvas,
        Offset(_victimX, _ground - _u * 1.40),
        _span(t, 0.53, 0.56),
      );
    }

    // Resta il cappello per terra, e una scarpa.
    final hatFall = _span(t, _hit, 0.62);
    if (t >= _hit) {
      _looseHat(
        canvas,
        Offset(
          _victimX + _u * 0.25 * hatFall,
          _mix(
                _ground - _u * 1.02,
                _ground - _u * 0.03,
                Curves.easeIn.transform(hatFall),
              ) -
              _u * 0.3 * sin(pi * hatFall),
        ),
        hatFall < 1 ? hatFall * 5 : 0.15,
      );
    }
    final shoe = _span(t, 0.58, 0.63);
    if (shoe > 0) {
      final at = Offset(
        _victimX - _u * 0.25 * shoe,
        _mix(
          _ground - _u * 0.55,
          _ground - _u * 0.03,
          Curves.easeIn.transform(shoe),
        ),
      );
      canvas.save();
      canvas.translate(at.dx, at.dy);
      canvas.rotate(shoe < 1 ? shoe * 7 : 0);
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTRB(-_u * 0.07, -_u * 0.045, _u * 0.08, 0),
          topLeft: Radius.circular(_u * 0.02),
          topRight: Radius.circular(_u * 0.045),
        ),
        Paint()..color = _inkF,
      );
      canvas.restore();
    }

    // Le bolle di sapone che escono dal furgone che sobbalza, e il fumo
    // quando riparte.
    for (var i = 0; i < 9; i++) {
      final life = _span(t, 0.61 + i * 0.012, 0.70 + i * 0.012);
      if (life <= 0 || life >= 1) continue;
      final from = Offset(
        rear - _u * (0.2 + 0.07 * (i % 4)),
        _ground - _u * (0.6 + 0.05 * (i % 3)),
      );
      final at =
          from +
          Offset(
            sin(life * 6 + i) * _u * 0.1 + _u * 0.15 * life,
            -_u * 0.8 * life,
          );
      final r = _u * (0.025 + 0.012 * (i % 3));
      canvas.drawCircle(
        at,
        r,
        Paint()
          ..color = const Color(0xFFBFD8EA)
              .withValues(alpha: 0.18 * (1 - life)),
      );
      canvas.drawCircle(
        at,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _u * 0.006
          ..color = const Color(0xFFE6F2FA).withValues(alpha: 0.8 * (1 - life)),
      );
      canvas.drawCircle(
        at.translate(-r * 0.35, -r * 0.35),
        r * 0.2,
        Paint()..color = Colors.white.withValues(alpha: 0.8 * (1 - life)),
      );
    }
    _puff(
      canvas,
      Offset(rear + _u * 0.1, _ground - _u * 0.12),
      _span(t, 0.70, 0.78),
      size: 0.6,
    );
    _dust(
      canvas,
      Offset(stop - _u * 0.2, _ground),
      _span(t, 0.70, 0.80),
      seed: 151,
      size: 0.6,
    );
    if (depart > 0 && depart < 1) {
      _speedLines(
        canvas,
        Offset(rear, _ground - _u * 0.5),
        const Offset(-1, 0),
        length: 0.6,
        spread: 0.2,
        alpha: 0.3,
      );
    }
  }
}
