import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'city_backdrop.dart';

export 'city_backdrop.dart' show SceneMood, SkylineStyle;

/// Una schermata con il fondale della città dietro: il cielo arriva fin
/// sotto la barra del titolo, il contenuto ci sta sopra.
class SceneScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final SceneMood mood;
  final SkylineStyle style;
  final bool rain;

  const SceneScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.mood = SceneMood.night,
    this.style = SkylineStyle.metropolis,
    this.rain = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: AppColors.background,
      appBar: appBar,
      body: CityBackdrop(mood: mood, style: style, rain: rain, child: body),
    );
  }
}

/// Il profilo giusto per ogni città del copione.
SkylineStyle skylineFor(String cityId) => switch (cityId) {
      'palermo' => SkylineStyle.mediterranean,
      'napoli' => SkylineStyle.volcano,
      'las-vegas' => SkylineStyle.desert,
      _ => SkylineStyle.metropolis,
    };
