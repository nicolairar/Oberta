import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omerta/main.dart';
import 'package:omerta/ui/widgets/flip_role_card.dart';

void _usePhoneScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1179, 2556);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<void> _openLobbyWith(WidgetTester tester, int testPlayers) async {
  await tester.pumpWidget(const OmertaApp());
  await tester.tap(find.text('CREA STANZA'));
  await tester.pumpAndSettle();
  for (var i = 0; i < testPlayers; i++) {
    await tester.tap(find.text('+ TEST'));
    await tester.pump();
  }
}

void main() {
  testWidgets('non si parte finché il tavolo è troppo piccolo', (tester) async {
    _usePhoneScreen(tester);
    await _openLobbyWith(tester, 1);

    final start = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'AVVIA'));
    expect(start.onPressed, isNull);
    expect(find.textContaining('Ne mancano ancora 1'), findsOneWidget);
  });

  testWidgets('narratore automatico: ognuno guarda la sua carta, poi cala la notte', (tester) async {
    _usePhoneScreen(tester);
    await _openLobbyWith(tester, 2);

    await tester.tap(find.text('AVVIA'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Narratore automatico'));
    await tester.pumpAndSettle();
    expect(find.text('Le carte sono pronte'), findsOneWidget);

    await tester.tap(find.text('DISTRIBUISCI LE CARTE'));
    await tester.pumpAndSettle();

    for (var card = 1; card <= 3; card++) {
      expect(find.text('CARTA $card DI 3'), findsOneWidget);
      await tester.tap(find.text('SONO IO'));
      await tester.pumpAndSettle();
      final done = find.widgetWithText(ElevatedButton, 'HO VISTO');
      expect(tester.widget<ElevatedButton>(done).onPressed, isNull, reason: 'carta non ancora vista');

      final gesture = await tester.startGesture(tester.getCenter(find.byType(FlipRoleCard)));
      await tester.pumpAndSettle();
      expect(find.text('TIENI PREMUTO'), findsNothing, reason: 'a dito premuto la carta è scoperta');
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.text('TIENI PREMUTO'), findsOneWidget, reason: 'al rilascio torna coperta');

      await tester.tap(done);
      await tester.pumpAndSettle();
    }

    expect(find.text('NOTTE 1'), findsOneWidget);
    expect(find.text('LEGGETE AD ALTA VOCE'), findsOneWidget);
  });

  testWidgets('narratore sorteggiato: non gioca ed è lui a leggere il copione', (tester) async {
    _usePhoneScreen(tester);
    await _openLobbyWith(tester, 3);

    await tester.tap(find.text('AVVIA'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sorteggiato dalla ruota'));
    await tester.pumpAndSettle();
    expect(find.text('IL NARRATORE È'), findsOneWidget);

    await tester.tap(find.text('CONTINUA'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DISTRIBUISCI LE CARTE'));
    await tester.pumpAndSettle();

    for (var card = 1; card <= 3; card++) {
      expect(find.text('CARTA $card DI 3'), findsOneWidget);
      await tester.tap(find.text('SONO IO'));
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(tester.getCenter(find.byType(FlipRoleCard)));
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
    await _openLobbyWith(tester, 2);

    await tester.tap(find.text('AVVIA'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Scelto dal gruppo'));
    await tester.pumpAndSettle();

    expect(find.text('CHI RACCONTA?'), findsNothing);
    expect(find.text('Servono almeno 4 giocatori'), findsNWidgets(2));
  });
}
