/// Cosa succede quando i mafiosi votano vittime diverse e finiscono pari.
enum TieBreak {
  /// Nessuno muore.
  nobody,

  /// Sorteggio tra i più votati.
  random,

  /// Il voto del capo vale doppio: è il Padrino finché è vivo, poi il primo
  /// della famiglia, in ordine di posto, che vota l'agguato.
  boss,
}

class GameSettings {
  final TieBreak mafiaTieBreak;
  final Duration discussion;

  const GameSettings({
    this.mafiaTieBreak = TieBreak.random,
    this.discussion = const Duration(minutes: 3),
  });
}
