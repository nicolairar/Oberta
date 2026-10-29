import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/ui/widgets/noir_modal.dart';
import 'package:oberta/ui/screens/online/game/noir_role_card.dart';
import 'package:oberta/main.dart';
import 'package:oberta/rules/game_setup.dart';
import 'package:oberta/ui/screens/role_deal_screen.dart';
import 'package:oberta/ui/screens/vote_mode_screen.dart';
import 'package:oberta/roster/roster_storage.dart';
import 'package:oberta/roster/roster_store.dart';

void _usePhoneScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1179, 2556);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  // I fondali animati non si fermano mai: nei test si chiede al sistema di
  // ridurre le animazioni, come farebbe un utente dalle impostazioni.
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

/// Apre il tavolo e ci fa sedere [players] giocatori di prova.
Future<void> _openLobbyWith(WidgetTester tester, int players) async {
  await tester.pumpWidget(const ObertaApp());
  await tester.tap(find.text('CREA STANZA'));
  await tester.pumpAndSettle();
  for (var i = 0; i < players; i++) {
    await tester.tap(find.text('+ TEST'));
    await tester.pumpAndSettle();
  }
}

void main() {
  // L'elenco dell'app dura quanto il processo: ogni test parte dal suo,
  // vuoto e in memoria, senza la gente del test di prima.
  setUp(() => RosterStore.instance = RosterStore(MemoryRosterStorage()));

  testWidgets('non si parte finché il tavolo è troppo piccolo', (tester) async {
    _usePhoneScreen(tester);
    await _openLobbyWith(tester, 2);

    final start = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'AVVIA'));
    expect(start.onPressed, isNull);
    expect(find.text('2 AL TAVOLO'), findsOneWidget);
    expect(find.text('Ne manca ancora uno per cominciare.'), findsOneWidget);
  });

  testWidgets('narratore automatico: ognuno guarda la sua carta, poi cala la notte', (tester) async {
    _usePhoneScreen(tester);
    await _openLobbyWith(tester, 3);

    await tester.tap(find.text('AVVIA'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Narratore automatico'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('vote.next')));
    await tester.pumpAndSettle();
    expect(find.text('Le carte sono servite'), findsOneWidget);

    await tester.tap(find.text('GUARDATE LE CARTE'));
    await tester.pumpAndSettle();

    for (var card = 1; card <= 3; card++) {
      expect(find.text('CARTA $card DI 3'), findsOneWidget);
      await tester.tap(find.text('SONO IO'));
      await tester.pumpAndSettle();
      final done = find.byKey(const Key('local.gotIt'));
      expect(tester.widget<NoirModalButton>(done).action.onPressed, isNull, reason: 'carta non ancora vista');

      final gesture = await tester.startGesture(tester.getCenter(find.byType(NoirRoleCard)));
      await tester.pumpAndSettle();
      expect(find.text('TIENI PREMUTO'), findsNothing, reason: 'a dito premuto la carta è scoperta');
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.text('TIENI PREMUTO'), findsOneWidget, reason: 'al rilascio torna coperta');

      await tester.tap(done);
      await tester.pumpAndSettle();
    }

    expect(find.text('NOTTE 1'), findsOneWidget);
    expect(find.text('PARLA IL NARRATORE'), findsOneWidget);
  });

  testWidgets('dopo il narratore si sceglie come si vota: si parte a voce, il segreto vale per una partita', (tester) async {
    _usePhoneScreen(tester);
    await _openLobbyWith(tester, 3);
    await tester.tap(find.text('AVVIA'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Narratore automatico'));
    await tester.pumpAndSettle();

    expect(find.text('Come vota la piazza?'), findsOneWidget);
    expect(find.text('Voto segreto sul telefono'), findsOneWidget);
    expect(find.byKey(const Key('vote.hint.voice')), findsOneWidget, reason: 'si parte dal voto a voce');
    expect(find.textContaining('Pareggio · nessuno'), findsOneWidget);
    await tester.tap(find.byKey(const Key('vote.secret')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('vote.hint.secret')), findsOneWidget);
    expect(find.textContaining('mai chi ha votato chi'), findsOneWidget);
    await tester.tap(find.byKey(const Key('vote.next')));
    await tester.pumpAndSettle();
    expect(tester.widget<RoleDealScreen>(find.byType(RoleDealScreen)).setup.vote, LocalVote.secret);

    // Si torna indietro e si riparte: la scelta non si ricorda, di nuovo a voce.
    Navigator.of(tester.element(find.byType(RoleDealScreen))).pop();
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byType(VoteModeScreen))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Narratore automatico'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('vote.hint.voice')), findsOneWidget);
    await tester.tap(find.byKey(const Key('vote.next')));
    await tester.pumpAndSettle();
    expect(tester.widget<RoleDealScreen>(find.byType(RoleDealScreen)).setup.vote, LocalVote.voice);
  });

  testWidgets('narratore sorteggiato: non gioca ed è lui a leggere il copione', (tester) async {
    _usePhoneScreen(tester);
    await _openLobbyWith(tester, 4);

    await tester.tap(find.text('AVVIA'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sorteggiato dal tamburo'));
    await tester.pumpAndSettle();
    expect(find.text('IL NARRATORE È'), findsOneWidget);

    await tester.tap(find.text('CONTINUA'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('vote.next')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('GUARDATE LE CARTE'));
    await tester.pumpAndSettle();

    for (var card = 1; card <= 3; card++) {
      expect(find.text('CARTA $card DI 3'), findsOneWidget);
      await tester.tap(find.text('SONO IO'));
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(tester.getCenter(find.byType(NoirRoleCard)));
      await tester.pumpAndSettle();
      await gesture.up();
      await tester.pumpAndSettle();
      await tester.tap(find.text('HO VISTO'));
      await tester.pumpAndSettle();
    }

    expect(find.textContaining(RegExp(r'^LEGGE .+, AD ALTA VOCE$')), findsOneWidget);
    expect(find.byIcon(Icons.visibility), findsOneWidget);
  });

  testWidgets('con tre al tavolo il narratore umano non è disponibile', (tester) async {
    _usePhoneScreen(tester);
    await _openLobbyWith(tester, 3);

    await tester.tap(find.text('AVVIA'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Scelto dal gruppo'));
    await tester.pumpAndSettle();

    expect(find.text('CHI RACCONTA?'), findsNothing);
    expect(find.text('Servono almeno 4 giocatori'), findsNWidgets(2));
  });
}
