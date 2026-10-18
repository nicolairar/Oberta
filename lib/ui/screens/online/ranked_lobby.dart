import 'dart:math';

import 'package:flutter/material.dart';

import '../../../online/online_services.dart';
import '../../avatar/avatar_look.dart';
import '../../theme/app_theme.dart';
import '../../widgets/deal_table.dart' show PokerFelt;
import '../../widgets/player_avatar.dart';
import 'game/noir_ui.dart';

/// Il retrobottega della classificata: la lampada che dondola, il panno
/// verde, le sedie intorno. Chi arriva entra dal buio e si siede, chi se ne
/// va si alza ed esce; le sedie vuote restano in penombra. Al centro il
/// contatore d'ottone e, a tavolo pieno, il conto alla rovescia con le
/// carte che si mescolano.
class LobbyTable extends StatefulWidget {
  final List<RoomMember> members;
  final int size;
  final String? myId;

  /// Secondi alla partenza (null: si aspetta ancora gente).
  final double? countdown;

  /// Quanto dura il conto alla rovescia, per la lancetta.
  final double countdownTotal;

  const LobbyTable({super.key, required this.members, required this.size, this.myId, this.countdown, this.countdownTotal = 10});

  @override
  State<LobbyTable> createState() => _LobbyTableState();
}

class _LobbyTableState extends State<LobbyTable> with SingleTickerProviderStateMixin {
  /// La lampada e le carte: un solo orologio per tutta la stanza.
  late final AnimationController _swing = AnimationController(vsync: this, duration: const Duration(seconds: 4));

  bool get _still => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_still) {
      _swing.stop();
    } else if (!_swing.isAnimating) {
      _swing.repeat();
    }
  }

  @override
  void dispose() {
    _swing.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bySeat = {for (final m in widget.members) m.seat: m};
    final countdown = widget.countdown;
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        final h = box.maxHeight;
        final avatar = min(54.0, min(w, h) * 0.15);
        final table = Rect.fromCenter(center: Offset(w / 2, h * 0.54), width: w * 0.6, height: h * 0.46);
        final rx = w / 2 - avatar * 0.7;
        final ry = h * 0.46 - avatar * 0.6;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _swing,
                  builder: (context, _) => CustomPaint(
                    painter: _BackRoomPainter(table: table, swing: _still ? 0 : sin(_swing.value * 2 * pi) * (countdown == null ? 0.06 : 0.16)),
                  ),
                ),
              ),
            ),
            for (var i = 0; i < widget.size; i++)
              Builder(
                builder: (context) {
                  final angle = -pi / 2 + 2 * pi * i / widget.size;
                  final x = w / 2 + cos(angle) * rx;
                  final y = table.center.dy + sin(angle) * ry;
                  return Positioned(
                    left: x - avatar * 0.8,
                    top: y - avatar * 0.62,
                    width: avatar * 1.6,
                    child: _Seat(
                      key: ValueKey('lobby-seat-$i'),
                      member: bySeat[i + 1],
                      mine: bySeat[i + 1]?.profile.id == widget.myId,
                      size: avatar,
                      away: Offset(cos(angle), sin(angle)) * (avatar * 3.2),
                      still: _still,
                    ),
                  );
                },
              ),
            Positioned.fromRect(
              rect: table,
              child: IgnorePointer(
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 450),
                    child: countdown == null
                        ? _BrassCounter(key: const ValueKey('count'), seated: widget.members.length, size: widget.size, height: table.height)
                        : _Shuffle(
                            key: const ValueKey('shuffle'),
                            seconds: countdown,
                            total: widget.countdownTotal,
                            clock: _swing,
                            still: _still,
                            height: table.height,
                          ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Una sedia: vuota in penombra, oppure qualcuno che entra, si siede, e un
/// giorno si alza ed esce.
class _Seat extends StatefulWidget {
  final RoomMember? member;
  final bool mine;
  final double size;
  final Offset away;
  final bool still;

  const _Seat({super.key, required this.member, required this.mine, required this.size, required this.away, required this.still});

  @override
  State<_Seat> createState() => _SeatState();
}

class _SeatState extends State<_Seat> with SingleTickerProviderStateMixin {
  late final AnimationController _walk = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
    value: widget.member == null ? 0 : 1,
  );

  /// Chi c'era: resta in scena mentre esce.
  RoomMember? _shown;

  @override
  void initState() {
    super.initState();
    _shown = widget.member;
  }

  @override
  void didUpdateWidget(_Seat old) {
    super.didUpdateWidget(old);
    final now = widget.member;
    if (now?.profile.id == _shown?.profile.id) {
      _shown = now ?? _shown;
      return;
    }
    if (_shown != null && now == null) {
      // Si alza ed esce.
      _walk.reverse().whenComplete(() {
        if (mounted && widget.member == null) setState(() => _shown = null);
      });
    } else {
      // Qualcuno di nuovo (anche al posto di chi è uscito): entra.
      _shown = now;
      _walk.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _walk.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final member = _shown;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size * 1.6,
          height: size * 1.05,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // La sedia, sempre al suo posto: accesa solo se occupata.
              AnimatedBuilder(
                animation: _walk,
                builder: (context, _) => CustomPaint(
                  size: Size(size * 0.9, size * 0.95),
                  painter: _ChairPainter(lit: member == null ? 0 : _walk.value),
                ),
              ),
              if (member != null)
                AnimatedBuilder(
                  animation: _walk,
                  builder: (context, child) {
                    final v = _walk.value;
                    if (widget.still) return Opacity(opacity: v, child: child);
                    // Prima cammina (dondolando), poi si siede.
                    final walk = Curves.easeOut.transform((v / 0.75).clamp(0.0, 1.0));
                    final sit = Curves.easeOutBack.transform(((v - 0.7) / 0.3).clamp(0.0, 1.0));
                    final bob = (1 - walk) * sin(v * pi * 9).abs() * size * 0.12;
                    return Opacity(
                      opacity: (v / 0.25).clamp(0.0, 1.0),
                      child: Transform.translate(
                        offset: widget.away * (1 - walk) + Offset(0, -bob - (1 - sit) * size * 0.1),
                        child: Transform.scale(scale: 0.94 + 0.06 * sit, child: child),
                      ),
                    );
                  },
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [if (widget.mine) BoxShadow(color: Saloon.brass.withValues(alpha: 0.55), blurRadius: 12)],
                    ),
                    child: PlayerAvatar(seed: member.profile.avatarSeed, look: member.profile.look, size: size),
                  ),
                ),
            ],
          ),
        ),
        AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: member == null ? 0 : 1,
          child: Container(
            margin: const EdgeInsets.only(top: 1),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: widget.mine ? const [Saloon.brass, Saloon.brassDeep] : const [Color(0xFF3A2A1C), Color(0xFF1E140C)]),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: Saloon.brassDeep, width: 0.8),
            ),
            child: Text(
              member?.profile.name ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.body.copyWith(fontSize: 9.5, fontWeight: FontWeight.w700, color: widget.mine ? Saloon.paperInk : Saloon.paper),
            ),
          ),
        ),
      ],
    );
  }
}

/// Il contatore d'ottone al centro del panno: «7/12».
class _BrassCounter extends StatelessWidget {
  final int seated;
  final int size;
  final double height;

  const _BrassCounter({super.key, required this.seated, required this.size, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('ranked.counter'),
      padding: EdgeInsets.symmetric(horizontal: height * 0.14, vertical: height * 0.04),
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
        builder: (context, value, _) => Text(softWrap: false, '${value.round()}/$size', style: AppText.display(height * 0.2, color: Saloon.paperInk)),
      ),
    );
  }
}

/// Il conto alla rovescia: le carte si mescolano sul panno, il numero
/// grande in mezzo e un anello che si chiude.
class _Shuffle extends StatelessWidget {
  final double seconds;
  final double total;
  final Animation<double> clock;
  final bool still;
  final double height;

  const _Shuffle({super.key, required this.seconds, required this.total, required this.clock, required this.still, required this.height});

  @override
  Widget build(BuildContext context) {
    final ring = height * 0.62;
    return SizedBox(
      width: ring * 1.8,
      height: ring,
      child: AnimatedBuilder(
        animation: clock,
        builder: (context, _) {
          final t = still ? 0.0 : clock.value * 4;
          return Stack(
            alignment: Alignment.center,
            children: [
              for (var i = 0; i < 5; i++)
                Transform.translate(
                  offset: Offset(sin(t * 2 * pi + i * 1.3) * ring * 0.55, cos(t * 2 * pi + i) * ring * 0.06),
                  child: Transform.rotate(
                    angle: sin(t * 2 * pi + i) * 0.35,
                    child: Container(
                      width: ring * 0.3,
                      height: ring * 0.42,
                      decoration: BoxDecoration(
                        color: Saloon.enamelDeep,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Saloon.paper, width: 1.4),
                        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2))],
                      ),
                    ),
                  ),
                ),
              CustomPaint(size: Size.square(ring), painter: _RingPainter((seconds / total).clamp(0.0, 1.0))),
              Text(
                '${seconds.ceil()}',
                key: const Key('ranked.countdown'),
                style: AppText.display(ring * 0.48, color: Saloon.paper).copyWith(shadows: const [Shadow(color: Colors.black, blurRadius: 8)]),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double left;

  _RingPainter(this.left);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawCircle(rect.center, size.width / 2, Paint()..color = Colors.black.withValues(alpha: 0.45));
    canvas.drawArc(
      rect.deflate(3),
      -pi / 2,
      2 * pi * left,
      false,
      Paint()
        ..color = Saloon.brass
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.left != left;
}

/// Una sedia di legno vista dall'alto, accesa quando c'è qualcuno.
class _ChairPainter extends CustomPainter {
  final double lit;

  _ChairPainter({required this.lit});

  @override
  void paint(Canvas canvas, Size size) {
    final wood = Color.lerp(const Color(0xFF2A1A10), Saloon.wood, lit)!.withValues(alpha: 0.55 + 0.45 * lit);
    final back = RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, size.height * 0.28), Radius.circular(size.width * 0.18));
    final seat = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.08, size.height * 0.3, size.width * 0.84, size.height * 0.66),
      Radius.circular(size.width * 0.16),
    );
    canvas.drawRRect(back, Paint()..color = wood);
    canvas.drawRRect(seat, Paint()..color = wood);
    canvas.drawRRect(
      seat.deflate(size.width * 0.1),
      Paint()..color = Color.lerp(const Color(0xFF1C130C), Saloon.enamelDeep, lit)!.withValues(alpha: 0.5 + 0.5 * lit),
    );
  }

  @override
  bool shouldRepaint(_ChairPainter old) => old.lit != lit;
}

/// La stanza: muro scuro, la luce calda della lampada che dondola, il
/// tavolo col bordo di legno e il panno verde.
class _BackRoomPainter extends CustomPainter {
  final Rect table;
  final double swing;

  _BackRoomPainter({required this.table, required this.swing});

  @override
  void paint(Canvas canvas, Size size) {
    final pivot = Offset(size.width / 2, -size.height * 0.1);
    // Appesa sopra il bordo alto del panno, sopra il contatore.
    final length = table.top + table.height * 0.06 - pivot.dy;
    final lamp = pivot + Offset(sin(swing) * length, cos(swing) * length);
    final light = table.center + Offset(sin(swing) * size.width * 0.25, 0);

    // La pozza di luce sul tavolo e intorno.
    canvas.drawCircle(
      light,
      size.longestSide * 0.6,
      Paint()
        ..shader = RadialGradient(colors: [const Color(0xFFFFC870).withValues(alpha: 0.28), const Color(0xFFFFC870).withValues(alpha: 0)])
            .createShader(Rect.fromCircle(center: light, radius: size.longestSide * 0.6)),
    );

    // Il tavolo.
    final rim = table.shortestSide * 0.08;
    canvas.drawOval(
      table.inflate(rim).shift(Offset(0, rim)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.6)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, rim * 1.2),
    );
    canvas.drawOval(table.inflate(rim), Paint()..shader = const LinearGradient(colors: PokerFelt.wood).createShader(table.inflate(rim)));
    canvas.drawOval(table, Paint()..shader = const RadialGradient(colors: PokerFelt.felt, stops: [0, 0.6, 1]).createShader(table));
    canvas.drawOval(
      table,
      Paint()
        ..shader = RadialGradient(
          center: Alignment((light.dx - table.center.dx) / (table.width / 2), -0.2),
          colors: [const Color(0xFFFFE2A0).withValues(alpha: 0.16), Colors.transparent],
        ).createShader(table),
    );

    // Il filo e la lampada.
    canvas.drawLine(
      pivot,
      lamp,
      Paint()
        ..color = const Color(0xFF14100C)
        ..strokeWidth = 1.5,
    );
    final shade = Path()
      ..moveTo(lamp.dx - 7, lamp.dy)
      ..lineTo(lamp.dx + 7, lamp.dy)
      ..lineTo(lamp.dx + 22, lamp.dy + 16)
      ..lineTo(lamp.dx - 22, lamp.dy + 16)
      ..close();
    canvas.save();
    canvas.translate(lamp.dx, lamp.dy);
    canvas.rotate(-swing);
    canvas.translate(-lamp.dx, -lamp.dy);
    canvas.drawPath(shade, Paint()..color = const Color(0xFF2E3B2C));
    canvas.drawCircle(lamp + const Offset(0, 17), 5, Paint()..color = const Color(0xFFFFE0A0));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BackRoomPainter old) => old.swing != swing || old.table != table;
}

/// Un consiglio o un ruolo, su carta: entra con un mezzo giro.
class LobbyCard extends StatelessWidget {
  final String? kicker;
  final String title;
  final String body;

  const LobbyCard({super.key, this.kicker, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: Saloon.paper,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Saloon.brassDeep, width: 1.5),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (kicker != null) Text(kicker!.toUpperCase(), style: AppText.overline.copyWith(color: Saloon.enamel, fontSize: 10)),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppText.display(17, color: Saloon.paperInk),
          ),
          const SizedBox(height: 3),
          Text(
            body,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: AppText.body.copyWith(color: Saloon.paperInk, fontSize: 12.5, height: 1.25),
          ),
        ],
      ),
    );
  }
}
