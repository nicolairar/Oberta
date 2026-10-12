import 'dart:math';

const _letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';

/// Genera un codice stanza di 4 lettere maiuscole (es. "WXPL").
String generateRoomCode([Random? random]) {
  final rng = random ?? Random();
  return List.generate(4, (_) => _letters[rng.nextInt(_letters.length)]).join();
}
