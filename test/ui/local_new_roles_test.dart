import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/rules/game_setup.dart';
import 'package:oberta/rules/player.dart';
import 'package:oberta/rules/role.dart';
import 'package:oberta/rules/role_assignment.dart';
import 'package:oberta/ui/screens/online/game/noir_role_card.dart';
import 'package:oberta/ui/screens/online/game/seat_card.dart';
import 'package:oberta/ui/screens/role_reveal_screen.dart';
import 'package:oberta/ui/theme/app_theme.dart';
import 'package:oberta/ui/screens/online/game/verdict_line.dart' show TallyScroll;
import 'package:oberta/ui/screens/local/local_table.dart';
import 'package:oberta/ui/widgets/death_scene.dart';
import 'package:oberta/ui/widgets/noir_modal.dart';
import 'package:oberta/ui/widgets/player_avatar.dart';
import 'package:oberta/ui/widgets/spoken_lines.dart';

import '../support/local_game.dart';
import 'game_screen_test.dart' show pumpGame, seat, table, watchVerdict;

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

    // La tregua: chi vuole usare un potere tocca il suo volto e prende il
    // telefono. Gina dietro la tenda non trova niente; Elio sì.
    await openPower(tester, gina);
    expect(find.text('Adesso non hai niente da usare.'), findsOneWidget);
    await tapKey(tester, 'game.powerBack');
    await openPower(tester, elio);
    expect(find.text('IL PACIFISTA'), findsOneWidget);
    expect(find.textContaining('sveli a tutti il ruolo esatto di una persona'), findsOneWidget);
    expect(table(tester).selectable, isNot(contains(elio)), reason: 'non si svela se stesso');
    await tapSeat(tester, ada);
    await tapKey(tester, 'game.powerUse');
    expect(find.byKey(const Key('game.verdict')), findsOneWidget);
    expect(find.textContaining('Il Pacifista ha chiesto la tregua'), findsWidgets);
    expect(seat(tester, elio).role, Role.pacifista, reason: 'il posto del Pacifista porta la sua carta');
    expect(seat(tester, ada).role, Role.mafioso, reason: 'il ruolo svelato è sul tavolo');
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

  testWidgets('la Prostituta gioca al buio: non vede la Famiglia, la blocca; rimasta sola, la notte è sua', (tester) async {
    await pumpGame(tester, deal: {
      ada: Role.mafioso,
      bruno: Role.cittadino,
      carla: Role.cittadino,
      dino: Role.cittadino,
      elio: Role.cittadino,
      fabio: Role.prostituta,
    });
    await tapLabel(tester, 'COMINCIA LA NOTTE');
    // La Famiglia non sa di lei.
    expect(curtainName(tester), contains('ADA'));
    await tapKey(tester, 'local.itsMe');
    expect(seat(tester, fabio).note, isNull);
    await tapSeat(tester, dino);
    await tapKey(tester, 'local.confirm');
    await tapKey(tester, 'local.done');
    for (final player in [bruno, carla, dino, elio]) {
      await nightTurn(tester, player);
    }
    // Lei non sa chi è della Famiglia, non vede le mani, e blocca proprio Ada.
    expect(curtainName(tester), contains('FABIO'));
    await tapKey(tester, 'local.itsMe');
    expect(find.text('Per chi canti stanotte?'), findsOneWidget);
    expect(seat(tester, ada).note, isNull);
    expect(table(tester).votes, isEmpty);
    expect(table(tester).selectable, contains(ada));
    expect(find.textContaining('ultima della Famiglia'), findsNothing);
    await tapSeat(tester, ada);
    await tapKey(tester, 'local.confirm');
    await tapKey(tester, 'local.done');

    // Ada era ferma: stanotte non muore nessuno. Di giorno la piazza la lincia.
    await _toTheDay(tester);
    expect(seat(tester, dino).fallen, isFalse, reason: 'l\'agguato bloccato non parte');
    await tapKey(tester, 'local.toVote');
    await voiceVerdict(tester, ada);
    await watchVerdict(tester);
    await tapKey(tester, 'local.afterVerdict');

    // La notte dopo: Ada ha letto che era occupata; Fabio è l'ultima, e vota lei.
    await tapLabel(tester, 'COMINCIA LA NOTTE');
    for (final player in [bruno, carla, dino, elio]) {
      await nightTurn(tester, player);
    }
    expect(curtainName(tester), contains('FABIO'));
    await tapKey(tester, 'local.itsMe');
    expect(find.text('Sei rimasta l\'ultima della Famiglia: ora la notte è tua.'), findsOneWidget);
    expect(find.text('Chi eliminate stanotte?'), findsOneWidget);
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
    await voiceVerdict(tester, null);
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
    // Il primo giorno il cannone tace: dietro la tenda, niente da usare.
    await openPower(tester, bruno);
    expect(find.text('Adesso non hai niente da usare.'), findsOneWidget);
    await tapKey(tester, 'game.powerBack');
    await tapKey(tester, 'local.toVote');
    await voiceVerdict(tester, null);
    await tapKey(tester, 'local.afterVerdict');
    await tapLabel(tester, 'COMINCIA LA NOTTE');
    for (final player in [ada, bruno, carla, dino, elio]) {
      await nightTurn(tester, player);
    }
    await _toTheDay(tester);
    await openPower(tester, bruno);
    expect(find.text('L\'ARTIGLIERE'), findsOneWidget);
    expect(find.text('Colpi rimasti: 2.'), findsOneWidget);
    expect(seat(tester, bruno).role, isNull, reason: 'prima del colpo nessuno sa chi è');
    await tapSeat(tester, ada);
    await tapKey(tester, 'game.powerUse');
    expect(find.byKey(const Key('game.shot')), findsOneWidget);
    expect(find.textContaining('l\'Artigliere ha colpito'), findsWidgets);
    expect(seat(tester, bruno).role, Role.artigliere, reason: 'dopo il colpo il suo posto porta la carta');
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

    await openPower(tester, carla);
    expect(find.text('Adesso non hai niente da usare.'), findsOneWidget);
    await tapKey(tester, 'game.powerBack');
    await openPower(tester, bruno);
    expect(find.text('IL TIRATORE SCELTO'), findsOneWidget);
    expect(find.textContaining('Nel mirino: 1 Ada'), findsWidgets);
    expect(find.text('Colpi rimasti: 2.'), findsOneWidget);
    await tapKey(tester, 'game.powerUse');
    expect(find.byKey(const Key('game.marksmanShot')), findsOneWidget);
    expect(find.textContaining('Un colpo dal campanile'), findsWidgets);
    await tapKey(tester, 'game.shotDone');
    expect(find.textContaining('Vincono gli onesti'), findsWidgets);
  });

  _powerTests();
  _voteTests();
}

/// Quello che il tavolo vede adesso: ogni scritta sullo schermo, ogni posto
/// con quello che mostra, e quello che legge la voce.
List<String> _screen(WidgetTester tester) => [
      for (final element in find.byType(RichText).evaluate()) (element.widget as RichText).text.toPlainText(),
      for (final element in find.byType(SeatCard).evaluate())
        switch (element.widget as SeatCard) {
          final s => '${s.name}|${s.number}|${s.role}|${s.note}|${s.me}|${s.selected}|${s.selectable}|${s.dimmed}|${s.votes}',
        },
      for (final element in find.byType(SpokenLines).evaluate())
        for (final line in (element.widget as SpokenLines).lines) 'voce: ${line.text}',
    ];

/// Una partita a cinque fino alla discussione del primo giorno, poi «Usa un
/// potere» toccato da Bruno: le schermate prima di «Sono io».
Future<List<List<String>>> _beforeTheCurtain(WidgetTester tester, Map<Player, Role> deal) async {
  await pumpGame(tester, deal: deal);
  await tapLabel(tester, 'COMINCIA LA NOTTE');
  for (final player in deal.keys) {
    await nightTurn(tester, player);
  }
  await tapLabel(tester, 'APRI LA DISCUSSIONE');
  final screens = [_screen(tester)];
  await tapKey(tester, 'game.usePower');
  screens.add(_screen(tester));
  await tapSeat(tester, bruno);
  screens.add(_screen(tester));
  await tapKey(tester, 'game.powerConfirm');
  screens.add(_screen(tester));
  return screens;
}

void _powerTests() {
  testWidgets('la carta di chi ha un potere di giorno dice dove trovarlo; le altre no', (tester) async {
    tester.view.physicalSize = const Size(393, 852) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: RoleRevealScreen(setup: GameSetup.fromRoles({ada: Role.artigliere, bruno: Role.cittadino, carla: Role.mafioso})),
    ));
    const hint = 'Di giorno: prendi il telefono e tocca «Usa un potere».';
    for (final (player, expected) in [(ada, findsOneWidget), (bruno, findsNothing)]) {
      await tapKey(tester, 'local.itsMe');
      final hold = await tester.startGesture(tester.getCenter(find.byType(NoirRoleCard)));
      await tester.pumpAndSettle();
      expect(find.text(hint), expected, reason: player.name);
      await hold.up();
      await tester.pumpAndSettle();
      await tapKey(tester, 'local.gotIt');
    }
  });

  testWidgets('prima di «Sono io» chi ha un potere e chi no vedono e sentono le stesse cose', (tester) async {
    final powered = await _beforeTheCurtain(tester, {
      ada: Role.mafioso,
      bruno: Role.pacifista,
      carla: Role.cittadino,
      dino: Role.cittadino,
      elio: Role.cittadino,
    });
    expect(curtainName(tester), '2 BRUNO');
    expect(find.text('Prendi il telefono in mano e non farti vedere da nessuno.'), findsOneWidget);
    await tapKey(tester, 'local.itsMe');
    expect(find.text('IL PACIFISTA'), findsOneWidget, reason: 'il potere solo dopo «Sono io»');
    await tester.pumpWidget(const SizedBox());

    final powerless = await _beforeTheCurtain(tester, {
      ada: Role.mafioso,
      bruno: Role.cittadino,
      carla: Role.pacifista,
      dino: Role.cittadino,
      elio: Role.cittadino,
    });
    expect(powerless, hasLength(powered.length));
    for (var i = 0; i < powered.length; i++) {
      expect(powerless[i], powered[i], reason: 'schermata $i');
    }
    for (final screen in powered) {
      expect(screen.where((text) => text.contains('Pacifista')), isEmpty, reason: 'nessun ruolo prima della tenda');
    }
    await tapKey(tester, 'local.itsMe');
    expect(find.text('Adesso non hai niente da usare.'), findsOneWidget);
    expect(find.byKey(const Key('game.powerUse')), findsNothing);
  });

  testWidgets('«Usa un potere» c\'è a ogni discussione, anche senza ruoli con un potere; dalla tenda si torna indietro', (tester) async {
    await pumpGame(tester);
    await tapLabel(tester, 'COMINCIA LA NOTTE');
    for (final player in [ada, bruno, carla, dino]) {
      await nightTurn(tester, player);
    }
    await tapLabel(tester, 'APRI LA DISCUSSIONE');
    expect(find.byKey(const Key('game.usePower')), findsOneWidget);
    expect(find.text('USA UN POTERE'), findsOneWidget);
    await tapKey(tester, 'game.usePower');
    expect(find.text('Chi sei? Tocca il tuo volto.'), findsWidgets);
    expect(table(tester).selectable, {ada, bruno, carla, dino});
    await tapKey(tester, 'game.powerCancel');
    expect(find.byKey(const Key('local.day')), findsOneWidget);

    // Un volto toccato per sbaglio: dalla tenda si torna alla discussione.
    await tapKey(tester, 'game.usePower');
    await tapSeat(tester, carla);
    await tapKey(tester, 'game.powerConfirm');
    expect(curtainName(tester), '3 CARLA');
    await tapKey(tester, 'local.curtainBack');
    expect(find.byKey(const Key('local.day')), findsOneWidget);

    // Dal voto a voce si torna alla discussione, e ai poteri.
    await tapKey(tester, 'local.toVote');
    await tapKey(tester, 'local.backToTalk');
    expect(find.byKey(const Key('game.usePower')), findsOneWidget);
  });
}

void _voteTests() {
  testWidgets('sulla scheda solo i vivi che si possono condannare, e al massimo dei posti stanno tutti sul telefono piccolo', (tester) async {
    final players = [for (var i = 1; i <= maxRolePlayers; i++) Player(id: 'g$i', name: i == 3 ? 'Massimiliano' : 'Posto$i')];
    await pumpGame(
      tester,
      vote: LocalVote.secret,
      screen: const Size(375, 667),
      deal: {
        for (final (i, player) in players.indexed)
          player: switch (i) {
            0 => Role.mafioso,
            1 => Role.presidente,
            _ => Role.cittadino,
          },
      },
    );
    await tapLabel(tester, 'COMINCIA LA NOTTE');
    await nightTurn(tester, players[0], pick: players[5]);
    for (final player in players.skip(1)) {
      await nightTurn(tester, player);
    }
    await tester.tap(find.text('BUIO IN SALA'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(DeathScene.length + const Duration(milliseconds: 100));
    await tester.pump();
    await tapLabel(tester, 'AVANTI');
    await tapLabel(tester, 'APRI LA DISCUSSIONE');
    await tapKey(tester, 'local.toVote');
    await tapLabel(tester, 'AVANTI');
    expect(tester.takeException(), isNull);

    expect(find.byKey(const Key('ballot-g2')), findsNothing, reason: 'il Presidente non si vota');
    expect(find.byKey(const Key('ballot-g6')), findsNothing, reason: 'i morti non stanno sulla scheda');
    expect(find.byKey(const Key('ballot-g1')), findsNothing, reason: 'chi vota non sta sulla scheda');
    final rows = [
      for (final player in players)
        if (!['g1', 'g2', 'g6'].contains(player.id)) find.byKey(ValueKey('ballot-${player.id}')),
    ];
    expect(rows, hasLength(9));
    final bottom = tester.getTopLeft(find.byKey(const Key('local.abstain'))).dy;
    for (final row in rows) {
      final box = tester.getRect(row);
      expect(box.height, greaterThanOrEqualTo(44), reason: 'si tocca col dito');
      expect(box.left, greaterThanOrEqualTo(0));
      expect(box.right, lessThanOrEqualTo(375));
      expect(box.bottom, lessThan(bottom), reason: 'niente nascosto sotto la striscia');
      expect(row.hitTestable(), findsOneWidget);
    }
    expect(find.byType(Scrollable), findsNothing, reason: 'la scheda non scorre mai');
    await tester.tap(rows.last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('ballot.stamped')), findsOneWidget);
  });

  testWidgets('il timbro parte, batte, e l\'inchiostro resta quando tocca la carta', (tester) async {
    await pumpGame(tester, vote: LocalVote.secret, deal: {ada: Role.mafioso, bruno: Role.cittadino, carla: Role.cittadino, dino: Role.cittadino});
    await tapLabel(tester, 'COMINCIA LA NOTTE');
    for (final player in [ada, bruno, carla, dino]) {
      await nightTurn(tester, player);
    }
    await tapLabel(tester, 'APRI LA DISCUSSIONE');
    await tapKey(tester, 'local.toVote');
    await tapLabel(tester, 'AVANTI');
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures();
    await tester.pump();
    await tester.tap(find.byKey(const Key('ballot-bruno')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.byKey(const Key('ballot.stamped')), findsNothing, reason: 'è ancora in volo');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('ballot.stamped')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.binding.transientCallbackCount, 0, reason: 'finito il timbro, in cabina non si muove più niente');
  });

  testWidgets('al voto a voce il Presidente non si tocca, e il Fesso linciato vince', (tester) async {
    await pumpGame(tester, deal: {
      ada: Role.mafioso,
      bruno: Role.presidente,
      carla: Role.fesso,
      dino: Role.cittadino,
      elio: Role.cittadino,
      fabio: Role.cittadino,
    });
    await tapLabel(tester, 'COMINCIA LA NOTTE');
    for (final player in [ada, bruno, carla, dino, elio, fabio]) {
      await nightTurn(tester, player);
    }
    await tapLabel(tester, 'APRI LA DISCUSSIONE');
    await tapKey(tester, 'local.toVote');
    expect(table(tester).selectable, isNot(contains(bruno)), reason: 'non si lincia lo Stato');
    await voiceVerdict(tester, carla);
    await watchVerdict(tester);
    expect(table(tester).lynched, carla);
    expect(find.byKey(const Key('local.afterVerdict')), findsOneWidget);
    await tapKey(tester, 'local.afterVerdict');
    expect(find.text('NOTTE 2'), findsOneWidget, reason: 'il Fesso vince da solo, e la partita va avanti');
  });

  testWidgets('al voto a voce il crepacuore porta via l\'innamorato del condannato', (tester) async {
    await pumpGame(tester, deal: {ada: Role.mafioso, bruno: Role.cupido, carla: Role.cittadino, dino: Role.cittadino, elio: Role.cittadino, fabio: Role.cittadino});
    await tapLabel(tester, 'COMINCIA LA NOTTE');
    await nightTurn(tester, ada);
    await tapKey(tester, 'local.itsMe');
    await tapSeat(tester, carla);
    await tapKey(tester, 'local.confirm');
    await tapSeat(tester, elio);
    await tapKey(tester, 'local.confirm');
    await tapKey(tester, 'local.done');
    for (final player in [carla, dino, elio, fabio]) {
      await nightTurn(tester, player);
    }
    await _toTheDay(tester);
    await tapKey(tester, 'local.toVote');
    await voiceVerdict(tester, carla);
    await watchVerdict(tester);
    expect(seat(tester, elio).fallen, isTrue, reason: 'il cuore di Elio si spezza');
  });

  testWidgets('il voto segreto: nessuno vede le schede degli altri, alla fine solo il conto', (tester) async {
    await pumpGame(tester, vote: LocalVote.secret, deal: {
      ada: Role.mafioso,
      bruno: Role.cittadino,
      carla: Role.cittadino,
      dino: Role.cittadino,
      elio: Role.cittadino,
    });
    await tapLabel(tester, 'COMINCIA LA NOTTE');
    for (final player in [ada, bruno, carla, dino, elio]) {
      await nightTurn(tester, player);
    }
    await tapLabel(tester, 'APRI LA DISCUSSIONE');
    await tapKey(tester, 'local.toVote');
    // Il richiamo si legge prima: in cabina non c'è posto per il copione.
    expect(find.textContaining('Voto segreto: il telefono passa di mano'), findsOneWidget);
    await tapLabel(tester, 'AVANTI');
    expect(find.text('1 ADA\nDEVE VOTARE', findRichText: true), findsOneWidget);
    expect(find.textContaining('nessuno vede la tua scheda'), findsOneWidget);
    expect(find.text('SCHEDA SEGRETA'), findsOneWidget);
    expect(find.byType(LocalTable), findsNothing, reason: 'il voto segreto è in cabina, non al tavolo');
    expect(find.byKey(const Key('ballot-ada')), findsNothing, reason: 'non si vota se stessi');
    expect(find.byType(PlayerAvatar), findsNWidgets(4), reason: 'ogni nome ha il suo ritratto');
    expect(find.text('Tocca un nome sulla scheda, o astieniti.'), findsOneWidget);
    expect(find.byKey(const Key('local.backToTalk')), findsOneWidget, reason: 'l\'urna è ancora vuota');
    final cast = find.byKey(const Key('local.castVote'));
    expect(tester.widget<NoirModalButton>(cast).action.onPressed, isNull, reason: 'prima si timbra');
    await stampBallot(tester, bruno);
    expect(find.text('Hai segnato 2 Bruno. Mettila nell\'urna o cambia nome.'), findsOneWidget);
    expect(find.byKey(const Key('ballot.stamped')), findsOneWidget);
    await tester.tap(cast);
    await tester.pumpAndSettle();

    // Il secondo votante non vede niente del primo.
    expect(find.text('2 BRUNO\nDEVE VOTARE', findRichText: true), findsOneWidget);
    expect(find.byKey(const Key('ballot.stamped')), findsNothing, reason: 'scheda pulita');
    expect(find.byKey(const Key('ballot-ada')), findsOneWidget);
    expect(find.byKey(const Key('ballot-bruno')), findsNothing);
    expect(find.byKey(const Key('local.backToTalk')), findsNothing, reason: 'una scheda è già nell\'urna');
    expect(find.byKey(const Key('local.undoVote')), findsNothing, reason: 'non si torna alla scheda di un altro');
    expect(find.byType(SeatCard), findsNothing, reason: 'nessun bollo, nessun accusato, nessun pizzino');
    expect(tester.widget<Text>(find.byKey(const Key('strip.count'))).data, '1/5');
    await stampBallot(tester, ada);
    await tapKey(tester, 'local.castVote');
    await secretVote(tester, [carla, dino, elio], {carla: ada, dino: bruno});

    // Pari, due a due: nessuna condanna, e solo i numeri sul tavolo.
    await watchVerdict(tester);
    expect(find.text('Pareggio: oggi non viene condannato nessuno. Si torna alla notte.'), findsOneWidget);
    expect(seat(tester, ada).votes, 2);
    expect(seat(tester, bruno).votes, 2);
    for (final player in [ada, bruno, carla, dino, elio]) {
      expect(seat(tester, player).pizzino, isNull, reason: 'chi ha votato chi resta segreto');
    }
    final tally = tester.widget<TallyScroll>(find.byKey(const Key('local.verdictVotes'))).text;
    expect(tally, allOf(contains('1 Ada: 2 voti'), contains('2 Bruno: 2 voti'), contains('1 astenuto')));
  });
}
