import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/rules/game_setup.dart';
import 'package:oberta/rules/knowledge.dart';
import 'package:oberta/rules/player.dart';
import 'package:oberta/rules/role_assignment.dart';
import 'package:oberta/ui/screens/game_screen.dart';
import 'package:oberta/ui/avatar/seated_character.dart';
import 'package:oberta/ui/seating.dart';
import 'package:oberta/ui/theme/app_theme.dart';
import 'package:oberta/ui/widgets/player_avatar.dart';
import 'package:oberta/ui/widgets/player_grid.dart';
import 'package:oberta/ui/screens/local/local_table.dart';

import '../support/local_game.dart';

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

  test('il tavolo di una mano: chi ha il telefono in basso, gli altri rimescolati, mai lo stesso giro', () {
    final players = _players(6);
    final random = Random(11);
    var last = <Player>[];
    for (var hand = 0; hand < 300; hand++) {
      final holder = players[hand % players.length];
      final seats = handSeating(players, holder, random, avoid: [last]);
      expect(seats.first, holder, reason: 'mano $hand');
      expect(seats.toSet(), players.toSet());
      expect(seats, hasLength(players.length));
      if (last.isNotEmpty) {
        final start = last.indexOf(holder);
        expect(seats, isNot(orderedEquals([...last.skip(start), ...last.take(start)])), reason: 'mano $hand: il giro cambia');
      }
      last = seats;
    }
  });

  testWidgets('di notte il tavolo si rimescola a ogni mano; di giorno resta in ordine', (tester) async {
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

    List<Player> table() => tester.widget<LocalTable>(find.byType(LocalTable)).seats;

    final public = publicSeating(players);
    await tapLabel(tester, 'COMINCIA LA NOTTE');
    final orders = <List<Player>>[];
    for (var turn = 0; turn < players.length; turn++) {
      await tapKey(tester, 'local.itsMe');
      final seats = table();
      expect(seats.toSet(), players.toSet(), reason: 'turno $turn: ci sono tutti');
      expect(seats, isNot(orderedEquals(public)), reason: 'turno $turn: non è il tavolo di giorno');
      if (orders.isNotEmpty) {
        expect(seats, isNot(orderedEquals(orders.last)), reason: 'turno $turn: cambia di mano in mano');
      }
      orders.add(seats);

      // Toccare una faccia non sposta le altre: il tavolo resta quello finché la mano dura.
      final open = tester.widget<LocalTable>(find.byType(LocalTable)).selectable;
      if (open.isNotEmpty) {
        await tapSeat(tester, open.first);
        expect(table(), orderedEquals(seats), reason: 'turno $turn: scegliere non rimescola');
      }
      await tapKey(tester, 'local.pass');
      await tapKey(tester, 'local.done');
    }
    // Il posto accanto a chi guarda cambia faccia di mano in mano.
    expect(orders.map((order) => order[1]).toSet().length, greaterThan(3));

    await tapLabel(tester, 'APRI LA DISCUSSIONE');
    expect(table(), orderedEquals(public), reason: 'di giorno il tavolo è quello di tutti');
    await tapKey(tester, 'local.toVote');
    expect(table(), orderedEquals(public), reason: 'al voto, lo stesso tavolo del giorno');
  });

  void still(WidgetTester tester) {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }

  testWidgets('chi viene scelto si alza dalla sedia, sopra tutti, col timbro sul petto', (tester) async {
    tester.view.physicalSize = const Size(375, 667) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    still(tester);
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

    // Il timbro sta sul petto di chi si è alzato: la faccia resta scoperta.
    final seat = PokerTableLayout.fit(6, tester.getSize(find.byType(PlayerGrid))).seats[3];
    final grid = tester.getTopLeft(find.byType(PlayerGrid));
    final stamp = tester.getRect(find.text('IMPUTATO'));
    final chin = grid.dy + seat.base.dy - seat.size * (0.64 + 0.42);
    expect(stamp.top, greaterThan(chin), reason: 'il timbro non copre la faccia');

    await tester.tap(find.text(players[5].name), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(selected, players[3], reason: 'i morti non si scelgono');
    expect(tester.takeException(), isNull);
  });

  group('il tavolo da poker', () {
    // Il più piccolo è il voto su un telefono piccolo, il più grande la notte su uno grande.
    const phones = [Size(327, 350), Size(327, 405), Size(345, 560), Size(382, 640)];

    void fits(PokerTableLayout layout, Size space, String why) {
      final boxes = [for (final seat in layout.seats) PokerTableLayout.footprint(seat)];
      if (layout.own != null) boxes.add(layout.own!);
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

    test('da quattro a sedici, tutti ci stanno senza coprirsi, e ogni posto si tocca bene', () {
      for (final space in phones) {
        for (var count = 4; count <= maxRolePlayers; count++) {
          final layout = PokerTableLayout.fit(count, space);
          expect(layout.seats, hasLength(count));
          fits(layout, space, '$count posti in $space');
          // Chi tiene il telefono siede qui davanti: di fronte uno di meno.
          // Il tavolo personale, di notte, ha sempre un po' più di spazio.
          if (space.height < 400) continue;
          final mine = PokerTableLayout.fit(count - 1, space, own: true);
          expect(mine.seats, hasLength(count - 1));
          fits(mine, space, '$count posti in $space, col proprio');
        }
      }
    });

    test('chi siede ai lati è più vicino e più grande di chi siede di fronte', () {
      final layout = PokerTableLayout.fit(8, const Size(345, 560));
      final side = layout.seats.first, across = layout.seats[4];
      expect(side.depth, greaterThan(across.depth));
      expect(side.size, greaterThan(across.size * 1.3));
      expect(side.base.dy, greaterThan(across.base.dy));
      expect(side.base.dx, lessThan(layout.seats.last.base.dx), reason: 'si va da sinistra a destra');
    });

    testWidgets('i posti non dipendono da chi ci siede', (tester) async {
      tester.view.physicalSize = const Size(375, 667) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      still(tester);
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
        return {for (final (i, p) in order.indexed) i: tester.getCenter(find.text(p.name))};
      }

      final first = await seats(players);
      final second = await seats(players.reversed.toList());
      for (var i = 0; i < players.length; i++) {
        expect((first[i]! - second[i]!).distance, lessThan(1), reason: 'il posto $i resta dov\'è');
      }
      expect(tester.hasRunningAnimations, isFalse, reason: 'senza animazioni nessuno si muove');
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
      await tester.pump(const Duration(milliseconds: 600));
      final walking = tester.getCenter(find.text(players[0].name));
      await tester.pump(const Duration(milliseconds: 1500));
      final seated = tester.getCenter(find.text(players[0].name));
      await tester.pump(const Duration(seconds: 3));
      expect(tester.getCenter(find.text(players[0].name)), seated, reason: 'seduto, resta al suo posto');
      expect((start - seated).distance, greaterThan(50), reason: 'arriva da un\'altra sedia');
      expect((walking - seated).distance, greaterThan(1));
    });

    testWidgets('chi tiene il telefono guarda dalla sua sedia, qui davanti', (tester) async {
      tester.view.physicalSize = const Size(375, 667) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      still(tester);
      final players = _players(6);
      Player? picked;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: PlayerGrid(
              players: players,
              isAlive: (_) => true,
              knowledgeOf: (_) => Knowledge.none,
              viewer: players[2],
              selectable: players,
              onSelect: (player) => picked = player,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('TU'), findsOneWidget);
      final mine = tester.getCenter(find.text(players[2].name));
      for (final other in players) {
        if (other == players[2]) continue;
        expect(tester.getCenter(find.text(other.name)).dy, lessThan(mine.dy), reason: 'gli altri sono di là dal tavolo');
      }
      await tester.tap(find.text(players[2].name));
      expect(picked, players[2], reason: 'ci si può scegliere, se il ruolo lo permette');
    });

    testWidgets('chi non c\'è più lascia la sedia vuota, col pugnale', (tester) async {
      tester.view.physicalSize = const Size(375, 667) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      still(tester);
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
      final painters = [
        for (final paint in tester.widgetList<CustomPaint>(find.byType(CustomPaint)))
          if (paint.painter case final SeatedCharacterPainter painter) painter,
      ];
      expect(painters, hasLength(5));
      expect(painters.where((painter) => painter.empty), hasLength(1), reason: 'la sedia del morto è vuota');
      expect(find.text(PlayerAvatar.dagger), findsOneWidget);
      expect(find.text(players[2].name), findsOneWidget, reason: 'la targhetta resta');
    });
  });
}
