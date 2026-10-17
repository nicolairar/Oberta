import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/table/seating.dart';

void main() {
  final seating = Seating.open([
    (name: 'Anna', profileId: 'profile-anna'),
    (name: 'Bruno', profileId: null),
    (name: 'Carla', profileId: 'profile-carla'),
  ]);

  test('i posti si danno in ordine e non dicono chi c\'è seduto', () {
    expect([for (final o in seating.occupants) o.seat], ['s1', 's2', 's3']);
    expect([for (final p in seating.players) p.id], ['s1', 's2', 's3']);
    expect(seating.playerAt('s2').name, 'Bruno');
  });

  test('dal posto al profilo e ritorno', () {
    expect(seating.profileOf('s1'), 'profile-anna');
    expect(seating.profileOf('s2'), isNull);
    expect(seating.seatOfProfile('profile-carla'), 's3');
    expect(seating.seatOfProfile('sconosciuto'), isNull);
    expect(() => seating.playerAt('s9'), throwsArgumentError);
  });

  test('torna uguale dal JSON', () {
    final back = Seating.fromJson(jsonDecode(jsonEncode(seating.toJson())) as Map<String, Object?>);
    expect(jsonEncode(back.toJson()), jsonEncode(seating.toJson()));
  });

  test('un posto per persona, un posto per profilo', () {
    expect(
      () => Seating([const Occupant(seat: 's1', name: 'A'), const Occupant(seat: 's1', name: 'B')]),
      throwsArgumentError,
    );
    expect(
      () => Seating([
        const Occupant(seat: 's1', name: 'A', profileId: 'p'),
        const Occupant(seat: 's2', name: 'B', profileId: 'p'),
      ]),
      throwsArgumentError,
    );
  });
}
