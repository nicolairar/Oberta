import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/rules/game_setup.dart';
import 'package:oberta/rules/knowledge.dart';
import 'package:oberta/rules/player.dart';
import 'package:oberta/rules/role_assignment.dart';
import 'package:oberta/ui/screens/game_screen.dart';
import 'package:oberta/ui/seating.dart';
import 'package:oberta/ui/theme/app_theme.dart';
import 'package:oberta/ui/widgets/player_grid.dart';

List<Player> _players(int count) => [for (var i = 0; i < count; i++) Player(id: 'p$i', name: 'Giocatore${16 - i}')];

void main() {
  group('i posti', () {
    test('il tavolo pubblico va per nome, ed è sempre lo stesso', () {
      const zoe = Player(id: 'z', name: 'zoe');
      const ada = Player(id: 'a', name: 'Ada');
      const bruno = Player(id: 'b', name: 'Bruno');
      expect(publicSeating([zoe, bruno, ada]), [ada, bruno, zoe]);
      expect(publicSeating([bruno, ada, zoe]), [ada, bruno, zoe], reason: 'non dipende da come arrivano');
    });

    test('un tavolo segreto ha tutti, una volta sola, e non ripete gli ordini da evitare', () {
      final players = _players(4);
      final random = Random(7);
      var last = <Player>[];
      final public = publicSeating(players);
      for (var turn = 0; turn < 200; turn++) {
        final seats = secretSeating(players, random, avoid: [last, public]);
        expect(seats.toSet(), players.toSet());
        expect(seats, hasLength(players.length));
        expect(seats, isNot(orderedEquals(last)), reason: 'turno $turn');
        expect(seats, isNot(orderedEquals(public)), reason: 'turno $turn');
        last = seats;
      }
    });

    test('ogni posto segreto viene occupato da tutti, prima o poi', () {
      final players = _players(5);
      final random = Random(3);
      final seen = {for (var seat = 0; seat < players.length; seat++) seat: <Player>{}};
      for (var turn = 0; turn < 300; turn++) {
        final seats = secretSeating(players, random);
        for (final (seat, player) in seats.indexed) {
          seen[seat]!.add(player);
        }
      }
      for (final faces in seen.values) {
        expect(faces, players.toSet());
      }
    });
  });

  testWidgets('di notte il tavolo si rimescola a ogni turno; di giorno resta in ordine', (tester) async {
    tester.view.physicalSize = const Size(393, 852) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    final players = _players(maxRolePlayers);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: GameScreen(
          setup: GameSetup.fromRoles(Map.fromIterables(players, rolesForPlayerCount(players.length))),
          random: Random(1),
          seating: Random(5),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> tap(String label) async {
      while (find.text(label).evaluate().isEmpty && find.text('CONTINUA A LEGGERE').evaluate().isNotEmpty) {
        await tester.tap(find.text('CONTINUA A LEGGERE'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    List<Player> table() => tester.widget<PlayerGrid>(find.byType(PlayerGrid)).players;

    final public = publicSeating(players);
    await tap('COMINCIA LA NOTTE');
    final orders = <List<Player>>[];
    for (var turn = 0; turn < players.length; turn++) {
      await tap('SONO IO');
      final seats = table();
      expect(seats.toSet(), players.toSet(), reason: 'turno $turn: ci sono tutti');
      expect(seats, isNot(orderedEquals(public)), reason: 'turno $turn: non è il tavolo di giorno');
      if (orders.isNotEmpty) {
        expect(seats, isNot(orderedEquals(orders.last)), reason: 'turno $turn: cambia di mano in mano');
      }
      orders.add(seats);

      // Toccare una faccia non sposta le altre: il tavolo resta quello finché il turno dura.
      final grid = tester.widget<PlayerGrid>(find.byType(PlayerGrid));
      final open = grid.selectable ?? const <Player>[];
      if (open.isNotEmpty) {
        await tester.tap(find.text(open.first.name));
        await tester.pumpAndSettle();
        expect(table(), orderedEquals(seats), reason: 'turno $turn: scegliere non rimescola');
      }
      await tap('PASSO');
      await tap('FATTO');
    }
    expect(orders.map((order) => order.first).toSet().length, greaterThan(3), reason: 'il primo posto cambia faccia');

    await tap('APRI LA DISCUSSIONE');
    expect(table(), orderedEquals(public), reason: 'di giorno il tavolo è quello di tutti');
    await tap('AL VOTO');
    expect(table(), orderedEquals(public), reason: 'al voto, lo stesso tavolo del giorno');
  });

  testWidgets('la carta scelta si raddrizza, si accende e si alza sopra le altre', (tester) async {
    tester.view.physicalSize = const Size(375, 667) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final players = _players(6);
    Player? selected;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: PlayerGrid(
              players: players,
              isAlive: (player) => player != players[5],
              knowledgeOf: (_) => Knowledge.none,
              selectable: players.sublist(0, 5),
              selected: selected,
              stamp: 'IMPUTATO',
              onSelect: (player) => setState(() => selected = player),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('IMPUTATO'), findsNothing);
    await tester.tap(find.text(players[3].name));
    await tester.pumpAndSettle();
    expect(selected, players[3]);
    expect(find.text('IMPUTATO'), findsOneWidget);
    final rotation = tester.widget<AnimatedRotation>(
      find.ancestor(of: find.text(players[3].name), matching: find.byType(AnimatedRotation)),
    );
    expect(rotation.turns, 0);
    await tester.tap(find.text(players[5].name), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(selected, players[3], reason: 'i morti non si scelgono');
    expect(tester.takeException(), isNull);
  });
}
