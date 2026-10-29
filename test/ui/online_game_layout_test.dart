import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/l10n/app_language.dart';
import 'package:oberta/l10n/lobby_language.dart';
import 'package:oberta/online/fake_online.dart';
import 'package:oberta/online/online_services.dart';
import 'package:oberta/ui/screens/online/online_game_screen.dart';

import 'package:oberta/ui/screens/online/game/chat_dock.dart';

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

/// Le altezze del tavolo e della chat, per confrontare le fasi.
({double table, double chat})? _slots(WidgetTester tester) {
  final table = find.byKey(const Key('game.tableSlot'));
  final chat = find.byKey(const Key('game.chatSlot'));
  if (table.evaluate().isEmpty || chat.evaluate().isEmpty) return null;
  return (table: tester.getSize(table).height, chat: tester.getSize(chat).height);
}

void _phases() {
  for (final size in const [Size(393, 852), Size(375, 667), Size(430, 932)]) {
    final tag = '${size.width.toInt()}x${size.height.toInt()}';
    testWidgets('ogni fase ha lo stesso tavolo e la stessa chat ($tag)', (tester) async {
      await tester.runAsync(_fonts);
      final top = size.height > 700 ? 47.0 : 20.0;
      final bottom = size.height > 700 ? 34.0 : 0.0;
      tester.view.physicalSize = size * 3;
      tester.view.devicePixelRatio = 3;
      tester.view.padding = FakeViewPadding(top: top * 3, bottom: bottom * 3);
      tester.view.viewPadding = FakeViewPadding(top: top * 3, bottom: bottom * 3);
      addTearDown(tester.view.reset);
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
        disableAnimations: true,
      );
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

      final clock = ManualClock();
      final online = FakeOnline(accountId: 'bruno', clock: clock)..signInReady(handle: 'bruno');
      for (final who in ['annalisa', 'carla', 'dario']) {
        online.addPlayer(who, handle: who);
      }
      final room = online.openRoomAs('annalisa', LobbyLanguage.it);
      for (final who in ['bruno', 'carla', 'dario']) {
        online.joinAs(who, room.code);
      }
      await settled(tester, online.gameAs('annalisa').setBots(room.id, 5));
      await settled(tester, online.gameAs('annalisa').startGame(room.id));
      final me = await settled(tester, online.services.profiles.me());
      const shot = Key('shot');
      await tester.pumpWidget(
        RepaintBoundary(
          key: shot,
          child: appIn(AppLanguage.it, OnlineGameScreen(services: online.services, room: room, me: me, clock: clock)),
        ),
      );
      await flush(tester);

      const phases = {
        'night_task': Key('online.pass'),
        'night_wait': Key('online.waiting'),
        'dawn': Key('online.dawn'),
        'discussion': Key('online.discussion'),
        'vote': Key('online.vote'),
        'verdict': Key('online.verdict'),
      };
      final taken = <String>{};
      final heights = <String, ({double table, double chat})>{};
      for (
        var i = 0;
        i < 600 && online.roomOf(room.id)!.status == RoomStatus.playing && taken.length < phases.length;
        i++
      ) {
        for (final MapEntry(key: name, value: key) in phases.entries) {
          if (taken.contains(name) || find.byKey(key).evaluate().isEmpty) continue;
          clock.elapse(const Duration(seconds: 1));
          await flush(tester);
          if (find.byKey(key).evaluate().isEmpty) continue;
          taken.add(name);
          if (_slots(tester) case final s?) heights[name] = s;
          await _shoot(tester, shot, '${name}_$tag');
        }
        clock.fireNext();
        await flush(tester);
      }
      expect(taken, containsAll(['dawn', 'discussion', 'vote', 'verdict']));
      expect(heights.length, greaterThanOrEqualTo(4), reason: 'le fasi usano la stessa pagina');
      final first = heights.values.first;
      for (final MapEntry(key: name, value: h) in heights.entries) {
        expect(h.table, closeTo(first.table, 0.5), reason: 'il tavolo di $name');
        expect(h.chat, closeTo(first.chat, 0.5), reason: 'la chat di $name');
      }
      await tester.pumpWidget(const SizedBox());
    });
  }
}

void main() {
  _phases();
  for (final size in const [Size(393, 852), Size(375, 667)]) {
    testWidgets(
      'di giorno la chat è grande, coi numeri e le chiamate in causa (${size.width.toInt()}x${size.height.toInt()})',
      (tester) async {
        await tester.runAsync(_fonts);
        tester.view.physicalSize = size * 3;
        tester.view.devicePixelRatio = 3;
        tester.view.padding = const FakeViewPadding(top: 47 * 3, bottom: 34 * 3);
        tester.view.viewPadding = const FakeViewPadding(top: 47 * 3, bottom: 34 * 3);
        addTearDown(tester.view.reset);
        tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
          disableAnimations: true,
        );
        addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

        final clock = ManualClock();
        final online = FakeOnline(accountId: 'bruno', clock: clock)..signInReady(handle: 'bruno');
        for (final who in ['anna', 'carla', 'dario']) {
          online.addPlayer(who, handle: who);
        }
        final room = online.openRoomAs('anna', LobbyLanguage.it);
        for (final who in ['bruno', 'carla', 'dario']) {
          online.joinAs(who, room.code);
        }
        await settled(tester, online.gameAs('anna').setBots(room.id, 4));
        await settled(tester, online.gameAs('anna').startGame(room.id));
        final me = await settled(tester, online.services.profiles.me());
        const shot = Key('shot');
        await tester.pumpWidget(
          RepaintBoundary(
            key: shot,
            child: appIn(AppLanguage.it, OnlineGameScreen(services: online.services, room: room, me: me, clock: clock)),
          ),
        );
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
          await settled(
            tester,
            online.gameAs(who).sendChat(room.id, ChatChannel.day, body).then((_) => true, onError: (_) => false),
          );
          clock.elapse(const Duration(milliseconds: 1100));
        }
        await flush(tester);

        expect(find.byType(ChatSeatChip), findsWidgets, reason: 'il numero di posto accanto al nome');
        expect(
          find.textContaining(RegExp(r'^(anna|carla|dario): ', multiLine: true), findRichText: true),
          findsWidgets,
          reason: 'il nome dopo il numero',
        );
        if (alive) {
          expect(
            find.byWidgetPredicate(
              (w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('chat.mention-'),
            ),
            findsWidgets,
          );
        }
        await _shoot(tester, shot, 'day_${size.width.toInt()}x${size.height.toInt()}');
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
