import 'dart:math';

import 'package:flutter/material.dart';

import '../../online/online_models.dart';
import '../avatar/avatar_look.dart';
import '../press.dart';
import '../theme/app_theme.dart';
import 'player_avatar.dart';
import 'targa.dart';

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
          painter: TargaPainter(down: _pressed, radius: 12),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 14, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(width: 9, height: 14, child: CustomPaint(painter: _KeyholePainter(Targa.brass))),
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
                        color: Targa.cream.withValues(alpha: _pressed ? 0.7 : 1),
                        shadows: const [Shadow(color: Color(0x99000000), offset: Offset(0, 1.5), blurRadius: 1)],
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

class _KeyholePainter extends CustomPainter {
  final Color color;
  const _KeyholePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final ink = Paint()..color = color;
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
  bool shouldRepaint(_KeyholePainter old) => old.color != color;
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

  /// Toccando il ritratto, o la targhetta «Il tuo look» appesa sotto, si
  /// apre lo specchio del barbiere.
  final VoidCallback? onMirror;
  final String? mirrorLabel;

  /// Il fascicolo delle missioni, con il bollino rosso di quelle da
  /// riscuotere ([missionsWaiting]).
  final VoidCallback? onMissions;
  final String? missionsLabel;
  final int missionsWaiting;

  const HomeProfileBadge({
    super.key,
    required this.profile,
    required this.pickHandle,
    required this.levelLabel,
    required this.coinsLabel,
    required this.onTap,
    this.onShop,
    this.onMirror,
    this.mirrorLabel,
    this.onMissions,
    this.missionsLabel,
    this.missionsWaiting = 0,
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
                      Row(
                        children: [
                          Flexible(
                            child: Text(
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
                          ),
                          if (widget.onMissions != null && profile != null) ...[
                            const SizedBox(width: 6),
                            _MissionsTag(
                              label: widget.missionsLabel ?? '',
                              waiting: widget.missionsWaiting,
                              onTap: pressed(widget.onMissions, Press.toggle)!,
                            ),
                          ],
                        ],
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
                                      const SizedBox.square(dimension: 13, child: CustomPaint(painter: CoinPainter())),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          CoinPurse.format(profile.coins),
                                          key: const Key('home.coins'),
                                          maxLines: 1,
                                          overflow: TextOverflow.fade,
                                          softWrap: false,
                                          style: const TextStyle(
                                            color: _cream,
                                            fontSize: 11.5,
                                            height: 1,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.4,
                                            fontFeatures: [FontFeature.tabularFigures()],
                                          ),
                                        ),
                                      ),
                                      if (widget.onShop != null) ...[
                                        const SizedBox(width: 4),
                                        Container(
                                          width: 14,
                                          height: 14,
                                          decoration: const BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: Targa.gold, stops: Targa.goldStops),
                                          ),
                                          child: const Icon(Icons.add, size: 11, color: Color(0xFF2A1A06)),
                                        ),
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
                  child: GestureDetector(
                    key: const Key('home.portrait'),
                    behavior: HitTestBehavior.opaque,
                    onTap: pressed(widget.onTap, Press.toggle),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _iron,
                        border: Border.all(color: AppColors.gold.withValues(alpha: _pressed ? 0.5 : 0.9), width: 2),
                        boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 6, offset: Offset(1, 3))],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: PlayerAvatar(seed: profile?.name ?? '?', look: profile?.look, picture: profile?.pictureUrl, size: bust - 8),
                      ),
                    ),
                  ),
                ),
                // La targhetta d'ottone sotto il ritratto: lo specchio del barbiere.
                if (widget.onMirror != null && widget.mirrorLabel != null)
                  Positioned(
                    left: -4,
                    width: bust + 8,
                    bottom: 0,
                    height: 15,
                    child: GestureDetector(
                      key: const Key('home.mirror'),
                      behavior: HitTestBehavior.opaque,
                      onTap: pressed(widget.onMirror, Press.toggle),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFFF0D27E), Color(0xFFB08A2E)]),
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(color: const Color(0xFF5A3F12), width: 0.8),
                          boxShadow: const [BoxShadow(color: Color(0xAA000000), blurRadius: 3, offset: Offset(0, 1.5))],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.content_cut, size: 9, color: Color(0xFF2A1E16)),
                                const SizedBox(width: 2),
                                Text(
                                  widget.mirrorLabel!,
                                  style: const TextStyle(
                                    color: Color(0xFF2A1E16),
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
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

/// Il fascicolo delle missioni sul cartellino: una cartellina d'ottone, e
/// il bollino rosso con quante aspettano di essere riscosse.
class _MissionsTag extends StatelessWidget {
  final String label;
  final int waiting;
  final VoidCallback onTap;

  const _MissionsTag({required this.label, required this.waiting, required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: waiting > 0 ? '$label, $waiting' : label,
    excludeSemantics: true,
    child: GestureDetector(
      key: const Key('home.missions'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 20,
        height: 16,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: Targa.gold, stops: Targa.goldStops),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: const Icon(Icons.assignment, size: 11, color: Color(0xFF2A1A06)),
              ),
            ),
            if (waiting > 0)
              Positioned(
                right: -5,
                top: -6,
                child: Container(
                  key: const Key('home.missionsWaiting'),
                  constraints: const BoxConstraints(minWidth: 13),
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5404C),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: const Color(0xFF0C0907), width: 1),
                  ),
                  child: Text(
                    '$waiting',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 9, height: 1.3, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _LevelTag extends StatelessWidget {
  final String label;

  const _LevelTag(this.label);

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(3)),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
      child: Text(
        label,
        key: const Key('home.level'),
        style: const TextStyle(color: _iron, fontSize: 9, height: 1.1, fontWeight: FontWeight.w900, letterSpacing: 0.8),
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
                painter: _CoachPainter(
                  spotlight: spotlight,
                  captionTop: captionTop,
                  captionRight: size.width - captionRight,
                ),
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
    canvas.drawPath(
      Path()
        ..moveTo(from.dx, from.dy)
        ..quadraticBezierTo(bend.dx, bend.dy, to.dx, to.dy),
      ink,
    );
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

/// L'insegna della bottega: una tavola di legno laccato appesa con due
/// catenelle a una staffa di ferro, con il cappello e le forbici dipinti in
/// oro e la scritta. Con [fresh], il cartellino rosso «Nuovo» legato
/// all'angolo: la vetrina è cambiata da poco. Stretta, resta solo l'icona.
class HomeShopSign extends StatefulWidget {
  final String label;
  final String? fresh;
  final VoidCallback onTap;

  /// Il disegno accanto alla scritta: il cappello e le forbici della
  /// bottega, o il palo del barbiere.
  final CustomPainter icon;

  const HomeShopSign({super.key, required this.label, required this.onTap, this.fresh, this.icon = const ShopIconPainter()});

  @override
  State<HomeShopSign> createState() => _HomeShopSignState();
}

class _HomeShopSignState extends State<HomeShopSign> with SingleTickerProviderStateMixin {
  bool _pressed = false;

  /// L'insegna dondola appena sulle catenelle, come mossa dal vento.
  late final AnimationController _swing = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _swing
        ..stop()
        ..value = 0;
    } else if (!_swing.isAnimating) {
      _swing.repeat();
    }
  }

  @override
  void dispose() {
    _swing.dispose();
    super.dispose();
  }

  void _press(bool down) {
    if (_pressed != down) setState(() => _pressed = down);
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: widget.label,
    excludeSemantics: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _press(true),
      onTapUp: (_) => _press(false),
      onTapCancel: () => _press(false),
      onTap: pressed(widget.onTap, Press.toggle),
      child: AnimatedBuilder(
        animation: _swing,
        builder: (context, child) =>
            Transform.rotate(angle: 0.035 * sin(_swing.value * 2 * pi), alignment: Alignment.topCenter, child: child),
        child: LayoutBuilder(
          builder: (context, box) {
            final compact = box.maxWidth < 76;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                // La luce calda di una lampada sopra la tavola.
                Positioned.fill(
                  top: _ShopSignPainter.hang,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFB347).withValues(alpha: _pressed ? 0.15 : 0.32),
                          blurRadius: 18,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned.fill(
                  child: CustomPaint(painter: _ShopSignPainter(pressed: _pressed)),
                ),
                Positioned.fill(
                  top: _ShopSignPainter.hang,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox.square(
                          dimension: min(28.0, box.maxHeight - _ShopSignPainter.hang - 8),
                          child: CustomPaint(painter: widget.icon),
                        ),
                        if (!compact) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                widget.label,
                                maxLines: 1,
                                style: TextStyle(
                                  fontFamily: 'Georgia',
                                  fontFamilyFallback: const ['serif'],
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                  color: const Color(0xFFFFDF8A).withValues(alpha: _pressed ? 0.6 : 1),
                                  shadows: const [
                                    Shadow(color: Colors.black, blurRadius: 2, offset: Offset(0, 1)),
                                    Shadow(color: Color(0x99FFB347), blurRadius: 8),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (widget.fresh case final fresh?)
                  Positioned(
                    right: -6,
                    top: _ShopSignPainter.hang - 7,
                    child: Transform.rotate(
                      angle: 0.18,
                      child: Container(
                        key: const Key('home.shopFresh'),
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFC8102E),
                          borderRadius: BorderRadius.circular(2),
                          border: Border.all(color: const Color(0xFFF3D27A), width: 0.8),
                          boxShadow: const [BoxShadow(color: Color(0xAA000000), blurRadius: 3, offset: Offset(0, 1.5))],
                        ),
                        child: Text(
                          fresh,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

class _ShopSignPainter extends CustomPainter {
  /// Quanto spazio prendono in alto la staffa e le catenelle.
  static const hang = 11.0;

  final bool pressed;

  const _ShopSignPainter({required this.pressed});

  @override
  void paint(Canvas canvas, Size size) {
    final iron = Paint()
      ..color = const Color(0xFF2A2A30)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    // La staffa, avvitata al muro.
    canvas.drawLine(Offset(4, 2.5), Offset(size.width - 4, 2.5), iron);
    _paintScrew(canvas, const Offset(4, 2.5), 2);
    _paintScrew(canvas, Offset(size.width - 4, 2.5), 2);
    // Le catenelle: anelli alternati.
    final ring = Paint()
      ..color = const Color(0xFF8C7A55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final x in [size.width * 0.2, size.width * 0.8]) {
      for (var y = 4.0; y < hang; y += 3.2) {
        canvas.drawOval(Rect.fromCenter(center: Offset(x, y + 1.4), width: 2.4, height: 3.4), ring);
      }
    }
    // La tavola.
    final board = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, hang, size.width, size.height - hang),
      const Radius.circular(5),
    );
    canvas.drawRRect(board.shift(const Offset(1.5, 3)), Paint()..color = Colors.black.withValues(alpha: 0.6));
    canvas.drawRRect(
      board,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: pressed
              ? const [Color(0xFF3A1610), Color(0xFF240C08)]
              : const [Color(0xFF7A2E1E), Color(0xFF4E1A10), Color(0xFF32100A)],
        ).createShader(board.outerRect),
    );
    // Le venature del legno.
    final grain = Paint()
      ..color = Colors.black.withValues(alpha: 0.18)
      ..strokeWidth = 0.7;
    for (var y = board.top + 6; y < board.bottom - 3; y += 5) {
      canvas.drawLine(Offset(board.left + 4, y), Offset(board.right - 4, y + 1), grain);
    }
    canvas.drawRRect(
      board.deflate(2.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..color = AppColors.gold.withValues(alpha: pressed ? 0.45 : 0.95),
    );
    // Gli occhielli dove si attaccano le catenelle.
    for (final x in [size.width * 0.2, size.width * 0.8]) {
      canvas.drawCircle(Offset(x, hang + 0.5), 1.8, Paint()..color = AppColors.gold);
    }
  }

  @override
  bool shouldRepaint(_ShopSignPainter old) => old.pressed != pressed;
}

/// Il segno della bottega: un cappello a tesa con, davanti, un paio di
/// forbici da sarto aperte. Dipinto in oro.
/// Il palo del barbiere: il cilindro a strisce rosse, bianche e blu, i
/// pomelli d'ottone.
class BarberPoleIconPainter extends CustomPainter {
  const BarberPoleIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    canvas.save();
    canvas.translate((size.width - s) / 2, (size.height - s) / 2);
    canvas.scale(s / 24);
    const gold = Color(0xFFF3D27A);
    final glass = RRect.fromRectAndRadius(const Rect.fromLTRB(8, 4, 16, 20), const Radius.circular(2));
    canvas.drawRRect(glass, Paint()..color = const Color(0xFFF4EEE2));
    canvas.save();
    canvas.clipRRect(glass);
    final red = Paint()
      ..color = const Color(0xFFC8102E)
      ..strokeWidth = 2.2;
    final blue = Paint()
      ..color = const Color(0xFF1F3F8A)
      ..strokeWidth = 1.2;
    for (var y = -4.0; y < 26; y += 5) {
      canvas.drawLine(Offset(6, y + 6), Offset(18, y), red);
      canvas.drawLine(Offset(6, y + 8.4), Offset(18, y + 2.4), blue);
    }
    canvas.restore();
    canvas.drawRRect(glass, Paint()
      ..color = gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9);
    final brass = Paint()..color = gold;
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(7, 2.4, 17, 4.6), const Radius.circular(1)), brass);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(7, 19.4, 17, 21.6), const Radius.circular(1)), brass);
    canvas.drawCircle(const Offset(12, 1.6), 1.5, brass);
    canvas.drawCircle(const Offset(12, 22.6), 1.3, brass);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ShopIconPainter extends CustomPainter {
  /// Il colore della pittura: oro sulle tavole scure, inchiostro sulla carta.
  final Color color;

  const ShopIconPainter({this.color = const Color(0xFFF3D27A)});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    canvas.save();
    canvas.translate((size.width - s) / 2, (size.height - s) / 2);
    canvas.scale(s / 24);
    final gold = color;
    final fill = Paint()..color = gold;
    // Il cappello: la cupola con la piega, la fascia scura, la tesa.
    final crown = Path()
      ..moveTo(6, 11)
      ..cubicTo(6, 4.5, 8, 3, 12, 3)
      ..cubicTo(16, 3, 18, 4.5, 18, 11)
      ..close();
    canvas.drawPath(crown, fill);
    canvas.drawPath(
      Path()
        ..moveTo(10, 3.6)
        ..quadraticBezierTo(12, 5.5, 14, 3.6),
      Paint()
        ..color = const Color(0xFF4E1A10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.drawRect(const Rect.fromLTRB(6, 8.6, 18, 10.6), Paint()..color = const Color(0xFF32100A));
    canvas.drawOval(const Rect.fromLTRB(1.5, 10, 22.5, 13.4), fill);
    // Le forbici, sotto: due lame incrociate e due anelli.
    final blade = Paint()
      ..color = gold
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(7.5, 15), const Offset(16.5, 22), blade);
    canvas.drawLine(const Offset(16.5, 15), const Offset(7.5, 22), blade);
    final ringPaint = Paint()
      ..color = gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawCircle(const Offset(6.2, 21.6), 1.9, ringPaint);
    canvas.drawCircle(const Offset(17.8, 21.6), 1.9, ringPaint);
    canvas.drawCircle(const Offset(12, 18.5), 0.9, Paint()..color = const Color(0xFF32100A));
    canvas.restore();
  }

  @override
  bool shouldRepaint(ShopIconPainter old) => old.color != color;
}
