import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/l10n/app_language.dart';
import 'package:oberta/rules/role.dart';
import 'package:oberta/ui/screens/online/game/noir_role_card.dart';
import 'package:oberta/ui/widgets/flip_role_card.dart';

import '../../support/languages.dart';

// QA P2-1: the reveal window closed while the finger was still on the card;
// lifting it then ran the card's release on a disposed state, and
// AnimationController.reverse() threw after dispose().
void main() {
  Widget table(Widget? card) => appIn(
        AppLanguage.it,
        Scaffold(
          body: Center(
            child: SizedBox(width: 260, child: card ?? const SizedBox(height: 380, key: Key('night'))),
          ),
        ),
      );

  for (final (name, card) in [
    ('online', const NoirRoleCard(role: Role.detective) as Widget),
    ('one phone', const FlipRoleCard(role: Role.detective)),
  ]) {
    testWidgets('$name: lifting the finger after the card has left the table does nothing', (tester) async {
      await tester.pumpWidget(table(card));
      await tester.pump(const Duration(milliseconds: 800));
      final finger = await tester.startGesture(tester.getCenter(find.byWidget(card)));
      await tester.pump(const Duration(milliseconds: 300));

      // The night replaces the card while the finger is still down.
      await tester.pumpWidget(table(null));
      expect(find.byWidget(card), findsNothing);
      await finger.up();
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('$name: a cancelled touch after the card has gone does nothing either', (tester) async {
      await tester.pumpWidget(table(card));
      await tester.pump(const Duration(milliseconds: 800));
      final finger = await tester.startGesture(tester.getCenter(find.byWidget(card)));
      await tester.pumpWidget(table(null));
      await finger.cancel();
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
}
