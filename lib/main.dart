import 'package:flutter/material.dart';

import 'roster/device_roster.dart';
import 'sound/device_stage.dart';
import 'sound/sound_stage.dart';
import 'ui/screens/home_screen.dart';
import 'ui/theme/app_theme.dart';
import 'ui/widgets/settings_sheet.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SoundStage.instance = DeviceStage();
  installDeviceRoster();
  runApp(const OmertaApp());
}

class OmertaApp extends StatelessWidget {
  const OmertaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Obertà',
      theme: buildAppTheme(),
      home: Builder(
        builder: (context) => HomeScreen(onSettings: () => SettingsSheet.show(context)),
      ),
    );
  }
}
