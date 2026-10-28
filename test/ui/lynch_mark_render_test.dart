import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/l10n/app_language.dart';
import 'package:oberta/online/fake_online.dart';
import 'package:oberta/online/online_services.dart';
import 'package:oberta/rules/knowledge.dart';
import 'package:oberta/rules/player.dart';
import 'package:oberta/rules/role.dart';
import 'package:oberta/ui/screens/online/online_game_screen.dart';
import 'package:oberta/ui/widgets/lynch_mark.dart';
import 'package:oberta/ui/widgets/player_grid.dart';

import '../support/languages.dart';
import '../support/manual_clock.dart';
import 'online_game_screen_test.dart' show flush, settled;

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

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(393, 852) * 3;
  tester.view.devicePixelRatio = 3;
  tester.view.padding = const FakeViewPadding(top: 47 * 3, bottom: 34 * 3);
  tester.view.viewPadding = const FakeViewPadding(top: 47 * 3, bottom: 34 * 3);
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('online: il linciaggio si gioca sul posto, poi la carta resta sul posto', (tester) async {
    await tester.runAsync(_fonts);
    _phone(tester);
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
    await tester.pumpWidget(RepaintBoundary(
      key: shot,
      child: appIn(AppLanguage.it, OnlineGameScreen(services: online.services, room: room, me: me, clock: clock)),
    ));
    await flush(tester);

    var mid = false;
    var after = false;
    for (var i = 0; i < 800 && online.roomOf(room.id)!.status == RoomStatus.playing && !after; i++) {
      final verdict = find.byKey(const Key('online.verdict')).evaluate().isNotEmpty;
      final lynch = find.byType(LynchMark).evaluate().isNotEmpty;
      if (verdict && lynch && !mid) {
        // In pieno linciaggio: la corda è scesa, il timbro batte.
        clock.elapse(const Duration(milliseconds: 750));
        await tester.pump(const Duration(milliseconds: 750));
        await _shoot(tester, shot, 'lynch_online_during');
        mid = true;
      } else if (verdict && lynch && mid) {
        await tester.pump(const Duration(seconds: 2));
        await _shoot(tester, shot, 'lynch_online_after');
        after = true;
        break;
      }
      if (find.byKey(const Key('online.vote')).evaluate().isNotEmpty &&
          find.byKey(const Key('online.abstain')).evaluate().isNotEmpty &&
          find.byKey(const Key('online.myVote')).evaluate().isEmpty) {
        clock.elapse(const Duration(seconds: 2));
        await flush(tester);
        final rows = find.descendant(of: find.byKey(const Key('online.vote')), matching: find.byType(InkWell));
        final target = [
          for (final row in rows.evaluate())
            if ((row.widget as InkWell).onTap != null) row,
        ].lastOrNull;
        if (target != null) {
          await tester.tap(find.byWidget(target.widget));
          await flush(tester);
          await tester.pump(const Duration(milliseconds: 600));
          await _shoot(tester, shot, 'lynch_online_before');
        }
      }
      clock.fireNext();
      await flush(tester);
    }
    expect(after, isTrue, reason: 'prima o poi la piazza lincia qualcuno');
    expect(find.byKey(const Key('online.verdictHeadline')), findsOneWidget);
    // Il verdetto si legge tutto: niente puntini dopo cinque parole.
    for (final key in const [Key('online.verdictHeadline'), Key('online.verdictStory')]) {
      final text = tester.widget<Text>(find.byKey(key));
      expect(text.maxLines, isNull, reason: '$key');
      expect(text.overflow, isNot(TextOverflow.ellipsis), reason: '$key');
      expect(tester.renderObject<RenderParagraph>(find.byKey(key)).didExceedMaxLines, isFalse, reason: '$key');
      expect(text.style!.fontSize, greaterThan(9), reason: '$key resta leggibile');
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a un telefono: il posto del linciato, prima e dopo', (tester) async {
    await tester.runAsync(_fonts);
    _phone(tester);
    final players = [for (final n in ['Ada', 'Bea', 'Cico', 'Dino', 'Elio', 'Febo']) Player(id: n, name: n)];
    Knowledge known(Player p) => p.name == 'Bea' ? Knowledge(role: Role.mafioso, team: Role.mafioso.team) : const Knowledge();
    const shot = Key('shot');
    Widget grid(Player? lynched, {bool dead = false}) => RepaintBoundary(
          key: shot,
          child: appIn(
            AppLanguage.it,
            Scaffold(
              backgroundColor: const Color(0xFF14100C),
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: PlayerGrid(
                  players: players,
                  isAlive: (p) => !(dead && p.name == 'Bea'),
                  knowledgeOf: dead ? known : (_) => const Knowledge(),
                  lynched: lynched,
                ),
              ),
            ),
          ),
        );
    await tester.pumpWidget(grid(null));
    await tester.pump(const Duration(seconds: 3));
    await _shoot(tester, shot, 'lynch_local_before');
    await tester.pumpWidget(grid(players[1], dead: true));
    await tester.pump(const Duration(milliseconds: 750));
    await _shoot(tester, shot, 'lynch_local_during');
    await tester.pump(const Duration(seconds: 2));
    await _shoot(tester, shot, 'lynch_local_after');
    expect(find.byKey(const Key('lynch.stamp')), findsOneWidget);
  });
}
