import 'dart:math';
import 'dart:ui';

/// Le armi dei filmati della notte, disegnate a mano e in scala vera.
///
/// Ogni arma è un modello in metri, con l'origine al centro del pugno che la
/// tiene: x va verso la bocca della canna (o la punta), y verso il basso. Il
/// pittore la porta in scena con [NoirWeapons.held], dato il punto della mano,
/// la direzione dell'avambraccio e quanti pixel fa un metro; per le figure dei
/// filmati il metro si ricava dalla loro altezza con [NoirWeapons.perMetre].
///
/// La forma è una sola, e deve leggersi già da sagoma nera; i tre [WeaponLook]
/// cambiano soltanto come la si colora.
enum NoirWeapon {
  /// Revolver .38 a canna da quattro pollici, quello delle questure e dei
  /// picciotti (sul tipo del Colt Official Police).
  revolver,

  /// Il "naso corto" da due pollici, il revolver da tasca dei detective (sul
  /// tipo del Colt Detective Special).
  snubNose,

  /// La Beretta del 1934, la pistola italiana dell'epoca.
  beretta,

  /// Il Thompson col caricatore a tamburo, l'impugnatura davanti, il calcio e
  /// le alette sulla canna.
  tommy,

  /// La custodia da violino: dentro ci sta il Thompson.
  violinCase,

  /// La lupara: doppietta a cani esterni, canne e calcio segati.
  lupara,

  /// Lo stiletto: lama sottile e guardia a croce.
  stiletto,

  /// La mazza da baseball, di frassino.
  bat,

  /// Il fucile del Cecchino: otturatore girevole e cannocchiale a tubo lungo e
  /// sottile, come quelli della guerra.
  sniper,

  /// Il fucile subacqueo a elastici, con la fiocina.
  speargun,

  /// La bomba a mano "ananas".
  grenade,

  /// Il forcone della folla.
  pitchfork,

  /// Una delle due maniglie di legno della garrota (il filo lo tira
  /// [NoirWeapons.garrote]).
  garroteToggle,
}

/// I tre modi di colorare la stessa sagoma.
enum WeaponLook {
  /// Nero pieno come le figure, con il filo di luce calda del lampione.
  inked,

  /// La sagoma nera con pochi dettagli: acciaio brunito, ottone, venature.
  detailed,

  /// Da romanzo a fumetti: contorno spesso, ombre nette, un solo colore.
  graphic,
}

enum _Mat { steel, bright, wood, ash, brass, leather, wire, rubber }

enum _Line { groove, grain, shine, brass }

class _Part {
  final Path path;
  final _Mat mat;

  const _Part(this.path, this.mat);
}

class _Detail {
  final Path path;
  final _Line kind;

  /// Lo spessore della linea in metri; 0 per una forma piena.
  final double width;

  /// Dove resta confinato il dettaglio (le venature dentro il calcio).
  final Path? clip;

  const _Detail(this.path, this.kind, {this.width = 0, this.clip});
}

class _Model {
  /// Le parti, dipinte in quest'ordine.
  final List<_Part> parts;

  /// I vuoti che si vedono attraverso: il ponticello, le feritoie.
  final List<Path> holes;

  /// Le parti che stanno dentro i vuoti (i grilletti).
  final List<_Part> after;
  final List<_Detail> details;

  /// La bocca della canna, o la punta.
  final Offset muzzle;

  /// Dove va l'altra mano, per le armi a due mani.
  final Offset? support;

  /// La parte che il pugno nasconde.
  final Path? grip;

  _Model(
    this.parts, {
    this.holes = const [],
    this.after = const [],
    this.details = const [],
    required this.muzzle,
    this.support,
    this.grip,
  });

  late final Path silhouette = () {
    var shape = Path();
    for (final part in parts) {
      shape = Path.combine(PathOperation.union, shape, part.path);
    }
    for (final hole in holes) {
      shape = Path.combine(PathOperation.difference, shape, hole);
    }
    for (final part in after) {
      shape = Path.combine(PathOperation.union, shape, part.path);
    }
    return shape;
  }();

  late final Rect bounds = silhouette.getBounds();

  /// Lo stesso modello, spostato di [by]: si disegna l'arma dove viene
  /// comodo e poi la si mette nel pugno.
  _Model shift(Offset by) => _Model(
    [for (final p in parts) _Part(p.path.shift(by), p.mat)],
    holes: [for (final h in holes) h.shift(by)],
    after: [for (final p in after) _Part(p.path.shift(by), p.mat)],
    details: [
      for (final d in details)
        _Detail(d.path.shift(by), d.kind, width: d.width, clip: d.clip?.shift(by)),
    ],
    muzzle: muzzle + by,
    support: support == null ? null : support! + by,
    grip: grip?.shift(by),
  );
}

/// I colori di una materia: il corpo e il bordo che prende luce.
typedef _Tone = ({Color base, Color lit});

class NoirWeapons {
  final WeaponLook look;

  /// Il nero delle figure.
  final Color ink;

  /// Il filo di luce del lampione.
  final Color rim;

  const NoirWeapons(
    this.look, {
    this.ink = const Color(0xFF050506),
    this.rim = const Color(0xFF8A6D3E),
  });

  /// Da dove arriva la luce, sullo schermo: il lampione è in alto a sinistra,
  /// come per il bordo caldo delle figure.
  static const _light = Offset(-0.85, -0.53);

  /// Il raggio del pugno delle figure dei filmati, in metri.
  static const fistRadius = 0.0565;

  /// Quanti pixel fa un metro per una figura dei filmati di unità [h]: dai
  /// piedi alla cima della testa ci sono 1,071 [h], e un uomo è alto 1,78 m.
  static double perMetre(double h) => h * 1.071 / 1.78;

  /// Quanto è lunga l'arma, in metri.
  static double lengthOf(NoirWeapon weapon) => _model(weapon).bounds.width;

  /// Quanto è alta l'arma, in metri.
  static double heightOf(NoirWeapon weapon) => _model(weapon).bounds.height;

  /// Il riquadro dell'arma, in metri, rispetto al centro del pugno.
  static Rect boundsOf(NoirWeapon weapon) => _model(weapon).bounds;

  /// La bocca della canna (o la punta) di [weapon] tenuta in [hand] lungo
  /// [along], in coordinate di schermo. L'arma si suppone dritta, col calcio
  /// in giù, anche quando la figura è specchiata.
  static Offset muzzleOf(
    NoirWeapon weapon,
    Offset hand,
    Offset along,
    double perMetre,
  ) => _onScreen(_model(weapon).muzzle, hand, along, perMetre);

  /// Dove va l'altra mano sulle armi a due mani; per le altre, la mano stessa.
  static Offset supportOf(
    NoirWeapon weapon,
    Offset hand,
    Offset along,
    double perMetre,
  ) {
    final at = _model(weapon).support;
    return at == null ? hand : _onScreen(at, hand, along, perMetre);
  }

  static Offset _onScreen(Offset local, Offset hand, Offset along, double perMetre) {
    final a = along / max(along.distance, 1e-9);
    var across = Offset(-a.dy, a.dx);
    if (across.dy < 0) across = -across;
    return hand + a * (local.dx * perMetre) + across * (local.dy * perMetre);
  }

  /// Disegna [weapon] nel pugno che sta in [hand], puntata lungo [along].
  /// [mirror] la ribalta sotto sopra (per chi la disegna già specchiata).
  void held(
    Canvas canvas,
    NoirWeapon weapon,
    Offset hand,
    Offset along,
    double perMetre, {
    bool mirror = false,
    bool fist = true,
  }) {
    canvas.save();
    canvas.translate(hand.dx, hand.dy);
    canvas.rotate(atan2(along.dy, along.dx));
    canvas.scale(perMetre, mirror ? -perMetre : perMetre);
    _paint(canvas, _model(weapon), fist: fist);
    canvas.restore();
  }

  /// L'arma da sola, dentro [box], inclinata di [tilt]: per i gesti del
  /// tavolo e i cataloghi.
  void icon(Canvas canvas, NoirWeapon weapon, Rect box, {double tilt = 0}) {
    final model = _model(weapon);
    final b = model.bounds;
    final c = cos(tilt).abs(), s = sin(tilt).abs();
    final w = b.width * c + b.height * s;
    final h = b.width * s + b.height * c;
    final scale = min(box.width / w, box.height / h);
    canvas.save();
    canvas.translate(box.center.dx, box.center.dy);
    canvas.rotate(tilt);
    canvas.scale(scale);
    canvas.translate(-b.center.dx, -b.center.dy);
    _paint(canvas, model, fist: false);
    canvas.restore();
  }

  /// La garrota: il filo da [a] a [b] (i due pugni), con la pancia [sag] in
  /// metri, e le due maniglie di legno strette nei pugni.
  void garrote(
    Canvas canvas,
    Offset a,
    Offset b,
    double perMetre, {
    double sag = 0,
  }) {
    final span = b - a;
    final d = span / max(span.distance, 1e-9);
    final side = Offset(-d.dy, d.dx);
    final belly = (a + b) / 2 + (side.dy < 0 ? -side : side) * (sag * perMetre);
    final width = max(0.0028 * perMetre, 1.0);
    final wire = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..color = switch (look) {
        WeaponLook.inked => rim,
        WeaponLook.detailed => const Color(0xFFC4CAD1),
        WeaponLook.graphic => const Color(0xFFF3E9D2),
      };
    final path = Path()
      ..moveTo(a.dx, a.dy)
      ..quadraticBezierTo(belly.dx, belly.dy, b.dx, b.dy);
    if (look == WeaponLook.graphic) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width + max(0.006 * perMetre, 2.0)
          ..strokeCap = StrokeCap.round
          ..color = ink,
      );
    }
    canvas.drawPath(path, wire);
    // Le maniglie stanno di traverso al filo, nel pugno.
    for (final end in [a, b]) {
      held(canvas, NoirWeapon.garroteToggle, end, side, perMetre, fist: false);
    }
  }

  // ------------------------------------------------------------- pittura

  void _paint(Canvas canvas, _Model model, {required bool fist}) {
    final m = canvas.getTransform();
    final a = m[0], b = m[1], c = m[4], d = m[5];
    final det = a * d - b * c;
    if (det.abs() < 1e-12) return;
    final px = sqrt(det.abs());

    /// Un passo verso il lampione, in metri del modello: [metres], ma fra
    /// [minPx] e [maxPx] pixel sullo schermo (da vicino il filo di luce non
    /// deve diventare un'ombra staccata).
    Offset toward(double metres, double minPx, double maxPx) {
      var v = Offset(
        (d * _light.dx - c * _light.dy) / det,
        (-b * _light.dx + a * _light.dy) / det,
      );
      v = v / v.distance;
      return v * ((metres * px).clamp(minPx, maxPx) / px);
    }

    double line(double metres, double minPx, [double maxPx = 1e9]) =>
        (metres * px).clamp(minPx, maxPx) / px;

    final shape = model.silhouette;
    switch (look) {
      case WeaponLook.inked:
        canvas.drawPath(shape.shift(toward(0.0070, 1.3, 3.2)), Paint()..color = rim);
        canvas.drawPath(shape, Paint()..color = ink);

      case WeaponLook.detailed:
        canvas.drawPath(shape.shift(toward(0.0070, 1.3, 3.2)), Paint()..color = rim);
        canvas.save();
        canvas.clipPath(shape);
        canvas.drawPath(shape, Paint()..color = ink);
        final lit = toward(0.0032, 0.8, 2.2);
        for (final part in [...model.parts, ...model.after]) {
          final tone = _detailed[part.mat]!;
          canvas.save();
          canvas.clipPath(part.path);
          canvas.drawPath(part.path, Paint()..color = tone.lit);
          canvas.drawPath(part.path.shift(-lit), Paint()..color = tone.base);
          canvas.restore();
        }
        _details(canvas, model, line);
        canvas.restore();
        canvas.drawPath(
          shape,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = line(0.0015, 0.6, 1.4)
            ..color = ink.withValues(alpha: 0.85),
        );
        if (fist) _fist(canvas, model);

      case WeaponLook.graphic:
        final cel = toward(0.0070, 1.4, 3.6);
        final outline = line(0.0105, 1.7, 4.4);
        // Il contorno sta tutto fuori dalla sagoma: le parti sottili (la
        // fiocina, il filo) restano del loro colore e non diventano nere.
        canvas.drawPath(
          shape,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = outline * 2
            ..strokeJoin = StrokeJoin.round
            ..color = ink,
        );
        canvas.save();
        canvas.clipPath(shape);
        final inner = outline * 0.42;
        for (final part in [...model.parts, ...model.after]) {
          final tone = _graphic[part.mat]!;
          canvas.save();
          canvas.clipPath(part.path);
          canvas.drawPath(part.path, Paint()..color = tone.lit);
          canvas.drawPath(part.path.shift(-cel), Paint()..color = tone.base);
          canvas.restore();
          if (part.path.getBounds().shortestSide > inner * 4) {
            canvas.drawPath(
              part.path,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = inner
                ..strokeJoin = StrokeJoin.round
                ..color = ink,
            );
          }
        }
        _details(canvas, model, line);
        canvas.restore();
        if (fist) _fist(canvas, model);
    }
  }

  void _details(
    Canvas canvas,
    _Model model,
    double Function(double metres, double minPx, [double maxPx]) line,
  ) {
    final graphic = look == WeaponLook.graphic;
    for (final detail in model.details) {
      final color = switch (detail.kind) {
        _Line.groove => graphic ? ink : const Color(0x99000000),
        _Line.grain => graphic ? ink.withValues(alpha: 0.55) : const Color(0x55000000),
        _Line.shine => graphic ? const Color(0xFFF3E9D2) : const Color(0xB0FFF1D8),
        _Line.brass => graphic ? const Color(0xFFF3E9D2) : const Color(0xFFC9A04A),
      };
      final paint = Paint()..color = color;
      if (detail.width > 0) {
        paint
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = line(
            detail.width * (graphic && detail.kind == _Line.groove ? 1.4 : 1),
            graphic ? 0.9 : 0.6,
          );
      }
      if (detail.clip != null) {
        canvas.save();
        canvas.clipPath(detail.clip!);
      }
      canvas.drawPath(detail.path, paint);
      if (detail.clip != null) canvas.restore();
    }
  }

  /// Le dita sopra l'impugnatura: senza, l'arma sembrerebbe davanti alla mano.
  void _fist(Canvas canvas, _Model model) {
    final grip = model.grip;
    if (grip == null) return;
    canvas.save();
    canvas.clipPath(grip);
    canvas.drawCircle(Offset.zero, fistRadius, Paint()..color = ink);
    canvas.restore();
  }

  static const Map<_Mat, _Tone> _detailed = {
    _Mat.steel: (base: Color(0xFF1B1E23), lit: Color(0xFF6A7480)),
    _Mat.bright: (base: Color(0xFF79828B), lit: Color(0xFFE4E9EE)),
    _Mat.wood: (base: Color(0xFF3A2114), lit: Color(0xFF8A552E)),
    _Mat.ash: (base: Color(0xFF5A4430), lit: Color(0xFFB8925F)),
    _Mat.brass: (base: Color(0xFF7A5C22), lit: Color(0xFFE6C068)),
    _Mat.leather: (base: Color(0xFF16100D), lit: Color(0xFF5E4535)),
    _Mat.wire: (base: Color(0xFF7D868F), lit: Color(0xFFD5DAE0)),
    _Mat.rubber: (base: Color(0xFF15110F), lit: Color(0xFF4A3C33)),
  };

  /// Il fumetto: grigi d'acciaio, la carta per le parti chiare, e un rosso
  /// solo (quello della cravatta del killer) per il legno.
  static const Map<_Mat, _Tone> _graphic = {
    _Mat.steel: (base: Color(0xFF24282E), lit: Color(0xFF7C8692)),
    _Mat.bright: (base: Color(0xFFA9B2BA), lit: Color(0xFFF3F5F7)),
    _Mat.wood: (base: Color(0xFF7A141C), lit: Color(0xFFD0313B)),
    _Mat.ash: (base: Color(0xFFB59C78), lit: Color(0xFFF3E9D2)),
    _Mat.brass: (base: Color(0xFFB59C78), lit: Color(0xFFF3E9D2)),
    _Mat.leather: (base: Color(0xFF1C1A1A), lit: Color(0xFF55504D)),
    _Mat.wire: (base: Color(0xFFA9B2BA), lit: Color(0xFFF3F5F7)),
    _Mat.rubber: (base: Color(0xFF7A141C), lit: Color(0xFFD0313B)),
  };

  // ------------------------------------------------------------- modelli

  static final Map<NoirWeapon, _Model> _models = {};

  static _Model _model(NoirWeapon weapon) => _models.putIfAbsent(
    weapon,
    () => switch (weapon) {
      NoirWeapon.revolver => _revolver(0.107, roundButt: false),
      NoirWeapon.snubNose => _revolver(0.054, roundButt: true),
      NoirWeapon.beretta => _beretta(),
      NoirWeapon.tommy => _tommy(),
      NoirWeapon.violinCase => _violinCase(),
      NoirWeapon.lupara => _lupara(),
      NoirWeapon.stiletto => _stiletto(),
      NoirWeapon.bat => _bat(),
      NoirWeapon.sniper => _sniper(),
      NoirWeapon.speargun => _speargun(),
      NoirWeapon.grenade => _grenade(),
      NoirWeapon.pitchfork => _pitchfork(),
      NoirWeapon.garroteToggle => _toggle(),
    },
  );
}

// --------------------------------------------------------------- geometria

Offset _o(double x, double y) => Offset(x, y);

Path _poly(List<Offset> points) => Path()..addPolygon(points, true);

Path _box(double l, double t, double r, double b, [double radius = 0]) =>
    Path()..addRRect(RRect.fromLTRBR(l, t, r, b, Radius.circular(radius)));

Path _disc(Offset c, double r) => Path()..addOval(Rect.fromCircle(center: c, radius: r));

Path _ellipse(Offset c, double rx, double ry) =>
    Path()..addOval(Rect.fromCenter(center: c, width: rx * 2, height: ry * 2));

Path _seg(Offset a, Offset b) => Path()
  ..moveTo(a.dx, a.dy)
  ..lineTo(b.dx, b.dy);

/// Una forma chiusa e morbida che passa vicino ai [points].
Path _smooth(List<Offset> points) {
  final n = points.length;
  Offset mid(int i) => (points[i % n] + points[(i + 1) % n]) / 2;
  final path = Path()..moveTo(mid(0).dx, mid(0).dy);
  for (var i = 1; i <= n; i++) {
    final p = points[i % n];
    final m = mid(i);
    path.quadraticBezierTo(p.dx, p.dy, m.dx, m.dy);
  }
  return path..close();
}

/// Un solido di rotazione visto di lato: [profile] dà, da sinistra a destra,
/// la x e la mezza altezza.
Path _lathe(List<Offset> profile, {double cy = 0}) => _smooth([
  for (final p in profile) _o(p.dx, cy - p.dy),
  for (final p in profile.reversed) _o(p.dx, cy + p.dy),
]);

/// Il ponticello: un anello sotto il castello, col vuoto per il dito.
(Path, Path) _guard(Rect outer, double wall, {double top = 0}) {
  final ring = Path()
    ..addRRect(RRect.fromRectAndRadius(outer, Radius.circular(outer.height * 0.55)));
  final hole = Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        outer.deflate(wall),
        Radius.circular(max(0.001, outer.height * 0.55 - wall)),
      ),
    );
  // Sopra, il vuoto lo chiude il castello.
  final below = Path()..addRect(Rect.fromLTRB(outer.left - 1, top, outer.right + 1, outer.bottom + 1));
  return (ring, Path.combine(PathOperation.intersect, hole, below));
}

/// Il grilletto: una virgola dentro il ponticello.
Path _trigger(Offset top, double length) => Path()
  ..moveTo(top.dx - length * 0.18, top.dy)
  ..quadraticBezierTo(top.dx + length * 0.30, top.dy + length * 0.45, top.dx + length * 0.05, top.dy + length)
  ..lineTo(top.dx - length * 0.12, top.dy + length * 0.92)
  ..quadraticBezierTo(top.dx + length * 0.05, top.dy + length * 0.45, top.dx - length * 0.42, top.dy + length * 0.05)
  ..close();

/// Le venature del legno: qualche curva lunga, appena storta.
List<_Detail> _grain(Path clip, Rect area, {int count = 3, double bend = 0.25}) => [
  for (var i = 0; i < count; i++)
    _Detail(
      Path()
        ..moveTo(area.left, area.top + area.height * (i + 0.6) / (count + 0.4))
        ..cubicTo(
          area.left + area.width * 0.33,
          area.top + area.height * ((i + 0.6) / (count + 0.4) - bend * 0.3),
          area.left + area.width * 0.66,
          area.top + area.height * ((i + 0.6) / (count + 0.4) + bend * 0.3),
          area.right,
          area.top + area.height * (i + 0.5) / (count + 0.4),
        ),
      _Line.grain,
      width: 0.0012,
      clip: clip,
    ),
];

/// La zigrinatura di un'impugnatura: due fasci di diagonali.
List<_Detail> _checker(Path clip, Rect area, {double step = 0.0055}) {
  final lines = Path();
  final span = area.width + area.height;
  for (var s = 0.0; s < span; s += step) {
    lines
      ..moveTo(area.left + s, area.top)
      ..lineTo(area.left + s - area.height, area.bottom)
      ..moveTo(area.left + s - area.height, area.top)
      ..lineTo(area.left + s, area.bottom);
  }
  return [_Detail(lines, _Line.groove, width: 0.0008, clip: clip)];
}

// ---------------------------------------------------------------- le armi

/// Il revolver .38: canna da [barrel] metri, tamburo che sporge sotto la
/// canna, cane a sperone, ponticello tondo, calcio di legno ricurvo.
_Model _revolver(double barrel, {required bool roundButt}) {
  const bore = -0.080;
  final end = 0.072 + barrel;
  final strap = _box(-0.004, -0.0945, 0.070, -0.0875, 0.002);
  final shield = _box(-0.010, -0.092, 0.020, -0.046, 0.005);
  final cylinder = _box(0.016, -0.0910, 0.061, -0.0455, 0.0125);
  final shank = _box(0.058, -0.0935, 0.073, -0.067, 0.004);
  final lower = _box(-0.004, -0.050, 0.024, -0.041, 0.003);
  final tube = _poly([_o(0.070, -0.0880), _o(end, -0.0872), _o(end, -0.0728), _o(0.070, -0.0720)]);
  final sight = _poly([
    _o(end - 0.016, -0.0872),
    _o(end - 0.005, -0.0950),
    _o(end - 0.0012, -0.0950),
    _o(end - 0.0012, -0.0872),
  ]);
  final rodEnd = 0.060 + barrel * (roundButt ? 0.80 : 0.66);
  final rod = Path()
    ..addPath(_box(0.058, -0.0712, rodEnd, -0.0648, 0.002), Offset.zero)
    ..addPath(_disc(_o(rodEnd, -0.068), 0.0048), Offset.zero);
  final hammer = Path()
    ..moveTo(-0.003, -0.0915)
    ..quadraticBezierTo(-0.010, -0.0990, -0.021, -0.1025)
    ..quadraticBezierTo(-0.031, -0.1055, -0.030, -0.0985)
    ..quadraticBezierTo(-0.022, -0.0945, -0.014, -0.0870)
    ..lineTo(-0.008, -0.0855)
    ..close();
  final butt = roundButt ? 0.012 : 0.020;
  final frame = Path()
    ..moveTo(-0.008, -0.089)
    ..cubicTo(-0.022, -0.087, -0.031, -0.075, -0.033, -0.058)
    ..cubicTo(-0.035, -0.036, -0.048, -0.016, -0.054, butt - 0.010);
  if (roundButt) {
    frame
      ..quadraticBezierTo(-0.057, butt + 0.003, -0.041, butt + 0.003)
      ..quadraticBezierTo(-0.024, butt + 0.003, -0.022, butt - 0.008);
  } else {
    frame
      ..lineTo(-0.054, butt)
      ..lineTo(-0.021, butt + 0.005)
      ..lineTo(-0.020, butt - 0.005);
  }
  frame
    ..cubicTo(-0.016, -0.014, -0.004, -0.030, 0.004, -0.044)
    ..lineTo(0.004, -0.089)
    ..close();
  final panel = Path()
    ..moveTo(-0.011, -0.075)
    ..cubicTo(-0.021, -0.070, -0.026, -0.058, -0.027, -0.046)
    ..cubicTo(-0.029, -0.028, -0.040, -0.012, -0.046, butt - 0.010)
    ..quadraticBezierTo(-0.037, butt - 0.003, -0.027, butt - 0.008)
    ..cubicTo(-0.022, -0.014, -0.010, -0.030, -0.003, -0.046)
    ..lineTo(-0.003, -0.073)
    ..close();
  final (guard, hole) = _guard(Rect.fromLTRB(0.001, -0.056, 0.041, -0.020), 0.0055, top: -0.041);
  final trigger = _trigger(_o(0.019, -0.041), 0.015);
  return _Model(
    [
      _Part(frame, _Mat.steel),
      _Part(panel, _Mat.wood),
      _Part(guard, _Mat.steel),
      _Part(lower, _Mat.steel),
      _Part(hammer, _Mat.steel),
      _Part(shield, _Mat.steel),
      _Part(tube, _Mat.steel),
      _Part(rod, _Mat.steel),
      _Part(sight, _Mat.steel),
      _Part(shank, _Mat.steel),
      _Part(cylinder, _Mat.steel),
      _Part(strap, _Mat.steel),
    ],
    holes: [hole],
    after: [_Part(trigger, _Mat.steel)],
    details: [
      // Le scanalature del tamburo, la luce sulla canna, il legno zigrinato.
      _Detail(_box(0.025, -0.0835, 0.053, -0.0775, 0.003), _Line.groove),
      _Detail(_box(0.025, -0.0600, 0.053, -0.0540, 0.003), _Line.groove),
      _Detail(_seg(_o(0.076, -0.0855), _o(end - 0.018, -0.0850)), _Line.shine, width: 0.0011),
      _Detail(_seg(_o(0.022, -0.0870), _o(0.056, -0.0870)), _Line.shine, width: 0.0009),
      ..._checker(panel, Rect.fromLTRB(-0.045, -0.080, 0.000, butt)),
      _Detail(_disc(_o(-0.020, -0.036), 0.0026), _Line.brass),
    ],
    muzzle: _o(end, bore),
    grip: frame,
  ).shift(_o(0.022, -0.0145));
}

/// La Beretta 1934: carrello con la canna scoperta davanti, cane esterno,
/// e lo sperone per il mignolo sotto il caricatore.
_Model _beretta() {
  const end = 0.104;
  final slide = Path()
    ..moveTo(-0.046, -0.090)
    ..lineTo(0.030, -0.090)
    ..lineTo(0.036, -0.084)
    ..lineTo(0.092, -0.084)
    ..lineTo(0.096, -0.090)
    ..lineTo(end, -0.090)
    ..lineTo(end, -0.064)
    ..lineTo(-0.046, -0.064)
    ..close();
  final barrel = _box(0.030, -0.088, end, -0.074, 0.002);
  final frame = _box(-0.040, -0.066, 0.070, -0.056, 0.003);
  final hammer = Path()
    ..moveTo(-0.044, -0.082)
    ..quadraticBezierTo(-0.054, -0.094, -0.060, -0.090)
    ..quadraticBezierTo(-0.058, -0.078, -0.046, -0.070)
    ..close();
  final grip = Path()
    ..moveTo(-0.040, -0.062)
    ..lineTo(-0.054, 0.004)
    ..lineTo(-0.054, 0.012)
    ..lineTo(-0.012, 0.012)
    ..quadraticBezierTo(0.004, 0.012, 0.004, 0.004)
    ..lineTo(-0.008, 0.002)
    ..lineTo(0.004, -0.058)
    ..close();
  final panel = _poly([_o(-0.034, -0.054), _o(-0.046, 0.000), _o(-0.014, 0.000), _o(-0.004, -0.054)]);
  final (guard, hole) = _guard(Rect.fromLTRB(0.004, -0.066, 0.044, -0.030), 0.005, top: -0.056);
  return _Model(
    [
      _Part(grip, _Mat.steel),
      _Part(panel, _Mat.wood),
      _Part(guard, _Mat.steel),
      _Part(frame, _Mat.steel),
      _Part(hammer, _Mat.steel),
      _Part(barrel, _Mat.steel),
      _Part(slide, _Mat.steel),
      _Part(_poly([_o(end - 0.008, -0.090), _o(end - 0.006, -0.096), _o(end - 0.002, -0.096), _o(end - 0.001, -0.090)]), _Mat.steel),
    ],
    holes: [hole],
    after: [_Part(_trigger(_o(0.022, -0.056), 0.016), _Mat.steel)],
    details: [
      for (var i = 0; i < 7; i++)
        _Detail(_seg(_o(-0.040 + i * 0.004, -0.088), _o(-0.040 + i * 0.004, -0.067)), _Line.groove, width: 0.0008),
      _Detail(_seg(_o(0.036, -0.0815), _o(0.090, -0.0815)), _Line.shine, width: 0.001),
      ..._checker(panel, const Rect.fromLTRB(-0.050, -0.056, 0.000, 0.002)),
    ],
    muzzle: _o(end, -0.081),
    grip: grip,
  ).shift(_o(0.024, -0.004));
}

/// Il Thompson del '28: calcio di noce, castello, tamburo da cinquanta colpi,
/// impugnatura davanti, canna con le alette e il compensatore.
_Model _tommy() {
  final stock = Path()
    ..moveTo(-0.074, -0.118)
    ..lineTo(-0.150, -0.112)
    ..lineTo(-0.372, -0.101)
    ..quadraticBezierTo(-0.386, -0.100, -0.387, -0.088)
    ..quadraticBezierTo(-0.392, -0.030, -0.388, 0.030)
    ..quadraticBezierTo(-0.386, 0.042, -0.372, 0.040)
    ..cubicTo(-0.290, 0.018, -0.190, -0.030, -0.112, -0.050)
    ..quadraticBezierTo(-0.090, -0.056, -0.074, -0.058)
    ..close();
  final butt = _box(-0.392, -0.100, -0.382, 0.040, 0.003);
  final receiver = _box(-0.078, -0.122, 0.190, -0.054, 0.006);
  final rearSight = _poly([_o(-0.060, -0.121), _o(-0.056, -0.140), _o(-0.040, -0.140), _o(-0.036, -0.121)]);
  final knob = _box(0.086, -0.134, 0.110, -0.119, 0.006);
  final frame = _box(-0.056, -0.058, 0.066, -0.042, 0.004);
  final grip = Path()
    ..moveTo(-0.032, -0.046)
    ..lineTo(0.010, -0.046)
    ..quadraticBezierTo(0.004, 0.010, 0.002, 0.040)
    ..quadraticBezierTo(-0.002, 0.056, -0.020, 0.055)
    ..quadraticBezierTo(-0.040, 0.053, -0.042, 0.038)
    ..quadraticBezierTo(-0.040, 0.000, -0.032, -0.046)
    ..close();
  final (guard, hole) = _guard(Rect.fromLTRB(0.010, -0.050, 0.056, -0.012), 0.0055, top: -0.042);
  final well = _box(0.088, -0.058, 0.152, -0.044, 0.002);
  const drumAt = Offset(0.122, 0.036);
  final drum = _disc(drumAt, 0.088);
  final barrel = _poly([_o(0.188, -0.101), _o(0.430, -0.100), _o(0.430, -0.080), _o(0.188, -0.079)]);
  final fins = Path();
  for (var i = 0; i < 10; i++) {
    final x = 0.194 + i * 0.0135;
    fins.addRRect(RRect.fromLTRBR(x, -0.1105, x + 0.0072, -0.0695, const Radius.circular(0.0015)));
  }
  final comp = _box(0.428, -0.107, 0.484, -0.073, 0.003);
  final slots = Path();
  for (var k = 0; k < 4; k++) {
    final x = 0.436 + k * 0.0105;
    slots.addRect(Rect.fromLTRB(x, -0.110, x + 0.0055, -0.098));
  }
  final frontSight = _poly([_o(0.470, -0.106), _o(0.473, -0.118), _o(0.479, -0.118), _o(0.482, -0.106)]);
  final foreMount = _box(0.214, -0.083, 0.270, -0.074, 0.002);
  final foregrip = Path()
    ..moveTo(0.222, -0.077)
    ..lineTo(0.262, -0.077)
    ..lineTo(0.268, -0.062)
    ..quadraticBezierTo(0.257, -0.050, 0.270, -0.038)
    ..quadraticBezierTo(0.259, -0.026, 0.272, -0.014)
    ..quadraticBezierTo(0.261, -0.002, 0.274, 0.010)
    ..quadraticBezierTo(0.278, 0.030, 0.258, 0.030)
    ..lineTo(0.240, 0.028)
    ..quadraticBezierTo(0.224, 0.000, 0.222, -0.077)
    ..close();
  return _Model(
    [
      _Part(stock, _Mat.wood),
      _Part(butt, _Mat.steel),
      _Part(grip, _Mat.wood),
      _Part(guard, _Mat.steel),
      _Part(frame, _Mat.steel),
      _Part(well, _Mat.steel),
      _Part(drum, _Mat.steel),
      _Part(barrel, _Mat.steel),
      _Part(fins, _Mat.steel),
      _Part(comp, _Mat.steel),
      _Part(frontSight, _Mat.steel),
      _Part(foreMount, _Mat.steel),
      _Part(foregrip, _Mat.wood),
      _Part(receiver, _Mat.steel),
      _Part(rearSight, _Mat.steel),
      _Part(knob, _Mat.steel),
    ],
    holes: [hole, slots],
    after: [_Part(_trigger(_o(0.028, -0.042), 0.020), _Mat.steel)],
    details: [
      ..._grain(stock, const Rect.fromLTRB(-0.390, -0.110, -0.070, 0.030), count: 4, bend: 0.4),
      ..._grain(foregrip, const Rect.fromLTRB(0.220, -0.078, 0.276, 0.030), count: 2),
      // Il tamburo: il bordo, il mozzo con la chiavetta per caricarlo.
      _Detail(_disc(drumAt, 0.075), _Line.groove, width: 0.0018),
      _Detail(_disc(drumAt, 0.018), _Line.shine, width: 0.0016),
      _Detail(_seg(drumAt.translate(-0.014, 0.010), drumAt.translate(0.014, -0.010)), _Line.groove, width: 0.004),
      _Detail(_seg(_o(-0.070, -0.1165), _o(0.182, -0.1165)), _Line.shine, width: 0.0014),
      _Detail(_seg(_o(0.010, -0.104), _o(0.070, -0.104)), _Line.groove, width: 0.0012),
      _Detail(_seg(_o(0.196, -0.0975), _o(0.425, -0.0965)), _Line.shine, width: 0.0012),
      _Detail(_disc(_o(-0.020, -0.084), 0.0035), _Line.groove),
      _Detail(_disc(_o(0.150, -0.084), 0.0035), _Line.groove),
    ],
    muzzle: _o(0.484, -0.090),
    support: _o(0.248, -0.028),
    grip: grip,
  ).shift(_o(0.016, -0.0125));
}

/// La custodia da violino, presa per la maniglia: si vede il fianco, con la
/// sagoma dello strumento.
_Model _violinCase() {
  const outline = [
    (-0.400, 0.000),
    (-0.394, 0.074),
    (-0.366, 0.110),
    (-0.310, 0.124),
    (-0.235, 0.120),
    (-0.165, 0.102),
    (-0.115, 0.090),
    (-0.065, 0.096),
    (0.000, 0.104),
    (0.055, 0.096),
    (0.100, 0.072),
    (0.140, 0.054),
    (0.200, 0.049),
    (0.320, 0.050),
    (0.372, 0.052),
    (0.396, 0.036),
    (0.402, 0.000),
  ];
  final shell = _lathe([for (final (x, r) in outline) _o(x, r)]);
  final lid = _lathe([for (final (x, r) in outline) _o(x * 0.965, max(0.0, r - 0.013))]);
  const hx = -0.110;
  const top = -0.090;
  final handle = Path()
    ..moveTo(hx - 0.044, top + 0.004)
    ..quadraticBezierTo(hx - 0.046, top - 0.052, hx, top - 0.052)
    ..quadraticBezierTo(hx + 0.046, top - 0.052, hx + 0.044, top + 0.004)
    ..lineTo(hx + 0.032, top + 0.004)
    ..quadraticBezierTo(hx + 0.032, top - 0.039, hx, top - 0.039)
    ..quadraticBezierTo(hx - 0.032, top - 0.039, hx - 0.032, top + 0.004)
    ..close();
  final latches = [
    _box(-0.322, -0.130, -0.300, -0.115, 0.002),
    _box(hx - 0.060, -0.098, hx - 0.044, -0.084, 0.002),
    _box(hx + 0.044, -0.098, hx + 0.060, -0.084, 0.002),
    _box(0.250, -0.056, 0.268, -0.042, 0.002),
  ];
  return _Model(
    [
      _Part(shell, _Mat.leather),
      _Part(handle, _Mat.leather),
      for (final latch in latches) _Part(latch, _Mat.brass),
    ],
    details: [
      _Detail(lid, _Line.groove, width: 0.0022),
      _Detail(lid.shift(_o(0.0015, -0.002)), _Line.shine, width: 0.0008, clip: _box(-0.4, -0.2, 0.4, -0.03)),
      for (final latch in latches) _Detail(latch, _Line.brass),
    ],
    muzzle: _o(0.402, 0),
    grip: handle,
  ).shift(_o(-hx, -top + 0.046));
}

/// La lupara: doppietta a cani esterni, canne affiancate e segate corte, il
/// calcio tagliato.
_Model _lupara() {
  final stock = Path()
    ..moveTo(0.040, -0.050)
    ..lineTo(-0.040, -0.047)
    ..quadraticBezierTo(-0.090, -0.046, -0.130, -0.044)
    ..lineTo(-0.244, -0.041)
    ..quadraticBezierTo(-0.254, -0.041, -0.254, -0.031)
    ..quadraticBezierTo(-0.258, 0.012, -0.254, 0.052)
    ..quadraticBezierTo(-0.252, 0.062, -0.240, 0.060)
    ..cubicTo(-0.190, 0.042, -0.125, 0.014, -0.080, 0.006)
    ..quadraticBezierTo(-0.050, 0.001, -0.036, 0.010)
    ..quadraticBezierTo(-0.022, 0.014, -0.012, 0.000)
    ..lineTo(0.036, -0.006)
    ..close();
  final butt = _box(-0.258, -0.042, -0.250, 0.060, 0.002);
  final action = _box(0.032, -0.052, 0.102, -0.004, 0.007);
  final fences = _box(0.090, -0.060, 0.104, -0.038, 0.005);
  // Le due canne: quella vicina e, appena sopra, quella lontana.
  final near = _poly([_o(0.098, -0.035), _o(0.398, -0.034), _o(0.398, -0.012), _o(0.098, -0.011)]);
  final far = _poly([_o(0.098, -0.054), _o(0.398, -0.0525), _o(0.398, -0.0315), _o(0.098, -0.033)]);
  final mouths = Path()
    ..addPath(_ellipse(_o(0.398, -0.023), 0.0050, 0.0115), Offset.zero)
    ..addPath(_ellipse(_o(0.398, -0.042), 0.0050, 0.0110), Offset.zero);
  // Fra le due canne, la bindella: un filo di vuoto che prende la luce.
  final notch = _poly([_o(0.130, -0.0345), _o(0.406, -0.0338), _o(0.406, -0.0300), _o(0.130, -0.0315)]);
  Path hammer(double dx, double dy) => (Path()
        ..moveTo(0.038, -0.049)
        ..lineTo(0.054, -0.050)
        ..quadraticBezierTo(0.048, -0.068, 0.030, -0.079)
        ..quadraticBezierTo(0.016, -0.087, 0.012, -0.078)
        ..quadraticBezierTo(0.024, -0.072, 0.034, -0.057)
        ..close())
      .shift(_o(dx, dy));
  final (guard, hole) = _guard(Rect.fromLTRB(0.034, -0.016, 0.092, 0.022), 0.005, top: -0.004);
  final fore = Path()
    ..moveTo(0.100, -0.014)
    ..lineTo(0.205, -0.013)
    ..quadraticBezierTo(0.216, -0.011, 0.214, -0.004)
    ..lineTo(0.100, -0.001)
    ..close();
  return _Model(
    [
      _Part(stock, _Mat.wood),
      _Part(butt, _Mat.steel),
      _Part(guard, _Mat.steel),
      _Part(hammer(0.014, -0.003), _Mat.steel),
      _Part(far, _Mat.steel),
      _Part(near, _Mat.steel),
      _Part(mouths, _Mat.steel),
      _Part(fore, _Mat.wood),
      _Part(action, _Mat.steel),
      _Part(fences, _Mat.steel),
      _Part(hammer(0, 0), _Mat.steel),
    ],
    holes: [hole, notch],
    after: [
      _Part(_trigger(_o(0.052, -0.004), 0.015), _Mat.steel),
      _Part(_trigger(_o(0.066, -0.004), 0.013), _Mat.steel),
    ],
    details: [
      ..._grain(stock, const Rect.fromLTRB(-0.256, -0.046, 0.040, 0.060), count: 3, bend: 0.35),
      // La bindella fra le due canne e la luce su quella di sopra.
      _Detail(_seg(_o(0.104, -0.0325), _o(0.130, -0.0330)), _Line.groove, width: 0.0022),
      _Detail(_seg(_o(0.104, -0.0500), _o(0.394, -0.0490)), _Line.shine, width: 0.0011),
      _Detail(_seg(_o(0.104, -0.0300), _o(0.394, -0.0295)), _Line.shine, width: 0.0008),
      // Le viti della bascula.
      _Detail(_disc(_o(0.050, -0.026), 0.0028), _Line.brass),
      _Detail(_disc(_o(0.082, -0.018), 0.0028), _Line.brass),
      _Detail(_seg(_o(0.040, -0.046), _o(0.094, -0.046)), _Line.shine, width: 0.0010),
    ],
    muzzle: _o(0.400, -0.031),
    support: _o(0.160, -0.004),
    grip: stock,
  ).shift(_o(0.030, 0.0));
}

/// Lo stiletto: pomo, manico, guardia a croce, lama sottile con la costola.
_Model _stiletto() {
  final pommel = _disc(_o(-0.060, 0), 0.0095);
  final handle = Path()
    ..moveTo(-0.054, -0.0085)
    ..quadraticBezierTo(0.000, -0.0125, 0.053, -0.0095)
    ..lineTo(0.053, 0.0095)
    ..quadraticBezierTo(0.000, 0.0125, -0.054, 0.0085)
    ..close();
  final guard = Path()
    ..addRRect(RRect.fromLTRBR(0.0525, -0.031, 0.0605, 0.031, const Radius.circular(0.003)))
    ..addOval(Rect.fromCircle(center: _o(0.0565, -0.032), radius: 0.0055))
    ..addOval(Rect.fromCircle(center: _o(0.0565, 0.032), radius: 0.0055));
  final blade = _poly([_o(0.060, -0.0078), _o(0.070, -0.0078), _o(0.194, -0.0007), _o(0.197, 0), _o(0.194, 0.0007), _o(0.070, 0.0078), _o(0.060, 0.0078)]);
  return _Model(
    [
      _Part(handle, _Mat.wood),
      _Part(pommel, _Mat.steel),
      _Part(blade, _Mat.bright),
      _Part(guard, _Mat.steel),
    ],
    details: [
      _Detail(_seg(_o(0.064, 0), _o(0.192, 0)), _Line.shine, width: 0.0012),
      _Detail(_seg(_o(0.064, 0.0015), _o(0.190, 0.0004)), _Line.groove, width: 0.0008),
      for (var i = 0; i < 6; i++)
        _Detail(_seg(_o(-0.040 + i * 0.016, -0.011), _o(-0.046 + i * 0.016, 0.011)), _Line.grain, width: 0.0012),
    ],
    muzzle: _o(0.197, 0),
    grip: handle,
  );
}

/// La mazza: pomello, manico sottile, botte grossa in fondo.
_Model _bat() {
  final body = _lathe([
    _o(-0.058, 0.0115),
    _o(0.060, 0.0118),
    _o(0.200, 0.0128),
    _o(0.330, 0.0165),
    _o(0.450, 0.0245),
    _o(0.560, 0.0318),
    _o(0.680, 0.0338),
    _o(0.770, 0.0338),
    _o(0.798, 0.026),
    _o(0.806, 0.000),
  ]);
  final knob = _ellipse(_o(-0.064, 0), 0.0085, 0.0205);
  return _Model(
    [_Part(body, _Mat.ash), _Part(knob, _Mat.ash)],
    details: [
      ..._grain(body, const Rect.fromLTRB(0.20, -0.030, 0.80, 0.030), count: 4, bend: 0.12),
      _Detail(_ellipse(_o(0.640, -0.002), 0.034, 0.0125), _Line.groove, width: 0.0016),
      _Detail(_seg(_o(0.30, -0.0115), _o(0.77, -0.0270)), _Line.shine, width: 0.0018, clip: body),
    ],
    muzzle: _o(0.806, 0),
    grip: _box(-0.05, -0.02, 0.05, 0.02),
  );
}

/// Il fucile del Cecchino: calcio dritto, otturatore col manubrio piegato in
/// giù, fascette, e il cannocchiale lungo e sottile su due supporti.
_Model _sniper() {
  final stock = Path()
    ..moveTo(0.000, -0.012)
    ..lineTo(-0.070, -0.013)
    ..quadraticBezierTo(-0.120, -0.016, -0.180, -0.020)
    ..lineTo(-0.318, -0.022)
    ..quadraticBezierTo(-0.328, -0.022, -0.328, -0.012)
    ..quadraticBezierTo(-0.333, 0.040, -0.330, 0.086)
    ..quadraticBezierTo(-0.328, 0.095, -0.316, 0.093)
    ..cubicTo(-0.250, 0.074, -0.170, 0.044, -0.112, 0.030)
    ..quadraticBezierTo(-0.078, 0.022, -0.062, 0.030)
    ..quadraticBezierTo(-0.046, 0.040, -0.030, 0.032)
    ..quadraticBezierTo(-0.016, 0.024, 0.000, 0.022)
    ..lineTo(0.216, 0.020)
    ..lineTo(0.216, -0.010)
    ..close();
  final butt = _box(-0.335, -0.022, -0.326, 0.090, 0.002);
  final fore = Path()
    ..moveTo(0.214, -0.011)
    ..lineTo(0.620, -0.009)
    ..quadraticBezierTo(0.632, -0.007, 0.629, 0.001)
    ..lineTo(0.620, 0.011)
    ..lineTo(0.214, 0.020)
    ..close();
  final receiver = _box(-0.010, -0.017, 0.216, 0.004, 0.004);
  final cocking = _box(-0.032, -0.015, -0.006, 0.000, 0.004);
  final bolt = Path()
    ..addPolygon([_o(0.034, -0.008), _o(0.041, -0.006), _o(0.024, 0.028), _o(0.017, 0.026)], true)
    ..addOval(Rect.fromCircle(center: _o(0.019, 0.032), radius: 0.0095));
  final (guard, hole) = _guard(Rect.fromLTRB(0.022, 0.012, 0.078, 0.046), 0.005, top: 0.021);
  final plate = _box(0.076, 0.016, 0.150, 0.028, 0.004);
  final barrel = _poly([_o(0.214, -0.0095), _o(0.776, -0.0075), _o(0.776, 0.0075), _o(0.214, 0.0095)]);
  final bands = Path()
    ..addRRect(RRect.fromLTRBR(0.395, -0.0125, 0.408, 0.0165, const Radius.circular(0.002)))
    ..addRRect(RRect.fromLTRBR(0.596, -0.0120, 0.612, 0.0150, const Radius.circular(0.002)));
  final frontSight = _poly([_o(0.758, -0.007), _o(0.761, -0.020), _o(0.768, -0.020), _o(0.772, -0.007)]);
  final tube = _box(-0.082, -0.054, 0.420, -0.036, 0.004);
  final eyepiece = _box(-0.112, -0.057, -0.076, -0.033, 0.005);
  final objective = _poly([_o(0.410, -0.054), _o(0.438, -0.0615), _o(0.480, -0.0615), _o(0.480, -0.0285), _o(0.438, -0.0285), _o(0.410, -0.036)]);
  final mounts = Path()
    ..addRRect(RRect.fromLTRBR(0.026, -0.040, 0.060, -0.015, const Radius.circular(0.002)))
    ..addRRect(RRect.fromLTRBR(0.300, -0.040, 0.326, -0.008, const Radius.circular(0.002)));
  final drum = _box(0.034, -0.067, 0.054, -0.053, 0.003);
  return _Model(
    [
      _Part(stock, _Mat.wood),
      _Part(butt, _Mat.steel),
      _Part(fore, _Mat.wood),
      _Part(guard, _Mat.steel),
      _Part(plate, _Mat.steel),
      _Part(barrel, _Mat.steel),
      _Part(bands, _Mat.steel),
      _Part(frontSight, _Mat.steel),
      _Part(receiver, _Mat.steel),
      _Part(cocking, _Mat.steel),
      _Part(bolt, _Mat.steel),
      _Part(mounts, _Mat.steel),
      _Part(tube, _Mat.steel),
      _Part(eyepiece, _Mat.steel),
      _Part(objective, _Mat.steel),
      _Part(drum, _Mat.steel),
    ],
    holes: [hole],
    after: [_Part(_trigger(_o(0.040, 0.021), 0.016), _Mat.steel)],
    details: [
      ..._grain(stock, const Rect.fromLTRB(-0.330, -0.018, 0.000, 0.085), count: 3, bend: 0.4),
      ..._grain(fore, const Rect.fromLTRB(0.214, -0.010, 0.630, 0.020), count: 2, bend: 0.1),
      _Detail(_seg(_o(-0.074, -0.0505), _o(0.414, -0.0505)), _Line.shine, width: 0.0012),
      _Detail(_seg(_o(0.220, -0.0062), _o(0.770, -0.0050)), _Line.shine, width: 0.0010),
      _Detail(_seg(_o(0.444, -0.0585), _o(0.478, -0.0585)), _Line.shine, width: 0.0010),
    ],
    muzzle: _o(0.776, 0),
    grip: stock,
  ).shift(_o(0.045, -0.010));
}

/// Il fucile subacqueo: fusto di legno, impugnatura a pistola, elastici in
/// testa e la fiocina con l'aletta.
_Model _speargun() {
  final body = Path()
    ..moveTo(-0.300, -0.028)
    ..lineTo(0.640, -0.022)
    ..lineTo(0.640, 0.000)
    ..lineTo(0.010, 0.006)
    ..lineTo(-0.280, 0.012)
    ..quadraticBezierTo(-0.302, 0.012, -0.302, -0.006)
    ..close();
  final grip = Path()
    ..moveTo(-0.034, 0.004)
    ..lineTo(0.010, 0.004)
    ..quadraticBezierTo(0.000, 0.050, -0.006, 0.080)
    ..quadraticBezierTo(-0.010, 0.094, -0.026, 0.092)
    ..quadraticBezierTo(-0.044, 0.088, -0.044, 0.074)
    ..close();
  final (guard, hole) = _guard(Rect.fromLTRB(0.010, -0.004, 0.052, 0.034), 0.005, top: 0.004);
  final head = _box(0.628, -0.034, 0.664, 0.006, 0.004);
  final bands = _poly([_o(0.650, -0.034), _o(0.300, -0.042), _o(0.300, -0.036), _o(0.650, -0.028)]);
  final spear = _box(-0.210, -0.042, 0.720, -0.035, 0.002);
  final tip = _poly([_o(0.716, -0.046), _o(0.770, -0.0385), _o(0.716, -0.031)]);
  final barb = _poly([_o(0.722, -0.041), _o(0.700, -0.054), _o(0.706, -0.056), _o(0.734, -0.040)]);
  final reel = _disc(_o(0.130, 0.024), 0.021);
  return _Model(
    [
      _Part(body, _Mat.wood),
      _Part(grip, _Mat.wood),
      _Part(guard, _Mat.steel),
      _Part(reel, _Mat.steel),
      _Part(head, _Mat.steel),
      _Part(bands, _Mat.rubber),
      _Part(spear, _Mat.bright),
      _Part(tip, _Mat.bright),
      _Part(barb, _Mat.bright),
    ],
    holes: [hole],
    after: [_Part(_trigger(_o(0.028, 0.004), 0.016), _Mat.steel)],
    details: [
      ..._grain(body, const Rect.fromLTRB(-0.30, -0.026, 0.64, 0.010), count: 2, bend: 0.1),
      _Detail(_disc(_o(0.130, 0.024), 0.012), _Line.groove, width: 0.0015),
      _Detail(_seg(_o(-0.20, -0.0405), _o(0.715, -0.0405)), _Line.shine, width: 0.0009),
    ],
    muzzle: _o(0.770, -0.0385),
    grip: grip,
  ).shift(_o(0.024, -0.034));
}

/// La bomba "ananas": il corpo a quadretti, la spoletta, la leva e l'anello.
_Model _grenade() {
  final body = <Offset>[];
  for (var i = 0; i < 120; i++) {
    final a = i / 120 * 2 * pi;
    final bump = 1 + 0.07 * pow(max(0.0, cos(a * 12)), 2);
    body.add(_o(sin(a) * 0.029 * bump, -cos(a) * 0.044 * bump));
  }
  final shell = _smooth(body);
  final neck = _box(-0.010, -0.052, 0.010, -0.040, 0.002);
  final fuze = _box(-0.012, -0.066, 0.012, -0.050, 0.003);
  final lever = Path()
    ..moveTo(0.006, -0.066)
    ..lineTo(0.020, -0.066)
    ..quadraticBezierTo(0.036, -0.040, 0.035, -0.006)
    ..lineTo(0.029, -0.006)
    ..quadraticBezierTo(0.030, -0.040, 0.010, -0.058)
    ..close();
  final ring = Path.combine(
    PathOperation.difference,
    _disc(_o(-0.022, -0.060), 0.011),
    _disc(_o(-0.022, -0.060), 0.0075),
  );
  final grid = Path();
  for (final y in [-0.022, 0.0, 0.022]) {
    grid
      ..moveTo(-0.032, y)
      ..lineTo(0.032, y);
  }
  grid
    ..moveTo(0, -0.046)
    ..lineTo(0, 0.046)
    ..moveTo(-0.015, -0.042)
    ..quadraticBezierTo(-0.020, 0, -0.015, 0.042)
    ..moveTo(0.015, -0.042)
    ..quadraticBezierTo(0.020, 0, 0.015, 0.042);
  return _Model(
    [
      _Part(shell, _Mat.steel),
      _Part(neck, _Mat.steel),
      _Part(fuze, _Mat.steel),
      _Part(lever, _Mat.steel),
      _Part(ring, _Mat.wire),
    ],
    details: [_Detail(grid, _Line.groove, width: 0.0022, clip: shell)],
    muzzle: _o(0, -0.066),
  );
}

/// Il forcone: manico lungo, ghiera, tre rebbi ricurvi.
_Model _pitchfork() {
  final shaft = _box(-0.950, -0.0155, 0.200, 0.0155, 0.012);
  final ferrule = _box(0.190, -0.019, 0.250, 0.019, 0.004);
  final bar = Path()
    ..moveTo(0.244, -0.008)
    ..quadraticBezierTo(0.252, -0.082, 0.300, -0.084)
    ..lineTo(0.300, -0.072)
    ..quadraticBezierTo(0.264, -0.068, 0.260, 0.000)
    ..quadraticBezierTo(0.264, 0.068, 0.300, 0.072)
    ..lineTo(0.300, 0.084)
    ..quadraticBezierTo(0.252, 0.082, 0.244, 0.008)
    ..close();
  Path tine(double y, double curl) => Path()
    ..moveTo(0.296, y - 0.006)
    ..quadraticBezierTo(0.440, y - 0.006 - curl, 0.580, y - curl * 1.6)
    ..lineTo(0.582, y - curl * 1.6 + 0.003)
    ..quadraticBezierTo(0.440, y + 0.006 - curl, 0.296, y + 0.006)
    ..close();
  final centre = _poly([_o(0.250, -0.006), _o(0.590, -0.0015), _o(0.590, 0.0015), _o(0.250, 0.006)]);
  return _Model(
    [
      _Part(shaft, _Mat.ash),
      _Part(bar, _Mat.steel),
      _Part(tine(-0.078, -0.012), _Mat.steel),
      _Part(tine(0.078, 0.012), _Mat.steel),
      _Part(centre, _Mat.steel),
      _Part(ferrule, _Mat.steel),
    ],
    details: [
      ..._grain(shaft, const Rect.fromLTRB(-0.95, -0.014, 0.19, 0.014), count: 2, bend: 0.05),
    ],
    muzzle: _o(0.590, 0),
    grip: _box(-0.06, -0.02, 0.06, 0.02),
  );
}

/// Una maniglia della garrota: un piolo di legno, di traverso al filo.
_Model _toggle() => _Model(
  [
    _Part(_box(-0.050, -0.0115, 0.050, 0.0115, 0.0105), _Mat.wood),
    _Part(_disc(Offset.zero, 0.006), _Mat.steel),
  ],
  details: [
    _Detail(_seg(_o(-0.044, -0.004), _o(0.044, -0.004)), _Line.grain, width: 0.0012),
  ],
  muzzle: Offset.zero,
);
