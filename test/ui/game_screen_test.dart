import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omerta/rules/game_setup.dart';
import 'package:omerta/rules/player.dart';
import 'package:omerta/rules/role.dart';
import 'package:omerta/ui/screens/game_screen.dart';
import 'package:omerta/ui/theme/app_theme.dart';
import 'package:omerta/ui/widgets/death_scene.dart';
import 'package:omerta/ui/widgets/player_grid.dart';

const ada = Player(id: 'ada', name: 'Ada');
const bruno = Player(id: 'bruno', name: 'Bruno');
const carla = Player(id: 'carla', name: 'Carla');
const dino = Player(id: 'dino', name: 'Dino');
const elio = Player(id: 'elio', name: 'Elio');

final roles = {
  ada: Role.mafioso,
  bruno: Role.detective,
  carla: Role.cittadino,
  dino: Role.cittadino,
};

Future<void> pumpGame(WidgetTester tester, {Player? narrator, Size screen = const Size(393, 852)}) async {
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
                setup: GameSetup.fromRoles(roles, narrator: narrator),
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
