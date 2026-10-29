import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../rules/player.dart';
import '../../rules/wheel_spin.dart';
import '../theme/app_theme.dart';
import '../widgets/revolver_cylinder.dart';
import '../widgets/scene_scaffold.dart';
import 'vote_mode_screen.dart';
import '../press.dart';

/// Il narratore si sorteggia alla maniera della famiglia: un nome per camera,
/// un giro di tamburo, e chi si ferma sotto il cane racconta.
class NarratorDrawScreen extends StatefulWidget {
  final List<Player> players;

  const NarratorDrawScreen({super.key, required this.players});

  @override
  State<NarratorDrawScreen> createState() => _NarratorDrawScreenState();
}

class _NarratorDrawScreenState extends State<NarratorDrawScreen> {
  // La camera sorteggiata deve fermarsi esattamente sotto il cane.
  late final WheelSpin _spin = WheelSpin.random(segmentCount: widget.players.length, spread: 0);
  bool _stopped = false;

  Player get _narrator => widget.players[_spin.winnerIndex];

  /// Il tamburo si gira una volta sola: si va avanti alla scelta del voto
  /// senza poter tornare a rigirarlo.
  void _continue() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => VoteModeScreen(players: widget.players, narrator: _narrator)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    return SceneScaffold(
      appBar: AppBar(title: Text(t.drawTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text(t.whoNarratesTonight, textAlign: TextAlign.center, style: AppText.display(30)),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(4, 40, 4, 24),
                    child: RevolverCylinder(
                      names: [for (final player in widget.players) player.name],
                      finalAngle: _spin.finalAngle,
                      winnerIndex: _spin.winnerIndex,
                      onStopped: () => setState(() => _stopped = true),
                    ),
                  ),
                ),
              ),
              AnimatedOpacity(
                opacity: _stopped ? 1 : 0,
                duration: const Duration(milliseconds: 500),
                child: Column(
                  children: [
                    Text(t.theNarratorIs, style: AppText.overline),
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _narrator.name.toUpperCase(),
                        style: AppText.display(34, color: AppColors.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: pressed(_stopped ? _continue : null, Press.confirm),
                  child: Text(t.continueLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
