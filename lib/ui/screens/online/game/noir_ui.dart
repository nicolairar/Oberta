import 'package:flutter/material.dart';

import '../../../press.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/targa.dart';

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
  @override
  Widget build(BuildContext context) => TargaButton(
    label: widget.label,
    onPressed: widget.onPressed,
    kind: widget.kind == NoirButtonKind.enamel ? TargaKind.primary : TargaKind.secondary,
    feel: widget.feel,
    icon: widget.icon,
    compact: widget.compact,
    desk: NoirDesk.of(context),
  );
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

/// Il cartiglio in cima: il giorno (o la notte) al centro, la fase in una
/// riga sotto, a sinistra l'uscita, a destra il mazzo e il cronometro.
/// Sempre alto uguale, col titolo sempre al centro: i due lati hanno la
/// stessa larghezza.
class StageHeader extends StatelessWidget {
  final String title;
  final String? ribbon;
  final String? countdown;
  final bool urgent;
  final Widget? leading;

  /// Un bottone a destra, prima dell'orologio (il foglio dei ruoli).
  final Widget? action;

  /// Al posto dell'orologio, quando non corre (la mano di prova).
  final Widget? corner;

  const StageHeader({
    super.key,
    required this.title,
    this.ribbon,
    this.countdown,
    this.urgent = false,
    this.leading,
    this.action,
    this.corner,
  });

  static const height = 56.0;

  /// Ogni lato è largo così: un pulsante da 48 e l'orologio.
  static const _side = 124.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xF2080605), Color(0xD90C0907), Color(0x000C0907)],
          stops: [0, 0.75, 1],
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: _side,
            child: Row(
              children: [
                if (leading case final leading?) SizedBox(width: 48, height: 48, child: Center(child: leading)),
              ],
            ),
          ),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title.toUpperCase(), maxLines: 1, style: Saloon.plate(22)),
                  if (ribbon != null) ...[const SizedBox(height: 2), _Ribbon(ribbon!)],
                ],
              ),
            ),
          ),
          SizedBox(
            width: _side,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (action case final action?) SizedBox(width: 44, height: 48, child: Center(child: action)),
                SizedBox(
                  width: 76,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: countdown != null ? _Countdown(countdown!, urgent: urgent) : corner,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Un pulsante a icona del cartiglio: niente cornice, un bersaglio da 48.
class HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const HeaderIconButton({super.key, required this.icon, required this.tooltip, required this.onPressed});

  @override
  Widget build(BuildContext context) => IconButton(
    icon: Icon(icon, color: Saloon.brass, size: 24),
    tooltip: tooltip,
    constraints: const BoxConstraints.tightFor(width: 48, height: 48),
    padding: EdgeInsets.zero,
    onPressed: onPressed,
  );
}

/// La fase, sotto il titolo: una riga in corsivo, come si scrive.
class _Ribbon extends StatelessWidget {
  final String text;

  const _Ribbon(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    maxLines: 1,
    style: const TextStyle(
      fontFamily: 'Georgia',
      fontFamilyFallback: ['serif'],
      fontSize: 14,
      fontStyle: FontStyle.italic,
      color: Color(0xFFE8D9B8),
      shadows: [Shadow(color: Colors.black, blurRadius: 6)],
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
      width: 72,
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: Saloon.scrim(radius: 10, border: color),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.hourglass_bottom, size: 16, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                text,
                key: const Key('online.countdown'),
                style: AppText.display(18, color: color).copyWith(
                  letterSpacing: 0.5,
                  fontFeatures: const [FontFeature.tabularFigures(), FontFeature.liningFigures()],
                ),
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
