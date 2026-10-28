// Concept 2, "La vetrina": whole looks on mannequins along the shop window.
// One swipe brings the next mannequin into the lamp; the one in the middle
// is the player dressed head to toe, its pieces listed under it, one Buy
// for the full look (cheaper than piece by piece). Departments are words
// at the top, not buttons.
import 'package:flutter/material.dart';
import 'package:oberta/online/shop_models.dart';
import 'package:oberta/ui/screens/shop/shop_screen.dart' show rarityColor;
import 'package:oberta/ui/theme/app_theme.dart';

import '../demo_avatar/demo_cast.dart';
import 'kit.dart';

class Look {
  final String name;
  final ShopRarity rarity;
  final List<Piece> parts;
  final int price;
  const Look(this.name, this.rarity, this.parts, this.price);

  DemoChar on(DemoChar c) => parts.fold(c, (c, p) => p.apply(c));
  int get full => parts.fold(0, (s, p) => s + (p.owned ? 0 : p.price));
}

Piece _p(String name) => pieces.firstWhere((p) => p.name == name);

final looks = [
  Look('Il Gentiluomo', ShopRarity.raro, [_p('Panama crema'), _p('Monocolo d\'oro'), _p('Tweed marrone'), _p('Garofano rosso')], 1650),
  Look('Il Dottore', ShopRarity.epico, [_p('Bombetta nera'), _p('Occhiali tondi'), _p('Smoking bianco'), _p('Sigaro cubano')], 2400),
  Look('Il Boss d\'oro', ShopRarity.leggendario, [_p('Corona del Boss'), _p('Statua d\'oro'), _p('Sigaro cubano')], 3600),
];

class VetrinaConcept extends StatefulWidget {
  const VetrinaConcept({super.key});

  @override
  State<VetrinaConcept> createState() => _VetrinaConceptState();
}

class _VetrinaConceptState extends State<VetrinaConcept> {
  var _at = 1;
  var _dept = 0;
  static const _depts = ['Completi', 'Cappelli', 'Abiti', 'Volto', 'Vizi', 'Pelli'];

  @override
  Widget build(BuildContext context) => BottegaStage(
    builder: (context, layout) {
      final w = layout.size.width;
      final top = layout.neon.bottom + 6;
      final look = looks[_at];
      final bottom = layout.size.height - layout.safe.bottom;
      const big = 350.0;
      const small = 220.0;
      final bigTop = top + 52;
      final plinth = bigTop + big - 26;
      Widget mannequin(int i, double size, double cx, double y, {bool dim = false}) => Positioned(
        left: cx - size / 2,
        top: y,
        child: GestureDetector(
          onTap: () => setState(() => _at = i),
          child: Opacity(
            opacity: dim ? 0.8 : 1,
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(dim ? const Color(0x8C140E1C) : const Color(0x00000000), BlendMode.srcATop),
              child: HeroBust(look: looks[i].on(player), size: size, glow: !dim),
            ),
          ),
        ),
      );
      return Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: top,
            height: 40,
            child: DecoratedBox(
              decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0x00000000), Color(0xB3000000), Color(0xB3000000), Color(0x00000000)], stops: [0, 0.1, 0.9, 1])),
              child: _deptRow(),
            ),
          ),
          // The window glass: a faint reflection band across the mannequins.
          Positioned(left: 0, right: 0, top: top + 44, height: big + 40, child: const CustomPaint(painter: _GlassPainter())),
          mannequin(0, small, 34, plinth - small + 30, dim: true),
          mannequin(2, small, w - 34, plinth - small + 30, dim: true),
          Positioned(left: -36, top: plinth + 12, width: 140, height: 36, child: const _Plinth(dim: true)),
          Positioned(left: w - 104, top: plinth + 12, width: 140, height: 36, child: const _Plinth(dim: true)),
          mannequin(_at, big, w / 2, bigTop),
          Positioned(left: w / 2 - 120, top: plinth, width: 240, height: 52, child: _Plinth(rarity: look.rarity)),
          Positioned(
            left: 16,
            right: 16,
            top: plinth + 58,
            bottom: layout.size.height - bottom + 8,
            child: Column(
              children: [
                _dots(),
                const SizedBox(height: 6),
                Text(look.name, style: const TextStyle(fontFamily: 'Georgia', fontStyle: FontStyle.italic, color: cream, fontSize: 28, height: 1.1)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final p in look.parts)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: _PartChip(piece: p),
                      ),
                  ],
                ),
                const Spacer(),
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${look.full}',
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 13, decoration: TextDecoration.lineThrough, decorationColor: AppColors.textSecondary)),
                        Text('−${100 - look.price * 100 ~/ look.full}%', style: const TextStyle(color: Color(0xFF7FD39A), fontSize: 15, fontWeight: FontWeight.w900)),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: BuyButton(label: 'COMPRA TUTTO', price: look.price, height: 54, expand: true)),
                  ],
                ),
              ],
            ),
          ),
        ],
      );
    },
  );

  Widget _deptRow() => ListView.separated(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    itemCount: _depts.length,
    separatorBuilder: (_, _) => const SizedBox(width: 20),
    itemBuilder: (context, i) {
      final on = i == _dept;
      return GestureDetector(
        onTap: () => setState(() => _dept = i),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _depts[i].toUpperCase(),
              style: TextStyle(
                color: on ? cream : AppColors.textSecondary.withValues(alpha: 0.8),
                fontSize: 12.5,
                fontWeight: on ? FontWeight.w900 : FontWeight.w700,
                letterSpacing: 1.8,
                shadows: const [Shadow(color: Colors.black, blurRadius: 6)],
              ),
            ),
            const SizedBox(height: 5),
            Container(width: on ? 26 : 0, height: 2.5, decoration: BoxDecoration(color: brass, borderRadius: BorderRadius.circular(2))),
          ],
        ),
      );
    },
  );

  Widget _dots() => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      for (var i = 0; i < 6; i++)
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: i == _at ? 16 : 6,
          height: 6,
          decoration: BoxDecoration(color: i == _at ? brass : const Color(0xFF4A3A2A), borderRadius: BorderRadius.circular(3)),
        ),
    ],
  );
}

class _PartChip extends StatelessWidget {
  final Piece piece;
  const _PartChip({required this.piece});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        width: 56,
        height: 56,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: rarityColor(piece.rarity).withValues(alpha: 0.85),
          boxShadow: const [BoxShadow(color: Color(0xAA000000), blurRadius: 6, offset: Offset(0, 3))],
        ),
        child: PieceThumb(piece: piece, base: player, radius: 8),
      ),
      const SizedBox(height: 4),
      SizedBox(
        width: 70,
        child: Text(piece.name,
            textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10.5)),
      ),
    ],
  );
}

/// The mannequin's stand: dark wood, a brass edge, the class on a plate.
class _Plinth extends StatelessWidget {
  final ShopRarity? rarity;
  final bool dim;
  const _Plinth({this.rarity, this.dim = false});

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: dim ? 0.5 : 1,
    child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF5A3A22), Color(0xFF2A1A0E)]),
        border: const Border(top: BorderSide(color: brass, width: 2)),
        boxShadow: const [BoxShadow(color: Color(0xCC000000), blurRadius: 12, offset: Offset(0, 6))],
      ),
      alignment: Alignment.center,
      child: rarity == null
          ? null
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: ink,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: rarityColor(rarity!), width: 1.4),
              ),
              child: Text(rarityLabel(rarity!), style: TextStyle(color: rarityColor(rarity!), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 2.4)),
            ),
    ),
  );
}

class _GlassPainter extends CustomPainter {
  const _GlassPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final band = Path()
      ..moveTo(size.width * 0.62, 0)
      ..lineTo(size.width * 0.78, 0)
      ..lineTo(size.width * 0.46, size.height)
      ..lineTo(size.width * 0.38, size.height)
      ..close();
    canvas.drawPath(band, Paint()..color = const Color(0x0DFFFFFF));
    final thin = Path()
      ..moveTo(size.width * 0.82, 0)
      ..lineTo(size.width * 0.85, 0)
      ..lineTo(size.width * 0.55, size.height)
      ..lineTo(size.width * 0.53, size.height)
      ..close();
    canvas.drawPath(thin, Paint()..color = const Color(0x0AFFFFFF));
  }

  @override
  bool shouldRepaint(_GlassPainter old) => false;
}
