import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/l10n/app_language.dart';
import 'package:oberta/rules/role.dart';
import 'package:oberta/settings/app_settings.dart';
import 'package:oberta/settings/settings_store.dart';
import 'package:oberta/tutorial/tutorial_story.dart';
import 'package:oberta/ui/screens/online/game/noir_role_card.dart';
import 'package:oberta/ui/screens/tutorial_screen.dart';

import '../support/desktop_shots.dart';
import '../support/languages.dart';

bool _enabled(WidgetTester tester, Finder finder) {
  if (finder.evaluate().isEmpty) return false;
  final widget = tester.widget(finder.last);
  final onPressed = (widget as dynamic).onPressed;
  return onPressed != null;
}

/// Gioca la mano di prova sullo schermo vero, come una persona: legge la
/// riga del narratore e tocca quello che illumina.
Future<void> _playThrough(WidgetTester tester) async {
  for (var i = 0; i < 4000; i++) {
    await tester.pump(const Duration(milliseconds: 200));
    if (find.byKey(const Key('tutorial.done')).evaluate().isNotEmpty) break;
    final table = TutorialScreen.lastTable!;
    final stage = table.stage;
    final reply = find.byKey(const Key('tutorial.reply.0'));
    if (reply.evaluate().isNotEmpty) {
      await tester.tap(reply);
      continue;
    }
    if (stage.startsWith('reveal') &&
        i % 10 == 5 &&
        !_enabled(tester, find.byKey(const Key('online.ready'))) &&
        find.byType(NoirRoleCard).evaluate().isNotEmpty) {
      final hold = await tester.startGesture(tester.getCenter(find.byType(NoirRoleCard)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await hold.up();
      await tester.pump(const Duration(milliseconds: 600));
      continue;
    }
    final ready = find.byKey(const Key('online.ready'));
    final waitingForChat = stage.startsWith('discussion') && table.replies.value.isNotEmpty;
    if (!waitingForChat && _enabled(tester, ready)) {
      await tester.tap(ready.last);
      continue;
    }
    if (stage.startsWith('night') || stage.startsWith('vote')) {
      if (table.replies.value.isNotEmpty) continue;
      final spot = table.coach.value?.spot;
      final seat = spot is ValueKey<String> && spot.value.startsWith('seat-') ? spot : const Key('seat-s2');
      final confirm = find.byKey(const Key('online.confirm'));
      if (_enabled(tester, confirm)) {
        await tester.tap(confirm.last);
        continue;
      }
      if (find.byKey(seat).evaluate().isNotEmpty && table.coach.value != null) {
        await tester.tap(find.byKey(seat).first, warnIfMissed: false);
      }
    }
  }
  expect(find.byKey(const Key('tutorial.done')), findsOneWidget, reason: 'stuck at ${TutorialScreen.lastTable!.stage} finished=${TutorialScreen.lastTable!.finished.value} ${tester.takeException()}');
  final table = TutorialScreen.lastTable!;
  expect(table.youWon, isTrue);
  expect(table.winner, switch (table.script.story) {
    TutorialStory.family => Team.mafia,
    TutorialStory.city => Team.citizens,
    // Il Fesso vince da solo, e la partita va avanti senza di lui.
    TutorialStory.solo => isNull,
  });
}

Future<void> _phone(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  for (final story in TutorialStory.values) {
    testWidgets('the ${story.name} tutorial plays to the end on a phone and counts as done', (tester) async {
      await _phone(tester);
      final settings = AppSettings(MemorySettingsStore());
      final completed = <TutorialStory>[];
      TutorialProgress.onComplete = completed.add;
      addTearDown(() => TutorialProgress.onComplete = null);
      await tester.pumpWidget(appIn(
        AppLanguage.it,
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(onPressed: () => TutorialScreen.open(context, settings: settings), child: const Text('go')),
          ),
        ),
      ));
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.text('Scegli da che parte imparare'), findsOneWidget);
      await tester.tap(find.byKey(Key('tutorial.story.${story.id}')));
      await tester.pump(const Duration(milliseconds: 500));
      await _playThrough(tester);
      expect(find.text('Ora sei pronto'), findsOneWidget);
      expect(settings.tutorialsDone, {story.id});
      expect(completed, [story]);
      await tester.tap(find.byKey(const Key('tutorial.done')));
      await tester.pumpAndSettle();
      expect(find.text('go'), findsOneWidget);
    });

    testWidgets('the ${story.name} tutorial plays on the desktop canvas, in English', (tester) async {
      await useDesktop(tester, const Size(1920, 1080));
      final settings = AppSettings(MemorySettingsStore());
      await tester.pumpWidget(desktopApp(TutorialScreen(story: story, settings: settings), language: AppLanguage.en));
      await tester.pump(const Duration(milliseconds: 500));
      await _playThrough(tester);
      expect(find.text('Now you are ready'), findsOneWidget);
    });
  }

  testWidgets('skipping does not count', (tester) async {
    await _phone(tester);
    final settings = AppSettings(MemorySettingsStore());
    await tester.pumpWidget(appIn(
      AppLanguage.it,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(onPressed: () => TutorialScreen.play(context, TutorialStory.family, settings: settings), child: const Text('go')),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.tap(find.byKey(const Key('tutorial.skip')));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.text('go'), findsOneWidget);
    expect(settings.tutorialsDone, isEmpty);
  });
}
