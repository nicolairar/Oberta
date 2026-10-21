import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/l10n/app_language.dart';
import 'package:oberta/online/fake_online.dart';
import 'package:oberta/online/online_services.dart';
import 'package:oberta/ui/screens/online/friends_screen.dart';
import 'package:oberta/ui/screens/online/join_room_screen.dart';
import 'package:oberta/ui/screens/online/online_room_screen.dart';
import 'package:oberta/ui/screens/online/online_screen.dart';
import 'package:oberta/ui/screens/online/ranked_queue_screen.dart';

import '../../support/desktop_shots.dart';

/// Gli amici e la classificata su desktop: ogni schermata a 1080p e 720p,
/// fotografata in build/screens/desktop.
void main() {
  FakeOnline world() {
    final online = FakeOnline(accountId: 'anna')
      ..signInReady(handle: 'anna', level: 7)
      ..slow = false;
    for (final name in ['bruno', 'carla', 'dario', 'elena', 'fabio', 'gina']) {
      online.addPlayer(name, handle: name);
    }
    return online;
  }

  Future<void> settle(WidgetTester tester, Future<void> Function() work) => tester.runAsync(work);

  for (final MapEntry(key: label, value: size) in desktopSizes.entries) {
    testWidgets('l\'ingresso online su desktop $label', (tester) async {
      await useDesktop(tester, size);
      final online = FakeOnline();
      await shootDesktopPage(tester, 'online_login_$label', (_) => OnlineScreen(services: online.services));
    });

    testWidgets('la sala online su desktop $label', (tester) async {
      await useDesktop(tester, size);
      final online = world();
      await shootDesktopPage(tester, 'online_hub_$label', (_) => OnlineScreen(services: online.services));
    });

    testWidgets('entrare con un codice su desktop $label', (tester) async {
      await useDesktop(tester, size);
      final online = world();
      final room = online.openRoomAs('bruno', AppLanguage.it);
      late final Profile me;
      await settle(tester, () async => me = await online.services.profiles.me());
      await shootDesktopPage(tester, 'join_room_$label', (_) => JoinRoomScreen(services: online.services, me: me));
      await tester.enterText(find.byKey(const Key('online.joinCode')), room.code.substring(0, 4));
      await desktopFrames(tester, 5);
      await saveDesktopShot(tester, 'join_room_typing_$label');
      await tester.enterText(find.byKey(const Key('online.joinCode')), room.code);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await desktopFrames(tester, 10);
      expect(find.byKey(const Key('online.roomCode')), findsOneWidget, reason: 'Invio entra nella stanza');
    });

    testWidgets('gli amici su desktop $label', (tester) async {
      await useDesktop(tester, size);
      final online = world();
      for (final name in ['bruno', 'carla', 'dario']) {
        online.requestFrom(name);
        await settle(tester, () => online.services.friends.request(name));
      }
      online.requestFrom('elena');
      await settle(tester, () => online.services.friends.request('fabio'));
      await shootDesktopPage(tester, 'friends_$label', (_) => FriendsScreen(services: online.services));
      await tester.enterText(find.byKey(const Key('online.search')), 'g');
      await tester.pump(const Duration(milliseconds: 400));
      await desktopFrames(tester, 5);
      await saveDesktopShot(tester, 'friends_search_$label');
    });

    testWidgets('la stanza degli amici su desktop $label', (tester) async {
      await useDesktop(tester, size);
      final online = world();
      final room = online.openRoomAs('anna', AppLanguage.it);
      for (final name in ['bruno', 'carla', 'dario']) {
        online.joinAs(name, room.code);
      }
      late final Profile me;
      await settle(tester, () async {
        me = await online.services.profiles.me();
        await online.gameAs('bruno').sendChat(room.id, ChatChannel.lobby, 'Chi dà le carte stasera?');
        await online.gameAs('carla').sendChat(room.id, ChatChannel.lobby, 'Aspettiamo Elena, arriva tra un minuto.');
      });
      await shootDesktopPage(tester, 'online_room_$label', (_) => OnlineRoomScreen(services: online.services, room: room, me: me));
    });

    testWidgets('la classificata su desktop $label', (tester) async {
      await useDesktop(tester, size);
      final online = world();
      await shootDesktopPage(tester, 'ranked_entry_$label', (_) => RankedQueueScreen(services: online.services));
      await tester.tap(find.byKey(const Key('ranked.start')));
      await desktopFrames(tester, 30);
      await saveDesktopShot(tester, 'ranked_lobby_$label');
      expect(find.byKey(const Key('ranked.table')), findsOneWidget);
    });
  }
}
