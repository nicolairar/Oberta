import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/online/online_services.dart';
import 'package:oberta/ui/screens/online/ranked_lobby.dart';

const _me = Profile(id: 'p1', handle: 'gino1');

Widget _host(int seated, {double? countdown}) => MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: RepaintBoundary(
            key: const Key('shot'),
            child: SizedBox(width: 390, height: 420, child: LobbyTable(seated: seated, size: 12, me: _me, countdown: countdown)),
          ),
        ),
      ),
    );

void main() {
  testWidgets('strangers walk in and out as silhouettes, never with a name', (tester) async {
    await tester.pumpWidget(_host(7));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('7/12'), findsOneWidget);
    expect(find.text('gino1'), findsOneWidget, reason: 'only my own name');
    expect(find.byKey(const Key('ranked.stranger')), findsNWidgets(6));
    await tester.pumpWidget(_host(6));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('ranked.stranger')), findsNWidgets(6), reason: 'still walking out');
    await tester.pump(const Duration(seconds: 2));
    expect(find.byKey(const Key('ranked.stranger')), findsNWidgets(5));
    expect(find.text('6/12'), findsOneWidget);
  });

  test('chairs fill in a scattered order, each once', () {
    final order = LobbyTable.fillOrder(12);
    expect(order.first, 0);
    expect(order.toSet().length, 12);
    expect(order.toSet(), {for (var i = 0; i < 12; i++) i});
  });

  testWidgets('a full table counts down', (tester) async {
    await tester.pumpWidget(_host(12, countdown: 7.4));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const Key('ranked.countdown')), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
  });
}
