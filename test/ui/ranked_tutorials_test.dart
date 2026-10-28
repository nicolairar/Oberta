import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/l10n/app_language.dart';
import 'package:oberta/online/fake_online.dart';
import 'package:oberta/online/online_services.dart';
import 'package:oberta/online/tutorial_sync.dart';
import 'package:oberta/settings/app_settings.dart';
import 'package:oberta/settings/settings_store.dart';
import 'package:oberta/tutorial/tutorial_story.dart';
import 'package:oberta/ui/screens/online/ranked_entry.dart';
import 'package:oberta/ui/screens/online/ranked_queue_screen.dart';

import '../support/desktop_shots.dart';
import '../support/languages.dart';

/// La classificata chiede le tre mani di prova: chiusa finché ne manca una.
void main() {
  late AppSettings previous;

  setUp(() {
    previous = AppSettings.instance;
    AppSettings.instance = AppSettings(MemorySettingsStore());
  });
  tearDown(() => AppSettings.instance = previous);

  FakeOnline world() => FakeOnline(accountId: 'anna')
    ..signInReady(handle: 'anna')
    ..slow = false
    ..requireTutorials = true;

  void usePhone(WidgetTester tester) {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }

  test('ranked_status porta le mani fatte; il server finto chiede tutte e tre', () async {
    expect(
      RankedStatus.fromJson({
        'tutorials': ['family', 'solo'],
      }).tutorials,
      {'family', 'solo'},
    );
    expect(RankedStatus.fromJson({}).tutorials, isEmpty);
    final online = world();
    final ranked = online.services.ranked!;
    await expectLater(
      ranked.enqueue(AppLanguage.it),
      throwsA(isA<OnlineException>().having((e) => e.failure, 'failure', OnlineFailure.tutorialsRequired)),
    );
    for (final story in TutorialStory.values) {
      await ranked.completeTutorial(story.id);
    }
    expect((await ranked.enqueue(AppLanguage.it)).queued, isTrue);
  });

  test('quelle finite sul telefono vanno al server', () async {
    final online = world();
    AppSettings.instance.markTutorialDone('family');
    final sync = TutorialSync(online.services);
    expect(await sync.upload(const {}), isTrue);
    expect(online.tutorials['anna'], {'family'});
    await sync.complete(TutorialStory.solo);
    expect(online.tutorials['anna'], {'family', 'solo'});
  });

  testWidgets('sul telefono: tre mani, la spunta su quelle fatte, il bottone per la prima che manca', (tester) async {
    usePhone(tester);
    final online = world();
    online.tutorials['anna'] = {'town'};
    AppSettings.instance.markTutorialDone('family');
    await tester.pumpWidget(appIn(AppLanguage.it, RankedQueueScreen(services: online.services)));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byKey(const Key('ranked.locked')), findsOneWidget);
    expect(find.byKey(const Key('ranked.start')), findsNothing);
    expect(find.byKey(const Key('ranked.tutorial.family.done')), findsOneWidget);
    expect(find.byKey(const Key('ranked.tutorial.town.done')), findsOneWidget);
    expect(find.byKey(const Key('ranked.tutorial.solo.todo')), findsOneWidget);
    expect(find.text('GIOCA LA MANO: CHI GIOCA DA SOLO'), findsOneWidget);
    // La mano del telefono è arrivata al server.
    expect(online.tutorials['anna'], {'family', 'town'});
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('tutte e tre fatte: si siede', (tester) async {
    usePhone(tester);
    final online = world();
    online.tutorials['anna'] = {'family', 'town', 'solo'};
    await tester.pumpWidget(appIn(AppLanguage.en, RankedQueueScreen(services: online.services)));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byKey(const Key('ranked.locked')), findsNothing);
    expect(find.byKey(const Key('ranked.start')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  for (final MapEntry(key: label, value: size) in desktopSizes.entries) {
    testWidgets('sul desktop $label: chiusa, e il bottone apre la mano che manca', (tester) async {
      await useDesktop(tester, size);
      TutorialStory? asked;
      final sweep = AnimationController(vsync: const TestVSync());
      addTearDown(sweep.dispose);
      await tester.pumpWidget(
        desktopApp(
          RankedEntryView(
            language: AppLanguage.en,
            onLanguage: (_) {},
            queued: false,
            sweep: sweep,
            cooldown: null,
            warning: false,
            onStart: () => fail('locked'),
            onCancel: () {},
            tutorialsDone: const {TutorialStory.city},
            onTutorial: (story) => asked = story,
          ),
          language: AppLanguage.en,
        ),
      );
      await tester.pump();
      expect(find.byKey(const Key('ranked.locked')), findsOneWidget);
      expect(find.text('PLAY THE HAND: THE FAMILY'), findsOneWidget);
      await tester.tap(find.byKey(const Key('ranked.tutorial')));
      expect(asked, TutorialStory.family);
    });
  }

  test('«Conosco già il gioco»: il server finto apre la classificata anche senza le mani', () async {
    expect(
      RankedStatus.fromJson({
        'tutorials': ['skip'],
      }).tutorialsSkipped,
      isTrue,
    );
    expect(
      RankedStatus.fromJson({
        'tutorials': ['family'],
      }).tutorialsSkipped,
      isFalse,
    );
    final online = world();
    final ranked = online.services.ranked!;
    await ranked.completeTutorial('family');
    expect(await ranked.skipTutorials(), {'family', 'skip'});
    expect(await ranked.skipTutorials(), {'family', 'skip'});
    expect((await ranked.status()).tutorialsSkipped, isTrue);
    expect((await ranked.enqueue(AppLanguage.it)).queued, isTrue);
  });

  testWidgets('«Conosco già il gioco» chiede «Sicuro?» e solo alla conferma apre la classificata', (tester) async {
    usePhone(tester);
    final online = world();
    Future<void> settle() async {
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    await tester.pumpWidget(appIn(AppLanguage.it, RankedQueueScreen(services: online.services)));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byKey(const Key('ranked.locked')), findsOneWidget);
    // Le mani restano lì per chi le vuole.
    expect(find.byKey(const Key('ranked.tutorial.family.todo')), findsOneWidget);
    expect(find.byKey(const Key('ranked.tutorial')), findsOneWidget);

    // Primo tocco: solo il dialogo. «Ci ripenso» non cambia nulla.
    await tester.ensureVisible(find.byKey(const Key('ranked.skip')));
    await tester.tap(find.byKey(const Key('ranked.skip')));
    await settle();
    expect(find.byKey(const Key('ranked.skip.dialog')), findsOneWidget);
    expect(find.text('Sicuro?'), findsOneWidget);
    expect(find.text('Salti tutti i tutorial e vai dritto in classificata.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('ranked.skip.cancel')));
    await settle();
    expect(find.byKey(const Key('ranked.skip.dialog')), findsNothing);
    expect(online.tutorials['anna'] ?? const <String>{}, isNot(contains('skip')));
    expect(find.byKey(const Key('ranked.locked')), findsOneWidget);

    // Secondo giro, con la conferma esplicita: si siede.
    await tester.tap(find.byKey(const Key('ranked.skip')));
    await settle();
    await tester.tap(find.byKey(const Key('ranked.skip.confirm')));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(online.tutorials['anna'], contains('skip'));
    expect(find.byKey(const Key('ranked.locked')), findsNothing);
    expect(find.byKey(const Key('ranked.start')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  for (final MapEntry(key: label, value: size) in desktopSizes.entries) {
    testWidgets('sul desktop $label: c\'è «I already know the game» sotto le mani', (tester) async {
      await useDesktop(tester, size);
      var skipped = false;
      final sweep = AnimationController(vsync: const TestVSync());
      addTearDown(sweep.dispose);
      await tester.pumpWidget(
        desktopApp(
          RankedEntryView(
            language: AppLanguage.en,
            onLanguage: (_) {},
            queued: false,
            sweep: sweep,
            cooldown: null,
            warning: false,
            onStart: () => fail('locked'),
            onCancel: () {},
            tutorialsDone: const {},
            onSkipTutorials: () => skipped = true,
          ),
          language: AppLanguage.en,
        ),
      );
      await tester.pump();
      expect(find.text('I already know the game'), findsOneWidget);
      await tester.tap(find.byKey(const Key('ranked.skip')));
      await tester.pumpAndSettle();
      expect(skipped, isFalse);
      await tester.tap(find.byKey(const Key('ranked.skip.confirm')));
      await tester.pumpAndSettle();
      expect(skipped, isTrue);
    });
  }

  testWidgets('saltate sul server: aperta anche senza le mani', (tester) async {
    usePhone(tester);
    final online = world();
    online.tutorials['anna'] = {'skip'};
    await tester.pumpWidget(appIn(AppLanguage.en, RankedQueueScreen(services: online.services)));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byKey(const Key('ranked.locked')), findsNothing);
    expect(find.byKey(const Key('ranked.start')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
