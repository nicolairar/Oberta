import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/roster/roster_storage.dart';
import 'package:oberta/roster/roster_store.dart';
import 'package:oberta/settings/app_settings.dart';
import 'package:oberta/settings/settings_store.dart';
import 'package:oberta/sound/narrator_voice.dart';

/// Il telefono dei test parla italiano, come quello di chi ha scritto le
/// prove: chi vuole l'inglese lo chiede nel test. Ogni prova parte da
/// impostazioni nuove, così una lingua scelta in un test non passa al
/// successivo; e l'elenco dei giocatori riparte vuoto.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  // La voce del narratore automatico con le sue clip vere: il palco dei test
  // è muto, ma i tempi e i sottotitoli sono quelli del telefono.
  final voice = File('assets/voice/index.json');
  final index = voice.existsSync() ? voice.readAsStringSync() : null;
  setUp(() {
    NarratorVoice.instance = index == null ? NarratorVoice() : NarratorVoice.fromJson(index);
    binding.platformDispatcher.localesTestValue = const [Locale('it', 'IT')];
    AppSettings.instance = AppSettings(MemorySettingsStore());
    RosterStore.instance = RosterStore(MemoryRosterStorage());
  });
  tearDown(binding.platformDispatcher.clearLocalesTestValue);
  await testMain();
}
