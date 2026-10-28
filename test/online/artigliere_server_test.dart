import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/online/game/game_schedule.dart';
import 'package:oberta/rules/game_engine.dart';
import 'package:oberta/rules/role.dart';

import 'blockers_server_test.dart' show Table, pass;

// Il colpo dell'Artigliere sul server: solo in discussione, dal secondo
// giorno; il colpito e il suo ruolo li vede tutto il tavolo, i colpi
// rimasti solo lui (docs/ruoli.md, 3.5).

const gunTable = {
  's1': Role.mafioso,
  's2': Role.artigliere,
  's3': Role.detective,
  's4': Role.cittadino,
  's5': Role.cittadino,
  's6': Role.cittadino,
};

Map<String, Object?> fire(String seat, String target) => {'type': 'fire', 'seat': seat, 'target': target};

void toDiscussion(Table table) {
  while (table.game.stage != Stage.discussion) {
    if (table.game.stage == Stage.night) {
      table.send({
        for (final seat in gunTable.keys)
          if (table.game.engine.isAlive(table.game.seating.playerAt(seat))) seat: pass(seat),
      });
      table.wait();
    } else if (table.game.stage.acknowledged) {
      table.ackAll();
    } else {
      table.wait();
    }
  }
}

void main() {
  test('il primo giorno no; dal secondo, in discussione, e lo sa tutto il tavolo', () {
    final table = Table(gunTable);
    table.ackAll();
    toDiscussion(table);
    expect(table.game.engine.round, 1);
    expect(table.view('s2').containsKey('fireTargets'), isFalse);
    expect(table.view('s2')['shotsLeft'], 2);
    table.send({'s2': fire('s2', 's4')});
    expect(table.receipt('s2')?['ok'], isFalse);
    // Il voto: nessuno condannato, e niente colpi nemmeno al voto.
    table.ackAll();
    if (table.game.stage == Stage.vote) {
      table.send({'s2': fire('s2', 's4')});
      expect(table.receipt('s2')?['ok'], isFalse);
      expect(table.view('s2').containsKey('fireTargets'), isFalse);
    }
    toDiscussion(table);
    expect(table.game.engine.round, 2);
    expect(table.view('s2')['fireTargets'], contains('s4'));
    for (final seat in gunTable.keys.where((s) => s != 's2')) {
      expect(table.view(seat).containsKey('fireTargets'), isFalse, reason: seat);
      expect(table.view(seat).containsKey('shotsLeft'), isFalse, reason: seat);
    }
    table.send({'s2': fire('s2', 's4')});
    expect(table.receipt('s2')?['ok'], isTrue);
    final board = table.last.board['board'] as Map<String, Object?>;
    expect(board['shots'], [
      {'round': 2, 'gunner': 's2', 'seat': 's4', 'role': 'cittadino'},
    ]);
    final known = [for (final k in board['revealed'] as List<Object?>) (k as Map)['seat']];
    expect(known, containsAll(['s2', 's4']));
    final cannon = table.last.events.singleWhere((e) => e['kind'] == 'cannon');
    expect(cannon['to'], isNull);
    expect((cannon['data'] as Map)['role'], 'cittadino');
    expect(table.view('s2')['shotsLeft'], 1);
    expect(table.view('s2').containsKey('fireTargets'), isFalse, reason: 'uno al giorno');
  });

  test('il colpo all\'ultimo della Famiglia chiude la partita subito', () {
    final table = Table(gunTable);
    table.ackAll();
    toDiscussion(table);
    table.ackAll();
    toDiscussion(table);
    if (!table.game.engine.isAlive(table.game.seating.playerAt('s2'))) return;
    table.send({'s2': fire('s2', 's1')});
    expect(table.receipt('s2')?['ok'], isTrue);
    expect(table.game.engine.phase, GamePhase.ended);
    expect(table.game.stage, Stage.ended);
    expect(table.game.engine.winner, Team.citizens);
  });
}
