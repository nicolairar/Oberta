import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/online/online_services.dart';
import 'package:oberta/ui/screens/online/ranked_lobby.dart';

RoomMember _m(int seat) => RoomMember(profile: Profile(id: 'p$seat', handle: 'gino$seat'), seat: seat);

Widget _host(List<RoomMember> members, {double? countdown}) => MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: RepaintBoundary(
            key: const Key('shot'),
            child: SizedBox(width: 390, height: 420, child: LobbyTable(members: members, size: 12, myId: 'p1', countdown: countdown)),
          ),
        ),
      ),
    );

void main() {
  testWidgets('players walk in, sit, and walk out', (tester) async {
    await tester.pumpWidget(_host([for (var i = 1; i <= 7; i++) _m(i)]));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('7/12'), findsOneWidget);
    expect(find.text('gino3'), findsOneWidget);
    await tester.pumpWidget(_host([for (var i = 1; i <= 7; i++) if (i != 3) _m(i)]));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('gino3'), findsOneWidget, reason: 'still walking out');
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('gino3'), findsNothing);
    expect(find.text('6/12'), findsOneWidget);
  });

  testWidgets('a full table counts down', (tester) async {
    await tester.pumpWidget(_host([for (var i = 1; i <= 12; i++) _m(i)], countdown: 7.4));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const Key('ranked.countdown')), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
  });
}
