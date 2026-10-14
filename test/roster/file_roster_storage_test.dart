import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:omerta/roster/file_roster_storage.dart';

void main() {
  late Directory folder;
  late FileRosterStorage storage;

  setUp(() {
    folder = Directory.systemTemp.createTempSync('omerta-roster-test-');
    // La cartella vera all'inizio non esiste: la crea chi scrive.
    storage = FileRosterStorage(() async => Directory('${folder.path}/roster'));
  });

  tearDown(() => folder.deleteSync(recursive: true));

  List<String> photoFiles() {
    final photos = Directory('${folder.path}/roster/photos');
    if (!photos.existsSync()) return [];
    return [for (final entry in photos.listSync()) entry.uri.pathSegments.last]..sort();
  }

  test('senza niente di salvato non c\'è niente da leggere', () async {
    expect(await storage.readRoster(), isNull);
    expect(await storage.readPhoto('nessuna.jpg'), isNull);
    await storage.deletePhoto('nessuna.jpg');
    await storage.sweepPhotos({});
  });

  test('l\'elenco si scrive, si rilegge e si sovrascrive senza lasciare bozze', () async {
    await storage.writeRoster('{"prima": true}');
    await storage.writeRoster('{"dopo": true}');

    expect(await storage.readRoster(), '{"dopo": true}');
    expect(await FileRosterStorage(() async => Directory('${folder.path}/roster')).readRoster(), '{"dopo": true}',
        reason: 'lo ritrova anche chi apre l\'app dopo');
    final files = [for (final entry in Directory('${folder.path}/roster').listSync()) entry.uri.pathSegments.last];
    expect(files, ['roster.json']);
  });

  test('ogni foto ha un file suo, che si rilegge e si cancella', () async {
    final first = await storage.writePhoto(Uint8List.fromList([1, 2, 3]));
    final second = await storage.writePhoto(Uint8List.fromList([4, 5, 6]));

    expect(first, isNot(second));
    expect(photoFiles(), [first, second]..sort());
    expect(await storage.readPhoto(first), [1, 2, 3]);
    expect(await storage.readPhoto(second), [4, 5, 6]);

    await storage.deletePhoto(first);
    expect(photoFiles(), [second]);
    expect(await storage.readPhoto(first), isNull);
    await storage.deletePhoto(first);
  });

  test('la pulizia tiene solo le foto ancora in uso', () async {
    final kept = await storage.writePhoto(Uint8List.fromList([1]));
    await storage.writePhoto(Uint8List.fromList([2]));
    await storage.writePhoto(Uint8List.fromList([3]));

    await storage.sweepPhotos({kept});

    expect(photoFiles(), [kept]);
  });

  test('una chiave non può indicare un file fuori dalla cartella delle foto', () async {
    final secret = File('${folder.path}/roster/roster.json');
    await storage.writeRoster('{}');

    expect(await storage.readPhoto('../roster.json'), isNull);
    await storage.deletePhoto('../roster.json');

    expect(secret.existsSync(), isTrue);
  });
}
