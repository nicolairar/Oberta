import 'package:flutter/material.dart';

import '../../../press.dart';
import '../../../theme/app_theme.dart';

/// I colori della sala da gioco: il panno verde, il legno, l'ottone, lo
/// smalto rosso delle targhe del vicolo.
class Saloon {
  static const felt = Color(0xFF1E4A33);
  static const feltDeep = Color(0xFF0E2A1C);
  static const wood = Color(0xFF4A2A17);
  static const woodDark = Color(0xFF24130A);
  static const brass = Color(0xFFD9B45A);
  static const brassDeep = Color(0xFF8C6A26);
  static const enamel = Color(0xFFA3161F);
  static const enamelDeep = Color(0xFF5A0A10);
  static const ink = Color(0xFF0C0907);
  static const paper = Color(0xFFEFE4CB);
  static const paperInk = Color(0xFF1C140E);
  static const blood = Color(0xFFE5404C);
  static const mafia = Color(0xFFE5606A);
  static const clean = Color(0xFF6FD3A2);
  static const online = Color(0xFF55D97A);

  /// Il fondo scuro dietro ogni testo: mai testo chiaro su fondo chiaro.
  static BoxDecoration scrim({double radius = 14, Color border = brassDeep}) => BoxDecoration(
    color: ink.withValues(alpha: 0.86),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: border.withValues(alpha: 0.7)),
    boxShadow: const [BoxShadow(color: Color(0xAA000000), blurRadius: 16, offset: Offset(0, 6))],
  );

  static TextStyle plate(double size, {Color color = AppColors.textPrimary}) =>
      AppText.display(size, color: color).copyWith(
        letterSpacing: size * 0.12,
        shadows: const [Shadow(color: Colors.black, blurRadius: 6, offset: Offset(0, 2))],
      );
}

/// Il layout desktop della sala: sotto, pulsanti e testi della sala si
/// fanno a misura di 1080p e di mouse (gli schermi che non lo mettono
/// restano come sul telefono).
class NoirDesk extends InheritedWidget {
  const NoirDesk({super.key, required super.child});

  static bool of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<NoirDesk>() != null;

  @override
  bool updateShouldNotify(NoirDesk oldWidget) => false;
}

enum NoirButtonKind {
  /// Smalto rosso con il bordo d'ottone: l'azione principale.
  enamel,

  /// Ottone su fondo scuro: l'alternativa.
  brass,
}

/// Un pulsante della sala: una targa smaltata con il bordo d'ottone, come
/// quelle della home. Si abbassa sotto il dito.
class NoirButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final NoirButtonKind kind;
  final Press feel;
  final IconData? icon;
  final bool compact;

  const NoirButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.kind = NoirButtonKind.enamel,
    this.feel = Press.tap,
    this.icon,
    this.compact = false,
  });

  @override
  State<NoirButton> createState() => _NoirButtonState();
}

class _NoirButtonState extends State<NoirButton> {
  bool _down = false;

  /// Il mouse ci sta sopra: la targa si accende.
  bool _hover = false;

  void _set(bool down) {
    if (_down != down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final desk = NoirDesk.of(context);
    final lit = enabled && _hover;
    final enamel = widget.kind == NoirButtonKind.enamel;
    final face = enamel
        ? lit
            ? [const Color(0xFFE0353F), const Color(0xFFB81B25), Saloon.enamelDeep]
            : [const Color(0xFFC72A33), Saloon.enamel, Saloon.enamelDeep]
        : lit
            ? [const Color(0xFF3A2E24), const Color(0xFF1F1812), Saloon.ink]
            : [const Color(0xFF2A211B), const Color(0xFF15100C), Saloon.ink];
    final text = enabled ? (enamel ? const Color(0xFFFFF3DC) : (lit ? const Color(0xFFF2D58A) : Saloon.brass)) : AppColors.textSecondary;
    final radius = desk ? 14.0 : 12.0;
    final minHeight = desk ? (widget.compact ? 60.0 : 68.0) : (widget.compact ? 44.0 : 56.0);
    final fontSize = desk ? (widget.compact ? 18.0 : 21.0) : (widget.compact ? 14.0 : 17.0);
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: enabled ? (_) => _set(true) : null,
          onTapUp: enabled ? (_) => _set(false) : null,
          onTapCancel: () => _set(false),
          onTap: pressed(widget.onPressed, widget.feel),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 150),
            opacity: enabled ? 1 : 0.55,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 110),
              transform: Matrix4.translationValues(0, _down ? 2 : (lit ? -1.5 : 0), 0),
              constraints: BoxConstraints(minHeight: minHeight),
              padding: EdgeInsets.symmetric(horizontal: desk ? 28 : 16, vertical: widget.compact ? 8 : 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: enabled ? face : [const Color(0xFF2A2420), const Color(0xFF1A1512), Saloon.ink],
                ),
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(
                  color: lit ? const Color(0xFFF2D58A) : (enabled ? Saloon.brass : Saloon.brassDeep),
                  width: desk ? 2 : 1.6,
                ),
                boxShadow: _down || !enabled
                    ? const []
                    : [
                        const BoxShadow(color: Color(0xCC000000), blurRadius: 10, offset: Offset(0, 4)),
                        if (lit) BoxShadow(color: Saloon.brass.withValues(alpha: 0.35), blurRadius: 18),
                      ],
              ),
              foregroundDecoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(color: Colors.black.withValues(alpha: 0.5), width: 0.8),
              ),
              child: Center(
                widthFactor: 1,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon, size: desk ? 24 : 18, color: text),
                      SizedBox(width: desk ? 12 : 8),
                    ],
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          widget.label.toUpperCase(),
                          maxLines: 1,
                          style: AppText.display(fontSize, color: text).copyWith(letterSpacing: desk ? 2.6 : 2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Testo su un fondo scuro: la regola della leggibilità, in un widget.
class ScrimText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign align;
  final EdgeInsetsGeometry padding;

  const ScrimText(
    this.text, {
    super.key,
    this.style,
    this.align = TextAlign.center,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
  });

  @override
  Widget build(BuildContext context) {
    final desk = NoirDesk.of(context);
    return DecoratedBox(
      decoration: Saloon.scrim(radius: desk ? 12 : 10),
      child: Padding(
        padding: desk ? const EdgeInsets.symmetric(horizontal: 24, vertical: 12) : padding,
        child: Text(
          text,
          textAlign: align,
          style: style ?? AppText.body.copyWith(color: AppColors.textPrimary, fontSize: desk ? 19 : 14, height: desk ? 1.4 : null),
        ),
      ),
    );
  }
}

/// Il cartiglio in cima: il giorno (o la notte), la fase in un nastro
/// smaltato, il cronometro grande. Tutto su legno scuro.
class StageHeader extends StatelessWidget {
  final String title;
  final String? ribbon;
  final String? countdown;
  final bool urgent;
  final Widget? leading;

  /// Un bottone a destra, prima dell'orologio (il foglio dei ruoli).
  final Widget? action;

  const StageHeader({
    super.key,
    required this.title,
    this.ribbon,
    this.countdown,
    this.urgent = false,
    this.leading,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    // Sempre alta così, con o senza il nastro: la pagina sotto non si muove.
    return Container(
      height: 58,
      padding: const EdgeInsets.fromLTRB(4, 3, 12, 5),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xF2080605), Color(0xD90C0907), Color(0x000C0907)],
          stops: [0, 0.75, 1],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(width: 44, child: leading),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 22, height: 1.2, color: Saloon.brass),
                        const SizedBox(width: 10),
                        Text(title.toUpperCase(), maxLines: 1, style: Saloon.plate(22)),
                        const SizedBox(width: 10),
                        Container(width: 22, height: 1.2, color: Saloon.brass),
                      ],
                    ),
                  ),
                  if (ribbon != null) ...[const SizedBox(height: 4), _Ribbon(ribbon!)],
                ],
              ),
            ),
          ),
          ?action,
          SizedBox(
            width: action == null ? 76 : 64,
            child: countdown == null ? null : _Countdown(countdown!, urgent: urgent),
          ),
        ],
      ),
    );
  }
}

class _Ribbon extends StatelessWidget {
  final String text;

  const _Ribbon(this.text);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [Saloon.enamelDeep, Saloon.enamel, Saloon.enamelDeep]),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: Saloon.brass, width: 1),
    ),
    child: Text(
      text.toUpperCase(),
      style: AppText.display(12, color: const Color(0xFFFFE9C2)).copyWith(letterSpacing: 2.4),
    ),
  );
}

class _Countdown extends StatelessWidget {
  final String text;
  final bool urgent;

  const _Countdown(this.text, {required this.urgent});

  @override
  Widget build(BuildContext context) {
    final color = urgent ? Saloon.blood : Saloon.brass;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: Saloon.scrim(radius: 10, border: color),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.hourglass_bottom, size: 16, color: color),
          const SizedBox(width: 2),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                text,
                key: const Key('online.countdown'),
                style: AppText.display(
                  20,
                  color: color,
                ).copyWith(letterSpacing: 1, fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Un foglio di giornale: inchiostro scuro su carta chiara, per la cronaca.
class NewsPaper extends StatelessWidget {
  final Widget child;

  const NewsPaper({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: -0.012,
    child: Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF4EAD2), Saloon.paper, Color(0xFFD9CBA8)],
        ),
        borderRadius: BorderRadius.circular(3),
        boxShadow: const [BoxShadow(color: Color(0xDD000000), blurRadius: 22, offset: Offset(0, 10))],
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: child,
    ),
  );
}
