/// Le cornici dei posti e gli inchiostri dei nomi: due posti della bottega
/// che non si indossano addosso ma intorno. Il nome di ogni valore è l'id di
/// catalogo (`shop_items.look_id`), quello che `profiles.avatar` salva sotto
/// `border` e `nameStyle`: non cambia mai.
library;

/// La cornice intorno alla carta del posto (e al ritratto).
enum SeatBorder {
  none,
  brass,
  velvet,
  mosaic,
  filmStrip,
  suits,
  artDeco,
  barbedWire,
  roseThorns,
  neonPink,
  flame,
  neonPulse,
  // Quelle che non si vendono: le regalano gli obiettivi delle missioni.
  badge,
  noose,
  laurel;

  /// Le leggendarie si muovono.
  bool get animated => this == flame || this == neonPulse;
}

/// Il colore (o lo stile) del nome sulla targhetta e in chat.
enum NameStyle {
  plain,
  crimson,
  emerald,
  sapphire,
  violet,
  goldFoil,
  silverFoil,
  tramonto,
  neonGlow,
  shimmer,
  inferno,
  // Quelli che non si vendono: li regalano gli obiettivi delle missioni.
  moonlight,
  bloodInk,
  siren;

  bool get animated => this == shimmer || this == inferno;
}
