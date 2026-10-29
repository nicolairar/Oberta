// Quanto costa un fotogramma, schermata per schermata, sul telefono (393x852
// a 3x) e sul desktop (1920x1080), nel motore dei test:
//
//   flutter test tool/perf/frame_cost_test.dart
//
// Stampa la tabella e la scrive in build/perf/$PERF_LABEL.json. PERF_SHOTS=dir
// salva anche un fotogramma per scenario, per confrontare i pixel prima e
// dopo; DIG=1 dice chi ridisegna e chi costa; ONLY=phone o desktop.
//
// ui: il lavoro del framework per un fotogramma (build, layout, paint,
// composizione), nel JIT di debug dei test: più lento del telefono in
// profile, ma i rapporti tengono. raster: il motore dei test che disegna il
// fotogramma sulla CPU, meno la sola lettura dei pixel. build/paint: widget
// ricostruiti e oggetti ridipinti per fotogramma; pict: immagini registrate
// di nuovo; bake: immagini di Baked rifatte; layers/fx: strati, e quanti
// sono filtri o trasparenze (un passaggio fuori schermo ciascuno).
//
// I tempi veri (Metal, profile) li dà integration_test/perf_test.dart.
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'perf_harness.dart';
import 'scenarios.dart';

final _label = Platform.environment['PERF_LABEL'] ?? 'latest';
final _only = Platform.environment['ONLY'];

class _TesterRig extends Rig {
  @override
  Future<void> screen(WidgetTester tester, Screen s) async => useScreen(tester, s);
  @override
  Future<void> measure(WidgetTester tester, String name, {int frames = 48, Future<void> Function(int i)? step}) =>
      measureFrames(tester, name, frames: frames, step: step);
  @override
  Future<void> snapshot(WidgetTester tester, String name) => snapshotFrame(tester, name);
}

void main() {
  rig = _TesterRig();
  setUpAll(loadFonts);
  // LiveKit's device watch: the test engine has no WebRTC, and the voice
  // here is a fake anyway.
  setUp(() {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockStreamHandler(const EventChannel('FlutterWebRTC.Event'), MockStreamHandler.inline(onListen: (_, _) {}));
    messenger.setMockMethodCallHandler(const MethodChannel('FlutterWebRTC.Method'), (_) async => null);
  });
  tearDownAll(() => report(_label));
  for (final screen in [phone, desktop]) {
    if (_only != null && _only != screen.name) continue;
    testWidgets('${screen.name}: vicolo, strada, bottega', (tester) => streetScenario(tester, screen));
    testWidgets('${screen.name}: regole', (tester) => rulesScenario(tester, screen));
    testWidgets('${screen.name}: film del verdetto', (tester) => filmScenario(tester, screen));
    testWidgets('${screen.name}: partita a dodici', (tester) => gameScenario(tester, screen));
    testWidgets('${screen.name}: fine partita', (tester) => endScenario(tester, screen));
  }
}
