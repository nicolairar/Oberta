import 'dart:math';

import 'package:flutter/material.dart';

import '../../online/shop_models.dart' show ShopBrand;
import '../widgets/noir_avatar.dart' show AvatarHead;
import 'avatar_look.dart';

/// Quello che si muove in un personaggio fermo al tavolo.
@immutable
class CharacterPose {
  /// Il respiro, da -1 a 1: le spalle salgono e scendono di un filo.
  final double breath;

  /// Dove guarda, da -1 (a sinistra di chi guarda lo schermo) a 1.
  final double glance;

  /// Da 0 (seduto) a 1 (in piedi, con le mani puntate sul tavolo).
  final double rise;

  /// I secondi che passano, per il fumo.
  final double time;

  /// Da dove arriva la luce della lampada, in coordinate dello schermo.
  final Offset light;

  /// Come tiene le mani sul panno (si sceglie dal nome, così ognuno ha il suo).
  final int hands;

  const CharacterPose({
    this.breath = 0,
    this.glance = 0,
    this.rise = 0,
    this.time = 0,
    this.light = const Offset(0, -1),
    this.hands = 0,
  });
}

/// Il pennello dei personaggi: la stessa persona, con quello che indossa,
/// seduta dietro il bordo di un tavolo ([seated]) o in un ritratto a mezzo
/// busto ([bust]). Lo stile è quello dei filmati della notte: sagome scure
/// staccate dal buio da un filo di luce calda, e la lampada che cade dall'alto
/// e lascia gli occhi nell'ombra della tesa.
///
/// Le misure sono in [s], la larghezza delle spalle; l'origine è il punto
/// del bordo del tavolo davanti al petto. In su è negativo.
abstract final class LookPainter {
  static const ink = Color(0xFF07070A);
  static const rim = Color(0xFFC9A066);
  static const gold = Color(0xFFFFD27A);
  static const paper = Color(0xFFF2EAE1);
  static const ember = Color(0xFFFF7A3B);

  /// Una persona seduta col petto contro il bordo in [base]: sotto il bordo
  /// non si vede niente, sopra il panno si posano gli avambracci.
  static void seated(
    Canvas canvas,
    AvatarLook look, {
    required Offset base,
    required double s,
    CharacterPose pose = const CharacterPose(),
    bool lit = false,
    double cut = 0.012,
    bool hands = true,
    bool chair = true,
  }) {
    if (s < 2) return;
    canvas.save();
    canvas.translate(base.dx, base.dy);
    canvas.scale(s);
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(-3, -4, 3, cut));
    if (hands && chair) _chair(canvas, empty: false, lit: lit);
    _figure(canvas, look, pose, lit: lit, hands: hands);
    if (!hands) {
      // Chi sta in piedi dietro sfuma nel buio sotto il petto.
      canvas.drawRect(
        Rect.fromLTRB(-0.7, cut - 0.3, 0.7, cut),
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x00000000), Color(0xE6000000)],
          ).createShader(Rect.fromLTRB(-0.7, cut - 0.3, 0.7, cut)),
      );
    }
    canvas.restore();
    if (hands) _forearms(canvas, look, pose, lit: lit);
    _smoke(canvas, look, pose);
    canvas.restore();
  }

  /// Il posto di chi non c'è più: la sedia vuota, scostata, e un garofano
  /// posato sul bordo del tavolo.
  static void emptyChair(Canvas canvas, {required Offset base, required double s}) {
    if (s < 2) return;
    canvas.save();
    canvas.translate(base.dx, base.dy);
    canvas.scale(s);
    canvas.save();
    canvas.clipRect(const Rect.fromLTRB(-3, -4, 3, 0.012));
    _chair(canvas, empty: true, lit: false);
    canvas.restore();
    carnation(canvas, const Offset(0.16, 0.07), 0.07, angle: -0.6);
    canvas.restore();
  }

  /// Solo la sedia, al suo posto, mentre chi ci siede gira per la sala.
  static void chair(Canvas canvas, {required Offset base, required double s}) {
    if (s < 2) return;
    canvas.save();
    canvas.translate(base.dx, base.dy);
    canvas.scale(s);
    canvas.clipRect(const Rect.fromLTRB(-3, -4, 3, 0.012));
    _chair(canvas, empty: false, lit: false);
    canvas.restore();
  }

  /// Un ritratto a mezzo busto in un quadrato di lato [side], senza fondo:
  /// la testa nel mezzo, le spalle che escono dal basso.
  static void bust(Canvas canvas, AvatarLook look, double side, {CharacterPose pose = const CharacterPose(light: Offset(-0.6, -0.8))}) {
    final s = side * 0.98;
    canvas.save();
    canvas.translate(side * 0.5, side * 0.47 + 0.86 * s);
    canvas.scale(s);
    _figure(canvas, look, pose, lit: false, hands: false);
    canvas.restore();
  }

  static Color _dark(Color c, double t) => Color.lerp(c, ink, t)!;
  static Color _bright(Color c, double t) => Color.lerp(c, const Color(0xFFFFF1D6), t)!;

  static void _chair(Canvas canvas, {required bool empty, required bool lit}) {
    // Uno schienale alto di cuoio, più largo delle spalle: si vede ai lati
    // e, quando la sedia è vuota, tutto intero.
    final back = RRect.fromRectAndCorners(
      const Rect.fromLTRB(-0.6, -0.86, 0.6, 0.2),
      topLeft: const Radius.elliptical(0.34, 0.26),
      topRight: const Radius.elliptical(0.34, 0.26),
    );
    final bounds = back.outerRect;
    canvas.drawRRect(
      back.shift(const Offset(0, -0.018)),
      Paint()..color = (lit ? gold : rim).withValues(alpha: empty ? 0.25 : 0.45),
    );
    canvas.drawRRect(back, Paint()..color = empty ? const Color(0xFF1E1C1B) : const Color(0xFF1C0D08));
    final leather = back.deflate(0.06);
    canvas.drawRRect(
      leather,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: empty
              ? const [Color(0xFF4A4542), Color(0xFF221F1D)]
              : const [Color(0xFF4A1916), Color(0xFF1A0807)],
        ).createShader(bounds),
    );
    // Le trapuntature del capitonné.
    final tuft = Paint()..color = Colors.black.withValues(alpha: 0.4);
    for (var row = 0; row < 3; row++) {
      for (var col = -2; col <= 2; col++) {
        final c = Offset(col * 0.2 + (row.isOdd ? 0.1 : 0), -0.66 + row * 0.2);
        if (!leather.contains(c)) continue;
        canvas.drawCircle(c, 0.018, tuft);
      }
    }
    final stud = Paint()..color = (empty ? const Color(0xFF8A847C) : const Color(0xFFB08E45)).withValues(alpha: 0.6);
    for (var i = 0; i <= 12; i++) {
      final a = pi + i * pi / 12;
      final c = Offset(cos(a) * 0.53, -0.6 + sin(a) * 0.21);
      canvas.drawCircle(c, 0.012, stud);
    }
  }

  /// La persona: busto, collo, testa, capelli, cappello e quello che porta.
  static void _figure(Canvas canvas, AvatarLook look, CharacterPose pose, {required bool lit, required bool hands}) {
    final lift = -0.42 * pose.rise + pose.breath * 0.012;
    final light = pose.light.distance == 0 ? const Offset(0, -1) : pose.light / pose.light.distance;
    final glow = lit ? gold : rim;
    canvas.save();
    canvas.translate(0, lift);

    final broad = look.dame ? 0.86 : 1.0;
    final torso = _torso(broad);
    final head = Rect.fromCenter(center: const Offset(0, -0.86), width: 0.32, height: 0.40);

    // Il filo di luce: la sagoma intera in chiaro, spostata verso la lampada,
    // poi tutto il resto sopra.
    canvas.save();
    canvas.translate(light.dx * 0.03, light.dy * 0.03);
    final halo = Paint()..color = glow.withValues(alpha: lit ? 0.95 : 0.75);
    canvas.drawPath(torso, halo);
    _hairBack(canvas, look, halo);
    canvas.drawOval(head, halo);
    _hat(canvas, look, halo, silhouette: true);
    canvas.restore();

    _hairBack(canvas, look, Paint()..color = _hairColor(look));
    _coat(canvas, look, torso, light);
    _neck(canvas, look);
    _face(canvas, look, head, pose, light);
    _hairFront(canvas, look);
    _glasses(canvas, look, pose);
    _hat(canvas, look, Paint(), silhouette: false);
    if (look.accessory == AvatarAccessory.carnation) carnation(canvas, Offset(0.2 * broad, -0.44), 0.05);
    if (look.accessory == AvatarAccessory.whiteCarnation) {
      carnation(canvas, Offset(0.2 * broad, -0.44), 0.05, petals: const Color(0xFFF4EEE2));
    }
    _chest(canvas, look, broad);
    _mouthProp(canvas, look);
    canvas.restore();
  }

  static Path _torso(double broad) {
    final w = 0.5 * broad;
    return Path()
      ..moveTo(-0.40 * broad, 0.6)
      ..lineTo(-w * 0.9, -0.3)
      ..quadraticBezierTo(-w * 1.02, -0.47, -w * 0.84, -0.555)
      ..quadraticBezierTo(-w * 0.5, -0.63, -0.1, -0.635)
      ..lineTo(0.1, -0.635)
      ..quadraticBezierTo(w * 0.5, -0.63, w * 0.84, -0.555)
      ..quadraticBezierTo(w * 1.02, -0.47, w * 0.9, -0.3)
      ..lineTo(0.40 * broad, 0.6)
      ..close();
  }

  static void _coat(Canvas canvas, AvatarLook look, Path torso, Offset light) {
    final outfit = look.outfit;
    final pattern = outfit.pattern;
    final bounds = torso.getBounds();
    canvas.drawPath(
      torso,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment(-light.dx * 0.6, -1),
          end: Alignment(light.dx * 0.3, 1),
          colors: [_bright(outfit.coat, 0.1), outfit.coat, _dark(outfit.coat, 0.6), _dark(outfit.coat, 0.85)],
          stops: const [0, 0.22, 0.75, 1],
        ).createShader(Rect.fromLTRB(bounds.left, -0.66, bounds.right, 0.05)),
    );
    canvas.save();
    canvas.clipPath(torso);
    final thread = Paint()
      ..color = _bright(outfit.coat, 0.5).withValues(alpha: 0.28)
      ..strokeWidth = 0.008;
    switch (pattern) {
      case CoatPattern.plain || CoatPattern.tuxedo:
        break;
      case CoatPattern.pinstripe:
        // Le righe seguono il petto: si aprono sulle spalle e si stringono in vita.
        final fine = outfit.brand == ShopBrand.vanetti;
        if (fine) thread.color = const Color(0xFFD9C9A0).withValues(alpha: 0.3);
        for (var x = -0.49; x < 0.5; x += 0.065) {
          final path = Path()
            ..moveTo(x, -0.7)
            ..quadraticBezierTo(x * 1.04, -0.35, x * 0.9, 0.6);
          canvas.drawPath(path, thread..style = PaintingStyle.stroke);
          if (fine) canvas.drawPath(path.shift(const Offset(0.014, 0)), thread);
        }
      case CoatPattern.check:
        thread.color = _bright(outfit.coat, 0.4).withValues(alpha: 0.22);
        for (var x = -0.5; x < 0.5; x += 0.09) {
          canvas.drawLine(Offset(x, -0.7), Offset(x, 0.6), thread);
        }
        for (var y = -0.62; y < 0.6; y += 0.09) {
          canvas.drawLine(Offset(-0.6, y), Offset(0.6, y), thread);
        }
        // Il secondo filo, più fino, a metà quadro.
        thread
          ..color = _dark(outfit.coat, 0.4).withValues(alpha: 0.3)
          ..strokeWidth = 0.006;
        for (var x = -0.455; x < 0.5; x += 0.09) {
          canvas.drawLine(Offset(x, -0.7), Offset(x, 0.6), thread);
        }
      case CoatPattern.windowpane:
        // Il finestrato: un quadro largo, il filo del colore della cravatta.
        thread
          ..color = Color.lerp(outfit.accent, outfit.coat, 0.25)!.withValues(alpha: 0.75)
          ..strokeWidth = 0.009;
        for (var x = -0.49; x < 0.5; x += 0.15) {
          canvas.drawLine(Offset(x, -0.7), Offset(x, 0.6), thread);
        }
        for (var y = -0.6; y < 0.6; y += 0.15) {
          canvas.drawLine(Offset(-0.6, y), Offset(0.6, y), thread);
        }
      case CoatPattern.herringbone:
        // La spina di pesce: colonne di trattini che cambiano verso.
        thread
          ..color = _bright(outfit.coat, 0.45).withValues(alpha: 0.26)
          ..strokeWidth = 0.007;
        var col = 0;
        for (var x = -0.52; x < 0.52; x += 0.04) {
          final dir = col.isEven ? 1.0 : -1.0;
          for (var y = -0.68; y < 0.6; y += 0.035) {
            canvas.drawLine(Offset(x, y), Offset(x + 0.04, y + dir * 0.022), thread);
          }
          col++;
        }
      case CoatPattern.sharkskin:
        // Il fresco di lana che cambia colore alla luce: un tratteggio fitto e
        // una lama di luce che scende dalla spalla.
        thread
          ..color = _bright(outfit.coat, 0.6).withValues(alpha: 0.12)
          ..strokeWidth = 0.006;
        for (var x = -0.9; x < 0.6; x += 0.028) {
          canvas.drawLine(Offset(x, -0.7), Offset(x + 0.4, 0.6), thread);
        }
        canvas.drawRect(
          bounds,
          Paint()
            ..shader = LinearGradient(
              begin: const Alignment(-1, -0.4),
              end: const Alignment(1, 0.4),
              colors: [Colors.transparent, Colors.white.withValues(alpha: 0.16), Colors.transparent],
              stops: const [0.2, 0.36, 0.52],
            ).createShader(bounds),
        );
      case CoatPattern.chalkstripe:
        thread
          ..color = const Color(0xFFE8E2D4).withValues(alpha: 0.42)
          ..strokeWidth = 0.011;
        for (var x = -0.48; x < 0.5; x += 0.09) {
          canvas.drawLine(Offset(x, -0.7), Offset(x * 0.9, 0.6), thread);
        }
      case CoatPattern.trench:
        // La cintura annodata e le spalline del soprabito.
        final belt = Paint()..color = _dark(outfit.coat, 0.35);
        canvas.drawRect(const Rect.fromLTRB(-0.6, -0.08, 0.6, -0.02), belt);
        canvas.drawRRect(
          RRect.fromRectAndRadius(const Rect.fromLTRB(-0.06, -0.095, 0.06, -0.005), const Radius.circular(0.01)),
          Paint()
            ..color = _dark(outfit.coat, 0.6)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.012,
        );
        final strap = Paint()
          ..color = _dark(outfit.coat, 0.35)
          ..strokeWidth = 0.035;
        final stud = Paint()..color = _dark(outfit.coat, 0.55);
        for (final side in [-1.0, 1.0]) {
          canvas.drawLine(Offset(side * 0.2, -0.6), Offset(side * 0.36, -0.53), strap);
          canvas.drawCircle(Offset(side * 0.12, -0.2), 0.014, stud);
          canvas.drawCircle(Offset(side * 0.12, -0.3), 0.014, stud);
        }
        // Il carré sulle spalle, staccato da un'ombra.
        canvas.drawLine(
          const Offset(-0.42, -0.46),
          const Offset(0.42, -0.46),
          Paint()
            ..color = _dark(outfit.coat, 0.4)
            ..strokeWidth = 0.01,
        );
      case CoatPattern.brocade:
        // Fiori d'oro ricamati, sparsi a quinconce, con un punto di luce.
        final gilt = Paint()..color = const Color(0xFFE2B54A).withValues(alpha: 0.5);
        final spark = Paint()..color = const Color(0xFFFFEBB0).withValues(alpha: 0.6);
        var row = 0;
        for (var y = -0.6; y < 0.6; y += 0.11) {
          for (var x = -0.5 + (row.isOdd ? 0.055 : 0); x < 0.5; x += 0.11) {
            for (var k = 0; k < 4; k++) {
              final a = k * pi / 2 + 0.4;
              canvas.drawCircle(Offset(x + cos(a) * 0.014, y + sin(a) * 0.014), 0.009, gilt);
            }
            canvas.drawCircle(Offset(x - 0.004, y - 0.004), 0.004, spark);
          }
          row++;
        }
      case CoatPattern.doubleBreasted:
        final button = Paint()..color = _bright(outfit.coat, 0.35);
        for (final y in [-0.26, -0.12, 0.02]) {
          canvas.drawCircle(Offset(-0.09, y), 0.016, button);
          canvas.drawCircle(Offset(0.09, y), 0.016, button);
        }
      case CoatPattern.velvet:
        // Il velluto beve la luce e la rende in una macchia morbida.
        canvas.drawOval(
          Rect.fromCenter(center: Offset(light.dx * 0.18, -0.45), width: 0.42, height: 0.5),
          Paint()
            ..color = _bright(outfit.coat, 0.5).withValues(alpha: 0.22)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.08),
        );
        // Gli alamari di passamaneria sul petto.
        final frog = Paint()
          ..color = const Color(0xFFD9B45A).withValues(alpha: 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.01;
        for (final y in [-0.3, -0.2]) {
          canvas.drawLine(Offset(-0.07, y), Offset(0.07, y), frog);
          canvas.drawCircle(Offset(-0.08, y), 0.012, frog);
          canvas.drawCircle(Offset(0.08, y), 0.012, frog);
        }
      case CoatPattern.cape:
        // Il mantello cade in pieghe lunghe dalle spalle.
        final fold = Paint()
          ..color = Colors.black.withValues(alpha: 0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.02;
        final sheen = Paint()
          ..color = Colors.white.withValues(alpha: 0.07)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.016;
        for (final x in [-0.36, -0.25, 0.25, 0.36]) {
          canvas.drawPath(
            Path()
              ..moveTo(x * 0.8, -0.58)
              ..quadraticBezierTo(x * 1.05, -0.1, x * 1.1, 0.6),
            fold,
          );
          canvas.drawPath(
            Path()
              ..moveTo(x * 0.8 + 0.025, -0.58)
              ..quadraticBezierTo(x * 1.05 + 0.025, -0.1, x * 1.1 + 0.025, 0.6),
            sheen,
          );
        }
        // La fodera rossa che si vede dove il mantello si apre.
        for (final side in [-1.0, 1.0]) {
          canvas.drawPath(
            Path()
              ..moveTo(side * 0.13, -0.625)
              ..lineTo(side * 0.21, -0.6)
              ..quadraticBezierTo(side * 0.16, -0.2, side * 0.2, 0.6)
              ..lineTo(side * 0.13, 0.6)
              ..quadraticBezierTo(side * 0.1, -0.2, side * 0.13, -0.625)
              ..close(),
            Paint()
              ..shader = LinearGradient(
                colors: [_bright(outfit.accent, 0.12), _dark(outfit.accent, 0.55)],
              ).createShader(const Rect.fromLTRB(-0.2, -0.6, 0.2, 0.0)),
          );
        }
      case CoatPattern.track:
        // La tuta: la cerniera nel mezzo, le cuciture raglan bordate.
        final piping = Paint()
          ..color = outfit.accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.018;
        for (final side in [-1.0, 1.0]) {
          canvas.drawPath(
            Path()
              ..moveTo(side * 0.11, -0.63)
              ..quadraticBezierTo(side * 0.24, -0.5, side * 0.42, -0.34),
            piping,
          );
        }
        canvas.drawLine(
          const Offset(0, -0.6),
          const Offset(0, 0.6),
          Paint()
            ..color = _dark(outfit.coat, 0.6)
            ..strokeWidth = 0.02,
        );
        final teeth = Paint()
          ..color = const Color(0xFFD9C9A8).withValues(alpha: 0.7)
          ..strokeWidth = 0.006;
        for (var y = -0.58; y < 0.0; y += 0.022) {
          canvas.drawLine(Offset(-0.008, y), Offset(0.008, y), teeth);
        }
      case CoatPattern.cardigan:
        // La maglia: costine verticali e i bottoni d'osso sul bordo.
        thread
          ..color = _dark(outfit.coat, 0.35).withValues(alpha: 0.5)
          ..strokeWidth = 0.007;
        for (var x = -0.5; x < 0.5; x += 0.03) {
          canvas.drawLine(Offset(x, -0.7), Offset(x, 0.6), thread);
        }
        // Due righe da squadra sul petto, nel colore della casa.
        final band = Paint()..color = outfit.accent;
        canvas.drawRect(const Rect.fromLTRB(-0.6, -0.36, -0.12, -0.335), band);
        canvas.drawRect(const Rect.fromLTRB(0.12, -0.36, 0.6, -0.335), band);
    }
    // Le ombre dei fianchi: il petto gira e si allontana dalla lampada.
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.black.withValues(alpha: light.dx < 0 ? 0.18 : 0.42),
            Colors.transparent,
            Colors.transparent,
            Colors.black.withValues(alpha: light.dx < 0 ? 0.42 : 0.18),
          ],
          stops: const [0, 0.3, 0.7, 1],
        ).createShader(bounds),
    );
    // Le braccia lungo i fianchi, un po' più scure del petto.
    if (pattern != CoatPattern.cape) {
      final sleeve = Paint()
        ..color = _dark(outfit.coat, 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.02;
      canvas.drawLine(const Offset(-0.33, -0.42), const Offset(-0.34, 0.6), sleeve);
      canvas.drawLine(const Offset(0.33, -0.42), const Offset(0.34, 0.6), sleeve);
    }
    // La cucitura della spalla, presa dalla luce.
    canvas.drawPath(
      Path()
        ..moveTo(-0.44, -0.52)
        ..quadraticBezierTo(-0.3, -0.6, -0.16, -0.625),
      Paint()
        ..color = _bright(outfit.coat, 0.5).withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.008,
    );
    // L'ombra del mento sul petto.
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, -0.6), width: 0.42, height: 0.16),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.04),
    );
    canvas.restore();

    if (look.dame) {
      // Uno scollo a V, senza risvolti.
      canvas.drawPath(
        Path()
          ..moveTo(-0.14, -0.62)
          ..lineTo(0.14, -0.62)
          ..lineTo(0, -0.36)
          ..close(),
        Paint()..color = _dark(look.base.skin, 0.35),
      );
      if (pattern == CoatPattern.cape) _capeCollar(canvas, outfit);
      _patch(canvas, outfit, -0.2);
      return;
    }
    // La camicia nello scollo della giacca, e i risvolti.
    final deep = switch (pattern) {
      CoatPattern.track => -0.5,
      CoatPattern.cardigan => -0.34,
      _ => -0.24,
    };
    final shirt = Path()
      ..moveTo(-0.13, -0.625)
      ..lineTo(0.13, -0.625)
      ..lineTo(0, deep)
      ..close();
    canvas.drawPath(
      shirt,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [outfit.shirt, _dark(outfit.shirt, 0.45)],
        ).createShader(Rect.fromLTRB(-0.13, -0.63, 0.13, deep)),
    );
    if (outfit.satin && pattern != CoatPattern.velvet) {
      // Lo sparato della camicia da sera: le pieghe e i bottoni d'oro.
      final pleat = Paint()
        ..color = _dark(outfit.shirt, 0.25)
        ..strokeWidth = 0.005;
      for (final x in [-0.04, 0.04]) {
        canvas.drawLine(Offset(x, -0.56), Offset(x * 0.4, -0.3), pleat);
      }
      final stud = Paint()..color = gold;
      for (final y in [-0.47, -0.39, -0.31]) {
        canvas.drawCircle(Offset(0, y), 0.009, stud);
      }
    }
    switch (pattern) {
      case CoatPattern.track:
        // Il collo a costine, chiuso fin quasi al mento.
        _ribCollar(canvas, outfit.coat, outfit.accent);
      case CoatPattern.cardigan:
        final edge = Paint()
          ..color = _dark(outfit.coat, 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.03;
        canvas.drawLine(const Offset(-0.13, -0.625), const Offset(0, -0.34), edge);
        canvas.drawLine(const Offset(0.13, -0.625), const Offset(0, -0.34), edge);
        final button = Paint()..color = const Color(0xFFE8DCC0);
        for (final y in [-0.3, -0.18, -0.06]) {
          canvas.drawCircle(Offset(0, y), 0.014, button);
        }
      case CoatPattern.cape:
        _capeCollar(canvas, outfit);
        // La catenella d'oro che chiude il mantello.
        final chain = Paint()
          ..color = gold
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.009;
        canvas.drawPath(
          Path()
            ..moveTo(-0.16, -0.5)
            ..quadraticBezierTo(0, -0.44, 0.16, -0.5),
          chain,
        );
        for (final side in [-1.0, 1.0]) {
          canvas.drawCircle(Offset(side * 0.165, -0.5), 0.02, Paint()..color = gold);
        }
        if (outfit.brand case final brand?) brandMark(canvas, brand, const Offset(0.165, -0.5), 0.016, color: ink);
      default:
        _lapels(canvas, outfit, light);
    }
    if (!pattern.ownCollar) {
      // Il taschino, un filo d'ombra e uno di luce.
      canvas.drawLine(const Offset(0.15, -0.415), const Offset(0.28, -0.425), Paint()
        ..color = _dark(outfit.coat, 0.55)
        ..strokeWidth = 0.012);
      canvas.drawLine(const Offset(0.15, -0.405), const Offset(0.28, -0.415), Paint()
        ..color = _bright(outfit.coat, 0.35).withValues(alpha: 0.35)
        ..strokeWidth = 0.005);
    }
    if (pattern != CoatPattern.cape) _patch(canvas, outfit, -0.21);
  }

  /// I risvolti: a lancia sui doppiopetti, a scialle sul velluto e sugli
  /// smoking della casa, a dente sugli altri. Il raso prende la luce.
  static void _lapels(Canvas canvas, AvatarOutfit outfit, Offset light) {
    final pattern = outfit.pattern;
    final shawl = pattern == CoatPattern.velvet || pattern == CoatPattern.tuxedo;
    final peak = pattern == CoatPattern.doubleBreasted || pattern == CoatPattern.brocade;
    final cloth = outfit.satin
        ? (outfit.coat.computeLuminance() > 0.4 ? const Color(0xFF16151A) : _dark(outfit.coat, 0.15))
        : _dark(outfit.coat, 0.3);
    final edge = Paint()
      ..color = _bright(outfit.coat, 0.35).withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.012;
    for (final side in [-1.0, 1.0]) {
      final Path path;
      if (shawl) {
        path = Path()
          ..moveTo(side * 0.13, -0.625)
          ..quadraticBezierTo(side * 0.27, -0.55, side * 0.17, -0.36)
          ..quadraticBezierTo(side * 0.09, -0.22, side * 0.02, -0.15)
          ..lineTo(0, -0.24)
          ..close();
      } else if (peak) {
        path = Path()
          ..moveTo(side * 0.13, -0.625)
          ..lineTo(side * 0.24, -0.585)
          ..lineTo(side * 0.19, -0.46)
          ..lineTo(side * 0.28, -0.5)
          ..lineTo(side * 0.24, -0.4)
          ..lineTo(side * 0.02, -0.15)
          ..lineTo(0, -0.24)
          ..close();
      } else {
        path = Path()
          ..moveTo(side * 0.13, -0.625)
          ..lineTo(side * 0.25, -0.585)
          ..lineTo(side * 0.17, -0.44)
          ..lineTo(side * 0.22, -0.4)
          ..lineTo(side * 0.02, -0.15)
          ..lineTo(0, -0.24)
          ..close();
      }
      final lit = side * light.dx < 0;
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: outfit.satin
                ? [_bright(cloth, lit ? 0.45 : 0.2), cloth, _bright(cloth, lit ? 0.3 : 0.1), _dark(cloth, 0.5)]
                : [_bright(cloth, lit ? 0.12 : 0.0), cloth, _dark(cloth, 0.4), _dark(cloth, 0.5)],
            stops: const [0, 0.35, 0.55, 1],
          ).createShader(const Rect.fromLTRB(-0.3, -0.63, 0.3, -0.15)),
      );
      canvas.drawPath(path, edge..color = (outfit.satin ? Colors.white : _bright(outfit.coat, 0.35)).withValues(alpha: lit ? 0.5 : 0.25));
      // L'ombra che il risvolto getta sulla giacca.
      canvas.drawLine(
        Offset(side * 0.23, -0.4),
        Offset(side * 0.04, -0.15),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.35)
          ..strokeWidth = 0.014,
      );
    }
    // L'occhiello, e il bottone sotto lo scollo.
    canvas.drawLine(const Offset(0.16, -0.5), const Offset(0.2, -0.51), Paint()
      ..color = _dark(cloth, 0.6)
      ..strokeWidth = 0.008);
    if (pattern != CoatPattern.doubleBreasted) {
      canvas.drawCircle(const Offset(0.0, -0.19), 0.017, Paint()..color = outfit.satin ? _dark(cloth, 0.2) : _bright(outfit.coat, 0.3));
    }
  }

  /// Il collo alto del mantello, foderato di rosso, dietro la nuca.
  static void _capeCollar(Canvas canvas, AvatarOutfit outfit) {
    for (final side in [-1.0, 1.0]) {
      canvas.drawPath(
        Path()
          ..moveTo(side * 0.11, -0.62)
          ..lineTo(side * 0.2, -0.76)
          ..quadraticBezierTo(side * 0.3, -0.66, side * 0.3, -0.56)
          ..close(),
        Paint()..color = _dark(outfit.coat, 0.1),
      );
      canvas.drawPath(
        Path()
          ..moveTo(side * 0.12, -0.62)
          ..lineTo(side * 0.19, -0.73)
          ..quadraticBezierTo(side * 0.25, -0.66, side * 0.26, -0.585)
          ..close(),
        Paint()..color = _dark(outfit.accent, 0.2),
      );
    }
  }

  /// Il collo a costine della tuta, con la cerniera tirata su.
  static void _ribCollar(Canvas canvas, Color coat, Color accent) {
    final collar = Path()
      ..moveTo(-0.14, -0.64)
      ..quadraticBezierTo(0, -0.6, 0.14, -0.64)
      ..lineTo(0.13, -0.57)
      ..quadraticBezierTo(0, -0.53, -0.13, -0.57)
      ..close();
    canvas.drawPath(collar, Paint()..color = _dark(coat, 0.15));
    canvas.save();
    canvas.clipPath(collar);
    final rib = Paint()
      ..color = Colors.black.withValues(alpha: 0.35)
      ..strokeWidth = 0.006;
    for (var x = -0.14; x < 0.15; x += 0.018) {
      canvas.drawLine(Offset(x, -0.65), Offset(x, -0.52), rib);
    }
    canvas.restore();
    canvas.drawPath(
      Path()
        ..moveTo(-0.13, -0.57)
        ..quadraticBezierTo(0, -0.53, 0.13, -0.57),
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.012,
    );
    // La linguetta della cerniera.
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTRB(-0.012, -0.56, 0.012, -0.515), const Radius.circular(0.006)),
      Paint()..color = const Color(0xFFD9C9A8),
    );
  }

  /// La toppa ricamata della casa, sul petto a sinistra di chi guarda.
  static void _patch(Canvas canvas, AvatarOutfit outfit, double x) {
    final brand = outfit.brand;
    if (brand == null) return;
    const y = -0.43;
    final shield = Path()
      ..moveTo(x - 0.042, y - 0.04)
      ..lineTo(x + 0.042, y - 0.04)
      ..lineTo(x + 0.042, y + 0.01)
      ..quadraticBezierTo(x + 0.04, y + 0.04, x, y + 0.055)
      ..quadraticBezierTo(x - 0.04, y + 0.04, x - 0.042, y + 0.01)
      ..close();
    canvas.drawPath(shield.shift(const Offset(0.004, 0.006)), Paint()..color = Colors.black.withValues(alpha: 0.4));
    canvas.drawPath(shield, Paint()..color = _dark(outfit.coat, 0.45));
    canvas.drawPath(
      shield,
      Paint()
        ..color = brand.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.008,
    );
    brandMark(canvas, brand, Offset(x, y + 0.005), 0.03);
  }

  /// Il marchio di una casa, inscritto in un cerchio di raggio [r]: segni
  /// semplici, inventati, che si leggono anche piccoli.
  static void brandMark(Canvas canvas, ShopBrand brand, Offset c, double r, {Color? color}) {
    final ink = color ?? brand.color;
    final fill = Paint()..color = ink;
    final line = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.2
      ..strokeJoin = StrokeJoin.miter
      ..strokeCap = StrokeCap.square;
    switch (brand) {
      case ShopBrand.vanetti:
        // Una V dentro un rombo.
        canvas.drawPath(
          Path()
            ..moveTo(c.dx, c.dy - r)
            ..lineTo(c.dx + r * 0.8, c.dy)
            ..lineTo(c.dx, c.dy + r)
            ..lineTo(c.dx - r * 0.8, c.dy)
            ..close(),
          line..strokeWidth = r * 0.14,
        );
        canvas.drawPath(
          Path()
            ..moveTo(c.dx - r * 0.38, c.dy - r * 0.36)
            ..lineTo(c.dx, c.dy + r * 0.45)
            ..lineTo(c.dx + r * 0.38, c.dy - r * 0.36),
          line..strokeWidth = r * 0.2,
        );
      case ShopBrand.moretti:
        // Una tesa di cappello sopra una riga: la bottega dei fratelli.
        canvas.drawOval(Rect.fromCenter(center: c.translate(0, r * 0.15), width: r * 1.9, height: r * 0.42), fill);
        canvas.drawPath(
          Path()
            ..moveTo(c.dx - r * 0.55, c.dy + r * 0.1)
            ..lineTo(c.dx - r * 0.48, c.dy - r * 0.62)
            ..quadraticBezierTo(c.dx, c.dy - r * 0.85, c.dx + r * 0.48, c.dy - r * 0.62)
            ..lineTo(c.dx + r * 0.55, c.dy + r * 0.1)
            ..close(),
          fill,
        );
        canvas.drawLine(c.translate(-r * 0.7, r * 0.72), c.translate(r * 0.7, r * 0.72), line..strokeWidth = r * 0.16);
      case ShopBrand.delacroix:
        // Una falce di luna e una stella: la sera di Parigi.
        canvas.saveLayer(Rect.fromCircle(center: c, radius: r * 1.2), Paint());
        canvas.drawCircle(c.translate(-r * 0.15, 0), r * 0.8, fill);
        canvas.drawCircle(c.translate(r * 0.2, -r * 0.15), r * 0.66, Paint()..blendMode = BlendMode.clear);
        canvas.restore();
        final star = Path();
        for (var k = 0; k < 8; k++) {
          final a = -pi / 2 + k * pi / 4;
          final d = k.isEven ? r * 0.38 : r * 0.13;
          final p = c.translate(r * 0.42 + cos(a) * d, -r * 0.1 + sin(a) * d);
          k == 0 ? star.moveTo(p.dx, p.dy) : star.lineTo(p.dx, p.dy);
        }
        canvas.drawPath(star..close(), fill);
      case ShopBrand.fulmine:
        // Un fulmine dentro un tondo.
        canvas.drawCircle(c, r * 0.92, line..strokeWidth = r * 0.14);
        canvas.drawPath(
          Path()
            ..moveTo(c.dx + r * 0.22, c.dy - r * 0.72)
            ..lineTo(c.dx - r * 0.38, c.dy + r * 0.1)
            ..lineTo(c.dx - r * 0.02, c.dy + r * 0.1)
            ..lineTo(c.dx - r * 0.22, c.dy + r * 0.72)
            ..lineTo(c.dx + r * 0.38, c.dy - r * 0.12)
            ..lineTo(c.dx + r * 0.02, c.dy - r * 0.12)
            ..close(),
          fill,
        );
      case ShopBrand.ricci:
        // Una gemma tagliata: la corona e il padiglione.
        final gem = Path()
          ..moveTo(c.dx - r * 0.85, c.dy - r * 0.25)
          ..lineTo(c.dx - r * 0.45, c.dy - r * 0.7)
          ..lineTo(c.dx + r * 0.45, c.dy - r * 0.7)
          ..lineTo(c.dx + r * 0.85, c.dy - r * 0.25)
          ..lineTo(c.dx, c.dy + r * 0.85)
          ..close();
        canvas.drawPath(gem, line..strokeWidth = r * 0.14);
        canvas.drawLine(c.translate(-r * 0.85, -r * 0.25), c.translate(r * 0.85, -r * 0.25), line..strokeWidth = r * 0.1);
        canvas.drawPath(
          Path()
            ..moveTo(c.dx - r * 0.3, c.dy - r * 0.25)
            ..lineTo(c.dx, c.dy + r * 0.85)
            ..lineTo(c.dx + r * 0.3, c.dy - r * 0.25),
          line,
        );
    }
  }

  /// La sagoma della cravatta, dal nodo alla punta.
  static Path _tiePath({bool square = false}) => square
      ? (Path()
          ..moveTo(-0.032, -0.615)
          ..lineTo(0.032, -0.615)
          ..lineTo(0.024, -0.56)
          ..lineTo(0.04, -0.25)
          ..lineTo(-0.04, -0.25)
          ..lineTo(-0.024, -0.56)
          ..close())
      : (Path()
          ..moveTo(-0.035, -0.615)
          ..lineTo(0.035, -0.615)
          ..lineTo(0.025, -0.56)
          ..lineTo(0.055, -0.27)
          ..lineTo(0, -0.22)
          ..lineTo(-0.055, -0.27)
          ..lineTo(-0.025, -0.56)
          ..close());

  /// Una cravatta di [color], con il nodo, la piega di luce e, se c'è,
  /// il disegno della stoffa ([decorate], già ritagliato sulla cravatta).
  static void _tie(Canvas canvas, Color color, {bool square = false, void Function()? decorate}) {
    final path = _tiePath(square: square);
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_bright(color, 0.15), _dark(color, 0.45)],
        ).createShader(const Rect.fromLTRB(-0.06, -0.62, 0.06, -0.2)),
    );
    if (decorate != null) {
      canvas.save();
      canvas.clipPath(path);
      decorate();
      canvas.restore();
    }
    // Il filo di luce della seta lungo un lato.
    canvas.drawLine(
      const Offset(-0.012, -0.55),
      const Offset(-0.03, -0.3),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.18)
        ..strokeWidth = 0.008,
    );
    canvas.drawPath(
      Path()
        ..moveTo(-0.035, -0.615)
        ..lineTo(0.035, -0.615)
        ..lineTo(0.025, -0.56)
        ..lineTo(-0.025, -0.56)
        ..close(),
      Paint()..color = _dark(color, 0.3),
    );
    canvas.drawLine(
      const Offset(-0.03, -0.56),
      const Offset(0.03, -0.56),
      Paint()
        ..color = _dark(color, 0.6)
        ..strokeWidth = 0.01,
    );
  }

  /// Il farfallino, liscio o a pois.
  static void _bow(Canvas canvas, Color color, {bool dots = false}) {
    final bow = Path()
      ..moveTo(0, -0.585)
      ..quadraticBezierTo(-0.05, -0.64, -0.088, -0.628)
      ..lineTo(-0.088, -0.542)
      ..quadraticBezierTo(-0.05, -0.53, 0, -0.585)
      ..close()
      ..moveTo(0, -0.585)
      ..quadraticBezierTo(0.05, -0.64, 0.088, -0.628)
      ..lineTo(0.088, -0.542)
      ..quadraticBezierTo(0.05, -0.53, 0, -0.585)
      ..close();
    canvas.drawPath(
      bow,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_bright(color, 0.25), _dark(color, 0.35)],
        ).createShader(const Rect.fromLTRB(-0.09, -0.63, 0.09, -0.54)),
    );
    if (dots) {
      final dot = Paint()..color = paper.withValues(alpha: 0.9);
      for (final p in const [
        Offset(-0.07, -0.6),
        Offset(-0.045, -0.57),
        Offset(-0.07, -0.56),
        Offset(0.07, -0.6),
        Offset(0.045, -0.57),
        Offset(0.07, -0.56),
      ]) {
        canvas.drawCircle(p, 0.007, dot);
      }
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: const Offset(0, -0.585), width: 0.032, height: 0.044), const Radius.circular(0.008)),
      Paint()..color = _dark(color, 0.4),
    );
  }

  /// Il colletto aperto della camicia.
  static void _openCollar(Canvas canvas, AvatarLook look) {
    if (look.dame) return;
    final collar = Paint()..color = _dark(look.outfit.shirt, 0.1);
    canvas.drawPath(
      Path()
        ..moveTo(-0.08, -0.64)
        ..lineTo(-0.13, -0.55)
        ..lineTo(-0.02, -0.5)
        ..close()
        ..moveTo(0.08, -0.64)
        ..lineTo(0.13, -0.55)
        ..lineTo(0.02, -0.5)
        ..close(),
      collar,
    );
  }

  static void _neck(Canvas canvas, AvatarLook look) {
    final skin = look.base.skin;
    canvas.drawRect(const Rect.fromLTRB(-0.075, -0.72, 0.075, -0.58), Paint()..color = _dark(skin, 0.62));
    final accent = look.outfit.accent;
    // La tuta ha il suo collo: niente cravatte sotto la cerniera.
    final zipped = look.outfit.pattern == CoatPattern.track && !look.dame;
    switch (look.accessory) {
      case AvatarAccessory.tie:
        if (look.dame || zipped) break;
        _tie(canvas, accent);
      case AvatarAccessory.stripeTie:
        if (look.dame || zipped) break;
        // A righe oblique, come quelle dei collegi.
        _tie(
          canvas,
          const Color(0xFF1B2A4A),
          decorate: () {
            final stripe = Paint()
              ..color = const Color(0xFFC9A04A)
              ..strokeWidth = 0.016;
            final thin = Paint()
              ..color = const Color(0xFF9B2335)
              ..strokeWidth = 0.007;
            for (var y = -0.62; y < -0.15; y += 0.07) {
              canvas.drawLine(Offset(-0.07, y), Offset(0.07, y + 0.07), stripe);
              canvas.drawLine(Offset(-0.07, y + 0.03), Offset(0.07, y + 0.1), thin);
            }
          },
        );
      case AvatarAccessory.knitTie:
        if (look.dame || zipped) break;
        // Di maglia, la punta dritta e la trama a righe fitte.
        _tie(
          canvas,
          const Color(0xFF2E3A2A),
          square: true,
          decorate: () {
            final knit = Paint()
              ..color = Colors.black.withValues(alpha: 0.35)
              ..strokeWidth = 0.005;
            for (var y = -0.55; y < -0.24; y += 0.016) {
              canvas.drawLine(Offset(-0.05, y), Offset(0.05, y), knit);
            }
          },
        );
      case AvatarAccessory.ricciTiePin:
        if (look.dame || zipped) break;
        _tie(canvas, accent);
        // Il fermacravatta d'oro con il brillante.
        canvas.drawRRect(
          RRect.fromRectAndRadius(const Rect.fromLTRB(-0.075, -0.43, 0.075, -0.414), const Radius.circular(0.006)),
          Paint()..color = gold,
        );
        canvas.drawLine(
          const Offset(-0.07, -0.427),
          const Offset(0.07, -0.427),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.6)
            ..strokeWidth = 0.004,
        );
        _diamond(canvas, const Offset(0.072, -0.422), 0.016);
      case AvatarAccessory.bowTie:
        if (zipped) break;
        _bow(canvas, look.outfit.id == 'black_tuxedo' || look.outfit.pattern == CoatPattern.tuxedo ? ink : _dark(accent, 0.1));
      case AvatarAccessory.polkaBowTie:
        if (zipped) break;
        _bow(canvas, const Color(0xFF15233F), dots: true);
      case AvatarAccessory.pearls:
        final pearl = Paint()..color = paper.withValues(alpha: 0.92);
        final shine = Paint()..color = Colors.white;
        for (var i = 0; i <= 10; i++) {
          final t = i / 10;
          final c = Offset(-0.12 + 0.24 * t, -0.6 + 0.07 * sin(pi * t));
          canvas.drawCircle(c, 0.014, pearl);
          canvas.drawCircle(c.translate(-0.004, -0.004), 0.004, shine);
        }
      case AvatarAccessory.scarf:
        canvas.drawPath(
          Path()
            ..moveTo(-0.13, -0.63)
            ..quadraticBezierTo(0, -0.54, 0.13, -0.63)
            ..lineTo(0.06, -0.42)
            ..quadraticBezierTo(0, -0.36, -0.05, -0.43)
            ..close(),
          Paint()
            ..shader = LinearGradient(
              colors: [_bright(accent, 0.3), _dark(accent, 0.3)],
            ).createShader(const Rect.fromLTRB(-0.13, -0.63, 0.13, -0.36)),
        );
      case AvatarAccessory.delacroixScarf:
        // La sciarpa di seta bianca da sera: gira intorno al collo e scende
        // sui risvolti, con le frange e la luna ricamata.
        final silk = Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFFBF2), Color(0xFFD8D0C2), Color(0xFFF6F0E4), Color(0xFFB8AFA2)],
            stops: [0, 0.35, 0.6, 1],
          ).createShader(const Rect.fromLTRB(-0.2, -0.66, 0.2, -0.32));
        canvas.drawPath(
          Path()
            ..moveTo(-0.14, -0.65)
            ..quadraticBezierTo(0, -0.57, 0.14, -0.65)
            ..lineTo(0.15, -0.6)
            ..quadraticBezierTo(0, -0.52, -0.15, -0.6)
            ..close(),
          silk,
        );
        for (final side in [-1.0, 1.0]) {
          canvas.drawPath(
            Path()
              ..moveTo(side * 0.15, -0.62)
              ..quadraticBezierTo(side * 0.17, -0.48, side * 0.13, -0.34)
              ..lineTo(side * 0.05, -0.36)
              ..quadraticBezierTo(side * 0.08, -0.48, side * 0.06, -0.58)
              ..close(),
            silk,
          );
          final fringe = Paint()
            ..color = const Color(0xFFE8E0D0)
            ..strokeWidth = 0.005;
          for (var k = 0; k <= 5; k++) {
            final x = side * (0.05 + 0.08 * k / 5);
            final y = -0.36 + 0.02 * k / 5;
            canvas.drawLine(Offset(x, y), Offset(x, y + 0.025), fringe);
          }
        }
        brandMark(canvas, ShopBrand.delacroix, const Offset(-0.1, -0.42), 0.022, color: const Color(0xFF8A7FA8));
      case AvatarAccessory.polkaTie:
        if (look.dame || zipped) break;
        _tie(
          canvas,
          const Color(0xFF8E1D28),
          decorate: () {
            final dot = Paint()..color = paper.withValues(alpha: 0.85);
            for (final p in const [Offset(0, -0.58), Offset(-0.02, -0.5), Offset(0.02, -0.44), Offset(-0.025, -0.37), Offset(0.025, -0.31), Offset(0, -0.26)]) {
              canvas.drawCircle(p, 0.008, dot);
            }
          },
        );
      case AvatarAccessory.cravat:
        // Il foulard di seta annodato sotto il mento, con la spilla.
        final silk = Paint()
          ..shader = LinearGradient(
            colors: [_bright(accent, 0.35), _dark(accent, 0.25)],
          ).createShader(const Rect.fromLTRB(-0.1, -0.64, 0.1, -0.36));
        canvas.drawPath(_ascotPath, silk);
        canvas.drawCircle(const Offset(0, -0.52), 0.015, Paint()..color = gold);
      case AvatarAccessory.delacroixAscot:
        // Il foulard della casa: seta lilla a lune piccole, la spilla d'oro.
        canvas.drawPath(
          _ascotPath,
          Paint()
            ..shader = const LinearGradient(
              colors: [Color(0xFFB7A6D6), Color(0xFF4E3F72)],
            ).createShader(const Rect.fromLTRB(-0.1, -0.64, 0.1, -0.36)),
        );
        canvas.save();
        canvas.clipPath(_ascotPath);
        for (final p in const [Offset(-0.05, -0.58), Offset(0.04, -0.55), Offset(-0.02, -0.46), Offset(0.05, -0.43), Offset(-0.05, -0.4)]) {
          brandMark(canvas, ShopBrand.delacroix, p, 0.014, color: const Color(0xFFF2EAE1).withValues(alpha: 0.6));
        }
        canvas.restore();
        canvas.drawPath(
          Path()
            ..moveTo(-0.06, -0.6)
            ..quadraticBezierTo(0, -0.52, 0.03, -0.38),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.25)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.008,
        );
        canvas.drawCircle(const Offset(0, -0.52), 0.017, Paint()..color = gold);
        canvas.drawCircle(const Offset(-0.004, -0.524), 0.006, Paint()..color = const Color(0xFFFFF4D0));
      case AvatarAccessory.suspenders:
        // Le bretelle sopra il panciotto, con le fibbie d'ottone.
        _openCollar(canvas, look);
        final strap = Paint()
          ..color = const Color(0xFF8E1D28)
          ..strokeWidth = 0.032;
        final clip = Paint()..color = gold;
        for (final side in [-1.0, 1.0]) {
          canvas.drawLine(Offset(side * 0.17, -0.63), Offset(side * 0.1, -0.33), strap);
          canvas.drawLine(
            Offset(side * 0.16, -0.62),
            Offset(side * 0.09, -0.33),
            Paint()
              ..color = Colors.white.withValues(alpha: 0.18)
              ..strokeWidth = 0.006,
          );
          canvas.drawRect(Rect.fromCenter(center: Offset(side * 0.135, -0.47), width: 0.045, height: 0.026), clip);
        }
      case AvatarAccessory.ricciChain:
        // La catena grossa, a maglie, con la medaglia di brillanti.
        _openCollar(canvas, look);
        final link = Paint()
          ..color = gold
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.008;
        for (var i = 0; i <= 12; i++) {
          final t = i / 12;
          final c = Offset(-0.12 + 0.24 * t, -0.61 + 0.13 * sin(pi * t));
          canvas.drawOval(Rect.fromCenter(center: c, width: i.isEven ? 0.026 : 0.018, height: i.isEven ? 0.018 : 0.026), link);
        }
        canvas.drawCircle(const Offset(0, -0.455), 0.032, Paint()..color = const Color(0xFFB8862E));
        canvas.drawCircle(const Offset(0, -0.455), 0.026, Paint()..color = gold);
        brandMark(canvas, ShopBrand.ricci, const Offset(0, -0.455), 0.018, color: const Color(0xFF7A5418));
        canvas.drawCircle(const Offset(-0.012, -0.468), 0.006, Paint()..color = Colors.white.withValues(alpha: 0.9));
      case AvatarAccessory.none ||
          AvatarAccessory.carnation ||
          AvatarAccessory.whiteCarnation ||
          AvatarAccessory.cigar ||
          AvatarAccessory.cigarette ||
          AvatarAccessory.cigaretteHolder ||
          AvatarAccessory.toothpick ||
          AvatarAccessory.pocketWatch ||
          AvatarAccessory.ricciWatch ||
          AvatarAccessory.pipe ||
          AvatarAccessory.pocketSquare:
        if (zipped) break;
        _openCollar(canvas, look);
    }
  }

  static final Path _ascotPath = Path()
    ..moveTo(-0.09, -0.63)
    ..quadraticBezierTo(0, -0.58, 0.09, -0.63)
    ..quadraticBezierTo(0.1, -0.5, 0.05, -0.38)
    ..quadraticBezierTo(0, -0.34, -0.05, -0.38)
    ..quadraticBezierTo(-0.1, -0.5, -0.09, -0.63)
    ..close();

  /// Un brillante: il taglio, il riflesso e la stella di luce.
  static void _diamond(Canvas canvas, Offset c, double r) {
    canvas.drawPath(
      Path()
        ..moveTo(c.dx, c.dy - r)
        ..lineTo(c.dx + r * 0.8, c.dy)
        ..lineTo(c.dx, c.dy + r)
        ..lineTo(c.dx - r * 0.8, c.dy)
        ..close(),
      Paint()..color = const Color(0xFFE6F2FF),
    );
    canvas.drawPath(
      Path()
        ..moveTo(c.dx, c.dy - r)
        ..lineTo(c.dx + r * 0.8, c.dy)
        ..lineTo(c.dx, c.dy)
        ..close(),
      Paint()..color = const Color(0xFF9FB8D6),
    );
    final glint = Paint()
      ..color = Colors.white
      ..strokeWidth = r * 0.25
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(c.translate(-r * 1.4, -r * 0.9), c.translate(-r * 0.6, -r * 0.9), glint);
    canvas.drawLine(c.translate(-r, -r * 1.3), c.translate(-r, -r * 0.5), glint);
  }

  /// Quello che si porta sulla giacca: la catena dell'orologio e il fazzoletto.
  /// Tutto sopra la vita, perché il ritratto taglia il petto a metà.
  static void _chest(Canvas canvas, AvatarLook look, double broad) {
    switch (look.accessory) {
      case AvatarAccessory.pocketWatch:
        // La catena va dall'occhiello al taschino, dove l'orologio fa capolino.
        final chain = Paint()
          ..color = gold
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.011;
        canvas.drawPath(
          Path()
            ..moveTo(-0.02, -0.45)
            ..quadraticBezierTo(0.08, -0.36, 0.2 * broad, -0.43),
          chain,
        );
        canvas.drawPath(
          Path()
            ..moveTo(-0.02, -0.45)
            ..quadraticBezierTo(0.08, -0.36, 0.2 * broad, -0.43),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.45)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.004,
        );
        canvas.drawCircle(const Offset(-0.02, -0.45), 0.011, Paint()..color = gold);
        canvas.drawCircle(Offset(0.2 * broad, -0.43), 0.024, Paint()..color = const Color(0xFFB8862E));
        canvas.drawCircle(Offset(0.2 * broad, -0.43), 0.019, Paint()..color = gold);
        canvas.drawCircle(Offset(0.2 * broad - 0.007, -0.437), 0.006, Paint()..color = Colors.white.withValues(alpha: 0.8));
      case AvatarAccessory.ricciWatch:
        // La cipolla d'oro: aperta, il quadrante bianco, le lancette, la
        // corona con il brillante e una catena doppia.
        final c = Offset(0.2 * broad, -0.44);
        final chain = Paint()
          ..color = gold
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.012;
        for (final sag in [-0.36, -0.33]) {
          canvas.drawPath(
            Path()
              ..moveTo(-0.03, -0.46)
              ..quadraticBezierTo(0.06, sag, c.dx - 0.02, c.dy + 0.03),
            chain,
          );
        }
        canvas.drawCircle(const Offset(-0.03, -0.46), 0.014, Paint()..color = gold);
        canvas.drawCircle(c.translate(0.003, 0.005), 0.05, Paint()..color = Colors.black.withValues(alpha: 0.45));
        canvas.drawCircle(
          c,
          0.048,
          Paint()
            ..shader = const RadialGradient(
              center: Alignment(-0.5, -0.5),
              colors: [Color(0xFFFFF0B8), Color(0xFFE2B54A), Color(0xFF8A5E1E)],
            ).createShader(Rect.fromCircle(center: c, radius: 0.048)),
        );
        canvas.drawCircle(c, 0.036, Paint()..color = const Color(0xFFF8F2E2));
        final tick = Paint()
          ..color = ink
          ..strokeWidth = 0.005;
        for (var k = 0; k < 12; k += 3) {
          final a = k * pi / 6;
          canvas.drawLine(c + Offset(cos(a), sin(a)) * 0.028, c + Offset(cos(a), sin(a)) * 0.034, tick);
        }
        canvas.drawLine(c, c.translate(0.0, -0.026), tick..strokeWidth = 0.006);
        canvas.drawLine(c, c.translate(0.018, 0.008), tick);
        canvas.drawRect(Rect.fromCenter(center: c.translate(0, -0.056), width: 0.016, height: 0.014), Paint()..color = gold);
        _diamond(canvas, c.translate(0, -0.068), 0.011);
      case AvatarAccessory.pocketSquare:
        canvas.drawPath(
          Path()
            ..moveTo(0.15 * broad, -0.4)
            ..lineTo(0.17 * broad, -0.45)
            ..lineTo(0.2 * broad, -0.41)
            ..lineTo(0.23 * broad, -0.46)
            ..lineTo(0.26 * broad, -0.4)
            ..close(),
          Paint()..color = paper,
        );
        canvas.drawLine(
          Offset(0.14 * broad, -0.4),
          Offset(0.27 * broad, -0.4),
          Paint()
            ..color = _dark(look.outfit.coat, 0.5)
            ..strokeWidth = 0.012,
        );
      default:
        break;
    }
  }

  static Color _hairColor(AvatarLook look) => switch (look.base.tone) {
    SkinTone.porcelain || SkinTone.rose => const Color(0xFF2A1C14),
    _ => const Color(0xFF0E0B0A),
  };

  static void _hairBack(Canvas canvas, AvatarLook look, Paint paint) {
    switch (look.hat) {
      case AvatarHead.bob || AvatarHead.wideBrim:
        canvas.drawRRect(
          RRect.fromRectAndRadius(const Rect.fromLTRB(-0.215, -1.07, 0.215, -0.68), const Radius.circular(0.15)),
          paint,
        );
      case AvatarHead.bun:
        canvas.drawCircle(const Offset(0, -1.1), 0.075, paint);
      default:
        break;
    }
  }

  static void _face(Canvas canvas, AvatarLook look, Rect head, CharacterPose pose, Offset light) {
    final skin = look.base.skin;
    // Le orecchie, poi la faccia: la lampada accende la fronte e uno zigomo,
    // il resto affonda nel buio.
    final ear = Paint()..color = _dark(skin, 0.55);
    canvas.drawOval(Rect.fromCenter(center: const Offset(-0.165, -0.85), width: 0.05, height: 0.09), ear);
    canvas.drawOval(Rect.fromCenter(center: const Offset(0.165, -0.85), width: 0.05, height: 0.09), ear);
    final face = Path()
      ..moveTo(-0.16, -0.9)
      ..quadraticBezierTo(-0.16, -1.06, 0, -1.06)
      ..quadraticBezierTo(0.16, -1.06, 0.16, -0.9)
      ..quadraticBezierTo(0.16, -0.76, 0.09, -0.7)
      ..quadraticBezierTo(0, -0.64, -0.09, -0.7)
      ..quadraticBezierTo(-0.16, -0.76, -0.16, -0.9)
      ..close();
    canvas.drawPath(
      face,
      Paint()
        ..shader = RadialGradient(
          center: Alignment(light.dx * 0.45, -0.25),
          radius: 0.95,
          colors: [_bright(skin, 0.06), _dark(skin, 0.3), _dark(skin, 0.72)],
          stops: const [0, 0.5, 1],
        ).createShader(head),
    );
    canvas.save();
    canvas.clipPath(face);
    // Sotto la tesa gli occhi restano in ombra.
    final brim = switch (look.hat) {
      AvatarHead.fedora ||
      AvatarHead.wideBrim ||
      AvatarHead.borsalino ||
      AvatarHead.homburg ||
      AvatarHead.pearlFedora ||
      AvatarHead.morettiFedora ||
      AvatarHead.morettiHomburg => 0.42,
      AvatarHead.panama || AvatarHead.trilby || AvatarHead.boater || AvatarHead.morettiPanama || AvatarHead.porkPie => 0.3,
      AvatarHead.bowler || AvatarHead.coppola || AvatarHead.topHat || AvatarHead.cloche || AvatarHead.fulmineCap => 0.32,
      AvatarHead.beret => 0.12,
      _ => 0.0,
    };
    if (brim > 0) {
      canvas.drawRect(
        const Rect.fromLTRB(-0.2, -1.1, 0.2, -0.82),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withValues(alpha: brim + 0.3), Colors.transparent],
          ).createShader(const Rect.fromLTRB(-0.2, -0.97, 0.2, -0.82)),
      );
    }
    final mark = look.base.mark;
    if (mark == FaceMark.stubble || mark == FaceMark.goatee) {
      canvas.drawPath(
        Path()
          ..moveTo(-0.15, -0.82)
          ..quadraticBezierTo(-0.1, -0.76, 0, -0.77)
          ..quadraticBezierTo(0.1, -0.76, 0.15, -0.82)
          ..lineTo(0.15, -0.6)
          ..lineTo(-0.15, -0.6)
          ..close(),
        Paint()..color = const Color(0xFF14100E).withValues(alpha: mark == FaceMark.stubble ? 0.4 : 0.22),
      );
    }
    if (mark == FaceMark.fullBeard || mark == FaceMark.muttonChops) {
      // La barba piena copre la mascella; i basettoni lasciano il mento nudo.
      final beard = Paint()..color = _dark(_hairColor(look), 0.05);
      final full = mark == FaceMark.fullBeard;
      final path = Path()
        ..moveTo(-0.17, -0.9)
        ..lineTo(-0.13, -0.9)
        ..quadraticBezierTo(-0.12, -0.8, -0.07, -0.79)
        ..lineTo(full ? 0.07 : -0.05, -0.79)
        ..quadraticBezierTo(0.12, -0.8, 0.13, -0.9)
        ..lineTo(0.17, -0.9)
        ..lineTo(0.17, -0.6)
        ..lineTo(-0.17, -0.6)
        ..close();
      if (!full) {
        // Il mento resta scoperto, sotto la bocca.
        path.addOval(Rect.fromCenter(center: const Offset(0, -0.71), width: 0.13, height: 0.13));
        path.fillType = PathFillType.evenOdd;
      }
      canvas.drawPath(path, beard);
      if (full) {
        // La bocca si apre nella barba.
        canvas.drawOval(
          Rect.fromCenter(center: const Offset(0, -0.758), width: 0.07, height: 0.022),
          Paint()..color = _dark(skin, 0.45),
        );
      }
      final grain = Paint()
        ..color = Colors.white.withValues(alpha: 0.08)
        ..strokeWidth = 0.006;
      for (var x = -0.15; x < 0.16; x += 0.03) {
        canvas.drawLine(Offset(x, -0.82), Offset(x * 0.85, -0.7), grain);
      }
    }
    canvas.restore();

    // Gli occhi: un lampo di bianco e la pupilla che si sposta.
    final look1 = pose.glance.clamp(-1.0, 1.0);
    final white = Paint()..color = paper.withValues(alpha: 0.82);
    final pupil = Paint()..color = ink;
    final brow = Paint()
      ..color = _dark(_hairColor(look), 0.2)
      ..strokeWidth = 0.022
      ..strokeCap = StrokeCap.round;
    for (final x in [-0.065, 0.065]) {
      final eye = Offset(x + look1 * 0.006, -0.875);
      if (!look.glasses.dark) {
        canvas.drawOval(Rect.fromCenter(center: eye, width: 0.058, height: 0.024), white);
        canvas.drawCircle(eye.translate(look1 * 0.016, 0), 0.0125, pupil);
      }
      final inner = x < 0 ? 1.0 : -1.0;
      canvas.drawLine(Offset(x - inner * 0.035, -0.915), Offset(x + inner * 0.03, -0.905 + (look.dame ? -0.006 : 0.004)), brow);
    }
    // Il naso, solo un'ombra e un filo di luce.
    canvas.drawLine(
      const Offset(0.008, -0.865),
      const Offset(0.018, -0.8),
      Paint()
        ..color = _dark(skin, 0.6)
        ..strokeWidth = 0.018
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(const Offset(-0.006, -0.81), 0.008, Paint()..color = _bright(skin, 0.3).withValues(alpha: 0.7));
    // La bocca.
    final mouth = Paint()
      ..color = _dark(skin, 0.72)
      ..strokeWidth = 0.014
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(-0.035, -0.762), const Offset(0.035, -0.765), mouth);

    final dark = Paint()..color = _dark(_hairColor(look), 0.1);
    switch (mark) {
      case FaceMark.clean || FaceMark.stubble:
        break;
      case FaceMark.mustache:
        canvas.drawPath(
          Path()
            ..moveTo(0, -0.79)
            ..quadraticBezierTo(-0.05, -0.8, -0.075, -0.765)
            ..quadraticBezierTo(-0.04, -0.775, 0, -0.772)
            ..quadraticBezierTo(0.04, -0.775, 0.075, -0.765)
            ..quadraticBezierTo(0.05, -0.8, 0, -0.79)
            ..close(),
          dark,
        );
      case FaceMark.lips:
        canvas.drawOval(
          Rect.fromCenter(center: const Offset(0, -0.763), width: 0.08, height: 0.028),
          Paint()..color = const Color(0xFFB8202E),
        );
        canvas.drawOval(
          Rect.fromCenter(center: const Offset(-0.01, -0.768), width: 0.03, height: 0.008),
          Paint()..color = Colors.white.withValues(alpha: 0.35),
        );
      case FaceMark.scar:
        final scar = Paint()
          ..color = _bright(skin, 0.55).withValues(alpha: 0.85)
          ..strokeWidth = 0.011
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(const Offset(0.085, -0.9), const Offset(0.115, -0.8), scar);
        for (final y in [-0.875, -0.85, -0.825]) {
          final x = 0.085 + (y + 0.9) * 0.3;
          canvas.drawLine(Offset(x - 0.015, y), Offset(x + 0.017, y - 0.006), scar);
        }
      case FaceMark.goatee:
        canvas.drawPath(
          Path()
            ..moveTo(-0.03, -0.745)
            ..quadraticBezierTo(0, -0.75, 0.03, -0.745)
            ..lineTo(0.018, -0.69)
            ..quadraticBezierTo(0, -0.675, -0.018, -0.69)
            ..close(),
          dark,
        );
        canvas.drawLine(
          const Offset(-0.05, -0.783),
          const Offset(0.05, -0.783),
          Paint()
            ..color = dark.color
            ..strokeWidth = 0.012
            ..strokeCap = StrokeCap.round,
        );
      case FaceMark.mole:
        canvas.drawCircle(const Offset(0.07, -0.79), 0.01, Paint()..color = const Color(0xFF1A0E0A));
      case FaceMark.pencil:
        // Il baffetto a matita: sottile, ma con un filo di luce sotto che lo
        // stacca dalla pelle anche nel ritratto piccolo.
        final line = Paint()
          ..color = _dark(_hairColor(look), 0.3)
          ..strokeWidth = 0.014
          ..strokeCap = StrokeCap.round;
        final lift = Paint()
          ..color = _bright(skin, 0.35).withValues(alpha: 0.55)
          ..strokeWidth = 0.008
          ..strokeCap = StrokeCap.round;
        for (final side in [-1.0, 1.0]) {
          canvas.drawLine(Offset(side * 0.058, -0.774), Offset(side * 0.008, -0.787), lift);
          canvas.drawLine(Offset(side * 0.06, -0.782), Offset(side * 0.008, -0.792), line);
        }
      case FaceMark.handlebar:
        // A manubrio: le punte arricciate all'insù.
        final curl = Paint()
          ..color = dark.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.016
          ..strokeCap = StrokeCap.round;
        for (final side in [-1.0, 1.0]) {
          canvas.drawPath(
            Path()
              ..moveTo(0, -0.787)
              ..quadraticBezierTo(side * 0.06, -0.79, side * 0.09, -0.77)
              ..quadraticBezierTo(side * 0.115, -0.785, side * 0.1, -0.81),
            curl,
          );
        }
      case FaceMark.walrus:
        // A tricheco: folti, scendono sopra il labbro.
        canvas.drawPath(
          Path()
            ..moveTo(-0.075, -0.75)
            ..quadraticBezierTo(-0.07, -0.8, 0, -0.8)
            ..quadraticBezierTo(0.07, -0.8, 0.075, -0.75)
            ..quadraticBezierTo(0.04, -0.762, 0, -0.757)
            ..quadraticBezierTo(-0.04, -0.762, -0.075, -0.75)
            ..close(),
          dark,
        );
      case FaceMark.imperial:
        // All'imperiale: baffi folti con le punte cerate all'insù e il
        // pizzetto sotto il labbro.
        canvas.drawPath(
          Path()
            ..moveTo(0, -0.796)
            ..quadraticBezierTo(-0.06, -0.8, -0.085, -0.785)
            ..quadraticBezierTo(-0.04, -0.77, 0, -0.774)
            ..quadraticBezierTo(0.04, -0.77, 0.085, -0.785)
            ..quadraticBezierTo(0.06, -0.8, 0, -0.796)
            ..close(),
          dark,
        );
        final wax = Paint()
          ..color = dark.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.012
          ..strokeCap = StrokeCap.round;
        for (final side in [-1.0, 1.0]) {
          canvas.drawPath(
            Path()
              ..moveTo(side * 0.08, -0.785)
              ..quadraticBezierTo(side * 0.12, -0.79, side * 0.125, -0.83),
            wax,
          );
        }
        canvas.drawPath(
          Path()
            ..moveTo(-0.018, -0.75)
            ..lineTo(0.018, -0.75)
            ..lineTo(0, -0.695)
            ..close(),
          dark,
        );
      case FaceMark.chevron:
        // A spazzola: larghi e folti, tagliati dritti sul labbro.
        canvas.drawPath(
          Path()
            ..moveTo(-0.07, -0.766)
            ..lineTo(-0.055, -0.8)
            ..quadraticBezierTo(0, -0.81, 0.055, -0.8)
            ..lineTo(0.07, -0.766)
            ..close(),
          dark,
        );
        canvas.drawLine(
          const Offset(-0.04, -0.795),
          const Offset(0.03, -0.798),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.12)
            ..strokeWidth = 0.006,
        );
      case FaceMark.horseshoe:
        // A ferro di cavallo: i baffi e due strisce giù fino alla mascella.
        canvas.drawPath(
          Path()
            ..moveTo(-0.065, -0.8)
            ..quadraticBezierTo(0, -0.81, 0.065, -0.8)
            ..lineTo(0.068, -0.7)
            ..lineTo(0.046, -0.7)
            ..lineTo(0.044, -0.774)
            ..quadraticBezierTo(0, -0.782, -0.044, -0.774)
            ..lineTo(-0.046, -0.7)
            ..lineTo(-0.068, -0.7)
            ..close(),
          dark,
        );
      case FaceMark.vandyke:
        // Alla moschettiera: baffetti all'insù e un pizzo a punta, staccati.
        final curl = Paint()
          ..color = dark.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.014
          ..strokeCap = StrokeCap.round;
        for (final side in [-1.0, 1.0]) {
          canvas.drawPath(
            Path()
              ..moveTo(side * 0.01, -0.789)
              ..quadraticBezierTo(side * 0.05, -0.79, side * 0.08, -0.805),
            curl,
          );
        }
        canvas.drawPath(
          Path()
            ..moveTo(-0.032, -0.742)
            ..quadraticBezierTo(0, -0.75, 0.032, -0.742)
            ..lineTo(0, -0.655)
            ..close(),
          dark,
        );
      case FaceMark.muttonChops || FaceMark.fullBeard:
        // I baffi che si uniscono alla barba (disegnata sotto la pelle).
        canvas.drawPath(
          Path()
            ..moveTo(-0.08, -0.77)
            ..quadraticBezierTo(-0.06, -0.805, 0, -0.8)
            ..quadraticBezierTo(0.06, -0.805, 0.08, -0.77)
            ..quadraticBezierTo(0.04, -0.778, 0, -0.774)
            ..quadraticBezierTo(-0.04, -0.778, -0.08, -0.77)
            ..close(),
          dark,
        );
    }
  }

  static void _hairFront(Canvas canvas, AvatarLook look) {
    final hair = Paint()..color = _hairColor(look);
    final shine = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.014
      ..strokeCap = StrokeCap.round;
    switch (look.hat) {
      case AvatarHead.slicked:
        canvas.drawPath(
          Path()
            ..moveTo(-0.168, -0.86)
            ..quadraticBezierTo(-0.18, -1.1, 0.02, -1.095)
            ..quadraticBezierTo(0.19, -1.09, 0.168, -0.86)
            ..quadraticBezierTo(0.15, -0.97, 0.05, -0.985)
            ..quadraticBezierTo(-0.1, -1.0, -0.168, -0.86)
            ..close(),
          hair,
        );
        canvas.drawArc(Rect.fromCenter(center: const Offset(0.0, -0.99), width: 0.22, height: 0.12), pi * 1.1, pi * 0.55, false, shine);
      case AvatarHead.bob:
        canvas.drawPath(
          Path()
            ..moveTo(-0.19, -0.8)
            ..quadraticBezierTo(-0.21, -1.085, 0, -1.085)
            ..quadraticBezierTo(0.21, -1.085, 0.19, -0.8)
            ..quadraticBezierTo(0.15, -0.94, 0.04, -0.96)
            ..quadraticBezierTo(-0.06, -0.93, -0.1, -0.97)
            ..quadraticBezierTo(-0.16, -0.92, -0.19, -0.8)
            ..close(),
          hair,
        );
        canvas.drawArc(Rect.fromCenter(center: const Offset(-0.04, -1.0), width: 0.24, height: 0.13), pi * 1.1, pi * 0.5, false, shine);
      case AvatarHead.bun:
        canvas.drawPath(
          Path()
            ..moveTo(-0.17, -0.86)
            ..quadraticBezierTo(-0.18, -1.09, 0, -1.09)
            ..quadraticBezierTo(0.18, -1.09, 0.17, -0.86)
            ..quadraticBezierTo(0.12, -0.98, 0, -0.99)
            ..quadraticBezierTo(-0.12, -0.98, -0.17, -0.86)
            ..close(),
          hair,
        );
        canvas.drawLine(
          const Offset(-0.07, -1.14),
          const Offset(0.09, -1.07),
          Paint()
            ..color = gold
            ..strokeWidth = 0.014
            ..strokeCap = StrokeCap.round,
        );
      case AvatarHead.cloche:
        // I riccioli che escono dalla campana del cappello.
        for (final side in [-1.0, 1.0]) {
          canvas.drawOval(Rect.fromCenter(center: Offset(side * 0.165, -0.86), width: 0.07, height: 0.1), hair);
          canvas.drawOval(Rect.fromCenter(center: Offset(side * 0.17, -0.79), width: 0.06, height: 0.07), hair);
        }
      case AvatarHead.wideBrim:
        canvas.drawPath(
          Path()
            ..moveTo(-0.2, -0.78)
            ..quadraticBezierTo(-0.2, -0.95, -0.12, -0.97)
            ..lineTo(-0.15, -0.8)
            ..close()
            ..moveTo(0.2, -0.78)
            ..quadraticBezierTo(0.2, -0.95, 0.12, -0.97)
            ..lineTo(0.15, -0.8)
            ..close(),
          hair,
        );
      case AvatarHead.fedora ||
          AvatarHead.bowler ||
          AvatarHead.coppola ||
          AvatarHead.borsalino ||
          AvatarHead.panama ||
          AvatarHead.trilby ||
          AvatarHead.homburg ||
          AvatarHead.boater ||
          AvatarHead.topHat ||
          AvatarHead.porkPie ||
          AvatarHead.beret ||
          AvatarHead.pearlFedora ||
          AvatarHead.morettiFedora ||
          AvatarHead.morettiPanama ||
          AvatarHead.morettiHomburg ||
          AvatarHead.fulmineCap:
        // Le basette sotto il cappello.
        canvas.drawRect(const Rect.fromLTRB(-0.165, -0.95, -0.14, -0.86), hair);
        canvas.drawRect(const Rect.fromLTRB(0.14, -0.95, 0.165, -0.86), hair);
    }
  }

  static void _glasses(Canvas canvas, AvatarLook look, CharacterPose pose) {
    final frame = Paint()
      ..color = const Color(0xFFD9C9A8).withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.012;
    final glint = Paint()..color = Colors.white.withValues(alpha: 0.7);
    switch (look.glasses) {
      case AvatarGlasses.none:
        break;
      case AvatarGlasses.round:
        for (final x in [-0.065, 0.065]) {
          canvas.drawCircle(Offset(x, -0.875), 0.046, frame);
          canvas.drawCircle(Offset(x - 0.018, -0.89), 0.009, glint);
        }
        canvas.drawLine(const Offset(-0.02, -0.88), const Offset(0.02, -0.88), frame);
      case AvatarGlasses.monocle:
        canvas.drawCircle(const Offset(0.065, -0.875), 0.05, frame..color = const Color(0xFFE2C46A));
        canvas.drawCircle(const Offset(0.048, -0.892), 0.009, glint);
        canvas.drawPath(
          Path()
            ..moveTo(0.11, -0.86)
            ..quadraticBezierTo(0.2, -0.72, 0.16, -0.5),
          frame..strokeWidth = 0.007,
        );
      case AvatarGlasses.shades:
        final lens = Paint()..color = const Color(0xFF0B0B10);
        for (final x in [-0.068, 0.068]) {
          final r = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x, -0.872), width: 0.105, height: 0.064), const Radius.circular(0.025));
          canvas.drawRRect(r, lens);
          canvas.drawRRect(r, frame..color = const Color(0xFF3A3A40)..strokeWidth = 0.01);
          canvas.drawLine(Offset(x - 0.035, -0.885), Offset(x - 0.01, -0.893), Paint()
            ..color = Colors.white.withValues(alpha: 0.55)
            ..strokeWidth = 0.01
            ..strokeCap = StrokeCap.round);
        }
        canvas.drawLine(const Offset(-0.016, -0.88), const Offset(0.016, -0.88), frame);
      case AvatarGlasses.pinceNez:
        final wire = frame..color = const Color(0xFFE2C46A);
        for (final x in [-0.06, 0.06]) {
          canvas.drawOval(Rect.fromCenter(center: Offset(x, -0.872), width: 0.07, height: 0.055), wire);
          canvas.drawCircle(Offset(x - 0.014, -0.885), 0.007, glint);
        }
        canvas.drawArc(Rect.fromCenter(center: const Offset(0, -0.875), width: 0.05, height: 0.03), pi, pi, false, wire);
        canvas.drawPath(
          Path()
            ..moveTo(-0.095, -0.865)
            ..quadraticBezierTo(-0.18, -0.7, -0.12, -0.52),
          Paint()
            ..color = const Color(0xFFE2C46A).withValues(alpha: 0.7)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.006,
        );
      case AvatarGlasses.tortoise:
        final shell = Paint()
          ..color = const Color(0xFF6B3A1E)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.022;
        final fleck = Paint()
          ..color = const Color(0xFFC07A3A).withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.007;
        for (final x in [-0.066, 0.066]) {
          final r = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x, -0.874), width: 0.1, height: 0.075), const Radius.circular(0.03));
          canvas.drawRRect(r, shell);
          canvas.drawRRect(r, fleck);
          canvas.drawCircle(Offset(x - 0.02, -0.89), 0.008, glint);
        }
        canvas.drawLine(const Offset(-0.016, -0.885), const Offset(0.016, -0.885), shell);
      case AvatarGlasses.aviator:
        final lens = Paint()..color = const Color(0xFF3B2A18).withValues(alpha: 0.85);
        final wire = Paint()
          ..color = const Color(0xFFE2C46A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.008;
        final shine = Paint()
          ..color = Colors.white.withValues(alpha: 0.55)
          ..strokeWidth = 0.008
          ..strokeCap = StrokeCap.round;
        for (final side in [-1.0, 1.0]) {
          final drop = Path()
            ..moveTo(side * 0.015, -0.9)
            ..lineTo(side * 0.118, -0.9)
            ..quadraticBezierTo(side * 0.125, -0.84, side * 0.075, -0.835)
            ..quadraticBezierTo(side * 0.02, -0.835, side * 0.015, -0.9)
            ..close();
          canvas.drawPath(drop, lens);
          canvas.drawPath(drop, wire);
          canvas.drawLine(Offset(side * 0.05, -0.89), Offset(side * 0.08, -0.885), shine);
        }
        canvas.drawLine(const Offset(-0.015, -0.905), const Offset(0.015, -0.905), wire);
      case AvatarGlasses.goldRims:
        // Tonde e sottili, d'oro: il filo prende la luce in alto.
        final wire = Paint()
          ..color = const Color(0xFFE2C46A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.009;
        for (final x in [-0.064, 0.064]) {
          final r = Rect.fromCenter(center: Offset(x, -0.874), width: 0.085, height: 0.075);
          canvas.drawOval(r, Paint()..color = Colors.white.withValues(alpha: 0.08));
          canvas.drawOval(r, wire);
          canvas.drawArc(r, pi * 1.1, pi * 0.5, false, Paint()
            ..color = const Color(0xFFFFF0B8)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.005);
          canvas.drawCircle(Offset(x - 0.018, -0.89), 0.007, glint);
        }
        canvas.drawArc(Rect.fromCenter(center: const Offset(0, -0.874), width: 0.045, height: 0.03), pi, pi, false, wire);
      case AvatarGlasses.browline:
        // Da ragioniere: la barra nera sopra, il filo sotto.
        final bar = Paint()
          ..color = const Color(0xFF141216)
          ..strokeWidth = 0.024
          ..strokeCap = StrokeCap.round;
        final wire = Paint()
          ..color = const Color(0xFFC8C2B8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.008;
        for (final x in [-0.066, 0.066]) {
          final r = Rect.fromCenter(center: Offset(x, -0.872), width: 0.1, height: 0.07);
          canvas.drawArc(r, 0, pi, false, wire);
          canvas.drawLine(Offset(x - 0.05, -0.894), Offset(x + 0.05, -0.894), bar);
          canvas.drawCircle(Offset(x - 0.02, -0.878), 0.007, glint);
        }
        canvas.drawLine(const Offset(-0.016, -0.89), const Offset(0.016, -0.89), wire);
      case AvatarGlasses.catEye:
        // A gatto: le punte all'insù, nere, con un punto d'oro all'angolo.
        final frame = Paint()..color = const Color(0xFF1A1014);
        for (final side in [-1.0, 1.0]) {
          final outer = Path()
            ..moveTo(side * 0.018, -0.885)
            ..quadraticBezierTo(side * 0.06, -0.905, side * 0.13, -0.92)
            ..quadraticBezierTo(side * 0.125, -0.85, side * 0.075, -0.845)
            ..quadraticBezierTo(side * 0.02, -0.845, side * 0.018, -0.885)
            ..close();
          canvas.drawPath(outer, frame);
          canvas.drawOval(
            Rect.fromCenter(center: Offset(side * 0.068, -0.872), width: 0.07, height: 0.042),
            Paint()..color = const Color(0xFF6E5A54).withValues(alpha: 0.6),
          );
          canvas.drawCircle(Offset(side * 0.118, -0.906), 0.007, Paint()..color = gold);
          canvas.drawCircle(Offset(side * 0.055, -0.882), 0.006, glint);
        }
      case AvatarGlasses.delacroixShades:
        // Ovali, fumé, montatura d'oro; la luna della casa sulla cerniera.
        final wire = Paint()
          ..color = const Color(0xFFE2C46A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.009;
        for (final side in [-1.0, 1.0]) {
          final r = Rect.fromCenter(center: Offset(side * 0.068, -0.874), width: 0.105, height: 0.068);
          canvas.drawOval(
            r,
            Paint()
              ..shader = const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0C0A12), Color(0xFF3A2E4E)],
              ).createShader(r),
          );
          canvas.drawOval(r, wire);
          canvas.drawLine(Offset(side * 0.045, -0.889), Offset(side * 0.07, -0.894), Paint()
            ..color = Colors.white.withValues(alpha: 0.5)
            ..strokeWidth = 0.009
            ..strokeCap = StrokeCap.round);
        }
        canvas.drawLine(const Offset(-0.016, -0.882), const Offset(0.016, -0.882), wire);
        brandMark(canvas, ShopBrand.delacroix, const Offset(0.128, -0.884), 0.014, color: const Color(0xFFE2C46A));
      case AvatarGlasses.ricciMonocle:
        // Il monocolo d'oro grosso, un brillante sul bordo e la catena.
        final c = const Offset(0.065, -0.875);
        canvas.drawCircle(c, 0.05, Paint()..color = Colors.white.withValues(alpha: 0.1));
        canvas.drawCircle(c, 0.05, Paint()
          ..color = const Color(0xFFB8862E)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.02);
        canvas.drawCircle(c, 0.05, Paint()
          ..color = gold
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.011);
        canvas.drawArc(Rect.fromCircle(center: c, radius: 0.05), pi * 1.05, pi * 0.5, false, Paint()
          ..color = const Color(0xFFFFF4D0)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.005);
        canvas.drawCircle(const Offset(0.045, -0.893), 0.009, glint);
        final chain = Paint()
          ..color = gold
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.008;
        canvas.drawPath(
          Path()
            ..moveTo(0.11, -0.855)
            ..quadraticBezierTo(0.21, -0.72, 0.17, -0.5),
          chain,
        );
        _diamond(canvas, const Offset(0.112, -0.85), 0.014);
    }
  }

  static const _felt = Color(0xFF1C1A1E);

  static void _hat(Canvas canvas, AvatarLook look, Paint paint, {required bool silhouette}) {
    final felt = silhouette ? paint : (Paint()..color = _felt);
    final accent = look.outfit.accent;
    final band = silhouette ? paint : (Paint()..color = _dark(accent, 0.35));
    final top = silhouette
        ? paint
        : (Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF3A3640), _felt],
            ).createShader(const Rect.fromLTRB(-0.2, -1.22, 0.2, -0.96)));
    void brim(double width, double height, {double tilt = 0, double y = -0.965}) {
      canvas.save();
      canvas.translate(0, y);
      canvas.rotate(tilt);
      final r = Rect.fromCenter(center: Offset.zero, width: width, height: height);
      canvas.drawOval(r, felt);
      if (!silhouette) {
        canvas.drawArc(
          r.deflate(0.004),
          0.15,
          pi - 0.3,
          false,
          Paint()
            ..color = Colors.black.withValues(alpha: 0.6)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.014,
        );
        canvas.drawArc(
          r,
          pi + 0.2,
          pi - 0.4,
          false,
          Paint()
            ..color = rim.withValues(alpha: 0.5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.008,
        );
      }
      canvas.restore();
    }

    switch (look.hat) {
      case AvatarHead.fedora:
        brim(0.62, 0.09, tilt: -0.04);
        canvas.drawPath(
          Path()
            ..moveTo(-0.18, -0.97)
            ..lineTo(-0.165, -1.15)
            ..quadraticBezierTo(-0.1, -1.2, -0.02, -1.16)
            ..quadraticBezierTo(0, -1.15, 0.02, -1.16)
            ..quadraticBezierTo(0.1, -1.2, 0.165, -1.15)
            ..lineTo(0.18, -0.97)
            ..close(),
          top,
        );
        canvas.drawRect(const Rect.fromLTRB(-0.179, -1.03, 0.179, -0.985), band);
        if (!silhouette) {
          canvas.drawLine(
            const Offset(0, -1.15),
            const Offset(0, -1.06),
            Paint()
              ..color = Colors.black.withValues(alpha: 0.45)
              ..strokeWidth = 0.014,
          );
        }
      case AvatarHead.wideBrim:
        brim(0.84, 0.12, tilt: -0.1, y: -0.99);
        canvas.save();
        canvas.translate(0, -0.99);
        canvas.rotate(-0.1);
        canvas.drawPath(
          Path()
            ..moveTo(-0.15, 0)
            ..quadraticBezierTo(-0.15, -0.15, 0, -0.15)
            ..quadraticBezierTo(0.15, -0.15, 0.15, 0)
            ..close(),
          top,
        );
        canvas.drawRect(const Rect.fromLTRB(-0.148, -0.055, 0.148, -0.015), Paint()..color = silhouette ? paint.color : accent);
        canvas.restore();
      case AvatarHead.bowler:
        brim(0.46, 0.075, y: -0.975);
        canvas.drawPath(
          Path()
            ..moveTo(-0.17, -0.975)
            ..quadraticBezierTo(-0.18, -1.19, 0, -1.19)
            ..quadraticBezierTo(0.18, -1.19, 0.17, -0.975)
            ..close(),
          top,
        );
        canvas.drawRect(const Rect.fromLTRB(-0.172, -1.02, 0.172, -0.985), band);
      case AvatarHead.coppola:
        final cap = silhouette ? paint : (Paint()..color = const Color(0xFF4A3D30));
        canvas.drawPath(
          Path()
            ..moveTo(-0.19, -0.95)
            ..quadraticBezierTo(-0.22, -1.11, 0, -1.12)
            ..quadraticBezierTo(0.22, -1.11, 0.19, -0.95)
            ..close(),
          cap,
        );
        if (!silhouette) {
          final weave = Paint()
            ..color = const Color(0xFF8A7458).withValues(alpha: 0.35)
            ..strokeWidth = 0.008;
          for (var x = -0.16; x < 0.17; x += 0.05) {
            canvas.drawLine(Offset(x, -1.1), Offset(x * 1.1, -0.95), weave);
          }
        }
        canvas.drawPath(
          Path()
            ..moveTo(-0.16, -0.955)
            ..quadraticBezierTo(0, -0.88, 0.16, -0.955)
            ..quadraticBezierTo(0, -0.99, -0.16, -0.955)
            ..close(),
          silhouette ? paint : (Paint()..color = const Color(0xFF2E251D)),
        );
      case AvatarHead.borsalino ||
          AvatarHead.panama ||
          AvatarHead.trilby ||
          AvatarHead.pearlFedora ||
          AvatarHead.morettiFedora ||
          AvatarHead.morettiPanama:
        // Il fedora di feltro buono (o di paglia): stessa forma, altra stoffa.
        final (shade, light, width) = switch (look.hat) {
          AvatarHead.borsalino => (const Color(0xFF5A4E44), const Color(0xFF85776A), 0.66),
          AvatarHead.panama => (const Color(0xFFD9C89E), const Color(0xFFF2E6C4), 0.6),
          AvatarHead.pearlFedora => (const Color(0xFF8E8C88), const Color(0xFFCAC6BE), 0.62),
          AvatarHead.morettiFedora => (const Color(0xFF16141A), const Color(0xFF4A4452), 0.66),
          AvatarHead.morettiPanama => (const Color(0xFFE2D2A2), const Color(0xFFFAF0D2), 0.66),
          _ => (const Color(0xFF3E2E22), const Color(0xFF6A5040), 0.48),
        };
        final cloth = silhouette ? paint : (Paint()..color = shade);
        final crown = silhouette
            ? paint
            : (Paint()
                ..shader = LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [light, shade],
                ).createShader(const Rect.fromLTRB(-0.2, -1.2, 0.2, -0.96)));
        canvas.save();
        canvas.translate(0, -0.965);
        canvas.rotate(look.hat == AvatarHead.trilby ? -0.09 : -0.04);
        final r = Rect.fromCenter(center: Offset.zero, width: width, height: 0.09);
        canvas.drawOval(r, cloth);
        if (!silhouette) {
          canvas.drawArc(
            r,
            pi + 0.2,
            pi - 0.4,
            false,
            Paint()
              ..color = rim.withValues(alpha: 0.5)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.008,
          );
        }
        canvas.restore();
        canvas.drawPath(
          Path()
            ..moveTo(-0.175, -0.97)
            ..lineTo(-0.16, -1.14)
            ..quadraticBezierTo(-0.1, -1.19, -0.02, -1.15)
            ..quadraticBezierTo(0, -1.14, 0.02, -1.15)
            ..quadraticBezierTo(0.1, -1.19, 0.16, -1.14)
            ..lineTo(0.175, -0.97)
            ..close(),
          crown,
        );
        canvas.drawRect(
          const Rect.fromLTRB(-0.176, -1.04, 0.176, -0.985),
          silhouette
              ? paint
              : (Paint()
                  ..color = switch (look.hat) {
                    AvatarHead.panama || AvatarHead.pearlFedora => _felt,
                    AvatarHead.morettiFedora => const Color(0xFF2A0E12),
                    AvatarHead.morettiPanama => const Color(0xFF15233F),
                    _ => _dark(accent, 0.55),
                  }),
        );
        if (!silhouette) {
          if (look.hat == AvatarHead.morettiPanama) {
            // Il nastro a righe della casa.
            canvas.drawRect(const Rect.fromLTRB(-0.176, -1.019, 0.176, -1.006), Paint()..color = const Color(0xFFA81C2C));
          }
          if (look.hat == AvatarHead.morettiFedora) {
            // Il bordino d'oro sul nastro.
            final trim = Paint()
              ..color = gold.withValues(alpha: 0.8)
              ..strokeWidth = 0.005;
            canvas.drawLine(const Offset(-0.176, -1.038), const Offset(0.176, -1.038), trim);
            canvas.drawLine(const Offset(-0.176, -0.987), const Offset(0.176, -0.987), trim);
          }
          // La piega del cocuzzolo, presa dalla luce.
          canvas.drawLine(
            const Offset(-0.06, -1.15),
            const Offset(-0.1, -1.06),
            Paint()
              ..color = Colors.white.withValues(alpha: 0.12)
              ..strokeWidth = 0.012,
          );
          if (look.hat == AvatarHead.morettiFedora || look.hat == AvatarHead.morettiPanama) {
            _hatPin(canvas, ShopBrand.moretti);
          }
        }
      case AvatarHead.homburg:
        // Rigido, la tesa arrotolata e il solco nel mezzo.
        brim(0.54, 0.085, y: -0.968);
        if (!silhouette) {
          canvas.drawArc(
            Rect.fromCenter(center: const Offset(0, -0.97), width: 0.54, height: 0.085),
            pi * 0.05,
            pi * 0.9,
            false,
            Paint()
              ..color = _bright(_felt, 0.3)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.014,
          );
        }
        canvas.drawPath(
          Path()
            ..moveTo(-0.17, -0.97)
            ..lineTo(-0.16, -1.16)
            ..quadraticBezierTo(-0.08, -1.19, 0, -1.15)
            ..quadraticBezierTo(0.08, -1.19, 0.16, -1.16)
            ..lineTo(0.17, -0.97)
            ..close(),
          top,
        );
        canvas.drawRect(const Rect.fromLTRB(-0.171, -1.03, 0.171, -0.985), silhouette ? paint : (Paint()..color = const Color(0xFF0C0B0D)));
      case AvatarHead.boater:
        // La paglietta: piatta, di paglia, col nastro.
        final straw = silhouette ? paint : (Paint()..color = const Color(0xFFE0CB8C));
        canvas.drawOval(Rect.fromCenter(center: const Offset(0, -0.97), width: 0.56, height: 0.07), straw);
        canvas.drawRect(const Rect.fromLTRB(-0.17, -1.09, 0.17, -0.97), straw);
        canvas.drawOval(
          Rect.fromCenter(center: const Offset(0, -1.09), width: 0.34, height: 0.05),
          silhouette ? paint : (Paint()..color = const Color(0xFFF0DFA6)),
        );
        if (!silhouette) {
          canvas.drawRect(const Rect.fromLTRB(-0.17, -1.035, 0.17, -0.995), Paint()..color = _felt);
          canvas.drawRect(const Rect.fromLTRB(-0.17, -1.025, 0.17, -1.005), Paint()..color = const Color(0xFF8E1D28));
        }
      case AvatarHead.topHat:
        // Il cilindro della prima alla Scala.
        brim(0.48, 0.07, y: -0.972);
        canvas.drawPath(
          Path()
            ..moveTo(-0.15, -0.975)
            ..lineTo(-0.165, -1.3)
            ..lineTo(0.165, -1.3)
            ..lineTo(0.15, -0.975)
            ..close(),
          top,
        );
        canvas.drawOval(
          Rect.fromCenter(center: const Offset(0, -1.3), width: 0.33, height: 0.05),
          silhouette ? paint : (Paint()..color = const Color(0xFF2A2730)),
        );
        canvas.drawRect(const Rect.fromLTRB(-0.152, -1.04, 0.152, -0.99), band);
      case AvatarHead.morettiHomburg:
        // L'homburg da sera: nero lucido, nastro di raso e la spilla d'oro.
        brim(0.56, 0.088, y: -0.968);
        if (!silhouette) {
          canvas.drawArc(
            Rect.fromCenter(center: const Offset(0, -0.97), width: 0.56, height: 0.088),
            pi * 0.05,
            pi * 0.9,
            false,
            Paint()
              ..color = const Color(0xFF6A6470)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.012,
          );
        }
        canvas.drawPath(
          Path()
            ..moveTo(-0.17, -0.97)
            ..lineTo(-0.16, -1.17)
            ..quadraticBezierTo(-0.08, -1.2, 0, -1.16)
            ..quadraticBezierTo(0.08, -1.2, 0.16, -1.17)
            ..lineTo(0.17, -0.97)
            ..close(),
          silhouette
              ? paint
              : (Paint()
                  ..shader = const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF4A4452), Color(0xFF0E0D10), Color(0xFF1E1C22)],
                  ).createShader(const Rect.fromLTRB(-0.2, -1.2, 0.2, -0.96))),
        );
        const satin = Rect.fromLTRB(-0.171, -1.04, 0.171, -0.985);
        if (silhouette) {
          canvas.drawRect(satin, paint);
        } else {
          canvas.drawRect(
            satin,
            Paint()
              ..shader = const LinearGradient(
                colors: [Color(0xFF0A090C), Color(0xFF5A5462), Color(0xFF0A090C), Color(0xFF2A2830)],
                stops: [0, 0.3, 0.6, 1],
              ).createShader(satin),
          );
          canvas.drawLine(
            const Offset(-0.03, -1.16),
            const Offset(-0.07, -1.06),
            Paint()
              ..color = Colors.white.withValues(alpha: 0.18)
              ..strokeWidth = 0.012,
          );
          _hatPin(canvas, ShopBrand.moretti);
        }
      case AvatarHead.porkPie:
        // Il pork pie: cupola bassa e piatta, la tesa corta.
        final cloth = silhouette ? paint : (Paint()..color = const Color(0xFF4A3A2C));
        brim(0.46, 0.07, y: -0.968);
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            const Rect.fromLTRB(-0.165, -1.1, 0.165, -0.968),
            topLeft: const Radius.circular(0.03),
            topRight: const Radius.circular(0.03),
          ),
          cloth,
        );
        if (!silhouette) {
          canvas.drawOval(
            Rect.fromCenter(center: const Offset(0, -1.098), width: 0.27, height: 0.03),
            Paint()..color = const Color(0xFF2A2018),
          );
          canvas.drawRect(const Rect.fromLTRB(-0.166, -1.03, 0.166, -0.985), Paint()..color = _dark(accent, 0.45));
          canvas.drawLine(
            const Offset(-0.12, -1.08),
            const Offset(-0.12, -1.04),
            Paint()
              ..color = Colors.white.withValues(alpha: 0.12)
              ..strokeWidth = 0.014,
          );
        }
      case AvatarHead.beret:
        // Il basco, posato di sbieco, col picciolo.
        canvas.save();
        canvas.translate(0.02, -1.02);
        canvas.rotate(-0.16);
        final r = Rect.fromCenter(center: Offset.zero, width: 0.42, height: 0.16);
        canvas.drawOval(
          r,
          silhouette
              ? paint
              : (Paint()
                  ..shader = const RadialGradient(
                    center: Alignment(-0.4, -0.6),
                    colors: [Color(0xFF5A2430), Color(0xFF2A0E14)],
                  ).createShader(r)),
        );
        canvas.drawLine(
          const Offset(0, -0.075),
          const Offset(0.015, -0.11),
          Paint()
            ..color = silhouette ? paint.color : const Color(0xFF2A0E14)
            ..strokeWidth = 0.016
            ..strokeCap = StrokeCap.round,
        );
        if (!silhouette) {
          canvas.drawArc(
            r.deflate(0.01),
            pi * 1.1,
            pi * 0.6,
            false,
            Paint()
              ..color = Colors.white.withValues(alpha: 0.12)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.012,
          );
        }
        canvas.restore();
      case AvatarHead.cloche:
        // La cloche: una campana stretta sulla testa e un nastro col fiocco.
        final bell = Path()
          ..moveTo(-0.2, -0.88)
          ..quadraticBezierTo(-0.22, -1.17, 0, -1.17)
          ..quadraticBezierTo(0.22, -1.17, 0.2, -0.88)
          ..quadraticBezierTo(0.12, -0.94, 0, -0.945)
          ..quadraticBezierTo(-0.12, -0.94, -0.2, -0.88)
          ..close();
        canvas.drawPath(
          bell,
          silhouette
              ? paint
              : (Paint()
                  ..shader = const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF3E4A5C), Color(0xFF1C2230)],
                  ).createShader(const Rect.fromLTRB(-0.2, -1.17, 0.2, -0.88))),
        );
        if (!silhouette) {
          canvas.drawPath(
            Path()
              ..moveTo(-0.19, -0.99)
              ..quadraticBezierTo(0, -1.03, 0.19, -0.99)
              ..lineTo(0.195, -0.95)
              ..quadraticBezierTo(0, -0.99, -0.195, -0.95)
              ..close(),
            Paint()..color = accent,
          );
          for (final side in [-1.0, 1.0]) {
            canvas.drawOval(
              Rect.fromCenter(center: Offset(0.12 + side * 0.03, -0.985), width: 0.05, height: 0.03),
              Paint()..color = _dark(accent, 0.25),
            );
          }
          canvas.drawArc(
            Rect.fromCenter(center: const Offset(-0.03, -1.08), width: 0.26, height: 0.14),
            pi * 1.1,
            pi * 0.5,
            false,
            Paint()
              ..color = Colors.white.withValues(alpha: 0.14)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.012,
          );
        }
      case AvatarHead.fulmineCap:
        // Il berretto da ciclista: spicchi a due colori, la visiera corta
        // e il fulmine della casa davanti.
        final cap = Path()
          ..moveTo(-0.175, -0.96)
          ..quadraticBezierTo(-0.19, -1.13, 0, -1.135)
          ..quadraticBezierTo(0.19, -1.13, 0.175, -0.96)
          ..close();
        canvas.drawPath(cap, silhouette ? paint : (Paint()..color = const Color(0xFFF2E6CF)));
        if (!silhouette) {
          canvas.save();
          canvas.clipPath(cap);
          canvas.drawRect(const Rect.fromLTRB(-0.2, -1.14, -0.06, -0.95), Paint()..color = const Color(0xFF1D2C58));
          canvas.drawRect(const Rect.fromLTRB(0.06, -1.14, 0.2, -0.95), Paint()..color = const Color(0xFF1D2C58));
          canvas.drawRect(const Rect.fromLTRB(-0.2, -0.99, 0.2, -0.96), Paint()..color = const Color(0xFFE2563F));
          canvas.restore();
          brandMark(canvas, ShopBrand.fulmine, const Offset(0, -1.05), 0.035, color: const Color(0xFFE2563F));
        }
        canvas.drawPath(
          Path()
            ..moveTo(-0.13, -0.965)
            ..quadraticBezierTo(0, -1.0, 0.13, -0.965)
            ..lineTo(0.11, -0.925)
            ..quadraticBezierTo(0, -0.95, -0.11, -0.925)
            ..close(),
          silhouette ? paint : (Paint()..color = const Color(0xFF1D2C58)),
        );
      case AvatarHead.slicked || AvatarHead.bob || AvatarHead.bun:
        break;
    }
  }

  /// La spilla della casa sul nastro del cappello.
  static void _hatPin(Canvas canvas, ShopBrand brand) {
    const c = Offset(0.125, -1.012);
    canvas.drawCircle(c, 0.026, Paint()..color = const Color(0xFF8A5E1E));
    canvas.drawCircle(c, 0.022, Paint()..color = gold);
    brandMark(canvas, brand, c, 0.016, color: const Color(0xFF3A2410));
  }

  static void _mouthProp(Canvas canvas, AvatarLook look) {
    switch (look.accessory) {
      case AvatarAccessory.cigarette:
        canvas.drawLine(
          const Offset(0.03, -0.765),
          const Offset(0.14, -0.745),
          Paint()
            ..color = paper
            ..strokeWidth = 0.018
            ..strokeCap = StrokeCap.round,
        );
        canvas.drawCircle(const Offset(0.145, -0.744), 0.012, Paint()..color = ember);
      case AvatarAccessory.cigar:
        canvas.drawLine(
          const Offset(0.025, -0.765),
          const Offset(0.16, -0.735),
          Paint()
            ..color = const Color(0xFF5A3A22)
            ..strokeWidth = 0.032
            ..strokeCap = StrokeCap.round,
        );
        canvas.drawLine(
          const Offset(0.06, -0.757),
          const Offset(0.075, -0.754),
          Paint()
            ..color = const Color(0xFFC9A54E)
            ..strokeWidth = 0.034,
        );
        canvas.drawCircle(const Offset(0.165, -0.734), 0.016, Paint()..color = ember);
      case AvatarAccessory.cigaretteHolder:
        // Il bocchino lungo, nero, con l'anello d'oro e la sigaretta in cima.
        canvas.drawLine(
          const Offset(0.03, -0.765),
          const Offset(0.2, -0.8),
          Paint()
            ..color = const Color(0xFF111014)
            ..strokeWidth = 0.011
            ..strokeCap = StrokeCap.round,
        );
        canvas.drawLine(
          const Offset(0.04, -0.769),
          const Offset(0.19, -0.8),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.25)
            ..strokeWidth = 0.003,
        );
        canvas.drawLine(const Offset(0.165, -0.795), const Offset(0.175, -0.797), Paint()
          ..color = gold
          ..strokeWidth = 0.016);
        canvas.drawLine(
          const Offset(0.2, -0.8),
          const Offset(0.24, -0.809),
          Paint()
            ..color = paper
            ..strokeWidth = 0.014
            ..strokeCap = StrokeCap.round,
        );
        canvas.drawCircle(const Offset(0.245, -0.81), 0.009, Paint()..color = ember);
      case AvatarAccessory.toothpick:
        canvas.drawLine(
          const Offset(0.025, -0.763),
          const Offset(0.11, -0.735),
          Paint()
            ..color = const Color(0xFFE8D5A8)
            ..strokeWidth = 0.008
            ..strokeCap = StrokeCap.round,
        );
      case AvatarAccessory.pipe:
        canvas.drawLine(
          const Offset(0.025, -0.765),
          const Offset(0.11, -0.72),
          Paint()
            ..color = const Color(0xFF4A2A16)
            ..strokeWidth = 0.016
            ..strokeCap = StrokeCap.round,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(const Rect.fromLTRB(0.1, -0.77, 0.15, -0.69), const Radius.circular(0.018)),
          Paint()..color = const Color(0xFF5E3519),
        );
        canvas.drawOval(const Rect.fromLTRB(0.103, -0.776, 0.147, -0.762), Paint()..color = ember.withValues(alpha: 0.8));
      default:
        break;
    }
  }

  /// Il garofano rosso: all'occhiello di chi se lo può permettere, sul
  /// tavolo davanti a chi non c'è più.
  static void carnation(Canvas canvas, Offset at, double r, {double angle = 0, Color petals = const Color(0xFFD23246)}) {
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(angle);
    canvas.drawLine(
      Offset(0, r * 0.6),
      Offset(r * 0.3, r * 2.4),
      Paint()
        ..color = const Color(0xFF2F5A2A)
        ..strokeWidth = r * 0.3
        ..strokeCap = StrokeCap.round,
    );
    for (var i = 0; i < 7; i++) {
      final a = i * 2 * pi / 7;
      canvas.drawCircle(Offset(cos(a), sin(a)) * (r * 0.5), r * 0.55, Paint()..color = _dark(petals, 0.3));
    }
    canvas.drawCircle(Offset.zero, r * 0.55, Paint()..color = petals);
    canvas.drawCircle(Offset(-r * 0.2, -r * 0.2), r * 0.22, Paint()..color = _bright(petals, 0.4));
    canvas.restore();
  }

  /// Gli avambracci posati sul panno, le mani nella luce della lampada.
  /// Chi si alza tiene le mani puntate dove sono e porta su i gomiti.
  static void _forearms(Canvas canvas, AvatarLook look, CharacterPose pose, {required bool lit}) {
    final lift = -0.42 * pose.rise + pose.breath * 0.012;
    final coat = look.outfit.coat;
    final skin = look.base.skin;
    final apart = pose.hands % 3;
    final hands = switch (apart) {
      0 => const [Offset(-0.07, 0.085), Offset(0.07, 0.09)],
      1 => const [Offset(-0.2, 0.09), Offset(0.2, 0.09)],
      _ => const [Offset(-0.16, 0.09), Offset(0.1, 0.095)],
    };
    if (apart == 1) {
      // Due carte coperte tra le mani.
      for (final (i, dx) in [-0.05, 0.03].indexed) {
        canvas.save();
        canvas.translate(dx, 0.1);
        canvas.rotate(-0.25 + i * 0.4);
        final card = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: 0.1, height: 0.07), const Radius.circular(0.01));
        canvas.drawRRect(card.shift(const Offset(0, 0.01)), Paint()..color = Colors.black.withValues(alpha: 0.4));
        canvas.drawRRect(card, Paint()..color = paper);
        canvas.drawRRect(card.deflate(0.01), Paint()..color = const Color(0xFF8E1D28));
        canvas.restore();
      }
    }
    for (final (i, hand) in hands.indexed) {
      final side = i == 0 ? -1.0 : 1.0;
      final elbow = Offset(side * 0.42 * (look.dame ? 0.9 : 1), 0.0 + lift * 0.9);
      final along = hand - elbow;
      final unit = along / along.distance;
      final cross = Offset(-unit.dy, unit.dx);
      final wrist = hand - unit * 0.06;
      final sleeve = Path()
        ..moveTo(elbow.dx + cross.dx * 0.0585, elbow.dy + cross.dy * 0.0585)
        ..quadraticBezierTo(
          (elbow.dx + wrist.dx) / 2 + cross.dx * 0.0585,
          (elbow.dy + wrist.dy) / 2 + cross.dy * 0.0585,
          wrist.dx + cross.dx * 0.058,
          wrist.dy + cross.dy * 0.058,
        )
        ..lineTo(wrist.dx - cross.dx * 0.058, wrist.dy - cross.dy * 0.058)
        ..quadraticBezierTo(
          (elbow.dx + wrist.dx) / 2 - cross.dx * 0.0585,
          (elbow.dy + wrist.dy) / 2 - cross.dy * 0.0585,
          elbow.dx - cross.dx * 0.0585,
          elbow.dy - cross.dy * 0.0585,
        )
        ..close();
      canvas.drawPath(sleeve.shift(Offset(pose.light.dx * 0.012, pose.light.dy * 0.012)), Paint()..color = (lit ? gold : rim).withValues(alpha: 0.6));
      canvas.drawPath(
        sleeve,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_dark(coat, 0.7), _dark(coat, 0.15)],
          ).createShader(Rect.fromPoints(elbow, wrist).inflate(0.1)),
      );
      // Il polsino della camicia.
      canvas.drawLine(
        wrist + cross * 0.055,
        wrist - cross * 0.055,
        Paint()
          ..color = look.dame ? _dark(coat, 0.2) : _dark(look.outfit.shirt, 0.15)
          ..strokeWidth = 0.03,
      );
      canvas.drawOval(
        Rect.fromCenter(center: hand.translate(0, 0.02), width: 0.15, height: 0.06),
        Paint()..color = Colors.black.withValues(alpha: 0.4),
      );
      canvas.drawOval(
        Rect.fromCenter(center: hand, width: 0.115, height: 0.075),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_bright(skin, 0.15), _dark(skin, 0.4)],
          ).createShader(Rect.fromCenter(center: hand, width: 0.115, height: 0.075)),
      );
      if (look.dame && i == 1) {
        canvas.drawCircle(hand.translate(-0.02, -0.02), 0.012, Paint()..color = gold);
      }
    }
  }

  /// Il fumo che sale dalla brace, piano, e si allarga.
  static void _smoke(Canvas canvas, AvatarLook look, CharacterPose pose) {
    if (!look.accessory.smokes) return;
    final lift = -0.42 * pose.rise + pose.breath * 0.012;
    final tip = switch (look.accessory) {
      AvatarAccessory.cigar => const Offset(0.165, -0.75),
      AvatarAccessory.pipe => const Offset(0.125, -0.78),
      AvatarAccessory.cigaretteHolder => const Offset(0.245, -0.81),
      _ => const Offset(0.145, -0.76),
    }.translate(0, lift);
    paintSmoke(canvas, tip, 1, pose.time, seed: look.hashCode % 97);
  }

  /// Una voluta di fumo alta [height] che parte da [from]: la usa anche il
  /// tavolo per la nebbia sotto la lampada.
  static void paintSmoke(Canvas canvas, Offset from, double height, double time, {int seed = 0, double alpha = 0.22}) {
    const puffs = 7;
    for (var i = 0; i < puffs; i++) {
      final p = (time * 0.22 + i / puffs + seed * 0.013) % 1;
      final y = -p * 0.75 * height;
      final x = sin(time * 1.1 + p * 7 + seed) * 0.06 * height * p + p * 0.08 * height;
      final r = (0.02 + 0.09 * p) * height;
      canvas.drawCircle(
        from + Offset(x, y),
        r,
        Paint()
          ..color = const Color(0xFFD8D2CA).withValues(alpha: alpha * sin(pi * p) * (1 - p * 0.4))
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.6),
      );
    }
  }
}
