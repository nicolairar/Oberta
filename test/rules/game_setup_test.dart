import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/rules/game_setup.dart';
import 'package:oberta/rules/player.dart';
import 'package:oberta/rules/role.dart';

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
    final mafiosi = setup.players.where((p) => setup.roleOf(p).team == Team.mafia).toList();
    expect(mafiosi, hasLength(2));
    expect(setup.teammatesOf(mafiosi[0]), [mafiosi[1]]);
    expect(setup.teammatesOf(mafiosi[1]), [mafiosi[0]]);
  });

  test('a un tavolo pieno la famiglia si conosce tutta, qualunque ruolo abbia', () {
    final setup = GameSetup.deal(lobby: _players(16), random: Random(2));
    final family = setup.players.where((p) => setup.roleOf(p).team == Team.mafia).toList();
    expect(family, hasLength(4));
    expect(family.map(setup.roleOf), contains(Role.mafioso));
    for (final member in family) {
      expect(setup.teammatesOf(member), family.where((other) => other != member));
    }
  });

  test('il Pregiudicato non conosce nessuno, e nessuno conosce lui', () {
    final players = _players(6);
    final setup = GameSetup.fromRoles(Map.fromIterables(
      players,
      [Role.mafioso, Role.padrino, Role.pregiudicato, Role.cittadino, Role.cittadino, Role.detective],
    ));
    final convict = setup.players.firstWhere((p) => setup.roleOf(p) == Role.pregiudicato);
    expect(setup.teammatesOf(convict), isEmpty);
    for (final player in setup.players) {
      expect(setup.teammatesOf(player), isNot(contains(convict)), reason: player.name);
    }
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
