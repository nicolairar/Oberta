import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omerta/main.dart';

void _usePhone(WidgetTester tester, Size size, {double top = 59, double bottom = 34}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = FakeViewPadding(top: top, bottom: bottom);
  addTearDown(tester.view.reset);
}

void _reduceAnimations(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

void main() {
  const phones = {
    'piccolo': (Size(375, 667), 20.0, 0.0),
    'grande': (Size(430, 932), 59.0, 34.0),
  };

  for (final MapEntry(key: name, value: (size, top, bottom)) in phones.entries) {
    testWidgets('sul telefono $name il vicolo mostra l\'insegna e le tre modalità', (tester) async {
      _usePhone(tester, size, top: top, bottom: bottom);
      await tester.pumpWidget(const OmertaApp());
      // L'apertura: il lampione, le lettere una dopo l'altra, i manifesti.
      for (var frame = 0; frame < 40; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull, reason: 'fotogramma $frame');
      }

      expect(find.text('OMERTÀ'), findsOneWidget);
      expect(find.text('UN TELEFONO PER TUTTI'), findsOneWidget);
      expect(find.text('CREA STANZA'), findsOneWidget);
      expect(find.text('UN TELEFONO\nA TESTA'), findsOneWidget);
      expect(find.text('CLASSIFICATA'), findsOneWidget);
      expect(find.text('PROSSIMAMENTE'), findsNWidgets(2));
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('un giro intero del vicolo si disegna senza inciampi', (tester) async {
    _usePhone(tester, const Size(393, 852));
    await tester.pumpWidget(const OmertaApp());
    // Sessantacinque secondi: il fiammifero, le boccate, le lettere in
    // corto, la berlina, il gatto, e il ciclo che ricomincia.
    for (var frame = 0; frame < 260; frame++) {
      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.takeException(), isNull, reason: 'fotogramma $frame');
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('nessuno schermo, per quanto strano, fa uscire la carta dai bordi', (tester) async {
    for (final size in const [Size(320, 480), Size(667, 375), Size(820, 1180)]) {
      _usePhone(tester, size, top: 0, bottom: 0);
      await tester.pumpWidget(const OmertaApp());
      await tester.pump(const Duration(seconds: 4));
      expect(tester.takeException(), isNull, reason: '$size');
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('con le animazioni ridotte il vicolo è fermo, e la stanza si apre lo stesso', (tester) async {
    _usePhone(tester, const Size(393, 852));
    _reduceAnimations(tester);
    await tester.pumpWidget(const OmertaApp());
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);

    await tester.tap(find.text('OMERTÀ'));
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse, reason: 'l\'insegna toccata non riparte');

    await tester.tap(find.text('CREA STANZA'));
    await tester.pumpAndSettle();
    expect(find.text('CODICE STANZA'), findsOneWidget);
  });

  testWidgets('un manifesto «prossimamente» risponde con una didascalia e non porta da nessuna parte',
      (tester) async {
    _usePhone(tester, const Size(393, 852));
    _reduceAnimations(tester);
    await tester.pumpWidget(const OmertaApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('CLASSIFICATA'));
    await tester.pumpAndSettle();
    expect(find.text('La classificata apre presto. Intanto fatti un nome.'), findsOneWidget);

    await tester.tap(find.text('UN TELEFONO\nA TESTA'));
    await tester.pumpAndSettle();
    expect(find.text('Un telefono a testa: arriva con la rete. Pazienza.'), findsOneWidget);
    expect(find.text('CREA STANZA'), findsOneWidget, reason: 'si resta nel vicolo');
    expect(find.text('CODICE STANZA'), findsNothing);
  });

  testWidgets('toccando CREA STANZA il nero si chiude a iride, poi si entra nella lobby', (tester) async {
    _usePhone(tester, const Size(393, 852));
    await tester.pumpWidget(const OmertaApp());
    await tester.pump(const Duration(seconds: 4));

    await tester.tap(find.text('CREA STANZA'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('CODICE STANZA'), findsNothing, reason: 'l\'iride si sta ancora chiudendo');
    for (var frame = 0; frame < 10; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('CODICE STANZA'), findsOneWidget);

    // Tornando indietro l'iride si riapre sul vicolo.
    await tester.pageBack();
    for (var frame = 0; frame < 10; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('CREA STANZA'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
