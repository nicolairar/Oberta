import 'dart:math';

import 'narration_pack.dart';

/// Il mazzo delle morti: ogni azione esce una volta prima che una si ripeta.
///
/// Pescare a caso non basta: con dodici azioni la stessa può capitare due
/// partite di fila, e al tavolo sembra che il gioco ne conosca una sola.
class MethodDeck {
  final Random _random;
  final List<String> _pile = [];
  String? _last;

  MethodDeck([Random? random]) : _random = random ?? Random();

  /// Il mazzo di tutta la serata: dura da una partita all'altra.
  static final session = MethodDeck();

  /// Con [where] si pesca solo fra le azioni che vanno bene stavolta (quelle
  /// che un filmato sa mandare a vuoto, per dire): la più in alto nel mazzo,
  /// e le altre restano dove sono. Se nel mazzo non ce n'è nessuna, se ne
  /// prende una a caso fra quelle buone, e il mazzo resta com'è.
  StoryPiece draw(List<StoryPiece> methods, {bool Function(StoryPiece method)? where}) {
    _pile.removeWhere((id) => !methods.any((method) => method.id == id));
    if (_pile.isEmpty) _refill(methods);
    final fitting = [
      for (final method in methods)
        if (where == null || where(method)) method,
    ];
    if (fitting.isEmpty) throw ArgumentError('nessuna azione va bene');
    for (var i = _pile.length - 1; i >= 0; i--) {
      final id = _pile[i];
      if (!fitting.any((method) => method.id == id)) continue;
      _pile.removeAt(i);
      _last = id;
      return fitting.firstWhere((method) => method.id == id);
    }
    final others = [
      for (final method in fitting)
        if (method.id != _last) method,
    ];
    final pool = others.isEmpty ? fitting : others;
    final method = pool[_random.nextInt(pool.length)];
    _last = method.id;
    return method;
  }

  void _refill(List<StoryPiece> methods) {
    final fresh = [for (final method in methods) method.id]..shuffle(_random);
    // L'ultima uscita del giro prima non deve aprire il giro nuovo.
    if (fresh.length > 1 && fresh.last == _last) {
      fresh
        ..removeLast()
        ..insert(0, _last!);
    }
    _pile.addAll(fresh);
  }
}
