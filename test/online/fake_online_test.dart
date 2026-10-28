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
      ..addPlayer('bruno', handle: 'bruno')
      ..addPlayer('carla', handle: 'carla');
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
      await expectLater(online.profiles.update(handle: 'bruno'), _fails(OnlineFailure.handleTaken));
      await expectLater(online.profiles.update(handle: 'No!'), _fails(OnlineFailure.invalidHandle));
      final profile = await online.profiles.update(handle: 'anna', language: AppLanguage.en);
      expect(profile.isComplete, isTrue);
      expect(profile.language, AppLanguage.en);
      expect([for (final p in await online.profiles.search('b')) p.handle], ['bruno']);
      expect(await online.profiles.search('anna'), isEmpty, reason: 'non si trova sé stessi');
    });

    test('il nome unico segue le regole: forma, parole vietate, nomi dei bot', () async {
      await online.auth.signInWithApple();
      for (final bad in ['ab', 'an na', 'anna!', 'ànna', '.anna', 'anna.', 'an..na', 'a_._.b', 'abcdefghijklm', '']) {
        await expectLater(online.profiles.update(handle: bad), _fails(OnlineFailure.invalidHandle), reason: bad);
      }
      for (final bad in ['str0nz0', 'f.u.c.k', 'admin', 'bot.alfa']) {
        await expectLater(online.profiles.update(handle: bad), _fails(OnlineFailure.handleNotAllowed), reason: bad);
      }
      final profile = await online.profiles.update(handle: 'Anna.R_92');
      expect(profile.handle, 'anna.r_92', reason: 'si salva in minuscolo');
      expect(profile.name, 'anna.r_92', reason: 'il nome unico è il nome che si vede');
    });

    test('maiuscole o minuscole, un nome preso resta preso; e si sa prima di salvare', () async {
      await online.auth.signInWithApple();
      expect(await online.profiles.handleAvailable('bruno'), isFalse);
      expect(await online.profiles.handleAvailable('BRUNO'), isFalse);
      expect(await online.profiles.handleAvailable('anna'), isTrue);
      await expectLater(online.profiles.update(handle: 'Bruno'), _fails(OnlineFailure.handleTaken));
      await online.profiles.update(handle: 'anna');
      expect(await online.profiles.handleAvailable('anna'), isTrue, reason: 'il proprio nome non è «preso»');
    });

    test('un vecchio nome che non vale più si rifà al prossimo accesso', () async {
      online.signInReady(handle: 'anna');
      online.forgetHandle('me');
      final profile = await online.profiles.me();
      expect(profile.isComplete, isFalse);
      expect(profile.name, isEmpty);
    });

    test('livello, esperienza e monete li scrive il server; il profilo li legge', () async {
      online.signInReady(handle: 'anna');
      var profile = await online.profiles.me();
      expect((profile.level, profile.xp, profile.coins), (1, 0, 0));
      online.award('me', level: 3, xp: 150, coins: 40);
      profile = await online.profiles.me();
      expect((profile.level, profile.xp, profile.coins), (3, 150, 40));
      expect(profile.levelProgress, closeTo(150 / 225, 1e-9));
      profile = await online.profiles.update(handle: 'anna');
      expect(profile.coins, 40, reason: 'salvare il nome non tocca le monete');
    });

    test('un accesso rifiutato dal server porta il motivo tecnico', () async {
      online.auth.failNext = const OnlineException(OnlineFailure.appleDisabled, null, 'provider is not enabled');
      await expectLater(
        online.auth.signInWithApple(),
        throwsA(isA<OnlineException>()
            .having((e) => e.failure, 'failure', OnlineFailure.appleDisabled)
            .having((e) => e.reason, 'reason', contains('provider is not enabled'))),
      );
      expect(online.auth.signedIn, isFalse);
      await online.auth.signInWithApple();
      expect(online.auth.signedIn, isTrue, reason: 'il guasto vale una volta sola');
    });
  });

  group('l\'account di prova', () {
    test('la prima volta crea l\'account, poi ci rientra con la stessa password', () async {
      await online.auth.signInWithTestAccount(email: 'prova@oberta.test', password: 'segreta');
      final first = online.auth.userId;
      expect(first, isNotNull);
      expect(first, isNot('me'), reason: 'è un altro account, non quello di Apple');
      await online.auth.signOut();
      await online.auth.signInWithTestAccount(email: ' Prova@Oberta.test ', password: 'segreta');
      expect(online.auth.userId, first);
    });

    test('password sbagliata, password debole, email storta', () async {
      await online.auth.signInWithTestAccount(email: 'prova@oberta.test', password: 'segreta');
      await online.auth.signOut();
      await expectLater(
        online.auth.signInWithTestAccount(email: 'prova@oberta.test', password: 'sbagliata'),
        _fails(OnlineFailure.wrongPassword),
      );
      await expectLater(
        online.auth.signInWithTestAccount(email: 'altra@oberta.test', password: '123'),
        _fails(OnlineFailure.weakPassword),
      );
      await expectLater(
        online.auth.signInWithTestAccount(email: 'non-una-email', password: 'segreta'),
        _fails(OnlineFailure.invalidEmail),
      );
      expect(online.auth.signedIn, isFalse);
    });

    test('col provider Email spento sul server non si entra', () async {
      online.emailEnabled = false;
      await expectLater(
        online.auth.signInWithTestAccount(email: 'prova@oberta.test', password: 'segreta'),
        _fails(OnlineFailure.emailDisabled),
      );
    });
  });

  group('le stanze', () {
    setUp(() => online.signInReady(handle: 'anna'));

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
      for (var i = 0; i < 11; i++) {
        online
          ..addPlayer('p$i', handle: 'player${String.fromCharCode(97 + i)}')
          ..joinAs('p$i', room.code);
      }
      expect(() => online.joinAs('bruno', room.code), _fails(OnlineFailure.roomFull));
    });

    test('il padrone di casa sceglie a chi lasciare la stanza; l\'ultimo la cancella', () async {
      final room = await online.rooms.create(AppLanguage.it);
      online.joinAs('bruno', room.code);
      await expectLater(online.rooms.leave(room.id), _fails(OnlineFailure.hostMustChoose));
      await online.rooms.leave(room.id, newHostId: 'bruno');
      expect(await online.rooms.fetch(room.id), isNull, reason: 'chi esce non vede più la stanza');
      online.leaveAs('bruno', room.id);
      await expectLater(online.rooms.join(room.code), _fails(OnlineFailure.roomNotFound));
    });
  });

  group('gli amici', () {
    setUp(() => online.signInReady(handle: 'anna'));

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
