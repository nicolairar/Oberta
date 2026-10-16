part of 'death_scene.dart';

// Le varianti del Dottore, del Cecchino e del colpo andato a vuoto. Stesso
// canovaccio delle altre scene (la vittima entra, la cinepresa stringe, il
// colpo a [DeathScenePainter.strike]), stesse sagome: cambia quello che
// succede intorno.

const _sInk = DeathScenePainter._ink;
const _sRim = DeathScenePainter._rim;
const _sBlood = DeathScenePainter._blood;
const _sSteel = DeathScenePainter._steel;
const _sWarm = DeathScenePainter._warm;
const _sStrike = DeathScenePainter.strike;

/// Il camice del Dottore e degli infermieri.
const _doctorWhite = Color(0xFFE9E4D8);
const _heartGreen = Color(0xFF8BE0A4);
const _bandageWhite = Color(0xFFF2EEE6);

extension _SaveFilms on DeathScenePainter {
  // ------------------------------------------------------------- cinepresa

  /// Quanto si allarga la cinepresa quando arriva il Dottore: per
  /// l'ambulanza ancora di più, deve starci il furgone.
  double get _rescueWiden => act == DeathAct.ambulance ? 0.30 : 0.17;

  /// Di quanto si sposta verso sinistra, per tenere in campo chi soccorre.
  double get _rescueShift => act == DeathAct.ambulance ? 0.62 : 0.50;

  /// Dopo il colpo la cinepresa si sposta verso destra di tanto (in unità di
  /// figura), dove il killer resta in scena: a terra sulla buccia, o col
  /// gatto in testa.
  double get _settleNudge => switch (act) {
    DeathAct.banana => 0.55,
    DeathAct.jam || DeathAct.blackCat => 0.30,
    _ => 0,
  };

  /// L'arma del killer nei colpi a vuoto: la pistola, o quella dell'agguato
  /// che la fortuna sta mandando a vuoto.
  _Prop get _weapon => switch (_armedWith) {
    DeathAct.knife => _Prop.knife,
    DeathAct.bat => _Prop.bat,
    DeathAct.lupara => _Prop.lupara,
    DeathAct.burst => _Prop.tommy,
    _ => _Prop.pistol,
  };

  /// Vero se l'arma spara: il colpo parte lo stesso, ma va in cielo.
  bool get _fires => switch (_weapon) {
    _Prop.pistol || _Prop.lupara || _Prop.tommy => true,
    _ => false,
  };

  /// Le scritte da fumetto che si aggiungono a quella del colpo.
  void _savesSfx(Canvas canvas) {
    switch (act) {
      case DeathAct.defibrillator:
        _word(canvas, 'ZAP!', 0.735, 0.03, const Color(0xFFA8D8FF));
        _word(canvas, 'ZAP!', 0.770, 0.03, const Color(0xFFA8D8FF));
        _word(canvas, 'TU-TUM!', 0.782, 0.05, _heartGreen);
      case DeathAct.pliers:
        _word(canvas, 'PLINK!', 0.786, 0.045, const Color(0xFFDDE9F0));
      case DeathAct.ambulance:
        _word(canvas, 'WEE-OO!', 0.615, 0.06, const Color(0xFFA8C4FF));
      case DeathAct.stitches:
        _word(canvas, 'SNIP!', 0.785, 0.045, const Color(0xFFDDE9F0));
      case DeathAct.belfry:
        _word(canvas, 'DONG!', 0.64, 0.07, const Color(0xFFFFE27A));
      case DeathAct.jam:
        _word(canvas, 'CLICK!', 0.585, 0.05, const Color(0xFFDDE9F0));
      default:
        break;
    }
  }

  // ------------------------------------------------------- il Dottore, comune

  /// Dove si inginocchia il Dottore: accanto alla testa di chi è a terra.
  double get _kneelX => _victimX - _u * 0.78;

  /// Il Dottore arriva di corsa da sinistra.
  double get _doctorCome => _span(t, 0.60, 0.665);

  double get _doctorX => _mix(-_w * 0.45, _kneelX, Curves.easeOut.transform(_doctorCome));

  /// In ginocchio accanto al petto, finché non lo rimette in piedi.
  double get _doctorKneel => _smooth(_span(t, 0.665, 0.685)) - _smooth(_span(t, 0.80, 0.835));

  /// Il braccio del Dottore quando ha finito: tende la mano a chi si rialza,
  /// poi si tocca il cappello.
  (double, double) _doctorDone() {
    final helping = _smooth(_span(t, 0.80, 0.83)) - _smooth(_span(t, 0.86, 0.88));
    final salute = _smooth(_span(t, 0.875, 0.90));
    return (_mix(_mix(0.3, 1.45, helping), 2.35, salute), _mix(_mix(0.3, 0.2, helping), 1.25, salute));
  }

  /// Il Dottore col camice bianco e la bombetta.
  void _doctor(
    Canvas canvas, {
    required Offset feet,
    int facing = 1,
    bool running = false,
    double lean = 0,
    double crouch = 0,
    double arm = 0.3,
    double elbow = 0.3,
    double backArm = -0.1,
    double backElbow = 0.2,
    _Prop prop = _Prop.none,
    AvatarHead hat = AvatarHead.bowler,
  }) {
    _person(
      canvas,
      feet: feet,
      facing: facing,
      walk: t * 300,
      stride: running ? 1 : 0,
      lean: lean,
      crouch: crouch,
      arm: arm,
      elbow: elbow,
      backArm: backArm,
      backElbow: backElbow,
      hat: hat,
      cloth: _doctorWhite,
      prop: prop,
    );
  }

  /// La parte comune dei salvataggi: la vittima entra, il killer spara
  /// dall'angolo e se ne va, la vittima va giù. Da [wakeAt] si tira su a
  /// sedere, poi in piedi, e saluta. [jolt] la fa sobbalzare da stesa;
  /// [lift] la solleva da terra (sulla barella); [mark] è quello che le
  /// resta sul petto: una fascia, una garza ricucita, o niente.
  void _savedVictim(
    Canvas canvas, {
    double wakeAt = 0.80,
    double jolt = 0,
    _Mark mark = _Mark.sash,
    bool getsUp = true,
  }) {
    final (walkX, walk, stride) = _entrance();
    final bang = _span(t, _sStrike, _sStrike + 0.025);
    final fall = _span(t, _sStrike + 0.01, _sStrike + 0.07);
    final wake = getsUp ? _span(t, wakeAt, wakeAt + 0.05) : 0.0;
    if (wake <= 0) {
      final lying = fall >= 1 && jolt > 0;
      if (lying) {
        // Il petto che salta su con la scarica: il corpo si inarca.
        canvas.save();
        canvas.translate(_victimX, _ground);
        canvas.rotate(0.16 * jolt);
        canvas.translate(-_victimX, -_ground - _u * 0.09 * jolt);
      }
      _victim(
        canvas,
        x: walkX,
        facing: t < 0.37 ? 1 : -1,
        walk: walk,
        stride: stride,
        fall: fall,
        lean: bang > 0 && bang < 1 ? 0.20 * sin(pi * bang) : 0,
        smoking: t > 0.37 && t < _sStrike,
      );
      if (lying) canvas.restore();
      return;
    }
    final sit = Curves.easeOut.transform(_span(wake, 0, 0.4));
    final stand = _smooth(_span(wake, 0.4, 1));
    final tilt = -1.30 * (1 - sit * 0.55) * (1 - stand);
    final crouch = 0.95 * (1 - stand);
    final wave = _smooth(_span(t, wakeAt + 0.055, wakeAt + 0.075));
    final feet = Offset(_victimX, _ground);
    final lean = 0.10 * (1 - stand);
    _person(
      canvas,
      feet: feet,
      facing: -1,
      tilt: tilt,
      crouch: crouch,
      lean: lean,
      arm: _mix(_mix(2.3, 1.45, sit), 2.7 + 0.2 * sin(t * 140), wave),
      elbow: _mix(0.25, 0.45, wave),
      backArm: _mix(-1.3, -0.1, stand),
      hat: victimHat,
      hatOn: false,
    );
    Offset body(Offset at) => _onBody(at, feet: feet, facing: -1, tilt: tilt, crouch: crouch, lean: lean);
    switch (mark) {
      case _Mark.none:
        break;
      case _Mark.sash:
        canvas.drawLine(
          body(const Offset(0.10, -0.33)),
          body(const Offset(-0.11, -0.10)),
          Paint()
            ..color = _bandageWhite
            ..strokeWidth = _u * 0.055
            ..strokeCap = StrokeCap.round,
        );
      case _Mark.stitched:
        // La garza sul petto, con i punti neri sopra.
        final centre = body(const Offset(0.05, -0.24));
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: centre, width: _u * 0.10, height: _u * 0.13),
            Radius.circular(_u * 0.015),
          ),
          Paint()..color = _bandageWhite,
        );
        final thread = Paint()
          ..color = _sInk
          ..strokeWidth = _u * 0.008;
        for (final dy in [-0.035, 0.0, 0.035]) {
          final c = centre.translate(0, _u * dy);
          canvas.drawLine(c.translate(-_u * 0.025, -_u * 0.012), c.translate(_u * 0.025, _u * 0.012), thread);
          canvas.drawLine(c.translate(-_u * 0.025, _u * 0.012), c.translate(_u * 0.025, -_u * 0.012), thread);
        }
    }
  }

  /// Il killer all'angolo, il muro, il cappello che vola e gli schizzi del
  /// colpo: l'agguato che il Dottore poi rimedia.
  void _ambush(Canvas canvas) {
    // Sopra un agguato della famiglia, l'agguato c'è già.
    if (_cut == _Cut.rescue) return;
    _gunman(canvas, leaveAt: 0.60);
    _wall(canvas);
    _hatOff(canvas, _sStrike + 0.01, _sStrike + 0.20, height: 0.9);
  }

  void _ambushSpray(Canvas canvas) {
    if (_cut == _Cut.rescue) return;
    _spray(canvas, Offset(_victimX, _ground - _u * 0.74), _span(t, _sStrike, _sStrike + 0.16), seed: 95, count: 9);
    _flash(canvas, _span(t, _sStrike, _sStrike + 0.025), strength: 0.4);
  }

  /// Il cuore che riparte: una croce verde che pulsa sopra il petto, con le
  /// scintille intorno.
  void _cure(Canvas canvas, double from, double to) {
    final cure = _span(t, from, to);
    if (cure <= 0 || cure >= 1) return;
    final heart = Offset(_victimX - _u * 0.50, _ground - _u * (0.30 + 0.14 * cure));
    final beat = sin(cure * pi * 6).abs();
    final pulse = 1 + 0.25 * beat;
    final fade = 1 - cure * cure;
    _sprite(canvas, sprites?.glow, heart, _u * 0.9 * pulse, opacity: 0.55 * fade, tint: _heartGreen);
    canvas.drawCircle(heart, _u * 0.10 * pulse, Paint()..color = _doctorWhite.withValues(alpha: fade));
    _cross(canvas, heart, _u * 0.065 * pulse);
    for (var i = 0; i < 5; i++) {
      final angle = cure * 5 + i * 2 * pi / 5;
      _star(
        canvas,
        heart + Offset(cos(angle), sin(angle) * 0.6) * (_u * (0.24 + 0.22 * cure)),
        _u * 0.04,
        AppColors.gold.withValues(alpha: fade),
      );
    }
  }

  /// Il petto di chi è steso a terra, dove lavora il Dottore.
  Offset get _chestDown => Offset(_victimX - _u * 0.52, _ground - _u * 0.165);

  // ---------------------------------------------------------- defibrillatore

  /// Il Dottore arriva con la cassetta, sfrega le piastre e dà la scossa:
  /// la prima non basta, la seconda fa ripartire il cuore.
  void _defibrillator(Canvas canvas) {
    _ambush(canvas);
    const shocks = [0.735, 0.770];
    var jolt = 0.0;
    for (final at in shocks) {
      final life = _span(t, at, at + 0.022);
      if (life > 0 && life < 1) jolt = max(jolt, sin(pi * life));
    }
    _savedVictim(canvas, jolt: jolt, mark: _Mark.none);

    final come = _doctorCome;
    if (come <= 0) return _ambushSpray(canvas);
    final x = _doctorX;
    final feet = Offset(x, _ground);
    final kneel = _doctorKneel;
    final box = Offset(x - _u * 0.34, _ground - _u * 0.085);
    final charge = _span(t, 0.69, 0.728);
    final working = t > 0.685 && t < 0.80;
    final rub = charge > 0 && charge < 1 ? sin(t * 900) * 0.10 : 0.0;
    var (arm, elbow, backArm, backElbow) = (0.3, 0.3, -0.1, 0.2);
    if (come < 1) {
      (arm, elbow) = (0.45, 0.9);
    } else if (working) {
      // Su le piastre a sfregarle, giù sul petto per la scossa, su di nuovo
      // a guardare il monitor.
      var down = 0.0;
      for (final at in shocks) {
        down = max(down, _smooth(_span(t, at - 0.008, at)) - _smooth(_span(t, at + 0.012, at + 0.022)));
      }
      final raise = _smooth(_span(t, 0.685, 0.70));
      final rest = _smooth(_span(t, 0.785, 0.80));
      arm = _mix(_mix(0.9, 1.40 + rub, raise), 1.02, down);
      elbow = _mix(_mix(0.5, 0.25, raise), 0.50, down);
      backArm = _mix(_mix(0.5, 1.28 - rub, raise), 0.86, down);
      backElbow = _mix(_mix(0.4, 0.40, raise), 0.62, down);
      arm = _mix(arm, 0.6, rest);
      backArm = _mix(backArm, 0.4, rest);
    } else if (t >= 0.80) {
      (arm, elbow) = _doctorDone();
    }
    final lean = come < 1 ? 0.22 : 0.45 * kneel;
    final crouch = 0.9 * kneel;

    // La cassetta: posata a terra, col monitor che prima è piatto e dopo la
    // seconda scossa batte.
    final carried = come < 1;
    final (hand, along) = _handOf(feet: feet, lean: lean, crouch: crouch, arm: arm, elbow: elbow);
    final (backHand, backAlong) = _handOf(
      feet: feet,
      lean: lean,
      crouch: crouch,
      arm: backArm,
      elbow: backElbow,
      back: true,
    );
    final boxAt = carried ? hand.translate(0, _u * 0.10) : box;
    _defibBox(canvas, boxAt, beating: t > 0.778);
    _doctor(
      canvas,
      feet: feet,
      running: come < 1,
      lean: lean,
      crouch: crouch,
      arm: arm,
      elbow: elbow,
      backArm: backArm,
      backElbow: backElbow,
    );
    if (!carried && t < 0.80) {
      // I due fili dalla cassetta alle piastre.
      final cable = Paint()
        ..color = const Color(0xFF2A2C31)
        ..style = PaintingStyle.stroke
        ..strokeWidth = _u * 0.012;
      for (final end in [backHand, hand]) {
        final from = boxAt.translate(_u * 0.06, -_u * 0.08);
        canvas.drawPath(
          Path()
            ..moveTo(from.dx, from.dy)
            ..quadraticBezierTo((from.dx + end.dx) / 2, max(from.dy, end.dy) + _u * 0.12, end.dx, end.dy),
          cable,
        );
      }
      _paddle(canvas, backHand, backAlong);
      _paddle(canvas, hand, along);
      // Mentre le sfrega, le piastre fanno scintille.
      if (charge > 0 && charge < 1) {
        final mid = Offset.lerp(hand, backHand, 0.5)!;
        _sprite(
          canvas,
          sprites?.electric,
          mid,
          _u * (0.18 + 0.10 * sin(t * 700).abs()) * charge,
          opacity: 0.9,
          rotation: t * 300,
          tint: const Color(0xFFA8D8FF),
        );
        _bolt(canvas, hand, backHand, seed: (t * 400).floor(), life: 0.3);
      }
    }
    // Le scosse: lampi azzurri dalle piastre al petto.
    for (final at in shocks) {
      final life = _span(t, at, at + 0.02);
      if (life <= 0 || life >= 1) continue;
      final chest = _chestDown;
      for (final (i, from) in [hand, backHand].indexed) {
        _bolt(canvas, from, chest, seed: (t * 500).floor() + i * 7, life: life);
      }
      _sprite(
        canvas,
        sprites?.electric,
        chest,
        _u * 0.75 * (1 - life * 0.4),
        opacity: 1 - life,
        rotation: life * 4,
        tint: const Color(0xFFA8D8FF),
      );
      _sprite(canvas, sprites?.glow, chest, _u * 1.4, opacity: 0.6 * (1 - life), tint: const Color(0xFF8FC8FF));
      canvas.drawRect(
        Rect.fromLTWH(-_w, -_h, _w * 3, _h * 3),
        Paint()..color = const Color(0xFFBFDFFF).withValues(alpha: 0.30 * (1 - life) * (1 - life)),
      );
    }
    _ambushSpray(canvas);
    _cure(canvas, 0.778, 0.80);
  }

  /// Un lampo elettrico frastagliato da [from] a [to].
  void _bolt(Canvas canvas, Offset from, Offset to, {required int seed, double life = 0}) {
    final rng = Random(seed);
    final delta = to - from;
    final side = Offset(-delta.dy, delta.dx) / max(delta.distance, 0.001);
    final path = Path()..moveTo(from.dx, from.dy);
    const steps = 6;
    for (var i = 1; i < steps; i++) {
      final p = from + delta * (i / steps) + side * ((rng.nextDouble() * 2 - 1) * _u * 0.05);
      path.lineTo(p.dx, p.dy);
    }
    path.lineTo(to.dx, to.dy);
    final fade = 1 - life;
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF8FC8FF).withValues(alpha: 0.6 * fade)
        ..style = PaintingStyle.stroke
        ..strokeWidth = _u * 0.028
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, _u * 0.012),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: fade)
        ..style = PaintingStyle.stroke
        ..strokeWidth = _u * 0.010
        ..strokeJoin = StrokeJoin.round,
    );
  }

  /// Una piastra del defibrillatore: impugnatura rossa e piatto d'acciaio.
  void _paddle(Canvas canvas, Offset hand, Offset along) {
    final across = Offset(-along.dy, along.dx);
    canvas.drawLine(
      hand - along * (_u * 0.015),
      hand + along * (_u * 0.045),
      Paint()
        ..color = const Color(0xFF8A1E26)
        ..strokeWidth = _u * 0.032
        ..strokeCap = StrokeCap.round,
    );
    final plate = hand + along * (_u * 0.06);
    canvas.drawLine(
      plate - across * (_u * 0.05),
      plate + across * (_u * 0.05),
      Paint()
        ..color = _sSteel
        ..strokeWidth = _u * 0.026
        ..strokeCap = StrokeCap.round,
    );
  }

  /// La cassetta del defibrillatore, col monitor del cuore.
  void _defibBox(Canvas canvas, Offset center, {required bool beating}) {
    final body = Rect.fromCenter(center: center, width: _u * 0.27, height: _u * 0.17);
    canvas.drawArc(
      Rect.fromCenter(center: body.topCenter, width: _u * 0.10, height: _u * 0.08),
      pi,
      pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _u * 0.016
        ..color = const Color(0xFF2A2C31),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, Radius.circular(_u * 0.02)),
      Paint()..color = const Color(0xFF6B4423),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(body.deflate(_u * 0.012), Radius.circular(_u * 0.012)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _u * 0.006
        ..color = const Color(0xFFB08A3E),
    );
    final screen = Rect.fromLTWH(body.left + _u * 0.03, body.top + _u * 0.035, _u * 0.13, _u * 0.08);
    canvas.drawRect(screen, Paint()..color = const Color(0xFF0B2016));
    final trace = Path();
    const n = 26;
    for (var i = 0; i <= n; i++) {
      final x = screen.left + screen.width * i / n;
      var y = screen.center.dy;
      if (beating) {
        final phase = (i / n - t * 18) % 1;
        if (phase > 0.40 && phase < 0.47) y -= screen.height * 0.42;
        if (phase >= 0.47 && phase < 0.52) y += screen.height * 0.25;
      } else {
        y += sin(i * 1.7 + t * 300) * screen.height * 0.03;
      }
      i == 0 ? trace.moveTo(x, y) : trace.lineTo(x, y);
    }
    canvas.drawPath(
      trace,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _u * 0.008
        ..color = _heartGreen,
    );
    _sprite(canvas, sprites?.glow, screen.center, _u * 0.28, opacity: beating ? 0.5 : 0.2, tint: _heartGreen);
    // La spia: rossa finché il cuore è fermo, verde dopo.
    canvas.drawCircle(
      Offset(body.right - _u * 0.05, body.top + _u * 0.05),
      _u * 0.018,
      Paint()..color = beating ? _heartGreen : (sin(t * 200) > 0 ? const Color(0xFFE23A4A) : const Color(0xFF5A1A1E)),
    );
    canvas.drawCircle(
      Offset(body.right - _u * 0.05, body.bottom - _u * 0.05),
      _u * 0.025,
      Paint()..color = const Color(0xFF2A2C31),
    );
  }

  // ------------------------------------------------------------------ pinze

  /// Il Dottore fruga nella ferita con le pinze, tira fuori il proiettile, lo
  /// mostra e lo lascia cadere nella bacinella. Poi la fascia.
  void _pliers(Canvas canvas) {
    _ambush(canvas);
    _savedVictim(canvas);
    final come = _doctorCome;
    if (come <= 0) return _ambushSpray(canvas);
    final x = _doctorX;
    final feet = Offset(x, _ground);
    final kneel = _doctorKneel;
    final tray = Offset(x - _u * 0.20, _ground - _u * 0.022);

    final dig = _span(t, 0.69, 0.74);
    final yank = _smooth(_span(t, 0.74, 0.752));
    final drop = _smooth(_span(t, 0.768, 0.782));
    final wrap = _span(t, 0.785, 0.80);
    final rub = dig > 0 && dig < 1 ? sin(t * 520) * 0.07 : 0.0;
    var (arm, elbow) = (0.3, 0.3);
    var (backArm, backElbow) = (-0.1, 0.2);
    var lean = come < 1 ? 0.22 : 0.45 * kneel;
    if (come >= 1 && t < 0.80) {
      // Giù nella ferita, su di scatto col piombo, indietro sopra la bacinella.
      arm = _mix(_mix(1.02 + rub, 2.55, yank), -0.35, drop);
      elbow = _mix(_mix(0.55, 0.25, yank), 0.25, drop);
      backArm = _mix(0.9, 0.4, yank);
      backElbow = 0.5;
      lean = _mix(lean, 0.20, yank * (1 - drop));
      if (wrap > 0) {
        final circle = sin(t * 380) * 0.10;
        (arm, elbow, backArm) = (1.05 + circle, 0.4, 0.95 - circle);
      }
    } else if (t >= 0.80) {
      (arm, elbow) = _doctorDone();
    }
    final crouch = 0.9 * kneel;

    if (come >= 1) {
      _bag(canvas, Offset(x - _u * 0.36, _ground - _u * 0.07), _u);
      _kidneyDish(canvas, tray);
    }
    _doctor(
      canvas,
      feet: feet,
      running: come < 1,
      lean: lean,
      crouch: crouch,
      arm: arm,
      elbow: elbow,
      backArm: backArm,
      backElbow: backElbow,
      prop: come < 1 ? _Prop.bag : _Prop.none,
    );
    final (hand, along) = _handOf(feet: feet, lean: lean, crouch: crouch, arm: arm, elbow: elbow);
    final holding = t > 0.745 && t < 0.782;
    if (come >= 1 && t > 0.685 && t < 0.785) {
      _drawPliers(canvas, hand, along, open: dig > 0 && dig < 1 ? 0.5 + 0.5 * sin(t * 400) : 0, bullet: holding);
    }
    final tip = hand + along * (_u * 0.21);
    // Il piombo in alto, che luccica.
    if (holding && yank > 0.9) {
      final shine = sin(pi * _span(t, 0.752, 0.775));
      _sprite(canvas, sprites?.glint, tip, _u * 0.45 * shine, opacity: shine);
      _star(canvas, tip, _u * 0.04 * shine, Colors.white.withValues(alpha: shine));
    }
    // E giù nella bacinella, con un rimbalzo.
    final fallen = _span(t, 0.782, 0.788);
    if (fallen > 0) {
      final start = _handOf(feet: feet, lean: 0.45, crouch: 0.9, arm: -0.35, elbow: 0.25);
      final from = start.$1 + start.$2 * (_u * 0.21);
      final bounce = sin(pi * _span(t, 0.788, 0.796)) * _u * 0.05;
      final at = Offset(_mix(from.dx, tray.dx, fallen), _mix(from.dy, tray.dy - _u * 0.02, fallen * fallen) - bounce);
      _slug(canvas, at);
      final ping = _span(t, 0.787, 0.80);
      if (ping > 0 && ping < 1) {
        _sprite(canvas, sprites?.glint, tray.translate(0, -_u * 0.03), _u * 0.5 * (1 - ping), opacity: 1 - ping);
      }
    }
    // Due goccioline quando il piombo viene via.
    _spray(canvas, _chestDown, _span(t, 0.742, 0.79), seed: 41, count: 6, bias: const Offset(0.1, -1.1), reach: 0.5);
    // La fascia stretta in fretta, giro dopo giro.
    if (wrap > 0 && t < 0.80) {
      for (final (dx, grow) in [(-0.56, wrap), (-0.46, _span(wrap, 0.4, 1))]) {
        if (grow <= 0) continue;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(
              _victimX + _u * (dx - 0.035),
              _ground - _u * (0.015 + 0.165 * grow),
              _victimX + _u * (dx + 0.035),
              _ground - _u * 0.008,
            ),
            Radius.circular(_u * 0.012),
          ),
          Paint()..color = _bandageWhite,
        );
      }
    }
    _ambushSpray(canvas);
  }

  /// Le pinze del Dottore, aperte di [open], col piombo stretto in punta.
  void _drawPliers(Canvas canvas, Offset hand, Offset along, {double open = 0, bool bullet = false}) {
    final across = Offset(-along.dy, along.dx);
    final pivot = hand + along * (_u * 0.08);
    final tip = hand + along * (_u * 0.21);
    final steel = Paint()
      ..color = _sSteel
      ..strokeWidth = _u * 0.016
      ..strokeCap = StrokeCap.round;
    final grip = Paint()
      ..color = const Color(0xFF8A1E26)
      ..strokeWidth = _u * 0.022
      ..strokeCap = StrokeCap.round;
    for (final side in [-1.0, 1.0]) {
      final end = hand - along * (_u * 0.07) + across * (side * _u * 0.028);
      canvas.drawLine(end, pivot, steel);
      canvas.drawLine(end, Offset.lerp(end, pivot, 0.55)!, grip);
      canvas.drawLine(pivot, tip + across * (side * _u * (0.008 + 0.018 * open)), steel..strokeWidth = _u * 0.012);
    }
    canvas.drawCircle(pivot, _u * 0.014, Paint()..color = const Color(0xFF9AA0A7));
    if (bullet) _slug(canvas, tip);
  }

  /// Il proiettile, schiacciato in punta.
  void _slug(Canvas canvas, Offset at) {
    canvas.drawOval(
      Rect.fromCenter(center: at, width: _u * 0.034, height: _u * 0.026),
      Paint()..color = const Color(0xFFD9A441),
    );
    canvas.drawCircle(at.translate(-_u * 0.006, -_u * 0.005), _u * 0.006, Paint()..color = const Color(0xFFFFF0C0));
  }

  /// La bacinella smaltata a forma di fagiolo.
  void _kidneyDish(Canvas canvas, Offset center) {
    final dish = Rect.fromCenter(center: center, width: _u * 0.17, height: _u * 0.045);
    canvas.drawOval(dish, Paint()..color = const Color(0xFFDDE9F0));
    canvas.drawOval(dish.deflate(_u * 0.008), Paint()..color = const Color(0xFF9FB2BE));
    canvas.drawOval(dish.deflate(_u * 0.008).translate(0, -_u * 0.006), Paint()..color = const Color(0xFFC7D6DE));
  }

  // ------------------------------------------------------------- ambulanza

  /// Il furgone bianco arriva a sirene spiegate, il Dottore e l'infermiere
  /// scendono con la barella, ci caricano su chi è a terra e lo portano via:
  /// dalla barella, saluta.
  void _ambulance(Canvas canvas) {
    _ambush(canvas);
    // Sopra un agguato il furgone arriva più tardi, a cose fatte, e
    // inchioda più di scatto.
    final late = _cut == _Cut.rescue;
    final arrive = Curves.easeOutCubic.transform(_span(t, late ? 0.625 : 0.585, 0.655));
    final vanFront = _mix(-_w * 0.2, _victimX + _u * 0.30, arrive);
    final stopped = arrive >= 1;
    final nod = stopped ? sin(pi * _span(t, 0.655, 0.675)) * 0.025 : 0.0;
    final siren = _span(t, late ? 0.59 : 0.56, late ? 0.63 : 0.60);
    _sirenGlow(canvas, Offset(vanFront - _u * 0.62, _ground - _u * 1.03), siren);

    // Chi è a terra, la barella e chi la porta.
    final out = _span(t, 0.672, 0.70);
    final load = _smooth(_span(t, 0.722, 0.745));
    final lift = _smooth(_span(t, 0.748, 0.77));
    final carry = _span(t, 0.80, 0.88);
    final sitUp = _smooth(_span(t, 0.775, 0.80));
    final back = _mix(0, -_u * 0.55, carry);
    final headX = _victimX - _u * 1.05 + back;
    final footX = _victimX + _u * 0.22 + back;
    final stretcherY = _ground - _u * _mix(0.05, 0.42, lift);
    final crouch = _smooth(_span(t, 0.70, 0.715)) - lift;
    final bending = crouch.clamp(0.0, 1.0) * 0.9;

    canvas.save();
    canvas.translate(0, 0);
    _van(canvas, vanFront, nod: nod, doors: _smooth(_span(t, 0.66, 0.675)));
    canvas.restore();

    final onStretcher = load > 0;
    if (!onStretcher) {
      _savedVictim(canvas, getsUp: false);
    }
    if (out > 0) {
      // La barella, prima portata in due, poi posata, poi su col carico.
      final carried = t < 0.70 || lift > 0;
      final enter = Curves.easeOut.transform(out);
      final shift = _mix(-_u * 1.1, 0, enter);
      final a = Offset(headX + shift + _u * 0.10, carried && t < 0.70 ? _ground - _u * 0.42 : stretcherY);
      final b = Offset(footX + shift - _u * 0.10, a.dy);
      if (onStretcher) {
        // Sopra la barella: steso, poi si tira su a sedere e saluta.
        final bodyFeet = Offset(_mix(_victimX, footX - _u * 0.12, load), 0);
        final rise = _mix(0, stretcherY - _ground - _u * 0.03, load);
        canvas.save();
        canvas.translate(0, rise);
        if (sitUp <= 0) {
          _corpse(canvas, bodyFeet.dx, -1);
        } else {
          final wave = _smooth(_span(t, 0.79, 0.805));
          _seated(canvas, Offset(bodyFeet.dx - _u * 0.42, _ground - _u * 0.06), recline: 1 - sitUp, wave: wave);
        }
        canvas.restore();
      }
      _stretcher(canvas, a, b, blanket: onStretcher && sitUp <= 0);
      final walking = (out > 0 && out < 1) || (carry > 0 && carry < 1);
      _doctor(
        canvas,
        feet: Offset(headX + shift - _u * 0.05, _ground),
        facing: carry > 0 ? -1 : 1,
        running: walking,
        crouch: bending,
        lean: 0.35 * bending,
        arm: carry > 0 ? -0.5 : 0.85,
        elbow: carry > 0 ? 0.3 : 0.35,
      );
      _doctor(
        canvas,
        feet: Offset(footX + shift + _u * 0.10, _ground),
        facing: -1,
        running: walking,
        crouch: bending,
        lean: 0.35 * bending,
        arm: 0.85,
        elbow: 0.35,
        hat: AvatarHead.coppola,
      );
    }
    _ambushSpray(canvas);
    // La luce della sirena passa anche sopra le figure.
    _sirenWash(canvas, siren);
  }

  /// Chi si tira su a sedere su una barella: le gambe distese verso destra,
  /// il busto che si alza da steso (di [recline]) e il braccio che saluta.
  void _seated(Canvas canvas, Offset hip, {double recline = 0, double wave = 0}) {
    void legs(Paint paint) {
      final knee = hip + Offset(_u * 0.22, -_u * 0.04);
      final foot = hip + Offset(_u * 0.44, _u * 0.01);
      _limb(canvas, hip, knee, _u * 0.058, _u * 0.046, paint);
      _limb(canvas, knee, foot, _u * 0.046, _u * 0.034, paint);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(foot.dx - _u * 0.02, foot.dy - _u * 0.10, foot.dx + _u * 0.03, foot.dy + _u * 0.02),
          Radius.circular(_u * 0.02),
        ),
        paint,
      );
    }

    canvas.save();
    canvas.translate(-_u * 0.012, -_u * 0.010);
    legs(Paint()..color = _sRim);
    canvas.restore();
    legs(Paint()..color = _sInk);
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(-_w, -_h * 2, _w * 3, hip.dy + _u * 0.02));
    canvas.translate(hip.dx, hip.dy);
    canvas.rotate(-1.35 * recline);
    canvas.translate(-hip.dx, -hip.dy);
    _person(
      canvas,
      feet: hip.translate(0, _u * 0.50),
      facing: -1,
      lean: 0.05,
      arm: _mix(0.6, 2.75 + 0.22 * sin(t * 150), wave),
      elbow: _mix(0.4, 0.45, wave),
      backArm: -0.4,
      hat: victimHat,
      hatOn: false,
    );
    canvas.restore();
  }

  /// Il lampeggiante: un alone che passa dal rosso al blu.
  void _sirenGlow(Canvas canvas, Offset at, double on) {
    if (on <= 0) return;
    final red = (t * 70).floor().isEven;
    final color = red ? const Color(0xFFE23A4A) : const Color(0xFF3B6BFF);
    _sprite(canvas, sprites?.glow, at, _u * 2.6 * on, opacity: 0.55 * on, tint: color);
    canvas.drawCircle(
      at,
      _u * (0.6 + 0.6 * on),
      Paint()
        ..color = color.withValues(alpha: 0.18 * on)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, _u * 0.35),
    );
  }

  void _sirenWash(Canvas canvas, double on) {
    if (on <= 0) return;
    final red = (t * 70).floor().isEven;
    canvas.drawRect(
      Rect.fromLTWH(-_w, -_h, _w * 3, _h * 3),
      Paint()..color = (red ? const Color(0xFFE23A4A) : const Color(0xFF3B6BFF)).withValues(alpha: 0.07 * on),
    );
  }

  /// La barella: due stanghe e il telo, da [head] a [foot].
  void _stretcher(Canvas canvas, Offset head, Offset foot, {bool blanket = false}) {
    final pole = Paint()
      ..color = const Color(0xFF8A6A45)
      ..strokeWidth = _u * 0.025
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(head.translate(-_u * 0.10, 0), foot.translate(_u * 0.10, 0), pole);
    canvas.drawRect(
      Rect.fromLTRB(head.dx, head.dy - _u * 0.025, foot.dx, head.dy + _u * 0.012),
      Paint()..color = const Color(0xFFD8CFBE),
    );
    final legs = Paint()
      ..color = const Color(0xFF6B5236)
      ..strokeWidth = _u * 0.014;
    for (final x in [head.dx + _u * 0.06, foot.dx - _u * 0.06]) {
      canvas.drawLine(Offset(x, head.dy), Offset(x, head.dy + _u * 0.05), legs);
    }
    if (blanket) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(_mix(head.dx, foot.dx, 0.30), head.dy - _u * 0.15, foot.dx - _u * 0.02, head.dy - _u * 0.02),
          Radius.circular(_u * 0.04),
        ),
        Paint()..color = const Color(0xFF7A1B22),
      );
    }
  }

  /// Il furgone dell'ambulanza, col muso a [front]: bianco, la croce rossa
  /// sul fianco, il lampeggiante sul tetto e i portelloni dietro.
  void _van(Canvas canvas, double front, {double nod = 0, double doors = 0}) {
    final length = _u * 1.85;
    final back = front - length;
    final roof = _ground - _u * 0.98;
    canvas.save();
    canvas.translate(front, _ground);
    canvas.rotate(nod);
    canvas.translate(-front, -_ground);

    // I fari: un cono caldo davanti al muso.
    final lamp = Offset(front - _u * 0.04, _ground - _u * 0.30);
    canvas.drawPath(
      Path()
        ..moveTo(lamp.dx, lamp.dy)
        ..lineTo(lamp.dx + _u * 2.2, lamp.dy - _u * 0.30)
        ..lineTo(lamp.dx + _u * 2.2, _ground + _u * 0.04)
        ..close(),
      Paint()
        ..shader = LinearGradient(colors: [_sWarm.withValues(alpha: 0.45), _sWarm.withValues(alpha: 0)])
            .createShader(Rect.fromLTWH(lamp.dx, lamp.dy - _u * 0.3, _u * 2.2, _u * 0.4)),
    );

    final shell = Path()
      ..moveTo(back, _ground - _u * 0.10)
      ..lineTo(back, roof + _u * 0.05)
      ..quadraticBezierTo(back, roof, back + _u * 0.05, roof)
      ..lineTo(front - _u * 0.50, roof)
      ..quadraticBezierTo(front - _u * 0.40, roof, front - _u * 0.34, _ground - _u * 0.60)
      ..quadraticBezierTo(front - _u * 0.02, _ground - _u * 0.56, front, _ground - _u * 0.36)
      ..lineTo(front, _ground - _u * 0.10)
      ..close();
    // Il filo di luce calda sul bordo, come per le sagome.
    canvas.save();
    canvas.translate(-_u * 0.014, -_u * 0.010);
    canvas.drawPath(shell, Paint()..color = _sRim);
    canvas.restore();
    canvas.drawPath(shell, Paint()..color = const Color(0xFFCFC8BA));
    // L'ombra in basso e la fascia rossa.
    canvas.drawRect(
      Rect.fromLTRB(back, _ground - _u * 0.30, front, _ground - _u * 0.10),
      Paint()..color = const Color(0xFFA9A397),
    );
    canvas.drawRect(
      Rect.fromLTRB(back, _ground - _u * 0.36, front, _ground - _u * 0.32),
      Paint()..color = const Color(0xFFB3202A),
    );
    // Il parabrezza e il finestrino della cabina.
    canvas.drawPath(
      Path()
        ..moveTo(front - _u * 0.47, roof + _u * 0.06)
        ..lineTo(front - _u * 0.33, roof + _u * 0.06)
        ..quadraticBezierTo(front - _u * 0.27, _ground - _u * 0.66, front - _u * 0.24, _ground - _u * 0.58)
        ..lineTo(front - _u * 0.47, _ground - _u * 0.58)
        ..close(),
      Paint()..color = const Color(0xFF3B4658),
    );
    canvas.drawLine(
      Offset(front - _u * 0.52, roof),
      Offset(front - _u * 0.52, _ground - _u * 0.12),
      Paint()
        ..color = const Color(0xFF8E887C)
        ..strokeWidth = _u * 0.01,
    );
    // La croce rossa nel tondo bianco.
    final badge = Offset(_mix(back, front - _u * 0.52, 0.5), roof + _u * 0.30);
    canvas.drawCircle(badge, _u * 0.15, Paint()..color = const Color(0xFFF4F0E6));
    final red = Paint()
      ..color = const Color(0xFFD2222D)
      ..strokeWidth = _u * 0.07;
    canvas.drawLine(badge.translate(-_u * 0.10, 0), badge.translate(_u * 0.10, 0), red);
    canvas.drawLine(badge.translate(0, -_u * 0.10), badge.translate(0, _u * 0.10), red);
    // Le ruote.
    for (final x in [back + _u * 0.36, front - _u * 0.36]) {
      canvas.drawCircle(Offset(x, _ground - _u * 0.13), _u * 0.15, Paint()..color = _sInk);
      canvas.drawCircle(Offset(x, _ground - _u * 0.13), _u * 0.06, Paint()..color = _sSteel.withValues(alpha: 0.7));
    }
    // Il paraurti e il faro.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(front - _u * 0.06, _ground - _u * 0.20, front + _u * 0.04, _ground - _u * 0.14),
        Radius.circular(_u * 0.02),
      ),
      Paint()..color = _sSteel,
    );
    canvas.drawCircle(lamp, _u * 0.05, Paint()..color = const Color(0xFFFFF3C4));
    // Il lampeggiante.
    final on = _span(t, 0.56, 0.60);
    final flashRed = (t * 70).floor().isEven;
    final beacon = Offset(front - _u * 0.62, roof - _u * 0.05);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: beacon, width: _u * 0.09, height: _u * 0.07),
        Radius.circular(_u * 0.03),
      ),
      Paint()..color = flashRed ? const Color(0xFFFF4A55) : const Color(0xFF7A1B22),
    );
    if (on > 0 && flashRed) {
      _sprite(canvas, sprites?.glow, beacon, _u * 0.9, opacity: 0.8 * on, tint: const Color(0xFFFF4A55));
    }
    // I portelloni dietro: si aprono, e dentro c'è luce.
    if (doors > 0) {
      final opening = Rect.fromLTRB(back, roof + _u * 0.08, back + _u * 0.05, _ground - _u * 0.12);
      canvas.drawRect(opening, Paint()..color = const Color(0xFF2A2418));
      canvas.drawRect(
        Rect.fromLTRB(back - _u * 0.26 * doors, roof + _u * 0.06, back, _ground - _u * 0.12),
        Paint()..color = const Color(0xFFBDB6A8),
      );
      _sprite(
        canvas,
        sprites?.glow,
        Offset(back - _u * 0.05, _ground - _u * 0.45),
        _u * 0.9,
        opacity: 0.35 * doors,
        tint: _sWarm,
      );
    } else {
      canvas.drawLine(
        Offset(back + _u * 0.02, roof + _u * 0.08),
        Offset(back + _u * 0.02, _ground - _u * 0.12),
        Paint()
          ..color = const Color(0xFF8E887C)
          ..strokeWidth = _u * 0.008,
      );
    }
    canvas.restore();
  }

  // -------------------------------------------------------------- i punti

  /// Sotto il lampione, ago e filo: tre punti sulla ferita, un nodo, un
  /// colpo di forbici, e chi era a terra si rialza ricucito.
  void _stitches(Canvas canvas) {
    _ambush(canvas);
    // La luce del lampione, più calda dove lavora il Dottore.
    final work = _span(t, 0.67, 0.70) * (1 - _span(t, 0.80, 0.84));
    if (work > 0) {
      _sprite(canvas, sprites?.glow, _chestDown.translate(0, -_u * 0.10), _u * 1.4, opacity: 0.35 * work, tint: _sWarm);
    }
    _savedVictim(canvas, mark: _Mark.stitched);
    final come = _doctorCome;
    if (come <= 0) return _ambushSpray(canvas);
    final x = _doctorX;
    final feet = Offset(x, _ground);
    final kneel = _doctorKneel;
    final lean = come < 1 ? 0.22 : 0.45 * kneel;
    final crouch = 0.9 * kneel;

    const stitches = [0.695, 0.722, 0.749];
    const length = 0.025;
    final snip = _span(t, 0.778, 0.79);
    var (arm, elbow) = (0.3, 0.3);
    var pulling = -1.0;
    if (come >= 1 && t < 0.80) {
      (arm, elbow) = (1.02, 0.45);
      for (final at in stitches) {
        final p = _span(t, at, at + length);
        if (p <= 0 || p >= 1) continue;
        // Giù a infilare l'ago, su in alto a tirare il filo.
        final up = p < 0.30 ? 0.0 : _smooth(_span(p, 0.30, 1));
        arm = _mix(1.02, 2.45, up);
        elbow = _mix(0.45, -0.05, up);
        pulling = up;
      }
      if (t > stitches.last + length && snip <= 0) (arm, elbow) = (1.15, 0.5);
      if (snip > 0) (arm, elbow) = (1.05, 0.42);
    } else if (t >= 0.80) {
      (arm, elbow) = _doctorDone();
    }
    if (come >= 1) {
      _bag(canvas, Offset(x - _u * 0.30, _ground - _u * 0.07), _u);
    }
    _doctor(
      canvas,
      feet: feet,
      running: come < 1,
      lean: lean,
      crouch: crouch,
      arm: arm,
      elbow: elbow,
      backArm: come >= 1 && t < 0.80 ? 0.95 : -0.1,
      backElbow: come >= 1 && t < 0.80 ? 0.5 : 0.2,
      prop: come < 1 ? _Prop.bag : _Prop.none,
    );
    final wound = _chestDown;
    // La ferita, coi punti che si aggiungono uno alla volta.
    if (t > _sStrike + 0.07 && t < 0.80) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: wound.translate(0, -_u * 0.005), width: _u * 0.18, height: _u * 0.035),
          Radius.circular(_u * 0.012),
        ),
        Paint()..color = _bandageWhite.withValues(alpha: _span(t, 0.69, 0.695)),
      );
      canvas.drawLine(
        wound.translate(-_u * 0.06, -_u * 0.006),
        wound.translate(_u * 0.06, -_u * 0.006),
        Paint()
          ..color = _sBlood
          ..strokeWidth = _u * 0.014
          ..strokeCap = StrokeCap.round,
      );
      final thread = Paint()
        ..color = _sInk
        ..strokeWidth = _u * 0.008
        ..strokeCap = StrokeCap.round;
      for (final (i, at) in stitches.indexed) {
        if (t < at + length * 0.3) continue;
        final c = wound.translate(_u * (-0.04 + 0.04 * i), -_u * 0.006);
        canvas.drawLine(c.translate(-_u * 0.012, -_u * 0.02), c.translate(_u * 0.012, _u * 0.012), thread);
        canvas.drawLine(c.translate(_u * 0.012, -_u * 0.02), c.translate(-_u * 0.012, _u * 0.012), thread);
      }
    }
    final (hand, along) = _handOf(feet: feet, lean: lean, crouch: crouch, arm: arm, elbow: elbow);
    if (come >= 1 && t > 0.69 && t < 0.778) {
      // L'ago in mano e il filo bianco fino alla ferita.
      final needle = hand + along * (_u * 0.07);
      canvas.drawLine(
        wound.translate(_u * 0.03, -_u * 0.01),
        needle,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.9)
          ..strokeWidth = _u * 0.006,
      );
      canvas.drawLine(
        hand,
        needle,
        Paint()
          ..color = _sSteel
          ..strokeWidth = _u * 0.010
          ..strokeCap = StrokeCap.round,
      );
      if (pulling > 0.85) {
        _sprite(canvas, sprites?.glint, needle, _u * 0.35, opacity: 0.9);
      }
    }
    if (snip > 0 && snip < 1) {
      _scissors(canvas, hand + along * (_u * 0.05), along, open: (sin(snip * pi * 2)).abs());
    }
    _ambushSpray(canvas);
  }

  /// Le forbici del Dottore, aperte di [open].
  void _scissors(Canvas canvas, Offset at, Offset along, {double open = 0}) {
    final across = Offset(-along.dy, along.dx);
    final steel = Paint()
      ..color = _sSteel
      ..strokeWidth = _u * 0.012
      ..strokeCap = StrokeCap.round;
    for (final side in [-1.0, 1.0]) {
      final ring = at - along * (_u * 0.04) + across * (side * _u * 0.025);
      canvas.drawCircle(
        ring,
        _u * 0.018,
        Paint()
          ..color = _sSteel
          ..style = PaintingStyle.stroke
          ..strokeWidth = _u * 0.008,
      );
      canvas.drawLine(ring, at + along * (_u * 0.10) - across * (side * _u * 0.03 * open), steel);
    }
    _sprite(canvas, sprites?.glint, at + along * (_u * 0.08), _u * 0.3, opacity: open);
  }

  // ------------------------------------------------------ il Cecchino, comune

  /// Il mirino rosso che cerca il bersaglio e lo trova: da [aim] 0 vaga
  /// largo, a 1 è fermo su [target].
  void _crosshair(Canvas canvas, Offset target, double aim) {
    if (aim <= 0 || t >= _sStrike + 0.02) return;
    final wander = (1 - aim) * _u;
    final sight = target + Offset(sin(t * 55) * 0.5 + 0.55, cos(t * 41) * 0.28 - 0.40) * wander;
    final radius = _u * _mix(0.36, 0.15, aim);
    final red = Paint()
      ..color = const Color(0xFFFF3B30).withValues(alpha: 0.9 * min(1, aim * 4))
      ..style = PaintingStyle.stroke
      ..strokeWidth = _u * 0.014;
    canvas.drawCircle(sight, radius, red);
    for (final side in const [Offset(1, 0), Offset(-1, 0), Offset(0, 1), Offset(0, -1)]) {
      canvas.drawLine(sight + side * (radius * 0.45), sight + side * (radius * 1.35), red);
    }
    canvas.drawCircle(sight, _u * 0.012, Paint()..color = red.color);
  }

  /// Il fucile lontano, puntato da [nest] verso [target], che sobbalza al colpo.
  void _farRifle(Canvas canvas, Offset nest, Offset target, double aim, {double size = 0.45}) {
    if (aim <= 0) return;
    final shotAt = target - nest;
    final kick = sin(pi * _span(t, _sStrike, _sStrike + 0.05));
    final angle = atan2(-shotAt.dy, -shotAt.dx) * _mix(0.75, 1, aim) - 0.18 * kick;
    canvas.saveLayer(
      Rect.fromCircle(center: nest, radius: _u * 0.6),
      Paint()..color = Colors.white.withValues(alpha: aim),
    );
    canvas.translate(nest.dx, nest.dy);
    canvas.rotate(angle);
    canvas.translate(-nest.dx + _u * 0.04 * kick, -nest.dy);
    _drawSniperRifle(canvas, nest, _u * size);
    canvas.restore();
  }

  /// Il lampo lontano del colpo, la scia fino al petto, il fumo.
  void _farShot(Canvas canvas, Offset nest, Offset chest, {double size = 0.6}) {
    final bang = _span(t, _sStrike, _sStrike + 0.03);
    if (bang > 0 && bang < 1) {
      _muzzleFlash(canvas, nest, bang, toward: chest - nest, size: size);
      _star(canvas, nest, _u * 0.10 * (1 - bang * 0.5), const Color(0xFFFFF3C4).withValues(alpha: 1 - bang));
      _tracer(canvas, nest, chest, bang);
    }
    _puff(canvas, nest.translate(-_u * 0.05, -_u * 0.1), _span(t, _sStrike + 0.02, _sStrike + 0.16), size: 0.35);
    _flash(canvas, bang, strength: 0.35);
  }

  /// Il riflesso della lente: una stella che si accende e si spegne.
  void _scopeGlint(Canvas canvas, Offset at, double from, double to, {double size = 0.10}) {
    final glint = sin(pi * _span(t, from, to));
    if (glint <= 0) return;
    _sprite(canvas, sprites?.glint, at, _u * size * 4 * glint, opacity: glint);
    _star(canvas, at, _u * size * glint, Colors.white.withValues(alpha: glint));
  }

  // -------------------------------------------------------------- campanile

  /// Dal campanile in fondo alla strada: il riflesso fra le campane, il
  /// colpo coperto dal rintocco, i piccioni che scappano.
  void _belfry(Canvas canvas) {
    final (walkX, walk, stride) = _entrance();
    final towerX = _w * 0.86;
    final arch = Offset(towerX, _ground - _u * 1.58);
    final rung = t - _sStrike;
    final early = t - 0.40;
    final swing =
        (rung > 0 ? 0.55 * sin(rung * 110) * exp(-rung * 9) : 0.0) +
        (early > 0 && rung < 0 ? 0.25 * sin(early * 110) * exp(-early * 12) : 0.0);
    _bellTower(canvas, towerX, swing);

    final fall = _span(t, _sStrike + 0.01, _sStrike + 0.11);
    _pool(canvas, Offset(_victimX - _u * 0.50, _ground + _u * 0.04), _smooth(_span(t, 0.67, 0.84)));
    _victim(
      canvas,
      x: walkX,
      facing: t < 0.37 ? 1 : -1,
      walk: walk,
      stride: stride,
      fall: fall,
      smoking: t > 0.37 && t < _sStrike,
    );
    _hatOff(canvas, _sStrike + 0.01, _sStrike + 0.24, height: 1.2);

    final nest = arch + Offset(-_u * 0.10, _u * 0.11);
    final chest = Offset(_victimX + _u * 0.02, _ground - _u * 0.76);
    final aim = _smooth(_span(t, 0.42, 0.535));
    _farRifle(canvas, nest, chest, aim, size: 0.42);
    _scopeGlint(canvas, nest, 0.35, 0.42, size: 0.11);
    _scopeGlint(canvas, nest, 0.49, 0.53, size: 0.07);
    _crosshair(canvas, chest, aim);
    _farShot(canvas, nest, chest, size: 0.5);
    _pigeons(canvas, arch, _span(t, _sStrike + 0.004, _sStrike + 0.30));
    // Il rintocco: un'onda che si allarga dalla cella delle campane.
    for (final at in [0.40, _sStrike, 0.64]) {
      final ring = _span(t, at, at + 0.07);
      if (ring <= 0 || ring >= 1) continue;
      canvas.drawCircle(
        arch,
        _u * (0.25 + 0.9 * ring),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _u * 0.02 * (1 - ring)
          ..color = AppColors.gold.withValues(alpha: 0.5 * (1 - ring)),
      );
    }
    _spray(canvas, chest, _span(t, _sStrike, _sStrike + 0.20), seed: 93, count: 18);
  }

  /// Il campanile lontano: fusto, cella con la campana che oscilla di
  /// [swing], tetto a punta con la croce.
  void _bellTower(Canvas canvas, double x, double swing) {
    const stone = Color(0xFF0E1017);
    final paint = Paint()..color = stone;
    final shaftTop = _ground - _u * 1.40;
    final cellTop = _ground - _u * 1.84;
    // Il filo di luce della luna sul bordo sinistro.
    canvas.drawRect(
      Rect.fromLTRB(x - _u * 0.215, cellTop, x + _u * 0.20, _ground),
      Paint()..color = const Color(0xFF2A2E3C),
    );
    canvas.drawRect(Rect.fromLTRB(x - _u * 0.20, shaftTop, x + _u * 0.20, _ground), paint);
    for (final y in [0.45, 0.80, 1.15]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(x, _ground - _u * y), width: _u * 0.05, height: _u * 0.14),
          Radius.circular(_u * 0.025),
        ),
        Paint()..color = const Color(0xFF1C2030),
      );
    }
    // La cornice e la cella delle campane.
    canvas.drawRect(Rect.fromLTRB(x - _u * 0.25, shaftTop - _u * 0.04, x + _u * 0.25, shaftTop + _u * 0.02), paint);
    canvas.drawRect(Rect.fromLTRB(x - _u * 0.23, cellTop, x + _u * 0.23, shaftTop), paint);
    final opening = Path()
      ..moveTo(x - _u * 0.14, shaftTop - _u * 0.04)
      ..lineTo(x - _u * 0.14, cellTop + _u * 0.16)
      ..arcToPoint(Offset(x + _u * 0.14, cellTop + _u * 0.16), radius: Radius.circular(_u * 0.14))
      ..lineTo(x + _u * 0.14, shaftTop - _u * 0.04)
      ..close();
    canvas.drawPath(opening, Paint()..color = const Color(0xFF26304A));
    // La campana, appesa alla trave, che oscilla.
    final pivot = Offset(x, cellTop + _u * 0.07);
    canvas.save();
    canvas.clipPath(opening);
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(swing);
    canvas.drawPath(
      Path()
        ..moveTo(-_u * 0.04, _u * 0.03)
        ..quadraticBezierTo(-_u * 0.05, _u * 0.16, -_u * 0.11, _u * 0.22)
        ..lineTo(_u * 0.11, _u * 0.22)
        ..quadraticBezierTo(_u * 0.05, _u * 0.16, _u * 0.04, _u * 0.03)
        ..close(),
      Paint()..color = const Color(0xFF9A7834),
    );
    canvas.drawCircle(Offset(0, _u * 0.24), _u * 0.025, Paint()..color = const Color(0xFF6E5424));
    canvas.restore();
    canvas.drawLine(
      Offset(x - _u * 0.16, cellTop + _u * 0.07),
      Offset(x + _u * 0.16, cellTop + _u * 0.07),
      Paint()
        ..color = stone
        ..strokeWidth = _u * 0.03,
    );
    // Il tetto a punta e la croce.
    canvas.drawPath(
      Path()
        ..moveTo(x - _u * 0.27, cellTop)
        ..lineTo(x, cellTop - _u * 0.42)
        ..lineTo(x + _u * 0.27, cellTop)
        ..close(),
      paint,
    );
    final cross = Paint()
      ..color = stone
      ..strokeWidth = _u * 0.025;
    canvas.drawLine(Offset(x, cellTop - _u * 0.42), Offset(x, cellTop - _u * 0.58), cross);
    canvas.drawLine(Offset(x - _u * 0.05, cellTop - _u * 0.52), Offset(x + _u * 0.05, cellTop - _u * 0.52), cross);
  }

  /// Lo stormo che si alza dal campanile, ali che sbattono.
  void _pigeons(Canvas canvas, Offset from, double life) {
    if (life <= 0 || life >= 1) return;
    final rng = Random(17);
    final ink = Paint()
      ..color = const Color(0xFF15171F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = _u * 0.018
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final ease = Curves.easeOut.transform(life);
    for (var i = 0; i < 8; i++) {
      final dir = Offset(rng.nextDouble() * 2.4 - 1.4, -(0.4 + rng.nextDouble() * 0.9));
      final at = from + Offset(rng.nextDouble() * 0.2 - 0.1, rng.nextDouble() * 0.2) * _u + dir * (_u * 1.3 * ease);
      final flap = sin(t * 700 + i * 1.7) * 0.7;
      final span = _u * (0.05 + 0.015 * (i % 3));
      final up = Offset(0, -span * flap);
      canvas.drawPath(
        Path()
          ..moveTo(at.dx - span, at.dy + up.dy)
          ..quadraticBezierTo(at.dx - span * 0.4, at.dy - span * 0.2, at.dx, at.dy)
          ..quadraticBezierTo(at.dx + span * 0.4, at.dy - span * 0.2, at.dx + span, at.dy + up.dy),
        ink..color = const Color(0xFF15171F).withValues(alpha: 1 - _span(life, 0.75, 1)),
      );
    }
  }

  // ---------------------------------------------------------------- cabina

  /// La cabina del telefono che squilla: chi risponde non sente nessuno, solo
  /// il vetro che si crepa a stella. La cornetta resta a penzolare.
  void _phoneBooth(Canvas canvas) {
    final (walkX, walk, stride) = _entrance();
    _wall(canvas);
    final bx = _victimX;
    final top = _ground - _u * 1.30;
    final hit = t >= _sStrike;
    final flicker = hit ? (sin(t * 900) > -0.2 ? 1.0 : 0.25) : 1.0;

    // Il fondo della cabina, con la lampadina accesa.
    canvas.drawRect(
      Rect.fromLTRB(bx - _u * 0.25, top, bx + _u * 0.25, _ground),
      Paint()..color = const Color(0xFF14110D),
    );
    _sprite(canvas, sprites?.glow, Offset(bx, top + _u * 0.25), _u * 1.3, opacity: 0.45 * flicker, tint: _sWarm);
    canvas.drawCircle(Offset(bx, top + _u * 0.07), _u * 0.03, Paint()..color = _sWarm.withValues(alpha: flicker));
    // L'apparecchio sulla parete di destra.
    final phone = Offset(bx + _u * 0.20, _ground - _u * 0.86);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: phone, width: _u * 0.08, height: _u * 0.16),
        Radius.circular(_u * 0.015),
      ),
      Paint()..color = const Color(0xFF050506),
    );
    canvas.drawCircle(phone.translate(0, -_u * 0.02), _u * 0.022, Paint()..color = const Color(0xFF3B4048));

    // Squilla: la cornetta trema sulla forcella.
    final ringing = t > 0.25 && t < 0.365;
    final pickUp = _smooth(_span(t, 0.365, 0.395));
    final arm = _mix(0.08, 1.0, pickUp);
    final elbow = _mix(0.2, 2.45, pickUp);
    final fall = _span(t, _sStrike + 0.012, _sStrike + 0.11);
    final jerk = sin(pi * _span(t, _sStrike, _sStrike + 0.03));
    final listening = t > 0.40 && t < _sStrike ? sin(t * 90) * 0.03 : 0.0;
    _victim(
      canvas,
      x: walkX,
      facing: 1,
      walk: walk,
      stride: stride,
      fall: fall,
      lean: -0.25 * jerk + listening,
      arm: arm,
      elbow: elbow,
    );
    _hatOff(canvas, _sStrike + 0.01, _sStrike + 0.22, height: 0.7);
    if (ringing) {
      final shake = sin(t * 2200) * _u * 0.012;
      _receiver(canvas, phone.translate(shake - _u * 0.055, -_u * 0.02), pi / 2);
      final ring = (t * 30) % 1;
      for (final side in [-1.0, 1.0]) {
        canvas.drawArc(
          Rect.fromCenter(center: phone, width: _u * (0.22 + 0.10 * ring), height: _u * (0.22 + 0.10 * ring)),
          side > 0 ? -0.6 : pi - 0.6,
          1.2,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = _u * 0.012
            ..color = AppColors.gold.withValues(alpha: 1 - ring),
        );
      }
    } else if (!hit && t >= 0.365) {
      final (hand, _) = _handOf(feet: Offset(walkX, _ground), lean: listening, arm: arm, elbow: elbow);
      _cord(canvas, phone.translate(0, _u * 0.07), hand);
      _receiver(canvas, hand.translate(_u * 0.005, -_u * 0.01), pi / 2 + 0.3);
    } else if (hit) {
      // Lasciata andare: penzola dal filo e sbatte contro il vetro.
      final tau = t - _sStrike - 0.01;
      final swing = tau < 0 ? -0.9 : -0.9 * exp(-tau * 12) * cos(tau * 95).abs();
      final anchor = phone.translate(0, _u * 0.07);
      final end = anchor + Offset(sin(swing), cos(swing)) * (_u * 0.34);
      _cord(canvas, anchor, end);
      _receiver(canvas, end, swing + pi / 2);
    } else {
      _receiver(canvas, phone.translate(-_u * 0.055, -_u * 0.02), pi / 2);
    }

    // Il vetro davanti: riflessi, poi il buco e la crepa a stella.
    final glass = Rect.fromLTRB(bx - _u * 0.22, top + _u * 0.10, bx + _u * 0.22, _ground - _u * 0.08);
    canvas.drawRect(glass, Paint()..color = const Color(0xFFB8D0E0).withValues(alpha: 0.10));
    canvas.drawLine(
      glass.topLeft.translate(_u * 0.05, _u * 0.10),
      glass.topLeft.translate(_u * 0.20, -_u * 0.02 + _u * 0.10 - _u * 0.10),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.10)
        ..strokeWidth = _u * 0.03,
    );
    final hole = Offset(bx + _u * 0.04, _ground - _u * 0.78);
    _scopeGlint(canvas, glass.topLeft.translate(_u * 0.08, _u * 0.18), 0.42, 0.49, size: 0.06);
    _crosshair(canvas, hole, _smooth(_span(t, 0.40, 0.535)));
    if (hit) {
      final grow = Curves.easeOut.transform(_span(t, _sStrike, _sStrike + 0.012));
      _glassCrack(canvas, hole, grow, glass);
      // Il sangue resta sul vetro e cola piano.
      final drip = _span(t, _sStrike + 0.03, 0.85);
      final rng = Random(5);
      for (var i = 0; i < 9; i++) {
        final at = hole + Offset(rng.nextDouble() * 0.20 - 0.14, rng.nextDouble() * 0.16 - 0.10) * _u;
        final r = _u * (0.008 + rng.nextDouble() * 0.018);
        final paint = Paint()..color = _sBlood.withValues(alpha: 0.9);
        canvas.drawCircle(at, r, paint);
        if (i.isEven) {
          canvas.drawLine(
            at,
            at.translate(0, _u * 0.18 * drip * (0.4 + rng.nextDouble())),
            paint..strokeWidth = r * 0.8,
          );
        }
      }
    }
    // L'intelaiatura rossa della cabina, col cartello acceso sul tetto.
    final frame = Paint()..color = const Color(0xFF5B1418);
    for (final x in [bx - _u * 0.25, bx + _u * 0.22]) {
      canvas.drawRect(Rect.fromLTWH(x, top, _u * 0.035, _ground - top), frame);
    }
    canvas.drawRect(Rect.fromLTRB(bx - _u * 0.27, top - _u * 0.05, bx + _u * 0.27, top + _u * 0.10), frame);
    canvas.drawRect(Rect.fromLTRB(bx - _u * 0.25, _ground - _u * 0.09, bx + _u * 0.25, _ground), frame);
    final bar = Paint()
      ..color = const Color(0xFF5B1418)
      ..strokeWidth = _u * 0.014;
    for (final y in [0.35, 0.62]) {
      canvas.drawLine(
        Offset(glass.left, _mix(glass.top, glass.bottom, y)),
        Offset(glass.right, _mix(glass.top, glass.bottom, y)),
        bar,
      );
    }
    final sign = Rect.fromCenter(center: Offset(bx, top + _u * 0.025), width: _u * 0.34, height: _u * 0.06);
    canvas.drawRect(sign, Paint()..color = const Color(0xFFF4ECD8).withValues(alpha: 0.85 * flicker));
    _receiver(canvas, sign.center, 0, color: const Color(0xFF5B1418), size: 0.8);
    // Il lampo lontano, sui tetti dall'altra parte della strada.
    final nest = Offset(bx - _u * 0.72, _ground - _u * 2.15);
    _farShot(canvas, nest, hole, size: 0.35);
    _debris(
      canvas,
      hole,
      _span(t, _sStrike, _sStrike + 0.30),
      seed: 23,
      count: 12,
      colors: const [Color(0xFFCFE3EE), Color(0xFF9FB8C6)],
      size: 0.8,
      reach: 0.5,
      lift: 0.4,
      drift: -0.6,
      glints: true,
    );
  }

  /// Le crepe a stella intorno al buco del colpo, dentro [pane].
  void _glassCrack(Canvas canvas, Offset hole, double grow, Rect pane) {
    canvas.save();
    canvas.clipRect(pane);
    final rng = Random(11);
    final crack = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = _u * 0.008
      ..strokeJoin = StrokeJoin.round;
    final ends = <Offset>[];
    for (var i = 0; i < 11; i++) {
      final angle = i * 2 * pi / 11 + rng.nextDouble() * 0.4;
      final length = _u * (0.18 + rng.nextDouble() * 0.22) * grow;
      final path = Path()..moveTo(hole.dx, hole.dy);
      var p = hole;
      for (var s = 1; s <= 4; s++) {
        final a = angle + (rng.nextDouble() - 0.5) * 0.5;
        p = p + Offset(cos(a), sin(a)) * (length / 4);
        path.lineTo(p.dx, p.dy);
        if (s == 2) ends.add(p);
      }
      canvas.drawPath(path, crack);
    }
    // L'anello di crepe intorno.
    if (ends.length > 2) {
      final ring = Path()..moveTo(ends.first.dx, ends.first.dy);
      for (final p in ends.skip(1)) {
        ring.lineTo(p.dx, p.dy);
      }
      ring.close();
      canvas.drawPath(ring, crack..strokeWidth = _u * 0.005);
    }
    canvas.restore();
    canvas.drawCircle(hole, _u * 0.022 * grow, Paint()..color = const Color(0xFF050506));
    canvas.drawCircle(
      hole,
      _u * 0.03 * grow,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _u * 0.008
        ..color = Colors.white.withValues(alpha: 0.9),
    );
  }

  /// La cornetta del telefono: due capsule tonde e il manico, girata di [angle].
  void _receiver(Canvas canvas, Offset center, double angle, {Color color = const Color(0xFF050506), double size = 1}) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    final paint = Paint()..color = color;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: _u * 0.15 * size, height: _u * 0.025 * size),
        Radius.circular(_u * 0.012 * size),
      ),
      paint,
    );
    for (final x in [-0.07, 0.07]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(_u * x * size, _u * 0.02 * size),
          width: _u * 0.05 * size,
          height: _u * 0.035 * size,
        ),
        paint,
      );
    }
    canvas.restore();
  }

  /// Il filo a spirale della cornetta.
  void _cord(Canvas canvas, Offset from, Offset to) {
    final delta = to - from;
    final side = Offset(-delta.dy, delta.dx) / max(delta.distance, 0.001);
    final path = Path()..moveTo(from.dx, from.dy);
    const turns = 14;
    for (var i = 1; i <= turns * 2; i++) {
      final f = i / (turns * 2);
      final sag = sin(pi * f) * _u * 0.06;
      final p = from + delta * f + side * ((i.isEven ? 1 : -1) * _u * 0.012) + Offset(0, sag);
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _u * 0.008
        ..color = const Color(0xFF2A2C31),
    );
  }

  // -------------------------------------------------------------- portiera

  /// L'auto parcheggiata: chiavi, portiera aperta, un piede dentro. Il colpo
  /// arriva da lontano, e la luce di cortesia resta accesa su chi è a terra.
  void _carDoor(Canvas canvas) {
    final (walkX, walk, stride) = _entrance();
    final back = _victimX - _u * 0.70;
    final doorRear = back + _u * 0.84;
    final hinge = back + _u * 1.30;
    final open = _smooth(_span(t, 0.44, 0.50));
    final panelLeft = _mix(doorRear, hinge - _u * 0.14, open);
    final hit = t >= _sStrike;
    final fall = _span(t, _sStrike + 0.01, _sStrike + 0.11);

    _parkedSedan(canvas, back, gapFrom: doorRear, gapTo: panelLeft, dome: open);

    // Le chiavi dalla tasca, la mano sulla maniglia, un piede sul predellino.
    final keys = _smooth(_span(t, 0.36, 0.40));
    final reach = _smooth(_span(t, 0.41, 0.44)) - _smooth(_span(t, 0.50, 0.53));
    final step = _smooth(_span(t, 0.50, 0.545));
    final x = walkX + _u * 0.10 * step;
    final arm = _mix(_mix(0.08, 1.15, keys), 1.45, reach);
    final elbow = _mix(_mix(0.2, 1.10, keys), 0.15, reach);
    final kick = sin(pi * _span(t, _sStrike, _sStrike + 0.04));
    _pool(canvas, Offset(x - _u * 0.50, _ground + _u * 0.04), _smooth(_span(t, 0.67, 0.84)));
    if (fall <= 0 && step > 0) {
      _person(
        canvas,
        feet: Offset(x, _ground),
        walk: pi * 0.55,
        stride: 0.65 * step,
        lean: 0.18 * step - 0.3 * kick,
        crouch: 0.15 * step,
        arm: arm,
        elbow: elbow,
        hat: victimHat,
      );
    } else {
      _victim(canvas, x: x, facing: 1, walk: walk, stride: stride, fall: fall, arm: arm, elbow: elbow);
    }
    if (fall <= 0) {
      final (hand, _) = _handOf(
        feet: Offset(x, _ground),
        lean: step > 0 ? 0.18 * step : 0,
        crouch: 0.15 * step,
        arm: arm,
        elbow: elbow,
      );
      if (keys > 0.3) _keyring(canvas, hand.translate(_u * 0.02, _u * 0.03), sin(t * 120) * 0.3);
    } else {
      // Le chiavi volano via e tintinnano sull'asfalto.
      final fly = _span(t, _sStrike, _sStrike + 0.06);
      final from = Offset(x + _u * 0.25, _ground - _u * 0.80);
      final land = Offset(x - _u * 0.15, _ground - _u * 0.01);
      _keyring(
        canvas,
        Offset(_mix(from.dx, land.dx, fly), _mix(from.dy, land.dy, fly) - sin(pi * fly) * _u * 0.35),
        fly * 9,
      );
    }
    _hatOff(canvas, _sStrike + 0.01, _sStrike + 0.24, height: 1.1);
    // La portiera aperta, vista di taglio.
    _doorPanel(canvas, panelLeft, hinge);

    final chest = Offset(x + _u * 0.06, _ground - _u * 0.76);
    final nest = Offset(_victimX + _u * 0.80, _ground - _u * 1.70);
    final aim = _smooth(_span(t, 0.43, 0.535));
    _farRifle(canvas, nest, chest, aim, size: 0.38);
    _scopeGlint(canvas, nest, 0.38, 0.45, size: 0.09);
    _crosshair(canvas, chest, aim);
    _farShot(canvas, nest, chest, size: 0.45);
    if (hit) {
      _spray(canvas, chest, _span(t, _sStrike, _sStrike + 0.20), seed: 77, count: 18, bias: const Offset(-0.6, -0.8));
    }
  }

  /// Il mazzo di chiavi: un anello e tre chiavi d'ottone.
  void _keyring(Canvas canvas, Offset at, double spin) {
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(spin);
    canvas.drawCircle(
      Offset.zero,
      _u * 0.022,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _u * 0.007
        ..color = _sSteel,
    );
    final brass = Paint()
      ..color = const Color(0xFFE0B65A)
      ..strokeWidth = _u * 0.012
      ..strokeCap = StrokeCap.round;
    for (final a in [0.6, 1.4, 2.2]) {
      final d = Offset(cos(a), sin(a));
      canvas.drawLine(d * (_u * 0.022), d * (_u * 0.075), brass);
    }
    canvas.restore();
    _sprite(canvas, sprites?.glint, at, _u * 0.16, opacity: sin(t * 140).abs() * 0.8);
  }

  /// L'auto ferma accanto al marciapiede, col muso a destra. Fra [gapFrom] e
  /// [gapTo] la portiera è aperta: dentro il sedile e la luce di cortesia.
  void _parkedSedan(Canvas canvas, double back, {required double gapFrom, required double gapTo, double dome = 0}) {
    final ink = Paint()..color = _sInk;
    final front = back + _u * 2.1;
    final base = _ground - _u * 0.08;
    final shell = Path()
      ..moveTo(back + _u * 0.05, base)
      ..quadraticBezierTo(back - _u * 0.03, _ground - _u * 0.42, back + _u * 0.22, _ground - _u * 0.46)
      ..quadraticBezierTo(back + _u * 0.42, _ground - _u * 0.86, back + _u * 0.82, _ground - _u * 0.86)
      ..quadraticBezierTo(back + _u * 1.15, _ground - _u * 0.86, back + _u * 1.32, _ground - _u * 0.52)
      ..quadraticBezierTo(back + _u * 1.80, _ground - _u * 0.52, front - _u * 0.04, _ground - _u * 0.40)
      ..quadraticBezierTo(front + _u * 0.03, _ground - _u * 0.30, front, base)
      ..close();
    canvas.save();
    canvas.translate(-_u * 0.014, -_u * 0.012);
    canvas.drawPath(shell, Paint()..color = _sRim);
    canvas.restore();
    canvas.drawPath(shell, ink);
    canvas.drawPath(
      Path()
        ..moveTo(back + _u * 0.50, _ground - _u * 0.52)
        ..quadraticBezierTo(back + _u * 0.58, _ground - _u * 0.78, back + _u * 0.84, _ground - _u * 0.78)
        ..quadraticBezierTo(back + _u * 1.06, _ground - _u * 0.78, back + _u * 1.20, _ground - _u * 0.52)
        ..close(),
      Paint()..color = const Color(0xFF3B4658),
    );
    // Il vano della portiera aperta: buio, il sedile, il volante, la luce.
    if (gapTo > gapFrom + 1) {
      final gap = Rect.fromLTRB(gapFrom, _ground - _u * 0.80, gapTo, _ground - _u * 0.14);
      canvas.save();
      canvas.clipPath(shell);
      canvas.drawRect(gap, Paint()..color = const Color(0xFF1A140C));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(gapFrom - _u * 0.02, _ground - _u * 0.62, gapFrom + _u * 0.12, _ground - _u * 0.22),
          Radius.circular(_u * 0.04),
        ),
        Paint()..color = const Color(0xFF4A3220),
      );
      canvas.drawCircle(
        Offset(gapTo - _u * 0.02, _ground - _u * 0.55),
        _u * 0.08,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _u * 0.018
          ..color = const Color(0xFF0A0806),
      );
      canvas.restore();
      _sprite(
        canvas,
        sprites?.glow,
        Offset((gapFrom + gapTo) / 2, _ground - _u * 0.55),
        _u * 1.3,
        opacity: 0.55 * dome,
        tint: _sWarm,
      );
      // La luce che esce e si posa sull'asfalto.
      canvas.drawOval(
        Rect.fromCenter(center: Offset(gapFrom - _u * 0.10, _ground + _u * 0.03), width: _u * 1.1, height: _u * 0.10),
        Paint()
          ..color = _sWarm.withValues(alpha: 0.18 * dome)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, _u * 0.04),
      );
    }
    for (final x in [back + _u * 0.38, front - _u * 0.36]) {
      canvas.drawCircle(Offset(x, _ground - _u * 0.15), _u * 0.21, ink);
      canvas.drawCircle(Offset(x, _ground - _u * 0.13), _u * 0.13, Paint()..color = const Color(0xFF17181C));
      canvas.drawCircle(Offset(x, _ground - _u * 0.13), _u * 0.055, Paint()..color = _sSteel.withValues(alpha: 0.7));
    }
    final chrome = Paint()..color = _sSteel.withValues(alpha: 0.85);
    for (final rect in [
      Rect.fromLTRB(front - _u * 0.10, _ground - _u * 0.23, front + _u * 0.05, _ground - _u * 0.175),
      Rect.fromLTRB(back - _u * 0.04, _ground - _u * 0.23, back + _u * 0.12, _ground - _u * 0.175),
    ]) {
      canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(_u * 0.02)), chrome);
    }
    canvas.drawCircle(
      Offset(front - _u * 0.03, _ground - _u * 0.34),
      _u * 0.05,
      Paint()..color = const Color(0xFF8A8270),
    );
    canvas.drawCircle(
      Offset(back + _u * 0.06, _ground - _u * 0.40),
      _u * 0.03,
      Paint()..color = const Color(0xFF7A1B22),
    );
  }

  /// La portiera aperta verso di noi: più stretta quanto più è aperta.
  void _doorPanel(Canvas canvas, double left, double hinge) {
    final panel = Rect.fromLTRB(left, _ground - _u * 0.80, hinge, _ground - _u * 0.16);
    canvas.drawRRect(
      RRect.fromRectAndRadius(panel.translate(-_u * 0.012, -_u * 0.01), Radius.circular(_u * 0.03)),
      Paint()..color = _sRim,
    );
    canvas.drawRRect(RRect.fromRectAndRadius(panel, Radius.circular(_u * 0.03)), Paint()..color = _sInk);
    canvas.drawRect(
      Rect.fromLTRB(left + _u * 0.02, panel.top + _u * 0.04, hinge - _u * 0.02, panel.top + _u * 0.24),
      Paint()..color = const Color(0xFF3B4658),
    );
    canvas.drawLine(
      Offset(left + _u * 0.03, _ground - _u * 0.44),
      Offset(left + _u * 0.10, _ground - _u * 0.44),
      Paint()
        ..color = _sSteel
        ..strokeWidth = _u * 0.02
        ..strokeCap = StrokeCap.round,
    );
  }

  // ------------------------------------------------------------- la Bibbia

  /// Come la fiaschetta, ma nel taschino c'è una Bibbia: il colpo si pianta
  /// fra le pagine, e chi l'ha scampata la alza verso il cielo.
  void _bible(Canvas canvas) {
    final (walkX, walk, stride) = _entrance();
    final puzzled = _smooth(_span(t, _sStrike + 0.035, _sStrike + 0.07)) - _smooth(_span(t, 0.655, 0.67));
    final killerX = _gunman(canvas, leaveAt: 0.67, puzzled: puzzled);
    _wall(canvas);
    if (puzzled > 0.5) {
      _mark(canvas, '?!', Offset(killerX - _u * 0.05, _ground - _u * 1.52));
    }

    final facing = _luckyFacing(t < 0.37 ? 1 : (t < 0.512 ? -1 : 1));
    final stagger = sin(pi * _span(t, _sStrike, _sStrike + 0.09));
    final back = _u * 0.12 * Curves.easeOut.transform(_span(t, _sStrike, _sStrike + 0.05));
    final clutch = _smooth(_span(t, _sStrike + 0.005, _sStrike + 0.03)) - _smooth(_span(t, 0.625, 0.65));
    final pull = _smooth(_span(t, 0.64, 0.69));
    final raise = _smooth(_span(t, 0.72, 0.75)) - _smooth(_span(t, 0.84, 0.87));
    final x = walkX - back;
    final lean = -0.34 * stagger - 0.12 * raise;
    final arm = _mix(_mix(_mix(0.08, 0.2, clutch), 1.95, pull), 2.85, raise);
    final elbow = _mix(_mix(_mix(0.2, 2.4, clutch), 0.85, pull), 0.15, raise);

    // La luce dall'alto, mentre la alza.
    if (raise > 0) {
      final top = Offset(x + _u * 0.10, _ground - _u * 3.2);
      canvas.drawPath(
        Path()
          ..moveTo(top.dx - _u * 0.15, top.dy)
          ..lineTo(top.dx + _u * 0.15, top.dy)
          ..lineTo(x + _u * 0.55, _ground)
          ..lineTo(x - _u * 0.40, _ground)
          ..close(),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFFFFF3C4).withValues(alpha: 0.38 * raise),
              const Color(0xFFFFF3C4).withValues(alpha: 0.04 * raise),
            ],
          ).createShader(Rect.fromLTRB(x - _u, top.dy, x + _u, _ground)),
      );
    }
    _victim(
      canvas,
      x: x,
      facing: facing,
      walk: walk,
      stride: stride,
      lean: lean,
      arm: arm,
      elbow: elbow,
      smoking: t > 0.37 && t < _sStrike,
    );
    _droppedCigarette(
      canvas,
      _onBody(const Offset(0.11, -0.435), feet: Offset(walkX, _ground), facing: 1),
      _span(t, _sStrike + 0.005, _sStrike + 0.055),
    );

    // Niente scintille: il piombo entra nella carta, e volano pagine.
    final chest = Offset(x + _u * 0.10, _ground - _u * 0.76);
    _impactBurst(canvas, chest, _span(t, _sStrike, _sStrike + 0.05), size: 0.55, color: const Color(0xFFF4ECD8));
    _debris(
      canvas,
      chest,
      _span(t, _sStrike, _sStrike + 0.32),
      seed: 61,
      count: 14,
      colors: const [Color(0xFFF4ECD8), Color(0xFFE0D6BE)],
      size: 0.85,
      reach: 0.6,
      lift: 0.5,
      drift: -0.4,
    );
    _flash(canvas, _span(t, _sStrike, _sStrike + 0.03), strength: 0.35);

    if (pull > 0.15) {
      final (hand, _) = _handOf(feet: Offset(x, _ground), facing: facing, lean: lean, arm: arm, elbow: elbow);
      final book = hand.translate(_u * 0.01, -_u * 0.07);
      _pocketBible(canvas, book, tilt: 0.25 * raise);
      if (raise > 0.5) {
        _sprite(canvas, sprites?.glow, book, _u * 1.1, opacity: 0.5 * raise, tint: const Color(0xFFFFE9A8));
        for (var i = 0; i < 5; i++) {
          final a = t * 6 + i * 2 * pi / 5;
          _star(
            canvas,
            book + Offset(cos(a), sin(a) * 0.7) * (_u * 0.22),
            _u * 0.03 * (0.6 + 0.4 * sin(t * 90 + i).abs()),
            AppColors.gold.withValues(alpha: raise),
          );
        }
      }
    }
  }

  /// La Bibbia tascabile: cuoio rosso scuro, croce e taglio dorati, il buco
  /// del colpo col piombo dentro.
  void _pocketBible(Canvas canvas, Offset center, {double tilt = 0}) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-tilt);
    final cover = Rect.fromCenter(center: Offset.zero, width: _u * 0.12, height: _u * 0.16);
    canvas.drawRect(cover.translate(_u * 0.012, 0), Paint()..color = const Color(0xFFF4ECD8));
    canvas.drawRRect(
      RRect.fromRectAndRadius(cover, Radius.circular(_u * 0.012)),
      Paint()..color = const Color(0xFF6A1E18),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(cover.deflate(_u * 0.01), Radius.circular(_u * 0.008)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _u * 0.005
        ..color = AppColors.gold,
    );
    final gold = Paint()
      ..color = AppColors.gold
      ..strokeWidth = _u * 0.012;
    canvas.drawLine(Offset(0, -_u * 0.055), Offset(0, _u * 0.005), gold);
    canvas.drawLine(Offset(-_u * 0.022, -_u * 0.035), Offset(_u * 0.022, -_u * 0.035), gold);
    canvas.drawCircle(Offset(_u * 0.01, _u * 0.04), _u * 0.02, Paint()..color = const Color(0xFF1A0A08));
    canvas.drawCircle(Offset(_u * 0.01, _u * 0.04), _u * 0.011, Paint()..color = const Color(0xFFD9A441));
    canvas.restore();
  }

  // -------------------------------------------------------------- inceppata

  /// La pistola fa clic, e poi ancora clic. Il killer ci guarda dentro, la
  /// scuote, riprova: niente. Chi era nel mirino si rimbocca le maniche, e
  /// il killer molla tutto e scappa.
  void _jam(Canvas canvas) {
    final (walkX, walk, stride) = _entrance();
    const clicks = [_sStrike, 0.585, 0.635];
    final peek = _smooth(_span(t, 0.38, 0.46));
    final out = _smooth(_span(t, 0.46, 0.53));
    final inspect = _smooth(_span(t, 0.598, 0.612)) - _smooth(_span(t, 0.624, 0.633));
    final panic = _smooth(_span(t, 0.645, 0.655));
    final flee = _span(t, 0.658, 0.72);
    var kick = 0.0;
    for (final at in clicks) {
      final life = _span(t, at, at + 0.012);
      if (life > 0 && life < 1) kick = max(kick, sin(pi * life));
    }
    final shake = inspect > 0.5 ? sin(t * 600) * 0.12 : 0.0;
    final fleeing = flee > 0;
    // Sopra un agguato della famiglia, il killer è il suo: qui restano solo
    // i clic, il dubbio e chi era nel mirino.
    final alone = _cut != _Cut.rescue;
    final killerX = !alone
        ? _handover!.killer?.dx ?? _cornerX
        : fleeing
        ? _mix(_cornerX, _hiddenX + _u * 0.5, Curves.easeIn.transform(flee))
        : _mix(_mix(_hiddenX, _peekX, peek), _cornerX, out);
    final double arm;
    final double elbow;
    if (fleeing) {
      (arm, elbow) = (0.5 + sin(t * 300) * 0.5, 0.6);
    } else if (panic > 0) {
      (arm, elbow) = (_mix(pi / 2, 2.7, panic), _mix(0.03, 0.3, panic));
    } else {
      (arm, elbow) = (
        _mix(_mix(0.2, pi / 2, out) + 0.12 * kick, 1.25 + shake, inspect),
        _mix(0.03 - 0.06 * kick, 2.25, inspect),
      );
    }
    final dropped = t >= 0.652;
    if (alone) {
      _jammedGunman(
        canvas,
        killerX,
        fleeing: fleeing,
        out: out,
        kick: kick,
        inspect: inspect,
        panic: panic,
        arm: arm,
        elbow: elbow,
        dropped: dropped,
        clicks: clicks,
      );
    }
    if (inspect > 0.3) _mark(canvas, '?', Offset(killerX - _u * 0.05, _ground - _u * 1.45));
    _exclaim(canvas, Offset(killerX, _ground - _u * 1.45), _span(t, 0.642, 0.665));

    // Chi era nel mirino: si ripara, poi capisce, poi alza i pugni.
    final facing = _luckyFacing(t < 0.37 ? 1 : (t < 0.512 ? -1 : 1));
    final flinch = _smooth(_span(t, _sStrike - 0.004, _sStrike + 0.008)) - _smooth(_span(t, 0.605, 0.625));
    final square = _smooth(_span(t, 0.628, 0.65)) - _smooth(_span(t, 0.74, 0.76));
    final advance = _smooth(_span(t, 0.64, 0.675));
    final tipHat = _smooth(_span(t, 0.765, 0.785));
    final x = walkX + _u * 0.28 * advance;
    final punch = square > 0.5 ? sin(t * 260) * 0.12 : 0.0;
    if (t < 0.50) {
      _victim(canvas, x: x, facing: facing, walk: walk, stride: stride, smoking: t > 0.37);
    } else if (!_victimOffstage) {
      _person(
        canvas,
        feet: Offset(x, _ground),
        facing: facing,
        walk: t * 300,
        stride: advance > 0 && advance < 1 ? 0.8 : 0,
        crouch: 0.25 * flinch + 0.15 * square,
        lean: -0.18 * flinch + 0.12 * square,
        arm: _mix(_mix(_mix(0.08, 2.45, flinch), 1.15 + punch, square), 2.35, tipHat),
        elbow: _mix(_mix(_mix(0.2, 0.9, flinch), 1.65, square), 1.25, tipHat),
        backArm: _mix(_mix(-0.1, 2.2, flinch), 1.0 - punch, square),
        backElbow: _mix(_mix(0.2, 0.9, flinch), 1.75, square),
        hat: victimHat,
        smoking: t < _sStrike,
      );
    }
    _droppedCigarette(
      canvas,
      _onBody(const Offset(0.11, -0.435), feet: Offset(walkX, _ground), facing: 1),
      _span(t, _sStrike + 0.005, _sStrike + 0.055),
    );
    if (alone) _dust(canvas, Offset(_cornerX + _u * 0.1, _ground), _span(t, 0.66, 0.74), size: 0.5);
  }

  /// Il killer della pistola inceppata: clic, la guarda, la scuote, la molla
  /// e scappa.
  void _jammedGunman(
    Canvas canvas,
    double killerX, {
    required bool fleeing,
    required double out,
    required double kick,
    required double inspect,
    required double panic,
    required double arm,
    required double elbow,
    required bool dropped,
    required List<double> clicks,
  }) {
    _person(
      canvas,
      feet: Offset(killerX, _ground),
      facing: fleeing ? 1 : -1,
      walk: t * 320,
      stride: (out > 0 && out < 1) || fleeing ? 1 : 0,
      lean: fleeing ? 0.25 : 0.10 * out - 0.08 * kick + 0.10 * inspect - 0.15 * panic,
      arm: arm,
      elbow: elbow,
      backArm: panic > 0 && !fleeing ? _mix(-0.1, 2.6, panic) : -0.1,
      prop: dropped ? _Prop.none : _Prop.pistol,
      killer: true,
    );
    // La pistola mollata lì, che rimbalza sull'asfalto.
    if (dropped) {
      final fall = _span(t, 0.652, 0.665);
      final at = Offset(_cornerX - _u * 0.30, _mix(_ground - _u * 1.0, _ground - _u * 0.04, fall * fall));
      final spin = fall < 1 ? fall * 6 : pi * 0.98;
      final along = Offset(cos(spin), sin(spin));
      _drawPistol(canvas, at, along, Offset(-along.dy, along.dx), _u * 1.08);
    }
    _wall(canvas);
    // Ogni clic: solo un filo di polvere dalla canna, niente fiammata.
    if (!fleeing && panic <= 0) {
      final (hand, along) = _handOf(
        feet: Offset(killerX, _ground),
        facing: -1,
        lean: 0.10 * out - 0.08 * kick,
        arm: arm,
        elbow: elbow,
        killer: true,
      );
      final muzzle = _muzzleOf(hand, along, _Prop.pistol);
      for (final at in clicks) {
        _puff(canvas, muzzle, _span(t, at, at + 0.05), size: 0.12, color: const Color(0xFFB8B2AA));
      }
    }
  }

  // ---------------------------------------------------------------- banana

  /// Il killer arriva di corsa, pesta la buccia di banana e vola: il colpo
  /// finisce in cielo, lui di schiena sull'asfalto con la buccia in testa.
  void _banana(Canvas canvas) {
    final (walkX, walk, stride) = _entrance();
    final peelX = _victimX + _u * 0.50;
    final run = _span(t, 0.455, 0.525);
    final air = _span(t, 0.525, 0.578);
    final up = _smooth(_span(t, 0.66, 0.70));
    final limp = _span(t, 0.70, 0.80);
    final slideX = peelX - _u * 0.28;

    Offset feet;
    var tilt = 0.0;
    var crouch = 0.0;
    var lean = 0.15;
    var facing = -1;
    var stride2 = 0.0;
    // Chi spara corre con l'arma puntata; chi colpisce, col braccio su.
    final weapon = _weapon;
    final (aimArm, aimElbow) = _fires ? (pi / 2, 0.03) : (weapon == _Prop.bat ? (2.7, 0.6) : (2.85, 0.5));
    var arm = aimArm;
    var elbow = aimElbow;
    var backArm = -0.1;
    if (t < 0.525) {
      feet = Offset(_mix(_w + _u * 0.5, peelX, run), _ground);
      stride2 = run > 0 && run < 1 ? 1 : 0;
    } else if (t < 0.578) {
      // In aria: i piedi vanno avanti, la schiena indietro, le braccia su.
      final spin = Curves.easeOut.transform(_span(air, 0, 0.7));
      feet = Offset(_mix(peelX, slideX, air), _ground - sin(pi * air) * _u * 0.32);
      tilt = 1.45 * spin;
      lean = 0.15 - 0.4 * spin;
      arm = _mix(aimArm, 2.9, spin);
      elbow = 0.1;
      backArm = _mix(-0.1, 2.4, spin);
    } else if (up <= 0) {
      feet = Offset(slideX, _ground - _u * 0.02);
      tilt = 1.45;
      lean = -0.25;
      arm = 2.6;
      backArm = 2.2;
    } else if (limp <= 0) {
      feet = Offset(slideX, _ground);
      tilt = 1.45 * (1 - up);
      crouch = 0.6 * (1 - up);
      lean = _mix(-0.25, 0.30, up);
      arm = _mix(2.6, 0.3, up);
      backArm = _mix(2.2, -0.9, up);
    } else {
      // Se ne va zoppicando, una mano sulla schiena.
      feet = Offset(_mix(slideX, _w + _u * 0.6, Curves.easeIn.transform(limp)), _ground);
      facing = 1;
      stride2 = 0.6;
      lean = 0.35;
      arm = 0.3;
      backArm = -1.2;
    }
    final kStride = stride2;
    final kWalk = t * 330;
    _person(
      canvas,
      feet: feet,
      facing: facing,
      walk: kWalk,
      stride: kStride,
      tilt: tilt,
      lean: lean,
      crouch: crouch,
      arm: arm,
      elbow: elbow,
      backArm: backArm,
      backElbow: 0.3,
      prop: _fires || t < 0.525 ? weapon : _Prop.none,
      killer: true,
    );
    // Il colpo parte mentre è in aria: dritto verso il cielo.
    final bang = _span(t, _sStrike, _sStrike + 0.03);
    if (!_fires) _thrownWeapon(canvas, weapon, peelX, aimArm, aimElbow);
    if (bang > 0 && bang < 1 && _fires) {
      final (hand, along) = _handOf(
        feet: feet,
        facing: facing,
        tilt: tilt,
        lean: lean,
        arm: arm,
        elbow: elbow,
        killer: true,
      );
      final muzzle = _muzzleOf(hand, along, weapon);
      _muzzleFlash(canvas, muzzle, bang, toward: along, size: weapon == _Prop.pistol ? 0.7 : 1.1);
      _tracer(canvas, muzzle, muzzle + along * (_u * 2.6), bang);
      _flash(canvas, bang, strength: 0.3);
    }
    // La schiena che sbatte: polvere e stelline.
    final head = feet + Offset(_u * 0.92, -_u * 0.10);
    _puff(canvas, Offset(slideX + _u * 0.5, _ground - _u * 0.06), _span(t, 0.578, 0.66), size: 0.5);
    if (t > 0.585 && up <= 0.3) _bonkStars(canvas, head.translate(0, -_u * 0.18), _span(t, 0.585, 0.68));

    // La buccia: a terra, poi in aria, poi in faccia al killer.
    final fly = _span(t, 0.525, 0.61);
    final Offset peelAt;
    double peelSpin = 0;
    if (t < 0.525) {
      peelAt = Offset(peelX, _ground - _u * 0.01);
    } else if (fly < 1) {
      final land = Offset(slideX + _u * 0.92, _ground - _u * 0.14);
      peelAt = Offset(_mix(peelX + _u * 0.1, land.dx, fly), _mix(_ground, land.dy, fly) - sin(pi * fly) * _u * 1.1);
      peelSpin = fly * 14;
    } else if (up <= 0.2) {
      peelAt = Offset(slideX + _u * 0.92, _ground - _u * 0.14);
      peelSpin = 0.4;
    } else {
      final drop = _span(t, 0.665, 0.69);
      peelAt = Offset(slideX + _u * 0.75, _mix(_ground - _u * 0.4, _ground - _u * 0.01, drop * drop));
      peelSpin = drop < 1 ? 0.4 + drop * 5 : 0;
    }
    _peel(canvas, peelAt, peelSpin);

    // Chi era nel mirino si volta, salta allo sparo, e ride.
    final facingV = t < 0.37 ? 1 : (t < 0.52 ? -1 : 1);
    final hop = sin(pi * _span(t, _sStrike, _sStrike + 0.03)) * _u * 0.07;
    final laugh = _smooth(_span(t, 0.62, 0.64)) - _smooth(_span(t, 0.76, 0.78));
    if (t < 0.50) {
      _victim(canvas, x: walkX, facing: facingV, walk: walk, stride: stride, smoking: t > 0.37);
    } else {
      _person(
        canvas,
        feet: Offset(walkX, _ground - hop),
        facing: facingV,
        lean: -0.15 * laugh + sin(t * 380) * 0.05 * laugh,
        arm: _mix(_mix(0.08, 2.2, hop / (_u * 0.07)), 0.75, laugh),
        elbow: _mix(0.2, 1.7, laugh),
        backArm: _mix(-0.1, 0.6, laugh),
        backElbow: _mix(0.2, 1.5, laugh),
        hat: victimHat,
        smoking: t < _sStrike,
      );
    }
    _droppedCigarette(
      canvas,
      _onBody(const Offset(0.11, -0.435), feet: Offset(walkX, _ground), facing: 1),
      _span(t, _sStrike + 0.005, _sStrike + 0.055),
    );
  }

  /// Il pugnale o la mazza che, alla scivolata, volano di mano al killer:
  /// su in alto girando, e giù dietro di lui. Il pugnale si pianta
  /// nell'asfalto, la mazza rimbalza e resta lì.
  void _thrownWeapon(Canvas canvas, _Prop weapon, double peelX, double arm, double elbow) {
    if (t < 0.525) return;
    final (hand, _) = _handOf(
      feet: Offset(peelX, _ground),
      facing: -1,
      lean: 0.15,
      arm: arm,
      elbow: elbow,
      killer: true,
    );
    final knife = weapon == _Prop.knife;
    final fly = _span(t, 0.525, 0.605);
    final land = Offset(peelX + _u * 0.62, _ground - _u * (knife ? 0.20 : 0.035));
    final bounce = knife ? 0.0 : sin(pi * _span(t, 0.605, 0.625)) * _u * 0.08;
    final at = fly < 1
        ? Offset(_mix(hand.dx, land.dx, fly), _mix(hand.dy, land.dy, fly) - sin(pi * fly) * _u * 1.3)
        : land.translate(0, -bounce);
    // Gira in aria; il pugnale atterra di punta, la mazza di piatto.
    final rest = knife ? atan2(1.0, 0.18) : 0.04;
    final spin = fly < 1 ? -pi / 2 + fly * (4 * pi + rest + pi / 2) : rest;
    _held(canvas, at, Offset(cos(spin), sin(spin)), _u * 1.08, weapon);
  }

  /// La buccia di banana, con le falde aperte.
  void _peel(Canvas canvas, Offset at, double spin) {
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(spin);
    final yellow = Paint()..color = const Color(0xFFF2D04A);
    final edge = Paint()
      ..color = const Color(0xFF7A5A1C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = _u * 0.008;
    for (final a in [-2.5, -1.6, -0.6]) {
      final tip = Offset(cos(a), sin(a) * 0.55) * (_u * 0.11);
      final flap = Path()
        ..moveTo(-_u * 0.015, 0)
        ..quadraticBezierTo(tip.dx * 0.5 - _u * 0.02, tip.dy * 0.5 - _u * 0.02, tip.dx, tip.dy)
        ..quadraticBezierTo(tip.dx * 0.5 + _u * 0.02, tip.dy * 0.5 + _u * 0.01, _u * 0.015, 0)
        ..close();
      canvas.drawPath(flap, yellow);
      canvas.drawPath(flap, edge);
    }
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: _u * 0.06, height: _u * 0.035), yellow);
    canvas.drawCircle(Offset(_u * 0.03, _u * 0.005), _u * 0.012, Paint()..color = const Color(0xFF4A3410));
    canvas.restore();
  }

  // ------------------------------------------------------------ gatto nero

  /// Sul bidone accanto all'angolo dorme un gatto nero. Quando il killer
  /// prende la mira gli salta sul braccio: il colpo va in cielo, la pistola
  /// vola via, il killer scappa. Il gatto si siede davanti al suo salvato.
  void _blackCat(Canvas canvas) {
    final (walkX, walk, stride) = _entrance();
    final canX = _cornerX - _u * 0.30;
    final lid = Offset(canX, _ground - _u * 0.40);
    final peek = _smooth(_span(t, 0.38, 0.46));
    final out = _smooth(_span(t, 0.46, 0.53));
    final yank = _smooth(_span(t, 0.552, 0.566));
    final flail = _span(t, 0.566, 0.635);
    final flee = _span(t, 0.635, 0.70);
    final fleeing = flee > 0;
    final killerX = fleeing
        ? _mix(_cornerX, _hiddenX + _u * 0.5, Curves.easeIn.transform(flee))
        : _mix(_mix(_hiddenX, _peekX, peek), _cornerX, out);
    final thrash = flail > 0 && flail < 1 ? sin(t * 420) : 0.0;
    // La lupara e il mitra si puntano a due mani.
    final weapon = _weapon;
    final (aimArm, aimElbow, aimBack) = switch (weapon) {
      _Prop.lupara => (1.38, 0.18, 1.50),
      _Prop.tommy => (0.55, 1.05, 1.25),
      _ => (pi / 2, 0.03, -0.1),
    };
    final arm = fleeing
        ? 0.5 + sin(t * 300) * 0.5
        : (flail > 0 ? 2.5 + 0.4 * thrash : _mix(_mix(0.2, aimArm, out), 2.75, yank));
    final elbow = fleeing ? 0.6 : (flail > 0 ? 0.6 : _mix(_mix(0.2, aimElbow, out), 0.15, yank));
    final lean = fleeing ? 0.25 : 0.10 * out - 0.15 * yank - 0.1 * thrash.abs();
    final killerFeet = Offset(killerX, _ground);
    final hasGun = t < 0.566;
    _person(
      canvas,
      feet: killerFeet,
      facing: fleeing ? 1 : -1,
      walk: t * 320,
      stride: (out > 0 && out < 1) || fleeing ? 1 : 0,
      lean: lean,
      arm: arm,
      elbow: elbow,
      backArm: flail > 0 && !fleeing
          ? 2.4 - 0.4 * thrash
          : (fleeing ? -0.1 : _mix(_mix(-0.1, aimBack, out), -0.1, yank)),
      backElbow: 0.6,
      hatOn: t < 0.575,
      prop: hasGun ? weapon : _Prop.none,
      killer: true,
    );
    final (hand, along) = _handOf(feet: killerFeet, facing: -1, lean: lean, arm: arm, elbow: elbow, killer: true);
    _wall(canvas);
    // Il cappello del killer che vola via graffiato.
    final hatFly = _span(t, 0.575, 0.64);
    if (hatFly > 0) {
      _looseHat(
        canvas,
        Offset(
          _mix(killerX + _u * 0.05, _cornerX - _u * 0.85, hatFly),
          _mix(_ground - _u * 1.10, _ground - _u * 0.03, hatFly * hatFly) - sin(pi * hatFly) * _u * 0.4,
        ),
        hatFly < 1 ? hatFly * 8 : 0.1,
      );
    }

    // Il bidone, col coperchio che salta quando il gatto spicca il balzo.
    _trashCan(canvas, canX, lidOff: _span(t, 0.535, 0.58));

    // Il gatto: seduto, poi col pelo dritto, poi il salto sul braccio, la
    // testa del killer, giù a terra, e via verso chi ha salvato.
    final leap = _span(t, 0.535, 0.552);
    final down = _span(t, 0.635, 0.66);
    final stroll = _span(t, 0.66, 0.73);
    final sitAt = Offset(walkX + _u * 0.34, _ground);
    final landAt = Offset(_cornerX - _u * 0.55, _ground);
    if (t < 0.50) {
      _kitty(canvas, lid, pose: _CatPose.sit, blink: (t * 7) % 1 < 0.06);
    } else if (t < 0.535) {
      _kitty(canvas, lid, pose: _CatPose.arch);
    } else if (leap < 1) {
      final to = hand.translate(_u * 0.05, _u * 0.06);
      final at = Offset(_mix(lid.dx, to.dx, leap), _mix(lid.dy, to.dy, leap) - sin(pi * leap) * _u * 0.30);
      _kitty(canvas, at, pose: _CatPose.leap, spin: -0.5 + leap * 0.6);
    } else if (t < 0.566) {
      _kitty(canvas, hand.translate(_u * 0.05, _u * 0.10), pose: _CatPose.leap, spin: -0.9);
    } else if (t < 0.635) {
      // In testa al killer, a graffiare.
      final head = _onBody(const Offset(0.03, -0.60), feet: killerFeet, facing: -1, lean: lean, killer: true);
      _kitty(canvas, head.translate(sin(t * 420) * _u * 0.03, 0), pose: _CatPose.arch, facing: 1);
      final scratch = (t * 40) % 1;
      final claw = Paint()
        ..color = Colors.white.withValues(alpha: 1 - scratch)
        ..strokeWidth = _u * 0.010
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 3; i++) {
        final s = head.translate(-_u * (0.14 + 0.03 * i), -_u * 0.02);
        canvas.drawLine(s, s.translate(-_u * 0.05, _u * 0.10), claw);
      }
    } else if (down < 1) {
      final from = _onBody(const Offset(0.03, -0.60), feet: Offset(_cornerX, _ground), facing: -1, killer: true);
      final at = Offset(
        _mix(from.dx, landAt.dx, down),
        _mix(from.dy, landAt.dy, down * down) - sin(pi * down) * _u * 0.2,
      );
      _kitty(canvas, at, pose: _CatPose.leap, spin: 0.4);
    } else if (stroll < 1) {
      _cat(canvas, _mix(landAt.dx, sitAt.dx, stroll), t * 260);
    } else {
      _kitty(canvas, sitAt, pose: _CatPose.sit, blink: (t * 5) % 1 < 0.05);
    }

    // Il colpo storto, verso il cielo; la pistola vola via e cade.
    final bang = _span(t, _sStrike, _sStrike + 0.03);
    if (bang > 0 && bang < 1) {
      final muzzle = _muzzleOf(hand, along, weapon);
      _muzzleFlash(canvas, muzzle, bang, toward: along, size: weapon == _Prop.pistol ? 0.7 : 1.1);
      _star(canvas, muzzle, _u * 0.08 * (1 - bang), const Color(0xFFFFF3C4).withValues(alpha: 1 - bang));
      _tracer(canvas, muzzle, muzzle + along * (_u * 2.4), bang);
      _flash(canvas, bang, strength: 0.3);
    }
    if (!hasGun) {
      final fly = _span(t, 0.566, 0.625);
      final slide = _smooth(_span(t, 0.625, 0.66));
      final from = hand;
      final land = Offset(walkX + _u * 0.62, _ground - _u * 0.035);
      final at = fly < 1
          ? Offset(_mix(from.dx, land.dx, fly), _mix(from.dy, land.dy, fly) - sin(pi * fly) * _u * 0.55)
          : land.translate(-_u * 0.10 * slide, 0);
      final spin = fly < 1 ? fly * 15 : pi;
      _held(canvas, at, Offset(cos(spin), sin(spin)), _u * 1.08, weapon);
      if (fly >= 1) _dust(canvas, land, _span(t, 0.625, 0.68), size: 0.3, seed: 9);
    }
    // Il ciuffo di pelo nero che resta in aria.
    _spray(
      canvas,
      hand,
      _span(t, 0.552, 0.62),
      seed: 13,
      color: const Color(0xFF1A1B20),
      count: 10,
      bias: const Offset(0, -0.7),
      reach: 0.5,
    );

    // Chi era nel mirino: si ripara allo sparo, poi si china ad
    // accarezzare il gatto e si tocca il cappello.
    final facing = t < 0.37 ? 1 : (t < 0.512 ? -1 : 1);
    final flinch = _smooth(_span(t, _sStrike - 0.004, _sStrike + 0.01)) - _smooth(_span(t, 0.60, 0.625));
    final pet = _smooth(_span(t, 0.735, 0.755)) - _smooth(_span(t, 0.80, 0.82));
    final stroke = pet > 0.5 ? sin(t * 160) * 0.12 : 0.0;
    if (t < 0.50) {
      _victim(canvas, x: walkX, facing: facing, walk: walk, stride: stride, smoking: t > 0.37);
    } else {
      _person(
        canvas,
        feet: Offset(walkX, _ground),
        facing: facing,
        crouch: 0.25 * flinch + 0.75 * pet,
        lean: -0.18 * flinch + 0.55 * pet,
        arm: _mix(_mix(0.08, 2.45, flinch), 0.75 + stroke, pet),
        elbow: _mix(_mix(0.2, 0.9, flinch), 0.25, pet),
        backArm: _mix(-0.1, 2.2, flinch),
        backElbow: _mix(0.2, 0.9, flinch),
        hat: victimHat,
        smoking: t < _sStrike,
      );
    }
    _droppedCigarette(
      canvas,
      _onBody(const Offset(0.11, -0.435), feet: Offset(walkX, _ground), facing: 1),
      _span(t, _sStrike + 0.005, _sStrike + 0.055),
    );
    if (pet > 0.6) {
      _heart(canvas, sitAt.translate(0, -_u * (0.40 + 0.1 * pet)), _u * 0.03, const Color(0xFFE23A4A));
    }
  }

  /// Il bidone della spazzatura; [lidOff] fa saltare il coperchio.
  void _trashCan(Canvas canvas, double x, {double lidOff = 0}) {
    final body = Rect.fromLTRB(x - _u * 0.14, _ground - _u * 0.38, x + _u * 0.14, _ground);
    canvas.drawRect(body.translate(-_u * 0.012, -_u * 0.008), Paint()..color = _sRim);
    canvas.drawRect(body, Paint()..color = const Color(0xFF26282E));
    final ridge = Paint()
      ..color = const Color(0xFF3B3E46)
      ..strokeWidth = _u * 0.012;
    for (final f in [0.25, 0.5, 0.75]) {
      final y = _mix(body.top, body.bottom, f);
      canvas.drawLine(Offset(body.left, y), Offset(body.right, y), ridge);
    }
    final fly = lidOff;
    final lidAt = Offset(
      x + _u * 0.25 * fly,
      _mix(body.top - _u * 0.015, _ground - _u * 0.02, fly * fly) - sin(pi * fly) * _u * 0.25,
    );
    canvas.save();
    canvas.translate(lidAt.dx, lidAt.dy);
    canvas.rotate(fly * 2 * pi);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: _u * 0.33, height: _u * 0.04),
        Radius.circular(_u * 0.02),
      ),
      Paint()..color = const Color(0xFF3B3E46),
    );
    canvas.drawRect(
      Rect.fromCenter(center: Offset(0, -_u * 0.03), width: _u * 0.06, height: _u * 0.025),
      Paint()..color = const Color(0xFF3B3E46),
    );
    canvas.restore();
  }

  /// Il gatto nero in posa: seduto, col pelo dritto o in pieno balzo. [at]
  /// è dove poggia (o il centro, in volo); guarda a sinistra se [facing] è 1.
  void _kitty(Canvas canvas, Offset at, {required _CatPose pose, int facing = 1, double spin = 0, bool blink = false}) {
    final ink = Paint()..color = const Color(0xFF08080A);
    final rim = Paint()..color = _sRim;
    final tail = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(spin);
    canvas.scale(facing.toDouble(), 1);
    void shape(Paint paint, {required bool details}) {
      Offset head;
      switch (pose) {
        case _CatPose.sit:
          canvas.drawOval(Rect.fromCenter(center: Offset(0, -_u * 0.10), width: _u * 0.16, height: _u * 0.21), paint);
          head = Offset(-_u * 0.035, -_u * 0.24);
          canvas.drawPath(
            Path()
              ..moveTo(_u * 0.06, -_u * 0.02)
              ..quadraticBezierTo(_u * 0.20, 0, _u * 0.16, -_u * 0.12),
            tail
              ..color = paint.color
              ..strokeWidth = _u * 0.03,
          );
        case _CatPose.arch:
          canvas.drawPath(
            Path()
              ..moveTo(-_u * 0.15, -_u * 0.10)
              ..quadraticBezierTo(0, -_u * 0.36, _u * 0.15, -_u * 0.10)
              ..lineTo(_u * 0.10, -_u * 0.06)
              ..quadraticBezierTo(0, -_u * 0.24, -_u * 0.10, -_u * 0.06)
              ..close(),
            paint,
          );
          final legs = Paint()
            ..color = paint.color
            ..strokeWidth = _u * 0.03
            ..strokeCap = StrokeCap.round;
          for (final x in [-0.12, -0.09, 0.09, 0.12]) {
            canvas.drawLine(Offset(_u * x, -_u * 0.10), Offset(_u * x, 0), legs);
          }
          head = Offset(-_u * 0.17, -_u * 0.14);
          canvas.drawPath(
            Path()
              ..moveTo(_u * 0.14, -_u * 0.12)
              ..quadraticBezierTo(_u * 0.20, -_u * 0.22, _u * 0.16, -_u * 0.38),
            tail
              ..color = paint.color
              ..strokeWidth = _u * 0.055,
          );
        case _CatPose.leap:
          canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: _u * 0.34, height: _u * 0.10), paint);
          final legs = Paint()
            ..color = paint.color
            ..strokeWidth = _u * 0.026
            ..strokeCap = StrokeCap.round;
          canvas.drawLine(Offset(-_u * 0.12, _u * 0.02), Offset(-_u * 0.26, _u * 0.04), legs);
          canvas.drawLine(Offset(-_u * 0.10, _u * 0.03), Offset(-_u * 0.24, _u * 0.08), legs);
          canvas.drawLine(Offset(_u * 0.12, _u * 0.02), Offset(_u * 0.25, _u * 0.07), legs);
          canvas.drawLine(Offset(_u * 0.10, _u * 0.03), Offset(_u * 0.22, _u * 0.10), legs);
          head = Offset(-_u * 0.19, -_u * 0.04);
          canvas.drawPath(
            Path()
              ..moveTo(_u * 0.15, -_u * 0.01)
              ..quadraticBezierTo(_u * 0.30, -_u * 0.04, _u * 0.36, -_u * 0.14),
            tail
              ..color = paint.color
              ..strokeWidth = _u * 0.04,
          );
      }
      canvas.drawCircle(head, _u * 0.06, paint);
      for (final dx in [-0.035, 0.03]) {
        canvas.drawPath(
          Path()
            ..moveTo(head.dx + _u * (dx - 0.022), head.dy - _u * 0.035)
            ..lineTo(head.dx + _u * dx, head.dy - _u * 0.105)
            ..lineTo(head.dx + _u * (dx + 0.022), head.dy - _u * 0.035)
            ..close(),
          paint,
        );
      }
      if (details) {
        final eye = Paint()..color = const Color(0xFFE8D24A);
        for (final dx in [-0.035, 0.0]) {
          final c = head.translate(_u * dx - _u * 0.005, -_u * 0.005);
          if (blink) {
            canvas.drawLine(c.translate(-_u * 0.01, 0), c.translate(_u * 0.01, 0), eye..strokeWidth = _u * 0.006);
          } else {
            canvas.drawCircle(c, _u * 0.013, eye);
          }
        }
        if (pose == _CatPose.arch) {
          // Il soffio: la bocca aperta e i denti.
          canvas.drawCircle(
            head.translate(-_u * 0.05, _u * 0.025),
            _u * 0.014,
            Paint()..color = const Color(0xFFE23A4A),
          );
        }
      }
    }

    canvas.save();
    canvas.translate(_u * 0.012, -_u * 0.008);
    shape(rim, details: false);
    canvas.restore();
    shape(ink, details: true);
    canvas.restore();
  }

  // ------------------------------------------------------- stub provvisori
}

/// Quello che resta sul petto di chi si rialza.
enum _Mark { none, sash, stitched }

/// Le pose del gatto nero.
enum _CatPose { sit, arch, leap }
