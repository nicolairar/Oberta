import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/main.dart';
import 'package:oberta/settings/app_settings.dart';
import 'package:oberta/settings/settings_store.dart';
import 'package:oberta/sound/sound_stage.dart';
import 'package:oberta/ui/widgets/flip_role_card.dart';

void _usePhone(WidgetTester tester, {List<Locale> speaks = const [Locale('it', 'IT')]}) {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
  addTearDown(tester.view.reset);
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  tester.platformDispatcher.localesTestValue = speaks;
}

void _expectItalianAlley() {
  expect(find.text('OBERTÀ'), findsOneWidget);
  expect(find.text('UN TELEFONO PER TUTTI'), findsOneWidget);
  expect(find.text('CREA STANZA'), findsOneWidget);
  expect(find.text('CREATE ROOM'), findsNothing);
}

void _expectEnglishAlley() {
  expect(find.text('OBERTÀ'), findsOneWidget, reason: 'il nome del gioco non si traduce');
  expect(find.text('TONIGHT ONLY'), findsOneWidget);
  expect(find.text('ONE PHONE FOR ALL'), findsOneWidget);
  expect(find.text('CREATE ROOM'), findsOneWidget);
  expect(find.text('PLAY WITH\nFRIENDS'), findsOneWidget);
  expect(find.text('RANKED'), findsOneWidget);
  expect(find.text('COMING SOON'), findsOneWidget);
  expect(find.text('CREA STANZA'), findsNothing);
}

void main() {
  tearDown(() => SoundStage.instance.enabled = true);

  testWidgets('un telefono in italiano apre il vicolo in italiano', (tester) async {
    _usePhone(tester, speaks: const [Locale('it', 'IT')]);
    await tester.pumpWidget(ObertaApp(settings: AppSettings(MemorySettingsStore())));
    await tester.pumpAndSettle();
    _expectItalianAlley();
    expect(find.byTooltip('Impostazioni'), findsOneWidget);
  });

  for (final locale in const [Locale('en', 'US'), Locale('de', 'DE'), Locale('fr', 'FR')]) {
    testWidgets('un telefono in $locale apre il vicolo in inglese', (tester) async {
      _usePhone(tester, speaks: [locale]);
      await tester.pumpWidget(ObertaApp(settings: AppSettings(MemorySettingsStore())));
      await tester.pumpAndSettle();
      _expectEnglishAlley();
      expect(find.byTooltip('Settings'), findsOneWidget);
    });
  }

  testWidgets('in inglese i manifesti e le impostazioni stanno in ogni schermo', (tester) async {
    for (final size in const [Size(320, 480), Size(375, 667), Size(667, 375), Size(430, 932)]) {
      _usePhone(tester, speaks: const [Locale('en', 'US')]);
      tester.view.physicalSize = size;
      await tester.pumpWidget(ObertaApp(settings: AppSettings(MemorySettingsStore())));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$size');
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'settings on $size');
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('dalle impostazioni si passa all\'inglese, e il vicolo cambia subito', (tester) async {
    _usePhone(tester);
    final store = MemorySettingsStore();
    await tester.pumpWidget(ObertaApp(settings: AppSettings(store)));
    await tester.pumpAndSettle();
    _expectItalianAlley();

    await tester.tap(find.byTooltip('Impostazioni'));
    await tester.pumpAndSettle();
    expect(find.text('Lingua'), findsOneWidget);
    expect(find.text('Automatica (telefono)'), findsOneWidget);
    expect(find.text('Italiano'), findsOneWidget);
    // La pagina sta nella vetrina della strada: si scorre fino alla voce.
    await tester.ensureVisible(find.text('English'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    // Il foglio stesso è già in inglese, e sotto il vicolo pure.
    expect(find.text('SETTINGS'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Automatic (phone)'), findsOneWidget);
    expect(find.text('Music and sound effects'), findsOneWidget);
    expect(store.values[AppSettings.languageKey], 'en');

    // Il foglio ora è alto (ci sono i volumi): lo si chiude come col gesto.
    Navigator.of(tester.element(find.text('SETTINGS'))).pop();
    await tester.pumpAndSettle();
    expect(find.text('SETTINGS'), findsNothing, reason: 'il foglio si è chiuso');
    _expectEnglishAlley();
  });

  testWidgets('la lingua scelta resta dopo un riavvio, anche se il telefono parla italiano', (tester) async {
    _usePhone(tester);
    final store = MemorySettingsStore({AppSettings.languageKey: 'en'});
    await tester.pumpWidget(ObertaApp(settings: AppSettings(store)));
    await tester.pumpAndSettle();
    _expectEnglishAlley();

    // Tornando ad "automatica" si torna alla lingua del telefono.
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    // La pagina sta nella vetrina della strada: si scorre fino alla voce.
    await tester.ensureVisible(find.text('Automatic (phone)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Automatic (phone)'));
    await tester.pumpAndSettle();
    expect(find.text('IMPOSTAZIONI'), findsOneWidget);
    expect(store.values.containsKey(AppSettings.languageKey), isFalse);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(ObertaApp(settings: AppSettings(store)));
    await tester.pumpAndSettle();
    _expectItalianAlley();
  });

  testWidgets('su un telefono inglese si può scegliere l\'italiano', (tester) async {
    _usePhone(tester, speaks: const [Locale('en', 'US')]);
    final store = MemorySettingsStore();
    await tester.pumpWidget(ObertaApp(settings: AppSettings(store)));
    await tester.pumpAndSettle();
    _expectEnglishAlley();

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    // La pagina sta nella vetrina della strada: si scorre fino alla voce.
    await tester.ensureVisible(find.text('Italiano'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Italiano'));
    await tester.pumpAndSettle();
    expect(find.text('IMPOSTAZIONI'), findsOneWidget);
    expect(store.values[AppSettings.languageKey], 'it');
  });

  testWidgets('l\'audio spento dalle impostazioni resta spento al riavvio', (tester) async {
    _usePhone(tester);
    final store = MemorySettingsStore();
    await tester.pumpWidget(ObertaApp(settings: AppSettings(store)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Impostazioni'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Musica ed effetti'));
    await tester.pumpAndSettle();
    expect(SoundStage.instance.enabled, isFalse);
    expect(store.values[AppSettings.soundKey], false);
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile).first).value, isFalse);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(ObertaApp(settings: AppSettings(store)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Impostazioni'));
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile).first).value, isFalse);
  });

  testWidgets('in inglese dal vicolo alla prima notte: narratore, carte, passaggio del telefono', (tester) async {
    _usePhone(tester, speaks: const [Locale('en', 'US')]);
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    await tester.pumpWidget(ObertaApp(settings: AppSettings(MemorySettingsStore())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CREATE ROOM'));
    await tester.pumpAndSettle();
    // Tre giocatori di prova al tavolo.
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('+ TEST'));
      await tester.pump();
    }
    await tester.tap(find.text('START'));
    await tester.pumpAndSettle();

    expect(find.text('NARRATOR'), findsOneWidget);
    expect(find.text('Who pulls\nthe strings?'), findsOneWidget);
    expect(find.text('You need at least 4 players'), findsNWidgets(2), reason: 'three at the table');
    await tester.tap(find.text('Automatic narrator'));
    await tester.pumpAndSettle();

    expect(find.text('THE CARDS'), findsOneWidget);
    expect(find.text('Automatic'), findsOneWidget);
    expect(find.text('The cards are dealt'), findsOneWidget);
    expect(find.textContaining('× '), findsWidgets, reason: 'i ruoli in gioco, in inglese');
    await tester.tap(find.text('CHECK YOUR CARDS'));
    await tester.pumpAndSettle();

    for (var card = 1; card <= 3; card++) {
      expect(find.text('CARD $card OF 3'), findsOneWidget);
      expect(find.text('PASS THE PHONE TO'), findsOneWidget);
      await tester.tap(find.text('IT\'S ME'));
      await tester.pumpAndSettle();
      expect(find.text('PRESS AND HOLD'), findsOneWidget);
      final gesture = await tester.startGesture(tester.getCenter(find.byType(FlipRoleCard)));
      await tester.pumpAndSettle();
      expect(find.textContaining(RegExp(r'^YOU.RE WITH THE (FAMILY|TOWN)$')), findsOneWidget);
      await gesture.up();
      await tester.pumpAndSettle();
      await tester.tap(find.text('GOT IT'));
      await tester.pumpAndSettle();
    }
    expect(find.text('NIGHT 1'), findsOneWidget);
    expect(find.text('THE NARRATOR SPEAKS'), findsOneWidget);
  });

  testWidgets('in inglese la collezione dei ruoli parla inglese', (tester) async {
    _usePhone(tester, speaks: const [Locale('en', 'US')]);
    await tester.pumpWidget(ObertaApp(settings: AppSettings(MemorySettingsStore())));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('The roles'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('The roles'));
    await tester.pumpAndSettle();
    expect(find.text('THE ROLES'), findsOneWidget);
    expect(find.text('VILLAGE'), findsOneWidget);
    expect(find.text('Every card stays face down until you win a game with that role.'), findsOneWidget);
    expect(find.byTooltip('Back'), findsOneWidget, reason: 'anche i pulsanti di sistema sono in inglese');
  });
}
