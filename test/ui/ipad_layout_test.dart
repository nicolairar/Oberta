import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/l10n/app_language.dart';
import 'package:oberta/main.dart';
import 'package:oberta/network/fake_local_session.dart';
import 'package:oberta/online/fake_online.dart';
import 'package:oberta/online/online_account.dart';
import 'package:oberta/online/online_models.dart';
import 'package:oberta/rules/game_setup.dart';
import 'package:oberta/ui/screens/avatar/barber_mirror_screen.dart';
import 'package:oberta/ui/screens/game_screen.dart';
import 'package:oberta/ui/screens/lobby_screen.dart';
import 'package:oberta/ui/screens/online/online_game_screen.dart';
import 'package:oberta/ui/screens/online/profile_sheet.dart';
import 'package:oberta/ui/screens/settings_screen.dart';
import 'package:oberta/ui/screens/shop/shop_screen.dart';

import '../support/languages.dart';
import '../support/manual_clock.dart';
import 'game_screen_test.dart' show roles;
import 'online_game_screen_test.dart' show flush, settled;

/// Gli schermi dell'iPad: in piedi, il grande, e coricato.
const ipads = {
  'air_portrait': Size(820, 1180),
  'pro_portrait': Size(1024, 1366),
  'air_landscape': Size(1180, 820),
};

const _shot = Key('ipad.shot');

Future<void> _fonts() async {
  const file = '/System/Library/Fonts/Supplemental/Georgia.ttf';
  if (!File(file).existsSync()) return;
  final bytes = File(file).readAsBytesSync();
  for (final family in ['Georgia', 'Roboto', 'serif', 'Courier']) {
    final loader = FontLoader(family)..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
  }
}

Future<void> _save(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_shot));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory('build/screens/ipad').createSync(recursive: true);
    File('build/screens/ipad/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

Future<void> _useIpad(WidgetTester tester, Size size) async {
  await tester.runAsync(_fonts);
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  tester.view.padding = const FakeViewPadding(top: 24 * 2, bottom: 20 * 2);
  tester.view.viewPadding = const FakeViewPadding(top: 24 * 2, bottom: 20 * 2);
  addTearDown(tester.view.reset);
  tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

Future<void> _frames(WidgetTester tester, [int count = 20]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull, reason: 'fotogramma $i');
  }
}

Future<void> _open(WidgetTester tester, String name, Widget Function(BuildContext) page) async {
  await tester.pumpWidget(RepaintBoundary(
    key: _shot,
    child: appIn(
      AppLanguage.it,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: page)),
            child: const Text('go'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('go'));
  await _frames(tester);
  await _save(tester, name);
  await tester.pumpWidget(const SizedBox());
}

void main() {
  for (final MapEntry(key: device, value: size) in ipads.entries) {
    group('iPad $device', () {
      testWidgets('il vicolo', (tester) async {
        await _useIpad(tester, size);
        await tester.pumpWidget(const RepaintBoundary(key: _shot, child: ObertaApp()));
        await _frames(tester, 40);
        await _save(tester, '${device}_home');
        await tester.pumpWidget(const SizedBox());
      });

      testWidgets('la sala d\'attesa', (tester) async {
        await _useIpad(tester, size);
        await _open(tester, '${device}_lobby', (_) => LobbyScreen(session: FakeLocalSession(hostName: 'Tu')));
      });

      testWidgets('la partita sul telefono di tutti', (tester) async {
        await _useIpad(tester, size);
        await _open(tester, '${device}_game', (_) => GameScreen(setup: GameSetup.fromRoles(roles), random: Random(1)));
      });

      testWidgets('le impostazioni', (tester) async {
        await _useIpad(tester, size);
        await _open(tester, '${device}_settings', (_) => SettingsScreen());
      });

      testWidgets('la bottega', (tester) async {
        await _useIpad(tester, size);
        WornLooks.clear();
        final online = FakeOnline()..signInReady(handle: 'anna');
        final account = OnlineAccount(online.services);
        await _open(tester, '${device}_shop', (_) => ShopScreen(account: account, shop: online.shop));
      });

      testWidgets('lo specchio del barbiere', (tester) async {
        await _useIpad(tester, size);
        WornLooks.clear();
        final online = FakeOnline()..signInReady(handle: 'anna');
        final profile = await tester.runAsync(online.profiles.me);
        await _open(tester, '${device}_barber',
            (_) => BarberMirrorScreen(services: online.services, profile: profile!));
      });

      testWidgets('il fascicolo', (tester) async {
        await _useIpad(tester, size);
        final online = FakeOnline()..signInReady(handle: 'anna');
        final account = OnlineAccount(online.services);
        await tester.pumpWidget(RepaintBoundary(
          key: _shot,
          child: appIn(
            AppLanguage.it,
            Builder(
              builder: (context) => Scaffold(
                body: TextButton(onPressed: () => showProfileSheet(context, account: account), child: const Text('go')),
              ),
            ),
          ),
        ));
        await tester.tap(find.text('go'));
        await _frames(tester);
        await _save(tester, '${device}_profile');
        await tester.pumpWidget(const SizedBox());
      });

      testWidgets('la partita online', (tester) async {
        await _useIpad(tester, size);
        final clock = ManualClock();
        final online = FakeOnline(accountId: 'bruno', clock: clock)..signInReady(handle: 'bruno');
        for (final who in ['anna', 'carla', 'dario']) {
          online.addPlayer(who, handle: who);
        }
        final room = online.openRoomAs('anna', AppLanguage.it);
        for (final who in ['bruno', 'carla', 'dario']) {
          online.joinAs(who, room.code);
        }
        await settled(tester, online.gameAs('anna').setBots(room.id, 4));
        await settled(tester, online.gameAs('anna').startGame(room.id));
        final me = await settled(tester, online.services.profiles.me());
        await tester.pumpWidget(RepaintBoundary(
          key: _shot,
          child: appIn(AppLanguage.it, OnlineGameScreen(services: online.services, room: room, me: me, clock: clock)),
        ));
        await flush(tester);
        expect(tester.takeException(), isNull);
        await _save(tester, '${device}_online_game');
        await tester.pumpWidget(const SizedBox());
      });
    });
  }
}
