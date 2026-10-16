import 'dart:math';

/// Pesca a caso da un elenco ricordando le ultime uscite, così la stessa
/// battuta non torna finché non ne sono passate altre.
class Picker {
  final Random _random;
  final Map<String, List<int>> _recent = {};

  Picker([Random? random]) : _random = random ?? Random();

  /// [pool] dà un nome all'elenco: ogni elenco ha la sua memoria. Con
  /// [where] si pesca solo fra le voci che vanno bene stavolta, ma la
  /// memoria resta quella dell'elenco intero; se fra quelle non ce n'è una
  /// fresca, se ne ripete una.
  T pick<T>(String pool, List<T> options, {bool Function(T option)? where}) {
    final recent = _recent.putIfAbsent(pool, () => []);
    final memory = min(options.length - 1, max(1, options.length ~/ 2));
    final allowed = [
      for (var i = 0; i < options.length; i++)
        if (where == null || where(options[i])) i,
    ];
    if (allowed.isEmpty) throw ArgumentError('nessuna voce va bene in $pool');
    final fresh = [
      for (final i in allowed)
        if (!recent.contains(i)) i,
    ];
    final from = fresh.isEmpty ? allowed : fresh;
    final index = from[_random.nextInt(from.length)];
    recent.remove(index);
    recent.add(index);
    if (recent.length > memory) recent.removeAt(0);
    return options[index];
  }
}
