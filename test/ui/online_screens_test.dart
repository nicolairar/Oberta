import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/l10n/app_language.dart';
import 'package:oberta/online/fake_online.dart';
import 'package:oberta/ui/screens/online/friends_screen.dart';
import 'package:oberta/ui/screens/online/join_room_screen.dart';
import 'package:oberta/ui/screens/online/online_screen.dart';
import 'package:oberta/ui/widgets/settings_sheet.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../support/languages.dart';

void _usePhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  // La città dietro resta ferma, così pumpAndSettle arriva in fondo.
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

void main() {
  late FakeOnline online;

  setUp(() {
    online = FakeOnline()
      ..addPlayer('bruno', handle: 'bruno', displayName: 'Bruno')
      ..addPlayer('carla', handle: 'carla', displayName: 'Carla');
  });

  Future<void> open(WidgetTester tester, Widget screen, {AppLanguage language = AppLanguage.it}) async {
    _usePhone(tester);
    await tester.pumpWidget(appIn(language, screen));
    await tester.pumpAndSettle();
  }

  testWidgets('senza server l\'online dice che non c\'è', (tester) async {
    await open(tester, const OnlineScreen());
    expect(find.text('NON DISPONIBILE'), findsOneWidget);
    expect(find.text('Entra con Apple'), findsNothing);
  });

  testWidgets('in inglese: unavailable', (tester) async {
    await open(tester, const OnlineScreen(), language: AppLanguage.en);
    expect(find.text('UNAVAILABLE'), findsOneWidget);
  });

  testWidgets('chi non è entrato trova Apple e Google, e dopo il primo accesso si fa il profilo', (tester) async {
    online.auth.suggestedName = 'Anna Rossi';
    await open(tester, OnlineScreen(services: online.services));
    expect(find.text('CHI SEI?'), findsOneWidget);
    expect(find.text('Entra con Apple'), findsOneWidget);
    expect(find.text('Entra con Google'), findsOneWidget);

    await tester.tap(find.text('Entra con Google'));
    await tester.pumpAndSettle();
    expect(find.text('IL TUO PROFILO'), findsOneWidget);
    expect(find.text('Anna Rossi'), findsOneWidget, reason: 'il nome dato da Google è già scritto');

    await tester.enterText(find.byKey(const Key('online.handle')), 'bruno');
    await tester.tap(find.text('SALVA'));
    await tester.pumpAndSettle();
    expect(find.text('Questo nome unico è già preso.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('online.handle')), 'Anna_R2');
    expect(find.text('annar'), findsOneWidget, reason: 'solo lettere, in minuscolo');
    await tester.tap(find.text('SALVA'));
    await tester.pumpAndSettle();
    expect(find.text('GIOCA CON AMICI'), findsOneWidget);
    expect(find.text('APRI UNA STANZA'), findsOneWidget);
    expect(online.profileOf('me')!.handle, 'annar');
  });

  testWidgets('senza Apple né Google sul telefono lo dice', (tester) async {
    online.auth
      ..appleAvailable = false
      ..googleAvailable = false;
    await open(tester, OnlineScreen(services: online.services));
    expect(find.text('Su questo telefono non c\'è ancora un modo per entrare.'), findsOneWidget);
  });

  testWidgets('chiudere la finestra di Apple non è un errore', (tester) async {
    online.auth.cancelNext = true;
    await open(tester, OnlineScreen(services: online.services));
    await tester.tap(find.text('Entra con Apple'));
    await tester.pumpAndSettle();
    expect(find.text('CHI SEI?'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('la stanza: codice grande, QR, chi entra arriva dal vivo, e si chiede l\'amicizia', (tester) async {
    online.signInReady(handle: 'anna', displayName: 'Anna');
    await open(tester, OnlineScreen(services: online.services));
    await tester.tap(find.text('APRI UNA STANZA'));
    await tester.pumpAndSettle();

    expect(find.text('LA STANZA'), findsOneWidget);
    final code = tester.widget<SelectableText>(find.byKey(const Key('online.roomCode'))).data!;
    expect(code, hasLength(6));
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('1 su 16 al tavolo'), findsOneWidget);
    expect(find.text('PADRONE DI CASA'), findsOneWidget);
    expect(find.byTooltip('Chiedi l\'amicizia'), findsNothing, reason: 'non a sé stessi');

    online.joinAs('bruno', code);
    await tester.pumpAndSettle();
    expect(find.text('2 su 16 al tavolo'), findsOneWidget);
    expect(find.text('Bruno'), findsOneWidget);

    await tester.scrollUntilVisible(find.byTooltip('Chiedi l\'amicizia'), 100, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byTooltip('Chiedi l\'amicizia'));
    await tester.pumpAndSettle();
    expect(find.text('Richiesta mandata a Bruno.'), findsOneWidget);
    expect(find.byTooltip('Chiedi l\'amicizia'), findsNothing);

    final start = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'INIZIA · PRESTO'));
    expect(start.onPressed, isNull, reason: 'la partita online non c\'è ancora');

    await tester.scrollUntilVisible(find.text('ESCI DALLA STANZA'), 100, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('ESCI DALLA STANZA'));
    await tester.pumpAndSettle();
    expect(find.text('APRI UNA STANZA'), findsOneWidget);
    expect(online.joinAs('bruno', code).hostId, 'bruno', reason: 'chi resta fa da padrone di casa');
  });

  testWidgets('entrare con un codice, scritto o letto dal QR', (tester) async {
    online.signInReady(handle: 'anna', displayName: 'Anna');
    final room = online.openRoomAs('bruno', AppLanguage.it);

    final me = online.profileOf('me')!;
    await open(tester, JoinRoomScreen(services: online.services, me: me, scanner: (_) async => room.code));

    await tester.enterText(find.byKey(const Key('online.joinCode')), 'ZZZ');
    await tester.tap(find.text('ENTRA'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Il codice ha sei caratteri'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('online.joinCode')), 'ZZZZZZ');
    await tester.tap(find.text('ENTRA'));
    await tester.pumpAndSettle();
    expect(find.text('Nessuna stanza con questo codice.'), findsOneWidget);

    await tester.tap(find.text('Inquadra il QR'));
    await tester.pumpAndSettle();
    expect(find.text('LA STANZA'), findsOneWidget);
    expect(find.text('2 su 16 al tavolo'), findsOneWidget);
  });

  testWidgets('gli amici: cercare, chiedere, rispondere', (tester) async {
    online
      ..signInReady(handle: 'anna', displayName: 'Anna')
      ..requestFrom('carla');
    await open(tester, FriendsScreen(services: online.services));
    expect(find.text('RICHIESTE'), findsOneWidget);
    expect(find.text('Carla'), findsOneWidget);
    expect(find.textContaining('Nessun amico, per ora'), findsOneWidget);

    await tester.tap(find.byTooltip('Accetta'));
    await tester.pumpAndSettle();
    expect(find.text('RICHIESTE'), findsNothing);
    expect(find.text('Tu e Carla ora siete amici.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('online.search')), 'bru');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('@bruno'), findsOneWidget);
    await tester.tap(find.text('Aggiungi'));
    await tester.pumpAndSettle();
    expect(find.text('IN ATTESA'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('online.search')), 'zzz');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Nessuno con questo nome.'), findsOneWidget);
  });

  testWidgets('dalle impostazioni si esce dall\'account', (tester) async {
    online.signInReady();
    await open(tester, Scaffold(body: SettingsSheet(online: online.services)));
    await tester.scrollUntilVisible(find.text('Esci dall\'account'), 100, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Esci dall\'account'));
    await tester.pumpAndSettle();
    expect(online.auth.signedIn, isFalse);
    expect(find.text('Esci dall\'account'), findsNothing);
  });

  testWidgets('chi non è entrato non vede l\'uscita nelle impostazioni', (tester) async {
    await open(tester, Scaffold(body: SettingsSheet(online: online.services)));
    expect(find.text('Esci dall\'account'), findsNothing);
  });
}
