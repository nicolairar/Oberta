import 'dart:math';

import 'package:flutter/material.dart';

import '../../online/online_models.dart';
import '../avatar/avatar_look.dart';
import '../press.dart';
import '../theme/app_theme.dart';
import 'player_avatar.dart';

const _cream = Color(0xFFE9DEC4);
const _iron = Color(0xFF08080B);

/// Lo smalto delle targhette del vicolo: blu notte, con il riflesso rosso
/// dell'insegna su un fianco. Lo stesso della targhetta delle impostazioni.
void _paintEnamel(Canvas canvas, RRect shape, {required bool pressed}) {
  canvas.drawRRect(shape.shift(const Offset(1.5, 2.5)), Paint()..color = Colors.black.withValues(alpha: 0.6));
  canvas.drawRRect(shape, Paint()..color = _iron);
  final inner = shape.deflate(2);
  canvas.drawRRect(
    inner,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: pressed
            ? const [Color(0xFF1B1F2C), Color(0xFF0B0D14)]
            : const [Color(0xFF3A3144), Color(0xFF171A27), Color(0xFF0C0E16)],
      ).createShader(inner.outerRect),
  );
  // Il filo di neon riflesso sul bordo alto.
  final glint = inner.deflate(3);
  canvas.drawLine(
    Offset(glint.left + glint.height * 0.5, glint.top),
    Offset(glint.left + glint.width * 0.42, glint.top),
    Paint()
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFFF6A5A).withValues(alpha: pressed ? 0.15 : 0.40),
  );
}

void _paintScrew(Canvas canvas, Offset at, double radius) {
  canvas.drawCircle(at, radius, Paint()..color = _iron);
  canvas.drawCircle(at.translate(-0.4, -0.4), radius * 0.42, Paint()..color = Colors.white.withValues(alpha: 0.25));
}

/// «Accedi»: una targhetta di smalto avvitata al muro accanto
/// all'ingranaggio, con il buco della serratura. Toccata apre l'accesso;
/// tenuta premuta, l'account di prova.
class HomeSignInPlate extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const HomeSignInPlate({super.key, required this.label, required this.onTap, this.onLongPress});

  @override
  State<HomeSignInPlate> createState() => _HomeSignInPlateState();
}

class _HomeSignInPlateState extends State<HomeSignInPlate> {
  bool _pressed = false;

  void _press(bool down) {
    if (_pressed != down) setState(() => _pressed = down);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _press(true),
        onTapUp: (_) => _press(false),
        onTapCancel: () => _press(false),
        onTap: pressed(widget.onTap, Press.toggle),
        onLongPress: widget.onLongPress == null
            ? null
            : () {
                _press(false);
                widget.onLongPress!();
              },
        child: CustomPaint(
          painter: _SignInPlatePainter(_pressed),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 14, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(width: 9, height: 14, child: CustomPaint(painter: _KeyholePainter())),
                const SizedBox(width: 8),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      style: TextStyle(
                        fontFamily: 'Georgia',
                        fontFamilyFallback: const ['serif'],
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.2,
                        color: _cream.withValues(alpha: _pressed ? 0.6 : 0.95),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SignInPlatePainter extends CustomPainter {
  final bool pressed;

  _SignInPlatePainter(this.pressed);

  @override
  void paint(Canvas canvas, Size size) {
    final shape = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(size.height * 0.22));
    _paintEnamel(canvas, shape, pressed: pressed);
    // Il filetto dorato all'interno, come sulle targhe vere.
    canvas.drawRRect(
      shape.deflate(4.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = AppColors.gold.withValues(alpha: pressed ? 0.25 : 0.55),
    );
    _paintScrew(canvas, Offset(7.5, size.height / 2), 1.8);
    _paintScrew(canvas, Offset(size.width - 7.5, size.height / 2), 1.8);
  }

  @override
  bool shouldRepaint(_SignInPlatePainter old) => old.pressed != pressed;
}

class _KeyholePainter extends CustomPainter {
  const _KeyholePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final ink = Paint()..color = AppColors.gold;
    final r = size.width / 2;
    canvas.drawCircle(Offset(r, r), r, ink);
    canvas.drawPath(
      Path()
        ..moveTo(r - r * 0.45, r)
        ..lineTo(r + r * 0.45, r)
        ..lineTo(r + r * 0.85, size.height)
        ..lineTo(r - r * 0.85, size.height)
        ..close(),
      ink,
    );
  }

  @override
  bool shouldRepaint(_KeyholePainter old) => false;
}

/// Una moneta d'oro, col bordo zigrinato: le monete del profilo.
class CoinPainter extends CustomPainter {
  const CoinPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF7A5A12));
    canvas.drawCircle(
      c,
      r * 0.88,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.4),
          colors: [Color(0xFFFFE9A0), AppColors.gold, Color(0xFF8C6A14)],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawCircle(
      c,
      r * 0.58,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(0.7, r * 0.12)
        ..color = const Color(0xFF7A5A12).withValues(alpha: 0.8),
    );
  }

  @override
  bool shouldRepaint(CoinPainter old) => false;
}

/// Il cartellino di chi è entrato, in alto a sinistra: il ritratto a mezzo
/// busto che sporge da una targhetta di smalto, il nome, il livello e le
/// monete. Toccato apre il profilo.
class HomeProfileBadge extends StatefulWidget {
  /// Il profilo, o null mentre arriva dal server.
  final Profile? profile;

  /// Che cosa scrivere al posto del nome se il profilo è da finire.
  final String pickHandle;
  final String Function(int level) levelLabel;
  final String coinsLabel;
  final VoidCallback onTap;

  /// Toccando le monete si entra in bottega.
  final VoidCallback? onShop;

  const HomeProfileBadge({
    super.key,
    required this.profile,
    required this.pickHandle,
    required this.levelLabel,
    required this.coinsLabel,
    required this.onTap,
    this.onShop,
  });

  @override
  State<HomeProfileBadge> createState() => _HomeProfileBadgeState();
}

class _HomeProfileBadgeState extends State<HomeProfileBadge> {
  bool _pressed = false;

  void _press(bool down) {
    if (_pressed != down) setState(() => _pressed = down);
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final complete = profile?.isComplete ?? false;
    final name = profile == null ? '…' : (complete ? profile.name : widget.pickHandle);
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final bust = h;
        final plateTop = h * 0.14;
        return Semantics(
          button: true,
          label: profile == null
              ? name
              : '$name, ${widget.levelLabel(profile.level)}, ${profile.coins} ${widget.coinsLabel}',
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => _press(true),
            onTapUp: (_) => _press(false),
            onTapCancel: () => _press(false),
            onTap: pressed(widget.onTap, Press.toggle),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: bust * 0.5,
                  right: 0,
                  top: plateTop,
                  bottom: plateTop,
                  child: CustomPaint(painter: _BadgePlatePainter(_pressed)),
                ),
                Positioned(
                  left: bust + 8,
                  right: 14,
                  top: plateTop,
                  bottom: plateTop,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Georgia',
                          fontFamilyFallback: const ['serif'],
                          fontSize: 13.5,
                          height: 1.1,
                          fontWeight: FontWeight.bold,
                          fontStyle: complete || profile == null ? FontStyle.normal : FontStyle.italic,
                          color: complete || profile == null ? _cream : AppColors.gold,
                        ),
                      ),
                      if (profile != null) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            _LevelTag(widget.levelLabel(profile.level)),
                            const SizedBox(width: 6),
                            Flexible(
                              child: GestureDetector(
                                key: const Key('home.shop'),
                                behavior: HitTestBehavior.opaque,
                                onTap: pressed(widget.onShop, Press.toggle),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 2),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const SizedBox.square(dimension: 11, child: CustomPaint(painter: CoinPainter())),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          '${profile.coins}',
                                          key: const Key('home.coins'),
                                          maxLines: 1,
                                          overflow: TextOverflow.fade,
                                          softWrap: false,
                                          style: const TextStyle(
                                            color: _cream,
                                            fontSize: 11,
                                            height: 1,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.6,
                                          ),
                                        ),
                                      ),
                                      if (widget.onShop != null) ...[
                                        const SizedBox(width: 3),
                                        const Icon(Icons.add_circle, size: 11, color: AppColors.gold),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                // Il ritratto sporge dalla targhetta, dentro un cerchio d'ottone.
                Positioned(
                  left: 0,
                  top: 0,
                  width: bust,
                  height: bust,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _iron,
                      border: Border.all(color: AppColors.gold.withValues(alpha: _pressed ? 0.5 : 0.9), width: 2),
                      boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 6, offset: Offset(1, 3))],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: PlayerAvatar(seed: profile?.name ?? '?', look: profile?.look, size: bust - 8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LevelTag extends StatelessWidget {
  final String label;

  const _LevelTag(this.label);

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.gold,
          borderRadius: BorderRadius.circular(3),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
          child: Text(
            label,
            key: const Key('home.level'),
            style: const TextStyle(
              color: _iron,
              fontSize: 9,
              height: 1.1,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
        ),
      );
}

class _BadgePlatePainter extends CustomPainter {
  final bool pressed;

  _BadgePlatePainter(this.pressed);

  @override
  void paint(Canvas canvas, Size size) {
    final shape = RRect.fromRectAndCorners(
      Offset.zero & size,
      topRight: Radius.circular(size.height * 0.22),
      bottomRight: Radius.circular(size.height * 0.22),
    );
    _paintEnamel(canvas, shape, pressed: pressed);
    _paintScrew(canvas, Offset(size.width - 7, size.height / 2), 1.8);
  }

  @override
  bool shouldRepaint(_BadgePlatePainter old) => old.pressed != pressed;
}

/// Il suggerimento per chi tocca «Gioca con amici» senza essere entrato: il
/// vicolo si spegne, resta acceso solo un cerchio di luce sulla targhetta
/// «Accedi», con due parole e una freccia. Toccando la luce si entra;
/// toccando altrove il vicolo si riaccende.
class HomeCoachMark extends StatelessWidget {
  final Rect target;
  final String caption;
  final VoidCallback onTarget;
  final VoidCallback onDismiss;

  /// Senza dissolvenza, per chi ha chiesto le animazioni ridotte.
  final bool still;

  const HomeCoachMark({
    super.key,
    required this.target,
    required this.caption,
    required this.onTarget,
    required this.onDismiss,
    this.still = false,
  });

  /// Il buco di luce, poco più grande della targhetta.
  Rect get spotlight => target.inflate(9);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final width = min(260.0, size.width - 40);
        final captionTop = spotlight.bottom + 62;
        final captionRight = max(20.0, size.width - spotlight.right);
        final layer = GestureDetector(
          key: const Key('home.coach'),
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) => spotlight.contains(details.localPosition) ? onTarget() : onDismiss(),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                painter: _CoachPainter(spotlight: spotlight, captionTop: captionTop, captionRight: size.width - captionRight),
              ),
              Positioned.fromRect(
                rect: spotlight,
                child: Semantics(button: true, label: caption, child: const SizedBox.expand()),
              ),
              Positioned(
                top: captionTop,
                right: captionRight,
                width: width,
                child: Text(
                  caption,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontFamily: 'Georgia',
                    fontFamilyFallback: ['serif'],
                    fontSize: 21,
                    height: 1.2,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.bold,
                    color: _cream,
                    shadows: [Shadow(color: Colors.black, blurRadius: 8)],
                  ),
                ),
              ),
            ],
          ),
        );
        if (still) return layer;
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
          builder: (context, t, child) => Opacity(opacity: t, child: child),
          child: layer,
        );
      },
    );
  }
}

class _CoachPainter extends CustomPainter {
  final Rect spotlight;
  final double captionTop;

  /// Dove finisce, a destra, la didascalia: la freccia parte da lì sopra.
  final double captionRight;

  _CoachPainter({required this.spotlight, required this.captionTop, required this.captionRight});

  @override
  void paint(Canvas canvas, Size size) {
    final hole = RRect.fromRectAndRadius(spotlight, Radius.circular(spotlight.height / 2));
    canvas.drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(Offset.zero & size)
        ..addRRect(hole),
      Paint()..color = const Color(0xD8050407),
    );
    // L'alone intorno alla luce, e il suo bordo d'oro.
    canvas.drawRRect(
      hole.inflate(3),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = AppColors.gold.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawRRect(
      hole,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = AppColors.gold.withValues(alpha: 0.9),
    );

    // La freccia, tracciata a mano: sale dalla didascalia e punta la luce.
    final from = Offset(captionRight - 34, captionTop - 8);
    final to = Offset(spotlight.center.dx - spotlight.width * 0.18, spotlight.bottom + 8);
    final bend = Offset(min(from.dx, to.dx) - 34, (from.dy + to.dy) / 2 + 6);
    final ink = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = _cream;
    canvas.drawPath(Path()..moveTo(from.dx, from.dy)..quadraticBezierTo(bend.dx, bend.dy, to.dx, to.dy), ink);
    // La punta segue la direzione della curva nell'ultimo tratto.
    final direction = to - bend;
    final angle = atan2(direction.dy, direction.dx);
    const spread = 0.5;
    const length = 11.0;
    for (final side in [-1, 1]) {
      final a = angle + pi + side * spread;
      canvas.drawLine(to, to + Offset(cos(a), sin(a)) * length, ink);
    }
  }

  @override
  bool shouldRepaint(_CoachPainter old) =>
      old.spotlight != spotlight || old.captionTop != captionTop || old.captionRight != captionRight;
}
