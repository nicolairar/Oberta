import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/ui/screens/online/game/felt_text.dart';

const _headline = 'Linciato 7 Margherita: era innocente';
const _story =
    'Margherita sale i gradini del patibolo senza guardare nessuno. La ghigliottina brilla al sole di '
    'mezzogiorno. La carta si gira: Margherita era... il Commissario. Stava con gli onesti. La famiglia '
    'ringrazia per la collaborazione, e qualcuno in piazza abbassa gli occhi.';

Future<void> _show(WidgetTester tester, Size box, {required double title, required double body}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox.fromSize(
          size: box,
          child: FeltText([
            (text: _headline, style: TextStyle(fontSize: title), key: const Key('h')),
            (text: _story, style: TextStyle(fontSize: body, fontStyle: FontStyle.italic), key: const Key('s')),
          ]),
        ),
      ),
    ),
  ));
}

void main() {
  for (final (name, box, title, body) in [
    ('telefono', const Size(180, 120), 17.0, 15.0),
    ('PC', const Size(420, 200), 28.0, 21.0),
  ]) {
    testWidgets('il verdetto lungo si legge tutto, a capo e senza puntini ($name)', (tester) async {
      await _show(tester, box, title: title, body: body);
      for (final key in const [Key('h'), Key('s')]) {
        final paragraph = tester.renderObject<RenderParagraph>(find.byKey(key));
        expect(paragraph.didExceedMaxLines, isFalse);
        expect(tester.widget<Text>(find.byKey(key)).maxLines, isNull);
        expect(tester.widget<Text>(find.byKey(key)).overflow, isNot(TextOverflow.ellipsis));
      }
      // Tutto dentro lo spazio che ha, senza strabordare.
      final area = tester.getRect(find.byType(FeltText));
      for (final key in const [Key('h'), Key('s')]) {
        final rect = tester.getRect(find.byKey(key));
        expect(rect.top, greaterThanOrEqualTo(area.top - 0.5));
        expect(rect.bottom, lessThanOrEqualTo(area.bottom + 0.5));
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('un testo corto resta a grandezza piena', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 300,
            height: 200,
            child: FeltText([(text: 'La piazza non si decide', style: TextStyle(fontSize: 17), key: Key('h'))]),
          ),
        ),
      ),
    ));
    expect(tester.widget<Text>(find.byKey(const Key('h'))).style!.fontSize, 17);
  });
}
