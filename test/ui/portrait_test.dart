import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/roster/portrait_registry.dart';
import 'package:oberta/roster/roster_storage.dart';
import 'package:oberta/roster/roster_store.dart';
import 'package:oberta/ui/widgets/death_scene.dart';
import 'package:oberta/ui/widgets/face_close_up.dart';
import 'package:oberta/rules/player.dart';
import 'package:oberta/ui/screens/local/local_table.dart';
import 'package:oberta/ui/widgets/mugshot_frame.dart';
import 'package:oberta/ui/widgets/noir_avatar.dart';
import 'package:oberta/ui/widgets/noir_photo.dart';
import 'package:oberta/ui/widgets/victim_card.dart';

import '../support/test_photo.dart';

late RosterStore store;

/// Le foto vere sullo schermo, dovunque siano.
Finder photos() => find.byType(RawImage);

/// La foto che un ritratto sta mostrando.
ImageProvider shownIn(WidgetTester tester, Finder portrait) =>
    tester.widget<Image>(find.descendant(of: portrait, matching: find.byType(Image))).image;

void main() {
  setUp(() {
    store = RosterStore(MemoryRosterStorage());
    RosterStore.instance = store;
  });

  testWidgets('chi non ha una foto ha il ritratto disegnato', (tester) async {
    final photo = (await tester.runAsync(fakePhoto))!;
    await store.add('Marco', photo: photo);
    await tester.pumpWidget(const MaterialApp(home: Center(child: NoirAvatar(seed: 'Giulia', size: 80))));
    await loadPhotos(tester, store);

    expect(photos(), findsNothing);
    expect(find.descendant(of: find.byType(NoirAvatar), matching: find.byType(CustomPaint)), findsOneWidget);
  });

  testWidgets('chi ha una foto la ritrova in ogni ritratto, da vivo e da morto', (tester) async {
    final photo = (await tester.runAsync(fakePhoto))!;
    final marco = await store.add('Marco', photo: photo, photoX: 0.5, photoY: -0.5);
    await tester.pumpWidget(const MaterialApp(
      home: Wrap(
        children: [
          NoirAvatar(key: ValueKey('vivo'), seed: 'Marco', size: 80),
          NoirAvatar(key: ValueKey('morto'), seed: 'Marco', size: 80, faded: true),
          NoirAvatar(key: ValueKey('altro'), seed: 'Giulia', size: 80),
        ],
      ),
    ));
    expect(photos(), findsNothing, reason: 'finché la foto non è pronta resta il disegno');

    await loadPhotos(tester, store);

    expect(photos(), findsNWidgets(2));
    final alive = find.byKey(const ValueKey('vivo'));
    expect(shownIn(tester, alive), store.photoOf(marco)!.image);
    expect(tester.widget<Image>(find.descendant(of: alive, matching: find.byType(Image))).alignment,
        const Alignment(0.5, -0.5), reason: 'inquadrata come l\'ha voluta lui');
    expect(tester.widget<NoirPhoto>(find.descendant(of: alive, matching: find.byType(NoirPhoto))).faded, isFalse);
    final dead = find.byKey(const ValueKey('morto'));
    expect(tester.widget<NoirPhoto>(find.descendant(of: dead, matching: find.byType(NoirPhoto))).faded, isTrue);
    expect(find.descendant(of: find.byKey(const ValueKey('altro')), matching: photos()), findsNothing);
    expect(NoirPhoto.filter(faded: true), isNot(NoirPhoto.filter(faded: false)));
  });

  testWidgets('la foto arriva e se ne va senza che nessuno ridisegni a mano', (tester) async {
    final photo = (await tester.runAsync(fakePhoto))!;
    await tester.pumpWidget(const MaterialApp(home: Center(child: NoirAvatar(seed: 'marco', size: 80))));
    expect(photos(), findsNothing);

    final marco = await store.add('Marco', photo: photo);
    await tester.pump();
    await loadPhotos(tester, store);
    expect(photos(), findsOneWidget, reason: 'il nome si riconosce anche scritto in minuscolo');

    await store.rename(marco.id, 'Marcone');
    await tester.pump();
    expect(photos(), findsNothing, reason: 'la foto segue la persona, non il vecchio nome');

    await store.rename(marco.id, 'Marco');
    await store.removePhoto(marco.id);
    await tester.pump();
    expect(photos(), findsNothing);
  });

  testWidgets('una foto illeggibile lascia il ritratto disegnato', (tester) async {
    await store.add('Marco', photo: Uint8List.fromList(List.filled(64, 7)));
    await tester.pumpWidget(const MaterialApp(home: Center(child: NoirAvatar(seed: 'Marco', size: 80))));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();

    expect(photos(), findsNothing);
    expect(tester.takeException(), isNull);
    expect(find.descendant(of: find.byType(NoirAvatar), matching: find.byType(CustomPaint)), findsWidgets);
  });

  testWidgets('dove la foto si sta ancora scegliendo si può chiedere solo il disegno', (tester) async {
    final photo = (await tester.runAsync(fakePhoto))!;
    await store.add('Marco', photo: photo);
    await tester.pumpWidget(const MaterialApp(
      home: Center(child: SizedBox(width: 200, child: MugshotFrame(name: 'Marco'))),
    ));
    await loadPhotos(tester, store);

    expect(find.byType(NoirAvatar), findsOneWidget);
    expect(photos(), findsNothing, reason: 'la scheda senza foto mostra il disegno, non la foto già salvata');
  });

  testWidgets('chi riceve il telefono si riconosce dalla faccia', (tester) async {
    final photo = (await tester.runAsync(fakePhoto))!;
    await store.add('Sara', photo: photo);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: LocalCurtain(player: const Player(id: 'sara', name: 'Sara'), number: 1, onReady: () {})),
    ));
    await tester.pumpAndSettle();
    await loadPhotos(tester, store);

    expect(photos(), findsOneWidget);
  });

  group('la scena del delitto', () {
    Future<void> stage(WidgetTester tester, {required String victim, DeathAct act = DeathAct.knife}) async {
      tester.view.physicalSize = const Size(375, 667) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DeathScene(act: act, victimName: victim, caption: 'Esterno, notte.', onFinished: () {}),
        ),
      ));
      await loadPhotos(tester, store);
    }

    testWidgets('mostra la faccia della vittima, e di nessun altro', (tester) async {
      final marcoPhoto = (await tester.runAsync(() => fakePhoto(variant: 0)))!;
      final giuliaPhoto = (await tester.runAsync(() => fakePhoto(variant: 1)))!;
      final marco = await store.add('Marco', photo: marcoPhoto);
      // Giulia ha una foto anche lei: se fosse lei ad aver colpito, non si
      // deve vedere da nessuna parte.
      await store.add('Giulia', photo: giuliaPhoto);
      await stage(tester, victim: 'Marco');

      // Per tutto il film ci sono solo sagome, niente primi piani: la faccia
      // della vittima arriva solo alla fine, sulla sua carta. Quella di
      // Giulia mai.
      for (var second = 0; second < 11; second++) {
        await tester.pump(const Duration(seconds: 1));
        expect(find.byType(FaceCloseUp), findsNothing, reason: 'secondo $second');
        final shown = photos().evaluate().length;
        expect(shown, lessThanOrEqualTo(1), reason: 'secondo $second');
        if (shown == 1) expect(shownIn(tester, find.byType(VictimCard)), store.photoOf(marco)!.image, reason: 'secondo $second');
      }

      await tester.pump(DeathScene.length);
      await tester.pump();
      expect(find.text('MARCO'), findsOneWidget);
      expect(photos(), findsOneWidget);
      expect(shownIn(tester, find.byType(VictimCard)), store.photoOf(marco)!.image);
      expect(find.text('†'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // La cinepresa stringe piano sulla foto, senza mai sporcare la scena.
      for (var second = 0; second < 12; second++) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(photos(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('chi l\'ha scampata torna a colori, senza pugnale', (tester) async {
      final photo = (await tester.runAsync(fakePhoto))!;
      await store.add('Giulia', photo: photo);
      await stage(tester, victim: 'Giulia', act: DeathAct.rescue);
      await tester.tap(find.text('SALTA'));
      await tester.pump();

      expect(photos(), findsOneWidget);
      expect(tester.widget<NoirPhoto>(find.byType(NoirPhoto)).faded, isFalse);
      expect(find.text('†'), findsNothing);
    });

    testWidgets('senza foto chiude sul ritratto disegnato, come prima', (tester) async {
      await store.add('Marco');
      await stage(tester, victim: 'Marco');
      await tester.tap(find.text('SALTA'));
      await tester.pump();

      expect(photos(), findsNothing);
      expect(find.descendant(of: find.byType(VictimCard), matching: find.byType(NoirAvatar)), findsOneWidget);
      expect(find.text('†'), findsOneWidget);
    });
  });

  test('il registro conosce solo nomi e facce', () {
    final registry = PortraitRegistry();
    var changes = 0;
    registry.addListener(() => changes++);
    final photo = PortraitPhoto(MemoryImage(Uint8List.fromList([1, 2, 3])));

    expect(registry.photoOf('Marco'), isNull);
    registry.replaceAll({'Marco': photo});
    registry.replaceAll({'Marco': photo});
    expect(changes, 1, reason: 'se non cambia niente non si avvisa nessuno');
    expect(registry.photoOf('  marco'), photo);

    registry.replaceAll({});
    expect(registry.photoOf('Marco'), isNull);
    expect(changes, 2);
  });
}
