import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../sound/cue_sounds.dart';
import '../../sound/sound_stage.dart';
import '../theme/app_theme.dart';
import 'noir_avatar.dart';
import '../../sound/memes.dart';

/// Il tavolo da poker nel retro del locale: i giocatori seduti intorno al
/// panno verde, il mazzo che si mescola al centro e una carta coperta che
/// vola davanti a ognuno. Chi ha preso cosa non si vede: le carte sono tutte
/// uguali, viste da dietro.
class DealTable extends StatefulWidget {
  /// Un nome per posto, in senso orario a partire dall'alto.
  final List<String> names;
  final VoidCallback? onDealt;

  const DealTable({super.key, required this.names, this.onDealt});

  @override
  State<DealTable> createState() => _DealTableState();
}

class _DealTableState extends State<DealTable> with SingleTickerProviderStateMixin {
  static const _shuffle = 1100.0;
  static const _stagger = 190.0;
  static const _flight = 520.0;

  late final AnimationController _deal;
  int _landed = 0;

  double get _total => _shuffle + widget.names.length * _stagger + _flight;

  @override
  void initState() {
    super.initState();
    _deal = AnimationController(vsync: this, duration: Duration(milliseconds: _total.round()))
      ..addListener(_tap)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) widget.onDealt?.call();
      })
      ..forward();
  }

  /// Quanto ha volato la carta [index], da 0 (nel mazzo) a 1 (sul tavolo).
  double _progress(int index) {
    final elapsed = _deal.value * _total - _shuffle - index * _stagger;
    return (elapsed / _flight).clamp(0.0, 1.0);
  }

  /// Un colpetto ogni volta che una carta tocca il panno.
  /// Quanti meme sono già usciti durante la distribuzione: un paio basta.
  int _memes = 0;

  void _tap() {
    var landed = 0;
    for (var i = 0; i < widget.names.length; i++) {
      if (_progress(i) >= 1) landed++;
    }
    if (landed > _landed) {
      HapticFeedback.lightImpact();
      SoundStage.instance.cue(Cue.deal);
      if (_memes < 2) {
        final meme = now(0.25);
        if (meme != null) {
          _memes++;
          SoundStage.instance.meme(meme);
        }
      }
    }
    _landed = landed;
  }

  @override
  void dispose() {
    _deal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.names.length;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final seat = (size.shortestSide * (count > 8 ? 0.14 : 0.18)).clamp(34.0, 62.0);
        final center = size.center(Offset.zero);
        final table = Rect.fromLTRB(seat * 0.62, seat * 0.62, size.width - seat * 0.62, size.height - seat * 0.62);

        Offset seatAt(int index) {
          final angle = -pi / 2 + index * 2 * pi / count;
          return center +
              Offset(cos(angle) * (size.width - seat) / 2, sin(angle) * (size.height - seat) / 2);
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(child: CustomPaint(painter: _TablePainter(table))),
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _deal,
                builder: (context, _) => CustomPaint(
                  painter: _CardsPainter(
                    center: center,
                    targets: [for (var i = 0; i < count; i++) Offset.lerp(center, seatAt(i), 0.60)!],
                    progress: [for (var i = 0; i < count; i++) _progress(i)],
                    shuffle: (_deal.value * _total / _shuffle).clamp(0.0, 1.0),
                    cardWidth: size.shortestSide * (count > 8 ? 0.085 : 0.105),
                  ),
                ),
              ),
            ),
            for (var i = 0; i < count; i++)
              Positioned(
                left: seatAt(i).dx - seat / 2,
                top: seatAt(i).dy - seat / 2,
                child: NoirAvatar(seed: widget.names[i], size: seat),
              ),
          ],
        );
      },
    );
  }
}

/// Il legno e il panno del tavolo da poker: lo stesso nella sala delle carte
/// e intorno al quale si sceglie in partita.
abstract final class PokerFelt {
  static const wood = [Color(0xFF7A4A24), Color(0xFF3F2412), Color(0xFF5C3519)];
  static const felt = [Color(0xFF2F8059), Color(0xFF1B5239), Color(0xFF0D2C1F)];
}

class _TablePainter extends CustomPainter {
  final Rect table;

  _TablePainter(this.table);

  @override
  void paint(Canvas canvas, Size size) {
    final rim = table.shortestSide * 0.06;
    canvas.drawOval(
      table.inflate(rim).shift(Offset(0, rim * 0.9)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.6)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, rim * 1.2),
    );
    canvas.drawOval(
      table.inflate(rim),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: PokerFelt.wood,
        ).createShader(table.inflate(rim)),
    );
    canvas.drawOval(
      table,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -0.25),
          radius: 0.9,
          colors: PokerFelt.felt,
          stops: [0, 0.6, 1],
        ).createShader(table),
    );
    canvas.drawOval(
      table.deflate(rim * 0.9),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = AppColors.gold.withValues(alpha: 0.35),
    );
  }

  @override
  bool shouldRepaint(_TablePainter old) => old.table != table;
}

class _CardsPainter extends CustomPainter {
  final Offset center;
  final List<Offset> targets;
  final List<double> progress;
  final double shuffle;
  final double cardWidth;

  _CardsPainter({
    required this.center,
    required this.targets,
    required this.progress,
    required this.shuffle,
    required this.cardWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Prima le carte già sul tavolo, poi il mazzo, poi quelle in volo sopra tutto.
    for (var i = 0; i < targets.length; i++) {
      if (progress[i] >= 1) _card(canvas, targets[i], _facing(i), 1);
    }

    final left = progress.where((p) => p <= 0).length;
    final riffle = sin(shuffle * pi * 4) * (1 - shuffle) * cardWidth * 0.9;
    for (var layer = 0; layer < min(left, 7); layer++) {
      final half = layer.isEven ? riffle : -riffle;
      _card(canvas, center + Offset(half - layer * 0.7, -layer * 1.1), 0, 1);
    }

    for (var i = 0; i < targets.length; i++) {
      final p = progress[i];
      if (p <= 0 || p >= 1) continue;
      final eased = Curves.easeOutCubic.transform(p);
      final position = Offset.lerp(center, targets[i], eased)!;
      // In volo la carta fa un giro su se stessa e arriva rivolta al suo giocatore.
      _card(canvas, position, _facing(i) + (1 - eased) * 2 * pi, 1 + 0.35 * sin(pi * p));
    }
  }

  double _facing(int index) {
    final toSeat = targets[index] - center;
    return atan2(toSeat.dy, toSeat.dx) + pi / 2;
  }

  void _card(Canvas canvas, Offset position, double rotation, double scale) {
    final width = cardWidth * scale;
    final card = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: width, height: width * 1.4),
      Radius.circular(width * 0.14),
    );
    canvas.save();
    canvas.translate(position.dx, position.dy);
    canvas.rotate(rotation);
    canvas.drawRRect(
      card.shift(Offset(0, 2 + (scale - 1) * 26)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.45)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 + (scale - 1) * 18),
    );
    canvas.drawRRect(card, Paint()..color = const Color(0xFF6E161E));
    canvas.drawRRect(
      card.deflate(width * 0.09),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width * 0.045
        ..color = AppColors.gold,
    );
    canvas.drawPath(
      Path()
        ..moveTo(0, -width * 0.26)
        ..lineTo(width * 0.17, 0)
        ..lineTo(0, width * 0.26)
        ..lineTo(-width * 0.17, 0)
        ..close(),
      Paint()..color = AppColors.gold.withValues(alpha: 0.85),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CardsPainter old) => true;
}
