// The secret ballot of the one-phone game, before anything changes in the
// live screen: three looks for the inside of a closed 1940s polling booth,
// where the voter whose turn it is taps the name they want eliminated.
//
// A Cabina di velluto: frontal booth, red velvet curtains tied back under a
//   fringed valance, a brass banker's lamp on the walnut desk, a cream
//   ballot with a grid of numbered boxes and a pencil cross.
// B Scheda timbrata: looking down onto the wooden shelf, the ballot fills
//   the screen like a printed scheda ("SCHEDA SEGRETA"), one row per name,
//   and the choice is a red rubber stamp, with its stamp pad on the shelf.
// C Cabina comunale: the municipal booth, bottle-green panels and brass
//   trims, the closed curtain on its brass rail, a slate ballot card with
//   enamel number plates, a pencil on a chain and a punched, inked mark.
//
// Everything is painted by hand (CustomPainter) and the buttons are the
// game's Targa plates. Nothing in lib/ uses this yet: it is the demo hook.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:oberta/ui/screens/online/game/noir_ui.dart';
import 'package:oberta/ui/theme/app_theme.dart';
import 'package:oberta/ui/widgets/targa.dart';

enum BoothLook { a, b, c }

/// A name on the ballot: the seat number and the player.
typedef Candidate = ({int number, String name});

/// The table of the demo: ten at the table, 4 Dino is in the booth, so the
/// ballot lists the other nine.
const demoVoter = '4 DINO';
const demoCandidates = <Candidate>[
  (number: 1, name: 'Ada'),
  (number: 2, name: 'Bruno'),
  (number: 3, name: 'Carla'),
  (number: 5, name: 'Elio'),
  (number: 6, name: 'Fabio'),
  (number: 7, name: 'Gina'),
  (number: 8, name: 'Ivo'),
  (number: 9, name: 'Lia'),
  (number: 10, name: 'Marco'),
];
const demoMarked = 6;

const _cream = Color(0xFFFFF1D6);
const _paper = Color(0xFFF1E6CC);
const _paperShade = Color(0xFFD9C9A4);
const _ink = Color(0xFF1C140E);
const _graphite = Color(0xFF2E2C30);
const _stampRed = Color(0xFFB3121E);

const _subtitle = 'Voto segreto: nessuno vede la tua scheda. Tocca chi vuoi eliminare, una volta sola.';

TextStyle _serif(
  double size,
  Color color, {
  FontWeight weight = FontWeight.w700,
  double spacing = 0,
  double? height,
  FontStyle? style,
}) => TextStyle(
  fontFamily: 'Georgia',
  fontFamilyFallback: const ['serif'],
  fontSize: size,
  fontWeight: weight,
  letterSpacing: spacing,
  height: height,
  fontStyle: style,
  color: color,
);

/// The polling booth, the whole screen: who must vote, the booth with the
/// ballot, and the two buttons.
class PollingBoothDemo extends StatelessWidget {
  final BoothLook look;

  /// Who is in the booth, with the seat number ("4 DINO").
  final String voter;
  final List<Candidate> candidates;

  /// The seat number marked on the ballot, if any.
  final int? marked;
  final bool desk;

  const PollingBoothDemo({
    super.key,
    required this.look,
    this.voter = demoVoter,
    this.candidates = demoCandidates,
    this.marked = demoMarked,
    this.desk = false,
  });

  Candidate? get _choice => candidates.where((c) => c.number == marked).firstOrNull;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Saloon.ink,
      child: LayoutBuilder(
        builder: (context, box) => switch (look) {
          BoothLook.a => _velvet(box.biggest),
          BoothLook.b => _stamped(box.biggest),
          BoothLook.c => _municipal(box.biggest),
        },
      ),
    );
  }

  // -------------------------------------------------------------------------
  // The pieces every look shares.

  double get _k => desk ? 1.6 : 1;

  Widget _heading({required Color title, required Color accent, required Color body, TextAlign align = TextAlign.center}) {
    final parts = voter.split(' ');
    final number = parts.length > 1 ? parts.first : null;
    final name = parts.length > 1 ? parts.sublist(1).join(' ') : voter;
    final big = desk ? 64.0 : 38.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: align == TextAlign.center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text.rich(
            TextSpan(
              children: [
                if (number != null)
                  TextSpan(
                    text: '$number ',
                    style: Saloon.plate(big, color: accent),
                  ),
                TextSpan(
                  text: name,
                  style: Saloon.plate(big, color: title),
                ),
              ],
            ),
            maxLines: 1,
          ),
        ),
        SizedBox(height: 2 * _k),
        Text('DEVE VOTARE', style: Saloon.plate(desk ? 30 : 19, color: accent)),
        SizedBox(height: 10 * _k),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: desk ? 900 : 340),
          child: Text(
            _subtitle,
            textAlign: align,
            style: TextStyle(
              color: body,
              fontSize: desk ? 22 : 14.5,
              height: 1.35,
              fontWeight: FontWeight.w500,
              shadows: const [Shadow(color: Colors.black, blurRadius: 6)],
            ),
          ),
        ),
      ],
    );
  }

  Widget _strip({Color scrim = const Color(0xE60C0907)}) {
    final choice = _choice;
    final status = choice == null
        ? 'Tocca un nome sulla scheda, o astieniti.'
        : 'Hai segnato ${choice.number} ${choice.name}. Mettila nell\'urna, o tocca un altro nome.';
    final body = desk ? 21.0 : 14.5;
    return Container(
      decoration: BoxDecoration(
        color: scrim,
        borderRadius: BorderRadius.circular(16 * _k),
        border: Border.all(color: Saloon.brassDeep.withValues(alpha: 0.7)),
        boxShadow: const [BoxShadow(color: Color(0xAA000000), blurRadius: 16, offset: Offset(0, 6))],
      ),
      padding: EdgeInsets.fromLTRB(14 * _k, 10 * _k, 14 * _k, 12 * _k),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(Icons.how_to_vote_outlined, size: desk ? 28 : 20, color: Saloon.brass),
              ),
              SizedBox(width: 8 * _k),
              Expanded(
                child: Text(
                  status,
                  maxLines: 2,
                  style: TextStyle(color: AppColors.textPrimary, fontSize: body, height: 1.3, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          SizedBox(height: 10 * _k),
          Row(
            children: [
              Expanded(
                flex: 4,
                child: TargaButton(label: 'Astieniti', kind: TargaKind.secondary, desk: desk, expand: true, onPressed: () {}),
              ),
              SizedBox(width: 10 * _k),
              Expanded(
                flex: 6,
                child: TargaButton(label: 'Metti nell\'urna', desk: desk, expand: true, onPressed: choice == null ? null : () {}),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // A · Cabina di velluto.

  Widget _velvet(Size size) {
    final w = size.width;
    final h = size.height;
    final pad = desk ? 56.0 : 16.0;
    final valance = desk ? 120.0 : 78.0;
    final stripH = desk ? 176.0 : 128.0;
    final headTop = valance + (desk ? 30 : 18);
    final headH = desk ? 210.0 : 168.0;
    // The desk top, seen from a little above: from the back edge to the lip.
    final deskBack = headTop + headH + (desk ? 10 : 4);
    final deskLip = h - stripH - (desk ? 28 : 10);
    final curtain = desk ? w * 0.17 : w * 0.11;
    final ballotW = desk ? min(1040.0, w * 0.56) : w - 2 * curtain * 0.72;
    final ballotH = deskLip - deskBack - (desk ? 18 : 14);
    final ballot = Rect.fromCenter(
      center: Offset(w / 2 + (desk ? -40 : 0), deskBack + 6 + ballotH / 2),
      width: ballotW,
      height: ballotH,
    );
    final scene = _VelvetScene(
      valance: valance,
      deskBack: deskBack,
      deskLip: deskLip,
      curtain: curtain,
      lamp: desk ? Offset(ballot.right + 150, deskBack + 40) : Offset(w - curtain - 26, valance + 10),
      desk: desk,
    );
    return Stack(
      children: [
        Positioned.fill(child: CustomPaint(painter: scene)),
        Positioned(
          left: pad + (desk ? w * 0.12 : 0),
          right: pad + (desk ? w * 0.12 : 0),
          top: headTop,
          height: headH,
          child: Center(
            child: _heading(title: _cream, accent: Saloon.brass, body: const Color(0xFFE2D6C4)),
          ),
        ),
        Positioned.fromRect(
          rect: ballot,
          child: Transform.rotate(
            angle: desk ? -0.012 : -0.018,
            child: _GridBallot(candidates: candidates, marked: marked, desk: desk),
          ),
        ),
        // The pencil, down on the desk beside the sheet.
        Positioned(
          left: desk ? ballot.left - 210 : ballot.right - 120,
          top: desk ? ballot.bottom - 250 : ballot.bottom - 34,
          width: desk ? 190 : 150,
          height: desk ? 190 : 60,
          child: CustomPaint(
            painter: _PencilPainter(angle: desk ? -1.05 : -0.08, body: const Color(0xFF7E111A)),
          ),
        ),
        Positioned(
          left: pad + (desk ? w * 0.24 : 0),
          right: pad + (desk ? w * 0.24 : 0),
          bottom: desk ? 28 : 10,
          height: stripH,
          child: _strip(scrim: const Color(0xE6140B07)),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // B · Scheda timbrata.

  Widget _stamped(Size size) {
    final w = size.width;
    final h = size.height;
    final pad = desk ? 56.0 : 16.0;
    final curtainH = desk ? 300.0 : 214.0;
    final stripH = desk ? 176.0 : 128.0;
    // The sheet on the left, the stamp and its pad beside it on the right.
    final ballotW = desk ? 1000.0 : w - pad - 92;
    final top = curtainH + (desk ? 26 : 14);
    final ballotH = h - top - stripH - (desk ? 56 : 22);
    final ballot = Rect.fromLTWH(desk ? (w - ballotW) / 2 - 150 : pad, top, ballotW, ballotH);
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _ShelfScene(curtain: curtainH, desk: desk),
          ),
        ),
        Positioned(
          left: pad,
          right: pad,
          top: desk ? 36 : 18,
          height: curtainH - (desk ? 50 : 30),
          child: Center(
            child: _heading(title: _cream, accent: const Color(0xFFFF8A8F), body: const Color(0xFFEADBD0)),
          ),
        ),
        // The stamp pad, open on the shelf.
        Positioned(
          left: desk ? ballot.right + 70 : ballot.right + 6,
          top: desk ? ballot.top + 50 : ballot.top + 132,
          width: desk ? 300 : 80,
          height: desk ? 210 : 150,
          child: const CustomPaint(painter: _StampPadPainter()),
        ),
        Positioned.fromRect(
          rect: ballot,
          child: Transform.rotate(
            angle: desk ? 0.008 : 0.012,
            child: _RowBallot(candidates: candidates, marked: marked, desk: desk),
          ),
        ),
        // The rubber stamp, set down after use.
        Positioned(
          left: desk ? ballot.right + 110 : ballot.right + 2,
          top: desk ? ballot.top + 320 : ballot.top + 16,
          width: desk ? 220 : 92,
          height: desk ? 220 : 92,
          child: CustomPaint(painter: _RubberStampPainter(angle: desk ? 0.5 : 0.35)),
        ),
        Positioned(
          left: pad + (desk ? w * 0.24 : 0),
          right: pad + (desk ? w * 0.24 : 0),
          bottom: desk ? 28 : 10,
          height: stripH,
          child: _strip(),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // C · Cabina comunale.

  Widget _municipal(Size size) {
    final w = size.width;
    final h = size.height;
    final pad = desk ? 56.0 : 16.0;
    final curtainH = desk ? 286.0 : 226.0;
    final stripH = desk ? 176.0 : 128.0;
    final ballotW = desk ? 980.0 : w - 2 * pad - 8;
    final ballotTop = curtainH + (desk ? 58 : 26);
    // The card stands on the shelf; in front of it, the pencil on its chain.
    final ballotBottom = h - stripH - (desk ? 60 : 92);
    final ballot = Rect.fromLTRB((w - ballotW) / 2, ballotTop, (w + ballotW) / 2, ballotBottom);
    final shelfTop = ballot.bottom - (desk ? 40 : 26);
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _MunicipalScene(curtain: curtainH, shelfTop: shelfTop, desk: desk, ballot: ballot),
          ),
        ),
        Positioned(
          left: pad,
          right: pad,
          top: desk ? 64 : 40,
          height: curtainH - (desk ? 74 : 50),
          child: Center(
            child: _heading(title: _cream, accent: Saloon.brass, body: const Color(0xFFD8E2DA)),
          ),
        ),
        Positioned.fromRect(
          rect: ballot,
          child: _PlateBallot(candidates: candidates, marked: marked, desk: desk),
        ),
        Positioned(
          left: pad + (desk ? w * 0.24 : 0),
          right: pad + (desk ? w * 0.24 : 0),
          bottom: desk ? 28 : 10,
          height: stripH,
          child: _strip(scrim: const Color(0xE6081510)),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Ballot A: a cream sheet, a grid of numbered boxes, a pencil cross.

class _GridBallot extends StatelessWidget {
  final List<Candidate> candidates;
  final int? marked;
  final bool desk;

  const _GridBallot({required this.candidates, required this.marked, required this.desk});

  @override
  Widget build(BuildContext context) {
    final k = desk ? 1.55 : 1.0;
    final columns = desk ? 3 : 3;
    final rows = (candidates.length / columns).ceil();
    return CustomPaint(
      painter: const _PaperPainter(color: _paper, shade: _paperShade, radius: 3),
      child: Padding(
        padding: EdgeInsets.fromLTRB(14 * k, 12 * k, 14 * k, 14 * k),
        child: Column(
          children: [
            Text('SCHEDA DI VOTAZIONE', style: _serif(14 * k, _ink, spacing: 3 * k)),
            SizedBox(height: 2 * k),
            Text(
              'Segna con una croce un solo nome',
              style: _serif(11 * k, const Color(0xFF5A4A38), weight: FontWeight.w500, style: FontStyle.italic),
            ),
            SizedBox(height: 8 * k),
            Container(height: 1.4 * k, color: _ink),
            SizedBox(height: 2 * k),
            Container(height: 0.6 * k, color: _ink),
            SizedBox(height: 10 * k),
            Expanded(
              child: Column(
                children: [
                  for (var r = 0; r < rows; r++) ...[
                    if (r > 0) SizedBox(height: 8 * k),
                    Expanded(
                      child: Row(
                        children: [
                          for (var c = 0; c < columns; c++) ...[
                            if (c > 0) SizedBox(width: 8 * k),
                            Expanded(
                              child: r * columns + c < candidates.length
                                  ? _GridBox(
                                      candidates[r * columns + c],
                                      marked: candidates[r * columns + c].number == marked,
                                      k: k,
                                    )
                                  : const SizedBox(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridBox extends StatelessWidget {
  final Candidate candidate;
  final bool marked;
  final double k;

  const _GridBox(this.candidate, {required this.marked, required this.k});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0x0F5A4A38),
          border: Border.all(color: _ink.withValues(alpha: 0.85), width: 1.3 * k),
        ),
        padding: EdgeInsets.all(4 * k),
        child: LayoutBuilder(
          builder: (context, box) {
            final disk = min(box.maxHeight * 0.56, 46 * k);
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // The cross goes over the disk, like a cross on a party
                // symbol; the white number stays on top, legible.
                SizedBox(
                  width: disk,
                  height: disk,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(center: Alignment(-0.3, -0.4), colors: [Color(0xFF3A2C22), Color(0xFF120C08)]),
                        ),
                        child: SizedBox.expand(),
                      ),
                      if (marked)
                        Positioned(
                          left: -disk * 0.42,
                          top: -disk * 0.3,
                          width: disk * 1.84,
                          height: disk * 1.6,
                          child: CustomPaint(painter: _PencilCross(k: k)),
                        ),
                      Text('${candidate.number}', style: _serif(disk * 0.46, Colors.white, height: 1)),
                    ],
                  ),
                ),
                SizedBox(height: 4 * k),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(candidate.name.toUpperCase(), maxLines: 1, style: _serif(13.5 * k, _ink, spacing: 1 * k)),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// A pencil cross: two graphite strokes, gone over twice by a nervous hand.
class _PencilCross extends CustomPainter {
  final double k;

  const _PencilCross({required this.k});

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    final strokes = [
      (Offset(r.left, r.top + r.height * 0.06), Offset(r.right, r.bottom - r.height * 0.02)),
      (Offset(r.right - r.width * 0.04, r.top), Offset(r.left + r.width * 0.05, r.bottom)),
    ];
    for (final (i, (a, b)) in strokes.indexed) {
      for (var pass = 0; pass < 3; pass++) {
        final jitter = Offset((pass - 1) * 1.1 * k, (pass.isEven ? 1 : -1) * 0.8 * k);
        final mid = Offset.lerp(a, b, 0.5)! + Offset(i == 0 ? 2.5 * k : -2 * k, i == 0 ? -2 * k : -1.5 * k) + jitter;
        final path = Path()
          ..moveTo(a.dx + jitter.dx, a.dy + jitter.dy)
          ..quadraticBezierTo(mid.dx, mid.dy, b.dx - jitter.dx, b.dy + jitter.dy);
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = (pass == 0 ? 3.4 : 1.6) * k
            ..color = _graphite.withValues(alpha: pass == 0 ? 0.82 : 0.5),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_PencilCross oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// Ballot B: the printed scheda, one row per name, a rubber stamp.

class _RowBallot extends StatelessWidget {
  final List<Candidate> candidates;
  final int? marked;
  final bool desk;

  const _RowBallot({required this.candidates, required this.marked, required this.desk});

  @override
  Widget build(BuildContext context) {
    final k = desk ? 1.45 : 1.0;
    final columns = desk ? 2 : 1;
    final rows = (candidates.length / columns).ceil();
    return CustomPaint(
      painter: const _PaperPainter(color: Color(0xFFF3EAD3), shade: Color(0xFFDCCBA6), radius: 2, perforated: true),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16 * k, 12 * k, 16 * k, 18 * k),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('GIORNO 2', style: _serif(10 * k, const Color(0xFF6A5A48), weight: FontWeight.w600, spacing: 1.5)),
                const Spacer(),
                Text('N. 0042', style: _serif(10 * k, const Color(0xFF6A5A48), weight: FontWeight.w600, spacing: 1)),
              ],
            ),
            SizedBox(height: 2 * k),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'SCHEDA SEGRETA',
                style: _serif(24 * k, _stampRed, spacing: 4 * k, height: 1.1).copyWith(
                  shadows: const [Shadow(color: Color(0x33B3121E), offset: Offset(0.6, 0.6))],
                ),
              ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'Elezione del condannato · timbrare un solo nome',
                style: _serif(11 * k, const Color(0xFF4A3A2A), weight: FontWeight.w500, style: FontStyle.italic),
              ),
            ),
            SizedBox(height: 7 * k),
            Container(height: 2 * k, color: _stampRed.withValues(alpha: 0.85)),
            SizedBox(height: 2 * k),
            Container(height: 0.8 * k, color: _stampRed.withValues(alpha: 0.85)),
            SizedBox(height: 4 * k),
            Expanded(
              child: Column(
                children: [
                  // One column on the phone; two on the wide desk.
                  for (var r = 0; r < rows; r++)
                    Expanded(
                      child: Row(
                        children: [
                          for (var c = 0; c < columns; c++) ...[
                            if (c > 0)
                              Container(
                                width: 1 * k,
                                margin: EdgeInsets.symmetric(horizontal: 14 * k),
                                color: _stampRed.withValues(alpha: 0.5),
                              ),
                            Expanded(
                              child: c * rows + r < candidates.length
                                  ? _Row(
                                      candidates[c * rows + r],
                                      marked: candidates[c * rows + r].number == marked,
                                      k: k,
                                      last: r == rows - 1 || c * rows + r == candidates.length - 1,
                                    )
                                  : const SizedBox(),
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final Candidate candidate;
  final bool marked;
  final bool last;
  final double k;

  const _Row(this.candidate, {required this.marked, required this.k, required this.last});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(
                bottom: BorderSide(color: _ink.withValues(alpha: 0.35), width: 0.8 * k),
              ),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final plate = min(box.maxHeight - 8 * k, 36 * k);
          return Row(
            children: [
              Container(
                width: plate * 1.25,
                height: plate,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: const Color(0xFF15100C), borderRadius: BorderRadius.circular(3 * k)),
                child: Text('${candidate.number}', style: _serif(plate * 0.55, Colors.white, height: 1)),
              ),
              SizedBox(width: 12 * k),
              Expanded(
                child: Text(
                  candidate.name.toUpperCase(),
                  maxLines: 1,
                  style: _serif(min(plate * 0.6, 19 * k), _ink, spacing: 2 * k),
                ),
              ),
              // Dotted leader to the stamp circle.
              SizedBox(
                width: plate * 1.6,
                height: plate * 1.25,
                child: CustomPaint(
                  painter: _StampSpot(marked: marked, k: k),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The circle where the stamp goes; on the marked row, the red impression.
class _StampSpot extends CustomPainter {
  final bool marked;
  final double k;

  const _StampSpot({required this.marked, required this.k});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.height * 0.36;
    if (!marked) {
      final dot = Paint()..color = _ink.withValues(alpha: 0.45);
      for (var a = 0.0; a < 2 * pi; a += pi / 14) {
        canvas.drawCircle(c + Offset(cos(a), sin(a)) * r, 0.9 * k, dot);
      }
      return;
    }
    // The impression: bigger than the circle, a little crooked, inked unevenly.
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(-0.22);
    final big = r * 1.75;
    final rnd = Random(7);
    final ink = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt;
    // Two rings, broken where the rubber didn't take.
    for (final (radius, width) in [(big, 3.2 * k), (big * 0.78, 1.6 * k)]) {
      var a = 0.0;
      while (a < 2 * pi) {
        final len = 0.25 + rnd.nextDouble() * 0.6;
        ink
          ..strokeWidth = width
          ..color = _stampRed.withValues(alpha: 0.62 + rnd.nextDouble() * 0.3);
        canvas.drawArc(Rect.fromCircle(center: Offset.zero, radius: radius), a, len, false, ink);
        a += len + 0.04 + rnd.nextDouble() * 0.08;
      }
    }
    // The cross in the middle.
    final cross = Paint()
      ..strokeWidth = 4.6 * k
      ..strokeCap = StrokeCap.square
      ..color = _stampRed.withValues(alpha: 0.86);
    final x = big * 0.48;
    canvas.drawLine(Offset(-x, -x), Offset(x, x), cross);
    canvas.drawLine(Offset(x, -x), Offset(-x, x), cross);
    // Specks of ink around the edge.
    for (var i = 0; i < 9; i++) {
      final a = rnd.nextDouble() * 2 * pi;
      final d = big * (1.05 + rnd.nextDouble() * 0.15);
      canvas.drawCircle(
        Offset(cos(a), sin(a)) * d,
        (0.6 + rnd.nextDouble()) * k,
        Paint()..color = _stampRed.withValues(alpha: 0.55),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StampSpot oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// Ballot C: a slate card with enamel number plates in two columns.

class _PlateBallot extends StatelessWidget {
  final List<Candidate> candidates;
  final int? marked;
  final bool desk;

  const _PlateBallot({required this.candidates, required this.marked, required this.desk});

  @override
  Widget build(BuildContext context) {
    final k = desk ? 1.5 : 1.0;
    final columns = desk ? 3 : 2;
    final rows = (candidates.length / columns).ceil();
    return CustomPaint(
      painter: _SlatePainter(k: k),
      child: Padding(
        padding: EdgeInsets.fromLTRB(14 * k, 12 * k, 14 * k, 14 * k),
        child: Column(
          children: [
            Row(
              children: [
                _Rivet(k: k),
                Expanded(
                  child: Center(
                    child: Text('SCHEDA · VOTO SEGRETO', style: _serif(13 * k, Saloon.brass, spacing: 3 * k)),
                  ),
                ),
                _Rivet(k: k),
              ],
            ),
            SizedBox(height: 4 * k),
            Text(
              'Un foro, un nome. Il resto lo sa solo la cabina.',
              style: _serif(11 * k, const Color(0xFFB8C4BC), weight: FontWeight.w500, style: FontStyle.italic),
            ),
            SizedBox(height: 10 * k),
            Expanded(
              child: Column(
                children: [
                  for (var r = 0; r < rows; r++) ...[
                    if (r > 0) SizedBox(height: 7 * k),
                    Expanded(
                      child: Row(
                        children: [
                          // A short last row sits in the middle.
                          if (columns - min(columns, candidates.length - r * columns) case final int gap when gap > 0)
                            Spacer(flex: gap),
                          for (var c = 0; c < columns && r * columns + c < candidates.length; c++) ...[
                            if (c > 0) SizedBox(width: 10 * k),
                            Expanded(
                              flex: 2,
                              child: _Plate(
                                candidates[r * columns + c],
                                marked: candidates[r * columns + c].number == marked,
                                k: k,
                              ),
                            ),
                          ],
                          if (columns - min(columns, candidates.length - r * columns) case final int gap when gap > 0)
                            Spacer(flex: gap),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Rivet extends StatelessWidget {
  final double k;

  const _Rivet({required this.k});

  @override
  Widget build(BuildContext context) => Container(
    width: 9 * k,
    height: 9 * k,
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(center: Alignment(-0.4, -0.4), colors: [Color(0xFFFFE7A8), Color(0xFF8C6A26)]),
    ),
  );
}

class _Plate extends StatelessWidget {
  final Candidate candidate;
  final bool marked;
  final double k;

  const _Plate(this.candidate, {required this.marked, required this.k});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final h = box.maxHeight;
        final plate = min(h * 0.8, 46 * k);
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6 * k),
            color: marked ? const Color(0x22D9B45A) : const Color(0x14000000),
            border: Border.all(color: marked ? Saloon.brass : const Color(0x55D9B45A), width: (marked ? 1.6 : 1) * k),
          ),
          padding: EdgeInsets.symmetric(horizontal: 6 * k),
          child: Row(
            children: [
              // The enamel plate with a brass rim: white number on black.
              Container(
                width: plate,
                height: plate,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(center: Alignment(-0.3, -0.4), colors: [Color(0xFF2B2B2B), Color(0xFF0A0A0A)]),
                  border: Border.all(color: const Color(0xFFD9B45A), width: 2.2 * k),
                  boxShadow: const [BoxShadow(color: Color(0x88000000), blurRadius: 3, offset: Offset(0, 1.5))],
                ),
                child: Text('${candidate.number}', style: _serif(plate * 0.44, Colors.white, height: 1)),
              ),
              SizedBox(width: 8 * k),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    candidate.name.toUpperCase(),
                    maxLines: 1,
                    style: _serif(15 * k, const Color(0xFFF0EBDD), spacing: 1.2 * k),
                  ),
                ),
              ),
              SizedBox(
                width: plate * 0.78,
                height: plate * 0.78,
                child: CustomPaint(
                  painter: _PunchHole(marked: marked, k: k),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The punch: an empty ring to aim at; on the marked plate a clean hole
/// through the card, ringed in red ink.
class _PunchHole extends CustomPainter {
  final bool marked;
  final double k;

  const _PunchHole({required this.marked, required this.k});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width * 0.32;
    if (!marked) {
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1 * k
          ..color = const Color(0x88D9B45A),
      );
      return;
    }
    // The punch's inked die: a thick red ring around the hole, and a thin one.
    canvas.drawCircle(
      c,
      r * 1.18,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.6 * k
        ..color = const Color(0xFFE5404C),
    );
    canvas.drawCircle(
      c,
      r * 1.48,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3 * k
        ..color = const Color(0xCCE5404C),
    );
    // The hole: the shelf's dark wood shows through, the card edge catches light.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(colors: [Color(0xFF0A0604), Color(0xFF24130A)])
            .createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      pi * 0.15,
      pi * 0.9,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4 * k
        ..color = const Color(0xCCB8C4BC),
    );
  }

  @override
  bool shouldRepaint(_PunchHole oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// Paper, slate and the small objects on the desk.

class _PaperPainter extends CustomPainter {
  final Color color;
  final Color shade;
  final double radius;
  final bool perforated;

  const _PaperPainter({required this.color, required this.shade, this.radius = 3, this.perforated = false});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    canvas.drawRRect(
      rr.shift(const Offset(3, 8)),
      Paint()
        ..color = const Color(0xAA000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.drawRRect(
      rr,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(color, Colors.white, 0.25)!, color, shade],
          stops: const [0, 0.55, 1],
        ).createShader(rect),
    );
    // The grain of cheap paper.
    final rnd = Random(3);
    final fleck = Paint()..color = const Color(0x147A6040);
    for (var i = 0; i < (size.width * size.height / 260).round(); i++) {
      canvas.drawCircle(
        Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height),
        0.5 + rnd.nextDouble() * 0.7,
        fleck,
      );
    }
    // A fold across the middle, from the pocket of whoever brought it.
    canvas.drawLine(
      Offset(0, size.height * 0.5),
      Offset(size.width, size.height * 0.5),
      Paint()
        ..strokeWidth = 1
        ..color = const Color(0x18000000),
    );
    canvas.drawLine(
      Offset(0, size.height * 0.5 + 1),
      Offset(size.width, size.height * 0.5 + 1),
      Paint()
        ..strokeWidth = 1
        ..color = const Color(0x22FFFFFF),
    );
    if (perforated) {
      // The tear line of the stub.
      final hole = Paint()..color = const Color(0x55000000);
      for (var x = 8.0; x < size.width - 4; x += 7) {
        canvas.drawCircle(Offset(x, size.height - 7), 1.1, hole);
      }
    }
    // Lit from the top left (the lamp), shadowed at the bottom.
    canvas.drawRRect(
      rr,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x14FFF1C0), Color(0x00000000), Color(0x22000000)],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_PaperPainter oldDelegate) => false;
}

class _SlatePainter extends CustomPainter {
  final double k;

  const _SlatePainter({required this.k});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(10 * k));
    canvas.drawRRect(
      rr.shift(Offset(0, 8 * k)),
      Paint()
        ..color = const Color(0xCC000000)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 12 * k),
    );
    canvas.drawRRect(
      rr,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4A5450), Color(0xFF353D3A), Color(0xFF262C2A)],
        ).createShader(rect),
    );
    // Slate streaks.
    final rnd = Random(11);
    for (var i = 0; i < 40; i++) {
      final y = rnd.nextDouble() * size.height;
      canvas.drawLine(
        Offset(rnd.nextDouble() * size.width * 0.3, y),
        Offset(size.width * (0.5 + rnd.nextDouble() * 0.5), y + rnd.nextDouble() * 6 - 3),
        Paint()
          ..strokeWidth = 0.7
          ..color = (rnd.nextBool() ? Colors.white : Colors.black).withValues(alpha: 0.04),
      );
    }
    // The brass frame.
    canvas.drawRRect(
      rr.deflate(2 * k),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * k
        ..shader = const LinearGradient(colors: Targa.gold, stops: Targa.goldStops).createShader(rect),
    );
    canvas.drawRRect(
      rr.deflate(6.5 * k),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8 * k
        ..color = const Color(0x66D9B45A),
    );
  }

  @override
  bool shouldRepaint(_SlatePainter oldDelegate) => false;
}

/// A sharpened pencil lying down, [angle] from the horizontal: lacquered
/// body in facets, the bare wood cone, graphite tip, brass ferrule, eraser.
class _PencilPainter extends CustomPainter {
  final double angle;
  final Color body;

  const _PencilPainter({required this.angle, required this.body});

  @override
  void paint(Canvas canvas, Size size) {
    final length = sqrt(size.width * size.width + size.height * size.height) * 0.82;
    _pencil(canvas, size.center(Offset.zero), angle, length, body);
  }

  @override
  bool shouldRepaint(_PencilPainter oldDelegate) => false;
}

/// The pencil, centred on [center]: the tip points away along [angle]
/// reversed, the eraser end sits at center + (cos, sin) * length / 2.
void _pencil(Canvas canvas, Offset center, double angle, double length, Color body) {
  final thick = max(9.0, length * 0.075);
  canvas.save();
  canvas.translate(center.dx, center.dy);
  canvas.rotate(angle);
  final half = length / 2;
  // The shadow on the desk.
  canvas.drawRRect(
    RRect.fromRectAndRadius(Rect.fromLTRB(-half + 8, -thick / 2 + 5, half - 2, thick / 2 + 7), Radius.circular(thick / 2)),
    Paint()
      ..color = const Color(0x99000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
  );
  final tipLen = thick * 2.1;
  final ferrule = thick * 1.3;
  final eraser = thick * 0.9;
  final bodyRect = Rect.fromLTRB(-half + tipLen, -thick / 2, half - ferrule - eraser, thick / 2);
  // Three facets.
  final facet = thick / 3;
  for (var i = 0; i < 3; i++) {
    final shade = [Color.lerp(body, Colors.white, 0.28)!, body, Color.lerp(body, Colors.black, 0.4)!][i];
    canvas.drawRect(Rect.fromLTWH(bodyRect.left, bodyRect.top + i * facet, bodyRect.width, facet + 0.5), Paint()..color = shade);
  }
  // Gold lettering on the body.
  canvas.drawRect(
    Rect.fromLTWH(bodyRect.left + bodyRect.width * 0.35, bodyRect.top + facet * 1.3, bodyRect.width * 0.22, facet * 0.4),
    Paint()..color = const Color(0xCCD9B45A),
  );
  // The cone of bare wood and the graphite.
  final cone = Path()
    ..moveTo(bodyRect.left, -thick / 2)
    ..lineTo(-half + thick * 0.55, -thick * 0.12)
    ..lineTo(-half + thick * 0.55, thick * 0.12)
    ..lineTo(bodyRect.left, thick / 2)
    ..close();
  canvas.drawPath(
    cone,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFF0D2A0), Color(0xFFC89A60)],
      ).createShader(Rect.fromLTRB(-half, -thick / 2, bodyRect.left, thick / 2)),
  );
  final lead = Path()
    ..moveTo(-half + thick * 0.55, -thick * 0.12)
    ..lineTo(-half, 0)
    ..lineTo(-half + thick * 0.55, thick * 0.12)
    ..close();
  canvas.drawPath(lead, Paint()..color = _graphite);
  // Ferrule and eraser.
  final f = Rect.fromLTWH(bodyRect.right, -thick / 2 - 0.5, ferrule, thick + 1);
  canvas.drawRect(
    f,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: Targa.gold,
        stops: Targa.goldStops,
      ).createShader(f),
  );
  for (var i = 1; i < 4; i++) {
    canvas.drawLine(
      Offset(f.left + f.width * i / 4, f.top),
      Offset(f.left + f.width * i / 4, f.bottom),
      Paint()
        ..strokeWidth = 0.8
        ..color = const Color(0x886A4A16),
    );
  }
  canvas.drawRRect(
    RRect.fromRectAndCorners(
      Rect.fromLTWH(f.right, -thick / 2, eraser, thick),
      topRight: Radius.circular(thick * 0.3),
      bottomRight: Radius.circular(thick * 0.3),
    ),
    Paint()..color = const Color(0xFFC9786E),
  );
  canvas.restore();
}

/// The rubber stamp seen from above: a turned wooden knob on a dark base,
/// red ink on the rubber's edge.
class _RubberStampPainter extends CustomPainter {
  final double angle;

  const _RubberStampPainter({required this.angle});

  @override
  void paint(Canvas canvas, Size size) {
    final s = min(size.width, size.height);
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(angle);
    canvas.drawCircle(
      Offset(s * 0.06, s * 0.1),
      s * 0.42,
      Paint()
        ..color = const Color(0xAA000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    // The base: a square block, red at the edges where the rubber shows.
    final base = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: s * 0.74, height: s * 0.74),
      Radius.circular(s * 0.07),
    );
    canvas.drawRRect(base.inflate(s * 0.025), Paint()..color = const Color(0xFF8E0E18));
    canvas.drawRRect(
      base,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF8A5A34), Color(0xFF5A3418), Color(0xFF3A200E)],
        ).createShader(base.outerRect),
    );
    // Wood grain on the block.
    for (var i = 0; i < 6; i++) {
      final y = base.top + base.height * (0.12 + i * 0.15);
      canvas.drawLine(
        Offset(base.left + 4, y),
        Offset(base.right - 4, y + 2),
        Paint()
          ..strokeWidth = 1
          ..color = const Color(0x22000000),
      );
    }
    // The knob, turned and polished.
    canvas.drawCircle(
      Offset.zero,
      s * 0.25,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.4),
          colors: [Color(0xFFD9A066), Color(0xFF8A5228), Color(0xFF4A2810)],
          stops: [0, 0.6, 1],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: s * 0.25)),
    );
    canvas.drawCircle(Offset(-s * 0.08, -s * 0.09), s * 0.06, Paint()..color = const Color(0x66FFF1D6));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RubberStampPainter oldDelegate) => false;
}

/// The stamp pad: an open tin with a red felt pad, the lid hinged back.
class _StampPadPainter extends CustomPainter {
  const _StampPadPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.save();
    canvas.translate(w / 2, h / 2);
    canvas.rotate(-0.12);
    canvas.translate(-w / 2, -h / 2);
    final tin = RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.04, h * 0.42, w * 0.9, h * 0.52), Radius.circular(h * 0.06));
    final lid = RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.04, h * 0.02, w * 0.9, h * 0.38), Radius.circular(h * 0.06));
    for (final r in [tin, lid]) {
      canvas.drawRRect(
        r.shift(const Offset(4, 8)),
        Paint()
          ..color = const Color(0x99000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      canvas.drawRRect(
        r,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6E7A74), Color(0xFF3A4440), Color(0xFF262C2A)],
          ).createShader(r.outerRect),
      );
    }
    // The lid's printed label.
    final label = RRect.fromRectAndRadius(lid.outerRect.deflate(h * 0.07), Radius.circular(h * 0.03));
    canvas.drawRRect(label, Paint()..color = const Color(0xFF7E111A));
    final tp = TextPainter(
      text: TextSpan(
        text: 'TAMPONE',
        style: _serif(min(h * 0.11, label.width / 6.4), const Color(0xFFFFE7A8), spacing: min(h * 0.025, label.width / 40)),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, label.center - Offset(tp.width / 2, tp.height / 2));
    // The red felt, inked.
    final pad = RRect.fromRectAndRadius(tin.outerRect.deflate(h * 0.06), Radius.circular(h * 0.03));
    canvas.drawRRect(
      pad,
      Paint()..shader = const RadialGradient(colors: [Color(0xFFC0202C), Color(0xFF7A0A12)]).createShader(pad.outerRect),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StampPadPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// Velvet: folds that follow the shape of the curtain.

/// Paints a velvet curtain inside [shape]: a deep base, then for each fold a
/// soft highlight and a dark crease along [line] (fraction 0..1 across, from
/// the top to the bottom of the curtain).
void _velvetFolds(
  Canvas canvas,
  Path shape,
  Rect bounds,
  int folds,
  Offset Function(double f, double t) line, {
  Color base = const Color(0xFF5A0A10),
  Color light = const Color(0xFFB3242E),
  Color dark = const Color(0xFF1C0306),
  double scale = 1,
}) {
  canvas.save();
  canvas.clipPath(shape);
  canvas.drawRect(
    bounds,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color.lerp(base, Colors.black, 0.2)!, base, Color.lerp(base, Colors.black, 0.35)!],
      ).createShader(bounds),
  );
  Path curve(double f) {
    final p = Path();
    for (var i = 0; i <= 24; i++) {
      final o = line(f, i / 24);
      i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
    }
    return p;
  }

  final width = bounds.width / folds;
  for (var i = 0; i < folds; i++) {
    final f = (i + 0.5) / folds;
    canvas.drawPath(
      curve(f),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width * 0.42
        ..color = light.withValues(alpha: 0.55)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, width * 0.22 * scale),
    );
    canvas.drawPath(
      curve(f),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width * 0.1
        ..color = const Color(0x55FFD0C0)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, width * 0.06),
    );
    canvas.drawPath(
      curve(i / folds),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width * 0.3
        ..color = dark.withValues(alpha: 0.75)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, width * 0.14),
    );
  }
  canvas.restore();
}

/// A gold fringe hanging down along [edge] (sampled points), with tassels
/// every few points.
void _fringe(Canvas canvas, List<Offset> edge, double length, {int tasselEvery = 0, double k = 1}) {
  final thread = Paint()
    ..strokeWidth = 1.3 * k
    ..color = const Color(0xFFC9A23E);
  final threadDark = Paint()
    ..strokeWidth = 1.3 * k
    ..color = const Color(0xFF7A5A1C);
  for (var i = 0; i < edge.length; i++) {
    final p = edge[i];
    canvas.drawLine(p, p + Offset(0, length), i.isEven ? thread : threadDark);
  }
  if (tasselEvery <= 0) return;
  for (var i = 0; i < edge.length; i += tasselEvery) {
    final p = edge[i];
    final t = Path()
      ..moveTo(p.dx, p.dy)
      ..quadraticBezierTo(p.dx - 6 * k, p.dy + length * 1.4, p.dx, p.dy + length * 2)
      ..quadraticBezierTo(p.dx + 6 * k, p.dy + length * 1.4, p.dx, p.dy)
      ..close();
    canvas.drawPath(
      t,
      Paint()
        ..shader = const LinearGradient(
          colors: Targa.gold,
          stops: Targa.goldStops,
        ).createShader(Rect.fromLTWH(p.dx - 6 * k, p.dy, 12 * k, length * 2)),
    );
    canvas.drawCircle(p + Offset(0, length * 0.35), 3 * k, Paint()..color = const Color(0xFFFFE7A8));
  }
}

/// A brass rod across the top, with round finials.
void _rod(Canvas canvas, double left, double right, double y, double thick) {
  final r = Rect.fromLTRB(left, y - thick / 2, right, y + thick / 2);
  final gold = Paint()
    ..shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: Targa.gold,
      stops: Targa.goldStops,
    ).createShader(r);
  canvas.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(thick / 2)), gold);
  for (final x in [left + thick, right - thick]) {
    final c = Offset(x, y);
    canvas.drawCircle(
      c,
      thick * 1.15,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.4, -0.4),
          colors: [Color(0xFFFFE7A8), Color(0xFF9C7424)],
        ).createShader(Rect.fromCircle(center: c, radius: thick * 1.15)),
    );
  }
}

/// Wood with grain, for desks and shelves.
void _wood(
  Canvas canvas,
  Rect rect, {
  required List<Color> colors,
  int seed = 1,
  double density = 1,
  Alignment begin = Alignment.topCenter,
  Alignment end = Alignment.bottomCenter,
}) {
  canvas.drawRect(rect, Paint()..shader = LinearGradient(begin: begin, end: end, colors: colors).createShader(rect));
  final rnd = Random(seed);
  final lines = (rect.height / 7 * density).round();
  canvas.save();
  canvas.clipRect(rect);
  for (var i = 0; i < lines; i++) {
    final y = rect.top + rnd.nextDouble() * rect.height;
    final amp = 1.5 + rnd.nextDouble() * 4;
    final wave = 0.004 + rnd.nextDouble() * 0.01;
    final phase = rnd.nextDouble() * 6;
    final p = Path()..moveTo(rect.left, y);
    for (var x = rect.left; x <= rect.right; x += 8) {
      p.lineTo(x, y + sin(x * wave + phase) * amp);
    }
    canvas.drawPath(
      p,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6 + rnd.nextDouble() * 1.2
        ..color = (rnd.nextInt(4) == 0 ? const Color(0xFFFFD9A0) : Colors.black).withValues(
          alpha: 0.06 + rnd.nextDouble() * 0.08,
        ),
    );
  }
  canvas.restore();
}

// ---------------------------------------------------------------------------
// Scene A: the velvet booth, seen from inside.

class _VelvetScene extends CustomPainter {
  final double valance;
  final double deskBack;
  final double deskLip;
  final double curtain;
  final Offset lamp;
  final bool desk;

  const _VelvetScene({
    required this.valance,
    required this.deskBack,
    required this.deskLip,
    required this.curtain,
    required this.lamp,
    required this.desk,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final k = desk ? 1.6 : 1.0;
    // The back wall: walnut panels.
    final wall = Rect.fromLTWH(0, 0, w, deskBack);
    canvas.drawRect(
      wall,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1C100A), Color(0xFF2E1A0E), Color(0xFF1A0E07)],
        ).createShader(wall),
    );
    final panelW = desk ? 220.0 : 96.0;
    for (var x = curtain * 0.6; x < w; x += panelW) {
      final panel = Rect.fromLTWH(x + 10 * k, valance + 24 * k, panelW - 20 * k, deskBack - valance - 40 * k);
      canvas.drawRRect(
        RRect.fromRectAndRadius(panel, Radius.circular(4 * k)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 * k
          ..color = const Color(0x33000000),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(panel.shift(Offset(1.2 * k, 1.2 * k)), Radius.circular(4 * k)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1 * k
          ..color = const Color(0x14FFD9A0),
      );
    }
    // The lamp's warm pool on the wall and on the desk.
    final glowCenter = Offset(w / 2 + (desk ? 140 : 40), deskBack + (deskLip - deskBack) * 0.3);
    canvas.drawCircle(
      glowCenter,
      desk ? 900 : 420,
      Paint()
        ..shader = RadialGradient(
          colors: const [Color(0x40FFB858), Color(0x10FFB858), Color(0x00FFB858)],
          stops: const [0, 0.5, 1],
        ).createShader(Rect.fromCircle(center: glowCenter, radius: desk ? 900 : 420)),
    );
    // The desk top: walnut, seen from a little above.
    final top = Path()
      ..moveTo(curtain * 0.5, deskBack)
      ..lineTo(w - curtain * 0.5, deskBack)
      ..lineTo(w + 20, deskLip)
      ..lineTo(-20, deskLip)
      ..close();
    canvas.save();
    canvas.clipPath(top);
    _wood(
      canvas,
      Rect.fromLTRB(-20, deskBack, w + 20, deskLip),
      colors: const [Color(0xFF3A2112), Color(0xFF5E3A20), Color(0xFF6E4426)],
      seed: 5,
      density: 1.4,
    );
    // Warm light on the wood.
    canvas.drawCircle(
      glowCenter,
      desk ? 700 : 330,
      Paint()
        ..shader = const RadialGradient(colors: [Color(0x55FFC070), Color(0x00FFC070)])
            .createShader(Rect.fromCircle(center: glowCenter, radius: desk ? 700 : 330)),
    );
    canvas.restore();
    // The back edge of the desk against the wall.
    canvas.drawLine(
      Offset(curtain * 0.5, deskBack),
      Offset(w - curtain * 0.5, deskBack),
      Paint()
        ..strokeWidth = 3 * k
        ..color = const Color(0xFF120A05),
    );
    // The lip and the front panel.
    final lip = Rect.fromLTWH(0, deskLip, w, 14 * k);
    canvas.drawRect(
      lip,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFA06A3C), Color(0xFF5A3418), Color(0xFF2A160A)],
        ).createShader(lip),
    );
    final front = Rect.fromLTRB(0, lip.bottom, w, h);
    _wood(canvas, front, colors: const [Color(0xFF2A160A), Color(0xFF1A0E06)], seed: 9, density: 0.8);
    // The lamp: a banker's lamp on the wide desk; on the phone a pendant
    // hanging in the corner, above the words.
    desk ? _bankerLamp(canvas, lamp, k) : _pendant(canvas, lamp, k);
    // The curtains: tied back at the sides, under the valance.
    final tie = deskBack + (deskLip - deskBack) * 0.25;
    for (final left in [true, false]) {
      final outer = left ? -4.0 : w + 4;
      final inner = left ? curtain : w - curtain;
      final waist = left ? curtain * 0.42 : w - curtain * 0.42;
      final bottom = left ? curtain * 0.9 : w - curtain * 0.9;
      double innerAt(double t) {
        final y = valance + t * (h - valance);
        if (y < tie) {
          final u = (y - valance) / (tie - valance);
          return inner + (waist - inner) * (u * u);
        }
        final u = (y - tie) / (h - tie);
        return waist + (bottom - waist) * sqrt(u);
      }

      final shape = Path()..moveTo(outer, valance);
      for (var i = 0; i <= 40; i++) {
        final t = i / 40;
        shape.lineTo(innerAt(t), valance + t * (h - valance));
      }
      shape
        ..lineTo(outer, h)
        ..close();
      _velvetFolds(
        canvas,
        shape,
        Rect.fromLTRB(min(outer, inner) - 10, valance, max(outer, inner) + 10, h),
        desk ? 5 : 3,
        (f, t) => Offset(outer + (innerAt(t) - outer) * f, valance + t * (h - valance)),
        scale: k,
      );
      // The edge catches the light.
      final edge = Path();
      for (var i = 0; i <= 40; i++) {
        final t = i / 40;
        final o = Offset(innerAt(t), valance + t * (h - valance));
        i == 0 ? edge.moveTo(o.dx, o.dy) : edge.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(
        edge,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 * k
          ..color = const Color(0x88E5606A),
      );
      // The gold rope at the waist.
      final ropeY = tie;
      final x0 = left ? 0.0 : w;
      final x1 = waist + (left ? 4 * k : -4 * k);
      final rope = Path()
        ..moveTo(x0, ropeY - 6 * k)
        ..quadraticBezierTo((x0 + x1) / 2, ropeY + 8 * k, x1, ropeY);
      canvas.drawPath(
        rope,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6 * k
          ..color = const Color(0xFF9C7424),
      );
      canvas.drawPath(
        rope,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4 * k
          ..color = const Color(0xFFFFE7A8),
      );
      // Its tassel.
      final tc = Offset(x1 + (left ? -2 * k : 2 * k), ropeY + 2 * k);
      final tassel = Path()
        ..moveTo(tc.dx, tc.dy)
        ..quadraticBezierTo(tc.dx - 9 * k, tc.dy + 26 * k, tc.dx - 6 * k, tc.dy + 38 * k)
        ..lineTo(tc.dx + 6 * k, tc.dy + 38 * k)
        ..quadraticBezierTo(tc.dx + 9 * k, tc.dy + 26 * k, tc.dx, tc.dy)
        ..close();
      canvas.drawPath(
        tassel,
        Paint()
          ..shader = const LinearGradient(
            colors: Targa.gold,
            stops: Targa.goldStops,
          ).createShader(Rect.fromLTWH(tc.dx - 9 * k, tc.dy, 18 * k, 38 * k)),
      );
      canvas.drawCircle(tc + Offset(0, 6 * k), 5 * k, Paint()..color = const Color(0xFFFFE7A8));
    }
    // The valance: a velvet pelmet with a scalloped hem, fringe and tassels.
    final scallops = desk ? 9 : 4;
    final sw = w / scallops;
    final hem = Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(w, valance);
    for (var i = scallops; i > 0; i--) {
      final x1 = (i - 1) * sw;
      hem.quadraticBezierTo(x1 + sw / 2, valance + 22 * k, x1, valance);
    }
    hem.close();
    _velvetFolds(
      canvas,
      hem,
      Rect.fromLTWH(0, 0, w, valance + 24 * k),
      scallops * 3,
      (f, t) => Offset(f * w, t * (valance + 24 * k)),
      base: const Color(0xFF6A0C14),
      scale: k,
    );
    final edge = <Offset>[];
    for (var i = 0; i < scallops; i++) {
      final x0 = i * sw;
      for (var s = 0; s < 14; s++) {
        final u = s / 14;
        // Along the quadratic: from x0 to x0+sw, dipping in the middle.
        final x = x0 + sw * u;
        final y = valance + 2 * u * (1 - u) * 22 * k;
        edge.add(Offset(x, y - 1));
      }
    }
    _fringe(canvas, edge, 10 * k, tasselEvery: 14, k: k);
    _rod(canvas, -10, w + 10, 7 * k, 10 * k);
    // A vignette, so the eye goes to the ballot.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, 0.1),
          radius: 1.0,
          colors: const [Color(0x00000000), Color(0x00000000), Color(0x99000000)],
          stops: const [0, 0.6, 1],
        ).createShader(Offset.zero & size),
    );
  }

  /// A small pendant lamp: the cord from the valance, a brass cap, a green
  /// enamel cone and the bulb glowing under it.
  void _pendant(Canvas canvas, Offset top, double k) {
    final cord = Paint()
      ..strokeWidth = 1.6 * k
      ..color = const Color(0xFF0A0604);
    final shadeTop = top.dy + 22 * k;
    canvas.drawLine(Offset(top.dx, 0), Offset(top.dx, shadeTop), cord);
    final cap = Rect.fromCenter(center: Offset(top.dx, shadeTop), width: 12 * k, height: 8 * k);
    canvas.drawRRect(
      RRect.fromRectAndRadius(cap, Radius.circular(2 * k)),
      Paint()..shader = const LinearGradient(colors: Targa.gold, stops: Targa.goldStops).createShader(cap),
    );
    final bulb = Offset(top.dx, shadeTop + 20 * k);
    canvas.drawCircle(
      bulb,
      70 * k,
      Paint()
        ..shader = const RadialGradient(colors: [Color(0x99FFE2A0), Color(0x00FFC070)])
            .createShader(Rect.fromCircle(center: bulb, radius: 70 * k)),
    );
    final shade = Path()
      ..moveTo(top.dx - 6 * k, shadeTop + 3 * k)
      ..lineTo(top.dx + 6 * k, shadeTop + 3 * k)
      ..lineTo(top.dx + 26 * k, shadeTop + 20 * k)
      ..quadraticBezierTo(top.dx, shadeTop + 25 * k, top.dx - 26 * k, shadeTop + 20 * k)
      ..close();
    canvas.drawPath(
      shade,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF0E2A1C), Color(0xFF3FA06A), Color(0xFF1E5A3A), Color(0xFF0E2A1C)],
          stops: [0, 0.35, 0.6, 1],
        ).createShader(Rect.fromLTWH(top.dx - 26 * k, shadeTop, 52 * k, 25 * k)),
    );
    canvas.drawCircle(bulb - Offset(0, 1 * k), 5 * k, Paint()..color = const Color(0xFFFFF1C8));
  }

  /// A brass banker's lamp with a green glass shade, the bulb glowing under it.
  void _bankerLamp(Canvas canvas, Offset base, double k) {
    final s = 1.0 * k;
    // Base and stem.
    final foot = Rect.fromCenter(center: base, width: 70 * s, height: 16 * s);
    canvas.drawOval(
      foot.shift(Offset(0, 4 * s)),
      Paint()
        ..color = const Color(0xAA000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawOval(foot, Paint()..shader = const LinearGradient(colors: Targa.gold, stops: Targa.goldStops).createShader(foot));
    final stem = Rect.fromLTWH(base.dx - 3.5 * s, base.dy - 70 * s, 7 * s, 70 * s);
    canvas.drawRect(stem, Paint()..shader = const LinearGradient(colors: Targa.gold, stops: Targa.goldStops).createShader(stem));
    // The shade: a half cylinder in green glass.
    final shadeTop = base.dy - 96 * s;
    final shade = Path()
      ..moveTo(base.dx - 52 * s, shadeTop + 26 * s)
      ..quadraticBezierTo(base.dx - 50 * s, shadeTop, base.dx, shadeTop)
      ..quadraticBezierTo(base.dx + 50 * s, shadeTop, base.dx + 52 * s, shadeTop + 26 * s)
      ..close();
    // The bulb's glow under it.
    final bulb = Offset(base.dx, shadeTop + 30 * s);
    canvas.drawCircle(
      bulb,
      90 * s,
      Paint()
        ..shader = const RadialGradient(colors: [Color(0xAAFFE2A0), Color(0x00FFC070)])
            .createShader(Rect.fromCircle(center: bulb, radius: 90 * s)),
    );
    canvas.drawPath(
      shade,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF3FA06A), Color(0xFF1E5A3A), Color(0xFF0E2A1C)],
        ).createShader(Rect.fromLTWH(base.dx - 52 * s, shadeTop, 104 * s, 26 * s)),
    );
    canvas.drawLine(
      Offset(base.dx - 52 * s, shadeTop + 26 * s),
      Offset(base.dx + 52 * s, shadeTop + 26 * s),
      Paint()
        ..strokeWidth = 3 * s
        ..color = const Color(0xFFD9B45A),
    );
    canvas.drawPath(
      Path()
        ..moveTo(base.dx - 30 * s, shadeTop + 8 * s)
        ..quadraticBezierTo(base.dx, shadeTop + 1 * s, base.dx + 22 * s, shadeTop + 5 * s),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4 * s
        ..color = const Color(0x88CFFFE0),
    );
  }

  @override
  bool shouldRepaint(_VelvetScene oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// Scene B: looking down onto the shelf, the curtain at the back.

class _ShelfScene extends CustomPainter {
  final double curtain;
  final bool desk;

  const _ShelfScene({required this.curtain, required this.desk});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final k = desk ? 1.6 : 1.0;
    // The shelf, from above: oak planks running across.
    final shelf = Rect.fromLTRB(0, curtain, w, h);
    _wood(canvas, shelf, colors: const [Color(0xFF6B4226), Color(0xFF7A4C2C), Color(0xFF5A361E)], seed: 21, density: 1.6);
    final plank = desk ? 150.0 : 96.0;
    for (var y = curtain + plank; y < h; y += plank) {
      canvas.drawLine(
        Offset(0, y),
        Offset(w, y),
        Paint()
          ..strokeWidth = 2.2 * k
          ..color = const Color(0x55000000),
      );
      canvas.drawLine(
        Offset(0, y + 2 * k),
        Offset(w, y + 2 * k),
        Paint()
          ..strokeWidth = 1 * k
          ..color = const Color(0x22FFD9A0),
      );
    }
    // A pool of light from above.
    final light = Offset(w / 2, curtain + (h - curtain) * 0.42);
    canvas.drawCircle(
      light,
      desk ? 900 : 440,
      Paint()
        ..shader = const RadialGradient(colors: [Color(0x30FFE0A0), Color(0x00FFE0A0)])
            .createShader(Rect.fromCircle(center: light, radius: desk ? 900 : 440)),
    );
    // The curtain at the back, closed, hanging down to the shelf.
    final drape = Path()..addRect(Rect.fromLTWH(0, 0, w, curtain));
    final folds = desk ? 22 : 9;
    _velvetFolds(
      canvas,
      drape,
      Rect.fromLTWH(0, 0, w, curtain),
      folds,
      (f, t) => Offset(f * w + sin(t * pi) * (w / folds) * 0.15, t * curtain),
      base: const Color(0xFF4E0910),
      scale: k,
    );
    // A dark scrim at the top, under the words.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, curtain),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x88000000), Color(0x33000000), Color(0x11000000)],
        ).createShader(Rect.fromLTWH(0, 0, w, curtain)),
    );
    // The hem, with its fringe, falling over the shelf's back edge.
    final hem = Rect.fromLTWH(0, curtain - 12 * k, w, 12 * k);
    canvas.drawRect(
      hem,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF7E111A), Color(0xFF3A060B)],
        ).createShader(hem),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, curtain, w, 10 * k),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x88000000), Color(0x00000000)],
        ).createShader(Rect.fromLTWH(0, curtain, w, 10 * k)),
    );
    _fringe(canvas, [for (var x = 0.0; x < w; x += 3.2 * k) Offset(x, curtain - 1)], 9 * k, k: k);
    // Vignette.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, 0.2),
          radius: 1.05,
          colors: [Color(0x00000000), Color(0x00000000), Color(0xAA000000)],
          stops: [0, 0.55, 1],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(_ShelfScene oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// Scene C: the municipal booth, bottle green and brass.

class _MunicipalScene extends CustomPainter {
  final double curtain;
  final double shelfTop;
  final bool desk;
  final Rect ballot;

  const _MunicipalScene({required this.curtain, required this.shelfTop, required this.desk, required this.ballot});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final k = desk ? 1.6 : 1.0;
    // The panels: painted bottle green, a brass beading around each.
    final wall = Offset.zero & size;
    canvas.drawRect(
      wall,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF173226), Color(0xFF1E3E2F), Color(0xFF0E1F17)],
        ).createShader(wall),
    );
    final cols = desk ? 4 : 2;
    final pw = w / cols;
    for (var i = 0; i < cols; i++) {
      final panel = Rect.fromLTWH(i * pw + 14 * k, curtain + 20 * k, pw - 28 * k, shelfTop - curtain - 36 * k);
      if (panel.height <= 0) continue;
      final rr = RRect.fromRectAndRadius(panel, Radius.circular(6 * k));
      canvas.drawRRect(
        rr,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF214636), Color(0xFF15301F)],
          ).createShader(panel),
      );
      canvas.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 * k
          ..color = const Color(0x998C6A26),
      );
    }
    // A brass plaque: the booth's number.
    // On the phone the card covers the wall: the plaque is only on the desk.
    if (desk) {
      _plaque(canvas, Rect.fromCenter(center: Offset(w / 2, (curtain + ballot.top) / 2 + 2), width: 150 * k, height: 30 * k), k);
    }
    // The shelf: dark wood with a brass edge.
    final shelf = Rect.fromLTRB(0, shelfTop, w, h);
    _wood(canvas, shelf, colors: const [Color(0xFF3A2414), Color(0xFF2A190D), Color(0xFF160C06)], seed: 13, density: 1.2);
    final edge = Rect.fromLTWH(0, shelfTop - 6 * k, w, 9 * k);
    canvas.drawRect(
      edge,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: Targa.gold,
          stops: Targa.goldStops,
        ).createShader(edge),
    );
    // The light from the ceiling lamp.
    final light = Offset(w / 2, ballot.top + ballot.height * 0.3);
    canvas.drawCircle(
      light,
      desk ? 820 : 400,
      Paint()
        ..shader = const RadialGradient(colors: [Color(0x26FFF0C0), Color(0x00FFF0C0)])
            .createShader(Rect.fromCircle(center: light, radius: desk ? 820 : 400)),
    );
    // The pencil on its chain, from a brass eyelet on the left.
    // It lies on the shelf in front of the card: eraser end on the chain.
    final eyelet = desk ? Offset(ballot.left - 40, shelfTop + 50) : Offset(ballot.left + 10, ballot.bottom + 18);
    final eraser = desk ? Offset(ballot.left - 120, shelfTop + 150) : Offset(ballot.left + 136, ballot.bottom + 52);
    final tip = desk ? Offset(ballot.left - 390, shelfTop + 196) : Offset(ballot.right - 6, ballot.bottom + 46);
    _chain(canvas, eyelet, eraser, sag: (desk ? 14 : 12) * k, k: k);
    canvas.drawCircle(eyelet, 7 * k, Paint()..color = const Color(0xFFD9B45A));
    canvas.drawCircle(eyelet, 3 * k, Paint()..color = const Color(0xFF0E1F17));
    final along = eraser - tip;
    _pencil(canvas, (eraser + tip) / 2, atan2(along.dy, along.dx), along.distance, const Color(0xFF1E3E2F));
    // The curtain, closed behind the voter: on its brass rail with rings.
    final drape = Path()..addRect(Rect.fromLTWH(0, 0, w, curtain));
    final folds = desk ? 20 : 8;
    _velvetFolds(
      canvas,
      drape,
      Rect.fromLTWH(0, 0, w, curtain),
      folds,
      (f, t) => Offset(f * w + sin(t * pi * 1.2) * (w / folds) * 0.18, t * curtain),
      base: const Color(0xFF233A33),
      light: const Color(0xFF5E7E72),
      dark: const Color(0xFF07110D),
      scale: k,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, curtain),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x55000000), Color(0x88000000), Color(0x66000000)],
        ).createShader(Rect.fromLTWH(0, 0, w, curtain)),
    );
    // The hem.
    final hem = Rect.fromLTWH(0, curtain - 10 * k, w, 10 * k);
    canvas.drawRect(hem, Paint()..color = const Color(0xFF0E1F17));
    canvas.drawLine(
      Offset(0, curtain - 10 * k),
      Offset(w, curtain - 10 * k),
      Paint()
        ..strokeWidth = 1.6 * k
        ..color = const Color(0xAAD9B45A),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, curtain, w, 14 * k),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x99000000), Color(0x00000000)],
        ).createShader(Rect.fromLTWH(0, curtain, w, 14 * k)),
    );
    // Rail and rings.
    final railY = 14 * k;
    _rod(canvas, -10, w + 10, railY, 9 * k);
    final ringStep = w / folds;
    for (var i = 0; i <= folds; i++) {
      final c = Offset(i * ringStep, railY + 2 * k);
      canvas.drawCircle(
        c,
        8 * k,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 * k
          ..color = const Color(0xFFC9A23E),
      );
      canvas.drawCircle(c - Offset(2 * k, 3 * k), 2 * k, Paint()..color = const Color(0x99FFE7A8));
    }
    // Vignette.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, 0.15),
          radius: 1.05,
          colors: [Color(0x00000000), Color(0x00000000), Color(0x99000000)],
          stops: [0, 0.6, 1],
        ).createShader(Offset.zero & size),
    );
  }

  void _plaque(Canvas canvas, Rect r, double k) {
    final rr = RRect.fromRectAndRadius(r, Radius.circular(4 * k));
    canvas.drawRRect(rr, Paint()..shader = const LinearGradient(colors: Targa.gold, stops: Targa.goldStops).createShader(r));
    canvas.drawRRect(
      rr.deflate(3 * k),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1 * k
        ..color = const Color(0x886A4A16),
    );
    final tp = TextPainter(
      text: TextSpan(
        text: 'CABINA 3',
        style: _serif(15 * k, const Color(0xFF2A1C08), spacing: 3 * k),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, r.center - Offset(tp.width / 2, tp.height / 2));
  }

  void _chain(Canvas canvas, Offset a, Offset b, {required double sag, required double k}) {
    final links = ((b - a).distance / (9 * k)).round();
    for (var i = 0; i < links; i++) {
      final t = i / links;
      final p = Offset.lerp(a, b, t)! + Offset(0, sin(t * pi) * sag);
      final next = Offset.lerp(a, b, (i + 1) / links)! + Offset(0, sin((i + 1) / links * pi) * sag);
      final angle = atan2(next.dy - p.dy, next.dx - p.dx);
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(angle);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 11 * k, height: (i.isEven ? 6 : 2.5) * k),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8 * k
          ..color = i.isEven ? const Color(0xFFD9B45A) : const Color(0xFF9C7424),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_MunicipalScene oldDelegate) => false;
}
