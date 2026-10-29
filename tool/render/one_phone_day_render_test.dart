// Il giorno sul telefono unico, per guardarlo senza telefono: la scelta del
// voto, «Usa un potere» con la tenda e il potere, il voto a voce e quello
// segreto, i verdetti. `flutter test tool/render/one_phone_day_render_test.dart`
// scrive i PNG (393×852 a 3x) in OUT (build/render/one_phone_day).
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/rules/game_setup.dart';
import 'package:oberta/rules/player.dart';
import 'package:oberta/rules/role.dart';
import 'package:oberta/ui/screens/game_screen.dart';
import 'package:oberta/ui/screens/vote_mode_screen.dart';
import 'package:oberta/ui/theme/app_theme.dart';

final out = Platform.environment['OUT'] ?? 'build/render/one_phone_day';

const _fonts = {
  'Georgia': ['Georgia.ttf', 'Georgia Bold.ttf', 'Georgia Italic.ttf'],
  'serif': ['Georgia.ttf', 'Georgia Bold.ttf'],
  'Courier': ['Courier New.ttf', 'Courier New Bold.ttf'],
};

Future<void> _loadFonts() async {
  const dir = '/System/Library/Fonts/Supplemental';
  for (final MapEntry(key: family, value: files) in _fonts.entries) {
    final loader = FontLoader(family);
    for (final file in files) {
      final f = File('$dir/$file');
      if (f.existsSync()) loader.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
    }
    await loader.load();
  }
  final material =
      '${Platform.environment['FLUTTER_ROOT'] ?? '/opt/homebrew/share/flutter'}'
      '/bin/cache/artifacts/material_fonts';
  for (final (family, files) in [
    ('MaterialIcons', ['MaterialIcons-Regular.otf']),
    ('Roboto', ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf', 'Roboto-Italic.ttf']),
  ]) {
    final loader = FontLoader(family);
    for (final file in files) {
      final f = File('$material/$file');
      if (f.existsSync()) loader.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
    }
    await loader.load();
  }
}

final _key = GlobalKey();

ThemeData _theme() {
  final theme = buildAppTheme();
  return theme.copyWith(textTheme: theme.textTheme.apply(fontFamily: 'Roboto'));
}

Future<void> _shot(WidgetTester tester, String name) async {
  await tester.pump(const Duration(milliseconds: 400));
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      await precacheImage((element.widget as Image).image, element);
    }
  });
  await tester.pump();
  await tester.runAsync(() async {
    final boundary = _key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$out/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

Future<void> _pump(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(393, 852) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  await tester.pumpWidget(
    RepaintBoundary(
      key: _key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: _theme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => home)),
                child: const Text('GIOCA'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('GIOCA'));
  await tester.pumpAndSettle();
}

Future<void> _tapKey(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

Future<void> _seat(WidgetTester tester, Player player) async {
  await tester.tap(find.byKey(ValueKey('seat-${player.id}')));
  await tester.pumpAndSettle();
}

Future<void> _label(WidgetTester tester, String label) async {
  while (find.text(label).evaluate().isEmpty && find.text('CONTINUA A LEGGERE').evaluate().isNotEmpty) {
    await tester.tap(find.text('CONTINUA A LEGGERE'));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

const _names = ['Ada', 'Bruno', 'Carla', 'Dino', 'Elio', 'Fabio', 'Gina', 'Ugo', 'Rosa'];
final _players = [for (final name in _names) Player(id: name.toLowerCase(), name: name)];

/// Nove al tavolo: la Famiglia, il Sindaco, il Pacifista, l'Artigliere...
final _deal = Map.fromIterables(_players, [
  Role.mafioso,
  Role.sindaco,
  Role.pacifista,
  Role.cittadino,
  Role.mafioso,
  Role.artigliere,
  Role.cittadino,
  Role.cittadino,
  Role.cittadino,
]);

/// Fino alla discussione del primo giorno: tutti passano.
Future<void> _toTheDay(WidgetTester tester, LocalVote vote) async {
  await _pump(tester, GameScreen(setup: GameSetup.fromRoles(_deal, vote: vote), random: Random(1)));
  await _label(tester, 'COMINCIA LA NOTTE');
  for (final _ in _players) {
    await _tapKey(tester, 'local.itsMe');
    await _tapKey(tester, 'local.pass');
    await _tapKey(tester, 'local.done');
  }
  await _label(tester, 'APRI LA DISCUSSIONE');
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('la scelta del voto', (tester) async {
    await _pump(tester, VoteModeScreen(players: _players));
    await _shot(tester, '01_vote_mode_voice');
    await _tapKey(tester, 'vote.secret');
    await _shot(tester, '02_vote_mode_secret');
  });

  testWidgets('usa un potere, e il voto a voce', (tester) async {
    await _toTheDay(tester, LocalVote.voice);
    await _shot(tester, '03_day');
    await _tapKey(tester, 'game.usePower');
    await _seat(tester, _players[2]);
    await _shot(tester, '04_power_who');
    await _tapKey(tester, 'game.powerConfirm');
    await _shot(tester, '05_power_curtain');
    await _tapKey(tester, 'local.itsMe');
    await _seat(tester, _players[4]);
    await _shot(tester, '06_power_pacifist');
    await _tapKey(tester, 'game.powerBack');
    await _tapKey(tester, 'game.usePower');
    await _seat(tester, _players[3]);
    await _tapKey(tester, 'game.powerConfirm');
    await _tapKey(tester, 'local.itsMe');
    await _shot(tester, '07_power_none');
    await _tapKey(tester, 'game.powerBack');
    await _tapKey(tester, 'game.usePower');
    await _seat(tester, _players[1]);
    await _tapKey(tester, 'game.powerConfirm');
    await _tapKey(tester, 'local.itsMe');
    await _shot(tester, '08_power_mayor');
    await _tapKey(tester, 'game.powerUse');
    await _shot(tester, '09_day_mayor_revealed');
    await _tapKey(tester, 'local.toVote');
    await _shot(tester, '10_voice_vote');
    await _seat(tester, _players[4]);
    await _shot(tester, '11_voice_vote_selected');
    await _tapKey(tester, 'local.condemn');
    await _shot(tester, '12_voice_verdict');
  });

  testWidgets('il voto segreto', (tester) async {
    await _toTheDay(tester, LocalVote.secret);
    await _tapKey(tester, 'local.toVote');
    await _shot(tester, '13_secret_vote');
    for (final (i, voter) in _players.indexed) {
      await _seat(tester, voter == _players[0] ? _players[4] : _players[0]);
      if (i == 1) await _shot(tester, '14_secret_vote_selected');
      await _tapKey(tester, 'local.castVote');
    }
    await _shot(tester, '15_secret_verdict');
  });
}
