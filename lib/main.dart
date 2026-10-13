import 'package:flutter/material.dart';

import 'sound/device_stage.dart';
import 'sound/sound_stage.dart';
import 'ui/screens/home_screen.dart';
import 'ui/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SoundStage.instance = DeviceStage();
  runApp(const OmertaApp());
}

class OmertaApp extends StatelessWidget {
  const OmertaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Omertà',
      theme: buildAppTheme(),
      home: const HomeScreen(),
    );
  }
}
