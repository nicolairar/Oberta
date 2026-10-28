import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/l10n/app_language.dart';
import 'package:oberta/l10n/player_gender.dart';
import 'package:oberta/l10n/table_strings.dart';
import 'package:oberta/online/online_models.dart';
import 'package:oberta/ui/screens/online/game/saloon_table.dart';
import 'package:oberta/ui/screens/online/game/seat_card.dart';
import 'package:oberta/ui/widgets/cosmetics/styled_name.dart';

import '../support/languages.dart';

/// The table slots the game really uses: iPhone 393x852 and SE 375x667 (the
/// table is 38% of the height, inside 16 points of margin), and the desktop
/// canvas at 1080p (a big table, bigger cards).
const _tables = {
  'iphone': (Size(393 - 32, 852 * 0.38), 118.0),
  'se': (Size(375 - 32, 667 * 0.38), 118.0),
  'desktop': (Size(1180, 760), 152.0),
};

void main() {
  group('the free space on the felt', () {
    for (final MapEntry(key: name, value: (size, maxCard)) in _tables.entries) {
      for (var count = 4; count <= 16; count++) {
        test('never touches a seat: $count seats, $name', () {
          final g = SaloonTable.layout(count, size, maxCard: maxCard);
          expect(g.center.width, greaterThan(40), reason: 'room for a few words');
          expect(g.center.height, greaterThan(20));
          for (final (i, c) in g.centers.indexed) {
            final seat = SaloonTable.seatBounds(c, g.width);
            expect(g.center.overlaps(seat), isFalse, reason: 'seat $i at $seat, centre ${g.center}');
          }
          expect(g.felt.contains(g.center.topLeft) && g.felt.contains(g.center.bottomRight), isTrue);
        });
      }
    }
  });

  for (final count in [6, 9, 12]) {
    testWidgets('on screen: the centre text, the seats and their slips keep apart ($count seats)', (tester) async {
      tester.view.physicalSize = const Size(393, 852) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      const centre = Key('centre');
      await tester.pumpWidget(appIn(
        AppLanguage.it,
        Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 361,
              height: 852 * 0.38,
              child: SaloonTable(
                count: count,
                center: Container(
                  key: centre,
                  color: Colors.black,
                  child: const Text('Carmela è stata linciata. Era il Picciotto.'),
                ),
                seatBuilder: (context, i, width) => SeatCard(
                  key: ValueKey('seat-$i'),
                  name: 'Massimiliano$i',
                  number: i + 1,
                  width: width,
                  votes: i.isEven ? 3 : 0,
                  accused: i == 2,
                  accusedLabel: 'ACCUSATO',
                  pizzino: '→ ${(i + 3) % count + 1}',
                  pizzinoKey: ValueKey('pizzino-$i'),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 500));
      final text = tester.getRect(find.byKey(centre));
      for (var i = 0; i < count; i++) {
        final seat = find.byKey(ValueKey('seat-$i'));
        expect(text.overlaps(tester.getRect(seat)), isFalse, reason: 'the centre text under seat $i');
        final slip = tester.getRect(find.byKey(ValueKey('pizzino-$i')));
        expect(text.overlaps(slip), isFalse, reason: 'the centre text under the slip of seat $i');
        final name = tester.getRect(find.descendant(of: seat, matching: find.byType(StyledName)));
        expect(slip.overlaps(name.deflate(1)), isFalse, reason: 'the slip of seat $i covers the name');
      }
    });
  }

  group('Italian agrees with the player', () {
    tearDown(() {
      PlayerGenders.clear();
      WornLooks.clear();
    });
    const it = TableStrings(AppLanguage.it);

    test('a woman is «linciata», a man «linciato», the unknown gets a sentence that needs no agreement', () {
      PlayerGenders.remember('Carmela', Gender.feminine);
      PlayerGenders.remember('Vito', Gender.masculine);
      expect(
        it.lynchedLine('4 Carmela', 'Il Picciotto', gender: PlayerGenders.of('4 Carmela')),
        '4 Carmela è stata linciata. Era il Picciotto.',
      );
      expect(it.lynchedLine('2 Vito', null, gender: PlayerGenders.of('2 Vito')), '2 Vito è stato linciato.');
      expect(it.lynchedLine('3 anna', 'Il Fesso', gender: PlayerGenders.of('3 anna')), 'La piazza ha linciato 3 anna. Era il Fesso.');
      expect(it.lynched(Gender.feminine), 'Linciata');
      expect(it.silenced(Gender.feminine), 'zittita');
      expect(it.abstained(Gender.feminine), startsWith('Ti sei astenuta.'));
      expect(const TableStrings(AppLanguage.en).lynchedLine('Ann', 'Fool', gender: Gender.feminine), 'Ann was lynched. They were the Fool.');
    });

    test('the choice in the barber\'s mirror decides, nothing else', () {
      WornLooks.remember(const Profile(id: 'p1', handle: 'dora', avatar: {'presentation': 'woman'}));
      WornLooks.remember(const Profile(id: 'p2', handle: 'enzo', avatar: {'presentation': 'man'}));
      WornLooks.remember(const Profile(id: 'p3', handle: 'sasha', avatar: {'presentation': 'other'}));
      WornLooks.remember(const Profile(id: 'p4', handle: 'carla', avatar: {'hat': 'bob'}));
      expect(PlayerGenders.of('5 dora'), Gender.feminine);
      expect(PlayerGenders.of('enzo'), Gender.masculine);
      expect(PlayerGenders.of('sasha'), Gender.unknown);
      expect(PlayerGenders.of('carla'), Gender.unknown, reason: 'a hat is not a gender');
      expect(PlayerGenders.of('nobody'), Gender.unknown);
    });
  });
}
