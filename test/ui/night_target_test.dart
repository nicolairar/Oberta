import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/l10n/app_language.dart';
import 'package:oberta/rules/knowledge.dart';
import 'package:oberta/rules/player.dart';
import 'package:oberta/rules/player_view.dart';
import 'package:oberta/ui/screens/local/local_table.dart';
import 'package:oberta/ui/screens/online/game/seat_card.dart';

import '../support/languages.dart';

const _anna = Player(id: 'a', name: 'anna');
const _bruno = Player(id: 'b', name: 'bruno');
const _carla = Player(id: 'c', name: 'carla');
const _dario = Player(id: 'd', name: 'dario');
const _seats = [_anna, _bruno, _carla, _dario];

Widget _table({required bool day, List<SeatVote> votes = const []}) => appIn(
  AppLanguage.it,
  Scaffold(
    body: SizedBox(
      width: 400,
      height: 700,
      child: LocalTable(
        seats: _seats,
        numbers: {for (var i = 0; i < _seats.length; i++) _seats[i]: i + 1},
        holder: _anna,
        isAlive: (_) => true,
        knowledgeOf: (_) => Knowledge.none,
        votes: votes,
        day: day,
      ),
    ),
  ),
);

void _usePhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 700) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

SeatCard _card(WidgetTester tester, Player player) => tester.widget<SeatCard>(find.byKey(ValueKey('seat-${player.id}')));

void main() {
  testWidgets('at night the family pick never gets the ACCUSATO ribbon, only the night crosshair', (tester) async {
    _usePhone(tester);
    await tester.pumpWidget(_table(day: false, votes: const [
      (voter: _anna, target: _carla),
      (voter: _bruno, target: _carla),
    ]));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('ACCUSATO'), findsNothing);
    expect(_card(tester, _carla).accused, isFalse);
    expect(_card(tester, _carla).nightTarget, isTrue);
    expect(find.byKey(const Key('seat.nightTarget')), findsOneWidget);
    expect(find.byKey(const Key('seat.votes')), findsNothing, reason: 'the red vote count is the day vote');
    // The picker's seat still carries the white seat number of the target.
    expect(find.byKey(const ValueKey('pizzino-a')), findsOneWidget);
  });

  testWidgets('at night with no family votes there is no crosshair at all', (tester) async {
    _usePhone(tester);
    await tester.pumpWidget(_table(day: false));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('seat.nightTarget')), findsNothing);
    expect(find.text('ACCUSATO'), findsNothing);
  });

  testWidgets('by day the leader keeps the ACCUSATO ribbon and no crosshair', (tester) async {
    _usePhone(tester);
    await tester.pumpWidget(_table(day: true, votes: const [
      (voter: _anna, target: _carla),
      (voter: _bruno, target: _carla),
      (voter: _dario, target: _bruno),
    ]));
    await tester.pump(const Duration(milliseconds: 300));
    expect(_card(tester, _carla).accused, isTrue);
    expect(find.text('ACCUSATO'), findsOneWidget);
    expect(find.byKey(const Key('seat.nightTarget')), findsNothing);
  });
}
