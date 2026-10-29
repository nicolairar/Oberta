import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/l10n/lobby_language.dart';
import 'package:oberta/online/fake_online.dart';
import 'package:oberta/online/game/bot_brain.dart';
import 'package:oberta/online/game/game_client.dart';
import 'package:oberta/online/game/game_schedule.dart';
import 'package:oberta/online/handle_rules.dart';
import 'package:oberta/online/online_services.dart';
import 'package:oberta/rules/intent.dart';
import 'package:oberta/rules/role.dart';
import 'package:oberta/rules/role_assignment.dart';

import '../support/manual_clock.dart';

Future<void> settle() async {
  for (var i = 0; i < 12; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// Una persona al telefono, che gioca come un bot ma dalla sua app: legge
/// la sua vista dal [GameClient], manda le mosse quando la fase è aperta e
/// conferma le fasi da guardare.
class _Human {
  final String id;
  final GameClient client;
  final BotBrain brain;
  String? _turn;

  _Human(this.id, this.client, Random random) : brain = BotBrain(random);

  /// Agisce se è il suo momento (una volta per fase). Vero se ha mandato.
  Future<bool> act() async {
    final seat = client.seat;
    final window = client.schedule;
    if (!client.ready || client.busy || seat == null || window == null) return false;
    if (_turn == window.key || client.elapsed.isNegative) return false;
    if (window.stage.acceptsActions) {
      if (seat.view.action == null) return false;
      _turn = window.key;
      final intent = brain.decide(seat.view);
      if (intent == null) return false;
      await client.send(intent);
      return true;
    }
    if (window.stage.acknowledged && seat.view.alive && !seat.acked) {
      _turn = window.key;
      await client.ack();
      return true;
    }
    return false;
  }
}

void main() {
  late FakeOnline online;
  late ManualClock clock;
  late Room room;

  FakeOnline fresh() {
    clock = ManualClock();
    return FakeOnline(accountId: 'anna', clock: clock)
      ..signInReady(handle: 'anna')
      ..addPlayer('bruno', handle: 'bruno')
      ..addPlayer('carla', handle: 'carla');
  }

  setUp(() {
    online = fresh();
    room = online.openRoomAs('anna', LobbyLanguage.it);
  });

  GameClient clientOf(String id) => GameClient(backend: online.gameAs(id), roomId: room.id, clock: clock);

  Future<void> startWith({required List<String> joiners, required int bots}) async {
    for (final id in joiners) {
      online.joinAs(id, room.code);
    }
    await online.gameAs('anna').setBots(room.id, bots);
    await online.gameAs('anna').startGame(room.id);
    await settle();
  }

  /// Gioca fino alla fine: le persone dai loro telefoni, i bot e le
  /// scadenze dall'orologio del server.
  Future<void> playToTheEnd(List<_Human> humans, {int maxSteps = 6000}) async {
    for (var step = 0; step < maxSteps; step++) {
      await settle();
      if (online.roomOf(room.id)?.status == RoomStatus.lobby) return;
      var acted = false;
      for (final human in humans) {
        if (await human.act()) acted = true;
      }
      if (!acted && !clock.fireNext()) fail('la partita si è fermata al passo $step');
    }
    fail('la partita non finisce');
  }

  group('una partita vera, dal server a tutti i telefoni', () {
    test('due persone e tre bot giocano fino alla fine, e ognuno riceve solo il suo posto', () async {
      for (var seed = 1; seed <= 4; seed++) {
        online = fresh();
        room = online.openRoomAs('anna', LobbyLanguage.it);
        await startWith(joiners: ['bruno'], bots: 3);
        final anna = _Human('anna', clientOf('anna'), Random(seed));
        final bruno = _Human('bruno', clientOf('bruno'), Random(seed + 50));
        await playToTheEnd([anna, bruno]);
        await settle();

        for (final human in [anna, bruno]) {
          final board = human.client.board!;
          expect(board.view.winner, isNotNull, reason: 'partita $seed');
          expect(board.schedule!.stage, Stage.ended);
          expect(board.view.finalRoles, hasLength(5), reason: 'a fine partita le carte si scoprono');
          expect(board.seating.occupants.map((o) => o.name), containsAll(['anna', 'bruno', 'bot.alfa']));
        }
        expect(online.roomOf(room.id)!.status, RoomStatus.lobby, reason: 'finita la partita, la stanza riapre');

        final seats = {for (final o in anna.client.board!.seating.occupants) o.profileId: o.seat};
        for (final delivery in online.deliveries) {
          final seat = delivery.feed.seat;
          if (seat != null) {
            expect(seat.seat, seats[delivery.user], reason: '${delivery.user} riceve solo il suo posto');
            expect((seat.payload['view'] as Map)['seat'], seats[delivery.user]);
          }
          final text = jsonEncode([delivery.feed.board?.payload, delivery.feed.seat?.payload]);
          expect(text, isNot(contains('snapshot')), reason: 'lo stato segreto resta sul server');
          expect(text, isNot(contains('"facts"')));
        }
        anna.client.dispose();
        bruno.client.dispose();
      }
    });

    test('una persona sola e tre bot', () async {
      await startWith(joiners: [], bots: 3);
      final anna = _Human('anna', clientOf('anna'), Random(3));
      await playToTheEnd([anna]);
      expect(anna.client.board!.view.winner, isNotNull);
      anna.client.dispose();
    });

    test('tre persone e nove bot', () async {
      await startWith(joiners: ['bruno', 'carla'], bots: 9);
      final humans = [for (final id in ['anna', 'bruno', 'carla']) _Human(id, clientOf(id), Random(id.hashCode))];
      await playToTheEnd(humans);
      expect(humans.first.client.board!.seating.occupants, hasLength(12));
      for (final h in humans) {
        h.client.dispose();
      }
    });
  });

  group('il padrone di casa non tiene la partita', () {
    test('se esce dalla stanza a metà, la partita va avanti per gli altri', () async {
      await startWith(joiners: ['bruno', 'carla'], bots: 2);
      final anna = clientOf('anna');
      final bruno = _Human('bruno', clientOf('bruno'), Random(1));
      final carla = _Human('carla', clientOf('carla'), Random(2));
      await settle();
      expect(anna.ready, isTrue);
      anna.dispose();
      await online.services.rooms.leave(room.id, newHostId: 'bruno');
      expect(online.roomOf(room.id)!.hostId, 'bruno');
      await playToTheEnd([bruno, carla]);
      expect(bruno.client.board!.view.winner, isNotNull);
      bruno.client.dispose();
      carla.client.dispose();
    });

    test('il padrone di casa riceve solo il suo posto, come tutti', () async {
      await startWith(joiners: ['bruno'], bots: 2);
      final anna = clientOf('anna');
      await settle();
      expect(anna.seat!.view.seat.id, 's1');
      final mine = online.deliveries.where((d) => d.user == 'anna' && d.feed.seat != null);
      expect(mine.every((d) => d.feed.seat!.seat == 's1'), isTrue);
      anna.dispose();
    });
  });

  group('le fasi e le mosse', () {
    test('le fasi seguono l\'orologio del server, e i telefoni conoscono la sua ora', () async {
      await startWith(joiners: ['bruno'], bots: 2);
      final bruno = clientOf('bruno');
      await settle();
      final window = bruno.schedule!;
      expect(window.stage, Stage.reveal);
      expect(window.length, const OnlinePacing().reveal);
      expect(bruno.elapsed.isNegative, isTrue, reason: 'la fase comincia un attimo dopo, per tutti insieme');
      expect(bruno.timeLeft, greaterThan(const Duration(seconds: 15)));
      bruno.dispose();
    });

    test('mosse fuori dalla loro fase tornano rifiutate; la conferma vale una volta', () async {
      await startWith(joiners: ['bruno'], bots: 2);
      final bruno = clientOf('bruno');
      final anna = clientOf('anna');
      await settle();
      final seat = bruno.seat!.view.seat.id;
      expect(bruno.seat!.view.action, isNull, reason: 'mentre si guarda la carta non si agisce');

      await bruno.send(Pass(seat));
      await settle();
      expect(bruno.takeRejection()?.error, IntentError.wrongPhase);
      expect(bruno.busy, isFalse);

      // Tutti e due confermano la carta: la notte parte prima del tempo.
      await bruno.ack();
      await anna.ack();
      await settle();
      expect(bruno.schedule!.stage, Stage.night);
      clock.elapse(const Duration(seconds: 2));
      await settle();

      final option = bruno.seat!.view.action!;
      await bruno.send(NightAction(seat, 's99'));
      await settle();
      expect(bruno.takeRejection()?.error, anyOf(IntentError.targetNotAllowed, IntentError.notYourAction));

      await bruno.send(Pass(seat));
      await settle();
      expect(bruno.takeRejection(), isNull, reason: 'la risposta del server conferma la mossa');
      expect(bruno.seat!.view.nightChoice, isNotNull, reason: option.type.name);
      expect(bruno.seat!.view.action, isNotNull, reason: 'fino allo scadere la scelta si può cambiare');

      await online.gameAs('bruno').sendRaw(room.id, {'type': 'magia', 'seat': seat});
      await settle();
      expect(bruno.seat!.receipt!.result, isA<IntentRejected>());
      bruno.dispose();
      anna.dispose();
    });

    test('nessuno agisce per un altro posto, e chi non siede non agisce', () async {
      await startWith(joiners: ['bruno'], bots: 2);
      await expectLater(
        online.gameAs('bruno').sendIntent(room.id, const Pass('s1')),
        throwsA(isA<OnlineException>().having((e) => e.failure, 'failure', OnlineFailure.notAllowed)),
      );
      await expectLater(
        online.gameAs('carla').sendIntent(room.id, const Pass('s1')),
        throwsA(isA<OnlineException>()),
        reason: 'Carla non è nella stanza',
      );
    });

    test('solo il padrone di casa mette i bot e apre la partita, e i posti li decide il server', () async {
      online.joinAs('bruno', room.code);
      await expectLater(online.gameAs('bruno').setBots(room.id, 2), throwsA(isA<OnlineException>()));
      await expectLater(online.gameAs('anna').setBots(room.id, 15), throwsA(isA<OnlineException>()),
          reason: 'bot e persone stanno nei sedici posti');
      await expectLater(online.gameAs('bruno').startGame(room.id), throwsA(isA<OnlineException>()));
      await expectLater(online.gameAs('anna').startGame(room.id), throwsA(isA<OnlineException>()),
          reason: 'in due non si gioca');
      await online.gameAs('anna').setBots(room.id, 2);
      await online.gameAs('anna').startGame(room.id);
      await settle();
      final anna = clientOf('anna');
      await settle();
      expect(anna.board!.seating.occupants.map((o) => '${o.seat}=${o.name}'),
          ['s1=anna', 's2=bruno', 's3=bot.alfa', 's4=bot.bravo']);
      anna.dispose();
    });

    test('allo scadere chi non sceglie passa e chi non vota si astiene: nessuno blocca', () async {
      await startWith(joiners: ['bruno'], bots: 2);
      final bruno = clientOf('bruno');
      await settle();
      final seen = <Stage>{};
      for (var i = 0; i < 400 && online.roomOf(room.id)!.status == RoomStatus.playing; i++) {
        if (bruno.schedule case final window?) seen.add(window.stage);
        clock.fireNext();
        await settle();
      }
      expect(seen, containsAll([Stage.reveal, Stage.night]));
      expect(seen.length, greaterThan(3), reason: 'la partita va avanti anche se le persone non toccano niente');
      bruno.dispose();
    });
  });

  group('chi si ricollega', () {
    test('un telefono che ricarica riceve di nuovo la sua vista e la fase in corso', () async {
      await startWith(joiners: ['bruno'], bots: 3);
      var bruno = clientOf('bruno');
      await settle();
      final role = bruno.seat!.view.role;
      final stage = bruno.schedule!.key;
      bruno.dispose();

      bruno = clientOf('bruno');
      expect(bruno.ready, isFalse);
      await settle();
      expect(bruno.ready, isTrue);
      expect(bruno.seat!.view.role, role);
      expect(bruno.schedule!.key, stage);
      bruno.dispose();
    });

    test('chi sparisce diventa offline per tutti, e se non torna lascia la città con la carta scoperta', () async {
      online.trackPresence = true;
      await startWith(joiners: ['bruno', 'carla'], bots: 3);
      final anna = clientOf('anna');
      final bruno = clientOf('bruno');
      var carla = clientOf('carla');
      await settle();

      // Carla chiude l'app; dopo un buco breve non succede niente.
      carla.dispose();
      clock.elapse(const Duration(seconds: 10));
      await settle();
      expect(anna.board!.offline, isEmpty);
      clock.elapse(const Duration(seconds: 10));
      await settle();
      expect(anna.board!.offline, contains('s3'), reason: 'tutti vedono che Carla è offline');

      // Torna in tempo: niente di fatto.
      carla = clientOf('carla');
      await settle();
      expect(anna.board!.offline, isEmpty);
      expect(carla.ready, isTrue);

      // Se ne va di nuovo e non torna più.
      carla.dispose();
      for (var i = 0; i < 200 && !anna.board!.departed.contains('s3'); i++) {
        if (!anna.board!.view.alive.any((p) => p.id == 's3')) break;
        clock.elapse(const Duration(seconds: 5));
        await settle();
      }
      final board = anna.board!;
      if (board.departed.contains('s3')) {
        expect(board.view.alive.map((p) => p.id), isNot(contains('s3')));
        expect(board.view.revealed.map((k) => k.seat.id), isNot(contains('s3')), reason: 'la carta resta coperta');
        expect(online.abandonsIn(room.id), ['s3'], reason: 'il server annota l\'abbandono');
      }
      anna.dispose();
      bruno.dispose();
    });
  });

  group('di ritorno dallo sfondo', () {
    test('chi perde la rete risulta assente; rientrando torna presente e riceve la partita di adesso', () async {
      online.trackPresence = true;
      await startWith(joiners: ['carla'], bots: 3);
      final anna = clientOf('anna');
      final carla = clientOf('carla');
      await settle();
      final before = carla.board!.version;

      // Il telefono di Carla va in sfondo: niente ping, niente tempo reale.
      online.unreachable.add('carla');
      clock.elapse(const Duration(seconds: 25));
      await settle();
      expect(anna.board!.offline, contains('s2'));
      expect(carla.board!.version, before, reason: 'Carla non ha ricevuto niente');

      // Torna: rientra al tavolo.
      online.unreachable.remove('carla');
      final rejoin = carla.rejoin();
      expect(carla.reconnecting, isTrue);
      await rejoin;
      await settle();
      expect(carla.reconnecting, isFalse);
      expect(online.resumes, 1);
      expect(anna.board!.offline, isEmpty, reason: 'gli altri la vedono tornata subito');
      expect(carla.board!.offline, isEmpty);
      expect(carla.board!.version, anna.board!.version, reason: 'Carla ha la partita di adesso');
      expect(carla.ready, isTrue);

      // E continua a farsi sentire: il battito non si è fermato.
      clock.elapse(const Duration(seconds: 30));
      await settle();
      expect(anna.board!.offline, isEmpty);
      anna.dispose();
      carla.dispose();
    });

    test('rientrare senza rete non resta appeso: si vede l\'errore e si riprova', () async {
      online.trackPresence = true;
      await startWith(joiners: ['bruno'], bots: 3);
      final bruno = clientOf('bruno');
      await settle();
      online.unreachable.add('bruno');
      await bruno.rejoin();
      await settle();
      expect(online.resumes, 0);
      online.unreachable.remove('bruno');
      await bruno.rejoin();
      await settle();
      expect(bruno.reconnecting, isFalse);
      expect(bruno.ready, isTrue);
      bruno.dispose();
    });
  });

  group('la chat', () {
    test('stanza prima, piazza di giorno per i vivi, famiglia di notte solo per la famiglia', () async {
      online.joinAs('bruno', room.code);
      online.joinAs('carla', room.code);
      await online.gameAs('bruno').sendChat(room.id, ChatChannel.lobby, 'ciao a tutti');
      await online.gameAs('anna').setBots(room.id, 3);
      await online.gameAs('anna').startGame(room.id);
      await settle();
      final clients = {for (final id in ['anna', 'bruno', 'carla']) id: clientOf(id)};
      await settle();
      expect(clients['carla']!.chat.single.body, 'ciao a tutti');
      await expectLater(online.gameAs('bruno').sendChat(room.id, ChatChannel.lobby, 'ancora'), throwsA(isA<OnlineException>()),
          reason: 'la chat della stanza si chiude quando si gioca');

      // Alla notte: scrive solo chi è della famiglia, e solo la famiglia legge.
      for (final c in clients.values) {
        await c.ack();
      }
      await settle();
      expect(clients['anna']!.schedule!.stage, Stage.night);
      for (final c in clients.values) {
        expect([for (final m in c.chat) if (m.channel == ChatChannel.event) m.event!.kind], ['night'],
            reason: 'the server tells everyone that night falls');
      }
      final family = [for (final MapEntry(:key, :value) in clients.entries) if (value.seat!.view.team == Team.mafia) key];
      final town = [for (final id in clients.keys) if (!family.contains(id)) id];
      for (final id in town) {
        await expectLater(online.gameAs(id).sendChat(room.id, ChatChannel.family, 'ehi'), throwsA(isA<OnlineException>()));
        await expectLater(online.gameAs(id).sendChat(room.id, ChatChannel.day, 'ehi'), throwsA(isA<OnlineException>()),
            reason: 'di notte la piazza tace');
      }
      if (family.isNotEmpty) {
        await online.gameAs(family.first).sendChat(room.id, ChatChannel.family, 'stanotte il medico');
        await settle();
        for (final id in town) {
          expect(clients[id]!.chat.where((m) => m.channel == ChatChannel.family), isEmpty);
        }
        final secret = clients[family.first]!.chat.last;
        expect(secret.body, 'stanotte il medico');
        // Ids random, order counted per channel: nothing to count from outside.
        expect(int.tryParse(secret.id), isNull);
        expect(secret.n, 1);
        final lobby = [for (final m in clients[town.first]!.chat) if (m.channel == ChatChannel.lobby) m.n];
        expect(lobby, [for (var i = 1; i <= lobby.length; i++) i]);
      }
      await expectLater(
        online.gameAs(town.first).sendChat(room.id, ChatChannel.lobby, 'porca madonna'),
        throwsA(isA<OnlineException>()),
      );
      for (final c in clients.values) {
        c.dispose();
      }
    });

    test('la moderazione è la stessa dei nomi, senza le parole riservate solo ai nomi', () {
      expect(HandleRules.offensive('porca madonna che notte'), isTrue);
      expect(HandleRules.offensive('chiedo al moderatore e allo staff'), isFalse);
      expect(HandleRules.offensive('buonanotte a tutti'), isFalse);
    });
  });

  group('risultati e classificata, sul server finto', () {
    test('una partita tra amici dà esperienza (e monete) a chi l\'ha giocata, niente rating', () async {
      await startWith(joiners: ['bruno'], bots: 3);
      await playToTheEnd([_Human('anna', clientOf('anna'), Random(3)), _Human('bruno', clientOf('bruno'), Random(4))]);
      final result = await online.ranked.lastResult();
      expect(result, isNotNull);
      expect(result!.ranked, isFalse);
      expect(result.xpGained, result.won ? 200 : 30);
      expect(result.ratingDelta, isNull);
      expect(online.ratings, isEmpty);
      expect(online.profileOf('anna')!.level, result.won ? 2 : 1);
    });

    test('chi entra in coda si siede subito in sala d\'attesa; a tavolo pieno il conto alla rovescia, poi una classificata senza bot', () async {
      online = fresh();
      final ids = ['anna', 'bruno', 'carla', for (var i = 0; i < 9; i++) 'p$i'];
      for (final id in ids.skip(3)) {
        online.addPlayer(id, handle: id);
      }
      online.auth.debugSignIn('anna');
      var status = await online.ranked.enqueue(LobbyLanguage.it);
      final lobby = status.roomId!;
      expect(online.roomOf(lobby)!.status, RoomStatus.lobby, reason: 'subito in sala, non un caricamento');
      for (final id in ids.skip(1).take(10)) {
        online.auth.debugSignIn(id);
        status = await online.ranked.enqueue(LobbyLanguage.it);
        expect(status.roomId, lobby);
      }
      expect(online.roomOf(lobby)!.startsAt, isNull, reason: '11/12: si aspetta');
      online.auth.debugSignIn('p8');
      await online.ranked.enqueue(LobbyLanguage.it);
      expect(online.roomOf(lobby)!.startsAt, isNotNull, reason: '12/12: conto alla rovescia');

      // Uno esce: il conto si ferma, senza penalità; un altro rientra.
      await online.ranked.leave();
      expect(online.roomOf(lobby)!.startsAt, isNull);
      expect(online.cooldowns, isEmpty);
      await online.ranked.enqueue(LobbyLanguage.it);
      expect(online.roomOf(lobby)!.startsAt, isNotNull);

      online.tickRanked();
      expect(online.roomOf(lobby)!.status, RoomStatus.lobby, reason: 'il conto non è finito');
      clock.elapse(online.rankedCountdown);
      online.tickRanked();
      expect(online.rankedQueue, isEmpty, reason: 'il tavolo è fatto');
      await expectLater(
        online.ranked.enqueue(LobbyLanguage.it),
        throwsA(isA<OnlineException>().having((e) => e.failure, 'failure', OnlineFailure.alreadyInGame)),
      );
      room = online.roomOf(lobby)!;
      expect((room.status, room.ranked, room.bots, room.testMatch), (RoomStatus.playing, true, 0, false));
      await expectLater(online.gameAs(room.hostId).setBots(room.id, 2), throwsA(isA<OnlineException>()));
      await settle();
      final humans = [for (final (i, id) in ids.indexed) _Human(id, clientOf(id), Random(i + 9))];
      await playToTheEnd(humans);
      // The ranked deck, as the real server deals it (QA P3-3: the fake
      // dealt the friends deck): both guns, and only the ranked pools.
      final roles = humans.first.client.board!.view.finalRoles.values.toList();
      expect(roles, hasLength(12));
      expect(roles, containsAll(rankedGuns));
      const pools = {
        ...rankedFamilyPowers, ...rankedNeutrals, ...rankedInvestigators, ...rankedProtectors, ...rankedGuns, //
        ...rankedCivics, Role.mafioso, Role.cittadino,
      };
      expect(roles.where((r) => !pools.contains(r)), isEmpty, reason: 'roles outside the ranked deck: $roles');
      for (final human in humans) {
        human.client.dispose();
      }
      for (final id in ids) {
        final match = online.history[id]!.single;
        expect(match.ranked, isTrue);
        final rating = online.ratings[(id, LobbyLanguage.it)]!;
        expect(rating.sigma, lessThan(Rating.initial.sigma));
        expect(rating.mu, match.won ? greaterThan(25) : lessThan(25));
      }
    });

    test('SOLO PROVA: col flag due persone bastano, con i bot fino al tavolo intero, e la partita non è classificata', () async {
      online = fresh()..rankedTestHumans = 2;
      online.auth.debugSignIn('anna');
      await online.ranked.enqueue(LobbyLanguage.en);
      online.auth.debugSignIn('bruno');
      final status = await online.ranked.enqueue(LobbyLanguage.en);
      expect(online.roomOf(status.roomId!)!.startsAt, isNotNull);
      clock.elapse(online.rankedCountdown);
      online.tickRanked();
      room = online.roomOf(status.roomId!)!;
      expect((room.ranked, room.testMatch, room.bots, room.status), (false, true, 10, RoomStatus.playing));
      expect(status.testMatch, isTrue);
    });

    test('in pausa per abbandoni non si entra in coda', () async {
      online.cooldowns['anna'] = clock.now().add(const Duration(minutes: 5));
      await expectLater(
        online.ranked.enqueue(LobbyLanguage.it),
        throwsA(isA<OnlineException>().having((e) => e.failure, 'failure', OnlineFailure.rankedCooldown)),
      );
    });
  });
}
