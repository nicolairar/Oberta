import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omerta/settings/app_settings.dart';
import 'package:omerta/settings/settings_store.dart';

/// Il telefono dei test parla italiano, come quello di chi ha scritto le
/// prove: chi vuole l'inglese lo chiede nel test. Ogni prova parte da
/// impostazioni nuove, così una lingua scelta in un test non passa al
/// successivo.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    binding.platformDispatcher.localesTestValue = const [Locale('it', 'IT')];
    AppSettings.instance = AppSettings(MemorySettingsStore());
  });
  tearDown(binding.platformDispatcher.clearLocalesTestValue);
  await testMain();
}
