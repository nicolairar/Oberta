import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../desktop/desktop_canvas.dart';
import '../press.dart';
import 'targa.dart';
import '../theme/script_fonts.dart';

/// The noir modal kit: one dialog, one bottom sheet, one action menu, the
/// same buttons everywhere. Phones get a card or a sheet; the desktop canvas
/// (1920×1080) gets the same pieces, larger, centred, with Esc and Enter.
///
///  * [showNoirDialog] / [NoirDialog] / [confirmNoir]: a centred card.
///  * [showNoirSheet] / [NoirSheet]: a sheet from the bottom (a card on PC).
///  * [showNoirMenu] / [NoirMenuItem]: a list of actions on someone or something.
///  * [NoirModalButton]: primary, secondary, danger, quiet.
///
/// Toasts are the paper slips of `showNotice` (noir_notice.dart).

/// The palette of the kit, shared by the three pieces.
abstract final class NoirInk {
  static const brass = Color(0xFFD9B45A);
  static const brassLight = Color(0xFFF2D58A);
  static const brassDeep = Color(0xFF8C6A26);
  static const card = Color(0xFF1C1613);
  static const cardDeep = Color(0xFF100C0A);
  static const text = Color(0xFFF2EAE1);
  static const body = Color(0xFFCFC4B6);
  static const muted = Color(0xFF9A8F84);
  static const blood = Color(0xFFE5404C);
  static const enamel = Color(0xFFA3161F);
  static const paper = Color(0xFFF2E6CF);
  static const paperInk = Color(0xFF2A1A10);
  static const paperBody = Color(0xFF4A3420);
  static const barrier = Color(0xC7050404);
}

/// The measures of the kit: an 8-point grid on the phone, the same grid a
/// size up on the 1080p desktop canvas.
class NoirMetrics {
  final bool desk;

  const NoirMetrics(this.desk);

  factory NoirMetrics.of(BuildContext context) => NoirMetrics(DesktopCanvas.of(context));

  double get dialogWidth => desk ? 640 : 360;
  double get sheetWidth => desk ? 760 : 640;
  double get pad => desk ? 48 : 24;
  double get gap => desk ? 16 : 8;
  double get radius => desk ? 22 : 18;
  double get button => desk ? 64 : 48;
  double get buttonText => desk ? 18 : 14;
  double get title => desk ? 32 : 21;
  double get overline => desk ? 15 : 11;
  double get body => desk ? 20 : 15;
  double get small => desk ? 16 : 12.5;
  double get icon => desk ? 30 : 22;
  double get row => desk ? 64 : 52;
}

TextStyle _serif(double size, Color color, {FontWeight weight = FontWeight.w700, double spacing = 0, double? height}) =>
    TextStyle(
      fontFamily: 'Georgia',
      fontFamilyFallback: serifFallback,
      fontSize: size,
      fontWeight: weight,
      letterSpacing: spacing,
      height: height,
      color: color,
      decoration: TextDecoration.none,
    );

/// The type scale of the kit, for the content callers put inside.
abstract final class NoirType {
  static TextStyle title(NoirMetrics m, {Color color = NoirInk.brass}) => _serif(m.title, color, height: 1.15);
  static TextStyle overline(NoirMetrics m, {Color color = NoirInk.muted}) =>
      _serif(m.overline, color, spacing: m.overline * 0.22);
  static TextStyle body(NoirMetrics m, {Color color = NoirInk.body}) =>
      TextStyle(fontSize: m.body, height: 1.45, color: color, decoration: TextDecoration.none);
  static TextStyle small(NoirMetrics m, {Color color = NoirInk.muted}) =>
      TextStyle(fontSize: m.small, height: 1.4, color: color, decoration: TextDecoration.none);
  static TextStyle label(NoirMetrics m, {Color color = NoirInk.text}) =>
      TextStyle(fontSize: m.desk ? 19 : 16, fontWeight: FontWeight.w600, color: color, decoration: TextDecoration.none);
}

// ---------------------------------------------------------------------------
// Buttons

enum NoirButtonStyle {
  /// Brass, filled: the thing the card is for.
  primary,

  /// Brass rim on the dark: the way back.
  secondary,

  /// Red enamel: the thing that cannot be undone.
  danger,

  /// Just the words: an extra way out.
  quiet,
}

/// One action of a dialog: what it says, how loud it is, what it does.
class NoirAction {
  final String label;
  final NoirButtonStyle style;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Widget? trailing;
  final Press feel;
  final Key? key;

  const NoirAction({
    required this.label,
    required this.onPressed,
    this.style = NoirButtonStyle.secondary,
    this.icon,
    this.trailing,
    this.feel = Press.tap,
    this.key,
  });

  bool get main => style == NoirButtonStyle.primary || style == NoirButtonStyle.danger;
}

/// The button of the kit: at least 48 points tall (64 on PC), uppercase
/// serif, a hover glow and a press dip, keyboard focus ring.
class NoirModalButton extends StatefulWidget {
  final NoirAction action;
  final bool paper;
  final bool autofocus;

  /// The size of the words, and the room at their sides, when a row of
  /// buttons has to share them ([NoirEvenActions]).
  final double? fontSize;
  final double? sidePadding;

  const NoirModalButton({
    super.key,
    required this.action,
    this.paper = false,
    this.autofocus = false,
    this.fontSize,
    this.sidePadding,
  });

  @override
  State<NoirModalButton> createState() => _NoirModalButtonState();
}

class _NoirModalButtonState extends State<NoirModalButton> {
  bool _hover = false;
  bool _focus = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final m = NoirMetrics.of(context);
    final a = widget.action;
    final enabled = a.onPressed != null;
    final lit = enabled && (_hover || _focus);
    final paper = widget.paper;
    var (List<Color>? fill, Color border, Color ink) = switch (a.style) {
      NoirButtonStyle.primary when paper => (
          lit ? const [Color(0xFF3A2A1E), Color(0xFF1C130C)] : const [Color(0xFF2E2117), Color(0xFF140D08)],
          lit ? NoirInk.brassLight : NoirInk.brass,
          lit ? NoirInk.brassLight : NoirInk.brass,
        ),
      NoirButtonStyle.primary => (
          lit
              ? const [Color(0xFFFFE6A3), Color(0xFFE2BE62), Color(0xFFB08A35)]
              : const [Color(0xFFF0D27A), Color(0xFFD2AC52), Color(0xFF9C7A2C)],
          const Color(0xFF5A420C),
          const Color(0xFF1C140E),
        ),
      NoirButtonStyle.danger => (
          lit
              ? const [Color(0xFFE0353F), Color(0xFFB81B25), Color(0xFF6A0D14)]
              : const [Color(0xFFC72A33), NoirInk.enamel, Color(0xFF5A0A10)],
          lit ? NoirInk.brassLight : NoirInk.brass,
          const Color(0xFFFFF3DC),
        ),
      NoirButtonStyle.secondary when paper => (
          lit ? [NoirInk.paperInk.withValues(alpha: 0.08), NoirInk.paperInk.withValues(alpha: 0.08)] : null,
          NoirInk.paperInk.withValues(alpha: lit ? 0.8 : 0.45),
          NoirInk.paperInk,
        ),
      NoirButtonStyle.secondary => (
          [NoirInk.brass.withValues(alpha: lit ? 0.16 : 0.06), NoirInk.brass.withValues(alpha: lit ? 0.12 : 0.03)],
          NoirInk.brass.withValues(alpha: lit ? 0.95 : 0.6),
          lit ? NoirInk.brassLight : NoirInk.brass,
        ),
      NoirButtonStyle.quiet => (
          lit ? [Colors.white.withValues(alpha: 0.06), Colors.white.withValues(alpha: 0.06)] : null,
          Colors.transparent,
          paper ? NoirInk.paperBody : (lit ? NoirInk.text : NoirInk.muted),
        ),
    };
    // On the dark cards the plates are Targa: enamel for the main action,
    // black lacquer for the other. The paper cards and the quiet links keep
    // their printed look.
    final plate = !paper && a.style != NoirButtonStyle.quiet;
    final targa = a.main ? TargaKind.primary : TargaKind.secondary;
    if (plate) ink = !enabled ? NoirInk.muted : (a.main ? Targa.cream : (lit ? NoirInk.brassLight : Targa.brass));
    final radius = BorderRadius.circular(m.desk ? 14 : 12);
    final words = widget.fontSize ?? m.buttonText;
    final label = Text(
      a.label.toUpperCase(),
      maxLines: 1,
      textAlign: TextAlign.center,
      style: _serif(words, ink, spacing: words * 0.12),
    );
    return FocusableActionDetector(
      enabled: enabled,
      autofocus: widget.autofocus,
      mouseCursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onShowHoverHighlight: (on) => setState(() => _hover = on),
      onShowFocusHighlight: (on) => setState(() => _focus = on),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => pressed(a.onPressed, a.feel)?.call()),
      },
      child: Semantics(
        button: true,
        enabled: enabled,
        label: a.label,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: enabled ? (_) => setState(() => _down = true) : null,
          onTapUp: enabled ? (_) => setState(() => _down = false) : null,
          onTapCancel: () => setState(() => _down = false),
          onTap: pressed(a.onPressed, a.feel),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 150),
            opacity: enabled ? 1 : 0.45,
            child: AnimatedScale(
              duration: const Duration(milliseconds: 90),
              scale: _down ? 0.97 : 1,
              child: CustomPaint(
                painter: plate ? TargaPainter(kind: targa, enabled: enabled, down: _down, lit: lit, radius: m.desk ? 14 : 12) : null,
                child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                constraints: BoxConstraints(minHeight: m.button),
                padding: EdgeInsets.symmetric(horizontal: widget.sidePadding ?? (m.desk ? 28 : 16), vertical: m.desk ? 12 : 8),
                decoration: plate
                    ? BoxDecoration(borderRadius: radius, border: _focus ? Border.all(color: NoirInk.brassLight, width: 2) : null)
                    : BoxDecoration(
                  gradient: fill == null
                      ? null
                      : LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: fill),
                  borderRadius: radius,
                  border: Border.all(
                    color: _focus && !_hover ? NoirInk.brassLight : border,
                    width: _focus ? 2 : (m.desk ? 1.6 : 1.3),
                  ),
                  boxShadow: a.main && enabled && !_down
                      ? [
                          const BoxShadow(color: Color(0x99000000), blurRadius: 10, offset: Offset(0, 4)),
                          if (lit) BoxShadow(color: NoirInk.brass.withValues(alpha: 0.28), blurRadius: 18),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (a.icon case final icon?) ...[
                      Icon(icon, size: m.desk ? 24 : 18, color: ink),
                      SizedBox(width: m.gap),
                    ],
                    Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: label)),
                    if (a.trailing case final trailing?) ...[
                      SizedBox(width: m.gap + 2),
                      IconTheme(
                        data: IconThemeData(color: ink, size: m.desk ? 22 : 16),
                        child: DefaultTextStyle(style: _serif(m.buttonText, ink), child: trailing),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The buttons at the foot of a card: two side by side (the way back on the
/// left, the main one on the right), three or more stacked, main on top.
class NoirActions extends StatelessWidget {
  final List<NoirAction> actions;
  final bool paper;

  const NoirActions({super.key, required this.actions, this.paper = false});

  @override
  Widget build(BuildContext context) {
    final m = NoirMetrics.of(context);
    Widget button(NoirAction a) => NoirModalButton(key: a.key, action: a, paper: paper, autofocus: a.main && m.desk);
    if (actions.length == 1) return button(actions.single);
    // Side by side, unless a button carries a price on a phone: half the
    // card is too narrow for both, and the words shrank to a whisper.
    if (actions.length == 2 && (m.desk || actions.every((a) => a.trailing == null))) {
      final ordered = [...actions]..sort((a, b) => (a.main ? 1 : 0) - (b.main ? 1 : 0));
      return Row(
        children: [
          Expanded(child: button(ordered[0])),
          SizedBox(width: m.gap * 1.5),
          Expanded(child: button(ordered[1])),
        ],
      );
    }
    final ordered = [...actions]..sort((a, b) => (b.main ? 1 : 0) - (a.main ? 1 : 0));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, a) in ordered.indexed) ...[
          if (i > 0) SizedBox(height: m.gap),
          button(a),
        ],
      ],
    );
  }
}

/// Three buttons or more on one row, all with their words at the same size:
/// each as wide as its words need, and if the row is short the words shrink
/// together, never one alone.
class NoirEvenActions extends StatelessWidget {
  final List<NoirAction> actions;

  const NoirEvenActions({super.key, required this.actions});

  @override
  Widget build(BuildContext context) {
    final m = NoirMetrics.of(context);
    final side = m.desk ? 18.0 : 7.0;
    final gap = m.desk ? m.gap : m.gap * 0.75;
    final scaler = MediaQuery.textScalerOf(context);
    final words = [
      for (final action in actions)
        (TextPainter(
          text: TextSpan(text: action.label.toUpperCase(), style: _serif(m.buttonText, const Color(0xFF000000), spacing: m.buttonText * 0.12)),
          textDirection: TextDirection.ltr,
          textScaler: scaler,
          maxLines: 1,
        )..layout()).width + 1,
    ];
    final needed = words.fold(0.0, (sum, width) => sum + width);
    return LayoutBuilder(
      builder: (context, box) {
        final room = box.maxWidth - gap * (actions.length - 1) - side * 2 * actions.length;
        final scale = (room / needed).clamp(0.0, 1.0);
        final spare = (room - needed * scale) / actions.length;
        return Row(
          children: [
            for (final (i, action) in actions.indexed) ...[
              if (i > 0) SizedBox(width: gap),
              SizedBox(
                width: words[i] * scale + side * 2 + spare,
                child: NoirModalButton(key: action.key, action: action, fontSize: m.buttonText * scale, sidePadding: side),
              ),
            ],
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Dialog

/// Opens a [NoirDialog] (or any card) in the middle of the screen: a short
/// fade and lift, a dark barrier, Esc closes when [dismissible].
Future<T?> showNoirDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool dismissible = true,
  Color barrierColor = NoirInk.barrier,
}) =>
    showGeneralDialog<T>(
      context: context,
      barrierDismissible: dismissible,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: barrierColor,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, _, _) => _ModalFrame(dismissible: dismissible, child: Builder(builder: builder)),
      transitionBuilder: (context, animation, _, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.02), end: Offset.zero).animate(curved),
            child: ScaleTransition(scale: Tween(begin: 0.97, end: 1.0).animate(curved), child: child),
          ),
        );
      },
    );

/// Keeps a card clear of the notch and the keyboard, centred.
class _ModalFrame extends StatelessWidget {
  final bool dismissible;
  final Widget child;

  const _ModalFrame({required this.dismissible, required this.child});

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final desk = DesktopCanvas.of(context);
    Widget frame = AnimatedPadding(
      duration: const Duration(milliseconds: 120),
      padding: media.viewInsets + media.padding + EdgeInsets.all(desk ? 48 : 16),
      child: Center(child: Material(type: MaterialType.transparency, child: child)),
    );
    if (desk) frame = DeskTheme(child: frame);
    return CallbackShortcuts(
      bindings: {
        if (dismissible) const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).maybePop(),
      },
      child: Focus(autofocus: true, child: frame),
    );
  }
}

enum NoirTone {
  /// The dark card with the brass rim: the default.
  dark,

  /// Cream paper with ink: receipts and notes.
  paper,
}

/// The card: an optional seal (icon), a small overline, the title, a short
/// line of body, any content, and the buttons. It scrolls in the middle if
/// the screen is short. [onEnter] is what Enter does (usually the main
/// action); Esc is handled by [showNoirDialog].
class NoirDialog extends StatelessWidget {
  final String title;
  final String? overline;
  final String? body;
  final IconData? icon;
  final Widget? lead;
  final Widget? child;
  final List<NoirAction> actions;
  final bool danger;
  final NoirTone tone;
  final Color? rim;
  final VoidCallback? onEnter;
  final double? width;
  final bool closeButton;

  const NoirDialog({
    super.key,
    required this.title,
    this.overline,
    this.body,
    this.icon,
    this.lead,
    this.child,
    this.actions = const [],
    this.danger = false,
    this.tone = NoirTone.dark,
    this.rim,
    this.onEnter,
    this.width,
    this.closeButton = false,
  });

  @override
  Widget build(BuildContext context) {
    final m = NoirMetrics.of(context);
    final paper = tone == NoirTone.paper;
    final accent = danger ? NoirInk.blood : (paper ? NoirInk.paperInk : NoirInk.brass);
    final rimColor = rim ?? (danger ? NoirInk.blood.withValues(alpha: 0.75) : NoirInk.brass.withValues(alpha: 0.6));
    final screen = MediaQuery.sizeOf(context);
    final width = min(this.width ?? m.dialogWidth, screen.width - 32);
    final center = CrossAxisAlignment.center;
    final head = <Widget>[
      if (lead case final lead?) ...[lead, SizedBox(height: m.gap * 2)],
      if (icon case final icon?) ...[
        Container(
          width: m.desk ? 72 : 52,
          height: m.desk ? 72 : 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accent.withValues(alpha: 0.1),
            border: Border.all(color: accent.withValues(alpha: 0.7), width: m.desk ? 2 : 1.5),
          ),
          child: Icon(icon, size: m.desk ? 34 : 24, color: accent),
        ),
        SizedBox(height: m.gap * 2),
      ],
      if (overline case final overline?) ...[
        Text(overline.toUpperCase(), textAlign: TextAlign.center, style: NoirType.overline(m, color: paper ? NoirInk.paperBody : NoirInk.muted)),
        SizedBox(height: m.gap),
      ],
      Text(
        title,
        textAlign: TextAlign.center,
        style: NoirType.title(m, color: paper ? NoirInk.paperInk : (danger ? NoirInk.text : NoirInk.brass)),
      ),
      SizedBox(height: m.gap * 1.5),
      _Ornament(color: paper ? NoirInk.paperInk.withValues(alpha: 0.4) : rimColor),
      if (body case final body?) ...[
        SizedBox(height: m.gap * 2),
        Text(body, textAlign: TextAlign.center, style: NoirType.body(m, color: paper ? NoirInk.paperBody : NoirInk.body)),
      ],
    ];
    Widget card = Container(
      width: width,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: paper
              ? const [Color(0xFFF7EDD9), NoirInk.paper, Color(0xFFE3D2B0)]
              : const [Color(0xFF261E19), NoirInk.card, NoirInk.cardDeep],
        ),
        borderRadius: BorderRadius.circular(paper ? 6 : m.radius),
        border: Border.all(color: paper ? (rim ?? const Color(0xFF8C6A14)) : rimColor, width: paper ? 2 : 1.2),
        boxShadow: [
          const BoxShadow(color: Color(0xCC000000), blurRadius: 48, offset: Offset(0, 20)),
          if (!paper) BoxShadow(color: (danger ? NoirInk.enamel : NoirInk.brass).withValues(alpha: 0.12), blurRadius: 60, spreadRadius: -8),
        ],
      ),
      foregroundDecoration: BoxDecoration(
        // The engraved inner rule, a few points inside the rim.
        borderRadius: BorderRadius.circular(paper ? 3 : m.radius - 5),
        border: Border.all(color: (paper ? NoirInk.paperInk : NoirInk.brass).withValues(alpha: 0.14)),
      ),
      padding: EdgeInsets.all(m.desk ? 6 : 5),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: screen.height - (m.desk ? 120 : 48) - MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(m.pad - 5, m.pad - 2, m.pad - 5, 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Column(crossAxisAlignment: center, children: head),
                    if (child case final child?) ...[SizedBox(height: m.gap * 2.5), child],
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(m.pad - 5, actions.isEmpty ? 0 : m.gap * 3, m.pad - 5, m.pad - 8),
              child: actions.isEmpty ? const SizedBox.shrink() : NoirActions(actions: actions, paper: paper),
            ),
          ],
        ),
      ),
    );
    if (closeButton) {
      card = Stack(
        clipBehavior: Clip.none,
        children: [card, Positioned(top: m.gap, right: m.gap, child: const NoirCloseButton())],
      );
    }
    if (onEnter case final enter?) {
      card = CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.enter): enter,
          const SingleActivator(LogicalKeyboardKey.numpadEnter): enter,
        },
        child: card,
      );
    }
    return card;
  }
}

/// A line, a diamond, a line: the rule under every title.
class _Ornament extends StatelessWidget {
  final Color color;

  const _Ornament({required this.color});

  @override
  Widget build(BuildContext context) {
    final m = NoirMetrics.of(context);
    final line = Container(width: m.desk ? 56 : 36, height: 1, color: color);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        line,
        Padding(
          padding: EdgeInsets.symmetric(horizontal: m.gap),
          child: Transform.rotate(
            angle: pi / 4,
            child: Container(width: m.desk ? 8 : 6, height: m.desk ? 8 : 6, color: color),
          ),
        ),
        line,
      ],
    );
  }
}

/// The round × in a corner of a card or sheet.
class NoirCloseButton extends StatefulWidget {
  const NoirCloseButton({super.key});

  @override
  State<NoirCloseButton> createState() => _NoirCloseButtonState();
}

class _NoirCloseButtonState extends State<NoirCloseButton> {
  @override
  Widget build(BuildContext context) {
    final m = NoirMetrics.of(context);
    final size = m.desk ? 48.0 : 44.0;
    return SizedBox.square(
      dimension: size,
      child: Center(
        child: TargaIconButton(
          icon: Icons.close,
          tooltip: m.desk ? 'Esc' : MaterialLocalizations.of(context).closeButtonTooltip,
          size: size - 8,
          feel: Press.back,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
    );
  }
}

/// «Are you sure?»: a title, one line, the way back and the main button.
/// True only if the main button was pressed. [danger] paints it red.
Future<bool> confirmNoir(
  BuildContext context, {
  required String title,
  String? body,
  required String confirm,
  required String cancel,
  bool danger = false,
  IconData? icon,
  Key? key,
  Key? confirmKey,
  Key? cancelKey,
}) async {
  final yes = await showNoirDialog<bool>(
    context,
    builder: (context) => NoirDialog(
      key: key,
      title: title,
      body: body,
      icon: icon,
      danger: danger,
      onEnter: () => Navigator.of(context).pop(true),
      actions: [
        NoirAction(
          key: cancelKey,
          label: cancel,
          feel: Press.back,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        NoirAction(
          key: confirmKey,
          label: confirm,
          style: danger ? NoirButtonStyle.danger : NoirButtonStyle.primary,
          feel: Press.confirm,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    ),
  );
  return yes == true;
}

// ---------------------------------------------------------------------------
// Sheet

/// Opens a sheet from the bottom of the phone (grab handle, at most 90% of
/// the screen, clear of the home bar and the keyboard). On the desktop
/// canvas it opens as a centred card instead. With [heightFactor] the
/// sheet takes that share of the screen and its content fills it.
Future<T?> showNoirSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  double? heightFactor,
  bool dismissible = true,
}) {
  if (DesktopCanvas.peek(context)) {
    return showNoirDialog<T>(
      context,
      dismissible: dismissible,
      builder: (context) => _SheetHeight(heightFactor: heightFactor, child: builder(context)),
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: dismissible,
    enableDrag: dismissible,
    backgroundColor: Colors.transparent,
    barrierColor: NoirInk.barrier,
    elevation: 0,
    constraints: const BoxConstraints(maxWidth: 640),
    sheetAnimationStyle: const AnimationStyle(duration: Duration(milliseconds: 260), reverseDuration: Duration(milliseconds: 180)),
    builder: (context) => _SheetHeight(heightFactor: heightFactor, child: builder(context)),
  );
}

class _SheetHeight extends StatelessWidget {
  final double? heightFactor;
  final Widget child;

  const _SheetHeight({required this.heightFactor, required this.child});

  @override
  Widget build(BuildContext context) {
    final factor = heightFactor;
    final screen = MediaQuery.sizeOf(context).height;
    if (factor == null) return ConstrainedBox(constraints: BoxConstraints(maxHeight: screen * 0.9), child: child);
    final height = screen * factor;
    return SizedBox(height: height, child: _SheetFill(child: child));
  }
}

/// Tells a [NoirSheet] it has a fixed height to fill.
class _SheetFill extends InheritedWidget {
  const _SheetFill({required super.child});

  static bool of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_SheetFill>() != null;

  @override
  bool updateShouldNotify(_SheetFill oldWidget) => false;
}

/// The sheet: grab handle, a title row (title, a line under it, an
/// optional ×), the content with comfortable margins. The content scrolls
/// when it is long. [scroll] false hands the content the space as it is
/// (for lists that scroll on their own).
class NoirSheet extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget? header;
  final List<Widget> children;
  final bool scroll;
  final EdgeInsets? padding;

  const NoirSheet({
    super.key,
    this.title,
    this.subtitle,
    this.header,
    required this.children,
    this.scroll = true,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final m = NoirMetrics.of(context);
    final fill = _SheetFill.of(context);
    final media = MediaQuery.of(context);
    final side = m.desk ? m.pad : 16.0;
    final head = <Widget>[
      if (header case final header?) ...[header, SizedBox(height: m.gap)],
      if (title case final title?)
        Text(title, textAlign: TextAlign.center, style: NoirType.title(m).copyWith(fontSize: m.desk ? 30 : 20)),
      if (subtitle case final subtitle?) ...[
        SizedBox(height: m.gap * 0.75),
        Text(subtitle, textAlign: TextAlign.center, style: NoirType.small(m, color: NoirInk.body).copyWith(fontSize: m.desk ? 18 : 14)),
      ],
      if (title != null) ...[SizedBox(height: m.gap * 1.5), Center(child: _Ornament(color: NoirInk.brass.withValues(alpha: 0.5)))],
    ];
    final contentPad = padding ?? EdgeInsets.fromLTRB(side, m.gap * 2, side, m.desk ? m.pad - 8 : 16);
    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
    final Widget content = scroll ? SingleChildScrollView(padding: contentPad, child: body) : Padding(padding: contentPad, child: body);
    final column = Column(
      mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!m.desk)
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 8, bottom: 12),
              decoration: BoxDecoration(color: NoirInk.brassDeep, borderRadius: BorderRadius.circular(2)),
            ),
          )
        else
          SizedBox(height: m.pad - 8),
        if (head.isNotEmpty) Padding(padding: EdgeInsets.symmetric(horizontal: side + (m.desk ? 40 : 28)), child: Column(children: head)),
        if (fill || !scroll) Expanded(child: content) else Flexible(child: content),
      ],
    );
    if (m.desk) {
      final screen = media.size;
      return Stack(
        children: [
          Container(
            width: m.sheetWidth,
            constraints: BoxConstraints(maxHeight: screen.height - 120),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF261E19), NoirInk.card, NoirInk.cardDeep],
              ),
              borderRadius: BorderRadius.circular(m.radius),
              border: Border.all(color: NoirInk.brass.withValues(alpha: 0.55), width: 1.2),
              boxShadow: const [BoxShadow(color: Color(0xCC000000), blurRadius: 48, offset: Offset(0, 20))],
            ),
            child: column,
          ),
          Positioned(top: 16, right: 16, child: const NoirCloseButton()),
        ],
      );
    }
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF221A15), NoirInk.cardDeep],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: NoirInk.brass, width: 1.2)),
        boxShadow: [BoxShadow(color: Color(0xAA000000), blurRadius: 24, offset: Offset(0, -6))],
      ),
      padding: EdgeInsets.only(bottom: max(media.viewPadding.bottom, media.viewInsets.bottom)),
      child: column,
    );
  }
}

// ---------------------------------------------------------------------------
// Menu

enum NoirMenuTone { normal, danger, dim }

/// One line of a [showNoirMenu].
class NoirMenuItem<T> {
  final T value;
  final String label;
  final IconData icon;
  final String? detail;
  final NoirMenuTone tone;
  final Key? key;
  final Widget? leading;

  const NoirMenuItem({
    required this.value,
    required this.label,
    required this.icon,
    this.detail,
    this.tone = NoirMenuTone.normal,
    this.key,
    this.leading,
  });
}

/// The menu on a player, a seat, a message: who it is about (title, maybe
/// a quoted line in [header]), then one row per action, the risky ones in
/// red, set apart. Returns the chosen value, or null.
Future<T?> showNoirMenu<T>(
  BuildContext context, {
  required String title,
  String? subtitle,
  Widget? header,
  required List<NoirMenuItem<T>> items,
  Key? key,
}) =>
    showNoirSheet<T>(
      context,
      builder: (context) => NoirSheet(
        key: key,
        title: title,
        subtitle: subtitle,
        children: [
          if (header case final header?) ...[header, SizedBox(height: NoirMetrics.of(context).gap * 2)],
          NoirMenuGroup(
            children: [
              for (final item in items.where((i) => i.tone != NoirMenuTone.danger)) _MenuRow(item: item),
            ],
          ),
          if (items.any((i) => i.tone == NoirMenuTone.danger)) ...[
            SizedBox(height: NoirMetrics.of(context).gap * 1.5),
            NoirMenuGroup(
              danger: true,
              children: [
                for (final item in items.where((i) => i.tone == NoirMenuTone.danger)) _MenuRow(item: item),
              ],
            ),
          ],
        ],
      ),
    );

/// A group of menu rows in one rimmed panel, hairlines between them.
class NoirMenuGroup extends StatelessWidget {
  final List<Widget> children;
  final bool danger;

  /// Where the hairlines start: after the icons, or (false) edge to edge.
  final bool indent;

  const NoirMenuGroup({super.key, required this.children, this.danger = false, this.indent = true});

  @override
  Widget build(BuildContext context) {
    final m = NoirMetrics.of(context);
    final rim = (danger ? NoirInk.blood : NoirInk.brass).withValues(alpha: 0.32);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.025),
        borderRadius: BorderRadius.circular(m.desk ? 16 : 14),
        border: Border.all(color: rim),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, child) in children.indexed) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: rim, indent: indent ? (m.desk ? 72 : 56) : 0),
            child,
          ],
        ],
      ),
    );
  }
}

class _MenuRow<T> extends StatelessWidget {
  final NoirMenuItem<T> item;

  const _MenuRow({required this.item});

  @override
  Widget build(BuildContext context) => NoirMenuRow(
        key: item.key,
        icon: item.icon,
        label: item.label,
        detail: item.detail,
        tone: item.tone,
        leading: item.leading,
        onTap: () => Navigator.of(context).pop(item.value),
      );
}

/// One row of a menu, usable on its own inside a [NoirMenuGroup].
class NoirMenuRow extends StatefulWidget {
  final IconData icon;
  final String label;
  final String? detail;
  final NoirMenuTone tone;
  final Widget? leading;
  final VoidCallback? onTap;

  const NoirMenuRow({
    super.key,
    required this.icon,
    required this.label,
    this.detail,
    this.tone = NoirMenuTone.normal,
    this.leading,
    required this.onTap,
  });

  @override
  State<NoirMenuRow> createState() => _NoirMenuRowState();
}

class _NoirMenuRowState extends State<NoirMenuRow> {
  bool _lit = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final m = NoirMetrics.of(context);
    final color = switch (widget.tone) {
      NoirMenuTone.danger => NoirInk.blood,
      NoirMenuTone.dim => NoirInk.muted,
      NoirMenuTone.normal => NoirInk.brass,
    };
    final text = switch (widget.tone) {
      NoirMenuTone.danger => NoirInk.blood,
      NoirMenuTone.dim => NoirInk.body,
      NoirMenuTone.normal => NoirInk.text,
    };
    return FocusableActionDetector(
      enabled: widget.onTap != null,
      mouseCursor: SystemMouseCursors.click,
      onShowHoverHighlight: (on) => setState(() => _lit = on),
      onShowFocusHighlight: (on) => setState(() => _lit = on),
      actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => pressed(widget.onTap)?.call())},
      child: Semantics(
        button: true,
        label: widget.label,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _down = true),
          onTapUp: (_) => setState(() => _down = false),
          onTapCancel: () => setState(() => _down = false),
          onTap: pressed(widget.onTap),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            constraints: BoxConstraints(minHeight: m.row),
            color: _down
                ? color.withValues(alpha: 0.16)
                : _lit
                    ? color.withValues(alpha: 0.09)
                    : Colors.transparent,
            padding: EdgeInsets.symmetric(horizontal: m.desk ? 24 : 16, vertical: m.gap),
            child: Row(
              children: [
                SizedBox(
                  width: m.desk ? 32 : 24,
                  child: widget.leading ?? Icon(widget.icon, size: m.icon, color: color),
                ),
                SizedBox(width: m.desk ? 16 : 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(widget.label, style: NoirType.label(m, color: text)),
                      if (widget.detail case final detail?)
                        Padding(padding: const EdgeInsets.only(top: 2), child: Text(detail, style: NoirType.small(m))),
                    ],
                  ),
                ),
                if (widget.tone != NoirMenuTone.danger)
                  Icon(Icons.chevron_right, size: m.desk ? 26 : 20, color: NoirInk.muted.withValues(alpha: _lit ? 1 : 0.6)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Form bits

/// A text field in the kit's style: a dark well with a brass focus rim.
class NoirField extends StatelessWidget {
  final TextEditingController? controller;
  final String? hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final int? maxLength;
  final int minLines;
  final int maxLines;
  final bool autocorrect;
  final TextCapitalization capitalization;

  const NoirField({
    super.key,
    this.controller,
    this.hint,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.maxLength,
    this.minLines = 1,
    this.maxLines = 1,
    this.autocorrect = true,
    this.capitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    final m = NoirMetrics.of(context);
    OutlineInputBorder rim(Color color, [double width = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(m.desk ? 12 : 10),
          borderSide: BorderSide(color: color, width: width),
        );
    return TextField(
      controller: controller,
      autofocus: autofocus,
      autocorrect: autocorrect,
      textCapitalization: capitalization,
      maxLength: maxLength,
      minLines: minLines,
      maxLines: maxLines,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      cursorColor: NoirInk.brass,
      style: TextStyle(color: NoirInk.text, fontSize: m.body),
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        hintStyle: TextStyle(color: NoirInk.muted, fontSize: m.body),
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.35),
        counterStyle: NoirType.small(m).copyWith(fontSize: m.small - 1),
        contentPadding: EdgeInsets.symmetric(horizontal: m.desk ? 20 : 14, vertical: m.desk ? 18 : 14),
        enabledBorder: rim(NoirInk.brass.withValues(alpha: 0.3)),
        focusedBorder: rim(NoirInk.brass, 1.4),
      ),
    );
  }
}

/// A quoted line (a chat message) in a soft panel.
class NoirQuote extends StatelessWidget {
  final String text;

  const NoirQuote(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final m = NoirMetrics.of(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: m.desk ? 20 : 14, vertical: m.desk ? 14 : 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(m.desk ? 12 : 10),
        border: Border(left: BorderSide(color: NoirInk.brass.withValues(alpha: 0.7), width: 3)),
      ),
      child: Text(
        '«$text»',
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
        style: NoirType.body(m, color: NoirInk.text).copyWith(fontStyle: FontStyle.italic),
      ),
    );
  }
}

/// An error line inside a card: red, with a small mark.
class NoirErrorLine extends StatelessWidget {
  final String text;

  const NoirErrorLine(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final m = NoirMetrics.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.error_outline, size: m.desk ? 22 : 16, color: const Color(0xFFFF8A80)),
        SizedBox(width: m.gap),
        Expanded(child: Text(text, style: NoirType.small(m, color: const Color(0xFFFF8A80)))),
      ],
    );
  }
}
