import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'online/online_config.dart';
import 'online/online_services.dart';
import 'online/supabase_online.dart';
import 'roster/device_roster.dart';
import 'l10n/app_language.dart';
import 'l10n/app_strings.dart';
import 'settings/app_settings.dart';
import 'sound/device_stage.dart';
import 'sound/narrator_voice.dart';
import 'sound/sound_stage.dart';
import 'ui/screens/home_screen.dart';
import 'ui/theme/app_theme.dart';
import 'ui/widgets/settings_sheet.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SoundStage.instance = DeviceStage();
  installDeviceRoster();
  NarratorVoice.instance = await NarratorVoice.load();
  AppSettings.instance = await AppSettings.open();
  // L'online c'è solo se l'app è stata compilata con config/supabase.json.
  OnlineServices.instance = await openSupabaseOnline(OnlineConfig.compiled);
  runApp(const ObertaApp());
  SoundStage.instance.music(MusicMood.menu);
}

class ObertaApp extends StatelessWidget {
  /// Le preferenze da seguire; senza, quelle aperte da `main`.
  final AppSettings? settings;

  const ObertaApp({super.key, this.settings});

  @override
  Widget build(BuildContext context) {
    final settings = this.settings ?? AppSettings.instance;
    // Chi cambia lingua nelle impostazioni ridisegna tutta l'app, subito.
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => MaterialApp(
        title: 'Obertà',
        theme: buildAppTheme(),
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
        home: Builder(
          builder: (context) => HomeScreen(onSettings: () => SettingsSheet.show(context, settings: settings)),
        ),
      ),
    );
  }
}
