/// Cosa succede quando i mafiosi votano vittime diverse e finiscono pari.
/// Nessun voto vale doppio: il Padrino conta come tutti.
enum TieBreak {
  /// Nessuno muore.
  nobody,

  /// Sorteggio tra i più votati.
  random,
}

class GameSettings {
  static const defaultNight = Duration(seconds: 30);
  static const defaultDiscussion = Duration(seconds: 60);
  static const defaultVote = Duration(seconds: 30);

  final TieBreak mafiaTieBreak;

  /// Quanto dura la notte (anche la prima).
  final Duration night;
  final Duration discussion;
  final Duration vote;

  const GameSettings({
    this.mafiaTieBreak = TieBreak.random,
    this.night = defaultNight,
    this.discussion = defaultDiscussion,
    this.vote = defaultVote,
  });
}
