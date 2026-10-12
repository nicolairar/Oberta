import 'package:flutter/material.dart';

import 'ui/screens/home_screen.dart';
import 'ui/theme/app_theme.dart';

void main() {
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
