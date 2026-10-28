import 'package:flutter/material.dart';

/// The verdict in the strip above «Ready», on a phone: the sentence first
/// (who was lynched, which card), the ballot under it. The sentence is read
/// whole, never cut: on one line if it fits (a little smaller at most),
/// otherwise on two at full size, and then the ballot gives up its line (the
/// wax seals on the seats and the chat log still have it). The ballot never
/// wraps into a mess: one line that scrolls sideways, fading at the edge.
class VerdictLine extends StatelessWidget {
  final String? headline;
  final Key? headlineKey;
  final TextStyle headlineStyle;
  final String tally;
  final Key? tallyKey;
  final TextStyle tallyStyle;

  /// How tall the line may grow.
  final double height;

  /// The sentence may shrink this far to stay on one line.
  static const oneLineScale = 0.86;

  const VerdictLine({
    super.key,
    this.headline,
    this.headlineKey,
    required this.headlineStyle,
    required this.tally,
    this.tallyKey,
    required this.tallyStyle,
    required this.height,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final headline = this.headline;
      final tallyLine = TallyScroll(tally, key: tallyKey, style: tallyStyle);
      if (headline == null) return SizedBox(height: height, child: Align(alignment: Alignment.topLeft, child: tallyLine));
      final base = DefaultTextStyle.of(context).style.merge(headlineStyle);
      final scaler = MediaQuery.textScalerOf(context);
      final width = box.maxWidth;
      double widthAt(double scale) {
        final painter = TextPainter(
          text: TextSpan(text: headline, style: base.copyWith(fontSize: (base.fontSize ?? 14) * scale)),
          textDirection: Directionality.of(context),
          textScaler: scaler,
          maxLines: 1,
        )..layout();
        final w = painter.width;
        painter.dispose();
        return w;
      }

      final full = widthAt(1);
      final fit = full <= width ? 1.0 : width / full;
      if (fit >= oneLineScale) {
        return SizedBox(
          height: height,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(headline, key: headlineKey, softWrap: false, style: _scaled(headlineStyle, fit * 0.995)),
              const SizedBox(height: 2),
              Flexible(child: tallyLine),
            ],
          ),
        );
      }
      return SizedBox(
        height: height,
        child: Align(
          alignment: Alignment.topLeft,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.topLeft,
            child: SizedBox(width: width, child: Text(headline, key: headlineKey, style: headlineStyle)),
          ),
        ),
      );
    },
  );

  static TextStyle _scaled(TextStyle style, double scale) =>
      scale >= 1 ? style : style.copyWith(fontSize: (style.fontSize ?? 14) * scale);
}

/// One line that scrolls sideways when it is longer than the room, with a
/// fade on the side that has more.
class TallyScroll extends StatefulWidget {
  final String text;
  final TextStyle style;

  const TallyScroll(this.text, {super.key, required this.style});

  @override
  State<TallyScroll> createState() => _TallyScrollState();
}

class _TallyScrollState extends State<TallyScroll> {
  final _scroll = ScrollController();
  bool _start = false;
  bool _end = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_edges);
    WidgetsBinding.instance.addPostFrameCallback((_) => _edges());
  }

  @override
  void didUpdateWidget(TallyScroll old) {
    super.didUpdateWidget(old);
    WidgetsBinding.instance.addPostFrameCallback((_) => _edges());
  }

  void _edges() {
    if (!mounted || !_scroll.hasClients) return;
    final p = _scroll.position;
    final start = p.pixels > 1;
    final end = p.pixels < p.maxScrollExtent - 1;
    if (start != _start || end != _end) {
      setState(() {
        _start = start;
        _end = end;
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final line = SingleChildScrollView(
      controller: _scroll,
      scrollDirection: Axis.horizontal,
      physics: const ClampingScrollPhysics(),
      child: Text(widget.text, maxLines: 1, softWrap: false, style: widget.style),
    );
    if (!_start && !_end) return line;
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) => LinearGradient(
        colors: [
          _start ? Colors.transparent : Colors.black,
          Colors.black,
          Colors.black,
          _end ? Colors.transparent : Colors.black,
        ],
        stops: const [0, 0.08, 0.9, 1],
      ).createShader(rect),
      child: line,
    );
  }
}
