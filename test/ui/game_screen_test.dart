import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/rules/game_setup.dart';
import 'package:oberta/rules/player.dart';
import 'package:oberta/rules/role.dart';
import 'package:oberta/rules/role_assignment.dart';
import 'package:oberta/ui/screens/game_screen.dart';
import 'package:oberta/ui/screens/local/local_table.dart';
import 'package:oberta/ui/screens/online/game/seat_card.dart';
import 'package:oberta/ui/theme/app_theme.dart';
import 'package:oberta/ui/widgets/death_scene.dart';
import 'package:oberta/ui/widgets/verdict_scene.dart';

import '../support/local_game.dart';

const ada = Player(id: 'ada', name: 'Ada');
const bruno = Player(id: 'bruno', name: 'Bruno');
const carla = Player(id: 'carla', name: 'Carla');
const dino = Player(id: 'dino', name: 'Dino');
const elio = Player(id: 'elio', name: 'Elio');
const fabio = Player(id: 'fabio', name: 'Fabio');

final roles = {
  ada: Role.mafioso,
  bruno: Role.detective,
  carla: Role.cittadino,
  dino: Role.cittadino,
};

/// Apre una partita. Senza [deal] si gioca il tavolo da quattro di sempre.
Future<void> pumpGame(
  WidgetTester tester, {
  Player? narrator,
  Map<Player, Role>? deal,
  Size screen = const Size(393, 852),
  Random? seating,
  LocalVote vote = LocalVote.voice,
}) async {
  tester.view.physicalSize = screen * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  // I fondali animati non si fermano mai: nei test si chiede al sistema di
  // ridurre le animazioni, come farebbe un utente dalle impostazioni.
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

  await tester.pumpWidget(MaterialApp(
    theme: buildAppTheme(),
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => GameScreen(
                setup: GameSetup.fromRoles(deal ?? roles, narrator: narrator, vote: vote),
                random: Random(1),
                seating: seating,
              ),
            )),
            child: const Text('GIOCA'),
          ),
        ),
      ),
    ),
  ));
  await tapLabel(tester, 'GIOCA');
}

/// Il verdetto sul tavolo: niente film, il linciaggio si gioca sul posto.
Future<void> watchVerdict(WidgetTester tester) async {
  expect(find.byType(VerdictScene), findsNothing, reason: 'il voto l\'hanno visto tutti: niente film');
  expect(find.byKey(const Key('game.verdict')), findsOneWidget);
  await tester.pumpAndSettle();
}

/// Dal buio in sala all'alba, saltando i film.
Future<void> skipFilms(WidgetTester tester) async {
  await tester.tap(find.text('BUIO IN SALA'));
  await tester.pump(const Duration(milliseconds: 500));
  await tapLabel(tester, 'SALTA');
  await tapLabel(tester, 'AVANTI');
}

LocalTable table(WidgetTester tester) => tester.widget<LocalTable>(find.byType(LocalTable));

SeatCard seat(WidgetTester tester, Player player) => tester.widget<SeatCard>(find.byKey(ValueKey('seat-${player.id}')));

void main() {
  testWidgets('una partita intera: notte, film, alba, discussione, voto a voce, verdetto, fine', (tester) async {
    await pumpGame(tester);
    await tapLabel(tester, 'COMINCIA LA NOTTE');

    await nightTurn(tester, ada, number: 1, pick: carla);

    expect(curtainName(tester), '2 BRUNO');
    await tapKey(tester, 'local.itsMe');
    expect(find.text('Su chi vuoi indagare?'), findsOneWidget);
    await tapSeat(tester, ada);
    expect(find.text('Hai scelto 1 Ada. Conferma, o tocca un altro posto.'), findsOneWidget);
    await tapKey(tester, 'local.confirm');
    expect(find.text('LA TUA INDAGINE'), findsOneWidget);
    expect(find.text('1 ADA'), findsOneWidget);
    expect(find.text('È DELLA FAMIGLIA'), findsOneWidget);
    expect(seat(tester, ada).selected, isTrue, reason: 'il posto scoperto resta acceso');
    await tapKey(tester, 'local.done');

    await nightTurn(tester, carla, number: 3);
    await nightTurn(tester, dino, number: 4);

    // Prima del racconto, il delitto va in scena col telefono sul tavolo.
    expect(find.text('Telefono\nsul tavolo'), findsOneWidget);
    await tester.tap(find.text('BUIO IN SALA'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(DeathScene), findsOneWidget);
    await tester.pump(DeathScene.length + const Duration(milliseconds: 100));
    await tester.pump();
    expect(find.text('CARLA'), findsOneWidget);
    await tapLabel(tester, 'AVANTI');

    expect(find.text('ALBA'), findsOneWidget);
    expect(find.text('Tra i morti di stanotte: Carla. Il suo ruolo resta segreto.'), findsOneWidget);
    expect(find.textContaining('L\'Onesto'), findsNothing, reason: 'di notte il ruolo resta segreto');
    // Il primo giorno il narratore dice dove sono i poteri di giorno.
    while (find.text('Chi ha un potere di giorno lo usa col tasto «Usa un potere».').evaluate().isEmpty &&
        find.text('CONTINUA A LEGGERE').evaluate().isNotEmpty) {
      await tester.tap(find.text('CONTINUA A LEGGERE'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Chi ha un potere di giorno lo usa col tasto «Usa un potere».'), findsOneWidget);
    await tapLabel(tester, 'APRI LA DISCUSSIONE');

    // La discussione: il tavolo di tutti, nell'ordine di sempre, il
    // cronometro nel cartiglio.
    expect(find.text('GIORNO 1'), findsOneWidget);
    expect(find.text('1:00'), findsOneWidget);
    expect(table(tester).seats, [ada, bruno, carla, dino]);
    expect(seat(tester, carla).fallen, isTrue);
    expect(seat(tester, ada).note, isNull, reason: 'l\'indagine non è pubblica');
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('0:58'), findsOneWidget);
    await tapKey(tester, 'local.moreTime');
    expect(find.text('1:58'), findsOneWidget);
    await tapKey(tester, 'local.toVote');

    // Il voto a voce: il tavolo vota ad alta voce, il telefono resta in
    // mezzo e uno tocca il condannato.
    expect(find.textContaining('Votate a voce, tutti insieme.'), findsOneWidget);
    expect(find.text('VOTATE A VOCE'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('local.voiceVoteStatus'))).data, 'Votate a voce. Poi toccate chi condannate.');
    expect(table(tester).selectable, {ada, bruno, dino}, reason: 'i vivi, nessuno escluso: non vota il telefono');
    expect(table(tester).holder, isNull, reason: 'il telefono è di tutti');
    expect(find.byKey(const Key('local.voterTurn')), findsNothing, reason: 'nessun turno: si vota a voce');
    expect(find.text('CONDANNA'), findsOneWidget);
    await tapSeat(tester, dino);
    expect(find.text('Condannate 4 Dino? Conferma, o tocca un altro posto.'), findsOneWidget);
    expect(find.text('CONDANNA 4 DINO'), findsOneWidget);
    // Il tavolo ci ripensa: si tocca un altro posto.
    await tapSeat(tester, ada);
    expect(find.text('CONDANNA 1 ADA'), findsOneWidget);
    await tapKey(tester, 'local.condemn');
    await watchVerdict(tester);

    expect(find.text('IL VERDETTO'), findsOneWidget);
    expect(find.byKey(const Key('lynch.stamp')), findsOneWidget, reason: 'il linciaggio sul posto di Ada');
    expect(find.text('La carta si gira. Ada era… IL PICCIOTTO. Stava con la famiglia.'), findsOneWidget);
    expect(find.byKey(const Key('local.verdictVotes')), findsNothing, reason: 'i voti li ha contati il tavolo');
    expect(seat(tester, ada).votes, 0);
    await tapKey(tester, 'local.afterVerdict');

    expect(find.text('Vincono\ngli onesti'), findsOneWidget);
    expect(find.text('CHI ERA CHI'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('TORNA ALLA HOME'), 200);
    await tester.pumpAndSettle();
    expect(find.text('Notte 1'), findsOneWidget);
    expect(find.text('Patibolo, giorno 1'), findsOneWidget);
    await tapLabel(tester, 'TORNA ALLA HOME');
    expect(find.text('GIOCA'), findsOneWidget);
  });

  testWidgets('a ogni passaggio di mano i posti si rimescolano; numeri e nomi restano giusti', (tester) async {
    final players = [ada, bruno, carla, dino, elio, fabio];
    await pumpGame(tester, deal: {
      ada: Role.mafioso,
      bruno: Role.detective,
      carla: Role.medico,
      dino: Role.cittadino,
      elio: Role.cittadino,
      fabio: Role.cittadino,
    });
    await tapLabel(tester, 'COMINCIA LA NOTTE');

    final hands = <List<({String name, int? number})>>[];
    for (final (i, player) in players.indexed) {
      expect(curtainName(tester), '${i + 1} ${player.name.toUpperCase()}');
      await tapKey(tester, 'local.itsMe');
      final seen = tableOnScreen(tester);
      hands.add(seen);
      // Il posto cambia, il numero no: ognuno porta il suo.
      expect(seen.length, players.length);
      expect({for (final s in seen) s.name}, {for (final p in players) p.name});
      for (final s in seen) {
        expect(s.number, players.indexWhere((p) => p.name == s.name) + 1, reason: s.name);
      }
      expect(seen.first.name, player.name, reason: 'chi ha il telefono sta in basso');
      await tapKey(tester, 'local.pass');
      await tapKey(tester, 'local.done');
    }
    // Da una mano all'altra il giro degli altri cambia: le stesse persone
    // non tornano allo stesso posto rispetto a chi guarda.
    for (var i = 1; i < hands.length; i++) {
      final before = [for (final s in hands[i - 1]) s.name];
      final now = [for (final s in hands[i]) s.name];
      final start = before.indexOf(now.first);
      final rotated = [...before.skip(start), ...before.take(start)];
      expect(now, isNot(rotated), reason: 'mano $i');
      expect(now, isNot(before), reason: 'mano $i');
    }

    // Di giorno il tavolo è di tutti: l'ordine di sempre.
    await tapLabel(tester, 'APRI LA DISCUSSIONE');
    expect(table(tester).seats, players);
    expect([for (final p in players) seat(tester, p).number], [1, 2, 3, 4, 5, 6]);
  });

  testWidgets('di notte ognuno vede sul tavolo solo quello che sa', (tester) async {
    await pumpGame(tester);
    await tapLabel(tester, 'COMINCIA LA NOTTE');

    await tapKey(tester, 'local.itsMe');
    expect(find.text('Chi eliminate stanotte?'), findsOneWidget);
    expect(table(tester).selectable, isNot(contains(ada)), reason: 'non può colpire se stessa');
    await tapSeat(tester, ada);
    expect(table(tester).selected, isNull);
    await tapSeat(tester, carla);
    await tapKey(tester, 'local.confirm');
    await tapKey(tester, 'local.done');

    await nightTurn(tester, bruno, pick: ada);
    await nightTurn(tester, carla);
    await nightTurn(tester, dino);
    await skipFilms(tester);
    await tapLabel(tester, 'APRI LA DISCUSSIONE');
    await tapKey(tester, 'local.toVote');
    // Pari: nessuna condanna, si torna alla notte.
    await voiceVerdict(tester, null);
    await watchVerdict(tester);
    expect(find.text('Nessuna condanna'), findsWidgets);
    expect(find.text('Pareggio: oggi non viene condannato nessuno. Si torna alla notte.'), findsOneWidget);
    await tapKey(tester, 'local.afterVerdict');

    expect(find.text('NOTTE 2'), findsOneWidget);
    await tapLabel(tester, 'COMINCIA LA NOTTE');
    await nightTurn(tester, ada);

    expect(curtainName(tester), '2 BRUNO');
    await tapKey(tester, 'local.itsMe');
    expect(seat(tester, ada).note, 'famiglia', reason: 'il Commissario ricorda la sua indagine');
    expect(table(tester).selectable, {ada, dino}, reason: 'i morti e se stessi non si scelgono');
  });

  testWidgets('il Becchino scava nella fossa di chi è morto di notte e vede chi era', (tester) async {
    await pumpGame(tester, deal: {
      ada: Role.mafioso,
      bruno: Role.becchino,
      carla: Role.cittadino,
      dino: Role.cittadino,
      elio: Role.cittadino,
    });
    await tapLabel(tester, 'COMINCIA LA NOTTE');
    await nightTurn(tester, ada, pick: carla);

    // Prima notte: nessun morto, quindi una domanda di copertura come gli altri.
    await tapKey(tester, 'local.itsMe');
    expect(find.text('Quale fossa scavi stanotte?'), findsNothing);
    expect(find.textContaining('Non hai mosse'), findsOneWidget);
    await tapKey(tester, 'local.pass');
    await tapKey(tester, 'local.done');
    for (final player in [carla, dino, elio]) {
      await nightTurn(tester, player);
    }
    await skipFilms(tester);
    await tapLabel(tester, 'APRI LA DISCUSSIONE');
    await tapKey(tester, 'local.toVote');
    await voiceVerdict(tester, null);
    await watchVerdict(tester);
    await tapKey(tester, 'local.afterVerdict');

    await tapLabel(tester, 'COMINCIA LA NOTTE');
    await nightTurn(tester, ada);
    await tapKey(tester, 'local.itsMe');
    expect(find.text('Quale fossa scavi stanotte?'), findsOneWidget);
    expect(find.textContaining('scopri subito, solo tu'), findsOneWidget);
    expect(table(tester).selectable, {carla}, reason: 'si scava solo dove c\'è una croce');
    await tapSeat(tester, dino);
    expect(table(tester).selected, isNull, reason: 'i vivi non si riesumano');
    await tapSeat(tester, carla);
    await tapKey(tester, 'local.confirm');

    expect(find.text('NELLA FOSSA'), findsOneWidget);
    expect(find.text('LA TUA INDAGINE'), findsNothing);
    expect(find.text('3 CARLA'), findsOneWidget);
    expect(find.text('ERA L\'ONESTO'), findsOneWidget);
    expect(find.text('STAVA CON GLI ONESTI'), findsOneWidget);
    expect(seat(tester, carla).role, Role.cittadino);
    await tapKey(tester, 'local.done');

    for (final player in [dino, elio]) {
      await nightTurn(tester, player);
    }
    expect(find.text('Tutti vivi'), findsOneWidget);
    await tapLabel(tester, 'APRI LA DISCUSSIONE');
    expect(seat(tester, carla).role, isNull, reason: 'quello che ha scoperto non è pubblico');
  });

  testWidgets('il Reduce incassa il primo colpo: va in scena un agguato che va a vuoto, e resta in gioco', (tester) async {
    await pumpGame(tester, deal: {
      ada: Role.mafioso,
      bruno: Role.reduce,
      carla: Role.cittadino,
      dino: Role.cittadino,
    });
    await tapLabel(tester, 'COMINCIA LA NOTTE');

    await nightTurn(tester, ada, pick: bruno);
    await tapKey(tester, 'local.itsMe');
    expect(find.textContaining('Non hai mosse'), findsOneWidget, reason: 'il Reduce di notte non agisce');
    await tapKey(tester, 'local.pass');
    await tapKey(tester, 'local.done');
    for (final player in [carla, dino]) {
      await nightTurn(tester, player);
    }

    await tester.tap(find.text('BUIO IN SALA'));
    await tester.pump(const Duration(milliseconds: 500));
    final scene = tester.widget<DeathScene>(find.byType(DeathScene));
    expect(scene.save?.luckyEscape, isTrue, reason: 'lo manda a vuoto un colpo di fortuna');
    await tapLabel(tester, 'SALTA');
    expect(find.text('QUALCUNO'), findsOneWidget);
    await tapLabel(tester, 'AVANTI');

    expect(find.text('Tutti vivi'), findsOneWidget);
    expect(find.textContaining('Reduce'), findsNothing, reason: 'il tavolo non deve sapere perché');
    await tapLabel(tester, 'APRI LA DISCUSSIONE');
    expect(seat(tester, bruno).fallen, isFalse);
  });

  testWidgets('il Sarto cuce una bocca, e il Padrino inganna il Commissario', (tester) async {
    await pumpGame(tester, deal: {
      ada: Role.padrino,
      bruno: Role.sarto,
      carla: Role.detective,
      dino: Role.cittadino,
      elio: Role.cittadino,
      fabio: Role.cittadino,
    });
    await tapLabel(tester, 'COMINCIA LA NOTTE');

    await tapKey(tester, 'local.itsMe');
    expect(find.text('Chi eliminate stanotte?'), findsOneWidget);
    expect(seat(tester, bruno).role, Role.sarto, reason: 'la famiglia si riconosce');
    expect(seat(tester, ada).role, isNull, reason: 'il proprio posto non mostra la carta');
    await tapSeat(tester, dino);
    await tapKey(tester, 'local.confirm');
    await tapKey(tester, 'local.done');

    expect(curtainName(tester), '2 BRUNO');
    await tapKey(tester, 'local.itsMe');
    expect(find.text('Chi eliminate stanotte?'), findsOneWidget, reason: 'il Sarto vota l\'agguato');
    expect(seat(tester, ada).pizzino, '4', reason: 'la famiglia vede dove punta il complice');
    await tapLabel(tester, 'CUCI UNA BOCCA');
    expect(find.text('A chi cuci la bocca stanotte?'), findsOneWidget);
    expect(find.textContaining('domani non potrà parlare'), findsOneWidget);
    await tapSeat(tester, elio);
    await tapKey(tester, 'local.confirm');
    expect(find.text('Nessuno saprà cosa hai scelto.'), findsOneWidget);
    await tapKey(tester, 'local.done');

    await tapKey(tester, 'local.itsMe');
    await tapSeat(tester, ada);
    await tapKey(tester, 'local.confirm');
    expect(find.text('LA TUA INDAGINE'), findsOneWidget);
    expect(find.text('È INNOCENTE'), findsOneWidget, reason: 'il Padrino ha le carte in regola');
    expect(find.text('È DELLA FAMIGLIA'), findsNothing);
    await tapKey(tester, 'local.done');

    for (final player in [dino, elio, fabio]) {
      await nightTurn(tester, player);
    }
    await skipFilms(tester);
    expect(find.text('Tra i morti di stanotte: Dino. Il suo ruolo resta segreto.'), findsOneWidget);
    await tapLabel(tester, 'APRI LA DISCUSSIONE');

    expect(seat(tester, elio).note, 'zittito', reason: 'il tavolo vede chi deve tacere');
    await tapKey(tester, 'local.toVote');
    expect(seat(tester, elio).note, 'zittito');
    expect(table(tester).selectable, contains(elio), reason: 'chi tace si può comunque condannare');
    await voiceVerdict(tester, null);
    await watchVerdict(tester);
    await tapKey(tester, 'local.afterVerdict');

    await tapLabel(tester, 'COMINCIA LA NOTTE');
    await nightTurn(tester, ada);
    await tapKey(tester, 'local.itsMe');
    expect(seat(tester, elio).note, isNull, reason: 'il silenzio dura un giorno');
    expect(find.byKey(const Key('task.alternative')), findsNothing, reason: 'il silenzio è uno per partita');
  });

  testWidgets('il Sindaco si rivela con «Usa un potere»: porta la carta, e il panno ricorda che vale doppio', (tester) async {
    await pumpGame(tester, deal: {
      ada: Role.mafioso,
      bruno: Role.sindaco,
      carla: Role.cittadino,
      dino: Role.cittadino,
      elio: Role.cittadino,
    });
    await tapLabel(tester, 'COMINCIA LA NOTTE');
    for (final player in [ada, bruno, carla, dino, elio]) {
      await nightTurn(tester, player);
    }
    await tapLabel(tester, 'APRI LA DISCUSSIONE');

    // Ada prova: dietro la tenda non trova niente, come chiunque non abbia un potere.
    await openPower(tester, ada);
    expect(find.text('Adesso non hai niente da usare.'), findsWidgets);
    expect(find.byKey(const Key('game.powerUse')), findsNothing);
    await tapKey(tester, 'game.powerBack');
    expect(find.byKey(const Key('local.day')), findsOneWidget);

    await openPower(tester, bruno);
    expect(find.text('IL SINDACO'), findsOneWidget);
    expect(find.text('Una volta a partita: ti riveli a tutti, e oggi il tuo voto vale doppio.'), findsOneWidget);
    await tapKey(tester, 'game.powerUse');
    expect(find.byKey(const Key('local.day')), findsOneWidget, reason: 'si torna alla discussione');
    expect(seat(tester, bruno).role, Role.sindaco, reason: 'il suo posto porta la carta, per sempre');
    expect(find.text('2 Bruno è il Sindaco: oggi il suo voto vale doppio.'), findsOneWidget);

    // Una volta per partita: al secondo giro dietro la tenda non c'è più niente.
    await openPower(tester, bruno);
    expect(find.text('Adesso non hai niente da usare.'), findsWidgets);
    await tapKey(tester, 'game.powerBack');

    // Al voto a voce il panno lo ricorda: il doppio lo conta il tavolo.
    await tapKey(tester, 'local.toVote');
    expect(find.text('2 Bruno è il Sindaco: oggi il suo voto vale doppio.'), findsOneWidget);
    await voiceVerdict(tester, ada);
    await watchVerdict(tester);
    expect(find.byKey(const Key('lynch.stamp')), findsOneWidget);
  });

  testWidgets('al voto segreto il Sindaco rivelato vale doppio nel conto', (tester) async {
    await pumpGame(tester, vote: LocalVote.secret, deal: {
      ada: Role.mafioso,
      bruno: Role.sindaco,
      carla: Role.cittadino,
      dino: Role.cittadino,
      elio: Role.cittadino,
    });
    await tapLabel(tester, 'COMINCIA LA NOTTE');
    for (final player in [ada, bruno, carla, dino, elio]) {
      await nightTurn(tester, player);
    }
    await tapLabel(tester, 'APRI LA DISCUSSIONE');
    await openPower(tester, bruno);
    await tapKey(tester, 'game.powerUse');
    await tapKey(tester, 'local.toVote');
    await secretVote(tester, [ada, bruno, carla, dino, elio], {ada: carla, bruno: ada});
    await watchVerdict(tester);
    expect(find.byKey(const Key('lynch.stamp')), findsOneWidget, reason: 'due voti contro uno: Ada');
    expect(seat(tester, ada).votes, 2, reason: 'il voto del Sindaco vale doppio');
    expect(seat(tester, carla).votes, 1);
    expect(find.text('1 Ada: 2 voti  ·  3 Carla: 1 voto  ·  3 astenuti'), findsOneWidget);
  });

  testWidgets('a fine partita la famiglia è in rosso, qualunque ruolo avesse', (tester) async {
    await pumpGame(tester, deal: {
      ada: Role.padrino,
      bruno: Role.pregiudicato,
      carla: Role.cittadino,
    });
    await tapLabel(tester, 'COMINCIA LA NOTTE');
    await nightTurn(tester, ada, pick: carla);
    await nightTurn(tester, bruno);
    await nightTurn(tester, carla);
    await skipFilms(tester);
    await tapLabel(tester, 'FINALE');

    expect(find.text('Vince\nla famiglia'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('TORNA ALLA HOME'), 200);
    await tester.pumpAndSettle();
    const red = Color(0xFFE5606A);
    expect(tester.widget<Text>(find.text('Il Padrino')).style!.color, red);
    expect(tester.widget<Text>(find.text('Il Pregiudicato')).style!.color, isNot(red),
        reason: 'la fedina è sporca, ma stava con gli onesti');
    expect(tester.widget<Text>(find.text('L\'Onesto')).style!.color, isNot(red));
  });

  testWidgets('un tavolo da sedici fa il giro della notte e arriva all\'alba', (tester) async {
    final players = [for (var i = 1; i <= maxRolePlayers; i++) Player(id: 'g$i', name: 'Posto$i')];
    await pumpGame(tester, deal: Map.fromIterables(players, rolesForPlayerCount(players.length)));
    await tapLabel(tester, 'COMINCIA LA NOTTE');

    for (final (i, player) in players.indexed) {
      expect(curtainName(tester), '${i + 1} ${player.name.toUpperCase()}');
      await tapKey(tester, 'local.itsMe');
      expect(tester.takeException(), isNull, reason: player.name);
      expect(table(tester).seats, hasLength(maxRolePlayers));
      await tapKey(tester, 'local.pass');
      await tapKey(tester, 'local.done');
    }

    expect(find.text('Tutti vivi'), findsOneWidget);
    await tapLabel(tester, 'APRI LA DISCUSSIONE');
    expect(tester.takeException(), isNull);
    expect(table(tester).seats, hasLength(maxRolePlayers));
  });

  testWidgets('ogni ruolo del telefono solo ha la sua domanda e i suoi posti, dal compito del motore', (tester) async {
    // Un ruolo nuovo nelle regole arriva qui da solo: lo schermo chiede al
    // motore il compito, la domanda e chi si può scegliere.
    final night = [
      for (final role in Role.values)
        if (role.playableIn(PlayMode.sharedPhone) && role != Role.mafioso && role.team != Team.mafia) role,
    ];
    for (final role in night) {
      await pumpGame(tester, deal: {ada: role, bruno: Role.mafioso, carla: Role.cittadino, dino: Role.cittadino, elio: Role.cittadino});
      await tapLabel(tester, 'COMINCIA LA NOTTE');
      await tapKey(tester, 'local.itsMe');
      expect(tester.takeException(), isNull, reason: role.name);
      final prompt = tester.widget<Text>(find.byKey(const Key('local.taskPrompt')));
      expect(prompt.data, isNotEmpty, reason: role.name);
      expect(table(tester).seats, hasLength(5), reason: role.name);
      await tapKey(tester, 'local.pass');
      await tapKey(tester, 'local.done');
      expect(curtainName(tester), '2 BRUNO', reason: role.name);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('con il narratore umano il telefono torna a lui per l\'alba', (tester) async {
    await pumpGame(tester, narrator: elio);

    expect(find.text('LEGGE ELIO, AD ALTA VOCE'), findsOneWidget);
    await tapLabel(tester, 'COMINCIA LA NOTTE');
    expect(find.byIcon(Icons.visibility), findsNothing, reason: 'di notte il telefono non è del narratore');

    for (final player in [ada, bruno, carla, dino]) {
      await nightTurn(tester, player);
    }

    expect(curtainName(tester), 'ELIO', reason: 'il narratore non ha un posto al tavolo');
    await tapKey(tester, 'local.itsMe');
    expect(find.text('Tutti vivi'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.visibility));
    await tester.pumpAndSettle();
    expect(find.text('SOLO PER IL NARRATORE'), findsOneWidget);
    expect(find.text('Il Picciotto'), findsNothing);

    final hold = await tester.startGesture(tester.getCenter(find.text('SOLO PER IL NARRATORE')));
    await tester.pumpAndSettle();
    expect(find.text('Il Picciotto'), findsOneWidget);
    expect(find.text('Il Commissario'), findsOneWidget);
    await hold.up();
    await tester.pumpAndSettle();
    expect(find.text('Il Picciotto'), findsNothing);
  });

  testWidgets('su uno schermo piccolo il copione si legge fino in fondo prima di proseguire', (tester) async {
    await pumpGame(tester, screen: const Size(320, 568));

    expect(find.text('COMINCIA LA NOTTE'), findsNothing);
    var pages = 0;
    while (find.text('CONTINUA A LEGGERE').evaluate().isNotEmpty) {
      expect(pages++, lessThan(10));
      await tester.tap(find.text('CONTINUA A LEGGERE'));
      await tester.pumpAndSettle();
    }
    expect(pages, greaterThan(0));
    expect(find.text('COMINCIA LA NOTTE'), findsOneWidget);
    expect(find.textContaining('Passatevi il telefono.').hitTestable(), findsOneWidget, reason: 'l\'istruzione finale è in vista');
  });

  testWidgets('su uno schermo piccolo il tavolo e la tenda stanno interi', (tester) async {
    await pumpGame(tester, screen: const Size(320, 568));
    await tapLabel(tester, 'COMINCIA LA NOTTE');
    expect(tester.takeException(), isNull);
    await tapKey(tester, 'local.itsMe');
    expect(tester.takeException(), isNull);
    expect(find.byType(LocalTable), findsOneWidget);
  });

  testWidgets('uscire dalla partita chiede conferma', (tester) async {
    await pumpGame(tester);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text('Abbandonare la partita?'), findsOneWidget);
    await tapLabel(tester, 'RESTA');
    expect(find.text('NOTTE 1'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    await tapLabel(tester, 'ESCI');
    expect(find.text('GIOCA'), findsOneWidget);
  });
}
