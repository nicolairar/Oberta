import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/l10n/app_language.dart';
import 'package:oberta/rules/game_setup.dart';
import 'package:oberta/rules/player.dart';
import 'package:oberta/rules/role.dart';
import 'package:oberta/ui/screens/game_screen.dart';
import 'package:oberta/ui/screens/role_reveal_screen.dart';

import '../support/desktop_shots.dart';
import '../support/languages.dart';
import '../support/local_game.dart';

/// Photos of the one-phone game on the seat table, for the eye: the curtain
/// between hands, the shuffled night pick, the open vote, the verdict. They
/// land in build/screens/local/.
const ada = Player(id: 'ada', name: 'Ada');
const bruno = Player(id: 'bruno', name: 'Bruno');
const carla = Player(id: 'carla', name: 'Carla');
const dario = Player(id: 'dario', name: 'Dario');
const elena = Player(id: 'elena', name: 'Elena');
const fabio = Player(id: 'fabio', name: 'Fabio');
const gina = Player(id: 'gina', name: 'Gina');

final deal = {
  ada: Role.mafioso,
  bruno: Role.detective,
  carla: Role.medico,
  dario: Role.sarto,
  elena: Role.cittadino,
  fabio: Role.cittadino,
  gina: Role.sindaco,
};

const _shot = Key('local.shot');

Future<void> _fonts() async {
  const file = '/System/Library/Fonts/Supplemental/Georgia.ttf';
  if (!File(file).existsSync()) return;
  final bytes = File(file).readAsBytesSync();
  for (final family in ['Georgia', 'Roboto', 'serif', 'Courier']) {
    final loader = FontLoader(family)..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
  }
}

Future<void> _save(WidgetTester tester, String name, {Key key = _shot}) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: key == _shot ? 2 : 1);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory('build/screens/local').createSync(recursive: true);
    File('build/screens/local/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

Future<void> _phone(WidgetTester tester) async {
  await tester.runAsync(_fonts);
  tester.view.physicalSize = const Size(393, 852) * 3;
  tester.view.devicePixelRatio = 3;
  tester.view.padding = const FakeViewPadding(top: 47 * 3, bottom: 34 * 3);
  tester.view.viewPadding = const FakeViewPadding(top: 47 * 3, bottom: 34 * 3);
  addTearDown(tester.view.reset);
  tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

/// Plays up to the open vote, taking the photos on the way.
Future<void> _toTheVote(WidgetTester tester, Future<void> Function(String name) shoot) async {
  await tapLabel(tester, 'COMINCIA LA NOTTE');
  await shoot('curtain');
  await tapKey(tester, 'local.itsMe');
  await shoot('night_pick_ada');
  await tapSeat(tester, elena);
  await tapKey(tester, 'local.confirm');
  await tapKey(tester, 'local.done');
  await tapKey(tester, 'local.itsMe');
  await tapSeat(tester, ada);
  await shoot('night_pick_bruno');
  await tapKey(tester, 'local.confirm');
  await shoot('night_finding_bruno');
  await tapKey(tester, 'local.done');
  for (final _ in [carla, dario, elena, fabio, gina]) {
    await tapKey(tester, 'local.itsMe');
    await tapKey(tester, 'local.pass');
    await tapKey(tester, 'local.done');
  }
  await tester.tap(find.text('BUIO IN SALA'));
  await tester.pump(const Duration(milliseconds: 500));
  await tapLabel(tester, 'SALTA');
  await tapLabel(tester, 'AVANTI');
  await tapLabel(tester, 'APRI LA DISCUSSIONE');
  await shoot('day');
  await tapKey(tester, 'local.toVote');
  await tapSeat(tester, dario);
  await tapSeat(tester, dario);
  await tapSeat(tester, ada);
  await shoot('vote');
}

void main() {
  testWidgets('the one-phone game on the seat table, on a phone', (tester) async {
    await _phone(tester);
    await tester.pumpWidget(RepaintBoundary(
      key: _shot,
      child: appIn(AppLanguage.it, GameScreen(setup: GameSetup.fromRoles(deal), random: Random(3), seating: Random(5))),
    ));
    await tester.pumpAndSettle();
    await _toTheVote(tester, (name) => _save(tester, 'phone_$name'));
    await tapSeat(tester, ada); // Dario
    await tapSeat(tester, dario); // Fabio
    await tapSeat(tester, dario); // Gina
    await _save(tester, 'phone_verdict');
  });

  testWidgets('the card behind the curtain, on a phone', (tester) async {
    await _phone(tester);
    await tester.pumpWidget(RepaintBoundary(
      key: _shot,
      child: appIn(AppLanguage.it, RoleRevealScreen(setup: GameSetup.fromRoles(deal))),
    ));
    await tester.pumpAndSettle();
    await _save(tester, 'phone_card_curtain');
    await tapKey(tester, 'local.itsMe');
    await _save(tester, 'phone_card');
  });

  testWidgets('the one-phone game on the seat table, on desktop', (tester) async {
    await useDesktop(tester, const Size(1920, 1080));
    await tester.pumpWidget(desktopApp(GameScreen(setup: GameSetup.fromRoles(deal), random: Random(3), seating: Random(5))));
    await tester.pumpAndSettle();
    await _toTheVote(tester, (name) async {
      if (name == 'night_pick_bruno' || name == 'vote' || name == 'curtain') await saveDesktopShot(tester, 'local_$name');
    });
  });
}
