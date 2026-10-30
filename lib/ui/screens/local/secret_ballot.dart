import 'dart:math';

import 'package:flutter/material.dart';

import '../../../rules/player.dart';
import '../../desktop/desktop_canvas.dart';
import '../../theme/script_fonts.dart';
import '../../widgets/baked.dart';
import '../../widgets/player_avatar.dart';
import '../online/game/action_strip.dart';
import '../online/game/noir_ui.dart';
import 'ballot_paint.dart';

/// The words printed on the ballot and said over the booth.
class BallotWords {
  /// Who is in the booth, with the seat number ("4 DINO"), and the rest of
  /// the sentence ("DEVE VOTARE").
  final String voter;
  final String mustVote;
  final String secrecy;

  /// The revealed Mayor, when there is one: his vote weighs on the count.
  final String? note;
  final String day;
  final String serial;
  final String title;
  final String rule;
  final String pad;

  const BallotWords({
    required this.voter,
    required this.mustVote,
    required this.secrecy,
    this.note,
    required this.day,
    required this.serial,
    required this.title,
    required this.rule,
    required this.pad,
  });
}

/// The inside of the booth, the whole screen: the closed curtain with who
/// must vote, the oak shelf, the printed secret ballot with a portrait for
/// every name, the rubber stamp and its pad, and the strip under it all.
///
/// Everything still is baked once (the shelf, the sheet and its portraits);
/// only the stamp moves, on its own layer. Nothing ever scrolls: the rows
/// shrink, or go to two columns, so the stamped name stays in sight.
class SecretBooth extends StatelessWidget {
  final BallotWords words;
  final List<Player> candidates;
  final Map<Player, int> numbers;
  final Player? marked;
  final ValueChanged<Player> onMark;

  /// The stamp hits the paper.
  final VoidCallback onImpact;

  /// Who is voting: a new voter gets a clean sheet.
  final Object voterKey;
  final Widget leading;
  final List<Widget> actions;
  final Widget strip;

  const SecretBooth({
    super.key,
    required this.words,
    required this.candidates,
    required this.numbers,
    required this.marked,
    required this.onMark,
    required this.onImpact,
    required this.voterKey,
    required this.leading,
    required this.actions,
    required this.strip,
  });

  @override
  Widget build(BuildContext context) {
    final desk = DesktopCanvas.of(context);
    return ColoredBox(
      color: Saloon.ink,
      child: LayoutBuilder(
        builder: (context, box) {
          final size = box.biggest;
          final safe = MediaQuery.paddingOf(context);
          // Under 720 points the title shrinks to the height of the buttons.
          final short = !desk && size.height < 720;
          final title = short ? StageHeader.height : (desk ? 132.0 : 84.0);
          final titleTop = safe.top + (short ? 0 : 4);
          final secrecy = desk ? 40.0 : 44.0;
          final note = words.note == null ? 0.0 : (desk ? 34.0 : 22.0);
          final curtain = titleTop + title + secrecy + note + (desk ? 22 : 12);
          final stripBox = ActionStrip.heightFor(desk: desk) + (desk ? 26 : 16);
          final stripGap = max(safe.bottom, desk ? 22.0 : 8.0);
          final area = Rect.fromLTRB(0, curtain + (desk ? 22 : 12), size.width, size.height - stripBox - stripGap - (desk ? 16 : 8));
          final geometry = BallotGeometry.of(area.size, candidates.length, desk: desk);
          return Stack(
            children: [
              Positioned.fill(
                child: Baked(
                  child: SizedBox.expand(
                    child: CustomPaint(painter: ShelfScenePainter(curtain: curtain, desk: desk)),
                  ),
                ),
              ),
              Positioned(
                left: desk ? 200 : 104,
                right: desk ? 200 : 104,
                top: titleTop,
                height: title,
                child: Center(child: _HeadingText(words: words, short: short, desk: desk)),
              ),
              Positioned(
                left: desk ? 24 : 8,
                top: safe.top,
                height: StageHeader.height,
                child: leading,
              ),
              Positioned(
                right: desk ? 24 : 8,
                top: safe.top,
                height: StageHeader.height,
                child: Row(mainAxisSize: MainAxisSize.min, children: actions),
              ),
              Positioned(
                left: desk ? 180 : 16,
                right: desk ? 180 : 16,
                top: titleTop + title,
                height: secrecy + note,
                child: Column(
                  children: [
                    SizedBox(
                      height: secrecy,
                      child: Center(
                        child: Text(
                          words.secrecy,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: const Color(0xFFEADBD0),
                            fontSize: desk ? 22 : 14,
                            height: 1.3,
                            fontWeight: FontWeight.w500,
                            shadows: const [Shadow(color: Colors.black, blurRadius: 6)],
                          ),
                        ),
                      ),
                    ),
                    if (words.note case final line?)
                      SizedBox(
                        height: note,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            line,
                            key: const Key('local.mayor'),
                            maxLines: 1,
                            style: TextStyle(
                              color: Saloon.brass,
                              fontSize: desk ? 20 : 13.5,
                              fontWeight: FontWeight.w700,
                              shadows: const [Shadow(color: Colors.black, blurRadius: 6)],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Positioned.fromRect(
                rect: area,
                child: SecretBallot(
                  key: ValueKey(voterKey),
                  geometry: geometry,
                  words: words,
                  candidates: candidates,
                  numbers: numbers,
                  marked: marked,
                  onMark: onMark,
                  onImpact: onImpact,
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: stripGap,
                height: stripBox,
                child: Center(
                  child: Container(
                    constraints: BoxConstraints(maxWidth: desk ? 900 : 560),
                    margin: EdgeInsets.symmetric(horizontal: desk ? 0 : 8),
                    padding: EdgeInsets.fromLTRB(desk ? 22 : 10, 0, desk ? 22 : 10, desk ? 10 : 6),
                    decoration: Saloon.scrim(radius: desk ? 20 : 14),
                    child: strip,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HeadingText extends StatelessWidget {
  final BallotWords words;
  final bool short;
  final bool desk;

  const _HeadingText({required this.words, required this.short, required this.desk});

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFFF8A8F);
    const cream = Color(0xFFFFF1D6);
    final big = short ? 20.0 : (desk ? 62.0 : 36.0);
    final small = short ? 14.0 : (desk ? 30.0 : 18.0);
    final parts = words.voter.split(' ');
    final number = parts.length > 1 ? parts.first : null;
    final name = parts.length > 1 ? parts.sublist(1).join(' ') : words.voter;
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text.rich(
        key: const Key('local.mustVote'),
        textAlign: TextAlign.center,
        TextSpan(
          children: [
            if (number != null) TextSpan(text: '$number ', style: Saloon.plate(big, color: accent)),
            TextSpan(text: name, style: Saloon.plate(big, color: cream)),
            TextSpan(text: '\n', style: Saloon.plate(small * 0.3)),
            TextSpan(text: words.mustVote, style: Saloon.plate(small, color: accent)),
          ],
        ),
        maxLines: 2,
      ),
    );
  }
}

/// Where everything goes on the sheet: one column with the stamp and the
/// pad beside it while the rows stay tall enough, then two columns with the
/// stamp on the sheet's top corner.
class BallotGeometry {
  final Size sheet;

  /// The sheet's top left corner in the booth's area.
  final Offset origin;
  final int columns;
  final int rows;
  final double rowHeight;
  final double headerHeight;
  final double padding;

  /// The stamp and the pad lie on the sheet's top corner, not beside it.
  final bool corner;
  final double scale;
  final int count;
  final Rect padRect;
  final Rect stampRect;

  const BallotGeometry._({
    required this.sheet,
    required this.origin,
    required this.columns,
    required this.rows,
    required this.rowHeight,
    required this.headerHeight,
    required this.padding,
    required this.corner,
    required this.scale,
    required this.count,
    required this.padRect,
    required this.stampRect,
  });

  /// The tallest row: past this the sheet stops growing, and sits on the shelf.
  static const _tallest = 84.0;

  /// The shortest row with the stamp beside the sheet: below this, two columns.
  static const _shortest = 52.0;

  factory BallotGeometry.of(Size area, int count, {required bool desk}) {
    final k = desk ? 1.45 : 1.0;
    final padding = 14 * k;
    final foot = 14 * k;
    final fullHeader = 78 * k;
    final slimHeader = 50 * k;
    final tallest = _tallest * (desk ? 1.3 : 1);
    if (desk) {
      final columns = count > 6 ? 2 : 1;
      final rows = max((count / columns).ceil(), 1);
      final rowHeight = min((area.height - fullHeader - foot) / rows, tallest);
      final width = columns == 1 ? 760.0 : 1120.0;
      const gutter = 300.0;
      final height = fullHeader + foot + rowHeight * rows;
      final origin = Offset((area.width - width - gutter) / 2, max((area.height - height) / 2, 0));
      return BallotGeometry._(
        sheet: Size(width, height),
        origin: origin,
        columns: columns,
        rows: rows,
        rowHeight: rowHeight,
        headerHeight: fullHeader,
        padding: padding,
        corner: false,
        scale: k,
        count: count,
        padRect: Rect.fromLTWH(width + 56, 16, 220, 170),
        stampRect: Rect.fromLTWH(width + 74, 200, 180, 180),
      );
    }
    final beside = area.width < 520 ? 92.0 : 150.0;
    final besideRow = (area.height - fullHeader - foot) / max(count, 1);
    if (besideRow >= _shortest) {
      final width = min(area.width - 12 - beside, 520.0);
      final rowHeight = min(besideRow, tallest);
      final height = fullHeader + foot + rowHeight * count;
      final origin = Offset(max((area.width - width - beside) / 2, 8), max((area.height - height) / 2, 0));
      final side = beside - 8;
      return BallotGeometry._(
        sheet: Size(width, height),
        origin: origin,
        columns: 1,
        rows: max(count, 1),
        rowHeight: rowHeight,
        headerHeight: fullHeader,
        padding: padding,
        corner: false,
        scale: 1,
        count: count,
        padRect: Rect.fromLTWH(width + 2, 104, side, side * 1.5),
        stampRect: Rect.fromLTWH(width, 8, side, side),
      );
    }
    final rows = (count / 2).ceil();
    final width = min(area.width - 16, 640.0);
    final rowHeight = min((area.height - slimHeader - foot) / rows, tallest);
    final height = slimHeader + foot + rowHeight * rows;
    final origin = Offset((area.width - width) / 2, max((area.height - height) / 2, 0));
    return BallotGeometry._(
      sheet: Size(width, height),
      origin: origin,
      columns: 2,
      rows: rows,
      rowHeight: rowHeight,
      headerHeight: slimHeader,
      padding: padding,
      corner: true,
      scale: 1,
      count: count,
      padRect: Rect.fromLTWH(width - 118, -14, 62, 62),
      stampRect: Rect.fromLTWH(width - 60, -14, 62, 62),
    );
  }

  double get _columnGap => columns > 1 ? 21 * scale : 0;

  double get cellWidth => (sheet.width - padding * 2 - _columnGap * (columns - 1)) / columns;

  /// The box of name number [index], filling down each column.
  Rect cell(int index) {
    final column = index ~/ rows;
    final row = index % rows;
    return Rect.fromLTWH(
      padding + column * (cellWidth + _columnGap),
      headerHeight + row * rowHeight,
      cellWidth,
      rowHeight,
    );
  }

  /// The side of the stamp's dotted square: the impression comes out a
  /// little bigger than the row.
  double get mark => wide ? min(rowHeight * 0.82, 58 * scale) : portrait * 0.74;

  /// The seat number's plate, its width, and the portrait, in a row.
  double get plate => wide ? min(rowHeight * 0.44, 30 * scale) : min(rowHeight * 0.38, 22.0);
  double get plateWidth => plate * 1.2;
  double get portrait => min(rowHeight - 6 * scale, min(cellWidth * (wide ? 0.36 : 0.32), 76 * scale));
  static const _plateGap = 5.0;

  /// The rows are wide enough for the name and the dotted circle beside it.
  bool get wide => columns == 1 || scale > 1;

  /// Where the impression lands in [cell]: in its circle or, on the narrow
  /// rows, right on the face, so the name stays clean.
  Offset spot(Rect cell) => wide
      ? Offset(cell.right - mark * 0.55, cell.center.dy)
      : Offset(cell.left + plateWidth + _plateGap * scale + portrait / 2, cell.center.dy);
}

/// The sheet on the shelf, with the stamp beside it. Tap a name: the stamp
/// leaves its place, comes down on the row, and goes back.
class SecretBallot extends StatefulWidget {
  final BallotGeometry geometry;
  final BallotWords words;
  final List<Player> candidates;
  final Map<Player, int> numbers;
  final Player? marked;
  final ValueChanged<Player> onMark;
  final VoidCallback onImpact;

  const SecretBallot({
    super.key,
    required this.geometry,
    required this.words,
    required this.candidates,
    required this.numbers,
    required this.marked,
    required this.onMark,
    required this.onImpact,
  });

  @override
  State<SecretBallot> createState() => _SecretBallotState();
}

class _SecretBallotState extends State<SecretBallot> with SingleTickerProviderStateMixin {
  /// When, in the stamp's trip, it touches the paper.
  static const _touch = 0.56;

  late final AnimationController _stamp = AnimationController(vsync: this, duration: const Duration(milliseconds: 620))
    ..addListener(_watchTouch);

  /// The name with the ink on it: the stamp has been there.
  Player? _inked;

  /// Where the stamp is going.
  Offset? _target;

  @override
  void didUpdateWidget(SecretBallot old) {
    super.didUpdateWidget(old);
    final marked = widget.marked;
    if (marked == old.marked) return;
    _inked = null;
    if (marked == null) {
      _stamp.value = 0;
      return;
    }
    _target = _spotOf(marked);
    if (MediaQuery.disableAnimationsOf(context)) {
      _inked = marked;
      widget.onImpact();
    } else {
      _stamp.forward(from: 0);
    }
  }

  void _watchTouch() {
    if (_inked != null || _stamp.value < _touch || widget.marked == null) return;
    setState(() => _inked = widget.marked);
    widget.onImpact();
  }

  Offset _spotOf(Player player) {
    final g = widget.geometry;
    return g.spot(g.cell(widget.candidates.indexOf(player)));
  }

  @override
  void dispose() {
    _stamp.dispose();
    super.dispose();
  }

  /// Where the stamp is at this point of its trip, and how far off the paper.
  (Offset, double) _flight(double t, Offset rest, Offset target) {
    if (t <= 0 || t >= 1) return (rest, 1);
    if (t < _touch) {
      final go = (t / _touch).clamp(0.0, 1.0);
      final eased = Curves.easeInOut.transform(min(go / 0.8, 1));
      final lift = go < 0.8 ? 1 + 0.22 * sin(go / 0.8 * pi / 2) : 1.22 - 0.3 * Curves.easeIn.transform((go - 0.8) / 0.2);
      return (Offset.lerp(rest, target, eased)!, lift);
    }
    if (t < 0.68) return (target, 0.92);
    final back = Curves.easeInOut.transform((t - 0.68) / 0.32);
    return (Offset.lerp(target, rest, back)!, 0.92 + 0.3 * sin(back * pi) + 0.08 * back);
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.geometry;
    final rest = g.stampRect.center;
    final inked = _inked;
    final inkedAt = inked == null ? null : _spotOf(inked);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: g.origin.dx,
          top: g.origin.dy,
          width: g.sheet.width,
          height: g.sheet.height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: Baked(
                  exact: true,
                  overflow: const EdgeInsets.all(24),
                  child: _Sheet(
                    geometry: g,
                    words: widget.words,
                    candidates: widget.candidates,
                    numbers: widget.numbers,
                    onMark: widget.onMark,
                  ),
                ),
              ),
              if (inkedAt != null)
                Positioned(
                  key: const Key('ballot.stamped'),
                  left: inkedAt.dx - g.mark / 2,
                  top: inkedAt.dy - g.mark / 2,
                  width: g.mark,
                  height: g.mark,
                  child: IgnorePointer(
                    child: CustomPaint(painter: StampSpotPainter(marked: true, k: g.mark / 46)),
                  ),
                ),
              Positioned.fromRect(
                rect: g.padRect,
                child: IgnorePointer(
                  child: Baked(
                    overflow: const EdgeInsets.all(16),
                    child: SizedBox.expand(child: CustomPaint(painter: StampPadPainter(label: widget.words.pad))),
                  ),
                ),
              ),
              Positioned.fromRect(
                rect: g.stampRect,
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _stamp,
                    builder: (context, child) {
                      final (at, lift) = _flight(_stamp.value, rest, _target ?? rest);
                      return Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.translationValues(at.dx - rest.dx, at.dy - rest.dy, 0)
                          ..scaleByDouble(lift, lift, 1, 1),
                        child: child,
                      );
                    },
                    child: const RepaintBoundary(
                      child: SizedBox.expand(child: CustomPaint(painter: RubberStampPainter(angle: 0.35))),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The printed sheet: everything on it that never changes.
class _Sheet extends StatelessWidget {
  final BallotGeometry geometry;
  final BallotWords words;
  final List<Player> candidates;
  final Map<Player, int> numbers;
  final ValueChanged<Player> onMark;

  const _Sheet({
    required this.geometry,
    required this.words,
    required this.candidates,
    required this.numbers,
    required this.onMark,
  });

  @override
  Widget build(BuildContext context) {
    final g = geometry;
    final k = g.scale;
    const faded = Color(0xFF6A5A48);
    return CustomPaint(
      painter: const BallotPaperPainter(
        color: Color(0xFFF3EAD3),
        shade: Color(0xFFDCCBA6),
        radius: 2,
        perforated: true,
        tilt: 0.008,
      ),
      child: Stack(
        children: [
          Positioned(
            left: g.padding,
            right: g.corner ? 126 : g.padding,
            top: (g.corner ? 6 : 10) * k,
            height: g.headerHeight - (g.corner ? 12 : 16) * k,
            child: Column(
              crossAxisAlignment: g.corner ? CrossAxisAlignment.start : CrossAxisAlignment.stretch,
              children: [
                if (!g.corner)
                  Row(
                    children: [
                      Text(words.day, style: _serif(10 * k, faded, weight: FontWeight.w600, spacing: 1.5)),
                      const Spacer(),
                      Text(words.serial, style: _serif(10 * k, faded, weight: FontWeight.w600, spacing: 1)),
                    ],
                  ),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: g.corner ? Alignment.centerLeft : Alignment.center,
                    child: Text(
                      words.title,
                      maxLines: 1,
                      style: _serif(23 * k, stampRed, spacing: 3 * k, height: 1.1),
                    ),
                  ),
                ),
                if (!g.corner)
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      words.rule,
                      maxLines: 1,
                      style: _serif(11 * k, const Color(0xFF4A3A2A), weight: FontWeight.w500, style: FontStyle.italic),
                    ),
                  ),
                SizedBox(height: 5 * k),
                Container(height: 2 * k, color: stampRed.withValues(alpha: 0.85)),
                SizedBox(height: 2 * k),
                Container(height: 0.8 * k, color: stampRed.withValues(alpha: 0.85)),
              ],
            ),
          ),
          for (final (i, player) in candidates.indexed)
            Positioned.fromRect(
              rect: g.cell(i),
              child: _Row(
                player: player,
                number: numbers[player],
                geometry: g,
                ruled: (i + 1) % g.rows != 0 && i != candidates.length - 1,
                onTap: () => onMark(player),
              ),
            ),
          if (g.columns > 1)
            Positioned(
              left: g.padding + g.cellWidth + g._columnGap / 2,
              width: 1 * k,
              top: g.headerHeight + 4,
              height: g.rowHeight * g.rows - 8,
              child: ColoredBox(color: stampRed.withValues(alpha: 0.5)),
            ),
        ],
      ),
    );
  }
}

/// One name on the ballot: the seat number, the portrait from the table,
/// the name, and on the wide rows the dotted circle for the stamp.
class _Row extends StatelessWidget {
  final Player player;
  final int? number;
  final BallotGeometry geometry;
  final bool ruled;
  final VoidCallback onTap;

  const _Row({required this.player, required this.number, required this.geometry, required this.ruled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final g = geometry;
    final k = g.scale;
    final h = g.rowHeight;
    final plate = g.plate;
    final name = (h * 0.32).clamp(13.0, 19 * k);
    return Semantics(
      button: true,
      label: player.name,
      excludeSemantics: true,
      child: GestureDetector(
        key: ValueKey('ballot-${player.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: ruled ? Border(bottom: BorderSide(color: const Color(0x591C140E), width: 0.8 * k)) : null,
          ),
          child: Row(
            children: [
              Container(
                width: g.plateWidth,
                height: plate,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: const Color(0xFF15100C), borderRadius: BorderRadius.circular(3 * k)),
                child: Text('${number ?? ''}', style: _serif(plate * 0.6, Colors.white, height: 1)),
              ),
              SizedBox(width: BallotGeometry._plateGap * k),
              PlayerAvatar(seed: player.name, size: g.portrait),
              SizedBox(width: 7 * k),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(player.name.toUpperCase(), maxLines: 1, style: _serif(name, const Color(0xFF1C140E), spacing: 0.5 * k)),
                ),
              ),
              if (g.wide)
                SizedBox.square(
                  dimension: g.mark * 1.1,
                  child: CustomPaint(painter: StampSpotPainter(marked: false, k: k)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

TextStyle _serif(double size, Color color, {FontWeight weight = FontWeight.w700, double spacing = 0, double? height, FontStyle? style}) => TextStyle(
  fontFamily: 'Georgia',
  fontFamilyFallback: serifFallback,
  fontSize: size,
  fontWeight: weight,
  letterSpacing: spacing,
  height: height,
  fontStyle: style,
  color: color,
  decoration: TextDecoration.none,
);
