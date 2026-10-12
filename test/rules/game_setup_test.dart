import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:omerta/rules/game_setup.dart';
import 'package:omerta/rules/player.dart';
import 'package:omerta/rules/role.dart';

List<Player> _players(int count) => [for (var i = 0; i < count; i++) Player(id: 'p$i', name: 'P$i')];

void main() {
  test('il narratore umano non riceve un ruolo', () {
    final lobby = _players(6);
    final setup = GameSetup.deal(lobby: lobby, narrator: lobby[2], random: Random(1));
    expect(setup.narrator, lobby[2]);
    expect(setup.players, hasLength(5));
    expect(setup.players, isNot(contains(lobby[2])));
  });

  test('con il narratore automatico giocano tutti', () {
    final lobby = _players(6);
    final setup = GameSetup.deal(lobby: lobby, random: Random(1));
    expect(setup.narrator, isNull);
    expect(setup.players, lobby);
  });

  test('i mafiosi si conoscono tra loro, senza includere se stessi', () {
    final setup = GameSetup.deal(lobby: _players(9), random: Random(5));
    final mafiosi = setup.players.where((p) => setup.roleOf(p) == Role.mafioso).toList();
    expect(mafiosi, hasLength(2));
    expect(setup.teammatesOf(mafiosi[0]), [mafiosi[1]]);
    expect(setup.teammatesOf(mafiosi[1]), [mafiosi[0]]);
  });

  test('chi non è mafioso non conosce nessuno', () {
    final setup = GameSetup.deal(lobby: _players(9), random: Random(5));
    for (final player in setup.players.where((p) => setup.roleOf(p).team == Team.citizens)) {
      expect(setup.teammatesOf(player), isEmpty, reason: player.name);
    }
  });

  test('la distribuzione non si può modificare da fuori', () {
    final setup = GameSetup.deal(lobby: _players(4), random: Random(1));
    expect(() => setup.roles.clear(), throwsUnsupportedError);
  });
}
