import 'dart:typed_data';

import 'package:flutter/services.dart';

import 'synth.dart';

/// I suoni registrati che le colonne sonore delle scene incollano sul nastro:
/// passi, tonfi, lame, vetri, metalli. Vengono dai pacchetti CC0 di Kenney
/// (vedi `assets/sounds/CREDITS.md`), già convertiti a 32 kHz mono.
typedef SampleBank = Map<String, Float64List>;

const sceneSamples = [
  'step_1', 'step_2', 'step_3', 'step_4',
  'knife', 'knife_2', 'knife_draw',
  'wood_heavy', 'wood_heavy_2', 'plank',
  'body_fall', 'body_fall_2',
  'punch', 'punch_2',
  'glass_heavy', 'glass_heavy_2', 'glass_medium',
  'plate', 'plate_2',
  'metal_heavy', 'metal_heavy_2', 'metal_medium', 'metal_light',
  'tin', 'latch', 'bag', 'cloth_1', 'cloth_2', 'creak', 'bell', 'bell_2',
];

/// Carica i campioni delle scene dagli asset dell'app. Quelli che mancano
/// semplicemente non ci sono: la scena ripiega sul suono sintetico.
Future<SampleBank> loadSampleBank([AssetBundle? bundle]) async {
  final source = bundle ?? rootBundle;
  final bank = <String, Float64List>{};
  for (final name in sceneSamples) {
    try {
      final bytes = await source.load('assets/sounds/$name.wav');
      bank[name] = Tape.decodeWav(bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes));
    } catch (_) {}
  }
  return bank;
}
