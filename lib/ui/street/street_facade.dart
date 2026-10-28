import 'dart:math';

import 'package:flutter/material.dart';

import 'street_section.dart';
import 'street_stage.dart';

/// Le misure di un tratto di strada davanti a un locale: l'insegna, la
/// facciata con la vetrina e la porta, il marciapiede, e il riquadro dove
/// compaiono i pannelli una volta entrati.
class StreetFacadeLayout {
  final Size size;
  final EdgeInsets safe;
  final bool desk;

  late final Rect neon;
  late final double ground;
  late final double curb;
  late final Rect door;
  late final Rect window;
  late final Rect awning;

  /// Dove stanno i pannelli della sezione.
  late final Rect panel;

  StreetFacadeLayout(this.size, this.safe, {this.desk = false}) {
    final w = size.width;
    final h = size.height;
    final street = desk ? 120.0 : (h * 0.10).clamp(60.0, 96.0);
    ground = h - safe.bottom - street;
    curb = ground + street * 0.34;
    if (desk) {
      neon = Rect.fromCenter(center: Offset(w / 2, 46), width: 640, height: 84);
    } else {
      final tall = (h * 0.082).clamp(44.0, 70.0);
      neon = Rect.fromLTRB(62, safe.top + 4, w - 62, safe.top + 4 + tall);
    }
    final top = neon.bottom + (desk ? 40 : 8);
    final room = ground - top;
    final doorH = min(room * 0.66, desk ? 560.0 : w * 0.62);
    final doorW = doorH * 0.46;
    final cx = w * (desk ? 0.62 : 0.68);
    door = Rect.fromLTWH(cx - doorW / 2, ground - doorH, doorW, doorH);
    window = Rect.fromLTRB(w * (desk ? 0.30 : 0.07), door.top + doorH * 0.10, door.left - w * (desk ? 0.03 : 0.07), ground - doorH * 0.17);
    awning = Rect.fromLTRB(window.left - doorW * 0.18, door.top - doorH * 0.22, door.right + doorW * 0.18, door.top - doorH * 0.07);
    panel = desk
        ? Rect.fromLTRB(0, 0, w, h)
        : Rect.fromLTRB(10, neon.bottom + 6, w - 10, h - max(safe.bottom, 8.0) - 2);
  }

  /// L'uomo sulla soglia: i piedi in mezzo alla porta, alto quasi quanto lei.
  StreetSpot get spot => StreetSpot(door.bottomCenter.translate(0, (curb - ground) * 0.25), door.height * 0.80, door: door);

  @override
  bool operator ==(Object other) =>
      other is StreetFacadeLayout && other.size == size && other.safe == safe && other.desk == desk;

  @override
  int get hashCode => Object.hash(size, safe, desk);
}

/// Le parti della facciata che [StreetFacadePainter] sa disegnare da sole.
enum StreetFacadePart {
  /// I mattoni, con la malta.
  wall,

  /// Tutto quello che sta sopra i mattoni: la vetrina, la porta, la tenda,
  /// il marciapiede.
  front,

  /// La facciata intera.
  all,
}

/// La facciata di un locale: i mattoni, la vetrina con quello che c'è
/// dentro, la porta (che si apre quando l'uomo entra o esce), la tenda, il
/// palo del barbiere, il marciapiede bagnato.
class StreetFacadePainter extends CustomPainter {
  final StreetFacadeLayout layout;
  final StreetSection section;

  /// Quanto è aperta la porta, da 0 a 1.
  final double open;

  /// Che parte disegnare: solo il muro di mattoni (fermo, si può tenere da
  /// parte in un'immagine), tutto il resto sopra il muro, o tutto insieme.
  final StreetFacadePart part;

  StreetFacadePainter({required this.layout, required this.section, required this.open, this.part = StreetFacadePart.all});

  /// Solo il muro: la porta non conta.
  StreetFacadePainter.wall({required this.layout, required this.section})
      : open = 0,
        part = StreetFacadePart.wall;

  static const _mortar = Color(0xFF07070B);
  static const _ink = Color(0xFF050506);

  StreetFront get _front => section.front;

  Color _shade(Color c, double k) => Color.lerp(Colors.black, c, k)!;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (part != StreetFacadePart.front) {
      canvas.drawRect(Offset.zero & size, Paint()..color = _mortar);
      _bricks(canvas, w);
    }
    if (part == StreetFacadePart.wall) return;
    _front_(canvas);
    _window(canvas);
    _door(canvas, open.clamp(0.0, 1.0));
    _awning(canvas);
    _props(canvas);
    _pavement(canvas, w, h);

    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -0.2),
          radius: 1.2,
          colors: [Color(0x00000000), Color(0x00000000), Color(0xA0000000)],
          stops: [0, 0.5, 1],
        ).createShader(rect),
    );
  }

  void _bricks(Canvas canvas, double w) {
    final rng = Random(section.index * 7 + 3);
    final course = (layout.size.height * 0.024).clamp(9.0, 24.0);
    final length = course * 2.55;
    final paint = Paint();
    final glow = layout.neon.center;
    final reach = max(layout.neon.width, 120.0);
    for (var row = 0, y = layout.ground - course; y > -course; row++, y -= course) {
      final shift = row.isOdd ? length / 2 : 0.0;
      for (var x = -shift; x < w; x += length) {
        final tone = rng.nextDouble();
        final center = Offset(x + length / 2, y + course / 2);
        final d = (center - glow).distance / reach;
        final lit = 1 / (1 + d * d * 2.2);
        final base = Color.fromARGB(255, (52 + 22 * tone).round(), (30 + 10 * tone).round(), (34 + 8 * tone).round());
        paint.color = Color.lerp(_shade(base, 0.55 + 0.25 * tone), section.neon, 0.38 * lit)!;
        canvas.drawRect(Rect.fromLTWH(x + 0.8, y + 0.8, length - 1.6, course - 1.6), paint);
      }
    }
  }

  Color get _wood => switch (_front) {
        StreetFront.shop => const Color(0xFF1C2A20),
        StreetFront.barber => const Color(0xFF3A3C42),
        StreetFront.club => const Color(0xFF2E0A12),
        StreetFront.cafe => const Color(0xFF2C1A10),
        StreetFront.office => const Color(0xFF24272D),
      };

  /// Il legno (o la pietra) che incornicia vetrina e porta.
  void _front_(Canvas canvas) {
    final frame = Rect.fromLTRB(layout.awning.left + 2, layout.awning.bottom - 2, layout.awning.right - 2, layout.ground);
    canvas.drawRect(frame.shift(const Offset(3, 4)), Paint()..color = Colors.black.withValues(alpha: 0.5));
    canvas.drawRect(frame, Paint()..color = _wood);
    canvas.drawRect(Rect.fromLTWH(frame.left, frame.top, frame.width, 1.2), Paint()..color = Colors.white.withValues(alpha: 0.10));
    // Lo zoccolo sotto la vetrina.
    final kick = Rect.fromLTRB(layout.window.left, layout.window.bottom + 6, layout.window.right, layout.ground - 4);
    canvas.drawRect(kick, Paint()..color = _shade(_wood, 0.6));
    if (_front == StreetFront.club) {
      // Il retrobottega non ha vetrina: velluto imbottito a rombi.
      final pad = layout.window;
      canvas.drawRect(pad, Paint()..color = const Color(0xFF4A0E1A));
      final line = Paint()
        ..color = Colors.black.withValues(alpha: 0.45)
        ..strokeWidth = 1.2;
      final step = pad.height / 4;
      canvas.save();
      canvas.clipRect(pad);
      for (var x = pad.left - pad.height; x < pad.right + pad.height; x += step) {
        canvas.drawLine(Offset(x, pad.top), Offset(x + pad.height, pad.bottom), line);
        canvas.drawLine(Offset(x + pad.height, pad.top), Offset(x, pad.bottom), line);
      }
      canvas.restore();
    }
  }

  void _window(Canvas canvas) {
    if (_front == StreetFront.club) return;
    final glass = layout.window;
    final warm = switch (_front) {
      StreetFront.office => const Color(0xFF9FB4C8),
      StreetFront.barber => const Color(0xFFE8F2F6),
      _ => const Color(0xFFFFC870),
    };
    canvas.drawRect(
      glass,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, 0.3),
          radius: 0.9,
          colors: [warm.withValues(alpha: 0.75), _shade(warm, 0.22)],
        ).createShader(glass),
    );
    canvas.save();
    canvas.clipRect(glass);
    final ink = Paint()..color = _ink.withValues(alpha: 0.92);
    final u = glass.height;
    switch (_front) {
      case StreetFront.shop:
        // I cappelli sui loro supporti, in fila.
        for (var i = 0; i < 3; i++) {
          final x = glass.left + glass.width * (0.2 + 0.3 * i);
          final y = glass.bottom - u * (0.28 + 0.08 * (i % 2));
          canvas.drawRect(Rect.fromLTRB(x - 1.5, y, x + 1.5, glass.bottom), ink);
          canvas.drawRect(Rect.fromCenter(center: Offset(x, glass.bottom - 2), width: u * 0.18, height: 4), ink);
          canvas.drawOval(Rect.fromCenter(center: Offset(x, y), width: u * 0.36, height: u * 0.06), ink);
          canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTRB(x - u * 0.10, y - u * 0.13, x + u * 0.10, y), Radius.circular(u * 0.04)),
            ink,
          );
        }
      case StreetFront.barber:
        // La poltrona e lo specchio.
        final mirror = Rect.fromCenter(center: Offset(glass.center.dx, glass.top + u * 0.32), width: u * 0.34, height: u * 0.42);
        canvas.drawOval(mirror, Paint()..color = const Color(0xFF6E8A96));
        canvas.drawOval(mirror, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = _ink);
        final cx = glass.center.dx;
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(cx - u * 0.16, glass.bottom - u * 0.46, cx + u * 0.16, glass.bottom - u * 0.30), const Radius.circular(4)), ink);
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(cx - u * 0.13, glass.bottom - u * 0.70, cx + u * 0.13, glass.bottom - u * 0.44), const Radius.circular(6)), ink);
        canvas.drawRect(Rect.fromLTRB(cx - 3, glass.bottom - u * 0.30, cx + 3, glass.bottom), ink);
        canvas.drawRect(Rect.fromCenter(center: Offset(cx, glass.bottom - 3), width: u * 0.3, height: 6), ink);
      case StreetFront.cafe:
        // Le bottiglie sulla mensola, i tavolini tondi.
        final shelf = glass.top + u * 0.34;
        canvas.drawRect(Rect.fromLTRB(glass.left, shelf, glass.right, shelf + 3), ink);
        for (var x = glass.left + 10.0, i = 0; x < glass.right - 6; x += u * 0.09, i++) {
          final tall = u * (0.14 + 0.05 * (i % 3));
          canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(x, shelf - tall, x + u * 0.05, shelf), Radius.circular(u * 0.02)), ink);
        }
        for (final f in [0.28, 0.72]) {
          final x = glass.left + glass.width * f;
          canvas.drawOval(Rect.fromCenter(center: Offset(x, glass.bottom - u * 0.26), width: u * 0.30, height: u * 0.05), ink);
          canvas.drawRect(Rect.fromLTRB(x - 2, glass.bottom - u * 0.26, x + 2, glass.bottom), ink);
        }
      case StreetFront.office:
        // Le veneziane, e la lampada sulla scrivania.
        final slat = Paint()
          ..color = _ink.withValues(alpha: 0.55)
          ..strokeWidth = max(1.5, u * 0.02);
        for (var y = glass.top + 4; y < glass.bottom; y += u * 0.07) {
          canvas.drawLine(Offset(glass.left, y), Offset(glass.right, y), slat);
        }
        final x = glass.left + glass.width * 0.3;
        canvas.drawPath(
          Path()
            ..moveTo(x - u * 0.12, glass.bottom - u * 0.42)
            ..lineTo(x + u * 0.12, glass.bottom - u * 0.42)
            ..lineTo(x + u * 0.05, glass.bottom - u * 0.54)
            ..lineTo(x - u * 0.05, glass.bottom - u * 0.54)
            ..close(),
          ink,
        );
        canvas.drawRect(Rect.fromLTRB(x - 2, glass.bottom - u * 0.42, x + 2, glass.bottom - u * 0.16), ink);
        canvas.drawRect(Rect.fromLTRB(glass.left, glass.bottom - u * 0.16, glass.right, glass.bottom - u * 0.12), ink);
      case StreetFront.club:
        break;
    }
    // Un riflesso storto sul vetro.
    canvas.drawPath(
      Path()
        ..moveTo(glass.left + glass.width * 0.55, glass.top)
        ..lineTo(glass.left + glass.width * 0.70, glass.top)
        ..lineTo(glass.left + glass.width * 0.35, glass.bottom)
        ..lineTo(glass.left + glass.width * 0.20, glass.bottom)
        ..close(),
      Paint()..color = Colors.white.withValues(alpha: 0.07),
    );
    canvas.restore();
    canvas.drawRect(
      glass,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(3.0, u * 0.03)
        ..color = _shade(_wood, 0.5),
    );
  }

  /// La porta: il vano buio con la luce dentro, il battente che ruota sui
  /// cardini a sinistra.
  void _door(Canvas canvas, double open) {
    final door = layout.door;
    final frame = door.inflate(door.width * 0.07);
    canvas.drawRect(Rect.fromLTRB(frame.left, frame.top, frame.right, door.bottom), Paint()..color = _shade(_wood, 0.45));
    // Dentro: una luce calda che si accende quando la porta si apre.
    final inside = Color.lerp(const Color(0xFF0C0806), section.front == StreetFront.office ? const Color(0xFF9FB4C8) : const Color(0xFFFFB45A), 0.15 + 0.6 * open)!;
    canvas.drawRect(
      door,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_shade(inside, 0.55), inside],
        ).createShader(door),
    );
    // Il battente: si stringe verso il cardine, come visto di fronte.
    final leafW = door.width * (1 - 0.82 * Curves.easeInOut.transform(open));
    final leaf = Rect.fromLTWH(door.left, door.top, leafW, door.height);
    final leafColor = switch (_front) {
      StreetFront.club => const Color(0xFF6A1222),
      StreetFront.barber => const Color(0xFF2E4A5A),
      StreetFront.office => const Color(0xFF3A3328),
      _ => _shade(_wood, 1.25),
    };
    canvas.drawRect(leaf, Paint()..color = Color.lerp(leafColor, Colors.black, 0.35 * open)!);
    if (leafW > 6) {
      final inset = leaf.deflate(max(3.0, leaf.width * 0.12));
      switch (_front) {
        case StreetFront.club:
          // Le borchie d'ottone sull'imbottitura, e lo spioncino.
          final stud = Paint()..color = const Color(0xFFC9A227);
          for (var r = 0; r < 6; r++) {
            for (var c = 0; c < 3; c++) {
              canvas.drawCircle(Offset(inset.left + inset.width * (c + 0.5) / 3, inset.top + inset.height * (r + 0.5) / 6), max(1.2, door.width * 0.018), stud);
            }
          }
          canvas.drawRect(Rect.fromCenter(center: Offset(leaf.center.dx, leaf.top + leaf.height * 0.2), width: leaf.width * 0.36, height: leaf.height * 0.035), Paint()..color = _ink);
        case StreetFront.office:
          final frosted = Rect.fromLTRB(inset.left, inset.top, inset.right, inset.top + inset.height * 0.45);
          canvas.drawRect(frosted, Paint()..color = const Color(0xFFB7C2C8).withValues(alpha: 0.8));
          canvas.drawRect(Rect.fromLTRB(inset.left, frosted.bottom + 6, inset.right, inset.bottom), Paint()..color = Colors.black.withValues(alpha: 0.25));
        default:
          final glassTop = Rect.fromLTRB(inset.left, inset.top, inset.right, inset.top + inset.height * 0.5);
          canvas.drawRect(glassTop, Paint()..color = const Color(0xFFFFC870).withValues(alpha: 0.55 * (1 - open)));
          canvas.drawRect(Rect.fromLTRB(inset.left, glassTop.bottom + 6, inset.right, inset.bottom), Paint()..color = Colors.black.withValues(alpha: 0.25));
      }
      canvas.drawCircle(Offset(leaf.right - leaf.width * 0.14, leaf.center.dy + door.height * 0.04), max(1.5, door.width * 0.04), Paint()..color = const Color(0xFFC9A227));
    }
    // La luce che esce dalla porta e cade sul marciapiede.
    if (open > 0.02) {
      final spill = Rect.fromLTRB(door.left - door.width * 0.4, layout.ground, door.right + door.width * 0.4, layout.curb + 6);
      canvas.drawOval(
        spill,
        Paint()
          ..shader = RadialGradient(
            colors: [inside.withValues(alpha: 0.45 * open), inside.withValues(alpha: 0)],
          ).createShader(spill),
      );
    }
  }

  void _awning(Canvas canvas) {
    final a = layout.awning;
    final (Color one, Color two)? stripes = switch (_front) {
      StreetFront.shop => (const Color(0xFF7A1E22), const Color(0xFFB8902A)),
      StreetFront.cafe => (const Color(0xFF1C2E5A), const Color(0xFFCFC4A8)),
      StreetFront.barber => (const Color(0xFF8E1E24), const Color(0xFFD8D4CC)),
      _ => null,
    };
    if (stripes == null) {
      // Il retrobottega ha le lampadine intorno alla porta; l'ufficio la targa d'ottone.
      if (_front == StreetFront.club) {
        final d = layout.door.inflate(layout.door.width * 0.16);
        final bulb = Paint()..color = const Color(0xFFFFE6A8);
        final halo = Paint()
          ..color = const Color(0xFFFFC870).withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
        final n = 7;
        for (var i = 0; i <= n; i++) {
          for (final p in [Offset(d.left, d.bottom - d.height * i / n), Offset(d.right, d.bottom - d.height * i / n), Offset(d.left + d.width * i / n, d.top)]) {
            canvas.drawCircle(p, max(2.5, d.width * 0.04), halo);
            canvas.drawCircle(p, max(1.4, d.width * 0.022), bulb);
          }
        }
      } else {
        final plate = Rect.fromLTWH(layout.door.right + layout.door.width * 0.16, layout.door.top + layout.door.height * 0.25, layout.door.width * 0.42, layout.door.width * 0.30);
        canvas.drawRRect(RRect.fromRectAndRadius(plate, const Radius.circular(3)), Paint()..color = const Color(0xFFB8902A));
        canvas.drawRRect(
          RRect.fromRectAndRadius(plate.deflate(2.5), const Radius.circular(2)),
          Paint()
            ..style = PaintingStyle.stroke
            ..color = const Color(0xFF5A4510),
        );
        for (var i = 0; i < 3; i++) {
          final y = plate.top + plate.height * (0.32 + 0.18 * i);
          canvas.drawLine(Offset(plate.left + plate.width * 0.2, y), Offset(plate.right - plate.width * 0.2, y), Paint()
            ..color = const Color(0xFF5A4510)
            ..strokeWidth = 1.2);
        }
      }
      return;
    }
    final (one, two) = stripes;
    final n = max(6, (a.width / 22).round());
    final step = a.width / n;
    for (var i = 0; i < n; i++) {
      final x = a.left + step * i;
      final c = i.isEven ? one : two;
      final path = Path()
        ..moveTo(x + step * 0.08, a.top)
        ..lineTo(x + step * 0.92, a.top)
        ..lineTo(x + step, a.bottom)
        ..arcToPoint(Offset(x, a.bottom), radius: Radius.circular(step / 2))
        ..close();
      canvas.drawPath(path, Paint()..color = _shade(c, 0.62));
    }
    canvas.drawRect(Rect.fromLTRB(a.left, a.top - 3, a.right, a.top + 1), Paint()..color = _ink);
  }

  void _props(Canvas canvas) {
    if (_front != StreetFront.barber) return;
    // Il palo del barbiere accanto alla porta: le strisce girano con la porta.
    final d = layout.door;
    final pole = Rect.fromLTWH(d.right + d.width * 0.22, d.top + d.height * 0.10, d.width * 0.18, d.height * 0.46);
    canvas.drawRRect(RRect.fromRectAndRadius(pole.inflate(3), Radius.circular(pole.width)), Paint()..color = const Color(0xFF1A1A1E));
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(pole, Radius.circular(pole.width / 2)));
    canvas.drawRect(pole, Paint()..color = const Color(0xFFEDE8E0));
    final spin = open * pole.width * 2;
    final band = pole.width * 0.7;
    for (var y = pole.top - pole.width * 2 + spin % (band * 2); y < pole.bottom + pole.width; y += band * 2) {
      canvas.drawPath(
        Path()
          ..moveTo(pole.left, y)
          ..lineTo(pole.right, y - pole.width * 0.8)
          ..lineTo(pole.right, y - pole.width * 0.8 + band * 0.6)
          ..lineTo(pole.left, y + band * 0.6)
          ..close(),
        Paint()..color = (y ~/ band).isEven ? const Color(0xFFC0242C) : const Color(0xFF2A5CB8),
      );
    }
    canvas.drawRect(Rect.fromLTWH(pole.left, pole.top, pole.width * 0.3, pole.height), Paint()..color = Colors.white.withValues(alpha: 0.25));
    canvas.restore();
    for (final y in [pole.top - 5, pole.bottom + 5]) {
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(pole.center.dx, y), width: pole.width * 1.4, height: 8), const Radius.circular(3)), Paint()..color = const Color(0xFFB8902A));
    }
  }

  void _pavement(Canvas canvas, double w, double h) {
    final depth = layout.curb - layout.ground;
    final slab = max(40.0, layout.door.height * 0.36);
    final paint = Paint();
    for (var x = -slab * 0.4; x < w; x += slab) {
      paint.color = const Color(0xFF2A2B31);
      canvas.drawRect(Rect.fromLTWH(x + 0.8, layout.ground, slab - 1.6, depth * 0.78), paint);
      paint.color = const Color(0xFF17181C);
      canvas.drawRect(Rect.fromLTWH(x + 0.8, layout.ground + depth * 0.78, slab - 1.6, depth * 0.22), paint);
    }
    canvas.drawRect(Rect.fromLTWH(0, layout.ground, w, 1.2), Paint()..color = Colors.white.withValues(alpha: 0.10));
    final asphalt = Rect.fromLTRB(0, layout.curb, w, h);
    canvas.drawRect(
      asphalt,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0E1016), Color(0xFF030304)],
        ).createShader(asphalt),
    );
    // Il riflesso dell'insegna sull'asfalto bagnato.
    final shine = Rect.fromCenter(center: Offset(layout.neon.center.dx, layout.curb + (h - layout.curb) * 0.4), width: layout.neon.width, height: max(8.0, (h - layout.curb) * 0.5));
    canvas.drawOval(
      shine,
      Paint()
        ..shader = RadialGradient(
          colors: [section.neon.withValues(alpha: 0.22), section.neon.withValues(alpha: 0)],
        ).createShader(shine),
    );
  }

  @override
  bool shouldRepaint(StreetFacadePainter old) =>
      old.layout != layout || old.section != section || old.part != part || (part != StreetFacadePart.wall && old.open != open);
}
