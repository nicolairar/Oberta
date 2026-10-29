// I tempi veri dei fotogrammi, nell'app in profile sul Mac (Impeller, Metal),
// con gli stessi scenari di tool/perf/frame_cost_test.dart:
//
//   flutter drive --profile -d macos \
//     --driver=test_driver/perf_driver.dart --target=integration_test/perf_test.dart
//
// La finestra prende la misura dello schermo: il telefono 393x852 punti
// (sul Retina a 2x, non a 3x), il desktop 960x540 punti, cioè 1920x1080
// pixel. Il driver scrive build/perf/profile_$PERF_LABEL.json: per ogni
// scenario build e raster in ms (media, 90°, 99°, peggiore) e i fotogrammi
// oltre gli 8,3 ms dei 120 Hz.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:oberta/online/incoming_links.dart';
import 'package:oberta/online/voice/mic_permission.dart';
import 'package:oberta/roster/roster_storage.dart';
import 'package:oberta/roster/roster_store.dart';
import 'package:oberta/settings/app_settings.dart';
import 'package:oberta/settings/settings_store.dart';
import 'package:oberta/sound/narrator_voice.dart';
import 'package:window_manager/window_manager.dart';

import '../tool/perf/perf_harness.dart' show Screen, phone, desktop;
import '../tool/perf/scenarios.dart';

class _LiveRig extends Rig {
  final IntegrationTestWidgetsFlutterBinding binding;
  _LiveRig(this.binding);

  @override
  bool get live => true;

  @override
  Future<void> screen(WidgetTester tester, Screen s) async {
    await windowManager.setSize(s.name == 'desktop' ? const Size(960, 540) : s.size);
    await windowManager.center();
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }

  @override
  Future<void> measure(WidgetTester tester, String name, {int frames = 48, Future<void> Function(int i)? step}) async {
    // Più fotogrammi che nel motore dei test: qui costano poco.
    final count = frames * 2;
    debugPrint('perf: $name');
    await binding.traceAction(() async {
      for (var i = 0; i < count; i++) {
        await step?.call(i ~/ 2);
        await tester.pump();
      }
    }, reportKey: name);
  }

  @override
  Future<void> snapshot(WidgetTester tester, String name) async {}
}

const _only = String.fromEnvironment('PERF_ONLY');
const _dig = bool.fromEnvironment('PERF_DIG');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  rig = _LiveRig(binding);
  setUpAll(() async {
    await windowManager.ensureInitialized();
    await windowManager.show();
  });
  setUp(() {
    NarratorVoice.instance = NarratorVoice();
    AppSettings.instance = AppSettings(MemorySettingsStore());
    RosterStore.instance = RosterStore(MemoryRosterStorage());
    IncomingLinks.instance = IncomingLinks();
    // La voce è finta: niente microfono vero, né la domanda del sistema.
    MicPermission.request = () async => true;
    MicPermission.openSettings = () async {};
    // --dart-define=PERF_DIG=true: every build, layout and paint in the
    // timeline, to see who works in a frame (the times grow, of course).
    debugProfileBuildsEnabled = _dig;
    debugProfileLayoutsEnabled = _dig;
    debugProfilePaintsEnabled = _dig;
  });
  // Un tetto per scenario: uno che si incaglia non tiene la finestra aperta
  // per sempre, e i numeri degli altri restano. Il film del verdetto non
  // c'è: nell'app non si vede più (il verdetto è sul tavolo).
  const cap = Timeout(Duration(minutes: 5));
  for (final screen in [phone, desktop]) {
    for (final (name, scenario) in [
      ('vicolo, strada, bottega', streetScenario),
      ('regole', rulesScenario),
      ('partita a dodici', gameScenario),
      ('fine partita', endScenario),
    ]) {
      final title = '${screen.name}: $name';
      // --dart-define=PERF_ONLY=phone: partita,desktop: only the scenarios
      // whose title has one of these.
      if (_only.isNotEmpty && !_only.split(',').any(title.contains)) continue;
      // Una partita vera, a tempo vero, dura qualche minuto.
      final long = scenario == gameScenario || scenario == endScenario;
      testWidgets(title, (tester) => scenario(tester, screen), timeout: long ? const Timeout(Duration(minutes: 9)) : cap);
    }
  }
}
