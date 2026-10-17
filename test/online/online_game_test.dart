import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/l10n/app_language.dart';
import 'package:oberta/online/fake_online.dart';
import 'package:oberta/online/game/bot_brain.dart';
import 'package:oberta/online/game/game_authority.dart';
import 'package:oberta/online/game/game_client.dart';
import 'package:oberta/online/game/game_protocol.dart';
import 'package:oberta/online/online_services.dart';
import 'package:oberta/rules/game_engine.dart';
import 'package:oberta/rules/game_snapshot.dart';
import 'package:oberta/rules/intent.dart';
import 'package:oberta/rules/player.dart';
import 'package:oberta/table/seating.dart';

import '../rules/player_view_test.dart' show leaksIn;
import '../support/manual_clock.dart';

/// Il backend del padrone di casa, con una lente: ogni pubblicazione si
/// controlla contro lo stato del motore da cui è stata fatta (che viaggia
/// nella pubblicazione stessa, nello stato salvato).
class _Inspected implements GameBackend {
  final GameBackend inner;
  final List<String> leaks = [];
  final List<GamePublication> publications = [];

  _Inspected(this.inner);

  @override
  Future<void> publish(String roomId, GamePublication publication) {
    publications.add(publication);
    final state = publication.hostState;
    final seating = Seating.fromJson(state['seating'] as Map<String, Object?>);
    final engine = GameEngine.fromSnapshot(
      GameSnapshot.fromJson(state['snapshot'] as Map<String, Object?>, seating.playerAt),
    );
    final board = publication.board['board'] as Map<String, Object?>;
    leaks.addAll(leaksIn(engine, null, board).map((leak) => 'tavolo v${publication.version}: $leak'));
    if (engine.phase != GamePhase.ended && (board['finalRoles'] as List).isNotEmpty) leaks.add('carte scoperte');
    for (final attack in ((board['lastDawn'] as Map?)?['attacks'] as List?) ?? const []) {
      if (attack['outcome'] != 'killed' && attack['target'] != anonymousSeat) leaks.add('chi si è salvato si vede');
    }
    for (final MapEntry(key: seat, value: payload) in publication.seatViews.entries) {
      final view = payload['view'] as Map<String, Object?>;
      if (view['seat'] != seat) leaks.add('la vista di ${view['seat']} sotto $seat');
      if (seating.profileOf(seat) == null) leaks.add('un bot ha una vista sul server: $seat');
      leaks.addAll(leaksIn(engine, seating.playerAt(seat), view).map((leak) => '$seat v${publication.version}: $leak'));
    }
    return inner.publish(roomId, publication);
  }

  @override
  Future<void> setBots(String roomId, int count) => inner.setBots(roomId, count);
  @override
  Future<void> startGame(String roomId, List<SeatPlan> seats) => inner.startGame(roomId, seats);
  @override
  Stream<List<IntentEnvelope>> watchIntents(String roomId) => inner.watchIntents(roomId);
  @override
  Future<Map<String, Object?>?> loadHostState(String roomId) => inner.loadHostState(roomId);
  @override
  Stream<GameFeed> watchGame(String roomId) => inner.watchGame(roomId);
  @override
  Future<int> sendIntent(String roomId, PlayerIntent intent) => inner.sendIntent(roomId, intent);
}

Future<void> settle() async {
  for (var i = 0; i < 12; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// Una persona al telefono, che gioca come un bot ma dalla sua app: legge
/// la sua vista dal [GameClient] e manda le intenzioni al server.
class _Human {
  final String id;
  final GameClient client;
  final BotBrain brain;
  String? _turn;

  _Human(this.id, this.client, Random random) : brain = BotBrain(random);

  /// Agisce se è il suo momento (una volta per fase). Vero se ha mandato.
  Future<bool> act() async {
    final seat = client.seat;
    final board = client.board;
    if (!client.ready || client.busy || seat == null || board == null) return false;
    final turn = '${board.view.phase.name}-${board.view.round}';
    if (seat.view.action == null || _turn == turn) return false;
    _turn = turn;
    final intent = brain.decide(seat.view);
    if (intent == null) return false;
    await client.send(intent);
    return true;
  }
}

void main() {
  late FakeOnline online;
  late ManualClock clock;
  late Room room;

  setUp(() {
    online = FakeOnline(accountId: 'anna')
      ..signInReady(handle: 'anna')
      ..addPlayer('bruno', handle: 'bruno')
      ..addPlayer('carla', handle: 'carla');
    clock = ManualClock();
    room = online.openRoomAs('anna', AppLanguage.it);
  });

  Future<List<RoomMember>> members() => online.services.rooms.watchMembers(room.id).first;

  Future<(GameAuthority, _Inspected)> startWith({required List<String> joiners, required int bots, int seed = 1}) async {
    for (final id in joiners) {
      online.joinAs(id, room.code);
    }
    final host = _Inspected(online.gameAs('anna'));
    await host.setBots(room.id, bots);
    final authority = await GameAuthority.start(
      backend: host,
      roomId: room.id,
      members: await members(),
      bots: bots,
      language: AppLanguage.it,
      clock: clock,
      random: Random(seed),
    );
    return (authority, host);
  }

  /// Gioca fino alla fine: le persone dai loro telefoni, i bot e le
  /// scadenze dall'orologio dell'autorità.
  Future<void> playToTheEnd(List<_Human> humans, {int maxSteps = 4000}) async {
    for (var step = 0; step < maxSteps; step++) {
      await settle();
      if (humans.every((h) => h.client.board?.view.phase == GamePhase.ended)) return;
      var acted = false;
      for (final human in humans) {
        if (await human.act()) acted = true;
      }
      if (!acted && !clock.fireNext()) {
        await settle();
        if (humans.every((h) => h.client.board?.view.phase == GamePhase.ended)) return;
        fail('la partita si è fermata al passo $step');
      }
    }
    fail('la partita non finisce');
  }

  group('una partita vera, dal padrone di casa a tutti i telefoni', () {
    test('due persone e tre bot giocano fino alla fine, e nessuno vede quello che non deve', () async {
      for (var seed = 1; seed <= 6; seed++) {
        {
          online = FakeOnline(accountId: 'anna')
            ..signInReady(handle: 'anna')
            ..addPlayer('bruno', handle: 'bruno');
          clock = ManualClock();
          room = online.openRoomAs('anna', AppLanguage.it);
        }
        final (authority, host) = await startWith(joiners: ['bruno'], bots: 3, seed: seed);
        final anna = _Human('anna', GameClient(backend: online.gameAs('anna'), roomId: room.id), Random(seed));
        final bruno = _Human('bruno', GameClient(backend: online.gameAs('bruno'), roomId: room.id), Random(seed + 50));
        await playToTheEnd([anna, bruno]);
        await settle();

        expect(host.leaks, isEmpty, reason: 'partita $seed');
        expect(authority.engine.winner, isNotNull);
        for (final human in [anna, bruno]) {
          final board = human.client.board!;
          expect(board.view.winner, authority.engine.winner);
          expect(board.view.finalRoles, hasLength(5), reason: 'a fine partita le carte si scoprono');
          expect(board.seating.occupants.map((o) => o.name), containsAll(['anna', 'bruno', 'bot.alfa']));
        }
        expect(online.roomOf(room.id)!.status, RoomStatus.lobby, reason: 'finita la partita, la stanza riapre');

        // Ogni telefono ha ricevuto solo il tavolo e la propria vista.
        final seats = {for (final o in authority.seating.occupants) o.profileId: o.seat};
        for (final delivery in online.deliveries) {
          final seat = delivery.feed.seat;
          if (seat != null) {
            expect(seat.seat, seats[delivery.user], reason: '${delivery.user} riceve solo il suo posto');
            expect((seat.payload['view'] as Map)['seat'], seats[delivery.user]);
          }
          final text = jsonEncode([delivery.feed.board?.payload, delivery.feed.seat?.payload]);
          expect(text, isNot(contains('snapshot')), reason: 'lo stato dell\'autorità resta all\'autorità');
          expect(text, isNot(contains('"facts"')));
        }
        authority.dispose();
        anna.client.dispose();
        bruno.client.dispose();
      }
    });

    test('una persona sola e tre bot: si gioca fino alla fine', () async {
      final (authority, host) = await startWith(joiners: [], bots: 3, seed: 9);
      final anna = _Human('anna', GameClient(backend: online.gameAs('anna'), roomId: room.id), Random(3));
      await playToTheEnd([anna]);
      expect(host.leaks, isEmpty);
      expect(anna.client.board!.view.winner, isNotNull);
      expect(host.publications.every((p) => p.seatViews.keys.single == 's1'), isTrue,
          reason: 'i bot non hanno righe sul server');
      authority.dispose();
      anna.client.dispose();
    });

    test('tre persone e dieci bot, sedici al massimo', () async {
      final (authority, host) = await startWith(joiners: ['bruno', 'carla'], bots: 10, seed: 4);
      final humans = [
        for (final id in ['anna', 'bruno', 'carla'])
          _Human(id, GameClient(backend: online.gameAs(id), roomId: room.id), Random(id.hashCode)),
      ];
      await playToTheEnd(humans);
      expect(host.leaks, isEmpty);
      expect(authority.seating.occupants, hasLength(13));
      authority.dispose();
      for (final h in humans) {
        h.client.dispose();
      }
    });
  });

  group('le intenzioni', () {
    test('quelle fuori regola tornano rifiutate a chi le ha mandate, e la partita resta com\'era', () async {
      final (authority, _) = await startWith(joiners: ['bruno'], bots: 2, seed: 2);
      final bruno = GameClient(backend: online.gameAs('bruno'), roomId: room.id);
      await settle();
      expect(bruno.ready, isTrue);
      final seat = bruno.seat!.view.seat.id;
      final version = authority.version;

      // Di notte non si vota in piazza.
      await bruno.send(DayVote(seat, 's1'));
      await settle();
      expect(bruno.takeRejection()?.error, IntentError.wrongPhase);
      expect(bruno.busy, isFalse);
      expect(authority.version, greaterThan(version), reason: 'la risposta arriva con una versione nuova');

      // Un bersaglio che non si può scegliere.
      await bruno.send(NightAction(seat, 's99'));
      await settle();
      expect(bruno.takeRejection()?.error, anyOf(IntentError.targetNotAllowed, IntentError.notYourAction));

      // La mossa giusta passa; la seconda no.
      final option = bruno.seat!.view.action!;
      await bruno.send(Pass(seat));
      await settle();
      expect(bruno.takeRejection(), isNull);
      expect(bruno.seat!.view.action, isNull, reason: option.type.name);
      await bruno.send(Pass(seat));
      await settle();
      expect(bruno.takeRejection()?.error, IntentError.alreadyActed);

      // Un'intenzione illeggibile.
      await online.gameAs('bruno').sendRaw(room.id, {'type': 'magia', 'seat': seat});
      await settle();
      expect(bruno.seat!.receipt!.result, isA<IntentRejected>());

      authority.dispose();
      bruno.dispose();
    });

    test('nessuno agisce per un altro posto, e chi non siede non agisce', () async {
      final (authority, _) = await startWith(joiners: ['bruno'], bots: 2, seed: 2);
      final other = authority.seating.occupants.firstWhere((o) => o.profileId == 'anna').seat;
      await expectLater(
        online.gameAs('bruno').sendIntent(room.id, Pass(other)),
        throwsA(isA<OnlineException>().having((e) => e.failure, 'failure', OnlineFailure.notAllowed)),
      );
      await expectLater(
        online.gameAs('carla').sendIntent(room.id, Pass('s1')),
        throwsA(isA<OnlineException>()),
        reason: 'Carla non è nella stanza',
      );
      authority.dispose();
    });

    test('le intenzioni e lo stato salvato li legge solo il padrone di casa', () async {
      final (authority, _) = await startWith(joiners: ['bruno'], bots: 2, seed: 2);
      await settle();
      final seat = authority.seating.occupants.firstWhere((o) => o.profileId == 'bruno').seat;
      final intents = <List<IntentEnvelope>>[];
      final sub = online.gameAs('bruno').watchIntents(room.id).listen(intents.add);
      await online.gameAs('bruno').sendIntent(room.id, Pass(seat));
      await settle();
      expect(intents, isEmpty, reason: 'Bruno non legge le intenzioni, nemmeno le sue');
      expect(await online.gameAs('bruno').loadHostState(room.id), isNull);
      expect(await online.gameAs('carla').loadHostState(room.id), isNull);
      await expectLater(
        online.gameAs('bruno').publish(
          room.id,
          GamePublication(version: 999, board: const {}, seatViews: const {}, hostState: const {}),
        ),
        throwsA(isA<OnlineException>()),
      );
      await sub.cancel();
      authority.dispose();
    });

    test('solo il padrone di casa mette i bot e apre la partita', () async {
      online.joinAs('bruno', room.code);
      await expectLater(online.gameAs('bruno').setBots(room.id, 2), throwsA(isA<OnlineException>()));
      await expectLater(online.gameAs('anna').setBots(room.id, 15), throwsA(isA<OnlineException>()),
          reason: 'bot e persone stanno nei sedici posti');
      await expectLater(
        online.gameAs('bruno').startGame(room.id, const []),
        throwsA(isA<OnlineException>()),
      );
      await expectLater(
        online.gameAs('anna').startGame(room.id, const [
          SeatPlan(seat: 's1', profileId: 'anna', name: 'anna'),
          SeatPlan(seat: 's2', profileId: null, name: 'bot.alfa'),
          SeatPlan(seat: 's3', profileId: null, name: 'bot.bravo'),
          SeatPlan(seat: 's4', profileId: null, name: 'bot.charlie'),
        ]),
        throwsA(isA<OnlineException>()),
        reason: 'Bruno è nella stanza e non ha un posto',
      );
      await expectLater(
        online.gameAs('anna').startGame(room.id, const [
          SeatPlan(seat: 's1', profileId: 'anna', name: 'anna'),
          SeatPlan(seat: 's2', profileId: 'bruno', name: 'bruno'),
          SeatPlan(seat: 's3', profileId: null, name: 'carla'),
          SeatPlan(seat: 's4', profileId: null, name: 'bot.bravo'),
        ]),
        throwsA(isA<OnlineException>()),
        reason: 'un bot non si spaccia per una persona',
      );
    });
  });

  group('chi si ricollega', () {
    test('un telefono che ricarica riceve di nuovo la sua vista', () async {
      final (authority, _) = await startWith(joiners: ['bruno'], bots: 3, seed: 5);
      var bruno = GameClient(backend: online.gameAs('bruno'), roomId: room.id);
      await settle();
      final role = bruno.seat!.view.role;
      final seat = bruno.seat!.view.seat.id;
      await bruno.send(Pass(seat));
      await settle();
      final version = bruno.board!.version;
      bruno.dispose();

      bruno = GameClient(backend: online.gameAs('bruno'), roomId: room.id);
      expect(bruno.ready, isFalse);
      await settle();
      expect(bruno.ready, isTrue);
      expect(bruno.seat!.view.role, role);
      expect(bruno.board!.version, greaterThanOrEqualTo(version));
      expect(bruno.seat!.view.action, isNull, reason: 'la mossa di stanotte resta fatta');
      authority.dispose();
      bruno.dispose();
    });

    test('il padrone di casa che riavvia l\'app riprende la partita da dove era', () async {
      final (first, _) = await startWith(joiners: ['bruno'], bots: 3, seed: 6);
      final anna = _Human('anna', GameClient(backend: online.gameAs('anna'), roomId: room.id), Random(1));
      final bruno = _Human('bruno', GameClient(backend: online.gameAs('bruno'), roomId: room.id), Random(2));
      await settle();
      await anna.act();
      await settle();
      final round = first.engine.round;
      final roles = first.engine.setup.roles.map((p, r) => MapEntry(p.id, r));
      final version = first.version;
      first.dispose();

      // Intanto Bruno manda la sua mossa: la ritroverà chi riprende.
      await bruno.act();
      await settle();

      final host = _Inspected(online.gameAs('anna'));
      final resumed = await GameAuthority.resume(backend: host, roomId: room.id, clock: clock, random: Random(7));
      expect(resumed, isNotNull);
      expect(resumed!.engine.round, round);
      expect(resumed.engine.setup.roles.map((Player p, r) => MapEntry(p.id, r)), roles);
      expect(resumed.version, greaterThan(version));
      await settle();
      expect(bruno.client.busy, isFalse, reason: 'la mossa di Bruno è stata gestita da chi ha ripreso');

      await playToTheEnd([anna, bruno]);
      expect(host.leaks, isEmpty);
      expect(resumed.engine.winner, isNotNull);
      resumed.dispose();
      anna.client.dispose();
      bruno.client.dispose();
    });

    test('allo scadere chi non ha scelto passa, e chi non ha votato si astiene', () async {
      final (authority, _) = await startWith(joiners: ['bruno'], bots: 2, seed: 8);
      await settle();
      expect(authority.engine.phase, GamePhase.night);
      clock.elapse(const Duration(minutes: 4));
      await settle();
      expect(authority.engine.round > 1 || authority.engine.phase != GamePhase.night, isTrue,
          reason: 'la notte si è chiusa anche senza le persone');
      authority.dispose();
    });
  });
}
