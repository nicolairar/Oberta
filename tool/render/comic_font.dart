// Le scritte da fumetto dei filmati della notte (BANG!, ZAC!...) usano sul
// telefono il carattere di sistema; nei test sarebbero rettangoli pieni.
// Qui se ne carica uno vero, per i provini.
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:oberta/ui/widgets/death_scene.dart';

Future<void> loadComicFont() async {
  final file = File('/System/Library/Fonts/Supplemental/Arial Black.ttf');
  if (!file.existsSync()) return;
  final loader = FontLoader('Comic')..addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
  await loader.load();
  DeathScenePainter.debugComicFont = 'Comic';
}
