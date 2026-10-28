// Concept 3, "La ruota": the player full-bleed, as big as the phone allows,
// and a brass dial rising from the bottom edge like a safe's. The pieces
// sit on its rim; the thumb spins it and the one under the notch is worn at
// once. Departments are on the dial's face; the price tag floats over the
// chest, right above the notch.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:oberta/ui/screens/shop/shop_screen.dart' show rarityColor;
import 'package:oberta/ui/theme/app_theme.dart';

import 'kit.dart';

class RuotaConcept extends StatefulWidget {
  final Slot slot;
  final int pick;
  const RuotaConcept({super.key, this.slot = Slot.face, this.pick = 1});

  @override
  State<RuotaConcept> createState() => _RuotaConceptState();
}

class _RuotaConceptState extends State<RuotaConcept> {
  late Slot _slot = widget.slot;
  late int _pick = widget.pick;

  @override
  Widget build(BuildContext context) => BottegaStage(
    builder: (context, layout) {
      final w = layout.size.width;
      final h = layout.size.height;
      final row = piecesOf(_slot);
      final picked = row[_pick.clamp(0, row.length - 1)];
      final center = Offset(w / 2, h - layout.safe.bottom + 150);
      const disc = 392.0;
      const rim = 332.0;
      const bust = 440.0;
      final dialTop = center.dy - disc;
      final bustTop = dialTop + 46 - bust;
      const step = 17.0 * pi / 180;
      final thumbs = <Widget>[];
      for (var k = -3; k <= 3; k++) {
        final i = _pick + k;
        if (i < 0 || i >= row.length) continue;
        final a = k * step;
        final on = k == 0;
        final side = on ? 82.0 : 60.0;
        final at = center + Offset(sin(a) * rim, -cos(a) * rim);
        thumbs.add(Positioned(
          left: at.dx - side / 2,
          top: at.dy - side / 2,
          child: GestureDetector(
            onTap: () => setState(() => _pick = i),
            child: Transform.rotate(angle: a * 0.6, child: _RimThumb(piece: row[i], side: side, on: on)),
          ),
        ));
      }
      return Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(left: (w - bust) / 2, top: bustTop, child: HeroBust(look: picked.apply(player), size: bust)),
          Positioned(
            left: center.dx - disc,
            top: dialTop,
            width: disc * 2,
            height: disc * 2,
            child: const CustomPaint(painter: _DialPainter()),
          ),
          ...thumbs,
          // The notch the pieces pass under.
          Positioned(
            left: w / 2 - 12,
            top: dialTop - 6,
            child: const CustomPaint(size: Size(24, 18), painter: _NotchPainter()),
          ),
          Positioned(left: 14, right: 14, top: dialTop - 74, child: _Tag(piece: picked)),
          Positioned(left: 0, right: 0, top: center.dy - rim + 104, child: _depts()),
        ],
      );
    },
  );

  Widget _depts() => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      for (final s in Slot.values)
        GestureDetector(
          onTap: () => setState(() {
            _slot = s;
            _pick = 0;
          }),
          child: Container(
            width: 62,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: s == _slot
                ? BoxDecoration(
                    color: const Color(0x33FFB443),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: brass.withValues(alpha: 0.7)),
                  )
                : null,
            child: Column(
              children: [
                Icon(s.icon, size: 20, color: s == _slot ? brass : const Color(0xFF8E8070)),
                const SizedBox(height: 3),
                Text(s.label,
                    style: TextStyle(color: s == _slot ? cream : const Color(0xFF8E8070), fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1)),
              ],
            ),
          ),
        ),
    ],
  );
}

class _RimThumb extends StatelessWidget {
  final Piece piece;
  final double side;
  final bool on;
  const _RimThumb({required this.piece, required this.side, required this.on});

  @override
  Widget build(BuildContext context) => Container(
    width: side,
    height: side,
    padding: EdgeInsets.all(on ? 3.5 : 2.5),
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: on ? AppColors.gold : rarityColor(piece.rarity).withValues(alpha: 0.8),
      boxShadow: [
        const BoxShadow(color: Color(0xCC000000), blurRadius: 8, offset: Offset(0, 4)),
        if (on) const BoxShadow(color: Color(0x99FFB443), blurRadius: 18),
      ],
    ),
    child: ClipOval(child: PieceThumb(piece: piece, base: player, radius: 0)),
  );
}

/// The price tag over the chest: name, class, price, Buy.
class _Tag extends StatelessWidget {
  final Piece piece;
  const _Tag({required this.piece});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
    decoration: BoxDecoration(
      color: const Color(0xE60C0907),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: brassDeep.withValues(alpha: 0.8)),
      boxShadow: const [BoxShadow(color: Color(0xCC000000), blurRadius: 16, offset: Offset(0, 6))],
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(piece.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Georgia', fontStyle: FontStyle.italic, color: cream, fontSize: 19)),
              const SizedBox(height: 3),
              RarityTag(piece.rarity, brand: piece.brand),
            ],
          ),
        ),
        if (piece.worn) const BuyButton(label: 'INDOSSATO', brassy: true, height: 46) else BuyButton(price: piece.price, height: 46),
      ],
    ),
  );
}

/// The dial: a dark enamel disc with a brass rim, ticks like a safe.
class _DialPainter extends CustomPainter {
  const _DialPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    canvas.drawCircle(c.translate(0, -6), r + 4, Paint()
      ..color = const Color(0xAA000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18));
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const SweepGradient(
          colors: [Color(0xFFFFE29A), Color(0xFF8C6A14), Color(0xFFC9A227), Color(0xFF5A420C), Color(0xFFFFE29A)],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawCircle(
      c,
      r - 7,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF0C0907), Color(0xFF1E1510), Color(0xFF2A1D14)],
          stops: [0.5, 0.86, 1],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    // Ticks round the rim.
    final tick = Paint()
      ..color = const Color(0x66D9B45A)
      ..strokeWidth = 1.4;
    for (var i = 0; i < 120; i++) {
      final a = i * 2 * pi / 120;
      final long = i % 5 == 0;
      final d = Offset(sin(a), -cos(a));
      canvas.drawLine(c + d * (r - 12), c + d * (r - (long ? 22 : 16)), tick);
    }
    // The inner ring the departments sit in.
    canvas.drawCircle(c, r - 112, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0x55D9B45A));
  }

  @override
  bool shouldRepaint(_DialPainter old) => false;
}

class _NotchPainter extends CustomPainter {
  const _NotchPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(p.shift(const Offset(0, 2)), Paint()..color = const Color(0xAA000000));
    canvas.drawPath(p, Paint()..color = const Color(0xFFFFE29A));
    canvas.drawPath(p, Paint()
      ..style = PaintingStyle.stroke
      ..color = const Color(0xFF5A420C));
  }

  @override
  bool shouldRepaint(_NotchPainter old) => false;
}
