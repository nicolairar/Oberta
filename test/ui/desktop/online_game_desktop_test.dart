import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/l10n/lobby_language.dart';
import 'package:oberta/online/fake_online.dart';
import 'package:oberta/online/online_services.dart';
import 'package:oberta/ui/screens/online/match_results_screen.dart';
import 'package:oberta/ui/screens/online/online_game_screen.dart';

import '../../support/desktop_shots.dart';
import '../../support/manual_clock.dart';
import '../online_game_screen_test.dart' show flush, settled;

/// Le fasi da fotografare, una volta ciascuna.
const _phases = ['online.night', 'online.dawn', 'online.discussion', 'online.vote', 'online.verdict', 'online.end'];

void main() {
  for (final MapEntry(key: label, value: size) in desktopSizes.entries) {
    testWidgets('la partita online su desktop $label', (tester) async {
      await useDesktop(tester, size);
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
      await tester.pumpWidget(
        desktopApp(OnlineGameScreen(services: online.services, room: room, me: me, clock: clock)),
      );
      await flush(tester);
      expect(tester.takeException(), isNull);
      await saveDesktopShot(tester, 'online_game_card_$label');

      final shot = <String>{};
      for (var i = 0; i < 600 && online.roomOf(room.id)!.status == RoomStatus.playing; i++) {
        for (final key in _phases) {
          if (shot.contains(key) || find.byKey(Key(key)).evaluate().isEmpty) continue;
          shot.add(key);
          final name = key.split('.').last;
          if (key == 'online.discussion') {
            for (final (who, body) in [
              ('anna', 'Stanotte ho sentito dei passi vicino al porto.'),
              ('carla', 'Il 4 dario era troppo tranquillo ieri sera...'),
              ('dario', 'Io? Ero al bar fino a mezzanotte, chiedete al barista.'),
              ('anna', 'Votiamo con calma, niente teste calde.'),
            ]) {
              // Chi è morto o zittito non parla: si va avanti lo stesso.
              await settled(
                tester,
                online.gameAs(who).sendChat(room.id, ChatChannel.day, body).catchError((Object _) => ''),
              );
            }
            await settled(
              tester,
              online.services.game
                  .sendChat(room.id, ChatChannel.day, 'Ci sto. Teniamo d\'occhio il 4.')
                  .catchError((Object _) => ''),
            );
            await flush(tester);
            await saveDesktopShot(tester, 'online_game_${name}_$label');
            // Esc: il menu di pausa.
            await tester.sendKeyEvent(LogicalKeyboardKey.escape);
            await flush(tester);
            expect(find.byKey(const Key('online.pause')), findsOneWidget);
            await saveDesktopShot(tester, 'online_game_pause_$label');
            await tester.sendKeyEvent(LogicalKeyboardKey.escape);
            await flush(tester);
            expect(find.byKey(const Key('online.pause')), findsNothing);
          } else {
            await saveDesktopShot(tester, 'online_game_${name}_$label');
          }
        }
        clock.fireNext();
        await flush(tester);
        expect(tester.takeException(), isNull);
      }
      await flush(tester);
      // Il tavolo finto chiude la stanza appena la partita finisce: resta
      // il cartello del tavolo chiuso.
      if (find.byKey(const Key('online.end')).evaluate().isNotEmpty && !shot.contains('online.end')) {
        await saveDesktopShot(tester, 'online_game_end_$label');
      } else if (find.byKey(const Key('online.closed')).evaluate().isNotEmpty) {
        await saveDesktopShot(tester, 'online_game_closed_$label');
      }
      expect(shot, containsAll(['online.night', 'online.discussion', 'online.vote']));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('i risultati su desktop $label', (tester) async {
      await useDesktop(tester, size);
      await tester.pumpWidget(
        desktopApp(
          const MatchResultsScreen(
            result: MatchResult(
              gameId: 'g1',
              ranked: true,
              won: true,
              role: 'detective',
              xpGained: 140,
              levelBefore: 4,
              levelAfter: 5,
              coinsGained: 60,
              ratingDelta: 18,
              ordinalAfter: 22,
            ),
            xpNow: 40,
            offerReplay: true,
          ),
        ),
      );
      await desktopFrames(tester, 30);
      await saveDesktopShot(tester, 'results_$label');
      await tester.pumpWidget(const SizedBox());
    });
  }
}
