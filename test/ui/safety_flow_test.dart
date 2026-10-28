import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/l10n/app_language.dart';
import 'package:oberta/online/fake_online.dart';
import 'package:oberta/online/online_services.dart';
import 'package:oberta/settings/app_settings.dart';
import 'package:oberta/settings/settings_store.dart';
import 'package:oberta/ui/screens/online/online_room_screen.dart';
import 'package:oberta/ui/screens/settings_screen.dart';

import '../support/languages.dart';

void _usePhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

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
    message = await online.gameAs('bruno').sendChat(room.id, ChatChannel.lobby, 'sei una schiappa');
    me = await online.services.profiles.me();
  });

  Future<void> openRoom(WidgetTester tester) async {
    _usePhone(tester);
    await tester.pumpWidget(appIn(AppLanguage.it, OnlineRoomScreen(services: online.services, room: room, me: me)));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const Key('online.lobbyChat')), 150,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
  }

  Finder said(String text) => find.textContaining(text, findRichText: true);

  testWidgets('tenendo premuto un messaggio lo si segnala, con motivo e nota', (tester) async {
    await openRoom(tester);
    await tester.longPress(find.byKey(ValueKey('chat.hold-$message')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('safety.actions')), findsOneWidget);
    await tester.tap(find.byKey(const Key('safety.report')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('safety.reportDialog')), findsOneWidget);
    expect(find.text('Regole della community'), findsOneWidget, reason: 'le regole sono a un tocco');
    await tester.tap(find.byKey(const Key('safety.reason.language')));
    await tester.enterText(find.byKey(const Key('safety.note')), 'insulti');
    await tester.tap(find.byKey(const Key('safety.report.send')));
    await tester.pumpAndSettle();
    expect(find.text('Segnalazione ricevuta. Ce ne occupiamo noi.'), findsOneWidget);
    final report = online.reports.single;
    expect(report.target, 'bruno');
    expect(report.reason, ReportReason.language);
    expect(report.note, 'insulti');
    expect(report.messageText, 'sei una schiappa');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('bloccato dalla stanza, i suoi messaggi spariscono', (tester) async {
    await openRoom(tester);
    expect(said('sei una schiappa'), findsOneWidget);
    await tester.scrollUntilVisible(find.byKey(const Key('online.memberActions.bruno')), -150,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const Key('online.memberActions.bruno')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('safety.block')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('safety.block.confirm')));
    await tester.pumpAndSettle();
    expect(online.blocks, {('anna', 'bruno')});
    await tester.scrollUntilVisible(find.byKey(const Key('online.lobbyChat')), 150,
        scrollable: find.byType(Scrollable).first);
    expect(said('sei una schiappa'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a face in the room opens the sheet: befriend, mute the chat only here', (tester) async {
    await openRoom(tester);
    expect(said('sei una schiappa'), findsOneWidget);
    await tester.scrollUntilVisible(find.byKey(const Key('online.memberActions.bruno')), -150,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const Key('online.memberActions.bruno')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('player.header')), findsOneWidget);
    expect(find.text('Nella stanza'), findsOneWidget);
    expect(find.byKey(const Key('safety.befriend')), findsOneWidget);
    await tester.tap(find.byKey(const Key('safety.muteChat')));
    await tester.pumpAndSettle();
    expect(online.blocks, isEmpty, reason: 'muting the chat is not a block');
    await tester.scrollUntilVisible(find.byKey(const Key('online.lobbyChat')), 150,
        scrollable: find.byType(Scrollable).first);
    expect(said('sei una schiappa'), findsNothing);

    await tester.scrollUntilVisible(find.byKey(const Key('online.memberActions.bruno')), -150,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const Key('online.memberActions.bruno')));
    await tester.pumpAndSettle();
    expect(find.text('Riattiva la chat'), findsOneWidget);
    await tester.tap(find.byKey(const Key('safety.befriend')));
    await tester.pumpAndSettle();
    expect((await online.services.friends.list()).map((f) => f.other.id), contains('bruno'));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('dalle impostazioni: le regole, e i bloccati da sbloccare', (tester) async {
    _usePhone(tester);
    await online.safety.block('bruno');
    await tester.pumpWidget(appIn(
      AppLanguage.en,
      SettingsScreen(settings: AppSettings(MemorySettingsStore()), online: online.services, versionLabel: '1'),
    ));
    await tester.pumpAndSettle();
    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.byKey(const Key('settings.rules')), 150, scrollable: scrollable);
    await tester.tap(find.byKey(const Key('settings.rules')));
    await tester.pumpAndSettle();
    expect(find.text('Community rules'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('niko.tana@outlook.com'), 150,
        scrollable: find.byType(Scrollable).last);
    expect(find.text('niko.tana@outlook.com'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.byKey(const Key('settings.blocked')), 150, scrollable: scrollable);
    await tester.tap(find.byKey(const Key('settings.blocked')));
    await tester.pumpAndSettle();
    expect(find.text('bruno'), findsOneWidget);
    await tester.tap(find.byKey(const Key('safety.unblock.bruno')));
    await tester.pumpAndSettle();
    expect(online.blocks, isEmpty);
    expect(find.byKey(const Key('safety.noneBlocked')), findsOneWidget);
  });
}
