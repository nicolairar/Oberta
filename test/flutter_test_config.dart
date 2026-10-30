import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/online/incoming_links.dart';
import 'package:oberta/online/online_services.dart';
import 'package:oberta/online/voice/mic_permission.dart';
import 'package:oberta/roster/roster_storage.dart';
import 'package:oberta/roster/roster_store.dart';
import 'package:oberta/settings/app_settings.dart';
import 'package:oberta/settings/settings_store.dart';
import 'package:oberta/sound/narrator_voice.dart';
import 'package:oberta/ui/season/season.dart';

/// Il telefono dei test parla italiano, come quello di chi ha scritto le
/// prove: chi vuole l'inglese lo chiede nel test. Ogni prova parte da
/// impostazioni nuove, così una lingua scelta in un test non passa al
/// successivo; e l'elenco dei giocatori riparte vuoto.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  // Le prove non cambiano col giorno in cui girano: a Natale come a luglio.
  SeasonLooks.debugCalendarOff = true;
  // La voce del narratore automatico con le sue clip vere: il palco dei test
  // è muto, ma i tempi e i sottotitoli sono quelli del telefono.
  final voice = File('assets/voice/index.json');
  final index = voice.existsSync() ? voice.readAsStringSync() : null;
  setUp(() {
    NarratorVoice.instance = index == null ? NarratorVoice() : NarratorVoice.fromJson(index);
    binding.platformDispatcher.localesTestValue = const [Locale('it', 'IT')];
    AppSettings.instance = AppSettings(MemorySettingsStore());
    RosterStore.instance = RosterStore(MemoryRosterStorage());
    // Nessun server: chi vuole l'online porta il suo FakeOnline.
    OnlineServices.instance = null;
    IncomingLinks.instance = IncomingLinks();
    // Il microfono dei test è sempre concesso: chi prova il rifiuto lo dice.
    MicPermission.request = () async => true;
    MicPermission.openSettings = () async {};
  });
  tearDown(binding.platformDispatcher.clearLocalesTestValue);
  await testMain();
}
