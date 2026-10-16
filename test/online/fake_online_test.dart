import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/l10n/app_language.dart';
import 'package:oberta/online/fake_online.dart';
import 'package:oberta/online/join_code.dart';
import 'package:oberta/online/online_services.dart';

Matcher _fails(OnlineFailure failure) =>
    throwsA(isA<OnlineException>().having((error) => error.failure, 'failure', failure));

void main() {
  late FakeOnline online;

  setUp(() {
    online = FakeOnline()
      ..addPlayer('bruno', handle: 'bruno', displayName: 'Bruno')
      ..addPlayer('carla', handle: 'carla', displayName: 'Carla');
  });

  group('l\'account', () {
    test('si entra con Apple o Google; il primo profilo è da finire', () async {
      expect(online.auth.signedIn, isFalse);
      await online.auth.signInWithApple();
      expect(online.auth.userId, 'me');
      expect((await online.profiles.me()).isComplete, isFalse);
      await online.auth.signOut();
      expect(online.auth.signedIn, isFalse);
      await online.auth.signInWithGoogle();
      expect(online.auth.signedIn, isTrue);
    });

    test('chi chiude la finestra di accesso resta fuori', () async {
      online.auth.cancelNext = true;
      await expectLater(online.auth.signInWithApple(), _fails(OnlineFailure.cancelled));
      expect(online.auth.signedIn, isFalse);
    });

    test('il nome unico è unico e ben fatto', () async {
      await online.auth.signInWithApple();
      await expectLater(online.profiles.update(handle: 'bruno', displayName: 'Io'), _fails(OnlineFailure.handleTaken));
      await expectLater(online.profiles.update(handle: 'No!', displayName: 'Io'), _fails(OnlineFailure.invalidHandle));
      final profile = await online.profiles.update(handle: 'anna', displayName: 'Anna', language: AppLanguage.en);
      expect(profile.isComplete, isTrue);
      expect(profile.language, AppLanguage.en);
      expect([for (final p in await online.profiles.search('b')) p.handle], ['bruno']);
      expect(await online.profiles.search('anna'), isEmpty, reason: 'non si trova sé stessi');
    });
  });

  group('le stanze', () {
    setUp(() => online.signInReady(handle: 'anna', displayName: 'Anna'));

    test('senza profilo finito non si apre niente', () async {
      final fresh = FakeOnline();
      await fresh.auth.signInWithApple();
      await expectLater(fresh.rooms.create(AppLanguage.it), _fails(OnlineFailure.profileIncomplete));
    });

    test('chi apre la stanza ha un codice valido e il primo posto', () async {
      final room = await online.rooms.create(AppLanguage.it);
      expect(JoinCode.normalize(room.code), room.code);
      expect(room.hostId, 'me');
      final members = await online.rooms.watchMembers(room.id).first;
      expect([for (final m in members) (m.profile.id, m.seat)], [('me', 1)]);
    });

    test('chi entra col codice si vede arrivare dal vivo', () async {
      final room = await online.rooms.create(AppLanguage.it);
      final seen = <List<String>>[];
      final watch = online.rooms.watchMembers(room.id).listen((m) => seen.add([for (final x in m) x.profile.id]));
      await pumpEventQueue();
      online.joinAs('bruno', room.code.toLowerCase());
      online.leaveAs('bruno', room.id);
      await pumpEventQueue();
      expect(seen, [
        ['me'],
        ['me', 'bruno'],
        ['me'],
      ]);
      await watch.cancel();
    });

    test('codice sbagliato, stanza piena, stanza chiusa', () async {
      await expectLater(online.rooms.join('ZZZZZZ'), _fails(OnlineFailure.roomNotFound));
      final room = await online.rooms.create(AppLanguage.it);
      for (var i = 0; i < 15; i++) {
        online
          ..addPlayer('p$i', handle: 'player$i', displayName: 'P$i')
          ..joinAs('p$i', room.code);
      }
      expect(() => online.joinAs('bruno', room.code), _fails(OnlineFailure.roomFull));
    });

    test('se il padrone di casa esce passa la mano; l\'ultimo chiude', () async {
      final room = await online.rooms.create(AppLanguage.it);
      online.joinAs('bruno', room.code);
      await online.rooms.leave(room.id);
      expect(await online.rooms.fetch(room.id), isNull, reason: 'chi esce non vede più la stanza');
      online.leaveAs('bruno', room.id);
      await expectLater(online.rooms.join(room.code), _fails(OnlineFailure.roomNotFound));
    });
  });

  group('gli amici', () {
    setUp(() => online.signInReady(handle: 'anna', displayName: 'Anna'));

    test('una richiesta, poi accettata dall\'altra parte', () async {
      expect(await online.friends.request('bruno'), FriendStatus.pending);
      final links = await online.friends.list();
      expect(links.single.other.id, 'bruno');
      expect(links.single.incoming, isFalse);
      await expectLater(online.friends.request('me'), _fails(OnlineFailure.playerNotFound));
    });

    test('chi chiede a chi aveva già chiesto diventa amico', () async {
      online.requestFrom('carla');
      expect(await online.friends.request('carla'), FriendStatus.accepted);
    });

    test('accettare, rifiutare, togliere', () async {
      online
        ..requestFrom('bruno')
        ..requestFrom('carla');
      await online.friends.respond('bruno', accept: true);
      await online.friends.respond('carla', accept: false);
      await expectLater(online.friends.respond('carla', accept: true), _fails(OnlineFailure.requestNotFound));
      final links = await online.friends.list();
      expect([for (final l in links) (l.other.id, l.status)], [('bruno', FriendStatus.accepted)]);
      await online.friends.remove('bruno');
      expect(await online.friends.list(), isEmpty);
    });
  });
}
