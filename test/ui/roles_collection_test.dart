import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/l10n/app_language.dart';
import 'package:oberta/online/fake_online.dart';
import 'package:oberta/online/online_services.dart';
import 'package:oberta/rules/role.dart';
import 'package:oberta/ui/screens/roles_screen.dart';

import '../support/languages.dart';

void main() {
  late FakeOnline online;

  setUp(() => online = FakeOnline()..signInReady(handle: 'anna'));

  Future<void> open(WidgetTester tester, {AppLanguage language = AppLanguage.it}) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(appIn(language, RolesScreen(services: online.services)));
    await tester.pumpAndSettle();
  }

  String rules(Role role, [AppLanguage language = AppLanguage.it]) => language.strings.role(role).description;

  testWidgets('every role has a card, grouped by side; only won ones are face up', (tester) async {
    online.progress.roles[online.accountId] = {
      'detective': const RoleRecord(role: 'detective', played: 4, wins: 3, bestStreak: 2),
      'medico': const RoleRecord(role: 'medico', played: 2),
    };
    await open(tester);
    expect(find.text('1 carte su ${Role.values.length}'), findsOneWidget);
    expect(find.text('3 V · 4 P'), findsOneWidget);

    // A face-down card: the name, never what the role does.
    await tester.tap(find.byKey(const Key('roles.card.medico')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('roles.detail.locked')), findsOneWidget);
    expect(find.text('Giocata 2 volte, mai vinta.'), findsOneWidget);
    expect(find.text(rules(Role.medico)), findsNothing);
    await tester.tap(find.text('CHIUDI'));
    await tester.pumpAndSettle();

    // A won card: the rules and the numbers.
    await tester.tap(find.byKey(const Key('roles.card.detective')));
    await tester.pumpAndSettle();
    expect(find.text(rules(Role.detective)), findsOneWidget);
    expect(find.text('75%'), findsOneWidget);
    await tester.tap(find.text('CHIUDI'));
    await tester.pumpAndSettle();

    for (final side in ['VILLAGGIO', 'MAFIA', 'SOLITARI']) {
      await tester.scrollUntilVisible(find.text(side), 200, scrollable: find.byType(Scrollable).first);
      expect(find.text(side), findsOneWidget);
    }
    for (final role in Role.values.where((r) => r.team == Team.neutral)) {
      expect(find.byKey(Key('roles.card.${role.name}'), skipOffstage: false), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('signed out: every card face down and a way to sign in', (tester) async {
    online = FakeOnline();
    await open(tester, language: AppLanguage.en);
    expect(find.byKey(const Key('roles.signIn')), findsOneWidget);
    expect(find.text('0 of ${Role.values.length} cards'), findsOneWidget);
    await tester.tap(find.byKey(const Key('roles.card.detective')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('roles.detail.locked')), findsOneWidget);
    expect(find.text(rules(Role.detective, AppLanguage.en)), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('a record moves with each counted game; the server rows parse', () {
    final won = const RoleRecord(role: 'sarto').after(won: true, at: DateTime(2026, 10, 28));
    expect(won.unlocked, isTrue);
    expect(won.after(won: false, at: DateTime(2026, 10, 29)).streak, 0);
    expect(won.after(won: true, at: DateTime(2026, 10, 29)).bestStreak, 2);
    final rows = RoleRecord.listFromJson([
      {'role': 'medico', 'played': 3, 'wins': 1, 'losses': 2, 'streak': 1, 'best_streak': 1, 'last_played': 0},
    ]);
    expect(rows['medico']!.losses, 2);
    expect(rows['medico']!.winRate, closeTo(1 / 3, 1e-9));
  });
}
