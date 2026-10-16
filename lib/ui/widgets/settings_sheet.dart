import 'package:flutter/material.dart';

import '../../l10n/app_language.dart';
import '../../l10n/app_strings.dart';
import '../../online/online_services.dart';
import '../../settings/app_settings.dart';
import '../screens/screening_room_screen.dart';
import '../theme/app_theme.dart';

/// Le impostazioni, dalla targa smaltata in cima al vicolo: l'audio, la
/// lingua, la sala prove dove rivedere le scene, e l'uscita dall'account
/// online per chi è entrato.
class SettingsSheet extends StatelessWidget {
  final AppSettings settings;

  /// L'account online, per uscirne. Senza, quello aperto da `main` (se c'è).
  final OnlineServices? online;

  SettingsSheet({super.key, AppSettings? settings, OnlineServices? online})
      : settings = settings ?? AppSettings.instance,
        online = online ?? OnlineServices.instance;

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
    final auth = online?.auth;
    return ListenableBuilder(
      listenable: Listenable.merge([settings, ?auth]),
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
                _VolumeTile(
                  icon: Icons.library_music,
                  label: t.musicVolumeLabel,
                  value: settings.musicVolume,
                  enabled: settings.soundOn,
                  onChanged: (volume) => settings.musicVolume = volume,
                ),
                _VolumeTile(
                  icon: Icons.graphic_eq,
                  label: t.effectsVolumeLabel,
                  value: settings.effectsVolume,
                  enabled: settings.soundOn,
                  onChanged: (volume) => settings.effectsVolume = volume,
                ),
                SwitchListTile(
                  value: settings.memeMode,
                  activeThumbColor: AppColors.gold,
                  title: Text(t.memeMode),
                  subtitle: Text(t.memeModeHint),
                  secondary: const Icon(Icons.sentiment_very_satisfied, color: AppColors.gold),
                  onChanged: settings.soundOn ? (on) => settings.memeMode = on : null,
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
                if (auth != null && auth.signedIn)
                  ListTile(
                    leading: const Icon(Icons.logout, color: AppColors.gold),
                    title: Text(t.online.signOut),
                    onTap: auth.signOut,
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

/// Un cursore di volume, con la percentuale a destra.
class _VolumeTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final double value;
  final bool enabled;
  final ValueChanged<double> onChanged;

  const _VolumeTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.gold),
      title: Text(label),
      subtitle: Row(
        children: [
          Expanded(
            child: Slider(
              value: value,
              divisions: 20,
              activeColor: AppColors.gold,
              onChanged: enabled ? onChanged : null,
            ),
          ),
          SizedBox(
            width: 44,
            child: Text('${(value * 100).round()}%', textAlign: TextAlign.end, style: AppText.body),
          ),
        ],
      ),
    );
  }
}
