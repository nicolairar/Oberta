import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:omerta/rules/room_code.dart';

void main() {
  test('generateRoomCode produce 4 lettere maiuscole', () {
    final code = generateRoomCode(Random(42));
    expect(code.length, 4);
    expect(code, matches(RegExp(r'^[A-Z]{4}$')));
  });

  test('generateRoomCode con Random diversi produce codici diversi', () {
    final a = generateRoomCode(Random(1));
    final b = generateRoomCode(Random(2));
    expect(a, isNot(equals(b)));
  });
}
