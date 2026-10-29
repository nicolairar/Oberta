// The walk of the Cappello and Volto skins audit, as a player does it: the
// real app on the test backend, from the street into the Bottega, every
// piece of the two departments on the dial (as the bust and as the seat
// card), a few bought and worn, then the barber with every option, then a
// table. A screenshot at every step, at the device's own size.
//
// Run on a device by integration_test/skins_walk_test.dart, headless by
// tool/audit/skins_walk_headless_test.dart.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/l10n/app_language.dart';
import 'package:oberta/l10n/lobby_language.dart';
import 'package:oberta/main.dart';
import 'package:oberta/online/fake_online.dart';
import 'package:oberta/online/game/game_clock.dart';
import 'package:oberta/online/online_services.dart';
import 'package:oberta/settings/app_settings.dart';
import 'package:oberta/settings/settings_store.dart';
import 'package:oberta/ui/avatar/avatar_look.dart';
import 'package:oberta/ui/screens/online/online_game_screen.dart';
import 'package:oberta/ui/widgets/targa.dart';

/// The three players of the audit (tool/audit/skins_cappello_volto_test.dart).
(String, FaceFeatures, String) _player(String who) => switch (who) {
  'vito' => ('vito', const FaceFeatures(hair: HairStyle.crewCut, hairColor: HairColor.darkBrown, shape: FaceShape.square, presentation: Presentation.man), 'porcelain'),
  'rosalinda' => (
    'rosalinda',
    const FaceFeatures(hair: HairStyle.long, hairColor: HairColor.chestnut, shape: FaceShape.heart, brows: BrowShape.thin, mouth: MouthShape.lipstickSmile, lips: LipColor.red, presentation: Presentation.woman),
    'olive',
  ),
  _ => (
    'nadia',
    const FaceFeatures(hair: HairStyle.afro, shape: FaceShape.round, eyes: EyeShape.doe, brows: BrowShape.arched, mouth: MouthShape.lipstick, lips: LipColor.wine, presentation: Presentation.woman),
    'ebony',
  ),
};

/// Bought and worn on the way, one per kind.
const _buy = {'hat.borsalino', 'face.walrus', 'glasses.aviator', 'tattoo.koi', 'eyeShine.star'};

final _screen = GlobalKey();
late Directory _out;
var _n = 0;

/// Real work outside the test's fake clock: `tester.runAsync` headless,
/// the call itself on a device.
late Future<T?> Function<T>(Future<T> Function() work) _io;

Future<void> _shot(WidgetTester tester, String name) async {
  await tester.pump();
  final boundary = _screen.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final ratio = tester.view.devicePixelRatio;
  final bytes = await _io(() async {
    final image = await boundary.toImage(pixelRatio: ratio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  });
  File('${_out.path}/${(_n++).toString().padLeft(3, '0')}_$name.png').writeAsBytesSync(bytes ?? Uint8List(0));
}

Future<void> _wait(WidgetTester tester, int ms) async {
  for (var t = 0; t < ms; t += 50) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// The thumbnails on the dial's rim, left to right.
List<(String, Rect)> _rim(WidgetTester tester) {
  final found = find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('shop.item.') && w is GestureDetector);
  final all = [
    for (final e in found.evaluate())
      ((e.widget.key! as ValueKey<String>).value.substring('shop.item.'.length), tester.getRect(find.byWidget(e.widget))),
  ]..sort((a, b) => a.$2.center.dx.compareTo(b.$2.center.dx));
  return all;
}

/// The piece under the notch: the biggest thumbnail.
(String, Rect)? _picked(WidgetTester tester) {
  final rim = _rim(tester);
  if (rim.isEmpty) return null;
  return rim.reduce((a, b) => a.$2.width >= b.$2.width ? a : b);
}

Future<void> _walkDial(WidgetTester tester, String dept, {required bool right, required String view}) async {
  final seen = <String>{};
  for (var guard = 0; guard < 120; guard++) {
    final picked = _picked(tester);
    if (picked == null) return;
    if (seen.add(picked.$1)) {
      await _shot(tester, '${dept}_${view}_${picked.$1}');
      if (view == 'bust' && _buy.contains(picked.$1)) await _buyAndWear(tester, picked.$1);
    }
    final next = [
      for (final t in _rim(tester))
        if (right ? t.$2.center.dx > picked.$2.center.dx + 8 : t.$2.center.dx < picked.$2.center.dx - 8) t,
    ];
    if (next.isEmpty) return;
    final target = right ? next.first : next.last;
    await tester.tap(find.byKey(Key('shop.item.${target.$1}')));
    await _wait(tester, 650);
  }
}

Future<void> _buyAndWear(WidgetTester tester, String id) async {
  // Buy (and confirm), then wear: a third tap would take it off again.
  for (var step = 0; step < 2; step++) {
    final action = find.byKey(const Key('shop.action'));
    if (action.evaluate().isEmpty) return;
    await tester.tap(action);
    await _wait(tester, 700);
    final confirm = find.byKey(const Key('shop.confirm'));
    if (confirm.evaluate().isNotEmpty) {
      await _shot(tester, 'buy_$id');
      await tester.tap(confirm.first);
      await _wait(tester, 900);
    }
  }
  await _shot(tester, 'worn_$id');
}

/// Waits for [future] while the frames go on (the test backend answers on
/// timers, which only run while the test pumps).
Future<T> _settle<T>(WidgetTester tester, Future<T> future) async {
  var done = false;
  late T value;
  future.then((v) {
    value = v;
    done = true;
  });
  for (var i = 0; i < 400 && !done; i++) {
    await tester.pump(const Duration(milliseconds: 5));
  }
  if (!done) throw StateError('the test backend did not answer');
  return value;
}

Future<void> _back(WidgetTester tester) async {
  final back = find.byType(TargaBackButton);
  if (back.evaluate().isNotEmpty) {
    await tester.tap(back.first);
  } else {
    await tester.state<NavigatorState>(find.byType(Navigator).first).maybePop();
  }
  // The walk back to the street, whole: a tap to skip it would land on a
  // poster once the walk is over, and open a screen.
  await _wait(tester, 6000);
}

/// The whole walk, as [who] (vito, nadia or rosalinda), with the
/// screenshots in [out].
///
/// [clock] runs the test backend's game (headless: one that only goes on
/// by hand, so no timer outlives the test).
Future<void> skinsWalk(
  WidgetTester tester, {
  required String who,
  required String out,
  required Future<T?> Function<T>(Future<T> Function() work) io,
  GameClock? clock,
  bool shop = true,
}) async {
  _io = io;
  _n = 0;
    _out = Directory(out)..createSync(recursive: true);
    for (final f in _out.listSync().whereType<File>()) {
      f.deleteSync();
    }
    // ignore: avoid_print
    print('SKINS_WALK_OUT=${_out.path}');
    AppSettings.instance = AppSettings(MemorySettingsStore())..language = AppLanguage.it;
    final online = FakeOnline(clock: clock)..signInReady(handle: _player(who).$1, coins: 999999, level: 30);
    OnlineServices.instance = online.services;
    await online.services.profiles.saveFace(_player(who).$2.toJson(), tone: _player(who).$3);
    // Without the shop part ([shop] false): straight to the barber, wearing
    // what the shop part buys.
    if (!shop) {
      for (final id in _buy) {
        online.shop.gift('me', id);
        await online.shop.equip(id);
      }
    }

    await tester.pumpWidget(RepaintBoundary(key: _screen, child: const ObertaApp()));
    await _wait(tester, 4000);
    await _shot(tester, 'street');

    if (shop) {
      // Into the Bottega.
      await tester.tap(find.byKey(const Key('home.shopSign')));
      await _wait(tester, 6000);
      await _shot(tester, 'shop');
      for (final dept in ['hats', 'face']) {
        final medal = find.byKey(Key('shop.dept.$dept'));
        await tester.ensureVisible(medal);
        await _wait(tester, 300);
        await tester.tap(medal);
        await _wait(tester, 900);
        await tester.tap(find.byKey(const Key('shop.view.bust')));
        await _wait(tester, 400);
        await _walkDial(tester, dept, right: true, view: 'bust');
        // And back, as the table sees it.
        await tester.tap(find.byKey(const Key('shop.view.card')));
        await _wait(tester, 600);
        await _walkDial(tester, dept, right: false, view: 'card');
        await tester.tap(find.byKey(const Key('shop.view.bust')));
        await _wait(tester, 400);
      }
      await _back(tester);
    }
    await _shot(tester, 'street_dressed');

    // The barber: every tab, every option.
    await tester.tap(find.byKey(const Key('home.barberSign')));
    await _wait(tester, 6000);
    await _shot(tester, 'barber');
    final all = find.byKey(const Key('mirror.showAll'));
    if (all.evaluate().isNotEmpty) {
      await tester.tap(all);
      await _wait(tester, 500);
    }
    final tabs = find.byType(Tab).evaluate().length;
    for (var t = 0; t < tabs; t++) {
      await tester.tap(find.byType(Tab).at(t));
      await _wait(tester, 700);
      // Every option of the tab (the page is built whole), scrolled to one
      // by one.
      final options = {
        for (final e in find.byWidgetPredicate((w) => w.key is ValueKey<String> && RegExp(r'^mirror\.[a-z -]+\.[A-Za-z]+$').hasMatch((w.key! as ValueKey<String>).value)).evaluate())
          (e.widget.key! as ValueKey<String>).value,
      }.toList();
      for (final key in options.where((k) => !k.startsWith('mirror.preset.') && !k.startsWith('mirror.outfit.') && !k.startsWith('mirror.presentation.') && !k.startsWith('mirror.present.'))) {
        final option = find.byKey(Key(key));
        if (option.evaluate().isEmpty) continue;
        await tester.ensureVisible(option);
        await _wait(tester, 150);
        await tester.tap(option, warnIfMissed: false);
        await _wait(tester, 350);
        await _shot(tester, 'barber_${key.substring('mirror.'.length)}');
      }
    }
    // Not saved: the player keeps the face he came in with.
    final undo = find.byKey(const Key('mirror.undo'));
    if (undo.evaluate().isNotEmpty) {
      await tester.tap(undo);
      await _wait(tester, 400);
    }
    await _back(tester);

    // A table: a room of friends and bots, and the game starts.
    final room = online.openRoomAs('me', LobbyLanguage.it);
    await _settle(tester, online.gameAs('me').setBots(room.id, 7));
    await _settle(tester, online.gameAs('me').startGame(room.id));
    final me = await _settle(tester, online.services.profiles.me());
    tester.state<NavigatorState>(find.byType(Navigator).first).push(
      MaterialPageRoute<void>(builder: (_) => OnlineGameScreen(services: online.services, room: room, me: me, clock: clock ?? const SystemGameClock())),
    );
    for (final at in [1500, 4000, 8000]) {
      await _wait(tester, at ~/ 2);
      await _shot(tester, 'table_$at');
    }
    // ignore: avoid_print
    print('SKINS_WALK_SHOTS=$_n');
}
