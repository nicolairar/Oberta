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

  StoryPiece draw(List<StoryPiece> methods) {
    _pile.removeWhere((id) => !methods.any((method) => method.id == id));
    if (_pile.isEmpty) {
      final fresh = [for (final method in methods) method.id]..shuffle(_random);
      // L'ultima uscita del giro prima non deve aprire il giro nuovo.
      if (fresh.length > 1 && fresh.last == _last) {
        fresh
          ..removeLast()
          ..insert(0, _last!);
      }
      _pile.addAll(fresh);
    }
    final id = _last = _pile.removeLast();
    return methods.firstWhere((method) => method.id == id);
  }
}
