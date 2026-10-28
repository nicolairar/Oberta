import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/rules/player.dart';
import 'package:oberta/rules/role.dart';
import 'package:oberta/ui/widgets/death_scene.dart';

import 'game_screen_test.dart' show pumpGame, tap, nightTurn;

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
      await tap(tester, 'AVANTI');
      continue;
    }
    await tester.pumpAndSettle();
  }
  await tap(tester, 'APRI LA DISCUSSIONE');
}

void main() {
  testWidgets('la cella, il blocco e la tregua sul telefono unico', (tester) async {
    await pumpGame(tester, deal: deal);
    await tap(tester, 'COMINCIA LA NOTTE');

    await nightTurn(tester, ada, pick: dino);
    await tap(tester, 'FATTO');

    // Il Carceriere chiude Carla in cella e le scrive una domanda.
    await nightTurn(tester, bruno, pick: carla);
    expect(find.text('Carla è in cella.'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('game.cellQuestion')), 'Chi sei?');
    await tap(tester, 'FATTO');

    // Carla, al suo turno, non ha mosse: la cella e la domanda.
    expect(find.text('CARLA'), findsOneWidget);
    await tap(tester, 'SONO IO');
    expect(find.byKey(const Key('game.jailed')), findsOneWidget);
    expect(find.text('«Chi sei?»'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('game.cellAnswer')), 'Una del popolo');
    await tap(tester, 'FATTO');

    await nightTurn(tester, dino);
    await tap(tester, 'FATTO');
    await nightTurn(tester, elio);
    await tap(tester, 'FATTO');
    // La Prostituta tiene occupato il Pacifista.
    await nightTurn(tester, fabio, pick: elio);
    await tap(tester, 'FATTO');
    await nightTurn(tester, gina);
    await tap(tester, 'FATTO');

    await _toTheDay(tester);

    // La tregua: il Pacifista si fa riconoscere, poi svela Ada a tutti.
    await tester.tap(find.byKey(const Key('game.truce')));
    await tester.pumpAndSettle();
    await tap(tester, 'Gina');
    await tester.tap(find.byKey(const Key('game.powerConfirm')));
    await tester.pumpAndSettle();
    expect(find.text('Solo il Pacifista può chiedere la tregua.'), findsOneWidget);
    await tap(tester, 'Elio');
    await tester.tap(find.byKey(const Key('game.powerConfirm')));
    await tester.pumpAndSettle();
    await tap(tester, 'Ada');
    await tester.tap(find.byKey(const Key('game.powerConfirm')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('game.verdict')), findsOneWidget);
    expect(find.textContaining('Il Pacifista ha chiesto la tregua'), findsWidgets);
    await tap(tester, 'CONTINUA');

    // La notte dopo: il Carceriere legge la risposta, il Pacifista il blocco.
    await tap(tester, 'COMINCIA LA NOTTE');
    await nightTurn(tester, ada, pick: gina);
    await tap(tester, 'FATTO');
    expect(find.text('BRUNO'), findsOneWidget);
    await tap(tester, 'SONO IO');
    expect(find.text('Dalla cella, Carla ha risposto: «Una del popolo»'), findsOneWidget);
    await tap(tester, 'PASSO');
    await tap(tester, 'FATTO');
    await nightTurn(tester, carla);
    await tap(tester, 'FATTO');
    expect(find.text('ELIO'), findsOneWidget);
    await tap(tester, 'SONO IO');
    expect(find.text('Ieri notte qualcuno ti ha tenuto occupato: la tua mossa è saltata.'), findsOneWidget);
  });
}
