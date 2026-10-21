import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../rules/role.dart';
import '../../../widgets/player_avatar.dart';
import 'noir_ui.dart';

/// Una riga di cronaca: i fatti in tondo nero, il colore in corsivo.
typedef FrontPageLine = ({String text, bool fact});

/// La prima pagina di un quotidiano degli anni Quaranta: testata, data,
/// titolone, ritratto a retino, colonne di testo, lo scrutinio in un
/// riquadro e il ruolo scoperto come un timbro. Arriva girando e si posa.
class FrontPage extends StatefulWidget {
  final String masthead;
  final String dateLine;
  final String headline;
  final String? kicker;
  final List<String> portraits;
  final bool fallen;
  final String? stamp;
  final String? stampTeam;
  final Color stampColor;
  final String? tallyTitle;
  final List<String> tally;
  final Key? tallyKey;
  final List<FrontPageLine> lines;

  /// In poco spazio (lo spazio del tavolo): testate più piccole, il
  /// ritratto accanto al racconto.
  final bool compact;

  /// Quanto ingrandire caratteri e ritratti (sul desktop la pagina è grande).
  final double scale;

  const FrontPage({
    this.compact = false,
    this.scale = 1,
    super.key,
    required this.masthead,
    required this.dateLine,
    required this.headline,
    required this.lines,
    this.kicker,
    this.portraits = const [],
    this.fallen = false,
    this.stamp,
    this.stampTeam,
    this.stampColor = _red,
    this.tallyTitle,
    this.tally = const [],
    this.tallyKey,
  });

  static const _red = Color(0xFF9E1B1B);

  @override
  State<FrontPage> createState() => _FrontPageState();
}

class _FrontPageState extends State<FrontPage> with SingleTickerProviderStateMixin {
  late final _spin = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_spin.isAnimating || _spin.isCompleted) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _spin.value = 1;
    } else {
      _spin.forward();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  static const _ink = Saloon.paperInk;
  double get _k => widget.scale;

  TextStyle get _body => TextStyle(fontFamily: 'Georgia', color: _ink, fontSize: 13.5 * _k, height: 1.32);

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _spin,
        builder: (context, child) {
          final t = Curves.easeOutCubic.transform(_spin.value);
          final land = Curves.easeOutBack.transform(_spin.value);
          return Opacity(
            opacity: (_spin.value * 4).clamp(0, 1),
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..rotateZ((1 - t) * -4 * pi - 0.012)
                ..scaleByDouble(0.15 + 0.85 * land, 0.15 + 0.85 * land, 1, 1),
              child: child,
            ),
          );
        },
        child: _paper(),
      );

  Widget _paper() => DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF2E6CA), Saloon.paper, Color(0xFFD6C59F)],
          ),
          boxShadow: [BoxShadow(color: Color(0xDD000000), blurRadius: 22, offset: Offset(0, 10))],
        ),
        child: CustomPaint(
          foregroundPainter: const _PaperPainter(),
          child: Padding(
            padding: EdgeInsets.fromLTRB(22 * _k - 8, 12 * _k, 22 * _k - 8, 14 * _k),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    widget.masthead.toUpperCase(),
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      color: _ink,
                      fontSize: (widget.compact ? 22 : 30) * _k,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      height: 1.05,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                const _Rule(heavy: true),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    widget.dateLine.toUpperCase(),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: 'Georgia', color: _ink, fontSize: 9.5 * _k, letterSpacing: 1.6),
                  ),
                ),
                const _Rule(),
                const SizedBox(height: 6),
                Text(
                  widget.headline.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    color: _ink,
                    fontSize: (widget.compact ? 19 : 25) * _k,
                    height: 1.02,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (widget.kicker != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      widget.kicker!,
                      textAlign: TextAlign.center,
                      style: _body.copyWith(fontStyle: FontStyle.italic, fontSize: 12.5 * _k),
                    ),
                  ),
                const SizedBox(height: 6),
                const _Rule(),
                SizedBox(height: 8 * _k),
                Expanded(child: SingleChildScrollView(child: _story())),
              ],
            ),
          ),
        ),
      );

  Widget _story() {
    final lines = widget.lines;
    final half = (lines.length / 2).ceil();
    Widget column(Iterable<FrontPageLine> part) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final line in part)
              Padding(
                padding: EdgeInsets.only(bottom: 7 * _k),
                child: Text(
                  line.text,
                  textAlign: TextAlign.left,
                  style: _body.copyWith(
                    fontWeight: line.fact ? FontWeight.w700 : FontWeight.w400,
                    fontStyle: line.fact ? FontStyle.normal : FontStyle.italic,
                  ),
                ),
              ),
          ],
        );
    final hasArt = widget.portraits.isNotEmpty || widget.stamp != null;
    if (widget.compact) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.portraits.isNotEmpty) ...[
            SizedBox(
              width: 76,
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final name in widget.portraits)
                    _Halftone(name: name, fallen: widget.fallen, width: widget.portraits.length > 1 ? 36 : 76),
                ],
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(child: column(lines)),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasArt)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final name in widget.portraits)
                        _Halftone(name: name, fallen: widget.fallen, width: (widget.portraits.length > 1 ? 74 : 112) * _k),
                    ],
                  ),
                ),
                if (widget.stamp != null || widget.tally.isNotEmpty)
                  SizedBox(
                    width: 138 * _k,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (widget.stamp != null)
                          _Stamp(label: widget.stamp!, team: widget.stampTeam, color: widget.stampColor),
                        if (widget.tally.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          _tallyBox(),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          )
        else if (widget.tally.isNotEmpty)
          Padding(padding: const EdgeInsets.only(bottom: 10), child: _tallyBox()),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: column(lines.take(half))),
              Container(width: 0.8, margin: EdgeInsets.symmetric(horizontal: 8 * _k), color: _ink.withValues(alpha: 0.5)),
              Expanded(child: column(lines.skip(half))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tallyBox() => Container(
        key: widget.tallyKey,
        padding: const EdgeInsets.fromLTRB(6, 4, 6, 5),
        decoration: BoxDecoration(border: Border.all(color: _ink, width: 1.2)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.tallyTitle != null)
              Text(widget.tallyTitle!.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: 'Georgia', color: _ink, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
            const Divider(color: _ink, thickness: 0.8, height: 6),
            for (final row in widget.tally)
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(row,
                    maxLines: 1,
                    style: const TextStyle(fontFamily: 'Courier', color: _ink, fontSize: 11, height: 1.3, fontWeight: FontWeight.w700)),
              ),
          ],
        ),
      );
}

class _Rule extends StatelessWidget {
  final bool heavy;

  const _Rule({this.heavy = false});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Container(height: heavy ? 2.2 : 0.9, color: Saloon.paperInk),
          if (heavy) ...[const SizedBox(height: 1.6), Container(height: 0.7, color: Saloon.paperInk)],
        ],
      );
}

/// Il ritratto stampato: il busto del giocatore in seppia, sotto un retino.
class _Halftone extends StatelessWidget {
  final String name;
  final bool fallen;
  final double width;

  const _Halftone({required this.name, required this.fallen, required this.width});

  static const _sepia = ColorFilter.matrix([
    0.39, 0.77, 0.19, 0, -18, //
    0.35, 0.69, 0.17, 0, -22, //
    0.27, 0.53, 0.13, 0, -30, //
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: Column(
          children: [
            Container(
              width: width,
              height: width * 1.12,
              decoration: BoxDecoration(border: Border.all(color: Saloon.paperInk, width: 1.4)),
              clipBehavior: Clip.hardEdge,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColorFiltered(
                    colorFilter: _sepia,
                    child: ColoredBox(
                      color: const Color(0xFFB8A27C),
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: PlayerAvatar(seed: name, size: width * 1.02),
                      ),
                    ),
                  ),
                  CustomPaint(painter: _ScreenPainter(seed: name.hashCode)),
                  if (fallen)
                    const Positioned(
                      right: 4,
                      top: 0,
                      child: Text(PlayerAvatar.dagger,
                          style: TextStyle(fontFamily: 'Georgia', color: Color(0xFF1E140C), fontSize: 22, fontWeight: FontWeight.w700)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              name.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'Georgia', color: Saloon.paperInk, fontSize: 9.5, letterSpacing: 1.2, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      );
}

/// Il retino tipografico: una griglia inclinata di punti carta, più grana.
class _ScreenPainter extends CustomPainter {
  final int seed;

  const _ScreenPainter({required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    const step = 3.4;
    final paper = Paint()..color = const Color(0x8CEDE0C0);
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(pi / 4);
    final reach = size.longestSide;
    for (var x = -reach; x < reach; x += step) {
      for (var y = -reach; y < reach; y += step) {
        canvas.drawCircle(Offset(x, y), 0.95, paper);
      }
    }
    canvas.restore();
    final random = Random(seed);
    final grain = Paint()..color = const Color(0x33201408);
    for (var i = 0; i < size.width * size.height / 40; i++) {
      canvas.drawCircle(Offset(random.nextDouble() * size.width, random.nextDouble() * size.height), 0.5, grain);
    }
  }

  @override
  bool shouldRepaint(_ScreenPainter old) => old.seed != seed;
}

/// Il ruolo scoperto, timbrato a inchiostro rosso e un po' storto.
class _Stamp extends StatelessWidget {
  final String label;
  final String? team;
  final Color color;

  const _Stamp({required this.label, required this.team, required this.color});

  @override
  Widget build(BuildContext context) => Transform.rotate(
        angle: -0.11,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          decoration: BoxDecoration(
            border: Border.all(color: color.withValues(alpha: 0.85), width: 2.4),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            decoration: BoxDecoration(border: Border.all(color: color.withValues(alpha: 0.7), width: 0.9)),
            child: Column(
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(label.toUpperCase(),
                      style: TextStyle(fontFamily: 'Courier', color: color.withValues(alpha: 0.9), fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: 1)),
                ),
                if (team != null)
                  Text(team!.toUpperCase(),
                      style: TextStyle(fontFamily: 'Courier', color: color.withValues(alpha: 0.85), fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
              ],
            ),
          ),
        ),
      );
}

/// La carta: grana, una piega a metà e l'angolo in basso ripiegato.
class _PaperPainter extends CustomPainter {
  const _PaperPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(1943);
    final speck = Paint()..color = const Color(0x1A3A2A14);
    for (var i = 0; i < 900; i++) {
      canvas.drawCircle(Offset(random.nextDouble() * size.width, random.nextDouble() * size.height), random.nextDouble() * 0.9, speck);
    }
    // La piega orizzontale del giornale ripiegato in tasca.
    final fold = size.height * 0.5;
    final crease = Rect.fromLTWH(0, fold - 10, size.width, 20);
    canvas.drawRect(
      crease,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00000000), Color(0x22000000), Color(0x18FFFFFF), Color(0x00000000)],
          stops: [0, 0.48, 0.52, 1],
        ).createShader(crease),
    );
    // L'angolo in basso a destra, ripiegato.
    const dog = 26.0;
    final corner = Path()
      ..moveTo(size.width - dog, size.height)
      ..lineTo(size.width, size.height - dog)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(corner, Paint()..color = const Color(0xFF14110F));
    final flap = Path()
      ..moveTo(size.width - dog, size.height)
      ..lineTo(size.width, size.height - dog)
      ..lineTo(size.width - dog, size.height - dog)
      ..close();
    canvas.drawShadow(flap, Colors.black, 3, false);
    canvas.drawPath(flap, Paint()..color = const Color(0xFFCDBB92));
  }

  @override
  bool shouldRepaint(_PaperPainter old) => false;
}

/// Il colore del timbro: rosso per la Famiglia, inchiostro per gli altri.
Color stampColorFor(Role role) => role.team == Team.mafia ? const Color(0xFF9E1B1B) : const Color(0xFF1F3A5A);
