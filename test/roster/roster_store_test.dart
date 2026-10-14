import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:omerta/roster/portrait_registry.dart';
import 'package:omerta/roster/roster.dart';
import 'package:omerta/roster/roster_storage.dart';
import 'package:omerta/roster/roster_store.dart';

/// Per l'elenco una foto è solo un mucchio di byte: non importa che si veda.
Uint8List shot(int seed) => Uint8List.fromList([seed, seed + 1, seed + 2]);

void main() {
  // Chi registra una faccia la fa decodificare subito: serve il motore.
  TestWidgetsFlutterBinding.ensureInitialized();

  late MemoryRosterStorage storage;
  late RosterStore store;

  setUp(() {
    storage = MemoryRosterStorage();
    store = RosterStore(storage);
  });

  test('prima di leggere non c\'è niente, poi l\'elenco vuoto', () async {
    expect(store.isLoaded, isFalse);
    await store.load();
    expect(store.isLoaded, isTrue);
    expect(store.roster.isEmpty, isTrue);
  });

  test('ogni modifica avvisa chi ascolta e finisce nell\'archivio', () async {
    var changes = 0;
    store.addListener(() => changes++);

    final marco = await store.add('Marco');
    expect(changes, greaterThan(0));
    expect(Roster.decode(storage.roster).members.single.name, 'Marco');

    await store.rename(marco.id, 'Marcone');
    expect(Roster.decode(storage.roster).members.single.name, 'Marcone');

    await store.seat(marco.id, false);
    expect(Roster.decode(storage.roster).table, isEmpty);
  });

  test('chi riapre l\'app ritrova la gente, le foto e il tavolo di prima', () async {
    final marco = await store.add('Marco', photo: shot(1), photoX: 0.3, photoY: -0.6);
    await store.add('Giulia');
    final luca = await store.add('Luca');
    await store.seat(luca.id, false);

    final reopened = RosterStore(storage);
    await reopened.load();

    expect([for (final member in reopened.roster.members) member.name], ['Marco', 'Giulia', 'Luca']);
    expect([for (final member in reopened.roster.table) member.name], ['Marco', 'Giulia']);
    final again = reopened.roster.byId(marco.id)!;
    expect(reopened.photoOf(again), isNotNull);
    expect((again.photoX, again.photoY), (0.3, -0.6));
    expect(reopened.photoOf(reopened.roster.members[1]), isNull);
  });

  test('una foto rifatta prende il posto della vecchia, che sparisce dal telefono', () async {
    final marco = await store.add('Marco', photo: shot(1));
    final first = store.roster.byId(marco.id)!.photo!;

    await store.setPhoto(marco.id, shot(7));

    final second = store.roster.byId(marco.id)!.photo!;
    expect(second, isNot(first));
    expect(storage.photos.keys, [second]);
    expect(storage.photos[second], shot(7));
  });

  test('spostare l\'inquadratura non tocca il file della foto', () async {
    final marco = await store.add('Marco', photo: shot(1));
    final key = store.roster.byId(marco.id)!.photo!;

    await store.framePhoto(marco.id, 0.4, 0.2);

    final moved = store.roster.byId(marco.id)!;
    expect((moved.photo, moved.photoX, moved.photoY), (key, 0.4, 0.2));
    expect(storage.photos.keys, [key]);
    expect(store.photoOf(moved)!.alignment.y, 0.2);
  });

  test('togliere la foto, la persona o tutti cancella anche i file', () async {
    final marco = await store.add('Marco', photo: shot(1));
    final giulia = await store.add('Giulia', photo: shot(2));
    await store.add('Luca', photo: shot(3));
    await store.add('Sara', photo: shot(4));
    expect(storage.photos, hasLength(4));

    await store.removePhoto(marco.id);
    expect(storage.photos, hasLength(3));
    expect(store.roster.byId(marco.id)!.photo, isNull);
    expect(store.roster.members, hasLength(4), reason: 'senza foto, ma ancora in elenco');

    await store.remove(giulia.id);
    expect(storage.photos, hasLength(2));
    expect(store.roster.byId(giulia.id), isNull);

    await store.clear();
    expect(storage.photos, isEmpty);
    expect(store.roster.isEmpty, isTrue);
    expect(Roster.decode(storage.roster).isEmpty, isTrue);
  });

  test('un nome rifiutato non lascia foto in giro', () async {
    await store.add('Marco');

    await expectLater(store.add('marco', photo: shot(1)), throwsA(isA<RosterError>()));
    await expectLater(store.add('  ', photo: shot(2)), throwsA(isA<RosterError>()));

    expect(storage.photos, isEmpty);
    expect(store.roster.members, hasLength(1));
  });

  test('a tavolo pieno chi arriva guarda, e sedersi non riesce', () async {
    for (var i = 0; i < maxTablePlayers; i++) {
      await store.add('Persona $i');
    }
    final last = await store.add('Ultimo');

    expect(last.seated, isFalse);
    expect(await store.seat(last.id, true), isFalse);
    expect(store.roster.table, hasLength(maxTablePlayers));

    expect(await store.seat(store.roster.members.first.id, false), isTrue);
    expect(await store.seat(last.id, true), isTrue);
  });

  test('una foto sparita dal telefono non porta via la persona', () async {
    final marco = await store.add('Marco', photo: shot(1));
    storage.photos.clear();

    final reopened = RosterStore(storage);
    await reopened.load();

    final again = reopened.roster.byId(marco.id)!;
    expect(again.photo, isNull);
    expect(reopened.photoOf(again), isNull);
  });

  test('aprendo si buttano le foto che nessuno usa più', () async {
    await store.add('Marco', photo: shot(1));
    final used = storage.photos.keys.single;
    storage.photos['avanzo'] = shot(9);

    await RosterStore(storage).load();

    expect(storage.photos.keys, [used]);
  });

  test('le facce pubblicate seguono l\'elenco: solo nomi e foto', () async {
    final marco = await store.add('Marco', photo: shot(1));
    await store.add('Giulia');
    final portraits = store.portraits;

    expect(portraits.photoOf('Marco'), isNotNull);
    expect(portraits.photoOf(' MARCO '), isNotNull, reason: 'il nome si cerca come lo cerca l\'elenco');
    expect(portraits.photoOf('Giulia'), isNull);

    await store.rename(marco.id, 'Marcone');
    expect(portraits.photoOf('Marco'), isNull);
    expect(portraits.photoOf('Marcone'), isNotNull);

    await store.removePhoto(marco.id);
    expect(portraits.photoOf('Marcone'), isNull);
  });

  test('l\'elenco installato porta con sé le sue facce', () async {
    final before = RosterStore.instance;
    addTearDown(() => RosterStore.instance = before);
    await store.add('Marco', photo: shot(1));

    RosterStore.instance = store;

    expect(PortraitRegistry.instance, same(store.portraits));
    expect(PortraitRegistry.instance.photoOf('Marco'), isNotNull);
  });
}
