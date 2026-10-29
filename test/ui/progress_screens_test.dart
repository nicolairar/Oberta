import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/l10n/app_language.dart';
import 'package:oberta/l10n/lobby_language.dart';
import 'package:oberta/online/fake_online.dart';
import 'package:oberta/online/online_services.dart';
import 'package:oberta/ui/screens/online/achievements_screen.dart';
import 'package:oberta/ui/screens/online/leaderboard_screen.dart';
import 'package:oberta/ui/screens/online/match_results_screen.dart';
import 'package:oberta/ui/screens/online/missions_screen.dart';
import 'package:oberta/ui/screens/online/progress_widgets.dart';

import '../support/desktop_shots.dart' show loadRealFonts;
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

  testWidgets('missions: today, the week and the goals, with progress and rewards', (tester) async {
    await open(tester, MissionsScreen(progress: online.progress));
    expect(find.text('OGGI'), findsOneWidget);
    expect(find.text('Gioca 3 partite'), findsOneWidget);
    expect(find.text('Vinci una partita'), findsOneWidget);
    await tester.tap(find.byKey(const Key('missions.tab.weekly')));
    await tester.pumpAndSettle();
    expect(find.text('Gioca 10 partite'), findsOneWidget);
    await tester.tap(find.byKey(const Key('missions.tab.long')));
    await tester.pumpAndSettle();
    expect(find.text('Vinci 5 partite da Commissario'), findsOneWidget);
    expect(find.text('Premio: Berretto da sbirro'), findsOneWidget);
    expect(find.byKey(const Key('mission.long_detective_wins_5.claim')), findsNothing, reason: 'not done yet');
    expect(tester.takeException(), isNull);
  });

  testWidgets('claiming: the plate pays coins and respect, stamps the order and gives the piece', (tester) async {
    online.progress.stats[online.accountId] = {'role_win:detective': 5};
    final before = (await online.profiles.me()).coins;
    await open(tester, MissionsScreen(progress: online.progress, tab: 2));
    expect(find.text('1 da riscuotere'), findsOneWidget);
    await tester.tap(find.byKey(const Key('mission.long_detective_wins_5.claim')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect((await online.profiles.me()).coins, before + 400);
    expect(online.shop.ownedBy(online.accountId), contains('hat.sbirro'));
    expect(find.text('RISCOSSO'), findsOneWidget);
    expect(find.byKey(const Key('mission.long_detective_wins_5.claim')), findsNothing);
    expect(tester.widget<Text>(find.byKey(const Key('missions.reputation'))).data, '50');
    await tester.pump(const Duration(seconds: 6));
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
    online.ratings[(online.accountId, LobbyLanguage.it)] = const Rating(40, 2);
    online.ratings[('bruno', LobbyLanguage.it)] = Rating.initial;
    await open(tester, LeaderboardScreen(progress: online.progress, language: LobbyLanguage.it));
    expect(find.text('@anna'), findsOneWidget);
    expect(find.text('@bruno'), findsOneWidget);
    expect(find.textContaining('Sei al 1° posto'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // QA P2-3: at 393x852 "Missione compiuta: Vinci una partita. Riscuotila!"
  // sat right on the VITTORIA headline of the results.
  for (final (size, top) in [(const Size(393, 852), 59.0), (const Size(375, 667), 20.0), (const Size(820, 1180), 24.0)]) {
    testWidgets('on the results at ${size.width.round()}x${size.height.round()}, the banners never cover the headline', (tester) async {
      await tester.runAsync(loadRealFonts);
      tester.view.physicalSize = size * 3;
      tester.view.devicePixelRatio = 3;
      tester.view.padding = FakeViewPadding(top: top * 3, bottom: 34 * 3);
      addTearDown(tester.view.reset);
      final me = online.accountId;
      online.history[me] = [
        const MatchResult(gameId: 'g1', won: true, role: 'detective', xpGained: 200, levelBefore: 1, levelAfter: 2, coinsGained: 40),
      ];
      online.progress.gameUnlocks[(me, 'g1')] = const GameUnlocks(
        missions: [(id: 'daily_win_1', coins: 40, xp: 80), (id: 'daily_play_3', coins: 30, xp: 60)],
        achievements: ['wins_10'],
      );
      await tester.pumpWidget(appIn(
        AppLanguage.it,
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                key: const Key('open'),
                onPressed: () => showMatchResults(context, online.services),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.byKey(const Key('open')));
      var seen = 0;
      for (var i = 0; i < 140; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        final toast = find.byKey(const Key('progress.toast'));
        final title = find.byKey(const Key('results.title'));
        if (toast.evaluate().isEmpty || title.evaluate().isEmpty) continue;
        final plate = tester.getRect(toast);
        if (plate.bottom <= 0) continue;
        seen++;
        final headline = tester.getRect(title);
        expect(plate.overlaps(headline), isFalse, reason: 'the banner $plate covers the headline $headline');
      }
      expect(seen, greaterThan(10), reason: 'the banners were shown');
      expect(tester.takeException(), isNull);
    });
  }

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
    Finder shown(String text) => find.descendant(of: find.byKey(const Key('progress.toast')), matching: find.text(text));
    expect(shown('Missione compiuta: Vinci una partita. Riscuotila!'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 700));
    expect(shown('Medaglia: Fortunato'), findsOneWidget);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(find.byKey(const Key('progress.toast')), findsNothing);
  });
}
