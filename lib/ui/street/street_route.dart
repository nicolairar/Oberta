import 'dart:math';

import 'package:flutter/material.dart';

import '../desktop/desktop_canvas.dart';
import 'noir_smoker.dart';
import 'street_section.dart';
import 'street_stage.dart';

double _span(double t, double from, double to) => ((t - from) / (to - from)).clamp(0.0, 1.0);

double _mix(double a, double b, double t) => a + (b - a) * t;

/// Un tragitto che parte da fermo, va a passo costante e rallenta in fondo:
/// [rise] e [fall] sono le frazioni spese ad avviarsi e a frenare (con
/// un'accelerazione morbida, senza strappi).
class _Stroll {
  final double rise;
  final double fall;

  const _Stroll(this.rise, this.fall);

  double get _area => 1 - rise / 2 - fall / 2;

  static double _smooth(double x) => x * x * (3 - 2 * x);

  /// Lo spazio percorso mentre la velocità sale con [_smooth].
  static double _gather(double x) => x * x * x - x * x * x * x / 2;

  /// Quanta strada ha fatto, da 0 a 1.
  double at(double u) {
    if (u <= 0) return 0;
    if (u >= 1) return 1;
    final double done;
    if (u < rise) {
      done = rise * _gather(u / rise);
    } else if (u <= 1 - fall) {
      done = rise / 2 + u - rise;
    } else {
      done = _area - fall * _gather((1 - u) / fall);
    }
    return done / _area;
  }

  /// Quanto va forte, da 0 (fermo) a 1 (il passo pieno).
  double pace(double u) {
    if (u <= 0 || u >= 1) return 0;
    if (u < rise) return _smooth(u / rise);
    if (u > 1 - fall) return _smooth((1 - u) / fall);
    return 1;
  }
}

/// I tempi della camminata, come frazioni della transizione. All'andata le
/// cose del posto di prima scivolano via mentre lui si avvia; la strada
/// scorre con lui a passo tranquillo; a metà strada arriva la facciata nuova
/// e la sua insegna si accende; lui rallenta davanti alla porta, la porta si
/// apre, entra, e solo allora compaiono i pannelli. Al ritorno la stessa
/// scena si riavvolge, con l'uomo girato a sinistra.
abstract final class StreetTiming {
  static const duration = Duration(milliseconds: 3500);
  static const back = Duration(milliseconds: 3000);
  static const still = Duration(milliseconds: 220);

  static const _walker = _Stroll(0.16, 0.30);
  static const _camera = _Stroll(0.30, 0.34);

  /// Quando si avvia (dopo essere uscito dalla porta di prima, se c'era) e
  /// quando si ferma davanti alla porta nuova.
  static double start({required bool fromDoor}) => fromDoor ? 0.17 : 0.05;
  static const arrive = 0.64;

  static double _walk(double t, bool fromDoor) => _span(t, start(fromDoor: fromDoor), arrive);

  /// Quanta strada ha fatto l'uomo, da 0 a 1.
  static double walk(double t, {required bool fromDoor}) => _walker.at(_walk(t, fromDoor));

  /// Quanto va forte, da 0 (fermo) a 1: il passo si allunga e si accorcia.
  static double pace(double t, {required bool fromDoor}) => _walker.pace(_walk(t, fromDoor));

  /// La strada che scorre: parte un attimo dopo di lui, più dolce, e si
  /// ferma insieme a lui.
  static double camera(double t, {required bool fromDoor}) =>
      _camera.at(_span(t, start(fromDoor: fromDoor) + 0.03, arrive));

  /// Le cose del vicolo (l'insegna, i manifesti) che scivolano via appena
  /// lui si avvia, prima che la strada scorra davvero.
  static double drift(double s) => Curves.easeInOut.transform(_span(s, 0.02, 0.40));

  /// L'insegna del posto nuovo: si accende a singhiozzo quando entra in vista.
  static double neon(double t) {
    const stutter = [0.0, 0.7, 0.0, 0.0, 0.45, 1.0, 0.25, 1.0];
    final u = _span(t, 0.34, 0.50);
    if (u >= 1) return 1;
    return stutter[(u * stutter.length).floor().clamp(0, stutter.length - 1)];
  }

  /// La porta del posto nuovo: si apre mentre lui rallenta, si richiude alle
  /// sue spalle.
  static double doorIn(double t) =>
      t < 0.80 ? Curves.easeOut.transform(_span(t, 0.62, 0.71)) : 1 - Curves.easeInOut.transform(_span(t, 0.85, 0.94));

  /// Entra: da 0 (sulla soglia) a 1 (dentro).
  static double enter(double t) => _span(t, 0.70, 0.85);

  /// I pannelli della sezione, una volta dentro.
  static double panels(double t) => Curves.easeOutCubic.transform(_span(t, 0.84, 1.0));

  /// Il posto che si lascia ([s] è la sua animazione secondaria): i pannelli
  /// spariscono, la porta si apre, lui esce, la porta si richiude.
  static double panelsOut(double s) => 1 - Curves.easeIn.transform(_span(s, 0.0, 0.06));
  static double doorOut(double s) =>
      s < 0.15 ? Curves.easeOut.transform(_span(s, 0.03, 0.10)) : 1 - Curves.easeInOut.transform(_span(s, 0.17, 0.25));

  /// Esce dalla porta del posto di prima: da 0 (dentro) a 1 (sul marciapiede).
  static double stepOut(double t) => _span(t, 0.08, 0.18);
}

/// Le cose davanti al muro del posto che si lascia (l'insegna, i manifesti):
/// quando l'uomo si avvia scivolano via di [depth] larghezze più del muro e
/// sfumano, così la scena si svuota prima che arrivi quella nuova. Al
/// ritorno rientrano mentre lui arriva. Sposta il livello già disegnato,
/// senza ridisegnare [child].
class StreetDrift extends StatelessWidget {
  final double depth;
  final double fade;
  final Widget child;

  const StreetDrift({super.key, required this.depth, this.fade = 1, required this.child});

  @override
  Widget build(BuildContext context) {
    final leaving = ModalRoute.of(context)?.secondaryAnimation;
    if (leaving == null) return child;
    final width = MediaQuery.sizeOf(context).width;
    return AnimatedBuilder(
      animation: Listenable.merge([leaving, StreetStage.walking]),
      child: RepaintBoundary(child: child),
      builder: (context, child) {
        // Solo per la strada: le altre pagine coprono il vicolo a modo loro.
        final d = StreetStage.walking.value > 0 ? StreetTiming.drift(leaving.value) : 0.0;
        return Opacity(
          opacity: 1 - fade * d,
          child: Transform.translate(offset: Offset(-width * depth * d, 0), child: child),
        );
      },
    );
  }
}

/// Una pagina dei menu lungo la strada. All'andata l'uomo del vicolo (o
/// quello che esce dalla porta di prima) si avvia verso destra a passo
/// tranquillo, la strada scorre con lui, la pagina di prima esce a sinistra;
/// arrivato davanti alla porta del posto nuovo rallenta, la apre ed entra, e
/// i pannelli compaiono. Al ritorno si riavvolge tutto: esce, cammina a
/// sinistra, e a casa si rigira verso la strada.
///
/// Un tocco durante la camminata la salta; con il movimento ridotto è solo
/// una dissolvenza.
class StreetRoute<T> extends PageRoute<T> {
  final WidgetBuilder builder;
  final StreetSection section;
  final bool still;

  StreetRoute({required this.builder, required this.section, this.still = false, super.settings});

  /// La strada verso [section], col movimento che chiede il telefono.
  static Future<T?> push<T>(BuildContext context, StreetSection section, WidgetBuilder builder) =>
      Navigator.of(context).push<T>(of<T>(context, section, builder));

  static StreetRoute<T> of<T>(BuildContext context, StreetSection section, WidgetBuilder builder) =>
      StreetRoute<T>(builder: builder, section: section, still: MediaQuery.maybeDisableAnimationsOf(context) ?? false);

  Route<dynamic>? _previous;
  bool _walking = false;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get opaque => true;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => still ? StreetTiming.still : StreetTiming.duration;

  @override
  Duration get reverseTransitionDuration => still ? StreetTiming.still : StreetTiming.back;

  @override
  void didChangePrevious(Route<dynamic>? previousRoute) {
    _previous = previousRoute;
    super.didChangePrevious(previousRoute);
  }

  @override
  void install() {
    super.install();
    animation!.addStatusListener(_status);
  }

  void _status(AnimationStatus status) {
    final moving = !still && status.isAnimating;
    if (moving == _walking) return;
    _walking = moving;
    StreetStage.walking.value += moving ? 1 : -1;
  }

  @override
  void dispose() {
    if (_walking) {
      _walking = false;
      StreetStage.walking.value -= 1;
    }
    super.dispose();
  }

  bool get _fromDoor => StreetStage.spotOf(_previous)?.door != null;

  @override
  DelegatedTransitionBuilder? get delegatedTransition => _leave;

  /// La pagina di prima esce a sinistra, alla velocità della strada.
  Widget? _leave(BuildContext context, Animation<double> animation, Animation<double> secondary, bool snapshot, Widget? child) {
    if (still) return child;
    final fromDoor = _fromDoor;
    return LayoutBuilder(
      builder: (context, box) => AnimatedBuilder(
        animation: secondary,
        builder: (context, child) => Transform.translate(
          offset: Offset(-box.maxWidth * StreetTiming.camera(secondary.value, fromDoor: fromDoor), 0),
          child: child,
        ),
        child: child,
      ),
    );
  }

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) =>
      Semantics(scopesRoute: true, explicitChildNodes: true, child: builder(context));

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    if (still) return FadeTransition(opacity: animation, child: child);
    final desk = DesktopCanvas.of(context);
    return LayoutBuilder(
      builder: (context, box) {
        final size = box.biggest;
        return AnimatedBuilder(
          animation: animation,
          child: child,
          builder: (context, child) {
            final t = animation.value;
            final fromDoor = _fromDoor;
            final gesture = navigator?.userGestureInProgress ?? false;
            final moving = animation.status.isAnimating && !gesture;
            return Stack(
              fit: StackFit.expand,
              children: [
                Transform.translate(
                  offset: Offset(size.width * (1 - StreetTiming.camera(t, fromDoor: fromDoor)), 0),
                  child: child,
                ),
                if (t < 1 && t > 0)
                  IgnorePointer(
                    child: CustomPaint(
                      painter: _WalkerPainter(
                        t: t,
                        size: size,
                        from: StreetStage.spotOf(_previous),
                        to: StreetStage.spotOf(this),
                        back: gesture || animation.status == AnimationStatus.reverse,
                        rim: section.neon,
                      ),
                    ),
                  ),
                // Un tocco salta la camminata.
                if (moving)
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (_) => _skip(),
                    ),
                  ),
                // Dal bordo sinistro si torna indietro trascinando (non sul PC).
                if (!desk && !isFirst && t == 1)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: 18,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onHorizontalDragStart: (_) => _dragStart(),
                      onHorizontalDragUpdate: (d) => _dragUpdate(d.primaryDelta ?? 0, size.width),
                      onHorizontalDragEnd: (d) => _dragEnd(d.primaryVelocity ?? 0, size.width),
                      onHorizontalDragCancel: () => _dragEnd(0, size.width),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  void _skip() {
    final controller = this.controller;
    if (controller == null) return;
    if (animation!.status == AnimationStatus.forward) {
      controller.value = 1;
    } else if (animation!.status == AnimationStatus.reverse) {
      controller.value = 0;
    }
  }

  bool _dragging = false;

  void _dragStart() {
    if (popDisposition != RoutePopDisposition.pop) return;
    _dragging = true;
    navigator?.didStartUserGesture();
  }

  void _dragUpdate(double dx, double width) {
    if (!_dragging) return;
    final controller = this.controller!;
    controller.value = (controller.value - dx / width).clamp(0.0, 1.0);
  }

  void _dragEnd(double velocity, double width) {
    if (!_dragging) return;
    _dragging = false;
    final controller = this.controller!;
    final pop = velocity > 600 || (velocity > -600 && controller.value < 0.6);
    if (pop) {
      navigator?.pop();
    } else {
      controller.forward();
    }
    navigator?.didStopUserGesture();
  }
}

/// L'uomo che cammina sopra le due pagine che scorrono. Va a passo costante
/// lungo tutta la strada (la pagina di prima più quella nuova) mentre la
/// strada lo segue: sullo schermo resta quasi fermo, e il passo segue lo
/// spazio fatto davvero.
class _WalkerPainter extends CustomPainter {
  final double t;
  final Size size;
  final StreetSpot? from;
  final StreetSpot? to;
  final bool back;
  final Color rim;

  /// Il filo di luce del lampione sull'uomo che fuma nel vicolo.
  static const _lamp = Color(0xFF7A6338);

  _WalkerPainter({
    required this.t,
    required this.size,
    required this.from,
    required this.to,
    required this.back,
    required this.rim,
  });

  @override
  void paint(Canvas canvas, Size _) {
    final w = size.width;
    final ground = size.height * 0.86;
    final to = this.to ?? StreetSpot(Offset(w * 1.15, ground), size.height * 0.2);
    final from = this.from ?? StreetSpot(Offset(-w * 0.15, to.feet.dy), to.height);
    final fromDoor = from.door != null;
    final out = fromDoor ? StreetTiming.stepOut(t) : 1.0;
    final enter = this.to?.door != null ? StreetTiming.enter(t) : 0.0;
    if (out <= 0 || enter >= 1) return;

    final walked = StreetTiming.walk(t, fromDoor: fromDoor);
    final cam = StreetTiming.camera(t, fromDoor: fromDoor);
    final road = w + to.feet.dx - from.feet.dx;
    final feet = Offset(
      from.feet.dx + walked * road - cam * w,
      _mix(from.feet.dy, to.feet.dy, walked),
    );
    final h = _mix(from.height, to.height, walked);
    // Un passo ogni tre quarti d'altezza di strada, più quello per uscire
    // dalla porta di prima e quello per entrare nella nuova.
    final step = (from.height + to.height) / 2 * 0.78;
    final phase = pi / 2 + (walked * road / step - (1 - out) + enter * 1.4) * pi;
    final stride = max(
      sqrt(StreetTiming.pace(t, fromDoor: fromDoor)),
      0.75 * max(sin(pi * out), sin(pi * enter)),
    );
    // Uscire e entrare: un passo dentro il buio della porta.
    final inside = Curves.easeInOut.transform(1 - out) + Curves.easeInOut.transform(enter);
    final opacity = (Curves.easeOut.transform(out) * (1 - Curves.easeIn.transform(enter))).clamp(0.0, 1.0);
    // Tornato nel vicolo si rigira verso la strada, come lo si era lasciato.
    final turn = back && !fromDoor ? -cos(pi * (1 - _span(t, 0, StreetTiming.start(fromDoor: false) * 0.8))) : (back ? -1.0 : 1.0);

    canvas.save();
    canvas.translate(feet.dx, feet.dy - h * 0.05 * inside);
    final scale = 1 - 0.12 * inside;
    canvas.scale(turn * scale, scale);
    // Dal vicolo parte con la luce del lampione addosso, e arriva con quella dell'insegna.
    final light = fromDoor ? rim : Color.lerp(_lamp, rim, walked)!;
    NoirSmoker.walker(canvas, h, phase: phase, walk: stride, rim: light, opacity: opacity);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_WalkerPainter old) =>
      old.t != t || old.from != from || old.to != to || old.back != back || old.size != size;
}
