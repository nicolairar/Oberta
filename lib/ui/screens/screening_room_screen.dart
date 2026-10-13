import 'dart:math';

import 'package:flutter/material.dart';

import '../../sound/sound_stage.dart';
import '../theme/app_theme.dart';
import '../widgets/death_scene.dart';
import '../widgets/scene_scaffold.dart';

/// La sala prove: tutte le scene della notte, da rivedere una per una senza
/// dover giocare una partita intera. Serve a chi le disegna e a chi vuole
/// mostrare agli amici "quella del pianoforte".
class ScreeningRoomScreen extends StatefulWidget {
  const ScreeningRoomScreen({super.key});

  @override
  State<ScreeningRoomScreen> createState() => _ScreeningRoomScreenState();
}

class _ScreeningRoomScreenState extends State<ScreeningRoomScreen> {
  static const _title = 'SALA PROVE';
  static const _intro = 'Tutte le scene della notte. Toccane una per rivederla.';
  static const _caption = 'Esterno, notte. Prova generale.';
  static const _extras = ['Marco', 'Giulia', 'Luca', 'Sara', 'Paolo', 'Elena', 'Davide', 'Chiara'];
  static const _endings = ['', 'gatto', 'sirene', 'carta', 'mambo', 'finestra', 'sipario'];

  static const _names = {
    DeathAct.knife: 'Il pugnale',
    DeathAct.gun: 'Il silenziatore',
    DeathAct.burst: 'La custodia da violino',
    DeathAct.car: 'L\'auto nera',
    DeathAct.piano: 'Il pianoforte',
    DeathAct.safe: 'La cassaforte',
    DeathAct.chandelier: 'Il lampadario',
    DeathAct.blast: 'Il pacco regalo',
    DeathAct.poison: 'Il caffè corretto',
    DeathAct.noose: 'Il cappio',
    DeathAct.grab: 'Le scarpe di cemento',
    DeathAct.bat: 'La mazza',
    DeathAct.lupara: 'La lupara',
    DeathAct.driveBy: 'La raffica dall\'auto',
    DeathAct.garrote: 'La garrota',
    DeathAct.pot: 'Il vaso dal terzo piano',
    DeathAct.manhole: 'Il tombino',
    DeathAct.blackout: 'Il buio',
    DeathAct.kiss: 'Il bacio',
    DeathAct.sniper: 'Il Cecchino',
    DeathAct.rescue: 'Il Dottore arriva in tempo',
    DeathAct.lucky: 'La fiaschetta',
  };

  final _random = Random();
  int _screenings = 0;

  void _screen(DeathAct act) {
    SoundStage.instance.prepare([act]);
    final take = _screenings++;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          body: DeathScene(
            act: act,
            victimName: _extras[_random.nextInt(_extras.length)],
            caption: _caption,
            epilogue: _endings[take % _endings.length],
            style: SkylineStyle.values[take % SkylineStyle.values.length],
            onFinished: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SceneScaffold(
      mood: SceneMood.night,
      appBar: AppBar(title: const Text(_title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          children: [
            const Text(_intro, textAlign: TextAlign.center, style: AppText.body),
            const SizedBox(height: 16),
            for (final act in DeathAct.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: OutlinedButton(
                  onPressed: () => _screen(act),
                  child: Row(
                    children: [
                      Icon(
                        act.survives ? Icons.favorite : Icons.movie_filter,
                        size: 20,
                        color: act.survives ? AppColors.gold : AppColors.accent,
                      ),
                      const SizedBox(width: 14),
                      Expanded(child: Text(_names[act]!, style: const TextStyle(letterSpacing: 0.5))),
                      const Icon(Icons.play_arrow, size: 20),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
