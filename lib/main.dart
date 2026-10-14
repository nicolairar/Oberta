import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/app_language.dart';
import 'l10n/app_strings.dart';
import 'settings/app_settings.dart';
import 'sound/device_stage.dart';
import 'sound/sound_stage.dart';
import 'ui/screens/home_screen.dart';
import 'ui/theme/app_theme.dart';
import 'ui/widgets/settings_sheet.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SoundStage.instance = DeviceStage();
  AppSettings.instance = await AppSettings.open();
  runApp(const OmertaApp());
}

class OmertaApp extends StatelessWidget {
  /// Le preferenze da seguire; senza, quelle aperte da `main`.
  final AppSettings? settings;

  const OmertaApp({super.key, this.settings});

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
