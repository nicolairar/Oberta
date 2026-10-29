import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/rules/player.dart';
import 'package:oberta/ui/screens/local/local_table.dart';
import 'package:oberta/ui/screens/online/game/seat_card.dart';

/// Moving through the one-phone game in tests: the buttons are found by
/// their keys, the seats by `seat-<id>`.

/// Taps a button by label; when the script is longer than the screen, reads
/// it to the end first, as the narrator would.
Future<void> tapLabel(WidgetTester tester, String label) async {
  while (find.text(label).evaluate().isEmpty && find.text('CONTINUA A LEGGERE').evaluate().isNotEmpty) {
    await tester.tap(find.text('CONTINUA A LEGGERE'));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

/// Taps the seat of [player] on the table on screen.
Future<void> tapSeat(WidgetTester tester, Player player) async {
  await tester.tap(find.byKey(ValueKey('seat-${player.id}')));
  await tester.pumpAndSettle();
}

/// The name on the privacy curtain ("4 DARIO").
String? curtainName(WidgetTester tester) {
  final name = find.byKey(const Key('local.curtainName'));
  if (name.evaluate().isEmpty) return null;
  return tester.widget<Text>(name).data;
}

/// The table on screen, seat by seat: who sits where (seat 0 at the bottom)
/// and the number on each card.
List<({String name, int? number})> tableOnScreen(WidgetTester tester) {
  final table = tester.widget<LocalTable>(find.byType(LocalTable));
  return [
    for (final player in table.seats)
      (name: player.name, number: tester.widget<SeatCard>(find.byKey(ValueKey('seat-${player.id}'))).number),
  ];
}

/// One night turn: the curtain names [actor], the phone is taken, a seat is
/// picked and confirmed (or the turn is passed), then the phone goes down.
Future<void> nightTurn(WidgetTester tester, Player actor, {Player? pick, int? number}) async {
  expect(curtainName(tester), contains(actor.name.toUpperCase()), reason: 'tocca a ${actor.name}');
  if (number != null) expect(curtainName(tester), '$number ${actor.name.toUpperCase()}');
  await tapKey(tester, 'local.itsMe');
  if (pick == null) {
    await tapKey(tester, 'local.pass');
  } else {
    await tapSeat(tester, pick);
    await tapKey(tester, 'local.confirm');
  }
  await tapKey(tester, 'local.done');
}

/// The secret vote: every living voter, in seat order, taps a seat and
/// confirms (or abstains when [votes] has no entry for them).
Future<void> secretVote(WidgetTester tester, List<Player> voters, Map<Player, Player?> votes) async {
  for (final voter in voters) {
    final status = tester.widget<Text>(find.byKey(const Key('local.voterTurn')));
    expect(status.data, contains(voter.name), reason: 'vota ${voter.name}');
    final target = votes[voter];
    if (target == null) {
      await tapKey(tester, 'local.abstain');
    } else {
      await tapSeat(tester, target);
      await tapKey(tester, 'local.castVote');
    }
  }
}

/// The vote out loud is over: whoever holds the phone taps the condemned
/// and confirms, or the tie when [condemned] is null.
Future<void> voiceVerdict(WidgetTester tester, Player? condemned) async {
  if (condemned == null) {
    await tapKey(tester, 'local.tie');
  } else {
    await tapSeat(tester, condemned);
    await tapKey(tester, 'local.condemn');
  }
}

/// "Use a power": [user] taps their own face in front of everyone, confirms,
/// takes the phone behind the curtain and taps "it's me".
Future<void> openPower(WidgetTester tester, Player user) async {
  await tapKey(tester, 'game.usePower');
  await tapSeat(tester, user);
  await tapKey(tester, 'game.powerConfirm');
  expect(curtainName(tester), contains(user.name.toUpperCase()), reason: 'la tenda di ${user.name}');
  await tapKey(tester, 'local.itsMe');
}
