import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'city_backdrop.dart';
import 'noir_avatar.dart';

/// Le coreografie disponibili per un delitto notturno.
enum DeathAct { knife, gun, burst, car, piano, safe, chandelier, blast, poison, noose, grab }

/// La coreografia che mette in scena un'azione del copione. Un'azione senza
/// coreografia sua ripiega sul classico: il pugnale da dietro l'angolo.
DeathAct deathActFor(String methodId) => switch (methodId) {
      'pugnale' => DeathAct.knife,
      'silenziatore' => DeathAct.gun,
      'violino' => DeathAct.burst,
      'auto' => DeathAct.car,
      'pianoforte' => DeathAct.piano,
      'cassaforte' => DeathAct.safe,
      'lampadario' => DeathAct.chandelier,
      'pacco' || 'sigaro' => DeathAct.blast,
      'veleno' => DeathAct.poison,
      'cappio' => DeathAct.noose,
      'cemento' => DeathAct.grab,
      _ => DeathAct.knife,
    };

/// La scena del delitto, da guardare tutti insieme col telefono sul tavolo:
/// una strada di notte, la vittima che arriva, e qualcuno dietro l'angolo.
/// Si chiude sul ritratto di chi non vedrà l'alba.
class DeathScene extends StatefulWidget {
  final DeathAct act;
  final String victimName;

  /// La didascalia sotto la scena, come il cartello di un film muto.
  final String caption;
  final SkylineStyle style;
  final VoidCallback onFinished;

  const DeathScene({
    super.key,
    required this.act,
    required this.victimName,
    required this.caption,
    required this.onFinished,
    this.style = SkylineStyle.metropolis,
  });

  @override
  State<DeathScene> createState() => _DeathSceneState();
}

class _DeathSceneState extends State<DeathScene> with SingleTickerProviderStateMixin {
  late final AnimationController _film;
  bool _struck = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    // Chi riduce le animazioni vede fermo il fondale, ma non questa scena: è
    // il racconto della notte, e accorciarla la renderebbe illeggibile.
    _film = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 8200),
      animationBehavior: AnimationBehavior.preserve,
    )
      ..addListener(() {
        if (!_struck && _film.value >= DeathScenePainter.strike) {
          _struck = true;
          HapticFeedback.heavyImpact();
        }
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _finish();
      })
      ..forward();
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    widget.onFinished();
  }

  @override
  void dispose() {
    _film.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hat = avatarHeadFor(widget.victimName);
    return Stack(
      fit: StackFit.expand,
      children: [
        CityBackdrop(style: widget.style, rain: true, child: const SizedBox.expand()),
        AnimatedBuilder(
          animation: _film,
          builder: (context, _) => CustomPaint(
            painter: DeathScenePainter(t: _film.value, act: widget.act, victimHat: hat),
          ),
        ),
        AnimatedBuilder(
          animation: _film,
          builder: (context, _) {
            final t = _film.value;
            final typed = (widget.caption.length * _span(t, 0.03, 0.26)).round();
            final card = _span(t, 0.86, 0.93);
            return Stack(
              fit: StackFit.expand,
              children: [
                Align(
                  alignment: const Alignment(0, 0.93),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Opacity(
                      opacity: 1 - _span(t, 0.80, 0.86),
                      child: Text(
                        widget.caption.substring(0, typed),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Courier',
                          fontFamilyFallback: ['monospace'],
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ),
                ),
                if (card > 0)
                  Opacity(
                    opacity: card,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Transform.scale(
                          scale: 1.25 - 0.25 * Curves.easeOut.transform(card),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              NoirAvatar(seed: widget.victimName, size: 132, faded: true),
                              const Text(
                                '†',
                                style: TextStyle(
                                  fontFamily: 'Georgia',
                                  fontSize: 78,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                  shadows: [Shadow(color: Colors.black, blurRadius: 12)],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              widget.victimName.toUpperCase(),
                              style: AppText.display(44, color: AppColors.textPrimary),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text('NON VEDRÀ L\'ALBA', style: AppText.overline),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
        SafeArea(
          child: Align(
            alignment: Alignment.topRight,
            child: TextButton(
              onPressed: _finish,
              child: const Text('SALTA', style: TextStyle(color: AppColors.textSecondary)),
            ),
          ),
        ),
      ],
    );
  }
}

double _span(double t, double from, double to) => ((t - from) / (to - from)).clamp(0.0, 1.0);

double _mix(double a, double b, double t) => a + (b - a) * t;

double _smooth(double t) => Curves.easeInOut.transform(t);

/// Direzione di un arto: 0 punta in basso, pi/2 in avanti, pi in alto.
Offset _aim(double angle) => Offset(sin(angle), cos(angle));

enum _Prop { none, knife, pistol, tommy, cup, box }

/// Disegna un fotogramma della scena. [t] va da 0 a 1 lungo tutto il film.
///
/// Il canovaccio è lo stesso per ogni coreografia: la vittima entra da
/// sinistra e si ferma sotto il lampione, la cinepresa stringe, qualcosa
/// succede a [strike], poi restano gli oggetti di scena e lo schermo vira al
/// rosso.
class DeathScenePainter extends CustomPainter {
  final double t;
  final DeathAct act;
  final AvatarHead victimHat;

  DeathScenePainter({required this.t, required this.act, this.victimHat = AvatarHead.fedora});

  /// Il momento del colpo, uguale per tutte le coreografie.
  static const strike = 0.56;

  static const _ink = Color(0xFF050506);
  static const _rim = Color(0xFF6A5632);
  static const _blood = Color(0xFFB3202A);
  static const _steel = Color(0xFFD5DAE0);
  static const _gunmetal = Color(0xFF3B4048);
  static const _warm = Color(0xFFFFD27A);

  late double _w;
  late double _h;
  late double _ground;
  late double _u;
  late double _victimX;
  late double _cornerX;

  double get _hiddenX => _cornerX + _u * 0.75;
  double get _peekX => _cornerX + _u * 0.17;

  bool get _hasWall => act != DeathAct.car;

  bool get _shakes => switch (act) {
        DeathAct.car || DeathAct.piano || DeathAct.safe || DeathAct.chandelier || DeathAct.blast => true,
        _ => false,
      };

  /// Le coreografie in cui la vittima finisce stesa verso sinistra: la
  /// cinepresa, dopo il colpo, si sposta per tenerla tutta in campo.
  bool get _fallsLeft => switch (act) {
        DeathAct.knife || DeathAct.gun || DeathAct.burst || DeathAct.poison => true,
        _ => false,
      };

  @override
  void paint(Canvas canvas, Size size) {
    _w = size.width;
    _h = size.height;
    _ground = _h * 0.76;
    // Lo schermo è stretto: le figure si misurano sulla larghezza, così chi
    // cade a terra resta dentro l'inquadratura.
    _u = min(_h * 0.30, _w * 0.50);
    _victimX = _w * 0.50;
    _cornerX = _w * 0.84;

    canvas.save();
    _camera(canvas);
    final quake = _span(t, strike, strike + 0.10);
    if (_shakes && quake > 0 && quake < 1) {
      final force = (1 - quake) * _u * 0.06;
      canvas.translate(sin(t * 900) * force, cos(t * 760) * force);
    }
    _street(canvas);
    switch (act) {
      case DeathAct.knife:
        _knife(canvas);
      case DeathAct.gun:
        _shooting(canvas, const [strike], _Prop.pistol);
      case DeathAct.burst:
        _shooting(canvas, const [0.55, 0.575, 0.60, 0.625, 0.65], _Prop.tommy);
      case DeathAct.car:
        _car(canvas);
      case DeathAct.piano || DeathAct.safe || DeathAct.chandelier:
        _fallingObject(canvas);
      case DeathAct.blast:
        _blast(canvas);
      case DeathAct.poison:
        _poison(canvas);
      case DeathAct.noose:
        _noose(canvas);
      case DeathAct.grab:
        _grab(canvas);
    }
    canvas.restore();

    final rect = Offset.zero & size;
    final red = _span(t, 0.82, 0.92);
    if (red > 0) {
      canvas.drawRect(rect, Paint()..color = Color.lerp(_blood, Colors.black, 0.55)!.withValues(alpha: red * 0.86));
    }
    // Le bande nere del cinema.
    final bar = _h * 0.105 * Curves.easeOut.transform(_span(t, 0, 0.05));
    final black = Paint()..color = Colors.black;
    canvas.drawRect(Rect.fromLTWH(0, 0, _w, bar), black);
    canvas.drawRect(Rect.fromLTWH(0, _h - bar * 1.5, _w, bar * 1.5), black);
  }

  /// La cinepresa: parte larga, stringe piano mentre cresce la tensione, e
  /// dopo il colpo si sistema su quello che resta.
  void _camera(Canvas canvas) {
    if (act == DeathAct.car) return;
    final push = _smooth(_span(t, 0.30, 0.54));
    final settle = _smooth(_span(t, strike + 0.10, strike + 0.28));
    final zoom = 1 + 0.22 * push - 0.08 * settle;
    final towardCorner = _hasWall && act != DeathAct.noose ? 0.28 : 0.0;
    var focus = _mix(_w / 2, _mix(_victimX, _cornerX, towardCorner), push);
    focus = _mix(focus, _victimX - (_fallsLeft ? _u * 0.34 : 0), settle);
    final horizon = _ground - _u * 0.45;
    canvas.translate(_w / 2, horizon);
    canvas.scale(zoom);
    canvas.translate(-focus, -horizon);
  }

  // ---------------------------------------------------------------- scenografia

  void _street(Canvas canvas) {
    final lampX = _w * 0.26;
    final lampTop = _ground - _u * 1.42;
    final head = Offset(lampX + _u * 0.24, lampTop + _u * 0.04);

    canvas.drawRect(
      Rect.fromLTRB(-_w, _ground, _w * 2, _h * 1.3),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF101117), Color(0xFF030304)],
        ).createShader(Rect.fromLTRB(0, _ground, _w, _h)),
    );
    // Il bordo del marciapiede.
    canvas.drawRect(
      Rect.fromLTRB(-_w, _ground, _w * 2, _ground + _u * 0.022),
      Paint()..color = const Color(0xFF23242C),
    );

    // Il cono di luce del lampione, e la pozza di luce sull'asfalto bagnato.
    final flicker = 0.92 + 0.08 * sin(t * 140);
    canvas.drawPath(
      Path()
        ..moveTo(head.dx - _u * 0.05, head.dy)
        ..lineTo(head.dx + _u * 0.05, head.dy)
        ..lineTo(head.dx + _u * 1.25, _ground)
        ..lineTo(head.dx - _u * 0.80, _ground)
        ..close(),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_warm.withValues(alpha: 0.30 * flicker), _warm.withValues(alpha: 0.03)],
        ).createShader(Rect.fromLTRB(0, head.dy, _w, _ground)),
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(head.dx + _u * 0.22, _ground + _u * 0.06), width: _u * 2.3, height: _u * 0.20),
      Paint()
        ..color = _warm.withValues(alpha: 0.16 * flicker)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, _u * 0.06),
    );

    final iron = Paint()
      ..color = _ink
      ..strokeWidth = _u * 0.04
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(lampX, _ground), Offset(lampX, lampTop), iron);
    canvas.drawPath(
      Path()
        ..moveTo(lampX, lampTop)
        ..quadraticBezierTo(lampX + _u * 0.02, lampTop - _u * 0.11, head.dx, head.dy - _u * 0.045),
      iron,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(lampX, _ground - _u * 0.05), width: _u * 0.11, height: _u * 0.10),
        Radius.circular(_u * 0.02),
      ),
      Paint()..color = _ink,
    );
    canvas.drawCircle(head, _u * 0.05, Paint()..color = _warm.withValues(alpha: flicker));
    canvas.drawCircle(
      head,
      _u * 0.18,
      Paint()
        ..color = _warm.withValues(alpha: 0.35 * flicker)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, _u * 0.09),
    );
  }

  /// Il muro dietro cui aspetta il killer. Va disegnato dopo di lui: è così
  /// che lo si vede spuntare dall'angolo.
  void _wall(Canvas canvas) {
    if (!_hasWall) return;
    final wall = Rect.fromLTRB(_cornerX, -_h, _w * 2, _ground);
    canvas.drawRect(wall, Paint()..color = const Color(0xFF0A0A0D));
    final mortar = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 1;
    for (var y = _ground - _u * 0.14; y > -_u; y -= _u * 0.14) {
      canvas.drawLine(Offset(_cornerX, y), Offset(_w * 2, y), mortar);
    }
    canvas.drawLine(
      Offset(_cornerX, -_h),
      Offset(_cornerX, _ground),
      Paint()
        ..color = const Color(0xFF2E2F38)
        ..strokeWidth = 2,
    );
    // Un manifesto strappato, e più su una finestra accesa: qualcuno, lassù,
    // non ha visto niente.
    final poster = Rect.fromLTWH(_cornerX + _u * 0.07, _ground - _u * 1.00, _u * 0.20, _u * 0.27);
    canvas.drawRect(poster, Paint()..color = const Color(0xFF3A3326));
    canvas.drawCircle(poster.center.translate(0, -_u * 0.03), _u * 0.045, Paint()..color = const Color(0xFF15120D));
    canvas.drawRect(
      Rect.fromLTWH(poster.left + _u * 0.03, poster.bottom - _u * 0.07, _u * 0.14, _u * 0.025),
      Paint()..color = const Color(0xFF15120D),
    );
    final window = Rect.fromLTWH(_cornerX + _u * 0.09, _ground - _u * 1.80, _u * 0.20, _u * 0.28);
    canvas.drawRect(window, Paint()..color = _warm.withValues(alpha: 0.5 - 0.5 * _span(t, 0.60, 0.66)));
    final frame = Paint()
      ..color = _ink
      ..strokeWidth = 2;
    canvas.drawLine(window.topCenter, window.bottomCenter, frame);
    canvas.drawLine(window.centerLeft, window.centerRight, frame);
  }

  // ------------------------------------------------------------------- sagome

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

  /// Dove si piega il ginocchio, dati anca e piede: sempre in avanti.
  Offset _knee(Offset hip, Offset foot, double thigh, double shin) {
    final delta = foot - hip;
    final length = max(delta.distance, 0.001);
    final reach = min(length, thigh + shin - 0.001);
    final along = delta / length;
    final base = (thigh * thigh - shin * shin + reach * reach) / (2 * reach);
    final rise = sqrt(max(0.0, thigh * thigh - base * base));
    final middle = hip + along * base;
    final side = Offset(along.dy, -along.dx);
    final a = middle + side * rise;
    final b = middle - side * rise;
    return a.dx > b.dx ? a : b;
  }

  /// Una persona in soprabito, vista di profilo.
  ///
  /// [stride] da 0 (ferma) a 1 (passo pieno), con [walk] che fa avanzare il
  /// passo; [lean] piega il busto in avanti; [crouch] piega le ginocchia;
  /// [tilt] ruota tutta la figura intorno ai piedi. [arm] e [elbow] muovono
  /// il braccio davanti: 0 lungo il fianco, pi/2 teso in avanti, pi in alto.
  void _person(
    Canvas canvas, {
    required Offset feet,
    int facing = 1,
    double walk = 0,
    double stride = 0,
    double lean = 0,
    double crouch = 0,
    double tilt = 0,
    double arm = 0.08,
    double elbow = 0.20,
    double backArm = -0.10,
    double backElbow = 0.20,
    double dangle = double.nan,
    AvatarHead hat = AvatarHead.fedora,
    bool hatOn = true,
    _Prop prop = _Prop.none,
    bool killer = false,
  }) {
    final h = killer ? _u * 1.08 : _u;
    canvas.save();
    canvas.translate(feet.dx, feet.dy);
    canvas.rotate(tilt);
    canvas.scale(facing.toDouble(), 1);

    void body(Paint paint, {required bool details}) {
      final bob = stride * sin(walk * 2).abs() * h * 0.012;
      final hip = Offset(-h * 0.03 * crouch, -h * (0.50 - 0.13 * crouch) + bob);
      const thigh = 0.265;
      const shin = 0.265;

      Offset footAt(double phase, double rest) {
        if (!dangle.isNaN) return hip + _aim(dangle * (rest > 0 ? 1 : -0.7)) * (h * 0.50);
        if (stride <= 0) return Offset(rest * h, 0);
        final cycle = (phase / (2 * pi)) % 1;
        final reach = stride * h * 0.21;
        if (cycle < 0.5) return Offset(_mix(reach, -reach, cycle * 2), 0);
        final swing = (cycle - 0.5) * 2;
        return Offset(_mix(-reach, reach, _smooth(swing)), -sin(pi * swing) * h * 0.075 * stride);
      }

      void leg(Offset foot) {
        final knee = _knee(hip, foot, h * thigh, h * shin);
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

      leg(footAt(walk + pi, -0.055));
      leg(footAt(walk, 0.06));

      canvas.save();
      canvas.translate(hip.dx, hip.dy);
      canvas.rotate(lean);

      final swing = stride * sin(walk) * 0.45;
      final broad = killer ? 1.16 : 1.0;

      (Offset, Offset) armAt(Offset shoulder, double angle, double bend) {
        final joint = shoulder + _aim(angle) * (h * 0.185);
        final hand = joint + _aim(angle + bend) * (h * 0.175);
        _limb(canvas, shoulder, joint, h * 0.046, h * 0.038, paint);
        _limb(canvas, joint, hand, h * 0.038, h * 0.030, paint);
        canvas.drawCircle(hand, h * 0.034, paint);
        return (hand, _aim(angle + bend));
      }

      armAt(Offset(-h * 0.03 * broad, -h * 0.325), backArm - swing, backElbow);

      // Il soprabito: spalle larghe, vita segnata, la falda che si apre dietro.
      final flare = h * (0.04 + 0.05 * stride * (0.5 + 0.5 * sin(walk * 2)));
      canvas.drawPath(
        Path()
          ..moveTo(-h * 0.145 * broad, -h * 0.335)
          ..quadraticBezierTo(-h * 0.10 * broad, -h * 0.385, 0, -h * 0.385)
          ..quadraticBezierTo(h * 0.11 * broad, -h * 0.385, h * 0.135 * broad, -h * 0.325)
          ..quadraticBezierTo(h * 0.16 * broad, -h * 0.20, h * 0.11, -h * 0.085)
          ..quadraticBezierTo(h * 0.13, h * 0.08, h * 0.165, h * 0.215)
          ..lineTo(-h * 0.17 - flare, h * 0.215)
          ..quadraticBezierTo(-h * 0.15, h * 0.04, -h * 0.115, -h * 0.085)
          ..quadraticBezierTo(-h * 0.17 * broad, -h * 0.22, -h * 0.145 * broad, -h * 0.335)
          ..close(),
        paint,
      );

      // Il bavero alzato, il collo, la testa di profilo.
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
      if (hatOn) _hat(canvas, head, h, hat, paint, details: details, killer: killer);

      if (details && killer) {
        // La cravatta rossa: è lui.
        canvas.drawPath(
          Path()
            ..moveTo(h * 0.035, -h * 0.365)
            ..lineTo(h * 0.085, -h * 0.365)
            ..lineTo(h * 0.075, -h * 0.20)
            ..lineTo(h * 0.045, -h * 0.25)
            ..close(),
          Paint()..color = _blood,
        );
      }

      final (hand, along) = armAt(Offset(h * 0.035 * broad, -h * 0.325), arm + swing, elbow);
      if (details) _held(canvas, hand, along, h, prop);
      canvas.restore();
    }

    // Due passate: prima un filo di luce calda dal lato del lampione, poi il
    // nero sopra. È quel bordo che dà spessore alla sagoma.
    canvas.save();
    canvas.translate(-h * 0.016 * facing, -h * 0.010);
    body(Paint()..color = _rim, details: false);
    canvas.restore();
    body(Paint()..color = _ink, details: true);
    canvas.restore();
  }

  void _hat(Canvas canvas, Offset head, double h, AvatarHead hat, Paint paint, {required bool details, required bool killer}) {
    void band(double left, double right, double y) {
      if (!details) return;
      canvas.drawRect(
        Rect.fromLTRB(head.dx + h * left, head.dy + h * y, head.dx + h * right, head.dy + h * (y + 0.024)),
        Paint()..color = killer ? _blood : _rim,
      );
    }

    switch (hat) {
      case AvatarHead.fedora || AvatarHead.wideBrim:
        final wide = hat == AvatarHead.wideBrim;
        canvas.save();
        canvas.translate(head.dx + h * 0.02, head.dy - h * 0.050);
        canvas.rotate(0.10);
        canvas.drawOval(
          Rect.fromCenter(center: Offset.zero, width: h * (wide ? 0.44 : 0.33), height: h * 0.048),
          paint,
        );
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
        band(-0.084, 0.102, -0.082);
      case AvatarHead.bowler:
        canvas.drawOval(
          Rect.fromCenter(center: head.translate(h * 0.01, -h * 0.052), width: h * 0.27, height: h * 0.04),
          paint,
        );
        canvas.drawArc(
          Rect.fromCenter(center: head.translate(h * 0.005, -h * 0.052), width: h * 0.18, height: h * 0.22),
          pi,
          pi,
          true,
          paint,
        );
        band(-0.085, 0.095, -0.080);
      case AvatarHead.coppola:
        canvas.drawPath(
          Path()
            ..moveTo(head.dx - h * 0.090, head.dy - h * 0.045)
            ..quadraticBezierTo(head.dx - h * 0.080, head.dy - h * 0.125, head.dx + h * 0.020, head.dy - h * 0.115)
            ..quadraticBezierTo(head.dx + h * 0.100, head.dy - h * 0.100, head.dx + h * 0.165, head.dy - h * 0.040)
            ..lineTo(head.dx + h * 0.160, head.dy - h * 0.022)
            ..close(),
          paint,
        );
      case AvatarHead.slicked:
        canvas.drawArc(
          Rect.fromCenter(center: head.translate(-h * 0.008, -h * 0.012), width: h * 0.165, height: h * 0.180),
          pi * 0.95,
          pi * 1.05,
          true,
          paint,
        );
      case AvatarHead.bob:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(head.dx - h * 0.105, head.dy - h * 0.100, head.dx + h * 0.045, head.dy + h * 0.105),
            Radius.circular(h * 0.07),
          ),
          paint,
        );
      case AvatarHead.bun:
        canvas.drawCircle(head.translate(-h * 0.075, -h * 0.075), h * 0.048, paint);
        canvas.drawArc(
          Rect.fromCenter(center: head.translate(-h * 0.008, -h * 0.010), width: h * 0.165, height: h * 0.185),
          pi * 0.9,
          pi * 1.0,
          true,
          paint,
        );
    }
  }

  void _held(Canvas canvas, Offset hand, Offset along, double h, _Prop prop) {
    final across = Offset(-along.dy, along.dx);
    switch (prop) {
      case _Prop.none:
        break;
      case _Prop.knife:
        final tip = hand + along * (h * 0.24);
        canvas.drawPath(
          Path()
            ..moveTo(hand.dx + across.dx * h * 0.022, hand.dy + across.dy * h * 0.022)
            ..lineTo(tip.dx, tip.dy)
            ..lineTo(hand.dx - across.dx * h * 0.012, hand.dy - across.dy * h * 0.012)
            ..close(),
          Paint()..color = _steel,
        );
        canvas.drawLine(
          hand - across * (h * 0.035),
          hand + across * (h * 0.035),
          Paint()
            ..color = _gunmetal
            ..strokeWidth = h * 0.018
            ..strokeCap = StrokeCap.round,
        );
      case _Prop.pistol:
        final metal = Paint()
          ..color = _gunmetal
          ..strokeWidth = h * 0.045
          ..strokeCap = StrokeCap.square;
        canvas.drawLine(hand, hand + along * (h * 0.13), metal);
        canvas.drawLine(hand, hand - across * (h * 0.05), metal..strokeWidth = h * 0.035);
        canvas.drawLine(
          hand + across * (h * 0.012),
          hand + along * (h * 0.13) + across * (h * 0.012),
          Paint()
            ..color = _steel.withValues(alpha: 0.7)
            ..strokeWidth = h * 0.008,
        );
      case _Prop.tommy:
        final metal = Paint()
          ..color = _gunmetal
          ..strokeCap = StrokeCap.square;
        canvas.drawLine(hand - along * (h * 0.16), hand + along * (h * 0.30), metal..strokeWidth = h * 0.045);
        canvas.drawLine(hand + along * (h * 0.30), hand + along * (h * 0.40), metal..strokeWidth = h * 0.022);
        canvas.drawCircle(hand + along * (h * 0.13) - across * (h * 0.055), h * 0.052, Paint()..color = _gunmetal);
        canvas.drawCircle(
          hand + along * (h * 0.13) - across * (h * 0.055),
          h * 0.052,
          Paint()
            ..color = _steel.withValues(alpha: 0.5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = h * 0.008,
        );
      case _Prop.cup:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: hand.translate(h * 0.035, -h * 0.02), width: h * 0.065, height: h * 0.055),
            Radius.circular(h * 0.012),
          ),
          Paint()..color = AppColors.textPrimary,
        );
      case _Prop.box:
        final box = Rect.fromCenter(center: hand.translate(h * 0.06, -h * 0.02), width: h * 0.19, height: h * 0.15);
        canvas.drawRect(box, Paint()..color = const Color(0xFF7A1B22));
        final ribbon = Paint()
          ..color = AppColors.gold
          ..strokeWidth = h * 0.02;
        canvas.drawLine(box.topCenter, box.bottomCenter, ribbon);
        canvas.drawLine(box.centerLeft, box.centerRight, ribbon);
        canvas.drawCircle(box.topCenter.translate(-h * 0.02, -h * 0.015), h * 0.02, Paint()..color = AppColors.gold);
        canvas.drawCircle(box.topCenter.translate(h * 0.02, -h * 0.015), h * 0.02, Paint()..color = AppColors.gold);
    }
  }

  /// La vittima, in piedi o mentre crolla. [fall] va da 0 a 1: le ginocchia
  /// cedono, il corpo gira, e alla fine resta a terra, stesa verso [fallTo].
  void _victim(
    Canvas canvas, {
    required double x,
    int facing = 1,
    double walk = 0,
    double stride = 0,
    double fall = 0,
    int fallTo = -1,
    double lean = 0,
    double arm = 0.08,
    double elbow = 0.20,
    _Prop prop = _Prop.none,
  }) {
    if (fall >= 1) return _corpse(canvas, x, fallTo);
    if (fall <= 0) {
      return _person(
        canvas,
        feet: Offset(x, _ground),
        facing: facing,
        walk: walk,
        stride: stride,
        lean: lean,
        arm: arm,
        elbow: elbow,
        hat: victimHat,
        prop: prop,
      );
    }
    final buckle = Curves.easeOut.transform(min(1, fall * 1.6));
    final topple = Curves.easeIn.transform(fall);
    _person(
      canvas,
      feet: Offset(x, _ground),
      facing: facing,
      crouch: buckle * 0.95,
      tilt: fallTo * (0.10 * buckle + 1.20 * topple),
      lean: -facing * fallTo * 0.25 * buckle,
      arm: _mix(arm, 2.3, buckle),
      elbow: 0.7,
      backArm: -1.3 * buckle,
      hat: victimHat,
      hatOn: false,
    );
  }

  /// Il corpo a terra, con i piedi in [feetX] e la testa verso [toward].
  void _corpse(Canvas canvas, double feetX, int toward) {
    canvas.save();
    canvas.translate(feetX, _ground);
    canvas.scale(toward.toDouble(), 1);
    final u = _u;

    void body(Paint paint) {
      // Il soprabito aperto sull'asfalto, poi gambe, busto, braccia, testa.
      canvas.drawOval(Rect.fromLTRB(u * 0.20, -u * 0.07, u * 0.80, u * 0.01), paint);
      _limb(canvas, Offset(u * 0.06, -u * 0.05), Offset(u * 0.36, -u * 0.07), u * 0.036, u * 0.056, paint);
      _limb(canvas, Offset(u * 0.02, -u * 0.04), Offset(u * 0.20, -u * 0.17), u * 0.034, u * 0.046, paint);
      _limb(canvas, Offset(u * 0.20, -u * 0.17), Offset(u * 0.36, -u * 0.07), u * 0.046, u * 0.056, paint);
      for (final x in [0.0, 0.055]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(u * (x - 0.025), -u * 0.135, u * (x + 0.03), -u * 0.01),
            Radius.circular(u * 0.025),
          ),
          paint,
        );
      }
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTRB(u * 0.32, -u * 0.165, u * 0.70, -u * 0.012), Radius.circular(u * 0.075)),
        paint,
      );
      _limb(canvas, Offset(u * 0.62, -u * 0.09), Offset(u * 0.48, -u * 0.02), u * 0.044, u * 0.032, paint);
      _limb(canvas, Offset(u * 0.64, -u * 0.07), Offset(u * 0.90, -u * 0.025), u * 0.044, u * 0.030, paint);
      final head = Offset(u * 0.77, -u * 0.085);
      canvas.drawCircle(head, u * 0.078, paint);
      canvas.drawPath(
        Path()
          ..moveTo(head.dx - u * 0.02, head.dy - u * 0.07)
          ..lineTo(head.dx + u * 0.02, head.dy - u * 0.115)
          ..lineTo(head.dx + u * 0.04, head.dy - u * 0.06)
          ..close(),
        paint,
      );
    }

    canvas.save();
    canvas.translate(-u * 0.012 * toward, -u * 0.014);
    body(Paint()..color = _rim);
    canvas.restore();
    body(Paint()..color = _ink);
    canvas.restore();
  }

  /// Un cappello caduto, che rotola o resta lì.
  void _looseHat(Canvas canvas, Offset center, double spin) {
    final ink = Paint()..color = _ink;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(spin);
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: _u * 0.33, height: _u * 0.055), ink);
    canvas.drawPath(
      Path()
        ..moveTo(-_u * 0.09, 0)
        ..quadraticBezierTo(-_u * 0.10, -_u * 0.12, -_u * 0.04, -_u * 0.12)
        ..quadraticBezierTo(_u * 0.005, -_u * 0.09, _u * 0.05, -_u * 0.125)
        ..quadraticBezierTo(_u * 0.10, -_u * 0.11, _u * 0.095, 0)
        ..close(),
      ink,
    );
    canvas.drawRect(Rect.fromLTRB(-_u * 0.09, -_u * 0.04, _u * 0.095, -_u * 0.014), Paint()..color = _rim);
    canvas.restore();
  }

  void _shoes(Canvas canvas, double x) {
    final ink = Paint()..color = _ink;
    for (final dx in [-0.12, 0.05]) {
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTRB(x + _u * dx, _ground - _u * 0.05, x + _u * (dx + 0.15), _ground),
          topLeft: Radius.circular(_u * 0.02),
          topRight: Radius.circular(_u * 0.045),
        ),
        ink,
      );
    }
  }

  // -------------------------------------------------------------------- effetti

  /// Schizzi che partono da [origin], volano secondo [bias] e ricadono.
  void _spray(
    Canvas canvas,
    Offset origin,
    double life, {
    required int seed,
    Color color = _blood,
    int count = 16,
    Offset bias = const Offset(-0.5, -0.9),
    double reach = 1,
  }) {
    if (life <= 0 || life >= 1) return;
    final rng = Random(seed);
    final paint = Paint();
    for (var i = 0; i < count; i++) {
      final angle = rng.nextDouble() * 2 * pi;
      final speed = (0.35 + rng.nextDouble() * 0.65) * _u * 0.9 * reach;
      final direction = Offset(cos(angle), sin(angle)) * 0.55 + bias;
      final position = origin + direction * (speed * life) + Offset(0, _u * 1.3 * life * life);
      paint.color = color.withValues(alpha: (1 - life * life).clamp(0.0, 1.0));
      canvas.drawCircle(position, _u * (0.012 + rng.nextDouble() * 0.022) * (1 - life * 0.4), paint);
    }
  }

  void _pool(Canvas canvas, Offset center, double grown) {
    if (grown <= 0) return;
    canvas.drawOval(
      Rect.fromCenter(center: center, width: _u * 0.95 * grown, height: _u * 0.11 * grown),
      Paint()..color = _blood.withValues(alpha: 0.9),
    );
  }

  void _puff(Canvas canvas, Offset center, double life, {double size = 1, Color color = const Color(0xFF8E8A86)}) {
    if (life <= 0 || life >= 1) return;
    final paint = Paint()
      ..color = color.withValues(alpha: 0.5 * (1 - life))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, _u * 0.05);
    for (final (dx, dy, r) in [(-0.22, 0.0, 0.16), (0.0, -0.08, 0.22), (0.24, 0.02, 0.15)]) {
      canvas.drawCircle(
        center + Offset(dx * (1 + life), dy - life * 0.25) * (_u * size),
        _u * r * size * (0.6 + life),
        paint,
      );
    }
  }

  void _flash(Canvas canvas, double life, {double strength = 0.8}) {
    if (life <= 0 || life >= 1) return;
    canvas.drawRect(
      Rect.fromLTWH(-_w, -_h, _w * 3, _h * 3),
      Paint()..color = Colors.white.withValues(alpha: strength * (1 - life) * (1 - life)),
    );
  }

  void _star(Canvas canvas, Offset center, double radius, Color color) {
    final path = Path();
    for (var i = 0; i < 16; i++) {
      final r = i.isEven ? radius : radius * 0.42;
      final point = center + Offset(cos(i * pi / 8), sin(i * pi / 8)) * r;
      i == 0 ? path.moveTo(point.dx, point.dy) : path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path..close(), Paint()..color = color);
  }

  // ---------------------------------------------------------------- canovaccio

  /// La vittima entra e si ferma sotto il lampione: posizione, fase del
  /// passo e ampiezza (zero quando è ferma).
  (double, double, double) _entrance() {
    final walk = _span(t, 0.04, 0.34);
    final slowing = 1 - Curves.easeIn.transform(_span(t, 0.30, 0.34));
    return (_mix(-_w * 0.25, _victimX, walk), walk * 9 * pi, walk < 1 ? slowing.clamp(0.25, 1.0) : 0.0);
  }

  /// Il killer che, a cose fatte, si affaccia dall'angolo e si tocca il cappello.
  void _killerSalute(Canvas canvas) {
    final out = _smooth(_span(t, 0.69, 0.75)) - _smooth(_span(t, 0.82, 0.86));
    if (out <= 0) return;
    _person(
      canvas,
      feet: Offset(_mix(_hiddenX, _cornerX - _u * 0.16, out), _ground),
      facing: -1,
      arm: _mix(0.1, 2.35, out),
      elbow: _mix(0.2, 1.25, out),
      killer: true,
    );
  }

  /// Un passo felpato, per chi si avvicina o se ne va.
  double get _prowl => t * 230;

  // ---------------------------------------------------------------- coreografie

  void _knife(Canvas canvas) {
    final (walkX, walk, stride) = _entrance();
    final peek = _smooth(_span(t, 0.38, 0.46));
    final dash = Curves.easeIn.transform(_span(t, 0.49, strike));
    final leave = _smooth(_span(t, 0.70, 0.84));
    final killerX = _mix(_mix(_mix(_hiddenX, _peekX, peek), _victimX + _u * 0.42, dash), _hiddenX, leave);
    final running = (dash > 0 && dash < 1) || (leave > 0 && leave < 1);
    final raise = _span(t, 0.46, 0.53);
    final blow = _span(t, strike, strike + 0.03);

    _person(
      canvas,
      feet: Offset(killerX, _ground),
      facing: leave > 0.08 ? 1 : -1,
      walk: _prowl,
      stride: running ? 1 : 0,
      lean: leave > 0 ? 0.08 : 0.16 * dash + 0.25 * sin(pi * blow),
      crouch: 0.18 * dash * (1 - leave),
      arm: leave > 0 ? 0.1 : _mix(_mix(0.3, 2.85, raise), 1.35, blow),
      elbow: leave > 0 ? 0.2 : _mix(0.9, 0.1, blow),
      prop: _Prop.knife,
      killer: true,
    );
    _wall(canvas);

    final fall = _span(t, strike + 0.02, strike + 0.13);
    _pool(canvas, Offset(_victimX - _u * 0.50, _ground + _u * 0.04), _smooth(_span(t, 0.67, 0.84)));
    _victim(
      canvas,
      x: walkX,
      facing: t < 0.37 ? 1 : -1,
      walk: walk,
      stride: stride,
      fall: fall,
    );
    if (fall > 0.12) {
      final flight = _span(t, strike + 0.03, 0.78);
      _looseHat(
        canvas,
        Offset(_victimX - _u * (0.30 + 0.95 * flight), _ground - _u * 0.03 - _u * 0.9 * sin(pi * min(1, flight * 1.6)) * (1 - flight)),
        flight < 1 ? -flight * 9 : -0.2,
      );
    }

    // Il lampo della lama, e quello che ne segue.
    if (blow > 0 && blow < 1) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(_victimX + _u * 0.22, _ground - _u * 0.72), radius: _u * 0.46),
        pi * 0.92,
        pi * 0.62 * blow,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _u * 0.035
          ..strokeCap = StrokeCap.round
          ..color = Colors.white.withValues(alpha: 1 - blow),
      );
    }
    _spray(canvas, Offset(_victimX, _ground - _u * 0.74), _span(t, strike, strike + 0.20), seed: 3, count: 20);
    _flash(canvas, _span(t, strike, strike + 0.04), strength: 0.35);
  }

  void _shooting(Canvas canvas, List<double> shots, _Prop weapon) {
    final (walkX, walk, stride) = _entrance();
    final last = shots.last;
    final peek = _smooth(_span(t, 0.38, 0.46));
    final out = _smooth(_span(t, 0.46, 0.53));
    final leave = _smooth(_span(t, last + 0.12, last + 0.25));
    final killerX = _mix(_mix(_mix(_hiddenX, _peekX, peek), _cornerX - _u * 0.10, out), _hiddenX, leave);

    var kick = 0.0;
    var jolt = 0.0;
    for (final shot in shots) {
      final bang = _span(t, shot, shot + 0.025);
      if (bang > 0 && bang < 1) {
        kick = sin(pi * bang);
        jolt = sin(pi * bang);
      }
    }

    final twoHands = weapon == _Prop.tommy;
    _person(
      canvas,
      feet: Offset(killerX, _ground),
      facing: leave > 0.08 ? 1 : -1,
      walk: _prowl,
      stride: (out > 0 && out < 1) || (leave > 0 && leave < 1) ? 0.8 : 0,
      lean: leave > 0 ? 0.05 : 0.10 * out - 0.05 * kick,
      arm: leave > 0 ? 0.1 : _mix(0.2, twoHands ? 1.25 : pi / 2, out) + 0.16 * kick,
      elbow: leave > 0 ? 0.2 : (twoHands ? 0.42 : 0.03),
      backArm: leave > 0 ? -0.1 : (twoHands ? _mix(-0.1, 1.45, out) : -0.1),
      backElbow: twoHands ? 0.25 : 0.2,
      prop: weapon,
      killer: true,
    );
    _wall(canvas);

    final fall = _span(t, last + 0.02, last + 0.13);
    _pool(canvas, Offset(_victimX - _u * 0.50, _ground + _u * 0.04), _smooth(_span(t, last + 0.11, last + 0.28)));
    _victim(
      canvas,
      x: walkX,
      facing: t < 0.37 ? 1 : -1,
      walk: walk,
      stride: stride,
      fall: fall,
      lean: 0.20 * jolt,
    );
    if (fall > 0.12) {
      final flight = _span(t, last + 0.03, last + 0.24);
      _looseHat(
        canvas,
        Offset(_victimX - _u * (0.30 + 0.90 * flight), _ground - _u * 0.03 - _u * 0.8 * sin(pi * min(1, flight * 1.6)) * (1 - flight)),
        flight < 1 ? -flight * 8 : -0.2,
      );
    }

    final killerHeight = _u * 1.08;
    final muzzle = Offset(
      killerX - killerHeight * (twoHands ? 0.74 : 0.56),
      _ground - killerHeight * (twoHands ? 0.74 : 0.83),
    );
    for (var i = 0; i < shots.length; i++) {
      final bang = _span(t, shots[i], shots[i] + 0.025);
      if (bang > 0 && bang < 1) {
        _star(canvas, muzzle, _u * 0.24 * (1 - bang * 0.5), const Color(0xFFFFF3C4).withValues(alpha: 1 - bang));
        canvas.drawLine(
          muzzle,
          Offset(_victimX + _u * 0.08, _ground - _u * 0.72),
          Paint()
            ..color = _warm.withValues(alpha: 0.85 * (1 - bang))
            ..strokeWidth = _u * 0.014,
        );
      }
      _flash(canvas, bang, strength: 0.4);
      _spray(
        canvas,
        Offset(_victimX, _ground - _u * 0.74),
        _span(t, shots[i], shots[i] + 0.16),
        seed: 20 + i,
        count: 9,
      );
    }
    // Il filo di fumo dalla canna.
    final smoke = _span(t, last + 0.02, last + 0.12);
    if (smoke > 0 && smoke < 1) {
      _puff(canvas, muzzle.translate(0, -_u * 0.25 * smoke), smoke, size: 0.4);
    }
  }

  void _car(Canvas canvas) {
    final (walkX, walk, stride) = _entrance();
    final drive = _span(t, 0.47, 0.66);
    final frontX = _mix(-_w * 0.35, _w * 2.4, Curves.easeIn.transform(drive));
    final hit = frontX >= _victimX;

    // Prima i fari, in fondo alla strada, da dove la vittima è arrivata.
    final glare = _span(t, 0.38, 0.50) * (1 - _span(t, 0.50, 0.56));
    if (glare > 0) {
      canvas.drawCircle(
        Offset(-_u * 0.1, _ground - _u * 0.30),
        _u * (0.3 + 0.9 * glare),
        Paint()
          ..color = _warm.withValues(alpha: 0.55 * glare)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, _u * 0.25),
      );
    }

    if (!hit) {
      final alarm = _span(t, 0.47, 0.52);
      _victim(
        canvas,
        x: walkX,
        facing: t < 0.43 ? 1 : -1,
        walk: walk,
        stride: stride,
        lean: -0.14 * alarm,
        arm: _mix(0.08, 2.1, alarm),
        elbow: _mix(0.2, 0.9, alarm),
      );
    } else {
      // La vittima vola via, e restano le scarpe.
      final flight = _span(t, strike - 0.02, 0.72);
      if (flight < 1) {
        final arc = sin(pi * flight);
        _person(
          canvas,
          feet: Offset(_victimX + _u * 2.6 * flight, _ground - _u * (0.2 + 2.2 * arc)),
          facing: -1,
          tilt: flight * 11,
          arm: 2.6,
          elbow: 0.3,
          backArm: -2.2,
          crouch: 0.5,
          hat: victimHat,
          hatOn: false,
        );
      }
      _shoes(canvas, _victimX);
      final hatFlight = _span(t, strike - 0.02, 0.86);
      _looseHat(
        canvas,
        Offset(_victimX + _u * 0.9 * hatFlight, _ground - _u * 0.04 - _u * 2.0 * sin(pi * min(1, hatFlight * 1.15)) * (1 - hatFlight * 0.3)),
        hatFlight < 1 ? hatFlight * 14 : 0,
      );
      _puff(canvas, Offset(_victimX + _u * 0.3, _ground - _u * 0.05), _span(t, strike, 0.74), size: 1.2);
    }

    if (drive > 0 && drive < 1) _sedan(canvas, frontX);
    // I segni della frenata che non c'è stata.
    if (hit) {
      final marks = Paint()
        ..color = Colors.black.withValues(alpha: 0.6)
        ..strokeWidth = _u * 0.02;
      for (final dy in [0.04, 0.10]) {
        canvas.drawLine(
          Offset(_victimX - _u * 0.4, _ground + _u * dy),
          Offset(min(frontX, _w + 40), _ground + _u * dy),
          marks,
        );
      }
    }
    _flash(canvas, _span(t, strike - 0.03, strike + 0.07), strength: 0.95);
  }

  void _sedan(Canvas canvas, double front) {
    final ink = Paint()..color = _ink;
    final length = _u * 2.1;
    final back = front - length;
    final base = _ground - _u * 0.08;

    final lamp = Offset(front - _u * 0.03, _ground - _u * 0.34);
    canvas.drawPath(
      Path()
        ..moveTo(lamp.dx, lamp.dy)
        ..lineTo(lamp.dx + _u * 2.6, lamp.dy - _u * 0.40)
        ..lineTo(lamp.dx + _u * 2.6, _ground + _u * 0.04)
        ..close(),
      Paint()
        ..shader = LinearGradient(
          colors: [_warm.withValues(alpha: 0.55), _warm.withValues(alpha: 0)],
        ).createShader(Rect.fromLTWH(lamp.dx, lamp.dy - _u * 0.4, _u * 2.6, _u * 0.5)),
    );

    // La carrozzeria: cofano lungo, tetto tondo, parafanghi gonfi.
    canvas.drawPath(
      Path()
        ..moveTo(back + _u * 0.05, base)
        ..quadraticBezierTo(back - _u * 0.03, _ground - _u * 0.42, back + _u * 0.22, _ground - _u * 0.46)
        ..quadraticBezierTo(back + _u * 0.42, _ground - _u * 0.86, back + _u * 0.82, _ground - _u * 0.86)
        ..quadraticBezierTo(back + _u * 1.15, _ground - _u * 0.86, back + _u * 1.32, _ground - _u * 0.52)
        ..quadraticBezierTo(back + _u * 1.80, _ground - _u * 0.52, front - _u * 0.04, _ground - _u * 0.40)
        ..quadraticBezierTo(front + _u * 0.03, _ground - _u * 0.30, front, base)
        ..close(),
      ink,
    );
    canvas.drawPath(
      Path()
        ..moveTo(back + _u * 0.50, _ground - _u * 0.52)
        ..quadraticBezierTo(back + _u * 0.58, _ground - _u * 0.78, back + _u * 0.84, _ground - _u * 0.78)
        ..quadraticBezierTo(back + _u * 1.06, _ground - _u * 0.78, back + _u * 1.20, _ground - _u * 0.52)
        ..close(),
      Paint()..color = const Color(0xFF3B4658),
    );
    canvas.drawLine(
      Offset(back + _u * 0.86, _ground - _u * 0.78),
      Offset(back + _u * 0.86, _ground - _u * 0.52),
      Paint()
        ..color = _ink
        ..strokeWidth = _u * 0.03,
    );
    for (final x in [back + _u * 0.38, front - _u * 0.36]) {
      canvas.drawCircle(Offset(x, _ground - _u * 0.15), _u * 0.21, ink);
      canvas.drawCircle(Offset(x, _ground - _u * 0.13), _u * 0.13, Paint()..color = const Color(0xFF17181C));
      canvas.drawCircle(Offset(x, _ground - _u * 0.13), _u * 0.055, Paint()..color = _steel.withValues(alpha: 0.7));
    }
    canvas.drawCircle(lamp, _u * 0.06, Paint()..color = const Color(0xFFFFF3C4));
    // Le righe della velocità.
    final streak = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..strokeWidth = _u * 0.012;
    for (final (dy, len) in [(0.70, 1.0), (0.48, 1.5), (0.24, 0.8)]) {
      canvas.drawLine(
        Offset(back - _u * 0.15, _ground - _u * dy),
        Offset(back - _u * (0.15 + len), _ground - _u * dy),
        streak,
      );
    }
  }

  void _fallingObject(Canvas canvas) {
    final (walkX, walk, stride) = _entrance();
    final drop = Curves.easeIn.transform(_span(t, 0.46, strike));
    final landed = t >= strike;
    final bottom = _mix(-_u * 2.2, _ground, drop);

    _killerSalute(canvas);
    _wall(canvas);

    // L'ombra che si allarga: la vittima se ne accorge un attimo troppo tardi.
    final shadow = _span(t, 0.40, strike);
    if (shadow > 0 && !landed) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(_victimX, _ground + _u * 0.04),
          width: _u * (0.3 + 1.1 * shadow),
          height: _u * 0.12 * (0.4 + shadow),
        ),
        Paint()..color = Colors.black.withValues(alpha: 0.6 * shadow),
      );
    }

    if (!landed) {
      final alarm = _span(t, 0.49, 0.53);
      _victim(
        canvas,
        x: walkX,
        walk: walk,
        stride: stride,
        lean: -0.16 * alarm,
        arm: _mix(0.08, 2.75, alarm),
        elbow: _mix(0.2, 0.5, alarm),
      );
      if (alarm > 0) {
        final mark = TextPainter(
          text: TextSpan(
            text: '!',
            style: TextStyle(
              fontFamily: 'Georgia',
              fontSize: _u * 0.34,
              fontWeight: FontWeight.w900,
              color: AppColors.gold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        mark.paint(canvas, Offset(_victimX + _u * 0.20, _ground - _u * 1.52));
      }
    } else {
      // Sotto resta poco: due gambe che spuntano, e un cappello che rotola via.
      final ink = Paint()..color = _ink;
      for (final dy in [0.04, 0.12]) {
        _limb(
          canvas,
          Offset(_victimX - _u * 0.36, _ground - _u * dy),
          Offset(_victimX - _u * 0.80, _ground - _u * dy),
          _u * 0.05,
          _u * 0.038,
          ink,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(_victimX - _u * 0.87, _ground - _u * (dy + 0.10), _u * 0.07, _u * 0.14),
            Radius.circular(_u * 0.03),
          ),
          ink,
        );
      }
      final roll = _span(t, strike, 0.80);
      _looseHat(canvas, Offset(_victimX - _u * (0.95 + 0.6 * roll), _ground - _u * 0.03), -roll * 9);
    }

    switch (act) {
      case DeathAct.safe:
        _safeShape(canvas, bottom);
      case DeathAct.chandelier:
        _chandelierShape(canvas, bottom, landed);
      default:
        _pianoShape(canvas, bottom);
    }
    if (!landed && drop > 0) {
      final rush = Paint()
        ..color = Colors.white.withValues(alpha: 0.3)
        ..strokeWidth = _u * 0.012;
      for (final dx in [-0.42, -0.1, 0.25, 0.45]) {
        canvas.drawLine(
          Offset(_victimX + _u * dx, bottom - _u * 1.05),
          Offset(_victimX + _u * dx, bottom - _u * 1.55),
          rush,
        );
      }
    }

    final dust = _span(t, strike, strike + 0.22);
    _puff(canvas, Offset(_victimX - _u * 0.6, _ground - _u * 0.05), dust, size: 1.3);
    _puff(canvas, Offset(_victimX + _u * 0.6, _ground - _u * 0.05), dust, size: 1.3);
    if (act == DeathAct.chandelier) {
      _spray(
        canvas,
        Offset(_victimX, _ground - _u * 0.2),
        _span(t, strike, strike + 0.22),
        seed: 8,
        color: const Color(0xFFFFF3C4),
        count: 26,
        bias: const Offset(0, -1.0),
        reach: 1.3,
      );
    }
    _flash(canvas, _span(t, strike, strike + 0.05), strength: 0.5);
  }

  void _pianoShape(Canvas canvas, double bottom) {
    final ink = Paint()..color = _ink;
    final x = _victimX;
    for (final dx in [-0.50, 0.06, 0.52]) {
      _limb(canvas, Offset(x + _u * dx, bottom - _u * 0.34), Offset(x + _u * dx, bottom - _u * 0.02), _u * 0.035, _u * 0.02, ink);
    }
    // La cassa a coda, il coperchio alzato, la tastiera.
    canvas.drawPath(
      Path()
        ..moveTo(x - _u * 0.64, bottom - _u * 0.30)
        ..lineTo(x - _u * 0.64, bottom - _u * 0.56)
        ..quadraticBezierTo(x - _u * 0.20, bottom - _u * 0.66, x + _u * 0.20, bottom - _u * 0.64)
        ..quadraticBezierTo(x + _u * 0.66, bottom - _u * 0.62, x + _u * 0.64, bottom - _u * 0.40)
        ..quadraticBezierTo(x + _u * 0.62, bottom - _u * 0.30, x + _u * 0.50, bottom - _u * 0.30)
        ..close(),
      ink,
    );
    canvas.drawPath(
      Path()
        ..moveTo(x - _u * 0.42, bottom - _u * 0.62)
        ..lineTo(x + _u * 0.58, bottom - _u * 1.10)
        ..lineTo(x + _u * 0.62, bottom - _u * 0.60)
        ..close(),
      ink,
    );
    canvas.drawLine(
      Offset(x + _u * 0.30, bottom - _u * 0.62),
      Offset(x + _u * 0.44, bottom - _u * 1.02),
      Paint()
        ..color = _ink
        ..strokeWidth = _u * 0.018,
    );
    canvas.drawRect(
      Rect.fromLTRB(x - _u * 0.64, bottom - _u * 0.44, x - _u * 0.40, bottom - _u * 0.385),
      Paint()..color = AppColors.textPrimary,
    );
    for (var i = 1; i < 6; i++) {
      canvas.drawRect(
        Rect.fromLTWH(x - _u * 0.64 + i * _u * 0.04 - _u * 0.008, bottom - _u * 0.44, _u * 0.016, _u * 0.032),
        ink,
      );
    }
  }

  void _safeShape(Canvas canvas, double bottom) {
    final box = Rect.fromLTRB(_victimX - _u * 0.44, bottom - _u * 0.88, _victimX + _u * 0.44, bottom);
    canvas.drawRRect(RRect.fromRectAndRadius(box, Radius.circular(_u * 0.04)), Paint()..color = const Color(0xFF0C0D10));
    final brass = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = _u * 0.022;
    canvas.drawRRect(RRect.fromRectAndRadius(box.deflate(_u * 0.07), Radius.circular(_u * 0.03)), brass);
    final dial = box.center.translate(-_u * 0.08, 0);
    canvas.drawCircle(dial, _u * 0.12, brass);
    for (var i = 0; i < 8; i++) {
      final spoke = Offset(cos(i * pi / 4), sin(i * pi / 4));
      canvas.drawLine(dial + spoke * (_u * 0.09), dial + spoke * (_u * 0.12), brass);
    }
    canvas.drawLine(dial, dial.translate(0, -_u * 0.08), brass);
    canvas.drawLine(box.center.translate(_u * 0.18, -_u * 0.10), box.center.translate(_u * 0.18, _u * 0.10), brass);
    for (final corner in [box.topLeft, box.topRight, box.bottomLeft, box.bottomRight]) {
      canvas.drawCircle(Offset.lerp(corner, box.center, 0.10)!, _u * 0.014, Paint()..color = AppColors.gold);
    }
  }

  void _chandelierShape(Canvas canvas, double bottom, bool landed) {
    final x = _victimX;
    final ink = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = _u * 0.04
      ..strokeCap = StrokeCap.round;
    if (!landed) canvas.drawLine(Offset(x, bottom - _u * 0.85), Offset(x, bottom - _u * 2.6), ink);
    final squash = landed ? 0.55 : 1.0;
    for (final (width, lift) in [(1.30, 0.20), (0.94, 0.44), (0.56, 0.66)]) {
      final y = bottom - _u * lift * squash;
      canvas.drawArc(
        Rect.fromCenter(center: Offset(x, y - _u * 0.10), width: _u * width, height: _u * 0.36 * squash),
        0,
        pi,
        false,
        ink,
      );
      for (var i = 0; i < 6; i++) {
        final cx = x - _u * width / 2 + _u * width * i / 5;
        final candle = Offset(cx, y - _u * 0.12);
        canvas.drawCircle(candle, _u * 0.03, Paint()..color = _warm.withValues(alpha: landed ? 0.25 : 0.95));
        if (!landed) {
          canvas.drawCircle(
            candle,
            _u * 0.07,
            Paint()
              ..color = _warm.withValues(alpha: 0.25)
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, _u * 0.03),
          );
        }
      }
    }
  }

  void _blast(Canvas canvas) {
    final (walkX, walk, stride) = _entrance();
    final boom = _span(t, strike, strike + 0.12);
    final gone = t >= strike;
    final centre = Offset(_victimX + _u * 0.15, _ground - _u * 0.55);

    _killerSalute(canvas);
    _wall(canvas);

    // La bruciatura resta sull'asfalto.
    if (gone) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(_victimX, _ground + _u * 0.04), width: _u * 1.6, height: _u * 0.18),
        Paint()..color = Colors.black.withValues(alpha: 0.8),
      );
    }

    if (!gone) {
      final curious = _smooth(_span(t, 0.36, 0.44));
      _victim(
        canvas,
        x: walkX,
        walk: walk,
        stride: stride,
        lean: 0.10 * curious,
        arm: _mix(0.5, 1.15, curious),
        elbow: _mix(0.6, 0.9, curious),
        prop: _Prop.box,
      );
      // La miccia sfrigola: chi guarda capisce prima della vittima.
      final fuse = _span(t, 0.40, strike);
      if (fuse > 0) {
        _star(
          canvas,
          Offset(_victimX + _u * 0.40, _ground - _u * 0.60),
          _u * (0.05 + 0.04 * sin(t * 500).abs()),
          const Color(0xFFFFF3C4).withValues(alpha: 0.6 + 0.4 * sin(t * 380).abs()),
        );
      }
    }

    if (boom > 0 && boom < 1) {
      final grow = Curves.easeOut.transform(boom);
      for (final (scale, color) in [
        (1.0, Color(0xFFFF6A2B)),
        (0.72, Color(0xFFFFB13B)),
        (0.42, Color(0xFFFFF3C4)),
      ]) {
        canvas.drawCircle(
          centre,
          _u * 1.5 * grow * scale,
          Paint()
            ..color = color.withValues(alpha: (1 - boom) * 0.95)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, _u * 0.05),
        );
      }
      _spray(canvas, centre, boom, seed: 5, color: const Color(0xFFFFB13B), count: 28, bias: Offset.zero, reach: 2.2);
    }
    // Il fumo sale, e alla fine dal cielo torna giù il cappello.
    for (var i = 0; i < 5; i++) {
      final life = _span(t, strike + 0.04 + i * 0.025, 0.86 + i * 0.02);
      _puff(
        canvas,
        centre + Offset((i - 2) * _u * 0.22, -_u * (0.2 + 1.3 * life) - i * _u * 0.05),
        life,
        size: 1.5,
        color: const Color(0xFF3A3836),
      );
    }
    final fallBack = _span(t, 0.68, 0.80);
    if (fallBack > 0) {
      _looseHat(
        canvas,
        Offset(_victimX - _u * 0.2, _mix(-_u * 1.4, _ground - _u * 0.03, Curves.easeIn.transform(fallBack))),
        fallBack < 1 ? fallBack * 9 : 0.2,
      );
      _shoes(canvas, _victimX + _u * 0.15);
    }
    _flash(canvas, _span(t, strike, strike + 0.08), strength: 1);
  }

  void _poison(Canvas canvas) {
    final (walkX, walk, stride) = _entrance();
    final sip = _smooth(_span(t, 0.37, 0.44)) - _smooth(_span(t, 0.48, 0.52));
    final queasy = _span(t, 0.50, strike + 0.04);
    final fall = _span(t, strike + 0.04, strike + 0.16);
    final dropped = t >= strike;

    _killerSalute(canvas);
    _wall(canvas);

    _victim(
      canvas,
      x: walkX,
      walk: walk,
      stride: stride,
      fall: fall,
      lean: queasy > 0 ? sin(t * 110) * 0.16 * queasy : 0,
      arm: dropped ? 2.5 : _mix(0.9, 2.0, sip),
      elbow: dropped ? 1.1 : _mix(0.5, 1.2, sip),
      prop: dropped || t < 0.34 ? _Prop.none : _Prop.cup,
    );
    if (fall > 0.12) {
      final flight = _span(t, strike + 0.07, 0.82);
      _looseHat(canvas, Offset(_victimX - _u * (0.30 + 0.90 * flight), _ground - _u * 0.03), flight < 1 ? -flight * 7 : -0.2);
    }

    // La tazzina cade, va in pezzi, e quello che c'era dentro non era caffè.
    if (dropped) {
      final tumble = Curves.easeIn.transform(_span(t, strike, strike + 0.04));
      final spot = Offset(_victimX + _u * 0.36, _ground - _u * 0.02);
      if (tumble < 1) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(spot.dx, _mix(_ground - _u * 0.98, spot.dy, tumble)), width: _u * 0.065, height: _u * 0.055),
            Radius.circular(_u * 0.012),
          ),
          Paint()..color = AppColors.textPrimary,
        );
      } else {
        _spray(canvas, spot, _span(t, strike + 0.04, strike + 0.16), seed: 4, color: AppColors.textPrimary, count: 8, bias: const Offset(0, -0.6), reach: 0.5);
        canvas.drawOval(
          Rect.fromCenter(center: spot.translate(0, _u * 0.06), width: _u * 0.46 * _span(t, strike + 0.04, 0.80), height: _u * 0.055),
          Paint()..color = const Color(0xFF6FBF4A).withValues(alpha: 0.85),
        );
      }
    }
  }

  void _noose(Canvas canvas) {
    final (walkX, walk, stride) = _entrance();
    final lower = Curves.easeOut.transform(_span(t, 0.37, 0.52));
    final hoist = _smooth(_span(t, strike, strike + 0.12));
    final lift = hoist * _u * 0.60;
    final calm = _span(t, 0.66, 0.86);
    final sway = sin(t * 26) * 0.12 * hoist * (1 - calm * 0.6);
    final caught = t >= strike - 0.02;

    _killerSalute(canvas);
    _wall(canvas);

    final neck = Offset(_victimX + sin(sway) * _u * 0.85, _ground - lift - _u * 0.88);
    final rope = Paint()
      ..color = const Color(0xFFC9B48A)
      ..strokeWidth = _u * 0.024
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final end = caught ? neck : Offset(_victimX, _mix(-_u * 1.2, _ground - _u * 1.20, lower));
    canvas.drawLine(Offset(_victimX, -_h), end, rope);
    canvas.drawOval(
      Rect.fromCenter(
        center: end.translate(0, caught ? 0 : _u * 0.11),
        width: _u * (caught ? 0.17 : 0.24),
        height: _u * (caught ? 0.07 : 0.26),
      ),
      rope,
    );

    if (hoist > 0) {
      _person(
        canvas,
        feet: Offset(walkX + sin(sway) * _u * 0.2, _ground - lift),
        tilt: sway,
        dangle: sin(t * 95) * 0.75 * (1 - calm) + 0.12,
        arm: 2.55,
        elbow: 1.5,
        backArm: 2.3,
        backElbow: 1.6,
        hat: victimHat,
        hatOn: hoist < 0.2,
      );
      if (hoist >= 0.2) {
        final dropHat = Curves.easeIn.transform(_span(t, strike + 0.03, strike + 0.10));
        _looseHat(
          canvas,
          Offset(_victimX - _u * 0.40 * dropHat, _mix(_ground - lift - _u, _ground - _u * 0.03, dropHat)),
          dropHat < 1 ? dropHat * 5 : 0.15,
        );
      }
    } else {
      final alarm = _span(t, 0.52, strike);
      _victim(
        canvas,
        x: walkX,
        walk: walk,
        stride: stride,
        arm: _mix(0.08, 2.3, alarm),
        elbow: _mix(0.2, 1.4, alarm),
      );
    }
  }

  void _grab(Canvas canvas) {
    final (walkX, walk, stride) = _entrance();
    final drag = _smooth(_span(t, strike + 0.03, strike + 0.20));
    final held = t >= strike;

    for (final (gap, delay) in [(0.40, 0.0), (0.82, 0.035)]) {
      final come = _smooth(_span(t, 0.43 + delay, strike));
      final x = _mix(_mix(_hiddenX + _u * gap, _victimX + _u * gap, come), _hiddenX + _u * gap, drag);
      final moving = (come > 0 && come < 1) || (drag > 0 && drag < 1);
      _person(
        canvas,
        feet: Offset(x, _ground),
        facing: drag > 0.05 ? 1 : -1,
        walk: _prowl + gap * 5,
        stride: moving ? 0.9 : 0,
        lean: 0.10 * come * (1 - drag),
        arm: held && drag < 1 ? 1.45 : 0.1,
        elbow: held && drag < 1 ? 0.15 : 0.2,
        killer: true,
      );
    }

    // La vittima viene trascinata dietro il muro: per questo va disegnata prima.
    final victimX = _mix(walkX, _hiddenX, drag);
    if (!held) {
      _victim(canvas, x: walkX, facing: t < 0.37 ? 1 : -1, walk: walk, stride: stride);
    } else {
      _person(
        canvas,
        feet: Offset(victimX, _ground),
        facing: -1,
        tilt: 0.45,
        crouch: 0.35,
        arm: 2.2 + 0.4 * sin(t * 120),
        elbow: 0.5,
        backArm: -1.6 + 0.4 * cos(t * 130),
        hat: victimHat,
        hatOn: false,
      );
    }
    _wall(canvas);

    if (held) {
      _looseHat(canvas, Offset(_victimX - _u * 0.25, _ground - _u * 0.03), 0.2);
      // I tacchi che strisciano sull'asfalto.
      final heels = Paint()
        ..color = Colors.black.withValues(alpha: 0.6)
        ..strokeWidth = _u * 0.02;
      for (final dy in [0.03, 0.07]) {
        canvas.drawLine(
          Offset(_victimX, _ground + _u * dy),
          Offset(min(victimX, _cornerX), _ground + _u * dy),
          heels,
        );
      }
    }
    // Da dietro l'angolo: un tonfo, e la polvere del cemento.
    _puff(canvas, Offset(_cornerX + _u * 0.05, _ground - _u * 0.25), _span(t, strike + 0.22, strike + 0.36), size: 1.6, color: const Color(0xFFB9B4AC));
    _puff(canvas, Offset(_cornerX + _u * 0.20, _ground - _u * 0.8), _span(t, strike + 0.25, strike + 0.40), size: 1.4, color: const Color(0xFFB9B4AC));
  }

  @override
  bool shouldRepaint(DeathScenePainter old) => old.t != t || old.act != act || old.victimHat != victimHat;
}
