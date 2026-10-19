import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/l10n/app_language.dart';
import 'package:oberta/online/fake_online.dart';
import 'package:oberta/online/online_services.dart';
import 'package:oberta/ui/screens/online/online_game_screen.dart';

import '../support/languages.dart';
import '../support/manual_clock.dart';
import 'online_game_screen_test.dart' show flush, settled;

/// Carica un font di sistema (se c'è) sotto i nomi usati dall'app, così le
/// foto dello schermo si leggono. Senza, restano i quadratini dei test.
Future<void> _fonts() async {
  const file = '/System/Library/Fonts/Supplemental/Georgia.ttf';
  if (!File(file).existsSync()) return;
  final bytes = File(file).readAsBytesSync();
  for (final family in ['Georgia', 'Roboto', 'serif', 'Courier']) {
    final loader = FontLoader(family)..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
  }
}

Future<void> _shoot(WidgetTester tester, Key key, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory('build/screens').createSync(recursive: true);
    File('build/screens/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

void main() {
  for (final size in const [Size(393, 852), Size(375, 667)]) {
    testWidgets('di giorno la chat è grande, coi numeri e le chiamate in causa (${size.width.toInt()}x${size.height.toInt()})', (tester) async {
      await tester.runAsync(_fonts);
      tester.view.physicalSize = size * 3;
      tester.view.devicePixelRatio = 3;
      tester.view.padding = const FakeViewPadding(top: 47 * 3, bottom: 34 * 3);
      tester.view.viewPadding = const FakeViewPadding(top: 47 * 3, bottom: 34 * 3);
      addTearDown(tester.view.reset);
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

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
      const shot = Key('shot');
      await tester.pumpWidget(RepaintBoundary(key: shot, child: appIn(AppLanguage.it, OnlineGameScreen(services: online.services, room: room, me: me, clock: clock))));
      await flush(tester);

      var day = false;
      for (var i = 0; i < 400 && online.roomOf(room.id)!.status == RoomStatus.playing; i++) {
        if (find.byKey(const Key('online.discussion')).evaluate().isNotEmpty) {
          clock.elapse(const Duration(seconds: 2));
          await flush(tester);
          day = find.byKey(const Key('online.discussion')).evaluate().isNotEmpty;
          if (day) break;
        }
        clock.fireNext();
        await flush(tester);
      }
      expect(day, isTrue, reason: 'si arriva alla discussione');
      final alive = find.byKey(const Key('chat.field')).evaluate().isNotEmpty;

      final lines = [
        ('anna', 'buongiorno a tutti'),
        ('carla', 'qualcuno ha visto qualcosa stanotte?'),
        ('dario', 'io dico che il 13 mente'),
        ('anna', '@bruno tu che ne pensi?'),
        ('carla', 'il 2 era sveglio'),
        ('dario', 'secondo me la famiglia è tra 5 e 7'),
        ('anna', 'votiamo presto'),
        ('carla', 'aspettiamo bruno'),
        ('dario', 'ok'),
        ('anna', 'chi ha il medico?'),
        ('carla', 'non lo dirà mai nessuno'),
      ];
      for (final (who, body) in lines) {
        // Chi è morto stanotte non parla più: si salta.
        await settled(tester, online.gameAs(who).sendChat(room.id, ChatChannel.day, body).then((_) => true, onError: (_) => false));
        clock.elapse(const Duration(milliseconds: 1100));
      }
      await flush(tester);

      expect(find.textContaining(RegExp(r'^\d+ anna: ', multiLine: true), findRichText: true), findsWidgets, reason: 'il numero accanto al nome');
      if (alive) {
        expect(find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('chat.mention-')), findsWidgets);
      }
      await _shoot(tester, shot, 'day_${size.width.toInt()}x${size.height.toInt()}');
      await tester.pumpWidget(const SizedBox());
    });
  }
}
