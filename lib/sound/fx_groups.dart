/// Gli effetti sonori registrati (CC0, vedi `assets/sfx/CREDITS.md`).
///
/// Ogni gruppo ha più registrazioni dello stesso genere: ogni volta ne esce
/// una diversa, così il gioco non suona mai uguale a sé stesso.
/// Generato dal catalogo scaricato: non si modifica a mano.
library;

enum FxGroup {
  rooster(4),
  birds(6),
  church(7),
  market(2),
  cart(1),
  crickets(5),
  owl(3),
  wind(4),
  dog(3),
  cat(5),
  thunder(2),
  rain(2),
  siren(5),
  clock(7),
  foghorn(2),
  train(3),
  carpass(1),
  carhorn(2),
  screech(2),
  revolver(3),
  shotgun(3),
  tommy(2),
  ricochet(2),
  scream(9),
  ouch(5),
  groan(3),
  gasp(3),
  laugh(5),
  boo(2),
  cheer(3),
  gavel(3),
  drumroll(2),
  trombone(3),
  slidewhist(3),
  boing(3),
  splash(3),
  explosion(3),
  pianocrash(2),
  glassbreak(3),
  cough(3),
  kiss(5),
  wolfwhistle(3),
  fallwhist(3),
  faint(3),
  cashreg(2),
  typewriter(2),
  phone(2),
  door(2),
  whisper(2),
  heartbeat(2),
  fuse(3),
  match(2),
  cigar(2),
  coin(2),
  whoosh(2),
  chuckle(4),
  surprise(1),
  tada(2),
  harmonica(2);

  /// Quante registrazioni ci sono.
  final int count;

  const FxGroup(this.count);

  /// Il file della registrazione [take] (da 1 a [count]).
  String asset(int take) => 'sfx/fx_${name}_$take.m4a';
}
