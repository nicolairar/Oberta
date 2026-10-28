import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/l10n/app_language.dart';
import 'package:oberta/online/fake_online.dart';
import 'package:oberta/online/online_services.dart';
import 'package:oberta/ui/screens/online/online_room_screen.dart';

import '../support/languages.dart';

void main() {
  late FakeOnline online;
  late Room room;
  late Profile me;
  late String message;

  setUp(() async {
    BlockedPlayers.clear();
    online = FakeOnline(accountId: 'anna')
      ..signInReady(handle: 'anna')
      ..addPlayer('bruno', handle: 'bruno');
    online.slow = false;
    room = online.openRoomAs('anna', AppLanguage.it);
    online.joinAs('bruno', room.code);
    message = await online.gameAs('bruno').sendChat(room.id, ChatChannel.lobby, 'ciao');
    me = await online.services.profiles.me();
  });

  Future<void> openProfile(WidgetTester tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(appIn(AppLanguage.it, OnlineRoomScreen(services: online.services, room: room, me: me)));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const Key('online.lobbyChat')), 150,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.longPress(find.byKey(ValueKey('chat.hold-$message')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('safety.profile')));
    await tester.pumpAndSettle();
  }

  testWidgets('dal messaggio si apre il fascicolo pubblico, senza dati riservati', (tester) async {
    await openProfile(tester);
    expect(find.byKey(const Key('public.page')), findsOneWidget);
    expect(find.text('bruno'), findsWidgets);
    expect(find.byKey(const Key('public.big.0')), findsOneWidget);
    expect(find.text('Abbandonate'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('profilo privato: solo nome, livello e ritratto', (tester) async {
    online.hideProfile('bruno');
    await openProfile(tester);
    expect(find.byKey(const Key('public.closed')), findsOneWidget);
    expect(find.byKey(const Key('public.big.0')), findsNothing);
    expect(find.byKey(const Key('public.level')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  test('chi è bloccato non vede il profilo', () async {
    online.blocks.add(('bruno', 'anna'));
    expect(online.services.profiles.publicProfile('bruno'), throwsA(isA<OnlineException>()));
  });

  test('public_stats si legge senza campi riservati', () {
    final p = PublicProfile.fromJson({
      'id': 'x',
      'handle': 'bruno',
      'level': 7,
      'public': true,
      'games': 10,
      'wins': 4,
      'longest_streak': 3,
      'seconds': 3600,
      'featured': ['a', 'b'],
      'roles': [
        {'role': 'doctor', 'games': 5, 'wins': 2},
      ],
    });
    expect(p.profile.level, 7);
    expect(p.winRate, 0.4);
    expect(p.favouriteRole, 'doctor');
    expect(p.featured, ['a', 'b']);
  });
}
