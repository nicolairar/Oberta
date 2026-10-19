import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/l10n/app_language.dart';
import 'package:oberta/rules/role.dart';
import 'package:oberta/ui/screens/screening/night_scenarios.dart';
import 'package:oberta/ui/screens/screening/scenario_screen.dart';
import 'package:oberta/ui/screens/screening_room_screen.dart';
import 'package:oberta/ui/widgets/death_scene.dart';
import 'package:oberta/ui/widgets/lynch_mark.dart';

import '../support/languages.dart';

Future<void> _fonts() async {
  const file = '/System/Library/Fonts/Supplemental/Georgia.ttf';
  if (!File(file).existsSync()) return;
  final bytes = File(file).readAsBytesSync();
  for (final family in ['Georgia', 'Roboto', 'serif', 'Courier']) {
    final loader = FontLoader(family)..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
  }
}

NightScenario _byId(String id) => nightScenarios.firstWhere((s) => s.id == id);

void main() {
  test('ogni notte di prova gira sul motore vero e fa quello che dice', () {
    final ids = nightScenarios.map((s) => s.id).toSet();
    expect(ids.length, nightScenarios.length);
    for (final s in nightScenarios) {
      expect(s.title.it, isNotEmpty);
      expect(s.title.en, isNotEmpty);
      expect(s.blurb.it, isNotEmpty);
      expect(s.blurb.en, isNotEmpty);
    }
    String outcomes(String id) =>
        _byId(id).run().dawn.attacks.map((a) => '${a.target.name}:${a.source.name}:${a.outcome.name}').join(',');
    expect(outcomes('doctor-save'), 'Anna:family:healed');
    expect(outcomes('family-and-hitman'), 'Anna:family:killed,Carla:assassin:killed');
    expect(outcomes('same-target'), 'Anna:family:killed');
    expect(outcomes('fire-and-family'), 'Anna:family:killed,Carla:fire:killed');
    expect(outcomes('veteran'), 'Anna:family:shrugged');
    expect(outcomes('bodyguard'), 'Bruno:family:killed');
    expect(outcomes('loan-shark'), 'Anna:family:healed');
    expect(outcomes('sniper'), 'Tano:sniper:killed,Anna:family:killed');
    expect(outcomes('quiet'), '');
    expect(_byId('scoop').run().dawn.scoop?.team, Team.mafia);
    expect(_byId('tailor').run().dawn.silenced?.name, 'Carla');
    expect(_byId('messiah').run().dawn.resurrected?.name, 'Carla');
    expect(_byId('lynch-family').run().lynch?.role, Role.mafioso);
    expect(_byId('lynch-fool').run().lynch?.personalWin, isTrue);
    final bounty = _byId('lynch-bounty').run().lynch!;
    expect(bounty.bountyHunter?.name, 'Fede');
    expect(bounty.winner, Team.neutral);
    expect(_byId('mayor').run().lynch?.condemned?.name, 'Rocco');
  });

  for (final language in AppLanguage.values) {
    for (final scenario in nightScenarios) {
      testWidgets('${language.name}: «${scenario.id}» si vede senza errori', (tester) async {
        tester.view.physicalSize = const Size(393, 852) * 3;
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(appIn(language, ScenarioScreen(scenario: scenario)));
        await tester.pump(const Duration(seconds: 2));
        final text = tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
            .join('\n');
        expect(text, isNot(contains('{')));
        expect(text, contains(scenario.titleIn(language == AppLanguage.it)));
        final run = scenario.run();
        for (final victim in run.dawn.victims) {
          expect(text, contains(victim.name));
        }
        if (run.lynch?.condemned != null) {
          await tester.scrollUntilVisible(find.byType(LynchMark), 300, scrollable: find.byType(Scrollable).first);
          expect(find.byType(LynchMark), findsOneWidget);
        }
        if (run.dawn.attacks.isNotEmpty) {
          await tester.tap(find.byKey(const Key('scenario.films')));
          await tester.pump();
          for (var i = 0; i < run.dawn.attacks.length; i++) {
            await tester.pump(const Duration(seconds: 1));
            await tester.tap(find.descendant(of: find.byType(DeathScene), matching: find.byType(TextButton)));
            await tester.pump(const Duration(seconds: 1));
            await tester.tap(find.descendant(of: find.byType(DeathScene), matching: find.byType(ElevatedButton)));
            await tester.pump(const Duration(seconds: 1));
          }
          await tester.pump(const Duration(seconds: 1));
          expect(find.byType(DeathScene), findsNothing);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('la sala prove elenca le notti di prova', (tester) async {
    await tester.pumpWidget(appIn(AppLanguage.it, const ScreeningRoomScreen()));
    await tester.scrollUntilVisible(find.text('NOTTI DI PROVA'), 400, scrollable: find.byType(Scrollable).first);
    expect(find.text('NOTTI DI PROVA'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('scenario.doctor-save')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('scenario.doctor-save')), findsOneWidget);
  });

  for (final id in ['fire-and-family', 'lynch-bounty', 'mayor']) {
    testWidgets('fotografia: $id', (tester) async {
      await tester.runAsync(_fonts);
      tester.view.physicalSize = const Size(393, 1900) * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      const shot = Key('shot');
      await tester.pumpWidget(
        RepaintBoundary(
          key: shot,
          child: appIn(AppLanguage.it, ScenarioScreen(scenario: _byId(id))),
        ),
      );
      await tester.pump(const Duration(seconds: 3));
      final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(shot));
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        Directory('build/screens').createSync(recursive: true);
        File('build/screens/scenario-$id.png').writeAsBytesSync(png!.buffer.asUint8List());
      });
    });
  }
}
