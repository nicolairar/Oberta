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

  testWidgets('Cupido lega due persone in due tocchi; gli innamorati lo leggono al turno dopo', (tester) async {
    await pumpGame(tester, deal: {ada: Role.mafioso, bruno: Role.cupido, carla: Role.cittadino, dino: Role.cittadino, elio: Role.cittadino});
    await tapLabel(tester, 'COMINCIA LA NOTTE');
    await nightTurn(tester, ada);
    expect(curtainName(tester), contains('BRUNO'));
    await tapKey(tester, 'local.itsMe');
    expect(find.text('Chi fai innamorare?'), findsOneWidget);
    await tapSeat(tester, carla);
    await tapKey(tester, 'local.confirm');
    expect(find.text('E chi altro? Tocca il secondo innamorato.'), findsOneWidget);
    await tapSeat(tester, elio);
    await tapKey(tester, 'local.confirm');
    await tapKey(tester, 'local.done');
    for (final player in [carla, dino, elio]) {
      await nightTurn(tester, player);
    }
    await _toTheDay(tester);
    await tapKey(tester, 'local.toVote');
    await openVote(tester, [ada, bruno, carla, dino, elio], const {});
    await tapKey(tester, 'local.afterVerdict');
    await tapLabel(tester, 'COMINCIA LA NOTTE');
    await nightTurn(tester, ada);
    await tapKey(tester, 'local.itsMe');
    expect(find.textContaining('Hai legato Carla e Elio.'), findsOneWidget);
    await tapKey(tester, 'local.pass');
    await tapKey(tester, 'local.done');
    await tapKey(tester, 'local.itsMe');
    expect(find.textContaining('Il tuo cuore batte per Elio'), findsOneWidget);
  });

  testWidgets('l\'Artigliere spara davanti a tutti dal secondo giorno', (tester) async {
    await pumpGame(tester, deal: {ada: Role.mafioso, bruno: Role.artigliere, carla: Role.cittadino, dino: Role.cittadino, elio: Role.cittadino});
    await tapLabel(tester, 'COMINCIA LA NOTTE');
    for (final player in [ada, bruno, carla, dino, elio]) {
      await nightTurn(tester, player);
    }
    await _toTheDay(tester);
    expect(find.byKey(const Key('game.fire')), findsNothing, reason: 'il primo giorno no');
    await tapKey(tester, 'local.toVote');
    await openVote(tester, [ada, bruno, carla, dino, elio], const {});
    await tapKey(tester, 'local.afterVerdict');
    await tapLabel(tester, 'COMINCIA LA NOTTE');
    for (final player in [ada, bruno, carla, dino, elio]) {
      await nightTurn(tester, player);
    }
    await _toTheDay(tester);
    await tapKey(tester, 'game.fire');
    await tapSeat(tester, carla);
    await tapKey(tester, 'game.powerConfirm');
    expect(find.text('Solo l\'Artigliere può sparare.'), findsOneWidget);
    await tapSeat(tester, bruno);
    await tapKey(tester, 'game.powerConfirm');
    await tapSeat(tester, ada);
    await tapKey(tester, 'game.powerConfirm');
    expect(find.byKey(const Key('game.shot')), findsOneWidget);
    expect(find.textContaining('l\'Artigliere ha colpito'), findsWidgets);
    // Era l'ultimo della Famiglia: la partita è finita.
    expect(find.byKey(const Key('game.shotsLeft')), findsNothing);
    await tapKey(tester, 'game.afterShot');
    expect(find.byKey(const Key('game.afterShot')), findsNothing);
  });

  testWidgets('il Tiratore scelto mira di notte e spara di giorno, davanti a tutti', (tester) async {
    await pumpGame(tester, deal: {ada: Role.mafioso, bruno: Role.tiratoreScelto, carla: Role.cittadino, dino: Role.cittadino, elio: Role.cittadino});
    await tapLabel(tester, 'COMINCIA LA NOTTE');
    await nightTurn(tester, ada, pick: dino);
    expect(curtainName(tester), contains('BRUNO'));
    await tapKey(tester, 'local.itsMe');
    expect(find.text('Chi tieni nel mirino?'), findsOneWidget);
    await tapSeat(tester, ada);
    await tapKey(tester, 'local.confirm');
    await tapKey(tester, 'local.done');
    for (final player in [carla, dino, elio]) {
      await nightTurn(tester, player);
    }
    await _toTheDay(tester);

    await tapKey(tester, 'game.marksman');
    await tapSeat(tester, carla);
    await tapKey(tester, 'game.powerConfirm');
    expect(find.text('Solo il Tiratore scelto può sparare.'), findsOneWidget);
    await tapSeat(tester, bruno);
    await tapKey(tester, 'game.powerConfirm');
    expect(find.textContaining('Nel mirino: 1 Ada'), findsWidgets);
    await tapKey(tester, 'game.marksmanFire');
    expect(find.byKey(const Key('game.marksmanShot')), findsOneWidget);
    expect(find.textContaining('Un colpo dal campanile'), findsWidgets);
    await tapKey(tester, 'game.shotDone');
    expect(find.textContaining('Vincono gli onesti'), findsWidgets);
  });
}
