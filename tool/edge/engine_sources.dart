// L'impronta dei sorgenti del motore che gira sul server: lo SHA-256 di
// tutti i file Dart che `engine_main.dart` importa, direttamente o no.
// `build.sh` la scrive in testa a `engine.js`; un test controlla che sia
// ancora quella giusta, così chi cambia le regole non si dimentica di
// ricompilare il server.
//
// Uso: dart run tool/edge/engine_sources.dart  (stampa l'impronta)

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

const engineEntry = 'tool/edge/engine_main.dart';
const engineBundle = 'supabase/functions/game/engine.js';

final _import = RegExp(r'''^(?:import|export|part)\s+['"]([^'"]+)['"]''', multiLine: true);

/// I file del motore, relativi a [root], in ordine.
List<String> engineSources(String root) {
  final seen = <String>{};
  final queue = [engineEntry];
  while (queue.isNotEmpty) {
    final path = queue.removeLast();
    if (!seen.add(path)) continue;
    final text = File('$root/$path').readAsStringSync();
    for (final match in _import.allMatches(text)) {
      final uri = match.group(1)!;
      if (uri.startsWith('dart:')) continue;
      if (uri.startsWith('package:')) {
        if (!uri.startsWith('package:oberta/')) throw StateError('il motore non può dipendere da $uri ($path)');
        queue.add('lib/${uri.substring('package:oberta/'.length)}');
      } else {
        queue.add(_normalize('${File(path).parent.path}/$uri'));
      }
    }
  }
  return seen.toList()..sort();
}

String _normalize(String path) {
  final out = <String>[];
  for (final part in path.split('/')) {
    if (part == '.' || part.isEmpty) continue;
    if (part == '..') {
      out.removeLast();
    } else {
      out.add(part);
    }
  }
  return out.join('/');
}

/// L'impronta: percorso e contenuto di ogni file, in ordine.
String engineFingerprint(String root) {
  final bytes = <int>[];
  for (final path in engineSources(root)) {
    bytes
      ..addAll(utf8.encode('$path\n'))
      ..addAll(File('$root/$path').readAsBytesSync());
  }
  return sha256.convert(bytes).toString();
}

/// L'impronta scritta in testa al bundle, o null.
String? bundleFingerprint(String root) {
  final file = File('$root/$engineBundle');
  if (!file.existsSync()) return null;
  final first = file.readAsLinesSync().first;
  return RegExp(r'sources: ([0-9a-f]{64})').firstMatch(first)?.group(1);
}

void main() => stdout.writeln(engineFingerprint(Directory.current.path));
