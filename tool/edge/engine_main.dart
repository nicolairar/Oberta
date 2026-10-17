// Il motore della partita online, per il server. Si compila in JavaScript
// con `tool/edge/build.sh`, che scrive `supabase/functions/game/engine.js`:
// la Edge Function `game` lo carica e chiama `globalThis.obertaStep`.
//
// Qui c'è solo il passaggio da stringa a JSON: tutta la logica sta in
// `lib/online/game/game_server.dart`, che i test Dart provano sulla VM.

import 'dart:convert';
import 'dart:js_interop';

import 'package:oberta/online/game/game_server.dart';

@JS('obertaStep')
external set _obertaStep(JSFunction step);

String _step(String input) => jsonEncode(serverStep(jsonDecode(input) as Map<String, Object?>));

void main() {
  _obertaStep = ((JSString input) => _step(input.toDart).toJS).toJS;
}
