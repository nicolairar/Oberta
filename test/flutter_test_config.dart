import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/roster/roster_storage.dart';
import 'package:oberta/roster/roster_store.dart';
import 'package:oberta/settings/app_settings.dart';
import 'package:oberta/settings/settings_store.dart';

/// Il telefono dei test parla italiano, come quello di chi ha scritto le
/// prove: chi vuole l'inglese lo chiede nel test. Ogni prova parte da
/// impostazioni nuove, così una lingua scelta in un test non passa al
/// successivo; e l'elenco dei giocatori riparte vuoto.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    binding.platformDispatcher.localesTestValue = const [Locale('it', 'IT')];
    AppSettings.instance = AppSettings(MemorySettingsStore());
    RosterStore.instance = RosterStore(MemoryRosterStorage());
  });
  tearDown(binding.platformDispatcher.clearLocalesTestValue);
  await testMain();
}
