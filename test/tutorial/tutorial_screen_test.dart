import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/l10n/app_language.dart';
import 'package:oberta/settings/app_settings.dart';
import 'package:oberta/settings/settings_store.dart';
import 'package:oberta/ui/screens/tutorial_screen.dart';
import 'package:oberta/ui/theme/app_theme.dart';
import 'package:oberta/ui/widgets/flip_role_card.dart';

import '../support/desktop_shots.dart';

/// The seats on the table keep breathing: settle by time, not by idleness.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Future<void> _next(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('tutorial.next')));
  await _settle(tester);
}

Future<void> _tapSeat(WidgetTester tester, String name) async {
  await tester.tap(find.text(name).first, warnIfMissed: false);
  await _settle(tester);
}

/// Plays the whole scripted hand through the real screen.
Future<void> _playThrough(WidgetTester tester, {required String accuse1, required String accuse2}) async {
  await _next(tester); // welcome
  final gesture = await tester.startGesture(tester.getCenter(find.byType(FlipRoleCard)));
  await tester.pumpAndSettle();
  await gesture.up();
  await tester.pumpAndSettle();
  await _next(tester); // card
  await _tapSeat(tester, 'Vito'); // investigate
  await _next(tester); // finding
  expect(find.textContaining('Bruno'), findsWidgets);
  await _next(tester); // dawn
  await tester.tap(find.text(accuse1));
  await _settle(tester);
  await _tapSeat(tester, 'Vito'); // vote
  expect(find.byIcon(Icons.pan_tool_alt), findsWidgets);
  await _next(tester); // verdict
  await _tapSeat(tester, 'Carmela');
  await _next(tester);
  await _next(tester); // dawn 2
  await tester.tap(find.text(accuse2));
  await _settle(tester);
  await _tapSeat(tester, 'Carmela');
  await _next(tester); // verdict 2
  await _next(tester); // win
  expect(find.byKey(const Key('tutorial.done')), findsOneWidget);
}

void main() {
  testWidgets('the tutorial plays to the end on a phone and marks itself seen', (tester) async {
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final settings = AppSettings(MemorySettingsStore());
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(onPressed: () => TutorialScreen.offer(context, settings: settings), child: const Text('go')),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(settings.tutorialSeen, isTrue);
    await tester.tap(find.byKey(const Key('tutorial.start')));
    await tester.pumpAndSettle();
    await _playThrough(
      tester,
      accuse1: 'Ho indagato su Vito: è della Famiglia.',
      accuse2: 'Ho indagato su Carmela: è della Famiglia.',
    );
    expect(find.text('Ora sei pronto'), findsOneWidget);
    await tester.tap(find.byKey(const Key('tutorial.done')));
    await tester.pumpAndSettle();
    expect(find.text('go'), findsOneWidget);

    // Offered only once.
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('tutorial.start')), findsNothing);
  });

  testWidgets('the tutorial plays on the desktop canvas, in English, and can be skipped', (tester) async {
    await useDesktop(tester, const Size(1920, 1080));
    await tester.pumpWidget(desktopApp(const TutorialScreen(), language: AppLanguage.en));
    await tester.pumpAndSettle();
    await _playThrough(
      tester,
      accuse1: 'I investigated Vito: Family.',
      accuse2: 'I investigated Carmela: Family.',
    );
    expect(find.text('Now you are ready'), findsOneWidget);

    await tester.pumpWidget(desktopApp(TutorialScreen(key: UniqueKey()), language: AppLanguage.en));
    await _settle(tester);
    expect(find.byKey(const Key('tutorial.skip')), findsOneWidget);
    await tester.tap(find.byKey(const Key('tutorial.skip')));
    await _settle(tester);
  });
}
