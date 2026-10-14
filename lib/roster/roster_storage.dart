import 'dart:typed_data';

/// Dove vive l'elenco tra una partita e l'altra: un testo con nomi e posti,
/// più una foto per chi se l'è fatta. Tutto resta sul telefono.
///
/// Implementazioni: [MemoryRosterStorage] (test, e finché l'app non installa
/// quella vera) e `FileRosterStorage` (una cartella privata dell'app).
abstract class RosterStorage {
  /// L'elenco salvato, o `null` se non ce n'è ancora uno.
  Future<String?> readRoster();

  Future<void> writeRoster(String json);

  /// Salva una foto e restituisce la chiave con cui ritrovarla.
  Future<String> writePhoto(Uint8List bytes);

  Future<Uint8List?> readPhoto(String key);

  /// Cancella una foto. Se non c'è già più, non è un errore.
  Future<void> deletePhoto(String key);

  /// Cancella tutte le foto tranne [keep]: gli avanzi di un salvataggio
  /// interrotto a metà non devono restare sul telefono.
  Future<void> sweepPhotos(Set<String> keep);
}

/// Un archivio che vive solo in memoria.
class MemoryRosterStorage implements RosterStorage {
  String? roster;
  final photos = <String, Uint8List>{};
  int _serial = 0;

  MemoryRosterStorage({this.roster});

  @override
  Future<String?> readRoster() async => roster;

  @override
  Future<void> writeRoster(String json) async => roster = json;

  @override
  Future<String> writePhoto(Uint8List bytes) async {
    final key = 'foto-${++_serial}';
    photos[key] = bytes;
    return key;
  }

  @override
  Future<Uint8List?> readPhoto(String key) async => photos[key];

  @override
  Future<void> deletePhoto(String key) async => photos.remove(key);

  @override
  Future<void> sweepPhotos(Set<String> keep) async => photos.removeWhere((key, _) => !keep.contains(key));
}
