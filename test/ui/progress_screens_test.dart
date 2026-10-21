import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/l10n/app_language.dart';
import 'package:oberta/online/fake_online.dart';
import 'package:oberta/online/online_services.dart';
import 'package:oberta/ui/screens/online/achievements_screen.dart';
import 'package:oberta/ui/screens/online/leaderboard_screen.dart';
import 'package:oberta/ui/screens/online/missions_screen.dart';
import 'package:oberta/ui/screens/online/progress_widgets.dart';

import '../support/languages.dart';

void main() {
  late FakeOnline online;

  setUp(() {
    online = FakeOnline()
      ..signInReady(handle: 'anna')
      ..addPlayer('bruno', handle: 'bruno');
  });

  Future<void> open(WidgetTester tester, Widget screen, {AppLanguage language = AppLanguage.it}) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(appIn(language, screen));
    await tester.pumpAndSettle();
  }

  testWidgets('missions: three a day, three a week, with progress and rewards', (tester) async {
    await open(tester, MissionsScreen(progress: online.progress));
    expect(find.text('DI GIORNATA'), findsOneWidget);
    expect(find.text('Gioca 3 partite'), findsOneWidget);
    expect(find.text('Vinci da neutrale'), findsOneWidget);
    expect(find.text('0/3'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('achievements in English: counted, with a title once earned', (tester) async {
    online.progress.unlocked[online.accountId] = {'wins_50': DateTime(2026, 10, 21)};
    online.progress.stats[online.accountId] = {'wins': 50};
    await open(tester, AchievementsScreen(progress: online.progress), language: AppLanguage.en);
    expect(find.text('1 of ${achievements.length}'), findsOneWidget);
    expect(find.text('TITLE: Man of honor'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the leaderboard shows only handles and tiers, and your place', (tester) async {
    online.ratings[(online.accountId, AppLanguage.it)] = const Rating(40, 2);
    online.ratings[('bruno', AppLanguage.it)] = Rating.initial;
    await open(tester, LeaderboardScreen(progress: online.progress, language: AppLanguage.it));
    expect(find.text('@anna'), findsOneWidget);
    expect(find.text('@bruno'), findsOneWidget);
    expect(find.textContaining('Sei al 1° posto'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a banner for every mission and achievement a game completed', (tester) async {
    await tester.pumpWidget(appIn(
      AppLanguage.it,
      const Scaffold(
        body: ProgressToasts(
          unlocks: GameUnlocks(missions: [(id: 'daily_win_1', coins: 40, xp: 80)], achievements: ['wins_10']),
        ),
      ),
    ));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('Incarico compiuto: Vinci una partita'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('Medaglia: Fortunato'), findsOneWidget);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(find.byKey(const Key('progress.toast')), findsNothing);
  });
}
