import 'package:flutter/widgets.dart';

import '../desktop/desktop_canvas.dart';

/// Su Mac e iPad lo schermo è grande, ma il gioco è disegnato per il
/// telefono: invece di allargare tutto (testi piccoli, chat enorme) lo si
/// ingrandisce. Il figlio si dispone in uno schermo più piccolo di [zoomFor]
/// volte, poi viene ingrandito per riempire quello vero: testi, posti e
/// bottoni crescono insieme. Sul telefono non cambia niente.
class WideScale extends StatelessWidget {
  /// Il lato corto (in punti) che vale ingrandimento 1.
  static const double base = 640;

  /// L'ingrandimento massimo.
  static const double most = 1.6;

  final Widget child;

  const WideScale({super.key, required this.child});

  /// Quanto si ingrandisce uno schermo di queste misure.
  static double zoomFor(Size size) => (size.shortestSide / base).clamp(1.0, most);

  /// Lo schermo (già rimpicciolito) è largo: tavolo e chat stanno affiancati.
  static bool isWide(Size size) => size.width >= 900 || (size.width > size.height && size.width >= 700);

  @override
  Widget build(BuildContext context) {
    // Sulla tela desktop lo schermo ha già il suo layout a 1080p.
    if (DesktopCanvas.of(context)) return child;
    final media = MediaQuery.of(context);
    final zoom = zoomFor(media.size);
    if (zoom <= 1.0) return child;
    final size = media.size / zoom;
    return FittedBox(
      fit: BoxFit.fill,
      alignment: Alignment.topLeft,
      child: SizedBox.fromSize(
        size: size,
        child: MediaQuery(
          data: media.copyWith(
            size: size,
            devicePixelRatio: media.devicePixelRatio * zoom,
            padding: media.padding / zoom,
            viewPadding: media.viewPadding / zoom,
            viewInsets: media.viewInsets / zoom,
            systemGestureInsets: media.systemGestureInsets / zoom,
          ),
          child: child,
        ),
      ),
    );
  }
}
