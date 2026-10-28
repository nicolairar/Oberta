import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/l10n/app_language.dart';
import 'package:oberta/online/fake_online.dart';
import 'package:oberta/online/online_services.dart';
import 'package:oberta/settings/app_settings.dart';
import 'package:oberta/settings/settings_store.dart';
import 'package:oberta/ui/screens/settings_screen.dart';

import '../support/languages.dart';

void main() {
  late FakeOnline online;
  late List<String> shared;

  setUp(() {
    online = FakeOnline()..addPlayer('bruno', handle: 'bruno');
    shared = [];
  });

  Future<void> open(WidgetTester tester, {AppLanguage language = AppLanguage.it}) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(appIn(
      language,
      SettingsScreen(
        settings: AppSettings(MemorySettingsStore()),
        online: online.services,
        versionLabel: '1.0.0 (40)',
        shareExport: (name, json) async => shared.add(json),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 150, scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('la pagina ha tutte le sezioni', (tester) async {
    online.signInReady(handle: 'anna');
    await open(tester);
    for (final title in ['AUDIO', 'LINGUA', 'GIOCO', 'ACCOUNT', 'PRIVACY E DATI', 'INFORMAZIONI']) {
      await scrollTo(tester, find.text(title));
      expect(find.text(title), findsOneWidget);
    }
    expect(find.text('Sei dentro come @anna'), findsOneWidget);
    expect(find.text('1.0.0 (40)'), findsOneWidget);
  });

  testWidgets('scaricare i dati consegna il JSON al foglio di condivisione', (tester) async {
    online.signInReady(handle: 'anna');
    await open(tester);
    await scrollTo(tester, find.byKey(const Key('settings.export')));
    await tester.tap(find.byKey(const Key('settings.export')));
    await tester.pumpAndSettle();
    expect(shared, hasLength(1));
    final data = jsonDecode(shared.single) as Map<String, dynamic>;
    expect(data['profile']['handle'], 'anna');
  });

  testWidgets('un errore nello scaricare lo dice', (tester) async {
    online.signInReady(handle: 'anna');
    online.account.failNext = const OnlineException(OnlineFailure.network);
    await open(tester);
    await scrollTo(tester, find.byKey(const Key('settings.export')));
    await tester.tap(find.byKey(const Key('settings.export')));
    await tester.pumpAndSettle();
    expect(shared, isEmpty);
    expect(find.textContaining('Non è stato possibile scaricare'), findsOneWidget);
  });

  testWidgets('eliminare l\'account chiede due conferme e il proprio nome', (tester) async {
    online.signInReady(handle: 'anna');
    await open(tester);
    await scrollTo(tester, find.byKey(const Key('settings.delete')));
    await tester.tap(find.byKey(const Key('settings.delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings.delete.continue')));
    await tester.pumpAndSettle();
    expect(find.text('Ultima parola: scrivi «anna» per confermare.'), findsOneWidget);

    // Con la parola sbagliata il pulsante resta spento.
    await tester.enterText(find.byKey(const Key('settings.delete.word')), 'bruno');
    await tester.pump();
    await tester.tap(find.byKey(const Key('settings.delete.confirm')));
    await tester.pump();
    expect(online.account.deleted, isEmpty);

    await tester.enterText(find.byKey(const Key('settings.delete.word')), 'Anna');
    await tester.pump();
    await tester.tap(find.byKey(const Key('settings.delete.confirm')));
    await tester.pumpAndSettle();
    expect(online.account.deleted, ['me']);
    expect(online.auth.signedIn, isFalse);
    expect(find.byKey(const Key('settings.delete')), findsNothing);
  });

  testWidgets('annullare la prima conferma non elimina niente', (tester) async {
    online.signInReady(handle: 'anna');
    await open(tester);
    await scrollTo(tester, find.byKey(const Key('settings.delete')));
    await tester.tap(find.byKey(const Key('settings.delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ANNULLA'));
    await tester.pumpAndSettle();
    expect(online.account.deleted, isEmpty);
    expect(online.auth.signedIn, isTrue);
  });

  test('i testi legali esistono nelle due lingue e si leggono', () {
    for (final name in ['privacy_it', 'privacy_en', 'terms_it', 'terms_en']) {
      final text = File('docs/legal/$name.md').readAsStringSync();
      expect(text, contains('niko.tana@outlook.com'));
      final widgets = LegalScreen.render(text);
      expect(widgets.length, greaterThan(20));
    }
  });

  testWidgets('Collega Steam dal telefono: niente codici, un tocco e il browser', (tester) async {
    online.signInReady(handle: 'anna');
    await open(tester);
    await scrollTo(tester, find.byKey(const Key('settings.link')));
    await tester.tap(find.byKey(const Key('settings.link')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('link.code')), findsNothing);
    expect(find.text('Collega Steam'), findsOneWidget);
    await tester.tap(find.byKey(const Key('link.steam')));
    await tester.pumpAndSettle();
    expect(online.links.linked, [('me', LinkProvider.steam)]);
    expect(find.text('Account collegati.'), findsOneWidget);
  });

  testWidgets('Collega: un conflitto resta nel foglio, lo stesso account dice «già collegato»', (tester) async {
    online.signInReady(handle: 'anna');
    await open(tester);
    await scrollTo(tester, find.byKey(const Key('settings.link')));
    await tester.tap(find.byKey(const Key('settings.link')));
    await tester.pumpAndSettle();
    online.links.failNext = const OnlineException(OnlineFailure.linkConflict);
    await tester.tap(find.byKey(const Key('link.steam')));
    await tester.pumpAndSettle();
    expect(find.textContaining('non si possono unire'), findsOneWidget);
    online.links.failNext = const OnlineException(OnlineFailure.linkSameAccount);
    await tester.tap(find.byKey(const Key('link.steam')));
    await tester.pumpAndSettle();
    expect(find.text('Questo account è già collegato.'), findsOneWidget);
  });
}
