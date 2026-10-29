import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/rules/game_setup.dart';
import 'package:oberta/rules/player.dart';
import 'package:oberta/rules/role.dart';
import 'package:oberta/sound/sound_stage.dart';
import 'package:oberta/ui/screens/game_screen.dart';
import 'package:oberta/ui/theme/app_theme.dart';
import 'package:oberta/ui/widgets/spoken_script_card.dart';

const ada = Player(id: 'ada', name: 'Ada');
const bruno = Player(id: 'bruno', name: 'Bruno');
const carla = Player(id: 'carla', name: 'Carla');
const dino = Player(id: 'dino', name: 'Dino');
const elio = Player(id: 'elio', name: 'Elio');

final roles = {ada: Role.mafioso, bruno: Role.detective, carla: Role.cittadino, dino: Role.cittadino};

/// Un palco muto che si segna cosa dice il narratore.
class _Ear extends SoundStage {
  final said = <String>[];
  var stops = 0;
  final ducks = <bool>[];

  @override
  void voice(String asset) => said.add(asset);

  @override
  void stopVoice() => stops++;

  @override
  void duckForVoice(bool ducked) => ducks.add(ducked);
}

/// La partita con le animazioni accese, come su un telefono vero: il
/// copione si scrive a tempo con la voce.
Future<void> open(WidgetTester tester, {Player? narrator, bool animations = true}) async {
  tester.view.physicalSize = const Size(393, 852) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  if (!animations) {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }
  await tester.pumpWidget(MaterialApp(
    theme: buildAppTheme(),
    home: GameScreen(setup: GameSetup.fromRoles(roles, narrator: narrator), random: Random(1)),
  ));
  await tester.pump();
}

/// Quanto si legge del copione: il testo dei sottotitoli che non è trasparente.
String visibleScript(WidgetTester tester) {
  final buffer = StringBuffer();
  for (final element in find.descendant(of: find.byType(SpokenScriptCard), matching: find.byType(RichText)).evaluate()) {
    final opacity = element.findAncestorWidgetOfExactType<Opacity>();
    if (opacity != null && opacity.opacity == 0) continue;
    if ((element.widget as RichText).text.toPlainText() == 'PARLA IL NARRATORE') continue;
    if (element.findAncestorWidgetOfExactType<Icon>() != null) continue;
    (element.widget as RichText).text.visitChildren((span) {
      if (span is TextSpan && span.text != null && span.style?.color != Colors.transparent) buffer.write(span.text);
      return true;
    });
  }
  return buffer.toString();
}

void main() {
  late _Ear ear;
  setUp(() => SoundStage.instance = ear = _Ear());
  tearDown(() => SoundStage.instance = SoundStage());

  testWidgets('narratore automatico: la voce legge, il testo si scrive a tempo', (tester) async {
    await open(tester);
    expect(find.text('PARLA IL NARRATORE'), findsOneWidget);
    expect(find.text('LEGGETE AD ALTA VOCE'), findsNothing);
    final city = RegExp(r'^(Chicago|New York|Palermo|Napoli|Las Vegas), 19\d\d\.');

    // Prima cala la notte, poi parla la voce.
    await tester.pump(const Duration(milliseconds: 1000));
    expect(ear.said, isEmpty, reason: 'il tramonto parte prima della voce');
    expect(visibleScript(tester).trim(), isEmpty);

    await tester.pump(const Duration(milliseconds: 1100));
    expect(ear.said, hasLength(1));
    expect(ear.said.first, matches(RegExp(r'^voice/it/[0-9a-f]{16}\.m4a$')));
    expect(ear.ducks, [true], reason: 'la musica si fa da parte');
    final early = visibleScript(tester);
    expect(early, isNotEmpty);
    expect(city.hasMatch(early), isFalse, reason: 'la prima battuta è ancora a metà');

    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 2));
    expect(city.hasMatch(visibleScript(tester)), isTrue);
    expect(visibleScript(tester).length, greaterThan(early.length));
    expect(ear.said.length, greaterThan(1), reason: 'una battuta dopo l\'altra');

    // Il pulsante non aspetta la voce: toccarlo la fa tacere.
    await tester.tap(find.text('COMINCIA LA NOTTE'));
    await tester.pump();
    expect(ear.stops, greaterThan(0));
    final said = ear.said.length;
    // Poi la tenda: la voce tace, il nome si legge.
    await tester.pump(const Duration(seconds: 20));
    expect(ear.said.length - said, 0, reason: 'a ogni mano «passa il telefono» è solo rumore');
    expect(ear.ducks.last, isFalse, reason: 'a voce zitta la musica torna su');
    expect(find.text('SONO IO'), findsOneWidget);
  });

  testWidgets('a voce finita la musica torna su, e il testo resta tutto', (tester) async {
    await open(tester);
    for (var i = 0; i < 90; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(ear.ducks.last, isFalse);
    expect(find.textContaining('Di notte la famiglia elimina una persona.'), findsOneWidget);
    expect(find.textContaining('Passatevi il telefono.'), findsOneWidget);
    expect(visibleScript(tester), contains('Passatevi il telefono.'));
  });

  testWidgets('senza animazioni il testo è subito tutto lì, ma la voce parla lo stesso', (tester) async {
    await open(tester, animations: false);
    expect(find.textContaining('Passatevi il telefono.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(ear.said, isNotEmpty);
    for (var i = 0; i < 10 && find.text('COMINCIA LA NOTTE').evaluate().isEmpty; i++) {
      await tester.tap(find.text('CONTINUA A LEGGERE'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('COMINCIA LA NOTTE'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 20));
    expect(ear.ducks.last, isFalse);
  });

  testWidgets('con il narratore umano il telefono non parla: il copione è da leggere', (tester) async {
    await open(tester, narrator: elio);
    expect(find.text('LEGGE ELIO, AD ALTA VOCE'), findsOneWidget);
    expect(find.text('PARLA IL NARRATORE'), findsNothing);
    expect(find.textContaining('Passatevi il telefono.'), findsOneWidget, reason: 'il testo è tutto lì da subito');
    await tester.pump(const Duration(seconds: 10));
    expect(ear.said, isEmpty);
    expect(ear.ducks, isEmpty);
  });

  testWidgets('con l\'audio spento il copione torna da leggere ad alta voce', (tester) async {
    ear.enabled = false;
    await open(tester);
    expect(find.text('LEGGETE AD ALTA VOCE'), findsOneWidget);
    await tester.pump(const Duration(seconds: 10));
    expect(ear.said, isEmpty);
  });
}
