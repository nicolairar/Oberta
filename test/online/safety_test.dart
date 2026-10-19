import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/l10n/app_language.dart';
import 'package:oberta/online/fake_online.dart';
import 'package:oberta/online/online_services.dart';

Matcher _fails(OnlineFailure failure) =>
    throwsA(isA<OnlineException>().having((error) => error.failure, 'failure', failure));

void main() {
  late FakeOnline online;

  setUp(() {
    BlockedPlayers.clear();
    online = FakeOnline(accountId: 'anna')
      ..signInReady(handle: 'anna')
      ..addPlayer('bruno', handle: 'bruno')
      ..addPlayer('carla', handle: 'carla');
    online.slow = false;
  });

  group('segnalare', () {
    test('si segnala un giocatore con un motivo e una nota', () async {
      await online.safety.report('bruno', ReportReason.cheating, note: '  esce sempre  ');
      expect(online.reports.single.target, 'bruno');
      expect(online.reports.single.reporter, 'anna');
      expect(online.reports.single.reason, ReportReason.cheating);
      expect(online.reports.single.note, 'esce sempre');
    });

    test('il messaggio segnalato resta in copia sul server', () async {
      final room = online.openRoomAs('anna', AppLanguage.it);
      online.joinAs('bruno', room.code);
      final id = await online.gameAs('bruno').sendChat(room.id, ChatChannel.lobby, 'ciao a tutti');
      await online.safety.report('bruno', ReportReason.language, messageId: id);
      expect(online.reports.single.messageText, 'ciao a tutti');
      expect(online.reports.single.messageId, id);
    });

    test('non si segnala sé stessi, e la seconda volta passa in silenzio', () async {
      await expectLater(online.safety.report('anna', ReportReason.spam), _fails(OnlineFailure.playerNotFound));
      await online.safety.report('bruno', ReportReason.spam);
      await online.safety.report('bruno', ReportReason.spam);
      expect(online.reports, hasLength(1));
    });

    test('troppe segnalazioni di fila si fermano', () async {
      for (var i = 0; i < 10; i++) {
        online.addPlayer('p$i', handle: 'player$i');
        await online.safety.report('p$i', ReportReason.spam);
      }
      await expectLater(online.safety.report('carla', ReportReason.spam), _fails(OnlineFailure.tooManyReports));
    });
  });

  group('bloccare', () {
    test('il bloccato sparisce dagli amici e non può chiedere di nuovo', () async {
      await online.friends.request('bruno');
      await online.safety.block('bruno');
      expect(await online.friends.list(), isEmpty);
      expect(BlockedPlayers.ids.value, {'bruno'});
      expect([for (final p in await online.safety.blocked()) p.handle], ['bruno']);
      await expectLater(online.friends.request('bruno'), _fails(OnlineFailure.notAllowed));

      final other = FakeOnline(accountId: 'bruno')
        ..signInReady(handle: 'bruno')
        ..addPlayer('anna', handle: 'anna')
        ..blocks.add(('anna', 'bruno'));
      await expectLater(other.friends.request('anna'), _fails(OnlineFailure.notAllowed),
          reason: 'nemmeno dall\'altra parte');
    });

    test('i suoi messaggi non arrivano a chi l\'ha bloccato', () async {
      final room = online.openRoomAs('anna', AppLanguage.it);
      online.joinAs('bruno', room.code);
      online.joinAs('carla', room.code);
      await online.gameAs('bruno').sendChat(room.id, ChatChannel.lobby, 'uffa');
      await online.gameAs('carla').sendChat(room.id, ChatChannel.lobby, 'ciao');
      await online.safety.block('bruno');
      final seen = await online.game.watchChat(room.id).first;
      expect([for (final m in seen) m.body], ['ciao']);
      final carla = await online.gameAs('carla').watchChat(room.id).first;
      expect(carla, hasLength(2), reason: 'gli altri lo leggono ancora');
    });

    test('non entra nelle stanze di chi l\'ha bloccato; sbloccato sì', () async {
      final room = online.openRoomAs('anna', AppLanguage.it);
      await online.safety.block('bruno');
      expect(() => online.joinAs('bruno', room.code), _fails(OnlineFailure.notAllowed));
      await online.safety.unblock('bruno');
      expect(BlockedPlayers.ids.value, isEmpty);
      online.joinAs('bruno', room.code);
    });
  });

  test('BlockedPlayers.visible toglie solo i bloccati', () {
    BlockedPlayers.set(['b']);
    expect(BlockedPlayers.visible(['a', 'b', 'c'], (x) => x), ['a', 'c']);
  });
}
