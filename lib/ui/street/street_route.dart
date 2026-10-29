import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import '../desktop/desktop_canvas.dart';
import 'noir_smoker.dart';
import 'street_section.dart';
import 'street_stage.dart';
import 'street_wall.dart';

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
  static const still = Duration(milliseconds: 220);

  /// Al ritorno la camminata va come prima (quella di 3 secondi), ma uscire
  /// dal locale (i pannelli che spariscono, la porta, il passo fuori) prende
  /// il 40% in meno: [backCurve] stringe quel tratto.
  static const _backWalk = 3000;
  static const _backExit = 0.6;
  static final back = Duration(milliseconds: (_backWalk * (arrive + (1 - arrive) * _backExit)).round());

  /// Il ritorno, sul tempo di [back]: fino a [arrive] al passo di sempre,
  /// dopo (l'uscita dalla porta) più svelto.
  static final Curve backCurve = _BackCurve(arrive / (arrive + (1 - arrive) * _backExit));

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

  /// Di quanto scorre la pagina che si lascia, posato sui pixel veri dello
  /// schermo ([ratio]): le due pagine si toccano su un bordo intero, senza
  /// la riga scura di un bordo a metà pixel.
  static double leaving(double width, double camera, double ratio) => -(width * camera * ratio).roundToDouble() / ratio;

  /// La pagina che arriva: subito dopo quella che si lascia, sovrapposta di
  /// un pixel vero, così tra le due non resta mai una fessura.
  static double arriving(double width, double camera, double ratio) => leaving(width, camera, ratio) + width - (camera > 0 && camera < 1 ? 1 / ratio : 0);
}

/// La curva del ritorno: il controller va da 1 a 0 a velocità costante; da
/// 1 a [knee] percorre l'uscita (da 1 ad [StreetTiming.arrive]), da [knee]
/// a 0 la camminata. Continua e sempre crescente: il ritorno non salta.
class _BackCurve extends Curve {
  final double knee;

  const _BackCurve(this.knee);

  @override
  double transformInternal(double u) {
    const arrive = StreetTiming.arrive;
    if (u <= knee) return u / knee * arrive;
    return arrive + (u - knee) / (1 - knee) * (1 - arrive);
  }
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
    // Si sposta e sfuma al momento di disegnare, senza ricostruire: dentro il
    // LayoutBuilder di una pagina, una ricostruzione a ogni fotogramma ne
    // rifarebbe l'impaginazione e il disegno interi.
    return _Drift(leaving: leaving, shift: width * depth, fade: fade, child: RepaintBoundary(child: child));
  }
}

/// Quanto si è spostato, da 0 a 1: solo per la strada (le altre pagine
/// coprono il vicolo a modo loro).
double _driftOf(Animation<double> leaving) => StreetStage.walking.value > 0 ? StreetTiming.drift(leaving.value) : 0.0;

class _Drift extends SingleChildRenderObjectWidget {
  final Animation<double> leaving;
  final double shift;
  final double fade;

  const _Drift({required this.leaving, required this.shift, required this.fade, required Widget super.child});

  @override
  _RenderDrift createRenderObject(BuildContext context) => _RenderDrift(leaving, shift, fade);

  @override
  void updateRenderObject(BuildContext context, _RenderDrift renderObject) => renderObject
    ..leaving = leaving
    ..shift = shift
    ..fade = fade;
}

/// Come `Opacity` sopra `Transform.translate`, con gli stessi strati (anche
/// lui uno strato a sé, come `Opacity`), ma seguendo la camminata da solo:
/// a ogni passo cambia solo dove si posa lo strato di [child].
class _RenderDrift extends RenderProxyBox {
  _RenderDrift(this._leaving, this._shift, this._fade);

  Animation<double> _leaving;
  set leaving(Animation<double> value) {
    if (value == _leaving) return;
    if (attached) _leaving.removeListener(_moved);
    _leaving = value;
    if (attached) _leaving.addListener(_moved);
    _moved();
  }

  double _shift;
  set shift(double value) {
    if (value == _shift) return;
    _shift = value;
    _moved();
  }

  double _fade;
  set fade(double value) {
    if (value == _fade) return;
    _fade = value;
    _moved();
  }

  double get _d => _driftOf(_leaving);
  Offset get _offset => Offset(-_shift * _d, 0);
  int get _alpha => Color.getAlphaFromOpacity(1 - _fade * _d);

  Offset _painted = Offset.zero;
  int _shown = 255;

  void _moved() {
    final alpha = _alpha;
    if (alpha != _shown) markNeedsCompositedLayerUpdate();
    // Trasparente del tutto [child] non si disegna: riapparendo, sì.
    if (_offset != _painted || (alpha == 0) != (_shown == 0)) markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _leaving.addListener(_moved);
    StreetStage.walking.addListener(_moved);
  }

  @override
  void detach() {
    _leaving.removeListener(_moved);
    StreetStage.walking.removeListener(_moved);
    super.detach();
  }

  @override
  bool get isRepaintBoundary => true;

  @override
  OffsetLayer updateCompositedLayer({required covariant OpacityLayer? oldLayer}) {
    final layer = oldLayer ?? OpacityLayer();
    _shown = _alpha;
    layer.alpha = _shown;
    return layer;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    _painted = _offset;
    if (child == null || _alpha == 0) return;
    context.paintChild(child, offset + _painted);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final child = this.child;
    if (child == null) return false;
    return result.addWithPaintOffset(offset: _offset, position: position, hitTest: (result, position) => child.hitTest(result, position: position));
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final shift = _offset;
    transform.translateByDouble(shift.dx, shift.dy, 0, 1);
  }

  @override
  bool paintsChild(RenderBox child) => _alpha != 0;
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

  /// La pagina da cui si parte (e a cui si torna).
  Route<dynamic>? get previous => _previous;

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

  /// Al ritorno l'uscita dalla porta va più svelta della camminata
  /// ([StreetTiming.backCurve]); all'andata e col dito il tempo è lineare.
  @override
  Animation<double> createAnimation() =>
      still ? super.createAnimation() : CurvedAnimation(parent: controller!, curve: Curves.linear, reverseCurve: StreetTiming.backCurve);

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
    final previous = _previous;
    if (moving && previous != null) {
      StreetStage.ahead.value = StreetAhead(previous, this, animation!);
    } else if (!moving && StreetStage.ahead.value?.to == this) {
      StreetStage.ahead.value = null;
    }
  }

  @override
  void dispose() {
    if (_dragging) {
      // Chiusa a metà gesto: lo si chiude dopo il fotogramma, a Navigator fermo.
      _dragging = false;
      final nav = navigator;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (nav != null && nav.mounted) nav.didStopUserGesture();
      });
    }
    if (_walking) {
      _walking = false;
      StreetStage.walking.value -= 1;
    }
    if (StreetStage.ahead.value?.to == this) {
      // Qui si è a metà di un fotogramma: le pagine si avvisano dopo.
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (StreetStage.ahead.value?.to == this) StreetStage.ahead.value = null;
      });
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
          offset: Offset(
            StreetTiming.leaving(box.maxWidth, StreetTiming.camera(secondary.value, fromDoor: fromDoor), MediaQuery.devicePixelRatioOf(context)),
            0,
          ),
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
            final ratio = MediaQuery.devicePixelRatioOf(context);
            final moving = animation.status.isAnimating && !gesture;
            return Stack(
              fit: StackFit.expand,
              children: [
                Transform.translate(
                  offset: Offset(StreetTiming.arriving(size.width, StreetTiming.camera(t, fromDoor: fromDoor), ratio), 0),
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
                // La vignettatura resta ferma sullo schermo: è l'obiettivo,
                // non il muro (le pagine la tolgono mentre si cammina).
                if (_walking) const IgnorePointer(child: RepaintBoundary(child: CustomPaint(painter: StreetVignettePainter(), size: Size.infinite))),
                // Un tocco salta la camminata.
                if (moving)
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (_) => _skip(),
                    ),
                  ),
                // Dal bordo sinistro si torna indietro trascinando (non sul PC).
                // Durante il trascinamento la striscia resta: tolta a metà,
                // la fine del gesto non arriverebbe mai e il Navigator
                // ignorerebbe ogni tocco per sempre (la pagina «congelata»).
                if (!desk && !isFirst && (t == 1 || _dragging))
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
    final controller = this.controller!;
    final pop = velocity > 600 || (velocity > -600 && controller.value < 0.6);
    if (pop) {
      navigator?.pop();
    } else {
      controller.forward();
    }
    _stopDrag();
  }

  /// Chiude il gesto col Navigator: finché è aperto, la pagina non sente i tocchi.
  void _stopDrag() {
    if (!_dragging) return;
    _dragging = false;
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
