import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/rules/game_setup.dart';
import 'package:oberta/rules/player.dart';
import 'package:oberta/rules/role.dart';
import 'package:oberta/rules/role_assignment.dart';
import 'package:oberta/ui/screens/game_screen.dart';
import 'package:oberta/ui/theme/app_theme.dart';
import 'package:oberta/ui/theme/role_style.dart';
import 'package:oberta/ui/widgets/death_scene.dart';
import 'package:oberta/ui/widgets/verdict_scene.dart';
import 'package:oberta/ui/widgets/player_grid.dart';

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
                setup: GameSetup.fromRoles(deal ?? roles, narrator: narrator),
                random: Random(1),
              ),
            )),
            child: const Text('GIOCA'),
          ),
        ),
      ),
    ),
  ));
  await tap(tester, 'GIOCA');
}

/// Il filmato della piazza: lo si salta fino al ritratto, poi avanti.
Future<void> watchVerdict(WidgetTester tester, {String skip = 'SALTA', String next = 'AVANTI'}) async {
  expect(find.byType(VerdictScene), findsOneWidget, reason: 'prima della carta va in scena la piazza');
  if (find.text(skip).evaluate().isNotEmpty) {
    await tester.tap(find.text(skip));
    await tester.pump();
  }
  await tester.tap(find.text(next));
  await tester.pumpAndSettle();
}

/// Tocca un pulsante; se il copione è più lungo dello schermo, prima lo
/// legge fino in fondo come farebbe il narratore.
Future<void> tap(WidgetTester tester, String label) async {
  while (find.text(label).evaluate().isEmpty &&
      find.text('CONTINUA A LEGGERE').evaluate().isNotEmpty) {
    await tester.tap(find.text('CONTINUA A LEGGERE'));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

/// Un turno di notte: prende il telefono, sceglie (o passa) e lo posa.
Future<void> nightTurn(WidgetTester tester, Player actor, {Player? pick}) async {
  expect(find.text(actor.name.toUpperCase()), findsOneWidget, reason: 'tocca a ${actor.name}');
  await tap(tester, 'SONO IO');
  if (pick == null) {
    await tap(tester, 'PASSO');
  } else {
    await tap(tester, pick.name);
    await tap(tester, 'CONFERMA');
  }
}

void main() {
  testWidgets('una partita intera: la mafia uccide, la piazza la scopre', (tester) async {
    await pumpGame(tester);

    expect(find.text('NOTTE 1'), findsOneWidget);
    expect(find.text('CALA LA NOTTE'), findsOneWidget);
    expect(find.text('LEGGETE AD ALTA VOCE'), findsOneWidget);
    expect(find.textContaining(RegExp(r'^(Chicago|New York|Palermo|Napoli|Las Vegas), 19\d\d$')), findsOneWidget);
    expect(find.textContaining('Di notte la famiglia elimina una persona.'), findsOneWidget);
    expect(find.textContaining('Passatevi il telefono.'), findsOneWidget);
    await tap(tester, 'COMINCIA LA NOTTE');

    await nightTurn(tester, ada, pick: carla);
    expect(find.text('Fatto.'), findsOneWidget);
    await tap(tester, 'FATTO');

    await nightTurn(tester, bruno, pick: ada);
    expect(find.text('LA TUA INDAGINE'), findsOneWidget);
    expect(find.text('ADA'), findsOneWidget);
    expect(find.text('È DELLA FAMIGLIA'), findsOneWidget);
    await tap(tester, 'FATTO');

    await nightTurn(tester, carla);
    await tap(tester, 'FATTO');
    await nightTurn(tester, dino);
    await tap(tester, 'FATTO');

    // Prima del racconto, il delitto va in scena col telefono sul tavolo.
    expect(find.text('Telefono\nsul tavolo'), findsOneWidget);
    await tester.tap(find.text('BUIO IN SALA'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(DeathScene), findsOneWidget);
    expect(find.text('CARLA'), findsNothing, reason: 'il nome arriva solo alla fine della scena');
    await tester.pump(DeathScene.length + const Duration(milliseconds: 100));
    await tester.pump();
    expect(find.text('CARLA'), findsOneWidget);
    expect(find.byType(DeathScene), findsOneWidget, reason: 'la scena aspetta che il tavolo vada avanti');
    await tap(tester, 'AVANTI');
    expect(find.byType(DeathScene), findsNothing);

    expect(find.text('ALBA'), findsOneWidget);
    expect(find.text('Cronaca nera'), findsOneWidget);
    expect(find.text('Stanotte è morta una persona: Carla. Il suo ruolo resta segreto.'), findsOneWidget);
    expect(find.textContaining('notte.'), findsWidgets, reason: 'la morte è raccontata come una scena');
    expect(find.textContaining('L\'Onesto'), findsNothing, reason: 'di notte il ruolo resta segreto');
    expect(find.text('Avete 3 minuti per discutere. Poi votate chi eliminare.'), findsOneWidget);
    await tap(tester, 'APRI LA DISCUSSIONE');

    expect(find.text('GIORNO 1'), findsOneWidget);
    expect(find.text('3:00'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('2:58'), findsOneWidget);
    await tester.tap(find.text('+1 MIN'));
    await tester.pump();
    expect(find.text('3:58'), findsOneWidget);
    await tap(tester, 'AL VOTO');

    expect(find.textContaining('Potete anche non eliminare nessuno.'), findsOneWidget);
    final condemn = find.widgetWithText(ElevatedButton, 'CONDANNA');
    expect(tester.widget<ElevatedButton>(condemn).onPressed, isNull);
    await tap(tester, 'Ada');
    await tap(tester, 'CONDANNA');
    await watchVerdict(tester);

    expect(find.text('IL VERDETTO'), findsOneWidget);
    expect(find.textContaining('PICCIOTTO'), findsNothing, reason: 'la carta è ancora coperta');
    expect(find.text('FINALE'), findsNothing);
    await tap(tester, 'GIRA LA CARTA');
    expect(find.text('IL PICCIOTTO'), findsOneWidget);
    expect(find.text('La carta si gira. Ada era… IL PICCIOTTO. Stava con la famiglia.'), findsOneWidget);
    await tap(tester, 'FINALE');

    expect(find.text('Vincono\ngli onesti'), findsOneWidget);
    expect(find.text('Vincono gli onesti: tutta la famiglia è stata eliminata.'), findsOneWidget);
    expect(find.text('CHI ERA CHI'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('TORNA ALLA HOME'), 200);
    await tester.ensureVisible(find.text('TORNA ALLA HOME'));
    await tester.pumpAndSettle();
    expect(find.text('Notte 1'), findsOneWidget);
    expect(find.text('Patibolo, giorno 1'), findsOneWidget);
    await tap(tester, 'TORNA ALLA HOME');
    expect(find.text('GIOCA'), findsOneWidget);
  });

  testWidgets('di notte ognuno vede sulla griglia solo quello che sa', (tester) async {
    await pumpGame(tester);
    await tap(tester, 'COMINCIA LA NOTTE');

    await tap(tester, 'SONO IO');
    expect(find.text('Chi eliminate stanotte?'), findsOneWidget);
    expect(find.text('TU'), findsOneWidget);
    expect(find.text('FAMIGLIA'), findsNothing);

    await tap(tester, 'Ada');
    final confirm = find.widgetWithText(ElevatedButton, 'CONFERMA');
    expect(tester.widget<ElevatedButton>(confirm).onPressed, isNull, reason: 'non può colpire se stessa');
    await tap(tester, 'Carla');
    await tap(tester, 'CONFERMA');
    await tap(tester, 'FATTO');

    await nightTurn(tester, bruno, pick: ada);
    await tap(tester, 'FATTO');
    await nightTurn(tester, carla);
    await tap(tester, 'FATTO');
    await nightTurn(tester, dino);
    await tap(tester, 'FATTO');
    await tester.tap(find.text('BUIO IN SALA'));
    await tester.pump(const Duration(milliseconds: 500));
    await tap(tester, 'SALTA');
    await tap(tester, 'AVANTI');
    await tap(tester, 'APRI LA DISCUSSIONE');

    expect(find.text('FAMIGLIA'), findsNothing, reason: 'l\'indagine non è pubblica');
    expect(find.text('†'), findsOneWidget);
    await tap(tester, 'AL VOTO');
    await tap(tester, 'NESSUNO');
    await watchVerdict(tester);
    expect(find.text('Nessuna condanna'), findsOneWidget);
    expect(find.text('Oggi non viene eliminato nessuno.'), findsOneWidget);
    await tap(tester, 'CONTINUA');

    expect(find.text('NOTTE 2'), findsOneWidget);
    await tap(tester, 'COMINCIA LA NOTTE');
    await nightTurn(tester, ada);
    await tap(tester, 'FATTO');

    expect(find.text('BRUNO'), findsOneWidget);
    await tap(tester, 'SONO IO');
    expect(find.text('FAMIGLIA'), findsOneWidget, reason: 'il Commissario ricorda la sua indagine');
    final grid = tester.widget<PlayerGrid>(find.byType(PlayerGrid));
    expect(grid.selectable, [ada, dino], reason: 'i morti e se stessi non si scelgono');
  });

  testWidgets('il Becchino scava nella fossa di chi è morto di notte e vede chi era', (tester) async {
    await pumpGame(tester, deal: {
      ada: Role.mafioso,
      bruno: Role.becchino,
      carla: Role.cittadino,
      dino: Role.cittadino,
      elio: Role.cittadino,
    });
    await tap(tester, 'COMINCIA LA NOTTE');

    await nightTurn(tester, ada, pick: carla);
    await tap(tester, 'FATTO');

    // Prima notte: nessun morto, quindi una domanda di copertura come gli altri.
    await tap(tester, 'SONO IO');
    expect(find.text('Quale fossa scavi stanotte?'), findsNothing);
    expect(find.textContaining('Stanotte non hai una mossa'), findsOneWidget);
    await tap(tester, 'PASSO');
    await tap(tester, 'FATTO');
    for (final player in [carla, dino, elio]) {
      await nightTurn(tester, player);
      await tap(tester, 'FATTO');
    }
    await tester.tap(find.text('BUIO IN SALA'));
    await tester.pump(const Duration(milliseconds: 500));
    await tap(tester, 'SALTA');
    await tap(tester, 'AVANTI');
    await tap(tester, 'APRI LA DISCUSSIONE');
    await tap(tester, 'AL VOTO');
    await tap(tester, 'NESSUNO');
    await watchVerdict(tester);
    await tap(tester, 'CONTINUA');

    await tap(tester, 'COMINCIA LA NOTTE');
    await nightTurn(tester, ada);
    await tap(tester, 'FATTO');

    expect(find.text('BRUNO'), findsOneWidget);
    await tap(tester, 'SONO IO');
    expect(find.text('Quale fossa scavi stanotte?'), findsOneWidget);
    expect(find.textContaining('scoprirai subito, solo tu'), findsOneWidget);
    var grid = tester.widget<PlayerGrid>(find.byType(PlayerGrid));
    expect(grid.selectable, [carla], reason: 'si scava solo dove c\'è una croce');

    final confirm = find.widgetWithText(ElevatedButton, 'CONFERMA');
    await tap(tester, 'Dino');
    expect(tester.widget<ElevatedButton>(confirm).onPressed, isNull, reason: 'i vivi non si riesumano');
    await tap(tester, 'Carla');
    expect(tester.widget<ElevatedButton>(confirm).onPressed, isNotNull);
    await tap(tester, 'CONFERMA');

    expect(find.text('NELLA FOSSA'), findsOneWidget);
    expect(find.text('LA TUA INDAGINE'), findsNothing);
    expect(find.text('CARLA'), findsOneWidget);
    expect(find.text('ERA L\'ONESTO'), findsOneWidget);
    expect(find.text('STAVA CON GLI ONESTI'), findsOneWidget);
    expect(find.byIcon(Role.cittadino.icon), findsOneWidget);
    await tap(tester, 'FATTO');

    for (final player in [dino, elio]) {
      await nightTurn(tester, player);
      await tap(tester, 'FATTO');
    }
    expect(find.text('Tutti vivi'), findsOneWidget);
    await tap(tester, 'APRI LA DISCUSSIONE');
    expect(find.byIcon(Role.cittadino.icon), findsNothing, reason: 'quello che ha scoperto non è pubblico');
    await tap(tester, 'AL VOTO');
    await tap(tester, 'NESSUNO');
    await watchVerdict(tester);
    await tap(tester, 'CONTINUA');

    await tap(tester, 'COMINCIA LA NOTTE');
    await nightTurn(tester, ada);
    await tap(tester, 'FATTO');
    await tap(tester, 'SONO IO');
    expect(find.textContaining('Stanotte non hai una mossa'), findsOneWidget, reason: 'le fosse sono finite');
    grid = tester.widget<PlayerGrid>(find.byType(PlayerGrid));
    expect(grid.knowledgeOf(carla).role, Role.cittadino, reason: 'il Becchino ricorda cosa ha trovato');
    expect(find.byIcon(Role.cittadino.icon), findsOneWidget);
    expect(find.byIcon(Role.becchino.icon), findsOneWidget);
  });

  testWidgets('il Reduce incassa il primo colpo: va in scena la fiaschetta, e resta in gioco', (tester) async {
    await pumpGame(tester, deal: {
      ada: Role.mafioso,
      bruno: Role.reduce,
      carla: Role.cittadino,
      dino: Role.cittadino,
    });
    await tap(tester, 'COMINCIA LA NOTTE');

    await nightTurn(tester, ada, pick: bruno);
    await tap(tester, 'FATTO');
    await tap(tester, 'SONO IO');
    expect(find.textContaining('Stanotte non hai una mossa'), findsOneWidget, reason: 'il Reduce di notte non agisce');
    await tap(tester, 'PASSO');
    await tap(tester, 'FATTO');
    for (final player in [carla, dino]) {
      await nightTurn(tester, player);
      await tap(tester, 'FATTO');
    }

    expect(find.text('Telefono\nsul tavolo'), findsOneWidget);
    await tester.tap(find.text('BUIO IN SALA'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.widget<DeathScene>(find.byType(DeathScene)).act, DeathAct.lucky);
    await tap(tester, 'SALTA');
    expect(find.text('BRUNO'), findsNothing, reason: 'chi si salva resta anonimo');
    expect(find.text('QUALCUNO'), findsOneWidget);
    expect(find.text('VEDRÀ L\'ALBA'), findsOneWidget);
    await tap(tester, 'AVANTI');

    expect(find.text('Tutti vivi'), findsOneWidget);
    expect(
      find.text('Stanotte hanno sparato a qualcuno, ma il colpo è andato a vuoto. Chi fosse, resta un segreto.'),
      findsOneWidget,
    );
    expect(find.textContaining('fiaschetta'), findsOneWidget);
    expect(find.textContaining('Reduce'), findsNothing, reason: 'il tavolo non deve sapere perché');
    expect(find.text('Stanotte non è morto nessuno.'), findsNothing, reason: 'l\'agguato c\'è stato');
    await tap(tester, 'APRI LA DISCUSSIONE');
    expect(find.text('†'), findsNothing);
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
    await tap(tester, 'COMINCIA LA NOTTE');

    await tap(tester, 'SONO IO');
    expect(find.text('Chi eliminate stanotte?'), findsOneWidget);
    expect(find.byIcon(Role.padrino.icon), findsOneWidget);
    expect(find.byIcon(Role.sarto.icon), findsOneWidget, reason: 'la famiglia si riconosce');
    await tap(tester, 'Dino');
    await tap(tester, 'CONFERMA');
    await tap(tester, 'FATTO');

    expect(find.text('BRUNO'), findsOneWidget);
    await tap(tester, 'SONO IO');
    expect(find.text('A chi cuci la bocca stanotte?'), findsOneWidget);
    expect(find.textContaining('domani non potrà parlare'), findsOneWidget);
    await tap(tester, 'Elio');
    await tap(tester, 'CONFERMA');
    expect(find.text('Fatto.'), findsOneWidget);
    await tap(tester, 'FATTO');

    await nightTurn(tester, carla, pick: ada);
    expect(find.text('LA TUA INDAGINE'), findsOneWidget);
    expect(find.text('ADA'), findsOneWidget);
    expect(find.text('È INNOCENTE'), findsOneWidget, reason: 'il Padrino ha le carte in regola');
    expect(find.text('È DELLA FAMIGLIA'), findsNothing);
    await tap(tester, 'FATTO');

    for (final player in [dino, elio, fabio]) {
      await nightTurn(tester, player);
      await tap(tester, 'FATTO');
    }
    await tester.tap(find.text('BUIO IN SALA'));
    await tester.pump(const Duration(milliseconds: 500));
    await tap(tester, 'SALTA');
    await tap(tester, 'AVANTI');

    expect(find.text('Cronaca nera'), findsOneWidget);
    expect(find.text('Stanotte è morta una persona: Dino. Il suo ruolo resta segreto.'), findsOneWidget);
    expect(
      find.text('Oggi Elio non può parlare durante la discussione. Vota a gesti, e resta tra chi potete eliminare.'),
      findsOneWidget,
    );
    await tap(tester, 'APRI LA DISCUSSIONE');

    expect(find.byIcon(Icons.voice_over_off), findsOneWidget, reason: 'il tavolo vede chi deve tacere');
    await tap(tester, 'AL VOTO');
    expect(find.byIcon(Icons.voice_over_off), findsOneWidget);
    final grid = tester.widget<PlayerGrid>(find.byType(PlayerGrid));
    expect(grid.selectable, contains(elio), reason: 'chi tace si può comunque condannare');
    await tap(tester, 'NESSUNO');
    await watchVerdict(tester);
    await tap(tester, 'CONTINUA');

    await tap(tester, 'COMINCIA LA NOTTE');
    await nightTurn(tester, ada);
    await tap(tester, 'FATTO');
    await tap(tester, 'SONO IO');
    expect(find.byIcon(Icons.voice_over_off), findsNothing, reason: 'il silenzio dura un giorno');
    expect(
      tester.widget<PlayerGrid>(find.byType(PlayerGrid)).selectable,
      [ada, carla, fabio],
      reason: 'mai la stessa bocca due notti di fila',
    );
  });

  testWidgets('a fine partita la famiglia è in rosso, qualunque ruolo avesse', (tester) async {
    await pumpGame(tester, deal: {
      ada: Role.padrino,
      bruno: Role.pregiudicato,
      carla: Role.cittadino,
    });
    await tap(tester, 'COMINCIA LA NOTTE');
    await nightTurn(tester, ada, pick: carla);
    await tap(tester, 'FATTO');
    await nightTurn(tester, bruno);
    await tap(tester, 'FATTO');
    await nightTurn(tester, carla);
    await tap(tester, 'FATTO');
    await tester.tap(find.text('BUIO IN SALA'));
    await tester.pump(const Duration(milliseconds: 500));
    await tap(tester, 'SALTA');
    await tap(tester, 'AVANTI');
    await tap(tester, 'FINALE');

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
    await tap(tester, 'COMINCIA LA NOTTE');

    for (final player in players) {
      expect(find.text(player.name.toUpperCase()), findsOneWidget);
      await tap(tester, 'SONO IO');
      expect(tester.takeException(), isNull, reason: player.name);
      expect(tester.widget<PlayerGrid>(find.byType(PlayerGrid)).players, hasLength(maxRolePlayers));
      await tap(tester, 'PASSO');
      await tap(tester, 'FATTO');
    }

    expect(find.text('Tutti vivi'), findsOneWidget);
    await tap(tester, 'APRI LA DISCUSSIONE');
    expect(tester.takeException(), isNull);
    expect(tester.widget<PlayerGrid>(find.byType(PlayerGrid)).players, hasLength(maxRolePlayers));
  });

  testWidgets('con il narratore umano il telefono torna a lui per l\'alba', (tester) async {
    await pumpGame(tester, narrator: elio);

    expect(find.text('LEGGE ELIO, AD ALTA VOCE'), findsOneWidget);
    await tap(tester, 'COMINCIA LA NOTTE');
    expect(find.byIcon(Icons.visibility), findsNothing, reason: 'di notte il telefono non è del narratore');

    for (final player in [ada, bruno, carla, dino]) {
      await nightTurn(tester, player);
      await tap(tester, 'FATTO');
    }

    expect(find.text('ELIO'), findsOneWidget);
    await tap(tester, 'SONO IO');
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

  testWidgets('uscire dalla partita chiede conferma', (tester) async {
    await pumpGame(tester);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text('Abbandonare la partita?'), findsOneWidget);
    await tap(tester, 'RESTA');
    expect(find.text('NOTTE 1'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    await tap(tester, 'ESCI');
    expect(find.text('GIOCA'), findsOneWidget);
  });
}
