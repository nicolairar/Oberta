import 'dart:math';

import 'package:flutter/material.dart';

import '../../../online/online_services.dart';
import '../../avatar/avatar_look.dart';
import '../../desktop/desktop_canvas.dart';
import '../../theme/app_theme.dart';
import '../../widgets/player_avatar.dart';
import 'game/noir_ui.dart';

/// La saletta riservata del caffè, dove si gioca con gli amici: la sorella
/// del retrobottega della classificata. Muro color vino, due applique
/// accese, il tavolo tondo con la tovaglia e il cartellino «RISERVATO».
/// Qui i nomi si vedono: si gioca tra gente che si conosce.
abstract final class Cafe {
  static const wine = Color(0xFF6E1420);
  static const wineDeep = Color(0xFF3A0A10);
  static const cream = Color(0xFFF1E3C4);
  static const background = Color(0xFF0B0506);

  /// Il muro: vino scuro che va nel nero.
  static BoxDecoration wall({Alignment center = const Alignment(0, -0.45)}) => BoxDecoration(
        gradient: RadialGradient(
          center: center,
          radius: 1.15,
          colors: const [Color(0xFF3A1416), Color(0xFF1A090A), Color(0xFF080405)],
          stops: const [0, 0.52, 1],
        ),
      );
}

/// La pagina del telefono: il muro, la freccia d'ottone e il titolo spaziato
/// in alto, come nella classificata.
class CafeScaffold extends StatelessWidget {
  final String title;
  final Widget child;

  /// Indietro. Senza, si chiude la pagina (passando dal PopScope).
  final VoidCallback? onBack;
  final bool resizeForKeyboard;

  const CafeScaffold({super.key, required this.title, required this.child, this.onBack, this.resizeForKeyboard = true});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Cafe.background,
      resizeToAvoidBottomInset: resizeForKeyboard,
      body: DecoratedBox(
        decoration: Cafe.wall(),
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 2, 16, 0),
                child: Row(
                  children: [
                    if (Navigator.of(context).canPop() || onBack != null)
                      Semantics(
                        button: true,
                        label: MaterialLocalizations.of(context).backButtonTooltip,
                        child: GestureDetector(
                          key: const Key('cafe.back'),
                          onTap: onBack ?? () => Navigator.of(context).maybePop(),
                          behavior: HitTestBehavior.opaque,
                          child: const SizedBox(width: 48, height: 48, child: CustomPaint(painter: CafeChevron())),
                        ),
                      )
                    else
                      const SizedBox(width: 48),
                    Expanded(
                      child: Text(
                        title.toUpperCase(),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.overline.copyWith(color: Saloon.brass, fontSize: 13, letterSpacing: 4),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

/// La pagina del PC: lo stesso muro, la barra in alto, Esc per tornare.
class CafeDesk extends StatelessWidget {
  final String title;
  final Widget child;
  final VoidCallback? onBack;
  final List<Widget> actions;
  final EdgeInsetsGeometry padding;

  const CafeDesk({
    super.key,
    required this.title,
    required this.child,
    this.onBack,
    this.actions = const [],
    this.padding = const EdgeInsets.fromLTRB(DeskSize.gutter, 0, DeskSize.gutter, DeskSize.gutter),
  });

  @override
  Widget build(BuildContext context) {
    final back = onBack ?? () => Navigator.of(context).maybePop();
    return Scaffold(
      backgroundColor: Cafe.background,
      resizeToAvoidBottomInset: false,
      body: NoirDesk(
        child: DeskTheme(
          child: DeskEscape(
            onEscape: back,
            child: DecoratedBox(
              decoration: Cafe.wall(center: const Alignment(-0.3, -0.25)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DeskTopBar(title: title, onBack: back, actions: actions),
                  Expanded(child: Padding(padding: padding, child: child)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Un riquadro scuro col filo d'ottone (lo [Saloon.scrim] della classificata),
/// con il titoletto spaziato.
class CafePanel extends StatelessWidget {
  final String? title;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry? padding;

  /// Sul PC il riquadro riempie l'altezza (il contenuto si espande).
  final bool expand;

  const CafePanel({super.key, this.title, this.trailing, required this.child, this.padding, this.expand = false});

  @override
  Widget build(BuildContext context) {
    final desk = DesktopCanvas.of(context);
    final head = title == null
        ? null
        : Row(
            children: [
              Expanded(
                child: Text(
                  title!.toUpperCase(),
                  style: desk
                      ? DeskText.overline(color: Saloon.brass)
                      : AppText.overline.copyWith(color: Saloon.brass, fontSize: 11, letterSpacing: 3.2),
                ),
              ),
              ?trailing,
            ],
          );
    return Container(
      padding: padding ?? (desk ? const EdgeInsets.fromLTRB(36, 32, 36, 32) : const EdgeInsets.fromLTRB(16, 14, 16, 14)),
      decoration: Saloon.scrim(radius: desk ? DeskSize.radius : 14),
      child: Column(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (head != null) ...[head, SizedBox(height: desk ? 20 : 8)],
          if (expand) Expanded(child: child) else child,
        ],
      ),
    );
  }
}

/// La freccia d'ottone per tornare.
class CafeChevron extends CustomPainter {
  const CafeChevron();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    canvas.drawPath(
      Path()
        ..moveTo(c.dx + 5, c.dy - 9)
        ..lineTo(c.dx - 5, c.dy)
        ..lineTo(c.dx + 5, c.dy + 9),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round
        ..color = Saloon.brass,
    );
  }

  @override
  bool shouldRepaint(CafeChevron old) => false;
}

/// La saletta vista da lontano, per l'ingresso e per il codice: le due
/// applique che respirano, il fumo, il tavolo tondo con la tovaglia, il
/// cartellino «RISERVATO», una tazzina e due carte.
class CafeScene extends StatefulWidget {
  const CafeScene({super.key});

  @override
  State<CafeScene> createState() => _CafeSceneState();
}

class _CafeSceneState extends State<CafeScene> with SingleTickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(vsync: this, duration: const Duration(seconds: 5));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _breath.stop();
    } else if (!_breath.isAnimating) {
      _breath.repeat();
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: AnimatedBuilder(
          animation: _breath,
          builder: (context, _) => CustomPaint(size: Size.infinite, painter: _CafeScenePainter(_breath.value)),
        ),
      );
}

void _sconce(Canvas canvas, Offset at, double scale, double glow) {
  canvas.drawCircle(
    at,
    160 * scale,
    Paint()
      ..shader = RadialGradient(colors: [const Color(0xFFFFC870).withValues(alpha: 0.26 * glow), Colors.transparent])
          .createShader(Rect.fromCircle(center: at, radius: 160 * scale)),
  );
  final brass = Paint()..color = Saloon.brassDeep;
  canvas.drawRRect(
    RRect.fromRectAndRadius(Rect.fromCenter(center: at + Offset(0, 16 * scale), width: 10 * scale, height: 26 * scale), Radius.circular(3 * scale)),
    brass,
  );
  final tulip = Path()
    ..moveTo(at.dx - 12 * scale, at.dy - 10 * scale)
    ..quadraticBezierTo(at.dx, at.dy + 12 * scale, at.dx + 12 * scale, at.dy - 10 * scale)
    ..close();
  canvas.drawPath(tulip, Paint()..color = const Color(0xFFFFE6B0).withValues(alpha: 0.85 + 0.15 * glow));
  canvas.drawCircle(at, 4 * scale, Paint()..color = const Color(0xFFFFF4D6)..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 * scale));
}

/// Il muro con la boiserie: una fascia scura in basso col filo d'ottone.
void _wainscot(Canvas canvas, Size size, double y) {
  canvas.drawRect(
    Rect.fromLTRB(0, y, size.width, size.height),
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [const Color(0xFF1C0D08).withValues(alpha: 0.7), Colors.transparent],
      ).createShader(Rect.fromLTRB(0, y, size.width, size.height)),
  );
  canvas.drawLine(Offset(0, y), Offset(size.width, y), Paint()..color = Saloon.brassDeep.withValues(alpha: 0.35)..strokeWidth = 1.2);
  // Le righe della tappezzeria, appena accennate.
  final stripe = Paint()..color = Colors.black.withValues(alpha: 0.12)..strokeWidth = 2;
  for (var x = 18.0; x < size.width; x += 26) {
    canvas.drawLine(Offset(x, 0), Offset(x, y), stripe);
  }
}

/// La tovaglia: il tavolo di legno, il panno vino con l'orlo color crema.
void _tablecloth(Canvas canvas, Rect table, {Offset? light}) {
  final rim = table.shortestSide * 0.07;
  canvas.drawOval(
    table.inflate(rim).shift(Offset(0, rim)),
    Paint()
      ..color = Colors.black.withValues(alpha: 0.6)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, rim * 1.2),
  );
  canvas.drawOval(
    table.inflate(rim),
    Paint()..shader = const LinearGradient(colors: [Color(0xFF6A3D20), Saloon.woodDark, Color(0xFF5C3519)]).createShader(table.inflate(rim)),
  );
  canvas.drawOval(
    table,
    Paint()
      ..shader = const RadialGradient(colors: [Color(0xFF8A1D2A), Cafe.wine, Cafe.wineDeep], stops: [0, 0.6, 1]).createShader(table),
  );
  canvas.drawOval(
    table.deflate(table.shortestSide * 0.05),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.0, table.shortestSide * 0.008)
      ..color = Cafe.cream.withValues(alpha: 0.35),
  );
  final glow = light ?? table.center;
  canvas.drawOval(
    table,
    Paint()
      ..shader = RadialGradient(
        center: Alignment((glow.dx - table.center.dx) / (table.width / 2), -0.25),
        colors: [const Color(0xFFFFE2A0).withValues(alpha: 0.16), Colors.transparent],
      ).createShader(table),
  );
}

class _CafeScenePainter extends CustomPainter {
  final double breath;

  const _CafeScenePainter(this.breath);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final cx = w / 2;
    final glow = 0.85 + 0.15 * (0.5 + 0.5 * sin(breath * 2 * pi));
    final scale = (min(w, h * 1.6) / 420).clamp(0.6, 2.4);
    _wainscot(canvas, size, h * 0.58);
    _sconce(canvas, Offset(w * 0.14, h * 0.26), scale, glow);
    _sconce(canvas, Offset(w * 0.86, h * 0.26), scale, glow);

    // Il fumo.
    final smoke = Paint()..maskFilter = MaskFilter.blur(BlurStyle.normal, 26 * scale);
    final drift = breath * 2 * pi;
    for (final (dx, dy, r, a) in [(-0.18, 0.45, 50.0, 0.06), (0.2, 0.32, 60.0, 0.05), (0.04, 0.62, 40.0, 0.05)]) {
      smoke.color = const Color(0xFFE8DCC4).withValues(alpha: a);
      canvas.drawCircle(Offset(cx + w * dx + 10 * scale * sin(drift + dy * 5), h * dy), r * scale, smoke);
    }

    // Il tavolo tondo, visto di sbieco.
    final tw = min(w * 0.86, 520 * scale);
    final table = Rect.fromCenter(center: Offset(cx, h * 0.8), width: tw, height: min(tw * 0.3, h * 0.32));
    _tablecloth(canvas, table);

    // La tazzina.
    final cup = table.center + Offset(tw * 0.2, -table.height * 0.05);
    canvas.drawOval(Rect.fromCenter(center: cup + Offset(0, 4 * scale), width: 34 * scale, height: 10 * scale), Paint()..color = Cafe.cream.withValues(alpha: 0.9));
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromCenter(center: cup - Offset(0, 4 * scale), width: 18 * scale, height: 14 * scale),
        bottomLeft: Radius.circular(7 * scale),
        bottomRight: Radius.circular(7 * scale),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.92),
    );
    canvas.drawOval(Rect.fromCenter(center: cup - Offset(0, 10 * scale), width: 18 * scale, height: 5 * scale), Paint()..color = const Color(0xFF3A2014));

    // Due carte coperte.
    void card(Offset c, double angle) {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(angle);
      canvas.scale(scale, scale * 0.42);
      final r = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: 30, height: 42), const Radius.circular(3));
      canvas.drawRRect(r, Paint()..color = const Color(0xFF14361F));
      canvas.drawRRect(r.deflate(3), Paint()..style = PaintingStyle.stroke..strokeWidth = 1.2..color = Saloon.paper.withValues(alpha: 0.7));
      canvas.restore();
    }

    card(table.center + Offset(-tw * 0.24, 2), -0.3);
    card(table.center + Offset(-tw * 0.19, 5), 0.25);

    // Il cartellino «RISERVATO».
    _reserved(canvas, table.center + Offset(-tw * 0.02, -table.height * 0.12), scale);
  }

  @override
  bool shouldRepaint(_CafeScenePainter old) => old.breath != breath;
}

/// Il cartellino piegato a tenda, crema con le lettere color vino.
void _reserved(Canvas canvas, Offset base, double scale) {
  final cw = 92 * scale, ch = 30 * scale;
  final face = Rect.fromLTWH(base.dx - cw / 2, base.dy - ch, cw, ch);
  canvas.drawRect(face.shift(Offset(3 * scale, 4 * scale)), Paint()..color = Colors.black.withValues(alpha: 0.45)..maskFilter = MaskFilter.blur(BlurStyle.normal, 4 * scale));
  canvas.drawRect(face, Paint()..color = Cafe.cream);
  canvas.drawRect(face.deflate(2.5 * scale), Paint()..style = PaintingStyle.stroke..strokeWidth = 0.8 * scale..color = Cafe.wine);
  final text = TextPainter(
    text: TextSpan(
      text: 'RISERVATO',
      style: AppText.display(11 * scale, color: Cafe.wine).copyWith(letterSpacing: 1.6 * scale),
    ),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: cw);
  text.paint(canvas, face.center - Offset(text.width / 2, text.height / 2));
}

/// Chi siede al tavolo degli amici.
class CafeGuest {
  final Profile profile;
  final bool host;
  final bool me;
  final bool bot;

  /// Si può chiedere l'amicizia (non è sé stessi, non c'è già un legame).
  final bool canBefriend;

  const CafeGuest({required this.profile, this.host = false, this.me = false, this.bot = false, this.canBefriend = false});
}

/// Il tavolo riservato con le sedie intorno: chi è entrato siede col suo
/// volto e il suo nome, le sedie vuote restano in penombra. Al centro il
/// cartellino «RISERVATO» e il contatore d'ottone. Toccare qualcuno apre il
/// suo fascicolo (profilo, segnalazione, blocco); il «+» chiede l'amicizia.
class CafeTable extends StatelessWidget {
  final List<CafeGuest> guests;
  final int size;
  final void Function(CafeGuest guest)? onGuest;
  final void Function(CafeGuest guest)? onBefriend;

  /// Il suggerimento del «+».
  final String befriendLabel;

  const CafeTable({
    super.key,
    required this.guests,
    required this.size,
    required this.befriendLabel,
    this.onGuest,
    this.onBefriend,
  });

  /// Le sedie da apparecchiare: dodici finché bastano, poi tutte.
  int get chairs => guests.length < 12 ? min(12, size) : size;

  @override
  Widget build(BuildContext context) {
    final desk = NoirDesk.of(context);
    final n = max(chairs, guests.length);
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        final h = box.maxHeight;
        final avatar = min(desk ? 92.0 : 50.0, min(w, h) * (n > 12 ? 0.12 : 0.14));
        final table = Rect.fromCenter(center: Offset(w / 2, h * 0.52), width: w * 0.58, height: h * 0.44);
        final rx = w / 2 - avatar * 0.85;
        final ry = h * 0.44 - avatar * 0.55;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(child: RepaintBoundary(child: CustomPaint(painter: _CafeTablePainter(table: table)))),
            Positioned.fromRect(
              rect: table,
              child: IgnorePointer(
                child: Center(child: _Placard(seated: guests.length, size: size, height: table.height)),
              ),
            ),
            for (var i = 0; i < n; i++)
              Builder(
                builder: (context) {
                  final angle = -pi / 2 + 2 * pi * i / n;
                  final x = w / 2 + cos(angle) * rx;
                  final y = table.center.dy + sin(angle) * ry;
                  final guest = i < guests.length ? guests[i] : null;
                  return Positioned(
                    left: x - avatar * 0.9,
                    top: y - avatar * 0.62,
                    width: avatar * 1.8,
                    child: _CafeSeat(
                      key: ValueKey(guest == null ? 'cafe-chair-$i' : 'cafe-seat-${guest.profile.id}'),
                      guest: guest,
                      size: avatar,
                      befriendLabel: befriendLabel,
                      onTap: guest == null || guest.me || guest.bot || onGuest == null ? null : () => onGuest!(guest),
                      onBefriend: guest != null && guest.canBefriend && onBefriend != null ? () => onBefriend!(guest) : null,
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

class _CafeSeat extends StatelessWidget {
  final CafeGuest? guest;
  final double size;
  final String befriendLabel;
  final VoidCallback? onTap;
  final VoidCallback? onBefriend;

  const _CafeSeat({super.key, required this.guest, required this.size, required this.befriendLabel, this.onTap, this.onBefriend});

  @override
  Widget build(BuildContext context) {
    final guest = this.guest;
    final desk = NoirDesk.of(context);
    final chair = CustomPaint(size: Size(size * 0.9, size * 0.95), painter: _ChairPainter(lit: guest != null));
    if (guest == null) {
      return Column(mainAxisSize: MainAxisSize.min, children: [SizedBox(width: size * 1.8, height: size * 1.05, child: Center(child: chair))]);
    }
    final profile = guest.profile;
    final plate = guest.me ? Saloon.brass : (guest.bot ? const Color(0xFF8C8170) : Cafe.cream);
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final face = DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: (guest.me ? Saloon.brass : Colors.black).withValues(alpha: 0.55), blurRadius: 12),
        ],
      ),
      child: PlayerAvatar(seed: profile.avatarSeed, look: profile.look, picture: profile.pictureUrl, size: size),
    );
    final seat = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size * 1.8,
          height: size * 1.05,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              chair,
              face,
              if (guest.host)
                Positioned(
                  left: size * 0.32,
                  top: -size * 0.02,
                  child: _Chip(size: size * 0.38, icon: Icons.vpn_key, color: Saloon.brass, ink: Saloon.paperInk),
                ),
              if (onBefriend != null)
                Positioned(
                  right: size * 0.22,
                  top: -size * 0.06,
                  child: Tooltip(
                    message: befriendLabel,
                    child: Semantics(
                      button: true,
                      label: befriendLabel,
                      child: GestureDetector(
                        key: Key('online.befriend.${profile.id}'),
                        behavior: HitTestBehavior.opaque,
                        onTap: onBefriend,
                        child: Padding(
                          padding: EdgeInsets.all(size * 0.06),
                          child: _Chip(size: max(22, size * 0.42), icon: Icons.person_add_alt_1, color: Saloon.enamel, ink: Saloon.paper),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.only(top: 1),
          padding: EdgeInsets.symmetric(horizontal: desk ? 9 : 5, vertical: desk ? 3 : 1),
          decoration: BoxDecoration(
            color: plate,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: Saloon.brassDeep, width: 0.8),
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 2))],
          ),
          child: Text(
            profile.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.body.copyWith(fontSize: desk ? 17 : 9.5, fontWeight: FontWeight.w700, color: Saloon.paperInk),
          ),
        ),
      ],
    );
    // Chi arriva si siede con un piccolo inchino.
    final arriving = still
        ? seat
        : TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutBack,
            builder: (context, v, child) => Opacity(
              opacity: v.clamp(0.0, 1.0),
              child: Transform.translate(offset: Offset(0, (1 - v) * -size * 0.3), child: child),
            ),
            child: seat,
          );
    if (onTap == null) return arriving;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        key: Key('online.memberActions.${profile.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: arriving,
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final double size;
  final IconData icon;
  final Color color;
  final Color ink;

  const _Chip({required this.size, required this.icon, required this.color, required this.ink});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(color: Saloon.brassDeep, width: 1),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 2))],
        ),
        child: Icon(icon, size: size * 0.6, color: ink),
      );
}

/// Il cartellino «RISERVATO» e, sotto, il contatore d'ottone «3/12».
class _Placard extends StatelessWidget {
  final int seated;
  final int size;
  final double height;

  const _Placard({required this.seated, required this.size, required this.height});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: height * 0.08, vertical: height * 0.02),
          decoration: BoxDecoration(
            color: Cafe.cream,
            border: Border.all(color: Cafe.wine, width: 1),
            boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 6, offset: Offset(0, 3))],
          ),
          child: Text(
            'RISERVATO',
            softWrap: false,
            style: AppText.display(max(9, height * 0.075), color: Cafe.wine).copyWith(letterSpacing: 2),
          ),
        ),
        SizedBox(height: height * 0.05),
        Container(
          key: const Key('cafe.counter'),
          padding: EdgeInsets.symmetric(horizontal: height * 0.12, vertical: height * 0.03),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF1D58A), Saloon.brass, Saloon.brassDeep],
            ),
            border: Border.all(color: const Color(0xFF5E4517), width: 1.5),
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 4))],
          ),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: seated.toDouble()),
            duration: const Duration(milliseconds: 500),
            builder: (context, value, _) =>
                Text(softWrap: false, '${value.round()}/$size', style: AppText.display(height * 0.16, color: Saloon.paperInk)),
          ),
        ),
      ],
    );
  }
}

class _ChairPainter extends CustomPainter {
  final bool lit;

  const _ChairPainter({required this.lit});

  @override
  void paint(Canvas canvas, Size size) {
    final wood = lit ? Saloon.wood : const Color(0xFF2A1A10).withValues(alpha: 0.6);
    final back = RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, size.height * 0.28), Radius.circular(size.width * 0.18));
    final seat = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.08, size.height * 0.3, size.width * 0.84, size.height * 0.66),
      Radius.circular(size.width * 0.16),
    );
    canvas.drawRRect(back, Paint()..color = wood);
    canvas.drawRRect(seat, Paint()..color = wood);
    canvas.drawRRect(seat.deflate(size.width * 0.1), Paint()..color = (lit ? Cafe.wineDeep : const Color(0xFF1C130C)).withValues(alpha: 0.8));
  }

  @override
  bool shouldRepaint(_ChairPainter old) => old.lit != lit;
}

class _CafeTablePainter extends CustomPainter {
  final Rect table;

  const _CafeTablePainter({required this.table});

  @override
  void paint(Canvas canvas, Size size) {
    final scale = (size.shortestSide / 420).clamp(0.6, 2.4);
    _sconce(canvas, Offset(size.width * 0.08, size.height * 0.08), scale, 1);
    _sconce(canvas, Offset(size.width * 0.92, size.height * 0.08), scale, 1);
    // La pozza di luce calda sul tavolo.
    canvas.drawCircle(
      table.center,
      size.longestSide * 0.55,
      Paint()
        ..shader = RadialGradient(colors: [const Color(0xFFFFC870).withValues(alpha: 0.2), const Color(0xFFFFC870).withValues(alpha: 0)])
            .createShader(Rect.fromCircle(center: table.center, radius: size.longestSide * 0.55)),
    );
    _tablecloth(canvas, table);
  }

  @override
  bool shouldRepaint(_CafeTablePainter old) => old.table != table;
}
