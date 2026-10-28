import 'package:flutter/material.dart';

/// Una riga di testo per [FeltText]: il testo, lo stile pieno, la chiave.
typedef FeltLine = ({String text, TextStyle style, Key? key});

/// Testo sul panno che si legge sempre per intero: va a capo quanto serve e,
/// se non ci sta nello spazio che ha, rimpicciolisce il carattere (e lo
/// rimpagina) invece di troncare. Sotto [minScale], come ultima risorsa,
/// l'intero blocco si rimpicciolisce: mai i puntini.
class FeltText extends StatelessWidget {
  final List<FeltLine> lines;

  /// Lo spazio fra una riga e l'altra, a grandezza piena.
  final double gap;
  final double minScale;

  const FeltText(this.lines, {super.key, this.gap = 4, this.minScale = 0.55});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final scaler = MediaQuery.textScalerOf(context);
      final direction = Directionality.of(context);
      // Si misura con lo stesso stile che il [Text] userà: quello di fondo
      // (il carattere del tema) più quello della riga.
      final base = DefaultTextStyle.of(context).style;
      final width = box.maxWidth;
      final height = box.maxHeight;

      double heightAt(double scale) {
        var total = gap * scale * (lines.length - 1);
        for (final line in lines) {
          final painter = TextPainter(
            text: TextSpan(text: line.text, style: base.merge(_scaled(line.style, scale))),
            textAlign: TextAlign.center,
            textDirection: direction,
            textScaler: scaler,
          )..layout(maxWidth: width);
          total += painter.height;
          painter.dispose();
        }
        return total;
      }

      var scale = 1.0;
      if (width.isFinite && height.isFinite && heightAt(1) > height) {
        var low = minScale;
        var high = 1.0;
        for (var i = 0; i < 10; i++) {
          final mid = (low + high) / 2;
          if (heightAt(mid) <= height) {
            low = mid;
          } else {
            high = mid;
          }
        }
        scale = low;
      }

      final column = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, line) in lines.indexed) ...[
            if (i > 0) SizedBox(height: gap * scale),
            Text(line.text, key: line.key, textAlign: TextAlign.center, softWrap: true, style: _scaled(line.style, scale)),
          ],
        ],
      );
      if (!width.isFinite || !height.isFinite) return column;
      return FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(width: width, child: column),
      );
    },
  );

  static TextStyle _scaled(TextStyle style, double scale) =>
      scale == 1 ? style : style.copyWith(fontSize: (style.fontSize ?? 14) * scale);
}
