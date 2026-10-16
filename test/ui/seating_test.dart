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
import 'package:oberta/ui/widgets/player_avatar.dart';
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

  testWidgets('chi viene scelto si alza dalla sedia, sopra tutti, col timbro', (tester) async {
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
    final stack = tester.widget<Stack>(
      find.descendant(of: find.byType(PlayerGrid), matching: find.byType(Stack)).first,
    );
    expect(stack.children.last.key, ValueKey(players[3].id), reason: 'il prescelto sta sopra gli altri');
    await tester.tap(find.text(players[5].name), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(selected, players[3], reason: 'i morti non si scelgono');
    expect(tester.takeException(), isNull);
  });

  group('il tavolo da poker', () {
    const phones = [Size(327, 300), Size(327, 420), Size(345, 560), Size(382, 640)];

    test('da quattro a sedici, tutti ci stanno senza coprirsi, e ogni posto si tocca bene', () {
      for (final space in phones) {
        for (var count = 4; count <= maxRolePlayers; count++) {
          final layout = PokerTableLayout.fit(count, space);
          final boxes = [for (final seat in layout.seats) PokerTableLayout.footprint(seat.portrait, seat.size)];
          final why = '$count posti in $space';
          expect(boxes, hasLength(count), reason: why);
          for (final (i, box) in boxes.indexed) {
            expect(box.width, greaterThanOrEqualTo(44), reason: why);
            expect(box.height, greaterThanOrEqualTo(44), reason: why);
            expect((Offset.zero & space).inflate(0.5).contains(box.topLeft), isTrue, reason: '$why: $i esce');
            expect((Offset.zero & space).inflate(0.5).contains(box.bottomRight), isTrue, reason: '$why: $i esce');
            for (final other in boxes.skip(i + 1)) {
              final overlap = box.intersect(other);
              expect(overlap.width <= 1 || overlap.height <= 1, isTrue, reason: '$why: $i si sovrappone');
            }
          }
        }
      }
    });

    test('chi siede davanti è più grande di chi siede in fondo', () {
      final layout = PokerTableLayout.fit(8, const Size(327, 420));
      final back = layout.seats.first, front = layout.seats[4];
      expect(back.depth, lessThan(front.depth));
      expect(back.size, lessThan(front.size));
      expect(back.portrait.dy, lessThan(front.portrait.dy));
    });

    testWidgets('i posti non dipendono da chi ci siede', (tester) async {
      tester.view.physicalSize = const Size(375, 667) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      final players = _players(8);
      Future<Map<int, Offset>> seats(List<Player> order) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(),
            home: Scaffold(
              body: PlayerGrid(
                players: order,
                isAlive: (_) => true,
                knowledgeOf: (_) => Knowledge.none,
                selectable: order,
                shuffled: true,
              ),
            ),
          ),
        );
        await tester.pump();
        return {for (final (i, p) in order.indexed) i: tester.getTopLeft(find.text(p.name))};
      }

      final first = await seats(players);
      final second = await seats(players.reversed.toList());
      for (var i = 0; i < players.length; i++) {
        expect((first[i]! - second[i]!).dx.abs(), lessThan(40), reason: 'il posto $i resta dov\'è');
      }
      expect(tester.hasRunningAnimations, isFalse, reason: 'senza animazioni nessuno cammina');
    });

    testWidgets('al tavolo segreto i giocatori cambiano sedia, poi si fermano', (tester) async {
      tester.view.physicalSize = const Size(375, 667) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final players = _players(6);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: PlayerGrid(
              players: players,
              isAlive: (_) => true,
              knowledgeOf: (_) => Knowledge.none,
              selectable: players,
              shuffled: true,
            ),
          ),
        ),
      );
      final start = tester.getCenter(find.text(players[0].name));
      await tester.pump(const Duration(milliseconds: 500));
      final walking = tester.getCenter(find.text(players[0].name));
      await tester.pumpAndSettle();
      final seated = tester.getCenter(find.text(players[0].name));
      expect((start - seated).distance, greaterThan(50), reason: 'arriva da un\'altra sedia');
      expect((walking - seated).distance, greaterThan(1));
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('chi non c\'è più lascia la sedia vuota, col pugnale', (tester) async {
      tester.view.physicalSize = const Size(375, 667) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final players = _players(5);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: PlayerGrid(players: players, isAlive: (p) => p != players[2], knowledgeOf: (_) => Knowledge.none),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PlayerAvatar), findsNWidgets(4), reason: 'la sedia del morto è vuota');
      expect(find.text(PlayerAvatar.dagger), findsOneWidget);
      expect(find.text(players[2].name), findsOneWidget, reason: 'la targhetta resta');
    });
  });
}
