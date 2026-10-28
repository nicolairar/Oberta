import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/network/fake_local_session.dart';
import 'package:oberta/roster/photo_camera.dart';
import 'package:oberta/roster/roster.dart';
import 'package:oberta/roster/roster_storage.dart';
import 'package:oberta/roster/roster_store.dart';
import 'package:oberta/ui/screens/lobby_screen.dart';
import 'package:oberta/ui/screens/narrator_selection_screen.dart';
import 'package:oberta/ui/theme/app_theme.dart';
import 'package:oberta/ui/widgets/mugshot_frame.dart';
import 'package:oberta/ui/widgets/noir_avatar.dart';

import '../support/test_photo.dart';

/// Una fotocamera che restituisce quello che il test le mette in mano.
class FakeCamera implements PhotoCamera {
  Uint8List? next;
  bool denied = false;
  final asked = <PhotoSource>[];

  @override
  Future<Uint8List?> take(PhotoSource source) async {
    asked.add(source);
    if (denied) throw const PhotoAccessDenied();
    return next;
  }
}

late MemoryRosterStorage storage;
late RosterStore store;
late FakeCamera camera;

void usePhone(WidgetTester tester, {Size size = const Size(393, 852), double keyboard = 0}) {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard * 3);
  addTearDown(tester.view.reset);
  // I fondali animati non si fermano mai: nei test si chiede al sistema di
  // ridurre le animazioni, come farebbe un utente dalle impostazioni.
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

Future<void> openLobby(WidgetTester tester) async {
  await tester.pumpWidget(MaterialApp(
    theme: buildAppTheme(),
    home: LobbyScreen(session: FakeLocalSession(hostName: 'Tu'), camera: camera),
  ));
  await tester.pumpAndSettle();
}

Future<void> seatPeople(Iterable<String> names) async {
  for (final name in names) {
    await store.add(name);
  }
}

Future<void> tap(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

bool canStart(WidgetTester tester) =>
    tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'AVVIA')).onPressed != null;

/// I ritratti che mostrano una foto vera invece del disegno.
Finder photoPortraits() => find.descendant(of: find.byType(NoirAvatar), matching: find.byType(RawImage));

void main() {
  setUp(() {
    storage = MemoryRosterStorage();
    store = RosterStore(storage);
    RosterStore.instance = store;
    camera = FakeCamera();
  });

  testWidgets('a elenco vuoto c\'è l\'invito, e non si parte', (tester) async {
    usePhone(tester);
    await openLobby(tester);

    expect(find.text('CHI GIOCA STASERA?'), findsOneWidget);
    expect(find.text('Nomi e foto restano su questo telefono.'), findsOneWidget);
    expect(canStart(tester), isFalse);
    expect(find.byTooltip('Via tutti'), findsNothing, reason: 'non c\'è nessuno da mandare via');
  });

  testWidgets('il telefono fa il giro: una scheda, il timbro, e avanti il prossimo', (tester) async {
    usePhone(tester);
    await openLobby(tester);

    await tap(tester, 'AGGIUNGI');
    expect(find.text('NUOVA SCHEDA'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Marco');
    await tap(tester, 'AGGIUNGI AL TAVOLO');
    expect(find.text('SCHEDATO'), findsOneWidget);
    expect(find.text('Marco è al tavolo.'), findsOneWidget);

    await tap(tester, 'AVANTI IL PROSSIMO');
    expect(find.text('SCHEDATO'), findsNothing);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
    await tester.enterText(find.byType(TextField), '  giulia ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('giulia è al tavolo.'), findsOneWidget, reason: 'si conferma anche dalla tastiera');

    await tap(tester, 'ABBIAMO FINITO');
    expect(find.text('2 AL TAVOLO'), findsOneWidget);
    expect(find.text('Marco'), findsOneWidget);
    expect(find.text('giulia'), findsOneWidget);
    expect(find.text('Ne manca ancora uno per cominciare.'), findsOneWidget);
    expect([for (final member in Roster.decode(storage.roster).table) member.name], ['Marco', 'giulia']);
  });

  testWidgets('senza nome non si scheda nessuno, e due nomi uguali nemmeno', (tester) async {
    usePhone(tester);
    await seatPeople(['Marco']);
    await openLobby(tester);
    await tap(tester, 'AGGIUNGI');

    await tap(tester, 'AGGIUNGI AL TAVOLO');
    expect(find.text('Senza un nome non ti si può schedare.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), ' MARCO');
    await tester.pumpAndSettle();
    expect(find.text('C\'è già qualcuno con questo nome.'), findsOneWidget);
    await tap(tester, 'AGGIUNGI AL TAVOLO');
    expect(find.text('SCHEDATO'), findsNothing);
    expect(store.roster.members, hasLength(1));

    await tester.enterText(find.byType(TextField), 'x' * 40);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, hasLength(maxNameLength),
        reason: 'oltre il limite la tastiera non scrive');
  });

  testWidgets('la foto si scatta, si rifà, si toglie, e resta sulla faccia di chi l\'ha fatta', (tester) async {
    usePhone(tester);
    final first = (await tester.runAsync(() => fakePhoto(variant: 0)))!;
    final second = (await tester.runAsync(() => fakePhoto(variant: 1)))!;
    await seatPeople(['Giulia']);
    await openLobby(tester);
    await tap(tester, 'AGGIUNGI');
    expect(find.text('SENZA FOTO'), findsOneWidget);

    camera.next = first;
    await tap(tester, 'SCATTA');
    expect(camera.asked, [PhotoSource.camera]);
    expect(find.text('SCATTA'), findsNothing);
    expect(find.text('Trascina per centrare la faccia'), findsOneWidget);

    await tap(tester, 'SENZA FOTO');
    expect(find.text('SCATTA'), findsOneWidget, reason: 'tolta la foto si torna al ritratto disegnato');

    camera.next = second;
    await tap(tester, 'GALLERIA');
    expect(camera.asked, [PhotoSource.camera, PhotoSource.gallery]);
    camera.next = null;
    await tap(tester, 'RIFAI');
    expect(find.text('RIFAI'), findsOneWidget, reason: 'chi ci ripensa tiene la foto che aveva');

    // Il dito trascina la foto in giù: l'inquadratura sale.
    await tester.drag(find.byType(MugshotFrame), const Offset(0, 60));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Marco');
    await tap(tester, 'AGGIUNGI AL TAVOLO');
    await tap(tester, 'ABBIAMO FINITO');

    final marco = store.roster.members.last;
    expect(marco.photo, isNotNull);
    expect(marco.photoY, lessThan(defaultPhotoY));
    expect(storage.photos.values.single, second, reason: 'sul telefono resta solo la foto scelta');

    await loadPhotos(tester, store);
    expect(photoPortraits(), findsOneWidget, reason: 'Marco ha la sua foto, Giulia il suo disegno');
  });

  testWidgets('senza permesso per la fotocamera si gioca lo stesso, col ritratto disegnato', (tester) async {
    usePhone(tester);
    await openLobby(tester);
    await tap(tester, 'AGGIUNGI');

    camera.denied = true;
    await tap(tester, 'SCATTA');
    expect(find.textContaining('Niente permesso per la fotocamera'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Marco');
    await tap(tester, 'AGGIUNGI AL TAVOLO');
    expect(find.text('Marco è al tavolo.'), findsOneWidget);
    expect(store.roster.members.single.photo, isNull);
    expect(storage.photos, isEmpty);
  });

  testWidgets('un tocco fa alzare e risedere, e chi è fuori resta in elenco', (tester) async {
    usePhone(tester);
    await seatPeople(['Marco', 'Giulia', 'Luca', 'Sara']);
    await openLobby(tester);
    expect(find.text('4 AL TAVOLO'), findsOneWidget);
    expect(find.text('Si può cominciare.'), findsOneWidget);
    expect(find.text('FUORI'), findsNothing);

    await tap(tester, 'Luca');
    expect(find.text('3 AL TAVOLO'), findsOneWidget);
    expect(find.text('FUORI'), findsOneWidget);
    expect(find.text('Luca'), findsOneWidget);
    expect(canStart(tester), isTrue);

    await tap(tester, 'Sara');
    expect(find.text('Ne manca ancora uno per cominciare.'), findsOneWidget);
    expect(canStart(tester), isFalse, reason: 'in due non si gioca');

    await tap(tester, 'Marco');
    expect(find.text('Ne mancano ancora 2 per cominciare.'), findsOneWidget);
    await tap(tester, 'Giulia');
    expect(find.text('TAVOLO VUOTO'), findsOneWidget);
    expect(find.text('FUORI'), findsNWidgets(4));

    await tap(tester, 'Luca');
    expect(find.text('1 AL TAVOLO'), findsOneWidget);
    expect(store.roster.members, hasLength(4));
  });

  testWidgets('al tavolo più di dodici non ci stanno', (tester) async {
    usePhone(tester);
    await seatPeople([for (var i = 1; i <= maxTablePlayers; i++) 'Persona $i']);
    await openLobby(tester);
    expect(find.text('12 AL TAVOLO'), findsOneWidget);
    expect(find.textContaining('Tavolo pieno'), findsOneWidget);
    expect(canStart(tester), isTrue);

    await tap(tester, 'AGGIUNGI');
    await tester.enterText(find.byType(TextField), 'Ultimo');
    await tap(tester, 'AGGIUNGI AL TAVOLO');
    expect(find.text('Il tavolo è pieno: Ultimo per ora guarda.'), findsOneWidget);
    await tap(tester, 'ABBIAMO FINITO');
    expect(find.text('12 AL TAVOLO'), findsOneWidget);

    await tap(tester, 'Ultimo');
    expect(find.textContaining('Il tavolo è pieno'), findsOneWidget);
    expect(store.roster.table, hasLength(maxTablePlayers));
    expect(store.roster.members.last.seated, isFalse);

    await tap(tester, 'Persona 1');
    await tap(tester, 'Ultimo');
    expect(store.roster.members.last.seated, isTrue, reason: 'liberato un posto, si siede');
    expect(find.text('12 AL TAVOLO'), findsOneWidget);
  });

  testWidgets('si riparte dal tavolo dell\'ultima volta, e giocano solo i seduti', (tester) async {
    usePhone(tester);
    final photo = (await tester.runAsync(fakePhoto))!;
    final earlier = RosterStore(storage);
    await earlier.add('Marco', photo: photo);
    await earlier.add('Giulia');
    final luca = await earlier.add('Luca');
    await earlier.add('Sara');
    final paolo = await earlier.add('Paolo');
    await earlier.seat(luca.id, false);
    await earlier.seat(paolo.id, false);

    // L'app si riapre: un elenco nuovo, sopra lo stesso archivio.
    store = RosterStore(storage);
    RosterStore.instance = store;
    await openLobby(tester);
    await loadPhotos(tester, store);

    expect(find.text('3 AL TAVOLO'), findsOneWidget);
    expect(find.text('FUORI'), findsNWidgets(2));
    expect(find.byType(NoirAvatar), findsNWidgets(5));
    expect(photoPortraits(), findsOneWidget, reason: 'la foto di Marco è ancora lì');

    await tap(tester, 'AVVIA');
    final players = tester.widget<NarratorSelectionScreen>(find.byType(NarratorSelectionScreen)).players;
    expect([for (final player in players) player.name], ['Marco', 'Giulia', 'Sara']);
  });

  testWidgets('tenendo premuta una faccia si apre la sua scheda: nome nuovo, foto via', (tester) async {
    usePhone(tester);
    final photo = (await tester.runAsync(fakePhoto))!;
    await store.add('Marco', photo: photo);
    await seatPeople(['Giulia']);
    await openLobby(tester);

    await tester.longPress(find.text('Marco'));
    await tester.pumpAndSettle();
    expect(find.text('SCHEDA'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'Marco');
    expect(find.text('RIFAI'), findsOneWidget, reason: 'la foto che ha già è sulla scheda');

    await tester.enterText(find.byType(TextField), 'giulia');
    await tap(tester, 'SALVA');
    expect(find.text('C\'è già qualcuno con questo nome.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'marco');
    await tap(tester, 'SENZA FOTO');
    await tap(tester, 'SALVA');

    expect(find.text('IL TAVOLO'), findsOneWidget);
    expect(find.text('marco'), findsOneWidget, reason: 'il proprio nome si può riscrivere come si vuole');
    expect(store.roster.members.first.photo, isNull);
    expect(storage.photos, isEmpty, reason: 'tolta la foto, sparisce anche dal telefono');
  });

  testWidgets('chi non gioca più si toglie dalla sua scheda, dopo una conferma', (tester) async {
    usePhone(tester);
    final photo = (await tester.runAsync(fakePhoto))!;
    await store.add('Marco', photo: photo);
    await seatPeople(['Giulia', 'Luca']);
    await openLobby(tester);

    await tester.longPress(find.text('Marco'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Togli dall\'elenco'));
    await tester.pumpAndSettle();
    expect(find.text('Via Marco?'), findsOneWidget);
    await tap(tester, 'ANNULLA');
    expect(store.roster.members, hasLength(3));

    await tester.tap(find.byTooltip('Togli dall\'elenco'));
    await tester.pumpAndSettle();
    await tap(tester, 'TOGLI');

    expect(find.text('IL TAVOLO'), findsOneWidget);
    expect(find.text('Marco'), findsNothing);
    expect(find.text('2 AL TAVOLO'), findsOneWidget);
    expect(storage.photos, isEmpty);
    expect([for (final member in Roster.decode(storage.roster).members) member.name], ['Giulia', 'Luca']);
  });

  testWidgets('via tutti chiede conferma, poi cancella nomi e foto', (tester) async {
    usePhone(tester);
    final photo = (await tester.runAsync(fakePhoto))!;
    await store.add('Marco', photo: photo);
    await seatPeople(['Giulia', 'Luca']);
    await openLobby(tester);

    await tester.tap(find.byTooltip('Via tutti'));
    await tester.pumpAndSettle();
    expect(find.text('Via tutti?'), findsOneWidget);
    await tap(tester, 'ANNULLA');
    expect(find.text('3 AL TAVOLO'), findsOneWidget);
    expect(storage.photos, hasLength(1));

    await tester.tap(find.byTooltip('Via tutti'));
    await tester.pumpAndSettle();
    await tap(tester, 'CANCELLA TUTTI');

    expect(find.text('CHI GIOCA STASERA?'), findsOneWidget);
    expect(store.roster.isEmpty, isTrue);
    expect(storage.photos, isEmpty);
    expect(Roster.decode(storage.roster).isEmpty, isTrue);
  });

  testWidgets('tavolo pieno e tastiera aperta stanno in ogni schermo, dal più piccolo al più grande', (tester) async {
    final photo = (await tester.runAsync(fakePhoto))!;
    for (var i = 1; i <= maxTablePlayers + 2; i++) {
      await store.add(i.isEven ? 'Gianfrancesco $i' : 'Ugo $i', photo: i < 4 ? photo : null);
    }
    camera.next = photo;

    for (final size in const [Size(375, 667), Size(393, 852), Size(430, 932)]) {
      usePhone(tester, size: size);
      await openLobby(tester);
      await loadPhotos(tester, store);
      expect(tester.takeException(), isNull, reason: 'tavolo, $size');
      expect(find.text('12 AL TAVOLO'), findsOneWidget);

      await tester.longPress(find.text('Ugo 1'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'scheda, $size');

      usePhone(tester, size: size, keyboard: 300);
      await tester.pumpAndSettle();
      await tester.showKeyboard(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'x' * maxNameLength);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'scheda con la tastiera, $size');
      final field = tester.getRect(find.byType(TextField));
      expect(field.bottom, lessThanOrEqualTo(size.height - 300), reason: 'il nome resta sopra la tastiera, $size');

      await tester.pumpWidget(const SizedBox());
    }

    for (final size in const [Size(375, 667), Size(430, 932)]) {
      usePhone(tester, size: size);
      await openLobby(tester);
      await tester.tap(find.byTooltip('Via tutti'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'conferma, $size');
      await tester.pumpWidget(const SizedBox());
    }
  });
}
