import 'dart:math';

import 'package:flutter/material.dart';

import 'street_section.dart';
import 'street_stage.dart';
import 'street_wall.dart';

/// Le misure di un tratto di strada davanti a un locale: l'insegna, la
/// facciata con la vetrina e la porta, il marciapiede, e il riquadro dove
/// compaiono i pannelli una volta entrati.
class StreetFacadeLayout {
  final Size size;
  final EdgeInsets safe;
  final bool desk;

  /// Sul telefono, quanto spazio tenere libero a destra dell'insegna (il
  /// borsellino della bottega): l'insegna si stringe e non ci finisce sotto.
  final double trailing;

  /// Il muro di tutta la strada: mattoni e marciapiede alla stessa altezza
  /// del vicolo di casa.
  late final StreetWall wall;

  late final Rect neon;
  late final double ground;
  late final double curb;
  late final Rect door;
  late final Rect window;
  late final Rect awning;

  /// Dove stanno i pannelli della sezione.
  late final Rect panel;

  StreetFacadeLayout(this.size, this.safe, {this.desk = false, this.trailing = 0}) {
    final w = size.width;
    final h = size.height;
    wall = StreetWall(size, safe);
    ground = wall.ground;
    curb = wall.curb;
    if (desk) {
      neon = Rect.fromCenter(center: Offset(w / 2, 46), width: 640, height: 84);
    } else {
      final tall = (h * 0.082).clamp(44.0, 70.0);
      neon = Rect.fromLTRB(62, safe.top + 4, w - max(62.0, trailing + 14), safe.top + 4 + tall);
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
  /// La luce dell'insegna di [section] sul muro: forte vicino ai tubi, poi
  /// sempre più tenue, fino a mescolarsi con le insegne accanto.
  List<StreetLight> lightsOf(StreetSection section) => [
    StreetSignLight(
      band: neon.deflate(neon.height * 0.2),
      reach: neon.height * 0.9,
      wash: 0.8,
      spread: size.width * 0.40,
      color: StreetLight.tint(section.neon, 0.95),
    ),
  ];

  StreetSpot get spot => StreetSpot(door.bottomCenter.translate(0, (curb - ground) * 0.25), door.height * 0.80, door: door);

  @override
  bool operator ==(Object other) =>
      other is StreetFacadeLayout && other.size == size && other.safe == safe && other.desk == desk && other.trailing == trailing;

  @override
  int get hashCode => Object.hash(size, safe, desk, trailing);
}

/// Le parti della facciata che [StreetFacadePainter] sa disegnare da sole.
enum StreetFacadePart {
  /// Tutto quello che sta sopra il muro: la vetrina, la porta, la tenda.
  /// Il muro lo dipinge [StreetWallLayer], uno solo per tutta la strada.
  front,

  /// La facciata intera, muro compreso.
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

  /// Quanto è accesa l'insegna (il suo riflesso sull'asfalto).
  final double glow;

  /// La vignettatura: mentre si cammina la mette la strada, ferma sullo schermo.
  final bool vignette;

  StreetFacadePainter({
    required this.layout,
    required this.section,
    required this.open,
    this.part = StreetFacadePart.all,
    this.glow = 1,
    this.vignette = true,
  });

  static const _ink = Color(0xFF050506);

  StreetFront get _front => section.front;

  Color _shade(Color c, double k) => Color.lerp(Colors.black, c, k)!;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (part == StreetFacadePart.all) {
      StreetWallPainter(wall: layout.wall, index: 0, lights: layout.lightsOf(section)).paint(canvas, size);
    }
    _front_(canvas);
    _window(canvas);
    _door(canvas, open.clamp(0.0, 1.0));
    _awning(canvas);
    _props(canvas);
    _shine(canvas, w, h);
    if (vignette) StreetWall.vignette(canvas, size);
  }

  Color get _wood => switch (_front) {
        StreetFront.shop => const Color(0xFF1C2A20),
        StreetFront.barber => const Color(0xFF3A3C42),
        StreetFront.club => const Color(0xFF2E0A12),
        StreetFront.cafe => const Color(0xFF2C1A10),
        StreetFront.office => const Color(0xFF24272D),
        StreetFront.hall => const Color(0xFF0F2A22),
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
      case StreetFront.hall:
        _hallWindow(canvas, glass, ink);
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
      StreetFront.hall => const Color(0xFF173F33),
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
        case StreetFront.hall:
          // Due specchiature col filo d'ottone, e la targhetta in alto.
          final brass = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = max(1.0, door.width * 0.02)
            ..color = const Color(0xFFC9A227).withValues(alpha: 0.85);
          final upper = Rect.fromLTRB(inset.left, inset.top, inset.right, inset.top + inset.height * 0.46);
          final lower = Rect.fromLTRB(inset.left, upper.bottom + inset.height * 0.06, inset.right, inset.bottom);
          for (final panel in [upper, lower]) {
            canvas.drawRect(panel, Paint()..color = Colors.black.withValues(alpha: 0.22));
            canvas.drawRect(panel, brass);
          }
          final tag = Rect.fromCenter(center: Offset(leaf.center.dx, upper.top + upper.height * 0.32), width: leaf.width * 0.5, height: door.height * 0.045);
          if (tag.width > 8) {
            canvas.drawRect(tag, Paint()..color = const Color(0xFFC9A227));
            canvas.drawLine(
              Offset(tag.left + tag.width * 0.2, tag.center.dy),
              Offset(tag.right - tag.width * 0.2, tag.center.dy),
              Paint()
                ..color = const Color(0xFF5A4510)
                ..strokeWidth = 1,
            );
          }
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
    if (_front == StreetFront.hall) return _canopy(canvas);
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
    if (_front == StreetFront.hall) return _rope(canvas);
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

  /// Dietro il vetro della sala: il tavolo verde sotto la lampada, due
  /// giocatori in controluce, la cornice dorata dipinta sul vetro.
  void _hallWindow(Canvas canvas, Rect glass, Paint ink) {
    final u = glass.height;
    final cx = glass.center.dx;
    final lamp = Offset(cx, glass.top + u * 0.30);
    canvas.drawLine(
      Offset(cx, glass.top),
      lamp,
      Paint()
        ..color = ink.color
        ..strokeWidth = max(1.2, u * 0.012),
    );
    final table = Rect.fromCenter(center: Offset(cx, glass.bottom - u * 0.30), width: glass.width * 0.62, height: u * 0.10);
    // Il cono di luce della lampada fino al panno.
    canvas.drawPath(
      Path()
        ..moveTo(lamp.dx - u * 0.07, lamp.dy)
        ..lineTo(lamp.dx + u * 0.07, lamp.dy)
        ..lineTo(table.right, table.center.dy)
        ..lineTo(table.left, table.center.dy)
        ..close(),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [const Color(0xFFFFE6A8).withValues(alpha: 0.45), const Color(0xFFFFE6A8).withValues(alpha: 0.05)],
        ).createShader(Rect.fromLTRB(table.left, lamp.dy, table.right, table.center.dy)),
    );
    canvas.drawPath(
      Path()
        ..moveTo(lamp.dx - u * 0.04, lamp.dy - u * 0.05)
        ..lineTo(lamp.dx + u * 0.04, lamp.dy - u * 0.05)
        ..lineTo(lamp.dx + u * 0.08, lamp.dy)
        ..lineTo(lamp.dx - u * 0.08, lamp.dy)
        ..close(),
      Paint()..color = const Color(0xFF1E4A38),
    );
    // I giocatori: spalle e cappello, uno per lato.
    for (final side in [-1.0, 1.0]) {
      final x = cx + side * table.width * 0.44;
      final base = table.center.dy;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x, base - u * 0.08), width: u * 0.20, height: u * 0.22), Radius.circular(u * 0.07)),
        ink,
      );
      canvas.drawCircle(Offset(x, base - u * 0.24), u * 0.055, ink);
      canvas.drawOval(Rect.fromCenter(center: Offset(x, base - u * 0.27), width: u * 0.19, height: u * 0.035), ink);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x, base - u * 0.30), width: u * 0.10, height: u * 0.07), Radius.circular(u * 0.02)),
        ink,
      );
    }
    // Il tavolo: il panno verde, il bordo, le gambe.
    for (final f in [-0.3, 0.3]) {
      canvas.drawRect(Rect.fromLTRB(cx + table.width * f - 2, table.center.dy, cx + table.width * f + 2, glass.bottom), ink);
    }
    canvas.drawOval(table.inflate(u * 0.012), ink);
    canvas.drawOval(table, Paint()..color = const Color(0xFF2F7A52));
    canvas.drawOval(table.deflate(u * 0.015), Paint()..color = const Color(0xFF3E9466).withValues(alpha: 0.6));
    // La cornice d'oro dipinta sul vetro, con un seme di quadri negli angoli.
    final leaf = glass.deflate(max(5.0, u * 0.05));
    canvas.drawRect(
      leaf,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.0, u * 0.01)
        ..color = const Color(0xFFE6C77A).withValues(alpha: 0.7),
    );
    for (final corner in [leaf.topLeft + Offset(u * 0.07, u * 0.07), leaf.topRight + Offset(-u * 0.07, u * 0.07)]) {
      final r = u * 0.035;
      canvas.drawPath(
        Path()
          ..moveTo(corner.dx, corner.dy - r)
          ..lineTo(corner.dx + r * 0.75, corner.dy)
          ..lineTo(corner.dx, corner.dy + r)
          ..lineTo(corner.dx - r * 0.75, corner.dy)
          ..close(),
        Paint()..color = const Color(0xFFE6C77A).withValues(alpha: 0.8),
      );
    }
  }

  /// La pensilina verde col filo d'ottone sopra porta e vetrina, e due
  /// lanterne accese ai lati della porta.
  void _canopy(Canvas canvas) {
    final a = layout.awning;
    final d = layout.door;
    final slab = Rect.fromLTRB(a.left, a.top + a.height * 0.15, a.right, a.bottom);
    canvas.drawRect(slab.shift(const Offset(0, 4)), Paint()..color = Colors.black.withValues(alpha: 0.45));
    canvas.drawRect(
      slab,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1E4A3A), Color(0xFF0A1E17)],
        ).createShader(slab),
    );
    final brass = Paint()..color = const Color(0xFFC9A227);
    canvas.drawRect(Rect.fromLTRB(slab.left, slab.bottom - 2.5, slab.right, slab.bottom), brass);
    canvas.drawRect(Rect.fromLTRB(slab.left, slab.top, slab.right, slab.top + 1.2), Paint()..color = const Color(0xFFE6C77A).withValues(alpha: 0.6));
    // Le borchie lungo la pensilina.
    final n = max(6, (slab.width / 26).round());
    for (var i = 0; i <= n; i++) {
      canvas.drawCircle(Offset(slab.left + slab.width * i / n, slab.center.dy), max(1.2, slab.height * 0.09), brass);
    }
    for (final x in [d.left - d.width * 0.24, d.right + d.width * 0.24]) {
      final at = Offset(x, d.top + d.height * 0.22);
      final s = d.width * 0.11;
      canvas.drawCircle(
        at,
        s * 3.2,
        Paint()
          ..shader = const RadialGradient(colors: [Color(0x52FFC870), Color(0x00FFC870)]).createShader(Rect.fromCircle(center: at, radius: s * 3.2)),
      );
      canvas.drawRect(Rect.fromCenter(center: at.translate(0, -s * 1.3), width: s * 0.3, height: s * 0.9), brass);
      final lantern = RRect.fromRectAndRadius(Rect.fromCenter(center: at, width: s * 1.1, height: s * 1.6), Radius.circular(s * 0.25));
      canvas.drawRRect(lantern, Paint()..color = const Color(0xFFFFE6A8));
      canvas.drawRRect(
        lantern,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(1.0, s * 0.18)
          ..color = const Color(0xFF8C6A26),
      );
      canvas.drawRect(Rect.fromCenter(center: lantern.outerRect.topCenter, width: s * 1.4, height: s * 0.25), brass);
      canvas.drawRect(Rect.fromCenter(center: lantern.outerRect.bottomCenter, width: s * 0.9, height: s * 0.22), brass);
    }
  }

  /// Il cordone di velluto rosso tra due colonnine d'ottone, davanti alla
  /// vetrina: la porta resta libera.
  void _rope(Canvas canvas) {
    final d = layout.door;
    final win = layout.window;
    final ground = layout.ground + (layout.curb - layout.ground) * 0.2;
    final tall = d.height * 0.40;
    final xs = [win.left + win.width * 0.12, win.right - win.width * 0.06];
    final pole = max(2.5, d.width * 0.05);
    final top = ground - tall;
    final rope = Path()
      ..moveTo(xs[0], top + pole)
      ..quadraticBezierTo((xs[0] + xs[1]) / 2, top + pole + tall * 0.6, xs[1], top + pole);
    canvas.drawPath(
      rope.shift(const Offset(0, 3)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = pole * 1.6
        ..color = Colors.black.withValues(alpha: 0.4),
    );
    canvas.drawPath(
      rope,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = pole * 1.5
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF8E1022),
    );
    canvas.drawPath(
      rope.shift(Offset(0, -pole * 0.35)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = pole * 0.35
        ..color = const Color(0xFFE0485A).withValues(alpha: 0.5),
    );
    for (final x in xs) {
      final brass = Paint()
        ..shader = const LinearGradient(colors: [Color(0xFF8C6A26), Color(0xFFFFE7A8), Color(0xFF9C7424)])
            .createShader(Rect.fromLTRB(x - pole * 2.5, 0, x + pole * 2.5, 1));
      canvas.drawOval(Rect.fromCenter(center: Offset(x, ground), width: pole * 6, height: pole * 1.6), Paint()..color = Colors.black.withValues(alpha: 0.5));
      canvas.drawOval(Rect.fromCenter(center: Offset(x, ground - pole * 0.4), width: pole * 5, height: pole * 1.5), brass);
      canvas.drawRect(Rect.fromLTRB(x - pole / 2, top, x + pole / 2, ground), brass);
      canvas.drawCircle(Offset(x, top - pole * 0.4), pole * 1.1, brass);
    }
  }

  void _shine(Canvas canvas, double w, double h) {
    if (glow <= 0) return;
    // Il riflesso dell'insegna sull'asfalto bagnato.
    final shine = Rect.fromCenter(center: Offset(layout.neon.center.dx, layout.curb + (h - layout.curb) * 0.4), width: layout.neon.width, height: max(8.0, (h - layout.curb) * 0.5));
    canvas.drawOval(
      shine,
      Paint()
        ..shader = RadialGradient(
          colors: [section.neon.withValues(alpha: 0.22 * glow.clamp(0.0, 1.0)), section.neon.withValues(alpha: 0)],
        ).createShader(shine),
    );
  }

  @override
  bool shouldRepaint(StreetFacadePainter old) =>
      old.layout != layout ||
      old.section != section ||
      old.part != part ||
      old.open != open ||
      old.glow != glow ||
      old.vignette != vignette;
}
