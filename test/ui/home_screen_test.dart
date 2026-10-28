import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/main.dart';
import 'package:oberta/ui/screens/home_screen.dart';
import 'package:oberta/ui/theme/app_theme.dart';

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
      await tester.pumpWidget(const ObertaApp());
      // L'apertura: il lampione, le lettere una dopo l'altra, i manifesti.
      for (var frame = 0; frame < 40; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull, reason: 'fotogramma $frame');
      }

      expect(find.text('OBERTÀ'), findsOneWidget);
      expect(find.text('UN TELEFONO PER TUTTI'), findsOneWidget);
      expect(find.text('CREA STANZA'), findsOneWidget);
      expect(find.text('GIOCA\nCON AMICI'), findsOneWidget);
      expect(find.text('ONLINE'), findsNothing, reason: 'la fascia ONLINE è stata tolta');
      expect(find.text('CLASSIFICATA'), findsOneWidget);
      expect(find.text('PROSSIMAMENTE'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('un giro intero del vicolo si disegna senza inciampi', (tester) async {
    _usePhone(tester, const Size(393, 852));
    await tester.pumpWidget(const ObertaApp());
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
      await tester.pumpWidget(const ObertaApp());
      await tester.pump(const Duration(seconds: 4));
      expect(tester.takeException(), isNull, reason: '$size');
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('con le animazioni ridotte il vicolo è fermo, e la stanza si apre lo stesso', (tester) async {
    _usePhone(tester, const Size(393, 852));
    _reduceAnimations(tester);
    await tester.pumpWidget(const ObertaApp());
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);

    await tester.tap(find.text('OBERTÀ'));
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse, reason: 'l\'insegna toccata non riparte');

    await tester.tap(find.text('CREA STANZA'));
    await tester.pumpAndSettle();
    expect(find.text('IL TAVOLO'), findsOneWidget);
  });

  testWidgets('il manifesto «prossimamente» risponde con una didascalia e non porta da nessuna parte',
      (tester) async {
    _usePhone(tester, const Size(393, 852));
    _reduceAnimations(tester);
    await tester.pumpWidget(const ObertaApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('CLASSIFICATA'));
    await tester.pumpAndSettle();
    expect(find.text('La classificata apre presto. Intanto fatti un nome.'), findsOneWidget);
    expect(find.text('CREA STANZA'), findsOneWidget, reason: 'si resta nel vicolo');
    expect(find.text('IL TAVOLO'), findsNothing);
  });

  testWidgets('«Gioca con amici» porta al gioco online, che senza server dice di non esserci', (tester) async {
    _usePhone(tester, const Size(393, 852));
    _reduceAnimations(tester);
    await tester.pumpWidget(const ObertaApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('GIOCA\nCON AMICI'));
    await tester.pumpAndSettle();
    expect(find.text('NON DISPONIBILE'), findsOneWidget);
    expect(find.textContaining('Un telefono per tutti funziona come sempre'), findsOneWidget);

    await tester.tap(find.byKey(const Key('cafe.back')));
    await tester.pumpAndSettle();
    expect(find.text('CREA STANZA'), findsOneWidget);
  });

  testWidgets('toccando CREA STANZA il nero si chiude a iride, poi si entra nella lobby', (tester) async {
    _usePhone(tester, const Size(393, 852));
    await tester.pumpWidget(const ObertaApp());
    await tester.pump(const Duration(seconds: 4));

    await tester.tap(find.text('CREA STANZA'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('IL TAVOLO'), findsNothing, reason: 'l\'iride si sta ancora chiudendo');
    for (var frame = 0; frame < 10; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('IL TAVOLO'), findsOneWidget);

    // Tornando indietro l'iride si riapre sul vicolo.
    // Il telefono dei test parla italiano: il pulsante si chiama «Indietro», non «Back».
    await tester.tap(find.byType(BackButton));
    for (var frame = 0; frame < 10; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('CREA STANZA'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('dalla lobby si torna nel vicolo trascinando dal bordo, come su ogni iPhone', (tester) async {
    _usePhone(tester, const Size(393, 852));
    _reduceAnimations(tester);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await tester.pumpWidget(const ObertaApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('CREA STANZA'));
      await tester.pumpAndSettle();
      expect(find.text('IL TAVOLO'), findsOneWidget);

      await tester.dragFrom(const Offset(4, 420), const Offset(330, 0));
      await tester.pumpAndSettle();
      expect(find.text('IL TAVOLO'), findsNothing);
      expect(find.text('CREA STANZA'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('la targhetta delle impostazioni c\'è solo se qualcuno la ascolta', (tester) async {
    _usePhone(tester, const Size(375, 667), top: 20, bottom: 0);
    _reduceAnimations(tester);
    await tester.pumpWidget(MaterialApp(theme: buildAppTheme(), home: const HomeScreen()));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Impostazioni'), findsNothing);

    var opened = 0;
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: HomeScreen(onSettings: () => opened++),
    ));
    await tester.pumpAndSettle();
    final plate = tester.getRect(find.byTooltip('Impostazioni'));
    expect(plate.top, greaterThanOrEqualTo(20), reason: 'sotto la tacca');
    expect(plate.right, lessThanOrEqualTo(375));
    expect(plate.width, greaterThanOrEqualTo(44), reason: 'abbastanza grande per un dito');

    await tester.tap(find.byTooltip('Impostazioni'));
    expect(opened, 1);
    expect(find.text('CREA STANZA'), findsOneWidget, reason: 'si resta nel vicolo');
  });

  testWidgets('dalla targhetta si aprono le impostazioni, con suoni e i ruoli', (tester) async {
    _usePhone(tester, const Size(393, 852), top: 47, bottom: 34);
    _reduceAnimations(tester);
    await tester.pumpWidget(const ObertaApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Impostazioni'));
    await tester.pumpAndSettle();
    expect(find.text('IMPOSTAZIONI'), findsOneWidget);
    expect(find.text('Musica ed effetti'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('settings.roles')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings.roles')));
    await tester.pumpAndSettle();
    expect(find.text('I RUOLI'), findsOneWidget);
    expect(find.byKey(const Key('roles.card.detective')), findsOneWidget);
  });
}
