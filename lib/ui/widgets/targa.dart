import 'dart:math';

import 'package:flutter/material.dart';

import '../press.dart';
import '../theme/app_theme.dart';
import 'home_account.dart' show CoinPainter;

/// The buttons of the whole game, «Targa»: an enamel plate in a bevelled
/// brass frame, a thin hairline inside the frame, a soft gloss on top.
/// Primary is oxblood enamel with cream letters; secondary is black lacquer
/// with brass letters; icon buttons are round brass medallions.
///
/// Every frame is one [CustomPaint] (no stacked boxes), so a screen full of
/// them stays cheap to lay out and to repaint.
enum TargaKind { primary, secondary }

class Targa {
  static const cream = Color(0xFFFFF1D6);
  static const brass = Color(0xFFE6C77A);
  static const brassDim = Color(0xFF8C6A26);
  static const ink = Color(0xFF0C0907);

  static const gold = [Color(0xFFFFE7A8), Color(0xFFD9B45A), Color(0xFF9C7424), Color(0xFFC9A23E)];
  static const goldStops = [0.0, 0.42, 0.78, 1.0];
  static const enamel = [Color(0xFFB3242E), Color(0xFF7E111A), Color(0xFF4A070D)];
  static const enamelLit = [Color(0xFFCB2E38), Color(0xFF931621), Color(0xFF560A11)];
  static const lacquer = [Color(0xFF2A211B), Color(0xFF15100C), Color(0xFF0C0907)];
  static const lacquerLit = [Color(0xFF3A2E24), Color(0xFF1F1812), Color(0xFF0C0907)];
  static const dead = [Color(0xFF2A2420), Color(0xFF1A1512), Color(0xFF0C0907)];

  /// The letters on a plate: serif capitals, spaced.
  static TextStyle label(double size, Color color) => TextStyle(
    fontFamily: 'Georgia',
    fontFamilyFallback: const ['serif'],
    fontSize: size,
    fontWeight: FontWeight.bold,
    letterSpacing: size * 0.16,
    height: 1.05,
    color: color,
  );
}

/// The frame and the face of a plate. [circle] draws a medallion.
class TargaPainter extends CustomPainter {
  final TargaKind kind;
  final bool enabled;
  final bool down;
  final bool lit;
  final double radius;
  final bool circle;

  const TargaPainter({
    this.kind = TargaKind.primary,
    this.enabled = true,
    this.down = false,
    this.lit = false,
    this.radius = 14,
    this.circle = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rim = circle ? max(1.6, size.shortestSide * 0.05) : (kind == TargaKind.primary ? 2.2 : 1.5);
    RRect shape(double inset) => circle
        ? RRect.fromRectAndRadius(rect.deflate(inset), Radius.circular(size.shortestSide / 2))
        : RRect.fromRectAndRadius(rect.deflate(inset), Radius.circular(max(0, radius - inset)));
    if (enabled && !down) {
      canvas.drawRRect(
        shape(0).shift(const Offset(0, 4)),
        Paint()
          ..color = const Color(0x99000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      if (lit || kind == TargaKind.primary) {
        canvas.drawRRect(
          shape(0),
          Paint()
            ..color = Color(lit ? 0x55FFB443 : 0x26FFB443)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
        );
      }
    }
    final frame = enabled ? Targa.gold : const [Color(0xFF6E5A3A), Color(0xFF4A3C26), Color(0xFF3A2E1C), Color(0xFF4A3C26)];
    canvas.drawRRect(
      shape(0),
      Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: frame, stops: Targa.goldStops).createShader(rect),
    );
    final faceColors = !enabled
        ? Targa.dead
        : kind == TargaKind.primary
        ? (lit ? Targa.enamelLit : Targa.enamel)
        : (lit ? Targa.lacquerLit : Targa.lacquer);
    final face = shape(rim);
    canvas.drawRRect(
      face,
      Paint()
        ..shader = (circle
                ? RadialGradient(center: const Alignment(0, -0.5), radius: 1, colors: [faceColors[0], faceColors[2]])
                : LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: faceColors, stops: const [0, 0.55, 1]))
            .createShader(face.outerRect),
    );
    canvas.drawRRect(
      shape(rim * 1.9),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = kind == TargaKind.primary ? const Color(0x66FFD9A0) : const Color(0x33FFE7A8),
    );
    if (kind == TargaKind.primary && !circle && enabled) {
      final gloss = Rect.fromLTRB(face.left + 3, face.top + 1, face.right - 3, face.top + face.height * 0.42);
      canvas.drawRRect(
        RRect.fromRectAndRadius(gloss, Radius.circular(max(0, radius - rim - 2))),
        Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x30FFFFFF), Color(0x00FFFFFF)]).createShader(gloss),
      );
    }
    if (down) canvas.drawRRect(face, Paint()..color = const Color(0x22000000));
  }

  @override
  bool shouldRepaint(TargaPainter old) =>
      old.kind != kind || old.enabled != enabled || old.down != down || old.lit != lit || old.radius != radius || old.circle != circle;
}

/// A hover and press state shared by the Targa controls.
mixin _Pressable<T extends StatefulWidget> on State<T> {
  bool down = false;
  bool hover = false;

  void setDown(bool value) {
    if (down != value) setState(() => down = value);
  }

  Widget pressable({required bool enabled, required VoidCallback? onTap, required Widget child, String? label, bool button = true}) => Semantics(
    button: button,
    enabled: enabled,
    label: label,
    excludeSemantics: label != null,
    child: MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => hover = true),
      onExit: (_) => setState(() => hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => setDown(true) : null,
        onTapUp: enabled ? (_) => setDown(false) : null,
        onTapCancel: () => setDown(false),
        onTap: onTap,
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 90),
          offset: Offset(0, down ? 0.03 : 0),
          child: child,
        ),
      ),
    ),
  );
}

/// A plate with words on it, and on a Buy button the price set into a
/// recessed socket.
class TargaButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final TargaKind kind;
  final Press feel;
  final IconData? icon;

  /// The price shown in the socket, with a coin.
  final int? price;

  /// 44 high instead of 56 (60 and 68 on the desk).
  final bool compact;

  /// Sized for the 1080p desk.
  final bool desk;

  /// Fill the width it is given.
  final bool expand;

  /// An explicit height, over [compact] and [desk].
  final double? height;

  const TargaButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.kind = TargaKind.primary,
    this.feel = Press.tap,
    this.icon,
    this.price,
    this.compact = false,
    this.desk = false,
    this.expand = false,
    this.height,
  });

  @override
  State<TargaButton> createState() => _TargaButtonState();
}

class _TargaButtonState extends State<TargaButton> with _Pressable {
  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final primary = widget.kind == TargaKind.primary;
    final h = widget.height ?? (widget.desk ? (widget.compact ? 60.0 : 68.0) : (widget.compact ? 44.0 : 56.0));
    final k = h / 56;
    final text = !enabled ? AppColors.textSecondary : (primary ? Targa.cream : (hover ? const Color(0xFFFFE7A8) : Targa.brass));
    final size = (widget.desk ? 20.0 : 16.0) * (widget.compact ? 0.88 : 1) * (widget.height == null ? 1 : k.clamp(0.75, 1.3));
    final label = Text(
      widget.label.toUpperCase(),
      maxLines: 1,
      style: Targa.label(size, text).copyWith(
        shadows: primary && enabled ? const [Shadow(color: Color(0x99000000), offset: Offset(0, 1.5), blurRadius: 1)] : null,
      ),
    );
    final row = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[Icon(widget.icon, size: size * 1.15, color: text), SizedBox(width: size * 0.5)],
        Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: label)),
        if (widget.price case final price?) ...[
          SizedBox(width: 12 * k),
          PriceSocket(price: price, height: h * 0.6, enabled: enabled),
        ],
      ],
    );
    return pressable(
      enabled: enabled,
      label: widget.price == null ? widget.label : '${widget.label} ${widget.price}',
      onTap: pressed(widget.onPressed, widget.feel),
      child: CustomPaint(
        painter: TargaPainter(kind: widget.kind, enabled: enabled, down: down, lit: enabled && hover, radius: 14 * k),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: h, maxHeight: h),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: (widget.desk ? 26 : 18) * k).copyWith(right: widget.price != null ? 7 * k : null),
            child: row,
          ),
        ),
      ),
    );
  }
}

/// The price in a dark stadium socket: a coin and the figures.
class PriceSocket extends StatelessWidget {
  final int price;
  final double height;
  final bool enabled;
  const PriceSocket({super.key, required this.price, this.height = 34, this.enabled = true});

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    padding: EdgeInsets.fromLTRB(height * 0.18, 0, height * 0.3, 0),
    decoration: const ShapeDecoration(
      shape: StadiumBorder(),
      color: Color(0xCC1A0306),
      shadows: [BoxShadow(color: Color(0x44FFFFFF), offset: Offset(0, 1))],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(dimension: height * 0.6, child: const CustomPaint(painter: CoinPainter())),
        SizedBox(width: height * 0.16),
        Text(
          '$price',
          style: TextStyle(
            color: enabled ? const Color(0xFFFFE7A8) : AppColors.textSecondary,
            fontSize: height * 0.46,
            fontWeight: FontWeight.w800,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    ),
  );
}

/// A round brass medallion with one icon: back, close, filters, gifts.
class TargaIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final Press feel;

  /// A small red count on the rim (active filters, news).
  final int? badge;

  /// Lit like a toggle that is on.
  final bool selected;

  const TargaIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = 44,
    this.feel = Press.tap,
    this.badge,
    this.selected = false,
  });

  @override
  State<TargaIconButton> createState() => _TargaIconButtonState();
}

class _TargaIconButtonState extends State<TargaIconButton> with _Pressable {
  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final s = widget.size;
    Widget plate = CustomPaint(
      painter: TargaPainter(kind: TargaKind.secondary, enabled: enabled, down: down, lit: enabled && (hover || widget.selected), circle: true),
      child: SizedBox.square(
        dimension: s,
        child: Icon(widget.icon, size: s * 0.46, color: enabled ? const Color(0xFFF0D590) : AppColors.textSecondary),
      ),
    );
    if (widget.badge case final badge? when badge > 0) {
      plate = Stack(
        clipBehavior: Clip.none,
        children: [
          plate,
          Positioned(
            right: -3,
            top: -3,
            child: Container(
              constraints: const BoxConstraints(minWidth: 18),
              height: 18,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFB3242E),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: const Color(0xFFFFE7A8), width: 1.2),
              ),
              child: Text('$badge', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      );
    }
    final button = pressable(enabled: enabled, label: widget.tooltip, onTap: pressed(widget.onPressed, widget.feel), child: plate);
    return widget.tooltip == null ? button : Tooltip(message: widget.tooltip!, child: button);
  }
}

/// The way back, on every page: a medallion with a slim chevron. Without
/// [onPressed] it pops the route.
class TargaBackButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final double size;
  const TargaBackButton({super.key, this.onPressed, this.size = 44});

  @override
  Widget build(BuildContext context) => TargaIconButton(
    icon: Icons.arrow_back_ios_new_rounded,
    tooltip: MaterialLocalizations.of(context).backButtonTooltip,
    size: size,
    feel: Press.back,
    onPressed: onPressed ?? () => Navigator.maybePop(context),
  );
}

/// The purse: the coin larger than its pill and sitting over its edge, the
/// sum in tabular figures, and a small brass + when there is somewhere to
/// get more coins ([onAdd]; hidden without it).
class CoinPurse extends StatelessWidget {
  final int coins;
  final VoidCallback? onAdd;
  final String? hint;
  final double scale;

  const CoinPurse({super.key, required this.coins, this.onAdd, this.hint, this.scale = 1});

  /// The figures with a dot for the thousands: 3.800.
  static String format(int n) {
    final s = '${n.abs()}';
    final b = StringBuffer(n < 0 ? '-' : '');
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
      b.write(s[i]);
    }
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    final k = scale;
    final h = 30 * k;
    final pill = Container(
      margin: EdgeInsets.only(left: 15 * k),
      height: h,
      padding: EdgeInsets.fromLTRB(24 * k, 0, onAdd == null ? 12 * k : 4 * k, 0),
      decoration: const ShapeDecoration(
        shape: StadiumBorder(side: BorderSide(color: Color(0x99D9B45A))),
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xF2201812), Color(0xF20A0807)]),
        shadows: [BoxShadow(color: Color(0x99000000), blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            format(coins),
            key: const Key('purse.coins'),
            style: TextStyle(
              color: const Color(0xFFF2E6CF),
              fontSize: 15 * k,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (onAdd != null) ...[
            SizedBox(width: 8 * k),
            GestureDetector(
              key: const Key('purse.add'),
              onTap: pressed(onAdd),
              child: Container(
                width: h - 8 * k,
                height: h - 8 * k,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: Targa.gold, stops: Targa.goldStops),
                ),
                child: Icon(Icons.add, size: 15 * k, color: const Color(0xFF2A1A06)),
              ),
            ),
          ],
        ],
      ),
    );
    final purse = SizedBox(
      height: 38 * k,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          pill,
          DecoratedBox(
            decoration: const BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: Color(0xAA000000), blurRadius: 6, offset: Offset(0, 2))]),
            child: SizedBox.square(dimension: 34 * k, child: const CustomPaint(painter: CoinPainter())),
          ),
        ],
      ),
    );
    return Semantics(
      label: '${format(coins)} ${hint ?? ''}'.trim(),
      child: hint == null ? purse : Tooltip(message: hint!, triggerMode: TooltipTriggerMode.tap, child: purse),
    );
  }
}

/// The button themes of the app, so every [ElevatedButton] and
/// [OutlinedButton] wears the Targa plate. The same two instances every
/// time: a theme built twice stays equal and never animates between them.
ButtonStyle targaButtonStyle(TargaKind kind) => kind == TargaKind.primary ? _primaryStyle : _secondaryStyle;

final _primaryStyle = _style(TargaKind.primary, _primaryBackground);
final _secondaryStyle = _style(TargaKind.secondary, _secondaryBackground);

Widget _primaryBackground(BuildContext context, Set<WidgetState> states, Widget? child) => _background(TargaKind.primary, states, child);
Widget _secondaryBackground(BuildContext context, Set<WidgetState> states, Widget? child) => _background(TargaKind.secondary, states, child);

Widget _background(TargaKind kind, Set<WidgetState> states, Widget? child) => CustomPaint(
  painter: TargaPainter(
    kind: kind,
    enabled: !states.contains(WidgetState.disabled),
    down: states.contains(WidgetState.pressed),
    lit: states.contains(WidgetState.hovered) || states.contains(WidgetState.focused),
  ),
  child: child,
);

ButtonStyle _style(TargaKind kind, ButtonLayerBuilder background) => ButtonStyle(
  backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
  shadowColor: const WidgetStatePropertyAll(Colors.transparent),
  surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
  overlayColor: const WidgetStatePropertyAll(Colors.transparent),
  elevation: const WidgetStatePropertyAll(0),
  side: const WidgetStatePropertyAll(BorderSide.none),
  minimumSize: const WidgetStatePropertyAll(Size(64, 48)),
  padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 26, vertical: 16)),
  shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
  foregroundColor: kind == TargaKind.primary ? _primaryInk : _secondaryInk,
  textStyle: const WidgetStatePropertyAll(TextStyle(fontFamily: 'Georgia', fontFamilyFallback: ['serif'], fontWeight: FontWeight.bold, letterSpacing: 1.8, fontSize: 15)),
  backgroundBuilder: background,
);

final _primaryInk = WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.disabled) ? AppColors.textSecondary : Targa.cream);
final _secondaryInk = WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.disabled) ? AppColors.textSecondary : Targa.brass);

/// The icons of the implicit back and close buttons of every [AppBar],
/// drawn as Targa medallions (the button around them stays Material's, so
/// taps, tooltips and semantics are unchanged). Top-level functions: the
/// theme built twice stays equal.
Widget targaBackIcon(BuildContext context) => const _MedallionIcon(Icons.arrow_back_ios_new_rounded);
Widget targaCloseIcon(BuildContext context) => const _MedallionIcon(Icons.close);

class _MedallionIcon extends StatelessWidget {
  final IconData icon;
  const _MedallionIcon(this.icon);

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: const TargaPainter(kind: TargaKind.secondary, circle: true),
    child: SizedBox.square(dimension: 38, child: Icon(icon, size: 17, color: const Color(0xFFF0D590))),
  );
}
