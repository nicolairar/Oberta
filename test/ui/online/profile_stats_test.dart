import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/l10n/app_language.dart';
import 'package:oberta/l10n/app_strings.dart';
import 'package:oberta/online/fake_online.dart';
import 'package:oberta/online/online_account.dart';
import 'package:oberta/online/online_services.dart';
import 'package:oberta/ui/screens/online/profile_sheet.dart';

MatchResult _m(String role, String team, bool won, {bool test = false, bool ranked = false, int? secs}) => MatchResult(
      gameId: 'g',
      role: role,
      team: team,
      won: won,
      testMatch: test,
      ranked: ranked,
      survived: won,
      durationSeconds: secs,
      xpGained: 10,
      levelBefore: 1,
      levelAfter: 1,
    );

void main() {
  test('the slice counts like my_stats', () {
    final s = StatsSlice.of([
      _m('mafioso', 'mafia', true, secs: 600),
      _m('mafioso', 'mafia', true, ranked: true),
      _m('detective', 'citizens', false, secs: 900),
      _m('detective', 'citizens', true),
      _m('detective', 'citizens', true),
      _m('detective', 'citizens', true),
    ]);
    expect(s.games, 6);
    expect(s.wins, 5);
    expect(s.losses, 1);
    expect(s.longestStreak, 3);
    expect(s.seconds, 1500);
    expect(s.timed, 2);
    expect(s.ranked.games, 1);
    expect(s.friends.wins, 4);
    expect(s.teams['citizens']!.games, 4);
    expect(s.favouriteRole, 'detective');
  });

  test('my_stats json', () {
    final stats = PlayerStats.fromJson({
      'all': {'games': 3, 'wins': 2, 'roles': {'medico': {'games': 3, 'wins': 2}}},
      'real': {'games': 1, 'wins': 1},
      'tests': 2,
      'counters': {'nights': 5},
    });
    expect(stats.slice(withTests: true).roles['medico']!.rate, closeTo(2 / 3, 1e-9));
    expect(stats.slice(withTests: false).games, 1);
    expect(stats.tests, 2);
    expect(stats.counters['nights'], 5);
  });

  testWidgets('the stats page turns, and the test matches switch', (tester) async {
    tester.view.physicalSize = const Size(393, 852) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final online = FakeOnline()..signInReady(handle: 'anna');
    online.history['me'] = [
      _m('mafioso', 'mafia', true, secs: 600),
      _m('detective', 'citizens', false, test: true),
    ];
    final account = OnlineAccount(online.services);
    await tester.pumpWidget(MaterialApp(
      locale: AppLanguage.it.locale,
      supportedLocales: AppLanguage.locales,
      localizationsDelegates: const [
        AppStrings.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(onPressed: () => showProfileSheet(context, account: account), child: const Text('go')),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile.tab.stats')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('stats.page')), findsOneWidget);
    expect(find.text('Includi partite di prova (1)'), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('stats.big.0')), matching: find.text('1')), findsOneWidget);

    await tester.tap(find.byKey(const Key('stats.tests')));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byKey(const Key('stats.big.0')), matching: find.text('2')), findsOneWidget);

    await tester.tap(find.byKey(const Key('profile.tab.file')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('stats.page')), findsNothing);
    expect(find.byKey(const Key('profile.coins')), findsOneWidget);
  });
}
