import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/online/game/game_backend.dart';
import 'package:oberta/online/game/game_schedule.dart';
import 'package:oberta/online/game/game_server.dart';
import 'package:oberta/rules/game_engine.dart';
import 'package:oberta/rules/role.dart';

import '../rules/player_view_test.dart' show leaksIn;

// La cella, il blocco e la tregua sul server: chi vede cosa, chi scrive
// dove, e quando una mossa vale (docs/ruoli.md, 3.1, 3.2, 3.10, 4).

const roles = {
  's1': Role.mafioso,
  's2': Role.prostituta,
  's3': Role.carceriere,
  's4': Role.pacifista,
  's5': Role.detective,
  's6': Role.cittadino,
  's7': Role.cittadino,
  's8': Role.cittadino,
};

class Table {
  final Map<String, Role> deal;
  final ServerGame game;
  DateTime now = DateTime.utc(2026, 10, 28, 21);
  int _id = 0;
  late ServerStep last;

  Table([this.deal = roles])
    : game = ServerGame.scripted(
        seats: [for (final seat in deal.keys) SeatPlan(seat: seat, profileId: 'p$seat', name: 'n$seat')],
        roles: deal,
        language: 'it',
        now: DateTime.utc(2026, 10, 28, 21),
        seed: 5,
      ) {
    last = game.step(now: now, fresh: true);
  }

  ServerStep send(Map<String, Map<String, Object?>> intents) {
    now = now.add(const Duration(seconds: 3));
    last = game.step(
      now: now,
      intents: [
        for (final MapEntry(key: seat, value: intent) in intents.entries)
          IntentEnvelope(id: ++_id, token: 't$_id', seat: seat, intent: intent),
      ],
    );
    _noLeaks();
    return last;
  }

  /// Tutti confermano la fase in corso (carta, alba, discussione...).
  ServerStep ackAll() => send({
    for (final seat in deal.keys)
      if (game.engine.isAlive(game.seating.playerAt(seat))) seat: {'type': 'ack', 'seat': seat, 'stage': game.window.key},
  });

  /// Lascia correre l'orologio fino alla prossima scadenza.
  ServerStep wait() {
    now = game.nextDue() ?? now;
    last = game.step(now: now.add(const Duration(seconds: 1)));
    _noLeaks();
    return last;
  }

  Map<String, Object?> view(String seat) => last.seatViews[seat]!['view'] as Map<String, Object?>;
  Map<String, Object?> rights(String seat) => ((last.chat['seats'] as Map)[seat] as Map).cast<String, Object?>();
  Map<String, Object?>? receipt(String seat) =>
      ((last.seatViews[seat]!['receipt'] as Map?)?['result'] as Map?)?.cast<String, Object?>();

  void _noLeaks() {
    for (final seat in deal.keys) {
      final json = jsonDecode(jsonEncode(view(seat))) as Map<String, Object?>;
      expect(leaksIn(game.engine, game.seating.playerAt(seat), json), isEmpty, reason: seat);
    }
  }
}

Map<String, Object?> night(String seat, String target) => {'type': 'nightAction', 'seat': seat, 'target': target};
Map<String, Object?> pass(String seat) => {'type': 'pass', 'seat': seat};
Map<String, Object?> pacify(String seat, String target) => {'type': 'pacify', 'seat': seat, 'target': target};

void main() {
  cupidTests();
  marksmanTests();
  test('la cella: la chat solo per il Carceriere (senza nome) e il prigioniero, niente voce né Famiglia', () {
    final table = Table();
    table.ackAll();
    expect(table.game.stage, Stage.night);
    table.send({'s3': night('s3', 's1')});

    // Chi scrive nella cella stanotte: un canale per notte.
    expect(table.rights('s3'), containsPair('jail', 'jail:1'));
    expect(table.rights('s3'), containsPair('jailer', true));
    expect(table.rights('s1'), containsPair('jail', 'jail:1'));
    expect(table.rights('s1'), containsPair('jailed', true));
    expect(table.rights('s1')['jailer'], isFalse);
    for (final seat in ['s2', 's4', 's5', 's6', 's7', 's8']) {
      expect(table.rights(seat)['jail'], isNull, reason: seat);
      expect(table.rights(seat)['jailed'], isFalse, reason: seat);
    }
    // Il prigioniero non agisce; gli altri non sanno chi è dentro (la
    // Prostituta nemmeno: non sa chi è della Famiglia).
    expect(table.view('s1')['action'], isNull);
    expect(table.view('s1')['cell'], 's1');
    expect(table.view('s3')['cell'], 's1');
    for (final seat in ['s2', 's4', 's5', 's6', 's7', 's8']) {
      expect(table.view(seat).containsKey('cell'), isFalse, reason: seat);
    }
    // Nessuna vista porta il nome di chi ha chiuso la cella, se non la sua.
    for (final seat in ['s1', 's2']) {
      expect(jsonEncode(table.view(seat)['known']), isNot(contains('s3')), reason: seat);
    }
    // Le righe private: al prigioniero e al Carceriere, non al resto.
    final cells = [for (final e in table.last.events) if (e['kind'] == 'cell') e['to']];
    expect(cells.toSet(), {'s1', 's3'});
    expect(table.last.events.where((e) => e['kind'] == 'cell' && e['to'] == null), isEmpty);
    // Un'altra mossa del prigioniero torna rifiutata.
    table.send({'s1': {'type': 'mafiaVote', 'seat': 's1', 'target': 's6'}});
    expect(table.receipt('s1')?['ok'], isFalse);

    // All'alba la cella si apre: niente più canale.
    table.send({for (final seat in ['s2', 's4', 's5', 's6', 's7', 's8']) seat: pass(seat)});
    table.wait();
    expect(table.game.stage, isNot(Stage.night));
    for (final seat in roles.keys) {
      expect(table.rights(seat)['jail'], isNull, reason: seat);
      expect(table.rights(seat)['jailed'], isFalse, reason: seat);
    }
  });

  test('la Prostituta gioca al buio: niente Famiglia per lei, niente lei per la Famiglia', () {
    final table = Table({...roles, 's6': Role.mafioso});
    // La carta: lei non ha complici, e i complici non hanno lei.
    expect(table.view('s2')['teammates'], anyOf(isNull, isEmpty));
    expect(table.view('s1')['teammates'], ['s6']);
    expect(table.view('s6')['teammates'], ['s1']);
    table.ackAll();
    expect(table.game.stage, Stage.night);
    // Chat e voce della Famiglia: lei fuori, loro dentro.
    expect(table.rights('s2')['family'], isFalse);
    expect(table.rights('s1')['family'], isTrue);
    expect(table.rights('s6')['family'], isTrue);
    expect(table.view('s2')['familyChat'], anyOf(isNull, isFalse));
    expect(table.view('s1')['familyChat'], isTrue);
    // Le mani: la Famiglia vota, lei non le vede; lei blocca uno di loro.
    table.send({'s1': {'type': 'mafiaVote', 'seat': 's1', 'target': 's7'}});
    table.send({'s2': night('s2', 's6')});
    expect(table.receipt('s2')?['ok'], isTrue);
    expect(table.view('s2')['familyVotes'], anyOf(isNull, isEmpty));
    final votes = table.view('s6')['familyVotes'] as List;
    expect([for (final v in votes) (v as Map)['seat']], ['s1']);
    expect(jsonEncode(table.view('s6')), isNot(contains('"busy"')));
    for (final seat in ['s1', 's6']) {
      expect(jsonEncode(table.view(seat)['known']), isNot(contains('"s2"')), reason: seat);
    }
    expect(jsonEncode(table.view('s2')['known']), allOf(isNot(contains('"s1"')), isNot(contains('"s6"'))));
    // All'alba: la riga della Famiglia va a loro due, mai a lei.
    final events = [...table.send({for (final seat in ['s3', 's4', 's5', 's6', 's7', 's8']) seat: pass(seat)}).events];
    while (table.game.stage == Stage.night || table.game.stage == Stage.dawnFilms) {
      events.addAll(table.wait().events);
    }
    final closing = [for (final e in events) if (e['kind'] == 'familyTarget') e['to']];
    expect(closing, isNot(contains('s2')));
    expect(closing, contains('s1'));
  });

  test('il blocco: lo sa solo chi l\'ha subito, all\'alba', () {
    final table = Table();
    table.ackAll();
    table.send({'s2': night('s2', 's5'), 's5': night('s5', 's1')});
    table.send({for (final seat in ['s1', 's3', 's4', 's6', 's7', 's8']) seat: pass(seat)});
    while (table.game.stage == Stage.night || table.game.stage == Stage.dawnFilms) {
      table.wait();
    }
    expect(table.view('s5')['busy'], isTrue);
    expect(jsonEncode(table.view('s5')['known']), isNot(contains('"s1"')), reason: 'il Commissario bloccato non sa niente');
    for (final seat in roles.keys.where((s) => s != 's5')) {
      expect(table.view(seat).containsKey('busy'), isFalse, reason: seat);
    }
    final events = [for (final step in [table.last]) ...step.events];
    expect(events.where((e) => e['kind'] == 'busy').map((e) => e['to']), anyOf(isEmpty, ['s5']));
  });

  test('la tregua: solo in discussione, poi niente voto', () {
    final table = Table();
    table.ackAll();
    // Di notte no.
    table.send({'s4': pacify('s4', 's1')});
    expect(table.receipt('s4')?['ok'], isFalse);
    table.send({for (final seat in roles.keys.where((s) => s != 's4')) seat: pass(seat)});
    table.send({'s4': pass('s4')});
    while (table.game.stage != Stage.discussion) {
      table.game.stage.acknowledged ? table.ackAll() : table.wait();
    }
    // In discussione il bottone ce l'ha solo il Pacifista.
    expect((table.view('s4')['action'] as Map)['canPacify'], isTrue);
    for (final seat in roles.keys.where((s) => s != 's4')) {
      expect(table.view(seat)['action'], isNull, reason: seat);
    }
    table.send({'s4': pacify('s4', 's1')});
    expect(table.receipt('s4')?['ok'], isTrue);
    final board = table.last.board['board'] as Map<String, Object?>;
    expect(board['pacifist'], 's4');
    expect(board['pacified'], 's1');
    final truce = table.last.events.singleWhere((e) => e['kind'] == 'truce');
    expect(truce['to'], isNull);
    expect((truce['data'] as Map)['role'], 'mafioso');
    // Fine della discussione: si salta il voto.
    table.ackAll();
    expect(table.game.stage, Stage.verdictFilm);
    expect(table.game.engine.lastLynchTruce, isTrue);
  });
}

const cupidTable = {
  's1': Role.mafioso,
  's2': Role.cupido,
  's3': Role.cittadino,
  's4': Role.cittadino,
  's5': Role.cittadino,
  's6': Role.detective,
};

void cupidTests() {
  test('gli innamorati: lo sa Cupido subito, loro all\'alba; di notte la loro chat, solo per loro', () {
    final table = Table(cupidTable);
    table.ackAll();
    table.send({'s2': {'type': 'link', 'seat': 's2', 'target': 's1', 'second': 's3'}});
    expect(table.game.stage, Stage.night);
    expect(table.view('s2')['lovers'], ['s1', 's3']);
    expect(table.view('s1').containsKey('lovers'), isFalse, reason: 'lo sapranno all\'alba');
    for (final seat in cupidTable.keys) {
      expect(table.rights(seat)['lovers'], isFalse, reason: '$seat: la chat apre dalla notte dopo');
    }
    table.send({for (final seat in ['s1', 's3', 's4', 's5', 's6']) seat: pass(seat)});
    while (table.game.stage == Stage.night) {
      table.wait();
    }
    while (table.game.stage != Stage.night) {
      if (table.game.stage == Stage.vote) {
        table.send({for (final seat in cupidTable.keys) seat: pass(seat)});
      }
      table.game.stage.acknowledged ? table.ackAll() : table.wait();
    }
    expect(table.view('s1')['lovers'], ['s1', 's3']);
    expect(table.view('s3')['lovers'], ['s1', 's3']);
    for (final seat in ['s4', 's5', 's6']) {
      expect(table.view(seat).containsKey('lovers'), isFalse, reason: seat);
    }
    expect(table.rights('s1')['lovers'], isTrue);
    expect(table.rights('s3')['lovers'], isTrue);
    for (final seat in ['s2', 's4', 's5', 's6']) {
      expect(table.rights(seat)['lovers'], isFalse, reason: seat);
    }
  });
}

extension on GameEngine {
  bool get lastLynchTruce => publicView().lastLynch?.truce ?? false;
}

const marksmanTable = {
  's1': Role.mafioso,
  's2': Role.mafioso,
  's3': Role.tiratoreScelto,
  's4': Role.cittadino,
  's5': Role.cittadino,
  's6': Role.cittadino,
  's7': Role.cittadino,
  's8': Role.cittadino,
  's9': Role.cittadino,
};

Map<String, Object?> shoot(String seat) => {'type': 'shoot', 'seat': seat};

void marksmanTests() {
  test('il Tiratore scelto: la mira la sa solo lui, il colpo solo in discussione, lo sparo lo sentono tutti', () {
    final table = Table(marksmanTable);
    table.ackAll();
    table.send({'s3': shoot('s3')});
    expect(table.receipt('s3')?['ok'], isFalse, reason: 'di notte non si spara');
    table.send({'s3': night('s3', 's1')});
    table.send({for (final seat in marksmanTable.keys.where((s) => s != 's3')) seat: pass(seat)});
    while (table.game.stage != Stage.discussion) {
      table.game.stage.acknowledged ? table.ackAll() : table.wait();
    }
    // La mira e i colpi: solo nella vista del Tiratore.
    expect(table.view('s3')['aim'], 's1');
    expect(table.view('s3')['shotsLeft'], 2);
    expect((table.view('s3')['action'] as Map)['canShoot'], isTrue);
    for (final seat in marksmanTable.keys.where((s) => s != 's3')) {
      expect(table.view(seat).containsKey('aim'), isFalse, reason: seat);
      expect(table.view(seat)['action'], isNull, reason: seat);
    }
    final aims = [for (final e in table.last.events) if (e['kind'] == 'aim') e['to']];
    expect(aims, anyOf(isEmpty, ['s3']));

    table.send({'s3': shoot('s3')});
    expect(table.receipt('s3')?['ok'], isTrue);
    expect(table.game.engine.isAlive(table.game.seating.playerAt('s1')), isFalse);
    final board = table.last.board['board'] as Map<String, Object?>;
    expect(board['lastShot'], containsPair('seat', 's1'));
    final shot = table.last.events.singleWhere((e) => e['kind'] == 'shot');
    expect(shot['to'], isNull);
    expect((shot['data'] as Map)['role'], 'mafioso');
    expect((shot['data'] as Map).containsKey('backfired'), isFalse);
    for (final seat in marksmanTable.keys.where((s) => s != 's3')) {
      expect(jsonEncode(table.view(seat)['known']), isNot(contains('tiratoreScelto')), reason: seat);
    }
    // Un colpo al giorno: la mira è consumata.
    expect((table.view('s3')['action'] as Map?)?['canShoot'], isNot(isTrue));
    expect(table.view('s3')['shotsLeft'], 1);
  });
}

