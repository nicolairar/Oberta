import 'package:flutter/material.dart';

import '../../sound/sound_stage.dart';
import '../screens/screening_room_screen.dart';
import '../theme/app_theme.dart';

/// Le impostazioni, dalla targa smaltata in cima al vicolo: l'audio, e la
/// sala prove dove rivedere le scene.
class SettingsSheet extends StatefulWidget {
  const SettingsSheet({super.key});

  static const _title = 'IMPOSTAZIONI';
  static const _sound = 'Musica ed effetti';
  static const _soundHint = 'Si sentono anche col telefono in silenzioso.';
  static const _rehearsal = 'Sala prove';
  static const _rehearsalHint = 'Rivedi le scene della notte, una per una.';

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        backgroundColor: AppColors.surface,
        showDragHandle: true,
        builder: (_) => const SettingsSheet(),
      );

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  @override
  Widget build(BuildContext context) {
    final stage = SoundStage.instance;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(SettingsSheet._title, textAlign: TextAlign.center, style: AppText.overline),
            const SizedBox(height: 8),
            SwitchListTile(
              value: stage.enabled,
              activeThumbColor: AppColors.gold,
              title: const Text(SettingsSheet._sound),
              subtitle: const Text(SettingsSheet._soundHint),
              secondary: const Icon(Icons.music_note, color: AppColors.gold),
              onChanged: (on) {
                setState(() => stage.enabled = on);
                if (!on) stage.stop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.movie_filter, color: AppColors.gold),
              title: const Text(SettingsSheet._rehearsal),
              subtitle: const Text(SettingsSheet._rehearsalHint),
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
  }
}
