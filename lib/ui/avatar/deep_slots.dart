/// I posti più cari della bottega: quello che sta intorno alla persona (la
/// scena dietro, le cose sulle spalle e in mano, gli effetti sopra la testa
/// e davanti a tutto) e i ritocchi alla faccia (i segni, la luce negli
/// occhi, la tinta dei capelli). Il nome di ogni valore è l'id di catalogo
/// (`shop_items.look_id`), quello che `profiles.avatar` salva sotto la sua
/// chiave: non cambia mai.
///
/// Si dipingono, dal fondo in avanti: la scena ([Aura]), le spalle
/// ([BackItem]), il bagliore dietro la testa ([HeadFx.glows]), la persona
/// con i suoi segni ([FaceExtra]), la luce negli occhi ([EyeShine]) e la
/// tinta ([HairDye]), l'effetto in testa ([HeadFx]), il cappello, le mani
/// ([HeldItem]) e l'effetto davanti ([FrontFx]); la cornice sta sopra.
library;

import 'dart:ui' show Color;

/// La scena dietro tutta la persona: riempie il ritratto.
enum Aura {
  none,
  inferno,
  harbourMoon,
  sunburst,
  neonAlley,
  cardRoomSmoke,
  varietyCurtain,
  vault,
  vesuvio,
  spaghettiStorm,
}

/// Quello che si porta sulle spalle, dietro il busto.
enum BackItem {
  none,
  violinCase,
  gildedWings,
  skeleton,
  parasol,
  saxophone,
  // Le ali di sempre, che erano un vezzo.
  angelWings,
  batWings,
  butterflyWings,
  dragonWings;

  /// Le ali della bottega delle stramberie: si disegnano coi pittori di sempre.
  bool get wing => this == angelWings || this == batWings || this == butterflyWings || this == dragonWings;

  /// Fanno spazio: la persona si rimpicciolisce un poco nel ritratto.
  bool get roomy => this != none && !wing;
}

/// Un effetto in testa: sopra il cappello, o un bagliore intorno ai capelli.
enum HeadFx {
  none,
  halo,
  starOrbit,
  sparks,
  hearts,
  coins,
  rainCloud,
  dizzyBirds,
  ghostGlow,
  emberGlow;

  /// Il colore del bagliore intorno alla sagoma, per quelli che lo sono.
  Color? get glow => switch (this) {
    ghostGlow => const Color(0xFF3FE0D0),
    emberGlow => const Color(0xFFFF8A3A),
    _ => null,
  };

  bool get glows => glow != null;

  /// Quanto sale sopra la cima della testa (o del cappello), nel quadrato.
  double get rise => switch (this) {
    halo => 0.1,
    rainCloud => 0.17,
    dizzyBirds => 0.07,
    hearts => 0.08,
    starOrbit || coins => 0.05,
    sparks => 0.04,
    _ => 0,
  };
}

/// I segni sulla faccia: se ne portano fino a due insieme.
enum FaceExtra {
  blush,
  tear,
  stitchScar,
  skullPaint,
  beautyStar,
  goldTooth,
  blackEye,
  lipstickKiss,
  plaster;

  /// Quanti se ne portano insieme.
  static const most = 2;
}

/// La luce negli occhi, sopra la pupilla.
enum EyeShine { none, glint, star, heart, spiral, lira, flame, diamond, crosshair }

/// La tinta dei capelli: una sfumatura dall'alto in basso, sopra la forma
/// e l'ombra dei capelli scelti allo specchio.
enum HairDye {
  none(Color(0x00000000), Color(0x00000000)),
  midnight(Color(0xFF5A6CE0), Color(0xFF7A2EA8)),
  neonPop(Color(0xFF3FE0D0), Color(0xFFFF4FA3)),
  sunset(Color(0xFFFFC94A), Color(0xFFC0401E)),
  tricolore(Color(0xFF2E9A4A), Color(0xFFD02A2E)),
  cherry(Color(0xFFD8283A), Color(0xFF2A0E18)),
  goldLeaf(Color(0xFFFFE08A), Color(0xFFB07A1E)),
  frost(Color(0xFFF4F6FF), Color(0xFF7AB8E8));

  final Color top;
  final Color bottom;

  const HairDye(this.top, this.bottom);

  /// Il tricolore ha anche la sua riga bianca in mezzo.
  List<Color> get colors => this == tricolore ? [top, const Color(0xFFF4F0E6), bottom] : [top, bottom];
}

/// Quello che si tiene in mano. Alcune cose (il gatto, l'orsacchiotto) si
/// tengono con tutte e due.
enum HeldItem {
  none,
  grappa,
  rose,
  revolver,
  cards,
  coupe,
  candle,
  cannolo,
  moka,
  fish,
  cat,
  teddy;

  bool get twoHanded => this == cat || this == teddy;
}

/// La mano: a sinistra o a destra del ritratto, come lo si guarda.
enum Hand {
  left('heldL'),
  right('heldR');

  /// La chiave in `profiles.avatar`.
  final String key;

  const Hand(this.key);

  Hand get other => this == left ? right : left;
}

/// Un effetto davanti a tutto, nel ritratto.
enum FrontFx { none, smokeRings, petals, sparkles, bats, yarn, banknotes, musicNotes, fireflies }
