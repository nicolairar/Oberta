import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../online/shop_models.dart' show CalcioEmblem, CalcioKit, CalcioProp, CalcioTeam, ShopBrand;
import '../widgets/noir_avatar.dart' show AvatarHead;
import 'avatar_look.dart';

part 'oddities_painter.dart';
part 'absurd_painter.dart';
part 'calcio_painter.dart';
part 'face_painter.dart';
part 'deep_painter.dart';
part 'extras_painter.dart';
part 'noir_painter.dart';

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
  /// non si vede niente, sopra il panno si posano gli avambracci. È la
  /// stessa del ritratto ([bust]), con il busto che scende fino al bordo.
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
    final light = pose.light.distance == 0 ? const Offset(0, -1) : pose.light / pose.light.distance;
    final p = _Noir.parts(look, base: 1.5);
    final b = p.b;
    final q = (look.dame ? 0.86 : 1.0) / b.shoulderW;
    final lift = -0.42 * pose.rise + pose.breath * 0.012;
    canvas.save();
    canvas.translate(base.dx, base.dy);
    canvas.scale(s);
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(-3, -4, 3, cut));
    if (hands && chair) _chair(canvas, empty: false, lit: lit);
    canvas.save();
    canvas.translate(0, lift - 0.56);
    canvas.scale(q);
    canvas.translate(-0.5, -b.shoulderY);
    if (lit) {
      // Chi è scelto: un filo d'oro intorno alla sagoma.
      for (final path in [p.torso, p.face, p.front, p.back, p.hat?.crown]) {
        if (path != null) canvas.drawPath(path, _nStroke(gold, 0.1));
      }
    }
    _Noir.paint(canvas, look, p, s * q, light: light, glance: pose.glance);
    canvas.restore();
    if (!hands) {
      // Chi sta in piedi dietro sfuma nel buio sotto il petto.
      canvas.drawRect(
        Rect.fromLTRB(-0.7, cut - 0.3, 0.7, cut),
        Paint()
          ..shader = LookPainter._gs(const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x00000000), Color(0xE6000000)],
          ), Rect.fromLTRB(-0.7, cut - 0.3, 0.7, cut)),
      );
    }
    canvas.restore();
    if (hands) _forearms(canvas, look, pose, lit: lit);
    if (look.accessory.smokes) {
      final tip = _Noir.smokeFrom(look, b);
      final at = Offset((tip.dx - 0.5) * q, (tip.dy - b.shoulderY) * q - 0.56 + lift);
      paintSmoke(canvas, at, 1, pose.time, seed: look.hashCode % 97);
    }
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
  /// la testa grande nel mezzo, le spalle che escono dal basso, nel cartoon
  /// noir ([_Noir]). Se quello che porta in testa salirebbe oltre il bordo,
  /// la persona si rimpicciolisce verso le spalle.
  ///
  /// La scena della bottega ([AvatarLook.aura]) riempie il quadrato; con
  /// [aura] false resta fuori, per chi la dipinge da sé più grande ([aura]).
  static void bust(Canvas canvas, AvatarLook look, double side, {CharacterPose pose = const CharacterPose(light: Offset(-0.6, -0.8)), bool aura = true}) {
    final light = pose.light.distance == 0 ? const Offset(-0.6, -0.8) : pose.light / pose.light.distance;
    _Noir.bust(canvas, look, side, light: light, glance: pose.glance, aura: aura);
  }

  /// La scena di [look] intorno al ritratto di lato [side] con l'angolo in
  /// alto a sinistra nell'origine: riempie [area] (in pixel, dalla stessa
  /// origine; senza, il quadrato del ritratto), così copre tutto l'arco del
  /// posto al tavolo con la testa al suo posto.
  static void aura(Canvas canvas, AvatarLook look, double side, {Rect? area}) => _Noir.aura(canvas, look, side, area ?? Offset.zero & Size.square(side));

  /// Solo alcuni strati della persona, nel riquadro del ritratto, senza
  /// inchiostro né ombre: per i test che controllano dove sta ogni pezzo.
  @visibleForTesting
  static void bustLayers(Canvas canvas, AvatarLook look, double side, Set<LookLayer> layers) => _Noir.bust(canvas, look, side, only: layers);

  /// Dove stanno, nel ritratto di lato [side], gli occhi (il centro di
  /// ognuno), la punta del naso, la bocca, il mento e la tesa: per i test.
  @visibleForTesting
  static ({Offset leftEye, Offset rightEye, double nose, double mouth, double chin, double brow, double width}) bustAnchors(AvatarLook look, double side) {
    final p = _Noir.parts(look);
    final b = p.b;
    final k = _Noir.scale(look, p);
    Offset at(double x, double y) => Offset(side * (0.5 + (x - 0.5) * k), side * (1 + (y - 1) * k));
    return (
      leftEye: at(b.cx - b.eyeDx, b.eyeY),
      rightEye: at(b.cx + b.eyeDx, b.eyeY),
      nose: at(0.5, b.noseY).dy,
      mouth: at(0.5, b.mouthY).dy,
      chin: at(0.5, b.bottom).dy,
      brow: at(0.5, b.browY).dy,
      width: b.w * side * k,
    );
  }

  /// Where the top of the player (the hat, the hair, what floats over
  /// them) falls in the portrait of side 1, as [bust] paints it.
  static double top(AvatarLook look) {
    final p = _Noir.parts(look);
    return 1 + (p.crown - 1) * _Noir.scale(look, p);
  }

  /// Fin dove sale la persona sopra la testa, nelle misure del busto (la
  /// sommità della testa è a -1.06): il cappello, la pettinatura, le ali.
  static double crown(AvatarLook look) {
    final hairdo = switch (look.hairdo) {
      Hairdo.beehive => -1.53,
      Hairdo.toweringPompadour => -1.47,
      Hairdo.punkSpikes => -1.42,
      Hairdo.flameBouffant => -1.39,
      _ => -1.22,
    };
    final hat = look.hairdo != Hairdo.none
        ? -1.22
        : switch (look.hat) {
            AvatarHead.magicianHat => -1.5,
            AvatarHead.unicornHorn => -1.41,
            AvatarHead.flamingHair => -1.39,
            AvatarHead.topHat || AvatarHead.spaghettiHat || AvatarHead.catOnHead => -1.35,
            AvatarHead.chefToque ||
            AvatarHead.fishHead ||
            AvatarHead.octopusHat ||
            AvatarHead.ufoHat ||
            AvatarHead.birthdayCake ||
            AvatarHead.rainbowAfro => -1.33,
            AvatarHead.astronautHelmet => -1.32,
            AvatarHead.sombrero || AvatarHead.operaHelmet => -1.31,
            AvatarHead.roosterHead ||
            AvatarHead.blaugranaCap ||
            AvatarHead.merenguesCap ||
            AvatarHead.celestiCap ||
            AvatarHead.diavoliCap ||
            AvatarHead.redsCap ||
            AvatarHead.rossoneriCap ||
            AvatarHead.nerazzurriCap ||
            AvatarHead.bianconeriCap ||
            AvatarHead.giallorossiCap ||
            AvatarHead.azzurriCap => -1.29,
            AvatarHead.dinoHood => -1.28,
            AvatarHead.devilHorns => -1.27,
            _ => -1.22,
          };
    final prop = look.accessory == AvatarAccessory.balloons || look.back == BackItem.dragonWings ? -1.34 : -1.22;
    final hair = look.hairdo == Hairdo.none ? _Face.hairTop(look) - 0.04 : -1.22;
    return min(min(hairdo, hair), min(hat + _hatLift(look), prop));
  }

  /// La pelle più chiara di [t]: verso una versione chiara della stessa pelle,
  /// non verso il crema, così le pelli scure non diventano cenere.
  static Color _skinLight(Color c, double t) {
    final h = HSLColor.fromColor(c);
    final target = h
        .withLightness(h.lightness + (1 - h.lightness) * 0.75)
        .withSaturation(h.saturation * 0.75)
        .toColor();
    return Color.lerp(c, target, t)!;
  }

  /// La pelle in ombra di [t]: verso un bruno caldo e spento della stessa
  /// pelle, invece del blu-nero che la sporca (e senza arancio sulle chiare).
  static Color _skinShade(Color c, double t) {
    final h = HSLColor.fromColor(c);
    final target = h
        .withLightness(h.lightness * 0.2)
        .withSaturation(h.saturation * 0.55)
        .withHue((h.hue - 8) % 360)
        .toColor();
    return Color.lerp(c, target, t)!;
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
        ..shader = LookPainter._gs(LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: empty
              ? const [Color(0xFF4A4542), Color(0xFF221F1D)]
              : const [Color(0xFF4A1916), Color(0xFF1A0807)],
        ), bounds),
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

  /// Come si dipinge adesso (lo decidono [bust] e [seated]).
  static _Style _style = const _Style();

  /// Il blu notte delle ombre nette.
  static const night = Color(0xFF1A1236);

  /// Una sfumatura dei pittori di sempre: nel cartoon noir diventa il suo
  /// colore di mezzo, pieno (le sfumature con il trasparente, i bagliori,
  /// restano).
  static Shader _gs(Gradient g, Rect r) {
    if (!_style.noir || g.colors.any((c) => c.a < 1)) return g.createShader(r);
    final mid = g.colors.length == 2 ? Color.lerp(g.colors.first, g.colors.last, 0.5)! : g.colors[g.colors.length ~/ 2];
    return LinearGradient(colors: [mid, mid]).createShader(r);
  }

  /// L'oro della bottega (la statua, le giacche d'oro): il ritratto luccica.
  static bool gilded(AvatarLook look) => _Noir._gilded(look);

  /// Un vezzo che sta accanto o dietro la persona (il fumogeno, la bandiera,
  /// il pappagallo, i palloncini): la sua miniatura mostra il ritratto
  /// intero, che si veda tutto.
  static bool beside(AvatarAccessory accessory) =>
      _Noir._wingedVice(accessory) ||
      const {AvatarAccessory.parrot, AvatarAccessory.pigeon, AvatarAccessory.plungerSword, AvatarAccessory.baguetteCigar}.contains(accessory);

  /// Quanto salgono le cose che si posano sopra i capelli (l'aureola, le
  /// corna, il gatto) quando i capelli sono alti: stanno sopra, non dentro.
  static double _hatLift(AvatarLook look) {
    if (look.hairdo != Hairdo.none || !_Face._onTop.contains(look.hat)) return 0;
    return min(0.0, _Face.hairTop(look) + 1.1);
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
    // Colore pieno: l'ombra netta la mette [_figure], sopra a tutto l'abito.
    canvas.drawPath(torso, Paint()..color = outfit.coat);
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
        for (var x = -0.49; x < 0.5; x += 0.065) {
          final path = Path()
            ..moveTo(x, -0.7)
            ..quadraticBezierTo(x * 1.04, -0.35, x * 0.9, 0.6);
          canvas.drawPath(path, thread..style = PaintingStyle.stroke);
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
            ..shader = LookPainter._gs(LinearGradient(
              begin: const Alignment(-1, -0.4),
              end: const Alignment(1, 0.4),
              colors: [Colors.transparent, Colors.white.withValues(alpha: 0.16), Colors.transparent],
              stops: const [0.2, 0.36, 0.52],
            ), bounds),
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
          ..color = outfit.accent.withValues(alpha: 0.85)
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
              ..shader = LookPainter._gs(LinearGradient(
                colors: [_bright(outfit.accent, 0.12), _dark(outfit.accent, 0.55)],
              ), const Rect.fromLTRB(-0.2, -0.6, 0.2, 0.0)),
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
      case CoatPattern.dress:
        // Il corpetto con le pince, la cintura in vita e la gonna che si apre.
        final dart = Paint()
          ..color = _dark(outfit.coat, 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.008;
        for (final side in [-1.0, 1.0]) {
          canvas.drawLine(Offset(side * 0.17, -0.4), Offset(side * 0.14, 0.12), dart);
          canvas.drawLine(Offset(side * 0.14, 0.18), Offset(side * 0.3, 0.6), dart);
        }
        canvas.drawRect(const Rect.fromLTRB(-0.6, 0.12, 0.6, 0.18), Paint()..color = outfit.accent);
        canvas.drawRRect(
          RRect.fromRectAndRadius(const Rect.fromLTRB(-0.04, 0.11, 0.04, 0.19), const Radius.circular(0.01)),
          Paint()..color = _dark(outfit.accent, 0.3),
        );
      case CoatPattern.blouse:
        // Le maniche a sbuffo, la pistagna e i bottoncini di madreperla.
        final puff = Paint()..color = _bright(outfit.coat, 0.12);
        for (final side in [-1.0, 1.0]) {
          canvas.drawOval(Rect.fromCenter(center: Offset(side * 0.36, -0.46), width: 0.2, height: 0.16), puff);
        }
        canvas.drawLine(const Offset(0, -0.4), const Offset(0, 0.6), Paint()
          ..color = _dark(outfit.coat, 0.2)
          ..strokeWidth = 0.008);
        final pearl = Paint()..color = const Color(0xFFF6F0E4);
        for (final y in [-0.3, -0.18, -0.06, 0.06]) {
          canvas.drawCircle(Offset(0, y), 0.012, pearl);
        }
        // La gonna scura a vita alta.
        canvas.drawRect(const Rect.fromLTRB(-0.6, 0.2, 0.6, 0.7), Paint()..color = outfit.shirt);
      case CoatPattern.canvas:
        _trunkCanvas(canvas, outfit.coat);
      case CoatPattern.baroque:
        _baroqueScrolls(canvas, outfit.accent);
      case CoatPattern.clown || CoatPattern.leotard || CoatPattern.breton || CoatPattern.chef || CoatPattern.banana ||
          CoatPattern.pizza || CoatPattern.cactus || CoatPattern.ghost || CoatPattern.mummy || CoatPattern.jersey:
        _Oddities.fabric(canvas, outfit, look.base.skin);
    }
    _houseTrim(canvas, outfit);
    // Le ombre dei fianchi: il petto gira e si allontana dalla lampada.
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = LookPainter._gs(LinearGradient(
          colors: [
            Colors.black.withValues(alpha: light.dx < 0 ? 0.18 : 0.42),
            Colors.transparent,
            Colors.transparent,
            Colors.black.withValues(alpha: light.dx < 0 ? 0.42 : 0.18),
          ],
          stops: const [0, 0.3, 0.7, 1],
        ), bounds),
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

    if (pattern == CoatPattern.blouse) {
      // Il colletto tondo della camicetta, con il fiocco.
      for (final side in [-1.0, 1.0]) {
        canvas.drawPath(
          Path()
            ..moveTo(0, -0.6)
            ..quadraticBezierTo(side * 0.06, -0.66, side * 0.15, -0.62)
            ..quadraticBezierTo(side * 0.14, -0.53, 0, -0.55)
            ..close(),
          Paint()..color = _bright(outfit.coat, 0.2),
        );
      }
      canvas.drawCircle(const Offset(0, -0.56), 0.02, Paint()..color = outfit.accent);
      _patch(canvas, outfit, -0.2);
      return;
    }
    // Un costume intero (il fantasma, la mummia, la banana) sale al collo
    // anche per lei: niente scollo a V nel lenzuolo.
    if ((look.dame && !pattern.costume) || pattern == CoatPattern.dress) {
      // Uno scollo a V, senza risvolti.
      canvas.drawPath(
        Path()
          ..moveTo(-0.14, -0.62)
          ..lineTo(0.14, -0.62)
          ..lineTo(0, -0.36)
          ..close(),
        // La stessa pelle del collo, che scende nell'ombra dell'abito.
        Paint()
          ..shader = LookPainter._gs(LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_skinShade(look.base.skin, 0.32), _skinShade(look.base.skin, 0.55)],
          ), const Rect.fromLTRB(-0.14, -0.62, 0.14, -0.36)),
      );
      if (pattern == CoatPattern.cape) _capeCollar(canvas, outfit);
      _patch(canvas, outfit, -0.2);
      return;
    }
    // La camicia nello scollo della giacca, e i risvolti.
    final deep = switch (pattern) {
      CoatPattern.track => -0.5,
      CoatPattern.cardigan => -0.34,
      _ when pattern.costume => -0.6,
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
        ..shader = LookPainter._gs(LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [outfit.shirt, _dark(outfit.shirt, 0.45)],
        ), Rect.fromLTRB(-0.13, -0.63, 0.13, deep)),
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
      case _ when pattern.costume:
        _Oddities.collar(canvas, outfit, look.base.skin);
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
    final peak = pattern == CoatPattern.doubleBreasted || pattern == CoatPattern.brocade || pattern == CoatPattern.baroque;
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
          ..shader = LookPainter._gs(LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: outfit.satin
                ? [_bright(cloth, lit ? 0.45 : 0.2), cloth, _bright(cloth, lit ? 0.3 : 0.1), _dark(cloth, 0.5)]
                : [_bright(cloth, lit ? 0.12 : 0.0), cloth, _dark(cloth, 0.4), _dark(cloth, 0.5)],
            stops: const [0, 0.35, 0.55, 1],
          ), const Rect.fromLTRB(-0.3, -0.63, 0.3, -0.15)),
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

  /// La tela da baule di Vaugirard: una trama diagonale fitta e, a
  /// quinconce, una borchia d'ottone a quattro punte e un rombo scuro.
  static void _trunkCanvas(Canvas canvas, Color coat) {
    final weave = Paint()
      ..color = _dark(coat, 0.4).withValues(alpha: 0.3)
      ..strokeWidth = 0.005;
    for (var x = -1.3; x < 0.7; x += 0.05) {
      canvas.drawLine(Offset(x, -0.7), Offset(x + 1.3, 0.6), weave);
    }
    final stud = Paint()..color = const Color(0xFFF0D18A).withValues(alpha: 0.85);
    final pip = Paint()..color = _dark(coat, 0.55).withValues(alpha: 0.85);
    var row = 0;
    for (var y = -0.66; y < 0.6; y += 0.1) {
      var col = 0;
      for (var x = -0.56 + (row.isOdd ? 0.05 : 0); x < 0.6; x += 0.1) {
        final c = Offset(x, y);
        if ((row + col).isEven) {
          canvas.drawPath(_starPath(c, 0.024, 4, 0.32), stud);
        } else {
          canvas.drawPath(
            Path()
              ..moveTo(x, y - 0.016)
              ..lineTo(x + 0.012, y)
              ..lineTo(x, y + 0.016)
              ..lineTo(x - 0.012, y)
              ..close(),
            pip,
          );
        }
        col++;
      }
      row++;
    }
  }

  /// Le volute d'oro di Versalli: coppie di riccioli schiena contro schiena,
  /// con una goccia sopra e una foglia sotto.
  static void _baroqueScrolls(Canvas canvas, Color gilt) {
    final scroll = Paint()
      ..color = gilt.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.008
      ..strokeCap = StrokeCap.round;
    final dot = Paint()..color = gilt.withValues(alpha: 0.8);
    var row = 0;
    for (var y = -0.6; y < 0.6; y += 0.13) {
      for (var x = -0.52 + (row.isOdd ? 0.075 : 0); x < 0.55; x += 0.15) {
        canvas.drawArc(Rect.fromCircle(center: Offset(x - 0.021, y), radius: 0.019), 0, -pi * 1.5, false, scroll);
        canvas.drawArc(Rect.fromCircle(center: Offset(x + 0.021, y), radius: 0.019), pi, pi * 1.5, false, scroll);
        canvas.drawCircle(Offset(x, y - 0.03), 0.007, dot);
        canvas.drawLine(Offset(x, y + 0.012), Offset(x, y + 0.038), scroll);
      }
      row++;
    }
    // L'orlo d'oro sotto le spalle.
    canvas.drawLine(const Offset(-0.6, -0.47), const Offset(0.6, -0.47), scroll..strokeWidth = 0.006);
  }

  /// La fascia di Cuccioli: verde, ambra, verde.
  static void _webBand(Canvas canvas, Rect r, {bool vertical = false}) {
    const teal = Color(0xFF1F6B63);
    const amber = Color(0xFFD89A2B);
    canvas.drawRect(r, Paint()..color = teal);
    final mid = vertical
        ? Rect.fromLTRB(r.left + r.width / 3, r.top, r.right - r.width / 3, r.bottom)
        : Rect.fromLTRB(r.left, r.top + r.height / 3, r.right, r.bottom - r.height / 3);
    canvas.drawRect(mid, Paint()..color = amber);
  }

  /// Una stella a [points] punte, la punta in alto.
  static Path _starPath(Offset c, double r, int points, double inner) {
    final path = Path();
    for (var k = 0; k < points * 2; k++) {
      final a = -pi / 2 + k * pi / points;
      final d = k.isEven ? r : r * inner;
      final p = c.translate(cos(a) * d, sin(a) * d);
      k == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  /// I dettagli che fanno riconoscere la casa anche da lontano.
  static void _houseTrim(Canvas canvas, AvatarOutfit outfit) {
    switch (outfit.brand) {
      case ShopBrand.chanterelle when outfit.pattern == CoatPattern.velvet:
        // Il bordo intrecciato bianco lungo l'apertura e sulle tasche, e i
        // bottoni di perla.
        final braid = Paint()
          ..color = outfit.accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.026;
        final weave = Paint()
          ..color = _dark(outfit.coat, 0.2)
          ..strokeWidth = 0.006;
        for (final side in [-1.0, 1.0]) {
          canvas.drawLine(Offset(side * 0.03, -0.17), Offset(side * 0.06, 0.6), braid);
          for (var t = 0.0; t <= 1; t += 0.06) {
            final x = side * (0.03 + 0.03 * t);
            final y = -0.17 + 0.77 * t;
            canvas.drawLine(Offset(x - 0.012, y - 0.008), Offset(x + 0.012, y + 0.008), weave);
          }
          final pocket = Rect.fromLTRB(side < 0 ? -0.31 : 0.15, 0.08, side < 0 ? -0.15 : 0.31, 0.2);
          canvas.drawRect(pocket, braid..strokeWidth = 0.016);
          braid.strokeWidth = 0.026;
        }
        final pearl = Paint()..color = const Color(0xFFF8F4EA);
        for (final y in [-0.06, 0.06, 0.18]) {
          for (final side in [-1.0, 1.0]) {
            final c = Offset(side * 0.1, y);
            canvas.drawCircle(c, 0.017, pearl);
            canvas.drawCircle(c.translate(-0.005, -0.005), 0.005, Paint()..color = Colors.white);
          }
        }
      case ShopBrand.cuccioli:
        // La fascia lungo l'apertura e la staffa d'ottone che la chiude.
        for (final side in [-1.0, 1.0]) {
          canvas.drawPath(
            Path()
              ..moveTo(side * 0.03, -0.16)
              ..lineTo(side * 0.085, -0.16)
              ..lineTo(side * 0.11, 0.6)
              ..lineTo(side * 0.05, 0.6)
              ..close(),
            Paint()..color = const Color(0xFF1F6B63),
          );
          canvas.drawPath(
            Path()
              ..moveTo(side * 0.048, -0.16)
              ..lineTo(side * 0.067, -0.16)
              ..lineTo(side * 0.09, 0.6)
              ..lineTo(side * 0.07, 0.6)
              ..close(),
            Paint()..color = const Color(0xFFD89A2B),
          );
        }
        canvas.drawRect(const Rect.fromLTRB(-0.07, -0.11, 0.07, -0.085), Paint()..color = const Color(0xFF8A5E1E));
        brandMark(canvas, ShopBrand.cuccioli, const Offset(0, -0.1), 0.04, color: gold);
      case ShopBrand.vaugirard:
        // La cintura di cuoio con la placca d'ottone, e i bottoni d'ottone.
        canvas.drawRect(const Rect.fromLTRB(-0.6, -0.04, 0.6, 0.03), Paint()..color = const Color(0xFF4A2E1A));
        final edge = Paint()
          ..color = const Color(0xFFE8C77A).withValues(alpha: 0.6)
          ..strokeWidth = 0.004;
        canvas.drawLine(const Offset(-0.6, -0.033), const Offset(0.6, -0.033), edge);
        canvas.drawLine(const Offset(-0.6, 0.023), const Offset(0.6, 0.023), edge);
        canvas.drawRRect(
          RRect.fromRectAndRadius(const Rect.fromLTRB(-0.045, -0.06, 0.045, 0.05), const Radius.circular(0.012)),
          Paint()..color = const Color(0xFFD9AE5A),
        );
        brandMark(canvas, ShopBrand.vaugirard, const Offset(0, -0.005), 0.04, color: const Color(0xFF4A2E1A));
        for (final y in [-0.3, -0.16, 0.16]) {
          for (final side in [-1.0, 1.0]) {
            canvas.drawCircle(Offset(side * 0.09, y), 0.017, Paint()..color = const Color(0xFFD9AE5A));
          }
        }
      case ShopBrand.adelphi when outfit.pattern == CoatPattern.track:
        // Il carré a due toni: la parte alta bianca, staccata da un filo blu.
        canvas.drawRect(const Rect.fromLTRB(-0.6, -0.7, 0.6, -0.34), Paint()..color = outfit.accent.withValues(alpha: 0.92));
        canvas.drawRect(
          const Rect.fromLTRB(-0.6, -0.345, 0.6, -0.325),
          Paint()..color = _bright(outfit.coat, 0.25),
        );
      case ShopBrand.nikea when outfit.pattern == CoatPattern.track:
        // La banda arancio che gira sotto il petto.
        canvas.drawRect(const Rect.fromLTRB(-0.6, -0.22, 0.6, -0.17), Paint()..color = outfit.accent);
      default:
        break;
    }
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
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    switch (brand) {
      case ShopBrand.vaugirard:
        // La placca della serratura di un baule, il buco della chiave e
        // quattro ribattini.
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: r * 1.35, height: r * 1.8), Radius.circular(r * 0.25)),
          line..strokeWidth = r * 0.16,
        );
        canvas.drawCircle(c.translate(0, -r * 0.18), r * 0.22, fill);
        canvas.drawPath(
          Path()
            ..moveTo(c.dx - r * 0.12, c.dy - r * 0.1)
            ..lineTo(c.dx + r * 0.12, c.dy - r * 0.1)
            ..lineTo(c.dx + r * 0.18, c.dy + r * 0.45)
            ..lineTo(c.dx - r * 0.18, c.dy + r * 0.45)
            ..close(),
          fill,
        );
        for (final dx in [-0.42, 0.42]) {
          for (final dy in [-0.65, 0.65]) {
            canvas.drawCircle(c.translate(r * dx, r * dy), r * 0.08, fill);
          }
        }
      case ShopBrand.arminio:
        // Un tondo sottile tagliato da un orizzonte: niente di più.
        canvas.drawCircle(c, r * 0.85, line..strokeWidth = r * 0.1);
        canvas.drawLine(c.translate(-r * 1.0, r * 0.1), c.translate(r * 1.0, r * 0.1), line..strokeWidth = r * 0.16);
        canvas.drawCircle(c.translate(0, -r * 0.35), r * 0.13, fill);
      case ShopBrand.cuccioli:
        // La staffa da sella, d'ottone: l'arco, la feritoia e il poggiapiede.
        canvas.drawPath(
          Path()
            ..moveTo(c.dx - r * 0.6, c.dy + r * 0.55)
            ..quadraticBezierTo(c.dx - r * 0.75, c.dy - r * 0.75, c.dx, c.dy - r * 0.72)
            ..quadraticBezierTo(c.dx + r * 0.75, c.dy - r * 0.75, c.dx + r * 0.6, c.dy + r * 0.55),
          line..strokeWidth = r * 0.2,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(c.dx - r * 0.85, c.dy + r * 0.48, c.dx + r * 0.85, c.dy + r * 0.8),
            Radius.circular(r * 0.1),
          ),
          fill,
        );
        canvas.drawRect(Rect.fromLTRB(c.dx - r * 0.2, c.dy - r * 1.0, c.dx + r * 0.2, c.dy - r * 0.7), fill);
      case ShopBrand.versalli:
        // Una rosa d'oro a otto petali dentro un anello di perline.
        for (var k = 0; k < 8; k++) {
          final a = k * pi / 4;
          canvas.drawCircle(c.translate(cos(a) * r * 0.5, sin(a) * r * 0.5), r * 0.22, fill);
        }
        canvas.drawCircle(c, r * 0.24, Paint()..color = Colors.black.withValues(alpha: 0.5));
        canvas.drawCircle(c, r * 0.14, fill);
        for (var k = 0; k < 16; k++) {
          final a = k * pi / 8;
          canvas.drawCircle(c.translate(cos(a) * r * 0.92, sin(a) * r * 0.92), r * 0.07, fill);
        }
      case ShopBrand.chanterelle:
        // Un fiocco di nastro e una perla appesa.
        for (final side in [-1.0, 1.0]) {
          canvas.drawPath(
            Path()
              ..moveTo(c.dx, c.dy - r * 0.2)
              ..quadraticBezierTo(c.dx + side * r * 0.5, c.dy - r * 0.95, c.dx + side * r * 0.95, c.dy - r * 0.55)
              ..quadraticBezierTo(c.dx + side * r * 1.0, c.dy - r * 0.15, c.dx, c.dy - r * 0.2)
              ..close(),
            fill,
          );
          canvas.drawLine(c.translate(0, -r * 0.15), c.translate(side * r * 0.35, r * 0.35), line..strokeWidth = r * 0.16);
        }
        canvas.drawCircle(c.translate(0, -r * 0.22), r * 0.2, fill);
        canvas.drawCircle(c.translate(0, r * 0.68), r * 0.26, fill);
      case ShopBrand.nikea:
        // Un'ala a tre penne che si apre in su.
        final root = c.translate(-r * 0.55, r * 0.55);
        for (var k = 0; k < 3; k++) {
          canvas.save();
          canvas.translate(root.dx, root.dy);
          canvas.rotate(-pi / 2 + 0.25 + k * 0.42);
          final length = r * (1.55 - k * 0.3);
          canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTRB(-r * 0.15, -length, r * 0.15, 0), Radius.circular(r * 0.15)),
            fill,
          );
          canvas.restore();
        }
        canvas.drawCircle(root, r * 0.22, fill);
      case ShopBrand.adelphi:
        // Due stelle affiancate: i due fratelli.
        canvas.drawPath(_starPath(c.translate(-r * 0.45, 0), r * 0.52, 5, 0.42), fill);
        canvas.drawPath(_starPath(c.translate(r * 0.45, 0), r * 0.52, 5, 0.42), fill);
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
        ..shader = LookPainter._gs(LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_bright(color, 0.15), _dark(color, 0.45)],
        ), const Rect.fromLTRB(-0.06, -0.62, 0.06, -0.2)),
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
        ..shader = LookPainter._gs(LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_bright(color, 0.25), _dark(color, 0.35)],
        ), const Rect.fromLTRB(-0.09, -0.63, 0.09, -0.54)),
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
    // A dress, a blouse and a jersey have their own neckline: no shirt.
    if (look.dame || const {CoatPattern.dress, CoatPattern.blouse, CoatPattern.jersey}.contains(look.outfit.pattern)) return;
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

  static void _neck(Canvas canvas, AvatarLook look, Offset light) {
    // The dresses keep a pale accent for their trim: a tie, a scarf or a
    // cravat in it would vanish on the skin, so they take a deep navy (a
    // wine on the black dress, where navy would vanish too).
    final pale = look.outfit.pattern.feminine && look.outfit.accent.computeLuminance() > 0.45;
    final accent = !pale ? look.outfit.accent : (look.outfit.coat.computeLuminance() < 0.03 ? const Color(0xFF8E1D2C) : const Color(0xFF1B2A4A));
    // La tuta ha il suo collo: niente cravatte sotto la cerniera.
    final zipped = (look.outfit.pattern == CoatPattern.track || look.outfit.pattern.costume) && !look.dame;
    // A tie wants a collar: under a zip or a costume there is none, for anyone.
    final covered = look.outfit.pattern == CoatPattern.track || look.outfit.pattern.costume;
    switch (look.accessory) {
      case AvatarAccessory.tie:
        if (covered) break;
        _tie(canvas, accent);
      case AvatarAccessory.stripeTie:
        if (covered) break;
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
        if (covered) break;
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
        if (covered) break;
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
            ..shader = LookPainter._gs(LinearGradient(
              colors: [_bright(accent, 0.3), _dark(accent, 0.3)],
            ), const Rect.fromLTRB(-0.13, -0.63, 0.13, -0.36)),
        );
      case AvatarAccessory.delacroixScarf:
        // La sciarpa di seta bianca da sera: gira intorno al collo e scende
        // sui risvolti, con le frange e la luna ricamata.
        final silk = Paint()
          ..shader = LookPainter._gs(const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFFBF2), Color(0xFFD8D0C2), Color(0xFFF6F0E4), Color(0xFFB8AFA2)],
            stops: [0, 0.35, 0.6, 1],
          ), const Rect.fromLTRB(-0.2, -0.66, 0.2, -0.32));
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
        for (final side in [-1.0, 1.0]) {
          canvas.drawPath(
            Path()
              ..moveTo(side * 0.15, -0.62)
              ..quadraticBezierTo(side * 0.17, -0.48, side * 0.13, -0.34),
            Paint()
              ..color = const Color(0xFF151417)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.012,
          );
        }
        brandMark(canvas, ShopBrand.chanterelle, const Offset(-0.1, -0.42), 0.024, color: const Color(0xFF151417));
      case AvatarAccessory.polkaTie:
        if (covered) break;
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
          ..shader = LookPainter._gs(LinearGradient(
            colors: [_bright(accent, 0.35), _dark(accent, 0.25)],
          ), const Rect.fromLTRB(-0.1, -0.64, 0.1, -0.36));
        canvas.drawPath(_ascotPath, silk);
        canvas.drawCircle(const Offset(0, -0.52), 0.015, Paint()..color = gold);
      case AvatarAccessory.delacroixAscot:
        // Il foulard della casa: seta lilla a lune piccole, la spilla d'oro.
        canvas.drawPath(
          _ascotPath,
          Paint()
            ..shader = LookPainter._gs(const LinearGradient(
              colors: [Color(0xFF3A383E), Color(0xFF0E0D10)],
            ), const Rect.fromLTRB(-0.1, -0.64, 0.1, -0.36)),
        );
        canvas.save();
        canvas.clipPath(_ascotPath);
        for (final p in const [Offset(-0.05, -0.58), Offset(0.04, -0.55), Offset(-0.02, -0.46), Offset(0.05, -0.43), Offset(-0.05, -0.4)]) {
          brandMark(canvas, ShopBrand.chanterelle, p, 0.016, color: const Color(0xFFF2EEE6).withValues(alpha: 0.85));
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
        canvas.drawCircle(const Offset(0, -0.52), 0.019, Paint()..color = const Color(0xFFF8F4EA));
        canvas.drawCircle(const Offset(-0.005, -0.525), 0.006, Paint()..color = Colors.white);
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
        brandMark(canvas, ShopBrand.versalli, const Offset(0, -0.455), 0.018, color: const Color(0xFF7A5418));
        canvas.drawCircle(const Offset(-0.012, -0.468), 0.006, Paint()..color = Colors.white.withValues(alpha: 0.9));
      case AvatarAccessory.vaugirardStrap:
        // La tracolla di cuoio della borsa da viaggio, di traverso sul petto,
        // con la fibbia e la placca d'ottone della casa.
        if (!covered) _tie(canvas, const Color(0xFF4A2E1A));
        final strap = Path()
          ..moveTo(-0.3, -0.62)
          ..lineTo(-0.22, -0.64)
          ..lineTo(0.42, 0.6)
          ..lineTo(0.33, 0.6)
          ..close();
        canvas.drawPath(strap.shift(const Offset(0.006, 0.01)), Paint()..color = Colors.black.withValues(alpha: 0.35));
        canvas.drawPath(strap, Paint()..color = const Color(0xFF6A4222));
        final stitch = Paint()
          ..color = const Color(0xFFE8C77A).withValues(alpha: 0.7)
          ..strokeWidth = 0.004;
        canvas.drawLine(const Offset(-0.285, -0.615), const Offset(0.345, 0.6), stitch);
        canvas.drawLine(const Offset(-0.235, -0.632), const Offset(0.405, 0.6), stitch);
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromCenter(center: const Offset(0.0, -0.2), width: 0.1, height: 0.1), const Radius.circular(0.014)),
          Paint()..color = const Color(0xFFD9AE5A),
        );
        brandMark(canvas, ShopBrand.vaugirard, const Offset(0.0, -0.2), 0.04, color: const Color(0xFF4A2E1A));
      case AvatarAccessory.chanterellePearls:
        // Due fili di perle, uno corto e uno lungo che scende sul petto, e il
        // fiocco nero della casa sul fermaglio.
        if (!zipped) _openCollar(canvas, look);
        final pearl = Paint()..color = const Color(0xFFF8F4EA);
        final shade = Paint()..color = const Color(0xFFB8B0A2);
        final shine = Paint()..color = Colors.white;
        for (final (drop, count, size) in [(0.08, 12, 0.013), (0.3, 20, 0.012)]) {
          for (var i = 0; i <= count; i++) {
            final t = i / count;
            final c = Offset(-0.14 + 0.28 * t, -0.61 + drop * sin(pi * t));
            canvas.drawCircle(c.translate(0.003, 0.004), size, shade);
            canvas.drawCircle(c, size, pearl);
            canvas.drawCircle(c.translate(-0.004, -0.004), size * 0.3, shine);
          }
        }
        brandMark(canvas, ShopBrand.chanterelle, const Offset(-0.14, -0.6), 0.03, color: const Color(0xFF151417));
      case AvatarAccessory.none ||
          AvatarAccessory.clownNose ||
          AvatarAccessory.parrot ||
          AvatarAccessory.rubberDuck ||
          AvatarAccessory.accordion ||
          AvatarAccessory.baguetteCigar ||
          AvatarAccessory.snailShell ||
          AvatarAccessory.jetpack ||
          AvatarAccessory.balloons ||
          AvatarAccessory.giantBowTie ||
          AvatarAccessory.pigeon ||
          AvatarAccessory.plungerSword ||
          AvatarAccessory.blaugranaScarf ||
          AvatarAccessory.blaugranaFlare ||
          AvatarAccessory.merenguesScarf ||
          AvatarAccessory.merenguesTrophy ||
          AvatarAccessory.celestiScarf ||
          AvatarAccessory.celestiMegaphone ||
          AvatarAccessory.diavoliScarf ||
          AvatarAccessory.diavoliFlare ||
          AvatarAccessory.redsScarf ||
          AvatarAccessory.redsMegaphone ||
          AvatarAccessory.rossoneriScarf ||
          AvatarAccessory.rossoneriFlare ||
          AvatarAccessory.nerazzurriScarf ||
          AvatarAccessory.nerazzurriFlag ||
          AvatarAccessory.bianconeriScarf ||
          AvatarAccessory.bianconeriTrophy ||
          AvatarAccessory.giallorossiScarf ||
          AvatarAccessory.giallorossiFlare ||
          AvatarAccessory.azzurriScarf ||
          AvatarAccessory.azzurriFlag ||
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
            ..shader = LookPainter._gs(const RadialGradient(
              center: Alignment(-0.5, -0.5),
              colors: [Color(0xFFFFF0B8), Color(0xFFE2B54A), Color(0xFF8A5E1E)],
            ), Rect.fromCircle(center: c, radius: 0.048)),
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

  static Color _hairColor(AvatarLook look) => _beardColor(look, look.features.hairColor.color);

  /// The colour of the beard: the hair's, but on dark skin a beard as dark
  /// as the skin takes a cool sheen, or it would not show at the table.
  static Color _beardColor(AvatarLook look, Color hair) {
    if (look.base.skin.computeLuminance() < 0.12 && hair.computeLuminance() < 0.05) return Color.lerp(hair, const Color(0xFF7A86A2), 0.28)!;
    return hair;
  }

  /// La barba e i baffi, sopra la bocca: la barba piena dentro la mascella
  /// di ogni forma di faccia (e oltre il mento), i baffi sul labbro.
  static void _beard(Canvas canvas, AvatarLook look) {
    final skin = look.base.mark == FaceMark.mimeFace ? const Color(0xFFF4F0E8) : look.base.skin;
    final mark = look.base.mark;
    final face = _Face.path(look.features.shape);
    canvas.save();
    canvas.clipPath(face);
    if (mark == FaceMark.fullBeard || mark == FaceMark.muttonChops) {
      // La barba piena copre la mascella; i basettoni lasciano il mento nudo.
      final beard = Paint()..color = _dark(_hairColor(look), 0.05);
      final full = mark == FaceMark.fullBeard;
      final Path path;
      if (full) {
        path = Path()
          ..moveTo(-0.17, -0.9)
          ..lineTo(-0.13, -0.9)
          ..quadraticBezierTo(-0.12, -0.8, -0.07, -0.79)
          ..lineTo(0.07, -0.79)
          ..quadraticBezierTo(0.12, -0.8, 0.13, -0.9)
          ..lineTo(0.17, -0.9)
          ..lineTo(0.17, -0.6)
          ..lineTo(-0.17, -0.6)
          ..close();
      } else {
        // I basettoni: dalle tempie lungo la mascella fino agli angoli della
        // bocca, dove si attaccano ai baffi. Il mento resta scoperto.
        path = Path();
        for (final side in [-1.0, 1.0]) {
          path
            ..moveTo(side * 0.18, -0.9)
            ..lineTo(side * 0.13, -0.9)
            ..quadraticBezierTo(side * 0.125, -0.82, side * 0.078, -0.772)
            ..quadraticBezierTo(side * 0.07, -0.73, side * 0.085, -0.705)
            ..quadraticBezierTo(side * 0.14, -0.7, side * 0.18, -0.74)
            ..close();
        }
      }
      canvas.drawPath(path, beard);
      if (full) {
        // La bocca si apre nella barba.
        canvas.drawOval(
          Rect.fromCenter(center: const Offset(0, -0.758), width: 0.07, height: 0.022),
          Paint()..color = _skinShade(skin, 0.45),
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
    if (mark == FaceMark.fullBeard) {
      // La barba piena scende oltre il mento e copre il colletto.
      final g = _Face.geometry(look.features.shape);
      canvas.drawPath(
        Path()
          ..moveTo(-g.jw, g.jy)
          ..cubicTo(-g.jw + 0.004, g.chin + 0.01, -0.07, g.chin + 0.045, 0, g.chin + 0.05)
          ..cubicTo(0.07, g.chin + 0.045, g.jw - 0.004, g.chin + 0.01, g.jw, g.jy)
          ..cubicTo(g.jw - 0.01, g.chin - 0.01, 0.05, g.chin - 0.004, 0, g.chin - 0.004)
          ..cubicTo(-0.05, g.chin - 0.004, -(g.jw - 0.01), g.chin - 0.01, -g.jw, g.jy)
          ..close(),
        Paint()..color = _dark(_hairColor(look), 0.12),
      );
    }

    final dark = Paint()..color = _dark(_hairColor(look), 0.1);
    switch (mark) {
      case FaceMark.clean || FaceMark.stubble || FaceMark.goldStatue:
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
          ..color = _skinLight(skin, 0.55).withValues(alpha: 0.85)
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
        // A touch bigger at the table, with a glint that lifts it off dark skin.
        final r = _Extras.table ? 0.015 : 0.01;
        canvas.drawCircle(const Offset(0.07, -0.79), r, Paint()..color = const Color(0xFF1A0E0A));
        canvas.drawCircle(Offset(0.07 - r * 0.35, -0.79 - r * 0.35), r * 0.38, Paint()..color = const Color(0x99FFF0DC));
      case FaceMark.pencil:
        // Il baffetto a matita: sottile, ma con un filo di luce sotto che lo
        // stacca dalla pelle anche nel ritratto piccolo.
        final line = Paint()
          ..color = _dark(_hairColor(look), 0.3)
          ..strokeWidth = 0.014
          ..strokeCap = StrokeCap.round;
        final lift = Paint()
          ..color = _skinLight(skin, 0.35).withValues(alpha: 0.55)
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
      case FaceMark.curledMoustache || FaceMark.giantMoustache || FaceMark.mimeFace || FaceMark.vikingBeard:
        _Oddities.mark(canvas, mark, dark.color);
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



  static void _glasses(Canvas canvas, AvatarLook look, CharacterPose pose) {
    final frame = Paint()
      ..color = const Color(0xFFD9C9A8).withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.012;
    final glint = Paint()..color = Colors.white.withValues(alpha: 0.7);
    switch (look.glasses) {
      case AvatarGlasses.none:
        break;
      case AvatarGlasses.noseDisguise || AvatarGlasses.heartGlasses || AvatarGlasses.hypnoGlasses || AvatarGlasses.eyePatch || AvatarGlasses.giantGlasses || AvatarGlasses.giantShades ||
          AvatarGlasses.googlyEyes || AvatarGlasses.glasses3d || AvatarGlasses.bulbMonocle:
        _Oddities.glasses(canvas, look.glasses);
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
          ..color = const Color(0xFFF2EEE6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.016;
        for (final side in [-1.0, 1.0]) {
          final r = Rect.fromCenter(center: Offset(side * 0.068, -0.874), width: 0.105, height: 0.068);
          canvas.drawOval(
            r,
            Paint()
              ..shader = LookPainter._gs(const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0C0B0E), Color(0xFF34323A)],
              ), r),
          );
          canvas.drawOval(r, wire);
          canvas.drawLine(Offset(side * 0.045, -0.889), Offset(side * 0.07, -0.894), Paint()
            ..color = Colors.white.withValues(alpha: 0.5)
            ..strokeWidth = 0.009
            ..strokeCap = StrokeCap.round);
        }
        canvas.drawLine(const Offset(-0.016, -0.882), const Offset(0.016, -0.882), wire);
        for (final side in [-1.0, 1.0]) {
          canvas.drawCircle(Offset(side * 0.124, -0.886), 0.012, Paint()..color = const Color(0xFFF8F4EA));
        }
        brandMark(canvas, ShopBrand.chanterelle, const Offset(0, -0.9), 0.014, color: const Color(0xFFF2EEE6));
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
            ..shader = LookPainter._gs(const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF3A3640), _felt],
            ), const Rect.fromLTRB(-0.2, -1.22, 0.2, -0.96)));
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
                ..shader = LookPainter._gs(LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [light, shade],
                ), const Rect.fromLTRB(-0.2, -1.2, 0.2, -0.96)));
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
                    AvatarHead.morettiFedora || AvatarHead.morettiPanama => const Color(0xFF1F6B63),
                    _ => _dark(accent, 0.55),
                  }),
        );
        if (!silhouette) {
          if (look.hat == AvatarHead.morettiFedora || look.hat == AvatarHead.morettiPanama) {
            // La fascia della casa: verde, ambra, verde.
            _webBand(canvas, const Rect.fromLTRB(-0.176, -1.04, 0.176, -0.985));
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
            _hatPin(canvas, ShopBrand.cuccioli);
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
                  ..shader = LookPainter._gs(const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF4A4452), Color(0xFF0E0D10), Color(0xFF1E1C22)],
                  ), const Rect.fromLTRB(-0.2, -1.2, 0.2, -0.96))),
        );
        const satin = Rect.fromLTRB(-0.171, -1.04, 0.171, -0.985);
        if (silhouette) {
          canvas.drawRect(satin, paint);
        } else {
          canvas.drawRect(
            satin,
            Paint()
              ..shader = LookPainter._gs(const LinearGradient(
                colors: [Color(0xFF0A090C), Color(0xFF5A5462), Color(0xFF0A090C), Color(0xFF2A2830)],
                stops: [0, 0.3, 0.6, 1],
              ), satin),
          );
          canvas.drawLine(
            const Offset(-0.03, -1.16),
            const Offset(-0.07, -1.06),
            Paint()
              ..color = Colors.white.withValues(alpha: 0.18)
              ..strokeWidth = 0.012,
          );
          _webBand(canvas, const Rect.fromLTRB(-0.171, -1.03, 0.171, -0.995));
          _hatPin(canvas, ShopBrand.cuccioli);
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
                  ..shader = LookPainter._gs(const RadialGradient(
                    center: Alignment(-0.4, -0.6),
                    colors: [Color(0xFF5A2430), Color(0xFF2A0E14)],
                  ), r)),
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
                  ..shader = LookPainter._gs(const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF3E4A5C), Color(0xFF1C2230)],
                  ), const Rect.fromLTRB(-0.2, -1.17, 0.2, -0.88))),
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
      case AvatarHead.sbirro:
        // Il berretto da sbirro: cupola blu questura, fascia nera, visiera
        // lucida e lo stemma d'oro davanti.
        final cap = Path()
          ..moveTo(-0.2, -0.97)
          ..quadraticBezierTo(-0.24, -1.13, 0, -1.15)
          ..quadraticBezierTo(0.24, -1.13, 0.2, -0.97)
          ..close();
        canvas.drawPath(cap, silhouette ? paint : (Paint()..color = const Color(0xFF1B2A4A)));
        if (!silhouette) {
          canvas.drawRect(const Rect.fromLTRB(-0.2, -1.01, 0.2, -0.965), Paint()..color = const Color(0xFF0E0E12));
          canvas.drawCircle(const Offset(0, -1.06), 0.034, Paint()..color = const Color(0xFFE8C45A));
          canvas.drawCircle(const Offset(0, -1.06), 0.016, Paint()..color = const Color(0xFF1B2A4A));
        }
        canvas.drawPath(
          Path()
            ..moveTo(-0.15, -0.97)
            ..quadraticBezierTo(0, -1.0, 0.15, -0.97)
            ..lineTo(0.12, -0.92)
            ..quadraticBezierTo(0, -0.945, -0.12, -0.92)
            ..close(),
          silhouette ? paint : (Paint()..color = const Color(0xFF0A0A0C)),
        );
      case AvatarHead.fulmineCap || AvatarHead.vaugirardCap || AvatarHead.adelphiCap:
        // I berretti delle case: spicchi a due colori, la visiera corta e il
        // marchio davanti. Quello di Vaugirard è di tela da baule.
        final (base, panel, band, visor, brand, mark) = switch (look.hat) {
          AvatarHead.vaugirardCap => (
            const Color(0xFF8E6A40),
            const Color(0xFF8E6A40),
            const Color(0xFF4A2E1A),
            const Color(0xFF4A2E1A),
            ShopBrand.vaugirard,
            const Color(0xFFE8C77A),
          ),
          AvatarHead.adelphiCap => (
            const Color(0xFFF2EEE6),
            const Color(0xFFF2EEE6),
            const Color(0xFF1B2D55),
            const Color(0xFF1B2D55),
            ShopBrand.adelphi,
            const Color(0xFF1B2D55),
          ),
          _ => (
            const Color(0xFFE6DDC8),
            const Color(0xFF1A1A1E),
            const Color(0xFFE8742A),
            const Color(0xFF1A1A1E),
            ShopBrand.nikea,
            const Color(0xFFE8742A),
          ),
        };
        final cap = Path()
          ..moveTo(-0.175, -0.96)
          ..quadraticBezierTo(-0.19, -1.13, 0, -1.135)
          ..quadraticBezierTo(0.19, -1.13, 0.175, -0.96)
          ..close();
        canvas.drawPath(cap, silhouette ? paint : (Paint()..color = base));
        if (!silhouette) {
          canvas.save();
          canvas.clipPath(cap);
          if (look.hat == AvatarHead.vaugirardCap) {
            _trunkCanvas(canvas, base);
          } else {
            canvas.drawRect(const Rect.fromLTRB(-0.2, -1.14, -0.06, -0.95), Paint()..color = panel);
            canvas.drawRect(const Rect.fromLTRB(0.06, -1.14, 0.2, -0.95), Paint()..color = panel);
          }
          canvas.drawRect(const Rect.fromLTRB(-0.2, -0.995, 0.2, -0.96), Paint()..color = band);
          canvas.restore();
          if (look.hat == AvatarHead.vaugirardCap) {
            canvas.drawRRect(
              RRect.fromRectAndRadius(const Rect.fromLTRB(-0.03, -1.085, 0.03, -1.01), const Radius.circular(0.008)),
              Paint()..color = const Color(0xFFD9AE5A),
            );
            brandMark(canvas, brand, const Offset(0, -1.047), 0.03, color: const Color(0xFF4A2E1A));
          } else {
            brandMark(canvas, brand, const Offset(0, -1.05), 0.038, color: mark);
          }
        }
        canvas.drawPath(
          Path()
            ..moveTo(-0.13, -0.965)
            ..quadraticBezierTo(0, -1.0, 0.13, -0.965)
            ..lineTo(0.11, -0.925)
            ..quadraticBezierTo(0, -0.95, -0.11, -0.925)
            ..close(),
          silhouette ? paint : (Paint()..color = visor),
        );
      case AvatarHead.clownWig ||
          AvatarHead.magicianHat ||
          AvatarHead.chefToque ||
          AvatarHead.sombrero ||
          AvatarHead.tricorn ||
          AvatarHead.operaHelmet ||
          AvatarHead.beekeeper ||
          AvatarHead.roosterHead ||
          AvatarHead.propellerBeanie ||
          AvatarHead.angelHalo ||
          AvatarHead.devilHorns ||
          AvatarHead.fishHead ||
          AvatarHead.dinoHood ||
          AvatarHead.astronautHelmet ||
          AvatarHead.unicornHorn ||
          AvatarHead.spaghettiHat ||
          AvatarHead.octopusHat ||
          AvatarHead.ufoHat ||
          AvatarHead.birthdayCake ||
          AvatarHead.rainbowAfro ||
          AvatarHead.flamingHair ||
          AvatarHead.starHalo ||
          AvatarHead.catOnHead || AvatarHead.blaugranaCap || AvatarHead.merenguesCap || AvatarHead.celestiCap || AvatarHead.diavoliCap || AvatarHead.redsCap || AvatarHead.rossoneriCap || AvatarHead.nerazzurriCap || AvatarHead.bianconeriCap || AvatarHead.giallorossiCap || AvatarHead.azzurriCap || AvatarHead.crown:
        _Oddities.hat(canvas, look.hat, silhouette ? paint : null);
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
      case AvatarAccessory.clownNose ||
          AvatarAccessory.parrot ||
          AvatarAccessory.rubberDuck ||
          AvatarAccessory.accordion ||
          AvatarAccessory.baguetteCigar ||
          AvatarAccessory.giantBowTie ||
          AvatarAccessory.pigeon ||
          AvatarAccessory.plungerSword:
        _Oddities.prop(canvas, look);
      case _ when CalcioTeam.of(look.accessory.name) != null:
        _Oddities.prop(canvas, look);
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
          ..shader = LookPainter._gs(LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_dark(coat, 0.7), _dark(coat, 0.15)],
          ), Rect.fromPoints(elbow, wrist).inflate(0.1)),
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
          ..shader = LookPainter._gs(LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_skinLight(skin, 0.1), _skinShade(skin, 0.35)],
          ), Rect.fromCenter(center: hand, width: 0.115, height: 0.075)),
      );
      if (look.dame && i == 1) {
        canvas.drawCircle(hand.translate(-0.02, -0.02), 0.012, Paint()..color = gold);
      }
    }
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

/// I pezzi di una persona nell'ordine in cui si dipingono: ognuno copre
/// quelli prima. L'ordine si decide solo qui.
enum LookLayer {
  /// Quello che sta sulle spalle ([BackItem], le ali comprese) e quello che
  /// il vezzo porta dietro (i palloncini, i fumogeni): dietro a tutto.
  back,

  /// Il bagliore intorno alla sagoma della testa ([HeadFx.glows]).
  headGlow,

  /// I capelli che stanno dietro la testa.
  hairBack,

  /// L'abito.
  body,

  /// Il collo, la camicia, la cravatta, i tatuaggi sul collo.
  neck,

  /// Le orecchie, la faccia, gli occhi, la bocca, il naso.
  face,

  /// La barba e i baffi.
  beard,

  /// I capelli davanti: la frangia, il ciuffo, le ciocche ai lati.
  hairFront,

  /// Gli occhiali, sulla linea degli occhi.
  glasses,

  /// L'effetto in testa ([HeadFx]): sopra il cappello, che però lo copre
  /// dove si incrociano.
  headFx,

  /// Il cappello, con quello che porta davanti (la spilla, la piuma).
  hat,

  /// Quello che sta sul petto: il garofano, la catena, il pappagallo.
  chest,

  /// Quello che sta in bocca: il sigaro, la sigaretta, la pipa.
  mouthProp,

  /// Quello che tiene in mano ([HeldItem]), con le mani che salgono dal bordo.
  held,

  /// L'effetto davanti a tutto ([FrontFx]).
  frontFx,
}

/// Come si dipinge una persona in questo momento.
@immutable
class _Style {
  /// Sotto i 110 px: la faccia semplice, che si legga al tavolo.
  final bool small;

  /// Per i test: solo i pezzi, senza inchiostro, luce né ombre.
  final bool bare;

  /// Il cartoon noir disegna da sé la pelle del collo e la faccia: i
  /// pittori di sempre portano solo i vestiti e gli oggetti.
  final bool noir;

  const _Style({this.small = false, this.bare = false, this.noir = false});
}
