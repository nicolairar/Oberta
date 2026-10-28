import 'dart:async';

import 'online/online_account.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'online/device_links.dart';
import 'online/incoming_links.dart';
import 'online/online_config.dart';
import 'online/online_services.dart';
import 'online/supabase_online.dart';
import 'online/tutorial_sync.dart';
import 'roster/device_roster.dart';
import 'l10n/app_language.dart';
import 'l10n/app_strings.dart';
import 'settings/app_settings.dart';
import 'sound/device_stage.dart';
import 'sound/narrator_voice.dart';
import 'sound/screen_music.dart';
import 'sound/sound_stage.dart';
import 'steam/steam.dart';
import 'ui/desktop/desktop_frame.dart';
import 'ui/desktop/desktop_platform.dart';
import 'ui/screens/home_screen.dart';
import 'ui/widgets/app_update_gate.dart';
import 'ui/widgets/device_session_gate.dart';
import 'ui/theme/app_theme.dart';
import 'ui/warm_up.dart';
import 'ui/screens/settings_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SoundStage.instance = DeviceStage();
  installDeviceRoster();
  NarratorVoice.instance = await NarratorVoice.load();
  AppSettings.instance = await AppSettings.open();
  if (DesktopPlatform.isDesktop) await DesktopWindow.open(AppSettings.instance);
  // Steamworks solo nelle build --dart-define=STEAM=true (docs/steam.md).
  await SteamClient.start();
  // L'online c'è solo se l'app è stata compilata con config/supabase.json.
  final sessionId = newDeviceSessionId();
  final package = await _packageInfo();
  final build = int.tryParse(package?.buildNumber ?? '');
  final platform = appPlatformHere();
  OnlineServices.instance = await openSupabaseOnline(
    OnlineConfig.compiled,
    deviceSessionId: sessionId,
    appBuild: build,
    appPlatform: platform,
  );
  if (OnlineServices.instance case final services?) TutorialSync.attach(services);
  if (OnlineServices.instance case OnlineServices(:final auth, sessions: final sessions?)) {
    DeviceSession.instance = DeviceSession(sessions, sessionId: sessionId, deviceLabel: deviceLabelHere())
      ..follow(auth, () => auth.signedIn);
  }
  // Aggiornamento obbligatorio: negozio (App Store / GitHub) e build minima
  // del server. Senza rete non blocca nulla.
  UpdateGate.instance = UpdateGate(
    version: package?.version ?? '0.0.0',
    build: build,
    platform: platform,
    store: _storeHere(platform),
    server: OnlineServices.instance?.requirements,
    cache: PrefsUpdateCache(),
  );
  unawaited(UpdateGate.instance!.check());
  // Il QR di una stanza inquadrato con la fotocamera apre l'app su quella stanza.
  listenToDeviceLinks(IncomingLinks.instance);
  runApp(const ObertaApp(offerTutorial: true));
  // Un po' di tutto disegnato una volta, fuori schermo: niente scatti dopo.
  WarmUp.start();
  SoundStage.instance.music(MusicMood.menu);
}

Future<PackageInfo?> _packageInfo() async {
  try {
    return await PackageInfo.fromPlatform();
  } catch (error) {
    debugPrint('Versione sconosciuta: $error');
    return null;
  }
}

/// Dove guardare se c'è una versione nuova: solo l'App Store. Nelle build di
/// debug nessun negozio (si lavora su versioni non ancora uscite); il desktop
/// esce solo su Steam, che aggiorna da sé: resta la build minima del server.
StoreReleaseSource? _storeHere(String? platform) {
  if (kDebugMode) return null;
  return switch (platform) {
    'ios' => const AppStoreLookup(),
    _ => null,
  };
}

class ObertaApp extends StatelessWidget {
  /// Le preferenze da seguire; senza, quelle aperte da `main`.
  final AppSettings? settings;

  /// Proporre il tutorial al primo avvio. Spento nei test dell'app intera.
  final bool offerTutorial;

  const ObertaApp({super.key, this.settings, this.offerTutorial = false});

  @override
  Widget build(BuildContext context) {
    final settings = this.settings ?? AppSettings.instance;
    // Chi cambia lingua nelle impostazioni ridisegna tutta l'app, subito.
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => MaterialApp(
        title: 'Obertà',
        theme: buildAppTheme(),
        navigatorObservers: [AccountRefreshObserver.instance, screenMusicRoutes],
        locale: settings.language?.locale,
        supportedLocales: AppLanguage.locales,
        localizationsDelegates: const [
          AppStrings.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        // Il telefono in italiano gioca in italiano; tutti gli altri in inglese.
        localeListResolutionCallback: (device, _) => AppLanguage.forDevice(device).locale,
        builder: (context, child) {
          final gated = UpdateGateView(
            gate: UpdateGate.instance,
            child: DeviceSessionGate(session: DeviceSession.instance, child: child!),
          );
          // Su desktop il gioco sta nel suo riquadro 16:9 (o 9:16), col letterbox.
          if (!DesktopPlatform.isDesktop) return gated;
          return DesktopFrame(orientation: settings.orientation, child: gated);
        },
        home: Builder(
          builder: (context) => HomeScreen(
            onSettings: () => SettingsScreen.open(context, settings: settings),
            offerTutorial: offerTutorial && !settings.tutorialSeen,
          ),
        ),
      ),
    );
  }
}
