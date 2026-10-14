import 'dart:io';
import 'dart:typed_data';

import 'roster_storage.dart';

/// L'elenco su disco: un file `roster.json` e una cartella `photos`, dentro
/// la cartella che [directory] indica. Nessuna rete, nessun database.
class FileRosterStorage implements RosterStorage {
  /// La cartella si chiede ogni volta a chi sa dov'è: su un telefono la
  /// risposta arriva dal sistema, e non subito.
  final Future<Directory> Function() directory;

  int _serial = 0;

  FileRosterStorage(this.directory);

  Future<File> get _rosterFile async => File('${(await directory()).path}/roster.json');

  Future<Directory> get _photoDirectory async => Directory('${(await directory()).path}/photos');

  /// Una chiave è solo il nome di un file dentro `photos`: niente che possa
  /// uscire dalla cartella.
  Future<File?> _photoFile(String key) async {
    if (!RegExp(r'^[A-Za-z0-9_-]+\.jpg$').hasMatch(key)) return null;
    return File('${(await _photoDirectory).path}/$key');
  }

  @override
  Future<String?> readRoster() async {
    final file = await _rosterFile;
    try {
      return await file.readAsString();
    } on FileSystemException {
      return null;
    }
  }

  /// Si scrive a fianco e poi si rinomina: se l'app muore a metà, il file
  /// vecchio è ancora intero.
  @override
  Future<void> writeRoster(String json) async {
    final file = await _rosterFile;
    await file.parent.create(recursive: true);
    final draft = File('${file.path}.tmp');
    await draft.writeAsString(json, flush: true);
    await draft.rename(file.path);
  }

  @override
  Future<String> writePhoto(Uint8List bytes) async {
    final folder = await _photoDirectory;
    await folder.create(recursive: true);
    // Un nome nuovo a ogni scatto: una foto rifatta non può mai essere
    // scambiata con quella di prima.
    final stamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final key = '$stamp-${++_serial}.jpg';
    await File('${folder.path}/$key').writeAsBytes(bytes, flush: true);
    return key;
  }

  @override
  Future<Uint8List?> readPhoto(String key) async {
    final file = await _photoFile(key);
    if (file == null) return null;
    try {
      return await file.readAsBytes();
    } on FileSystemException {
      return null;
    }
  }

  @override
  Future<void> deletePhoto(String key) async {
    final file = await _photoFile(key);
    if (file == null) return;
    try {
      await file.delete();
    } on FileSystemException {
      // Già sparita: va bene così.
    }
  }

  @override
  Future<void> sweepPhotos(Set<String> keep) async {
    final folder = await _photoDirectory;
    if (!await folder.exists()) return;
    await for (final entry in folder.list()) {
      final name = entry.uri.pathSegments.lastWhere((segment) => segment.isNotEmpty);
      if (entry is! File || keep.contains(name)) continue;
      try {
        await entry.delete();
      } on FileSystemException {
        // Ci si riprova al prossimo avvio.
      }
    }
  }
}
