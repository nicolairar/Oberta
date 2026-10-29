import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../theme/script_fonts.dart';

/// Il gioco su desktop coricato si disegna sempre su una tela fissa di
/// 1920×1080 punti, poi la tela si ingrandisce o rimpicciolisce tutta
/// insieme fino al riquadro 16:9 vero (1280×720 → 2560×1440). Così le misure
/// dei layout desktop sono quelle di un 1080p, sempre: niente widget del
/// telefono stirati.
class DesktopCanvas extends StatelessWidget {
  static const size = Size(1920, 1080);

  final Widget child;

  const DesktopCanvas({super.key, required this.child});

  /// Siamo sulla tela desktop coricata: gli schermi usano il loro layout PC.
  static bool of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_DesktopScope>() != null;

  /// Come [of], senza iscriversi ai cambi (per chi chiede fuori da build).
  static bool peek(BuildContext context) => context.getInheritedWidgetOfExactType<_DesktopScope>() != null;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final scale = media.size.isEmpty ? 1.0 : media.size.width / size.width;
    return FittedBox(
      fit: BoxFit.fill,
      alignment: Alignment.topLeft,
      child: SizedBox.fromSize(
        size: size,
        child: MediaQuery(
          data: media.copyWith(
            size: size,
            devicePixelRatio: media.devicePixelRatio * scale,
            padding: EdgeInsets.zero,
            viewPadding: EdgeInsets.zero,
            viewInsets: EdgeInsets.zero,
            textScaler: TextScaler.noScaling,
          ),
          child: _DesktopScope(child: child),
        ),
      ),
    );
  }
}

class _DesktopScope extends InheritedWidget {
  const _DesktopScope({required super.child});

  @override
  bool updateShouldNotify(_DesktopScope oldWidget) => false;
}

/// La scala dei testi a 1080p: il corpo a 19, i titoli in proporzione.
abstract final class DeskText {
  static const double caption = 15;
  static const double label = 16;
  static const double body = 19;
  static const double lead = 22;
  static const double title = 28;
  static const double heading = 40;
  static const double hero = 64;

  static TextStyle overline({Color color = AppColors.textSecondary}) =>
      TextStyle(color: color, fontSize: label, fontWeight: FontWeight.w700, letterSpacing: 3.2);

  static TextStyle text({double size = body, Color color = AppColors.textPrimary, FontWeight weight = FontWeight.w400}) =>
      TextStyle(color: color, fontSize: size, height: 1.45, fontWeight: weight);

  static TextStyle display(double size, {Color color = AppColors.gold}) => AppText.display(size, color: color);
}

/// Le misure ricorrenti dei layout desktop.
abstract final class DeskSize {
  static const double gutter = 48;
  static const double gap = 24;
  static const double topBar = 88;
  static const double button = 60;
  static const double radius = 14;
}

/// Il tema dei layout desktop: bottoni alti per il mouse, testi più grandi,
/// il passaggio del puntatore che accende il bordo. Gli schermi lo mettono
/// sopra il loro layout desktop con `Theme(data: buildDesktopTheme(...))`.
ThemeData buildDesktopTheme(ThemeData base) {
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(DeskSize.radius));
  const padding = EdgeInsets.symmetric(horizontal: 36, vertical: 22);
  const textStyle = TextStyle(fontFamily: 'Georgia', fontFamilyFallback: serifFallback, fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 2);
  WidgetStateProperty<Color?> hover(Color color) => WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.hovered) || states.contains(WidgetState.focused) ? color : null,
      );
  return base.copyWith(
    visualDensity: VisualDensity.standard,
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: (base.elevatedButtonTheme.style ?? const ButtonStyle()).copyWith(
        padding: const WidgetStatePropertyAll(padding),
        shape: WidgetStatePropertyAll(shape),
        textStyle: const WidgetStatePropertyAll(textStyle),
        minimumSize: const WidgetStatePropertyAll(Size(0, DeskSize.button)),
        overlayColor: hover(Colors.white.withValues(alpha: 0.12)),
        mouseCursor: const WidgetStatePropertyAll(SystemMouseCursors.click),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: (base.outlinedButtonTheme.style ?? const ButtonStyle()).copyWith(
        padding: const WidgetStatePropertyAll(padding),
        shape: WidgetStatePropertyAll(shape),
        textStyle: const WidgetStatePropertyAll(textStyle),
        minimumSize: const WidgetStatePropertyAll(Size(0, DeskSize.button)),
        overlayColor: hover(AppColors.gold.withValues(alpha: 0.14)),
        mouseCursor: const WidgetStatePropertyAll(SystemMouseCursors.click),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.gold,
        textStyle: textStyle,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      ).copyWith(overlayColor: hover(AppColors.gold.withValues(alpha: 0.12))),
    ),
    iconTheme: base.iconTheme.copyWith(size: 28),
    tooltipTheme: const TooltipThemeData(
      textStyle: TextStyle(fontSize: 16, color: AppColors.textPrimary),
      decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: BorderRadius.all(Radius.circular(8))),
      waitDuration: Duration(milliseconds: 400),
    ),
  );
}

/// Il tema desktop sopra [child].
class DeskTheme extends StatelessWidget {
  final Widget child;

  const DeskTheme({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Theme(data: buildDesktopTheme(Theme.of(context)), child: child);
}

/// Una superficie cliccabile col mouse: [builder] sa se il puntatore ci sta
/// sopra (per alzarla e accendere il bordo), e mostra la manina.
class DeskHover extends StatefulWidget {
  final Widget Function(BuildContext context, bool hovered) builder;
  final VoidCallback? onTap;
  final String? tooltip;

  const DeskHover({super.key, required this.builder, this.onTap, this.tooltip});

  @override
  State<DeskHover> createState() => _DeskHoverState();
}

class _DeskHoverState extends State<DeskHover> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    Widget child = MouseRegion(
      cursor: widget.onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: widget.builder(context, _hovered && widget.onTap != null),
      ),
    );
    if (widget.tooltip != null) child = Tooltip(message: widget.tooltip!, child: child);
    return child;
  }
}

/// Un pannello noir dei layout desktop: fondo scuro, filo dorato, titolo a
/// occhiello. Va messo dove l'altezza è limitata (il figlio si espande).
class DeskPanel extends StatelessWidget {
  final String? title;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Widget? trailing;

  const DeskPanel({super.key, this.title, required this.child, this.padding = const EdgeInsets.all(28), this.trailing});

  static BoxDecoration decoration({bool lit = false}) => BoxDecoration(
        color: const Color(0xEB120F0D),
        borderRadius: BorderRadius.circular(DeskSize.radius),
        border: Border.all(color: AppColors.gold.withValues(alpha: lit ? 0.7 : 0.26), width: lit ? 1.6 : 1),
        boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 32, offset: Offset(0, 12))],
      );

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: decoration(),
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) ...[
              Row(children: [
                Expanded(child: Text(title!.toUpperCase(), style: DeskText.overline(color: AppColors.gold))),
                ?trailing,
              ]),
              const SizedBox(height: 20),
            ],
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

/// La barra in alto degli schermi desktop: indietro, titolo grande, azioni.
class DeskTopBar extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;
  final List<Widget> actions;

  const DeskTopBar({super.key, required this.title, this.onBack, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    final back = onBack ?? (Navigator.of(context).canPop() ? () => Navigator.of(context).maybePop() : null);
    return SizedBox(
      height: DeskSize.topBar,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: DeskSize.gutter),
        child: Row(
          children: [
            if (back != null) ...[
              DeskHover(
                onTap: back,
                tooltip: 'Esc',
                builder: (context, hovered) => AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: hovered ? AppColors.gold.withValues(alpha: 0.16) : Colors.transparent,
                    border: Border.all(color: AppColors.gold.withValues(alpha: hovered ? 0.9 : 0.4)),
                  ),
                  child: const Icon(Icons.arrow_back, color: AppColors.gold, size: 26),
                ),
              ),
              const SizedBox(width: 24),
            ],
            Expanded(
              child: Text(title.toUpperCase(), style: DeskText.display(DeskText.title), overflow: TextOverflow.ellipsis),
            ),
            ...actions,
          ],
        ),
      ),
    );
  }
}

/// Esc sul desktop: chiama [onEscape] (di solito torna indietro o apre il
/// menu di pausa).
class DeskEscape extends StatelessWidget {
  final VoidCallback onEscape;
  final Widget child;

  const DeskEscape({super.key, required this.onEscape, required this.child});

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.escape): onEscape},
        child: Focus(autofocus: true, child: child),
      );
}
