// The skins walk on a device: the real app, at the device's own size.
//
//   flutter test integration_test/skins_walk_test.dart -d <simulator> --dart-define=WALK_LOOK=nadia
//
// The screenshots go to WALK_OUT/<who> (--dart-define=WALK_OUT=<absolute
// folder>, which the simulator can write), or <app tmp>/skins_walk_<who>.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'skins_walk.dart';

const _who = String.fromEnvironment('WALK_LOOK', defaultValue: 'nadia');

/// Where the screenshots go: on the simulator a folder of the Mac
/// (WALK_OUT), on a phone the app's tmp.
const _outDir = String.fromEnvironment('WALK_OUT');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('a player walks the Cappello and Volto departments, the barber and a table', (tester) async {
    await skinsWalk(tester, who: _who, out: _outDir.isNotEmpty ? '$_outDir/$_who' : '${Directory.systemTemp.path}/skins_walk_$_who', io: <T>(work) => work());
  }, timeout: const Timeout(Duration(minutes: 40)));
}
