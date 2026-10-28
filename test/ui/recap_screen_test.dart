import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/rules/game_engine.dart';
import 'package:oberta/ui/screens/online/recap_screen.dart';
import 'package:oberta/ui/widgets/noir_notice.dart';

import '../support/random_game.dart';

void main() {
  testWidgets('il resoconto mostra tutte le carte e la cronaca', (tester) async {
    final random = Random(3);
    final engine = randomEngine(random);
    while (engine.phase != GamePhase.ended) {
      engine.run(randomCommand(engine, random)!);
    }
    final recap = engine.recap!;
    await tester.pumpWidget(MaterialApp(home: RecapScreen(recap: recap)));
    expect(find.byKey(const Key('recap.winner')), findsOneWidget);
    for (final player in recap.roles.keys) {
      await tester.scrollUntilVisible(find.byKey(Key('recap.player.${player.id}')), 80);
    }
  });

  testWidgets('i biglietti: al massimo due, e poi se ne vanno', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () {
              showNotice(context, 'uno');
              showNotice(context, 'due');
              showNotice(context, 'tre', kind: NoticeKind.leave);
            },
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(NoticeSlip), findsNWidgets(2));
    expect(find.text('uno'), findsNothing);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.byType(NoticeSlip), findsNothing);
  });
}
