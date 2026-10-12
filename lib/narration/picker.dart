import 'dart:math';

/// Pesca a caso da un elenco ricordando le ultime uscite, così la stessa
/// battuta non torna finché non ne sono passate altre.
class Picker {
  final Random _random;
  final Map<String, List<int>> _recent = {};

  Picker([Random? random]) : _random = random ?? Random();

  /// [pool] dà un nome all'elenco: ogni elenco ha la sua memoria.
  T pick<T>(String pool, List<T> options) {
    final recent = _recent.putIfAbsent(pool, () => []);
    final memory = min(options.length - 1, max(1, options.length ~/ 2));
    final fresh = [
      for (var i = 0; i < options.length; i++)
        if (!recent.contains(i)) i,
    ];
    final index = fresh[_random.nextInt(fresh.length)];
    recent.add(index);
    if (recent.length > memory) recent.removeAt(0);
    return options[index];
  }
}
