part of 'death_scene.dart';

// La regia dei filmati della notte. La coreografia (il pugnale, la lupara,
// l'auto...) dice cosa succede e quando; la regia dice come lo si gira: da
// che parte arriva il killer, dove aspetta, cosa fa la vittima mentre
// aspetta, dove sta la cinepresa. Le due cose cambiano ognuna per conto suo,
// così due notti con la stessa arma non sembrano lo stesso filmato.
//
// La regia non sposta i tempi: il colpo resta a [DeathScenePainter.strike],
// e così ogni suono di [sceneCuesFor]. I passi della vittima restano nove,
// fra 0.04 e 0.34, anche quando esce dalla porta del bar invece di arrivare
// dal fondo della strada.

/// Dove aspetta il killer, prima di uscire.
enum Cover {
  /// Dietro l'angolo del palazzo: il classico.
  corner,

  /// Dietro l'edicola dei giornali, chiusa per la notte.
  kiosk,

  /// Dietro un portone: si apre, e lui è lì in controluce.
  doorway,

  /// Già lì dall'inizio, nel buio di un androne: si vedono solo la brace
  /// della sigaretta e il riflesso sotto la tesa.
  shadow,
}

/// Cosa fa la vittima mentre aspetta.
enum Business {
  /// Si accende una sigaretta: il classico.
  smoke,

  /// Apre il giornale, e quando arriva il colpo i fogli volano via.
  newspaper,

  /// Piove: aspetta sotto l'ombrello, che poi vola via.
  umbrella,

  /// Si china ad allacciarsi una scarpa, e si rialza appena in tempo.
  shoelace,
}

/// Come guarda la cinepresa.
enum Shot {
  /// Parte larga e stringe piano verso il colpo: il classico.
  push,

  /// Dal basso, che guarda in su: i lampioni pendono, le figure torreggiano.
  low,

  /// Larga e ferma, come un palcoscenico visto dalla platea.
  wide,

  /// Inclinata; quando si apre il nascondiglio va a guardarlo, e sul colpo
  /// uno stacco secco al primo piano.
  closeUp,
}

/// Da dove viene la luce della scena.
enum Light {
  /// Il lampione: il classico.
  lamp,

  /// La vetrina accesa di un bar: chi ci passa davanti è una sagoma nera.
  window,
}

/// Da dove arriva la vittima.
enum Arrival {
  /// Dal fondo della strada: il classico.
  street,

  /// Dalla porta del bar, che si richiude alle sue spalle.
  door,
}

/// Cosa fa la vittima quando arriva il colpo.
enum Reaction {
  /// Niente: non se ne accorge. Il classico.
  unaware,

  /// Si gira all'ultimo, vede il killer e alza le mani.
  turns,
}

/// La regia di un filmato: ogni asse cambia per conto suo, e nessuno
/// cambia i tempi della coreografia.
@immutable
class Staging {
  /// Il nome di lavorazione, per i provini.
  final String name;

  /// La scena ribaltata: il killer arriva da sinistra.
  final bool mirrored;
  final Cover cover;
  final Business business;
  final Shot shot;
  final Light light;
  final Arrival arrival;
  final Reaction reaction;

  const Staging({
    this.name = 'classica',
    this.mirrored = false,
    this.cover = Cover.corner,
    this.business = Business.smoke,
    this.shot = Shot.push,
    this.light = Light.lamp,
    this.arrival = Arrival.street,
    this.reaction = Reaction.unaware,
  });

  /// La regia di sempre: lampione a sinistra, angolo a destra.
  static const classic = Staging();

  /// L'edicola: scena ribaltata, la vittima legge il giornale, il killer
  /// esce da dietro l'edicola chiusa, la cinepresa guarda dal basso.
  static const kiosk = Staging(
    name: 'edicola',
    mirrored: true,
    cover: Cover.kiosk,
    business: Business.newspaper,
    shot: Shot.low,
  );

  /// Controluce: la vittima esce dal bar e aspetta sotto l'ombrello davanti
  /// alla vetrina accesa; il killer è nell'androne fin dall'inizio; la
  /// cinepresa larga e ferma.
  static const backlit = Staging(
    name: 'controluce',
    cover: Cover.shadow,
    business: Business.umbrella,
    shot: Shot.wide,
    light: Light.window,
    arrival: Arrival.door,
  );

  /// Il portone: scena ribaltata, la vittima si allaccia una scarpa, il
  /// portone si apre e c'è lui; la vittima si gira e alza le mani; sul
  /// colpo, il primo piano.
  static const doorway = Staging(
    name: 'portone',
    mirrored: true,
    cover: Cover.doorway,
    business: Business.shoelace,
    shot: Shot.closeUp,
    reaction: Reaction.turns,
  );

  /// I provini da far vedere prima di cambiare i filmati a tutti.
  static const demos = [kiosk, backlit, doorway];

  bool get isClassic =>
      !mirrored &&
      cover == Cover.corner &&
      business == Business.smoke &&
      shot == Shot.push &&
      light == Light.lamp &&
      arrival == Arrival.street &&
      reaction == Reaction.unaware;

  /// Quello che di questa regia [act] sa girare. Le coreografie non ancora
  /// provate con la regia nuova restano classiche; l'auto non ha nessuno
  /// dietro l'angolo e ha già la sua reazione (i fari negli occhi).
  Staging forAct(DeathAct act) => switch (act) {
    DeathAct.knife || DeathAct.gun || DeathAct.burst || DeathAct.lupara => this,
    DeathAct.car => Staging(
      name: name,
      mirrored: mirrored,
      business: business,
      shot: shot,
      light: light,
      arrival: arrival,
    ),
    _ => classic,
  };

  @override
  bool operator ==(Object other) =>
      other is Staging &&
      other.name == name &&
      other.mirrored == mirrored &&
      other.cover == cover &&
      other.business == business &&
      other.shot == shot &&
      other.light == light &&
      other.arrival == arrival &&
      other.reaction == reaction;

  @override
  int get hashCode =>
      Object.hash(name, mirrored, cover, business, shot, light, arrival, reaction);
}

/// La regia con cui si gira [story], scelta fra [from]. Dipende solo da
/// quello che la storia è (la scena, l'azione, il finale), non da un dado
/// tirato qui: online ogni telefono compone le stesse storie dal copione
/// col seme della partita, e così vede lo stesso filmato.
Staging stagingFor(
  DeathStory story, {
  List<Staging> from = const [Staging.classic, ...Staging.demos],
}) {
  var hash = 0x811c9dc5;
  for (final id in [
    story.scene.id,
    story.method.id,
    story.attack?.id ?? '',
    story.epilogue?.id ?? '',
  ]) {
    for (final unit in [...id.codeUnits, 0x2f]) {
      hash = ((hash ^ unit) * 0x01000193) & 0x7fffffff;
    }
  }
  return from[hash % from.length];
}

const _stInk = DeathScenePainter._ink;
const _stRim = DeathScenePainter._rim;
const _stWarm = DeathScenePainter._warm;
const _stStrike = DeathScenePainter.strike;

typedef _Pose = ({
  double arm,
  double elbow,
  double backArm,
  double backElbow,
  double lean,
  double crouch,
});

const _Pose _idle = (
  arm: 0.08,
  elbow: 0.20,
  backArm: -0.10,
  backElbow: 0.20,
  lean: 0.0,
  crouch: 0.0,
);

const _newsprint = Color(0xFFC9C0A6);
const _newsShade = Color(0xFF8E866F);
const _newsInk = Color(0xFF3A362E);

extension _Staged on DeathScenePainter {
  // ------------------------------------------------------------ inquadratura

  /// Ribalta la scena intorno al centro dello schermo.
  void _mirror(Canvas canvas) {
    if (!staging.mirrored) return;
    canvas.translate(_w, 0);
    canvas.scale(-1, 1);
  }

  /// In una scena ribaltata, rimette dritto quello che va letto.
  void _readable(Canvas canvas) {
    if (staging.mirrored) canvas.scale(-1, 1);
  }

  /// La cinepresa della regia.
  void _stagedCamera(Canvas canvas) {
    switch (staging.shot) {
      case Shot.push:
        final lens = _lens;
        _shoot(canvas, lens);
        _zoom = lens.$1;
      case Shot.low:
        _lowAngle(canvas);
      case Shot.wide:
        _wideShot(canvas);
      case Shot.closeUp:
        _closeUp(canvas);
    }
  }

  /// Mette [focus] (un punto della scena) in [screen], con [zoom] e la
  /// cinepresa inclinata di [roll].
  void _frameOn(
    Canvas canvas,
    Offset focus,
    double zoom, {
    Offset? screen,
    double roll = 0,
  }) {
    final at = screen ?? Offset(_w / 2, _ground - _u * 0.45);
    canvas.translate(at.dx, at.dy);
    if (roll != 0) canvas.rotate(roll);
    canvas.scale(zoom);
    canvas.translate(-focus.dx, -focus.dy);
    _zoom = zoom;
  }

  /// Dal basso: i piedi restano dove sono, tutto quello che sta in alto
  /// si allontana e le verticali si chiudono verso il cielo.
  void _lowAngle(Canvas canvas) {
    final car = act == DeathAct.car;
    final push = _smooth(_span(t, 0.30, 0.54));
    var zoom = car ? 1.05 : 1.24 + 0.16 * push;
    var focus = car ? _w / 2 : _mix(_w / 2, _mix(_victimX, _cornerX, 0.45), push);
    if (!car) {
      // Dopo il colpo si allarga un poco e va su chi è a terra.
      final settle = _smooth(_span(t, _stStrike + 0.04, _stStrike + 0.16));
      zoom = _mix(zoom, 1.16, settle);
      focus = _mix(focus, _mix(_restingCenter, _cornerX, 0.15), settle);
    }
    canvas.translate(_w / 2, _ground + _h * (car ? 0.05 : 0.065));
    canvas.transform(
      (Matrix4.identity()..setEntry(3, 1, -0.21 / _u)).storage,
    );
    canvas.scale(zoom);
    canvas.translate(-focus, -_ground);
    _zoom = zoom;
  }

  /// Il centro di quello che resta steso a terra dopo il colpo: la cinepresa,
  /// a cose fatte, lo vuole tutto in campo.
  double get _restingCenter {
    final down = _downs[act];
    if (down == null) return _victimX;
    return _victimX + down.$1 * _u - _u * 0.48;
  }

  /// Larga e ferma: si vede tutta la strada, e la cinepresa si muove appena.
  void _wideShot(Canvas canvas) {
    final horizon = _ground - _u * 0.45;
    if (act == DeathAct.car) {
      return _frameOn(canvas, Offset(_w / 2, horizon), 0.88);
    }
    final drift = _smooth(_span(t, 0.0, 0.55));
    final settle = _smooth(_span(t, _stStrike + 0.04, _stStrike + 0.16));
    final zoom = 0.84 + 0.05 * drift - 0.03 * settle;
    // Dopo il colpo, in campo chi è a terra e chi è stato.
    final focus = _mix(
      _mix(_w * 0.50, _w * 0.53, drift),
      _mix(_restingCenter, _cornerX, 0.40),
      settle,
    );
    _frameOn(canvas, Offset(focus, horizon), zoom);
  }

  /// Dove cade il colpo, per il primo piano.
  Offset get _hitPoint => switch (act) {
    DeathAct.knife => Offset(_victimX + _u * 0.18, _ground - _u * 0.74),
    DeathAct.gun || DeathAct.burst => Offset(
      _mix(_victimX, _cornerX, 0.42),
      _ground - _u * 0.78,
    ),
    DeathAct.lupara => Offset(
      _mix(_victimX, _cornerX + _u * 0.16, 0.42),
      _ground - _u * 0.80,
    ),
    DeathAct.car => Offset(_victimX - _u * 0.05, _ground - _u * 0.52),
    _ => Offset(_mix(_victimX, _cornerX, 0.3), _ground - _u * 0.74),
  };

  /// L'inquadratura inclinata, la cinepresa che va a guardare il
  /// nascondiglio quando si apre, e il primo piano secco sul colpo.
  void _closeUp(Canvas canvas) {
    final horizon = _ground - _u * 0.45;
    var (zoom, x) = _lens;
    var focus = Offset(x, horizon);
    var roll = 0.045 * _smooth(_span(t, 0.0, 0.40));
    if (act != DeathAct.car) {
      // Il portone si apre: la cinepresa si gira a guardarlo, e torna di
      // scatto sulla vittima quando lui esce.
      final look = _smooth(_span(t, 0.355, 0.405)) * (1 - _smooth(_span(t, 0.47, 0.50)));
      focus = Offset.lerp(focus, Offset(_cornerX + _u * 0.02, horizon), look)!;
      zoom = _mix(zoom, 1.08, look);
      roll *= 1 - look;
    }
    // Lo stacco: un attimo prima del colpo, il primo piano; quando il
    // corpo tocca terra, di nuovo largo.
    if (t >= _stStrike - 0.022 && t < _stStrike + 0.068) {
      final creep = _span(t, _stStrike - 0.022, _stStrike + 0.068);
      return _frameOn(
        canvas,
        _hitPoint.translate(0, -_u * 0.10),
        1.72 + 0.08 * creep,
        screen: Offset(_w / 2, _h * 0.47),
        roll: -0.075,
      );
    }
    if (t >= _stStrike + 0.068) {
      // Di nuovo largo, dritto, su chi è rimasto a terra.
      roll = 0;
      if (act != DeathAct.car) {
        zoom = 1.04;
        focus = Offset(_mix(_restingCenter, _cornerX, 0.28), horizon);
      }
    }
    _frameOn(canvas, focus, zoom, roll: roll);
  }

  // -------------------------------------------------------------- scenografia

  /// Il bar con la vetrina accesa, dietro la vittima.
  Rect get _cafeWindow => Rect.fromLTRB(
    _victimX - _u * 0.64,
    _ground - _u * 1.36,
    _victimX + _u * 0.52,
    _ground - _u * 0.20,
  );

  /// La porta del bar, a sinistra della vetrina.
  Rect get _cafeDoor => Rect.fromLTRB(
    _cafeWindow.left - _u * 0.46,
    _ground - _u * 1.20,
    _cafeWindow.left - _u * 0.10,
    _ground,
  );

  /// Quanto è aperta la porta del bar: si apre perché esca la vittima, e
  /// si richiude dietro di lei.
  double get _cafeDoorOpen => staging.arrival != Arrival.door
      ? 0
      : _smooth(_span(t, 0.0, 0.035)) - _smooth(_span(t, 0.13, 0.18));

  /// L'androne del killer, nel muro del palazzo all'angolo.
  Rect get _recess => switch (staging.cover) {
    Cover.doorway => Rect.fromLTRB(
      _cornerX + _u * 0.07,
      _ground - _u * 1.26,
      _cornerX + _u * 0.55,
      _ground,
    ),
    _ => Rect.fromLTRB(
      _cornerX + _u * 0.06,
      _ground - _u * 1.30,
      _cornerX + _u * 0.50,
      _ground,
    ),
  };

  /// Quanto è aperto il portone del killer.
  double get _doorOpen =>
      _smooth(_span(t, 0.355, 0.40)) - _smooth(_span(t, 0.87, 0.91));

  /// Dove aspetta il killer, a seconda del nascondiglio.
  double get _coverHidden => switch (staging.cover) {
    Cover.doorway => _cornerX + _u * 0.75,
    Cover.shadow => _cornerX + _u * 0.28,
    _ => _cornerX + _u * 0.75,
  };

  /// Fin dove si sporge per guardare.
  double get _coverPeek => switch (staging.cover) {
    Cover.doorway => _cornerX + _u * 0.25,
    Cover.shadow => _cornerX + _u * 0.16,
    _ => _cornerX + _u * 0.17,
  };

  /// Quello che sta dietro le figure: la facciata del bar, l'interno del
  /// portone, il fondo dell'androne. Si disegna prima della strada.
  void _setBehind(Canvas canvas) {
    if (staging.light == Light.window) _cafe(canvas);
    if (!_hasWall) return;
    switch (staging.cover) {
      case Cover.doorway:
        _doorwayInside(canvas);
      case Cover.shadow:
        _recessInside(canvas);
      case Cover.corner || Cover.kiosk:
        break;
    }
  }

  /// Sull'asfalto, dopo la strada: la luce che esce dalla vetrina e dal
  /// portone.
  void _setSpill(Canvas canvas) {
    if (staging.light == Light.window) {
      final window = _cafeWindow;
      canvas.drawPath(
        Path()
          ..moveTo(window.left, _ground)
          ..lineTo(window.right, _ground)
          ..lineTo(window.right + _u * 0.55, _ground + _u * 0.42)
          ..lineTo(window.left - _u * 0.35, _ground + _u * 0.42)
          ..close(),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _stWarm.withValues(alpha: 0.30),
              _stWarm.withValues(alpha: 0.0),
            ],
          ).createShader(
            Rect.fromLTRB(window.left, _ground, window.right, _ground + _u * 0.42),
          ),
      );
      // I riflessi sull'asfalto bagnato: strisce verticali che tremano.
      final streak = Paint()
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, _u * 0.02);
      for (var i = 0; i < 5; i++) {
        final x = _mix(window.left + _u * 0.10, window.right - _u * 0.10, i / 4);
        streak.color = _stWarm.withValues(alpha: 0.10 + 0.05 * sin(t * 50 + i * 1.7));
        canvas.drawRect(
          Rect.fromLTWH(
            x - _u * 0.03,
            _ground + _u * 0.05,
            _u * 0.06,
            _u * (0.22 + 0.08 * (i % 2)),
          ),
          streak,
        );
      }
      final door = _cafeDoorOpen;
      if (door > 0) {
        final d = _cafeDoor;
        canvas.drawPath(
          Path()
            ..moveTo(d.left, _ground)
            ..lineTo(d.right, _ground)
            ..lineTo(d.right + _u * 0.30, _ground + _u * 0.35)
            ..lineTo(d.left - _u * 0.20, _ground + _u * 0.35)
            ..close(),
          Paint()..color = _stWarm.withValues(alpha: 0.22 * door),
        );
      }
    }
    if (_hasWall && staging.cover == Cover.doorway) {
      final open = _doorOpen;
      if (open <= 0) return;
      final door = _recess;
      canvas.drawPath(
        Path()
          ..moveTo(door.left, _ground)
          ..lineTo(door.right, _ground)
          ..lineTo(door.right - _u * 0.05, _ground + _u * 0.40)
          ..lineTo(door.left - _u * 0.85 * open, _ground + _u * 0.40)
          ..close(),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              _stWarm.withValues(alpha: 0.42 * open),
              _stWarm.withValues(alpha: 0.0),
            ],
          ).createShader(
            Rect.fromLTRB(door.left - _u, _ground, door.right, _ground + _u * 0.4),
          ),
      );
    }
  }

  /// La facciata del bar: la vetrina accesa con le tende alla veneziana,
  /// la tenda a strisce, la porta, due finestre ai piani di sopra.
  void _cafe(Canvas canvas) {
    final window = _cafeWindow;
    final door = _cafeDoor;
    final top = _ground - _u * 2.30;
    final facade = Rect.fromLTRB(-_w, top, _hasWall ? _cornerX : _w * 2, _ground);
    canvas.drawRect(facade, Paint()..color = const Color(0xFF14141B));
    // Il cornicione, e i ricorsi dei piani.
    canvas.drawRect(
      Rect.fromLTRB(facade.left, top - _u * 0.05, facade.right + _u * 0.04, top + _u * 0.04),
      Paint()..color = const Color(0xFF1E1E27),
    );
    canvas.drawRect(
      Rect.fromLTRB(facade.left, _ground - _u * 1.72, facade.right, _ground - _u * 1.69),
      Paint()..color = const Color(0xFF1C1C25),
    );
    // Le finestre di sopra: una buia, una con la luce bassa.
    for (final (dx, lit) in [(-0.35, 0.0), (0.55, 0.22)]) {
      final upper = Rect.fromCenter(
        center: Offset(_victimX + _u * dx, _ground - _u * 1.98),
        width: _u * 0.26,
        height: _u * 0.40,
      );
      canvas.drawRect(upper, Paint()..color = const Color(0xFF08080B));
      if (lit > 0) {
        canvas.drawRect(upper, Paint()..color = _stWarm.withValues(alpha: lit));
      }
      final frame = Paint()
        ..color = const Color(0xFF26262F)
        ..strokeWidth = _u * 0.012
        ..style = PaintingStyle.stroke;
      canvas.drawRect(upper, frame);
      canvas.drawLine(upper.topCenter, upper.bottomCenter, frame);
    }

    // La vetrina: calda al centro, più scura verso i bordi.
    canvas.drawRect(
      window.inflate(_u * 0.035),
      Paint()..color = const Color(0xFF0B0B0F),
    );
    canvas.drawRect(
      window,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.1),
          radius: 0.9,
          colors: const [Color(0xFFFFE2A3), Color(0xFFF4B45E), Color(0xFFB8742E)],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(window),
    );
    // Dentro: il banco e una lampada che pende. Solo ombre.
    final inside = Paint()..color = const Color(0xFF6B4520).withValues(alpha: 0.55);
    canvas.drawRect(
      Rect.fromLTRB(window.left, window.bottom - _u * 0.30, window.right, window.bottom),
      inside,
    );
    canvas.drawLine(
      Offset(window.left + window.width * 0.72, window.top),
      Offset(window.left + window.width * 0.72, window.top + _u * 0.26),
      Paint()
        ..color = inside.color
        ..strokeWidth = _u * 0.010,
    );
    canvas.drawPath(
      Path()
        ..moveTo(window.left + window.width * 0.72 - _u * 0.07, window.top + _u * 0.33)
        ..lineTo(window.left + window.width * 0.72 + _u * 0.07, window.top + _u * 0.33)
        ..lineTo(window.left + window.width * 0.72 + _u * 0.03, window.top + _u * 0.26)
        ..lineTo(window.left + window.width * 0.72 - _u * 0.03, window.top + _u * 0.26)
        ..close(),
      inside,
    );
    // Le veneziane abbassate per un terzo.
    final slat = Paint()..color = const Color(0xFF5A3A18).withValues(alpha: 0.70);
    for (var y = window.top + _u * 0.025; y < window.top + window.height * 0.34; y += _u * 0.055) {
      canvas.drawRect(Rect.fromLTRB(window.left, y, window.right, y + _u * 0.026), slat);
    }
    // I montanti.
    final mullion = Paint()..color = const Color(0xFF0B0B0F);
    for (final f in [1 / 3, 2 / 3]) {
      final x = window.left + window.width * f;
      canvas.drawRect(
        Rect.fromLTRB(x - _u * 0.014, window.top, x + _u * 0.014, window.bottom),
        mullion,
      );
    }
    // Il bagliore della vetrina sul muro intorno.
    canvas.drawRect(
      window.inflate(_u * 0.12),
      Paint()
        ..color = _stWarm.withValues(alpha: 0.10)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, _u * 0.10),
    );
    // Lo zoccolo sotto la vetrina.
    canvas.drawRect(
      Rect.fromLTRB(window.left - _u * 0.035, window.bottom + _u * 0.035, window.right + _u * 0.035, _ground),
      Paint()..color = const Color(0xFF0E0E13),
    );

    // La tenda a strisce, con la frangia smerlata.
    final awning = Rect.fromLTRB(
      door.left - _u * 0.06,
      window.top - _u * 0.30,
      window.right + _u * 0.10,
      window.top - _u * 0.08,
    );
    final stripes = (awning.width / (_u * 0.11)).round();
    for (var i = 0; i < stripes; i++) {
      final x0 = awning.left + awning.width * i / stripes;
      final x1 = awning.left + awning.width * (i + 1) / stripes;
      canvas.drawPath(
        Path()
          ..moveTo(x0 + _u * 0.03, awning.top)
          ..lineTo(x1 + _u * 0.03, awning.top)
          ..lineTo(x1, awning.bottom)
          ..quadraticBezierTo((x0 + x1) / 2, awning.bottom + _u * 0.055, x0, awning.bottom)
          ..close(),
        Paint()..color = i.isEven ? const Color(0xFF5E1B22) : const Color(0xFF8A7A5C),
      );
    }
    canvas.drawRect(
      Rect.fromLTRB(awning.left, awning.top - _u * 0.02, awning.right + _u * 0.03, awning.top + _u * 0.01),
      Paint()..color = const Color(0xFF0B0B0F),
    );

    // La porta: vetro in alto, legno in basso. Quando si apre si vede il
    // bar acceso.
    final open = _cafeDoorOpen;
    canvas.drawRect(door.inflate(_u * 0.03), Paint()..color = const Color(0xFF0B0B0F));
    canvas.drawRect(
      door,
      Paint()..color = Color.lerp(const Color(0xFF3A2614), const Color(0xFFFFD592), open)!,
    );
    final leaf = Rect.fromLTRB(door.left, door.top, door.right - door.width * 0.82 * open, door.bottom);
    canvas.drawRect(leaf, Paint()..color = const Color(0xFF1C130B));
    final glass = Rect.fromLTRB(
      leaf.left + leaf.width * 0.16,
      leaf.top + _u * 0.08,
      leaf.right - leaf.width * 0.16,
      leaf.top + door.height * 0.55,
    );
    if (glass.width > 0) {
      canvas.drawRect(glass, Paint()..color = const Color(0xFFE8A955).withValues(alpha: 0.75));
    }
  }

  /// L'interno del portone: un androne acceso, la lampadina nuda, i primi
  /// gradini. Si vede solo quando il portone si apre.
  void _doorwayInside(Canvas canvas) {
    final door = _recess;
    canvas.drawRect(door, Paint()..color = const Color(0xFF060607));
    final open = _doorOpen;
    if (open <= 0) return;
    canvas.drawRect(
      door,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFFFE0A0).withValues(alpha: open),
            const Color(0xFFC98A3E).withValues(alpha: open),
          ],
        ).createShader(door),
    );
    final step = Paint()..color = const Color(0xFF8A5A26).withValues(alpha: 0.6 * open);
    for (var i = 0; i < 3; i++) {
      canvas.drawRect(
        Rect.fromLTRB(
          door.left + door.width * (0.45 + 0.12 * i),
          door.bottom - _u * (0.10 + 0.09 * i),
          door.right,
          door.bottom - _u * (0.08 + 0.09 * i),
        ),
        step,
      );
    }
    final bulb = Offset(door.center.dx, door.top + _u * 0.16);
    canvas.drawLine(
      Offset(bulb.dx, door.top),
      bulb,
      Paint()
        ..color = const Color(0xFF3A2614).withValues(alpha: open)
        ..strokeWidth = _u * 0.008,
    );
    canvas.drawCircle(
      bulb,
      _u * 0.14,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.45 * open)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, _u * 0.07),
    );
    canvas.drawCircle(bulb, _u * 0.025, Paint()..color = Colors.white.withValues(alpha: open));
  }

  /// Il fondo dell'androne buio: una porta più in là, appena accennata.
  void _recessInside(Canvas canvas) {
    final recess = _recess;
    canvas.drawRect(recess, Paint()..color = const Color(0xFF07070A));
    canvas.drawRect(
      Rect.fromLTRB(
        recess.left + recess.width * 0.22,
        recess.top + recess.height * 0.18,
        recess.right - recess.width * 0.22,
        recess.bottom,
      ),
      Paint()..color = const Color(0xFF0D0D12),
    );
  }

  /// Il nascondiglio, davanti al killer: lo copre finché non esce.
  void _cover(Canvas canvas) {
    switch (staging.cover) {
      case Cover.corner:
        break;
      case Cover.kiosk:
        _kiosk(canvas);
      case Cover.doorway:
        _doorwayFront(canvas);
      case Cover.shadow:
        _shadowFront(canvas);
    }
  }

  /// L'edicola chiusa: la saracinesca, i giornali appesi di lato sotto la
  /// lampadina, la pensilina a strisce, una pila di copie legate.
  void _kiosk(Canvas canvas) {
    final left = _cornerX - _u * 0.04;
    final top = _ground - _u * 1.16;
    final body = Rect.fromLTRB(left, top, _w * 2, _ground);
    canvas.drawRect(body, Paint()..color = const Color(0xFF15241D));
    // La saracinesca abbassata, a righe.
    final shutter = Rect.fromLTRB(left + _u * 0.40, top + _u * 0.14, _w * 2, _ground - _u * 0.12);
    canvas.drawRect(shutter, Paint()..color = const Color(0xFF1C2C24));
    final groove = Paint()
      ..color = const Color(0xFF0C140F)
      ..strokeWidth = _u * 0.010;
    for (var y = shutter.top + _u * 0.05; y < shutter.bottom; y += _u * 0.05) {
      canvas.drawLine(Offset(shutter.left, y), Offset(shutter.right, y), groove);
    }
    // Lo spigolo, e lo zoccolo.
    canvas.drawRect(
      Rect.fromLTRB(left, top, left + _u * 0.025, _ground),
      Paint()..color = const Color(0xFF2C4237),
    );
    canvas.drawRect(
      Rect.fromLTRB(left, _ground - _u * 0.10, _w * 2, _ground),
      Paint()..color = const Color(0xFF0A110D),
    );
    // I giornali e le riviste appesi alle mollette, illuminati dalla
    // lampadina: colori smorti, testate nere.
    final bulb = Offset(left + _u * 0.20, top + _u * 0.05);
    canvas.drawCircle(
      bulb.translate(0, _u * 0.25),
      _u * 0.36,
      Paint()
        ..color = _stWarm.withValues(alpha: 0.16)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, _u * 0.12),
    );
    final wire = Paint()
      ..color = const Color(0xFF0A0A0C)
      ..strokeWidth = _u * 0.006;
    const covers = [
      Color(0xFF9C4A3A),
      Color(0xFFC9B27A),
      Color(0xFF4F7A78),
      Color(0xFFB8B0A0),
      Color(0xFF8C6A3A),
      Color(0xFF7A3F55),
    ];
    for (var row = 0; row < 2; row++) {
      final y = top + _u * (0.22 + 0.30 * row);
      canvas.drawLine(Offset(left + _u * 0.04, y), Offset(left + _u * 0.38, y), wire);
      for (var i = 0; i < 3; i++) {
        final sheet = Rect.fromLTWH(
          left + _u * (0.05 + 0.11 * i),
          y + _u * 0.01,
          _u * 0.095,
          _u * 0.24,
        );
        final color = covers[(row * 3 + i) % covers.length];
        canvas.drawRect(sheet, Paint()..color = Color.lerp(color, Colors.black, 0.35)!);
        canvas.drawRect(
          Rect.fromLTWH(sheet.left + _u * 0.01, sheet.top + _u * 0.02, sheet.width - _u * 0.02, _u * 0.035),
          Paint()..color = const Color(0xFF15120D),
        );
        canvas.drawRect(
          Rect.fromLTWH(sheet.left + _u * 0.015, sheet.top + _u * 0.08, sheet.width - _u * 0.03, _u * 0.08),
          Paint()..color = Colors.black.withValues(alpha: 0.25),
        );
      }
    }
    // La pensilina: un tetto a falda che sporge, con la frangia a strisce.
    final eave = Path()
      ..moveTo(left - _u * 0.16, top + _u * 0.02)
      ..lineTo(left + _u * 0.10, top - _u * 0.16)
      ..lineTo(_w * 2, top - _u * 0.16)
      ..lineTo(_w * 2, top + _u * 0.02)
      ..close();
    canvas.drawPath(eave, Paint()..color = const Color(0xFF0F1A14));
    final fringe = top + _u * 0.02;
    final run = _w * 2 - (left - _u * 0.16);
    final stripes = (run / (_u * 0.10)).ceil();
    for (var i = 0; i < stripes; i++) {
      final x0 = left - _u * 0.16 + _u * 0.10 * i;
      canvas.drawPath(
        Path()
          ..moveTo(x0, fringe)
          ..lineTo(x0 + _u * 0.10, fringe)
          ..quadraticBezierTo(x0 + _u * 0.05, fringe + _u * 0.07, x0, fringe)
          ..close(),
        Paint()..color = i.isEven ? const Color(0xFF2E5A44) : const Color(0xFF9A8E6A),
      );
    }
    // La lampadina, accesa.
    canvas.drawLine(
      Offset(bulb.dx, fringe),
      bulb.translate(0, _u * 0.08),
      wire,
    );
    canvas.drawCircle(bulb.translate(0, _u * 0.10), _u * 0.022, Paint()..color = const Color(0xFFFFF1C8));
    canvas.drawCircle(
      bulb.translate(0, _u * 0.10),
      _u * 0.08,
      Paint()
        ..color = _stWarm.withValues(alpha: 0.55)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, _u * 0.05),
    );
    // La pila di copie legate con lo spago, davanti.
    final pile = Rect.fromLTWH(left - _u * 0.30, _ground - _u * 0.16, _u * 0.24, _u * 0.16);
    canvas.drawRect(pile, Paint()..color = _newsShade);
    for (var i = 1; i < 6; i++) {
      final y = pile.top + pile.height * i / 6;
      canvas.drawLine(
        Offset(pile.left, y),
        Offset(pile.right, y),
        Paint()
          ..color = const Color(0xFF5E5848)
          ..strokeWidth = 1,
      );
    }
    canvas.drawRect(
      Rect.fromLTRB(pile.left, pile.top - _u * 0.012, pile.right, pile.top + _u * 0.012),
      Paint()..color = _newsprint,
    );
    canvas.drawLine(
      Offset(pile.center.dx, pile.top),
      Offset(pile.center.dx, pile.bottom),
      Paint()
        ..color = const Color(0xFF2A2418)
        ..strokeWidth = _u * 0.010,
    );
  }

  /// Il muro del palazzo con un buco a forma di porta: dentro, quello che
  /// [_setBehind] ha già disegnato, e il killer.
  void _wallWithOpening(Canvas canvas, Rect opening, {bool arch = false}) {
    final face = Rect.fromLTRB(_cornerX, -_h, _w * 2, _ground);
    final hole = arch
        ? (Path()
            ..moveTo(opening.left, opening.bottom)
            ..lineTo(opening.left, opening.top + opening.width / 2)
            ..arcToPoint(
              Offset(opening.right, opening.top + opening.width / 2),
              radius: Radius.circular(opening.width / 2),
            )
            ..lineTo(opening.right, opening.bottom)
            ..close())
        : (Path()..addRect(opening));
    canvas.drawPath(
      Path.combine(PathOperation.difference, Path()..addRect(face), hole),
      Paint()..color = const Color(0xFF0A0A0D),
    );
    final mortar = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 1;
    for (var y = _ground - _u * 0.14; y > -_u; y -= _u * 0.14) {
      if (y > opening.top - _u * 0.02) {
        canvas.drawLine(Offset(_cornerX, y), Offset(opening.left, y), mortar);
        canvas.drawLine(Offset(opening.right, y), Offset(_w * 2, y), mortar);
      } else {
        canvas.drawLine(Offset(_cornerX, y), Offset(_w * 2, y), mortar);
      }
    }
    canvas.drawLine(
      Offset(_cornerX, -_h),
      Offset(_cornerX, _ground),
      Paint()
        ..color = const Color(0xFF2E2F38)
        ..strokeWidth = 2,
    );
    // La cornice di pietra.
    canvas.drawPath(
      hole,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _u * 0.035
        ..color = const Color(0xFF1B1B22),
    );
  }

  /// Il portone: il muro, l'anta che si apre verso l'interno, il
  /// sopraluce acceso.
  void _doorwayFront(Canvas canvas) {
    final door = _recess;
    _wallWithOpening(canvas, door);
    final open = _doorOpen;
    // L'anta è incernierata a destra: aprendosi si stringe verso il cardine.
    final leaf = Rect.fromLTRB(
      _mix(door.left, door.right - door.width * 0.16, open),
      door.top,
      door.right,
      door.bottom,
    );
    canvas.drawRect(leaf, Paint()..color = const Color(0xFF221810));
    final panel = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _u * 0.010
      ..color = const Color(0xFF3A2A1A);
    for (final (y0, y1) in [(0.07, 0.45), (0.53, 0.93)]) {
      final r = Rect.fromLTRB(
        leaf.left + leaf.width * 0.16,
        door.top + door.height * y0,
        leaf.right - leaf.width * 0.16,
        door.top + door.height * y1,
      );
      if (r.width > _u * 0.02) canvas.drawRect(r, panel);
    }
    if (open < 0.9) {
      canvas.drawCircle(
        Offset(leaf.left + leaf.width * 0.12, door.top + door.height * 0.52),
        _u * 0.015,
        Paint()..color = const Color(0xFFB08A4A),
      );
    }
    // Il sopraluce: una mezzaluna di vetro, sempre accesa.
    final transom = Rect.fromLTRB(door.left, door.top - _u * 0.19, door.right, door.top - _u * 0.03);
    canvas.drawRect(transom, Paint()..color = const Color(0xFF060607));
    canvas.drawRect(
      transom.deflate(_u * 0.02),
      Paint()..color = _stWarm.withValues(alpha: 0.35 + 0.45 * open),
    );
    final bars = Paint()
      ..color = const Color(0xFF0A0A0D)
      ..strokeWidth = _u * 0.012;
    for (var i = 1; i < 4; i++) {
      final x = transom.left + transom.width * i / 4;
      canvas.drawLine(Offset(x, transom.top), Offset(x, transom.bottom), bars);
    }
    // Il gradino di pietra.
    canvas.drawRect(
      Rect.fromLTRB(door.left - _u * 0.06, _ground - _u * 0.035, door.right + _u * 0.06, _ground),
      Paint()..color = const Color(0xFF24242C),
    );
  }

  /// L'androne buio: il killer c'è, ma il buio se lo mangia. Si vedono la
  /// brace della sigaretta e il riflesso sotto la tesa.
  void _shadowFront(Canvas canvas) {
    final recess = _recess;
    _wallWithOpening(canvas, recess, arch: true);
    final dark = Path()
      ..moveTo(recess.left, recess.bottom)
      ..lineTo(recess.left, recess.top + recess.width / 2)
      ..arcToPoint(
        Offset(recess.right, recess.top + recess.width / 2),
        radius: Radius.circular(recess.width / 2),
      )
      ..lineTo(recess.right, recess.bottom)
      ..close();
    canvas.drawPath(
      dark,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            const Color(0xFF07070A).withValues(alpha: 0.82),
            const Color(0xFF07070A).withValues(alpha: 0.96),
          ],
        ).createShader(recess),
    );
    // L'ombra dell'androne si allunga sul marciapiede: copre anche la lama
    // che spunta, finché lui non fa un passo fuori.
    final pool = Rect.fromLTRB(_cornerX - _u * 0.34, recess.top + _u * 0.30, _cornerX + _u * 0.002, _ground);
    canvas.drawRect(
      pool,
      Paint()
        ..shader = LinearGradient(
          colors: [
            const Color(0xFF07070A).withValues(alpha: 0.0),
            const Color(0xFF07070A).withValues(alpha: 0.80),
            const Color(0xFF07070A).withValues(alpha: 0.94),
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(pool),
    );
    final feet = _killerAt;
    if (feet == null) return;
    // Finché è dentro: la brace che si ravviva a ogni tirata, e il
    // riflesso degli occhi. Quando esce, la sigaretta vola via.
    final inside = feet.dx > recess.left + _u * 0.04 && t < 0.46;
    final h = _u * 1.08;
    final facing = _killerFacing.toDouble();
    final mouth = feet + Offset(facing * h * 0.11, -h * 0.935);
    if (inside) {
      final drag = pow(max(0.0, sin(t * 38)), 3).toDouble();
      canvas.drawCircle(
        mouth,
        _u * (0.13 + 0.07 * drag),
        Paint()
          ..color = const Color(0xFFFF7A3B).withValues(alpha: 0.22 + 0.30 * drag)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, _u * 0.07),
      );
      canvas.drawCircle(
        mouth.translate(facing * h * 0.06, h * 0.01),
        _u * (0.016 + 0.006 * drag),
        Paint()..color = Color.lerp(const Color(0xFFE0501E), const Color(0xFFFFD08A), drag)!,
      );
      canvas.drawCircle(
        feet + Offset(facing * h * 0.078, -h * 0.997),
        _u * 0.009,
        Paint()..color = const Color(0xFFFFF3C4).withValues(alpha: 0.85),
      );
    }
    _droppedCigarette(
      canvas,
      Offset(_coverPeek + facing * h * 0.15, _ground - h * 0.93),
      _span(t, 0.46, 0.53),
    );
  }

  // ------------------------------------------------------------------ vittima

  /// Il momento in cui la vittima smette di fare quello che faceva: al
  /// colpo, o prima, se si gira (o se la abbagliano i fari).
  double get _dropAt => act == DeathAct.car
      ? 0.46
      : staging.reaction == Reaction.turns
      ? _turnAt
      : _stStrike;

  /// Quando la vittima, nella regia in cui se ne accorge, si gira.
  static const _turnAt = 0.505;

  /// Verso dove guarda la vittima: si gira verso il killer, se la regia lo
  /// vuole.
  int _faced(int facing) =>
      staging.reaction == Reaction.turns && t >= _turnAt ? 1 : facing;

  /// La posa di quello che fa la vittima mentre aspetta. [waiting] è la
  /// finestra di attesa della coreografia (la sigaretta del classico).
  _Pose _businessPose({required bool waiting, double stride = 0, double walk = 0}) {
    final after = t >= _dropAt;
    switch (staging.business) {
      case Business.smoke:
        return _idle;
      case Business.newspaper:
        final hold = waiting && !after ? _smooth(_span(t, 0.37, 0.41)) : 0.0;
        return (
          arm: _mix(0.08, 0.95, hold),
          elbow: _mix(0.20, 1.30, hold),
          backArm: _mix(-0.10, 0.80, hold),
          backElbow: _mix(0.20, 1.45, hold),
          lean: 0.05 * hold,
          crouch: 0.0,
        );
      case Business.umbrella:
        if (after) return _idle;
        // Il braccio dell'ombrello non dondola col passo.
        final swing = stride * sin(walk) * 0.45;
        return (
          arm: 0.55 - swing,
          elbow: 1.72,
          backArm: -0.10,
          backElbow: 0.20,
          lean: 0.0,
          crouch: 0.0,
        );
      case Business.shoelace:
        final bend = waiting
            ? _smooth(_span(t, 0.37, 0.41)) - _smooth(_span(t, 0.462, 0.50))
            : 0.0;
        return (
          arm: _mix(0.08, 0.30, bend),
          elbow: _mix(0.20, 0.05, bend),
          backArm: _mix(-0.10, 0.45, bend),
          backElbow: _mix(0.20, 0.10, bend),
          lean: 1.05 * bend,
          crouch: 0.95 * bend,
        );
    }
  }

  /// La posa di chi si è girato e ha visto il killer: le mani in alto.
  _Pose _handsUp(_Pose from) {
    final up = _smooth(_span(t, _turnAt, _turnAt + 0.02));
    final shiver = sin(t * 420) * 0.04 * up;
    return (
      arm: _mix(from.arm, 2.25, up) + shiver,
      elbow: _mix(from.elbow, 0.62, up),
      backArm: _mix(from.backArm, 2.05, up) - shiver,
      backElbow: _mix(from.backElbow, 0.80, up),
      lean: _mix(from.lean, -0.12, up),
      crouch: _mix(from.crouch, 0.10, up),
    );
  }

  /// La vittima in piedi con la regia nuova: quello che fa mentre aspetta,
  /// o le mani in alto. Falso se la regia è quella classica (la sigaretta).
  bool _busyVictim(
    Canvas canvas, {
    required double x,
    required int facing,
    required double walk,
    required double stride,
    required double lean,
    required bool waiting,
    required _Prop prop,
  }) {
    final turns = staging.reaction == Reaction.turns && t >= _turnAt;
    if (prop != _Prop.none) return false;
    if (staging.business == Business.smoke && !turns) return false;
    var pose = _businessPose(waiting: waiting, stride: stride, walk: walk);
    if (turns) pose = _handsUp(pose);
    final feet = Offset(x, _ground);
    final faced = _faced(facing);
    _person(
      canvas,
      feet: feet,
      facing: faced,
      walk: walk,
      stride: stride,
      lean: lean + pose.lean,
      crouch: pose.crouch,
      arm: pose.arm,
      elbow: pose.elbow,
      backArm: pose.backArm,
      backElbow: pose.backElbow,
      hat: victimHat,
      smoking: staging.business == Business.smoke && waiting && t > 0.395,
    );
    _businessProp(canvas, feet: feet, facing: faced, pose: pose, lean: lean + pose.lean, waiting: waiting);
    if (turns) {
      _exclaim(
        canvas,
        Offset(x + faced * _u * 0.05, _ground - _u * 1.42),
        _span(t, _turnAt, _turnAt + 0.05),
      );
    }
    return true;
  }

  /// Il giornale o l'ombrello in mano alla vittima.
  void _businessProp(
    Canvas canvas, {
    required Offset feet,
    required int facing,
    required _Pose pose,
    required double lean,
    required bool waiting,
  }) {
    if (t >= _dropAt) return;
    switch (staging.business) {
      case Business.newspaper:
        final open = waiting ? _smooth(_span(t, 0.37, 0.41)) : 0.0;
        if (open <= 0) return;
        final (hand, _) = _handOf(
          feet: feet,
          facing: facing,
          lean: lean,
          crouch: pose.crouch,
          arm: pose.arm,
          elbow: pose.elbow,
        );
        _newspaper(canvas, hand, facing, open);
      case Business.umbrella:
        final (hand, _) = _handOf(
          feet: feet,
          facing: facing,
          lean: lean,
          crouch: pose.crouch,
          arm: pose.arm,
          elbow: pose.elbow,
        );
        final open = staging.arrival == Arrival.door
            ? Curves.easeOutBack.transform(_span(t, 0.07, 0.12))
            : 1.0;
        _umbrella(canvas, hand, facing, open: open);
      case Business.smoke || Business.shoelace:
        break;
    }
  }

  /// Il giornale aperto davanti alla faccia, visto di sbieco: la prima
  /// pagina verso di noi, la testata, le colonne, una foto.
  void _newspaper(Canvas canvas, Offset hand, int facing, double open) {
    canvas.save();
    canvas.translate(hand.dx, hand.dy);
    canvas.scale(facing.toDouble(), 1);
    canvas.rotate(-0.06 + 0.02 * sin(t * 30));
    final width = _u * 0.27 * (0.30 + 0.70 * open);
    final height = _u * 0.34;
    final sheet = Path()
      ..moveTo(-width * 0.62, -height * 0.86)
      ..lineTo(width * 0.38, -height * 0.80)
      ..lineTo(width * 0.30, height * 0.16)
      ..lineTo(-width * 0.66, height * 0.10)
      ..close();
    canvas.drawPath(sheet, Paint()..color = _newsShade);
    canvas.save();
    canvas.clipPath(sheet);
    canvas.drawRect(
      Rect.fromLTRB(-width, -height, width * 0.05, height),
      Paint()..color = _newsprint,
    );
    final ink = Paint()..color = _newsInk;
    // La testata, e il titolo grosso.
    canvas.drawRect(Rect.fromLTRB(-width * 0.58, -height * 0.78, width * 0.28, -height * 0.70), ink);
    canvas.drawRect(Rect.fromLTRB(-width * 0.58, -height * 0.64, width * 0.20, -height * 0.58), ink);
    // La foto.
    canvas.drawRect(
      Rect.fromLTRB(-width * 0.56, -height * 0.50, -width * 0.12, -height * 0.24),
      Paint()..color = const Color(0xFF5E5848),
    );
    // Le colonne.
    final line = Paint()
      ..color = _newsInk.withValues(alpha: 0.55)
      ..strokeWidth = max(1.0, _u * 0.006);
    for (var y = -height * 0.48; y < height * 0.08; y += height * 0.06) {
      canvas.drawLine(Offset(-width * 0.06, y), Offset(width * 0.24, y), line);
      if (y > -height * 0.20) {
        canvas.drawLine(Offset(-width * 0.60, y), Offset(-width * 0.14, y), line);
      }
    }
    canvas.restore();
    // La piega in mezzo.
    canvas.drawLine(
      Offset(-width * 0.12, -height * 0.83),
      Offset(-width * 0.18, height * 0.13),
      Paint()
        ..color = _newsShade
        ..strokeWidth = max(1.0, _u * 0.008),
    );
    canvas.restore();
  }

  /// L'ombrello aperto, col manico nella mano della vittima.
  void _umbrella(Canvas canvas, Offset hand, int facing, {double open = 1, double spin = 0, bool rain = true}) {
    final ink = Paint()..color = _stInk;
    canvas.save();
    canvas.translate(hand.dx, hand.dy);
    canvas.rotate(spin);
    canvas.scale(facing.toDouble(), 1);
    // Il manico a uncino, l'asta, la punta.
    final top = Offset(-_u * 0.14, -_u * 0.56);
    canvas.drawPath(
      Path()
        ..moveTo(_u * 0.0, _u * 0.02)
        ..quadraticBezierTo(_u * 0.0, _u * 0.09, _u * 0.05, _u * 0.08),
      Paint()
        ..color = _stInk
        ..style = PaintingStyle.stroke
        ..strokeWidth = _u * 0.022
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset.zero,
      top,
      Paint()
        ..color = _stInk
        ..strokeWidth = _u * 0.016,
    );
    canvas.drawLine(
      top,
      top + const Offset(-0.25, -1) * (_u * 0.07),
      Paint()
        ..color = _stInk
        ..strokeWidth = _u * 0.014
        ..strokeCap = StrokeCap.round,
    );
    // La cupola: si apre a scatto, e ha le stecche sotto il bordo smerlato.
    canvas.save();
    canvas.translate(top.dx, top.dy);
    canvas.rotate(-0.25);
    final span = _u * 0.50 * max(0.18, open);
    final rise = _u * (0.24 - 0.06 * open);
    final rim = _u * 0.05 * open;
    final dome = Path()
      ..moveTo(-span, rise)
      ..quadraticBezierTo(-span * 0.95, -_u * 0.02, 0, -_u * 0.02)
      ..quadraticBezierTo(span * 0.95, -_u * 0.02, span, rise);
    const lobes = 4;
    for (var i = lobes; i > 0; i--) {
      final x0 = span * (2 * i / lobes - 1);
      final x1 = span * (2 * (i - 1) / lobes - 1);
      dome.quadraticBezierTo((x0 + x1) / 2, rise - rim, x1, rise);
    }
    dome.close();
    canvas.drawPath(
      dome.shift(Offset(_u * 0.012, -_u * 0.01)),
      Paint()..color = _stRim,
    );
    canvas.drawPath(dome, ink);
    canvas.restore();
    canvas.restore();
    if (!rain || open < 1) return;
    // La pioggia che gocciola dalle punte.
    final drip = Paint()
      ..color = const Color(0xFFB8C4D0).withValues(alpha: 0.55)
      ..strokeWidth = _u * 0.008
      ..strokeCap = StrokeCap.round;
    for (final side in [-1.0, 1.0]) {
      final tip = hand +
          _turn(
            Offset(-_u * 0.14 * facing, -_u * 0.56) +
                _turn(Offset(side * _u * 0.50 * facing, _u * 0.22), -0.25 * facing),
            0,
          );
      for (var k = 0; k < 2; k++) {
        final fall = ((t * 9 + k * 0.5 + (side > 0 ? 0.25 : 0)) % 1);
        final at = tip.translate(0, _u * 0.6 * fall);
        canvas.drawLine(at, at.translate(0, _u * 0.04), drip);
      }
    }
  }

  /// Quello che resta della vittima dopo il colpo: i fogli del giornale che
  /// volano e ricadono sull'asfalto, l'ombrello che vola via e atterra
  /// capovolto.
  ///
  /// Si disegna due volte: con [landed] prima della coreografia, quello che
  /// è già a terra (così il corpo ci cade sopra); senza, dopo, quello che
  /// vola ancora.
  void _businessAftermath(Canvas canvas, {required bool landed}) {
    if (staging.business == Business.smoke || staging.business == Business.shoelace) return;
    final from = _dropAt;
    if (t < from) return;
    final drop = Offset(_victimX + _u * 0.22, _ground - _u * 0.86);
    switch (staging.business) {
      case Business.newspaper:
        // I fogli: ognuno se ne va per conto suo, ondeggiando, e si posa.
        for (var i = 0; i < 4; i++) {
          final life = _span(t, from + 0.004 * i, from + 0.20 + 0.03 * i);
          if ((life >= 1) != landed) continue;
          final dx = _u * (-0.95 + 0.45 * i + (act == DeathAct.car ? 0.5 : 0));
          final rest = Offset(drop.dx + dx, _ground + _u * (0.02 + 0.025 * (i % 3)));
          final lift = _u * (0.35 + 0.12 * (i % 2)) * sin(pi * min(1, life * 1.4)) * (1 - life);
          final at = Offset(
            _mix(drop.dx, rest.dx, Curves.easeOut.transform(life)) + sin(life * 11 + i) * _u * 0.08 * (1 - life),
            _mix(drop.dy, rest.dy, Curves.easeIn.transform(life)) - lift,
          );
          canvas.save();
          canvas.translate(at.dx, at.dy);
          canvas.rotate(life < 1 ? sin(life * 9 + i * 1.3) * 1.2 : (i - 1.5) * 0.12);
          canvas.scale(1, life < 1 ? 0.55 + 0.45 * cos(life * 13 + i).abs() : 0.22);
          final page = Rect.fromCenter(center: Offset.zero, width: _u * 0.20, height: _u * 0.15);
          canvas.drawRect(page, Paint()..color = i.isEven ? _newsprint : _newsShade);
          final line = Paint()
            ..color = _newsInk.withValues(alpha: 0.5)
            ..strokeWidth = max(1.0, _u * 0.006);
          for (var k = 0; k < 4; k++) {
            final y = page.top + page.height * (0.22 + 0.18 * k);
            canvas.drawLine(Offset(page.left + _u * 0.02, y), Offset(page.right - _u * 0.02, y), line);
          }
          canvas.restore();
        }
      case Business.umbrella:
        final life = _span(t, from, from + 0.12);
        if ((life >= 1) != landed) return;
        // Atterra capovolto, sulla cupola, dietro ai piedi di chi cade: il
        // manico resta in aria.
        final land = Offset(_victimX + _u * (act == DeathAct.car ? 0.9 : 0.30), _ground - _u * 0.60);
        final at = Offset(
          _mix(drop.dx - _u * 0.1, land.dx, Curves.easeOut.transform(life)),
          _mix(drop.dy - _u * 0.2, land.dy, Curves.easeIn.transform(life)) -
              _u * 0.9 * sin(pi * life) * (1 - life * 0.4),
        );
        final rock = life >= 1 ? 0.18 * sin(t * 60) * (1 - _span(t, from + 0.12, from + 0.26)) : 0.0;
        _umbrella(
          canvas,
          at,
          -1,
          spin: life < 1 ? -3.08 * pi * Curves.easeOut.transform(life) : 0.92 * pi + rock,
          rain: false,
        );
      case Business.smoke || Business.shoelace:
        break;
    }
  }
}
