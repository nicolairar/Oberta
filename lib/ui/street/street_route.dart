import 'dart:math';

import 'package:flutter/material.dart';

import '../desktop/desktop_canvas.dart';
import 'noir_smoker.dart';
import 'street_section.dart';
import 'street_stage.dart';

double _span(double t, double from, double to) => ((t - from) / (to - from)).clamp(0.0, 1.0);

/// I tempi della camminata, come frazioni della transizione (andata; al
/// ritorno la stessa scena si riavvolge, con l'uomo girato a sinistra).
abstract final class StreetTiming {
  static const duration = Duration(milliseconds: 850);
  static const still = Duration(milliseconds: 220);

  /// Esce dalla porta del posto di prima (se ne aveva una).
  static double stepOut(double t) => _span(t, 0.0, 0.12);

  /// La strada scorre e l'uomo cammina: [fromDoor] se prima esce da una porta.
  static double camera(double t, {required bool fromDoor}) =>
      Curves.easeInOutCubic.transform(_span(t, fromDoor ? 0.10 : 0.0, 0.66));

  /// La porta del posto nuovo: si apre davanti a lui, si richiude alle spalle.
  static double doorIn(double t) =>
      t < 0.86 ? Curves.easeOut.transform(_span(t, 0.60, 0.72)) : 1 - Curves.easeIn.transform(_span(t, 0.86, 0.97));

  /// Entra: da 0 (sulla soglia) a 1 (dentro).
  static double enter(double t) => _span(t, 0.70, 0.88);

  /// I pannelli della sezione, una volta dentro.
  static double panels(double t) => Curves.easeOutCubic.transform(_span(t, 0.84, 1.0));

  /// Il posto che si lascia ([s] è la sua animazione secondaria): i pannelli
  /// spariscono, la porta si apre per farlo uscire e si richiude.
  static double panelsOut(double s) => 1 - _span(s, 0.0, 0.07);
  static double doorOut(double s) =>
      s < 0.14 ? Curves.easeOut.transform(_span(s, 0.0, 0.07)) : 1 - _span(s, 0.18, 0.30);
}

/// Una pagina dei menu lungo la strada. All'andata l'uomo del vicolo (o
/// quello che esce dalla porta di prima) cammina verso destra, la strada
/// scorre con lui, la pagina di prima esce a sinistra; arrivato davanti
/// alla porta del posto nuovo la apre ed entra, e i pannelli compaiono. Al
/// ritorno si riavvolge tutto: esce, si gira e cammina a sinistra.
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
  Duration get reverseTransitionDuration => transitionDuration;

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
            final moving = animation.status.isAnimating && !(navigator?.userGestureInProgress ?? false);
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
                        back: animation.status == AnimationStatus.reverse,
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

/// L'uomo che cammina sopra le due pagine che scorrono.
class _WalkerPainter extends CustomPainter {
  final double t;
  final Size size;
  final StreetSpot? from;
  final StreetSpot? to;
  final bool back;
  final Color rim;

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
    final cam = StreetTiming.camera(t, fromDoor: fromDoor);
    final out = fromDoor ? StreetTiming.stepOut(t) : 1.0;
    final enter = this.to?.door != null ? StreetTiming.enter(t) : 0.0;
    if (out <= 0 || enter >= 1) return;

    final feet = Offset.lerp(from.feet, to.feet, cam)!;
    final h = from.height + (to.height - from.height) * cam;
    // Il passo segue la strada percorsa davvero: la pagina di prima più quella nuova.
    final world = from.feet.dx + cam * (w + to.feet.dx - from.feet.dx);
    final phase = world / (h * 0.62) * pi;
    final walking = cam > 0 && cam < 1 ? 1.0 : 0.45;
    // Uscire e entrare: un passo dentro il buio della porta.
    final depth = (1 - out) + enter;
    final opacity = (out * (1 - enter)).clamp(0.0, 1.0);

    canvas.save();
    canvas.translate(feet.dx, feet.dy - h * 0.05 * depth);
    final scale = 1 - 0.08 * depth;
    canvas.scale(back ? -scale : scale, scale);
    NoirSmoker.walker(canvas, h, phase: phase, walk: walking, rim: rim, opacity: opacity);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_WalkerPainter old) =>
      old.t != t || old.from != from || old.to != to || old.back != back || old.size != size;
}
