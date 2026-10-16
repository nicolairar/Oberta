// Fotogrammi delle schermate di gioco, per guardarle senza telefono:
// `flutter test tool/render/game_ui_render_test.dart` scrive i PNG in OUT.
// Carica i caratteri di sistema del Mac, così il testo si legge davvero.
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/rules/game_setup.dart';
import 'package:oberta/rules/knowledge.dart';
import 'package:oberta/rules/player.dart';
import 'package:oberta/rules/role.dart';
import 'package:oberta/rules/role_assignment.dart';
import 'package:oberta/ui/screens/game_screen.dart';
import 'package:oberta/ui/theme/app_theme.dart';
import 'package:oberta/ui/widgets/player_grid.dart';

final out = Platform.environment['OUT'] ?? 'build/render/game';

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

/// Il tema dell'app, con i caratteri caricati anche dove i test non li mettono.
ThemeData _theme() {
  final theme = buildAppTheme();
  const label = WidgetStatePropertyAll(
    TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w700, letterSpacing: 1.6, fontSize: 14),
  );
  return theme.copyWith(
    textTheme: theme.textTheme.apply(fontFamily: 'Roboto'),
    elevatedButtonTheme: ElevatedButtonThemeData(style: theme.elevatedButtonTheme.style!.copyWith(textStyle: label)),
    outlinedButtonTheme: OutlinedButtonThemeData(style: theme.outlinedButtonTheme.style!.copyWith(textStyle: label)),
    textButtonTheme: const TextButtonThemeData(style: ButtonStyle(textStyle: label)),
  );
}

Future<void> _shot(WidgetTester tester, String name, {bool settle = true}) async {
  if (settle) await tester.pump(const Duration(milliseconds: 400));
  await tester.runAsync(() async {
    final boundary = _key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1.5);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$out/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

Future<void> _tap(WidgetTester tester, String label) async {
  for (var i = 0; i < 12 && find.text(label).evaluate().isEmpty; i++) {
    final more = find.text('CONTINUA A LEGGERE');
    if (more.evaluate().isEmpty) break;
    await tester.tap(more);
    await tester.pumpAndSettle();
  }
  final target = find.text(label).first;
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target, warnIfMissed: false);
  await tester.pumpAndSettle();
}

/// Un filmato: lo si salta e si va avanti.
Future<void> _film(WidgetTester tester) async {
  if (find.text('SALTA').evaluate().isNotEmpty) {
    await tester.tap(find.text('SALTA'));
    await tester.pump();
  }
  for (var i = 0; i < 40 && find.text('AVANTI').evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 500));
  }
  if (find.text('AVANTI').evaluate().isEmpty) {
    debugPrint([for (final t in tester.widgetList<Text>(find.byType(Text))) t.data].join(' | '));
  }
  await tester.tap(find.text('AVANTI'));
  await tester.pumpAndSettle();
}

const _names = [
  'Ada',
  'Bruno',
  'Carla',
  'Dino',
  'Elio',
  'Fabio',
  'Gina',
  'Ugo',
  'Massimiliano',
  'Rosa',
  'Teresa',
  'Vito',
  'Lucia',
  'Nino',
  'Ottavio',
  'Pia',
];

Future<void> _pump(WidgetTester tester, Size screen, Map<Player, Role> deal) async {
  tester.view.physicalSize = screen * 3;
  tester.view.devicePixelRatio = 3;
  tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
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
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => GameScreen(setup: GameSetup.fromRoles(deal), random: Random(1)),
                  ),
                ),
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

/// Una notte intera, un giorno e un verdetto, con le foto delle tappe.
Future<void> _round(WidgetTester tester, String tag, Size screen, int count) async {
  final players = [for (var i = 0; i < count; i++) Player(id: 'p$i', name: _names[i])];
  await _pump(tester, screen, Map.fromIterables(players, rolesForPlayerCount(count)));
  await _shot(tester, '${tag}_01_night_script');
  await _tap(tester, 'COMINCIA LA NOTTE');
  await _shot(tester, '${tag}_02_handoff');
  for (final (i, player) in players.indexed) {
    await _tap(tester, 'SONO IO');
    if (i == 0) {
      await _shot(tester, '${tag}_03_task_kill');
      await _tap(tester, players[2].name);
      await _shot(tester, '${tag}_04_task_kill_selected');
      await _tap(tester, 'CONFERMA');
      await _shot(tester, '${tag}_05_task_done');
    } else if (i == count - 1) {
      await _shot(tester, '${tag}_06_task_cover');
      await _tap(tester, 'PASSO');
    } else {
      await _tap(tester, 'PASSO');
    }
    await _tap(tester, 'FATTO');
    expect(player.name, isNotEmpty);
  }
  await _shot(tester, '${tag}_07_crime_intro');
  await tester.tap(find.text('BUIO IN SALA'));
  await tester.pump(const Duration(milliseconds: 500));
  await _film(tester);
  await _shot(tester, '${tag}_08_dawn');
  await _tap(tester, 'APRI LA DISCUSSIONE');
  await _shot(tester, '${tag}_09_day');
  await _tap(tester, 'AL VOTO');
  await _shot(tester, '${tag}_10_vote');
  await _tap(tester, players[1].name);
  await _shot(tester, '${tag}_11_vote_selected');
  await _tap(tester, 'CONDANNA');
  await _film(tester);
  await _shot(tester, '${tag}_12_verdict');
  await _tap(tester, 'GIRA LA CARTA');
  await _shot(tester, '${tag}_13_verdict_turned');
}

void main() {
  setUpAll(_loadFonts);
  const phones = {'s': Size(375, 667), 'm': Size(393, 852), 'l': Size(430, 932)};
  final only = Platform.environment['PHONE'];
  final counts = (Platform.environment['COUNTS'] ?? '4,8,16').split(',').map(int.parse);

  for (final MapEntry(key: phone, value: size) in phones.entries) {
    if (only != null && !only.split(',').contains(phone)) continue;
    for (final count in counts) {
      testWidgets('partita $phone $count', (tester) async {
        addTearDown(tester.view.reset);
        await _round(tester, '${phone}_$count', size, count);
      });
    }
    testWidgets('rimescolo $phone', (tester) async {
      addTearDown(tester.view.reset);
      tester.view.physicalSize = size * 3;
      tester.view.devicePixelRatio = 3;
      final players = [for (var i = 0; i < 8; i++) Player(id: 'p$i', name: _names[i])];
      await tester.pumpWidget(
        RepaintBoundary(
          key: _key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: _theme(),
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.fromLTRB(24, 120, 24, 120),
                child: PlayerGrid(
                  players: players,
                  isAlive: (_) => true,
                  knowledgeOf: (_) => Knowledge.none,
                  selectable: players,
                  shuffled: true,
                ),
              ),
            ),
          ),
        ),
      );
      for (final ms in [0, 200, 400, 600, 800, 1100]) {
        await tester.pump(Duration(milliseconds: ms == 0 ? 0 : 200));
        if (ms == 1100) await tester.pump(const Duration(milliseconds: 100));
        await _shot(tester, '${phone}_shuffle_$ms', settle: false);
      }
    });
    testWidgets('finale $phone', (tester) async {
      addTearDown(tester.view.reset);
      const a = Player(id: 'a', name: 'Ada'), b = Player(id: 'b', name: 'Bruno'), c = Player(id: 'c', name: 'Carla');
      await _pump(tester, size, {a: Role.padrino, b: Role.pregiudicato, c: Role.cittadino});
      await _tap(tester, 'COMINCIA LA NOTTE');
      await _tap(tester, 'SONO IO');
      await _tap(tester, 'Carla');
      await _tap(tester, 'CONFERMA');
      await _tap(tester, 'FATTO');
      for (var i = 0; i < 2; i++) {
        await _tap(tester, 'SONO IO');
        await _tap(tester, 'PASSO');
        await _tap(tester, 'FATTO');
      }
      await tester.tap(find.text('BUIO IN SALA'));
      await tester.pump(const Duration(milliseconds: 500));
      await _film(tester);
      await _tap(tester, 'FINALE');
      await _shot(tester, '${phone}_end');
    });
  }
}
