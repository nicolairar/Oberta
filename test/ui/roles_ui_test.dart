import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omerta/rules/game_setup.dart';
import 'package:omerta/rules/knowledge.dart';
import 'package:omerta/rules/player.dart';
import 'package:omerta/rules/role.dart';
import 'package:omerta/rules/role_assignment.dart';
import 'package:omerta/ui/theme/app_theme.dart';
import 'package:omerta/ui/theme/role_style.dart';
import 'package:omerta/ui/widgets/flip_role_card.dart';
import 'package:omerta/ui/widgets/narrator_roles_sheet.dart';
import 'package:omerta/ui/widgets/player_grid.dart';
import 'package:omerta/ui/widgets/role_reveal_card.dart';

const _mafiaRed = Color(0xFFE5606A);

List<Player> _players(int count) => [for (var i = 0; i < count; i++) Player(id: 'p$i', name: 'Giocatore $i')];

void _useScreen(WidgetTester tester, Size size) {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  test('ogni ruolo ha il suo colore e la sua icona', () {
    expect({for (final role in Role.values) role.color}, hasLength(Role.values.length));
    expect({for (final role in Role.values) role.icon}, hasLength(Role.values.length));
  });

  for (final screen in const [Size(393, 852), Size(320, 568)]) {
    testWidgets('la carta di ogni ruolo sta nello schermo ${screen.width.round()}x${screen.height.round()}',
        (tester) async {
      _useScreen(tester, screen);
      const accomplices = [
        Player(id: 'a', name: 'Massimiliano'),
        Player(id: 'b', name: 'Francesca'),
        Player(id: 'c', name: 'Alessandro'),
      ];
      for (final role in Role.values) {
        // Lo stesso spazio che la carta ha quando ci si passa il telefono.
        await tester.pumpWidget(MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text('NOME', style: AppText.display(24)),
                    Expanded(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
                          child: FlipRoleCard(
                            key: ValueKey(role),
                            role: role,
                            teammates: role.team == Team.mafia ? accomplices : const [],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 110),
                  ],
                ),
              ),
            ),
          ),
        ));
        final hold = await tester.startGesture(tester.getCenter(find.byType(FlipRoleCard)));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: role.name);
        expect(find.text(role.label.toUpperCase()), findsOneWidget);
        expect(find.text(role.motto), findsOneWidget);
        expect(find.text(role.description), findsOneWidget);
        expect(
          find.text(role.team == Team.mafia ? 'STAI CON LA FAMIGLIA' : 'STAI CON GLI ONESTI'),
          findsOneWidget,
          reason: role.name,
        );
        expect(find.text('I TUOI COMPLICI'), role.team == Team.mafia ? findsOneWidget : findsNothing);
        await hold.up();
        await tester.pumpAndSettle();
      }
    });
  }

  testWidgets('la carta del condannato dice la squadra vera di ogni ruolo', (tester) async {
    for (final role in Role.values) {
      await tester.pumpWidget(MaterialApp(
        home: Center(child: RoleRevealCard(key: ValueKey(role), role: role, faceUp: true)),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: role.name);
      expect(find.text(role.label.toUpperCase()), findsOneWidget);
      expect(find.text(role.team == Team.mafia ? 'FAMIGLIA' : 'ONESTI'), findsOneWidget, reason: role.name);
    }
    expect(Role.pregiudicato.team, Team.citizens);
  });

  testWidgets('il narratore vede tutti e dodici i ruoli, la famiglia in rosso', (tester) async {
    _useScreen(tester, const Size(393, 852));
    final players = _players(12);
    final setup = GameSetup.fromRoles(Map.fromIterables(players, Role.values));
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: NarratorRolesSheet(setup: setup, isAlive: (player) => player != players.last),
        ),
      ),
    ));

    final hold = await tester.startGesture(tester.getCenter(find.text('SOLO PER IL NARRATORE')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    for (final role in Role.values) {
      final label = tester.widget<Text>(find.text(role.label));
      expect(label.style!.color == _mafiaRed, role.team == Team.mafia, reason: role.name);
    }
    expect(find.byIcon(Icons.smoking_rooms), findsOneWidget);
    expect(find.byIcon(Icons.content_cut), findsOneWidget);
    await hold.up();
    await tester.pumpAndSettle();
    expect(find.text('Il Padrino'), findsNothing);
  });

  group('PlayerGrid', () {
    Future<void> pumpGrid(WidgetTester tester, PlayerGrid grid) async {
      _useScreen(tester, const Size(393, 852));
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(body: Padding(padding: const EdgeInsets.all(24), child: grid)),
      ));
      await tester.pumpAndSettle();
    }

    double opacityOf(WidgetTester tester, Player player) => tester
        .widget<AnimatedOpacity>(
          find.ancestor(of: find.text(player.name), matching: find.byType(AnimatedOpacity)).first,
        )
        .opacity;

    testWidgets('un tavolo da sedici ci sta, e si scorre fino all\'ultimo posto', (tester) async {
      final players = _players(maxRolePlayers);
      Player? picked;
      await pumpGrid(
        tester,
        PlayerGrid(
          players: players,
          isAlive: (_) => true,
          knowledgeOf: (_) => Knowledge.none,
          selectable: players,
          onSelect: (player) => picked = player,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text(players.first.name), findsOneWidget);

      await tester.scrollUntilVisible(find.text(players.last.name), 200);
      await tester.pumpAndSettle();
      await tester.tap(find.text(players.last.name));
      expect(picked, players.last);
    });

    testWidgets('quando si scelgono i morti, sono loro in piena luce e i vivi sfumano', (tester) async {
      final players = _players(4);
      final dead = players[2];
      Player? picked;
      await pumpGrid(
        tester,
        PlayerGrid(
          players: players,
          isAlive: (player) => player != dead,
          knowledgeOf: (_) => Knowledge.none,
          selectable: [dead],
          onSelect: (player) => picked = player,
        ),
      );
      expect(opacityOf(tester, dead), 1);
      expect(opacityOf(tester, players[0]), lessThan(1));
      expect(find.text('†'), findsOneWidget, reason: 'resta chiaro che non c\'è più');

      await tester.tap(find.text(players[0].name));
      expect(picked, isNull, reason: 'i vivi non si riesumano');
      await tester.tap(find.text(dead.name));
      expect(picked, dead);
    });

    testWidgets('di solito i morti restano in ombra, e non si toccano', (tester) async {
      final players = _players(4);
      final dead = players[2];
      Player? picked;
      await pumpGrid(
        tester,
        PlayerGrid(
          players: players,
          isAlive: (player) => player != dead,
          knowledgeOf: (_) => Knowledge.none,
          selectable: [players[0], players[1]],
          onSelect: (player) => picked = player,
        ),
      );
      expect(opacityOf(tester, players[0]), 1);
      expect(opacityOf(tester, players[3]), 0.55);
      expect(opacityOf(tester, dead), 0.38);
      await tester.tap(find.text(dead.name));
      expect(picked, isNull);
    });

    testWidgets('la griglia di sola lettura mostra i vivi in luce e i morti in ombra', (tester) async {
      final players = _players(3);
      await pumpGrid(
        tester,
        PlayerGrid(
          players: players,
          isAlive: (player) => player != players[1],
          knowledgeOf: (_) => Knowledge.none,
        ),
      );
      expect(opacityOf(tester, players[0]), 1);
      expect(opacityOf(tester, players[1]), 0.38);
    });

    testWidgets('chi ha la bocca cucita porta il segno sul ritratto, finché è in gioco', (tester) async {
      final players = _players(3);
      await pumpGrid(
        tester,
        PlayerGrid(
          players: players,
          isAlive: (_) => true,
          knowledgeOf: (_) => Knowledge.none,
          silenced: players[1],
        ),
      );
      expect(find.byIcon(Icons.voice_over_off), findsOneWidget);
      expect(
        find.descendant(
          of: find.ancestor(of: find.text(players[1].name), matching: find.byType(InkWell)),
          matching: find.byIcon(Icons.voice_over_off),
        ),
        findsOneWidget,
      );

      await pumpGrid(
        tester,
        PlayerGrid(
          players: players,
          isAlive: (player) => player != players[1],
          knowledgeOf: (_) => Knowledge.none,
          silenced: players[1],
        ),
      );
      expect(find.byIcon(Icons.voice_over_off), findsNothing);
    });

    testWidgets('chi ha scavato vede sulla tessera il ruolo trovato', (tester) async {
      final players = _players(3);
      await pumpGrid(
        tester,
        PlayerGrid(
          players: players,
          isAlive: (player) => player != players[2],
          knowledgeOf: (player) =>
              player == players[2] ? const Knowledge(role: Role.reduce, team: Team.citizens) : Knowledge.none,
        ),
      );
      expect(find.byIcon(Role.reduce.icon), findsOneWidget);
      expect(find.text('INNOCENTE'), findsNothing, reason: 'il ruolo dice già tutto');
    });
  });
}
