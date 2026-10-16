import 'dart:math';

import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../sound/cue_sounds.dart';
import '../../sound/sound_stage.dart';
import '../../sound/verdict_stage.dart';
import '../theme/app_theme.dart';
import '../widgets/death_scene.dart';
import '../widgets/verdict_scene.dart';
import '../widgets/scene_scaffold.dart';
import '../press.dart';

/// La sala prove: tutte le scene della notte, da rivedere una per una senza
/// dover giocare una partita intera. Serve a chi le disegna e a chi vuole
/// mostrare agli amici "quella del pianoforte".
class ScreeningRoomScreen extends StatefulWidget {
  const ScreeningRoomScreen({super.key});

  @override
  State<ScreeningRoomScreen> createState() => _ScreeningRoomScreenState();
}

class _ScreeningRoomScreenState extends State<ScreeningRoomScreen> {
  static const _extras = ['Marco', 'Giulia', 'Luca', 'Sara', 'Paolo', 'Elena', 'Davide', 'Chiara'];
  static const _endings = ['', 'gatto', 'sirene', 'carta', 'mambo', 'finestra', 'sipario'];

  final _random = Random();
  int _screenings = 0;

  /// Proietta [act]; con [save], l'agguato di [act] che [save] manda a vuoto.
  void _screen(DeathAct act, {DeathAct? save}) {
    SoundStage.instance.prepare([act, ?save]);
    final caption = AppStrings.of(context).screeningCaption;
    final take = _screenings++;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          body: DeathScene(
            act: act,
            save: save,
            victimName: _extras[_random.nextInt(_extras.length)],
            caption: caption,
            epilogue: _endings[take % _endings.length],
            style: SkylineStyle.values[take % SkylineStyle.values.length],
            onFinished: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    );
  }

  /// Un salvataggio o un colpo di fortuna sopra uno degli agguati della
  /// famiglia che sa mandare a vuoto, pescato a caso.
  void _screenSpliced(DeathAct save) {
    final attacks = [
      for (final act in DeathAct.values)
        if (canSpare(act, save) && spliceOf(act, save) != Splice.alone) act,
    ];
    if (attacks.isEmpty) return _screen(save);
    _screen(attacks[_random.nextInt(attacks.length)], save: save);
  }

  void _screenVerdict(VerdictTake take) {
    SoundStage.instance.prepareVerdicts([take]);
    final style = SkylineStyle.values[_screenings++ % SkylineStyle.values.length];
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          body: take == VerdictTake.assoluzione
              ? VerdictScene.acquittal(style: style, onFinished: () => Navigator.of(context).pop())
              : VerdictScene(
                  condemnedName: _extras[_random.nextInt(_extras.length)],
                  variant: take.name,
                  town: 'Palermo',
                  style: style,
                  onFinished: () => Navigator.of(context).pop(),
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    return SceneScaffold(
      mood: SceneMood.night,
      appBar: AppBar(title: Text(t.screeningTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          children: [
            Text(t.screeningIntro, textAlign: TextAlign.center, style: AppText.body),
            const SizedBox(height: 16),
            for (final act in DeathAct.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: OutlinedButton(
                  onPressed: pressed(() => _screen(act), Press.tap),
                  child: Row(
                    children: [
                      Icon(
                        act.survives ? Icons.favorite : Icons.movie_filter,
                        size: 20,
                        color: act.survives ? AppColors.gold : AppColors.accent,
                      ),
                      const SizedBox(width: 14),
                      Expanded(child: Text(t.sceneName(act), style: const TextStyle(letterSpacing: 0.5))),
                      if (act.survives)
                        IconButton(
                          icon: const Icon(Icons.shuffle, size: 20),
                          tooltip: t.screeningSpliced,
                          visualDensity: VisualDensity.compact,
                          onPressed: pressed(() => _screenSpliced(act), Press.tap),
                        ),
                      const Icon(Icons.play_arrow, size: 20),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 18),
            Text(t.screeningVerdicts, textAlign: TextAlign.center, style: AppText.overline),
            const SizedBox(height: 10),
            for (final take in VerdictTake.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: OutlinedButton(
                  onPressed: pressed(() => _screenVerdict(take), Press.tap),
                  child: Row(
                    children: [
                      const Icon(Icons.gavel, size: 20, color: AppColors.gold),
                      const SizedBox(width: 14),
                      Expanded(child: Text(t.verdictName(take), style: const TextStyle(letterSpacing: 0.5))),
                      const Icon(Icons.play_arrow, size: 20),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 18),
            Text(t.screeningEffects, textAlign: TextAlign.center, style: AppText.overline),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final cue in Cue.values)
                  ActionChip(
                    avatar: const Icon(Icons.volume_up, size: 18, color: AppColors.gold),
                    label: Text(t.cueName(cue)),
                    onPressed: () => SoundStage.instance.cue(cue),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
