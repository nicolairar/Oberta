import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'baked.dart';
import 'noir_avatar.dart';

const _ink = Color(0xFF14110F);
const _cream = Color(0xFFEDE2C8);
const _red = Color(0xFFB3202A);

TextStyle _print(double size, {Color color = _ink, bool italic = false, double spacing = 0}) => TextStyle(
      fontFamily: 'Georgia',
      fontFamilyFallback: const ['serif'],
      fontSize: size,
      height: 1.18,
      fontWeight: italic ? FontWeight.normal : FontWeight.bold,
      fontStyle: italic ? FontStyle.italic : FontStyle.normal,
      letterSpacing: spacing,
      color: color,
    );

/// Un manifesto disegnato su misure fisse e poi ridotto o ingrandito tutto
/// insieme per riempire lo spazio che gli tocca: così il testo non esce mai
/// dalla carta, su nessun telefono.
class _Sheet extends StatelessWidget {
  final double width;
  final double minHeight;
  final Color paper;
  final int seed;
  final Widget child;

  const _Sheet({
    required this.width,
    required this.minHeight,
    required this.paper,
    required this.seed,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final space = constraints.biggest;
        final height = max(minHeight, width * space.height / max(1.0, space.width));
        return FittedBox(
          child: SizedBox(
            width: width,
            height: height,
            child: CustomPaint(painter: _PaperPainter(paper, seed), child: child),
          ),
        );
      },
    );
  }
}

/// La carta: bordi un po' storti, un angolo strappato, le pieghe di quando
/// era in tasca a qualcuno, due pezzi di nastro per tenerla al muro.
class _PaperPainter extends CustomPainter {
  final Color paper;
  final int seed;

  _PaperPainter(this.paper, this.seed);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(seed);
    final w = size.width;
    final h = size.height;
    double wobble() => (rng.nextDouble() - 0.5) * 1.6;

    final sheet = Path()..moveTo(wobble(), wobble());
    for (var x = 22.0; x < w - 10; x += 22) {
      sheet.lineTo(x, wobble());
    }
    sheet.lineTo(w + wobble(), wobble());
    for (var y = 22.0; y < h - 22; y += 22) {
      sheet.lineTo(w + wobble(), y);
    }
    // L'angolo in basso a destra se l'è portato via qualcuno.
    final tear = 9 + rng.nextDouble() * 7;
    sheet
      ..lineTo(w, h - tear)
      ..lineTo(w - tear * 0.35, h - tear * 0.75)
      ..lineTo(w - tear * 0.55, h - tear * 0.30)
      ..lineTo(w - tear, h);
    for (var x = w - 30; x > 10; x -= 22) {
      sheet.lineTo(x, h + wobble());
    }
    sheet.lineTo(wobble(), h + wobble());
    for (var y = h - 22; y > 10; y -= 22) {
      sheet.lineTo(wobble(), y);
    }
    sheet.close();

    canvas.drawPath(sheet.shift(const Offset(3, 4.5)), Paint()..color = Colors.black.withValues(alpha: 0.55));
    canvas.drawPath(sheet, Paint()..color = paper);

    canvas.save();
    canvas.clipPath(sheet);
    final rect = Offset.zero & size;
    // La luce viene dall'alto: l'insegna tinge di rosso, il fondo resta in ombra.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.10),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.26),
          ],
          stops: const [0, 0.4, 1],
        ).createShader(rect),
    );
    for (var i = 0; i < 4; i++) {
      final center = Offset(rng.nextDouble() * w, rng.nextDouble() * h);
      final stain = Rect.fromCircle(center: center, radius: 14 + rng.nextDouble() * 26);
      canvas.drawOval(
        stain,
        Paint()
          ..shader = RadialGradient(
            colors: [const Color(0xFF3A2410).withValues(alpha: 0.13), const Color(0x003A2410)],
          ).createShader(stain),
      );
    }
    final shade = Paint()..color = Colors.black.withValues(alpha: 0.13);
    final light = Paint()..color = Colors.white.withValues(alpha: 0.10);
    final foldX = w * (0.46 + rng.nextDouble() * 0.08);
    final foldY = h * (0.46 + rng.nextDouble() * 0.08);
    canvas.drawRect(Rect.fromLTWH(foldX, 0, 1, h), shade);
    canvas.drawRect(Rect.fromLTWH(foldX + 1, 0, 1, h), light);
    canvas.drawRect(Rect.fromLTWH(0, foldY, w, 1), shade);
    canvas.drawRect(Rect.fromLTWH(0, foldY + 1, w, 1), light);
    canvas.restore();

    for (final (corner, turn) in [(const Offset(8, 3), -0.62), (Offset(w - 8, 3), 0.58)]) {
      canvas.save();
      canvas.translate(corner.dx, corner.dy);
      canvas.rotate(turn + wobble() * 0.08);
      final tape = Rect.fromCenter(center: Offset.zero, width: 30, height: 11);
      canvas.drawRect(tape, Paint()..color = const Color(0xFFD9CC9A).withValues(alpha: 0.72));
      canvas.drawRect(
        Rect.fromLTWH(tape.left, tape.top, tape.width, 1.2),
        Paint()..color = Colors.white.withValues(alpha: 0.25),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_PaperPainter old) => old.paper != paper || old.seed != seed;
}

/// Il manifesto di stasera: l'unica modalità che si gioca davvero. Una
/// fila di foto segnaletiche, il titolo, e un pulsante stampato a rilievo
/// che sotto il dito si schiaccia sulla sua ombra.
class HomeTonightPoster extends StatefulWidget {
  final String banner;
  final String title;
  final String blurb;
  final String action;
  final VoidCallback onTap;

  /// Il giro d'ambiente della schermata, da 0 a 1: ogni tanto fa passare un
  /// riflesso sul pulsante.
  final Animation<double> ambient;

  const HomeTonightPoster({
    super.key,
    required this.banner,
    required this.title,
    required this.blurb,
    required this.action,
    required this.onTap,
    required this.ambient,
  });

  @override
  State<HomeTonightPoster> createState() => _HomeTonightPosterState();
}

class _HomeTonightPosterState extends State<HomeTonightPoster> {
  // Le facce della fila: nomi scelti perché i ritratti vengano diversi.
  static const _lineup = ['Tu', 'Giulia', 'Paolo', 'Elena', 'Luca'];

  bool _pressed = false;

  void _press(bool down) {
    if (_pressed != down) setState(() => _pressed = down);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _press(true),
        onTapUp: (_) => _press(false),
        onTapCancel: () => _press(false),
        onTap: widget.onTap,
        child: _Sheet(
          width: 264,
          minHeight: 206,
          paper: _cream,
          seed: 3,
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: DecoratedBox(
              decoration: BoxDecoration(border: Border.all(color: _ink, width: 2)),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      height: 23,
                      color: _red,
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CustomPaint(size: Size.square(9), painter: _StarPainter(_cream)),
                          const SizedBox(width: 8),
                          Text(widget.banner, style: _print(10.5, color: _cream, spacing: 2.4)),
                          const SizedBox(width: 8),
                          const CustomPaint(size: Size.square(9), painter: _StarPainter(_cream)),
                        ],
                      ),
                    ),
                    const Expanded(child: _Lineup(names: _lineup)),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(widget.title, maxLines: 1, style: _print(18, spacing: 1.2)),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        widget.blurb,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: _print(11, color: const Color(0xFF4A4036), italic: true),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 11, 11),
                      child: _PrintedButton(label: widget.action, pressed: _pressed, ambient: widget.ambient),
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

/// Il pulsante come lo stamperebbe un fumetto: un blocco rosso con la sua
/// ombra nera sfalsata. Premuto, ci scende sopra.
class _PrintedButton extends StatelessWidget {
  final String label;
  final bool pressed;
  final Animation<double> ambient;

  const _PrintedButton({required this.label, required this.pressed, required this.ambient});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Stack(
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        children: [
          const Positioned(left: 3, top: 3, right: -3, bottom: -3, child: ColoredBox(color: _ink)),
          AnimatedContainer(
            duration: const Duration(milliseconds: 70),
            transform: Matrix4.translationValues(pressed ? 3 : 0, pressed ? 3 : 0, 0),
            decoration: BoxDecoration(
              color: pressed ? const Color(0xFF8E1820) : _red,
              border: Border.all(color: _ink, width: 2),
            ),
            // Il riflesso si ridisegna spesso: resta nel suo strato, così il
            // resto del manifesto non se ne accorge.
            child: RepaintBoundary(
              child: CustomPaint(
                foregroundPainter: _GlintPainter(ambient),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(label, style: _print(17, color: const Color(0xFFFFF6E2), spacing: 2.6)),
                        const SizedBox(width: 9),
                        const CustomPaint(size: Size(9, 12), painter: _ArrowPainter()),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Una lama di luce che attraversa il pulsante dieci volte a giro, come un
/// riflesso sull'inchiostro ancora fresco: dice dove toccare.
class _GlintPainter extends CustomPainter {
  final Animation<double> ambient;

  _GlintPainter(this.ambient) : super(repaint: ambient);

  @override
  void paint(Canvas canvas, Size size) {
    final pass = ((ambient.value * 10) % 1 - 0.5) / 0.11;
    if (pass <= 0 || pass >= 1) return;
    final lean = size.height * 0.7;
    final wide = size.width * 0.13;
    final x = -wide + (size.width + wide + lean) * Curves.easeInOut.transform(pass);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawPath(
      Path()
        ..moveTo(x, 0)
        ..lineTo(x + wide, 0)
        ..lineTo(x + wide - lean, size.height)
        ..lineTo(x - lean, size.height)
        ..close(),
      Paint()..color = Colors.white.withValues(alpha: 0.34 * sin(pi * pass)),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlintPainter old) => old.ambient != ambient;
}

/// La fila dei sospetti davanti alle righe dell'altezza.
class _Lineup extends StatelessWidget {
  final List<String> names;

  const _Lineup({required this.names});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _HeightChartPainter(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final space = constraints.biggest;
          final overlap = 0.84;
          final face = min(space.height - 8, (space.width - 12) / (1 + (names.length - 1) * overlap));
          if (face < 12) return const SizedBox.shrink();
          return Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final name in names)
                  Align(widthFactor: name == names.last ? 1 : overlap, child: NoirAvatar(seed: name, size: face)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HeightChartPainter extends CustomPainter {
  const _HeightChartPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF2A2420));
    final line = Paint()
      ..color = _cream.withValues(alpha: 0.22)
      ..strokeWidth = 1;
    final rows = max(3, (size.height / 11).round());
    for (var i = 1; i < rows; i++) {
      final y = size.height * i / rows;
      canvas.drawLine(Offset(i.isEven ? 0 : size.width * 0.04, y), Offset(size.width * (i.isEven ? 1 : 0.96), y), line);
    }
    canvas.drawRect(Rect.fromLTWH(0, size.height - 2, size.width, 2), Paint()..color = _ink);
  }

  @override
  bool shouldRepaint(_HeightChartPainter old) => false;
}

class _StarPainter extends CustomPainter {
  final Color color;

  const _StarPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final star = Path();
    for (var i = 0; i < 10; i++) {
      final reach = i.isEven ? radius : radius * 0.42;
      final point = center + Offset(sin(i * pi / 5), -cos(i * pi / 5)) * reach;
      i == 0 ? star.moveTo(point.dx, point.dy) : star.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(star..close(), Paint()..color = color);
  }

  @override
  bool shouldRepaint(_StarPainter old) => old.color != color;
}

class _ArrowPainter extends CustomPainter {
  const _ArrowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width, size.height / 2)
        ..lineTo(0, size.height)
        ..close(),
      Paint()..color = const Color(0xFFFFF6E2),
    );
  }

  @override
  bool shouldRepaint(_ArrowPainter old) => false;
}

/// Il disegno in cima a un manifesto «prossimamente».
enum HomeSoonEmblem { phones, laurel }

/// Un manifesto più piccolo, più in ombra, con una striscia incollata di
/// traverso («prossimamente», o «online»). A toccarlo dondola sul suo
/// nastro, e fa quello che dice [onTap].
class HomeSoonPoster extends StatefulWidget {
  final String title;
  final String blurb;
  /// La fascetta di traverso («presto»); null: niente fascetta.
  final String? strip;

  /// Il timbro in alto («24 in coda»); null: niente timbro.
  final String? stamp;
  final HomeSoonEmblem emblem;
  final Color paper;
  final int seed;
  final VoidCallback onTap;

  const HomeSoonPoster({
    super.key,
    required this.title,
    required this.blurb,
    this.strip,
    this.stamp,
    required this.emblem,
    required this.paper,
    required this.seed,
    required this.onTap,
  });

  @override
  State<HomeSoonPoster> createState() => _HomeSoonPosterState();
}

class _HomeSoonPosterState extends State<HomeSoonPoster> with SingleTickerProviderStateMixin {
  late final AnimationController _swing =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 720));

  void _tap() {
    _swing.forward(from: 0);
    widget.onTap();
  }

  @override
  void dispose() {
    _swing.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Il foglio è fermo (storto sul muro): si stampa una volta in
    // un'immagine fitta, e non si ridisegna a ogni goccia di pioggia.
    final sheet = Baked(
      tilted: true,
      overflow: const EdgeInsets.all(12),
      child: _Sheet(
        width: 132,
        minHeight: 150,
        paper: widget.paper,
        seed: widget.seed,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(9, 12, 9, 34),
                child: Column(
                  children: [
                    Expanded(
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: _EmblemPainter(widget.emblem),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Il titolo va a capo dove dice il testo, e si stringe
                    // se una riga non ci sta.
                    SizedBox(
                      height: 33,
                      width: double.infinity,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          widget.title,
                          softWrap: false,
                          textAlign: TextAlign.center,
                          style: _print(13.5, color: _cream, spacing: 0.8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.blurb,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: _print(10, color: _cream.withValues(alpha: 0.85), italic: true),
                    ),
                  ],
                ),
              ),
            ),
            if (widget.stamp case final stamp?)
              Positioned(
                top: 4,
                right: -6,
                child: Transform.rotate(
                  angle: 0.09,
                  child: Container(
                    key: const Key('home.rankedCount'),
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: _red,
                      border: Border.all(color: _cream, width: 1),
                      boxShadow: const [BoxShadow(color: Color(0x99000000), offset: Offset(1, 2))],
                    ),
                    constraints: const BoxConstraints(maxWidth: 118),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(stamp.toUpperCase(), style: _print(8.5, color: _cream, spacing: 1.2)),
                    ),
                  ),
                ),
              ),
            if (widget.strip != null)
            Positioned(
              left: -5,
              right: -5,
              bottom: 9,
              child: Transform.rotate(
                angle: -0.07,
                child: Container(
                  height: 19,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: _cream,
                    boxShadow: [BoxShadow(color: Color(0x99000000), offset: Offset(1.5, 2.5))],
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(widget.strip!, style: _print(10, color: _red, spacing: 2.2)),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _tap,
        child: AnimatedBuilder(
          animation: _swing,
          child: sheet,
          builder: (context, child) {
            final t = _swing.value;
            final swing = _swing.isAnimating ? sin(t * pi * 5) * (1 - t) * 0.075 : 0.0;
            return Transform.rotate(angle: swing, alignment: Alignment.topCenter, child: child);
          },
        ),
      ),
    );
  }
}

class _EmblemPainter extends CustomPainter {
  final HomeSoonEmblem emblem;

  _EmblemPainter(this.emblem);

  static const _gold = AppColors.gold;

  @override
  void paint(Canvas canvas, Size size) {
    switch (emblem) {
      case HomeSoonEmblem.phones:
        _phones(canvas, size);
      case HomeSoonEmblem.laurel:
        _laurel(canvas, size);
    }
  }

  /// Tre telefoni tenuti a ventaglio, come una mano di carte.
  void _phones(Canvas canvas, Size size) {
    final tall = min(size.height * 0.80, size.width * 0.52);
    final wide = tall * 0.54;
    final pivot = Offset(size.width / 2, size.height / 2 + tall * 0.62);
    for (final turn in [-0.46, 0.46, 0.0]) {
      canvas.save();
      canvas.translate(pivot.dx, pivot.dy);
      canvas.rotate(turn);
      final body = RRect.fromRectAndRadius(
        Rect.fromLTWH(-wide / 2, -tall * 1.16, wide, tall),
        Radius.circular(wide * 0.16),
      );
      canvas.drawRRect(body.shift(const Offset(1.5, 2)), Paint()..color = Colors.black.withValues(alpha: 0.45));
      canvas.drawRRect(body, Paint()..color = const Color(0xFF0B0908));
      canvas.drawRRect(
        body,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = _gold,
      );
      final screen = body.outerRect.deflate(wide * 0.12);
      canvas.drawRRect(
        RRect.fromRectAndRadius(screen, Radius.circular(wide * 0.07)),
        Paint()..color = turn == 0 ? const Color(0xFFFFD77A) : const Color(0xFF8A6D1E),
      );
      if (turn == 0) {
        // I sei caratteri del codice della stanza.
        final cell = screen.width * 0.12;
        for (var i = 0; i < 6; i++) {
          canvas.drawRect(
            Rect.fromCenter(
              center: Offset(screen.left + screen.width * (0.12 + 0.152 * i), screen.center.dy),
              width: cell,
              height: cell * 1.3,
            ),
            Paint()..color = const Color(0xFF0B0908),
          );
        }
      }
      canvas.restore();
    }
  }

  /// Una corona d'alloro con la stella di chi sta in cima.
  void _laurel(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = min(size.height * 0.44, size.width * 0.34);
    final leaf = Paint()..color = _gold;
    for (final side in [-1.0, 1.0]) {
      for (var i = 0; i < 6; i++) {
        final angle = pi / 2 + side * (0.30 + i * 0.36);
        final at = center + Offset(cos(angle), sin(angle)) * radius;
        canvas.save();
        canvas.translate(at.dx, at.dy);
        canvas.rotate(angle + side * (pi / 2 + 0.55));
        canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: radius * 0.42, height: radius * 0.17), leaf);
        canvas.restore();
      }
    }
    final star = Path();
    for (var i = 0; i < 10; i++) {
      final reach = radius * (i.isEven ? 0.50 : 0.21);
      final point = center + Offset(sin(i * pi / 5), -cos(i * pi / 5)) * reach;
      i == 0 ? star.moveTo(point.dx, point.dy) : star.lineTo(point.dx, point.dy);
    }
    star.close();
    canvas.drawPath(star.shift(const Offset(1.5, 2)), Paint()..color = Colors.black.withValues(alpha: 0.4));
    canvas.drawPath(star, Paint()..color = const Color(0xFFFFD77A));
  }

  @override
  bool shouldRepaint(_EmblemPainter old) => old.emblem != emblem;
}
