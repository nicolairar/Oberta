import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/l10n/app_language.dart';
import 'package:oberta/l10n/rules_strings.dart';
import 'package:oberta/main.dart';
import 'package:oberta/rules/role.dart';
import 'package:oberta/sound/narrator_voice.dart';
import 'package:oberta/ui/screens/lobby_screen.dart';
import 'package:oberta/ui/screens/rules_screen.dart';
import 'package:oberta/ui/theme/app_theme.dart';

void _usePhone(WidgetTester tester, Size size, {double top = 59, double bottom = 34}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = FakeViewPadding(top: top, bottom: bottom);
  addTearDown(tester.view.reset);
}

Future<void> _frames(WidgetTester tester, [int count = 12]) async {
  for (var frame = 0; frame < count; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('dal cartello REGOLE sul palo si leggono le regole, e in fondo si va al tavolo', (tester) async {
    _usePhone(tester, const Size(393, 852));
    await tester.pumpWidget(const ObertaApp());
    await tester.pump(const Duration(seconds: 4));

    await tester.tap(find.byKey(const Key('home.rules')));
    await _frames(tester);
    expect(find.byType(RulesScreen), findsOneWidget);
    expect(find.text('REGOLE DEL GIOCO'), findsOneWidget);
    expect(find.text('Leggi questa pagina ad alta voce: in un minuto i tuoi amici sanno giocare.'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('rules.play')));
    await _frames(tester, 6);
    await tester.tap(find.byKey(const Key('rules.play')));
    await _frames(tester, 16);
    expect(find.byType(RulesScreen), findsNothing);
    expect(find.byType(LobbyScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('il cartello delle regole sta sul palo anche sul telefono piccolo', (tester) async {
    _usePhone(tester, const Size(375, 667), top: 20, bottom: 0);
    await tester.pumpWidget(const ObertaApp());
    await tester.pump(const Duration(seconds: 4));
    expect(find.byKey(const Key('home.rules')), findsOneWidget);
    expect(find.byKey(const Key('home.tutorial')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('due versioni, sbrigativa e teatrale, e i ruoli più comuni si aprono', (tester) async {
    _usePhone(tester, const Size(393, 852));
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: RulesScreen(onPlayLocal: () {}),
      ),
    );
    await tester.pump();
    expect(find.text('DUE SQUADRE'), findsOneWidget);

    await tester.tap(find.byKey(const Key('rules.style.stage')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('C\'ERA UNA VOLTA'), findsOneWidget);
    expect(find.text('DUE SQUADRE'), findsNothing);

    final picciotto = find.text('Il Picciotto', findRichText: true);
    expect(picciotto, findsNothing);
    await tester.ensureVisible(find.byKey(const Key('rules.roles')));
    await tester.tap(find.byKey(const Key('rules.roles')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Il Picciotto', findRichText: true), findsOneWidget);
  });

  testWidgets('«Fammela leggere» fa parlare il narratore, e si ferma quando si vuole', (tester) async {
    _usePhone(tester, const Size(393, 852));
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: RulesScreen(onPlayLocal: () {}),
      ),
    );
    await tester.pump();
    expect(find.text('FAMMELA LEGGERE'), findsOneWidget);

    await tester.tap(find.byKey(const Key('rules.read')));
    await tester.pump(const Duration(seconds: 6));
    expect(find.text('BASTA COSÌ'), findsOneWidget);

    await tester.tap(find.byKey(const Key('rules.read')));
    await tester.pump();
    expect(find.text('FAMMELA LEGGERE'), findsOneWidget);

    // Chi esce a metà lettura non lascia la voce accesa.
    await tester.tap(find.byKey(const Key('rules.read')));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 30));
    expect(tester.takeException(), isNull);
  });

  test('le due versioni raccontano gli stessi sei passi, nelle due lingue', () {
    for (final language in AppLanguage.values) {
      final strings = RulesStrings(language);
      for (final style in RulesStyle.values) {
        final steps = strings.steps(style);
        expect(steps, hasLength(6), reason: '$language $style');
        for (final step in steps) {
          expect(step.beats.where((beat) => !beat.cue), isNotEmpty, reason: step.title);
        }
      }
    }
  });

  test('i ruoli più comuni vengono dall\'elenco dei ruoli e si giocano tutti sul telefono', () {
    final roles = RulesStrings.commonRoleList;
    expect(roles, containsAll([Role.mafioso, Role.cittadino, Role.detective, Role.medico]));
    expect(roles.every((role) => role.playableIn(PlayMode.sharedPhone)), isTrue);
    expect(
      RulesStrings.oneLine('Sei della Famiglia. Ogni notte decidi chi uccidere. Vinci con loro.'),
      'Sei della Famiglia. Ogni notte decidi chi uccidere.',
    );
  });

  test('ogni frase detta delle regole ha la sua clip, in tutte e due le lingue', () {
    final voice = NarratorVoice.instance;
    for (final language in AppLanguage.values) {
      for (final line in RulesStrings(language).spoken) {
        expect(voice.clip(language, line), isNotNull, reason: '${language.name}: $line');
      }
    }
  });
}
