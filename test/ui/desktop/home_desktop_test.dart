import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/online/fake_online.dart';
import 'package:oberta/online/incoming_links.dart';
import 'package:oberta/online/online_models.dart';
import 'package:oberta/ui/desktop/home_handle_picker.dart';
import 'package:oberta/ui/screens/home_screen.dart';
import 'package:oberta/ui/screens/online/sign_in_sheet.dart';

import '../../support/desktop_shots.dart';

/// Un pulsante «go» che apre [open] sopra una pagina vuota.
Widget _opener(void Function(BuildContext) open) => Builder(
  builder: (context) => Scaffold(
    backgroundColor: const Color(0xFF07070B),
    body: TextButton(onPressed: () => open(context), child: const Text('go')),
  ),
);

/// Le icone vere nelle foto (la tela di prova non le ha).
Future<void> _icons() async {
  const file =
      '/opt/homebrew/Caskroom/flutter/3.47.7/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
  if (!File(file).existsSync()) return;
  final loader = FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(File(file).readAsBytesSync())));
  await loader.load();
}

void main() {
  setUpAll(_icons);
  for (final MapEntry(key: label, value: size) in desktopSizes.entries) {
    testWidgets('il vicolo su desktop $label, senza accesso', (tester) async {
      await useDesktop(tester, size);
      final online = FakeOnline();
      await tester.pumpWidget(
        desktopApp(HomeScreen(onSettings: () {}, services: online.services, links: IncomingLinks())),
      );
      await desktopFrames(tester, 40);
      expect(find.byKey(const Key('home.signIn')), findsOneWidget);
      expect(find.byKey(const Key('desk.settings')), findsOneWidget);
      await saveDesktopShot(tester, 'home_$label');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('il vicolo su desktop $label, dentro, col mouse su un manifesto', (tester) async {
      await useDesktop(tester, size);
      final online = FakeOnline()..signInReady(handle: 'anna', level: 7, coins: 1250);
      await tester.pumpWidget(
        desktopApp(HomeScreen(onSettings: () {}, services: online.services, links: IncomingLinks())),
      );
      await desktopFrames(tester, 40);
      expect(find.byKey(const Key('home.badge')), findsOneWidget);
      expect(find.byKey(const Key('desk.shop')), findsOneWidget);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.text('GIOCA\nCON AMICI').hitTestable().first, warnIfMissed: false));
      await desktopFrames(tester, 4);
      await saveDesktopShot(tester, 'home_signed_in_$label');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('l\'accesso su desktop $label', (tester) async {
      await useDesktop(tester, size);
      final online = FakeOnline();
      online.auth.steamAvailable = true;
      online.auth.appleAvailable = false;
      online.auth.googleAvailable = false;
      var signedIn = false;
      await tester.pumpWidget(
        desktopApp(
          _opener((context) async {
            signedIn = await showSignInSheet(context, services: online.services);
          }),
        ),
      );
      await tester.tap(find.text('go'));
      await desktopFrames(tester, 6);
      expect(find.byKey(const Key('online.signInSteam')), findsOneWidget);
      await saveDesktopShot(tester, 'sign_in_$label');
      // INVIO entra con Steam.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await desktopFrames(tester, 6);
      expect(signedIn, isTrue);
    });

    testWidgets('il nome unico su desktop $label', (tester) async {
      await useDesktop(tester, size);
      final online = FakeOnline()..signInReady();
      Profile? saved;
      await tester.pumpWidget(
        desktopApp(
          _opener((context) async {
            saved = await showDeskHandlePicker(
              context,
              services: online.services,
              profile: const Profile(id: 'me'),
            );
          }),
        ),
      );
      await tester.tap(find.text('go'));
      await desktopFrames(tester, 6);
      await tester.enterText(find.byKey(const Key('online.handle')), 'don_vito');
      await desktopFrames(tester, 6);
      await saveDesktopShot(tester, 'handle_picker_$label');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await desktopFrames(tester, 6);
      expect(saved?.handle, 'don_vito');
    });
  }

  testWidgets('chi entra con Steam trova il nome Steam già scritto; se è preso, nomi liberi a un tocco', (tester) async {
    await useDesktop(tester, desktopSizes['1080p']!);
    final online = FakeOnline()..signInReady();
    online.addPlayer('other', handle: 'donvitocorle');
    Profile? saved;
    await tester.pumpWidget(
      desktopApp(
        _opener((context) async {
          saved = await showDeskHandlePicker(
            context,
            services: online.services,
            profile: const Profile(id: 'me', onSteam: true, steamPersona: 'Don Vito Corleone'),
          );
        }),
      ),
    );
    await tester.tap(find.text('go'));
    await desktopFrames(tester, 6);
    expect(find.byKey(const Key('desk.handleFromSteam')), findsOneWidget);
    final field = tester.widget<TextField>(find.byKey(const Key('online.handle')));
    expect(field.controller!.text, 'donvitocorle');
    await desktopFrames(tester, 6);
    expect(find.byKey(const Key('desk.handleSuggestion.donvitocorl1')), findsOneWidget);
    await saveDesktopShot(tester, 'handle_picker_steam_taken');
    await tester.tap(find.byKey(const Key('desk.handleSuggestion.donvitocorl1')));
    await desktopFrames(tester, 6);
    await tester.tap(find.byKey(const Key('desk.handleSave')));
    await desktopFrames(tester, 6);
    expect(saved?.handle, 'donvitocorl1');
  });

  testWidgets('il nome Steam libero: basta salvare', (tester) async {
    await useDesktop(tester, desktopSizes['1080p']!);
    final online = FakeOnline()..signInReady();
    Profile? saved;
    await tester.pumpWidget(
      desktopApp(
        _opener((context) async {
          saved = await showDeskHandlePicker(
            context,
            services: online.services,
            profile: const Profile(id: 'me', onSteam: true, steamPersona: 'Fredo ☕'),
          );
        }),
      ),
    );
    await tester.tap(find.text('go'));
    await desktopFrames(tester, 6);
    await tester.tap(find.byKey(const Key('desk.handleSave')));
    await desktopFrames(tester, 6);
    expect(saved?.handle, 'fredo');
  });
}
