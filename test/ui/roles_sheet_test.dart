import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/l10n/app_language.dart';
import 'package:oberta/rules/game_engine.dart';
import 'package:oberta/rules/knowledge.dart';
import 'package:oberta/rules/player.dart';
import 'package:oberta/rules/player_view.dart';
import 'package:oberta/rules/role.dart';
import 'package:oberta/ui/widgets/roles_sheet.dart';

import '../support/languages.dart';

void main() {
  test('deck composition counts roles in card order', () {
    expect(deckOf([Role.cittadino, Role.mafioso, Role.cittadino]), {Role.mafioso: 1, Role.cittadino: 2});
  });

  testWidgets('sheet lists the deck with counts, marks reveals, and names no hidden holder', (tester) async {
    final strings = AppLanguage.it.strings;
    await tester.pumpWidget(appIn(
      AppLanguage.it,
      Scaffold(
        body: RolesSheet(
          deck: const {Role.mafioso: 2, Role.medico: 1},
          revealed: const [(role: Role.mafioso, name: 'Marco')],
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final mafioso = strings.role(Role.mafioso).label;
    final medico = strings.role(Role.medico).label;
    expect(find.text(mafioso), findsNWidgets(2));
    expect(find.text('rivelato: Marco'), findsOneWidget);
    expect(find.text(medico), findsOneWidget);
    expect(find.textContaining(strings.role(Role.medico).description), findsOneWidget);
    await tester.scrollUntilVisible(find.textContaining('zittito dal Sarto'), 200);
    expect(find.textContaining('zittito dal Sarto'), findsOneWidget);
    expect(find.textContaining('Luca'), findsNothing);
  });

  test('public reveals use only public facts', () {
    const marco = Player(id: 'm', name: 'Marco');
    const luca = Player(id: 'l', name: 'Luca');
    final board = PublicView.fromJson(PublicView(
      round: 1,
      phase: GamePhase.day,
      winner: null,
      seats: const [marco, luca],
      alive: const [luca],
      revealed: [SeatKnowledge(marco, const Knowledge(role: Role.mafioso))],
      history: const [],
      lastDawn: null,
      lastLynch: null,
      nightPending: 0,
      dayVotes: const [],
      finalRoles: const {},
      deck: const {Role.mafioso: 1, Role.medico: 1},
    ).toJson(), (id) => id == 'm' ? marco : luca);
    expect(board.deck, {Role.mafioso: 1, Role.medico: 1});
    expect(publicReveals(board), [(role: Role.mafioso, name: 'Marco')]);
  });
}
