import 'package:flutter/material.dart';

import '../../l10n/app_language.dart';
import '../../l10n/app_strings.dart';
import '../../settings/app_settings.dart';
import '../screens/screening_room_screen.dart';
import '../theme/app_theme.dart';

/// Le impostazioni, dalla targa smaltata in cima al vicolo: l'audio, la
/// lingua, e la sala prove dove rivedere le scene.
class SettingsSheet extends StatelessWidget {
  final AppSettings settings;

  SettingsSheet({super.key, AppSettings? settings}) : settings = settings ?? AppSettings.instance;

  static Future<void> show(BuildContext context, {AppSettings? settings}) => showModalBottomSheet<void>(
        context: context,
        backgroundColor: AppColors.surface,
        showDragHandle: true,
        // Alto quanto serve: con la lingua non sta più nel mezzo schermo di
        // un foglio normale. Su un telefono piccolo scorre.
        isScrollControlled: true,
        builder: (_) => SettingsSheet(settings: settings),
      );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final t = AppStrings.of(context);
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(t.settingsTitle, textAlign: TextAlign.center, style: AppText.overline),
                const SizedBox(height: 8),
                SwitchListTile(
                  value: settings.soundOn,
                  activeThumbColor: AppColors.gold,
                  title: Text(t.sound),
                  subtitle: Text(t.soundHint),
                  secondary: const Icon(Icons.music_note, color: AppColors.gold),
                  onChanged: (on) => settings.soundOn = on,
                ),
                ListTile(
                  leading: const Icon(Icons.translate, color: AppColors.gold),
                  title: Text(t.languageSetting),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final language in <AppLanguage?>[null, ...AppLanguage.values])
                          ChoiceChip(
                            label: Text(language?.nativeName ?? t.languageAutomatic),
                            selected: settings.language == language,
                            selectedColor: AppColors.gold.withValues(alpha: 0.3),
                            onSelected: (_) => settings.language = language,
                          ),
                      ],
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.movie_filter, color: AppColors.gold),
                  title: Text(t.rehearsal),
                  subtitle: Text(t.rehearsalHint),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context)
                      ..pop()
                      ..push(MaterialPageRoute<void>(builder: (_) => const ScreeningRoomScreen()));
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
