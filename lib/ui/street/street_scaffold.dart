import 'dart:math';

import 'package:flutter/material.dart';

import '../desktop/desktop_canvas.dart';
import '../theme/app_theme.dart';
import 'street_facade.dart';
import 'street_neon.dart';
import 'street_route.dart';
import 'street_section.dart';
import 'street_stage.dart';

export 'street_section.dart';

/// Il tratto di strada davanti a un locale, dietro i pannelli di una
/// sezione: la facciata con la porta, l'insegna al neon della sezione. Dice
/// alla strada dov'è la porta, la apre quando l'uomo entra o esce, e fa
/// comparire [child] solo una volta entrati.
class StreetBackdrop extends StatelessWidget {
  final StreetSection section;

  /// Il nome della pagina per chi usa VoiceOver (l'insegna è disegnata).
  final String? title;
  final bool desk;

  /// I pannelli, posati nel riquadro giusto da [builder].
  final Widget Function(BuildContext context, StreetFacadeLayout layout) builder;

  const StreetBackdrop({super.key, required this.section, required this.builder, this.title, this.desk = false});

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final layout = StreetFacadeLayout(media.size, media.padding, desk: desk);
    StreetStage.report(context, layout.spot);
    final route = ModalRoute.of(context);
    final walks = route is StreetRoute && !route.still;
    final incoming = route?.animation ?? kAlwaysCompleteAnimation;
    final outgoing = route?.secondaryAnimation ?? kAlwaysDismissedAnimation;
    final language = section.nameOf(context);

    return AnimatedBuilder(
      animation: Listenable.merge([incoming, outgoing, StreetStage.walking]),
      child: builder(context, layout),
      builder: (context, child) {
        final t = walks ? incoming.value : 1.0;
        var door = walks && incoming.status.isAnimating ? StreetTiming.doorIn(t) : 0.0;
        var shown = walks ? StreetTiming.panels(t) : 1.0;
        final s = outgoing.value;
        if (s > 0 && StreetStage.walking.value > 0) {
          door = max(door, StreetTiming.doorOut(s));
          shown *= StreetTiming.panelsOut(s);
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(
              child: CustomPaint(painter: StreetFacadePainter(layout: layout, section: section, open: door)),
            ),
            Positioned.fromRect(
              rect: layout.neon,
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: StreetNeonPainter(text: language, color: section.neon),
                  child: title == null
                      ? Semantics(header: true, label: language, child: const SizedBox.expand())
                      : Semantics(
                          header: true,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(title!, style: const TextStyle(color: Color(0x00000000))),
                          ),
                        ),
                ),
              ),
            ),
            IgnorePointer(
              ignoring: shown < 0.6,
              child: Opacity(
                opacity: shown,
                child: Transform.translate(offset: Offset(0, 22 * (1 - shown)), child: child),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Una sezione dei menu sul telefono: la strada dietro, l'insegna in alto,
/// la targhetta per tornare indietro e i pannelli in una vetrina scura.
class StreetScaffold extends StatelessWidget {
  final StreetSection section;
  final String? title;
  final Widget body;
  final List<Widget> actions;

  /// Senza, la targhetta torna alla pagina di prima. Falso: niente targhetta
  /// (la pagina ha già il suo «indietro»).
  final bool showBack;
  final VoidCallback? onBack;

  /// I pannelli si accorciano sopra la tastiera.
  final bool resizeForKeyboard;

  const StreetScaffold({
    super.key,
    required this.section,
    required this.body,
    this.title,
    this.actions = const [],
    this.showBack = true,
    this.onBack,
    this.resizeForKeyboard = true,
  });

  @override
  Widget build(BuildContext context) {
    if (DesktopCanvas.of(context)) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: StreetBackdrop(section: section, desk: true, builder: (context, _) => body),
      );
    }
    final insets = MediaQuery.viewInsetsOf(context).bottom;
    return Scaffold(
      backgroundColor: const Color(0xFF07070B),
      resizeToAvoidBottomInset: false,
      body: StreetBackdrop(
        section: section,
        title: title,
        builder: (context, layout) {
          var panel = layout.panel;
          if (resizeForKeyboard && insets > 0) {
            panel = Rect.fromLTRB(panel.left, panel.top, panel.right, max(panel.top + 120, layout.size.height - insets - 6));
          }
          return Stack(
            children: [
              Positioned(
                left: 8,
                top: layout.neon.top + (layout.neon.height - 46) / 2,
                child: showBack ? _BackPlate(onBack: onBack) : const SizedBox.shrink(),
              ),
              if (actions.isNotEmpty)
                Positioned(
                  right: 6,
                  top: layout.neon.top + (layout.neon.height - 46) / 2,
                  height: 46,
                  child: IconTheme(
                    data: const IconThemeData(color: AppColors.gold),
                    child: Row(mainAxisSize: MainAxisSize.min, children: actions),
                  ),
                ),
              Positioned.fromRect(
                rect: panel,
                child: StreetWindow(
                  child: MediaQuery.removePadding(
                    context: context,
                    removeTop: true,
                    removeBottom: true,
                    child: MediaQuery.removeViewInsets(context: context, removeBottom: true, child: body),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// La targhetta smaltata con la freccia: torna indietro lungo la strada.
class _BackPlate extends StatelessWidget {
  final VoidCallback? onBack;

  const _BackPlate({this.onBack});

  @override
  Widget build(BuildContext context) => Container(
    width: 46,
    height: 46,
    decoration: BoxDecoration(
      color: const Color(0xFF14202A),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: const Color(0xFFC9A227).withValues(alpha: 0.7), width: 1.5),
      boxShadow: const [BoxShadow(color: Color(0xAA000000), blurRadius: 6, offset: Offset(1, 3))],
    ),
    child: BackButton(color: AppColors.gold, onPressed: onBack),
  );
}

/// La vetrina che fa da pannello: vetro scuro, telaio di ferro, un filo
/// d'ottone, la luce calda che viene da dentro.
class StreetWindow extends StatelessWidget {
  final Widget child;

  const StreetWindow({super.key, required this.child});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(8),
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xF2120E0C), Color(0xF00A0908)],
      ),
      border: Border.all(color: const Color(0xFF2B2622), width: 3),
      boxShadow: const [BoxShadow(color: Color(0xCC000000), blurRadius: 14, offset: Offset(0, 6))],
    ),
    child: DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: const Color(0xFFC9A227).withValues(alpha: 0.28)),
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(5), child: child),
    ),
  );
}
