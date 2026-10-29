import 'dart:math';

import 'package:flutter/material.dart';

import '../../../online/online_models.dart';
import '../../avatar/avatar_look.dart';
import '../platform_marks.dart';

/// Un nome scritto con l'inchiostro della bottega: sulla targhetta del posto,
/// in chat, ovunque compaia chi l'ha comprato. Senza [style] usa quello di
/// chi si chiama [name] ([AvatarLook.of]); [NameStyle.plain] è un [Text]
/// qualunque con [base].
///
/// [text] è quello che si scrive (di solito il nome stesso, magari in
/// maiuscolo o col numero del posto davanti).
class StyledName extends StatefulWidget {
  final String name;
  final String? text;
  final NameStyle? style;
  final TextStyle? base;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;
  final bool softWrap;

  /// I loghi delle piattaforme (Steam, Apple) dopo il nome, se ci sono.
  final bool marks;

  const StyledName(
    this.name, {
    super.key,
    this.text,
    this.style,
    this.base,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
    this.textAlign,
    this.softWrap = false,
    this.marks = true,
  });

  /// Lo stile di chi si chiama [name].
  static NameStyle styleOf(String name) => AvatarLook.of(name).nameStyle;

  /// Il nome dentro un testo ([Text.rich], le righe della chat): un pezzo
  /// di testo normale se l'inchiostro è [NameStyle.plain], altrimenti il
  /// nome con il suo stile, sulla stessa riga di base.
  static InlineSpan span(String name, {required String text, required TextStyle style, NameStyle? nameStyle}) {
    final ink = nameStyle ?? styleOf(name);
    final mark = PlayerMarks.of(name);
    if (ink == NameStyle.plain && !mark.steam && !mark.apple) return TextSpan(text: text, style: style);
    return WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: StyledName(name, text: text, style: ink, base: style, maxLines: 1, overflow: TextOverflow.visible),
    );
  }

  /// Il colore pieno di [style], o null per gli inchiostri a sfumatura.
  static Color? solid(NameStyle style) => switch (style) {
        NameStyle.crimson => const Color(0xFFE0394A),
        NameStyle.emerald => const Color(0xFF3FCB8A),
        NameStyle.sapphire => const Color(0xFF5FA2FF),
        NameStyle.violet => const Color(0xFFB487FF),
        NameStyle.neonGlow => const Color(0xFFFFB3E2),
        _ => null,
      };

  /// I colori della sfumatura, per gli inchiostri che ne hanno una.
  static List<Color>? gradient(NameStyle style) => switch (style) {
        NameStyle.goldFoil => const [Color(0xFFA8761E), Color(0xFFFFE7A0), Color(0xFFD3A23C), Color(0xFFFFF4CF), Color(0xFF9C6A16)],
        NameStyle.silverFoil => const [Color(0xFF8C9298), Color(0xFFF4F7FA), Color(0xFFB5BCC3), Color(0xFFFFFFFF), Color(0xFF7E848A)],
        NameStyle.tramonto => const [Color(0xFFFFC14D), Color(0xFFFF6F4A), Color(0xFFE2366F), Color(0xFF8A3BC6)],
        NameStyle.shimmer => const [Color(0xFFB8862B), Color(0xFFFFE9A6), Color(0xFFFFFFFF), Color(0xFFFFE9A6), Color(0xFFB8862B)],
        NameStyle.inferno => const [Color(0xFFFFF2B0), Color(0xFFFFB02E), Color(0xFFFF5A1A), Color(0xFFC81E12), Color(0xFFFFB02E)],
        NameStyle.moonlight => const [Color(0xFF8FA6C8), Color(0xFFEAF2FF), Color(0xFFB9C9E4), Color(0xFFFFFFFF), Color(0xFF7D93B8)],
        NameStyle.bloodInk => const [Color(0xFFA8142A), Color(0xFFE8283E), Color(0xFFB01628), Color(0xFFFF5A66), Color(0xFF9A1022)],
        NameStyle.siren => const [Color(0xFF3D7BFF), Color(0xFF9EC0FF), Color(0xFFFF4A4A), Color(0xFFFFB0B0), Color(0xFF3D7BFF)],
        _ => null,
      };

  @override
  State<StyledName> createState() => _StyledNameState();
}

class _StyledNameState extends State<StyledName> with SingleTickerProviderStateMixin {
  AnimationController? _clock;

  NameStyle get _style => widget.style ?? StyledName.styleOf(widget.name);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(StyledName old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final moving = _style.animated && !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    if (moving && _clock == null) {
      _clock = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..repeat();
    } else if (!moving && _clock != null) {
      _clock!.dispose();
      _clock = null;
    }
  }

  @override
  void dispose() {
    _clock?.dispose();
    super.dispose();
  }

  Text _text(TextStyle style) => Text(
        widget.text ?? widget.name,
        style: style,
        maxLines: widget.maxLines,
        overflow: widget.overflow,
        textAlign: widget.textAlign,
        softWrap: widget.softWrap,
      );

  @override
  Widget build(BuildContext context) {
    final name = _name(context);
    if (!widget.marks) return name;
    return ValueListenableBuilder<int>(
      valueListenable: PlayerMarks.changes,
      builder: (context, _, child) {
        final mark = PlayerMarks.of(widget.name);
        if (!mark.steam && !mark.apple) return child!;
        final base = DefaultTextStyle.of(context).style.merge(widget.base);
        final size = (base.fontSize ?? 14) * 0.85;
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(child: child!),
            PlatformBadges(widget.name, size: size, gap: size * 0.4, color: (base.color ?? Colors.white).withValues(alpha: 0.85)),
          ],
        );
      },
      child: name,
    );
  }

  Widget _name(BuildContext context) {
    final base = DefaultTextStyle.of(context).style.merge(widget.base);
    final style = _style;
    final size = base.fontSize ?? 14;
    if (style == NameStyle.plain) return _text(base);
    if (StyledName.solid(style) case final color?) {
      final glow = style == NameStyle.neonGlow;
      return _text(base.copyWith(
        color: color,
        shadows: glow
            ? [
                Shadow(color: const Color(0xFFFF3FB0), blurRadius: size * 0.35),
                Shadow(color: const Color(0xFFFF3FB0), blurRadius: size * 0.9),
                Shadow(color: const Color(0xAAFF1F9A), blurRadius: size * 1.6),
              ]
            : [Shadow(color: Colors.black.withValues(alpha: 0.7), blurRadius: 2, offset: const Offset(0, 1))],
      ));
    }
    final colors = StyledName.gradient(style)!;
    // Il testo bianco fa da stampo; l'ombra resta fuori dalla maschera.
    final shadow = switch (style) {
      NameStyle.inferno => [Shadow(color: const Color(0xCCFF4A10), blurRadius: size * 0.7)],
      NameStyle.shimmer => [Shadow(color: const Color(0x88FFD36A), blurRadius: size * 0.5)],
      NameStyle.moonlight => [Shadow(color: const Color(0x887FA8FF), blurRadius: size * 0.45)],
      _ => [Shadow(color: Colors.black.withValues(alpha: 0.75), blurRadius: 2, offset: const Offset(0, 1))],
    };
    Widget masked(double t) => Stack(
          children: [
            _text(base.copyWith(color: Colors.transparent, shadows: shadow)),
            ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (rect) => _shader(style, colors, rect, t),
              child: _text(base.copyWith(color: Colors.white, shadows: const [])),
            ),
          ],
        );
    final clock = _clock;
    if (clock == null) return masked(0.3);
    // La luce che scorre ridisegna solo il nome, non quello che ha intorno.
    return RepaintBoundary(child: AnimatedBuilder(animation: clock, builder: (context, _) => masked(clock.value)));
  }

  static Shader _shader(NameStyle style, List<Color> colors, Rect rect, double t) {
    switch (style) {
      case NameStyle.shimmer:
        // Una lama di luce che passa da sinistra a destra.
        final x = -1.6 + t * 3.2;
        return LinearGradient(
          begin: Alignment(x - 0.9, -0.4),
          end: Alignment(x + 0.9, 0.4),
          colors: colors,
          stops: const [0, 0.38, 0.5, 0.62, 1],
          tileMode: TileMode.clamp,
        ).createShader(rect);
      case NameStyle.inferno:
        // Il fuoco sale.
        final h = max(rect.height, 1.0);
        return LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: colors,
          tileMode: TileMode.mirror,
          transform: _Shift(dy: -t * h * 2),
        ).createShader(Rect.fromLTWH(rect.left, rect.top, rect.width, h));
      case NameStyle.tramonto:
        return LinearGradient(colors: colors).createShader(rect);
      case NameStyle.siren:
        // The police lights: blue at one end, red at the other, whatever
        // the length of the name.
        return LinearGradient(colors: colors.take(4).toList(), stops: const [0, 0.42, 0.58, 1]).createShader(rect);
      default:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
          tileMode: TileMode.mirror,
        ).createShader(Rect.fromLTWH(rect.left, rect.top, max(rect.width * 0.5, 30), rect.height));
    }
  }
}

class _Shift extends GradientTransform {
  final double dy;
  const _Shift({required this.dy});

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) => Matrix4.translationValues(0, dy, 0);
}
