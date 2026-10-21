import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'desktop_canvas.dart';

/// Apre una finestra al centro della tela desktop, sopra il vicolo
/// oscurato: il posto del foglio dal fondo dei telefoni. Esc la chiude.
Future<T?> showDeskModal<T>(BuildContext context, {required WidgetBuilder builder, bool dismissible = true}) =>
    showGeneralDialog<T>(
      context: context,
      barrierDismissible: dismissible,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: const Color(0xC0050406),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, _, _) => DeskTheme(child: Builder(builder: builder)),
      transitionBuilder: (context, animation, _, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(scale: Tween(begin: 0.96, end: 1.0).animate(curved), child: child),
        );
      },
    );

/// La carta di una finestra desktop: occhiello, titolo grande, la crocetta
/// per chiudere, il contenuto. [onEnter] è quello che fa INVIO.
class DeskModal extends StatelessWidget {
  final String? overline;
  final String title;
  final Widget child;
  final double width;
  final VoidCallback? onEnter;

  /// Una riga piccola in basso: i tasti che servono.
  final String? hint;

  const DeskModal({
    super.key,
    this.overline,
    required this.title,
    required this.child,
    this.width = 720,
    this.onEnter,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    Widget card = Material(
      type: MaterialType.transparency,
      child: Container(
        width: width,
        constraints: const BoxConstraints(maxHeight: 940),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF231C18), Color(0xFF120F0D)],
          ),
          borderRadius: BorderRadius.circular(DeskSize.radius + 4),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
          boxShadow: [
            const BoxShadow(color: Color(0xCC000000), blurRadius: 60, offset: Offset(0, 24)),
            BoxShadow(color: AppColors.accent.withValues(alpha: 0.18), blurRadius: 90, spreadRadius: -10),
          ],
        ),
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(56, 48, 56, 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (overline case final overline?) ...[
                    Text(
                      overline.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: DeskText.overline(color: AppColors.gold),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Text(title.toUpperCase(), textAlign: TextAlign.center, style: DeskText.display(DeskText.heading)),
                  const SizedBox(height: 14),
                  Center(child: Container(width: 120, height: 1.4, color: AppColors.gold.withValues(alpha: 0.45))),
                  const SizedBox(height: 30),
                  child,
                  if (hint case final hint?) ...[
                    const SizedBox(height: 26),
                    Text(
                      hint,
                      textAlign: TextAlign.center,
                      style: DeskText.overline(color: AppColors.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
            Positioned(
              top: 18,
              right: 18,
              child: DeskHover(
                onTap: () => Navigator.of(context).maybePop(),
                tooltip: 'Esc',
                builder: (context, hovered) => AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: hovered ? AppColors.gold.withValues(alpha: 0.16) : Colors.transparent,
                    border: Border.all(color: AppColors.gold.withValues(alpha: hovered ? 0.9 : 0.3)),
                  ),
                  child: Icon(Icons.close, size: 24, color: hovered ? AppColors.gold : AppColors.textSecondary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (onEnter case final enter?) {
      card = CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.enter): enter,
          const SingleActivator(LogicalKeyboardKey.numpadEnter): enter,
        },
        child: Focus(autofocus: true, child: card),
      );
    }
    return Center(child: card);
  }
}
