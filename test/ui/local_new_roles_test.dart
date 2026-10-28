import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/rules/player.dart';
import 'package:oberta/rules/role.dart';
import 'package:oberta/ui/widgets/death_scene.dart';

import '../support/local_game.dart';
import 'game_screen_test.dart' show pumpGame;

// Sul telefono unico: la cella con la domanda e la risposta scritte, il
// blocco della Prostituta letto al turno dopo, la tregua del Pacifista
// davanti a tutti (docs/ruoli.md, 3.1, 3.2, 3.10).

const ada = Player(id: 'ada', name: 'Ada');
const bruno = Player(id: 'bruno', name: 'Bruno');
const carla = Player(id: 'carla', name: 'Carla');
const dino = Player(id: 'dino', name: 'Dino');
const elio = Player(id: 'elio', name: 'Elio');
const fabio = Player(id: 'fabio', name: 'Fabio');
const gina = Player(id: 'gina', name: 'Gina');

final deal = {
  ada: Role.mafioso,
  bruno: Role.carceriere,
  carla: Role.detective,
  dino: Role.cittadino,
  elio: Role.pacifista,
  fabio: Role.prostituta,
  gina: Role.cittadino,
};

Future<void> _toTheDay(WidgetTester tester) async {
  for (var i = 0; i < 12 && find.text('APRI LA DISCUSSIONE').evaluate().isEmpty; i++) {
    if (find.text('BUIO IN SALA').evaluate().isNotEmpty) {
      await tester.tap(find.text('BUIO IN SALA'));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(DeathScene.length + const Duration(milliseconds: 100));
      await tester.pump();
      await tapLabel(tester, 'AVANTI');
      continue;
    }
    await tester.pumpAndSettle();
  }
  await tapLabel(tester, 'APRI LA DISCUSSIONE');
}

void main() {
  testWidgets('la cella, il blocco e la tregua sul telefono unico', (tester) async {
    await pumpGame(tester, deal: deal);
    await tapLabel(tester, 'COMINCIA LA NOTTE');

    await nightTurn(tester, ada, pick: dino);

    // Il Carceriere chiude Carla in cella e le scrive una domanda.
    await tapKey(tester, 'local.itsMe');
    await tapSeat(tester, carla);
    await tapKey(tester, 'local.confirm');
    expect(find.text('3 Carla è in cella.'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('game.cellQuestion')), 'Chi sei?');
    await tapKey(tester, 'local.done');

    // Carla, al suo turno, non ha mosse: la cella e la domanda.
    expect(curtainName(tester), '3 CARLA');
    await tapKey(tester, 'local.itsMe');
    expect(find.byKey(const Key('game.jailed')), findsOneWidget);
    expect(find.textContaining('«Chi sei?»'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('game.cellAnswer')), 'Una del popolo');
    await tapKey(tester, 'local.done');

    await nightTurn(tester, dino);
    await nightTurn(tester, elio);
    // La Prostituta tiene occupato il Pacifista.
    await nightTurn(tester, fabio, pick: elio);
    await nightTurn(tester, gina);

    await _toTheDay(tester);

    // La tregua: il Pacifista si fa riconoscere, poi svela Ada a tutti.
    await tapKey(tester, 'game.truce');
    await tapSeat(tester, gina);
    await tapKey(tester, 'game.powerConfirm');
    expect(find.text('Solo il Pacifista può chiedere la tregua.'), findsOneWidget);
    await tapSeat(tester, elio);
    await tapKey(tester, 'game.powerConfirm');
    await tapSeat(tester, ada);
    await tapKey(tester, 'game.powerConfirm');
    expect(find.byKey(const Key('game.verdict')), findsOneWidget);
    expect(find.textContaining('Il Pacifista ha chiesto la tregua'), findsWidgets);
    await tapKey(tester, 'local.afterVerdict');

    // La notte dopo: il Carceriere legge la risposta, il Pacifista il blocco.
    await tapLabel(tester, 'COMINCIA LA NOTTE');
    await nightTurn(tester, ada, pick: gina);
    expect(curtainName(tester), '2 BRUNO');
    await tapKey(tester, 'local.itsMe');
    expect(find.text('Dalla cella, Carla ha risposto: «Una del popolo»'), findsOneWidget);
    await tapKey(tester, 'local.pass');
    await tapKey(tester, 'local.done');
    await nightTurn(tester, carla);
    expect(curtainName(tester), '5 ELIO');
    await tapKey(tester, 'local.itsMe');
    expect(find.text('Ieri notte qualcuno ti ha tenuto occupato: la tua mossa è saltata.'), findsOneWidget);
  });
}
